import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { mediaSettingsStore, IMAGE_QUALITY_DATA_SAVER, IMAGE_QUALITY_HIGH, IMAGE_QUALITY_ORIGINAL,
  VIDEO_QUALITY_LD, VIDEO_QUALITY_HIGH } from './MediaSettingsStore';
import { motionSettingsStore, MotionSettings } from './MotionSettingsStore';
import { pageBackgroundStore, PageBackgroundState } from './PageBackgroundStore';

export const STORAGE_KEY_SCENE_MODE: string = 'harmonyx.scene_mode';
export const SCENE_READING: string = 'reading';
export const SCENE_SAVER: string = 'saver';
export const SCENE_MEDIA: string = 'media';

export class SceneSnapshot {
  autoplay: boolean = true;
  imageQuality: number = IMAGE_QUALITY_ORIGINAL;
  videoQuality: number = 0;
  reduceMotion: boolean = false;
  symbolEffects: boolean = true;
  backgroundEnabled: boolean = true;
}

export class SceneModeStore {
  private store(context: common.Context): preferences.Preferences {
    return preferences.getPreferencesSync(context, { name: 'harmonyx_scene_mode' });
  }
  current(context: common.Context): string {
    try { return this.store(context).getSync('mode', '') as string; } catch (_error) { return ''; }
  }
  initialize(context: common.Context): void {
    AppStorage.setOrCreate<string>(STORAGE_KEY_SCENE_MODE, this.current(context));
  }
  private snapshot(context: common.Context): SceneSnapshot {
    const result: SceneSnapshot = new SceneSnapshot();
    result.autoplay = mediaSettingsStore.loadVideoAutoplay(context);
    result.imageQuality = mediaSettingsStore.loadImageQuality(context);
    result.videoQuality = mediaSettingsStore.loadVideoQuality(context);
    const motion: MotionSettings = motionSettingsStore.load(context);
    result.reduceMotion = motion.reduceMotion; result.symbolEffects = motion.symbolEffects;
    result.backgroundEnabled = pageBackgroundStore.load(context).enabled;
    return result;
  }
  apply(context: common.Context, mode: string): boolean {
    if (mode !== '' && mode !== SCENE_READING && mode !== SCENE_SAVER && mode !== SCENE_MEDIA) { return false; }
    try {
      const store: preferences.Preferences = this.store(context);
      let backup: string = store.getSync('backup', '') as string;
      if (mode === '' && backup.length === 0) { return true; }
      if (backup.length === 0) {
        backup = JSON.stringify(this.snapshot(context));
        store.putSync('backup', backup);
        // Save recovery data before changing any of the participating stores.
        store.flushSync();
      }
      const original: SceneSnapshot = JSON.parse(backup) as SceneSnapshot;
      const next: SceneSnapshot = JSON.parse(backup) as SceneSnapshot;
      if (mode === SCENE_READING) {
        next.autoplay = false; next.imageQuality = IMAGE_QUALITY_HIGH; next.videoQuality = VIDEO_QUALITY_LD;
        next.reduceMotion = true; next.symbolEffects = false; next.backgroundEnabled = false;
      } else if (mode === SCENE_SAVER) {
        next.autoplay = false; next.imageQuality = IMAGE_QUALITY_DATA_SAVER; next.videoQuality = VIDEO_QUALITY_LD;
        next.reduceMotion = true; next.symbolEffects = false; next.backgroundEnabled = false;
      } else if (mode === SCENE_MEDIA) {
        next.autoplay = true; next.imageQuality = IMAGE_QUALITY_ORIGINAL; next.videoQuality = VIDEO_QUALITY_HIGH;
        next.reduceMotion = false; next.symbolEffects = true; next.backgroundEnabled = original.backgroundEnabled;
      }
      // A partial write retains the original snapshot, allowing retry/restore.
      store.putSync('mode', mode.length > 0 ? mode : 'restore'); store.flushSync();
      AppStorage.setOrCreate<string>(STORAGE_KEY_SCENE_MODE, mode.length > 0 ? mode : 'restore');
      const autoplay: boolean = mediaSettingsStore.saveVideoAutoplay(context, next.autoplay);
      const image: boolean = mediaSettingsStore.saveImageQuality(context, next.imageQuality);
      const video: boolean = mediaSettingsStore.saveVideoQuality(context, next.videoQuality);
      const reduced: boolean = motionSettingsStore.saveBoolean(context, 'reduce_motion', next.reduceMotion);
      const symbols: boolean = motionSettingsStore.saveBoolean(context, 'symbol_effects', next.symbolEffects);
      const background: PageBackgroundState = pageBackgroundStore.load(context);
      background.enabled = next.backgroundEnabled;
      pageBackgroundStore.save(context, background);
      if (!autoplay || !image || !video || !reduced || !symbols) { return false; }
      if (mode === '') { store.putSync('backup', ''); store.putSync('mode', ''); store.flushSync(); }
      AppStorage.setOrCreate<string>(STORAGE_KEY_SCENE_MODE, mode);
      return true;
    } catch (_error) { return false; }
  }
}

export const sceneModeStore: SceneModeStore = new SceneModeStore();
