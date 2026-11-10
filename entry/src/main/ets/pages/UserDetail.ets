import type { VideoFeedRouteParam } from './VideoFeedViewer';
import { pendingMediaViewerSource } from '../utils/MediaViewerMotion';
import { videoPlayerHandoff } from '../services/VideoPlayerHandoff';
import { videoPlaybackPositionStore } from '../services/VideoPlaybackPositionStore';
import { AboutAccountRouteParam } from './AboutAccount';
import { scrollFrame, scrollStarted, scrollStopped, stopScrollOnTouch } from '../utils/ScrollInteraction';
import { ProfileBioTranslation } from '../components/ProfileBioTranslation';
import { AdaptivePostFeed } from '../components/AdaptivePostFeed';
import { pageTextColor } from '../utils/ThemeColors';
import { appPageBackground } from '../components/PageBackgroundLayer';
import { pageCanvasColor, pageReadingSurfaceColor } from '../utils/ThemeColors';
import { STORAGE_KEY_PAGE_TRANSITION_MODE, DEFAULT_PAGE_TRANSITION_MODE } from '../services/PageTransitionSettingsStore';
import { pageSystemTransition, PageTransitionMotion } from '../utils/PageTransition';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { STORAGE_KEY_SYSTEM_EMOJI_ENABLED } from '../services/AppearanceStore';
import { userAvatarRadius, verificationBadgeColor } from '../utils/UserIdentity';
import { DEFAULT_SHEET_MATERIAL_ENABLED, DEFAULT_SHEET_MATERIAL_LEVEL, STORAGE_KEY_SHEET_MATERIAL_ENABLED, STORAGE_KEY_SHEET_MATERIAL_LEVEL } from '../services/SheetMaterialSettingsStore';
import { sheetMaterialOptions } from '../utils/SheetMaterial';
// Profile destination with one continuous banner behind the toolbar and hero.
import common from '@ohos.app.ability.common';
import hilog from '@ohos.hilog';
import promptAction from '@ohos.promptAction';
import { SymbolGlyphModifier } from '@kit.ArkUI';
import {
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  hdsMaterial,
  ScrollEffectType
} from '@kit.UIDesignKit';
import { ConversationTweetCard as TweetCard } from '../components/ConversationTweetCard';
import { FollowSuggestions } from '../components/FollowSuggestions';
import { FollowDiscoveryData, FollowSuggestionGroup } from '../services/FollowDiscoveryData';
import { followStateStore, STORAGE_KEY_FOLLOW_REVISION } from '../services/FollowStateStore';
import { FloatingComposeButton } from '../components/FloatingComposeButton';
import { HdsButton } from '../components/HdsButton';
import { MaterialButton } from '../components/MaterialButton';
import { ProfileActionButtons } from '../components/ProfileActionButtons';
import { AnchoredCover } from '../components/AnchoredCover';
import type { EditProfileRouteParam } from './EditProfile';
import { STORAGE_KEY_EDITED_PROFILE, lastEditedProfile } from '../services/ProfileEditService';
import type { Tweet, TweetAuthor, UserProfile, MediaAttachment, ListPage, ListRow } from '../models/Tweet';
import { formatCount } from '../models/Tweet';
import { formatPostTime, STORAGE_KEY_POST_TIME_NOW } from '../utils/PostTime';
import { XApiClient } from '../services/XApiClient';
import { XWebClient } from '../services/XWebClient';
import { authStore } from '../services/AuthStore';
import type { TweetPage } from '../services/XApiClient';
import { XPrivateResult, xPrivateClient } from '../services/XPrivateClient';
import { XUserParser } from '../services/XUserParser';
import { postModerationStore } from '../services/PostModerationStore';
import { XTimelineParser } from '../services/XTimelineParser';
import { ProfileTweetPage } from '../services/ProfileTweetPage';
import { ProfileAccountData, ProfileActivityPage } from '../services/ProfileAccountData';
import { XListParser } from '../services/XListParser';
import { SpaceAwareAvatar } from '../components/SpaceAwareAvatar';
import { ProxyMediaImage } from '../components/ProxyMediaImage';
import { MentionSegment, splitPostText } from '../utils/MentionText';
import { EmojiSpans } from '../components/EmojiSpans';
import { openExternalLink, requestSearch } from '../utils/PostEntities';
import { shareProfile } from '../utils/SharePost';
import { PhotoViewerPhoto, requestPhotoViewer } from '../utils/PhotoViewerRequest';
import { captureMediaViewerSource, createMediaSourcePrefix, MediaViewerSource } from '../utils/MediaViewerMotion';
import type { ReplyComposerRouteParam } from '../components/ReplyComposer';
import type { ListsRouteParam } from './Lists';
import type { ProfileWebRouteParam } from './ProfileWeb';
import type { DmConversationRouteParam } from './DmConversation';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';
import { DesktopLayout } from '../utils/DesktopLayout';
import {
  STORAGE_KEY_TIMELINE_COLUMNS,
  TIMELINE_COLUMNS_AUTO_TWO,
  TIMELINE_COLUMNS_TWO
} from '../services/TimelineSettingsStore';
import { ProfileTabMotion } from '../utils/ProfileTabMotion';
import { ProfileHeaderAnchor, ProfileHeaderMotion } from '../utils/ProfileHeaderMotion';
import { STORAGE_KEY_HOME_FLOATING_ACTION, HOME_FLOATING_COMPOSE, HOME_FLOATING_HIDDEN,
  HOME_FLOATING_TOP } from '../services/InteractionSettingsStore';
import { destinationTitleBarFullStyleEnabled } from '../utils/DestinationTitleBar';
import { SystemMaterialUtil } from '../utils/SystemMaterial';
import { cardSurfaceColor, fieldSurfaceColor, pageSurfaceColor } from '../utils/ThemeColors';
import { USER_LIST_FOLLOWERS, USER_LIST_FOLLOWING } from './UserList';
import type { UserListRouteParam } from './UserList';
import type { PostDetailRouteParam } from './PostDetail';
import {
  ContentFilterSettings,
  contentFilterStore,
  STORAGE_KEY_FILTER_HIDE_ADS,
  STORAGE_KEY_FILTER_HIDE_REPLIES,
  STORAGE_KEY_FILTER_HIDE_REPOSTS,
  STORAGE_KEY_FILTER_LANGUAGES,
  STORAGE_KEY_FILTER_KEYWORDS,
  STORAGE_KEY_FILTER_MUTED_USERS,
  STORAGE_KEY_FILTER_ONLY_MEDIA,
  STORAGE_KEY_FILTER_REVISION
} from '../services/ContentFilterStore';

const DOMAIN = 0xFF00;
const TAG = 'HarmonyX-Follow';
const PROFILE_TAB_BAR_HEIGHT: number = 52;
const PROFILE_TAB_TRANSITION_DURATION: number = 280;
const PROFILE_COMPACT_ACTIONS_WIDTH: number = 144;

export interface UserDetailRouteParam {
  author: TweetAuthor;
  posts: Tweet[];
  profile?: UserProfile | null;
}

@Builder
export function UserDetailBuilder(): void {
  UserDetail();
}

@Component
export struct UserDetail {
  @StorageProp('harmonyx.page_background') private pageBackgroundValue: string = '';
  @State private pageMotion: PageTransitionMotion = new PageTransitionMotion();
  @StorageProp(STORAGE_KEY_PAGE_TRANSITION_MODE) private pageTransitionMode: string = DEFAULT_PAGE_TRANSITION_MODE;
  @StorageProp('harmonyx.compact_window') private sheetCompactWindow: boolean = false;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp(STORAGE_KEY_HOME_FLOATING_ACTION) private homeFloatingAction: string = HOME_FLOATING_COMPOSE;
  @StorageProp(STORAGE_KEY_SYSTEM_EMOJI_ENABLED) private systemEmojiEnabled: boolean = false;
  @StorageProp('harmonyx.breakpoint') private sheetWindowBreakpoint: string = 'sm';
  @StorageProp('harmonyx.desktop_layout') private desktopLayoutEnabled: boolean = false;
  @StorageProp(STORAGE_KEY_TIMELINE_COLUMNS) private timelineColumnsMode: number = 0;
  @StorageProp(STORAGE_KEY_SHEET_MATERIAL_ENABLED) private sheetMaterialEnabled: boolean = DEFAULT_SHEET_MATERIAL_ENABLED;
  @StorageProp(STORAGE_KEY_SHEET_MATERIAL_LEVEL) private sheetMaterialLevel: number = DEFAULT_SHEET_MATERIAL_LEVEL;
  @StorageProp(STORAGE_KEY_FOLLOW_REVISION) @Watch('syncFollowState') private followRevision: number = 0;
  @StorageProp(STORAGE_KEY_POST_TIME_NOW) private postTimeNow: number = Date.now();
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp('harmonyx.status_bar_height') statusBarHeight: number =
    AppStorage.get<number>('harmonyx.status_bar_height') ?? 0;
  @StorageProp('harmonyx.navigation_indicator_height') navigationIndicatorHeight: number =
    AppStorage.get<number>('harmonyx.navigation_indicator_height') ?? 0;
  @StorageLink('harmonyx.accent_color') accentColor: string = '#007DFF';
  @StorageProp('harmonyx.display_mode') private themeDisplayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private themeDarkSurface: string = '';
  @StorageLink('harmonyx.title_bar_style_mode') titleBarStyleMode: number = 0;
  @StorageLink(STORAGE_KEY_FILTER_ONLY_MEDIA) filterOnlyMedia: boolean = false;
  @StorageLink(STORAGE_KEY_FILTER_HIDE_REPOSTS) filterHideReposts: boolean = false;
  @StorageLink(STORAGE_KEY_FILTER_HIDE_REPLIES) filterHideReplies: boolean = false;
  @StorageLink(STORAGE_KEY_FILTER_HIDE_ADS) filterHideAds: boolean = true;
  @StorageProp(STORAGE_KEY_FILTER_LANGUAGES) private filterLanguages: string = '';
  @StorageLink(STORAGE_KEY_FILTER_KEYWORDS) filterKeywords: string = '';
  @StorageLink(STORAGE_KEY_FILTER_MUTED_USERS) filterMutedUsers: string = '';
  @StorageLink(STORAGE_KEY_FILTER_REVISION) filterRevision: number = 0;
  @State author: TweetAuthor | null = null;
  @State posts: Tweet[] = [];
  @State profile: UserProfile | null = null;
  @State profilePosts: Tweet[] = [];
  @State postsLoaded: boolean = false;
  @State postsLoading: boolean = false;
  @State refreshing: boolean = false;
  @State postsStatus: string = '';
  @State isSelfProfile: boolean = false;
  @State following: boolean = false;
  @State followPending: boolean = false;
  @State followerAdjust: number = 0;
  @State blocking: boolean = false;
  @State blockPending: boolean = false;
  @State replyPosts: Tweet[] = [];
  @State mediaPosts: Tweet[] = [];
  @State repliesLoaded: boolean = false;
  @State mediaLoaded: boolean = false;
  @State repliesLoading: boolean = false;
  @State mediaLoading: boolean = false;
  @State repliesStatus: string = '';
  @State mediaStatus: string = '';
  @StorageProp(STORAGE_KEY_EDITED_PROFILE) @Watch('onProfileEdited') private editedProfileRevision: number = 0;
  private postsCursor: string = '';
  private replyCursor: string = '';
  private mediaCursor: string = '';
  private privateProfileAvailable: boolean = false;
  @State selectedTab: number = 0;
  private readonly activityTabOrder: number[] = [0, 1, 3, 2, 4];
  private activityTabs(): number[] {
    return this.isSelfProfile ? [0, 1, 3, 2, 4, 6] : this.activityTabOrder;
  }

