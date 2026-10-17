import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { MaterialButton } from './MaterialButton';

// Hold-to-speed feedback. It is built like the feed's new-posts capsule: one
// MaterialButton for the glass, with the rate and the state spelled out inside.
const CAPSULE_HEIGHT: number = 40;
const CAPSULE_PADDING: number = 18;
const CAPSULE_TEXT_GAP: number = 8;

@Component
export struct VideoHoldSpeedCapsule {
  @Prop rateLabel: string = '2x';
  @Prop hint: string = '';
  @Prop lightColor: ResourceColor = Color.White;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;

  private textWidth(text: string, fontSize: Resource, weight: FontWeight): number {
    const measured: number = this.getUIContext().getMeasureUtils().measureText({
      textContent: text,
      fontSize: fontSize,
      fontWeight: weight
    });
    return this.getUIContext().px2vp(measured);
  }

  // The material layer and its content share one fixed box, so the width has to
  // be known before layout.
  private capsuleWidth(): number {
    const rate: number = this.textWidth(this.rateLabel, $r('sys.float.Body_L'), FontWeight.Bold);
    const hint: number = this.textWidth(this.hint, $r('sys.float.Body_S'), FontWeight.Regular);
    return Math.ceil(rate + CAPSULE_TEXT_GAP + hint + CAPSULE_PADDING * 2);
  }

  build(): void {
    MaterialButton({
      buttonWidth: this.capsuleWidth(),
      buttonHeight: CAPSULE_HEIGHT,
      buttonRadius: CAPSULE_HEIGHT / 2,
      surfaceColor: '#66000000',
      materialLevel: 1,
      applyShadow: true,
      enableFallbackBlur: true,
      lightColor: this.lightColor,
      accessibilityLabel: this.rateLabel + ' ' + this.hint
    }) {
      Row({ space: CAPSULE_TEXT_GAP }) {
        Text(this.rateLabel).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_L'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_on_brand'))
          .maxFontScale(1)
        Text(this.hint).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('app.color.text_on_brand'))
          .maxFontScale(1)
      }
      .alignItems(VerticalAlign.Center)
    }
  }
}
