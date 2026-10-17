// Harmony X signs in with the Client ID selected in Settings. Native OAuth
// uses PKCE, so users never need to expose a Client Secret in the app.
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import webview from '@ohos.web.webview';
import hilog from '@ohos.hilog';
import common from '@ohos.app.ability.common';
import { curves } from '@kit.ArkUI';
import { Pkce } from '../services/Pkce';
import { authStore } from '../services/AuthStore';
import { oauthFlowStore } from '../services/OAuthFlowStore';
import { XApiClient, REDIRECT_URI } from '../services/XApiClient';
import { OAuthConfigStore, XDeveloperConfig } from '../services/OAuthConfig';
import { xPrivateStore } from '../services/XPrivateStore';
import { XSession } from '../services/XPrivateStore';
import { xWebCookieBridge } from '../services/XWebCookieBridge';
import { cardSurfaceColor, pageSurfaceColor, secondaryButtonSurfaceColor } from '../utils/ThemeColors';

// Sign-in runs inside the app's own Web component. That is what makes the
// x.com cookie session (auth_token / ct0) readable afterwards — a session in
// the system browser belongs to another app and cannot be read from here.
// Set to false to fall back to the external browser if X ever refuses to
// render its authorization page inside an embedded web view.
const USE_EMBEDDED_AUTH_WEB: boolean = true;
const DOMAIN = 0xFF00;
const TAG = 'HarmonyX-Login';

@Entry
@Component
struct Login {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @State busy: boolean = false;
  @State private xMarkOpacity: number = 1;
  @State private xMarkScale: number = 1;
  @State private foregroundOpacity: number = 0;
  @State private foregroundScale: number = 0.72;
  @StorageLink('harmonyx.accent_color') accentColor: string = '#007DFF';
  @StorageProp('harmonyx.display_mode') private themeDisplayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private themeDarkSurface: string = '';
  @StorageProp('harmonyx.status_bar_height') private statusBarHeight: number =
    AppStorage.get<number>('harmonyx.status_bar_height') ?? 0;
  @StorageProp('harmonyx.navigation_indicator_height') private navigationIndicatorHeight: number =
    AppStorage.get<number>('harmonyx.navigation_indicator_height') ?? 0;
  @State private clientId: string = '';
  // Set when this page was opened from the account switcher: another account
  // stays signed in, so nothing here may replace it.
  private addAccount: boolean = false;
  private configStore: OAuthConfigStore = new OAuthConfigStore();

  private text(resource: Resource): string {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    return context.resourceManager.getStringSync(resource);
  }

  aboutToAppear(): void {
    this.playBrandIntro();
    const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const config: XDeveloperConfig = this.configStore.load(ctx);
    this.clientId = config.clientId;
    const params = router.getParams() as Record<string, Object> | undefined;
    if (params !== undefined && String(params['mode'] ?? '') === 'add') {
      this.addAccount = true;
      this.startSessionLogin();
      return;
    }
    authStore.load(ctx).then(() => {
      if (authStore.isSignedIn()) {
        router.replaceUrl({ url: 'pages/Index' });
        return;
      }
      // A cookie session is enough on its own: everything except direct
      // messages works through the private interface.
      const session: XSession = xPrivateStore.load(ctx);
      if (session.isUsable()) {
        router.replaceUrl({ url: 'pages/Index' });
      }
    });
  }

  // Primary path: sign in on the real x.com page inside the app. No developer
  // application or Client ID is required — the resulting cookie session is what
  // the private GraphQL/REST interface authenticates with.
  private async startSessionLogin(): Promise<void> {
    try {
      await this.prepareAddAccount();
      await router.pushUrl({
        url: 'pages/AuthWeb',
        params: { 'mode': 'session', 'addAccount': this.addAccount ? '1' : '' }
      });
    } catch (e) {
      promptAction.showToast({ message: this.text($r('app.string.login_browser_failed')), duration: 2500 });
    }
  }

  // Adding an account has to start from an empty cookie jar: x.com would
  // otherwise still be signed in as the account in use, and either flow would
  // hand that same session back instead of a new one. The stored sessions of
  // the other accounts live in preferences and are not touched.
  private async prepareAddAccount(): Promise<void> {
    if (!this.addAccount) {
      return;
    }
    // AuthWeb also checks the captured session against the stored accounts, so
    // a jar that could not be emptied is caught there. Sites with their own
    // login in the same jar (Grok web mode) are preserved.
    await xWebCookieBridge.beginFreshXSession();
  }

  private playBrandIntro(): void {
    this.xMarkOpacity = 1;
    this.xMarkScale = 1;
    this.foregroundOpacity = 0;
    this.foregroundScale = 0.72;
    this.getUIContext().animateTo({ duration: 680, curve: curves.springMotion(0.72, 0.86) }, (): void => {
      this.xMarkOpacity = 0;
      this.xMarkScale = 0.78;
      this.foregroundOpacity = 1;
      this.foregroundScale = 1;
    });
  }