  private activitySwiper: SwiperController = new SwiperController();
  private readonly activityScrollers: Scroller[] = [new Scroller(), new Scroller(), new Scroller(),
    new Scroller(), new Scroller(), new Scroller(), new Scroller()];
  @State private activityIndex: number = 0;
  @State private tabPosition: number = 0;
  @State private tabBarWidth: number = 0;
  @State private tabTextWidths: number[] = [32, 32, 32, 32, 32, 32];
  private tabBarOriginX: number = 0;
  @State private activityPages: ProfileActivityPage[] = [new ProfileActivityPage(),
    new ProfileActivityPage(), new ProfileActivityPage(), new ProfileActivityPage(), new ProfileActivityPage(),
    new ProfileActivityPage(), new ProfileActivityPage()];
  @State private mediaFilter: string = 'video';
  @State private postsFilter: string = 'posts';
  @State private notificationOpen: boolean = false;
  @State private notificationMode: number = -1;
  @State private actionPending: boolean = false;
  @State private muted: boolean = false;
  @State private repostsEnabled: boolean = true;
  @State private listPickerOpen: boolean = false;
  @State private profileMenuOpen: boolean = false;
  @State private listLoading: boolean = false;
  @State private ownedLists: ListRow[] = [];
  @State private memberListIds: string[] = [];
  @State private listStatus: string = '';
  private listCursor: string = '';
  private alive: boolean = true;
  @State private suggestionGroups: FollowSuggestionGroup[] = [];
  @State private headerScrollOffset: number = 0;
  @State private headerPullOffset: number = 0;
  @State private headerOriginX: number = 0;
  @State private headerOriginY: number = 0;
  @State private heroAvatarAnchor: ProfileHeaderAnchor = new ProfileHeaderAnchor();
  @State private heroNameAnchor: ProfileHeaderAnchor = new ProfileHeaderAnchor();
  @State private titleNameAnchor: ProfileHeaderAnchor = new ProfileHeaderAnchor();
  @State private heroActionsAnchor: ProfileHeaderAnchor = new ProfileHeaderAnchor();
  @State private titleActionsAnchor: ProfileHeaderAnchor = new ProfileHeaderAnchor();
  @State viewportHeight: number = 0;
  private scroller: Scroller = new Scroller();
  private api: XApiClient = new XApiClient();
  private webClient: XWebClient = new XWebClient();

  aboutToAppear(): void {
    setTimeout((): void => {
      this.loadRoute();
      const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      contentFilterStore.load(context);
      this.scroller.scrollEdge(Edge.Top);
      this.headerScrollOffset = 0;
      this.loadLiveProfile();
    }, 30);
  }

  private loadRoute(): void {
    const params: UserDetailRouteParam[] = this.pageStack.getParamByName('UserDetail') as UserDetailRouteParam[];
    if (params === undefined || params === null || params.length === 0) {
      return;
    }
    const param: UserDetailRouteParam = params[params.length - 1];
    this.author = param.author;
    this.posts = param.posts;
    // Self controls and the known header do not depend on a network response.
    this.isSelfProfile = param.author.id.length > 0 &&
      (param.author.id === xPrivateClient.viewerId() || param.author.id === authStore.getUserId());
    if (param.profile !== undefined && param.profile !== null && param.profile.id === param.author.id) {
      this.profile = param.profile;
    }
  }

  private async loadLiveProfile(): Promise<void> {
    const current: TweetAuthor | null = this.author;
    // Mentions only carry a handle, so a profile opened from one has no id yet;
    // the private path resolves everything from the screen name.
    if (current === null || (current.id.length === 0 && current.username.length === 0)) {
      return;
    }
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    await authStore.load(context);

    // Private session first: UserByScreenName resolves the canonical profile
    // (avatar, banner, counts) and the profile timeline in one credential,
    // without depending on an OAuth token or a paid API tier.
    xPrivateClient.load(context);
    if (xPrivateClient.isSignedIn()) {
      let profileResult: XPrivateResult = await xPrivateClient.userByScreenName(current.username);
      let privateProfile: UserProfile | null =
        profileResult.ok ? XUserParser.parse(profileResult.body) : null;
      if (privateProfile === null && current.id.length > 0) {
        profileResult = await xPrivateClient.userByRestId(current.id);
        privateProfile = profileResult.ok ? XUserParser.parse(profileResult.body) : null;
      }
      if (privateProfile !== null) {
        this.privateProfileAvailable = true;
        this.profile = privateProfile;
        this.following = privateProfile.following === true;
        this.blocking = privateProfile.blocking === true;
        this.muted = privateProfile.muting === true;
        this.loadRelationship();
        this.isSelfProfile = xPrivateClient.viewerId() === privateProfile.id;
        if (this.activitySource(this.selectedTab) > 0) {
          this.loadProfilePage(this.activitySource(this.selectedTab), true);
        }
        await this.loadProfilePage(0, true);
        return;
      }
    }

    if (!authStore.isSignedIn()) {
      const publicProfile: UserProfile | null = await this.webClient.fetchPublicProfile(current.username);
      if (publicProfile !== null) {
        this.profile = publicProfile;
        this.following = publicProfile.following === true;
      }
      return;
    }
    if (current.id.length === 0) {
      return;
    }
    this.isSelfProfile = authStore.getUserId() === current.id;
    this.api.setToken(authStore.getToken());
    this.api.setUser(authStore.getUserId());
    const liveProfile: UserProfile | null = await this.api.userProfile(current.id);
    if (liveProfile !== null) {
      this.profile = liveProfile;
      this.following = liveProfile.following === true;
    }
    if (this.activitySource(this.selectedTab) > 0) {
      this.loadProfilePage(this.activitySource(this.selectedTab), true);
    }
    await this.loadProfilePage(0, true);
  }

  private text(resource: Resource): string {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    return context.resourceManager.getStringSync(resource);
  }

  private postsForAuthor(): Tweet[] {
    const current: TweetAuthor | null = this.author;
    if (current === null) {
      return [];
    }
    const result: Tweet[] = [];
    for (let index: number = 0; index < this.posts.length; index++) {
      const post: Tweet = this.posts[index];
      if (post.author.id === current.id) {
        result.push(post);
      }
    }
    return result;
  }

  private displayPosts(): Tweet[] {
    return this.activityPages[0].loaded ? this.activityPages[0].posts : this.postsForAuthor();
  }

  private contentFilterSettings(tab: number = 0): ContentFilterSettings {
    return new ContentFilterSettings(
      tab === 0 ? this.filterOnlyMedia : false,
      this.filterHideReposts,
      tab === 0 ? this.filterHideReplies : false,
      this.filterKeywords,
      this.filterMutedUsers,
      this.filterHideAds, this.filterLanguages
    );
  }

  private filteredPosts(posts: Tweet[], tab: number = 0): Tweet[] {
    return contentFilterStore.filter(posts, this.contentFilterSettings(tab));
  }

  private visibleDisplayPosts(): Tweet[] {
    return this.filteredPosts(this.displayPosts());
  }

  private authorName(): string {
    if (this.profile !== null && this.profile.name.length > 0) {
      return this.profile.name;
    }
    return this.author === null ? '' : this.author.name;
  }

  private authorHandle(): string {
    if (this.profile !== null && this.profile.username.length > 0) {
      return '@' + this.profile.username;
    }
    return this.author === null ? '' : '@' + this.author.username;
  }

  private avatarUrl(): string {
    if (this.profile !== null && this.profile.avatarUrl !== undefined) {
      return this.profile.avatarUrl;
    }
    return this.author === null || this.author.avatarUrl === undefined ? '' : this.author.avatarUrl;
  }

  private updateHeaderScroll(): void {
    const offset: number = this.scroller.currentOffset().yOffset;
    if (isFinite(offset) && this.headerScrollOffset !== offset) {
      this.headerScrollOffset = offset;
    }
  }

  private headerAnchor(area: Area, scrolling: boolean): ProfileHeaderAnchor {
    return new ProfileHeaderAnchor(Number(area.globalPosition.x),
      Number(area.globalPosition.y) + (scrolling ? this.scroller.currentOffset().yOffset : 0),
      Number(area.width), Number(area.height));
  }

  private headerAnchorsReady(): boolean {
    return this.heroAvatarAnchor.width > 0 && this.heroNameAnchor.width > 0 &&
      this.titleNameAnchor.width > 0;
  }

  private headerProgress(): number {
    if (!this.headerAnchorsReady()) {
      return 0;
    }
    // Begin when the avatar reaches the toolbar; finish when the hero name
    // would reach its title position. Both endpoints follow the actual layout.
    const start: number = Math.max(0, this.heroAvatarAnchor.y -
      (this.headerOriginY + this.statusBarHeight + 60));
    const end: number = Math.max(start + 1, this.heroNameAnchor.y - this.titleNameAnchor.y);
    return ProfileHeaderMotion.progress(this.headerScrollOffset, start, end);
  }

  private actionAnchorsReady(): boolean {
    return !this.isSelfProfile && this.heroActionsAnchor.width > 0 && this.titleActionsAnchor.width > 0;
  }

  private headerActionsProgress(): number {
    if (!this.actionAnchorsReady()) { return 0; }
    const end: number = Math.max(1, this.heroActionsAnchor.y - this.titleActionsAnchor.y);
    return ProfileHeaderMotion.progress(this.headerScrollOffset, Math.max(0, end - 52), end);
  }


  private headerActionsX(): number {
    return ProfileHeaderMotion.interpolate(this.heroActionsAnchor.x, this.titleActionsAnchor.x,
      this.headerActionsProgress()) - this.headerOriginX;
  }

  private headerActionsY(): number {
    return ProfileHeaderMotion.interpolate(this.heroActionsAnchor.y - this.headerScrollOffset,
      this.titleActionsAnchor.y, this.headerActionsProgress()) - this.headerOriginY;
  }

  private refreshCurrentProfilePage(): void {
    this.refreshing = true;
    this.loadProfilePage(this.activitySource(this.selectedTab), true).then((): void => {
      this.refreshing = false;
    });
  }

  private bannerUrl(): string {
    if (this.profile !== null && this.profile.bannerUrl !== undefined) {
      return this.profile.bannerUrl;
    }
    return '';
  }

  private profileDescription(): string {
    return this.profile === null ? '' : this.profile.description;
  }

  private isVerified(): boolean {
    return this.profile !== null ? this.profile.verified : (this.author !== null && this.author.verified);
  }

  private profilePostCount(): number {
    return this.profile === null ? this.postsForAuthor().length : this.profile.postCount;
  }

  private followingCount(): string {
    return this.profile === null ? '–' : this.exactCount(this.profile.followingCount);
  }

  private followersCount(): string {
    const current: UserProfile | null = this.profile;
    if (current === null) {
      return '-';
    }
    return this.exactCount(Math.max(0, current.followersCount + this.followerAdjust));
  }

  private followLabel(): Resource {
    return this.following ? $r('app.string.profile_detail_following') :
      $r('app.string.profile_detail_follow');
  }

