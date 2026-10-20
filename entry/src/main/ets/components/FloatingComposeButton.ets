import { mixedAccentRoleColor } from '../utils/AccentPalette';
import { motionDuration, motionCurve, motionScale } from '../utils/AppMotion';
import { DEFAULT_COMPONENT_HDR_ENABLED, DEFAULT_COMPONENT_HDR_RATIO, STORAGE_KEY_COMPONENT_HDR_ENABLED,
  STORAGE_KEY_COMPONENT_HDR_RATIO } from '../services/ComponentHdrSettingsStore';
import { common } from '@kit.AbilityKit';
import { ColorMetrics, curves, display } from '@kit.ArkUI';
import { HdsButton } from './HdsButton';
import { GripHandManager } from '../utils/GripHandManager';
import { SystemMaterialUtil } from '../utils/SystemMaterial';
import { ComponentHdrHighlight } from '../utils/ComponentHdrHighlight';
import { STORAGE_KEY_FLOATING_COMPOSE_MATERIAL_TINT } from '../services/InteractionSettingsStore';

const FAB_SIZE: number = 56;
const FAB_SIDE_MARGIN: number = 16;
const FAB_TOP_LIMIT: number = 12;
const HDS_TAB_BAR_HEIGHT: number = 56;
const FAB_BAR_GAP: number = 24;
const GRIP_SUBSCRIBER_KEY: string = 'floating-compose-button';

/**
 * Full-page draggable action button. Its position follows the MiniBeerHall
 * handedness subscription, while its surface is supplied by Mark-dev's
 * HdsButton material wrapper. Click and pan are handled by the same
 * hit-testable material root, matching MiniBeerHall's record add button.
 *
 * The same control composes on the feed, replies to an author on their profile,
 * refreshes a deep Home timeline, jumps to the top on Explore, and starts read-aloud from a post
 * page. Pressing or dragging it also makes it an HDS point light, so the
 * illuminated cards around it pick up the glow.
 */
@Component
export struct FloatingComposeButton {
  @StorageProp(STORAGE_KEY_COMPONENT_HDR_ENABLED) private componentHdrEnabled: boolean = DEFAULT_COMPONENT_HDR_ENABLED;
  @StorageProp(STORAGE_KEY_COMPONENT_HDR_RATIO) private componentHdrRatio: number = DEFAULT_COMPONENT_HDR_RATIO;
  @Prop @Watch('onBottomClearanceChanged') bottomInset: number = 0;
  @StorageProp('harmonyx.accent_theme') private accentTheme: string = '';
  @StorageLink('harmonyx.accent_color') accentColor: string = '#007DFF';
  @StorageProp(STORAGE_KEY_FLOATING_COMPOSE_MATERIAL_TINT) private materialTintEnabled: boolean = true;
  @StorageProp('harmonyx.grip_floating_enabled') @Watch('onGripHandEnabledChanged') private componentGripEnabled: boolean = true;
  @StorageLink('harmonyx.grip_hand_enabled') @Watch('onGripHandEnabledChanged')
  gripHandEnabled: boolean = true;
  @StorageLink('harmonyx.grip_preferred_hand') @Watch('onPreferredHandChanged')
  preferredHand: string = 'right';
  onCompose: () => void = () => {
  };
  onReply: () => void = () => {
  };
  @Prop accessibilityLabel: string = '';
  @Prop composeSymbol: Resource = $r('sys.symbol.square_and_pencil');
  @Prop composeColor: ResourceColor | undefined = undefined;
  @Prop @Watch('onBottomClearanceChanged') bottomBarHeight: number = HDS_TAB_BAR_HEIGHT;
  @Prop gripSubscriberKey: string = GRIP_SUBSCRIBER_KEY;
  // The same slot serves compose, Home refresh, Explore jump-to-top, and
  // read-aloud according to the owning page's scroll state.
  @Prop @Watch('onModeChanged') mode: string = 'compose';
  @Prop @Watch('onRefreshingChanged') refreshing: boolean = false;
  // Hidden buttons are removed from the UI tree, including their hit regions.
  @Prop @Watch('onHiddenChanged') hidden: boolean = false;
  onTop: () => void = () => {
  };
  onRefresh: () => void = () => {
  };
  onRead: () => void = () => {
  };

