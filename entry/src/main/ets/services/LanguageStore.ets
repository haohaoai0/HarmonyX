// Persistent application-language preference. Language resources are resolved
// by the system after i18n.System.setAppPreferredLanguage() updates this setting.
// APP_LANGUAGE_SYSTEM keeps the platform default, where the interface follows
// the system language and keeps following it while the app runs.
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

export const APP_LANGUAGE_SYSTEM: string = 'system';
export const APP_LANGUAGE_ZH_CN: string = 'zh-cn';
export const APP_LANGUAGE_EN: string = 'en';
export const APP_LANGUAGE_IT: string = 'it';
export const DEFAULT_APP_LANGUAGE: string = APP_LANGUAGE_SYSTEM;

export interface AppLanguageOption { tag: string; name: Resource; }

export const SUPPORTED_APP_LANGUAGE_TAGS: string[] = [
  APP_LANGUAGE_ZH_CN, 'zh-Hant', APP_LANGUAGE_EN, 'ru', 'uk', 'fa', 'ar', 'id', 'ms', 'tr',
  'vi', 'th', 'ja', 'ko', 'de', 'fr', 'es', 'pt', APP_LANGUAGE_IT, 'hi'
];

// Endonyms stay readable even when the user accidentally chooses another language.
export function supportedAppLanguages(): AppLanguageOption[] {
  return [
    { tag: APP_LANGUAGE_ZH_CN, name: $r('app.string.settings_language_name_zh_hans') },
    { tag: 'zh-Hant', name: $r('app.string.settings_language_name_zh_hant') },
    { tag: APP_LANGUAGE_EN, name: $r('app.string.settings_language_name_en') },
    { tag: 'ru', name: $r('app.string.settings_language_name_ru') },
    { tag: 'uk', name: $r('app.string.settings_language_name_uk') },
    { tag: 'fa', name: $r('app.string.settings_language_name_fa') },
    { tag: 'ar', name: $r('app.string.settings_language_name_ar') },
    { tag: 'id', name: $r('app.string.settings_language_name_id') },
    { tag: 'ms', name: $r('app.string.settings_language_name_ms') },
    { tag: 'tr', name: $r('app.string.settings_language_name_tr') },
    { tag: 'vi', name: $r('app.string.settings_language_name_vi') },
    { tag: 'th', name: $r('app.string.settings_language_name_th') },
    { tag: 'ja', name: $r('app.string.settings_language_name_ja') },
    { tag: 'ko', name: $r('app.string.settings_language_name_ko') },
    { tag: 'de', name: $r('app.string.settings_language_name_de') },
    { tag: 'fr', name: $r('app.string.settings_language_name_fr') },
    { tag: 'es', name: $r('app.string.settings_language_name_es') },
    { tag: 'pt', name: $r('app.string.settings_language_name_pt') },
    { tag: APP_LANGUAGE_IT, name: $r('app.string.settings_language_name_it') },
    { tag: 'hi', name: $r('app.string.settings_language_name_hi') }
  ];
}

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
    return language === APP_LANGUAGE_SYSTEM || SUPPORTED_APP_LANGUAGE_TAGS.indexOf(language) >= 0;
  }
}
