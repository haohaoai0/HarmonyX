// Grok configuration is deliberately independent from translation. It owns
// both the consumer-web preference and the optional xAI API credentials.
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { TRANSLATION_MODE_API } from '../models/Translation';
import { TranslationSettings, translationStore } from './TranslationStore';

export const GROK_MODE_WEB: string = 'web';
export const GROK_MODE_API: string = 'api';
export const DEFAULT_GROK_MODE: string = GROK_MODE_WEB;
export const DEFAULT_GROK_MODEL: string = 'grok-4-1-fast';
export const DEFAULT_GROK_BASE_URL: string = 'https://api.x.ai/v1';
export const STORAGE_KEY_GROK_MODE: string = 'harmonyx.grok_mode';

export class GrokSettings {
  mode: string = DEFAULT_GROK_MODE;
  apiKey: string = '';
  model: string = DEFAULT_GROK_MODEL;
  baseUrl: string = DEFAULT_GROK_BASE_URL;
  useXWebSession: boolean = true;

  constructor(mode: string, apiKey: string, model: string, baseUrl: string, useXWebSession: boolean) {
    this.mode = mode === GROK_MODE_API ? GROK_MODE_API : GROK_MODE_WEB;
    this.apiKey = apiKey.trim();
    this.model = model.trim().length > 0 ? model.trim() : DEFAULT_GROK_MODEL;
    this.baseUrl = this.normalizeBaseUrl(baseUrl);
    this.useXWebSession = useXWebSession;
  }

  isApiReady(): boolean {
    return this.apiKey.length > 0 && this.model.length > 0 && this.baseUrl.length > 0;
  }

  effectiveBaseUrl(): string {
    return this.baseUrl;
  }

  effectiveModel(): string {
    return this.model;
  }

  private normalizeBaseUrl(value: string): string {
    let url: string = value.trim();
    if (url.length === 0) {
      return DEFAULT_GROK_BASE_URL;
    }
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }
}

export class GrokSettingsStore {
  private static readonly STORE_NAME: string = 'harmonyx_grok';
  private static readonly MODE_KEY: string = 'open_mode';
  private static readonly API_KEY_KEY: string = 'api_key';
  private static readonly MODEL_KEY: string = 'model';
  private static readonly BASE_URL_KEY: string = 'base_url';
  private static readonly X_WEB_SESSION_KEY: string = 'use_x_web_session';

  load(context: common.Context): GrokSettings {
    try {
      const options: preferences.Options = { name: GrokSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      const storedMode: string = String(store.getSync(GrokSettingsStore.MODE_KEY, ''));
      if (storedMode.length === 0) {
        return this.legacySettings(context);
      }
      const mode: string = this.normalize(storedMode);
      const apiKey: string = String(store.getSync(GrokSettingsStore.API_KEY_KEY, ''));
      const model: string = String(store.getSync(GrokSettingsStore.MODEL_KEY, DEFAULT_GROK_MODEL));
      const baseUrl: string = String(store.getSync(GrokSettingsStore.BASE_URL_KEY, DEFAULT_GROK_BASE_URL));
      const useXWebSession: boolean = String(store.getSync(GrokSettingsStore.X_WEB_SESSION_KEY, 'true')) !== 'false';
      if (apiKey.length === 0) {
        const legacy: GrokSettings = this.legacySettings(context);
        if (legacy.apiKey.length > 0) {
          return new GrokSettings(mode, legacy.apiKey, legacy.effectiveModel(), legacy.effectiveBaseUrl(),
            useXWebSession);
        }
      }
      return new GrokSettings(mode, apiKey, model, baseUrl, useXWebSession);
    } catch (error) {
      return new GrokSettings(DEFAULT_GROK_MODE, '', DEFAULT_GROK_MODEL, DEFAULT_GROK_BASE_URL, true);
    }
  }

  save(context: common.Context, settings: GrokSettings): boolean {
    try {
      const options: preferences.Options = { name: GrokSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      store.putSync(GrokSettingsStore.MODE_KEY, this.normalize(settings.mode));
      store.putSync(GrokSettingsStore.API_KEY_KEY, settings.apiKey);
      store.putSync(GrokSettingsStore.MODEL_KEY, settings.effectiveModel());
      store.putSync(GrokSettingsStore.BASE_URL_KEY, settings.effectiveBaseUrl());
      store.putSync(GrokSettingsStore.X_WEB_SESSION_KEY, settings.useXWebSession ? 'true' : 'false');
      store.flushSync();
      return true;
    } catch (error) {
      return false;
    }
  }

  private normalize(mode: string): string {
    return mode === GROK_MODE_API ? GROK_MODE_API : GROK_MODE_WEB;
  }

  // Existing installs briefly stored xAI data under translation settings.
  // Read it once so an API key is never discarded, but keep future Grok
  // changes entirely outside the translation screen.
  private legacySettings(context: common.Context): GrokSettings {
    const legacy: TranslationSettings = translationStore.load(context);
    if (legacy.mode === TRANSLATION_MODE_API && legacy.providerId === 'grok') {
      return new GrokSettings(GROK_MODE_API, legacy.apiKey, legacy.effectiveModel(),
        legacy.effectiveBaseUrl(), true);
    }
    return new GrokSettings(DEFAULT_GROK_MODE, '', DEFAULT_GROK_MODEL, DEFAULT_GROK_BASE_URL, true);
  }
}

export const grokSettingsStore: GrokSettingsStore = new GrokSettingsStore();
