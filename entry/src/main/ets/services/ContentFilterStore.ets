// Reading controls shared by every tweet timeline. The store keeps plain text
// lists so users can paste, copy, and edit rules without a separate manager UI.
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import type { Tweet, MediaAttachment } from '../models/Tweet';
import { isAdPost } from '../utils/PostDisclosure';

export const STORAGE_KEY_FILTER_ONLY_MEDIA: string = 'harmonyx.filter_only_media';
export const STORAGE_KEY_FILTER_HIDE_REPOSTS: string = 'harmonyx.filter_hide_reposts';
export const STORAGE_KEY_FILTER_HIDE_REPLIES: string = 'harmonyx.filter_hide_replies';
export const STORAGE_KEY_FILTER_HIDE_ADS: string = 'harmonyx.filter_hide_ads';
export const STORAGE_KEY_FILTER_KEYWORDS: string = 'harmonyx.filter_keywords';
export const STORAGE_KEY_FILTER_MUTED_USERS: string = 'harmonyx.filter_muted_users';
export const STORAGE_KEY_FILTER_REVISION: string = 'harmonyx.filter_revision';

export class ContentFilterSettings {
  onlyMedia: boolean = false;
  hideReposts: boolean = false;
  hideReplies: boolean = false;
  hideAds: boolean = true;
  keywordsText: string = '';
  mutedUsersText: string = '';

  constructor(onlyMedia: boolean, hideReposts: boolean, hideReplies: boolean,
    keywordsText: string, mutedUsersText: string, hideAds: boolean = true) {
    this.onlyMedia = onlyMedia;
    this.hideReposts = hideReposts;
    this.hideReplies = hideReplies;
    this.hideAds = hideAds;
    this.keywordsText = keywordsText;
    this.mutedUsersText = mutedUsersText;
  }
}

export class ContentFilterStore {
  private static readonly STORE_NAME: string = 'harmonyx_content_filter';
  private static readonly ONLY_MEDIA_KEY: string = 'only_media';
  private static readonly HIDE_REPOSTS_KEY: string = 'hide_reposts';
  private static readonly HIDE_REPLIES_KEY: string = 'hide_replies';
  private static readonly HIDE_ADS_KEY: string = 'hide_ads';
  private static readonly KEYWORDS_KEY: string = 'keywords';
  private static readonly MUTED_USERS_KEY: string = 'muted_users';

