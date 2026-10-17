import type { Tweet, MediaAttachment } from '../models/Tweet';

export class ProfileActivityPage {
  posts: Tweet[] = [];
  cursor: string = '';
  loaded: boolean = false;
  loading: boolean = false;
  status: string = '';
}

export class AccountAbout {
  country: string = '';
  source: string = '';
  locationAccurate: boolean = true;
  verifiedSince: string = '';
}

export class ProfileAccountData {
  static about(body: string): AccountAbout | null {
    try {
      const root: Record<string, Object> = JSON.parse(body) as Record<string, Object>;
      const data: Record<string, Object> = ProfileAccountData.obj(root, 'data');
      const wrapper: Record<string, Object> = ProfileAccountData.obj(data, 'user_result_by_screen_name');
      const result: Record<string, Object> = ProfileAccountData.obj(wrapper, 'result');
      const profile: Record<string, Object> = ProfileAccountData.obj(result, 'about_profile');
      if (Object.keys(profile).length === 0) {
        return null;
      }
      const about: AccountAbout = new AccountAbout();
      about.country = String(profile['account_based_in'] ?? '');
      about.source = String(profile['source'] ?? '');
      about.locationAccurate = profile['location_accurate'] !== false;
      return about;
    } catch (error) {
      return null;
    }
  }

  static video(post: Tweet): MediaAttachment | null {
    const media: MediaAttachment[] = post.attachments ?? [];
    for (let i: number = 0; i < media.length; i++) {
      if (media[i].type === 'video' || media[i].type === 'animated_gif') {
        return media[i];
      }
    }
    return null;
  }

  static duration(media: MediaAttachment | null): string {
    const seconds: number = Math.ceil((media === null ? 0 : media.durationMs ?? 0) / 1000);
    if (seconds <= 0) {
      return '';
    }
    const rest: number = seconds % 60;
    return Math.floor(seconds / 60).toString() + ':' + (rest < 10 ? '0' : '') + rest;
  }

  private static obj(source: Record<string, Object>, key: string): Record<string, Object> {
    const value: Object | undefined = source[key];
    return value !== undefined && value !== null && typeof value === 'object' &&
      !(value instanceof Array) ? value as Record<string, Object> : {};
  }
}
