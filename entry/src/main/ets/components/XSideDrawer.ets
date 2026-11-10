import { STORAGE_KEY_SIDEBAR_ORDER, STORAGE_KEY_SIDEBAR_HIDDEN } from '../services/SidebarSettingsStore';
import { sidebarVisibleIds, sidebarMainIds, sidebarItemIcon, sidebarItemLabel, DEFAULT_SIDEBAR_HIDDEN } from '../utils/SidebarItems';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
// X-style drawer built as the content panel of HdsSideBar. The layout follows
// the PaperTalk pattern: a self-contained content component plus callbacks
// owned by the root navigation page.
import type { UserProfile } from '../models/Tweet';
import { formatCount } from '../models/Tweet';
import { MaterialButton } from './MaterialButton';
import { secondaryButtonSurfaceColor } from '../utils/ThemeColors';
import { SideBarMaterialLayer } from './SideBarMaterialLayer';
import { ProxyAvatar } from './ProxyAvatar';
import { XAccount, accountStore, STORAGE_KEY_ACCOUNTS_CHANGED } from '../services/AccountStore';
import { common } from '@kit.AbilityKit';
import { DEFAULT_DESKTOP_RAIL_MATERIAL_LEVEL, STORAGE_KEY_DESKTOP_RAIL_MATERIAL_LEVEL,
  SIDEBAR_MATERIAL_GLASS, SIDEBAR_MATERIAL_SYSTEM } from '../services/LayoutSettingsStore';

@Component
export struct XSideDrawer {
  scroller: Scroller = new Scroller();
  @StorageProp('harmonyx.compact_window') private compactWindow: boolean = false;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp(STORAGE_KEY_SIDEBAR_ORDER) private itemOrder: string = '';
  @StorageProp(STORAGE_KEY_SIDEBAR_HIDDEN) private hiddenItems: string = DEFAULT_SIDEBAR_HIDDEN;
  @Prop profile: UserProfile | null = null;
  @StorageProp(STORAGE_KEY_ACCOUNTS_CHANGED) @Watch('loadCachedAccount') private accountsChanged: number = 0;
  @State private cachedAccount: XAccount | null = null;
  @Prop fallbackName: string = 'Harmony X';
  @Prop fallbackHandle: string = '@harmonyx';
  onClose: () => void = (): void => {};
  onProfile: () => void = (): void => {};
  onFollowing: () => void = (): void => {};
  onFollowers: () => void = (): void => {};
  onSettings: () => void = (): void => {};
  onAccounts: () => void = (): void => {};
  onMenu: (label: string) => void = (_label: string): void => {};
  @StorageProp('harmonyx.status_bar_height') statusBarHeight: number =
    AppStorage.get<number>('harmonyx.status_bar_height') ?? 0;
  @StorageProp('harmonyx.navigation_indicator_height') navigationIndicatorHeight: number =
    AppStorage.get<number>('harmonyx.navigation_indicator_height') ?? 0;
  @StorageLink('harmonyx.accent_color') accentColor: string = '#007DFF';
  @StorageProp('harmonyx.display_mode') private themeDisplayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private themeDarkSurface: string = '';
  @StorageProp(STORAGE_KEY_DESKTOP_RAIL_MATERIAL_LEVEL)
  private sidebarMaterialLevel: number = DEFAULT_DESKTOP_RAIL_MATERIAL_LEVEL;
  @Prop sidebarMaterialType: number = SIDEBAR_MATERIAL_GLASS;

  aboutToAppear(): void {
    this.loadCachedAccount();
  }

  private loadCachedAccount(): void {
    const context: common.Context | undefined = this.getUIContext().getHostContext();
    this.cachedAccount = context === undefined ? null : accountStore.active(context);
  }

  private avatarUrl(): string {
    return this.profile?.avatarUrl || this.cachedAccount?.avatarUrl || '';
  }

  private name(): string {
    if (this.profile !== null && this.profile.name.length > 0) {
      return this.profile.name;
    }
    return this.cachedAccount?.displayName || this.cachedAccount?.username || this.fallbackName;
  }

  private handle(): string {
    if (this.profile !== null && this.profile.username.length > 0) {
      return '@' + this.profile.username;
    }
    const username: string = this.cachedAccount?.username ?? '';
    return username.length > 0 ? '@' + username : this.fallbackHandle;
  }

  private followingCount(): string {
    return this.profile === null ? '0' : formatCount(this.profile.followingCount);
  }

  private followersCount(): string {
    return this.profile === null ? '0' : formatCount(this.profile.followersCount);
  }

  @Builder
  private DrawerItem(icon: Resource, title: Resource, action: () => void): void {
    Row({ space: 18 }) {
      SymbolGlyph(icon)
        .fontSize(24)
        .fontColor([$r('app.color.text_primary')])
        .width(28)
      Text(title).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Subtitle_L'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
    }
    .width('100%')
    .constraintSize({ minHeight: 58 })
    .padding({ left: 20, right: 20, top: 12, bottom: 12 })
    .borderRadius(14)
    .onClick((): void => action())
  }