  load(context: common.Context): ContentFilterSettings {
    try {
      const options: preferences.Options = { name: ContentFilterStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      const settings: ContentFilterSettings = new ContentFilterSettings(
        store.getSync(ContentFilterStore.ONLY_MEDIA_KEY, false) as boolean,
        store.getSync(ContentFilterStore.HIDE_REPOSTS_KEY, false) as boolean,
        store.getSync(ContentFilterStore.HIDE_REPLIES_KEY, false) as boolean,
        store.getSync(ContentFilterStore.KEYWORDS_KEY, '') as string,
        store.getSync(ContentFilterStore.MUTED_USERS_KEY, '') as string,
        store.getSync(ContentFilterStore.HIDE_ADS_KEY, true) as boolean
      );
      this.publish(settings);
      return settings;
    } catch (error) {
      const settings: ContentFilterSettings = new ContentFilterSettings(false, false, false, '', '', true);
      this.publish(settings);
      return settings;
    }
  }

  save(context: common.Context, settings: ContentFilterSettings): boolean {
    const cleaned: ContentFilterSettings = new ContentFilterSettings(
      settings.onlyMedia,
      settings.hideReposts,
      settings.hideReplies,
      this.normaliseText(settings.keywordsText),
      this.normaliseText(settings.mutedUsersText),
      settings.hideAds
    );
    try {
      const options: preferences.Options = { name: ContentFilterStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      store.putSync(ContentFilterStore.ONLY_MEDIA_KEY, cleaned.onlyMedia);
      store.putSync(ContentFilterStore.HIDE_REPOSTS_KEY, cleaned.hideReposts);
      store.putSync(ContentFilterStore.HIDE_REPLIES_KEY, cleaned.hideReplies);
      store.putSync(ContentFilterStore.HIDE_ADS_KEY, cleaned.hideAds);
      store.putSync(ContentFilterStore.KEYWORDS_KEY, cleaned.keywordsText);
      store.putSync(ContentFilterStore.MUTED_USERS_KEY, cleaned.mutedUsersText);
      store.flushSync();
      this.publish(cleaned);
      return true;
    } catch (error) {
      return false;
    }
  }

  publish(settings: ContentFilterSettings): void {
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_FILTER_ONLY_MEDIA, settings.onlyMedia);
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_FILTER_HIDE_REPOSTS, settings.hideReposts);
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_FILTER_HIDE_REPLIES, settings.hideReplies);
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_FILTER_HIDE_ADS, settings.hideAds);
    AppStorage.setOrCreate<string>(STORAGE_KEY_FILTER_KEYWORDS, this.normaliseText(settings.keywordsText));
    AppStorage.setOrCreate<string>(STORAGE_KEY_FILTER_MUTED_USERS, this.normaliseText(settings.mutedUsersText));
    const previous: number = AppStorage.get<number>(STORAGE_KEY_FILTER_REVISION) ?? 0;
    AppStorage.setOrCreate<number>(STORAGE_KEY_FILTER_REVISION, previous + 1);
  }

  filter(tweets: Tweet[], settings: ContentFilterSettings): Tweet[] {
    const out: Tweet[] = [];
    for (let i: number = 0; i < tweets.length; i++) {
      if (!this.shouldHide(tweets[i], settings)) {
        out.push(tweets[i]);
      }
    }
    return out;
  }

  shouldHide(tweet: Tweet, settings: ContentFilterSettings): boolean {
    if (settings.hideAds && isAdPost(tweet.presentation)) {
      return true;
    }
    if (settings.onlyMedia && !this.hasMedia(tweet)) {
      return true;
    }
    if (settings.hideReposts && tweet.isRepost === true) {
      return true;
    }
    if (settings.hideReplies && tweet.isReply === true) {
      return true;
    }
    if (this.userMuted(tweet, settings.mutedUsersText)) {
      return true;
    }
    if (this.keywordMuted(tweet, settings.keywordsText)) {
      return true;
    }
    return false;
  }

  private hasMedia(tweet: Tweet): boolean {
    const attachments: MediaAttachment[] | undefined = tweet.attachments;
    if (attachments !== undefined && attachments.length > 0) {
      return true;
    }
    if (tweet.quotedTweet !== undefined && tweet.quotedTweet.attachments !== undefined &&
      tweet.quotedTweet.attachments.length > 0) {
      return true;
    }
    return false;
  }

  private userMuted(tweet: Tweet, mutedUsersText: string): boolean {
    const tokens: string[] = this.tokens(mutedUsersText, true);
    if (tokens.length === 0) {
      return false;
    }
    const handle: string = tweet.author.username.toLowerCase();
    const name: string = tweet.author.name.toLowerCase();
    const id: string = tweet.author.id.toLowerCase();
    for (let i: number = 0; i < tokens.length; i++) {
      const token: string = tokens[i];
      if (handle === token || name === token || id === token) {
        return true;
      }
    }
    return false;
  }

  private keywordMuted(tweet: Tweet, keywordsText: string): boolean {
    const tokens: string[] = this.tokens(keywordsText, false);
    if (tokens.length === 0) {
      return false;
    }
    let body: string = tweet.text.toLowerCase();
    if (tweet.quotedTweet !== undefined) {
      body += '\n' + tweet.quotedTweet.text.toLowerCase();
    }
    for (let i: number = 0; i < tokens.length; i++) {
      if (body.includes(tokens[i])) {
        return true;
      }
    }
    return false;
  }

  private tokens(text: string, stripAt: boolean): string[] {
    const lines: string[] = this.normaliseText(text).split('\n');
    const out: string[] = [];
    for (let i: number = 0; i < lines.length; i++) {
      let token: string = lines[i].trim().toLowerCase();
      if (stripAt && token.startsWith('@')) {
        token = token.substring(1);
      }
      if (token.length > 0) {
        out.push(token);
      }
    }
    return out;
  }

  normaliseText(text: string): string {
    const unified: string = text.split('\r').join('\n').split(',').join('\n').split('，').join('\n');
    const lines: string[] = unified.split('\n');
    const out: string[] = [];
    for (let i: number = 0; i < lines.length; i++) {
      const line: string = lines[i].trim();
      if (line.length > 0 && !this.containsLine(out, line)) {
        out.push(line);
      }
    }
    return out.join('\n');
  }

  private containsLine(lines: string[], value: string): boolean {
    const lowered: string = value.toLowerCase();
    for (let i: number = 0; i < lines.length; i++) {
      if (lines[i].toLowerCase() === lowered) {
        return true;
      }
    }
    return false;
  }
}

export const contentFilterStore: ContentFilterStore = new ContentFilterStore();
