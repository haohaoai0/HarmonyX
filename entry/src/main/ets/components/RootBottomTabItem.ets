import { mixedAccentRoleColor, accentPageRole, isMixedAccentTheme } from '../utils/AccentPalette';
import { symbolMotionEnabled } from '../utils/AppMotion';
import { STORAGE_KEY_REDUCE_MOTION, STORAGE_KEY_SYMBOL_EFFECTS, STORAGE_KEY_MOTION_AMPLITUDE } from '../services/MotionSettingsStore';
import { DEFAULT_COMPONENT_HDR_ENABLED, DEFAULT_COMPONENT_HDR_RATIO, STORAGE_KEY_COMPONENT_HDR_ENABLED,
  STORAGE_KEY_COMPONENT_HDR_RATIO } from '../services/ComponentHdrSettingsStore';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { ComponentHdrHighlight } from '../utils/ComponentHdrHighlight';
import { pageTextColor } from '../utils/ThemeColors';

// Keep the unread mark inside the icon's layout so HDS owns its position,
// handedness translation, and hide/show animation together with the tab.
@Component
export struct RootBottomTabItem {
  @StorageProp(STORAGE_KEY_REDUCE_MOTION) private motionReducedValue: boolean = false;
  @StorageProp(STORAGE_KEY_SYMBOL_EFFECTS) private symbolEffectsValue: boolean = true;
  @StorageProp(STORAGE_KEY_MOTION_AMPLITUDE) private motionAmplitudeValue: number = 1;
  @State private symbolTrigger: number = -1;

  private selectionChanged(): void {
    if (this.selected && symbolMotionEnabled()) { this.symbolTrigger++; }
  }

  @StorageProp(STORAGE_KEY_COMPONENT_HDR_ENABLED) private componentHdrEnabled: boolean = DEFAULT_COMPONENT_HDR_ENABLED;
  @StorageProp(STORAGE_KEY_COMPONENT_HDR_RATIO) private componentHdrRatio: number = DEFAULT_COMPONENT_HDR_RATIO;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp('harmonyx.accent_color') private accentColor: string = '#1D9BF0';
  @StorageProp('harmonyx.accent_theme') private accentTheme: string = '';
  @StorageProp('harmonyx.page_background') private pageBackgroundValue: string = '';
  @Prop page: number = 0;
  @Prop icon: Resource = $r('sys.symbol.house_fill');
  @Prop activeIcon: Resource = $r('sys.symbol.house_fill');
  @Prop label: ResourceStr = '';
  @Prop @Watch('selectionChanged') selected: boolean = false;
  @Prop unread: number = 0;
  @Prop floating: boolean = true;
  @Prop showLabel: boolean = true;
  @Prop adaptiveForeground: boolean = false;
  @Prop accessibleLabel: string = '';

  private adaptedColor(color: ResourceColor, minimum: number): ResourceColor {
    return this.adaptiveForeground ? pageTextColor(color, this.pageBackgroundValue, Color.Transparent, minimum) : color;
  }

  private navigationColor(minimum: number = 4.6): ResourceColor {
    return this.adaptedColor(mixedAccentRoleColor(this.accentTheme, accentPageRole(this.page), this.accentColor), minimum);
  }

  private iconColor(): ResourceColor {
    const requested: ResourceColor = this.selected || isMixedAccentTheme(this.accentTheme) ? this.navigationColor() :
      (this.floating ? $r('sys.color.icon_primary') : $r('app.color.text_secondary'));
    return this.adaptedColor(requested, this.selected ? 4.6 : 3);
  }

  private labelColor(): ResourceColor {
    const requested: ResourceColor = this.selected ? mixedAccentRoleColor(this.accentTheme, 'primary', this.accentColor) :
      (this.floating ? $r('sys.color.font_primary') : $r('app.color.text_secondary'));
    return this.adaptedColor(requested, 4.6);
  }

  @Builder
  private Icon(): void {
    SymbolGlyph(this.selected ? this.activeIcon : this.icon)
      .fontSize($r('app.float.root_tab_icon_size'))
      .fontColor([this.iconColor()])
      .renderingStrategy(SymbolRenderingStrategy.SINGLE)
      .symbolEffect(this.symbolEffectsValue && !this.motionReducedValue && this.motionAmplitudeValue > 0 ?
        new BounceSymbolEffect(EffectScope.WHOLE) : new SymbolEffect(), this.symbolTrigger)
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
            badgeColor: this.navigationColor(3),
            borderColor: this.navigationColor(3),
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
          .fontWeight(this.selected ? FontWeight.Bold : FontWeight.Medium)
          .fontColor(this.labelColor())
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .compositingFilter(ComponentHdrHighlight.filter(this.getUIContext(), this.componentHdrEnabled && this.selected, this.componentHdrRatio))
    .accessibilityText(this.accessibleLabel)
  }
}
