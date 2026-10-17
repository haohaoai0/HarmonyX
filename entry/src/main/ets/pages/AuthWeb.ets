// Embedded X sign-in browser: loads the OAuth authorize page and
// intercepts the harmonyx://callback redirect carrying the auth code,
// then exchanges it for an access token without leaving the app.
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import webview from '@ohos.web.webview';
import common from '@ohos.app.ability.common';
import { authStore } from '../services/AuthStore';
import { XApiClient, REDIRECT_URI } from '../services/XApiClient';
import { OAuthConfigStore, XDeveloperConfig } from '../services/OAuthConfig';
import { XPrivateStore, XSession, xPrivateStore } from '../services/XPrivateStore';
import { XAccount, accountStore } from '../services/AccountStore';
import { xWebCookieBridge } from '../services/XWebCookieBridge';
import { xUserAgent } from '../services/XUserAgent';
import { WebProxyCredential, proxyStore } from '../services/ProxyStore';
import hilog from '@ohos.hilog';
import { DISPLAY_MODE_DARK, DISPLAY_MODE_LIGHT, DISPLAY_MODE_SYSTEM } from '../services/AppearanceStore';
import { pageSurfaceColor, secondaryButtonSurfaceColor } from '../utils/ThemeColors';

const DOMAIN = 0xFF00;
const TAG = 'HarmonyX-AuthWeb';

@Entry
@Component
struct AuthWeb {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @State authUrl: string = '';
  @State verifier: string = '';
  @State expectedState: string = '';
  // Session mode signs in to x.com directly and only needs the resulting
  // cookies; OAuth mode runs the PKCE authorize flow first.
  @State private sessionMode: boolean = false;
  // "Add account" keeps the other signed-in accounts and stores this capture as
  // a new entry instead of replacing the one in use.
  private addAccount: boolean = false;
  @State busy: boolean = false;
  @State statusText: string = '';
  @StorageLink('harmonyx.accent_color') accentColor: string = '#007DFF';
  // The X sign-in page advertises prefers-color-scheme, so it follows the app's
  // light/dark setting rather than staying bright white at night.
  @StorageLink('harmonyx.display_mode') displayMode: string = DISPLAY_MODE_SYSTEM;
  @StorageProp('harmonyx.dark_surface') private themeDarkSurface: string = '';
  // The window is laid out full screen, so the page owns its own safe area.
  @StorageProp('harmonyx.status_bar_height') statusBarHeight: number =
    AppStorage.get<number>('harmonyx.status_bar_height') ?? 0;
  @StorageProp('harmonyx.navigation_indicator_height') navigationIndicatorHeight: number =
    AppStorage.get<number>('harmonyx.navigation_indicator_height') ?? 0;
  private controller: webview.WebviewController = new webview.WebviewController();
  private api: XApiClient = new XApiClient();
  private configStore: OAuthConfigStore = new OAuthConfigStore();
  private handled: boolean = false;
  // The "sign out of the account in use first" hint is shown once per attempt.
  private addHintShown: boolean = false;
  private pollTimer: number = -1;
  // Standard mobile-browser UA: the default ArkWeb UA looks unfamiliar to
  // X's login risk engine and can contribute to "temporarily limited"
  // flags. This only identifies the renderer, nothing else is spoofed; the
  // device token is the real productModel from deviceInfo.
  private readonly ua: string = xUserAgent.value();

  private text(resource: Resource): string {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    return context.resourceManager.getStringSync(resource);
  }

  private webDarkMode(): WebDarkMode {
    if (this.displayMode === DISPLAY_MODE_DARK) {
      return WebDarkMode.On;
    }
    if (this.displayMode === DISPLAY_MODE_LIGHT) {
      return WebDarkMode.Off;
    }
    return WebDarkMode.Auto;
  }

  // Until the avoid-area callback lands the stored height can be 0; the floor
  // keeps the header off the very top edge either way.
  private topInset(): number {
    return Math.max(this.statusBarHeight, 16);
  }

  aboutToAppear(): void {
    this.statusText = this.text($r('app.string.auth_loading'));
    const params = router.getParams() as Record<string, Object> | undefined;
    if (params !== undefined) {
      this.sessionMode = String(params['mode'] ?? '') === 'session';
      this.addAccount = String(params['addAccount'] ?? '') === '1';
      if (this.sessionMode) {
        this.authUrl = 'https://x.com/i/flow/login';
        this.statusText = this.text($r('app.string.auth_session_waiting'));
      } else {
        this.authUrl = String(params['authUrl'] ?? '');
        this.verifier = String(params['verifier'] ?? '');
        this.expectedState = String(params['state'] ?? '');
      }
    }
    if (this.authUrl.length === 0) {
      this.statusText = this.text($r('app.string.auth_missing_url'));
    }
    if (this.sessionMode) {
      this.startSessionPolling();
    }
  }

