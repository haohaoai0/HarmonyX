import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

export const STORAGE_KEY_PAGE_TRANSITION_MODE: string = 'harmonyx.page_transition_mode';
export const PAGE_TRANSITION_CLASSIC: string = 'classic';
export const PAGE_TRANSITION_OFFICIAL: string = 'official';
export const DEFAULT_PAGE_TRANSITION_MODE: string = PAGE_TRANSITION_CLASSIC;

export function validPageTransitionMode(value: string): string {
  return value === PAGE_TRANSITION_OFFICIAL ? PAGE_TRANSITION_OFFICIAL : DEFAULT_PAGE_TRANSITION_MODE;
}

export class PageTransitionSettingsStore {
  private static readonly STORE_NAME: string = 'harmonyx_page_transition';
  private static readonly MODE_KEY: string = 'mode';

  load(context: common.Context): string {
    try {
      const options: preferences.Options = { name: PageTransitionSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      return validPageTransitionMode(store.getSync(PageTransitionSettingsStore.MODE_KEY,
        DEFAULT_PAGE_TRANSITION_MODE) as string);
    } catch (error) {
      return DEFAULT_PAGE_TRANSITION_MODE;
    }
  }

  save(context: common.Context, mode: string): boolean {
    const value: string = validPageTransitionMode(mode);
    try {
      const options: preferences.Options = { name: PageTransitionSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      store.putSync(PageTransitionSettingsStore.MODE_KEY, value);
      store.flushSync();
      AppStorage.setOrCreate<string>(STORAGE_KEY_PAGE_TRANSITION_MODE, value);
      return true;
    } catch (error) {
      return false;
    }
  }
}

export const pageTransitionSettingsStore: PageTransitionSettingsStore = new PageTransitionSettingsStore();
