// Fetches images through the configured proxy and decodes them in memory.
// PixelMaps are shared by URL while callers hold leases, then kept in a small
// LRU cache so opening an already visible image does not decode it again.
import { image } from '@kit.ImageKit';
import { fileIo } from '@kit.CoreFileKit';
import http from '@ohos.net.http';
import hilog from '@ohos.hilog';
import { proxyStore } from './ProxyStore';

const DOMAIN: number = 0xFF00;
const TAG: string = 'HarmonyX-ProxyImage';
const CONNECT_TIMEOUT_MS: number = 20000;
const READ_TIMEOUT_MS: number = 60000;
const MAX_CACHE_BYTES: number = 25165824;
const MAX_CACHE_ITEMS: number = 12;
const MAX_PIXEL_CACHE_BYTES: number = 50331648;
const MAX_PIXEL_CACHE_ITEMS: number = 8;

class ProxyImageCacheEntry {
  url: string = '';
  bytes: ArrayBuffer | null = null;
  pixelMap: image.PixelMap | null = null;
  pixelBytes: number = 0;
  referenceCount: number = 0;
  cachedPixelMap: boolean = false;
  lastUsed: number = 0;

  constructor(url: string) {
    this.url = url;
  }
}

class ProxyImagePendingRequest {
  url: string = '';
  promise: Promise<image.PixelMap | null>;

  constructor(url: string, promise: Promise<image.PixelMap | null>) {
    this.url = url;
    this.promise = promise;
  }
}

class ProxyImageResolver {
  private entries: ProxyImageCacheEntry[] = [];
  private pending: ProxyImagePendingRequest[] = [];
  private pendingBytes: Map<string, Promise<ArrayBuffer | null>> = new Map();
  private cacheBytes: number = 0;
  private cacheItems: number = 0;
  private cachedPixelBytes: number = 0;
  private cachedPixelItems: number = 0;
  private useSerial: number = 0;

  // Every non-null result is a lease; callers must balance it with release().
  async load(url: string, allowDirect: boolean = false): Promise<image.PixelMap | null> {
    // Private media is decoded on demand and never enters the shared HTTP cache.
    if (url.startsWith('file://')) { return this.loadLocal(url); }
    if (url.length === 0 || (!proxyStore.snapshot().enabled && !allowDirect)) {
      return null;
    }
    let entry: ProxyImageCacheEntry | null = this.findEntry(url);
    if (entry !== null && entry.pixelMap !== null) {
      this.acquire(entry);
      return entry.pixelMap;
    }
    let request: ProxyImagePendingRequest | null = this.findPending(url);
    if (request === null) {
      request = new ProxyImagePendingRequest(url, this.loadAndDecode(url));
      this.pending.push(request);
    }
    const pixelMap: image.PixelMap | null = await request.promise;
    this.removePending(request);
    if (pixelMap === null) {
      return null;
    }
    entry = this.findEntry(url);
    if (entry === null) {
      entry = this.createEntry(url);
    }
    if (entry.pixelMap === null) {
      entry.pixelMap = pixelMap;
      entry.pixelBytes = this.pixelByteCount(pixelMap);
      entry.lastUsed = this.nextUseSerial();
    }
    if (entry.pixelMap !== pixelMap) {
      this.releaseUncached(pixelMap);
    }
    this.acquire(entry);
    return entry.pixelMap;
  }

  // Viewer images outlive navigation transitions. Keep their native maps
  // independent while still sharing downloads and the compressed-byte cache.
  async loadForViewer(url: string, allowDirect: boolean = false): Promise<image.PixelMap | null> {
    if (url.startsWith('file://')) { return this.loadLocal(url); }
    if (url.length === 0 || (!proxyStore.snapshot().enabled && !allowDirect)) {
      return null;
    }
    const bytes: ArrayBuffer | null = await this.loadBytes(url);
    return bytes === null ? null : await this.decode(bytes);
  }

  private async loadLocal(url: string): Promise<image.PixelMap | null> {
    let file: fileIo.File | null = null;
    let source: image.ImageSource | null = null;
    try {
      file = fileIo.openSync(url, fileIo.OpenMode.READ_ONLY);
      source = image.createImageSource(file.fd);
      return await source.createPixelMap();
    } catch (error) { return null; }
    finally {
      try { if (source !== null) { await source.release().catch((): void => {}); } }
      finally { if (file !== null) { fileIo.closeSync(file.fd); } }
    }
  }

