import { PostLinkMenu } from '../components/PostLinkMenu';
import { PostTranslationInfo } from '../components/PostTranslationInfo';
import { postUsesHorizontalMediaStrip } from '../utils/PostMediaStrip';
import { mediaAvatarScale } from '../utils/PostMediaAvatarMotion';
import { PostActionBar } from './PostActionBar';
import { DEFAULT_POST_ACTIONS_MASK, STORAGE_KEY_POST_ACTIONS_MASK, STORAGE_KEY_POST_ACTION_COUNTS } from '../services/PostDisplaySettingsStore';
import { activateInputKey, contextInputMouse } from '../utils/InputSupport';
import { offlineReadingStore, OfflineSaveResult } from '../services/OfflineReadingStore';
import { DEFAULT_COMPONENT_HDR_ENABLED, DEFAULT_COMPONENT_HDR_RATIO, STORAGE_KEY_COMPONENT_HDR_ENABLED,
  STORAGE_KEY_COMPONENT_HDR_RATIO } from '../services/ComponentHdrSettingsStore';
import { ComponentHdrHighlight } from '../utils/ComponentHdrHighlight';
import { pageTextColor } from '../utils/ThemeColors';
import { postCardSurfaceColor } from '../utils/ThemeColors';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { STORAGE_KEY_SYSTEM_EMOJI_ENABLED } from '../services/AppearanceStore';
import { PostAdLabel } from './PostAdLabel';
import { userAvatarRadius, userVerifiedType, userAvatarShape, verificationBadgeColor } from '../utils/UserIdentity';
// Reusable post card: X-style row (avatar, header, text, action bar)
// with HarmonyOS SymbolGlyph icons and theme-resource colors.
import type { MediaAttachment, Tweet, TweetPoll } from '../models/Tweet';
import { formatCount } from '../models/Tweet';
import { hdsEffect } from '@kit.UIDesignKit';
import { motionDuration, motionScale, motionDistance, motionCurve } from '../utils/AppMotion';
import { STORAGE_KEY_REDUCE_MOTION } from '../services/MotionSettingsStore';
import { common } from '@kit.AbilityKit';
import promptAction from '@ohos.promptAction';
import { PostMedia } from './PostMedia';
import { SpaceAwareAvatar } from './SpaceAwareAvatar';
import { CommunitySource } from './CommunitySource';
import { ProxyMediaImage } from './ProxyMediaImage';
import { QuotedPostCard } from './QuotedPostCard';
import { PostInteractiveContent } from './PostInteractiveContent';
import { canPostAction } from '../utils/PostContentVisibility';
import {
  STORAGE_KEY_TRANSLATION_AUTO_ENABLED,
  STORAGE_KEY_TRANSLATION_REPLACE_ORIGINAL,
  STORAGE_KEY_TRANSLATION_SETTINGS_REVISION,
  TranslationSettings,
  translationStore
} from '../services/TranslationStore';
import { TranslationResult, translationService } from '../services/TranslationService';
import { TARGET_LANGUAGE_APP } from '../models/Translation';
import { MentionSegment, splitPostText } from '../utils/MentionText';
import { PostLinkSpans } from './PostLinkSpans';
import { EmojiSpans } from './EmojiSpans';
import { EmojiCopyMenu } from '../utils/EmojiCopyMenu';
import { openExternalLink, requestSearch } from '../utils/PostEntities';
import { hapticTick } from '../utils/Haptics';
import { sharePost } from '../utils/SharePost';
import { LIST_ITEM_PRESS_SCALE } from '../utils/SharedElementMotion';
import { XPrivateResult, xPrivateClient } from '../services/XPrivateClient';
import { fieldSurfaceColor } from '../utils/ThemeColors';
import { STORAGE_KEY_PRESS_EFFECT_ENABLED } from '../services/PressEffectSettingsStore';
import { formatPostTime, STORAGE_KEY_POST_TIME_NOW } from '../utils/PostTime';
import { postIsEdited, bookmarkCountAfter } from '../utils/PostMetadata';
import { effectiveAppLocale, isAppRtl, STORAGE_KEY_APP_LOCALE } from '../utils/AppLocale';
import { LengthMetrics } from '@kit.ArkUI';
import { postViewCounts, STORAGE_KEY_POST_VIEWS_REVISION } from '../services/PostViewCounts';
import { postLikeStore, STORAGE_KEY_POST_LIKES_REVISION } from '../services/PostLikeStore';
import { postPollStore, STORAGE_KEY_POST_POLL_REVISION } from '../services/PostPollStore';
import { photoStripLayout } from '../utils/PostPhotoLayout';
import {
  DEFAULT_CONTENT_FONT_FAMILY,
  STORAGE_KEY_CONTENT_FONT_FAMILY,
  STORAGE_KEY_AVATAR_TINT_ENABLED
} from '../services/AppearanceStore';
import { AvatarTintPalette, avatarTintIsDark, avatarTintSurface } from '../utils/AvatarTintColors';
import { PostOverflowButton } from './PostOverflowButton';
import { postModerationStore, STORAGE_KEY_POST_MODERATION_REVISION } from '../services/PostModerationStore';
import { STORAGE_KEY_ACCOUNTS_CHANGED } from '../services/AccountStore';
import { homeSeenTweetStore } from '../services/HomeSeenTweetStore';

// Collapse a post body once it passes this many characters.
const LONG_TEXT_CHARACTERS: number = 180;
const LONG_TEXT_MAX_LINES: number = 6;
const LONG_TEXT_MAX_LINES_EXPANDED: number = 400;

@Component
export struct TweetCard {
  @State private linkMenuVisible: boolean = false;
  @State private translatedLinkMenuVisible: boolean = false;
  @State private selectedLinkUrl: string = '';

  private selectPostLink(url: string): void {
    this.selectedLinkUrl = url;
    this.translatedLinkMenuVisible = false;
    this.linkMenuVisible = true;
  }

  private selectTranslatedPostLink(url: string): void {
    this.selectedLinkUrl = url;
    this.linkMenuVisible = false;
    this.translatedLinkMenuVisible = true;
  }

  @Builder
  private LinkMenu(): void { PostLinkMenu(this.getUIContext(), this.selectedLinkUrl) }

