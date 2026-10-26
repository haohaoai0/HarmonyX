import { MediaDownloadButton } from './MediaDownloadButton';
import { STORAGE_KEY_VIDEO_DOWNLOAD_BUTTON } from '../services/MediaSettingsStore';
import { postUsesHorizontalMediaStrip } from '../utils/PostMediaStrip';
import { mediaAvatarPanProgress } from '../utils/PostMediaAvatarMotion';
import { InputModalScope } from '../utils/InputModalScope';
import { KeyCode } from '@kit.InputKit';
import { activateInputKey, plainInputKey, contextInputMouse } from '../utils/InputSupport';
// Media renderer shared by the timeline, the search results and the post
// detail page.
//
// Three rules shape this file, all of them about how a cell behaves while its
// video is still on the way:
//
//   * A Video paints nothing but black until its first frame is decoded, and a
//     remote video takes a while to get there. Every player therefore sits
//     under the post's own cover, and that cover is lifted only once the
//     player reports progress. A stream that is slow, blocked or broken keeps
//     the cover, so a cell never degrades into an empty black rectangle.
//   * X answers a search with the video renditions and no still image at all,
//     which is why those cells used to have no cover. A frame is decoded from
//     the video instead, one cell ahead of the reader, and cached per media id.
//   * Several videos can be on screen at once — a post may carry four and a
//     list shows several posts — so every cell that is far enough into the
//     viewport streams on its own instead of the page electing one winner. The
//     election used to hand the video the reader had just tapped back to its
//     cover the moment another cell scrolled in, which is exactly the video
//     that was being watched. Each cell uses the selected rendition and can
//     step through parsed variants when its current stream stalls.
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import type { MediaAttachment, Tweet, VideoRendition } from '../models/Tweet';
import { STORAGE_KEY_VIDEO_HDR_ENHANCEMENT, DEFAULT_VIDEO_HDR_ENHANCEMENT } from '../services/MediaSettingsStore';
import { STORAGE_KEY_VIDEO_HDR_SUPPORTED, VideoHdrEnhancementModifier } from '../services/VideoHdrEnhancement';
import { videoKeepAwake } from '../services/VideoKeepAwake';
import { appWindowOrientation, STORAGE_KEY_VIDEO_FULLSCREEN_OWNER } from '../utils/AppWindowOrientation';
import { normalizedPostMediaType, postGifHeight } from '../utils/PostGif';
import { GifPreviewImage } from './GifPreviewImage';
import { LandscapeVideoControls } from './LandscapeVideoControls';
import { MaterialButton } from './MaterialButton';
import { SystemMaterialUtil } from '../utils/SystemMaterial';
import { MediaPhotoSurface, mediaPhotoNodeFor } from './MediaPhotoSurface';
import { PhotoStripLayout, photoStripLayout } from '../utils/PostPhotoLayout';
import { MediaCommentLayout, MediaCommentLayoutInput, mediaCommentLayout } from '../utils/MediaCommentLayout';
import { image } from '@kit.ImageKit';
import { fileUri, fileIo } from '@kit.CoreFileKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { systemShare } from '@kit.ShareKit';
import { PiPWindow, SymbolGlyphModifier, uiMaterial, window } from '@kit.ArkUI';
import { AICaptionComponent, AICaptionController, AICaptionFontSize, AICaptionOptions } from '@kit.SpeechKit';
// Aliased so the AVPlayer types never collide with the `media` cell parameter
// used all over this file.
import { media as mediaKit } from '@kit.MediaKit';
import { avSession } from '@kit.AVSessionKit';
import { hapticTick } from '../utils/Haptics';
import { BusinessError, deviceInfo } from '@kit.BasicServicesKit';
import { videoMediaSession, VideoPlaybackHandle } from '../services/VideoMediaSession';
import { videoPipGate } from '../services/VideoPipGate';
import { videoPosterStore, videoPosterSource, videoPosterRendition } from '../services/VideoPosterStore';
import { videoPlaybackCache, VideoCacheLease, VideoDataSourceLease } from '../services/VideoPlaybackCache';
import { videoPlaybackPositionStore } from '../services/VideoPlaybackPositionStore';
import { requestVideoViewer } from '../utils/VideoViewerRequest';
import { captureMediaViewerSource, createMediaSourcePrefix, MediaViewerSource,
  pendingMediaViewerSource } from '../utils/MediaViewerMotion';
import { videoPlaybackCoordinator, STORAGE_KEY_VIDEO_FEED_ACTIVE } from '../services/VideoPlaybackCoordinator';
import { videoPlayerHandoff, VideoPlayerHandoffPayload, VideoPlayerReturnTarget } from '../services/VideoPlayerHandoff';
import { videoPlayerPreparation } from '../services/VideoPlayerPreparation';
import { proxyStore } from '../services/ProxyStore';
import { videoRangeSource } from '../services/VideoRangeSource';
import { videoNetworkEstimate } from '../services/VideoNetworkEstimate';
import { inlineVideoGate } from '../services/InlineVideoGate';
import { common } from '@kit.AbilityKit';
import promptAction from '@ohos.promptAction';
import hilog from '@ohos.hilog';
import {
  MEDIA_DOWNLOAD_CANCELED,
  MEDIA_DOWNLOAD_FAILED,
  MEDIA_DOWNLOAD_SAVED_AS_VIDEO,
  MEDIA_DOWNLOAD_SUCCESS,
  mediaDownloadService
} from '../services/MediaDownloadService';
import { proxyDownloadService } from '../services/ProxyDownloadService';
import {
  PhotoViewerPhoto,
  requestPhotoViewer
} from '../utils/PhotoViewerRequest';
import {
  DEFAULT_CAPTION_OPACITY,
  DEFAULT_VIDEO_AUTO_BITRATE_CAP,
  IMAGE_QUALITY_DATA_SAVER,
  IMAGE_QUALITY_ORIGINAL,
  imageUrlForQuality,
  mediaSettingsStore,
  STORAGE_KEY_CAPTION_OPACITY,
  STORAGE_KEY_VIDEO_COMMENT_PROGRESS_RING,
  STORAGE_KEY_HOME_VIDEO_MUTED,
  STORAGE_KEY_VIEWER_VIDEO_MUTED,
  STORAGE_KEY_SHOW_SENSITIVE_MEDIA,
  STORAGE_KEY_VIDEO_AUTO_PIP,
  STORAGE_KEY_VIDEO_AUTOPLAY,
  STORAGE_KEY_VIDEO_BACKGROUND_MODE,
  STORAGE_KEY_VIDEO_CONTROL_STYLE,
  STORAGE_KEY_VIDEO_FEED_CONTROLS_ALWAYS_VISIBLE,
  STORAGE_KEY_VIDEO_FEED_TAP_PAUSE,
  STORAGE_KEY_VIDEO_AUTO_BITRATE_CAP,
  STORAGE_KEY_VIDEO_HOLD_SPEED,
  STORAGE_KEY_VIDEO_DOUBLE_TAP_SEEK,
  STORAGE_KEY_VIDEO_DOUBLE_TAP_SEEK_SECONDS,
  DEFAULT_VIDEO_DOUBLE_TAP_SEEK_ENABLED,
  DEFAULT_VIDEO_DOUBLE_TAP_SEEK_SECONDS,
  normalizeVideoDoubleTapSeekSeconds,
  videoHoldSpeedLabel,
  VIDEO_HOLD_SPEED_RATE,
  VIDEO_HOLD_SPEED_MAX_RATE,
  VIDEO_HOLD_SPEED_MIN_RATE,
  VIDEO_HOLD_SPEED_STEP_RATE,
  VIDEO_BACKGROUND_AUDIO,
  VIDEO_BACKGROUND_PIP,
  VIDEO_CONTROL_STYLE_ORIGINAL,
  VIDEO_CONTROL_STYLE_SPACED,
  VIDEO_QUALITY_DATA_SAVER,
  VIDEO_QUALITY_HIGH,
  VIDEO_QUALITY_SD,
  VIDEO_QUALITY_LD
} from '../services/MediaSettingsStore';
import { videoBackgroundPlayback } from '../services/VideoBackgroundPlayback';
import { videoPipPlaybackKeeper, VideoPipPlaybackHandle } from '../services/VideoPipPlaybackKeeper';
import { VideoDownloadChoice, videoDownloadChoices } from '../services/VideoDownloadChoice';
import { gifVideoDownloadUrl } from '../services/GifDownloadChoice';
import { HdsButton } from './HdsButton';
import { ProxyMediaImage } from './ProxyMediaImage';
import { PostMediaActions } from './PostMediaActions';
import { VideoFeedBackdrop } from './VideoFeedBackdrop';
import { VideoHoldSpeedCapsule } from './VideoHoldSpeedCapsule';
import { MAIN_NAVIGATION_ID } from '../utils/NavigationIdentity';
import { fieldSurfaceColor } from '../utils/ThemeColors';
import { pageTextColor } from '../utils/ThemeColors';
import { materialModifier } from '../utils/SystemMaterial';

const DOMAIN = 0xFF00;
const TAG = 'HarmonyX-Media';
const MEDIA_HEIGHT: number = 228;
const VIDEO_FEED_WIDE_BREAKPOINT: number = 840;
const VIDEO_FEED_COMPACT_HEIGHT_RATIO: number = 0.58;
const VIDEO_FEED_WIDE_HEIGHT_RATIO: number = 0.82;
// Only bridge a small height mismatch; larger letterboxes retain the full frame.
const VIDEO_FEED_EDGE_FILL_MAX_SCALE: number = 1.06;
// Fraction of a cell that has to be on screen before its video starts
// buffering. Starting below one half is deliberate: the stream has a moment to
// open while the reader finishes scrolling the cell into place.
const PLAY_RATIO: number = 0.35;
// Fraction at which the neighbouring cell's cover is decoded, so the next
// video already shows artwork when it arrives.
const COVER_RATIO: number = 0.05;
// The surface can still hold the pre-roll frame right after onStart, so the
// cover is lifted on the first progress report and, failing that, shortly
// after playback begins.
const PROGRESS_FALLBACK_MS: number = 600;
const REMOUNT_DELAY_MS: number = 80;
const FIRST_FRAME_TIMEOUT_MS: number = 12000;
const BUFFER_STALL_TIMEOUT_MS: number = 16000;
const VIDEO_SOURCE_RETRY_DELAY_MS: number = 500;
const VIDEO_FEED_PRELOAD_DURATION_MS: number = 2600;
const HOLD_SEEK_DURATION_MS: number = 500;
const HOLD_SEEK_STEP_SECONDS: number = 5;
// Dragging the held finger this far changes the temporary speed by one step.
const HOLD_SPEED_STEP_VP: number = 40;
// Press this long to start the temporary speed, and give the press back to the
// list as soon as the finger travels this far before then.
const HOLD_SPEED_HOLD_MS: number = 500;
const HOLD_SPEED_SLOP_VP: number = 12;
// Covers requested in this page. Bounded so a long result list cannot decode
// every video it contains.
const MAX_COVER_IDS: number = 24;
// Keep the latest inline player alive while its home feed row remains in the
// List's cached range. The row itself is already bounded by cachedCount(8).
const MAX_RETAINED_INLINE_PLAYERS_PER_POST: number = 1;

function isVideoLike(media: MediaAttachment): boolean {
  return media.type === 'video' || isAnimatedGif(media);
}

function isAnimatedGif(media: MediaAttachment): boolean {
  return normalizedPostMediaType(media.type) === 'animated_gif';
}

function maxNaturalVideoDisplayHeight(windowWidth: number, windowHeight: number): number {
  if (windowHeight <= 0) {
    return MEDIA_HEIGHT;
  }
  const wideLandscape: boolean = windowWidth >= VIDEO_FEED_WIDE_BREAKPOINT && windowWidth > windowHeight;
  const heightRatio: number = wideLandscape ? VIDEO_FEED_WIDE_HEIGHT_RATIO : VIDEO_FEED_COMPACT_HEIGHT_RATIO;
  return Math.max(MEDIA_HEIGHT, windowHeight * heightRatio);
}

// Inline playback uses the small rendition; the heavy one is kept for
// fullscreen, where the extra detail is actually visible.
function streamSource(media: MediaAttachment, videoQuality: number,
  autoBitrateCap: number = DEFAULT_VIDEO_AUTO_BITRATE_CAP): string {
  const renditions: VideoRendition[] = media.videoVariants ?? [];
  if (renditions.length > 0) {
    if (videoQuality === VIDEO_QUALITY_HIGH) {
      return renditions[renditions.length - 1].url;
    }
    if (videoQuality === VIDEO_QUALITY_LD) {
      return renditions[0].url;
    }
    if (videoQuality === VIDEO_QUALITY_SD) {
      let selected: VideoRendition = renditions[0];
      for (let index: number = 0; index < renditions.length; index++) {
        const candidate: VideoRendition = renditions[index];
        if (candidate.bitrate > 1800000) {
          break;
        }
        selected = candidate;
      }
      return selected.url;
    }
    // Auto starts from the highest modest rendition available. If it stalls,
    // the retry path walks down to lighter variants first.
    // A fast nominal link must not force a heavy first rendition. Auto favors
    // prompt startup; explicit HD remains available without this ceiling.
    const configuredCap: number = Math.min(autoBitrateCap > 0 ? autoBitrateCap : DEFAULT_VIDEO_AUTO_BITRATE_CAP,
      DEFAULT_VIDEO_AUTO_BITRATE_CAP);
    const bitrateCap: number = videoNetworkEstimate.bitrateCap(renditions[0].url, configuredCap);
    let selected: VideoRendition = renditions[0];
    for (let index: number = 0; index < renditions.length; index++) {
      const candidate: VideoRendition = renditions[index];
      if (candidate.bitrate > bitrateCap) {
        break;
      }
      selected = candidate;
    }
    return selected.url;
  }
  if (videoQuality === VIDEO_QUALITY_HIGH || media.feedUrl.length === 0) {
    return media.mediaUrl;
  }
  return media.feedUrl;
}

// The cover of a cell in either state: the still image X shipped with the
// post, a frame decoded from the video when the payload carried none, or the
// shape of a player as a last resort.
@Component
struct MediaCover {
  @Prop photoSourceId: string = '';
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Prop media: MediaAttachment;
  @Prop imageQuality: number = IMAGE_QUALITY_ORIGINAL;
  @Prop videoQuality: number = VIDEO_QUALITY_DATA_SAVER;
  @Prop mediaHeight: number = MEDIA_HEIGHT;
  @Prop videoContain: boolean = false;
  @Prop photoContain: boolean = false;
  @Prop cornerRadius: number = 14;
  // Explore's promoted hero begins as an ambient looping video, so its cover
  // deliberately omits the usual central play affordance.
  @Prop minimalVideoControls: boolean = false;
  @StorageProp('harmonyx.display_mode') private themeDisplayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private themeDarkSurface: string = '';
  // Set by the list while the cell is approaching the viewport. Covers are
  // decoded just ahead of the reader rather than for every post in the result.
  @Prop @Watch('onWantsChanged') wants: boolean = false;
  @StorageLink(STORAGE_KEY_VIDEO_AUTO_BITRATE_CAP) @Watch('onAutoBitrateCapChanged')
  autoBitrateCap: number = DEFAULT_VIDEO_AUTO_BITRATE_CAP;
  // Spinner while the video the reader is waiting for is still opening.
  @Prop spinner: boolean = false;
  @Prop failed: boolean = false;
  onTap: () => void = (): void => {
  };
  onLongPress: () => void = (): void => {};
  @State private pixels: image.PixelMap | null = null;
  private alive: boolean = true;

  aboutToAppear(): void {
    this.alive = true;
    this.pickUp();
  }

  aboutToDisappear(): void {
    this.alive = false;
  }

  onWantsChanged(): void {
    this.pickUp();
  }

  private onAutoBitrateCapChanged(): void {
    this.pickUp();
  }

  private isLoop(): boolean {
    return isAnimatedGif(this.media);
  }

  private imageSource(url: string): string {
    return isVideoLike(this.media) ? url : imageUrlForQuality(url, this.imageQuality);
  }

  private pickUp(): void {
    if (this.pixels !== null || this.media.previewUrl.length > 0) {
      return;
    }
    // A frame that was decoded earlier is reused without any network work, so
    // scrolling back up still shows artwork.
    const ready: image.PixelMap | null = videoPosterStore.cached(this.media.id);
    if (ready !== null) {
      this.pixels = ready;
      return;
    }
    if (!this.wants || !isVideoLike(this.media)) {
      return;
    }
    const source: string = videoPosterSource(this.media);
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    videoPosterStore.load(this.media.id, source, context, videoPosterRendition(this.media, source))
      .then((frame: image.PixelMap | null): void => {
        if (this.alive && frame !== null) {
          this.pixels = frame;
        }
      });
  }

  // Clip length chip for promoted media; minutes:seconds as in the store page.
  private durationBadgeLabel(): string {
    const total: number = Math.max(0, Math.round((this.media.durationMs ?? 0) / 1000));
    const minutes: number = Math.floor(total / 60);
    const seconds: number = total % 60;
    return minutes.toString() + ':' + (seconds < 10 ? '0' : '') + seconds.toString();
  }

  @Builder
  private Still(): void {
    if (this.isLoop() && this.media.previewUrl.length > 0) {
      GifPreviewImage({
        url: '',
        previewUrl: this.media.previewUrl,
        displayHeight: this.mediaHeight,
        surfaceColor: fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface)
      })
        .borderRadius(this.cornerRadius)
        .clip(true)
    } else if (!isVideoLike(this.media) && this.photoSourceId.length > 0) {
      MediaPhotoSurface({ sourceId: this.photoSourceId,
        url: this.imageSource(this.media.previewUrl.length > 0 ? this.media.previewUrl : this.media.mediaUrl),
        displayHeight: this.mediaHeight, contain: this.photoContain })
        .borderRadius(this.cornerRadius).clip(true)
    } else if (this.media.previewUrl.length > 0) {
      ProxyMediaImage({
        url: this.imageSource(this.media.previewUrl),
        displayHeight: this.mediaHeight,
        contain: this.photoContain || (this.videoContain && isVideoLike(this.media)),
        surfaceColor: fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface)
      })
        .borderRadius(this.cornerRadius)
        .clip(true)
    } else if (!isVideoLike(this.media) && this.media.mediaUrl.length > 0) {
      ProxyMediaImage({
        url: this.imageSource(this.media.mediaUrl),
        displayHeight: this.mediaHeight,
        contain: this.photoContain,
        surfaceColor: fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface)
      })
        .borderRadius(this.cornerRadius)
        .clip(true)
    } else if (this.pixels !== null) {
      Image(this.pixels)
        .width('100%')
        .height(this.mediaHeight)
        .objectFit(this.videoContain || this.photoContain ? ImageFit.Contain : ImageFit.Cover)
        .backgroundColor(fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
        .borderRadius(this.cornerRadius)
        .clip(true)
    } else {
      Column()
        .width('100%')
        .height(this.mediaHeight)
        .borderRadius(this.cornerRadius)
        .backgroundColor(fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
    }
  }

  build(): void {
    Stack({ alignContent: Alignment.Center }) {
      this.Still()
      // Promoted media asks for its clip length on the tile; ordinary posts keep
      // the current look because the flag stays off.
      if (isVideoLike(this.media) && this.media.showDurationBadge === true && this.media.durationMs !== undefined &&
        this.media.durationMs > 0) {
        Column() {
          Text(this.durationBadgeLabel())
            .fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_S'))
            .fontColor(Color.White)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .backgroundColor('#99000000')
            .borderRadius(6)
        }
        .width('100%')
        .height('100%')
        .padding(8)
        .justifyContent(FlexAlign.End)
        .alignItems(HorizontalAlign.End)
        .hitTestBehavior(HitTestMode.Transparent)
        .accessibilityLevel('no')
      }
      Column({ space: 10 }) {
        if (isVideoLike(this.media) && !this.isLoop() && !this.minimalVideoControls) {
          Stack() {
            SymbolGlyph($r('sys.symbol.play_fill'))
              .fontSize(22)
              .fontColor([$r('app.color.text_on_brand')])
          }
          .width(48)
          .height(48)
          .borderRadius(24)
          .backgroundColor('#99000000')
          .alignContent(Alignment.Center)
        }
        // The stream is still opening: say so, instead of leaving the reader
        // to guess whether the cell is stuck.
        if (this.spinner && !this.failed) {
          LoadingProgress()
            .width(24)
            .height(24)
            .color($r('app.color.text_on_brand'))
        }
      }
      if (this.failed && (!this.isLoop() || this.media.previewUrl.length === 0)) {
        Text(this.isLoop() ? $r('app.string.post_gif_failed') : $r('app.string.media_video_failed')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('app.color.text_on_brand'))
          .backgroundColor('#99000000')
          .borderRadius(12)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .margin({ top: 74 })
      }
    }
    .width('100%')
    .height(this.mediaHeight)
    // Media sits inside a card that also opens the post. Without event
    // monopoly one tap can push both PhotoViewer and PostDetail, leaving two
    // shared-element transitions fighting over the return path.
    .monopolizeEvents(true)
    .gesture(GestureGroup(GestureMode.Exclusive,
      LongPressGesture({ fingers: 1, repeat: false, duration: 500 })
        .onAction((): void => this.onLongPress()),
      TapGesture({ count: 1, fingers: 1 })
        .onAction((): void => this.onTap())
    ))
  }
}

// ---- Shared video player ----------------------------------------------------
//
// Every video in the app plays through this component: the timeline, search
// results, profiles, bookmarks, list timelines, the replies under a post and
// the post detail page all render it, so they share one control row instead of
// the built-in Video component's own bar.
//
// It is built on AVPlayer and an XComponent of type SURFACE because that is the
// only kind of surface HarmonyOS migrates into the system picture-in-picture
// window. One player therefore covers the whole feature set: the playback row
// (play/pause, scrubber, sound, fullscreen, picture-in-picture), the row sliding
// away while the video runs, and — on the post detail page — handing the surface
// to the floating window when the reader scrolls on to the comments.

// Adapts the AVPlayer to the system media session, which only needs these three
// calls, so fullscreen playback still answers the control centre.
class SurfacePlaybackHandle implements VideoPlaybackHandle {
  onCastState: (casting: boolean, state: avSession.AVPlaybackState | undefined) => void =
    (casting: boolean, state: avSession.AVPlaybackState | undefined): void => {};
  onCastFailed: () => void = (): void => {};
  onStart: () => void = (): void => {
  };
  onPause: () => void = (): void => {
  };
  onSeek: (seconds: number) => void = (): void => {
  };

  startPlayback(): void {
    this.onStart();
  }

  pausePlayback(): void {
    this.onPause();
  }

  seekPlayback(seconds: number): void {
    this.onSeek(seconds);
  }

  castStateChanged(casting: boolean, state: avSession.AVPlaybackState | undefined): void {
    this.onCastState(casting, state);
  }

  castFailed(): void {
    this.onCastFailed();
  }
}

class SurfacePipPlaybackHandle implements VideoPipPlaybackHandle {
  private mediaId: string = '';
  private resume: () => void = (): void => {
  };

  update(mediaId: string, resume: () => void): void {
    this.mediaId = mediaId;
    this.resume = resume;
  }

  id(): string {
    return this.mediaId;
  }

  resumePipPlayback(): void {
    this.resume();
  }
}

const PLAYER_BAR_HEIGHT: number = 56;
const INLINE_VIDEO_CONTROLS_HEIGHT: number = 56;
// 44vp seek target + 12vp separation + 48vp buttons + 8vp bottom padding.
export const VIDEO_FEED_CONTROLS_HEIGHT: number = 112;
const INLINE_PROGRESS_LINE_HEIGHT: number = 28;
const INLINE_CONTROL_PANEL_HEIGHT: number = PLAYER_BAR_HEIGHT + 22 + 4;
const FULLSCREEN_CONTROL_PANEL_HEIGHT: number = 94;
const LEGACY_INLINE_CONTROL_PANEL_HEIGHT: number = 64;
const LEGACY_FULLSCREEN_CONTROL_PANEL_HEIGHT: number = 88;
const FULLSCREEN_PLAYBACK_RATES: number[] = [0.75, 1, 1.25, 1.5, 2];
const PLAYER_PLAY_RATIO: number = 0.35;
const PLAYER_HIDE_RATIO: number = 0.05;
// Once playback is running the control row gets out of the way; tapping the
// picture only changes the control row's visibility.
const CONTROLS_HIDE_DELAY_MS: number = 3000;
const LANDSCAPE_CONTROLS_HIDE_DELAY_MS: number = 15000;
const PIP_FALLBACK_WIDTH: number = 1280;
const PIP_FALLBACK_HEIGHT: number = 720;
const PIP_SEEK_STEP_SECONDS: number = 10;
const AI_CAPTION_INLINE_HEIGHT: number = 64;
const AI_CAPTION_FULLSCREEN_PORTRAIT_HEIGHT: number = 84;
const AI_CAPTION_FULLSCREEN_LANDSCAPE_HEIGHT: number = 60;
const AI_CAPTION_VIDEO_EDGE_GAP: number = 14;
const AI_CAPTION_INLINE_SCALE: number = 0.9;
const AI_CAPTION_FULLSCREEN_SCALE: number = 0.82;
const AI_CAPTION_INLINE_X_OFFSET: number = -28;
const AI_CAPTION_INLINE_Y_OFFSET: number = 0;
const AI_CAPTION_FULLSCREEN_PORTRAIT_X_OFFSET: number = -24;
const AI_CAPTION_FULLSCREEN_LANDSCAPE_X_OFFSET: number = -18;
// Pinch is deliberately a fullscreen-only gesture. Its thresholds keep small
// two-finger corrections from unexpectedly cropping the picture.
const FULLSCREEN_PINCH_DISTANCE: number = 16;
const FULLSCREEN_PINCH_FILL_THRESHOLD: number = 1.08;
const FULLSCREEN_PINCH_FIT_THRESHOLD: number = 0.92;
const FULLSCREEN_PINCH_HINT_DURATION_MS: number = 1400;
const FULLSCREEN_PAN_DISTANCE: number = 12;
const FULLSCREEN_GESTURE_HINT_DURATION_MS: number = 1000;
const FULLSCREEN_GESTURE_NONE: number = 0;
const FULLSCREEN_GESTURE_SEEK: number = 1;
const FULLSCREEN_GESTURE_VOLUME: number = 2;
const FULLSCREEN_GESTURE_BRIGHTNESS: number = 3;
const FULLSCREEN_GESTURE_FEED: number = 4;

class DecodedVideoSize {
  width: number = 0;
  height: number = 0;

  constructor(width: number, height: number) {
    this.width = width;
    this.height = height;
  }
}

const decodedVideoSizeCache: Map<string, DecodedVideoSize> = new Map<string, DecodedVideoSize>();

function clockLabel(seconds: number): string {
  const total: number = seconds > 0 ? Math.floor(seconds) : 0;
  const minutes: number = Math.floor(total / 60);
  const rest: number = total % 60;
  return minutes.toString() + ':' + (rest < 10 ? '0' : '') + rest.toString();
}

