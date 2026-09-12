// Persistent sign-in state for Harmony X, backed by @ohos.data.preferences.
// OAuth is the only auth method: this holds the X OAuth 2.0 access token
// plus the resolved user id / handle. Empty token = signed out (the
// timeline still shows sample posts so the app works with zero setup).
import preferences from '@ohos.data.preferences';
import hilog from '@ohos.hilog';
import common from '@ohos.app.ability.common';

const DOMAIN = 0xFF00;
const TAG = 'HarmonyX-AuthStore';
const STORE_NAME = 'harmony_x_auth';
const KEY_TOKEN = 'access_token';
const KEY_USER_ID = 'user_id';
const KEY_USERNAME = 'username';

export class AuthStore {
  private token: string = '';
  private userId: string = '';
  private username: string = '';
  private loaded: boolean = false;

  async load(ctx: common.UIAbilityContext): Promise<void> {
    try {
      const prefs: preferences.Preferences = await preferences.getPreferences(ctx, STORE_NAME);
      const t: preferences.ValueType = await prefs.get(KEY_TOKEN, '');
      const u: preferences.ValueType = await prefs.get(KEY_USER_ID, '');
      const n: preferences.ValueType = await prefs.get(KEY_USERNAME, '');
      this.token = String(t);
      this.userId = String(u);
      this.username = String(n);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'load failed: %{public}s', JSON.stringify(e));
    }
    this.loaded = true;
  }

  isLoaded(): boolean {
    return this.loaded;
  }

  isSignedIn(): boolean {
    return this.token.length > 0;
  }

  getToken(): string {
    return this.token;
  }

  getUserId(): string {
    return this.userId;
  }

  getUsername(): string {
    return this.username;
  }

  async saveToken(ctx: common.UIAbilityContext, token: string, userId: string, username: string): Promise<void> {
    this.token = token.trim();
    this.userId = userId;
    this.username = username;
    await this.persist(ctx);
  }

  async signOut(ctx: common.UIAbilityContext): Promise<void> {
    this.token = '';
    this.userId = '';
    this.username = '';
    await this.persist(ctx);
  }

  private async persist(ctx: common.UIAbilityContext): Promise<void> {
    try {
      const prefs: preferences.Preferences = await preferences.getPreferences(ctx, STORE_NAME);
      await prefs.put(KEY_TOKEN, this.token);
      await prefs.put(KEY_USER_ID, this.userId);
      await prefs.put(KEY_USERNAME, this.username);
      await prefs.flush();
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'persist failed: %{public}s', JSON.stringify(e));
    }
  }
}

export const authStore: AuthStore = new AuthStore();
