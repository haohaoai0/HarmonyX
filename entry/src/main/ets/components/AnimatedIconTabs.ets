import { TimelineTabCover } from './TimelineTabCover';
import { motionDuration, motionCurve } from '../utils/AppMotion';
import { hapticTick } from '../utils/Haptics';
import { DEFAULT_COMPONENT_HDR_ENABLED, DEFAULT_COMPONENT_HDR_RATIO, STORAGE_KEY_COMPONENT_HDR_ENABLED,
  STORAGE_KEY_COMPONENT_HDR_RATIO } from '../services/ComponentHdrSettingsStore';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { LengthMetrics, UIContext } from '@kit.ArkUI';
import { resourceManager } from '@kit.LocalizationKit';
import { ProfileTabMotion } from '../utils/ProfileTabMotion';
import { SystemMaterialUtil } from '../utils/SystemMaterial';
import { ComponentHdrHighlight } from '../utils/ComponentHdrHighlight';
import { materialModifier } from '../utils/SystemMaterial';

export interface IconTabItem {
  key: string;
  label: ResourceStr;
  icon?: Resource;
  imageUrl?: string;
  chevron?: boolean;
}

interface ButtonTabArea {
  key: string;
  start: number;
  width: number;
}

const TAB_MIN_SLOT_WIDTH_VP: number = 56;
const TAB_LABEL_PADDING_VP: number = 20;
const TAB_ICON_PREFIX_VP: number = 27;
const TAB_MIN_GAP_VP: number = 4;

// Labels stay visible when inactive; selection unfolds the icon beside the
// label. Pagers supply fractional progress, other surfaces animate selection.
@Component
export struct AnimatedIconTabs {
  @StorageProp(STORAGE_KEY_COMPONENT_HDR_ENABLED) private componentHdrEnabled: boolean = DEFAULT_COMPONENT_HDR_ENABLED;
  @StorageProp(STORAGE_KEY_COMPONENT_HDR_RATIO) private componentHdrRatio: number = DEFAULT_COMPONENT_HDR_RATIO;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Prop items: IconTabItem[] = [];
  @Prop @Watch('selectionChanged') selected: number = 0;
  @Prop tabPosition: number = -1;
  @Prop barHeight: number = 52;
  @Prop showDivider: boolean = false;
  @Prop equalWidth: boolean = false;
  @Prop @Watch('selectionChanged') buttonStyle: boolean = false;
  // Explore's category row sizes every slot from its own label. The active
  // icon unfolds inside that slot instead of taking width away from the text.
  @Prop contentSized: boolean = false;
  @StorageProp('harmonyx.accent_color') private accentColor: string = '#007DFF';
  @State private animatedPosition: number = 0;
  @State private viewportWidth: number = 0;
  @State private textWidths: number[] = [];
  @State private intrinsicWidths: number[] = [];
  @State private buttonAreas: ButtonTabArea[] = [];
  private scroller: Scroller = new Scroller();
  private buttonGap: number = 0;
  private buttonMaxHeight: number = 0;
  private buttonFillOpacity: number = 0;
  onSelect: (index: number) => void = (): void => {};
  onOptions: (index: number) => void = (index: number): void => this.onSelect(index);

  aboutToAppear(): void {
    this.animatedPosition = this.selected;
    const context: UIContext = this.getUIContext();
    const resources: resourceManager.ResourceManager | undefined = context.getHostContext()?.resourceManager;
    if (resources === undefined) { return; }
    this.buttonGap = context.px2vp(resources.getNumber($r('app.float.icon_buttons_gap').id));
    this.buttonMaxHeight = context.px2vp(resources.getNumber($r('app.float.icon_buttons_height').id));
    this.buttonFillOpacity = resources.getNumber($r('app.float.icon_buttons_fill_opacity').id);
  }

  private selectionChanged(): void {
    if (this.tabPosition < 0) {
      this.getUIContext().animateTo({ duration: motionDuration(280), curve: motionCurve() }, (): void => {
        this.animatedPosition = this.selected;
      });
    }
    this.revealSelected();
  }

