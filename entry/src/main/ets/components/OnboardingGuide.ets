import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import common from '@ohos.app.ability.common';
import webview from '@ohos.web.webview';
import { HdsSceneController, HdsSceneType, HdsVisualComponent } from '@kit.UIDesignKit';
import { WebProxyCredential, proxyStore } from '../services/ProxyStore';
import { XPrivateStore, XSession, xPrivateStore } from '../services/XPrivateStore';
import { XAccount, accountStore } from '../services/AccountStore';
import { xWebCookieBridge } from '../services/XWebCookieBridge';
import { xUserAgent } from '../services/XUserAgent';
import { DISPLAY_MODE_DARK, DISPLAY_MODE_LIGHT, DISPLAY_MODE_SYSTEM } from '../services/AppearanceStore';
import { linkSettingsStore, STORAGE_KEY_LINK_IN_APP } from '../services/LinkSettingsStore';
import { mediaSettingsStore, STORAGE_KEY_HOME_VIDEO_MUTED, STORAGE_KEY_VIDEO_AUTO_PIP } from '../services/MediaSettingsStore';
import { notificationSettingsStore, STORAGE_KEY_NOTIFICATION_ALERTS } from '../services/NotificationSettingsStore';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';
import { SystemMaterialUtil } from '../utils/SystemMaterial';
import { STORAGE_KEY_SHEET_MATERIAL_ENABLED } from '../services/SheetMaterialSettingsStore';
import { sheetMaterialActive } from '../utils/SheetMaterial';
import { fieldSurfaceColor, pageSurfaceColor } from '../utils/ThemeColors';

const LAST_GUIDE_PAGE: number = 7;
const X_LOGIN_URL: string = 'https://x.com/i/flow/login';

@Component
export struct OnboardingGuide {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp(STORAGE_KEY_SHEET_MATERIAL_ENABLED) private sheetMaterialEnabled: boolean = false;
  @Link visible: boolean;
  onCompleted: () => void = (): void => {};
  loginOnly: boolean = false;
  addAccount: boolean = false;
  @State private currentPage: number = 0;
  @State private loginSaveFailed: boolean = false;
  @State private addAccountWaiting: boolean = false;
  @State private alreadySignedIn: boolean = false;
  @State private finishing: boolean = false;
  @StorageProp('harmonyx.breakpoint') private breakpoint: string = ResponsiveLayout.BREAKPOINT_SM;
  @StorageProp('harmonyx.navigation_indicator_height') private navigationIndicatorHeight: number = 0;
  @StorageLink('harmonyx.display_mode') private displayMode: string = DISPLAY_MODE_SYSTEM;
  @StorageProp('harmonyx.dark_surface') private darkSurface: string = '';
  @StorageLink('harmonyx.accent_color') private accentColor: string = '#007DFF';
  @StorageLink(STORAGE_KEY_LINK_IN_APP) private linksInApp: boolean = false;
  @StorageLink(STORAGE_KEY_HOME_VIDEO_MUTED) private homeVideoMuted: boolean = true;
  @StorageLink(STORAGE_KEY_VIDEO_AUTO_PIP) private videoAutoPip: boolean = true;
  @StorageLink(STORAGE_KEY_NOTIFICATION_ALERTS) private notificationAlerts: boolean = true;
  private webController: webview.WebviewController = new webview.WebviewController();
  private swiperController: SwiperController = new SwiperController();
  private pollTimer: number = -1;
  private checkingCookies: boolean = false;
  private loginSaved: boolean = false;
  private readonly userAgent: string = xUserAgent.value();
  private brandGlowController: HdsSceneController = new HdsSceneController().setSceneParams({
    backgroundMaskColors: ['#18007DFF', '#1400C8FF'],
    firstEdgeFlowLight: { startPos: 0, endPos: 0.5, color: '#67D7FF' },
    secondEdgeFlowLight: { startPos: 0, endPos: -0.5, color: '#007DFF' }
  });
  private brandGlowActive: boolean = false;

  aboutToAppear(): void {
    const context: common.Context | undefined = this.getUIContext().getHostContext();
    if (context !== undefined) {
      const active: XAccount | null = accountStore.active(context);
      this.alreadySignedIn = !this.loginOnly && active !== null && active.isUsable();
    }
    if (this.loginOnly) {
      this.currentPage = LAST_GUIDE_PAGE;
      this.startLoginPolling();
    }
  }

  aboutToDisappear(): void {
    this.stopLoginPolling();
    this.updateBrandGlow(false);
    if (this.loginOnly && this.addAccount && !this.loginSaved) {
      const context: common.Context | undefined = this.getUIContext().getHostContext();
      if (context !== undefined) {
        xWebCookieBridge.syncActive(context);
      }
    }
  }

