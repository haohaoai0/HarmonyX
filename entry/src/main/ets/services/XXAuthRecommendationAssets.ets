import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { http } from '@kit.NetworkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { parseRecommendationSnoozePrompt, RecommendationSnoozePrompt } from './XXAuthRecommendation';
import { XXAuthRecommendationCatalog } from './XXAuthRecommendationCatalog';
import { XXAuthAnnouncement, XXAuthResult } from '../models/XXAuth';
import { xxAuthService } from './XXAuthService';

const PREFERENCES_NAME: string = 'harmonyx_update';
const ICON_RECORD_KEY: string = 'recommendation_icon_record';
const SNOOZE_PROMPT_DISABLED_KEY: string = 'snooze_prompt_disabled';
const LEGACY_PROMPT_DISABLED_KEY: string = 'reminders_disabled';
const MAX_ICON_BYTES: number = 5 * 1024 * 1024;

interface IconRecord {
  url: string;
  path: string;
}

export class XXAuthRecommendationAssets {
  private context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  private getPreferences(): preferences.Preferences {
    return preferences.getPreferencesSync(this.context, { name: PREFERENCES_NAME });
  }

  async fetchSnoozePrompt(appId: string = ''): Promise<RecommendationSnoozePrompt | null> {
    if (this.isSnoozePromptDisabled(appId)) { return null; }
    const result: XXAuthResult<XXAuthAnnouncement[]> = await xxAuthService.announcements();
    if (!result.ok || !(result.data instanceof Array)) { return null; }
    return appId.length > 0 ? XXAuthRecommendationCatalog.snoozePrompt(result.data, appId) :
      parseRecommendationSnoozePrompt(result.data);
  }

  isSnoozePromptDisabled(appId: string = ''): boolean {
    try {
      const pref: preferences.Preferences = this.getPreferences();
      // 上个版本保存的选择也只用于优先级 14，不再参与半模态的显示判断。
      const legacy: boolean = appId.length === 0 && pref.getSync(LEGACY_PROMPT_DISABLED_KEY, false) === true;
      const key: string = SNOOZE_PROMPT_DISABLED_KEY + (appId.length > 0 ? '_' + appId : '');
      return pref.getSync(key, legacy) as boolean;
    } catch (error) {
      hilog.error(0x0000, 'Recommendation', 'Read snooze prompt preference failed: %{public}s', JSON.stringify(error));
      return false;
    }
  }

  disableSnoozePrompt(appId: string = ''): void {
    const pref: preferences.Preferences = this.getPreferences();
    const previous: boolean = this.isSnoozePromptDisabled(appId);
    const key: string = SNOOZE_PROMPT_DISABLED_KEY + (appId.length > 0 ? '_' + appId : '');
    try {
      pref.putSync(key, true);
      pref.flushSync();
    } catch (error) {
      pref.putSync(key, previous);
      throw new Error('Save snooze prompt preference failed: ' + JSON.stringify(error));
    }
  }

  private iconDirectory(): string {
    // filesDir 持久保存，系统清理 cacheDir 不会导致每次重新下载。
    return this.context.filesDir + '/app_recommendation';
  }

  private readIconRecord(): IconRecord | null {
    try {
      const record: IconRecord = JSON.parse(this.getPreferences().getSync(ICON_RECORD_KEY, '{}') as string) as IconRecord;
      if (typeof record.url === 'string' && typeof record.path === 'string' &&
        record.path.startsWith(this.iconDirectory() + '/icon_') && fileIo.accessSync(record.path) &&
        fileIo.statSync(record.path).size > 0) {
        return record;
      }
    } catch (error) {
      hilog.warn(0x0000, 'Recommendation', 'Read icon cache failed: %{public}s', JSON.stringify(error));
    }
    return null;
  }

  async getLocalIcon(url: string): Promise<string> {
    const cached: IconRecord | null = this.readIconRecord();
    if (cached !== null && cached.url === url) {
      return fileUri.getUriFromPath(cached.path);
    }
    const request: http.HttpRequest = http.createHttp();
    let newPath: string = '';
    let committed: boolean = false;
    try {
      const response: http.HttpResponse = await request.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        usingCache: false,
        maxLimit: MAX_ICON_BYTES,
        connectTimeout: 8000,
        readTimeout: 8000
      });
      if (response.responseCode !== 200 || !(response.result instanceof ArrayBuffer) ||
        response.result.byteLength === 0 || response.result.byteLength > MAX_ICON_BYTES) {
        throw new Error('Invalid icon response');
      }
      const data: ArrayBuffer = response.result;
      const source: image.ImageSource = image.createImageSource(data);
      try {
        const info: image.ImageInfo = await source.getImageInfo();
        if (info.size.width <= 0 || info.size.height <= 0) {
          throw new Error('Invalid icon image');
        }
      } finally {
        await source.release();
      }
      const directory: string = this.iconDirectory();
      if (!fileIo.accessSync(directory)) {
        await fileIo.mkdir(directory);
      }
      // 新文件写完并保存 URL 记录后再清理旧文件，失败不会破坏原缓存。
      newPath = directory + '/icon_' + Date.now() + '_' + Math.floor(Math.random() * 1000000000) + '.image';
      const file: fileIo.File = await fileIo.open(newPath,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
      try {
        let written: number = 0;
        while (written < data.byteLength) {
          const count: number = await fileIo.write(file.fd, data.slice(written));
          if (count <= 0) {
            throw new Error('Incomplete icon write');
          }
          written += count;
        }
      } finally {
        await fileIo.close(file);
      }
      const record: IconRecord = { url: url, path: newPath };
      const pref: preferences.Preferences = this.getPreferences();
      const previousRecord: string = pref.getSync(ICON_RECORD_KEY, '{}') as string;
      try {
        pref.putSync(ICON_RECORD_KEY, JSON.stringify(record));
        pref.flushSync();
      } catch (error) {
        // flush 失败时回退内存中的链接，避免错误命中新图标缓存。
        pref.putSync(ICON_RECORD_KEY, previousRecord);
        throw new Error('Save icon record failed: ' + JSON.stringify(error));
      }
      committed = true;
      if (cached !== null && cached.path !== newPath) {
        await this.removeIconFile(cached.path);
      }
      return fileUri.getUriFromPath(newPath);
    } catch (error) {
      hilog.warn(0x0000, 'Recommendation', 'Refresh icon failed: %{public}s', JSON.stringify(error));
      // 不把旧图标作为新 URL 的缓存；下一次检查仍会重试下载。
      return '';
    } finally {
      request.destroy();
      if (!committed && newPath.length > 0) {
        await this.removeIconFile(newPath);
      }
    }
  }

  private async removeIconFile(path: string): Promise<void> {
    try {
      if (fileIo.accessSync(path)) {
        await fileIo.unlink(path);
      }
    } catch (error) {
      hilog.warn(0x0000, 'Recommendation', 'Clean icon failed: %{public}s', JSON.stringify(error));
    }
  }
}
