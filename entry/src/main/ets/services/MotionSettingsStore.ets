import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

// Reuse the key already observed by media viewers and the constellation.
export const STORAGE_KEY_REDUCE_MOTION: string = 'reduceMotionEnabled';
export const STORAGE_KEY_MOTION_DURATION: string = 'harmonyx.motion_duration';
export const STORAGE_KEY_MOTION_AMPLITUDE: string = 'harmonyx.motion_amplitude';
export const STORAGE_KEY_MOTION_DAMPING: string = 'harmonyx.motion_damping';
export const STORAGE_KEY_SYMBOL_EFFECTS: string = 'harmonyx.symbol_effects';
export const STORAGE_KEY_HAPTICS_ENABLED: string = 'harmonyx.haptics_enabled';
export const STORAGE_KEY_HAPTICS_INTENSITY: string = 'harmonyx.haptics_intensity';
export const DEFAULT_MOTION_DURATION: number = 300;
export const DEFAULT_MOTION_AMPLITUDE: number = 1;
export const DEFAULT_MOTION_DAMPING: number = 0.82;

export function boundedMotionValue(value: number, fallback: number, min: number, max: number): number {
  return Number.isFinite(value) ? Math.max(min, Math.min(max, value)) : fallback;
}

export class MotionSettings {
  reduceMotion: boolean = false;
  duration: number = DEFAULT_MOTION_DURATION;
  amplitude: number = DEFAULT_MOTION_AMPLITUDE;
  damping: number = DEFAULT_MOTION_DAMPING;
  symbolEffects: boolean = true;
  hapticsEnabled: boolean = true;
  hapticsIntensity: number = 60;
}

export const MOTION_PRESET_QUICK: string = 'quick';
export const MOTION_PRESET_STANDARD: string = 'standard';
export const MOTION_PRESET_SPRING: string = 'spring';
export const MOTION_PRESET_REDUCED: string = 'reduced';
export const MOTION_PRESET_CUSTOM: string = 'custom';

export function selectedMotionPreset(duration: number, amplitude: number, damping: number,
  reduced: boolean, symbols: boolean): string {
  if (reduced) { return MOTION_PRESET_REDUCED; }
  if (!symbols) { return MOTION_PRESET_CUSTOM; }
  if (duration === 175 && Math.abs(amplitude - 0.6) < 0.001 && Math.abs(damping - 1) < 0.001) {
    return MOTION_PRESET_QUICK;
  }
  if (duration === DEFAULT_MOTION_DURATION && Math.abs(amplitude - DEFAULT_MOTION_AMPLITUDE) < 0.001 &&
    Math.abs(damping - DEFAULT_MOTION_DAMPING) < 0.001) { return MOTION_PRESET_STANDARD; }
  if (duration === 450 && Math.abs(amplitude - 1.2) < 0.001 && Math.abs(damping - 0.6) < 0.001) {
    return MOTION_PRESET_SPRING;
  }
  return MOTION_PRESET_CUSTOM;
}

export class MotionSettingsStore {
  private store(context: common.Context): preferences.Preferences {
    return preferences.getPreferencesSync(context, { name: 'harmonyx_motion' });
  }

  load(context: common.Context): MotionSettings {
    const result: MotionSettings = new MotionSettings();
    try {
      const store: preferences.Preferences = this.store(context);
      result.reduceMotion = store.getSync('reduce_motion', false) === true;
      result.duration = boundedMotionValue(store.getSync('duration', DEFAULT_MOTION_DURATION) as number,
        DEFAULT_MOTION_DURATION, 100, 700);
      result.amplitude = boundedMotionValue(store.getSync('amplitude', DEFAULT_MOTION_AMPLITUDE) as number,
        DEFAULT_MOTION_AMPLITUDE, 0, 1.5);
      result.damping = boundedMotionValue(store.getSync('damping', DEFAULT_MOTION_DAMPING) as number,
        DEFAULT_MOTION_DAMPING, 0.5, 1);
      result.symbolEffects = store.getSync('symbol_effects', true) === true;
      result.hapticsEnabled = store.getSync('haptics_enabled', true) === true;
      result.hapticsIntensity = Math.round(boundedMotionValue(store.getSync('haptics_intensity', 60) as number, 60, 1, 100));
    } catch (_error) { }
    return result;
  }

  publish(value: MotionSettings): void {
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_REDUCE_MOTION, value.reduceMotion);
    AppStorage.setOrCreate<number>(STORAGE_KEY_MOTION_DURATION, value.duration);
    AppStorage.setOrCreate<number>(STORAGE_KEY_MOTION_AMPLITUDE, value.amplitude);
    AppStorage.setOrCreate<number>(STORAGE_KEY_MOTION_DAMPING, value.damping);
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_SYMBOL_EFFECTS, value.symbolEffects);
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_HAPTICS_ENABLED, value.hapticsEnabled);
    AppStorage.setOrCreate<number>(STORAGE_KEY_HAPTICS_INTENSITY, value.hapticsIntensity);
  }

  saveNumber(context: common.Context, key: string, value: number): boolean {
    let normal: number = value;
    if (key === 'duration') { normal = Math.round(boundedMotionValue(value, DEFAULT_MOTION_DURATION, 100, 700)); }
    else if (key === 'amplitude') { normal = boundedMotionValue(value, DEFAULT_MOTION_AMPLITUDE, 0, 1.5); }
    else if (key === 'damping') { normal = boundedMotionValue(value, DEFAULT_MOTION_DAMPING, 0.5, 1); }
    else if (key === 'haptics_intensity') { normal = Math.round(boundedMotionValue(value, 60, 1, 100)); }
    else { return false; }
    try {
      const store: preferences.Preferences = this.store(context);
      store.putSync(key, normal);
      store.flushSync();
      this.publish(this.load(context));
      return true;
    } catch (_error) { return false; }
  }

  saveBoolean(context: common.Context, key: string, value: boolean): boolean {
    if (key !== 'reduce_motion' && key !== 'symbol_effects' && key !== 'haptics_enabled') { return false; }
    try {
      const store: preferences.Preferences = this.store(context);
      store.putSync(key, value);
      store.flushSync();
      this.publish(this.load(context));
      return true;
    } catch (_error) { return false; }
  }

  applyPreset(context: common.Context, preset: string): boolean {
    if (preset !== MOTION_PRESET_QUICK && preset !== MOTION_PRESET_STANDARD &&
      preset !== MOTION_PRESET_SPRING && preset !== MOTION_PRESET_REDUCED) { return false; }
    try {
      const store: preferences.Preferences = this.store(context);
      store.putSync('reduce_motion', preset === MOTION_PRESET_REDUCED);
      // Reduced motion is reversible without discarding the current tuning.
      if (preset !== MOTION_PRESET_REDUCED) {
        store.putSync('duration', preset === MOTION_PRESET_QUICK ? 175 :
          (preset === MOTION_PRESET_SPRING ? 450 : DEFAULT_MOTION_DURATION));
        store.putSync('amplitude', preset === MOTION_PRESET_QUICK ? 0.6 :
          (preset === MOTION_PRESET_SPRING ? 1.2 : DEFAULT_MOTION_AMPLITUDE));
        store.putSync('damping', preset === MOTION_PRESET_QUICK ? 1 :
          (preset === MOTION_PRESET_SPRING ? 0.6 : DEFAULT_MOTION_DAMPING));
        store.putSync('symbol_effects', true);
      }
      store.flushSync();
      this.publish(this.load(context));
      return true;
    } catch (_error) { return false; }
  }
}

export const motionSettingsStore: MotionSettingsStore = new MotionSettingsStore();
