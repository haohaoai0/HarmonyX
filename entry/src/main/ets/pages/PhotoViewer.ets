import { KeyCode } from '@kit.InputKit';
import { backInputKey, plainInputKey, contextInputMouse } from '../utils/InputSupport';
import { DesktopLayout } from '../utils/DesktopLayout';
import { motionDuration, motionCurve } from '../utils/AppMotion';
import { menuActionVisible } from '../models/MenuActionCatalog';
import { STORAGE_KEY_HIDDEN_MENU_ACTIONS } from '../services/MenuSettingsStore';
import { STORAGE_KEY_PAGE_TRANSITION_MODE, DEFAULT_PAGE_TRANSITION_MODE } from '../services/PageTransitionSettingsStore';
import { pageSystemTransition } from '../utils/PageTransition';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { DEFAULT_SHEET_MATERIAL_ENABLED, DEFAULT_SHEET_MATERIAL_LEVEL, STORAGE_KEY_SHEET_MATERIAL_ENABLED, STORAGE_KEY_SHEET_MATERIAL_LEVEL } from '../services/SheetMaterialSettingsStore';
import { sheetMaterialActive, sheetMaterialOptions, sheetUsesCenteredPresentation } from '../utils/SheetMaterial';
// Full-screen photo viewer: swipe between photos, pinch or double-tap to zoom,
// tap to hide controls, and drag down or use Back to return to the post.
import { HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { common } from '@kit.AbilityKit';
import { curves } from '@kit.ArkUI';
import { MediaViewerMotion, MediaViewerMotionFrame } from '../components/MediaViewerMotion';
import { MediaPhotoNode, MediaPhotoSession, mediaPhotoNodeFor } from '../components/MediaPhotoSurface';
import { captureMediaViewerSource, createMediaSourcePrefix, measureMediaViewerGeometry,
  MediaViewerGeometry, MediaViewerMotionState, MediaViewerSource } from '../utils/MediaViewerMotion';
import { STORAGE_KEY_PHOTO_FULLSCREEN } from '../services/InteractionSettingsStore';
import { STORAGE_KEY_DESKTOP_LAYOUT } from '../services/LayoutSettingsStore';
import { MaterialButton } from '../components/MaterialButton';
import { PhotoViewerAuthorBar } from '../components/PhotoViewerAuthorBar';
import { SurfaceVideoPlayer } from '../components/PostMedia';
import { gifVideoDownloadUrl } from '../services/GifDownloadChoice';
import { GifPreviewImage } from '../components/GifPreviewImage';
import type { UserDetailRouteParam } from './UserDetail';
import { SystemMaterialUtil } from '../utils/SystemMaterial';
import { pasteboard } from '@kit.BasicServicesKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { textRecognition, subjectSegmentation } from '@kit.CoreVisionKit';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';
import { MediaViewerPostActions } from '../components/MediaViewerPostActions';
import { PostDetail } from './PostDetail';
import type { MediaAttachment, Tweet } from '../models/Tweet';
import { mediaDownloadService, MEDIA_DOWNLOAD_SUCCESS, MEDIA_DOWNLOAD_CANCELED,
  MEDIA_DOWNLOAD_SAVED_AS_VIDEO } from '../services/MediaDownloadService';
import promptAction from '@ohos.promptAction';
import { openExternalLink, requestSearch } from '../utils/PostEntities';
import { postShareUrl } from '../utils/SharePost';
import { pageSurfaceColor } from '../utils/ThemeColors';
import type { ReplyComposerRouteParam } from '../components/ReplyComposer';
import { IMAGE_QUALITY_ORIGINAL, imageUrlForQuality, STORAGE_KEY_MEDIA_VIEWER_BLACK_BACKGROUND } from '../services/MediaSettingsStore';
import { image } from '@kit.ImageKit';
import { proxyImageResolver } from '../services/ProxyImageResolver';
import { proxyStore } from '../services/ProxyStore';
import { setChatWindowPrivacy } from '../utils/ChatWindowPrivacy';
import { backgroundImageStore } from '../services/BackgroundImageStore';
import {
  PhotoViewerPhoto,
  STORAGE_KEY_PHOTO_RETURN
} from '../utils/PhotoViewerRequest';

export interface PhotoViewerRouteParam {
  source?: MediaViewerSource;
  urls: string[];
  items?: PhotoViewerPhoto[];
  index: number;
  alt: string;
  transitionPrefix: string;
  screenBlocked?: boolean;
  windowOverlay?: boolean;
  tweet?: Tweet | null;
  onLike?: (post: Tweet, liked: boolean) => Promise<boolean>;
  onRepost?: (post: Tweet, reposted: boolean) => Promise<boolean>;
  onReply?: (post: Tweet) => void;
  onGifSelect?: (index: number) => Promise<void>;
}

class PhotoOcrEntry {
  text: string;
  position: string;

  constructor(text: string, position: string) {
    this.text = text;
    this.position = position;
  }
}

@Builder
export function PhotoViewerBuilder(): void {
  PhotoViewer();
}

@Component
struct PhotoViewerBackdrop {
  @Prop @Watch('onUrlChanged') url: string;
  @Prop backdropOpacity: number = 1;
  @State private pixelMap: image.PixelMap | null = null;
  private alive: boolean = true;
  private requestSerial: number = 0;
  private retryTimer: number = -1;

  aboutToAppear(): void {
    this.alive = true;
    this.loadSource();
  }

  aboutToDisappear(): void {
    this.alive = false;
    this.requestSerial += 1;
    this.clearRetryTimer();
    this.releasePixelMap();
  }

  private onUrlChanged(): void {
    this.loadSource();
  }

  private releasePixelMap(): void {
    const current: image.PixelMap | null = this.pixelMap;
    this.pixelMap = null;
    if (current !== null) {
      proxyImageResolver.release(current);
    }
  }

  private loadSource(): void {
    this.clearRetryTimer();
    const sourceUrl: string = this.url;
    const serial: number = this.requestSerial + 1;
    this.requestSerial = serial;
    if (sourceUrl.length === 0) {
      this.releasePixelMap();
      return;
    }
    this.loadImage(sourceUrl, serial, 0);
  }

  private loadImage(sourceUrl: string, serial: number, attempt: number): void {
    proxyImageResolver.loadForViewer(sourceUrl, true).then((pixelMap: image.PixelMap | null): void => {
      if (!this.alive || serial !== this.requestSerial || sourceUrl !== this.url) {
        if (pixelMap !== null) { proxyImageResolver.release(pixelMap); }
        return;
      }
      if (pixelMap === null) {
        this.retryImage(sourceUrl, serial, attempt);
        return;
      }
      const previous: image.PixelMap | null = this.pixelMap;
      this.pixelMap = pixelMap;
      if (previous !== null) { proxyImageResolver.release(previous); }
    }).catch((): void => {
      if (this.alive && serial === this.requestSerial) { this.retryImage(sourceUrl, serial, attempt); }
    });
  }

  private retryImage(sourceUrl: string, serial: number, attempt: number): void {
    if (attempt >= 2) { return; }
    this.clearRetryTimer();
    this.retryTimer = setTimeout((): void => {
      this.retryTimer = -1;
      if (this.alive && serial === this.requestSerial) { this.loadImage(sourceUrl, serial, attempt + 1); }
    }, 1500 * (attempt + 1));
  }

  private clearRetryTimer(): void {
    if (this.retryTimer !== -1) { clearTimeout(this.retryTimer); this.retryTimer = -1; }
  }

  @Builder
  private BackdropImage(): void {
    if (this.pixelMap !== null) {
      Image(this.pixelMap)
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
        .blur(60)
        .scale({ x: 1.2, y: 1.2 })
        .opacity(this.backdropOpacity)
        .renderGroup(true)
    } else {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Black)
        .opacity(this.backdropOpacity)
    }
  }

  build(): void {
    Stack() {
      this.BackdropImage()
    }
    .width('100%')
    .height('100%')
    .clip(true)
      .transition(TransitionEffect.OPACITY.animation({
        duration: motionDuration(220),
        curve: Curve.EaseOut
      }))
  }
}

@Component
struct ZoomablePhoto {
  @Prop sourceId: string = '';
  @Prop gifMedia: MediaAttachment | null = null;
  @Prop playbackEnabled: boolean = true;
  @Prop @Watch('onPresentationReady') presentImage: boolean = true;
  @State private sharedPhoto: MediaPhotoNode | null = null;
  private sharedOwner: string = '';
  onTransformChanged: (scale: number, x: number, y: number) => void = (): void => {};
  onImageReady: () => void = (): void => {};
  canAdoptNode: () => boolean = (): boolean => true;
  onAdoptNode: (node: MediaPhotoNode, owner: string, url: string) => boolean = (): boolean => false;
  @Prop @Watch('onUrlChanged') url: string;
  @Prop alt: string;
  @Prop photoWidth: number = 0;
  @Prop photoHeight: number = 0;
  @Prop @Watch('onClosingChanged') closing: boolean = false;
  onZoomChanged: (zoomed: boolean) => void = (): void => {
  };
  onZoomStart: () => void = (): void => {
  };
  onSingleTap: () => void = (): void => {
  };
  onLongPress: (url: string) => void = (_url: string): void => {
  };
  onDismissDrag: (progress: number) => void = (): void => {
  };
  onDismiss: () => void = (): void => {
  };
  // Not named "scale": that collides with the built-in component attribute.
  @State @Watch('reportTransform') private zoomScale: number = 1;
  @State @Watch('reportTransform') private offsetX: number = 0;
  @State @Watch('reportTransform') private offsetY: number = 0;
  @State @Watch('reportTransform') private dismissY: number = 0;
  @State private viewportWidth: number = 360;
  @State private viewportHeight: number = 720;
  @State private loading: boolean = true;
  @State private loadFailed: boolean = false;
  @State private source: string = '';
  @State private fallbackPixelMap: image.PixelMap | null = null;
  private alive: boolean = true;
  private requestSerial: number = 0;
  private retryTimer: number = -1;
  private panStartX: number = 0;
  private panStartY: number = 0;
  private pinchStartScale: number = 1;
  private pinchStartX: number = 0;
  private pinchStartY: number = 0;
  private pinchCenterStartX: number = 0;
  private pinchCenterStartY: number = 0;
  private pinching: boolean = false;
  private panInterrupted: boolean = false;
  private reportedZoomed: boolean = false;
  private decodedWidth: number = 0;
  private decodedHeight: number = 0;

