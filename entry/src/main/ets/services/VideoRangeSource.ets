// Native AVPlayer consumes this loopback HTTP source. Remote Range requests
// use the app's actual proxy; validated chunks persist across player releases.
// No decoder is replaced and no second full-file download runs during playback.
import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { socket } from '@kit.NetworkKit';
import http from '@ohos.net.http';
import hilog from '@ohos.hilog';
import { proxyStore } from './ProxyStore';
import { videoNetworkEstimate } from './VideoNetworkEstimate';
import { VIDEO_RANGE_CHUNK_BYTES, VIDEO_RANGE_START_BYTES, VideoByteRange, VideoRemoteRange, videoRequestRange,
  videoHeader, videoResponseRange, videoResponseStatus, videoRangeKey } from './VideoRangeProtocol';

const DOMAIN: number = 0xFF00;
const TAG: string = 'HarmonyX-VideoRange';
const DIRECTORY: string = 'video-playback-cache/ranges';
const MAX_BYTES: number = 200 * 1024 * 1024;
const MAX_AGE_MS: number = 7 * 24 * 60 * 60 * 1000;
const SERVE_BYTES: number = 64 * 1024;
const MAX_CONNECTIONS: number = 6;
const CLIENT_IDLE_MS: number = 10000;

class RangeClientState {
  header: string = '';
  busy: boolean = false;
  idleTimer: number = -1;
}

class RangeMetadata {
  total: number = 0;
  validator: string = '';
  lastAccessMs: number = 0;
}

class RangeCacheFile {
  name: string;
  bytes: number;
  accessMs: number;
  completed: boolean;
  constructor(name: string, bytes: number, accessMs: number, completed: boolean = false) {
    this.name = name; this.bytes = bytes; this.accessMs = accessMs; this.completed = completed;
  }
}

class RangeFetchJob {
  priority: () => number;
  run: () => Promise<void>;
  constructor(priority: () => number, run: () => Promise<void>) {
    this.priority = priority; this.run = run;
  }
}

// Two remote requests across all players. Current playback gets the next slot
// ahead of preloading; a seek can fetch its tail beside the current head.
class RangeFetchScheduler {
  private active: number = 0;
  private jobs: RangeFetchJob[] = [];
  schedule<T>(priority: () => number, task: () => Promise<T>): Promise<T> {
    return new Promise<T>((resolve: (value: T) => void, reject: (reason: Error) => void): void => {
      this.jobs.push(new RangeFetchJob(priority, async (): Promise<void> => {
        try { resolve(await task()); } catch (error) { reject(error as Error); }
      }));
      this.pump();
    });
  }
  refresh(): void { this.pump(); }
  private pump(): void {
    while (this.active < 2 && this.jobs.length > 0) {
      let index: number = -1;
      let priority: number = 0;
      for (let i: number = 0; i < this.jobs.length; i++) {
        const candidate: number = this.jobs[i].priority();
        if (candidate > priority) { index = i; priority = candidate; }
      }
      // Leave a slot available for a newly visible player. Background work
      // waits while foreground transfers keep the current buffer growing.
      if (index < 0 && this.active > 0) { return; }
      if (index < 0) { index = 0; }
      const job: RangeFetchJob = this.jobs.splice(index, 1)[0];
      this.active++;
      job.run().finally((): void => { this.active--; this.pump(); });
    }
  }
}

const rangeFetchScheduler: RangeFetchScheduler = new RangeFetchScheduler();

// Only active transfers allocate a chunk. Readers can consume validated
// response prefixes before the complete body is eligible for disk caching.
class RangeStreamBuffer {
  received: number = 0;
  overflow: boolean = false;
  private capacity: number;
  private data: Uint8Array = new Uint8Array(0);
  private streamable: boolean = false;
  private finished: boolean = false;
  private successful: boolean = false;
  private waiters: Array<() => void> = [];
  private cancelListeners: Array<() => void> = [];
  constructor(capacity: number) { this.capacity = capacity; }
  restart(): void {
    this.data = new Uint8Array(this.capacity); this.received = 0;
    this.overflow = false; this.streamable = false;
  }
  allowStreaming(allowed: boolean): void { this.streamable = allowed; this.wake(); }
  append(data: ArrayBuffer): boolean {
    if (this.finished) { return false; }
    if (this.received + data.byteLength > this.capacity) { this.overflow = true; return false; }
    this.data.set(new Uint8Array(data), this.received); this.received += data.byteLength;
    this.wake(); return true;
  }
  body(): ArrayBuffer { return this.data.buffer.slice(0, this.received); }
  finish(successful: boolean): void {
    this.finished = true; this.successful = successful; this.wake();
    const listeners: Array<() => void> = this.cancelListeners;
    this.cancelListeners = [];
    if (!successful) { for (let i: number = 0; i < listeners.length; i++) { listeners[i](); } }
  }
  onCancelled(listener: () => void): void {
    if (this.finished && !this.successful) { listener(); }
    else { this.cancelListeners.push(listener); }
  }
  async read(offset: number, length: number): Promise<ArrayBuffer | null> {
    while (!this.finished && (!this.streamable || this.received < offset + length)) {
      await new Promise<void>((resolve: () => void): void => { this.waiters.push(resolve); });
    }
    if ((this.finished && !this.successful) || this.received < offset + length) { return null; }
    return this.data.buffer.slice(offset, offset + length);
  }
  private wake(): void {
    const waiters: Array<() => void> = this.waiters;
    this.waiters = [];
    for (let i: number = 0; i < waiters.length; i++) { waiters[i](); }
  }
}

