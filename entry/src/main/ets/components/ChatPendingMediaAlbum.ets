import { common } from '@kit.AbilityKit';
import { ChatPickedFile } from '../services/XChatMedia';
import { ChatMediaSend, chatMediaOutbox } from '../services/ChatMediaOutbox';
import { ChatAlbumCell, ChatAlbumGeometry, ChatAlbumRow, ChatAlbumSize, chatAlbumLayout } from '../utils/ChatAlbumLayout';
import { ChatPendingMediaCard } from './ChatPendingMediaCard';

@Component
export struct ChatPendingMediaAlbum {
  files: ChatPickedFile[] = [];
  sendId: string = '';
  @Prop conversationId: string = '';
  @State private progress: number[] = [];
  @State private failed: boolean = false;
  @StorageProp('harmonyx.window_height') @Watch('resize') windowHeight: number = 0;
  @State private layout: ChatAlbumGeometry = new ChatAlbumGeometry();
  private sizes: ChatAlbumSize[] = [];
  private availableWidth: number = 0;
  private active: boolean = true;
  private outboxListener: () => void = (): void => { if (this.active) { this.syncProgress(); } };

  aboutToAppear(): void {
    this.active = true; this.sizes = this.files.map((_file: ChatPickedFile): ChatAlbumSize => ({ width: 0, height: 0 })); this.resize();
    chatMediaOutbox.subscribe(this.outboxListener); this.syncProgress();
  }
  aboutToDisappear(): void { this.active = false; chatMediaOutbox.unsubscribe(this.outboxListener); }
  private syncProgress(): void {
    const send: ChatMediaSend | undefined = chatMediaOutbox.status(this.sendId);
    if (send !== undefined) {
      // Keep primitives in this component's own state. ForEach retains its
      // builder, so a captured, undecorated send object cannot drive @Prop.
      this.progress = send.progress.slice(); this.failed = send.state === 'failed';
    }
  }
  private dimension(resource: Resource): number {
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    return this.getUIContext().px2vp(context.resourceManager.getNumber(resource.id));
  }
  private resize(): void {
    if (!this.active) { return; }
    const single: boolean = this.files.length === 1;
    const width: number = this.dimension(single ? $r('app.float.chat_media_single_max_width') : $r('app.float.chat_media_max_width'));
    const height: number = this.dimension(single ? $r('app.float.chat_media_single_max_height') : $r('app.float.chat_media_max_height'));
    const fallback: number = this.dimension($r('app.float.chat_media_default_width'));
    this.layout = chatAlbumLayout(this.sizes, Math.min(width, this.availableWidth > 0 ? this.availableWidth : fallback),
      this.windowHeight > 0 ? Math.min(height, this.windowHeight * 0.38) : height,
      this.dimension($r('app.float.chat_media_album_gap')));
  }
  private measured(index: number, width: number, height: number): void {
    if (!this.active || width <= 0 || height <= 0 || index >= this.sizes.length ||
      this.sizes[index].width === width && this.sizes[index].height === height) { return; }
    this.sizes = this.sizes.map((size: ChatAlbumSize, i: number): ChatAlbumSize => i === index ? { width: width, height: height } : size);
    this.resize();
  }
  @Builder
  private Tile(cell: ChatAlbumCell): void {
    if (this.files[cell.index] !== undefined) {
      ChatPendingMediaCard({ file: this.files[cell.index], conversationId: this.conversationId,
        progress: this.progress[cell.index] ?? 0,
        failed: this.failed, mediaWidth: cell.width, mediaHeight: cell.height,
        onDimensions: (width: number, height: number): void => { this.measured(cell.index, width, height); } })
    }
  }
  @Builder
  private Rows(): void {
    Column({ space: this.layout.gap }) {
      ForEach(this.layout.rows, (row: ChatAlbumRow) => {
        Row({ space: this.layout.gap }) {
          ForEach(row.cells, (cell: ChatAlbumCell) => { this.Tile(cell); },
            (cell: ChatAlbumCell): string => cell.index + ':' + cell.width.toFixed(2) + ':' + cell.height.toFixed(2))
        }.height(row.height)
      }, (row: ChatAlbumRow): string => row.cells.map((cell: ChatAlbumCell): string => cell.index.toString()).join('-') + ':' + row.height.toFixed(2))
    }
  }
  build(): void {
    Column() {
      Stack() {
        if (this.layout.leading !== null) {
          Row({ space: this.layout.gap }) {
            ForEach([this.layout.leading], (cell: ChatAlbumCell) => { this.Tile(cell); },
              (cell: ChatAlbumCell): string => cell.width.toFixed(2) + ':' + cell.height.toFixed(2))
            this.Rows();
          }
        } else { this.Rows(); }
      }.width(this.layout.width).height(this.layout.height).borderRadius($r('app.float.chat_media_album_radius')).clip(true)
    }.width('100%').constraintSize({ maxWidth: $r('app.float.chat_media_max_width') }).alignItems(HorizontalAlign.End)
      .onAreaChange((_previous: Area, area: Area): void => {
        const width: number = Number(area.width);
        if (width > 0 && Math.abs(width - this.availableWidth) > 0.5) { this.availableWidth = width; this.resize(); }
      })
  }
}
