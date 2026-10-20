import { HdsTabs, HdsTabsFloatingStyle, hdsMaterial } from '@kit.UIDesignKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { RootBottomTabItem } from './RootBottomTabItem';
import { RootLiquidTabSurface } from './RootLiquidTabSurface';
import { RootLiquidTabMotion } from '../utils/RootLiquidTabMotion';
import { LiquidTabTarget, RootLiquidTabGeometry } from '../utils/RootLiquidTabGeometry';
import { curves, uiMaterial } from '@kit.ArkUI';
import { ReplyCapsuleSurface } from './ReplyCapsuleSurface';
import { SystemMaterialUtil } from '../utils/SystemMaterial';
import { DEFAULT_NATIVE_TAB_MATERIAL_LEVEL, STORAGE_KEY_NATIVE_TAB_MATERIAL_LEVEL } from '../services/HdsTabsSettingsStore';
import { motionCurve, motionDuration } from '../utils/AppMotion';
import { hapticTick } from '../utils/Haptics';
import { mixedAccentRoleColor } from '../utils/AccentPalette';
import { effectiveAppLocale, isAppRtl, STORAGE_KEY_APP_LOCALE } from '../utils/AppLocale';
import { GripHandManager } from '../utils/GripHandManager';
import { common } from '@kit.AbilityKit';
import { pageTextColor } from '../utils/ThemeColors';

const GRIP_SUBSCRIBER_KEY: string = 'root-split-navigation';

// Both surfaces use the same native HDS floating material and 56vp / 28vp
// height/radius as the root HdsTabs. The content pager remains full width.
@Component
export struct RootSplitNavigation {
  @Prop pages: number[] = [0, 1, 2, 3, 4];
  @Prop @Watch('onSelectedPageChanged') selectedPage: number = 0;
  @Prop showLabel: boolean = true;
  @Prop showSelection: boolean = true;
  @Prop unreadNotifications: number = 0;
  @Prop unreadMessages: number = 0;
  @Prop materialLevel: number = 10;
  @Prop nativeMaterial: boolean = false;
  @StorageProp(STORAGE_KEY_NATIVE_TAB_MATERIAL_LEVEL)
  private nativeMaterialLevel: number = DEFAULT_NATIVE_TAB_MATERIAL_LEVEL;
  @Prop showAction: boolean = true;
  @Prop actionHidden: boolean = false;
  @Prop actionMode: string = 'compose';
  @Prop actionSymbol: Resource = $r('sys.symbol.square_and_pencil');
  @Prop actionLabel: string = '';
  @Prop refreshing: boolean = false;
  @Prop @Watch('onVisibilityChanged') hidden: boolean = false;
  @StorageProp('harmonyx.accent_color') private accentColor: string = '#007DFF';
  @StorageProp('harmonyx.accent_theme') private accentTheme: string = '';
  @StorageProp('harmonyx.page_background') private pageBackgroundValue: string = '';
  @StorageProp(STORAGE_KEY_APP_LOCALE) private appLocale: string = effectiveAppLocale();
  @StorageProp('harmonyx.grip_hand_enabled') @Watch('onGripPreferenceChanged') private gripEnabled: boolean = true;
  @StorageProp('harmonyx.grip_hdstabs_enabled') @Watch('onGripPreferenceChanged') private navigationGripEnabled: boolean = true;
  @StorageProp('harmonyx.grip_preferred_hand') @Watch('onGripPreferenceChanged') private preferredHand: string = 'right';
  @State private navigationWidth: number = 0;
  @State private actionOnLeft: boolean = false;
  @State private navigationPage: number = 0;
  @State private liquidMotion: RootLiquidTabMotion = new RootLiquidTabMotion();
  private active: boolean = false;
  private targets: LiquidTabTarget[] = [];
  private labeledWidth: number = 88;
  private labeledHeight: number = 52;
  private compactWidth: number = 64;
  private compactHeight: number = 40;
  private slotOverhang: number = 12;
  private pendingPage: number = -1;
  private settling: boolean = false;
  private settleTimer: number = -1;
  private dragOriginX: number = 0;
  private lastDragOffset: number = 0;
  private smoothedDelta: number = 0;
  private dragDirection: number = 0;
  private lastDragEndedAt: number = 0;
  private readonly layoutCallback: () => void = (): void => this.syncSelectionGeometry();
  onSelect: (page: number) => void = (): void => {};
  onTabClick: (page: number) => void = (): void => {};
  onAction: () => void = (): void => {};