class RangeStreamResponse {
  code: number = 0;
  headerText: string = '{}';
  data: ArrayBuffer = new ArrayBuffer(0);
}

export class VideoRangeLease {
  url: string;
  private session: VideoRangeSession;
  private closed: boolean = false;
  private foreground: boolean;
  constructor(session: VideoRangeSession, foreground: boolean) {
    this.session = session; this.url = session.url; this.foreground = foreground;
  }
  setForeground(foreground: boolean): void {
    if (this.closed || this.foreground === foreground) { return; }
    this.session.updateForeground(this.foreground, foreground); this.foreground = foreground;
  }
  copyCompleteTo(path: string): Promise<boolean> {
    return this.closed ? Promise.resolve(false) : this.session.copyCompleteTo(path);
  }
  close(): void {
    if (!this.closed) { this.closed = true; this.session.release(this.foreground); }
  }
}

class VideoRangeSession {
  url: string = '';
  foreground: boolean;
  retired: boolean = false;
  references: number = 0;
  private foregroundReferences: number = 0;
  private directory: string;
  private key: string;
  private remoteUrl: string;
  private metadata: RangeMetadata = new RangeMetadata();
  private server: socket.TCPSocketServer | null = null;
  private clients: Map<number, socket.TCPSocketConnection> = new Map<number, socket.TCPSocketConnection>();
  private clientStates: Map<number, RangeClientState> = new Map<number, RangeClientState>();
  private pending: Map<number, Promise<boolean>> = new Map<number, Promise<boolean>>();
  private transfers: Map<number, RangeStreamBuffer> = new Map<number, RangeStreamBuffer>();
  private demands: Map<number, boolean> = new Map<number, boolean>();
  private requests: http.HttpRequest[] = [];
  private closed: boolean = false;
  private onClosed: () => void;
  private onChunk: () => void;
  private createdAt: number = Date.now();
  private remoteBytes: number = 0;
  private cacheHits: number = 0;
  private servedRequests: number = 0;
  private pins: Map<number, number> = new Map<number, number>();
  private accesses: Map<number, number> = new Map<number, number>();

  constructor(directory: string, key: string, remoteUrl: string, foreground: boolean,
    onClosed: () => void, onChunk: () => void) {
    this.directory = directory; this.key = key; this.remoteUrl = remoteUrl; this.foreground = foreground;
    this.onClosed = onClosed; this.onChunk = onChunk;
  }

