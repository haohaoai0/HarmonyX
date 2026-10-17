import { userIsVerified, userVerifiedType, userAvatarShape, normalizedVerifiedType } from '../utils/UserIdentity';
// Decodes NotificationTimelineQuery, whose entries carry notification items
// rather than plain posts:
//
//   data.<timeline>.instructions[].entries[]      TimelineTimelineEntry
//     .entryId
//     .content.itemContent                        TimelineTimelineItem
//       .__typename            "TimelineNotification"
//       .icon                  "heart" | "person" | "repeat" | ...
//       .rich_message.text     rendered copy, when X supplies it
//       .target_tweets_results the post the notification is about
//       .template.from_users[] the accounts that triggered it
//       .timestamp_ms          epoch milliseconds
//     .content                 TimelineTimelineCursor (paging token)
//
// X mixes snake_case and camelCase inside the same payload, and the wrappers
// move between schema revisions, so every field is read through a key list.
// Anything missing degrades the row instead of dropping it, and paging only
// depends on the Bottom cursor when one is present.
import hilog from '@ohos.hilog';
import type { AppNotification, MediaAttachment, Tweet, TweetAuthor } from '../models/Tweet';
import type { TweetPage } from './XApiClient';
import { XTimelineParser } from './XTimelineParser';

const DOMAIN = 0xFF00;
const TAG = 'HarmonyX-Notify';
// A timestamp below this is seconds, not milliseconds (both have been seen).
const SECONDS_CUTOFF = 100000000000;

export interface XNotificationPage {
  items: AppNotification[];
  // Bottom cursor of this page, '' when X returned no continuation.
  cursor: string;
  // Top cursor, which is what the "mark notifications seen" call takes.
  topCursor: string;
  // Entries sorting after this instant are still unread; 0 when the page
  // declares no unread boundary.
  unreadSince: number;
}

export class XNotificationParser {
  static parseMentions(body: string): XNotificationPage | null {
    const page: TweetPage | null = XTimelineParser.parseDeviceFollow(body);
    if (page === null) { return null; }
    return { items: page.tweets.map((tweet: Tweet): AppNotification =>
      XNotificationParser.tweetNotification(tweet, 'mention-' + tweet.id)),
      cursor: page.nextToken, topCursor: page.topToken ?? '', unreadSince: 0 };
  }

  // Replies and mentions are tweet entries in both the web and Android
  // timelines. They do not have a TimelineNotification icon/template wrapper.
  private static tweetNotification(tweet: Tweet, id: string): AppNotification {
    const parsedTime: number = Date.parse(tweet.createdAt);
    const timestamp: number = Number.isFinite(parsedTime) ? parsedTime : 0;
    const media: MediaAttachment | undefined = tweet.attachments?.[0];
    return { id: id, kind: tweet.isReply ? 'reply' : 'mention',
      text: (tweet.author.name || '@' + tweet.author.username) + ' · ' + tweet.text,
      postText: tweet.text, time: XNotificationParser.relativeTime(timestamp), timestampMs: timestamp,
      targetPostId: tweet.id, authorId: tweet.author.id, authorName: tweet.author.name,
      authorUsername: tweet.author.username, authorAvatarUrl: tweet.author.avatarUrl ?? '',
      authorVerifiedType: tweet.author.verifiedType, authorAvatarShape: tweet.author.avatarShape,
      fromVerifiedAccount: tweet.author.verified, imageUrl: media?.previewUrl ?? '',
      imageIsVideo: media?.type === 'video' || media?.type === 'animated_gif', unread: false,
      deepLink: 'https://x.com/' + tweet.author.username + '/status/' + tweet.id, targetPosts: [tweet] };
  }
  static parse(body: string): AppNotification[] | null {
    const page: XNotificationPage | null = XNotificationParser.parsePage(body);
    return page === null ? null : page.items;
  }

