import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { common } from '@kit.AbilityKit';
import promptAction from '@ohos.promptAction';
import type { MediaAttachment } from '../models/Tweet';
import { chooseVideoDownloadUrl } from '../services/VideoDownloadChoice';
import {
  MEDIA_DOWNLOAD_CANCELED,
  MEDIA_DOWNLOAD_SUCCESS,
  mediaDownloadService
} from '../services/MediaDownloadService';
import { MaterialButton } from './MaterialButton';

@Component
export struct MediaDownloadButton {
  @Prop url: string = '';
  @Prop mediaId: string = 'media';
  @Prop isVideo: boolean = false;
  @Prop videoMedia: MediaAttachment | null = null;
  @Prop buttonSize: number = 36;
  @State private downloading: boolean = false;
  @State private choosingQuality: boolean = false;

  private text(resource: Resource): string {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    return context.resourceManager.getStringSync(resource);
  }

  private async startDownload(): Promise<void> {
    if (this.downloading || this.choosingQuality || this.url.length === 0) {
      return;
    }
    let source: string = this.url;
    const mediaId: string = this.mediaId;
    const isVideo: boolean = this.isVideo;
    if (isVideo && this.videoMedia !== null) {
      this.choosingQuality = true;
      try {
        source = await chooseVideoDownloadUrl(this.getUIContext(), this.videoMedia);
      } finally {
        this.choosingQuality = false;
      }
      if (source.length === 0) {
        return;
      }
    }
    this.downloading = true;
    if (!isVideo) { promptAction.showToast({ message: this.text($r('app.string.media_download_started')), duration: 1600 }); }
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    mediaDownloadService.download(context, source, mediaId, isVideo, (result: number): void => {
      this.downloading = false;
      if (isVideo && result === MEDIA_DOWNLOAD_SUCCESS) { return; }
      if (result === MEDIA_DOWNLOAD_SUCCESS) {
        promptAction.showToast({
          message: this.text(isVideo ? $r('app.string.media_video_saved') :
            $r('app.string.media_image_saved')),
          duration: 2200
        });
      } else if (result === MEDIA_DOWNLOAD_CANCELED) {
        promptAction.showToast({ message: this.text($r('app.string.media_download_canceled')), duration: 1800 });
      } else {
        promptAction.showToast({ message: this.text($r('app.string.media_download_failed')), duration: 2400 });
      }
    });
  }

  build(): void {
    MaterialButton({
      buttonWidth: this.buttonSize,
      buttonHeight: this.buttonSize,
      buttonRadius: this.buttonSize / 2,
      surfaceColor: '#99000000',
      materialLevel: 1,
      applyShadow: true,
      lightColor: $r('app.color.brand'),
      buttonEnabled: !this.downloading && !this.choosingQuality && this.url.length > 0,
      buttonOpacity: this.url.length > 0 ? 1 : 0.45,
      accessibilityLabel: this.text($r('app.string.media_download')),
      buttonMonopolizeEvents: true,
      onButtonClick: (): void => { this.startDownload(); }
    }) {
      if (this.downloading) {
        LoadingProgress()
          .width(20)
          .height(20)
          .color($r('app.color.text_on_brand'))
      } else {
        SymbolGlyph($r('sys.symbol.download'))
          .fontSize(19)
          .fontColor([$r('app.color.text_on_brand')])
      }
    }
  }
}

@Component
export struct MediaDownloadAllButton {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Prop urls: string[] = [];
  @Prop mediaId: string = 'photos';
  @State private downloading: boolean = false;

  private text(resource: Resource): string {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    return context.resourceManager.getStringSync(resource);
  }

  private allButtonWidth(): number {
    const textWidth: number = this.getUIContext().getMeasureUtils().measureText({
      textContent: this.text($r('app.string.media_download_all_originals')),
      fontSize: $r('sys.float.Body_M'),
      fontWeight: FontWeight.Medium
    });
    return this.getUIContext().px2vp(textWidth) + 50;
  }

  private startDownload(): void {
    if (this.downloading || this.urls.length === 0) {
      return;
    }
    this.downloading = true;
    promptAction.showToast({ message: this.text($r('app.string.media_download_all_started')), duration: 1800 });
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    mediaDownloadService.downloadImages(context, this.urls, this.mediaId, (result: number): void => {
      this.downloading = false;
      if (result === MEDIA_DOWNLOAD_SUCCESS) {
        promptAction.showToast({ message: this.text($r('app.string.media_all_images_saved')), duration: 2200 });
      } else if (result === MEDIA_DOWNLOAD_CANCELED) {
        promptAction.showToast({ message: this.text($r('app.string.media_download_canceled')), duration: 1800 });
      } else {
        promptAction.showToast({ message: this.text($r('app.string.media_download_failed')), duration: 2400 });
      }
    });
  }

  build(): void {
    MaterialButton({
      buttonWidth: this.allButtonWidth(),
      buttonHeight: 36,
      buttonRadius: 18,
      surfaceColor: '#99000000',
      materialLevel: 1,
      applyShadow: true,
      lightColor: $r('app.color.brand'),
      buttonEnabled: !this.downloading && this.urls.length > 0,
      buttonOpacity: this.urls.length > 0 ? 1 : 0.45,
      accessibilityLabel: this.text($r('app.string.media_download_all_originals')),
      onButtonClick: (): void => this.startDownload()
    }) {
      Row({ space: 6 }) {
        if (this.downloading) {
          LoadingProgress()
            .width(18)
            .height(18)
            .color($r('app.color.text_on_brand'))
        } else {
          SymbolGlyph($r('sys.symbol.download'))
            .fontSize(18)
            .fontColor([$r('app.color.text_on_brand')])
        }
        Text($r('app.string.media_download_all_originals')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M'))
          .maxFontScale(1.4)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_on_brand'))
          .maxLines(1)
      }
      .height(36)
      .padding({ left: 12, right: 12 })
    }
  }
}