  async start(): Promise<boolean> {
    try {
      this.loadMetadata();
      // The first GET returns both the size and usable bytes. No HEAD round trip.
      if (this.metadata.total <= 0 && !await rangeFetchScheduler.schedule<boolean>((): number => this.foreground ? 2 : 0,
        (): Promise<boolean> => this.fetchChunk(0, true))) { this.close(); return false; }
      if (this.closed) { return false; }
      const server: socket.TCPSocketServer = socket.constructTCPSocketServerInstance();
      this.server = server;
      server.on('connect', (client: socket.TCPSocketConnection): void => this.connect(client));
      server.on('error', (): void => {
        if (!this.closed) { hilog.warn(DOMAIN, TAG, 'loopback server error key=%{public}s', this.key); }
      });
      await server.listen({ address: '127.0.0.1', port: 0, family: 1 });
      const address: socket.NetAddress = await server.getLocalAddress();
      if (this.closed || address.port === undefined) {
        await server.close().catch((): void => {}); this.close(); return false;
      }
      this.url = 'http://127.0.0.1:' + address.port.toString() + '/video/' + this.key;
      this.metadata.lastAccessMs = Date.now(); this.saveMetadata();
      hilog.info(DOMAIN, TAG, 'stream ready key=%{public}s size=%{public}d startupMs=%{public}d',
        this.key, this.metadata.total, Date.now() - this.createdAt);
      return true;
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'stream open failed key=%{public}s', this.key);
      this.close(); return false;
    }
  }

  acquire(foreground: boolean): VideoRangeLease {
    this.references++; this.updateForeground(false, foreground);
    return new VideoRangeLease(this, foreground);
  }
  updateForeground(previous: boolean, next: boolean): void {
    if (previous) { this.foregroundReferences--; }
    if (next) { this.foregroundReferences++; }
    this.foreground = this.foregroundReferences > 0; rangeFetchScheduler.refresh();
  }
  release(foreground: boolean): void {
    this.updateForeground(foreground, false);
    if (--this.references <= 0) { this.close(); }
  }

  // Export only complete, validated spans. Recovery never downloads missing
  // data or trusts an unfinished streaming response as a completed MP4.
  async copyCompleteTo(path: string): Promise<boolean> {
    if (this.closed || this.retired || this.metadata.total <= 0 || this.metadata.total > MAX_BYTES) { return false; }
    const count: number = Math.ceil(this.metadata.total / VIDEO_RANGE_CHUNK_BYTES);
    for (let index: number = 0; index < count; index++) {
      if (!this.hasChunk(index) && !(index === 0 && this.metadata.total <= VIDEO_RANGE_START_BYTES && this.hasHead())) {
        return false;
      }
    }
    for (let index: number = 0; index < count; index++) {
      this.pins.set(index, (this.pins.get(index) ?? 0) + 1);
    }
    let output: fileIo.File | null = null;
    try {
      output = await fileIo.open(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC | fileIo.OpenMode.WRITE_ONLY);
      for (let index: number = 0; index < count; index++) {
        if (this.closed || this.retired) { return false; }
        const input: fileIo.File = await fileIo.open(this.hasChunk(index) ? this.chunkPath(index) : this.headPath(),
          fileIo.OpenMode.READ_ONLY);
        try {
          const size: number = this.chunkLength(index);
          for (let offset: number = 0; offset < size; offset += SERVE_BYTES) {
            if (this.closed || this.retired) { return false; }
            const length: number = Math.min(SERVE_BYTES, size - offset);
            const data: ArrayBuffer = new ArrayBuffer(length);
            if (await fileIo.read(input.fd, data, { length: length }) !== length ||
              await fileIo.write(output.fd, data) !== length) { return false; }
          }
        } finally { await fileIo.close(input.fd); }
      }
      return !this.closed && !this.retired && fileIo.statSync(path).size === this.metadata.total;
    } catch (error) { return false; }
    finally {
      if (output !== null) { await fileIo.close(output.fd); }
      for (let index: number = 0; index < count; index++) {
        const remaining: number = (this.pins.get(index) ?? 1) - 1;
        if (remaining > 0) { this.pins.set(index, remaining); } else { this.pins.delete(index); }
      }
    }
  }

  pinned(name: string): boolean {
    if (name === this.key + '.meta') { return true; }
    const index: number = Number(name.substring(this.key.length + 1, name.lastIndexOf('.')));
    return (this.pins.get(index) ?? 0) > 0;
  }

  accessTime(name: string, fallback: number): number {
    const index: number = Number(name.substring(this.key.length + 1, name.lastIndexOf('.')));
    return this.accesses.get(index) ?? fallback;
  }

  close(): void {
    if (this.closed) { return; }
    this.closed = true;
    for (const transfer of this.transfers.values()) { transfer.finish(false); }
    this.transfers.clear();
    for (let i: number = 0; i < this.requests.length; i++) {
      try { this.requests[i].destroy(); } catch (error) {}
    }
    this.requests = [];
    for (const state of this.clientStates.values()) { if (state.idleTimer >= 0) { clearTimeout(state.idleTimer); } }
    for (const client of this.clients.values()) { client.close().catch((): void => {}); }
    this.clients.clear(); this.clientStates.clear();
    const server: socket.TCPSocketServer | null = this.server;
    this.server = null;
    if (server !== null) { server.close().catch((): void => {}); }
    hilog.info(DOMAIN, TAG, 'stream closed key=%{public}s remoteBytes=%{public}d cacheHits=%{public}d',
      this.key, this.remoteBytes, this.cacheHits);
    this.onClosed();
  }

  private chunkPath(index: number): string { return this.directory + '/' + this.key + '-' + index.toString() + '.chunk'; }
  private headPath(): string { return this.directory + '/' + this.key + '-0.head'; }
  private metadataPath(): string { return this.directory + '/' + this.key + '.meta'; }
  private chunkLength(index: number): number {
    return this.metadata.total <= 0 ? VIDEO_RANGE_CHUNK_BYTES :
      Math.min(VIDEO_RANGE_CHUNK_BYTES, this.metadata.total - index * VIDEO_RANGE_CHUNK_BYTES);
  }

  private loadMetadata(): void {
    try {
      const metadata: RangeMetadata = JSON.parse(fileIo.readTextSync(this.metadataPath())) as RangeMetadata;
      if (Number.isSafeInteger(metadata.total) && metadata.total > 0 &&
        metadata.total <= 2 * 1024 * 1024 * 1024 && metadata.lastAccessMs > Date.now() - MAX_AGE_MS &&
        typeof metadata.validator === 'string') { this.metadata = metadata; return; }
    } catch (error) { /* A missing or evicted cache starts with a range probe. */ }
    // A new probe must never make chunks from an expired/damaged index valid.
    const names: string[] = fileIo.listFileSync(this.directory);
    for (let i: number = 0; i < names.length; i++) {
      if (names[i] === this.key + '.meta' || names[i].startsWith(this.key + '-')) {
        try { fileIo.unlinkSync(this.directory + '/' + names[i]); } catch (error) {}
      }
    }
  }

  private saveMetadata(): void {
    if (this.retired || this.closed) { return; }
    let file: fileIo.File | null = null;
    try {
      file = fileIo.openSync(this.metadataPath(), fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC | fileIo.OpenMode.WRITE_ONLY);
      fileIo.writeSync(file.fd, JSON.stringify(this.metadata));
    } catch (error) { /* Cache persistence failure does not change fetched bytes. */ }
    finally { if (file !== null) { fileIo.closeSync(file.fd); } }
  }

  private hasChunk(index: number): boolean {
    if (this.metadata.total <= 0) { return false; }
    try { return fileIo.statSync(this.chunkPath(index)).size === this.chunkLength(index); }
    catch (error) { return false; }
  }

  private hasHead(): boolean {
    try { return fileIo.statSync(this.headPath()).size === Math.min(VIDEO_RANGE_START_BYTES, this.metadata.total); }
    catch (error) { return false; }
  }

  private ensureChunk(index: number, speculative: boolean = false): Promise<boolean> {
    if (this.closed || index < 0 || (this.metadata.total > 0 && this.chunkLength(index) <= 0)) {
      return Promise.resolve(false);
    }
    this.accesses.set(index, Date.now());
    if (this.hasChunk(index)) { this.cacheHits++; return Promise.resolve(true); }
    const existing: Promise<boolean> | undefined = this.pending.get(index);
    this.demands.set(index, (this.demands.get(index) ?? false) || !speculative);
    if (existing !== undefined) { rangeFetchScheduler.refresh(); return existing; }
    const transfer: RangeStreamBuffer = new RangeStreamBuffer(this.chunkLength(index));
    this.transfers.set(index, transfer);
    const operation: Promise<boolean> = rangeFetchScheduler.schedule<boolean>((): number =>
      this.foreground ? (this.demands.get(index) === true ? 2 : 1) : 0,
      (): Promise<boolean> => this.fetchChunk(index, false, transfer));
    this.pending.set(index, operation);
    operation.then((successful: boolean): void => {
      transfer.finish(successful);
      this.pending.delete(index); this.demands.delete(index); this.transfers.delete(index);
    }).catch((): void => {
      transfer.finish(false);
      this.pending.delete(index); this.demands.delete(index); this.transfers.delete(index);
    });
    return operation;
  }

  private validStreamHeaders(headerText: string, start: number, length: number): boolean {
    const range: VideoRemoteRange | null = videoResponseRange(headerText);
    if (range === null || range.start !== start || range.total !== this.metadata.total ||
      range.end !== Math.min(start + length - 1, range.total - 1)) { return false; }
    const size: string = videoHeader(headerText, 'content-length');
    if (size.length > 0 && Number(size) !== range.end - range.start + 1) { return false; }
    const validator: string = videoHeader(headerText, 'etag');
    return !this.metadata.validator.startsWith('"') || validator.length === 0 || validator === this.metadata.validator;
  }

  private async receiveStream(request: http.HttpRequest, options: http.HttpRequestOptions,
    start: number, length: number, transfer: RangeStreamBuffer): Promise<RangeStreamResponse> {
    const response: RangeStreamResponse = new RangeStreamResponse();
    const started: number = Date.now();
    let firstByteMs: number = 0;
    transfer.restart();
    request.on('headersReceive', (header: Object): void => {
      response.headerText = JSON.stringify(header);
      // status-line is the documented header field. If it is unavailable,
      // retain bytes privately until the final status code is confirmed.
      transfer.allowStreaming(videoResponseStatus(response.headerText) === 206 &&
        this.validStreamHeaders(response.headerText, start, length));
    });
    request.on('dataReceive', (data: ArrayBuffer): void => {
      if (this.closed) { return; }
      if (firstByteMs === 0) { firstByteMs = Date.now() - started; }
      if (!transfer.append(data)) { transfer.finish(false); request.destroy(); }
    });
    const ended: Promise<void> = new Promise<void>((resolve: () => void): void => {
      request.on('dataEnd', (): void => { resolve(); });
    });
    const cancelled: Promise<number> = new Promise<number>((resolve: (code: number) => void): void => {
      transfer.onCancelled((): void => { resolve(0); });
    });
    const completed: Promise<number> = request.requestInStream(this.remoteUrl, options)
      .then(async (code: number): Promise<number> => { await ended; return code; });
    // Some platform versions settle the status before dataEnd. Cancellation
    // must still release the scheduler slot when dataEnd will never arrive.
    const code: number = await Promise.race<number>([completed, cancelled]);
    response.code = code; response.data = transfer.body();
    if (start === 0) {
      hilog.info(DOMAIN, TAG, 'streamed range key=%{public}s bytes=%{public}d firstByteMs=%{public}d totalMs=%{public}d',
        this.key, response.data.byteLength, firstByteMs, Date.now() - started);
    }
    return response;
  }

  private async fetchChunk(index: number, bootstrap: boolean = false,
    transfer: RangeStreamBuffer | null = null): Promise<boolean> {
    for (let attempt: number = 0; attempt < 2 && !this.closed; attempt++) {
      let request: http.HttpRequest | null = null;
      try {
        const start: number = index * VIDEO_RANGE_CHUNK_BYTES;
        const length: number = bootstrap ? VIDEO_RANGE_START_BYTES : this.chunkLength(index);
        const header: Record<string, string> = {
          'Range': 'bytes=' + start.toString() + '-' + (start + length - 1).toString(),
          'Accept-Encoding': 'identity', 'User-Agent': 'HarmonyX media'
        };
        if (this.metadata.validator.length > 0) { header['If-Range'] = this.metadata.validator; }
        const options: http.HttpRequestOptions = { method: http.RequestMethod.GET, header: header,
          expectDataType: http.HttpDataType.ARRAY_BUFFER, usingCache: false, maxLimit: VIDEO_RANGE_CHUNK_BYTES,
          connectTimeout: 5000, readTimeout: 8000 };
        await proxyStore.applyForMediaRequest(options, this.remoteUrl);
        if (this.closed) { return false; }
        request = http.createHttp(); this.requests.push(request);
        const started: number = Date.now();
        let code: number = 0;
        let headerText: string = '{}';
        let data: ArrayBuffer = new ArrayBuffer(0);
        if (transfer === null) {
          const response: http.HttpResponse = await request.request(this.remoteUrl, options);
          code = response.responseCode; headerText = JSON.stringify(response.header); data = response.result as ArrayBuffer;
          const timing: http.PerformanceTiming = response.performanceTiming;
          if (timing !== undefined) {
            hilog.info(DOMAIN, TAG, 'first range key=%{public}s bytes=%{public}d dnsMs=%{public}d tlsMs=%{public}d firstByteMs=%{public}d totalMs=%{public}d',
              this.key, length, timing.dnsTiming, timing.tlsTiming, timing.firstReceiveTiming, timing.totalTiming);
          }
        } else {
          const response: RangeStreamResponse = await this.receiveStream(request, options, start, length, transfer);
          code = response.code; headerText = response.headerText; data = response.data;
        }
        if (this.closed) { return false; }
        const range: VideoRemoteRange | null = videoResponseRange(headerText);
        if ((code >= 500 || code === 408 || code === 429) && attempt === 0) {
          continue;
        }
        if (code === 206 && range !== null && range.start === start &&
          range.end === Math.min(start + length - 1, range.total - 1) &&
          data.byteLength === range.end - range.start + 1 &&
          (this.metadata.total <= 0 || range.total === this.metadata.total)) {
          const validator: string = videoHeader(headerText, 'etag');
          if (this.metadata.validator.startsWith('"') && validator.length > 0 && validator !== this.metadata.validator) {
            return false;
          }
          if (this.metadata.total <= 0) {
            this.metadata.total = range.total;
            const etag: string = videoHeader(headerText, 'etag');
            this.metadata.validator = etag.startsWith('W/') ? videoHeader(headerText, 'last-modified') :
              (etag.length > 0 ? etag : videoHeader(headerText, 'last-modified'));
          }
        } else if (code === 200 && start === 0 && this.metadata.total <= 0 &&
          data.byteLength > 0 && data.byteLength <= length &&
          Number(videoHeader(headerText, 'content-length')) === data.byteLength) {
          this.metadata.total = data.byteLength;
        } else {
          hilog.warn(DOMAIN, TAG, 'invalid range key=%{public}s status=%{public}d offset=%{public}d',
            this.key, code, start);
          return false;
        }
        if (this.metadata.total > 2 * 1024 * 1024 * 1024) { return false; }
        videoNetworkEstimate.record(this.remoteUrl, data.byteLength, Date.now() - started, this.foreground);
        this.remoteBytes += data.byteLength;
        let file: fileIo.File | null = null;
        try {
          file = await fileIo.open(bootstrap ? this.headPath() : this.chunkPath(index),
            fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC | fileIo.OpenMode.WRITE_ONLY);
          const written: number = await fileIo.write(file.fd, data);
          if (written !== data.byteLength) { return false; }
        } finally { if (file !== null) { await fileIo.close(file.fd); } }
        if (this.closed && this.retired) {
          try { fileIo.unlinkSync(bootstrap ? this.headPath() : this.chunkPath(index)); } catch (error) {}
          return false;
        }
        this.metadata.lastAccessMs = Date.now(); this.saveMetadata(); this.onChunk();
        return true;
      } catch (error) {
        if (transfer !== null && transfer.overflow) { return false; }
        if (!this.closed && attempt === 1) {
          proxyStore.noteNetworkFailure(this.remoteUrl);
          hilog.warn(DOMAIN, TAG, 'range transfer failed key=%{public}s chunk=%{public}d', this.key, index);
        }
      } finally {
        if (request !== null) {
          const requestIndex: number = this.requests.indexOf(request);
          if (requestIndex >= 0) { this.requests.splice(requestIndex, 1); }
          try { request.destroy(); } catch (error) {}
        }
      }
    }
    return false;
  }

  private async readChunk(index: number, offset: number, length: number): Promise<ArrayBuffer> {
    if (!this.hasChunk(index)) {
      const pending: Promise<boolean> = this.ensureChunk(index);
      const transfer: RangeStreamBuffer | undefined = this.transfers.get(index);
      if (transfer !== undefined) {
        const streamed: ArrayBuffer | null = await transfer.read(offset, length);
        if (streamed === null) { throw new Error('video range unavailable'); }
        return streamed;
      }
      if (!await pending) { throw new Error('video range unavailable'); }
    } else { this.cacheHits++; this.accesses.set(index, Date.now()); }
    const data: ArrayBuffer = new ArrayBuffer(length);
    const file: fileIo.File = await fileIo.open(this.chunkPath(index), fileIo.OpenMode.READ_ONLY);
    let read: number = 0;
    try { read = await fileIo.read(file.fd, data, { offset: offset, length: length }); }
    finally { await fileIo.close(file.fd); }
    if (read !== length) { throw new Error('video cache short read'); }
    return data;
  }

  private connect(client: socket.TCPSocketConnection): void {
    if (this.closed || this.clients.size >= MAX_CONNECTIONS) {
      if (!this.closed) { hilog.warn(DOMAIN, TAG, 'player connections full key=%{public}s', this.key); }
      client.close().catch((): void => {}); return;
    }
    const state: RangeClientState = new RangeClientState();
    this.clients.set(client.clientId, client); this.clientStates.set(client.clientId, state);
    client.on('close', (): void => {
      if (state.idleTimer >= 0) { clearTimeout(state.idleTimer); }
      this.clients.delete(client.clientId); this.clientStates.delete(client.clientId);
    });
    client.on('error', (): void => { client.close().catch((): void => {}); });
    client.on('message', (info: socket.SocketMessageInfo): void => {
      const bytes: Uint8Array = new Uint8Array(info.message);
      for (let i: number = 0; i < bytes.length && state.header.length <= 8192; i++) {
        state.header += String.fromCharCode(bytes[i]);
      }
      if (state.header.length > 8192) { client.close().catch((): void => {}); return; }
      this.processClient(client, state);
    });
    this.armClientIdle(client, state);
  }

  private armClientIdle(client: socket.TCPSocketConnection, state: RangeClientState): void {
    if (state.idleTimer >= 0) { clearTimeout(state.idleTimer); }
    state.idleTimer = setTimeout((): void => {
      state.idleTimer = -1;
      if (!state.busy) { client.close().catch((): void => {}); }
    }, CLIENT_IDLE_MS);
  }

  private processClient(client: socket.TCPSocketConnection, state: RangeClientState): void {
    if (this.closed || state.busy || !this.clients.has(client.clientId)) { return; }
    const end: number = state.header.indexOf('\r\n\r\n');
    if (end < 0) { return; }
    const request: string = state.header.substring(0, end + 4);
    state.header = state.header.substring(end + 4);
    if (state.idleTimer >= 0) { clearTimeout(state.idleTimer); state.idleTimer = -1; }
    state.busy = true;
    this.serve(client, request).catch((error: Error): void => {
        if (!this.closed && this.clients.has(client.clientId)) {
          hilog.warn(DOMAIN, TAG, 'player response failed key=%{public}s reason=%{public}s', this.key, error.message);
        }
        client.close().catch((): void => {});
    }).finally((): void => {
      state.busy = false;
      if (this.closed || !this.clients.has(client.clientId)) { return; }
      this.armClientIdle(client, state);
      this.processClient(client, state);
    });
  }

  private async serve(client: socket.TCPSocketConnection, request: string): Promise<void> {
    const parts: string[] = request.split('\r\n')[0].split(' ');
    const method: string = parts[0];
    if ((method !== 'GET' && method !== 'HEAD') || parts[1] !== '/video/' + this.key) {
      await this.sendStatus(client, '404 Not Found'); return;
    }
    const range: VideoByteRange | null = videoRequestRange(request, this.metadata.total);
    if (range === null) {
      hilog.warn(DOMAIN, TAG, 'player range rejected key=%{public}s total=%{public}d', this.key, this.metadata.total);
      await this.sendStatus(client, '416 Range Not Satisfiable', 'Content-Range: bytes */' + this.metadata.total.toString() + '\r\n');
      return;
    }
    const diagnostic: boolean = method === 'GET' && this.servedRequests++ < 6;
    if (diagnostic) {
      hilog.info(DOMAIN, TAG, 'player range key=%{public}s start=%{public}d end=%{public}d foreground=%{public}d',
        this.key, range.start, range.end, this.foreground ? 1 : 0);
    }
    let headers: string = 'HTTP/1.1 ' + (range.partial ? '206 Partial Content' : '200 OK') +
      '\r\nContent-Type: video/mp4\r\nAccept-Ranges: bytes\r\nContent-Length: ' + (range.end - range.start + 1).toString() + '\r\n';
    if (range.partial) {
      headers += 'Content-Range: bytes ' + range.start.toString() + '-' + range.end.toString() + '/' + this.metadata.total.toString() + '\r\n';
    }
    const close: boolean = /\r\nconnection\s*:\s*close\s*\r\n/i.test(request);
    await client.send({ data: headers + (close ? 'Connection: close\r\n\r\n' :
      'Connection: keep-alive\r\nKeep-Alive: timeout=10\r\n\r\n') });
    if (method === 'HEAD') { if (close) { await client.close(); } return; }
    let position: number = range.start;
    while (!this.closed && this.clients.has(client.clientId) && position <= range.end) {
      const index: number = Math.floor(position / VIDEO_RANGE_CHUNK_BYTES);
      this.pins.set(index, (this.pins.get(index) ?? 0) + 1);
      try {
        // Hand the parser 64 KB immediately, while the full aligned chunk
        // downloads beside it. Existing 256 KB disk spans remain compatible.
        const head: boolean = index === 0 && position < VIDEO_RANGE_START_BYTES && !this.hasChunk(0) && this.hasHead();
        if (!head) { this.ensureChunk(index).catch((): boolean => false); }
        if (this.closed || !this.clients.has(client.clientId)) { return; }
        // Keep two CDN chunks in flight so local sends are not the only work
        // overlapping a round trip. Actual reads/seeks outrank lookahead.
        if (head && range.end >= VIDEO_RANGE_START_BYTES) {
          this.ensureChunk(0, true).catch((): boolean => false);
        }
        if (this.foreground) {
          const ahead: number = head ? 1 : 2;
          for (let next: number = index + 1; next <= index + ahead; next++) {
            if (next * VIDEO_RANGE_CHUNK_BYTES > range.end) { break; }
            this.ensureChunk(next, true).catch((): boolean => false);
          }
        }
        const offset: number = position % VIDEO_RANGE_CHUNK_BYTES;
        const available: number = head ? Math.min(VIDEO_RANGE_START_BYTES, this.metadata.total) : this.chunkLength(index);
        const length: number = Math.min(SERVE_BYTES, available - offset, range.end - position + 1);
        let data: ArrayBuffer;
        if (head) {
          data = new ArrayBuffer(length);
          const file: fileIo.File = await fileIo.open(this.headPath(), fileIo.OpenMode.READ_ONLY);
          try {
            if (await fileIo.read(file.fd, data, { offset: offset, length: length }) !== length) {
              throw new Error('video cache short read');
            }
          } finally { await fileIo.close(file.fd); }
        } else { data = await this.readChunk(index, offset, length); }
        if (this.closed || !this.clients.has(client.clientId)) { return; }
        await client.send({ data: data }); position += length;
      } finally {
        const count: number = (this.pins.get(index) ?? 1) - 1;
        if (count > 0) { this.pins.set(index, count); } else { this.pins.delete(index); }
      }
    }
    if (diagnostic && position > range.end) {
      hilog.info(DOMAIN, TAG, 'player range complete key=%{public}s start=%{public}d bytes=%{public}d',
        this.key, range.start, position - range.start);
    }
    // Content-Length already delimits the response. Let the native downloader
    // reuse the connection; an eager shutdown can race its final parser read.
    if (close) { await client.close(); }
  }

  private async sendStatus(client: socket.TCPSocketConnection, status: string, extra: string = ''): Promise<void> {
    await client.send({ data: 'HTTP/1.1 ' + status + '\r\n' + extra + 'Content-Length: 0\r\nConnection: close\r\n\r\n' });
    await client.close();
  }
}

