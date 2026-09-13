// X API v2 client for HarmonyOS (OAuth 2.0 user context + app-only Bearer).
// Uses @ohos.net.http (stable from API 6 through API 24/26).
// Every network call returns null/false on failure so the UI can fall
// back to offline demo data — nothing here may throw across the boundary.
import http from '@ohos.net.http';
import hilog from '@ohos.hilog';
import type { Tweet, DirectMessage, AppNotification, UserProfile, MediaAttachment } from '../models/Tweet';

const DOMAIN = 0xFF00;
const TAG = 'HarmonyX-XApi';
const BASE_URL = 'https://api.x.com/2';
const AUTHORIZE_URL = 'https://x.com/i/oauth2/authorize';
const TOKEN_URL = 'https://api.x.com/2/oauth2/token';
export const REDIRECT_URI = 'harmonyx://callback';
const TWEET_FIELDS = 'created_at,public_metrics,attachments';
const USER_FIELDS = 'name,username,verified,profile_image_url';
const PROFILE_FIELDS = 'name,username,verified,description,public_metrics,profile_image_url,profile_banner_url';
const MEDIA_FIELDS = 'type,url,preview_image_url,width,height,alt_text,variants';
const EXPANSIONS = 'author_id,attachments.media_keys';

export interface TokenResult {
  ok: boolean;
  accessToken: string;
  errorText: string;
}

export interface MeResult {
  id: string;
  username: string;
}

// A page keeps X's opaque cursor with the posts it returned. The UI must pass
// the cursor back unchanged when it asks for older items in the feed.
export interface TweetPage {
  tweets: Tweet[];
  nextToken: string;
}

export class XApiClient {
  private token: string = '';
  private userId: string = '';
  private lastCode: number = 0;

  setToken(token: string): void {
    this.token = token.trim();
  }

  setUser(userId: string): void {
    this.userId = userId;
  }

  hasToken(): boolean {
    return this.token.length > 0;
  }

  // Most recent HTTP status (0 = not called yet, -1 = network error).
  // 402 means X demands paid API access for that endpoint.
  lastStatus(): number {
    return this.lastCode;
  }

  // ---- OAuth 2.0 -------------------------------------------------------

  static buildAuthorizeUrl(clientId: string, challenge: string, state: string): string {
    const scope = encodeURIComponent('tweet.read tweet.write users.read like.read like.write follows.read dm.read offline.access');
    return AUTHORIZE_URL + '?response_type=code' +
      '&client_id=' + encodeURIComponent(clientId.trim()) +
      '&redirect_uri=' + encodeURIComponent(REDIRECT_URI) +
      '&scope=' + scope +
      '&state=' + encodeURIComponent(state) +
      '&code_challenge=' + encodeURIComponent(challenge) +
      '&code_challenge_method=S256';
  }

