// Cookie session for X's private surface (the same thing the reference client
// keeps in its Room `account` table): auth_token identifies the account, ct0 is
// the CSRF token that must be echoed in the x-csrf-token header.
//
// The cookies themselves live with the account they belong to, so this store is
// a view over AccountStore: reads return the active account's session and
// writes land on the account the capture belongs to.
import { common } from '@kit.AbilityKit';
import hilog from '@ohos.hilog';
import { XAccount, accountStore } from './AccountStore';

const DOMAIN = 0xFF00;
const TAG = 'HarmonyX-XPrivate';

export class XSession {
  accountId: string = '';
  authToken: string = '';
  ct0: string = '';
  // The full cookie string is what the request actually carries; the two named
  // fields above are extracted for validation and the csrf header.
  rawCookie: string = '';
  userId: string = '';
  username: string = '';

  constructor(accountId: string, authToken: string, ct0: string, rawCookie: string, userId: string,
    username: string) {
    this.accountId = accountId;
    this.authToken = authToken;
    this.ct0 = ct0;
    this.rawCookie = rawCookie;
    this.userId = userId;
    this.username = username;
  }

  isUsable(): boolean {
    return this.authToken.length > 0 && this.ct0.length > 0;
  }

  cacheIdentity(): string {
    if (this.accountId.length > 0) {
      return this.accountId;
    }
    if (this.userId.length > 0) {
      return 'u:' + this.userId;
    }
    if (this.authToken.length > 0) {
      return 'cookie:' + this.authToken;
    }
    return 'anonymous';
  }
}

export class XPrivateStore {
  // The cookie session of one account, in the shape the private client uses.
  static sessionOf(account: XAccount): XSession {
    return new XSession(account.id, account.authToken, account.ct0, account.rawCookie,
      account.userId, account.username);
  }

  // Splits "a=1; b=2" into the two cookies this client needs and keeps the
  // whole string for the request header.
  static parseCookieString(raw: string): XSession {
    let authToken: string = '';
    let ct0: string = '';
    const jar: Map<string, string> = XPrivateStore.splitCookies(raw);
    const auth: string | undefined = jar.get('auth_token');
    const csrf: string | undefined = jar.get('ct0');
    if (auth !== undefined) {
      authToken = auth;
    }
    if (csrf !== undefined) {
      ct0 = csrf;
    }
    // x.com keeps the signed-in account id in the twid cookie as "u%3D<id>"
    // (URL-encoded "u=<id>"). Having it locally means notifications and other
    // account-scoped calls work without an OAuth round trip.
    let userId: string = '';
    const twid: string | undefined = jar.get('twid');
    if (twid !== undefined) {
      userId = XPrivateStore.userIdFromTwid(twid);
    }
    return new XSession('', authToken, ct0, raw.trim(), userId, '');
  }

  private static userIdFromTwid(twid: string): string {
    let value: string = twid;
    try {
      value = decodeURIComponent(twid);
    } catch (e) {
      // A malformed cookie simply yields no id.
    }
    if (value.startsWith('u=')) {
      value = value.substring(2);
    }
    let digitsOnly: string = '';
    for (let i: number = 0; i < value.length; i++) {
      const ch: string = value.charAt(i);
      if (ch >= '0' && ch <= '9') {
        digitsOnly += ch;
      }
    }
    return digitsOnly;
  }

  private static splitCookies(raw: string): Map<string, string> {
    const jar: Map<string, string> = new Map();
    const parts: string[] = raw.split(';');
    for (let i: number = 0; i < parts.length; i++) {
      const part: string = parts[i].trim();
      const eq: number = part.indexOf('=');
      if (eq <= 0) {
        continue;
      }
      const name: string = part.substring(0, eq).trim();
      const value: string = part.substring(eq + 1).trim();
      if (name.length > 0 && value.length > 0) {
        jar.set(name, value);
      }
    }
    return jar;
  }

  // Session of the account currently in use.
  load(context: common.Context): XSession {
    const active: XAccount | null = accountStore.active(context);
    if (active === null) {
      return new XSession('', '', '', '', '', '');
    }
    return XPrivateStore.sessionOf(active);
  }

  // Session of one specific account, for callers that switch accounts.
  loadFor(context: common.Context, accountId: string): XSession {
    const account: XAccount | null = accountStore.find(context, accountId);
    if (account === null) {
      return new XSession('', '', '', '', '', '');
    }
    return XPrivateStore.sessionOf(account);
  }

  // Stores a captured cookie session on the account it belongs to and makes it
  // active. `asNewAccount` is the "add account" path: even an unattributed
  // session then becomes its own entry instead of overwriting the one in use.
  save(context: common.Context, session: XSession, asNewAccount: boolean = false): boolean {
    const existing: XAccount | null =
      accountStore.resolve(context, session.userId, session.username, !asNewAccount);
    const target: XAccount = existing !== null ? existing
      : new XAccount(accountStore.newId(session.userId, session.username), session.userId,
        session.username, '', '', '', session.authToken, session.ct0, session.rawCookie, Date.now());
    if (existing !== null) {
      if (session.userId.length > 0) {
        target.userId = session.userId;
      }
      if (session.username.length > 0) {
        target.username = session.username;
      }
      target.authToken = session.authToken;
      target.ct0 = session.ct0;
      target.rawCookie = session.rawCookie;
    }
    const saved: boolean = accountStore.upsert(context, target);
    if (!saved) {
      hilog.error(DOMAIN, TAG, '%{public}s', 'session save failed');
      return false;
    }
    hilog.info(DOMAIN, TAG, '%{public}s', 'private session stored for the active account');
    return true;
  }

  // Drops the cookies of the active account. An account that only ever had a
  // cookie session has nothing left afterwards, so it is removed; one with an
  // OAuth token stays in the list.
  clear(context: common.Context): void {
    const active: XAccount | null = accountStore.active(context);
    if (active === null) {
      return;
    }
    if (!active.hasOAuthToken()) {
      accountStore.remove(context, active.id);
      return;
    }
    active.authToken = '';
    active.ct0 = '';
    active.rawCookie = '';
    accountStore.upsert(context, active);
  }
}

export const xPrivateStore: XPrivateStore = new XPrivateStore();
