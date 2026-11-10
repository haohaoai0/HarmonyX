import { DohHttpRequest, createDohHttpRequest } from './DohHttpRequest';
import { userIsVerified, userVerifiedType, userAvatarShape, normalizedVerifiedType } from '../utils/UserIdentity';
// Read-only public-web adapter for X content. It intentionally maps only
// public posts and profiles into the app's existing models; writes and private
// data always remain on the OAuth-backed X API client.
import http from '@ohos.net.http';
import hilog from '@ohos.hilog';
import { proxyStore } from './ProxyStore';
import type { Tweet, UserProfile } from '../models/Tweet';

const DOMAIN: number = 0xFF00;
const TAG: string = 'HarmonyX-XWeb';
const FX_TWITTER_BASE_URL: string = 'https://api.fxtwitter.com/';
const REQUEST_TIMEOUT_MS: number = 10000;
const CACHE_TTL_MS: number = 15 * 60 * 1000;
const WEB_AUTHOR_COLOR: string = '#1D9BF0';

class WebPostReference {
  public handle: string;
  public postId: string;

  constructor(handle: string, postId: string) {
    this.handle = handle;
    this.postId = postId;
  }
}

class CachedWebTweet {
  public tweet: Tweet;
  public timestamp: number;

  constructor(tweet: Tweet, timestamp: number) {
    this.tweet = tweet;
    this.timestamp = timestamp;
  }
}

class CachedWebProfile {
  public profile: UserProfile;
  public timestamp: number;

  constructor(profile: UserProfile, timestamp: number) {
    this.profile = profile;
    this.timestamp = timestamp;
  }
}

class JsonStringValue {
  public value: string;
  public nextIndex: number;

  constructor(value: string, nextIndex: number) {
    this.value = value;
    this.nextIndex = nextIndex;
  }
}

// The public endpoint returns JSON, but its shape is not an X API contract.
// This narrow parser reads only the known scalar fields and avoids dynamic
// object indexing so the adapter remains compatible with ArkTS restrictions.
export class XWebClient {
  private tweetCache: Map<string, CachedWebTweet> = new Map<string, CachedWebTweet>();
  private profileCache: Map<string, CachedWebProfile> = new Map<string, CachedWebProfile>();

  public async fetchStarterTimeline(): Promise<Tweet[]> {
    const references: WebPostReference[] = this.starterReferences();
    const pending: Promise<Tweet | null>[] = [];
    for (let index: number = 0; index < references.length; index++) {
      const reference: WebPostReference = references[index];
      pending.push(this.fetchPost(reference.handle, reference.postId));
    }
    const resolved: Array<Tweet | null> = await Promise.all(pending);
    const posts: Tweet[] = [];
    for (let index: number = 0; index < resolved.length; index++) {
      const post: Tweet | null = resolved[index];
      if (post !== null) {
        posts.push(post);
      }
    }
    return posts;
  }

  public async fetchPublicProfile(handle: string): Promise<UserProfile | null> {
    const normalizedHandle: string = this.normalizedHandle(handle);
    if (!this.isValidHandle(normalizedHandle)) {
      return null;
    }
    const cached: CachedWebProfile | undefined = this.profileCache.get(normalizedHandle);
    if (cached !== undefined && this.isFresh(cached.timestamp)) {
      return cached.profile;
    }
    const raw: string | null = await this.requestText(FX_TWITTER_BASE_URL + normalizedHandle);
    if (raw === null) {
      return null;
    }
    const profile: UserProfile | null = this.parseProfile(raw);
    if (profile !== null) {
      this.profileCache.set(normalizedHandle, new CachedWebProfile(profile, Date.now()));
    }
    return profile;
  }

  private starterReferences(): WebPostReference[] {
    return [
      new WebPostReference('elonmusk', '1518623997054918657'),
      new WebPostReference('BarackObama', '1221552460768202756'),
      new WebPostReference('JoeBiden', '1325118992785223682'),
      new WebPostReference('GretaThunberg', '1608056944501178368'),
      new WebPostReference('BTS_twt', '1256648835272605697'),
      new WebPostReference('IncredibleCulk', '1298730289737293824'),
      new WebPostReference('TwitterDev', '1460323737035677698'),
      new WebPostReference('jack', '20')
    ];
  }