  private motionPosition(): number {
    return ProfileTabMotion.clamp(this.tabPosition >= 0 ? this.tabPosition : this.animatedPosition, this.items.length);
  }
  private contentSizedActive(): boolean {
    return this.contentSized && !this.buttonStyle && !this.equalWidth;
  }
  private slotExpansion(): number {
    return this.equalWidth || this.buttonStyle || this.contentSized ? 0 : 0.5;
  }
  private contentBase(index: number): number {
    if (!this.contentSizedActive()) { return this.base(); }
    const measured: number = this.intrinsicWidths[index] ?? this.labelWidth(index);
    return Math.max(TAB_MIN_SLOT_WIDTH_VP, measured + TAB_LABEL_PADDING_VP + (this.items[index].chevron ? 27 : 0));
  }
  private contentBaseSum(): number {
    let total: number = 0;
    for (let i: number = 0; i < this.items.length; i++) {
      total += this.contentBase(i);
    }
    return total;
  }
  private activeIconWidth(position: number): number {
    let total: number = 0;
    for (let i: number = 0; i < this.items.length; i++) {
      total += this.iconPrefix(i) * this.fractionAt(i, position);
    }
    return total;
  }
  private contentWidth(): number {
    if (this.contentSizedActive()) {
      let widestIcon: number = 0;
      for (let i: number = 0; i < this.items.length; i++) {
        widestIcon = Math.max(widestIcon, this.iconPrefix(i));
      }
      return Math.max(this.viewportWidth,
        this.contentBaseSum() + this.items.length * TAB_MIN_GAP_VP + widestIcon);
    }
    return Math.max(this.viewportWidth, (this.items.length + this.slotExpansion()) * 56);
  }
  private contentSpacing(position: number): number {
    if (!this.contentSizedActive()) { return 0; }
    const count: number = Math.max(1, this.items.length);
    return Math.max(0, (this.contentWidth() - this.contentBaseSum() - this.activeIconWidth(position)) / count);
  }
  private base(): number { return ProfileTabMotion.baseWidth(this.contentWidth(), this.items.length, this.slotExpansion()); }
  private expanded(): number { return ProfileTabMotion.expandedWidth(this.contentWidth(), this.items.length, this.slotExpansion()); }
  private fractionAt(index: number, position: number): number {
    return ProfileTabMotion.fraction(index, position, this.items.length);
  }
  private fraction(index: number): number { return this.fractionAt(index, this.motionPosition()); }
  private labelWidth(index: number): number {
    if (this.contentSizedActive() && this.intrinsicWidths[index] !== undefined) {
      return this.intrinsicWidths[index];
    }
    return this.textWidths[index] ?? 32;
  }
  private slotWidthAt(index: number, position: number): number {
    if (!this.contentSizedActive()) {
      return ProfileTabMotion.slotWidth(index, position, this.contentWidth(), this.items.length, this.slotExpansion());
    }
    return this.contentBase(index) + this.contentSpacing(position) +
      this.iconPrefix(index) * this.fractionAt(index, position);
  }
  private slotStartAt(index: number, position: number): number {
    if (!this.contentSizedActive()) {
      return ProfileTabMotion.slotStart(index, position, this.contentWidth(), this.items.length, this.slotExpansion());
    }
    let start: number = 0;
    for (let i: number = 0; i < index; i++) {
      start += this.slotWidthAt(i, position);
    }
    return start;
  }
  private slotCenterAt(index: number, position: number): number {
    return this.slotStartAt(index, position) + this.slotWidthAt(index, position) / 2;
  }
  private motionCenter(index: number): number {
    return this.slotCenterAt(index, this.motionPosition());
  }
  private indicatorWidthAt(position: number): number {
    if (!this.contentSizedActive()) {
      return ProfileTabMotion.indicatorWidth(this.contentWidth(), this.items.length, this.slotExpansion());
    }
    let width: number = 0;
    for (let i: number = 0; i < this.items.length; i++) {
      width += this.contentBase(i) * this.fractionAt(i, position);
    }
    return Math.max(1, width * 0.9);
  }
  private indicatorLeftAt(position: number): number {
    if (!this.contentSizedActive()) {
      return ProfileTabMotion.indicatorLeft(position, this.contentWidth(), this.items.length, this.slotExpansion());
    }
    let center: number = 0;
    for (let i: number = 0; i < this.items.length; i++) {
      center += this.slotCenterAt(i, position) * this.fractionAt(i, position);
    }
    return center - this.indicatorWidthAt(position) / 2;
  }
  private iconPrefix(index: number): number { return this.items[index].icon || (this.items[index].imageUrl ?? '').length > 0 ? 27 : 0; }
  private optionsOffset(index: number): number {
    return this.motionCenter(index) + (this.iconPrefix(index) + this.labelWidth(index) - 17) / 2;
  }
  private measure(index: number, area: Area): void {
    const width: number = Number(area.width);
    if (width > 0 && Math.abs(this.labelWidth(index) - width) > 0.5) {
      const widths: number[] = this.textWidths.slice();
      widths[index] = width;
      this.textWidths = widths;
    }
  }
  private measureIntrinsic(index: number, area: Area): void {
    const width: number = Number(area.width);
    const previous: number | undefined = this.intrinsicWidths[index];
    if (width > 0 && (previous === undefined || Math.abs(previous - width) > 0.5)) {
      const widths: number[] = this.intrinsicWidths.slice();
      widths[index] = width;
      this.intrinsicWidths = widths;
    }
  }
  private label(index: number): string {
    const label: ResourceStr = this.items[index].label;
    if (typeof label === 'string') { return label; }
    try { return this.getUIContext().getHostContext()?.resourceManager.getStringSync(label) ?? ''; }
    catch (_error) { return ''; }
  }
  private revealSelected(): void {
    if (this.buttonStyle) {
      const item: IconTabItem | undefined = this.items[this.selected];
      if (item === undefined || this.viewportWidth <= 0) { return; }
      const area: ButtonTabArea | undefined = this.buttonAreas.find((value: ButtonTabArea): boolean => value.key === item.key);
      if (area === undefined) { return; }
      const current: number = this.scroller.currentOffset().xOffset;
      const target: number = area.width >= this.viewportWidth || area.start < current ? area.start :
        area.start + area.width > current + this.viewportWidth ? area.start + area.width - this.viewportWidth : current;
      if (Math.abs(target - current) > 0.5) {
        this.scroller.scrollTo({ xOffset: Math.max(0, target), yOffset: 0, animation: { duration: motionDuration(280) } });
      }
      return;
    }
    if (this.viewportWidth <= 0 || this.contentWidth() <= this.viewportWidth) { return; }
    const left: number = this.slotStartAt(this.selected, this.selected);
    const right: number = left + this.slotWidthAt(this.selected, this.selected);
    const current: number = this.scroller.currentOffset().xOffset;
    const target: number = left < current ? left : right > current + this.viewportWidth ? right - this.viewportWidth : current;
    this.scroller.scrollTo({ xOffset: Math.max(0, target), yOffset: 0, animation: { duration: motionDuration(280) } });
  }

