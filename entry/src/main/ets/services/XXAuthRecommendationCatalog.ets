import { XXAuthAnnouncement, XXAuthPanel } from '../models/XXAuth';
import { isRecommendationStoreUrl, RecommendationSnoozePrompt } from './XXAuthRecommendation';

export const XXAUTH_RECOMMENDATION_APP_PRIORITY: number = 15;

export class XXAuthRecommendationApp {
  id: string = '';
  name: string = '';
  subtitle: string = '';
  description: string = '';
  iconUrl: string = '';
  link: string = '';
  enabled: boolean = false;
  popupEnabled: boolean = false;
  postEnabled: boolean = false;
  splashEnabled: boolean = false;
  splashImage: string = '';
  splashImages: string[] = [];
  splashTitle: string = '';
  splashDescription: string = '';
  splashAction: string = '';
  splashDuration: number = 3;
  reminderForced: boolean = false;
  snoozeTitle: string = '';
  snoozeMessage: string = '';
  post: XXAuthAnnouncement = { id: '', title: '', content: '', priority: 15 };
}

// A published priority-15 record now contains one complete app. The legacy
// split records are read only when no app records exist, including when every
// app is disabled or invalid, so switching an app off never revives old copy.
export class XXAuthRecommendationCatalog {
  static fields(content: string): Map<string, string> {
    const fields: Map<string, string> = new Map();
    const lines: string[] = content.replace(/\r\n?/g, '\n').split('\n');
    let section: string = '';
    for (let i: number = 0; i < lines.length; i++) {
      const match: RegExpMatchArray | null = lines[i].trim().match(
        /^(应用标识|应用名称|应用小注释|应用多行注释|应用图标|应用链接|应用开关|弹窗开关|信息流开关|弹窗提醒|免提醒标题|免提醒文案|帖子昵称|帖子账号|帖子认证|帖子头像|帖子正文|帖子媒体|帖子媒体平板|帖子链接|帖子开关|开屏开关|开屏图片|开屏标题|开屏文案|开屏按钮|开屏时长)\s*[:：]\s*(.*)$/);
      if (match !== null) {
        section = match[1];
        fields.set(section, match[2]);
      } else if (section.length > 0) {
        fields.set(section, (fields.get(section) ?? '') + '\n' + lines[i]);
      }
    }
    return fields;
  }

  static isApp(item: XXAuthAnnouncement): boolean {
    return item.priority === XXAUTH_RECOMMENDATION_APP_PRIORITY && typeof item.content === 'string' &&
      /(?:^|\n)\s*应用标识\s*[:：]/.test(item.content);
  }

  static present(items: XXAuthAnnouncement[]): boolean {
    return items.some((item: XXAuthAnnouncement): boolean => XXAuthRecommendationCatalog.isApp(item));
  }

  private static on(value: string | undefined): boolean {
    return /^(开|开启|启用|on|true|1|yes)$/i.test((value ?? '').trim());
  }