  aboutToAppear(): void {
    this.active = true;
    this.navigationPage = this.selectedPage;
    this.liquidMotion.displayPage = this.selectedPage;
    this.labeledWidth = this.dimension($r('app.float.root_liquid_tab_label_width'));
    this.labeledHeight = this.dimension($r('app.float.root_liquid_tab_label_height'));
    this.compactWidth = this.dimension($r('app.float.root_liquid_tab_compact_width'));
    this.compactHeight = this.dimension($r('app.float.root_liquid_tab_compact_height'));
    this.slotOverhang = this.dimension($r('app.float.root_liquid_tab_slot_overhang'));
    this.getUIContext().getUIObserver().on('willDraw', this.layoutCallback);
    this.initializeHandedness();
  }

  aboutToDisappear(): void {
    this.active = false;
    this.cancelDrag();
    this.getUIContext().getUIObserver().off('willDraw', this.layoutCallback);
    GripHandManager.getInstance().stopFor(GRIP_SUBSCRIBER_KEY);
  }

  private onSelectedPageChanged(): void {
    if (this.pendingPage >= 0 && this.selectedPage !== this.pendingPage) { return; }
    this.pendingPage = -1;
    this.navigationPage = this.selectedPage;
  }

  private dimension(resource: Resource): number {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    return this.getUIContext().px2vp(context.resourceManager.getNumber(resource.id));
  }

  private onVisibilityChanged(): void {
    if (this.hidden) { this.cancelDrag(); }
  }

  private onGripPreferenceChanged(): void {
    if (this.active) { this.initializeHandedness(); }
  }

  private async initializeHandedness(): Promise<void> {
    const context: common.Context | undefined = this.getUIContext().getHostContext();
    const manager: GripHandManager = GripHandManager.getInstance();
    if (context !== undefined) { await manager.load(context); }
    if (!this.active) { return; }
    if (!this.gripEnabled || !this.navigationGripEnabled) {
      manager.stopFor(GRIP_SUBSCRIBER_KEY);
      this.actionOnLeft = manager.getPreferredHand() === 'left';
      return;
    }
    this.actionOnLeft = manager.getLastHand() === 'left';
    manager.startFor(GRIP_SUBSCRIBER_KEY, (hand: string): void => {
      if (this.active && this.gripEnabled && this.navigationGripEnabled) {
        this.actionOnLeft = hand === 'left';
      }
    });
  }

  private onNativeSelected(index: number): void {
    if (this.hidden || this.liquidMotion.dragging || Date.now() - this.lastDragEndedAt < 150 ||
      index < 0 || index >= this.pages.length) { return; }
    const page: number = this.pages[index];
    this.navigationPage = page;
    this.pendingPage = page === this.selectedPage ? -1 : page;
    // Prop-driven updates from a content swipe already selected the pager.
    if (page !== this.selectedPage) { this.onSelect(page); }
  }

  private onNativeTabClick(index: number): void {
    if (!this.hidden && !this.liquidMotion.dragging && Date.now() - this.lastDragEndedAt >= 150 &&
      index >= 0 && index < this.pages.length) {
      this.onTabClick(this.pages[index]);
    }
  }

  private onNativeAction(): void {
    if (this.hidden || this.actionHidden) { return; }
    hapticTick();
    this.onAction();
  }

