import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { HdsNavigation, HdsNavDestination, HdsNavigationTitleMode, DividerShowType } from '@kit.UIDesignKit';
import { SettingsHome } from '../pages/Settings';
import type { AccountPrivacyRouteParam } from '../models/AccountPrivacy';
import { pageSurfaceColor } from '../utils/ThemeColors';
import { rootTitleBarStyle, titleBarGlassMaterial } from '../utils/DestinationTitleBar';
import { DEFAULT_TITLE_BAR_GLASS_MATERIAL_LEVEL, STORAGE_KEY_TITLE_BAR_GLASS_MATERIAL_LEVEL } from '../services/AppearanceStore';

@Component
export struct DesktopSettingsHost {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  // Settings destinations consume the nearest stack, independent of the app's root navigation.
  @Provide({ allowOverride: 'pageStack' }) pageStack: NavPathStack = new NavPathStack();
  @BuilderParam destinationBuilder: (name: string) => void;
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
      HdsNavigation(this.pageStack) {
        SettingsHome({ embedded: true, scroller: this.settingsScroller })
      }
      .mode(this.detailOpen ? NavigationMode.Split : NavigationMode.Stack)
      .navBarWidth('42%').minContentWidth(360)
      .titleMode(HdsNavigationTitleMode.MINI)
      .titleBar({ avoidLayoutSafeArea: true, enableComponentSafeArea: true,
        content: { stackBuilder: (): void => { this.SettingsTitle(); }, divider: { showType: DividerShowType.OFF } },
        style: rootTitleBarStyle(this.displayMode, this.darkSurface, this.titleBarStyleMode, true) })
      .bindToScrollable([this.settingsScroller])
      .hideBackButton(true).navDestination(this.destinationBuilder)
      .width('100%').height('100%')
    }
    .hideTitleBar(true)
    .backgroundColor(pageSurfaceColor(this.displayMode, this.darkSurface))
    .onReady((context: NavDestinationContext): void => { this.outerStack = context.pathStack; })
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
}