  private static text(value: string | undefined): string {
    return (value ?? '').replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, '')
      .replace(/<style\b[^>]*>[\s\S]*?<\/style>/gi, '')
      .replace(/<\/(p|div|li|h[1-6])\s*>|<br\s*\/?\s*>/gi, '\n')
      .replace(/<[^>]*>/g, '').replace(/&nbsp;/g, ' ').replace(/&amp;/g, '&').trim();
  }

  private static https(value: string | undefined): string {
    const url: string = (value ?? '').trim();
    return /^https:\/\/[^\s/@]+(?:\:[0-9]+)?(?:[/?#][^\s]*)?$/i.test(url) ? url : '';
  }

  private static pictures(value: string | undefined): string[] {
    const result: string[] = [];
    const lines: string[] = (value ?? '').replace(/\r\n?/g, '\n').split('\n');
    for (let i: number = 0; i < lines.length && result.length < 6; i++) {
      const url: string = XXAuthRecommendationCatalog.https(lines[i].trim().split('|')[0]);
      if (url.length > 0 && !/\.(mp4|m3u8|webm|mov)(\?|#|$)/i.test(url) && !result.includes(url)) {
        result.push(url);
      }
    }
    return result;
  }

  static apps(items: XXAuthAnnouncement[]): XXAuthRecommendationApp[] {
    const records: XXAuthAnnouncement[] = items.filter(
      (item: XXAuthAnnouncement): boolean => XXAuthRecommendationCatalog.isApp(item));
    records.sort((left: XXAuthAnnouncement, right: XXAuthAnnouncement): number =>
      (Date.parse(right.updated_at || right.created_at || '') || 0) -
      (Date.parse(left.updated_at || left.created_at || '') || 0));
    const apps: XXAuthRecommendationApp[] = [];
    const seen: string[] = [];
    for (let i: number = 0; i < records.length; i++) {
      const record: XXAuthAnnouncement = records[i];
      const fields: Map<string, string> = XXAuthRecommendationCatalog.fields(record.content);
      const id: string = (fields.get('应用标识') ?? '').trim();
      if (!/^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$/.test(id) || seen.indexOf(id) >= 0) { continue; }
      seen.push(id);
      const app: XXAuthRecommendationApp = new XXAuthRecommendationApp();
      app.id = id;
      app.name = XXAuthRecommendationCatalog.text(fields.get('应用名称'));
      app.subtitle = XXAuthRecommendationCatalog.text(fields.get('应用小注释'));
      app.description = XXAuthRecommendationCatalog.text(fields.get('应用多行注释'));
      app.iconUrl = XXAuthRecommendationCatalog.https(fields.get('应用图标'));
      const link: string = (fields.get('应用链接') ?? '').trim();
      app.link = isRecommendationStoreUrl(link) ? link : '';
      const usable: boolean = app.name.length > 0 && app.iconUrl.length > 0 && app.link.length > 0;
      app.enabled = usable && (record.status === undefined || record.status === 1) &&
        record.content.indexOf('//关闭') < 0 && XXAuthRecommendationCatalog.on(fields.get('应用开关'));
      app.popupEnabled = XXAuthRecommendationCatalog.on(fields.get('弹窗开关'));
      app.postEnabled = XXAuthRecommendationCatalog.on(fields.get('信息流开关'));
      const configuredPictures: string[] = XXAuthRecommendationCatalog.pictures(fields.get('开屏图片'));
      // One poster can be supplemented by this app's own introduction images.
      // An explicit multi-image list gives the operator full control of the mosaic.
      app.splashImages = configuredPictures.length > 1 ? configuredPictures :
        XXAuthRecommendationCatalog.pictures(configuredPictures.join('\n') + '\n' + (fields.get('帖子媒体') ?? ''));
      app.splashImage = app.splashImages.length > 0 ? app.splashImages[0] : '';
      app.splashEnabled = XXAuthRecommendationCatalog.on(fields.get('开屏开关')) && app.splashImage.length > 0;
      app.splashTitle = XXAuthRecommendationCatalog.text(fields.get('开屏标题')) || app.name;
      app.splashDescription = XXAuthRecommendationCatalog.text(fields.get('开屏文案')) || app.description;
      app.splashAction = XXAuthRecommendationCatalog.text(fields.get('开屏按钮'));
      const splashDuration: number = Number((fields.get('开屏时长') ?? '').trim());
      app.splashDuration = Number.isFinite(splashDuration) && splashDuration > 0 ?
        Math.max(1, Math.min(5, splashDuration)) : 3;
      app.reminderForced = /^(强制提醒|force)$/i.test((fields.get('弹窗提醒') ?? '').trim());
      app.snoozeTitle = XXAuthRecommendationCatalog.text(fields.get('免提醒标题'));
      app.snoozeMessage = XXAuthRecommendationCatalog.text(fields.get('免提醒文案'));
      // Only this app's fields reach the legacy post parser. No shared icon,
      // media or destination can bleed from another app into this post.
      const body: string[] = [
        '帖子昵称：' + (XXAuthRecommendationCatalog.text(fields.get('帖子昵称')) || app.name),
        '帖子账号：' + (XXAuthRecommendationCatalog.text(fields.get('帖子账号')) || '@' + app.name),
        '帖子认证：' + (fields.get('帖子认证') ?? '无'),
        '帖子头像：' + (XXAuthRecommendationCatalog.https(fields.get('帖子头像')) || app.iconUrl),
        '帖子链接：' + app.link,
        '帖子媒体：' + (fields.get('帖子媒体') ?? ''),
        '帖子媒体平板：' + (fields.get('帖子媒体平板') ?? ''),
        '帖子正文：' + (fields.get('帖子正文') ?? app.description)
      ];
      app.post = { id: record.id, title: record.title, content: body.join('\n'),
        priority: 15, status: record.status, created_at: record.created_at, updated_at: record.updated_at };
      apps.push(app);
    }
    return apps;
  }

  static panels(items: XXAuthAnnouncement[]): XXAuthPanel[] {
    const apps: XXAuthRecommendationApp[] = XXAuthRecommendationCatalog.apps(items);
    const panels: XXAuthPanel[] = [];
    for (let i: number = 0; i < apps.length; i++) {
      const app: XXAuthRecommendationApp = apps[i];
      if (!app.enabled || !app.popupEnabled) { continue; }
      const panel: XXAuthPanel = new XXAuthPanel();
      panel.kind = 'recommendation';
      panel.id = 'app:' + app.id;
      panel.recommendationAppId = app.id;
      panel.structuredRecommendation = true;
      panel.reminderForced = app.reminderForced;
      panel.title = app.name;
      panel.subtitle = app.subtitle;
      panel.content = app.description;
      panel.imageUrl = app.iconUrl;
      panel.link = app.link;
      panel.snoozeTitle = app.snoozeTitle;
      panel.snoozeMessage = app.snoozeMessage;
      panel.fingerprint = JSON.stringify([app.id, app.name, app.subtitle, app.description,
        app.iconUrl, app.link, app.reminderForced, app.snoozeTitle, app.snoozeMessage]);
      panels.push(panel);
    }
    return panels;
  }

  static snoozePrompt(items: XXAuthAnnouncement[], appId: string): RecommendationSnoozePrompt | null {
    const app: XXAuthRecommendationApp | undefined = XXAuthRecommendationCatalog.apps(items).find(
      (candidate: XXAuthRecommendationApp): boolean => candidate.id === appId);
    return app !== undefined && app.enabled && app.popupEnabled && app.snoozeMessage.length > 0 ?
      { title: app.snoozeTitle || app.name, message: app.snoozeMessage, storeUrl: app.link } : null;
  }
}
