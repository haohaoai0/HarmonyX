// Proxy-aware local cache for avatar images. ArkUI Image loads a remote URL
// itself and cannot receive the proxy options held by ProxyStore.
import { common } from '@kit.AbilityKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import hilog from '@ohos.hilog';
import { proxyDownloadService } from './ProxyDownloadService';
import { proxyStore } from './ProxyStore';

const DOMAIN: number = 0xFF00;
const TAG: string = 'HarmonyX-AvatarCache';
const DIRECTORY: string = 'avatar-proxy-cache';

class AvatarImageStore {
  private directory: string = '';
  private inFlight: Map<string, Promise<string>> = new Map();

  load(context: common.UIAbilityContext, url: string, requireLocal: boolean = false): Promise<string> {
    if (url.startsWith('file://') || url.length === 0 || (!proxyStore.snapshot().enabled && !requireLocal)) {
      return Promise.resolve(url);
    }
    this.ensureDirectory(context);
    const key: string = this.keyFor(url);
    const cached: string = this.directory + '/' + key + '.img';
    try {
      const stat: fileIo.Stat = fileIo.statSync(cached);
      if (stat.isFile() && stat.size > 0) {
        return Promise.resolve(fileUri.getUriFromPath(cached));
      }
    } catch (error) {
      // A missing cache entry is expected before the first render.
    }
    const active: Promise<string> | undefined = this.inFlight.get(key);
    if (active !== undefined) {
      return active;
    }
    const request: Promise<string> = proxyDownloadService.download(url, cached)
      .then((success: boolean): string => {
        this.inFlight.delete(key);
        if (success) {
          return fileUri.getUriFromPath(cached);
        }
        this.remove(cached);
        hilog.debug(DOMAIN, TAG, 'avatar request failed key=%{public}s', key);
        return '';
      });
    this.inFlight.set(key, request);
    return request;
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
      hilog.warn(DOMAIN, TAG, '%{public}s', 'avatar cache unavailable');
    }
  }

  private keyFor(url: string): string {
    let hash: number = 0x811c9dc5;
    for (let index: number = 0; index < url.length; index++) {
      hash = hash ^ url.charCodeAt(index);
      hash = (hash * 0x01000193) >>> 0;
    }
    return hash.toString(16) + '-' + url.length.toString();
  }

  private remove(path: string): void {
    try {
      if (fileIo.accessSync(path)) {
        fileIo.unlinkSync(path);
      }
    } catch (error) {
      // Failed avatar downloads have no useful cache state to preserve.
    }
  }
}

export const avatarImageStore: AvatarImageStore = new AvatarImageStore();
