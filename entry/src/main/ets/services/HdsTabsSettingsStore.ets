import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

export const STORAGE_KEY_HOME_TAB_MATERIAL_LEVEL: string = 'harmonyx.home_tab_material_level';
export const STORAGE_KEY_CLASSIC_BOTTOM_BAR: string = 'harmonyx.classic_bottom_bar';
export const STORAGE_KEY_SPLIT_BOTTOM_BAR: string = 'harmonyx.split_bottom_bar';
export const STORAGE_KEY_NATIVE_BOTTOM_BAR: string = 'harmonyx.native_bottom_bar';
export const STORAGE_KEY_NATIVE_TAB_MATERIAL_LEVEL: string = 'harmonyx.native_tab_material_level';
export const DEFAULT_NATIVE_TAB_MATERIAL_LEVEL: number = 0;
export const STORAGE_KEY_ROOT_TAB_LABELS_VISIBLE: string = 'harmonyx.root_tab_labels_visible';
export const STORAGE_KEY_ROOT_LIQUID_TAB_INDICATOR_ENABLED: string = 'harmonyx.root_liquid_tab_indicator_enabled';
export const STORAGE_KEY_ROOT_TAB_GRADIENT_MASK_ENABLED: string = 'harmonyx.root_tab_gradient_mask_enabled';
export const HDS_TAB_MATERIAL_EXQUISITE: number = 0;
export const HDS_TAB_MATERIAL_GENTLE: number = 1;
export const HDS_TAB_MATERIAL_SMOOTH: number = 2;
export const HDS_TAB_MATERIAL_ADAPTIVE: number = 10;
export const DEFAULT_HOME_TAB_MATERIAL_LEVEL: number = HDS_TAB_MATERIAL_ADAPTIVE;

export class HdsTabsSettingsStore {
  private static readonly STORE_NAME: string = 'harmonyx_hds_tabs';
  private static readonly HOME_TAB_MATERIAL_LEVEL_KEY: string = 'home_tab_material_level';
  private static readonly CLASSIC_BOTTOM_BAR_KEY: string = 'classic_bottom_bar';
  private static readonly SPLIT_BOTTOM_BAR_KEY: string = 'split_bottom_bar';
  private static readonly NATIVE_BOTTOM_BAR_KEY: string = 'native_bottom_bar';
  private static readonly NATIVE_TAB_MATERIAL_LEVEL_KEY: string = 'native_tab_material_level';
  private static readonly ROOT_TAB_LABELS_VISIBLE_KEY: string = 'root_tab_labels_visible';
  private static readonly ROOT_LIQUID_TAB_INDICATOR_ENABLED_KEY: string = 'root_liquid_tab_indicator_enabled';
  private static readonly ROOT_TAB_GRADIENT_MASK_ENABLED_KEY: string = 'root_tab_gradient_mask_enabled';

  loadRootTabGradientMaskEnabled(context: common.Context): boolean {
    try {
      const options: preferences.Options = { name: HdsTabsSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      return store.getSync(HdsTabsSettingsStore.ROOT_TAB_GRADIENT_MASK_ENABLED_KEY, true) as boolean;
    } catch (error) {
      return true;
    }
  }

  saveRootTabGradientMaskEnabled(context: common.Context, enabled: boolean): boolean {
    try {
      const options: preferences.Options = { name: HdsTabsSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      store.putSync(HdsTabsSettingsStore.ROOT_TAB_GRADIENT_MASK_ENABLED_KEY, enabled);
      store.flushSync();
      AppStorage.setOrCreate<boolean>(STORAGE_KEY_ROOT_TAB_GRADIENT_MASK_ENABLED, enabled);
      return true;
    } catch (error) {
      return false;
    }
  }

  loadRootLiquidTabIndicatorEnabled(context: common.Context): boolean {
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context,
        { name: HdsTabsSettingsStore.STORE_NAME });
      return store.getSync(HdsTabsSettingsStore.ROOT_LIQUID_TAB_INDICATOR_ENABLED_KEY, true) as boolean;
    } catch (error) { return true; }
  }

  saveRootLiquidTabIndicatorEnabled(context: common.Context, enabled: boolean): boolean {
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context,
        { name: HdsTabsSettingsStore.STORE_NAME });
      store.putSync(HdsTabsSettingsStore.ROOT_LIQUID_TAB_INDICATOR_ENABLED_KEY, enabled);
      store.flushSync();
      AppStorage.setOrCreate<boolean>(STORAGE_KEY_ROOT_LIQUID_TAB_INDICATOR_ENABLED, enabled);
      return true;
    } catch (error) { return false; }
  }

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

  loadSplitBottomBar(context: common.Context): boolean {
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context,
        { name: HdsTabsSettingsStore.STORE_NAME });
      return store.getSync(HdsTabsSettingsStore.SPLIT_BOTTOM_BAR_KEY, false) as boolean;
    } catch (error) { return false; }
  }

  loadNativeBottomBar(context: common.Context): boolean {
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context,
        { name: HdsTabsSettingsStore.STORE_NAME });
      return store.getSync(HdsTabsSettingsStore.NATIVE_BOTTOM_BAR_KEY, false) as boolean;
    } catch (error) { return false; }
  }

  loadNativeTabMaterialLevel(context: common.Context): number {
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context,
        { name: HdsTabsSettingsStore.STORE_NAME });
      return this.validNativeTabMaterialLevel(store.getSync(HdsTabsSettingsStore.NATIVE_TAB_MATERIAL_LEVEL_KEY,
        DEFAULT_NATIVE_TAB_MATERIAL_LEVEL) as number);
    } catch (error) { return DEFAULT_NATIVE_TAB_MATERIAL_LEVEL; }
  }

  saveNativeTabMaterialLevel(context: common.Context, level: number): boolean {
    const value: number = this.validNativeTabMaterialLevel(level);
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context,
        { name: HdsTabsSettingsStore.STORE_NAME });
      store.putSync(HdsTabsSettingsStore.NATIVE_TAB_MATERIAL_LEVEL_KEY, value);
      store.flushSync();
      AppStorage.setOrCreate<number>(STORAGE_KEY_NATIVE_TAB_MATERIAL_LEVEL, value);
      return true;
    } catch (error) { return false; }
  }

  private validNativeTabMaterialLevel(level: number): number {
    return Number.isInteger(level) && level >= 0 && level <= 4 ? level : DEFAULT_NATIVE_TAB_MATERIAL_LEVEL;
  }

  // One flush keeps all four presentations mutually exclusive on restart.
  saveNavigationStyle(context: common.Context, style: number): boolean {
    if (style !== 0 && style !== 1 && style !== 2 && style !== 3) { return false; }
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context,
        { name: HdsTabsSettingsStore.STORE_NAME });
      store.putSync(HdsTabsSettingsStore.CLASSIC_BOTTOM_BAR_KEY, style === 2);
      store.putSync(HdsTabsSettingsStore.SPLIT_BOTTOM_BAR_KEY, style === 1 || style === 3);
      store.putSync(HdsTabsSettingsStore.NATIVE_BOTTOM_BAR_KEY, style === 3);
      store.flushSync();
      AppStorage.setOrCreate<boolean>(STORAGE_KEY_CLASSIC_BOTTOM_BAR, style === 2);
      AppStorage.setOrCreate<boolean>(STORAGE_KEY_SPLIT_BOTTOM_BAR, style === 1 || style === 3);
      AppStorage.setOrCreate<boolean>(STORAGE_KEY_NATIVE_BOTTOM_BAR, style === 3);
      return true;
    } catch (error) { return false; }
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
