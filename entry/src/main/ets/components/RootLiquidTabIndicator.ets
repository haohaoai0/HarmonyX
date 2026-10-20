import { common } from '@kit.AbilityKit';
import { curves } from '@kit.ArkUI';
import { LiquidTabTarget, RootLiquidTabGeometry } from '../utils/RootLiquidTabGeometry';
import { RootLiquidTabMotion, RootLiquidTabHitTarget } from '../utils/RootLiquidTabMotion';

@Component
struct RootLiquidTabHitArea {
  @ObjectLink target: RootLiquidTabHitTarget;
  onSelect: (page: number) => void = (_page: number): void => {};

  build(): void {
    Column()
      .width(this.target.width).height(this.target.height)
      .position({ x: 0, y: 0 })
      .translate({ x: this.target.x - this.target.width / 2, y: this.target.y - this.target.height / 2 })
      .hitTestBehavior(HitTestMode.Block)
      .accessibilityLevel('no')
      .id('root-liquid-tab-hit-' + this.target.page.toString())
      .onClick((): void => this.onSelect(this.target.page))
  }
}

// Window-level interaction for the liquid capsule. Its decorative surface is
// mounted inside the native bar, sharing this motion without intercepting taps.
@Component
export struct RootLiquidTabIndicator {
  @ObjectLink motion: RootLiquidTabMotion;
  @Prop @Watch('onSelectionChanged') selectedPage: number = 0;
  @Prop @Watch('onRequestedPageChanged') requestedPage: number = 0;
  @Prop @Watch('onPresentationChanged') pagesMask: number = 31;
  @Prop @Watch('onPresentationChanged') showLabel: boolean = true;
  @Prop @Watch('onVisibilityChanged') hidden: boolean = false;
  onSelect: (visibleIndex: number) => void = (_index: number): void => {};
  onSelectedClick: (visibleIndex: number) => void = (_index: number): void => {};

  @State private nativeOriginX: number = 0;
  @State private nativeOriginY: number = 0;
  @State private hitTargets: RootLiquidTabHitTarget[] = [];
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
  private pendingPage: number = -1;
  private settleTimer: number = -1;
  private readonly layoutCallback: () => void = (): void => this.syncGeometry();

  aboutToAppear(): void {
    this.motion.ready = false;
    this.labeledWidth = this.dimension($r('app.float.root_liquid_tab_label_width'));
    this.labeledHeight = this.dimension($r('app.float.root_liquid_tab_label_height'));
    this.compactWidth = this.dimension($r('app.float.root_liquid_tab_compact_width'));
    this.compactHeight = this.dimension($r('app.float.root_liquid_tab_compact_height'));
    this.slotOverhang = this.dimension($r('app.float.root_liquid_tab_slot_overhang'));
    this.motion.displayPage = this.selectedPage;
    this.getUIContext().getUIObserver().on('willDraw', this.layoutCallback);
  }

