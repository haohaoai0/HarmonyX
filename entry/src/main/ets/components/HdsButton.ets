import { activateInputKey } from '../utils/InputSupport';
import { TouchHdrLight } from './TouchHdrLight';
import { motionDuration, motionScale, motionCurve, symbolMotionEnabled } from '../utils/AppMotion';
import { STORAGE_KEY_REDUCE_MOTION, STORAGE_KEY_SYMBOL_EFFECTS, STORAGE_KEY_MOTION_AMPLITUDE } from '../services/MotionSettingsStore';
import { hapticTick } from '../utils/Haptics';
import { DEFAULT_COMPONENT_HDR_ENABLED, DEFAULT_COMPONENT_HDR_RATIO, STORAGE_KEY_COMPONENT_HDR_ENABLED,
  STORAGE_KEY_COMPONENT_HDR_RATIO } from '../services/ComponentHdrSettingsStore';
import { ComponentHdrHighlight } from '../utils/ComponentHdrHighlight';
import { ConfigurationConstant } from '@kit.AbilityKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { uiMaterial } from '@kit.ArkUI';
import { HdsTabs, HdsTabsController, hdsEffect, hdsMaterial } from '@kit.UIDesignKit';
import { HdsMaterialUtil } from '../utils/HdsMaterialUtil';
import { SystemMaterialUtil } from '../utils/SystemMaterial';
import { materialModifier } from '../utils/SystemMaterial';
import { MaterialCompat } from '../utils/MaterialCompat';

/**
 * HDS floating material button adapted from F:\\Mark-dev.  The foreground
 * builder remains separate, so a branded translucent surface can sit above
 * the native material without losing its optical effect.
 */
