// Embedded X sign-in browser: loads the OAuth authorize page and
// intercepts the harmonyx://callback redirect carrying the auth code,
// then exchanges it for an access token without leaving the app.
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import webview from '@ohos.web.webview';
import common from '@ohos.app.ability.common';
import { authStore } from '../services/AuthStore';
import { XApiClient, REDIRECT_URI } from '../services/XApiClient';
import { OAuthConfigStore, XDeveloperConfig } from '../services/OAuthConfig';

@Entry
@Component
struct AuthWeb {
  @State authUrl: string = '';
  @State verifier: string = '';
  @State expectedState: string = '';
  @State busy: boolean = false;
  @State statusText: string = '';
  @StorageLink('harmonyx.accent_color') accentColor: string = '#007DFF';
  private controller: webview.WebviewController = new webview.WebviewController();
  private api: XApiClient = new XApiClient();
  private configStore: OAuthConfigStore = new OAuthConfigStore();
  private handled: boolean = false;
  // Standard mobile-browser UA: the default ArkWeb UA looks unfamiliar to
  // X's login risk engine and can contribute to "temporarily limited"
  // flags. This only identifies the renderer, nothing else is spoofed.
  private readonly ua: string = 'Mozilla/5.0 (Linux; Android 14; K) AppleWebKit/537.36' +
    ' (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36';

  private text(resource: Resource): string {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    return context.resourceManager.getStringSync(resource);
  }

  aboutToAppear(): void {
    this.statusText = this.text($r('app.string.auth_loading'));
    const params = router.getParams() as Record<string, Object> | undefined;
    if (params !== undefined) {
      this.authUrl = String(params['authUrl'] ?? '');
      this.verifier = String(params['verifier'] ?? '');
      this.expectedState = String(params['state'] ?? '');
    }
    if (this.authUrl.length === 0) {
      this.statusText = this.text($r('app.string.auth_missing_url'));
    }
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
      } else {
        await authStore.saveToken(ctx, result.accessToken, '', '');
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

  build(): void {
    Navigation() {
      Column() {
        Row() {
          Text(this.statusText)
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .layoutWeight(1)
          Button($r('app.string.compose_cancel'), { stateEffect: true })
            .fontSize(13)
            .backgroundColor($r('app.color.bg_secondary_btn'))
            .fontColor($r('app.color.text_primary'))
            .onClick(() => {
              router.back();
            })
        }
        .width('100%')
        .padding({ left: 16, right: 12, top: 8, bottom: 4 })
        if (this.authUrl.length > 0) {
          Web({ src: this.authUrl, controller: this.controller })
            .layoutWeight(1)
            .width('100%')
            .javaScriptAccess(true)
            .domStorageAccess(true)
            .userAgent(this.ua)
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
          LoadingProgress().color(this.accentColor).margin(12)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.bg_page'))
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
    .title($r('app.string.auth_navigation_title'))
    .titleMode(NavigationTitleMode.Mini)
  }
}
