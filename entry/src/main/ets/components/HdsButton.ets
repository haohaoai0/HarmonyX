import { ConfigurationConstant } from '@kit.AbilityKit';
import { HdsTabs, HdsTabsController, hdsEffect, hdsMaterial } from '@kit.UIDesignKit';
import { HdsMaterialUtil } from '../utils/HdsMaterialUtil';

/**
 * HDS floating material button adapted from F:\\Mark-dev.  The foreground
 * builder remains separate, so a branded translucent surface can sit above
 * the native material without losing its optical effect.
 */
@Component
export struct HdsButton {
  @Prop barWidth: number = 52;
  @Prop barHeight: number = 58;
  @Prop iconResource: Resource | undefined = undefined;
  @Prop iconSize: number = 24;
  @Prop iconColor: ResourceColor[] = [Color.Gray];
  @Prop lightColor: ResourceColor | undefined = undefined;
  @Prop surfaceColor: ResourceColor = Color.Transparent;
  @Prop enableSurfaceBlur: boolean = false;
  @Prop enableShadow: boolean = true;
  @Prop enablePressLight: boolean = false;
  @Prop barPosition: BarPosition = BarPosition.End;
  @Prop barOverlap: boolean = true;
  @Prop forceHdsStyle: boolean = false;
  @Prop materialLevel: number = 2;

  @StorageLink('isHdsTabsEnabled') isHdsTabsEnabled: boolean = false;
  @StorageLink('currentColorMode') currentColorMode: number = ConfigurationConstant.ColorMode.COLOR_MODE_DARK;

  @State private isPressLightActive: boolean = false;
  @State private isPanLightActive: boolean = false;
  public onButtonClick: (() => void) | undefined = undefined;
  public onButtonPanStart: (() => void) | undefined = undefined;
  public onButtonPanUpdate: ((event: GestureEvent) => void) | undefined = undefined;
  public onButtonPanEnd: (() => void) | undefined = undefined;
  private tabsController: HdsTabsController = new HdsTabsController();

  @Builder
  defaultButtonBuilder(): void {
    if (this.iconResource !== undefined) {
      SymbolGlyph(this.iconResource)
        .fontSize(this.iconSize)
        .fontColor(this.iconColor);
    }
  }

  @BuilderParam buttonContent: () => void = this.defaultButtonBuilder;

  private shouldUseHdsMaterial(): boolean {
    return (this.forceHdsStyle || this.isHdsTabsEnabled) && HdsMaterialUtil.isHdsMaterialAvailable();
  }

  private getCornerRadius(): number {
    return Math.min(this.barWidth, this.barHeight - 12) / 2;
  }

  build(): void {
    Stack() {
      Stack() {
        if (this.shouldUseHdsMaterial()) {
          HdsTabs({ controller: this.tabsController, index: 0 }) {
          }
          .clip(false)
          .align(Alignment.Center)
          .barWidth(this.barWidth)
          .barHeight(this.barHeight - 12)
          .barOverlap(this.barOverlap)
          .barPosition(this.barPosition)
          .backgroundColor(Color.Transparent)
          .shadow(undefined)
          .vertical(false)
          .monopolizeEvents(false)
          .barFloatingStyle({
            barWidth: {
              smallWidth: this.barWidth,
              mediumWidth: this.barWidth,
              largeWidth: this.barWidth
            },
            lightColor: this.lightColor,
            gradientMask: { maskColor: Color.Transparent },
            barBottomMargin: 0,
            barSideMargin: 0,
            systemMaterialEffect: {
              materialType: hdsMaterial.MaterialType.IMMERSIVE,
              materialLevel: HdsMaterialUtil.resolveLegacyHdsMaterialLevel(this.materialLevel)
            },
            thermoCtrl: true
          });
        } else {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor(this.surfaceColor === Color.Transparent ?
              $r('sys.color.ohos_id_color_button_normal') : this.surfaceColor)
            .backgroundBlurStyle(this.enableSurfaceBlur ? BlurStyle.COMPONENT_ULTRA_THIN : BlurStyle.NONE);
        }
      }
      .width(this.barWidth)
      .height(this.barHeight - 12)
      .borderRadius(this.getCornerRadius())
      .border({
        width: this.shouldUseHdsMaterial() ? 0 : 0.5,
        color: this.currentColorMode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT ?
          'rgba(255,255,255,0.72)' : 'rgba(255,255,255,0.14)'
      })
      .clip(true)
      .hitTestBehavior(HitTestMode.None);

      Stack({ alignContent: Alignment.Center }) {
        this.buttonContent();
      }
      .width(this.barWidth)
      .height(this.barHeight - 12)
      .hitTestBehavior(HitTestMode.Default);
    }
    .width(this.barWidth)
    .height(this.barHeight - 12)
    .borderRadius(this.getCornerRadius())
    .clip(false)
    .shadow(this.enableShadow && this.shouldUseHdsMaterial() ? ShadowStyle.OUTER_FLOATING_SM : undefined)
    .visualEffect(new hdsEffect.HdsEffectBuilder()
      .pointLight({
        sourceType: this.enablePressLight && (this.isPressLightActive || this.isPanLightActive) ?
          hdsEffect.PointLightSourceType.BRIGHT : hdsEffect.PointLightSourceType.NONE,
        illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
      })
      .buildEffect())
    .animation({ duration: 150, curve: Curve.EaseOut })
    .onTouch((event: TouchEvent): void => {
      if (!this.enablePressLight) {
        return;
      }
      if (event.type === TouchType.Down) {
        this.isPressLightActive = true;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.isPressLightActive = false;
      }
    })
    .gesture(
      PanGesture({ fingers: 1, direction: PanDirection.All })
        .onActionStart((): void => {
          // Pan recognition can cancel the touch sequence. Keep a dedicated
          // drag state so the point light remains active until pan end.
          this.isPanLightActive = true;
          if (this.onButtonPanStart !== undefined) {
            this.onButtonPanStart();
          }
        })
        .onActionUpdate((event: GestureEvent): void => {
          if (this.onButtonPanUpdate !== undefined) {
            this.onButtonPanUpdate(event);
          }
        })
        .onActionEnd((): void => {
          this.isPanLightActive = false;
          if (this.onButtonPanEnd !== undefined) {
            this.onButtonPanEnd();
          }
        })
        .onActionCancel((): void => {
          this.isPanLightActive = false;
          if (this.onButtonPanEnd !== undefined) {
            this.onButtonPanEnd();
          }
        })
    )
    .onClick((): void => {
      if (this.onButtonClick !== undefined) {
        this.onButtonClick();
      }
    });
  }
}
