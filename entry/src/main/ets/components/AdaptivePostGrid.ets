import { STORAGE_KEY_TIMELINE_COLUMNS } from '../services/TimelineSettingsStore';
import { PostFeedLayout } from '../utils/PostFeedLayout';

// Embedded collections share the page's existing scroller.
@Component
export struct AdaptivePostGrid {
  @Prop itemKeys: string[] = [];
  @StorageProp(STORAGE_KEY_TIMELINE_COLUMNS) private preferredColumns: number = 0;
  @State private paneWidth: number = 0;
  @BuilderParam item: (index: number) => void = this.EmptyItem;
  @Builder private EmptyItem(_index: number): void { Column() }

  build(): void {
    GridRow({ columns: PostFeedLayout.columns(this.paneWidth, this.preferredColumns),
      gutter: { x: $r('app.float.post_feed_column_gap'), y: $r('app.float.post_feed_row_gap') } }) {
      ForEach(this.itemKeys, (_key: string, index: number) => {
        GridCol() { this.item(index) }
      }, (key: string, index: number): string => index.toString() + ':' + key)
    }.width('100%')
      .onAreaChange((_old: Area, area: Area): void => {
        const width: number = Number(area.width);
        if (width > 0 && Math.abs(width - this.paneWidth) > 0.5) { this.paneWidth = width; }
      })
  }
}
