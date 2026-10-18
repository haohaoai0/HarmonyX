import { SystemMaterialUtil } from '../utils/SystemMaterial';
import { desktopRailBlurStyle } from '../utils/DesktopRailMaterial';
import { DEFAULT_DESKTOP_RAIL_MATERIAL_LEVEL, SIDEBAR_MATERIAL_GLASS, SIDEBAR_MATERIAL_BLUR } from '../services/LayoutSettingsStore';

@Component
export struct SideBarMaterialLayer {
  @Prop materialLevel: number = DEFAULT_DESKTOP_RAIL_MATERIAL_LEVEL;
  @Prop layerPrefix: string = 'sidebar';
  @Prop materialType: number = SIDEBAR_MATERIAL_GLASS;

  private bleed(): number {
    return this.getUIContext().px2vp(getContext(this).resourceManager.getNumber($r('app.float.sidebar_material_bleed').id));
  }

  private extendedSize(): string {
    return 'calc(100% + ' + (this.bleed() * 2).toString() + 'vp)';
  }

  @Builder
  private GlassMaterial(): void {
    if (SystemMaterialUtil.isApi26OrAbove()) {
      Toggle({ type: ToggleType.Button, isOn: false })
        .width(this.extendedSize()).height(this.extendedSize()).position({ x: -this.bleed(), y: -this.bleed() })
        .borderRadius(0).borderWidth(0).borderColor(Color.Transparent).backgroundColor(Color.Transparent)
        .systemMaterial(SystemMaterialUtil.immersiveMaterial(this.materialLevel, false, false, false, undefined))
        .hitTestBehavior(HitTestMode.None).focusable(false).accessibilityLevel('no')
        .id(this.layerPrefix + '-native-material')
    } else {
      Column().width(this.extendedSize()).height(this.extendedSize()).position({ x: -this.bleed(), y: -this.bleed() })
        .borderRadius(0).backgroundColor(Color.Transparent)
        .backgroundBlurStyle(desktopRailBlurStyle(this.materialLevel))
        .hitTestBehavior(HitTestMode.None).id(this.layerPrefix + '-glass-fallback')
    }
  }

  @Builder
  private GradientBlurMaterial(): void {
    // A complete blur material provides its own mask. Do not depend on a
    // tint left by the system-sidebar or glass branch.
    Column().width(this.extendedSize()).height(this.extendedSize()).position({ x: -this.bleed(), y: -this.bleed() })
      .borderRadius(0).backgroundColor(Color.Transparent)
      .backgroundBlurStyle(desktopRailBlurStyle(this.materialLevel))
      .linearGradient({ angle: 120, colors: [[$r('app.color.sidebar_blur_start'), 0],
        [$r('app.color.sidebar_blur_end'), 1]] })
      .hitTestBehavior(HitTestMode.None).id(this.layerPrefix + '-gradient-blur-material')
  }

  build(): void {
    Stack() {
      if (this.materialLevel >= 0) {
        if (this.materialType === SIDEBAR_MATERIAL_GLASS) {
          this.GlassMaterial()
        } else if (this.materialType === SIDEBAR_MATERIAL_BLUR) {
          this.GradientBlurMaterial()
        }
      }
    }.width('100%').height('100%').borderRadius(0).clip(false)
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM],
        [LayoutSafeAreaEdge.START, LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.START, SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
  }
}
