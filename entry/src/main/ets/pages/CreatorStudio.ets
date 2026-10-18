import { pageTextColor } from '../utils/ThemeColors';
import { appPageBackground } from '../components/PageBackgroundLayer';
import { pageCanvasColor, pageReadingSurfaceColor } from '../utils/ThemeColors';
import { STORAGE_KEY_PAGE_TRANSITION_MODE, DEFAULT_PAGE_TRANSITION_MODE } from '../services/PageTransitionSettingsStore';
import { pageSystemTransition, PageTransitionMotion } from '../utils/PageTransition';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { HdsNavDestination, HdsNavDestinationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import type { ProfileWebRouteParam } from './ProfileWeb';
import { pageSurfaceColor } from '../utils/ThemeColors';
import { destinationTitleBarStyle } from '../utils/DestinationTitleBar';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';

@Builder
export function CreatorStudioBuilder(): void { CreatorStudio(); }

@Component
struct CreatorStudio {
  @StorageProp('harmonyx.page_background') private pageBackgroundValue: string = '';
  @State private pageMotion: PageTransitionMotion = new PageTransitionMotion();
  @StorageProp(STORAGE_KEY_PAGE_TRANSITION_MODE) private pageTransitionMode: string = DEFAULT_PAGE_TRANSITION_MODE;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp('harmonyx.display_mode') displayMode: string = '';
  @StorageProp('harmonyx.dark_surface') darkSurface: string = '';
  @StorageProp('harmonyx.status_bar_height') statusBarHeight: number = 0;
  @StorageProp('harmonyx.title_bar_style_mode') titleBarStyleMode: number = 0;
  @StorageProp('harmonyx.desktop_layout') desktopLayoutEnabled: boolean = false;
  @StorageProp('harmonyx.breakpoint') windowBreakpoint: string = 'sm';
  private scroller: Scroller = new Scroller();
  private open(url: string): void {
    const param: ProfileWebRouteParam = { url: url, title: 'Creator Studio' };
    this.pageStack.pushPath({ name: 'ProfileWeb', param: param });
  }

  @Builder
  private Tool(title: Resource, icon: Resource, url: string): void {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 24 }) {
        SymbolGlyph(icon).fontSize(26).fontColor([pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent)])
        Text(title).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontWeight(FontWeight.Bold)
          .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent)).layoutWeight(1).textAlign(TextAlign.Start)
        SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(16).fontColor([pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)])
      }.width('100%')
    }.width('100%').height(76).padding({ left: 24, right: 24 }).backgroundColor(Color.Transparent)
      .onClick((): void => this.open(url))
  }

  build(): void {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        appPageBackground()
      Scroll(this.scroller) {
        Column({ space: 12 }) {
          Text($r('app.string.desktop_studio_desc')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
            .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)).width('100%').padding(24)
          this.Tool($r('app.string.desktop_studio_rewards'), $r('sys.symbol.gift'), 'https://x.com/i/monetization')
          this.Tool($r('app.string.desktop_studio_subscriptions'), $r('sys.symbol.person_badge_plus'), 'https://x.com/i/monetization/subscriptions')
          this.Tool($r('app.string.desktop_studio_live'), $r('sys.symbol.video'), 'https://studio.x.com/')
          this.Tool($r('app.string.desktop_studio_analytics'), $r('sys.symbol.waveform'), 'https://x.com/i/account_analytics')
          this.Tool($r('app.string.desktop_studio_support'), $r('sys.symbol.message'), 'https://help.x.com/en/using-x/creator-revenue-sharing')
        }.width('100%').padding({ top: this.desktopLayoutEnabled && ResponsiveLayout.isLarge(this.windowBreakpoint) ?
          0 : this.statusBarHeight + 60, bottom: 24 })
      }.width('100%').height('100%').scrollBar(BarState.Auto).align(Alignment.TopStart)
        .clip(!(this.desktopLayoutEnabled && ResponsiveLayout.isLarge(this.windowBreakpoint)))
    
      }.width('100%').height('100%')
    }
    .scale({ x: this.pageMotion.scale, y: this.pageMotion.scale })
    .opacity(this.pageMotion.opacity)
    .onReady((context: NavDestinationContext): void => { this.pageMotion.attach(context); })
    .systemTransition(pageSystemTransition(this.pageTransitionMode)).titleMode(HdsNavDestinationTitleMode.MINI)
      .titleBar({ avoidLayoutSafeArea: true,
        enableComponentSafeArea: this.desktopLayoutEnabled && ResponsiveLayout.isLarge(this.windowBreakpoint),
        content: { title: { mainTitle: $r('app.string.side_creator_studio') } },
        style: destinationTitleBarStyle(ScrollEffectType.IMMERSIVE_GRADIENT_BLUR,
          this.displayMode, this.darkSurface, this.titleBarStyleMode) })
      .bindToScrollable([this.scroller])
      .backgroundColor(pageCanvasColor(this.displayMode, this.darkSurface, this.pageBackgroundValue))
      .onBackPressed((): boolean => { this.pageStack.pop(); return true; })
  }
}