  aboutToAppear(): void {
    this.alive = true;
    this.sharedPhoto = null;
    // Animations retain their encoded source; adopting or decoding a photo node
    // would replace the animation with a single static frame.
    if (this.gifMedia !== null) { return; }
    if (!this.canAdoptNode()) { return; }
    if (this.sourceId.length > 0) {
      const node: MediaPhotoNode | undefined = mediaPhotoNodeFor(this.sourceId);
      this.sharedOwner = createMediaSourcePrefix();
      if (node !== undefined && node.width > 0 && node.height > 0) {
        this.sharedPhoto = node;
        if (!this.presentImage) { return; }
        if (this.onAdoptNode(node, this.sharedOwner, this.url)) { return; }
        this.sharedPhoto = null;
      }
    }
    this.resolveSource();
  }

  aboutToDisappear(): void {
    this.alive = false;
    this.requestSerial += 1;
    this.clearRetryTimer();
    this.releaseFallback();
    this.sharedPhoto?.restore(this.getUIContext(), this.sharedOwner);
  }

  private onUrlChanged(): void {
    if (this.gifMedia !== null) { return; }
    if (!this.alive || !this.canAdoptNode()) { return; }
    if (this.sharedPhoto !== null) {
      if (!this.presentImage || this.onAdoptNode(this.sharedPhoto, this.sharedOwner, this.url)) { return; }
      this.sharedPhoto = null;
    }
    this.resolveSource();
  }

  private onPresentationReady(): void {
    // Keep the live image in the card until the overlay has committed that
    // exact card frame. Moving it during onAppear would leave a blank frame
    // while the destination is still measuring its full-size viewport.
    if (!this.alive || !this.presentImage || !this.canAdoptNode()) { return; }
    if (this.sharedPhoto === null) { this.resolveSource(); return; }
    if (!this.onAdoptNode(this.sharedPhoto, this.sharedOwner, this.url)) {
      this.sharedPhoto = null;
      this.resolveSource();
      return;
    }
  }

  private reportTransform(): void {
    this.onTransformChanged(this.zoomScale, this.offsetX, this.offsetY + this.dismissY);
  }

  private resolveSource(): void {
    if (this.gifMedia !== null) { return; }
    this.clearRetryTimer();
    this.loading = true;
    this.loadFailed = false;
    const serial: number = ++this.requestSerial;
    const sourceUrl: string = this.url;
    if (sourceUrl.length === 0) {
      this.releaseFallback();
      this.source = '';
      return;
    }
    if (sourceUrl.startsWith('file://')) {
      this.releaseFallback();
      this.source = sourceUrl;
      return;
    }
    // Retain the displayed preview while the original is being decoded.
    if (!proxyStore.snapshot().enabled) {
      this.releaseFallback();
      this.source = sourceUrl;
      return;
    }
    this.beginProxyFetch(sourceUrl, serial, 0);
  }

  private onImageError(): void {
    if (this.alive && this.source === this.url && this.fallbackPixelMap === null && this.url.length > 0) {
      this.loading = true;
      this.beginProxyFetch(this.url, this.requestSerial, 0);
    }
  }

  private beginProxyFetch(sourceUrl: string, serial: number, attempt: number): void {
    proxyImageResolver.loadForViewer(sourceUrl, true).then((pixelMap: image.PixelMap | null): void => {
      if (!this.alive || serial !== this.requestSerial || sourceUrl !== this.url) {
        if (pixelMap !== null) { this.releasePixelMap(pixelMap); }
        return;
      }
      if (pixelMap === null) {
        this.retrySource(sourceUrl, serial, attempt);
        return;
      }
      const previous: image.PixelMap | null = this.fallbackPixelMap;
      this.fallbackPixelMap = pixelMap;
      this.loading = false;
      this.loadFailed = false;
      if (previous !== null) { this.releasePixelMap(previous); }
    }).catch((): void => {
      if (this.alive && serial === this.requestSerial) { this.retrySource(sourceUrl, serial, attempt); }
    });
  }

  private retrySource(sourceUrl: string, serial: number, attempt: number): void {
    if (attempt >= 2) {
      this.loading = false; this.loadFailed = true; this.onImageReady(); return;
    }
    this.clearRetryTimer();
    this.retryTimer = setTimeout((): void => {
      this.retryTimer = -1;
      if (this.alive && serial === this.requestSerial) {
        this.beginProxyFetch(sourceUrl, serial, attempt + 1);
      }
    }, 1500 * (attempt + 1));
  }