  private navigationTranslation(): number {
    return this.showAction && this.actionOnLeft ? 64 : 0;
  }

  private actionTranslation(): number {
    return this.actionOnLeft ? -(this.navigationWidth + 8) : 0;
  }

  private pageIcon(page: number): Resource {
    if (page === 1) { return $r('sys.symbol.magnifyingglass'); }
    if (page === 2) { return $r('sys.symbol.bell_fill'); }
    if (page === 3) { return $r('sys.symbol.message_fill'); }
    if (page === 4) { return $r('sys.symbol.person_fill'); }
    return $r('sys.symbol.house_fill');
  }

  private pageLabel(page: number): Resource {
    if (page === 1) { return $r('app.string.explore_title'); }
    if (page === 2) { return $r('app.string.tab_alerts'); }
    if (page === 3) { return $r('app.string.chat_title'); }
    if (page === 4) { return $r('app.string.tab_me'); }
    return $r('app.string.home_title');
  }

  private labelText(page: number): string {
    return this.getUIContext().getHostContext()?.resourceManager.getStringSync(this.pageLabel(page)) ?? '';
  }

  private selectedIndex(): number {
    return Math.max(0, this.pages.indexOf(this.navigationPage));
  }

  private syncSelectionGeometry(): void {
    if (!this.active || !this.showSelection || this.pages.length === 0) { return; }
    const ui = this.getUIContext();
    const host = ui.getFrameNodeById('split-root-capsule');
    if (host === null) { return; }
    // Both positions use layout coordinates: the shared grip/hide transform
    // is applied once by the capsule ancestor. Native HDS padding stays included.
    const origin = host.getPositionToWindow();
    const next: LiquidTabTarget[] = [];
    for (let index: number = 0; index < this.pages.length; index++) {
      const page: number = this.pages[index];
      const node = ui.getFrameNodeById('split-root-tab-' + page.toString());
      if (node === null) { return; }
      const size = node.getMeasuredSize();
      if (size.width <= 0 || size.height <= 0) { return; }
      const position = node.getPositionToWindow();
      const target: LiquidTabTarget = new LiquidTabTarget();
      target.page = page;
      target.visibleIndex = index;
      target.width = ui.px2vp(size.width);
      target.height = ui.px2vp(size.height);
      target.x = position.x - origin.x + target.width / 2;
      target.y = position.y - origin.y + target.height / 2;
      if (!Number.isFinite(target.x) || !Number.isFinite(target.y)) { return; }
      next.push(target);
    }
    this.targets = next;
    if (this.liquidMotion.dragging) { return; }
    const target: LiquidTabTarget = this.targets[this.selectedIndex()];
    this.updateSelectionSize(target);
    if (Math.abs(this.liquidMotion.centerY - target.y) > 0.1) { this.liquidMotion.centerY = target.y; }
    if (!this.liquidMotion.ready || this.liquidMotion.displayPage !== target.page) {
      this.snapSelection(target, true);
    } else if (!this.settling && Math.abs(this.liquidMotion.centerX - target.x) > 0.1) {
      this.liquidMotion.centerX = target.x;
    }
  }

  private updateSelectionSize(target: LiquidTabTarget): void {
    const width: number = RootLiquidTabGeometry.width(target.width, this.showLabel,
      this.labeledWidth, this.compactWidth, this.slotOverhang);
    const height: number = this.showLabel ? this.labeledHeight : this.compactHeight;
    if (Math.abs(this.liquidMotion.restWidth - width) > 0.1) { this.liquidMotion.restWidth = width; }
    if (Math.abs(this.liquidMotion.restHeight - height) > 0.1) { this.liquidMotion.restHeight = height; }
  }

  private clearSettleTimer(): void {
    if (this.settleTimer >= 0) { clearTimeout(this.settleTimer); }
    this.settleTimer = -1;
  }