  release(pixelMap: image.PixelMap): void {
    for (let i: number = 0; i < this.entries.length; i++) {
      const entry: ProxyImageCacheEntry = this.entries[i];
      if (entry.pixelMap !== pixelMap) {
        continue;
      }
      if (entry.referenceCount <= 0) {
        return;
      }
      entry.referenceCount -= 1;
      entry.lastUsed = this.nextUseSerial();
      if (entry.referenceCount > 0) {
        return;
      }
      if (entry.pixelBytes > 0 && entry.pixelBytes <= MAX_PIXEL_CACHE_BYTES) {
        entry.cachedPixelMap = true;
        this.cachedPixelBytes += entry.pixelBytes;
        this.cachedPixelItems += 1;
        this.trimPixelCache();
      } else {
        this.disposePixelMap(entry);
      }
      this.removeEmptyEntry(entry);
      return;
    }
    this.releaseUncached(pixelMap);
  }

  private async loadAndDecode(url: string): Promise<image.PixelMap | null> {
    const bytes: ArrayBuffer | null = await this.loadBytes(url);
    if (bytes === null) {
      return null;
    }
    const pixelMap: image.PixelMap | null = await this.decode(bytes);
    if (pixelMap === null) {
      return null;
    }
    let entry: ProxyImageCacheEntry | null = this.findEntry(url);
    if (entry === null) {
      entry = this.createEntry(url);
    }
    entry.pixelMap = pixelMap;
    entry.pixelBytes = this.pixelByteCount(pixelMap);
    entry.lastUsed = this.nextUseSerial();
    return pixelMap;
  }

  private async loadBytes(url: string): Promise<ArrayBuffer | null> {
    const entry: ProxyImageCacheEntry | null = this.findEntry(url);
    if (entry !== null && entry.bytes !== null) {
      entry.lastUsed = this.nextUseSerial();
      return entry.bytes;
    }
    const active: Promise<ArrayBuffer | null> | undefined = this.pendingBytes.get(url);
    if (active !== undefined) { return await active; }
    const request: Promise<ArrayBuffer | null> = this.fetchBytes(url)
      .then((bytes: ArrayBuffer | null): ArrayBuffer | null => {
        if (bytes !== null) { this.storeBytes(url, bytes); }
        return bytes;
      }).finally((): void => { this.pendingBytes.delete(url); });
    this.pendingBytes.set(url, request);
    return await request;
  }

  private findEntry(url: string): ProxyImageCacheEntry | null {
    for (let i: number = 0; i < this.entries.length; i++) {
      if (this.entries[i].url === url) {
        return this.entries[i];
      }
    }
    return null;
  }

  private createEntry(url: string): ProxyImageCacheEntry {
    const entry: ProxyImageCacheEntry = new ProxyImageCacheEntry(url);
    entry.lastUsed = this.nextUseSerial();
    this.entries.push(entry);
    return entry;
  }

  private findPending(url: string): ProxyImagePendingRequest | null {
    for (let i: number = 0; i < this.pending.length; i++) {
      if (this.pending[i].url === url) {
        return this.pending[i];
      }
    }
    return null;
  }

  private removePending(target: ProxyImagePendingRequest): void {
    for (let i: number = 0; i < this.pending.length; i++) {
      if (this.pending[i] === target) {
        this.pending.splice(i, 1);
        return;
      }
    }
  }

  private acquire(entry: ProxyImageCacheEntry): void {
    if (entry.cachedPixelMap) {
      entry.cachedPixelMap = false;
      this.cachedPixelBytes -= entry.pixelBytes;
      this.cachedPixelItems -= 1;
    }
    entry.referenceCount += 1;
    entry.lastUsed = this.nextUseSerial();
  }

  private storeBytes(url: string, bytes: ArrayBuffer): void {
    let entry: ProxyImageCacheEntry | null = this.findEntry(url);
    if (entry === null) {
      entry = this.createEntry(url);
    }
    if (entry.bytes !== null) {
      this.cacheBytes -= entry.bytes.byteLength;
      this.cacheItems -= 1;
      entry.bytes = null;
    }
    if (bytes.byteLength > MAX_CACHE_BYTES) {
      this.removeEmptyEntry(entry);
      return;
    }
    entry.bytes = bytes;
    entry.lastUsed = this.nextUseSerial();
    this.cacheBytes += bytes.byteLength;
    this.cacheItems += 1;
    this.trimByteCache();
  }

  private trimByteCache(): void {
    while (this.cacheBytes > MAX_CACHE_BYTES || this.cacheItems > MAX_CACHE_ITEMS) {
      let oldestIndex: number = -1;
      let oldestUse: number = Number.MAX_SAFE_INTEGER;
      for (let i: number = 0; i < this.entries.length; i++) {
        const entry: ProxyImageCacheEntry = this.entries[i];
        if (entry.bytes !== null && entry.lastUsed < oldestUse) {
          oldestIndex = i;
          oldestUse = entry.lastUsed;
        }
      }
      if (oldestIndex < 0) {
        return;
      }
      const oldest: ProxyImageCacheEntry = this.entries[oldestIndex];
      if (oldest.bytes !== null) {
        this.cacheBytes -= oldest.bytes.byteLength;
        this.cacheItems -= 1;
        oldest.bytes = null;
      }
      this.removeEmptyEntry(oldest);
    }
  }