  private measureButton(index: number, area: Area): void {
    const item: IconTabItem | undefined = this.items[index];
    const width: number = Number(area.width);
    const start: number = Number(area.position.x);
    if (item === undefined || width <= 0) { return; }
    const previous: ButtonTabArea | undefined = this.buttonAreas.find((value: ButtonTabArea): boolean => value.key === item.key);
    if (previous !== undefined && Math.abs(previous.start - start) <= 0.5 && Math.abs(previous.width - width) <= 0.5) { return; }
    const areas: ButtonTabArea[] = this.buttonAreas.filter((value: ButtonTabArea): boolean =>
      value.key !== item.key && this.items.some((tab: IconTabItem): boolean => tab.key === value.key));
    areas.push({ key: item.key, start: start, width: width });
    this.buttonAreas = areas;
    this.revealSelected();
  }

  private buttonHeight(): number { return Math.min(this.buttonMaxHeight, this.barHeight - 4); }

  @Builder
  private TabIcon(index: number): void {
    if ((this.items[index].imageUrl ?? '').length > 0) {
      Stack() {
        if (this.items[index].icon) {
          SymbolGlyph(this.items[index].icon as Resource).fontSize($r('app.float.icon_tabs_icon_size'))
            .fontColor([$r('app.color.text_primary')])
        }
        TimelineTabCover({ url: this.items[index].imageUrl ?? '' })
      }.width(22).height(22).borderRadius(5).clip(true)
    } else if (this.items[index].icon) {
      SymbolGlyph(this.items[index].icon as Resource)
        .fontSize(this.buttonStyle ? $r('app.float.icon_buttons_icon_size') : $r('app.float.icon_tabs_icon_size'))
        .fontColor([$r('app.color.text_primary')])
        .width(this.buttonStyle ? LayoutPolicy.fixAtIdealSize : 22)
    }
  }