@Component
export struct SurfaceVideoPlayer {
  @StorageProp(STORAGE_KEY_VIDEO_DOWNLOAD_BUTTON) private videoDownloadButton: boolean = true;
  @Prop sourceTweet: Tweet | null = null;
  @Prop viewerDanmakuEnabled: boolean = false;
  @Prop viewerAuthorFollowing: boolean = false;
  @Prop viewerDownloading: boolean = false;
  onViewerDownload: () => void = (): void => {};
  onViewerFollow: () => void = (): void => {};
  onViewerComment: () => void = (): void => {};
  onViewerDanmakuToggle: () => void = (): void => {};
  onViewerDanmakuSend: () => void = (): void => {};
  @StorageProp(STORAGE_KEY_VIDEO_HDR_ENHANCEMENT) private videoHdrEnhancement: boolean = DEFAULT_VIDEO_HDR_ENHANCEMENT;
  @StorageProp(STORAGE_KEY_VIDEO_HDR_SUPPORTED) private videoHdrSupported: boolean = false;
  @StorageProp('harmonyx.page_background') private pageBackgroundValue: string = '';
  @Prop controlsUsePageBackground: boolean = false;
  @Prop controlSurface: ResourceColor = Color.Transparent;
  private controlMaterial: uiMaterial.Material | undefined = undefined;
  @Prop transitionSourceId: string = '';
  onViewerSurfaceReady: () => void = (): void => {};
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Prop @Watch('onCastRequested') castRequestSerial: number = 0;
  @Prop @Watch('onViewerFullscreenRequested') viewerFullscreenRequest: number = 0;
  @State private casting: boolean = false;
  @StorageLink('harmonyx.video_feed_elapsed_time') private feedElapsedTime: boolean = false;
  onViewerCastPickerChanged: (visible: boolean) => void = (visible: boolean): void => {};
  onViewerCastingChanged: (casting: boolean) => void = (casting: boolean): void => {};
  @Prop @Watch('onMediaChanged') media: MediaAttachment;
  @Prop imageQuality: number = IMAGE_QUALITY_ORIGINAL;
  @Prop @Watch('onVideoQualityChanged') videoQuality: number = VIDEO_QUALITY_DATA_SAVER;
  @StorageLink(STORAGE_KEY_VIDEO_AUTO_BITRATE_CAP) @Watch('onAutoBitrateCapChanged')
  autoBitrateCap: number = DEFAULT_VIDEO_AUTO_BITRATE_CAP;
  @Prop @Watch('onManualStartChanged') manualStart: boolean = false;
  @Prop @Watch('onPlaybackEnabledChanged') playbackEnabled: boolean = true;
  @Prop @Watch('onPreloadEnabledChanged') preloadEnabled: boolean = false;
  @Prop initialPositionSeconds: number = 0;
  @Prop naturalVideoSize: boolean = false;
  @Prop limitNaturalHeight: boolean = false;
  // Feed previews and players share a frame, independent of decoder rendition.
  @Prop inlineFrameHeight: number = 0;
  @Prop persistentInlinePreview: boolean = false;
  onInlinePreviewHidden: (hidden: boolean) => void = (): void => {};
  @Prop @Watch('onVideoScaleModeChanged') immersiveVideo: boolean = false;
  @Prop @Watch('onVideoScaleModeChanged') fillVideoViewport: boolean = false;
  @Prop @Watch('onVideoScaleModeChanged') containVideo: boolean = false;
  @Prop @Watch('applyVideoScaleType') videoViewportHeight: number = 0;
  @Prop controlsAtScreenBottom: boolean = false;
  @Prop hideInlineControls: boolean = false;
  @Prop @Watch('applyVideoScaleType') compactFeedLayout: boolean = false;
  @Prop compactBottomActions: boolean = false;
  @Prop mediaViewerLayout: boolean = false;
  @Prop viewerUsesSideComments: boolean = false;
  @Prop viewerPhoneFeedLayout: boolean = false;
  @Prop viewerCommentProgress: number = 0;
  @Prop viewerCommentTop: number = 0;
  @Prop viewerCommentHeight: number = 0;
  @Prop retainViewerPlayback: boolean = false;
  @BuilderParam landscapePostContent: () => void = this.EmptyLandscapePost;
  @BuilderParam viewerDanmakuContent: () => void = this.EmptyLandscapePost;
  @BuilderParam compactFeedActions: () => void = this.EmptyLandscapePost;
  onViewerBack: () => void = (): void => {};
  onViewerMore: () => void = (): void => {};
  onViewerCommentDismiss: () => void = (): void => {};
  @Prop fullscreenFeedSwipeEnabled: boolean = false;
  onFullscreenFeedSwipe: () => void = (): void => {};
  onViewerControlsChanged: (visible: boolean) => void = (visible: boolean): void => {};
  onViewerVideoTap: () => void = (): void => {};
  // Inline posts use the media menu; the viewer keeps its playback hold gesture.
  onMenuRequest: () => void = (): void => {};
  @StorageProp(STORAGE_KEY_VIDEO_FEED_TAP_PAUSE) private videoFeedTapPause: boolean = false;
  @Prop adaptiveShortVideo: boolean = false;
  @Prop forceUnmuted: boolean = false;
  @Prop homeTimelineVideo: boolean = false;
  // The Explore hero is intentionally an ambient preview: it loops, starts
  // silently, and delegates its sole mute control to the card overlay.
  @Prop exploreHeroVideo: boolean = false;
  @Prop linkCardVideo: boolean = false;
  onLinkCardOpen: () => void = (): void => {};
  @Prop @Watch('onExploreHeroMutedChanged') exploreHeroMuted: boolean = true;
  @Prop playerBarBottomOffset: number = 12;
  @Prop @Watch('onCaptionRequestedChanged') captionRequested: boolean = false;
  // Only the post detail page hands a running video to the floating window on
  // its own; everywhere else the reader asks for it from the control row.
  @Prop allowPip: boolean = false;
  @Prop pipNavigationHandleId: number = -1;
  onPipIntent: () => void = (): void => {
  };
  onFullscreenIntent: (positionSeconds: number) => boolean = (positionSeconds: number): boolean => {
    return false;
  };
  onCaptionChanged: (shown: boolean) => void = (): void => {
  };
  onPlaybackCompleted: () => void = (): void => {
  };
  onPlaybackStateChanged: (playing: boolean) => void = (playing: boolean): void => {
  };
  // The viewer draws its own rate capsule below the back/more row, so the
  // hold state is reported upward as well as drawn here.
  onHoldSpeedChanged: (active: boolean, rate: number) => void = (active: boolean, rate: number): void => {
  };
  onInitialPositionApplied: () => void = (): void => {
  };
  @StorageLink(STORAGE_KEY_VIDEO_AUTOPLAY) videoAutoplay: boolean = true;
  @StorageProp(STORAGE_KEY_VIDEO_COMMENT_PROGRESS_RING) videoCommentProgressRing: boolean = true;
  @StorageProp(STORAGE_KEY_VIDEO_FEED_ACTIVE) @Watch('onVideoFeedActiveChanged')
  videoFeedActive: boolean = false;
  @StorageLink(STORAGE_KEY_HOME_VIDEO_MUTED) @Watch('onHomeVideoMutedChanged')
  homeVideoMuted: boolean = true;
  @StorageLink(STORAGE_KEY_VIEWER_VIDEO_MUTED) @Watch('onViewerVideoMutedChanged')
  viewerVideoMuted: boolean = true;
  @StorageLink(STORAGE_KEY_VIDEO_AUTO_PIP) autoPip: boolean = true;
  @StorageLink(STORAGE_KEY_VIDEO_CONTROL_STYLE) videoControlStyle: number = VIDEO_CONTROL_STYLE_SPACED;
  @StorageLink(STORAGE_KEY_VIDEO_FEED_CONTROLS_ALWAYS_VISIBLE)
  @Watch('onVideoFeedControlsAlwaysVisibleChanged')
  videoFeedControlsAlwaysVisible: boolean = false;
  // Holding a playing video raises its rate instead of seeking. The reader
  // chooses between the two gestures in Media settings.
  @StorageLink(STORAGE_KEY_VIDEO_HOLD_SPEED) holdSpeedEnabled: boolean = true;
  @StorageProp(STORAGE_KEY_VIDEO_DOUBLE_TAP_SEEK) doubleTapSeekEnabled: boolean = DEFAULT_VIDEO_DOUBLE_TAP_SEEK_ENABLED;
  @StorageProp(STORAGE_KEY_VIDEO_DOUBLE_TAP_SEEK_SECONDS) doubleTapSeekSeconds: number = DEFAULT_VIDEO_DOUBLE_TAP_SEEK_SECONDS;
  // What this video does when the reader leaves the app while it is playing
  // fullscreen: keep the sound going through the control centre, or move the
  // picture into the system picture-in-picture window.
  @StorageLink(STORAGE_KEY_VIDEO_BACKGROUND_MODE) @Watch('onBackgroundModeChanged')
  videoBackgroundMode: number = VIDEO_BACKGROUND_AUDIO;
  @StorageLink('harmonyx.background_tick') @Watch('onBackgroundTick')
  backgroundTick: number = 0;
  // SpeechKit reads `initialOpacity` only when the caption component is
  // created, so the layer is rebuilt whenever the reader moves the slider.
  @StorageLink(STORAGE_KEY_CAPTION_OPACITY) @Watch('onCaptionOpacityChanged')
  captionOpacity: number = DEFAULT_CAPTION_OPACITY;
  @StorageProp('harmonyx.navigation_indicator_height') @Watch('applyVideoScaleType') navigationIndicatorHeight: number =
    AppStorage.get<number>('harmonyx.navigation_indicator_height') ?? 0;
  @StorageProp('harmonyx.status_bar_height') statusBarHeight: number =
    AppStorage.get<number>('harmonyx.status_bar_height') ?? 0;
  @StorageProp('harmonyx.window_width') @Watch('onVideoScaleModeChanged') windowWidth: number =
    AppStorage.get<number>('harmonyx.window_width') ?? 0;
  @StorageProp('harmonyx.window_height') @Watch('onVideoScaleModeChanged') windowHeight: number =
    AppStorage.get<number>('harmonyx.window_height') ?? 0;
  @State @Watch('syncKeepAwake') private playing: boolean = false;
  private keepAwakeOwner: string = videoKeepAwake.createOwner();
  private keepAwakeVisible: boolean = true;
  // Stays false until the decoder reports a frame, which is what keeps the
  // cover on top of a stream that has not painted anything yet.
  @State @Watch('publishInlinePreview') private ready: boolean = false;
  @State @Watch('publishInlinePreview') private failed: boolean = false;
  @State private buffering: boolean = false;
  @State private measuredWidth: number = 0;
  @State private decodedVideoWidth: number = 0;
  @State private decodedVideoHeight: number = 0;
  @State private positionSec: number = 0;
  @State private durationSec: number = 0;
  @State private playbackRateIndex: number = 1;
  @State private muted: boolean = true;
  @State @Watch('onFullscreenChanged') private fullscreen: boolean = false;
  @StorageLink(STORAGE_KEY_VIDEO_FULLSCREEN_OWNER) @Watch('onFullscreenOwnerChanged')
  private fullscreenOwnerId: string = '';
  @State private pipActive: boolean = false;
  @State private aiCaptionShown: boolean = false;
  @State private captionLayerRevision: number = 0;
  @State private scrubbing: boolean = false;
  @State private scrubSec: number = 0;
  @State @Watch('onControlsVisibilityChanged') private controlsVisible: boolean = true;
  @State private fullscreenFill: boolean = false;
  @State private fullscreenPinchHint: boolean = false;
  @State private fullscreenGestureMode: number = FULLSCREEN_GESTURE_NONE;
  @State private fullscreenGestureValue: number = 0;
  @State private playerControlsLocked: boolean = false;
  @State private holdSeekDirection: number = 0;
  @State private doubleTapSeekDirection: number = 0;
  @State private doubleTapSeekAmount: number = 0;
  private doubleTapSeekHintTimer: number = -1;
  @State private holdSpeedActive: boolean = false;
  @State private holdSpeedRate: number = VIDEO_HOLD_SPEED_RATE;
  private holdSpeedRestoreIndex: number = 1;
  private holdSpeedNotified: boolean = false;
  private holdSpeedOriginY: number = 0;
  private holdSpeedOriginSet: boolean = false;
  private holdSpeedDownY: number = 0;
  private holdSpeedArmed: boolean = false;
  private holdSpeedTimer: number = -1;
  private suppressVideoTapUntil: number = 0;
  private inlineController: XComponentController = new XComponentController();
  private fullController: XComponentController = new XComponentController();
  private inlineOptions: XComponentOptions = {
    type: XComponentType.SURFACE,
    controller: this.inlineController
  };
  private fullOptions: XComponentOptions = {
    type: XComponentType.SURFACE,
    controller: this.fullController
  };
  private inlineSurfaceId: string = '';
  private fullSurfaceId: string = '';
  private player: mediaKit.AVPlayer | null = null;
  private handedOff: boolean = false;
  private playerEpoch: number = 0;
  private pipController: PiPWindow.PiPController | null = null;
  // Which XComponent the controller above is bound to: the inline cell
  // surface, or the fullscreen one that is on screen while the reader watches
  // the video at full size.
  private pipBoundToFull: boolean = false;
  // Set when the floating window opened because the app went to the
  // background, which is what tells a dismissed window apart from a restored
  // one when the window closes again.
  private backgroundPip: boolean = false;
  private aiCaptionController: AICaptionController = new AICaptionController();
  private aiCaptionOptions: AICaptionOptions = {
    initialOpacity: DEFAULT_CAPTION_OPACITY,
    fontSize: AICaptionFontSize.SMALL,
    onPrepared: (): void => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'AI caption ready');
    },
    onError: (error: BusinessError): void => {
      hilog.warn(DOMAIN, TAG, 'AI caption failed: %{public}d', error.code);
    }
  };
  private playerState: string = 'idle';
  private preparing: boolean = false;
  private wantsPlay: boolean = false;
  // Keep the remote URL as the source identity while AVPlayer reads either
  // the completed file descriptor or the local cached Range stream.
  private currentSource: string = '';
  private fullscreenInstanceKey: string = '';
  private cacheLease: VideoCacheLease | null = null;
  private dataSourceLease: VideoDataSourceLease | null = null;
  // During reset, AVPlayer may still be consuming the previous descriptor.
  // Keep that lease open until reset/release has completed.
  private resettingCacheLease: VideoCacheLease | null = null;
  private resettingDataSourceLease: VideoDataSourceLease | null = null;
  private preloadTimer: number = -1;
  private preloading: boolean = false;
  private preloaded: boolean = false;
  private preloadFailed: boolean = false;
  private initialPositionApplied: boolean = false;
  private sourceSwitchPositionSec: number = 0;
  private pendingSeekSeconds: number = -1;
  private resumeAfterVideoFeed: boolean = false;
  private proxyPrepareEpoch: number = 0;
  private preparingSource: string = '';
  private playbackStartedAt: number = 0;
  private lastProgressAt: number = 0;
  private progressTimer: number = -1;
  private sourceRetryCount: number = 0;
  private invalidCacheRetried: boolean = false;
  // A failing cached stream gets one retry through AVPlayer's own URL
  // loader before the rendition fallback moves to another URL.
  private bypassProgressiveDataSource: boolean = false;
  private retryTimer: number = -1;
  private sourceTransitioning: boolean = false;
  private sourceResetPending: boolean = false;
  private loadTimer: number = -1;
  private mutedBeforeFullscreen: boolean = true;
  private stopRequested: boolean = false;
  private pendingPip: boolean = false;
  private pipResumeDesired: boolean = false;
  private pipWidth: number = PIP_FALLBACK_WIDTH;
  private pipHeight: number = PIP_FALLBACK_HEIGHT;
  private playbackHandle: SurfacePlaybackHandle = new SurfacePlaybackHandle();
  private pipPlaybackHandle: SurfacePipPlaybackHandle = new SurfacePipPlaybackHandle();
  // Last visible ratio, so a dismissed picture-in-picture window knows whether
  // the cell it came from is on screen.
  private lastRatio: number = 1;
  private hideTimer: number = -1;
  private fullscreenPinchHintTimer: number = -1;
  private fullscreenGestureHintTimer: number = -1;
  private playerWindow: window.Window | null = null;
  private panStartPosition: number = 0;
  private panStartVolume: number = 1;
  private panStartBrightness: number = 0.5;
  private panStartsOnRight: boolean = true;
  private windowBrightness: number = 0.5;
  private playbackVolume: number = 1;
  private alive: boolean = true;
  private retainedForPip: boolean = false;
  private fullscreenOrientationRequest: number = 0;

  aboutToAppear(): void {
    this.alive = true;
    this.positionSec = this.isAnimatedGif() ? 0 : this.initialPositionSeconds;
    this.keepAwakeVisible = true;
    this.initialPositionApplied = this.initialPositionSeconds <= 0;
    if (this.fullscreenInstanceKey.length === 0) {
      this.fullscreenInstanceKey = this.media.id + '-' + Date.now().toString() + '-' +
        Math.floor(Math.random() * 1000000).toString();
    }
    // Returning needs a surface owner even if autoplay was off and this
    // component never created a native player underneath the viewer.
    const returnTarget: VideoPlayerReturnTarget | null = this.playerReturnTarget();
    if (returnTarget !== null) { videoPlayerHandoff.registerReturnTarget(this.media.id, returnTarget); }
    this.syncDecodedVideoSize();
    this.muted = !this.playbackEnabled || this.startMuted();
    this.playbackVolume = this.muted ? 0 : 1;
    this.mutedBeforeFullscreen = this.muted;
    this.aiCaptionShown = this.captionRequested;
    this.aiCaptionOptions.initialOpacity = this.captionOpacity;
    this.playbackHandle.onStart = (): void => {
      this.play();
    };
    this.playbackHandle.onPause = (): void => {
      this.pause();
    };
    this.playbackHandle.onSeek = (seconds: number): void => {
      this.seekTo(seconds);
    };
    this.playbackHandle.onCastState = (casting: boolean, state: avSession.AVPlaybackState | undefined): void => {
      this.onCastStateChanged(casting, state);
    };
    this.playbackHandle.onCastFailed = (): void => {
      promptAction.showToast({ message: $r('app.string.video_cast_failed') });
    };
    this.wantsPlay = this.playbackEnabled ?
      (this.exploreHeroVideo || this.videoAutoplay || this.manualStart) :
      this.preloadEnabled;
    if (this.isCoveredByVideoFeed()) { this.wantsPlay = false; }
    this.preloading = !this.playbackEnabled && this.wantsPlay;
    this.currentSource = streamSource(this.media, this.videoQuality, this.autoBitrateCap);
    if (this.playbackEnabled && !this.isAnimatedGif()) {
      const handoff: VideoPlayerHandoffPayload | null = videoPlayerHandoff.take(this.media.id);
      if (handoff !== null) {
        this.adoptPlayerHandoff(handoff);
        return;
      }
    }
    this.cacheLease = this.acquireCacheLease(this.currentSource);
    this.buffering = this.wantsPlay;
    if (this.wantsPlay) {
      this.armLoadTimeout(FIRST_FRAME_TIMEOUT_MS);
    }
    if (this.shouldUseProgressiveDataSource()) {
      this.prepareProgressiveSource();
      return;
    }
    if (!this.wantsPlay && this.cacheLease === null) { return; }
    this.createPlayer();
  }

  private shouldStartMuted(): boolean {
    if (this.isAnimatedGif()) {
      return true;
    }
    if (this.usesFeedMutePreference()) {
      return this.preferredMuted();
    }
    return !this.forceUnmuted;
  }

  private usesFeedMutePreference(): boolean {
    return this.usesHomeMutePreference() || this.usesViewerMutePreference();
  }

  private usesHomeMutePreference(): boolean {
    return !this.mediaViewerLayout && !this.fullscreen &&
      (this.linkCardVideo || !this.hideVideoChrome() && this.homeTimelineVideo);
  }

  private usesViewerMutePreference(): boolean {
    return !this.hideVideoChrome() && (this.mediaViewerLayout || this.fullscreen);
  }

  private preferredMuted(): boolean {
    return this.usesViewerMutePreference() ? this.viewerVideoMuted : this.homeVideoMuted;
  }

  private isCoveredByVideoFeed(): boolean {
    return this.videoFeedActive && !this.mediaViewerLayout && !this.fullscreen && !this.pipActive &&
      !videoPlayerHandoff.isRequested(this.media.id) && !videoPlayerHandoff.isReturning(this.media.id, this.fullscreenInstanceKey);
  }

  private onVideoFeedActiveChanged(): void {
    if (!this.alive || this.mediaViewerLayout) { return; }
    if (this.isCoveredByVideoFeed()) {
      this.resumeAfterVideoFeed = this.wantsPlay;
      this.pause();
      hilog.debug(DOMAIN, TAG, 'covered inline player paused id=%{public}s', this.media.id);
      return;
    }
    if (this.takeRequestedPlayer()) { this.resumeAfterVideoFeed = false; return; }
    const resume: boolean = this.resumeAfterVideoFeed;
    this.resumeAfterVideoFeed = false;
    if (resume && this.playbackEnabled && this.lastRatio >= PLAYER_PLAY_RATIO) { this.play(); }
  }

  private isAnimatedGif(): boolean {
    return isAnimatedGif(this.media);
  }

  private hideInlineVideoControls(): boolean {
    return this.hideInlineControls && !this.fullscreen && !this.mediaViewerLayout;
  }

  private hideVideoChrome(): boolean {
    return this.exploreHeroVideo || this.isAnimatedGif() || this.linkCardVideo && !this.fullscreen;
  }

  private startMuted(): boolean {
    if (this.isAnimatedGif()) {
      return true;
    }
    return this.exploreHeroVideo ? this.exploreHeroMuted : this.shouldStartMuted();
  }

  private onHomeVideoMutedChanged(): void {
    if (this.usesHomeMutePreference()) { this.onFeedMutePreferenceChanged(); }
  }

  private onViewerVideoMutedChanged(): void {
    if (this.usesViewerMutePreference()) { this.onFeedMutePreferenceChanged(); }
  }

  private onFeedMutePreferenceChanged(): void {
    if (!this.usesFeedMutePreference() || !this.alive || this.casting) {
      return;
    }
    const muted: boolean = this.preferredMuted();
    if (this.muted === muted || (!muted && this.isCoveredByVideoFeed())) {
      return;
    }
    // The tapped player keeps audio ownership. Other already-running muted
    // cells pick up sound on their next activation instead of stealing it.
    if (!muted && (this.playing || this.wantsPlay) &&
      videoPlaybackCoordinator.isOwnedByOther(this.media.id)) {
      return;
    }
    this.setMuted(muted, !this.isCoveredByVideoFeed() &&
      (this.playing || this.wantsPlay));
  }

  private onExploreHeroMutedChanged(): void {
    if (!this.exploreHeroVideo || !this.alive) {
      return;
    }
    this.setMuted(this.exploreHeroMuted);
  }

  aboutToDisappear(): void {
    videoPlayerHandoff.unregisterReturnTarget(this.media.id, this.fullscreenInstanceKey);
    this.disarmHoldSpeed();
    if (this.holdSpeedActive) {
      this.holdSpeedActive = false;
      this.playbackRateIndex = this.holdSpeedRestoreIndex;
      this.notifyHoldSpeedEnded();
    }
    this.finishHoldSeek(false);
    this.keepAwakeVisible = false;
    this.clearDoubleTapSeekHint();
    this.releaseKeepAwake();
    if (this.aiCaptionShown) {
      this.captureCaptionOpacity();
    }
    this.clearPreloadTimer();
    if (this.fullscreen) {
      hilog.info(DOMAIN, TAG, 'fullscreen player removed id=%{public}s', this.media.id);
      this.setFullscreenWindowState(false);
      this.setFullscreenWindowOrientation(false);
    }
    this.clearFullscreenPinchHint();
    this.clearFullscreenGestureHint();
    if (this.pipActive || videoPipGate.isHeld(this.media.id)) {
      this.retainedForPip = true;
      this.clearHideTimer();
      return;
    }
    this.alive = false;
    this.clearHideTimer();
    this.clearLoadTimeout();
    this.clearSourceRetryTimer();
    if (this.handedOff && this.player === null) { this.releasePip(false); return; }
    this.syncBackgroundPlayback();
    this.releasePip();
    if (videoPlayerHandoff.isRequested(this.media.id) && this.player !== null) {
      return;
    }
    this.destroyPlayer();
  }

  private clearHideTimer(): void {
    if (this.hideTimer >= 0) {
      clearTimeout(this.hideTimer);
      this.hideTimer = -1;
    }
  }

  private clearFullscreenPinchHint(): void {
    if (this.fullscreenPinchHintTimer >= 0) {
      clearTimeout(this.fullscreenPinchHintTimer);
      this.fullscreenPinchHintTimer = -1;
    }
    this.fullscreenPinchHint = false;
  }

  private clearFullscreenGestureHint(): void {
    if (this.fullscreenGestureHintTimer >= 0) {
      clearTimeout(this.fullscreenGestureHintTimer);
      this.fullscreenGestureHintTimer = -1;
    }
    this.fullscreenGestureMode = FULLSCREEN_GESTURE_NONE;
  }

  private async ensurePlayerWindow(): Promise<window.Window | null> {
    if (this.playerWindow !== null) {
      return this.playerWindow;
    }
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    try {
      const resolved: window.Window = await window.getLastWindow(context);
      this.playerWindow = resolved;
      return resolved;
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'player window unavailable id=%{public}s', this.media.id);
      return null;
    }
  }

  private async setFullscreenWindowState(keepScreenOn: boolean): Promise<void> {
    this.syncKeepAwake();
    const current: window.Window | null = await this.ensurePlayerWindow();
    if (current === null) {
      return;
    }
    try {
      if (!keepScreenOn) {
        await current.setWindowBrightness(-1);
      }
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'fullscreen window update skipped id=%{public}s', this.media.id);
    }
  }

  private syncKeepAwake(): void {
    const context: common.UIAbilityContext | undefined = this.getUIContext().getHostContext() as common.UIAbilityContext;
    if (context !== undefined) {
      videoKeepAwake.update(this.keepAwakeOwner, this.keepAwakeVisible && this.alive && this.playbackEnabled && this.playing &&
        !this.failed && !this.casting && !this.isAnimatedGif(), context);
    }
  }

  private releaseKeepAwake(): void {
    const context: common.UIAbilityContext | undefined = this.getUIContext().getHostContext() as common.UIAbilityContext;
    if (context !== undefined) { videoKeepAwake.update(this.keepAwakeOwner, false, context); }
  }

  private async setFullscreenBrightness(value: number): Promise<void> {
    const current: window.Window | null = await this.ensurePlayerWindow();
    if (current === null) {
      return;
    }
    try {
      await current.setWindowBrightness(value);
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'brightness update skipped id=%{public}s', this.media.id);
    }
  }

  private clearLoadTimeout(): void {
    if (this.loadTimer >= 0) {
      clearTimeout(this.loadTimer);
      this.loadTimer = -1;
    }
  }

  private clearSourceRetryTimer(): void {
    if (this.retryTimer >= 0) {
      clearTimeout(this.retryTimer);
      this.retryTimer = -1;
    }
  }

  private clearProgressWatchdog(): void {
    if (this.progressTimer >= 0) { clearInterval(this.progressTimer); this.progressTimer = -1; }
  }

  private startProgressWatchdog(): void {
    this.clearProgressWatchdog();
    this.progressTimer = setInterval((): void => {
      if (!this.alive || !this.wantsPlay || !this.playing || !this.playbackEnabled ||
        !this.ready || this.scrubbing || this.sourceTransitioning || this.failed) { return; }
      const player: mediaKit.AVPlayer | null = this.player;
      if (player === null || player.state !== 'playing') { return; }
      if (player.currentTime > this.positionSec * 1000 + 1) {
        this.positionSec = player.currentTime / 1000;
        this.lastProgressAt = Date.now();
      }
      if (Date.now() - this.lastProgressAt >= 8000) {
        this.buffering = true;
        this.onPlaybackStateChanged(false);
        hilog.warn(DOMAIN, TAG, 'video progress stalled id=%{public}s position=%{public}s',
          this.media.id, this.positionSec.toString());
        this.onStreamFailed(false, false);
      }
    }, 1000);
  }

  private armLoadTimeout(duration: number): void {
    this.clearLoadTimeout();
    if (!this.wantsPlay || this.failed) {
      return;
    }
    this.loadTimer = setTimeout((): void => {
      this.loadTimer = -1;
      if (this.alive && this.wantsPlay && !this.failed && (this.buffering || !this.ready)) {
        hilog.warn(DOMAIN, TAG, 'video stalled id=%{public}s source=%{public}s',
          this.media.id, this.currentSource);
        this.onStreamFailed(false, false);
      }
    }, duration);
  }

  private markFrameReady(): void {
    const player: mediaKit.AVPlayer | null = this.player;
    if (this.failed || !this.alive || this.sourceTransitioning || player === null ||
      player.state === 'error' || player.state === 'released' || (this.preloadFailed && !this.playbackEnabled)) {
      return;
    }
    if (!this.ready) {
      hilog.info(DOMAIN, TAG, 'video first frame id=%{public}s elapsedMs=%{public}d preload=%{public}d',
        this.media.id, Date.now() - this.playbackStartedAt, this.playbackEnabled ? 0 : 1);
    }
    this.ready = true;
    this.onViewerSurfaceReady();
    this.buffering = false;
    this.lastProgressAt = Date.now();
    this.clearLoadTimeout();
    this.tryStartPendingPip();
  }

  private publishInlinePreview(): void {
    if (this.persistentInlinePreview) { this.onInlinePreviewHidden(this.ready || this.failed); }
  }

  private cacheRendition(source: string): string {
    const renditions: VideoRendition[] = this.media.videoVariants ?? [];
    for (let index: number = 0; index < renditions.length; index++) {
      if (renditions[index].url === source) {
        const rendition: VideoRendition = renditions[index];
        return 'v' + rendition.bitrate.toString() + '-' + rendition.width.toString() + 'x' +
          rendition.height.toString();
      }
    }
    if (source === this.media.feedUrl && source !== this.media.mediaUrl) {
      return 'feed';
    }
    return 'full';
  }

  private acquireCacheLease(source: string): VideoCacheLease | null {
    if (source.startsWith('file://')) {
      let file: fileIo.File | null = null;
      try {
        file = fileIo.openSync(source, fileIo.OpenMode.READ_ONLY);
        return new VideoCacheLease('local:' + this.media.id, file.fd, fileIo.statSync(file.fd).size,
          (_key: string): void => {});
      } catch (error) {
        if (file !== null) { fileIo.closeSync(file.fd); }
        return null;
      }
    }
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    return videoPlaybackCache.acquire(context, this.media.id, this.cacheRendition(source), source);
  }

  private shouldUseProgressiveDataSource(): boolean {
    return !this.bypassProgressiveDataSource && this.wantsPlay && this.cacheLease === null &&
      this.dataSourceLease === null && videoPlaybackCache.canCache(this.currentSource);
  }

  private prepareProgressiveSource(): void {
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const source: string = this.currentSource;
    if (this.preparingSource === source) { return; }
    this.playbackStartedAt = Date.now();
    this.preparingSource = source;
    const epoch: number = ++this.proxyPrepareEpoch;
    videoPlaybackCache.openDataSource(context, this.media.id, this.cacheRendition(source), source, this.playbackEnabled)
      .then((lease: VideoDataSourceLease | null): void => {
        if (!this.alive || epoch !== this.proxyPrepareEpoch || source !== this.currentSource) {
          if (lease !== null) {
            lease.close();
          }
          return;
        }
        this.preparingSource = '';
        if (!this.wantsPlay && !this.preloadEnabled) {
          if (lease !== null) { lease.close(); }
          return;
        }
        this.dataSourceLease = lease;
        if (lease === null && this.requiresProxyDownload(source)) {
          this.bypassProgressiveDataSource = true;
          this.prepareProxySource();
          return;
        }
        if (lease === null) {
          hilog.debug(DOMAIN, TAG, 'progressive source unavailable; using AVPlayer URL id=%{public}s',
            this.media.id);
        }
        this.createPlayer();
      }).catch((): void => {
        if (!this.alive || epoch !== this.proxyPrepareEpoch) { return; }
        this.preparingSource = '';
        this.bypassProgressiveDataSource = true;
        if (this.requiresProxyDownload(source)) { this.prepareProxySource(); }
        else { this.createPlayer(); }
      });
  }

  private invalidateCacheLease(source: string): void {
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    videoPlaybackCache.invalidate(context, this.media.id, this.cacheRendition(source));
  }

  private requiresProxyDownload(source: string): boolean {
    return (proxyStore.requiresHttpTransport() || proxyStore.videoCdnProxyEnabledFor(source)) &&
      videoPlaybackCache.canCache(source);
  }

  // AVPlayer does not take HttpRequestOptions, so it cannot receive the
  // per-request proxy selected in ProxyStore. Fetch through the proxy-aware
  // downloader into the shared playback cache, then give AVPlayer a lease.
  // The same completed file can be reused when this post is opened in the feed.
  private prepareProxySource(): void {
    if (this.dataSourceLease !== null) { return; }
    if (!this.bypassProgressiveDataSource && this.shouldUseProgressiveDataSource()) {
      this.prepareProgressiveSource(); return;
    }
    if (!this.requiresProxyDownload(this.currentSource)) {
      this.createPlayer();
      return;
    }
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const source: string = this.currentSource;
    const rendition: string = this.cacheRendition(source);
    if (this.preparingSource === source) { return; }
    this.preparingSource = source;
    const epoch: number = ++this.proxyPrepareEpoch;
    this.armLoadTimeout(25000);
    videoPlaybackCache.prepare(context, this.media.id, rendition, source)
      .then((ready: boolean): void => {
      if (!this.alive || epoch !== this.proxyPrepareEpoch || source !== this.currentSource) {
        return;
      }
      this.preparingSource = '';
      if (!ready) {
        hilog.warn(DOMAIN, TAG, 'proxy video download failed id=%{public}s', this.media.id);
        this.onStreamFailed(false);
        return;
      }
      const lease: VideoCacheLease | null = this.acquireCacheLease(source);
      if (lease === null) {
        this.onStreamFailed(false);
        return;
      }
      this.cacheLease = lease;
      if (this.wantsPlay) {
        this.armLoadTimeout(FIRST_FRAME_TIMEOUT_MS);
      }
      this.createPlayer();
    });
  }

  private closeCacheLease(lease: VideoCacheLease | null): void {
    if (lease !== null) {
      lease.close();
    }
  }

  private closeCurrentCacheLease(): void {
    const lease: VideoCacheLease | null = this.cacheLease;
    this.cacheLease = null;
    this.closeCacheLease(lease);
  }

  private closeDataSourceLease(lease: VideoDataSourceLease | null): void {
    if (lease !== null) {
      lease.close();
    }
  }

  private closeCurrentDataSourceLease(): void {
    const lease: VideoDataSourceLease | null = this.dataSourceLease;
    this.dataSourceLease = null;
    this.closeDataSourceLease(lease);
  }

  private closeResettingDataSourceLease(): void {
    const lease: VideoDataSourceLease | null = this.resettingDataSourceLease;
    this.resettingDataSourceLease = null;
    this.closeDataSourceLease(lease);
  }

  private closeResettingCacheLease(): void {
    const lease: VideoCacheLease | null = this.resettingCacheLease;
    this.resettingCacheLease = null;
    this.closeCacheLease(lease);
  }

  private fallbackSource(): string {
    const ordered: string[] = [];
    const preferred: string = streamSource(this.media, this.videoQuality, this.autoBitrateCap);
    if (preferred.length > 0) {
      ordered.push(preferred);
    }
    const variants: string[] = this.media.videoVariantUrls ?? [];
    let preferredIndex: number = variants.indexOf(preferred);
    if (preferredIndex < 0) {
      preferredIndex = variants.length;
    }
    // Try smaller MP4 renditions first. They are the most useful recovery if
    // the current URL is stale or the network cannot sustain its bitrate.
    for (let i: number = preferredIndex - 1; i >= 0; i--) {
      if (variants[i].length > 0 && ordered.indexOf(variants[i]) < 0) {
        ordered.push(variants[i]);
      }
    }
    for (let i: number = preferredIndex + 1; i < variants.length; i++) {
      if (variants[i].length > 0 && ordered.indexOf(variants[i]) < 0) {
        ordered.push(variants[i]);
      }
    }
    if (this.media.feedUrl.length > 0 && ordered.indexOf(this.media.feedUrl) < 0) {
      ordered.push(this.media.feedUrl);
    }
    if (this.media.mediaUrl.length > 0 && ordered.indexOf(this.media.mediaUrl) < 0) {
      ordered.push(this.media.mediaUrl);
    }
    let currentIndex: number = ordered.indexOf(this.currentSource);
    if (currentIndex < 0) {
      currentIndex = -1;
    }
    for (let i: number = currentIndex + 1; i < ordered.length; i++) {
      if (ordered[i] !== this.currentSource) {
        return ordered[i];
      }
    }
    return '';
  }

  private lighterSource(): string {
    const renditions: VideoRendition[] = this.media.videoVariants ?? [];
    let currentBitrate: number = 0;
    for (let i: number = 0; i < renditions.length; i++) {
      if (renditions[i].url === this.currentSource) { currentBitrate = renditions[i].bitrate; break; }
    }
    let selected: string = '';
    let selectedBitrate: number = 0;
    if (currentBitrate > 0) {
      for (let i: number = 0; i < renditions.length; i++) {
        const candidate: VideoRendition = renditions[i];
        if (candidate.bitrate > selectedBitrate && candidate.bitrate < currentBitrate) {
          selected = candidate.url; selectedBitrate = candidate.bitrate;
        }
      }
      return selected;
    }
    const variants: string[] = this.media.videoVariantUrls ?? [];
    const index: number = variants.indexOf(this.currentSource);
    if (index > 0) { return variants[index - 1]; }
    if (this.currentSource === this.media.mediaUrl && this.media.feedUrl.length > 0 &&
      this.media.feedUrl !== this.currentSource) { return this.media.feedUrl; }
    return '';
  }

  private syncDecodedVideoSize(): void {
    const cached: DecodedVideoSize | undefined = decodedVideoSizeCache.get(this.media.id);
    if (cached !== undefined) {
      this.decodedVideoWidth = cached.width;
      this.decodedVideoHeight = cached.height;
      this.pipWidth = cached.width;
      this.pipHeight = cached.height;
      return;
    }
    this.decodedVideoWidth = 0;
    this.decodedVideoHeight = 0;
    this.pipWidth = PIP_FALLBACK_WIDTH;
    this.pipHeight = PIP_FALLBACK_HEIGHT;
  }

  private videoSourceWidth(): number {
    return this.decodedVideoWidth > 0 ? this.decodedVideoWidth : this.media.width;
  }

  private videoSourceHeight(): number {
    return this.decodedVideoHeight > 0 ? this.decodedVideoHeight : this.media.height;
  }

  private availableDisplayWidth(): number {
    const fallbackInset: number = this.forceUnmuted ? 24 : 80;
    return this.measuredWidth > 0 ? this.measuredWidth :
      (this.windowWidth > fallbackInset ? this.windowWidth - fallbackInset : 280);
  }

  private maxNaturalDisplayHeight(): number {
    return maxNaturalVideoDisplayHeight(this.windowWidth, this.windowHeight);
  }

  private displayHeight(): number {
    if (this.inlineFrameHeight > 0 && !this.mediaViewerLayout && !this.fullscreen) {
      return this.inlineFrameHeight;
    }
    if (this.mediaViewerLayout && this.isWindowLandscape()) { return this.windowHeight; }
    if (this.fillVideoViewport) {
      return this.videoViewportHeight > 0 ? this.videoViewportHeight : MEDIA_HEIGHT;
    }
    if (this.isAnimatedGif()) {
      return postGifHeight(this.videoSourceWidth(), this.videoSourceHeight(),
        this.availableDisplayWidth(), this.windowHeight);
    }
    if (this.immersiveVideo && this.windowHeight > 0) {
      return this.windowHeight;
    }
    const videoWidth: number = this.videoSourceWidth();
    const videoHeight: number = this.videoSourceHeight();
    if (!this.naturalVideoSize || videoWidth <= 0 || videoHeight <= 0) {
      return MEDIA_HEIGHT;
    }
    const availableWidth: number = this.availableDisplayWidth();
    const naturalHeight: number = availableWidth * videoHeight / videoWidth;
    if (!this.limitNaturalHeight) {
      return Math.max(1, naturalHeight);
    }
    const maxHeight: number = this.maxNaturalDisplayHeight();
    return Math.max(MEDIA_HEIGHT, Math.min(naturalHeight, maxHeight));
  }

  private legacyPlayerBarWidth(): number {
    const availableWidth: number = this.fullscreen && this.windowWidth > 0 ? this.windowWidth - 32 :
      this.availableDisplayWidth();
    let width: number = availableWidth;
    const videoWidth: number = this.videoSourceWidth();
    const videoHeight: number = this.videoSourceHeight();
    if (!this.fullscreen && this.naturalVideoSize && this.limitNaturalHeight &&
      videoWidth > 0 && videoHeight > 0) {
      const naturalHeight: number = availableWidth * videoHeight / videoWidth;
      if (naturalHeight > this.maxNaturalDisplayHeight()) {
        width = this.displayHeight() * videoWidth / videoHeight;
      }
    }
    if (!this.fullscreen && this.immersiveVideo && this.adaptiveShortVideo) {
      width *= 0.92;
    }
    return Math.max(1, Math.min(availableWidth, width));
  }

  // The feed slot owns the available space; the surface owns the video's
  // aspect ratio. Keep these separate so a tall slot never crops a wide clip.
  private videoFrameControlsInset(): number {
    return this.hasFeedControlStrip() && !this.compactFeedLayout ?
      VIDEO_FEED_CONTROLS_HEIGHT + this.navigationIndicatorHeight : 0;
  }

  private hasFeedControlStrip(): boolean {
    return this.mediaViewerLayout && (this.compactFeedLayout || !this.isWindowLandscape());
  }

  private feedPlayerBarHeight(): number {
    const height: number = this.compactFeedLayout ?
      this.commentDimension(this.compactBottomActions ? $r('app.float.compact_video_bottom_controls_height') :
        $r('app.float.compact_video_controls_height')) : VIDEO_FEED_CONTROLS_HEIGHT;
    return height + this.navigationIndicatorHeight;
  }

  private fillsSmallFeedGap(): boolean {
    if (!this.mediaViewerLayout || this.compactFeedLayout || this.isWindowLandscape() || this.containVideo) { return false; }
    const sourceWidth: number = this.videoSourceWidth();
    const sourceHeight: number = this.videoSourceHeight();
    if (sourceWidth <= 0 || sourceHeight <= sourceWidth) { return false; }
    const naturalHeight: number = this.availableDisplayWidth() * sourceHeight / sourceWidth;
    const layerHeight: number = this.videoLayerHeight();
    return naturalHeight > 0 && naturalHeight < layerHeight &&
      layerHeight / naturalHeight <= VIDEO_FEED_EDGE_FILL_MAX_SCALE;
  }

  private videoFrameHeight(): number {
    if (!this.mediaViewerLayout) {
      return this.displayHeight();
    }
    const availableHeight: number = Math.max(1, this.displayHeight() - this.videoFrameControlsInset());
    if (this.fillsSmallFeedGap()) { return availableHeight; }
    const sourceWidth: number = this.videoSourceWidth();
    const sourceHeight: number = this.videoSourceHeight();
    if (sourceWidth <= 0 || sourceHeight <= 0) {
      return availableHeight;
    }
    return Math.min(availableHeight, this.availableDisplayWidth() * sourceHeight / sourceWidth);
  }

  private videoFrameWidth(): string {
    if (!this.mediaViewerLayout) {
      return this.displayWidth();
    }
    if (this.fillsSmallFeedGap()) { return this.availableDisplayWidth().toString() + 'vp'; }
    const sourceWidth: number = this.videoSourceWidth();
    const sourceHeight: number = this.videoSourceHeight();
    if (sourceWidth <= 0 || sourceHeight <= 0) {
      return '100%';
    }
    return Math.min(this.availableDisplayWidth(), this.videoFrameHeight() * sourceWidth / sourceHeight)
      .toString() + 'vp';
  }

  private videoLayerHeight(): number {
    return this.hasFeedControlStrip() ?
      Math.max(1, this.displayHeight() - this.videoFrameControlsInset()) : this.displayHeight();
  }

  private videoFrameAlignment(): Alignment {
    // A 4:5 or 3:4 clip still leaves vertical space; aspect ratio must not
    // force its surface against the header.
    return Alignment.Center;
  }

  private commentDimension(resource: Resource): number {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    return this.getUIContext().px2vp(context.resourceManager.getNumber(resource.id));
  }

  private commentVideoLayout(): MediaCommentLayout {
    if (!this.mediaViewerLayout) { return new MediaCommentLayout(); }
    const frameHeight: number = this.videoFrameHeight();
    const sourceWidth: number = this.videoSourceWidth();
    const sourceHeight: number = this.videoSourceHeight();
    const viewportWidth: number = this.availableDisplayWidth();
    const frameWidth: number = this.fillsSmallFeedGap() ? viewportWidth :
      sourceWidth > 0 && sourceHeight > 0 && this.mediaViewerLayout ?
      Math.min(viewportWidth, frameHeight * sourceWidth / sourceHeight) : viewportWidth;
    const input: MediaCommentLayoutInput = {
      viewportWidth: viewportWidth,
      frameWidth: frameWidth,
      frameHeight: frameHeight,
      frameCenterY: this.videoFrameAlignment() === Alignment.Top ? frameHeight / 2 : this.videoLayerHeight() / 2,
      previewTop: this.viewerCommentTop,
      previewHeight: this.viewerCommentHeight,
      controlSize: this.commentDimension($r('app.float.media_viewer_action_height')),
      controlSpacing: this.commentDimension($r('app.float.media_viewer_comment_control_spacing')),
      inset: this.commentDimension($r('app.float.media_viewer_comment_control_inset')),
      gap: this.commentDimension($r('app.float.media_viewer_post_sheet_gap')),
      progress: this.viewerCommentProgress
    };
    return mediaCommentLayout(input);
  }

  private showsProgressBelowVideo(): boolean {
    return !this.controlsAtScreenBottom && !this.adaptiveShortVideo && !this.hideVideoChrome() && !this.hideInlineVideoControls() &&
      (this.mediaViewerLayout || this.fullscreen || this.videoAutoplay || this.manualStart || this.playing);
  }

  private playerContainerHeight(): number {
    if (this.hasFeedControlStrip()) {
      return this.displayHeight();
    }
    if (this.controlsAtScreenBottom && !this.hideVideoChrome() && !this.hideInlineVideoControls() && this.windowHeight > 0) {
      return this.windowHeight;
    }
    if (!this.showsProgressBelowVideo()) {
      return this.displayHeight();
    }
    const controlsHeight: number = this.videoControlStyle === VIDEO_CONTROL_STYLE_ORIGINAL ?
      INLINE_PROGRESS_LINE_HEIGHT : INLINE_VIDEO_CONTROLS_HEIGHT;
    return this.displayHeight() + controlsHeight;
  }

  private displayWidth(): string {
    if (this.mediaViewerLayout && this.isWindowLandscape()) { return '100%'; }
    if (this.isAnimatedGif()) {
      return '100%';
    }
    if (this.fillVideoViewport || this.immersiveVideo || !this.naturalVideoSize) {
      return '100%';
    }
    const videoWidth: number = this.videoSourceWidth();
    const videoHeight: number = this.videoSourceHeight();
    if (videoWidth <= 0 || videoHeight <= 0) {
      return '100%';
    }
    const availableWidth: number = this.availableDisplayWidth();
    const naturalHeight: number = availableWidth * videoHeight / videoWidth;
    if (!this.limitNaturalHeight || naturalHeight <= this.maxNaturalDisplayHeight()) {
      return '100%';
    }
    const limitedWidth: number = this.displayHeight() * videoWidth / videoHeight;
    return Math.max(1, Math.min(availableWidth, limitedWidth)).toString() + 'vp';
  }

  private videoRadius(): number {
    if (this.mediaViewerLayout) { return 0; }
    if (this.immersiveVideo) {
      return 0;
    }
    return this.fillVideoViewport ? 22 : 14;
  }

  private controlsShouldStayVisible(): boolean {
    return (this.mediaViewerLayout || this.immersiveVideo) && this.videoFeedControlsAlwaysVisible;
  }

  private onControlsVisibilityChanged(): void {
    if (this.mediaViewerLayout && !this.fullscreen) {
      this.onViewerControlsChanged(this.controlsVisible);
    }
  }

  private onVideoFeedControlsAlwaysVisibleChanged(): void {
    if (!this.alive || (!this.mediaViewerLayout && !this.immersiveVideo)) {
      return;
    }
    if (this.controlsShouldStayVisible()) {
      this.holdControls();
    } else if (this.playing) {
      this.scheduleHide();
    }
  }

  // Playback is running: show the row, then let it slide away again.
  private scheduleHide(): void {
    this.controlsVisible = true;
    this.clearHideTimer();
    if (this.controlsShouldStayVisible()) {
      return;
    }
    this.hideTimer = setTimeout((): void => {
      this.hideTimer = -1;
      if (this.alive && this.playing && !this.scrubbing) {
        this.controlsVisible = false;
      }
    }, this.isWindowLandscape() ? LANDSCAPE_CONTROLS_HIDE_DELAY_MS : CONTROLS_HIDE_DELAY_MS);
  }

  // Paused or being scrubbed: the row stays until playback resumes.
  private holdControls(): void {
    this.clearHideTimer();
    this.controlsVisible = true;
  }

  private toggleControls(): void {
    if (this.controlsShouldStayVisible() && !this.mediaViewerLayout) {
      this.holdControls();
      return;
    }
    if (this.controlsVisible) {
      this.clearHideTimer();
      this.controlsVisible = false;
    } else if (this.playing) {
      this.scheduleHide();
    } else {
      this.holdControls();
    }
  }

  // ---- AVPlayer ------------------------------------------------------------

  private createPlayer(): void {
    if (this.player !== null || this.isCoveredByVideoFeed()) { return; }
    if (this.playbackStartedAt <= 0) { this.playbackStartedAt = Date.now(); }
    this.lastProgressAt = Date.now();
    if (this.playbackEnabled && !this.isAnimatedGif()) {
      const handoff: VideoPlayerHandoffPayload | null = videoPlayerHandoff.take(this.media.id);
      if (handoff !== null) {
        this.adoptPlayerHandoff(handoff);
        return;
      }
    }
    const epoch: number = ++this.playerEpoch;
    this.handedOff = false;
    mediaKit.createAVPlayer().then((created: mediaKit.AVPlayer): void => {
      if (!this.alive || epoch !== this.playerEpoch || this.isCoveredByVideoFeed()) {
        created.release();
        return;
      }
      this.player = created;
      this.bindPlayerEvents(created);
      if (this.currentSource.length === 0) {
        this.currentSource = streamSource(this.media, this.videoQuality, this.autoBitrateCap);
      }
      this.setPlayerSource(created);
      this.registerPlayerHandoff(created);
    }).catch((error: BusinessError): void => {
      if (epoch !== this.playerEpoch) {
        return;
      }
      hilog.error(DOMAIN, TAG, 'avplayer create failed: %{public}d', error.code);
      this.onStreamFailed();
    });
  }

  private bindPlayerEvents(player: mediaKit.AVPlayer): void {
    player.on('stateChange', (state: mediaKit.AVPlayerState, reason: mediaKit.StateChangeReason): void => {
      if (this.player !== player) {
        return;
      }
      const current: string = state;
      this.onPlayerState(current);
    });
    player.on('error', (error: BusinessError): void => {
      if (this.player !== player) {
        return;
      }
      hilog.warn(DOMAIN, TAG, 'surface video operation error id=%{public}s code=%{public}d state=%{public}s message=%{public}s',
        this.media.id, error.code, player.state, error.message);
      // A refused UI control does not mean the media bytes are damaged.
      // Fatal source failures also report the native error state below.
      if (error.code === 5400102 && player.state !== 'error') { return; }
      if (this.wantsPlay && !this.sourceTransitioning) {
        this.onStreamFailed();
      }
    });
    player.on('timeUpdate', (time: number): void => {
      if (this.casting) { return; }
      if (this.player !== player || this.sourceTransitioning || this.failed) {
        return;
      }
      // Progress/seek callbacks can arrive before the first rendered frame.
      if (time > 0 && !this.ready && !this.persistentInlinePreview) {
        this.markFrameReady();
      }
      if (this.ready && this.buffering && time > this.positionSec * 1000 + 100) {
        this.buffering = false;
        this.clearLoadTimeout();
      }
      if (time > this.positionSec * 1000 + 1) { this.lastProgressAt = Date.now(); }
      if (!this.scrubbing) {
        this.positionSec = time / 1000;
      }
      if (this.playbackEnabled && !this.isAnimatedGif()) {
        videoMediaSession.updatePosition(this.media.id, time / 1000);
        videoPlaybackPositionStore.remember(this.media.id, time / 1000);
      }
    });
    player.on('bufferingUpdate', (infoType: mediaKit.BufferingInfoType, value: number): void => {
      if (this.player !== player || this.sourceTransitioning || this.failed) {
        return;
      }
      if (infoType === mediaKit.BufferingInfoType.BUFFERING_START && this.wantsPlay) {
        this.buffering = true;
        if (this.playbackEnabled) { this.onPlaybackStateChanged(false); }
        this.armLoadTimeout(BUFFER_STALL_TIMEOUT_MS);
      } else if (infoType === mediaKit.BufferingInfoType.BUFFERING_END) {
        this.buffering = false;
        if (this.ready) {
          this.clearLoadTimeout();
          if (this.playbackEnabled && this.playing) { this.onPlaybackStateChanged(true); }
        }
      }
    });
    player.on('durationUpdate', (duration: number): void => {
      if (this.player !== player) {
        return;
      }
      this.durationSec = duration / 1000;
      if (this.playbackEnabled) {
        videoMediaSession.updateDuration(this.media.id, duration / 1000);
      }
    });
    player.on('videoSizeChange', (width: number, height: number): void => {
      if (this.player !== player || width <= 0 || height <= 0) {
        return;
      }
      decodedVideoSizeCache.set(this.media.id, new DecodedVideoSize(width, height));
      this.decodedVideoWidth = width;
      this.decodedVideoHeight = height;
      this.pipWidth = width;
      this.pipHeight = height;
      this.applyVideoScaleType();
      const controller: PiPWindow.PiPController | null = this.pipController;
      if (controller !== null) {
        controller.updateContentSize(width, height);
      }
    });
    player.on('startRenderFrame', (): void => {
      if (this.player === player) {
        hilog.debug(DOMAIN, TAG, 'native video frame id=%{public}s surface=%{public}s', this.media.id, this.inlineSurfaceId);
        this.markFrameReady();
      }
    });
  }

  private playerReturnTarget(): VideoPlayerReturnTarget | null {
    return this.mediaViewerLayout || this.isAnimatedGif() || this.transitionSourceId.length === 0 ? null :
      new VideoPlayerReturnTarget(this.fullscreenInstanceKey, this.transitionSourceId,
        (): boolean => this.alive && this.playbackEnabled && this.inlineSurfaceId.length > 0 &&
          !this.fullscreen && !this.pipActive && !this.casting,
        (payload: VideoPlayerHandoffPayload): void => this.receivePlayerHandoff(payload));
  }

  private registerPlayerHandoff(player: mediaKit.AVPlayer): void {
    if (!this.playbackEnabled || this.isAnimatedGif()) {
      return;
    }
    const target: VideoPlayerReturnTarget | null = this.playerReturnTarget();
    videoPlayerHandoff.register(this.media.id, player, (): VideoPlayerHandoffPayload | null => {
      if (this.player !== player || this.pipActive || videoPipGate.isHeld(this.media.id)) {
        return null;
      }
      const payload: VideoPlayerHandoffPayload = new VideoPlayerHandoffPayload(player,
        this.currentSource, this.cacheLease, this.dataSourceLease, this.playerState,
        this.positionSec, this.durationSec, this.ready, this.playing, this.muted, this.playbackVolume);
      hilog.info(DOMAIN, TAG, 'video handoff take id=%{public}s viewer=%{public}d state=%{public}s',
        this.media.id, this.mediaViewerLayout ? 1 : 0, player.state);
      this.detachPlayerEvents(player);
      this.player = null;
      this.handedOff = true;
      this.wantsPlay = false;
      this.playing = false;
      this.cacheLease = null;
      this.dataSourceLease = null;
      this.playerEpoch += 1;
      this.clearProgressWatchdog();
      this.clearLoadTimeout();
      this.clearSourceRetryTimer();
      this.playerState = 'idle';
      videoMediaSession.release(this.media.id);
      this.releaseKeepAwake();
      return payload;
    }, (): void => {
      if (!this.alive && this.player === player) {
        this.destroyPlayer();
      }
    }, target);
  }

  private adoptPlayerHandoff(handoff: VideoPlayerHandoffPayload): void {
    this.handedOff = false;
    this.playbackStartedAt = Date.now();
    this.player = handoff.player;
    this.cacheLease = handoff.cacheLease;
    this.dataSourceLease = handoff.dataSourceLease;
    this.currentSource = handoff.source;
    this.playerState = handoff.player.state;
    this.positionSec = handoff.positionSeconds;
    this.durationSec = handoff.durationSeconds;
    this.ready = handoff.ready;
    // A pause callback can lag behind the handoff. The native player decides
    // whether resume is required; the outgoing UI flag can still say playing.
    this.playing = handoff.player.state === 'playing';
    this.muted = this.usesFeedMutePreference() ? this.startMuted() : handoff.muted;
    this.playbackVolume = this.usesFeedMutePreference() ?
      (this.muted ? 0 : (handoff.volume > 0 ? handoff.volume : 1)) : handoff.volume;
    this.wantsPlay = true;
    this.initialPositionApplied = true;
    this.buffering = false;
    this.failed = false;
    this.preparing = false;
    this.bindPlayerEvents(handoff.player);
    if (this.playing && this.playbackEnabled) {
      this.claimExclusivePlayback();
      this.lastProgressAt = Date.now();
      this.startProgressWatchdog();
    }
    try {
      this.applyPlayerVolume(handoff.player);
      if (this.canControlPlayer(handoff.player)) {
        handoff.player.loop = this.exploreHeroVideo || this.isAnimatedGif();
      }
      this.applyVideoScaleType();
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'transferred player setup skipped id=%{public}s', this.media.id);
    }
    this.registerPlayerHandoff(handoff.player);
    this.onInitialPositionApplied();
    this.onPlaybackStateChanged(this.playing);
    if (this.playing) {
      this.claimMediaSession();
    }
    videoPlaybackPositionStore.remember(this.media.id, this.positionSec);
    this.syncBackgroundPlayback();
    this.attachSurfaceAndPrepare();
    hilog.info(DOMAIN, TAG, 'video handoff adopted id=%{public}s viewer=%{public}d state=%{public}s surface=%{public}s',
      this.media.id, this.mediaViewerLayout ? 1 : 0, handoff.player.state, this.inlineSurfaceId);
    if (!this.playing && this.playbackEnabled) {
      this.play();
    }
  }

  private receivePlayerHandoff(handoff: VideoPlayerHandoffPayload): void {
    if (this.player !== handoff.player) { this.destroyPlayer(); }
    this.adoptPlayerHandoff(handoff);
  }

  private takeRequestedPlayer(): boolean {
    if (this.isAnimatedGif()) { return false; }
    const handoff: VideoPlayerHandoffPayload | null = videoPlayerHandoff.take(this.media.id);
    if (handoff === null) { return false; }
    this.receivePlayerHandoff(handoff);
    return true;
  }

  private detachPlayerEvents(player: mediaKit.AVPlayer): void {
    player.off('stateChange');
    player.off('error');
    player.off('timeUpdate');
    player.off('bufferingUpdate');
    player.off('durationUpdate');
    player.off('videoSizeChange');
    player.off('startRenderFrame');
  }

  private onPlayerState(state: string): void {
    if (this.casting) { this.playerState = state; return; }
    if (this.sourceTransitioning && state !== 'initialized' && state !== 'idle') {
      return;
    }
    if (this.failed && state !== 'idle') {
      return;
    }
    this.playerState = state;
    if (state === 'playing' && !this.playbackEnabled && this.preloadEnabled) {
      this.muted = true;
      this.playbackVolume = 0;
      const preloadPlayer: mediaKit.AVPlayer | null = this.player;
      if (preloadPlayer !== null) {
        try {
          this.applyPlayerVolume(preloadPlayer);
        } catch (error) {
          hilog.warn(DOMAIN, TAG, 'preload mute skipped id=%{public}s', this.media.id);
        }
      }
      this.playing = true;
      this.buffering = false;
      this.controlsVisible = false;
      this.clearPreloadTimer();
      this.preloadTimer = setTimeout((): void => {
        this.preloadTimer = -1;
        if (!this.alive || this.playbackEnabled || !this.preloadEnabled || !this.playing) {
          return;
        }
        this.preloading = false;
        this.preloaded = true;
        this.pause();
        this.seekTo(0);
      }, VIDEO_FEED_PRELOAD_DURATION_MS);
      return;
    }
    if (state === 'playing' && !this.playbackEnabled) {
      this.wantsPlay = false;
      this.playing = false;
      this.buffering = false;
      this.muted = true;
      this.playbackVolume = 0;
      const inactivePlayer: mediaKit.AVPlayer | null = this.player;
      if (inactivePlayer !== null) {
        try {
          this.applyPlayerVolume(inactivePlayer);
          inactivePlayer.pause();
        } catch (error) {
          hilog.warn(DOMAIN, TAG, 'inactive player stop skipped id=%{public}s', this.media.id);
        }
      }
      videoMediaSession.release(this.media.id);
      this.syncBackgroundPlayback();
      return;
    }
    if (state === 'playing' && this.playbackEnabled && !this.wantsPlay) {
      const pausedPlayer: mediaKit.AVPlayer | null = this.player;
      if (pausedPlayer !== null) {
        pausedPlayer.pause();
      }
      return;
    }
    if (state === 'initialized') {
      this.sourceTransitioning = false;
      this.attachSurfaceAndPrepare();
      return;
    }
    if (state === 'prepared') {
      const player: mediaKit.AVPlayer | null = this.player;
      if (player === null) {
        return;
      }
      this.preparing = false;
      if (player.duration > 0) {
        this.durationSec = player.duration / 1000;
      }
      const pendingSeek: number = this.pendingSeekSeconds;
      this.pendingSeekSeconds = -1;
      if (!this.initialPositionApplied) {
        if (pendingSeek < 0) { this.seekTo(this.initialPositionSeconds); }
        this.initialPositionApplied = true;
        this.onInitialPositionApplied();
      }
      if (pendingSeek >= 0) {
        this.seekTo(pendingSeek);
        this.sourceSwitchPositionSec = 0;
      } else if (this.sourceSwitchPositionSec > 0) {
        this.seekTo(this.sourceSwitchPositionSec);
        this.sourceSwitchPositionSec = 0;
      }
      try {
        this.applyVideoScaleType();
        player.loop = this.exploreHeroVideo || this.isAnimatedGif();
        this.applyPlayerVolume(player);
        this.applyPlaybackRate(player);
      } catch (error) {
        hilog.warn(DOMAIN, TAG, 'player setup skipped id=%{public}s', this.media.id);
      }
      if (!this.playbackEnabled) {
        this.muted = true;
        this.playbackVolume = 0;
        try {
          this.applyPlayerVolume(player);
        } catch (error) {
          hilog.warn(DOMAIN, TAG, 'preload setup mute skipped id=%{public}s', this.media.id);
        }
      }
      if (this.wantsPlay && (this.playbackEnabled || this.preloadEnabled)) {
        if (this.playbackEnabled) {
          this.claimExclusivePlayback();
        }
        const source: string = this.currentSource;
        player.play().catch((error: BusinessError): void => {
          if (source !== this.currentSource) {
            return;
          }
          hilog.warn(DOMAIN, TAG, 'play failed id=%{public}s code=%{public}d', this.media.id, error.code);
          this.onStreamFailed();
        });
      }
      this.tryStartPendingPip();
      return;
    }
    if (state === 'playing') {
      this.playing = true;
      if (this.dataSourceLease !== null) { this.dataSourceLease.setForeground(this.playbackEnabled); }
      this.lastProgressAt = Date.now();
      this.startProgressWatchdog();
      if (this.playbackEnabled) {
        this.claimExclusivePlayback();
        this.scheduleHide();
        this.updatePipControl();
        videoMediaSession.updatePlayback(this.media.id, true, this.playbackRate());
        this.tryStartPendingPip();
        this.syncBackgroundPlayback();
        this.onPlaybackStateChanged(true);
      }
      return;
    }
    if (state === 'paused') {
      this.clearProgressWatchdog();
      if (this.dataSourceLease !== null) { this.dataSourceLease.setForeground(false); }
      this.playing = false;
      this.buffering = false;
      this.clearLoadTimeout();
      if (this.playbackEnabled) {
        this.holdControls();
      } else {
        this.controlsVisible = false;
      }
      this.updatePipControl();
      if (this.playbackEnabled) {
        videoMediaSession.updatePlayback(this.media.id, false, this.playbackRate());
        this.syncBackgroundPlayback();
        this.onPlaybackStateChanged(false);
        if (!this.isAnimatedGif()) {
          videoPlaybackPositionStore.remember(this.media.id, this.positionSec);
        }
      }
      return;
    }
    if (state === 'completed') {
      this.clearProgressWatchdog();
      this.playing = false;
      this.buffering = false;
      this.clearLoadTimeout();
      videoPlaybackCoordinator.release(this.media.id);
      if (this.playbackEnabled) {
        this.holdControls();
      } else {
        this.controlsVisible = false;
      }
      this.updatePipControl();
      if (this.playbackEnabled) {
        videoMediaSession.updatePlayback(this.media.id, false, this.playbackRate());
        this.onPlaybackStateChanged(false);
        videoPlaybackPositionStore.clear(this.media.id);
      } else if (this.preloadEnabled) {
        this.preloading = false;
        this.preloaded = true;
        this.seekTo(0);
      }
      if (this.pipActive) {
        this.stopPip();
      }
      this.syncBackgroundPlayback();
      if (this.playbackEnabled) {
        this.onPlaybackCompleted();
      }
      return;
    }
    if (state === 'error') {
      if (!this.sourceTransitioning) {
        this.onStreamFailed();
      }
      this.syncBackgroundPlayback();
    }
  }

  // The surface is created asynchronously by the XComponent, and the url has to
  // be set before prepare(), so both sides call this and whichever arrives last
  // performs the handshake.
  private attachSurfaceAndPrepare(): void {
    const player: mediaKit.AVPlayer | null = this.player;
    if (player === null || this.preparing) {
      return;
    }
    const surface: string = this.fullscreen && this.fullSurfaceId.length > 0 ?
      this.fullSurfaceId : this.inlineSurfaceId;
    if (surface.length === 0) {
      return;
    }
    const nativeState: string = player.state;
    if (nativeState !== 'initialized') {
      if (nativeState === 'prepared' || nativeState === 'playing' ||
        nativeState === 'paused' || nativeState === 'completed') {
        try {
          player.surfaceId = surface;
          this.applyVideoScaleType();
        } catch (error) {
          hilog.warn(DOMAIN, TAG, 'prepared surface rebind failed id=%{public}s', this.media.id);
        }
      }
      return;
    }
    this.preparing = true;
    try {
      player.surfaceId = surface;
    } catch (error) {
      this.preparing = false;
      hilog.error(DOMAIN, TAG, 'surface attach failed id=%{public}s', this.media.id);
      // With autoplay disabled the player may have been initialized before
      // the reader asks to play.  Keep that idle state retryable; once there
      // is an explicit play intent, treat the attach failure as a stream
      // failure and try the alternate rendition.
      if (this.wantsPlay) {
        this.onStreamFailed();
      }
      return;
    }
    const source: string = this.currentSource;
    const strategy: mediaKit.PlaybackStrategy = {
      preferredBufferDuration: this.playbackEnabled ? 10 : 3,
      preferredBufferDurationForPlaying: this.playbackEnabled ? 0.8 : 0.3,
      showFirstFrameOnPrepare: true
    };
    videoPlayerPreparation.prepare(player, strategy).catch((error: BusinessError): void => {
      if (this.player !== player || source !== this.currentSource || !this.alive) { return; }
      this.preparing = false;
      if (error.code === 5400102 && player.state !== 'error') {
        hilog.warn(DOMAIN, TAG, 'prepare control refused id=%{public}s state=%{public}s', this.media.id, player.state);
        return;
      }
      hilog.error(DOMAIN, TAG, 'prepare failed id=%{public}s code=%{public}d', this.media.id, error.code);
      this.onStreamFailed();
    });
  }

  private setPlayerSource(player: mediaKit.AVPlayer): void {
    hilog.info(DOMAIN, TAG, 'video source selected id=%{public}s quality=%{public}d rendition=%{public}s',
      this.media.id, this.videoQuality, this.cacheRendition(this.currentSource));
    const dataSourceLease: VideoDataSourceLease | null = this.dataSourceLease;
    if (dataSourceLease !== null) {
      player.url = dataSourceLease.url;
      hilog.info(DOMAIN, TAG, 'using cached range stream id=%{public}s', this.media.id);
      return;
    }
    const lease: VideoCacheLease | null = this.cacheLease;
    if (lease === null) {
      player.url = this.currentSource;
      return;
    }
    const descriptor: mediaKit.AVFileDescriptor = {
      fd: lease.fd,
      offset: 0,
      length: lease.length
    };
    player.fdSrc = descriptor;
    hilog.info(DOMAIN, TAG, 'using cached video id=%{public}s', this.media.id);
  }

  private onStreamFailed(allowSameSourceRetry: boolean = true, discardCache: boolean = true): void {
    // A rejected prepare/play call and AVPlayer's error event can describe the
    // same failed operation.  Only one of them may advance the fallback state;
    // otherwise the second callback would turn the first fallback attempt into
    // an immediate terminal error.
    if (!this.alive || this.failed || this.sourceTransitioning || this.retryTimer >= 0) {
      return;
    }
    this.onViewerSurfaceReady();
    this.clearLoadTimeout();
    if (!this.playbackEnabled && this.preloadEnabled) {
      this.clearPreloadTimer();
      this.preloading = false;
      this.preloaded = false;
      this.preloadFailed = true;
      this.wantsPlay = false;
      this.playing = false;
      this.buffering = false;
      this.ready = false;
      this.failed = false;
      return;
    }
    if (!discardCache) {
      const lighter: string = this.lighterSource();
      if (lighter.length > 0) {
        hilog.warn(DOMAIN, TAG, 'buffer stall switching to lighter stream id=%{public}s', this.media.id);
        this.switchSource(lighter);
        return;
      }
      if (this.sourceRetryCount < 1) {
        this.sourceRetryCount++;
        hilog.warn(DOMAIN, TAG, 'buffer stall reconnecting with cached spans id=%{public}s', this.media.id);
        this.switchSource(this.currentSource);
        return;
      }
    }
    if (discardCache && this.cacheLease !== null && !this.currentSource.startsWith('file://') && !this.invalidCacheRetried) {
      // A stale or damaged local file must not consume the network fallback.
      // Discard it and retry the same remote rendition once.
      const source: string = this.currentSource;
      this.invalidCacheRetried = true;
      this.invalidateCacheLease(source);
      this.switchSource(source);
      return;
    }
    if (discardCache && this.dataSourceLease !== null) {
      const source: string = this.currentSource;
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      this.recoverRangeSource(context, source, this.dataSourceLease);
      return;
    }
    if (allowSameSourceRetry && this.sourceRetryCount < 1) {
      const retrySource: string = this.currentSource;
      this.sourceRetryCount += 1;
      this.playing = false;
      this.ready = false;
      this.buffering = this.wantsPlay;
      this.retryTimer = setTimeout((): void => {
        this.retryTimer = -1;
        if (this.alive && this.wantsPlay && retrySource === this.currentSource) {
          hilog.warn(DOMAIN, TAG, 'retrying video source id=%{public}s', this.media.id);
          this.switchSource(retrySource);
        }
      }, VIDEO_SOURCE_RETRY_DELAY_MS);
      return;
    }
    const alternate: string = discardCache ? this.fallbackSource() : '';
    if (alternate.length > 0) {
      hilog.warn(DOMAIN, TAG, 'trying alternate video stream id=%{public}s', this.media.id);
      this.switchSource(alternate);
      return;
    }
    this.playing = false;
    this.ready = false;
    this.buffering = false;
    this.failed = true;
    this.clearProgressWatchdog();
    videoMediaSession.release(this.media.id);
    videoPipPlaybackKeeper.unregister(this.media.id);
    this.syncBackgroundPlayback();
  }

  private recoverRangeSource(context: common.UIAbilityContext, source: string, lease: VideoDataSourceLease): void {
    // An AVPlayer HTTP parser error is not evidence that verified CDN bytes
    // are corrupt. Reuse complete spans through fdSrc before downloading again.
    const epoch: number = ++this.proxyPrepareEpoch;
    this.sourceTransitioning = true;
    this.playing = false;
    this.buffering = this.wantsPlay;
    videoPlaybackCache.promoteDataSource(context, this.media.id, this.cacheRendition(source), lease)
      .then((complete: boolean): void => {
        if (!this.alive || epoch !== this.proxyPrepareEpoch || this.currentSource !== source ||
          this.dataSourceLease !== lease) { return; }
        this.sourceTransitioning = false;
        if (!complete) { videoRangeSource.invalidate(context, this.media.id, this.cacheRendition(source), source); }
        // The old stream remains leased until native reset/release finishes.
        this.bypassProgressiveDataSource = true;
        this.switchSource(source);
      });
  }

  private switchSource(source: string): void {
    const player: mediaKit.AVPlayer | null = this.player;
    const previousLease: VideoCacheLease | null = this.cacheLease;
    const previousDataSource: VideoDataSourceLease | null = this.dataSourceLease;
    this.clearSourceRetryTimer();
    if (source !== this.currentSource) {
      this.sourceRetryCount = 0;
      this.invalidCacheRetried = false;
      this.bypassProgressiveDataSource = false;
    }
    this.sourceSwitchPositionSec = this.initialPositionApplied ? this.positionSec : this.initialPositionSeconds;
    this.playbackStartedAt = Date.now();
    this.clearProgressWatchdog();
    this.proxyPrepareEpoch++;
    this.preparingSource = '';
    this.currentSource = source;
    this.cacheLease = this.acquireCacheLease(source);
    this.dataSourceLease = null;
    this.failed = false;
    this.ready = false;
    this.playing = false;
    this.buffering = this.wantsPlay;
    this.positionSec = this.sourceSwitchPositionSec;
    this.preparing = false;
    if (this.wantsPlay) {
      this.armLoadTimeout(FIRST_FRAME_TIMEOUT_MS);
    }
    if (player === null) {
      this.closeCacheLease(previousLease);
      this.closeDataSourceLease(previousDataSource);
      if (this.shouldUseProgressiveDataSource()) {
        this.prepareProgressiveSource();
      } else if (this.requiresProxyDownload(source) && this.cacheLease === null) {
        this.prepareProxySource();
      } else {
        this.createPlayer();
      }
      return;
    }
    if (this.sourceResetPending) {
      // The native reset still owns the original stream. This intermediate
      // source has not reached AVPlayer and can be discarded immediately.
      this.closeCacheLease(previousLease);
      this.closeDataSourceLease(previousDataSource);
      return;
    }
    this.sourceResetPending = true;
    this.resettingCacheLease = previousLease;
    this.resettingDataSourceLease = previousDataSource;
    const closePrevious: () => void = (): void => {
      this.closeCacheLease(previousLease);
      this.closeDataSourceLease(previousDataSource);
      if (this.resettingCacheLease === previousLease) { this.resettingCacheLease = null; }
      if (this.resettingDataSourceLease === previousDataSource) { this.resettingDataSourceLease = null; }
    };
    this.sourceTransitioning = true;
    videoPlayerPreparation.cancel(player);
    player.reset().then((): void => {
      closePrevious();
      if (this.player !== player) { return; }
      this.sourceResetPending = false;
      if (!this.alive) { return; }
      if (this.shouldUseProgressiveDataSource() || (this.requiresProxyDownload(this.currentSource) && this.cacheLease === null)) {
        this.sourceTransitioning = false;
        this.destroyPlayer();
        if (this.shouldUseProgressiveDataSource()) { this.prepareProgressiveSource(); }
        else { this.prepareProxySource(); }
        return;
      }
      try {
        this.setPlayerSource(player);
      } catch (error) {
        this.sourceTransitioning = false;
        this.onStreamFailed();
      }
    }).catch((error: BusinessError): void => {
      // A rejected reset must keep its source alive until release. Capture
      // ownership instead of restoring fields overwritten by a later choice.
      if (this.player !== player) { closePrevious(); return; }
      this.sourceResetPending = false;
      this.sourceTransitioning = false;
      hilog.error(DOMAIN, TAG, 'player reset failed: %{public}d', error.code);
      this.destroyPlayer();
      this.switchSource(this.currentSource);
    });
  }

  private retry(): void {
    if (!this.playbackEnabled && !this.preloadEnabled) {
      return;
    }
    this.wantsPlay = true;
    this.sourceRetryCount = 0;
    this.invalidCacheRetried = false;
    this.bypassProgressiveDataSource = false;
    this.clearSourceRetryTimer();
    this.switchSource(streamSource(this.media, this.videoQuality, this.autoBitrateCap));
  }

  private destroyPlayer(): void {
    this.releaseKeepAwake();
    this.clearProgressWatchdog();
    if (this.handedOff && this.player === null) { return; }
    this.wantsPlay = false;
    this.playing = false;
    this.sourceResetPending = false;
    const player: mediaKit.AVPlayer | null = this.player;
    const activeLease: VideoCacheLease | null = this.cacheLease;
    const resettingLease: VideoCacheLease | null = this.resettingCacheLease;
    const activeDataSource: VideoDataSourceLease | null = this.dataSourceLease;
    const resettingDataSource: VideoDataSourceLease | null = this.resettingDataSourceLease;
    videoPipPlaybackKeeper.unregister(this.media.id);
    videoPlaybackCoordinator.release(this.media.id);
    this.pipResumeDesired = false;
    this.cacheLease = null;
    this.resettingCacheLease = null;
    this.dataSourceLease = null;
    this.resettingDataSourceLease = null;
    videoPlayerHandoff.unregister(this.media.id, player);
    this.playerEpoch += 1;
    this.proxyPrepareEpoch += 1;
    this.preparingSource = '';
    this.clearLoadTimeout();
    this.clearSourceRetryTimer();
    this.clearPreloadTimer();
    this.player = null;
    this.playerState = 'idle';
    if (player === null) {
      this.closeCacheLease(activeLease);
      this.closeCacheLease(resettingLease);
      this.closeDataSourceLease(activeDataSource);
      this.closeDataSourceLease(resettingDataSource);
      return;
    }
    videoPlayerPreparation.cancel(player);
    videoMediaSession.release(this.media.id);
    // Native release can finish after the page has gone. Stop its output now,
    // while retaining the leases until the asynchronous release completes.
    try {
      if (this.canControlPlayer(player)) { player.setVolume(0); }
      if (player.state === 'playing') {
        player.pause().catch((error: BusinessError): void => {
          hilog.warn(DOMAIN, TAG, 'player teardown pause failed: %{public}d', error.code);
        });
      }
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'player teardown mute skipped id=%{public}s', this.media.id);
    }
    player.release().then((): void => {
      this.closeCacheLease(activeLease);
      this.closeCacheLease(resettingLease);
      this.closeDataSourceLease(activeDataSource);
      this.closeDataSourceLease(resettingDataSource);
    }).catch((error: BusinessError): void => {
      this.closeCacheLease(activeLease);
      this.closeCacheLease(resettingLease);
      this.closeDataSourceLease(activeDataSource);
      this.closeDataSourceLease(resettingDataSource);
      hilog.warn(DOMAIN, TAG, 'player release failed: %{public}d', error.code);
    });
  }

  private onInlineSurfaceLoaded(): void {
    this.inlineSurfaceId = this.inlineController.getXComponentSurfaceId();
    this.attachSurfaceAndPrepare();
    // A cold video must open with its cover/loading UI while decoding. Waiting
    // for the first frame here keeps the entire destination invisible.
    this.onViewerSurfaceReady();
  }

  // ---- Playback ------------------------------------------------------------

  private play(): void {
    if (this.casting) {
      videoMediaSession.sendCastCommand(this.media.id, { command: 'play' });
      this.holdControls();
      return;
    }
    if (this.isCoveredByVideoFeed()) { this.pause(); return; }
    if (!this.playbackEnabled && !this.preloadEnabled) {
      this.wantsPlay = false;
      this.setMuted(true);
      this.pause();
      return;
    }
    if (!this.playbackEnabled) {
      this.muted = true;
      this.playbackVolume = 0;
      this.preloading = true;
      this.preloaded = false;
      const silentPlayer: mediaKit.AVPlayer | null = this.player;
      if (silentPlayer !== null) {
        try {
          this.applyPlayerVolume(silentPlayer);
        } catch (error) {
          hilog.warn(DOMAIN, TAG, 'preload volume skipped id=%{public}s', this.media.id);
        }
      }
    }
    if (this.playbackEnabled && this.usesFeedMutePreference() && this.muted !== this.preferredMuted()) {
      this.setMuted(this.preferredMuted());
    }
    if (this.preloadFailed && this.playbackEnabled) {
      this.preloadFailed = false;
      this.sourceRetryCount = 0;
      this.wantsPlay = true;
      this.switchSource(streamSource(this.media, this.videoQuality, this.autoBitrateCap));
      return;
    }
    if (this.failed) {
      this.retry();
      return;
    }
    this.wantsPlay = true;
    if (this.dataSourceLease !== null) { this.dataSourceLease.setForeground(this.playbackEnabled); }
    if (this.player === null && this.shouldUseProgressiveDataSource()) {
      this.prepareProgressiveSource(); return;
    }
    if (this.requiresProxyDownload(this.currentSource) && this.cacheLease === null && this.dataSourceLease === null) {
      this.prepareProxySource(); return;
    }
    if (!this.ready) {
      this.buffering = true;
      this.armLoadTimeout(FIRST_FRAME_TIMEOUT_MS);
    }
    const player: mediaKit.AVPlayer | null = this.player;
    if (player === null) {
      this.createPlayer();
      return;
    }
    if (this.playerState === 'initialized') {
      // Preparation is deferred until the XComponent owns a surface.  This is
      // also the state reached when autoplay was off at component creation,
      // so an explicit first tap must resume the handshake rather than wait
      // for a second tap.
      this.attachSurfaceAndPrepare();
      return;
    }
    if (this.playerState === 'completed') {
      this.seekTo(0);
    }
    if (this.playerState === 'prepared' || this.playerState === 'paused' ||
      this.playerState === 'completed') {
      if (this.playbackEnabled) {
        this.claimExclusivePlayback();
      }
      const source: string = this.currentSource;
      player.play().catch((error: BusinessError): void => {
        if (source !== this.currentSource) {
          return;
        }
        hilog.warn(DOMAIN, TAG, 'play failed id=%{public}s code=%{public}d', this.media.id, error.code);
        this.onStreamFailed();
      });
    }
  }

  private pause(): void {
    if (this.handedOff && this.player === null) {
      this.wantsPlay = false;
      this.clearProgressWatchdog();
      this.clearLoadTimeout();
      return;
    }
    this.finishHoldSeek(false);
    if (this.casting) {
      videoMediaSession.sendCastCommand(this.media.id, { command: 'pause' });
      this.holdControls();
      return;
    }
    this.wantsPlay = false;
    this.clearProgressWatchdog();
    if (this.dataSourceLease !== null) { this.dataSourceLease.setForeground(false); }
    videoPlaybackCoordinator.release(this.media.id);
    this.buffering = false;
    this.clearLoadTimeout();
    if (this.playbackEnabled) {
      this.holdControls();
    } else {
      this.controlsVisible = false;
    }
    const player: mediaKit.AVPlayer | null = this.player;
    if (player !== null && this.playerState === 'playing') {
      player.pause();
    }
  }

  private playerInputKey(event: KeyEvent): boolean {
    if (!this.playbackEnabled || !this.alive || !plainInputKey(event)) { return false; }
    if (activateInputKey(event, (): void => this.togglePlay())) { return true; }
    if (event.keyCode === KeyCode.KEYCODE_DPAD_LEFT || event.keyCode === KeyCode.KEYCODE_DPAD_RIGHT) {
      if (event.type === KeyType.Down) { this.seekBy(event.keyCode === KeyCode.KEYCODE_DPAD_LEFT ? -10 : 10); }
      return true;
    }
    return false;
  }

  private togglePlay(): void {
    if (this.failed) {
      this.retry();
      return;
    }
    if (this.playing) {
      this.pipResumeDesired = false;
      this.pause();
    } else {
      if (this.pipActive) {
        this.pipResumeDesired = true;
      }
      this.play();
    }
  }

  private seekTo(seconds: number): void {
    const player: mediaKit.AVPlayer | null = this.player;
    const target: number = this.durationSec > 0 ?
      Math.max(0, Math.min(seconds, this.durationSec)) : Math.max(0, seconds);
    this.positionSec = target;
    if (this.casting) {
      videoMediaSession.sendCastCommand(this.media.id, { command: 'seek', parameter: Math.round(target * 1000) });
      return;
    }
    if (this.playbackEnabled && !this.isAnimatedGif()) {
      videoPlaybackPositionStore.remember(this.media.id, target);
    }
    if (player === null || !this.canControlPlayer(player)) {
      this.pendingSeekSeconds = target;
      return;
    }
    this.lastProgressAt = Date.now();
    try {
      player.seek(Math.round(target * 1000), mediaKit.SeekMode.SEEK_CLOSEST);
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'seek refused id=%{public}s', this.media.id);
    }
  }

  private canControlPlayer(player: mediaKit.AVPlayer): boolean {
    const state: mediaKit.AVPlayerState = player.state;
    return state === 'prepared' || state === 'playing' || state === 'paused' || state === 'completed';
  }

  private applyPlayerVolume(player: mediaKit.AVPlayer): void {
    if (this.canControlPlayer(player)) { player.setVolume(this.muted ? 0 : this.playbackVolume); }
  }

  private toggleMutedFromUser(): void {
    this.setMuted(!this.muted, true, true);
    this.saveFeedMuteChoice();
  }

  private onInlineAudioTap(): void {
    if (!this.playing) {
      this.setMuted(false, true, true);
      this.saveFeedMuteChoice();
    } else {
      this.toggleMutedFromUser();
    }
    if (!this.muted && !this.playing) {
      this.play();
    }
  }

  private inlineAudioMuted(): boolean {
    return this.muted || this.hideInlineVideoControls() && (!this.playing || this.failed);
  }

  private saveFeedMuteChoice(): void {
    if (!this.usesFeedMutePreference() || !this.playbackEnabled || this.casting ||
      this.preferredMuted() === this.muted) {
      return;
    }
    // Publish before persistence so the next post follows the choice even if
    // writing preferences is temporarily unavailable.
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    if (this.usesViewerMutePreference()) {
      mediaSettingsStore.publishViewerVideoMuted(this.muted);
      mediaSettingsStore.saveViewerVideoMuted(context, this.muted);
    } else {
      mediaSettingsStore.publishHomeVideoMuted(this.muted);
      mediaSettingsStore.saveHomeVideoMuted(context, this.muted);
    }
  }

  private setMuted(muted: boolean, claimPlayback: boolean = true, selected: boolean = false): void {
    if (this.casting) {
      if (this.muted !== muted) {
        this.muted = muted;
        videoMediaSession.sendCastCommand(this.media.id, { command: 'toggleMute' });
      }
      this.holdControls();
      return;
    }
    this.muted = this.isAnimatedGif() || !this.playbackEnabled ? true : muted;
    if (this.muted) {
      videoPlaybackCoordinator.release(this.media.id);
    } else if (this.playbackEnabled && claimPlayback) {
      this.claimExclusivePlayback(selected);
    }
    this.playbackVolume = this.muted ? 0 : 1;
    const player: mediaKit.AVPlayer | null = this.player;
    if (player === null) {
      return;
    }
    try {
      this.applyPlayerVolume(player);
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'volume refused id=%{public}s', this.media.id);
    }
  }

  private claimExclusivePlayback(selected: boolean = false): void {
    if (!this.playbackEnabled || this.muted) {
      return;
    }
    const onReplaced: () => void = (): void => {
      this.setMuted(true);
      // Visible Home previews share the screen; only their audio is exclusive.
      // Viewer, fullscreen and PiP playback keep the existing pause behavior.
      if (!this.homeTimelineVideo || this.mediaViewerLayout || this.fullscreen || this.pipActive ||
        this.casting || this.isCoveredByVideoFeed()) {
        this.pause();
      }
    };
    if (this.homeTimelineVideo && !this.mediaViewerLayout && !this.fullscreen && !this.pipActive &&
      !this.casting && !this.isCoveredByVideoFeed()) {
      if (!videoPlaybackCoordinator.claimPreview(this.media.id, onReplaced, selected)) {
        this.setMuted(true, false);
      }
    } else {
      videoPlaybackCoordinator.claim(this.media.id, onReplaced);
    }
  }

  private fullscreenGestureWidth(): number {
    return this.windowWidth > 0 ? this.windowWidth : 360;
  }

  private fullscreenGestureHeight(): number {
    return this.windowHeight > 0 ? this.windowHeight : 640;
  }

  private clampGestureValue(value: number): number {
    return Math.max(0, Math.min(value, 1));
  }

  private currentGestureVolume(): number {
    return this.playbackVolume;
  }

  private startsOnRightSide(event: GestureEvent): boolean {
    if (event.fingerList.length === 0) {
      return true;
    }
    const touchX: number = event.fingerList[0].globalX;
    const centerX: number = this.getUIContext().vp2px(this.fullscreenGestureWidth() / 2);
    return touchX >= centerX;
  }

  private onVideoDoubleTap(event: GestureEvent): void {
    // With the setting off the recognizer is a single tap, preserving the
    // original immediate control/entry action without the double-tap delay.
    if (!this.doubleTapSeekEnabled) {
      if (this.fullscreen) { this.onFullscreenSurfaceTap(); }
      else { this.onVideoSurfaceTap(); }
      return;
    }
    if (!this.alive || !this.ready || this.failed || !this.playbackEnabled || this.playerControlsLocked ||
      this.isAnimatedGif() || this.retainViewerPlayback || this.pipActive || this.casting ||
      this.sourceTransitioning || this.scrubbing || this.holdSpeedActive || this.holdSeekDirection !== 0 ||
      Date.now() < this.suppressVideoTapUntil || this.durationSec <= 0 || event.fingerList.length === 0) { return; }
    const width: number = this.fullscreen ? this.fullscreenGestureWidth() : this.measuredWidth;
    if (width <= 0) { return; }
    const direction: number = event.fingerList[0].localX >= width / 2 ? 1 : -1;
    const target: number = Math.max(0, Math.min(this.durationSec,
      this.positionSec + direction * normalizeVideoDoubleTapSeekSeconds(this.doubleTapSeekSeconds)));
    this.clearDoubleTapSeekHint();
    this.doubleTapSeekAmount = Math.round(Math.abs(target - this.positionSec));
    this.doubleTapSeekDirection = direction;
    this.seekTo(target);
    hapticTick();
    // Seeking keeps the reader's play/pause, mute and speed choices intact.
    this.doubleTapSeekHintTimer = setTimeout((): void => {
      this.doubleTapSeekHintTimer = -1;
      this.doubleTapSeekDirection = 0;
    }, 800);
    hilog.info(DOMAIN, TAG, 'double tap seek direction=%{public}d target=%{public}d', direction, Math.round(target));
  }

  private clearDoubleTapSeekHint(): void {
    if (this.doubleTapSeekHintTimer >= 0) {
      clearTimeout(this.doubleTapSeekHintTimer);
      this.doubleTapSeekHintTimer = -1;
    }
    this.doubleTapSeekDirection = 0;
  }

  private holdSeek(event: GestureEvent): void {
    if (!this.alive || !this.ready || !this.playbackEnabled || this.playerControlsLocked ||
      this.isAnimatedGif() || this.retainViewerPlayback || this.pipActive || this.casting ||
      this.sourceTransitioning || this.durationSec <= 0) {
      this.finishHoldSeek(false);
      return;
    }
    if (this.holdSeekDirection === 0) {
      if (this.scrubbing || event.fingerList.length === 0) { return; }
      const width: number = this.fullscreen ? this.fullscreenGestureWidth() : this.measuredWidth;
      if (width <= 0) { return; }
      const touchX: number = event.fingerList[0].localX;
      // Gesture localX and layout widths are both vp, independent of density.
      this.holdSeekDirection = touchX >= width / 2 ? 1 : -1;
      this.clearHideTimer();
      this.scrubbing = true;
      hapticTick();
    }
    this.suppressVideoTapUntil = Date.now() + 350;
    this.seekTo(this.positionSec + this.holdSeekDirection * HOLD_SEEK_STEP_SECONDS);
  }

  private finishHoldSeek(showControls: boolean = true): void {
    if (this.holdSeekDirection === 0) { return; }
    this.holdSeekDirection = 0;
    this.scrubbing = false;
    this.suppressVideoTapUntil = Date.now() + 350;
    if (showControls && this.alive) { this.holdControls(); }
  }

  // ---- Hold to speed up ----------------------------------------------------

  private holdSpeedUsable(): boolean {
    return this.alive && this.ready && this.playing && this.playbackEnabled &&
      !this.playerControlsLocked && !this.isAnimatedGif() && !this.retainViewerPlayback &&
      !this.pipActive && !this.casting && !this.sourceTransitioning && !this.scrubbing &&
      this.durationSec > 0;
  }

  private beginHoldSpeed(): void {
    if (this.holdSpeedActive || !this.holdSpeedUsable()) {
      return;
    }
    this.holdSpeedRestoreIndex = this.playbackRateIndex;
    this.holdSpeedActive = true;
    this.holdSpeedRate = VIDEO_HOLD_SPEED_RATE;
    this.holdSpeedOriginSet = false;
    this.holdSpeedNotified = true;
    this.suppressVideoTapUntil = Date.now() + 400;
    this.clearHideTimer();
    hapticTick();
    this.setPlayerRate(VIDEO_HOLD_SPEED_RATE);
    this.onHoldSpeedChanged(true, VIDEO_HOLD_SPEED_RATE);
    hilog.info(DOMAIN, TAG, 'holdSpeed begin id=%{public}s', this.media.id);
  }

  // The press is owned by the raw touch stream rather than by the long-press
  // gesture: a recognised long press is dropped as soon as the reader slides
  // their finger, and sliding is exactly how the temporary rate is chosen.
  private onHoldSpeedTouch(event: TouchEvent): void {
    if ((!this.mediaViewerLayout && !this.fullscreen) || !this.holdSpeedEnabled) {
      return;
    }
    if (event.type === TouchType.Down) {
      this.armHoldSpeed(event.touches.length > 0 ? event.touches[0].y : 0);
      return;
    }
    if (event.type === TouchType.Move) {
      if (this.holdSpeedActive) {
        this.trackHoldSpeedMove(event);
      } else if (this.holdSpeedArmed && event.touches.length > 0 &&
        Math.abs(event.touches[0].y - this.holdSpeedDownY) > HOLD_SPEED_SLOP_VP) {
        // Moving before the press settles means the reader is scrolling, not
        // holding: give the gesture back to the list underneath.
        this.disarmHoldSpeed();
      }
      return;
    }
    this.disarmHoldSpeed();
    if (this.holdSpeedActive) {
      this.finishHoldSpeed();
    }
  }

  private armHoldSpeed(downY: number): void {
    this.disarmHoldSpeed();
    this.holdSpeedDownY = downY;
    this.holdSpeedArmed = true;
    this.holdSpeedTimer = setTimeout((): void => {
      this.holdSpeedTimer = -1;
      if (this.holdSpeedArmed && this.alive) {
        this.beginHoldSpeed();
      }
    }, HOLD_SPEED_HOLD_MS);
  }

  private disarmHoldSpeed(): void {
    this.holdSpeedArmed = false;
    if (this.holdSpeedTimer >= 0) {
      clearTimeout(this.holdSpeedTimer);
      this.holdSpeedTimer = -1;
    }
  }

  // Sliding up raises the rate, sliding down lowers it. The mapping is absolute:
  // the rate follows how far the finger travelled from where the hold began, so
  // dragging back returns to the starting speed.
  private trackHoldSpeedMove(event: TouchEvent): void {
    if (event.touches.length === 0) {
      return;
    }
    const fingerY: number = event.touches[0].y;
    if (!this.holdSpeedOriginSet) {
      this.holdSpeedOriginY = fingerY;
      this.holdSpeedOriginSet = true;
      return;
    }
    const steps: number = Math.round((this.holdSpeedOriginY - fingerY) / HOLD_SPEED_STEP_VP);
    this.applyHoldSpeedRate(VIDEO_HOLD_SPEED_RATE + steps * VIDEO_HOLD_SPEED_STEP_RATE);
  }

  private applyHoldSpeedRate(rate: number): void {
    const clamped: number = Math.min(VIDEO_HOLD_SPEED_MAX_RATE,
      Math.max(VIDEO_HOLD_SPEED_MIN_RATE, rate));
    if (Math.abs(clamped - this.holdSpeedRate) < 0.001) {
      return;
    }
    this.holdSpeedRate = clamped;
    this.setPlayerRate(clamped);
    this.onHoldSpeedChanged(true, clamped);
  }

  private finishHoldSpeed(): void {
    if (!this.holdSpeedActive) { return; }
    this.holdSpeedActive = false;
    this.holdSpeedOriginSet = false;
    this.holdSpeedRate = VIDEO_HOLD_SPEED_RATE;
    this.suppressVideoTapUntil = Date.now() + 400;
    // The reader's own rate choice survives the temporary boost.
    this.playbackRateIndex = this.holdSpeedRestoreIndex;
    const player: mediaKit.AVPlayer | null = this.player;
    if (player !== null) { this.applyPlaybackRate(player); }
    videoMediaSession.updatePlayback(this.media.id, this.playing, this.playbackRate());
    this.notifyHoldSpeedEnded();
    if (this.alive) { this.holdControls(); }
  }

  private notifyHoldSpeedEnded(): void {
    if (!this.holdSpeedNotified) { return; }
    this.holdSpeedNotified = false;
    this.onHoldSpeedChanged(false, this.playbackRate());
  }

  private setPlayerRate(rate: number): void {
    if (this.casting) {
      return;
    }
    const player: mediaKit.AVPlayer | null = this.player;
    if (player === null || !this.canControlPlayer(player)) {
      return;
    }
    try {
      player.setPlaybackRate(rate);
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'hold speed refused id=%{public}s', this.media.id);
    }
  }

  private finishHoldGesture(showControls: boolean = true): void {
    if (this.holdSpeedActive) {
      // The touch stream owns a speed hold: a long press the system drops as
      // soon as the finger slides must not end it.
      return;
    }
    this.finishHoldSeek(showControls);
  }

  private showFullscreenGestureHint(): void {
    if (this.fullscreenGestureHintTimer >= 0) {
      clearTimeout(this.fullscreenGestureHintTimer);
    }
    this.fullscreenGestureHintTimer = setTimeout((): void => {
      this.fullscreenGestureHintTimer = -1;
      if (this.alive) {
        this.fullscreenGestureMode = FULLSCREEN_GESTURE_NONE;
      }
    }, FULLSCREEN_GESTURE_HINT_DURATION_MS);
  }

  private setGestureVolume(value: number): void {
    const volume: number = this.clampGestureValue(value);
    const player: mediaKit.AVPlayer | null = this.player;
    this.playbackVolume = volume;
    this.muted = volume <= 0.01;
    if (!this.muted && this.playbackEnabled && this.usesFeedMutePreference()) {
      this.claimExclusivePlayback(true);
    } else if (this.muted) {
      videoPlaybackCoordinator.release(this.media.id);
    }
    this.saveFeedMuteChoice();
    if (player === null) {
      return;
    }
    try {
      this.applyPlayerVolume(player);
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'gesture volume update skipped id=%{public}s', this.media.id);
    }
  }

  private startFullscreenPan(event: GestureEvent): void {
    if (this.playerControlsLocked) {
      return;
    }
    this.clearFullscreenGestureHint();
    this.panStartPosition = this.positionSec;
    this.panStartVolume = this.currentGestureVolume();
    this.panStartBrightness = this.windowBrightness;
    this.panStartsOnRight = this.startsOnRightSide(event);
    this.holdControls();
  }

  private updateFullscreenPan(event: GestureEvent): void {
    if (this.playerControlsLocked) {
      return;
    }
    const horizontal: number = Math.abs(event.offsetX);
    const vertical: number = Math.abs(event.offsetY);
    if (this.fullscreenGestureMode === FULLSCREEN_GESTURE_NONE) {
      if (horizontal < FULLSCREEN_PAN_DISTANCE && vertical < FULLSCREEN_PAN_DISTANCE) {
        return;
      }
      this.fullscreenGestureMode = horizontal >= vertical ? FULLSCREEN_GESTURE_SEEK :
        (event.offsetY < 0 && this.fullscreenFeedSwipeEnabled ? FULLSCREEN_GESTURE_FEED :
          (this.panStartsOnRight ? FULLSCREEN_GESTURE_VOLUME : FULLSCREEN_GESTURE_BRIGHTNESS));
    }
    if (this.fullscreenGestureMode === FULLSCREEN_GESTURE_FEED) {
      this.fullscreenGestureValue = Math.max(0, -event.offsetY);
      return;
    }
    if (this.fullscreenGestureMode === FULLSCREEN_GESTURE_SEEK) {
      if (this.durationSec <= 0) {
        return;
      }
      const width: number = Math.max(1, this.getUIContext().vp2px(this.fullscreenGestureWidth()));
      const target: number = this.panStartPosition + event.offsetX / width * this.durationSec;
      this.positionSec = Math.max(0, Math.min(target, this.durationSec));
      this.fullscreenGestureValue = this.positionSec / this.durationSec;
      return;
    }
    const height: number = Math.max(1, this.getUIContext().vp2px(this.fullscreenGestureHeight()));
    const next: number = this.clampGestureValue(this.fullscreenGestureMode === FULLSCREEN_GESTURE_VOLUME ?
      this.panStartVolume - event.offsetY / height : this.panStartBrightness - event.offsetY / height);
    this.fullscreenGestureValue = next;
    if (this.fullscreenGestureMode === FULLSCREEN_GESTURE_VOLUME) {
      this.setGestureVolume(next);
      return;
    }
    this.windowBrightness = next;
    this.setFullscreenBrightness(next);
  }

  private finishFullscreenPan(commit: boolean): void {
    if (this.fullscreenGestureMode === FULLSCREEN_GESTURE_FEED) {
      const advance: boolean = commit && this.fullscreenGestureValue >= 64;
      this.fullscreenGestureMode = FULLSCREEN_GESTURE_NONE;
      if (advance) { this.exitFullscreen(); this.onFullscreenFeedSwipe(); }
      return;
    }
    if (this.fullscreenGestureMode === FULLSCREEN_GESTURE_SEEK) {
      if (commit) {
        this.seekTo(this.positionSec);
      } else {
        this.positionSec = this.panStartPosition;
      }
    }
    if (this.fullscreenGestureMode !== FULLSCREEN_GESTURE_NONE) {
      this.showFullscreenGestureHint();
    }
  }

  private lockPlayerControls(): void {
    if (!this.fullscreen) {
      return;
    }
    this.playerControlsLocked = true;
    this.clearHideTimer();
    this.controlsVisible = true;
    this.clearFullscreenGestureHint();
    this.clearFullscreenPinchHint();
  }

  private unlockPlayerControls(): void {
    if (!this.playerControlsLocked) {
      return;
    }
    this.playerControlsLocked = false;
    if (this.playing) { this.scheduleHide(); } else { this.holdControls(); }
  }

  private applyVideoScaleType(): void {
    const player: mediaKit.AVPlayer | null = this.player;
    if (player === null || !this.canControlPlayer(player)) {
      return;
    }
    try {
      // Fullscreen defaults to fitting the whole frame. A deliberate pinch-out
      // switches to crop-fill; pinch-in restores the uncropped frame.
      if (this.fullscreen) {
        player.videoScaleType = this.fullscreenFill ?
          mediaKit.VideoScaleType.VIDEO_SCALE_TYPE_FIT_CROP :
          mediaKit.VideoScaleType.VIDEO_SCALE_TYPE_SCALED_ASPECT;
        return;
      }
      if (this.fillsSmallFeedGap()) {
        player.videoScaleType = mediaKit.VideoScaleType.VIDEO_SCALE_TYPE_FIT_CROP;
        return;
      }
      player.videoScaleType = this.containVideo || this.mediaViewerLayout ? mediaKit.VideoScaleType.VIDEO_SCALE_TYPE_SCALED_ASPECT :
        this.immersiveVideo || this.fillVideoViewport ?
        mediaKit.VideoScaleType.VIDEO_SCALE_TYPE_FIT_CROP :
        (this.adaptiveShortVideo ? mediaKit.VideoScaleType.VIDEO_SCALE_TYPE_SCALED_ASPECT :
          mediaKit.VideoScaleType.VIDEO_SCALE_TYPE_FIT_CROP);
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'scale update skipped id=%{public}s', this.media.id);
    }
  }

  private showFullscreenPinchHint(): void {
    this.fullscreenPinchHint = true;
    if (this.fullscreenPinchHintTimer >= 0) {
      clearTimeout(this.fullscreenPinchHintTimer);
    }
    this.fullscreenPinchHintTimer = setTimeout((): void => {
      this.fullscreenPinchHintTimer = -1;
      if (this.alive) {
        this.fullscreenPinchHint = false;
      }
    }, FULLSCREEN_PINCH_HINT_DURATION_MS);
  }

  private onFullscreenPinch(event: GestureEvent): void {
    if (!this.fullscreen) {
      return;
    }
    if (event.scale >= FULLSCREEN_PINCH_FILL_THRESHOLD) {
      if (!this.fullscreenFill) {
        this.fullscreenFill = true;
        this.applyVideoScaleType();
      }
      this.showFullscreenPinchHint();
      return;
    }
    if (event.scale <= FULLSCREEN_PINCH_FIT_THRESHOLD) {
      if (this.fullscreenFill) {
        this.fullscreenFill = false;
        this.applyVideoScaleType();
      }
      this.showFullscreenPinchHint();
    }
  }

  // ---- Fullscreen ----------------------------------------------------------

  private enterFullscreen(landscape: boolean = false): void {
    if (this.fullscreen) {
      return;
    }
    hilog.info(DOMAIN, TAG, 'enter fullscreen id=%{public}s', this.media.id);
    if (this.pipActive) {
      this.stopPip();
    }
    this.mutedBeforeFullscreen = this.muted;
    this.fullscreenFill = false;
    this.playerControlsLocked = false;
    this.fullscreenOwnerId = this.fullscreenInstanceKey;
    this.fullscreen = true;
    this.scheduleHide();
    this.setFullscreenWindowOrientation(true, landscape);
    this.setFullscreenWindowState(true);
    this.setMuted(this.usesFeedMutePreference() ? this.preferredMuted() : false);
    // Fullscreen playback is what the control centre should drive, so the
    // media session takes over from here.
    this.claimMediaSession();
    this.syncBackgroundPlayback();
  }

  private onViewerFullscreenRequested(): void {
    if (this.viewerFullscreenRequest > 0 && this.mediaViewerLayout && this.playbackEnabled) {
      this.enterFullscreen(true);
    }
  }

  private onCaptionRequestedChanged(): void {
    this.aiCaptionShown = this.captionRequested;
  }

  private onVideoScaleModeChanged(): void {
    this.finishHoldSeek(false);
    if (this.controlsShouldStayVisible()) {
      this.holdControls();
    } else if (this.playing) {
      this.scheduleHide();
    }
    const player: mediaKit.AVPlayer | null = this.player;
    if (player === null || (this.playerState !== 'prepared' && this.playerState !== 'playing' &&
      this.playerState !== 'paused' && this.playerState !== 'completed')) {
      return;
    }
    this.applyVideoScaleType();
  }

  private onVideoQualityChanged(): void {
    if (this.alive && this.player !== null) {
      this.sourceRetryCount = 0;
      this.switchSource(streamSource(this.media, this.videoQuality, this.autoBitrateCap));
    }
  }

  private onAutoBitrateCapChanged(): void {
    if (!this.alive || this.videoQuality !== VIDEO_QUALITY_DATA_SAVER || this.player === null) {
      return;
    }
    const selectedSource: string = streamSource(this.media, this.videoQuality, this.autoBitrateCap);
    if (selectedSource.length > 0 && selectedSource !== this.currentSource) {
      this.sourceRetryCount = 0;
      this.switchSource(selectedSource);
    }
  }

  private onManualStartChanged(): void {
    if (this.playbackEnabled && this.manualStart && !this.wantsPlay) {
      this.play();
    }
  }

  private onFullscreenSurfaceTap(): void {
    if (this.holdSeekDirection !== 0 || Date.now() < this.suppressVideoTapUntil) { return; }
    if (this.playerControlsLocked) {
      if (this.isWindowLandscape()) { this.scheduleHide(); }
      else { this.unlockPlayerControls(); }
      return;
    }
    if (this.isWindowLandscape()) { this.toggleControls(); return; }
    if (this.mediaViewerLayout && this.videoFeedTapPause) { this.togglePlay(); }
    else { this.toggleControls(); }
  }

  private onVideoSurfaceTap(): void {
    if (this.holdSeekDirection !== 0 || Date.now() < this.suppressVideoTapUntil) { return; }
    if (this.linkCardVideo && !this.fullscreen) { this.onLinkCardOpen(); return; }
    if (!this.mediaViewerLayout && !this.fullscreen && !this.isAnimatedGif() &&
      this.onFullscreenIntent(this.positionSec)) { return; }
    if (this.retainViewerPlayback) { this.onViewerCommentDismiss(); return; }
    if (this.mediaViewerLayout && !this.fullscreen) {
      this.onViewerVideoTap();
      if (this.videoFeedTapPause) { this.togglePlay(); return; }
    }
    if (this.isAnimatedGif()) { this.togglePlay(); }
    else if (!this.hideVideoChrome()) { this.toggleControls(); }
  }

  private onVideoLongPress(event: GestureEvent): void {
    if (this.mediaViewerLayout || this.fullscreen) {
      // Touch owns temporary speed so sliding does not cancel the hold.
      if (!this.holdSpeedEnabled) { this.holdSeek(event); }
      return;
    }
    this.requestMediaMenu();
  }

  private requestMediaMenu(): void {
    // Long press and the release tap arrive separately. Keep the release from
    // also toggling playback or revealing the controls behind the menu.
    this.suppressVideoTapUntil = Date.now() + 700;
    this.clearHideTimer();
    this.onMenuRequest();
  }

  private clearPreloadTimer(): void {
    if (this.preloadTimer >= 0) {
      clearTimeout(this.preloadTimer);
      this.preloadTimer = -1;
    }
  }

  private onPreloadEnabledChanged(): void {
    if (!this.alive || this.playbackEnabled) {
      return;
    }
    if (this.preloadEnabled) {
      this.setMuted(true);
      this.play();
      return;
    }
    this.clearPreloadTimer();
    if (this.preloading || this.preloaded) {
      this.preloading = false;
      this.preloaded = false;
      this.wantsPlay = false;
      this.setMuted(true);
      this.pause();
      this.seekTo(0);
    }
  }

  private onPlaybackEnabledChanged(): void {
    this.syncKeepAwake();
    if (!this.alive) {
      return;
    }
    if (this.handedOff && this.player === null && !this.playbackEnabled) { this.wantsPlay = false; return; }
    if (this.dataSourceLease !== null) { this.dataSourceLease.setForeground(this.playbackEnabled); }
    if (!this.playbackEnabled) {
      // A page that stops playing cannot keep a temporary boost on screen.
      this.finishHoldSpeed();
      this.pendingPip = false;
      this.pipResumeDesired = false;
      this.setMuted(true);
      if (this.preloadEnabled) {
        this.play();
      } else {
        const wasPreloaded: boolean = this.preloading || this.preloaded;
        this.clearPreloadTimer();
        this.preloading = false;
        this.preloaded = false;
        this.pause();
        if (wasPreloaded) {
          this.seekTo(0);
        }
      }
      videoMediaSession.release(this.media.id);
      this.syncBackgroundPlayback();
      if (this.pipActive) {
        this.stopPip();
      }
      return;
    }
    if (this.takeRequestedPlayer()) { return; }
    if (this.mediaViewerLayout) {
      // A cached preload hides its controls. Restore them on activation even
      // while native playback is still preparing or waiting for a play callback.
      this.holdControls();
      this.onControlsVisibilityChanged();
    }
    // Start visible-first-frame timing at activation, excluding time spent
    // waiting as a neighboring preload while another video was on screen.
    if (!this.ready) { this.playbackStartedAt = Date.now(); }
    const wasPreloaded: boolean = this.preloading || this.preloaded;
    this.clearPreloadTimer();
    this.preloading = false;
    this.preloaded = false;
    const shouldAutoPlay: boolean = this.preloadFailed || this.exploreHeroVideo || this.videoAutoplay || this.manualStart;
    if (wasPreloaded && this.playerState === 'playing') {
      if (shouldAutoPlay) {
        this.seekTo(0);
        this.setMuted(this.startMuted());
        // The preload is already playing silently. Keep that AVPlayer run alive
        // and hand it to the visible page instead of pausing and waiting for a
        // stateChange callback before starting it again.
        this.onPlayerState('playing');
      } else {
        this.pause();
        this.seekTo(0);
        this.setMuted(this.startMuted());
      }
      return;
    }
    if (wasPreloaded) {
      this.pause();
      this.seekTo(0);
    }
    this.setMuted(this.startMuted());
    if (shouldAutoPlay) {
      this.play();
    } else if (wasPreloaded) {
      this.pause();
      this.seekTo(0);
    }
  }

  private onMediaChanged(): void {
    this.syncDecodedVideoSize();
  }

  private seekBy(seconds: number): void {
    let target: number = this.positionSec + seconds;
    if (this.durationSec > 0) {
      target = Math.max(0, Math.min(target, this.durationSec));
    } else {
      target = Math.max(0, target);
    }
    this.seekTo(target);
  }

  private exitFullscreen(resetWindowState: boolean = true): void {
    this.finishHoldSeek(false);
    if (!this.fullscreen) {
      return;
    }
    hilog.info(DOMAIN, TAG, 'exit fullscreen id=%{public}s resetWindow=%{public}s',
      this.media.id, resetWindowState.toString());
    this.fullscreen = false;
    this.bindInlineSurface();
    this.setMuted(this.usesFeedMutePreference() ? this.preferredMuted() : this.mutedBeforeFullscreen);
    videoMediaSession.release(this.media.id);
    this.fullscreenFill = false;
    this.playerControlsLocked = false;
    this.clearFullscreenPinchHint();
    this.clearFullscreenGestureHint();
    this.applyVideoScaleType();
    if (resetWindowState) {
      this.setFullscreenWindowOrientation(false);
      this.setFullscreenWindowState(false);
    } else {
      this.pause();
    }
    this.syncBackgroundPlayback();
  }

  private onFullscreenChanged(): void {
    if (this.fullscreen) {
      if (this.fullscreenInstanceKey.length > 0 && this.fullscreenOwnerId !== this.fullscreenInstanceKey) {
        this.fullscreenOwnerId = this.fullscreenInstanceKey;
      }
      return;
    }
    if (this.fullscreenOwnerId === this.fullscreenInstanceKey) {
      this.fullscreenOwnerId = '';
    }
  }

  private onFullscreenOwnerChanged(): void {
    if (this.fullscreen && this.fullscreenOwnerId !== this.fullscreenInstanceKey) {
      this.exitFullscreen(false);
    }
  }

  // Feed fullscreen starts in portrait; the title-bar rotate action starts in
  // landscape. USER_ROTATION_* applies that initial direction, then follows the
  // sensor while respecting system rotation lock. Exit restores the app policy.
  private async setFullscreenWindowOrientation(fullscreen: boolean, landscape: boolean = false): Promise<void> {
    this.fullscreenOrientationRequest += 1;
    const request: number = this.fullscreenOrientationRequest;
    const current: window.Window | null = await this.ensurePlayerWindow();
    if (current === null || request !== this.fullscreenOrientationRequest) {
      return;
    }
    let orientation: window.Orientation = appWindowOrientation();
    if (fullscreen) {
      orientation = landscape ? window.Orientation.USER_ROTATION_LANDSCAPE :
        this.mediaViewerLayout ? window.Orientation.USER_ROTATION_PORTRAIT :
          window.Orientation.AUTO_ROTATION_RESTRICTED;
    }
    try {
      await current.setPreferredOrientation(orientation);
    } catch (error) {
      const businessError: BusinessError = error as BusinessError;
      hilog.warn(DOMAIN, TAG, 'fullscreen orientation update failed code=%{public}d', businessError.code);
    }
  }

  private bindInlineSurface(): void {
    const player: mediaKit.AVPlayer | null = this.player;
    if (player === null || this.inlineSurfaceId.length === 0) {
      return;
    }
    if (player.state !== 'initialized' && player.state !== 'stopped' && !this.canControlPlayer(player)) { return; }
    try {
      player.surfaceId = this.inlineSurfaceId;
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'inline surface restore failed id=%{public}s', this.media.id);
    }
  }

  private bindFullSurface(): void {
    const player: mediaKit.AVPlayer | null = this.player;
    if (player === null || this.fullSurfaceId.length === 0) {
      this.attachSurfaceAndPrepare();
      return;
    }
    if (this.playerState === 'initialized') {
      this.attachSurfaceAndPrepare();
      return;
    }
    if (player.state !== 'stopped' && !this.canControlPlayer(player)) { return; }
    try {
      player.surfaceId = this.fullSurfaceId;
      this.applyVideoScaleType();
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'fullscreen surface failed id=%{public}s', this.media.id);
    }
  }

  // ---- Picture in picture --------------------------------------------------

  private pipSupported(): boolean {
    try {
      return PiPWindow.isPiPEnabled();
    } catch (error) {
      return false;
    }
  }

  private async startPip(): Promise<void> {
    if (!this.alive || this.pipActive || this.fullscreen || !this.pipSupported()) {
      return;
    }
    const controller: PiPWindow.PiPController | null = await this.ensurePipController(false);
    if (controller === null || !this.alive || this.pipActive) {
      return;
    }
    videoPipGate.hold(this.media.id);
    this.stopRequested = false;
    const activeController: PiPWindow.PiPController = controller;
    try {
      activeController.setAutoStartEnabled(true);
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'pip auto start enable skipped id=%{public}s', this.media.id);
    }
    activeController.startPiP().then((): void => {
      hilog.info(DOMAIN, TAG, 'pip started id=%{public}s', this.media.id);
    }).catch((error: BusinessError): void => {
      videoPipGate.release(this.media.id);
      if (this.pipController === activeController) {
        this.pipController = null;
        this.pipBoundToFull = false;
      }
      activeController.off('stateChange');
      activeController.off('controlEvent');
      hilog.error(DOMAIN, TAG, 'pip start failed id=%{public}s code=%{public}d',
        this.media.id, error.code);
    });
  }

  // A controller stays bound to one XComponent for its whole life, so the
  // inline cell surface and the fullscreen surface cannot share one. They do
  // not have to: only one floating window can be live at a time, and the two
  // hand-overs never overlap.
  private async ensurePipController(full: boolean): Promise<PiPWindow.PiPController | null> {
    const existing: PiPWindow.PiPController | null = this.pipController;
    if (existing !== null) {
      if (this.pipBoundToFull === full) {
        return existing;
      }
      if (this.pipActive) {
        return null;
      }
      this.teardownPipController();
    }
    const context: common.Context = this.getUIContext().getHostContext() as common.Context;
    const config: PiPWindow.PiPConfiguration = {
      context: context,
      componentController: full ? this.fullController : this.inlineController,
      templateType: PiPWindow.PiPTemplateType.VIDEO_PLAY,
      contentWidth: this.pipWidth,
      contentHeight: this.pipHeight,
      controlGroups: [PiPWindow.VideoPlayControlGroup.FAST_FORWARD_BACKWARD]
    };
    if (this.allowPip) {
      config.navigationId = MAIN_NAVIGATION_ID;
      // Restore the owning destination, rather than this nested player component.
      config.handleId = this.pipNavigationHandleId;
    }
    let controller: PiPWindow.PiPController | null = null;
    try {
      controller = await PiPWindow.create(config);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'pip create failed id=%{public}s', this.media.id);
      return null;
    }
    if (!this.alive) {
      return null;
    }
    this.pipController = controller;
    this.pipBoundToFull = full;
    // The floating window is opt-in everywhere: the scroll hand-off asks for
    // it from the player, and leaving the app asks for it through the
    // background-playback setting.
    controller.setAutoStartEnabled(false);
    controller.on('stateChange', (state: PiPWindow.PiPState, reason: string): void => {
      this.onPipState(state, reason);
    });
    controller.on('controlEvent', (control: PiPWindow.ControlEventParam): void => {
      this.onPipControl(control);
    });
    return controller;
  }

  // Drops a controller that is only armed for a hand-over. No floating window
  // is live, so there is nothing left to stop.
  private teardownPipController(): void {
    const controller: PiPWindow.PiPController | null = this.pipController;
    this.pipController = null;
    this.pipBoundToFull = false;
    if (controller === null) {
      return;
    }
    try {
      controller.setAutoStartEnabled(false);
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'pip auto start release failed id=%{public}s', this.media.id);
    }
    controller.off('stateChange');
    controller.off('controlEvent');
  }

  // ---- Background playback -------------------------------------------------
  //
  // Fullscreen playback is the one the control centre drives, so it is also
  // the video that follows the reader's background-playback setting: either
  // the sound keeps running after the app is left or the screen locks, or the
  // picture moves into the system floating window.

  private syncBackgroundPlayback(): void {
    this.syncKeepAwake();
    if (this.handedOff && this.player === null) { return; }
    const host: common.Context | undefined = this.getUIContext().getHostContext();
    if (host === undefined) {
      return;
    }
    const context: common.UIAbilityContext = host as common.UIAbilityContext;
    const active: boolean = this.alive && (this.fullscreen || this.pipActive) && this.playing && !this.failed;
    if (active) {
      videoBackgroundPlayback.start(this.media.id, context);
    } else {
      videoBackgroundPlayback.stop(this.media.id, context);
    }
    if (active && this.videoBackgroundMode === VIDEO_BACKGROUND_PIP && this.pipSupported()) {
      this.armFullscreenPip();
      return;
    }
    this.disarmFullscreenPip();
  }

  private onBackgroundModeChanged(): void {
    this.syncBackgroundPlayback();
  }

  private onBackgroundTick(): void {
    if (!this.pipActive || !this.wantsPlay || this.failed) {
      return;
    }
    this.resumePipPlayback();
    setTimeout((): void => {
      this.resumePipPlayback();
    }, 160);
    setTimeout((): void => {
      this.resumePipPlayback();
    }, 520);
  }

  private resumePipPlayback(): void {
    if (!this.alive || !this.playbackEnabled || !this.pipActive || !this.pipResumeDesired || this.failed) {
      return;
    }
    this.claimMediaSession();
    this.syncBackgroundPlayback();
    const player: mediaKit.AVPlayer | null = this.player;
    if (player === null) {
      return;
    }
    if (this.playerState !== 'prepared' && this.playerState !== 'paused' && this.playerState !== 'playing') {
      return;
    }
    const source: string = this.currentSource;
    player.play().catch((error: BusinessError): void => {
      if (source !== this.currentSource) {
        return;
      }
      hilog.warn(DOMAIN, TAG, 'pip resume failed id=%{public}s code=%{public}d', this.media.id, error.code);
    });
  }

  // The system refuses to open a floating window for an app that is already in
  // the background, so the hand-over is armed while the app is still in front
  // and the system fires it when the reader leaves.
  private armFullscreenPip(): void {
    if (this.fullSurfaceId.length === 0 || this.pipActive) {
      return;
    }
    this.enableFullscreenPipAutoStart();
  }

  private async enableFullscreenPipAutoStart(): Promise<void> {
    const controller: PiPWindow.PiPController | null = await this.ensurePipController(true);
    if (controller === null || !this.alive || !this.fullscreen || !this.playing) {
      return;
    }
    try {
      controller.setAutoStartEnabled(true);
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'pip auto start arming skipped id=%{public}s', this.media.id);
    }
  }

  private disarmFullscreenPip(): void {
    const controller: PiPWindow.PiPController | null = this.pipController;
    if (controller === null || !this.pipBoundToFull || this.pipActive) {
      return;
    }
    this.teardownPipController();
  }

  private appForeground(): boolean {
    return AppStorage.get<boolean>('harmonyx.app_foreground') ?? true;
  }

  private requestPip(): void {
    if (!this.alive || !this.playbackEnabled || this.fullscreen || this.pipActive || !this.pipSupported()) {
      return;
    }
    this.onPipIntent();
    videoPipGate.hold(this.media.id);
    this.pendingPip = true;
    if (!this.playing) {
      this.play();
    }
    this.tryStartPendingPip();
  }

  private tryStartPendingPip(): void {
    if (!this.pendingPip || this.inlineSurfaceId.length === 0) {
      return;
    }
    if (this.playerState !== 'playing' && this.playerState !== 'paused' && this.playerState !== 'prepared') {
      return;
    }
    this.pendingPip = false;
    this.startPip();
  }

  private stopPip(): void {
    const controller: PiPWindow.PiPController | null = this.pipController;
    this.stopRequested = true;
    this.pipResumeDesired = false;
    videoPipPlaybackKeeper.unregister(this.media.id);
    if (controller === null) {
      this.pipActive = false;
      this.stopRequested = false;
      videoPipGate.release(this.media.id);
      return;
    }
    controller.stopPiP().then((): void => {
      this.pipActive = false;
      videoPipGate.release(this.media.id);
    }).catch((error: BusinessError): void => {
      this.pipActive = false;
      videoPipGate.release(this.media.id);
      hilog.warn(DOMAIN, TAG, 'pip stop failed: %{public}d', error.code);
    });
  }

  private async claimMediaSession(): Promise<void> {
    if (this.isAnimatedGif()) {
      return;
    }
    const context: common.Context = this.getUIContext().getHostContext() as common.Context;
    const claimed: boolean = await videoMediaSession.claim(context, this.media.id,
      this.media.previewUrl, this.playbackHandle, this.durationSec, (): void => {
        this.fullscreen = false;
        this.setFullscreenWindowOrientation(false);
      }, 'X 视频', 'video', streamSource(this.media, this.videoQuality, this.autoBitrateCap));
    if (claimed) {
      videoMediaSession.updatePosition(this.media.id, this.positionSec);
      videoMediaSession.updatePlayback(this.media.id, this.playing, this.playbackRate());
    }
  }

  private onCastRequested(): void {
    if (this.castRequestSerial > 0 && this.mediaViewerLayout && this.playbackEnabled && this.alive) {
      this.openCastPicker();
    }
  }

  private async openCastPicker(): Promise<void> {
    try {
      await this.claimMediaSession();
      if (!this.alive || !this.playbackEnabled) {
        this.onViewerCastPickerChanged(false);
        return;
      }
      const context: common.Context = this.getUIContext().getHostContext() as common.Context;
      await videoMediaSession.selectCastDevice(context, this.media.id, (visible: boolean): void => {
        this.onViewerCastPickerChanged(visible);
      });
    } catch (error) {
      this.onViewerCastPickerChanged(false);
      promptAction.showToast({ message: $r('app.string.video_cast_failed') });
    }
  }

  private onCastStateChanged(casting: boolean, state: avSession.AVPlaybackState | undefined): void {
    this.casting = casting;
    this.syncKeepAwake();
    this.onViewerCastingChanged(casting);
    this.clearProgressWatchdog();
    this.holdControls();
    if (state === undefined) { return; }
    if (state.position !== undefined && !this.scrubbing) {
      this.positionSec = state.position.elapsedTime / 1000;
      videoPlaybackPositionStore.remember(this.media.id, this.positionSec);
    }
    if (state.state !== undefined) {
      this.playing = state.state === avSession.PlaybackState.PLAYBACK_STATE_PLAY;
      this.buffering = state.state === avSession.PlaybackState.PLAYBACK_STATE_BUFFERING;
      this.onPlaybackStateChanged(this.playing);
    }
    if (state.muted !== undefined) { this.muted = state.muted; }
    if (state.speed !== undefined) {
      const index: number = FULLSCREEN_PLAYBACK_RATES.indexOf(state.speed);
      if (index >= 0) { this.playbackRateIndex = index; }
    }
  }

  private releasePip(releaseOwnership: boolean = true): void {
    const controller: PiPWindow.PiPController | null = this.pipController;
    this.pipController = null;
    this.pipBoundToFull = false;
    this.backgroundPip = false;
    this.pipActive = false;
    this.pipResumeDesired = false;
    if (releaseOwnership) {
      videoPipPlaybackKeeper.unregister(this.media.id);
      videoPipGate.release(this.media.id);
    }
    if (controller === null) {
      return;
    }
    this.stopRequested = true;
    controller.stopPiP().then((): void => {
      controller.off('stateChange');
      controller.off('controlEvent');
    }).catch((): void => {
      controller.off('stateChange');
      controller.off('controlEvent');
    });
  }

  private onPipState(state: PiPWindow.PiPState, reason: string): void {
    hilog.info(DOMAIN, TAG, 'pip state id=%{public}s state=%{public}d reason=%{public}s',
      this.media.id, state, reason);
    if (state === PiPWindow.PiPState.STARTED) {
      this.pipActive = true;
      this.pipResumeDesired = this.wantsPlay || this.playing;
      this.pipPlaybackHandle.update(this.media.id, (): void => {
        this.resumePipPlayback();
      });
      videoPipPlaybackKeeper.register(this.pipPlaybackHandle);
      // "autoStart" means the app went to the background with the floating
      // window armed by the background-playback setting.
      if (reason === 'autoStart') {
        this.backgroundPip = true;
      }
      // The floating window shows this cell's surface, so the list must not
      // unmount the cell while it scrolls on.
      videoPipGate.hold(this.media.id);
      this.claimMediaSession();
      this.updatePipControl();
      this.syncBackgroundPlayback();
      return;
    }
    if (state === PiPWindow.PiPState.STOPPED) {
      const restored: boolean = reason === 'panelActionRestore';
      const requested: boolean = this.stopRequested;
      const offscreen: boolean = this.lastRatio <= PLAYER_HIDE_RATIO;
      const retained: boolean = this.retainedForPip;
      const background: boolean = this.backgroundPip;
      this.pipActive = false;
      this.stopRequested = false;
      this.retainedForPip = false;
      this.backgroundPip = false;
      this.pipResumeDesired = false;
      videoPipPlaybackKeeper.unregister(this.media.id);
      videoPipGate.release(this.media.id);
      this.syncBackgroundPlayback();
      if (retained && !restored) {
        this.alive = false;
        this.releasePipCallbacks();
        this.destroyPlayer();
        return;
      }
      if (restored) {
        if (this.wantsPlay && !this.playing && !this.failed) {
          this.play();
        }
        return;
      }
      if (background) {
        // The reader either tapped the floating window to come back to the
        // app, or closed it while the app stayed behind. Only the second case
        // stops the video.
        if (!requested && (reason === 'panelActionRestore' || this.appForeground())) {
          if (this.wantsPlay && !this.playing && !this.failed) {
            this.play();
          }
          return;
        }
        this.pause();
        return;
      }
      // The floating window closed by itself — the reader dismissed it — so the
      // video should not keep running unseen.
      if (!requested || offscreen) {
        this.pause();
      }
    }
  }

  private onPipControl(control: PiPWindow.ControlEventParam): void {
    if (control.controlType === PiPWindow.PiPControlType.FAST_FORWARD) {
      this.seekBy(PIP_SEEK_STEP_SECONDS);
      return;
    }
    if (control.controlType === PiPWindow.PiPControlType.FAST_BACKWARD) {
      this.seekBy(-PIP_SEEK_STEP_SECONDS);
      return;
    }
    if (control.controlType !== PiPWindow.PiPControlType.VIDEO_PLAY_PAUSE) {
      return;
    }
    if (control.status === PiPWindow.PiPControlStatus.PLAY) {
      this.pipResumeDesired = true;
      this.play();
    } else if (control.status === PiPWindow.PiPControlStatus.PAUSE) {
      this.pipResumeDesired = false;
      this.pause();
    }
  }

  private updatePipControl(): void {
    const controller: PiPWindow.PiPController | null = this.pipController;
    if (controller === null || !this.pipActive) {
      return;
    }
    try {
      controller.updatePiPControlStatus(PiPWindow.PiPControlType.VIDEO_PLAY_PAUSE,
        this.playing ? PiPWindow.PiPControlStatus.PLAY : PiPWindow.PiPControlStatus.PAUSE);
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'pip control status skipped id=%{public}s', this.media.id);
    }
  }

  private releasePipCallbacks(): void {
    const controller: PiPWindow.PiPController | null = this.pipController;
    this.pipController = null;
    this.pipBoundToFull = false;
    this.backgroundPip = false;
    this.pipResumeDesired = false;
    videoPipPlaybackKeeper.unregister(this.media.id);
    if (controller === null) {
      return;
    }
    controller.off('stateChange');
    controller.off('controlEvent');
  }

  // ---- Visibility ----------------------------------------------------------
  //
  // This is the rule the reader asked for: a playing video that leaves the
  // screen hands itself to the floating window instead of stopping, and coming
  // back into view takes it over again.

  private onVisibleChange(isExpanding: boolean, ratio: number): void {
    if (ratio <= PLAYER_HIDE_RATIO) { this.finishHoldSeek(false); }
    this.lastRatio = ratio;
    // Moving the viewer surface into PiP hides its original viewport.
    if (this.pipActive && this.mediaViewerLayout) { return; }
    if (this.casting) { return; }
    if (videoPlayerHandoff.isReturning(this.media.id, this.fullscreenInstanceKey)) { return; }
    if (this.isCoveredByVideoFeed()) { this.pause(); return; }
    if (!this.playbackEnabled) {
      if (this.playing && !this.preloadEnabled) {
        this.setMuted(true);
        this.pause();
      }
      return;
    }
    // The current feed owns playback while its comments cover/shrink the surface.
    // Explicit pause/mute buttons still act on this same AVPlayer.
    if (this.retainViewerPlayback) {
      return;
    }
    if (isExpanding) {
      if (ratio < PLAYER_PLAY_RATIO) {
        return;
      }
      if (this.pipActive) {
        this.stopPip();
        return;
      }
      if ((this.videoAutoplay || this.exploreHeroVideo) && !this.wantsPlay && !this.failed && !this.fullscreen) {
        this.play();
      }
      return;
    }
    if (ratio > PLAYER_HIDE_RATIO || this.fullscreen || (!this.playing && !this.wantsPlay)) {
      return;
    }
    if (this.playing && this.allowPip && this.autoPip && videoPipGate.isAutoArmed(this.media.id) &&
      this.pipSupported()) {
      this.startPip();
      return;
    }
    this.pause();
  }

  // ---- UI ------------------------------------------------------------------

  private displaySeconds(): number {
    return this.scrubbing ? this.scrubSec : this.positionSec;
  }

  private remainingSeconds(): number {
    return Math.max(0, this.durationSec - this.displaySeconds());
  }

  private playbackRate(): number {
    return FULLSCREEN_PLAYBACK_RATES[this.playbackRateIndex];
  }

  private playbackRateLabel(): string {
    // While the reader is holding the picture, the control strip reports the
    // temporary rate instead of their own choice.
    return videoHoldSpeedLabel(this.holdSpeedActive ? this.holdSpeedRate : this.playbackRate());
  }

  private holdSpeedHint(): string {
    return this.text(this.holdSpeedRate < 1 ? $r('app.string.video_hold_speed_slow_hint') :
      $r('app.string.video_hold_speed_hint'));
  }

  private applyPlaybackRate(player: mediaKit.AVPlayer): void {
    if (!this.canControlPlayer(player)) {
      return;
    }
    try {
      player.setPlaybackRate(this.playbackRate());
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'playback speed refused id=%{public}s', this.media.id);
    }
  }

  private cyclePlaybackRate(): void {
    const lastIndex: number = FULLSCREEN_PLAYBACK_RATES.length - 1;
    this.playbackRateIndex = this.playbackRateIndex >= lastIndex ? 0 : this.playbackRateIndex + 1;
    if (this.casting) {
      videoMediaSession.sendCastCommand(this.media.id, { command: 'setSpeed', parameter: this.playbackRate() });
      this.holdControls();
      return;
    }
    const player: mediaKit.AVPlayer | null = this.player;
    if (player !== null) {
      this.applyPlaybackRate(player);
    }
    videoMediaSession.updatePlayback(this.media.id, this.playing, this.playbackRate());
    this.holdControls();
  }

  private onCoverTapped(): void {
    if (this.failed) {
      this.retry();
      return;
    }
    this.play();
  }

  private onCaptionOpacityChanged(): void {
    if (this.aiCaptionOptions.initialOpacity === this.captionOpacity) {
      return;
    }
    this.aiCaptionOptions.initialOpacity = this.captionOpacity;
    this.captionLayerRevision++;
  }

  // The system caption panel edits the option object it was handed. When it
  // does, the reader's own choice is kept for the next rebuild instead of
  // falling back to the app default.
  private captureCaptionOpacity(): void {
    const value: number = this.aiCaptionOptions.initialOpacity ?? DEFAULT_CAPTION_OPACITY;
    if (!Number.isFinite(value) || value < 0 || value > 1) {
      return;
    }
    if (Math.abs(value - this.captionOpacity) < 0.001) {
      return;
    }
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    mediaSettingsStore.saveCaptionOpacity(context, value);
  }

  private toggleAiCaption(): void {
    if (this.aiCaptionShown) {
      this.captureCaptionOpacity();
    }
    this.aiCaptionShown = !this.aiCaptionShown;
    this.onCaptionChanged(this.aiCaptionShown);
    this.holdControls();
  }

  private aiCaptionHeight(): number {
    if (!this.fullscreen) {
      return AI_CAPTION_INLINE_HEIGHT;
    }
    return this.isWindowLandscape() ? AI_CAPTION_FULLSCREEN_LANDSCAPE_HEIGHT : AI_CAPTION_FULLSCREEN_PORTRAIT_HEIGHT;
  }

  private aiCaptionWidth(): string {
    return this.fullscreen ? '72%' : '82%';
  }

  private aiCaptionScale(): number {
    return this.fullscreen ? AI_CAPTION_FULLSCREEN_SCALE : AI_CAPTION_INLINE_SCALE;
  }

  private aiCaptionHorizontalOffset(): number {
    if (!this.fullscreen) {
      return AI_CAPTION_INLINE_X_OFFSET;
    }
    return this.isWindowLandscape() ?
      AI_CAPTION_FULLSCREEN_LANDSCAPE_X_OFFSET : AI_CAPTION_FULLSCREEN_PORTRAIT_X_OFFSET;
  }

  private aiCaptionVerticalOffset(): number {
    if (!this.fullscreen) {
      return AI_CAPTION_INLINE_Y_OFFSET;
    }
    return 0;
  }

  private isWindowLandscape(): boolean {
    if (this.mediaViewerLayout && (this.viewerUsesSideComments || this.viewerPhoneFeedLayout) && !this.fullscreen) {
      return false;
    }
    return this.windowWidth > this.windowHeight && this.windowHeight > 0;
  }

  private fullscreenVideoBottomOffset(): number {
    if (this.windowWidth <= 0 || this.windowHeight <= 0 || this.pipWidth <= 0 || this.pipHeight <= 0) {
      return AI_CAPTION_VIDEO_EDGE_GAP;
    }
    const containerAspect: number = this.windowWidth / this.windowHeight;
    const videoAspect: number = this.pipWidth / this.pipHeight;
    let displayHeight: number = this.windowHeight;
    if (containerAspect <= videoAspect) {
      displayHeight = this.windowWidth / videoAspect;
    }
    const bottomInset: number = Math.max(0, (this.windowHeight - displayHeight) / 2);
    return bottomInset + AI_CAPTION_VIDEO_EDGE_GAP;
  }

  private aiCaptionBottomOffset(): number {
    if (this.fullscreen) {
      const videoOffset: number = this.fullscreenVideoBottomOffset();
      if (!this.controlsVisible) {
        return videoOffset;
      }
      const panelHeight: number = this.videoControlStyle === VIDEO_CONTROL_STYLE_ORIGINAL ?
        LEGACY_FULLSCREEN_CONTROL_PANEL_HEIGHT : FULLSCREEN_CONTROL_PANEL_HEIGHT;
      const controlOffset: number = this.navigationIndicatorHeight + panelHeight;
      return Math.max(videoOffset, controlOffset);
    }
    if (this.showsProgressBelowVideo() || !this.controlsVisible) {
      return 12;
    }
    const panelHeight: number = this.videoControlStyle === VIDEO_CONTROL_STYLE_ORIGINAL ?
      LEGACY_INLINE_CONTROL_PANEL_HEIGHT : INLINE_CONTROL_PANEL_HEIGHT;
    return this.playerBarBottomOffset + panelHeight + 8;
  }

  private onSliderChange(value: number, mode: SliderChangeMode): void {
    if (mode === SliderChangeMode.Begin) {
      this.holdControls();
      this.scrubbing = true;
      this.scrubSec = value;
      return;
    }
    if (mode === SliderChangeMode.Moving) {
      this.scrubSec = value;
      return;
    }
    this.scrubbing = false;
    this.seekTo(value);
    if (this.playing) {
      this.scheduleHide();
    } else {
      this.holdControls();
    }
  }

  @Builder
  private LegacyProgressLine(): void {
    Slider({
      value: this.displaySeconds(),
      min: 0,
      max: this.durationSec > 0 ? this.durationSec : 1,
      step: 1,
      style: SliderStyle.OutSet
    })
      .width('100%')
      .height(INLINE_PROGRESS_LINE_HEIGHT)
      .selectedColor(this.inlineContrastColor($r('app.color.text_on_brand')))
      .trackColor(this.inlineContrastColor($r('app.color.video_control_progress_track'), 3.2))
      .blockColor(this.inlineContrastColor($r('app.color.text_on_brand')))
      .onChange((value: number, mode: SliderChangeMode): void => this.onSliderChange(value, mode))
      .monopolizeEvents(true)
      .onClick((): void => {
      })
  }

  @Builder
  private LegacyInlineButtons(): void {
    Row({ space: 10 }) {
      SymbolGlyph(this.playing ? $r('sys.symbol.pause_fill') : $r('sys.symbol.play_fill'))
        .fontSize(25)
        .fontColor([$r('app.color.text_on_brand')])
        .accessibilityText(this.playing ? $r('app.string.video_pause') : $r('app.string.video_play'))
        .width(32)
        .height(48)
        .onClick((): void => this.togglePlay())
      Text(clockLabel(this.displaySeconds())).fontFamily(this.appFontFamily)
        .fontSize(13)
        .fontColor($r('app.color.text_on_brand'))
        .width(40)
        .textAlign(TextAlign.Center)
      SymbolGlyph(this.muted ? $r('sys.symbol.speaker_slash_fill') : $r('sys.symbol.speaker_wave_2_fill'))
        .fontSize(22)
        .fontColor([$r('app.color.text_on_brand')])
        .accessibilityText(this.muted ? $r('app.string.video_unmute') : $r('app.string.video_mute'))
        .width(30)
        .height(48)
        .onClick((): void => this.toggleMutedFromUser())
      SymbolGlyph($r('sys.symbol.AI_subtitles'))
        .fontSize(21)
        .fontColor([$r('app.color.text_on_brand')])
        .accessibilityText($r('app.string.video_feed_subtitles'))
        .width(30)
        .height(48)
        .onClick((): void => this.toggleAiCaption())
      if (this.allowPip && this.pipSupported() && !this.pipActive) {
        SymbolGlyph($r('sys.symbol.rectangle_on_rectangle'))
          .fontSize(22)
          .fontColor([$r('app.color.text_on_brand')])
          .accessibilityText($r('app.string.video_pip'))
          .width(30)
          .height(48)
          .onClick((): void => this.requestPip())
      }
      SymbolGlyph($r('sys.symbol.arrow_up_left_and_arrow_down_right'))
        .fontSize(23)
        .fontColor([$r('app.color.text_on_brand')])
        .accessibilityText($r('app.string.video_fullscreen'))
        .width(30)
        .height(48)
        .onClick((): void => {
          if (this.onFullscreenIntent(this.positionSec)) {
            return;
          }
          this.enterFullscreen();
        })
    }
      .width('100%')
      .height(56)
      .padding({ left: 12, right: 12 })
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Center)
  }

  @Builder
  private LegacyFullscreenButtons(): void {
    Row({ space: 8 }) {
      SymbolGlyph(this.playing ? $r('sys.symbol.pause_fill') : $r('sys.symbol.play_fill'))
        .fontSize(25)
        .fontColor([$r('app.color.text_on_brand')])
        .accessibilityText(this.playing ? $r('app.string.video_pause') : $r('app.string.video_play'))
        .width(32)
        .height(48)
        .onClick((): void => this.togglePlay())
      Text(clockLabel(this.displaySeconds())).fontFamily(this.appFontFamily)
        .fontSize(13)
        .fontColor($r('app.color.text_on_brand'))
        .width(38)
        .textAlign(TextAlign.Center)
      SymbolGlyph(this.muted ? $r('sys.symbol.speaker_slash_fill') : $r('sys.symbol.speaker_wave_2_fill'))
        .fontSize(22)
        .fontColor([$r('app.color.text_on_brand')])
        .accessibilityText(this.muted ? $r('app.string.video_unmute') : $r('app.string.video_mute'))
        .width(30)
        .height(48)
        .onClick((): void => this.toggleMutedFromUser())
      SymbolGlyph($r('sys.symbol.AI_subtitles'))
        .fontSize(21)
        .fontColor([$r('app.color.text_on_brand')])
        .accessibilityText($r('app.string.video_feed_subtitles'))
        .width(30)
        .height(48)
        .onClick((): void => this.toggleAiCaption())
      if (this.allowPip && this.pipSupported() && !this.pipActive) {
        SymbolGlyph($r('sys.symbol.rectangle_on_rectangle'))
          .fontSize(22)
          .fontColor([$r('app.color.text_on_brand')])
          .accessibilityText($r('app.string.video_pip'))
          .width(30)
          .height(48)
          .onClick((): void => this.requestPip())
      }
      SymbolGlyph($r('sys.symbol.lock_fill'))
        .fontSize(22)
        .fontColor([$r('app.color.text_on_brand')])
        .accessibilityText($r('app.string.video_player_lock_controls'))
        .width(30)
        .height(48)
        .onClick((): void => this.lockPlayerControls())
      SymbolGlyph($r('sys.symbol.exit_full_screen'))
        .fontSize(24)
        .fontColor([$r('app.color.text_on_brand')])
        .accessibilityText($r('app.string.video_exit_fullscreen'))
        .width(30)
        .height(48)
        .onClick((): void => this.exitFullscreen())
    }
      .width('100%')
      .height(56)
      .padding({ left: 12, right: 12 })
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Center)
  }

  private text(resource: Resource): string {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    return context.resourceManager.getStringSync(resource);
  }

  @Builder
  private EmptyLandscapePost(): void {
    Row() {}
  }

  private fullscreenControlsMaterial(): uiMaterial.Material | undefined {
    if (this.controlMaterial === undefined) {
      this.controlMaterial = SystemMaterialUtil.immersiveMaterial(0, false, false, true, undefined);
    }
    return this.controlMaterial;
  }

  private fullscreenControlsBackground(): ResourceColor {
    return SystemMaterialUtil.isApi26OrAbove() ? Color.Transparent : $r('app.color.video_control_glass_tint');
  }

  private async showLandscapeQuality(): Promise<void> {
    this.holdControls();
    try {
      const result: promptAction.ActionMenuSuccessResponse = await this.getUIContext().getPromptAction().showActionMenu({
        title: this.text($r('app.string.video_feed_quality')),
        buttons: [
          { text: this.text($r('app.string.video_feed_quality_auto')), color: $r('app.color.text_primary') },
          { text: this.text($r('app.string.media_download_quality_hd')), color: $r('app.color.text_primary') },
          { text: this.text($r('app.string.media_download_quality_sd')), color: $r('app.color.text_primary') },
          { text: this.text($r('app.string.media_download_quality_ld')), color: $r('app.color.text_primary') }
        ]
      });
      if (result.index >= 0 && result.index < 4) {
        mediaSettingsStore.saveVideoQuality(this.getUIContext().getHostContext() as common.Context, result.index);
      }
    } catch (error) {}
  }

  @Builder
  private LandscapeViewerControls(): void {
    LandscapeVideoControls({
      playing: $playing, muted: $muted, controlsVisible: $controlsVisible, locked: $playerControlsLocked,
      rateIndex: $playbackRateIndex, positionSeconds: $positionSec, duration: $durationSec,
      scrubbing: $scrubbing, scrubPosition: $scrubSec,
      fullscreen: this.fullscreen, rates: FULLSCREEN_PLAYBACK_RATES,
      backgroundAudio: this.videoBackgroundMode === VIDEO_BACKGROUND_AUDIO,
      holdSpeedActive: this.holdSpeedActive, holdSpeedRate: this.holdSpeedRate,
      statusBarHeight: this.statusBarHeight, navigationIndicatorHeight: this.navigationIndicatorHeight,
      sourceTweet: this.sourceTweet, danmakuAvailable: this.mediaViewerLayout,
      authorFollowing: this.viewerAuthorFollowing,
      danmakuEnabled: this.viewerDanmakuEnabled,
      downloadAvailable: this.mediaViewerLayout && this.videoDownloadButton, downloading: this.viewerDownloading,
      qualityLabel: this.text(this.videoQuality === 1 ? $r('app.string.video_controls_quality_hd') :
        this.videoQuality === 2 ? $r('app.string.video_controls_quality_sd') :
        this.videoQuality === 3 ? $r('app.string.video_controls_quality_ld') : $r('app.string.video_feed_quality_auto')),
      onPlayPause: (): void => { this.togglePlay(); },
      onMute: (): void => { this.toggleMutedFromUser(); },
      onRate: (): void => { this.cyclePlaybackRate(); },
      onSeek: (value: number, mode: SliderChangeMode): void => this.onSliderChange(value, mode),
      onBack: (): void => { if (this.fullscreen) { this.exitFullscreen(); } else { this.onViewerBack(); } },
      onFullscreen: (): void => { if (this.fullscreen) { this.exitFullscreen(); } else { this.enterFullscreen(); } },
      onLock: (): void => { if (this.playerControlsLocked) { this.unlockPlayerControls(); } else { this.lockPlayerControls(); } },
      onAspect: (): void => { this.fullscreenFill = !this.fullscreenFill; this.applyVideoScaleType(); this.showFullscreenPinchHint(); },
      onBackground: (): void => {
        mediaSettingsStore.saveVideoBackgroundMode(this.getUIContext().getHostContext() as common.Context,
          this.videoBackgroundMode === VIDEO_BACKGROUND_AUDIO ? VIDEO_BACKGROUND_PIP : VIDEO_BACKGROUND_AUDIO);
      },
      onMore: (): void => { this.onViewerMore(); },
      onQuality: (): void => { void this.showLandscapeQuality(); },
      onDownload: this.onViewerDownload,
      onFollow: this.onViewerFollow, onComment: this.onViewerComment,
      onDanmakuToggle: this.onViewerDanmakuToggle, onDanmakuSend: this.onViewerDanmakuSend,
      onInteraction: (): void => { if (this.playing) { this.scheduleHide(); } else { this.holdControls(); } }
    })
  }

  @Builder
  private FullscreenControlPanel(): void {
    Column() {
      Row() {
        Row({ space: 12 }) {
          SymbolGlyph(this.playing ? $r('sys.symbol.pause_fill') : $r('sys.symbol.play_fill'))
            .fontSize(28)
            .fontColor([$r('app.color.text_on_brand')])
            .accessibilityText(this.playing ? $r('app.string.video_pause') : $r('app.string.video_play'))
            .width(36)
            .height(48)
            .onClick((): void => {
              hapticTick();
            this.togglePlay();
            })
          Text('-' + clockLabel(this.remainingSeconds())).fontFamily(this.appFontFamily)
            .fontSize(17)
            .fontColor($r('app.color.text_on_brand'))
            .width(58)
            .textAlign(TextAlign.Start)
        }
        .alignItems(VerticalAlign.Center)

        Text(this.playbackRateLabel()).fontFamily(this.appFontFamily)
          .fontSize(22)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_on_brand'))
          .width(58)
          .height(48)
          .textAlign(TextAlign.Center)
          .onClick((): void => {
            hapticTick();
            this.cyclePlaybackRate();
          })

        SymbolGlyph(this.muted ? $r('sys.symbol.speaker_slash_fill') : $r('sys.symbol.speaker_wave_2_fill'))
          .fontSize(28)
          .fontColor([$r('app.color.text_on_brand')])
          .accessibilityText(this.muted ? $r('app.string.video_unmute') : $r('app.string.video_mute'))
          .width(38)
          .height(48)
          .onClick((): void => {
            hapticTick();
            this.toggleMutedFromUser();
          })
        SymbolGlyph($r('sys.symbol.exit_full_screen'))
          .fontSize(27)
          .fontColor([$r('app.color.text_on_brand')])
          .accessibilityText($r('app.string.video_exit_fullscreen'))
          .width(38)
          .height(48)
          .onClick((): void => {
            hapticTick();
            this.exitFullscreen();
          })
      }
      .width('100%')
      .height(56)
      .padding({ left: 26, right: 26 })
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Center)
      .monopolizeEvents(true)
      .onClick((): void => {
      })

      Slider({
        value: this.displaySeconds(),
        min: 0,
        max: this.durationSec > 0 ? this.durationSec : 1,
        step: 1,
        style: SliderStyle.OutSet
      })
        .width('100%')
        .height($r('app.float.video_viewer_seek_height'))
        .trackThickness($r('app.float.video_viewer_seek_track'))
        .blockSize({ width: $r('app.float.video_viewer_seek_thumb'), height: $r('app.float.video_viewer_seek_thumb') })
        .selectedColor($r('app.color.text_on_brand'))
        .blockColor($r('app.color.text_on_brand'))
        .trackColor($r('app.color.video_control_progress_track'))
        .onChange((value: number, mode: SliderChangeMode): void => {
          this.onSliderChange(value, mode);
        })
        .monopolizeEvents(true)
        .onClick((): void => {
        })
        .margin({ top: $r('app.float.video_viewer_seek_gap') })
    }
    .width(this.legacyPlayerBarWidth())
    .padding({ top: 10, bottom: 6 })
    .borderRadius($r('app.float.video_fullscreen_controls_radius'))
    .backgroundColor(this.fullscreenControlsBackground())
    .attributeModifier(materialModifier(this.fullscreenControlsMaterial()))
    .margin({ bottom: this.navigationIndicatorHeight + 8 })
    .transition(TransitionEffect.OPACITY.animation({ duration: 180, curve: Curve.EaseOut })
      .combine(TransitionEffect.translate({ y: 14 })))
  }

  @Builder
  private LegacyFullscreenControlPanel(): void {
    Column({ space: $r('app.float.video_viewer_seek_gap') }) {
      Row() {
        this.LegacyFullscreenButtons();
      }
      .width(this.legacyPlayerBarWidth())
      .height(56)
      .borderRadius($r('app.float.video_fullscreen_controls_radius'))
      .backgroundColor(this.fullscreenControlsBackground())
      .attributeModifier(materialModifier(this.fullscreenControlsMaterial()))
      Slider({
        value: this.displaySeconds(),
        min: 0,
        max: this.durationSec > 0 ? this.durationSec : 1,
        step: 1,
        style: SliderStyle.OutSet
      })
        .width(this.legacyPlayerBarWidth())
        .height($r('app.float.video_viewer_seek_height'))
        .trackThickness($r('app.float.video_viewer_seek_track'))
        .blockSize({ width: $r('app.float.video_viewer_seek_thumb'), height: $r('app.float.video_viewer_seek_thumb') })
        .selectedColor($r('app.color.text_on_brand'))
        .blockColor($r('app.color.text_on_brand'))
        .attributeModifier(materialModifier(this.fullscreenControlsMaterial()))
        .trackColor($r('app.color.video_control_progress_track'))
        .onChange((value: number, mode: SliderChangeMode): void => this.onSliderChange(value, mode))
        .monopolizeEvents(true)
        .onClick((): void => {
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .padding({ bottom: this.navigationIndicatorHeight + 8 })
    .transition(TransitionEffect.OPACITY.animation({ duration: 180, curve: Curve.EaseOut })
      .combine(TransitionEffect.translate({ y: 14 })))
  }

  @Builder
  private PlayerBar(): void {
    Column() {
      Slider({
        value: this.displaySeconds(),
        min: 0,
        max: this.durationSec > 0 ? this.durationSec : 1,
        step: 1,
        style: SliderStyle.OutSet
      })
        .width('100%')
        .height(22)
        .selectedColor($r('app.color.text_on_brand'))
        .blockColor($r('app.color.text_on_brand'))
        .trackColor($r('app.color.video_control_progress_track'))
        .onChange((value: number, mode: SliderChangeMode): void => {
          this.onSliderChange(value, mode);
        })
        .monopolizeEvents(true)
        .onClick((): void => {
        })
        .margin({ bottom: 4 })

      Row() {
        Row({ space: 12 }) {
          SymbolGlyph(this.playing ? $r('sys.symbol.pause_fill') : $r('sys.symbol.play_fill'))
            .fontSize(28)
            .fontColor([$r('app.color.text_on_brand')])
            .accessibilityText(this.playing ? $r('app.string.video_pause') : $r('app.string.video_play'))
            .width(36)
            .height(48)
            .onClick((): void => {
              this.togglePlay();
            })
          Text('-' + clockLabel(this.remainingSeconds())).fontFamily(this.appFontFamily)
            .fontSize(17)
            .fontColor($r('app.color.text_on_brand'))
            .width(58)
            .textAlign(TextAlign.Start)
        }
        .alignItems(VerticalAlign.Center)

        Text(this.playbackRateLabel()).fontFamily(this.appFontFamily)
          .fontSize(22)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_on_brand'))
          .width(58)
          .height(48)
          .textAlign(TextAlign.Center)
          .onClick((): void => {
            this.cyclePlaybackRate();
          })

        SymbolGlyph(this.muted ? $r('sys.symbol.speaker_slash_fill') : $r('sys.symbol.speaker_wave_2_fill'))
          .fontSize(28)
          .fontColor([$r('app.color.text_on_brand')])
          .accessibilityText(this.muted ? $r('app.string.video_unmute') : $r('app.string.video_mute'))
          .width(38)
          .height(48)
          .onClick((): void => {
            this.toggleMutedFromUser();
          })
        if (this.allowPip && this.pipSupported() && !this.pipActive) {
          SymbolGlyph($r('sys.symbol.rectangle_on_rectangle'))
            .fontSize(22)
            .fontColor([$r('app.color.text_on_brand')])
            .accessibilityText($r('app.string.video_pip'))
            .width(38)
            .height(48)
            .onClick((): void => this.requestPip())
        }
        SymbolGlyph($r('sys.symbol.arrow_up_left_and_arrow_down_right'))
          .fontSize(27)
          .fontColor([$r('app.color.text_on_brand')])
          .accessibilityText($r('app.string.video_fullscreen'))
          .width(38)
          .height(48)
          .onClick((): void => {
            if (this.onFullscreenIntent(this.positionSec)) {
              return;
            }
            this.enterFullscreen();
          })
      }
      .width('100%')
      .height(PLAYER_BAR_HEIGHT)
      .padding({ left: 26, right: 26 })
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Center)
      .monopolizeEvents(true)
      .onClick((): void => {
      })
    }
    .width('100%')
    .attributeModifier(materialModifier(this.fullscreenControlsMaterial()))
    .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN)
    .linearGradient({
      angle: 180,
      colors: [[$r('app.color.video_control_gradient_top'), 0.0],
        [$r('app.color.video_control_gradient_bottom'), 1.0]]
    })
    .monopolizeEvents(true)
    .onClick((): void => {
    })
    .width(this.controlsAtScreenBottom ? '100%' : this.displayWidth())
    // Slides and fades away while the video runs, and animates back in the
    // moment the reader pauses or touches the controls.
    .transition(TransitionEffect.OPACITY.animation({ duration: 180, curve: Curve.EaseOut })
      .combine(TransitionEffect.translate({ y: 14 })))
    .padding({ bottom: this.playerBarBottomOffset })
  }

  private inlineControlColor(): ResourceColor {
    return this.mediaViewerLayout ? $r('app.color.text_on_brand') : this.inlineContrastColor($r('app.color.text_primary'));
  }

  private inlineSecondaryControlColor(): ResourceColor {
    return this.mediaViewerLayout ? $r('app.color.video_feed_secondary_text') : this.inlineContrastColor($r('app.color.text_secondary'));
  }

  private inlineContrastColor(original: ResourceColor, minimum: number = 4.6): ResourceColor {
    return this.controlsUsePageBackground && !this.mediaViewerLayout && !this.fullscreen ?
      pageTextColor(original, this.pageBackgroundValue, this.controlSurface, minimum) : original;
  }

  @Builder
  private InlinePlayerBar(): void {
    Column() {
      Slider({
        value: this.displaySeconds(),
        min: 0,
        max: this.durationSec > 0 ? this.durationSec : 1,
        step: 1,
        style: SliderStyle.OutSet
      })
        .width('100%')
        .height(16)
        .padding({ left: 12, right: 12 })
        .selectedColor(this.mediaViewerLayout ? $r('app.color.text_on_brand') : this.inlineContrastColor($r('app.color.brand')))
        .trackColor(this.mediaViewerLayout ? $r('app.color.video_control_progress_track') :
          this.inlineContrastColor($r('app.color.text_secondary'), 3.2))
        .blockColor(this.inlineControlColor())
        .onChange((value: number, mode: SliderChangeMode): void => {
          this.onSliderChange(value, mode);
        })
        .monopolizeEvents(true)
        .onClick((): void => {
        })

      Row() {
        SymbolGlyph(this.playing ? $r('sys.symbol.pause_fill') : $r('sys.symbol.play_fill'))
          .fontSize(24)
          .fontColor([this.inlineControlColor()])
          .accessibilityText(this.playing ? $r('app.string.video_pause') : $r('app.string.video_play'))
          .width(32)
          .height(40)
          .onClick((): void => this.togglePlay())
        Text('-' + clockLabel(this.remainingSeconds())).fontFamily(this.appFontFamily)
          .fontSize(14)
          .fontColor(this.inlineSecondaryControlColor())
          .width(48)
          .textAlign(TextAlign.Center)
        Text(this.playbackRateLabel()).fontFamily(this.appFontFamily)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.inlineControlColor())
          .width(40)
          .height(40)
          .textAlign(TextAlign.Center)
          .onClick((): void => this.cyclePlaybackRate())
        SymbolGlyph(this.muted ? $r('sys.symbol.speaker_slash_fill') : $r('sys.symbol.speaker_wave_2_fill'))
          .fontSize(21)
          .fontColor([this.inlineControlColor()])
          .accessibilityText(this.muted ? $r('app.string.video_unmute') : $r('app.string.video_mute'))
          .width(32)
          .height(40)
          .onClick((): void => this.toggleMutedFromUser())
        if (this.allowPip && this.pipSupported() && !this.pipActive) {
          SymbolGlyph($r('sys.symbol.rectangle_on_rectangle'))
            .fontSize(22)
            .fontColor([this.inlineControlColor()])
            .accessibilityText($r('app.string.video_pip'))
            .width(32)
            .height(40)
            .onClick((): void => this.requestPip())
        }
        SymbolGlyph($r('sys.symbol.arrow_up_left_and_arrow_down_right'))
          .fontSize(22)
          .fontColor([this.inlineControlColor()])
          .accessibilityText($r('app.string.video_fullscreen'))
          .width(32)
          .height(40)
          .onClick((): void => {
            if (this.onFullscreenIntent(this.positionSec)) {
              return;
            }
            this.enterFullscreen();
          })
      }
      .width('100%')
      .height(40)
      .padding({ left: 12, right: 12 })
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Center)
      .monopolizeEvents(true)
      .onClick((): void => {
      })
    }
    .width('100%')
    .height(INLINE_VIDEO_CONTROLS_HEIGHT)
  }

  @Builder
  private CompactPlaybackMenu(): void {
    Menu() {
      MenuItem({ content: this.playing ? $r('app.string.video_pause') : $r('app.string.video_play'),
        labelInfo: this.feedTimeLabel() })
        .onClick((): void => { hapticTick(); this.togglePlay(); })
      MenuItem({ content: $r('app.string.video_playback_speed'), labelInfo: this.playbackRateLabel() })
        .onClick((): void => { hapticTick(); this.cyclePlaybackRate(); })
      MenuItem({ content: this.muted ? $r('app.string.video_unmute') : $r('app.string.video_mute') })
        .onClick((): void => { hapticTick(); this.toggleMutedFromUser(); })
      MenuItem({ content: $r('app.string.video_fullscreen') })
        .onClick((): void => { hapticTick(); this.enterFullscreen(); })
      if (this.allowPip && this.pipSupported() && !this.pipActive) {
        MenuItem({ content: $r('app.string.video_pip') })
          .onClick((): void => { hapticTick(); this.requestPip(); })
      }
    }.onAppear((): void => this.clearHideTimer())
      .onDisAppear((): void => this.scheduleHide())
  }

  @Builder
  private FeedProgressSlider(): void {
    Slider({
      value: this.displaySeconds(),
      min: 0,
      max: this.durationSec > 0 ? this.durationSec : 1,
      step: 1,
      style: SliderStyle.OutSet
    })
      .width('100%')
      .height(this.compactFeedLayout ? $r('app.float.compact_video_seek_height') : $r('app.float.video_viewer_seek_height'))
      .trackThickness(this.compactFeedLayout ? $r('app.float.compact_video_seek_track') : $r('app.float.video_viewer_seek_track'))
      .blockSize({
        width: this.compactFeedLayout ? $r('app.float.compact_video_seek_thumb') : $r('app.float.video_viewer_seek_thumb'),
        height: this.compactFeedLayout ? $r('app.float.compact_video_seek_thumb') : $r('app.float.video_viewer_seek_thumb')
      })
      .margin({ bottom: this.compactFeedLayout ? 0 : $r('app.float.video_viewer_seek_gap') })
      .id('video-viewer-seek')
      .accessibilityText($r('app.string.video_progress'))
      .selectedColor($r('app.color.text_on_brand'))
      .blockColor($r('app.color.text_on_brand'))
      .trackColor($r('app.color.video_control_progress_track'))
      .onChange((value: number, mode: SliderChangeMode): void => {
        this.onSliderChange(value, mode);
        if (mode !== SliderChangeMode.Begin && mode !== SliderChangeMode.Moving) { hapticTick(); }
      })
      .monopolizeEvents(true)
  }

  @Builder
  private FeedPlayerBar(): void {
    Column() {
      if (this.compactFeedLayout && this.compactBottomActions) {
        Row() {
          Row() { this.FeedProgressSlider() }.layoutWeight(1)
          Button({ type: ButtonType.Normal, stateEffect: true }) {
            SymbolGlyph($r('sys.symbol.slider_horizontal_2_square'))
              .fontSize($r('app.float.compact_video_bottom_icon')).fontColor([$r('app.color.text_on_brand')])
          }.width($r('app.float.compact_video_bottom_action_height'))
            .height($r('app.float.compact_video_bottom_action_height')).padding(0)
            .borderRadius($r('app.float.compact_video_bottom_radius')).backgroundColor(Color.Transparent)
            .accessibilityText($r('app.string.settings_category_video_controls')).monopolizeEvents(true)
            .bindMenu(this.CompactPlaybackMenu)
            .id('video-feed-compact-playback-menu')
        }.width('100%').height($r('app.float.compact_video_bottom_action_height'))
          .padding({ left: $r('app.float.compact_video_bottom_inset'), right: $r('app.float.compact_video_bottom_inset') })
        this.compactFeedActions()
      } else {
        this.FeedProgressSlider()
        Row({ space: this.compactFeedLayout ? $r('app.float.compact_video_control_gap') : 14 }) {
          SymbolGlyph(this.playing ? $r('sys.symbol.pause_fill') : $r('sys.symbol.play_fill'))
            .fontSize(24)
            .fontColor([$r('app.color.text_on_brand')])
            .accessibilityText(this.playing ? $r('app.string.video_pause') : $r('app.string.video_play'))
            .width(32)
            .height(this.compactFeedLayout ? $r('app.float.compact_video_controls_row_height') : 48)
            .onClick((): void => { hapticTick(); this.togglePlay(); })
          Text(this.feedTimeLabel()).fontFamily(this.appFontFamily)
            .fontSize(14)
            .fontColor($r('app.color.video_feed_secondary_text'))
            .layoutWeight(1)
            .maxLines(1)
            .height(this.compactFeedLayout ? $r('app.float.compact_video_controls_row_height') : 48)
            .onClick((): void => { hapticTick(); this.feedElapsedTime = !this.feedElapsedTime; this.holdControls(); })
          Text(this.playbackRateLabel()).fontFamily(this.appFontFamily)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_on_brand'))
            .width(40)
            .height(this.compactFeedLayout ? $r('app.float.compact_video_controls_row_height') : 48)
            .textAlign(TextAlign.Center)
            .onClick((): void => { hapticTick(); this.cyclePlaybackRate(); })
          SymbolGlyph(this.muted ? $r('sys.symbol.speaker_slash_fill') : $r('sys.symbol.speaker_wave_2_fill'))
            .fontSize(22)
            .fontColor([$r('app.color.text_on_brand')])
            .accessibilityText(this.muted ? $r('app.string.video_unmute') : $r('app.string.video_mute'))
            .width(32)
            .height(this.compactFeedLayout ? $r('app.float.compact_video_controls_row_height') : 48)
            .onClick((): void => { hapticTick(); this.toggleMutedFromUser(); })
          SymbolGlyph($r('sys.symbol.arrow_up_left_and_arrow_down_right'))
            .fontSize(22)
            .fontColor([$r('app.color.text_on_brand')])
            .accessibilityText($r('app.string.video_fullscreen'))
            .width(32)
            .height(this.compactFeedLayout ? $r('app.float.compact_video_controls_row_height') : 48)
            .onClick((): void => { hapticTick(); this.enterFullscreen(); })
          if (this.allowPip && this.pipSupported() && !this.pipActive) {
            SymbolGlyph($r('sys.symbol.rectangle_on_rectangle'))
              .fontSize(22)
              .fontColor([$r('app.color.text_on_brand')])
              .accessibilityText($r('app.string.video_pip'))
              .width(32)
              .height(this.compactFeedLayout ? $r('app.float.compact_video_controls_row_height') : 48)
              .onClick((): void => { hapticTick(); this.requestPip(); })
          }
        }
        .width('100%')
        .height(this.compactFeedLayout ? $r('app.float.compact_video_controls_row_height') : 48)
        .padding({ left: 16, right: 16 })
        .alignItems(VerticalAlign.Center)
        .monopolizeEvents(true)
        .onClick((): void => {})
      }
    }
    .width('100%')
    .id('video-feed-player-bar')
    .attributeModifier(materialModifier(this.fullscreenControlsMaterial()))
    .height(this.feedPlayerBarHeight())
    .padding({ bottom: this.navigationIndicatorHeight + 8 })
  }

  private feedTimeLabel(): string {
    return this.feedElapsedTime ? clockLabel(this.displaySeconds()) + ' / ' + clockLabel(this.durationSec) :
      '-' + clockLabel(this.remainingSeconds());
  }

  @Builder
  private CommentPreviewControls(): void {
    Row({ space: $r('app.float.media_viewer_comment_control_spacing') }) {
      MaterialButton({
        buttonWidth: $r('app.float.media_viewer_action_height'),
        buttonHeight: $r('app.float.media_viewer_action_height'),
        buttonRadius: $r('app.float.media_viewer_comment_control_radius'),
        surfaceColor: $r('app.color.media_viewer_control'), materialLevel: 0, applyShadow: false,
        materialTint: $r('app.color.media_viewer_comment_control_tint'), buttonPressFeedback: true, buttonMonopolizeEvents: true,
        accessibilityLabel: this.text(this.muted ? $r('app.string.video_unmute') : $r('app.string.video_mute')),
        onButtonClick: (): void => { hapticTick(); this.toggleMutedFromUser(); }
      }) {
        SymbolGlyph(this.muted ? $r('sys.symbol.speaker_slash_fill') : $r('sys.symbol.speaker_wave_2_fill'))
          .fontSize($r('app.float.media_viewer_comment_control_icon_size'))
          .fontColor([$r('app.color.text_on_brand')])
      }
      MaterialButton({
        buttonWidth: $r('app.float.media_viewer_action_height'),
        buttonHeight: $r('app.float.media_viewer_action_height'),
        buttonRadius: $r('app.float.media_viewer_comment_control_radius'),
        surfaceColor: $r('app.color.media_viewer_control'), materialLevel: 0, applyShadow: false,
        materialTint: $r('app.color.media_viewer_comment_control_tint'), buttonPressFeedback: true, buttonMonopolizeEvents: true,
        accessibilityLabel: this.text(this.playing ? $r('app.string.video_pause') : $r('app.string.video_play')),
        onButtonClick: (): void => { hapticTick(); this.togglePlay(); }
      }) {
        Stack({ alignContent: Alignment.Center }) {
          if (this.videoCommentProgressRing && this.durationSec > 0) {
            Progress({ value: this.displaySeconds(), total: this.durationSec, type: ProgressType.Ring })
              .width($r('app.float.media_viewer_comment_progress_size'))
              .height($r('app.float.media_viewer_comment_progress_size'))
              .color($r('app.color.text_on_brand'))
              .backgroundColor(Color.Transparent)
              .opacity(0.75)
              .style({ strokeWidth: $r('app.float.media_viewer_comment_progress_stroke'), enableSmoothEffect: false })
              .accessibilityLevel('no')
              .hitTestBehavior(HitTestMode.None)
          }
          SymbolGlyph(this.playing ? $r('sys.symbol.pause_fill') : $r('sys.symbol.play_fill'))
            .fontSize($r('app.float.media_viewer_comment_control_icon_size'))
            .fontColor([$r('app.color.text_on_brand')])
        }
        .width('100%')
        .height('100%')
      }
    }
    .position({ top: 0, right: $r('app.float.media_viewer_comment_control_inset') })
    .translate({ y: this.commentVideoLayout().controlsY })
    .opacity(this.commentVideoLayout().controlsOpacity)
    .hitTestBehavior(this.viewerCommentProgress > 0 && this.viewerCommentHeight > 0 ?
      HitTestMode.Default : HitTestMode.None)
    .monopolizeEvents(true)
  }

  @Builder
  private LegacyPlayerBar(): void {
    Stack() {
      HdsButton({
        useImmersiveMaterial: true, adaptiveForeground: true,
        barWidth: this.legacyPlayerBarWidth(),
        barHeight: 68,
        surfaceColor: $r('app.color.video_control_glass_tint'),
        enableSurfaceBlur: true,
        enableShadow: false,
        forceHdsStyle: true,
        // HDS EXQUISITE (0) is the highest visual-quality material level.
        materialLevel: 0,
        lightColor: $r('app.color.brand')
      }) {
        this.LegacyInlineButtons();
      }
    }
    .width(this.legacyPlayerBarWidth())
    .height(56)
    .margin({ bottom: this.playerBarBottomOffset })
    .transition(TransitionEffect.OPACITY.animation({ duration: 180, curve: Curve.EaseOut })
      .combine(TransitionEffect.translate({ y: 14 })))
  }

  @Builder
  private LegacyShortVideoControlPanel(): void {
    Column({ space: 2 }) {
      HdsButton({
        useImmersiveMaterial: true, adaptiveForeground: true,
        barWidth: this.legacyPlayerBarWidth(),
        barHeight: 68,
        surfaceColor: $r('app.color.video_control_glass_tint'),
        enableSurfaceBlur: true,
        enableShadow: false,
        forceHdsStyle: true,
        // HDS EXQUISITE (0) is the highest visual-quality material level.
        materialLevel: 0,
        lightColor: $r('app.color.brand')
      }) {
        this.LegacyInlineButtons();
      }
      Slider({
        value: this.displaySeconds(),
        min: 0,
        max: this.durationSec > 0 ? this.durationSec : 1,
        step: 1,
        style: SliderStyle.OutSet
      })
        .width(this.legacyPlayerBarWidth())
        .height(INLINE_PROGRESS_LINE_HEIGHT)
        .selectedColor($r('app.color.text_on_brand'))
        .blockColor($r('app.color.text_on_brand'))
        .attributeModifier(materialModifier(this.fullscreenControlsMaterial()))
        .trackColor($r('app.color.video_control_progress_track'))
        .onChange((value: number, mode: SliderChangeMode): void => this.onSliderChange(value, mode))
        .monopolizeEvents(true)
        .onClick((): void => {
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .padding({ bottom: this.playerBarBottomOffset })
    .transition(TransitionEffect.OPACITY.animation({ duration: 180, curve: Curve.EaseOut })
      .combine(TransitionEffect.translate({ y: 14 })))
  }

  @Builder
  private AiCaptionLayer(): void {
    Stack({ alignContent: Alignment.Bottom }) {
      Stack({ alignContent: Alignment.Bottom }) {
        // The revision in the key forces the system component to be created
        // again after the background opacity changed, which is the only way
        // SpeechKit applies a new `initialOpacity`.
        ForEach([this.captionLayerKey()], (revision: string): void => {
          AICaptionComponent({
            isShown: this.aiCaptionShown,
            controller: this.aiCaptionController,
            options: this.aiCaptionOptions
          })
            .width('100%')
            .height(this.aiCaptionHeight())
            .scale({ x: this.aiCaptionScale(), y: this.aiCaptionScale() })
        }, (revision: string): string => revision)
      }
      .width(this.aiCaptionWidth())
      .height(this.aiCaptionHeight())
      .translate({ x: this.aiCaptionHorizontalOffset(), y: this.aiCaptionVerticalOffset() })
    }
    .width('100%')
    .height(this.aiCaptionHeight())
    .margin({
      bottom: this.aiCaptionBottomOffset()
    })
    .opacity(1 - this.viewerCommentProgress)
  }

  private captionLayerKey(): string {
    return this.captionLayerRevision.toString() + '-' +
      (this.fullscreen ? 'fullscreen' : 'inline');
  }

  @Builder
  private HoldSeekHint(): void {
    if (this.holdSeekDirection !== 0 || this.doubleTapSeekDirection !== 0) {
      Column({ space: 6 }) {
        if (this.holdSeekDirection === 0) {
          Text(this.doubleTapSeekDirection > 0 ? $r('app.string.video_double_tap_forward', this.doubleTapSeekAmount) :
            $r('app.string.video_double_tap_rewind', this.doubleTapSeekAmount)).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_on_brand'))
        } else {
        Text(this.holdSeekDirection > 0 ? $r('app.string.video_hold_fast_forward') : $r('app.string.video_hold_rewind')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_on_brand'))
        }
        Text(clockLabel(this.positionSec) + ' / ' + clockLabel(this.durationSec)).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Title_S')).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_on_brand'))
      }.padding({ left: 16, right: 16, top: 10, bottom: 10 }).borderRadius(16)
        .backgroundColor($r('app.color.media_viewer_control')).hitTestBehavior(HitTestMode.None)
    }
  }

  @Builder
  private FullscreenLayer(): void {
    Stack({ alignContent: Alignment.Center }) {
      Stack({ alignContent: Alignment.Bottom }) {
        XComponent(this.fullOptions)
          .attributeModifier(new VideoHdrEnhancementModifier(this.videoHdrEnhancement && !this.isAnimatedGif(), this.videoHdrSupported))
          .width('100%')
          .height('100%')
          .backgroundColor(Color.Black)
          .onLoad((): void => {
            this.fullSurfaceId = this.fullController.getXComponentSurfaceId();
            this.bindFullSurface();
            // The floating window can only mirror a surface that exists, so the
            // background hand-over is armed once this one is on screen.
            this.syncBackgroundPlayback();
          })
          .onDestroy((): void => {
            this.fullSurfaceId = '';
          })
          .onTouch((event: TouchEvent): void => this.onHoldSpeedTouch(event))
          .gesture(GestureGroup(GestureMode.Exclusive,
            PinchGesture({ fingers: 2, distance: FULLSCREEN_PINCH_DISTANCE })
          .onActionEnd((event: GestureEvent): void => {
            this.onFullscreenPinch(event);
          }),
        PanGesture({ fingers: 1, direction: PanDirection.All, distance: FULLSCREEN_PAN_DISTANCE })
          .onActionStart((event: GestureEvent): void => {
            this.startFullscreenPan(event);
          })
          .onActionUpdate((event: GestureEvent): void => {
            this.updateFullscreenPan(event);
          })
          .onActionEnd((): void => {
            this.finishFullscreenPan(true);
          })
          .onActionCancel((): void => {
            this.finishFullscreenPan(false);
          }),
            LongPressGesture({ fingers: 1, repeat: this.mediaViewerLayout || this.fullscreen, duration: HOLD_SEEK_DURATION_MS })
              .onAction((event: GestureEvent): void => this.onVideoLongPress(event))
              .onActionEnd((): void => this.finishHoldGesture())
              .onActionCancel((): void => this.finishHoldGesture()),
            TapGesture({ count: this.doubleTapSeekEnabled ? 2 : 1, fingers: 1 })
              .onAction((event: GestureEvent): void => this.onVideoDoubleTap(event)),
            TapGesture({ count: 1, fingers: 1 })
              .onAction((): void => this.onFullscreenSurfaceTap())))
        Stack({ alignContent: Alignment.TopStart }) {
          this.viewerDanmakuContent()
        }.width('100%').height('100%').padding({ top: this.statusBarHeight + 52 })
          .hitTestBehavior(HitTestMode.None)
        if (this.aiCaptionShown) {
          this.AiCaptionLayer()
        }
        if (this.isWindowLandscape()) {
          this.LandscapeViewerControls()
        } else if (this.controlsVisible) {
          if (this.videoControlStyle === VIDEO_CONTROL_STYLE_ORIGINAL) {
            this.LegacyFullscreenControlPanel()
          } else {
            this.FullscreenControlPanel()
          }
        }
        if (this.fullscreenPinchHint) {
          Text(this.fullscreenFill ? $r('app.string.video_gesture_aspect_fill') :
            $r('app.string.video_gesture_aspect_fit')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('app.color.text_on_brand'))
            .backgroundColor('#99000000')
            .borderRadius(16)
            .padding({ left: 14, right: 14, top: 8, bottom: 8 })
            .margin({ bottom: this.navigationIndicatorHeight + FULLSCREEN_CONTROL_PANEL_HEIGHT })
            .transition(TransitionEffect.OPACITY.animation({ duration: 160, curve: Curve.EaseOut }))
        }
        if (this.fullscreenGestureMode !== FULLSCREEN_GESTURE_NONE && this.fullscreenGestureMode !== FULLSCREEN_GESTURE_FEED) {
          Column({ space: 6 }) {
            if (this.fullscreenGestureMode === FULLSCREEN_GESTURE_SEEK) {
              Text($r('app.string.video_gesture_seek')).fontFamily(this.appFontFamily)
                .fontSize($r('sys.float.Body_M'))
                .fontColor($r('app.color.text_on_brand'))
            } else if (this.fullscreenGestureMode === FULLSCREEN_GESTURE_VOLUME) {
              Text($r('app.string.video_gesture_volume')).fontFamily(this.appFontFamily)
                .fontSize($r('sys.float.Body_M'))
                .fontColor($r('app.color.text_on_brand'))
            } else {
              Text($r('app.string.video_gesture_brightness')).fontFamily(this.appFontFamily)
                .fontSize($r('sys.float.Body_M'))
                .fontColor($r('app.color.text_on_brand'))
            }
            Text(this.fullscreenGestureMode === FULLSCREEN_GESTURE_SEEK ?
              clockLabel(this.positionSec) + ' / ' + clockLabel(this.durationSec) :
              Math.round(this.fullscreenGestureValue * 100).toString() + '%').fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Title_S'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_on_brand'))
          }
          .alignItems(HorizontalAlign.Center)
          .backgroundColor('#99000000')
          .borderRadius(16)
          .padding({ left: 16, right: 16, top: 10, bottom: 10 })
          .margin({ bottom: this.navigationIndicatorHeight + FULLSCREEN_CONTROL_PANEL_HEIGHT })
        }
        if (this.playerControlsLocked && !this.isWindowLandscape()) {
          Button({ type: ButtonType.Circle, stateEffect: true }) {
            SymbolGlyph($r('sys.symbol.lock_fill'))
              .fontSize($r('app.float.landscape_player_icon'))
              .fontColor([$r('app.color.text_on_brand')])
          }
          .width($r('app.float.landscape_player_target')).height($r('app.float.landscape_player_target'))
          .margin({ left: $r('app.float.landscape_player_inset') })
          .backgroundColor(Color.Transparent).align(Alignment.Start).monopolizeEvents(true)
          .accessibilityText($r('app.string.video_player_unlock_controls')).id('landscape-player-unlock')
          .onClick((): void => this.unlockPlayerControls())
        }
        this.HoldSeekHint()
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Black)
      .clip(true)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
    .clip(true)

  }

  build(): void {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
      Stack({ alignContent: this.videoFrameAlignment() }) {
        Stack({ alignContent: Alignment.Center }) {
          if (!this.isAnimatedGif() || !this.failed) {
            XComponent(this.inlineOptions)
            .attributeModifier(new VideoHdrEnhancementModifier(this.videoHdrEnhancement && !this.isAnimatedGif(), this.videoHdrSupported))
            .width(this.mediaViewerLayout ? '100%' : this.displayWidth())
            .height(this.mediaViewerLayout ? '100%' : this.displayHeight())
            .backgroundColor(Color.Black)
            .borderRadius(this.videoRadius())
            .clip(true)
            .focusable(true).focusOnTouch(true)
            .onKeyEvent((event: KeyEvent): boolean => this.playerInputKey(event))
            .onLoad((): void => {
              this.onInlineSurfaceLoaded();
            })
            .onDestroy((): void => {
              this.inlineSurfaceId = '';
            })
          }
          if (this.ready && !this.playing && !this.failed && !this.hideVideoChrome() && !this.hideInlineVideoControls() &&
            !this.mediaViewerLayout) {
            Stack() {
              SymbolGlyph($r('sys.symbol.play_fill'))
                .fontSize(22)
                .fontColor([$r('app.color.text_on_brand')])
            }
            .width(48)
            .height(48)
            .borderRadius(24)
            .backgroundColor('#99000000')
            .monopolizeEvents(true)
            .onClick((): void => {
              this.togglePlay();
            })
          }
          if (this.ready && this.buffering && this.wantsPlay && !this.failed) {
            LoadingProgress()
              .width(26)
              .height(26)
              .color($r('app.color.text_on_brand'))
              .hitTestBehavior(HitTestMode.None)
          }
          if (!this.ready) {
            MediaCover({
              media: this.media,
              imageQuality: this.imageQuality,
              videoQuality: this.videoQuality,
              mediaHeight: this.videoFrameHeight(),
              videoContain: this.mediaViewerLayout ? !this.fillsSmallFeedGap() : this.containVideo,
              cornerRadius: this.videoRadius(),
              minimalVideoControls: this.hideVideoChrome() || this.hideInlineVideoControls(),
              wants: true,
              spinner: this.buffering && this.wantsPlay && !this.failed,
              failed: this.failed,
              onTap: (): void => {
                if (this.linkCardVideo && !this.fullscreen) {
                  this.onLinkCardOpen();
                } else if (this.mediaViewerLayout) {
                  this.onViewerVideoTap();
                  if (this.videoFeedTapPause) { this.togglePlay(); }
                  else { this.toggleControls(); }
                } else {
                  this.onCoverTapped();
                }
              }
            })
          }
        }
        .width(this.videoFrameWidth())
        .height(this.videoFrameHeight())
        .id(this.mediaViewerLayout ? 'video-viewer-frame-' + this.media.id : this.transitionSourceId)
        .align(this.videoFrameAlignment())
        .borderRadius(this.videoRadius())
        .clip(true)
        .scale({ x: this.commentVideoLayout().scale, y: this.commentVideoLayout().scale })
        .translate({ x: this.commentVideoLayout().offsetX, y: this.commentVideoLayout().offsetY })
        .onTouch((event: TouchEvent): void => this.onHoldSpeedTouch(event))
        this.HoldSeekHint()
        if (this.holdSpeedActive && !this.mediaViewerLayout) {
          Stack({ alignContent: Alignment.TopStart }) {
            VideoHoldSpeedCapsule({
              rateLabel: videoHoldSpeedLabel(this.holdSpeedRate),
              hint: this.holdSpeedHint(),
              lightColor: $r('app.color.brand')
            })
          }
          .width('100%')
          .height(this.videoLayerHeight())
          .padding({ left: this.fullscreen ? 20 : 12, top: this.fullscreen ? this.statusBarHeight + 16 : 12 })
          .hitTestBehavior(HitTestMode.None)
          .transition(TransitionEffect.OPACITY.animation({ duration: 140, curve: Curve.EaseOut })
            .combine(TransitionEffect.scale({ x: 0.9, y: 0.9 }))
            .combine(TransitionEffect.translate({ y: -6 })))
        }
        if (this.aiCaptionShown && !this.fullscreen) {
          this.AiCaptionLayer()
        }
        if ((this.linkCardVideo || this.hideInlineVideoControls()) && !this.fullscreen && !this.isAnimatedGif()) {
          Stack({ alignContent: Alignment.BottomEnd }) {
            Button({ type: ButtonType.Circle }) {
              SymbolGlyph(this.inlineAudioMuted() ? $r('sys.symbol.speaker_slash_fill') : $r('sys.symbol.speaker_wave_2_fill'))
                .fontSize($r('app.float.post_card_video_control_icon')).fontColor([$r('app.color.post_card_overlay_text')])
            }.width($r('app.float.post_card_video_control_size')).height($r('app.float.post_card_video_control_size'))
              .backgroundColor(!this.inlineAudioMuted() && this.hideInlineVideoControls() ?
                $r('app.color.brand') : $r('app.color.post_card_title_overlay'))
              .margin($r('app.float.post_card_cover_inset'))
              .id('inline-video-audio-' + this.media.id)
              .accessibilityText(this.inlineAudioMuted() ? $r('app.string.video_unmute') : $r('app.string.video_mute'))
              .monopolizeEvents(true).onClick((): void => {
                if (this.hideInlineVideoControls()) {
                  this.onInlineAudioTap();
                } else {
                  this.toggleMutedFromUser();
                }
              })
          }.width('100%').height(this.videoLayerHeight()).hitTestBehavior(HitTestMode.Transparent)
        }
        if (this.controlsVisible && !this.hideVideoChrome() && !this.hideInlineVideoControls() && !this.controlsAtScreenBottom &&
          !this.hasFeedControlStrip()) {
          Stack({ alignContent: Alignment.Bottom }) {
            if (this.videoControlStyle === VIDEO_CONTROL_STYLE_ORIGINAL) {
              if (this.adaptiveShortVideo) {
                this.LegacyShortVideoControlPanel()
              } else {
                this.LegacyPlayerBar()
              }
            } else if (this.adaptiveShortVideo) {
              this.PlayerBar()
            }
          }
          .width('100%')
          .height(this.displayHeight())
          .hitTestBehavior(HitTestMode.Transparent)
        }
      }
      .width('100%')
      .height(this.videoLayerHeight())
      .id(this.mediaViewerLayout ? 'video-viewer-layer' : '')
      .gesture(GestureGroup(GestureMode.Exclusive,
        LongPressGesture({ fingers: 1, repeat: this.mediaViewerLayout || this.fullscreen, duration: HOLD_SEEK_DURATION_MS })
          .onAction((event: GestureEvent): void => this.onVideoLongPress(event))
          .onActionEnd((): void => this.finishHoldGesture())
          .onActionCancel((): void => this.finishHoldGesture()),
        TapGesture({ count: this.doubleTapSeekEnabled ? 2 : 1, fingers: 1 })
          .onAction((event: GestureEvent): void => this.onVideoDoubleTap(event)),
        TapGesture({ count: 1, fingers: 1 })
          .onAction((): void => this.onVideoSurfaceTap())))
      if (this.hasFeedControlStrip() && !this.compactFeedLayout) {
        Column() {
          Column() {
            // Keep the strip geometry, but remove hidden buttons and sliders
            // from the hit-test tree until a video tap restores the controls.
            if (this.controlsVisible) {
              this.FeedPlayerBar()
            }
          }
          .opacity(this.controlsVisible ? 1 - this.viewerCommentProgress : 0)
          .width('100%')
          .height(this.videoFrameControlsInset())
          .hitTestBehavior(this.controlsVisible && !this.retainViewerPlayback ? HitTestMode.Default : HitTestMode.None)
        }
        .width('100%')
        .height(this.videoFrameControlsInset())
        .backgroundColor(this.mediaViewerLayout ? Color.Transparent : $r('app.color.video_feed_player_surface'))
        .onClick((): void => {
          if (!this.controlsVisible) {
            this.holdControls();
          }
        })
      } else if (this.showsProgressBelowVideo()) {
        if (this.videoControlStyle === VIDEO_CONTROL_STYLE_ORIGINAL) {
          this.LegacyProgressLine()
        } else {
          this.InlinePlayerBar()
        }
      }
      }
      .width('100%')
      .height(this.playerContainerHeight())
      .justifyContent(this.controlsAtScreenBottom ? FlexAlign.Center : FlexAlign.Start)
      if (this.hasFeedControlStrip() && this.compactFeedLayout) {
        Stack({ alignContent: Alignment.Bottom }) {
          Column() {
            if (this.controlsVisible) {
              this.FeedPlayerBar()
            }
          }
            .width('100%')
            .height(this.feedPlayerBarHeight())
            .linearGradient({ angle: 180, colors: [
              [Color.Transparent, 0], [$r('app.color.video_feed_post_scrim'), 1]
            ] })
            .opacity(this.controlsVisible ? 1 - this.viewerCommentProgress : 0)
            .hitTestBehavior(this.controlsVisible && !this.retainViewerPlayback ? HitTestMode.Default : HitTestMode.None)
        }
        .width('100%')
        .height(this.displayHeight())
        .hitTestBehavior(HitTestMode.Transparent)
      }
      if (this.controlsAtScreenBottom && (this.controlsVisible || this.mediaViewerLayout && this.isWindowLandscape()) &&
        !this.hideVideoChrome() && !this.hideInlineVideoControls()) {
        Stack({ alignContent: Alignment.Bottom }) {
          if (this.mediaViewerLayout && this.isWindowLandscape()) {
            this.LandscapeViewerControls()
          } else if (this.videoControlStyle === VIDEO_CONTROL_STYLE_ORIGINAL) {
            this.LegacyPlayerBar()
          } else {
            this.PlayerBar()
          }
        }
        .width('100%')
        .height(this.windowHeight > 0 ? this.windowHeight : this.displayHeight())
        .opacity(1 - this.viewerCommentProgress)
        .hitTestBehavior(this.retainViewerPlayback ? HitTestMode.None : HitTestMode.Transparent)
      }
      if (this.mediaViewerLayout) {
        this.CommentPreviewControls()
      }
    }
    .width('100%')
    .height(this.playerContainerHeight())
    .onAreaChange((oldValue: Area, newValue: Area): void => {
      const width: number = Number(newValue.width);
      if (width > 0 && Math.abs(width - this.measuredWidth) > 0.5) {
        this.measuredWidth = width;
        this.applyVideoScaleType();
      }
    })
    .onVisibleAreaApproximateChange({ ratios: [PLAYER_HIDE_RATIO, PLAYER_PLAY_RATIO],
      expectedUpdateInterval: 300 }, (isExpanding: boolean, currentRatio: number): void => {
      this.onVisibleChange(isExpanding, currentRatio);
    })
    .bindContentCover(this.fullscreen && this.fullscreenOwnerId === this.fullscreenInstanceKey,
      this.FullscreenLayer(), {
      modalTransition: ModalTransition.NONE,
      backgroundColor: Color.Black,
      onWillDismiss: (action: DismissContentCoverAction): void => {
        // Restore the inline surface before a system back gesture destroys
        // the fullscreen XComponent. The cover uses a derived show condition,
        // so its dismissal cannot update fullscreen through two-way binding.
        this.exitFullscreen();
        action.dismiss();
      },
      onDisappear: (): void => {
        this.exitFullscreen();
      }
    })
  }
}

