import { STORAGE_KEY_REDUCE_MOTION } from '../services/MotionSettingsStore';
import { appPageBackground } from '../components/PageBackgroundLayer';
import { pageCanvasColor, pageReadingSurfaceColor } from '../utils/ThemeColors';
import { HuaweiAccountSheet } from './HuaweiAccountSheet';
import { HUAWEI_ACCOUNT_SIGNED_IN, HUAWEI_ACCOUNT_AVATAR } from '../services/HuaweiAccountService';
import { sheetMaterialOptions } from '../utils/SheetMaterial';
import { STORAGE_KEY_SHEET_MATERIAL_ENABLED, STORAGE_KEY_SHEET_MATERIAL_LEVEL,
  DEFAULT_SHEET_MATERIAL_ENABLED, DEFAULT_SHEET_MATERIAL_LEVEL } from '../services/SheetMaterialSettingsStore';
import { STORAGE_KEY_PAGE_TRANSITION_MODE, DEFAULT_PAGE_TRANSITION_MODE } from '../services/PageTransitionSettingsStore';
import { pageSystemTransition, PageTransitionMotion, officialPageTransition } from '../utils/PageTransition';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { HdsNavigation, HdsNavDestination, HdsNavigationTitleMode, DividerShowType } from '@kit.UIDesignKit';
import { SettingsHome } from '../pages/Settings';
import type { AccountPrivacyRouteParam } from '../models/AccountPrivacy';
import { pageSurfaceColor } from '../utils/ThemeColors';
import { rootTitleBarStyle, titleBarGlassMaterial } from '../utils/DestinationTitleBar';
import { DEFAULT_TITLE_BAR_GLASS_MATERIAL_LEVEL, STORAGE_KEY_TITLE_BAR_GLASS_MATERIAL_LEVEL } from '../services/AppearanceStore';

@Component
export struct DesktopSettingsHost {
  @StorageProp(STORAGE_KEY_REDUCE_MOTION) @Watch('onMotionPreferenceChanged') private reduceMotion: boolean = false;

  private onMotionPreferenceChanged(): void {
    this.pageStack.disableAnimation(this.reduceMotion);
  }

