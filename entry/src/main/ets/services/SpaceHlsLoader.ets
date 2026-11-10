import { DohHttpRequest, createDohHttpRequest } from './DohHttpRequest';
import http from '@ohos.net.http';
import hilog from '@ohos.hilog';
import { media } from '@kit.MediaKit';
import { proxyStore } from './ProxyStore';

class SpaceResource {
  request: media.MediaSourceLoadingRequest;
  httpRequest: DohHttpRequest | null = null;
  bytes: ArrayBuffer | null = null;
  baseOffset: number = 0;
  offset: number = 0;
  end: number = -1;
  reading: boolean = false;
  finished: boolean = false;
  constructor(request: media.MediaSourceLoadingRequest) { this.request = request; }
}

// The native loader routes manifests AND audio chunks through the same proxy
// as the API. Each handle owns one small HLS resource, never the whole stream.
export class SpaceHlsLoader {
  private resources: Map<number, SpaceResource> = new Map<number, SpaceResource>();
  private sequence: number = 0;
  private disposed: boolean = false;

  delegate(): media.MediaSourceLoader {
    return {
      open: (request: media.MediaSourceLoadingRequest): number => this.open(request),
      read: (id: number, offset: number, length: number): void => this.read(id, offset, length),
      close: (id: number): void => this.close(id)
    };
  }
  dispose(): void {
    this.disposed = true;
    this.resources.forEach((_entry: SpaceResource, id: number): void => this.close(id));
  }
  private open(request: media.MediaSourceLoadingRequest): number {
    if (this.disposed || !/^https:\/\//i.test(request.url)) { return -1; }
    const id: number = ++this.sequence;
    const entry: SpaceResource = new SpaceResource(request);
    this.resources.set(id, entry);
    this.fetch(id, entry);
    return id;
  }
  private read(id: number, offset: number, length: number): void {
    const entry: SpaceResource | undefined = this.resources.get(id);
    if (entry === undefined || entry.finished) { return; }
    entry.offset = Math.max(0, offset);
    entry.end = length < 0 ? -1 : entry.offset + length;
    entry.reading = true;
    // Native callbacks must return before respondHeader/respondData is called.
    setTimeout((): void => this.drain(id, entry), 0);
  }
  private async fetch(id: number, entry: SpaceResource): Promise<void> {
    const request: DohHttpRequest = createDohHttpRequest();
    entry.httpRequest = request;
    try {
      const options: http.HttpRequestOptions = {
        method: http.RequestMethod.GET,
        header: entry.request.header ?? { 'User-Agent': 'HarmonyX', 'Accept-Encoding': 'identity' },
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        usingCache: false,
        maxLimit: 16 * 1024 * 1024,
        connectTimeout: 15000,
        readTimeout: 20000
      };
      await proxyStore.apply(options);
      if (this.resources.get(id) !== entry) { return; }
      const response: http.HttpResponse = await request.request(entry.request.url, options);
      if (this.resources.get(id) !== entry) { return; }
      if ((response.responseCode !== 200 && response.responseCode !== 206) || !(response.result instanceof ArrayBuffer)) {
        hilog.warn(0xFF00, 'HarmonyX-Spaces', 'media resource HTTP status: %{public}d', response.responseCode);
        entry.request.finishLoading(id, media.LoadingRequestError.LOADING_ERROR_NO_RESOURCE); return;
      }
      entry.bytes = response.result as ArrayBuffer;
      const responseHeaders: Record<string, string> = response.header as Record<string, string>;
      const range: string = responseHeaders?.['content-range'] ?? responseHeaders?.['Content-Range'] ?? '';
      const rangeParts: RegExpMatchArray | null = range.match(/^bytes (\d+)-(\d+)\/(\d+|\*)$/);
      if (response.responseCode === 206 && rangeParts === null) {
        entry.request.finishLoading(id, media.LoadingRequestError.LOADING_ERROR_NO_RESOURCE); return;
      }
      entry.baseOffset = rangeParts === null ? 0 : Number(rangeParts[1]);
      const header: Record<string, string> = {
        'content-length': entry.bytes.byteLength.toString(),
        'Content-Type': responseHeaders?.['content-type'] ?? responseHeaders?.['Content-Type'] ??
          (/\.m3u8(?:\?|$)/i.test(entry.request.url) ? 'application/vnd.apple.mpegurl' : 'application/octet-stream'),
        'Accept-Ranges': 'bytes'
      };
      if (range.length > 0) { header['Content-Range'] = range; }
      entry.request.respondHeader(id, header);
      this.drain(id, entry);
    } catch (error) {
      if (this.resources.get(id) === entry) {
        hilog.warn(0xFF00, 'HarmonyX-Spaces', 'media resource request failed');
        entry.request.finishLoading(id, media.LoadingRequestError.LOADING_ERROR_ACCESS_TIMEOUT);
      }
    } finally { request.destroy(); entry.httpRequest = null; }
  }
  private drain(id: number, entry: SpaceResource): void {
    const bytes: ArrayBuffer | null = entry.bytes;
    if (this.resources.get(id) !== entry || bytes === null || !entry.reading || entry.finished) { return; }
    const resourceEnd: number = entry.baseOffset + bytes.byteLength;
    if (entry.offset < entry.baseOffset) {
      entry.finished = true;
      entry.request.finishLoading(id, media.LoadingRequestError.LOADING_ERROR_NO_RESOURCE); return;
    }
    const end: number = entry.end < 0 ? resourceEnd : Math.min(resourceEnd, entry.end);
    while (entry.offset < end) {
      const chunk: ArrayBuffer = bytes.slice(entry.offset - entry.baseOffset,
        Math.min(end, entry.offset + 65536) - entry.baseOffset);
      const accepted: number = entry.request.respondData(id, entry.offset, chunk);
      if (accepted <= 0) { entry.reading = false; return; }
      entry.offset += accepted;
    }
    entry.reading = false;
    if (entry.offset >= resourceEnd) {
      entry.finished = true;
      entry.request.finishLoading(id, media.LoadingRequestError.LOADING_ERROR_SUCCESS);
    }
  }
  private close(id: number): void {
    const entry: SpaceResource | undefined = this.resources.get(id);
    this.resources.delete(id);
    if (entry?.httpRequest !== null && entry?.httpRequest !== undefined) { entry.httpRequest.destroy(); }
  }
}
