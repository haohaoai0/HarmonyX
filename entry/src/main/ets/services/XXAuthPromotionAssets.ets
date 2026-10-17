import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { http } from '@kit.NetworkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const PREFERENCES_NAME: string = 'harmonyx_update';
const RECORD_KEY: string = 'promotion_media_paths';
const MAX_BYTES: number = 5 * 1024 * 1024;
const MAX_FILES: number = 12;

class PromotionAssetRecord {
  url: string = '';
  path: string = '';
}

// The market CDN answers with an octet-stream content type, which ArkUI's own
// remote Image request refuses and which the proxy-aware decoder silently drops
// for cards. Downloading the bytes here and showing the local file is the same
// path the recommendation icon already proved on device.
export class XXAuthPromotionAssets {
  private context: common.UIAbilityContext;
  private paths: Map<string, string> | null = null;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  private directory(): string {
    return this.context.filesDir + '/app_recommendation';
  }

  private fileName(url: string): string {
    let hash: number = 2166136261;
    for (let i: number = 0; i < url.length; i++) {
      hash = hash ^ url.charCodeAt(i);
      hash = (hash * 16777619) >>> 0;
    }
    return 'promo_' + (hash >>> 0).toString(16) + '.image';
  }

  private read(): Map<string, string> {
    if (this.paths !== null) { return this.paths; }
    const loaded: Map<string, string> = new Map();
    try {
      const pref: preferences.Preferences = preferences.getPreferencesSync(this.context, { name: PREFERENCES_NAME });
      const raw: string = pref.getSync(RECORD_KEY, '{}') as string;
      const parsed: PromotionAssetRecord[] = JSON.parse(raw) as PromotionAssetRecord[];
      const records: PromotionAssetRecord[] = parsed instanceof Array ? parsed : [];
      for (let i: number = 0; i < records.length; i++) {
        const url: string = records[i].url;
        const path: string = records[i].path;
        if (typeof url === 'string' && url.length > 0 && typeof path === 'string' &&
          path.length > 0 && fileIo.accessSync(path)) {
          loaded.set(url, path);
        }
      }
    } catch (error) {
      hilog.warn(0xFF00, 'HarmonyX-Promo', 'read promotion cache failed: %{public}s', JSON.stringify(error));
    }
    this.paths = loaded;
    return loaded;
  }

  private persist(): void {
    const paths: Map<string, string> = this.read();
    const records: PromotionAssetRecord[] = [];
    const keys: string[] = Array.from(paths.keys());
    for (let i: number = 0; i < keys.length; i++) {
      const record: PromotionAssetRecord = new PromotionAssetRecord();
      record.url = keys[i];
      record.path = paths.get(keys[i]) as string;
      records.push(record);
    }
    try {
      const pref: preferences.Preferences = preferences.getPreferencesSync(this.context, { name: PREFERENCES_NAME });
      pref.putSync(RECORD_KEY, JSON.stringify(records));
      pref.flushSync();
    } catch (error) {
      hilog.warn(0xFF00, 'HarmonyX-Promo', 'save promotion cache failed: %{public}s', JSON.stringify(error));
    }
  }

  private async prune(keep: string): Promise<void> {
    const paths: Map<string, string> = this.read();
    while (paths.size > MAX_FILES) {
      const first: string | undefined = Array.from(paths.keys())[0];
      if (first === undefined || first === keep) { return; }
      const path: string = paths.get(first) as string;
      paths.delete(first);
      try {
        if (fileIo.accessSync(path)) { await fileIo.unlink(path); }
      } catch (error) { }
    }
    this.persist();
  }

  // Returns a file URI for the cached image, or '' when it could not be kept.
  async local(url: string): Promise<string> {
    if (url.length === 0) { return ''; }
    const cached: string | undefined = this.read().get(url);
    if (cached !== undefined && fileIo.accessSync(cached) && fileIo.statSync(cached).size > 0) {
      return fileUri.getUriFromPath(cached);
    }
    const request: http.HttpRequest = http.createHttp();
    let path: string = '';
    let committed: boolean = false;
    try {
      const response: http.HttpResponse = await request.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        usingCache: true,
        maxLimit: MAX_BYTES,
        connectTimeout: 10000,
        readTimeout: 10000
      });
      if (response.responseCode !== 200 || !(response.result instanceof ArrayBuffer) ||
        response.result.byteLength === 0 || response.result.byteLength > MAX_BYTES) {
        throw new Error('Invalid image response');
      }
      const data: ArrayBuffer = response.result;
      const source: image.ImageSource = image.createImageSource(data);
      try {
        const info: image.ImageInfo = await source.getImageInfo();
        if (info.size.width <= 0 || info.size.height <= 0) { throw new Error('Invalid image data'); }
      } finally {
        await source.release();
      }
      const directory: string = this.directory();
      if (!fileIo.accessSync(directory)) { await fileIo.mkdir(directory); }
      path = directory + '/' + this.fileName(url);
      const file: fileIo.File = await fileIo.open(path,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
      try {
        let written: number = 0;
        while (written < data.byteLength) {
          const count: number = await fileIo.write(file.fd, data.slice(written));
          if (count <= 0) { throw new Error('Incomplete image write'); }
          written += count;
        }
      } finally {
        await fileIo.close(file);
      }
      this.read().set(url, path);
      this.persist();
      committed = true;
      await this.prune(url);
      return fileUri.getUriFromPath(path);
    } catch (error) {
      hilog.warn(0xFF00, 'HarmonyX-Promo', 'promotion image failed: %{public}s', JSON.stringify(error));
      return '';
    } finally {
      request.destroy();
      if (!committed && path.length > 0) {
        try { if (fileIo.accessSync(path)) { await fileIo.unlink(path); } } catch (error) { }
      }
    }
  }
}
