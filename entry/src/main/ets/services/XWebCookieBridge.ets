// Synchronizes the app's per-account X cookie session back into ArkWeb's
// global cookie jar so in-app x.com pages open as the active account.
import webview from '@ohos.web.webview';
import hilog from '@ohos.hilog';
import { common } from '@kit.AbilityKit';
import { XAccount, accountStore } from './AccountStore';

const DOMAIN = 0xFF00;
const TAG = 'HarmonyX-WebCookie';
const X_COOKIE_URL: string = 'https://x.com/';
const X_COOKIE_SUFFIX: string = '; Domain=.x.com; Path=/; Secure; SameSite=None';
const X_HTTP_ONLY_SUFFIX: string = X_COOKIE_SUFFIX + '; HttpOnly';

class CookiePair {
  name: string = '';
  value: string = '';

  constructor(name: string, value: string) {
    this.name = name;
    this.value = value;
  }
}

// One origin whose cookies are carried across a blank-slate X login.
class SavedOriginCookies {
  url: string = '';
  cookie: string = '';

  constructor(url: string, cookie: string) {
    this.url = url;
    this.cookie = cookie;
  }
}

export class XWebCookieBridge {
  // Origins the app's own web surfaces own: Grok web mode and its xAI sign-in.
  // A fresh X login must not sign the reader out of them, because ArkWeb's
  // cookie jar is shared by every Web component in the process.
  private static readonly PRESERVED_ORIGINS: string[] = [
    'https://grok.com/',
    'https://x.ai/',
    'https://accounts.x.ai/'
  ];

  // Replaces the old "clearAllCookies" step before an account is added: the jar
  // still ends up without any x.com session, so X asks for another account, but
  // the third-party logins kept by the same jar survive.
  async beginFreshXSession(): Promise<void> {
    const saved: SavedOriginCookies[] = await this.capturePreserved();
    try {
      await webview.WebCookieManager.clearAllCookies();
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'cookie jar could not be cleared: %{public}s',
        JSON.stringify(error));
    }
    this.restorePreserved(saved);
  }

  private async capturePreserved(): Promise<SavedOriginCookies[]> {
    const saved: SavedOriginCookies[] = [];
    for (let i: number = 0; i < XWebCookieBridge.PRESERVED_ORIGINS.length; i++) {
      const url: string = XWebCookieBridge.PRESERVED_ORIGINS[i];
      try {
        const cookie: string = await webview.WebCookieManager.fetchCookie(url);
        if (cookie.length > 0) {
          saved.push(new SavedOriginCookies(url, cookie));
        }
      } catch (error) {
        // Nothing to carry over for that origin; the login step below still
        // has to run.
      }
    }
    return saved;
  }

  private restorePreserved(saved: SavedOriginCookies[]): void {
    let wrote: boolean = false;
    for (let i: number = 0; i < saved.length; i++) {
      const entry: SavedOriginCookies = saved[i];
      const pairs: CookiePair[] = this.splitRawCookie(entry.cookie);
      for (let j: number = 0; j < pairs.length; j++) {
        const pair: CookiePair = pairs[j];
        try {
          // Host-scoped on the origin that produced it, which is where the
          // login was valid; SameSite=None keeps the SSO round trip working.
          webview.WebCookieManager.configCookieSync(entry.url,
            pair.name + '=' + pair.value + '; Path=/; Secure; SameSite=None',
            false, true);
          wrote = true;
        } catch (error) {
          hilog.warn(DOMAIN, TAG, 'cookie restore failed for %{public}s: %{public}s',
            pair.name, JSON.stringify(error));
        }
      }
    }
    if (wrote) {
      webview.WebCookieManager.saveCookieAsync().then((): void => {
      }).catch((): void => {
      });
    }
  }

  syncActive(context: common.Context): boolean {
    const active: XAccount | null = accountStore.active(context);
    if (active === null) {
      return false;
    }
    return this.syncAccount(active);
  }

  syncAccountId(context: common.Context, accountId: string): boolean {
    if (accountId.length === 0) {
      return this.syncActive(context);
    }
    const account: XAccount | null = accountStore.find(context, accountId);
    if (account === null) {
      return false;
    }
    return this.syncAccount(account);
  }

  syncAccount(account: XAccount): boolean {
    const pairs: CookiePair[] = this.cookiePairs(account);
    if (pairs.length === 0) {
      return false;
    }
    let wrote: boolean = false;
    for (let i: number = 0; i < pairs.length; i++) {
      const pair: CookiePair = pairs[i];
      const suffix: string = pair.name === 'auth_token' ? X_HTTP_ONLY_SUFFIX : X_COOKIE_SUFFIX;
      try {
        webview.WebCookieManager.configCookieSync(X_COOKIE_URL, pair.name + '=' + pair.value + suffix,
          false, true);
        wrote = true;
      } catch (error) {
        hilog.warn(DOMAIN, TAG, 'cookie sync failed for %{public}s: %{public}s',
          pair.name, JSON.stringify(error));
      }
    }
    if (wrote) {
      webview.WebCookieManager.saveCookieAsync().then((): void => {
      }).catch((): void => {
      });
    }
    return wrote;
  }

  private cookiePairs(account: XAccount): CookiePair[] {
    const out: CookiePair[] = [];
    this.pushPair(out, 'auth_token', account.authToken);
    this.pushPair(out, 'ct0', account.ct0);
    if (account.userId.length > 0) {
      this.pushPair(out, 'twid', 'u%3D' + account.userId);
    }
    const rawPairs: CookiePair[] = this.splitRawCookie(account.rawCookie);
    for (let i: number = 0; i < rawPairs.length; i++) {
      this.pushPair(out, rawPairs[i].name, rawPairs[i].value);
    }
    return this.uniqueByName(out);
  }

  private splitRawCookie(raw: string): CookiePair[] {
    const out: CookiePair[] = [];
    const parts: string[] = raw.split(';');
    for (let i: number = 0; i < parts.length; i++) {
      const part: string = parts[i].trim();
      const eq: number = part.indexOf('=');
      if (eq <= 0) {
        continue;
      }
      const name: string = part.substring(0, eq).trim();
      const value: string = part.substring(eq + 1).trim();
      this.pushPair(out, name, value);
    }
    return out;
  }

  private pushPair(out: CookiePair[], name: string, value: string): void {
    const cleanName: string = name.trim();
    const cleanValue: string = value.trim();
    if (cleanName.length === 0 || cleanValue.length === 0) {
      return;
    }
    out.push(new CookiePair(cleanName, cleanValue));
  }

  private uniqueByName(pairs: CookiePair[]): CookiePair[] {
    const out: CookiePair[] = [];
    for (let i: number = 0; i < pairs.length; i++) {
      const pair: CookiePair = pairs[i];
      let replaced: boolean = false;
      for (let j: number = 0; j < out.length; j++) {
        if (out[j].name === pair.name) {
          out[j] = pair;
          replaced = true;
        }
      }
      if (!replaced) {
        out.push(pair);
      }
    }
    return out;
  }
}

export const xWebCookieBridge: XWebCookieBridge = new XWebCookieBridge();
