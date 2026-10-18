import fs from '@ohos.file.fs';
import { common } from '@kit.AbilityKit';
import hilog from '@ohos.hilog';
import type { AppNotification, MediaAttachment, Tweet } from '../models/Tweet';
import { ArticleCardItem } from '../models/ArticleCardItem';
import { accountStore } from './AccountStore';
import { avatarTintStore } from './AvatarTintStore';
import type { AvatarTintPalette } from '../utils/AvatarTintColors';
import { isAdPost } from '../utils/PostDisclosure';

const DOMAIN = 0xFF00;
const TAG = 'HarmonyX-ArticleCardStore';
const FILE_NAME = 'article-card.json';
const MAX_ITEMS = 12;
const WIDGET_ITEMS = 6;
const SNAPSHOT_VERSION: number = 2;

export const CARD_SOURCE_FOR_YOU: string = 'for_you';
export const CARD_SOURCE_FOLLOWING: string = 'following';
export const CARD_SOURCE_TRENDS: string = 'trends';
export const CARD_SOURCE_NOTIFICATIONS: string = 'notifications';

export class ArticleCardSourceOption {
  id: string = '';
  title: Resource = $r('app.string.card_source_for_you');
  description: Resource = $r('app.string.card_source_for_you_desc');
}

class ArticleCardBucket {
  source: string = '';
  accountId: string = '';
  updatedAt: number = 0;
  revision: number = 0;
  items: ArticleCardItem[] = [];
}

class ArticleCardPayload {
  version: number = SNAPSHOT_VERSION;
  selectedSource: string = CARD_SOURCE_FOR_YOU;
  buckets: ArticleCardBucket[] = [];
}

class CardGradient {
  start: string = '';
  end: string = '';
}

export class ArticleCardStore {
  private static path(context: common.Context): string {
    return context.filesDir + '/' + FILE_NAME;
  }

  static sources(): ArticleCardSourceOption[] {
    const options: ArticleCardSourceOption[] = [];
    const forYou: ArticleCardSourceOption = new ArticleCardSourceOption();
    forYou.id = CARD_SOURCE_FOR_YOU;
    forYou.title = $r('app.string.card_source_for_you');
    forYou.description = $r('app.string.card_source_for_you_desc');
    options.push(forYou);
    const following: ArticleCardSourceOption = new ArticleCardSourceOption();
    following.id = CARD_SOURCE_FOLLOWING;
    following.title = $r('app.string.card_source_following');
    following.description = $r('app.string.card_source_following_desc');
    options.push(following);
    const trends: ArticleCardSourceOption = new ArticleCardSourceOption();
    trends.id = CARD_SOURCE_TRENDS;
    trends.title = $r('app.string.card_source_trends');
    trends.description = $r('app.string.card_source_trends_desc');
    options.push(trends);
    const notifications: ArticleCardSourceOption = new ArticleCardSourceOption();
    notifications.id = CARD_SOURCE_NOTIFICATIONS;
    notifications.title = $r('app.string.card_source_notifications');
    notifications.description = $r('app.string.card_source_notifications_desc');
    options.push(notifications);
    return options;
  }

  static validSource(source: string): boolean {
    return source === CARD_SOURCE_FOR_YOU || source === CARD_SOURCE_FOLLOWING ||
      source === CARD_SOURCE_TRENDS || source === CARD_SOURCE_NOTIFICATIONS;
  }

  private static empty(): ArticleCardPayload {
    return new ArticleCardPayload();
  }

  private static copy(item: ArticleCardItem): ArticleCardItem {
    const out: ArticleCardItem = new ArticleCardItem();
    out.kind = item.kind ?? 'post';
    out.postId = item.postId ?? '';
    out.query = item.query ?? '';
    out.title = item.title ?? '';
    out.label = item.label ?? '';
    out.mediaUrl = item.mediaUrl ?? '';
    out.mediaIsVideo = item.mediaIsVideo ?? false;
    out.avatarUrl = item.avatarUrl ?? '';
    out.gradientStart = item.gradientStart ?? '';
    out.gradientEnd = item.gradientEnd ?? '';
    out.score = item.score ?? 0;
    out.savedAt = item.savedAt ?? 0;
    return out;
  }

