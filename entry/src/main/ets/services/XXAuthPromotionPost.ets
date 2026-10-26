import { XXAuthAnnouncement, XXAuthPopupConfig } from '../models/XXAuth';
import { XXAuthRecommendationApp, XXAuthRecommendationCatalog } from './XXAuthRecommendationCatalog';
import { XXAUTH_CONTROL_PRIORITY_MAX, XXAUTH_CONTROL_PRIORITY_MIN,
  XXAuthPopupPolicy } from './XXAuthPopupPolicy';

// Priority slots reserved for the promotion controls. Records in this range are
// configuration, never user-facing announcements.
export const XXAUTH_PROMOTION_PRIORITY_MIN: number = XXAUTH_CONTROL_PRIORITY_MIN;
export const XXAUTH_PROMOTION_PRIORITY_MAX: number = XXAUTH_CONTROL_PRIORITY_MAX;
const INFO_PRIORITY: number = 15;
const MEDIA_PRIORITY: number = 16;
const ICON_PRIORITY: number = 12;
const STORE_PRIORITY: number = 13;
const MEDIA_LIMIT: number = 6;

export class XXAuthPromotionMedia {
  url: string = '';
  video: boolean = false;
  // Poster frame for a video, so the tile shows a still before playback.
  poster: string = '';
  // Encoded size when the source advertises it, so a landscape clip is not laid
  // out like the portrait screenshots.
  width: number = 0;
  height: number = 0;
  durationMs: number = 0;
}

// A recommendation rendered as a native-looking timeline post. Everything the
// card shows comes from the remote records, so nothing needs a new release.
export class XXAuthPromotionPost {
  dismissible: boolean = true;
  appId: string = '';
  name: string = '';
  handle: string = '';
  verified: boolean = true;
  content: string = '';
  avatarUrl: string = '';
  media: XXAuthPromotionMedia[] = [];
  // Tablet artwork, used when the reader is on a large-screen device and the
  // record supplies it; falls back to the phone set otherwise.
  mediaPad: XXAuthPromotionMedia[] = [];
  link: string = '';
  fingerprint: string = '';
}

// How many promotions each surface should carry, resolved once per refresh so
// every reader of the published plan agrees on the numbers.
export class XXAuthPromotionPlan {
  dismissible: boolean = true;
  posts: XXAuthPromotionPost[] = [];
  timelineCount: number = 2;
  commentCount: number = 1;
  commentProbability: number = 0.3;
  revision: number = 0;
}

export class XXAuthPromotionPostPolicy {
  static isControl(item: XXAuthAnnouncement): boolean {
    return XXAuthPopupPolicy.isControlRecord(item);
  }

  private static latest(items: XXAuthAnnouncement[], priority: number): XXAuthAnnouncement | null {
    let selected: XXAuthAnnouncement | null = null;
    let selectedTime: number = -1;
    for (let i: number = 0; i < items.length; i++) {
      const item: XXAuthAnnouncement = items[i];
      if (!item || item.priority !== priority) { continue; }
      if (item.status !== undefined && item.status !== 1) { continue; }
      if (typeof item.content !== 'string' || item.content.trim().length === 0) { continue; }
      const time: number = Date.parse(item.updated_at || item.created_at || '') || 0;
      if (selected === null || time >= selectedTime) { selected = item; selectedTime = time; }
    }
    return selected;
  }

  private static fields(content: string): Map<string, string> {
    const values: Map<string, string> = new Map();
    let section: string = '';
    const lines: string[] = content.replace(/\r\n?/g, '\n').split('\n');
    for (let i: number = 0; i < lines.length; i++) {
      const line: string = lines[i];
      const field: RegExpMatchArray | null = line.trim().match(
        /^(帖子昵称|帖子账号|帖子认证|帖子头像|帖子正文|帖子媒体|帖子媒体平板|帖子链接|帖子开关)\s*[:：]\s*(.*)$/);
      if (field !== null) {
        section = field[1];
        values.set(section, field[2]);
        continue;
      }
      // Continuation lines belong to the last section, so a multi-line body and
      // its // markers survive without a dedicated syntax.
      if (section.length > 0) {
        const current: string = values.get(section) ?? '';
        values.set(section, current + '\n' + line);
      }
    }
    return values;
  }

  private static media(items: XXAuthAnnouncement[]): XXAuthPromotionMedia[] {
    const record: XXAuthAnnouncement | null = XXAuthPromotionPostPolicy.latest(items, MEDIA_PRIORITY);
    return record === null ? [] : XXAuthPromotionPostPolicy.mediaFromText(record.content);
  }