@Component
export struct PostMedia {
  @StorageProp(STORAGE_KEY_VIDEO_DOWNLOAD_BUTTON) private videoDownloadButton: boolean = true;
  private inputModalScope: InputModalScope = new InputModalScope();
  @Prop controlsUsePageBackground: boolean = true;
  @Prop controlSurface: ResourceColor = Color.Transparent;
  private mediaSourcePrefix: string = createMediaSourcePrefix();
  onViewerSurfaceReady: () => void = (): void => {};
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Prop castRequestSerial: number = 0;
  @Prop viewerFullscreenRequest: number = 0;
  onViewerCastPickerChanged: (visible: boolean) => void = (visible: boolean): void => {};
  onViewerCastingChanged: (casting: boolean) => void = (casting: boolean): void => {};
  @Prop sourceTweet: Tweet | null = null;
  @Prop viewerDanmakuEnabled: boolean = false;
  @Prop viewerAuthorFollowing: boolean = false;
  @Prop viewerDownloading: boolean = false;
  onViewerDownload: () => void = (): void => {};
  onViewerFollow: () => void = (): void => {};
  onViewerComment: () => void = (): void => {};
  onViewerDanmakuToggle: () => void = (): void => {};
  onViewerDanmakuSend: () => void = (): void => {};
  onViewerAdvance: () => void = (): void => {};
  // Reported by the player that is being held, so the short-video viewer can
  // draw the rate capsule directly under its back/more row.
  onHoldSpeedChanged: (active: boolean, rate: number) => void = (active: boolean, rate: number): void => {};
  @Prop attachments: MediaAttachment[] = [];
  @Prop photoStartOffset: number = 0;
  @Prop photoEndOffset: number = 0;
  @Prop photoViewportHeight: number = 0;
  @Prop photoViewerAttachments: MediaAttachment[] = [];
  onPhotoViewerReturn: (sourceIndex: number) => void = (sourceIndex: number): void => {};
  onPhotoPageChanged: (index: number) => void = (): void => {};
  onMediaPanProgress: (progress: number) => void = (): void => {};
  private mediaStripScroller: ListScroller = new ListScroller();
  @Prop videoFeedEnabled: boolean = false;
  @Prop captionEnabled: boolean = false;
  // Set by the post detail page: its video plays through the picture-in-picture
  // capable player instead of the gated Video component, and the player itself
  // watches the viewport so it can hand itself to the floating window.
  @Prop pipEnabled: boolean = false;
  @Prop pipNavigationHandleId: number = -1;
  @Prop @Watch('onPlaybackEnabledChanged') playbackEnabled: boolean = true;
  @Prop preloadMediaId: string = '';
  // Retire distant viewer players even before LazyForEach's idle cleanup.
  @Prop viewerPlayerRetained: boolean = true;
  @Prop initialPositionMediaId: string = '';
  @Prop initialPositionSeconds: number = 0;
  @Prop showDownloadButton: boolean = true;
  @Prop naturalVideoSize: boolean = false;
  @Prop limitNaturalHeight: boolean = false;
  @Prop adaptiveShortVideo: boolean = false;
  @Prop manualStartMediaId: string = '';
  @Prop immersiveVideo: boolean = false;
  @Prop fillVideoViewport: boolean = false;
  @Prop videoViewportHeight: number = 0;
  @Prop controlsAtScreenBottom: boolean = false;
  @Prop hideInlineControls: boolean = false;
  @Prop compactFeedLayout: boolean = false;
  @Prop compactBottomActions: boolean = false;
  @Prop mediaViewerLayout: boolean = false;
  @Prop viewerUsesSideComments: boolean = false;
  @Prop viewerPhoneFeedLayout: boolean = false;
  @Prop viewerCommentProgress: number = 0;
  @Prop viewerCommentTop: number = 0;
  @Prop viewerCommentHeight: number = 0;
  @Prop retainViewerPlayback: boolean = false;
  @Builder
  private EmptyLandscapePost(): void {
    Row() {}
  }

