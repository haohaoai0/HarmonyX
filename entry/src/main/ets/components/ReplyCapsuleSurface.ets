import { DEFAULT_REPLY_CAPSULE_MATERIAL_LEVEL } from '../services/AppearanceStore';
import { replyCapsuleMaterial } from '../utils/ReplyCapsuleMaterial';
import { materialModifier } from '../utils/SystemMaterial';
import { MaterialSurfaceHost } from './MaterialSurfaceHost';

// Keep the material shape independent of Navigation's internally clipped NavBar.
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
      // The material follows borderRadius itself; clipping cuts its light and deformation.
      .borderRadius(this.cornerRadius).clip(!this.materialEnabled)
      .attributeModifier(materialModifier(replyCapsuleMaterial(this.materialEnabled, this.materialLevel)))
  }

  @Builder
  private Surface(): void {
    if (this.transitionId.length > 0) {
      Stack({ alignContent: Alignment.BottomStart }) {
        this.SurfaceFrame()
      }
      .width('100%').height(this.capsuleHeight)
      .clip(false)
      .geometryTransition(this.transitionId, { follow: this.transitionFollow })
      .transition(TransitionEffect.OPACITY)
    } else {
      this.SurfaceFrame()
    }
  }

  build(): void {
    MaterialSurfaceHost({ surfaceHeight: this.capsuleHeight,
      surfaceContent: (): void => { this.Surface(); }
    })
    .backgroundColor(Color.Transparent).width('100%').height(this.capsuleHeight)
    .clip(false)
  }
}