class VideoRangeSourceStore {
  private directory: string = '';
  private opening: Map<string, Promise<VideoRangeSession | null>> = new Map<string, Promise<VideoRangeSession | null>>();
  private sessions: Map<string, VideoRangeSession> = new Map<string, VideoRangeSession>();
  private writes: number = 0;
  private trimOperation: Promise<void> | null = null;
  private trimRequested: boolean = false;
  private completedProtected: (name: string) => boolean = (_name: string): boolean => true;
  private completedAccess: (name: string, fallback: number) => number = (_name: string, fallback: number): number => fallback;
  private completedRemove: (name: string) => void = (_name: string): void => {};

  setCompletedCachePolicy(protectedFile: (name: string) => boolean,
    access: (name: string, fallback: number) => number, remove: (name: string) => void): void {
    this.completedProtected = protectedFile; this.completedAccess = access; this.completedRemove = remove;
  }

  async open(context: common.UIAbilityContext, mediaId: string, rendition: string, remoteUrl: string,
    foreground: boolean): Promise<VideoRangeLease | null> {
    this.ensureDirectory(context);
    const key: string = videoRangeKey(mediaId, rendition, remoteUrl);
    let operation: Promise<VideoRangeSession | null> | undefined = this.opening.get(key);
    const current: VideoRangeSession | undefined = this.sessions.get(key);
    if (current !== undefined && current.retired) { return null; }
    if (current !== undefined && foreground) { current.foreground = true; }
    if (operation === undefined && current !== undefined) {
      return current.acquire(foreground);
    }
    if (operation === undefined) {
      const session: VideoRangeSession = new VideoRangeSession(this.directory, key, remoteUrl, foreground,
        (): void => {
          if (this.sessions.get(key) === session) { this.sessions.delete(key); }
          if (session.retired) { this.removeKey(key); }
          this.trim();
        }, (): void => { if (++this.writes % 32 === 0) { this.trim(); } });
      this.sessions.set(key, session);
      operation = session.start().then((ready: boolean): VideoRangeSession | null => ready ? session : null);
      this.opening.set(key, operation);
    }
    const opened: VideoRangeSession | null = await operation;
    if (this.opening.get(key) === operation) { this.opening.delete(key); }
    if (opened === null) { return null; }
    if (opened.retired) {
      if (opened.references === 0) { opened.close(); }
      return null;
    }
    return opened.acquire(foreground);
  }