  private snapSelection(target: LiquidTabTarget, stretch: boolean): void {
    this.clearSettleTimer();
    this.updateSelectionSize(target);
    this.liquidMotion.displayPage = target.page;
    this.liquidMotion.contentBlur = 0;
    this.liquidMotion.centerY = target.y;
    if (!this.liquidMotion.ready || this.hidden) {
      this.liquidMotion.centerX = target.x;
      this.liquidMotion.scaleX = 1;
      this.liquidMotion.scaleY = 1;
      this.liquidMotion.ready = true;
      this.settling = false;
      return;
    }
    this.settling = true;
    this.getUIContext().animateTo({ duration: motionDuration(280), curve: Curve.EaseOut }, (): void => {
      this.liquidMotion.centerX = target.x;
      if (!stretch) { this.liquidMotion.scaleX = 1; this.liquidMotion.scaleY = 1; }
    });
    if (stretch) {
      this.getUIContext().animateTo({ duration: motionDuration(90), curve: Curve.EaseOut }, (): void => {
        this.liquidMotion.scaleX = 1.3;
        this.liquidMotion.scaleY = 0.86;
      });
    }
    this.settleTimer = setTimeout((): void => {
      this.getUIContext().animateTo({ duration: motionDuration(420), curve: curves.springMotion(0.36, 0.4) }, (): void => {
        this.liquidMotion.scaleX = 1;
        this.liquidMotion.scaleY = 1;
      });
      this.settleTimer = setTimeout((): void => {
        this.settling = false;
        this.settleTimer = -1;
        this.syncSelectionGeometry();
      }, motionDuration(420));
    }, stretch ? motionDuration(90) : 0);
  }

