// Multi-account storage for Harmony X.
//
// One entry owns a complete credential pair: the x.com cookie session the
// private GraphQL/REST layer authenticates with, plus the OAuth 2.0 access
// token when the developer-API path was used. Keeping both per account is what
// makes switching instant — the other account keeps its session and never has
// to sign in again. Everything stays in this app's private preferences.
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import hilog from '@ohos.hilog';

const DOMAIN = 0xFF00;
const TAG = 'HarmonyX-Accounts';

// Bumped whenever the account list or the active account changes, so the root
// page can reload instead of polling preferences.
export const STORAGE_KEY_ACCOUNTS_CHANGED: string = 'harmonyx.accounts_changed';

// Single-account stores written by earlier builds. Read once so an existing
// sign-in survives the upgrade instead of asking the user to log in again.
const LEGACY_AUTH_STORE: string = 'harmony_x_auth';
const LEGACY_SESSION_STORE: string = 'harmonyx_x_session';
const LEGACY_TOKEN_KEY: string = 'access_token';
const LEGACY_AUTH_TOKEN_KEY: string = 'auth_token';
const LEGACY_CT0_KEY: string = 'ct0';
const LEGACY_COOKIE_KEY: string = 'raw_cookie';
const LEGACY_USER_ID_KEY: string = 'user_id';
const LEGACY_USERNAME_KEY: string = 'username';

// Shape of one persisted account. Every field is optional because the JSON
// comes from preferences and may predate a field.
class XAccountRecord {
  id?: string;
  userId?: string;
  username?: string;
  displayName?: string;
  avatarUrl?: string;
  verifiedType?: string;
  avatarShape?: string;
  accessToken?: string;
  authToken?: string;
  ct0?: string;
  rawCookie?: string;
  addedAt?: number;
}

export class XAccount {
  id: string = '';
  userId: string = '';
  username: string = '';
  displayName: string = '';
  avatarUrl: string = '';
  verifiedType: string = '';
  avatarShape: string = '';
  accessToken: string = '';
  authToken: string = '';
  ct0: string = '';
  rawCookie: string = '';
  addedAt: number = 0;

  constructor(id: string, userId: string, username: string, displayName: string, avatarUrl: string,
    accessToken: string, authToken: string, ct0: string, rawCookie: string, addedAt: number) {
    this.id = id;
    this.userId = userId;
    this.username = username;
    this.displayName = displayName;
    this.avatarUrl = avatarUrl;
    this.accessToken = accessToken;
    this.authToken = authToken;
    this.ct0 = ct0;
    this.rawCookie = rawCookie;
    this.addedAt = addedAt;
  }

  // The cookie pair is the credential the private interface needs.
  hasCookieSession(): boolean {
    return this.authToken.length > 0 && this.ct0.length > 0;
  }

  hasOAuthToken(): boolean {
    return this.accessToken.length > 0;
  }

  isUsable(): boolean {
    return this.hasCookieSession() || this.hasOAuthToken();
  }

  handle(): string {
    return this.username.length > 0 ? '@' + this.username : '';
  }

  // Preferred label for list rows and toasts.
  title(): string {
    if (this.displayName.length > 0) {
      return this.displayName;
    }
    if (this.username.length > 0) {
      return '@' + this.username;
    }
    if (this.userId.length > 0) {
      return this.userId;
    }
    return this.id;
  }

  initial(): string {
    const source: string = this.displayName.length > 0 ? this.displayName : this.username;
    return source.length > 0 ? source.substring(0, 1).toUpperCase() : 'X';
  }
}

export class AccountStore {
  private static readonly STORE_NAME: string = 'harmonyx_accounts';
  private static readonly ACCOUNTS_KEY: string = 'accounts';
  private static readonly ACTIVE_KEY: string = 'active_id';
  private static readonly SCHEMA_KEY: string = 'schema';
  private static readonly SCHEMA_VERSION: string = '2';

  // ---- reads --------------------------------------------------------------