  private trimPixelCache(): void {
    while (this.cachedPixelBytes > MAX_PIXEL_CACHE_BYTES ||
      this.cachedPixelItems > MAX_PIXEL_CACHE_ITEMS) {
      let oldestIndex: number = -1;
      let oldestUse: number = Number.MAX_SAFE_INTEGER;
      for (let i: number = 0; i < this.entries.length; i++) {
        const entry: ProxyImageCacheEntry = this.entries[i];
        if (entry.cachedPixelMap && entry.lastUsed < oldestUse) {
          oldestIndex = i;
          oldestUse = entry.lastUsed;
        }
      }
      if (oldestIndex < 0) {
        return;
      }
      const oldest: ProxyImageCacheEntry = this.entries[oldestIndex];
      if (oldest.cachedPixelMap) {
        oldest.cachedPixelMap = false;
        this.cachedPixelBytes -= oldest.pixelBytes;
        this.cachedPixelItems -= 1;
        this.disposePixelMap(oldest);
      }
      this.removeEmptyEntry(oldest);
    }
  }

  private disposePixelMap(entry: ProxyImageCacheEntry): void {
    const pixelMap: image.PixelMap | null = entry.pixelMap;
    entry.pixelMap = null;
    entry.pixelBytes = 0;
    if (pixelMap !== null) {
      this.releaseUncached(pixelMap);
    }
  }

  private removeEmptyEntry(target: ProxyImageCacheEntry): void {
    if (target.bytes !== null || target.pixelMap !== null || target.referenceCount > 0) {
      return;
    }
    for (let i: number = 0; i < this.entries.length; i++) {
      if (this.entries[i] === target) {
        this.entries.splice(i, 1);
        return;
      }
    }
  }

  private pixelByteCount(pixelMap: image.PixelMap): number {
    try {
      return pixelMap.getPixelBytesNumber();
    } catch (error) {
      return MAX_PIXEL_CACHE_BYTES + 1;
    }
  }

  private nextUseSerial(): number {
    this.useSerial += 1;
    return this.useSerial;
  }

  private releaseUncached(pixelMap: image.PixelMap): void {
    pixelMap.release().catch((): void => {
    });
  }

  private async decode(bytes: ArrayBuffer): Promise<image.PixelMap | null> {
    let imageSource: image.ImageSource | undefined = undefined;
    try {
      imageSource = image.createImageSource(bytes);
      return await imageSource.createPixelMap();
    } catch (error) {
      hilog.debug(DOMAIN, TAG, 'proxy image decode failed: %{public}s', JSON.stringify(error));
      return null;
    } finally {
      if (imageSource !== undefined) {
        try {
          await imageSource.release();
        } catch (error) {
          // Decoding may fail before the ImageSource has usable native state.
        }
      }
    }
  }

  private async fetchBytes(url: string): Promise<ArrayBuffer | null> {
    let request: http.HttpRequest | undefined = undefined;
    try {
      request = http.createHttp();
      const options: http.HttpRequestOptions = {
        method: http.RequestMethod.GET,
        header: { 'User-Agent': 'HarmonyX image' },
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        usingCache: false,
        connectTimeout: CONNECT_TIMEOUT_MS,
        readTimeout: READ_TIMEOUT_MS
      };
      await proxyStore.apply(options);
      const response: http.HttpResponse = await request.request(url, options);
      hilog.info(DOMAIN, TAG, 'image response status=%{public}d type=%{public}d array=%{public}s',
        response.responseCode, response.resultType, String(response.result instanceof ArrayBuffer));
      if (response.responseCode < 200 || response.responseCode >= 400 ||
        response.resultType !== http.HttpDataType.ARRAY_BUFFER) {
        return null;
      }
      const bytes: ArrayBuffer = response.result as ArrayBuffer;
      if (bytes.byteLength === 0) {
        return null;
      }
      return bytes;
    } catch (error) {
      hilog.debug(DOMAIN, TAG, 'proxy image request failed: %{public}s', JSON.stringify(error));
      proxyStore.noteNetworkFailure();
      return null;
    } finally {
      if (request !== undefined) {
        request.destroy();
      }
    }
  }
}

export const proxyImageResolver: ProxyImageResolver = new ProxyImageResolver();
