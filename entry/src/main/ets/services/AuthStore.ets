// Signed-in state of the *active* account, backed by the multi-account store.
//
// AccountStore owns the list; this facade answers the questions the rest of the
// app already asks ("is the OAuth token present?", "which user id do I send?")
// and forwards sign-in/sign-out to that list. OAuth is only one half of a
// session: a cookie-only account is tracked separately by XPrivateStore, and
// the timeline still shows sample posts while nothing is signed in.
import hilog from '@ohos.hilog';
import { common } from '@kit.AbilityKit';
import { XAccount, accountStore } from './AccountStore';

const DOMAIN = 0xFF00;
const TAG = 'HarmonyX-AuthStore';

export class AuthStore {
  private token: string = '';
  private userId: string = '';
  private username: string = '';
  private loaded: boolean = false;

  async load(ctx: common.UIAbilityContext): Promise<void> {
    const active: XAccount | null = accountStore.active(ctx);
    if (active === null) {
      this.token = '';
      this.userId = '';
      this.username = '';
    } else {
      this.token = active.accessToken;
      this.userId = active.userId;
      this.username = active.username;
    }
    this.loaded = true;
  }

  isLoaded(): boolean {
    return this.loaded;
  }

  // True for the OAuth path only. A cookie-only account signs in through the
  // private interface, which is what XPrivateStore reports.
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

  // Writes the OAuth credential onto the account it belongs to, creating one
  // when this identity has not been seen before.
  async saveToken(ctx: common.UIAbilityContext, token: string, userId: string,
    username: string): Promise<void> {
    const trimmed: string = token.trim();
    const existing: XAccount | null = accountStore.resolve(ctx, userId, username);
    const target: XAccount = existing !== null ? existing
      : new XAccount(accountStore.newId(userId, username), userId, username, '', '',
        trimmed, '', '', '', Date.now());
    if (existing !== null) {
      target.accessToken = trimmed;
      if (userId.length > 0) {
        target.userId = userId;
      }
      if (username.length > 0) {
        target.username = username;
      }
    }
    const saved: boolean = accountStore.upsert(ctx, target);
    if (!saved) {
      hilog.error(DOMAIN, TAG, '%{public}s', 'unable to persist the OAuth token');
    }
    await this.load(ctx);
  }

  // Signs out of the account in use by removing it. Any other account stays
  // signed in and takes over; the returned count lets the caller decide whether
  // the app is now signed out entirely.
  async signOut(ctx: common.UIAbilityContext): Promise<number> {
    const active: XAccount | null = accountStore.active(ctx);
    if (active !== null) {
      accountStore.remove(ctx, active.id);
    }
    await this.load(ctx);
    return accountStore.list(ctx).length;
  }
}

export const authStore: AuthStore = new AuthStore();
