import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

export const STORAGE_KEY_HOME_TAB_MATERIAL_LEVEL: string = 'harmonyx.home_tab_material_level';
export const STORAGE_KEY_CLASSIC_BOTTOM_BAR: string = 'harmonyx.classic_bottom_bar';
export const STORAGE_KEY_ROOT_TAB_LABELS_VISIBLE: string = 'harmonyx.root_tab_labels_visible';
export const HDS_TAB_MATERIAL_EXQUISITE: number = 0;
export const HDS_TAB_MATERIAL_GENTLE: number = 1;
export const HDS_TAB_MATERIAL_SMOOTH: number = 2;
export const HDS_TAB_MATERIAL_ADAPTIVE: number = 10;
export const DEFAULT_HOME_TAB_MATERIAL_LEVEL: number = HDS_TAB_MATERIAL_ADAPTIVE;

export class HdsTabsSettingsStore {
  private static readonly STORE_NAME: string = 'harmonyx_hds_tabs';
  private static readonly HOME_TAB_MATERIAL_LEVEL_KEY: string = 'home_tab_material_level';
  private static readonly CLASSIC_BOTTOM_BAR_KEY: string = 'classic_bottom_bar';
  private static readonly ROOT_TAB_LABELS_VISIBLE_KEY: string = 'root_tab_labels_visible';

  loadRootTabLabelsVisible(context: common.Context): boolean {
    try {
      const options: preferences.Options = { name: HdsTabsSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      return store.getSync(HdsTabsSettingsStore.ROOT_TAB_LABELS_VISIBLE_KEY, true) as boolean;
    } catch (error) {
      return true;
    }
  }

  saveRootTabLabelsVisible(context: common.Context, visible: boolean): boolean {
    try {
      const options: preferences.Options = { name: HdsTabsSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      store.putSync(HdsTabsSettingsStore.ROOT_TAB_LABELS_VISIBLE_KEY, visible);
      store.flushSync();
      AppStorage.setOrCreate<boolean>(STORAGE_KEY_ROOT_TAB_LABELS_VISIBLE, visible);
      return true;
    } catch (error) {
      return false;
    }
  }

  loadClassicBottomBar(context: common.Context): boolean {
    try {
      const options: preferences.Options = { name: HdsTabsSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      return store.getSync(HdsTabsSettingsStore.CLASSIC_BOTTOM_BAR_KEY, false) as boolean;
    } catch (error) {
      return false;
    }
  }

  saveClassicBottomBar(context: common.Context, enabled: boolean): boolean {
    try {
      const options: preferences.Options = { name: HdsTabsSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      store.putSync(HdsTabsSettingsStore.CLASSIC_BOTTOM_BAR_KEY, enabled);
      store.flushSync();
      AppStorage.setOrCreate<boolean>(STORAGE_KEY_CLASSIC_BOTTOM_BAR, enabled);
      return true;
    } catch (error) {
      return false;
    }
  }

  loadHomeTabMaterialLevel(context: common.Context): number {
    try {
      const options: preferences.Options = { name: HdsTabsSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      const value: number = store.getSync(HdsTabsSettingsStore.HOME_TAB_MATERIAL_LEVEL_KEY,
        DEFAULT_HOME_TAB_MATERIAL_LEVEL) as number;
      return this.validHomeTabMaterialLevel(value);
    } catch (error) {
      return DEFAULT_HOME_TAB_MATERIAL_LEVEL;
    }
  }

  saveHomeTabMaterialLevel(context: common.Context, level: number): boolean {
    const value: number = this.validHomeTabMaterialLevel(level);
    try {
      const options: preferences.Options = { name: HdsTabsSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      store.putSync(HdsTabsSettingsStore.HOME_TAB_MATERIAL_LEVEL_KEY, value);
      store.flushSync();
      AppStorage.setOrCreate<number>(STORAGE_KEY_HOME_TAB_MATERIAL_LEVEL, value);
      return true;
    } catch (error) {
      return false;
    }
  }

  private validHomeTabMaterialLevel(value: number): number {
    if (value === HDS_TAB_MATERIAL_EXQUISITE || value === HDS_TAB_MATERIAL_GENTLE ||
      value === HDS_TAB_MATERIAL_SMOOTH) {
      return value;
    }
    return HDS_TAB_MATERIAL_ADAPTIVE;
  }
}

export const hdsTabsSettingsStore: HdsTabsSettingsStore = new HdsTabsSettingsStore();