  // Keep this bound to PostMedia when SurfaceVideoPlayer invokes the forwarded builder.
  @LocalBuilder
  private ForwardLandscapePost(): void {
    this.landscapePostContent()
  }

  @LocalBuilder
  private ForwardDanmaku(): void {
    this.viewerDanmakuContent()
  }

  @LocalBuilder
  private ForwardCompactFeedActions(): void {
    this.compactFeedActions()
  }

  @BuilderParam landscapePostContent: () => void = this.EmptyLandscapePost;
  @BuilderParam viewerDanmakuContent: () => void = this.EmptyLandscapePost;
  @BuilderParam compactFeedActions: () => void = this.EmptyLandscapePost;
  onViewerBack: () => void = (): void => {};
  onViewerMore: () => void = (): void => {};
  onViewerCommentDismiss: () => void = (): void => {};
  onViewerControlsChanged: (visible: boolean) => void = (visible: boolean): void => {};
  onViewerVideoTap: () => void = (): void => {};
  @Prop forceUnmuted: boolean = false;
  @Prop homeTimelineVideo: boolean = false;
  @Prop linkCardVideo: boolean = false;
  @Prop exploreHeroVideo: boolean = false;
  @Prop exploreHeroMuted: boolean = true;
  @Prop playerBarBottomOffset: number = 12;
  onVideoOpen: (media: MediaAttachment) => void = (): void => {
  };
  onCaptionChanged: (shown: boolean) => void = (): void => {
  };
  onPlaybackCompleted: () => void = (): void => {
  };
  onPlaybackStateChanged: (playing: boolean) => void = (playing: boolean): void => {
  };
  onInitialPositionApplied: () => void = (): void => {
  };
  @StorageLink('harmonyx.video_autoplay') @Watch('onVideoAutoplayChanged')
  videoAutoplay: boolean = true;
  @StorageLink(STORAGE_KEY_SHOW_SENSITIVE_MEDIA) @Watch('onShowSensitiveMediaChanged')
  showSensitiveMedia: boolean = false;
  @StorageLink('harmonyx.image_quality') imageQuality: number = IMAGE_QUALITY_ORIGINAL;
  @StorageLink('harmonyx.video_quality') videoQuality: number = VIDEO_QUALITY_DATA_SAVER;
  @StorageLink(STORAGE_KEY_VIDEO_CONTROL_STYLE) private videoControlStyle: number = VIDEO_CONTROL_STYLE_SPACED;
  @StorageLink(STORAGE_KEY_VIDEO_AUTO_BITRATE_CAP) autoBitrateCap: number = DEFAULT_VIDEO_AUTO_BITRATE_CAP;
  @StorageProp(STORAGE_KEY_VIDEO_FEED_ACTIVE) videoFeedActive: boolean = false;
  @StorageProp('harmonyx.display_mode') private themeDisplayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private themeDarkSurface: string = '';
  @StorageProp('harmonyx.window_width') private windowWidth: number =
    AppStorage.get<number>('harmonyx.window_width') ?? 360;
  @StorageProp('harmonyx.window_height') private windowHeight: number =
    AppStorage.get<number>('harmonyx.window_height') ?? 0;
  // Attachments of this post that are streaming right now. A page can hold
  // several videos, so this is a list and not a single winner: every cell that
  // is far enough into the viewport opens its own stream and holds it.
  @State private activeIds: string[] = [];
  // Keep one recently used home inline player mounted per post while the List
  // retains that row, so returning from a nearby swipe can reuse its AVPlayer.
  @State private retainedPlayerIds: string[] = [];
  @State private uncoveredInlineIds: string[] = [];
  @State private manualIds: string[] = [];
  @State private gifActionMenuMediaId: string = '';
  @State private videoContainerWidth: number = 0;
  // Media ids whose cover is worth decoding, oldest first.
  @State private coverIds: string[] = [];
  // A reader may reveal a guarded attachment for the current card without
  // weakening the global preference for the rest of the timeline.
  @State private revealedMediaIds: string[] = [];
  @State private photoTransitionPrefix: string = '';
  @State private photoContainerWidth: number = 320;
  @StorageLink('harmonyx.photo_return') @Watch('onPhotoReturn') photoReturn: string = '';
  private photoScrollers: Map<number, ListScroller> = new Map<number, ListScroller>();
  private photoListVisible: Map<number, boolean> = new Map<number, boolean>();
  private alive: boolean = true;
  private gifActionBusy: boolean = false;

