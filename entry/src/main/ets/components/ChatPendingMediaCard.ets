import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { image } from '@kit.ImageKit';
import { ChatPickedFile } from '../services/XChatMedia';
import { chatVideoPreview, ChatVideoPreview } from '../services/ChatLocalVideo';
import type { PhotoViewerRouteParam } from '../pages/PhotoViewer';
import { xChatService } from '../services/XChatService';

@Component
export struct ChatPendingMediaCard {
  @Consume('pageStack') pageStack: NavPathStack;
  @Prop conversationId: string = '';
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp('harmonyx.accent_color') accentColor: string = '#007DFF';
  file: ChatPickedFile = { uri: '', filename: '', type: 1 };
  @Prop progress: number = 0;
  @Prop failed: boolean = false;
  @Prop mediaWidth: number = 220;
  @Prop mediaHeight: number = 160;
  onDimensions: (width: number, height: number) => void = (_width: number, _height: number): void => {};
  @State private posterReady: boolean = false;
  private poster: image.PixelMap | undefined = undefined;
  private active: boolean = true;

  aboutToAppear(): void { this.active = true; if (this.file.type === 3) { this.preparePoster(); } }
  aboutToDisappear(): void {
    this.active = false;
    if (this.poster !== undefined) { this.poster.release().catch((): void => {}); this.poster = undefined; }
  }
  private async preparePoster(): Promise<void> {
    try {
      const preview: ChatVideoPreview = await chatVideoPreview(this.file.uri);
      if (!this.active) { preview.frame.release().catch((): void => {}); return; }
      this.poster = preview.frame; this.posterReady = true;
      this.onDimensions(preview.width, preview.height);
    } catch (error) { /* Keep the progress indicator usable when a video has no poster. */ }
  }
  private uploadProgress(): number { return Math.min(100, Math.max(0, this.progress)); }
  private shade(): number { return this.failed ? 0.35 : 0.58 * (1 - this.uploadProgress() / 100); }

  private openGif(): void {
    if (!this.active || this.file.type !== 2 || this.file.uri.length === 0 || !xChatService.isUnlocked()) { return; }
    const param: PhotoViewerRouteParam = { urls: [this.file.uri], index: 0, alt: '', transitionPrefix: '',
      screenBlocked: xChatService.conversationInfo(this.conversationId).screenBlocked };
    this.pageStack.pushPath({ name: 'PhotoViewer', param: param });
  }

  build(): void {
    Stack() {
      if (this.file.type === 1 || this.file.type === 2) {
        Image(this.file.uri).width('100%').height('100%').objectFit(ImageFit.Cover).draggable(false)
          .hitTestBehavior(HitTestMode.None)
          .onComplete((event): void => {
            if (event !== undefined && event.width > 0 && event.height > 0) { this.onDimensions(event.width, event.height); }
          })
      } else if (this.posterReady && this.poster !== undefined) {
        Image(this.poster).width('100%').height('100%').objectFit(ImageFit.Cover).hitTestBehavior(HitTestMode.None)
      } else {
        Column({ space: 8 }) {
          SymbolGlyph(this.file.type === 3 ? $r('sys.symbol.play_fill') : this.file.type === 4 ?
            $r('sys.symbol.waveform') : $r('sys.symbol.doc')).fontSize(30).fontColor([$r('app.color.text_secondary')])
          if (this.file.type >= 4) {
            Text(this.file.filename).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_primary')).maxLines(2)
          }
        }.width('100%').height('100%').justifyContent(FlexAlign.Center).backgroundColor($r('app.color.bg_secondary_btn'))
      }
      Column().width('100%').height('100%').backgroundColor($r('app.color.chat_media_upload_scrim'))
        .opacity(this.shade()).animation({ duration: 180, curve: Curve.EaseOut }).hitTestBehavior(HitTestMode.None)
      if (!this.failed) {
        // A single ResourceColor selects Gauge's native progress ring and translucent track.
        Gauge({ value: this.uploadProgress(), min: 0, max: 100 })
          .value(this.uploadProgress()).startAngle(0).endAngle(360)
          .width($r('app.float.chat_media_upload_ring_size')).height($r('app.float.chat_media_upload_ring_size'))
          .colors(this.accentColor).strokeWidth($r('app.float.chat_media_upload_ring_stroke'))
          .indicator(null).description(null).trackShadow(null)
          .accessibilityText($r('app.string.chat_media_sending')).hitTestBehavior(HitTestMode.None)
      }
    }.width(this.mediaWidth).height(this.mediaHeight).clip(true).renderGroup(true)
      .onClick((): void => this.openGif())
  }
}
