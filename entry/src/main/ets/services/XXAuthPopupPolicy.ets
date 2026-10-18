import { XXAuthAnnouncement, XXAuthArticle, XXAuthBanner, XXAuthPanel,
  XXAuthPopupConfig, XXAuthVariable, XXAuthVersionCheck } from '../models/XXAuth';
import { parseRecommendationConfig, RecommendationConfig, RecommendationMode } from './XXAuthRecommendation';
import { XXAuthRecommendationCatalog } from './XXAuthRecommendationCatalog';

interface XXAuthVariableValue {
  value?: Object;
}

// Reserved priority slots that configure the product instead of addressing the
// reader: 10 mode, 11 app info, 12 icon, 13 store link, 14 snooze wording,
// 15 promotion post, 16 promotion media, plus the -2 legacy link record.
export const XXAUTH_CONTROL_PRIORITY_MIN: number = 10;
export const XXAUTH_CONTROL_PRIORITY_MAX: number = 16;

// Each switch is its own backend variable, so the 变量配置 page shows one row
// per decision instead of a single JSON blob. `on/off` is the readable form;
// true/false/1/0/开/关 are accepted too.
export const XXAUTH_VAR_MASTER: string = 'harmonyx_enabled';
export const XXAUTH_VAR_RECOMMEND: string = 'harmonyx_recommend';
export const XXAUTH_VAR_ANNOUNCEMENTS: string = 'harmonyx_announcements';
export const XXAUTH_VAR_GUIDE: string = 'harmonyx_guide';
export const XXAUTH_VAR_BANNER: string = 'harmonyx_banner';
export const XXAUTH_VAR_POST_COUNT: string = 'harmonyx_post_count';
export const XXAUTH_VAR_POST_COMMENT_COUNT: string = 'harmonyx_post_comment_count';
export const XXAUTH_VAR_POST_REVISION: string = 'harmonyx_post_revision';
export const XXAUTH_POPUP_RECOMMENDATION_VAR: string = 'harmonyx_popup';

export class XXAuthPopupPolicy {
  private static flagValue(value: Object | undefined): boolean | undefined {
    if (value === undefined || value === null) { return undefined; }
    const text: string = typeof value === 'string' ? value.trim().toLowerCase() : JSON.stringify(value);
    if (text === 'on' || text === 'true' || text === '1' || text === '开' || text === '启用' || text === 'yes') {
      return true;
    }
    if (text === 'off' || text === 'false' || text === '0' || text === '关' || text === '停用' ||
      text === 'no' || text === '') {
      return false;
    }
    return undefined;
  }

  private static numberValue(value: Object | undefined): number | undefined {
    if (value === undefined || value === null) { return undefined; }
    const parsed: number = typeof value === 'number' ? value : Number(String(value).trim());
    return Number.isFinite(parsed) ? parsed : undefined;
  }