  private async toggleFollow(): Promise<void> {
    const current: TweetAuthor | null = this.author;
    if (this.followPending || this.isSelfProfile || current === null) {
      return;
    }
    // A profile opened from a mention starts without an id; the loaded profile
    // carries the canonical rest_id, which the follow endpoint needs.
    const userId: string = this.resolvedUserId();
    if (userId.length === 0) {
      promptAction.showToast({
        message: this.text($r('app.string.profile_not_ready')),
        duration: 2000
      });
      return;
    }
    if (!xPrivateClient.isSignedIn()) {
      promptAction.showToast({ message: this.text($r('app.string.profile_follow_sign_in')), duration: 2000 });
      return;
    }
    const next: boolean = !this.following;
    const viewer: string = xPrivateClient.viewerId();
    this.followPending = true;
    const result: XPrivateResult = await xPrivateClient.follow(userId, next);
    this.followPending = false;
    if (!this.alive || viewer !== xPrivateClient.viewerId()) { return; }
    hilog.info(DOMAIN, TAG, 'follow id=%{public}s following=%{public}s status=%{public}d',
      userId, String(next), result.status);
    if (!result.ok) {
      promptAction.showToast({
        message: this.text($r('app.string.profile_follow_failed')) + ' · HTTP ' + result.status,
        duration: 2000
      });
      return;
    }
    this.following = next;
    followStateStore.set(viewer, userId, next);
    this.followerAdjust = this.followerAdjust + (next ? 1 : -1);
  }

  private syncFollowState(): void {
    const following: boolean | undefined = followStateStore.get(xPrivateClient.viewerId(), this.resolvedUserId());
    if (following !== undefined && following !== this.following) {
      this.following = following;
      this.followerAdjust += following ? 1 : -1;
    }
  }

  // The id the follow/block endpoints require: the loaded profile's rest_id
  // first, then the route author, which is empty when the page came from a
  // mention and the author was never part of a post payload.
  private resolvedUserId(): string {
    const current: UserProfile | null = this.profile;
    if (current !== null && current.id.length > 0) {
      return current.id;
    }
    const author: TweetAuthor | null = this.author;
    return author === null ? '' : author.id;
  }

  private back(): void {
    ResponsiveLayout.closeContentDestination(this.pageStack);
  }

  // The platform's own page transition, as on every other post entry point.
  private openPostFromProfile(post: Tweet): void {
    const param: PostDetailRouteParam = { tweet: post };
    this.pageStack.pushPath({ name: 'PostDetail', param: param });
  }

  private openMention(handle: string): void {
    if (handle.length === 0) {
      return;
    }
    const author: TweetAuthor = {
      id: '',
      name: handle,
      username: handle,
      avatarColor: this.accentColor,
      verified: false
    };
    const param: UserDetailRouteParam = { author: author, posts: [] };
    this.pageStack.pushPath({ name: 'UserDetail', param: param });
  }

  private openUserList(mode: string): void {
    const userId: string = this.resolvedUserId();
    if (userId.length === 0) {
      promptAction.showToast({
        message: this.text($r('app.string.profile_not_ready')),
        duration: 2000
      });
      return;
    }
    const param: UserListRouteParam = { mode: mode, userId: userId };
    this.pageStack.pushPath({ name: 'UserList', param: param });
  }

  private selectTab(index: number): void {
    const position: number = this.activityTabs().indexOf(index);
    if (position < 0) {
      return;
    }
    this.ensureActivityLoaded(index);
    if (position !== this.activityIndex) {
      this.activitySwiper.changeIndex(position, true);
    }
  }

  private ensureActivityLoaded(index: number): void {
    const source: number = this.activitySource(index);
    const page: ProfileActivityPage = this.activityPages[source];
    if (!page.loaded && !page.loading && page.status.length === 0) {
      this.loadProfilePage(source, true);
    }
  }

  private activitySource(tab: number): number {
    return tab === 0 && this.postsFilter === 'highlights' ? 5 : tab;
  }

  private choosePostsFilter(filter: string): void {
    if (this.postsFilter !== filter) {
      this.postsFilter = filter;
      this.activityScrollers[0].scrollEdge(Edge.Top);
      this.ensureActivityLoaded(0);
    }
  }

  private chooseMediaFilter(filter: string): void {
    if (this.mediaFilter !== filter) {
      this.mediaFilter = filter;
      this.activityScrollers[2].scrollEdge(Edge.Top);
      this.ensureActivityLoaded(2);
    }
  }

  private onActivityScroll(index: number, position: number): void {
    const progress: number = ProfileTabMotion.scrollPosition(index, position, this.activityTabs().length);
    if (Math.abs(this.tabPosition - progress) > 0.0001) {
      this.tabPosition = progress;
    }
    this.ensureActivityLoaded(this.activityTabs()[index]);
  }

  private activityChanged(index: number): void {
    this.activityIndex = index;
    this.selectedTab = this.activityTabs()[index];
    this.ensureActivityLoaded(this.selectedTab);
  }

  private tabPosts(tab: number): Tweet[] {
    const source: Tweet[] = tab === 0 && this.postsFilter === 'posts' ? this.displayPosts() :
      this.activityPages[this.activitySource(tab)].posts;
    const filtered: Tweet[] = this.filteredPosts(source, tab);
    const out: Tweet[] = [];
    for (let i: number = 0; i < filtered.length; i++) {
      const post: Tweet = filtered[i];
      if (tab === 2 && this.mediaFilter === 'video' && ProfileAccountData.video(post) === null) {
        continue;
      }
      if (tab === 2 && this.mediaFilter === 'photo' &&
        !(post.attachments ?? []).some((m: MediaAttachment): boolean => m.type === 'photo')) {
        continue;
      }
      out.push(post);
    }
    return out;
  }

  private tabMoreCursor(tab: number): string {
    return this.activityPages[this.activitySource(tab)].cursor;
  }

  private currentTabLoading(tab: number): boolean {
    return this.activityPages[this.activitySource(tab)].loading;
  }

  private currentTabStatus(tab: number): string {
    return this.activityPages[this.activitySource(tab)].status;
  }

  private retryTab(tab: number): void {
    const source: number = this.activitySource(tab);
    this.loadProfilePage(source, this.activityPages[source].posts.length === 0);
  }

  private notifyActivityChanged(): void {
    this.activityPages = [...this.activityPages];
  }

  private async loadProfilePage(tab: number, replace: boolean): Promise<void> {
    if (tab === 6 && !this.isSelfProfile) { return; }
    const userId: string = this.resolvedUserId();
    const state: ProfileActivityPage = this.activityPages[tab];
    if (userId.length === 0 || state.loading || (!replace && state.cursor.length === 0)) {
      return;
    }
    const cursor: string = replace ? '' : state.cursor;
    state.loading = true;
    state.status = '';
    this.notifyActivityChanged();
    let page: TweetPage | null = null;
    let result: XPrivateResult | null = null;
    try {
      if (this.privateProfileAvailable) {
        if (tab === 0) {
          result = await xPrivateClient.userTweets(userId, cursor, 20);
        } else if (tab === 1) {
          result = await xPrivateClient.userTweetsAndReplies(userId, cursor, 20);
        } else if (tab === 2) {
          result = await xPrivateClient.userMedia(userId, cursor, 20);
        } else if (tab === 6) {
          result = await xPrivateClient.userLikes(userId, cursor, 20);
        } else if (tab === 5) {
          result = await xPrivateClient.userHighlights(userId, cursor, 20);
        } else {
          result = await xPrivateClient.userProfileActivity(userId, cursor, 20, tab === 4);
        }
        page = result.ok ? XTimelineParser.parse(result.body) : null;
        if (result.ok && tab === 0 && this.alive) {
          const suggestions: FollowDiscoveryData | null = FollowDiscoveryData.parse(result.body);
          if (suggestions !== null) {
            this.suggestionGroups = replace ? suggestions.groups :
              [...this.suggestionGroups, ...suggestions.groups.filter((group: FollowSuggestionGroup): boolean =>
                !this.suggestionGroups.some((existing: FollowSuggestionGroup): boolean => existing.id === group.id))];
          }
        }
      }
      if (page === null && tab === 6 && authStore.isSignedIn()) {
        this.api.setToken(authStore.getToken());
        this.api.setUser(authStore.getUserId());
        page = await this.api.userLikesPage(userId, cursor);
      }
      if (page === null && authStore.isSignedIn() && (!this.privateProfileAvailable || tab === 0) && tab < 3) {
        this.api.setToken(authStore.getToken());
        this.api.setUser(authStore.getUserId());
        page = await this.api.userPostsPage(userId, cursor);
      }
    } catch (error) {
      page = null;
    }
    if (!this.alive) {
      return;
    }
    state.loading = false;
    if (page === null) {
      state.status = this.text($r('app.string.profile_load_failed')) +
        (result !== null && result.status > 0 ? ' · HTTP ' + result.status : '');
    } else {
      state.posts = ProfileTweetPage.merge(tab, state.posts, page.tweets, replace);
      state.cursor = page.nextToken === cursor ? '' : page.nextToken;
      state.loaded = true;
    }
    this.notifyActivityChanged();
  }

  private profileMenuItems(): MenuElement[] {
    if (this.isSelfProfile) {
      return [{ value: this.text($r('app.string.profile_about_title')), action: (): void => { this.openAbout(); } }];
    }
    return [
      { value: this.text($r('app.string.profile_grok')) + ' ' + this.authorHandle(),
        action: (): void => this.openWeb('https://x.com/i/grok', this.text($r('app.string.profile_grok'))) },
      { value: this.text($r('app.string.profile_search')),
        action: (): void => requestSearch('from:' + this.authorHandle().substring(1)) },
      { value: this.text(this.repostsEnabled ? $r('app.string.profile_reposts_off') :
        $r('app.string.profile_reposts_on')), action: (): void => { this.toggleReposts(); } },
      { value: this.text($r('app.string.profile_list_manage')), action: (): void => { this.openListPicker(); } },
      { value: this.text($r('app.string.profile_lists_view')), action: (): void => this.openLists(false) },
      { value: this.text($r('app.string.profile_lists_member')), action: (): void => this.openLists(true) },
      { value: this.text(this.muted ? $r('app.string.profile_unmute') : $r('app.string.profile_mute')) +
        ' ' + this.authorHandle(), action: (): void => { this.toggleMute(); } },
      { value: this.text(this.blocking ? $r('app.string.menu_unblock_user') : $r('app.string.menu_block_user')) +
        ' ' + this.authorHandle(), action: (): void => { this.toggleBlock(); } },
      { value: this.text($r('app.string.profile_report')) + ' ' + this.authorHandle(),
        action: (): void => this.openWeb(this.profileUrl(), this.text($r('app.string.profile_report'))) }
    ];
  }

  private profileUrl(): string {
    return 'https://x.com/' + encodeURIComponent(this.authorHandle().substring(1));
  }

  private openWeb(url: string, title: string): void {
    const param: ProfileWebRouteParam = { url: url, title: title };
    this.pageStack.pushPath({ name: 'ProfileWeb', param: param });
  }

  private exactCount(value: number): string {
    return Math.max(0, value).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');
  }

  private joinedDate(): string {
    const date: Date = new Date(this.profile === null ? '' : this.profile.createdAt ?? '');
    if (isNaN(date.getTime())) {
      return this.text($r('app.string.profile_info_unavailable'));
    }
    return (getContext(this) as common.UIAbilityContext).resourceManager.getStringSync(
      $r('app.string.profile_year_month'), date.getFullYear(), date.getMonth() + 1);
  }

  private profileMediaPrefix: string = createMediaSourcePrefix();

