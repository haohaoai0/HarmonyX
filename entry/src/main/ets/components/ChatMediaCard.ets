import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { common } from '@kit.AbilityKit';
import promptAction from '@ohos.promptAction';
import { connection } from '@kit.NetworkKit';
import { fileIo, picker, fileUri } from '@kit.CoreFileKit';
import { DmAttachment, MediaAttachment } from '../models/Tweet';
import { image } from '@kit.ImageKit';
import { chatVideoPreview, ChatVideoPreview } from '../services/ChatLocalVideo';
import { xChatMedia } from '../services/XChatMedia';
import { xChatActions } from '../services/XChatActions';
import { xChatService } from '../services/XChatService';
import { ChatVoicePlayer } from './ChatVoicePlayer';
import { MediaPhotoSurface } from './MediaPhotoSurface';
import { captureMediaViewerSource, pendingMediaViewerSource } from '../utils/MediaViewerMotion';

@Component
export struct ChatMediaCard {
  @Prop transitionSourceId: string = '';
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Prop attachment: DmAttachment;
  @Prop conversationId: string = '';
  @Prop keyVersion: string = '';
  @Prop outgoing: boolean = false;
  @Prop visible: boolean = true;
  @Prop mediaWidth: number = 220;
  @Prop mediaHeight: number = 160;
  @Prop albumTile: boolean = false;
  onPhotoOpen: (attachment: DmAttachment) => void = (_attachment: DmAttachment): void => {};
  onVideoOpen: (attachment: MediaAttachment) => void = (_attachment: MediaAttachment): void => {};
  onDimensions: (width: number, height: number) => void = (_width: number, _height: number): void => {};
  onLongPress: () => void = (): void => {};
  @StorageLink('harmonyx.accent_color') accentColor: string = '#007DFF';
  @State private path: string = '';
  @State private busy: boolean = false;
  @State private failed: boolean = false;
  @State private posterReady: boolean = false;
  private poster: image.PixelMap | undefined = undefined;
  private videoWidth: number = 0;
  private videoHeight: number = 0;
  private videoDurationMs: number = 0;
  private active: boolean = true;
  private context(): common.UIAbilityContext { return getContext(this) as common.UIAbilityContext; }
  aboutToAppear(): void { this.active = true; this.autoLoad(); }
  aboutToDisappear(): void {
    this.active = false;
    if (this.poster !== undefined) { this.poster.release().catch((): void => {}); this.poster = undefined; }
  }
  private async autoLoad(): Promise<void> {
    if (!this.active || !xChatService.isUnlocked() || this.attachment.mediaHash.length === 0) { return; }
    const cached: string = xChatMedia.cachedPath(this.context(), this.conversationId, this.attachment.mediaHash);
    if (cached.length > 0) { this.path = cached; await this.preparePoster(); return; }
    const key: string = this.attachment.mediaType === 3 ? 'download_videos' :
      this.attachment.mediaType === 5 ? 'download_documents' : 'download_photos';
    const policy: string = xChatActions.localString(this.context(), key, 'all');
    if (policy === 'never') { return; }
    if (policy === 'wifi') {
      try {
        const net: connection.NetHandle = await connection.getDefaultNet();
        const capabilities: connection.NetCapabilities = await connection.getNetCapabilities(net);
        if (capabilities.bearerTypes.indexOf(connection.NetBearType.BEARER_WIFI) < 0) { return; }
      } catch (error) { return; }
    }
    this.load();
  }
  private async load(): Promise<void> {
    if (this.busy || !xChatService.isUnlocked() || this.attachment.mediaHash.length === 0) { return; }
    this.busy = true; this.failed = false;
    try {
      const path: string = await xChatMedia.receive(this.context(), this.conversationId, this.attachment.mediaHash,
        this.keyVersion, this.attachment.mediaType);
      if (this.active) { this.path = path; await this.preparePoster(); }
    } catch (error) { if (this.active) { this.failed = true; } }
    finally { if (this.active) { this.busy = false; } }
  }
  private async preparePoster(): Promise<void> {
    if (this.attachment.mediaType !== 3 || this.poster !== undefined || this.path.length === 0) { return; }
    try {
      const preview: ChatVideoPreview = await chatVideoPreview(this.path);
      if (!this.active) { preview.frame.release().catch((): void => {}); return; }
      this.poster = preview.frame; this.posterReady = true;
      this.videoWidth = preview.width; this.videoHeight = preview.height; this.videoDurationMs = preview.durationMs;
      this.onDimensions(preview.width, preview.height);
    } catch (error) { /* A missing thumbnail does not prevent opening a playable video. */ }
  }
  private async open(): Promise<void> {
    if (this.path.length === 0) { await this.load(); }
    if (!this.active || !this.visible || !xChatService.isUnlocked() || this.path.length === 0) { return; }
    if (this.attachment.mediaType === 3) {
      const uri: string = fileUri.getUriFromPath(this.path);
      pendingMediaViewerSource.request(captureMediaViewerSource(this.getUIContext(), this.transitionSourceId,
        'chat-video-' + this.conversationId + '-' + this.attachment.mediaHash,
        this.videoWidth > 0 ? this.videoWidth : this.attachment.width,
        this.videoHeight > 0 ? this.videoHeight : this.attachment.height, false, this.albumTile ? 0 : 14));
      this.onVideoOpen({ id: 'chat-video-' + this.conversationId + '-' + this.attachment.mediaHash,
        type: 'video', mediaUrl: uri, feedUrl: uri, previewUrl: '',
        width: this.videoWidth > 0 ? this.videoWidth : this.attachment.width,
        height: this.videoHeight > 0 ? this.videoHeight : this.attachment.height,
        durationMs: this.videoDurationMs > 0 ? this.videoDurationMs : this.attachment.durationMs,
        altText: '' });
    } else { this.onPhotoOpen(this.attachment); }
  }