  private async fetchPost(handle: string, postId: string): Promise<Tweet | null> {
    const normalizedHandle: string = this.normalizedHandle(handle);
    if (!this.isValidHandle(normalizedHandle) || !this.isValidPostId(postId)) {
      return null;
    }
    const cacheKey: string = normalizedHandle + '/' + postId;
    const cached: CachedWebTweet | undefined = this.tweetCache.get(cacheKey);
    if (cached !== undefined && this.isFresh(cached.timestamp)) {
      return cached.tweet;
    }
    const url: string = FX_TWITTER_BASE_URL + normalizedHandle + '/status/' + postId;
    const raw: string | null = await this.requestText(url);
    if (raw === null) {
      return null;
    }
    const tweet: Tweet | null = this.parseTweet(raw);
    if (tweet !== null) {
      this.tweetCache.set(cacheKey, new CachedWebTweet(tweet, Date.now()));
    }
    return tweet;
  }

  private async requestText(url: string): Promise<string | null> {
    let request: DohHttpRequest | undefined = undefined;
    try {
      request = createDohHttpRequest();
      const options: http.HttpRequestOptions = {
        method: http.RequestMethod.GET,
        header: { 'User-Agent': 'HarmonyX public web adapter' },
        connectTimeout: REQUEST_TIMEOUT_MS,
        readTimeout: REQUEST_TIMEOUT_MS
      };
      await proxyStore.apply(options);
      const response: http.HttpResponse = await request.request(url, options);
      if (response.responseCode !== 200 || typeof response.result !== 'string') {
        hilog.warn(DOMAIN, TAG, 'Public-web request unavailable: %{public}d', response.responseCode);
        return null;
      }
      return response.result as string;
    } catch (error) {
      hilog.warn(DOMAIN, TAG, '%{public}s', 'Public-web request failed');
      return null;
    } finally {
      if (request !== undefined) {
        request.destroy();
      }
    }
  }

  private parseTweet(raw: string): Tweet | null {
    const tweetObject: string = this.objectForProperty(raw, 'tweet');
    if (tweetObject.length === 0) {
      return null;
    }
    const authorObject: string = this.objectForProperty(tweetObject, 'author');
    if (authorObject.length === 0) {
      return null;
    }
    const id: string = this.stringForProperty(tweetObject, 'id');
    const text: string = this.stringForProperty(tweetObject, 'text');
    const username: string = this.normalizedHandle(this.stringForProperty(authorObject, 'screen_name'));
    if (id.length === 0 || text.length === 0 || !this.isValidHandle(username)) {
      return null;
    }
    const verificationObject: string = this.objectForProperty(authorObject, 'verification');
    const authorId: string = this.stringForProperty(authorObject, 'id');
    return {
      id: id,
      author: {
        id: authorId.length > 0 ? authorId : username,
        name: this.stringForProperty(authorObject, 'name'),
        username: username,
        avatarColor: WEB_AUTHOR_COLOR,
        avatarUrl: this.stringForProperty(authorObject, 'avatar_url'),
        verified: verificationObject.length > 0 && this.booleanForProperty(verificationObject, 'verified'),
        verifiedType: normalizedVerifiedType(this.stringForProperty(verificationObject, 'type') || this.stringForProperty(verificationObject, 'verified_type'))
      },
      text: text,
      createdAt: this.stringForProperty(tweetObject, 'created_at'),
      metrics: {
        replyCount: this.numberForProperty(tweetObject, 'replies'),
        repostCount: this.numberForProperty(tweetObject, 'retweets'),
        likeCount: this.numberForProperty(tweetObject, 'likes'),
        viewCount: this.numberForProperty(tweetObject, 'views')
      },
      liked: false,
      reposted: false,
      attachments: []
    };
  }

