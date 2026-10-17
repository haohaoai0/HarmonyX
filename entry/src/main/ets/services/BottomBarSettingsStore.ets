import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

export const STORAGE_KEY_BOTTOM_BAR_PAGES: string = 'harmonyx.bottom_bar_pages';
export const DEFAULT_BOTTOM_BAR_PAGES_MASK: number = 31;
export const BOTTOM_BAR_PAGE_COUNT: number = 5;
export const BOTTOM_BAR_HOME_PAGE: number = 0;
export const BOTTOM_BAR_EXPLORE_PAGE: number = 1;
export const BOTTOM_BAR_NOTIFICATIONS_PAGE: number = 2;
export const BOTTOM_BAR_MESSAGES_PAGE: number = 3;
export const BOTTOM_BAR_ME_PAGE: number = 4;

export class BottomBarSettingsStore {
  private static readonly STORE_NAME: string = 'harmonyx_bottom_bar';
  private static readonly PAGES_KEY: string = 'pages_mask';

  load(context: common.Context): number {
    try {
      const options: preferences.Options = { name: BottomBarSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      const saved: number = store.getSync(BottomBarSettingsStore.PAGES_KEY,
        DEFAULT_BOTTOM_BAR_PAGES_MASK) as number;
      return this.normalise(saved);
    } catch (error) {
      return DEFAULT_BOTTOM_BAR_PAGES_MASK;
    }
  }

  save(context: common.Context, pagesMask: number): boolean {
    const normalized: number = pagesMask & DEFAULT_BOTTOM_BAR_PAGES_MASK;
    if (this.enabledPageCount(normalized) < 2) {
      return false;
    }
    try {
      const options: preferences.Options = { name: BottomBarSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      store.putSync(BottomBarSettingsStore.PAGES_KEY, normalized);
      store.flushSync();
      AppStorage.setOrCreate<number>(STORAGE_KEY_BOTTOM_BAR_PAGES, normalized);
      return true;
    } catch (error) {
      return false;
    }
  }

  enabledPageCount(pagesMask: number): number {
    let count: number = 0;
    for (let page: number = 0; page < BOTTOM_BAR_PAGE_COUNT; page++) {
      if ((pagesMask & (1 << page)) !== 0) {
        count++;
      }
    }
    return count;
  }

  private normalise(pagesMask: number): number {
    const normalized: number = pagesMask & DEFAULT_BOTTOM_BAR_PAGES_MASK;
    if (this.enabledPageCount(normalized) < 2) {
      return DEFAULT_BOTTOM_BAR_PAGES_MASK;
    }
    return normalized;
  }
}

export const bottomBarSettingsStore: BottomBarSettingsStore = new BottomBarSettingsStore();