  private static read(context: common.Context): ArticleCardPayload {
    try {
      const path: string = ArticleCardStore.path(context);
      if (!fs.accessSync(path)) {
        return ArticleCardStore.empty();
      }
      const parsed: ArticleCardPayload = JSON.parse(fs.readTextSync(path)) as ArticleCardPayload;
      const payload: ArticleCardPayload = ArticleCardStore.empty();
      payload.selectedSource = ArticleCardStore.validSource(parsed.selectedSource) ?
        parsed.selectedSource : CARD_SOURCE_FOR_YOU;
      // Legacy previews dropped ad metadata and mixed multiple fetches by
      // popularity. They cannot be treated as a clean timeline snapshot.
      if (parsed.version !== SNAPSHOT_VERSION) {
        return payload;
      }
      const sourceBuckets: ArticleCardBucket[] = parsed.buckets ?? [];
      for (let i: number = 0; i < sourceBuckets.length; i++) {
        const source: ArticleCardBucket = sourceBuckets[i];
        if (!ArticleCardStore.validSource(source.source)) {
          continue;
        }
        const bucket: ArticleCardBucket = new ArticleCardBucket();
        bucket.source = source.source;
        bucket.accountId = source.accountId ?? '';
        bucket.updatedAt = source.updatedAt ?? 0;
        bucket.revision = source.revision ?? 0;
        const items: ArticleCardItem[] = source.items ?? [];
        for (let j: number = 0; j < items.length && bucket.items.length < MAX_ITEMS; j++) {
          const item: ArticleCardItem = items[j];
          if (item === undefined || item.title.length === 0) {
            continue;
          }
          bucket.items.push(ArticleCardStore.copy(item));
        }
        payload.buckets.push(bucket);
      }
      return payload;
    } catch (error) {
      hilog.debug(DOMAIN, TAG, 'card read failed: %{public}s', JSON.stringify(error));
      return ArticleCardStore.empty();
    }
  }

  private static write(context: common.Context, payload: ArticleCardPayload): void {
    let file: fs.File | undefined = undefined;
    const path: string = ArticleCardStore.path(context);
    const temporary: string = path + '.tmp';
    try {
      file = fs.openSync(temporary, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, JSON.stringify(payload));
      fs.closeSync(file);
      file = undefined;
      fs.renameSync(temporary, path);
    } catch (error) {
      hilog.debug(DOMAIN, TAG, 'card write failed: %{public}s', JSON.stringify(error));
      if (file !== undefined) {
        try {
          fs.closeSync(file);
        } catch (closeError) {
        }
      }
      try {
        if (fs.accessSync(temporary)) {
          fs.unlinkSync(temporary);
        }
      } catch (cleanupError) {
      }
    }
  }

  private static sameItem(left: ArticleCardItem, right: ArticleCardItem): boolean {
    if (left.kind !== right.kind) {
      return false;
    }
    if (left.postId.length > 0 || right.postId.length > 0) {
      return left.postId.length > 0 && left.postId === right.postId;
    }
    if (left.query.length > 0 || right.query.length > 0) {
      return left.query.length > 0 && left.query === right.query;
    }
    return left.title === right.title;
  }

  private static indexOf(items: ArticleCardItem[], candidate: ArticleCardItem): number {
    for (let i: number = 0; i < items.length; i++) {
      if (ArticleCardStore.sameItem(items[i], candidate)) {
        return i;
      }
    }
    return -1;
  }

  private static bucket(payload: ArticleCardPayload, context: common.Context,
    source: string): ArticleCardBucket {
    const accountId: string = accountStore.activeId(context);
    for (let i: number = 0; i < payload.buckets.length; i++) {
      if (payload.buckets[i].source === source && payload.buckets[i].accountId === accountId) {
        return payload.buckets[i];
      }
    }
    const bucket: ArticleCardBucket = new ArticleCardBucket();
    bucket.source = source;
    bucket.accountId = accountId;
    payload.buckets.push(bucket);
    return bucket;
  }

  static selectedSource(context: common.Context): string {
    return ArticleCardStore.read(context).selectedSource;
  }

  static setSource(context: common.Context, source: string): boolean {
    if (!ArticleCardStore.validSource(source)) {
      return false;
    }
    const payload: ArticleCardPayload = ArticleCardStore.read(context);
    if (payload.selectedSource === source) {
      return true;
    }
    payload.selectedSource = source;
    ArticleCardStore.write(context, payload);
    return true;
  }

  static hasSnapshot(context: common.Context, source: string): boolean {
    const payload: ArticleCardPayload = ArticleCardStore.read(context);
    const accountId: string = accountStore.activeId(context);
    return payload.buckets.some((bucket: ArticleCardBucket): boolean =>
      bucket.source === source && bucket.accountId === accountId);
  }

  private static sameContent(left: ArticleCardItem, right: ArticleCardItem): boolean {
    return ArticleCardStore.sameItem(left, right) && left.title === right.title && left.label === right.label &&
      left.mediaUrl === right.mediaUrl && left.mediaIsVideo === right.mediaIsVideo && left.avatarUrl === right.avatarUrl;
  }

