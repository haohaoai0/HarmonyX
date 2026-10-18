import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

export const STORAGE_KEY_COMPONENT_HDR_RATIO: string = 'harmonyx.component_hdr_ratio';
export const STORAGE_KEY_COMPONENT_HDR_ENABLED: string = 'harmonyx.component_hdr_enabled';
export const DEFAULT_COMPONENT_HDR_RATIO: number = 1.25;
export const DEFAULT_COMPONENT_HDR_ENABLED: boolean = false;

export function isValidComponentHdrRatio(value: number): boolean {
  return Number.isFinite(value) && value >= 1;
}

export function parseComponentHdrRatio(text: string): number | null {
  const decimal: string = text.trim().replace(',', '.');
  if (!/^[0-9]+(?:\.[0-9]*)?$/.test(decimal)) { return null; }
  const value: number = Number(decimal);
  return isValidComponentHdrRatio(value) ? value : null;
}

export class ComponentHdrSettingsStore {
  private static readonly STORE_NAME: string = 'harmonyx_component_hdr';
  private static readonly RATIO_KEY: string = 'ratio';
  private static readonly ENABLED_KEY: string = 'enabled';

  load(context: common.Context): number {
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context,
        { name: ComponentHdrSettingsStore.STORE_NAME });
      const ratio: number = store.getSync(ComponentHdrSettingsStore.RATIO_KEY, DEFAULT_COMPONENT_HDR_RATIO) as number;
      return isValidComponentHdrRatio(ratio) ? ratio : DEFAULT_COMPONENT_HDR_RATIO;
    } catch (error) {
      return DEFAULT_COMPONENT_HDR_RATIO;
    }
  }

  loadEnabled(context: common.Context): boolean {
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context,
        { name: ComponentHdrSettingsStore.STORE_NAME });
      const enabled: boolean = store.getSync(ComponentHdrSettingsStore.ENABLED_KEY, DEFAULT_COMPONENT_HDR_ENABLED) as boolean;
      return enabled === true;
    } catch (error) {
      return DEFAULT_COMPONENT_HDR_ENABLED;
    }
  }

  initialize(context: common.Context): void {
    AppStorage.setOrCreate<number>(STORAGE_KEY_COMPONENT_HDR_RATIO, this.load(context));
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_COMPONENT_HDR_ENABLED, this.loadEnabled(context));
  }

  saveEnabled(context: common.Context, enabled: boolean): boolean {
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context,
        { name: ComponentHdrSettingsStore.STORE_NAME });
      store.putSync(ComponentHdrSettingsStore.ENABLED_KEY, enabled);
      store.flushSync();
      AppStorage.setOrCreate<boolean>(STORAGE_KEY_COMPONENT_HDR_ENABLED, enabled);
      return true;
    } catch (error) {
      return false;
    }
  }

  save(context: common.Context, ratio: number): boolean {
    if (!isValidComponentHdrRatio(ratio)) { return false; }
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context,
        { name: ComponentHdrSettingsStore.STORE_NAME });
      store.putSync(ComponentHdrSettingsStore.RATIO_KEY, ratio);
      store.flushSync();
      AppStorage.setOrCreate<number>(STORAGE_KEY_COMPONENT_HDR_RATIO, ratio);
      return true;
    } catch (error) {
      return false;
    }
  }
}

export const componentHdrSettingsStore: ComponentHdrSettingsStore = new ComponentHdrSettingsStore();
