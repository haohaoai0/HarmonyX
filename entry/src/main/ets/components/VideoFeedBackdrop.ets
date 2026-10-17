import { image } from '@kit.ImageKit';
import { effectKit } from '@kit.ArkGraphics2D';
import { common } from '@kit.AbilityKit';
import { videoPosterStore } from '../services/VideoPosterStore';
import { proxyImageResolver } from '../services/ProxyImageResolver';

@Component
export struct VideoFeedBackdrop {
  @Prop @Watch('onSourceChanged') mediaId: string = '';
  @Prop @Watch('onSourceChanged') previewUrl: string = '';
  @Prop @Watch('onSourceChanged') streamUrl: string = '';
  @Prop @Watch('onSourceChanged') rendition: string = 'full';
  @State private poster: image.PixelMap | null = null;
  @State private tintColor: ResourceColor = $r('app.color.video_feed_backdrop_start');
  private alive: boolean = true;
  private posterOwnedByView: boolean = false;
  private requestSerial: number = 0;
  private previewReady: boolean = false;
  private retryTimer: number = -1;
  private sourceTimer: number = -1;
  private fallbackTimer: number = -1;

  aboutToAppear(): void {
    this.alive = true;
    this.loadPoster();
  }

  aboutToDisappear(): void {
    this.alive = false;
    this.requestSerial += 1;
    this.clearTimers();
    this.clearPosterReference();
  }

  private onSourceChanged(): void {
    this.requestSerial += 1;
    this.clearTimers();
    this.sourceTimer = setTimeout((): void => {
      this.sourceTimer = -1;
      if (this.alive) { this.loadPoster(); }
    }, 0);
  }

  private loadPoster(): void {
    this.clearTimers();
    const serial: number = ++this.requestSerial;
    this.previewReady = false;
    if (this.mediaId.length === 0 && this.previewUrl.length === 0 && this.streamUrl.length === 0) {
      this.clearPosterReference();
      return;
    }
    const cached: image.PixelMap | null = videoPosterStore.cached(this.mediaId);
    if (cached !== null) {
      this.applyPoster(cached, false);
    }
    if (this.previewUrl.length > 0) {
      this.loadPreviewPoster(serial, this.previewUrl, 0);
      if (cached === null && this.streamUrl.length > 0) {
        this.fallbackTimer = setTimeout((): void => {
          this.fallbackTimer = -1;
          if (this.alive && serial === this.requestSerial && !this.previewReady) {
            this.loadStreamPoster(serial, 0);
          }
        }, 1500);
      }
    } else {
      this.loadStreamPoster(serial, 0);
    }
  }

  private loadPreviewPoster(serial: number, sourceUrl: string, attempt: number): void {
    proxyImageResolver.load(sourceUrl, true).then((frame: image.PixelMap | null): void => {
      if (!this.alive || serial !== this.requestSerial || sourceUrl !== this.previewUrl) {
        if (frame !== null) { proxyImageResolver.release(frame); }
        return;
      }
      if (frame === null) {
        this.onPreviewFailed(serial, sourceUrl, attempt);
        return;
      }
      this.previewReady = true;
      this.clearRetryTimer();
      this.clearFallbackTimer();
      this.applyPoster(frame, true);
    }).catch((): void => {
      if (this.alive && serial === this.requestSerial) {
        this.onPreviewFailed(serial, sourceUrl, attempt);
      }
    });
  }

  private onPreviewFailed(serial: number, sourceUrl: string, attempt: number): void {
    if (attempt === 0 && this.poster === null) {
      this.clearFallbackTimer();
      this.loadStreamPoster(serial, 0);
    }
    if (attempt < 2) {
      this.scheduleRetry(serial, (): void => this.loadPreviewPoster(serial, sourceUrl, attempt + 1),
        1500 * (attempt + 1));
    }
  }