  @State private buttonX: number = 0;
  @State private buttonY: number = 0;
  @State private isDragging: boolean = false;
  @State private displayedMode: string = 'compose';
  @State private displayedRefreshing: boolean = false;
  private pageWidth: number = 0;
  private pageHeight: number = 0;
  private initialButtonX: number = 0;
  private initialButtonY: number = 0;
  private lastHand: string = 'right';
  private hasPositioned: boolean = false;
  private manuallyPositioned: boolean = false;
  private lastBottomClearance: number = HDS_TAB_BAR_HEIGHT;

  aboutToAppear(): void {
    this.lastBottomClearance = this.bottomBarHeight + this.bottomInset;
    this.displayedMode = this.mode;
    this.displayedRefreshing = this.refreshing;
    this.readScreenSize();
    this.initializeGripHand();
  }

  private onModeChanged(): void {
    this.displayedMode = this.mode;
  }

  private onRefreshingChanged(): void {
    this.displayedRefreshing = this.refreshing;
  }

  private onHiddenChanged(): void {
    if (this.hidden) { this.isDragging = false; }
  }

  private onBottomClearanceChanged(): void {
    const clearance: number = this.bottomBarHeight + this.bottomInset;
    const delta: number = clearance - this.lastBottomClearance;
    this.lastBottomClearance = clearance;
    if (this.hasPositioned && !this.isDragging && !this.manuallyPositioned) { this.buttonY = this.clampY(this.buttonY - delta); }
  }

  aboutToDisappear(): void {
    GripHandManager.getInstance().stopFor(this.gripSubscriberKey);
  }

  private async initializeGripHand(): Promise<void> {
    const context: common.Context | undefined = this.getUIContext().getHostContext();
    if (context !== undefined) {
      await GripHandManager.getInstance().load(context);
      this.gripHandEnabled = GripHandManager.getInstance().isGripHandEnabled();
      this.preferredHand = GripHandManager.getInstance().getPreferredHand();
    }
    this.lastHand = this.componentGripEnabled ? GripHandManager.getInstance().getLastHand() : this.preferredHand;
    if (!this.manuallyPositioned) { this.positionForHand(this.lastHand, false); }
    if (this.gripHandEnabled && this.componentGripEnabled) {
      GripHandManager.getInstance().startFor(this.gripSubscriberKey, (hand: string): void => {
        this.onGripHandChanged(hand);
      });
    } else {
      GripHandManager.getInstance().stopFor(this.gripSubscriberKey);
    }
  }

  private onGripHandEnabledChanged(): void {
    if (this.gripHandEnabled && this.componentGripEnabled) {
      this.initializeGripHand();
      return;
    }
    GripHandManager.getInstance().stopFor(this.gripSubscriberKey);
    this.onPreferredHandChanged();
  }

  private onPreferredHandChanged(): void {
    if ((!this.gripHandEnabled || !this.componentGripEnabled)) {
      this.lastHand = this.preferredHand;
      this.positionForHand(this.lastHand, true);
    }
  }

  private onGripHandChanged(hand: string): void {
    if ((!this.gripHandEnabled || !this.componentGripEnabled)) { return; }
    this.lastHand = hand;
    if (!this.isDragging) { this.positionForHand(hand, true); }
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
    const targetY: number = this.manuallyPositioned ? this.buttonY :
      this.pageHeight - FAB_SIZE - this.bottomBarHeight - FAB_BAR_GAP - this.bottomInset;
    const safeX: number = this.clampX(targetX);
    const safeY: number = this.clampY(targetY);
    this.hasPositioned = true;
    if (animated) {
      this.getUIContext().animateTo({ duration: motionDuration(400), curve: motionCurve() }, (): void => {
        this.buttonX = safeX;
        this.buttonY = safeY;
      });
      return;
    }
    this.buttonX = safeX;
    this.buttonY = safeY;
  }

  private clampX(value: number): number {
    const maxX: number = Math.max(0, this.pageWidth - FAB_SIZE);
    return Math.min(Math.max(value, 0), maxX);
  }

  private clampY(value: number): number {
    const maxY: number = Math.max(0, this.pageHeight - FAB_SIZE);
    return Math.min(Math.max(value, 0), maxY);
  }