  private bodyTextController: TextController = new TextController();
  private translatedTextController: TextController = new TextController();
  @StorageProp(STORAGE_KEY_COMPONENT_HDR_ENABLED) private componentHdrEnabled: boolean = DEFAULT_COMPONENT_HDR_ENABLED;
  @StorageProp(STORAGE_KEY_COMPONENT_HDR_RATIO) private componentHdrRatio: number = DEFAULT_COMPONENT_HDR_RATIO;
  @StorageProp('harmonyx.page_background') private pageBackgroundValue: string = '';
  @StorageProp(STORAGE_KEY_POST_MODERATION_REVISION) @Watch('loadModeration') private moderationRevision: number = 0;
  @State private readerHidden: boolean = false;
  @StorageProp(STORAGE_KEY_ACCOUNTS_CHANGED) @Watch('loadModeration') private accountRevision: number = 0;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp(STORAGE_KEY_SYSTEM_EMOJI_ENABLED) private systemEmojiEnabled: boolean = false;
  @Prop @Watch('onTweetChanged') tweet: Tweet;
  @StorageProp(STORAGE_KEY_POST_TIME_NOW) private postTimeNow: number = Date.now();
  @StorageProp(STORAGE_KEY_APP_LOCALE) @Watch('onTranslationAppLocaleChanged')
  private appLocale: string = effectiveAppLocale();
  @StorageProp(STORAGE_KEY_POST_VIEWS_REVISION) private viewCountRevision: number = 0;
  @StorageProp(STORAGE_KEY_POST_LIKES_REVISION) @Watch('syncLikeState') private likeRevision: number = 0;
  @StorageProp(STORAGE_KEY_POST_POLL_REVISION) private pollRevision: number = 0;
  @Prop sharedElementId: string = '';
  @StorageProp('harmonyx.display_mode') private themeDisplayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private themeDarkSurface: string = '';
  @StorageProp(STORAGE_KEY_AVATAR_TINT_ENABLED) private avatarTintEnabled: boolean = false;
  @State private avatarPalette: AvatarTintPalette | null = null;
  @State private avatarThemeDark: boolean = false;
  @StorageLink(STORAGE_KEY_CONTENT_FONT_FAMILY) private contentFontFamily: string = DEFAULT_CONTENT_FONT_FAMILY;
  onLikeChanged: (t: Tweet, liked: boolean) => Promise<boolean> = async () => false;
  onRepostChanged: (t: Tweet, reposted: boolean) => Promise<boolean> = async () => false;
  onBookmarkChanged: (t: Tweet, bookmarked: boolean) => void = () => {
  };
  onReply: (t: Tweet) => void = () => {
  };
  // The card owns the shared-element id of whatever was tapped, so the page
  // never has to rebuild it: the tapped post is either this card or the quoted
  // block inside it, and each has its own id.
  onOpen: (t: Tweet, sourceId: string) => void = () => {
  };
  onVideoOpen: (t: Tweet, media: MediaAttachment) => void = (): void => {
  };
  onAuthorTapped: (t: Tweet) => void = () => {
  };
  onMentionTapped: (handle: string) => void = () => {
  };
  @Prop showActions: boolean = true;
  @Prop transparentBackground: boolean = false;
  @Prop compactAuthorHeader: boolean = true;
  @Prop narrowColumn: boolean = false;
  @Prop showReplyContext: boolean = false;
  @Prop videoFeedEnabled: boolean = false;
  // Only cards in the root home timeline use its autoplay-audio preference.
  @Prop homeTimelineVideo: boolean = false;
  @Prop recordRecommendationSeen: boolean = false;
  // Stream-view pages opt out explicitly. Timeline and detail cards keep the
  // source video's native aspect ratio everywhere else.
  @Prop naturalVideoSize: boolean = true;
  @Prop connectAbove: boolean = false;
  @Prop connectBelow: boolean = false;
  // A promotion row is a synthetic Tweet: the card keeps the ordinary post
  // layout while the actions that would write to a real post are removed.
  promotion: boolean = false;
  @Prop promotionDismissible: boolean = true;
  onPromotionHideSession: () => void = (): void => { };
  onPromotionHideWeek: () => void = (): void => { };
  @State private cardHeight: number = 0;
  @State private inputMenuRequest: number = 0;
  @State private avatarTop: number = 12;
  @State liked: boolean = false;
  @State private likeCount: number = 0;
  @State reposted: boolean = false;
  @State bookmarked: boolean = false;
  @State likePending: boolean = false;
  @State repostPending: boolean = false;
  @State bookmarkPending: boolean = false;
  @StorageProp(STORAGE_KEY_REDUCE_MOTION) private reduceMotion: boolean = false;
  @State private likeScale: number = 1;
  @State private repostRotation: number = 0;
  @State private bookmarkScale: number = 1;
  @StorageLink('harmonyx.translation_enabled') translationEnabled: boolean = false;
  @StorageLink(STORAGE_KEY_TRANSLATION_AUTO_ENABLED)
  translationAutoEnabled: boolean = false;
  @StorageLink(STORAGE_KEY_TRANSLATION_SETTINGS_REVISION) @Watch('onTranslationSettingsRevisionChanged')
  translationSettingsRevision: number = 0;
  @StorageLink(STORAGE_KEY_TRANSLATION_REPLACE_ORIGINAL) translationReplaceOriginal: boolean = false;
  @State translatedText: string = '';
  @State private showingOriginal: boolean = false;
  @State translating: boolean = false;
  @State private lastAutoTranslationRevision: number = -1;
  @State private lastAutoTranslationPostId: string = '';
  private translationRequestGeneration: number = 0;
  private translationPostId: string = '';
  private translationWasAutomatic: boolean = false;
  @State private textExpanded: boolean = false;
  @State private photoPageIndex: number = 0;
  @State private mediaPanProgress: number = 0;
  @StorageProp(STORAGE_KEY_POST_ACTIONS_MASK) private actionsMask: number = DEFAULT_POST_ACTIONS_MASK;
  @State private cardWidth: number = 0;
  @StorageProp('harmonyx.window_height') private photoWindowHeight: number = 0;
  private visibleForViews: boolean = false;
  // The row sinks under the finger while it is pressed.
  @State private pressScale: number = 1;
  @StorageLink(STORAGE_KEY_PRESS_EFFECT_ENABLED) pressEffectEnabled: boolean = false;
  @StorageLink('harmonyx.accent_color') accentColor: string = '#007DFF';

  aboutToAppear(): void {
    this.loadModeration();
    this.syncLikeState();
    this.reposted = this.tweet.reposted;
    this.bookmarked = this.tweet.bookmarked ?? false;
    this.tryAutomaticTranslation();
  }

  onWillApplyTheme(theme: Theme): void {
    this.avatarThemeDark = avatarTintIsDark(theme);
  }

  private loadModeration(): void {
    postModerationStore.load(getContext(this));
    this.readerHidden = postModerationStore.hidden(this.tweet);
  }

  private onTweetChanged(): void {
    this.mediaPanProgress = 0;
    this.photoPageIndex = 0;
    this.loadModeration();
    this.syncLikeState();
    if (this.visibleForViews) {
      postViewCounts.requestMissing(this.tweet);
    }
    if (this.translationPostId !== this.tweet.id && (this.translating || this.translatedText.length > 0)) {
      this.resetTranslation();
    } else if (this.translationWasAutomatic) {
      const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      if (!translationStore.load(context).shouldAutomaticallyTranslate(this.tweet.language ?? '')) {
        this.resetTranslation();
      }
    }
    this.tryAutomaticTranslation();
  }

  private syncLikeState(): void {
    postLikeStore.apply(this.tweet);
    this.liked = this.tweet.liked;
    this.likeCount = this.tweet.metrics.likeCount;
  }

  private onTranslationSettingsRevisionChanged(): void {
    this.resetTranslation();
    this.tryAutomaticTranslation();
  }

  private onTranslationAppLocaleChanged(): void {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    if (translationStore.load(context).targetLanguage === TARGET_LANGUAGE_APP) {
      this.resetTranslation();
      this.tryAutomaticTranslation();
    }
  }

