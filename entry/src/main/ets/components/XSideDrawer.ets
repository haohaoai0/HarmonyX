// X-style drawer built as the content panel of HdsSideBar. The layout follows
// the PaperTalk pattern: a self-contained content component plus callbacks
// owned by the root navigation page.
import type { UserProfile } from '../models/Tweet';
import { uiMaterial } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';

@Component
export struct XSideDrawer {
  @Prop profile: UserProfile | null = null;
  @Prop fallbackName: string = 'Harmony X';
  @Prop fallbackHandle: string = '@harmonyx';
  onClose: () => void = (): void => {};
  onProfile: () => void = (): void => {};
  onSettings: () => void = (): void => {};
  onMenu: (label: string) => void = (_label: string): void => {};
  @StorageProp('harmonyx.status_bar_height') statusBarHeight: number =
    AppStorage.get<number>('harmonyx.status_bar_height') ?? 0;
  @StorageProp('harmonyx.navigation_indicator_height') navigationIndicatorHeight: number =
    AppStorage.get<number>('harmonyx.navigation_indicator_height') ?? 0;
  @StorageLink('harmonyx.accent_color') accentColor: string = '#007DFF';

  private surfaceMaterial(): uiMaterial.Material | undefined {
    if (!deviceInfo.apiAvailable('26.0.0')) {
      return undefined;
    }
    return new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.REGULAR,
      applyShadow: true,
      colorInvert: true
    });
  }

  private interactiveMaterial(): uiMaterial.Material | undefined {
    if (!deviceInfo.apiAvailable('26.0.0')) {
      return undefined;
    }
    return new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.THIN,
      interactive: true,
      applyShadow: true,
      colorInvert: true,
      lightEffect: { color: this.accentColor }
    });
  }

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

  @Builder
  private DrawerItem(icon: Resource, title: Resource, action: () => void): void {
    Row({ space: 18 }) {
      SymbolGlyph(icon)
        .fontSize(24)
        .fontColor([$r('app.color.text_primary')])
        .width(28)
      Text(title)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
    }
    .width('100%')
    .height(58)
    .padding({ left: 20, right: 20 })
    .borderRadius(14)
    .onClick((): void => action())
  }

  build(): void {
    Column() {
      Row() {
        Blank()
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(18)
            .fontColor([$r('app.color.text_primary')])
        }
        .width(38)
        .height(38)
        .backgroundColor($r('app.color.bg_secondary_btn'))
        .systemMaterial(this.interactiveMaterial())
        .onClick((): void => this.onClose())
      }
      .width('100%')
      .padding({ top: this.statusBarHeight + 10, left: 18, right: 18 })

      Column({ space: 8 }) {
        if (this.profile !== null && this.profile.avatarUrl !== undefined && this.profile.avatarUrl.length > 0) {
          Image(this.profile.avatarUrl)
            .width(58)
            .height(58)
            .objectFit(ImageFit.Cover)
            .borderRadius(29)
            .clip(true)
        } else {
          Text(this.name().substring(0, 1).toUpperCase())
            .width(58)
            .height(58)
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_on_brand'))
            .backgroundColor(this.accentColor)
            .borderRadius(29)
            .textAlign(TextAlign.Center)
        }
        Text(this.name())
          .fontSize(21)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.handle())
          .fontSize(15)
          .fontColor($r('app.color.text_secondary'))
        Row({ space: 14 }) {
          Text('0')
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
          Text($r('app.string.profile_following'))
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
          Text('0')
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
          Text($r('app.string.profile_followers'))
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
        }
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 12, bottom: 16 })
      .alignItems(HorizontalAlign.Start)
      .onClick((): void => this.onProfile())

      Divider().color($r('app.color.divider'))

      Scroll() {
        Column({ space: 2 }) {
          this.DrawerItem($r('sys.symbol.person'), $r('app.string.side_profile'), (): void => this.onProfile())
          this.DrawerItem($r('sys.symbol.star_rosette'), $r('app.string.side_premium'),
            (): void => this.onMenu('premium'))
          this.DrawerItem($r('sys.symbol.person_2'), $r('app.string.side_communities'),
            (): void => this.onMenu('communities'))
          this.DrawerItem($r('sys.symbol.bookmark'), $r('app.string.side_bookmarks'),
            (): void => this.onMenu('bookmarks'))
          this.DrawerItem($r('sys.symbol.list_bullet'), $r('app.string.side_lists'),
            (): void => this.onMenu('lists'))
          this.DrawerItem($r('sys.symbol.waveform'), $r('app.string.side_spaces'),
            (): void => this.onMenu('spaces'))
          this.DrawerItem($r('sys.symbol.rectangle_3_group'), $r('app.string.side_creator_studio'),
            (): void => this.onMenu('studio'))
          Divider().color($r('app.color.divider')).margin({ top: 8, bottom: 8 })
          this.DrawerItem($r('sys.symbol.gearshape'), $r('app.string.settings_title'),
            (): void => this.onSettings())
          this.DrawerItem($r('sys.symbol.questionmark_circle'), $r('app.string.side_help'),
            (): void => this.onMenu('help'))
        }
        .width('100%')
        .padding({ left: 10, right: 10, top: 8, bottom: this.navigationIndicatorHeight + 28 })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
    .systemMaterial(this.surfaceMaterial())
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
