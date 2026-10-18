import { AdaptivePostGrid } from '../components/AdaptivePostGrid';
import { DEFAULT_COMPONENT_HDR_ENABLED, DEFAULT_COMPONENT_HDR_RATIO, STORAGE_KEY_COMPONENT_HDR_ENABLED,
  STORAGE_KEY_COMPONENT_HDR_RATIO } from '../services/ComponentHdrSettingsStore';
import { ComponentHdrHighlight } from '../utils/ComponentHdrHighlight';
import { pageTextColor } from '../utils/ThemeColors';
import { appPageBackground } from '../components/PageBackgroundLayer';
import { pageCanvasColor, pageReadingSurfaceColor, postCardSurfaceColor, postCardUsesCustomSurface } from '../utils/ThemeColors';
import { STORAGE_KEY_PAGE_TRANSITION_MODE, DEFAULT_PAGE_TRANSITION_MODE } from '../services/PageTransitionSettingsStore';
import { pageSystemTransition, PageTransitionMotion } from '../utils/PageTransition';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { STORAGE_KEY_SYSTEM_EMOJI_ENABLED } from '../services/AppearanceStore';
import { PostAdLabel } from '../components/PostAdLabel';
import { isAdPost, refreshedPostPresentation } from '../utils/PostDisclosure';
import { STORAGE_KEY_FILTER_HIDE_ADS } from '../services/ContentFilterStore';
import { userAvatarRadius, userVerifiedType, userAvatarShape, verificationBadgeColor } from '../utils/UserIdentity';
import { DEFAULT_SHEET_MATERIAL_ENABLED, DEFAULT_SHEET_MATERIAL_LEVEL, STORAGE_KEY_SHEET_MATERIAL_ENABLED, STORAGE_KEY_SHEET_MATERIAL_LEVEL } from '../services/SheetMaterialSettingsStore';
import { sheetContentBackground, sheetMaterialOptions } from '../utils/SheetMaterial';
import { STORAGE_KEY_MEDIA_COMMENT_BACKGROUND } from '../services/MediaSettingsStore';
// Post detail destination. It lives inside the root HdsNavigation stack to
// share the native secondary-page transition and immersive title bar pattern
// used by PaperTalk's HdsNavDestination child pages.
import {
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  hdsEffect,
  ScrollEffectType
} from '@kit.UIDesignKit';
import common from '@ohos.app.ability.common';
import promptAction from '@ohos.promptAction';
import { inputMethod } from '@kit.IMEKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { deviceInfo } from '@kit.BasicServicesKit';
import { display, KeyboardAvoidMode, uiMaterial, window } from '@kit.ArkUI';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { harmonyShare, systemShare } from '@kit.ShareKit';
import { TweetCard } from '../components/TweetCard';
import { PromotionPostCard } from '../components/PromotionPostCard';
import { XXAuthPromotionPlan, XXAuthPromotionPost } from '../services/XXAuthPromotionPost';
import { XXAuthPromotionInjector, XXAuthPromotionSlot } from '../utils/XXAuthPromotionInjector';
import { XXAUTH_PROMOTION_POST, xxAuthPopupStore } from '../services/XXAuthPopupStore';
import { AvatarTintPalette, avatarTintIsDark, avatarTintSurface } from '../utils/AvatarTintColors';
import { SpaceAwareAvatar } from '../components/SpaceAwareAvatar';
import { CommunitySource } from '../components/CommunitySource';
import { PostMedia } from '../components/PostMedia';
import { browsingHistoryStore } from '../services/BrowsingHistoryStore';
import { QuotedPostCard } from '../components/QuotedPostCard';
import { PostInteractiveContent } from '../components/PostInteractiveContent';
import { canPostAction } from '../utils/PostContentVisibility';
import { FloatingComposeButton } from '../components/FloatingComposeButton';
import type { GrokRouteParam } from './Grok';
import type { PostInteractionsRouteParam } from './PostInteractions';
import type { EditHistoryRouteParam } from './EditHistory';
import { ReplyComposerCapsuleBuilder } from '../components/ReplyComposer';
import type { ReplyComposerContext, ReplyComposerRouteParam } from '../components/ReplyComposer';
import { XPrivateResult, xPrivateClient } from '../services/XPrivateClient';
import { XUserParser } from '../services/XUserParser';
import { XTimelineParser } from '../services/XTimelineParser';
import type { TweetDetailPage } from '../services/XTimelineParser';
import { ThreadReplyOrder } from '../services/ThreadReplyOrder';
import type { ThreadReplyRow } from '../services/ThreadReplyOrder';
import { formatCount } from '../models/Tweet';
import type { MediaAttachment, Tweet, TweetAuthor, UserProfile } from '../models/Tweet';
import type { UserDetailRouteParam } from './UserDetail';
import type { ReadAloudRouteParam } from './ReadAloud';
import { STORAGE_KEY_READ_ALOUD_ENTRY_ENABLED } from '../services/ReadAloudSettingsStore';
import {
  STORAGE_KEY_TRANSLATION_AUTO_ENABLED,
  STORAGE_KEY_TRANSLATION_ENABLED,
  STORAGE_KEY_TRANSLATION_REPLACE_ORIGINAL,
  STORAGE_KEY_TRANSLATION_SETTINGS_REVISION,
  TranslationSettings,
  translationStore
} from '../services/TranslationStore';
import { TranslationResult, translationService } from '../services/TranslationService';
import { TARGET_LANGUAGE_APP } from '../models/Translation';
import { effectiveAppLocale, STORAGE_KEY_APP_LOCALE } from '../utils/AppLocale';
import { GROK_MODE_API, GROK_MODE_WEB, GrokSettings, grokSettingsStore } from '../services/GrokSettingsStore';
import { XApiClient } from '../services/XApiClient';
import { XPostFeedback } from '../services/XPostFeedback';
import { PostOverflowButton } from '../components/PostOverflowButton';
import { authStore } from '../services/AuthStore';
import { postLikeStore, STORAGE_KEY_POST_LIKES_REVISION } from '../services/PostLikeStore';
import { videoPipGate } from '../services/VideoPipGate';
import { continuationStore } from '../services/ContinuationState';
import { destinationTitleBarStyle } from '../utils/DestinationTitleBar';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';
import { NavigationGuard } from '../utils/NavigationGuard';
import { STORAGE_KEY_DESKTOP_LAYOUT } from '../services/LayoutSettingsStore';
import { LIST_EXPAND_BACK_CURVE, LIST_EXPAND_PUSH_CURVE, SHARED_ELEMENT_DURATION } from '../utils/SharedElementMotion';
import { MentionSegment, splitPostText } from '../utils/MentionText';
import { EmojiSpans } from '../components/EmojiSpans';
import { EmojiCopyMenu } from '../utils/EmojiCopyMenu';
import { openExternalLink, requestSearch } from '../utils/PostEntities';
import { hapticTick } from '../utils/Haptics';
import { symbolMotionEnabled } from '../utils/AppMotion';
import { STORAGE_KEY_REDUCE_MOTION, STORAGE_KEY_SYMBOL_EFFECTS, STORAGE_KEY_MOTION_AMPLITUDE } from '../services/MotionSettingsStore';
import { GripHandManager } from '../utils/GripHandManager';
import { cardSurfaceColor, fieldSurfaceColor, pageSurfaceColor } from '../utils/ThemeColors';
import { formatPostDetailTime, STORAGE_KEY_POST_TIME_NOW } from '../utils/PostTime';
import { postViewCounts, STORAGE_KEY_POST_VIEWS_REVISION } from '../services/PostViewCounts';
import {
  DEFAULT_CONTENT_FONT_FAMILY,
  STORAGE_KEY_CONTENT_FONT_FAMILY,
  STORAGE_KEY_AVATAR_TINT_ENABLED
} from '../services/AppearanceStore';

const REPLY_CAPSULE_GRIP_KEY: string = 'post-detail-reply-capsule';

// A comment-section row is either a real reply or an injected recommendation;
// one list keeps the thread order and the promotion position in the same pass.
class CommentTimelineRow {
  key: string = '';
  reply: ThreadReplyRow | null = null;
  promotion: XXAuthPromotionPost | null = null;
}

const REPLY_SORT_RECENT: string = 'recent';
const REPLY_SORT_RELEVANCE: string = 'relevance';
const REPLY_SORT_LIKES: string = 'likes';
const EMBEDDED_POST_SECTION_RADIUS: number = 24;
// Room one control of the detail action bar needs before the bar wraps. The
// widest control is a counter button - icon, gap and a compact number such as
// "1.2K" - which measures about 65vp.
const POST_ACTION_MIN_BUTTON_WIDTH: number = 64;

export interface PostDetailRouteParam {
  tweet: Tweet;
  sharedElementId?: string;
  continuationScrollOffset?: number;
  continuationReplySortMode?: string;
  returnToMain?: boolean;
  refreshContent?: boolean;
}

@Builder
export function PostDetailBuilder(): void {
  PostDetail();
}

@Component
export struct PostDetail {
  @StorageProp(STORAGE_KEY_COMPONENT_HDR_ENABLED) private componentHdrEnabled: boolean = DEFAULT_COMPONENT_HDR_ENABLED;
  @StorageProp(STORAGE_KEY_COMPONENT_HDR_RATIO) private componentHdrRatio: number = DEFAULT_COMPONENT_HDR_RATIO;
  @StorageProp('harmonyx.page_background') private pageBackgroundValue: string = '';
  @State private pageMotion: PageTransitionMotion = new PageTransitionMotion();
  @StorageProp(STORAGE_KEY_REDUCE_MOTION) private reduceMotion: boolean = false;
  @StorageProp(STORAGE_KEY_SYMBOL_EFFECTS) private symbolEffects: boolean = true;
  @StorageProp(STORAGE_KEY_MOTION_AMPLITUDE) private motionAmplitude: number = 1;
  @State private likeSymbolTrigger: number = -1;
  @State private repostSymbolTrigger: number = -1;
  @State private bookmarkSymbolTrigger: number = -1;

  @StorageProp(STORAGE_KEY_PAGE_TRANSITION_MODE) private pageTransitionMode: string = DEFAULT_PAGE_TRANSITION_MODE;
  @StorageProp('harmonyx.compact_window') private sheetCompactWindow: boolean = false;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp(STORAGE_KEY_SYSTEM_EMOJI_ENABLED) private systemEmojiEnabled: boolean = false;
  @StorageLink(STORAGE_KEY_FILTER_HIDE_ADS) private filterHideAds: boolean = true;
  @StorageProp('harmonyx.breakpoint') private sheetWindowBreakpoint: string = 'sm';
  @StorageProp(STORAGE_KEY_DESKTOP_LAYOUT) desktopLayoutEnabled: boolean = false;
  @StorageProp(STORAGE_KEY_SHEET_MATERIAL_ENABLED) private sheetMaterialEnabled: boolean = DEFAULT_SHEET_MATERIAL_ENABLED;
  @StorageProp(STORAGE_KEY_SHEET_MATERIAL_LEVEL) private sheetMaterialLevel: number = DEFAULT_SHEET_MATERIAL_LEVEL;
  @Prop embedded: boolean = false;
  @StorageProp(STORAGE_KEY_MEDIA_COMMENT_BACKGROUND) private mediaCommentBackground: boolean = true;
  @Prop initialTweet: Tweet | null = null;
  onEmbeddedPostChanged: (post: Tweet) => void = (): void => {};
  onEmbeddedNavigate: () => void = (): void => {};
  @StorageProp(STORAGE_KEY_POST_TIME_NOW) private postTimeNow: number = Date.now();
  @StorageProp(STORAGE_KEY_POST_VIEWS_REVISION) private viewCountRevision: number = 0;
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp('harmonyx.status_bar_height') statusBarHeight: number =
    AppStorage.get<number>('harmonyx.status_bar_height') ?? 0;
  @StorageProp('harmonyx.navigation_indicator_height') navigationIndicatorHeight: number =
    AppStorage.get<number>('harmonyx.navigation_indicator_height') ?? 0;
  @StorageProp('harmonyx.window_height') private detailWindowHeight: number =
    AppStorage.get<number>('harmonyx.window_height') ?? 780;
  @State private wideMediaIndex: number = 0;
  @StorageLink('harmonyx.accent_color') accentColor: string = '#007DFF';
  @StorageProp('harmonyx.display_mode') private themeDisplayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private themeDarkSurface: string = '';
  @StorageLink('harmonyx.title_bar_style_mode') titleBarStyleMode: number = 0;
  @StorageLink('harmonyx.font_scale') fontScale: number = 1;
  @StorageLink(STORAGE_KEY_CONTENT_FONT_FAMILY) private contentFontFamily: string = DEFAULT_CONTENT_FONT_FAMILY;
  @StorageLink(STORAGE_KEY_READ_ALOUD_ENTRY_ENABLED) readAloudEntryEnabled: boolean = false;
  @StorageLink(STORAGE_KEY_TRANSLATION_ENABLED) translationEnabled: boolean = false;
  @StorageLink(STORAGE_KEY_TRANSLATION_AUTO_ENABLED)
  translationAutoEnabled: boolean = false;
  @StorageLink(STORAGE_KEY_TRANSLATION_SETTINGS_REVISION) @Watch('onTranslationSettingsRevisionChanged')
  translationSettingsRevision: number = 0;
  @StorageLink(STORAGE_KEY_TRANSLATION_REPLACE_ORIGINAL) translationReplaceOriginal: boolean = false;
  @StorageLink('harmonyx.breakpoint') @Watch('onPostDetailBreakpointChanged')
  breakpoint: string = ResponsiveLayout.BREAKPOINT_SM;
  @StorageLink('harmonyx.grip_hand_enabled') @Watch('onReplyGripHandEnabledChanged')
  replyGripHandEnabled: boolean = true;
  @StorageLink('harmonyx.grip_preferred_hand') @Watch('onReplyPreferredHandChanged')
  replyPreferredHand: string = 'right';
  @State @Watch('onHeroTweetChanged') tweet: Tweet | null = null;
  @StorageProp(STORAGE_KEY_AVATAR_TINT_ENABLED) private avatarTintEnabled: boolean = false;
  @State private avatarPalette: AvatarTintPalette | null = null;
  @State private avatarThemeDark: boolean = false;
  @StorageProp(XXAUTH_PROMOTION_POST) @Watch('onPromotionChanged') private promotionPostJson: string = '';
  @State sharedElementId: string = '';
  @State private returnToMain: boolean = false;
  @State replies: Tweet[] = [];
  @State private discoverMore: Tweet[] = [];
  @State private threadNextToken: string = '';
  @State private threadLoadingMore: boolean = false;
  @State private threadLoadMoreFailed: boolean = false;
  private threadLoadGeneration: number = 0;
  private discoverMoreStarted: boolean = false;
  @State currentProfile: UserProfile | null = null;
  @State threadStatus: string = '';
  @State threadLoading: boolean = true;
  @State transitionSettled: boolean = true;
  @State refreshing: boolean = false;
  @State private readAloudFabMode: string = 'read';
  @State liked: boolean = false;
  @State private likeCount: number = 0;
  @StorageProp(STORAGE_KEY_POST_LIKES_REVISION) @Watch('syncLikeState') private likeRevision: number = 0;
  @State reposted: boolean = false;
  @State bookmarked: boolean = false;
  @State authorFollowing: boolean = false;
  @State authorFollowPending: boolean = false;
  @State authorUserId: string = '';
  @State gestureSharing: boolean = false;
  @State heroTranslatedText: string = '';
  @State heroTranslating: boolean = false;
  @State private lastAutoTranslationRevision: number = -1;
  @State private lastAutoTranslationPostId: string = '';
  private heroTranslationRequestGeneration: number = 0;
  private heroTranslationPostId: string = '';
  private heroTranslationWasAutomatic: boolean = false;
  @StorageProp(STORAGE_KEY_APP_LOCALE) @Watch('onTranslationAppLocaleChanged')
  private appLocale: string = effectiveAppLocale();
  @State private replySortSheetVisible: boolean = false;
  @State private replyCapsuleExpanded: boolean = false;
  @State private replyComposerDismissRequest: number = 0;
  @State private replySortMode: string = REPLY_SORT_RELEVANCE;
  @State private replyCapsuleHand: string = 'right';
  @State private viewportShortSide: number = 360;
  @State private actionBarWidth: number = 0;
  @State private postPinned: boolean = false;
  @State private postActionPending: boolean = false;
  @State private keyboardVisible: boolean = false;
  private likePending: boolean = false;
  private repostPending: boolean = false;
  private bookmarkPending: boolean = false;
  private scroller: Scroller = new Scroller();
  private primaryScroller: Scroller = new Scroller();
  private repliesScroller: Scroller = new Scroller();
  private api: XApiClient = new XApiClient();
  private replyCapsuleSending: boolean = false;
  private gestureShareListening: boolean = false;
  private gestureSharePreviewPostId: string = '';
  private gestureSharePreviewUri: string = '';
  private initialLoadStarted: boolean = false;
  private routeNeedsContent: boolean = false;
  private alive: boolean = true;
  private detailVisible: boolean = true;
  private keyboardListenerRegistered: boolean = false;
  private keyboardObserverGeneration: number = 0;
  private continuationScrollOffset: number = 0;
  private lastPublishedContinuationOffset: number = -1;
  private gesturesShareCallback: (target: harmonyShare.SharableTarget) => void =
    (target: harmonyShare.SharableTarget): void => {
      this.sharePostByGesture(target);
    };
  private keyboardHeightChangeListener: (height: number) => void = (height: number): void => {
    if (this.detailVisible) {
      this.keyboardVisible = height > 0;
    }
  };