  @StorageProp('harmonyx.page_background') private pageBackgroundValue: string = '';
  @State private huaweiAccountOpen: boolean = false;
  @StorageProp(HUAWEI_ACCOUNT_SIGNED_IN) private huaweiSignedIn: boolean = false;
  @StorageProp(HUAWEI_ACCOUNT_AVATAR) private huaweiAvatar: string = '';
  @StorageProp(STORAGE_KEY_SHEET_MATERIAL_ENABLED) private accountSheetMaterialEnabled: boolean = DEFAULT_SHEET_MATERIAL_ENABLED;
  @StorageProp(STORAGE_KEY_SHEET_MATERIAL_LEVEL) private accountSheetMaterialLevel: number = DEFAULT_SHEET_MATERIAL_LEVEL;
  @State private settingsRootMotion: PageTransitionMotion = new PageTransitionMotion();
  @State private pageMotion: PageTransitionMotion = new PageTransitionMotion();
  @StorageProp(STORAGE_KEY_PAGE_TRANSITION_MODE) private pageTransitionMode: string = DEFAULT_PAGE_TRANSITION_MODE;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  // Settings destinations consume the nearest stack, independent of the app's root navigation.
  @Provide({ allowOverride: 'pageStack' }) pageStack: NavPathStack = new NavPathStack();
  @BuilderParam destinationBuilder: (name: string, param: Object) => void;
  @StorageProp('harmonyx.display_mode') displayMode: string = '';
  @StorageProp('harmonyx.dark_surface') darkSurface: string = '';
  @StorageProp('harmonyx.title_bar_style_mode') titleBarStyleMode: number = 0;
  @StorageProp(STORAGE_KEY_TITLE_BAR_GLASS_MATERIAL_LEVEL)
  titleBarGlassMaterialLevel: number = DEFAULT_TITLE_BAR_GLASS_MATERIAL_LEVEL;
  @State private detailOpen: boolean = false;
  private outerStack: NavPathStack | null = null;
  private initialized: boolean = false;
  private settingsScroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.onMotionPreferenceChanged();
    this.pageStack.setInterception({
      didShow: (): void => { this.detailOpen = this.pageStack.size() > 0; }
    });
  }

  @Builder
  private SettingsTitle(): void {
    Row() {
      Text($r('app.string.settings_title')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Title_M')).fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
    }.width('100%').height(56).padding({ left: 16, right: 16 })
      .systemMaterial(titleBarGlassMaterial(this.titleBarStyleMode, this.titleBarGlassMaterialLevel))
  }

  build(): void {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        appPageBackground()
      HdsNavigation(this.pageStack) {
        SettingsHome({ embedded: true, scroller: this.settingsScroller })
          .scale({ x: this.settingsRootMotion.scale, y: this.settingsRootMotion.scale })
          .opacity(this.settingsRootMotion.opacity)
      }
      .customNavContentTransition((from: NavContentInfo, to: NavContentInfo,
        operation: NavigationOperation): NavigationAnimatedTransition | undefined =>
        officialPageTransition(this.getUIContext(), this.settingsRootMotion, this.pageTransitionMode, from, to, operation))
      .mode(this.detailOpen ? NavigationMode.Split : NavigationMode.Stack)
      .navBarWidth('42%').minContentWidth(360)
      .titleMode(HdsNavigationTitleMode.MINI)
      .titleBar({ avoidLayoutSafeArea: true, enableComponentSafeArea: true,
        content: { stackBuilder: (): void => { this.SettingsTitle(); }, divider: { showType: DividerShowType.OFF },
          menu: { value: [{ content: {
            icon: this.huaweiSignedIn && this.huaweiAvatar.length > 0 ? this.huaweiAvatar : $r('sys.symbol.person_crop_circle_fill'),
            label: $r('app.string.huawei_account_title'), componentId: 'desktop-settings-huawei-account',
            action: (): void => { this.huaweiAccountOpen = true; }
          } }] } },
        style: rootTitleBarStyle(this.displayMode, this.darkSurface, this.titleBarStyleMode, true) })
      .bindToScrollable([this.settingsScroller])
      .hideBackButton(true).navDestination(this.destinationBuilder)
      .width('100%').height('100%')
    
      }.width('100%').height('100%')
    }
    .bindSheet($$this.huaweiAccountOpen, this.HuaweiAccountContent(), sheetMaterialOptions({
      height: this.huaweiSignedIn ? 560 : 380, preferType: SheetType.CENTER, width: 480, showClose: true, dragBar: false,
      backgroundColor: pageSurfaceColor(this.displayMode, this.darkSurface),
      onDisappear: (): void => { this.huaweiAccountOpen = false; }
    }, this.accountSheetMaterialEnabled, this.accountSheetMaterialLevel))
    .scale({ x: this.pageMotion.scale, y: this.pageMotion.scale })
    .opacity(this.pageMotion.opacity)
    .systemTransition(pageSystemTransition(this.pageTransitionMode))
    .hideTitleBar(true)
    .backgroundColor(pageCanvasColor(this.displayMode, this.darkSurface, this.pageBackgroundValue))
    .onReady((context: NavDestinationContext): void => {
      this.pageMotion.attach(context); this.outerStack = context.pathStack; })
    .onShown((): void => {
      if (!this.initialized) {
        this.initialized = true;
        const section: string = AppStorage.get<string>('harmonyx.desktop_settings_section') ?? 'account';
        const param: AccountPrivacyRouteParam = { section: section };
        this.pageStack.pushPath({ name: section === 'account' || section === 'privacy' || section === 'security' ?
          'AccountPrivacy' : 'SettingsSection', param: param }, false);
        this.detailOpen = true;
      }
    })
    .onBackPressed((): boolean => {
      if (this.pageStack.size() > 1) { this.pageStack.pop(); }
      else { this.outerStack?.pop(); }
      return true;
    })
  }

  @Builder
  private HuaweiAccountContent(): void {
    HuaweiAccountSheet({ onClose: (): void => { this.huaweiAccountOpen = false; } })
  }
}