  aboutToDisappear(): void {
    this.stopSessionPolling();
    if (this.sessionMode && this.addAccount && !this.handled) {
      const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      xWebCookieBridge.syncActive(ctx);
    }
  }

  // Session mode has no redirect to intercept: the user just signs in on the
  // real x.com page. The cookie jar is the completion signal, so poll it while
  // the page is alive.
  private startSessionPolling(): void {
    this.stopSessionPolling();
    this.pollTimer = setInterval((): void => {
      this.checkSessionCookies();
    }, 1500);
  }

  private stopSessionPolling(): void {
    if (this.pollTimer !== -1) {
      clearInterval(this.pollTimer);
      this.pollTimer = -1;
    }
  }

  private async checkSessionCookies(): Promise<void> {
    if (this.handled) {
      return;
    }
    let cookie: string = '';
    try {
      cookie = await webview.WebCookieManager.fetchCookie('https://x.com');
    } catch (e) {
      return;
    }
    const session: XSession = XPrivateStore.parseCookieString(cookie);
    if (!session.isUsable()) {
      return;
    }
    // Adding an account has to produce a different identity. If x.com is still
    // signed in as an account that is already stored — the cookie jar could not
    // be emptied, or the user went back to the same account — keep waiting
    // instead of reporting a new account that does not exist.
    if (this.addAccount) {
      const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      const known: XAccount | null = accountStore.match(context, session.userId, session.username);
      const knownSession: XAccount | null = accountStore.matchSession(context, session.authToken, session.ct0);
      if (known !== null || knownSession !== null) {
        if (!this.addHintShown) {
          this.addHintShown = true;
          this.statusText = this.text($r('app.string.accounts_add_waiting'));
        }
        return;
      }
    }
    const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    if (!xPrivateStore.save(ctx, session, this.addAccount)) {
      this.stopSessionPolling();
      this.statusText = this.text($r('app.string.accounts_failed'));
      promptAction.showToast({ message: this.statusText, duration: 2500 });
      return;
    }
    this.handled = true;
    this.stopSessionPolling();
    this.busy = true;
    this.statusText = this.text($r('app.string.auth_session_done'));
    promptAction.showToast({
      message: this.text(this.addAccount ? $r('app.string.accounts_added') :
        $r('app.string.auth_signed_in')),
      duration: 1500
    });
    await router.replaceUrl({ url: 'pages/Index' });
  }

  private onIntercept(url: string): boolean {
    if (!url.startsWith(REDIRECT_URI)) {
      return false;
    }
    if (this.handled) {
      return true;
    }
    this.handled = true;
    this.finishOAuth(url);
    return true;
  }

  private async finishOAuth(url: string): Promise<void> {
    this.busy = true;
    this.statusText = this.text($r('app.string.auth_finishing'));
    try {
      const code: string = this.queryParam(url, 'code');
      const state: string = this.queryParam(url, 'state');
      const err: string = this.queryParam(url, 'error');
      if (err.length > 0) {
        promptAction.showToast({ message: this.text($r('app.string.auth_cancelled')), duration: 2000 });
        router.back();
        return;
      }
      if (code.length === 0) {
        promptAction.showToast({ message: this.text($r('app.string.auth_no_code')), duration: 2000 });
        router.back();
        return;
      }
      if (this.expectedState.length > 0 && state !== this.expectedState) {
        promptAction.showToast({ message: this.text($r('app.string.auth_state_mismatch')), duration: 2000 });
        router.back();
        return;
      }
      const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      const config: XDeveloperConfig = this.configStore.load(ctx);
      const result = await this.api.exchangeCode(config.clientId, '', code, this.verifier);
      if (!result.ok) {
        promptAction.showToast({ message: result.errorText, duration: 2500 });
        router.back();
        return;
      }
      this.api.setToken(result.accessToken);
      const me = await this.api.me();
      if (me !== null) {
        await authStore.saveToken(ctx, result.accessToken, me.id, me.username);
        await this.capturePrivateSession(ctx, me.id, me.username);
      } else {
        await authStore.saveToken(ctx, result.accessToken, '', '');
        await this.capturePrivateSession(ctx, '', '');
      }
      promptAction.showToast({ message: this.text($r('app.string.auth_signed_in')), duration: 1500 });
      await router.replaceUrl({ url: 'pages/Index' });
    } finally {
      this.busy = false;
    }
  }