  private resetTranslation(): void {
    // Invalidated requests may finish, but cannot restore an excluded post or
    // a translation in the language selected before the settings changed.
    this.translationRequestGeneration++;
    this.translating = false;
    this.translatedText = '';
    this.showingOriginal = false;
    this.translationWasAutomatic = false;
    this.lastAutoTranslationRevision = -1;
    this.lastAutoTranslationPostId = '';
  }

  private tryAutomaticTranslation(): void {
    if (!this.translationAutoEnabled || this.translating || this.translatedText.length > 0 ||
      (this.lastAutoTranslationRevision === this.translationSettingsRevision &&
        this.lastAutoTranslationPostId === this.tweet.id)) {
      return;
    }
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    if (!translationStore.load(context).shouldAutomaticallyTranslate(this.tweet.language ?? '')) { return; }
    this.lastAutoTranslationRevision = this.translationSettingsRevision;
    this.lastAutoTranslationPostId = this.tweet.id;
    this.runTranslation(true);
  }

  private avatarUrl(): string {
    return this.tweet.author.avatarUrl ?? '';
  }

  private authorTimeLabel(): string {
    const time: string = formatPostTime(this.tweet.createdAt, this.postTimeNow);
    return '@' + this.tweet.author.username + (time.length > 0 ? ' · ' + time : '') +
      (postIsEdited(this.tweet.editHistoryIds) ? ' · ' + this.resourceText($r('app.string.post_edited')) : '');
  }

  private mentionSegments(): MentionSegment[] {
    return splitPostText(this.tweet.text);
  }

  private hasPhotoStrip(): boolean {
    const attachments: MediaAttachment[] = this.tweet.attachments ?? [];
    if (attachments.length === 0) {
      return false;
    }
    for (let i: number = 0; i < attachments.length; i++) {
      if (attachments[i].type !== 'photo') {
        return false;
      }
    }
    return true;
  }

  private photoOnlyPost(): boolean {
    return this.hasPhotoStrip() && this.tweet.text.trim().length === 0;
  }

  private hasWidePhotoStrip(): boolean {
    const attachments: MediaAttachment[] = this.tweet.attachments ?? [];
    const videoStrip: boolean = postUsesHorizontalMediaStrip(attachments, false);
    if (this.connectAbove || this.connectBelow || (!this.hasPhotoStrip() && !videoStrip) || attachments.length < 2 || this.cardWidth <= 0) {
      return false;
    }
    return photoStripLayout(attachments, Math.max(1, this.cardWidth - 72), this.photoWindowHeight).overflows;
  }

  private displayedViewCount(): number {
    return postViewCounts.countFor(this.tweet.id, this.tweet.metrics.viewCount, this.viewCountRevision);
  }

  private repostLabel(): string {
    if (this.tweet.repostAuthor !== undefined) {
      const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      const name: string = this.tweet.repostAuthor.name.length > 0 ?
        this.tweet.repostAuthor.name : '@' + this.tweet.repostAuthor.username;
      return context.resourceManager.getStringSync($r('app.string.post_reposted_by'), name);
    }
    return (this.tweet.repostText ?? '').length > 0 ? this.tweet.repostText as string :
      this.resourceText($r('app.string.post_reposted'));
  }

  @Builder
  private PhotoPageIndicator(): void {
    Row({ space: 6 }) {
      ForEach(this.tweet.attachments ?? [], (_media: MediaAttachment, index: number) => {
        Column()
          .width(22)
          .height(4)
          .borderRadius(2)
          .backgroundColor($r('app.color.text_secondary'))
          .opacity(index === this.photoPageIndex ? 1 : 0.35)
      }, (media: MediaAttachment) => media.id)
    }
    .height(20)
    .alignItems(VerticalAlign.Center)
  }

  // Long posts collapse to a few lines with an explicit expander, matching how
  // X keeps the feed scannable.
  private textIsLong(): boolean {
    const displayText: string = this.translationReplaceOriginal && this.translatedText.length > 0 && !this.showingOriginal ?
      this.translatedText : this.tweet.text;
    return displayText.length > LONG_TEXT_CHARACTERS;
  }

  private resourceText(resource: Resource): string {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    return context.resourceManager.getStringSync(resource);
  }

  // The numbers a row shows when it has no action handlers of its own: the same
  // maths the card's action bar uses, so a row without buttons still reports
  // what it knows.
  private displayedLikeCount(): number {
    return this.likeCount;
  }

  private displayedRepostCount(): number {
    return Math.max(0, this.tweet.metrics.repostCount +
      (this.reposted === this.tweet.reposted ? 0 : (this.reposted ? 1 : -1)));
  }

  private metricLabel(label: Resource, value: number): string {
    const name: string = this.resourceText(label);
    return value > 0 ? name + ' ' + formatCount(value) : name;
  }

  private translationMenuItems(): MenuElement[] {
    const items: MenuElement[] = [];
    items.push({
      value: this.resourceText(this.translatedText.length > 0 ?
        $r('app.string.post_hide_translation') : $r('app.string.post_translate')),
      action: (): void => {
        this.runTranslation();
      }
    });
    return items;
  }

  // One tap translates, a second tap hides the result again. The service
  // caches per post, so re-opening a card is free.
  private async runTranslation(automatic: boolean = false): Promise<void> {
    if (this.translating) {
      return;
    }
    if (this.translatedText.length > 0) {
      if (automatic) {
        return;
      }
      this.showingOriginal = !this.showingOriginal;
      return;
    }
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const settings: TranslationSettings = translationStore.load(context);
    if (automatic && !settings.shouldAutomaticallyTranslate(this.tweet.language ?? '')) {
      return;
    }
    if (!settings.isRunnable()) {
      if (!automatic) {
        promptAction.showToast({
          message: this.resourceText($r('app.string.post_translate_no_key')),
          duration: 2600
        });
      }
      return;
    }
    const generation: number = this.translationRequestGeneration;
    const postId: string = this.tweet.id;
    this.translationPostId = postId;
    this.translationWasAutomatic = automatic;
    this.translating = true;
    const result: TranslationResult = await translationService.translate(postId, this.tweet.text, settings,
      this.tweet.language ?? '');
    if (generation !== this.translationRequestGeneration || this.tweet.id !== postId) { return; }
    this.translating = false;
    if (result.ok) {
      this.translatedText = result.text;
      return;
    }
    if (!automatic) {
      promptAction.showToast({
        message: this.resourceText(result.errorText === 'no_session' ?
          $r('app.string.post_translate_x_login') : $r('app.string.post_translate_failed')),
        duration: 2600
      });
    }
  }

  private playLikeMotion(next: boolean): void {
    this.likeScale = motionScale(next ? 0.72 : 1.12);
    this.getUIContext().animateTo({ duration: motionDuration(320), curve: motionCurve() }, (): void => {
      this.likeScale = 1;
    });
  }

  private playRepostMotion(next: boolean): void {
    this.getUIContext().animateTo({ duration: motionDuration(280), curve: motionCurve() }, (): void => {
      this.repostRotation = next ? motionDistance(180) : 0;
    });
  }

