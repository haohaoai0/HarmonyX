// Animated GIF preview that keeps working with the app's configured proxy.
// A PixelMap decode keeps only one frame, so proxy-enabled sessions download
// the original GIF to cache and hand its URI to ArkUI's animated Image node.
import common from '@ohos.app.ability.common';
import hilog from '@ohos.hilog';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { proxyDownloadService } from '../services/ProxyDownloadService';
import { proxyImageResolver } from '../services/ProxyImageResolver';
import { proxyStore } from '../services/ProxyStore';

@Component
export struct GifPreviewImage {
  @Prop @Watch('onUrlChanged') url: string = '';
  @Prop @Watch('onUrlChanged') previewUrl: string = '';
  @Prop displayHeight: number = 228;
  @Prop surfaceColor: ResourceColor = '';
  @State private source: string = '';
  @State private previewSource: string = '';
  @State private previewPixelMap: image.PixelMap | null = null;
  private alive: boolean = true;
  private cachedGifPath: string = '';
  private previewRequestUrl: string = '';
  private gifRequestUrl: string = '';
  private sourceEpoch: number = 0;

  aboutToAppear(): void {
    this.alive = true;
    this.onUrlChanged();
  }

  aboutToDisappear(): void {
    this.alive = false;
    this.sourceEpoch += 1;
    this.removeCachedGif();
    this.releasePreview();
  }

  private onUrlChanged(): void {
    this.sourceEpoch += 1;
    this.source = '';
    this.removeCachedGif();
    this.previewSource = '';
    this.previewRequestUrl = '';
    this.gifRequestUrl = '';
    this.releasePreview();
    this.resolveSource();
  }

  private resolveSource(): void {
    const gifUrl: string = this.url;
    const thumbnailUrl: string = this.previewUrl;
    const proxyEnabled: boolean = proxyStore.snapshot().enabled;
    if (thumbnailUrl.length > 0 && thumbnailUrl !== gifUrl) {
      if (proxyEnabled || gifUrl.length === 0) {
        this.beginProxyPreview(thumbnailUrl);
      } else {
        this.previewSource = thumbnailUrl;
      }
    }
    // A post whose animation is unavailable still has a useful thumbnail.
    // Resolve it even when no animated source is provided.
    if (gifUrl.length === 0) {
      return;
    }
    if (!proxyEnabled) {
      // ArkUI Image handles GIF frame playback for URL sources; do not decode
      // this URL into a PixelMap because that would freeze it on one frame.
      this.source = gifUrl;
      return;
    }
    this.downloadForProxy(gifUrl);
  }

  private beginProxyPreview(thumbnailUrl: string): void {
    if (thumbnailUrl.length === 0 || this.previewRequestUrl === thumbnailUrl) {
      return;
    }
    this.previewRequestUrl = thumbnailUrl;
    const epoch: number = this.sourceEpoch;
    proxyImageResolver.load(thumbnailUrl, true).then((pixelMap: image.PixelMap | null): void => {
      hilog.info(0xFF00, 'HarmonyX-GifPreview',
        'thumbnail result pixels=%{public}s alive=%{public}s epoch=%{public}d current=%{public}d',
        String(pixelMap !== null), String(this.alive), epoch, this.sourceEpoch);
      if (pixelMap === null) {
        return;
      }
      const currentPreviewUrl: string = this.previewUrl.length > 0 ? this.previewUrl : this.url;
      hilog.info(0xFF00, 'HarmonyX-GifPreview', 'thumbnail source current=%{public}s',
        String(currentPreviewUrl === thumbnailUrl));
      if (!this.alive || epoch !== this.sourceEpoch || currentPreviewUrl !== thumbnailUrl) {
        proxyImageResolver.release(pixelMap);
        return;
      }
      this.previewPixelMap = pixelMap;
    });
  }

  private async downloadForProxy(gifUrl: string): Promise<void> {
    if (gifUrl.length === 0 || this.gifRequestUrl === gifUrl) {
      return;
    }
    this.gifRequestUrl = gifUrl;
    const epoch: number = this.sourceEpoch;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const suffix: string = Math.floor(Math.random() * 1000000).toString();
    const filePath: string = context.cacheDir + '/harmonyx-gif-preview-' + Date.now().toString() +
      '-' + suffix + '.gif';
    const downloaded: boolean = await proxyDownloadService.downloadWithRetry(gifUrl, filePath, 2);
    if (!this.alive || epoch !== this.sourceEpoch || this.url !== gifUrl) {
      if (downloaded) {
        this.unlink(filePath);
      }
      return;
    }
    if (!downloaded) {
      return;
    }
    this.cachedGifPath = filePath;
    this.source = fileUri.getUriFromPath(filePath);
  }

  private onPreviewLoadFailed(): void {
    this.previewSource = '';
    this.beginProxyPreview(this.previewUrl);
  }

  private onGifLoadFailed(): void {
    this.source = '';
    this.beginProxyPreview(this.previewUrl.length > 0 ? this.previewUrl : this.url);
    this.downloadForProxy(this.url);
  }

  private removeCachedGif(): void {
    const path: string = this.cachedGifPath;
    this.cachedGifPath = '';
    if (path.length > 0) {
      this.unlink(path);
    }
  }

  private releasePreview(): void {
    const pixelMap: image.PixelMap | null = this.previewPixelMap;
    this.previewPixelMap = null;
    if (pixelMap !== null) {
      proxyImageResolver.release(pixelMap);
    }
  }

  private unlink(path: string): void {
    try {
      fileIo.unlinkSync(path);
    } catch (error) {
      // The image may already have been removed by the cache or failed download.
    }
  }

  build(): void {
    Stack() {
      if (this.previewPixelMap !== null) {
        Image(this.previewPixelMap)
          .width('100%')
          .height(this.displayHeight)
          .objectFit(ImageFit.Cover)
          .draggable(false)
          .renderGroup(true)
      } else if (this.previewSource.length > 0) {
        Image(this.previewSource)
          .width('100%')
          .height(this.displayHeight)
          .objectFit(ImageFit.Cover)
          .draggable(false)
          .renderGroup(true)
          .onError((): void => { this.onPreviewLoadFailed(); })
      }
      if (this.source.length > 0) {
        Image(this.source)
          .width('100%')
          .height(this.displayHeight)
          .objectFit(ImageFit.Cover)
          .draggable(false)
          .renderGroup(true)
          .onError((): void => { this.onGifLoadFailed(); })
      }
    }
    .width('100%')
    .height(this.displayHeight)
    .backgroundColor(this.surfaceColor)
  }
}
