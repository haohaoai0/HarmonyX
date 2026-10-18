import { DEFAULT_COMPONENT_HDR_RATIO, STORAGE_KEY_COMPONENT_HDR_RATIO } from '../services/ComponentHdrSettingsStore';
import { ComponentHdrHighlight } from '../utils/ComponentHdrHighlight';
import { motionDuration, motionScale, motionCurve } from '../utils/AppMotion';
import { hapticTick } from '../utils/Haptics';
import { SystemMaterialUtil } from '../utils/SystemMaterial';

@Component
export struct MaterialButton {
  @StorageProp(STORAGE_KEY_COMPONENT_HDR_RATIO) private componentHdrRatio: number = DEFAULT_COMPONENT_HDR_RATIO;
  @Prop buttonWidth: Length | undefined = 42;
  @Prop buttonHeight: Length = 42;
  @Prop buttonRadius: Length = 21;
  @Prop surfaceColor: ResourceColor = Color.Transparent;
  @Prop materialEnabled: boolean = true;
  @Prop materialLevel: number = 1;
  @Prop applyShadow: boolean = false;
  @Prop enableFallbackBlur: boolean = false;
  @Prop lightColor: ResourceColor | undefined = undefined;
  @Prop materialTint: ResourceColor | undefined = undefined;
  @Prop adaptiveForeground: boolean = false;
  @Prop buttonEnabled: boolean = true;
  @Prop enableHdrHighlight: boolean = true;
  @Prop buttonOpacity: number = 1;
  @Prop accessibilityLabel: string = '';
  @Prop buttonMonopolizeEvents: boolean = false;
  @Prop buttonBorderWidth: number = 0;
  @Prop buttonBorderColor: ResourceColor = Color.Transparent;
  @Prop buttonPressFeedback: boolean = true;
  @StorageProp('reduceMotionEnabled') private reduceMotion: boolean = false;
  @State private pressed: boolean = false;

  public onButtonClick: () => void = (): void => {
  };

  @Builder
  private DefaultContent(): void {
  }

  @BuilderParam buttonContent: () => void = this.DefaultContent;

  private material(): SystemUiMaterial | undefined {
    if (!this.materialEnabled) {
      return undefined;
    }
    return SystemMaterialUtil.immersiveMaterial(this.materialLevel, false, this.applyShadow,
      this.materialTint === undefined, this.lightColor, this.materialTint);
  }

  private onButtonTouch(event: TouchEvent): void {
    if (!this.buttonPressFeedback || !this.buttonEnabled) { return; }
    const pressed: boolean = event.type === TouchType.Down ? true :
      (event.type === TouchType.Up || event.type === TouchType.Cancel ? false : this.pressed);
    if (pressed === this.pressed) { return; }
    this.getUIContext().animateTo({ duration: motionDuration(130), curve: motionCurve() }, (): void => {
      this.pressed = pressed;
    });
  }

  @Builder
  private MaterialLayer(): void {
    if (this.materialEnabled && SystemMaterialUtil.isApi26OrAbove()) {
      Toggle({ type: ToggleType.Button, isOn: false })
        .width(LayoutPolicy.matchParent)
        .height(LayoutPolicy.matchParent)
        .borderRadius(this.buttonRadius)
        .backgroundColor(Color.Transparent)
        .focusable(false)
        .accessibilityLevel('no')
        .hitTestBehavior(HitTestMode.None)
        .systemMaterial(this.material())
    } else {
      Column()
        .width(LayoutPolicy.matchParent)
        .height(LayoutPolicy.matchParent)
        .backgroundColor(this.surfaceColor)
        .backgroundBlurStyle(this.enableFallbackBlur ? BlurStyle.COMPONENT_ULTRA_THIN : BlurStyle.NONE)
        .hitTestBehavior(HitTestMode.None)
    }
  }

  @Builder
  private ForegroundContent(): void {
    Stack({ alignContent: Alignment.Center }) {
      this.buttonContent();
    }
    .width(this.buttonWidth === undefined ? undefined : '100%')
    .height('100%')
    .compositingFilter(ComponentHdrHighlight.filter(this.getUIContext(), this.enableHdrHighlight && this.buttonEnabled, this.componentHdrRatio))
    .hitTestBehavior(HitTestMode.None)
  }

  build(): void {
    Stack({ alignContent: Alignment.Center }) {
      if (this.adaptiveForeground && this.materialEnabled && SystemMaterialUtil.isApi26OrAbove()) {
        // Automatic foreground inversion only reaches descendants of the material node.
        Toggle({ type: ToggleType.Button, isOn: false }) {
          this.ForegroundContent();
        }
        .width(this.buttonWidth === undefined ? undefined : '100%')
        .height('100%')
        .padding(0)
        .borderRadius(this.buttonRadius)
        .backgroundColor(Color.Transparent)
        .focusable(false)
        .accessibilityLevel('no')
        .hitTestBehavior(HitTestMode.None)
        .systemMaterial(this.material())
      } else {
        this.MaterialLayer();
        this.ForegroundContent();
      }
    }
    .width(this.buttonWidth)
    .height(this.buttonHeight)
    .borderRadius(this.buttonRadius)
    .border({ width: this.buttonBorderWidth, color: this.buttonBorderColor })
    .clip(true)
    .onClick((): void => {
      hapticTick();
      this.onButtonClick();
    })
    .enabled(this.buttonEnabled)
    .scale({ x: this.buttonPressFeedback && this.pressed && !this.reduceMotion ? motionScale(0.96) : 1,
      y: this.buttonPressFeedback && this.pressed && !this.reduceMotion ? motionScale(0.96) : 1 })
    .opacity(this.buttonOpacity * (this.buttonPressFeedback && this.pressed ? 0.82 : 1))
    .onTouch((event: TouchEvent): void => this.onButtonTouch(event))
    .accessibilityText(this.accessibilityLabel)
    .monopolizeEvents(this.buttonMonopolizeEvents)
  }
}
