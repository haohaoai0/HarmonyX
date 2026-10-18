import { mixedAccentRoleColor, accentPageRole } from '../utils/AccentPalette';
import { TouchHdrLight } from './TouchHdrLight';
import { common } from '@kit.AbilityKit';
import { curves } from '@kit.ArkUI';
import { HdsTabs, hdsEffect, hdsMaterial } from '@kit.UIDesignKit';
import { LiquidTabTarget, RootLiquidTabGeometry } from '../utils/RootLiquidTabGeometry';
import { RootBottomTabItem } from './RootBottomTabItem';
import { DEFAULT_COMPONENT_HDR_RATIO, STORAGE_KEY_COMPONENT_HDR_RATIO } from '../services/ComponentHdrSettingsStore';
import { ComponentHdrHighlight } from '../utils/ComponentHdrHighlight';

// Mark's floating liquid capsule, anchored to the actual native tab items.
// Native HDS retains control of bar width, handedness, and scroll visibility.
@Component
export struct RootLiquidTabIndicator {
  @Prop @Watch('onSelectionChanged') selectedPage: number = 0;
  @Prop @Watch('onRequestedPageChanged') requestedPage: number = 0;
  @Prop @Watch('onPresentationChanged') pagesMask: number = 31;
  @Prop @Watch('onPresentationChanged') showLabel: boolean = true;
  @Prop @Watch('onVisibilityChanged') hidden: boolean = false;
  @Prop materialLevel: number = 10;
  @Prop unreadNotifications: number = 0;
  @Prop unreadMessages: number = 0;
  @StorageProp('harmonyx.accent_theme') private accentTheme: string = '';
  @StorageProp('harmonyx.accent_color') private accentColor: string = '#1D9BF0';
  @StorageProp(STORAGE_KEY_COMPONENT_HDR_RATIO) private componentHdrRatio: number = DEFAULT_COMPONENT_HDR_RATIO;
  onSelect: (visibleIndex: number) => void = (_index: number): void => {};
  onSelectedClick: (visibleIndex: number) => void = (_index: number): void => {};

  @State private centerX: number = 0;
  @State private centerY: number = 0;
  @State private restWidth: number = 1;
  @State private restHeight: number = 1;
  @State private scaleX: number = 1;
  @State private scaleY: number = 1;
  @State private contentBlur: number = 0;
  @State private displayPage: number = 0;
  @State private ready: boolean = false;
  @State private dragging: boolean = false;
  @State private touchHeld: boolean = false;
  @State private hitTargets: LiquidTabTarget[] = [];
  private targets: LiquidTabTarget[] = [];
  private labeledWidth: number = 1;
  private labeledHeight: number = 1;
  private compactWidth: number = 1;
  private compactHeight: number = 1;
  private slotOverhang: number = 0;
  private dragOriginX: number = 0;
  private lastDragOffset: number = 0;
  private smoothedDelta: number = 0;
  private dragDirection: number = 0;
  private settling: boolean = false;
  private settleTimer: number = -1;
  private readonly layoutCallback: () => void = (): void => this.syncGeometry();

  aboutToAppear(): void {
    this.labeledWidth = this.dimension($r('app.float.root_liquid_tab_label_width'));
    this.labeledHeight = this.dimension($r('app.float.root_liquid_tab_label_height'));
    this.compactWidth = this.dimension($r('app.float.root_liquid_tab_compact_width'));
    this.compactHeight = this.dimension($r('app.float.root_liquid_tab_compact_height'));
    this.slotOverhang = this.dimension($r('app.float.root_liquid_tab_slot_overhang'));
    this.displayPage = this.selectedPage;
    this.getUIContext().getUIObserver().on('willDraw', this.layoutCallback);
  }

  aboutToDisappear(): void {
    this.touchHeld = false;
    this.dragging = false;
    this.clearSettleTimer();
    this.getUIContext().getUIObserver().off('willDraw', this.layoutCallback);
  }

  private dimension(resource: Resource): number {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    return this.getUIContext().px2vp(context.resourceManager.getNumber(resource.id));
  }

  private clearSettleTimer(): void {
    if (this.settleTimer >= 0) { clearTimeout(this.settleTimer); }
    this.settleTimer = -1;
  }