  private static rememberItems(context: common.Context, source: string, items: ArticleCardItem[]): boolean {
    if (!ArticleCardStore.validSource(source)) {
      return false;
    }
    const payload: ArticleCardPayload = ArticleCardStore.read(context);
    const bucket: ArticleCardBucket = ArticleCardStore.bucket(payload, context, source);
    const next: ArticleCardItem[] = [];
    for (let i: number = 0; i < items.length && next.length < MAX_ITEMS; i++) {
      if (ArticleCardStore.indexOf(next, items[i]) < 0) {
        next.push(ArticleCardStore.copy(items[i]));
      }
    }
    let changed: boolean = bucket.items.length !== next.length || bucket.revision === 0;
    for (let i: number = 0; !changed && i < next.length; i++) {
      changed = !ArticleCardStore.sameContent(bucket.items[i], next[i]);
    }
    if (changed) {
      bucket.items = next;
      bucket.updatedAt = Date.now();
      bucket.revision++;
      ArticleCardStore.write(context, payload);
    }
    return changed;
  }

  private static excerpt(value: string): string {
    let text: string = value.replace(/\s+/g, ' ').trim();
    if (text.length > 150) {
      text = text.substring(0, 150) + '…';
    }
    return text;
  }

  private static gradientFor(seed: string): CardGradient {
    const pairs: string[][] = [
      ['#0B4F8A', '#12314F'],
      ['#5B2A86', '#24123F'],
      ['#0C6B63', '#0A2E35'],
      ['#8A4B12', '#35200C'],
      ['#8A2450', '#330D20'],
      ['#355E2B', '#152B12'],
      ['#334A8A', '#141B36'],
      ['#455A6B', '#1A242E']
    ];
    let hash: number = 0;
    for (let i: number = 0; i < seed.length; i++) {
      hash = (hash * 31 + seed.charCodeAt(i)) >>> 0;
    }
    const pair: string[] = pairs[hash % pairs.length];
    const out: CardGradient = new CardGradient();
    out.start = pair[0];
    out.end = pair[1];
    return out;
  }

  private static mediaOf(tweet: Tweet): MediaAttachment | undefined {
    const attachments: MediaAttachment[] = tweet.attachments ?? [];
    for (let i: number = 0; i < attachments.length; i++) {
      const media: MediaAttachment = attachments[i];
      if (media.previewUrl.length > 0 && media.sensitive !== true) {
        return media;
      }
    }
    return undefined;
  }

  static rememberTweets(context: common.Context, source: string, tweets: Tweet[]): boolean {
    if (source !== CARD_SOURCE_FOR_YOU && source !== CARD_SOURCE_FOLLOWING) {
      return false;
    }
    const items: ArticleCardItem[] = [];
    for (let i: number = 0; i < tweets.length; i++) {
      const tweet: Tweet = tweets[i];
      if (isAdPost(tweet.presentation) || tweet.id.startsWith('promotion-') ||
        tweet.author.id === 'xxauth-promotion' || tweet.presentation?.visibility?.hidden === true) {
        continue;
      }
      let text: string = ArticleCardStore.excerpt(tweet.text);
      if (text.length === 0 && tweet.article !== undefined) {
        text = ArticleCardStore.excerpt(tweet.article.title);
      }
      if (tweet.id.length === 0 || text.length === 0) {
        continue;
      }
      const item: ArticleCardItem = new ArticleCardItem();
      item.kind = 'post';
      item.postId = tweet.id;
      item.title = text;
      item.label = tweet.author.username.length > 0 ? '@' + tweet.author.username : tweet.author.name;
      const media: MediaAttachment | undefined = ArticleCardStore.mediaOf(tweet);
      if (media !== undefined) {
        item.mediaUrl = media.type === 'photo' && media.mediaUrl.length > 0 ? media.mediaUrl : media.previewUrl;
        item.mediaIsVideo = media.type === 'video' || media.type === 'animated_gif';
      } else if (tweet.article !== undefined && tweet.article.coverUrl.length > 0) {
        item.mediaUrl = tweet.article.coverUrl;
      }
      item.avatarUrl = tweet.author.avatarUrl ?? '';
      const gradient: CardGradient = ArticleCardStore.gradientFor(tweet.author.username + '|' + tweet.id);
      item.gradientStart = gradient.start;
      item.gradientEnd = gradient.end;
      item.score = tweet.metrics.likeCount + tweet.metrics.repostCount + tweet.metrics.replyCount;
      item.savedAt = Date.now();
      items.push(item);
    }
    return ArticleCardStore.rememberItems(context, source, items);
  }

  static rememberTrends(context: common.Context, trends: string[]): boolean {
    const items: ArticleCardItem[] = [];
    for (let i: number = 0; i < trends.length; i++) {
      const text: string = trends[i].trim();
      if (text.length === 0) {
        continue;
      }
      const item: ArticleCardItem = new ArticleCardItem();
      item.kind = 'trend';
      item.query = text;
      item.title = text;
      item.label = '';
      const gradient: CardGradient = ArticleCardStore.gradientFor('trend|' + text);
      item.gradientStart = gradient.start;
      item.gradientEnd = gradient.end;
      item.score = 1000 - i;
      item.savedAt = Date.now() - i;
      items.push(item);
    }
    return ArticleCardStore.rememberItems(context, CARD_SOURCE_TRENDS, items);
  }