  // PKCE code -> access token. Supports public clients (no secret) and
  // confidential clients (secret -> HTTP Basic auth), per X docs.
  async exchangeCode(clientId: string, clientSecret: string, code: string,
    verifier: string): Promise<TokenResult> {
    const fail: TokenResult = { ok: false, accessToken: '', errorText: 'Token exchange failed' };
    let httpRequest: http.HttpRequest | undefined = undefined;
    try {
      httpRequest = http.createHttp();
      const body: string = 'grant_type=authorization_code' +
        '&code=' + encodeURIComponent(code) +
        '&redirect_uri=' + encodeURIComponent(REDIRECT_URI) +
        '&code_verifier=' + encodeURIComponent(verifier) +
        '&client_id=' + encodeURIComponent(clientId.trim());
      const headers: Record<string, string> = { 'Content-Type': 'application/x-www-form-urlencoded' };
      const secret: string = clientSecret.trim();
      if (secret.length > 0) {
        headers['Authorization'] = 'Basic ' + this.base64Of(clientId.trim() + ':' + secret);
      }
      const resp: http.HttpResponse = await httpRequest.request(TOKEN_URL, {
        method: http.RequestMethod.POST,
        header: headers,
        extraData: body,
        readTimeout: 15000,
        connectTimeout: 15000
      });
      const text: string = typeof resp.result === 'string' ? resp.result as string : JSON.stringify(resp.result);
      if (resp.responseCode !== 200) {
        hilog.error(DOMAIN, TAG, 'token HTTP %{public}d: %{public}s', resp.responseCode, text.substring(0, 300));
        return { ok: false, accessToken: '', errorText: 'X rejected the code (HTTP ' + resp.responseCode + ')' };
      }
      const json: Record<string, string> = JSON.parse(text) as Record<string, string>;
      const access: string = String(json['access_token'] ?? '');
      if (access.length === 0) {
        return fail;
      }
      return { ok: true, accessToken: access, errorText: '' };
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'exchange failed: %{public}s', JSON.stringify(e));
      return { ok: false, accessToken: '', errorText: 'Network error during sign-in' };
    } finally {
      if (httpRequest !== undefined) {
        httpRequest.destroy();
      }
    }
  }

  private base64Of(s: string): string {
    const alpha = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    const bytes: number[] = [];
    // UTF-8 encode (client ids/secrets are ASCII in practice).
    for (let i = 0; i < s.length; i++) {
      const c: number = s.charCodeAt(i);
      if (c < 0x80) {
        bytes.push(c);
      } else if (c < 0x800) {
        bytes.push(0xC0 | (c >> 6), 0x80 | (c & 0x3F));
      } else {
        bytes.push(0xE0 | (c >> 12), 0x80 | ((c >> 6) & 0x3F), 0x80 | (c & 0x3F));
      }
    }
    let out = '';
    let i = 0;
    while (i < bytes.length) {
      const b0: number = bytes[i];
      const b1: number = i + 1 < bytes.length ? bytes[i + 1] : 0;
      const b2: number = i + 2 < bytes.length ? bytes[i + 2] : 0;
      const n: number = (b0 << 16) | (b1 << 8) | b2;
      out += alpha.charAt((n >>> 18) & 0x3F) + alpha.charAt((n >>> 12) & 0x3F);
      out += i + 1 < bytes.length ? alpha.charAt((n >>> 6) & 0x3F) : '=';
      out += i + 2 < bytes.length ? alpha.charAt(n & 0x3F) : '=';
      i += 3;
    }
    return out;
  }

  // ---- Reads -----------------------------------------------------------

  async me(): Promise<MeResult | null> {
    if (!this.hasToken()) {
      return null;
    }
    const resp: string | null = await this.get(BASE_URL + '/users/me?user.fields=' + USER_FIELDS);
    if (resp === null) {
      return null;
    }
    try {
      const json: Record<string, Record<string, string>> = JSON.parse(resp) as Record<string, Record<string, string>>;
      const data: Record<string, string> = json['data'] ?? {};
      const id: string = String(data['id'] ?? '');
      if (id.length === 0) {
        return null;
      }
      return { id: id, username: String(data['username'] ?? '') };
    } catch (e) {
      return null;
    }
  }

  // Home timeline needs a user-context token (OAuth sign-in).
  async homeTimelinePage(userId: string, paginationToken: string = ''): Promise<TweetPage | null> {
    if (!this.hasToken() || userId.length === 0) {
      return null;
    }
    const url: string = BASE_URL + '/users/' + encodeURIComponent(userId) +
      '/timelines/reverse_chronological?max_results=20' +
      (paginationToken.length > 0 ? '&pagination_token=' + encodeURIComponent(paginationToken) : '') +
      '&tweet.fields=' + TWEET_FIELDS + '&expansions=' + EXPANSIONS + '&user.fields=' + USER_FIELDS +
      '&media.fields=' + MEDIA_FIELDS;
    const resp: string | null = await this.get(url);
    if (resp === null) {
      return null;
    }
    return XApiClient.parseTweetPage(resp);
  }

  async homeTimeline(userId: string): Promise<Tweet[] | null> {
    const page: TweetPage | null = await this.homeTimelinePage(userId);
    return page === null ? null : page.tweets;
  }

  // App-only search (works with a pasted Bearer token too).
  async searchRecentPage(query: string = 'HarmonyOS', nextToken: string = ''): Promise<TweetPage | null> {
    if (!this.hasToken()) {
      return null;
    }
    const url: string = BASE_URL + '/tweets/search/recent?query=' +
      encodeURIComponent(query) + '&max_results=20' +
      (nextToken.length > 0 ? '&next_token=' + encodeURIComponent(nextToken) : '') +
      '&tweet.fields=' + TWEET_FIELDS + '&expansions=' + EXPANSIONS + '&user.fields=' + USER_FIELDS +
      '&media.fields=' + MEDIA_FIELDS;
    const resp: string | null = await this.get(url);
    if (resp === null) {
      return null;
    }
    return XApiClient.parseTweetPage(resp);
  }

  async searchRecent(query: string = 'HarmonyOS'): Promise<Tweet[] | null> {
    const page: TweetPage | null = await this.searchRecentPage(query);
    return page === null ? null : page.tweets;
  }

  // The X v2 mentions timeline is the closest API-backed equivalent to the
  // notifications surface: it contains posts directed at the signed-in user.
  async mentions(userId: string): Promise<AppNotification[] | null> {
    if (!this.hasToken() || userId.length === 0) {
      return null;
    }
    const url: string = BASE_URL + '/users/' + encodeURIComponent(userId) +
      '/mentions?max_results=20&tweet.fields=created_at&expansions=author_id&user.fields=name,username';
    const resp: string | null = await this.get(url);
    if (resp === null) {
      return null;
    }
    return XApiClient.parseMentions(resp);
  }

  // DM events require the dm.read OAuth scope. They replace the former
  // in-app samples with the user's real message history when permitted.
  async directMessages(): Promise<DirectMessage[] | null> {
    if (!this.hasToken()) {
      return null;
    }
    const url: string = BASE_URL + '/dm_events?event_types=MessageCreate&max_results=50' +
      '&dm_event.fields=created_at,sender_id,text&expansions=sender_id&user.fields=name,username,profile_image_url';
    const resp: string | null = await this.get(url);
    if (resp === null) {
      return null;
    }
    return XApiClient.parseDirectMessages(resp);
  }

  async personalizedTrends(): Promise<string[] | null> {
    if (!this.hasToken()) {
      return null;
    }
    const resp: string | null = await this.get(BASE_URL +
      '/users/personalized_trends?personalized_trend.fields=post_count,trend_name');
    if (resp === null) {
      return null;
    }
    return XApiClient.parseTrends(resp);
  }

  async profile(): Promise<UserProfile | null> {
    if (!this.hasToken()) {
      return null;
    }
    const resp: string | null = await this.get(BASE_URL + '/users/me?user.fields=' + PROFILE_FIELDS);
    if (resp === null) {
      return null;
    }
    return XApiClient.parseProfile(resp);
  }

  // Public user lookup supplies the canonical bio, metrics, avatar and
  // profile banner for the detail destination.
  async userProfile(userId: string): Promise<UserProfile | null> {
    if (!this.hasToken() || userId.length === 0) {
      return null;
    }
    const url: string = BASE_URL + '/users/' + encodeURIComponent(userId) + '?user.fields=' + PROFILE_FIELDS;
    const resp: string | null = await this.get(url);
    if (resp === null) {
      return null;
    }
    return XApiClient.parseProfile(resp);
  }

  // The user Posts endpoint is distinct from the home timeline and returns
  // only the profile owner's public posts.
  async userPosts(userId: string): Promise<Tweet[] | null> {
    if (!this.hasToken() || userId.length === 0) {
      return null;
    }
    const url: string = BASE_URL + '/users/' + encodeURIComponent(userId) + '/tweets?max_results=20' +
      '&tweet.fields=' + TWEET_FIELDS + '&expansions=' + EXPANSIONS + '&user.fields=' + USER_FIELDS +
      '&media.fields=' + MEDIA_FIELDS;
    const resp: string | null = await this.get(url);
    if (resp === null) {
      return null;
    }
    return XApiClient.parseTweets(resp);
  }

  // Fetch the current canonical representation before opening a post detail.
  // This reflects edits, deletes and the latest public metrics instead of
  // relying on the copy that was present in the home timeline.
  async tweetById(tweetId: string): Promise<Tweet | null> {
    if (!this.hasToken() || tweetId.length === 0) {
      return null;
    }
    const url: string = BASE_URL + '/tweets/' + encodeURIComponent(tweetId) +
      '?tweet.fields=' + TWEET_FIELDS + '&expansions=' + EXPANSIONS + '&user.fields=' + USER_FIELDS +
      '&media.fields=' + MEDIA_FIELDS;
    const resp: string | null = await this.get(url);
    if (resp === null) {
      return null;
    }
    const posts: Tweet[] | null = XApiClient.parseTweets(resp);
    if (posts === null || posts.length === 0) {
      return null;
    }
    return posts[0];
  }

  // X documents conversation_id as the API-supported way to reconstruct a
  // reply thread. Recent search covers the posts available to the app plan.
  async conversationReplies(tweetId: string): Promise<Tweet[] | null> {
    if (!this.hasToken() || tweetId.length === 0) {
      return null;
    }
    const url: string = BASE_URL + '/tweets/search/recent?query=' +
      encodeURIComponent('conversation_id:' + tweetId) + '&max_results=100' +
      '&tweet.fields=' + TWEET_FIELDS + '&expansions=' + EXPANSIONS + '&user.fields=' + USER_FIELDS +
      '&media.fields=' + MEDIA_FIELDS;
    const resp: string | null = await this.get(url);
    if (resp === null) {
      return null;
    }
    const posts: Tweet[] | null = XApiClient.parseTweets(resp);
    if (posts === null) {
      return null;
    }
    const replies: Tweet[] = [];
    // The API returns newest first. Display oldest first so a conversation
    // reads naturally, and omit the root if it is included in search results.
    for (let i = posts.length - 1; i >= 0; i--) {
      if (posts[i].id !== tweetId) {
        replies.push(posts[i]);
      }
    }
    return replies;
  }

  // ---- Writes (user context) -------------------------------------------

  async postTweet(text: string, replyToId: string = ''): Promise<boolean> {
    if (!this.hasToken()) {
      return false;
    }
    const payload: Record<string, Object> = { 'text': text };
    if (replyToId.length > 0) {
      const reply: Record<string, string> = { 'in_reply_to_tweet_id': replyToId };
      payload['reply'] = reply;
    }
    return await this.post(BASE_URL + '/tweets', payload, [200, 201]);
  }

  async setLike(tweetId: string, like: boolean): Promise<boolean> {
    if (!this.hasToken() || this.userId.length === 0) {
      return false;
    }
    if (like) {
      const payload: Record<string, string> = { 'tweet_id': tweetId };
      return await this.post(BASE_URL + '/users/' + encodeURIComponent(this.userId) + '/likes', payload, [200, 201]);
    }
    return await this.del(BASE_URL + '/users/' + encodeURIComponent(this.userId) + '/likes/' + encodeURIComponent(tweetId));
  }

  async setRepost(tweetId: string, repost: boolean): Promise<boolean> {
    if (!this.hasToken() || this.userId.length === 0) {
      return false;
    }
    if (repost) {
      const payload: Record<string, string> = { 'tweet_id': tweetId };
      return await this.post(BASE_URL + '/users/' + encodeURIComponent(this.userId) + '/retweets', payload, [200, 201]);
    }
    return await this.del(BASE_URL + '/users/' + encodeURIComponent(this.userId) + '/retweets/' + encodeURIComponent(tweetId));
  }

  // ---- HTTP primitives --------------------------------------------------

  private async get(url: string): Promise<string | null> {
    let httpRequest: http.HttpRequest | undefined = undefined;
    try {
      httpRequest = http.createHttp();
      const resp: http.HttpResponse = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: { 'Authorization': 'Bearer ' + this.token },
        readTimeout: 10000,
        connectTimeout: 10000
      });
      this.lastCode = resp.responseCode;
      if (resp.responseCode !== 200) {
        hilog.error(DOMAIN, TAG, 'GET %{public}d', resp.responseCode);
        return null;
      }
      return typeof resp.result === 'string' ? resp.result as string : JSON.stringify(resp.result);
    } catch (e) {
      this.lastCode = -1;
      hilog.error(DOMAIN, TAG, 'GET failed: %{public}s', JSON.stringify(e));
      return null;
    } finally {
      if (httpRequest !== undefined) {
        httpRequest.destroy();
      }
    }
  }

  private async post(url: string, payload: Record<string, Object>, okCodes: number[]): Promise<boolean> {
    let httpRequest: http.HttpRequest | undefined = undefined;
    try {
      httpRequest = http.createHttp();
      const resp: http.HttpResponse = await httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: {
          'Authorization': 'Bearer ' + this.token,
          'Content-Type': 'application/json'
        },
        extraData: payload,
        readTimeout: 10000,
        connectTimeout: 10000
      });
      this.lastCode = resp.responseCode;
      for (let i = 0; i < okCodes.length; i++) {
        if (resp.responseCode === okCodes[i]) {
          return true;
        }
      }
      return false;
    } catch (e) {
      this.lastCode = -1;
      hilog.error(DOMAIN, TAG, 'POST failed: %{public}s', JSON.stringify(e));
      return false;
    } finally {
      if (httpRequest !== undefined) {
        httpRequest.destroy();
      }
    }
  }

  private async del(url: string): Promise<boolean> {
    let httpRequest: http.HttpRequest | undefined = undefined;
    try {
      httpRequest = http.createHttp();
      const resp: http.HttpResponse = await httpRequest.request(url, {
        method: http.RequestMethod.DELETE,
        header: { 'Authorization': 'Bearer ' + this.token },
        readTimeout: 10000,
        connectTimeout: 10000
      });
      this.lastCode = resp.responseCode;
      return resp.responseCode === 200;
    } catch (e) {
      this.lastCode = -1;
      hilog.error(DOMAIN, TAG, 'DELETE failed: %{public}s', JSON.stringify(e));
      return false;
    } finally {
      if (httpRequest !== undefined) {
        httpRequest.destroy();
      }
    }
  }

  private static parseTweetPage(body: string): TweetPage | null {
    const tweets: Tweet[] | null = XApiClient.parseTweets(body);
    if (tweets === null) {
      return null;
    }
    try {
      const json: Record<string, Object> = JSON.parse(body) as Record<string, Object>;
      const meta: Record<string, Object> = (json['meta'] ?? {}) as Record<string, Object>;
      return { tweets: tweets, nextToken: String(meta['next_token'] ?? '') };
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'page metadata parse failed: %{public}s', JSON.stringify(e));
      return null;
    }
  }

  private static parseTweets(body: string): Tweet[] | null {
    try {
      const json: Record<string, Object> = JSON.parse(body) as Record<string, Object>;
      const rawData: Object = json['data'] ?? [];
      const data: Array<Record<string, Object>> = [];
      if (rawData instanceof Array) {
        const items: Array<Record<string, Object>> = rawData as Array<Record<string, Object>>;
        for (let i = 0; i < items.length; i++) {
          data.push(items[i]);
        }
      } else {
        data.push(rawData as Record<string, Object>);
      }
      const includes: Record<string, Object> = (json['includes'] ?? {}) as Record<string, Object>;
      const users: Array<Record<string, Object>> = (includes['users'] ?? []) as Array<Record<string, Object>>;
      const userById: Map<string, Record<string, Object>> = new Map();
      for (let i = 0; i < users.length; i++) {
        const u: Record<string, Object> = users[i];
        userById.set(String(u['id']), u);
      }
      const rawMedia: Array<Record<string, Object>> = (includes['media'] ?? []) as Array<Record<string, Object>>;
      const mediaByKey: Map<string, Record<string, Object>> = new Map<string, Record<string, Object>>();
      for (let i = 0; i < rawMedia.length; i++) {
        mediaByKey.set(String(rawMedia[i]['media_key'] ?? ''), rawMedia[i]);
      }
      const out: Tweet[] = [];
      for (let i = 0; i < data.length; i++) {
        const t: Record<string, Object> = data[i];
        const authorId: string = String(t['author_id'] ?? t['id'] ?? ('x' + i));
        const u: Record<string, Object> | undefined = userById.get(authorId);
        const metrics: Record<string, Object> = (t['public_metrics'] ?? {}) as Record<string, Object>;
        const attachments: MediaAttachment[] = XApiClient.parseAttachments(t, mediaByKey);
        out.push({
          id: String(t['id'] ?? ('x' + i)),
          author: {
            id: authorId,
            name: String(u?.['name'] ?? 'X User'),
            username: String(u?.['username'] ?? 'x'),
            avatarColor: '#1D9BF0',
            avatarUrl: String(u?.['profile_image_url'] ?? ''),
            verified: Boolean(u?.['verified'] ?? false)
          },
          text: String(t['text'] ?? ''),
          createdAt: String(t['created_at'] ?? 'now'),
          metrics: {
            replyCount: Number(metrics['reply_count'] ?? 0),
            repostCount: Number(metrics['retweet_count'] ?? 0),
            likeCount: Number(metrics['like_count'] ?? 0),
            viewCount: Number(metrics['impression_count'] ?? 0)
          },
          liked: false,
          reposted: false,
          attachments: attachments
        });
      }
      return out;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'parse failed: %{public}s', JSON.stringify(e));
      return null;
    }
  }

  private static parseAttachments(tweet: Record<string, Object>,
    mediaByKey: Map<string, Record<string, Object>>): MediaAttachment[] {
    const result: MediaAttachment[] = [];
    const rawAttachments: Record<string, Object> = (tweet['attachments'] ?? {}) as Record<string, Object>;
    const mediaKeys: Array<Object> = (rawAttachments['media_keys'] ?? []) as Array<Object>;
    for (let i = 0; i < mediaKeys.length; i++) {
      const key: string = String(mediaKeys[i]);
      const media: Record<string, Object> | undefined = mediaByKey.get(key);
      if (media === undefined) {
        continue;
      }
      const type: string = String(media['type'] ?? 'photo');
      const previewUrl: string = String(media['preview_image_url'] ?? media['url'] ?? '');
      let mediaUrl: string = String(media['url'] ?? '');
      if (type === 'video' && mediaUrl.length === 0) {
        mediaUrl = XApiClient.videoVariantUrl(media);
      }
      result.push({
        id: key,
        type: type,
        mediaUrl: mediaUrl,
        previewUrl: previewUrl,
        width: Number(media['width'] ?? 0),
        height: Number(media['height'] ?? 0),
        altText: String(media['alt_text'] ?? '')
      });
    }
    return result;
  }

  private static videoVariantUrl(media: Record<string, Object>): string {
    const variants: Array<Record<string, Object>> = (media['variants'] ?? []) as Array<Record<string, Object>>;
    let selected: string = '';
    let bitrate: number = -1;
    for (let i = 0; i < variants.length; i++) {
      const contentType: string = String(variants[i]['content_type'] ?? '');
      const url: string = String(variants[i]['url'] ?? '');
      const currentBitrate: number = Number(variants[i]['bit_rate'] ?? 0);
      if (contentType === 'video/mp4' && url.length > 0 && currentBitrate > bitrate) {
        selected = url;
        bitrate = currentBitrate;
      }
    }
    return selected;
  }

  private static parseMentions(body: string): AppNotification[] | null {
    try {
      const json: Record<string, Object> = JSON.parse(body) as Record<string, Object>;
      const rawData: Object = json['data'] ?? [];
      const data: Array<Record<string, Object>> = [];
      if (rawData instanceof Array) {
        const items: Array<Record<string, Object>> = rawData as Array<Record<string, Object>>;
        for (let i = 0; i < items.length; i++) {
          data.push(items[i]);
        }
      } else {
        data.push(rawData as Record<string, Object>);
      }
      const includes: Record<string, Object> = (json['includes'] ?? {}) as Record<string, Object>;
      const users: Array<Record<string, Object>> = (includes['users'] ?? []) as Array<Record<string, Object>>;
      const userById: Map<string, Record<string, Object>> = new Map();
      for (let i = 0; i < users.length; i++) {
        const user: Record<string, Object> = users[i];
        userById.set(String(user['id'] ?? ''), user);
      }
      const result: AppNotification[] = [];
      for (let i = 0; i < data.length; i++) {
        const mention: Record<string, Object> = data[i];
        const authorId: string = String(mention['author_id'] ?? '');
        const author: Record<string, Object> | undefined = userById.get(authorId);
        const username: string = String(author?.['username'] ?? 'X user');
        result.push({
          id: String(mention['id'] ?? ('mention-' + i)),
          kind: '@',
          text: '@' + username + ': ' + String(mention['text'] ?? ''),
          time: XApiClient.displayTime(String(mention['created_at'] ?? ''))
        });
      }
      return result;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'mentions parse failed: %{public}s', JSON.stringify(e));
      return null;
    }
  }

  private static parseDirectMessages(body: string): DirectMessage[] | null {
    try {
      const json: Record<string, Object> = JSON.parse(body) as Record<string, Object>;
      const data: Array<Record<string, Object>> = (json['data'] ?? []) as Array<Record<string, Object>>;
      const includes: Record<string, Object> = (json['includes'] ?? {}) as Record<string, Object>;
      const users: Array<Record<string, Object>> = (includes['users'] ?? []) as Array<Record<string, Object>>;
      const userById: Map<string, Record<string, Object>> = new Map();
      for (let i = 0; i < users.length; i++) {
        const user: Record<string, Object> = users[i];
        userById.set(String(user['id'] ?? ''), user);
      }
      const result: DirectMessage[] = [];
      for (let i = 0; i < data.length; i++) {
        const event: Record<string, Object> = data[i];
        const senderId: string = String(event['sender_id'] ?? '');
        const sender: Record<string, Object> | undefined = userById.get(senderId);
        result.push({
          id: String(event['id'] ?? ('dm-' + i)),
          from: String(sender?.['name'] ?? sender?.['username'] ?? 'X user'),
          preview: String(event['text'] ?? ''),
          time: XApiClient.displayTime(String(event['created_at'] ?? '')),
          unread: 0,
          avatarUrl: String(sender?.['profile_image_url'] ?? '')
        });
      }
      return result;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'DM parse failed: %{public}s', JSON.stringify(e));
      return null;
    }
  }

  private static parseTrends(body: string): string[] | null {
    try {
      const json: Record<string, Object> = JSON.parse(body) as Record<string, Object>;
      const data: Array<Record<string, Object>> = (json['data'] ?? []) as Array<Record<string, Object>>;
      const result: string[] = [];
      for (let i = 0; i < data.length; i++) {
        const name: string = String(data[i]['trend_name'] ?? '');
        if (name.length > 0) {
          result.push(name);
        }
      }
      return result;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'trends parse failed: %{public}s', JSON.stringify(e));
      return null;
    }
  }

  private static parseProfile(body: string): UserProfile | null {
    try {
      const json: Record<string, Object> = JSON.parse(body) as Record<string, Object>;
      const data: Record<string, Object> = (json['data'] ?? {}) as Record<string, Object>;
      const id: string = String(data['id'] ?? '');
      if (id.length === 0) {
        return null;
      }
      const metrics: Record<string, Object> = (data['public_metrics'] ?? {}) as Record<string, Object>;
      return {
        id: id,
        name: String(data['name'] ?? ''),
        username: String(data['username'] ?? ''),
        description: String(data['description'] ?? ''),
        followersCount: Number(metrics['followers_count'] ?? 0),
        followingCount: Number(metrics['following_count'] ?? 0),
        postCount: Number(metrics['tweet_count'] ?? 0),
        verified: Boolean(data['verified'] ?? false),
        avatarUrl: String(data['profile_image_url'] ?? ''),
        bannerUrl: String(data['profile_banner_url'] ?? '')
      };
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'profile parse failed: %{public}s', JSON.stringify(e));
      return null;
    }
  }

  private static displayTime(value: string): string {
    if (value.length >= 10) {
      return value.substring(0, 10);
    }
    return value;
  }
}
