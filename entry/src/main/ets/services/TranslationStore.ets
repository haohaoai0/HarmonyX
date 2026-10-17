// Persistent AI-translation configuration (bring-your-own key).
// Only the settings live here; the request itself is issued by
// TranslationService so the UI layer never touches vendor payloads.
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import {
  DEFAULT_TARGET_LANGUAGE,
  DEFAULT_SOURCE_LANGUAGE,
  findTranslationProvider,
  isValidSourceLanguage,
  isValidTranslationMode,
  isValidTargetLanguage,
  normalizeExcludedTranslationLanguages,
  normalizeTranslationLanguage,
  sameTranslationLanguage,
  TARGET_LANGUAGE_APP,
  TARGET_LANGUAGE_ZH,
  TRANSLATION_MODE_API,
  TRANSLATION_MODE_WEB,
  TRANSLATION_MODE_X,
  TRANSLATION_PROVIDERS
} from '../models/Translation';
import { effectiveAppLocale } from '../utils/AppLocale';

// Published so any post card can react to the toggle without re-reading
// preferences on every render.
export const STORAGE_KEY_TRANSLATION_ENABLED: string = 'harmonyx.translation_enabled';
export const STORAGE_KEY_TRANSLATION_REPLACE_ORIGINAL: string = 'harmonyx.translation_replace_original';
export const STORAGE_KEY_TRANSLATION_AUTO_ENABLED: string = 'harmonyx.translation_auto_enabled';
export const STORAGE_KEY_TRANSLATION_SETTINGS_REVISION: string = 'harmonyx.translation_settings_revision';

export class TranslationSettings {
  enabled: boolean = false;
  replaceOriginal: boolean = false;
  autoTranslate: boolean = false;
  sourceLanguage: string = DEFAULT_SOURCE_LANGUAGE;
  autoTranslateExcludedLanguages: string = '';
  mode: string = TRANSLATION_MODE_API;
  providerId: string = 'openai';
  model: string = '';
  apiKey: string = '';
  targetLanguage: string = DEFAULT_TARGET_LANGUAGE;
  // Blank means "use the provider preset". Azure and self-hosted gateways
  // fill this in from Settings.
  baseUrlOverride: string = '';

  constructor(enabled: boolean, replaceOriginal: boolean, autoTranslate: boolean, sourceLanguage: string,
    autoTranslateExcludedLanguages: string, mode: string, providerId: string, model: string, apiKey: string,
    targetLanguage: string, baseUrlOverride: string) {
    this.enabled = enabled;
    this.replaceOriginal = replaceOriginal;
    this.autoTranslate = autoTranslate;
    this.sourceLanguage = sourceLanguage;
    this.autoTranslateExcludedLanguages = autoTranslateExcludedLanguages;
    this.mode = mode;
    this.providerId = providerId;
    this.model = model;
    this.apiKey = apiKey;
    this.targetLanguage = targetLanguage;
    this.baseUrlOverride = baseUrlOverride;
  }

  // Web translation is intentionally keyless. API translation remains opt-in
  // and requires a complete provider configuration.
  isRunnable(): boolean {
    if (!this.enabled) {
      return false;
    }
    if (this.mode === TRANSLATION_MODE_WEB || this.mode === TRANSLATION_MODE_X) {
      return true;
    }
    if (this.apiKey.length === 0) {
      return false;
    }
    const provider: string = this.effectiveBaseUrl();
    return provider.length > 0 && this.effectiveModel().length > 0;
  }

  shouldAutomaticallyTranslate(postLanguage: string): boolean {
    if (!this.autoTranslate || (this.mode !== TRANSLATION_MODE_API && this.mode !== TRANSLATION_MODE_X) ||
      !this.isRunnable()) {
      return false;
    }
    // The post's detected language controls exclusions even when the user has
    // configured a fixed source language for the provider's translation prompt.
    const source: string = normalizeTranslationLanguage(postLanguage);
    // Unknown/undetermined languages cannot safely bypass an exclusion list.
    if (source.length === 0 && this.autoTranslateExcludedLanguages.trim().length > 0) { return false; }
    if (sameTranslationLanguage(source, this.effectiveTargetLanguage())) {
      return false;
    }
    const excluded: string[] = this.autoTranslateExcludedLanguages.split(',');
    for (let i: number = 0; i < excluded.length; i++) {
      if (sameTranslationLanguage(source, excluded[i])) {
        return false;
      }
    }
    return true;
  }

  effectiveTargetLanguage(): string {
    const language: string = this.targetLanguage === TARGET_LANGUAGE_APP ? effectiveAppLocale() : this.targetLanguage;
    return normalizeTranslationLanguage(language) || TARGET_LANGUAGE_ZH;
  }

  effectiveBaseUrl(): string {
    const override: string = this.baseUrlOverride.trim();
    if (override.length > 0) {
      return TranslationStore.trimTrailingSlash(override);
    }
    const preset = findTranslationProvider(this.providerId);
    if (preset === undefined) {
      return '';
    }
    return TranslationStore.trimTrailingSlash(preset.baseUrl);
  }

  effectiveModel(): string {
    const chosen: string = this.model.trim();
    if (chosen.length > 0) {
      return chosen;
    }
    const preset = findTranslationProvider(this.providerId);
    if (preset === undefined || preset.models.length === 0) {
      return '';
    }
    return preset.models[0];
  }
}