  static rememberNotifications(context: common.Context, notifications: AppNotification[]): boolean {
    const items: ArticleCardItem[] = [];
    for (let i: number = 0; i < notifications.length; i++) {
      const notification: AppNotification = notifications[i];
      const text: string = ArticleCardStore.excerpt(notification.text.length > 0 ? notification.text :
        notification.postText);
      if (text.length === 0) {
        continue;
      }
      const item: ArticleCardItem = new ArticleCardItem();
      item.kind = 'notification';
      item.postId = notification.targetPostId;
      item.title = text;
      item.label = notification.authorUsername.length > 0 ? '@' + notification.authorUsername :
        notification.time;
      item.avatarUrl = notification.authorAvatarUrl;
      const gradient: CardGradient = ArticleCardStore.gradientFor(notification.authorUsername + '|' + text);
      item.gradientStart = gradient.start;
      item.gradientEnd = gradient.end;
      item.score = 0;
      item.savedAt = notification.timestampMs > 0 ? notification.timestampMs : Date.now() - i;
      items.push(item);
    }
    return ArticleCardStore.rememberItems(context, CARD_SOURCE_NOTIFICATIONS, items);
  }

  // Avatar colors are extracted lazily so reading the timeline never waits on
  // a download. The fallback gradient is already visible; this pass refines
  // the first few cards and republishes them once the palette is known.
  static async refineAvatarGradients(context: common.UIAbilityContext, source: string): Promise<boolean> {
    const payload: ArticleCardPayload = ArticleCardStore.read(context);
    const accountId: string = accountStore.activeId(context);
    let bucket: ArticleCardBucket | null = null;
    for (let i: number = 0; i < payload.buckets.length; i++) {
      if (payload.buckets[i].source === source && payload.buckets[i].accountId === accountId) {
        bucket = payload.buckets[i];
        break;
      }
    }
    if (bucket === null) {
      return false;
    }
    let changed: boolean = false;
    const limit: number = Math.min(bucket.items.length, WIDGET_ITEMS);
    for (let i: number = 0; i < limit; i++) {
      const item: ArticleCardItem = bucket.items[i];
      if (item.avatarUrl.length === 0) {
        continue;
      }
      const palette: AvatarTintPalette | null = await avatarTintStore.load(context, item.avatarUrl);
      if (palette === null || palette.dark.length === 0) {
        continue;
      }
      if (item.gradientStart !== palette.dark || item.gradientEnd !== palette.light) {
        item.gradientStart = palette.dark;
        item.gradientEnd = palette.light;
        changed = true;
      }
    }
    if (changed) {
      // Palette downloads can finish after the feed, account or source changes.
      // Never write the old payload over a newer timeline/source selection.
      if (accountStore.activeId(context) !== accountId) { return false; }
      const latest: ArticleCardPayload = ArticleCardStore.read(context);
      for (let i: number = 0; i < latest.buckets.length; i++) {
        const current: ArticleCardBucket = latest.buckets[i];
        if (current.source === source && current.accountId === accountId) {
          if (current.revision !== bucket.revision) { return false; }
          current.items = bucket.items;
          ArticleCardStore.write(context, latest);
          return true;
        }
      }
      return false;
    }
    return changed;
  }

  static loadForWidget(context: common.Context): ArticleCardItem[] {
    const payload: ArticleCardPayload = ArticleCardStore.read(context);
    const source: string = payload.selectedSource;
    const accountId: string = accountStore.activeId(context);
    for (let i: number = 0; i < payload.buckets.length; i++) {
      const bucket: ArticleCardBucket = payload.buckets[i];
      if (bucket.source !== source || bucket.accountId !== accountId) {
        continue;
      }
      const out: ArticleCardItem[] = [];
      for (let j: number = 0; j < bucket.items.length && out.length < WIDGET_ITEMS; j++) {
        out.push(ArticleCardStore.copy(bucket.items[j]));
      }
      return out;
    }
    return [];
  }

  static findPost(context: common.Context, postId: string): ArticleCardItem | null {
    const payload: ArticleCardPayload = ArticleCardStore.read(context);
    const accountId: string = accountStore.activeId(context);
    for (let i: number = 0; i < payload.buckets.length; i++) {
      const bucket: ArticleCardBucket = payload.buckets[i];
      if (bucket.accountId !== accountId) { continue; }
      for (let j: number = 0; j < bucket.items.length; j++) {
        if (bucket.items[j].postId === postId) {
          return ArticleCardStore.copy(bucket.items[j]);
        }
      }
    }
    return null;
  }
}
