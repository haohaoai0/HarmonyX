import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { AppearanceStore } from './AppearanceStore';
import { accentUsesDarkMode, resolveAccentColor, isKnownAccentTheme } from '../utils/AccentPalette';

export const CLOUD_GROUP_APPEARANCE: number = 1;
export const CLOUD_GROUP_MEDIA: number = 2;
export const CLOUD_GROUP_FILTERS: number = 4;
export const CLOUD_GROUP_ALL: number = 7;
type CloudPreferenceValue = string | number | boolean;

export class CloudSettingField {
  store: string;
  key: string;
  storageKey: string;
  group: number;
  fallback: CloudPreferenceValue;
  min: number;
  max: number;
  constructor(store: string, key: string, storageKey: string, group: number,
    fallback: CloudPreferenceValue, min: number = 0, max: number = 1) {
    this.store = store; this.key = key; this.storageKey = storageKey;
    this.group = group; this.fallback = fallback; this.min = min; this.max = max;
  }
  id(): string { return this.store + '/' + this.key; }
}

// A small, explicit allowlist. No account, token, proxy, API key, file URI or chat store is exported.
export const CLOUD_SETTING_FIELDS: CloudSettingField[] = [
  new CloudSettingField('harmonyx_motion', 'reduce_motion', 'reduceMotionEnabled', 1, false),
  new CloudSettingField('harmonyx_motion', 'duration', 'harmonyx.motion_duration', 1, 300, 100, 700),
  new CloudSettingField('harmonyx_motion', 'amplitude', 'harmonyx.motion_amplitude', 1, 1, 0, 1.5),
  new CloudSettingField('harmonyx_motion', 'damping', 'harmonyx.motion_damping', 1, 0.82, 0.5, 1),
  new CloudSettingField('harmonyx_motion', 'symbol_effects', 'harmonyx.symbol_effects', 1, true),
  new CloudSettingField('harmonyx_motion', 'haptics_enabled', 'harmonyx.haptics_enabled', 1, true),
  new CloudSettingField('harmonyx_motion', 'haptics_intensity', 'harmonyx.haptics_intensity', 1, 60, 1, 100),
  new CloudSettingField('harmonyx_appearance', 'display_mode', 'harmonyx.display_mode', 1, 'system'),
  new CloudSettingField('harmonyx_appearance', 'accent_color', 'harmonyx.accent_theme', 1, '#007DFF'),
  new CloudSettingField('harmonyx_appearance', 'font_mode', 'harmonyx.font_mode', 1, 'system'),
  new CloudSettingField('harmonyx_appearance', 'font_scale', 'harmonyx.font_scale', 1, 1, 0.85, 1.75),
  new CloudSettingField('harmonyx_appearance', 'dark_surface', 'harmonyx.dark_surface', 1, 'black'),
  new CloudSettingField('harmonyx_appearance', 'auto_hide_title_bar', 'harmonyx.auto_hide_title_bar', 1, false),
  new CloudSettingField('harmonyx_appearance', 'auto_hide_tab_bar', 'harmonyx.auto_hide_tab_bar', 1, false),
  new CloudSettingField('harmonyx_appearance', 'auto_hide_fab', 'harmonyx.auto_hide_fab', 1, true),
  new CloudSettingField('harmonyx_appearance', 'title_bar_style_mode', 'harmonyx.title_bar_style_mode', 1, 0, 0, 3),
  new CloudSettingField('harmonyx_appearance', 'title_bar_glass_material_level', 'harmonyx.title_bar_glass_material_level', 1, 0, 0, 4),
  new CloudSettingField('harmonyx_appearance', 'title_bar_logo', 'harmonyx.title_bar_logo', 1, true),
  new CloudSettingField('harmonyx_hds_tabs', 'classic_bottom_bar', 'harmonyx.classic_bottom_bar', 1, false),
  new CloudSettingField('harmonyx_hds_tabs', 'root_tab_labels_visible', 'harmonyx.root_tab_labels_visible', 1, true),
  new CloudSettingField('harmonyx_sheet_material', 'enabled', 'harmonyx.sheet_material_enabled', 1, true),
  new CloudSettingField('harmonyx_sheet_material', 'level', 'harmonyx.sheet_material_level', 1, 2, 0, 4),
  new CloudSettingField('harmonyx_media', 'video_autoplay', 'harmonyx.video_autoplay', 2, true),
  new CloudSettingField('harmonyx_media', 'home_video_muted', 'harmonyx.home_video_muted', 2, true),
  new CloudSettingField('harmonyx_media', 'viewer_video_muted', 'harmonyx.viewer_video_muted', 2, true),
  new CloudSettingField('harmonyx_media', 'image_quality', 'harmonyx.image_quality', 2, 2, 0, 2),
  new CloudSettingField('harmonyx_media', 'video_quality', 'harmonyx.video_quality', 2, 0, 0, 3),
  new CloudSettingField('harmonyx_media', 'video_feed_tap_pause', 'harmonyx.video_feed_tap_pause', 2, true),
  new CloudSettingField('harmonyx_media', 'video_double_tap_seek', 'harmonyx.video_double_tap_seek', 2, true),
  new CloudSettingField('harmonyx_media', 'video_double_tap_seek_seconds', 'harmonyx.video_double_tap_seek_seconds', 2, 10, 1, 60),
  new CloudSettingField('harmonyx_media', 'media_viewer_black_background', 'harmonyx.media_viewer_black_background', 2, false),
  new CloudSettingField('harmonyx_media', 'media_comment_background', 'harmonyx.media_comment_background', 2, true),
  new CloudSettingField('harmonyx_content_filter', 'only_media', 'harmonyx.filter_only_media', 4, false),
  new CloudSettingField('harmonyx_content_filter', 'hide_reposts', 'harmonyx.filter_hide_reposts', 4, false),
  new CloudSettingField('harmonyx_content_filter', 'hide_replies', 'harmonyx.filter_hide_replies', 4, false),
  new CloudSettingField('harmonyx_content_filter', 'hide_ads', 'harmonyx.filter_hide_ads', 4, true),
  new CloudSettingField('harmonyx_content_filter', 'keywords', 'harmonyx.filter_keywords', 4, ''),
  new CloudSettingField('harmonyx_content_filter', 'muted_users', 'harmonyx.filter_muted_users', 4, '')
];

