// Private, bounded playback cache for progressive video files.
//
// AVPlayer owns the descriptor it is given, so callers acquire a lease and
// keep it open until the player has been released.  Network URLs never enter
// the manifest: X refreshes their query tokens, while a completed local MP4
// remains valid for the media/rendition that produced it.
import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { videoRangeSource, VideoRangeLease } from './VideoRangeSource';
import hilog from '@ohos.hilog';
import { proxyDownloadService } from './ProxyDownloadService';

const DOMAIN: number = 0xFF00;
const TAG: string = 'HarmonyX-VideoCache';
const DIRECTORY: string = 'video-playback-cache';
const INDEX_FILE: string = 'index.txt';
const MAX_ENTRIES: number = 8;
const MAX_BYTES: number = 200 * 1024 * 1024;
const MAX_AGE_MS: number = 7 * 24 * 60 * 60 * 1000;

export type VideoCacheLeaseClosedCallback = (key: string) => void;
export type VideoCacheDownloadCallback = (success: boolean) => void;

// Ownership follows the AVPlayer through handoff/reset/release.
export class VideoDataSourceLease {
  key: string;
  url: string;
  private lease: VideoRangeLease;
  constructor(key: string, lease: VideoRangeLease) {
    this.key = key; this.url = lease.url; this.lease = lease;
  }
  setForeground(foreground: boolean): void { this.lease.setForeground(foreground); }
  copyCompleteTo(path: string): Promise<boolean> { return this.lease.copyCompleteTo(path); }
  close(): void { this.lease.close(); }
}

export class VideoCacheLease {
  key: string = '';
  fd: number = -1;
  length: number = 0;
  private onClosed: VideoCacheLeaseClosedCallback;

  constructor(key: string, fd: number, length: number, onClosed: VideoCacheLeaseClosedCallback) {
    this.key = key;
    this.fd = fd;
    this.length = length;
    this.onClosed = onClosed;
  }

  close(): void {
    if (this.fd < 0) {
      return;
    }
    const releasedKey: string = this.key;
    const releasedFd: number = this.fd;
    this.fd = -1;
    try {
      fileIo.closeSync(releasedFd);
    } catch (error) {
      hilog.debug(DOMAIN, TAG, 'cache fd already closed key=%{public}s', releasedKey);
    }
    this.onClosed(releasedKey);
  }
}

class VideoCacheRecord {
  key: string = '';
  fileName: string = '';
  bytes: number = 0;
  lastAccessMs: number = 0;

  constructor(key: string, fileName: string, bytes: number, lastAccessMs: number) {
    this.key = key;
    this.fileName = fileName;
    this.bytes = bytes;
    this.lastAccessMs = lastAccessMs;
  }
}

class VideoWarmRequest {
  context: common.UIAbilityContext;
  mediaId: string = '';
  rendition: string = '';
  remoteUrl: string = '';
  onComplete: VideoCacheDownloadCallback | undefined = undefined;

  constructor(context: common.UIAbilityContext, mediaId: string, rendition: string, remoteUrl: string,
    onComplete: VideoCacheDownloadCallback | undefined = undefined) {
    this.context = context;
    this.mediaId = mediaId;
    this.rendition = rendition;
    this.remoteUrl = remoteUrl;
    this.onComplete = onComplete;
  }
}

class VideoPlaybackCache {
  private directory: string = '';
  private loaded: boolean = false;
  private records: VideoCacheRecord[] = [];
  private leasedKeys: string[] = [];
  private retiredKeys: string[] = [];
  private activeKey: string = '';
  private clearGeneration: number = 0;
  private queuedRequest: VideoWarmRequest | null = null;
  private activeCallbacks: VideoCacheDownloadCallback[] = [];
  private promotions: Map<string, Promise<boolean>> = new Map<string, Promise<boolean>>();

  // HLS is a playlist and cannot be made reusable by downloading one file.
  // Only an actual progressive MP4 is eligible for the private file cache.
  canCache(remoteUrl: string): boolean {
    if (remoteUrl.length === 0) {
      return false;
    }
    const queryIndex: number = remoteUrl.indexOf('?');
    const path: string = queryIndex >= 0 ? remoteUrl.substring(0, queryIndex) : remoteUrl;
    return path.toLowerCase().endsWith('.mp4');
  }

