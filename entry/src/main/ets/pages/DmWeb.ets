// Private-message thread.
//
// XChat stores message bodies as end-to-end encrypted events: the GraphQL
// payload only carries `encoded_message_events`, and both the key exchange and
// the event codec live in X's own native key-store library (libjuicebox_sdk_jni
// in the reference Android client). Reimplementing that stack on the client is
// not a port, it is a rewrite, so the thread is rendered by the client that
// already owns the keys: X's web client.
//
// The app cookie jar is synced into ArkWeb first, so x.com/messages opens as
// the active account, decrypts the thread and sends through the same session.
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

const X_MESSAGES_URL: string = 'https://x.com/messages';
const DISPLAY_MODE_LIGHT: string = 'light';
const DISPLAY_MODE_DARK: string = 'dark';

export interface DmWebRouteParam {
  conversationId: string;
  title: string;
}

@Builder
export function DmWebBuilder(): void {
  DmWebPage();
}

@Component
export struct DmWebPage {
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
  private conversationId: string = '';
  private title: string = '';
  private url: string = X_MESSAGES_URL;
  private controller: webview.WebviewController = new webview.WebviewController();

  aboutToAppear(): void {
    this.readRoute();
    this.prepareSession();
  }

  private readRoute(): void {
    const params: DmWebRouteParam[] =
      this.pageStack.getParamByName('DmWeb') as DmWebRouteParam[];
    if (params === undefined || params === null || params.length === 0) {
      return;
    }
    const param: DmWebRouteParam = params[params.length - 1];
    this.conversationId = param.conversationId;
    this.title = param.title;
    this.url = this.conversationId.length > 0 ?
      X_MESSAGES_URL + '/' + encodeURIComponent(this.conversationId) : X_MESSAGES_URL;
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
    this.failed = false;
    this.failureText = '';
    this.loading = true;
    // A failed main-frame load leaves an error document behind; reloading the
    // controller replaces it instead of stacking another history entry.
    try {
      this.controller.refresh();
    } catch (error) {
      promptAction.showToast({
        message: this.text($r('app.string.dm_web_failed')),
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
        .fontColor([$r('app.color.text_secondary')])
      Text(this.failureText.length > 0 ? this.failureText :
        this.text($r('app.string.dm_web_failed'))).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_L'))
        .fontColor($r('app.color.text_secondary'))
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
          Text($r('app.string.dm_loading')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('app.color.text_secondary'))
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
          .backgroundColor(pageSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
          .onPageBegin((): void => {
            this.loading = true;
          })
          .onPageEnd((): void => {
            this.loading = false;
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
            Text($r('app.string.dm_loading')).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_M'))
              .fontColor($r('app.color.text_secondary'))
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
    .backgroundColor(pageSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
  }

  build(): void {
    HdsNavDestination() {
      this.WebContent()
    }
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
          mainTitle: this.title.length > 0 ? this.title : this.text($r('app.string.messages_title'))
        }
      },
      style: destinationTitleBarStyle(ScrollEffectType.IMMERSIVE_GRADIENT_BLUR,
        this.themeDisplayMode, this.themeDarkSurface, this.titleBarStyleMode)
    })
    .backgroundColor(pageSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
    .systemMaterial(this.pageMaterial());
  }
}