  private updateViewport(area: Area): void {
    const width: number = Number(area.width);
    const height: number = Number(area.height);
    if (width <= 0 || height <= 0 || (width === this.pageWidth && height === this.pageHeight)) { return; }
    this.pageWidth = width;
    this.pageHeight = height;
    if (this.manuallyPositioned) {
      this.buttonX = this.clampX(this.buttonX);
      this.buttonY = this.clampY(this.buttonY);
    } else { this.positionForHand(this.lastHand, false); }
  }

  private buttonSurfaceColor(): ResourceColor {
    if (SystemMaterialUtil.isApi26OrAbove()) {
      return Color.Transparent;
    }
    return this.actionColor();
  }

  private actionForegroundColor(): ResourceColor {
    return this.composeColor === undefined ?
      mixedAccentRoleColor(this.accentTheme, 'on_action', $r('app.color.text_on_accent')) : $r('app.color.text_on_accent');
  }

  private actionColor(): ResourceColor { return this.composeColor ?? mixedAccentRoleColor(this.accentTheme, 'action', this.accentColor); }

  private surfaceBorderWidth(): number {
    if (SystemMaterialUtil.isApi26OrAbove()) {
      return 0;
    }
    return 1;
  }

  private materialTint(): string | undefined {
    if (!this.materialTintEnabled) { return undefined; }
    try {
      const color: ColorMetrics = ColorMetrics.resourceColor(this.actionColor());
      return ColorMetrics.rgba(color.red, color.green, color.blue, 0.8).color;
    } catch (error) { }
    // Keep the glyph opaque; only the material tint has 20% transparency.
    if (this.accentColor.length === 7 && this.accentColor.substring(0, 1) === '#') {
      return '#CC' + this.accentColor.substring(1);
    }
    return '#CC007DFF';
  }

