import { pageBackgroundActive } from '../services/PageBackgroundStore';
import { pageTextColor } from '../utils/ThemeColors';
import { appPageBackground } from '../components/PageBackgroundLayer';
import { pageCanvasColor, pageReadingSurfaceColor } from '../utils/ThemeColors';
import { STORAGE_KEY_PAGE_TRANSITION_MODE, DEFAULT_PAGE_TRANSITION_MODE } from '../services/PageTransitionSettingsStore';
import { pageSystemTransition, PageTransitionMotion } from '../utils/PageTransition';
// X account flows use the active cookie session and application proxy.
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import common from '@ohos.app.ability.common';
import webview from '@ohos.web.webview';
import promptAction from '@ohos.promptAction';
import { deviceInfo } from '@kit.BasicServicesKit';
import { uiMaterial } from '@kit.ArkUI';
import { HdsNavDestination, HdsNavDestinationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { xWebCookieBridge } from '../services/XWebCookieBridge';
import { xUserAgent } from '../services/XUserAgent';
import { ProxyEntry, proxyStore } from '../services/ProxyStore';
import { WEB_AUDIO_CAPTURE, webPermission } from '../utils/WebPermission';
import { destinationTitleBarStyle } from '../utils/DestinationTitleBar';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';
import { pageSurfaceColor, secondaryButtonSurfaceColor } from '../utils/ThemeColors';
import { accountStore, XAccount } from '../services/AccountStore';
import { XPrivateStore, XSession } from '../services/XPrivateStore';
import { xPrivateClient } from '../services/XPrivateClient';
import { materialModifier } from '../utils/SystemMaterial';

const X_MESSAGES_URL: string = 'https://x.com/';
const DISPLAY_MODE_LIGHT: string = 'light';
const DISPLAY_MODE_DARK: string = 'dark';

export interface ProfileWebRouteParam {
  url: string;
  title: string;
  accountSettings?: boolean;
}

@Builder
export function ProfileWebBuilder(): void {
  ProfileWebPage();
}

@Component
export struct ProfileWebPage {
  @StorageProp('harmonyx.page_background') private pageBackgroundValue: string = '';
  @State private pageMotion: PageTransitionMotion = new PageTransitionMotion();
  @StorageProp(STORAGE_KEY_PAGE_TRANSITION_MODE) private pageTransitionMode: string = DEFAULT_PAGE_TRANSITION_MODE;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp('harmonyx.status_bar_height') statusBarHeight: number =
    AppStorage.get<number>('harmonyx.status_bar_height') ?? 0;
  @StorageProp('harmonyx.navigation_indicator_height') navigationIndicatorHeight: number =
    AppStorage.get<number>('harmonyx.navigation_indicator_height') ?? 0;
  @StorageLink('harmonyx.accent_color') accentColor: string = '#007DFF';
  @StorageProp('harmonyx.display_mode') private themeDisplayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private themeDarkSurface: string = '';
  @StorageLink('harmonyx.title_bar_style_mode') titleBarStyleMode: number = 0;
  @State private loading: boolean = true;
  @State private failed: boolean = false;
  @State private failureText: string = '';
  @State private ready: boolean = false;
  @StorageProp('harmonyx.accounts_changed') @Watch('onAccountChanged') private accountsChanged: number = 0;
  private accountSettings: boolean = false;
  private accountId: string = '';
  private alive: boolean = true;
  private title: string = '';
  private url: string = X_MESSAGES_URL;
  private controller: webview.WebviewController = new webview.WebviewController();

  aboutToAppear(): void {
    this.readRoute();
    this.accountId = accountStore.activeId(getContext(this) as common.UIAbilityContext);
    this.prepareSession();
  }

  aboutToDisappear(): void { this.alive = false; }

  private onAccountChanged(): void {
    if (!this.accountSettings || !this.alive) { return; }
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    if (this.accountId !== accountStore.activeId(context)) {
      this.failed = true;
      this.ready = false;
      this.loading = false;
      this.failureText = this.text($r('app.string.xsettings_web_account_changed'));
    }
  }

  private async captureSettingsSession(): Promise<void> {
    if (!this.accountSettings || !this.alive) { return; }
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    if (accountStore.activeId(context) !== this.accountId) { this.onAccountChanged(); return; }
    try {
      const cookie: string = await webview.WebCookieManager.fetchCookie('https://x.com');
      if (!this.alive || accountStore.activeId(context) !== this.accountId) { return; }
      const account: XAccount | null = accountStore.find(context, this.accountId);
      const session: XSession = XPrivateStore.parseCookieString(cookie);
      if (account === null || !session.isUsable()) { return; }
      // Rotation is accepted only when the jar still demonstrably belongs to
      // the account this page opened with. A web account switch cannot replace
      // another account's credentials or make it active in Harmony X.
      const sameAccount: boolean = account.userId.length > 0 ?
        session.userId === account.userId : session.authToken === account.authToken;
      if (!sameAccount) {
        this.failed = true;
        this.ready = false;
        this.loading = false;
        this.failureText = this.text($r('app.string.xsettings_web_account_changed'));
        return;
      }
      if (account.authToken === session.authToken && account.ct0 === session.ct0) { return; }
      account.authToken = session.authToken;
      account.ct0 = session.ct0;
      account.rawCookie = session.rawCookie;
      if (accountStore.upsert(context, account)) { xPrivateClient.load(context); }
    } catch (error) { }
  }

  private readRoute(): void {
    const params: ProfileWebRouteParam[] =
      this.pageStack.getParamByName('ProfileWeb') as ProfileWebRouteParam[];
    if (params === undefined || params === null || params.length === 0) {
      return;
    }
    const param: ProfileWebRouteParam = params[params.length - 1];
    this.title = param.title;
    this.url = param.url.startsWith('https://x.com/') ? param.url : X_MESSAGES_URL;
    this.accountSettings = param.accountSettings === true;
  }

  // The web client authenticates from its own cookie jar and reaches the
  // network through the application level proxy, so both have to be in place
  // before the first navigation: the Web component is not built until then.
  private async prepareSession(): Promise<void> {
    try {
      const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      xWebCookieBridge.syncActive(context);
    } catch (error) {
      // A signed-out app simply lands on X's login page.
    }
    await proxyStore.applyToWebStack();
    if (!this.alive || (this.accountSettings &&
      this.accountId !== accountStore.activeId(getContext(this) as common.UIAbilityContext))) { return; }
    this.ready = true;
  }

  private text(resource: Resource): string {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    return context.resourceManager.getStringSync(resource);
  }

  private pageMaterial(): uiMaterial.Material | undefined {
    if (!deviceInfo.apiAvailable('26.0.0')) {
      return undefined;
    }
    return new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.REGULAR,
      applyShadow: true,
      colorInvert: true
    });
  }

  private webDarkMode(): WebDarkMode {
    if (this.themeDisplayMode === DISPLAY_MODE_DARK) {
      return WebDarkMode.On;
    }
    if (this.themeDisplayMode === DISPLAY_MODE_LIGHT) {
      return WebDarkMode.Off;
    }
    return WebDarkMode.Auto;
  }

  private webForceDark(): boolean {
    return this.themeDisplayMode !== DISPLAY_MODE_LIGHT;
  }

  private retry(): void {
    if (this.accountSettings && (!this.ready ||
      this.accountId !== accountStore.activeId(getContext(this) as common.UIAbilityContext))) {
      ResponsiveLayout.closeContentDestination(this.pageStack);
      return;
    }
    this.failed = false;
    this.failureText = '';
    this.loading = true;
    // A failed main-frame load leaves an error document behind; reloading the
    // controller replaces it instead of stacking another history entry.
    try {
      this.controller.refresh();
    } catch (error) {
      promptAction.showToast({
        message: this.text($r('app.string.profile_web_failed')),
        duration: 1800
      });
      this.loading = false;
    }
  }

  @Builder
  private Failure(): void {
    Column({ space: 12 }) {
      SymbolGlyph($r('sys.symbol.exclamationmark_circle'))
        .fontSize(32)
        .fontColor([pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)])
      Text(this.failureText.length > 0 ? this.failureText :
        this.text($r('app.string.profile_web_failed'))).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_L'))
        .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
        .textAlign(TextAlign.Center)
        .width('100%')
      Button($r('app.string.common_retry'), { stateEffect: true })
        .fontSize($r('sys.float.Body_L'))
        .fontColor($r('app.color.text_on_accent'))
        .backgroundColor(this.accentColor)
        .borderRadius(20)
        .onClick((): void => {
          this.retry();
        })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .padding({ left: 28, right: 28 })
  }

  @Builder
  private WebContent(): void {
    Column() {
      if (this.failed) {
        this.Failure()
      } else if (!this.ready) {
        Column({ space: 12 }) {
          LoadingProgress().color(this.accentColor).width(18).height(18)
          Text($r('app.string.status_loading')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M'))
            .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Web({ src: this.url, controller: this.controller })
          .width('100%')
          .layoutWeight(1)
          .javaScriptAccess(true)
          .domStorageAccess(true)
          .databaseAccess(true)
          .userAgent(xUserAgent.value())
          .darkMode(this.webDarkMode())
          .forceDarkAccess(this.webForceDark())
          .backgroundColor(pageCanvasColor(this.themeDisplayMode, this.themeDarkSurface, this.pageBackgroundValue))
          .onPageBegin((): void => {
            this.loading = true;
          })
          .onPageEnd((): void => {
            this.loading = false;
            this.captureSettingsSession();
            // The thread's own login (and any cookie X refreshes while the
            // page runs) is written out now instead of waiting for the jar's
            // periodic flush.
            webview.WebCookieManager.saveCookieAsync().then((): void => {
            }).catch((): void => {
            });
          })
          .onErrorReceive((event): void => {
            if (event === undefined || event === null) {
              return;
            }
            if (!event.request.isMainFrame()) {
              // Sub-resource failures (an avatar, a font) must not replace a
              // readable conversation with an error page.
              return;
            }
            this.failed = true;
            this.loading = false;
            this.failureText = event.error.getErrorInfo();
          })
          // A proxy that asks for credentials answers the CONNECT tunnel with
          // 407; without them ArkWeb only reports ERR_TUNNEL_CONNECTION_FAILED,
          // so the entry the Web component is routed through answers here.
          .onHttpAuthRequest((event): boolean => {
            if (event === undefined || event === null) {
              return false;
            }
            const proxy: ProxyEntry | null = proxyStore.webProxyEntry();
            if (proxy === null || proxy.username.length === 0 || proxy.password.length === 0) {
              event.handler.cancel();
              return false;
            }
            return event.handler.confirm(proxy.username, proxy.password);
          })
          // X's message surface records voice notes, which needs the app to
          // answer the page's capture request.
          .onPermissionRequest((event): void => {
            if (event === undefined || event === null) {
              return;
            }
            const resources: string[] = event.request.getAccessibleResource();
            let wantsAudio: boolean = false;
            for (let i: number = 0; i < resources.length; i++) {
              if (resources[i] === WEB_AUDIO_CAPTURE) {
                wantsAudio = true;
              }
            }
            if (!wantsAudio) {
              event.request.deny();
              return;
            }
            const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
            webPermission.canUseMicrophone(context, event.request.getOrigin())
              .then((granted: boolean): void => {
                if (granted) {
                  event.request.grant([WEB_AUDIO_CAPTURE]);
                } else {
                  event.request.deny();
                }
              })
              .catch((): void => {
                event.request.deny();
              });
          })
        if (this.loading) {
          Row({ space: 8 }) {
            LoadingProgress().color(this.accentColor).width(18).height(18)
            Text($r('app.string.status_loading')).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_M'))
              .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .padding({ top: 8, bottom: 8 })
        }
      }
    }
    .width('100%')
    .height('100%')
    // The web client draws its own header and composer, so the page is inset
    // under the native title bar and above the navigation indicator.
    .padding({
      top: this.statusBarHeight + 56,
      bottom: this.navigationIndicatorHeight
    })
    .backgroundColor(pageCanvasColor(this.themeDisplayMode, this.themeDarkSurface, this.pageBackgroundValue))
  }

  build(): void {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        appPageBackground()
      this.WebContent()
    
      }.width('100%').height('100%')
    }
    .scale({ x: this.pageMotion.scale, y: this.pageMotion.scale })
    .opacity(this.pageMotion.opacity)
    .onReady((context: NavDestinationContext): void => { this.pageMotion.attach(context); })
    .systemTransition(pageSystemTransition(this.pageTransitionMode))
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .hideBackButton(false)
    .onBackPressed((): boolean => {
      // The web client keeps its own history (list -> thread -> profile), so
      // the system gesture walks that history before leaving the destination.
      try {
        if (this.controller.accessBackward()) {
          this.controller.backward();
          return true;
        }
      } catch (error) {
      }
      ResponsiveLayout.closeContentDestination(this.pageStack);
      return true;
    })
    .titleBar({
      avoidLayoutSafeArea: true,
      content: {
        title: {
          mainTitle: this.title.length > 0 ? this.title : this.text($r('app.string.profile_about_title'))
        }
      },
      style: destinationTitleBarStyle(ScrollEffectType.IMMERSIVE_GRADIENT_BLUR,
        this.themeDisplayMode, this.themeDarkSurface, this.titleBarStyleMode)
    })
    .backgroundColor(pageCanvasColor(this.themeDisplayMode, this.themeDarkSurface, this.pageBackgroundValue))
    .attributeModifier(materialModifier(pageBackgroundActive(this.pageBackgroundValue) ? undefined : this.pageMaterial()));
  }
}