  list(context: common.Context): XAccount[] {
    try {
      const store: preferences.Preferences | null = AccountStore.store(context);
      if (store === null) {
        return [];
      }
      const stored: XAccount[] = AccountStore.decode(store.getSync(AccountStore.ACCOUNTS_KEY, '') as string);
      if (stored.length > 0) {
        return stored;
      }
      const schema: string = String(store.getSync(AccountStore.SCHEMA_KEY, ''));
      if (schema === AccountStore.SCHEMA_VERSION) {
        return [];
      }
      // First run after the multi-account upgrade: fold the single account the
      // previous build kept (if any) into the new list. The marker makes this
      // a one-time migration even when nothing was signed in.
      const migrated: XAccount[] = AccountStore.migrateLegacy(context);
      store.putSync(AccountStore.SCHEMA_KEY, AccountStore.SCHEMA_VERSION);
      if (migrated.length > 0) {
        store.putSync(AccountStore.ACCOUNTS_KEY, AccountStore.encode(migrated));
        store.putSync(AccountStore.ACTIVE_KEY, migrated[0].id);
      }
      store.flushSync();
      return migrated;
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'list failed: %{public}s', JSON.stringify(error));
      return [];
    }
  }

  activeId(context: common.Context): string {
    const accounts: XAccount[] = this.list(context);
    if (accounts.length === 0) {
      return '';
    }
    const stored: string = AccountStore.storedActiveId(context);
    for (let i: number = 0; i < accounts.length; i++) {
      if (accounts[i].id === stored) {
        return stored;
      }
    }
    return accounts[0].id;
  }

  active(context: common.Context): XAccount | null {
    const accounts: XAccount[] = this.list(context);
    if (accounts.length === 0) {
      return null;
    }
    const id: string = this.activeId(context);
    for (let i: number = 0; i < accounts.length; i++) {
      if (accounts[i].id === id) {
        return accounts[i];
      }
    }
    return accounts[0];
  }

  find(context: common.Context, id: string): XAccount | null {
    const accounts: XAccount[] = this.list(context);
    for (let i: number = 0; i < accounts.length; i++) {
      if (accounts[i].id === id) {
        return accounts[i];
      }
    }
    return null;
  }

  // Exact identity match: the user id first, then the handle.
  match(context: common.Context, userId: string, username: string): XAccount | null {
    const accounts: XAccount[] = this.list(context);
    const wantedHandle: string = username.trim().toLowerCase();
    if (userId.length === 0 && wantedHandle.length === 0) {
      return null;
    }
    for (let i: number = 0; i < accounts.length; i++) {
      const account: XAccount = accounts[i];
      if (userId.length > 0 && account.userId === userId) {
        return account;
      }
      if (wantedHandle.length > 0 && account.username.toLowerCase() === wantedHandle) {
        return account;
      }
    }
    return null;
  }

  // Cookie-only sign-in can occasionally hide twid/userId from fetchCookie.
  // The auth_token still identifies the X account, so use it to avoid adding
  // the same web session as a second local account.
  matchSession(context: common.Context, authToken: string, ct0: string): XAccount | null {
    const wantedAuth: string = authToken.trim();
    const wantedCt0: string = ct0.trim();
    if (wantedAuth.length === 0 && wantedCt0.length === 0) {
      return null;
    }
    const accounts: XAccount[] = this.list(context);
    for (let i: number = 0; i < accounts.length; i++) {
      const account: XAccount = accounts[i];
      if (wantedAuth.length > 0 && account.authToken === wantedAuth) {
        return account;
      }
      if (wantedAuth.length === 0 && wantedCt0.length > 0 && account.ct0 === wantedCt0) {
        return account;
      }
    }
    return null;
  }

  // Which account a freshly captured credential belongs to. An exact match
  // wins; otherwise a placeholder left by a cookie-only sign-in (no identity
  // yet) is adopted instead of leaving a duplicate behind. A null result means
  // "this is a new account".
  resolve(context: common.Context, userId: string, username: string,
    allowActiveFallback: boolean = true): XAccount | null {
    const exact: XAccount | null = this.match(context, userId, username);
    if (exact !== null) {
      return exact;
    }
    if (!allowActiveFallback) {
      return null;
    }
    const active: XAccount | null = this.active(context);
    if (active === null) {
      return null;
    }
    if (userId.length === 0 && username.trim().length === 0) {
      return active;
    }
    return active.userId.length === 0 && active.username.length === 0 ? active : null;
  }

  // Stable id for a brand new account: the X user id when the flow supplied
  // one, else the handle, else a timestamp so two anonymous sessions never
  // collide.
  newId(userId: string, username: string): string {
    if (userId.trim().length > 0) {
      return 'u:' + userId.trim();
    }
    const handle: string = username.trim().toLowerCase();
    if (handle.length > 0) {
      return 'h:' + handle;
    }
    return 'l:' + Date.now().toString();
  }

  // ---- writes -------------------------------------------------------------

  // Inserts or updates one account and makes it the active one.
  upsert(context: common.Context, account: XAccount): boolean {
    if (!account.isUsable()) {
      return false;
    }
    const accounts: XAccount[] = this.list(context);
    const next: XAccount[] = [];
    let replaced: boolean = false;
    for (let i: number = 0; i < accounts.length; i++) {
      if (accounts[i].id === account.id) {
        next.push(account);
        replaced = true;
      } else {
        next.push(accounts[i]);
      }
    }
    if (!replaced) {
      if (account.addedAt === 0) {
        account.addedAt = Date.now();
      }
      next.push(account);
    }
    return this.persist(context, next, account.id, true);
  }

  setActive(context: common.Context, id: string): boolean {
    const accounts: XAccount[] = this.list(context);
    for (let i: number = 0; i < accounts.length; i++) {
      if (accounts[i].id === id) {
        return this.persist(context, accounts, id, true);
      }
    }
    return false;
  }

  // Removes one account and hands the active slot to the first remaining one.
  remove(context: common.Context, id: string): boolean {
    const accounts: XAccount[] = this.list(context);
    const next: XAccount[] = [];
    for (let i: number = 0; i < accounts.length; i++) {
      if (accounts[i].id !== id) {
        next.push(accounts[i]);
      }
    }
    if (next.length === accounts.length) {
      return false;
    }
    const active: string = next.length === 0 ? '' : next[0].id;
    return this.persist(context, next, active, true);
  }

  // Profile metadata is cosmetic: it refreshes the drawer label but must not
  // trigger the root page's reload watcher, or loading a profile would loop.
  updateProfile(context: common.Context, id: string, displayName: string, username: string,
    avatarUrl: string, verifiedType: string = '', avatarShape: string = ''): boolean {
    const accounts: XAccount[] = this.list(context);
    let target: XAccount | null = null;
    for (let i: number = 0; i < accounts.length; i++) {
      if (accounts[i].id === id) {
        target = accounts[i];
      }
    }
    if (target === null) {
      return false;
    }
    const name: string = displayName.trim();
    const handle: string = username.trim();
    if (target.displayName === name && target.username === handle && target.avatarUrl === avatarUrl && target.verifiedType === verifiedType && target.avatarShape === avatarShape) {
      return false;
    }
    target.displayName = name;
    if (handle.length > 0) {
      target.username = handle;
    }
    target.avatarUrl = avatarUrl; target.verifiedType = verifiedType; target.avatarShape = avatarShape;
    return this.persist(context, accounts, AccountStore.storedActiveId(context), false);
  }

  // Notifies the UI layer that the account set or the active account changed.
  publish(): void {
    const current: number = AppStorage.get<number>(STORAGE_KEY_ACCOUNTS_CHANGED) ?? 0;
    AppStorage.setOrCreate<number>(STORAGE_KEY_ACCOUNTS_CHANGED, current + 1);
  }

  private persist(context: common.Context, accounts: XAccount[], activeId: string,
    publish: boolean): boolean {
    try {
      const store: preferences.Preferences | null = AccountStore.store(context);
      if (store === null) {
        return false;
      }
      store.putSync(AccountStore.ACCOUNTS_KEY, AccountStore.encode(accounts));
      store.putSync(AccountStore.ACTIVE_KEY, activeId);
      store.putSync(AccountStore.SCHEMA_KEY, AccountStore.SCHEMA_VERSION);
      store.flushSync();
      if (publish) {
        this.publish();
      }
      return true;
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'persist failed: %{public}s', JSON.stringify(error));
      return false;
    }
  }

  // ---- storage helpers ----------------------------------------------------

  private static store(context: common.Context): preferences.Preferences | null {
    try {
      const options: preferences.Options = { name: AccountStore.STORE_NAME };
      return preferences.getPreferencesSync(context, options);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'store unavailable: %{public}s', JSON.stringify(error));
      return null;
    }
  }

  private static storedActiveId(context: common.Context): string {
    try {
      const store: preferences.Preferences | null = AccountStore.store(context);
      if (store === null) {
        return '';
      }
      return String(store.getSync(AccountStore.ACTIVE_KEY, ''));
    } catch (error) {
      return '';
    }
  }

  private static encode(accounts: XAccount[]): string {
    try {
      return JSON.stringify(accounts);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'encode failed: %{public}s', JSON.stringify(error));
      return '';
    }
  }

  // Entries that lost a credential since they were written are dropped, so a
  // half-cleared record can never look like a signed-in account.
  private static decode(raw: string): XAccount[] {
    const out: XAccount[] = [];
    const seenAuthTokens: Set<string> = new Set();
    if (raw.length === 0) {
      return out;
    }
    try {
      const records: XAccountRecord[] = JSON.parse(raw) as XAccountRecord[];
      for (let i: number = 0; i < records.length; i++) {
        const record: XAccountRecord | undefined = records[i];
        if (record === undefined) {
          continue;
        }
        const account: XAccount = new XAccount(record.id ?? '', record.userId ?? '',
          record.username ?? '', record.displayName ?? '', record.avatarUrl ?? '',
          record.accessToken ?? '', record.authToken ?? '', record.ct0 ?? '',
          record.rawCookie ?? '', record.addedAt ?? 0);
        account.verifiedType = record.verifiedType ?? ''; account.avatarShape = record.avatarShape ?? '';
        if (account.id.length > 0 && account.isUsable()) {
          if (account.authToken.length > 0) {
            if (seenAuthTokens.has(account.authToken)) {
              continue;
            }
            seenAuthTokens.add(account.authToken);
          }
          out.push(account);
        }
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'decode failed: %{public}s', JSON.stringify(error));
    }
    return out;
  }

  // The previous release stored exactly one identity across two preference
  // stores; this rebuilds it as a single account record.
  private static migrateLegacy(context: common.Context): XAccount[] {
    let accessToken: string = '';
    let userId: string = '';
    let username: string = '';
    let authToken: string = '';
    let ct0: string = '';
    let rawCookie: string = '';
    try {
      const options: preferences.Options = { name: LEGACY_AUTH_STORE };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      accessToken = String(store.getSync(LEGACY_TOKEN_KEY, '')).trim();
      userId = String(store.getSync(LEGACY_USER_ID_KEY, '')).trim();
      username = String(store.getSync(LEGACY_USERNAME_KEY, '')).trim();
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'legacy auth store unavailable: %{public}s', JSON.stringify(error));
    }
    try {
      const options: preferences.Options = { name: LEGACY_SESSION_STORE };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      authToken = String(store.getSync(LEGACY_AUTH_TOKEN_KEY, '')).trim();
      ct0 = String(store.getSync(LEGACY_CT0_KEY, '')).trim();
      rawCookie = String(store.getSync(LEGACY_COOKIE_KEY, '')).trim();
      if (userId.length === 0) {
        userId = String(store.getSync(LEGACY_USER_ID_KEY, '')).trim();
      }
      if (username.length === 0) {
        username = String(store.getSync(LEGACY_USERNAME_KEY, '')).trim();
      }
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'legacy session store unavailable: %{public}s', JSON.stringify(error));
    }
    const usable: boolean = accessToken.length > 0 || (authToken.length > 0 && ct0.length > 0);
    if (!usable) {
      return [];
    }
    const out: XAccount[] = [];
    out.push(new XAccount('u:' + (userId.length > 0 ? userId : Date.now().toString()),
      userId, username, '', '', accessToken, authToken, ct0, rawCookie, Date.now()));
    hilog.info(DOMAIN, TAG, '%{public}s', 'migrated the single account of the previous release');
    return out;
  }
}

export const accountStore: AccountStore = new AccountStore();