  private playBookmarkMotion(next: boolean): void {
    this.bookmarkScale = motionScale(next ? 0.74 : 1.08);
    this.getUIContext().animateTo({ duration: motionDuration(260), curve: motionCurve() }, (): void => {
      this.bookmarkScale = 1;
    });
  }

  private async toggleLike(): Promise<void> {
    if (!canPostAction(this.tweet, 'like')) { return; }
    if (this.likePending || postLikeStore.isPending(this.tweet.id)) { return; }
    const post: Tweet = this.tweet;
    const next: boolean = !this.liked;
    this.likePending = true;
    const completion: Promise<boolean> = postLikeStore.setLike(post, next,
      (): Promise<boolean> => this.onLikeChanged(post, next));
    this.syncLikeState();
    this.playLikeMotion(next);
    hapticTick();
    try {
      await completion;
    } finally {
      this.likePending = false;
      this.syncLikeState();
    }
  }

  private commitRepost(next: boolean): void {
    if (this.tweet.reposted !== next) {
      if (next) {
        this.tweet.metrics.repostCount += 1;
      } else if (this.tweet.metrics.repostCount > 0) {
        this.tweet.metrics.repostCount -= 1;
      }
    }
    this.tweet.reposted = next;
    this.reposted = next;
  }

  private async toggleBookmark(): Promise<void> {
    if (!canPostAction(this.tweet, 'bookmark')) { return; }
    if (this.bookmarkPending) {
      return;
    }
    const context: common.UIAbilityContext =
      this.getUIContext().getHostContext() as common.UIAbilityContext;
    xPrivateClient.load(context);
    if (!xPrivateClient.isSignedIn()) {
      promptAction.showToast({
        message: this.resourceText($r('app.string.bookmarks_sign_in')),
        duration: 2000
      });
      return;
    }
    this.bookmarkPending = true;
    const next: boolean = !this.bookmarked;
    const saveAccount: string = offlineReadingStore.account(context);
    try {
      const result: XPrivateResult = await xPrivateClient.bookmark(this.tweet.id, next);
      if (!result.ok) {
        promptAction.showToast({
          message: this.resourceText($r('app.string.action_bookmark')) + ' · HTTP ' + result.status,
          duration: 2000
        });
        return;
      }
      if (saveAccount !== offlineReadingStore.account(context)) { return; }
      this.tweet.metrics.bookmarkCount = bookmarkCountAfter(this.tweet.metrics.bookmarkCount, this.bookmarked, next);
      this.bookmarked = next;
      this.tweet.bookmarked = next;
      this.playBookmarkMotion(next);
      hapticTick();
      this.onBookmarkChanged(this.tweet, next);
      const message: Resource = next ? $r('app.string.toast_bookmark_added') :
        $r('app.string.toast_bookmark_removed');
      promptAction.showToast({ message: this.resourceText(message), duration: 1500 });
      if (next) {
        const saved: OfflineSaveResult = await offlineReadingStore.capture(context, this.tweet, saveAccount);
        if (saveAccount === offlineReadingStore.account(context) && (!saved.ok || !saved.complete)) {
          promptAction.showToast({ message: this.resourceText(saved.ok ? $r('app.string.offline_partial_saved') :
            $r('app.string.offline_save_failed')), duration: 2500 });
        }
      }
    } finally {
      this.bookmarkPending = false;
    }
  }

  // A quoted post is a list item of its own inside the card, so it expands from
  // the quoted block rather than from the card that contains it.
  private quotedSharedElementId(): string {
    if (this.sharedElementId.length === 0 || this.tweet.quotedTweet === undefined) {
      return '';
    }
    return this.sharedElementId + '-quote-' + this.tweet.quotedTweet.id;
  }

