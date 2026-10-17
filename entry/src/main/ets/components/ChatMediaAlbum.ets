import { common } from '@kit.AbilityKit';
import { fileUri } from '@kit.CoreFileKit';
import promptAction from '@ohos.promptAction';
import { DmAttachment, MediaAttachment } from '../models/Tweet';
import { ChatMediaItem, ChatMovingPhotoProtocol } from '../utils/ChatMovingPhotoProtocol';
import { ChatAlbumCell, ChatAlbumGeometry, ChatAlbumRow, ChatAlbumSize, chatAlbumLayout } from '../utils/ChatAlbumLayout';
import { PhotoViewerPhoto } from '../utils/PhotoViewerRequest';
import { PhotoViewerRouteParam } from '../pages/PhotoViewer';
import { captureMediaViewerSource, createMediaSourcePrefix } from '../utils/MediaViewerMotion';
import { xChatMedia } from '../services/XChatMedia';
import { xChatService } from '../services/XChatService';
import { ChatMediaCard } from './ChatMediaCard';
import { ChatMovingPhotoCard } from './ChatMovingPhotoCard';

@Component
export struct ChatMediaAlbum {
  private mediaSourcePrefix: string = createMediaSourcePrefix();
  @Consume('pageStack') pageStack: NavPathStack;
  @Prop attachments: DmAttachment[] = [];
  @Prop conversationId: string = '';
  @Prop keyVersion: string = '';
  @Prop visible: boolean = true;
  @Prop outgoing: boolean = false;
  onVideoOpen: (media: MediaAttachment) => void = (_media: MediaAttachment): void => {};
  onLongPress: () => void = (): void => {};
  @StorageProp('harmonyx.window_height') @Watch('resize') windowHeight: number = 0;
  private availableWidth: number = 0;
  private sizes: ChatAlbumSize[] = [];
  @State private layout: ChatAlbumGeometry = new ChatAlbumGeometry();
  @State private opening: boolean = false;
  private active: boolean = true;

  private context(): common.UIAbilityContext { return this.getUIContext().getHostContext() as common.UIAbilityContext; }
  private items(): ChatMediaItem[] {
    return ChatMovingPhotoProtocol.group(this.attachments).filter((item: ChatMediaItem): boolean =>
      item.attachment.type === 'Media' && item.attachment.mediaType >= 1 && item.attachment.mediaType <= 3);
  }
  aboutToAppear(): void {
    this.active = true;
    this.sizes = this.items().map((item: ChatMediaItem): ChatAlbumSize =>
      ({ width: item.attachment.width, height: item.attachment.height }));
    this.resize();
  }
  aboutToDisappear(): void { this.active = false; }
  private measured(index: number, width: number, height: number): void {
    if (!this.active || !Number.isFinite(width) || !Number.isFinite(height) || width <= 0 || height <= 0 || index >= this.sizes.length) { return; }
    if (this.sizes[index].width === width && this.sizes[index].height === height) { return; }
    this.sizes = this.sizes.map((size: ChatAlbumSize, i: number): ChatAlbumSize =>
      i === index ? { width: width, height: height } : size);
    this.resize();
  }
  private dimension(resource: Resource): number {
    return this.getUIContext().px2vp(this.context().resourceManager.getNumber(resource.id));
  }
  private resize(): void {
    if (!this.active) { return; }
    const fallback: number = this.dimension($r('app.float.chat_media_default_width'));
    const single: boolean = this.sizes.length === 1;
    const maxWidth: number = this.dimension(single ?
      $r('app.float.chat_media_single_max_width') : $r('app.float.chat_media_max_width'));
    const cap: number = this.dimension(single ?
      $r('app.float.chat_media_single_max_height') : $r('app.float.chat_media_max_height'));
    const gap: number = this.dimension($r('app.float.chat_media_album_gap'));
    this.layout = chatAlbumLayout(this.sizes, Math.min(maxWidth, this.availableWidth > 0 ? this.availableWidth : fallback),
      this.windowHeight > 0 ? Math.min(cap, this.windowHeight * 0.38) : cap, gap);
  }
  private async openPhotos(selected: DmAttachment): Promise<void> {
    if (this.opening || !this.active || !this.visible || !xChatService.isUnlocked()) { return; }
    this.opening = true;
    try {
      const photos: DmAttachment[] = this.items().map((item: ChatMediaItem): DmAttachment => item.attachment)
        .filter((attachment: DmAttachment): boolean => attachment.mediaType === 1 || attachment.mediaType === 2);
      const items: PhotoViewerPhoto[] = [];
      let index: number = -1;
      for (let i: number = 0; i < photos.length; i++) {
        const attachment: DmAttachment = photos[i];
        let path: string = '';
        try {
          path = await xChatMedia.receive(this.context(), this.conversationId,
            attachment.mediaHash, this.keyVersion, attachment.mediaType);
        } catch (error) {
          if (attachment.mediaHash === selected.mediaHash) { throw error as Error; }
          continue;
        }
        if (!this.active || !this.visible || !xChatService.isUnlocked()) { return; }
        if (attachment.mediaHash === selected.mediaHash) { index = items.length; }
        const uri: string = fileUri.getUriFromPath(path);
        const mediaIndex: number = this.items().findIndex((item: ChatMediaItem): boolean =>
          item.attachment.mediaHash === attachment.mediaHash);
        const size: ChatAlbumSize | undefined = this.sizes[mediaIndex];
        items.push(new PhotoViewerPhoto(uri, uri, size?.width ?? attachment.width, size?.height ?? attachment.height, i, '',
          this.mediaSourcePrefix + attachment.mediaHash));
      }
      if (index < 0) { return; }
      const param: PhotoViewerRouteParam = { items: items, urls: items.map((item: PhotoViewerPhoto): string => item.previewUrl),
        source: captureMediaViewerSource(this.getUIContext(), this.mediaSourcePrefix + selected.mediaHash,
          selected.mediaHash, items[index].width, items[index].height, false, 0),
        index: index, alt: '', transitionPrefix: '',
        screenBlocked: xChatService.conversationInfo(this.conversationId).screenBlocked };
      this.pageStack.pushPath({ name: 'PhotoViewer', param: param }, param.source === undefined);
    } catch (error) {
      if (this.active) { promptAction.showToast({ message: this.context().resourceManager.getStringSync($r('app.string.chat_action_failed')) }); }
    }
    finally { if (this.active) { this.opening = false; } }
  }

