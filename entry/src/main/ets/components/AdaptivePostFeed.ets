import { scrollFrame, scrollStarted, scrollStopped, stopScrollOnTouch } from '../utils/ScrollInteraction';
import { STORAGE_KEY_TIMELINE_COLUMNS } from '../services/TimelineSettingsStore';
import { PostFeedLayout } from '../utils/PostFeedLayout';
import { common } from '@kit.AbilityKit';

// Keep the same scroll container and card identities when the pane changes
// width. Header/footer sections always span the full available width.
@Component
export struct AdaptivePostFeed {
  @Prop @Watch('syncSections') itemKeys: string[] = [];
  @Prop @Watch('syncSections') allowColumns: boolean = true;
  @StorageProp(STORAGE_KEY_TIMELINE_COLUMNS) @Watch('syncSections') private preferredColumns: number = 0;
  scroller: Scroller = new Scroller();
  @Prop startOffset: number = 0;
  @Prop endOffset: number = 0;
  @Prop clipContent: boolean = false;
  @Prop forwardMode: NestedScrollMode = NestedScrollMode.SELF_ONLY;
  @Prop backwardMode: NestedScrollMode = NestedScrollMode.SELF_ONLY;
  @Prop feedId: string = '';
  @BuilderParam header: () => void = this.Empty;
  @BuilderParam footer: () => void = this.Empty;
  @BuilderParam item: (index: number) => void = this.EmptyItem;
  onLoadMore: () => void = (): void => {};
  onFeedScroll: (offset: number) => void = (): void => {};
  onVisibleItems: (start: number, end: number) => void = (): void => {};
  @State private paneWidth: number = 0;
  @State private sections: WaterFlowSections = new WaterFlowSections();

  @Builder private Empty(): void { Column() }
  @Builder private EmptyItem(_index: number): void { Column() }

  aboutToAppear(): void { this.syncSections(); }

  private columns(): number {
    return this.allowColumns ? PostFeedLayout.columns(this.paneWidth, this.preferredColumns) : 1;
  }

  private gap(resource: Resource): number {
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    return this.getUIContext().px2vp(context.resourceManager.getNumber(resource.id));
  }

  private syncSections(): void {
    const content: SectionOptions = { itemsCount: this.itemKeys.length, crossCount: this.columns(),
      columnsGap: this.columns() > 1 ? this.gap($r('app.float.post_feed_column_gap')) : 0,
      rowsGap: this.columns() > 1 ? this.gap($r('app.float.post_feed_row_gap')) : 0 };
    const previous: SectionOptions[] = this.sections.values();
    if (previous.length !== 3) {
      const sections: SectionOptions[] = [
        { itemsCount: 1, crossCount: 1 }, content, { itemsCount: 1, crossCount: 1 }
      ];
      this.sections.splice(0, previous.length, sections);
    } else if (previous[1].itemsCount !== content.itemsCount || previous[1].crossCount !== content.crossCount) {
      this.sections.update(1, content);
    }
  }

  build(): void {
    WaterFlow({ scroller: this.scroller, sections: this.sections, layoutMode: WaterFlowLayoutMode.SLIDING_WINDOW }) {
      FlowItem() { Column() { this.header() }.width('100%') }
      ForEach(this.itemKeys, (_key: string, index: number) => {
        FlowItem() { this.item(index) }.width('100%')
      }, (key: string, index: number): string => index.toString() + ':' + key)
      FlowItem() { Column() { this.footer() }.width('100%') }
    }
    .onScrollStop((): void => scrollStopped(this.scroller))
    .onScrollStart((): void => scrollStarted(this.scroller))
    .onScrollFrameBegin((offset: number, state: ScrollState): OnScrollFrameBeginHandlerResult =>
      scrollFrame(this.scroller, offset, state))
    .onTouchIntercept((event: TouchEvent): HitTestMode => stopScrollOnTouch(event, this.scroller))
    .id(this.feedId).width('100%').height('100%')
    .columnsTemplate(PostFeedLayout.template(this.columns()))
    .contentStartOffset(this.startOffset).contentEndOffset(this.endOffset)
    .cachedCount(8).clip(this.clipContent).scrollBar(BarState.Auto)
    .nestedScroll({ scrollForward: this.forwardMode, scrollBackward: this.backwardMode })
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .onAreaChange((_old: Area, area: Area): void => {
      const width: number = Number(area.width);
      if (width > 0 && Math.abs(width - this.paneWidth) > 0.5) {
        this.paneWidth = width;
        this.syncSections();
      }
    })
    .onReachEnd((): void => this.onLoadMore())
    .onDidScroll((offset: number): void => this.onFeedScroll(offset))
    .onScrollIndex((start: number, end: number): void => this.onVisibleItems(Math.max(0, start - 1), end - 1))
  }
}