  private handleNativeTouch(event: TouchEvent): void {
    if (this.hidden || !this.showSelection || this.liquidMotion.dragging || this.settling) { return; }
    // Observe touch for deformation only; HdsTabs supplies the native light.
    if (event.type === TouchType.Down) {
      this.getUIContext().animateTo({ duration: motionDuration(90), curve: Curve.EaseOut }, (): void => {
        this.liquidMotion.scaleX = 1.12;
        this.liquidMotion.scaleY = 1.2;
      });
    } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.getUIContext().animateTo({ duration: motionDuration(420), curve: curves.springMotion(0.36, 0.4) }, (): void => {
        this.liquidMotion.scaleX = 1;
        this.liquidMotion.scaleY = 1;
      });
    }
  }

  private startDrag(): void {
    if (this.hidden || !this.showSelection || !this.liquidMotion.ready) { return; }
    this.clearSettleTimer();
    this.settling = false;
    this.liquidMotion.dragging = true;
    this.dragOriginX = this.liquidMotion.centerX;
    this.lastDragOffset = 0;
    this.smoothedDelta = 0;
    this.dragDirection = 0;
    this.getUIContext().animateTo({ duration: motionDuration(100), curve: Curve.EaseOut }, (): void => {
      this.liquidMotion.scaleX = 1.18;
      this.liquidMotion.scaleY = 1.24;
    });
  }

  private updateDrag(event: GestureEvent): void {
    if (!this.liquidMotion.dragging) { return; }
    this.smoothedDelta = this.smoothedDelta * 0.7 + (event.offsetX - this.lastDragOffset) * 0.3;
    this.lastDragOffset = event.offsetX;
    this.liquidMotion.centerX = RootLiquidTabGeometry.rubberBand(this.targets, this.dragOriginX + event.offsetX);
    const nearest: number = RootLiquidTabGeometry.nearest(this.targets, this.liquidMotion.centerX);
    if (nearest < 0) { return; }
    const target: LiquidTabTarget = this.targets[nearest];
    this.liquidMotion.displayPage = target.page;
    this.liquidMotion.contentBlur = Math.abs(this.liquidMotion.centerX - target.x) > target.width * 0.28 ? 4 : 0;
    const deformation: number = Math.sqrt(Math.min(Math.abs(this.smoothedDelta) / 25, 1));
    const direction: number = this.smoothedDelta >= 0 ? 1 : -1;
    if (this.dragDirection === 0 || Math.abs(this.smoothedDelta) < 0.15) { this.dragDirection = direction; }
    if (this.dragDirection === direction) {
      this.liquidMotion.scaleX = 1.2 + deformation * 0.5;
      this.liquidMotion.scaleY = 1.14 - deformation * 0.32;
    } else {
      this.liquidMotion.scaleX = 1.12 - deformation * 0.2;
      this.liquidMotion.scaleY = 1.2 + deformation * 0.4;
    }
  }

  private endDrag(): void {
    if (!this.liquidMotion.dragging) { return; }
    this.liquidMotion.dragging = false;
    this.lastDragEndedAt = Date.now();
    const nearest: number = RootLiquidTabGeometry.nearest(this.targets, this.liquidMotion.centerX);
    if (nearest < 0) { this.cancelDrag(); return; }
    const target: LiquidTabTarget = this.targets[nearest];
    this.navigationPage = target.page;
    this.pendingPage = target.page === this.selectedPage ? -1 : target.page;
    this.snapSelection(target, false);
    if (target.page !== this.selectedPage) { this.onSelect(target.page); }
  }

  private cancelDrag(): void {
    this.clearSettleTimer();
    this.liquidMotion.dragging = false;
    this.liquidMotion.touchHeld = false;
    this.settling = false;
    this.liquidMotion.scaleX = 1;
    this.liquidMotion.scaleY = 1;
    this.liquidMotion.contentBlur = 0;
    this.liquidMotion.displayPage = this.navigationPage;
  }

  private floatingStyle(width: number): HdsTabsFloatingStyle | undefined {
    if (deviceInfo.apiAvailable('6.1.0(23)')) {
      return {
        barWidth: { smallWidth: Math.max(1, width), mediumWidth: Math.max(1, width), largeWidth: Math.max(1, width) },
        lightColor: this.accentColor,
        gradientMask: { maskColor: Color.Transparent },
        barBottomMargin: 0,
        barSideMargin: 0,
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.IMMERSIVE,
          materialLevel: this.materialLevel
        },
        thermoCtrl: true
      };
    }
    return undefined;
  }

  private usesNativeMaterial(): boolean {
    return this.nativeMaterial && SystemMaterialUtil.isApi26OrAbove() && uiMaterial.isImmersiveMaterialSupported();
  }

  private actionIcon(): Resource {
    if (this.actionMode === 'search') { return $r('sys.symbol.magnifyingglass'); }
    if (this.actionMode === 'top') { return $r('sys.symbol.chevron_up'); }
    if (this.actionMode === 'refresh') { return $r('sys.symbol.arrow_clockwise'); }
    return this.actionSymbol;
  }

  private actionForegroundColor(): ResourceColor {
    const color: ResourceColor = mixedAccentRoleColor(this.accentTheme, 'primary', this.accentColor);
    return this.usesNativeMaterial() ? color :
      pageTextColor(color, this.pageBackgroundValue, Color.Transparent, 4.6);
  }

  @Builder
  private NavigationTab(page: number): void {
    RootBottomTabItem({ page: page, icon: this.pageIcon(page), activeIcon: this.pageIcon(page),
      label: this.pageLabel(page), selected: this.navigationPage === page,
      unread: page === 2 ? this.unreadNotifications : (page === 3 ? this.unreadMessages : 0),
      showLabel: this.showLabel, adaptiveForeground: !this.usesNativeMaterial(),
      accessibleLabel: this.labelText(page) })
      .id('split-root-tab-' + page.toString())
      // Attach inside the native tab builder: gestures on the HdsTabs host
      // do not receive its floating bar's touch sequence on device.
      .onTouch((event: TouchEvent): void => this.handleNativeTouch(event))
      .parallelGesture(PanGesture({ direction: PanDirection.Horizontal })
        .onActionStart((): void => this.startDrag())
        .onActionUpdate((event: GestureEvent): void => this.updateDrag(event))
        .onActionEnd((): void => this.endDrag())
        .onActionCancel((): void => { if (this.liquidMotion.dragging) { this.cancelDrag(); } }))
  }

  @Builder
  private ActionTab(): void {
    Stack() {
      if (this.actionMode === 'refresh' && this.refreshing) {
        LoadingProgress().width(24).height(24)
          .color(this.actionForegroundColor())
      } else {
        SymbolGlyph(this.actionIcon()).fontSize($r('app.float.root_tab_icon_size'))
          .fontColor([this.actionForegroundColor()])
      }
    }
    .width('100%').height('100%')
    .accessibilityText(this.actionLabel)
  }

  @Builder
  private NativeActionTab(): void {
    Button({ type: ButtonType.Circle, stateEffect: false }) {
      this.ActionTab()
    }
    .width('100%').height('100%').padding(0)
    .backgroundColor(Color.Transparent)
    .accessibilityText(this.actionLabel)
    .onClick((): void => this.onNativeAction())
  }

  @Builder
  private NativeNavigationItems(): void {
    Row() {
      ForEach(this.pages, (page: number): void => {
        Button({ type: ButtonType.Normal, stateEffect: false }) {
          this.NavigationTab(page)
        }
        .layoutWeight(1).height('100%').padding(0)
        .borderRadius($r('app.float.split_navigation_corner_radius'))
        .backgroundColor(Color.Transparent)
        .accessibilityText(this.labelText(page))
        .accessibilitySelected(this.navigationPage === page)
        .onClick((): void => {
          const index: number = this.pages.indexOf(page);
          this.onNativeSelected(index);
          this.onNativeTabClick(index);
        })
      }, (page: number): string => page.toString())
    }
    .width('100%').height('100%')
    .padding({ left: $r('app.float.split_navigation_side_margin'), right: $r('app.float.split_navigation_side_margin'),
      top: $r('app.float.split_navigation_content_inset'), bottom: $r('app.float.split_navigation_content_inset') })
    .direction(isAppRtl(this.appLocale) ? Direction.Rtl : Direction.Ltr)
  }

  @Builder
  private NavigationCapsule(): void {
    Stack() {
      // Native tab bars own the touch sequence, material light and hit targets.
      // Foreground hit targets or exclusive gestures would intercept that light.
      if (this.usesNativeMaterial()) {
        ReplyCapsuleSurface({ capsuleHeight: 56, cornerRadius: 28, materialEnabled: true,
          materialLevel: this.nativeMaterialLevel, capsuleContent: (): void => { this.NativeNavigationItems(); } })
          .width('100%').height('100%')
          .id('split-root-native-material')
      } else if (deviceInfo.apiAvailable('6.1.0(23)')) {
        HdsTabs({ index: this.selectedIndex() }) {
          ForEach(this.pages, (page: number): void => {
            TabContent() {}
              .tabBar(this.NavigationTab(page))
          }, (page: number): string => page.toString())
        }
        .width('100%').height($r('app.float.root_tab_bar_height'))
        .barHeight($r('app.float.root_tab_bar_height'))
        .barPosition(BarPosition.End)
        .barMode(BarMode.Fixed)
        .barOverlap(true)
        .vertical(false)
        .scrollable(false)
        .animationDuration(0)
        .backgroundColor(Color.Transparent)
        .barFloatingStyle(this.floatingStyle(this.navigationWidth))
        .direction(isAppRtl(this.appLocale) ? Direction.Rtl : Direction.Ltr)
        .onSelected((index: number): void => this.onNativeSelected(index))
        .onTabBarClick((index: number): void => this.onNativeTabClick(index))
      }
      if (this.showSelection) {
        RootLiquidTabSurface({ motion: this.liquidMotion, showLabel: this.showLabel, materialLevel: this.materialLevel,
          nativeMaterial: this.usesNativeMaterial(), nativeMaterialLevel: this.nativeMaterialLevel,
          unreadNotifications: this.unreadNotifications, unreadMessages: this.unreadMessages })
          .width('100%').height('100%')
          .hitTestBehavior(HitTestMode.None)
      }
    }
    .height($r('app.float.root_tab_bar_height'))
    .layoutWeight(1)
    .borderRadius($r('app.float.split_navigation_corner_radius'))
    .clip(true)
    .id('split-root-capsule')
    .translate({ x: this.navigationTranslation() })
    .animation({ duration: motionDuration(300), curve: motionCurve() })
    .onAreaChange((_old: Area, area: Area): void => {
      const width: number = Number(area.width);
      if (width > 0 && width !== this.navigationWidth) { this.navigationWidth = width; }
    })
  }

  build(): void {
    Row({ space: $r('app.float.split_navigation_gap') }) {
      this.NavigationCapsule()
      if (this.showAction && this.usesNativeMaterial()) {
        ReplyCapsuleSurface({ capsuleHeight: 56, cornerRadius: 28, materialEnabled: true,
          materialLevel: this.nativeMaterialLevel, capsuleContent: (): void => { this.NativeActionTab(); } })
          .width($r('app.float.root_tab_bar_height')).height($r('app.float.root_tab_bar_height'))
          .borderRadius($r('app.float.split_navigation_corner_radius'))
          .clip(true)
          .id('split-root-native-action')
          .opacity(this.actionHidden ? 0 : 1)
          .translate({ x: this.actionTranslation(), y: this.actionHidden ? 16 : 0 })
          .animation({ duration: motionDuration(300), curve: motionCurve() })
          .hitTestBehavior(this.actionHidden ? HitTestMode.None : HitTestMode.Default)
      } else if (this.showAction && deviceInfo.apiAvailable('6.1.0(23)')) {
        HdsTabs({ index: 0 }) {
          TabContent() {}
            .tabBar(this.ActionTab())
        }
        .width($r('app.float.root_tab_bar_height')).height($r('app.float.root_tab_bar_height'))
        .barHeight($r('app.float.root_tab_bar_height'))
        .barPosition(BarPosition.End)
        .barMode(BarMode.Fixed)
        .barOverlap(true)
        .vertical(false)
        .scrollable(false)
        .animationDuration(0)
        .backgroundColor(Color.Transparent)
        .barFloatingStyle(this.floatingStyle(56))
        .onTabBarClick((): void => this.onNativeAction())
        .accessibilityText(this.actionLabel)
        .borderRadius($r('app.float.split_navigation_corner_radius'))
        .clip(true)
        .id('split-root-action')
        .opacity(this.actionHidden ? 0 : 1)
        .translate({ x: this.actionTranslation(), y: this.actionHidden ? 16 : 0 })
        .animation({ duration: motionDuration(300), curve: motionCurve() })
        .hitTestBehavior(this.actionHidden ? HitTestMode.None : HitTestMode.Default)
      }
    }
    .height($r('app.float.root_tab_bar_height'))
    .width('100%')
    .direction(Direction.Ltr)
    .constraintSize({ maxWidth: $r('app.float.split_navigation_max_width') })
    .padding({ left: $r('app.float.split_navigation_side_margin'), right: $r('app.float.split_navigation_side_margin') })
    .translate({ y: this.hidden ? 88 : 0 })
    .opacity(this.hidden ? 0 : 1)
    .animation({ duration: motionDuration(220), curve: motionCurve() })
    .hitTestBehavior(this.hidden ? HitTestMode.None : HitTestMode.Default)
    .enabled(!this.hidden)
    .accessibilityLevel(this.hidden ? 'no-hide-descendants' : 'auto')
    .id('split-root-navigation')
  }
}