  private topSafePadding(): number {
    return Math.max(this.statusBarHeight, 16) + 8;
  }

  private async startOAuth(): Promise<void> {
    const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const config: XDeveloperConfig = this.configStore.load(ctx);
    this.clientId = config.clientId;
    if (this.clientId.length === 0) {
      promptAction.showToast({ message: this.text($r('app.string.login_not_configured')), duration: 2500 });
      return;
    }
    this.busy = true;
    try {
      await this.prepareAddAccount();
      const verifier: string = Pkce.newVerifier();
      const challenge: string = Pkce.challengeS256(verifier);
      const state: string = Pkce.newState();
      if (verifier.length === 0 || state.length === 0) {
        promptAction.showToast({ message: this.text($r('app.string.login_prepare_failed')), duration: 2500 });
        return;
      }
      const authUrl: string = XApiClient.buildAuthorizeUrl(this.clientId, challenge, state);
      const saved: boolean = await oauthFlowStore.save(ctx, verifier, state, this.clientId);
      if (!saved) {
        promptAction.showToast({ message: this.text($r('app.string.login_prepare_failed')), duration: 2500 });
        return;
      }
      if (USE_EMBEDDED_AUTH_WEB) {
        await router.pushUrl({
          url: 'pages/AuthWeb',
          params: {
            'authUrl': authUrl,
            'verifier': verifier,
            'state': state
          }
        });
        return;
      }
      await ctx.startAbility({
        action: 'ohos.want.action.viewData',
        entities: ['entity.system.browsable'],
        uri: authUrl
      });
      promptAction.showToast({ message: this.text($r('app.string.login_continue_browser')), duration: 2000 });
    } catch (e) {
      promptAction.showToast({ message: this.text($r('app.string.login_browser_failed')), duration: 2500 });
    } finally {
      this.busy = false;
    }
  }

  build(): void {
    Column() {
      Text(this.addAccount ? $r('app.string.accounts_add') : $r('app.string.login_navigation_title')).fontFamily(this.appFontFamily)
        .width('100%')
        .fontSize($r('sys.float.Title_M'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .padding({ left: 24, right: 24, top: this.topSafePadding(), bottom: 12 })

      Scroll() {
        Column({ space: 16 }) {
          Stack({ alignContent: Alignment.Center }) {
            Text('𝕏').fontFamily(this.appFontFamily)
              .fontSize(76)
              // The wordmark is brand art, not part of the reading hierarchy,
              // so it stays at a fixed size while body text follows the system.
              .maxFontScale(1)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .opacity(this.xMarkOpacity)
              .scale({ x: this.xMarkScale, y: this.xMarkScale })

            Image($r('app.media.ui_brand_foreground'))
              .width(88)
              .height(88)
              .objectFit(ImageFit.Contain)
              .opacity(this.foregroundOpacity)
              .scale({ x: this.foregroundScale, y: this.foregroundScale })
          }
          .width(104)
          .height(104)
          .renderGroup(true)
          .margin({ top: 56 })

          Text($r('app.string.login_title')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Title_L'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))

          Text($r('app.string.login_description')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('app.color.text_secondary'))

          // Primary path: sign in on x.com. No developer application needed.
          Button($r('app.string.login_x_account'), { stateEffect: true })
            .width('100%')
            .backgroundColor(this.accentColor)
            .fontColor($r('app.color.text_on_accent'))
            .enabled(!this.busy)
            .onClick(() => this.startSessionLogin())
          Text($r('app.string.login_x_account_desc')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('app.color.text_secondary'))
            .width('100%')

          // Optional path: OAuth 2.0 with a self-registered developer app. It
          // also yields the official API v2 token, which the cookie session
          // alone cannot provide.
          Button($r('app.string.login_developer_api'), { stateEffect: true })
            .width('100%')
            .backgroundColor(secondaryButtonSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
            .fontColor($r('app.color.text_primary'))
            .enabled(!this.busy && this.clientId.length > 0)
            .onClick(() => this.startOAuth())
          Text($r('app.string.login_developer_api_desc')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('app.color.text_secondary'))
            .width('100%')

          if (this.clientId.length === 0) {
            Column({ space: 8 }) {
              Text($r('app.string.login_developer_setup')).fontFamily(this.appFontFamily)
                .fontSize($r('sys.float.Body_M'))
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
              Text(this.text($r('app.string.login_developer_steps_prefix')) + REDIRECT_URI +
                this.text($r('app.string.login_developer_steps_suffix'))).fontFamily(this.appFontFamily)
                .fontSize($r('sys.float.Body_M'))
                .fontColor($r('app.color.text_secondary'))
            }
            .width('100%')
            .padding(12)
            .backgroundColor(cardSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
            .borderRadius(16)
          }

          if (this.busy) {
            LoadingProgress().width(18).height(18).color(this.accentColor)
          }
        }
        .width('100%')
        .padding({ left: 24, right: 24, bottom: this.navigationIndicatorHeight + 32 })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(pageSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
  }
}
