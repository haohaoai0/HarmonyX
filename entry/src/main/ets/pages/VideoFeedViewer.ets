import { MediaViewerNavigationReturn } from '../utils/MediaViewerNavigation';
import { ProfileVideoStream } from '../services/ProfileVideoStream';
import { VideoSourceAttribution } from '../components/VideoSourceAttribution';
import { mediaViewerTitleBarStyle } from '../utils/MediaViewerTitleBar';
import { STORAGE_KEY_VIDEO_DOWNLOAD_BUTTON } from '../services/MediaSettingsStore';
import { HdsNavigationMenuItemOptions } from '@kit.UIDesignKit';
import { offlineReadingStore, OfflineSaveResult } from '../services/OfflineReadingStore';
import { KeyCode } from '@kit.InputKit';
import { backInputKey, plainInputKey, contextInputMouse } from '../utils/InputSupport';
import { motionDuration, motionCurve, motionDistance, motionScale } from '../utils/AppMotion';
import { menuActionVisible, menuActionsForGroup, MenuActionOption } from '../models/MenuActionCatalog';
import { STORAGE_KEY_HIDDEN_MENU_ACTIONS } from '../services/MenuSettingsStore';
import { STORAGE_KEY_VIDEO_CAPTIONS_ENABLED, STORAGE_KEY_VIDEO_AUTO_ADVANCE } from '../services/MediaSettingsStore';
import { STORAGE_KEY_PAGE_TRANSITION_MODE, DEFAULT_PAGE_TRANSITION_MODE } from '../services/PageTransitionSettingsStore';
import { pageSystemTransition } from '../utils/PageTransition';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { STORAGE_KEY_SYSTEM_EMOJI_ENABLED } from '../services/AppearanceStore';
import { PostAdLabel } from '../components/PostAdLabel';
import { verificationBadgeColor } from '../utils/UserIdentity';
import { ProxyAvatar } from '../components/ProxyAvatar';
import { DEFAULT_SHEET_MATERIAL_ENABLED, DEFAULT_SHEET_MATERIAL_LEVEL, STORAGE_KEY_SHEET_MATERIAL_ENABLED, STORAGE_KEY_SHEET_MATERIAL_LEVEL } from '../services/SheetMaterialSettingsStore';
import { sheetMaterialOptions, sheetUsesCenteredPresentation } from '../utils/SheetMaterial';
// Vertical video-post surface. It is intentionally thin: playback, quality,
// cover generation, and fullscreen controls stay inside PostMedia.
import { HdsNavDestination, HdsNavDestinationTitleMode, HdsNavDestinationAttribute } from '@kit.UIDesignKit';
import { common } from '@kit.AbilityKit';
import { EmojiSpans } from '../components/EmojiSpans';
import { curves, uiMaterial, window } from '@kit.ArkUI';
import { BusinessError, deviceInfo } from '@kit.BasicServicesKit';
import { connection } from '@kit.NetworkKit';
import promptAction from '@ohos.promptAction';
import { MediaViewerPostActions } from '../components/MediaViewerPostActions';
import { PostMedia, VIDEO_FEED_CONTROLS_HEIGHT } from '../components/PostMedia';
import { VideoFeedBackdrop } from '../components/VideoFeedBackdrop';
import { videoPosterSource, videoPosterRendition } from '../services/VideoPosterStore';
import { chooseVideoDownloadUrl } from '../services/VideoDownloadChoice';
import { MaterialButton } from '../components/MaterialButton';
import { CompactVideoActionButton } from '../components/CompactVideoActionButton';
import { VideoHoldSpeedCapsule } from '../components/VideoHoldSpeedCapsule';
import { formatCount } from '../models/Tweet';
import type { MediaAttachment, Tweet, UserProfile } from '../models/Tweet';
import { authStore } from '../services/AuthStore';
import { postLikeStore, STORAGE_KEY_POST_LIKES_REVISION } from '../services/PostLikeStore';
import { videoPlayerHandoff } from '../services/VideoPlayerHandoff';
import { videoPipGate } from '../services/VideoPipGate';
import { MediaViewerMotion, MediaViewerMotionFrame } from '../components/MediaViewerMotion';
import { captureMediaViewerSource, createMediaSourcePrefix, measureMediaViewerGeometry,
  MediaViewerGeometry, MediaViewerMotionState, MediaViewerSource } from '../utils/MediaViewerMotion';
import { STORAGE_KEY_VIDEO_FEED_ACTIVE } from '../services/VideoPlaybackCoordinator';
import {
  DEFAULT_VIDEO_AUTO_BITRATE_CAP,
  DEFAULT_CAPTION_OPACITY,
  mediaSettingsStore,
  STORAGE_KEY_CAPTION_OPACITY,
  STORAGE_KEY_MEDIA_VIEWER_BLACK_BACKGROUND,
  STORAGE_KEY_SHOW_SENSITIVE_MEDIA,
  STORAGE_KEY_VIDEO_FEED_CONTROLS_ALWAYS_VISIBLE,
  STORAGE_KEY_VIDEO_FEED_LAYOUT,
  STORAGE_KEY_COMPACT_VIDEO_LAYOUT,
  COMPACT_VIDEO_LAYOUT_RAIL,
  COMPACT_VIDEO_LAYOUT_BOTTOM,
  videoHoldSpeedLabel,
  STORAGE_KEY_VIDEO_IMMERSIVE_FILL,
  STORAGE_KEY_VIDEO_QUALITY,
  STORAGE_KEY_VIDEO_AUTO_BITRATE_CAP,
  VIDEO_QUALITY_DATA_SAVER,
  VIDEO_QUALITY_HIGH,
  VIDEO_QUALITY_SD,
  VIDEO_QUALITY_LD,
  VIDEO_FEED_LAYOUT_CLASSIC,
  VIDEO_FEED_LAYOUT_DOUYIN
} from '../services/MediaSettingsStore';
import {
  MEDIA_DOWNLOAD_CANCELED,
  MEDIA_DOWNLOAD_SUCCESS,
  mediaDownloadService
} from '../services/MediaDownloadService';
import { XPrivateResult, xPrivateClient } from '../services/XPrivateClient';
import { XUserParser } from '../services/XUserParser';
import { hapticTick } from '../utils/Haptics';
import { openExternalLink } from '../utils/PostEntities';
import { GripHandManager } from '../utils/GripHandManager';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';
import { STORAGE_KEY_DESKTOP_VIDEO_LAYOUT,
  DESKTOP_VIDEO_LAYOUT_SPLIT, DESKTOP_VIDEO_LAYOUT_FEED } from '../services/LayoutSettingsStore';
import { VideoRecommendationStream, VideoRecommendationPage } from '../services/VideoRecommendationStream';
import { postModerationStore } from '../services/PostModerationStore';
import { STORAGE_KEY_FILTER_HIDE_ADS } from '../services/ContentFilterStore';
import { isAdPost } from '../utils/PostDisclosure';
import { VideoFeedDataSource, VideoFeedItem } from '../services/VideoFeedDataSource';
import { postShareUrl, sharePost } from '../utils/SharePost';
import { pageSurfaceColor } from '../utils/ThemeColors';
import {
  DEFAULT_CONTENT_FONT_FAMILY,
  STORAGE_KEY_CONTENT_FONT_FAMILY
} from '../services/AppearanceStore';
import { PostDetail } from './PostDetail';
import type { PostDetailRouteParam } from './PostDetail';
import type { UserDetailRouteParam } from './UserDetail';
import { browsingHistoryStore } from '../services/BrowsingHistoryStore';
import { OfflineVideoSaveStatus, offlineVideoStore } from '../services/OfflineVideoStore';
import { VideoDanmakuOverlay } from '../components/VideoDanmakuOverlay';
import { VideoFullscreenCapsule } from '../components/VideoFullscreenCapsule';
import { VideoFeedActionButton } from '../components/VideoFeedActionButton';
import { VideoDanmaku, VideoDanmakuComment } from '../services/VideoDanmaku';
import { VIDEO_FEED_LAYOUT_BILIBILI } from '../services/MediaSettingsStore';
import { STORAGE_KEY_VIDEO_FEED_TAP_PAUSE } from '../services/MediaSettingsStore';
import { XTimelineParser, TweetDetailPage } from '../services/XTimelineParser';
import { XApiClient } from '../services/XApiClient';
import { XPostFeedback } from '../services/XPostFeedback';
import { SystemMaterialUtil } from '../utils/SystemMaterial';
import { materialModifier } from '../utils/SystemMaterial';

export interface VideoFeedRouteParam {
  source?: MediaViewerSource;
  sourceTweetIds?: string[];
  sourceProfileId?: string;
  tweets: Tweet[];
  index: number;
  startPlaying?: boolean;
  startMediaId?: string;
  startPositionSeconds?: number;
  offline?: boolean;
  onLike: (target: Tweet, liked: boolean) => Promise<boolean>;
  onRepost: (target: Tweet, reposted: boolean) => Promise<boolean>;
  onReply: (target: Tweet) => void;
}

export interface VideoFeedPage {
  tweets: Tweet[];
  hasMore: boolean;
}

// Space the short-video caption reserves on its right so the action rail floats
// clear of the text: rail width plus its outer margin and a small gap.
const VIDEO_FEED_RAIL_RESERVED_WIDTH: number = 80;
// Vertical spacing inside the rail and between the rail and the control strip.
const VIDEO_FEED_RAIL_GAP: number = 12;
const VIDEO_FEED_RAIL_WIDTH: number = 56;
const VIDEO_FEED_RAIL_BUTTON: number = 52;
const VIDEO_FEED_RAIL_ICON: number = 26;
const VIDEO_FEED_RAIL_BADGE_OFFSET: number = 12;
// The rail always lays out against the leading edge and is moved to the held
// side by an animated translation, so the switch tweens instead of snapping.
const VIDEO_FEED_RAIL_SIDE_MARGIN: number = 10;
const VIDEO_FEED_CAPTION_INSET: number = 16;
const VIDEO_FEED_RAIL_SWITCH_DURATION_MS: number = 360;
const VIDEO_FEED_RAIL_GRIP_KEY: string = 'video-feed-rail';
// Height of the back / more button row, used to place the hold-to-speed capsule
// directly under it.
const TOP_CONTROLS_HEIGHT: number = 44;

@Component
struct VideoFeedCell {
  @ObjectLink item: VideoFeedItem;
  @BuilderParam content: (item: VideoFeedItem) => void;

  build(): void { this.content(this.item) }
}

@Builder
export function VideoFeedViewerBuilder(): void {
  VideoFeedViewer();
}

@Component
export struct VideoFeedViewer {
  @StorageProp(STORAGE_KEY_PAGE_TRANSITION_MODE) private pageTransitionMode: string = DEFAULT_PAGE_TRANSITION_MODE;
  @State private motion: MediaViewerMotionState = new MediaViewerMotionState();
  @State private initialVideoSurfaceReady: boolean = false;
  private motionSurfaceId: string = createMediaSourcePrefix() + 'video-viewer';
  private returnNavigation: MediaViewerNavigationReturn = new MediaViewerNavigationReturn();
  private routeLoaded: boolean = false;
  @StorageProp('reduceMotionEnabled') private reduceMotion: boolean = false;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp(STORAGE_KEY_SYSTEM_EMOJI_ENABLED) private systemEmojiEnabled: boolean = false;
  @StorageProp('harmonyx.breakpoint') @Watch('onWindowSizeChanged') private sheetWindowBreakpoint: string = 'sm';
  @StorageProp(STORAGE_KEY_DESKTOP_VIDEO_LAYOUT) @Watch('onWindowSizeChanged')
  private desktopVideoLayout: number = DESKTOP_VIDEO_LAYOUT_SPLIT;
  @StorageProp(STORAGE_KEY_SHEET_MATERIAL_ENABLED) private sheetMaterialEnabled: boolean = DEFAULT_SHEET_MATERIAL_ENABLED;
  @StorageProp(STORAGE_KEY_SHEET_MATERIAL_LEVEL) private sheetMaterialLevel: number = DEFAULT_SHEET_MATERIAL_LEVEL;
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp('harmonyx.status_bar_height') @Watch('onWindowSizeChanged') statusBarHeight: number =
    AppStorage.get<number>('harmonyx.status_bar_height') ?? 0;
  @StorageProp('harmonyx.navigation_indicator_height') @Watch('onWindowSizeChanged') navigationIndicatorHeight: number =
    AppStorage.get<number>('harmonyx.navigation_indicator_height') ?? 0;
  @StorageProp('harmonyx.window_width') @Watch('onWindowSizeChanged') windowWidth: number =
    AppStorage.get<number>('harmonyx.window_width') ?? 0;
  @StorageProp('harmonyx.window_height') @Watch('onWindowSizeChanged') windowHeight: number =
    AppStorage.get<number>('harmonyx.window_height') ?? 0;
  @StorageLink('harmonyx.accent_color') accentColor: string = '#007DFF';
  @StorageProp('harmonyx.display_mode') private themeDisplayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private themeDarkSurface: string = '';
  @StorageLink(STORAGE_KEY_CONTENT_FONT_FAMILY) private contentFontFamily: string = DEFAULT_CONTENT_FONT_FAMILY;
  @StorageLink(STORAGE_KEY_FILTER_HIDE_ADS) private filterHideAds: boolean = true;
  @StorageLink(STORAGE_KEY_VIDEO_IMMERSIVE_FILL) videoImmersiveFill: boolean = false;
  @StorageProp(STORAGE_KEY_MEDIA_VIEWER_BLACK_BACKGROUND) mediaViewerBlackBackground: boolean = false;
  @StorageLink(STORAGE_KEY_VIDEO_FEED_CONTROLS_ALWAYS_VISIBLE)
  videoFeedControlsAlwaysVisible: boolean = false;
  @StorageProp(STORAGE_KEY_HIDDEN_MENU_ACTIONS) private hiddenMenuActions: string = '';
  @StorageLink(STORAGE_KEY_VIDEO_FEED_LAYOUT) videoFeedLayout: number = VIDEO_FEED_LAYOUT_CLASSIC;
  @StorageLink(STORAGE_KEY_COMPACT_VIDEO_LAYOUT) private compactVideoLayout: number = COMPACT_VIDEO_LAYOUT_RAIL;
  @StorageLink(STORAGE_KEY_VIDEO_FEED_TAP_PAUSE) private videoFeedTapPause: boolean = false;
  @StorageProp('harmonyx.grip_video_enabled') @Watch('onGripHandEnabledChanged') private componentGripEnabled: boolean = true;
  @StorageLink('harmonyx.grip_hand_enabled') @Watch('onGripHandEnabledChanged')
  gripHandEnabled: boolean = true;
  @StorageLink('harmonyx.grip_preferred_hand') @Watch('onPreferredHandChanged')
  preferredHand: string = 'right';
  @State private railHand: string = 'right';
  @State private railShiftX: number = 0;
  @State private captionLeadingInset: number = VIDEO_FEED_CAPTION_INSET;
  @State private captionTrailingInset: number = VIDEO_FEED_RAIL_RESERVED_WIDTH;
  @StorageLink(STORAGE_KEY_SHOW_SENSITIVE_MEDIA) showSensitiveMedia: boolean = false;
  @StorageLink(STORAGE_KEY_VIDEO_QUALITY) videoQuality: number = VIDEO_QUALITY_DATA_SAVER;
  @StorageLink(STORAGE_KEY_CAPTION_OPACITY) captionOpacity: number = DEFAULT_CAPTION_OPACITY;
  @State private items: VideoFeedItem[] = [];
  private videoDataSource: VideoFeedDataSource = new VideoFeedDataSource();
  @State private current: number = 0;
  @State private preloadActive: boolean = false;
  @State private pageShown: boolean = true;
  @State private preloadAheadCount: number = 1;
  @State private videoViewportHeights: number[] = [];
  @State private videoChromeVisible: boolean[] = [];
  @State private castRequestSerial: number = 0;
  @State private castRequestMediaId: string = '';
  @State private castPickerShowing: boolean = false;
  @State private castingMediaId: string = '';
  @State private manualStartPending: boolean = false;
  @State private startMediaId: string = '';
  @State private startPositionSeconds: number = 0;
  @State private startPositionPending: boolean = false;
  private initialIndex: number = -1;
  @State private showMoreSheet: boolean = false;
  @State private showPostSheet: boolean = false;
  @State private postSheetActive: boolean = false;
  @State private postSheetTweet: Tweet | null = null;
  @State private postSheetHeight: number = 0;
  @State private commentPreviewHeight: number = 0;
  @State private commentPreviewProgress: number = 0;
  private postSheetOpening: boolean = false;
  @StorageLink(STORAGE_KEY_VIDEO_CAPTIONS_ENABLED) private captionsEnabled: boolean = false;
  // Set while the reader holds the playing video: the rate capsule sits just
  // below the back/more row, exactly where the press started.
  @State private holdSpeedActive: boolean = false;
  @State private holdSpeedRate: number = 2;
  @StorageLink(STORAGE_KEY_VIDEO_AUTO_ADVANCE) private autoAdvance: boolean = true;
  @State private qualityExpanded: boolean = false;
  @State private liked: boolean = false;
  @State private likeCount: number = 0;
  @StorageProp(STORAGE_KEY_POST_LIKES_REVISION) @Watch('syncLikeState') private likeRevision: number = 0;
  @State private reposted: boolean = false;
  @State private bookmarked: boolean = false;
  @State private authorFollowing: boolean = false;
  @State private authorFollowPending: boolean = false;
  @State private downloading: boolean = false;
  private choosingDownloadQuality: boolean = false;
  private pager: SwiperController = new SwiperController();

