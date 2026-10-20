// Playback preferences are kept out of the render path. Components observe
// the AppStorage mirror while this store owns persistence across launches.
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

export const STORAGE_KEY_VIDEO_AUTOPLAY: string = 'harmonyx.video_autoplay';
// Possible-sensitive media stays hidden by default. This is a local display
// preference, kept separately from X's account-level privacy setting.
export const STORAGE_KEY_SHOW_SENSITIVE_MEDIA: string = 'harmonyx.show_sensitive_media';
// Inline previews and opened videos remember separate explicit mute choices.
// Temporary silence for preloading or playback ownership never changes them.
export const STORAGE_KEY_HOME_VIDEO_MUTED: string = 'harmonyx.home_video_muted';
export const STORAGE_KEY_VIEWER_VIDEO_MUTED: string = 'harmonyx.viewer_video_muted';
export const STORAGE_KEY_IMAGE_QUALITY: string = 'harmonyx.image_quality';
export const STORAGE_KEY_MEDIA_VIEWER_BLACK_BACKGROUND: string = 'harmonyx.media_viewer_black_background';
export const STORAGE_KEY_MEDIA_COMMENT_BACKGROUND: string = 'harmonyx.media_comment_background';
export const STORAGE_KEY_VIDEO_COMMENT_PROGRESS_RING: string = 'harmonyx.video_comment_progress_ring';
export const STORAGE_KEY_VIDEO_QUALITY: string = 'harmonyx.video_quality';
export const STORAGE_KEY_VIDEO_AUTO_BITRATE_CAP: string = 'harmonyx.video_auto_bitrate_cap';
// Detail pages hand a running video over to the system picture-in-picture
// window once the reader scrolls past it. Readers who would rather have the
// video stop turn this off.
export const STORAGE_KEY_VIDEO_AUTO_PIP: string = 'harmonyx.video_auto_pip';
export const STORAGE_KEY_VIDEO_IMMERSIVE_FILL: string = 'harmonyx.video_immersive_fill';
export const STORAGE_KEY_VIDEO_FEED_CONTROLS_ALWAYS_VISIBLE: string = 'harmonyx.video_feed_controls_always_visible';
export const STORAGE_KEY_VIDEO_CAPTIONS_ENABLED: string = 'harmonyx.video_captions_enabled';
export const STORAGE_KEY_VIDEO_AUTO_ADVANCE: string = 'harmonyx.video_auto_advance';
export const STORAGE_KEY_VIDEO_FEED_TAP_PAUSE: string = 'harmonyx.video_feed_tap_pause';
// Pressing and holding a playing video temporarily raises its playback rate and
// shows a glass capsule, in the style of the short-video feeds. Turning this off
// keeps the original hold-to-seek gesture (left half rewinds, right half
// forwards).
export const STORAGE_KEY_VIDEO_HOLD_SPEED: string = 'harmonyx.video_hold_speed';
export const STORAGE_KEY_VIDEO_HDR_ENHANCEMENT: string = 'harmonyx.video_hdr_enhancement';
export const DEFAULT_VIDEO_HDR_ENHANCEMENT: boolean = true;
export const STORAGE_KEY_VIDEO_DOUBLE_TAP_SEEK: string = 'harmonyx.video_double_tap_seek';
export const STORAGE_KEY_VIDEO_DOUBLE_TAP_SEEK_SECONDS: string = 'harmonyx.video_double_tap_seek_seconds';
export const DEFAULT_VIDEO_DOUBLE_TAP_SEEK_ENABLED: boolean = true;
export const DEFAULT_VIDEO_DOUBLE_TAP_SEEK_SECONDS: number = 10;
export const MIN_VIDEO_DOUBLE_TAP_SEEK_SECONDS: number = 1;
export const MAX_VIDEO_DOUBLE_TAP_SEEK_SECONDS: number = 60;

export function normalizeVideoDoubleTapSeekSeconds(value: number): number {
  if (!Number.isFinite(value)) { return DEFAULT_VIDEO_DOUBLE_TAP_SEEK_SECONDS; }
  return Math.max(MIN_VIDEO_DOUBLE_TAP_SEEK_SECONDS,
    Math.min(MAX_VIDEO_DOUBLE_TAP_SEEK_SECONDS, Math.round(value)));
}