  clear(context: common.UIAbilityContext): void {
    this.ensureDirectory(context);
    for (const session of this.sessions.values()) { session.retired = true; }
    const names: string[] = fileIo.listFileSync(this.directory);
    for (let i: number = 0; i < names.length; i++) {
      if (!this.isActiveFile(names[i])) { this.removeFile(names[i]); }
    }
  }

  size(context: common.UIAbilityContext): number {
    this.ensureDirectory(context);
    let bytes: number = 0;
    try {
      const names: string[] = fileIo.listFileSync(this.directory);
      for (let i: number = 0; i < names.length; i++) { bytes += fileIo.statSync(this.directory + '/' + names[i]).size; }
    } catch (error) {}
    return bytes;
  }

  trimToBudget(): Promise<void> { return this.trim(); }

  invalidate(context: common.UIAbilityContext, mediaId: string, rendition: string, remoteUrl: string): void {
    this.ensureDirectory(context);
    const key: string = videoRangeKey(mediaId, rendition, remoteUrl);
    const session: VideoRangeSession | undefined = this.sessions.get(key);
    if (session !== undefined) { session.retired = true; } else { this.removeKey(key); }
  }

  private ensureDirectory(context: common.UIAbilityContext): void {
    const directory: string = context.cacheDir + '/' + DIRECTORY;
    if (this.directory === directory) { return; }
    this.directory = directory;
    if (!fileIo.accessSync(directory)) { fileIo.mkdirSync(directory, true); }
    this.trim();
  }