export class TranslationStore {
  private static readonly STORE_NAME: string = 'harmonyx_translation';
  private static readonly ENABLED_KEY: string = 'enabled';
  private static readonly REPLACE_ORIGINAL_KEY: string = 'replace_original';
  private static readonly AUTO_TRANSLATE_KEY: string = 'auto_translate';
  private static readonly SOURCE_LANGUAGE_KEY: string = 'source_language';
  private static readonly AUTO_EXCLUDED_LANGUAGES_KEY: string = 'auto_excluded_languages';
  private static readonly MODE_KEY: string = 'mode';
  private static readonly PROVIDER_KEY: string = 'provider_id';
  private static readonly MODEL_KEY: string = 'model';
  private static readonly API_KEY_KEY: string = 'api_key';
  private static readonly TARGET_KEY: string = 'target_language';
  private static readonly BASE_URL_KEY: string = 'base_url';

  load(context: common.Context): TranslationSettings {
    try {
      const options: preferences.Options = { name: TranslationStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      const enabled: boolean = store.getSync(TranslationStore.ENABLED_KEY, false) as boolean;
      const replaceOriginal: boolean = store.getSync(TranslationStore.REPLACE_ORIGINAL_KEY, false) as boolean;
      const autoTranslate: boolean = store.getSync(TranslationStore.AUTO_TRANSLATE_KEY, false) as boolean;
      const sourceLanguage: string = store.getSync(TranslationStore.SOURCE_LANGUAGE_KEY,
        DEFAULT_SOURCE_LANGUAGE) as string;
      const autoExcluded: string = store.getSync(TranslationStore.AUTO_EXCLUDED_LANGUAGES_KEY, '') as string;
      const mode: string = store.getSync(TranslationStore.MODE_KEY, TRANSLATION_MODE_API) as string;
      const providerId: string = store.getSync(TranslationStore.PROVIDER_KEY, 'openai') as string;
      const model: string = store.getSync(TranslationStore.MODEL_KEY, '') as string;
      const apiKey: string = store.getSync(TranslationStore.API_KEY_KEY, '') as string;
      const target: string = store.getSync(TranslationStore.TARGET_KEY, DEFAULT_TARGET_LANGUAGE) as string;
      const baseUrl: string = store.getSync(TranslationStore.BASE_URL_KEY, '') as string;
      const resolvedProvider: string =
        findTranslationProvider(providerId) === undefined ? TRANSLATION_PROVIDERS[0].id : providerId;
      return new TranslationSettings(enabled, replaceOriginal, autoTranslate,
        isValidSourceLanguage(sourceLanguage) && sourceLanguage !== DEFAULT_SOURCE_LANGUAGE ?
          normalizeTranslationLanguage(sourceLanguage) : DEFAULT_SOURCE_LANGUAGE,
        normalizeExcludedTranslationLanguages(autoExcluded),
        isValidTranslationMode(mode) ? mode : TRANSLATION_MODE_API, resolvedProvider, model.trim(), apiKey.trim(),
        target === TARGET_LANGUAGE_APP ? target :
          isValidTargetLanguage(target) ? normalizeTranslationLanguage(target) : DEFAULT_TARGET_LANGUAGE, baseUrl.trim());
    } catch (error) {
      return new TranslationSettings(false, false, false, DEFAULT_SOURCE_LANGUAGE, '', TRANSLATION_MODE_API,
        TRANSLATION_PROVIDERS[0].id, '', '', DEFAULT_TARGET_LANGUAGE, '');
    }
  }

  save(context: common.Context, settings: TranslationSettings): boolean {
    try {
      const options: preferences.Options = { name: TranslationStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      store.putSync(TranslationStore.ENABLED_KEY, settings.enabled);
      store.putSync(TranslationStore.REPLACE_ORIGINAL_KEY, settings.replaceOriginal);
      store.putSync(TranslationStore.AUTO_TRANSLATE_KEY, settings.autoTranslate);
      store.putSync(TranslationStore.SOURCE_LANGUAGE_KEY, settings.sourceLanguage);
      store.putSync(TranslationStore.AUTO_EXCLUDED_LANGUAGES_KEY,
        normalizeExcludedTranslationLanguages(settings.autoTranslateExcludedLanguages));
      store.putSync(TranslationStore.MODE_KEY, settings.mode);
      store.putSync(TranslationStore.PROVIDER_KEY, settings.providerId);
      store.putSync(TranslationStore.MODEL_KEY, settings.model.trim());
      store.putSync(TranslationStore.API_KEY_KEY, settings.apiKey.trim());
      store.putSync(TranslationStore.TARGET_KEY, settings.targetLanguage);
      store.putSync(TranslationStore.BASE_URL_KEY, settings.baseUrlOverride.trim());
      store.flushSync();
      this.publish(settings, true);
      return true;
    } catch (error) {
      return false;
    }
  }

  // Mirrors the enable flag into AppStorage; failures are non-fatal because
  // post cards fall back to reading the persisted value.
  publish(settings: TranslationSettings, settingsChanged: boolean = false): void {
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_TRANSLATION_ENABLED, settings.enabled);
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_TRANSLATION_REPLACE_ORIGINAL, settings.replaceOriginal);
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_TRANSLATION_AUTO_ENABLED, settings.autoTranslate);
    if (settingsChanged) {
      const revision: number = AppStorage.get<number>(STORAGE_KEY_TRANSLATION_SETTINGS_REVISION) ?? 0;
      AppStorage.setOrCreate<number>(STORAGE_KEY_TRANSLATION_SETTINGS_REVISION, revision + 1);
    }
  }

  // Shared with TranslationSettings, hence not private.
  static trimTrailingSlash(value: string): string {
    let url: string = value.trim();
    while (url.length > 0 && url.charAt(url.length - 1) === '/') {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }
}

export const translationStore: TranslationStore = new TranslationStore();
