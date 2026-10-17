import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { userAvatarRadius, userVerifiedType, userAvatarShape, verificationBadgeColor } from '../utils/UserIdentity';
// X-style drawer built as the content panel of HdsSideBar. The layout follows
// the PaperTalk pattern: a self-contained content component plus callbacks
// owned by the root navigation page.
import type { UserProfile } from '../models/Tweet';
import { formatCount } from '../models/Tweet';
import { MaterialButton } from './MaterialButton';
import { secondaryButtonSurfaceColor } from '../utils/ThemeColors';
import { SideBarMaterialLayer } from './SideBarMaterialLayer';
import { DEFAULT_DESKTOP_RAIL_MATERIAL_LEVEL, STORAGE_KEY_DESKTOP_RAIL_MATERIAL_LEVEL } from '../services/LayoutSettingsStore';

@Component
export struct XSideDrawer {
  @StorageProp('harmonyx.compact_window') private compactWindow: boolean = false;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Prop profile: UserProfile | null = null;
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

  private name(): string {
    if (this.profile !== null && this.profile.name.length > 0) {
      return this.profile.name;
    }
    return this.fallbackName;
  }

  private handle(): string {
    if (this.profile !== null && this.profile.username.length > 0) {
      return '@' + this.profile.username;
    }
    return this.fallbackHandle;
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
      Row() {
        Blank()
        MaterialButton({
          buttonWidth: 38,
          buttonHeight: 38,
          buttonRadius: 19,
          surfaceColor: secondaryButtonSurfaceColor(this.themeDisplayMode, this.themeDarkSurface),
          materialLevel: 1,
          applyShadow: true,
          lightColor: this.accentColor,
          onButtonClick: (): void => this.onClose()
        }) {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(18)
            .fontColor([$r('app.color.text_primary')])
        }
      }
      .width('100%')
      .padding({ top: this.statusBarHeight + 10, left: 18, right: 18 })

      Column({ space: 4 }) {
        Row({ space: 10 }) {
        Column({ space: 8 }) {
          if (this.profile !== null && this.profile.avatarUrl !== undefined && this.profile.avatarUrl.length > 0) {
            Image(this.profile.avatarUrl)
              .width(58)
              .height(58)
              .objectFit(ImageFit.Cover)
              .borderRadius(userAvatarRadius(58, 29, this.profile?.verifiedType ?? '', this.profile?.avatarShape ?? ''))
              .clip(true)
          } else {
            Text(this.name().substring(0, 1).toUpperCase()).fontFamily(this.appFontFamily)
              .width(58)
              .height(58)
              .fontSize($r('sys.float.Title_M'))
              .maxFontScale(1)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_on_accent'))
              .backgroundColor(this.accentColor)
              .borderRadius(userAvatarRadius(58, 29, this.profile?.verifiedType ?? '', this.profile?.avatarShape ?? ''))
              .textAlign(TextAlign.Center)
          }
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
          this.DrawerItem($r('sys.symbol.person'), $r('app.string.side_profile'), (): void => this.onProfile())
          this.DrawerItem($r('sys.symbol.bell'), $r('app.string.side_notifications'),
            (): void => this.onMenu('notifications'))
          this.DrawerItem($r('sys.symbol.star_rosette'), $r('app.string.side_premium'),
            (): void => this.onMenu('premium'))
          this.DrawerItem($r('sys.symbol.person_2'), $r('app.string.side_communities'),
            (): void => this.onMenu('communities'))
          this.DrawerItem($r('sys.symbol.bookmark'), $r('app.string.side_bookmarks'),
            (): void => this.onMenu('bookmarks'))
          this.DrawerItem($r('sys.symbol.clock'), $r('app.string.browsing_history_title'),
            (): void => this.onMenu('history'))
          this.DrawerItem($r('sys.symbol.list_bullet'), $r('app.string.side_lists'),
            (): void => this.onMenu('lists'))
          this.DrawerItem($r('sys.symbol.waveform'), $r('app.string.side_spaces'),
            (): void => this.onMenu('spaces'))
          this.DrawerItem($r('sys.symbol.rectangle_3_group'), $r('app.string.side_creator_studio'),
            (): void => this.onMenu('studio'))
          Divider().color($r('app.color.divider')).margin({ top: 8, bottom: 8 })
          // A single drawer entry makes voluntary support easy to find without
          // placing a prompt or banner over the reader's timeline.
          this.DrawerItem($r('sys.symbol.heart_fill'), $r('app.string.side_support'),
            (): void => this.onMenu('support'))
          this.DrawerItem($r('sys.symbol.gearshape'), $r('app.string.settings_title'),
            (): void => this.onSettings())
          this.DrawerItem($r('sys.symbol.questionmark_circle'), $r('app.string.side_help'),
            (): void => this.onMenu('help'))
        }
        .width('100%')
        .padding({ left: 10, right: 10, top: 8, bottom: this.navigationIndicatorHeight + 28 })
  }

  build(): void {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.sidebarMaterialLevel >= 0) {
        SideBarMaterialLayer({ materialLevel: this.sidebarMaterialLevel, layerPrefix: 'account-sidebar', useBackdropBlur: true })
      }
      if (this.compactWindow) {
        // The account header must scroll with the menu on a short cover screen.
        Scroll() {
          Column() { this.DrawerHeader(); this.DrawerItems(); }.width('100%')
        }.width('100%').height('100%').scrollBar(BarState.Off)
      } else {
        Column() {
          this.DrawerHeader()
          Scroll() { this.DrawerItems() }.width('100%').layoutWeight(1).scrollBar(BarState.Off)
        }.width('100%').height('100%').backgroundColor(Color.Transparent)
      }
    }
    .width('100%').height('100%').borderRadius(0).clip(true).id('account-sidebar-panel')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.START, SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
