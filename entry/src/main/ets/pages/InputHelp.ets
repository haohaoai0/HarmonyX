import { uiMaterial } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';
import { HdsNavDestination, HdsNavDestinationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { ROOT_INPUT_SHORTCUTS, InputShortcut } from '../models/InputShortcutCatalog';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { pageBackgroundActive } from '../services/PageBackgroundStore';
import { STORAGE_KEY_PAGE_TRANSITION_MODE, DEFAULT_PAGE_TRANSITION_MODE } from '../services/PageTransitionSettingsStore';
import { PageTransitionMotion, pageSystemTransition } from '../utils/PageTransition';
import { destinationTitleBarStyle } from '../utils/DestinationTitleBar';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';
import { backInputKey } from '../utils/InputSupport';
import { appPageBackground } from '../components/PageBackgroundLayer';
import { pageCanvasColor, pageReadingSurfaceColor, pageTextColor, cardSurfaceColor } from '../utils/ThemeColors';
import { materialModifier } from '../utils/SystemMaterial';

@Builder
export function InputHelpBuilder(): void { InputHelp(); }

@Component
struct InputHelp {
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp('harmonyx.page_background') private pageBackgroundValue: string = '';
  @StorageProp('harmonyx.display_mode') private themeDisplayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private themeDarkSurface: string = '';
  @StorageProp('harmonyx.title_bar_style_mode') private titleBarStyleMode: number = 0;
  @StorageProp('harmonyx.status_bar_height') private statusBarHeight: number = 0;
  @StorageProp('harmonyx.navigation_indicator_height') private navigationIndicatorHeight: number = 0;
  @StorageProp(STORAGE_KEY_PAGE_TRANSITION_MODE) private pageTransitionMode: string = DEFAULT_PAGE_TRANSITION_MODE;
  @State private pageMotion: PageTransitionMotion = new PageTransitionMotion();
  private scroller: Scroller = new Scroller();

  private surface(): ResourceColor {
    return pageReadingSurfaceColor(cardSurfaceColor(this.themeDisplayMode, this.themeDarkSurface), this.pageBackgroundValue);
  }

  private foreground(secondary: boolean = false): ResourceColor {
    return pageTextColor(secondary ? $r('app.color.text_secondary') : $r('app.color.text_primary'),
      this.pageBackgroundValue, this.surface());
  }

  private material(): uiMaterial.Material | undefined {
    if (!deviceInfo.apiAvailable('26.0.0') || pageBackgroundActive(this.pageBackgroundValue)) { return undefined; }
    return new uiMaterial.ImmersiveMaterial({ style: uiMaterial.ImmersiveStyle.REGULAR, applyShadow: true, colorInvert: true });
  }

  @Builder
  private Shortcut(keys: Resource, label: Resource): void {
    Column({ space: 5 }) {
      Text(keys).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontWeight(FontWeight.Medium)
        .fontColor(this.foreground()).width('100%')
      Text(label).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor(this.foreground(true))
        .width('100%')
    }.width('100%').padding({ top: 12, bottom: 12 }).alignItems(HorizontalAlign.Start)
  }

  @Builder
  private SectionTitle(title: Resource): void {
    Text(title).fontFamily(this.appFontFamily).fontSize($r('sys.float.Title_S')).fontWeight(FontWeight.Bold)
      .fontColor(this.foreground()).width('100%').padding({ bottom: 8 })
  }

  build(): void {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        appPageBackground()
        Scroll(this.scroller) {
          Column({ space: 18 }) {
            Column() {
              this.SectionTitle($r('app.string.input_main_title'))
              Text($r('app.string.input_main_scope')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
                .fontColor(this.foreground(true)).width('100%')
              ForEach(ROOT_INPUT_SHORTCUTS, (shortcut: InputShortcut) => {
                this.Shortcut(shortcut.keys, shortcut.label)
              }, (shortcut: InputShortcut): string => shortcut.id)
            }.width('100%').padding(18).borderRadius(20).backgroundColor(this.surface())
            Column() {
              this.SectionTitle($r('app.string.input_keyboard_title'))
              this.Shortcut($r('app.string.input_key_focus'), $r('app.string.input_focus'))
              this.Shortcut($r('app.string.input_key_activate'), $r('app.string.input_activate'))
              this.Shortcut($r('app.string.input_key_submit'), $r('app.string.input_submit'))
              this.Shortcut($r('app.string.input_key_back'), $r('app.string.input_back'))
              this.Shortcut($r('app.string.input_key_photo'), $r('app.string.input_photo'))
              this.Shortcut($r('app.string.input_key_video'), $r('app.string.input_video'))
              this.Shortcut($r('app.string.input_key_playback'), $r('app.string.input_playback'))
            }.width('100%').padding(18).borderRadius(20).backgroundColor(this.surface())
            Column() {
              this.SectionTitle($r('app.string.input_pointer_title'))
              Text($r('app.string.input_pointer')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L'))
                .fontColor(this.foreground()).width('100%').lineHeight(24)
              Text($r('app.string.input_trackpad')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L'))
                .fontColor(this.foreground()).width('100%').lineHeight(24).margin({ top: 12 })
            }.width('100%').padding(18).borderRadius(20).backgroundColor(this.surface())
          }.width('100%').constraintSize({ maxWidth: 720 }).padding({ left: 20, right: 20,
            top: this.statusBarHeight + 88, bottom: this.navigationIndicatorHeight + 28 })
        }.width('100%').height('100%').scrollBar(BarState.Auto)
      }.width('100%').height('100%')
    }
    .scale({ x: this.pageMotion.scale, y: this.pageMotion.scale }).opacity(this.pageMotion.opacity)
    .onReady((context: NavDestinationContext): void => { this.pageMotion.attach(context); })
    .systemTransition(pageSystemTransition(this.pageTransitionMode))
    .titleMode(HdsNavDestinationTitleMode.MINI).hideBackButton(false)
    .onBackPressed((): boolean => { ResponsiveLayout.closeContentDestination(this.pageStack); return true; })
    .onKeyEvent((event: KeyEvent): boolean => backInputKey(event,
      (): void => ResponsiveLayout.closeContentDestination(this.pageStack)))
    .bindToScrollable([this.scroller])
    .titleBar({ avoidLayoutSafeArea: true, content: { title: { mainTitle: $r('app.string.input_help_title') } },
      style: destinationTitleBarStyle(ScrollEffectType.GRADIENT_BLUR, this.themeDisplayMode,
        this.themeDarkSurface, this.titleBarStyleMode) })
    .backgroundColor(pageCanvasColor(this.themeDisplayMode, this.themeDarkSurface, this.pageBackgroundValue))
    .attributeModifier(materialModifier(this.material()));
  }
}
