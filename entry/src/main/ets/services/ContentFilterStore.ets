// Reading controls shared by every tweet timeline. The store keeps plain text
// lists so users can paste, copy, and edit rules without a separate manager UI.
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import type { Tweet, MediaAttachment } from '../models/Tweet';
import { isAdPost } from '../utils/PostDisclosure';

export const STORAGE_KEY_FOR_YOU_ONLY_SENSITIVE: string = 'harmonyx.for_you_only_sensitive';
export const STORAGE_KEY_FILTER_ONLY_MEDIA: string = 'harmonyx.filter_only_media';
export const STORAGE_KEY_FILTER_HIDE_REPOSTS: string = 'harmonyx.filter_hide_reposts';
export const STORAGE_KEY_FILTER_HIDE_REPLIES: string = 'harmonyx.filter_hide_replies';
export const STORAGE_KEY_FILTER_HIDE_ADS: string = 'harmonyx.filter_hide_ads';
export const STORAGE_KEY_FILTER_KEYWORDS: string = 'harmonyx.filter_keywords';
export const STORAGE_KEY_FILTER_MUTED_USERS: string = 'harmonyx.filter_muted_users';
export const STORAGE_KEY_FILTER_REVISION: string = 'harmonyx.filter_revision';
export const STORAGE_KEY_FILTER_LANGUAGES: string = 'harmonyx.filter_languages';

export function postLanguageCode(tag: string): string {
  const code: string = tag.trim().toLowerCase().replace(/_/g, '-').split('-')[0];
  if (code === 'iw') { return 'he'; }
  if (code === 'in') { return 'id'; }
  return /^[a-z]{2,3}$/.test(code) && code !== 'und' && code !== 'zxx' ? code : '';
}

export function normalizedMutedLanguages(value: string): string {
  const codes: string[] = [];
  for (const tag of value.split(/[\s,;]+/)) {
    const code: string = postLanguageCode(tag);
    if (code.length > 0 && codes.indexOf(code) < 0) { codes.push(code); }
  }
  return codes.join(',');
}

export class ContentFilterSettings {
  onlySensitiveForYou: boolean = false;
  onlySensitiveAgeConfirmed: boolean = false;
  onlyMedia: boolean = false;
  hideReposts: boolean = false;
  hideReplies: boolean = false;
  hideAds: boolean = true;
  keywordsText: string = '';
  mutedUsersText: string = '';
  mutedLanguagesText: string = '';