  private measureTargets(): boolean {
    try {
      const ui = this.getUIContext();
      const host = ui.getFrameNodeById('root-liquid-tabs-overlay');
      if (host === null || host.getMeasuredSize().width <= 0) { return false; }
      const origin = host.getPositionToWindowWithTransform();
      const next: LiquidTabTarget[] = [];
      for (let page: number = 0; page < 5; page++) {
        if ((this.pagesMask & (1 << page)) === 0) { continue; }
        const node = ui.getFrameNodeById('root-floating-tab-' + page.toString());
        if (node === null) { return false; }
        const size = node.getMeasuredSize();
        if (size.width <= 0 || size.height <= 0) { return false; }
        // Unlike componentUtils.windowOffset, this includes the native HDS
        // bar's render translation (safe areas and handedness). Units are vp.
        const position = node.getPositionToWindowWithTransform();
        const target: LiquidTabTarget = new LiquidTabTarget();
        target.page = page;
        target.visibleIndex = next.length;
        target.x = position.x - origin.x + ui.px2vp(size.width / 2);
        target.y = position.y - origin.y + ui.px2vp(size.height / 2);
        target.width = ui.px2vp(size.width);
        target.height = ui.px2vp(size.height);
        if (!Number.isFinite(target.x) || !Number.isFinite(target.y)) { return false; }
        next.push(target);
      }
      let hitAreasChanged: boolean = next.length !== this.hitTargets.length;
      for (let index: number = 0; !hitAreasChanged && index < next.length; index++) {
        const previous: LiquidTabTarget = this.hitTargets[index];
        const target: LiquidTabTarget = next[index];
        hitAreasChanged = previous.page !== target.page || Math.abs(previous.x - target.x) > 0.1 ||
          Math.abs(previous.y - target.y) > 0.1 || Math.abs(previous.width - target.width) > 0.1 ||
          Math.abs(previous.height - target.height) > 0.1;
      }
      if (hitAreasChanged) { this.hitTargets = next; }
      this.targets = next;
      return next.length > 0;
    } catch (_error) { return false; }
  }

  private selectedTarget(): LiquidTabTarget | undefined {
    return this.targets.find((target: LiquidTabTarget): boolean => target.page === this.selectedPage);
  }

  private updateSize(target: LiquidTabTarget): void {
    const width: number = RootLiquidTabGeometry.width(target.width, this.showLabel,
      this.labeledWidth, this.compactWidth, this.slotOverhang);
    const height: number = this.showLabel ? this.labeledHeight : this.compactHeight;
    // Preference/viewport changes update layout once. Motion only transforms
    // this fixed surface, without relaying out the material on every frame.
    if (Math.abs(width - this.restWidth) > 0.1) { this.restWidth = width; }
    if (Math.abs(height - this.restHeight) > 0.1) { this.restHeight = height; }
  }

  private syncGeometry(): void {
    if (this.hidden || this.dragging || this.settling || !this.measureTargets()) { return; }
    const target: LiquidTabTarget | undefined = this.selectedTarget();
    if (target === undefined) { return; }
    this.updateSize(target);
    if (Math.abs(this.centerX - target.x) > 0.1) { this.centerX = target.x; }
    if (Math.abs(this.centerY - target.y) > 0.1) { this.centerY = target.y; }
    if (this.displayPage !== this.selectedPage) { this.displayPage = this.selectedPage; }
    if (!this.ready) { this.ready = true; }
  }

  private onPresentationChanged(): void {
    this.cancelDrag();
    this.syncGeometry();
  }

  private onVisibilityChanged(): void {
    this.cancelDrag();
    if (!this.hidden) { this.syncGeometry(); }
  }

  private onSelectionChanged(): void {
    // A native tab click starts the capsule immediately. Its later onChange
    // commits the page without restarting the same spring a second time.
    if (this.ready && this.displayPage === this.selectedPage && !this.dragging) { return; }
    this.dragging = false;
    if (!this.measureTargets()) { return; }
    const target: LiquidTabTarget | undefined = this.selectedTarget();
    if (target !== undefined) { this.snapTo(target, true); }
  }

  private onRequestedPageChanged(): void {
    if (!this.measureTargets()) { return; }
    const target: LiquidTabTarget | undefined = this.targets.find((item: LiquidTabTarget): boolean =>
      item.page === this.requestedPage);
    if (target !== undefined && target.page !== this.displayPage) {
      this.dragging = false;
      this.snapTo(target, true);
    }
  }

  private clickTarget(target: LiquidTabTarget): void {
    if (this.hidden) { return; }
    this.dragging = false;
    if (target.page !== this.selectedPage) {
      this.snapTo(target, true);
      this.onSelectedClick(target.visibleIndex);
      this.onSelect(target.visibleIndex);
    } else {
      this.onSelectedClick(target.visibleIndex);
    }
  }