  private observeKeyboardState(): void {
    const generation: number = this.keyboardObserverGeneration + 1;
    this.keyboardObserverGeneration = generation;
    const hostContext: common.Context | undefined = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      return;
    }
    window.getLastWindow(hostContext).then((currentWindow): void => {
      if (generation !== this.keyboardObserverGeneration || !this.alive || !this.detailVisible) {
        return;
      }
      if (!this.keyboardListenerRegistered) {
        currentWindow.on('keyboardHeightChange', this.keyboardHeightChangeListener);
        this.keyboardListenerRegistered = true;
      }
      this.keyboardVisible =
        currentWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_KEYBOARD).bottomRect.height > 0;
    }).catch((): void => {
    });
  }

  private stopObservingKeyboard(): void {
    const generation: number = this.keyboardObserverGeneration + 1;
    this.keyboardObserverGeneration = generation;
    const hostContext: common.Context | undefined = this.getUIContext().getHostContext();
    if (hostContext !== undefined) {
      window.getLastWindow(hostContext).then((currentWindow): void => {
        if (generation !== this.keyboardObserverGeneration || this.detailVisible) {
          return;
        }
        currentWindow.off('keyboardHeightChange', this.keyboardHeightChangeListener);
        this.keyboardListenerRegistered = false;
      }).catch((): void => {
      });
    }
  }

  private cardMaterial(): uiMaterial.Material | undefined {
    if (!this.usesCardMaterial()) {
      return undefined;
    }
    return new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.REGULAR,
      applyShadow: true,
      colorInvert: true
    });
  }

  private usesCardMaterial(): boolean {
    return !this.transparentEmbeddedBackground() && !postCardUsesCustomSurface(this.pageBackgroundValue) &&
      deviceInfo.apiAvailable('26.0.0');
  }

  private inputMaterial(): uiMaterial.Material | undefined {
    if (!deviceInfo.apiAvailable('26.0.0')) {
      return undefined;
    }
    return new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.THIN,
      interactive: true,
      applyShadow: true,
      colorInvert: true,
      lightEffect: { color: this.accentColor }
    });
  }

  aboutToAppear(): void {
    this.alive = true;
    this.detailVisible = true;
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE);
    this.observeKeyboardState();
    this.readViewportShortSide();
    this.initializeReplyGripHand();
    // The route parameter is ready on the next frame after the destination
    // mounts, matching the child-page handoff used in PaperTalk.
    setTimeout((): void => {
      if (this.embedded && this.initialTweet !== null) {
        const param: PostDetailRouteParam = { tweet: this.initialTweet };
        this.applyRouteParam(param);
      } else {
        this.loadRouteParam();
      }
      this.startInitialLoad();
      this.registerGesturesShare();
    }, 50);
  }

  onWillApplyTheme(theme: Theme): void {
    this.avatarThemeDark = avatarTintIsDark(theme);
  }

  aboutToDisappear(): void {
    if (this.embedded && this.tweet !== null) {
      this.onEmbeddedPostChanged(this.tweet);
    }
    this.alive = false;
    this.detailVisible = false;
    this.replyCapsuleExpanded = false;
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.OFFSET);
    this.stopObservingKeyboard();
    this.keyboardVisible = false;
    this.setAutoPipArmed(false);
    GripHandManager.getInstance().stopFor(REPLY_CAPSULE_GRIP_KEY);
    this.unregisterGesturesShare();
  }

  private setAutoPipArmed(armed: boolean): void {
    const current: Tweet | null = this.tweet;
    if (current === null || current.attachments === undefined) {
      return;
    }
    for (let i: number = 0; i < current.attachments.length; i++) {
      const media: MediaAttachment = current.attachments[i];
      if (media.type !== 'video') {
        continue;
      }
      if (armed) {
        videoPipGate.armAuto(media.id);
      } else {
        videoPipGate.disarmAuto(media.id);
      }
    }
  }

  private onDetailScroll(scrollOffset: number): void {
    if (!this.detailVisible || scrollOffset === 0) {
      return;
    }
    // Positive means the content is moving up: the reader is scrolling from
    // the focal video toward the replies. Scrolling back up disarms the
    // automatic hand-off until the reader moves down again.
    this.setAutoPipArmed(scrollOffset > 0);
    this.publishContinuationState(false);
  }

  private onDetailWillHide(): void {
    this.detailVisible = false;
    // Keep the detail page in resize mode while a full reply destination is
    // stacked above it, so returning with the keyboard open does not lift the
    // whole page.
    this.setAutoPipArmed(false);
  }

  private onDetailShown(): void {
    this.alive = true;
    this.detailVisible = true;
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE);
    this.observeKeyboardState();
    // A page restored from another destination must not inherit a stale scroll
    // trigger from before it was hidden.
    this.setAutoPipArmed(false);
    this.publishContinuationState(true);
  }

  private dismissExpandedReply(): void {
    this.replyComposerDismissRequest = this.replyComposerDismissRequest + 1;
    try {
      inputMethod.getController().hideTextInput().catch((): void => {
      });
    } catch (error) {
    }
  }

  private currentContinuationOffset(): number {
    try {
      if (this.useWideThreadLayout()) {
        return Math.max(0, this.primaryScroller.currentOffset().yOffset);
      }
      return Math.max(0, this.scroller.currentOffset().yOffset);
    } catch (error) {
      return 0;
    }
  }

  private updateReadAloudFabMode(scrollOffset: number): void {
    if (scrollOffset === 0 || this.refreshing) {
      return;
    }
    this.readAloudFabMode = scrollOffset > 0 ? 'refresh' : 'read';
  }

  private onPrimaryDetailScroll(scrollOffset: number): void {
    this.onDetailScroll(scrollOffset);
    this.updateReadAloudFabMode(scrollOffset);
  }

  private onRepliesDetailScroll(scrollOffset: number): void {
    this.updateReadAloudFabMode(scrollOffset);
  }

  private publishContinuationState(force: boolean): void {
    const current: Tweet | null = this.tweet;
    if (current === null) {
      return;
    }
    const offset: number = this.currentContinuationOffset();
    if (!force && Math.abs(offset - this.lastPublishedContinuationOffset) < 24) {
      return;
    }
    this.lastPublishedContinuationOffset = offset;
    continuationStore.publishPost(current.id, offset, this.replySortMode);
  }

  private restoreContinuationScroll(): void {
    const offset: number = this.continuationScrollOffset;
    if (offset <= 0) {
      return;
    }
    this.continuationScrollOffset = 0;
    setTimeout((): void => {
      try {
        if (this.useWideThreadLayout()) {
          this.primaryScroller.scrollTo({ xOffset: 0, yOffset: offset, animation: { duration: 180 } });
        } else {
          this.scroller.scrollTo({ xOffset: 0, yOffset: offset, animation: { duration: 180 } });
        }
        this.lastPublishedContinuationOffset = offset;
      } catch (error) {
      }
    }, 160);
  }

  private useWideThreadLayout(): boolean {
    return ResponsiveLayout.isLarge(this.breakpoint);
  }

  private useWideMediaLayout(): boolean {
    return !this.embedded && this.useWideThreadLayout() && this.tweet !== null &&
      (this.tweet.attachments?.length ?? 0) > 0 && this.tweet.presentation?.visibility?.hidden !== true;
  }

  private readViewportShortSide(): void {
    try {
      const uiContext: UIContext = this.getUIContext();
      const displayObject: display.Display = display.getDefaultDisplaySync();
      const widthVp: number = uiContext.px2vp(displayObject.width);
      const heightVp: number = uiContext.px2vp(displayObject.height);
      this.viewportShortSide = Math.min(widthVp, heightVp);
    } catch (error) {
      this.viewportShortSide = 360;
    }
  }

  private replyCapsuleWidth(): number {
    return Math.max(240, this.viewportShortSide * 0.8);
  }

  private replyCapsuleAlign(): HorizontalAlign {
    if (!this.useWideThreadLayout()) {
      return HorizontalAlign.Center;
    }
    return this.replyCapsuleHand === 'left' ? HorizontalAlign.Start : HorizontalAlign.End;
  }

  private async initializeReplyGripHand(): Promise<void> {
    const context: common.Context | undefined = this.getUIContext().getHostContext();
    if (context !== undefined) {
      await GripHandManager.getInstance().load(context);
      this.replyGripHandEnabled = GripHandManager.getInstance().isGripHandEnabled();
      this.replyPreferredHand = GripHandManager.getInstance().getPreferredHand();
    }
    this.replyCapsuleHand = GripHandManager.getInstance().getLastHand();
    if (this.replyGripHandEnabled && this.useWideThreadLayout()) {
      GripHandManager.getInstance().startFor(REPLY_CAPSULE_GRIP_KEY, (hand: string): void => {
        this.onReplyGripHandChanged(hand);
      });
    } else {
      GripHandManager.getInstance().stopFor(REPLY_CAPSULE_GRIP_KEY);
    }
  }

  private onPostDetailBreakpointChanged(): void {
    this.readViewportShortSide();
    this.initializeReplyGripHand();
  }

  private onReplyGripHandEnabledChanged(): void {
    if (this.replyGripHandEnabled && this.useWideThreadLayout()) {
      this.initializeReplyGripHand();
      return;
    }
    GripHandManager.getInstance().stopFor(REPLY_CAPSULE_GRIP_KEY);
    this.onReplyPreferredHandChanged();
  }

  private onReplyPreferredHandChanged(): void {
    if (!this.replyGripHandEnabled) {
      this.replyCapsuleHand = this.replyPreferredHand;
    }
  }

  private onReplyGripHandChanged(hand: string): void {
    if (!this.replyGripHandEnabled) { return; }
    this.replyCapsuleHand = hand;
  }

  private applyRouteParam(param: PostDetailRouteParam): void {
    this.routeNeedsContent = param.refreshContent === true;
    const firstRoute: boolean = this.tweet === null;
    const previousId: string = this.tweet === null ? '' : this.tweet.id;
    this.tweet = param.tweet;
    if (!this.embedded && previousId !== param.tweet.id) {
      browsingHistoryStore.record(getContext(this) as common.UIAbilityContext, param.tweet);
    }
    if (previousId !== param.tweet.id) {
      this.wideMediaIndex = 0;
      this.resetHeroTranslation();
    }
    this.sharedElementId = param.sharedElementId ?? '';
    this.returnToMain = param.returnToMain === true;
    if (param.continuationReplySortMode === REPLY_SORT_RECENT ||
      param.continuationReplySortMode === REPLY_SORT_RELEVANCE ||
      param.continuationReplySortMode === REPLY_SORT_LIKES) {
      this.replySortMode = param.continuationReplySortMode;
    }
    this.continuationScrollOffset = param.continuationScrollOffset === undefined ? 0 :
      Math.max(0, param.continuationScrollOffset);
    this.lastPublishedContinuationOffset = -1;
    this.syncActionStates(param.tweet);
    this.prepareGestureSharePreview();
    this.publishContinuationState(true);
    this.tryAutoHeroTranslation();
    if (firstRoute && this.sharedElementId.length > 0) {
      this.transitionSettled = false;
      setTimeout((): void => {
        if (this.alive) {
          this.transitionSettled = true;
        }
      }, SHARED_ELEMENT_DURATION);
    }
  }

  private startInitialLoad(): void {
    if (this.initialLoadStarted || this.tweet === null) {
      return;
    }
    this.initialLoadStarted = true;
    this.threadLoading = true;
    this.loadLiveThread();
  }

  private loadRouteParam(): void {
    const params: PostDetailRouteParam[] =
      this.pageStack.getParamByName('PostDetail') as PostDetailRouteParam[];
    if (params === undefined || params === null || params.length === 0) {
      return;
    }
    const param: PostDetailRouteParam = params[params.length - 1];
    if (param !== undefined && param !== null) {
      this.applyRouteParam(param);
    }
  }

  private syncActionStates(tweet: Tweet): void {
    postLikeStore.apply(tweet);
    this.liked = tweet.liked;
    this.likeCount = tweet.metrics.likeCount;
    this.reposted = tweet.reposted;
    this.bookmarked = tweet.bookmarked ?? false;
  }

  private syncLikeState(): void {
    const post: Tweet | null = this.tweet;
    if (post === null) { return; }
    postLikeStore.apply(post);
    this.liked = post.liked;
    this.likeCount = post.metrics.likeCount;
  }

  // Keep the route-delivered hero structure intact during and after the
  // shared-element transition. Live data may refresh counters and viewer
  // state, but must not replace text/media fields and trigger a second layout.
  private applyLivePostState(live: Tweet): void {
    const current: Tweet | null = this.tweet;
    if (current === null || current.id !== live.id) {
      return;
    }
    if (!this.embedded) { browsingHistoryStore.enrich(getContext(this) as common.UIAbilityContext, live); }
    if (this.routeNeedsContent) {
      this.routeNeedsContent = false;
      this.tweet = live;
      postViewCounts.remember(live.id, live.metrics.viewCount);
      this.syncActionStates(live);
      return;
    }
    const stable: Tweet = {
      id: current.id,
      author: current.author,
      text: current.text,
      language: (live.language ?? '').length > 0 ? live.language : current.language,
      createdAt: live.createdAt.length > 0 ? live.createdAt : current.createdAt,
      metrics: live.metrics,
      liked: live.liked,
      reposted: live.reposted,
      bookmarked: live.bookmarked,
      isReply: live.isReply,
      replyToTweetId: live.replyToTweetId,
      replyToUsername: live.replyToUsername,
      conversationId: live.conversationId,
      isRepost: current.isRepost,
      repostAuthor: current.repostAuthor,
      repostText: current.repostText,
      quotedTweet: current.quotedTweet,
      attachments: current.attachments,
      article: live.article ?? current.article,
      presentation: refreshedPostPresentation(current.presentation, live.presentation),
      poll: live.poll ?? current.poll,
      card: live.card ?? current.card
    };
    this.tweet = stable;
    postViewCounts.remember(live.id, live.metrics.viewCount);
    this.syncActionStates(stable);
  }

  private isXPostId(value: string): boolean {
    if (value.length === 0) {
      return false;
    }
    for (let i = 0; i < value.length; i++) {
      const code: number = value.charCodeAt(i);
      if (code < 48 || code > 57) {
        return false;
      }
    }
    return true;
  }

  private async loadLiveThread(): Promise<void> {
    const current: Tweet | null = this.tweet;
    if (current === null) {
      return;
    }
    const generation: number = ++this.threadLoadGeneration;
    this.threadNextToken = '';
    this.threadLoadingMore = false;
    this.threadLoadMoreFailed = false;
    this.discoverMoreStarted = false;
    this.discoverMore = [];
    try {
      const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      await authStore.load(context);
      xPrivateClient.load(context);
      if (authStore.isSignedIn()) {
        this.api.setToken(authStore.getToken());
        this.api.setUser(authStore.getUserId());
        this.currentProfile = await this.api.profile();
      }
      if (!this.alive || generation !== this.threadLoadGeneration) {
        return;
      }
      if (!this.isXPostId(current.id)) {
        this.threadStatus = this.text($r('app.string.post_detail_local_only'));
        return;
      }
      if (!authStore.isSignedIn() && !xPrivateClient.isSignedIn()) {
        this.threadStatus = this.text($r('app.string.post_detail_sign_in'));
        return;
      }
      // Private session first: one call returns the canonical post plus the
      // conversation, which is exactly what this page renders.
      if (xPrivateClient.isSignedIn()) {
        await this.loadThreadViaPrivate(current.id, this.privateReplyRankingMode(), generation);
        this.loadAuthorFollowState();
        return;
      }
      const latest: Tweet | null = await this.api.tweetById(current.id);
      if (!this.alive || generation !== this.threadLoadGeneration) {
        return;
      }
      if (latest !== null) {
        this.applyLivePostState(latest);
      }
      const liveReplies: Tweet[] | null = await this.api.conversationReplies(current.id);
      if (!this.alive || generation !== this.threadLoadGeneration) {
        return;
      }
      if (liveReplies !== null) {
        this.replies = liveReplies;
        this.threadStatus = liveReplies.length > 0 ? this.text($r('app.string.post_detail_live')) :
          this.text($r('app.string.post_detail_no_replies'));
      } else {
        this.replies = [];
        this.threadStatus = this.text($r('app.string.post_detail_unavailable'));
      }
    } catch (error) {
      if (this.alive && generation === this.threadLoadGeneration) {
        this.replies = [];
        this.threadStatus = this.text($r('app.string.post_detail_unavailable'));
      }
    } finally {
      if (this.alive && generation === this.threadLoadGeneration) {
        this.threadLoading = false;
        this.refreshing = false;
        this.restoreContinuationScroll();
      }
    }
  }

  // The follow button in the author row needs the viewer-scoped follow state,
  // which only the profile query carries; the post payload has no such field.
  private async loadAuthorFollowState(): Promise<void> {
    const current: Tweet | null = this.tweet;
    if (current === null || current.author.username.length === 0) {
      return;
    }
    const result: XPrivateResult = await xPrivateClient.userByScreenName(current.author.username);
    const authorProfile: UserProfile | null = result.ok ? XUserParser.parse(result.body) : null;
    if (authorProfile !== null) {
      this.authorFollowing = authorProfile.following === true;
      this.authorUserId = authorProfile.id;
    }
  }

  private async toggleAuthorFollow(): Promise<void> {
    const current: Tweet | null = this.tweet;
    if (this.authorFollowPending || current === null) {
      return;
    }
    const userId: string = this.authorUserId.length > 0 ? this.authorUserId : current.author.id;
    if (userId.length === 0) {
      promptAction.showToast({
        message: this.text($r('app.string.profile_not_ready')),
        duration: 2000
      });
      return;
    }
    if (!xPrivateClient.isSignedIn()) {
      promptAction.showToast({
        message: this.text($r('app.string.profile_follow_sign_in')),
        duration: 2000
      });
      return;
    }
    const next: boolean = !this.authorFollowing;
    this.authorFollowPending = true;
    const result: XPrivateResult = await xPrivateClient.follow(userId, next);
    this.authorFollowPending = false;
    if (!result.ok) {
      promptAction.showToast({
        message: this.text($r('app.string.profile_follow_failed')) + ' · HTTP ' + result.status,
        duration: 2000
      });
      return;
    }
    this.authorFollowing = next;
  }

  private isOwnPost(): boolean {
    const current: Tweet | null = this.tweet;
    let viewerId: string = authStore.getUserId();
    if (viewerId.length === 0 && xPrivateClient.isSignedIn()) {
      viewerId = xPrivateClient.viewerId();
    }
    return current !== null && viewerId.length > 0 && viewerId === current.author.id;
  }

  private hasPostMenu(): boolean {
    const current: Tweet | null = this.tweet;
    return this.isOwnPost() || (current !== null && this.isXPostId(current.id));
  }

  private postMenuItems(): MenuElement[] {
    const items: MenuElement[] = [];
    const current: Tweet | null = this.tweet;
    if (current !== null && this.isXPostId(current.id)) {
      items.push({
        value: this.text($r('app.string.post_edit_history_title')),
        action: (): void => {
          this.openEditHistory();
        }
      });
    }
    if (!this.isOwnPost()) {
      return items;
    }
    items.push({
      value: this.text(this.postPinned ? $r('app.string.post_unpin') : $r('app.string.post_pin')),
      action: (): void => {
        this.updatePinnedState(!this.postPinned);
      }
    });
    items.push({
      value: this.text($r('app.string.post_reply_control_everyone')),
      action: (): void => {
        this.updateReplyControl('');
      }
    });
    items.push({
      value: this.text($r('app.string.post_reply_control_followers')),
      action: (): void => {
        this.updateReplyControl('Community');
      }
    });
    items.push({
      value: this.text($r('app.string.post_reply_control_mentioned')),
      action: (): void => {
        this.updateReplyControl('ByInvitation');
      }
    });
    items.push({
      value: this.text($r('app.string.menu_delete_post')),
      action: (): void => {
        this.confirmDeletePost();
      }
    });
    return items;
  }

  private openEditHistory(): void {
    const current: Tweet | null = this.tweet;
    if (current === null || !this.isXPostId(current.id)) {
      return;
    }
    const param: EditHistoryRouteParam = { tweet: current };
    this.setAutoPipArmed(false);
    if (this.embedded) { this.onEmbeddedNavigate(); }
    this.pageStack.pushPath({ name: 'EditHistory', param: param });
  }

  private async updatePinnedState(pinned: boolean): Promise<void> {
    const current: Tweet | null = this.tweet;
    if (current === null || this.postActionPending) {
      return;
    }
    this.postActionPending = true;
    const result: XPrivateResult = await xPrivateClient.pinTweet(current.id, pinned);
    this.postActionPending = false;
    if (!result.ok) {
      promptAction.showToast({
        message: this.text($r('app.string.post_advanced_action_failed')) + ' · HTTP ' + result.status,
        duration: 2200
      });
      return;
    }
    this.postPinned = pinned;
    promptAction.showToast({
      message: this.text(pinned ? $r('app.string.post_pinned_done') : $r('app.string.post_unpinned_done')),
      duration: 1500
    });
  }

  private async updateReplyControl(policy: string): Promise<void> {
    const current: Tweet | null = this.tweet;
    if (current === null || this.postActionPending) {
      return;
    }
    this.postActionPending = true;
    const result: XPrivateResult = policy.length === 0 ?
      await xPrivateClient.clearTweetConversationControl(current.id) :
      await xPrivateClient.setTweetConversationControl(current.id, policy);
    this.postActionPending = false;
    if (!result.ok) {
      promptAction.showToast({
        message: this.text($r('app.string.post_advanced_action_failed')) + ' · HTTP ' + result.status,
        duration: 2200
      });
      return;
    }
    promptAction.showToast({ message: this.text($r('app.string.post_reply_control_done')), duration: 1500 });
  }

  private async confirmDeletePost(): Promise<void> {
    const current: Tweet | null = this.tweet;
    if (current === null) {
      return;
    }
    const dialog: promptAction.ShowDialogSuccessResponse = await promptAction.showDialog({
      title: this.text($r('app.string.menu_delete_post')),
      message: this.text($r('app.string.delete_post_confirm')),
      buttons: [
        { text: this.text($r('app.string.compose_cancel')), color: '#666666' },
        { text: this.text($r('app.string.menu_delete_post')), color: '#E0245E' }
      ]
    });
    if (dialog.index !== 1) {
      return;
    }
    const result: XPrivateResult = await xPrivateClient.deleteTweet(current.id);
    if (!result.ok) {
      promptAction.showToast({
        message: this.text($r('app.string.delete_post_failed')) + ' · HTTP ' + result.status,
        duration: 2000
      });
      return;
    }
    promptAction.showToast({ message: this.text($r('app.string.delete_post_done')), duration: 1500 });
    this.notifyPostsChanged();
    this.setAutoPipArmed(false);
    ResponsiveLayout.closeContentDestination(this.pageStack);
  }

  // Keep the root timeline and the Me surface coherent with a confirmed
  // delete. The same counter is emitted after a successful composer publish,
  // so every feed refresh follows one account-scoped update contract.
  private notifyPostsChanged(): void {
    const current: number = AppStorage.get<number>('harmonyx.posts_changed') ?? 0;
    AppStorage.setOrCreate<number>('harmonyx.posts_changed', current + 1);
  }

  private async loadThreadViaPrivate(tweetId: string, rankingMode: string, generation: number): Promise<void> {
    const result: XPrivateResult = await xPrivateClient.tweetDetail(tweetId, rankingMode);
    if (!this.alive || generation !== this.threadLoadGeneration) {
      return;
    }
    if (!result.ok) {
      this.replies = [];
      this.threadStatus = result.status === 401 || result.status === 403 ?
        this.text($r('app.string.private_session_expired')) :
        this.text($r('app.string.post_detail_unavailable'));
      return;
    }
    const page: TweetDetailPage | null = XTimelineParser.parseTweetDetail(result.body, tweetId);
    if (page === null || (page.focal === null && page.replies.length === 0 && page.discoverMore.length === 0 &&
      page.nextToken.length === 0)) {
      this.replies = [];
      this.threadStatus = this.text($r('app.string.post_detail_unavailable'));
      return;
    }
    if (page.focal !== null) {
      this.applyLivePostState(page.focal);
    }
    this.replies = page.replies;
    this.discoverMore = page.discoverMore;
    this.threadNextToken = page.nextToken;
    this.discoverMoreStarted = page.discoverMoreStarted;
    this.threadStatus = this.replies.length > 0 ? this.text($r('app.string.post_detail_live')) :
      this.text($r('app.string.post_detail_no_replies'));
  }

  private mergeThreadPosts(current: Tweet[], incoming: Tweet[]): Tweet[] {
    const merged: Map<string, Tweet> = new Map<string, Tweet>();
    for (let i: number = 0; i < current.length; i++) {
      merged.set(current[i].id, current[i]);
    }
    for (let i: number = 0; i < incoming.length; i++) {
      merged.set(incoming[i].id, incoming[i]);
    }
    const posts: Tweet[] = [];
    merged.forEach((post: Tweet): void => { posts.push(post); });
    return posts;
  }

  private async loadMoreThread(): Promise<void> {
    const current: Tweet | null = this.tweet;
    if (current === null || this.threadLoading || this.refreshing || this.threadLoadingMore ||
      this.threadNextToken.length === 0 || !xPrivateClient.isSignedIn()) {
      return;
    }
    const generation: number = this.threadLoadGeneration;
    const cursor: string = this.threadNextToken;
    this.threadLoadingMore = true;
    this.threadLoadMoreFailed = false;
    try {
      const result: XPrivateResult = await xPrivateClient.tweetDetail(current.id, this.privateReplyRankingMode(), cursor);
      if (!this.alive || generation !== this.threadLoadGeneration) {
        return;
      }
      const previous: Tweet[] = [current, ...this.replies];
      const page: TweetDetailPage | null = result.ok ?
        XTimelineParser.parseTweetDetail(result.body, current.id, previous, this.discoverMoreStarted) : null;
      if (page === null) {
        this.threadLoadMoreFailed = true;
        return;
      }
      this.replies = this.mergeThreadPosts(this.replies, page.replies);
      const replyIds: Set<string> = new Set<string>();
      for (let i: number = 0; i < this.replies.length; i++) {
        replyIds.add(this.replies[i].id);
      }
      this.discoverMore = this.mergeThreadPosts(this.discoverMore, page.discoverMore)
        .filter((post: Tweet): boolean => !replyIds.has(post.id) && post.id !== current.id);
      this.threadNextToken = page.nextToken === cursor ? '' : page.nextToken;
      this.discoverMoreStarted = page.discoverMoreStarted;
      this.threadStatus = this.replies.length > 0 ? this.text($r('app.string.post_detail_live')) :
        this.text($r('app.string.post_detail_no_replies'));
    } catch (error) {
      if (this.alive && generation === this.threadLoadGeneration) {
        this.threadLoadMoreFailed = true;
      }
    } finally {
      if (this.alive && generation === this.threadLoadGeneration) {
        this.threadLoadingMore = false;
      }
    }
  }

  private orderedReplies(): ThreadReplyRow[] {
    const current: Tweet | null = this.tweet;
    return ThreadReplyOrder.order(current === null ? '' : current.id, this.sortedReplies());
  }

  private onPromotionChanged(): void {
    // Rebuilt in place by the comment list; nothing to prefetch.
  }

  private promotionPlan(): XXAuthPromotionPlan {
    if (this.promotionPostJson.length === 0) { return new XXAuthPromotionPlan(); }
    try {
      const parsed: XXAuthPromotionPlan = JSON.parse(this.promotionPostJson) as XXAuthPromotionPlan;
      if (parsed === null || !(parsed.posts instanceof Array)) { return new XXAuthPromotionPlan(); }
      return parsed;
    } catch (error) { return new XXAuthPromotionPlan(); }
  }

  private hidePromotionPost(): void {
    if (this.promotionPlan().dismissible === false) { return; }
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    xxAuthPopupStore.hidePromotion(context, Date.now(), this.promotionPostJson);
    AppStorage.setOrCreate<string>(XXAUTH_PROMOTION_POST, '');
  }

  private hidePromotionForSession(): void {
    if (this.promotionPlan().dismissible === false) { return; }
    xxAuthPopupStore.hidePromotionForSession();
    AppStorage.setOrCreate<string>(XXAUTH_PROMOTION_POST, '');
  }

  private openPromotionLink(url: string): void {
    if (url.length === 0) { return; }
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    context.startAbility({ action: 'ohos.want.action.viewData',
      entities: ['entity.system.browsable'], uri: url }).catch((): void => { });
  }

  @Builder
  private PromotionRow(post: XXAuthPromotionPost): void {
    PromotionPostCard({
      post: post,
      onOpen: (): void => { this.openPromotionLink(post.link); },
      onHideSession: (): void => { this.hidePromotionForSession(); },
      onHideWeek: (): void => { this.hidePromotionPost(); }
    })
  }

  // The promotion only ever lands before a top-level reply, so the thread
  // connectors of a nested answer stay attached to their parent.
  private commentRows(): CommentTimelineRow[] {
    const rows: CommentTimelineRow[] = [];
    const replies: ThreadReplyRow[] = this.orderedReplies().filter((row: ThreadReplyRow): boolean =>
      !this.filterHideAds || !isAdPost(row.tweet.presentation));
    if (this.embedded) { return rows; }
    const anchors: number[] = [];
    for (let i: number = 1; i < replies.length; i++) {
      if (!replies[i].isNestedReply) { anchors.push(i); }
    }
    const plan: XXAuthPromotionPlan = this.promotionPlan();
    const placement: Map<number, XXAuthPromotionPost> = new Map();
    if (anchors.length > 0 && plan.posts.length > 0 && plan.commentCount > 0) {
      const count: number = Math.min(plan.commentCount, plan.posts.length, anchors.length);
      const salt: string = 'comments:' + (this.tweet === null ? '' : this.tweet.id);
      const slots: XXAuthPromotionSlot[] = XXAuthPromotionInjector.slots(anchors.length,
        plan.posts, count, salt);
      for (let i: number = 0; i < slots.length; i++) {
        const at: number = Math.max(0, Math.min(anchors.length, slots[i].index) - 1);
        placement.set(anchors[at], slots[i].post);
      }
    }
    for (let i: number = 0; i < replies.length; i++) {
      const injected: XXAuthPromotionPost | undefined = placement.get(i);
      if (injected !== undefined) {
        const promotion: CommentTimelineRow = new CommentTimelineRow();
        promotion.key = 'promo:' + injected.fingerprint + ':' + i.toString();
        promotion.promotion = injected;
        rows.push(promotion);
      }
      const row: CommentTimelineRow = new CommentTimelineRow();
      row.key = replies[i].tweet.id;
      row.reply = replies[i];
      rows.push(row);
    }
    return rows;
  }

  @Builder
  private CommentReplyRow(row: ThreadReplyRow): void {
    Column({ space: 0 }) {
      if (row.isNestedReply && !row.connectAbove) {
        Text(row.replyingToUsername.length > 0 ?
          this.text($r('app.string.compose_replying_to')) + row.replyingToUsername :
          this.text($r('app.string.post_detail_reply_to_comment'))).fontFamily(this.appFontFamily)
          .width('100%')
          .fontSize($r('sys.float.Body_S'))
          .fontColor(pageTextColor($r('app.color.text_secondary'), this.embedded ? '' : this.pageBackgroundValue, postCardSurfaceColor($r('app.color.bg_card'), this.pageBackgroundValue)))
          .padding({ left: 10, top: 4 })
      }
      TweetCard({
        tweet: row.tweet,
        transparentBackground: this.transparentEmbeddedBackground(),
        sharedElementId: this.tweet === null ? '' : 'post-reply-' + this.tweet.id + '-' + row.tweet.id,
        showActions: true,
        connectAbove: row.connectAbove,
        connectBelow: row.connectBelow,
        onOpen: (selected: Tweet, sourceId: string): void => this.openPost(selected, sourceId),
        onAuthorTapped: (reply: Tweet): void => this.openUser(reply.author),
        onMentionTapped: (handle: string): void => this.openMention(handle)
      })
    }
    .width('100%')
  }

  // The private detail query asks X for either relevance or recency before the
  // reply tree is built.  X exposes no likes-ranking token for this endpoint,
  // so "most liked" is an honest client-side presentation of the actual rows
  // returned by X, never a claimed server-side sort.
  private sortedReplies(): Tweet[] {
    const ordered: Tweet[] = [];
    if (this.replySortMode === REPLY_SORT_RECENT) {
      for (let index: number = this.replies.length - 1; index >= 0; index--) {
        ordered.push(this.replies[index]);
      }
      return ordered;
    }
    for (let index: number = 0; index < this.replies.length; index++) {
      ordered.push(this.replies[index]);
    }
    if (this.replySortMode !== REPLY_SORT_LIKES) {
      return ordered;
    }
    // Use an explicit insertion pass rather than mutating the API result: the
    // same reply list is used by refresh, read-aloud and the quote entry.
    for (let index: number = 1; index < ordered.length; index++) {
      const candidate: Tweet = ordered[index];
      let previous: number = index - 1;
      while (previous >= 0 && ordered[previous].metrics.likeCount < candidate.metrics.likeCount) {
        ordered[previous + 1] = ordered[previous];
        previous--;
      }
      ordered[previous + 1] = candidate;
    }
    return ordered;
  }

  private replySortLabel(): Resource {
    if (this.replySortMode === REPLY_SORT_RECENT) {
      return $r('app.string.post_detail_sort_recent');
    }
    if (this.replySortMode === REPLY_SORT_LIKES) {
      return $r('app.string.post_detail_sort_likes');
    }
    return $r('app.string.post_detail_sort_relevance');
  }

  private privateReplyRankingMode(): string {
    return this.replySortMode === REPLY_SORT_RECENT ? 'Recency' : 'Relevance';
  }

  private chooseReplySort(mode: string): void {
    if (this.replySortMode === mode) {
      this.replySortSheetVisible = false;
      return;
    }
    this.replySortMode = mode;
    this.replySortSheetVisible = false;
    this.publishContinuationState(true);
    hapticTick();
    // Relevance and recency deliberately fetch a new X reply timeline instead
    // of simply reshuffling what happened to be loaded.  The likes view uses
    // the genuine like counters on that current X response.
    if (xPrivateClient.isSignedIn() && this.isXPostId(this.tweet === null ? '' : this.tweet.id)) {
      this.threadLoading = true;
      this.loadLiveThread();
    }
  }

  private openPostInteractions(): void {
    const current: Tweet | null = this.tweet;
    if (current === null) {
      return;
    }
    const param: PostInteractionsRouteParam = { tweet: current };
    this.setAutoPipArmed(false);
    if (this.embedded) { this.onEmbeddedNavigate(); }
    this.pageStack.pushPath({ name: 'PostInteractions', param: param });
  }

  private openGrok(): void {
    const current: Tweet | null = this.tweet;
    if (current === null) {
      return;
    }
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const settings: GrokSettings = grokSettingsStore.load(context);
    const param: GrokRouteParam = {
      tweet: current,
      mode: settings.mode === GROK_MODE_WEB ? GROK_MODE_WEB : GROK_MODE_API
    };
    this.setAutoPipArmed(false);
    if (this.embedded) { this.onEmbeddedNavigate(); }
    this.pageStack.pushPath({ name: 'Grok', param: param });
  }

  private onRefresh(): void {
    this.refreshing = true;
    this.loadLiveThread();
  }

  private text(resource: Resource): string {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    return context.resourceManager.getStringSync(resource);
  }

  private postTimePrefix(): string {
    const time: string = formatPostDetailTime(this.tweet?.createdAt ?? '', this.postTimeNow);
    return time.length > 0 ? time + ' · ' : '';
  }

  // The detail hero is not a TweetCard, so it owns the same translation
  // request/result state explicitly. This keeps the visible result in ArkUI
  // while replies use the shared TweetCard path below.
  private onHeroTweetChanged(): void {
    const current: Tweet | null = this.tweet;
    if (current === null) { this.resetHeroTranslation(); return; }
    if (this.heroTranslationPostId !== current.id && (this.heroTranslating || this.heroTranslatedText.length > 0)) {
      this.resetHeroTranslation();
    } else if (this.heroTranslationWasAutomatic) {
      const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      if (!translationStore.load(context).shouldAutomaticallyTranslate(current.language ?? '')) {
        this.resetHeroTranslation();
      }
    }
    this.tryAutoHeroTranslation();
  }

  private onTranslationSettingsRevisionChanged(): void {
    this.resetHeroTranslation();
    this.tryAutoHeroTranslation();
  }

  private onTranslationAppLocaleChanged(): void {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    if (translationStore.load(context).targetLanguage === TARGET_LANGUAGE_APP) {
      this.resetHeroTranslation();
      this.tryAutoHeroTranslation();
    }
  }

  private resetHeroTranslation(): void {
    this.heroTranslationRequestGeneration++;
    this.heroTranslating = false;
    this.heroTranslatedText = '';
    this.heroTranslationWasAutomatic = false;
    this.lastAutoTranslationRevision = -1;
    this.lastAutoTranslationPostId = '';
  }

  private tryAutoHeroTranslation(): void {
    const current: Tweet | null = this.tweet;
    if (!this.translationAutoEnabled || current === null || this.heroTranslating ||
      this.heroTranslatedText.length > 0 ||
      (this.lastAutoTranslationRevision === this.translationSettingsRevision &&
        this.lastAutoTranslationPostId === current.id)) {
      return;
    }
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    if (!translationStore.load(context).shouldAutomaticallyTranslate(current.language ?? '')) { return; }
    this.lastAutoTranslationRevision = this.translationSettingsRevision;
    this.lastAutoTranslationPostId = current.id;
    this.runHeroTranslation(true);
  }

  private async runHeroTranslation(automatic: boolean = false): Promise<void> {
    const current: Tweet | null = this.tweet;
    if (current === null || this.heroTranslating) {
      return;
    }
    if (this.heroTranslatedText.length > 0) {
      if (automatic) {
        return;
      }
      this.heroTranslatedText = '';
      return;
    }
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const settings: TranslationSettings = translationStore.load(context);
    if (automatic && !settings.shouldAutomaticallyTranslate(current.language ?? '')) {
      return;
    }
    if (!settings.isRunnable()) {
      if (!automatic) {
        promptAction.showToast({
          message: this.text($r('app.string.post_translate_no_key')),
          duration: 2600
        });
      }
      return;
    }
    const postId: string = current.id;
    const generation: number = this.heroTranslationRequestGeneration;
    this.heroTranslationPostId = postId;
    this.heroTranslationWasAutomatic = automatic;
    this.heroTranslating = true;
    const result: TranslationResult = await translationService.translate(postId, current.text, settings,
      current.language ?? '');
    if (generation !== this.heroTranslationRequestGeneration || this.tweet === null || this.tweet.id !== postId) {
      return;
    }
    this.heroTranslating = false;
    if (result.ok) {
      this.heroTranslatedText = result.text;
      return;
    }
    if (!automatic) {
      promptAction.showToast({
        message: this.text(result.errorText === 'no_session' ?
          $r('app.string.post_translate_x_login') : $r('app.string.post_translate_failed')),
        duration: 2600
      });
    }
  }

  // The quoted block inside this post is a list item of its own, so opening the
  // quoted post expands from that block.
  private heroQuotedElementId(): string {
    if (this.tweet === null || this.tweet.quotedTweet === undefined || this.sharedElementId.length === 0) {
      return '';
    }
    return this.sharedElementId + '-quote-' + this.tweet.quotedTweet.id;
  }

  private openPost(tweet: Tweet, sourceId: string): void {
    this.setAutoPipArmed(false);
    if (sourceId.length === 0) {
      const plain: PostDetailRouteParam = { tweet: tweet };
      if (this.embedded) { this.onEmbeddedNavigate(); }
      NavigationGuard.pushPath<PostDetailRouteParam>(this.pageStack, { name: 'PostDetail', param: plain },
        (route: PostDetailRouteParam): string => route.tweet.id);
      return;
    }
    const param: PostDetailRouteParam = { tweet: tweet, sharedElementId: sourceId };
    this.getUIContext().animateTo({ curve: LIST_EXPAND_PUSH_CURVE }, (): void => {
      if (this.embedded) { this.onEmbeddedNavigate(); }
      NavigationGuard.pushPath<PostDetailRouteParam>(this.pageStack, { name: 'PostDetail', param: param },
        (route: PostDetailRouteParam): string => route.tweet.id, false);
    });
  }

  private openAuthor(): void {
    if (this.tweet === null) {
      return;
    }
    this.setAutoPipArmed(false);
    this.openUser(this.tweet.author);
  }

  private openUser(author: TweetAuthor): void {
    const param: UserDetailRouteParam = { author: author, posts: [] };
    if (this.embedded) { this.onEmbeddedNavigate(); }
    this.pageStack.pushPath({ name: 'UserDetail', param: param });
  }

  // A mention only carries the handle, so the profile page resolves the rest
  // from the screen name.
  private openMention(handle: string): void {
    if (handle.length === 0) {
      return;
    }
    this.setAutoPipArmed(false);
    const author: TweetAuthor = {
      id: '',
      name: handle,
      username: handle,
      avatarColor: this.accentColor,
      verified: false
    };
    const param: UserDetailRouteParam = { author: author, posts: [] };
    if (this.embedded) { this.onEmbeddedNavigate(); }
    this.pageStack.pushPath({ name: 'UserDetail', param: param });
  }

  private replyComposerContext(): ReplyComposerContext {
    const profile: UserProfile | null = this.currentProfile;
    const fallbackName: string = authStore.getUsername().length > 0 ? authStore.getUsername() :
      this.text($r('app.string.tab_me'));
    return {
      replyToId: this.tweet === null ? '' : this.tweet.id,
      replyToUser: this.tweet === null ? '' : this.tweet.author.username,
      avatarUrl: profile === null || profile.avatarUrl === undefined ? '' : profile.avatarUrl, verifiedType: profile?.verifiedType, avatarShape: profile?.avatarShape,
      avatarName: profile === null ? fallbackName : profile.name,
      avatarColor: this.accentColor,
      accentColor: this.accentColor
    };
  }

  private openReplyComposer(text: string, imageUri: string, gifUri: string): void {
    if (this.tweet !== null && !canPostAction(this.tweet, 'reply')) { return; }
    const context: ReplyComposerContext = this.replyComposerContext();
    const param: ReplyComposerRouteParam = {
      replyToId: context.replyToId,
      replyToUser: context.replyToUser,
      avatarUrl: context.avatarUrl, verifiedType: context.verifiedType, avatarShape: context.avatarShape,
      avatarName: context.avatarName,
      avatarColor: context.avatarColor,
      initialText: text,
      imageUri: imageUri,
      gifUri: gifUri,
      communityId: '',
      communityName: '',
      parentTweet: this.tweet
    };
    this.setAutoPipArmed(false);
    if (this.embedded) { this.onEmbeddedNavigate(); }
    NavigationGuard.pushPath<ReplyComposerRouteParam>(this.pageStack, { name: 'ReplyComposer', param: param },
      (route: ReplyComposerRouteParam): string => route.replyToId);
  }

  private async sendCapsuleReply(text: string): Promise<boolean> {
    const content: string = text.trim();
    const current: Tweet | null = this.tweet;
    if (content.length === 0 || current === null || this.replyCapsuleSending) {
      return false;
    }
    this.replyCapsuleSending = true;
    try {
      const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      await authStore.load(context);
      xPrivateClient.load(context);
      const hasOAuth: boolean = authStore.isSignedIn() && authStore.getUserId().length > 0;
      const hasPrivateSession: boolean = xPrivateClient.isSignedIn();
      if (!hasOAuth && !hasPrivateSession) {
        this.showSignInRequired($r('app.string.action_reply'));
        return false;
      }

      if (hasOAuth) {
        this.api.setToken(authStore.getToken());
        this.api.setUser(authStore.getUserId());
        const published: boolean = await this.api.postTweet(content, current.id);
        if (published) {
          await this.finishCapsuleReply();
          return true;
        }
        const status: number = this.api.lastStatus();
        if (status < 0 || (status >= 200 && status < 300)) {
          promptAction.showToast({
            message: XPostFeedback.failure(context, status, this.api.lastPostReceipt()),
            duration: 3000
          });
          return false;
        }
      }

      if (hasPrivateSession) {
        const result: XPrivateResult = await xPrivateClient.createTweetWithMedia(content, current.id, []);
        if (result.ok) {
          await this.finishCapsuleReply();
          return true;
        }
        if (result.postReceipt.errorCode === '226') {
          this.openReplyComposer(content, '', '');
          return true;
        }
        promptAction.showToast({
          message: XPostFeedback.failure(context, result.status, result.postReceipt),
          duration: 3000
        });
        return false;
      }

      // Keep the draft and use the full composer when the OAuth endpoint rejects
      // a definite request, where it can fall back to X's web composer.
      this.openReplyComposer(content, '', '');
      return true;
    } catch (error) {
      promptAction.showToast({ message: this.text($r('app.string.post_send_unconfirmed')), duration: 3000 });
      return false;
    } finally {
      this.replyCapsuleSending = false;
    }
  }

  private async finishCapsuleReply(): Promise<void> {
    promptAction.showToast({ message: this.text($r('app.string.reply_sent')), duration: 1500 });
    await this.loadLiveThread();
  }

  private showSignInRequired(action: Resource): void {
    promptAction.showToast({
      message: this.text($r('app.string.toast_sign_in_to_prefix')) + this.text(action),
      duration: 2000
    });
  }

  private syncActionAvailable(): boolean {
    // Either credential can act: the OAuth token needs a user id, the cookie
    // session does not.
    if (xPrivateClient.isSignedIn()) {
      return true;
    }
    return authStore.isSignedIn() && authStore.getUserId().length > 0;
  }

  // X answers a write it refuses with a GraphQL error inside an HTTP 200, so
  // the reason has to be read out of the payload: an account-level posting
  // limit and a dead session both used to collapse into "无法连接 X".
  private privateActionError(result: XPrivateResult, action: Resource): string {
    if (result.status === 401 || result.status === 403) {
      return this.text($r('app.string.private_session_expired'));
    }
    if (result.isWriteLimit()) {
      return this.text(action) + this.text($r('app.string.action_write_limit'));
    }
    // A bare 404 on a write is how X's edge refuses a throttled account; the
    // request itself is well formed, so "unreachable" would mislead.
    if (result.status === 404) {
      return this.text(action) + this.text($r('app.string.action_write_refused'));
    }
    if (result.errorText.length > 0) {
      return this.text(action) + ' · ' + result.errorText;
    }
    return this.text(action) + this.text($r('app.string.api_unreachable_suffix'));
  }

  private async toggleLike(): Promise<void> {
    const post: Tweet | null = this.tweet;
    if (post !== null && !canPostAction(post, 'like')) { return; }
    if (post === null || this.likePending || postLikeStore.isPending(post.id)) {
      return;
    }
    if (!this.syncActionAvailable()) {
      this.showSignInRequired($r('app.string.action_like_posts'));
      return;
    }
    const nextLiked: boolean = !this.liked;
    this.likePending = true;
    const completion: Promise<boolean> = postLikeStore.setLike(post, nextLiked,
      (): Promise<boolean> => this.writeLike(post, nextLiked));
    this.syncLikeState();
    if (symbolMotionEnabled()) { this.likeSymbolTrigger++; }
    hapticTick();
    try {
      await completion;
    } finally {
      this.likePending = false;
      this.syncLikeState();
    }
  }

  private async writeLike(post: Tweet, nextLiked: boolean): Promise<boolean> {
    if (!this.isXPostId(post.id)) {
      return true;
    }
    if (xPrivateClient.isSignedIn()) {
      const result: XPrivateResult = await xPrivateClient.like(post.id, nextLiked);
      if (!result.ok) {
        promptAction.showToast({ message: this.privateActionError(result, $r('app.string.action_like')),
          duration: 2200 });
      }
      return result.ok;
    }
    const ok: boolean = await this.api.setLike(post.id, nextLiked);
    if (!ok) {
      promptAction.showToast({ message: this.text($r('app.string.action_like')) +
        this.text($r('app.string.api_unreachable_suffix')), duration: 2000 });
    }
    return ok;
  }

  private rollbackRepost(post: Tweet, reposted: boolean): void {
    this.reposted = !reposted;
    post.reposted = !reposted;
    if (reposted && post.metrics.repostCount > 0) {
      post.metrics.repostCount -= 1;
    } else if (!reposted) {
      post.metrics.repostCount += 1;
    }
  }

  private applyRepostState(post: Tweet, reposted: boolean): void {
    this.reposted = reposted;
    post.reposted = reposted;
    if (reposted) {
      post.metrics.repostCount += 1;
    } else if (post.metrics.repostCount > 0) {
      post.metrics.repostCount -= 1;
    }
  }

  private toggleRepost(): void {
    const post: Tweet | null = this.tweet;
    if (post === null || this.repostPending) {
      return;
    }
    if (!this.syncActionAvailable()) {
      this.showSignInRequired($r('app.string.action_repost'));
      return;
    }
    const nextReposted: boolean = !this.reposted;
    this.applyRepostState(post, nextReposted);
    if (symbolMotionEnabled()) { this.repostSymbolTrigger++; }
    hapticTick();
    if (!this.isXPostId(post.id)) {
      return;
    }
    this.repostPending = true;
    if (xPrivateClient.isSignedIn()) {
      xPrivateClient.repost(post.id, nextReposted).then((result: XPrivateResult): void => {
        this.repostPending = false;
        if (!result.ok) {
          this.rollbackRepost(post, nextReposted);
          promptAction.showToast({
            message: this.privateActionError(result, $r('app.string.action_repost')),
            duration: 2200
          });
        }
      });
      return;
    }
    this.api.setRepost(post.id, nextReposted).then((ok: boolean): void => {
      this.repostPending = false;
      if (!ok) {
        this.rollbackRepost(post, nextReposted);
        promptAction.showToast({
          message: this.text($r('app.string.action_repost')) + this.text($r('app.string.api_unreachable_suffix')),
          duration: 2000
        });
      }
    });
  }

  private async toggleBookmark(): Promise<void> {
    if (this.tweet !== null && !canPostAction(this.tweet, 'bookmark')) { return; }
    const current: Tweet | null = this.tweet;
    if (current === null || this.bookmarkPending) {
      return;
    }
    if (!xPrivateClient.isSignedIn()) {
      promptAction.showToast({
        message: this.text($r('app.string.profile_follow_sign_in')),
        duration: 2000
      });
      return;
    }
    const next: boolean = !this.bookmarked;
    this.bookmarked = next;
    current.bookmarked = next;
    if (symbolMotionEnabled()) { this.bookmarkSymbolTrigger++; }
    hapticTick();
    this.bookmarkPending = true;
    const result: XPrivateResult = await xPrivateClient.bookmark(current.id, next);
    this.bookmarkPending = false;
    if (!result.ok) {
      this.bookmarked = !next;
      current.bookmarked = !next;
      promptAction.showToast({
        message: this.privateActionError(result, $r('app.string.action_bookmark')),
        duration: 2200
      });
      return;
    }
    const message: Resource = next ? $r('app.string.toast_bookmark_added') :
      $r('app.string.toast_bookmark_removed');
    promptAction.showToast({ message: this.text(message), duration: 1500 });
  }

  private postShareUrl(post: Tweet): string {
    return 'https://x.com/' + encodeURIComponent(post.author.username) + '/status/' + encodeURIComponent(post.id);
  }

  private registerGesturesShare(): void {
    if (this.gestureShareListening || !canIUse('SystemCapability.Collaboration.HarmonyShare')) {
      return;
    }
    try {
      harmonyShare.on('gesturesShare', this.gesturesShareCallback);
      this.gestureShareListening = true;
    } catch {
      this.gestureShareListening = false;
    }
  }

  private unregisterGesturesShare(): void {
    if (!this.gestureShareListening) {
      return;
    }
    try {
      harmonyShare.off('gesturesShare', this.gesturesShareCallback);
    } catch {
      // The page is already leaving, so the listener state can be safely discarded.
    }
    this.gestureShareListening = false;
  }

  private createGestureShareData(post: Tweet, thumbnailUri: string): systemShare.SharedData {
    if (thumbnailUri.length > 0) {
      return new systemShare.SharedData({
        utd: utd.UniformDataType.HYPERLINK,
        content: this.postShareUrl(post),
        thumbnailUri: thumbnailUri,
        title: post.author.name + ' on X',
        description: post.text
      });
    }
    return new systemShare.SharedData({
      utd: utd.UniformDataType.HYPERLINK,
      content: this.postShareUrl(post),
      title: post.author.name + ' on X',
      description: post.text
    });
  }

  private async captureGestureSharePreview(post: Tweet): Promise<string> {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const previewPath: string = context.filesDir + '/harmonyx-post-' + post.id + '.png';
    try {
      const pixelMap: image.PixelMap = await this.getUIContext().getComponentSnapshot().createFromBuilder(
        (): void => {
          this.GestureSharePreview();
        }, 0, true, { scale: 1, waitUntilRenderFinished: true });
      const packer: image.ImagePacker = image.createImagePacker();
      const data: ArrayBuffer = await packer.packToData(pixelMap, { format: 'image/png', quality: 100 });
      const file: fileIo.File = fileIo.openSync(previewPath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);
      try {
        fileIo.writeSync(file.fd, data);
      } finally {
        fileIo.closeSync(file.fd);
      }
      return fileUri.getUriFromPath(previewPath);
    } catch {
      return '';
    }
  }

  private async prepareGestureSharePreview(): Promise<void> {
    const post: Tweet | null = this.tweet;
    if (post === null || this.gestureSharePreviewPostId === post.id) {
      return;
    }
    const previewUri: string = await this.captureGestureSharePreview(post);
    if (this.tweet !== null && this.tweet.id === post.id) {
      this.gestureSharePreviewPostId = post.id;
      this.gestureSharePreviewUri = previewUri;
    }
  }

  private async sharePostByGesture(target: harmonyShare.SharableTarget): Promise<void> {
    const post: Tweet | null = this.tweet;
    if (post === null) {
      return;
    }
    if (this.gestureSharePreviewPostId !== post.id) {
      await this.prepareGestureSharePreview();
    }
    this.gestureSharing = true;
    try {
      const shareData: systemShare.SharedData = this.createGestureShareData(post, this.gestureSharePreviewUri);
      await target.share(shareData);
    } catch {
      promptAction.showToast({ message: this.text($r('app.string.share_failed')), duration: 2000 });
    }
    this.gestureSharing = false;
  }

  private async shareCurrentPost(): Promise<void> {
    const post: Tweet | null = this.tweet;
    if (post === null) {
      return;
    }
    const sharedData: systemShare.SharedData = new systemShare.SharedData({
      utd: utd.UniformDataType.HYPERLINK,
      content: this.postShareUrl(post),
      title: post.author.name + ' on X',
      description: post.text
    });
    const controller: systemShare.ShareController = new systemShare.ShareController(sharedData);
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    try {
      await controller.show(context, {
        selectionMode: systemShare.SelectionMode.SINGLE,
        previewMode: systemShare.SharePreviewMode.DEFAULT
      });
    } catch {
      promptAction.showToast({ message: this.text($r('app.string.share_failed')), duration: 2000 });
    }
  }

  @Builder
  private ReplyComposerBar(): void {
    ReplyComposerCapsuleBuilder(this.replyComposerContext(),
      (text: string, imageUri: string, gifUri: string): void => {
        this.openReplyComposer(text, imageUri, gifUri);
      },
      (text: string): Promise<boolean> => {
        return this.sendCapsuleReply(text);
      },
      (expanded: boolean): void => {
        this.replyCapsuleExpanded = expanded;
      },
      this.replyComposerDismissRequest);
  }

  @Builder
  private ReplySortOption(mode: string, label: Resource): void {
    Row({ space: 12 }) {
      Text(label).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_L'))
        .fontColor(pageTextColor($r('app.color.text_primary'), this.embedded ? '' : this.pageBackgroundValue, this.replySortMode === mode ?
      fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface) : Color.Transparent))
        .layoutWeight(1)
      if (this.replySortMode === mode) {
        SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
          .fontSize(24)
          .fontColor([this.accentColor])
      } else {
        SymbolGlyph($r('sys.symbol.circle'))
          .fontSize(24)
          .fontColor([pageTextColor($r('app.color.text_secondary'), this.embedded ? '' : this.pageBackgroundValue, this.replySortMode === mode ?
      fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface) : Color.Transparent)])
      }
    }
    .width('100%')
    .height(62)
    .padding({ left: 14, right: 14 })
    .borderRadius(16)
    .backgroundColor(this.replySortMode === mode ?
      fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface) : Color.Transparent)
    .accessibilityText(this.text(label))
    .onClick((): void => {
      this.chooseReplySort(mode);
    })
  }

  @Builder
  private ReplySortSheet(): void {
    Column({ space: 8 }) {
      Text($r('app.string.post_detail_sort_title')).fontFamily(this.appFontFamily)
        .width('100%')
        .fontSize($r('sys.float.Title_L'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .padding({ left: 14, right: 14, top: 6, bottom: 10 })
      this.ReplySortOption(REPLY_SORT_RECENT, $r('app.string.post_detail_sort_recent'))
      this.ReplySortOption(REPLY_SORT_RELEVANCE, $r('app.string.post_detail_sort_relevance'))
      this.ReplySortOption(REPLY_SORT_LIKES, $r('app.string.post_detail_sort_likes'))
    }
    .width('100%')
    .padding({ left: 12, right: 12, bottom: 18 })
  }

  @Builder
  private ReplyInteractionHeader(): void {
    Row() {
      Row({ space: 5 }) {
        Text(this.replySortLabel()).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Subtitle_L'))
          .fontWeight(FontWeight.Medium)
          .fontColor(pageTextColor($r('app.color.text_primary'), this.embedded ? '' : this.pageBackgroundValue, postCardSurfaceColor($r('app.color.bg_card'), this.pageBackgroundValue)))
        SymbolGlyph($r('sys.symbol.chevron_down'))
          .fontSize(16)
          .fontColor([pageTextColor($r('app.color.text_secondary'), this.embedded ? '' : this.pageBackgroundValue, postCardSurfaceColor($r('app.color.bg_card'), this.pageBackgroundValue))])
      }
      .height(44)
      .padding({ left: 4, right: 10 })
      .borderRadius(12)
      .accessibilityText(this.text($r('app.string.post_detail_sort_title')))
      .onClick((): void => {
        this.replySortSheetVisible = true;
      })

      Blank()

      Row({ space: 4 }) {
        Text($r('app.string.post_detail_view_quotes')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_L'))
          .fontWeight(FontWeight.Medium)
          .fontColor(pageTextColor($r('app.color.text_primary'), this.embedded ? '' : this.pageBackgroundValue, postCardSurfaceColor($r('app.color.bg_card'), this.pageBackgroundValue)))
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(16)
          .fontColor([pageTextColor($r('app.color.text_secondary'), this.embedded ? '' : this.pageBackgroundValue, postCardSurfaceColor($r('app.color.bg_card'), this.pageBackgroundValue))])
      }
      .height(44)
      .padding({ left: 10, right: 4 })
      .borderRadius(12)
      .accessibilityText(this.text($r('app.string.post_detail_view_quotes')))
      .onClick((): void => {
        this.openPostInteractions();
      })
    }
    .width('100%')
    .padding({ left: 4, right: 4, top: 4 })
  }

  // The thread is the reading queue: the post itself first, then every loaded
  // reply, so "next" walks the conversation in the order it is displayed.
  private openReadAloud(): void {
    const post: Tweet | null = this.tweet;
    if (post === null) {
      return;
    }
    const queue: Tweet[] = [post];
    for (let index = 0; index < this.replies.length; index++) {
      queue.push(this.replies[index]);
    }
    const param: ReadAloudRouteParam = { tweets: queue, startId: post.id };
    this.setAutoPipArmed(false);
    if (this.embedded) { this.onEmbeddedNavigate(); }
    this.pageStack.pushPath({ name: 'ReadAloud', param: param });
  }

  @Builder
  private Metric(value: number, label: Resource): void {
    Column({ space: 2 }) {
      Text(formatCount(value)).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Subtitle_L'))
        .fontWeight(FontWeight.Bold)
        .fontColor(pageTextColor($r('app.color.text_primary'), this.embedded ? '' : this.pageBackgroundValue, postCardSurfaceColor($r('app.color.bg_card'), this.pageBackgroundValue)))
      Text(label).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_S'))
        .fontColor(pageTextColor($r('app.color.text_secondary'), this.embedded ? '' : this.pageBackgroundValue, postCardSurfaceColor($r('app.color.bg_card'), this.pageBackgroundValue)))
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  // Each button reads liked / reposted / bookmarked straight from the component
  // state instead of taking them as @Builder arguments: @Builder parameters are
  // passed by value, so a parameterised button kept rendering the state it was
  // first created with and the row never repainted after a tap.
  //
  // The bar keeps the reply, repost, like, bookmark and share actions together.
  // The translation action lives in the post menu so it stays available from
  // the top of a long post with several media attachments.
  private postActionCount(): number {
    return 5;
  }

  private postActionColumns(): number {
    const count: number = this.postActionCount();
    if (this.actionBarWidth <= 0) {
      return count > 5 ? 3 : count;
    }
    const perRow: number = Math.max(1,
      Math.floor(this.actionBarWidth / POST_ACTION_MIN_BUTTON_WIDTH));
    const rows: number = Math.ceil(count / Math.min(count, perRow));
    return Math.ceil(count / rows);
  }

  private postActionButtonWidth(): string {
    // Just under the exact share, so a rounded-up percentage cannot push the
    // last control of a row onto the next one.
    const share: number = Math.floor(10000 / this.postActionColumns() - 1) / 100;
    return share.toString() + '%';
  }

  private embeddedSectionRadius(): number {
    return this.embedded ? EMBEDDED_POST_SECTION_RADIUS : 0;
  }

  private transparentEmbeddedBackground(): boolean {
    return this.embedded && !this.mediaCommentBackground;
  }

  private embeddedSectionBackground(): ResourceColor {
    return this.embedded && this.mediaCommentBackground ?
      postCardSurfaceColor(cardSurfaceColor(this.themeDisplayMode, this.themeDarkSurface), this.pageBackgroundValue) : Color.Transparent;
  }

  private postActionRadius(): number {
    return this.embedded ? EMBEDDED_POST_SECTION_RADIUS : 16;
  }

  private captureActionBarWidth(area: Area): void {
    const width: number = Number(area.width);
    if (width > 0 && Math.abs(width - this.actionBarWidth) > 0.5) {
      this.actionBarWidth = width;
    }
  }

  private postActionColor(color: ResourceColor): ResourceColor {
    return pageTextColor(color, this.embedded ? '' : this.pageBackgroundValue,
      postCardSurfaceColor(cardSurfaceColor(this.themeDisplayMode, this.themeDarkSurface), this.pageBackgroundValue));
  }

  @Builder
  private PostActions(): void {
    if (this.tweet !== null) {
      Flex({ wrap: FlexWrap.Wrap }) {
        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Row({ space: 5 }) {
            SymbolGlyph($r('sys.symbol.ellipsis_bubble'))
              .fontSize($r('app.float.post_detail_action_icon'))
              .fontColor([this.postActionColor($r('app.color.text_secondary'))])
            Text(formatCount(this.tweet.metrics.replyCount)).fontFamily(this.appFontFamily)
              .fontSize($r('app.float.post_detail_action_text'))
              .fontColor(this.postActionColor($r('app.color.text_secondary')))
          }
          .justifyContent(FlexAlign.Center)
        }
        .width(this.postActionButtonWidth())
        .height($r('app.float.post_detail_action_height'))
        .padding(0)
        .backgroundColor(Color.Transparent)
        .accessibilityText(this.text($r('app.string.action_reply')))
        .onClick((): void => this.openReplyComposer('', '', ''))

        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Row({ space: 5 }) {
            SymbolGlyph($r('sys.symbol.repeat'))
              .symbolEffect(!this.reduceMotion && this.symbolEffects && this.motionAmplitude > 0 ?
                new BounceSymbolEffect(EffectScope.WHOLE) : new SymbolEffect(), this.repostSymbolTrigger)
              .fontSize($r('app.float.post_detail_action_icon'))
              .fontColor([this.reposted ? this.postActionColor($r('app.color.repost')) : this.postActionColor($r('app.color.text_secondary'))])
              .foregroundFilter(ComponentHdrHighlight.filter(this.getUIContext(), this.componentHdrEnabled && this.reposted, this.componentHdrRatio))
              .scale({ x: this.reposted ? 1.08 : 1, y: this.reposted ? 1.08 : 1 })
              .animation({ duration: 150, curve: Curve.EaseOut })
            Text(formatCount(this.tweet.metrics.repostCount)).fontFamily(this.appFontFamily)
              .fontSize($r('app.float.post_detail_action_text'))
              .fontColor(this.reposted ? this.postActionColor($r('app.color.repost')) : this.postActionColor($r('app.color.text_secondary')))
              .animation({ duration: 150, curve: Curve.EaseOut })
          }
          .justifyContent(FlexAlign.Center)
        }
        .width(this.postActionButtonWidth())
        .height($r('app.float.post_detail_action_height'))
        .padding(0)
        .backgroundColor(Color.Transparent)
        .accessibilityText(this.text($r('app.string.action_repost')))
        .onClick((): void => this.toggleRepost())

        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Row({ space: 5 }) {
            SymbolGlyph(this.liked ? $r('sys.symbol.heart_fill') : $r('sys.symbol.heart'))
              .symbolEffect(!this.reduceMotion && this.symbolEffects && this.motionAmplitude > 0 ?
                new BounceSymbolEffect(EffectScope.WHOLE) : new SymbolEffect(), this.likeSymbolTrigger)
              .fontSize($r('app.float.post_detail_action_icon'))
              .fontColor([this.liked ? this.postActionColor($r('app.color.like')) : this.postActionColor($r('app.color.text_secondary'))])
              .foregroundFilter(ComponentHdrHighlight.filter(this.getUIContext(), this.componentHdrEnabled && this.liked, this.componentHdrRatio))
              .scale({ x: this.liked ? 1.08 : 1, y: this.liked ? 1.08 : 1 })
              .animation({ duration: 150, curve: Curve.EaseOut })
            Text(formatCount(this.likeCount)).fontFamily(this.appFontFamily)
              .fontSize($r('app.float.post_detail_action_text'))
              .fontColor(this.liked ? this.postActionColor($r('app.color.like')) : this.postActionColor($r('app.color.text_secondary')))
              .animation({ duration: 150, curve: Curve.EaseOut })
          }
          .justifyContent(FlexAlign.Center)
        }
        .width(this.postActionButtonWidth())
        .height($r('app.float.post_detail_action_height'))
        .padding(0)
        .backgroundColor(Color.Transparent)
        .accessibilityText(this.text($r('app.string.action_like')))
        .onClick((): void => { void this.toggleLike(); })

        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Row({ space: 5 }) {
            SymbolGlyph(this.bookmarked ? $r('sys.symbol.bookmark_fill') : $r('sys.symbol.bookmark'))
              .symbolEffect(!this.reduceMotion && this.symbolEffects && this.motionAmplitude > 0 ?
                new BounceSymbolEffect(EffectScope.WHOLE) : new SymbolEffect(), this.bookmarkSymbolTrigger)
              .fontSize($r('app.float.post_detail_action_icon'))
              .fontColor([this.bookmarked ? this.postActionColor(this.accentColor) : this.postActionColor($r('app.color.text_secondary'))])
              .foregroundFilter(ComponentHdrHighlight.filter(this.getUIContext(), this.componentHdrEnabled && this.bookmarked, this.componentHdrRatio))
              .scale({ x: this.bookmarked ? 1.08 : 1, y: this.bookmarked ? 1.08 : 1 })
              .animation({ duration: 150, curve: Curve.EaseOut })
          }
          .justifyContent(FlexAlign.Center)
        }
        .width(this.postActionButtonWidth())
        .height($r('app.float.post_detail_action_height'))
        .padding(0)
        .backgroundColor(Color.Transparent)
        .accessibilityText(this.text($r('app.string.action_bookmark')))
        .onClick((): void => {
          this.toggleBookmark();
        })

        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Row({ space: 5 }) {
            SymbolGlyph($r('sys.symbol.share'))
              .fontSize($r('app.float.post_detail_action_icon'))
              .fontColor([this.postActionColor($r('app.color.text_secondary'))])
            }
            .justifyContent(FlexAlign.Center)
          }
        .width(this.postActionButtonWidth())
        .height($r('app.float.post_detail_action_height'))
        .padding(0)
        .backgroundColor(Color.Transparent)
        .accessibilityText(this.text($r('app.string.action_share')))
        .onClick((): void => {
          this.shareCurrentPost();
        })
      }
      .width('100%')
      .padding({ left: 4, right: 4, top: 2, bottom: 2 })
      .backgroundColor(this.transparentEmbeddedBackground() || this.usesCardMaterial() ? Color.Transparent :
        postCardSurfaceColor(cardSurfaceColor(this.themeDisplayMode, this.themeDarkSurface), this.pageBackgroundValue))
      .systemMaterial(this.cardMaterial())
      .borderRadius(this.postActionRadius())
      .clip(true)
      .visualEffect(new hdsEffect.HdsEffectBuilder()
        .pointLight({
          illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
        })
        .buildEffect())
      .onAreaChange((_oldValue: Area, newValue: Area): void => {
        this.captureActionBarWidth(newValue);
      })
    }
  }

  @Builder
  private GestureSharePreview(): void {
    if (this.tweet !== null) {
      Column({ space: 12 }) {
        Row({ space: 10 }) {
          Image($r('app.media.icon'))
            .width(32)
            .height(32)
            .borderRadius(8)
            .syncLoad(true)
          Column({ space: 2 }) {
            Text($r('app.string.EntryAbility_label')).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_L'))
              .fontWeight(FontWeight.Bold)
              .fontColor(pageTextColor($r('app.color.text_primary'), this.embedded ? '' : this.pageBackgroundValue, Color.Transparent))
            Text('@' + this.tweet.author.username).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_M'))
              .fontColor(pageTextColor($r('app.color.text_secondary'), this.embedded ? '' : this.pageBackgroundValue, Color.Transparent))
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        Text() { EmojiSpans(this.getUIContext(), this.tweet.text, $r('sys.float.Subtitle_L'), this.systemEmojiEnabled) }
          .width('100%')
          .fontSize($r('sys.float.Subtitle_L'))
          .fontFamily(this.appFontFamily === DEFAULT_APP_FONT_FAMILY ? this.contentFontFamily : this.appFontFamily)
          .fontColor(pageTextColor($r('app.color.text_primary'), this.embedded ? '' : this.pageBackgroundValue, Color.Transparent))
          .maxLines(6)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.postShareUrl(this.tweet)).fontFamily(this.appFontFamily)
          .width('100%')
          .fontSize($r('sys.float.Body_S'))
          .fontColor(pageTextColor($r('app.color.text_accent'), this.embedded ? '' : this.pageBackgroundValue, Color.Transparent))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width(320)
      .padding(20)
      .backgroundColor(pageCanvasColor(this.themeDisplayMode, this.themeDarkSurface, this.pageBackgroundValue))
      .border({ width: 1, color: $r('app.color.divider') })
      .borderRadius(20)
    }
  }

  @Builder
  private SkeletonLine(width: string, height: number): void {
    Column()
      .width(width)
      .height(height)
      .borderRadius(height / 2)
      .backgroundColor(fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
  }

  @Builder
  private PostHeroPlaceholder(): void {
    Column({ space: 12 }) {
      Row({ space: 12 }) {
        Column()
          .width(48)
          .height(48)
          .borderRadius(24)
          .backgroundColor(fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
        Column({ space: 8 }) {
          this.SkeletonLine('42%', 16)
          this.SkeletonLine('30%', 13)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Column()
          .width(72)
          .height(34)
          .borderRadius(17)
          .backgroundColor(fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
      }
      .width('100%')
      this.SkeletonLine('92%', 18)
      this.SkeletonLine('76%', 18)
      Column()
        .width('100%')
        .height(228)
        .borderRadius(14)
        .backgroundColor(fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
      this.SkeletonLine('38%', 13)
    }
    .width('100%')
    .padding({ left: 4, right: 4, top: 6, bottom: this.embedded ? 14 : 4 })
    .backgroundColor(this.embeddedSectionBackground())
    .borderRadius(this.embeddedSectionRadius())
    .clip(this.embedded)
    .renderGroup(true)
  }

  @Builder
  private PostActionsPlaceholder(): void {
    // Mirrors the real bar, rows and all, so the loaded bar drops into the
    // place the skeleton already occupied instead of reflowing the page.
    Flex({ wrap: FlexWrap.Wrap }) {
      ForEach([0, 1, 2, 3, 4, 5], (index: number) => {
        if (index < this.postActionCount()) {
          Row({ space: 5 }) {
            Column()
              .width(20)
              .height(20)
              .borderRadius(10)
              .backgroundColor(fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
            if (index < 3) {
              Column()
                .width(24)
                .height(12)
                .borderRadius(6)
                .backgroundColor(fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
            }
          }
          .width(this.postActionButtonWidth())
          .height($r('app.float.post_detail_action_height'))
          .justifyContent(FlexAlign.Center)
        }
      }, (index: number) => index.toString())
    }
    .width('100%')
    .padding({ left: 4, right: 4, top: 2, bottom: 2 })
    .backgroundColor(this.embeddedSectionBackground())
    .borderRadius(this.postActionRadius())
    .clip(this.embedded)
    .onAreaChange((_oldValue: Area, newValue: Area): void => {
      this.captureActionBarWidth(newValue);
    })
  }

  @Builder
  private ReplyPlaceholder(): void {
    Row({ space: 10 }) {
      Column()
        .width(44)
        .height(44)
        .borderRadius(22)
        .backgroundColor(fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
      Column({ space: 9 }) {
        this.SkeletonLine('46%', 15)
        this.SkeletonLine('94%', 16)
        this.SkeletonLine('68%', 16)
        Row() {
          this.SkeletonLine('14%', 13)
          this.SkeletonLine('14%', 13)
          this.SkeletonLine('14%', 13)
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height(132)
    .alignItems(VerticalAlign.Top)
    .padding(12)
    .border({ width: { bottom: 1 }, color: $r('app.color.divider') })
  }

  @Builder
  private ThreadPlaceholder(): void {
    Column({ space: 8 }) {
      this.SkeletonLine('24%', 18)
      this.ReplyPlaceholder()
      this.ReplyPlaceholder()
      this.ReplyPlaceholder()
    }
    .width('100%')
    .renderGroup(true)
  }

  @Builder
  private PostHero(): void {
    if (this.tweet !== null) {
      Column({ space: 12 }) {
        CommunitySource({ communityId: this.tweet.communityId ?? '', communityName: this.tweet.communityName ?? '' })
        Row({ space: 12 }) {
            SpaceAwareAvatar({verifiedType: this.tweet.author.verifiedType ?? '', avatarShape: this.tweet.author.avatarShape ?? '',  userId: this.tweet.author.id, url: this.tweet.author.avatarUrl ?? '', avatarSize: 48, radius: 24,
              followed: this.tweet.author.following === true,
              fallbackText: this.tweet.author.name.substring(0, 1).toUpperCase(),
              fallbackColor: this.tweet.author.avatarColor, tintBackground: true,
              onTintResolved: (palette: AvatarTintPalette | null): void => { this.avatarPalette = palette; },
              onProfile: (): void => this.openAuthor() })
          Column({ space: 2 }) {
            Flex({ alignItems: ItemAlign.Center }) {
              Text() { EmojiSpans(this.getUIContext(), this.tweet.author.name, $r('sys.float.Subtitle_L'), this.systemEmojiEnabled) }.fontFamily(this.appFontFamily)
                .fontSize($r('sys.float.Subtitle_L'))
                .fontWeight(FontWeight.Bold)
                .fontColor(pageTextColor($r('app.color.text_primary'), this.embedded ? '' : this.pageBackgroundValue, postCardSurfaceColor(this.transparentEmbeddedBackground() ? Color.Transparent :
        avatarTintSurface(this.avatarPalette, this.tweet.author.avatarUrl ?? '',
        this.avatarTintEnabled, this.themeDisplayMode, this.themeDarkSurface, this.avatarThemeDark), this.pageBackgroundValue)))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .flexShrink(1)
                .margin({ right: 5 })
                .onClick((): void => this.openAuthor())
              if (this.tweet.author.verified) {
                SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
                  .fontSize(16)
                  .fontColor([verificationBadgeColor(this.tweet.author.verifiedType ?? '', this.accentColor)])
                  .flexShrink(0)
              }
            }
            .width('100%')
            Text('@' + this.tweet.author.username).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_M'))
              .fontColor(pageTextColor($r('app.color.text_secondary'), this.embedded ? '' : this.pageBackgroundValue, postCardSurfaceColor(this.transparentEmbeddedBackground() ? Color.Transparent :
        avatarTintSurface(this.avatarPalette, this.tweet.author.avatarUrl ?? '',
        this.avatarTintEnabled, this.themeDisplayMode, this.themeDarkSurface, this.avatarThemeDark), this.pageBackgroundValue)))
              .onClick((): void => this.openAuthor())
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          PostAdLabel({ foreground: this.postActionColor($r('app.color.text_secondary')), presentation: this.tweet.presentation })
          if (!this.isOwnPost()) {
            if (this.tweet !== null) { PostOverflowButton({ foreground: this.postActionColor($r('app.color.text_secondary')), tweet: this.tweet }) }
          } else if (this.hasPostMenu()) {
            Stack() {
              SymbolGlyph($r('sys.symbol.ellipsis_circle'))
                .fontSize(22)
                .fontColor([pageTextColor($r('app.color.text_primary'), this.embedded ? '' : this.pageBackgroundValue, fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))])
            }
            .width(36)
            .height(36)
            .borderRadius(18)
            .backgroundColor(fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
            .bindMenu(this.postMenuItems())
          } else {
            Button(this.authorFollowing ? $r('app.string.profile_detail_following') :
              $r('app.string.profile_detail_follow'), { stateEffect: true })
              .fontSize($r('sys.float.Body_M'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_on_inverse'))
              .backgroundColor($r('app.color.text_primary'))
              .borderRadius(18)
              .onClick((): void => {
                this.toggleAuthorFollow();
              })
          }
        }
        .width('100%')
        if (this.translationReplaceOriginal && this.heroTranslatedText.length > 0 && this.tweet.presentation?.visibility?.hidden !== true) {
          Text() { EmojiSpans(this.getUIContext(), this.heroTranslatedText, $r('sys.float.Title_S'), this.systemEmojiEnabled) }
            .fontSize($r('sys.float.Title_S'))
            .fontFamily(this.appFontFamily === DEFAULT_APP_FONT_FAMILY ? this.contentFontFamily : this.appFontFamily)
            .fontColor(pageTextColor($r('app.color.text_primary'), this.embedded ? '' : this.pageBackgroundValue, postCardSurfaceColor(this.transparentEmbeddedBackground() ? Color.Transparent :
        avatarTintSurface(this.avatarPalette, this.tweet.author.avatarUrl ?? '',
        this.avatarTintEnabled, this.themeDisplayMode, this.themeDarkSurface, this.avatarThemeDark), this.pageBackgroundValue)))
            .width('100%')
            .copyOption(CopyOptions.LocalDevice)
            .accessibilityText(this.heroTranslatedText)
            .editMenuOptions(new EmojiCopyMenu(getContext(this) as common.UIAbilityContext, this.heroTranslatedText, this.systemEmojiEnabled))
        } else {
          Text() {
            ForEach(splitPostText(this.tweet.text), (segment: MentionSegment) => {
              if (segment.mention) {
                EmojiSpans(this.getUIContext(), segment.text, $r('sys.float.Title_S'), this.systemEmojiEnabled, (): void => {
                    this.openMention(segment.handle);
                })
              } else if (segment.hashtag.length > 0) {
                EmojiSpans(this.getUIContext(), segment.text, $r('sys.float.Title_S'), this.systemEmojiEnabled, (): void => {
                    requestSearch(segment.text);
                })
              } else if (segment.url.length > 0) {
                EmojiSpans(this.getUIContext(), segment.text, $r('sys.float.Title_S'), this.systemEmojiEnabled, (): void => {
                    const context: common.UIAbilityContext =
                      this.getUIContext().getHostContext() as common.UIAbilityContext;
                    openExternalLink(context, segment.url);
                })
              } else {
                EmojiSpans(this.getUIContext(), segment.text, $r('sys.float.Title_S'), this.systemEmojiEnabled)
              }
            })
          }
            .fontSize($r('sys.float.Title_S'))
            .fontFamily(this.appFontFamily === DEFAULT_APP_FONT_FAMILY ? this.contentFontFamily : this.appFontFamily)
            .fontColor(pageTextColor($r('app.color.text_primary'), this.embedded ? '' : this.pageBackgroundValue, postCardSurfaceColor(this.transparentEmbeddedBackground() ? Color.Transparent :
        avatarTintSurface(this.avatarPalette, this.tweet.author.avatarUrl ?? '',
        this.avatarTintEnabled, this.themeDisplayMode, this.themeDarkSurface, this.avatarThemeDark), this.pageBackgroundValue)))
            .width('100%')
            .copyOption(CopyOptions.LocalDevice)
            .accessibilityText(this.tweet.text)
            .editMenuOptions(new EmojiCopyMenu(getContext(this) as common.UIAbilityContext, this.tweet.text, this.systemEmojiEnabled))
        }
        if (this.heroTranslating) {
          Row({ space: 6 }) {
            LoadingProgress()
              .width(16)
              .height(16)
              .color(this.accentColor)
            Text($r('app.string.post_translating')).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_S'))
              .fontColor(pageTextColor($r('app.color.text_secondary'), this.embedded ? '' : this.pageBackgroundValue, postCardSurfaceColor(this.transparentEmbeddedBackground() ? Color.Transparent :
        avatarTintSurface(this.avatarPalette, this.tweet.author.avatarUrl ?? '',
        this.avatarTintEnabled, this.themeDisplayMode, this.themeDarkSurface, this.avatarThemeDark), this.pageBackgroundValue)))
          }
        }
        if (this.heroTranslatedText.length > 0 && !this.translationReplaceOriginal && this.tweet.presentation?.visibility?.hidden !== true) {
          Text() { EmojiSpans(this.getUIContext(), this.heroTranslatedText, $r('sys.float.Body_L'), this.systemEmojiEnabled) }
            .fontSize($r('sys.float.Body_L'))
            .fontFamily(this.appFontFamily === DEFAULT_APP_FONT_FAMILY ? this.contentFontFamily : this.appFontFamily)
            .fontWeight(FontWeight.Medium)
            .fontColor(pageTextColor($r('app.color.text_primary'), this.embedded ? '' : this.pageBackgroundValue, postCardSurfaceColor(this.transparentEmbeddedBackground() ? Color.Transparent :
        avatarTintSurface(this.avatarPalette, this.tweet.author.avatarUrl ?? '',
        this.avatarTintEnabled, this.themeDisplayMode, this.themeDarkSurface, this.avatarThemeDark), this.pageBackgroundValue)))
            .width('100%')
            .padding({ left: 10 })
            .border({ width: { left: 2 }, color: this.accentColor })
        }
        if (!this.embedded && !this.useWideMediaLayout() && this.tweet.attachments !== undefined && this.tweet.attachments.length > 0 && this.tweet.presentation?.visibility?.hidden !== true) {
          // The focal video keeps playing in a picture-in-picture window when
          // the reader scrolls down to the replies.
          PostMedia({
            controlsUsePageBackground: !this.embedded,
            controlSurface: postCardSurfaceColor(this.transparentEmbeddedBackground() ? Color.Transparent :
              avatarTintSurface(this.avatarPalette, this.tweet.author.avatarUrl ?? '', this.avatarTintEnabled,
                this.themeDisplayMode, this.themeDarkSurface, this.avatarThemeDark), this.pageBackgroundValue),
            sourceTweet: this.tweet,
            attachments: this.tweet.attachments,
            pipEnabled: true,
            naturalVideoSize: true
          })
        }
        if (this.tweet.poll !== undefined || this.tweet.card !== undefined || this.tweet.article !== undefined || this.tweet.presentation !== undefined) {
          PostInteractiveContent({ postId: this.tweet.id, poll: this.tweet.poll, card: this.tweet.card,
            article: this.tweet.article, presentation: this.tweet.presentation,
            accentColor: this.accentColor, showPollMedia: (this.tweet.attachments?.length ?? 0) === 0 })
        }
        if (this.tweet.quotedTweet !== undefined && this.tweet.presentation?.visibility?.hidden !== true) {
          QuotedPostCard({
            quoted: this.tweet.quotedTweet,
            accentColor: this.accentColor,
            sharedElementId: this.heroQuotedElementId(),
            onOpen: (quoted: Tweet): void => {
              this.openPost(quoted, this.heroQuotedElementId());
            }
          })
        }
        Text() {
          Span(this.postTimePrefix())
          Span(formatCount(postViewCounts.countFor(this.tweet.id, this.tweet.metrics.viewCount, this.viewCountRevision)))
            .fontWeight(FontWeight.Bold)
            .fontColor(pageTextColor($r('app.color.text_primary'), this.embedded ? '' : this.pageBackgroundValue, postCardSurfaceColor(this.transparentEmbeddedBackground() ? Color.Transparent :
        avatarTintSurface(this.avatarPalette, this.tweet.author.avatarUrl ?? '',
        this.avatarTintEnabled, this.themeDisplayMode, this.themeDarkSurface, this.avatarThemeDark), this.pageBackgroundValue)))
          Span(' ' + this.text($r('app.string.post_detail_views')))
        }.fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M'))
          .fontColor(pageTextColor($r('app.color.text_secondary'), this.embedded ? '' : this.pageBackgroundValue, postCardSurfaceColor(this.transparentEmbeddedBackground() ? Color.Transparent :
        avatarTintSurface(this.avatarPalette, this.tweet.author.avatarUrl ?? '',
        this.avatarTintEnabled, this.themeDisplayMode, this.themeDarkSurface, this.avatarThemeDark), this.pageBackgroundValue)))
          .width('100%')
          .copyOption(CopyOptions.LocalDevice)
      }
      .width('100%')
      .padding({ left: 4, right: 4, top: 6, bottom: this.embedded ? 14 : 4 })
      .backgroundColor(postCardSurfaceColor(this.transparentEmbeddedBackground() ? Color.Transparent :
        avatarTintSurface(this.avatarPalette, this.tweet.author.avatarUrl ?? '',
        this.avatarTintEnabled, this.themeDisplayMode, this.themeDarkSurface, this.avatarThemeDark), this.pageBackgroundValue))
      .borderRadius(this.embeddedSectionRadius())
      .clip(this.embedded)
      .scale({ x: this.gestureSharing ? 0.82 : 1, y: this.gestureSharing ? 0.82 : 1 })
      .opacity(this.gestureSharing ? 0.72 : 1)
      .renderGroup(true)
      .animation({ duration: 180, curve: Curve.EaseOut })
    }
  }

  @Builder
  private PrimaryPane(): void {
    Column({ space: 16 }) {
      if (this.tweet === null) {
        this.PostHeroPlaceholder()
        this.PostActionsPlaceholder()
      } else {
        this.PostHero()
        this.PostActions()
      }
    }
    .width('100%')
  }

  @Builder
  private RepliesListPane(): void {
    Column({ space: 16 }) {
      if (this.threadLoading || !this.transitionSettled) {
        this.ThreadPlaceholder()
      } else {
        this.ReplyInteractionHeader()
        Text(this.threadStatus).fontFamily(this.appFontFamily)
          .width('100%')
          .height(20)
          .fontSize($r('sys.float.Body_S'))
          .fontColor(pageTextColor($r('app.color.text_secondary'), this.embedded ? '' : this.pageBackgroundValue, this.embeddedSectionBackground()))
          .padding({ left: 4, right: 4, top: 4 })

        if (this.replies.length > 0) {
          Text($r('app.string.post_detail_comments')).fontFamily(this.appFontFamily)
            .width('100%')
            .fontSize($r('sys.float.Subtitle_L'))
            .fontWeight(FontWeight.Bold)
            .fontColor(pageTextColor($r('app.color.text_primary'), this.embedded ? '' : this.pageBackgroundValue, this.embeddedSectionBackground()))
            .padding({ left: 4, right: 4, top: 8 })
        }
        Column({ space: 0 }) {
        ForEach(this.commentRows(), (row: CommentTimelineRow) => {
          if (row.promotion !== null) {
            this.PromotionRow(row.promotion as XXAuthPromotionPost)
          } else {
            this.CommentReplyRow(row.reply as ThreadReplyRow)
          }
        }, (row: CommentTimelineRow) => row.key)
        }.width('100%')
      }
    }
    .width('100%')
    .backgroundColor(this.embeddedSectionBackground())
    .borderRadius(this.embeddedSectionRadius())
    .clip(this.embedded)
  }

  @Builder
  private RepliesPane(): void {
    Column({ space: 16 }) {
      this.RepliesListPane()
      if (!this.threadLoading && this.transitionSettled) {
        this.DiscoverMorePane()
        this.ThreadPagination()
      }
    }
    .width('100%')
  }

  @Builder
  private DiscoverMorePane(): void {
    if (this.discoverMore.some((post: Tweet): boolean => !this.filterHideAds || !isAdPost(post.presentation))) {
      Column({ space: 0 }) {
        Column({ space: 6 }) {
          Text($r('app.string.post_detail_discover_more')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Subtitle_L'))
            .fontWeight(FontWeight.Bold)
            .fontColor(pageTextColor($r('app.color.text_primary'), this.embedded ? '' : this.pageBackgroundValue, this.embeddedSectionBackground()))
            .width('100%')
          Text($r('app.string.post_detail_discover_more_desc')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_S'))
            .fontColor(pageTextColor($r('app.color.text_secondary'), this.embedded ? '' : this.pageBackgroundValue, this.embeddedSectionBackground()))
            .width('100%')
        }
        .width('100%')
        .padding({ left: 4, right: 4, top: 16, bottom: 12 })
        AdaptivePostGrid({ itemKeys: this.discoverMore.filter((post: Tweet): boolean => !this.filterHideAds || !isAdPost(post.presentation)).map((post: Tweet): string => post.id),
        item: (index: number): void => this.DiscoverMorePost(this.discoverMore.filter((post: Tweet): boolean => !this.filterHideAds || !isAdPost(post.presentation))[index]) })
      }
      .width('100%')
      .backgroundColor(this.embeddedSectionBackground())
      .borderRadius(this.embeddedSectionRadius())
      .clip(this.embedded)
    }
  }

  @Builder
  private DiscoverMorePost(post: Tweet): void {
    TweetCard({
      tweet: post,
      transparentBackground: this.transparentEmbeddedBackground(),
      sharedElementId: this.tweet === null ? '' : 'post-discover-' + this.tweet.id + '-' + post.id,
      showActions: true,
      onOpen: (selected: Tweet, sourceId: string): void => this.openPost(selected, sourceId),
      onAuthorTapped: (selected: Tweet): void => this.openUser(selected.author),
      onMentionTapped: (handle: string): void => this.openMention(handle)
    })
  }

  @Builder
  private ThreadPagination(): void {
    if (this.threadLoadingMore) {
      LoadingProgress().width(28).height(28).color(this.accentColor)
    } else if (this.threadNextToken.length > 0) {
      Column({ space: 8 }) {
        if (this.threadLoadMoreFailed) {
          Text($r('app.string.post_detail_unavailable')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_S'))
            .fontColor(pageTextColor($r('app.color.text_secondary'), this.embedded ? '' : this.pageBackgroundValue, postCardSurfaceColor($r('app.color.bg_card'), this.pageBackgroundValue)))
        }
        Button(this.threadLoadMoreFailed ? $r('app.string.common_retry') : $r('app.string.timeline_load_more'))
          .fontSize($r('sys.float.Body_M'))
          .fontColor(this.accentColor)
          .backgroundColor(fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
          .onClick((): void => { this.loadMoreThread(); })
      }
      .width('100%')
      .padding({ top: 8, bottom: 12 })
    }
  }

  @Builder
  private SingleThreadLayout(): void {
    Scroll(this.scroller) {
      Column({ space: 16 }) {
        this.PrimaryPane()
        this.RepliesPane()
      }
      .width('100%')
      .padding({
        left: 12,
        right: 12,
        top: this.embedded ? 16 : this.statusBarHeight + 64,
        bottom: this.navigationIndicatorHeight + 92
      })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .onWillScroll((scrollOffset: number): void => {
      this.onPrimaryDetailScroll(scrollOffset);
    })
    .onScrollEdge((edge: Edge): void => {
      if (edge === Edge.Bottom && !this.threadLoadMoreFailed) {
        this.loadMoreThread();
      }
    })
  }

  @Builder
  private WideThreadLayout(): void {
    if (this.useWideMediaLayout()) {
      this.WideMediaThreadLayout()
    } else {
    Row({ space: 12 }) {
      Scroll(this.primaryScroller) {
        Column() {
          this.PrimaryPane()
        }
        .width('100%')
        .padding({ bottom: this.navigationIndicatorHeight + 92 })
      }
      .width('42%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .onWillScroll((scrollOffset: number): void => {
        this.onPrimaryDetailScroll(scrollOffset);
      })

      Scroll(this.repliesScroller) {
        Column() {
          this.RepliesPane()
        }
        .width('100%')
        .padding({ bottom: this.navigationIndicatorHeight + 92 })
      }
      .layoutWeight(1)
      .height('100%')
      .scrollBar(BarState.Off)
      .onWillScroll((scrollOffset: number): void => {
        this.onRepliesDetailScroll(scrollOffset);
      })
      .onScrollEdge((edge: Edge): void => {
        if (edge === Edge.Bottom && !this.threadLoadMoreFailed) {
          this.loadMoreThread();
        }
      })
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    }
    .width('100%')
    .height('100%')
    .padding({
      left: 12,
      right: 12,
      top: this.statusBarHeight + 64
    })
    }
  }

  private wideMediaHeight(): number {
    return Math.max(1, this.detailWindowHeight - this.statusBarHeight - this.navigationIndicatorHeight - 100);
  }

  @Builder
  private WideMediaThreadLayout(): void {
    Row({ space: 0 }) {
      Stack({ alignContent: Alignment.Center }) {
        if (this.tweet !== null && this.tweet.attachments !== undefined) {
          Swiper() {
            ForEach(this.tweet.attachments, (media: MediaAttachment, index: number) => {
              PostMedia({ sourceTweet: this.tweet, attachments: [media], pipEnabled: true,
                playbackEnabled: index === this.wideMediaIndex, naturalVideoSize: true,
                fillVideoViewport: true, videoViewportHeight: this.wideMediaHeight(),
                photoViewportHeight: this.wideMediaHeight(), photoViewerAttachments: this.tweet?.attachments ?? [],
                onPhotoViewerReturn: (sourceIndex: number): void => { this.wideMediaIndex = sourceIndex; },
                showDownloadButton: true })
                .width('100%')
            }, (media: MediaAttachment): string => media.id)
          }.index(this.wideMediaIndex).loop(false).width('100%').height(this.wideMediaHeight())
            .onChange((index: number): void => { this.wideMediaIndex = index; })
        }
      }.width('56%').height('100%')
        .backgroundColor($r('app.color.bg_field'))
      Scroll(this.repliesScroller) {
        Column({ space: 16 }) {
          this.PrimaryPane()
          this.RepliesPane()
        }.width('100%').padding({ left: 16, right: 16, top: 16,
          bottom: this.navigationIndicatorHeight + 92 })
      }.layoutWeight(1).height('100%').scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .onWillScroll((scrollOffset: number): void => this.onRepliesDetailScroll(scrollOffset))
        .onScrollEdge((edge: Edge): void => { if (edge === Edge.Bottom && !this.threadLoadMoreFailed) { this.loadMoreThread(); } })
    }.width('100%').height('100%').padding({ top: this.statusBarHeight + 64 })
  }

  @Builder
  private FloatingReadAloudEntry(): void {
    if (this.readAloudEntryEnabled && this.tweet !== null) {
      // Same control as the feed's compose button, re-pointed at read-aloud.
      // It doubles as the thread's HDS point light, which is why it stays
      // mounted over the replies instead of living in the title bar.
      FloatingComposeButton({
        bottomInset: this.navigationIndicatorHeight + 4,
        mode: this.readAloudFabMode,
        refreshing: this.refreshing,
        onRefresh: (): void => {
          this.onRefresh();
        },
        onRead: (): void => {
          this.openReadAloud();
        }
      })
    }
  }

  @Builder
  private ContentBuilder(): void {
    Refresh({ refreshing: $$this.refreshing }) {
      Stack({ alignContent: Alignment.Bottom }) {
        if (!this.embedded && this.useWideThreadLayout()) {
          this.WideThreadLayout()
        } else {
          this.SingleThreadLayout()
        }
        if (!this.embedded) {
          this.FloatingReadAloudEntry()
        }
        if (this.replyCapsuleExpanded) {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor($r('app.color.reply_composer_scrim'))
            .onClick((): void => this.dismissExpandedReply())
        }
        if (this.tweet !== null) {
          Column() {
            this.ReplyComposerBar();
          }
          .width(this.useWideMediaLayout() ? '44%' : '100%')
          .align(this.useWideMediaLayout() ? Alignment.BottomEnd : Alignment.Bottom)
          .padding({ left: 12, right: 12,
            bottom: this.keyboardVisible ? 4 : this.navigationIndicatorHeight + 12 })
        }
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .onRefreshing((): void => this.onRefresh())
  }

  build(): void {
    if (this.embedded) {
      Column() {
        this.ContentBuilder()
      }
      .width('100%')
      .height('100%')
      .backgroundColor(sheetContentBackground(pageSurfaceColor(this.themeDisplayMode, this.themeDarkSurface),
        this.sheetMaterialEnabled))
      .bindSheet($$this.replySortSheetVisible, this.ReplySortSheet(), sheetMaterialOptions({
        height: 340, preferType: SheetType.BOTTOM, showClose: false, dragBar: true,
        backgroundColor: pageSurfaceColor(this.themeDisplayMode, this.themeDarkSurface)
      }, this.sheetMaterialEnabled, this.sheetMaterialLevel, this.sheetWindowBreakpoint, this.sheetCompactWindow))
    } else {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        appPageBackground()
      // The whole content area is the shared element: the tapped row follows
      // this container while it grows from the row's rect to the full page, so
      // the post page is revealed through a window that starts as the row
      // itself. Its own background keeps the list behind covered for the whole
      // expansion, and the content fades in with it instead of reflowing.
      Stack({ alignContent: Alignment.TopStart }) {
        this.ContentBuilder()
      }
      .width('100%')
      .height('100%')
      .clip(true)
      .backgroundColor(pageCanvasColor(this.themeDisplayMode, this.themeDarkSurface, this.pageBackgroundValue))
      .geometryTransition(this.sharedElementId)
      // The near-opaque transition sits on the shared element itself, so the
      // page above stays free to use the platform's own page transition.
      .transition(TransitionEffect.opacity(0.99))
      .bindSheet($$this.replySortSheetVisible, this.ReplySortSheet(), sheetMaterialOptions({
        height: 340,
        preferType: SheetType.BOTTOM,
        showClose: false,
        dragBar: true,
        maskColor: '#66000000',
        radius: { topLeft: 28, topRight: 28 },
        backgroundColor: pageSurfaceColor(this.themeDisplayMode, this.themeDarkSurface),
        onDisappear: (): void => {
          this.replySortSheetVisible = false;
        }
      }, this.sheetMaterialEnabled, this.sheetMaterialLevel, this.sheetWindowBreakpoint, this.sheetCompactWindow))
    
      }.width('100%').height('100%')
    }
    .scale({ x: this.pageMotion.scale, y: this.pageMotion.scale })
    .opacity(this.pageMotion.opacity)
    // Two ways in, one page. A reply row expands into this page, so that entry
    // keeps the platform's page transition switched off and lets the shared
    // element do all the moving. Every other entry point - the timelines, the
    // alert rows, a deep link - uses the platform's own page transition, as
    // every other child page in the app does.
    .systemTransition(pageSystemTransition(this.pageTransitionMode, this.sharedElementId.length > 0 ?
      NavigationSystemTransitionType.NONE : NavigationSystemTransitionType.DEFAULT))
    .onReady((context: NavDestinationContext): void => {
      this.pageMotion.attach(context);
      const param: PostDetailRouteParam = context.pathInfo?.param as PostDetailRouteParam;
      if (param !== undefined && param !== null) {
        this.applyRouteParam(param);
        this.startInitialLoad();
      }
    })
    .onWillHide((): void => {
      this.onDetailWillHide();
    })
    .onShown((): void => {
      this.onDetailShown();
    })
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .hideBackButton(false)
    .onBackPressed((): boolean => {
      this.setAutoPipArmed(false);
      continuationStore.publishHome();
      if (this.returnToMain) {
        ResponsiveLayout.closeToMain(this.pageStack);
      } else if (this.sharedElementId.length > 0) {
        this.getUIContext().animateTo({ curve: LIST_EXPAND_BACK_CURVE }, (): void => {
          ResponsiveLayout.closeContentDestination(this.pageStack, false);
        });
      } else {
        ResponsiveLayout.closeContentDestination(this.pageStack);
      }
      return true;
    })
    .bindToScrollable([this.scroller, this.primaryScroller, this.repliesScroller])
    .titleBar({
      avoidLayoutSafeArea: true,
      // This uses the HDS-native title-bar menu button, so the Grok entry
      // follows the platform's material, press feedback and safe-area layout.
      content: {
        title: { mainTitle: (this.tweet?.communityId ?? '').length > 0 ?
          $r('app.string.community_post_title') : $r('app.string.post_detail_title') },
        menu: {
          value: this.translationEnabled ? [
            {
              content: {
                icon: $r('sys.symbol.translate'),
                label: this.text(this.heroTranslating ? $r('app.string.post_translating') :
                  this.heroTranslatedText.length > 0 ? $r('app.string.post_hide_translation') :
                  $r('app.string.post_translate')),
                action: (): void => {
                  this.runHeroTranslation();
                }
              }
            },
            {
              content: {
                // HDS title-bar menus accept app media in addition to system
                // symbols.  This uses the bundled Grok mark because custom
                // brand symbols cannot be registered in the system Symbol set.
                icon: $r('app.media.grok_mark'),
                label: this.text($r('app.string.grok_open')),
                action: (): void => {
                  this.openGrok();
                }
              }
            }
          ] : [
            {
              content: {
                icon: $r('app.media.grok_mark'),
                label: this.text($r('app.string.grok_open')),
                action: (): void => {
                  this.openGrok();
                }
              }
            }
          ]
        }
      },
      style: destinationTitleBarStyle(ScrollEffectType.GRADIENT_BLUR, this.themeDisplayMode,
        this.themeDarkSurface, this.titleBarStyleMode, this.replyCapsuleExpanded)
    })
    // Transparent while the row expands, so the list is not blanked out by a
    // freshly mounted page before the expansion has covered it.
    .backgroundColor(this.sharedElementId.length > 0 ? Color.Transparent :
      pageCanvasColor(this.themeDisplayMode, this.themeDarkSurface, this.pageBackgroundValue));
    }
  }
}