export const STORAGE_KEY_VIDEO_FEED_LAYOUT: string = 'harmonyx.video_feed_layout';
export const STORAGE_KEY_COMPACT_VIDEO_LAYOUT: string = 'harmonyx.compact_video_layout';
export const COMPACT_VIDEO_LAYOUT_RAIL: number = 0;
export const COMPACT_VIDEO_LAYOUT_BOTTOM: number = 1;
export const STORAGE_KEY_VIDEO_CONTROL_STYLE: string = 'harmonyx.video_control_style';
// What a fullscreen video does when the reader leaves the app or locks the
// screen: keep the sound running through the control centre, or hand the
// picture over to the system picture-in-picture window.
export const STORAGE_KEY_VIDEO_BACKGROUND_MODE: string = 'harmonyx.video_background_mode';
// The system AI caption component only accepts the panel background opacity
// when it is created, so the last value the reader picked has to be replayed
// from here every time the caption layer is rebuilt.
export const STORAGE_KEY_CAPTION_OPACITY: string = 'harmonyx.caption_opacity';

export const IMAGE_QUALITY_DATA_SAVER: number = 0;
export const IMAGE_QUALITY_HIGH: number = 1;
export const IMAGE_QUALITY_ORIGINAL: number = 2;
export const VIDEO_QUALITY_DATA_SAVER: number = 0;
export const VIDEO_QUALITY_HIGH: number = 1;
export const VIDEO_QUALITY_SD: number = 2;
export const VIDEO_QUALITY_LD: number = 3;
export const VIDEO_QUALITY_AUTO: number = VIDEO_QUALITY_DATA_SAVER;
export const DEFAULT_VIDEO_AUTO_BITRATE_CAP: number = 1500000;
export const VIDEO_BACKGROUND_AUDIO: number = 0;
export const VIDEO_BACKGROUND_PIP: number = 1;
export const VIDEO_CONTROL_STYLE_ORIGINAL: number = 0;
export const VIDEO_CONTROL_STYLE_SPACED: number = 1;
export const VIDEO_FEED_LAYOUT_CLASSIC: number = 0;
export const VIDEO_FEED_LAYOUT_DOUYIN: number = 1;
export const VIDEO_FEED_LAYOUT_BILIBILI: number = 2;

const DEFAULT_IMAGE_QUALITY: number = IMAGE_QUALITY_ORIGINAL;
const DEFAULT_VIDEO_QUALITY: number = VIDEO_QUALITY_AUTO;
const DEFAULT_VIDEO_BACKGROUND_MODE: number = VIDEO_BACKGROUND_AUDIO;
const DEFAULT_VIDEO_CONTROL_STYLE: number = VIDEO_CONTROL_STYLE_SPACED;
export const DEFAULT_CAPTION_OPACITY: number = 0.7;
// The rate a held video plays at while the reader keeps pressing it.
export const VIDEO_HOLD_SPEED_RATE: number = 2;
// Sliding the held finger up raises the temporary rate, sliding down lowers it.
export const VIDEO_HOLD_SPEED_STEP_RATE: number = 0.5;
export const VIDEO_HOLD_SPEED_MIN_RATE: number = 0.5;
// AVPlayer refuses rates above 4x.
export const VIDEO_HOLD_SPEED_MAX_RATE: number = 4;
export const DEFAULT_VIDEO_HOLD_SPEED_ENABLED: boolean = true;

// "2x", "2.5x" — the capsule label for a temporary playback rate.
export function videoHoldSpeedLabel(rate: number): string {
  const rounded: number = Math.round(rate * 100) / 100;
  return (rounded % 1 === 0 ? rounded.toFixed(0) : rounded.toString()) + 'x';
}

