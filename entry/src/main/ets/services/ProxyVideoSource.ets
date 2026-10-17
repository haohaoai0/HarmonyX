// Bridges the proxy-aware HTTP client to AVPlayer. AVPlayer cannot consume an
// HTTP response body directly, so a progressive MP4 is placed in a temporary
// app-cache file only for the lifetime of the player descriptor, then removed.
import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import hilog from '@ohos.hilog';
import { proxyDownloadService } from './ProxyDownloadService';
import { VideoCacheLease } from './VideoPlaybackCache';

const DOMAIN: number = 0xFF00;
const TAG: string = 'HarmonyX-ProxyVideo';
const DIRECTORY: string = 'proxy-video-source';

class ProxyVideoSource {
  private directory: string = '';
  private sequence: number = 0;

  async prepare(context: common.UIAbilityContext, mediaId: string, rendition: string,
    remoteUrl: string): Promise<VideoCacheLease | null> {
    if (!this.isProgressiveMp4(remoteUrl)) {
      return null;
    }
    this.ensureDirectory(context);
    const key: string = this.newKey(mediaId, rendition);
    const path: string = this.directory + '/' + key + '.mp4';
    const success: boolean = await proxyDownloadService.download(remoteUrl, path);
    if (!success) {
      this.remove(path);
      return null;
    }
    try {
      const stat: fileIo.Stat = fileIo.statSync(path);
      if (!stat.isFile() || stat.size <= 0) {
        this.remove(path);
        return null;
      }
      const file: fileIo.File = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
      return new VideoCacheLease(key, file.fd, stat.size, (): void => {
        this.remove(path);
      });
    } catch (error) {
      hilog.debug(DOMAIN, TAG, 'temporary video open failed');
      this.remove(path);
      return null;
    }
  }

  private isProgressiveMp4(remoteUrl: string): boolean {
    const queryIndex: number = remoteUrl.indexOf('?');
    const path: string = queryIndex >= 0 ? remoteUrl.substring(0, queryIndex) : remoteUrl;
    return path.toLowerCase().endsWith('.mp4');
  }

  private ensureDirectory(context: common.UIAbilityContext): void {
    const nextDirectory: string = context.cacheDir + '/' + DIRECTORY;
    if (nextDirectory === this.directory) {
      return;
    }
    this.directory = nextDirectory;
    try {
      if (!fileIo.accessSync(this.directory)) {
        fileIo.mkdirSync(this.directory, true);
      }
    } catch (error) {
      hilog.warn(DOMAIN, TAG, '%{public}s', 'temporary video directory unavailable');
    }
  }

  private newKey(mediaId: string, rendition: string): string {
    this.sequence += 1;
    let hash: number = 0x811c9dc5;
    const value: string = mediaId + ':' + rendition + ':' + Date.now().toString() + ':' + this.sequence.toString();
    for (let index: number = 0; index < value.length; index++) {
      hash = hash ^ value.charCodeAt(index);
      hash = (hash * 0x01000193) >>> 0;
    }
    return hash.toString(16) + '-' + this.sequence.toString();
  }

  private remove(path: string): void {
    try {
      if (fileIo.accessSync(path)) {
        fileIo.unlinkSync(path);
      }
    } catch (error) {
      // A released descriptor can hold the OS file briefly; cacheDir cleanup
      // will reclaim that rare leftover on a later app launch.
    }
  }
}

export const proxyVideoSource: ProxyVideoSource = new ProxyVideoSource();