  aboutToDisappear(): void {
    this.motion.touchHeld = false;
    this.motion.dragging = false;
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
      const hits: RootLiquidTabHitTarget[] = [];
      let anchorX: number = 0;
      let anchorY: number = 0;
      for (let page: number = 0; page < 5; page++) {
        if ((this.pagesMask & (1 << page)) === 0) { continue; }
        const node = ui.getFrameNodeById('root-floating-tab-' + page.toString());
        if (node === null) { return false; }
        const size = node.getMeasuredSize();
        if (size.width <= 0 || size.height <= 0) { return false; }
        // Visual motion uses layout coordinates relative to the first slot.
        // HDS applies its render transforms once to the entire native subtree.
        const layout = node.getPositionToWindow();
        const position = node.getPositionToWindowWithTransform();
        if (next.length === 0) {
          anchorX = layout.x;
          anchorY = layout.y;
          const originX: number = position.x - origin.x;
          const originY: number = position.y - origin.y;
          if (Math.abs(this.nativeOriginX - originX) > 0.1) { this.nativeOriginX = originX; }
          if (Math.abs(this.nativeOriginY - originY) > 0.1) { this.nativeOriginY = originY; }
        }
        const target: LiquidTabTarget = new LiquidTabTarget();
        target.page = page;
        target.visibleIndex = next.length;
        target.x = layout.x - anchorX + ui.px2vp(size.width / 2);
        target.y = layout.y - anchorY + ui.px2vp(size.height / 2);
        target.width = ui.px2vp(size.width);
        target.height = ui.px2vp(size.height);
        if (!Number.isFinite(target.x) || !Number.isFinite(target.y)) { return false; }
        next.push(target);
        // Retain each observed target so a keyed ForEach does not keep the
        // initial geometry captured before native HDS finishes its layout.
        let hit: RootLiquidTabHitTarget | undefined = this.hitTargets.find((item: RootLiquidTabHitTarget): boolean =>
          item.page === page);
        if (hit === undefined) { hit = new RootLiquidTabHitTarget(); }
        hit.page = target.page;
        hit.visibleIndex = target.visibleIndex;
        hit.x = position.x - origin.x + target.width / 2;
        hit.y = position.y - origin.y + target.height / 2;
        hit.width = target.width;
        hit.height = target.height;
        hits.push(hit);
      }
      let hitAreasChanged: boolean = next.length !== this.hitTargets.length;
      for (let index: number = 0; !hitAreasChanged && index < next.length; index++) {
        hitAreasChanged = this.hitTargets[index].page !== hits[index].page;
      }
      if (hitAreasChanged) { this.hitTargets = hits; }
      this.targets = next;
      return next.length > 0;
    } catch (_error) { return false; }
  }

  private selectedTarget(): LiquidTabTarget | undefined {
    const page: number = this.pendingPage >= 0 ? this.pendingPage : this.selectedPage;
    return this.targets.find((target: LiquidTabTarget): boolean => target.page === page);
  }

  private updateSize(target: LiquidTabTarget): void {
    const width: number = RootLiquidTabGeometry.width(target.width, this.showLabel,
      this.labeledWidth, this.compactWidth, this.slotOverhang);
    const height: number = this.showLabel ? this.labeledHeight : this.compactHeight;
    // Preference/viewport changes update layout once. Motion only transforms
    // this fixed surface, without relaying out the material on every frame.
    if (Math.abs(width - this.motion.restWidth) > 0.1) { this.motion.restWidth = width; }
    if (Math.abs(height - this.motion.restHeight) > 0.1) { this.motion.restHeight = height; }
  }

  private syncGeometry(): void {
    if (!this.measureTargets()) { return; }
    const target: LiquidTabTarget | undefined = this.selectedTarget();
    if (target === undefined) { return; }
    // Native HDS owns visibility; keep local geometry ready across reversals.
    if (Math.abs(this.motion.centerY - target.y) > 0.1) { this.motion.centerY = target.y; }
    if (this.motion.dragging || this.settling) { return; }
    this.updateSize(target);
    if (Math.abs(this.motion.centerX - target.x) > 0.1) { this.motion.centerX = target.x; }
    if (this.motion.displayPage !== target.page) { this.motion.displayPage = target.page; }
    if (!this.motion.ready) { this.motion.ready = true; }
  }

  private onPresentationChanged(): void {
    this.cancelDrag();
    this.syncGeometry();
  }

  private onVisibilityChanged(): void {
    if (this.motion.dragging) { this.cancelDrag(); }
    this.syncGeometry();
  }

  private onSelectionChanged(): void {
    // HDS can publish an older committed page while a newer click is pending.
    // Keep the requested target until its own commit arrives.
    if (this.pendingPage >= 0 && this.selectedPage !== this.pendingPage) { return; }
    this.pendingPage = -1;
    // A native tab click starts the capsule immediately. Its later onChange
    // commits the page without restarting the same spring a second time.
    if (this.motion.ready && this.motion.displayPage === this.selectedPage && !this.motion.dragging) { return; }
    this.motion.dragging = false;
    if (!this.measureTargets()) { return; }
    const target: LiquidTabTarget | undefined = this.selectedTarget();
    if (target !== undefined) { this.snapTo(target, true); }
  }

  private onRequestedPageChanged(): void {
    if (!this.measureTargets()) { return; }
    const target: LiquidTabTarget | undefined = this.targets.find((item: LiquidTabTarget): boolean =>
      item.page === this.requestedPage);
    if (target !== undefined && target.page !== this.motion.displayPage) {
      this.motion.dragging = false;
      this.snapTo(target, true);
    }
  }

  private clickTarget(target: LiquidTabTarget): void {
    if (this.hidden) { return; }
    this.motion.dragging = false;
    if (target.page !== this.selectedPage) {
      this.snapTo(target, true);
      this.onSelectedClick(target.visibleIndex);
      this.onSelect(target.visibleIndex);
    } else {
      this.onSelectedClick(target.visibleIndex);
    }
  }

  private clickPage(page: number): void {
    // Hit geometry is in window coordinates; liquid motion is local to the
    // native bar. Always resolve the page to its local target before snapping.
    const target: LiquidTabTarget | undefined = this.targets.find((item: LiquidTabTarget): boolean => item.page === page);
    if (target !== undefined) { this.clickTarget(target); }
  }

  private snapTo(target: LiquidTabTarget, stretch: boolean): void {
    this.clearSettleTimer();
    this.updateSize(target);
    this.motion.displayPage = target.page;
    this.pendingPage = target.page === this.selectedPage ? -1 : target.page;
    this.motion.contentBlur = 0;
    this.motion.centerY = target.y;
    if (!this.motion.ready || this.hidden) {
      this.motion.centerX = target.x;
      this.motion.scaleX = 1;
      this.motion.scaleY = 1;
      this.motion.ready = true;
      this.settling = false;
      return;
    }
    this.settling = true;
    this.getUIContext().animateTo({ duration: 280, curve: Curve.EaseOut }, (): void => {
      this.motion.centerX = target.x;
      if (!stretch) {
        this.motion.scaleX = 1;
        this.motion.scaleY = 1;
      }
    });
    if (stretch) {
      this.getUIContext().animateTo({ duration: 90, curve: Curve.EaseOut }, (): void => {
        this.motion.scaleX = 1.3;
        this.motion.scaleY = 0.86;
      });
    }
    this.settleTimer = setTimeout((): void => {
      this.getUIContext().animateTo({ duration: 420, curve: curves.springMotion(0.36, 0.4) }, (): void => {
        this.motion.scaleX = 1;
        this.motion.scaleY = 1;
      });
      this.settleTimer = setTimeout((): void => {
        this.settling = false;
        this.settleTimer = -1;
        this.syncGeometry();
      }, 420);
    }, stretch ? 90 : 0);
  }

  private startDrag(): void {
    if (this.hidden || !this.motion.ready) { return; }
    this.clearSettleTimer();
    this.settling = false;
    if (!this.measureTargets()) { return; }
    this.motion.dragging = true;
    this.dragOriginX = this.motion.centerX;
    this.lastDragOffset = 0;
    this.smoothedDelta = 0;
    this.dragDirection = 0;
    this.getUIContext().animateTo({ duration: 100, curve: Curve.EaseOut }, (): void => {
      this.motion.scaleX = 1.18;
      this.motion.scaleY = 1.24;
    });
  }

  private updateDrag(event: GestureEvent): void {
    if (!this.motion.dragging) { return; }
    this.smoothedDelta = this.smoothedDelta * 0.7 + (event.offsetX - this.lastDragOffset) * 0.3;
    this.lastDragOffset = event.offsetX;
    this.motion.centerX = RootLiquidTabGeometry.rubberBand(this.targets, this.dragOriginX + event.offsetX);
    const nearest: number = RootLiquidTabGeometry.nearest(this.targets, this.motion.centerX);
    if (nearest < 0) { return; }
    const target: LiquidTabTarget = this.targets[nearest];
    this.motion.displayPage = target.page;
    this.motion.contentBlur = Math.abs(this.motion.centerX - target.x) > target.width * 0.28 ? 4 : 0;
    const deformation: number = Math.sqrt(Math.min(Math.abs(this.smoothedDelta) / 25, 1));
    const direction: number = this.smoothedDelta >= 0 ? 1 : -1;
    if (this.dragDirection === 0 || Math.abs(this.smoothedDelta) < 0.15) { this.dragDirection = direction; }
    if (this.dragDirection === direction) {
      this.motion.scaleX = 1.2 + deformation * 0.5;
      this.motion.scaleY = 1.14 - deformation * 0.32;
    } else {
      this.motion.scaleX = 1.12 - deformation * 0.2;
      this.motion.scaleY = 1.2 + deformation * 0.4;
    }
  }

  private endDrag(): void {
    if (!this.motion.dragging) { return; }
    this.motion.dragging = false;
    const nearest: number = RootLiquidTabGeometry.nearest(this.targets, this.motion.centerX);
    if (nearest < 0) { this.cancelDrag(); return; }
    const target: LiquidTabTarget = this.targets[nearest];
    this.snapTo(target, false);
    if (target.page !== this.selectedPage) { this.onSelect(target.visibleIndex); }
  }

  private cancelDrag(): void {
    this.pendingPage = -1;
    this.motion.touchHeld = false;
    this.clearSettleTimer();
    this.motion.dragging = false;
    this.settling = false;
    this.motion.scaleX = 1;
    this.motion.scaleY = 1;
    this.motion.contentBlur = 0;
    this.motion.displayPage = this.selectedPage;
  }

  private handleTouch(event: TouchEvent): void {
    if (this.hidden) { return; }
    if (event.type === TouchType.Down) { this.motion.touchHeld = true; }
    else if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.motion.touchHeld = false; }
    if (this.motion.dragging || this.settling) { return; }
    if (event.type === TouchType.Down) {
      this.getUIContext().animateTo({ duration: 90, curve: Curve.EaseOut }, (): void => {
        this.motion.scaleX = 1.12;
        this.motion.scaleY = 1.2;
      });
    } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.getUIContext().animateTo({ duration: 420, curve: curves.springMotion(0.36, 0.4) }, (): void => {
        this.motion.scaleX = 1;
        this.motion.scaleY = 1;
      });
    }
  }

  build(): void {
    Stack({ alignContent: Alignment.TopStart }) {
      // Use the same measured native slots for tapping and dragging. The
      // decorative overlay must not swallow clicks on unselected tabs.
      ForEach(this.hitTargets, (target: RootLiquidTabHitTarget): void => {
        RootLiquidTabHitArea({ target: target, onSelect: (page: number): void => this.clickPage(page) })
      }, (target: RootLiquidTabHitTarget): string => target.page.toString())
      Column()
      .width(this.motion.restWidth).height(this.motion.restHeight)
      .position({ x: 0, y: 0 })
      .translate({ x: this.nativeOriginX + this.motion.centerX - this.motion.restWidth / 2,
        y: this.nativeOriginY + this.motion.centerY - this.motion.restHeight / 2 })
      .hitTestBehavior(HitTestMode.Block)
      .accessibilityLevel('no')
      .id('root-liquid-tab-gesture')
      .onTouch((event: TouchEvent): void => this.handleTouch(event))
      .gesture(PanGesture({ direction: PanDirection.Horizontal })
        .onActionStart((): void => this.startDrag())
        .onActionUpdate((event: GestureEvent): void => this.updateDrag(event))
        .onActionEnd((): void => this.endDrag())
        .onActionCancel((): void => { this.cancelDrag(); this.syncGeometry(); }))
      .onClick((): void => {
        const target: LiquidTabTarget | undefined = this.targets.find((item: LiquidTabTarget): boolean =>
          item.page === this.motion.displayPage);
        if (target !== undefined) { this.clickTarget(target); }
      })
    }
    .width('100%').height('100%')
    .id('root-liquid-tabs-overlay')
    // The touch layer becomes inert immediately; the native visual continues
    // its own animation without visibility toggles from this hidden flag.
    .hitTestBehavior(this.hidden || !this.motion.ready ? HitTestMode.None : HitTestMode.Transparent)
    .onAreaChange((): void => this.syncGeometry())
  }
}
