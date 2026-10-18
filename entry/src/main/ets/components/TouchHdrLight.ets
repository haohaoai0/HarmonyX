import { deviceInfo } from '@kit.BasicServicesKit';
import { DEFAULT_COMPONENT_HDR_RATIO, STORAGE_KEY_COMPONENT_HDR_RATIO } from '../services/ComponentHdrSettingsStore';
import { ComponentHdrHighlight } from '../utils/ComponentHdrHighlight';

// Keep this optical layer separate from existing HDR icons and native material.
// Native point lights retain their original illumination of nearby components.
@Component
export struct TouchHdrLight {
  @Prop active: boolean = false;
  @Prop cornerRadius: Length = 0;
  @StorageProp(STORAGE_KEY_COMPONENT_HDR_RATIO) private componentHdrRatio: number = DEFAULT_COMPONENT_HDR_RATIO;

  private lightVisible(): boolean {
    return this.active && deviceInfo.sdkApiVersion >= 24 &&
      Number.isFinite(this.componentHdrRatio) && this.componentHdrRatio > 1;
  }

  build(): void {
    Column()
      .width('100%').height('100%')
      .radialGradient({
        center: ['50%', '12%'],
        radius: '90%',
        colors: [[$r('app.color.hdr_touch_light_center'), 0],
          [$r('app.color.hdr_touch_light_edge'), 0.55], [Color.Transparent, 1]]
      })
      .border({ width: $r('app.float.hdr_touch_light_border_width'), color: $r('app.color.hdr_touch_light_border') })
      .borderRadius(this.cornerRadius).clip(true)
      .compositingFilter(ComponentHdrHighlight.filter(this.getUIContext(), this.lightVisible(), this.componentHdrRatio))
      .opacity(this.lightVisible() ? 1 : 0)
      .renderGroup(true)
      .hitTestBehavior(HitTestMode.None)
      .accessibilityLevel('no-hide-descendants')
      .id(this.lightVisible() ? 'hdr-touch-light-active' : 'hdr-touch-light-idle')
  }
}
