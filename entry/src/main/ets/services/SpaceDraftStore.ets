import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { SpaceDraft } from '../models/SpaceDraft';
import { XAccount, accountStore } from './AccountStore';

class SpaceDraftStore {
  private accountKey(context: common.Context): string {
    const account: XAccount | null = accountStore.active(context);
    return 'draft_' + (account?.id || 'guest');
  }
  load(context: common.Context): SpaceDraft {
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: 'harmonyx_spaces_drafts' });
      const body: string = store.getSync(this.accountKey(context), '') as string;
      return body.length > 0 ? SpaceDraft.normalize(JSON.parse(body) as SpaceDraft) : new SpaceDraft();
    } catch (error) { return new SpaceDraft(); }
  }
  save(context: common.Context, draft: SpaceDraft): boolean {
    try {
      const stored: SpaceDraft = SpaceDraft.normalize(draft);
      stored.updatedAt = Date.now();
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: 'harmonyx_spaces_drafts' });
      store.putSync(this.accountKey(context), JSON.stringify(stored));
      store.flushSync();
      return true;
    } catch (error) { return false; }
  }
  clear(context: common.Context): boolean {
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: 'harmonyx_spaces_drafts' });
      store.deleteSync(this.accountKey(context)); store.flushSync(); return true;
    } catch (error) { return false; }
  }
}

export const spaceDraftStore: SpaceDraftStore = new SpaceDraftStore();