  private openProfileImage(banner: boolean, avatarSource: string = 'hero'): void {
    const url: string = banner ? this.bannerUrl() : this.avatarUrl();
    if (url.length > 0) {
      const sourceId: string = this.profileMediaPrefix + (banner ? 'banner' : avatarSource);
      const radius: number = banner ? 0 : userAvatarRadius(84, 42,
        this.profile?.verifiedType ?? this.author?.verifiedType ?? '',
        this.profile?.avatarShape ?? this.author?.avatarShape ?? '');
      const source: MediaViewerSource | undefined = captureMediaViewerSource(this.getUIContext(), sourceId,
        sourceId, banner ? 1500 : 400, banner ? 500 : 400, false, radius);
      requestPhotoViewer([new PhotoViewerPhoto(url, url, banner ? 1500 : 400, banner ? 500 : 400,
        0, this.authorName(), sourceId)], 0, this.authorName(), '', null, source);
    }
  }

  private async openAbout(): Promise<void> {
    if (this.author === null) { return; }
    const author: TweetAuthor = {
      id: this.resolvedUserId(), name: this.authorName(), username: this.authorHandle().substring(1),
      avatarColor: this.author.avatarColor, avatarUrl: this.avatarUrl(), verified: this.isVerified(),
      verifiedType: this.profile?.verifiedType ?? this.author.verifiedType,
      avatarShape: this.profile?.avatarShape ?? this.author.avatarShape
    };
    const param: AboutAccountRouteParam = { author: author, joined: this.joinedDate() };
    this.pageStack.pushPath({ name: 'AboutAccount', param: param });
  }

  private onProfileTouchIntercept(event: TouchEvent): HitTestMode {
    if (event.type === TouchType.Down && event.touches.length > 0) {
      try {
        const node = this.getUIContext().getFrameNodeById('profile-post-feed-' + this.selectedTab.toString());
        if (node !== null) {
          const top: number = node.getPositionToWindowWithTransform().y;
          // Let the inner WaterFlow receive the stopping press and the next
          // drag. Blocking it here strands the gesture on a collapsed parent.
          if (event.touches[0].windowY >= top) { return HitTestMode.Default; }
        }
      } catch (error) { }
    }
    return stopScrollOnTouch(event, this.scroller, [this.activityScrollers[this.selectedTab]]);
  }

  private isDesktopLayout(): boolean {
    return DesktopLayout.active(this.desktopLayoutEnabled, this.sheetWindowBreakpoint);
  }

  private useTimelineWaterFlow(): boolean {
    return this.isDesktopLayout() || ResponsiveLayout.isLarge(this.sheetWindowBreakpoint) ||
      this.timelineColumnsMode === TIMELINE_COLUMNS_TWO ||
      this.timelineColumnsMode === TIMELINE_COLUMNS_AUTO_TWO;
  }

  private useListFeed(): boolean {
    return !this.useTimelineWaterFlow();
  }

  private async loadRelationship(): Promise<void> {
    const result: XPrivateResult = await xPrivateClient.rest('GET', '/1.1/friendships/show.json',
      { 'target_id': this.resolvedUserId() });
    if (!result.ok || !this.alive) {
      return;
    }
    try {
      const root: Record<string, Object> = JSON.parse(result.body) as Record<string, Object>;
      const relationship: Record<string, Object> = root['relationship'] as Record<string, Object>;
      const source: Record<string, Object> = relationship['source'] as Record<string, Object>;
      this.repostsEnabled = source['want_retweets'] !== false;
      this.muted = source['muting'] === true;
      if (source['notifications_enabled'] !== undefined) {
        this.notificationMode = source['notifications_enabled'] === true ? 0 : 3;
      }
    } catch (error) {
      // Keep the state unresolved when X does not expose the relationship.
    }
  }

  private canAct(): boolean {
    if (this.actionPending || this.isSelfProfile) {
      return false;
    }
    if (this.resolvedUserId().length === 0 || !xPrivateClient.isSignedIn()) {
      promptAction.showToast({ message: this.text($r('app.string.profile_follow_sign_in')) });
      return false;
    }
    return true;
  }

  private async toggleReposts(): Promise<void> {
    if (!this.canAct()) { return; }
    this.actionPending = true;
    const result: XPrivateResult = await xPrivateClient.updateReposts(this.resolvedUserId(), !this.repostsEnabled);
    this.actionPending = false;
    if (result.ok) {
      this.repostsEnabled = !this.repostsEnabled;
    }
    this.actionFeedback(result);
  }

  private async toggleMute(): Promise<void> {
    if (!this.canAct()) { return; }
    this.actionPending = true;
    const result: XPrivateResult = await xPrivateClient.muteUser(this.resolvedUserId(), !this.muted);
    this.actionPending = false;
    if (result.ok) {
      this.muted = !this.muted;
      void this.syncReaderModeration();
    }
    this.actionFeedback(result);
  }

  private async syncReaderModeration(): Promise<void> {
    const generation: number = xPrivateClient.sessionGeneration();
    const userId: string = this.resolvedUserId();
    try {
      const result: XPrivateResult = await xPrivateClient.userByRestId(userId, true);
      if (!this.alive || generation !== xPrivateClient.sessionGeneration()) { return; }
      const profile: UserProfile | null = result.ok ? XUserParser.parse(result.body) : null;
      if (profile === null) { return; }
      const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      if (profile.muting === true || profile.blocking === true) { postModerationStore.hide(context, userId, true); }
      else if (profile.muting === false && profile.blocking === false) { postModerationStore.unhideUser(context, userId); }
    } catch (error) { }
  }

  private actionFeedback(result: XPrivateResult): void {
    promptAction.showToast({ message: this.text(result.ok ? $r('app.string.profile_setting_saved') :
      $r('app.string.profile_setting_failed')) + (result.ok ? '' : ' · HTTP ' + result.status) });
  }

  private async setNotificationMode(mode: number): Promise<void> {
    if (!this.canAct()) { return; }
    if (mode === 1 || mode === 2) {
      this.notificationOpen = false;
      promptAction.showToast({ message: this.text($r('app.string.profile_notification_web')) });
      this.openWeb(this.profileUrl(), this.text($r('app.string.profile_notifications')));
      return;
    }
    this.actionPending = true;
    const result: XPrivateResult = await xPrivateClient.updatePostNotifications(this.resolvedUserId(), mode === 0);
    this.actionPending = false;
    if (result.ok) {
      this.notificationMode = mode;
      this.notificationOpen = false;
    }
    this.actionFeedback(result);
  }

  private openLists(memberships: boolean): void {
    const param: ListsRouteParam = { userId: this.resolvedUserId(), memberships: memberships,
      title: this.text(memberships ? $r('app.string.profile_lists_member') : $r('app.string.profile_lists_view')) };
    this.pageStack.pushPath({ name: 'Lists', param: param });
  }

  private async openListPicker(): Promise<void> {
    if (!this.canAct()) { return; }
    this.listPickerOpen = true;
    this.listLoading = true;
    this.listStatus = '';
    this.ownedLists = [];
    this.memberListIds = [];
    let cursor: string = '';
    do {
      const result: XPrivateResult = await xPrivateClient.userLists(this.resolvedUserId(), cursor, true);
      const page: ListPage | null = result.ok ? XListParser.parse(result.body) : null;
      if (page === null) {
        this.listStatus = this.text($r('app.string.lists_failed'));
        break;
      }
      for (let i: number = 0; i < page.lists.length; i++) {
        this.memberListIds.push(page.lists[i].id);
      }
      const next: string = page.nextToken;
      if (next.length === 0 || next === cursor) { break; }
      cursor = next;
    } while (this.alive && this.listPickerOpen);
    this.listCursor = '';
    await this.loadOwnedLists(true);
    this.listLoading = false;
  }

  private async loadOwnedLists(reset: boolean): Promise<void> {
    const result: XPrivateResult = await xPrivateClient.userLists(xPrivateClient.viewerId(),
      reset ? '' : this.listCursor, false, this.resolvedUserId());
    const page: ListPage | null = result.ok ? XListParser.parse(result.body) : null;
    if (page === null) {
      this.listStatus = this.text($r('app.string.lists_failed'));
      return;
    }
    const rows: ListRow[] = reset ? [] : [...this.ownedLists];
    for (let i: number = 0; i < page.lists.length; i++) {
      if (!rows.some((row: ListRow): boolean => row.id === page.lists[i].id)) {
        rows.push(page.lists[i]);
      }
    }
    this.ownedLists = rows;
    this.memberListIds = [...this.memberListIds];
    this.listCursor = page.nextToken === this.listCursor ? '' : page.nextToken;
  }

  private async toggleList(row: ListRow): Promise<void> {
    if (this.actionPending || this.listStatus.length > 0) { return; }
    this.actionPending = true;
    const member: boolean = this.memberListIds.indexOf(row.id) >= 0;
    const result: XPrivateResult = await xPrivateClient.rest('POST', member ?
      '/1.1/lists/members/destroy.json' : '/1.1/lists/members/create.json',
      { 'list_id': row.id, 'user_id': this.resolvedUserId() });
    this.actionPending = false;
    if (result.ok) {
      const ids: string[] = this.memberListIds.filter((id: string): boolean => id !== row.id);
      if (!member) { ids.push(row.id); }
      this.memberListIds = ids;
    }
    this.actionFeedback(result);
  }

  private openMessages(): void {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    xPrivateClient.load(context);
    const userId: string = this.resolvedUserId();
    const viewerId: string = xPrivateClient.viewerId();
    if (!xPrivateClient.isSignedIn() || viewerId.length === 0) {
      promptAction.showToast({ message: this.text($r('app.string.profile_follow_sign_in')) }); return;
    }
    if (userId.length === 0 || userId === viewerId) {
      promptAction.showToast({ message: this.text($r('app.string.profile_not_ready')) }); return;
    }
    const ids: string[] = [viewerId, userId];
    ids.sort((left: string, right: string): number => left.length !== right.length ? left.length - right.length :
      left > right ? 1 : left < right ? -1 : 0);
    const param: DmConversationRouteParam = { conversationId: ids.join('-'), title: this.authorName(),
      username: this.authorHandle().replace(/^@/, ''), avatarUrl: this.avatarUrl(), group: false,
      participantIds: ids, latestSequenceId: '', contactProfile: this.profile ?? undefined };
    this.pageStack.pushPath({ name: 'DmConversation', param: param });
  }

  private replyToAuthor(): void {
    const handle: string = this.authorHandle();
    if (handle.length <= 1) {
      promptAction.showToast({ message: this.text($r('app.string.profile_not_ready')) });
      return;
    }
    // A profile addresses an author through a mention; only post replies carry
    // an in_reply_to id. The author id must never be sent as a post id.
    const param: ReplyComposerRouteParam = { replyToId: '', replyToUser: handle.substring(1), avatarUrl: '',
      avatarName: '', avatarColor: this.accentColor, initialText: handle + ' ', imageUri: '', gifUri: '',
      communityId: '', communityName: '', parentTweet: null };
    this.pageStack.pushPath({ name: 'ReplyComposer', param: param });
  }

  private async onLike(post: Tweet, liked: boolean): Promise<boolean> {
    if (xPrivateClient.isSignedIn()) {
      const result: XPrivateResult = await xPrivateClient.like(post.id, liked);
      if (!result.ok) {
        promptAction.showToast({ message: this.text($r('app.string.action_like')) + ' · ' +
          (result.errorText.length > 0 ? result.errorText : 'HTTP ' + result.status), duration: 2200 });
      }
      return result.ok;
    }
    if (!authStore.isSignedIn() || authStore.getUserId().length === 0) {
      promptAction.showToast({ message: this.text($r('app.string.toast_sign_in_to_prefix')) +
        this.text($r('app.string.action_like_posts')), duration: 2000 });
      return false;
    }
    this.api.setToken(authStore.getToken());
    this.api.setUser(authStore.getUserId());
    const ok: boolean = await this.api.setLike(post.id, liked);
    if (!ok) {
      promptAction.showToast({ message: this.text($r('app.string.action_like')) +
        this.text($r('app.string.api_unreachable_suffix')), duration: 2000 });
    }
    return ok;
  }

