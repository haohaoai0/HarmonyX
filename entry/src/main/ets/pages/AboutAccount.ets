import { common } from '@kit.AbilityKit';
import { HdsNavDestination, HdsNavDestinationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import type { TweetAuthor } from '../models/Tweet';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { AccountAbout, ProfileAccountData } from '../services/ProfileAccountData';
import { XPrivateResult, xPrivateClient } from '../services/XPrivateClient';
import { STORAGE_KEY_PAGE_TRANSITION_MODE, DEFAULT_PAGE_TRANSITION_MODE } from '../services/PageTransitionSettingsStore';
import { appPageBackground } from '../components/PageBackgroundLayer';
import { SpaceAwareAvatar } from '../components/SpaceAwareAvatar';
import { destinationTitleBarStyle } from '../utils/DestinationTitleBar';
import { pageSystemTransition, PageTransitionMotion } from '../utils/PageTransition';
import { pageCanvasColor, fieldSurfaceColor, pageTextColor } from '../utils/ThemeColors';
import { verificationBadgeColor } from '../utils/UserIdentity';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';
import { DesktopLayout } from '../utils/DesktopLayout';
import { openExternalLink } from '../utils/PostEntities';
import { scrollFrame, scrollStarted, scrollStopped, stopScrollOnTouch } from '../utils/ScrollInteraction';

export interface AboutAccountRouteParam {
  author: TweetAuthor;
  joined: string;
}

@Builder
export function AboutAccountBuilder(): void { AboutAccountPage(); }

@Component
struct AboutAccountPage {
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp('harmonyx.page_background') private pageBackgroundValue: string = '';
  @StorageProp('harmonyx.display_mode') private displayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private darkSurface: string = '';
  @StorageProp('harmonyx.title_bar_style_mode') private titleBarStyleMode: number = 0;
  @StorageProp('harmonyx.status_bar_height') private statusBarHeight: number = 0;
  @StorageProp('harmonyx.navigation_indicator_height') private bottomInset: number = 0;
  @StorageProp('harmonyx.desktop_layout') private desktopLayoutEnabled: boolean = false;
  @StorageProp('harmonyx.breakpoint') private breakpoint: string = 'sm';
  @StorageProp('harmonyx.accent_color') private accentColor: string = '#007DFF';
  @StorageProp(STORAGE_KEY_PAGE_TRANSITION_MODE) private transitionMode: string = DEFAULT_PAGE_TRANSITION_MODE;
  @State private motion: PageTransitionMotion = new PageTransitionMotion();
  @State private author: TweetAuthor | null = null;
  @State private joined: string = '';
  @State private data: AccountAbout | null = null;
  @State private loading: boolean = false;
  @State private failed: boolean = false;
  private scroller: Scroller = new Scroller();
  private alive: boolean = true;

  aboutToAppear(): void {
    const params: AboutAccountRouteParam[] = this.pageStack.getParamByName('AboutAccount') as AboutAccountRouteParam[];
    if (params.length > 0) {
      this.author = params[params.length - 1].author;
      this.joined = params[params.length - 1].joined;
      void this.load();
    }
  }

  aboutToDisappear(): void { this.alive = false; }

  private async load(): Promise<void> {
    if (this.loading || this.author === null) { return; }
    this.loading = true;
    this.failed = false;
    try {
      const result: XPrivateResult = await xPrivateClient.userAbout(this.author.username);
      if (!this.alive) { return; }
      this.data = result.ok ? ProfileAccountData.about(result.body) : null;
      this.failed = this.data === null;
    } catch (error) { if (this.alive) { this.failed = true; } }
    finally { if (this.alive) { this.loading = false; } }
  }

  private foreground(secondary: boolean = false): ResourceColor {
    return pageTextColor(secondary ? $r('app.color.text_secondary') : $r('app.color.text_primary'), this.pageBackgroundValue,
      fieldSurfaceColor(this.displayMode, this.darkSurface));
  }

  @Builder
  private InfoRow(icon: Resource, title: Resource, value: ResourceStr): void {
    Row({ space: 16 }) {
      Stack() { SymbolGlyph(icon).fontSize(22).fontColor([this.accentColor]) }
        .width(44).height(44).borderRadius(14).backgroundColor(fieldSurfaceColor(this.displayMode, this.darkSurface))
      Column({ space: 5 }) {
        Text(title).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor(this.foreground(true))
        Text(value === '' ? $r('app.string.profile_info_unavailable') : value)
          .fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontWeight(FontWeight.Medium)
          .fontColor(this.foreground()).width('100%').copyOption(CopyOptions.LocalDevice)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }.width('100%').padding({ top: 16, bottom: 16 })
  }

  @Builder
  private Identity(): void {
    if (this.author !== null) {
      Column({ space: 12 }) {
        SpaceAwareAvatar({ userId: this.author.id, url: this.author.avatarUrl ?? '', avatarSize: 80, radius: 40,
          verifiedType: this.author.verifiedType ?? '', avatarShape: this.author.avatarShape ?? '',
          fallbackText: this.author.name.substring(0, 1), fallbackColor: this.author.avatarColor })
        Row({ space: 6 }) {
          Text(this.author.name).fontFamily(this.appFontFamily).fontSize($r('sys.float.Title_L')).fontWeight(FontWeight.Bold)
            .fontColor(this.foreground()).maxLines(2).textAlign(TextAlign.Center).flexShrink(1)
          if (this.author.verified) {
            SymbolGlyph($r('sys.symbol.checkmark_circle_fill')).fontSize(20)
              .fontColor([verificationBadgeColor(this.author.verifiedType ?? '', this.accentColor)])
          }
        }.width('100%').justifyContent(FlexAlign.Center)
        Text('@' + this.author.username).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontColor(this.foreground(true))
      }.width('100%').padding({ top: 24, bottom: 28, left: 20, right: 20 })
    }
  }

  build(): void {
    HdsNavDestination() {
      Stack() {
        appPageBackground()
        Scroll(this.scroller) {
          Column({ space: 12 }) {
            this.Identity()
            Column() {
              this.InfoRow($r('sys.symbol.calendar'), $r('app.string.profile_join_date'), this.joined)
              Divider().color($r('app.color.divider')).opacity(0.5)
              this.InfoRow($r('sys.symbol.location_up'), $r('app.string.profile_account_country'), this.data?.country ?? '')
              if (this.data?.locationAccurate === false) {
                Text($r('app.string.profile_location_approximate')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S'))
                  .fontColor(this.foreground(true)).width('100%').padding({ left: 60, bottom: 12 })
              }
              Divider().color($r('app.color.divider')).opacity(0.5)
              this.InfoRow($r('sys.symbol.checkmark_circle'), $r('app.string.profile_verified'),
                this.author?.verified === true ? $r('app.string.profile_verified_yes') : $r('app.string.profile_verified_no'))
              Divider().color($r('app.color.divider')).opacity(0.5)
              this.InfoRow($r('sys.symbol.globe_badge_message'), $r('app.string.profile_connected_via'), this.data?.source ?? '')
            }.width('100%').padding({ left: 20, right: 20 }).borderRadius(24)
              .backgroundColor(fieldSurfaceColor(this.displayMode, this.darkSurface))
            if (this.loading) { LoadingProgress().width(28).height(28).color(this.accentColor) }
            if (this.failed) {
              Text($r('app.string.profile_about_failed')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
                .fontColor(this.foreground(true)).textAlign(TextAlign.Center)
              Button($r('app.string.profile_retry')).backgroundColor(Color.Transparent).fontColor(this.accentColor)
                .onClick((): void => { void this.load(); })
            }
            Button($r('app.string.profile_get_verified')).width('100%').height(48).borderRadius(24)
              .backgroundColor(this.accentColor).fontColor($r('app.color.text_on_brand'))
              .onClick((): void => openExternalLink(this.getUIContext().getHostContext() as common.UIAbilityContext, 'https://x.com/i/premium_sign_up'))
          }.width('100%').constraintSize({ maxWidth: 600 }).padding({ left: 16, right: 16,
            top: DesktopLayout.active(this.desktopLayoutEnabled, this.breakpoint) ? 12 : this.statusBarHeight + 64,
            bottom: this.bottomInset + 24 })
        }.width('100%').height('100%').scrollBar(BarState.Off)
          .onScrollStart((): void => scrollStarted(this.scroller)).onScrollStop((): void => scrollStopped(this.scroller))
          .onScrollFrameBegin((offset: number, state: ScrollState): OnScrollFrameBeginHandlerResult => scrollFrame(this.scroller, offset, state))
          .onTouchIntercept((event: TouchEvent): HitTestMode => stopScrollOnTouch(event, this.scroller))
      }.width('100%').height('100%')
    }.titleMode(HdsNavDestinationTitleMode.MINI).hideBackButton(false)
      .bindToScrollable([this.scroller])
      .titleBar({ avoidLayoutSafeArea: true, enableComponentSafeArea: DesktopLayout.active(this.desktopLayoutEnabled, this.breakpoint),
        content: { title: { mainTitle: $r('app.string.profile_about_title') } },
        style: destinationTitleBarStyle(ScrollEffectType.GRADIENT_BLUR, this.displayMode, this.darkSurface, this.titleBarStyleMode) })
      .scale({ x: this.motion.scale, y: this.motion.scale }).opacity(this.motion.opacity)
      .onReady((context: NavDestinationContext): void => this.motion.attach(context))
      .systemTransition(pageSystemTransition(this.transitionMode))
      .onBackPressed((): boolean => { ResponsiveLayout.closeContentDestination(this.pageStack); return true; })
      .backgroundColor(pageCanvasColor(this.displayMode, this.darkSurface, this.pageBackgroundValue))
  }
}
