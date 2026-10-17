// Self-hosted gateway configuration.
// The private X surface (cookie session, GraphQL query ids, anti-bot headers)
// lives in the harmonyx-gateway service; the app only needs its address and a
// shared token, so rotating the backend never requires shipping a new HAP.
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

export class GatewaySettings {
  baseUrl: string = '';
  token: string = '';

  constructor(baseUrl: string, token: string) {
    this.baseUrl = baseUrl;
    this.token = token;
  }

  isConfigured(): boolean {
    return this.baseUrl.length > 0 && this.token.length > 0;
  }

  // Trailing slashes would produce "//v1/..." paths on the wire.
  normalizedBaseUrl(): string {
    let url: string = this.baseUrl.trim();
    while (url.length > 0 && url.charAt(url.length - 1) === '/') {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }
}

export class GatewayConfigStore {
  private static readonly STORE_NAME: string = 'harmonyx_gateway';
  private static readonly BASE_URL_KEY: string = 'base_url';
  private static readonly TOKEN_KEY: string = 'gateway_token';

  load(context: common.Context): GatewaySettings {
    try {
      const options: preferences.Options = { name: GatewayConfigStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      const baseUrl: string = store.getSync(GatewayConfigStore.BASE_URL_KEY, '') as string;
      const token: string = store.getSync(GatewayConfigStore.TOKEN_KEY, '') as string;
      return new GatewaySettings(baseUrl.trim(), token.trim());
    } catch (error) {
      return new GatewaySettings('', '');
    }
  }

  save(context: common.Context, settings: GatewaySettings): boolean {
    try {
      const options: preferences.Options = { name: GatewayConfigStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      store.putSync(GatewayConfigStore.BASE_URL_KEY, settings.normalizedBaseUrl());
      store.putSync(GatewayConfigStore.TOKEN_KEY, settings.token.trim());
      store.flushSync();
      return true;
    } catch (error) {
      return false;
    }
  }
}

export const gatewayConfigStore: GatewayConfigStore = new GatewayConfigStore();
