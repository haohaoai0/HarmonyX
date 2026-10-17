import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import type { Tweet } from '../models/Tweet';
import { accountStore } from './AccountStore';

export const STORAGE_KEY_POST_MODERATION_REVISION: string = 'harmonyx.post_moderation_revision';

export class PostModerationStore {
  private accountId: string = '';
  private loaded: boolean = false;
  private hiddenIds: string[] = [];
  private hiddenUsers: string[] = [];

  load(context: common.Context): void {
    const accountId: string = accountStore.activeId(context);
    if (this.loaded && this.accountId === accountId) { return; }
    this.loaded = true;
    this.accountId = accountId;
    this.hiddenIds = [];
    this.hiddenUsers = [];
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: 'harmonyx_post_moderation' });
      this.hiddenIds = JSON.parse(store.getSync(accountId + ':posts', '[]') as string) as string[];
      this.hiddenUsers = JSON.parse(store.getSync(accountId + ':users', '[]') as string) as string[];
    } catch (error) { }
  }

  hidden(tweet: Tweet): boolean {
    return this.hiddenIds.indexOf(tweet.id) >= 0 || this.hiddenUsers.indexOf(tweet.author.id) >= 0;
  }

  hide(context: common.Context, id: string, user: boolean = false): boolean {
    this.load(context);
    const current: string[] = user ? this.hiddenUsers : this.hiddenIds;
    const updated: string[] = current.indexOf(id) >= 0 ? current.slice() : [...current, id];
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: 'harmonyx_post_moderation' });
      store.putSync(this.accountId + (user ? ':users' : ':posts'), JSON.stringify(updated));
      store.flushSync();
      if (user) { this.hiddenUsers = updated; } else { this.hiddenIds = updated; }
      AppStorage.setOrCreate<number>(STORAGE_KEY_POST_MODERATION_REVISION,
        (AppStorage.get<number>(STORAGE_KEY_POST_MODERATION_REVISION) ?? 0) + 1);
      return true;
    } catch (error) { return false; }
  }

  unhideUser(context: common.Context, userId: string): boolean {
    this.load(context);
    const updated: string[] = this.hiddenUsers.filter((id: string): boolean => id !== userId);
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: 'harmonyx_post_moderation' });
      store.putSync(this.accountId + ':users', JSON.stringify(updated));
      store.flushSync();
      this.hiddenUsers = updated;
      AppStorage.setOrCreate<number>(STORAGE_KEY_POST_MODERATION_REVISION,
        (AppStorage.get<number>(STORAGE_KEY_POST_MODERATION_REVISION) ?? 0) + 1);
      return true;
    } catch (error) { return false; }
  }
}

export const postModerationStore: PostModerationStore = new PostModerationStore();