  private snapTo(target: LiquidTabTarget, stretch: boolean): void {
    this.clearSettleTimer();
    this.updateSize(target);
    this.displayPage = target.page;
    this.contentBlur = 0;
    if (!this.ready || this.hidden) {
      this.centerX = target.x;
      this.centerY = target.y;
      this.scaleX = 1;
      this.scaleY = 1;
      this.ready = true;
      this.settling = false;
      return;
    }
    this.settling = true;
    this.getUIContext().animateTo({ duration: 420, curve: curves.springMotion(0.38, 0.58) }, (): void => {
      this.centerX = target.x;
      this.centerY = target.y;
      if (!stretch) {
        this.scaleX = 1;
        this.scaleY = 1;
      }
    });
    if (stretch) {
      this.getUIContext().animateTo({ duration: 90, curve: Curve.EaseOut }, (): void => {
        this.scaleX = 1.3;
        this.scaleY = 0.86;
      });
    }
    this.settleTimer = setTimeout((): void => {
      this.getUIContext().animateTo({ duration: 420, curve: curves.springMotion(0.36, 0.4) }, (): void => {
        this.scaleX = 1;
        this.scaleY = 1;
      });
      this.settleTimer = setTimeout((): void => {
        this.settling = false;
        this.settleTimer = -1;
        this.syncGeometry();
      }, 420);
    }, stretch ? 90 : 0);
  }

  private startDrag(): void {
    this.clearSettleTimer();
    this.settling = false;
    if (!this.measureTargets()) { return; }
    this.dragging = true;
    this.dragOriginX = this.centerX;
    this.lastDragOffset = 0;
    this.smoothedDelta = 0;
    this.dragDirection = 0;
    this.getUIContext().animateTo({ duration: 100, curve: Curve.EaseOut }, (): void => {
      this.scaleX = 1.18;
      this.scaleY = 1.24;
    });
  }

  private updateDrag(event: GestureEvent): void {
    if (!this.dragging) { return; }
    this.smoothedDelta = this.smoothedDelta * 0.7 + (event.offsetX - this.lastDragOffset) * 0.3;
    this.lastDragOffset = event.offsetX;
    this.centerX = RootLiquidTabGeometry.rubberBand(this.targets, this.dragOriginX + event.offsetX);
    const nearest: number = RootLiquidTabGeometry.nearest(this.targets, this.centerX);
    if (nearest < 0) { return; }
    const target: LiquidTabTarget = this.targets[nearest];
    this.displayPage = target.page;
    this.contentBlur = Math.abs(this.centerX - target.x) > target.width * 0.28 ? 4 : 0;
    const deformation: number = Math.sqrt(Math.min(Math.abs(this.smoothedDelta) / 25, 1));
    const direction: number = this.smoothedDelta >= 0 ? 1 : -1;
    if (this.dragDirection === 0 || Math.abs(this.smoothedDelta) < 0.15) { this.dragDirection = direction; }
    if (this.dragDirection === direction) {
      this.scaleX = 1.2 + deformation * 0.5;
      this.scaleY = 1.14 - deformation * 0.32;
    } else {
      this.scaleX = 1.12 - deformation * 0.2;
      this.scaleY = 1.2 + deformation * 0.4;
    }
  }

  private endDrag(): void {
    if (!this.dragging) { return; }
    this.dragging = false;
    const nearest: number = RootLiquidTabGeometry.nearest(this.targets, this.centerX);
    if (nearest < 0) { this.cancelDrag(); return; }
    const target: LiquidTabTarget = this.targets[nearest];
    this.snapTo(target, false);
    if (target.page !== this.selectedPage) { this.onSelect(target.visibleIndex); }
  }

  private cancelDrag(): void {
    this.touchHeld = false;
    this.clearSettleTimer();
    this.dragging = false;
    this.settling = false;
    this.scaleX = 1;
    this.scaleY = 1;
    this.contentBlur = 0;
    this.displayPage = this.selectedPage;
  }