  @Builder
  private VisualMedia(): void {
    Stack() {
      if (this.path.length > 0 && this.attachment.mediaType !== 3) {
        if (this.transitionSourceId.length > 0) {
          MediaPhotoSurface({ sourceId: this.transitionSourceId, url: fileUri.getUriFromPath(this.path),
            displayHeight: this.mediaHeight, onDimensions: this.onDimensions })
            .width('100%').height('100%').hitTestBehavior(HitTestMode.None)
        } else {
        Image(fileUri.getUriFromPath(this.path)).width('100%').height('100%').objectFit(ImageFit.Cover)
          .draggable(false).hitTestBehavior(HitTestMode.None)
          .onComplete((event): void => {
            if (event !== undefined && event.width > 0 && event.height > 0) { this.onDimensions(event.width, event.height); }
          })
        }
      } else if (this.posterReady && this.poster !== undefined) {
        Image(this.poster).width('100%').height('100%').objectFit(ImageFit.Cover).hitTestBehavior(HitTestMode.None)
      } else {
        Column().width('100%').height('100%').backgroundColor($r('app.color.bg_secondary_btn'))
      }
      if (this.busy) {
        LoadingProgress().width(24).height(24).color(this.accentColor).hitTestBehavior(HitTestMode.None)
      } else if (this.failed || this.path.length === 0 || this.attachment.mediaType === 3) {
        SymbolGlyph(this.attachment.mediaType === 3 ? $r('sys.symbol.play_fill') : $r('sys.symbol.arrow_down'))
          .fontSize($r('sys.float.Title_L')).fontColor([$r('app.color.text_on_brand')])
          .backgroundColor($r('app.color.chat_media_play_scrim')).padding(12).borderRadius(24)
          .hitTestBehavior(HitTestMode.None)
      }
    }.width(this.mediaWidth).height(this.mediaHeight).borderRadius(this.albumTile ? 0 : $r('app.float.chat_bubble_radius')).clip(true)
      .id(this.transitionSourceId)
      .gesture(GestureGroup(GestureMode.Exclusive,
        LongPressGesture({ repeat: false, duration: 500 }).onAction((): void => { this.onLongPress(); }),
        TapGesture().onAction((): void => { this.open(); })
      ))
      .accessibilityText(this.attachment.mediaType === 3 ? $r('app.string.chat_video') : $r('app.string.chat_photos'))
  }
  private async save(): Promise<void> {
    if (this.path.length === 0) { await this.load(); }
    if (this.path.length === 0 || !this.active) { return; }
    try {
      const dialog: picker.DocumentViewPicker = new picker.DocumentViewPicker(this.context());
      const options: picker.DocumentSaveOptions = { newFileNames: [this.attachment.filename.length > 0 ? this.attachment.filename : 'attachment'] };
      const uris: string[] = await dialog.save(options);
      if (uris.length === 0) { return; }
      const file: fileIo.File = fileIo.openSync(uris[0], fileIo.OpenMode.READ_WRITE);
      try { fileIo.copyFileSync(this.path, file.fd); } finally { fileIo.closeSync(file.fd); }
    } catch (error) {
      promptAction.showToast({ message: this.context().resourceManager.getStringSync($r('app.string.chat_action_failed')) });
    }
  }
  build(): void {
    if (this.attachment.mediaType >= 1 && this.attachment.mediaType <= 3) {
      this.VisualMedia()
    } else {
    Column({ space: 8 }) {
      if (this.path.length > 0 && this.attachment.mediaType === 4) {
        ChatVoicePlayer({ path: this.path, durationMs: this.attachment.durationMs ?? 0, outgoing: this.outgoing,
          samples: xChatMedia.waveform(this.context(), this.conversationId, this.attachment.mediaHash), visible: this.visible })
      } else {
        Row({ space: 8 }) {
          SymbolGlyph(this.attachment.mediaType === 4 ? $r('sys.symbol.waveform') : $r('sys.symbol.doc'))
            .fontSize(24).fontColor([this.accentColor])
          Text(this.attachment.filename.length > 0 ? this.attachment.filename : $r('app.string.dm_attachment_message')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_primary')).maxLines(2).layoutWeight(1)
          if (this.busy) { LoadingProgress().width(20).height(20).color(this.accentColor) }
        }.width(220).padding(12).onClick((): void => { if (this.attachment.mediaType === 5) { this.save(); } else { this.load(); } })
      }
      if (this.failed) { Text($r('app.string.chat_retry')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S')).fontColor(this.accentColor).onClick((): void => { this.load(); }) }
    }.constraintSize({ maxWidth: this.attachment.mediaType === 4 ? 260 : 240 })
    }
  }
}
