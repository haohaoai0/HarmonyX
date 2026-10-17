import { i18n } from '@kit.LocalizationKit';

export const STORAGE_KEY_APP_LOCALE: string = 'harmonyx.app_locale';

export function effectiveAppLocale(): string {
  try {
    const preferred: string = i18n.System.getAppPreferredLanguage();
    if (preferred.length > 0 && preferred !== 'default') { return preferred; }
  } catch (error) { }
  return i18n.System.getSystemLanguage();
}

export function publishAppLocale(): void {
  const locale: string = effectiveAppLocale();
  if (AppStorage.get<string>(STORAGE_KEY_APP_LOCALE) === locale) { return; }
  AppStorage.setOrCreate<string>(STORAGE_KEY_APP_LOCALE, locale);
  const previous: number = AppStorage.get<number>('harmonyx.post_time_now') ?? 0;
  // Existing post components observe this clock and can reformat without a fetch.
  AppStorage.setOrCreate<number>('harmonyx.post_time_now', Math.max(Date.now(), previous + 1));
}

export function isAppRtl(locale: string = effectiveAppLocale()): boolean {
  try { return i18n.isRTL(locale); } catch (error) { return false; }
}
