import { mixedAccentRoleColor, isMixedAccentTheme } from '../utils/AccentPalette';
import { hapticTick } from '../utils/Haptics';
import { DEFAULT_COMPONENT_HDR_RATIO, STORAGE_KEY_COMPONENT_HDR_RATIO } from '../services/ComponentHdrSettingsStore';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import type { UserProfile } from '../models/Tweet';
import { ProxyAvatar } from './ProxyAvatar';
import { ComponentHdrHighlight } from '../utils/ComponentHdrHighlight';

@Component
export struct DesktopNavRail {
  @StorageProp(STORAGE_KEY_COMPONENT_HDR_RATIO) private componentHdrRatio: number = DEFAULT_COMPONENT_HDR_RATIO;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Prop topInset: number = 0;
  @Prop bottomInset: number = 0;
  @Prop compact: boolean = false;
  @Prop selected: string = 'home';
  @Prop profile: UserProfile | null = null;
  @Prop handle: string = '';
  @Prop unread: number = 0;
  @StorageProp('harmonyx.accent_theme') private accentTheme: string = '';
  @StorageProp('harmonyx.accent_color') accentColor: string = '#1D9BF0';
  @State private hovered: string = '';
  @State private moreOpen: boolean = false;
  onSelect: (name: string) => void = (): void => {};
  onCompose: () => void = (): void => {};
  onAccounts: () => void = (): void => {};

  private itemColor(name: string): ResourceColor {
    return isMixedAccentTheme(this.accentTheme) ?
      mixedAccentRoleColor(this.accentTheme, name, this.accentColor) : $r('app.color.text_primary');
  }