  // Overlays the per-switch variables on top of the JSON configuration; a
  // variable that is absent leaves the JSON value in place.
  static applyVariables(config: XXAuthPopupConfig, rows: XXAuthVariable[]): void {
    const values: Map<string, Object> = new Map();
    for (let i: number = 0; i < rows.length; i++) {
      const row: XXAuthVariable = rows[i];
      if (row !== undefined && typeof row.key === 'string') { values.set(row.key, row.value); }
    }
    const flag = (key: string): boolean | undefined => XXAuthPopupPolicy.flagValue(values.get(key));
    const number = (key: string): number | undefined => XXAuthPopupPolicy.numberValue(values.get(key));
    const master: boolean | undefined = flag(XXAUTH_VAR_MASTER);
    const recommend: boolean | undefined = flag(XXAUTH_VAR_RECOMMEND);
    const announcements: boolean | undefined = flag(XXAUTH_VAR_ANNOUNCEMENTS);
    const guide: boolean | undefined = flag(XXAUTH_VAR_GUIDE);
    const banner: boolean | undefined = flag(XXAUTH_VAR_BANNER);
    if (master !== undefined) { config.enabled = master; }
    if (recommend !== undefined) { config.promotion_enabled = recommend; }
    if (announcements !== undefined) { config.announcements_enabled = announcements; }
    if (guide !== undefined) { config.articles_enabled = guide; }
    if (banner !== undefined) { config.banners_enabled = banner; }
    const postCount: number | undefined = number(XXAUTH_VAR_POST_COUNT);
    const commentCount: number | undefined = number(XXAUTH_VAR_POST_COMMENT_COUNT);
    const revision: number | undefined = number(XXAUTH_VAR_POST_REVISION);
    if (postCount !== undefined) { config.post_count = postCount; }
    if (commentCount !== undefined) { config.post_comment_count = commentCount; }
    if (revision !== undefined) { config.post_revision = revision; }
    const dismissible: boolean | undefined = flag('harmonyx_post_dismissible');
    const force: boolean | undefined = flag('harmonyx_popup_force');
    const popupDismissible: boolean | undefined = flag('harmonyx_popup_dismissible');
    if (dismissible !== undefined) { config.post_dismissible = dismissible; }
    if (force !== undefined) { config.popup_force = force; }
    if (popupDismissible !== undefined) { config.popup_dismissible = popupDismissible; }
    const delay: number | undefined = number('harmonyx_popup_delay_seconds');
    const interval: number | undefined = number('harmonyx_popup_interval_hours');
    const daily: number | undefined = number('harmonyx_popup_daily_limit');
    const total: number | undefined = number('harmonyx_popup_total_limit');
    const session: number | undefined = number('harmonyx_popup_session_limit');
    const popupRevision: number | undefined = number('harmonyx_popup_revision');
    if (delay !== undefined) { config.popup_delay_seconds = delay; }
    if (interval !== undefined) { config.popup_interval_hours = interval; }
    if (daily !== undefined) { config.popup_daily_limit = daily; }
    if (total !== undefined) { config.popup_total_limit = total; }
    if (session !== undefined) { config.popup_session_limit = session; }
    if (popupRevision !== undefined) { config.popup_revision = popupRevision; }
    const start: Object | undefined = values.get('harmonyx_popup_start_at');
    const end: Object | undefined = values.get('harmonyx_popup_end_at');
    if (typeof start === 'string') { config.popup_start_at = start; }
    if (typeof end === 'string') { config.popup_end_at = end; }
  }

  static isControlRecord(item: XXAuthAnnouncement): boolean {
    const priority: number | undefined = item.priority;
    if (typeof priority !== 'number') { return false; }
    if (priority === -2 && item.title?.trim() === '链接') { return true; }
    return priority >= XXAUTH_CONTROL_PRIORITY_MIN && priority <= XXAUTH_CONTROL_PRIORITY_MAX;
  }

  static variableValue(items: XXAuthVariable[], key: string): Object | undefined {
    for (let i: number = 0; i < items.length; i++) {
      if (items[i].key === key) { return items[i].value; }
    }
    return undefined;
  }

