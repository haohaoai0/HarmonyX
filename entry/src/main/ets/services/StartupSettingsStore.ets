import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

export const STORAGE_KEY_STARTUP_MODE: string = 'harmonyx.startup_mode';
export const STORAGE_KEY_STARTUP_SPEED: string = 'harmonyx.startup_speed';
export const STARTUP_MODE_NONE: string = 'none';
export const STARTUP_MODE_ICON: string = 'icon';
export const STARTUP_MODE_IOS: string = 'ios';
export const STARTUP_MODE_VIDEO: string = 'video';
export const STARTUP_PLAYBACK_SPEEDS: number[] = [0.5, 0.75, 1, 1.25, 1.5, 1.75, 2];

export function normaliseStartupSpeed(value: number): number {
  return STARTUP_PLAYBACK_SPEEDS.indexOf(value) >= 0 ? value : 1;
}

export function normaliseStartupMode(value: string): string {
  return value === STARTUP_MODE_NONE || value === STARTUP_MODE_ICON || value === STARTUP_MODE_IOS ?
    value : STARTUP_MODE_VIDEO;
}

export class StartupSettingsStore {
  load(context: common.Context): string {
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: 'harmonyx_startup' });
      return normaliseStartupMode(store.getSync('mode', STARTUP_MODE_VIDEO) as string);
    } catch (_error) { return STARTUP_MODE_VIDEO; }
  }

  initialize(context: common.Context): void {
    AppStorage.setOrCreate<string>(STORAGE_KEY_STARTUP_MODE, this.load(context));
    AppStorage.setOrCreate<number>(STORAGE_KEY_STARTUP_SPEED, this.loadSpeed(context));
  }

  loadSpeed(context: common.Context): number {
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: 'harmonyx_startup' });
      return normaliseStartupSpeed(store.getSync('speed', 1) as number);
    } catch (_error) { return 1; }
  }

  saveSpeed(context: common.Context, value: number): boolean {
    if (STARTUP_PLAYBACK_SPEEDS.indexOf(value) < 0) { return false; }
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: 'harmonyx_startup' });
      store.putSync('speed', value);
      store.flushSync();
      AppStorage.setOrCreate<number>(STORAGE_KEY_STARTUP_SPEED, value);
      return true;
    } catch (_error) { return false; }
  }

  save(context: common.Context, value: string): boolean {
    if (value !== STARTUP_MODE_NONE && value !== STARTUP_MODE_ICON &&
      value !== STARTUP_MODE_IOS && value !== STARTUP_MODE_VIDEO) { return false; }
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: 'harmonyx_startup' });
      store.putSync('mode', value);
      store.flushSync();
      AppStorage.setOrCreate<string>(STORAGE_KEY_STARTUP_MODE, value);
      return true;
    } catch (_error) { return false; }
  }
}

export const startupSettingsStore: StartupSettingsStore = new StartupSettingsStore();
