import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

export const STORAGE_KEY_DESKTOP_LAYOUT: string = 'harmonyx.desktop_layout';
export const STORAGE_KEY_DESKTOP_VIDEO_LAYOUT: string = 'harmonyx.desktop_video_layout';
export const DESKTOP_VIDEO_LAYOUT_SPLIT: number = 0;
export const DESKTOP_VIDEO_LAYOUT_FEED: number = 1;
export const STORAGE_KEY_DESKTOP_ASIDE: string = 'harmonyx.desktop_aside';
export const STORAGE_KEY_DESKTOP_RAIL_AUTO_HIDE: string = 'harmonyx.desktop_rail_auto_hide';
export const STORAGE_KEY_DESKTOP_RAIL_MATERIAL_LEVEL: string = 'harmonyx.desktop_rail_material_level';
export const DEFAULT_DESKTOP_RAIL_MATERIAL_LEVEL: number = -1;
export const STORAGE_KEY_SIDEBAR_MATERIAL_TYPE: string = 'harmonyx.sidebar_material_type';
export const SIDEBAR_MATERIAL_GLASS: number = 0;
export const SIDEBAR_MATERIAL_BLUR: number = 1;
export const SIDEBAR_MATERIAL_SYSTEM: number = 2;
export const STORAGE_KEY_DESKTOP_RAIL_SWIPE: string = 'harmonyx.desktop_rail_swipe';