  private async onRepost(post: Tweet, reposted: boolean): Promise<boolean> {
    if (xPrivateClient.isSignedIn()) {
      const result: XPrivateResult = await xPrivateClient.repost(post.id, reposted);
      if (!result.ok) {
        promptAction.showToast({ message: this.text($r('app.string.action_repost')) + ' · ' +
          (result.errorText.length > 0 ? result.errorText : 'HTTP ' + result.status), duration: 2200 });
      }
      return result.ok;
    }
    if (!authStore.isSignedIn() || authStore.getUserId().length === 0) {
      promptAction.showToast({ message: this.text($r('app.string.toast_sign_in_to_prefix')) +
        this.text($r('app.string.action_repost')), duration: 2000 });
      return false;
    }
    this.api.setToken(authStore.getToken());
    this.api.setUser(authStore.getUserId());
    const ok: boolean = await this.api.setRepost(post.id, reposted);
    if (!ok) {
      promptAction.showToast({ message: this.text($r('app.string.action_repost')) +
        this.text($r('app.string.api_unreachable_suffix')), duration: 2000 });
    }
    return ok;
  }

  private replyToPost(post: Tweet): void {
    if (!xPrivateClient.isSignedIn() && !authStore.isSignedIn()) {
      promptAction.showToast({ message: this.text($r('app.string.toast_sign_in_to_prefix')) +
        this.text($r('app.string.action_reply')), duration: 2000 });
      return;
    }
    const param: ReplyComposerRouteParam = {
      replyToId: post.id, replyToUser: post.author.username,
      avatarUrl: '', avatarName: '', avatarColor: this.accentColor,
      initialText: '@' + post.author.username + ' ', imageUri: '', gifUri: '',
      communityId: '', communityName: '', parentTweet: post
    };
    this.pageStack.pushPath({ name: 'ReplyComposer', param: param });
  }

  aboutToDisappear(): void {
    this.alive = false;
  }

  private async toggleBlock(): Promise<void> {
    const current: TweetAuthor | null = this.author;
    if (current === null || this.isSelfProfile || this.blockPending) {
      return;
    }
    const userId: string = this.resolvedUserId();
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
    const next: boolean = !this.blocking;
    if (next) {
      const dialog: promptAction.ShowDialogSuccessResponse = await promptAction.showDialog({
        title: this.text($r('app.string.menu_block_user')),
        message: this.text($r('app.string.block_confirm')),
        buttons: [
          { text: this.text($r('app.string.compose_cancel')), color: '#666666' },
          { text: this.text($r('app.string.menu_block_user')), color: '#E0245E' }
        ]
      });
      if (dialog.index !== 1) {
        return;
      }
    }
    this.blockPending = true;
    const result: XPrivateResult = await xPrivateClient.block(userId, next);
    this.blockPending = false;
    if (!result.ok) {
      promptAction.showToast({
        message: this.text($r('app.string.block_failed')) + ' · HTTP ' + result.status,
        duration: 2000
      });
      return;
    }
    this.blocking = next;
    void this.syncReaderModeration();
    if (next) {
      this.following = false;
      this.notificationMode = 3;
    }
    const done: Resource = next ? $r('app.string.block_done') : $r('app.string.unblock_done');
    promptAction.showToast({ message: this.text(done), duration: 1500 });
  }

  private startEditing(): void {
    const current: UserProfile | null = this.profile;
    if (current === null || !this.isSelfProfile || !xPrivateClient.isSignedIn()) {
      promptAction.showToast({ message: this.text($r('app.string.profile_follow_sign_in')), duration: 1800 });
      return;
    }
    const param: EditProfileRouteParam = { profile: current };
    this.pageStack.pushPath({ name: 'EditProfile', param: param });
  }

  private onProfileEdited(): void {
    const fresh: UserProfile | null = lastEditedProfile();
    if (fresh !== null && this.resolvedUserId() === fresh.id && xPrivateClient.viewerId() === fresh.id) {
      this.profile = fresh;
    }
  }

  @Builder
  private HeroAvatar(source: string = 'hero'): void {
    SpaceAwareAvatar({verifiedType: this.profile?.verifiedType ?? this.author?.verifiedType ?? '', avatarShape: this.profile?.avatarShape ?? this.author?.avatarShape ?? '',  userId: this.resolvedUserId(), followed: this.following, url: this.avatarUrl(), avatarSize: 84, radius: 42,
      fallbackText: this.authorName().substring(0, 1).toUpperCase(), fallbackColor: this.accentColor,
      onProfile: (): void => this.openProfileImage(false, source) })
      .id(this.profileMediaPrefix + source)
  }

