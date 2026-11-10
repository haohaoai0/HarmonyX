import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { SIDEBAR_ITEM_IDS, sidebarOrderedIds, DEFAULT_SIDEBAR_HIDDEN } from '../utils/SidebarItems';

export const STORAGE_KEY_SIDEBAR_ORDER: string = 'harmonyx.sidebar_order';
export const STORAGE_KEY_SIDEBAR_HIDDEN: string = 'harmonyx.sidebar_hidden';
export const STORAGE_KEY_SIDEBAR_SEARCH_CAPSULE: string = 'harmonyx.sidebar_search_capsule';

export class SidebarSettings {
  order: string = '';
  hidden: string = DEFAULT_SIDEBAR_HIDDEN;
  searchCapsule: boolean = false;
}

export class SidebarSettingsStore {
  load(context: common.Context): SidebarSettings {
    const result: SidebarSettings = new SidebarSettings();
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: 'harmonyx_sidebar' });
      result.order = sidebarOrderedIds(store.getSync('order', '') as string).join(',');
      result.hidden = this.normalizeHidden(store.getSync('hidden', DEFAULT_SIDEBAR_HIDDEN) as string);
      result.searchCapsule = store.getSync('search_capsule', false) as boolean;
    } catch (error) {}
    return result;
  }

  save(context: common.Context, order: string, hidden: string): boolean {
    const normalizedOrder: string = sidebarOrderedIds(order).join(',');
    const normalizedHidden: string = this.normalizeHidden(hidden);
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: 'harmonyx_sidebar' });
      store.putSync('order', normalizedOrder);
      store.putSync('hidden', normalizedHidden);
      store.flushSync();
      AppStorage.setOrCreate<string>(STORAGE_KEY_SIDEBAR_ORDER, normalizedOrder);
      AppStorage.setOrCreate<string>(STORAGE_KEY_SIDEBAR_HIDDEN, normalizedHidden);
      return true;
    } catch (error) { return false; }
  }

  saveSearchCapsule(context: common.Context, enabled: boolean): boolean {
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: 'harmonyx_sidebar' });
      store.putSync('search_capsule', enabled);
      store.flushSync();
      AppStorage.setOrCreate<boolean>(STORAGE_KEY_SIDEBAR_SEARCH_CAPSULE, enabled);
      return true;
    } catch (error) { return false; }
  }

  private normalizeHidden(hidden: string): string {
    const ids: string[] = hidden.split(',');
    return SIDEBAR_ITEM_IDS.filter((id: string): boolean => ids.indexOf(id) >= 0).join(',');
  }
}

export const sidebarSettingsStore: SidebarSettingsStore = new SidebarSettingsStore();
