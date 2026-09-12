import { common } from '@kit.AbilityKit';
import { curves, display } from '@kit.ArkUI';
import { HdsButton } from './HdsButton';
import { GripHandManager } from '../utils/GripHandManager';

const FAB_SIZE: number = 56;
const FAB_SIDE_MARGIN: number = 16;
const FAB_TOP_LIMIT: number = 12;
const HDS_TAB_BAR_HEIGHT: number = 56;
const FAB_BAR_GAP: number = 24;

/**
 * Full-page draggable compose action. Its position follows the MiniBeerHall
 * handedness subscription, while its surface is supplied by Mark-dev's
 * HdsButton material wrapper. Click and pan are handled by the same
 * hit-testable material root, matching MiniBeerHall's record add button.
 */
@Component
export struct FloatingComposeButton {
  @Prop bottomInset: number = 0;
  onCompose: () => void = () => {
  };

  @State private buttonX: number = 0;
  @State private buttonY: number = 0;
  @State private isDragging: boolean = false;
  private pageWidth: number = 0;
  private pageHeight: number = 0;
  private initialButtonX: number = 0;
  private initialButtonY: number = 0;
  private lastHand: string = 'right';
  private hasPositioned: boolean = false;

  aboutToAppear(): void {
    this.readScreenSize();
    this.initializeGripHand();
  }

  aboutToDisappear(): void {
    GripHandManager.getInstance().stop();
  }

  private async initializeGripHand(): Promise<void> {
    const context: common.Context | undefined = this.getUIContext().getHostContext();
    if (context !== undefined) {
      await GripHandManager.getInstance().load(context);
    }
    this.lastHand = GripHandManager.getInstance().getLastHand();
    this.positionForHand(this.lastHand, false);
    GripHandManager.getInstance().start((hand: string): void => {
      this.onGripHandChanged(hand);
    });
  }

  private onGripHandChanged(hand: string): void {
    this.lastHand = hand;
    this.positionForHand(hand, true);
    const context: common.Context | undefined = this.getUIContext().getHostContext();
    if (context !== undefined) {
      GripHandManager.getInstance().saveLastHand(context, hand);
    }
  }

  private readScreenSize(): void {
    try {
      const uiContext: UIContext = this.getUIContext();
      const displayObject: display.Display = display.getDefaultDisplaySync();
      this.pageWidth = uiContext.px2vp(displayObject.width);
      this.pageHeight = uiContext.px2vp(displayObject.height);
    } catch (error) {
      this.pageWidth = 360;
      this.pageHeight = 780;
    }
  }

  private positionForHand(hand: string, animated: boolean): void {
    if (this.pageWidth <= 0 || this.pageHeight <= 0) {
      return;
    }
    const targetX: number = hand === 'left' ? FAB_SIDE_MARGIN :
      this.pageWidth - FAB_SIZE - FAB_SIDE_MARGIN;
    const targetY: number = this.pageHeight - FAB_SIZE - HDS_TAB_BAR_HEIGHT - FAB_BAR_GAP - this.bottomInset;
    const safeX: number = this.clampX(targetX);
    const safeY: number = this.clampY(targetY);
    this.hasPositioned = true;
    if (animated) {
      this.getUIContext().animateTo({ duration: 400, curve: curves.springMotion(0.6, 0.9) }, (): void => {
        this.buttonX = safeX;
        this.buttonY = safeY;
      });
      return;
    }
    this.buttonX = safeX;
    this.buttonY = safeY;
  }

  private clampX(value: number): number {
    const maxX: number = Math.max(FAB_SIDE_MARGIN, this.pageWidth - FAB_SIZE - FAB_SIDE_MARGIN);
    return Math.min(Math.max(value, FAB_SIDE_MARGIN), maxX);
  }

  private clampY(value: number): number {
    const maxY: number = Math.max(FAB_TOP_LIMIT,
      this.pageHeight - FAB_SIZE - this.bottomInset - FAB_SIDE_MARGIN);
    return Math.min(Math.max(value, FAB_TOP_LIMIT), maxY);
  }

  private handlePanStart(): void {
    this.isDragging = true;
    this.initialButtonX = this.buttonX;
    this.initialButtonY = this.buttonY;
  }

  private handlePanUpdate(event: GestureEvent): void {
    this.buttonX = this.clampX(this.initialButtonX + event.offsetX);
    this.buttonY = this.clampY(this.initialButtonY + event.offsetY);
  }

  private handlePanEnd(): void {
    this.isDragging = false;
  }

  @Builder
  private BlueComposeContent(): void {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width(FAB_SIZE)
        .height(FAB_SIZE)
        .backgroundColor($r('app.color.compose_material_overlay'))
        .border({ width: 1, color: $r('app.color.compose_material_border') })
        .borderRadius(FAB_SIZE / 2);
      SymbolGlyph($r('sys.symbol.square_and_pencil'))
        .fontSize(24)
        .fontColor([$r('app.color.text_on_brand')]);
    }
    .width(FAB_SIZE)
    .height(FAB_SIZE);
  }

  build(): void {
    Stack() {
      HdsButton({
        barWidth: FAB_SIZE,
        barHeight: FAB_SIZE + 12,
        lightColor: $r('app.color.brand'),
        materialLevel: 2,
        forceHdsStyle: true,
        enableShadow: true,
        enablePressLight: true,
        onButtonClick: (): void => {
          this.onCompose();
        },
        onButtonPanStart: (): void => {
          this.handlePanStart();
        },
        onButtonPanUpdate: (event: GestureEvent): void => {
          this.handlePanUpdate(event);
        },
        onButtonPanEnd: (): void => {
          this.handlePanEnd();
        }
      }) {
        this.BlueComposeContent();
      }
    }
    .width(FAB_SIZE)
    .height(FAB_SIZE)
    .position({ x: this.buttonX, y: this.buttonY })
    .scale({ x: this.isDragging ? 1.08 : 1, y: this.isDragging ? 1.08 : 1 })
    .animation({ duration: 150, curve: Curve.EaseOut });
  }
}
