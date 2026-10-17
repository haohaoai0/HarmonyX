// Login persistence for the web surfaces the app owns itself.
//
// ArkWeb keeps one cookie jar for the whole process and writes it out on a
// timer, but a third-party page's own login (grok.com in Grok web mode) has no
// stored session to re-inject the way X does through XWebCookieBridge, so the
// reader is asked to sign in again after the jar is dropped. The cookies of
// those origins are therefore kept in the app's own preferences and put back
// before the page loads.
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import webview from '@ohos.web.webview';
import hilog from '@ohos.hilog';

const DOMAIN = 0xFF00;
const TAG = 'HarmonyX-WebSession';
const STORE_NAME: string = 'harmonyx_web_session';
const COOKIES_KEY: string = 'origins';
const ORIGIN_SEPARATOR: string = '\n';
const FIELD_SEPARATOR: string = '\t';

// Grok uses these first-party hosts during its own sign-in flow. Keeping the
// list here lets both the destination and the ability lifecycle use the exact
// same session scope.
export const GROK_WEB_SESSION_ORIGINS: string[] = [
  'https://grok.com/',
  'https://x.ai/',
  'https://accounts.x.ai/'
];

class CookiePair {
  name: string = '';
  value: string = '';

  constructor(name: string, value: string) {
    this.name = name;
    this.value = value;
  }
}

class OriginCookies {
  url: string = '';
  cookie: string = '';

  constructor(url: string, cookie: string) {
    this.url = url;
    this.cookie = cookie;
  }
}

export class WebSessionStore {
  // Puts the stored cookies of every origin back into the jar. Called before a
  // Web component is created, so the first request already carries them.
  async restore(context: common.Context, origins: string[]): Promise<void> {
    const stored: OriginCookies[] = this.load(context, origins);
    if (stored.length === 0) {
      return;
    }
    let wrote: boolean = false;
    for (let i: number = 0; i < stored.length; i++) {
      const entry: OriginCookies = stored[i];
      const pairs: CookiePair[] = this.split(entry.cookie);
      for (let j: number = 0; j < pairs.length; j++) {
        try {
          // Host-scoped on the origin that produced the value; SameSite=None
          // keeps the sign-in round trip between the page and its SSO host.
          webview.WebCookieManager.configCookieSync(entry.url,
            pairs[j].name + '=' + pairs[j].value + '; Path=/; Secure; SameSite=None',
            false, true);
          wrote = true;
        } catch (error) {
          hilog.warn(DOMAIN, TAG, 'restore failed for %{public}s: %{public}s',
            pairs[j].name, JSON.stringify(error));
        }
      }
    }
    if (wrote) {
      try {
        // configCookieSync updates the manager immediately, but the Web
        // renderer can otherwise start its first request before that update is
        // committed. Do not create the Web surface until this has resolved.
        await webview.WebCookieManager.saveCookieAsync();
      } catch (error) {
        hilog.warn(DOMAIN, TAG, 'cookie restore save failed: %{public}s', JSON.stringify(error));
      }
    }
  }

  // Web sign-in can finish without a document navigation, so onPageEnd alone
  // is not a reliable persistence boundary. Call this when the surface leaves
  // or the ability moves to background to commit ArkWeb's jar and refresh the
  // app-owned recovery copy from the current in-memory session.
  async persist(context: common.Context, origins: string[]): Promise<void> {
    try {
      await webview.WebCookieManager.saveCookieAsync();
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'ArkWeb cookie save failed: %{public}s', JSON.stringify(error));
    }
    await this.capture(context, origins);
  }

  // Reads the current cookies of those origins back into the store. HttpOnly
  // cookies the engine withholds simply cannot be carried over, which is a Web
  // engine limit rather than a choice made here.
  async capture(context: common.Context, origins: string[]): Promise<void> {
    const captured: OriginCookies[] = [];
    for (let i: number = 0; i < origins.length; i++) {
      try {
        const cookie: string = await webview.WebCookieManager.fetchCookie(origins[i]);
        if (cookie.length > 0) {
          captured.push(new OriginCookies(origins[i], cookie));
        }
      } catch (error) {
        // An origin that cannot be read keeps whatever was stored earlier.
      }
    }
    if (captured.length === 0) {
      return;
    }
    this.save(context, captured);
  }

  private encode(entries: OriginCookies[]): string {
    let text: string = '';
    for (let i: number = 0; i < entries.length; i++) {
      if (i > 0) {
        text += ORIGIN_SEPARATOR;
      }
      text += encodeURIComponent(entries[i].url) + FIELD_SEPARATOR +
        encodeURIComponent(entries[i].cookie);
    }
    return text;
  }

  private save(context: common.Context, entries: OriginCookies[]): boolean {
    try {
      const options: preferences.Options = { name: STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      store.putSync(COOKIES_KEY, this.encode(entries));
      store.flushSync();
      return true;
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'session store write failed: %{public}s', JSON.stringify(error));
      return false;
    }
  }

  private load(context: common.Context, origins: string[]): OriginCookies[] {
    let raw: string = '';
    try {
      const options: preferences.Options = { name: STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      raw = String(store.getSync(COOKIES_KEY, ''));
    } catch (error) {
      return [];
    }
    const out: OriginCookies[] = [];
    if (raw.length === 0) {
      return out;
    }
    const lines: string[] = raw.split(ORIGIN_SEPARATOR);
    for (let i: number = 0; i < lines.length; i++) {
      const fields: string[] = lines[i].split(FIELD_SEPARATOR);
      if (fields.length < 2) {
        continue;
      }
      const url: string = decodeURIComponent(fields[0]);
      // Only origins this surface asked for are restored, so a page cannot
      // receive cookies that belong to another one.
      if (origins.indexOf(url) < 0) {
        continue;
      }
      out.push(new OriginCookies(url, decodeURIComponent(fields[1])));
    }
    return out;
  }

  private split(cookie: string): CookiePair[] {
    const out: CookiePair[] = [];
    const parts: string[] = cookie.split(';');
    for (let i: number = 0; i < parts.length; i++) {
      const part: string = parts[i].trim();
      const eq: number = part.indexOf('=');
      if (eq <= 0) {
        continue;
      }
      const name: string = part.substring(0, eq).trim();
      const value: string = part.substring(eq + 1).trim();
      if (name.length === 0 || value.length === 0) {
        continue;
      }
      out.push(new CookiePair(name, value));
    }
    return out;
  }
}

export const webSessionStore: WebSessionStore = new WebSessionStore();
