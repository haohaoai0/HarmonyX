import { DEFAULT_REPLY_CAPSULE_MATERIAL_LEVEL } from '../services/AppearanceStore';
import { ReplyCapsuleSurface } from './ReplyCapsuleSurface';

// Keep the editor mounted while its collapsed entry and action capsule separate.
@Component
export struct ReplyCapsuleLayout {
  @Prop split: boolean = false;
  @Prop expanded: boolean = false;
  @Prop capsuleHeight: number = 64;
  @Prop actionWidth: number = 232;
  @Prop transitionId: string = 'reply-capsule-long-take';
  @Prop materialEnabled: boolean = false;
  @Prop materialLevel: number = DEFAULT_REPLY_CAPSULE_MATERIAL_LEVEL;
  @BuilderParam capsuleContent: () => void = this.EmptyContent;
  @BuilderParam postActions: () => void = this.EmptyContent;

  @Builder
  private EmptyContent(): void {}

  build(): void {
    Column() {
      if (this.split && this.expanded) {
        Stack({ alignContent: Alignment.BottomStart }) {
          ReplyCapsuleSurface({ capsuleHeight: this.capsuleHeight, materialEnabled: this.materialEnabled,
            materialLevel: this.materialLevel, transitionId: this.transitionId, transitionFollow: true,
            capsuleContent: (): void => { this.capsuleContent(); } })
            .width('100%').height('100%')
        }
        .width('100%').height('100%')
        .id(this.transitionId + '-expanded')
      } else if (this.split) {
        Row({ space: 8 }) {
          Stack({ alignContent: Alignment.BottomStart }) {
            ReplyCapsuleSurface({ capsuleHeight: this.capsuleHeight, materialEnabled: this.materialEnabled,
              materialLevel: this.materialLevel, transitionId: this.transitionId,
              capsuleContent: (): void => { this.capsuleContent(); } })
              .width('100%').height('100%')
          }
          .layoutWeight(1).height('100%')
          .id(this.transitionId + '-collapsed')
          ReplyCapsuleSurface({ capsuleHeight: this.capsuleHeight, materialEnabled: this.materialEnabled,
            materialLevel: this.materialLevel, capsuleContent: (): void => { this.postActions(); } })
            .width(this.actionWidth)
            .id('reply-capsule-post-actions')
            .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ x: 12 }))
              .animation({ duration: 180, curve: Curve.EaseOut }))
        }.width('100%').height('100%')
      } else {
        ReplyCapsuleSurface({ capsuleHeight: this.capsuleHeight, materialEnabled: this.materialEnabled,
          materialLevel: this.materialLevel, capsuleContent: (): void => { this.capsuleContent(); } })
          .width('100%').height('100%')
      }
    }
    .width('100%').height(this.capsuleHeight)
    .justifyContent(FlexAlign.End)
    .alignItems(HorizontalAlign.Start)
  }
}