  private queryParam(url: string, key: string): string {
    const q: number = url.indexOf('?');
    if (q < 0) {
      return '';
    }
    const parts: string[] = url.substring(q + 1).split('&');
    for (let i = 0; i < parts.length; i++) {
      const kv: string[] = parts[i].split('=');
      if (kv.length === 2 && kv[0] === key) {
        return decodeURIComponent(kv[1]);
      }
    }
    return '';
  }

  // The OAuth flow just ran inside this Web component, so its cookie jar holds
  // the x.com session the private interface layer needs: auth_token identifies
  // the account and ct0 becomes the x-csrf-token header. The same flow yields
  // both credentials — the OAuth token for the official API and the cookie
  // session for the private one.
  private async capturePrivateSession(ctx: common.UIAbilityContext,
    userId: string, username: string): Promise<void> {
    let cookie: string = '';
    try {
      cookie = await webview.WebCookieManager.fetchCookie('https://x.com');
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'fetchCookie failed: %{public}s', JSON.stringify(e));
    }
    if (cookie.length === 0) {
      try {
        cookie = await webview.WebCookieManager.fetchCookie('https://x.com/');
      } catch (e) {
        hilog.warn(DOMAIN, TAG, 'fetchCookie retry failed: %{public}s', JSON.stringify(e));
      }
    }
    const session: XSession = XPrivateStore.parseCookieString(cookie);
    // The jar belongs to whoever last used the Web component. Accept it only
    // when it is the account that just authorized, or the OAuth token would be
    // paired with another account's cookies — which is exactly what happens
    // when a second account is added while the first one is still active.
    if (userId.length > 0 && session.userId.length > 0 && session.userId !== userId) {
      hilog.warn(DOMAIN, TAG, '%{public}s', 'cookie jar belongs to another account, kept the token only');
      return;
    }
    session.userId = userId;
    session.username = username;
    if (!session.isUsable()) {
      // ct0 arrives with any x.com page; auth_token is HttpOnly and may be
      // withheld by the web engine. Settings offers a manual paste fallback.
      hilog.warn(DOMAIN, TAG, 'private session incomplete: %{public}d bytes of cookie',
        cookie.length);
      return;
    }
    xPrivateStore.save(ctx, session, this.addAccount);
    hilog.info(DOMAIN, TAG, 'private session captured');
  }

  build(): void {
    Navigation() {
      Column() {
        Row() {
          Text($r('app.string.auth_navigation_title')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Subtitle_L'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Button($r('app.string.compose_cancel'), { stateEffect: true })
            .fontSize($r('sys.float.Body_M'))
            .backgroundColor(secondaryButtonSurfaceColor(this.displayMode, this.themeDarkSurface))
            .fontColor($r('app.color.text_primary'))
            .onClick(() => {
              router.back();
            })
        }
        .width('100%')
        .height(56)
        .alignItems(VerticalAlign.Center)
        .padding({ left: 16, right: 12 })
        if (this.statusText.length > 0) {
          Text(this.statusText).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .padding({ left: 16, right: 16, bottom: 6 })
        }
        if (this.authUrl.length > 0) {
          Web({ src: this.authUrl, controller: this.controller })
            .layoutWeight(1)
            .width('100%')
            .javaScriptAccess(true)
            .domStorageAccess(true)
            .userAgent(this.ua)
            .darkMode(this.webDarkMode())
            .forceDarkAccess(this.displayMode === DISPLAY_MODE_DARK)
            .backgroundColor(pageSurfaceColor(this.displayMode, this.themeDarkSurface))
            .onHttpAuthRequest((event): boolean => {
              if (event === undefined || event === null) {
                return false;
              }
              const credential: WebProxyCredential = proxyStore.webCredential();
              if (!credential.usable) {
                event.handler.cancel();
                return false;
              }
              return event.handler.confirm(credential.username, credential.password);
            })
            .onPageEnd(() => {
              // Login can complete without navigation firing the intercept
              // path, so re-check whenever a page finishes loading.
              if (this.sessionMode) {
                this.checkSessionCookies();
              }
            })
            .onLoadIntercept((event) => {
              if (event === undefined) {
                return false;
              }
              const url: string = event.data.getRequestUrl();
              return this.onIntercept(url);
            })
        } else {
          Blank().layoutWeight(1)
        }
        if (this.busy) {
          LoadingProgress().width(18).height(18).color(this.accentColor).margin(12)
        }
      }
      .width('100%')
      .height('100%')
      .padding({ top: this.topInset(), bottom: this.navigationIndicatorHeight })
      .backgroundColor(pageSurfaceColor(this.displayMode, this.themeDarkSurface))
    }
    .width('100%')
    .height('100%')
    .backgroundColor(pageSurfaceColor(this.displayMode, this.themeDarkSurface))
    .hideTitleBar(true)
    .titleMode(NavigationTitleMode.Mini)
  }
}