  private clearRetryTimer(): void {
    if (this.retryTimer !== -1) { clearTimeout(this.retryTimer); this.retryTimer = -1; }
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

  private clampScale(value: number): number {
    if (value < 1) {
      return 1;
    }
    if (value > 4) {
      return 4;
    }
    return value;
  }

  private reset(): void {
    this.pinching = false;
    this.panInterrupted = false;
    this.zoomScale = 1;
    this.offsetX = 0;
    this.offsetY = 0;
    this.dismissY = 0;
    this.reportZoom(false);
    this.onDismissDrag(0);
  }

  private reportZoom(zoomed: boolean): void {
    if (this.reportedZoomed === zoomed) { return; }
    this.reportedZoomed = zoomed;
    this.onZoomChanged(zoomed);
  }

  private onClosingChanged(): void {
    if (!this.closing) {
      return;
    }
    this.getUIContext().animateTo({ duration: motionDuration(130), curve: Curve.EaseOut }, (): void => {
      this.reset();
    });
  }

  private fittedWidth(): number {
    const width: number = this.photoWidth > 0 ? this.photoWidth : this.decodedWidth;
    const height: number = this.photoHeight > 0 ? this.photoHeight : this.decodedHeight;
    if (width <= 0 || height <= 0) {
      return this.viewportWidth;
    }
    const fit: number = Math.min(this.viewportWidth / width, this.viewportHeight / height);
    return width * fit;
  }

  private fittedHeight(): number {
    const width: number = this.photoWidth > 0 ? this.photoWidth : this.decodedWidth;
    const height: number = this.photoHeight > 0 ? this.photoHeight : this.decodedHeight;
    if (width <= 0 || height <= 0) {
      return this.viewportHeight;
    }
    const fit: number = Math.min(this.viewportWidth / width, this.viewportHeight / height);
    return height * fit;
  }

  private boundX(value: number, scale: number): number {
    const limit: number = Math.max(0, (this.fittedWidth() * scale - this.viewportWidth) / 2);
    return Math.max(-limit, Math.min(limit, value));
  }

  private boundY(value: number, scale: number): number {
    const limit: number = Math.max(0, (this.fittedHeight() * scale - this.viewportHeight) / 2);
    return Math.max(-limit, Math.min(limit, value));
  }

  private doubleTap(event: GestureEvent): void {
    this.onZoomStart();
    if (this.zoomScale > 1) {
      this.getUIContext().animateTo({ duration: motionDuration(280), curve: motionCurve() }, (): void => {
        this.reset();
      });
      return;
    }
    let touchX: number = this.viewportWidth / 2;
    let touchY: number = this.viewportHeight / 2;
    if (event.fingerList.length > 0 && event.fingerList[0] !== undefined) {
      touchX = event.fingerList[0].localX;
      touchY = event.fingerList[0].localY;
    }
    const nextScale: number = 2.5;
    const nextX: number = this.boundX((touchX - this.viewportWidth / 2) * (1 - nextScale), nextScale);
    const nextY: number = this.boundY((touchY - this.viewportHeight / 2) * (1 - nextScale), nextScale);
    this.reportZoom(true);
    this.getUIContext().animateTo({ duration: motionDuration(280), curve: motionCurve() }, (): void => {
      this.zoomScale = nextScale;
      this.offsetX = nextX;
      this.offsetY = nextY;
    });
  }

  private pinchStart(event: GestureEvent): void {
    this.onZoomStart();
    this.pinching = true;
    this.panInterrupted = true;
    this.dismissY = 0;
    this.onDismissDrag(0);
    this.pinchStartScale = this.zoomScale;
    this.pinchStartX = this.offsetX;
    this.pinchStartY = this.offsetY;
    this.pinchCenterStartX = event.source === SourceType.Mouse ? this.viewportWidth / 2 : event.pinchCenterX;
    this.pinchCenterStartY = event.source === SourceType.Mouse ? this.viewportHeight / 2 : event.pinchCenterY;
    this.reportZoom(true);
  }

  private pinchUpdate(event: GestureEvent): void {
    const rawScale: number = this.pinchStartScale * event.scale;
    const nextScale: number = rawScale < 1 ? Math.max(0.85, 1 + (rawScale - 1) * 0.25) :
      (rawScale > 4 ? Math.min(4.5, 4 + (rawScale - 4) * 0.2) : rawScale);
    const centerX: number = event.source === SourceType.Mouse ? 0 : event.pinchCenterX - this.viewportWidth / 2;
    const centerY: number = event.source === SourceType.Mouse ? 0 : event.pinchCenterY - this.viewportHeight / 2;
    const startX: number = this.pinchCenterStartX - this.viewportWidth / 2;
    const startY: number = this.pinchCenterStartY - this.viewportHeight / 2;
    const ratio: number = nextScale / this.pinchStartScale;
    this.zoomScale = nextScale;
    this.offsetX = this.boundX(centerX - ratio * (startX - this.pinchStartX), nextScale);
    this.offsetY = this.boundY(centerY - ratio * (startY - this.pinchStartY), nextScale);
  }

  private pinchEnd(): void {
    this.pinching = false;
    this.panInterrupted = true;
    const scale: number = this.zoomScale <= 1.02 ? 1 : this.clampScale(this.zoomScale);
    const ratio: number = scale / this.zoomScale;
    const x: number = this.boundX(this.offsetX * ratio, scale);
    const y: number = this.boundY(this.offsetY * ratio, scale);
    this.getUIContext().animateTo({ duration: motionDuration(240), curve: motionCurve() }, (): void => {
      this.zoomScale = scale;
      this.offsetX = x;
      this.offsetY = y;
    });
    this.reportZoom(scale > 1);
  }

  private resistedOffset(value: number, bound: number): number {
    return bound + (value - bound) * 0.25;
  }

  private panUpdate(event: GestureEvent): void {
    // Wheel/touchpad scrolling may pan a zoomed image, but must never dismiss it.
    if (event.source === SourceType.Mouse && this.zoomScale <= 1) { return; }
    if (this.pinching || this.activeFingers(event) > 1) {
      return;
    }
    if (this.zoomScale > 1) {
      if (this.panInterrupted) {
        this.panStartX = this.offsetX - event.offsetX;
        this.panStartY = this.offsetY - event.offsetY;
        this.panInterrupted = false;
        return;
      }
      // PanGesture offsets are cumulative from the touch start, not frame deltas.
      const x: number = this.panStartX + event.offsetX;
      const y: number = this.panStartY + event.offsetY;
      this.offsetX = this.resistedOffset(x, this.boundX(x, this.zoomScale));
      this.offsetY = this.resistedOffset(y, this.boundY(y, this.zoomScale));
      return;
    }
    this.dismissY = Math.max(0, event.offsetY);
    this.onDismissDrag(this.dismissY / Math.max(1, this.viewportHeight));
  }

  private activeFingers(event: GestureEvent): number {
    let count: number = 0;
    for (let i: number = 0; i < event.fingerList.length; i++) {
      if (event.fingerList[i] !== undefined) { count += 1; }
    }
    return count;
  }

  private panCancel(): void {
    if (this.pinching) { return; }
    if (this.zoomScale > 1) {
      this.panEnd();
      return;
    }
    this.getUIContext().animateTo({ duration: motionDuration(200), curve: Curve.EaseOut }, (): void => {
      this.dismissY = 0;
      this.onDismissDrag(0);
    });
  }

  private panEnd(event?: GestureEvent): void {
    if (event?.source === SourceType.Mouse && this.zoomScale <= 1) { return; }
    if (this.pinching) { return; }
    if (this.zoomScale > 1) {
      const velocityX: number = event === undefined ? 0 : event.velocityX;
      const velocityY: number = event === undefined ? 0 : event.velocityY;
      const x: number = this.boundX(this.offsetX + velocityX * 0.12, this.zoomScale);
      const y: number = this.boundY(this.offsetY + velocityY * 0.12, this.zoomScale);
      this.getUIContext().animateTo({ duration: motionDuration(240), curve: Curve.EaseOut }, (): void => {
        this.offsetX = x;
        this.offsetY = y;
      });
      return;
    }
    if (this.dismissY > 110) {
      this.onDismiss();
      return;
    }
    this.getUIContext().animateTo({ duration: motionDuration(200), curve: Curve.EaseOut }, (): void => {
      this.dismissY = 0;
      this.onDismissDrag(0);
    });
  }

  @Builder
  private PhotoImage(): void {
    Stack() {
      if (this.gifMedia !== null) {
        if (this.gifMedia.mediaUrl.length === 0 || this.isGifImage(this.gifMedia.mediaUrl)) {
          GifPreviewImage({ url: this.playbackEnabled ? this.gifMedia.mediaUrl : '', previewUrl: this.gifMedia.previewUrl,
            displayHeight: this.viewportHeight, imageFit: ImageFit.Contain,
            surfaceColor: Color.Transparent, onImageReady: this.onImageReady })
        } else {
          SurfaceVideoPlayer({ media: this.gifMedia, manualStart: true, playbackEnabled: this.playbackEnabled,
            fillVideoViewport: true, containVideo: true, immersiveVideo: true,
            videoViewportHeight: this.viewportHeight, onViewerSurfaceReady: this.onImageReady })
        }
      } else if (this.sharedPhoto !== null) {
        ContentSlot(this.sharedPhoto.pageContent)
      } else {
        Image(this.fallbackPixelMap !== null ? this.fallbackPixelMap : this.source)
          .width('100%').height('100%').objectFit(ImageFit.Contain).draggable(false)
          .onError((): void => this.onImageError())
          .onComplete((event): void => {
            if (event !== undefined && event.width > 0 && event.height > 0) {
              this.decodedWidth = event.width;
              this.decodedHeight = event.height;
              if (this.alive) { this.loading = false; this.loadFailed = false; this.onImageReady(); }
            }
          })
      }
    }
      .width('100%')
      .height('100%')
      .scale({ x: this.zoomScale, y: this.zoomScale })
      .translate({ x: this.offsetX, y: this.offsetY + this.dismissY })
      .renderGroup(true)
      .hitTestBehavior(HitTestMode.None)
      .accessibilityText(this.alt.length > 0 ? this.alt : 'photo')
  }

  private isGifImage(url: string): boolean {
    const lower: string = url.toLowerCase();
    return lower.split('?')[0].split('#')[0].endsWith('.gif') || lower.indexOf('format=gif') >= 0;
  }

  build(): void {
    // The gesture surface stays fixed; only the image beneath it transforms.
    Stack() {
      this.PhotoImage()
      if (this.gifMedia === null && this.sharedPhoto === null) {
        if (this.loading) { LoadingProgress().width(32).height(32).color(Color.White).hitTestBehavior(HitTestMode.None) }
        else if (this.loadFailed) {
          Column({ space: 12 }) {
            Text($r('app.string.image_edit_load_failed')).fontColor(Color.White).fontSize($r('sys.float.Body_M'))
            Button($r('app.string.xxauth_retry')).onClick((): void => this.resolveSource())
          }.padding(20)
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
    .clip(true)
    .onAreaChange((_oldValue: Area, newValue: Area): void => {
      const width: number = Number(newValue.width);
      const height: number = Number(newValue.height);
      if (width > 0 && height > 0) {
        this.viewportWidth = width;
        this.viewportHeight = height;
        this.offsetX = this.boundX(this.offsetX, this.zoomScale);
        this.offsetY = this.boundY(this.offsetY, this.zoomScale);
      }
    })
    .gesture(
      GestureGroup(GestureMode.Parallel,
        PinchGesture({ fingers: 2 })
          .onActionStart((event: GestureEvent): void => this.pinchStart(event))
          .onActionUpdate((event: GestureEvent): void => this.pinchUpdate(event))
          .onActionEnd((): void => this.pinchEnd())
          .onActionCancel((): void => this.pinchEnd()),
        PanGesture({ fingers: 1,
          direction: this.zoomScale > 1 ? PanDirection.All : PanDirection.Vertical })
          .onActionStart((): void => {
            this.panStartX = this.offsetX;
            this.panStartY = this.offsetY;
            this.panInterrupted = false;
          })
          .onActionUpdate((event: GestureEvent): void => this.panUpdate(event))
          .onActionEnd((event: GestureEvent): void => this.panEnd(event))
          .onActionCancel((): void => this.panCancel()),
        GestureGroup(GestureMode.Exclusive,
          LongPressGesture()
            .onAction((): void => this.onLongPress(this.url)),
          TapGesture({ count: 2 })
            .onAction((event: GestureEvent): void => this.doubleTap(event)),
          TapGesture({ count: 1 })
            .onAction((): void => this.onSingleTap())
        )
      )
    )
  }
}
@Component
export struct PhotoViewer {
  @StorageProp(STORAGE_KEY_HIDDEN_MENU_ACTIONS) private hiddenMenuActions: string = '';
  @StorageProp(STORAGE_KEY_PAGE_TRANSITION_MODE) private pageTransitionMode: string = DEFAULT_PAGE_TRANSITION_MODE;
  private photoSession: MediaPhotoSession = new MediaPhotoSession();
  @State private motion: MediaViewerMotionState = new MediaViewerMotionState();
  @State private initialPhotoReady: boolean = false;
  private motionSurfaceId: string = createMediaSourcePrefix() + 'photo-viewer';
  private photoTransformScale: number = 1;
  private photoTransformX: number = 0;
  private photoTransformY: number = 0;
  private viewerAlive: boolean = true;
  private windowOverlay: boolean = false;
  @StorageProp('reduceMotionEnabled') private reduceMotion: boolean = false;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp('harmonyx.breakpoint') @Watch('onPhotoViewportChanged') private sheetWindowBreakpoint: string = 'sm';
  @StorageProp('harmonyx.breakpoint') breakpoint: string = 'sm';
  @StorageProp(STORAGE_KEY_PHOTO_FULLSCREEN) photoFullscreen: boolean = true;
  @StorageProp(STORAGE_KEY_DESKTOP_LAYOUT) private desktopLayoutEnabled: boolean = false;
  @StorageProp(STORAGE_KEY_MEDIA_VIEWER_BLACK_BACKGROUND) mediaViewerBlackBackground: boolean = false;
  @State private viewerHeight: number = 0;
  @StorageProp('harmonyx.window_width') @Watch('onPhotoViewportChanged') private windowWidth: number = 0;
  private desktop(): boolean { return !this.photoFullscreen && ResponsiveLayout.isLarge(this.breakpoint); }
  @StorageProp(STORAGE_KEY_SHEET_MATERIAL_ENABLED) private sheetMaterialEnabled: boolean = DEFAULT_SHEET_MATERIAL_ENABLED;
  @StorageProp(STORAGE_KEY_SHEET_MATERIAL_LEVEL) private sheetMaterialLevel: number = DEFAULT_SHEET_MATERIAL_LEVEL;
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp('harmonyx.status_bar_height') @Watch('onPhotoViewportChanged') statusBarHeight: number =
    AppStorage.get<number>('harmonyx.status_bar_height') ?? 0;
  @StorageProp('harmonyx.navigation_indicator_height') @Watch('onPhotoViewportChanged') navigationIndicatorHeight: number =
    AppStorage.get<number>('harmonyx.navigation_indicator_height') ?? 0;
  @StorageProp('harmonyx.window_height') @Watch('onPhotoViewportChanged') windowHeight: number =
    AppStorage.get<number>('harmonyx.window_height') ?? 780;
  @StorageProp('harmonyx.display_mode') themeDisplayMode: string = '';
  @StorageProp('harmonyx.dark_surface') themeDarkSurface: string = '';
  @State private tweet: Tweet | null = null;
  @State private showPostSheet: boolean = false;
  @State private showMoreSheet: boolean = false;
  @State private postSheetHeight: number = 0;
  @State private photoViewportWidth: number = 0;
  @State private postPhotoScale: number = 1;
  @State private postPhotoOffsetY: number = 0;
  @State private postControlsOpacity: number = 1;
  private postSheetOpening: boolean = false;
  @State private downloading: boolean = false;
  @State private savingBackground: boolean = false;
  @State private postRevision: number = 0;
  private likeAction: (post: Tweet, liked: boolean) => Promise<boolean> = async (): Promise<boolean> => false;
  private repostAction: (post: Tweet, reposted: boolean) => Promise<boolean> = async (): Promise<boolean> => false;
  private replyAction: (post: Tweet) => void = (): void => {};
  @State private items: PhotoViewerPhoto[] = [];
  @State private viewerSession: number = 0;
  @State private alt: string = '';
  @State private current: number = 0;
  @State private zoomed: boolean = false;
  @State private pointerHover: boolean = false;
  private inputPager: SwiperController = new SwiperController();
  @State private transitionPrefix: string = '';
  @State private controlsVisible: boolean = false;
  @State private originalShown: boolean = false;
  @State private resetting: boolean = false;
  @State private backdropOpacity: number = 1;
  @State private ocrVisible: boolean = false;
  @State private ocrLoading: boolean = false;
  @State private ocrEntries: PhotoOcrEntry[] = [];
  @State private ocrStatus: string = '';
  @State private subjectVisible: boolean = false;
  @State private subjectLoading: boolean = false;
  @State private subjectPixelMap: image.PixelMap | null = null;
  @State private subjectStatus: string = '';
  @State private copyStatus: string = '';
  @StorageLink('harmonyx.accent_color') accentColor: string = '#007DFF';
  @State private closing: boolean = false;
  private ocrRequestId: number = 0;
  private screenBlocked: boolean = false;
  private subjectRequestId: number = 0;
  private gifSelectAction: ((index: number) => Promise<void>) | null = null;
  @State private selectingGif: boolean = false;

  aboutToDisappear(): void {
    this.viewerAlive = false;
    this.ocrRequestId += 1;
    this.subjectRequestId += 1;
    this.releaseSubjectPixelMap();
  }

  private inputBack(): boolean {
      if (this.subjectVisible) {
        this.closeSubjectPanel();
        return true;
      }
      if (this.ocrVisible) {
        this.closeOcrPanel();
        return true;
      }
      if (this.showMoreSheet) { this.showMoreSheet = false; return true; }
      if (this.showPostSheet) { this.closePostSheet(); return true; }
      this.close();
      return true;
  }

  private inputPhoto(direction: number): void {
    if (this.closing || this.zoomed || this.showMoreSheet || this.showPostSheet || this.ocrVisible || this.subjectVisible) { return; }
    const next: number = this.current + direction;
    if (next < 0 || next >= this.items.length) { return; }
    this.inputPager.changeIndex(next, true);
  }

  private photoInputKey(event: KeyEvent): boolean {
    if (!plainInputKey(event) || this.zoomed || this.showMoreSheet || this.showPostSheet || this.ocrVisible || this.subjectVisible) { return false; }
    if (event.keyCode !== KeyCode.KEYCODE_DPAD_LEFT && event.keyCode !== KeyCode.KEYCODE_DPAD_RIGHT) { return false; }
    if (event.type === KeyType.Down) { this.inputPhoto(event.keyCode === KeyCode.KEYCODE_DPAD_LEFT ? -1 : 1); }
    return true;
  }

  @Builder
  private PointerPhotoNavigation(): void {
    if ((this.desktop() || this.pointerHover) && this.items.length > 1 && !this.zoomed && !this.showPostSheet) {
      Row() {
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(24).fontColor([Color.White])
        }.width(44).height(44).backgroundColor($r('app.color.photo_viewer_author_scrim'))
          .enabled(this.current > 0).accessibilityText($r('app.string.input_previous'))
          .onClick((): void => this.inputPhoto(-1))
        Blank()
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(24).fontColor([Color.White])
        }.width(44).height(44).backgroundColor($r('app.color.photo_viewer_author_scrim'))
          .enabled(this.current < this.items.length - 1).accessibilityText($r('app.string.input_next'))
          .onClick((): void => this.inputPhoto(1))
      }.width('100%').height('100%').alignItems(VerticalAlign.Center).padding(16).hitTestBehavior(HitTestMode.Transparent)
    }
  }

  private text(resource: Resource): string {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    return context.resourceManager.getStringSync(resource);
  }

  private menuVisible(id: string): boolean {
    return menuActionVisible(this.hiddenMenuActions, id);
  }

  private readRoute(param: PhotoViewerRouteParam): void {
    this.viewerAlive = true;
    this.windowOverlay = param.windowOverlay === true;
    this.motion.prepare(param.source);
    this.photoTransformScale = 1;
    this.photoTransformX = 0;
    this.photoTransformY = 0;
    this.viewerSession += 1;
    this.closing = false;
    this.resetting = false;
    this.zoomed = false;
    this.originalShown = false;
    this.gifSelectAction = param.onGifSelect ?? null;
    this.selectingGif = false;
    this.controlsVisible = this.gifSelectAction !== null || !this.photoFullscreen;
    this.backdropOpacity = 1;
    this.showPostSheet = false;
    this.showMoreSheet = false;
    this.postPhotoScale = 1;
    this.postPhotoOffsetY = 0;
    this.postControlsOpacity = 1;
    const next: PhotoViewerPhoto[] = [];
    if (param.items !== undefined && param.items.length > 0) {
      for (let i: number = 0; i < param.items.length; i++) {
        next.push(param.items[i]);
      }
    } else {
      for (let i: number = 0; i < param.urls.length; i++) {
        const url: string = param.urls[i];
        next.push(new PhotoViewerPhoto(url, imageUrlForQuality(url, IMAGE_QUALITY_ORIGINAL),
          0, 0, i, param.alt));
      }
    }
    this.items = next;
    const initialIndex: number = Math.max(0, Math.min(next.length - 1, param.index));
    const sourceNode: MediaPhotoNode | undefined = param.source === undefined ? undefined :
      mediaPhotoNodeFor(next[initialIndex]?.sourceId ?? '');
    this.initialPhotoReady = param.source === undefined || next[initialIndex]?.animation != null ||
      (sourceNode !== undefined && sourceNode.width > 0 && sourceNode.height > 0);
    this.alt = param.alt;
    this.current = initialIndex;
    this.transitionPrefix = param.transitionPrefix;
    this.screenBlocked = param.screenBlocked === true;
    this.tweet = param.tweet ?? null;
    if (param.onLike !== undefined) { this.likeAction = param.onLike; }
    if (param.onRepost !== undefined) { this.repostAction = param.onRepost; }
    if (param.onReply !== undefined) { this.replyAction = param.onReply; }
  }

  private currentOriginalUrl(): string {
    if (this.current < 0 || this.current >= this.items.length) {
      return '';
    }
    return this.items[this.current].originalUrl;
  }

  private currentAnimation(): MediaAttachment | null {
    return this.items[this.current]?.animation ?? null;
  }

  private currentDisplayUrl(): string {
    if (this.current < 0 || this.current >= this.items.length) {
      return '';
    }
    return this.displayUrl(this.items[this.current], this.current);
  }

  @Builder
  private ViewerBackdrop(): void {
    if (!this.mediaViewerBlackBackground) {
      PhotoViewerBackdrop({
        url: this.currentDisplayUrl(),
        backdropOpacity: this.backdropOpacity
      })
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.None)
    }
    Column()
      .width('100%')
      .height('100%')
      .backgroundColor(this.mediaViewerBlackBackground ? $r('app.color.media_viewer_black_background') :
        $r('app.color.video_feed_post_scrim'))
      .hitTestBehavior(HitTestMode.None)
  }

  private flattenOcrResult(result: textRecognition.TextRecognitionResult): PhotoOcrEntry[] {
    const entries: PhotoOcrEntry[] = [];
    for (let blockIndex: number = 0; blockIndex < result.blocks.length; blockIndex++) {
      const block: textRecognition.TextBlock = result.blocks[blockIndex];
      for (let lineIndex: number = 0; lineIndex < block.lines.length; lineIndex++) {
        const line: textRecognition.TextLine = block.lines[lineIndex];
        const points: textRecognition.PixelPoint[] = line.cornerPoints;
        let left: number = 0;
        let top: number = 0;
        let right: number = 0;
        let bottom: number = 0;
        if (points.length > 0) {
          left = points[0].x;
          right = points[0].x;
          top = points[0].y;
          bottom = points[0].y;
          for (let pointIndex: number = 1; pointIndex < points.length; pointIndex++) {
            const point: textRecognition.PixelPoint = points[pointIndex];
            left = Math.min(left, point.x);
            top = Math.min(top, point.y);
            right = Math.max(right, point.x);
            bottom = Math.max(bottom, point.y);
          }
        }
        const position: string = this.text($r('app.string.photo_ocr_position')) + ' x:' +
          Math.floor(left).toString() + ' y:' + Math.floor(top).toString() + ' w:' +
          Math.max(0, Math.floor(right - left)).toString() + ' h:' +
          Math.max(0, Math.floor(bottom - top)).toString() + ' px';
        if (line.value.trim().length > 0) {
          entries.push(new PhotoOcrEntry(line.value, position));
        }
      }
    }
    return entries;
  }

  private async recognizeCurrentPhoto(sourceUrl: string): Promise<void> {
    const requestId: number = this.ocrRequestId + 1;
    this.ocrRequestId = requestId;
    this.ocrVisible = true;
    this.ocrLoading = false;
    this.ocrEntries = [];
    this.ocrStatus = '';
    this.copyStatus = '';
    if (sourceUrl.length === 0) {
      this.ocrStatus = this.text($r('app.string.photo_ocr_failed'));
      return;
    }
    this.ocrLoading = true;
    let pixelMap: image.PixelMap | null = null;
    let initialized: boolean = false;
    try {
      pixelMap = await proxyImageResolver.load(sourceUrl, true);
      if (pixelMap === null) {
        if (requestId === this.ocrRequestId && sourceUrl === this.currentDisplayUrl()) {
          this.ocrStatus = this.text($r('app.string.photo_ocr_failed'));
        }
        return;
      }
      initialized = await textRecognition.init();
      if (!initialized) {
        if (requestId === this.ocrRequestId && sourceUrl === this.currentDisplayUrl()) {
          this.ocrStatus = this.text($r('app.string.photo_ocr_failed'));
        }
        return;
      }
      const result: textRecognition.TextRecognitionResult =
        await textRecognition.recognizeText({ pixelMap: pixelMap });
      if (requestId !== this.ocrRequestId || sourceUrl !== this.currentDisplayUrl()) {
        return;
      }
      this.ocrEntries = this.flattenOcrResult(result);
      if (this.ocrEntries.length === 0) {
        this.ocrStatus = this.text($r('app.string.photo_ocr_empty'));
      }
    } catch (error) {
      if (requestId === this.ocrRequestId) {
        this.ocrStatus = this.text($r('app.string.photo_ocr_failed'));
      }
    } finally {
      if (initialized) {
        try {
          await textRecognition.release();
        } catch (error) {
        }
      }
      if (pixelMap !== null) {
        proxyImageResolver.release(pixelMap);
      }
      if (requestId === this.ocrRequestId) {
        this.ocrLoading = false;
      }
    }
  }

  private async cutOutCurrentSubject(): Promise<void> {
    const sourceUrl: string = this.currentDisplayUrl();
    if (this.subjectLoading || sourceUrl.length === 0) {
      return;
    }
    const requestId: number = this.subjectRequestId + 1;
    this.subjectRequestId = requestId;
    this.subjectVisible = true;
    this.subjectLoading = true;
    this.subjectStatus = '';
    this.copyStatus = '';
    this.releaseSubjectPixelMap();
    let pixelMap: image.PixelMap | null = null;
    let foreground: image.PixelMap | null = null;
    let initialized: boolean = false;
    try {
      pixelMap = await proxyImageResolver.load(sourceUrl, true);
      if (pixelMap === null) {
        if (requestId === this.subjectRequestId && sourceUrl === this.currentDisplayUrl()) {
          this.subjectStatus = this.text($r('app.string.photo_subject_failed'));
        }
        return;
      }
      initialized = await subjectSegmentation.init();
      if (!initialized) {
        if (requestId === this.subjectRequestId && sourceUrl === this.currentDisplayUrl()) {
          this.subjectStatus = this.text($r('app.string.photo_subject_failed'));
        }
        return;
      }
      const result: subjectSegmentation.SegmentationResult = await subjectSegmentation.doSegmentation(
        { pixelMap: pixelMap },
        { maxCount: 1, enableSubjectDetails: false, enableSubjectForegroundImage: true }
      );
      if (requestId !== this.subjectRequestId || sourceUrl !== this.currentDisplayUrl()) {
        foreground = result.fullSubject.foregroundImage;
        return;
      }
      if (result.subjectCount <= 0) {
        this.subjectStatus = this.text($r('app.string.photo_subject_empty'));
        return;
      }
      foreground = result.fullSubject.foregroundImage;
      this.subjectPixelMap = foreground;
      foreground = null;
    } catch (error) {
      if (requestId === this.subjectRequestId) {
        this.subjectStatus = this.text($r('app.string.photo_subject_failed'));
      }
    } finally {
      if (initialized) {
        try {
          await subjectSegmentation.release();
        } catch (error) {
        }
      }
      if (foreground !== null) {
        proxyImageResolver.release(foreground);
      }
      if (pixelMap !== null) {
        proxyImageResolver.release(pixelMap);
      }
      if (requestId === this.subjectRequestId) {
        this.subjectLoading = false;
      }
    }
  }

  private releaseSubjectPixelMap(): void {
    const pixelMap: image.PixelMap | null = this.subjectPixelMap;
    this.subjectPixelMap = null;
    if (pixelMap !== null) {
      proxyImageResolver.release(pixelMap);
    }
  }

  private closeOcrPanel(): void {
    this.ocrVisible = false;
    this.ocrRequestId += 1;
  }

  private closeSubjectPanel(): void {
    this.subjectVisible = false;
    this.subjectRequestId += 1;
    this.subjectLoading = false;
    this.releaseSubjectPixelMap();
  }

  private async copyOcrText(value: string): Promise<void> {
    if (value.trim().length === 0) {
      return;
    }
    try {
      await pasteboard.getSystemPasteboard().setPasteData(pasteboard.createPlainTextData(value));
      this.copyStatus = this.text($r('app.string.photo_copied'));
    } catch (error) {
      this.copyStatus = this.text($r('app.string.photo_copy_failed'));
    }
  }

  private searchOcrText(value: string): void {
    const query: string = value.trim();
    if (query.length === 0) {
      return;
    }
    this.closeOcrPanel();
    requestSearch(query);
  }

  private async saveSubjectPng(): Promise<string> {
    const pixelMap: image.PixelMap | null = this.subjectPixelMap;
    if (pixelMap === null) {
      return '';
    }
    let file: fileIo.File | undefined = undefined;
    try {
      const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      const filePath: string = context.cacheDir + '/harmonyx-subject-sticker-' + Date.now().toString() + '.png';
      const packer: image.ImagePacker = image.createImagePacker();
      const data: ArrayBuffer = await packer.packToData(pixelMap, { format: 'image/png', quality: 100 });
      file = fileIo.openSync(filePath,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(file.fd, data);
      return fileUri.getUriFromPath(filePath);
    } catch (error) {
      this.subjectStatus = this.text($r('app.string.photo_subject_save_failed'));
      return '';
    } finally {
      if (file !== undefined) {
        try {
          fileIo.closeSync(file.fd);
        } catch (error) {
        }
      }
    }
  }

  private async addSubjectToPost(): Promise<void> {
    if (this.subjectPixelMap === null || this.subjectLoading) {
      return;
    }
    const imageUri: string = await this.saveSubjectPng();
    if (imageUri.length === 0) {
      return;
    }
    const param: ReplyComposerRouteParam = {
      replyToId: '',
      replyToUser: '',
      avatarUrl: '',
      avatarName: '',
      avatarColor: this.accentColor,
      initialText: '',
      imageUri: imageUri,
      gifUri: '',
      communityId: '',
      communityName: '',
      parentTweet: null
    };
    this.closeSubjectPanel();
    this.pageStack.pushPath({ name: 'ReplyComposer', param: param });
  }

  @Builder
  private OcrResultPanel(): void {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#99000000')
        .onClick((): void => this.closeOcrPanel())
      Column({ space: 14 }) {
        Row() {
          Text($r('app.string.photo_ocr_title')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Title_M'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
          Text($r('app.string.common_back')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('app.color.brand'))
            .onClick((): void => this.closeOcrPanel())
        }
        if (this.ocrLoading) {
          Text($r('app.string.photo_ocr_loading')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
        } else if (this.ocrEntries.length === 0) {
          Text(this.ocrStatus).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
        } else {
          Row({ space: 10 }) {
            Text($r('app.string.photo_copy_all')).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_M'))
              .fontColor($r('app.color.brand'))
              .onClick((): void => {
                let allText: string = '';
                for (let index: number = 0; index < this.ocrEntries.length; index++) {
                  if (allText.length > 0) {
                    allText += '\n';
                  }
                  allText += this.ocrEntries[index].text;
                }
                void this.copyOcrText(allText);
              })
            if (this.copyStatus.length > 0) {
              Text(this.copyStatus).fontFamily(this.appFontFamily)
                .fontSize($r('sys.float.Caption_M'))
                .fontColor($r('app.color.text_secondary'))
            }
          }
          .width('100%')
          Scroll() {
            Column({ space: 12 }) {
              ForEach(this.ocrEntries, (entry: PhotoOcrEntry) => {
                Column({ space: 6 }) {
                  Text(entry.text).fontFamily(this.appFontFamily)
                    .fontSize($r('sys.float.Body_M'))
                    .fontColor($r('app.color.text_primary'))
                    .width('100%')
                    .textSelectable(TextSelectableMode.SELECTABLE_UNFOCUSABLE)
                  Text(entry.position).fontFamily(this.appFontFamily)
                    .fontSize($r('sys.float.Caption_M'))
                    .fontColor($r('app.color.text_secondary'))
                    .width('100%')
                  Row({ space: 18 }) {
                    Text($r('app.string.photo_copy')).fontFamily(this.appFontFamily)
                      .fontSize($r('sys.float.Body_S'))
                      .fontColor($r('app.color.brand'))
                      .onClick((): void => {
                        void this.copyOcrText(entry.text);
                      })
                    Text($r('app.string.photo_search')).fontFamily(this.appFontFamily)
                      .fontSize($r('sys.float.Body_S'))
                      .fontColor($r('app.color.brand'))
                      .onClick((): void => this.searchOcrText(entry.text))
                  }
                }
                .width('100%')
                .padding(12)
                .backgroundColor($r('app.color.bg_field'))
                .borderRadius(12)
              }, (entry: PhotoOcrEntry, index: number) => index.toString() + '-' + entry.text)
            }
            .width('100%')
          }
          .layoutWeight(1)
          .width('100%')
        }
      }
      .width('92%')
      .height('68%')
      .padding(18)
      .backgroundColor($r('app.color.bg_card'))
      .borderRadius(24)
    }
    .width('100%')
    .height('100%')
    .zIndex(20)
  }

  @Builder
  private SubjectPreviewPanel(): void {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#99000000')
        .onClick((): void => this.closeSubjectPanel())
      Column({ space: 14 }) {
        Row() {
          Text($r('app.string.photo_subject_title')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Title_M'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
          Text($r('app.string.common_back')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('app.color.brand'))
            .onClick((): void => this.closeSubjectPanel())
        }
        if (this.subjectLoading) {
          Text($r('app.string.photo_subject_loading')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
        } else if (this.subjectPixelMap === null) {
          Text(this.subjectStatus).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
        } else {
          Stack({ alignContent: Alignment.Center }) {
            Column()
              .width('100%')
              .height('100%')
              .backgroundColor($r('app.color.bg_field'))
              .borderRadius(16)
            Image(this.subjectPixelMap)
              .width('100%')
              .height('100%')
              .objectFit(ImageFit.Contain)
              .renderGroup(true)
          }
          .layoutWeight(1)
          .width('100%')
          .clip(true)
          Row() {
            Text($r('app.string.photo_add_to_post')).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_M'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_on_brand'))
              .padding({ left: 18, right: 18, top: 10, bottom: 10 })
              .backgroundColor($r('app.color.brand'))
              .borderRadius(22)
              .onClick((): void => {
                void this.addSubjectToPost();
              })
            if (this.subjectStatus.length > 0) {
              Text(this.subjectStatus).fontFamily(this.appFontFamily)
                .fontSize($r('sys.float.Caption_M'))
                .fontColor($r('app.color.text_secondary'))
            }
          }
        }
      }
      .width('92%')
      .height('68%')
      .padding(18)
      .backgroundColor($r('app.color.bg_card'))
      .borderRadius(24)
    }
    .width('100%')
    .height('100%')
    .zIndex(20)
  }

  private displayUrl(item: PhotoViewerPhoto, index: number): string {
    if (item.animation != null) { return item.previewUrl; }
    return this.originalShown && index === this.current ? item.originalUrl : item.previewUrl;
  }

  private originalUrls(): string[] {
    const urls: string[] = [];
    for (let i: number = 0; i < this.items.length; i++) {
      urls.push(this.items[i].originalUrl);
    }
    return urls;
  }

  private adoptPhoto(node: MediaPhotoNode, owner: string, url: string, index: number): boolean {
    // Props and preloaded pages may still update while the return is waiting
    // for layout. They must not take an already restored thumbnail back.
    if (this.closing || !this.viewerAlive || !node.adopt(this.getUIContext(), owner, url)) { return false; }
    this.photoSession.remember(node, owner, index);
    return true;
  }

  private close(): void {
    if (this.closing) {
      return;
    }
    this.closing = true;
    // First align the source strip with the currently viewed photo. Measure
    // it after layout, then return from the current zoom/drag without a reset.
    if (this.transitionPrefix.length > 0) {
      AppStorage.setOrCreate<string>(STORAGE_KEY_PHOTO_RETURN,
        this.transitionPrefix + '|' + this.current.toString() + '|' + Date.now().toString());
    }
    if (!this.motion.enabled()) {
      this.photoSession.restoreOthers(this.getUIContext(), this.current);
      this.popViewer();
      return;
    }
    const session: number = this.viewerSession;
    this.getUIContext().postFrameCallback(new MediaViewerMotionFrame((): void => {
      if (!this.viewerAlive || session !== this.viewerSession) { return; }
      // Source scrolling may remount neighbours. Restore their original nodes
      // after that layout, and let their thumbnails paint before shrinking.
      this.photoSession.restoreOthers(this.getUIContext(), this.current);
      this.getUIContext().postFrameCallback(new MediaViewerMotionFrame((): void => {
        if (!this.viewerAlive || session !== this.viewerSession) { return; }
        this.animatePhotoReturn();
      }));
    }));
  }

  private animatePhotoReturn(): void {
    const item: PhotoViewerPhoto | undefined = this.items[this.current];
    const geometry: MediaViewerGeometry | undefined = measureMediaViewerGeometry(this.getUIContext(),
      this.motionSurfaceId, this.motionSurfaceId + '-photo', item?.width ?? 0, item?.height ?? 0);
    if (geometry === undefined || item === undefined) {
      this.finishPhotoReturn();
      return;
    }
    const source: MediaViewerSource | undefined = captureMediaViewerSource(this.getUIContext(),
      item.sourceId ?? '', '', item.width, item.height, this.motion.source?.contain ?? false,
      this.motion.source?.radius ?? 14);
    const width: number = geometry.target.width;
    const height: number = geometry.target.height;
    geometry.target.width *= this.photoTransformScale;
    geometry.target.height *= this.photoTransformScale;
    geometry.target.x += (width - geometry.target.width) / 2 + this.photoTransformX;
    geometry.target.y += (height - geometry.target.height) / 2 + this.photoTransformY;
    this.motion.dismiss(this.getUIContext(), source, geometry.viewport, geometry.target, this.reduceMotion,
      (): void => this.finishPhotoReturn());
  }

  private finishPhotoReturn(): void {
    const session: number = this.viewerSession;
    const ui = this.getUIContext();
    // Move the live image and hide its now-empty destination in one commit.
    // The source must get a layout/paint frame before Navigation removes the
    // outgoing tree; otherwise the handoff exposes one empty thumbnail frame.
    ui.animateTo({ duration: 0 }, (): void => {
      this.photoSession.restore(ui);
      this.motion.handoff();
    });
    ui.postFrameCallback(new MediaViewerMotionFrame((): void => {
      if (!this.viewerAlive || session !== this.viewerSession) { return; }
      ui.postFrameCallback(new MediaViewerMotionFrame((): void => {
        if (!this.viewerAlive || session !== this.viewerSession) { return; }
        this.popViewer(false);
      }));
    }));
  }

  private popViewer(animated: boolean = true): void {
    if (this.windowOverlay) { this.pageStack.pop(animated); }
    else { ResponsiveLayout.closeContentDestination(this.pageStack, animated); }
  }

  private initialPostSheetHeight(): number {
    return ResponsiveLayout.mediaSheetHeight(this.windowWidth, this.windowHeight, 620,
      this.statusBarHeight, this.navigationIndicatorHeight);
  }

  private photoViewportTop(): number {
    return 0;
  }

  private photoViewportHeight(): number {
    return Math.max(1, this.viewerHeight || this.windowHeight);
  }

  private setControlsVisible(visible: boolean): void {
    if (this.controlsVisible === visible) { return; }
    // The image viewport never changes; only floating controls transform.
    this.getUIContext().animateTo({ duration: motionDuration(visible ? 240 : 180), curve: Curve.EaseOut }, (): void => {
      this.controlsVisible = visible;
    });
  }

  private onPhotoTap(index: number): void {
    if (index !== this.current || this.showPostSheet || this.closing) { return; }
    this.setControlsVisible(!this.controlsVisible);
  }

  private onPhotoZoomStart(index: number): void {
    if (index !== this.current) { return; }
    this.setControlsVisible(false);
  }

  private upperPhotoHeight(): number {
    const sheet: number = this.postSheetHeight > 0 ? this.postSheetHeight : this.initialPostSheetHeight();
    return Math.max(0, this.windowHeight - sheet - this.statusBarHeight - 12);
  }

  private fittedPhotoHeight(): number {
    const photo: PhotoViewerPhoto | undefined = this.items[this.current];
    if (photo === undefined || photo.width <= 0 || photo.height <= 0 || this.photoViewportWidth <= 0) {
      return this.photoViewportHeight();
    }
    return Math.min(this.photoViewportHeight(), this.photoViewportWidth * photo.height / photo.width);
  }

  private photoSheetScale(): number {
    if (sheetUsesCenteredPresentation(this.sheetWindowBreakpoint)) { return 1; }
    return this.showPostSheet ? Math.min(1, this.upperPhotoHeight() / this.fittedPhotoHeight()) : 1;
  }

  private photoNeedsReset(): boolean {
    return this.resetting || (this.showPostSheet && !sheetUsesCenteredPresentation(this.sheetWindowBreakpoint));
  }

  private photoSheetOffset(): number {
    if (sheetUsesCenteredPresentation(this.sheetWindowBreakpoint)) { return 0; }
    return this.showPostSheet ? this.statusBarHeight + this.upperPhotoHeight() / 2 -
      this.photoViewportTop() - this.photoViewportHeight() / 2 : 0;
  }

  private updatePostSheetPhoto(animated: boolean): void {
    const scale: number = this.photoSheetScale();
    const offsetY: number = this.photoSheetOffset();
    const controlsOpacity: number = this.showPostSheet ? 0 : 1;
    if (animated) {
      // Retarget the same image layer; interrupted springs retain their velocity.
      this.getUIContext().animateTo({ curve: curves.springMotion(0.35, 1) }, (): void => {
        this.postPhotoScale = scale;
        this.postPhotoOffsetY = offsetY;
        this.postControlsOpacity = controlsOpacity;
      });
    } else {
      // Sheet dragging already provides each frame, so follow it without lag.
      this.postPhotoScale = scale;
      this.postPhotoOffsetY = offsetY;
      this.postControlsOpacity = controlsOpacity;
    }
  }

  private onPhotoViewportChanged(): void {
    if (this.showPostSheet) {
      this.updatePostSheetPhoto(this.postSheetOpening);
    }
  }

  private closePostSheet(): void {
    if (!this.showPostSheet) { return; }
    this.postSheetOpening = false;
    this.showPostSheet = false;
    this.updatePostSheetPhoto(true);
  }

  private openPostSheet(): void {
    if (this.tweet === null) { return; }
    this.showMoreSheet = false;
    if (this.desktop()) { return; }
    const movePhoto: boolean = !sheetUsesCenteredPresentation(this.sheetWindowBreakpoint);
    if (movePhoto) {
      this.zoomed = false;
      this.resetting = true;
    }
    this.postSheetHeight = this.initialPostSheetHeight();
    this.setControlsVisible(true);
    this.postSheetOpening = true;
    this.showPostSheet = true;
    this.updatePostSheetPhoto(true);
    if (movePhoto) { setTimeout((): void => { this.resetting = false; }, 0); }
  }

  private async downloadPhotos(all: boolean, fromSaveButton: boolean = false): Promise<void> {
    if (this.downloading || this.items.length === 0) { return; }
    const urls: string[] = all ? this.originalUrls() : [this.currentOriginalUrl()];
    const mediaId: string = this.tweet === null ? 'photo' : this.tweet.id;
    this.showMoreSheet = false;
    this.downloading = true;
    promptAction.showToast({ message: this.text(all ? $r('app.string.media_download_all_started') :
      $r('app.string.media_download_started')) });
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const completed: (result: number) => void = (result: number): void => {
      this.downloading = false;
      const message: Resource = result === MEDIA_DOWNLOAD_SAVED_AS_VIDEO ? $r('app.string.gif_save_video_fallback') :
        result === MEDIA_DOWNLOAD_SUCCESS ?
        (all ? $r('app.string.media_all_images_saved') : $r('app.string.media_image_saved')) :
        (result === MEDIA_DOWNLOAD_CANCELED ? $r('app.string.media_download_canceled') :
        $r('app.string.media_download_failed'));
      promptAction.showToast({ message: this.text(message), duration: 2200 });
    };
    if (all && this.items.some((item: PhotoViewerPhoto): boolean => item.animation != null)) {
      // The image batch API cannot accept MP4-backed GIFs. Preserve each item's
      // media kind and stop if the user cancels a destination dialog.
      let result: number = MEDIA_DOWNLOAD_SUCCESS;
      const items: PhotoViewerPhoto[] = this.items.slice();
      for (let i: number = 0; i < items.length; i++) {
        result = await new Promise<number>((resolve): void => {
          this.downloadItem(context, items[i], mediaId + '-' + i.toString(), false, resolve);
        });
        if (result !== MEDIA_DOWNLOAD_SUCCESS) { break; }
      }
      completed(result);
    } else if (all) {
      mediaDownloadService.downloadImages(context, urls, mediaId, completed);
    } else {
      this.downloadItem(context, this.items[this.current], mediaId + '-' + this.current, fromSaveButton, completed);
    }
  }

  private downloadItem(context: common.UIAbilityContext, item: PhotoViewerPhoto, mediaId: string,
    fromSaveButton: boolean, completed: (result: number) => void): void {
    const animation: MediaAttachment | null = item.animation ?? null;
    const lower: string = item.originalUrl.toLowerCase();
    const gifImage: boolean = lower.split('?')[0].split('#')[0].endsWith('.gif') || lower.indexOf('format=gif') >= 0;
    if (animation !== null && !gifImage) {
      mediaDownloadService.downloadAnimatedGif(context, item.originalUrl, mediaId,
        animation.durationMs ?? 0, item.width, item.height, completed);
    } else if (fromSaveButton) {
      void mediaDownloadService.downloadPhotoWithSaveButton(context, item.originalUrl, mediaId, completed);
    } else {
      mediaDownloadService.download(context, item.originalUrl, mediaId, false, completed);
    }
  }

  private currentGifVideoUrl(): string {
    const item: PhotoViewerPhoto | undefined = this.items[this.current];
    const animation: MediaAttachment | null = item?.animation ?? null;
    return item !== undefined && animation !== null ? gifVideoDownloadUrl(animation, item.originalUrl) : '';
  }

  private downloadGifAsVideo(): void {
    if (this.downloading) { return; }
    const url: string = this.currentGifVideoUrl();
    if (url.length === 0) { return; }
    this.showMoreSheet = false;
    this.downloading = true;
    const mediaId: string = (this.tweet === null ? 'gif' : this.tweet.id) + '-' + this.current.toString();
    promptAction.showToast({ message: this.text($r('app.string.media_download_started')) });
    mediaDownloadService.download(getContext(this) as common.UIAbilityContext, url, mediaId, true,
      (result: number): void => {
        this.downloading = false;
        const message: Resource = result === MEDIA_DOWNLOAD_SUCCESS ? $r('app.string.media_video_saved') :
          result === MEDIA_DOWNLOAD_CANCELED ? $r('app.string.media_download_canceled') : $r('app.string.media_download_failed');
        promptAction.showToast({ message: this.text(message), duration: 2200 });
      });
  }

  private async selectCurrentGif(): Promise<void> {
    const action: ((index: number) => Promise<void>) | null = this.gifSelectAction;
    if (action === null || this.selectingGif) { return; }
    this.selectingGif = true;
    try { await action(this.current); }
    finally { if (this.viewerAlive) { this.selectingGif = false; } }
  }

  private async saveBackground(): Promise<void> {
    const url: string = this.currentOriginalUrl();
    if (this.savingBackground || url.length === 0) { return; }
    this.savingBackground = true;
    this.showMoreSheet = false;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    promptAction.showToast({ message: this.text($r('app.string.chat_background_saving_photo')) });
    try {
      await backgroundImageStore.savePhoto(context, url);
      promptAction.showToast({ message: this.text($r('app.string.chat_background_saved_photo')), duration: 2600 });
    } catch (error) {
      promptAction.showToast({ message: this.text($r('app.string.chat_background_save_photo_failed')), duration: 2200 });
    } finally { this.savingBackground = false; }
  }

  @Builder
  private TopControls(): void {
    Row() {
      MaterialButton({ buttonWidth: 44, buttonHeight: 44, buttonRadius: 22,
        surfaceColor: $r('app.color.media_viewer_control'), materialLevel: 1, applyShadow: true,
        adaptiveForeground: true,
        lightColor: this.accentColor, accessibilityLabel: this.text($r('app.string.common_back')),
        buttonMonopolizeEvents: true, onButtonClick: (): void => this.close() }) {
        SymbolGlyph($r('sys.symbol.arrow_left')).fontSize(24).fontColor([this.controlForeground()])
      }
      Blank()
      if (this.gifSelectAction !== null) {
        Button(this.text($r('app.string.gif_action_use')))
          .fontFamily(this.appFontFamily).fontColor($r('app.color.text_on_brand'))
          .backgroundColor(this.accentColor).enabled(!this.selectingGif)
          .id('photo-viewer-select-gif').margin({ right: 12 })
          .onClick((): void => { void this.selectCurrentGif(); })
      }
      Row({ space: 8 }) {
        if (this.downloading) {
          LoadingProgress().width($r('app.float.photo_viewer_quick_size'))
            .height($r('app.float.photo_viewer_quick_size')).color($r('app.color.text_on_brand'))
        } else {
          SaveButton({ icon: SaveIconStyle.LINES, buttonType: ButtonType.Circle })
            .width($r('app.float.photo_viewer_quick_size')).height($r('app.float.photo_viewer_quick_size'))
            .iconSize($r('app.float.photo_viewer_quick_icon_size')).padding(10)
            .iconColor($r('app.color.text_on_brand')).backgroundColor($r('app.color.photo_save_background'))
            .id('photo-viewer-save')
            .onClick((_event: ClickEvent, result: SaveButtonOnClickResult): void => {
              if (result === SaveButtonOnClickResult.SUCCESS) { void this.downloadPhotos(false, true); }
            })
        }
      }.margin({ right: 12 })
      MaterialButton({ buttonWidth: 44, buttonHeight: 44, buttonRadius: 22,
        surfaceColor: $r('app.color.media_viewer_control'), materialLevel: 1, applyShadow: true,
        adaptiveForeground: true,
        lightColor: this.accentColor, accessibilityLabel: this.text($r('app.string.photo_viewer_more')),
        buttonMonopolizeEvents: true, onButtonClick: (): void => { this.showMoreSheet = true; } }) {
        SymbolGlyph($r('sys.symbol.more')).fontSize(24).fontColor([this.controlForeground()])
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: this.statusBarHeight + 16 })
  }

  @Builder
  private BottomControls(): void {
    Column({ space: 18 }) {
      if (this.items.length > 1) {
        Row({ space: 6 }) {
          ForEach(this.items, (item: PhotoViewerPhoto, index: number) => {
            Circle().width(index === this.current ? 8 : 5).height(index === this.current ? 8 : 5)
              .fill(index === this.current ? Color.White : $r('app.color.media_viewer_dot'))
          }, (item: PhotoViewerPhoto): string => item.sourceIndex.toString())
        }
        .height(14)
        .accessibilityText((this.current + 1).toString() + ' / ' + this.items.length)
      }
      if (this.tweet !== null) {
        ForEach([this.tweet], (post: Tweet) => {
          MediaViewerPostActions({
            tweet: post,
            adaptiveForeground: true,
            onOpenPost: (): void => this.openPostSheet(),
            onLike: this.likeAction,
            onRepost: this.repostAction,
            onPostChanged: (changed: Tweet): void => { this.tweet = changed; }
          })
        }, (post: Tweet): string => post.id + '-' + this.postRevision)
        MaterialButton({ buttonWidth: '100%', buttonHeight: 50, buttonRadius: 25,
          surfaceColor: $r('app.color.media_viewer_control'), materialLevel: 1, applyShadow: true,
          adaptiveForeground: true,
          lightColor: this.accentColor, accessibilityLabel: this.text($r('app.string.action_reply')),
          buttonMonopolizeEvents: true,
          onButtonClick: (): void => { if (this.tweet !== null) { this.replyAction(this.tweet); } } }) {
          Text($r('app.string.post_detail_reply_placeholder')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_L')).fontWeight(FontWeight.Medium)
            .fontColor(this.controlForeground(true)).width('100%')
            .padding({ left: 24, right: 24 })
        }
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, bottom: this.navigationIndicatorHeight + 20 })
  }

  @Builder
  private PostSheet(): void {
    if (this.tweet !== null) {
      PostDetail({
        embedded: true,
        initialTweet: this.tweet,
        onEmbeddedPostChanged: (post: Tweet): void => { this.tweet = post; this.postRevision += 1; },
        onEmbeddedNavigate: (): void => this.closePostSheet()
      })
    }
  }

  @Builder
  private MoreRow(symbol: Resource, label: Resource, enabled: boolean, action: () => void): void {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: 18 }) {
        SymbolGlyph(symbol).fontSize(26).fontColor([sheetMaterialActive(this.sheetMaterialEnabled) ?
          $r('sys.color.icon_primary') : $r('app.color.text_on_brand')]).width(30)
        Text(label).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontWeight(FontWeight.Medium)
          .fontColor(sheetMaterialActive(this.sheetMaterialEnabled) ?
            $r('sys.color.font_primary') : $r('app.color.text_on_brand')).layoutWeight(1).textAlign(TextAlign.Start)
      }.width('100%')
    }
    .width('100%').height(56).padding({ left: 20, right: 20 })
    .backgroundColor(Color.Transparent).enabled(enabled).onClick(action)
  }

