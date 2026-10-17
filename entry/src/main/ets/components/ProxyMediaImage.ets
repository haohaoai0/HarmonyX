// Image renderer for post media. ArkUI's remote Image request does not inherit
// the HTTP proxy configured by the app, so the fallback is fetched and decoded
// in memory before its PixelMap is displayed.
import { image } from '@kit.ImageKit';
import { proxyImageResolver } from '../services/ProxyImageResolver';
import { proxyStore } from '../services/ProxyStore';

@Component
export struct ProxyMediaImage {
  @Prop @Watch('onUrlChanged') url: string = '';
  @Prop displayHeight: number = 228;
  @Prop contain: boolean = false;
  @Prop fillParent: boolean = false;
  @Prop @Watch('onViewerResolutionChanged') viewerResolution: boolean = false;
  onDimensions: (width: number, height: number) => void = (): void => {};
  // A sensitive-media cover uses the same proxy-aware image path as ordinary
  // media, but blurs the decoded preview before it reaches the card surface.
  @Prop blurRadius: number = 0;
  @Prop surfaceColor: ResourceColor = '';
  @State private source: string = '';
  @State private fallbackPixelMap: image.PixelMap | null = null;
  private alive: boolean = true;
  private requestSerial: number = 0;
  private retryTimer: number = -1;

  aboutToAppear(): void {
    this.alive = true;
    this.resolveSource();
  }

  aboutToDisappear(): void {
    this.alive = false;
    this.requestSerial += 1;
    this.clearRetryTimer();
    this.releaseFallback();
  }

  private onUrlChanged(): void {
    this.resolveSource();
  }

  private onViewerResolutionChanged(): void {
    if (!this.viewerResolution) { this.clearRetryTimer(); return; }
    if (this.fallbackPixelMap === null && this.source.length === 0) { this.resolveSource(); }
  }

  private resolveSource(): void {
    const sourceUrl: string = this.url;
    this.clearRetryTimer();
    this.requestSerial += 1;
    if (sourceUrl.length === 0) {
      this.releaseFallback();
      this.source = '';
      return;
    }
    // Picker/file URIs belong to the local image decoder. Sending them to the
    // HTTP proxy resolver leaves a selected cover stuck on its placeholder.
    if ((!sourceUrl.startsWith('https://') && !sourceUrl.startsWith('http://')) ||
      !proxyStore.snapshot().enabled) {
      this.releaseFallback();
      this.source = sourceUrl;
      return;
    }
    this.beginProxyFetch(sourceUrl);
  }

  // When a proxy is enabled this is the only image request: the resolver adds
  // the proxy at the HTTP layer and returns an in-memory PixelMap to ArkUI.
  private beginProxyFetch(sourceUrl: string, attempt: number = 0): void {
    const serial: number = this.requestSerial;
    const pending: Promise<image.PixelMap | null> = this.viewerResolution ?
      proxyImageResolver.loadForViewer(sourceUrl, true) : proxyImageResolver.load(sourceUrl);
    pending.then((pixelMap: image.PixelMap | null): void => {
      if (pixelMap === null) {
        this.retrySource(sourceUrl, serial, attempt);
        return;
      }
      if (!this.alive || serial !== this.requestSerial || sourceUrl !== this.url) {
        this.releasePixelMap(pixelMap);
        return;
      }
      const previous: image.PixelMap | null = this.fallbackPixelMap;
      this.fallbackPixelMap = pixelMap;
      this.source = '';
      if (previous !== null) { this.releasePixelMap(previous); }
    }).catch((): void => this.retrySource(sourceUrl, serial, attempt));
  }

  private retrySource(sourceUrl: string, serial: number, attempt: number): void {
    if (!this.alive || !this.viewerResolution || serial !== this.requestSerial || attempt >= 2) { return; }
    this.clearRetryTimer();
    this.retryTimer = setTimeout((): void => {
      this.retryTimer = -1;
      if (this.alive && this.viewerResolution && serial === this.requestSerial) {
        this.beginProxyFetch(sourceUrl, attempt + 1);
      }
    }, 1500 * (attempt + 1));
  }

  private clearRetryTimer(): void {
    if (this.retryTimer !== -1) { clearTimeout(this.retryTimer); this.retryTimer = -1; }
  }

  private onImageError(): void {
    if (this.alive && this.viewerResolution && this.source === this.url && this.url.length > 0) {
      this.beginProxyFetch(this.url);
    }
  }

  private imageDimensions(width: number, height: number): void {
    if (width > 0 && height > 0) { this.onDimensions(width, height); }
  }

  private releaseFallback(): void {
    const pixelMap: image.PixelMap | null = this.fallbackPixelMap;
    this.fallbackPixelMap = null;
    if (pixelMap !== null) {
      this.releasePixelMap(pixelMap);
    }
  }

  private releasePixelMap(pixelMap: image.PixelMap): void {
    proxyImageResolver.release(pixelMap);
  }

  build(): void {
    Stack() {
      if (this.fallbackPixelMap !== null) {
        Image(this.fallbackPixelMap)
          .width('100%')
          .height(this.fillParent ? '100%' : this.displayHeight)
          .objectFit(this.contain ? ImageFit.Contain : ImageFit.Cover)
          .draggable(false)
          .blur(this.blurRadius)
          .renderGroup(true)
          .onError((): void => this.onImageError())
          .onComplete((event): void => {
            if (event !== undefined) { this.imageDimensions(event.width, event.height); }
          })
      } else if (this.source.length > 0) {
        Image(this.source)
          .width('100%')
          .height(this.fillParent ? '100%' : this.displayHeight)
          .objectFit(this.contain ? ImageFit.Contain : ImageFit.Cover)
          .draggable(false)
          .blur(this.blurRadius)
          .renderGroup(true)
          .onError((): void => this.onImageError())
          .onComplete((event): void => {
            if (event !== undefined) { this.imageDimensions(event.width, event.height); }
          })
      }
    }
    .width('100%')
    .height(this.fillParent ? '100%' : this.displayHeight)
    .backgroundColor(this.surfaceColor)
  }
}