  private isActiveFile(name: string): boolean {
    for (const key of this.sessions.keys()) { if (name === key + '.meta' || name.startsWith(key + '-')) { return true; } }
    return false;
  }

  private sessionForFile(name: string): VideoRangeSession | null {
    for (const entry of this.sessions.entries()) {
      if (name === entry[0] + '.meta' || name.startsWith(entry[0] + '-')) { return entry[1]; }
    }
    return null;
  }

  private trim(): Promise<void> {
    this.trimRequested = true;
    if (this.trimOperation !== null) { return this.trimOperation; }
    const operation: Promise<void> = this.drainTrimRequests().finally((): void => {
      this.trimOperation = null;
      if (this.trimRequested) { this.trim(); }
    });
    this.trimOperation = operation;
    return operation;
  }

  private async drainTrimRequests(): Promise<void> {
    while (this.trimRequested) {
      this.trimRequested = false;
      await this.trimFiles();
    }
  }

  // Directory enumeration and metadata reads must yield to scrolling/playback.
  // Coalesce concurrent opens, closes and chunk writes into one cache sweep.
  private async trimFiles(): Promise<void> {
    if (this.directory.length === 0) { return; }
    const directory: string = this.directory;
    try {
      const names: string[] = await fileIo.listFile(directory);
      let total: number = 0;
      const candidates: RangeCacheFile[] = [];
      const parent: string = directory.substring(0, directory.lastIndexOf('/'));
      const legacyNames: string[] = await fileIo.listFile(parent);
      // Completed MP4s and streamed chunks share the same 200 MB budget.
      for (let i: number = 0; i < legacyNames.length; i++) {
        const name: string = legacyNames[i];
        if (!name.endsWith('.mp4')) { continue; }
        let stat: fileIo.Stat;
        try { stat = await fileIo.stat(parent + '/' + name); } catch (error) { continue; }
        total += stat.size;
        if (!this.completedProtected(name)) {
          candidates.push(new RangeCacheFile(name, stat.size, this.completedAccess(name, stat.mtime * 1000), true));
        }
      }
      for (let i: number = 0; i < names.length; i++) {
        const name: string = names[i];
        let stat: fileIo.Stat;
        try { stat = await fileIo.stat(directory + '/' + name); } catch (error) { continue; }
        total += stat.size;
        const session: VideoRangeSession | null = this.sessionForFile(name);
        if ((name.endsWith('.chunk') || name.endsWith('.head')) && (session === null || !session.pinned(name))) {
          candidates.push(new RangeCacheFile(name, stat.size, session === null ? stat.mtime * 1000 :
            session.accessTime(name, stat.mtime * 1000)));
        }
      }
      if (this.directory !== directory) { return; }
      candidates.sort((a: RangeCacheFile, b: RangeCacheFile): number => a.accessMs - b.accessMs);
      for (let i: number = 0; i < candidates.length; i++) {
        if (total <= MAX_BYTES) { break; }
        const candidate: RangeCacheFile = candidates[i];
        if (candidate.completed) {
          if (this.completedProtected(candidate.name)) { continue; }
          this.completedRemove(candidate.name);
        } else {
          // A read can pin this file while async enumeration is in flight.
          const session: VideoRangeSession | null = this.sessionForFile(candidate.name);
          if (session !== null && session.pinned(candidate.name)) { continue; }
          this.removeFile(candidate.name);
        }
        total -= candidates[i].bytes;
      }
      for (let i: number = 0; i < names.length; i++) {
        const name: string = names[i];
        if (!name.endsWith('.meta') || this.isActiveFile(name)) { continue; }
        let lastAccess: number = 0;
        try { lastAccess = (JSON.parse(await fileIo.readText(directory + '/' + name)) as RangeMetadata).lastAccessMs; }
        catch (error) {}
        if (this.directory !== directory) { return; }
        if (this.isActiveFile(name) || Date.now() - lastAccess <= MAX_AGE_MS) { continue; }
        const key: string = name.substring(0, name.length - 5);
        this.removeKey(key);
      }
      // A crash can leave a chunk written before its metadata. It is never
      // trusted and is reclaimed once no matching active session exists.
      for (let i: number = 0; i < names.length; i++) {
        const name: string = names[i];
        if ((name.endsWith('.chunk') || name.endsWith('.head')) && !this.isActiveFile(name)) {
          const key: string = name.substring(0, name.lastIndexOf('-'));
          const hasMetadata: boolean = await fileIo.access(directory + '/' + key + '.meta');
          if (this.directory !== directory) { return; }
          if (!hasMetadata && !this.isActiveFile(name)) { this.removeFile(name); }
        }
      }
    } catch (error) { hilog.debug(DOMAIN, TAG, 'range cache trim deferred'); }
  }

  private removeKey(key: string): number {
    let bytes: number = 0;
    const names: string[] = fileIo.listFileSync(this.directory);
    for (let i: number = 0; i < names.length; i++) {
      if (names[i] === key + '.meta' || names[i].startsWith(key + '-')) {
        try { bytes += fileIo.statSync(this.directory + '/' + names[i]).size; } catch (error) {}
        this.removeFile(names[i]);
      }
    }
    return bytes;
  }
  private removeFile(name: string): void {
    if (name.includes('/') || name.includes('\\')) { return; }
    try { fileIo.unlinkSync(this.directory + '/' + name); } catch (error) {}
  }
}

export const videoRangeSource: VideoRangeSourceStore = new VideoRangeSourceStore();