  private handleTouch(event: TouchEvent): void {
    if (event.type === TouchType.Down) { this.touchHeld = true; }
    else if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.touchHeld = false; }
    if (this.dragging || this.settling) { return; }
    if (event.type === TouchType.Down) {
      this.getUIContext().animateTo({ duration: 90, curve: Curve.EaseOut }, (): void => {
        this.scaleX = 1.12;
        this.scaleY = 1.2;
      });
    } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.getUIContext().animateTo({ duration: 420, curve: curves.springMotion(0.36, 0.4) }, (): void => {
        this.scaleX = 1;
        this.scaleY = 1;
      });
    }
  }

  private icon(): Resource {
    if (this.displayPage === 1) { return $r('sys.symbol.magnifyingglass'); }
    if (this.displayPage === 2) { return $r('sys.symbol.bell_fill'); }
    if (this.displayPage === 3) { return $r('sys.symbol.message_fill'); }
    if (this.displayPage === 4) { return $r('sys.symbol.person_fill'); }
    return $r('sys.symbol.house_fill');
  }

  private label(): Resource {
    if (this.displayPage === 1) { return $r('app.string.explore_title'); }
    if (this.displayPage === 2) { return $r('app.string.tab_alerts'); }
    if (this.displayPage === 3) { return $r('app.string.chat_title'); }
    if (this.displayPage === 4) { return $r('app.string.tab_me'); }
    return $r('app.string.home_title');
  }

  build(): void {
    Stack({ alignContent: Alignment.TopStart }) {
      // Use the same measured native slots for tapping and dragging. The
      // decorative overlay must not swallow clicks on unselected tabs.
      ForEach(this.hitTargets, (target: LiquidTabTarget): void => {
        Column()
          .width(target.width).height(target.height)
          .position({ x: target.x - target.width / 2, y: target.y - target.height / 2 })
          .hitTestBehavior(HitTestMode.Block)
          .accessibilityLevel('no')
          .id('root-liquid-tab-hit-' + target.page.toString())
          .onClick((): void => this.clickTarget(target))
      }, (target: LiquidTabTarget): string => target.page.toString())
      Stack({ alignContent: Alignment.Center }) {
        HdsTabs({ index: 0 }) {}
          .width(this.restWidth).height(this.restHeight)
          .barWidth(this.restWidth).barHeight(this.restHeight)
          .barPosition(BarPosition.End).barOverlap(true).vertical(false)
          .barFloatingStyle({
            barWidth: { smallWidth: this.restWidth, mediumWidth: this.restWidth, largeWidth: this.restWidth },
            barBottomMargin: 0, barSideMargin: 0,
            gradientMask: { maskColor: Color.Transparent },
            lightColor: mixedAccentRoleColor(this.accentTheme, accentPageRole(this.displayPage), this.accentColor),
            systemMaterialEffect: { materialType: hdsMaterial.MaterialType.IMMERSIVE,
              materialLevel: this.materialLevel },
            thermoCtrl: true
          })
          .clip(false)
          .scale({ x: this.scaleX, y: this.scaleY })
          // Boost the material capsule itself. The foreground is a sibling
          // with its own filter, so neither layer receives the ratio twice.
          .compositingFilter(ComponentHdrHighlight.filter(this.getUIContext(), true, this.componentHdrRatio))
          .visualEffect(new hdsEffect.HdsEffectBuilder().pointLight({
            sourceType: this.dragging ? hdsEffect.PointLightSourceType.BRIGHT : hdsEffect.PointLightSourceType.NONE,
            illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER
          }).buildEffect())
          .hitTestBehavior(HitTestMode.None)
        TouchHdrLight({ active: !this.hidden && (this.touchHeld || this.dragging), cornerRadius: this.restHeight / 2 })
          .width(this.restWidth).height(this.restHeight)
          .scale({ x: this.scaleX, y: this.scaleY })
        RootBottomTabItem({ page: this.displayPage, icon: this.icon(), activeIcon: this.icon(), label: this.label(), selected: true,
          showLabel: this.showLabel, unread: this.displayPage === 2 ? this.unreadNotifications :
            (this.displayPage === 3 ? this.unreadMessages : 0) })
          .width(this.restWidth).height(this.restHeight)
          .renderGroup(true)
          .blur(this.contentBlur)
          .hitTestBehavior(HitTestMode.None)
      }
      .width(this.restWidth).height(this.restHeight)
      .position({ x: 0, y: 0 })
      .translate({ x: this.centerX - this.restWidth / 2, y: this.centerY - this.restHeight / 2 })
      .opacity(this.ready && !this.hidden ? 1 : 0)
      .visibility(this.hidden || !this.ready ? Visibility.Hidden : Visibility.Visible)
      .clip(false)
      .id('root-liquid-tab-indicator')
      // The underlying native item supplies the label, focus and selection.
      .accessibilityLevel('no-hide-descendants')
      .onTouch((event: TouchEvent): void => this.handleTouch(event))
      .gesture(PanGesture({ direction: PanDirection.Horizontal })
        .onActionStart((): void => this.startDrag())
        .onActionUpdate((event: GestureEvent): void => this.updateDrag(event))
        .onActionEnd((): void => this.endDrag())
        .onActionCancel((): void => { this.cancelDrag(); this.syncGeometry(); }))
      .onClick((): void => {
        const target: LiquidTabTarget | undefined = this.targets.find((item: LiquidTabTarget): boolean =>
          item.page === this.displayPage);
        if (target !== undefined) { this.clickTarget(target); }
      })
    }
    .width('100%').height('100%')
    .id('root-liquid-tabs-overlay')
    .hitTestBehavior(HitTestMode.Transparent)
    .visibility(this.hidden ? Visibility.Hidden : Visibility.Visible)
    .onAreaChange((): void => this.syncGeometry())
  }
}