  // Rows plus the Bottom cursor, which is what the caller needs for the next
  // page. Returns null only when the body is not a timeline at all.
  static parsePage(body: string): XNotificationPage | null {
    try {
      const json: Record<string, Object> = JSON.parse(body) as Record<string, Object>;
      const data: Record<string, Object> = XNotificationParser.obj(json, 'data');
      const timeline: Record<string, Object> = XNotificationParser.findInstructions(data, 0);
      if (Object.keys(timeline).length === 0) {
        hilog.warn(DOMAIN, TAG, 'notification timeline not found');
        return null;
      }
      const items: AppNotification[] = [];
      let cursor: string = '';
      let topCursor: string = '';
      let unreadSince: number = 0;
      const instructions: Array<Record<string, Object>> = XNotificationParser.arr(timeline, 'instructions');
      for (let i: number = 0; i < instructions.length; i++) {
        // X flags unread rows with a single instruction rather than a field on
        // each notification: everything sorting after it is unread.
        const instructionType: string = XNotificationParser.str(instructions[i],
          ['__typename', 'type', 'entryType']);
        if (instructionType === 'TimelineMarkEntriesUnreadGreaterThanSortIndex') {
          unreadSince = XNotificationParser.normaliseTime(
            Number(XNotificationParser.str(instructions[i], ['sortIndex', 'sort_index'])));
          continue;
        }
        const entries: Array<Record<string, Object>> = XNotificationParser.arr(instructions[i], 'entries');
        for (let e: number = 0; e < entries.length; e++) {
          const direction: string = XNotificationParser.cursorDirection(entries[e]);
          if (direction !== '') {
            const value: string = XNotificationParser.cursorPayload(entries[e]);
            if (direction === 'bottom') {
              cursor = value;
            } else if (direction === 'top') {
              topCursor = value;
            }
            continue;
          }
          const row: AppNotification | null =
            XNotificationParser.entryToNotification(entries[e], items.length);
          if (row !== null) {
            items.push(row);
          }
        }
      }
      if (items.length === 0) {
        // Shape-drift fallback: collect every notification object wherever the
        // payload nests it.
        XNotificationParser.harvest(json, items, 0);
      }
      let unread: number = 0;
      for (let i: number = 0; i < items.length; i++) {
        items[i].unread = unreadSince > 0 && items[i].timestampMs > unreadSince;
        if (items[i].unread) {
          unread += 1;
        }
      }
      // unreadSince=0 means the page declared no unread boundary at all, which
      // is different from "nothing new".
      hilog.info(DOMAIN, TAG,
        'decoded %{public}d notifications, more=%{public}s, unread=%{public}d, boundary=%{public}s',
        items.length, cursor.length > 0 ? 'yes' : 'no', unread,
        unreadSince > 0 ? 'set' : 'none');
      return { items: items, cursor: cursor, topCursor: topCursor, unreadSince: unreadSince };
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'parse failed: %{public}s', JSON.stringify(e));
      return null;
    }
  }

  // "1h" / "3d" style label, matching the sample rows and X's own list. Entries
  // older than a week fall back to a date.
  static relativeTime(ms: number): string {
    if (ms <= 0) {
      return '';
    }
    const elapsed: number = Date.now() - ms;
    if (elapsed < 0) {
      return '';
    }
    const minutes: number = Math.floor(elapsed / 60000);
    if (minutes < 1) {
      return 'now';
    }
    if (minutes < 60) {
      return minutes.toString() + 'm';
    }
    const hours: number = Math.floor(minutes / 60);
    if (hours < 24) {
      return hours.toString() + 'h';
    }
    const days: number = Math.floor(hours / 24);
    if (days < 7) {
      return days.toString() + 'd';
    }
    const date: Date = new Date(ms);
    const month: number = date.getMonth() + 1;
    const day: number = date.getDate();
    return date.getFullYear().toString() + '-' +
      (month < 10 ? '0' + month.toString() : month.toString()) + '-' +
      (day < 10 ? '0' + day.toString() : day.toString());
  }

  private static entryToNotification(entry: Record<string, Object>,
    index: number): AppNotification | null {
    const item: Record<string, Object> = XNotificationParser.notificationNode(entry);
    if (Object.keys(item).length === 0) {
      const content: Record<string, Object> = XNotificationParser.obj(entry, 'content');
      const inner: Record<string, Object> = XNotificationParser.objKey(content, ['itemContent', 'content']);
      const entryId: string = XNotificationParser.str(entry, ['entryId', 'entry_id']);
      const tweet: Tweet | null = XTimelineParser.parseTweetItemContent(
        Object.keys(inner).length > 0 ? inner : content, entryId);
      if (tweet !== null) { return XNotificationParser.tweetNotification(tweet, entryId || 'mention-' + tweet.id); }
      return null;
    }
    const entryId: string = XNotificationParser.str(entry, ['entryId', 'entry_id']);
    const itemId: string = XNotificationParser.str(item, ['id']);
    let id: string = entryId;
    if (id.length === 0) {
      id = itemId;
    }
    if (id.length === 0) {
      id = 'notification-' + index;
    }
    return XNotificationParser.buildRow(item, id, XNotificationParser.sortIndexOf(entry));
  }

  // The notification item sits one wrapper below the entry in current
  // payloads, but the flat schema puts it directly on `content`.
  private static notificationNode(entry: Record<string, Object>): Record<string, Object> {
    const content: Record<string, Object> = XNotificationParser.obj(entry, 'content');
    if (Object.keys(content).length === 0) {
      return {};
    }
    const inner: Record<string, Object> = XNotificationParser.objKey(content, ['itemContent', 'content']);
    if (XNotificationParser.isNotification(inner)) {
      return inner;
    }
    if (XNotificationParser.isNotification(content)) {
      return content;
    }
    return {};
  }

  private static isNotification(node: Record<string, Object>): boolean {
    if (Object.keys(node).length === 0) {
      return false;
    }
    const type: string = XNotificationParser.str(node, ['__typename', 'itemType', 'entryType']);
    return type === 'TimelineNotification';
  }

  private static buildRow(item: Record<string, Object>, id: string,
    fallbackMs: number): AppNotification | null {
    const actor: Record<string, Object> = XNotificationParser.actorNode(item);
    const name: string = XNotificationParser.actorName(actor);
    const handle: string = XNotificationParser.actorHandle(actor);
    const parts: string[] = [];
    const message: string = XNotificationParser.messageText(item);
    if (message.length > 0) {
      // X's rendered copy already names the actor, so the row leads with it and
      // only falls back to the account when there is no sentence.
      parts.push(message);
    } else {
      const display: string = name.length > 0 ? name :
        (handle.length > 0 ? '@' + handle : '');
      if (display.length > 0) {
        parts.push(display);
      }
    }
    const postText: string = XNotificationParser.postText(item);
    if (postText.length > 0) {
      parts.push(postText);
    }
    if (parts.length === 0) {
      return null;
    }
    const timestampMs: number = XNotificationParser.timestampOf(item, fallbackMs);
    const media: Record<string, Object> = XNotificationParser.mediaNodeOf(item);
    const targets: Array<Record<string, Object>> = XNotificationParser.arrKey(item,
      ['target_tweets_results', 'targetTweetsResults']);
    if (targets.length === 0) {
      const target: Record<string, Object> = XNotificationParser.postResults(item);
      if (Object.keys(target).length > 0) { targets.push(target); }
    }
    const targetPosts: Tweet[] = XTimelineParser.parseNotificationPosts(targets);
    return {
      id: id,
      kind: XNotificationParser.kindOf(XNotificationParser.str(item, ['icon', 'notification_icon'])),
      text: parts.join(' · '),
      actionText: message.length > 0 ? message : (name || '@' + handle),
      actors: XNotificationParser.actors(item, actor),
      time: XNotificationParser.relativeTime(timestampMs),
      timestampMs: timestampMs,
      targetPostId: XNotificationParser.postId(item),
      postText: postText,
      authorId: XNotificationParser.str(actor, ['rest_id', 'restId']),
      authorName: name,
      authorUsername: handle,
      authorAvatarUrl: XNotificationParser.actorAvatar(actor),
      authorVerifiedType: userVerifiedType(actor), authorAvatarShape: userAvatarShape(actor),
      fromVerifiedAccount: XNotificationParser.hasVerifiedActor(item, actor),
      imageUrl: XNotificationParser.mediaUrlOf(media),
      imageIsVideo: XNotificationParser.mediaIsVideo(media),
      // Filled in once the whole timeline is read: the unread boundary is an
      // instruction, not a field on the row.
      unread: false,
      deepLink: XNotificationParser.deepLink(item),
      targetPosts: targetPosts
    };
  }

  // Depth-first scan for notification items, used when the strict walk finds
  // nothing because the wrapper names changed.
  private static harvest(node: Object, out: AppNotification[], depth: number): void {
    if (depth > 16 || out.length >= 200) {
      return;
    }
    if (node === null || node === undefined) {
      return;
    }
    if (node instanceof Array) {
      const items: Array<Object> = node as Array<Object>;
      for (let i: number = 0; i < items.length; i++) {
        XNotificationParser.harvest(items[i], out, depth + 1);
      }
      return;
    }
    if (typeof node !== 'object') {
      return;
    }
    const record: Record<string, Object> = node as Record<string, Object>;
    if (XNotificationParser.isNotification(record)) {
      const row: AppNotification | null =
        XNotificationParser.buildRow(record, 'notification-' + out.length, 0);
      if (row !== null) {
        out.push(row);
        return;
      }
    }
    const keys: string[] = Object.keys(record);
    for (let i: number = 0; i < keys.length; i++) {
      XNotificationParser.harvest(record[keys[i]], out, depth + 1);
    }
  }

  // X names the action; the UI only needs a stable token.
  private static kindOf(icon: string): string {
    const token: string = icon.toLowerCase();
    if (token.indexOf('heart') >= 0 || token === 'like') {
      return 'like';
    }
    if (token.indexOf('repeat') >= 0 || token.indexOf('retweet') >= 0) {
      return 'repost';
    }
    if (token.indexOf('recommend') >= 0 || token.indexOf('trend') >= 0) {
      return 'recommendation';
    }
    if (token.indexOf('security') >= 0 || token.indexOf('shield') >= 0) {
      return 'security';
    }
    if (token.indexOf('person') >= 0 || token.indexOf('follow') >= 0) {
      return 'follow';
    }
    if (token.indexOf('reply') >= 0) {
      return 'reply';
    }
    if (token.indexOf('mention') >= 0 || token === 'at') {
      return 'mention';
    }
    if (token.indexOf('bell') >= 0 || token.indexOf('alert') >= 0) {
      return 'alert';
    }
    return 'default';
  }

  // `message` is the pre-rendered copy X shows in its own list; rich_message and
  // social_context are the structured variants of the same sentence.
  private static messageText(item: Record<string, Object>): string {
    const rich: string = XNotificationParser.str(
      XNotificationParser.objKey(item, ['rich_message', 'richMessage']), ['text']);
    if (rich.length > 0) {
      return rich;
    }
    const social: string = XNotificationParser.str(
      XNotificationParser.objKey(item, ['social_context', 'socialContext']), ['text']);
    if (social.length > 0) {
      return social;
    }
    const flat: string = XNotificationParser.str(XNotificationParser.obj(item, 'message'), ['text']);
    if (flat.length > 0) {
      return flat;
    }
    const template: Record<string, Object> = XNotificationParser.obj(item, 'template');
    const extra: Record<string, Object> = XNotificationParser.objKey(template,
      ['additional_context', 'additionalContext']);
    return XNotificationParser.str(extra, ['text']);
  }

  private static postId(item: Record<string, Object>): string {
    const results: Record<string, Object> = XNotificationParser.postResults(item);
    const result: Record<string, Object> = XNotificationParser.obj(results, 'result');
    const wrapped: string = XNotificationParser.str(XNotificationParser.obj(result, 'tweet'),
      ['rest_id', 'restId']);
    if (wrapped.length > 0) {
      return wrapped;
    }
    const direct: string = XNotificationParser.str(result, ['rest_id', 'restId']);
    if (direct.length > 0) {
      return direct;
    }
    const outer: string = XNotificationParser.str(results, ['rest_id', 'restId']);
    if (outer.length > 0) {
      return outer;
    }
    // Aggregated rows ("X and 3 others liked") ship the results without a
    // rest_id; the row's own link still ends in /status/<post id>.
    return XNotificationParser.postIdFromUrl(XNotificationParser.deepLink(item));
  }

  private static postText(item: Record<string, Object>): string {
    const post: Record<string, Object> = XNotificationParser.targetPost(item);
    const legacy: string = XNotificationParser.str(XNotificationParser.obj(post, 'legacy'),
      ['full_text', 'fullText']);
    if (legacy.length > 0) {
      return legacy;
    }
    return XNotificationParser.str(XNotificationParser.obj(post, 'details'),
      ['full_text', 'fullText', 'text']);
  }

  // The post a row points at, unwrapped from TweetResults and from the
  // TweetWithVisibilityResults wrapper when present.
  private static targetPost(item: Record<string, Object>): Record<string, Object> {
    const results: Record<string, Object> = XNotificationParser.postResults(item);
    const result: Record<string, Object> = XNotificationParser.obj(results, 'result');
    const wrapper: Record<string, Object> = XNotificationParser.obj(result, 'tweet');
    return Object.keys(wrapper).length > 0 ? wrapper : result;
  }

  // First attachment of that post, as the flat schema stores it (ApiMediaEntity
  // wrapping ApiMedia), so the row can show the same thumbnail X's own list
  // shows.
  private static mediaNodeOf(item: Record<string, Object>): Record<string, Object> {
    const post: Record<string, Object> = XNotificationParser.targetPost(item);
    const flat: Record<string, Object> = XNotificationParser.firstMediaNode(
      XNotificationParser.arrKey(post, ['media_entities', 'mediaEntities']));
    if (Object.keys(flat).length > 0) {
      return flat;
    }
    const legacy: Record<string, Object> = XNotificationParser.obj(post, 'legacy');
    const extended: Record<string, Object> = XNotificationParser.firstMediaNode(
      XNotificationParser.arr(XNotificationParser.obj(legacy, 'extended_entities'), 'media'));
    if (Object.keys(extended).length > 0) {
      return extended;
    }
    return XNotificationParser.firstMediaNode(
      XNotificationParser.arr(XNotificationParser.obj(legacy, 'entities'), 'media'));
  }

  private static firstMediaNode(list: Array<Record<string, Object>>): Record<string, Object> {
    for (let i: number = 0; i < list.length; i++) {
      const node: Record<string, Object> = XNotificationParser.mediaNode(list[i]);
      if (Object.keys(XNotificationParser.mediaInfo(node)).length > 0 ||
        XNotificationParser.str(node, ['media_url_https', 'mediaUrlHttps']).length > 0) {
        return node;
      }
    }
    return {};
  }

  // media_results.result wraps the ApiMedia object in the current schema; the
  // classic schema puts the fields on the entity itself.
  private static mediaNode(node: Record<string, Object>): Record<string, Object> {
    const results: Record<string, Object> = XNotificationParser.objKey(node,
      ['media_results', 'mediaResults']);
    const inner: Record<string, Object> = XNotificationParser.obj(results, 'result');
    return Object.keys(inner).length > 0 ? inner : node;
  }

  private static mediaInfo(node: Record<string, Object>): Record<string, Object> {
    return XNotificationParser.objKey(node, ['media_info', 'mediaInfo']);
  }

  private static mediaUrlOf(node: Record<string, Object>): string {
    const info: Record<string, Object> = XNotificationParser.mediaInfo(node);
    const photo: string = XNotificationParser.str(info, ['original_img_url', 'originalImgUrl']);
    if (photo.length > 0) {
      return photo;
    }
    // Video and GIF attachments carry a poster frame instead.
    const preview: Record<string, Object> = XNotificationParser.objKey(info,
      ['preview_image', 'previewImage']);
    const poster: string = XNotificationParser.str(preview,
      ['original_img_url', 'originalImgUrl', 'url']);
    if (poster.length > 0) {
      return poster;
    }
    const classic: string = XNotificationParser.str(node, ['media_url_https', 'mediaUrlHttps']);
    if (classic.length > 0) {
      return classic;
    }
    return XNotificationParser.str(node, ['preview_image_url', 'previewImageUrl']);
  }

  private static mediaIsVideo(node: Record<string, Object>): boolean {
    if (Object.keys(node).length === 0) {
      return false;
    }
    const type: string = XNotificationParser.str(node, ['__typename']).toLowerCase();
    if (type === 'apivideo' || type === 'apigif') {
      return true;
    }
    const declared: string = XNotificationParser.str(node, ['type']).toLowerCase();
    if (declared === 'video' || declared === 'animated_gif') {
      return true;
    }
    const info: Record<string, Object> = XNotificationParser.mediaInfo(node);
    const infoType: string = XNotificationParser.str(info, ['__typename']).toLowerCase();
    if (infoType === 'apivideo' || infoType === 'apigif') {
      return true;
    }
    return XNotificationParser.arrKey(info, ['variants']).length > 0;
  }

  // Current payloads use an array of results, older ones a single object, so
  // both have to be unwrapped before the post can be read.
  private static postResults(item: Record<string, Object>): Record<string, Object> {
    const keys: string[] = ['target_tweets_results', 'targetTweetsResults',
      'tweet_results', 'tweetResults'];
    for (let i: number = 0; i < keys.length; i++) {
      const value: Object | undefined = item[keys[i]];
      if (value === undefined || value === null) {
        continue;
      }
      if (value instanceof Array) {
        const list: Array<Record<string, Object>> = value as Array<Record<string, Object>>;
        for (let e: number = 0; e < list.length; e++) {
          if (Object.keys(list[e]).length > 0) {
            return list[e];
          }
        }
        continue;
      }
      if (typeof value === 'object') {
        const record: Record<string, Object> = value as Record<string, Object>;
        if (Object.keys(record).length > 0) {
          return record;
        }
      }
    }
    return {};
  }

  private static deepLink(item: Record<string, Object>): string {
    return XNotificationParser.str(XNotificationParser.obj(item, 'url'), ['url']);
  }

  private static postIdFromUrl(url: string): string {
    const marker: string = '/status/';
    const at: number = url.indexOf(marker);
    if (at < 0) {
      return '';
    }
    let id: string = '';
    for (let i: number = at + marker.length; i < url.length; i++) {
      const code: number = url.charCodeAt(i);
      if (code < 48 || code > 57) {
        break;
      }
      id += url.charAt(i);
    }
    return id;
  }

  // The accounts behind the notification: template.from_users in the current
  // payload, a single user_results in older ones, and the target post's author
  // when neither is present.
  private static actorNode(item: Record<string, Object>): Record<string, Object> {
    const template: Record<string, Object> = XNotificationParser.obj(item, 'template');
    const fromUsers: Array<Record<string, Object>> = XNotificationParser.arrKey(template,
      ['from_users', 'fromUsers']);
    for (let i: number = 0; i < fromUsers.length; i++) {
      const result: Record<string, Object> = XNotificationParser.actorReference(fromUsers[i]);
      if (Object.keys(result).length > 0) {
        return result;
      }
    }
    const direct: Record<string, Object> = XNotificationParser.objKey(item,
      ['user_results', 'userResults']);
    const directResult: Record<string, Object> = XNotificationParser.obj(direct, 'result');
    if (Object.keys(directResult).length > 0) {
      return directResult;
    }
    const post: Record<string, Object> = XNotificationParser.targetPost(item);
    const core: Record<string, Object> = XNotificationParser.obj(post, 'core');
    return XNotificationParser.obj(XNotificationParser.objKey(core,
      ['user_results', 'userResults']), 'result');
  }

  private static actorReference(reference: Record<string, Object>): Record<string, Object> {
    const wrapped: Record<string, Object> = XNotificationParser.objKey(reference,
      ['user_results', 'userResults', 'user_result', 'userResult']);
    const result: Record<string, Object> = XNotificationParser.obj(wrapped, 'result');
    if (Object.keys(result).length > 0) { return result; }
    const direct: Record<string, Object> = XNotificationParser.obj(reference, 'result');
    if (Object.keys(direct).length > 0) { return direct; }
    return XNotificationParser.str(reference, ['__typename']) === 'User' ? reference : {};
  }

  private static actors(item: Record<string, Object>, fallback: Record<string, Object>): TweetAuthor[] {
    const references: Array<Record<string, Object>> = XNotificationParser.arrKey(
      XNotificationParser.obj(item, 'template'), ['from_users', 'fromUsers']);
    const nodes: Array<Record<string, Object>> = references.map((reference: Record<string, Object>): Record<string, Object> =>
      XNotificationParser.actorReference(reference));
    if (nodes.length === 0 && Object.keys(fallback).length > 0) { nodes.push(fallback); }
    const authors: TweetAuthor[] = [];
    const seen: Set<string> = new Set<string>();
    for (const node of nodes) {
      const handle: string = XNotificationParser.actorHandle(node);
      const id: string = XNotificationParser.str(node, ['rest_id', 'restId']) || handle;
      if (id.length === 0 || seen.has(id)) { continue; }
      seen.add(id);
      authors.push({ id: id, name: XNotificationParser.actorName(node), username: handle,
        avatarUrl: XNotificationParser.actorAvatar(node), avatarColor: '#1D9BF0',
        verified: XNotificationParser.actorVerified(node), verifiedType: userVerifiedType(node),
        avatarShape: userAvatarShape(node) });
    }
    return authors;
  }

  private static hasVerifiedActor(item: Record<string, Object>, actor: Record<string, Object>): boolean {
    if (XNotificationParser.actorVerified(actor)) { return true; }
    const template: Record<string, Object> = XNotificationParser.obj(item, 'template');
    const users: Array<Record<string, Object>> = XNotificationParser.arrKey(template, ['from_users', 'fromUsers']);
    for (let i: number = 0; i < users.length; i++) {
      const results: Record<string, Object> = XNotificationParser.objKey(users[i], ['user_results', 'userResults']);
      if (XNotificationParser.actorVerified(XNotificationParser.obj(results, 'result'))) { return true; }
    }
    return false;
  }

  private static actorVerified(actor: Record<string, Object>): boolean {
    const verification: Record<string, Object> = XNotificationParser.obj(actor, 'verification');
    const legacy: Record<string, Object> = XNotificationParser.obj(actor, 'legacy');
    return verification['is_blue_verified'] === true || actor['is_blue_verified'] === true ||
      verification['verified'] === true || legacy['verified'] === true ||
      verification['is_verified_organization'] === true;
  }

  private static actorName(node: Record<string, Object>): string {
    const core: string = XNotificationParser.str(XNotificationParser.obj(node, 'core'), ['name']);
    if (core.length > 0) {
      return core;
    }
    return XNotificationParser.str(XNotificationParser.obj(node, 'legacy'), ['name']);
  }

  private static actorHandle(node: Record<string, Object>): string {
    const core: string = XNotificationParser.str(XNotificationParser.obj(node, 'core'),
      ['screen_name', 'screenName']);
    if (core.length > 0) {
      return core;
    }
    return XNotificationParser.str(XNotificationParser.obj(node, 'legacy'),
      ['screen_name', 'screenName']);
  }

  private static actorAvatar(node: Record<string, Object>): string {
    const avatar: string = XNotificationParser.str(XNotificationParser.obj(node, 'avatar'),
      ['image_url', 'imageUrl']);
    if (avatar.length > 0) {
      return avatar;
    }
    return XNotificationParser.str(XNotificationParser.obj(node, 'legacy'),
      ['profile_image_url_https', 'profileImageUrlHttps']);
  }

  // `timestamp_ms` is an epoch number in the schema and an ISO 8601 string in
  // the payloads X actually serves; the entry's sort_index carries the same
  // instant in milliseconds when neither is usable.
  private static timestampOf(item: Record<string, Object>, fallbackMs: number): number {
    const raw: Object | undefined = item['timestamp_ms'] ?? item['timestampMs'];
    if (raw !== undefined && raw !== null) {
      if (typeof raw === 'number') {
        return XNotificationParser.normaliseTime(raw);
      }
      if (typeof raw === 'string') {
        const text: string = raw as string;
        const numeric: number = Number(text);
        if (!isNaN(numeric) && numeric > 0) {
          return XNotificationParser.normaliseTime(numeric);
        }
        const parsed: number = Date.parse(text);
        if (!isNaN(parsed)) {
          return parsed;
        }
      }
    }
    return fallbackMs;
  }

  private static normaliseTime(value: number): number {
    if (value <= 0) {
      return 0;
    }
    return value < SECONDS_CUTOFF ? value * 1000 : value;
  }

  private static sortIndexOf(entry: Record<string, Object>): number {
    const raw: string = XNotificationParser.str(entry, ['sortIndex', 'sort_index']);
    if (raw.length === 0) {
      return 0;
    }
    const parsed: number = Number(raw);
    return isNaN(parsed) ? 0 : XNotificationParser.normaliseTime(parsed);
  }

  // 'top' / 'bottom' for a cursor entry, '' for anything else. The direction is
  // declared either in the content type or in the entry id X assigns it.
  private static cursorDirection(entry: Record<string, Object>): string {
    const content: Record<string, Object> = XNotificationParser.obj(entry, 'content');
    const entryId: string = XNotificationParser.str(entry, ['entryId', 'entry_id']);
    const type: string = XNotificationParser.str(content, ['__typename', 'itemType', 'entryType']);
    const isCursor: boolean = type === 'TimelineTimelineCursor' || entryId.indexOf('cursor-') === 0;
    if (!isCursor) {
      return '';
    }
    const direction: string =
      XNotificationParser.str(content, ['cursor_type', 'cursorType']).toLowerCase();
    if (direction.length > 0) {
      return direction;
    }
    if (entryId.indexOf('cursor-bottom') === 0) {
      return 'bottom';
    }
    if (entryId.indexOf('cursor-top') === 0) {
      return 'top';
    }
    return '';
  }

  private static cursorPayload(entry: Record<string, Object>): string {
    const content: Record<string, Object> = XNotificationParser.obj(entry, 'content');
    return XNotificationParser.str(content, ['value', 'cursorValue', 'cursor']);
  }

  private static findInstructions(node: Record<string, Object>, depth: number): Record<string, Object> {
    if (depth > 6) {
      return {};
    }
    if (node['instructions'] instanceof Array) {
      return node;
    }
    const keys: string[] = Object.keys(node);
    for (let i: number = 0; i < keys.length; i++) {
      const value: Object | undefined = node[keys[i]];
      if (value === undefined || value === null || typeof value !== 'object' || value instanceof Array) {
        continue;
      }
      const found: Record<string, Object> =
        XNotificationParser.findInstructions(value as Record<string, Object>, depth + 1);
      if (Object.keys(found).length > 0) {
        return found;
      }
    }
    return {};
  }

  // Reads the first usable value among the alternative spellings of a key.
  private static str(source: Record<string, Object> | undefined, keys: string[]): string {
    if (source === undefined) {
      return '';
    }
    for (let i: number = 0; i < keys.length; i++) {
      const value: Object | undefined = source[keys[i]];
      if (value === undefined || value === null) {
        continue;
      }
      if (typeof value === 'string') {
        const text: string = value as string;
        if (text.length > 0) {
          return text;
        }
      } else if (typeof value === 'number') {
        return value.toString();
      }
    }
    return '';
  }

  private static obj(source: Record<string, Object> | undefined, key: string): Record<string, Object> {
    if (source === undefined) {
      return {};
    }
    const value: Object | undefined = source[key];
    if (value === undefined || value === null || typeof value !== 'object' || value instanceof Array) {
      return {};
    }
    return value as Record<string, Object>;
  }

  private static objKey(source: Record<string, Object>, keys: string[]): Record<string, Object> {
    for (let i: number = 0; i < keys.length; i++) {
      const found: Record<string, Object> = XNotificationParser.obj(source, keys[i]);
      if (Object.keys(found).length > 0) {
        return found;
      }
    }
    return {};
  }

  private static arr(source: Record<string, Object>, key: string): Array<Record<string, Object>> {
    const value: Object | undefined = source[key];
    if (value instanceof Array) {
      return value as Array<Record<string, Object>>;
    }
    return [];
  }

  private static arrKey(source: Record<string, Object>,
    keys: string[]): Array<Record<string, Object>> {
    for (let i: number = 0; i < keys.length; i++) {
      const found: Array<Record<string, Object>> = XNotificationParser.arr(source, keys[i]);
      if (found.length > 0) {
        return found;
      }
    }
    return [];
  }
}
