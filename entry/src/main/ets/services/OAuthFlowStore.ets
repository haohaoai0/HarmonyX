// Short-lived OAuth transaction state. The PKCE verifier and state must
// survive the trip through the system browser, but never leave this app's
// private preferences storage.
import preferences from '@ohos.data.preferences';
import hilog from '@ohos.hilog';
import common from '@ohos.app.ability.common';

const DOMAIN = 0xFF00;
const TAG = 'HarmonyX-OAuthFlow';
const STORE_NAME = 'harmony_x_oauth_flow';
const KEY_VERIFIER = 'verifier';
const KEY_STATE = 'state';
const KEY_CLIENT_ID = 'client_id';
const KEY_CALLBACK_URI = 'callback_uri';

export interface OAuthPendingTransaction {
  verifier: string;
  state: string;
  clientId: string;
}

export class OAuthFlowStore {
  async save(ctx: common.UIAbilityContext, verifier: string, state: string, clientId: string): Promise<boolean> {
    try {
      const prefs: preferences.Preferences = await preferences.getPreferences(ctx, STORE_NAME);
      await prefs.put(KEY_VERIFIER, verifier);
      await prefs.put(KEY_STATE, state);
      await prefs.put(KEY_CLIENT_ID, clientId);
      await prefs.put(KEY_CALLBACK_URI, '');
      await prefs.flush();
      return true;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'save failed: %{public}s', JSON.stringify(e));
      return false;
    }
  }

  async load(ctx: common.UIAbilityContext): Promise<OAuthPendingTransaction> {
    let verifier: string = '';
    let state: string = '';
    let clientId: string = '';
    try {
      const prefs: preferences.Preferences = await preferences.getPreferences(ctx, STORE_NAME);
      const savedVerifier: preferences.ValueType = await prefs.get(KEY_VERIFIER, '');
      const savedState: preferences.ValueType = await prefs.get(KEY_STATE, '');
      const savedClientId: preferences.ValueType = await prefs.get(KEY_CLIENT_ID, '');
      verifier = String(savedVerifier);
      state = String(savedState);
      clientId = String(savedClientId);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'load failed: %{public}s', JSON.stringify(e));
    }
    return { verifier: verifier, state: state, clientId: clientId };
  }

  async clear(ctx: common.UIAbilityContext): Promise<void> {
    try {
      const prefs: preferences.Preferences = await preferences.getPreferences(ctx, STORE_NAME);
      await prefs.put(KEY_VERIFIER, '');
      await prefs.put(KEY_STATE, '');
      await prefs.put(KEY_CLIENT_ID, '');
      await prefs.put(KEY_CALLBACK_URI, '');
      await prefs.flush();
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'clear failed: %{public}s', JSON.stringify(e));
    }
  }

  async saveCallback(ctx: common.UIAbilityContext, callbackUri: string): Promise<boolean> {
    try {
      const prefs: preferences.Preferences = await preferences.getPreferences(ctx, STORE_NAME);
      await prefs.put(KEY_CALLBACK_URI, callbackUri);
      await prefs.flush();
      return true;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'save callback failed: %{public}s', JSON.stringify(e));
      return false;
    }
  }

  async takeCallback(ctx: common.UIAbilityContext): Promise<string> {
    let callbackUri: string = '';
    try {
      const prefs: preferences.Preferences = await preferences.getPreferences(ctx, STORE_NAME);
      const savedCallback: preferences.ValueType = await prefs.get(KEY_CALLBACK_URI, '');
      callbackUri = String(savedCallback);
      await prefs.put(KEY_CALLBACK_URI, '');
      await prefs.flush();
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'take callback failed: %{public}s', JSON.stringify(e));
    }
    return callbackUri;
  }
}

export const oauthFlowStore: OAuthFlowStore = new OAuthFlowStore();
