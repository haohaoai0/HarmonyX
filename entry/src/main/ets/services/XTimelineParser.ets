// Decodes an X GraphQL timeline response into the app's Tweet model.
//
// COMPATIBILITY MAP — read this before changing a field lookup.
//
// X runs two tweet schemas in production at the same time, and which one an
// operation returns is not predictable from the operation name. The home
// timeline currently answers with the classic shape while search answers with
// the flat one, in the same session.
//
//   field            classic shape                     flat shape
//   ---------------  --------------------------------  ------------------------
//   body             legacy.full_text                  details.full_text
//   long body        note_tweet.note_tweet_results…   (same)
//   metrics          legacy.favorite_count etc.        counts.like_count etc.
//   media            legacy.extended_entities.media    media_entities
//   created at       legacy.created_at                 details.created_at
//   author           core.user_results.result          (same)
//   views            views.count                       (same)
//
// Wrappers add a second axis of variation:
//   * a post may sit behind a TweetWithVisibilityResults wrapper;
//   * a timeline entry may be a TimelineTimelineItem with no itemType at all,
//     so the presence of tweet_results is the reliable signal;
//   * conversation modules nest posts under content.items[].item.itemContent;
//   * quoted posts appear in the same node and must not become their own row.
//
// Every lookup below therefore tries several paths and falls back, and
// describe() / entryShapes() / describeTextlessTweet() can print the real
// structure of a payload when a new variation appears. The probe in
// Settings > Private interface session drives them.
//
// The shape is deeply nested and shifts between operations, so every step is
// defensive: unknown wrappers are skipped rather than treated as errors.
//
//   data.<timeline>.instructions[]          type = TimelineAddEntries
//     .entries[]                            content.entryType
//       .itemContent.tweet_results.result   __typename = Tweet | TweetWithVisibilityResults
//         .core.user_results.result         author
//         .legacy                           full_text, counts, media
//         .views.count                      impressions
//
// Bottom cursors live in entries whose content.entryType is TimelineTimelineCursor.
import hilog from '@ohos.hilog';
import type {
  MediaAttachment,
  QuotedTweet,
  Tweet,
  TweetAuthor,
  TweetMetrics,
  TweetFeedbackAction,
  ProfileArticle,
  VideoRendition,
  UserListPage,
  UserRow
} from '../models/Tweet';
import type { TweetPage } from './XApiClient';
import { normalizedPostMediaType } from '../utils/PostGif';
import { optionalPostCount, postEditHistoryIds } from '../utils/PostMetadata';
import { ReplyConversation } from './ReplyConversation';
import { XPostCardParser } from './XPostCardParser';
import { XArticleParser } from './XArticleParser';
import { XPostPresentationParser } from './XPostPresentationParser';
import { userIsVerified, userVerifiedType, userAvatarShape } from '../utils/UserIdentity';

const DOMAIN = 0xFF00;
const TAG = 'HarmonyX-Timeline';
// A feed cell plays in a 228vp tall box, so a 480x270 rendition is already
// sharper than the frame it is drawn into while being several times smaller
// than the 720p copy. Anything below this bitrate looks blocky even there.
const FEED_BITRATE_FLOOR: number = 500000;

export interface TweetDetailPage {
  focal: Tweet | null;
  replies: Tweet[];
  discoverMore: Tweet[];
  nextToken: string;
  discoverMoreStarted: boolean;
}

interface PostReplyRelation {
  parentId: string;
  username: string;
  conversationId: string;
  isReply: boolean;
}

export class XTimelineParser {
  static videoTimelineId(body: string): string {
    try {
      const root: Record<string, Object> = JSON.parse(body) as Record<string, Object>;
      const timeline: Record<string, Object> = XTimelineParser.findTimeline(XTimelineParser.obj(root, 'data'));
      return typeof timeline['id'] === 'string' ? timeline['id'] as string : '';
    } catch (error) { return ''; }
  }

  static parseNotificationPosts(results: Array<Record<string, Object>>): Tweet[] {
    XTimelineParser.users = new Map();
    XTimelineParser.mediaByKey = new Map();
    XTimelineParser.collectUsers(results, 0);
    XTimelineParser.collectMedia(results, 0);
    const posts: Tweet[] = [];
    for (const result of results) {
      const wrapped: Record<string, Object> = XTimelineParser.obj(result, 'result');
      const post: Tweet | null = XTimelineParser.tweetFromNode(Object.keys(wrapped).length > 0 ? wrapped : result);
      if (post !== null) { posts.push(post); }
    }
    return XTimelineParser.dedupe(posts);
  }

  static parseDeviceFollow(body: string): TweetPage | null {
    try {
      const root: Record<string, Object> = JSON.parse(body) as Record<string, Object>;
      const global: Record<string, Object> = XTimelineParser.obj(root, 'globalObjects');
      const sourcePosts: Record<string, Object> = XTimelineParser.obj(global, 'tweets');
      const sourceUsers: Record<string, Object> = XTimelineParser.obj(global, 'users');
      const timeline: Record<string, Object> = XTimelineParser.obj(root, 'timeline');
      if (Object.keys(timeline).length === 0 || root['globalObjects'] === undefined) { return XTimelineParser.parse(body); }
      const instructions: Array<Record<string, Object>> = XTimelineParser.arr(timeline, 'instructions');
      const results: Array<Record<string, Object>> = [];
      let cursor: string = '';
      for (const instruction of instructions) {
        const entries: Array<Record<string, Object>> = XTimelineParser.arr(XTimelineParser.obj(instruction, 'addEntries'), 'entries');
        for (const entry of entries) {
          const content: Record<string, Object> = XTimelineParser.obj(entry, 'content');
          const operation: Record<string, Object> = XTimelineParser.obj(content, 'operation');
          const cursorNode: Record<string, Object> = XTimelineParser.obj(operation, 'cursor');
          if (String(cursorNode['cursorType'] ?? '').toLowerCase() === 'bottom') {
            cursor = String(cursorNode['value'] ?? '');
          }
          const item: Record<string, Object> = XTimelineParser.obj(XTimelineParser.obj(content, 'item'), 'content');
          const target: Record<string, Object> = XTimelineParser.obj(item, 'tweet');
          const id: string = String(target['id'] ?? '');
          const raw: Object | undefined = sourcePosts[id];
          if (raw !== undefined && typeof raw === 'object') {
            results.push(XTimelineParser.deviceFollowPost(raw as Record<string, Object>, sourcePosts, sourceUsers, 0));
          }
        }
      }
      return { tweets: XTimelineParser.parseNotificationPosts(results), nextToken: cursor, topToken: '' };
    } catch (error) { return null; }
  }

  private static deviceFollowPost(raw: Record<string, Object>, posts: Record<string, Object>,
    users: Record<string, Object>, depth: number): Record<string, Object> {
    if (depth > 3) { return {}; }
    const legacy: Record<string, Object> = {};
    for (const key of Object.keys(raw)) { legacy[key] = raw[key] as Object; }
    const empty: Record<string, Object> = {};
    const user: Object = users[String(raw['user_id_str'] ?? '')] ?? raw['user'] ?? empty;
    const userResult: Record<string, Object> = { '__typename': 'User',
      'rest_id': String(raw['user_id_str'] ?? ''), 'legacy': user };
    const userResults: Record<string, Object> = { 'result': userResult };
    const core: Record<string, Object> = { 'user_results': userResults };
    const result: Record<string, Object> = { '__typename': 'Tweet', 'rest_id': String(raw['id_str'] ?? ''),
      'legacy': legacy, 'core': core };
    const repost: Record<string, Object> = XTimelineParser.obj(raw, 'retweeted_status');
    if (Object.keys(repost).length > 0) {
      const wrapper: Record<string, Object> = { 'result': XTimelineParser.deviceFollowPost(repost, posts, users, depth + 1) };
      legacy['retweeted_status_result'] = wrapper;
    }
    const quoteId: string = String(raw['quoted_status_id_str'] ?? '');
    const quoted: Object | undefined = posts[quoteId] ?? raw['quoted_status'];
    if (quoted !== undefined && typeof quoted === 'object') {
      const wrapper: Record<string, Object> = { 'result': XTimelineParser.deviceFollowPost(quoted as Record<string, Object>, posts, users, depth + 1) };
      result['quoted_status_result'] = wrapper;
    }
    return result;
  }

  private static attachFeedback(tweets: Tweet[], timeline: Record<string, Object>): void {
    const objects: Record<string, Object> = XTimelineParser.obj(timeline, 'response_objects');
    const responseObjects: Record<string, Object> = Object.keys(objects).length > 0 ? objects :
      XTimelineParser.obj(timeline, 'responseObjects');
    const rows: Array<Record<string, Object>> = XTimelineParser.arr(responseObjects, 'feedback_actions').length > 0 ?
      XTimelineParser.arr(responseObjects, 'feedback_actions') : XTimelineParser.arr(responseObjects, 'feedbackActions');
    for (const tweet of tweets) {
      const actions: TweetFeedbackAction[] = [];
      for (const row of rows) {
        const key: string = String(row['key'] ?? '');
        if ((tweet.feedbackKeys ?? []).indexOf(key) < 0) { continue; }
        const value: Record<string, Object> = XTimelineParser.obj(row, 'value');
        actions.push({ key: key, type: String(value['feedback_type'] ?? value['feedbackType'] ?? ''),
          prompt: String(value['prompt'] ?? ''), confirmation: String(value['confirmation'] ?? ''),
          url: String(value['feedback_url'] ?? value['feedbackUrl'] ?? '') });
      }
      tweet.feedbackActions = actions;
    }
  }
  static parsePostContent(body: string, postId: string): Tweet | null {
    try {
      const data: Record<string, Object> = XTimelineParser.obj(JSON.parse(body) as Record<string, Object>, 'data');
      const wrapper: Record<string, Object> = XTimelineParser.obj(data, 'tweetResult');
      return XTimelineParser.tweetFromNode(XTimelineParser.obj(wrapper, 'result'), postId);
    } catch (error) { return null; }
  }
  // Users harvested from the current payload, keyed by rest_id. Some response
  // shapes do not embed the author in the tweet node and reference it by id
  // instead, so a side table is needed to resolve handles. The parser is called
  // sequentially from the UI, so a single static map is sufficient.
  private static users: Map<string, Record<string, Object>> = new Map();
  // Media objects harvested from the payload, keyed by media_key. The flat
  // schema lists media_entities as bare references in some responses, so the
  // actual URLs have to be resolved from the surrounding payload.
  private static mediaByKey: Map<string, Record<string, Object>> = new Map();