  @Builder
  private MoreSheet(): void {
    Scroll() {
      Column() {
        if (!(this.currentAnimation() === null &&
          ['photo.background', 'photo.original', 'photo.ocr', 'photo.subject'].some((id: string): boolean => this.menuVisible(id))) &&
          !(this.tweet !== null && (this.menuVisible('photo.post') || this.menuVisible('photo.report'))) &&
          !(this.items.length > 1 && this.menuVisible('photo.save_all'))) {
          Text($r('app.string.settings_menu_empty')).fontFamily(this.appFontFamily)
            .fontColor($r('app.color.text_secondary')).padding(20)
        }
        if (this.currentAnimation() === null && this.menuVisible('photo.background')) {
          this.MoreRow($r('sys.symbol.picture'), $r('app.string.post_photo_save_background'), !this.savingBackground,
            (): void => { void this.saveBackground(); })
        }
        if (this.currentAnimation() === null && this.menuVisible('photo.original')) {
          this.MoreRow($r('sys.symbol.arrow_up_left_and_arrow_down_right'),
            this.originalShown ? $r('app.string.media_original_loaded') : $r('app.string.media_view_original'),
            !this.originalShown, (): void => {
              this.showMoreSheet = false;
              this.originalShown = true;
            })
        }
        if (this.tweet !== null) {
          if (this.menuVisible('photo.post')) {
            this.MoreRow($r('sys.symbol.link'), $r('app.string.video_feed_go_to_post'), true,
              (): void => this.openPostSheet())
          }
          if (this.menuVisible('photo.report')) {
            this.MoreRow($r('sys.symbol.flag'), $r('app.string.video_feed_report_post'), true, (): void => {
              this.showMoreSheet = false;
              if (this.tweet !== null) {
                openExternalLink(getContext(this) as common.UIAbilityContext, postShareUrl(this.tweet));
                promptAction.showToast({ message: this.text($r('app.string.video_feed_report_handoff')) });
              }
            })
          }
        }
        if (this.currentGifVideoUrl().length > 0) {
          this.MoreRow($r('sys.symbol.video'), $r('app.string.gif_action_save_video'), !this.downloading,
            (): void => { this.downloadGifAsVideo(); })
        }
        if (this.items.length > 1) {
          if (this.menuVisible('photo.save_all')) {
            this.MoreRow($r('sys.symbol.download'), $r('app.string.media_download_all_originals'), !this.downloading,
              (): void => { void this.downloadPhotos(true); })
          }
        }
        if (this.currentAnimation() === null && this.menuVisible('photo.ocr')) {
          this.MoreRow($r('sys.symbol.textformat'), $r('app.string.photo_ocr_action'), !this.ocrLoading, (): void => {
            this.showMoreSheet = false; void this.recognizeCurrentPhoto(this.currentDisplayUrl());
          })
        }
        if (this.currentAnimation() === null && this.menuVisible('photo.subject')) {
          this.MoreRow($r('sys.symbol.cut'), $r('app.string.photo_subject_action'), !this.subjectLoading, (): void => {
            this.showMoreSheet = false; void this.cutOutCurrentSubject();
          })
        }
      }.width('100%').padding({ top: 8, bottom: this.navigationIndicatorHeight + 12 })
    }.width('100%').scrollBar(BarState.Auto)
  }

