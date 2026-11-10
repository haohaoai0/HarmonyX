import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

export const STORAGE_KEY_POST_ACTIONS_MASK: string = 'harmonyx.post_actions_mask';
export const STORAGE_KEY_POST_ACTION_COUNTS: string = 'harmonyx.post_action_counts';
export const STORAGE_KEY_POST_COUNT_FORMAT: string = 'harmonyx.post_count_format';
export const DEFAULT_POST_ACTIONS_MASK: number = 127;
export const POST_ACTION_REPLY: number = 1;
export const POST_ACTION_REPOST: number = 2;
export const POST_ACTION_LIKE: number = 4;
export const POST_ACTION_VIEWS: number = 8;
export const POST_ACTION_BOOKMARK: number = 16;
export const POST_ACTION_SHARE: number = 32;
export const POST_ACTION_TRANSLATE: number = 64;

export class PostDisplaySettingsStore {
  loadCountFormat(context: common.Context): number {
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: 'harmonyx_post_display' });
      const format: number = store.getSync('count_format', 0) as number;
      return Number.isInteger(format) && format >= 0 && format <= 2 ? format : 0;
    } catch (error) { return 0; }
  }

  saveCountFormat(context: common.Context, format: number): boolean {
    if (!Number.isInteger(format) || format < 0 || format > 2) { return false; }
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: 'harmonyx_post_display' });
      store.putSync('count_format', format);
      store.flushSync();
      AppStorage.setOrCreate<number>(STORAGE_KEY_POST_COUNT_FORMAT, format);
      return true;
    } catch (error) { return false; }
  }

  loadMask(context: common.Context): number {
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: 'harmonyx_post_display' });
      const mask: number = store.getSync('actions_mask', DEFAULT_POST_ACTIONS_MASK) as number;
      return Number.isInteger(mask) && mask >= 0 && mask <= DEFAULT_POST_ACTIONS_MASK ? mask : DEFAULT_POST_ACTIONS_MASK;
    } catch (error) { return DEFAULT_POST_ACTIONS_MASK; }
  }

  loadCounts(context: common.Context): boolean {
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: 'harmonyx_post_display' });
      return store.getSync('counts', true) as boolean;
    } catch (error) { return true; }
  }

  saveMask(context: common.Context, mask: number): boolean {
    if (!Number.isInteger(mask) || mask < 0 || mask > DEFAULT_POST_ACTIONS_MASK) { return false; }
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: 'harmonyx_post_display' });
      store.putSync('actions_mask', mask);
      store.flushSync();
      AppStorage.setOrCreate<number>(STORAGE_KEY_POST_ACTIONS_MASK, mask);
      return true;
    } catch (error) { return false; }
  }

  saveCounts(context: common.Context, counts: boolean): boolean {
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: 'harmonyx_post_display' });
      store.putSync('counts', counts);
      store.flushSync();
      AppStorage.setOrCreate<boolean>(STORAGE_KEY_POST_ACTION_COUNTS, counts);
      return true;
    } catch (error) { return false; }
  }
}

export const postDisplaySettingsStore: PostDisplaySettingsStore = new PostDisplaySettingsStore();