export class LayoutSettingsStore {
  loadDesktopVideoLayout(context: common.Context): number {
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: 'harmonyx_layout' });
      return store.getSync('desktop_video_layout', DESKTOP_VIDEO_LAYOUT_SPLIT) === DESKTOP_VIDEO_LAYOUT_FEED ?
        DESKTOP_VIDEO_LAYOUT_FEED : DESKTOP_VIDEO_LAYOUT_SPLIT;
    } catch (error) { return DESKTOP_VIDEO_LAYOUT_SPLIT; }
  }

  saveDesktopVideoLayout(context: common.Context, layout: number): boolean {
    if (layout !== DESKTOP_VIDEO_LAYOUT_SPLIT && layout !== DESKTOP_VIDEO_LAYOUT_FEED) { return false; }
    return this.saveOption(context, 'desktop_video_layout', STORAGE_KEY_DESKTOP_VIDEO_LAYOUT, layout);
  }

  private sidebarMaterialType(store: preferences.Preferences): number {
    const type: preferences.ValueType = store.getSync('sidebar_material_type', SIDEBAR_MATERIAL_GLASS);
    if (type === SIDEBAR_MATERIAL_SYSTEM) { return SIDEBAR_MATERIAL_SYSTEM; }
    return type === SIDEBAR_MATERIAL_BLUR ? SIDEBAR_MATERIAL_BLUR : SIDEBAR_MATERIAL_GLASS;
  }

  private sidebarMaterialPreferenceKey(type: number): string {
    if (type === SIDEBAR_MATERIAL_SYSTEM) { return 'sidebar_system_blur_enabled'; }
    if (type === SIDEBAR_MATERIAL_BLUR) { return 'sidebar_gradient_blur_level'; }
    return 'sidebar_glass_material_level';
  }

  private sidebarMaterialLevel(store: preferences.Preferences, type: number): number {
    // Migrate the active legacy choice only. Other modes start at regular
    // strength and then retain their own setting, including an explicit off.
    const legacyLevel: preferences.ValueType = store.getSync('rail_material_level', DEFAULT_DESKTOP_RAIL_MATERIAL_LEVEL);
    const fallback: number = type === this.sidebarMaterialType(store) ?
      (typeof legacyLevel === 'number' && this.validRailMaterialLevel(legacyLevel) ?
        legacyLevel : DEFAULT_DESKTOP_RAIL_MATERIAL_LEVEL) : 2;
    const key: string = this.sidebarMaterialPreferenceKey(type);
    if (type === SIDEBAR_MATERIAL_SYSTEM) {
      const enabled: preferences.ValueType = store.getSync(key, fallback >= 0);
      return typeof enabled === 'boolean' ? (enabled ? 2 : -1) : fallback;
    }
    const level: preferences.ValueType = store.getSync(key, fallback);
    return typeof level === 'number' && this.validRailMaterialLevel(level) ? level : fallback;
  }

  private putSidebarMaterialLevel(store: preferences.Preferences, type: number, level: number): void {
    const key: string = this.sidebarMaterialPreferenceKey(type);
    if (type === SIDEBAR_MATERIAL_SYSTEM) { store.putSync(key, level >= 0); }
    else { store.putSync(key, level); }
  }

  loadSidebarMaterialType(context: common.Context): number {
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: 'harmonyx_layout' });
      return this.sidebarMaterialType(store);
    } catch (error) { return SIDEBAR_MATERIAL_GLASS; }
  }

  saveSidebarMaterialType(context: common.Context, type: number): boolean {
    if (type !== SIDEBAR_MATERIAL_GLASS && type !== SIDEBAR_MATERIAL_BLUR &&
      type !== SIDEBAR_MATERIAL_SYSTEM) { return false; }
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: 'harmonyx_layout' });
      const previousType: number = this.sidebarMaterialType(store);
      const previousLevel: number = this.sidebarMaterialLevel(store, previousType);
      const nextLevel: number = this.sidebarMaterialLevel(store, type);
      this.putSidebarMaterialLevel(store, previousType, previousLevel);
      this.putSidebarMaterialLevel(store, type, nextLevel);
      store.putSync('sidebar_material_type', type);
      // Retain the old key as a projection of the active mode for existing
      // consumers. It is no longer the stored strength of all three modes.
      store.putSync('rail_material_level', nextLevel);
      store.flushSync();
      AppStorage.setOrCreate<number>(STORAGE_KEY_DESKTOP_RAIL_MATERIAL_LEVEL, nextLevel);
      AppStorage.setOrCreate<number>(STORAGE_KEY_SIDEBAR_MATERIAL_TYPE, type);
      return true;
    } catch (error) { return false; }
  }

  loadRailSwipe(context: common.Context): boolean {
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: 'harmonyx_layout' });
      return store.getSync('rail_swipe', true) as boolean;
    } catch (error) { return true; }
  }

  saveRailSwipe(context: common.Context, enabled: boolean): boolean {
    return this.saveOption(context, 'rail_swipe', STORAGE_KEY_DESKTOP_RAIL_SWIPE, enabled);
  }

  private saveOption(context: common.Context, preferenceKey: string, storageKey: string,
    value: number | boolean): boolean {
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: 'harmonyx_layout' });
      store.putSync(preferenceKey, value);
      store.flushSync();
      AppStorage.setOrCreate(storageKey, value);
      return true;
    } catch (error) { return false; }
  }

  loadRailMaterialLevel(context: common.Context): number {
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: 'harmonyx_layout' });
      return this.sidebarMaterialLevel(store, this.sidebarMaterialType(store));
    } catch (error) {
      return DEFAULT_DESKTOP_RAIL_MATERIAL_LEVEL;
    }
  }

  private validRailMaterialLevel(level: number): boolean {
    return Number.isInteger(level) && level >= -1 && level <= 4;
  }

  saveRailMaterialLevel(context: common.Context, level: number): boolean {
    if (!this.validRailMaterialLevel(level)) { return false; }
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: 'harmonyx_layout' });
      const type: number = this.sidebarMaterialType(store);
      const activeLevel: number = type === SIDEBAR_MATERIAL_SYSTEM ? (level >= 0 ? 2 : -1) : level;
      this.putSidebarMaterialLevel(store, type, activeLevel);
      store.putSync('rail_material_level', activeLevel);
      store.flushSync();
      AppStorage.setOrCreate<number>(STORAGE_KEY_DESKTOP_RAIL_MATERIAL_LEVEL, activeLevel);
      return true;
    } catch (error) {
      return false;
    }
  }

  loadRailAutoHide(context: common.Context): boolean {
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: 'harmonyx_layout' });
      return store.getSync('rail_auto_hide', true) as boolean;
    } catch (error) {
      return true;
    }
  }

  saveRailAutoHide(context: common.Context, enabled: boolean): boolean {
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: 'harmonyx_layout' });
      store.putSync('rail_auto_hide', enabled);
      store.flushSync();
      AppStorage.setOrCreate<boolean>(STORAGE_KEY_DESKTOP_RAIL_AUTO_HIDE, enabled);
      return true;
    } catch (error) {
      return false;
    }
  }

  loadAsideEnabled(context: common.Context): boolean {
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: 'harmonyx_layout' });
      return store.getSync('aside', true) as boolean;
    } catch (error) {
      return true;
    }
  }

  saveAsideEnabled(context: common.Context, enabled: boolean): boolean {
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: 'harmonyx_layout' });
      store.putSync('aside', enabled);
      store.flushSync();
      AppStorage.setOrCreate<boolean>(STORAGE_KEY_DESKTOP_ASIDE, enabled);
      return true;
    } catch (error) {
      return false;
    }
  }

  load(context: common.Context): boolean {
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: 'harmonyx_layout' });
      return store.getSync('desktop', false) as boolean;
    } catch (error) {
      return false;
    }
  }

  save(context: common.Context, enabled: boolean): boolean {
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: 'harmonyx_layout' });
      store.putSync('desktop', enabled);
      store.flushSync();
      AppStorage.setOrCreate<boolean>(STORAGE_KEY_DESKTOP_LAYOUT, enabled);
      return true;
    } catch (error) {
      return false;
    }
  }
}

export const layoutSettingsStore: LayoutSettingsStore = new LayoutSettingsStore();
