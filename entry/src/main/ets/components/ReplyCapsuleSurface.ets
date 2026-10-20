import { DEFAULT_REPLY_CAPSULE_MATERIAL_LEVEL } from '../services/AppearanceStore';
import { replyCapsuleMaterial } from '../utils/ReplyCapsuleMaterial';
import { materialModifier } from '../utils/SystemMaterial';

// Navigation's custom title hosts the material just like the reply composer.
// Keep this presentation-only so settings can reuse it without editor lifecycle.
@Component
export struct ReplyCapsuleSurface {
  @Prop capsuleHeight: number = 64;
  @Prop cornerRadius: number = 32;
  @Prop materialEnabled: boolean = false;
  @Prop materialLevel: number = DEFAULT_REPLY_CAPSULE_MATERIAL_LEVEL;
  @Prop transitionId: string = '';
  @Prop transitionFollow: boolean = false;
  @BuilderParam capsuleContent: () => void = this.EmptyContent;

  @Builder
  private EmptyContent(): void {}

  @Builder
  private SurfaceFrame(): void {
    Column() { this.capsuleContent() }
      .width('100%').height('100%')
      .backgroundColor(this.materialEnabled ? Color.Transparent : $r('app.color.bg_field'))
      .border({ width: this.materialEnabled ? 0 : 1, color: $r('app.color.divider') })
      .borderRadius(this.cornerRadius).clip(true)
      .attributeModifier(materialModifier(replyCapsuleMaterial(this.materialEnabled, this.materialLevel)))
  }

  @Builder
  private Surface(): void {
    if (this.transitionId.length > 0) {
      Stack({ alignContent: Alignment.BottomStart }) {
        this.SurfaceFrame()
      }
      .width('100%').height(this.capsuleHeight)
      .geometryTransition(this.transitionId, { follow: this.transitionFollow })
      .transition(TransitionEffect.OPACITY)
    } else {
      this.SurfaceFrame()
    }
  }

  build(): void {
    Navigation() {
      Column().width('100%').height('100%').hitTestBehavior(HitTestMode.None)
    }
    .title({ builder: (): void => { this.Surface(); }, height: this.capsuleHeight }, { barStyle: BarStyle.STACK })
    .titleMode(NavigationTitleMode.Full).mode(NavigationMode.Stack).hideToolBar(true)
    .backgroundColor(Color.Transparent).width('100%').height(this.capsuleHeight)
  }
}
