import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import type { TweetAuthor } from '../models/Tweet';
import { accountStore } from './AccountStore';

export const STORAGE_KEY_REPLY_QUALITY_ENABLED: string = 'harmonyx.reply_quality_enabled';
export const STORAGE_KEY_REPLY_QUALITY_REVISION: string = 'harmonyx.reply_quality_revision';

export class ReplyQualityAllowedAuthor {
  id: string = '';
  username: string = '';
  name: string = '';
}

export class ReplyQualitySettings {
  enabled: boolean = false;
  authors: ReplyQualityAllowedAuthor[] = [];
}

// The switch is an app preference; explicit author exceptions belong to the
// active account and are never mixed with the app's mute/block rules.
export class ReplyQualityStore {
  private loaded: boolean = false;
  private accountId: string = '';
  private settings: ReplyQualitySettings = new ReplyQualitySettings();

  load(context: common.Context): ReplyQualitySettings {
    const account: string = accountStore.activeId(context);
    if (!this.loaded || this.accountId !== account) {
      this.accountId = account;
      this.loaded = true;
      this.settings = new ReplyQualitySettings();
      try {
        const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: 'harmonyx_reply_quality' });
        this.settings.enabled = store.getSync('enabled', false) as boolean;
        const raw: ReplyQualityAllowedAuthor[] = JSON.parse(store.getSync(account + ':authors', '[]') as string) as ReplyQualityAllowedAuthor[];
        const seen: Set<string> = new Set<string>();
        for (const author of raw) {
          if (author !== null && typeof author.id === 'string' && author.id.length > 0 && !seen.has(author.id)) {
            const entry: ReplyQualityAllowedAuthor = new ReplyQualityAllowedAuthor();
            entry.id = author.id;
            entry.name = typeof author.name === 'string' ? author.name : '';
            entry.username = typeof author.username === 'string' ? author.username : '';
            seen.add(entry.id);
            this.settings.authors.push(entry);
          }
        }
      } catch (error) { }
      this.publish();
    }
    return this.copy();
  }

  setEnabled(context: common.Context, enabled: boolean): boolean {
    this.load(context);
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: 'harmonyx_reply_quality' });
      store.putSync('enabled', enabled);
      store.flushSync();
      this.settings.enabled = enabled;
      this.publish();
      return true;
    } catch (error) { return false; }
  }

  allow(context: common.Context, author: TweetAuthor): boolean {
    this.load(context);
    if (author.id.length === 0) { return false; }
    const updated: ReplyQualityAllowedAuthor[] = this.settings.authors.filter((item: ReplyQualityAllowedAuthor): boolean => item.id !== author.id);
    const entry: ReplyQualityAllowedAuthor = new ReplyQualityAllowedAuthor();
    entry.id = author.id; entry.name = author.name; entry.username = author.username;
    updated.push(entry);
    return this.saveAuthors(context, updated);
  }

  remove(context: common.Context, authorId: string): boolean {
    this.load(context);
    return this.saveAuthors(context, this.settings.authors.filter((item: ReplyQualityAllowedAuthor): boolean => item.id !== authorId));
  }

  private saveAuthors(context: common.Context, authors: ReplyQualityAllowedAuthor[]): boolean {
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: 'harmonyx_reply_quality' });
      store.putSync(this.accountId + ':authors', JSON.stringify(authors));
      store.flushSync();
      this.settings.authors = authors;
      this.publish();
      return true;
    } catch (error) { return false; }
  }

  private copy(): ReplyQualitySettings {
    const out: ReplyQualitySettings = new ReplyQualitySettings();
    out.enabled = this.settings.enabled;
    out.authors = this.settings.authors.map((author: ReplyQualityAllowedAuthor): ReplyQualityAllowedAuthor => {
      const entry: ReplyQualityAllowedAuthor = new ReplyQualityAllowedAuthor();
      entry.id = author.id; entry.name = author.name; entry.username = author.username;
      return entry;
    });
    return out;
  }

  private publish(): void {
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_REPLY_QUALITY_ENABLED, this.settings.enabled);
    AppStorage.setOrCreate<number>(STORAGE_KEY_REPLY_QUALITY_REVISION,
      (AppStorage.get<number>(STORAGE_KEY_REPLY_QUALITY_REVISION) ?? 0) + 1);
  }
}

export const replyQualityStore: ReplyQualityStore = new ReplyQualityStore();