  aboutToDisappear(): void {
    this.inputModalScope.setActive(false);
    this.alive = false;
    this.gifActionMenuMediaId = '';
    for (let i: number = 0; i < this.activeIds.length; i++) {
      inlineVideoGate.release(this.activeIds[i]);
    }
  }

  private text(resource: Resource): string {
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    return context.resourceManager.getStringSync(resource);
  }

  private gifMenuMaterial(): uiMaterial.Material | undefined {
    return SystemMaterialUtil.immersiveMaterial(1, true, false, true, undefined);
  }

  private gifContextMenuOptions(media: MediaAttachment): ContextMenuOptions {
    const options: ContextMenuOptions = {
      preview: MenuPreviewMode.IMAGE,
      borderRadius: 16,
      backgroundColor: Color.Transparent,
      backgroundBlurStyle: BlurStyle.BACKGROUND_THIN,
      mask: { color: '#52000000', backgroundBlurStyle: BlurStyle.BACKGROUND_THIN },
      modalMode: ModalMode.TARGET_WINDOW,
      hapticFeedbackMode: HapticFeedbackMode.AUTO,
      onAppear: (): void => { this.inputModalScope.setActive(true); },
      onDisappear: (): void => {
        this.inputModalScope.setActive(false);
        if (this.gifActionMenuMediaId === media.id) { this.gifActionMenuMediaId = ''; }
      }
    };
    if (deviceInfo.apiAvailable('26.0.0')) {
      options.systemMaterial = this.gifMenuMaterial();
    }
    return options;
  }