  private updateBrandGlow(enabled: boolean): void {
    if (enabled && !this.brandGlowActive) {
      this.brandGlowController.start();
      this.brandGlowActive = true;
    } else if (!enabled && this.brandGlowActive) {
      this.brandGlowController.stop();
      this.brandGlowActive = false;
    }
  }

  private isCompact(): boolean {
    return ResponsiveLayout.isSmall(this.breakpoint);
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

  private nextPage(): void {
    if (this.currentPage >= LAST_GUIDE_PAGE) {
      this.finishGuide();
      return;
    }
    this.swiperController.showNext();
  }

  private previousPage(): void {
    if (this.currentPage > 0) {
      this.swiperController.showPrevious();
    }
  }

  private onPageChanged(index: number): void {
    this.currentPage = index;
    this.updateBrandGlow(index === 0);
    if (index === LAST_GUIDE_PAGE && !this.alreadySignedIn) {
      this.startLoginPolling();
      this.checkSessionCookies();
    } else {
      this.stopLoginPolling();
    }
  }

  private saveLinksInApp(enabled: boolean): void {
    const context: common.Context | undefined = this.getUIContext().getHostContext();
    if (context !== undefined) {
      linkSettingsStore.save(context, enabled);
    }
  }

  private saveHomeVideoMuted(enabled: boolean): void {
    const context: common.Context | undefined = this.getUIContext().getHostContext();
    if (context !== undefined) {
      mediaSettingsStore.saveHomeVideoMuted(context, enabled);
    }
  }

  private saveVideoAutoPip(enabled: boolean): void {
    const context: common.Context | undefined = this.getUIContext().getHostContext();
    if (context !== undefined) {
      mediaSettingsStore.saveVideoAutoPip(context, enabled);
    }
  }

  private saveNotificationAlerts(enabled: boolean): void {
    const context: common.Context | undefined = this.getUIContext().getHostContext();
    if (context !== undefined) {
      notificationSettingsStore.saveAlertsEnabled(context, enabled);
    }
  }

  private finishGuide(): void {
    if (this.finishing) {
      return;
    }
    this.finishing = true;
    this.stopLoginPolling();
    this.onCompleted();
    this.visible = false;
  }

  private startLoginPolling(): void {
    this.stopLoginPolling();
    this.pollTimer = setInterval((): void => {
      this.checkSessionCookies();
    }, 1500);
  }

  private stopLoginPolling(): void {
    if (this.pollTimer !== -1) {
      clearInterval(this.pollTimer);
      this.pollTimer = -1;
    }
  }

  private async checkSessionCookies(): Promise<void> {
    if ((!this.loginOnly && this.currentPage !== LAST_GUIDE_PAGE) || this.finishing || this.checkingCookies) {
      return;
    }
    this.checkingCookies = true;
    try {
      const cookie: string = await webview.WebCookieManager.fetchCookie('https://x.com');
      const session: XSession = XPrivateStore.parseCookieString(cookie);
      if (!session.isUsable() || this.finishing) {
        return;
      }
      const context: common.Context | undefined = this.getUIContext().getHostContext();
      if (context === undefined) {
        return;
      }
      if (this.addAccount) {
        const known: XAccount | null = accountStore.match(context, session.userId, session.username);
        const knownSession: XAccount | null = accountStore.matchSession(context, session.authToken, session.ct0);
        if (known !== null || knownSession !== null) {
          this.addAccountWaiting = true;
          return;
        }
      }
      if (!xPrivateStore.save(context, session, this.addAccount)) {
        this.loginSaveFailed = true;
        return;
      }
      this.loginSaved = true;
      this.finishGuide();
    } catch (error) {
      return;
    } finally {
      this.checkingCookies = false;
    }
  }

  @Builder
  private GuideIllustration(icon: Resource) {
    Stack() {
      Column()
        .width(122)
        .height(122)
        .borderRadius(61)
        .backgroundColor($r('app.color.bg_field'))
      Column()
        .width(92)
        .height(92)
        .borderRadius(46)
        .backgroundColor($r('app.color.bg_card'))
      SymbolGlyph(icon)
        .fontSize(48)
        .fontColor([this.accentColor])
    }
    .width(136)
    .height(136)
  }

  @Builder
  private FeatureItem(icon: Resource, title: Resource, detail: Resource) {
    Row({ space: 14 }) {
      SymbolGlyph(icon)
        .fontSize(24)
        .fontColor([this.accentColor])
        .width(38)
      Column({ space: 4 }) {
      Text(title).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Subtitle_M'))
          .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
      Text(detail).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_S'))
        .fontColor($r('app.color.text_secondary'))
          .maxLines(3)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(14)
    .borderRadius(16)
    .backgroundColor($r('app.color.bg_card'))
  }

  @Builder
  private FeatureHeading(icon: Resource, title: Resource, detail: Resource) {
    Column({ space: 10 }) {
      this.GuideIllustration(icon)
      Text(title).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Title_L'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .textAlign(TextAlign.Center)
      Text(detail).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)
        .maxLines(3)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private WelcomePage() {
    Column({ space: 22 }) {
      Blank()
      Stack({ alignContent: Alignment.Center }) {
        HdsVisualComponent()
          .scene(HdsSceneType.DUAL_EDGE_FLOW_LIGHT_WITH_BACKGROUND_MASK, this.brandGlowController)
          .width(160)
          .height(160)
          .borderRadius(40)
          .clip(true)
          .onAppear((): void => this.updateBrandGlow(this.currentPage === 0))
          .onDisAppear((): void => this.updateBrandGlow(false))
        Image($r('app.media.ui_brand_foreground'))
          .width(148)
          .height(148)
          .borderRadius(34)
          .objectFit(ImageFit.Contain)
          .shadow({ radius: 24, color: $r('app.color.divider'), offsetY: 12 })
          .draggable(false)
      }
      .width(164)
      .height(164)
      .renderGroup(true)
      Text($r('app.string.onboarding_welcome_title')).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Title_L'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .textAlign(TextAlign.Center)
      Text($r('app.string.onboarding_welcome_detail')).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_L'))
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)
        .maxLines(4)
      Blank()
    }
    .width('100%')
    .height('100%')
    .padding({ left: 30, right: 30 })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private TimelinePage() {
    Scroll() {
      Column({ space: 12 }) {
        this.FeatureHeading($r('sys.symbol.house_fill'), $r('app.string.onboarding_timeline_title'),
          $r('app.string.onboarding_timeline_detail'))
        this.FeatureItem($r('sys.symbol.house_fill'), $r('app.string.onboarding_for_you_title'),
          $r('app.string.onboarding_for_you_detail'))
        this.FeatureItem($r('sys.symbol.person_fill'), $r('app.string.onboarding_following_title'),
          $r('app.string.onboarding_following_detail'))
        this.FeatureItem($r('sys.symbol.bell_fill'), $r('app.string.onboarding_refresh_title'),
          $r('app.string.onboarding_refresh_detail'))
      }
      .width('100%')
      .padding({ left: 24, right: 24, bottom: 16 })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private DiscoverPage() {
    Scroll() {
      Column({ space: 12 }) {
        this.FeatureHeading($r('sys.symbol.magnifyingglass'), $r('app.string.onboarding_explore_title'),
          $r('app.string.onboarding_explore_detail'))
        this.FeatureItem($r('sys.symbol.magnifyingglass'), $r('app.string.onboarding_search_title'),
          $r('app.string.onboarding_search_detail'))
        this.FeatureItem($r('sys.symbol.person_fill'), $r('app.string.onboarding_people_title'),
          $r('app.string.onboarding_people_detail'))
        this.FeatureItem($r('sys.symbol.house_fill'), $r('app.string.onboarding_topics_title'),
          $r('app.string.onboarding_topics_detail'))
      }
      .width('100%')
      .padding({ left: 24, right: 24, bottom: 16 })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private ConversationPage() {
    Scroll() {
      Column({ space: 12 }) {
        this.FeatureHeading($r('sys.symbol.text_bubble_left_2'), $r('app.string.onboarding_connect_title'),
          $r('app.string.onboarding_connect_detail'))
        this.FeatureItem($r('sys.symbol.text_bubble_left_2'), $r('app.string.onboarding_post_title'),
          $r('app.string.onboarding_post_detail'))
        this.FeatureItem($r('sys.symbol.heart_fill'), $r('app.string.onboarding_react_title'),
          $r('app.string.onboarding_react_detail'))
        this.FeatureItem($r('sys.symbol.person_fill'), $r('app.string.onboarding_profile_title'),
          $r('app.string.onboarding_profile_detail'))
      }
      .width('100%')
      .padding({ left: 24, right: 24, bottom: 16 })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private SettingToggle(title: Resource, detail: Resource, enabled: boolean, onChange: (enabled: boolean) => void) {
    Row({ space: 12 }) {
      Column({ space: 4 }) {
        Text(title).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Subtitle_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Text(detail).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('app.color.text_secondary'))
          .maxLines(3)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Toggle({ type: ToggleType.Switch, isOn: enabled })
        .selectedColor(this.accentColor)
        .onChange((value: boolean): void => onChange(value))
    }
    .width('100%')
    .padding(14)
    .borderRadius(16)
    .backgroundColor($r('app.color.bg_card'))
  }

  @Builder
  private MediaPage() {
    Scroll() {
      Column({ space: 12 }) {
        this.FeatureHeading($r('sys.symbol.play_fill'), $r('app.string.onboarding_media_title'),
          $r('app.string.onboarding_media_detail'))
        Text($r('app.string.onboarding_recommended')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_S'))
          .fontColor(this.accentColor)
          .width('100%')
        this.SettingToggle($r('app.string.settings_home_video_mute'),
          $r('app.string.settings_home_video_mute_desc'), this.homeVideoMuted,
          (enabled: boolean): void => this.saveHomeVideoMuted(enabled))
        this.SettingToggle($r('app.string.settings_video_auto_pip'),
          $r('app.string.settings_video_auto_pip_desc'), this.videoAutoPip,
          (enabled: boolean): void => this.saveVideoAutoPip(enabled))
      }
      .width('100%')
      .padding({ left: 24, right: 24, bottom: 16 })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private NotificationPage() {
    Scroll() {
      Column({ space: 12 }) {
        this.FeatureHeading($r('sys.symbol.bell_fill'), $r('app.string.onboarding_notifications_title'),
          $r('app.string.onboarding_notifications_detail'))
        Text($r('app.string.onboarding_recommended')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_S'))
          .fontColor(this.accentColor)
          .width('100%')
        this.SettingToggle($r('app.string.settings_notifications'),
          $r('app.string.settings_notifications_desc'), this.notificationAlerts,
          (enabled: boolean): void => this.saveNotificationAlerts(enabled))
        this.FeatureItem($r('sys.symbol.envelope'), $r('app.string.onboarding_messages_title'),
          $r('app.string.onboarding_messages_detail'))
        this.FeatureItem($r('sys.symbol.bell_fill'), $r('app.string.onboarding_permission_title'),
          $r('app.string.onboarding_permission_detail'))
      }
      .width('100%')
      .padding({ left: 24, right: 24, bottom: 16 })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private TipsPage() {
    Scroll() {
      Column({ space: 12 }) {
        this.FeatureHeading($r('sys.symbol.gearshape'), $r('app.string.onboarding_tips_title'),
          $r('app.string.onboarding_tips_detail'))
        Text($r('app.string.onboarding_recommended')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_S'))
          .fontColor(this.accentColor)
          .width('100%')
        this.SettingToggle($r('app.string.settings_link_in_app'),
          $r('app.string.settings_link_in_app_desc'), this.linksInApp,
          (enabled: boolean): void => this.saveLinksInApp(enabled))
        this.FeatureItem($r('sys.symbol.gearshape'), $r('app.string.onboarding_customize_title'),
          $r('app.string.onboarding_customize_detail'))
        this.FeatureItem($r('sys.symbol.person_fill'), $r('app.string.onboarding_account_title'),
          $r('app.string.onboarding_account_detail'))
      }
      .width('100%')
      .padding({ left: 24, right: 24, bottom: 16 })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private LoginPage() {
    Column({ space: 8 }) {
      Text($r('app.string.onboarding_login_title')).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Title_M'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
      Text(this.alreadySignedIn && !this.loginOnly ? $r('app.string.onboarding_already_signed_in') :
        (this.loginSaveFailed ? $r('app.string.onboarding_login_save_failed') :
          (this.addAccountWaiting ? $r('app.string.accounts_add_waiting') :
            $r('app.string.onboarding_login_hint')))).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .maxLines(2)
      if (this.alreadySignedIn && !this.loginOnly) {
        Column({ space: 22 }) {
          Blank()
          Image($r('app.media.ui_brand_foreground'))
            .width(132)
            .height(132)
            .borderRadius(30)
            .objectFit(ImageFit.Contain)
          SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
            .fontSize(42)
            .fontColor([this.accentColor])
          Blank()
        }
        .width('100%')
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
      } else {
        Web({ src: X_LOGIN_URL, controller: this.webController })
        .width('100%')
        .layoutWeight(1)
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .userAgent(this.userAgent)
        .darkMode(this.webDarkMode())
        .forceDarkAccess(this.displayMode === DISPLAY_MODE_DARK)
        .backgroundColor(pageSurfaceColor(this.displayMode, this.darkSurface))
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
        .onPageEnd((): void => {
          this.checkSessionCookies();
        })
        .onAppear((): void => {
          if (this.loginOnly) {
            this.startLoginPolling();
            this.checkSessionCookies();
          }
        })
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: this.isCompact() ? 0 : 24, right: this.isCompact() ? 0 : 24 })
  }

  @Builder
  private ProgressDot(index: number) {
    Row()
      .width(8)
      .height(8)
      .borderRadius(4)
      .backgroundColor(this.currentPage === index ? this.accentColor : $r('app.color.divider'))
      .scale({ x: this.currentPage === index ? 2.3 : 1, y: 1 })
      .animation({ duration: 260, curve: Curve.EaseOut })
  }

  build(): void {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        if (this.loginOnly) {
          Row() {
            Blank()
            Button($r('app.string.onboarding_close'), { type: ButtonType.Normal })
              .backgroundColor(Color.Transparent)
              .fontColor($r('app.color.text_secondary'))
              .onClick((): void => this.finishGuide())
          }
          .width('100%')
          .height(52)
          .padding({ left: 12, right: 12 })
          Column() {
            this.LoginPage()
          }
          .width('100%')
          .layoutWeight(1)
        } else {
          Row() {
            if (this.currentPage > 0) {
              Button($r('app.string.onboarding_back'), { type: ButtonType.Normal })
                .backgroundColor(Color.Transparent)
                .fontColor($r('app.color.text_secondary'))
                .onClick((): void => this.previousPage())
            }
            Blank()
            Button($r('app.string.onboarding_skip'), { type: ButtonType.Normal })
              .backgroundColor(Color.Transparent)
              .fontColor($r('app.color.text_secondary'))
              .onClick((): void => this.finishGuide())
          }
          .width('100%')
          .height(52)
          .padding({ left: 12, right: 12 })

          Swiper(this.swiperController) {
            this.WelcomePage()
            this.TimelinePage()
            this.DiscoverPage()
            this.ConversationPage()
            this.MediaPage()
            this.NotificationPage()
            this.TipsPage()
            this.LoginPage()
          }
          .width('100%')
          .layoutWeight(1)
          .index(this.currentPage)
          .indicator(false)
          .loop(false)
          .duration(320)
          .onChange((index: number): void => this.onPageChanged(index))

          Row({ space: 10 }) {
            this.ProgressDot(0)
            this.ProgressDot(1)
            this.ProgressDot(2)
            this.ProgressDot(3)
            this.ProgressDot(4)
            this.ProgressDot(5)
            this.ProgressDot(6)
            this.ProgressDot(7)
          }
          .width('100%')
          .height(28)
          .justifyContent(FlexAlign.Center)

          if (this.currentPage < LAST_GUIDE_PAGE) {
            Button($r('app.string.onboarding_next'), { type: ButtonType.Normal })
              .width('75%')
              .constraintSize({ maxWidth: 360 })
              .height(50)
              .fontColor($r('app.color.text_on_accent'))
              .backgroundColor(this.accentColor)
              .borderRadius(16)
              .onClick((): void => this.nextPage())
              .margin({ bottom: 12 })
          } else {
            Button(this.alreadySignedIn ? $r('app.string.onboarding_finish') :
              $r('app.string.onboarding_browse_without_login'), { type: ButtonType.Normal })
            .width('75%')
            .constraintSize({ maxWidth: 360 })
            .height(46)
            .fontColor($r('app.color.text_primary'))
            .backgroundColor($r('app.color.bg_secondary_btn'))
            .borderRadius(16)
            .onClick((): void => this.finishGuide())
            .margin({ bottom: 12 })
          }
        }
      }
      .width('100%')
      .height('100%')
      .padding({
        top: 12,
        bottom: this.isCompact() ? this.navigationIndicatorHeight : 12
      })
      .alignItems(HorizontalAlign.Center)
      .backgroundBlurStyle(sheetMaterialActive(this.sheetMaterialEnabled) ? BlurStyle.NONE : BlurStyle.COMPONENT_THICK)
      .backgroundColor(!SystemMaterialUtil.isApi26OrAbove() ?
        fieldSurfaceColor(this.displayMode, this.darkSurface) : Color.Transparent)
      .borderRadius(28)
      .clip(true)
      .systemMaterial(sheetMaterialActive(this.sheetMaterialEnabled) ? undefined :
        SystemMaterialUtil.immersiveMaterial(2, false, true, false, undefined))
    }
    .width('100%')
    .height('100%')
  }
}