  private parseProfile(raw: string): UserProfile | null {
    const userObject: string = this.objectForProperty(raw, 'user');
    if (userObject.length === 0) {
      return null;
    }
    const id: string = this.stringForProperty(userObject, 'id');
    const username: string = this.normalizedHandle(this.stringForProperty(userObject, 'screen_name'));
    if (id.length === 0 || !this.isValidHandle(username)) {
      return null;
    }
    const verificationObject: string = this.objectForProperty(userObject, 'verification');
    return {
      id: id,
      name: this.stringForProperty(userObject, 'name'),
      username: username,
      description: this.stringForProperty(userObject, 'description'),
      followersCount: this.numberForProperty(userObject, 'followers'),
      followingCount: this.numberForProperty(userObject, 'following'),
      postCount: this.numberForProperty(userObject, 'tweets'),
      verified: verificationObject.length > 0 && this.booleanForProperty(verificationObject, 'verified'),
        verifiedType: normalizedVerifiedType(this.stringForProperty(verificationObject, 'type') || this.stringForProperty(verificationObject, 'verified_type')),
      avatarUrl: this.stringForProperty(userObject, 'avatar_url'),
      bannerUrl: this.highResBannerUrl(this.stringForProperty(userObject, 'banner_url'))
    };
  }

  private highResBannerUrl(url: string): string {
    if (url.length === 0) {
      return '';
    }
    const queryStart: number = url.indexOf('?');
    let body: string = url;
    let query: string = '';
    if (queryStart >= 0) {
      body = url.substring(0, queryStart);
      query = url.substring(queryStart);
    }
    const size: string = '1500x500';
    const slash: number = body.lastIndexOf('/');
    if (slash < 0) {
      return body + '/' + size + query;
    }
    const lastSegment: string = body.substring(slash + 1);
    if (this.isBannerSizeSegment(lastSegment)) {
      return body.substring(0, slash + 1) + size + query;
    }
    return body + '/' + size + query;
  }

  private isBannerSizeSegment(value: string): boolean {
    const split: number = value.indexOf('x');
    if (split <= 0 || split >= value.length - 1) {
      return false;
    }
    return this.isDigits(value.substring(0, split)) && this.isDigits(value.substring(split + 1));
  }