  private isGifFileUrl(url: string): boolean {
    const lower: string = url.toLowerCase();
    const queryStart: number = lower.indexOf('?');
    const path: string = queryStart >= 0 ? lower.substring(0, queryStart) : lower;
    return path.endsWith('.gif') || lower.indexOf('format=gif') >= 0;
  }

  private isHlsUrl(url: string): boolean {
    const lower: string = url.toLowerCase();
    return lower.indexOf('.m3u8') >= 0 || lower.indexOf('mpegurl') >= 0;
  }

  private gifActionUrl(media: MediaAttachment): string {
    if (media.mediaUrl.length > 0 && !this.isHlsUrl(media.mediaUrl)) {
      return media.mediaUrl;
    }
    const renditions: VideoRendition[] = media.videoVariants ?? [];
    for (let index: number = renditions.length - 1; index >= 0; index--) {
      if (renditions[index].url.length > 0 && !this.isHlsUrl(renditions[index].url)) {
        return renditions[index].url;
      }
    }
    const variantUrls: string[] = media.videoVariantUrls ?? [];
    for (let index: number = variantUrls.length - 1; index >= 0; index--) {
      if (variantUrls[index].length > 0 && !this.isHlsUrl(variantUrls[index])) {
        return variantUrls[index];
      }
    }
    if (media.feedUrl.length > 0 && !this.isHlsUrl(media.feedUrl)) {
      return media.feedUrl;
    }
    return '';
  }