  static parse(body: string, conversationCards: boolean = true): TweetPage | null {
    try {
      const json: Record<string, Object> = JSON.parse(body) as Record<string, Object>;
      XTimelineParser.users = new Map();
      XTimelineParser.collectUsers(json, 0);
      XTimelineParser.mediaByKey = new Map();
      XTimelineParser.collectMedia(json, 0);
      const data: Record<string, Object> = XTimelineParser.obj(json, 'data');
      const timeline: Record<string, Object> = XTimelineParser.findTimeline(data);
      if (Object.keys(timeline).length === 0) {
        hilog.warn(DOMAIN, TAG, 'timeline root not found');
        return null;
      }
      const instructions: Array<Record<string, Object>> = XTimelineParser.arr(timeline, 'instructions');
      const tweets: Tweet[] = [];
      let nextToken: string = '';
      let topToken: string = '';
      const undirectedCursors: string[] = [];
      for (let i: number = 0; i < instructions.length; i++) {
        const instruction: Record<string, Object> = instructions[i];
        const entries: Array<Record<string, Object>> = XTimelineParser.arr(instruction, 'entries');
        for (let e: number = 0; e < entries.length; e++) {
          const top: string = XTimelineParser.topCursorValue(entries[e]);
          if (top.length > 0) { topToken = top; }
          const cursor: string = XTimelineParser.entryCursor(entries[e], undirectedCursors);
          if (cursor.length > 0) {
            nextToken = cursor;
            continue;
          }
          const tweet: Tweet | null = XTimelineParser.entryTweet(entries[e]);
          if (tweet !== null) {
            tweets.push(tweet);
          }
          // Conversation modules nest their posts one level deeper.
          const nested: Tweet[] = XTimelineParser.moduleTweets(entries[e], conversationCards);
          for (let n: number = 0; n < nested.length; n++) {
            tweets.push(nested[n]);
          }
        }
        // Modules (conversation threads) carry their items in a separate list.
        const moduleItems: Array<Record<string, Object>> = XTimelineParser.arr(instruction, 'moduleItems');
        const additions: Tweet[] = [];
        for (let m: number = 0; m < moduleItems.length; m++) {
          const tweet: Tweet | null = XTimelineParser.moduleItemTweet(moduleItems[m]);
          if (tweet !== null) {
            additions.push(tweet);
          }
        }
        const modulePosts: Tweet[] = conversationCards ? ReplyConversation.module(additions) : additions;
        for (let m: number = 0; m < modulePosts.length; m++) {
          tweets.push(modulePosts[m]);
        }
        // TimelineReplaceEntry (and TimelinePinEntry) wrap a single entry under
        // "entry". From the second page onward X replaces the two cursor entries
        // instead of appending them, so this wrapper carries the paging token
        // and has to be checked for a cursor before it is read as a post.
        const replaced: Record<string, Object> = XTimelineParser.obj(instruction, 'entry');
        if (Object.keys(replaced).length > 0) {
          const top: string = XTimelineParser.topCursorValue(replaced);
          if (top.length > 0) { topToken = top; }
          const replacedCursor: string = XTimelineParser.entryCursor(replaced, undirectedCursors);
          if (replacedCursor.length > 0) {
            nextToken = replacedCursor;
          } else {
            const tweet: Tweet | null = XTimelineParser.entryTweet(replaced);
            if (tweet !== null) {
              if (String(instruction['type'] ?? instruction['__typename'] ?? '') === 'TimelinePinEntry') {
                tweet.pinned = true;
                tweets.unshift(tweet);
              } else {
                tweets.push(tweet);
              }
            }
            const nested: Tweet[] = XTimelineParser.moduleTweets(replaced, conversationCards);
            for (let n: number = 0; n < nested.length; n++) {
              tweets.push(nested[n]);
            }
          }
        }
      }
      // Only infer Bottom when neither cursor declares a direction and X
      // supplied both Top and Bottom in document order. A lone Top cursor is
      // never a valid "load older" token.
      if (nextToken.length === 0 && undirectedCursors.length >= 2) {
        nextToken = undirectedCursors[undirectedCursors.length - 1];
        if (topToken.length === 0) { topToken = undirectedCursors[0]; }
      }
      if (tweets.length > 0) {
        const parsed: Tweet[] = XTimelineParser.dedupe(tweets);
        XTimelineParser.attachFeedback(parsed, timeline);
        return { tweets: conversationCards ? ReplyConversation.attach(parsed) : parsed, nextToken: nextToken, topToken: topToken };
      }
      // Shape-independent fallback: harvest every tweet-shaped object in the
      // payload. X moves timeline entries around between schema revisions, and
      // this keeps the feed working when the strict walk finds nothing.
      const harvested: Tweet[] = [];
      XTimelineParser.harvest(json, harvested, 0);
      const parsed: Tweet[] = XTimelineParser.dedupe(harvested);
      XTimelineParser.attachFeedback(parsed, timeline);
      return { tweets: conversationCards ? ReplyConversation.attach(parsed) : parsed, nextToken: nextToken, topToken: topToken };
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'parse failed: %{public}s', JSON.stringify(e));
      return null;
    }
  }

  // Detail timelines contain both conversation modules and X's
  // tweetdetailrelatedtweets modules. Preserve that boundary before flattening.
  static parseTweetDetail(body: string, focalId: string, previous: Tweet[] = [],
    inDiscoverMore: boolean = false): TweetDetailPage | null {
    const page: TweetPage | null = XTimelineParser.parse(body, false);
    if (page === null) {
      return null;
    }
    try {
      const json: Record<string, Object> = JSON.parse(body) as Record<string, Object>;
      const timeline: Record<string, Object> = XTimelineParser.findTimeline(XTimelineParser.obj(json, 'data'));
      const instructions: Array<Record<string, Object>> = XTimelineParser.arr(timeline, 'instructions');
      const suggestedIds: Set<string> = new Set<string>();
      const replyIds: Set<string> = new Set<string>();
      let discoverMoreStarted: boolean = inDiscoverMore;
      for (let i: number = 0; i < instructions.length; i++) {
        const instruction: Record<string, Object> = instructions[i];
        const entries: Array<Record<string, Object>> = XTimelineParser.arr(instruction, 'entries');
        const replaced: Record<string, Object> = XTimelineParser.obj(instruction, 'entry');
        if (Object.keys(replaced).length > 0) {
          entries.push(replaced);
        }
        for (let e: number = 0; e < entries.length; e++) {
          const entry: Record<string, Object> = entries[e];
          const entryId: string = String(entry['entryId'] ?? entry['entry_id'] ?? '').toLowerCase();
          const related: boolean = entryId.indexOf('tweetdetailrelatedtweets') === 0;
          discoverMoreStarted = discoverMoreStarted || related;
          const posts: Tweet[] = XTimelineParser.moduleTweets(entry, false);
          const direct: Tweet | null = XTimelineParser.entryTweet(entry);
          if (direct !== null) {
            posts.push(direct);
          }
          const conversation: boolean = entryId.indexOf('conversationthread') === 0;
          for (let p: number = 0; p < posts.length; p++) {
            if (related || (discoverMoreStarted && !conversation)) {
              suggestedIds.add(posts[p].id);
            } else if (conversation) {
              replyIds.add(posts[p].id);
            }
          }
        }
        const moduleId: string = String(instruction['moduleEntryId'] ?? instruction['module_entry_id'] ?? '')
          .toLowerCase();
        const relatedModule: boolean = moduleId.indexOf('tweetdetailrelatedtweets') === 0;
        const conversationModule: boolean = moduleId.indexOf('conversationthread') === 0;
        discoverMoreStarted = discoverMoreStarted || relatedModule;
        const additions: Array<Record<string, Object>> = XTimelineParser.arr(instruction, 'moduleItems');
        for (let m: number = 0; m < additions.length; m++) {
          const post: Tweet | null = XTimelineParser.moduleItemTweet(additions[m]);
          if (post !== null) {
            if (relatedModule || (discoverMoreStarted && !conversationModule)) {
              suggestedIds.add(post.id);
            } else if (conversationModule) {
              replyIds.add(post.id);
            }
          }
        }
      }
      const byId: Map<string, Tweet> = new Map<string, Tweet>();
      for (let i: number = 0; i < previous.length; i++) {
        byId.set(previous[i].id, previous[i]);
      }
      let focal: Tweet | null = byId.get(focalId) ?? null;
      for (let i: number = 0; i < page.tweets.length; i++) {
        const post: Tweet = page.tweets[i];
        byId.set(post.id, post);
        if (post.id === focalId) {
          focal = post;
        }
      }
      const ancestors: Set<string> = new Set<string>();
      let parentId: string = focal?.replyToTweetId ?? '';
      while (parentId.length > 0 && parentId !== focalId && !ancestors.has(parentId)) {
        ancestors.add(parentId);
        parentId = byId.get(parentId)?.replyToTweetId ?? '';
      }
      const replies: Tweet[] = [];
      const discoverMore: Tweet[] = [];
      for (let i: number = 0; i < page.tweets.length; i++) {
        const post: Tweet = page.tweets[i];
        if (post.id === focalId || ancestors.has(post.id)) {
          continue;
        }
        if (suggestedIds.has(post.id) && !replyIds.has(post.id)) {
          discoverMore.push(post);
          continue;
        }
        const conversationId: string = post.conversationId ?? '';
        const focalConversationId: string = focal?.conversationId || focalId;
        const belongs: boolean = XTimelineParser.detailReplyReaches(post, focalId, byId);
        if (replyIds.has(post.id) || belongs ||
          (conversationId.length > 0 && conversationId === focalConversationId && post.isReply === true) ||
          (conversationId.length === 0 && post.isReply === true && !discoverMoreStarted)) {
          replies.push(post);
        } else {
          discoverMore.push(post);
        }
      }
      hilog.info(DOMAIN, TAG, 'detail %{public}s posts=%{public}d replies=%{public}d modules=%{public}d related=%{public}d cursor=%{public}s expected=%{public}d',
        focalId, page.tweets.length, replies.length, replyIds.size, suggestedIds.size,
        String(page.nextToken.length > 0), focal?.metrics.replyCount ?? -1);
      return { focal: focal, replies: replies, discoverMore: discoverMore, nextToken: page.nextToken,
        discoverMoreStarted: discoverMoreStarted || discoverMore.length > 0 };
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'detail parse failed: %{public}s', JSON.stringify(error));
      return null;
    }
  }

  private static detailReplyReaches(post: Tweet, focalId: string, byId: Map<string, Tweet>): boolean {
    const visited: Set<string> = new Set<string>();
    visited.add(post.id);
    let parentId: string = post.replyToTweetId ?? '';
    while (parentId.length > 0 && !visited.has(parentId)) {
      if (parentId === focalId) {
        return true;
      }
      visited.add(parentId);
      parentId = byId.get(parentId)?.replyToTweetId ?? '';
    }
    return false;
  }

  // Followers, following, blocked and people-search payloads are user
  // timelines: same cursor contract as a post timeline, but each entry carries
  // a User instead of a Tweet, so they share this parser's cursor rules.
  static parseUserList(body: string): UserListPage | null {
    try {
      const json: Record<string, Object> = JSON.parse(body) as Record<string, Object>;
      XTimelineParser.users = new Map();
      XTimelineParser.collectUsers(json, 0);
      const data: Record<string, Object> = XTimelineParser.obj(json, 'data');
      const timeline: Record<string, Object> = XTimelineParser.findTimeline(data);
      const rows: UserRow[] = [];
      const undirectedCursors: string[] = [];
      let nextToken: string = '';
      const instructions: Array<Record<string, Object>> =
        XTimelineParser.arr(timeline, 'instructions');
      for (let i: number = 0; i < instructions.length; i++) {
        const entries: Array<Record<string, Object>> =
          XTimelineParser.arr(instructions[i], 'entries');
        for (let e: number = 0; e < entries.length; e++) {
          const cursor: string = XTimelineParser.entryCursor(entries[e], undirectedCursors);
          if (cursor.length > 0) {
            nextToken = cursor;
            continue;
          }
          const row: UserRow | null = XTimelineParser.entryUser(entries[e]);
          if (row !== null) {
            rows.push(row);
          }
        }
        const moduleItems: Array<Record<string, Object>> =
          XTimelineParser.arr(instructions[i], 'moduleItems');
        for (let m: number = 0; m < moduleItems.length; m++) {
          const row: UserRow | null = XTimelineParser.entryUser(moduleItems[m]);
          if (row !== null) {
            rows.push(row);
          }
        }
        // People search and the follower timelines replace their cursors the
        // same way the post timelines do, so the wrapper needs the same check.
        const replaced: Record<string, Object> = XTimelineParser.obj(instructions[i], 'entry');
        if (Object.keys(replaced).length > 0) {
          const replacedCursor: string = XTimelineParser.entryCursor(replaced, undirectedCursors);
          if (replacedCursor.length > 0) {
            nextToken = replacedCursor;
          } else {
            const row: UserRow | null = XTimelineParser.entryUser(replaced);
            if (row !== null) {
              rows.push(row);
            }
          }
        }
      }
      if (nextToken.length === 0 && undirectedCursors.length >= 2) {
        nextToken = undirectedCursors[undirectedCursors.length - 1];
      }
      if (rows.length > 0) {
        return { users: XTimelineParser.dedupeUsers(rows), nextToken: nextToken };
      }
      // Shape-independent fallback, mirroring the post parser: take every user
      // object the payload carried, in document order.
      const collected: UserRow[] = [];
      XTimelineParser.users.forEach((value: Record<string, Object>): void => {
        const row: UserRow | null = XTimelineParser.rowFromUser(value);
        if (row !== null) {
          collected.push(row);
        }
      });
      return { users: XTimelineParser.dedupeUsers(collected), nextToken: nextToken };
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'user list parse failed: %{public}s', JSON.stringify(e));
      return null;
    }
  }

  private static entryUser(entry: Record<string, Object>): UserRow | null {
    const content: Record<string, Object> = XTimelineParser.obj(entry, 'content');
    const itemContent: Record<string, Object> = XTimelineParser.obj(content, 'itemContent');
    return XTimelineParser.parseUserItemContent(itemContent);
  }

  static parseUserItemContent(itemContent: Record<string, Object>): UserRow | null {
    const results: Record<string, Object> = XTimelineParser.obj(itemContent, 'user_results');
    const result: Record<string, Object> = XTimelineParser.obj(results, 'result');
    return XTimelineParser.rowFromUser(result);
  }

  static rowFromUser(user: Record<string, Object>): UserRow | null {
    const id: string = String(user['rest_id'] ?? user['id_str'] ?? '');
    if (id.length === 0) {
      return null;
    }
    const core: Record<string, Object> = XTimelineParser.obj(user, 'core');
    const legacy: Record<string, Object> = XTimelineParser.obj(user, 'legacy');
    const avatar: Record<string, Object> = XTimelineParser.obj(user, 'avatar');
    const bio: Record<string, Object> = XTimelineParser.obj(user, 'profile_bio');
    const perspectives: Record<string, Object> = XTimelineParser.obj(user, 'relationship_perspectives');
    const banner: Record<string, Object> = XTimelineParser.obj(user, 'banner');
    const verification: Record<string, Object> = XTimelineParser.obj(user, 'verification');
    const profile: Record<string, Object> = Object.keys(legacy).length > 0 ? legacy : user;
    let avatarUrl: string = XTimelineParser.highResAvatarUrl(String(avatar['image_url'] ?? ''));
    if (avatarUrl.length === 0) {
      avatarUrl = XTimelineParser.highResAvatarUrl(String(profile['profile_image_url_https'] ?? ''));
    }
    return {
      id: id,
      name: String(core['name'] ?? profile['name'] ?? ''),
      username: String(core['screen_name'] ?? profile['screen_name'] ?? ''),
      avatarUrl: avatarUrl,
      avatarColor: '#1D9BF0',
      verified: userIsVerified(user), verifiedType: userVerifiedType(user), avatarShape: userAvatarShape(user),
      bio: String(bio['description'] ?? profile['description'] ?? ''),
      following: Boolean(perspectives['following'] ?? profile['following'] ?? false),
      followedBy: Boolean(perspectives['followed_by'] ?? profile['followed_by'] ?? false),
      bannerUrl: String(banner['image_url'] ?? profile['profile_banner_url'] ?? '')
    };
  }

  private static dedupeUsers(rows: UserRow[]): UserRow[] {
    const seen: string[] = [];
    const out: UserRow[] = [];
    for (let i: number = 0; i < rows.length; i++) {
      const id: string = rows[i].id;
      if (seen.indexOf(id) >= 0) {
        continue;
      }
      seen.push(id);
      out.push(rows[i]);
    }
    return out;
  }

  // HomeTimeline aliases its root as "home"; other operations use different
  // keys and nesting depths (search, profile timelines, conversation pages),
  // so fall back to a bounded search for the first object holding instructions.
  private static findTimeline(data: Record<string, Object>): Record<string, Object> {
    const direct: Record<string, Object> = XTimelineParser.obj(
      XTimelineParser.obj(data, 'home'), 'home_timeline_urt');
    if (Object.keys(direct).length > 0) {
      return direct;
    }
    return XTimelineParser.searchTimeline(data, 0);
  }

  // Depth-limited descent: X wraps timelines in a different number of layers
  // per operation, and the URT itself is recognisable by its instructions list.
  private static searchTimeline(node: Record<string, Object>, depth: number): Record<string, Object> {
    if (depth > 6) {
      return {};
    }
    if (node['instructions'] instanceof Array) {
      return node;
    }
    const keys: string[] = Object.keys(node);
    for (let i: number = 0; i < keys.length; i++) {
      const value: Object | undefined = node[keys[i]];
      if (value === undefined || value === null || typeof value !== 'object') {
        continue;
      }
      if (value instanceof Array) {
        continue;
      }
      const found: Record<string, Object> =
        XTimelineParser.searchTimeline(value as Record<string, Object>, depth + 1);
      if (Object.keys(found).length > 0) {
        return found;
      }
    }
    return {};
  }

  // Cursor entries reach the parser under two spellings: page one appends them
  // to instruction.entries, while every page after that replaces them, so the
  // cursor sits inside instruction.entry instead. Both have to feed the same
  // paging state; reading only the appended spelling is what ended a search
  // after a single page.
  private static entryCursor(entry: Record<string, Object>, undirected: string[]): string {
    const unknownDirection: string = XTimelineParser.undirectedCursorValue(entry);
    if (unknownDirection.length > 0) {
      undirected.push(unknownDirection);
    }
    return XTimelineParser.cursorValue(entry);
  }

  private static topCursorValue(entry: Record<string, Object>): string {
    const content: Record<string, Object> = XTimelineParser.obj(entry, 'content');
    const entryId: string = String(entry['entryId'] ?? entry['entry_id'] ?? '');
    const direction: string = String(content['cursor_type'] ?? content['cursorType'] ?? '').toLowerCase();
    const isCursor: boolean = XTimelineParser.contentType(content) === 'TimelineTimelineCursor' || entryId.startsWith('cursor-');
    if (!isCursor || (direction.length > 0 ? direction !== 'top' : !entryId.startsWith('cursor-top'))) { return ''; }
    return XTimelineParser.cursorPayload(content);
  }

  private static cursorValue(entry: Record<string, Object>): string {
    const content: Record<string, Object> = XTimelineParser.obj(entry, 'content');
    const entryId: string = String(entry['entryId'] ?? entry['entry_id'] ?? '');
    // The cursor is recognisable either by its content type or, when the payload
    // omits that discriminator, by the entry id X assigns it.
    const looksLikeCursor: boolean =
      XTimelineParser.contentType(content) === 'TimelineTimelineCursor' ||
      entryId.indexOf('cursor-') === 0;
    if (!looksLikeCursor) {
      return '';
    }
    // The direction field is camelCase in the classic schema and snake_case in
    // the flat one; entryId, the classic schema's second signal, is empty there.
    const declaredType: string = String(content['cursor_type'] ?? content['cursorType'] ?? '');
    if (declaredType.length > 0) {
      if (declaredType.toLowerCase() !== 'bottom') {
        return '';
      }
    } else if (entryId.indexOf('cursor-bottom') !== 0) {
      // An undirected cursor needs its partner for document-order inference.
      // A declared id that is not Bottom cannot advance paging either.
      return '';
    }
    return XTimelineParser.cursorPayload(content);
  }

  private static cursorPayload(content: Record<string, Object>): string {
    // The cursor payload has been seen under several key names.
    return String(content['value'] ?? content['cursorValue'] ?? content['cursor'] ?? '');
  }

  // Any cursor payload in document order, used when a response declares no
  // direction at all: X lists Top before Bottom.
  private static undirectedCursorValue(entry: Record<string, Object>): string {
    const content: Record<string, Object> = XTimelineParser.obj(entry, 'content');
    const entryId: string = String(entry['entryId'] ?? entry['entry_id'] ?? '');
    const looksLikeCursor: boolean =
      XTimelineParser.contentType(content) === 'TimelineTimelineCursor' ||
      entryId.indexOf('cursor-') === 0;
    if (!looksLikeCursor) {
      return '';
    }
    const declaredType: string = String(content['cursor_type'] ?? content['cursorType'] ?? '');
    if (declaredType.length > 0 || entryId.length > 0) {
      return '';
    }
    return XTimelineParser.cursorPayload(content);
  }

  // X ships two spellings of the same discriminator: the older responses use
  // entryType/itemType, current ones carry __typename on the same nodes.
  private static contentType(content: Record<string, Object>): string {
    return String(content['entryType'] ?? content['__typename'] ?? '');
  }

  private static itemType(itemContent: Record<string, Object>): string {
    return String(itemContent['itemType'] ?? itemContent['__typename'] ?? '');
  }

  private static entryTweet(entry: Record<string, Object>): Tweet | null {
    const content: Record<string, Object> = XTimelineParser.obj(entry, 'content');
    const itemContent: Record<string, Object> = XTimelineParser.obj(content, 'itemContent');
    if (Object.keys(itemContent).length > 0) {
      const tweet: Tweet | null = XTimelineParser.parseTweetItemContent(itemContent, String(entry['entryId'] ?? ''));
      if (tweet !== null) { XTimelineParser.readFeedbackKeys(tweet, content); }
      return tweet;
    }
    // The flat search schema drops the itemContent wrapper and nests the post
    // one level directly under the timeline item.
    const tweet: Tweet | null = XTimelineParser.parseTweetItemContent(XTimelineParser.obj(content, 'content'), String(entry['entryId'] ?? ''));
    if (tweet !== null) { XTimelineParser.readFeedbackKeys(tweet, content); }
    return tweet;
  }

  private static readFeedbackKeys(tweet: Tweet, content: Record<string, Object>): void {
    const info: Record<string, Object> = XTimelineParser.obj(content, 'feedbackInfo');
    const fallback: Record<string, Object> = XTimelineParser.obj(content, 'feedback_info');
    const raw: Object | undefined = info['feedbackKeys'] ?? info['feedback_keys'] ??
      fallback['feedback_keys'] ?? fallback['feedbackKeys'];
    if (raw instanceof Array) {
      tweet.feedbackKeys = (raw as Object[]).map((key: Object): string => String(key));
    }
  }

  static parseTweetItemContent(itemContent: Record<string, Object>, entryId: string = ''): Tweet | null {
    // Current payloads drop the itemType discriminator entirely, so the
    // result wrapper is the reliable signal. Native community media uses
    // tweetResult while other timelines use tweet_results.
    let tweetResults: Record<string, Object> = XTimelineParser.obj(itemContent, 'tweet_results');
    if (Object.keys(tweetResults).length === 0) {
      tweetResults = XTimelineParser.obj(itemContent, 'tweetResult');
    }
    const hasTweetResults: boolean = Object.keys(tweetResults).length > 0;
    if (!hasTweetResults && XTimelineParser.itemType(itemContent) !== 'TimelineTweet') {
      return null;
    }
    const tweet: Tweet | null =
      XTimelineParser.tweetFromResult(tweetResults, String(itemContent['tweet_id'] ?? '') ||
        (entryId.match(/(?:tweet|post)-(\d+)$/)?.[1] ?? ''));
    if (tweet !== null) {
      const itemPresentation = XPostPresentationParser.parse(itemContent);
      if (itemPresentation !== undefined) {
        if (tweet.presentation === undefined) { tweet.presentation = itemPresentation; }
        else { tweet.presentation.labels.push(...itemPresentation.labels); }
      }
      XTimelineParser.attachCommunity(tweet, itemContent);
      let context: Record<string, Object> = XTimelineParser.obj(itemContent, 'social_context');
      if (Object.keys(context).length === 0) {
        context = XTimelineParser.obj(itemContent, 'socialContext');
      }
      const contextType: string = String(context['context_type'] ?? context['contextType'] ?? '').toLowerCase();
      if (contextType === 'retweet' || contextType === 'repost') {
        tweet.isRepost = true;
        tweet.repostText = String(context['text'] ?? '');
      }
    }
    return tweet;
  }

  // "TimelineTimelineModule" entries (threads, "show more" groups) carry their
  // posts as items[].item.itemContent rather than a single itemContent.
  private static moduleTweets(entry: Record<string, Object>, conversationCards: boolean): Tweet[] {
    const out: Tweet[] = [];
    const content: Record<string, Object> = XTimelineParser.obj(entry, 'content');
    if (XTimelineParser.contentType(content) !== 'TimelineTimelineModule') {
      return out;
    }
    const items: Array<Record<string, Object>> = XTimelineParser.arr(content, 'items');
    for (let i: number = 0; i < items.length; i++) {
      const tweet: Tweet | null = XTimelineParser.moduleItemTweet(items[i]);
      if (tweet !== null) { out.push(tweet); }
    }
    return conversationCards ? ReplyConversation.module(out) : out;
  }

  // Initial modules and TimelineAddToModule use the same two item wrappers.
  private static moduleItemTweet(row: Record<string, Object>): Tweet | null {
    const item: Record<string, Object> = XTimelineParser.obj(row, 'item');
    let content: Record<string, Object> = XTimelineParser.obj(item, 'itemContent');
    if (Object.keys(content).length === 0) { content = XTimelineParser.obj(row, 'itemContent'); }
    const tweet: Tweet | null = Object.keys(content).length > 0 ?
      XTimelineParser.parseTweetItemContent(content, String(row['entryId'] ?? row['entry_id'] ?? item['entryId'] ?? '')) :
      XTimelineParser.entryTweet(row);
    if (tweet !== null) { XTimelineParser.readFeedbackKeys(tweet, item); }
    return tweet;
  }

  // Compact structural summary, used when parsing yields nothing. Prints the
  // path, array lengths and the first element's shape instead of the whole
  // payload, so a response that does not match the parser can be diagnosed
  // from a screenshot.
  static describe(body: string, maxLines: number = 60): string {
    const lines: string[] = [];
    try {
      const json: Object = JSON.parse(body) as Object;
      XTimelineParser.walk(json, '$', lines, 0, maxLines);
    } catch (e) {
      lines.push('not json: ' + body.substring(0, 120));
    }
    return lines.join('\n');
  }

  // Just the per-array shape histogram, which shows what a payload is mostly
  // made of (posts, users, cursors) without dumping its contents.
  static entryShapes(body: string): string {
    const lines: string[] = [];
    try {
      const json: Object = JSON.parse(body) as Object;
      XTimelineParser.walk(json, '$', lines, 0, 400);
    } catch (e) {
      return '';
    }
    const shapes: string[] = [];
    for (let i: number = 0; i < lines.length && shapes.length < 4; i++) {
      const at: number = lines[i].indexOf('shapes:');
      if (at >= 0) {
        shapes.push(lines[i].substring(at).trim());
      }
    }
    return shapes.join('\n');
  }

  // Structure of the first tweet node, used when posts decode but their author
  // does not resolve.
  // Dumps the first real timeline entry: that is where the tweet, its author and
  // its body live, so it shows the actual field names a payload uses.
  static describeFirstEntry(body: string, maxLines: number = 45): string {
    try {
      const json: Object = JSON.parse(body) as Object;
      const entry: Record<string, Object> = XTimelineParser.findFirstEntry(json, 0);
      if (Object.keys(entry).length === 0) {
        return 'no timeline entry found';
      }
      const lines: string[] = [];
      XTimelineParser.walk(entry, '$entry', lines, 0, maxLines);
      return lines.join('\n');
    } catch (e) {
      return 'entry dump failed';
    }
  }

  // Dumps the first entry whose post decoded without body text: that entry
  // carries whichever field arrangement the parser does not know yet.
  // Dumps the first tweet node that decoded without a body. That node is the
  // one holding an arrangement the text lookup does not yet cover.
  static describeTextlessTweet(body: string, maxLines: number = 40): string {
    try {
      const json: Object = JSON.parse(body) as Object;
      const node: Record<string, Object> = XTimelineParser.findTextlessTweet(json, 0);
      if (Object.keys(node).length === 0) {
        return 'no textless tweet node found';
      }
      const lines: string[] = [];
      XTimelineParser.keySummary(node, '$tweet', lines, 3);
      return lines.join('\n');
    } catch (e) {
      return 'textless tweet dump failed';
    }
  }

  // Key-only summary. A deep dump of a tweet spends its whole budget inside the
  // author subtree, so this prints the field names of the node and of the
  // containers that can hold a body.
  private static keySummary(node: Record<string, Object>, path: string,
    lines: string[], depth: number): void {
    if (lines.length > 60) {
      return;
    }
    lines.push(path + '.keys = [' + Object.keys(node).join(',') + ']');
    if (depth <= 0) {
      return;
    }
    const interesting: string[] = ['core', 'legacy', 'note_tweet', 'tweet', 'tweet_results',
      'result', 'text', 'tweet_text', 'full_text', 'media_results', 'media'];
    for (let i: number = 0; i < interesting.length; i++) {
      const key: string = interesting[i];
      const value: Object | undefined = node[key];
      if (value === undefined || value === null) {
        continue;
      }
      if (typeof value === 'string') {
        lines.push(path + '.' + key + ' = "' + String(value).substring(0, 60) + '"');
        continue;
      }
      if (value instanceof Array) {
        const items: Array<Object> = value as Array<Object>;
        lines.push(path + '.' + key + '[] len=' + items.length);
        if (items.length > 0 && typeof items[0] === 'object' && !(items[0] instanceof Array)) {
          XTimelineParser.keySummary(items[0] as Record<string, Object>,
            path + '.' + key + '[0]', lines, depth - 1);
        }
        continue;
      }
      if (typeof value === 'object') {
        XTimelineParser.keySummary(value as Record<string, Object>, path + '.' + key, lines, depth - 1);
      }
    }
  }

  private static findTextlessTweet(node: Object, depth: number): Record<string, Object> {
    if (depth > 16 || node === null || node === undefined) {
      return {};
    }
    if (node instanceof Array) {
      const items: Array<Object> = node as Array<Object>;
      for (let i: number = 0; i < items.length; i++) {
        const found: Record<string, Object> = XTimelineParser.findTextlessTweet(items[i], depth + 1);
        if (Object.keys(found).length > 0) {
          return found;
        }
      }
      return {};
    }
    if (typeof node !== 'object') {
      return {};
    }
    const record: Record<string, Object> = node as Record<string, Object>;
    const legacy: Record<string, Object> = XTimelineParser.obj(record, 'legacy');
    const typeName: string = String(record['__typename'] ?? '');
    const looksLikeTweet: boolean = record['rest_id'] !== undefined &&
      (typeName === 'Tweet' || typeName === 'TweetWithVisibilityResults' ||
        String(legacy['full_text'] ?? '').length > 0);
    if (looksLikeTweet) {
      const tweet: Tweet | null = XTimelineParser.tweetFromNode(record);
      if (tweet !== null && tweet.text.length === 0) {
        return record;
      }
    }
    const keys: string[] = Object.keys(record);
    for (let i: number = 0; i < keys.length; i++) {
      const found: Record<string, Object> = XTimelineParser.findTextlessTweet(record[keys[i]], depth + 1);
      if (Object.keys(found).length > 0) {
        return found;
      }
    }
    return {};
  }

  static describeTextlessEntry(body: string, maxLines: number = 45): string {
    try {
      const json: Record<string, Object> = JSON.parse(body) as Record<string, Object>;
      const data: Record<string, Object> = XTimelineParser.obj(json, 'data');
      const timeline: Record<string, Object> = XTimelineParser.findTimeline(data);
      if (Object.keys(timeline).length === 0) {
        return 'no timeline in payload';
      }
      const instructions: Array<Record<string, Object>> =
        XTimelineParser.arr(timeline, 'instructions');
      for (let i: number = 0; i < instructions.length; i++) {
        const entries: Array<Record<string, Object>> =
          XTimelineParser.arr(instructions[i], 'entries');
        for (let e: number = 0; e < entries.length; e++) {
          const tweet: Tweet | null = XTimelineParser.entryTweet(entries[e]);
          if (tweet !== null && tweet.text.length === 0) {
            const lines: string[] = [];
            XTimelineParser.walk(entries[e], '$entry', lines, 0, maxLines);
            return lines.join('\n');
          }
        }
      }
      return XTimelineParser.describeFirstEntry(body, maxLines);
    } catch (e) {
      return 'textless entry dump failed';
    }
  }

  // Where a decoded post claims no attachments: shows the media containers of
  // the first tweet node so the reference-vs-object question is answered.
  static describeMedia(body: string): string {
    try {
      const json: Object = JSON.parse(body) as Object;
      const node: Record<string, Object> = XTimelineParser.findFirstTweet(json, 0);
      if (Object.keys(node).length === 0) {
        return 'no tweet node found';
      }
      const lines: string[] = [];
      const entities: Array<Record<string, Object>> = XTimelineParser.arr(node, 'media_entities');
      lines.push('media_entities len=' + entities.length);
      if (entities.length > 0) {
        XTimelineParser.keySummary(entities[0], 'media[0]', lines, 2);
      }
      const legacy: Record<string, Object> = XTimelineParser.obj(node, 'legacy');
      const extended: Record<string, Object> = XTimelineParser.obj(legacy, 'extended_entities');
      lines.push('legacy.extended_entities keys=[' + Object.keys(extended).join(',') + ']');
      return lines.join('\n');
    } catch (e) {
      return 'media dump failed';
    }
  }

  // Every cursor entry with its direction and payload length, used when a
  // timeline decodes but yields no paging token.
  static describeCursors(body: string): string {
    try {
      const json: Record<string, Object> = JSON.parse(body) as Record<string, Object>;
      const data: Record<string, Object> = XTimelineParser.obj(json, 'data');
      const timeline: Record<string, Object> = XTimelineParser.findTimeline(data);
      if (Object.keys(timeline).length === 0) {
        return 'no timeline in payload';
      }
      const lines: string[] = [];
      const instructions: Array<Record<string, Object>> =
        XTimelineParser.arr(timeline, 'instructions');
      for (let i: number = 0; i < instructions.length; i++) {
        const entries: Array<Record<string, Object>> =
          XTimelineParser.arr(instructions[i], 'entries');
        for (let e: number = 0; e < entries.length; e++) {
          XTimelineParser.appendCursorLine(entries[e], '', lines);
        }
        // Pages after the first replace the cursors, so the dump has to follow
        // that wrapper too or it reports "no cursor entry found" for a payload
        // that plainly carries one.
        const wrapped: Record<string, Object> = XTimelineParser.obj(instructions[i], 'entry');
        if (Object.keys(wrapped).length > 0) {
          XTimelineParser.appendCursorLine(wrapped,
            String(instructions[i]['entry_id_to_replace'] ?? ''), lines);
        }
      }
      return lines.length > 0 ? lines.join('\n') : 'no cursor entry found';
    } catch (e) {
      return 'cursor dump failed';
    }
  }

  private static appendCursorLine(entry: Record<string, Object>, replacedId: string,
    lines: string[]): void {
    const content: Record<string, Object> = XTimelineParser.obj(entry, 'content');
    const entryId: string = String(entry['entryId'] ?? entry['entry_id'] ?? '');
    const isCursor: boolean =
      XTimelineParser.contentType(content) === 'TimelineTimelineCursor' ||
      entryId.indexOf('cursor-') === 0;
    if (!isCursor) {
      return;
    }
    lines.push('entryId=' + entryId);
    if (replacedId.length > 0) {
      lines.push('  replaces=' + replacedId);
    }
    lines.push('  keys=[' + Object.keys(content).join(',') + ']');
    lines.push('  direction=' + String(content['cursor_type'] ?? content['cursorType'] ?? '-') +
      ' valueLen=' + String(content['value'] ?? '').length);
  }

  private static findFirstEntry(node: Object, depth: number): Record<string, Object> {
    if (depth > 16 || node === null || node === undefined) {
      return {};
    }
    if (node instanceof Array) {
      const items: Array<Object> = node as Array<Object>;
      for (let i: number = 0; i < items.length; i++) {
        const found: Record<string, Object> = XTimelineParser.findFirstEntry(items[i], depth + 1);
        if (Object.keys(found).length > 0) {
          return found;
        }
      }
      return {};
    }
    if (typeof node !== 'object') {
      return {};
    }
    const record: Record<string, Object> = node as Record<string, Object>;
    const content: Record<string, Object> = XTimelineParser.obj(record, 'content');
    if (record['entryId'] !== undefined &&
      Object.keys(XTimelineParser.obj(content, 'itemContent')).length > 0) {
      return record;
    }
    const keys: string[] = Object.keys(record);
    for (let i: number = 0; i < keys.length; i++) {
      const found: Record<string, Object> = XTimelineParser.findFirstEntry(record[keys[i]], depth + 1);
      if (Object.keys(found).length > 0) {
        return found;
      }
    }
    return {};
  }

  static describeFirstTweet(body: string, maxLines: number = 40): string {
    try {
      const json: Object = JSON.parse(body) as Object;
      const node: Record<string, Object> = XTimelineParser.findFirstTweet(json, 0);
      if (Object.keys(node).length === 0) {
        return 'no tweet node found';
      }
      const lines: string[] = [];
      XTimelineParser.walk(node, '$tweet', lines, 0, maxLines);
      return lines.join('\n');
    } catch (e) {
      return 'tweet shape dump failed';
    }
  }

  private static findFirstTweet(node: Object, depth: number): Record<string, Object> {
    if (depth > 16 || node === null || node === undefined) {
      return {};
    }
    if (node instanceof Array) {
      const items: Array<Object> = node as Array<Object>;
      for (let i: number = 0; i < items.length; i++) {
        const found: Record<string, Object> = XTimelineParser.findFirstTweet(items[i], depth + 1);
        if (Object.keys(found).length > 0) {
          return found;
        }
      }
      return {};
    }
    if (typeof node !== 'object') {
      return {};
    }
    const record: Record<string, Object> = node as Record<string, Object>;
    const legacy: Record<string, Object> = XTimelineParser.obj(record, 'legacy');
    const typeName: string = String(record['__typename'] ?? '');
    if (record['rest_id'] !== undefined &&
      (String(legacy['full_text'] ?? '').length > 0 || typeName === 'Tweet' ||
        typeName === 'TweetWithVisibilityResults')) {
      return record;
    }
    const keys: string[] = Object.keys(record);
    for (let i: number = 0; i < keys.length; i++) {
      const found: Record<string, Object> = XTimelineParser.findFirstTweet(record[keys[i]], depth + 1);
      if (Object.keys(found).length > 0) {
        return found;
      }
    }
    return {};
  }

  private static walk(node: Object, path: string, lines: string[], depth: number, maxLines: number): void {
    if (lines.length >= maxLines) {
      return;
    }
    if (node === null || node === undefined) {
      lines.push(path + ' = null');
      return;
    }
    if (node instanceof Array) {
      const items: Array<Object> = node as Array<Object>;
      lines.push(path + '[] len=' + items.length);
      // A histogram of the shapes in the array is far more informative than
      // element [0] alone: timeline arrays mix cursors, items and modules.
      if (items.length > 1) {
        const summary: string = XTimelineParser.summarize(items);
        if (summary.length > 0) {
          lines.push('    shapes: ' + summary);
        }
      }
      if (items.length > 0 && depth < 10) {
        XTimelineParser.walk(items[0], path + '[0]', lines, depth + 1, maxLines);
      }
      return;
    }
    if (typeof node !== 'object') {
      lines.push(path + ' = ' + JSON.stringify(node).substring(0, 70));
      return;
    }
    const record: Record<string, Object> = node as Record<string, Object>;
    const keys: string[] = Object.keys(record);
    if (depth >= 10) {
      lines.push(path + '.keys = [' + keys.slice(0, 14).join(',') + ']');
      return;
    }
    for (let i: number = 0; i < keys.length; i++) {
      if (lines.length >= maxLines) {
        return;
      }
      // Pure metadata: it is large and never holds timeline entries.
      if (keys[i] === 'responseObjects' || keys[i] === 'metadata') {
        continue;
      }
      XTimelineParser.walk(record[keys[i]], path + '.' + keys[i], lines, depth + 1, maxLines);
    }
  }

  // Counts how many elements carry each discriminator combination, so a shape
  // mismatch is visible without dumping the payload.
  private static summarize(items: Array<Object>): string {
    const counts: Map<string, number> = new Map();
    const limit: number = Math.min(items.length, 40);
    for (let i: number = 0; i < limit; i++) {
      const signature: string = XTimelineParser.signatureOf(items[i]);
      const seen: number | undefined = counts.get(signature);
      counts.set(signature, seen === undefined ? 1 : seen + 1);
    }
    const keys: string[] = Array.from(counts.keys());
    const parts: string[] = [];
    for (let i: number = 0; i < keys.length && i < 6; i++) {
      parts.push(keys[i] + ' x' + counts.get(keys[i]));
    }
    return parts.join(' | ');
  }

  private static signatureOf(item: Object): string {
    if (item === null || item === undefined || typeof item !== 'object' || item instanceof Array) {
      return 'scalar';
    }
    const record: Record<string, Object> = item as Record<string, Object>;
    const content: Record<string, Object> = XTimelineParser.obj(record, 'content');
    let signature: string = String(content['entryType'] ?? content['__typename'] ?? '-');
    const itemContent: Record<string, Object> = XTimelineParser.obj(content, 'itemContent');
    const itemType: string = String(itemContent['itemType'] ?? itemContent['__typename'] ?? '');
    if (itemType.length > 0) {
      signature += '/' + itemType;
    }
    const nested: Record<string, Object> = XTimelineParser.obj(
      XTimelineParser.obj(XTimelineParser.obj(content, 'items'), '0'), 'item');
    const nestedContent: Record<string, Object> = XTimelineParser.obj(nested, 'itemContent');
    const nestedType: string = String(nestedContent['itemType'] ?? nestedContent['__typename'] ?? '');
    if (nestedType.length > 0) {
      signature += '/item:' + nestedType;
    }
    const entryId: string = String(record['entryId'] ?? '');
    if (entryId.length > 0) {
      const dash: number = entryId.indexOf('-');
      signature += ' [' + (dash > 0 ? entryId.substring(0, dash) : entryId) + ']';
    }
    return signature;
  }

  private static tweetFromResult(tweetResults: Record<string, Object>, hintedId: string = ''): Tweet | null {
    const result: Record<string, Object> = XTimelineParser.obj(tweetResults, 'result');
    return XTimelineParser.tweetFromNode(result, hintedId);
  }

  // Builds a Tweet from a result node. The caller may pass either a Tweet or a
  // TweetWithVisibilityResults wrapper.
  private static tweetFromNode(input: Record<string, Object>, hintedId: string = ''): Tweet | null {
    if (Object.keys(input).length === 0) {
      return null;
    }
    let result: Record<string, Object> = input;
    // Visibility-limited posts wrap the real object one level deeper.
    if (String(result['__typename'] ?? '') === 'TweetWithVisibilityResults') {
      result = XTimelineParser.obj(result, 'tweet');
    }
    const unavailable: boolean = ['TweetTombstone', 'TweetUnavailable'].indexOf(String(result['__typename'] ?? '')) >= 0;
    const restId: string = String(result['rest_id'] ?? (unavailable ? hintedId : ''));
    if (restId.length === 0) {
      return null;
    }
    const legacy: Record<string, Object> = XTimelineParser.obj(result, 'legacy');
    const repost: Record<string, Object> = XTimelineParser.repostedPost(result, legacy);
    if (Object.keys(repost).length > 0 && String(repost['rest_id'] ?? '') !== restId) {
      const original: Tweet | null = XTimelineParser.tweetFromNode(repost);
      if (original !== null) {
        original.isRepost = true;
        original.repostAuthor = XTimelineParser.author(result);
        return original;
      }
    }
    const author: TweetAuthor = XTimelineParser.author(result);
    const perspective: Record<string, Object> = XTimelineParser.obj(result, 'perspective');
    const metrics: TweetMetrics = XTimelineParser.metrics(result, legacy);
    const quotedTweet: QuotedTweet | undefined = XTimelineParser.quotedTweet(result);
    const community: Record<string, Object> = XTimelineParser.communityNode(result);
    const reply: PostReplyRelation = XTimelineParser.replyRelation(result, legacy);
    return {
      id: restId,
      communityId: String(community['rest_id'] ?? community['id'] ?? ''),
      communityName: String(community['name'] ?? ''),
      author: author,
      text: XTimelineParser.text(result, legacy),
      language: String(legacy['lang'] ?? ''),
      editHistoryIds: postEditHistoryIds(result),
      createdAt: XTimelineParser.createdAt(result, legacy),
      metrics: metrics,
      liked: Boolean(perspective['favorited'] ?? legacy['favorited'] ?? false),
      reposted: Boolean(perspective['retweeted'] ?? legacy['retweeted'] ?? false),
      bookmarked: Boolean(perspective['bookmarked'] ?? legacy['bookmarked'] ?? false),
      isReply: reply.isReply,
      replyToTweetId: reply.parentId,
      replyToUsername: reply.username,
      conversationId: reply.conversationId,
      isRepost: XTimelineParser.isRepost(result, legacy),
      quotedTweet: quotedTweet,
      possiblySensitive: XTimelineParser.isPossiblySensitive(result, legacy),
      article: XArticleParser.parse(result),
      presentation: XPostPresentationParser.parse(input, result),
      poll: XPostCardParser.poll(result),
      card: XPostCardParser.link(result, restId),
      attachments: XTimelineParser.media(result, legacy,
        XTimelineParser.isPossiblySensitive(result, legacy))
    };
  }

  private static communityNode(node: Record<string, Object>): Record<string, Object> {
    const results: Record<string, Object> = XTimelineParser.obj(node, 'community_results');
    if (Object.keys(results).length > 0) { return XTimelineParser.obj(results, 'result'); }
    return XTimelineParser.obj(node, 'community');
  }

  private static attachCommunity(tweet: Tweet, node: Record<string, Object>): void {
    const community: Record<string, Object> = XTimelineParser.communityNode(node);
    const id: string = String(community['rest_id'] ?? community['id'] ?? '');
    const name: string = String(community['name'] ?? '');
    if (id.length > 0 && name.length > 0) { tweet.communityId = id; tweet.communityName = name; }
  }

  private static replyRelation(result: Record<string, Object>, legacy: Record<string, Object>): PostReplyRelation {
    const details: Record<string, Object> = XTimelineParser.obj(result, 'details');
    const parentId: string = String(legacy['in_reply_to_status_id_str'] ?? legacy['in_reply_to_status_id'] ?? '') ||
      String(details['in_reply_to_status_id_str'] ?? details['in_reply_to_status_id'] ?? '');
    const username: string = String(legacy['in_reply_to_screen_name'] ?? '') ||
      String(details['in_reply_to_screen_name'] ?? '');
    const userId: string = String(legacy['in_reply_to_user_id_str'] ?? legacy['in_reply_to_user_id'] ?? '') ||
      String(details['in_reply_to_user_id_str'] ?? details['in_reply_to_user_id'] ?? '');
    return { parentId: parentId, username: username,
      conversationId: String(legacy['conversation_id_str'] ?? legacy['conversation_id'] ?? '') ||
        String(details['conversation_id_str'] ?? details['conversation_id'] ?? ''),
      isReply: parentId.length > 0 || userId.length > 0 || username.length > 0 };
  }

  private static article(result: Record<string, Object>): ProfileArticle | undefined {
    const article: Record<string, Object> = XTimelineParser.obj(
      XTimelineParser.obj(XTimelineParser.obj(result, 'article'), 'article_results'), 'result');
    if (String(article['rest_id'] ?? '').length === 0) {
      return undefined;
    }
    const media: Record<string, Object> = XTimelineParser.obj(
      XTimelineParser.obj(article, 'cover_media_results'), 'result');
    const info: Record<string, Object> = XTimelineParser.obj(media, 'media_info');
    return { id: String(article['rest_id']), title: String(article['title'] ?? ''),
      previewText: String(article['preview_text'] ?? ''), coverUrl: String(info['original_img_url'] ?? '') };
  }

  private static isRepost(result: Record<string, Object>, legacy: Record<string, Object>): boolean {
    if (Object.keys(XTimelineParser.repostedPost(result, legacy)).length > 0) {
      return true;
    }
    if (Object.keys(XTimelineParser.obj(result, 'retweeted_status_result')).length > 0 ||
      Object.keys(XTimelineParser.obj(result, 'retweetedStatusResult')).length > 0 ||
      Object.keys(XTimelineParser.obj(legacy, 'retweeted_status_result')).length > 0 ||
      Object.keys(XTimelineParser.obj(legacy, 'retweeted_status')).length > 0) {
      return true;
    }
    const text: string = String(legacy['full_text'] ?? legacy['text'] ?? '');
    return text.startsWith('RT @');
  }

  private static repostedPost(result: Record<string, Object>, legacy: Record<string, Object>): Record<string, Object> {
    const wrappers: Record<string, Object>[] = [
      XTimelineParser.obj(legacy, 'repostedStatusResults'),
      XTimelineParser.obj(legacy, 'retweeted_status_results'),
      XTimelineParser.obj(legacy, 'retweeted_status_result'),
      XTimelineParser.obj(result, 'retweeted_status_result'),
      XTimelineParser.obj(result, 'retweetedStatusResult')
    ];
    for (let i: number = 0; i < wrappers.length; i++) {
      let post: Record<string, Object> = XTimelineParser.obj(wrappers[i], 'result');
      if (String(post['__typename'] ?? '') === 'TweetWithVisibilityResults') {
        post = XTimelineParser.obj(post, 'tweet');
      }
      if (String(post['rest_id'] ?? '').length > 0) {
        return post;
      }
    }
    return XTimelineParser.obj(legacy, 'retweeted_status');
  }

  private static createdAt(result: Record<string, Object>, legacy: Record<string, Object>): string {
    const details: Record<string, Object> = XTimelineParser.obj(result, 'details');
    const timestamp: number = Number(details['created_at_ms'] ?? 0);
    if (timestamp > 0 && !isNaN(timestamp)) {
      return new Date(timestamp).toISOString();
    }
    return String(details['created_at'] ?? legacy['created_at'] ?? '');
  }

  private static quotedTweet(result: Record<string, Object>): QuotedTweet | undefined {
    const keys: string[] = ['quotedPostResults', 'quoted_post_results', 'quotedTweetResults',
      'quoted_tweet_results', 'quoted_status_result'];
    let wrapper: Record<string, Object> = {};
    for (let i: number = 0; i < keys.length; i++) {
      const candidate: Record<string, Object> = XTimelineParser.obj(result, keys[i]);
      if (Object.keys(candidate).length > 0) {
        wrapper = candidate;
        break;
      }
    }
    if (Object.keys(wrapper).length === 0) {
      const legacy: Record<string, Object> = XTimelineParser.obj(result, 'legacy');
      for (let i: number = 0; i < keys.length; i++) {
        const candidate: Record<string, Object> = XTimelineParser.obj(legacy, keys[i]);
        if (Object.keys(candidate).length > 0) {
          wrapper = candidate;
          break;
        }
      }
    }
    if (Object.keys(wrapper).length === 0) {
      return undefined;
    }
    let quote: Record<string, Object> = XTimelineParser.obj(wrapper, 'result');
    if (Object.keys(quote).length === 0) {
      quote = wrapper;
    }
    const outer: Record<string, Object> = quote;
    if (String(quote['__typename'] ?? '') === 'TweetWithVisibilityResults') {
      quote = XTimelineParser.obj(quote, 'tweet');
    }
    const originalLegacy: Record<string, Object> = XTimelineParser.obj(result, 'legacy');
    const id: string = String(quote['rest_id'] ?? originalLegacy['quoted_status_id_str'] ?? '');
    if (id.length === 0) {
      return undefined;
    }
    const legacy: Record<string, Object> = XTimelineParser.obj(quote, 'legacy');
    const reply: PostReplyRelation = XTimelineParser.replyRelation(quote, legacy);
    return {
      id: id,
      author: XTimelineParser.author(quote),
      text: XTimelineParser.text(quote, legacy),
      createdAt: XTimelineParser.createdAt(quote, legacy),
      editHistoryIds: postEditHistoryIds(quote),
      isReply: reply.isReply, replyToTweetId: reply.parentId, replyToUsername: reply.username,
      poll: XPostCardParser.poll(quote),
      card: XPostCardParser.link(quote, id),
      article: XArticleParser.parse(quote),
      presentation: XPostPresentationParser.parse(outer, quote),
      possiblySensitive: XTimelineParser.isPossiblySensitive(quote, legacy),
      attachments: XTimelineParser.media(quote, legacy,
        XTimelineParser.isPossiblySensitive(quote, legacy))
    };
  }

  // Depth-first scan for tweet objects, used when the strict entry walk finds
  // nothing. Document order matches timeline order closely enough for a feed.
  private static harvest(node: Object, out: Tweet[], depth: number): void {
    if (depth > 16 || out.length >= 200) {
      return;
    }
    if (node === null || node === undefined) {
      return;
    }
    if (node instanceof Array) {
      const items: Array<Object> = node as Array<Object>;
      for (let i: number = 0; i < items.length; i++) {
        XTimelineParser.harvest(items[i], out, depth + 1);
      }
      return;
    }
    if (typeof node !== 'object') {
      return;
    }
    const record: Record<string, Object> = node as Record<string, Object>;
    const typeName: string = String(record['__typename'] ?? '');
    // Accept either the declared typename or anything carrying a rest_id plus
    // rendered text, so a renamed wrapper does not hide the whole feed.
    const legacyProbe: Record<string, Object> = XTimelineParser.obj(record, 'legacy');
    const looksLikeTweet: boolean = record['rest_id'] !== undefined &&
      (typeName === 'Tweet' || typeName === 'TweetWithVisibilityResults' ||
        String(legacyProbe['full_text'] ?? '').length > 0);
    if (looksLikeTweet) {
      const tweet: Tweet | null = XTimelineParser.tweetFromNode(record);
      if (tweet !== null && tweet.text.length > 0) {
        out.push(tweet);
        return;
      }
      // A node can look like a tweet but only wrap the real one (visibility and
      // retweet wrappers both do this). Prefer a nested post that carries a
      // body; fall back to the wrapper only when nothing better is inside.
      const before: number = out.length;
      const keys: string[] = Object.keys(record);
      for (let i: number = 0; i < keys.length; i++) {
        XTimelineParser.harvest(record[keys[i]], out, depth + 1);
      }
      if (out.length === before && tweet !== null) {
        out.push(tweet);
      }
      return;
    }
    const keys: string[] = Object.keys(record);
    for (let i: number = 0; i < keys.length; i++) {
      // A quoted post is not a feed row of its own.
      if (keys[i] === 'quotedPostResults' || keys[i] === 'quoted_tweet_results') {
        continue;
      }
      XTimelineParser.harvest(record[keys[i]], out, depth + 1);
    }
  }

  private static author(result: Record<string, Object>): TweetAuthor {
    let user: Record<string, Object> = XTimelineParser.findUserNode(result);
    if (Object.keys(user).length === 0) {
      const authorId: string = XTimelineParser.authorId(result);
      if (authorId.length > 0) {
        const fromSideTable: Record<string, Object> | undefined =
          XTimelineParser.users.get(authorId);
        if (fromSideTable !== undefined) {
          user = fromSideTable;
        }
      }
    }
    if (Object.keys(user).length === 0) {
      return {
        id: XTimelineParser.authorId(result),
        name: 'X User',
        username: 'x',
        avatarColor: '#1D9BF0',
        avatarUrl: '',
        verified: false
      };
    }
    const userCore: Record<string, Object> = XTimelineParser.obj(user, 'core');
    // Newer responses put identity on `core`; older ones only fill `legacy`.
    const legacy: Record<string, Object> = XTimelineParser.obj(user, 'legacy');
    const avatar: Record<string, Object> = XTimelineParser.obj(user, 'avatar');
    const name: string = String(userCore['name'] ?? legacy['name'] ?? 'X User');
    const username: string = String(userCore['screen_name'] ?? legacy['screen_name'] ?? 'x');
    let avatarUrl: string = XTimelineParser.highResAvatarUrl(String(avatar['image_url'] ?? ''));
    if (avatarUrl.length === 0) {
      avatarUrl = XTimelineParser.highResAvatarUrl(String(legacy['profile_image_url_https'] ?? ''));
    }
    return {
      id: String(user['rest_id'] ?? username),
      name: name,
      username: username,
      avatarColor: '#1D9BF0',
      avatarUrl: avatarUrl,
      following: Boolean(XTimelineParser.obj(user, 'relationship_perspectives')['following'] ?? legacy['following'] ?? false),
      verified: userIsVerified(user), verifiedType: userVerifiedType(user), avatarShape: userAvatarShape(user)
    };
  }

  private static authorId(result: Record<string, Object>): string {
    const legacy: Record<string, Object> = XTimelineParser.obj(result, 'legacy');
    const core: Record<string, Object> = XTimelineParser.obj(result, 'core');
    return String(legacy['user_id_str'] ?? legacy['user_id'] ??
      XTimelineParser.obj(core, 'user_results')['rest_id'] ??
      XTimelineParser.obj(core, 'user_result')['rest_id'] ?? '');
  }

  // Only explicit author routes are valid. A tweet can also contain its
  // community creator, members, viewer and quoted author; scanning those
  // subtrees for the first user silently attributes the post to someone else.
  private static findUserNode(result: Record<string, Object>): Record<string, Object> {
    const authorId: string = XTimelineParser.authorId(result);
    const routes: string[] = [
      'core.user_results.result',
      'core.user_result.result',
      'author_results.result',
      'author_result.result',
      'user_results.result',
      'user_result.result',
      'core.author_results.result',
      'core.author_result.result',
      'author',
      'user'
    ];
    for (let i: number = 0; i < routes.length; i++) {
      const candidate: Record<string, Object> = XTimelineParser.follow(result, routes[i]);
      const candidateId: string = String(candidate['rest_id'] ?? XTimelineParser.obj(candidate, 'legacy')['id_str'] ?? '');
      if (XTimelineParser.looksLikeUser(candidate) &&
        (authorId.length === 0 || candidateId === authorId)) {
        return candidate;
      }
    }
    return {};
  }

  private static highResAvatarUrl(url: string): string {
    let out: string = url;
    out = XTimelineParser.replaceQueryAvatarSize(out, 'normal');
    out = XTimelineParser.replaceQueryAvatarSize(out, 'bigger');
    out = XTimelineParser.replaceQueryAvatarSize(out, 'mini');
    return XTimelineParser.replacePathAvatarSize(out);
  }

  private static replaceQueryAvatarSize(url: string, size: string): string {
    const token: string = 'name=' + size;
    const index: number = url.indexOf(token);
    if (index < 0) {
      return url;
    }
    return url.substring(0, index) + 'name=400x400' + url.substring(index + token.length);
  }

  private static replacePathAvatarSize(url: string): string {
    const markers: string[] = ['_normal.', '_bigger.', '_mini.'];
    for (let i: number = 0; i < markers.length; i++) {
      const marker: string = markers[i];
      const index: number = url.indexOf(marker);
      if (index >= 0) {
        return url.substring(0, index) + '_400x400.' + url.substring(index + marker.length);
      }
    }
    return url;
  }

  private static follow(source: Record<string, Object>, path: string): Record<string, Object> {
    const parts: string[] = path.split('.');
    let node: Record<string, Object> = source;
    for (let i: number = 0; i < parts.length; i++) {
      node = XTimelineParser.obj(node, parts[i]);
      if (Object.keys(node).length === 0) {
        return {};
      }
    }
    return node;
  }

  private static looksLikeUser(node: Record<string, Object>): boolean {
    if (Object.keys(node).length === 0) {
      return false;
    }
    const core: Record<string, Object> = XTimelineParser.obj(node, 'core');
    const legacy: Record<string, Object> = XTimelineParser.obj(node, 'legacy');
    const name: string = String(core['name'] ?? legacy['name'] ?? '');
    const handle: string = String(core['screen_name'] ?? legacy['screen_name'] ?? '');
    return name.length > 0 && handle.length > 0;
  }

  // Registers every user-shaped object in the payload so authors can be
  // resolved by id when they are not nested in the tweet.
  private static collectUsers(node: Object, depth: number): void {
    if (depth > 24 || XTimelineParser.users.size > 400) {
      return;
    }
    if (node === null || node === undefined) {
      return;
    }
    if (node instanceof Array) {
      const items: Array<Object> = node as Array<Object>;
      for (let i: number = 0; i < items.length; i++) {
        XTimelineParser.collectUsers(items[i], depth + 1);
      }
      return;
    }
    if (typeof node !== 'object') {
      return;
    }
    const record: Record<string, Object> = node as Record<string, Object>;
    if (XTimelineParser.looksLikeUser(record)) {
      const id: string = String(record['rest_id'] ?? '');
      if (id.length > 0 && !XTimelineParser.users.has(id)) {
        XTimelineParser.users.set(id, record);
      }
    }
    const keys: string[] = Object.keys(record);
    for (let i: number = 0; i < keys.length; i++) {
      XTimelineParser.collectUsers(record[keys[i]], depth + 1);
    }
  }

  private static metrics(result: Record<string, Object>, legacy: Record<string, Object>): TweetMetrics {
    // The flat schema moved engagement counts out of legacy into "counts", so
    // read that first and fall back to the legacy field names.
    const counts: Record<string, Object> = XTimelineParser.obj(result, 'counts');
    const views: Record<string, Object> = XTimelineParser.obj(result, 'views');
    const viewCounts: Record<string, Object> = XTimelineParser.obj(result, 'view_count');
    const legacyViews: Record<string, Object> = XTimelineParser.obj(legacy, 'view_count');
    const viewCount: number = Number(views['count'] ?? viewCounts['count'] ?? legacyViews['count'] ??
      counts['view_count'] ?? counts['impression_count'] ?? legacy['view_count'] ??
      legacy['impression_count'] ?? 0);
    return {
      replyCount: XTimelineParser.num(counts, 'reply_count') > 0 ?
        XTimelineParser.num(counts, 'reply_count') : XTimelineParser.num(legacy, 'reply_count'),
      repostCount: XTimelineParser.num(counts, 'retweet_count') > 0 ?
        XTimelineParser.num(counts, 'retweet_count') : XTimelineParser.num(legacy, 'retweet_count'),
      likeCount: XTimelineParser.num(counts, 'like_count') > 0 ?
        XTimelineParser.num(counts, 'like_count') :
        Number(counts['favorite_count'] ?? legacy['favorite_count'] ?? 0),
      viewCount: !isFinite(viewCount) || viewCount < 0 ? 0 : viewCount,
      bookmarkCount: optionalPostCount(counts['bookmark_count'] ?? legacy['bookmark_count']),
      quoteCount: optionalPostCount(counts['quote_count'] ?? legacy['quote_count'])
    };
  }

  // Long posts keep the visible body in note_tweet; legacy.full_text is a
  // truncated preview ending in an ellipsis link.
  private static text(result: Record<string, Object>, legacy: Record<string, Object>): string {
    // Flat schema: the body sits in "details".
    const details: Record<string, Object> = XTimelineParser.obj(result, 'details');
    const detailsText: string = String(details['full_text'] ?? details['text'] ?? '');
    if (detailsText.length > 0) {
      return XTimelineParser.displayText(detailsText, result, legacy);
    }
    const note: Record<string, Object> = XTimelineParser.obj(
      XTimelineParser.obj(result, 'note_tweet'), 'note_tweet_results');
    const noteResult: Record<string, Object> = XTimelineParser.obj(note, 'result');
    const noteText: string = String(noteResult['text'] ?? '');
    if (noteText.length > 0) {
      return noteText;
    }
    const legacyText: string = String(legacy['full_text'] ?? legacy['text'] ?? '');
    if (legacyText.length > 0) {
      return XTimelineParser.displayText(legacyText, result, legacy);
    }
    // Some surfaces place the body on the tweet node itself, or on a nested
    // "tweet" wrapper (visibility-limited results).
    const direct: string = String(result['full_text'] ?? result['text'] ?? '');
    if (direct.length > 0) {
      return direct;
    }
    const inner: Record<string, Object> = XTimelineParser.obj(result, 'tweet');
    const innerText: string = String(inner['full_text'] ?? inner['text'] ?? '');
    if (innerText.length > 0) {
      return innerText;
    }
    // Last resort: search the node for a body field. Containers that only hold
    // hashtag or mention labels are skipped so a tag is never mistaken for the
    // post text.
    return XTimelineParser.findText(result, 0);
  }

  private static displayText(text: string, result: Record<string, Object>, legacy: Record<string, Object>): string {
    const details: Record<string, Object> = XTimelineParser.obj(result, 'details');
    const rawRange: Object | undefined = details['display_text_range'] ?? legacy['display_text_range'];
    const offsets: number[] = XTimelineParser.codePointOffsets(text);
    const tailCodes: string[] = [];
    for (let diagnosticIndex: number = Math.max(0, text.length - 8); diagnosticIndex < text.length; diagnosticIndex++) {
      tailCodes.push(text.charCodeAt(diagnosticIndex).toString(16));
    }
    hilog.warn(0xFF00, 'HarmonyX-Emoji-Diag', 'id=%{public}s rawUnits=%{public}d points=%{public}d range=%{public}s tail=%{public}s',
      String(result['rest_id'] ?? ''), text.length, offsets.length - 1, JSON.stringify(rawRange), tailCodes.join(','));
    if (rawRange instanceof Array) {
      const range: number[] = rawRange as number[];
      if (range.length >= 2 && Number.isInteger(range[0]) && Number.isInteger(range[1]) &&
        range[0] >= 0 && range[1] >= range[0]) {
        // X display ranges count Unicode code points. JS/ArkTS substring uses
        // UTF-16 units and can cut a final emoji in half or drop text after it.
        if (range[1] < offsets.length) {
          return text.substring(offsets[range[0]], offsets[range[1]]);
        }
        // Some locally normalized responses supply a full UTF-16 range.
        // Accept that compatibility form only at complete code-point boundaries.
        if (range[1] <= text.length && XTimelineParser.codePointBoundary(text, range[0]) &&
          XTimelineParser.codePointBoundary(text, range[1])) {
          return text.substring(range[0], range[1]);
        }
      }
    }
    // These short URLs point to the attached media already shown below the
    // body. Remove only an exact trailing media URL, keeping ordinary links.
    let visible: string = text;
    const media: Array<Record<string, Object>> = XTimelineParser.arr(
      XTimelineParser.obj(legacy, 'extended_entities'), 'media');
    for (let i: number = 0; i < media.length; i++) {
      const url: string = String(media[i]['url'] ?? '');
      const withoutTrailingSpace: string = visible.trimEnd();
      const start: number = withoutTrailingSpace.length - url.length;
      if (url.length > 0 && withoutTrailingSpace.endsWith(url) &&
        (start === 0 || /\s/.test(withoutTrailingSpace.charAt(start - 1)))) {
        // Remove the attachment separator, preserving authored stanza breaks.
        visible = withoutTrailingSpace.substring(0, start).replace(/[ \t]+$/, '');
      }
    }
    return visible;
  }

  private static codePointBoundary(text: string, index: number): boolean {
    if (index <= 0 || index >= text.length) { return true; }
    const current: number = text.charCodeAt(index);
    const previous: number = text.charCodeAt(index - 1);
    return !(current >= 0xDC00 && current <= 0xDFFF && previous >= 0xD800 && previous <= 0xDBFF);
  }

  private static codePointOffsets(text: string): number[] {
    // Array.from(string) on the device's ArkTS runtime yielded UTF-16 units.
    // Walk surrogate pairs explicitly instead of relying on string iteration.
    const offsets: number[] = [0];
    let index: number = 0;
    while (index < text.length) {
      const high: number = text.charCodeAt(index);
      const low: number = text.charCodeAt(index + 1);
      index += high >= 0xD800 && high <= 0xDBFF && low >= 0xDC00 && low <= 0xDFFF ? 2 : 1;
      offsets.push(index);
    }
    return offsets;
  }

  private static findText(node: Record<string, Object>, depth: number): string {
    if (depth > 3) {
      return '';
    }
    const direct: string = String(node['full_text'] ?? node['tweet_text'] ?? '');
    if (direct.length > 0) {
      return direct;
    }
    // "details" is where the flat, newer tweet schema keeps the body; the rest
    // are the legacy and wrapper paths.
    const containers: string[] = ['details', 'legacy', 'note_tweet', 'note_tweet_results',
      'tweet_results', 'result', 'tweet', 'core', 'text'];
    for (let i: number = 0; i < containers.length; i++) {
      const key: string = containers[i];
      if (key === 'text') {
        const value: Object | undefined = node['text'];
        if (value !== undefined && value !== null) {
          if (typeof value === 'string') {
            return String(value);
          }
          // Some revisions model the body as an object wrapper.
          if (typeof value === 'object' && !(value instanceof Array)) {
            const nested: string = String((value as Record<string, Object>)['text'] ?? '');
            if (nested.length > 0) {
              return nested;
            }
          }
        }
        continue;
      }
      const child: Record<string, Object> = XTimelineParser.obj(node, key);
      if (Object.keys(child).length === 0) {
        continue;
      }
      const found: string = XTimelineParser.findText(child, depth + 1);
      if (found.length > 0) {
        return found;
      }
    }
    return '';
  }

  private static isPossiblySensitive(result: Record<string, Object>, legacy: Record<string, Object>): boolean {
    return Boolean(result['possibly_sensitive']) || Boolean(legacy['possibly_sensitive']);
  }

  private static media(result: Record<string, Object>, legacy: Record<string, Object>,
    sensitive: boolean): MediaAttachment[] {
    // Flat schema keeps attachments in media_entities; the legacy paths put
    // them under extended_entities (all of them) or entities (a single one).
    // Whichever source actually yields usable attachments wins, so a present
    // but unusable flat list cannot hide a working legacy one.
    const flat: MediaAttachment[] =
      XTimelineParser.buildAttachments(XTimelineParser.arr(result, 'media_entities'), sensitive);
    if (flat.length > 0) {
      return flat;
    }
    const extended: MediaAttachment[] = XTimelineParser.buildAttachments(
      XTimelineParser.arr(XTimelineParser.obj(legacy, 'extended_entities'), 'media'), sensitive);
    if (extended.length > 0) {
      return extended;
    }
    const entities: MediaAttachment[] = XTimelineParser.buildAttachments(
      XTimelineParser.arr(XTimelineParser.obj(legacy, 'entities'), 'media'), sensitive);
    if (entities.length > 0) {
      return entities;
    }
    // Long-form posts hang their attachments off the note object and reference
    // them by media_id only, so they resolve through the payload media table.
    return XTimelineParser.noteTweetMedia(result, sensitive);
  }

  private static noteTweetMedia(result: Record<string, Object>, sensitive: boolean): MediaAttachment[] {
    const note: Record<string, Object> = XTimelineParser.obj(result, 'note_tweet');
    const results: Record<string, Object> = XTimelineParser.obj(note, 'note_tweet_results');
    const notePost: Record<string, Object> = XTimelineParser.obj(results, 'result');
    const holder: Record<string, Object> = XTimelineParser.obj(notePost, 'media');
    const inline: Array<Record<string, Object>> = XTimelineParser.arr(holder, 'inline_media');
    if (inline.length > 0) {
      return XTimelineParser.buildAttachments(inline, sensitive);
    }
    return XTimelineParser.buildAttachments(XTimelineParser.arr(holder, 'media'), sensitive);
  }

  private static buildAttachments(rawMedia: Array<Record<string, Object>>, sensitive: boolean): MediaAttachment[] {
    const out: MediaAttachment[] = [];
    for (let i: number = 0; i < rawMedia.length; i++) {
      const item: Record<string, Object> | undefined =
        XTimelineParser.resolveMediaNode(rawMedia[i]);
      if (item === undefined) {
        continue;
      }
      // The newer shape nests dimensions and URLs under media_info; the classic
      // one keeps them on the object itself.
      const info: Record<string, Object> = XTimelineParser.obj(item, 'media_info');
      // Search answers deepen the still image one level further, as
      // media_info.preview_image, which carries its own preview/original URLs
      // and sizes. Missing this is what left search-video cells without a
      // cover while the home timeline had one.
      const preview: Record<string, Object> = XTimelineParser.obj(info, 'preview_image');
      const original: Record<string, Object> = XTimelineParser.obj(item, 'original_info');
      // Legacy tweet entities keep the actual pixel dimensions in a named
      // rendition, most often `sizes.large.w/h`. The sensitive-media cover
      // needs these rather than falling back to a generic card height.
      const sizes: Record<string, Object> = XTimelineParser.obj(item, 'sizes');
      const sizeSources: Record<string, Object>[] = [
        XTimelineParser.obj(sizes, 'large'),
        XTimelineParser.obj(sizes, 'orig'),
        XTimelineParser.obj(sizes, 'medium'),
        XTimelineParser.obj(sizes, 'small')
      ];
      const photoUrl: string = String(info['original_img_url'] ??
        preview['original_img_url'] ?? item['media_url_https'] ?? info['preview_img_url'] ??
        preview['preview_img_url'] ?? item['media_url'] ?? '');
      let previewUrl: string = String(info['preview_img_url'] ?? preview['preview_img_url'] ??
        item['preview_image_url'] ?? item['media_url_https'] ?? '');
      if (previewUrl.length === 0) {
        previewUrl = photoUrl;
      }
      const variants: Array<Record<string, Object>> = XTimelineParser.variantsOf(item);
      let width: number = XTimelineParser.num(info, 'original_img_width');
      if (width === 0) {
        width = XTimelineParser.num(preview, 'original_img_width');
      }
      if (width === 0) {
        width = XTimelineParser.num(preview, 'preview_img_width');
      }
      if (width === 0) {
        width = XTimelineParser.num(original, 'width');
      }
      if (width === 0) {
        width = XTimelineParser.num(info, 'width');
      }
      if (width === 0) {
        width = XTimelineParser.num(item, 'width');
      }
      for (let sizeIndex: number = 0; sizeIndex < sizeSources.length && width === 0; sizeIndex++) {
        width = XTimelineParser.num(sizeSources[sizeIndex], 'w');
      }
      let height: number = XTimelineParser.num(info, 'original_img_height');
      if (height === 0) {
        height = XTimelineParser.num(preview, 'original_img_height');
      }
      if (height === 0) {
        height = XTimelineParser.num(preview, 'preview_img_height');
      }
      if (height === 0) {
        height = XTimelineParser.num(original, 'height');
      }
      if (height === 0) {
        height = XTimelineParser.num(info, 'height');
      }
      if (height === 0) {
        height = XTimelineParser.num(item, 'height');
      }
      for (let sizeIndex: number = 0; sizeIndex < sizeSources.length && height === 0; sizeIndex++) {
        height = XTimelineParser.num(sizeSources[sizeIndex], 'h');
      }
      const declared: string = String(item['type'] ?? '');
      const type: string = XTimelineParser.mediaType(item, info, declared, variants.length > 0);
      let mediaUrl: string = photoUrl;
      let feedUrl: string = '';
      let durationMs: number = XTimelineParser.num(info, 'duration_millis');
      if (durationMs === 0) {
        durationMs = XTimelineParser.num(info, 'duration_ms');
      }
      const videoInfo: Record<string, Object> = XTimelineParser.obj(info, 'video_info');
      if (durationMs === 0) {
        durationMs = XTimelineParser.num(videoInfo, 'duration_millis');
      }
      if (durationMs === 0) {
        durationMs = XTimelineParser.num(item, 'duration_millis');
      }
      if (variants.length > 0) {
        // Two renditions of the same video: the heaviest for fullscreen, the
        // lightest watchable one for an inline cell. Picking the small one for
        // the feed is what makes a search result start quickly instead of
        // buffering a 720p stream behind a black surface.
        const heaviest: string = XTimelineParser.bestVariant(variants, true);
        const lightest: string = XTimelineParser.bestVariant(variants, false);
        if (heaviest.length > 0) {
          mediaUrl = heaviest;
          feedUrl = lightest.length > 0 ? lightest : heaviest;
        } else if (XTimelineParser.isVideoLike(type)) {
          // AVPlayer accepts HLS streams as well. Keep an HLS-only upload
          // playable when X does not expose an MP4 rendition.
          mediaUrl = XTimelineParser.hlsVariant(variants);
          feedUrl = mediaUrl;
        }
      }
      out.push({
        id: String(item['id_str'] ?? item['media_id'] ?? item['id'] ?? ('media-' + i)),
        type: type,
        mediaUrl: mediaUrl,
        feedUrl: feedUrl,
        videoVariantUrls: XTimelineParser.videoVariantUrls(variants),
        videoVariants: XTimelineParser.videoRenditions(variants),
        durationMs: durationMs,
        previewUrl: previewUrl,
        width: width,
        height: height,
        altText: String(item['ext_alt_text'] ?? info['ext_alt_text'] ?? ''),
        sensitive: sensitive
      });
      if (XTimelineParser.isVideoLike(type)) {
        // Which rendition a cell got and whether the payload shipped a still
        // image at all: the two things that decide if a feed shows a cover or
        // an empty box.
        hilog.info(DOMAIN, TAG,
          'video id=%{public}s poster=%{public}d stream=%{public}d feed=%{public}d variants=%{public}d',
          String(item['id_str'] ?? item['media_id'] ?? item['id'] ?? ''), previewUrl.length,
          mediaUrl.length, feedUrl.length, variants.length);
      }
    }
    return out;
  }

  // Variants live in media_info, video_info or on the object, depending on the
  // schema revision.
  private static variantsOf(item: Record<string, Object>): Array<Record<string, Object>> {
    const info: Record<string, Object> = XTimelineParser.obj(item, 'media_info');
    const sources: Record<string, Object>[] = [
      info,
      XTimelineParser.obj(info, 'video_info'),
      XTimelineParser.obj(item, 'video_info'),
      item
    ];
    for (let i: number = 0; i < sources.length; i++) {
      const found: Array<Record<string, Object>> = XTimelineParser.arr(sources[i], 'variants');
      if (found.length > 0) {
        return found;
      }
    }
    return [];
  }

  private static mediaType(item: Record<string, Object>, info: Record<string, Object>,
    declared: string, hasVideo: boolean): string {
    // The flat schema tags the media with __typename only: ApiVideo, ApiGif
    // (an MP4 that loops) or ApiPhoto.
    const stamp: string = String(info['__typename'] ?? item['__typename'] ?? '');
    return normalizedPostMediaType(declared, stamp, hasVideo);
  }

  private static isVideoLike(type: string): boolean {
    return type === 'video' || type === 'animated_gif';
  }

  // Every X video ships one MP4 per rendition, each with its own bitrate.
  // heaviest = the fullscreen copy, otherwise the lightest copy that is still
  // watchable at feed size. A video whose variants carry no bitrate at all
  // falls back to whatever rendition was found.
  private static bestVariant(variants: Array<Record<string, Object>>, heaviest: boolean): string {
    let selected: string = '';
    let selectedBitrate: number = -1;
    let lightest: string = '';
    let lightestBitrate: number = -1;
    for (let i: number = 0; i < variants.length; i++) {
      const variant: Record<string, Object> = variants[i];
      const url: string = String(variant['url'] ?? variant['src'] ?? '');
      if (url.length === 0) {
        continue;
      }
      let contentType: string = String(variant['content_type'] ?? variant['contentType'] ?? '');
      if (contentType.length === 0 && url.indexOf('.mp4') >= 0) {
        contentType = 'video/mp4';
      }
      if (contentType !== 'video/mp4') {
        continue;
      }
      let bitrate: number = XTimelineParser.num(variant, 'bit_rate');
      if (bitrate === 0) {
        bitrate = XTimelineParser.num(variant, 'bitrate');
      }
      if (lightest.length === 0 || bitrate < lightestBitrate) {
        lightest = url;
        lightestBitrate = bitrate;
      }
      const better: boolean = heaviest ? bitrate > selectedBitrate :
        (bitrate >= FEED_BITRATE_FLOOR && (selected.length === 0 || bitrate < selectedBitrate));
      if (better) {
        selected = url;
        selectedBitrate = bitrate;
      }
    }
    return selected.length > 0 ? selected : lightest;
  }

  // Keep every playable rendition so the player can step down when one CDN
  // URL is stale or a particular bitrate fails on the current connection.
  private static videoVariantUrls(variants: Array<Record<string, Object>>): string[] {
    const urls: string[] = [];
    const bitrates: number[] = [];
    for (let i: number = 0; i < variants.length; i++) {
      const variant: Record<string, Object> = variants[i];
      const url: string = String(variant['url'] ?? variant['src'] ?? '');
      if (url.length === 0) {
        continue;
      }
      let contentType: string = String(variant['content_type'] ?? variant['contentType'] ?? '');
      if (contentType.length === 0 && url.toLowerCase().indexOf('.mp4') >= 0) {
        contentType = 'video/mp4';
      }
      if (contentType !== 'video/mp4' || urls.indexOf(url) >= 0) {
        continue;
      }
      let bitrate: number = XTimelineParser.num(variant, 'bit_rate');
      if (bitrate === 0) {
        bitrate = XTimelineParser.num(variant, 'bitrate');
      }
      let insertAt: number = urls.length;
      for (let j: number = 0; j < bitrates.length; j++) {
        if (bitrate < bitrates[j]) {
          insertAt = j;
          break;
        }
      }
      urls.splice(insertAt, 0, url);
      bitrates.splice(insertAt, 0, bitrate);
    }
    const hls: string = XTimelineParser.hlsVariant(variants);
    if (hls.length > 0 && urls.indexOf(hls) < 0) {
      urls.push(hls);
    }
    return urls;
  }

  private static videoRenditions(variants: Array<Record<string, Object>>): VideoRendition[] {
    const out: VideoRendition[] = [];
    for (let i: number = 0; i < variants.length; i++) {
      const variant: Record<string, Object> = variants[i];
      const url: string = String(variant['url'] ?? variant['src'] ?? '');
      if (url.length === 0) {
        continue;
      }
      let contentType: string = String(variant['content_type'] ?? variant['contentType'] ?? '');
      if (contentType.length === 0 && url.toLowerCase().indexOf('.mp4') >= 0) {
        contentType = 'video/mp4';
      }
      if (contentType !== 'video/mp4') {
        continue;
      }
      let bitrate: number = XTimelineParser.num(variant, 'bit_rate');
      if (bitrate === 0) {
        bitrate = XTimelineParser.num(variant, 'bitrate');
      }
      let width: number = XTimelineParser.num(variant, 'width');
      let height: number = XTimelineParser.num(variant, 'height');
      if (width === 0 || height === 0) {
        const dimensions: number[] = XTimelineParser.dimensionsFromUrl(url);
        if (width === 0) {
          width = dimensions[0];
        }
        if (height === 0) {
          height = dimensions[1];
        }
      }
      out.push({ url: url, bitrate: bitrate, width: width, height: height });
    }
    for (let i: number = 1; i < out.length; i++) {
      const current: VideoRendition = out[i];
      let j: number = i - 1;
      while (j >= 0 && out[j].bitrate > current.bitrate) {
        out[j + 1] = out[j];
        j--;
      }
      out[j + 1] = current;
    }
    return out;
  }

  private static dimensionsFromUrl(url: string): number[] {
    const segments: string[] = url.split('/');
    for (let i: number = 0; i < segments.length; i++) {
      const segment: string = segments[i];
      const separator: number = segment.indexOf('x');
      if (separator <= 0 || separator >= segment.length - 1) {
        continue;
      }
      const widthText: string = segment.substring(0, separator);
      const heightText: string = segment.substring(separator + 1);
      if (XTimelineParser.isDigits(widthText) && XTimelineParser.isDigits(heightText)) {
        return [Number(widthText), Number(heightText)];
      }
    }
    return [0, 0];
  }

  private static isDigits(value: string): boolean {
    if (value.length === 0) {
      return false;
    }
    for (let i: number = 0; i < value.length; i++) {
      const code: number = value.charCodeAt(i);
      if (code < 48 || code > 57) {
        return false;
      }
    }
    return true;
  }

  private static hlsVariant(variants: Array<Record<string, Object>>): string {
    for (let i: number = 0; i < variants.length; i++) {
      const variant: Record<string, Object> = variants[i];
      const url: string = String(variant['url'] ?? variant['src'] ?? '');
      const contentType: string = String(variant['content_type'] ?? variant['contentType'] ?? '').toLowerCase();
      if (url.length > 0 && (contentType.indexOf('application/x-mpegurl') >= 0 ||
        contentType.indexOf('application/vnd.apple.mpegurl') >= 0 || url.toLowerCase().indexOf('.m3u8') >= 0)) {
        return url;
      }
    }
    return '';
  }

  // A media entry is either the media object itself, one wrapped in
  // media_results.result / result / media, or a bare reference carrying only a
  // media_key. Each form is tried in turn.
  private static resolveMediaNode(entry: Record<string, Object>): Record<string, Object> | undefined {
    if (XTimelineParser.hasMediaData(entry)) {
      return entry;
    }
    // media_results holds the real media object. It arrives as an object with a
    // result child, as an array of those, or as the media object itself.
    const fromResults: Record<string, Object> | undefined =
      XTimelineParser.unwrapMediaHolder(entry['media_results']);
    if (fromResults !== undefined) {
      return fromResults;
    }
    const candidates: Record<string, Object>[] = [
      XTimelineParser.obj(entry, 'result'),
      XTimelineParser.obj(entry, 'media')
    ];
    for (let i: number = 0; i < candidates.length; i++) {
      if (XTimelineParser.hasMediaData(candidates[i])) {
        return candidates[i];
      }
    }
    // Bare reference: resolve through the payload side table by either key.
    const keys: string[] = [String(entry['media_key'] ?? ''), String(entry['id_str'] ?? ''),
      String(entry['media_id'] ?? '')];
    for (let i: number = 0; i < keys.length; i++) {
      if (keys[i].length === 0) {
        continue;
      }
      const fromTable: Record<string, Object> | undefined = XTimelineParser.mediaByKey.get(keys[i]);
      if (fromTable !== undefined) {
        return fromTable;
      }
    }
    return undefined;
  }

  // Walks a media_results holder of any shape down to the object carrying URLs.
  private static unwrapMediaHolder(holder: Object | undefined): Record<string, Object> | undefined {
    if (holder === undefined || holder === null) {
      return undefined;
    }
    if (holder instanceof Array) {
      const items: Array<Object> = holder as Array<Object>;
      for (let i: number = 0; i < items.length; i++) {
        const found: Record<string, Object> | undefined =
          XTimelineParser.unwrapMediaHolder(items[i]);
        if (found !== undefined) {
          return found;
        }
      }
      return undefined;
    }
    if (typeof holder !== 'object') {
      return undefined;
    }
    const record: Record<string, Object> = holder as Record<string, Object>;
    if (XTimelineParser.hasMediaData(record)) {
      return record;
    }
    return XTimelineParser.unwrapMediaHolder(record['result']);
  }

  private static hasMediaData(node: Record<string, Object>): boolean {
    if (Object.keys(node).length === 0) {
      return false;
    }
    // Classic media objects carry media_url_https / video_info; the newer shape
    // wraps everything in media_info using original_img_url / preview_img_url.
    return node['media_url_https'] !== undefined || node['media_url'] !== undefined ||
      node['video_info'] !== undefined || node['media_info'] !== undefined ||
      node['original_img_url'] !== undefined || node['preview_img_url'] !== undefined;
  }

  private static collectMedia(node: Object, depth: number): void {
    if (depth > 16 || XTimelineParser.mediaByKey.size > 200) {
      return;
    }
    if (node === null || node === undefined) {
      return;
    }
    if (node instanceof Array) {
      const items: Array<Object> = node as Array<Object>;
      for (let i: number = 0; i < items.length; i++) {
        XTimelineParser.collectMedia(items[i], depth + 1);
      }
      return;
    }
    if (typeof node !== 'object') {
      return;
    }
    const record: Record<string, Object> = node as Record<string, Object>;
    if (XTimelineParser.hasMediaData(record)) {
      const key: string = String(record['media_key'] ?? '');
      if (key.length > 0 && !XTimelineParser.mediaByKey.has(key)) {
        XTimelineParser.mediaByKey.set(key, record);
      }
      // Entities reference media by numeric id rather than by media_key.
      const idStr: string = String(record['id_str'] ?? '');
      if (idStr.length > 0 && !XTimelineParser.mediaByKey.has(idStr)) {
        XTimelineParser.mediaByKey.set(idStr, record);
      }
      // Note posts reference their media by media_id instead of id_str.
      const mediaId: string = String(record['media_id'] ?? '');
      if (mediaId.length > 0 && !XTimelineParser.mediaByKey.has(mediaId)) {
        XTimelineParser.mediaByKey.set(mediaId, record);
      }
    }
    const keys: string[] = Object.keys(record);
    for (let i: number = 0; i < keys.length; i++) {
      XTimelineParser.collectMedia(record[keys[i]], depth + 1);
    }
  }

  private static dedupe(tweets: Tweet[]): Tweet[] {
    const seen: Map<string, boolean> = new Map();
    const out: Tweet[] = [];
    for (let i: number = 0; i < tweets.length; i++) {
      if (!seen.has(tweets[i].id)) {
        seen.set(tweets[i].id, true);
        out.push(tweets[i]);
      }
    }
    return out;
  }

  private static obj(source: Record<string, Object> | undefined, key: string): Record<string, Object> {
    if (source === undefined) {
      return {};
    }
    const value: Object | undefined = source[key];
    if (value === undefined || value === null) {
      return {};
    }
    return value as Record<string, Object>;
  }

  private static arr(source: Record<string, Object>, key: string): Array<Record<string, Object>> {
    const value: Object | undefined = source[key];
    if (value instanceof Array) {
      return value as Array<Record<string, Object>>;
    }
    return [];
  }

  private static num(source: Record<string, Object>, key: string): number {
    const value: Object | undefined = source[key];
    if (value === undefined || value === null) {
      return 0;
    }
    const parsed: number = Number(value);
    return isNaN(parsed) ? 0 : parsed;
  }
}