// X image URLs expose their rendition through the `name` query parameter.
// Other hosts are left untouched because their quality contract is unknown.
export function imageUrlForQuality(url: string, quality: number): string {
  if (url.length === 0 || url.indexOf('pbs.twimg.com/media/') < 0) {
    return url;
  }
  let rendition: string = 'large';
  if (quality === IMAGE_QUALITY_DATA_SAVER) {
    rendition = 'small';
  } else if (quality === IMAGE_QUALITY_ORIGINAL) {
    rendition = 'orig';
  }
  const hashAt: number = url.indexOf('#');
  const suffix: string = hashAt >= 0 ? url.substring(hashAt) : '';
  const withoutHash: string = hashAt >= 0 ? url.substring(0, hashAt) : url;
  const queryAt: number = withoutHash.indexOf('?');
  const base: string = queryAt >= 0 ? withoutHash.substring(0, queryAt) : withoutHash;
  const query: string = queryAt >= 0 ? withoutHash.substring(queryAt + 1) : '';
  const fields: string[] = query.length > 0 ? query.split('&') : [];
  const kept: string[] = [];
  for (let i: number = 0; i < fields.length; i++) {
    if (!fields[i].startsWith('name=')) {
      kept.push(fields[i]);
    }
  }
  kept.push('name=' + rendition);
  return base + '?' + kept.join('&') + suffix;
}

export class MediaSettingsStore {
  private static readonly STORE_NAME: string = 'harmonyx_media';
  private static readonly VIDEO_AUTOPLAY_KEY: string = 'video_autoplay';
  private static readonly SHOW_SENSITIVE_MEDIA_KEY: string = 'show_sensitive_media';
  private static readonly HOME_VIDEO_MUTED_KEY: string = 'home_video_muted';
  private static readonly VIEWER_VIDEO_MUTED_KEY: string = 'viewer_video_muted';
  private static readonly IMAGE_QUALITY_KEY: string = 'image_quality';
  private static readonly MEDIA_VIEWER_BLACK_BACKGROUND_KEY: string = 'media_viewer_black_background';
  private static readonly MEDIA_COMMENT_BACKGROUND_KEY: string = 'media_comment_background';
  private static readonly VIDEO_COMMENT_PROGRESS_RING_KEY: string = 'video_comment_progress_ring';
  private static readonly VIDEO_QUALITY_KEY: string = 'video_quality';
  private static readonly VIDEO_AUTO_PIP_KEY: string = 'video_auto_pip';
  private static readonly VIDEO_IMMERSIVE_FILL_KEY: string = 'video_immersive_fill';
  private static readonly VIDEO_FEED_CONTROLS_ALWAYS_VISIBLE_KEY: string = 'video_feed_controls_always_visible';
  private static readonly VIDEO_FEED_TAP_PAUSE_KEY: string = 'video_feed_tap_pause';
  private static readonly VIDEO_HOLD_SPEED_KEY: string = 'video_hold_speed';
  private static readonly VIDEO_DOUBLE_TAP_SEEK_KEY: string = 'video_double_tap_seek';
  private static readonly VIDEO_DOUBLE_TAP_SEEK_SECONDS_KEY: string = 'video_double_tap_seek_seconds';
  private static readonly VIDEO_FEED_LAYOUT_KEY: string = 'video_feed_layout';
  private static readonly COMPACT_VIDEO_LAYOUT_KEY: string = 'compact_video_layout';
  private static readonly VIDEO_CONTROL_STYLE_KEY: string = 'video_control_style';
  private static readonly VIDEO_BACKGROUND_MODE_KEY: string = 'video_background_mode';
  private static readonly CAPTION_OPACITY_KEY: string = 'caption_opacity';