@Component
export struct HdsButton {
  @StorageProp(STORAGE_KEY_REDUCE_MOTION) private motionReducedValue: boolean = false;
  @StorageProp(STORAGE_KEY_SYMBOL_EFFECTS) private symbolEffectsValue: boolean = true;
  @StorageProp(STORAGE_KEY_MOTION_AMPLITUDE) private motionAmplitudeValue: number = 1;
  @State private pressScale: number = 1;
  @State private symbolTrigger: number = -1;
  @StorageProp(STORAGE_KEY_COMPONENT_HDR_ENABLED) private componentHdrEnabled: boolean = DEFAULT_COMPONENT_HDR_ENABLED;
  @StorageProp(STORAGE_KEY_COMPONENT_HDR_RATIO) private componentHdrRatio: number = DEFAULT_COMPONENT_HDR_RATIO;
  @Prop barWidth: number = 52;
  @Prop barHeight: number = 58;
  @Prop iconResource: Resource | undefined = undefined;
  @Prop iconSize: number = 24;
  @Prop iconColor: ResourceColor[] = [Color.Gray];
  @Prop lightColor: ResourceColor | undefined = undefined;
  @Prop surfaceColor: ResourceColor = Color.Transparent;
  @Prop enableSurfaceBlur: boolean = false;
  @Prop enableShadow: boolean = true;
  @Prop @Watch('onPressLightAvailabilityChanged') enablePressLight: boolean = false;
  @Prop enableHdrHighlight: boolean = true;
  @Prop barPosition: BarPosition = BarPosition.End;
  @Prop barOverlap: boolean = true;
  @Prop forceHdsStyle: boolean = false;
  @Prop materialLevel: number = 2;
  @Prop useImmersiveMaterial: boolean = false;
  @Prop adaptiveForeground: boolean = false;
  @Prop immersiveTint: ResourceColor | undefined = undefined;
  @Prop panLightActive: boolean = false;

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
        .fontColor(this.iconColor)
        .symbolEffect(this.symbolEffectsValue && !this.motionReducedValue && this.motionAmplitudeValue > 0 ?
          new BounceSymbolEffect(EffectScope.WHOLE) : new SymbolEffect(), this.symbolTrigger);
    }
  }

  @BuilderParam buttonContent: () => void = this.defaultButtonBuilder;

  private shouldUseHdsMaterial(): boolean {
    return (this.forceHdsStyle || this.isHdsTabsEnabled) && HdsMaterialUtil.isHdsMaterialAvailable();
  }

  private shouldUseImmersiveMaterial(): boolean {
    return this.useImmersiveMaterial && SystemMaterialUtil.isApi26OrAbove();
  }

  private immersiveMaterial(): uiMaterial.Material | undefined {
    if (deviceInfo.apiAvailable('26.0.0')) {
      return new uiMaterial.ImmersiveMaterial({
        style: uiMaterial.ImmersiveStyle.THIN,
        materialColor: this.immersiveTint,
        interactive: false,
        applyShadow: this.enableShadow,
        colorInvert: this.adaptiveForeground,
        lightEffect: null
      });
    }
    return undefined;
  }

  private getCornerRadius(): number {
    return Math.min(this.barWidth, this.barHeight - 12) / 2;
  }

  aboutToDisappear(): void {
    this.isPressLightActive = false;
    this.isPanLightActive = false;
  }

  private onPressLightAvailabilityChanged(): void {
    if (!this.enablePressLight) {
      this.isPressLightActive = false;
      this.isPanLightActive = false;
    }
  }

  private pressLightActive(): boolean {
    return this.enablePressLight && (this.isPressLightActive || this.isPanLightActive || this.panLightActive);
  }

  @Builder
  private FallbackSurface(): void {
    Column()
      .width('100%')
      .height('100%')
      .backgroundColor(this.surfaceColor === Color.Transparent ?
        $r('sys.color.ohos_id_color_button_normal') : this.surfaceColor)
      .backgroundBlurStyle(this.enableSurfaceBlur ? BlurStyle.COMPONENT_ULTRA_THIN : BlurStyle.NONE);
  }

  build(): void {
    Stack() {
      Stack() {
        if (this.shouldUseImmersiveMaterial()) {
          Column()
            .width('100%')
            .height('100%');
        } else if (this.shouldUseHdsMaterial()) {
          if (deviceInfo.apiAvailable('6.1.0(23)')) {
            HdsTabs({ controller: this.tabsController, index: 0 }) {
            }
            .clip(false)
            .align(Alignment.Center)
            .barWidth(this.barWidth)
            .barHeight(this.barHeight - 12)
            .barOverlap(this.barOverlap)
            .barPosition(this.barPosition)
            .backgroundColor(Color.Transparent)
            .barBackgroundColor(Color.Transparent)
            .barBackgroundStyle({ maskColor: Color.Transparent, maskHeight: 1 })
            .barBackgroundBlurStyle(MaterialCompat.NO_PLATE_BLUR)
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
              gradientMask: { maskColor: Color.Transparent, maskHeight: 1 },
              barBottomMargin: 0,
              barSideMargin: 0,
              systemMaterialEffect: {
                materialType: hdsMaterial.MaterialType.IMMERSIVE,
                materialLevel: HdsMaterialUtil.resolveLegacyHdsMaterialLevel(this.materialLevel)
              },
              thermoCtrl: true
            });
          } else {
            this.FallbackSurface();
          }
        } else {
          this.FallbackSurface();
        }
      }
      .width(this.barWidth)
      .height(this.barHeight - 12)
      .borderRadius(this.getCornerRadius())
      .border({
        width: this.shouldUseHdsMaterial() || this.shouldUseImmersiveMaterial() ? 0 : 0.5,
        color: this.currentColorMode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT ?
          'rgba(255,255,255,0.72)' : 'rgba(255,255,255,0.14)'
      })
      .clip(!this.shouldUseHdsMaterial() && !this.shouldUseImmersiveMaterial())
      .hitTestBehavior(HitTestMode.None);

      Stack({ alignContent: Alignment.Center }) {
        Stack({ alignContent: Alignment.Center }) {
          this.buttonContent();
        }
        .width(this.barWidth)
        .height(this.barHeight - 12)
        .compositingFilter(ComponentHdrHighlight.filter(this.getUIContext(), this.componentHdrEnabled && this.enableHdrHighlight, this.componentHdrRatio));
      }
      .width(this.barWidth)
      .height(this.barHeight - 12)
      .backgroundColor(Color.Transparent)
      .borderRadius(this.getCornerRadius())
      .clip(!this.shouldUseImmersiveMaterial())
      .hitTestBehavior(HitTestMode.Default)
      .attributeModifier(materialModifier(this.shouldUseImmersiveMaterial() ? this.immersiveMaterial() : undefined));

      TouchHdrLight({ active: this.pressLightActive(), cornerRadius: this.getCornerRadius() })
        .width(this.barWidth).height(this.barHeight - 12);
    }
    .width(this.barWidth)
    .height(this.barHeight - 12)
    .borderRadius(this.getCornerRadius())
    .clip(false)
    .shadow(this.enableShadow && this.shouldUseHdsMaterial() && !this.shouldUseImmersiveMaterial() ?
      ShadowStyle.OUTER_FLOATING_SM : undefined)
    .visualEffect(new hdsEffect.HdsEffectBuilder()
      .pointLight({
          sourceType: this.pressLightActive() ?
          hdsEffect.PointLightSourceType.BRIGHT : hdsEffect.PointLightSourceType.NONE,
        illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
      })
      .buildEffect())
    .animation({ duration: motionDuration(150), curve: Curve.EaseOut })
    .scale({ x: this.motionReducedValue ? 1 : this.pressScale, y: this.motionReducedValue ? 1 : this.pressScale })
    .onTouch((event: TouchEvent): void => {
      if (event.type === TouchType.Down || event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.getUIContext().animateTo({ duration: motionDuration(130), curve: motionCurve() }, (): void => {
          this.pressScale = event.type === TouchType.Down ? motionScale(0.94) : 1;
        });
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
          hapticTick();
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
    .focusable(true).focusOnTouch(false).hoverEffect(HoverEffect.Highlight)
    .onKeyEvent((event: KeyEvent): boolean => activateInputKey(event, (): void => { if (this.onButtonClick !== undefined) { hapticTick(); this.onButtonClick(); } }))
    .onClick((): void => {
      if (this.onButtonClick !== undefined) {
        hapticTick();
        if (symbolMotionEnabled()) { this.symbolTrigger++; }
        this.onButtonClick();
      }
    });
  }
}
