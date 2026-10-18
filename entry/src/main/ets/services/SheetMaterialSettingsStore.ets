import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

export const STORAGE_KEY_SHEET_MATERIAL_ENABLED: string = 'harmonyx.sheet_material_enabled';
export const STORAGE_KEY_SHEET_MATERIAL_LEVEL: string = 'harmonyx.sheet_material_level';
export const DEFAULT_SHEET_MATERIAL_ENABLED: boolean = true;
export const DEFAULT_SHEET_MATERIAL_LEVEL: number = 2;

export function validSheetMaterialLevel(level: number): number {
  return Number.isInteger(level) && level >= 0 && level <= 4 ? level : DEFAULT_SHEET_MATERIAL_LEVEL;
}

export class SheetMaterialSettings {
  enabled: boolean = DEFAULT_SHEET_MATERIAL_ENABLED;
  level: number = DEFAULT_SHEET_MATERIAL_LEVEL;

  constructor(enabled: boolean = DEFAULT_SHEET_MATERIAL_ENABLED, level: number = DEFAULT_SHEET_MATERIAL_LEVEL) {
    this.enabled = enabled;
    this.level = validSheetMaterialLevel(level);
  }
}

export class SheetMaterialSettingsStore {
  private static readonly STORE_NAME: string = 'harmonyx_sheet_material';

  load(context: common.Context): SheetMaterialSettings {
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context,
        { name: SheetMaterialSettingsStore.STORE_NAME });
      const enabled: boolean = store.getSync('enabled', DEFAULT_SHEET_MATERIAL_ENABLED) as boolean;
      const level: number = store.getSync('level', DEFAULT_SHEET_MATERIAL_LEVEL) as number;
      return new SheetMaterialSettings(enabled === true, level);
    } catch (error) {
      return new SheetMaterialSettings();
    }
  }

  initialize(context: common.Context): void {
    const settings: SheetMaterialSettings = this.load(context);
    this.publish(settings);
  }

  save(context: common.Context, enabled: boolean, level: number): boolean {
    const settings: SheetMaterialSettings = new SheetMaterialSettings(enabled, level);
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context,
        { name: SheetMaterialSettingsStore.STORE_NAME });
      store.putSync('enabled', settings.enabled);
      store.putSync('level', settings.level);
      store.flushSync();
      this.publish(settings);
      return true;
    } catch (error) {
      return false;
    }
  }

  private publish(settings: SheetMaterialSettings): void {
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_SHEET_MATERIAL_ENABLED, settings.enabled);
    AppStorage.setOrCreate<number>(STORAGE_KEY_SHEET_MATERIAL_LEVEL, settings.level);
  }
}

export const sheetMaterialSettingsStore: SheetMaterialSettingsStore = new SheetMaterialSettingsStore();
