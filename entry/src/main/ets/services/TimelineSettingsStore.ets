// The selected home timeline is restored before the first network request, so
// launch never briefly loads the wrong feed.
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

export const STORAGE_KEY_DEFAULT_HOME_FEED: string = 'harmonyx.default_home_feed';
export const STORAGE_KEY_TIMELINE_COLUMNS: string = 'harmonyx.timeline_columns';
export const STORAGE_KEY_COVER_SINGLE_COLUMN: string = 'harmonyx.cover_single_column';
export const STORAGE_KEY_COVER_SCREEN_ACTIVE: string = 'harmonyx.cover_screen_active';
export const HOME_FEED_FOR_YOU: number = 0;
export const HOME_FEED_FOLLOWING: number = 1;
export const TIMELINE_COLUMNS_AUTO: number = 0;
export const TIMELINE_COLUMNS_ONE: number = 1;
export const TIMELINE_COLUMNS_TWO: number = 2;
export const TIMELINE_COLUMNS_THREE: number = 3;
export const TIMELINE_COLUMNS_AUTO_TWO: number = 4;
// Keep the stored value 4 for the existing adaptive two-column mode.
export const TIMELINE_COLUMNS_FOUR: number = 5;
export const TIMELINE_COLUMNS_FIVE: number = 6;

export class TimelineSettingsStore {
  private static readonly STORE_NAME: string = 'harmonyx_timeline';
  private static readonly DEFAULT_HOME_FEED_KEY: string = 'default_home_feed';
  private static readonly TIMELINE_COLUMNS_KEY: string = 'timeline_columns';

  private normalise(mode: number): number {
    return mode === HOME_FEED_FOLLOWING ? HOME_FEED_FOLLOWING : HOME_FEED_FOR_YOU;
  }

  private normaliseColumns(value: number): number {
    if (value === TIMELINE_COLUMNS_ONE || value === TIMELINE_COLUMNS_TWO ||
      value === TIMELINE_COLUMNS_THREE || value === TIMELINE_COLUMNS_AUTO_TWO ||
      value === TIMELINE_COLUMNS_FOUR || value === TIMELINE_COLUMNS_FIVE) {
      return value;
    }
    return TIMELINE_COLUMNS_AUTO;
  }

  loadDefaultHomeFeed(context: common.Context): number {
    try {
      const options: preferences.Options = { name: TimelineSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      const saved: number = store.getSync(TimelineSettingsStore.DEFAULT_HOME_FEED_KEY,
        HOME_FEED_FOR_YOU) as number;
      return this.normalise(saved);
    } catch (error) {
      return HOME_FEED_FOR_YOU;
    }
  }

  saveDefaultHomeFeed(context: common.Context, mode: number): boolean {
    const value: number = this.normalise(mode);
    try {
      const options: preferences.Options = { name: TimelineSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      store.putSync(TimelineSettingsStore.DEFAULT_HOME_FEED_KEY, value);
      store.flushSync();
      this.publishDefaultHomeFeed(value);
      return true;
    } catch (error) {
      return false;
    }
  }

  publishDefaultHomeFeed(mode: number): void {
    AppStorage.setOrCreate<number>(STORAGE_KEY_DEFAULT_HOME_FEED, this.normalise(mode));
  }

  loadTimelineColumns(context: common.Context): number {
    try {
      const options: preferences.Options = { name: TimelineSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      const saved: number = store.getSync(TimelineSettingsStore.TIMELINE_COLUMNS_KEY,
        TIMELINE_COLUMNS_AUTO) as number;
      return this.normaliseColumns(saved);
    } catch (error) {
      return TIMELINE_COLUMNS_AUTO;
    }
  }

  saveTimelineColumns(context: common.Context, value: number): boolean {
    const columns: number = this.normaliseColumns(value);
    try {
      const options: preferences.Options = { name: TimelineSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      store.putSync(TimelineSettingsStore.TIMELINE_COLUMNS_KEY, columns);
      store.flushSync();
      this.publishTimelineColumns(columns);
      return true;
    } catch (error) {
      return false;
    }
  }

  loadCoverSingleColumn(context: common.Context): boolean {
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: TimelineSettingsStore.STORE_NAME });
      return store.getSync('cover_single_column', true) === true;
    } catch (error) { return true; }
  }

  saveCoverSingleColumn(context: common.Context, enabled: boolean): boolean {
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: TimelineSettingsStore.STORE_NAME });
      store.putSync('cover_single_column', enabled);
      store.flushSync();
      AppStorage.setOrCreate<boolean>(STORAGE_KEY_COVER_SINGLE_COLUMN, enabled);
      return true;
    } catch (error) { return false; }
  }

  publishTimelineColumns(value: number): void {
    AppStorage.setOrCreate<number>(STORAGE_KEY_TIMELINE_COLUMNS, this.normaliseColumns(value));
  }
}

export const timelineSettingsStore: TimelineSettingsStore = new TimelineSettingsStore();