  private showGifActionMenu(media: MediaAttachment): void {
    if (isAnimatedGif(media)) {
      this.gifActionMenuMediaId = media.id;
    }
  }

  private saveGifAsVideo(media: MediaAttachment): void {
    if (this.gifActionBusy) { return; }
    const url: string = gifVideoDownloadUrl(media);
    if (url.length === 0) { return; }
    this.gifActionBusy = true;
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    mediaDownloadService.download(context, url, media.id, true, (result: number): void => {
      this.gifActionBusy = false;
      if (result === MEDIA_DOWNLOAD_SUCCESS) { return; }
      const message: Resource = result === MEDIA_DOWNLOAD_SUCCESS ? $r('app.string.media_video_saved') :
        result === MEDIA_DOWNLOAD_CANCELED ? $r('app.string.media_download_canceled') : $r('app.string.media_download_failed');
      promptAction.showToast({ message: this.text(message), duration: 2200 });
    });
  }

  private saveGifToGallery(media: MediaAttachment): void {
    if (this.gifActionBusy) {
      return;
    }
    const url: string = this.gifActionUrl(media);
    if (url.length === 0) {
      promptAction.showToast({ message: this.text($r('app.string.media_download_failed')), duration: 2200 });
      return;
    }
    this.gifActionBusy = true;
    promptAction.showToast({ message: this.text($r('app.string.gif_save_started')), duration: 1800 });
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    // The post's animation is an MP4 rendition, so saving it as a GIF means
    // re-encoding the frames instead of copying the video file.
    const onResult: (result: number) => void = (result: number): void => {
      this.gifActionBusy = false;
      if (result === MEDIA_DOWNLOAD_SUCCESS) {
        promptAction.showToast({ message: this.text($r('app.string.gif_saved')), duration: 2200 });
      } else if (result === MEDIA_DOWNLOAD_CANCELED) {
        promptAction.showToast({ message: this.text($r('app.string.media_download_canceled')), duration: 1800 });
      } else if (result === MEDIA_DOWNLOAD_SAVED_AS_VIDEO) {
        promptAction.showToast({ message: this.text($r('app.string.gif_save_video_fallback')), duration: 2600 });
      } else if (result === MEDIA_DOWNLOAD_FAILED) {
        promptAction.showToast({ message: this.text($r('app.string.media_download_failed')), duration: 2400 });
      }
    };
    if (this.isGifFileUrl(url)) {
      mediaDownloadService.download(context, url, media.id, false, onResult);
      return;
    }
    mediaDownloadService.downloadAnimatedGif(context, url, media.id, media.durationMs ?? 0,
      media.width, media.height, onResult);
  }

  private async shareGif(media: MediaAttachment): Promise<void> {
    if (this.gifActionBusy) {
      return;
    }
    const url: string = this.gifActionUrl(media);
    if (url.length === 0) {
      promptAction.showToast({ message: this.text($r('app.string.gif_share_failed')), duration: 2200 });
      return;
    }
    this.gifActionBusy = true;
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const extension: string = this.isGifFileUrl(url) ? 'gif' : 'mp4';
    const filePath: string = context.cacheDir + '/harmonyx-gif-share-' + Date.now().toString() + '.' + extension;
    const downloaded: boolean = await proxyDownloadService.downloadWithRetry(url, filePath, 2);
    if (!downloaded) {
      this.gifActionBusy = false;
      promptAction.showToast({ message: this.text($r('app.string.gif_share_failed')), duration: 2200 });
      return;
    }
    const sharedData: systemShare.SharedData = new systemShare.SharedData({
      utd: extension === 'gif' ? utd.UniformDataType.GIF : utd.UniformDataType.VIDEO,
      uri: fileUri.getUriFromPath(filePath),
      title: this.text($r('app.string.gif_share_title'))
    });
    const controller: systemShare.ShareController = new systemShare.ShareController(sharedData);
    try {
      await controller.show(context, {
        selectionMode: systemShare.SelectionMode.SINGLE,
        previewMode: systemShare.SharePreviewMode.DEFAULT
      });
    } catch (error) {
      promptAction.showToast({ message: this.text($r('app.string.gif_share_failed')), duration: 2200 });
      hilog.warn(DOMAIN, TAG, 'gif share failed: %{public}s', JSON.stringify(error));
    }
    this.gifActionBusy = false;
  }