  @Builder
  private Item(name: string, title: Resource, icon: Resource): void {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 16 }) {
        Stack({ alignContent: Alignment.TopEnd }) {
          SymbolGlyph(icon).fontSize($r('app.float.desktop_nav_icon'))
            .fontColor([this.itemColor(name)])
          if (name === 'notifications' && this.unread > 0) {
            Text(this.unread > 99 ? '99+' : this.unread.toString()).fontFamily(this.appFontFamily)
              .fontSize(11).fontColor($r('app.color.text_on_accent'))
              .backgroundColor(this.accentColor).borderRadius(10).padding({ left: 4, right: 4 })
              .translate({ x: 7, y: -5 })
          }
        }
        if (!this.compact) {
          Text(title).fontFamily(this.appFontFamily).fontSize($r('app.float.desktop_nav_text'))
            .fontWeight(this.selected === name ? FontWeight.Bold : FontWeight.Regular)
            .fontColor(this.selected === name ? this.itemColor(name) : $r('app.color.text_primary')).maxLines(1)
        }
      }.width('100%').justifyContent(this.compact ? FlexAlign.Center : FlexAlign.Start)
        .compositingFilter(ComponentHdrHighlight.filter(this.getUIContext(), this.selected === name, this.componentHdrRatio))
    }
    .width('100%').height($r('app.float.desktop_nav_row')).padding({ left: 12, right: 12 })
    .borderRadius(28).backgroundColor(this.hovered === name ? $r('app.color.bg_field') : Color.Transparent)
    .onHover((hover: boolean): void => { this.hovered = hover ? name : ''; })
    .id('desktop-nav-' + name).accessibilityText(title)
    .onClick((): void => { hapticTick(); this.moreOpen = false; this.onSelect(name); })
  }

  @Builder
  private MoreMenu(): void {
    Column() {
      this.MenuItem('lists', $r('app.string.side_lists'), $r('sys.symbol.list_bullet'))
      this.MenuItem('communities', $r('app.string.side_communities'), $r('sys.symbol.person_2'))
      this.MenuItem('spaces', $r('app.string.side_spaces'), $r('sys.symbol.mic'))
      this.MenuItem('settings', $r('app.string.settings_title'), $r('sys.symbol.gearshape'))
      this.MenuItem('help', $r('app.string.desktop_studio_support'), $r('sys.symbol.questionmark_circle'))
    }.width(280).padding(8)
  }

  @Builder
  private MenuItem(name: string, title: Resource, icon: Resource): void {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 16 }) {
        SymbolGlyph(icon).fontSize(24).fontColor([$r('app.color.text_primary')])
        Text(title).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary')).layoutWeight(1).textAlign(TextAlign.Start)
      }.width('100%')
    }.width('100%').height(52).padding(12).backgroundColor(Color.Transparent)
      .onClick((): void => { hapticTick(); this.moreOpen = false; this.onSelect(name); })
  }

  build(): void {
    Column({ space: 8 }) {
      Button({ type: ButtonType.Circle }) {
        Image($r('app.media.ui_brand_foreground')).width(38).height(38).objectFit(ImageFit.Contain)
      }.width(52).height(52).backgroundColor(Color.Transparent)
        .align(Alignment.Start).accessibilityText($r('app.string.home_title'))
        .onClick((): void => this.onSelect('home'))
      Scroll() {
        Column({ space: 0 }) {
          this.Item('home', $r('app.string.home_title'), this.selected === 'home' ? $r('sys.symbol.house_fill') : $r('sys.symbol.house'))
          this.Item('explore', $r('app.string.explore_title'), $r('sys.symbol.magnifyingglass'))
          this.Item('notifications', $r('app.string.tab_alerts'), $r('sys.symbol.bell'))
          this.Item('follow', $r('app.string.desktop_follow'), $r('sys.symbol.person_badge_plus'))
          this.Item('messages', $r('app.string.chat_title'), $r('sys.symbol.message'))
          this.Item('grok', $r('app.string.grok_title'), $r('sys.symbol.wand_and_stars'))
          this.Item('bookmarks', $r('app.string.desktop_history'), $r('sys.symbol.bookmark'))
          this.Item('history', $r('app.string.browsing_history_title'), $r('sys.symbol.clock'))
          this.Item('studio', $r('app.string.side_creator_studio'), $r('sys.symbol.rectangle_3_group'))
          this.Item('premium', $r('app.string.side_premium'), $r('sys.symbol.star_rosette'))
          this.Item('profile', $r('app.string.side_profile'), $r('sys.symbol.person'))
          Button({ type: ButtonType.Normal }) {
            Row({ space: 16 }) {
              SymbolGlyph($r('sys.symbol.ellipsis_circle')).fontSize($r('app.float.desktop_nav_icon'))
                .fontColor([$r('app.color.text_primary')])
              if (!this.compact) {
                Text($r('app.string.desktop_more')).fontFamily(this.appFontFamily).fontSize($r('app.float.desktop_nav_text'))
                  .fontColor($r('app.color.text_primary'))
              }
            }.width('100%').justifyContent(this.compact ? FlexAlign.Center : FlexAlign.Start)
          }.width('100%').height($r('app.float.desktop_nav_row')).padding(12).backgroundColor(Color.Transparent)
            .id('desktop-nav-more').accessibilityText($r('app.string.desktop_more'))
            .onClick((): void => { this.moreOpen = !this.moreOpen; })
            .bindPopup(this.moreOpen, {
              builder: this.MoreMenu(), placement: Placement.Right,
              popupColor: $r('app.color.bg_card'),
              onStateChange: (event: PopupStateChangeParam): void => { this.moreOpen = event.isVisible; }
            })
          Button({ type: ButtonType.Normal }) {
            if (this.compact) {
              SymbolGlyph($r('sys.symbol.square_and_pencil')).fontSize(26).fontColor([mixedAccentRoleColor(this.accentTheme, 'on_action', isMixedAccentTheme(this.accentTheme) ? $r('app.color.mix_preview_on_action') : $r('app.color.text_on_inverse'))])
            } else {
              Text($r('app.string.action_post')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontWeight(FontWeight.Bold)
                .fontColor(mixedAccentRoleColor(this.accentTheme, 'on_action', isMixedAccentTheme(this.accentTheme) ? $r('app.color.mix_preview_on_action') : $r('app.color.text_on_inverse')))
            }
          }.width('100%').height(52).borderRadius(26).backgroundColor(mixedAccentRoleColor(this.accentTheme, 'action', $r('app.color.text_primary')))
            .compositingFilter(ComponentHdrHighlight.filter(this.getUIContext(), true, this.componentHdrRatio))
            .margin({ top: 12 }).id('desktop-compose').onClick(this.onCompose)
        }.width('100%')
      }.width('100%').layoutWeight(1).scrollBar(BarState.Auto).align(Alignment.TopStart)
      Button({ type: ButtonType.Normal }) {
        Row({ space: 10 }) {
          ProxyAvatar({verifiedType: this.profile?.verifiedType ?? '', avatarShape: this.profile?.avatarShape ?? '',  url: this.profile?.avatarUrl ?? '', avatarSize: 40, radius: 20,
            fallbackText: (this.profile?.name ?? 'X').substring(0, 1), fallbackColor: this.accentColor })
          if (!this.compact) {
            Column({ space: 2 }) {
              Text(this.profile?.name ?? 'Harmony X').fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary')).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(this.handle).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S')).fontColor($r('app.color.text_secondary'))
                .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            SymbolGlyph($r('sys.symbol.ellipsis_circle')).fontSize(18).fontColor([$r('app.color.text_primary')])
          }
        }.width('100%').justifyContent(FlexAlign.Center)
      }.width('100%').height(64).padding(8).backgroundColor(Color.Transparent).onClick(this.onAccounts)
    }.width('100%').height('100%').alignItems(HorizontalAlign.Start)
      .padding({ left: 10, right: 10, top: this.topInset + 8, bottom: this.bottomInset + 8 })
  }
}