  private loadStreamPoster(serial: number, attempt: number): void {
    if (!this.alive || this.previewReady || this.streamUrl.length === 0 || this.mediaId.length === 0) {
      return;
    }
    const cached: image.PixelMap | null = videoPosterStore.cached(this.mediaId);
    if (cached !== null) {
      this.applyPoster(cached, false);
      return;
    }
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    videoPosterStore.load(this.mediaId, this.streamUrl, context, this.rendition)
      .then((frame: image.PixelMap | null): void => {
        if (!this.alive || serial !== this.requestSerial || this.previewReady) { return; }
        if (frame !== null) {
          this.applyPoster(frame, false);
        } else if (attempt < 2) {
          this.clearFallbackTimer();
          this.fallbackTimer = setTimeout((): void => {
            this.fallbackTimer = -1;
            if (this.alive && serial === this.requestSerial && !this.previewReady) {
              this.loadStreamPoster(serial, attempt + 1);
            }
          }, 1500 * (attempt + 1));
        }
      });
  }

  private scheduleRetry(serial: number, action: () => void, delay: number): void {
    this.clearRetryTimer();
    this.retryTimer = setTimeout((): void => {
      this.retryTimer = -1;
      if (this.alive && serial === this.requestSerial) { action(); }
    }, delay);
  }

  private clearRetryTimer(): void {
    if (this.retryTimer !== -1) { clearTimeout(this.retryTimer); this.retryTimer = -1; }
  }

  private clearTimers(): void {
    this.clearRetryTimer();
    this.clearFallbackTimer();
    if (this.sourceTimer !== -1) { clearTimeout(this.sourceTimer); this.sourceTimer = -1; }
  }

  private clearFallbackTimer(): void {
    if (this.fallbackTimer !== -1) { clearTimeout(this.fallbackTimer); this.fallbackTimer = -1; }
  }

  private applyPoster(frame: image.PixelMap, ownedByView: boolean): void {
    const previous: image.PixelMap | null = this.poster;
    const previousOwned: boolean = this.posterOwnedByView;
    this.poster = frame;
    this.posterOwnedByView = ownedByView;
    if (previous !== null && previousOwned) { proxyImageResolver.release(previous); }
    effectKit.createColorPicker(frame).then((picker: effectKit.ColorPicker): void => {
      if (!this.alive || this.poster !== frame) {
        return;
      }
      const color: effectKit.Color | null = picker.getLargestProportionColor();
      if (color !== null) {
        this.tintColor = '#' + this.hex(color.alpha) + this.hex(color.red) +
          this.hex(color.green) + this.hex(color.blue);
      }
    }).catch((): void => {
    });
  }

  private releaseOwnedPoster(): void {
    if (!this.posterOwnedByView || this.poster === null) {
      return;
    }
    const owned: image.PixelMap = this.poster;
    this.poster = null;
    this.posterOwnedByView = false;
    proxyImageResolver.release(owned);
  }

  private clearPosterReference(): void {
    if (this.posterOwnedByView && this.poster !== null) {
      this.releaseOwnedPoster();
      return;
    }
    this.poster = null;
    this.posterOwnedByView = false;
  }

  private hex(value: number): string {
    const channel: number = Math.max(0, Math.min(255, Math.round(value)));
    return channel < 16 ? '0' + channel.toString(16) : channel.toString(16);
  }

  build(): void {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({ angle: 180, colors: [
          [this.tintColor, 0], [$r('app.color.video_feed_backdrop_end'), 1]
        ] })
      if (this.poster !== null) {
        Image(this.poster)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .blur(60)
          .scale({ x: 1.2, y: 1.2 })
          .renderGroup(true)
      } else if (this.previewUrl.length > 0) {
        Image(this.previewUrl)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .blur(60)
          .scale({ x: 1.2, y: 1.2 })
          .renderGroup(true)
      }
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.video_feed_backdrop_scrim'))
    }
    .width('100%')
    .height('100%')
    .clip(true)
    .backgroundColor($r('app.color.video_feed_backdrop_end'))
  }
}