  // Press feedback for the card itself, independent of how the post opens:
  // every timeline row sinks under the finger, reply rows included.
  private onCardTouch(event?: TouchEvent): void {
    if (event === undefined || !this.pressEffectEnabled) {
      return;
    }
    if (event.type === TouchType.Down) {
      this.getUIContext().animateTo({ duration: motionDuration(180), curve: motionCurve() }, (): void => {
        this.pressScale = motionScale(LIST_ITEM_PRESS_SCALE);
      });
      return;
    }
    if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.getUIContext().animateTo({ duration: motionDuration(180), curve: motionCurve() }, (): void => {
        this.pressScale = 1;
      });
    }
  }

  @Builder
  private PostAttachments(): void {
    if (this.tweet.attachments !== undefined && this.tweet.attachments.length > 0 && this.tweet.presentation?.visibility?.hidden !== true) {
      PostMedia({
        controlsUsePageBackground: !this.transparentBackground, controlSurface: this.readingSurface(),
        sourceTweet: this.tweet,
        attachments: this.tweet.attachments,
        videoFeedEnabled: this.videoFeedEnabled,
        homeTimelineVideo: this.homeTimelineVideo,
        naturalVideoSize: this.naturalVideoSize,
        photoStartOffset: this.hasWidePhotoStrip() ? 64 : 0,
        photoEndOffset: this.hasWidePhotoStrip() ? 8 : 0,
        onMediaPanProgress: (progress: number): void => { this.mediaPanProgress = progress; },
        onPhotoPageChanged: (index: number): void => { this.photoPageIndex = index; },
        onVideoOpen: (media: MediaAttachment): void => {
          this.onVideoOpen(this.tweet, media);
        }
      })
        .width('100%')
        .padding({ start: LengthMetrics.vp(this.hasWidePhotoStrip() ? 0 : 64), end: LengthMetrics.vp(this.hasWidePhotoStrip() ? 0 : 8) })
        .margin({ top: 8 })
    }

  }

  @Builder
  private PostFooter(): void {
    Column({ space: 4 }) {
      if (this.interactivePoll() !== undefined || this.tweet.card !== undefined || this.tweet.article !== undefined || this.tweet.presentation !== undefined) {
        PostInteractiveContent({ postId: this.tweet.id, poll: this.interactivePoll(), card: this.tweet.card,
          article: this.tweet.article, presentation: this.tweet.presentation,
          accentColor: this.accentColor, showPollMedia: (this.tweet.attachments?.length ?? 0) === 0 })
      }
      if (this.tweet.quotedTweet !== undefined && this.tweet.presentation?.visibility?.hidden !== true) {
        QuotedPostCard({
          quoted: this.tweet.quotedTweet,
          accentColor: this.accentColor,
          sharedElementId: this.quotedSharedElementId(),
          onOpen: (quoted: Tweet): void => {
            this.onOpen(quoted, this.quotedSharedElementId());
          }
        })
      }

      PostActionBar({
        surface: this.readingSurface(), transparentBackground: this.transparentBackground,
        readOnly: !this.showActions, replyCount: this.tweet.metrics.replyCount,
        repostCount: this.displayedRepostCount(), likeCount: this.displayedLikeCount(), viewCount: this.displayedViewCount(),
        likeScale: this.reduceMotion ? 1 : this.likeScale, repostRotation: this.reduceMotion ? 0 : this.repostRotation,
        bookmarkScale: this.reduceMotion ? 1 : this.bookmarkScale, liked: this.liked, reposted: this.reposted, bookmarked: this.bookmarked, accentColor: this.accentColor,
        translationEnabled: this.translationEnabled, translating: this.translating, translated: this.translatedText.length > 0,
        onReply: (): void => { if (canPostAction(this.tweet, 'reply')) { this.onReply(this.tweet); } },
        onRepost: (): void => { void this.toggleRepost(); },
        onLike: (): void => { void this.toggleLike(); },
        onBookmark: (): void => { this.toggleBookmark(); },
        onShare: (): void => { sharePost(this.getUIContext().getHostContext() as common.UIAbilityContext, this.tweet); },
        onTranslate: (): void => { this.runTranslation(); }
      })

    }
    .width('100%')
    .padding({ start: LengthMetrics.vp(64), end: LengthMetrics.vp(8), bottom: LengthMetrics.vp(4) })
    .onClick((): void => { this.onOpen(this.tweet, this.sharedElementId); })
  }

  private async toggleRepost(): Promise<void> {
    if (!canPostAction(this.tweet, 'repost') || this.repostPending) { return; }
    this.repostPending = true;
    const next: boolean = !this.reposted;
    try {
      if (await this.onRepostChanged(this.tweet, next)) {
        this.commitRepost(next);
        this.playRepostMotion(next);
        hapticTick();
      }
    } finally { this.repostPending = false; }
  }

  private interactivePoll(): TweetPoll | undefined {
    return this.tweet.poll ?? postPollStore.known(this.tweet.id, this.pollRevision);
  }

  @Builder
  private ConversationLines(): void {
    Column({ space: 0 }) {
      if (!this.narrowColumn && (this.connectAbove || this.connectBelow)) {
        Rect()
          .width($r('app.float.reply_connector_width'))
          .height(this.avatarTop)
          .fill(this.connectAbove ? $r('app.color.reply_connector') : Color.Transparent)
        Blank().height(44)
        Rect()
          .width($r('app.float.reply_connector_width'))
          .height(Math.max(0, this.cardHeight - this.avatarTop - 48))
          .fill(this.connectBelow ? $r('app.color.reply_connector') : Color.Transparent)
      }
    }
    .width($r('app.float.reply_connector_width'))
    .alignItems(HorizontalAlign.Center)
    .hitTestBehavior(HitTestMode.Transparent)
    .accessibilityLevel('no')
  }

  private columnDimension(resource: Resource): number {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    return this.getUIContext().px2vp(context.resourceManager.getNumber(resource.id));
  }

  private narrowCoverAttachments(): MediaAttachment[] {
    return (this.tweet.attachments ?? []).slice(0, 1);
  }

  private narrowHasMedia(): boolean {
    return this.narrowCoverAttachments().length > 0 && this.tweet.presentation?.visibility?.hidden !== true;
  }

  private narrowPreviewLines(): number {
    return this.narrowHasMedia() ? 2 : 6;
  }

  @Builder
  private NarrowTimelineCard(): void {
    Column({ space: 0 }) {
      if (this.narrowHasMedia()) {
        PostMedia({
          controlsUsePageBackground: !this.transparentBackground, controlSurface: this.readingSurface(),
          sourceTweet: this.tweet,
          attachments: this.narrowCoverAttachments(),
          photoViewerAttachments: this.tweet.attachments ?? [],
          videoFeedEnabled: this.videoFeedEnabled,
          homeTimelineVideo: this.homeTimelineVideo,
          naturalVideoSize: true,
          limitNaturalHeight: true,
          // Use the same autoplay and visibility policy as the ordinary feed.
          hideInlineControls: true,
          showDownloadButton: false,
          onVideoOpen: (media: MediaAttachment): void => this.onVideoOpen(this.tweet, media)
        }).width('100%')
      }
      Column({ space: 6 }) {
          if (this.translatedText.length > 0 && !this.promotion && this.tweet.presentation?.visibility?.hidden !== true) {
            PostTranslationInfo({ language: this.tweet.language ?? '', showingOriginal: this.showingOriginal,
              foreground: this.readingText($r('app.color.text_secondary')), accent: this.readingText(this.accentColor),
              onToggle: (): void => { this.showingOriginal = !this.showingOriginal; } })
          }
        // Distinct branches remount EmojiSpans when an asynchronous translation
        // arrives; a helper value passed to its builder retains the initial text.
        if (this.tweet.presentation?.visibility?.hidden !== true) {
          if (this.translationReplaceOriginal && this.translatedText.length > 0 && !this.showingOriginal) {
          Text() {
            PostLinkSpans(this.getUIContext(), this.translatedText, $r('app.float.timeline_column_body_font'), this.systemEmojiEnabled, (url: string): void => this.selectTranslatedPostLink(url))
          }.width('100%').fontSize($r('app.float.timeline_column_body_font'))
            .fontFamily(this.appFontFamily === DEFAULT_APP_FONT_FAMILY ? this.contentFontFamily : this.appFontFamily)
            .fontWeight(FontWeight.Medium).fontColor(this.readingText($r('app.color.text_primary')))
            .maxLines(this.narrowPreviewLines()).textOverflow({ overflow: TextOverflow.Ellipsis })
            .accessibilityText(this.translatedText)
            .bindMenu(this.translatedLinkMenuVisible, this.LinkMenu(), { onDisappear: (): void => { this.translatedLinkMenuVisible = false; } })
            .onClick((): void => this.onOpen(this.tweet, this.sharedElementId))
          } else if (this.tweet.text.length > 0) {
          Text() {
            PostLinkSpans(this.getUIContext(), this.tweet.text, $r('app.float.timeline_column_body_font'), this.systemEmojiEnabled, (url: string): void => this.selectPostLink(url))
          }.width('100%').fontSize($r('app.float.timeline_column_body_font'))
            .fontFamily(this.appFontFamily === DEFAULT_APP_FONT_FAMILY ? this.contentFontFamily : this.appFontFamily)
            .fontWeight(FontWeight.Medium).fontColor(this.readingText($r('app.color.text_primary')))
            .maxLines(this.narrowPreviewLines()).textOverflow({ overflow: TextOverflow.Ellipsis })
            .accessibilityText(this.tweet.text)
            .bindMenu(this.linkMenuVisible, this.LinkMenu(), { onDisappear: (): void => { this.linkMenuVisible = false; } })
            .onClick((): void => this.onOpen(this.tweet, this.sharedElementId))
          }
          if (!this.translationReplaceOriginal && this.translatedText.length > 0 && !this.showingOriginal) {
          Text() {
            PostLinkSpans(this.getUIContext(), this.translatedText, $r('app.float.timeline_column_body_font'), this.systemEmojiEnabled, (url: string): void => this.selectTranslatedPostLink(url))
          }.width('100%').fontSize($r('app.float.timeline_column_body_font'))
            .fontFamily(this.appFontFamily === DEFAULT_APP_FONT_FAMILY ? this.contentFontFamily : this.appFontFamily)
            .fontWeight(FontWeight.Medium).fontColor(this.readingText($r('app.color.text_primary')))
            .maxLines(this.narrowPreviewLines()).textOverflow({ overflow: TextOverflow.Ellipsis })
            .accessibilityText(this.translatedText)
            .bindMenu(this.translatedLinkMenuVisible, this.LinkMenu(), { onDisappear: (): void => { this.translatedLinkMenuVisible = false; } })
            .onClick((): void => this.onOpen(this.tweet, this.sharedElementId))
          }
        }
        if (!this.narrowHasMedia() && (this.interactivePoll() !== undefined || this.tweet.card !== undefined ||
          this.tweet.article !== undefined || this.tweet.presentation !== undefined)) {
          PostInteractiveContent({ postId: this.tweet.id, poll: this.interactivePoll(), card: this.tweet.card,
            article: this.tweet.article, presentation: this.tweet.presentation,
            accentColor: this.accentColor, showPollMedia: true })
        }
        if (!this.narrowHasMedia() && this.tweet.quotedTweet !== undefined && this.tweet.presentation?.visibility?.hidden !== true) {
          QuotedPostCard({ quoted: this.tweet.quotedTweet, narrowColumn: true, accentColor: this.accentColor,
            sharedElementId: this.quotedSharedElementId(),
            onOpen: (quoted: Tweet): void => this.onOpen(quoted, this.quotedSharedElementId()) })
        }
        Row({ space: 4 }) {
          Row({ space: 4 }) {
            SpaceAwareAvatar({ verifiedType: this.tweet.author.verifiedType ?? '',
              avatarShape: this.tweet.author.avatarShape ?? '', userId: this.tweet.author.id,
              url: this.avatarUrl(), avatarSize: this.columnDimension($r('app.float.timeline_column_avatar')),
              radius: this.columnDimension($r('app.float.timeline_column_avatar')) / 2,
              followed: this.tweet.author.following === true,
              tintBackground: true,
              onTintResolved: (palette: AvatarTintPalette | null): void => { this.avatarPalette = palette; },
              fallbackText: this.tweet.author.name.substring(0, 1).toUpperCase(), fallbackColor: this.tweet.author.avatarColor,
              onProfile: (): void => this.onAuthorTapped(this.tweet) })
            Text() { EmojiSpans(this.getUIContext(), this.tweet.author.name, $r('app.float.timeline_column_author_font'), this.systemEmojiEnabled) }
              .fontFamily(this.appFontFamily).fontSize($r('app.float.timeline_column_author_font'))
              .fontColor(this.readingText($r('app.color.text_secondary'))).maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
          }.layoutWeight(1).alignItems(VerticalAlign.Center)
            .onClick((): void => this.onAuthorTapped(this.tweet)).monopolizeEvents(true)
          PostAdLabel({ foreground: this.readingText($r('app.color.text_secondary')), presentation: this.tweet.presentation })
          if (this.showActions && !this.promotion && (this.actionsMask & 4) !== 0) {
            Row({ space: 3 }) {
              SymbolGlyph(this.liked ? $r('sys.symbol.heart_fill') : $r('sys.symbol.heart'))
                .fontSize($r('app.float.timeline_column_action_icon'))
                .fontColor([this.liked ? this.readingText($r('app.color.like')) : this.readingText($r('app.color.text_secondary'))])
                .foregroundFilter(ComponentHdrHighlight.filter(this.getUIContext(), this.componentHdrEnabled && this.liked, this.componentHdrRatio))
                .scale({ x: this.reduceMotion ? 1 : this.likeScale, y: this.reduceMotion ? 1 : this.likeScale })
              Text(formatCount(this.displayedLikeCount())).fontFamily(this.appFontFamily)
                .fontSize($r('app.float.timeline_column_meta_font'))
                .fontColor(this.liked ? this.readingText($r('app.color.like')) : this.readingText($r('app.color.text_secondary'))).maxLines(1)
            }.height($r('app.float.timeline_column_action_target')).flexShrink(0)
              .id('narrow-post-like-' + this.tweet.id).monopolizeEvents(true)
              .accessibilityText(this.metricLabel($r('app.string.action_like'), this.displayedLikeCount()))
              .onClick((): void => { void this.toggleLike(); })
          } else if (this.promotion && this.promotionDismissible) {
            Button({ type: ButtonType.Circle }) {
              SymbolGlyph($r('sys.symbol.xmark')).fontSize($r('app.float.timeline_column_action_icon'))
                .fontColor([this.readingText($r('app.color.text_secondary'))])
            }.width($r('app.float.timeline_column_action_target')).height($r('app.float.timeline_column_action_target'))
              .backgroundColor(Color.Transparent).accessibilityText($r('app.string.xxauth_close'))
              .bindMenu([
                { value: $r('app.string.promotion_hide_once'), action: (): void => this.onPromotionHideSession() },
                { value: $r('app.string.promotion_hide_week'), action: (): void => this.onPromotionHideWeek() }
              ])
          }
        }.width('100%').alignItems(VerticalAlign.Center).id('narrow-post-author-' + this.tweet.id)
        if (!this.promotion) {
          PostOverflowButton({ tweet: this.tweet, inputMenuRequest: this.inputMenuRequest, hideTrigger: true })
        }
      }.width('100%').alignItems(HorizontalAlign.Start).padding($r('app.float.timeline_column_inset'))
    }.width('100%').id('narrow-post-card-' + this.tweet.id)
  }

  private readingText(color: ResourceColor): ResourceColor {
    return pageTextColor(color, this.transparentBackground ? '' : this.pageBackgroundValue, this.readingSurface());
  }

  private readingSurface(): ResourceColor {
    return postCardSurfaceColor(this.transparentBackground ? Color.Transparent :
      this.narrowColumn && !this.avatarTintEnabled ? fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface) :
      avatarTintSurface(this.avatarPalette, this.avatarUrl(), this.avatarTintEnabled,
      this.themeDisplayMode, this.themeDarkSurface, this.avatarThemeDark), this.pageBackgroundValue);
  }

  build(): void {
    if (!this.readerHidden) {
    Column() {
      if (this.narrowColumn) { this.NarrowTimelineCard() } else {
      CommunitySource({ communityId: this.tweet.communityId ?? '', communityName: this.tweet.communityName ?? '', inset: 56 })
      if (this.tweet.pinned) {
        Row({ space: 6 }) {
          SymbolGlyph($r('sys.symbol.pin_fill')).fontSize(13).fontColor([this.readingText($r('app.color.text_secondary'))])
          Text($r('app.string.community_pinned_post')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S'))
            .fontColor(this.readingText($r('app.color.text_secondary')))
        }.width('100%').padding({ start: LengthMetrics.vp(56), top: LengthMetrics.vp(6) })
      }
      if (this.tweet.isRepost) {
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.repeat'))
            .fontSize(14)
            .fontColor([this.readingText($r('app.color.text_secondary'))])
          Text(this.repostLabel()).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_S'))
            .fontWeight(FontWeight.Medium)
            .fontColor(this.readingText($r('app.color.text_secondary')))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .padding({ start: LengthMetrics.vp(38), end: LengthMetrics.vp(12), top: LengthMetrics.vp(8) })
      }
      Row({ space: 8 }) {
          SpaceAwareAvatar({verifiedType: this.tweet.author.verifiedType ?? '', avatarShape: this.tweet.author.avatarShape ?? '',  userId: this.tweet.author.id, url: this.avatarUrl(), avatarSize: 48, radius: 24,
            followed: this.tweet.author.following === true,
            fallbackText: this.tweet.author.name.substring(0, 1).toUpperCase(),
            fallbackColor: this.tweet.author.avatarColor, tintBackground: true,
            onTintResolved: (palette: AvatarTintPalette | null): void => { this.avatarPalette = palette; },
            onProfile: (): void => this.onAuthorTapped(this.tweet) })
            .renderGroup(true)
            .scale({ x: mediaAvatarScale(this.mediaPanProgress), y: mediaAvatarScale(this.mediaPanProgress),
              centerX: '50%', centerY: '50%' })

        Column({ space: 4 }) {
          Column({ space: 1 }) {
            Row({ space: 4 }) {
              Flex({ alignItems: ItemAlign.Center }) {
                Text() { EmojiSpans(this.getUIContext(), this.tweet.author.name, $r('sys.float.Body_L'), this.systemEmojiEnabled) }.fontFamily(this.appFontFamily)
                  .fontSize($r('sys.float.Body_L'))
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.readingText($r('app.color.text_primary')))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .flexShrink(1)
                  .margin({ end: LengthMetrics.vp(4) })
                if (this.tweet.author.verified) {
                  SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
                    .fontSize(16)
                    .fontColor([verificationBadgeColor(this.tweet.author.verifiedType ?? '', this.accentColor)])
                    .flexShrink(0)
                }
                if (this.compactAuthorHeader) {
                  Text(this.authorTimeLabel()).fontFamily(this.appFontFamily)
                    .margin({ start: LengthMetrics.vp(4) })
                    .fontSize($r('sys.float.Body_M')).fontColor(this.readingText($r('app.color.text_secondary')))
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).flexShrink(1)
                }
              }
              .layoutWeight(1)
              .onClick((): void => this.onAuthorTapped(this.tweet))
              PostAdLabel({ foreground: this.readingText($r('app.color.text_secondary')), presentation: this.tweet.presentation })
              // A promotion row reuses this card for identical layout, so the
              // affordances that need a real post are replaced by the dismissal
              // choices the promotion supports.
              if (this.promotion && this.promotionDismissible) {
                Button({ type: ButtonType.Normal, stateEffect: true }) {
                  SymbolGlyph($r('sys.symbol.xmark'))
                    .fontSize(16)
                    .fontColor([this.readingText($r('app.color.text_secondary'))])
                    .accessibilityLevel('no')
                }
                .width(32)
                .height(32)
                .padding(0)
                .backgroundColor(Color.Transparent)
                .flexShrink(0)
                .accessibilityText($r('app.string.xxauth_close'))
                .bindMenu([
                  { value: $r('app.string.promotion_hide_once'), action: (): void => this.onPromotionHideSession() },
                  { value: $r('app.string.promotion_hide_week'), action: (): void => this.onPromotionHideWeek() }
                ])
              } else if (!this.promotion) {
                PostOverflowButton({ compactHeader: true, foreground: this.readingText($r('app.color.text_secondary')), tweet: this.tweet, inputMenuRequest: this.inputMenuRequest })
              }
              if (this.translationEnabled && (this.actionsMask & 64) !== 0 && !this.showActions && !this.promotion) {
                Stack() {
                  SymbolGlyph($r('sys.symbol.ellipsis_circle'))
                    .fontSize(20)
                    .fontColor([this.translatedText.length > 0 ? pageTextColor(this.accentColor, this.transparentBackground ? '' : this.pageBackgroundValue, fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface)) :
                      pageTextColor($r('app.color.text_secondary'), this.transparentBackground ? '' : this.pageBackgroundValue, fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))])
                }
                .width(32)
                .height(32)
                .borderRadius(16)
                .backgroundColor(fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
                .bindMenu(this.translationMenuItems())
              }
            }
            .width('100%')

            if (!this.compactAuthorHeader) {
            Text(this.authorTimeLabel()).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_M'))
              .fontColor(this.readingText($r('app.color.text_secondary')))
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .maxLines(1)
              .width('100%')
              .onClick((): void => this.onAuthorTapped(this.tweet))
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          if (this.translatedText.length > 0 && !this.promotion && this.tweet.presentation?.visibility?.hidden !== true) {
            PostTranslationInfo({ language: this.tweet.language ?? '', showingOriginal: this.showingOriginal,
              foreground: this.readingText($r('app.color.text_secondary')), accent: this.readingText(this.accentColor),
              onToggle: (): void => { this.showingOriginal = !this.showingOriginal; } })
          }
          if (this.showReplyContext && (this.tweet.replyToUsername ?? '').length > 0) {
            Text() {
              Span($r('app.string.compose_replying_to')).fontColor(this.readingText($r('app.color.text_secondary')))
              Span(this.tweet.replyToUsername ?? '').fontColor(this.readingText(this.accentColor))
                .onClick((): void => this.onMentionTapped(this.tweet.replyToUsername ?? ''))
            }.fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          }

          if (this.photoOnlyPost() && (this.tweet.attachments?.length ?? 0) > 1) {
            this.PhotoPageIndicator()
          }

          if (this.translationReplaceOriginal && this.translatedText.length > 0 && !this.showingOriginal) {
            Text(undefined, { controller: this.translatedTextController }) { PostLinkSpans(this.getUIContext(), this.translatedText, $r('sys.float.Body_L'), this.systemEmojiEnabled, (url: string): void => this.selectTranslatedPostLink(url)) }
              .fontSize($r('sys.float.Body_L'))
              .fontFamily(this.appFontFamily === DEFAULT_APP_FONT_FAMILY ? this.contentFontFamily : this.appFontFamily)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.readingText($r('app.color.text_primary')))
              .width('100%')
              .maxLines(this.textExpanded || !this.textIsLong() ? LONG_TEXT_MAX_LINES_EXPANDED :
                LONG_TEXT_MAX_LINES)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .copyOption(CopyOptions.LocalDevice)
              .onMouse((event: MouseEvent): void => {
                if (event.button === MouseButton.Right) { event.stopPropagation(); }
              })
              .accessibilityText(this.translatedText)
            .bindMenu(this.translatedLinkMenuVisible, this.LinkMenu(), { onDisappear: (): void => { this.translatedLinkMenuVisible = false; } })
              .editMenuOptions(new EmojiCopyMenu(this.getUIContext(), this.translatedTextController, this.translatedText, this.systemEmojiEnabled))
              .bindMenu(this.linkMenuVisible, this.LinkMenu(), { onDisappear: (): void => { this.linkMenuVisible = false; } })
              .onClick((): void => {
                this.onOpen(this.tweet, this.sharedElementId);
              })
          } else if (this.tweet.text.length > 0 && this.tweet.presentation?.visibility?.hidden !== true) {
            Text(undefined, { controller: this.bodyTextController }) {
              ForEach(this.mentionSegments(), (segment: MentionSegment) => {
                if (segment.mention) {
                  EmojiSpans(this.getUIContext(), segment.text, $r('sys.float.Body_L'), this.systemEmojiEnabled, (): void => {
                      this.onMentionTapped(segment.handle);
                  })
                } else if (segment.hashtag.length > 0) {
                  EmojiSpans(this.getUIContext(), segment.text, $r('sys.float.Body_L'), this.systemEmojiEnabled, (): void => {
                      requestSearch(segment.text);
                  })
                } else if (segment.url.length > 0) {
                  EmojiSpans(this.getUIContext(), segment.text, $r('sys.float.Body_L'), this.systemEmojiEnabled, (): void => {
                      this.selectPostLink(segment.url);
                  })
                } else {
                  EmojiSpans(this.getUIContext(), segment.text, $r('sys.float.Body_L'), this.systemEmojiEnabled)
                }
              })
            }
              .fontSize($r('sys.float.Body_L'))
              .fontFamily(this.appFontFamily === DEFAULT_APP_FONT_FAMILY ? this.contentFontFamily : this.appFontFamily)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.readingText($r('app.color.text_primary')))
              .width('100%')
              .maxLines(this.textExpanded || !this.textIsLong() ? LONG_TEXT_MAX_LINES_EXPANDED :
                LONG_TEXT_MAX_LINES)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .copyOption(CopyOptions.LocalDevice)
              .onMouse((event: MouseEvent): void => {
                if (event.button === MouseButton.Right) { event.stopPropagation(); }
              })
              .accessibilityText(this.tweet.text)
              .editMenuOptions(new EmojiCopyMenu(this.getUIContext(), this.bodyTextController, this.tweet.text, this.systemEmojiEnabled))
              .bindMenu(this.linkMenuVisible, this.LinkMenu(), { onDisappear: (): void => { this.linkMenuVisible = false; } })
              // Clickable spans handle mentions, hashtags and links first. This
              // handler opens the post when the rest of the body is tapped.
              .onClick((): void => {
                this.onOpen(this.tweet, this.sharedElementId);
              })
          }

          if (this.textIsLong() && this.tweet.presentation?.visibility?.hidden !== true) {
            Text(this.textExpanded ? $r('app.string.post_show_less') :
              $r('app.string.post_show_more')).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_M'))
              .fontWeight(FontWeight.Medium)
              .fontColor(this.readingText($r('app.color.text_accent')))
              .margin({ top: 4 })
              .onClick((): void => {
                this.textExpanded = !this.textExpanded;
              })
          }

          if (this.translating) {
            Row({ space: 6 }) {
              LoadingProgress()
                .width(16)
                .height(16)
                .color(this.accentColor)
              Text($r('app.string.post_translating')).fontFamily(this.appFontFamily)
                .fontSize($r('sys.float.Body_S'))
                .fontColor(this.readingText($r('app.color.text_secondary')))
            }
            .margin({ top: 6 })
          }

          if (this.translatedText.length > 0 && !this.showingOriginal && !this.translationReplaceOriginal && this.tweet.presentation?.visibility?.hidden !== true) {
            Text() { PostLinkSpans(this.getUIContext(), this.translatedText, $r('sys.float.Body_L'), this.systemEmojiEnabled, (url: string): void => this.selectTranslatedPostLink(url)) }.fontFamily(this.appFontFamily)
              .bindMenu(this.translatedLinkMenuVisible, this.LinkMenu(), { onDisappear: (): void => { this.translatedLinkMenuVisible = false; } })
              .fontSize($r('sys.float.Body_L'))
              .fontWeight(FontWeight.Medium)
              .fontColor(this.readingText($r('app.color.text_primary')))
              .width('100%')
              .padding({ start: LengthMetrics.vp(10) })
              .borderWidth({ start: LengthMetrics.vp(2) })
              .borderColor(this.accentColor)
              .margin({ top: 8 })
          }

        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .onClick((): void => {
          this.onOpen(this.tweet, this.sharedElementId);
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      .padding({ left: 8, right: 8, top: 12 })
      .onAreaChange((_oldValue: Area, newValue: Area): void => {
        const top: number = Number(newValue.position.y) + 12;
        if (Math.abs(top - this.avatarTop) > 0.5) {
          this.avatarTop = top;
        }
      })
      this.PostAttachments()
      this.PostFooter()
      }
    }
    .width('100%')
    .borderRadius(this.narrowColumn ? $r('app.float.timeline_column_radius') : 0)
    .clip(this.narrowColumn)
    .backgroundColor(postCardSurfaceColor(this.transparentBackground ? Color.Transparent :
      this.narrowColumn && !this.avatarTintEnabled ? fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface) :
      avatarTintSurface(this.avatarPalette, this.avatarUrl(), this.avatarTintEnabled,
      this.themeDisplayMode, this.themeDarkSurface, this.avatarThemeDark), this.pageBackgroundValue))
    .onAreaChange((_oldValue: Area, newValue: Area): void => {
      const width: number = Number(newValue.width);
      if (width > 0 && Math.abs(width - this.cardWidth) > 1) {
        this.cardWidth = width;
      }
      const height: number = Number(newValue.height);
      if (Math.abs(height - this.cardHeight) > 0.5) {
        this.cardHeight = height;
      }
    })
    .overlay(this.ConversationLines(), { align: Alignment.TopStart, offset: { x: isAppRtl(this.appLocale) ? -31 : 31, y: 0 } })
    .border({ width: { bottom: this.narrowColumn || this.connectBelow ? 0 : 1 }, color: $r('app.color.divider') })
    .scale({ x: this.reduceMotion ? 1 : this.pressScale, y: this.reduceMotion ? 1 : this.pressScale })
    .visualEffect(new hdsEffect.HdsEffectBuilder()
      .pointLight({
        illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
      })
      .buildEffect())
    // The row follows the destination page: the post page leads, the row
    // tracks it, which is what turns the tap into a list expansion instead of
    // two independent elements flying to a meeting point.
    .geometryTransition(this.sharedElementId, { follow: true })
    // Paired with the transition above, as in the official long-take samples:
    // the near-opaque transition keeps the row's node alive for the length of
    // the expansion instead of letting it be torn down the moment the list
    // rebuilds under the opening page.
    .transition(TransitionEffect.opacity(0.99))
    .focusable(true).focusOnTouch(false).hoverEffect(HoverEffect.Highlight)
    .onKeyEvent((event: KeyEvent): boolean => activateInputKey(event, (): void => this.onOpen(this.tweet, this.sharedElementId)))
    .onMouse((event: MouseEvent): void => contextInputMouse(event, (): void => {
      if (!this.promotion) { this.inputMenuRequest++; }
    }))
    .onClick((): void => {
      this.onOpen(this.tweet, this.sharedElementId);
    })
    .onTouch((event?: TouchEvent): void => {
      this.onCardTouch(event);
    })
    .onVisibleAreaApproximateChange({ ratios: [0, 0.1], expectedUpdateInterval: 200 },
      (_visible: boolean, ratio: number): void => {
        this.visibleForViews = ratio > 0.1;
        if (ratio > 0.1) {
          postViewCounts.requestMissing(this.tweet);
          if (this.recordRecommendationSeen) { homeSeenTweetStore.observe(getContext(this), this.tweet.id); }
        }
      })
    }
  }
}
