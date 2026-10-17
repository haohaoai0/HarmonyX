// Where post links should open: the in-app half-modal preview or the system
// browser. Only the flag is persisted; the URL itself never is.
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

export const STORAGE_KEY_LINK_IN_APP: string = 'harmonyx.link_in_app';
export const STORAGE_KEY_LINK_PREVIEW_URL: string = 'harmonyx.link_preview_url';

export class LinkSettingsStore {
  private static readonly STORE_NAME: string = 'harmonyx_links';
  private static readonly IN_APP_KEY: string = 'open_in_app';

  load(context: common.Context): boolean {
    try {
      const options: preferences.Options = { name: LinkSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      return store.getSync(LinkSettingsStore.IN_APP_KEY, false) as boolean;
    } catch (error) {
      return false;
    }
  }

  save(context: common.Context, inApp: boolean): boolean {
    try {
      const options: preferences.Options = { name: LinkSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      store.putSync(LinkSettingsStore.IN_APP_KEY, inApp);
      store.flushSync();
      this.publish(inApp);
      return true;
    } catch (error) {
      return false;
    }
  }

  // Post text reads the flag from AppStorage so a tap never has to touch
  // preferences on the render path.
  publish(inApp: boolean): void {
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_LINK_IN_APP, inApp);
  }

  // Asks the root page to show its preview sheet instead of opening a browser.
  static requestPreview(url: string): void {
    AppStorage.setOrCreate<string>(STORAGE_KEY_LINK_PREVIEW_URL, url);
  }
}

export const linkSettingsStore: LinkSettingsStore = new LinkSettingsStore();
