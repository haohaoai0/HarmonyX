// Persistent, application-wide display preferences.  Color mode is applied
// through ApplicationContext so resource-qualified dark colors update too.
import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

export const DISPLAY_MODE_SYSTEM: string = 'system';
export const DISPLAY_MODE_LIGHT: string = 'light';
export const DISPLAY_MODE_DARK: string = 'dark';
// OpenHarmony UI design-spec examples use this system blue for selected UI.
export const DEFAULT_ACCENT_COLOR: string = '#007DFF';
const ICON_BLUE: string = '#0B77FD';
export const DEFAULT_FONT_SCALE: number = 1;

export class AppearanceSettings {
  mode: string = DISPLAY_MODE_SYSTEM;
  accentColor: string = DEFAULT_ACCENT_COLOR;
  fontScale: number = DEFAULT_FONT_SCALE;

  constructor(mode: string, accentColor: string, fontScale: number) {
    this.mode = mode;
    this.accentColor = accentColor;
    this.fontScale = fontScale;
  }
}

export class AppearanceStore {
  private static readonly STORE_NAME: string = 'harmonyx_appearance';
  private static readonly MODE_KEY: string = 'display_mode';
  private static readonly ACCENT_KEY: string = 'accent_color';
  private static readonly FONT_KEY: string = 'font_scale';

  load(context: common.Context): AppearanceSettings {
    try {
      const options: preferences.Options = { name: AppearanceStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      const savedMode: string = store.getSync(AppearanceStore.MODE_KEY, DISPLAY_MODE_SYSTEM) as string;
      const savedAccent: string = store.getSync(AppearanceStore.ACCENT_KEY, DEFAULT_ACCENT_COLOR) as string;
      const savedScale: number = store.getSync(AppearanceStore.FONT_KEY, DEFAULT_FONT_SCALE) as number;
      const mode: string = this.isValidMode(savedMode) ? savedMode : DISPLAY_MODE_SYSTEM;
      // Earlier builds used X blue and icon blue as implicit defaults. Migrate
      // only those defaults while preserving any explicit color selection.
    const accentColor: string = savedAccent === ICON_BLUE ? DEFAULT_ACCENT_COLOR :
      (savedAccent.length === 7 ? savedAccent : DEFAULT_ACCENT_COLOR);
      const fontScale: number = savedScale >= 0.85 && savedScale <= 1.35 ? savedScale : DEFAULT_FONT_SCALE;
      return new AppearanceSettings(mode, accentColor, fontScale);
    } catch (error) {
      return new AppearanceSettings(DISPLAY_MODE_SYSTEM, DEFAULT_ACCENT_COLOR, DEFAULT_FONT_SCALE);
    }
  }

  save(context: common.Context, settings: AppearanceSettings): void {
    try {
      const options: preferences.Options = { name: AppearanceStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      store.putSync(AppearanceStore.MODE_KEY, settings.mode);
      store.putSync(AppearanceStore.ACCENT_KEY, settings.accentColor);
      store.putSync(AppearanceStore.FONT_KEY, settings.fontScale);
      store.flushSync();
    } catch (error) {
      // Preferences are an enhancement: a failed write must not interrupt UI.
    }
  }

  colorMode(mode: string): ConfigurationConstant.ColorMode {
    if (mode === DISPLAY_MODE_LIGHT) {
      return ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
    }
    if (mode === DISPLAY_MODE_DARK) {
      return ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    }
    return ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
  }

  private isValidMode(mode: string): boolean {
    return mode === DISPLAY_MODE_SYSTEM || mode === DISPLAY_MODE_LIGHT || mode === DISPLAY_MODE_DARK;
  }
}
