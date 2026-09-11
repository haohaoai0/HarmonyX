// X API v2 client for HarmonyOS (OAuth 2.0 user context + app-only Bearer).
// Uses @ohos.net.http (stable from API 6 through API 24/26).
// Every network call returns null/false on failure so the UI can fall
// back to offline demo data — nothing here may throw across the boundary.
import http from '@ohos.net.http';
import hilog from '@ohos.hilog';
import type { Tweet } from '../models/Tweet';

const DOMAIN = 0xFF00;
const TAG = 'OpenTwit-XApi';
const BASE_URL = 'https://api.x.com/2';
const AUTHORIZE_URL = 'https://x.com/i/oauth2/authorize';
const TOKEN_URL = 'https://api.x.com/2/oauth2/token';
export const REDIRECT_URI = 'opentwit://callback';
const TWEET_FIELDS = 'created_at,public_metrics';
const USER_FIELDS = 'name,username,verified';
const EXPANSIONS = 'author_id';

export interface TokenResult {
  ok: boolean;
  accessToken: string;
  errorText: string;
}

export interface MeResult {
  id: string;
  username: string;
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
    const scope = encodeURIComponent('tweet.read tweet.write users.read like.read like.write follows.read offline.access');
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
  async homeTimeline(userId: string): Promise<Tweet[] | null> {
    if (!this.hasToken() || userId.length === 0) {
      return null;
    }
    const url: string = BASE_URL + '/users/' + encodeURIComponent(userId) +
      '/timelines/reverse_chronological?max_results=20' +
      '&tweet.fields=' + TWEET_FIELDS + '&expansions=' + EXPANSIONS + '&user.fields=' + USER_FIELDS;
    const resp: string | null = await this.get(url);
    if (resp === null) {
      return null;
    }
    return XApiClient.parseTweets(resp);
  }

  // App-only search (works with a pasted Bearer token too).
  async searchRecent(query: string = 'HarmonyOS'): Promise<Tweet[] | null> {
    if (!this.hasToken()) {
      return null;
    }
    const url: string = BASE_URL + '/tweets/search/recent?query=' +
      encodeURIComponent(query) + '&max_results=10' +
      '&tweet.fields=' + TWEET_FIELDS + '&expansions=' + EXPANSIONS + '&user.fields=' + USER_FIELDS;
    const resp: string | null = await this.get(url);
    if (resp === null) {
      return null;
    }
    return XApiClient.parseTweets(resp);
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

  private static parseTweets(body: string): Tweet[] | null {
    try {
      const json: Record<string, Object> = JSON.parse(body) as Record<string, Object>;
      const data: Array<Record<string, Object>> = (json['data'] ?? []) as Array<Record<string, Object>>;
      const includes: Record<string, Object> = (json['includes'] ?? {}) as Record<string, Object>;
      const users: Array<Record<string, Object>> = (includes['users'] ?? []) as Array<Record<string, Object>>;
      const userById: Map<string, Record<string, Object>> = new Map();
      for (let i = 0; i < users.length; i++) {
        const u: Record<string, Object> = users[i];
        userById.set(String(u['id']), u);
      }
      const out: Tweet[] = [];
      for (let i = 0; i < data.length; i++) {
        const t: Record<string, Object> = data[i];
        const authorId: string = String(t['author_id'] ?? t['id'] ?? ('x' + i));
        const u: Record<string, Object> | undefined = userById.get(authorId);
        const metrics: Record<string, Object> = (t['public_metrics'] ?? {}) as Record<string, Object>;
        out.push({
          id: String(t['id'] ?? ('x' + i)),
          author: {
            id: authorId,
            name: String(u?.['name'] ?? 'X User'),
            username: String(u?.['username'] ?? 'x'),
            avatarColor: '#1D9BF0',
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
          reposted: false
        });
      }
      return out;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'parse failed: %{public}s', JSON.stringify(e));
      return null;
    }
  }
}