  @Builder
  private DrawerHeader(): void {
    Column() {
      Column({ space: 4 }) {
        Row({ space: 10 }) {
        Column({ space: 8 }) {
          ProxyAvatar({ url: this.avatarUrl(), avatarSize: 58, radius: 29,
            verifiedType: this.profile?.verifiedType ?? this.cachedAccount?.verifiedType ?? '',
            avatarShape: this.profile?.avatarShape ?? this.cachedAccount?.avatarShape ?? '',
            fallbackText: this.name().substring(0, 1).toUpperCase(), fallbackColor: this.accentColor })
            .id('sidebar-account-avatar')
          Text(this.name()).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Title_S'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.handle()).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_L'))
            .fontColor($r('app.color.text_secondary'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .onClick((): void => this.onProfile())

        // Switching accounts is the one drawer action X keeps next to the
        // account itself rather than in the list below.
        MaterialButton({
          buttonWidth: 36,
          buttonHeight: 36,
          buttonRadius: 18,
          surfaceColor: secondaryButtonSurfaceColor(this.themeDisplayMode, this.themeDarkSurface),
          materialLevel: 1,
          applyShadow: true,
          lightColor: this.accentColor,
          onButtonClick: (): void => this.onAccounts()
        }) {
          SymbolGlyph($r('sys.symbol.person_2_badge_arrow_2_circlepath'))
            .fontSize(18)
            .fontColor([$r('app.color.text_primary')])
        }
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)

        Row({ space: 14 }) {
          Row({ space: 4 }) {
            Text(this.followingCount()).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_M'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
            Text($r('app.string.profile_following')).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_M'))
              .fontColor($r('app.color.text_primary'))
          }
          .padding({ top: 8, bottom: 8 })
          .onClick((): void => this.onFollowing())

          Row({ space: 4 }) {
            Text(this.followersCount()).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_M'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
            Text($r('app.string.profile_followers')).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_M'))
              .fontColor($r('app.color.text_primary'))
          }
          .padding({ top: 8, bottom: 8 })
          .onClick((): void => this.onFollowers())
        }
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 12, bottom: 16 })
      .alignItems(HorizontalAlign.Start)

      Divider().color($r('app.color.divider'))
    }.width('100%')
  }

  @Builder
  private DrawerItems(): void {
    Column({ space: 2 }) {
      ForEach(sidebarMainIds(this.itemOrder, this.hiddenItems), (id: string) => {
        Column() {
          this.DrawerItem(sidebarItemIcon(id), sidebarItemLabel(id),
            (): void => { if (id === 'profile') { this.onProfile(); } else { this.onMenu(id); } })
        }.width('100%').id('sidebar-item-' + id)
      }, (id: string): string => id)
      Divider().color($r('app.color.divider')).margin({ top: 8, bottom: 8 })
      if (sidebarVisibleIds(this.itemOrder, this.hiddenItems).indexOf('support') >= 0) {
        Column() { this.DrawerItem(sidebarItemIcon('support'), sidebarItemLabel('support'), (): void => this.onMenu('support')) }
          .width('100%').id('sidebar-item-support')
      }
      this.DrawerItem($r('sys.symbol.gearshape'), $r('app.string.settings_title'), (): void => this.onSettings())
      if (sidebarVisibleIds(this.itemOrder, this.hiddenItems).indexOf('help') >= 0) {
        Column() { this.DrawerItem(sidebarItemIcon('help'), sidebarItemLabel('help'), (): void => this.onMenu('help')) }
          .width('100%').id('sidebar-item-help')
      }
    }.width('100%').padding({ left: 10, right: 10, top: 8, bottom: this.navigationIndicatorHeight + 28 })
  }

  private sidebarContentTopInset(): number {
    return this.statusBarHeight + this.getUIContext().px2vp(
      getContext(this).resourceManager.getNumber($r('app.float.sidebar_navigation_title_height').id));
  }

  build(): void {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.sidebarMaterialLevel >= 0 && this.sidebarMaterialType !== SIDEBAR_MATERIAL_SYSTEM) {
        SideBarMaterialLayer({ materialType: this.sidebarMaterialType, materialLevel: this.sidebarMaterialLevel,
          layerPrefix: 'account-sidebar' })
      }
      Scroll(this.scroller) {
        Column() {
          Row().width('100%').height(this.sidebarContentTopInset()).flexShrink(0)
          this.DrawerHeader()
          this.DrawerItems()
        }.width('100%')
      }.width('100%').height('100%').scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    }
    .width('100%').height('100%').borderRadius(0).clip(true).id('account-sidebar-panel')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.START, SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