  private handlePanStart(): void {
    this.isDragging = true;
    this.manuallyPositioned = true;
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
        .backgroundColor(this.buttonSurfaceColor())
        .border({ width: this.surfaceBorderWidth(), color: $r('app.color.compose_material_border') })
        .borderRadius(FAB_SIZE / 2);
      SymbolGlyph(this.composeSymbol)
        .fontSize(24)
        .foregroundFilter(ComponentHdrHighlight.filter(this.getUIContext(), this.componentHdrEnabled, this.componentHdrRatio))
        .fontColor([this.actionForegroundColor()]);
    }
    .width(FAB_SIZE)
    .height(FAB_SIZE);
  }

  @Builder
  private TopContent(): void {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width(FAB_SIZE)
        .height(FAB_SIZE)
        .backgroundColor(this.buttonSurfaceColor())
        .border({ width: this.surfaceBorderWidth(), color: $r('app.color.compose_material_border') })
        .borderRadius(FAB_SIZE / 2);
      SymbolGlyph($r('sys.symbol.chevron_up'))
        .fontSize(26)
        .foregroundFilter(ComponentHdrHighlight.filter(this.getUIContext(), this.componentHdrEnabled, this.componentHdrRatio))
        .fontColor([this.actionForegroundColor()]);
    }
    .width(FAB_SIZE)
    .height(FAB_SIZE);
  }

  @Builder
  private RefreshContent(): void {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width(FAB_SIZE)
        .height(FAB_SIZE)
        .backgroundColor(this.buttonSurfaceColor())
        .border({ width: this.surfaceBorderWidth(), color: $r('app.color.compose_material_border') })
        .borderRadius(FAB_SIZE / 2);
      if (this.displayedRefreshing) {
        LoadingProgress()
          .width(24)
          .height(24)
          .foregroundFilter(ComponentHdrHighlight.filter(this.getUIContext(), this.componentHdrEnabled, this.componentHdrRatio))
          .color(this.actionForegroundColor())
      } else {
        SymbolGlyph($r('sys.symbol.arrow_clockwise'))
          .fontSize(26)
          .foregroundFilter(ComponentHdrHighlight.filter(this.getUIContext(), this.componentHdrEnabled, this.componentHdrRatio))
          .fontColor([this.actionForegroundColor()]);
      }
    }
    .width(FAB_SIZE)
    .height(FAB_SIZE);
  }

  @Builder
  private ReadContent(): void {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width(FAB_SIZE)
        .height(FAB_SIZE)
        .backgroundColor(this.buttonSurfaceColor())
        .border({ width: this.surfaceBorderWidth(), color: $r('app.color.compose_material_border') })
        .borderRadius(FAB_SIZE / 2);
      SymbolGlyph($r('sys.symbol.text_speaker_wave_rectangle'))
        .fontSize(26)
        .foregroundFilter(ComponentHdrHighlight.filter(this.getUIContext(), this.componentHdrEnabled, this.componentHdrRatio))
        .fontColor([this.actionForegroundColor()]);
    }
    .width(FAB_SIZE)
    .height(FAB_SIZE);
  }

  @Builder
  private FloatingActionButton(): void {
    HdsButton({
        barWidth: FAB_SIZE,
        barHeight: FAB_SIZE + 12,
        lightColor: this.actionColor(),
        useImmersiveMaterial: true,
        immersiveTint: this.materialTint(),
        materialLevel: 2,
        panLightActive: this.isDragging,
        forceHdsStyle: true,
        enableShadow: true,
        enablePressLight: true,
        // The glyphs already own their HDR filter; keep the material host neutral.
        enableHdrHighlight: false,
        onButtonClick: (): void => {
          if (this.hidden) { return; }
          if (this.displayedMode === 'top') {
            this.onTop();
            return;
          }
          if (this.displayedMode === 'refresh') {
            this.onRefresh();
            return;
          }
          if (this.displayedMode === 'read') {
            this.onRead();
            return;
          }
          if (this.displayedMode === 'reply') {
            this.onReply();
            return;
          }
          this.onCompose();
        },
        onButtonPanStart: (): void => {
          if (this.hidden) { return; }
          this.handlePanStart();
        },
        onButtonPanUpdate: (event: GestureEvent): void => {
          if (this.hidden) { return; }
          this.handlePanUpdate(event);
        },
        onButtonPanEnd: (): void => {
          if (this.hidden) { return; }
          this.handlePanEnd();
        }
      }) {
        if (this.displayedMode === 'top') {
          this.TopContent();
        } else if (this.displayedMode === 'refresh') {
          this.RefreshContent();
        } else if (this.displayedMode === 'read') {
          this.ReadContent();
        } else {
          this.BlueComposeContent();
        }
      }
  }

  build(): void {
    Stack({ alignContent: Alignment.TopStart }) {
    if (!this.hidden) {
    if (SystemMaterialUtil.isApi26OrAbove()) {
      Navigation() {
        Column()
          .width('100%')
          .height('100%')
          .hitTestBehavior(HitTestMode.None)
      }
      .title({
        builder: (): void => {
          this.FloatingActionButton();
        },
        height: FAB_SIZE
      }, { barStyle: BarStyle.STACK })
      .titleMode(NavigationTitleMode.Full)
      .mode(NavigationMode.Stack)
      .hideToolBar(true)
      .backgroundColor(Color.Transparent)
      .borderRadius(FAB_SIZE / 2)
      .clip(true)
      .width(FAB_SIZE)
      .height(FAB_SIZE)
      .position({ x: this.buttonX, y: this.buttonY })
      .scale({
        x: this.isDragging ? motionScale(1.08) : 1,
        y: this.isDragging ? motionScale(1.08) : 1
      })
      .accessibilityText(this.accessibilityLabel)
      .animation({ duration: this.isDragging ? 0 : motionDuration(240), curve: Curve.EaseOut });
    } else {
      Stack() {
        this.FloatingActionButton();
      }
      .width(FAB_SIZE)
      .height(FAB_SIZE)
      .position({ x: this.buttonX, y: this.buttonY })
      .scale({
        x: this.isDragging ? motionScale(1.08) : 1,
        y: this.isDragging ? motionScale(1.08) : 1
      })
      .accessibilityText(this.accessibilityLabel)
      .animation({ duration: this.isDragging ? 0 : motionDuration(240), curve: Curve.EaseOut });
    }
    }
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.Transparent)
    .onAreaChange((_old: Area, area: Area): void => this.updateViewport(area))
  }
}