  @Builder
  private GifActionMenu(media: MediaAttachment): void {
    Menu() {
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.download')),
        content: $r('app.string.gif_action_save')
      }).onClick((): void => {
        this.saveGifToGallery(media);
      });
      if (gifVideoDownloadUrl(media).length > 0) {
        MenuItem({
          symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.video')),
          content: $r('app.string.gif_action_save_video')
        }).onClick((): void => { this.saveGifAsVideo(media); });
      }
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.share')),
        content: $r('app.string.gif_action_share')
      }).onClick((): void => {
        void this.shareGif(media);
      });
    }
  }

  private canStream(media: MediaAttachment): boolean {
    return isVideoLike(media) && media.mediaUrl.length > 0;
  }

  private isRevealed(id: string): boolean {
    for (let i: number = 0; i < this.revealedMediaIds.length; i++) {
      if (this.revealedMediaIds[i] === id) {
        return true;
      }
    }
    return false;
  }

  private isMediaHidden(media: MediaAttachment): boolean {
    const explicitlyOpened: boolean = this.mediaViewerLayout && this.manualStartMediaId === media.id;
    return media.sensitive === true && !this.showSensitiveMedia && !this.isRevealed(media.id) && !explicitlyOpened;
  }

  private revealMedia(media: MediaAttachment): void {
    let startIndex: number = -1;
    for (let i: number = 0; i < this.attachments.length; i++) {
      if (this.attachments[i].id === media.id) {
        startIndex = i;
        break;
      }
    }
    if (startIndex < 0) {
      return;
    }
    if (!isVideoLike(media)) {
      while (startIndex > 0 && this.isUsablePhoto(this.attachments[startIndex - 1])) {
        startIndex -= 1;
      }
    }
    const mediaToReveal: MediaAttachment[] = isVideoLike(media) ? [media] : this.photoRun(startIndex);
    const next: string[] = [];
    for (let i: number = 0; i < this.revealedMediaIds.length; i++) {
      next.push(this.revealedMediaIds[i]);
    }
    for (let i: number = 0; i < mediaToReveal.length; i++) {
      if (!this.isRevealed(mediaToReveal[i].id)) {
        next.push(mediaToReveal[i].id);
      }
    }
    this.revealedMediaIds = next;
  }

  private photoRunHasHiddenSensitive(startIndex: number): boolean {
    const photos: MediaAttachment[] = this.photoRun(startIndex);
    for (let i: number = 0; i < photos.length; i++) {
      if (this.isMediaHidden(photos[i])) {
        return true;
      }
    }
    return false;
  }

  private onShowSensitiveMediaChanged(): void {
    if (this.showSensitiveMedia) {
      return;
    }
    this.revealedMediaIds = [];
    const retained: string[] = [];
    for (let i: number = 0; i < this.activeIds.length; i++) {
      let sensitive: boolean = false;
      for (let j: number = 0; j < this.attachments.length; j++) {
        if (this.attachments[j].id === this.activeIds[i] && this.attachments[j].sensitive === true) {
          sensitive = true;
          break;
        }
      }
      if (sensitive) {
        inlineVideoGate.release(this.activeIds[i]);
      } else {
        retained.push(this.activeIds[i]);
      }
    }
    this.activeIds = retained;
    const retainedPlayers: string[] = [];
    for (let i: number = 0; i < this.retainedPlayerIds.length; i++) {
      let sensitive: boolean = false;
      for (let j: number = 0; j < this.attachments.length; j++) {
        if (this.attachments[j].id === this.retainedPlayerIds[i] && this.attachments[j].sensitive === true) {
          sensitive = true;
          break;
        }
      }
      if (!sensitive) {
        retainedPlayers.push(this.retainedPlayerIds[i]);
      }
    }
    this.retainedPlayerIds = retainedPlayers;
  }

  // The detail page keeps its focal player mounted for the whole visit, and
  // the home feed keeps its most recent inline player while the row is cached.
  // Other pages mount a player only while its cell is streaming.
  private showsPlayer(media: MediaAttachment): boolean {
    if (!this.canStream(media)) {
      return false;
    }
    if (this.mediaViewerLayout && !this.viewerPlayerRetained && !this.playbackEnabled &&
      this.preloadMediaId !== media.id && !this.retainViewerPlayback) {
      return false;
    }
    return this.exploreHeroVideo || (this.pipEnabled && !isAnimatedGif(media)) || this.isActive(media.id) ||
      this.isRetainedPlayer(media.id) || this.manualStartMediaId === media.id || this.preloadMediaId === media.id;
  }

  private onPlaybackEnabledChanged(): void {
    if (this.playbackEnabled) {
      return;
    }
    for (let i: number = 0; i < this.activeIds.length; i++) {
      inlineVideoGate.release(this.activeIds[i]);
    }
    this.activeIds = [];
    this.retainedPlayerIds = [];
    this.uncoveredInlineIds = [];
  }

  private isRetainedPlayer(id: string): boolean {
    for (let i: number = 0; i < this.retainedPlayerIds.length; i++) {
      if (this.retainedPlayerIds[i] === id) {
        return true;
      }
    }
    return false;
  }

  private retainInlinePlayer(id: string): string {
    const next: string[] = [];
    for (let i: number = 0; i < this.retainedPlayerIds.length; i++) {
      if (this.retainedPlayerIds[i] !== id) {
        next.push(this.retainedPlayerIds[i]);
      }
    }
    let evictedId: string = '';
    while (next.length >= MAX_RETAINED_INLINE_PLAYERS_PER_POST) {
      evictedId = next.shift() ?? '';
    }
    next.push(id);
    this.retainedPlayerIds = next;
    return evictedId;
  }

  private isManualStart(id: string): boolean {
    if (this.manualStartMediaId === id) {
      return true;
    }
    for (let i: number = 0; i < this.manualIds.length; i++) {
      if (this.manualIds[i] === id) {
        return true;
      }
    }
    return false;
  }

  private videoDisplayHeight(media: MediaAttachment): number {
    if (this.isHorizontalMediaStrip()) { return this.horizontalMediaLayout().height; }
    if (isAnimatedGif(media)) {
      return postGifHeight(media.width, media.height, this.videoContainerWidth, this.windowHeight);
    }
    if (this.fillVideoViewport) {
      return this.videoViewportHeight > 0 ? this.videoViewportHeight : MEDIA_HEIGHT;
    }
    if (!this.naturalVideoSize || media.width <= 0 || media.height <= 0) {
      return MEDIA_HEIGHT;
    }
    const windowWidth: number = this.windowWidth;
    const inset: number = this.forceUnmuted ? 24 : 80;
    const width: number = this.videoContainerWidth > 0 ? this.videoContainerWidth :
      (windowWidth > inset ? windowWidth - inset : 280);
    const naturalHeight: number = Math.max(1, width * media.height / media.width);
    if (!this.limitNaturalHeight) {
      return naturalHeight;
    }
    const maxHeight: number = maxNaturalVideoDisplayHeight(this.windowWidth, this.windowHeight);
    return Math.max(MEDIA_HEIGHT, Math.min(naturalHeight, maxHeight));
  }

  private usesStableInlineLayout(): boolean {
    return !this.mediaViewerLayout && !this.immersiveVideo && !this.adaptiveShortVideo &&
      !this.controlsAtScreenBottom && !this.exploreHeroVideo && !this.linkCardVideo &&
      !this.fillVideoViewport && !this.isHorizontalMediaStrip();
  }

  private inlineControlsHeight(media: MediaAttachment): number {
    if (!this.usesStableInlineLayout() || this.hideInlineControls ||
      (!this.videoAutoplay && !this.isManualStart(media.id))) { return 0; }
    return this.videoControlStyle === VIDEO_CONTROL_STYLE_ORIGINAL ?
      INLINE_PROGRESS_LINE_HEIGHT : INLINE_VIDEO_CONTROLS_HEIGHT;
  }

  private inlinePreviewHidden(id: string): boolean {
    return this.uncoveredInlineIds.indexOf(id) >= 0;
  }

  private setInlinePreviewHidden(id: string, hidden: boolean): void {
    if (!this.alive || this.inlinePreviewHidden(id) === hidden) { return; }
    const next: string[] = this.uncoveredInlineIds.filter((value: string): boolean => value !== id);
    if (hidden) { next.push(id); }
    this.uncoveredInlineIds = next;
  }

  // Media payloads carry the source pixels' dimensions. Use their aspect ratio
  // for the sensitive cover rather than inventing a generic rectangle, while
  // still constraining unusually tall media to the visible window.
  private sensitiveMediaHeight(media: MediaAttachment): number {
    if (this.photoViewportHeight > 0 && !isVideoLike(media)) { return this.photoViewportHeight; }
    if (media.width <= 0 || media.height <= 0) {
      return isVideoLike(media) ? this.videoDisplayHeight(media) : MEDIA_HEIGHT;
    }
    const windowWidth: number = this.windowWidth;
    const inset: number = this.forceUnmuted ? 24 : 48;
    const fallbackWidth: number = windowWidth > inset ? windowWidth - inset : 280;
    const containerWidth: number = isVideoLike(media) ? this.videoContainerWidth : this.photoContainerWidth;
    const width: number = containerWidth > 0 ? (isVideoLike(media) ? containerWidth :
      Math.max(1, containerWidth - this.photoStartOffset - this.photoEndOffset)) : fallbackWidth;
    const naturalHeight: number = Math.max(1, width * media.height / media.width);
    const windowHeight: number = this.windowHeight;
    const maxHeight: number = windowHeight > 0 ? Math.max(MEDIA_HEIGHT, windowHeight * 0.65) : 480;
    return Math.min(naturalHeight, maxHeight);
  }

  private onVideoAutoplayChanged(): void {
    if (this.videoAutoplay || this.exploreHeroVideo) {
      return;
    }
    const retained: string[] = [];
    for (let i: number = 0; i < this.activeIds.length; i++) {
      if (this.isManualStart(this.activeIds[i])) {
        retained.push(this.activeIds[i]);
      } else {
        inlineVideoGate.release(this.activeIds[i]);
      }
    }
    this.activeIds = retained;
  }

  // Photos and animations in payload order, which is the order the full-screen
  // viewer swipes through.
  private viewerPhotoMedia(): MediaAttachment[] {
    return this.photoViewerAttachments.length > 0 ? this.photoViewerAttachments : this.attachments;
  }

  private photoItems(): PhotoViewerPhoto[] {
    const items: PhotoViewerPhoto[] = [];
    const attachments: MediaAttachment[] = this.viewerPhotoMedia();
    for (let i: number = 0; i < attachments.length; i++) {
      const media: MediaAttachment = attachments[i];
      if (isVideoLike(media) && !isAnimatedGif(media) || this.isMediaHidden(media)) {
        continue;
      }
      const previewSource: string = media.previewUrl.length > 0 ? media.previewUrl : media.mediaUrl;
      const animation: boolean = isAnimatedGif(media) || this.isGifFileUrl(media.mediaUrl);
      const animationUrl: string = animation ? this.gifActionUrl(media) : '';
      const originalSource: string = animation ? animationUrl :
        media.mediaUrl.length > 0 ? media.mediaUrl : previewSource;
      if (previewSource.length > 0 || originalSource.length > 0) {
        const previewUrl: string = imageUrlForQuality(previewSource.length > 0 ? previewSource : originalSource,
          this.imageQuality);
        const originalUrl: string = animation ? originalSource :
          imageUrlForQuality(originalSource, IMAGE_QUALITY_ORIGINAL);
        const animatedMedia: MediaAttachment | null = animation ? {
          id: media.id, type: 'animated_gif', mediaUrl: animationUrl, feedUrl: media.feedUrl,
          previewUrl: media.previewUrl, width: media.width, height: media.height, altText: media.altText,
          durationMs: media.durationMs, videoVariants: media.videoVariants, videoVariantUrls: media.videoVariantUrls
        } : null;
        const node = mediaPhotoNodeFor(this.mediaSourceId(media));
        items.push(new PhotoViewerPhoto(previewUrl, originalUrl, media.width > 0 ? media.width : node?.width ?? 0,
          media.height > 0 ? media.height : node?.height ?? 0,
          i, media.altText, this.mediaSourceId(media), animatedMedia));
      }
    }
    return items;
  }

  private isHorizontalMediaStrip(): boolean {
    return postUsesHorizontalMediaStrip(this.attachments, this.mediaViewerLayout);
  }

  private horizontalMediaLayout(): PhotoStripLayout {
    const width: number = this.photoContainerWidth > 0 ? this.photoContainerWidth : Math.max(1, this.windowWidth - 72);
    return photoStripLayout(this.attachments, Math.max(1, width - this.photoStartOffset - this.photoEndOffset), this.windowHeight, true);
  }

  private updateMediaPan(scroller: Scroller): void {
    const offset: number = scroller.currentOffset().xOffset;
    this.onMediaPanProgress(mediaAvatarPanProgress(offset, this.photoStartOffset));
  }

  private isUsablePhoto(media: MediaAttachment): boolean {
    return !isVideoLike(media) && (media.mediaUrl.length > 0 || media.previewUrl.length > 0);
  }

  private photoRun(startIndex: number): MediaAttachment[] {
    const photos: MediaAttachment[] = [];
    for (let i: number = startIndex; i < this.attachments.length; i++) {
      const media: MediaAttachment = this.attachments[i];
      if (!this.isUsablePhoto(media)) {
        break;
      }
      photos.push(media);
    }
    return photos;
  }

  private photoRunHeight(startIndex: number): number {
    if (this.isHorizontalMediaStrip()) { return this.horizontalMediaLayout().height; }
    const photos: MediaAttachment[] = this.photoRun(startIndex);
    if (photos.length === 0) {
      return MEDIA_HEIGHT;
    }
    return photos.length === 1 ? this.sensitiveMediaHeight(photos[0]) :
      this.photoLayout(startIndex).height;
  }

  private sensitivePhotoForRun(startIndex: number): MediaAttachment {
    const photos: MediaAttachment[] = this.photoRun(startIndex);
    for (let i: number = 0; i < photos.length; i++) {
      if (this.isMediaHidden(photos[i])) {
        return photos[i];
      }
    }
    return this.attachments[startIndex];
  }

  private isPhotoRunStart(index: number): boolean {
    if (!this.isUsablePhoto(this.attachments[index])) {
      return false;
    }
    return index === 0 || !this.isUsablePhoto(this.attachments[index - 1]);
  }

  private photoScrollerFor(startIndex: number): ListScroller {
    let scroller: ListScroller | undefined = this.photoScrollers.get(startIndex);
    if (scroller === undefined) {
      scroller = new ListScroller();
      this.photoScrollers.set(startIndex, scroller);
    }
    return scroller;
  }

  private photoLayout(startIndex: number): PhotoStripLayout {
    const bodyWidth: number = Math.max(1, this.photoContainerWidth - this.photoStartOffset - this.photoEndOffset);
    return photoStripLayout(this.photoRun(startIndex), bodyWidth, this.windowHeight);
  }

  private photoCellWidth(startIndex: number, media: MediaAttachment): number {
    if (this.isHorizontalMediaStrip()) {
      const index: number = this.attachments.findIndex((item: MediaAttachment): boolean => item.id === media.id);
      return this.horizontalMediaLayout().widths[index] ?? this.photoContainerWidth;
    }
    const photos: MediaAttachment[] = this.photoRun(startIndex);
    if (photos.length <= 1) {
      return Math.max(1, this.photoContainerWidth - this.photoStartOffset - this.photoEndOffset);
    }
    const layout: PhotoStripLayout = this.photoLayout(startIndex);
    for (let i: number = 0; i < photos.length; i++) {
      if (photos[i].id === media.id) {
        return layout.widths[i];
      }
    }
    return this.photoContainerWidth;
  }

  private onPhotoReturn(): void {
    if (this.photoTransitionPrefix.length === 0 || this.photoReturn.length === 0) {
      return;
    }
    const separator: number = this.photoReturn.indexOf('|');
    if (separator < 0 || this.photoReturn.substring(0, separator) !== this.photoTransitionPrefix) {
      return;
    }
    const suffix: string = this.photoReturn.substring(separator + 1);
    const nextSeparator: number = suffix.indexOf('|');
    if (nextSeparator < 0) {
      return;
    }
    const index: number = Number(suffix.substring(0, nextSeparator));
    const items: PhotoViewerPhoto[] = this.photoItems();
    if (!Number.isInteger(index) || index < 0 || index >= items.length) {
      return;
    }
    const sourceIndex: number = items[index].sourceIndex;
    if (this.photoViewerAttachments.length > 0) {
      this.onPhotoViewerReturn(sourceIndex);
      return;
    }
    if (this.isHorizontalMediaStrip()) {
      if (!this.photoReturnVisible(this.attachments[sourceIndex], sourceIndex)) {
        this.mediaStripScroller.scrollToIndex(sourceIndex + (this.photoStartOffset > 0 ? 1 : 0), false, ScrollAlign.AUTO);
      }
      return;
    }
    // In photo-only runs, GIFs retain their independent viewer entry.
    if (!this.isUsablePhoto(this.attachments[sourceIndex])) { return; }
    let runStart: number = sourceIndex;
    while (runStart > 0 && this.isUsablePhoto(this.attachments[runStart - 1])) {
      runStart -= 1;
    }
    if (this.photoReturnVisible(this.attachments[sourceIndex], runStart)) { return; }
    // Keep even a partially visible thumbnail at the reader's exact offset.
    // An offscreen photo needs only the shortest scroll, without recentering.
    const leadingItem: number = this.photoStartOffset > 0 ? 1 : 0;
    this.photoScrollerFor(runStart).scrollToIndex(sourceIndex - runStart + leadingItem, false, ScrollAlign.AUTO);
  }

  private photoListId(startIndex: number): string {
    return this.isHorizontalMediaStrip() ? this.mediaSourcePrefix + 'mixed-media-strip' :
      this.mediaSourcePrefix + 'photo-list-' + startIndex.toString();
  }

  private photoReturnVisible(media: MediaAttachment, startIndex: number): boolean {
    try {
      const utils = this.getUIContext().getComponentUtils();
      const photo = utils.getRectangleById(this.mediaSourceId(media));
      const strip = utils.getRectangleById(this.photoListId(startIndex));
      return photo.size.width > 1 && photo.size.height > 1 && strip.size.width > 1 && strip.size.height > 1 &&
        photo.windowOffset.x + photo.size.width > strip.windowOffset.x + 0.5 &&
        photo.windowOffset.x < strip.windowOffset.x + strip.size.width - 0.5 &&
        photo.windowOffset.y + photo.size.height > strip.windowOffset.y + 0.5 &&
        photo.windowOffset.y < strip.windowOffset.y + strip.size.height - 0.5;
    } catch (_error) { return false; }
  }

  private photoIndex(media: MediaAttachment): number {
    const items: PhotoViewerPhoto[] = this.photoItems();
    const attachments: MediaAttachment[] = this.viewerPhotoMedia();
    for (let i: number = 0; i < items.length; i++) {
      if (attachments[items[i].sourceIndex]?.id === media.id) {
        return i;
      }
    }
    return -1;
  }

  private openPhoto(media: MediaAttachment): void {
    const items: PhotoViewerPhoto[] = this.photoItems();
    const index: number = this.photoIndex(media);
    hilog.info(DOMAIN, TAG, 'photo viewer requested id=%{public}s kind=%{public}s count=%{public}d index=%{public}d',
      media.id, media.type, items.length, index);
    if (items.length === 0) {
      return;
    }
    if (index < 0) {
      return;
    }
    this.photoTransitionPrefix = 'photo-viewer-' + Date.now().toString() + '-' + media.id;
    const source: MediaViewerSource | undefined = captureMediaViewerSource(this.getUIContext(),
      this.mediaSourceId(media), media.id, items[index].width, items[index].height, this.photoViewportHeight > 0);
    requestPhotoViewer(items, index, media.altText, this.photoTransitionPrefix, this.sourceTweet, source);
  }

  private mediaSourceId(media: MediaAttachment): string {
    return this.mediaSourcePrefix + media.id;
  }

  private isActive(id: string): boolean {
    for (let i: number = 0; i < this.activeIds.length; i++) {
      if (this.activeIds[i] === id) {
        return true;
      }
    }
    return false;
  }

  private wantsCover(media: MediaAttachment): boolean {
    for (let i: number = 0; i < this.coverIds.length; i++) {
      if (this.coverIds[i] === media.id) {
        return true;
      }
    }
    return false;
  }

  // Called as a cell approaches the viewport: the neighbouring video gets its
  // cover decoded now, so it is already there when the reader arrives.
  private requestCover(media: MediaAttachment): void {
    if (!this.alive || this.wantsCover(media) || media.previewUrl.length > 0) {
      return;
    }
    const next: string[] = [];
    const first: number = this.coverIds.length > MAX_COVER_IDS - 1 ? 1 : 0;
    for (let i: number = first; i < this.coverIds.length; i++) {
      next.push(this.coverIds[i]);
    }
    next.push(media.id);
    this.coverIds = next;
  }

  private activate(media: MediaAttachment, manual: boolean = false): void {
    if (!this.alive || !this.playbackEnabled || !this.canStream(media)) {
      return;
    }
    if (this.videoFeedActive && !this.mediaViewerLayout) { return; }
    if (manual && !this.isManualStart(media.id)) {
      const manualIds: string[] = [];
      for (let i: number = 0; i < this.manualIds.length; i++) {
        manualIds.push(this.manualIds[i]);
      }
      manualIds.push(media.id);
      this.manualIds = manualIds;
    }
    if (this.isActive(media.id)) {
      return;
    }
    if (this.isRetainedPlayer(media.id)) {
      const retained: string[] = [];
      for (let i: number = 0; i < this.retainedPlayerIds.length; i++) {
        if (this.retainedPlayerIds[i] !== media.id) {
          retained.push(this.retainedPlayerIds[i]);
        }
      }
      this.retainedPlayerIds = retained;
    }
    inlineVideoGate.claim(media.id);
    const next: string[] = [];
    for (let i: number = 0; i < this.activeIds.length; i++) {
      next.push(this.activeIds[i]);
    }
    next.push(media.id);
    this.activeIds = next;
    // How many cells ended up streaming at once is the number to look at when a
    // cell that should be playing is still showing its cover.
    hilog.info(DOMAIN, TAG, 'video stream start id=%{public}s live=%{public}d',
      media.id, inlineVideoGate.streamingCount());
  }

  private deactivate(media: MediaAttachment): void {
    if (!this.isActive(media.id)) {
      return;
    }
    // A cell playing in the floating window keeps its surface where it is.
    if (videoPipGate.isHeld(media.id)) {
      return;
    }
    let evictedId: string = '';
    if ((this.homeTimelineVideo || this.usesStableInlineLayout()) && !this.exploreHeroVideo && !this.pipEnabled &&
      !isAnimatedGif(media) && !videoPlayerHandoff.isRequested(media.id)) {
      evictedId = this.retainInlinePlayer(media.id);
    }
    if (!this.isRetainedPlayer(media.id)) { this.setInlinePreviewHidden(media.id, false); }
    if (evictedId.length > 0) { this.setInlinePreviewHidden(evictedId, false); }
    const next: string[] = [];
    for (let i: number = 0; i < this.activeIds.length; i++) {
      if (this.activeIds[i] !== media.id) {
        next.push(this.activeIds[i]);
      }
    }
    this.activeIds = next;
    const manualIds: string[] = [];
    for (let i: number = 0; i < this.manualIds.length; i++) {
      if (this.manualIds[i] !== media.id && this.manualIds[i] !== evictedId) {
        manualIds.push(this.manualIds[i]);
      }
    }
    this.manualIds = manualIds;
    inlineVideoGate.release(media.id);
  }

  private videoDownloadUrl(media: MediaAttachment): string {
    const choices: VideoDownloadChoice[] = videoDownloadChoices(media);
    return choices.length > 0 ? choices[0].url : '';
  }

  private openVideo(media: MediaAttachment): boolean {
    if (isAnimatedGif(media) || this.mediaViewerLayout || !this.canStream(media)) {
      return false;
    }
    const source: MediaViewerSource | undefined = captureMediaViewerSource(this.getUIContext(),
      this.mediaSourceId(media), media.id, media.width, media.height,
      this.naturalVideoSize && !this.fillVideoViewport && !this.immersiveVideo,
      this.immersiveVideo ? 0 : (this.fillVideoViewport ? 22 : 14));
    if (this.videoFeedEnabled) {
      this.retainInlinePlayer(media.id);
      pendingMediaViewerSource.request(source);
      this.onVideoOpen(media);
      return true;
    }
    if (this.sourceTweet !== null) {
      this.retainInlinePlayer(media.id);
      requestVideoViewer(this.sourceTweet, media, videoPlaybackPositionStore.positionFor(media.id), source);
      return true;
    }
    return false;
  }

  @Builder
  private SensitiveMediaGate(media: MediaAttachment, mediaHeight: number): void {
    Stack({ alignContent: Alignment.Center }) {
      // A hidden video never starts poster extraction or swaps a dynamic
      // poster/palette while scrolling. Decode only its blurred thumbnail.
      if (this.sensitivePreviewUrl(media).length > 0) {
        ProxyMediaImage({
          url: this.sensitivePreviewUrl(media),
          displayHeight: mediaHeight,
          contain: true,
          blurRadius: 28,
          surfaceColor: fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface)
        })
      } else {
        Column()
          .width('100%')
          .height(mediaHeight)
          .backgroundColor(fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
      }
      Column({ space: 10 }) {
        Text($r('app.string.sensitive_media_hidden')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_L'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_on_brand'))
          .textAlign(TextAlign.Center)
        Button($r('app.string.sensitive_media_show'))
          .fontSize($r('sys.float.Body_M'))
          .onClick((): void => this.revealMedia(media))
      }
      .width('100%')
      .height(mediaHeight)
      .padding({ left: 24, right: 24 })
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor('#77000000')
    }
    .width('100%')
    .height(mediaHeight)
    .borderRadius(14)
    .clip(true)
    .monopolizeEvents(true)
  }

  private sensitivePreviewUrl(media: MediaAttachment): string {
    if (isVideoLike(media) && media.previewUrl.length === 0) { return ''; }
    const url: string = media.previewUrl.length > 0 ? media.previewUrl : media.mediaUrl;
    return imageUrlForQuality(url, IMAGE_QUALITY_DATA_SAVER);
  }

  @Builder
  private PhotoActionContent(media: MediaAttachment, startIndex: number, onLongPress: () => void): void {
    MediaCover({
      photoSourceId: this.mediaSourceId(media),
      media: media, imageQuality: this.imageQuality, mediaHeight: this.photoRunHeight(startIndex),
      photoContain: true,
      onTap: (): void => this.openPhoto(media), onLongPress: onLongPress
    }).width(this.photoCellWidth(startIndex, media)).id(this.mediaSourceId(media))
  }

  @Builder
  private VideoActionContent(media: MediaAttachment, onLongPress: () => void): void {
    MediaCover({
      media: media, imageQuality: this.imageQuality, videoQuality: this.videoQuality,
      mediaHeight: this.videoDisplayHeight(media),
      videoContain: this.naturalVideoSize && !this.fillVideoViewport && !this.immersiveVideo,
      cornerRadius: this.immersiveVideo ? 0 : (this.fillVideoViewport ? 22 : 14),
      minimalVideoControls: this.exploreHeroVideo || this.hideInlineControls, wants: this.wantsCover(media),
      spinner: this.usesStableInlineLayout() && (this.videoAutoplay || this.isManualStart(media.id)) &&
        this.showsPlayer(media) && !this.inlinePreviewHidden(media.id),
      onLongPress: onLongPress,
      onTap: (): void => {
        if (this.linkCardVideo) { this.onVideoOpen(media); return; }
        if (this.canStream(media)) {
          if (this.openVideo(media)) { return; }
          this.activate(media, true);
        }
      }
    }).id(this.mediaSourceId(media))
  }

  @Builder
  private PhotoStrip(startIndex: number): void {
    List({ space: 6, scroller: this.photoScrollerFor(startIndex) }) {
      if (this.photoStartOffset > 0) {
        ListItem() {
          Column().width(Math.max(0, this.photoStartOffset - 6))
        }
        .width(Math.max(0, this.photoStartOffset - 6))
      }
      ForEach(this.photoRun(startIndex), (media: MediaAttachment) => {
        ListItem() {
          Column() {
            PostMediaActions({ media: media,
              content: (onLongPress: () => void): void => { this.PhotoActionContent(media, startIndex, onLongPress); } })
          }.width(this.photoCellWidth(startIndex, media))
        }
        .width(this.photoCellWidth(startIndex, media))
      }, (media: MediaAttachment) => media.id)
    }
    .listDirection(Axis.Horizontal)
    .onDidScroll((): void => this.updateMediaPan(this.photoScrollerFor(startIndex)))
    .onScrollStop((): void => this.updateMediaPan(this.photoScrollerFor(startIndex)))
    .id(this.photoListId(startIndex))
    .scrollBar(BarState.Off)
    .contentEndOffset(this.photoEndOffset)
    .width('100%')
    .height(this.photoRunHeight(startIndex))
    .onScrollIndex((_start: number, _end: number, center: number): void => {
      const firstPhoto: number = this.photoStartOffset > 0 ? 1 : 0;
      this.onPhotoPageChanged(startIndex + Math.max(0, center - firstPhoto));
    })
    .onAreaChange((oldValue: Area, newValue: Area): void => {
      const width: number = Number(newValue.width);
      if (width > 0 && Math.abs(width - this.photoContainerWidth) > 1) {
        this.photoContainerWidth = width;
      }
    })
    .onVisibleAreaApproximateChange({ ratios: [0, 0.05], expectedUpdateInterval: 100 },
      (isExpanding: boolean, currentRatio: number): void => {
        this.photoListVisible.set(startIndex, currentRatio > 0);
      })
    .onTouch((event: TouchEvent): void => {
      if (event.type === TouchType.Down) {
        event.stopPropagation();
      }
    })
  }

  @Builder
  private AnimatedGif(media: MediaAttachment): void {
    Stack({ alignContent: Alignment.TopEnd }) {
      if (this.isGifFileUrl(media.mediaUrl)) {
        GifPreviewImage({
          url: media.mediaUrl,
          previewUrl: media.previewUrl,
          displayHeight: this.videoDisplayHeight(media),
          surfaceColor: fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface)
        })
          .borderRadius(14)
          .clip(true)
          .hitTestBehavior(HitTestMode.None)
      } else if (this.showsPlayer(media)) {
        // MP4 is only the decoder input: the GIF surface has no video controls,
        // player handoff, resume time, captions, audio or PiP interaction.
        SurfaceVideoPlayer({
              controlsUsePageBackground: this.controlsUsePageBackground, controlSurface: this.controlSurface,
          hideInlineControls: this.hideInlineControls,
          media: media,
          imageQuality: this.imageQuality,
          videoQuality: this.videoQuality,
          playbackEnabled: this.playbackEnabled,
          naturalVideoSize: true,
          fillVideoViewport: this.isHorizontalMediaStrip(), videoViewportHeight: this.horizontalMediaLayout().height,
          manualStart: this.isManualStart(media.id)
        })
          .hitTestBehavior(HitTestMode.None)
      } else {
        MediaCover({
          media: media,
          imageQuality: this.imageQuality,
          videoQuality: this.videoQuality,
          mediaHeight: this.videoDisplayHeight(media),
          videoContain: false,
          minimalVideoControls: true,
          wants: this.wantsCover(media)
        })
          .hitTestBehavior(HitTestMode.None)
      }
      // A native target owns the entire animation rectangle. The decoder's
      // XComponent and its preview cannot consume the post's open gesture.
      // Keep event arbitration enabled so the parent feed can still scroll.
      Button({ type: ButtonType.Normal, stateEffect: false }) {
        Column().width('100%').height('100%')
      }
        .width('100%').height('100%').backgroundColor(Color.Transparent)
        .id('post-gif-open-' + media.id)
        .accessibilityText($r('app.string.post_gif_label'))
        .onClick((): void => this.openPhoto(media))
        .gesture(LongPressGesture({ fingers: 1, repeat: false, duration: 500 })
          .onAction((): void => this.showGifActionMenu(media)))
      Text($r('app.string.post_gif_label')).fontFamily(this.appFontFamily)
        .fontSize(11)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_on_brand'))
        .backgroundColor($r('app.color.post_media_badge_background'))
        .borderRadius(6)
        .padding({ left: 7, right: 7, top: 4, bottom: 4 })
        .margin({ top: 10, right: 10 })
        .hitTestBehavior(HitTestMode.None)
    }
    .width('100%')
    .height(this.videoDisplayHeight(media))
    .id(this.mediaSourceId(media))
    .onAreaChange((_oldValue: Area, newValue: Area): void => {
      const width: number = Number(newValue.width);
      if (width > 0 && Math.abs(width - this.videoContainerWidth) > 1) {
        this.videoContainerWidth = width;
      }
    })
    .onVisibleAreaApproximateChange({ ratios: [COVER_RATIO, PLAY_RATIO], expectedUpdateInterval: 300 },
      (isExpanding: boolean, currentRatio: number): void => {
        if (this.isGifFileUrl(media.mediaUrl) || !this.canStream(media)) {
          return;
        }
        if (isExpanding) {
          this.requestCover(media);
          if (this.videoAutoplay && currentRatio >= PLAY_RATIO) {
            this.activate(media);
          }
        } else if (currentRatio <= COVER_RATIO) {
          this.deactivate(media);
        }
      })
    .onMouse((event: MouseEvent): void => contextInputMouse(event, (): void => this.showGifActionMenu(media)))
    .bindContextMenu(this.gifActionMenuMediaId === media.id, this.GifActionMenu(media),
      this.gifContextMenuOptions(media))
  }

  @Builder
  private VideoAttachmentContent(media: MediaAttachment, onLongPress: () => void): void {
        Stack({ alignContent: Alignment.TopEnd }) {
          if (this.showsPlayer(media)) {
            SurfaceVideoPlayer({
              controlsUsePageBackground: this.controlsUsePageBackground, controlSurface: this.controlSurface,
              hideInlineControls: this.hideInlineControls,
              transitionSourceId: this.mediaSourceId(media),
              onViewerSurfaceReady: this.onViewerSurfaceReady,
              castRequestSerial: this.castRequestSerial,
              onViewerCastPickerChanged: this.onViewerCastPickerChanged,
              onViewerCastingChanged: this.onViewerCastingChanged,
              mediaViewerLayout: this.mediaViewerLayout,
              landscapePostContent: this.ForwardLandscapePost,
              onViewerBack: this.onViewerBack,


              onViewerMore: this.onViewerMore,
              onViewerCommentDismiss: this.onViewerCommentDismiss,
              sourceTweet: this.sourceTweet,
              viewerDanmakuEnabled: this.viewerDanmakuEnabled,
              viewerAuthorFollowing: this.viewerAuthorFollowing,
              viewerDownloading: this.viewerDownloading,
              onViewerDownload: this.onViewerDownload,
              onViewerFollow: this.onViewerFollow,
              onViewerComment: this.onViewerComment,
              onViewerDanmakuToggle: this.onViewerDanmakuToggle,
              onViewerDanmakuSend: this.onViewerDanmakuSend,
              viewerFullscreenRequest: this.viewerFullscreenRequest,
              viewerDanmakuContent: this.ForwardDanmaku,
              compactFeedActions: this.ForwardCompactFeedActions,
              onViewerControlsChanged: this.onViewerControlsChanged,
              onViewerVideoTap: this.onViewerVideoTap,
              onMenuRequest: onLongPress,
              media: media,
              imageQuality: this.imageQuality,
              videoQuality: this.videoQuality,
              playbackEnabled: this.playbackEnabled,
              preloadEnabled: !this.playbackEnabled && this.preloadMediaId === media.id,
              initialPositionSeconds: this.initialPositionMediaId === media.id ? this.initialPositionSeconds :
                (this.initialPositionMediaId.length === 0 && (this.homeTimelineVideo || this.mediaViewerLayout) && !this.exploreHeroVideo ?
                videoPlaybackPositionStore.positionFor(media.id) : 0),
              naturalVideoSize: this.naturalVideoSize,
              limitNaturalHeight: this.limitNaturalHeight,
              inlineFrameHeight: this.usesStableInlineLayout() ? this.videoDisplayHeight(media) : 0,
              persistentInlinePreview: this.usesStableInlineLayout(),
              onInlinePreviewHidden: (hidden: boolean): void => this.setInlinePreviewHidden(media.id, hidden),
              adaptiveShortVideo: this.adaptiveShortVideo,
              immersiveVideo: this.immersiveVideo,
              fillVideoViewport: this.isHorizontalMediaStrip() || this.fillVideoViewport,
              videoViewportHeight: this.isHorizontalMediaStrip() ? this.horizontalMediaLayout().height : this.videoViewportHeight,
              controlsAtScreenBottom: this.controlsAtScreenBottom,
              compactFeedLayout: this.compactFeedLayout,
              compactBottomActions: this.compactBottomActions,
              viewerUsesSideComments: this.viewerUsesSideComments,
              viewerPhoneFeedLayout: this.viewerPhoneFeedLayout,
              viewerCommentProgress: this.viewerCommentProgress,
              viewerCommentTop: this.viewerCommentTop,
              viewerCommentHeight: this.viewerCommentHeight,
              retainViewerPlayback: this.retainViewerPlayback,
              forceUnmuted: this.forceUnmuted,
              homeTimelineVideo: this.homeTimelineVideo,
              linkCardVideo: this.linkCardVideo,
              onLinkCardOpen: (): void => this.onVideoOpen(media),
              exploreHeroVideo: this.exploreHeroVideo,
              exploreHeroMuted: this.exploreHeroMuted,
              playerBarBottomOffset: this.playerBarBottomOffset,
              captionRequested: this.captionEnabled && media.type === 'video',
              manualStart: this.isManualStart(media.id),
              allowPip: this.pipEnabled,
              pipNavigationHandleId: this.pipNavigationHandleId,
              onPipIntent: (): void => {
                this.activate(media);
              },
              onFullscreenIntent: (positionSeconds: number): boolean => {
                videoPlaybackPositionStore.remember(media.id, positionSeconds);
                return this.openVideo(media);
              },
              fullscreenFeedSwipeEnabled: this.sourceTweet !== null || this.mediaViewerLayout,
              onFullscreenFeedSwipe: (): void => {
                if (this.mediaViewerLayout) { this.onViewerAdvance(); }
                else { this.openVideo(media); }
              },
              onCaptionChanged: (shown: boolean): void => {
                this.onCaptionChanged(shown);
              },
              onPlaybackCompleted: (): void => {
                this.onPlaybackCompleted();
              },
              onPlaybackStateChanged: (playing: boolean): void => {
                if (playing && !this.videoAutoplay && !this.isManualStart(media.id)) {
                  this.manualIds = [...this.manualIds, media.id];
                }
                this.onPlaybackStateChanged(playing);
              },
              onHoldSpeedChanged: this.onHoldSpeedChanged,
              onInitialPositionApplied: (): void => {
                this.onInitialPositionApplied();
              }
            })
          }
          if (this.usesStableInlineLayout() || !this.showsPlayer(media)) {
            // This preview stays decoded while the native surface opens.
            // A manual-play cover does not reserve an empty control strip.
            Column() {
              this.VideoActionContent(media, onLongPress)
              if (this.inlineControlsHeight(media) > 0) {
                Column().width('100%').height(this.inlineControlsHeight(media))
              }
            }
            .width('100%')
            .opacity(this.showsPlayer(media) && this.inlinePreviewHidden(media.id) ? 0 : 1)
            // None excludes only this Column; its preview and control spacer
            // would still hide the live player's buttons from touch testing.
            .hitTestBehavior(this.showsPlayer(media) ? HitTestMode.BLOCK_DESCENDANTS : HitTestMode.Default)
          }
          if (this.showDownloadButton && this.videoDownloadButton && media.type === 'video' &&
            this.videoDownloadUrl(media).length > 0 && !this.mediaViewerLayout && !this.hideInlineControls) {
            MediaDownloadButton({ url: this.videoDownloadUrl(media), mediaId: media.id,
              isVideo: true, videoMedia: media }).position({ top: 12, right: 12 }).zIndex(5)
          }
        }
        .width('100%')
        .onAreaChange((oldValue: Area, newValue: Area): void => {
          const width: number = Number(newValue.width);
          if (width > 0 && Math.abs(width - this.videoContainerWidth) > 1) {
            this.videoContainerWidth = width;
          }
        })
        .onVisibleAreaApproximateChange({ ratios: [COVER_RATIO, PLAY_RATIO],
          expectedUpdateInterval: 300 }, (isExpanding: boolean, currentRatio: number): void => {
          // The picture-in-picture player watches its own viewport.
          if (!this.canStream(media) || this.pipEnabled) {
            return;
          }
          if (isExpanding) {
            this.requestCover(media);
            if ((this.videoAutoplay || this.exploreHeroVideo) && currentRatio >= PLAY_RATIO) {
              this.activate(media);
            }
          } else if (currentRatio <= COVER_RATIO) {
            this.deactivate(media);
          }
        })
  }

  @Builder
  private VideoAttachment(media: MediaAttachment): void {
    if (this.isMediaHidden(media)) {
      this.SensitiveMediaGate(media, this.sensitiveMediaHeight(media))
    } else {
      PostMediaActions({
        media: media,
        tweet: this.sourceTweet,
        content: (onLongPress: () => void): void => {
          this.VideoAttachmentContent(media, onLongPress);
        }
      })
    }
  }

  @Builder
  private HorizontalMediaStrip(): void {
    List({ space: 6, scroller: this.mediaStripScroller }) {
      if (this.photoStartOffset > 0) {
        ListItem() { Column().width(Math.max(0, this.photoStartOffset - 6)) }
          .width(Math.max(0, this.photoStartOffset - 6))
      }
      ForEach(this.attachments, (media: MediaAttachment, index: number) => {
        ListItem() {
          if (isAnimatedGif(media)) {
            if (this.isMediaHidden(media)) { this.SensitiveMediaGate(media, this.horizontalMediaLayout().height) }
            else { this.AnimatedGif(media) }
          } else if (isVideoLike(media)) {
            this.VideoAttachment(media)
          } else if (this.isUsablePhoto(media)) {
            if (this.isMediaHidden(media)) { this.SensitiveMediaGate(media, this.horizontalMediaLayout().height) }
            else {
              PostMediaActions({ media: media,
                content: (onLongPress: () => void): void => { this.PhotoActionContent(media, index, onLongPress); } })
            }
          }
        }.width(this.horizontalMediaLayout().widths[index])
      }, (media: MediaAttachment): string => media.id)
    }.listDirection(Axis.Horizontal).width('100%').height(this.horizontalMediaLayout().height)
      .id(this.mediaSourcePrefix + 'mixed-media-strip')
      .scrollBar(BarState.Off).contentEndOffset(this.photoEndOffset)
      .onDidScroll((): void => this.updateMediaPan(this.mediaStripScroller))
      .onScrollStop((): void => this.updateMediaPan(this.mediaStripScroller))
      .onAreaChange((_old: Area, area: Area): void => {
        const width: number = Number(area.width);
        if (width > 0 && Math.abs(width - this.photoContainerWidth) > 1) { this.photoContainerWidth = width; }
      })
  }

  build(): void {
    Column({ space: 6 }) {
      if (this.isHorizontalMediaStrip()) { this.HorizontalMediaStrip() } else {
      ForEach(this.attachments, (media: MediaAttachment, index: number) => {
        if (this.isPhotoRunStart(index)) {
          if (this.photoRunHasHiddenSensitive(index)) {
            this.SensitiveMediaGate(this.sensitivePhotoForRun(index), this.photoRunHeight(index))
          } else {
            this.PhotoStrip(index)
          }
        }
        if (isAnimatedGif(media)) {
          if (this.isMediaHidden(media)) {
            this.SensitiveMediaGate(media, this.videoDisplayHeight(media))
          } else {
            this.AnimatedGif(media)
          }
        } else if (media.type === 'video') {
          this.VideoAttachment(media)
        }
      }, (media: MediaAttachment) => media.id)
      }
    }
    .width('100%')
  }
}
