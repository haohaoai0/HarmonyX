// Decodes UserByScreenName / UserByRestId responses into the app's UserProfile.
//
//   data.user.result
//     .__typename            "User" | "UserUnavailable"
//     .rest_id
//     .is_blue_verified
//     .legacy                name, screen_name, description, counts, images
import hilog from '@ohos.hilog';
import type { UserProfile } from '../models/Tweet';
import { userIsVerified, userVerifiedType, userAvatarShape } from '../utils/UserIdentity';

const DOMAIN = 0xFF00;
const TAG = 'HarmonyX-User';

export class XUserParser {
  static isProtectedAccount(body: string): boolean {
    try {
      const json: Record<string, Object> = JSON.parse(body) as Record<string, Object>;
      const data: Record<string, Object> = XUserParser.obj(json, 'data');
      let result: Record<string, Object> = XUserParser.resultOf(XUserParser.obj(data, 'user'));
      if (Object.keys(result).length === 0) {
        const keys: string[] = Object.keys(data);
        for (let i: number = 0; i < keys.length; i++) {
          const candidate: Record<string, Object> = XUserParser.obj(data, keys[i]);
          const found: Record<string, Object> = XUserParser.resultOf(candidate);
          if (Object.keys(found).length > 0) {
            result = found;
            break;
          }
        }
      }
      if (Object.keys(result).length === 0) {
        return false;
      }
      const legacy: Record<string, Object> = XUserParser.obj(result, 'legacy');
      return Boolean(legacy['protected'] ?? result['protected'] ?? false);
    } catch (e) {
      return false;
    }
  }