  acquire(context: common.UIAbilityContext, mediaId: string, rendition: string,
    remoteUrl: string): VideoCacheLease | null {
    if (!this.canCache(remoteUrl) || mediaId.length === 0) {
      return null;
    }
    this.ensureLoaded(context);
    const key: string = this.cacheKey(mediaId, rendition);
    const record: VideoCacheRecord | null = this.findRecord(key);
    if (record === null || this.isRetired(key)) {
      return null;
    }
    const path: string = this.filePath(record.fileName);
    try {
      if (!fileIo.accessSync(path)) {
        this.removeRecord(key, false);
        return null;
      }
      const stat = fileIo.statSync(path);
      if (!stat.isFile() || stat.size <= 0 || stat.size !== record.bytes) {
        this.removeRecord(key, true);
        return null;
      }
      const file: fileIo.File = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
      record.lastAccessMs = Date.now();
      this.leasedKeys.push(key);
      this.writeIndex();
      hilog.info(DOMAIN, TAG, 'cache hit key=%{public}s bytes=%{public}d', key, record.bytes);
      return new VideoCacheLease(key, file.fd, record.bytes,
        (closedKey: string): void => {
          this.releaseLease(closedKey);
        });
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'cache open failed key=%{public}s', key);
      this.removeRecord(key, true);
      return null;
    }
  }

  warm(context: common.UIAbilityContext, mediaId: string, rendition: string, remoteUrl: string): void {
    if (!this.canCache(remoteUrl) || mediaId.length === 0) {
      return;
    }
    this.ensureLoaded(context);
    const key: string = this.cacheKey(mediaId, rendition);
    if (this.findRecord(key) !== null || this.activeKey === key || this.promotions.has(key)) {
      return;
    }
    this.enqueueWarm(context, mediaId, rendition, remoteUrl, undefined);
  }

  // Fetch a progressive video before it reaches AVPlayer.  @ohos.net.http is
  // the layer that understands the app proxy, while AVPlayer only accepts a
  // URL or a local descriptor and otherwise bypasses that setting entirely.
  prepare(context: common.UIAbilityContext, mediaId: string, rendition: string,
    remoteUrl: string): Promise<boolean> {
    if (!this.canCache(remoteUrl) || mediaId.length === 0) {
      return Promise.resolve(false);
    }
    this.ensureLoaded(context);
    const key: string = this.cacheKey(mediaId, rendition);
    if (this.findRecord(key) !== null && !this.isRetired(key)) {
      return Promise.resolve(true);
    }
    const promotion: Promise<boolean> | undefined = this.promotions.get(key);
    if (promotion !== undefined) {
      return promotion.then((ready: boolean): Promise<boolean> => ready ? Promise.resolve(true) :
        this.prepare(context, mediaId, rendition, remoteUrl));
    }
    return new Promise<boolean>((resolve: (value: boolean) => void): void => {
      this.enqueueWarm(context, mediaId, rendition, remoteUrl, resolve);
    });
  }

  promoteDataSource(context: common.UIAbilityContext, mediaId: string, rendition: string,
    source: VideoDataSourceLease): Promise<boolean> {
    this.ensureLoaded(context);
    const key: string = this.cacheKey(mediaId, rendition);
    if (this.findRecord(key) !== null && !this.isRetired(key)) { return Promise.resolve(true); }
    if (this.activeKey === key || this.isRetired(key)) { return Promise.resolve(false); }
    const existing: Promise<boolean> | undefined = this.promotions.get(key);
    if (existing !== undefined) { return existing; }
    const generation: number = this.clearGeneration;
    const path: string = this.filePath(this.fileNameFor(key));
    const temporary: string = path + '.range-tmp';
    const operation: Promise<boolean> = source.copyCompleteTo(temporary).then((complete: boolean): boolean => {
      if (!complete || generation !== this.clearGeneration || this.activeKey === key || this.isRetired(key)) {
        return false;
      }
      fileIo.renameSync(temporary, path);
      const bytes: number = fileIo.statSync(path).size;
      this.removeRecord(key, false);
      this.records.push(new VideoCacheRecord(key, this.fileNameFor(key), bytes, Date.now()));
      this.trim();
      hilog.info(DOMAIN, TAG, 'recovered complete ranges key=%{public}s bytes=%{public}d', key, bytes);
      return true;
    }).catch((): boolean => false).finally((): void => {
      this.removeFile(temporary);
      this.promotions.delete(key);
    });
    this.promotions.set(key, operation);
    return operation;
  }

  async openDataSource(context: common.UIAbilityContext, mediaId: string, rendition: string,
    remoteUrl: string, foreground: boolean = true): Promise<VideoDataSourceLease | null> {
    if (!this.canCache(remoteUrl) || mediaId.length === 0) { return null; }
    this.ensureLoaded(context);
    const lease: VideoRangeLease | null = await videoRangeSource.open(context, mediaId, rendition, remoteUrl, foreground);
    return lease === null ? null : new VideoDataSourceLease(this.cacheKey(mediaId, rendition), lease);
  }

  invalidate(context: common.UIAbilityContext, mediaId: string, rendition: string): void {
    if (mediaId.length === 0) {
      return;
    }
    this.ensureLoaded(context);
    const key: string = this.cacheKey(mediaId, rendition);
    const record: VideoCacheRecord | null = this.findRecord(key);
    const path: string = record === null ? this.filePath(this.fileNameFor(key)) : this.filePath(record.fileName);
    this.removeRecord(key, false);
    if (this.isLeased(key)) {
      if (!this.isRetired(key)) {
        this.retiredKeys.push(key);
      }
      return;
    }
    this.removeFile(path);
  }

  getCacheSize(context: common.UIAbilityContext): number {
    this.ensureLoaded(context);
    return this.totalBytes() + videoRangeSource.size(context);
  }

  clear(context: common.UIAbilityContext): number {
    this.ensureLoaded(context);
    videoRangeSource.clear(context);
    this.clearGeneration = this.clearGeneration + 1;
    let removedBytes: number = 0;
    for (let index: number = this.records.length - 1; index >= 0; index--) {
      const record: VideoCacheRecord = this.records[index];
      removedBytes = removedBytes + record.bytes;
      if (this.isLeased(record.key)) {
        if (!this.isRetired(record.key)) {
          this.retiredKeys.push(record.key);
        }
      } else {
        this.removeFile(this.filePath(record.fileName));
      }
      this.records.splice(index, 1);
    }
    const queued: VideoWarmRequest | null = this.queuedRequest;
    this.queuedRequest = null;
    if (queued !== null && queued.onComplete !== undefined) {
      queued.onComplete(false);
    }
    if (this.activeKey.length > 0) {
      this.removeFile(this.filePath(this.fileNameFor(this.activeKey)));
    }
    this.writeIndex();
    return removedBytes;
  }

  private enqueueWarm(context: common.UIAbilityContext, mediaId: string, rendition: string,
    remoteUrl: string, onComplete: VideoCacheDownloadCallback | undefined): void {
    const key: string = this.cacheKey(mediaId, rendition);
    if (this.activeKey === key) {
      if (onComplete !== undefined) {
        this.activeCallbacks.push(onComplete);
      }
      return;
    }
    if (this.activeKey.length > 0) {
      // Keep only the most recent background request. A foreground playback
      // request always receives a callback instead of being silently lost.
      const queued: VideoWarmRequest | null = this.queuedRequest;
      if (queued !== null && queued.onComplete !== undefined && onComplete === undefined) {
        return;
      }
      if (queued !== null && queued.onComplete !== undefined) {
        queued.onComplete(false);
      }
      this.queuedRequest = new VideoWarmRequest(context, mediaId, rendition, remoteUrl, onComplete);
      return;
    }
    this.startWarm(context, key, remoteUrl, onComplete);
  }

  private startWarm(context: common.UIAbilityContext, key: string, remoteUrl: string,
    onComplete: VideoCacheDownloadCallback | undefined): void {
    const path: string = this.filePath(this.fileNameFor(key));
    this.removeFile(path);
    this.activeKey = key;
    if (onComplete !== undefined) {
      this.activeCallbacks.push(onComplete);
    }
    const clearGeneration: number = this.clearGeneration;
    proxyDownloadService.downloadWithRetry(remoteUrl, path, 3).then((ok: boolean): void => {
      if (clearGeneration !== this.clearGeneration) {
        this.removeFile(path);
        this.finishActive(false);
        this.startQueuedRequest();
        return;
      }
      if (ok) {
      this.completeWarm(key, path);
        return;
      }
      hilog.debug(DOMAIN, TAG, 'cache download failed key=%{public}s', key);
      this.failWarm(key, path);
    });
  }

  private completeWarm(key: string, path: string): void {
    let success: boolean = false;
    try {
      const stat = fileIo.statSync(path);
      if (!stat.isFile() || stat.size <= 0) {
        this.removeFile(path);
      } else {
        const record: VideoCacheRecord = new VideoCacheRecord(key, this.fileNameFor(key),
          stat.size, Date.now());
        this.removeRecord(key, false);
        this.records.push(record);
        this.trim();
        success = true;
        hilog.info(DOMAIN, TAG, 'cache ready key=%{public}s bytes=%{public}d', key, stat.size);
      }
    } catch (error) {
      this.removeFile(path);
      hilog.debug(DOMAIN, TAG, 'cache completion check failed key=%{public}s', key);
    }
    this.finishActive(success);
    this.startQueuedRequest();
  }

  private failWarm(key: string, path: string): void {
    this.finishActive(false);
    this.removeFile(path);
    this.startQueuedRequest();
  }

  private startQueuedRequest(): void {
    const next: VideoWarmRequest | null = this.queuedRequest;
    this.queuedRequest = null;
    if (next === null) {
      return;
    }
    this.startWarm(next.context, this.cacheKey(next.mediaId, next.rendition), next.remoteUrl,
      next.onComplete);
  }

  private finishActive(success: boolean): void {
    this.activeKey = '';
    const callbacks: VideoCacheDownloadCallback[] = this.activeCallbacks;
    this.activeCallbacks = [];
    for (let index: number = 0; index < callbacks.length; index++) {
      callbacks[index](success);
    }
  }

  private ensureLoaded(context: common.UIAbilityContext): void {
    const nextDirectory: string = context.cacheDir + '/' + DIRECTORY;
    if (this.loaded && this.directory === nextDirectory) {
      return;
    }
    this.loaded = true;
    this.directory = nextDirectory;
    this.records = [];
    this.leasedKeys = [];
    this.retiredKeys = [];
    videoRangeSource.setCompletedCachePolicy(
      (name: string): boolean => {
        if (this.activeKey.length > 0 && name === this.fileNameFor(this.activeKey)) { return true; }
        for (const key of this.promotions.keys()) { if (name === this.fileNameFor(key)) { return true; } }
        return this.leasedKeys.some((key: string): boolean => this.fileNameFor(key) === name);
      }, (name: string, fallback: number): number => {
        const record: VideoCacheRecord | undefined = this.records.find((item: VideoCacheRecord): boolean => item.fileName === name);
        return record === undefined ? fallback : record.lastAccessMs;
      }, (name: string): void => {
        const record: VideoCacheRecord | undefined = this.records.find((item: VideoCacheRecord): boolean => item.fileName === name);
        if (record !== undefined) { this.removeRecord(record.key, true); }
        else { this.removeFile(this.filePath(name)); }
      });
    this.ensureDirectory();
    const indexPath: string = this.directory + '/' + INDEX_FILE;
    try {
      if (!fileIo.accessSync(indexPath)) {
        return;
      }
      const content: string = fileIo.readTextSync(indexPath);
      const lines: string[] = content.split('\n');
      for (let index: number = 0; index < lines.length; index++) {
        const line: string = lines[index];
        if (line.length === 0) {
          continue;
        }
        const fields: string[] = line.split('\t');
        if (fields.length !== 4) {
          continue;
        }
        const key: string = fields[0];
        const fileName: string = fields[1];
        const bytes: number = Number(fields[2]);
        const lastAccessMs: number = Number(fields[3]);
        if (key.length === 0 || fileName.indexOf('/') >= 0 || fileName.indexOf('\\') >= 0 ||
          bytes <= 0 || lastAccessMs <= 0 || this.findRecord(key) !== null) {
          continue;
        }
        const path: string = this.filePath(fileName);
        try {
          const stat = fileIo.statSync(path);
          if (stat.isFile() && stat.size === bytes && stat.size > 0) {
            this.records.push(new VideoCacheRecord(key, fileName, bytes, lastAccessMs));
          }
        } catch (error) {
          // A cache directory may be cleared by the system between launches.
        }
      }
    } catch (error) {
      hilog.debug(DOMAIN, TAG, 'cache index read failed');
    }
    this.trim();
  }

  private trim(): void {
    const now: number = Date.now();
    for (let index: number = this.records.length - 1; index >= 0; index--) {
      const record: VideoCacheRecord = this.records[index];
      if (!this.isLeased(record.key) && now - record.lastAccessMs > MAX_AGE_MS) {
        this.removeFile(this.filePath(record.fileName));
        this.records.splice(index, 1);
      }
    }
    while (this.records.length > MAX_ENTRIES ||
      (this.totalBytes() > MAX_BYTES && this.records.length > 1)) {
      const oldest: number = this.oldestUnleasedRecord();
      if (oldest < 0) {
        break;
      }
      const record: VideoCacheRecord = this.records[oldest];
      this.removeFile(this.filePath(record.fileName));
      this.records.splice(oldest, 1);
    }
    this.writeIndex();
    videoRangeSource.trimToBudget();
  }

  private oldestUnleasedRecord(): number {
    let result: number = -1;
    let oldestAccess: number = 9000000000000000000;
    for (let index: number = 0; index < this.records.length; index++) {
      const record: VideoCacheRecord = this.records[index];
      if (this.isLeased(record.key) || record.key === this.activeKey) {
        continue;
      }
      if (record.lastAccessMs < oldestAccess) {
        oldestAccess = record.lastAccessMs;
        result = index;
      }
    }
    return result;
  }

  private totalBytes(): number {
    let total: number = 0;
    for (let index: number = 0; index < this.records.length; index++) {
      total = total + this.records[index].bytes;
    }
    return total;
  }

  private findRecord(key: string): VideoCacheRecord | null {
    for (let index: number = 0; index < this.records.length; index++) {
      if (this.records[index].key === key) {
        return this.records[index];
      }
    }
    return null;
  }

  private removeRecord(key: string, removeFile: boolean): void {
    for (let index: number = this.records.length - 1; index >= 0; index--) {
      const record: VideoCacheRecord = this.records[index];
      if (record.key !== key) {
        continue;
      }
      if (removeFile && !this.isLeased(key)) {
        this.removeFile(this.filePath(record.fileName));
      }
      this.records.splice(index, 1);
    }
    this.writeIndex();
  }

  private releaseLease(key: string): void {
    const index: number = this.leasedKeys.indexOf(key);
    if (index >= 0) {
      this.leasedKeys.splice(index, 1);
    }
    if (!this.isLeased(key) && this.isRetired(key)) {
      const retiredIndex: number = this.retiredKeys.indexOf(key);
      if (retiredIndex >= 0) {
        this.retiredKeys.splice(retiredIndex, 1);
      }
      this.removeFile(this.filePath(this.fileNameFor(key)));
    }
    this.trim();
  }

  private isLeased(key: string): boolean {
    return this.leasedKeys.indexOf(key) >= 0;
  }

  private isRetired(key: string): boolean {
    return this.retiredKeys.indexOf(key) >= 0;
  }

  private cacheKey(mediaId: string, rendition: string): string {
    const value: string = mediaId + ':' + rendition;
    let hash: number = 0x811c9dc5;
    for (let index: number = 0; index < value.length; index++) {
      hash = hash ^ value.charCodeAt(index);
      hash = (hash * 0x01000193) >>> 0;
    }
    return hash.toString(16) + '-' + value.length.toString() + '-' + rendition;
  }

  private fileNameFor(key: string): string {
    return key + '.mp4';
  }

  private filePath(fileName: string): string {
    return this.directory + '/' + fileName;
  }

  private ensureDirectory(): void {
    try {
      if (!fileIo.accessSync(this.directory)) {
        fileIo.mkdirSync(this.directory, true);
      }
    } catch (error) {
      hilog.debug(DOMAIN, TAG, 'cache directory unavailable');
    }
  }

  private writeIndex(): void {
    if (this.directory.length === 0) {
      return;
    }
    let file: fileIo.File | undefined = undefined;
    try {
      this.ensureDirectory();
      let content: string = '';
      for (let index: number = 0; index < this.records.length; index++) {
        const record: VideoCacheRecord = this.records[index];
        content = content + record.key + '\t' + record.fileName + '\t' +
          record.bytes.toString() + '\t' + record.lastAccessMs.toString() + '\n';
      }
      file = fileIo.openSync(this.directory + '/' + INDEX_FILE,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(file.fd, content);
    } catch (error) {
      hilog.debug(DOMAIN, TAG, 'cache index write failed');
    } finally {
      if (file !== undefined) {
        try {
          fileIo.closeSync(file.fd);
        } catch (error) {
          // The descriptor may already be closed after a filesystem failure.
        }
      }
    }
  }

  private removeFile(path: string): void {
    try {
      if (fileIo.accessSync(path)) {
        fileIo.unlinkSync(path);
      }
    } catch (error) {
      // A cache miss and a system cache eviction are both harmless here.
    }
  }
}

export const videoPlaybackCache: VideoPlaybackCache = new VideoPlaybackCache();