  @Builder
  private Tile(cell: ChatAlbumCell): void {
    if (this.items()[cell.index].video !== undefined) {
      ChatMovingPhotoCard({ attachment: this.items()[cell.index].attachment, video: this.items()[cell.index].video,
        conversationId: this.conversationId, keyVersion: this.keyVersion, visible: this.visible,
        compact: cell.width < 150, tileWidth: cell.width, tileHeight: cell.height,
        onLongPress: this.onLongPress,
        onDimensions: (width: number, height: number): void => { this.measured(cell.index, width, height); } })
    } else {
      ChatMediaCard({ attachment: this.items()[cell.index].attachment, conversationId: this.conversationId,
        transitionSourceId: this.mediaSourcePrefix + this.items()[cell.index].attachment.mediaHash,
        keyVersion: this.keyVersion, outgoing: this.outgoing, visible: this.visible,
        mediaWidth: cell.width, mediaHeight: cell.height, albumTile: true,
        onPhotoOpen: (attachment: DmAttachment): void => { this.openPhotos(attachment); },
        onVideoOpen: this.onVideoOpen,
        onLongPress: this.onLongPress,
        onDimensions: (width: number, height: number): void => { this.measured(cell.index, width, height); } })
    }
  }
  @Builder
  private Rows(): void {
    Column({ space: this.layout.gap }) {
      ForEach(this.layout.rows, (row: ChatAlbumRow) => {
        Row({ space: this.layout.gap }) {
          ForEach(row.cells, (cell: ChatAlbumCell) => { this.Tile(cell); },
            (cell: ChatAlbumCell): string => this.items()[cell.index].attachment.mediaHash + ':' +
              cell.width.toFixed(2) + ':' + cell.height.toFixed(2))
        }.height(row.height)
      }, (row: ChatAlbumRow): string => row.cells.map((cell: ChatAlbumCell): string => cell.index.toString()).join('-') +
        ':' + row.height.toFixed(2))
    }
  }
  @Builder
  private Album(): void {
    Stack() {
      if (this.layout.leading !== null) {
        Row({ space: this.layout.gap }) {
          ForEach([this.layout.leading], (cell: ChatAlbumCell) => { this.Tile(cell); },
            (cell: ChatAlbumCell): string => cell.width.toFixed(2) + ':' + cell.height.toFixed(2))
          this.Rows();
        }
      } else { this.Rows(); }
      if (this.opening) { LoadingProgress().width(24).height(24).hitTestBehavior(HitTestMode.None) }
    }.width(this.layout.width).height(this.layout.height).borderRadius($r('app.float.chat_media_album_radius')).clip(true)
  }
  build(): void {
    Column() { this.Album(); }
      .width('100%').constraintSize({ maxWidth: $r('app.float.chat_media_max_width') })
      .alignItems(this.outgoing ? HorizontalAlign.End : HorizontalAlign.Start)
      .onAreaChange((_previous: Area, area: Area): void => {
        const width: number = Number(area.width);
        if (width > 0 && Math.abs(width - this.availableWidth) > 0.5) { this.availableWidth = width; this.resize(); }
      })
  }
}