  private isDigits(value: string): boolean {
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

  private isFresh(timestamp: number): boolean {
    return Date.now() - timestamp < CACHE_TTL_MS;
  }

  private normalizedHandle(handle: string): string {
    const trimmed: string = handle.trim();
    return trimmed.startsWith('@') ? trimmed.substring(1) : trimmed;
  }

  private isValidHandle(handle: string): boolean {
    if (handle.length === 0 || handle.length > 15) {
      return false;
    }
    for (let index: number = 0; index < handle.length; index++) {
      const code: number = handle.charCodeAt(index);
      const isLetter: boolean = (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
      const isNumber: boolean = code >= 48 && code <= 57;
      if (!isLetter && !isNumber && code !== 95) {
        return false;
      }
    }
    return true;
  }

  private isValidPostId(postId: string): boolean {
    if (postId.length === 0 || postId.length > 32) {
      return false;
    }
    for (let index: number = 0; index < postId.length; index++) {
      const code: number = postId.charCodeAt(index);
      if (code < 48 || code > 57) {
        return false;
      }
    }
    return true;
  }

  private objectForProperty(input: string, property: string): string {
    const valueStart: number = this.propertyValueStart(input, property);
    if (valueStart < 0 || input.charAt(valueStart) !== '{') {
      return '';
    }
    const end: number = this.objectEnd(input, valueStart);
    return end < 0 ? '' : input.substring(valueStart, end + 1);
  }

  private stringForProperty(input: string, property: string): string {
    const valueStart: number = this.propertyValueStart(input, property);
    if (valueStart < 0) {
      return '';
    }
    const parsed: JsonStringValue | null = this.readJsonString(input, valueStart);
    return parsed === null ? '' : parsed.value;
  }

  private numberForProperty(input: string, property: string): number {
    const valueStart: number = this.propertyValueStart(input, property);
    if (valueStart < 0) {
      return 0;
    }
    let index: number = valueStart;
    let value: string = '';
    while (index < input.length) {
      const char: string = input.charAt(index);
      const code: number = char.charCodeAt(0);
      const isDigit: boolean = code >= 48 && code <= 57;
      if (!isDigit && char !== '-' && char !== '.') {
        break;
      }
      value += char;
      index += 1;
    }
    if (value.length === 0) {
      return 0;
    }
    const result: number = Number(value);
    return result >= 0 ? result : 0;
  }

  private booleanForProperty(input: string, property: string): boolean {
    const valueStart: number = this.propertyValueStart(input, property);
    return valueStart >= 0 && input.substring(valueStart, valueStart + 4) === 'true';
  }

  private propertyValueStart(input: string, property: string): number {
    let index: number = 0;
    let depth: number = 0;
    while (index < input.length) {
      const char: string = input.charAt(index);
      if (char === '"') {
        const parsed: JsonStringValue | null = this.readJsonString(input, index);
        if (parsed === null) {
          return -1;
        }
        if (depth === 1 && parsed.value === property) {
          const separator: number = this.skipWhitespace(input, parsed.nextIndex);
          if (input.charAt(separator) === ':') {
            return this.skipWhitespace(input, separator + 1);
          }
        }
        index = parsed.nextIndex;
        continue;
      }
      if (char === '{' || char === '[') {
        depth += 1;
      } else if (char === '}' || char === ']') {
        depth -= 1;
      }
      index += 1;
    }
    return -1;
  }

  private objectEnd(input: string, start: number): number {
    let index: number = start;
    let depth: number = 0;
    let insideString: boolean = false;
    let escaped: boolean = false;
    while (index < input.length) {
      const char: string = input.charAt(index);
      if (insideString) {
        if (escaped) {
          escaped = false;
        } else if (char === '\\') {
          escaped = true;
        } else if (char === '"') {
          insideString = false;
        }
      } else if (char === '"') {
        insideString = true;
      } else if (char === '{') {
        depth += 1;
      } else if (char === '}') {
        depth -= 1;
        if (depth === 0) {
          return index;
        }
      }
      index += 1;
    }
    return -1;
  }

  private readJsonString(input: string, start: number): JsonStringValue | null {
    if (input.charAt(start) !== '"') {
      return null;
    }
    let index: number = start + 1;
    let value: string = '';
    while (index < input.length) {
      const char: string = input.charAt(index);
      if (char === '"') {
        return new JsonStringValue(value, index + 1);
      }
      if (char !== '\\') {
        value += char;
        index += 1;
        continue;
      }
      index += 1;
      if (index >= input.length) {
        return null;
      }
      const escaped: string = input.charAt(index);
      if (escaped === 'b') {
        value += '\b';
      } else if (escaped === 'f') {
        value += '\f';
      } else if (escaped === 'n') {
        value += '\n';
      } else if (escaped === 'r') {
        value += '\r';
      } else if (escaped === 't') {
        value += '\t';
      } else if (escaped === 'u') {
        const unicodeStart: number = index + 1;
        const unicodeEnd: number = unicodeStart + 4;
        if (unicodeEnd > input.length) {
          return null;
        }
        const code: number = parseInt(input.substring(unicodeStart, unicodeEnd), 16);
        if (code >= 0) {
          value += String.fromCharCode(code);
        }
        index = unicodeEnd;
        continue;
      } else {
        value += escaped;
      }
      index += 1;
    }
    return null;
  }

  private skipWhitespace(input: string, start: number): number {
    let index: number = start;
    while (index < input.length) {
      const char: string = input.charAt(index);
      if (char !== ' ' && char !== '\n' && char !== '\r' && char !== '\t') {
        return index;
      }
      index += 1;
    }
    return index;
  }
}
