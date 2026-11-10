import { mixedAccentRoleColor, accentPageRole } from '../utils/AccentPalette';
import { TouchHdrLight } from './TouchHdrLight';
import { HdsTabs, hdsEffect, hdsMaterial } from '@kit.UIDesignKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { RootBottomTabItem } from './RootBottomTabItem';
import { RootLiquidTabMotion } from '../utils/RootLiquidTabMotion';
import { DEFAULT_COMPONENT_HDR_ENABLED, DEFAULT_COMPONENT_HDR_RATIO, STORAGE_KEY_COMPONENT_HDR_ENABLED,
  STORAGE_KEY_COMPONENT_HDR_RATIO } from '../services/ComponentHdrSettingsStore';
import { ComponentHdrHighlight } from '../utils/ComponentHdrHighlight';
import { ReplyCapsuleSurface } from './ReplyCapsuleSurface';
import { MaterialCompat } from '../utils/MaterialCompat';

// Decorative only: the native tab-bar ancestor supplies its hide/show transform,
// opacity and clipping, including interrupted and reversed animations.
@Component
export struct RootLiquidTabSurface {
  @ObjectLink motion: RootLiquidTabMotion;
  @Prop showLabel: boolean = true;
  @Prop materialLevel: number = 10;
  @Prop nativeMaterial: boolean = false;
  @Prop nativeMaterialLevel: number = 0;
  @Prop unreadNotifications: number = 0;
  @Prop unreadMessages: number = 0;
  @StorageProp('harmonyx.accent_theme') private accentTheme: string = '';
  @StorageProp('harmonyx.accent_color') private accentColor: string = '#1D9BF0';
  @StorageProp(STORAGE_KEY_COMPONENT_HDR_ENABLED) private componentHdrEnabled: boolean = DEFAULT_COMPONENT_HDR_ENABLED;
  @StorageProp(STORAGE_KEY_COMPONENT_HDR_RATIO) private componentHdrRatio: number = DEFAULT_COMPONENT_HDR_RATIO;

  private icon(): Resource {
    if (this.motion.displayPage === 1) { return $r('sys.symbol.magnifyingglass'); }
    if (this.motion.displayPage === 2) { return $r('sys.symbol.bell_fill'); }
    if (this.motion.displayPage === 3) { return $r('sys.symbol.message_fill'); }
    if (this.motion.displayPage === 4) { return $r('sys.symbol.person_fill'); }
    return $r('sys.symbol.house_fill');
  }

  private label(): Resource {
    if (this.motion.displayPage === 1) { return $r('app.string.explore_title'); }
    if (this.motion.displayPage === 2) { return $r('app.string.tab_alerts'); }
    if (this.motion.displayPage === 3) { return $r('app.string.chat_title'); }
    if (this.motion.displayPage === 4) { return $r('app.string.tab_me'); }
    return $r('app.string.home_title');
  }

  @Builder
  private SelectedContent(): void {
    RootBottomTabItem({ page: this.motion.displayPage, icon: this.icon(), activeIcon: this.icon(),
      label: this.label(), selected: true, showLabel: this.showLabel,
      adaptiveForeground: !this.nativeMaterial,
      unread: this.motion.displayPage === 2 ? this.unreadNotifications :
        (this.motion.displayPage === 3 ? this.unreadMessages : 0) })
      .width('100%').height('100%')
      .renderGroup(true)
      .blur(this.motion.contentBlur)
      .hitTestBehavior(HitTestMode.None)
  }

  build(): void {
    Stack({ alignContent: Alignment.Center }) {
      if (this.nativeMaterial) {
        ReplyCapsuleSurface({ capsuleHeight: this.motion.restHeight, cornerRadius: this.motion.restHeight / 2,
          materialEnabled: true, materialLevel: this.nativeMaterialLevel,
          capsuleContent: (): void => { this.SelectedContent(); } })
          .width(this.motion.restWidth).height(this.motion.restHeight)
          .clip(false)
          .scale({ x: this.motion.scaleX, y: this.motion.scaleY })
          .compositingFilter(ComponentHdrHighlight.filter(this.getUIContext(), this.componentHdrEnabled, this.componentHdrRatio))
          .hitTestBehavior(HitTestMode.None)
      } else {
        if (deviceInfo.apiAvailable('6.1.0(23)')) {
          HdsTabs({ index: 0 }) {}
            .width(this.motion.restWidth).height(this.motion.restHeight)
            .barWidth(this.motion.restWidth).barHeight(this.motion.restHeight)
            .barPosition(BarPosition.End).barOverlap(true).vertical(false)
            .backgroundColor(Color.Transparent)
            .barBackgroundColor(Color.Transparent)
            .barBackgroundStyle({ maskColor: Color.Transparent, maskHeight: 1 })
            .barBackgroundBlurStyle(MaterialCompat.NO_PLATE_BLUR)
            .barFloatingStyle({
              barWidth: { smallWidth: this.motion.restWidth, mediumWidth: this.motion.restWidth, largeWidth: this.motion.restWidth },
              barBottomMargin: 0, barSideMargin: 0,
              gradientMask: { maskColor: Color.Transparent, maskHeight: 1 },
              lightColor: mixedAccentRoleColor(this.accentTheme, accentPageRole(this.motion.displayPage), this.accentColor),
              systemMaterialEffect: { materialType: hdsMaterial.MaterialType.IMMERSIVE,
                materialLevel: this.materialLevel },
              thermoCtrl: true
            })
            .clip(false)
            .scale({ x: this.motion.scaleX, y: this.motion.scaleY })
            // Boost the material capsule itself. The foreground is a sibling
            // with its own filter, so neither layer receives the ratio twice.
            .compositingFilter(ComponentHdrHighlight.filter(this.getUIContext(), this.componentHdrEnabled, this.componentHdrRatio))
            .visualEffect(new hdsEffect.HdsEffectBuilder().pointLight({
              sourceType: this.motion.dragging ? hdsEffect.PointLightSourceType.BRIGHT : hdsEffect.PointLightSourceType.NONE,
              illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER
            }).buildEffect())
            .hitTestBehavior(HitTestMode.None)
        } else {
          Column()
            .width(this.motion.restWidth).height(this.motion.restHeight)
            .borderRadius(this.motion.restHeight / 2)
            .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
            .scale({ x: this.motion.scaleX, y: this.motion.scaleY })
        }
        TouchHdrLight({ active: this.motion.touchHeld || this.motion.dragging, cornerRadius: this.motion.restHeight / 2 })
          .width(this.motion.restWidth).height(this.motion.restHeight)
          .scale({ x: this.motion.scaleX, y: this.motion.scaleY })
        this.SelectedContent()
      }
    }
    .width(this.motion.restWidth).height(this.motion.restHeight)
    .position({ x: 0, y: 0 })
    .translate({ x: this.motion.centerX - this.motion.restWidth / 2, y: this.motion.centerY - this.motion.restHeight / 2 })
    .opacity(this.motion.ready ? 1 : 0)
    .visibility(this.motion.ready ? Visibility.Visible : Visibility.Hidden)
    .clip(false)
    .id('root-liquid-tab-indicator')
    // The underlying native item supplies the label, focus and selection.
    .accessibilityLevel('no-hide-descendants')
    .hitTestBehavior(HitTestMode.None)
  }
}