  @Builder
  private ButtonLabel(index: number, active: boolean): void {
    Row({ space: 5 }) {
      if (active && this.iconPrefix(index) > 0) {
        this.TabIcon(index)
      }
      Text(this.items[index].label).fontFamily(this.appFontFamily).fontSize($r('app.float.icon_buttons_label_size'))
        .fontWeight(active ? FontWeight.Bold : FontWeight.Medium).fontColor($r('app.color.text_primary'))
        .maxLines(1).width(LayoutPolicy.fixAtIdealSize)
      if (active && this.items[index].chevron) {
        SymbolGlyph($r('sys.symbol.chevron_down')).fontSize($r('app.float.icon_tabs_chevron_size'))
          .fontColor([$r('app.color.text_primary')])
      }
    }.width(LayoutPolicy.fixAtIdealSize).height(this.buttonHeight()).justifyContent(FlexAlign.Center)
      .padding({ left: this.buttonGap, right: this.buttonGap })
      .compositingFilter(ComponentHdrHighlight.filter(this.getUIContext(), this.componentHdrEnabled && active && this.fraction(index) > 0, this.componentHdrRatio))
      .opacity(active ? this.fraction(index) : 1 - this.fraction(index))
  }

  @Builder
  private FilledButton(index: number): void {
    Stack({ alignContent: Alignment.Center }) {
      if (SystemMaterialUtil.isApi26OrAbove()) {
        // Match MaterialButton's native material host, below the independent
        // progress fill, so the whole pill retains its material while dragging.
        Toggle({ type: ToggleType.Button, isOn: false })
          .width(LayoutPolicy.matchParent).height(LayoutPolicy.matchParent).borderRadius(this.buttonHeight() / 2)
          .backgroundColor(Color.Transparent).focusable(false)
          .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
          .attributeModifier(materialModifier(SystemMaterialUtil.immersiveMaterial(1, false, false, false, undefined)))
      }
      // Only the fill transforms during paging; the pill and label keep their
      // layout sizes so horizontal progress never relayouts the feed.
      Row().width(LayoutPolicy.matchParent).height(LayoutPolicy.matchParent).backgroundColor(this.accentColor)
        .opacity(this.buttonFillOpacity)
        .scale({ x: this.fraction(index), y: 1, centerX: 0 })
      this.ButtonLabel(index, false)
      this.ButtonLabel(index, true)
    }.width(LayoutPolicy.wrapContent).height(this.buttonHeight())
      .backgroundColor(SystemMaterialUtil.isApi26OrAbove() ? Color.Transparent : $r('app.color.bg_field'))
      .borderRadius(this.buttonHeight() / 2).clip(true)
      .id('harmonyx-capsule-tab-' + this.items[index].key)
      .accessibilityGroup(true).accessibilityText(this.label(index)).accessibilitySelected(this.selected === index)
      .onClick((): void => { hapticTick(); this.onSelect(index); })
      .onAreaChange((_old: Area, area: Area): void => this.measureButton(index, area))
  }