  static parse(body: string): UserProfile | null {
    try {
      const json: Record<string, Object> = JSON.parse(body) as Record<string, Object>;
      const data: Record<string, Object> = XUserParser.obj(json, 'data');
      // The alias differs per operation ("user", "user_result", ...), so take
      // the first child that carries a result object.
      let result: Record<string, Object> = XUserParser.resultOf(XUserParser.obj(data, 'user'));
      if (Object.keys(result).length === 0) {
        const keys: string[] = Object.keys(data);
        for (let i: number = 0; i < keys.length; i++) {
          const candidate: Record<string, Object> = XUserParser.obj(data, keys[i]);
          const found: Record<string, Object> = XUserParser.resultOf(candidate);
          if (Object.keys(found).length > 0) {
            result = found;
            break;
          }
        }
      }
      let restId: string = String(result['rest_id'] ?? '');
      if (restId.length === 0) {
        restId = String(result['id'] ?? '');
      }
      if (restId.length === 0) {
        const keys: string[] = Object.keys(data);
        hilog.warn(DOMAIN, TAG, 'no user result; data keys=%{public}s', keys.join(','));
        return null;
      }
      const legacy: Record<string, Object> = XUserParser.obj(result, 'legacy');
      const relationshipCounts: Record<string, Object> = XUserParser.obj(result, 'relationship_counts');
      const tweetCounts: Record<string, Object> = XUserParser.obj(result, 'tweet_counts');
      const perspectives: Record<string, Object> = XUserParser.obj(result, 'relationship_perspectives');
      const avatar: Record<string, Object> = XUserParser.obj(result, 'avatar');
      const core: Record<string, Object> = XUserParser.obj(result, 'core');
      const verification: Record<string, Object> = XUserParser.obj(result, 'verification');
      const banner: Record<string, Object> = XUserParser.obj(result, 'banner');
      let avatarUrl: string = XUserParser.highResAvatarUrl(String(avatar['image_url'] ?? ''));
      if (avatarUrl.length === 0) {
        avatarUrl = XUserParser.highResAvatarUrl(String(legacy['profile_image_url_https'] ?? ''));
      }
      let bannerUrl: string = XUserParser.highResBannerUrl(String(banner['image_url'] ?? ''));
      if (bannerUrl.length === 0) {
        bannerUrl = XUserParser.highResBannerUrl(String(legacy['profile_banner_url'] ?? ''));
      }
      return {
        id: restId,
        name: String(core['name'] ?? legacy['name'] ?? ''),
        username: String(core['screen_name'] ?? legacy['screen_name'] ?? ''),
        description: String(legacy['description'] ?? ''),
        followersCount: XUserParser.numWithFallback(legacy, 'followers_count',
          relationshipCounts, 'followers'),
        followingCount: XUserParser.numWithFallback(legacy, 'friends_count',
          relationshipCounts, 'following'),
        postCount: XUserParser.numWithFallback(legacy, 'statuses_count',
          tweetCounts, 'tweets'),
        verified: userIsVerified(result), verifiedType: userVerifiedType(result), avatarShape: userAvatarShape(result),
        following: XUserParser.optionalFlag(perspectives, legacy, 'following'),
        followedBy: XUserParser.flag(perspectives, 'followed_by') || XUserParser.flag(legacy, 'followed_by'),
        blocking: XUserParser.optionalFlag(perspectives, legacy, 'blocking'),
        avatarUrl: avatarUrl,
        bannerUrl: bannerUrl,
        createdAt: XUserParser.createdAt(core, legacy),
        location: String(legacy['location'] ?? ''),
        website: XUserParser.website(legacy),
        muting: XUserParser.optionalFlag(perspectives, legacy, 'muting'),
        notifications: XUserParser.flag(legacy, 'notifications')
      };
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'parse failed: %{public}s', JSON.stringify(e));
      return null;
    }
  }

  private static resultOf(wrapper: Record<string, Object>): Record<string, Object> {
    const result: Record<string, Object> = XUserParser.obj(wrapper, 'result');
    if (Object.keys(result).length === 0) {
      return {};
    }
    if (String(result['__typename'] ?? '') !== 'User') {
      return {};
    }
    return result;
  }

  private static website(legacy: Record<string, Object>): string {
    const url: Record<string, Object> = XUserParser.obj(XUserParser.obj(legacy, 'entities'), 'url');
    const urls: Object | undefined = url['urls'];
    if (urls instanceof Array && urls.length > 0) {
      const first: Record<string, Object> = urls[0] as Record<string, Object>;
      return String(first['expanded_url'] ?? first['url'] ?? '');
    }
    return String(legacy['url'] ?? '');
  }

  private static createdAt(core: Record<string, Object>, legacy: Record<string, Object>): string {
    const timestamp: Object | undefined = core['created_at_ms'];
    if (timestamp !== undefined && timestamp !== null && String(timestamp).length > 0) {
      const date: Date = new Date(Number(timestamp));
      if (!isNaN(date.getTime())) {
        return date.toISOString();
      }
    }
    return String(core['created_at'] ?? legacy['created_at'] ?? '');
  }

  public static highResAvatarUrl(url: string): string {
    let out: string = url;
    out = XUserParser.replaceQueryAvatarSize(out, 'normal');
    out = XUserParser.replaceQueryAvatarSize(out, 'bigger');
    out = XUserParser.replaceQueryAvatarSize(out, 'mini');
    return XUserParser.replacePathAvatarSize(out);
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

  private static highResBannerUrl(url: string): string {
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
    if (XUserParser.isBannerSizeSegment(lastSegment)) {
      return body.substring(0, slash + 1) + size + query;
    }
    return body + '/' + size + query;
  }

  private static isBannerSizeSegment(value: string): boolean {
    const split: number = value.indexOf('x');
    if (split <= 0 || split >= value.length - 1) {
      return false;
    }
    return XUserParser.isDigits(value.substring(0, split)) &&
      XUserParser.isDigits(value.substring(split + 1));
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

  private static obj(source: Record<string, Object> | undefined, key: string): Record<string, Object> {
    if (source === undefined) {
      return {};
    }
    const value: Object | undefined = source[key];
    if (value === undefined || value === null || typeof value !== 'object') {
      return {};
    }
    if (value instanceof Array) {
      return {};
    }
    return value as Record<string, Object>;
  }

  private static num(source: Record<string, Object>, key: string): number {
    const value: Object | undefined = source[key];
    if (value === undefined || value === null) {
      return 0;
    }
    const parsed: number = Number(value);
    return isNaN(parsed) ? 0 : parsed;
  }

  private static numWithFallback(primary: Record<string, Object>, primaryKey: string,
    fallback: Record<string, Object>, fallbackKey: string): number {
    const primaryValue: Object | undefined = primary[primaryKey];
    if (primaryValue !== undefined && primaryValue !== null) {
      const parsed: number = Number(primaryValue);
      if (!isNaN(parsed)) {
        return parsed;
      }
    }
    const fallbackValue: Object | undefined = fallback[fallbackKey];
    if (fallbackValue === undefined || fallbackValue === null) {
      return 0;
    }
    const parsedFallback: number = Number(fallbackValue);
    return isNaN(parsedFallback) ? 0 : parsedFallback;
  }

  private static flag(source: Record<string, Object>, key: string): boolean {
    const value: Object | undefined = source[key];
    return value === true;
  }

  private static optionalFlag(primary: Record<string, Object>, fallback: Record<string, Object>, key: string): boolean | undefined {
    const value: Object | undefined = primary[key] ?? fallback[key];
    return typeof value === 'boolean' ? value as boolean : undefined;
  }
}
