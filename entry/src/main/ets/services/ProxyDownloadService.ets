import { DohHttpRequest, createDohHttpRequest } from './DohHttpRequest';
// Streaming file downloader used for media and playback cache. Unlike the
// system request.downloadFile API, this path accepts the same proxy options as
// the rest of the app's HTTP stack.
import { fileIo } from '@kit.CoreFileKit';
import http from '@ohos.net.http';
import hilog from '@ohos.hilog';
import { proxyStore } from './ProxyStore';

const DOMAIN: number = 0xFF00;
const TAG: string = 'HarmonyX-ProxyDownload';
const CONNECT_TIMEOUT_MS: number = 20000;
const READ_TIMEOUT_MS: number = 300000;

export type ProxyDownloadProgress = (receivedBytes: number, totalBytes: number) => void;

export const PROXY_DOWNLOAD_COMPLETE: number = 0;
export const PROXY_DOWNLOAD_STOPPED: number = 1;
export const PROXY_DOWNLOAD_FAILED: number = 2;

export class ProxyDownloadOperation {
  promise: Promise<number> = Promise.resolve(PROXY_DOWNLOAD_FAILED);
  private request: DohHttpRequest | null = null;
  private stopped: boolean = false;

  cancel(): void {
    this.stopped = true;
    const request: DohHttpRequest | null = this.request;
    if (request !== null) {
      try {
        request.destroy();
      } catch (error) {
        // The request may have completed immediately before the pause action.
      }
    }
  }

  isStopped(): boolean {
    return this.stopped;
  }

  setRequest(request: DohHttpRequest | null): void {
    this.request = request;
  }
}

export class ProxyDownloadService {
  startResumableDownload(url: string, filePath: string, offset: number,
    onProgress: ProxyDownloadProgress): ProxyDownloadOperation {
    const operation: ProxyDownloadOperation = new ProxyDownloadOperation();
    operation.promise = this.downloadResumable(operation, url, filePath, offset, onProgress);
    return operation;
  }

  async download(url: string, filePath: string,
    onProgress: ProxyDownloadProgress | undefined = undefined): Promise<boolean> {
    if (url.length === 0 || filePath.length === 0) {
      return false;
    }
    let request: DohHttpRequest | undefined = undefined;
    let file: fileIo.File | undefined = undefined;
    let writeFailed: boolean = false;
    let expectedBytes: number = 0;
    let receivedBytes: number = 0;
    let dataEnded: boolean = false;
    try {
      file = fileIo.openSync(filePath,
        fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      request = createDohHttpRequest();
      request.on('dataReceive', (data: ArrayBuffer): void => {
        if (writeFailed || file === undefined) {
          return;
        }
        try {
          receivedBytes += fileIo.writeSync(file.fd, data);
        } catch (error) {
          writeFailed = true;
          hilog.error(DOMAIN, TAG, 'write failed: %{public}s', JSON.stringify(error));
        }
      });
      request.on('dataReceiveProgress', (progress: http.DataReceiveProgressInfo): void => {
        if (progress.totalSize > 0) {
          expectedBytes = progress.totalSize;
        }
        if (onProgress !== undefined) {
          onProgress(progress.receiveSize, progress.totalSize);
        }
      });
      request.on('dataEnd', (): void => {
        dataEnded = true;
      });
      const options: http.HttpRequestOptions = {
        method: http.RequestMethod.GET,
        header: { 'User-Agent': 'HarmonyX media' },
        connectTimeout: CONNECT_TIMEOUT_MS,
        readTimeout: READ_TIMEOUT_MS
      };
      await proxyStore.applyForMediaRequest(options, url);
      const status: number = await request.requestInStream(url, options);
      if (writeFailed || status < 200 || status >= 300) {
        hilog.warn(DOMAIN, TAG, 'download rejected status=%{public}d bytes=%{public}d ended=%{public}s',
          status, receivedBytes, String(dataEnded));
        return false;
      }
      const stat = fileIo.statSync(filePath);
      if (stat.size <= 0 || (expectedBytes > 0 && stat.size !== expectedBytes)) {
        hilog.warn(DOMAIN, TAG,
          'download incomplete status=%{public}d bytes=%{public}d expected=%{public}d ended=%{public}s',
          status, receivedBytes, expectedBytes, String(dataEnded));
      }
      return stat.isFile() && stat.size > 0 && (expectedBytes <= 0 || stat.size === expectedBytes);
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'download failed: %{public}s', JSON.stringify(error));
      proxyStore.noteNetworkFailure(url);
      return false;
    } finally {
      if (request !== undefined) {
        try {
          request.off('dataReceive');
          request.off('dataReceiveProgress');
          request.off('dataEnd');
          request.destroy();
        } catch (error) {
          // A user pause may already have destroyed the request.
        }
      }
      if (file !== undefined) {
        try {
          fileIo.closeSync(file.fd);
        } catch (error) {
          // The request may fail before the file is created.
        }
      }
    }
  }