  loadMediaViewerBlackBackground(context: common.Context): boolean {
    try {
      const options: preferences.Options = { name: MediaSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      return store.getSync(MediaSettingsStore.MEDIA_VIEWER_BLACK_BACKGROUND_KEY, false) as boolean;
    } catch (error) {
      return false;
    }
  }

  saveMediaViewerBlackBackground(context: common.Context, enabled: boolean): boolean {
    try {
      const options: preferences.Options = { name: MediaSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      store.putSync(MediaSettingsStore.MEDIA_VIEWER_BLACK_BACKGROUND_KEY, enabled);
      store.flushSync();
      AppStorage.setOrCreate<boolean>(STORAGE_KEY_MEDIA_VIEWER_BLACK_BACKGROUND, enabled);
      return true;
    } catch (error) {
      return false;
    }
  }

  loadVideoCommentProgressRing(context: common.Context): boolean {
    try {
      const options: preferences.Options = { name: MediaSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      return store.getSync(MediaSettingsStore.VIDEO_COMMENT_PROGRESS_RING_KEY, true) as boolean;
    } catch (error) {
      return true;
    }
  }

  saveVideoCommentProgressRing(context: common.Context, enabled: boolean): boolean {
    try {
      const options: preferences.Options = { name: MediaSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      store.putSync(MediaSettingsStore.VIDEO_COMMENT_PROGRESS_RING_KEY, enabled);
      store.flushSync();
      AppStorage.setOrCreate<boolean>(STORAGE_KEY_VIDEO_COMMENT_PROGRESS_RING, enabled);
      return true;
    } catch (error) {
      return false;
    }
  }

  loadMediaCommentBackground(context: common.Context): boolean {
    try {
      const options: preferences.Options = { name: MediaSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      return store.getSync(MediaSettingsStore.MEDIA_COMMENT_BACKGROUND_KEY, true) as boolean;
    } catch (error) {
      return true;
    }
  }

  saveMediaCommentBackground(context: common.Context, enabled: boolean): boolean {
    try {
      const options: preferences.Options = { name: MediaSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      store.putSync(MediaSettingsStore.MEDIA_COMMENT_BACKGROUND_KEY, enabled);
      store.flushSync();
      AppStorage.setOrCreate<boolean>(STORAGE_KEY_MEDIA_COMMENT_BACKGROUND, enabled);
      return true;
    } catch (error) {
      return false;
    }
  }

  loadVideoAutoplay(context: common.Context): boolean {
    try {
      const options: preferences.Options = { name: MediaSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      return store.getSync(MediaSettingsStore.VIDEO_AUTOPLAY_KEY, true) as boolean;
    } catch (error) {
      return true;
    }
  }

  saveVideoAutoplay(context: common.Context, enabled: boolean): boolean {
    try {
      const options: preferences.Options = { name: MediaSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      store.putSync(MediaSettingsStore.VIDEO_AUTOPLAY_KEY, enabled);
      store.flushSync();
      this.publishVideoAutoplay(enabled);
      return true;
    } catch (error) {
      return false;
    }
  }

  publishVideoAutoplay(enabled: boolean): void {
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_VIDEO_AUTOPLAY, enabled);
  }

  loadShowSensitiveMedia(context: common.Context): boolean {
    try {
      const options: preferences.Options = { name: MediaSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      return store.getSync(MediaSettingsStore.SHOW_SENSITIVE_MEDIA_KEY, false) as boolean;
    } catch (error) {
      return false;
    }
  }

  saveShowSensitiveMedia(context: common.Context, enabled: boolean): boolean {
    try {
      const options: preferences.Options = { name: MediaSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      store.putSync(MediaSettingsStore.SHOW_SENSITIVE_MEDIA_KEY, enabled);
      store.flushSync();
      this.publishShowSensitiveMedia(enabled);
      return true;
    } catch (error) {
      return false;
    }
  }

  publishShowSensitiveMedia(enabled: boolean): void {
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_SHOW_SENSITIVE_MEDIA, enabled);
  }

  loadHomeVideoMuted(context: common.Context): boolean {
    try {
      const options: preferences.Options = { name: MediaSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      return store.getSync(MediaSettingsStore.HOME_VIDEO_MUTED_KEY, true) as boolean;
    } catch (error) {
      return true;
    }
  }

  saveHomeVideoMuted(context: common.Context, enabled: boolean): boolean {
    try {
      const options: preferences.Options = { name: MediaSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      store.putSync(MediaSettingsStore.HOME_VIDEO_MUTED_KEY, enabled);
      store.flushSync();
      this.publishHomeVideoMuted(enabled);
      return true;
    } catch (error) {
      return false;
    }
  }

  publishHomeVideoMuted(enabled: boolean): void {
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_HOME_VIDEO_MUTED, enabled);
  }

  loadViewerVideoMuted(context: common.Context): boolean {
    try {
      const options: preferences.Options = { name: MediaSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      return store.getSync(MediaSettingsStore.VIEWER_VIDEO_MUTED_KEY, true) as boolean;
    } catch (error) {
      return true;
    }
  }

  saveViewerVideoMuted(context: common.Context, enabled: boolean): boolean {
    try {
      const options: preferences.Options = { name: MediaSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      store.putSync(MediaSettingsStore.VIEWER_VIDEO_MUTED_KEY, enabled);
      store.flushSync();
      this.publishViewerVideoMuted(enabled);
      return true;
    } catch (error) {
      return false;
    }
  }

  publishViewerVideoMuted(enabled: boolean): void {
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_VIEWER_VIDEO_MUTED, enabled);
  }

  loadVideoCaptionsEnabled(context: common.Context): boolean {
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: MediaSettingsStore.STORE_NAME });
      return store.getSync('video_captions_enabled', false) as boolean;
    } catch (error) { return false; }
  }

  saveVideoCaptionsEnabled(context: common.Context, enabled: boolean): boolean {
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: MediaSettingsStore.STORE_NAME });
      store.putSync('video_captions_enabled', enabled);
      store.flushSync();
      AppStorage.setOrCreate<boolean>(STORAGE_KEY_VIDEO_CAPTIONS_ENABLED, enabled);
      return true;
    } catch (error) { return false; }
  }

  loadVideoAutoAdvance(context: common.Context): boolean {
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: MediaSettingsStore.STORE_NAME });
      return store.getSync('video_auto_advance', true) as boolean;
    } catch (error) { return true; }
  }

  saveVideoAutoAdvance(context: common.Context, enabled: boolean): boolean {
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: MediaSettingsStore.STORE_NAME });
      store.putSync('video_auto_advance', enabled);
      store.flushSync();
      AppStorage.setOrCreate<boolean>(STORAGE_KEY_VIDEO_AUTO_ADVANCE, enabled);
      return true;
    } catch (error) { return false; }
  }

  loadVideoAutoPip(context: common.Context): boolean {
    try {
      const options: preferences.Options = { name: MediaSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      return store.getSync(MediaSettingsStore.VIDEO_AUTO_PIP_KEY, true) as boolean;
    } catch (error) {
      return true;
    }
  }

  saveVideoAutoPip(context: common.Context, enabled: boolean): boolean {
    try {
      const options: preferences.Options = { name: MediaSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      store.putSync(MediaSettingsStore.VIDEO_AUTO_PIP_KEY, enabled);
      store.flushSync();
      this.publishVideoAutoPip(enabled);
      return true;
    } catch (error) {
      return false;
    }
  }

  publishVideoAutoPip(enabled: boolean): void {
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_VIDEO_AUTO_PIP, enabled);
  }

  loadVideoImmersiveFill(context: common.Context): boolean {
    try {
      const options: preferences.Options = { name: MediaSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      return store.getSync(MediaSettingsStore.VIDEO_IMMERSIVE_FILL_KEY, false) as boolean;
    } catch (error) {
      return false;
    }
  }

  saveVideoImmersiveFill(context: common.Context, enabled: boolean): boolean {
    try {
      const options: preferences.Options = { name: MediaSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      store.putSync(MediaSettingsStore.VIDEO_IMMERSIVE_FILL_KEY, enabled);
      store.flushSync();
      this.publishVideoImmersiveFill(enabled);
      return true;
    } catch (error) {
      return false;
    }
  }

  publishVideoImmersiveFill(enabled: boolean): void {
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_VIDEO_IMMERSIVE_FILL, enabled);
  }

  loadVideoFeedControlsAlwaysVisible(context: common.Context): boolean {
    try {
      const options: preferences.Options = { name: MediaSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      return store.getSync(MediaSettingsStore.VIDEO_FEED_CONTROLS_ALWAYS_VISIBLE_KEY, false) as boolean;
    } catch (error) {
      return false;
    }
  }

  saveVideoFeedControlsAlwaysVisible(context: common.Context, enabled: boolean): boolean {
    try {
      const options: preferences.Options = { name: MediaSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      store.putSync(MediaSettingsStore.VIDEO_FEED_CONTROLS_ALWAYS_VISIBLE_KEY, enabled);
      store.flushSync();
      this.publishVideoFeedControlsAlwaysVisible(enabled);
      return true;
    } catch (error) {
      return false;
    }
  }

  publishVideoFeedControlsAlwaysVisible(enabled: boolean): void {
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_VIDEO_FEED_CONTROLS_ALWAYS_VISIBLE, enabled);
  }

  loadVideoFeedTapPause(context: common.Context): boolean {
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: MediaSettingsStore.STORE_NAME });
      return store.getSync(MediaSettingsStore.VIDEO_FEED_TAP_PAUSE_KEY, false) as boolean;
    } catch (error) { return false; }
  }

  saveVideoFeedTapPause(context: common.Context, enabled: boolean): boolean {
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: MediaSettingsStore.STORE_NAME });
      store.putSync(MediaSettingsStore.VIDEO_FEED_TAP_PAUSE_KEY, enabled);
      store.flushSync();
      AppStorage.setOrCreate<boolean>(STORAGE_KEY_VIDEO_FEED_TAP_PAUSE, enabled);
      return true;
    } catch (error) { return false; }
  }

  loadVideoHdrEnhancement(context: common.Context): boolean {
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: MediaSettingsStore.STORE_NAME });
      return store.getSync('video_hdr_enhancement', DEFAULT_VIDEO_HDR_ENHANCEMENT) as boolean;
    } catch (error) { return DEFAULT_VIDEO_HDR_ENHANCEMENT; }
  }

  saveVideoHdrEnhancement(context: common.Context, enabled: boolean): boolean {
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: MediaSettingsStore.STORE_NAME });
      store.putSync('video_hdr_enhancement', enabled);
      store.flushSync();
      AppStorage.setOrCreate<boolean>(STORAGE_KEY_VIDEO_HDR_ENHANCEMENT, enabled);
      return true;
    } catch (error) { return false; }
  }

  loadVideoDoubleTapSeek(context: common.Context): boolean {
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: MediaSettingsStore.STORE_NAME });
      return store.getSync(MediaSettingsStore.VIDEO_DOUBLE_TAP_SEEK_KEY, DEFAULT_VIDEO_DOUBLE_TAP_SEEK_ENABLED) as boolean;
    } catch (error) { return DEFAULT_VIDEO_DOUBLE_TAP_SEEK_ENABLED; }
  }

  saveVideoDoubleTapSeek(context: common.Context, enabled: boolean): boolean {
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: MediaSettingsStore.STORE_NAME });
      store.putSync(MediaSettingsStore.VIDEO_DOUBLE_TAP_SEEK_KEY, enabled);
      store.flushSync();
      AppStorage.setOrCreate<boolean>(STORAGE_KEY_VIDEO_DOUBLE_TAP_SEEK, enabled);
      return true;
    } catch (error) { return false; }
  }

  loadVideoDoubleTapSeekSeconds(context: common.Context): number {
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: MediaSettingsStore.STORE_NAME });
      return normalizeVideoDoubleTapSeekSeconds(store.getSync(MediaSettingsStore.VIDEO_DOUBLE_TAP_SEEK_SECONDS_KEY,
        DEFAULT_VIDEO_DOUBLE_TAP_SEEK_SECONDS) as number);
    } catch (error) { return DEFAULT_VIDEO_DOUBLE_TAP_SEEK_SECONDS; }
  }

  saveVideoDoubleTapSeekSeconds(context: common.Context, seconds: number): boolean {
    const value: number = normalizeVideoDoubleTapSeekSeconds(seconds);
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: MediaSettingsStore.STORE_NAME });
      store.putSync(MediaSettingsStore.VIDEO_DOUBLE_TAP_SEEK_SECONDS_KEY, value);
      store.flushSync();
      AppStorage.setOrCreate<number>(STORAGE_KEY_VIDEO_DOUBLE_TAP_SEEK_SECONDS, value);
      return true;
    } catch (error) { return false; }
  }

  loadVideoHoldSpeed(context: common.Context): boolean {
    try {
      const options: preferences.Options = { name: MediaSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      return store.getSync(MediaSettingsStore.VIDEO_HOLD_SPEED_KEY, DEFAULT_VIDEO_HOLD_SPEED_ENABLED) as boolean;
    } catch (error) {
      return DEFAULT_VIDEO_HOLD_SPEED_ENABLED;
    }
  }

  saveVideoHoldSpeed(context: common.Context, enabled: boolean): boolean {
    try {
      const options: preferences.Options = { name: MediaSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      store.putSync(MediaSettingsStore.VIDEO_HOLD_SPEED_KEY, enabled);
      store.flushSync();
      this.publishVideoHoldSpeed(enabled);
      return true;
    } catch (error) {
      return false;
    }
  }

  publishVideoHoldSpeed(enabled: boolean): void {
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_VIDEO_HOLD_SPEED, enabled);
  }

  loadCompactVideoLayout(context: common.Context): number {
    try {
      const options: preferences.Options = { name: MediaSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      const value: number = store.getSync(MediaSettingsStore.COMPACT_VIDEO_LAYOUT_KEY,
        COMPACT_VIDEO_LAYOUT_RAIL) as number;
      return value === COMPACT_VIDEO_LAYOUT_BOTTOM ? value : COMPACT_VIDEO_LAYOUT_RAIL;
    } catch (error) {
      return COMPACT_VIDEO_LAYOUT_RAIL;
    }
  }

  saveCompactVideoLayout(context: common.Context, layout: number): boolean {
    const value: number = layout === COMPACT_VIDEO_LAYOUT_BOTTOM ? layout : COMPACT_VIDEO_LAYOUT_RAIL;
    try {
      const options: preferences.Options = { name: MediaSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      store.putSync(MediaSettingsStore.COMPACT_VIDEO_LAYOUT_KEY, value);
      store.flushSync();
      AppStorage.setOrCreate<number>(STORAGE_KEY_COMPACT_VIDEO_LAYOUT, value);
      return true;
    } catch (error) {
      return false;
    }
  }

  loadVideoFeedLayout(context: common.Context): number {
    try {
      const options: preferences.Options = { name: MediaSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      const value: number = store.getSync(MediaSettingsStore.VIDEO_FEED_LAYOUT_KEY, VIDEO_FEED_LAYOUT_CLASSIC) as number;
      return value === VIDEO_FEED_LAYOUT_DOUYIN || value === VIDEO_FEED_LAYOUT_BILIBILI ? value : VIDEO_FEED_LAYOUT_CLASSIC;
    } catch (error) {
      return VIDEO_FEED_LAYOUT_CLASSIC;
    }
  }

  saveVideoFeedLayout(context: common.Context, layout: number): boolean {
    const value: number = layout === VIDEO_FEED_LAYOUT_DOUYIN || layout === VIDEO_FEED_LAYOUT_BILIBILI ? layout : VIDEO_FEED_LAYOUT_CLASSIC;
    try {
      const options: preferences.Options = { name: MediaSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      store.putSync(MediaSettingsStore.VIDEO_FEED_LAYOUT_KEY, value);
      store.flushSync();
      AppStorage.setOrCreate<number>(STORAGE_KEY_VIDEO_FEED_LAYOUT, value);
      return true;
    } catch (error) {
      return false;
    }
  }

  loadVideoControlStyle(context: common.Context): number {
    try {
      const options: preferences.Options = { name: MediaSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      const value: number = store.getSync(MediaSettingsStore.VIDEO_CONTROL_STYLE_KEY,
        DEFAULT_VIDEO_CONTROL_STYLE) as number;
      return this.validVideoControlStyle(value);
    } catch (error) {
      return DEFAULT_VIDEO_CONTROL_STYLE;
    }
  }

  saveVideoControlStyle(context: common.Context, style: number): boolean {
    const value: number = this.validVideoControlStyle(style);
    try {
      const options: preferences.Options = { name: MediaSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      store.putSync(MediaSettingsStore.VIDEO_CONTROL_STYLE_KEY, value);
      store.flushSync();
      this.publishVideoControlStyle(value);
      return true;
    } catch (error) {
      return false;
    }
  }

  publishVideoControlStyle(style: number): void {
    AppStorage.setOrCreate<number>(STORAGE_KEY_VIDEO_CONTROL_STYLE,
      this.validVideoControlStyle(style));
  }

  loadVideoBackgroundMode(context: common.Context): number {
    try {
      const options: preferences.Options = { name: MediaSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      const value: number = store.getSync(MediaSettingsStore.VIDEO_BACKGROUND_MODE_KEY,
        DEFAULT_VIDEO_BACKGROUND_MODE) as number;
      return this.validVideoBackgroundMode(value);
    } catch (error) {
      return DEFAULT_VIDEO_BACKGROUND_MODE;
    }
  }

  saveVideoBackgroundMode(context: common.Context, mode: number): boolean {
    const value: number = this.validVideoBackgroundMode(mode);
    try {
      const options: preferences.Options = { name: MediaSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      store.putSync(MediaSettingsStore.VIDEO_BACKGROUND_MODE_KEY, value);
      store.flushSync();
      this.publishVideoBackgroundMode(value);
      return true;
    } catch (error) {
      return false;
    }
  }

  publishVideoBackgroundMode(mode: number): void {
    AppStorage.setOrCreate<number>(STORAGE_KEY_VIDEO_BACKGROUND_MODE,
      this.validVideoBackgroundMode(mode));
  }

  loadCaptionOpacity(context: common.Context): number {
    try {
      const options: preferences.Options = { name: MediaSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      const value: number = store.getSync(MediaSettingsStore.CAPTION_OPACITY_KEY,
        DEFAULT_CAPTION_OPACITY) as number;
      return this.validCaptionOpacity(value);
    } catch (error) {
      return DEFAULT_CAPTION_OPACITY;
    }
  }

  saveCaptionOpacity(context: common.Context, opacity: number): boolean {
    const value: number = this.validCaptionOpacity(opacity);
    try {
      const options: preferences.Options = { name: MediaSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      store.putSync(MediaSettingsStore.CAPTION_OPACITY_KEY, value);
      store.flushSync();
      this.publishCaptionOpacity(value);
      return true;
    } catch (error) {
      return false;
    }
  }

  publishCaptionOpacity(opacity: number): void {
    AppStorage.setOrCreate<number>(STORAGE_KEY_CAPTION_OPACITY, opacity);
  }

  loadImageQuality(context: common.Context): number {
    try {
      const options: preferences.Options = { name: MediaSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      const value: number = store.getSync(MediaSettingsStore.IMAGE_QUALITY_KEY,
        DEFAULT_IMAGE_QUALITY) as number;
      return this.validImageQuality(value);
    } catch (error) {
      return DEFAULT_IMAGE_QUALITY;
    }
  }

  saveImageQuality(context: common.Context, quality: number): boolean {
    const value: number = this.validImageQuality(quality);
    try {
      const options: preferences.Options = { name: MediaSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      store.putSync(MediaSettingsStore.IMAGE_QUALITY_KEY, value);
      store.flushSync();
      AppStorage.setOrCreate<number>(STORAGE_KEY_IMAGE_QUALITY, value);
      return true;
    } catch (error) {
      return false;
    }
  }

  loadVideoQuality(context: common.Context): number {
    try {
      const options: preferences.Options = { name: MediaSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      const value: number = store.getSync(MediaSettingsStore.VIDEO_QUALITY_KEY,
        DEFAULT_VIDEO_QUALITY) as number;
      return this.validVideoQuality(value);
    } catch (error) {
      return DEFAULT_VIDEO_QUALITY;
    }
  }

  saveVideoQuality(context: common.Context, quality: number): boolean {
    const value: number = this.validVideoQuality(quality);
    try {
      const options: preferences.Options = { name: MediaSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      store.putSync(MediaSettingsStore.VIDEO_QUALITY_KEY, value);
      store.flushSync();
      AppStorage.setOrCreate<number>(STORAGE_KEY_VIDEO_QUALITY, value);
      return true;
    } catch (error) {
      return false;
    }
  }

  private validImageQuality(value: number): number {
    if (value === IMAGE_QUALITY_DATA_SAVER || value === IMAGE_QUALITY_ORIGINAL) {
      return value;
    }
    return IMAGE_QUALITY_HIGH;
  }

  private validVideoQuality(value: number): number {
    if (value === VIDEO_QUALITY_HIGH || value === VIDEO_QUALITY_SD || value === VIDEO_QUALITY_LD) {
      return value;
    }
    return VIDEO_QUALITY_AUTO;
  }

  private validVideoBackgroundMode(value: number): number {
    return value === VIDEO_BACKGROUND_PIP ? VIDEO_BACKGROUND_PIP : VIDEO_BACKGROUND_AUDIO;
  }

  private validVideoControlStyle(value: number): number {
    return value === VIDEO_CONTROL_STYLE_ORIGINAL ? VIDEO_CONTROL_STYLE_ORIGINAL : VIDEO_CONTROL_STYLE_SPACED;
  }

  private validCaptionOpacity(value: number): number {
    if (!Number.isFinite(value)) {
      return DEFAULT_CAPTION_OPACITY;
    }
    if (value < 0) {
      return 0;
    }
    if (value > 1) {
      return 1;
    }
    return value;
  }
}

export const mediaSettingsStore: MediaSettingsStore = new MediaSettingsStore();