  @Builder
  private IconButton(symbol: Resource, label: Resource, action: () => void, size: number = 23): void {
    Stack() {
      if (SystemMaterialUtil.isApi26OrAbove()) {
        MaterialButton({ nativeMaterialHost: true, buttonWidth: 40, buttonHeight: 40, buttonRadius: 20,
          materialLevel: 1, applyShadow: true, lightColor: this.accentColor,
          accessibilityLabel: this.text(label), onButtonClick: action }) {
          SymbolGlyph(symbol).fontSize(size).fontColor([pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent)])
        }
      } else {
        HdsButton({ barWidth: 40, barHeight: 52, lightColor: this.accentColor,
          useImmersiveMaterial: true, materialLevel: 2, forceHdsStyle: true,
          enableShadow: true, enablePressLight: true, onButtonClick: action }) {
          SymbolGlyph(symbol).fontSize(size).fontColor([pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent)])
        }
      }
    }
    .width(40).height(40).clip(false).accessibilityText(this.text(label))
  }

  @Builder
  private GrokButton(): void {
    Stack() {
      if (SystemMaterialUtil.isApi26OrAbove()) {
        MaterialButton({ nativeMaterialHost: true, buttonWidth: 40, buttonHeight: 40, buttonRadius: 20,
          materialLevel: 1, applyShadow: true, lightColor: this.accentColor,
          accessibilityLabel: this.text($r('app.string.profile_grok')),
          onButtonClick: (): void => this.openWeb('https://x.com/i/grok', this.text($r('app.string.profile_grok'))) }) {
          Image($r('app.media.grok_mark')).width(23).height(23).fillColor($r('app.color.text_primary'))
        }
      } else {
        HdsButton({ barWidth: 40, barHeight: 52, lightColor: this.accentColor,
          useImmersiveMaterial: true, materialLevel: 2, forceHdsStyle: true,
          enableShadow: true, enablePressLight: true,
          onButtonClick: (): void => this.openWeb('https://x.com/i/grok', this.text($r('app.string.profile_grok'))) }) {
          Image($r('app.media.grok_mark')).width(23).height(23).fillColor($r('app.color.text_primary'))
        }
      }
    }
    .width(40).height(40).clip(false).accessibilityText(this.text($r('app.string.profile_grok')))
  }

  @Builder
  private NameRow(size: number): void {
    Row({ space: 5 }) {
      Text(this.authorName()).fontFamily(this.appFontFamily).fontSize(size).fontWeight(FontWeight.Bold)
        .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent)).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        .flexShrink(1)
      if (this.isVerified()) {
        SymbolGlyph($r('sys.symbol.checkmark_circle_fill')).fontSize(18).fontColor([verificationBadgeColor(this.profile?.verifiedType ?? this.author?.verifiedType ?? '', this.accentColor)])
      }
    }
    .width('100%')
  }

  @Builder
  private ProfileBanner(): void {
    // Scroll the hero's 60-vp cover space away while keeping the toolbar covered.
    // Transparent activity surfaces must reveal the page wallpaper below it.
    AnchoredCover({ coverHeight: this.statusBarHeight + 120, pullOffset: this.headerPullOffset,
      scrollOffset: Math.min(60, this.headerScrollOffset) }) {
    Stack() {
      if (this.bannerUrl().length > 0) {
        ProxyMediaImage({ url: this.bannerUrl(), displayHeight: this.statusBarHeight + 120,
          blurRadius: 18 * this.headerProgress() })
      } else {
        Column().width('100%').height('100%').backgroundColor(this.accentColor)
      }
      Column().width('100%').height('100%').backgroundColor($r('app.color.profile_nav_scrim'))
        .opacity(this.headerProgress())
    }
    .width('100%').height('100%').clip(true)
    .id(this.profileMediaPrefix + 'banner')
    .hitTestBehavior(HitTestMode.None)
    }
  }

  @Builder
  private NavigationButtons(): void {
      Row({ space: 4 }) {
        this.IconButton($r('sys.symbol.arrow_left'), $r('app.string.common_back'), (): void => this.back())
        Column({ space: 1 }) {
          Row() { this.NameRow(17) }
            .width('100%')
            .onAreaChange((_oldArea: Area, area: Area): void => {
              const anchor: ProfileHeaderAnchor = this.headerAnchor(area, false);
              if (!ProfileHeaderMotion.sameAnchor(this.titleNameAnchor, anchor)) {
                this.titleNameAnchor = anchor;
              }
            })
          Text(this.exactCount(this.profilePostCount()) + ' ' + this.text($r('app.string.profile_detail_posts'))).fontFamily(this.appFontFamily)
            .fontSize(13).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
        }
        .alignItems(HorizontalAlign.Start).layoutWeight(1).opacity(this.headerProgress())
        .accessibilityLevel(this.headerProgress() >= 0.5 ? 'auto' : 'no-hide-descendants')
        if (!this.isSelfProfile) {
          Stack({ alignContent: Alignment.End }) {
            Row().width(PROFILE_COMPACT_ACTIONS_WIDTH).height(36).hitTestBehavior(HitTestMode.None)
            if (this.headerActionsProgress() < 1) {
              Row({ space: 4 }) {
                this.IconButton($r('sys.symbol.magnifyingglass'), $r('app.string.profile_search'),
                  (): void => requestSearch('from:' + this.authorHandle().substring(1)))
                this.GrokButton()
              }.opacity(1 - this.headerActionsProgress())
                .hitTestBehavior(this.headerActionsProgress() < 0.1 ? HitTestMode.Default : HitTestMode.None)
            }
          }.width(PROFILE_COMPACT_ACTIONS_WIDTH).height(36)
            .onAreaChange((_old: Area, area: Area): void => {
              const anchor: ProfileHeaderAnchor = this.headerAnchor(area, false);
              if (!ProfileHeaderMotion.sameAnchor(this.titleActionsAnchor, anchor)) { this.titleActionsAnchor = anchor; }
            })
        } else {
        this.GrokButton()
        this.IconButton($r('sys.symbol.magnifyingglass'), $r('app.string.profile_search'),
          (): void => requestSearch('from:' + this.authorHandle().substring(1)))
        }
        Stack() {
          this.IconButton($r('sys.symbol.ellipsis_circle'), $r('app.string.profile_more'),
            (): void => { this.profileMenuOpen = true; }, 25)
        }
        .width(40).height(40).accessibilityText(this.text($r('app.string.profile_more')))
        .bindMenu(this.profileMenuOpen, this.profileMenuItems(), {
          onDisappear: (): void => { this.profileMenuOpen = false; }
        })
        .bindSheet($$this.listPickerOpen, this.ListPickerSheet(), sheetMaterialOptions({
          height: SheetSize.LARGE, showClose: true, backgroundColor: pageSurfaceColor(this.themeDisplayMode, this.themeDarkSurface)
        }, this.sheetMaterialEnabled, this.sheetMaterialLevel, this.sheetWindowBreakpoint, this.sheetCompactWindow))
      }
      .width('100%').height(60).padding({ left: 8, right: 8 }).clip(false)
  }

  @Builder
  private TopNavigation(): void {
    Stack({ alignContent: Alignment.Bottom }) {
      // Each API 26 button owns its expanded Navigation material host.
      this.NavigationButtons()
    }
    .width('100%').height(this.statusBarHeight + 60).clip(false)
  }

  @Builder
  private ProfileActionsOverlay(): void {
    // Only the action buttons travel into the toolbar. Profile identity stays
    // in the List so scrolling and Refresh move it with the rest of the hero.
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.actionAnchorsReady() && this.headerActionsProgress() > 0) {
        ProfileActionButtons({ expandedWidth: this.heroActionsAnchor.width,
          progress: this.headerActionsProgress(), following: this.following, followLabel: this.followLabel(),
          followEnabled: !this.followPending && !this.blockPending && !this.blocking,
          accentColor: this.accentColor, appFontFamily: this.appFontFamily,
          onMessage: (): void => this.openMessages(), onFollow: (): void => { void this.toggleFollow(); } })
          .translate({ x: this.headerActionsX(), y: this.headerActionsY() })
      }
    }
    .width('100%').height('100%')
    .hitTestBehavior(HitTestMode.Transparent)
  }

  @Builder
  private ProfileHero(): void {
    Column() {
      // The transparent hero space reveals the same image as the toolbar.
      Stack() {}
      .width('100%').height(60).onClick((): void => this.openProfileImage(true))
      Column({ space: 0 }) {
        Row({ space: 8 }) {
          Stack() { this.HeroAvatar() }
            .width(84).height(84)
            .onAreaChange((_oldArea: Area, area: Area): void => {
              const anchor: ProfileHeaderAnchor = this.headerAnchor(area, true);
              if (!ProfileHeaderMotion.sameAnchor(this.heroAvatarAnchor, anchor)) {
                this.heroAvatarAnchor = anchor;
              }
            })
          Blank()
          if (!this.isSelfProfile) {
            Stack() {
              MaterialButton({ nativeMaterialHost: true, buttonWidth: 40, buttonHeight: 40, buttonRadius: 20,
                buttonBorderWidth: 1,
                buttonBorderColor: $r('app.color.divider'), lightColor: this.accentColor,
                accessibilityLabel: this.text($r('app.string.profile_notifications')),
                onButtonClick: (): void => { this.notificationOpen = true; } }) {
                SymbolGlyph(this.notificationMode >= 0 && this.notificationMode !== 3 ?
                  $r('sys.symbol.bell_fill') : $r('sys.symbol.bell'))
                  .fontSize(23).fontColor([pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent)])
              }
            }.width(40).height(40).clip(false)
            .bindSheet($$this.notificationOpen, this.NotificationSheet(), sheetMaterialOptions({
              height: SheetSize.LARGE, showClose: true, backgroundColor: pageSurfaceColor(this.themeDisplayMode, this.themeDarkSurface)
            }, this.sheetMaterialEnabled, this.sheetMaterialLevel, this.sheetWindowBreakpoint, this.sheetCompactWindow))
          }
          MaterialButton({ nativeMaterialHost: true, buttonWidth: 40, buttonHeight: 40, buttonRadius: 20,
            buttonBorderWidth: 1,
            buttonBorderColor: $r('app.color.divider'), lightColor: this.accentColor,
            accessibilityLabel: this.text($r('app.string.profile_share')),
            onButtonClick: (): void => {
              shareProfile(getContext(this) as common.UIAbilityContext, this.authorName(),
                this.authorHandle().substring(1), this.profileDescription());
            } }) {
            SymbolGlyph($r('sys.symbol.share')).fontSize(22).fontColor([pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent)])
          }
        }
        .width('100%').margin({ top: -14, bottom: 16 })
        Row() { this.NameRow(24) }
          .width('100%')
          .onAreaChange((_oldArea: Area, area: Area): void => {
            const anchor: ProfileHeaderAnchor = this.headerAnchor(area, true);
            if (!ProfileHeaderMotion.sameAnchor(this.heroNameAnchor, anchor)) {
              this.heroNameAnchor = anchor;
            }
          })
        Text(this.authorHandle()).fontFamily(this.appFontFamily).fontSize(15).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
          .width('100%').margin({ top: 3, bottom: 18 })
        if (this.profileDescription().length > 0) {
          Text() {
            ForEach(splitPostText(this.profileDescription()), (segment: MentionSegment) => {
              EmojiSpans(this.getUIContext(), segment.text, 15, this.systemEmojiEnabled, (): void => {
                  if (segment.mention) { this.openMention(segment.handle); }
                  else if (segment.hashtag.length > 0) { requestSearch(segment.text); }
                  else if (segment.url.length > 0) {
                    openExternalLink(getContext(this) as common.UIAbilityContext, segment.url);
                  }
                }, segment.mention || segment.hashtag.length > 0 || segment.url.length > 0 ?
                  this.accentColor : $r('app.color.text_primary'))
            })
          }.fontFamily(this.appFontFamily)
          .fontSize(15).width('100%').margin({ bottom: 4 })
          ProfileBioTranslation({ userId: this.resolvedUserId(), bio: this.profileDescription() })
        }
        if (this.profile !== null && (this.profile.location ?? '').length > 0) {
          Text(this.profile.location).fontFamily(this.appFontFamily).fontSize(14).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
            .width('100%').margin({ bottom: 8 })
        }
        if (this.profile !== null && (this.profile.website ?? '').length > 0) {
          Text(this.profile.website).fontFamily(this.appFontFamily).fontSize(14).fontColor(this.accentColor).width('100%')
            .margin({ bottom: 8 }).onClick((): void => {
              if (this.profile !== null) { openExternalLink(getContext(this) as common.UIAbilityContext,
                this.profile.website ?? ''); }
            })
        }
        Row({ space: 6 }) {
          SymbolGlyph($r('sys.symbol.calendar')).fontSize(16).fontColor([pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)])
          Text(this.text($r('app.string.profile_joined')) + ' ' + this.joinedDate()).fontFamily(this.appFontFamily)
            .fontSize(14).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)).maxLines(2).layoutWeight(1)
          SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(13).fontColor([pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)])
        }
        .width('100%').margin({ bottom: 18 }).onClick((): void => { this.openAbout(); })
        Row({ space: 18 }) {
          Row({ space: 4 }) {
            Text(this.followingCount()).fontFamily(this.appFontFamily).fontSize(15).fontWeight(FontWeight.Bold).fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent))
            Text($r('app.string.profile_following')).fontFamily(this.appFontFamily).fontSize(14).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
          }.onClick((): void => this.openUserList(USER_LIST_FOLLOWING))
          Row({ space: 4 }) {
            Text(this.followersCount()).fontFamily(this.appFontFamily).fontSize(15).fontWeight(FontWeight.Bold).fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent))
            Text($r('app.string.profile_followers')).fontFamily(this.appFontFamily).fontSize(14).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
          }.onClick((): void => this.openUserList(USER_LIST_FOLLOWERS))
        }
        .width('100%').margin({ bottom: 16 })
        if (this.isSelfProfile) {
          MaterialButton({ nativeMaterialHost: true, buttonWidth: '100%', buttonHeight: 42, buttonRadius: 22,
            buttonBorderWidth: 1,
            buttonBorderColor: $r('app.color.divider'), lightColor: this.accentColor,
            accessibilityLabel: this.text($r('app.string.profile_detail_edit')),
            onButtonClick: (): void => this.startEditing() }) {
            Text($r('app.string.profile_detail_edit')).fontFamily(this.appFontFamily).fontSize(16)
              .fontWeight(FontWeight.Bold).fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent))
          }
        } else {
          Stack() {
            ProfileActionButtons({ expandedWidth: this.heroActionsAnchor.width > 0 ? this.heroActionsAnchor.width : 312,
              progress: 0, following: this.following, followLabel: this.followLabel(),
              followEnabled: !this.followPending && !this.blockPending && !this.blocking,
              accentColor: this.accentColor, appFontFamily: this.appFontFamily,
              onMessage: (): void => this.openMessages(), onFollow: (): void => { void this.toggleFollow(); } })
          }.width('100%').height(42).opacity(this.headerActionsProgress() > 0 ? 0 : 1)
            .hitTestBehavior(this.headerActionsProgress() > 0 ? HitTestMode.None : HitTestMode.Default)
            .accessibilityLevel(this.headerActionsProgress() > 0 ? 'no-hide-descendants' : 'auto')
            .onAreaChange((_old: Area, area: Area): void => {
              const anchor: ProfileHeaderAnchor = this.headerAnchor(area, true);
              if (!ProfileHeaderMotion.sameAnchor(this.heroActionsAnchor, anchor)) { this.heroActionsAnchor = anchor; }
            })
        }
      }
      .width('100%').padding({ left: 14, right: 14, bottom: 10 }).alignItems(HorizontalAlign.Start)
      .backgroundColor(pageCanvasColor(this.themeDisplayMode, this.themeDarkSurface, this.pageBackgroundValue))
    }
    .width('100%')
  }

  private tabLabel(index: number): Resource {
    if (index === 6) { return $r('app.string.profile_detail_likes'); }
    if (index === 0) { return this.postsFilter === 'highlights' ? $r('app.string.profile_highlights_tab') :
      $r('app.string.profile_detail_posts_tab'); }
    if (index === 1) { return $r('app.string.profile_detail_replies_tab'); }
    if (index === 3) { return $r('app.string.profile_reposts_tab'); }
    if (index === 4) { return $r('app.string.profile_articles_tab'); }
    return this.mediaFilter === 'photo' ? $r('app.string.profile_photos_tab') : $r('app.string.profile_videos_tab');
  }

  private filterCheck(selected: boolean): SymbolGlyphModifier {
    return new SymbolGlyphModifier($r('sys.symbol.checkmark'))
      .fontColor([selected ? pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent) : Color.Transparent]);
  }

  @Builder
  private ActivityFilterMenu(): void {
    Menu() {
      if (this.selectedTab === 0) {
        MenuItem({ content: $r('app.string.profile_detail_posts_tab'),
          symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.doc_plaintext')),
          symbolEndIcon: this.filterCheck(this.postsFilter === 'posts') })
          .selected(this.postsFilter === 'posts').contentFont({ size: 18 })
          .onClick((): void => this.choosePostsFilter('posts'))
        MenuItem({ content: $r('app.string.profile_highlights_tab'),
          symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.star')),
          symbolEndIcon: this.filterCheck(this.postsFilter === 'highlights') })
          .selected(this.postsFilter === 'highlights').contentFont({ size: 18 })
          .onClick((): void => this.choosePostsFilter('highlights'))
      } else {
        MenuItem({ content: $r('app.string.profile_videos_tab'),
          symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.play_video')),
          symbolEndIcon: this.filterCheck(this.mediaFilter === 'video') })
          .selected(this.mediaFilter === 'video').contentFont({ size: 18 })
          .onClick((): void => this.chooseMediaFilter('video'))
        MenuItem({ content: $r('app.string.profile_photos_tab'),
          symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.picture_2')),
          symbolEndIcon: this.filterCheck(this.mediaFilter === 'photo') })
          .selected(this.mediaFilter === 'photo').contentFont({ size: 18 })
          .onClick((): void => this.chooseMediaFilter('photo'))
      }
    }
  }

  private tabSymbol(index: number): Resource {
    if (index === 6) { return $r('sys.symbol.heart'); }
    if (index === 0) { return this.postsFilter === 'highlights' ? $r('sys.symbol.star') : $r('sys.symbol.doc_plaintext'); }
    if (index === 1) { return $r('sys.symbol.message'); }
    if (index === 3) { return $r('sys.symbol.arrow_2_circlepath'); }
    if (index === 2) { return this.mediaFilter === 'photo' ? $r('sys.symbol.picture_2') : $r('sys.symbol.play_video'); }
    return $r('sys.symbol.square_and_pencil');
  }

  private tabLabelWidth(tab: number, position: number): number {
    return this.tabTextWidths[position] + (tab === 0 || tab === 2 ? 27 : 0);
  }

  private tabIconOffset(tab: number, position: number): number {
    return -(5 + this.tabLabelWidth(tab, position)) / 2 * ProfileTabMotion.fraction(position, this.tabPosition, this.activityTabs().length);
  }

  private measureTabText(position: number, area: Area): void {
    const width: number = Number(area.width);
    if (width > 0 && Math.abs(this.tabTextWidths[position] - width) > 0.5) {
      const widths: number[] = [...this.tabTextWidths];
      widths[position] = width;
      this.tabTextWidths = widths;
    }
  }

  private selectTabAt(event: ClickEvent): void {
    const position: number = ProfileTabMotion.tabAt(event.windowX - this.tabBarOriginX,
      this.tabPosition, this.tabBarWidth, this.activityTabs().length);
    this.selectTab(this.activityTabs()[position]);
  }

  @Builder
  private ProfileTab(tab: number, position: number): void {
    // Only transforms and opacity depend on drag progress; layout stays fixed throughout the gesture.
    Stack({ alignContent: Alignment.TopStart }) {
      Row() {
        Text(this.tabLabel(tab)).fontFamily(this.appFontFamily).fontSize($r('app.float.icon_tabs_label_size')).fontWeight(FontWeight.Medium)
          .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          .constraintSize({ maxWidth: Math.max(1, ProfileTabMotion.baseWidth(this.tabBarWidth, this.activityTabs().length) - 10) })
      }.width(ProfileTabMotion.baseWidth(this.tabBarWidth, this.activityTabs().length)).height(50).justifyContent(FlexAlign.Center)
        .opacity(1 - ProfileTabMotion.fraction(position, this.tabPosition, this.activityTabs().length))
      Stack() {
        SymbolGlyph(this.tabSymbol(tab)).fontSize(22).fontColor([pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent)])
      }
      .width(22).height(50)
      .translate({ x: (ProfileTabMotion.baseWidth(this.tabBarWidth, this.activityTabs().length) - 22) / 2 +
        this.tabIconOffset(tab, position) })
      .scale({ x: Math.max(0.001, ProfileTabMotion.fraction(position, this.tabPosition, this.activityTabs().length)), y: 1 })
      .opacity(ProfileTabMotion.fraction(position, this.tabPosition, this.activityTabs().length))
      .hitTestBehavior(HitTestMode.None)
      Row({ space: 5 }) {
        Text(this.tabLabel(tab)).fontFamily(this.appFontFamily).fontSize(16).fontWeight(FontWeight.Bold).fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent))
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          .constraintSize({ maxWidth: Math.max(1, ProfileTabMotion.expandedWidth(this.tabBarWidth, this.activityTabs().length) - 27 -
            (tab === 0 || tab === 2 ? 27 : 0)) })
          .onAreaChange((oldArea: Area, area: Area): void => this.measureTabText(position, area))
        if (tab === 0 || tab === 2) {
          SymbolGlyph($r('sys.symbol.chevron_down')).fontSize(12).fontColor([pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)])
            .width(22)
        }
      }
      .width(Math.max(1, ProfileTabMotion.expandedWidth(this.tabBarWidth, this.activityTabs().length) - 27)).height(50)
      .translate({ x: ProfileTabMotion.baseWidth(this.tabBarWidth, this.activityTabs().length) / 2 + 16 + this.tabIconOffset(tab, position) })
      .scale({ x: Math.max(0.001, ProfileTabMotion.fraction(position, this.tabPosition, this.activityTabs().length)), y: 1, centerX: 0 })
      .opacity(ProfileTabMotion.fraction(position, this.tabPosition, this.activityTabs().length))
      .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
    }
    .width(ProfileTabMotion.baseWidth(this.tabBarWidth, this.activityTabs().length)).height(50).clip(false)
    .translate({ x: ProfileTabMotion.center(position, this.tabPosition, this.tabBarWidth, this.activityTabs().length) -
      ProfileTabMotion.baseWidth(this.tabBarWidth, this.activityTabs().length) / 2 })
    .accessibilityText(this.text(this.tabLabel(tab))).accessibilitySelected(this.selectedTab === tab)
    .onClick((): void => this.selectTab(tab))
  }

  @Builder
  private ProfileTabs(): void {
    Stack({ alignContent: Alignment.TopStart }) {
      ForEach(this.activityTabs(), (tab: number, position: number) => {
        this.ProfileTab(tab, position)
      }, (tab: number): string => tab.toString())
      Row().width(ProfileTabMotion.indicatorWidth(this.tabBarWidth, this.activityTabs().length))
        .height($r('app.float.icon_tabs_indicator_height')).borderRadius($r('app.float.icon_tabs_indicator_radius'))
        .backgroundColor($r('app.color.text_primary')).hitTestBehavior(HitTestMode.None)
        .translate({ x: ProfileTabMotion.indicatorLeft(this.tabPosition, this.tabBarWidth, this.activityTabs().length), y: 49 })
      // The selected tab's whole slot opens its filter, including the icon, label, chevron and padding.
      if ((this.selectedTab === 0 || this.selectedTab === 2) && Math.abs(this.tabPosition - this.activityIndex) < 0.01) {
        Button({ type: ButtonType.Normal }) { Row() }
          .width(ProfileTabMotion.expandedWidth(this.tabBarWidth, this.activityTabs().length)).height(PROFILE_TAB_BAR_HEIGHT)
          .borderRadius(0).backgroundColor(Color.Transparent)
          .translate({ x: ProfileTabMotion.slotStart(this.activityIndex, this.tabPosition, this.tabBarWidth, this.activityTabs().length) })
          .accessibilityText(this.text($r('app.string.profile_content_filter')))
          .bindMenu(this.ActivityFilterMenu)
      }
    }
    .width('100%').height(PROFILE_TAB_BAR_HEIGHT).clip(true)
    .backgroundColor(pageCanvasColor(this.themeDisplayMode, this.themeDarkSurface, this.pageBackgroundValue))
    .border({ width: { bottom: 0.5 }, color: $r('app.color.divider') })
    .onAreaChange((oldArea: Area, area: Area): void => {
      this.tabBarOriginX = Number(area.globalPosition.x);
      const width: number = Number(area.width);
      if (Math.abs(this.tabBarWidth - width) > 0.5) { this.tabBarWidth = width; }
    })
    .onClick((event: ClickEvent): void => this.selectTabAt(event))
  }

  private openProfileVideo(post: Tweet, media: MediaAttachment): void {
    videoPlayerHandoff.request(media.id);
    const source = pendingMediaViewerSource.take(media.id);
    const param: VideoFeedRouteParam = {
      tweets: [post], index: 0, sourceProfileId: this.resolvedUserId(),
      sourceTweetIds: [post.id], startMediaId: media.id, startPlaying: true, source: source,
      startPositionSeconds: videoPlaybackPositionStore.positionFor(media.id),
      onLike: (target: Tweet, liked: boolean): Promise<boolean> => this.onLike(target, liked),
      onRepost: (target: Tweet, reposted: boolean): Promise<boolean> => this.onRepost(target, reposted),
      onReply: (target: Tweet): void => this.replyToPost(target)
    };
    this.pageStack.pushPath({ name: 'VideoFeedViewer', param: param }, source === undefined);
  }

  @Builder
  private VideoRow(post: Tweet): void {
    Row({ space: 12 }) {
      Stack({ alignContent: Alignment.BottomStart }) {
        if (ProfileAccountData.video(post)?.sensitive !== true) {
          ProxyMediaImage({ url: ProfileAccountData.video(post)?.previewUrl ?? '', displayHeight: 100, contain: true,
            surfaceColor: fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface) })
        } else {
          SymbolGlyph($r('sys.symbol.eye_slash')).fontSize(24).fontColor([pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))])
        }
        if (ProfileAccountData.duration(ProfileAccountData.video(post)).length > 0) {
          Text(ProfileAccountData.duration(ProfileAccountData.video(post))).fontFamily(this.appFontFamily).fontSize(13).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_on_brand')).padding(4).backgroundColor($r('app.color.profile_video_badge'))
            .borderRadius(4).margin(6)
        }
      }
      .width('46%').height(100).borderRadius(12).clip(true)
      .backgroundColor(fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
      Column({ space: 5 }) {
        Text() { EmojiSpans(this.getUIContext(), post.text.length > 0 ? post.text : this.text($r('app.string.profile_videos_tab')), 16, this.systemEmojiEnabled) }.fontFamily(this.appFontFamily)
          .fontSize(16).fontWeight(FontWeight.Bold).fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent))
          .maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
        Text(formatCount(post.metrics.viewCount) + ' ' + this.text($r('app.string.profile_video_views')) +
          ' · ' + formatPostTime(post.createdAt, this.postTimeNow)).fontFamily(this.appFontFamily)
          .fontSize(14).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)).width('100%')
      }
      .layoutWeight(1).alignItems(HorizontalAlign.Start)
    }
    .width('100%').padding({ left: 14, right: 14, top: 10, bottom: 10 }).alignItems(VerticalAlign.Top)
    .onClick((): void => {
      const media: MediaAttachment | null = ProfileAccountData.video(post);
      if (media !== null) { this.openProfileVideo(post, media); }
    })
  }

  @Builder
  private ActivityHeader(tab: number): void {
    if (tab === 0) {
      ForEach(this.suggestionGroups.filter((group: FollowSuggestionGroup): boolean => group.afterTweetId.length === 0),
        (group: FollowSuggestionGroup) => {
          Column() { FollowSuggestions({ group: group, contextualUserId: this.resolvedUserId(), showBanner: true }) }
        }, (group: FollowSuggestionGroup): string => group.id)
    }
  }

  @Builder
  private ActivityPost(tab: number, post: Tweet, index: number): void {
    // A FlowItem accepts one child: keep the post and its suggestions in the
    // same vertical container so the recommendation strip takes layout space.
    Column() {
      Column() {
        if (post.pinned && tab === 0 && this.postsFilter === 'posts') {
          Row({ space: 8 }) {
            SymbolGlyph($r('sys.symbol.pin')).fontSize(13).fontColor([pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)])
            Text($r('app.string.profile_pinned')).fontFamily(this.appFontFamily).fontSize(13).fontWeight(FontWeight.Bold)
              .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
          }.width('100%').padding({ left: 58, top: 10 })
        }
        if (tab === 2 && this.mediaFilter === 'video') {
          this.VideoRow(post)
        } else {
          TweetCard({ tweet: post, naturalVideoSize: true, videoFeedEnabled: true,
            onVideoOpen: (t: Tweet, media: MediaAttachment): void => this.openProfileVideo(t, media),
            onLikeChanged: (t: Tweet, liked: boolean): Promise<boolean> => this.onLike(t, liked),
            onRepostChanged: (t: Tweet, reposted: boolean): Promise<boolean> => this.onRepost(t, reposted),
            onReply: (t: Tweet): void => this.replyToPost(t),
            onOpen: (t: Tweet): void => this.openPostFromProfile(t),
            onAuthorTapped: (t: Tweet): void => {
              const param: UserDetailRouteParam = { author: t.author, posts: [] };
              this.pageStack.pushPath({ name: 'UserDetail', param: param });
            },
            onMentionTapped: (handle: string): void => this.openMention(handle) })
        }
      }.width('100%')
      if (tab === 0) {
        ForEach(this.suggestionGroups.filter((group: FollowSuggestionGroup): boolean => group.afterTweetId === post.id),
          (group: FollowSuggestionGroup) => {
            Column() { FollowSuggestions({ group: group, contextualUserId: this.resolvedUserId(), showBanner: true }) }
          }, (group: FollowSuggestionGroup): string => group.id)
        if (this.privateProfileAvailable && !this.isSelfProfile && this.suggestionGroups.length === 0 &&
          index === Math.min(2, this.tabPosts(tab).length - 1)) {
          Column() { FollowSuggestions({ autoLoad: true, contextualUserId: this.resolvedUserId(), showBanner: true }) }
        }
      }
    }
    .width('100%')
  }

  @Builder
  private ActivityFooter(tab: number): void {
    Column() {
      Column({ space: 12 }) {
        if (this.currentTabLoading(tab)) {
          LoadingProgress().width(26).height(26).color(this.accentColor)
        } else if (this.currentTabStatus(tab).length > 0) {
          Text(this.currentTabStatus(tab)).fontFamily(this.appFontFamily).fontSize(14).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)).textAlign(TextAlign.Center)
          Button($r('app.string.profile_retry')).backgroundColor(Color.Transparent).fontColor(this.accentColor)
            .onClick((): void => this.retryTab(tab))
        } else if (this.tabMoreCursor(tab).length > 0) {
          Button($r('app.string.timeline_load_more')).backgroundColor(Color.Transparent).fontColor(this.accentColor)
            .onClick((): void => { this.loadProfilePage(this.activitySource(tab), false); })
        } else if (this.tabPosts(tab).length === 0) {
          Text($r('app.string.profile_activity_empty')).fontFamily(this.appFontFamily).fontSize(15).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
        }
      }
      .width('100%').padding({ top: 24, bottom: 100, left: 20, right: 20 }).constraintSize({ minHeight: 180 })
    }
  }

  @Builder
  private ActivityList(tab: number): void {
    AdaptivePostFeed({ scroller: this.activityScrollers[tab], relatedScrollers: [this.scroller],
      itemKeys: this.tabPosts(tab).map((post: Tweet): string => post.id), feedId: 'profile-post-feed-' + tab.toString(),
      useList: this.useListFeed(), lazyItems: true,
      endOffset: this.navigationIndicatorHeight, forwardMode: NestedScrollMode.PARENT_FIRST,
      backwardMode: NestedScrollMode.SELF_FIRST,
      header: (): void => this.ActivityHeader(tab),
      item: (index: number): void => this.ActivityPost(tab, this.tabPosts(tab)[index], index),
      footer: (): void => this.ActivityFooter(tab), onLoadMore: (): void => {
      if (this.selectedTab === tab && this.tabMoreCursor(tab).length > 0 &&
          !this.currentTabLoading(tab) && this.currentTabStatus(tab).length === 0) {
          this.loadProfilePage(this.activitySource(tab), false);
        }
      } })
  }

  @Builder
  private ActivityPager(): void {
    Swiper(this.activitySwiper) {
      ForEach(this.activityTabs(), (tab: number) => { this.ActivityList(tab) },
        (tab: number): string => tab.toString())
    }
    .width('100%').height(Math.max(1, this.viewportHeight - PROFILE_TAB_BAR_HEIGHT))
    .index(this.activityIndex).loop(false).indicator(false).cachedCount(1)
    .duration(PROFILE_TAB_TRANSITION_DURATION).curve(Curve.EaseOut).clip(true)
    .disableSwipe(this.refreshing)
    .onChange((index: number): void => this.activityChanged(index))
    .onContentDidScroll((selectedIndex: number, index: number, position: number, length: number): void => {
      this.onActivityScroll(index, position);
    })
    .onAnimationStart((index: number, target: number, event: SwiperAnimationEvent): void => {
      this.ensureActivityLoaded(this.activityTabs()[target]);
    })
    .onAnimationEnd((index: number, event: SwiperAnimationEvent): void => { this.tabPosition = index; })
  }

  @Builder
  private NotificationOption(title: Resource, subtitle: Resource, index: number): void {
    Row({ space: 20 }) {
      Column({ space: 5 }) {
        Text(title).fontFamily(this.appFontFamily).fontSize(17).fontWeight(FontWeight.Medium).fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent)).width('100%')
        Text(subtitle).fontFamily(this.appFontFamily).fontSize(14).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)).width('100%')
      }.layoutWeight(1)
      SymbolGlyph(this.notificationMode === index ? $r('sys.symbol.checkmark_circle_fill') : $r('sys.symbol.circle'))
        .fontSize(24).fontColor([this.notificationMode === index ? this.accentColor : pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)])
    }
    .width('100%').padding({ top: 18, bottom: 18 }).enabled(!this.actionPending)
    .accessibilitySelected(this.notificationMode === index)
    .onClick((): void => { this.setNotificationMode(index); })
  }

  @Builder
  private NotificationSheet(): void {
    Scroll() {
      Column() {
        Text($r('app.string.profile_notifications_title')).fontFamily(this.appFontFamily).fontSize(26).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary')).width('100%')
        Text(this.authorHandle()).fontFamily(this.appFontFamily).fontSize(16).fontColor($r('app.color.text_secondary')).width('100%')
          .margin({ top: 8, bottom: 20 })
        this.NotificationOption($r('app.string.profile_notify_posts'), $r('app.string.profile_notify_posts_desc'), 0)
        this.NotificationOption($r('app.string.profile_notify_replies'), $r('app.string.profile_notify_replies_desc'), 1)
        this.NotificationOption($r('app.string.profile_notify_live'), $r('app.string.profile_notify_live_desc'), 2)
        this.NotificationOption($r('app.string.profile_notify_off'), $r('app.string.profile_notify_off_desc'), 3)
        if (this.actionPending) { LoadingProgress().width(24).height(24).color(this.accentColor) }
      }
      .width('100%').padding({ left: 20, right: 20, top: 24, bottom: this.navigationIndicatorHeight + 20 })
    }.width('100%').height('100%').scrollBar(BarState.Off)
  }

  @Builder
  private ListPickerSheet(): void {
    Scroll() {
      Column({ space: 12 }) {
        Text($r('app.string.profile_list_manage')).fontFamily(this.appFontFamily).fontSize(22).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary')).width('100%')
        Text(this.authorHandle()).fontFamily(this.appFontFamily).fontSize(15).fontColor($r('app.color.text_secondary')).width('100%')
        if (this.listLoading) { LoadingProgress().width(28).height(28).color(this.accentColor) }
        if (this.listStatus.length > 0) {
          Text(this.listStatus).fontFamily(this.appFontFamily).fontColor($r('app.color.text_secondary'))
          Button($r('app.string.profile_retry')).onClick((): void => { this.openListPicker(); })
        }
        ForEach(this.ownedLists, (row: ListRow) => {
          Row({ space: 12 }) {
            Text(row.name).fontFamily(this.appFontFamily).fontSize(17).fontColor($r('app.color.text_primary')).layoutWeight(1)
            SymbolGlyph(this.memberListIds.indexOf(row.id) >= 0 ? $r('sys.symbol.checkmark_circle_fill') : $r('sys.symbol.circle'))
              .fontSize(24).fontColor([this.memberListIds.indexOf(row.id) >= 0 ? this.accentColor : $r('app.color.text_secondary')])
          }
          .width('100%').padding({ top: 14, bottom: 14 }).enabled(!this.actionPending && !this.listLoading)
          .onClick((): void => { this.toggleList(row); })
        }, (row: ListRow): string => row.id)
        if (!this.listLoading && this.ownedLists.length === 0 && this.listStatus.length === 0) {
          Text($r('app.string.lists_empty')).fontFamily(this.appFontFamily).fontColor($r('app.color.text_secondary'))
        }
        if (this.listCursor.length > 0) {
          Button($r('app.string.timeline_load_more')).enabled(!this.listLoading)
            .onClick((): void => { this.listLoading = true;
              this.loadOwnedLists(false).then((): void => { this.listLoading = false; }); })
        }
      }.width('100%').padding(20)
    }.width('100%').height('100%')
  }

  build(): void {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        appPageBackground()
      Stack({ alignContent: Alignment.Top }) {
        this.ProfileBanner()
        Column() {
          this.TopNavigation()
          Refresh({ refreshing: $$this.refreshing }) {
            List({ scroller: this.scroller }) {
              ListItem() { this.ProfileHero() }
              ListItemGroup({ header: this.ProfileTabs() }) {
                ListItem() { this.ActivityPager() }
              }
              .backgroundColor(pageCanvasColor(this.themeDisplayMode, this.themeDarkSurface, this.pageBackgroundValue))
            }
            .onScrollStop((): void => scrollStopped(this.scroller))
            .onScrollStart((): void => scrollStarted(this.scroller))
            .onScrollFrameBegin((offset: number, state: ScrollState): OnScrollFrameBeginHandlerResult =>
              scrollFrame(this.scroller, offset, state))
            .onTouchIntercept((event: TouchEvent): HitTestMode => this.onProfileTouchIntercept(event))
            .width('100%').height('100%').scrollBar(BarState.Off).sticky(StickyStyle.Header)
            .onDidScroll((): void => {
              this.updateHeaderScroll();
            })
          }
          .width('100%').layoutWeight(1).onRefreshing((): void => this.refreshCurrentProfilePage())
          .onOffsetChange((offset: number): void => { this.headerPullOffset = offset; })
          .onAreaChange((oldArea: Area, area: Area): void => {
            const height: number = Number(area.height);
            if (Math.abs(this.viewportHeight - height) > 0.5) { this.viewportHeight = height; }
          })
        }.width('100%').height('100%')
        if (this.actionAnchorsReady() && this.headerActionsProgress() > 0) {
          this.ProfileActionsOverlay()
        }
        FloatingComposeButton({ bottomInset: this.navigationIndicatorHeight,
          mode: this.homeFloatingAction === HOME_FLOATING_TOP ? 'top' : 'reply',
          hidden: this.homeFloatingAction === HOME_FLOATING_HIDDEN,
          accessibilityLabel: this.text(this.homeFloatingAction === HOME_FLOATING_TOP ?
            $r('app.string.action_scroll_top') : $r('app.string.action_reply')),
          onTop: (): void => { this.scroller.scrollEdge(Edge.Top); this.headerScrollOffset = 0; },
          onReply: (): void => this.replyToAuthor() })

      }.width('100%').height('100%')
        .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
        .onAreaChange((_oldArea: Area, area: Area): void => {
          this.headerOriginX = Number(area.globalPosition.x);
          this.headerOriginY = Number(area.globalPosition.y);
        })
    
      }.width('100%').height('100%')
    }
    .scale({ x: this.pageMotion.scale, y: this.pageMotion.scale })
    .opacity(this.pageMotion.opacity)
    .onReady((context: NavDestinationContext): void => { this.pageMotion.attach(context); })
    .systemTransition(pageSystemTransition(this.pageTransitionMode))
    .hideTitleBar(true).hideBackButton(true)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
    .onBackPressed((): boolean => {
      this.back();
      return true;
    })
    .backgroundColor(pageCanvasColor(this.themeDisplayMode, this.themeDarkSurface, this.pageBackgroundValue));
  }


}
