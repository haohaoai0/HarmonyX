// Persistent application-language preference. Language resources are resolved
// by the system after ApplicationContext.setLanguage() updates this setting.
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

export const APP_LANGUAGE_ZH_CN: string = 'zh-cn';
export const APP_LANGUAGE_EN: string = 'en';
export const DEFAULT_APP_LANGUAGE: string = APP_LANGUAGE_ZH_CN;

export class LanguageStore {
  private static readonly STORE_NAME: string = 'harmonyx_language';
  private static readonly LANGUAGE_KEY: string = 'app_language';

  load(context: common.Context): string {
    try {
      const options: preferences.Options = { name: LanguageStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      const savedLanguage: string = store.getSync(LanguageStore.LANGUAGE_KEY, DEFAULT_APP_LANGUAGE) as string;
      return this.isSupported(savedLanguage) ? savedLanguage : DEFAULT_APP_LANGUAGE;
    } catch (error) {
      return DEFAULT_APP_LANGUAGE;
    }
  }

  save(context: common.Context, language: string): void {
    if (!this.isSupported(language)) {
      return;
    }
    try {
      const options: preferences.Options = { name: LanguageStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      store.putSync(LanguageStore.LANGUAGE_KEY, language);
      store.flushSync();
    } catch (error) {
      // A failed preference write must not prevent the active language change.
    }
  }

  private isSupported(language: string): boolean {
    return language === APP_LANGUAGE_ZH_CN || language === APP_LANGUAGE_EN;
  }
}