  async downloadWithRetry(url: string, filePath: string, maxAttempts: number = 3): Promise<boolean> {
    const attempts: number = Math.max(1, maxAttempts);
    for (let i: number = 0; i < attempts; i++) {
      if (await this.download(url, filePath)) {
        return true;
      }
      if (i + 1 < attempts) {
        const delayMs: number = 350 * (i + 1);
        await new Promise<void>((resolve: () => void): void => {
          setTimeout((): void => resolve(), delayMs);
        });
      }
    }
    try {
      fileIo.unlinkSync(filePath);
    } catch (error) {
      // The failed request may not have left a partial file.
    }
    return false;
  }

  private async downloadResumable(operation: ProxyDownloadOperation, url: string, filePath: string,
    offset: number, onProgress: ProxyDownloadProgress): Promise<number> {
    if (url.length === 0 || filePath.length === 0) {
      return PROXY_DOWNLOAD_FAILED;
    }
    const firstStatus: number = await this.downloadAttempt(operation, url, filePath, offset, onProgress);
    if (operation.isStopped()) {
      return PROXY_DOWNLOAD_STOPPED;
    }
    if (firstStatus >= 200 && firstStatus < 300 && (offset === 0 || firstStatus === 206)) {
      return PROXY_DOWNLOAD_COMPLETE;
    }
      if (firstStatus >= 400) {
        try {
          fileIo.unlinkSync(filePath);
        } catch (error) {
          // There may be no response body to remove.
        }
        return PROXY_DOWNLOAD_FAILED;
      }
      if (offset > 0 && firstStatus === 200) {
      // Some CDNs ignore Range. Retry from the beginning instead of appending
      // a complete response to the saved partial file.
      try {
        fileIo.unlinkSync(filePath);
      } catch (error) {
        // The partial file may not exist if the first request failed early.
      }
      return await this.downloadResumable(operation, url, filePath, 0, onProgress);
    }
    return PROXY_DOWNLOAD_FAILED;
  }

  private async downloadAttempt(operation: ProxyDownloadOperation, url: string, filePath: string,
    offset: number, onProgress: ProxyDownloadProgress): Promise<number> {
    let request: DohHttpRequest | undefined = undefined;
    let file: fileIo.File | undefined = undefined;
    let writeFailed: boolean = false;
    try {
      const openMode: number = fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE |
        (offset > 0 ? fileIo.OpenMode.APPEND : fileIo.OpenMode.TRUNC);
      file = fileIo.openSync(filePath, openMode);
      request = createDohHttpRequest();
      operation.setRequest(request);
      request.on('dataReceive', (data: ArrayBuffer): void => {
        if (operation.isStopped() || writeFailed || file === undefined) {
          return;
        }
        try {
          fileIo.writeSync(file.fd, data);
        } catch (error) {
          writeFailed = true;
          hilog.error(DOMAIN, TAG, 'resumable write failed: %{public}s', JSON.stringify(error));
        }
      });
      request.on('dataReceiveProgress', (progress: http.DataReceiveProgressInfo): void => {
        if (operation.isStopped()) {
          return;
        }
        const receivedBytes: number = offset + progress.receiveSize;
        const totalBytes: number = progress.totalSize > 0 ? offset + progress.totalSize : 0;
        onProgress(receivedBytes, totalBytes);
      });
      const header: Record<string, string> = { 'User-Agent': 'HarmonyX media' };
      if (offset > 0) {
        header['Range'] = 'bytes=' + offset.toString() + '-';
      }
      const options: http.HttpRequestOptions = {
        method: http.RequestMethod.GET,
        header: header,
        connectTimeout: CONNECT_TIMEOUT_MS,
        readTimeout: READ_TIMEOUT_MS
      };
      await proxyStore.applyForMediaRequest(options, url);
      const status: number = await request.requestInStream(url, options);
      return writeFailed ? -1 : status;
    } catch (error) {
      if (!operation.isStopped()) {
        hilog.warn(DOMAIN, TAG, 'resumable download failed: %{public}s', JSON.stringify(error));
        proxyStore.noteNetworkFailure(url);
      }
      return -1;
    } finally {
      if (request !== undefined) {
        request.off('dataReceive');
        request.off('dataReceiveProgress');
        request.destroy();
      }
      operation.setRequest(null);
      if (file !== undefined) {
        try {
          fileIo.closeSync(file.fd);
        } catch (error) {
          // A failed transfer may already have closed its descriptor.
        }
      }
      if (writeFailed) {
        hilog.warn(DOMAIN, TAG, '%{public}s', 'resumable download write did not complete');
      }
    }
  }
}

export const proxyDownloadService: ProxyDownloadService = new ProxyDownloadService();
