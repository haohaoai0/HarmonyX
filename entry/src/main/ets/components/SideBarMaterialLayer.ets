import { SystemMaterialUtil } from '../utils/SystemMaterial';
import { desktopRailBlurStyle } from '../utils/DesktopRailMaterial';
import { SIDEBAR_MATERIAL_GLASS, STORAGE_KEY_SIDEBAR_MATERIAL_TYPE } from '../services/LayoutSettingsStore';

@Component
export struct SideBarMaterialLayer {
  @Prop materialLevel: number = 0;
  @Prop layerPrefix: string = 'sidebar';
  @Prop useBackdropBlur: boolean = false;
  @StorageProp(STORAGE_KEY_SIDEBAR_MATERIAL_TYPE) private materialType: number = SIDEBAR_MATERIAL_GLASS;

  private bleed(): number {
    return this.getUIContext().px2vp(getContext(this).resourceManager.getNumber($r('app.float.sidebar_material_bleed').id));
  }

  private extendedSize(): string {
    return 'calc(100% + ' + (this.bleed() * 2).toString() + 'vp)';
  }

  private blurRadius(): number {
    let radius: Resource = $r('app.float.sidebar_blur_radius_regular');
    if (this.materialLevel <= 0) { radius = $r('app.float.sidebar_blur_radius_ultra_thin'); }
    else if (this.materialLevel === 1) { radius = $r('app.float.sidebar_blur_radius_thin'); }
    else if (this.materialLevel === 3) { radius = $r('app.float.sidebar_blur_radius_thick'); }
    else if (this.materialLevel >= 4) { radius = $r('app.float.sidebar_blur_radius_ultra_thick'); }
    return this.getUIContext().px2vp(getContext(this).resourceManager.getNumber(radius.id));
  }

  build(): void {
    Stack() {
      if (this.materialLevel >= 0) {
      if (SystemMaterialUtil.isApi26OrAbove() && this.materialType === SIDEBAR_MATERIAL_GLASS) {
        Toggle({ type: ToggleType.Button, isOn: false })
          .width(this.extendedSize()).height(this.extendedSize()).position({ x: -this.bleed(), y: -this.bleed() })
          .borderRadius(0).borderWidth(0).borderColor(Color.Transparent).backgroundColor(Color.Transparent)
          .systemMaterial(SystemMaterialUtil.immersiveMaterial(this.materialLevel, false, false, false, undefined))
          .hitTestBehavior(HitTestMode.None).focusable(false).accessibilityLevel('no')
          .id(this.layerPrefix + '-native-material')
      } else {
        if (this.useBackdropBlur) {
          // HdsSideBar already supplies its container tint. Avoid adding the
          // preset material's mask to it; blur the backdrop and tint once here.
          Column().width(this.extendedSize()).height(this.extendedSize()).position({ x: -this.bleed(), y: -this.bleed() })
            .borderRadius(0).backgroundColor(Color.Transparent)
            .backdropBlur(this.blurRadius())
            .hitTestBehavior(HitTestMode.None).id(this.layerPrefix + '-blur-material')
          Column().width(this.extendedSize()).height(this.extendedSize()).position({ x: -this.bleed(), y: -this.bleed() })
            .borderRadius(0)
            .linearGradient({ angle: 120, colors: [[$r('app.color.sidebar_blur_start'), 0],
              [$r('app.color.sidebar_blur_end'), 1]] })
            .hitTestBehavior(HitTestMode.None).id(this.layerPrefix + '-blur-tint')
        } else {
          Column().width(this.extendedSize()).height(this.extendedSize()).position({ x: -this.bleed(), y: -this.bleed() })
            .borderRadius(0).backgroundColor(Color.Transparent)
            .backgroundBlurStyle(desktopRailBlurStyle(this.materialLevel))
            .linearGradient({ angle: 120, colors: [[$r('app.color.sidebar_blur_start'), 0],
              [$r('app.color.sidebar_blur_end'), 1]] })
            .hitTestBehavior(HitTestMode.None).id(this.layerPrefix + '-blur-material')
        }
      }
      }
    }.width('100%').height('100%').borderRadius(0).clip(false)
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM],
        [LayoutSafeAreaEdge.START, LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.START, SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
  }
}