  @Builder
  private ViewerSurface(): void {
      Stack({ alignContent: Alignment.Top }) {
        this.ViewerBackdrop()

        if (this.items.length > 0) {
          Swiper(this.inputPager) {
            ForEach(this.items, (item: PhotoViewerPhoto, index: number) => {
              ZoomablePhoto({
                sourceId: item.sourceId ?? '',
                gifMedia: item.animation ?? null,
                playbackEnabled: this.current === index && !this.closing,
                presentImage: this.motion.visible,
                onImageReady: (): void => { if (this.current === index) { this.initialPhotoReady = true; } },
                canAdoptNode: (): boolean => this.viewerAlive && !this.closing,
                onAdoptNode: (node: MediaPhotoNode, owner: string, url: string): boolean =>
                  this.adoptPhoto(node, owner, url, index),
                url: this.displayUrl(item, index),
                alt: item.altText.length > 0 ? item.altText : this.alt,
                photoWidth: item.width,
                photoHeight: item.height,
                onTransformChanged: (scale: number, x: number, y: number): void => {
                  if (this.current !== index) { return; }
                  this.photoTransformScale = scale;
                  this.photoTransformX = x;
                  this.photoTransformY = y;
                },
                closing: this.photoNeedsReset(),
                onZoomChanged: (zoomed: boolean): void => {
                  if (this.current === index) { this.zoomed = zoomed; }
                },
                onZoomStart: (): void => this.onPhotoZoomStart(index),
                onSingleTap: (): void => this.onPhotoTap(index),
                onLongPress: (url: string): void => {
                  if (this.current === index) {
                    if (!this.showPostSheet && !this.closing) { this.showMoreSheet = true; }
                  }
                },
                onDismissDrag: (progress: number): void => {
                  this.backdropOpacity = 1 - Math.min(0.65, progress * 1.6);
                },
                onDismiss: (): void => {
                  this.close();
                }
              })
            }, (item: PhotoViewerPhoto) => this.viewerSession.toString() + '-' +
              item.sourceIndex.toString() + '-' + item.previewUrl)
          }
          .index(this.current)
          .id(this.motionSurfaceId + '-photo')
          .loop(false)
          .indicator(false)
          .disableSwipe(this.zoomed || this.showPostSheet || this.closing)
          .width('100%')
          .height(this.photoViewportHeight())
          .margin({ top: this.photoViewportTop() })
          .scale({ x: this.postPhotoScale, y: this.postPhotoScale })
          .translate({ y: this.postPhotoOffsetY })
          .renderGroup(true)
          .onAreaChange((_oldValue: Area, newValue: Area): void => {
            const width: number = Number(newValue.width);
            if (width > 0 && width !== this.photoViewportWidth) {
              this.photoViewportWidth = width;
              this.onPhotoViewportChanged();
            }
          })
          .onChange((index: number): void => {
            if (this.closing) { return; }
            this.closeOcrPanel();
            this.closeSubjectPanel();
            this.current = index;
            this.zoomed = false;
            this.photoTransformScale = 1;
            this.photoTransformX = 0;
            this.photoTransformY = 0;
            this.originalShown = false;
            this.backdropOpacity = 1;
          })
        }

        this.PointerPhotoNavigation()
        Stack({ alignContent: Alignment.Top }) {
          Column() {
            this.TopControls()
            if (this.tweet !== null) {
              PhotoViewerAuthorBar({ author: this.tweet.author, onOpenAuthor: (): void => {
                if (this.tweet === null) { return; }
                const param: UserDetailRouteParam = { author: this.tweet.author, posts: [] };
                this.pageStack.pushPath({ name: 'UserDetail', param: param });
              } })
            }
          }
            .width('100%')
            .linearGradient({ angle: 180, colors: [[$r('app.color.photo_viewer_author_scrim'), 0],
              [$r('app.color.photo_viewer_author_scrim'), 0.8], [Color.Transparent, 1]] })
            .translate({ y: this.controlsVisible ? 0 : -12 })
          Stack({ alignContent: Alignment.Bottom }) {
            Column() { this.BottomControls() }
              .width('100%')
              .translate({ y: this.controlsVisible ? 0 : 12 })
          }
          .width('100%')
          .height('100%')
          .hitTestBehavior(HitTestMode.Transparent)
        }
        .width('100%')
        .height('100%')
        .opacity(this.controlsVisible ? this.postControlsOpacity * this.motion.chromeOpacity : 0)
        .renderGroup(true)
        .enabled(this.controlsVisible && !this.showPostSheet)
        .hitTestBehavior(!this.controlsVisible || this.showPostSheet ? HitTestMode.None : HitTestMode.Transparent)
        Column()
          .width(0)
          .height(0)
          .bindSheet($$this.showPostSheet, this.PostSheet(), sheetMaterialOptions({
            height: this.initialPostSheetHeight(),
            detents: [this.initialPostSheetHeight(), SheetSize.LARGE],
            preferType: SheetType.BOTTOM,
            keyboardAvoidMode: SheetKeyboardAvoidMode.RESIZE_ONLY,
            showClose: false,
            dragBar: true,
            maskColor: Color.Transparent,
            radius: { topLeft: 28, topRight: 28 },
            backgroundColor: pageSurfaceColor(this.themeDisplayMode, this.themeDarkSurface),
            onHeightDidChange: (heightPx: number): void => {
              if (!this.showPostSheet) { return; }
              // Sheet callbacks return px; viewport and layout heights use vp.
              this.postSheetHeight = this.getUIContext().px2vp(heightPx);
              this.updatePostSheetPhoto(this.postSheetOpening);
            },
            onAppear: (): void => { this.postSheetOpening = false; },
            onWillDismiss: (action: DismissSheetAction): void => {
              this.closePostSheet();
              action.dismiss();
            },
            // Dismiss directly from the dragged position instead of bouncing first.
            onWillSpringBackWhenDismiss: (): void => {},
            onDisappear: (): void => {
              this.closePostSheet();
              this.postSheetHeight = 0;
              this.postRevision += 1;
            }
          }, this.sheetMaterialEnabled, this.sheetMaterialLevel, this.sheetWindowBreakpoint, ResponsiveLayout.isCompactWindow(this.windowWidth, this.windowHeight)))
        if (this.ocrVisible) {
          this.OcrResultPanel();
        }
        if (this.subjectVisible) {
          this.SubjectPreviewPanel();
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Black)
      // The viewer's own covering layer reaches behind the system status bar and
      // navigation indicator instead of those bars pushing the picture inward.
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .clip(true)
      .bindSheet($$this.showMoreSheet, this.MoreSheet(), this.moreSheetOptions())
      .onAreaChange((_old: Area, area: Area): void => { this.viewerHeight = Number(area.height); })
  }

  private controlForeground(secondary: boolean = false): Resource {
    if (SystemMaterialUtil.isApi26OrAbove()) {
      return secondary ? $r('sys.color.font_secondary') : $r('sys.color.font_primary');
    }
    return secondary ? $r('app.color.media_viewer_placeholder') : $r('app.color.text_on_brand');
  }

  private moreSheetOptions(): SheetOptions {
    const options: SheetOptions = sheetMaterialOptions({
        height: SheetSize.FIT_CONTENT,
        preferType: SheetType.BOTTOM,
        showClose: false,
        dragBar: true,
        radius: { topLeft: 28, topRight: 28 },
        backgroundColor: $r('app.color.media_viewer_sheet'),
        onDisappear: (): void => { this.showMoreSheet = false; }
      }, this.sheetMaterialEnabled, this.sheetMaterialLevel, this.sheetWindowBreakpoint, ResponsiveLayout.isCompactWindow(this.windowWidth, this.windowHeight));
    return options;
  }

  build(): void {
    HdsNavDestination() {
      MediaViewerMotion({ motion: this.motion, surfaceId: this.motionSurfaceId,
        presentation: this.motion.presentation,
        targetId: this.motionSurfaceId + '-photo', contentReady: this.items.length > 0 && this.initialPhotoReady,
        mediaWidth: this.items[this.current]?.width ?? 0, mediaHeight: this.items[this.current]?.height ?? 0 }) {
      Row({ space: 0 }) {
        Column() { this.ViewerSurface() }.height('100%').layoutWeight(1).backgroundColor(Color.Black)
          .focusable(true).defaultFocus(true)
          .onKeyEvent((event: KeyEvent): boolean => this.photoInputKey(event))
          .onHover((hover: boolean): void => { this.pointerHover = hover; })
          .onMouse((event: MouseEvent): void => contextInputMouse(event, (): void => {
            if (!this.closing && !this.showPostSheet && !this.ocrVisible && !this.subjectVisible) { this.showMoreSheet = true; }
          }))
        if (this.desktop() && this.tweet !== null) {
          Column() { this.PostSheet() }.width('44%').height('100%')
            .backgroundColor(pageSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
            .border({ width: { left: 0.5 }, color: $r('app.color.divider') })
        }
      }.width('100%').height('100%')
        .backgroundColor(Color.Black).clip(true)
        .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM,
          LayoutSafeAreaEdge.START, LayoutSafeAreaEdge.END])
      }
    }
    .mode(NavDestinationMode.DIALOG)
    .systemTransition(pageSystemTransition(this.pageTransitionMode, this.motion.enabled() ? NavigationSystemTransitionType.NONE :
      this.photoFullscreen && DesktopLayout.active(this.desktopLayoutEnabled, this.breakpoint) ?
      NavigationSystemTransitionType.FADE : NavigationSystemTransitionType.DEFAULT))
    .onReady((context: NavDestinationContext): void => {
      const param: PhotoViewerRouteParam = context.pathInfo?.param as PhotoViewerRouteParam;
      if (param !== undefined && param !== null &&
        (param.urls.length > 0 || (param.items !== undefined && param.items.length > 0))) {
        this.readRoute(param);
      }
    })
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .hideTitleBar(true)
    .hideBackButton(true)
    .width('100%').height('100%').borderRadius(0)
    .backgroundColor(Color.Transparent)
    .clip(true)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM,
      LayoutSafeAreaEdge.START, LayoutSafeAreaEdge.END])
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])
    .onShown((): void => {
      if (this.screenBlocked) { setChatWindowPrivacy(this.getUIContext().getHostContext() as common.UIAbilityContext, true); }
    })
    .onWillHide((): void => {
      if (this.screenBlocked) { setChatWindowPrivacy(this.getUIContext().getHostContext() as common.UIAbilityContext, false); }
    })
    .onBackPressed((): boolean => this.inputBack())
    .onKeyEvent((event: KeyEvent): boolean => backInputKey(event, (): void => { this.inputBack(); }))
    ;
  }
}
