import { pageTextColor } from '../utils/ThemeColors';
import { appPageBackground } from '../components/PageBackgroundLayer';
import { pageCanvasColor, pageReadingSurfaceColor } from '../utils/ThemeColors';
import { STORAGE_KEY_PAGE_TRANSITION_MODE, DEFAULT_PAGE_TRANSITION_MODE } from '../services/PageTransitionSettingsStore';
import { pageSystemTransition, PageTransitionMotion } from '../utils/PageTransition';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { common } from '@kit.AbilityKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { uiMaterial } from '@kit.ArkUI';
import { HdsNavDestination, HdsNavDestinationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { SpaceInfoRouteParam } from '../models/Space';
import { spacePlayback } from '../services/SpacePlayback';
import { spacePreferencesStore } from '../services/SpacePreferencesStore';
import { destinationTitleBarStyle } from '../utils/DestinationTitleBar';
import { openExternalLink } from '../utils/PostEntities';
import { pageSurfaceColor } from '../utils/ThemeColors';
import { materialModifier } from '../utils/SystemMaterial';

@Builder
export function SpaceInfoBuilder(): void { SpaceInfo(); }

@Component
struct SpaceInfo {
  @StorageProp('harmonyx.page_background') private pageBackgroundValue: string = '';
  @State private pageMotion: PageTransitionMotion = new PageTransitionMotion();
  @StorageProp(STORAGE_KEY_PAGE_TRANSITION_MODE) private pageTransitionMode: string = DEFAULT_PAGE_TRANSITION_MODE;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp('harmonyx.status_bar_height') statusBarHeight: number = 0;
  @StorageProp('harmonyx.navigation_indicator_height') navigationIndicatorHeight: number = 0;
  @StorageProp('harmonyx.display_mode') themeDisplayMode: string = '';
  @StorageProp('harmonyx.dark_surface') themeDarkSurface: string = '';
  @StorageLink('harmonyx.title_bar_style_mode') titleBarStyleMode: number = 0;
  @State private kind: string = 'welcome';
  private param: SpaceInfoRouteParam = { kind: 'welcome' };
  private scroller: Scroller = new Scroller();
  aboutToAppear(): void {
    const params: SpaceInfoRouteParam[] = this.pageStack.getParamByName('SpaceInfo') as SpaceInfoRouteParam[];
    if (params?.length > 0) { this.param = params[params.length - 1]; this.kind = this.param.kind; }
  }
  private acknowledge(): void {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    spacePreferencesStore.acknowledge(context, this.kind);
    if (this.param.listenAfter && this.param.room !== undefined) { spacePlayback.listen(context, this.param.room); }
    this.pageStack.pop();
  }
  @Builder
  private Explanation(icon: Resource, title: Resource, body: Resource): void {
    Row({ space: 16 }) {
      SymbolGlyph(icon).fontSize(25).fontColor([$r('app.color.space_accent')]).margin({ top: 2 })
      Column({ space: 6 }) {
        Text(title).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontWeight(FontWeight.Bold).fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent))
        Text(body).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)).lineHeight(23)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }.width('100%').alignItems(VerticalAlign.Top)
  }
  build(): void {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        appPageBackground()
      Column() {
        Scroll(this.scroller) {
          Column({ space: 28 }) {
            SymbolGlyph(this.kind === 'recording' ? $r('sys.symbol.mic_badge_recordingtape') : $r('sys.symbol.music_note_mic'))
              .fontSize(56).fontColor([$r('app.color.space_accent')]).margin({ top: 24, bottom: 10 })
            Column({ space: 8 }) {
              Text(this.kind === 'recording' ? $r('app.string.spaces_recording_title') : $r('app.string.spaces_welcome_title')).fontFamily(this.appFontFamily)
                .fontSize($r('app.float.space_room_title_size')).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
              Text(this.kind === 'recording' ? $r('app.string.spaces_recording_subtitle') : $r('app.string.spaces_welcome_subtitle')).fontFamily(this.appFontFamily)
                .fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_secondary')).textAlign(TextAlign.Center)
            }.width('100%').margin({ bottom: 12 })
            if (this.kind === 'recording') {
              this.Explanation($r('sys.symbol.mic'), $r('app.string.spaces_recording_speakers'), $r('app.string.spaces_recording_speakers_body'))
              this.Explanation($r('sys.symbol.arrowshape_turn_up_right'), $r('app.string.spaces_recording_replay'), $r('app.string.spaces_recording_replay_body'))
            } else {
              this.Explanation($r('sys.symbol.globe_badge_message'), $r('app.string.spaces_public_title'), $r('app.string.spaces_public_body'))
              this.Explanation($r('sys.symbol.headphones'), $r('app.string.spaces_listen_only_title'), $r('app.string.spaces_listen_only_body'))
              this.Explanation($r('sys.symbol.checkmark_shield'), $r('app.string.spaces_manage_title'), $r('app.string.spaces_manage_body'))
            }
            Button($r('app.string.spaces_learn_more')).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.space_accent'))
              .backgroundColor(Color.Transparent).onClick((): void => {
                openExternalLink(getContext(this) as common.UIAbilityContext, 'https://help.x.com/en/using-x/spaces');
              })
          }.width('100%').constraintSize({ maxWidth: $r('app.float.space_content_width') })
            .padding({ left: 24, right: 24, bottom: 24 })
        }.width('100%').layoutWeight(1).scrollBar(BarState.Off)
        Button(this.param.listenAfter ? $r('app.string.spaces_listen') : $r('app.string.spaces_got_it'))
          .width('90%').height($r('app.float.space_listen_height')).fontSize($r('sys.float.Body_L'))
          .fontWeight(FontWeight.Bold).fontColor($r('app.color.space_card_text')).backgroundColor($r('app.color.space_button'))
          .margin({ top: 12, bottom: this.navigationIndicatorHeight + 16 }).onClick((): void => this.acknowledge())
      }.width('100%').height('100%').padding({ top: this.statusBarHeight + 60 })
    
      }.width('100%').height('100%')
    }
    .scale({ x: this.pageMotion.scale, y: this.pageMotion.scale })
    .opacity(this.pageMotion.opacity)
    .onReady((context: NavDestinationContext): void => { this.pageMotion.attach(context); })
    .systemTransition(pageSystemTransition(this.pageTransitionMode)).titleMode(HdsNavDestinationTitleMode.MINI).hideBackButton(false).bindToScrollable([this.scroller])
      .titleBar({ avoidLayoutSafeArea: true, content: { title: { mainTitle: $r('app.string.spaces_about') } },
        style: destinationTitleBarStyle(ScrollEffectType.IMMERSIVE_GRADIENT_BLUR,
          this.themeDisplayMode, this.themeDarkSurface, this.titleBarStyleMode) })
      .backgroundColor(pageCanvasColor(this.themeDisplayMode, this.themeDarkSurface, this.pageBackgroundValue))
      .attributeModifier(materialModifier(deviceInfo.apiAvailable('26.0.0') ? new uiMaterial.ImmersiveMaterial({
        style: uiMaterial.ImmersiveStyle.REGULAR, applyShadow: true, colorInvert: true }) : undefined))
  }
}