  @Builder
  private Tab(index: number): void {
    if (this.contentSizedActive()) {
      Stack({ alignContent: Alignment.TopStart }) {
        Row() {
          Text(this.items[index].label).fontFamily(this.appFontFamily)
            .fontSize($r('app.float.icon_tabs_label_size')).fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_secondary')).maxLines(1)
            .width(LayoutPolicy.fixAtIdealSize)
        }.width(this.slotWidthAt(index, this.motionPosition())).height(this.barHeight - 3)
          .justifyContent(FlexAlign.Center).opacity(1 - this.fraction(index))
        Row({ space: 5 }) {
          if (this.iconPrefix(index) > 0) {
            this.TabIcon(index)
          }
          Text(this.items[index].label).fontFamily(this.appFontFamily)
            .fontSize($r('app.float.icon_tabs_label_size')).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary')).maxLines(1)
            .width(LayoutPolicy.fixAtIdealSize)
          if (this.items[index].chevron) {
            SymbolGlyph($r('sys.symbol.chevron_down')).fontSize($r('app.float.icon_tabs_chevron_size'))
              .fontColor([$r('app.color.text_secondary')]).width(22)
          }
        }.width(this.slotWidthAt(index, this.motionPosition())).height(this.barHeight - 3)
          .justifyContent(FlexAlign.Center)
          .compositingFilter(ComponentHdrHighlight.filter(this.getUIContext(), this.componentHdrEnabled && this.fraction(index) > 0, this.componentHdrRatio))
          .scale({ x: Math.max(0.001, this.fraction(index)), y: 1 }).opacity(this.fraction(index))
      }.width(this.slotWidthAt(index, this.motionPosition())).height(this.barHeight - 3).clip(false)
        .translate({ x: this.slotStartAt(index, this.motionPosition()) })
        .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
    } else {
      Stack({ alignContent: Alignment.TopStart }) {
        Row() {
          Text(this.items[index].label).fontFamily(this.appFontFamily).fontSize($r('app.float.icon_tabs_label_size')).fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_secondary')).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            .constraintSize({ maxWidth: Math.max(1, this.base() - 10) })
        }.width(this.base()).height(this.barHeight - 3).justifyContent(FlexAlign.Center)
          .opacity(1 - this.fraction(index))
        Row({ space: 5 }) {
          if (this.iconPrefix(index) > 0) {
            this.TabIcon(index)
          }
          Text(this.items[index].label).fontFamily(this.appFontFamily).fontSize($r('app.float.icon_tabs_label_size')).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary')).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            .constraintSize({ maxWidth: Math.max(1, this.expanded() - this.iconPrefix(index) -
              (this.items[index].chevron ? 27 : 0) - 16) })
            .onAreaChange((_old: Area, area: Area): void => this.measure(index, area))
          if (this.items[index].chevron) {
            SymbolGlyph($r('sys.symbol.chevron_down')).fontSize($r('app.float.icon_tabs_chevron_size'))
              .fontColor([$r('app.color.text_secondary')]).width(22)
          }
        }.width(this.expanded()).height(this.barHeight - 3).justifyContent(FlexAlign.Center)
          .translate({ x: (this.base() - this.expanded()) / 2 })
          .compositingFilter(ComponentHdrHighlight.filter(this.getUIContext(), this.componentHdrEnabled && this.fraction(index) > 0, this.componentHdrRatio))
          .scale({ x: Math.max(0.001, this.fraction(index)), y: 1 }).opacity(this.fraction(index))
      }.width(this.base()).height(this.barHeight - 3).clip(false)
        .translate({ x: this.motionCenter(index) - this.base() / 2 })
        .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
    }
  }

  @Builder
  private HitArea(index: number): void {
    if (this.contentSizedActive()) {
      Button({ type: ButtonType.Normal, stateEffect: false }) { Row() }
        .width(this.slotWidthAt(index, this.motionPosition())).height(this.barHeight - 3)
        .padding(0).backgroundColor(Color.Transparent)
        .translate({ x: this.slotStartAt(index, this.motionPosition()) })
        .accessibilityText(this.label(index)).accessibilitySelected(this.selected === index)
        .onClick((): void => { hapticTick(); this.onSelect(index); })
    } else {
      // Fixed layout width; transform the transparent hit area to match the
      // expanding slot, so the complete label remains clickable during motion.
      Button({ type: ButtonType.Normal, stateEffect: false }) { Row() }
        .width(this.expanded()).height(this.barHeight - 3).padding(0).backgroundColor(Color.Transparent)
        .scale({ x: this.slotWidthAt(index, this.motionPosition()) / this.expanded(),
          y: 1, centerX: 0 })
        .translate({ x: this.slotStartAt(index, this.motionPosition()) })
        .accessibilityText(this.label(index)).accessibilitySelected(this.selected === index)
        .onClick((): void => { hapticTick(); this.onSelect(index); })
    }
  }

  @Builder
  private IntrinsicLabelProbe(index: number): void {
    // Invisible, intrinsic-width copy used only to feed the slot geometry.
    Row() {
      Text(this.items[index].label).fontFamily(this.appFontFamily)
        .fontSize($r('app.float.icon_tabs_label_size')).fontWeight(FontWeight.Bold)
        .maxLines(1).width(LayoutPolicy.fixAtIdealSize)
        .onAreaChange((_old: Area, area: Area): void => this.measureIntrinsic(index, area))
    }.opacity(0).hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
  }

  build(): void {
    Scroll(this.scroller) {
      if (this.buttonStyle) {
        // Each capsule keeps its complete bold label, optional icons and padding.
        // The two label states share an intrinsic size; only the fill/opacity animate.
        Row({ space: this.buttonGap }) {
          ForEach(this.items, (item: IconTabItem, index: number) => { this.FilledButton(index) },
            (item: IconTabItem): string => item.key)
        }.width(LayoutPolicy.fixAtIdealSize).height(this.barHeight)
          .padding({ left: this.buttonGap / 2, right: this.buttonGap / 2 })
      } else {
        Stack({ alignContent: Alignment.TopStart }) {
          ForEach(this.items, (item: IconTabItem, index: number) => { this.Tab(index) },
            (item: IconTabItem): string => item.key)
          Row().width(this.indicatorWidthAt(this.motionPosition()))
            .height($r('app.float.icon_tabs_indicator_height')).borderRadius($r('app.float.icon_tabs_indicator_radius'))
            .backgroundColor($r('app.color.text_primary'))
            .translate({ x: this.indicatorLeftAt(this.motionPosition()), y: this.barHeight - 3 })
            .hitTestBehavior(HitTestMode.None)
          ForEach(this.items, (item: IconTabItem, index: number) => { this.HitArea(index) }, (item: IconTabItem): string => item.key)
          if (this.contentSizedActive()) {
            ForEach(this.items, (item: IconTabItem, index: number) => { this.IntrinsicLabelProbe(index) },
              (item: IconTabItem): string => 'probe-' + item.key)
          }
          if (this.items[this.selected]?.chevron && Math.abs(this.motionPosition() - this.selected) < 0.01) {
            Button({ type: ButtonType.Normal, stateEffect: false }) { Row() }.width(22).height(this.barHeight - 8)
              .backgroundColor(Color.Transparent)
              .translate({ x: this.optionsOffset(this.selected), y: 3 })
              .accessibilityText(this.label(this.selected)).onClick((): void => this.onOptions(this.selected))
          }
        }.width(this.contentWidth()).height(this.barHeight).clip(true)
      }
    }.width('100%').height(this.barHeight).scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
      .fadingEdge(this.buttonStyle, {
        fadingEdgeLength: LengthMetrics.resource($r('app.float.title_bar_pill_edge_fade_length'))
      })
      .border({ width: { bottom: this.showDivider ? 0.5 : 0 }, color: $r('app.color.divider') })
      .onAreaChange((_old: Area, area: Area): void => {
        const width: number = Number(area.width);
        if (width > 0 && Math.abs(this.viewportWidth - width) > 0.5) {
          this.viewportWidth = width;
          this.revealSelected();
        }
      })
  }
}