  private static mediaFromText(content: string): XXAuthPromotionMedia[] {
    const rows: XXAuthPromotionMedia[] = [];
    if (content.indexOf('//关闭') >= 0) { return rows; }
    const lines: string[] = content.replace(/\r\n?/g, '\n').split('\n');
    for (let i: number = 0; i < lines.length && rows.length < MEDIA_LIMIT; i++) {
      // One line is either an image, or `video|poster|seconds` for a video.
      const parts: string[] = lines[i].trim().split('|');
      const url: string = parts[0].trim();
      if (!/^https:\/\/[^\s]+$/.test(url)) { continue; }
      const media: XXAuthPromotionMedia = new XXAuthPromotionMedia();
      media.url = url;
      media.video = /\.(mp4|m3u8|webm|mov)(\?|#|$)/i.test(url);
      const poster: string = parts.length > 1 ? parts[1].trim() : '';
      media.poster = media.video && /^https:\/\/[^\s]+$/.test(poster) ? poster : '';
      // `url|poster|seconds` carries the clip length for the card badge.
      const seconds: number = parts.length > 2 ? Number.parseInt(parts[2].trim(), 10) : 0;
      media.durationMs = Number.isFinite(seconds) && seconds > 0 ? seconds * 1000 : 0;
      if (media.video) {
        const size: RegExpMatchArray | null = url.match(/(\d{3,4})x(\d{3,4})/);
        if (size !== null) {
          media.width = Number.parseInt(size[1], 10);
          media.height = Number.parseInt(size[2], 10);
        }
      }
      rows.push(media);
    }
    return rows;
  }

  // Every published info record becomes one promotion post, newest first, so a
  // developer can mix several recommendations into the same feed.
  private static records(items: XXAuthAnnouncement[]): XXAuthAnnouncement[] {
    const found: XXAuthAnnouncement[] = [];
    for (let i: number = 0; i < items.length; i++) {
      const item: XXAuthAnnouncement = items[i];
      if (!item || item.priority !== INFO_PRIORITY) { continue; }
      if (item.status !== undefined && item.status !== 1) { continue; }
      if (typeof item.content !== 'string' || item.content.trim().length === 0) { continue; }
      found.push(item);
    }
    found.sort((left: XXAuthAnnouncement, right: XXAuthAnnouncement): number =>
      (Date.parse(right.updated_at || right.created_at || '') || 0) -
      (Date.parse(left.updated_at || left.created_at || '') || 0));
    return found;
  }

  private static build(record: XXAuthAnnouncement, shared: XXAuthPromotionMedia[],
    iconUrl: string, link: string): XXAuthPromotionPost | null {
    const values: Map<string, string> = XXAuthPromotionPostPolicy.fields(record.content);
    const post: XXAuthPromotionPost = new XXAuthPromotionPost();
    post.name = XXAuthPopupPolicy.text(values.get('帖子昵称') ?? '');
    post.handle = XXAuthPopupPolicy.text(values.get('帖子账号') ?? '');
    post.content = XXAuthPopupPolicy.text(values.get('帖子正文') ?? '');
    const avatar: string = XXAuthPopupPolicy.https(values.get('帖子头像'));
    post.avatarUrl = avatar.length > 0 ? avatar : XXAuthPopupPolicy.https(iconUrl);
    post.link = link;
    const verified: string = (values.get('帖子认证') ?? '').trim();
    post.verified = !/^(无|否|不认证|false|no)$/i.test(verified);
    // A record may carry its own store link so several promoted apps never
    // share one fallback target.
    const own_link: string = XXAuthPopupPolicy.https(values.get('帖子链接'));
    if (own_link.length > 0) { post.link = own_link; }
    const own: XXAuthPromotionMedia[] = XXAuthPromotionPostPolicy.mediaFromText(values.get('帖子媒体') ?? '');
    post.media = own.length > 0 ? own : shared;
    post.mediaPad = XXAuthPromotionPostPolicy.mediaFromText(values.get('帖子媒体平板') ?? '');
    if (post.name.length === 0 || post.content.length === 0) { return null; }
    post.fingerprint = JSON.stringify([post.name, post.handle, post.verified, post.content,
      post.avatarUrl, post.link, post.media.map((item: XXAuthPromotionMedia): string => item.url),
      post.mediaPad.map((item: XXAuthPromotionMedia): string => item.url)]);
    return post;
  }

  // Returns the posts to inject, or an empty list when the remote configuration
  // is closed, switched off, or carries no usable record.
  static posts(items: XXAuthAnnouncement[], config: XXAuthPopupConfig): XXAuthPromotionPost[] {
    const result: XXAuthPromotionPost[] = [];
    // `promotion_enabled` is the recommendation switch; the per-channel keys
    // only exist so a special run can show one channel without the other.
    if (config.enabled === false || config.post_enabled === false) { return result; }
    if (config.promotion_enabled === false && config.post_enabled !== true) { return result; }
    if (config.post_enabled !== true && config.recommendation_enabled === false) { return result; }
    if (XXAuthRecommendationCatalog.present(items)) {
      const apps: XXAuthRecommendationApp[] = XXAuthRecommendationCatalog.apps(items);
      for (let i: number = 0; i < apps.length; i++) {
        const app: XXAuthRecommendationApp = apps[i];
        if (!app.enabled || !app.postEnabled) { continue; }
        const post: XXAuthPromotionPost | null = XXAuthPromotionPostPolicy.build(app.post, [], app.iconUrl, app.link);
        if (post !== null) { post.appId = app.id; result.push(post); }
      }
      return result;
    }
    const shared: XXAuthPromotionMedia[] = XXAuthPromotionPostPolicy.media(items);
    const icon: XXAuthAnnouncement | null = XXAuthPromotionPostPolicy.latest(items, ICON_PRIORITY);
    const store: XXAuthAnnouncement | null = XXAuthPromotionPostPolicy.latest(items, STORE_PRIORITY);
    let link: string = store === null ? '' : XXAuthPopupPolicy.text(store.content);
    if (!/^https?:\/\/[^\s]+$/.test(link)) { link = ''; }
    const records: XXAuthAnnouncement[] = XXAuthPromotionPostPolicy.records(items);
    for (let i: number = 0; i < records.length; i++) {
      const record: XXAuthAnnouncement = records[i];
      if (record.content.indexOf('//关闭') >= 0) { continue; }
      // Per-record switch, so one promoted app can be paused without touching
      // the others or the global post_enabled flag.
      const values: Map<string, string> = XXAuthPromotionPostPolicy.fields(record.content);
      if (/^(关|关闭|停|停用|否|off|false|no|0)$/i.test((values.get('帖子开关') ?? '').trim())) { continue; }
      const post: XXAuthPromotionPost | null = XXAuthPromotionPostPolicy.build(record, shared,
        icon === null ? '' : icon.content, link);
      if (post !== null) { result.push(post); }
    }
    return result;
  }

  static post(items: XXAuthAnnouncement[], config: XXAuthPopupConfig): XXAuthPromotionPost | null {
    const list: XXAuthPromotionPost[] = XXAuthPromotionPostPolicy.posts(items, config);
    return list.length > 0 ? list[0] : null;
  }

  private static count(value: number | undefined, fallback: number, max: number): number {
    if (typeof value !== 'number' || !Number.isFinite(value)) { return fallback; }
    return Math.max(0, Math.min(max, Math.floor(value)));
  }

  static plan(items: XXAuthAnnouncement[], config: XXAuthPopupConfig): XXAuthPromotionPlan {
    const plan: XXAuthPromotionPlan = new XXAuthPromotionPlan();
    plan.posts = XXAuthPromotionPostPolicy.posts(items, config);
    plan.dismissible = config.post_dismissible !== false;
    for (let i: number = 0; i < plan.posts.length; i++) { plan.posts[i].dismissible = plan.dismissible; }
    // One promotion per timeline: several rows in the same feed read as a block
    // of advertising instead of a single native-looking post.
    plan.timelineCount = XXAuthPromotionPostPolicy.count(config.post_count, 1, 1);
    plan.commentCount = XXAuthPromotionPostPolicy.count(config.post_comment_count, 1, 2);
    const probability: number | undefined = config.post_comment_probability;
    plan.commentProbability = typeof probability === 'number' && Number.isFinite(probability) ?
      Math.max(0, Math.min(1, probability)) : 0.3;
    plan.revision = XXAuthPromotionPostPolicy.count(config.post_revision, 0, 1000000);
    if (plan.posts.length === 0) { plan.timelineCount = 0; plan.commentCount = 0; }
    return plan;
  }
}