  private inputBack(): void {
    if (this.showDanmakuSheet) { this.showDanmakuSheet = false; return; }
    if (this.showPostSheet) { this.closePostSheet(); return; }
    if (this.showMoreSheet) { this.showMoreSheet = false; return; }
    this.close();
  }

  private videoInputKey(event: KeyEvent): boolean {
    if (!this.pageShown || this.closing || this.postSheetActive || this.showDanmakuSheet || this.showMoreSheet ||
      this.castPickerShowing || this.danmakuSending || !plainInputKey(event)) { return false; }
    const previous: boolean = event.keyCode === KeyCode.KEYCODE_DPAD_UP || event.keyCode === KeyCode.KEYCODE_PAGE_UP;
    const next: boolean = event.keyCode === KeyCode.KEYCODE_DPAD_DOWN || event.keyCode === KeyCode.KEYCODE_PAGE_DOWN;
    if (!previous && !next) { return false; }
    if (event.type === KeyType.Down) {
      const target: number = this.current + (previous ? -1 : 1);
      if (target >= 0 && target < this.items.length) { this.pager.changeIndex(target, true); }
    }
    return true;
  }
  private authorUserId: string = '';
  @State private likePending: boolean = false;
  @State private repostPending: boolean = false;
  @State private bookmarkPending: boolean = false;
  @State private closing: boolean = false;
  private viewerAlive: boolean = true;
  private returningMediaId: string = '';
  private fullscreenAdvanceFrom: number = -1;
  private likeAction: (target: Tweet, liked: boolean) => Promise<boolean> =
    async (target: Tweet, liked: boolean): Promise<boolean> => false;
  private repostAction: (target: Tweet, reposted: boolean) => Promise<boolean> =
    async (target: Tweet, reposted: boolean): Promise<boolean> => false;
  private loadMoreAction: () => Promise<VideoFeedPage> = async (): Promise<VideoFeedPage> => {
    return { tweets: [], hasMore: false };
  };
  @State private loadingMoreVideos: boolean = false;
  @State private recommendationRetryNeeded: boolean = false;
  private recommendationStream: VideoRecommendationStream = new VideoRecommendationStream();
  private videoFeedExhausted: boolean = false;
  private profileStream: ProfileVideoStream | null = null;
  @State private openingSourceVideo: boolean = false;
  @StorageProp(STORAGE_KEY_VIDEO_DOWNLOAD_BUTTON) private videoDownloadButton: boolean = true;
  private preloadPolicyEpoch: number = 0;
  private networkPolicyConnection: connection.NetConnection | null = null;
  private pagerShown: boolean = false;
  @State private danmakuComments: VideoDanmakuComment[] = [];
  @State private danmakuEnabled: boolean = true;
  @State private danmakuLoading: boolean = false;
  @State private danmakuFailed: boolean = false;
  @State private danmakuDraft: string = '';
  @State private danmakuSending: boolean = false;
  @State private showDanmakuSheet: boolean = false;
  @State private episodesExpanded: boolean = false;
  @State private fullscreenRequest: number = 0;
  @State private fullscreenCapsuleTapSerial: number = 0;
  private danmakuGeneration: number = 0;
  private danmakuTweetId: string = '';
  private danmakuApi: XApiClient = new XApiClient();
  @State private danmakuKeyboardHeight: number = 0;
  private danmakuKeyboardWindow: window.Window | null = null;
  private danmakuKeyboardEpoch: number = 0;
  private danmakuKeyboardListener: (height: number) => void = (height: number): void => {
    if (this.showDanmakuSheet) { this.danmakuKeyboardHeight = this.getUIContext().px2vp(height); }
  };

  aboutToAppear(): void {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    xPrivateClient.load(context);
    authStore.load(context);
    this.initializeRailGripHand();
    setTimeout((): void => {
      this.readRoute();
    }, 30);
  }

