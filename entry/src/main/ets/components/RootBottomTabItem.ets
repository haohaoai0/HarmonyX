import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';

// Keep the unread mark inside the icon's layout so HDS owns its position,
// handedness translation, and hide/show animation together with the tab.
@Component
export struct RootBottomTabItem {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp('harmonyx.accent_color') private accentColor: string = '#1D9BF0';
  @Prop icon: Resource = $r('sys.symbol.house_fill');
  @Prop activeIcon: Resource = $r('sys.symbol.house_fill');
  @Prop label: ResourceStr = '';
  @Prop selected: boolean = false;
  @Prop unread: number = 0;
  @Prop floating: boolean = true;
  @Prop showLabel: boolean = true;
  @Prop accessibleLabel: string = '';

  @Builder
  private Icon(): void {
    SymbolGlyph(this.selected ? this.activeIcon : this.icon)
      .fontSize($r('app.float.root_tab_icon_size'))
      .fontColor([this.selected ? this.accentColor :
        (this.floating ? $r('sys.color.icon_primary') : $r('app.color.text_secondary'))])
      .renderingStrategy(SymbolRenderingStrategy.SINGLE)
      .width($r('app.float.root_tab_icon_size'))
      .height($r('app.float.root_tab_icon_size'))
  }

  build(): void {
    Column({ space: $r('app.float.root_tab_item_gap') }) {
      if (this.unread > 0) {
        Badge({
          value: '',
          position: BadgePosition.RightTop,
          style: {
            badgeSize: $r('app.float.root_tab_badge_size'),
            badgeColor: this.accentColor,
            borderColor: this.accentColor,
            borderWidth: 0
          }
        }) {
          this.Icon()
        }
        .width($r('app.float.root_tab_icon_size'))
        .height($r('app.float.root_tab_icon_size'))
      } else {
        this.Icon()
      }
      if (this.showLabel) {
        Text(this.label).fontFamily(this.appFontFamily)
          .fontSize(this.floating ? $r('app.float.root_tab_label_size') : $r('sys.float.Caption_L'))
          .maxFontScale(1.5)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .fontWeight(FontWeight.Medium)
          .fontColor(this.selected ? this.accentColor :
            (this.floating ? $r('sys.color.font_primary') : $r('app.color.text_secondary')))
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .accessibilityText(this.accessibleLabel)
  }
}
