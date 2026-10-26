import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

export const STORAGE_KEY_BOTTOM_TAB_ORDER: string = 'harmonyx.bottom_tab_order';
export const STORAGE_KEY_HOME_TAB_ORDER: string = 'harmonyx.home_tab_order';

export class TabOrderSettingsStore {
  load(context: common.Context, home: boolean): string {
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: 'harmonyx_tab_order' });
      return store.getSync(home ? 'home' : 'bottom', '') as string;
    } catch (error) { return ''; }
  }

  save(context: common.Context, home: boolean, order: string): boolean {
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: 'harmonyx_tab_order' });
      store.putSync(home ? 'home' : 'bottom', order);
      store.flushSync();
      AppStorage.setOrCreate<string>(home ? STORAGE_KEY_HOME_TAB_ORDER : STORAGE_KEY_BOTTOM_TAB_ORDER, order);
      return true;
    } catch (error) { return false; }
  }
}

export const tabOrderSettingsStore: TabOrderSettingsStore = new TabOrderSettingsStore();
