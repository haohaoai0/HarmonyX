// Per-install X developer configuration. A native OAuth application uses
// PKCE, so only the public Client ID belongs in the app. Never collect or
// store an X Client Secret on a user's device.
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

export class XDeveloperConfig {
  clientId: string = '';

  constructor(clientId: string) {
    this.clientId = clientId;
  }
}

export class OAuthConfigStore {
  private static readonly STORE_NAME: string = 'harmonyx_oauth_config';
  private static readonly CLIENT_ID_KEY: string = 'x_client_id';

  load(context: common.Context): XDeveloperConfig {
    try {
      const options: preferences.Options = { name: OAuthConfigStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      const clientId: string = store.getSync(OAuthConfigStore.CLIENT_ID_KEY, '') as string;
      return new XDeveloperConfig(clientId.trim());
    } catch (error) {
      return new XDeveloperConfig('');
    }
  }

  save(context: common.Context, clientId: string): boolean {
    try {
      const options: preferences.Options = { name: OAuthConfigStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      store.putSync(OAuthConfigStore.CLIENT_ID_KEY, clientId.trim());
      store.flushSync();
      return true;
    } catch (error) {
      return false;
    }
  }
}