  private controlMaterial(interactive: boolean): uiMaterial.Material | undefined {
    if (!deviceInfo.apiAvailable('26.0.0')) {
      return undefined;
    }
    return new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.THIN,
      colorInvert: true,
      applyShadow: true,
      interactive: interactive,
      lightEffect: interactive ? { color: this.accentColor } : null
    });
  }

  private readRoute(): void {
    if (this.routeLoaded) { return; }
    const params: VideoFeedRouteParam[] =
      this.pageStack.getParamByName('VideoFeedViewer') as VideoFeedRouteParam[];
    if (params === undefined || params === null || params.length === 0) {
      return;
    }
    const param: VideoFeedRouteParam = params[params.length - 1];
    this.routeLoaded = true;
    this.motion.prepare(param.source);
    this.initialVideoSurfaceReady = param.source === undefined;
    const next: VideoFeedItem[] = [];
    const requestedId: string = param.tweets[param.index]?.id ?? '';
    for (let i: number = 0; i < param.tweets.length; i++) {
      const tweet: Tweet = param.tweets[i];
      if (this.filterHideAds && isAdPost(tweet.presentation)) { continue; }
      const videos: MediaAttachment[] = this.videoAttachments(tweet, i === param.index && param.startPlaying === true);
      if (videos.length > 0) {
        next.push(new VideoFeedItem(tweet, this.focusedVideo(videos, i, param), next.length));
      }
    }
    this.likeAction = param.onLike;
    this.repostAction = param.onRepost;
    const selectedIndex: number = next.findIndex((item: VideoFeedItem): boolean => item.tweet.id === requestedId);
    const selected: VideoFeedItem | undefined = next[selectedIndex >= 0 ? selectedIndex : this.clampIndex(param.index, next.length)];
    this.items = selected === undefined ? [] : [new VideoFeedItem(selected.tweet, selected.attachments, 0)];
    this.videoDataSource.reset(this.items);
    this.current = 0;
    this.recommendationStream.close();
    this.recommendationStream = new VideoRecommendationStream(selected?.tweet.id ?? '',
      param.sourceTweetIds ?? param.tweets.map((tweet: Tweet): string => tweet.id),
      getContext(this) as common.UIAbilityContext, selected?.tweet.author.username ?? '');
    if (selected !== undefined) {
      this.recommendationStream.noteViewed(selected.tweet.id);
      browsingHistoryStore.record(getContext(this) as common.UIAbilityContext, selected.tweet);
    }
    this.profileStream = (param.sourceProfileId ?? '').length > 0 ?
      new ProfileVideoStream(param.sourceProfileId ?? '', this.recommendationStream) : null;
    this.loadMoreAction = (): Promise<VideoFeedPage> => this.loadRecommendedVideos();
    if (this.profileStream !== null && selected !== undefined) {
      this.appendVideoPage([selected.tweet]);
    }
    this.initialIndex = this.current;
    this.manualStartPending = param.startPlaying === true;
    this.startMediaId = param.startMediaId === undefined ? '' : param.startMediaId;
    this.startPositionSeconds = param.startPositionSeconds === undefined ? 0 : param.startPositionSeconds;
    this.startPositionPending = this.startMediaId.length > 0 && this.startPositionSeconds > 0;
    this.videoFeedExhausted = param.offline === true;
    this.updatePreloadPolicy();
    this.syncCurrentPostState();
    if (!this.videoFeedExhausted && this.current >= this.items.length - 3) {
      this.loadMoreVideos();
    }
  }

  private clampIndex(index: number, total: number): number {
    if (total <= 0 || index <= 0) {
      return 0;
    }
    if (index >= total) {
      return total - 1;
    }
    return index;
  }

  // A viewer page plays exactly one video. When the reader tapped the fullscreen
  // button of a specific video inside a multi-video post, that video — not the
  // post's first one — becomes the page's video. The post's other videos stay
  // behind in the timeline instead of being stacked below the invisible page.
  private focusedVideo(videos: MediaAttachment[], postIndex: number, param: VideoFeedRouteParam): MediaAttachment[] {
    const requested: string = param.startMediaId === undefined ? '' : param.startMediaId;
    if (requested.length > 0 && postIndex === param.index) {
      for (let i: number = 0; i < videos.length; i++) {
        if (videos[i].id === requested) {
          return [videos[i]];
        }
      }
    }
    return [videos[0]];
  }

  private videoAttachments(tweet: Tweet, allowSensitive: boolean = false): MediaAttachment[] {
    const out: MediaAttachment[] = [];
    const attachments: MediaAttachment[] | undefined = tweet.attachments;
    if (attachments === undefined) {
      return out;
    }
    for (let i: number = 0; i < attachments.length; i++) {
      const media: MediaAttachment = attachments[i];
      if (media.type === 'video' && media.mediaUrl.length > 0 &&
        (media.sensitive !== true || this.showSensitiveMedia || allowSensitive)) {
        out.push(media);
      }
    }
    return out;
  }

  private currentTweet(): Tweet | null {
    if (this.current < 0 || this.current >= this.items.length) {
      return null;
    }
    return this.items[this.current].tweet;
  }

  private currentVideo(): MediaAttachment | null {
    if (this.current < 0 || this.current >= this.items.length || this.items[this.current].attachments.length === 0) {
      return null;
    }
    return this.items[this.current].attachments[0];
  }

  private backdropStreamUrl(media: MediaAttachment): string {
    return videoPosterSource(media);
  }

  private requestVideoCast(): void {
    const media: MediaAttachment | null = this.currentVideo();
    if (media === null) { return; }
    hapticTick();
    this.showMoreSheet = false;
    this.castPickerShowing = true;
    this.castRequestMediaId = media.id;
    ++this.castRequestSerial;
  }

  private syncCurrentPostState(): void {
    const tweet: Tweet | null = this.currentTweet();
    if (tweet === null) {
      return;
    }
    this.syncLikeState();
    this.reposted = tweet.reposted;
    this.bookmarked = tweet.bookmarked ?? false;
    this.authorFollowing = false;
    this.authorUserId = tweet.author.id;
    this.loadAuthorFollowState(tweet);
    if (this.videoFeedLayout === VIDEO_FEED_LAYOUT_BILIBILI) { void this.loadDanmaku(tweet); }
  }

  private async loadAuthorFollowState(tweet: Tweet): Promise<void> {
    if (!xPrivateClient.isSignedIn() || tweet.author.username.length === 0 || this.isOwnPost(tweet)) {
      return;
    }
    const result: XPrivateResult = await xPrivateClient.userByScreenName(tweet.author.username);
    const active: Tweet | null = this.currentTweet();
    if (!result.ok || active === null || active.id !== tweet.id) {
      return;
    }
    const profile: UserProfile | null = XUserParser.parse(result.body);
    if (profile !== null) {
      this.authorFollowing = profile.following === true;
      this.authorUserId = profile.id;
    }
  }

  private isOwnPost(tweet: Tweet): boolean {
    const viewerId: string = authStore.getUserId();
    return viewerId.length > 0 && viewerId === tweet.author.id;
  }

  private toggleVideoOrientation(): void {
    if (this.currentVideo() === null) { return; }
    // This title-bar request starts the active player's fullscreen cover in
    // landscape; its bottom fullscreen button keeps the portrait entry.
    this.fullscreenRequest++;
  }

  private close(): void {
    if (this.closing) {
      return;
    }
    if (this.returnNavigation.request((): void => this.close(), (): void => ResponsiveLayout.closeContentDestination(this.pageStack, true))) { return; }
    this.closing = true;
    this.recommendationStream.close();
    const media: MediaAttachment | null = this.currentVideo();
    // PiP owns the real surface. A normal dismiss would animate the whole
    // viewer into the card and hand its decoder away from the floating window.
    if (media !== null && videoPipGate.isHeld(media.id)) {
      this.finishNavigationReturn();
      return;
    }
    const finish: () => void = (): void => {
      const sourceId: string = media !== null && this.motion.source?.mediaId === media.id ? this.motion.source.id : '';
      const ui = this.getUIContext();
      let returned: boolean = false;
      if (media !== null && sourceId.length > 0) {
        ui.animateTo({ duration: 0 }, (): void => {
          returned = videoPlayerHandoff.returnToSource(media.id, sourceId);
          if (returned) { this.motion.handoff(); }
        });
      }
      if (!returned || media === null) {
        if (media !== null) { videoPlayerHandoff.request(media.id); }
        this.finishNavigationReturn();
        return;
      }
      this.returningMediaId = media.id;
      // Let the original live source surface paint before removing the viewer
      // surface. No capture, decoder restart, or buffered-frame probing.
      ui.postFrameCallback(new MediaViewerMotionFrame((): void => {
        if (!this.viewerAlive) { return; }
        ui.postFrameCallback(new MediaViewerMotionFrame((): void => {
          if (this.viewerAlive) { this.finishNavigationReturn(); }
        }));
      }));
    };
    if (!this.motion.enabled()) { finish(); return; }
    const geometry: MediaViewerGeometry | undefined = measureMediaViewerGeometry(this.getUIContext(),
      this.motionSurfaceId, 'video-viewer-frame-' + (media?.id ?? ''), media?.width ?? 0, media?.height ?? 0, false);
    if (geometry === undefined) { finish(); return; }
    const openingSource: MediaViewerSource | undefined = this.motion.source;
    const source: MediaViewerSource | undefined = media !== null && openingSource?.mediaId === media.id ?
      captureMediaViewerSource(this.getUIContext(), openingSource.id, media.id, media.width, media.height,
        openingSource.contain, openingSource.radius) : undefined;
    this.motion.dismiss(this.getUIContext(), source, geometry.viewport, geometry.target, this.reduceMotion, finish);
  }

  private finishNavigationReturn(): void {
    if (!this.returnNavigation.complete()) { ResponsiveLayout.closeContentDestination(this.pageStack, false); }
  }

  aboutToDisappear(): void {
    this.returnNavigation.detach();
    this.stopDanmakuKeyboardObserver();
    ++this.danmakuGeneration;
    this.viewerAlive = false;
    this.closing = true;
    this.recommendationStream.close();
    this.pageShown = false;
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_VIDEO_FEED_ACTIVE, false);
    videoPlayerHandoff.completeReturn(this.returningMediaId);
    this.stopNetworkPolicyMonitoring();
    GripHandManager.getInstance().stopFor(VIDEO_FEED_RAIL_GRIP_KEY);
  }

  // Opening a post from here uses the platform's own page transition.
  private openPost(tweet: Tweet): void {
    const param: PostDetailRouteParam = { tweet: tweet, returnToMain: true };
    this.pageStack.pushPath({ name: 'PostDetail', param: param });
  }

  // The rail avatar in the short-video layout opens the same profile page the
  // timeline uses, so the reader keeps one navigation habit across surfaces.
  private openAuthorProfile(tweet: Tweet): void {
    const param: UserDetailRouteParam = { author: tweet.author, posts: [] };
    this.pageStack.pushPath({ name: 'UserDetail', param: param });
  }

  private openCurrentPost(): void {
    const tweet: Tweet | null = this.currentTweet();
    if (tweet !== null) {
      this.showMoreSheet = false;
      this.openPost(tweet);
    }
  }

  private sheetDimension(resource: Resource): number {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    return this.getUIContext().px2vp(context.resourceManager.getNumber(resource.id));
  }

  private initialPostSheetHeight(): number {
    const height: number = this.windowHeight > 0 ? this.windowHeight : this.videoViewportHeightForLayout(this.current);
    return ResponsiveLayout.mediaSheetHeight(this.windowWidth, height,
      this.sheetDimension($r('app.float.media_viewer_post_sheet_max_height')),
      this.statusBarHeight, this.navigationIndicatorHeight);
  }

  private updateCommentPreview(animated: boolean): void {
    const centered: boolean = sheetUsesCenteredPresentation(this.sheetWindowBreakpoint);
    const viewportHeight: number = this.windowHeight > 0 ? this.windowHeight : this.videoViewportHeightForLayout(this.current);
    const sheetHeight: number = this.postSheetHeight > 0 ? this.postSheetHeight : this.initialPostSheetHeight();
    const height: number = centered ? 0 : Math.max(0, viewportHeight - sheetHeight - this.statusBarHeight -
      this.sheetDimension($r('app.float.media_viewer_post_sheet_gap')));
    const progress: number = this.showPostSheet && !centered ? 1 : 0;
    if (animated) {
      this.getUIContext().animateTo({ duration: motionDuration(280), curve: motionCurve() }, (): void => {
        this.commentPreviewHeight = height;
        this.commentPreviewProgress = progress;
      });
    } else {
      this.commentPreviewHeight = height;
      this.commentPreviewProgress = progress;
    }
  }

  private openPostSheet(tweet: Tweet): void {
    if (this.useSideComments()) { return; }
    if (this.postSheetActive) { return; }
    this.showMoreSheet = false;
    this.postSheetTweet = tweet;
    this.postSheetHeight = this.initialPostSheetHeight();
    this.postSheetOpening = true;
    this.postSheetActive = true;
    this.showPostSheet = true;
    this.updateCommentPreview(true);
    hapticTick();
  }

  private closePostSheet(): void {
    if (!this.showPostSheet) { return; }
    this.postSheetOpening = false;
    this.showPostSheet = false;
    this.updateCommentPreview(true);
  }

  private applyPostSheetChange(post: Tweet): void {
    for (let index: number = 0; index < this.items.length; index++) {
      if (this.items[index].tweet.id === post.id) {
        // Preserve attachment references so updated counts do not reload the player.
        this.items[index].tweet = post;
        if (index === this.current) { this.syncCurrentPostState(); }
      }
    }
    if (this.postSheetTweet !== null && this.postSheetTweet.id === post.id) {
      this.postSheetTweet = post;
    }
  }

  @Builder
  private PostSheet(): void {
    if (this.postSheetTweet !== null) {
      PostDetail({
        embedded: true,
        initialTweet: this.postSheetTweet,
        onEmbeddedPostChanged: (post: Tweet): void => this.applyPostSheetChange(post),
        onEmbeddedNavigate: (): void => this.closePostSheet()
      })
    }
  }

  private onPageChanged(index: number): void {
    this.fullscreenRequest = 0;
    this.episodesExpanded = false;
    this.showDanmakuSheet = false;
    this.fullscreenAdvanceFrom = -1;
    this.preloadActive = false;
    this.holdSpeedActive = false;
    this.current = index;
    const viewed: Tweet | null = this.currentTweet();
    if (viewed !== null) {
      this.recommendationStream.noteViewed(viewed.id, index);
      browsingHistoryStore.record(getContext(this) as common.UIAbilityContext, viewed);
    }
    this.updatePreloadPolicy();
    if (index !== this.initialIndex) {
      this.manualStartPending = false;
    }
    this.syncCurrentPostState();
    this.preloadNextPage();
    if (index >= this.items.length - 3) {
      this.loadMoreVideos();
    }
  }

  private advanceFromFullscreen(): void {
    if (this.closing) { return; }
    if (this.current < this.items.length - 1) {
      this.pager.showNext();
    } else if (!this.videoFeedExhausted) {
      this.fullscreenAdvanceFrom = this.current;
      void this.loadMoreVideos();
    }
  }

  private async updatePreloadPolicy(): Promise<void> {
    const epoch: number = ++this.preloadPolicyEpoch;
    try {
      if (!connection.hasDefaultNetSync()) {
        if (epoch === this.preloadPolicyEpoch) {
          this.preloadAheadCount = 0;
          AppStorage.setOrCreate<number>(STORAGE_KEY_VIDEO_AUTO_BITRATE_CAP, DEFAULT_VIDEO_AUTO_BITRATE_CAP);
        }
        return;
      }
      const netHandle: connection.NetHandle = await connection.getDefaultNet();
      const capabilities: connection.NetCapabilities = await connection.getNetCapabilities(netHandle);
      const measuredDownlinkKbps: number | undefined = capabilities.linkDownBandwidthKbps;
      const downlinkKbps: number = measuredDownlinkKbps === undefined ? 0 : measuredDownlinkKbps;
      let cellular: boolean = false;
      for (let i: number = 0; i < capabilities.bearerTypes.length; i++) {
        if (capabilities.bearerTypes[i] === connection.NetBearType.BEARER_CELLULAR) {
          cellular = true;
          break;
        }
      }
      let nextCount: number = 1;
      if (downlinkKbps > 0 && downlinkKbps < 1600) {
        nextCount = 0;
      }
      if (epoch === this.preloadPolicyEpoch) {
        this.preloadAheadCount = nextCount;
        let nextBitrateCap: number = DEFAULT_VIDEO_AUTO_BITRATE_CAP;
        if (downlinkKbps > 0 && downlinkKbps < 1600) {
          nextBitrateCap = 600000;
        } else if (downlinkKbps >= 1600 && downlinkKbps < 4500) {
          nextBitrateCap = 1200000;
        } else if (downlinkKbps >= 4500 && downlinkKbps < 10000) {
          nextBitrateCap = cellular ? 1800000 : 2500000;
        } else if (downlinkKbps >= 10000) {
          nextBitrateCap = cellular ? 2500000 : 4500000;
        }
        AppStorage.setOrCreate<number>(STORAGE_KEY_VIDEO_AUTO_BITRATE_CAP, nextBitrateCap);
        this.preloadNextPage();
      }
    } catch (error) {
      if (epoch === this.preloadPolicyEpoch) {
        this.preloadAheadCount = 0;
        AppStorage.setOrCreate<number>(STORAGE_KEY_VIDEO_AUTO_BITRATE_CAP, DEFAULT_VIDEO_AUTO_BITRATE_CAP);
      }
    }
  }

  private startNetworkPolicyMonitoring(): void {
    if (this.networkPolicyConnection !== null) {
      return;
    }
    try {
      const netConnection: connection.NetConnection = connection.createNetConnection();
      this.networkPolicyConnection = netConnection;
      netConnection.on('netAvailable', (netHandle: connection.NetHandle): void => {
        if (this.networkPolicyConnection === netConnection) {
          this.updatePreloadPolicy();
        }
      });
      netConnection.on('netLost', (netHandle: connection.NetHandle): void => {
        if (this.networkPolicyConnection === netConnection) {
          this.updatePreloadPolicy();
        }
      });
      netConnection.on('netUnavailable', (): void => {
        if (this.networkPolicyConnection === netConnection) {
          this.updatePreloadPolicy();
        }
      });
      netConnection.on('netCapabilitiesChange', (info: connection.NetCapabilityInfo): void => {
        if (this.networkPolicyConnection === netConnection) {
          this.updatePreloadPolicy();
        }
      });
      netConnection.register((error: BusinessError): void => {
        if (error !== undefined && error !== null && this.networkPolicyConnection === netConnection) {
          this.networkPolicyConnection = null;
        }
      });
      this.updatePreloadPolicy();
    } catch (error) {
      this.stopNetworkPolicyMonitoring();
    }
  }

  private stopNetworkPolicyMonitoring(): void {
    this.preloadPolicyEpoch += 1;
    const netConnection: connection.NetConnection | null = this.networkPolicyConnection;
    this.networkPolicyConnection = null;
    if (netConnection === null) {
      return;
    }
    try {
      netConnection.unregister((error: BusinessError): void => {
        if (error !== undefined && error !== null) {
          return;
        }
      });
    } catch (error) {
      // The system may already have dropped this listener while its network changed.
    }
  }

  private preloadMediaIdForItem(item: VideoFeedItem): string {
    if (!this.pageShown || !this.preloadActive || item.index <= this.current ||
      item.index > this.current + this.preloadAheadCount || item.attachments.length === 0) {
      return '';
    }
    const media: MediaAttachment = item.attachments[0];
    if (media.sensitive === true && !this.showSensitiveMedia) {
      return '';
    }
    return media.id;
  }

  private shouldRetainVideoPlayer(item: VideoFeedItem): boolean {
    return this.pageShown && Math.abs(item.index - this.current) <= 1;
  }

  private async preloadNextPage(): Promise<void> {
    const next: number = this.current + 1;
    if (!this.pagerShown || !this.pageShown || this.closing || this.preloadAheadCount <= 0 ||
      next >= this.items.length) {
      return;
    }
    try {
      // Mount the next cached cell immediately, rather than waiting for an idle frame.
      await this.pager.preloadItems([next]);
    } catch (error) {
      // Navigation or a removed recommendation can invalidate an in-flight index.
    }
  }

  private feedItem(item: VideoFeedItem): VideoFeedItem {
    // LocalBuilder belongs to this viewer. Read its state here instead of relying
    // on a child ObjectLink passed by value to refresh post details and indices.
    return this.items[item.index] ?? item;
  }

  private onCurrentVideoPlaybackChanged(index: number, playing: boolean): void {
    if (index !== this.current) {
      return;
    }
    this.preloadActive = playing;
    if (playing) {
      this.updatePreloadPolicy();
    }
  }

  // A hold belongs to the page that started it: a swipe during the press must
  // not leave the capsule on the incoming video.
  private setHoldSpeedState(index: number, active: boolean, rate: number): void {
    if (active && index !== this.current) {
      return;
    }
    if (this.holdSpeedActive === active) {
      this.holdSpeedRate = rate;
      return;
    }
    this.holdSpeedRate = rate;
    this.getUIContext().animateTo({ duration: motionDuration(active ? 170 : 140), curve: Curve.EaseOut }, (): void => {
      this.holdSpeedActive = active;
    });
  }

  private async loadMoreVideos(): Promise<void> {
    if (this.loadingMoreVideos || this.videoFeedExhausted) {
      return;
    }
    this.loadingMoreVideos = true;
    this.recommendationRetryNeeded = false;
    let addedVideos: number = 0;
    try {
      // The ranked timeline can contain several non-video posts between two
      // videos. Keep asking until this batch produces at least one new cell.
      for (let attempt: number = 0; attempt < 5; attempt++) {
        const page: VideoFeedPage = await this.loadMoreAction();
        if (this.closing) { break; }
        const added: number = this.appendVideoPage(page.tweets);
        addedVideos += added;
        if (!page.hasMore) {
          this.videoFeedExhausted = true;
          break;
        }
        if (added > 0) {
          break;
        }
      }
    } catch (error) {
      // Keep the existing cursor retryable when the network is transient.
      this.recommendationRetryNeeded = !this.closing;
    }
    if (!this.closing && !this.videoFeedExhausted && addedVideos === 0) {
      this.recommendationRetryNeeded = true;
    }
    this.loadingMoreVideos = false;
    const advance: boolean = this.fullscreenAdvanceFrom === this.current &&
      !this.closing && this.current < this.items.length - 1;
    this.fullscreenAdvanceFrom = -1;
    if (advance) { this.pager.showNext(); }
  }

  private async loadRecommendedVideos(): Promise<VideoFeedPage> {
    const page: VideoRecommendationPage = this.profileStream === null ?
      await this.recommendationStream.nextPage() : await this.profileStream.nextPage();
    if (this.closing) { return { tweets: [], hasMore: false }; }
    if (page.error.length > 0) {
      promptAction.showToast({ message: this.text($r('app.string.video_recommendations_failed')) + ' · ' + page.error });
      throw new Error(page.error);
    }
    return { tweets: page.tweets, hasMore: page.hasMore };
  }

  private appendVideoPage(tweets: Tweet[]): number {
    const added: VideoFeedItem[] = [];
    const batchIds: Set<string> = new Set<string>();
    for (const tweet of tweets) {
      if (postModerationStore.hidden(tweet) || this.filterHideAds && isAdPost(tweet.presentation)) { continue; }
      for (const media of this.videoAttachments(tweet)) {
        if (this.items.some((item: VideoFeedItem): boolean =>
          item.attachments.some((existing: MediaAttachment): boolean => existing.id === media.id)) ||
          batchIds.has(media.id)) { continue; }
        batchIds.add(media.id);
        added.push(new VideoFeedItem(tweet, [media], this.items.length + added.length));
      }
    }
    if (added.length > 0) {
      this.items.push(...added);
      this.videoDataSource.append(added);
      this.preloadNextPage();
    }
    return added.length;
  }

  private onVideoCompleted(index: number): void {
    if (!this.pageShown || this.closing || this.postSheetActive || !this.autoAdvance || index !== this.current) {
      return;
    }
    if (this.videoFeedLayout === VIDEO_FEED_LAYOUT_BILIBILI) {
      const tweet: Tweet | null = this.currentTweet();
      if (tweet !== null) {
        const videos: MediaAttachment[] = this.episodeVideos(tweet);
        const next: number = VideoDanmaku.episodeIndex(videos, this.currentVideo()?.id ?? '') + 1;
        if (next < videos.length) { this.selectEpisode(tweet, next); return; }
      }
    }
    if (this.current >= this.items.length - 1) { return; }
    this.pager.showNext();
  }

  private async toggleFollow(tweet: Tweet): Promise<void> {
    if (this.authorFollowPending || this.isOwnPost(tweet)) {
      return;
    }
    if (!xPrivateClient.isSignedIn()) {
      promptAction.showToast({
        message: this.text($r('app.string.profile_follow_sign_in')),
        duration: 2000
      });
      return;
    }
    const userId: string = this.authorUserId.length > 0 ? this.authorUserId : tweet.author.id;
    if (userId.length === 0) {
      return;
    }
    const next: boolean = !this.authorFollowing;
    this.authorFollowPending = true;
    const result: XPrivateResult = await xPrivateClient.follow(userId, next);
    this.authorFollowPending = false;
    if (!result.ok) {
      promptAction.showToast({
        message: this.text($r('app.string.profile_follow_failed')) + ' · HTTP ' + result.status,
        duration: 2200
      });
      return;
    }
    this.authorFollowing = next;
    hapticTick();
  }

  private syncLikeState(): void {
    const post: Tweet | null = this.currentTweet();
    if (post === null) { return; }
    postLikeStore.apply(post);
    this.liked = post.liked;
    this.likeCount = post.metrics.likeCount;
  }

  private async toggleLike(tweet: Tweet): Promise<void> {
    if (this.likePending || postLikeStore.isPending(tweet.id)) {
      return;
    }
    const next: boolean = !this.liked;
    this.likePending = true;
    const completion: Promise<boolean> = postLikeStore.setLike(tweet, next,
      (): Promise<boolean> => this.likeAction(tweet, next));
    this.syncLikeState();
    hapticTick();
    try {
      await completion;
    } finally {
      this.likePending = false;
      this.syncLikeState();
    }
  }

  private applyRepost(tweet: Tweet, next: boolean): void {
    this.reposted = next;
    tweet.reposted = next;
    if (next) {
      tweet.metrics.repostCount += 1;
    } else if (tweet.metrics.repostCount > 0) {
      tweet.metrics.repostCount -= 1;
    }
  }

  private async toggleRepost(tweet: Tweet): Promise<void> {
    if (this.repostPending) {
      return;
    }
    const next: boolean = !this.reposted;
    this.repostPending = true;
    this.applyRepost(tweet, next);
    hapticTick();
    let ok: boolean = false;
    try {
      ok = await this.repostAction(tweet, next);
    } catch (error) {
      ok = false;
    }
    if (!ok) {
      this.applyRepost(tweet, !next);
    }
    this.repostPending = false;
  }

  private async toggleBookmark(tweet: Tweet): Promise<void> {
    if (this.bookmarkPending) {
      return;
    }
    if (!xPrivateClient.isSignedIn()) {
      promptAction.showToast({
        message: this.text($r('app.string.bookmarks_sign_in')),
        duration: 2000
      });
      return;
    }
    const next: boolean = !this.bookmarked;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const account: string = offlineReadingStore.account(context);
    this.bookmarked = next;
    tweet.bookmarked = next;
    this.bookmarkPending = true;
    hapticTick();
    const result: XPrivateResult = await xPrivateClient.bookmark(tweet.id, next);
    this.bookmarkPending = false;
    if (account !== offlineReadingStore.account(context)) { return; }
    if (!result.ok) {
      this.bookmarked = !next;
      tweet.bookmarked = !next;
      promptAction.showToast({
        message: this.text($r('app.string.action_bookmark')) + ' · HTTP ' + result.status,
        duration: 2200
      });
      return;
    }
    const message: Resource = next ? $r('app.string.toast_bookmark_added') :
      $r('app.string.toast_bookmark_removed');
    promptAction.showToast({ message: this.text(message), duration: 1500 });
    if (next) {
      const saved: OfflineSaveResult = await offlineReadingStore.capture(context, tweet, account);
      if (account === offlineReadingStore.account(context) && (!saved.ok || !saved.complete)) {
        promptAction.showToast({ message: this.text(saved.ok ? $r('app.string.offline_partial_saved') : $r('app.string.offline_save_failed')), duration: 2500 });
      }
    }
  }

  private share(tweet: Tweet): void {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    sharePost(context, tweet);
  }

  private async dismissCurrent(): Promise<void> {
    const tweet: Tweet | null = this.currentTweet();
    if (tweet === null) {
      return;
    }
    this.showMoreSheet = false;
    const generation: number = xPrivateClient.sessionGeneration();
    const action = (tweet.feedbackActions ?? []).find((feedback): boolean => {
      const kind: string = feedback.type.toLowerCase();
      return kind === 'dontlike' || kind === 'notinterested' || kind === 'not_interested';
    });
    let submitted: boolean = false;
    if (action !== undefined && action.url.length > 0) {
      try {
        const result: XPrivateResult = await xPrivateClient.timelineFeedback(action.url, action.type);
        if (generation !== xPrivateClient.sessionGeneration() || this.closing) { return; }
        if (!result.ok) {
          promptAction.showToast({ message: this.text($r('app.string.profile_setting_failed')) + ' · HTTP ' + result.status.toString() });
          return;
        }
        submitted = true;
      } catch (error) {
        promptAction.showToast({ message: this.text($r('app.string.profile_setting_failed')) });
        return;
      }
    }
    if (!postModerationStore.hide(getContext(this) as common.UIAbilityContext, tweet.id)) {
      promptAction.showToast({ message: this.text($r('app.string.timeline_save_failed')) });
      return;
    }
    if (this.currentTweet()?.id !== tweet.id || this.closing) { return; }
    // A profile post can own several consecutive video cells.
    for (let index: number = this.items.length - 1; index >= 0; index--) {
      if (this.items[index].tweet.id === tweet.id) {
        this.items.splice(index, 1);
        this.videoDataSource.remove(index);
      }
    }
    this.showMoreSheet = false;
    this.videoViewportHeights = [];
    this.videoChromeVisible = [];
    this.current = this.clampIndex(this.current, this.items.length);
    this.preloadNextPage();
    promptAction.showToast({
      message: this.text(submitted ? $r('app.string.post_menu_feedback_sent') : $r('app.string.post_menu_hidden_local')),
      duration: 1600
    });
    if (this.items.length === 0) {
      this.close();
      return;
    }
    const target: number = this.current;
    this.current = target;
    this.syncCurrentPostState();
    setTimeout((): void => {
      this.pager.changeIndex(target, false);
    }, 0);
  }

  private menuVisible(id: string): boolean {
    return menuActionVisible(this.hiddenMenuActions, id);
  }

  private setCaptionsEnabled(enabled: boolean): void {
    if (mediaSettingsStore.saveVideoCaptionsEnabled(getContext(this) as common.UIAbilityContext, enabled)) { hapticTick(); }
    else { promptAction.showToast({ message: $r('app.string.settings_interaction_save_failed') }); }
  }

  private toggleCaptions(): void {
    this.setCaptionsEnabled(!this.captionsEnabled);
  }

  private setCaptionOpacity(opacity: number): void {
    const previous: number = this.captionOpacity;
    this.captionOpacity = opacity;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    if (!mediaSettingsStore.saveCaptionOpacity(context, opacity)) {
      this.captionOpacity = previous;
      return;
    }
    hapticTick();
  }

  private toggleAutoAdvance(): void {
    if (mediaSettingsStore.saveVideoAutoAdvance(getContext(this) as common.UIAbilityContext, !this.autoAdvance)) { hapticTick(); }
    else { promptAction.showToast({ message: $r('app.string.settings_interaction_save_failed') }); }
  }

  private toggleQualityOptions(): void {
    this.qualityExpanded = !this.qualityExpanded;
    hapticTick();
  }

  private setVideoQuality(value: number): void {
    const previous: number = this.videoQuality;
    this.videoQuality = value;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    if (!mediaSettingsStore.saveVideoQuality(context, value)) {
      this.videoQuality = previous;
      return;
    }
    hapticTick();
  }

  private toggleVideoImmersiveFill(): void {
    const previous: boolean = this.videoImmersiveFill;
    const next: boolean = !this.videoImmersiveFill;
    this.videoImmersiveFill = next;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    if (!mediaSettingsStore.saveVideoImmersiveFill(context, next)) {
      this.videoImmersiveFill = previous;
      return;
    }
    hapticTick();
  }

  private setVideoFeedControlsAlwaysVisible(enabled: boolean): void {
    const previous: boolean = this.videoFeedControlsAlwaysVisible;
    this.videoFeedControlsAlwaysVisible = enabled;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    if (!mediaSettingsStore.saveVideoFeedControlsAlwaysVisible(context, enabled)) {
      this.videoFeedControlsAlwaysVisible = previous;
      return;
    }
    hapticTick();
  }

  private setCompactVideoLayout(layout: number): void {
    if (layout === this.compactVideoLayout) { return; }
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    if (mediaSettingsStore.saveCompactVideoLayout(context, layout)) {
      hapticTick();
    } else {
      promptAction.showToast({ message: this.text($r('app.string.settings_layout_save_failed')) });
    }
  }

  private setVideoFeedLayout(layout: number): void {
    if (this.videoFeedLayout === layout) {
      return;
    }
    const previous: number = this.videoFeedLayout;
    this.videoFeedLayout = layout;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    if (!mediaSettingsStore.saveVideoFeedLayout(context, layout)) {
      this.videoFeedLayout = previous;
      return;
    }
    // Only the short-video layout follows the holding hand.
    this.initializeRailGripHand();
    if (layout === VIDEO_FEED_LAYOUT_BILIBILI) {
      const tweet: Tweet | null = this.currentTweet();
      if (tweet !== null) { void this.loadDanmaku(tweet); }
    }
    hapticTick();
  }

  private toggleVideoFeedTapPause(): void {
    if (mediaSettingsStore.saveVideoFeedTapPause(getContext(this) as common.UIAbilityContext, !this.videoFeedTapPause)) {
      hapticTick();
    }
  }

  // The short-video layout only owns the phone-portrait feed; wide windows keep
  // the post in their own pane, so the switch stays hidden there.
  private layoutSwitchAvailable(): boolean {
    return !this.isWideLandscape() && !this.useSideComments();
  }

  // ---- Grip posture --------------------------------------------------------
  // The action rail follows the holding hand the same way the floating compose
  // button and the post-detail reply capsule do, so the thumb reaches it.

  private railGripAdaptationNeeded(): boolean {
    return this.gripHandEnabled && this.componentGripEnabled && this.layoutSwitchAvailable() &&
      this.usesShortVideoLayout();
  }

  private railOnLeadingSide(): boolean {
    return this.railHand === 'left';
  }

  private railShiftForHand(hand: string): number {
    if (hand === 'left') {
      return 0;
    }
    const viewport: number = this.windowWidth > 0 ? this.windowWidth : 0;
    return Math.max(0, viewport - VIDEO_FEED_RAIL_WIDTH - VIDEO_FEED_RAIL_SIDE_MARGIN * 2);
  }

  // An alignment swap cannot be tweened, so the rail keeps its leading-edge
  // layout and slides through a translation while the caption insets animate.
  private applyRailHand(hand: string, animated: boolean): void {
    this.railHand = hand;
    const shift: number = this.railShiftForHand(hand);
    const leading: number = hand === 'left' ? VIDEO_FEED_RAIL_RESERVED_WIDTH : VIDEO_FEED_CAPTION_INSET;
    const trailing: number = hand === 'left' ? VIDEO_FEED_CAPTION_INSET : VIDEO_FEED_RAIL_RESERVED_WIDTH;
    if (!animated) {
      this.railShiftX = shift;
      this.captionLeadingInset = leading;
      this.captionTrailingInset = trailing;
      return;
    }
    this.getUIContext().animateTo({
      duration: motionDuration(VIDEO_FEED_RAIL_SWITCH_DURATION_MS),
      curve: motionCurve()
    }, (): void => {
      this.railShiftX = shift;
      this.captionLeadingInset = leading;
      this.captionTrailingInset = trailing;
    });
  }

  private async initializeRailGripHand(): Promise<void> {
    const context: common.Context | undefined = this.getUIContext().getHostContext();
    if (context !== undefined) {
      await GripHandManager.getInstance().load(context);
      this.gripHandEnabled = GripHandManager.getInstance().isGripHandEnabled();
      this.preferredHand = GripHandManager.getInstance().getPreferredHand();
    }
    this.railHand = this.componentGripEnabled ? GripHandManager.getInstance().getLastHand() : this.preferredHand;
    this.applyRailHand(this.railHand, false);
    if (this.railGripAdaptationNeeded()) {
      GripHandManager.getInstance().startFor(VIDEO_FEED_RAIL_GRIP_KEY, (hand: string): void => {
        this.onRailGripHandChanged(hand);
      });
      return;
    }
    GripHandManager.getInstance().stopFor(VIDEO_FEED_RAIL_GRIP_KEY);
  }

  private onGripHandEnabledChanged(): void {
    if ((!this.gripHandEnabled || !this.componentGripEnabled)) {
      GripHandManager.getInstance().stopFor(VIDEO_FEED_RAIL_GRIP_KEY);
      this.applyRailHand(this.preferredHand, true);
      return;
    }
    this.initializeRailGripHand();
  }

  private onPreferredHandChanged(): void {
    if ((!this.gripHandEnabled || !this.componentGripEnabled)) {
      this.applyRailHand(this.preferredHand, true);
    }
  }

  private onRailGripHandChanged(hand: string): void {
    if (!this.railGripAdaptationNeeded()) { return; }
    this.applyRailHand(hand, true);
  }

  private async downloadCurrentVideo(): Promise<void> {
    const media: MediaAttachment | null = this.currentVideo();
    if (media === null || this.downloading || this.choosingDownloadQuality) {
      return;
    }
    this.showMoreSheet = false;
    this.choosingDownloadQuality = true;
    let source: string = '';
    try {
      source = await chooseVideoDownloadUrl(this.getUIContext(), media);
    } finally {
      this.choosingDownloadQuality = false;
    }
    if (source.length === 0 || this.closing) {
      return;
    }
    this.downloading = true;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    mediaDownloadService.download(context, source, media.id, true, (result: number): void => {
      this.downloading = false;
      if (result === MEDIA_DOWNLOAD_SUCCESS) {
        return;
      } else if (result === MEDIA_DOWNLOAD_CANCELED) {
        promptAction.showToast({ message: this.text($r('app.string.media_download_canceled')), duration: 1800 });
      } else {
        promptAction.showToast({ message: this.text($r('app.string.media_download_failed')), duration: 2400 });
      }
    });
  }

  private async addCurrentVideoOffline(): Promise<void> {
    const media: MediaAttachment | null = this.currentVideo();
    const tweet: Tweet | null = this.currentTweet();
    if (media === null || tweet === null || this.downloading || this.choosingDownloadQuality) {
      return;
    }
    this.showMoreSheet = false;
    this.choosingDownloadQuality = true;
    let source: string = '';
    try {
      source = await chooseVideoDownloadUrl(this.getUIContext(), media);
    } finally {
      this.choosingDownloadQuality = false;
    }
    if (source.length === 0 || this.closing) {
      return;
    }
    this.downloading = true;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    try {
      const status: OfflineVideoSaveStatus = await offlineVideoStore.save(context, tweet, media, source);
      if (status === OfflineVideoSaveStatus.SAVED) {
        promptAction.showToast({ message: this.text($r('app.string.offline_videos_added')), duration: 1800 });
      } else if (status === OfflineVideoSaveStatus.ALREADY_SAVED) {
        promptAction.showToast({ message: this.text($r('app.string.offline_videos_already')), duration: 1800 });
      } else if (status === OfflineVideoSaveStatus.FAILED) {
        promptAction.showToast({ message: this.text($r('app.string.media_download_failed')), duration: 1800 });
      }
    } catch (error) {
      promptAction.showToast({ message: this.text($r('app.string.media_download_failed')), duration: 1800 });
    } finally {
      this.downloading = false;
    }
  }

  private reportCurrentPost(): void {
    const tweet: Tweet | null = this.currentTweet();
    if (tweet === null) {
      return;
    }
    this.showMoreSheet = false;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    promptAction.showToast({
      message: this.text($r('app.string.video_feed_report_handoff')),
      duration: 1800
    });
    openExternalLink(context, postShareUrl(tweet));
  }

  private text(resource: Resource): string {
    return getContext(this).resourceManager.getStringSync(resource);
  }

  private nativeViewerMenus(): HdsNavigationMenuItemOptions[] {
    const entries: HdsNavigationMenuItemOptions[] = [];
    if (this.videoDownloadButton) {
      entries.push({ content: { icon: $r('sys.symbol.download'), label: $r('app.string.media_download'),
        isEnabled: !this.downloading && !this.choosingDownloadQuality,
        action: (): void => { void this.downloadCurrentVideo(); } } });
    }
    entries.push({ content: { icon: $r('sys.symbol.rectangle_portrait_rotate'), label: $r('app.string.video_rotate'),
      action: (): void => { void this.toggleVideoOrientation(); } } });
    entries.push({ content: { icon: $r('sys.symbol.more'), label: $r('app.string.video_feed_more'),
      action: (): void => { this.showMoreSheet = true; } } });
    return entries;
  }

  private async openSourceVideo(postId: string): Promise<void> {
    if (postId.length === 0 || this.openingSourceVideo || this.closing) { return; }
    this.openingSourceVideo = true;
    const mediaId: string = this.currentVideo()?.id ?? '';
    const generation: number = xPrivateClient.sessionGeneration();
    try {
      const result: XPrivateResult = await xPrivateClient.tweetDetail(postId);
      if (this.closing || !this.pageShown || this.currentVideo()?.id !== mediaId ||
        generation !== xPrivateClient.sessionGeneration()) { return; }
      const page: TweetDetailPage | null = result.ok ? XTimelineParser.parseTweetDetail(result.body, postId) : null;
      const post: Tweet | null = page?.focal ?? null;
      if (post === null) { throw new Error('source_video_unavailable'); }
      const media: MediaAttachment | undefined = post.attachments?.find((item: MediaAttachment): boolean => item.id === mediaId) ??
        post.attachments?.find((item: MediaAttachment): boolean => item.type === 'video' && item.mediaUrl.length > 0);
      if (media === undefined) { throw new Error('source_video_unavailable'); }
      const param: VideoFeedRouteParam = {
        tweets: [post], index: 0, startPlaying: true, startMediaId: media.id,
        onLike: this.likeAction, onRepost: this.repostAction,
        onReply: (target: Tweet): void => this.openPostSheet(target)
      };
      this.pageStack.pushPath({ name: 'VideoFeedViewer', param: param });
    } catch (error) {
      if (!this.closing && this.pageShown) {
        promptAction.showToast({ message: this.text($r('app.string.video_source_open_failed')) });
      }
    } finally { this.openingSourceVideo = false; }
  }

  @Builder
  private SourceAttribution(tweet: Tweet): void {
    if (this.currentVideo() !== null) {
      VideoSourceAttribution({ media: this.currentVideo() as MediaAttachment, postId: tweet.id,
        onOpen: (postId: string): void => { void this.openSourceVideo(postId); } })
    }
  }

  @Builder
  private AuthorLine(tweet: Tweet): void {
    Row({ space: 10 }) {
      ProxyAvatar({
        url: tweet.author.avatarUrl ?? '',
        avatarSize: 42,
        radius: 21,
        verifiedType: tweet.author.verifiedType ?? '',
        avatarShape: tweet.author.avatarShape ?? '',
        fallbackText: tweet.author.name.substring(0, 1).toUpperCase(),
        fallbackColor: tweet.author.avatarColor
      }).onClick((): void => this.openAuthorProfile(tweet))
      PostAdLabel({ presentation: tweet.presentation })
      Column({ space: 1 }) {
        Row({ space: 4 }) {
          Text(tweet.author.name).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_L'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_on_brand'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (tweet.author.verified) {
            SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
              .fontSize(16)
              .fontColor([verificationBadgeColor(tweet.author.verifiedType ?? '', this.accentColor)])
          }
        }
        Text('@' + tweet.author.username).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M'))
          .fontColor('#CCFFFFFF')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .onClick((): void => this.openAuthorProfile(tweet))

      if (!this.isOwnPost(tweet)) {
        MaterialButton({
          buttonWidth: this.authorFollowing ? 90 : 72,
          buttonHeight: 38,
          buttonRadius: 19,
          surfaceColor: '#66000000',
          materialLevel: 1,
          applyShadow: true,
          lightColor: this.accentColor,
          buttonEnabled: !this.authorFollowPending,
          buttonPressFeedback: this.usesBiliLayout(),
          buttonOpacity: this.authorFollowPending ? 0.6 : 1,
          accessibilityLabel: this.text(this.authorFollowing ?
            $r('app.string.profile_detail_following') : $r('app.string.profile_detail_follow')),
          buttonMonopolizeEvents: true,
          onButtonClick: (): void => {
            this.toggleFollow(tweet);
          }
        }) {
          Text(this.authorFollowing ? $r('app.string.profile_detail_following') :
            $r('app.string.profile_detail_follow')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_on_brand'))
            .maxLines(1)
            .maxFontScale(1.15)
        }
      }
    }
    .width('100%')
  }

  @Builder
  private PostActions(tweet: Tweet): void {
    Row() {
      MaterialButton({
        buttonWidth: 64,
        buttonHeight: 42,
        buttonRadius: 21,
        surfaceColor: '#66000000',
        materialLevel: 1,
        applyShadow: true,
        lightColor: this.accentColor,
        accessibilityLabel: this.text($r('app.string.action_reply')),
        buttonMonopolizeEvents: true,
        onButtonClick: (): void => this.openPostSheet(tweet)
      }) {
        Row({ space: 5 }) {
          SymbolGlyph($r('sys.symbol.ellipsis_bubble'))
            .fontSize(19)
            .fontColor([$r('app.color.text_on_brand')])
          Text(formatCount(tweet.metrics.replyCount)).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('app.color.text_on_brand'))
            .maxFontScale(1)
        }
      }
      MaterialButton({
        buttonWidth: 68,
        buttonHeight: 42,
        buttonRadius: 21,
        surfaceColor: '#66000000',
        materialLevel: 1,
        applyShadow: true,
        lightColor: $r('app.color.repost'),
        buttonEnabled: !this.repostPending,
        buttonOpacity: this.repostPending ? 0.6 : 1,
        accessibilityLabel: this.text($r('app.string.action_repost')),
        buttonMonopolizeEvents: true,
        onButtonClick: (): void => {
          this.toggleRepost(tweet);
        }
      }) {
        Row({ space: 5 }) {
          SymbolGlyph($r('sys.symbol.repeat'))
            .fontSize(19)
            .fontColor([this.reposted ? $r('app.color.repost') : $r('app.color.text_on_brand')])
          Text(formatCount(tweet.metrics.repostCount)).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M'))
            .fontColor(this.reposted ? $r('app.color.repost') : $r('app.color.text_on_brand'))
            .maxFontScale(1)
        }
      }
      MaterialButton({
        buttonWidth: 68,
        buttonHeight: 42,
        buttonRadius: 21,
        surfaceColor: '#66000000',
        materialLevel: 1,
        applyShadow: true,
        lightColor: $r('app.color.like'),
        buttonEnabled: !this.likePending,
        buttonOpacity: this.likePending ? 0.6 : 1,
        accessibilityLabel: this.text($r('app.string.action_like')),
        buttonMonopolizeEvents: true,
        onButtonClick: (): void => {
          this.toggleLike(tweet);
        }
      }) {
        Row({ space: 5 }) {
          SymbolGlyph(this.liked ? $r('sys.symbol.heart_fill') : $r('sys.symbol.heart'))
            .fontSize(19)
            .fontColor([this.liked ? $r('app.color.like') : $r('app.color.text_on_brand')])
          Text(formatCount(this.likeCount)).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M'))
            .fontColor(this.liked ? $r('app.color.like') : $r('app.color.text_on_brand'))
            .maxFontScale(1)
        }
      }
      MaterialButton({
        buttonWidth: 42,
        buttonHeight: 42,
        buttonRadius: 21,
        surfaceColor: '#66000000',
        materialLevel: 1,
        applyShadow: true,
        lightColor: this.accentColor,
        buttonEnabled: !this.bookmarkPending,
        buttonOpacity: this.bookmarkPending ? 0.6 : 1,
        accessibilityLabel: this.text($r('app.string.action_bookmark')),
        buttonMonopolizeEvents: true,
        onButtonClick: (): void => {
          this.toggleBookmark(tweet);
        }
      }) {
        SymbolGlyph(this.bookmarked ? $r('sys.symbol.bookmark_fill') : $r('sys.symbol.bookmark'))
          .fontSize(20)
          .fontColor([this.bookmarked ? this.accentColor : $r('app.color.text_on_brand')])
      }
      MaterialButton({
        buttonWidth: 42,
        buttonHeight: 42,
        buttonRadius: 21,
        surfaceColor: '#66000000',
        materialLevel: 1,
        applyShadow: true,
        lightColor: this.accentColor,
        accessibilityLabel: this.text($r('app.string.action_share')),
        buttonMonopolizeEvents: true,
        onButtonClick: (): void => this.share(tweet)
      }) {
        SymbolGlyph($r('sys.symbol.share'))
          .fontSize(20)
          .fontColor([$r('app.color.text_on_brand')])
      }
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceBetween)
  }

  @Builder
  private MoreMenuRow(symbol: Resource, title: Resource, detail: string, action: () => void): void {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: 18 }) {
        SymbolGlyph(symbol)
          .fontSize(28)
          .fontColor([$r('app.color.text_secondary')])
          .width(32)
        Column({ space: 2 }) {
          Text(title).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_L'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
          if (detail.length > 0) {
            Text(detail).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_M'))
              .fontColor($r('app.color.text_secondary'))
              .maxLines(1)
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .height(64)
    }
    .width('100%')
    .height(64)
    .padding({ left: 20, right: 20 })
    .backgroundColor(Color.Transparent)
    .accessibilityText(this.text(title))
    .onClick(action)
  }

  private videoQualityLabel(): string {
    if (this.videoQuality === VIDEO_QUALITY_HIGH) {
      return this.text($r('app.string.settings_quality_hd'));
    }
    if (this.videoQuality === VIDEO_QUALITY_SD) {
      return this.text($r('app.string.settings_quality_sd'));
    }
    if (this.videoQuality === VIDEO_QUALITY_LD) {
      return this.text($r('app.string.settings_quality_ld'));
    }
    return this.text($r('app.string.settings_quality_auto'));
  }

  @Builder
  private QualityChoiceRow(value: number, title: Resource): void {
    Row({ space: 14 }) {
      Text(title).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_L'))
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
      if (this.videoQuality === value) {
        SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
          .fontSize(22)
          .fontColor([this.accentColor])
      }
    }
    .width('100%')
    .height(54)
    .padding({ left: 70, right: 20 })
    .onClick((): void => {
      this.setVideoQuality(value);
    })
  }

  @Builder
  private MoreSectionHeader(symbol: Resource, title: Resource): void {
    Row({ space: 18 }) {
      SymbolGlyph(symbol)
        .fontSize(28)
        .fontColor([$r('app.color.text_secondary')])
        .width(32)
      Text(title).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_L'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .maxLines(1)
        .layoutWeight(1)
    }
    .width('100%')
    .height(52)
    .padding({ left: 20, right: 20 })
    .accessibilityText(this.text(title))
  }

  @Builder
  private LayoutChoiceRow(value: number, title: Resource, compact: boolean = false): void {
    Row({ space: 14 }) {
      Text(title).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_L'))
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
      if ((compact ? this.compactVideoLayout : this.videoFeedLayout) === value) {
        SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
          .fontSize(22)
          .fontColor([this.accentColor])
      }
    }
    .width('100%')
    .height(54)
    .padding({ left: 70, right: 20 })
    .accessibilityText(this.text(title))
    .onClick((): void => {
      if (compact) { this.setCompactVideoLayout(value); }
      else { this.setVideoFeedLayout(value); }
    })
  }

  @Builder
  private MoreSheet(): void {
    Scroll() {
      Column() {
        if (menuActionsForGroup('video_menu')
          .every((option: MenuActionOption): boolean => !this.menuVisible(option.id))) {
          Text($r('app.string.settings_menu_empty')).fontFamily(this.appFontFamily)
            .fontColor($r('app.color.text_secondary')).padding(20)
        }
        ForEach([this.moreSheetRevision() + '-lead'], (revision: string) => {
          Column() {
            if (this.menuVisible('video.not_interested')) {
              this.MoreMenuRow($r('sys.symbol.face_sading'), $r('app.string.video_feed_not_interested'), '',
                (): void => {
                  void this.dismissCurrent();
                })
            }
            if (this.menuVisible('video.cast')) {
              this.MoreMenuRow($r('sys.symbol.display'), $r('app.string.video_feed_cast'),
                this.castingMediaId.length > 0 ? this.text($r('app.string.video_cast_active')) : '',
                (): void => this.requestVideoCast())
            }
            if (this.menuVisible('video.captions')) {
              this.MoreMenuRow($r('sys.symbol.AI_subtitles'), $r('app.string.video_feed_subtitles'),
                this.text(this.captionsEnabled ? $r('app.string.video_feed_subtitles_on') :
                  $r('app.string.video_feed_subtitles_off')), (): void => {
                  this.toggleCaptions();
                })
            }
          }
          .width('100%')
        }, (revision: string): string => revision)
        if (this.menuVisible('video.caption_opacity')) {
          this.CaptionOpacityRow()
        }
        ForEach([this.moreSheetRevision() + '-tail'], (revision: string) => {
          Column() {
            if (this.compactWindow() && this.menuVisible('video.layout')) {
              this.MoreSectionHeader($r('sys.symbol.rectangle_split_2x1'), $r('app.string.compact_video_layout'))
              this.LayoutChoiceRow(COMPACT_VIDEO_LAYOUT_RAIL, $r('app.string.compact_video_layout_rail'), true)
              this.LayoutChoiceRow(COMPACT_VIDEO_LAYOUT_BOTTOM, $r('app.string.compact_video_layout_bottom'), true)
            } else if (this.menuVisible('video.layout')) {
              this.MoreSectionHeader($r('sys.symbol.rectangle_split_2x1'), $r('app.string.video_feed_layout'))
              this.LayoutChoiceRow(VIDEO_FEED_LAYOUT_CLASSIC, $r('app.string.video_feed_layout_classic'))
              if (this.layoutSwitchAvailable()) {
                this.LayoutChoiceRow(VIDEO_FEED_LAYOUT_DOUYIN, $r('app.string.video_feed_layout_douyin'))
              }
              this.LayoutChoiceRow(VIDEO_FEED_LAYOUT_BILIBILI, $r('app.string.video_feed_layout_bilibili'))
            }
            if (this.menuVisible('video.tap')) {
              this.MoreMenuRow($r('sys.symbol.play_fill'), $r('app.string.video_feed_tap_action'),
                this.text(this.videoFeedTapPause ? $r('app.string.video_feed_tap_pause') : $r('app.string.video_feed_tap_controls')),
                (): void => this.toggleVideoFeedTapPause())
            }
            if (this.menuVisible('video.fill')) {
              this.MoreMenuRow($r('sys.symbol.display'), $r('app.string.settings_video_immersive_fill'),
                this.text(this.videoImmersiveFill ? $r('app.string.video_feed_subtitles_on') :
                  $r('app.string.video_feed_subtitles_off')), (): void => {
                  this.toggleVideoImmersiveFill();
                })
            }
            if (this.menuVisible('video.controls')) {
              Row({ space: 14 }) {
                SymbolGlyph($r('sys.symbol.slider_horizontal_2_square'))
                  .fontSize(28)
                  .fontColor([$r('app.color.text_secondary')])
                  .width(32)
                Column({ space: 3 }) {
                  Text($r('app.string.video_feed_controls_always_visible')).fontFamily(this.appFontFamily)
                    .fontSize($r('sys.float.Body_L'))
                    .fontColor($r('app.color.text_primary'))
                  Text($r('app.string.video_feed_controls_always_visible_desc')).fontFamily(this.appFontFamily)
                    .fontSize($r('sys.float.Body_M'))
                    .fontColor($r('app.color.text_secondary'))
                    .maxLines(2)
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
                Toggle({ type: ToggleType.Switch, isOn: this.videoFeedControlsAlwaysVisible })
                  .selectedColor(this.accentColor)
                  .onChange((value: boolean): void => this.setVideoFeedControlsAlwaysVisible(value))
              }
              .width('100%')
              .padding({ left: 20, right: 20, top: 12, bottom: 12 })
            }
            if (this.menuVisible('video.quality')) {
              this.MoreMenuRow($r('sys.symbol.AI_hd_rectangle'), $r('app.string.video_feed_quality'),
                this.videoQualityLabel(), (): void => {
                  this.toggleQualityOptions();
                })
            }
            if (this.qualityExpanded && this.menuVisible('video.quality')) {
              this.QualityChoiceRow(VIDEO_QUALITY_DATA_SAVER, $r('app.string.settings_quality_auto'))
              this.QualityChoiceRow(VIDEO_QUALITY_HIGH, $r('app.string.settings_quality_hd'))
              this.QualityChoiceRow(VIDEO_QUALITY_SD, $r('app.string.settings_quality_sd'))
              this.QualityChoiceRow(VIDEO_QUALITY_LD, $r('app.string.settings_quality_ld'))
            }
            if (this.menuVisible('video.advance')) {
              this.MoreMenuRow($r('sys.symbol.repeat_play'), $r('app.string.video_feed_auto_advance'),
                this.text(this.autoAdvance ? $r('app.string.video_feed_auto_advance_on') :
                  $r('app.string.video_feed_auto_advance_off')), (): void => {
                  this.toggleAutoAdvance();
                })
            }
            if (this.menuVisible('video.post')) {
              this.MoreMenuRow($r('sys.symbol.rectangle_text_rectangle_portrait'),
                $r('app.string.video_feed_go_to_post'), '', (): void => {
                  this.openCurrentPost();
                })
            }
            if (this.menuVisible('video.offline')) {
              this.MoreMenuRow($r('sys.symbol.plus'), $r('app.string.video_feed_add_offline'), '',
                (): void => {
                  void this.addCurrentVideoOffline();
                })
            }
            if (this.menuVisible('video.report')) {
              this.MoreMenuRow($r('sys.symbol.flag'), $r('app.string.video_feed_report_post'), '',
                (): void => {
                  this.reportCurrentPost();
                })
            }
          }
          .width('100%')
          .padding({ top: 6, bottom: this.navigationIndicatorHeight + 12 })
        }, (revision: string): string => revision)
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
  }

  // SpeechKit reads the caption panel opacity once, when the caption component
  // is created, so the choice made here is stored and replayed on every rebuild.
  @Builder
  private CaptionOpacityRow(): void {
    Column({ space: 8 }) {
      Row({ space: 12 }) {
        Text($r('app.string.video_feed_caption_background')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_L'))
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Text(Math.round(this.captionOpacity * 100).toString() + '%').fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      Slider({
        value: this.captionOpacity * 100,
        min: 0,
        max: 100,
        step: 5,
        style: SliderStyle.InSet
      })
        .width('100%')
        .selectedColor(this.accentColor)
        .showTips(true)
        .onChange((value: number, mode: SliderChangeMode): void => {
          if (mode === SliderChangeMode.Begin || mode === SliderChangeMode.Moving) {
            return;
          }
          this.setCaptionOpacity(value / 100);
        })
    }
    .width('100%')
    .padding({ left: 70, right: 20, top: 4, bottom: 10 })
  }

  private moreSheetRevision(): string {
    return (this.captionsEnabled ? 'captions-on' : 'captions-off') + '-' +
      (this.autoAdvance ? 'advance-on' : 'advance-off') + '-' +
      (this.videoImmersiveFill ? 'immersive-on' : 'immersive-off') + '-' +
      this.videoFeedLayout.toString() + '-' + (this.videoFeedTapPause ? 'tap-pause' : 'tap-controls') + '-' +
      this.compactVideoLayout.toString() + '-' +
      (this.videoFeedControlsAlwaysVisible ? 'controls-persistent' : 'controls-auto-hide') + '-' +
      this.videoQuality.toString() + '-' + (this.qualityExpanded ? 'quality-open' : 'quality-closed') + '-' +
      Math.round(this.captionOpacity * 100).toString();
  }

  @Builder
  private StandardFeedVideo(item: VideoFeedItem): void {
    PostMedia({
      onViewerSurfaceReady: (): void => {
        if (this.feedItem(item).index === this.current && !this.closing) { this.initialVideoSurfaceReady = true; }
      },
      attachments: this.feedItem(item).attachments,
      sourceTweet: this.feedItem(item).tweet,
      viewerDanmakuEnabled: this.danmakuEnabled,
      viewerAuthorFollowing: this.authorFollowing,
      viewerDownloading: this.downloading || this.choosingDownloadQuality,
      onViewerDownload: (): void => { void this.downloadCurrentVideo(); },
      onViewerFollow: (): void => { void this.toggleFollow(this.feedItem(item).tweet); },
      onViewerComment: (): void => this.openPostSheet(this.feedItem(item).tweet),
      onViewerDanmakuToggle: (): void => { this.danmakuEnabled = !this.danmakuEnabled; },
      onViewerDanmakuSend: (): void => { this.showDanmakuSheet = true; },
      mediaViewerLayout: true,

      viewerFullscreenRequest: this.feedItem(item).index === this.current ? this.fullscreenRequest : 0,
      viewerDanmakuContent: (): void => this.FullscreenDanmaku(this.feedItem(item)),
      viewerPlayerRetained: this.shouldRetainVideoPlayer(item) ||
        videoPipGate.isHeld(this.feedItem(item).attachments[0].id),
      viewerUsesSideComments: this.useSideComments(),
      viewerPhoneFeedLayout: this.usesPhoneFeedLayout(),
      viewerCommentProgress: this.feedItem(item).index === this.current ? this.commentPreviewProgress : 0,
      viewerCommentTop: this.statusBarHeight,
      viewerCommentHeight: this.commentPreviewHeight,
      retainViewerPlayback: (this.postSheetActive || this.motion.enabled() && !this.motion.interactive) &&
        this.feedItem(item).index === this.current,
      onViewerCommentDismiss: (): void => this.closePostSheet(),
      onViewerVideoTap: (): void => {
        if (this.usesBiliLayout() && this.feedItem(item).index === this.current) {
          ++this.fullscreenCapsuleTapSerial;
        }
      },
      onViewerAdvance: (): void => this.advanceFromFullscreen(),
      castRequestSerial: this.castRequestMediaId === this.feedItem(item).attachments[0].id ? this.castRequestSerial : 0,
      onViewerCastPickerChanged: (visible: boolean): void => {
        this.castPickerShowing = visible;
      },
      onViewerCastingChanged: (casting: boolean): void => {
        if (casting) { this.castingMediaId = this.feedItem(item).attachments[0].id; }
        else if (this.castingMediaId === this.feedItem(item).attachments[0].id) { this.castingMediaId = ''; }
      },
      landscapePostContent: (): void => this.LandscapePostOverlay(this.feedItem(item).tweet),
      onViewerBack: (): void => this.close(),
      onViewerMore: (): void => { this.showMoreSheet = true; },

      onViewerControlsChanged: (visible: boolean): void => {
        this.updateVideoChromeVisible(this.feedItem(item).index, visible);
      },
      playbackEnabled: videoPipGate.isHeld(this.feedItem(item).attachments[0].id) ||
        (this.pageShown || this.castPickerShowing || this.castingMediaId === this.feedItem(item).attachments[0].id) &&
        this.feedItem(item).index === this.current,
      preloadMediaId: this.preloadMediaIdForItem(item),
      initialPositionMediaId: this.startPositionPending && this.feedItem(item).index === this.initialIndex ? this.startMediaId : '',
      initialPositionSeconds: this.startPositionPending ? this.startPositionSeconds : 0,
      // Opening the viewer is an explicit play intent for its whole session;
      // Home's inline autoplay preference must not pause swiped/advanced pages.
      manualStartMediaId: this.feedItem(item).attachments[0].id,
      videoFeedEnabled: false,
      captionEnabled: this.captionsEnabled,
      pipEnabled: true,
      pipNavigationHandleId: this.getUniqueId(),
      showDownloadButton: false,
      naturalVideoSize: true,
      limitNaturalHeight: false,
      immersiveVideo: this.videoImmersiveFill,
      fillVideoViewport: true,
      videoViewportHeight: this.videoViewportHeightForLayout(this.feedItem(item).index),
      compactFeedLayout: this.compactWindow(),
      compactBottomActions: this.usesCompactBottomLayout(),
      compactFeedActions: (): void => this.CompactBottomActions(this.feedItem(item)),
      controlsAtScreenBottom: this.isWideLandscape(),
      adaptiveShortVideo: true,
      forceUnmuted: true,
      playerBarBottomOffset: 0,
      onCaptionChanged: (shown: boolean): void => {
        this.setCaptionsEnabled(shown);
      },
      onPlaybackCompleted: (): void => {
        this.onVideoCompleted(this.feedItem(item).index);
      },
      onPlaybackStateChanged: (playing: boolean): void => {
        this.onCurrentVideoPlaybackChanged(this.feedItem(item).index, playing);
      },
      onHoldSpeedChanged: (active: boolean, rate: number): void => {
        this.setHoldSpeedState(this.feedItem(item).index, active, rate);
      },
      onInitialPositionApplied: (): void => {
        this.startPositionPending = false;
      }
    })
      .width('100%')
  }

  private onWindowSizeChanged(): void {
    this.videoViewportHeights = [];
    this.applyRailHand(this.railHand, false);
    if (this.showPostSheet) { this.updateCommentPreview(this.postSheetOpening); }
  }

  private updateVideoViewportHeight(index: number, height: number): void {
    const previous: number = this.videoViewportHeights[index] ?? 0;
    if (height <= 0 || Math.abs(height - previous) <= 0.5) {
      return;
    }
    const next: number[] = this.videoViewportHeights.slice();
    while (next.length <= index) {
      next.push(0);
    }
    next[index] = height;
    this.videoViewportHeights = next;
  }

  private videoViewportHeightForLayout(index: number): number {
    if (this.isWideLandscape()) {
      return this.windowHeight;
    }
    const measuredHeight: number = this.videoViewportHeights[index] ?? 0;
    if (measuredHeight > 0) {
      return measuredHeight;
    }
    return this.windowHeight > 0 ? this.windowHeight : 640;
  }

  private updateVideoChromeVisible(index: number, visible: boolean): void {
    if (this.isVideoChromeVisible(index) === visible) {
      return;
    }
    const next: boolean[] = this.videoChromeVisible.slice();
    while (next.length <= index) {
      next.push(true);
    }
    next[index] = visible;
    this.videoChromeVisible = next;
  }

  private isVideoChromeVisible(index: number): boolean {
    return this.videoChromeVisible[index] ?? true;
  }

  private feedControlStripHeight(): number {
    if (this.isWideLandscape()) { return 0; }
    const height: number = this.compactWindow() ?
      this.feedDimension(this.usesCompactBottomLayout() ? $r('app.float.compact_video_bottom_controls_height') :
        $r('app.float.compact_video_controls_height')) : VIDEO_FEED_CONTROLS_HEIGHT;
    return height + this.navigationIndicatorHeight;
  }

  private feedDimension(resource: Resource): number {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    return this.getUIContext().px2vp(context.resourceManager.getNumber(resource.id));
  }

  private usesShortVideoLayout(): boolean {
    return this.compactWindow() || this.videoFeedLayout === VIDEO_FEED_LAYOUT_DOUYIN;
  }

  private usesCompactBottomLayout(): boolean {
    return this.compactWindow() && this.compactVideoLayout === COMPACT_VIDEO_LAYOUT_BOTTOM;
  }

  private compactBottomCaptionFits(): boolean {
    return this.windowHeight - this.statusBarHeight - TOP_CONTROLS_HEIGHT - this.feedControlStripHeight() >=
      this.feedDimension($r('app.float.compact_video_bottom_caption_height'));
  }

  private shortVideoRailButtonSize(): number {
    return this.compactWindow() ? this.feedDimension($r('app.float.compact_video_rail_button_size')) :
      VIDEO_FEED_RAIL_BUTTON;
  }

  private shortVideoRailHeight(): number {
    return Math.max(1, this.windowHeight - this.statusBarHeight - TOP_CONTROLS_HEIGHT -
      this.feedControlStripHeight() - VIDEO_FEED_RAIL_GAP * 2);
  }

  @LocalBuilder
  private ViewerBackdrop(item: VideoFeedItem): void {
    if (!this.mediaViewerBlackBackground && Math.abs(this.feedItem(item).index - this.current) <= 1 && this.feedItem(item).attachments.length > 0) {
      VideoFeedBackdrop({
        mediaId: this.feedItem(item).attachments[0].id,
        previewUrl: this.feedItem(item).attachments[0].previewUrl,
        streamUrl: this.backdropStreamUrl(this.feedItem(item).attachments[0]),
        rendition: videoPosterRendition(this.feedItem(item).attachments[0], this.backdropStreamUrl(this.feedItem(item).attachments[0]))
      })
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.None)
    }
  }

  @LocalBuilder
  private VideoPage(item: VideoFeedItem): void {
    Stack({ alignContent: Alignment.Center }) {
      this.ViewerBackdrop(item)
      // The surface and the control strip keep their size when chrome is hidden.
      // Post information overlays the video instead of shrinking its viewport.
      this.StandardFeedVideo(item)
      // The hold-to-speed capsule lives on its own layer: it stays visible while
      // the chrome is hidden, and never swallows the press that produced it.
      Stack({ alignContent: Alignment.Top }) {
        this.HoldSpeedCapsule()
      }
      .width('100%')
      .height('100%')
      .hitTestBehavior(HitTestMode.None)
      if (this.usesBiliLayout() && !this.compactWindow()) {
        this.BiliOverlay(this.feedItem(item))
      } else if (!this.isWideLandscape()) {
        Stack({ alignContent: Alignment.Top }) {
          Column() {
            if (this.isVideoChromeVisible(this.feedItem(item).index)) {
              Row().height(0)
            }
          }
          .opacity(this.isVideoChromeVisible(this.feedItem(item).index) ? 1 - this.commentPreviewProgress : 0)
          .width('100%')
          .hitTestBehavior(this.isVideoChromeVisible(this.feedItem(item).index) && !this.postSheetActive ? HitTestMode.Default : HitTestMode.None)
        }
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.Transparent)
        if (!this.useSideComments()) {
          Stack({ alignContent: Alignment.Bottom }) {
            Column() {
              if (this.isVideoChromeVisible(this.feedItem(item).index)) {
                if (this.usesCompactBottomLayout()) {
                  if (this.compactBottomCaptionFits()) {
                    this.CompactBottomCaption(this.feedItem(item).tweet)
                  }
                } else if (this.usesShortVideoLayout()) {
                  this.ShortVideoCaption(this.feedItem(item).tweet, this.compactWindow() ? 8 : 16)
                } else {
                  this.PostOverlay(this.feedItem(item).tweet, 16)
                }
              }
            }
            .opacity(this.isVideoChromeVisible(this.feedItem(item).index) ? 1 - this.commentPreviewProgress : 0)
            .width('100%')
            .linearGradient({ angle: 180, colors: [
              [Color.Transparent, 0], [$r('app.color.video_feed_post_scrim'), 1]
            ] })
            .hitTestBehavior(this.isVideoChromeVisible(this.feedItem(item).index) && !this.postSheetActive ? HitTestMode.Default : HitTestMode.None)
          }
          .width('100%')
          .height('100%')
          .padding({ bottom: this.feedControlStripHeight() })
          .hitTestBehavior(HitTestMode.Transparent)
          if (this.usesShortVideoLayout() && !this.usesCompactBottomLayout() &&
            this.isVideoChromeVisible(this.feedItem(item).index)) {
            Stack({ alignContent: Alignment.BottomStart }) {
              if (this.compactWindow()) {
                Scroll() { this.ShortVideoRail(this.feedItem(item).tweet) }
                  .width(VIDEO_FEED_RAIL_WIDTH)
                  .height(this.shortVideoRailHeight())
                  .scrollBar(BarState.Off).edgeEffect(EdgeEffect.None)
                  .nestedScroll({ scrollForward: NestedScrollMode.SELF_FIRST,
                    scrollBackward: NestedScrollMode.SELF_FIRST })
                  .id('video-feed-compact-rail')
              } else {
                this.ShortVideoRail(this.feedItem(item).tweet)
              }
            }
            .width('100%')
            .height('100%')
            .padding({ left: VIDEO_FEED_RAIL_SIDE_MARGIN,
              bottom: this.feedControlStripHeight() + VIDEO_FEED_RAIL_GAP })
            .translate({ x: this.railShiftX, y: 0 })
            .opacity(this.isVideoChromeVisible(this.feedItem(item).index) ? 1 - this.commentPreviewProgress : 0)
            .hitTestBehavior(this.isVideoChromeVisible(this.feedItem(item).index) && !this.postSheetActive ?
              HitTestMode.Transparent : HitTestMode.None)
          }
        }
      }
    }
    .width('100%')
    .height('100%')
    .clip(true)
    .onAreaChange((oldValue: Area, newValue: Area): void => {
      this.updateVideoViewportHeight(this.feedItem(item).index, Number(newValue.height));
    })
  }

  // Sits directly below the back / more row, so the capsule reads as feedback
  // for the press the reader is holding.
  @Builder
  private HoldSpeedCapsule(): void {
    if (this.holdSpeedActive) {
      Row() {
        VideoHoldSpeedCapsule({
          rateLabel: videoHoldSpeedLabel(this.holdSpeedRate),
          hint: this.text(this.holdSpeedRate < 1 ? $r('app.string.video_hold_speed_slow_hint') :
            $r('app.string.video_hold_speed_hint')),
          lightColor: this.accentColor
        })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ left: 14, right: 14, top: this.statusBarHeight + TOP_CONTROLS_HEIGHT + 6 })
      .transition(TransitionEffect.OPACITY.animation({ duration: motionDuration(170), curve: Curve.EaseOut })
        .combine(TransitionEffect.scale({ x: motionScale(0.9), y: motionScale(0.9) }))
        .combine(TransitionEffect.translate({ y: motionDistance(-8) })))
    }
  }


  @Builder
  private PostOverlay(tweet: Tweet, bottomInset: number): void {
    Column({ space: 10 }) {
      // Both the caption and comment count open the current video's conversation.
      Column({ space: 6 }) {
        this.SourceAttribution(tweet)
        this.AuthorLine(tweet)
        if (tweet.text.length > 0) {
          Text() { EmojiSpans(this.getUIContext(), tweet.text, $r('sys.float.Body_L'), this.systemEmojiEnabled) }
            .fontSize($r('sys.float.Body_L'))
            .fontFamily(this.appFontFamily === DEFAULT_APP_FONT_FAMILY ? this.contentFontFamily : this.appFontFamily)
            .fontColor($r('app.color.text_on_brand'))
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
      }
      .width('100%')
      .onClick((): void => this.openPostSheet(tweet))

      this.PostActions(tweet)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: bottomInset })
  }

  private isWideLandscape(): boolean {
    return !this.compactWindow() && !this.useSideComments() && !this.usesPhoneFeedLayout() &&
      this.windowHeight > 0 && this.windowWidth > this.windowHeight;
  }

  private compactWindow(): boolean {
    return ResponsiveLayout.isCompactWindow(this.windowWidth, this.windowHeight);
  }

  @Builder
  private CompactBottomCaption(tweet: Tweet): void {
    Column({ space: $r('app.float.compact_video_bottom_gap') }) {
      this.SourceAttribution(tweet)
      Row({ space: $r('app.float.compact_video_bottom_gap') }) {
        Row({ space: $r('app.float.compact_video_bottom_gap') }) {
          ProxyAvatar({ url: tweet.author.avatarUrl ?? '',
            avatarSize: this.feedDimension($r('app.float.compact_video_bottom_avatar')),
            radius: this.feedDimension($r('app.float.compact_video_bottom_avatar')) / 2,
            verifiedType: tweet.author.verifiedType ?? '', avatarShape: tweet.author.avatarShape ?? '',
            fallbackText: tweet.author.name.substring(0, 1).toUpperCase(), fallbackColor: tweet.author.avatarColor })
          Text(tweet.author.name).fontFamily(this.appFontFamily)
            .fontSize($r('app.float.compact_video_caption_font')).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_on_brand')).maxLines(1).maxFontScale(1.15)
            .textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
          if (tweet.author.verified) {
            SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
              .fontSize($r('app.float.compact_video_caption_font'))
              .fontColor([verificationBadgeColor(tweet.author.verifiedType ?? '', this.accentColor)])
          }
        }.layoutWeight(1).height($r('app.float.compact_video_bottom_action_height'))
          .accessibilityText(tweet.author.name).monopolizeEvents(true)
          .onClick((): void => this.openAuthorProfile(tweet))
        PostAdLabel({ presentation: tweet.presentation })
        if (!this.isOwnPost(tweet)) {
          MaterialButton({ buttonWidth: $r('app.float.compact_video_bottom_follow_width'),
            buttonHeight: $r('app.float.compact_video_bottom_action_height'),
            buttonRadius: $r('app.float.compact_video_bottom_radius'), materialLevel: 1,
            surfaceColor: $r('app.color.video_episode_surface'), lightColor: this.accentColor,
            buttonEnabled: !this.authorFollowPending, buttonOpacity: this.authorFollowPending ? 0.6 : 1,
            accessibilityLabel: this.text(this.authorFollowing ?
              $r('app.string.profile_detail_following') : $r('app.string.profile_detail_follow')),
            buttonMonopolizeEvents: true, onButtonClick: (): void => { void this.toggleFollow(tweet); } }) {
            Text(this.authorFollowing ? $r('app.string.profile_detail_following') : $r('app.string.profile_detail_follow'))
              .fontFamily(this.appFontFamily).fontSize($r('app.float.compact_video_count_font'))
              .fontColor($r('app.color.text_on_brand')).maxLines(1).maxFontScale(1)
          }
        }
        CompactVideoActionButton({ icon: $r('sys.symbol.share'), label: $r('app.string.action_share'),
          onAction: (): void => this.share(tweet) }).width($r('app.float.compact_video_bottom_action_height'))
      }.width('100%')
      if (tweet.text.length > 0) {
        Text() { EmojiSpans(this.getUIContext(), tweet.text, $r('app.float.compact_video_caption_font'), this.systemEmojiEnabled) }
          .fontFamily(this.appFontFamily === DEFAULT_APP_FONT_FAMILY ? this.contentFontFamily : this.appFontFamily)
          .fontSize($r('app.float.compact_video_caption_font')).fontColor($r('app.color.text_on_brand'))
          .maxLines(1).maxFontScale(1.15).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
          .monopolizeEvents(true).onClick((): void => this.openPostSheet(tweet))
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
      .padding({ left: $r('app.float.compact_video_bottom_inset'), right: $r('app.float.compact_video_bottom_inset'),
        top: $r('app.float.compact_video_bottom_gap'), bottom: $r('app.float.compact_video_bottom_gap') })
      .id('video-feed-compact-bottom-caption')
  }

  @LocalBuilder
  private CompactBottomActions(item: VideoFeedItem): void {
    Row({ space: $r('app.float.compact_video_bottom_gap') }) {
      CompactVideoActionButton({ icon: $r('sys.symbol.pencil_line'), label: $r('app.string.action_reply'),
        value: this.text($r('app.string.post_detail_reply_placeholder')), pill: true,
        onAction: (): void => this.openPostSheet(this.feedItem(item).tweet) }).layoutWeight(1.5)
      CompactVideoActionButton({ icon: this.liked ? $r('sys.symbol.heart_fill') : $r('sys.symbol.heart'),
        label: $r('app.string.action_like'), value: formatCount(this.likeCount),
        selected: this.liked, pending: this.likePending, selectedColor: $r('app.color.like'),
        onAction: (): void => { void this.toggleLike(this.feedItem(item).tweet); } }).layoutWeight(1)
      CompactVideoActionButton({ icon: this.bookmarked ? $r('sys.symbol.bookmark_fill') : $r('sys.symbol.bookmark'),
        label: $r('app.string.action_bookmark'), selected: this.bookmarked, pending: this.bookmarkPending,
        selectedColor: this.accentColor,
        onAction: (): void => { void this.toggleBookmark(this.feedItem(item).tweet); } })
        .width($r('app.float.compact_video_bottom_action_height'))
      CompactVideoActionButton({ icon: $r('sys.symbol.ellipsis_bubble'), label: $r('app.string.action_reply'),
        value: formatCount(this.feedItem(item).tweet.metrics.replyCount),
        onAction: (): void => this.openPostSheet(this.feedItem(item).tweet) }).layoutWeight(1)
    }.width('100%').height($r('app.float.compact_video_bottom_action_height'))
      .padding({ left: $r('app.float.compact_video_bottom_inset'), right: $r('app.float.compact_video_bottom_inset') })
      .id('video-feed-compact-bottom-actions')
  }

  // ---- Short-video (Douyin-style) layout -----------------------------------
  // Same live actions as the classic overlay, rearranged: the author and the
  // caption sit at the bottom left, the actions stack down the right edge.
  // The player and its control strip are untouched.

  @Builder
  private ShortVideoRailLike(tweet: Tweet): void {
    Column({ space: 2 }) {
      // Same surface treatment as the reply capsule in the classic overlay, so
      // both layouts read as one family.
      MaterialButton({
        buttonWidth: this.shortVideoRailButtonSize(),
        buttonHeight: this.shortVideoRailButtonSize(),
        buttonRadius: this.shortVideoRailButtonSize() / 2,
        surfaceColor: '#66000000',
        materialLevel: 1,
        applyShadow: true,
        buttonPressFeedback: true,
        lightColor: this.accentColor,
        accessibilityLabel: this.text($r('app.string.action_like')),
        buttonMonopolizeEvents: true,
        onButtonClick: (): void => {
          this.toggleLike(tweet);
        }
      }) {
        SymbolGlyph(this.liked ? $r('sys.symbol.heart_fill') : $r('sys.symbol.heart'))
          .fontSize(VIDEO_FEED_RAIL_ICON)
          .fontColor([this.liked ? $r('app.color.like') : $r('app.color.text_on_brand')])
      }
      Text(formatCount(this.likeCount)).fontFamily(this.appFontFamily)
        .fontSize(this.compactWindow() ? $r('app.float.compact_video_count_font') : $r('sys.float.Body_M'))
        .fontWeight(FontWeight.Medium)
        .fontColor(this.liked ? $r('app.color.like') : $r('app.color.text_on_brand'))
        .maxLines(1)
        .maxFontScale(1)
    }
    .width(VIDEO_FEED_RAIL_WIDTH)
    .alignItems(HorizontalAlign.Center)
    .id('video-feed-rail-like')
  }

  @Builder
  private ShortVideoRailReply(tweet: Tweet): void {
    Column({ space: 2 }) {
      MaterialButton({
        buttonWidth: this.shortVideoRailButtonSize(),
        buttonHeight: this.shortVideoRailButtonSize(),
        buttonRadius: this.shortVideoRailButtonSize() / 2,
        surfaceColor: '#66000000',
        materialLevel: 1,
        applyShadow: true,
        buttonPressFeedback: true,
        lightColor: this.accentColor,
        accessibilityLabel: this.text($r('app.string.action_reply')),
        buttonMonopolizeEvents: true,
        onButtonClick: (): void => this.openPostSheet(tweet)
      }) {
        SymbolGlyph($r('sys.symbol.ellipsis_bubble'))
          .fontSize(VIDEO_FEED_RAIL_ICON)
          .fontColor([$r('app.color.text_on_brand')])
      }
      Text(formatCount(tweet.metrics.replyCount)).fontFamily(this.appFontFamily)
        .fontSize(this.compactWindow() ? $r('app.float.compact_video_count_font') : $r('sys.float.Body_M'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_on_brand'))
        .maxLines(1)
        .maxFontScale(1)
    }
    .width(VIDEO_FEED_RAIL_WIDTH)
    .alignItems(HorizontalAlign.Center)
    .id('video-feed-rail-reply')
  }

  @Builder
  private ShortVideoRailRepost(tweet: Tweet): void {
    Column({ space: 2 }) {
      MaterialButton({
        buttonWidth: this.shortVideoRailButtonSize(),
        buttonHeight: this.shortVideoRailButtonSize(),
        buttonRadius: this.shortVideoRailButtonSize() / 2,
        surfaceColor: '#66000000',
        materialLevel: 1,
        applyShadow: true,
        buttonPressFeedback: true,
        lightColor: this.accentColor,
        accessibilityLabel: this.text($r('app.string.action_repost')),
        buttonMonopolizeEvents: true,
        onButtonClick: (): void => {
          this.toggleRepost(tweet);
        }
      }) {
        SymbolGlyph($r('sys.symbol.repeat'))
          .fontSize(VIDEO_FEED_RAIL_ICON)
          .fontColor([this.reposted ? $r('app.color.repost') : $r('app.color.text_on_brand')])
      }
      Text(formatCount(tweet.metrics.repostCount)).fontFamily(this.appFontFamily)
        .fontSize(this.compactWindow() ? $r('app.float.compact_video_count_font') : $r('sys.float.Body_M'))
        .fontWeight(FontWeight.Medium)
        .fontColor(this.reposted ? $r('app.color.repost') : $r('app.color.text_on_brand'))
        .maxLines(1)
        .maxFontScale(1)
    }
    .width(VIDEO_FEED_RAIL_WIDTH)
    .alignItems(HorizontalAlign.Center)
    .id('video-feed-rail-repost')
  }

  @Builder
  private ShortVideoRailBookmark(tweet: Tweet): void {
    Column() {
      MaterialButton({
        buttonWidth: this.shortVideoRailButtonSize(),
        buttonHeight: this.shortVideoRailButtonSize(),
        buttonRadius: this.shortVideoRailButtonSize() / 2,
        surfaceColor: '#66000000',
        materialLevel: 1,
        applyShadow: true,
        buttonPressFeedback: true,
        lightColor: this.accentColor,
        accessibilityLabel: this.text($r('app.string.action_bookmark')),
        buttonEnabled: !this.bookmarkPending,
        buttonOpacity: this.bookmarkPending ? 0.6 : 1,
        buttonMonopolizeEvents: true,
        onButtonClick: (): void => {
          this.toggleBookmark(tweet);
        }
      }) {
        SymbolGlyph(this.bookmarked ? $r('sys.symbol.bookmark_fill') : $r('sys.symbol.bookmark'))
          .fontSize(VIDEO_FEED_RAIL_ICON)
          .fontColor([this.bookmarked ? this.accentColor : $r('app.color.text_on_brand')])
      }
    }
    .width(VIDEO_FEED_RAIL_WIDTH)
    .alignItems(HorizontalAlign.Center)
    .id('video-feed-rail-bookmark')
  }

  @Builder
  private ShortVideoRailShare(tweet: Tweet): void {
    Column() {
      MaterialButton({
        buttonWidth: this.shortVideoRailButtonSize(),
        buttonHeight: this.shortVideoRailButtonSize(),
        buttonRadius: this.shortVideoRailButtonSize() / 2,
        surfaceColor: '#66000000',
        materialLevel: 1,
        applyShadow: true,
        buttonPressFeedback: true,
        lightColor: this.accentColor,
        accessibilityLabel: this.text($r('app.string.action_share')),
        buttonMonopolizeEvents: true,
        onButtonClick: (): void => this.share(tweet)
      }) {
        SymbolGlyph($r('sys.symbol.share'))
          .fontSize(VIDEO_FEED_RAIL_ICON)
          .fontColor([$r('app.color.text_on_brand')])
      }
    }
    .width(VIDEO_FEED_RAIL_WIDTH)
    .alignItems(HorizontalAlign.Center)
    .id('video-feed-rail-share')
  }

  @Builder
  private ShortVideoRail(tweet: Tweet): void {
    Column({ space: this.compactWindow() ? 8 : VIDEO_FEED_RAIL_GAP }) {
      Stack({ alignContent: Alignment.Bottom }) {
        ProxyAvatar({
          url: tweet.author.avatarUrl ?? '',
          avatarSize: this.shortVideoRailButtonSize(),
          radius: this.shortVideoRailButtonSize() / 2,
          verifiedType: tweet.author.verifiedType ?? '',
          avatarShape: tweet.author.avatarShape ?? '',
          fallbackText: tweet.author.name.substring(0, 1).toUpperCase(),
          fallbackColor: tweet.author.avatarColor
        })
        if (!this.isOwnPost(tweet) && !this.authorFollowing) {
          Stack({ alignContent: Alignment.Center }) {
            SymbolGlyph($r('sys.symbol.plus'))
              .fontSize(14)
              .fontColor([$r('app.color.text_on_brand')])
          }
          .width(20)
          .height(20)
          .borderRadius(10)
          .backgroundColor($r('app.color.like'))
          // Straddle the avatar's bottom edge, the way the follow badge does on
          // a short-video profile picture.
          .offset({ x: 0, y: VIDEO_FEED_RAIL_BADGE_OFFSET })
          .accessibilityText(this.text($r('app.string.profile_detail_follow')))
          .monopolizeEvents(true)
          .onClick((): void => {
            this.toggleFollow(tweet);
          })
        }
      }
      .width(VIDEO_FEED_RAIL_WIDTH)
      .accessibilityText(tweet.author.name)
      .onClick((): void => {
        this.openAuthorProfile(tweet);
      })
      this.ShortVideoRailLike(tweet)
      this.ShortVideoRailReply(tweet)
      this.ShortVideoRailRepost(tweet)
      this.ShortVideoRailBookmark(tweet)
      this.ShortVideoRailShare(tweet)
    }
    .width(VIDEO_FEED_RAIL_WIDTH)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private ShortVideoCaption(tweet: Tweet, bottomInset: number): void {
    Column({ space: this.compactWindow() ? 4 : 6 }) {
      this.SourceAttribution(tweet)
      Row({ space: 6 }) {
        Text(tweet.author.name).fontFamily(this.appFontFamily)
          .fontSize(this.compactWindow() ? $r('app.float.compact_video_caption_font') : $r('sys.float.Body_L'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_on_brand'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        if (tweet.author.verified) {
          SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
            .fontSize(16)
            .fontColor([verificationBadgeColor(tweet.author.verifiedType ?? '', this.accentColor)])
        }
      }
      if (!this.compactWindow()) {
        Text('@' + tweet.author.username).fontFamily(this.appFontFamily)
          .fontSize(this.compactWindow() ? $r('app.float.compact_video_count_font') : $r('sys.float.Body_M'))
          .fontColor('#D9FFFFFF')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      if (tweet.text.length > 0) {
        Text() { EmojiSpans(this.getUIContext(), tweet.text,
          this.compactWindow() ? $r('app.float.compact_video_caption_font') : $r('sys.float.Body_L'), this.systemEmojiEnabled) }
          .fontSize(this.compactWindow() ? $r('app.float.compact_video_caption_font') : $r('sys.float.Body_L'))
          .fontFamily(this.appFontFamily === DEFAULT_APP_FONT_FAMILY ? this.contentFontFamily : this.appFontFamily)
          .fontColor($r('app.color.text_on_brand'))
          .maxLines(this.compactWindow() ? 1 : 2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: this.captionLeadingInset, right: this.captionTrailingInset,
      top: this.compactWindow() ? 6 : 12, bottom: bottomInset })
    .id('video-feed-caption')
    .onClick((): void => this.openPostSheet(tweet))
  }

  private usesBiliLayout(): boolean {
    return this.videoFeedLayout === VIDEO_FEED_LAYOUT_BILIBILI;
  }

  private episodeVideos(tweet: Tweet): MediaAttachment[] {
    // An explicitly revealed sensitive clip remains available as an episode;
    // other guarded clips continue to use the app's existing privacy setting.
    const selected: MediaAttachment[] = this.items.find((item: VideoFeedItem): boolean => item.tweet.id === tweet.id)?.attachments ?? [];
    return (tweet.attachments ?? []).filter((media: MediaAttachment): boolean =>
      media.type === 'video' && media.mediaUrl.length > 0 &&
      (media.sensitive !== true || this.showSensitiveMedia || selected.some((active: MediaAttachment): boolean => active.id === media.id)));
  }

  private selectEpisode(tweet: Tweet, index: number): void {
    const videos: MediaAttachment[] = this.episodeVideos(tweet);
    const item: VideoFeedItem | undefined = this.items[this.current];
    if (item === undefined || item.tweet.id !== tweet.id || index < 0 || index >= videos.length ||
      item.attachments[0]?.id === videos[index].id) { return; }
    const existing: number = this.items.findIndex((entry: VideoFeedItem): boolean =>
      entry.tweet.id === tweet.id && entry.attachments[0]?.id === videos[index].id);
    if (existing >= 0) {
      this.pager.changeIndex(existing, false);
      hapticTick();
      return;
    }
    this.preloadActive = false;
    this.holdSpeedActive = false;
    this.fullscreenRequest = 0;
    this.startPositionPending = false;
    item.attachments = [videos[index]];
    hapticTick();
  }

  private async loadDanmaku(tweet: Tweet, retry: boolean = false): Promise<void> {
    if (!retry && this.danmakuTweetId === tweet.id) { return; }
    const generation: number = ++this.danmakuGeneration;
    if (this.danmakuTweetId !== tweet.id) {
      this.danmakuComments = [];
      this.danmakuDraft = '';
    }
    this.danmakuTweetId = tweet.id;
    this.danmakuFailed = false;
    this.danmakuLoading = true;
    try {
      let cursor: string = '';
      let replies: Tweet[] = [];
      let pendingReplies: boolean = false;
      // Only the reply portion is parsed; discover-more recommendations never
      // become comments. Bound pagination so entering a feed cannot flood X.
      for (let pageIndex: number = 0; pageIndex < 3; pageIndex++) {
        const result: XPrivateResult = await xPrivateClient.tweetDetail(tweet.id, 'Relevance', cursor, retry);
        if (!this.viewerAlive || generation !== this.danmakuGeneration) { return; }
        if (!result.ok) { this.danmakuFailed = true; break; }
        const page: TweetDetailPage | null = XTimelineParser.parseTweetDetail(result.body, tweet.id, [tweet, ...replies]);
        if (page === null) { this.danmakuFailed = true; break; }
        replies = [...replies, ...page.replies];
        // The detail parser already excludes ancestors and recommendations.
        // Rechecking conversation_id here loses nested replies to a video that
        // is itself a reply, and module replies with omitted relation fields.
        const comments: VideoDanmakuComment[] = VideoDanmaku.comments(replies, tweet.id, true);
        const own: VideoDanmakuComment[] = this.danmakuComments.filter((comment: VideoDanmakuComment): boolean =>
          comment.own && !comments.some((loaded: VideoDanmakuComment): boolean => loaded.id === comment.id));
        this.danmakuComments = [...own, ...comments];
        pendingReplies = page.nextToken.length > 0 && page.nextToken !== cursor && !page.discoverMoreStarted;
        if (comments.length >= 100 || page.nextToken.length === 0 || page.nextToken === cursor || page.discoverMoreStarted) { break; }
        cursor = page.nextToken;
      }
      // Exhausting the request budget with unread reply pages is not proof of
      // an empty thread. Keep the existing retry affordance in that case.
      if (this.danmakuComments.length === 0 && pendingReplies) { this.danmakuFailed = true; }
    } catch (error) {
      if (generation === this.danmakuGeneration) { this.danmakuFailed = true; }
    } finally {
      if (generation === this.danmakuGeneration) { this.danmakuLoading = false; }
    }
  }

  private async sendDanmaku(): Promise<void> {
    const tweet: Tweet | null = this.currentTweet();
    const text: string = this.danmakuDraft.trim();
    if (tweet === null || text.length === 0 || this.danmakuSending) { return; }
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    this.danmakuSending = true;
    try {
      await authStore.load(context);
      xPrivateClient.load(context);
      let postId: string = '';
      if (authStore.isSignedIn() && authStore.getUserId().length > 0) {
        this.danmakuApi.setToken(authStore.getToken());
        this.danmakuApi.setUser(authStore.getUserId());
        if (await this.danmakuApi.postTweet(text, tweet.id)) {
          postId = this.danmakuApi.lastPostReceipt().postId;
          if (postId.length === 0) {
            promptAction.showToast({ message: this.text($r('app.string.post_send_unconfirmed')) });
            return;
          }
        } else {
          const status: number = this.danmakuApi.lastStatus();
          if (status < 0 || status >= 200 && status < 300 || !xPrivateClient.isSignedIn()) {
            promptAction.showToast({ message: XPostFeedback.failure(context, status, this.danmakuApi.lastPostReceipt()) });
            return;
          }
        }
      }
      if (postId.length === 0) {
        if (!xPrivateClient.isSignedIn()) {
          promptAction.showToast({ message: this.text($r('app.string.profile_follow_sign_in')) });
          return;
        }
        const result: XPrivateResult = await xPrivateClient.createTweet(text, tweet.id);
        if (!result.ok) {
          promptAction.showToast({ message: XPostFeedback.failure(context, result.status, result.postReceipt) });
          return;
        }
        postId = result.postReceipt.postId;
      }
      if (postId.length === 0) {
        promptAction.showToast({ message: this.text($r('app.string.post_send_unconfirmed')) });
        return;
      }
      AppStorage.setOrCreate<number>('harmonyx.posts_changed', (AppStorage.get<number>('harmonyx.posts_changed') ?? 0) + 1);
      if (!this.viewerAlive || this.currentTweet()?.id !== tweet.id) { return; }
      this.danmakuComments = [new VideoDanmakuComment(postId, VideoDanmaku.commentText(text), true, '', text), ...this.danmakuComments];
      tweet.metrics.replyCount += 1;
      this.danmakuDraft = '';
      this.showDanmakuSheet = false;
      this.danmakuEnabled = true;
      promptAction.showToast({ message: this.text($r('app.string.video_danmaku_sent')) });
    } catch (error) {
      promptAction.showToast({ message: this.text($r('app.string.post_send_unconfirmed')) });
    } finally {
      this.danmakuSending = false;
    }
  }

  @Builder
  private DanmakuEditor(): void {
    Column({ space: 16 }) {
      Text($r('app.string.video_danmaku_reply_hint')).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary'))
      TextInput({ text: this.danmakuDraft, placeholder: this.text($r('app.string.video_danmaku_send')) })
        .fontFamily(this.appFontFamily).fontSize(17).height(52).maxLength(280)
        .keyboardAppearance(KeyboardAppearance.IMMERSIVE)
        .fontColor($r('sys.color.font_primary')).backgroundColor(Color.Transparent)
        .attributeModifier(materialModifier(SystemMaterialUtil.immersiveMaterial(2, false, true, true, undefined)))
        .borderRadius(26).enterKeyType(EnterKeyType.Send)
        .onChange((value: string): void => { this.danmakuDraft = value; })
        .onSubmit((): void => { void this.sendDanmaku(); })
        .enabled(!this.danmakuSending)
      MaterialButton({ buttonWidth: '100%', buttonHeight: 48, buttonRadius: 24,
        buttonPressFeedback: true,
        materialLevel: 2, applyShadow: true, surfaceColor: this.accentColor,
        buttonEnabled: this.danmakuDraft.trim().length > 0 && !this.danmakuSending,
        buttonOpacity: this.danmakuSending ? 0.65 : (this.danmakuDraft.trim().length > 0 ? 1 : 0.45),
        onButtonClick: (): void => { void this.sendDanmaku(); } }) {
        Text(this.danmakuSending ? $r('app.string.video_danmaku_sending') : $r('app.string.video_danmaku_send'))
          .fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
      }
    }.width('100%').padding(20)
  }

  private startDanmakuKeyboardObserver(): void {
    const epoch: number = ++this.danmakuKeyboardEpoch;
    const context: common.Context | undefined = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    window.getLastWindow(context).then((currentWindow: window.Window): void => {
      if (epoch !== this.danmakuKeyboardEpoch || !this.viewerAlive || !this.showDanmakuSheet) { return; }
      this.danmakuKeyboardWindow = currentWindow;
      currentWindow.on('keyboardHeightChange', this.danmakuKeyboardListener);
      this.danmakuKeyboardListener(currentWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_KEYBOARD).bottomRect.height);
    }).catch((): void => {});
  }

  private stopDanmakuKeyboardObserver(): void {
    ++this.danmakuKeyboardEpoch;
    if (this.danmakuKeyboardWindow !== null) {
      this.danmakuKeyboardWindow.off('keyboardHeightChange', this.danmakuKeyboardListener);
      this.danmakuKeyboardWindow = null;
    }
    this.danmakuKeyboardHeight = 0;
  }

  @Builder
  private BiliEpisodes(tweet: Tweet): void {
    if (this.episodeVideos(tweet).length > 1) {
      Column({ space: 4 }) {
        Button({ type: ButtonType.Normal, stateEffect: true }) {
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.rectangle_split_2x1')).fontSize(20)
            .fontColor([$r('app.color.text_on_brand')])
          Text($r('app.string.video_episodes')).fontFamily(this.appFontFamily).fontSize(15)
            .fontColor($r('app.color.text_on_brand')).layoutWeight(1)
          Text((VideoDanmaku.episodeIndex(this.episodeVideos(tweet), this.currentVideo()?.id ?? '') + 1).toString() +
            '/' + this.episodeVideos(tweet).length.toString()).fontSize(14).fontColor($r('app.color.text_on_brand'))
          SymbolGlyph(this.episodesExpanded ? $r('sys.symbol.chevron_up') : $r('sys.symbol.chevron_down'))
            .fontSize(16).fontColor([$r('app.color.text_on_brand')])
        }.width('100%').height(44)
        }.width('100%').height(44).padding(0).backgroundColor(Color.Transparent).borderRadius(10)
          .onClick((): void => { this.episodesExpanded = !this.episodesExpanded; })
          .accessibilityText($r('app.string.video_episodes'))
        if (this.episodesExpanded) {
          Scroll() {
            Column({ space: 4 }) {
              ForEach(this.episodeVideos(tweet), (media: MediaAttachment, index: number) => {
                Button({ type: ButtonType.Normal, stateEffect: true }) {
                Row({ space: 8 }) {
                  Text(this.getUIContext().getHostContext()?.resourceManager.getStringSync($r('app.string.video_episode_number'), index + 1) ?? '')
                    .fontSize(14).fontColor(media.id === this.currentVideo()?.id ? this.accentColor : $r('app.color.text_on_brand'))
                    .layoutWeight(1).maxLines(1)
                  if (media.id === this.currentVideo()?.id) {
                    SymbolGlyph($r('sys.symbol.play_fill')).fontSize(14).fontColor([this.accentColor])
                  }
                }.width('100%').height(36)
                }.width('100%').height(36).padding(0).backgroundColor(Color.Transparent).borderRadius(8)
                  .onClick((): void => this.selectEpisode(tweet, index))
              }, (media: MediaAttachment): string => media.id)
            }.width('100%')
          }.width('100%').height(Math.min(120, this.episodeVideos(tweet).length * 40)).scrollBar(BarState.Off)
        }
      }.width('100%').padding({ left: 12, right: 12, bottom: this.episodesExpanded ? 8 : 0 })
        .backgroundColor($r('app.color.video_episode_surface')).borderRadius(12)
    }
  }

  @Builder
  private BiliFooter(tweet: Tweet): void {
    Column({ space: 12 }) {
      this.SourceAttribution(tweet)
      this.AuthorLine(tweet)
      Text() { EmojiSpans(this.getUIContext(), tweet.text, $r('sys.float.Body_L'), this.systemEmojiEnabled) }
        .fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_on_brand'))
        .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
        .onClick((): void => this.openPostSheet(tweet))
      this.BiliEpisodes(tweet)
      Row({ space: 4 }) {
        MaterialButton({ buttonWidth: 40, buttonHeight: 44, buttonRadius: 22, materialLevel: 2,
          buttonPressFeedback: true,
          applyShadow: true, surfaceColor: $r('app.color.video_episode_surface'),
          accessibilityLabel: this.text($r('app.string.video_danmaku_toggle')),
          onButtonClick: (): void => { this.danmakuEnabled = !this.danmakuEnabled; } }) {
          SymbolGlyph($r('sys.symbol.ellipsis_bubble')).fontSize(21)
            .fontColor([this.danmakuEnabled ? this.accentColor : $r('app.color.text_on_brand')])
        }
        Row() {
        MaterialButton({ buttonWidth: '100%', buttonHeight: 44, buttonRadius: 22, materialLevel: 2,
          buttonPressFeedback: true,
          applyShadow: true, surfaceColor: $r('app.color.video_episode_surface'),
          accessibilityLabel: this.text($r('app.string.video_danmaku_send')),
          onButtonClick: (): void => { this.showDanmakuSheet = true; } }) {
          Text($r('app.string.video_danmaku_send')).fontFamily(this.appFontFamily)
            .fontSize(14).fontColor($r('app.color.text_on_brand')).maxLines(1)
        }
        }.layoutWeight(1)
        VideoFeedActionButton({ icon: this.liked ? $r('sys.symbol.heart_fill') : $r('sys.symbol.heart'),
          label: $r('app.string.action_like'), count: this.likeCount, selected: this.liked, pending: this.likePending,
          selectedColor: $r('app.color.like'), onAction: (): void => { void this.toggleLike(tweet); } })
        VideoFeedActionButton({ icon: $r('sys.symbol.repeat'), label: $r('app.string.action_repost'),
          count: tweet.metrics.repostCount, selected: this.reposted, pending: this.repostPending,
          selectedColor: $r('app.color.repost'), onAction: (): void => { void this.toggleRepost(tweet); } })
        VideoFeedActionButton({ icon: this.bookmarked ? $r('sys.symbol.bookmark_fill') : $r('sys.symbol.bookmark'),
          label: $r('app.string.action_bookmark'), count: -1, selected: this.bookmarked, pending: this.bookmarkPending,
          selectedColor: this.accentColor, onAction: (): void => { void this.toggleBookmark(tweet); } })
        VideoFeedActionButton({ icon: $r('sys.symbol.ellipsis_bubble'), label: $r('app.string.action_reply'),
          count: tweet.metrics.replyCount, onAction: (): void => this.openPostSheet(tweet) })
      }.width('100%')
    }.width('100%').padding({ left: 14, right: 14, top: 12, bottom: 10 })
  }

  @Builder
  private FullscreenDanmaku(item: VideoFeedItem): void {
    if (this.usesBiliLayout() && item.index === this.current && this.danmakuEnabled) {
      ForEach([item.tweet.id + '-' + item.attachments[0].id], (key: string) => {
        VideoDanmakuOverlay({ comments: this.danmakuComments, playing: this.preloadActive && this.pageShown })
      }, (key: string): string => key)
    }
  }

  @Builder
  private BiliOverlay(item: VideoFeedItem): void {
    Column() {
      Row().height(0)
      Stack({ alignContent: Alignment.Bottom }) {
        if (item.index === this.current && this.danmakuEnabled) {
          ForEach([item.tweet.id + '-' + item.attachments[0].id], (key: string) => {
            VideoDanmakuOverlay({ comments: this.danmakuComments,
              playing: this.preloadActive && this.pageShown && !this.showMoreSheet && !this.showPostSheet })
          }, (key: string): string => key)
        }
        Column({ space: 8 }) {
          if (this.danmakuEnabled && this.danmakuComments.length === 0) {
            Text(this.danmakuLoading ? $r('app.string.video_danmaku_loading') :
              (this.danmakuFailed ? $r('app.string.video_danmaku_failed') : $r('app.string.video_danmaku_empty')))
              .fontSize(12).fontColor($r('app.color.video_danmaku_hint'))
              .onClick((): void => { if (this.danmakuFailed) { void this.loadDanmaku(item.tweet, true); } })
          }

        }.width('100%').padding({ bottom: 12 }).hitTestBehavior(HitTestMode.Transparent)
      }.width('100%').layoutWeight(1).hitTestBehavior(HitTestMode.Transparent)
      if (this.compactWindow()) {
        Scroll() { this.BiliFooter(item.tweet) }
          .width('100%').constraintSize({ maxHeight: this.windowHeight * 0.4 })
          .scrollBar(BarState.Off).edgeEffect(EdgeEffect.None)
      } else {
        this.BiliFooter(item.tweet)
      }
    }.width('100%').height('100%')
      .padding({ bottom: VIDEO_FEED_CONTROLS_HEIGHT + this.navigationIndicatorHeight })
      .opacity(1 - this.commentPreviewProgress)
      .hitTestBehavior(this.postSheetActive ? HitTestMode.None : HitTestMode.Transparent)
  }

  private usesPhoneFeedLayout(): boolean {
    return ResponsiveLayout.isLarge(this.sheetWindowBreakpoint) &&
      this.desktopVideoLayout === DESKTOP_VIDEO_LAYOUT_FEED;
  }

  private useSideComments(): boolean {
    return ResponsiveLayout.isLarge(this.sheetWindowBreakpoint) && !this.usesPhoneFeedLayout();
  }

  private commentsTweets(): Tweet[] {
    const current: Tweet | null = this.currentTweet();
    return current === null ? [] : [current];
  }

  @Builder
  private VideoPager(): void {
    Swiper(this.pager) {
      LazyForEach(this.videoDataSource, (item: VideoFeedItem) => {
        VideoFeedCell({ item: item, content: this.VideoPage })
      }, (item: VideoFeedItem): string => item.tweet.id + '-' + item.attachments[0].id)
    }
    .index(this.current)
    .vertical(true)
    .loop(false)
    // Cached XComponents must render so their surfaces can prepare and decode.
    .cachedCount(1, true)
    .indicator(false)
    .disableSwipe(this.postSheetActive || this.showDanmakuSheet || this.danmakuSending)
    .width('100%')
    .height('100%')
    .clip(true)
    .align(Alignment.Center)
    .onAppear((): void => {
      this.pagerShown = true;
      this.preloadNextPage();
    })
    .onDisAppear((): void => { this.pagerShown = false; })
    .onChange((index: number): void => {
      this.onPageChanged(index);
    })
  }

  @Builder
  private RecommendationRetry(): void {
    if (this.recommendationRetryNeeded && this.current >= this.items.length - 1 && this.items.length > 0) {
      Button($r('app.string.common_retry'))
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('app.color.text_on_brand'))
        .backgroundColor(deviceInfo.apiAvailable('26.0.0') ? Color.Transparent : '#66000000')
        .attributeModifier(materialModifier(this.controlMaterial(true)))
        .borderRadius(20)
        .padding({ left: 20, right: 20 })
        .height(40)
        .margin({ top: this.statusBarHeight + 62 })
        .align(Alignment.Top)
        .onClick((): void => { this.loadMoreVideos(); })
    }
  }

  @LocalBuilder
  private LandscapePostOverlay(tweet: Tweet): void {
    Column({ space: 4 }) {
        this.SourceAttribution(tweet)
        Text() { EmojiSpans(this.getUIContext(), tweet.text, $r('sys.float.Caption_M'), this.systemEmojiEnabled) }
          .fontSize($r('sys.float.Caption_M')).fontWeight(FontWeight.Medium)
          .fontFamily(this.appFontFamily === DEFAULT_APP_FONT_FAMILY ? this.contentFontFamily : this.appFontFamily).fontColor($r('app.color.text_on_brand'))
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
        Text(tweet.author.name + ' · @' + tweet.author.username).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Caption_M')).fontColor($r('app.color.video_feed_secondary_text'))
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
    }.width('100%').alignItems(HorizontalAlign.Start).id('landscape-player-title')
      .onClick((): void => this.openPostSheet(tweet))
  }

  build(): void {
    HdsNavDestination() {
      MediaViewerMotion({ motion: this.motion, surfaceId: this.motionSurfaceId,
        presentation: this.motion.presentation,
        targetId: 'video-viewer-frame-' + (this.currentVideo()?.id ?? ''),
        contentReady: this.items.length > 0 && this.initialVideoSurfaceReady,
        mediaWidth: this.currentVideo()?.width ?? 0, mediaHeight: this.currentVideo()?.height ?? 0,
        targetContainsMedia: false }) {
      Row({ space: 0 }) {
      Stack({ alignContent: Alignment.Center }) {
        if (this.items.length > 0) {
          this.VideoPager()
        }
        this.RecommendationRetry()
        Column()
          .width(0).height(0)
          .bindSheet($$this.showDanmakuSheet, this.DanmakuEditor(), sheetMaterialOptions({
            // Reserve keyboard space in the sheet itself. RESIZE_ONLY removes
            // that reserve and leaves the complete 240vp editor above the IME.
            height: 240 + this.danmakuKeyboardHeight,
            preferType: SheetType.BOTTOM,
            showClose: true,
            dragBar: true,
            keyboardAvoidMode: SheetKeyboardAvoidMode.RESIZE_ONLY,
            onAppear: (): void => this.startDanmakuKeyboardObserver(),
            onDisappear: (): void => this.stopDanmakuKeyboardObserver(),
            backgroundColor: pageSurfaceColor(this.themeDisplayMode, this.themeDarkSurface)
          }, this.sheetMaterialEnabled, this.sheetMaterialLevel, this.sheetWindowBreakpoint, this.compactWindow()))
        Column()
          .width(0).height(0)
          .bindSheet($$this.showPostSheet, this.PostSheet(), sheetMaterialOptions({
            height: this.initialPostSheetHeight(),
            detents: [this.initialPostSheetHeight(), SheetSize.LARGE],
            preferType: SheetType.BOTTOM,
            keyboardAvoidMode: SheetKeyboardAvoidMode.RESIZE_ONLY,
            showClose: false,
            dragBar: true,
            maskColor: Color.Transparent,
            enableOutsideInteractive: true,
            radius: { topLeft: $r('app.float.media_viewer_post_sheet_radius'),
              topRight: $r('app.float.media_viewer_post_sheet_radius') },
            backgroundColor: pageSurfaceColor(this.themeDisplayMode, this.themeDarkSurface),
            onHeightDidChange: (heightPx: number): void => {
              if (!this.showPostSheet) { return; }
              this.postSheetHeight = this.getUIContext().px2vp(heightPx);
              this.updateCommentPreview(this.postSheetOpening);
            },
            onAppear: (): void => { this.postSheetOpening = false; },
            onWillDismiss: (action: DismissSheetAction): void => {
              this.closePostSheet();
              action.dismiss();
            },
            onWillSpringBackWhenDismiss: (): void => {},
            onDisappear: (): void => {
              this.closePostSheet();
              this.postSheetActive = false;
              this.postSheetHeight = 0;
              this.postSheetTweet = null;
            }
          }, this.sheetMaterialEnabled, this.sheetMaterialLevel, this.sheetWindowBreakpoint, this.compactWindow()))
      }
      // Both panes share the Row's available width. matchParent bypasses the
      // sibling's allocation and pushes the post pane outside the viewport.
      .height('100%')
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
      .backgroundColor(Color.Transparent)
      .layoutWeight(56)
      .clip(true)
      .id('video-feed-playback-pane').focusable(true).defaultFocus(true)
      .onKeyEvent((event: KeyEvent): boolean => this.videoInputKey(event))
      .onMouse((event: MouseEvent): void => contextInputMouse(event, (): void => {
        if (!this.closing && !this.postSheetActive && !this.showDanmakuSheet) { this.showMoreSheet = true; }
      }))
      if (this.useSideComments()) {
        Column() {
          ForEach(this.commentsTweets(), (post: Tweet) => {
            PostDetail({ embedded: true, initialTweet: post,
              onEmbeddedPostChanged: (changed: Tweet): void => this.applyPostSheetChange(changed) })
          }, (post: Tweet): string => post.id)
        }.layoutWeight(44).height('100%')
          .id('video-feed-post-pane')
          .padding({ top: this.statusBarHeight })
          .backgroundColor(pageSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
          .border({ width: { left: 0.5 }, color: $r('app.color.divider') })
      }
      }.width('100%').height('100%').backgroundColor($r('app.color.media_viewer_black_background'))
      .bindSheet($$this.showMoreSheet, this.MoreSheet(), sheetMaterialOptions({
        height: SheetSize.MEDIUM,
        detents: [SheetSize.MEDIUM, SheetSize.LARGE],
        preferType: SheetType.BOTTOM,
        showClose: false,
        dragBar: true,
        backgroundColor: pageSurfaceColor(this.themeDisplayMode, this.themeDarkSurface)
      }, this.sheetMaterialEnabled, this.sheetMaterialLevel, this.sheetWindowBreakpoint, this.compactWindow()))
      }
    }
    .mode(NavDestinationMode.STANDARD)
    .systemTransition(pageSystemTransition(this.pageTransitionMode, this.motion.enabled() ? NavigationSystemTransitionType.NONE : NavigationSystemTransitionType.DEFAULT))
    .onReady((context: NavDestinationContext): void => {
      this.returnNavigation.attach(context);
      this.readRoute();
    })
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .titleBar({
      avoidLayoutSafeArea: true,
      content: { title: { mainTitle: '' }, menu: { value: this.nativeViewerMenus() } },
      style: mediaViewerTitleBarStyle()
    })
    .hideTitleBar(this.closing || !this.isVideoChromeVisible(this.current))
    .hideBackButton(false)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .onShown((): void => {
      this.viewerAlive = true;
      this.closing = false;
      this.pageShown = true;
      AppStorage.setOrCreate<boolean>(STORAGE_KEY_VIDEO_FEED_ACTIVE, true);
      this.startNetworkPolicyMonitoring();
    })
    .onWillHide((): void => {
      this.recommendationStream.flush();
      this.pageShown = false;
      this.preloadActive = false;
      const media: MediaAttachment | null = this.currentVideo();
      if (media !== null && videoPipGate.isHeld(media.id)) {
        AppStorage.setOrCreate<boolean>(STORAGE_KEY_VIDEO_FEED_ACTIVE, false);
      }
      this.stopNetworkPolicyMonitoring();
    })
    .onKeyEvent((event: KeyEvent): boolean => backInputKey(event, (): void => this.inputBack()))
    .onBackPressed((): boolean => { this.inputBack(); return true; })
    .backgroundColor(this.closing ? Color.Transparent : $r('app.color.media_viewer_black_background'));
  }
}