  static text(value: string | undefined): string {
    if (typeof value !== 'string') { return ''; }
    return value.replace(/\/\/(提醒|关闭)/g, '')
      .replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, '')
      .replace(/<style\b[^>]*>[\s\S]*?<\/style>/gi, '')
      .replace(/<\/(p|div|li|h[1-6])\s*>|<br\s*\/?\s*>/gi, '\n')
      .replace(/<[^>]*>/g, '').replace(/&nbsp;/g, ' ').replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&#39;/g, "'")
      .replace(/&amp;/g, '&').trim();
  }

  static https(value: string | undefined): string {
    if (typeof value !== 'string') { return ''; }
    const link: string = value.trim();
    return /^https:\/\/[^\s/@]+(?:\:[0-9]+)?(?:[/?#][^\s]*)?$/i.test(link) ? link : '';
  }

  static config(value: Object | undefined): XXAuthPopupConfig {
    if (value === undefined || value === null) { return {}; }
    try {
      let parsed: Object = typeof value === 'string' ? JSON.parse(value as string) as Object : value;
      if (typeof parsed !== 'object' || parsed instanceof Array || parsed === null) { return { enabled: false }; }
      const variable: XXAuthVariableValue = parsed as XXAuthVariableValue;
      if (variable.value !== undefined) {
        parsed = typeof variable.value === 'string' ? JSON.parse(variable.value as string) as Object : variable.value;
        if (typeof parsed !== 'object' || parsed instanceof Array || parsed === null) { return { enabled: false }; }
      }
      return parsed as XXAuthPopupConfig;
    } catch (error) { return { enabled: false }; }
  }

  static linkItem(items: XXAuthAnnouncement[]): XXAuthAnnouncement | undefined {
    let selected: XXAuthAnnouncement | undefined = undefined;
    for (let i: number = 0; i < items.length; i++) {
      const item: XXAuthAnnouncement = items[i];
      if (item.priority !== -2 || item.title?.trim() !== '链接') { continue; }
      if (selected === undefined || (Date.parse(item.created_at ?? '') || 0) >
        (Date.parse(selected.created_at ?? '') || 0)) { selected = item; }
    }
    return selected;
  }

  static contentPanel(id: string, kind: string, title: string, content: string): XXAuthPanel {
    const panel: XXAuthPanel = new XXAuthPanel();
    panel.id = id;
    panel.kind = kind;
    panel.title = XXAuthPopupPolicy.text(title);
    panel.content = XXAuthPopupPolicy.text(content);
    panel.fingerprint = JSON.stringify([id, title, content]);
    panel.repeat = content.indexOf('//提醒') >= 0;
    return panel;
  }

  static startup(items: XXAuthAnnouncement[], banners: XXAuthBanner[], articles: XXAuthArticle[],
    config: XXAuthPopupConfig): XXAuthPanel[] {
    const panels: XXAuthPanel[] = [];
    if (config.enabled === false) { return panels; }
    const catalog: boolean = XXAuthRecommendationCatalog.present(items);
    if (catalog && config.promotion_enabled !== false && config.recommendation_enabled !== false) {
      const recommendations: XXAuthPanel[] = XXAuthRecommendationCatalog.panels(items);
      for (let i: number = 0; i < recommendations.length; i++) { panels.push(recommendations[i]); }
    }
    const structured: boolean = !catalog && items.some(
      (item: XXAuthAnnouncement): boolean => item.priority >= 10 && item.priority <= 14);
    // The recommendation switch covers the popup and the timeline post; the
    // per-channel key only narrows it further.
    if (structured && config.promotion_enabled !== false && config.recommendation_enabled !== false) {
      const recommendation: RecommendationConfig | null = parseRecommendationConfig(items);
      if (recommendation !== null && recommendation.mode !== RecommendationMode.CLOSED) {
        const panel: XXAuthPanel = new XXAuthPanel();
        panel.kind = 'recommendation';
        panel.id = 'priority_10_13';
        panel.structuredRecommendation = true;
        panel.reminderForced = recommendation.mode === RecommendationMode.FORCE;
        panel.title = recommendation.name;
        panel.subtitle = recommendation.subtitle;
        panel.content = recommendation.description;
        panel.imageUrl = recommendation.iconUrl;
        panel.link = recommendation.storeUrl;
        panel.fingerprint = JSON.stringify(recommendation);
        panels.push(panel);
      }
    }
    const link: XXAuthAnnouncement | undefined = XXAuthPopupPolicy.linkItem(items);
    if (!catalog && !structured && config.promotion_enabled !== false && config.recommendation_enabled !== false &&
      link !== undefined &&
      typeof link.content === 'string' && link.content.indexOf('//关闭') < 0) {
      const url: string = XXAuthPopupPolicy.https(XXAuthPopupPolicy.text(link.content));
      if (url.length > 0) {
        const panel: XXAuthPanel = XXAuthPopupPolicy.contentPanel(link.id, 'recommendation',
          config.recommendation_title ?? '', config.recommendation_description ?? '');
        panel.link = url;
        panel.imageUrl = XXAuthPopupPolicy.https(config.recommendation_icon);
        panel.fingerprint = JSON.stringify([link.id, link.content]);
        panels.push(panel);
      }
    }
    if (config.announcements_enabled !== false) {
      const sorted: XXAuthAnnouncement[] = items.slice().sort(
        (a: XXAuthAnnouncement, b: XXAuthAnnouncement): number => (b.priority ?? 0) - (a.priority ?? 0));
      for (let i: number = 0; i < sorted.length; i++) {
        const item: XXAuthAnnouncement = sorted[i];
        // A control record is never a user-facing announcement; it would
        // otherwise pop the promotion copy up as an announcement dialog.
        if (XXAuthPopupPolicy.isControlRecord(item) || typeof item.content !== 'string' ||
          item.content.indexOf('//关闭') >= 0 || XXAuthPopupPolicy.text(item.content).length === 0) { continue; }
        panels.push(XXAuthPopupPolicy.contentPanel(item.id, 'announcement', item.title, item.content));
      }
    }
    if (config.banners_enabled !== false) {
      for (let i: number = 0; i < banners.length; i++) {
        const banner: XXAuthBanner = banners[i];
        const image: string = XXAuthPopupPolicy.https(banner.image_url);
        if (image.length === 0) { continue; }
        const panel: XXAuthPanel = XXAuthPopupPolicy.contentPanel(banner.id, 'banner', banner.title ?? '', '');
        panel.imageUrl = image;
        panel.link = XXAuthPopupPolicy.https(banner.link_url);
        panel.fingerprint = JSON.stringify([banner.id, image, panel.link]);
        panels.push(panel);
      }
    }
    // Articles are available on demand; opt in explicitly to show them at startup.
    if (config.articles_enabled === true) {
      for (let i: number = 0; i < articles.length; i++) {
        const article: XXAuthArticle = articles[i];
        if (typeof article.content !== 'string' || article.content.indexOf('//关闭') >= 0 ||
          XXAuthPopupPolicy.text(article.content).length === 0) { continue; }
        panels.push(XXAuthPopupPolicy.contentPanel(article.id, 'article', article.title, article.content));
      }
    }
    for (let i: number = 0; i < panels.length; i++) {
      const panel: XXAuthPanel = panels[i];
      if (panel.kind !== 'recommendation') { continue; }
      if (config.popup_force !== undefined) { panel.reminderForced = config.popup_force; }
      panel.forced = config.popup_dismissible === false;
    }
    return panels;
  }

  static update(data: XXAuthVersionCheck): XXAuthPanel | undefined {
    if (data.is_latest !== false) { return undefined; }
    const panel: XXAuthPanel = new XXAuthPanel();
    panel.kind = 'update';
    panel.forced = data.force_update === true || data.update_strategy === 'force';
    if (!panel.forced && (data.update_strategy === 'none' || data.update_strategy === 'silent')) { return undefined; }
    if (typeof data.latest_version === 'string') { panel.version = data.latest_version; }
    else if (data.latest_version !== undefined && data.latest_version !== null) {
      panel.version = data.latest_version.version ?? '';
      panel.link = XXAuthPopupPolicy.https(data.latest_version.download_url);
      panel.content = XXAuthPopupPolicy.text(data.latest_version.change_log);
    }
    panel.link = XXAuthPopupPolicy.https(data.download_url) || panel.link;
    panel.content = XXAuthPopupPolicy.text(data.update_notice ?? data.change_log) || panel.content;
    panel.id = panel.version;
    panel.fingerprint = JSON.stringify([panel.version, panel.content, panel.link, panel.forced]);
    return panel.version.length > 0 ? panel : undefined;
  }
}