  constructor(onlyMedia: boolean, hideReposts: boolean, hideReplies: boolean,
    keywordsText: string, mutedUsersText: string, hideAds: boolean = true,
    mutedLanguagesText: string = '', onlySensitiveForYou: boolean = false,
    onlySensitiveAgeConfirmed: boolean = false) {
    this.onlySensitiveForYou = onlySensitiveForYou;
    this.onlySensitiveAgeConfirmed = onlySensitiveAgeConfirmed;
    this.onlyMedia = onlyMedia;
    this.hideReposts = hideReposts;
    this.hideReplies = hideReplies;
    this.hideAds = hideAds;
    this.keywordsText = keywordsText;
    this.mutedUsersText = mutedUsersText;
    this.mutedLanguagesText = normalizedMutedLanguages(mutedLanguagesText);
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
  private static readonly LANGUAGES_KEY: string = 'languages';
  private static readonly SENSITIVE_ONLY_AGE_CONFIRMED_KEY: string = 'for_you_only_sensitive_age_confirmed';

  load(context: common.Context): ContentFilterSettings {
    try {
      const options: preferences.Options = { name: ContentFilterStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      const storedSensitiveOnly: boolean = store.getSync('for_you_only_sensitive', false) as boolean;
      const ageConfirmed: boolean =
        store.getSync(ContentFilterStore.SENSITIVE_ONLY_AGE_CONFIRMED_KEY, false) as boolean;
      const onlySensitiveForYou: boolean = storedSensitiveOnly && ageConfirmed;
      if (storedSensitiveOnly && !ageConfirmed) {
        store.putSync('for_you_only_sensitive', false);
        store.flushSync();
      }
      const settings: ContentFilterSettings = new ContentFilterSettings(
        store.getSync(ContentFilterStore.ONLY_MEDIA_KEY, false) as boolean,
        store.getSync(ContentFilterStore.HIDE_REPOSTS_KEY, false) as boolean,
        store.getSync(ContentFilterStore.HIDE_REPLIES_KEY, false) as boolean,
        store.getSync(ContentFilterStore.KEYWORDS_KEY, '') as string,
        store.getSync(ContentFilterStore.MUTED_USERS_KEY, '') as string,
        store.getSync(ContentFilterStore.HIDE_ADS_KEY, true) as boolean,
        store.getSync(ContentFilterStore.LANGUAGES_KEY, '') as string,
        onlySensitiveForYou, ageConfirmed
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
      settings.hideAds,
      settings.mutedLanguagesText, settings.onlySensitiveForYou,
      settings.onlySensitiveForYou && settings.onlySensitiveAgeConfirmed
    );
    try {
      const options: preferences.Options = { name: ContentFilterStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      store.putSync('for_you_only_sensitive', cleaned.onlySensitiveForYou);
      store.putSync(ContentFilterStore.SENSITIVE_ONLY_AGE_CONFIRMED_KEY,
        cleaned.onlySensitiveAgeConfirmed);
      store.putSync(ContentFilterStore.ONLY_MEDIA_KEY, cleaned.onlyMedia);
      store.putSync(ContentFilterStore.HIDE_REPOSTS_KEY, cleaned.hideReposts);
      store.putSync(ContentFilterStore.HIDE_REPLIES_KEY, cleaned.hideReplies);
      store.putSync(ContentFilterStore.HIDE_ADS_KEY, cleaned.hideAds);
      store.putSync(ContentFilterStore.KEYWORDS_KEY, cleaned.keywordsText);
      store.putSync(ContentFilterStore.MUTED_USERS_KEY, cleaned.mutedUsersText);
      store.putSync(ContentFilterStore.LANGUAGES_KEY, cleaned.mutedLanguagesText);
      store.flushSync();
      this.publish(cleaned);
      return true;
    } catch (error) {
      return false;
    }
  }

  publish(settings: ContentFilterSettings): void {
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_FOR_YOU_ONLY_SENSITIVE, settings.onlySensitiveForYou);
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_FILTER_ONLY_MEDIA, settings.onlyMedia);
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_FILTER_HIDE_REPOSTS, settings.hideReposts);
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_FILTER_HIDE_REPLIES, settings.hideReplies);
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_FILTER_HIDE_ADS, settings.hideAds);
    AppStorage.setOrCreate<string>(STORAGE_KEY_FILTER_KEYWORDS, this.normaliseText(settings.keywordsText));
    AppStorage.setOrCreate<string>(STORAGE_KEY_FILTER_MUTED_USERS, this.normaliseText(settings.mutedUsersText));
    AppStorage.setOrCreate<string>(STORAGE_KEY_FILTER_LANGUAGES, normalizedMutedLanguages(settings.mutedLanguagesText));
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
    // Missing language and media-only posts remain visible. A quoted post's
    // language must not hide an otherwise allowed author commentary.
    const language: string = postLanguageCode(tweet.language ?? '');
    if (language.length > 0 && tweet.text.trim().length > 0 &&
      settings.mutedLanguagesText.split(',').indexOf(language) >= 0) { return true; }
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

export function isSensitivePost(tweet: Tweet): boolean {
  return hasSensitiveContent(tweet) || (tweet.replyContext ?? [])
    .some((parent: Tweet): boolean => hasSensitiveContent(parent));
}

function hasSensitiveContent(tweet: Tweet): boolean {
  return tweet.possiblySensitive === true || tweet.quotedTweet?.possiblySensitive === true ||
    (tweet.attachments ?? []).some((media: MediaAttachment): boolean => media.sensitive === true) ||
    (tweet.quotedTweet?.attachments ?? []).some((media: MediaAttachment): boolean => media.sensitive === true);
}
