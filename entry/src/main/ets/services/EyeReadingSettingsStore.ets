import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

export const STORAGE_KEY_EYE_READING_ENABLED: string = 'harmonyx.eye_reading_enabled';
export const STORAGE_KEY_EYE_READING_DWELL: string = 'harmonyx.eye_reading_dwell';
export const STORAGE_KEY_EYE_READING_THRESHOLD: string = 'harmonyx.eye_reading_threshold';

export class EyeReadingSettings {
  enabled: boolean = false;
  dwell: number = 900;
  threshold: number = 0.22;
}

class EyeReadingSettingsStore {
  private store(context: common.Context): preferences.Preferences {
    return preferences.getPreferencesSync(context, { name: 'harmonyx_eye_reading' });
  }
  load(context: common.Context): EyeReadingSettings {
    const settings: EyeReadingSettings = new EyeReadingSettings();
    try {
      const store: preferences.Preferences = this.store(context);
      settings.enabled = store.getSync('enabled', false) === true;
      const dwell: number = store.getSync('dwell', 900) as number;
      const threshold: number = store.getSync('threshold', 0.22) as number;
      settings.dwell = Number.isFinite(dwell) ? Math.max(600, Math.min(2000, dwell)) : 900;
      settings.threshold = Number.isFinite(threshold) ? Math.max(0.12, Math.min(0.5, threshold)) : 0.22;
    } catch (_error) { }
    this.publish(settings);
    return settings;
  }
  save(context: common.Context, settings: EyeReadingSettings): boolean {
    try {
      const store: preferences.Preferences = this.store(context);
      store.putSync('enabled', settings.enabled); store.putSync('dwell', settings.dwell);
      store.putSync('threshold', settings.threshold); store.flushSync(); this.publish(settings); return true;
    } catch (_error) { return false; }
  }
  private publish(settings: EyeReadingSettings): void {
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_EYE_READING_ENABLED, settings.enabled);
    AppStorage.setOrCreate<number>(STORAGE_KEY_EYE_READING_DWELL, settings.dwell);
    AppStorage.setOrCreate<number>(STORAGE_KEY_EYE_READING_THRESHOLD, settings.threshold);
  }
}

export const eyeReadingSettingsStore: EyeReadingSettingsStore = new EyeReadingSettingsStore();