export class CloudSettingRecord {
  id: string = '';
  value: string = '';
  revision: number = 0;
  writer: string = '';
}

export class CloudSettingsPayload {
  version: number = 1;
  owner: string = '';
  records: CloudSettingRecord[] = [];
}

export function cloudField(id: string): CloudSettingField | undefined {
  return CLOUD_SETTING_FIELDS.find((field: CloudSettingField): boolean => field.id() === id);
}

export function validCloudValue(field: CloudSettingField, encoded: string): boolean {
  try {
    if (typeof encoded !== 'string' || encoded.length > 50000) { return false; }
    const value: CloudPreferenceValue = JSON.parse(encoded) as CloudPreferenceValue;
    if (typeof value !== typeof field.fallback) { return false; }
    if (typeof value === 'number') {
      return Number.isFinite(value) && value >= field.min && value <= field.max &&
        (field.key === 'font_scale' || (field.store === 'harmonyx_motion' &&
          (field.key === 'amplitude' || field.key === 'damping')) || Number.isInteger(value));
    }
    if (typeof value === 'string') {
      if (field.key === 'display_mode') { return ['system', 'light', 'dark'].indexOf(value) >= 0; }
      if (field.key === 'font_mode') { return ['system', 'app'].indexOf(value) >= 0; }
      if (field.key === 'dark_surface') { return ['black', 'gentle'].indexOf(value) >= 0; }
      if (field.key === 'accent_color') { return isKnownAccentTheme(value) && (/^#[0-9a-fA-F]{6}$/.test(value) || /^[a-z_]{1,32}$/.test(value)); }
    }
    return true;
  } catch (error) { return false; }
}

export function parseCloudSettings(raw: string, owner: string): CloudSettingsPayload {
  if (raw.length > 2000000) { throw new Error('Cloud settings too large'); }
  const payload: CloudSettingsPayload = JSON.parse(raw) as CloudSettingsPayload;
  if (payload === null || payload.version !== 1 || payload.owner !== owner || !Array.isArray(payload.records) ||
    payload.records.length > 256) { throw new Error('Invalid cloud settings'); }
  const ids: string[] = [];
  for (const record of payload.records) {
    if (record === null || typeof record.id !== 'string' || typeof record.writer !== 'string' ||
      !/^[a-zA-Z0-9-]{1,64}$/.test(record.writer) || !Number.isSafeInteger(record.revision) ||
      record.revision < 0 || ids.indexOf(record.id) >= 0) { throw new Error('Invalid cloud record'); }
    ids.push(record.id);
    const field: CloudSettingField | undefined = cloudField(record.id);
    if (field !== undefined && !validCloudValue(field, record.value)) { throw new Error('Invalid cloud value'); }
  }
  return payload;
}

// Field revisions are logical clocks. Wall-clock skew cannot overwrite newer observations.
export function mergeCloudSettings(local: CloudSettingRecord[], remote: CloudSettingRecord[], mask: number): CloudSettingRecord[] {
  const merged: CloudSettingRecord[] = local.slice();
  for (const candidate of remote) {
    const field: CloudSettingField | undefined = cloudField(candidate.id);
    if (field === undefined || (field.group & mask) === 0 || !validCloudValue(field, candidate.value)) { continue; }
    const index: number = merged.findIndex((item: CloudSettingRecord): boolean => item.id === candidate.id);
    if (index < 0) { merged.push(candidate); continue; }
    const current: CloudSettingRecord = merged[index];
    if (candidate.revision > current.revision ||
      (candidate.revision === current.revision && candidate.writer > current.writer)) { merged[index] = candidate; }
  }
  return merged;
}

export class CloudSettingsRepository {
  private context: common.UIAbilityContext;
  constructor(context: common.UIAbilityContext) { this.context = context; }

  capture(records: CloudSettingRecord[], writer: string, mask: number): CloudSettingRecord[] {
    let clock: number = records.reduce((max: number, item: CloudSettingRecord): number => Math.max(max, item.revision), 0);
    const result: CloudSettingRecord[] = records.slice();
    for (const field of CLOUD_SETTING_FIELDS) {
      if ((field.group & mask) === 0) { continue; }
      const store: preferences.Preferences = preferences.getPreferencesSync(this.context, { name: field.store });
      const value: string = JSON.stringify(store.getSync(field.key, field.fallback));
      if (!validCloudValue(field, value)) { continue; }
      const index: number = result.findIndex((item: CloudSettingRecord): boolean => item.id === field.id());
      if (index >= 0 && result[index].value === value) { continue; }
      const record: CloudSettingRecord = new CloudSettingRecord();
      record.id = field.id(); record.value = value; record.writer = writer;
      // An absent default is a baseline, not a fresh user edit on a new device.
      record.revision = index < 0 && !store.hasSync(field.key) ? 0 : ++clock;
      if (index < 0) { result.push(record); } else { result[index] = record; }
    }
    return result;
  }

  apply(records: CloudSettingRecord[], mask: number): void {
    for (const record of records) {
      const field: CloudSettingField | undefined = cloudField(record.id);
      if (field === undefined || (field.group & mask) === 0 || !validCloudValue(field, record.value)) { continue; }
      const value: CloudPreferenceValue = JSON.parse(record.value) as CloudPreferenceValue;
      const store: preferences.Preferences = preferences.getPreferencesSync(this.context, { name: field.store });
      if (JSON.stringify(store.getSync(field.key, field.fallback)) !== record.value) {
        store.putSync(field.key, value); store.flushSync();
      }
      AppStorage.setOrCreate<CloudPreferenceValue>(field.storageKey, value);
    }
    if ((mask & CLOUD_GROUP_APPEARANCE) !== 0) {
      const appearance: AppearanceStore = new AppearanceStore();
      const settings = appearance.load(this.context);
      const dark: boolean = accentUsesDarkMode(settings.mode,
        this.context.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
      AppStorage.setOrCreate<string>('harmonyx.accent_color', resolveAccentColor(settings.accentColor, dark));
      this.context.getApplicationContext().setColorMode(appearance.colorMode(settings.mode));
    }
    if ((mask & CLOUD_GROUP_FILTERS) !== 0) {
      AppStorage.setOrCreate<number>('harmonyx.filter_revision',
        (AppStorage.get<number>('harmonyx.filter_revision') ?? 0) + 1);
    }
  }
}
