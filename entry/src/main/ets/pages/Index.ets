import { STORAGE_KEY_SYSTEM_EMOJI_ENABLED } from '../services/AppearanceStore';
import { XXAuthPopupHost } from '../components/XXAuthPopupHost';
import { userAvatarRadius, userVerifiedType, userAvatarShape, verificationBadgeColor } from '../utils/UserIdentity';
import { DEFAULT_SHEET_MATERIAL_LEVEL, STORAGE_KEY_SHEET_MATERIAL_ENABLED, STORAGE_KEY_SHEET_MATERIAL_LEVEL } from '../services/SheetMaterialSettingsStore';
import { sheetContentBackground, sheetMaterialOptions } from '../utils/SheetMaterial';
import { HOME_FLOATING_COMPOSE, HOME_FLOATING_HIDDEN, STORAGE_KEY_HOME_FLOATING_ACTION, STORAGE_KEY_PHOTO_FULLSCREEN,
  STORAGE_KEY_REFRESH_ON_FOREGROUND, STORAGE_KEY_REFRESH_ON_HOME_TAB,
  STORAGE_KEY_HOME_DOUBLE_TAP_LATEST, STORAGE_KEY_HOME_PULL_REFRESH_LATEST } from '../services/InteractionSettingsStore';
// Harmony X main page. ArkUI renders the browsing surfaces and opens the
// shared full-screen composer for new posts and replies.
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import hilog from '@ohos.hilog';
import common from '@ohos.app.ability.common';
import webview from '@ohos.web.webview';
import { deviceInfo } from '@kit.BasicServicesKit';
import { preferences } from '@kit.ArkData';
import { curves, FrameCallback, LengthMetrics, SymbolGlyphModifier, uiMaterial } from '@kit.ArkUI';
import {
  BottomBuilderShowType,
  DividerShowType,
  DynamicHideParams,
  HdsAnimationMode,
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  HdsNavigation,
  HdsNavigationTitleBarOptions,
  HdsNavigationTitleMode,
  HdsTabs,
  HdsTabsController,
  HdsTabsFloatingStyle,
  HdsSideBar,
  HideMode,
  hdsEffect,
  hdsMaterial,
  ScrollEffectType,
  TitleBarStyleOptions
} from '@kit.UIDesignKit';
import { FloatingComposeButton } from '../components/FloatingComposeButton';
import { OnboardingGuide } from '../components/OnboardingGuide';
import { MaterialButton } from '../components/MaterialButton';
import { NewPostsPill } from '../components/NewPostsPill';
import { TimelinePageDataSource, TimelinePageItem } from '../utils/TimelinePageDataSource';
import { PromotionPostCard } from '../components/PromotionPostCard';
import { XXAuthPromotionPlan, XXAuthPromotionPost } from '../services/XXAuthPromotionPost';
import { XXAuthPromotionInjector, XXAuthPromotionSlot } from '../utils/XXAuthPromotionInjector';
import { XXAUTH_PROMOTION_POST, xxAuthPopupStore } from '../services/XXAuthPopupStore';
import { HomeSpacePill } from '../components/HomeSpacePill';
import { RootBottomTabItem } from '../components/RootBottomTabItem';
import { SpacePreviewSheet } from '../components/SpacePreviewSheet';
import { SPACE_SURFACE_REVISION, SPACE_PREVIEW_REQUEST, spaceSurfaceStore } from '../services/SpaceSurfaceStore';
import { STORAGE_KEY_HOME_SPACE_CAPSULE_ENABLED, STORAGE_KEY_HOME_SPACE_CAPSULE_HIDDEN_FOR_SESSION,
  spacePreferencesStore } from '../services/SpacePreferencesStore';
import { spaceUserParam } from '../utils/SpacePresentation';
import { PostMedia } from '../components/PostMedia';
import { ProxyAvatar } from '../components/ProxyAvatar';
import { AnimatedIconTabs, IconTabItem } from '../components/AnimatedIconTabs';
import { RootRefreshIndicator } from '../components/RootRefreshIndicator';
import { ProfileTabMotion } from '../utils/ProfileTabMotion';
import { RootTitleBarLayout } from '../utils/RootTitleBarLayout';
import { NotificationPresentation } from '../utils/NotificationPresentation';
import { NotificationSummary } from '../components/NotificationSummary';
import { TweetCard as NotificationTweetCard } from '../components/TweetCard';
import { NotificationFilters } from '../utils/NotificationFilters';
import { NotificationRateLimit } from '../utils/NotificationRateLimit';
import { ConversationInboxRow } from '../components/ConversationInboxRow';
import { ChatPinPad } from '../components/ChatPinPad';
import { ConversationTweetCard as TweetCard } from '../components/ConversationTweetCard';
import { EmojiSpans } from '../components/EmojiSpans';
import { UserRowCard } from '../components/UserRowCard';
import { FollowSuggestions } from '../components/FollowSuggestions';
import { FollowDiscoveryData, FollowSuggestionGroup } from '../services/FollowDiscoveryData';
import { FollowDiscoveryBuilder } from './FollowDiscovery';
import type { FollowDiscoveryRouteParam } from './FollowDiscovery';
import { formatCount } from '../models/Tweet';
import type {
  Tweet,
  TweetAuthor,
  MediaAttachment,
  AppNotification,
  DirectMessage,
  DmInboxPage,
  UserListPage,
  UserProfile,
  UserRow
} from '../models/Tweet';
import { MockData } from '../services/MockData';
import { WebProxyCredential, proxyStore } from '../services/ProxyStore';
import { CachedFeed, FeedCache } from '../services/FeedCache';
import { ConnectivityMonitor } from '../services/ConnectivityMonitor';
import { XApiClient } from '../services/XApiClient';
import { XWebClient } from '../services/XWebClient';
import type { TweetPage } from '../services/XApiClient';
import { authStore } from '../services/AuthStore';
import { videoPlaybackPositionStore } from '../services/VideoPlaybackPositionStore';
import { videoPlayerHandoff } from '../services/VideoPlayerHandoff';
import { XPrivateClient, XPrivateResult, xPrivateClient } from '../services/XPrivateClient';
import { XTimelineParser } from '../services/XTimelineParser';
import { XNotificationParser } from '../services/XNotificationParser';
import type { XNotificationPage } from '../services/XNotificationParser';
import {
  XExploreHero,
  XExploreFrame,
  XExploreFrameTile,
  XExploreParser,
  XExploreSection,
  XExploreTimelineCard,
  XExploreTrend
} from '../services/XExploreParser';
import { XUserParser } from '../services/XUserParser';
import { XDmParser } from '../services/XDmParser';
import { PostDetailBuilder } from './PostDetail';
import { PostArticleBuilder } from './PostArticle';
import type { PostArticleRouteParam } from '../utils/PostArticleRoute';
import { ImageEditBuilder } from './ImageEdit';
import { ReadAloudBuilder } from './ReadAloud';
import { GrokBuilder } from './Grok';
import { PostInteractionsBuilder } from './PostInteractions';
import { EditHistoryBuilder } from './EditHistory';
import type { PostDetailRouteParam } from './PostDetail';
import { ReplyComposerBuilder } from '../components/ReplyComposer';
import type { ReplyComposerRouteParam } from '../components/ReplyComposer';
import { externalShareStore, ExternalSharePayload, STORAGE_KEY_EXTERNAL_SHARE } from '../services/ExternalShareStore';
import type { DmComposeRouteParam } from './DmCompose';
import { effectiveAppLocale, isAppRtl, STORAGE_KEY_APP_LOCALE } from '../utils/AppLocale';
import { GifSearchBuilder } from './GifSearch';
import { XSideDrawer } from '../components/XSideDrawer';
import { SettingsBuilder, SettingsSectionBuilder } from './Settings';
import { SidebarHandleSettingsBuilder } from './SidebarHandleSettings';
import { SidebarExpandHandle } from '../components/SidebarExpandHandle';
import { STORAGE_KEY_SIDEBAR_HANDLE_STYLE, STORAGE_KEY_SIDEBAR_HANDLE_PATH,
  SIDEBAR_HANDLE_DEFAULT } from '../services/SidebarHandleStore';
import { STORAGE_KEY_DESKTOP_RAIL_SWIPE } from '../services/LayoutSettingsStore';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY, appFontStore } from '../services/AppFontStore';
import type { SettingsRouteParam } from './Settings';
import { ProxySettingsBuilder } from './ProxySettings';
import { HelpCenterBuilder } from './HelpCenter';
import { AboutBuilder } from './About';
import { LogoUniverseBuilder } from './LogoUniverse';
import { UserDetailBuilder } from './UserDetail';
import { ProfileWebBuilder } from './ProfileWeb';
import { AccountPrivacyBuilder } from './AccountPrivacy';
import { NativeAccountBuilder } from './NativeAccount';
import { accountPrivacyService } from '../services/AccountPrivacyService';
import { BookmarksBuilder } from './Bookmarks';
import { USER_LIST_FOLLOWERS, USER_LIST_FOLLOWING, UserListBuilder } from './UserList';
import type { UserListRouteParam } from './UserList';
import { ListsBuilder } from './Lists';
import { SpacesBuilder, SpaceRoomBuilder } from './Spaces';
import { SpaceMembersBuilder } from './SpaceMembers';
import { SpaceInfoBuilder } from './SpaceInfo';
import { SpaceDraftBuilder } from './SpaceDraftPage';
import { SpaceListeningBar } from '../components/SpaceListeningBar';
import { SPACE_PLAYBACK_REVISION, spacePlayback } from '../services/SpacePlayback';
import { SpaceParticipant, SpaceRoom, SpaceRouteParam } from '../models/Space';
import type { ListTimelineRouteParam } from './Lists';
import { TimelineManagerBuilder } from './TimelineManager';
import { PauseTopicsSheet, FollowingOrderSheet } from '../components/HomeTimelineSheets';
import { homeTimelineStore, STORAGE_KEY_HOME_TIMELINE_REVISION, TimelineTopic } from '../services/HomeTimelineStore';
import { ListTimelineBuilder } from './ListTimeline';
import { ListMembersBuilder } from './ListMembers';
import { ListEditorBuilder } from './ListEditor';
import { CommunitiesBuilder } from './Communities';
import { CommunitySearchBuilder } from './CommunitySearch';
import type { CommunityTimelineRouteParam } from './Communities';
import { CommunityTimelineBuilder } from './CommunityTimeline';
import { CommunityRulesBuilder } from './CommunityRules';
import { PhotoViewerBuilder } from './PhotoViewer';
import { PhotoViewerOverlay } from '../components/PhotoViewerOverlay';
import { NotificationPostsBuilder } from './NotificationPosts';
import { postModerationStore, STORAGE_KEY_POST_MODERATION_REVISION } from '../services/PostModerationStore';
import { homeSeenTweetStore } from '../services/HomeSeenTweetStore';
import type { NotificationPostsRouteParam } from './NotificationPosts';
import type { PhotoViewerRouteParam } from './PhotoViewer';
import { VideoFeedViewerBuilder } from './VideoFeedViewer';
import { ChatVideoViewerBuilder } from './ChatVideoViewer';
import type { VideoFeedRouteParam } from './VideoFeedViewer';
import { PhotoRequest } from '../utils/PhotoViewerRequest';
import { MediaViewerSource, pendingMediaViewerSource } from '../utils/MediaViewerMotion';
import { STORAGE_KEY_VIDEO_REQUEST, VideoViewerRequest } from '../utils/VideoViewerRequest';
import { BrowsingHistoryBuilder } from './BrowsingHistory';
import { DiagnosticsBuilder } from './Diagnostics';
import { DownloadManagerBuilder } from './DownloadManagerPage';
import { DataStorageBuilder } from './DataStoragePage';
import { AccountsBuilder } from './Accounts';
import { DmConversationBuilder } from './DmConversation';
import { DmComposeBuilder } from './DmCompose';
import { DmSettingsBuilder, DmSettingsRouteParam } from './DmSettings';
import { DmInfoBuilder } from './DmInfo';
import { DmGroupBuilder } from './DmGroup';
import { ChatBackgroundBuilder } from './ChatBackground';
import { DmRequestsBuilder } from './DmRequests';
import { xChatActions } from '../services/XChatActions';
import type { DmConversationRouteParam } from './DmConversation';
import { xChatService } from '../services/XChatService';
import { xPrivateStore } from '../services/XPrivateStore';
import { DmWebBuilder } from './DmWeb';
import { XAccount, accountStore } from '../services/AccountStore';
import { xWebCookieBridge } from '../services/XWebCookieBridge';
import { searchHistoryStore } from '../services/SearchHistoryStore';
import { ComposerDraft, composerDraftStore } from '../services/ComposerDraftStore';
import {
  CONTINUATION_KIND_COMPOSER,
  CONTINUATION_KIND_POST,
  CONTINUATION_RESTORE_REQUEST_KEY,
  ContinuationState,
  continuationStore
} from '../services/ContinuationState';
import {
  DARK_SURFACE_BLACK,
  DISPLAY_MODE_DARK,
  DISPLAY_MODE_LIGHT,
  DISPLAY_MODE_SYSTEM,
  STORAGE_KEY_AUTO_HIDE_FAB,
  STORAGE_KEY_AUTO_HIDE_TAB_BAR,
  STORAGE_KEY_AUTO_HIDE_TITLE_BAR,
  STORAGE_KEY_HOME_HEADER_COLLAPSE,
  STORAGE_KEY_TITLE_BAR_LOGO,
  STORAGE_KEY_COMPACT_SWITCH_STYLE,
  COMPACT_SWITCH_TABS,
  COMPACT_SWITCH_BUTTONS,
  STORAGE_KEY_COMPOSE_BUTTON_ENABLED,
  STORAGE_KEY_DARK_SURFACE,
  STORAGE_KEY_TITLE_BAR_GLASS_MATERIAL_LEVEL,
  DEFAULT_TITLE_BAR_GLASS_MATERIAL_LEVEL
} from '../services/AppearanceStore';
import {
  BOTTOM_BAR_EXPLORE_PAGE,
  BOTTOM_BAR_HOME_PAGE,
  BOTTOM_BAR_ME_PAGE,
  BOTTOM_BAR_MESSAGES_PAGE,
  BOTTOM_BAR_NOTIFICATIONS_PAGE,
  BOTTOM_BAR_PAGE_COUNT,
  DEFAULT_BOTTOM_BAR_PAGES_MASK,
  STORAGE_KEY_BOTTOM_BAR_PAGES
} from '../services/BottomBarSettingsStore';
import type { UserDetailRouteParam } from './UserDetail';
import { DesktopNavRail } from '../components/DesktopNavRail';
import { DesktopSettingsHost } from '../components/DesktopSettingsHost';
import { CreatorStudioBuilder } from './CreatorStudio';
import { DesktopLayout } from '../utils/DesktopLayout';
import { layoutSettingsStore, STORAGE_KEY_DESKTOP_LAYOUT, STORAGE_KEY_DESKTOP_ASIDE,
  STORAGE_KEY_DESKTOP_RAIL_AUTO_HIDE, STORAGE_KEY_DESKTOP_RAIL_MATERIAL_LEVEL,
  DEFAULT_DESKTOP_RAIL_MATERIAL_LEVEL } from '../services/LayoutSettingsStore';
import { RootContentNavigation } from '../utils/RootContentNavigation';
import { NavigationGuard } from '../utils/NavigationGuard';
import { SideBarMaterialLayer } from '../components/SideBarMaterialLayer';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';
import {
  cardSurfaceColor,
  fieldSurfaceColor,
  pageSurfaceColor,
  secondaryButtonSurfaceColor,
  titleBarScrimColor
} from '../utils/ThemeColors';
import {
  classifyXLink,
  STORAGE_KEY_EXTERNAL_LINK,
  X_LINK_POST,
  X_LINK_PROFILE,
  X_LINK_SEARCH,
  X_LINK_COMMUNITY,
  X_LINK_LIST,
  X_LINK_SPACE,
  X_LINK_ARTICLE,
  X_LINK_MESSAGES,
  XLinkTarget
} from '../utils/XLinkRouter';
import { MAIN_NAVIGATION_ID } from '../utils/NavigationIdentity';
import { SystemMaterialUtil } from '../utils/SystemMaterial';
import {
  customTitleBarGlassEnabled,
  destinationTitleBarStyle,
  retainedTitleBarBuilder,
  rootTitleBarStyle,
  titleBarGlassMaterial,
  TitleBarGlassMaterialCache,
  TitleBarControlMaterialCache
} from '../utils/DestinationTitleBar';
import {
  STORAGE_KEY_TIMELINE_COLUMNS,
  TIMELINE_COLUMNS_ONE,
  TIMELINE_COLUMNS_THREE,
  TIMELINE_COLUMNS_TWO,
  timelineSettingsStore
} from '../services/TimelineSettingsStore';
import {
  HDS_TAB_MATERIAL_EXQUISITE,
  HDS_TAB_MATERIAL_GENTLE,
  HDS_TAB_MATERIAL_SMOOTH,
  STORAGE_KEY_HOME_TAB_MATERIAL_LEVEL,
  STORAGE_KEY_CLASSIC_BOTTOM_BAR,
  STORAGE_KEY_ROOT_TAB_LABELS_VISIBLE,
  DEFAULT_HOME_TAB_MATERIAL_LEVEL
} from '../services/HdsTabsSettingsStore';
import {
  ContentFilterSettings,
  contentFilterStore,
  STORAGE_KEY_FILTER_HIDE_ADS,
  STORAGE_KEY_FILTER_HIDE_REPLIES,
  STORAGE_KEY_FILTER_HIDE_REPOSTS,
  STORAGE_KEY_FILTER_KEYWORDS,
  STORAGE_KEY_FILTER_MUTED_USERS,
  STORAGE_KEY_FILTER_ONLY_MEDIA,
  STORAGE_KEY_FILTER_REVISION
} from '../services/ContentFilterStore';
import { notificationDeliveryService } from '../services/NotificationDeliveryService';
import { meowPushService } from '../services/MeowPushService';
import {
  STORAGE_KEY_NOTIFICATION_DND_SILENT,
  STORAGE_KEY_SYSTEM_NOTIFICATIONS
} from '../services/NotificationSettingsStore';
import { midAutumnGreetingStore } from '../services/MidAutumnGreetingStore';

// One row of a search-result timeline: either a real post or an injected
// recommendation. Keeping both in one list is what lets a promotion sit at any
// position without a second scroll container.
class SearchTimelineRow {
  key: string = '';
  tweet: Tweet | null = null;
  promotion: XXAuthPromotionPost | null = null;
}

// A notification timeline re-read is skipped for this long after a successful
// fetch, so switching tabs does not hammer the endpoint.
const NOTIFICATIONS_FRESH_MS = 30000;
const ONBOARDING_STORE_NAME: string = 'harmonyx_onboarding';
const ONBOARDING_COMPLETED_KEY: string = 'completed_v1';
const NOTIFICATIONS_BACKGROUND_POLL_MS = 120000;
// Tab order is Home, Explore, Notifications, Messages, Me.
const HOME_TAB_INDEX: number = BOTTOM_BAR_HOME_PAGE;
const EXPLORE_TAB_INDEX: number = BOTTOM_BAR_EXPLORE_PAGE;
const NOTIFICATIONS_TAB_INDEX: number = BOTTOM_BAR_NOTIFICATIONS_PAGE;
const MESSAGES_TAB_INDEX: number = BOTTOM_BAR_MESSAGES_PAGE;
const ME_TAB_INDEX: number = BOTTOM_BAR_ME_PAGE;
const SEARCH_FIELD_TRANSITION_ID = 'SEARCH_ONE_SHOT_DEMO_TRANSITION_ID';
// A DM inbox refresh is skipped for this long after a successful fetch.
const MESSAGES_FRESH_MS = 30000;
// 底部导航栏要等内容区离开顶部这么远才收起，避免刚滑动就抖动。
const TAB_BAR_HIDE_DEPTH = 36;
// How far the reader has to travel down a feed before the compose button
// becomes "back to top".
const FAB_SWITCH_DEPTH = 620;
// How long a link's post may take to resolve before the web sheet takes over.
const INCOMING_LINK_RESOLVE_BUDGET_MS = 6000;
const MAX_DUPLICATE_TIMELINE_PAGES: number = 3;
// Keep the secondary-tabs gesture intentional while preserving ordinary
// vertical scrolling and taps inside the feed.
const SECONDARY_TAB_SWIPE_DISTANCE = 72;
// A short native page-slide gives a tab tap or boundary swipe visible motion
// without delaying interaction with the destination list.
const ROOT_TAB_SWITCH_DURATION_MS = 260;
// Root pages carry different amounts of title-bar content. Morph the bar
// together with the page switch; the short spring keeps the bar from feeling
// like it arrives after the new page has already settled.
const TITLE_BAR_MORPH_DURATION_MS = 180;
const HOME_TAB_DOUBLE_TAP_INTERVAL_MS: number = 400;
const EXPLORE_CATEGORY_IDS: string[] = ['explore', 'trending', 'news', 'sports', 'entertainment'];
const SEARCH_PRODUCT_IDS: string[] = ['Top', 'Latest', 'People', 'Media', 'Lists'];
// The title bar is drawn as one material pane spanning the system status bar,
// the identity row and the page-label row. HDS only lets its top slot overflow
// and draws that slot above its own page-label slot, so the labels are rendered
// in the top slot instead. These keep them exactly where that slot used to put
// them: the top slot measures 63vp in MINI mode, and the label row keeps the
// 54vp / 108vp the HDS page-label slot allocated per page.
const TITLE_BAR_TITLE_SLOT_HEIGHT_VP = 63;
const TITLE_BAR_LABELS_HOME_HEIGHT_VP = 54;
const HOME_HEADER_COLLAPSE_DEPTH_VP = 36;
const HOME_HEADER_COLLAPSE_TRANSLATE_VP = 58;
// Where each label row starts, measured against the top slot's own top edge.
// The two rows lay their content out differently, so the offsets that keep
// them on the baseline they had inside HDS's page-label slot differ too. Both
// were read off the device against that slot's previous geometry.
// The pane is pushed this far above the physical top of the screen and made
// correspondingly taller, so no seam can show between the surface and the
// status bar. The screen clips the overscan, so being generous costs nothing.
const TITLE_BAR_SURFACE_OVERSCAN_VP = 60;

class HomeFeedSnapshot {
  timeline: Tweet[] = [];
  suggestions: FollowSuggestionGroup[] = [];
  pendingPosts: Tweet[] = [];
  pendingAuthors: TweetAuthor[] = [];
  nextToken: string = '';
  topToken: string = '';
  cursorHistory: string[] = [];
  duplicatePageCount: number = 0;
  source: string = '';
  samplePage: number = 0;
  hasMore: boolean = false;
  statusLine: string = '';
  liveBadge: string = '';
  scrollOffset: number = 0;
  loaded: boolean = false;
}

class FeedTopFrameCallback extends FrameCallback {
  private scroller: Scroller;

  constructor(scroller: Scroller) {
    super();
    this.scroller = scroller;
  }

  // Keep the captured controller available even when the callback is invoked
  // without its class receiver.
  onIdle: (timeLeftInNano: number) => void = (_timeLeftInNano: number): void => {
    this.scroller.scrollEdge(Edge.Top);
  };
}

class HomeViewportFrameCallback extends FrameCallback {
  private action: () => void;
  constructor(action: () => void) { super(); this.action = action; }
  onIdle: (timeLeftInNano: number) => void = (_timeLeftInNano: number): void => { this.action(); };
}

class SearchTabSnapshot {
  posts: Tweet[] = [];
  users: UserRow[] = [];
  status: string = '';
}

class ContentPageSections {
  sections: WaterFlowSections = new WaterFlowSections();
  itemsCount: number = -1;
  columns: number = -1;
}

@Observed
class ExploreCategoryPage {
  cards: XExploreTimelineCard[] = [];
  posts: Tweet[] = [];
  trends: string[] = [];
  trendItems: XExploreTrend[] = [];
  hero: XExploreHero | null = null;
  frameCount: number = 0;
  nextToken: string = '';
  status: string = '';
  loading: boolean = false;
  loaded: boolean = false;
  requestId: number = 0;
}

// Notification rows carry the thumbnail of the post they refer to, the way X's
// own list does. It is its own component so a dead media URL collapses the
// column instead of leaving an empty square behind.
@Component
struct NotificationThumb {
  @Prop url: string = '';
  @Prop isVideo: boolean = false;
  @State failed: boolean = false;

  build() {
    if (this.url.length > 0 && !this.failed) {
      Stack() {
        Image(this.url)
          .width(64)
          .height(64)
          .borderRadius(12)
          .objectFit(ImageFit.Cover)
          .clip(true)
          .onError((): void => {
            this.failed = true;
          })
        if (this.isVideo) {
          SymbolGlyph($r('sys.symbol.play_fill'))
            .fontSize(18)
            .fontColor([$r('app.color.text_on_brand')])
        }
      }
      .width(64)
      .height(64)
    }
  }
}

@Entry
@Component
struct Index {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp(STORAGE_KEY_SYSTEM_EMOJI_ENABLED) private systemEmojiEnabled: boolean = false;
  @StorageProp('harmonyx.breakpoint') private sheetWindowBreakpoint: string = 'sm';
  @StorageProp(STORAGE_KEY_DESKTOP_LAYOUT) @Watch('onDesktopLayoutChanged') desktopLayoutEnabled: boolean = false;
  @StorageProp(STORAGE_KEY_DESKTOP_ASIDE) desktopAsideEnabled: boolean = true;
  @StorageProp(STORAGE_KEY_DESKTOP_RAIL_AUTO_HIDE) @Watch('closeDesktopRail') desktopRailAutoHide: boolean = true;
  @StorageProp(STORAGE_KEY_DESKTOP_RAIL_MATERIAL_LEVEL)
  desktopRailMaterialLevel: number = DEFAULT_DESKTOP_RAIL_MATERIAL_LEVEL;
  @State private desktopRailOpen: boolean = false;
  @StorageProp(STORAGE_KEY_DESKTOP_RAIL_SWIPE) private desktopRailSwipe: boolean = true;
  @StorageProp(STORAGE_KEY_SIDEBAR_HANDLE_STYLE) private desktopHandleStyle: string = SIDEBAR_HANDLE_DEFAULT;
  @StorageProp(STORAGE_KEY_SIDEBAR_HANDLE_PATH) private desktopHandlePath: string = '';
  @State private desktopRoute: string = '';
  @State private desktopModalOpen: boolean = false;
  @State private desktopConversationId: string = '';
  @State private desktopInlineDraft: string = '';
  @State private desktopAdvancedSearchOpen: boolean = false;
  @State private desktopAdvancedValues: string[] = ['', '', '', '', '', '', '', '', ''];
  @StorageProp(STORAGE_KEY_SHEET_MATERIAL_ENABLED) private sheetMaterialEnabled: boolean = false;
  @StorageProp(STORAGE_KEY_SHEET_MATERIAL_LEVEL) private sheetMaterialLevel: number = DEFAULT_SHEET_MATERIAL_LEVEL;
  @State currentTab: number = 0;
  // `currentTab` drives the tab content. The shared title-bar content follows
  // it in one short animation; only the HDS hide configuration waits for the
  // page swipe to settle, because changing that mid-swipe rebuilds the material
  // bar. Keeping the two moments separate gives the bar motion without that
  // rebuild.
  @State private chromeTab: number = 0;
  @State private chromeTabSettled: number = 0;
  // Global vp geometry of the single title-bar surface. Its top is the top of
  // HDS's material slot (which sits below the system status bar), and its
  // bottom is read from the page-label row, so the pane always matches the
  // title bar's real content height instead of a guessed constant.
  @State private titleBarSurfaceTop: number = 44;
  @State private titleBarSurfaceBottom: number = 0;
  @State private exploreTitleContentBottom: number = 0;
  @State private exploreTitleIdentityBottom: number = 0;
  @State private exploreContentTop: number = 0;
  @State private exploreNativeTitleHeight: number = TITLE_BAR_TITLE_SLOT_HEIGHT_VP;
  private titleBarMaterialCache: TitleBarGlassMaterialCache = new TitleBarGlassMaterialCache();
  private chatSearchMaterialCache: TitleBarControlMaterialCache = new TitleBarControlMaterialCache();
  private chatFilterMaterialCache: TitleBarControlMaterialCache = new TitleBarControlMaterialCache();
  private exploreSearchMaterialCache: TitleBarControlMaterialCache = new TitleBarControlMaterialCache();
  private rootTitleBarBuilder: CustomBuilder = (): void => { this.RootTitleBarContent(); };
  private rootTitleBarBottomBuilder: CustomBuilder = (): void => { this.RootTitleBarBottomContent(); };
  private sideBarPanelBuilder: CustomBuilder = (): void => { this.SideBarPanelBuilder(); };
  private contentPanelBuilder: CustomBuilder = (): void => { this.ContentPanelBuilder(); };
  // While reading down the Home feed, the feed switch moves beside the avatar
  // and the centered brand mark fades out as one title-bar transition.
  @State private homeHeaderCollapsed: boolean = false;
  // 0 = For you (recommended), 1 = Following.
  @State homeFeedMode: number = 0;
  @State private homeTabPosition: number = 0;
  @State private exploreTabPosition: number = 0;
  @State private searchTabPosition: number = 1;
  @State private notificationTabPosition: number = 0;
  @State private meTabPosition: number = 0;
  @State private exploreCategoryPages: ExploreCategoryPage[] = [new ExploreCategoryPage(), new ExploreCategoryPage(),
    new ExploreCategoryPage(), new ExploreCategoryPage(), new ExploreCategoryPage()];
  @State private activeHomeTopicId: string = '';
  @State private pinnedHomeTopics: TimelineTopic[] = [];
  @State private showPauseTopics: boolean = false;
  @State private showFollowingOrder: boolean = false;
  @StorageLink(STORAGE_KEY_HOME_TIMELINE_REVISION) @Watch('onHomeTimelinePreferencesChanged')
  private homeTimelineRevision: number = 0;
  private manageTimelinesAfterDismiss: boolean = false;
  private topicPauseTimer: number = -1;
  @StorageLink('harmonyx.default_home_feed') @Watch('onDefaultHomeFeedChanged')
  defaultHomeFeedMode: number = 0;
  @State @Watch('onTimelineChanged') timeline: Tweet[] = [];
  @State trends: string[] = [];
  @State private exploreSections: XExploreSection[] = [];
  @State private exploreHomePosts: Tweet[] = [];
  @State private exploreHomeTrends: string[] = [];
  @State private exploreTrendItems: XExploreTrend[] = [];
  @State private exploreHomeCards: XExploreTimelineCard[] = [];
  @State private exploreHero: XExploreHero | null = null;
  // The promoted Explore hero always begins without sound. Its own glass
  // control owns this state rather than inheriting the timeline preference.
  @State private exploreHeroMuted: boolean = true;
  @State private exploreFrameCount: number = 0;
  @State private exploreHomeCategory: string = 'explore';
  @State private exploreHomeLoading: boolean = false;
  @State private exploreHomeRefreshing: boolean = false;
  private exploreRefreshInFlight: boolean = false;
  @State private exploreHomeStatus: string = '';
  @State @Watch('onExploreResultsChanged') exploreResults: Tweet[] = [];
  // Search product: Latest | Top | Media. The private search operation
  // declares timeline_type as SearchProductInput, so these map straight onto it.
  @State searchProduct: string = 'Latest';
  @State exploreUsers: UserRow[] = [];
  @State private searchHistory: string[] = [];
  // Set by hashtag taps anywhere in the app; this root consumes it, switches to
  // the explore tab and runs the search.
  @StorageLink('harmonyx.search_request') @Watch('onSearchRequested') searchRequest: string = '';
  // Post links can open here instead of the system browser (设置里可切换).
  @StorageLink('harmonyx.link_preview_url') @Watch('onLinkPreviewRequested') linkPreviewUrl: string = '';
  // Another app handed us an x.com link through the system's 打开方式 chooser.
  @StorageLink(STORAGE_KEY_EXTERNAL_LINK) @Watch('onExternalLinkRequested')
  externalLinkRequest: string = '';
  @StorageProp(STORAGE_KEY_APP_LOCALE) private appLocale: string = effectiveAppLocale();
  @StorageLink(STORAGE_KEY_EXTERNAL_SHARE) @Watch('onExternalShareRequested') externalShareRequest: string = '';
  private externalShareBusy: boolean = false;
  @StorageLink(CONTINUATION_RESTORE_REQUEST_KEY) @Watch('onContinuationRestoreRequested')
  continuationRestoreRequest: number = 0;
  // Post media asks the root to push the full-screen viewer.
  @StorageLink('harmonyx.photo_request') @Watch('onPhotoRequested') photoRequest: string = '';
  @StorageLink(STORAGE_KEY_VIDEO_REQUEST) @Watch('onVideoRequested') videoRequest: string = '';
  // The in-app web sheet follows the app's own light/dark setting.
  @StorageLink('harmonyx.display_mode') displayMode: string = DISPLAY_MODE_SYSTEM;
  @StorageLink(STORAGE_KEY_DARK_SURFACE) darkSurface: string = DARK_SURFACE_BLACK;
  @StorageLink('harmonyx.notification_alerts') @Watch('onNotificationAlertsChanged')
  notificationAlertsEnabled: boolean = true;
  @StorageLink(STORAGE_KEY_SYSTEM_NOTIFICATIONS) systemNotificationsEnabled: boolean = true;
  @StorageLink(STORAGE_KEY_NOTIFICATION_DND_SILENT) notificationDndSilent: boolean = true;
  @StorageLink('harmonyx.foreground_tick') @Watch('onForegroundTick')
  foregroundTick: number = 0;
  @StorageLink('harmonyx.open_notifications_request') @Watch('onNotificationLaunchRequested')
  notificationLaunchRequest: number = 0;
  @StorageLink('harmonyx.open_messages_request') @Watch('onMessageLaunchRequested')
  messageLaunchRequest: number = 0;
  @State private showLinkPreview: boolean = false;
  @State private showOnboardingGuide: boolean = true;
  @State private onboardingLoginOnly: boolean = false;
  @State private onboardingAddAccount: boolean = false;
  @State private showLoginSheet: boolean = false;
  @State private loginAccounts: XAccount[] = [];
  @State private loginActiveAccountId: string = '';
  // The compose button morphs into jump-to-top once the reader has scrolled
  // away from the newest post, and morphs back on any downward scroll.
  @State private fabMode: string = 'compose';
  @StorageProp(STORAGE_KEY_HOME_FLOATING_ACTION) homeFloatingAction: string = HOME_FLOATING_COMPOSE;
  @StorageProp(STORAGE_KEY_REFRESH_ON_FOREGROUND) refreshOnForeground: boolean = false;
  @StorageProp(STORAGE_KEY_REFRESH_ON_HOME_TAB) refreshOnHomeTab: boolean = false;
  @StorageProp(STORAGE_KEY_HOME_DOUBLE_TAP_LATEST) homeDoubleTapLatest: boolean = true;
  @StorageProp(STORAGE_KEY_HOME_PULL_REFRESH_LATEST) homePullRefreshLatest: boolean = true;
  @StorageProp(STORAGE_KEY_POST_MODERATION_REVISION) @Watch('onPostModerationChanged') private moderationRevision: number = 0;
  @State private fabHidden: boolean = false;
  @State private pendingNewPosts: Tweet[] = [];
  @StorageProp(SPACE_SURFACE_REVISION) private spaceSurfaceRevision: number = 0;
  @StorageLink(SPACE_PREVIEW_REQUEST) @Watch('onSpacePreviewRequested') private spacePreviewRequest: string = '';
  @State private showSpacePreview: boolean = false;
  @State private previewSpaceId: string = '';
  @State private previewFromHomeCapsule: boolean = false;
  @StorageProp(STORAGE_KEY_HOME_SPACE_CAPSULE_ENABLED) private homeSpaceCapsuleEnabled: boolean = true;
  @StorageProp(STORAGE_KEY_HOME_SPACE_CAPSULE_HIDDEN_FOR_SESSION) private homeSpaceCapsuleHiddenForSession: boolean = false;
  private previewPerson: SpaceParticipant | null = null;
  private spaceRecommendationTimer: number = -1;
  private spaceRecommendationsAlive: boolean = false;
  private spaceRecommendationsLoading: boolean = false;
  @StorageProp('harmonyx.app_foreground') private appForeground: boolean = true;
  // Authors of the posts waiting behind the new-posts capsule, so the capsule
  // can say who posted instead of only how much arrived.
  @State private pendingAuthors: TweetAuthor[] = [];
  // False while the posts on screen are the ones replayed from the device
  // cache, which is what the offline status line reports.
  @State private feedFromCache: boolean = false;
  @State private networkOnline: boolean = true;
  // When the posts on screen were fetched, which is what the offline status
  // line reports.
  private lastFeedAt: number = 0;
  private scrollDepth: number = 0;
  private linkPreviewController: webview.WebviewController = new webview.WebviewController();
  @State @Watch('onNotificationsChanged') notifications: AppNotification[] = [];
  @State @Watch('onNotificationsChanged') private mentionNotifications: AppNotification[] = [];
  @State @Watch('onNotificationFilterChanged') private notificationFilter: number = 0;
  @State messages: DirectMessage[] = [];
  @State private chatFilter: string = 'all';
  @State private chatSearch: string = '';
  @State private markingChats: boolean = false;
  @StorageLink('harmonyx.chat_revision') @Watch('onChatChanged') private chatRevision: number = 0;
  @State profile: UserProfile | null = null;
  @State @Watch('onOwnPostsChanged') ownPosts: Tweet[] = [];
  @State @Watch('onLikedPostsChanged') likedPosts: Tweet[] = [];
  @State private meTimelineTab: number = 0;
  @State ownPostsStatus: string = '';
  @State ownPostsLoading: boolean = false;
  @State ownPostsLoadingMore: boolean = false;
  @State ownPostsHasMore: boolean = false;
  @State likedPostsStatus: string = '';
  @State likedPostsLoading: boolean = false;
  @State likedPostsLoadingMore: boolean = false;
  @State likedPostsHasMore: boolean = false;
  @State private meRefreshing: boolean = false;
  private meRefreshInFlight: boolean = false;
  @State exploreStatus: string = '';
  @State notificationsStatus: string = '';
  @State notificationsRefreshing: boolean = false;
  @State notificationsLoading: boolean = false;
  @State loadingMoreNotifications: boolean = false;
  @State hasMoreNotifications: boolean = false;
  @State private mentionsLoading: boolean = false;
  @State private mentionsStatus: string = '';
  @State private mentionsHasMore: boolean = false;
  // Rows X flagged as newer than the last seen notification. The tab shows a
  // dot while this is non-zero and the list is not on screen.
  @State unreadNotifications: number = 0;
  @State unreadMessages: number = 0;
  @State messagesStatus: string = '';
  @State private messagesLoading: boolean = false;
  @State private messagesRefreshing: boolean = false;
  @State replyToId: string = '';
  @State replyToUser: string = '';
  @State statusLine: string = '';
  @State searchText: string = '';
  @State private searchFilterOpen: boolean = false;
  // The sheet edits these while the results keep using the applied snapshot
  // below, so dismissing the sheet without 应用 cannot change the query the
  // current page is paging through.
  @State private searchFilterFrom: string = 'Anyone';
  // Publish-date floor picked in the calendar dialog, '' means 全部时间.
  @State private searchFilterSince: string = '';
  @State private searchFilterLanguage: string = 'Any';
  @State private searchFilterActivity: string = 'Any';
  @State private searchFilterExcludeReplies: boolean = false;
  @State refreshing: boolean = false;
  @State private homeRefreshPullOffset: number = 0;
  @State private exploreRefreshPullOffset: number = 0;
  @State private notificationsRefreshPullOffset: number = 0;
  @State private messagesRefreshPullOffset: number = 0;
  @State private meRefreshPullOffset: number = 0;
  private homeRefreshInFlight: boolean = false;
  private homeRefreshFailed: boolean = false;
  @State loading: boolean = true;
  @State loadingMore: boolean = false;
  @State hasMoreTimeline: boolean = true;
  @State loadingMoreExplore: boolean = false;
  // First-page loading is separate from pagination so the empty state never
  // flashes before SearchTimeline returns.
  @State private searchLoading: boolean = false;
  @State hasMoreExplore: boolean = false;
  @State handleText: string = '';
  @State liveBadge: string = '';
  // Cached at load time: the render path must not touch preferences.
  @State private hasCookieSession: boolean = false;
  @StorageLink('harmonyx.posts_changed') @Watch('onPostsChanged') postsChanged: number = 0;
  // Bumped by the account store whenever an account is added, removed or made
  // active, which is what reloads every account-scoped surface below.
  @StorageLink('harmonyx.accounts_changed') @Watch('onAccountsChanged') accountsChanged: number = 0;
  @State showSideDrawer: boolean = false;
  // 中秋祝福弹窗，窗口见 MidAutumnGreetingStore（2026-09-25 起三天）。
  @State showMidAutumnGreeting: boolean = false;
  @StorageProp('harmonyx.window_width') @Watch('onHomeViewportChanged') windowWidth: number =
    AppStorage.get<number>('harmonyx.window_width') ?? 0;
  @StorageProp('harmonyx.window_height') windowHeight: number =
    AppStorage.get<number>('harmonyx.window_height') ?? 0;
  @StorageProp('harmonyx.compact_window') @Watch('onCompactWindowChanged') private compactWindow: boolean = false;
  @StorageLink('harmonyx.breakpoint') @Watch('onBreakpointChange') breakpoint: string = ResponsiveLayout.BREAKPOINT_SM;
  @StorageLink('harmonyx.content_destination_open') @Watch('onContentDestinationChange')
  contentDestinationOpen: boolean = false;
  @StorageLink(STORAGE_KEY_TIMELINE_COLUMNS) @Watch('onTimelineLayoutChanged') timelineColumnsMode: number = 0;
  @State private desktopContentWidth: number = 0;
  @State mainNavigationMode: NavigationMode = NavigationMode.Stack;
  private pendingFullPageDestination: boolean = false;
  @StorageLink('harmonyx.accent_color') accentColor: string = '#007DFF';
  @StorageLink('harmonyx.font_scale') fontScale: number = 1;
  // 显示设置里的两个自动隐藏开关，见 Settings.ets 的 AutoHideSection。
  @StorageLink(STORAGE_KEY_AUTO_HIDE_TITLE_BAR) autoHideTitleBar: boolean = false;
  @StorageLink(STORAGE_KEY_HOME_HEADER_COLLAPSE) @Watch('onHomeHeaderCollapseEnabledChanged')
  homeHeaderCollapseEnabled: boolean = false;
  @StorageLink(STORAGE_KEY_TITLE_BAR_LOGO) @Watch('onTitleBarLogoChanged')
  titleBarLogoEnabled: boolean = true;
  @StorageProp(STORAGE_KEY_COMPACT_SWITCH_STYLE) compactSwitchStyle: string = COMPACT_SWITCH_TABS;
  @StorageLink('harmonyx.title_bar_style_mode') titleBarStyleMode: number = 0;
  @StorageLink(STORAGE_KEY_TITLE_BAR_GLASS_MATERIAL_LEVEL)
  titleBarGlassMaterialLevel: number = DEFAULT_TITLE_BAR_GLASS_MATERIAL_LEVEL;
  @StorageLink(STORAGE_KEY_AUTO_HIDE_TAB_BAR) @Watch('onAutoHideTabBarChanged')
  autoHideTabBar: boolean = false;
  @StorageLink(STORAGE_KEY_BOTTOM_BAR_PAGES) @Watch('onBottomBarPagesChanged')
  bottomBarPagesMask: number = DEFAULT_BOTTOM_BAR_PAGES_MASK;
  @StorageLink(STORAGE_KEY_CLASSIC_BOTTOM_BAR) @Watch('onClassicBottomBarChanged')
  classicBottomBar: boolean = false;
  @StorageLink(STORAGE_KEY_ROOT_TAB_LABELS_VISIBLE) rootTabLabelsVisible: boolean = true;
  @StorageLink(STORAGE_KEY_AUTO_HIDE_FAB) @Watch('onAutoHideFabChanged')
  autoHideFab: boolean = true;
  @StorageLink(STORAGE_KEY_COMPOSE_BUTTON_ENABLED) composeButtonEnabled: boolean = true;
  @StorageProp(STORAGE_KEY_PHOTO_FULLSCREEN) private photoFullscreen: boolean = true;
  @State private tabBarHidden: boolean = false;
  @StorageProp(SPACE_PLAYBACK_REVISION) spacePlaybackRevision: number = 0;
  @StorageLink(STORAGE_KEY_HOME_TAB_MATERIAL_LEVEL)
  homeTabMaterialLevel: number = DEFAULT_HOME_TAB_MATERIAL_LEVEL;
  @StorageLink(STORAGE_KEY_FILTER_ONLY_MEDIA) filterOnlyMedia: boolean = false;
  @StorageLink(STORAGE_KEY_FILTER_HIDE_REPOSTS) filterHideReposts: boolean = false;
  @StorageLink(STORAGE_KEY_FILTER_HIDE_REPLIES) filterHideReplies: boolean = false;
  @StorageLink(STORAGE_KEY_FILTER_HIDE_ADS) filterHideAds: boolean = true;
  @StorageLink(STORAGE_KEY_FILTER_KEYWORDS) filterKeywords: string = '';
  @StorageLink(STORAGE_KEY_FILTER_MUTED_USERS) filterMutedUsers: string = '';
  @StorageLink(STORAGE_KEY_FILTER_REVISION) @Watch('onContentFilterChanged')
  filterRevision: number = 0;
  @StorageProp('harmonyx.status_bar_height') statusBarHeight: number =
    AppStorage.get<number>('harmonyx.status_bar_height') ?? 0;
  @StorageProp('harmonyx.navigation_indicator_height') navigationIndicatorHeight: number =
    AppStorage.get<number>('harmonyx.navigation_indicator_height') ?? 0;
  @StorageProp(XXAUTH_PROMOTION_POST) @Watch('onPromotionPostChanged') promotionPostJson: string = '';
  private api: XApiClient = new XApiClient();
  // Private-interface client (cookie session). Independent from `api`, which
  // speaks the official OAuth API; whichever one has credentials supplies the
  // feed.
  private xPrivate: XPrivateClient = new XPrivateClient();
  private webClient: XWebClient = new XWebClient();
  private connectivity: ConnectivityMonitor = new ConnectivityMonitor();
  private tabsController: TabsController = new TabsController();
  private hdsTabsController: HdsTabsController = new HdsTabsController();
  private lastHomeTabClickAt: number = 0;
  @Provide('pageStack') navPathStack: NavPathStack = new NavPathStack();
  private photoOverlayStack: NavPathStack = new NavPathStack();
  @State private photoOverlayOpen: boolean = false;
  private handledContinuationRestoreRequest: number = 0;
  private homePager: SwiperController = new SwiperController();
  private explorePager: SwiperController = new SwiperController();
  private searchPager: SwiperController = new SwiperController();
  private notificationPager: SwiperController = new SwiperController();
  private mePager: SwiperController = new SwiperController();
  private contentPageScrollers: Map<string, Scroller> = new Map<string, Scroller>();
  private homePageSources: Map<string, TimelinePageDataSource> = new Map<string, TimelinePageDataSource>();
  private contentPageLayouts: Map<string, ContentPageSections> = new Map<string, ContentPageSections>();
  private searchTabSnapshots: Map<string, SearchTabSnapshot> = new Map<string, SearchTabSnapshot>();
  private getHomeScroller(): Scroller { return this.contentPageScroller('home', this.homeTabItems()[this.homeTabIndex()]?.key ?? 'for-you'); }
  private homeFirstVisibleItem: number = 0;
  private homeVisiblePostId: string = '';
  private homeVisiblePostOffset: number = 0;
  private homeViewportChanging: boolean = false;
  private homeViewportReady: boolean = false;
  private homeViewportHasAnchor: boolean = false;
  private homeViewportMount: string = '';
  private homeViewportRevision: number = 0;
  private homeViewportRestoreTimer: number = -1;
  private getExploreScroller(): Scroller { return this.contentPageScroller('explore', this.exploreHomeCategory); }
  private searchHistoryScroller: Scroller = new Scroller();
  private getSearchSurfaceScroller(): Scroller { return this.contentPageScroller('search', this.searchProduct); }
  private getNotificationsScroller(): Scroller { return this.contentPageScroller('notifications', this.notificationFilter.toString()); }
  private messagesScroller: Scroller = new Scroller();
  private profileScroller: Scroller = new Scroller();
  private timelineNextToken: string = '';
  private timelineTopToken: string = '';
  @State private homeSuggestionGroups: FollowSuggestionGroup[] = [];
  private timelineCursorHistory: string[] = [];
  private duplicateTimelinePageCount: number = 0;
  private timelineSource: string = '';
  private sampleTimelinePage: number = 0;
  private exploreNextToken: string = '';
  private exploreHomeNextToken: string = '';
  private exploreHomeRequestId: number = 0;
  private activeExploreQuery: string = '';
  private activeSearchQuerySource: string = 'typed_query';
  // Search settings (过滤器弹窗) that the current result page was fetched with.
  // Only 应用 writes them, which is what keeps paging and the visible results
  // on the same query.
  private appliedFilterFrom: string = 'Anyone';
  private appliedFilterSince: string = '';
  private appliedFilterLanguage: string = 'Any';
  private appliedFilterActivity: string = 'Any';
  private appliedFilterExcludeReplies: boolean = false;
  // Notification paging: the private timeline owns a Bottom cursor, the OAuth
  // mentions fallback and the offline sample surface are single-page.
  private notificationsCursor: string = '';
  private notificationsTopCursor: string = '';
  private notificationsSource: string = '';
  private notificationsFetchedAt: number = 0;
  private mentionsCursor: string = '';
  private mentionsFetchedAt: number = 0;
  private mentionsRequestId: number = 0;
  private notificationPollTimer: number = -1;
  private midAutumnGreetingTimer: number = -1;
  private chromeTabTimer: number = -1;
  private messagesFetchedAt: number = 0;
  private afterChatMenuDismiss: (() => void) | null = null;
  @State private showChatUnlock: boolean = false;
  @State private chatUnlocking: boolean = false;
  @State private chatUnlockError: string = '';
  private chatUnlockAttempts: number = -1;
  private chatUnlockAccount: string = '';
  private chatUnlockSucceeded: boolean = false;
  private afterChatUnlock: (() => void) | null = null;
  // Unread rows counted on the last page, and whether that batch has already
  // been reported to X.
  private notificationsUnread: number = 0;
  private messagesUnread: number = 0;
  private notificationsSeenMarked: boolean = false;
  // Last private-search outcome, surfaced in the status line so a failure is
  // diagnosable without reading logs.
  private lastSearchStatus: number = 0;
  private lastSearchError: string = '';
  private searchRequestId: number = 0;
  private ownPostsCursor: string = '';
  private ownPostsLoadedFor: string = '';
  private likedPostsCursor: string = '';
  private likedPostsLoadedFor: string = '';
  // Preserve the exact preference-derived query while paging the For You feed.
  private activeRecommendationQuery: string = '';
  private recommendationSignalsLoaded: boolean = false;
  private forYouSnapshot: HomeFeedSnapshot = new HomeFeedSnapshot();
  private followingSnapshot: HomeFeedSnapshot = new HomeFeedSnapshot();
  private topicSnapshots: Map<string, HomeFeedSnapshot> = new Map<string, HomeFeedSnapshot>();
  private homeTimelineRequestId: number = 0;
  @State private homeWaterFlowSections: WaterFlowSections = new WaterFlowSections();
  private homeWaterFlowSectionsReady: boolean = false;
  @State private exploreWaterFlowSections: WaterFlowSections = new WaterFlowSections();
  private exploreWaterFlowSectionsReady: boolean = false;
  @State private notificationsWaterFlowSections: WaterFlowSections = new WaterFlowSections();
  private notificationsWaterFlowSectionsReady: boolean = false;
  @State private ownPostsWaterFlowSections: WaterFlowSections = new WaterFlowSections();
  private ownPostsWaterFlowSectionsReady: boolean = false;

  aboutToAppear(): void {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    appFontStore.restore(context, this.getUIContext());
    xPrivateClient.load(context);
    postModerationStore.load(context);
    homeSeenTweetStore.load(context);
    accountPrivacyService.syncSensitiveMedia(context, true).catch((): void => { });
    this.loadOnboardingState(context);
    xWebCookieBridge.syncActive(context);
    this.syncAllWaterFlowSections();
    this.onBreakpointChange();
    this.bindHdsTabScrollers();
    this.watchConnectivity();
    this.homeFeedMode = this.defaultHomeFeedMode;
    this.statusLine = this.text($r('app.string.status_loading'));
    this.loadSearchHistory();
    contentFilterStore.load(context);
    homeTimelineStore.load(context);
    this.loadTimeline();
    this.spaceRecommendationsAlive = true;
    this.refreshHomeSpaces();
    this.startNotificationPolling();
    meowPushService.checkin(context, accountStore.activeId(context)).catch((): void => {});
    this.scheduleMidAutumnGreeting();
    // A link launch sets the request before this page exists, so the watcher
    // alone would miss the cold start.
    this.onExternalLinkRequested();
    this.onNotificationLaunchRequested();
    this.onMessageLaunchRequested();
    this.onExternalShareRequested();
    this.restoreContinuationIfRequested();
    this.navPathStack.setInterception({ didShow: (): void => this.syncDesktopRoute() });
    this.photoOverlayStack.setInterception({
      didShow: (): void => { this.photoOverlayOpen = this.photoOverlayStack.size() > 0; }
    });
    this.syncDesktopRoute();
  }

  aboutToDisappear(): void {
    homeSeenTweetStore.flush(getContext(this) as common.UIAbilityContext);
    this.spaceRecommendationsAlive = false;
    if (this.spaceRecommendationTimer >= 0) { clearTimeout(this.spaceRecommendationTimer); this.spaceRecommendationTimer = -1; }
    if (this.homeViewportRestoreTimer >= 0) {
      clearTimeout(this.homeViewportRestoreTimer);
      this.homeViewportRestoreTimer = -1;
    }
    if (this.topicPauseTimer >= 0) {
      clearTimeout(this.topicPauseTimer);
      this.topicPauseTimer = -1;
    }
    this.connectivity.stop();
    this.stopNotificationPolling();
    if (this.midAutumnGreetingTimer >= 0) {
      clearTimeout(this.midAutumnGreetingTimer);
      this.midAutumnGreetingTimer = -1;
    }
    if (this.chromeTabTimer >= 0) {
      clearTimeout(this.chromeTabTimer);
      this.chromeTabTimer = -1;
    }
    if (!this.usesFloatingTabBar()) {
      return;
    }
    this.hdsTabsController.unbindScroller(this.getHomeScroller());
    this.hdsTabsController.unbindScroller(this.getExploreScroller());
    this.hdsTabsController.unbindScroller(this.getNotificationsScroller());
    this.hdsTabsController.unbindScroller(this.messagesScroller);
    this.hdsTabsController.unbindScroller(this.profileScroller);
  }

  private text(resource: Resource): string {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    return context.resourceManager.getStringSync(resource);
  }

  private loadOnboardingState(context: common.UIAbilityContext): void {
    try {
      const options: preferences.Options = { name: ONBOARDING_STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      this.showOnboardingGuide = !(store.getSync(ONBOARDING_COMPLETED_KEY, false) as boolean);
    } catch (error) {
      this.showOnboardingGuide = true;
      console.error('Unable to read onboarding state: ' + JSON.stringify(error));
    }
  }

  private completeOnboarding(): void {
    this.showOnboardingGuide = false;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    try {
      const options: preferences.Options = { name: ONBOARDING_STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      store.putSync(ONBOARDING_COMPLETED_KEY, true);
      store.flushSync();
    } catch (error) {
      console.error('Unable to save onboarding state: ' + JSON.stringify(error));
    }
  }

  private onboardingSheetHeight(): number {
    if (this.windowHeight <= 0) {
      return 720;
    }
    return Math.max(0, Math.min(760, this.windowHeight - 24));
  }

  @Builder
  private OnboardingSheetContent(): void {
    OnboardingGuide({
      visible: this.showOnboardingGuide,
      loginOnly: this.onboardingLoginOnly,
      addAccount: this.onboardingAddAccount,
      onCompleted: (): void => {
        if (this.onboardingLoginOnly) {
          this.showOnboardingGuide = false;
        } else {
          this.completeOnboarding();
        }
      }
    })
      .width('100%')
      .height('100%')
  }

  private supportsImmersiveMaterial(): boolean {
    return SystemMaterialUtil.isApi26OrAbove();
  }

  private supportsHdsNavigation(): boolean {
    return deviceInfo.sdkApiVersion >= 20;
  }

  private supportsHdsFloatingMaterial(): boolean {
    return deviceInfo.sdkApiVersion >= 23;
  }

  private usesFloatingTabBar(): boolean {
    return this.supportsHdsFloatingMaterial() && !this.classicBottomBar;
  }

  private onClassicBottomBarChanged(): void {
    this.tabBarHidden = false;
    this.lastHomeTabClickAt = 0;
    if (this.supportsHdsFloatingMaterial()) {
      try {
        this.hdsTabsController.applyShowAnimation(HdsAnimationMode.SCROLL_ANIMATION);
      } catch (error) {
        // The style switch still restores the bar on systems without this animation.
      }
    }
  }

  // 中秋祝福弹窗：2026-09-25 起连续三天内，每天第一次进首页弹一次；
  // 2026-09-28 零点后窗口关闭（MidAutumnGreetingStore），不再出现。
  private scheduleMidAutumnGreeting(): void {
    if (this.midAutumnGreetingTimer >= 0) {
      return;
    }
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    if (!midAutumnGreetingStore.shouldShow(context, Date.now())) {
      return;
    }
    // 等首页首帧落地后再弹，避免和启动动画抢同一帧。
    this.midAutumnGreetingTimer = setTimeout((): void => {
      this.midAutumnGreetingTimer = -1;
      midAutumnGreetingStore.markShown(context, Date.now());
      this.showMidAutumnGreeting = true;
    }, 600);
  }

  private dismissMidAutumnGreeting(): void {
    this.showMidAutumnGreeting = false;
  }

  // API 26+ 走沉浸光感：容器保持透明，材质交给系统；低版本回退成普通卡片背景，
  // 否则透明容器背后就是桌面，内容会看不清。
  private midAutumnGreetingSheetOptions(): SheetOptions {
    const options: SheetOptions = {
      height: 452,
      preferType: SheetType.BOTTOM,
      showClose: false,
      dragBar: true,
      maskColor: '#66000000',
      radius: { topLeft: 28, topRight: 28 },
      onDisappear: (): void => {
        this.showMidAutumnGreeting = false;
      }
    };
    if (this.supportsImmersiveMaterial()) {
      options.backgroundColor = Color.Transparent;
      options.systemMaterial = new uiMaterial.ImmersiveMaterial({
        style: uiMaterial.ImmersiveStyle.THICK
      });
    } else {
      options.backgroundColor = this.themedPageSurface();
    }
    return options;
  }

  private showSearchPage(): void {
    this.selectRootTabPage(EXPLORE_TAB_INDEX);
    this.resetExploreSearchState();
    this.getUIContext().animateTo({
      curve: curves.interpolatingSpring(0, 1, 342, 38)
    }, (): void => {
      this.navPathStack.pushPath({ name: 'SearchHistoryPage' }, false);
    });
  }

  private showSearchResultsPage(): void {
    this.selectRootTabPage(EXPLORE_TAB_INDEX);
    this.getUIContext().animateTo({
      curve: curves.interpolatingSpring(0, 1, 342, 38)
    }, (): void => {
      this.navPathStack.pushPath({ name: 'SearchResultsPage' }, false);
    });
  }

  private closeSearchPage(): void {
    this.getUIContext().animateTo({
      curve: curves.interpolatingSpring(0, 1, 342, 38)
    }, (): void => {
      this.navPathStack.pop(false);
    });
  }

  private closeSearchHistoryPage(): void {
    this.resetExploreSearchState();
    this.closeSearchPage();
    this.restoreExploreHomeTop();
  }

  private closeSearchResultsPage(): void {
    this.resetExploreSearchState();
    this.closeSearchPage();
    this.restoreExploreHomeTop();
  }

  private restoreExploreHomeTop(): void {
    setTimeout((): void => {
      try {
        this.getExploreScroller().scrollToIndex(0, false, ScrollAlign.START);
      } catch (error) {
        // The Explore list is attached again after the destination pop.
      }
    }, 360);
  }

  private resetExploreSearchState(): void {
    this.searchText = '';
    this.activeExploreQuery = '';
    this.exploreResults = [];
    this.exploreUsers = [];
    this.exploreNextToken = '';
    this.hasMoreExplore = false;
    this.loadingMoreExplore = false;
    this.searchLoading = false;
    this.activeSearchQuerySource = 'typed_query';
    this.searchRequestId += 1;
  }

  private submitSearchFromHistory(value: string): void {
    const query: string = value.trim();
    if (query.length === 0) {
      return;
    }
    this.submitSearch(query, 'recent_search_click');
    this.showSearchResultsPage();
  }

  private submitSearchFromTrend(value: string): void {
    const query: string = value.trim();
    if (query.length === 0) {
      return;
    }
    this.submitSearch(query, 'trend_click');
    this.showSearchResultsPage();
  }

  private submitSearchFromTrendItem(item: XExploreTrend): void {
    if (item.query.length > 0) {
      this.submitSearchFromTrend(item.query);
      return;
    }
    if (item.url.length > 0) {
      this.openExploreDestination(item.url);
      return;
    }
    this.submitSearchFromTrend(item.name);
  }

  private openExploreDestination(rawUrl: string): void {
    if (rawUrl.length === 0) {
      return;
    }
    const trendingPrefix: string = 'twitter://trending/';
    if (rawUrl.indexOf(trendingPrefix) === 0) {
      this.openIncomingXLink('https://x.com/i/trending/' + rawUrl.substring(trendingPrefix.length));
      return;
    }
    if (rawUrl === 'twitter://connect_people') {
      this.openIncomingXLink('https://x.com/i/connect_people');
      return;
    }
    this.openIncomingXLink(rawUrl);
  }

  private submitSearchFromHeader(value: string, inResults: boolean): void {
    if (inResults) {
      this.submitSearch(value, 'typed_query');
    } else {
      const query: string = value.trim();
      if (query.length === 0) {
        return;
      }
      this.submitSearch(query, 'typed_query');
      this.showSearchResultsPage();
    }
  }

  private isLargeScreen(): boolean {
    return ResponsiveLayout.isLarge(this.breakpoint);
  }

  private sideDrawerWidth(): number {
    if (this.isLargeScreen()) {
      return 300;
    }
    const viewportWidth: number = this.windowWidth > 0 ? this.windowWidth : 390;
    return Math.min(280, viewportWidth * 0.72);
  }

  onBackPress(): boolean {
    if (!this.isLargeScreen() && this.showSideDrawer) {
      this.showSideDrawer = false;
      return true;
    }
    return false;
  }

  private isWideScreen(): boolean {
    return ResponsiveLayout.isWide(this.breakpoint);
  }

  private effectiveTimelineColumns(): number {
    if (this.isDesktopLayout()) {
      return DesktopLayout.timelineColumns(this.timelineColumnsMode, this.desktopContentWidth);
    }
    if (!this.isLargeScreen()) {
      return 1;
    }
    if (this.timelineColumnsMode === TIMELINE_COLUMNS_ONE) {
      return 1;
    }
    if (this.timelineColumnsMode === TIMELINE_COLUMNS_TWO) {
      return 2;
    }
    if (this.timelineColumnsMode === TIMELINE_COLUMNS_THREE) {
      return 3;
    }
    if (this.isWideScreen() && this.contentDestinationOpen) {
      return 1;
    }
    if (this.isWideScreen()) {
      return 3;
    }
    return 2;
  }

  private timelineColumnsTemplate(): string {
    const columns: number = this.effectiveTimelineColumns();
    if (columns >= 3) {
      return '1fr 1fr 1fr';
    }
    if (columns === 2) {
      return '1fr 1fr';
    }
    return '1fr';
  }

  private useTimelineWaterFlow(): boolean {
    // A split changes the column count, not the mounted scroll container.
    // Switching WaterFlow to List destroys the visible post/media subtree.
    return this.isLargeScreen();
  }

  private homeFlowItems(): number[] {
    const items: number[] = [];
    const total: number = this.filteredTimeline().length + 2;
    for (let i: number = 0; i < total; i++) {
      items.push(i);
    }
    return items;
  }

  private pagedFlowItems(contentCount: number): number[] {
    const items: number[] = [];
    const total: number = contentCount + 2;
    for (let i: number = 0; i < total; i++) {
      items.push(i);
    }
    return items;
  }

  private syncThreePartWaterFlowSections(sections: WaterFlowSections, ready: boolean, contentCount: number): boolean {
    const headerSection: SectionOptions = {
      itemsCount: 1,
      crossCount: 1,
      columnsGap: 0,
      rowsGap: 0
    };
    const contentSection: SectionOptions = {
      itemsCount: contentCount,
      crossCount: this.effectiveTimelineColumns(),
      columnsGap: 1,
      rowsGap: 0
    };
    const footerSection: SectionOptions = {
      itemsCount: 1,
      crossCount: 1,
      columnsGap: 0,
      rowsGap: 0
    };
    if (!ready) {
      const sectionOptions: SectionOptions[] = [headerSection, contentSection, footerSection];
      sections.splice(0, 0, sectionOptions);
      return true;
    }
    const previous: SectionOptions[] = sections.values();
    if (previous[1]?.itemsCount !== contentSection.itemsCount || previous[1]?.crossCount !== contentSection.crossCount) {
      sections.update(1, contentSection);
    }
    return true;
  }

  private syncHomeWaterFlowSections(): void {
    this.homeWaterFlowSectionsReady = this.syncThreePartWaterFlowSections(
      this.homeWaterFlowSections,
      this.homeWaterFlowSectionsReady,
      this.filteredTimeline().length
    );
  }

  private syncExploreWaterFlowSections(): void {
    this.exploreWaterFlowSectionsReady = this.syncThreePartWaterFlowSections(
      this.exploreWaterFlowSections,
      this.exploreWaterFlowSectionsReady,
      this.filteredExploreResults().length
    );
  }

  private syncNotificationsWaterFlowSections(): void {
    this.notificationsWaterFlowSectionsReady = this.syncThreePartWaterFlowSections(
      this.notificationsWaterFlowSections,
      this.notificationsWaterFlowSectionsReady,
      this.visibleNotifications().length
    );
  }

  private syncOwnPostsWaterFlowSections(): void {
    this.ownPostsWaterFlowSectionsReady = this.syncThreePartWaterFlowSections(
      this.ownPostsWaterFlowSections,
      this.ownPostsWaterFlowSectionsReady,
      this.visibleMePosts().length
    );
  }

  private syncAllWaterFlowSections(): void {
    this.syncHomeWaterFlowSections();
    this.syncExploreWaterFlowSections();
    this.syncNotificationsWaterFlowSections();
    this.syncOwnPostsWaterFlowSections();
  }

  private onTimelineChanged(): void {
    this.syncHomeWaterFlowSections();
    this.homePageDataSource(this.homeTabIndex()).replace(this.filteredTimeline(),
      this.promotionsForTab(this.homeTabIndex()), this.tabKey(this.homeTabIndex()),
      this.promotionCountForTab(this.homeTabIndex()));
  }

  private onExploreResultsChanged(): void {
    this.syncExploreWaterFlowSections();
  }

  private onNotificationsChanged(): void {
    this.syncNotificationsWaterFlowSections();
  }

  private visibleNotifications(index: number = this.notificationFilter): AppNotification[] {
    if (this.usesPrivateMentions(index)) { return this.mentionNotifications; }
    return NotificationFilters.apply(this.notifications, index);
  }

  private usesPrivateMentions(index: number = this.notificationFilter): boolean {
    return index === 1 && this.notificationsSource !== 'sample' && this.xPrivate.isSignedIn();
  }

  private notificationPageStatus(index: number): string {
    return this.usesPrivateMentions(index) ? this.mentionsStatus : this.notificationsStatus;
  }

  private notificationPageLoading(index: number): boolean {
    return this.usesPrivateMentions(index) ? this.mentionsLoading :
      this.notificationsLoading || this.loadingMoreNotifications;
  }

  private notificationPageHasMore(index: number): boolean {
    return this.usesPrivateMentions(index) ? this.mentionsHasMore : this.hasMoreNotifications;
  }

  private onNotificationFilterChanged(): void {
    this.syncNotificationsWaterFlowSections();
    if (this.usesPrivateMentions() &&
      (this.mentionsFetchedAt === 0 || Date.now() - this.mentionsFetchedAt >= NOTIFICATIONS_FRESH_MS)) {
      this.loadNotificationMentions(true).catch((): void => {});
    }
  }

  private onTitleBarLogoChanged(): void {
    this.setHomeHeaderCollapsed(false);
  }

  private onOwnPostsChanged(): void {
    this.syncOwnPostsWaterFlowSections();
  }

  private onLikedPostsChanged(): void {
    this.syncOwnPostsWaterFlowSections();
  }

  private onTimelineLayoutChanged(): void {
    this.beginHomeViewportChange();
    this.syncAllWaterFlowSections();
  }

  private onDesktopContentAreaChanged(area: Area): void {
    const width: number = Number(area.width);
    if (!Number.isFinite(width) || width <= 0 || Math.abs(width - this.desktopContentWidth) < 0.5) { return; }
    const columnsChanged: boolean = DesktopLayout.timelineColumns(this.timelineColumnsMode, width) !==
      DesktopLayout.timelineColumns(this.timelineColumnsMode, this.desktopContentWidth);
    if (columnsChanged) { this.beginHomeViewportChange(); }
    this.desktopContentWidth = width;
    if (columnsChanged) { this.syncAllWaterFlowSections(); }
    this.scheduleHomeViewportRestore();
  }

  private rememberHomeVisibleItem(first: number): void {
    if (this.homeViewportChanging || !this.homeViewportReady) { return; }
    const posts: Tweet[] = this.filteredTimeline();
    const item: number = Math.max(0, Math.min(first, posts.length));
    // Read while the old layout is still live. During a breakpoint change the
    // old Scroller can already be detached or bound to a new, topmost viewport.
    try {
      const rect: RectResult = this.getHomeScroller().getItemRect(item);
      if (rect.height <= 0 || !Number.isFinite(rect.y)) { return; }
      this.homeVisiblePostOffset = rect.y;
    } catch (_error) { return; }
    this.homeFirstVisibleItem = item;
    this.homeVisiblePostId = this.homeFirstVisibleItem > 0 ? posts[this.homeFirstVisibleItem - 1].id : '';
    this.homeViewportHasAnchor = true;
  }

  private onHomeViewportAppear(index: number, kind: string): void {
    if (index !== this.homeTabIndex()) { return; }
    this.homeViewportMount = this.homeTabItems()[index].key + ':' + kind;
    this.homeViewportReady = true;
    if (this.homeViewportHasAnchor) { this.beginHomeViewportChange(); }
  }

  private onHomeViewportDisappear(index: number, kind: string): void {
    if (index !== this.homeTabIndex() ||
      this.homeViewportMount !== this.homeTabItems()[index].key + ':' + kind) { return; }
    this.homeViewportReady = false;
    this.homeViewportMount = '';
    this.beginHomeViewportChange();
  }

  private onHomeViewportChanged(): void {
    this.beginHomeViewportChange();
  }

  private beginHomeViewportChange(): void {
    if (!this.homeViewportHasAnchor) { return; }
    this.homeViewportChanging = true;
    this.scheduleHomeViewportRestore();
  }

  private scheduleHomeViewportRestore(): void {
    if (!this.homeViewportChanging) { return; }
    if (this.homeViewportRestoreTimer >= 0) { clearTimeout(this.homeViewportRestoreTimer); }
    const revision: number = ++this.homeViewportRevision;
    // Let the resized viewport and WaterFlow sections settle before restoring
    // the same post. Repeated width/area events keep the original anchor.
    this.homeViewportRestoreTimer = setTimeout((): void => {
      this.homeViewportRestoreTimer = -1;
      // A rotation can unmount desktop/WaterFlow before its replacement List
      // appears. Keep the anchor pending until that replacement is attached.
      if (!this.homeViewportReady) { return; }
      const posts: Tweet[] = this.filteredTimeline();
      const found: number = posts.findIndex((post: Tweet): boolean => post.id === this.homeVisiblePostId);
      const item: number = found >= 0 ? found + 1 : Math.min(this.homeFirstVisibleItem, posts.length);
      try {
        this.getHomeScroller().scrollToIndex(item, false, ScrollAlign.START,
          { extraOffset: LengthMetrics.vp(-this.homeVisiblePostOffset) });
      } catch (_error) { return; }
      // scrollToIndex is applied in layout, not synchronously. Protect against
      // the replacement container's initial onScrollIndex(0) until it commits.
      this.getUIContext().postFrameCallback(new HomeViewportFrameCallback((): void => {
        if (revision !== this.homeViewportRevision || !this.homeViewportReady) { return; }
        this.homeViewportChanging = false;
        this.rememberHomeVisibleItem(item);
      }));
    }, 120);
  }

  private onContentFilterChanged(): void {
    this.syncAllWaterFlowSections();
    for (let index: number = 0; index < this.homeTabItems().length; index++) {
      this.homePageDataSource(index).replace(this.filteredTimeline(index),
        this.promotionsForTab(index), this.tabKey(index), this.promotionCountForTab(index));
    }
  }

  private contentFilterSettings(): ContentFilterSettings {
    return new ContentFilterSettings(
      this.filterOnlyMedia,
      this.filterHideReposts,
      this.filterHideReplies,
      this.filterKeywords,
      this.filterMutedUsers,
      this.filterHideAds
    );
  }

  private filteredTimeline(index: number = this.homeTabIndex()): Tweet[] {
    const source: Tweet[] = index === this.homeTabIndex() ? this.timeline : this.homeSnapshotAt(index).timeline;
    const filtered: Tweet[] = contentFilterStore.filter(source, this.contentFilterSettings())
      .filter((tweet: Tweet): boolean => !postModerationStore.hidden(tweet));
    return index >= 2 ? filtered : homeTimelineStore.present(filtered, index === 0);
  }

  private onHomeTimelinePreferencesChanged(): void {
    this.pinnedHomeTopics = homeTimelineStore.pinnedTopics();
    if (this.activeHomeTopicId.length > 0 && !homeTimelineStore.isPinned(this.activeHomeTopicId)) {
      this.applyHomeFeedMode(this.defaultHomeFeedMode);
    }
    // Refresh both List and WaterFlow when the store changes without touching
    // the original pagination order or fetching a new page.
    this.timeline = this.copyTweets(this.timeline);
    if (this.topicPauseTimer >= 0) {
      clearTimeout(this.topicPauseTimer);
      this.topicPauseTimer = -1;
    }
    const next: number = homeTimelineStore.nextPauseExpiry();
    if (next > 0) {
      this.topicPauseTimer = setTimeout((): void => {
        this.topicPauseTimer = -1;
        homeTimelineStore.publish();
      }, Math.max(1, next - Date.now()));
    }
  }

  private onPostModerationChanged(): void {
    for (let index: number = 0; index < this.homeTabItems().length; index++) {
      this.homePageDataSource(index).replace(this.filteredTimeline(index),
        this.promotionsForTab(index), this.tabKey(index), this.promotionCountForTab(index));
    }
    this.syncAllWaterFlowSections();
  }

  private openHomeTimelineOptions(mode: number): void {
    if (!this.isBaseHomeFeedSelected(mode)) {
      this.showPauseTopics = false;
      this.showFollowingOrder = false;
      this.changeHomeFeed(mode);
      return;
    }
    this.showPauseTopics = mode === 0;
    this.showFollowingOrder = mode === 1;
  }

  private openTimelineManager(): void {
    this.openContentDestination();
    this.navPathStack.pushPath({ name: 'TimelineManager' });
  }

  private pauseTopicsSheetHeight(): number {
    const height: number = this.windowHeight > 0 ? this.windowHeight : 844;
    return Math.max(240, Math.min(780, height - this.statusBarHeight - 112));
  }

  private filteredExploreResults(): Tweet[] {
    return contentFilterStore.filter(this.exploreResults, this.contentFilterSettings());
  }

  private visibleExploreCards(index: number): XExploreTimelineCard[] {
    return this.exploreCategoryPages[index].cards.filter((card: XExploreTimelineCard): boolean => {
      if (this.filterHideAds && card.kind === 'hero' && card.hero?.promoted === true) { return false; }
      if (card.kind === 'tweets') {
        return contentFilterStore.filter(card.tweets, this.contentFilterSettings()).length > 0;
      }
      return true;
    });
  }

  private searchPagePosts(index: number): Tweet[] {
    const source: Tweet[] = index === this.searchProductIndex() ? this.exploreResults :
      this.searchTabSnapshots.get(SEARCH_PRODUCT_IDS[index])?.posts ?? [];
    return contentFilterStore.filter(source, this.contentFilterSettings());
  }

  private searchPageUsers(index: number): UserRow[] {
    return index === this.searchProductIndex() ? this.exploreUsers :
      this.searchTabSnapshots.get(SEARCH_PRODUCT_IDS[index])?.users ?? [];
  }

  private searchPageStatus(index: number): string {
    return index === this.searchProductIndex() ? this.exploreStatus :
      this.searchTabSnapshots.get(SEARCH_PRODUCT_IDS[index])?.status ?? '';
  }

  private searchPageLoading(index: number): boolean {
    return index === this.searchProductIndex() ? this.searchLoading : !this.searchTabSnapshots.has(SEARCH_PRODUCT_IDS[index]);
  }

  private filteredOwnPosts(): Tweet[] {
    return contentFilterStore.filter(this.ownPosts, this.contentFilterSettings());
  }

  private filteredLikedPosts(): Tweet[] {
    return contentFilterStore.filter(this.likedPosts, this.contentFilterSettings());
  }

  private visibleMePosts(index: number = this.meTimelineTab): Tweet[] {
    return index === 1 ? this.filteredLikedPosts() : this.filteredOwnPosts();
  }

  // At 840vp the drawer becomes a persistent navigation rail. At 1200vp we
  // additionally have room for the feed and a destination side by side.
  private onBreakpointChange(): void {
    this.closeDesktopRail();
    this.beginHomeViewportChange();
    if (ResponsiveLayout.isSmall(this.breakpoint)) {
      this.showSideDrawer = false;
      this.updateNavigationMode();
      this.syncAllWaterFlowSections();
      return;
    }
    this.showSideDrawer = !this.isDesktopLayout() && this.isLargeScreen();
    this.updateNavigationMode();
    this.syncAllWaterFlowSections();
  }

  private onContentDestinationChange(): void {
    this.beginHomeViewportChange();
    this.updateNavigationMode();
    this.syncAllWaterFlowSections();
  }

  private updateNavigationMode(): void {
    if (this.isDesktopLayout()) {
      this.mainNavigationMode = this.currentTab === MESSAGES_TAB_INDEX &&
        (this.desktopRoute === 'DmConversation' || this.desktopRoute === 'DmInfo' || this.desktopRoute === 'DmGroup') ?
        NavigationMode.Split : NavigationMode.Stack;
      return;
    }
    this.mainNavigationMode = this.isWideScreen() && this.contentDestinationOpen &&
      !this.contentDestinationUsesFullPage() ?
      NavigationMode.Split : NavigationMode.Stack;
  }

  // A post is a reading page, not a second feed pane. Keep it in the same
  // full-width stack on every large screen while nested destinations remain
  // reachable through ordinary back navigation.
  private contentDestinationUsesFullPage(): boolean {
    if (this.pendingFullPageDestination) { return true; }
    const names: string[] = this.navPathStack.getAllPathName();
    for (let i: number = 0; i < names.length; i++) {
      if (names[i] === 'PostDetail') { return true; }
    }
    return false;
  }

  private openContentDestination(): void {
    ResponsiveLayout.openContentDestination();
    this.updateNavigationMode();
    if (this.isDesktopLayout() || !this.isLargeScreen()) {
      this.showSideDrawer = false;
    }
  }

  private contentTopInset(): number {
    if (this.isDesktopLayout()) { return 0; }
    if (!this.supportsHdsNavigation()) {
      return 12;
    }
    return RootTitleBarLayout.contentTopInset(this.currentTab, this.useTitleBarLogo(),
      this.statusBarHeight, false, 0, this.rootTitleBarContentClearance());
  }

  private useTitleBarLogo(): boolean {
    return this.titleBarLogoEnabled && !this.compactWindow;
  }

  private onCompactWindowChanged(): void {
    this.beginHomeViewportChange();
    this.homeHeaderCollapsed = false;
    this.setTabBarHidden(false);
    this.fabHidden = false;
  }

  private rootTitleBarContentClearance(): number {
    if (!this.isLargeScreen() || this.isDesktopLayout()) { return 0; }
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    return this.getUIContext().px2vp(context.resourceManager.getNumber(
      $r('app.float.large_title_bar_content_gap').id));
  }

  // Home owns its identity row and feed switch inside its own tab page. Keep
  // the list clear of that fixed overlay, independently of the outer
  // navigation container and of the other mounted tab pages.
  private homeContentTopInset(): number {
    if (this.isDesktopLayout()) { return 0; }
    if (!this.supportsHdsNavigation()) {
      return 12;
    }
    return RootTitleBarLayout.contentTopInset(HOME_TAB_INDEX, this.useTitleBarLogo(),
      this.statusBarHeight, this.homeHeaderCollapsed, this.homeSpaceHeight(), this.rootTitleBarContentClearance());
  }

  private homeSpace(): SpaceRoom | null {
    if (this.compactWindow || !this.homeSpaceCapsuleEnabled || this.homeSpaceCapsuleHiddenForSession) { return null; }
    if (this.spaceSurfaceRevision < 0) { return null; }
    const hidden: string[] = spacePreferencesStore.hidden(getContext(this) as common.UIAbilityContext);
    return spaceSurfaceStore.liveRecommendations().find((room: SpaceRoom): boolean => hidden.indexOf(room.id) < 0) ?? null;
  }
  private homeSpaceHeight(): number { return this.homeSpace() !== null ? 60 : 0; }
  private refreshHomeSpaces(): void {
    if (this.spaceRecommendationsLoading) { return; }
    if (this.spaceRecommendationTimer >= 0) { clearTimeout(this.spaceRecommendationTimer); this.spaceRecommendationTimer = -1; }
    if (!this.spaceRecommendationsAlive || !this.appForeground) { return; }
    this.spaceRecommendationsLoading = true;
    spaceSurfaceStore.refresh().catch((): void => {
      console.warn('Home Spaces recommendation lookup unavailable');
    }).finally((): void => {
      this.spaceRecommendationsLoading = false;
      if (this.spaceRecommendationsAlive) {
        this.spaceRecommendationTimer = setTimeout((): void => this.refreshHomeSpaces(), 60000);
      }
    });
  }
  private openSpacePreview(room: SpaceRoom, fromHomeCapsule: boolean = false): void {
    this.previewFromHomeCapsule = fromHomeCapsule;
    this.previewSpaceId = room.id; this.showSpacePreview = true;
  }
  private closeHomeSpaceCapsule(permanent: boolean): void {
    if (permanent) {
      if (!spacePreferencesStore.saveHomeCapsuleEnabled(getContext(this) as common.UIAbilityContext, false)) {
        promptAction.showToast({ message: this.text($r('app.string.spaces_save_failed')) });
        return;
      }
    } else { spacePreferencesStore.hideHomeCapsuleForSession(); }
    this.showSpacePreview = false;
  }
  private onSpacePreviewRequested(): void {
    if (this.spacePreviewRequest.length === 0) { return; }
    const id: string = this.spacePreviewRequest;
    this.spacePreviewRequest = '';
    if (/^[A-Za-z0-9]{5,64}$/.test(id)) {
      this.previewFromHomeCapsule = false;
      this.previewSpaceId = id; this.showSpacePreview = true;
    }
  }
  @Builder
  private HomeSpaceCapsule(): void {
    if (this.homeSpace() !== null) {
      HomeSpacePill({ room: this.homeSpace() as SpaceRoom,
        pillWidth: Math.max(180, (this.windowWidth > 0 ? Math.min(this.windowWidth, this.isLargeScreen() ? 480 : this.windowWidth) : 390) - 24),
        onOpen: (room: SpaceRoom): void => this.openSpacePreview(room, true) })
    }
  }
  @Builder
  private SpacePreviewContent(): void {
    SpacePreviewSheet({ spaceId: this.previewSpaceId, canCloseHomeCapsule: this.previewFromHomeCapsule,
      onCloseHomeCapsule: (permanent: boolean): void => this.closeHomeSpaceCapsule(permanent),
      onClose: (): void => { this.showSpacePreview = false; },
      onPerson: (person: SpaceParticipant): void => { this.previewPerson = person; this.showSpacePreview = false; } })
  }

  private exploreContentTopInset(): number {
    if (this.isDesktopLayout()) { return 0; }
    if (!this.supportsHdsNavigation()) {
      return 12;
    }
    if (this.exploreTitleContentBottom > 0) {
      return Math.max(0, Math.max(this.exploreTitleContentBottom,
        this.titleBarSurfaceTop + this.exploreNativeTitleHeight) - this.exploreContentTop) +
        this.rootTitleBarContentClearance();
    }
    // Used only before the first intrinsic header measurement arrives.
    return RootTitleBarLayout.contentTopInset(EXPLORE_TAB_INDEX, this.useTitleBarLogo(),
      this.statusBarHeight, false, 0, this.rootTitleBarContentClearance());
  }

  private messagesContentTopInset(): number {
    if (this.isDesktopLayout()) { return 0; }
    return this.supportsHdsNavigation() ? RootTitleBarLayout.contentTopInset(MESSAGES_TAB_INDEX,
      this.useTitleBarLogo(), this.statusBarHeight, false, 0, this.rootTitleBarContentClearance()) : 12;
  }

  private notificationsContentTopInset(standalone: boolean = false): number {
    if (this.isDesktopLayout()) { return 0; }
    if (standalone) { return this.statusBarHeight + 116 + this.rootTitleBarContentClearance(); }
    return this.supportsHdsNavigation() ? RootTitleBarLayout.contentTopInset(NOTIFICATIONS_TAB_INDEX,
      this.useTitleBarLogo(), this.statusBarHeight, false, 0, this.rootTitleBarContentClearance()) : 12;
  }

  private rootTitleBarBottomHeight(): number {
    if (this.isDesktopLayout()) { return Math.max(0, this.desktopHeaderHeight() - this.desktopTitleBarHeight()); }
    if (this.chromeTab === EXPLORE_TAB_INDEX && this.exploreTitleContentBottom > 0) {
      return RootTitleBarLayout.measuredBottomHeight(this.exploreTitleContentBottom - this.titleBarSurfaceTop,
        this.exploreNativeTitleHeight);
    }
    return RootTitleBarLayout.bottomHeight(this.chromeTab, this.useTitleBarLogo(),
      this.homeHeaderCollapsed, this.homeSpaceHeight(), this.activeExploreQuery.length > 0);
  }

  // The floating tab bar is drawn on top of the feed instead of taking its own
  // strip, so every tab content has to reserve that height at its own end.
  // Without it the last post stops under the bar and cannot be pulled clear,
  // which reads as "the last post will not scroll up".
  private contentBottomInset(): number {
    if (this.isDesktopLayout()) { return this.navigationIndicatorHeight + 20; }
    if (!this.usesFloatingTabBar()) {
      if (this.supportsHdsNavigation()) {
        return this.classicTabBarHeight() + (this.hasActiveSpace() ? 72 : 0);
      }
      return this.hasActiveSpace() ? 72 : 0;
    }
    return this.floatingTabBottomMargin() + 96 + (this.hasActiveSpace() ? 72 : 0);
  }

  private hasActiveSpace(): boolean { return this.spacePlaybackRevision >= 0 && spacePlayback.room !== null; }

  private titleBarStyle(): TitleBarStyleOptions {
    return rootTitleBarStyle(this.displayMode, this.darkSurface, this.titleBarStyleMode, this.isDesktopLayout());
  }

  private rootTitleBarOptions(): HdsNavigationTitleBarOptions {
    // Retain the shared title nodes on phones as well: scroll and pager updates
    // must update their state without mounting a new avatar/image subtree.
    if (SystemMaterialUtil.isApi26OrAbove()) {
      return {
        style: this.titleBarStyle(), avoidLayoutSafeArea: true, enableComponentSafeArea: this.isDesktopLayout(),
        content: {
          stackBuilder: this.rootTitleBarBuilder,
          stackBuilderContent: retainedTitleBarBuilder(this.rootTitleBarBuilder),
          bottomBuilder: {
            builder: this.rootTitleBarBottomBuilder,
            builderContent: retainedTitleBarBuilder(this.rootTitleBarBottomBuilder),
            height: this.rootTitleBarBottomHeight(), showType: BottomBuilderShowType.DIRECTLY_SHOW
          },
          divider: { showType: DividerShowType.OFF }
        }
      };
    }
    // Older HDS must receive only its supported builder fields. An explicitly
    // undefined API 26 content field can suppress the legacy title builder.
    return {
      style: this.titleBarStyle(), avoidLayoutSafeArea: true, enableComponentSafeArea: this.isDesktopLayout(),
      content: {
        stackBuilder: this.isDesktopLayout() ? this.rootTitleBarBuilder : (): void => this.ImmersiveTitleBarContent(),
        bottomBuilder: {
          builder: this.isDesktopLayout() ? this.rootTitleBarBottomBuilder : (): void => this.TitleBarBottomContent(),
          height: this.rootTitleBarBottomHeight(), showType: BottomBuilderShowType.DIRECTLY_SHOW
        },
        divider: { showType: DividerShowType.OFF }
      }
    };
  }

  private floatingTabBottomMargin(): number {
    if (!this.usesFloatingTabBar()) {
      return this.navigationIndicatorHeight;
    }
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const gap: number = this.getUIContext().px2vp(context.resourceManager.getNumber(
      $r('app.float.floating_tab_bottom_gap').id));
    return Math.max(0, this.navigationIndicatorHeight) + gap;
  }

  private classicTabBarHeight(): number {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    return this.getUIContext().px2vp(context.resourceManager.getNumber(
      $r('app.float.root_tab_bar_height').id)) + Math.max(0, this.navigationIndicatorHeight);
  }

  private rootTabFloatingStyle(): HdsTabsFloatingStyle | undefined {
    if (!this.usesFloatingTabBar()) {
      return undefined;
    }
    return {
      adaptToHandedness: true,
      barBottomMargin: this.floatingTabBottomMargin(),
      lightColor: this.accentColor,
      systemMaterialEffect: {
        materialType: hdsMaterial.MaterialType.IMMERSIVE,
        materialLevel: this.resolveHomeTabMaterialLevel()
      }
    };
  }

  private resolveHomeTabMaterialLevel(): hdsMaterial.MaterialLevel {
    if (this.homeTabMaterialLevel === HDS_TAB_MATERIAL_EXQUISITE) {
      return hdsMaterial.MaterialLevel.EXQUISITE;
    }
    if (this.homeTabMaterialLevel === HDS_TAB_MATERIAL_GENTLE) {
      return hdsMaterial.MaterialLevel.GENTLE;
    }
    if (this.homeTabMaterialLevel === HDS_TAB_MATERIAL_SMOOTH) {
      return hdsMaterial.MaterialLevel.SMOOTH;
    }
    return hdsMaterial.MaterialLevel.ADAPTIVE;
  }

  private bindHdsTabScrollers(): void {
    if (!this.usesFloatingTabBar()) {
      return;
    }
    this.contentPageScrollers.forEach((scroller: Scroller): void => { this.hdsTabsController.unbindScroller(scroller); });
    this.hdsTabsController.unbindScroller(this.messagesScroller);
    this.hdsTabsController.unbindScroller(this.profileScroller);
    let tabIndex: number = 0;
    for (let pageIndex: number = 0; pageIndex < BOTTOM_BAR_PAGE_COUNT; pageIndex++) {
      if (!this.isBottomBarPageEnabled(pageIndex)) {
        continue;
      }
      const scrollers: Scroller[] = this.rootPageScrollers(pageIndex);
      for (let i: number = 0; i < scrollers.length; i++) {
        this.hdsTabsController.bindScroller(tabIndex, scrollers[i]);
      }
      tabIndex++;
    }
  }

  private rootPageScrollers(pageIndex: number): Scroller[] {
    if (pageIndex === HOME_TAB_INDEX) {
      return this.homeTabItems().map((item: IconTabItem): Scroller => this.contentPageScroller('home', item.key));
    }
    if (pageIndex === EXPLORE_TAB_INDEX) {
      return EXPLORE_CATEGORY_IDS.map((id: string): Scroller => this.contentPageScroller('explore', id));
    }
    if (pageIndex === NOTIFICATIONS_TAB_INDEX) {
      return [0, 1, 2].map((index: number): Scroller => this.contentPageScroller('notifications', index.toString()));
    }
    return [pageIndex === MESSAGES_TAB_INDEX ? this.messagesScroller : this.profileScroller];
  }

  private rootScrollableControllers(): Scroller[] {
    const scrollers: Scroller[] = [];
    for (let index: number = 0; index < BOTTOM_BAR_PAGE_COUNT; index++) {
      scrollers.push(...this.rootPageScrollers(index));
    }
    return scrollers;
  }

  private isBottomBarPageEnabled(pageIndex: number): boolean {
    return (this.bottomBarPagesMask & (1 << pageIndex)) !== 0;
  }

  private bottomBarPageIndex(pageIndex: number): number {
    let visibleIndex: number = 0;
    for (let candidate: number = 0; candidate < BOTTOM_BAR_PAGE_COUNT; candidate++) {
      if (!this.isBottomBarPageEnabled(candidate)) {
        continue;
      }
      if (candidate === pageIndex) {
        return visibleIndex;
      }
      visibleIndex++;
    }
    return 0;
  }

  private countBottomBarPages(): number {
    let count: number = 0;
    for (let pageIndex: number = 0; pageIndex < BOTTOM_BAR_PAGE_COUNT; pageIndex++) {
      if (this.isBottomBarPageEnabled(pageIndex)) {
        count++;
      }
    }
    return count;
  }

  private bottomBarPageAt(visibleIndex: number): number {
    let visiblePageIndex: number = 0;
    for (let pageIndex: number = 0; pageIndex < BOTTOM_BAR_PAGE_COUNT; pageIndex++) {
      if (!this.isBottomBarPageEnabled(pageIndex)) {
        continue;
      }
      if (visiblePageIndex === visibleIndex) {
        return pageIndex;
      }
      visiblePageIndex++;
    }
    return this.firstBottomBarPage();
  }

  private firstBottomBarPage(): number {
    for (let pageIndex: number = 0; pageIndex < BOTTOM_BAR_PAGE_COUNT; pageIndex++) {
      if (this.isBottomBarPageEnabled(pageIndex)) {
        return pageIndex;
      }
    }
    return HOME_TAB_INDEX;
  }

  private selectRootTabPage(pageIndex: number): void {
    const targetPage: number = this.isDesktopLayout() || this.isBottomBarPageEnabled(pageIndex) ? pageIndex : this.firstBottomBarPage();
    this.onTabChange(targetPage);
    if (!this.usesFloatingTabBar()) {
      this.tabsController.changeIndex(this.bottomBarPageIndex(targetPage));
    }
  }

  private onBottomBarPagesChanged(): void {
    this.bindHdsTabScrollers();
    if (!this.isBottomBarPageEnabled(this.currentTab)) {
      this.selectRootTabPage(this.firstBottomBarPage());
    }
  }

  // 显示设置 → 自动隐藏顶部标题栏。HdsNavigation 已经通过 bindToScrollable
  // 绑定了五个 tab 的滚动控制器，所以这里只需要给参数：开关关闭时所有字段都为
  // false，等于保持原来的常显行为。
  //
  // HideMode.SCROLL_UP 是"方向"触发：内容向上滚动（往下看）就收起，手指反向
  // 一滑就立刻展开。SCROLL_UP_TO 是按滚动位置的渐隐模式，那种模式要退回列表
  // 顶部标题栏才会完整出现，和"自动隐藏"的预期相反。
  private titleBarHideParams(): DynamicHideParams {
    if (this.isDesktopLayout() || (!this.autoHideTitleBar && !this.compactWindow)) {
      return {
        hideTitleArea: false,
        hideBottomBuilder: false,
        hideStatusBar: false
      };
    }
    return {
      hideTitleArea: true,
      // Keep the outgoing title-bar layout until the tab transition settles;
      // otherwise HdsNavigation tears down and recreates this material bar.
      hideBottomBuilder: !(this.chromeTabSettled === 1 && this.activeExploreQuery.length === 0),
      hideStatusBar: false,
      mode: HideMode.SCROLL_UP
    };
  }

  // Turning the switch off has to bring a bar that is already hidden back,
  // otherwise the setting would only take effect after the next restart.
  private onAutoHideTabBarChanged(): void {
    if (!this.autoHideTabBar && !this.compactWindow) {
      this.setTabBarHidden(false);
    }
  }

  // Turning the switch off has to bring back a button that is already out of
  // the way, instead of waiting for the next scroll to stop.
  private onAutoHideFabChanged(): void {
    if (!this.autoHideFab) {
      this.fabHidden = false;
    }
  }

  // scrollOffset is the per-frame delta used by the feed lists: positive while
  // the reader heads deeper, negative as soon as they scroll back up.
  private onChromeScroll(scrollOffset: number): void {
    if (scrollOffset === 0 || (!this.autoHideTabBar && !this.compactWindow) || !this.supportsHdsFloatingMaterial()) {
      return;
    }
    if (scrollOffset < 0) {
      this.setTabBarHidden(false);
      return;
    }
    this.setTabBarHidden(this.currentTabScrollOffset() > TAB_BAR_HIDE_DEPTH);
  }

  private onChromeScrollStop(): void {
    if ((!this.autoHideTabBar && !this.compactWindow) || !this.supportsHdsFloatingMaterial()) {
      return;
    }
    if (this.currentTabScrollOffset() <= TAB_BAR_HIDE_DEPTH) {
      this.setTabBarHidden(false);
    }
  }

  private currentTabScrollOffset(): number {
    try {
      if (this.currentTab === 1) {
        return Math.max(0, this.getExploreScroller().currentOffset().yOffset);
      }
      if (this.currentTab === 2) {
        return Math.max(0, this.getNotificationsScroller().currentOffset().yOffset);
      }
      if (this.currentTab === 3) {
        return Math.max(0, this.messagesScroller.currentOffset().yOffset);
      }
      if (this.currentTab === 4) {
        return Math.max(0, this.profileScroller.currentOffset().yOffset);
      }
      return Math.max(0, this.getHomeScroller().currentOffset().yOffset);
    } catch (error) {
      return 0;
    }
  }

  // 显示设置 → 自动隐藏底部导航栏。动效由 HdsTabsController 提供，页面只负责
  // 判断方向；隐藏状态同时驱动未读红点的显隐。
  private setTabBarHidden(hidden: boolean): void {
    const wantHidden: boolean = hidden && (this.autoHideTabBar || this.compactWindow) && this.supportsHdsFloatingMaterial();
    if (this.tabBarHidden === wantHidden) {
      return;
    }
    this.tabBarHidden = wantHidden;
    if (!this.usesFloatingTabBar()) {
      return;
    }
    try {
      if (wantHidden) {
        this.hdsTabsController.applyHideAnimation(HdsAnimationMode.SCROLL_ANIMATION);
      } else {
        this.hdsTabsController.applyShowAnimation(HdsAnimationMode.SCROLL_ANIMATION);
      }
    } catch (error) {
      // Systems without the 6.1 hide animation simply keep the bar in place.
    }
  }

  private contentPageScroller(group: string, key: string): Scroller {
    const id: string = group + ':' + key;
    let scroller: Scroller | undefined = this.contentPageScrollers.get(id);
    if (scroller === undefined) {
      scroller = new Scroller();
      this.contentPageScrollers.set(id, scroller);
    }
    return scroller;
  }

  private homePageDataSource(index: number): TimelinePageDataSource {
    const key: string = this.homeTabItems()[index].key;
    let source: TimelinePageDataSource | undefined = this.homePageSources.get(key);
    if (source === undefined) {
      source = new TimelinePageDataSource();
      source.replace(this.filteredTimeline(index), this.promotionsForTab(index),
        this.tabKey(index), this.promotionCountForTab(index));
      this.homePageSources.set(key, source);
    }
    return source;
  }

  // The remote recommendation post belongs to the for-you feed only; pinned
  // topics and the following feed keep showing exactly what X returned.
  private promotionsForTab(index: number): XXAuthPromotionPost[] {
    const items: IconTabItem[] = this.homeTabItems();
    if (index < 0 || index >= items.length) { return []; }
    const key: string = items[index].key;
    // Recommended and following timelines carry the promotions; a pinned topic
    // stays exactly what the reader asked for.
    if (key !== 'for-you' && key !== 'following') { return []; }
    const posts: XXAuthPromotionPost[] = this.promotionPlan().posts;
    return posts;
  }

  private promotionPlan(): XXAuthPromotionPlan {
    if (this.promotionPostJson.length === 0) { return new XXAuthPromotionPlan(); }
    try {
      const parsed: XXAuthPromotionPlan = JSON.parse(this.promotionPostJson) as XXAuthPromotionPlan;
      if (parsed === null || !(parsed.posts instanceof Array)) { return new XXAuthPromotionPlan(); }
      return parsed;
    } catch (error) { return new XXAuthPromotionPlan(); }
  }

  // The search timeline is a plain ForEach, so the rows are planned per query:
  // the same query keeps its positions, a new query draws new ones, and paging
  // in more results never moves a row that is already on screen.
  private searchTimelineRows(index: number): SearchTimelineRow[] {
    const posts: Tweet[] = this.searchPagePosts(index);
    const rows: SearchTimelineRow[] = [];
    const plan: XXAuthPromotionPlan = this.promotionPlan();
    const salt: string = SEARCH_PRODUCT_IDS[index] + ':' + this.activeExploreQuery;
    const slots: XXAuthPromotionSlot[] = XXAuthPromotionInjector.slots(posts.length,
      plan.posts, Math.min(plan.timelineCount, plan.posts.length), 'search:' + salt);
    const placement: Map<number, XXAuthPromotionPost> = new Map();
    for (let i: number = 0; i < slots.length; i++) {
      placement.set(Math.min(slots[i].index + i, posts.length + i), slots[i].post);
    }
    for (let position: number = 0; position <= posts.length; position++) {
      const injected: XXAuthPromotionPost | undefined = placement.get(position);
      if (injected !== undefined) {
        const row: SearchTimelineRow = new SearchTimelineRow();
        row.key = 'promo:' + injected.fingerprint + ':' + position.toString();
        row.promotion = injected;
        rows.push(row);
      }
      if (position < posts.length) {
        const row: SearchTimelineRow = new SearchTimelineRow();
        row.key = 'surface-post-' + posts[position].id;
        row.tweet = posts[position];
        rows.push(row);
      }
    }
    return rows;
  }

  private tabKey(index: number): string {
    const items: IconTabItem[] = this.homeTabItems();
    return index >= 0 && index < items.length ? items[index].key : '';
  }

  // The remote budget decides how many rows a timeline carries; the injector
  // picks which of the configured posts fills that row.
  private promotionCountForTab(index: number): number {
    const items: IconTabItem[] = this.homeTabItems();
    if (index < 0 || index >= items.length) { return 0; }
    const key: string = items[index].key;
    if (key !== 'for-you' && key !== 'following') { return 0; }
    return this.promotionPlan().timelineCount;
  }

  private onPromotionPostChanged(): void {
    for (let index: number = 0; index < this.homeTabItems().length; index++) {
      this.homePageDataSource(index).replace(this.filteredTimeline(index),
        this.promotionsForTab(index), this.tabKey(index), this.promotionCountForTab(index));
    }
  }

  private hidePromotionPost(): void {
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    xxAuthPopupStore.hidePromotion(context, Date.now(), this.promotionPostJson);
    AppStorage.setOrCreate<string>(XXAUTH_PROMOTION_POST, '');
  }

  private hidePromotionForSession(): void {
    xxAuthPopupStore.hidePromotionForSession();
    AppStorage.setOrCreate<string>(XXAUTH_PROMOTION_POST, '');
  }

  private openPromotionLink(url: string): void {
    if (url.length === 0) { return; }
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    context.startAbility({ action: 'ohos.want.action.viewData',
      entities: ['entity.system.browsable'], uri: url }).catch((): void => { });
  }

  private pageSections(group: string, key: string, count: number): WaterFlowSections {
    const id: string = group + ':' + key;
    let layout: ContentPageSections | undefined = this.contentPageLayouts.get(id);
    if (layout === undefined) {
      layout = new ContentPageSections();
      this.contentPageLayouts.set(id, layout);
    }
    const columns: number = this.effectiveTimelineColumns();
    if (layout.itemsCount !== count || layout.columns !== columns) {
      this.syncThreePartWaterFlowSections(layout.sections, layout.itemsCount >= 0, count);
      layout.itemsCount = count;
      layout.columns = columns;
    }
    return layout.sections;
  }

  private homeSnapshotAt(index: number): HomeFeedSnapshot {
    const topicId: string = this.pinnedHomeTopics[index - 2]?.id ?? '';
    if (index >= 2 && topicId.length > 0) {
      const saved: HomeFeedSnapshot | undefined = this.topicSnapshots.get(topicId);
      if (saved !== undefined) {
        return saved;
      }
      const snapshot: HomeFeedSnapshot = new HomeFeedSnapshot();
      this.topicSnapshots.set(topicId, snapshot);
      return snapshot;
    }
    return index === 0 ? this.forYouSnapshot : this.followingSnapshot;
  }

  private activeFeedSnapshot(): HomeFeedSnapshot { return this.homeSnapshotAt(this.homeTabIndex()); }

  private currentHomeOffset(): number {
    try {
      return Math.max(0, this.getHomeScroller().currentOffset().yOffset);
    } catch (error) {
      return 0;
    }
  }

  private copyTweets(source: Tweet[]): Tweet[] {
    const result: Tweet[] = [];
    for (let i: number = 0; i < source.length; i++) {
      result.push(source[i]);
    }
    return result;
  }

  private saveCurrentFeedSnapshot(): void {
    const snapshot: HomeFeedSnapshot = this.activeFeedSnapshot();
    snapshot.timeline = this.copyTweets(this.timeline);
    snapshot.suggestions = this.homeSuggestionGroups.slice();
    snapshot.pendingPosts = this.pendingNewPosts.slice();
    snapshot.pendingAuthors = this.pendingAuthors.slice();
    snapshot.nextToken = this.timelineNextToken;
    snapshot.topToken = this.timelineTopToken;
    snapshot.cursorHistory = [];
    for (let i: number = 0; i < this.timelineCursorHistory.length; i++) {
      snapshot.cursorHistory.push(this.timelineCursorHistory[i]);
    }
    snapshot.duplicatePageCount = this.duplicateTimelinePageCount;
    snapshot.source = this.timelineSource;
    snapshot.samplePage = this.sampleTimelinePage;
    snapshot.hasMore = this.hasMoreTimeline;
    snapshot.statusLine = this.statusLine;
    snapshot.liveBadge = this.liveBadge;
    snapshot.scrollOffset = this.currentHomeOffset();
    snapshot.loaded = true;
  }

  private restoreFeedSnapshot(snapshot: HomeFeedSnapshot): void {
    this.timeline = this.copyTweets(snapshot.timeline);
    this.homeSuggestionGroups = snapshot.suggestions.slice();
    this.pendingNewPosts = snapshot.pendingPosts.slice();
    this.pendingAuthors = snapshot.pendingAuthors.slice();
    this.timelineNextToken = snapshot.nextToken;
    this.timelineTopToken = snapshot.topToken;
    this.timelineCursorHistory = [];
    for (let i: number = 0; i < snapshot.cursorHistory.length; i++) {
      this.timelineCursorHistory.push(snapshot.cursorHistory[i]);
    }
    this.duplicateTimelinePageCount = snapshot.duplicatePageCount;
    this.timelineSource = snapshot.source;
    this.sampleTimelinePage = snapshot.samplePage;
    this.hasMoreTimeline = snapshot.hasMore;
    this.statusLine = snapshot.statusLine;
    this.liveBadge = snapshot.liveBadge;
  }

  // The capsule promises the newest post, so the merge is followed by a jump to
  // the top of the list instead of a scroll that lands wherever the reader was.
  private jumpToNewestPost(): void {
    // The lazy source applies its new rows in the next layout. Capture this
    // page's controller now, then scroll after that layout has completed.
    this.getUIContext().postFrameCallback(new FeedTopFrameCallback(this.getHomeScroller()));
  }

  // The offline cache is per account and per feed: replaying one account's
  // posts into another one's timeline would be worse than showing nothing.
  private feedCacheKey(): string {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const activeId: string = accountStore.activeId(context);
    const feed: string = this.activeHomeTopicId.length > 0 ? 'topic:' + this.activeHomeTopicId : this.homeFeedMode.toString();
    if (activeId.length > 0) {
      return activeId + '|' + feed;
    }
    const viewer: string = this.xPrivate.viewerId().length > 0 ? this.xPrivate.viewerId() :
      authStore.getUserId();
    return (viewer.length > 0 ? 'u:' + viewer : 'local') + '|' + feed;
  }

  // Keeps the first page the reader actually saw, so the next cold start has
  // something to show before — or instead of — a network round trip.
  private persistFeed(): void {
    if (this.feedFromCache || this.timelineSource === 'sample' || this.timeline.length === 0) {
      return;
    }
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const feed: CachedFeed = {
      savedAt: Date.now(),
      tweets: this.copyTweets(this.timeline),
      nextToken: this.timelineNextToken,
      source: this.timelineSource
    };
    this.lastFeedAt = feed.savedAt;
    FeedCache.save(context, this.feedCacheKey(), feed);
  }

  // Returns true when the cached page took over the timeline. Paging stops at
  // that point: the cache only ever holds one page.
  private restoreCachedFeed(): boolean {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const feed: CachedFeed | null = FeedCache.load(context, this.feedCacheKey());
    if (feed === null) {
      return false;
    }
    this.timeline = feed.tweets;
    this.timelineNextToken = '';
    this.timelineTopToken = '';
    this.hasMoreTimeline = false;
    if (feed.source.length > 0) {
      this.timelineSource = feed.source;
    }
    this.feedFromCache = true;
    this.lastFeedAt = feed.savedAt;
    this.liveBadge = '';
    this.statusLine = this.offlineStatusLine(feed.savedAt);
    return true;
  }

  private offlineStatusLine(savedAt: number): string {
    if (savedAt <= 0) {
      return this.text($r('app.string.status_offline_lost'));
    }
    return this.text($r('app.string.status_offline_cached_prefix')) + this.clockLabel(savedAt);
  }

  // HH:MM of the moment the cached page was fetched. A wall-clock stamp reads
  // the same in both languages, unlike a relative "3 minutes ago".
  private clockLabel(timestampMs: number): string {
    const at: Date = new Date(timestampMs);
    const hour: number = at.getHours();
    const minute: number = at.getMinutes();
    return (hour < 10 ? '0' + hour.toString() : hour.toString()) + ':' +
      (minute < 10 ? '0' + minute.toString() : minute.toString());
  }

  // The feed follows the device's data network: going offline only changes what
  // the status line says, while the connection coming back re-reads the
  // timeline so anything posted meanwhile is offered behind the capsule.
  private watchConnectivity(): void {
    this.networkOnline = this.connectivity.isOnline();
    this.connectivity.start((online: boolean): void => {
      this.onNetworkChanged(online);
    });
  }

  private onNetworkChanged(online: boolean): void {
    const wasOffline: boolean = !this.networkOnline;
    this.networkOnline = online;
    if (!online) {
      if (!this.feedFromCache) {
        this.statusLine = this.offlineStatusLine(this.lastFeedAt);
      }
      return;
    }
    if (!wasOffline) {
      return;
    }
    // The connection is back: re-read the feed and let the capsule announce
    // what the people the reader follows posted while it was gone.
    this.checkFollowUpdates();
  }

  private checkFollowUpdates(): void {
    if (this.loading || this.homeRefreshInFlight) {
      return;
    }
    this.refreshTimelineWithIndicator().catch((): void => {
    });
  }

  // Unique authors behind a batch of fresh posts, newest first. The capsule
  // caps how many of them it draws.
  private authorsOf(posts: Tweet[]): TweetAuthor[] {
    const seen: Set<string> = new Set();
    const authors: TweetAuthor[] = [];
    for (let i: number = 0; i < posts.length; i++) {
      const author: TweetAuthor = posts[i].author;
      if (seen.has(author.id)) {
        continue;
      }
      seen.add(author.id);
      authors.push(author);
    }
    return authors;
  }

  private async loadTimeline(): Promise<void> {
    this.loading = true;
    try {
      const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      await authStore.load(ctx);
      this.api.setToken(authStore.getToken());
      this.api.setUser(authStore.getUserId());
      this.xPrivate.load(ctx);
      this.hasCookieSession = this.xPrivate.isSignedIn();
      this.handleText = authStore.getUsername().length > 0 ? '@' + authStore.getUsername() : '';
      await this.fetchPosts();
      await this.loadSupportingData();
      this.saveCurrentFeedSnapshot();
    } finally {
      this.loading = false;
      this.refreshing = false;
    }
  }

  // The selected home mode determines the source. Recommended content is never
  // used as an implicit fallback for the Following feed. A public-web preview
  // is available only for the For you surface, never for a user's Following feed.
  private async fetchPosts(refreshing: boolean = false, requestContext: string = 'launch'): Promise<void> {
    const refreshCursor: string = refreshing ? this.timelineTopToken : '';
    const previousNextToken: string = this.timelineNextToken;
    const previousCursorHistory: string[] = this.timelineCursorHistory.slice();
    const requestId: number = ++this.homeTimelineRequestId;
    this.homeRefreshFailed = false;
    this.homeSuggestionGroups = [];
    this.timelineNextToken = '';
    if (!refreshing) { this.timelineTopToken = ''; }
    this.timelineCursorHistory = [];
    this.duplicateTimelinePageCount = 0;
    this.timelineSource = '';
    this.sampleTimelinePage = 0;
    this.hasMoreTimeline = false;
    this.feedFromCache = false;
    let page: TweetPage | null = null;

    const topic: TimelineTopic | null = homeTimelineStore.topicById(this.activeHomeTopicId);
    if (topic !== null) {
      await this.fetchHomeTopicPosts(topic, requestId);
      return;
    }

    // Private-interface path. A cookie session wins over the OAuth path: it is
    // the only source that returns the real For-you or Following timeline
    // instead of a public preview or a rate-limited search fallback.
    if (this.xPrivate.isSignedIn()) {
      page = await this.fetchPrivateTimeline(refreshCursor, refreshing, requestContext);
      if (requestId !== this.homeTimelineRequestId) {
        return;
      }
      if (refreshing && page === null) {
        this.homeRefreshFailed = true;
        this.timelineNextToken = previousNextToken;
        this.timelineCursorHistory = previousCursorHistory;
        this.hasMoreTimeline = previousNextToken.length > 0;
        this.timelineSource = 'private';
        this.liveBadge = '';
        this.statusLine = this.text($r('app.string.status_home_unavailable'));
        return;
      }
      if (page !== null && (page.tweets.length > 0 || refreshing)) {
        if (refreshing) {
          const existing: Tweet[] = this.timeline;
          if (this.homeFeedMode === 0) {
            const seen: Set<string> = new Set<string>(this.seenTweetIdsForTimeline(true));
            page.tweets = page.tweets.filter((tweet: Tweet): boolean => !seen.has(tweet.id));
          }
          page.tweets = this.mergeFreshPosts(page.tweets, existing);
        }
        this.timeline = page.tweets;
        if ((page.topToken ?? '').length > 0) { this.timelineTopToken = page.topToken ?? ''; }
        this.timelineNextToken = refreshing && refreshCursor.length > 0 && previousNextToken.length > 0 ? previousNextToken : page.nextToken;
        if (this.timelineNextToken === previousNextToken) { this.timelineCursorHistory = previousCursorHistory; }
        this.hasMoreTimeline = this.timelineNextToken.length > 0;
        this.timelineSource = 'private';
        this.liveBadge = this.text($r('app.string.status_live_badge'));
        if (this.homeFeedMode === 0) {
          this.statusLine = this.text($r('app.string.status_for_you_live'));
        } else {
          this.statusLine = this.text($r('app.string.status_home_live_prefix')) + this.handleText;
        }
        this.persistFeed();
        return;
      }
      if (!authStore.isSignedIn()) {
        // Nothing came back and there is no second credential to try: the last
        // page this device rendered beats an empty screen.
        if (this.restoreCachedFeed()) {
          return;
        }
        this.timeline = [];
        this.liveBadge = '';
        this.statusLine = page === null ? this.text($r('app.string.status_home_unavailable')) :
          this.text($r('app.string.status_home_empty'));
        return;
      }
    }

    if (authStore.isSignedIn()) {
      if (this.homeFeedMode === 0) {
        this.recommendationSignalsLoaded = false;
        await this.loadRecommendationSignals();
        if (requestId !== this.homeTimelineRequestId) {
          return;
        }
        this.activeRecommendationQuery = this.recommendationSearchQuery();
        page = await this.api.searchRecentPage(this.activeRecommendationQuery);
        if (requestId !== this.homeTimelineRequestId) {
          return;
        }
        if (page !== null && page.tweets.length > 0) {
          this.timelineSource = 'recommend';
        }
      } else if (authStore.getUserId().length > 0) {
        page = await this.api.homeTimelinePage(authStore.getUserId());
        if (requestId !== this.homeTimelineRequestId) {
          return;
        }
        if (page !== null && page.tweets.length > 0) {
          this.timelineSource = 'home';
        }
      }
    }
    if (page !== null && page.tweets.length > 0) {
      this.timeline = page.tweets;
      this.timelineNextToken = page.nextToken;
      this.hasMoreTimeline = page.nextToken.length > 0;
      this.liveBadge = this.text($r('app.string.status_live_badge'));
      if (this.homeFeedMode === 0) {
        this.statusLine = this.text($r('app.string.status_for_you_live'));
      } else if (authStore.getUserId().length > 0) {
        this.statusLine = this.text($r('app.string.status_home_live_prefix')) + this.handleText;
      }
      this.persistFeed();
      return;
    }

    if (this.homeFeedMode === 0) {
      const publicPosts: Tweet[] = await this.webClient.fetchStarterTimeline();
      if (requestId !== this.homeTimelineRequestId) {
        return;
      }
      if (publicPosts.length > 0) {
        this.timelineSource = 'public-web';
        this.timeline = publicPosts;
        this.hasMoreTimeline = false;
        this.liveBadge = '';
        this.statusLine = this.text($r('app.string.status_public_web_preview'));
        this.persistFeed();
        return;
      }
    }

    // Every live source declined. Replay the cached page when there is one —
    // this is the path a cold start in a tunnel takes.
    if (this.restoreCachedFeed()) {
      return;
    }

    if (authStore.isSignedIn()) {
      this.timeline = [];
      this.liveBadge = '';
      if (this.homeFeedMode === 0) {
        this.statusLine = this.text($r('app.string.status_for_you_unavailable'));
      } else {
        this.statusLine = page === null ? this.text($r('app.string.status_home_unavailable')) :
          this.text($r('app.string.status_home_empty'));
      }
      return;
    }

    this.timelineSource = 'sample';
    this.timeline = MockData.timelinePage(this.sampleTimelinePage);
    this.hasMoreTimeline = MockData.hasTimelinePage(this.sampleTimelinePage + 1);
    this.liveBadge = '';
    this.statusLine = this.text($r('app.string.status_sample_sign_in'));
  }

  private async homeTopicPage(topic: TimelineTopic, cursor: string, privateSession: boolean): Promise<TweetPage | null> {
    if (privateSession) {
      const result: XPrivateResult = await this.xPrivate.searchTimeline(topic.query, cursor, 20, 'Latest');
      return result.ok ? XTimelineParser.parse(result.body) : null;
    }
    return this.api.searchRecentPage(topic.query, cursor);
  }

  private async fetchHomeTopicPosts(topic: TimelineTopic, requestId: number): Promise<void> {
    let page: TweetPage | null = null;
    let source: string = '';
    if (this.xPrivate.isSignedIn()) {
      page = await this.homeTopicPage(topic, '', true);
      source = 'topic-private';
    }
    if (requestId !== this.homeTimelineRequestId) {
      return;
    }
    if (page === null && authStore.isSignedIn()) {
      page = await this.homeTopicPage(topic, '', false);
      source = 'topic-search';
    }
    if (requestId !== this.homeTimelineRequestId) {
      return;
    }
    if (page !== null) {
      this.timeline = page.tweets;
      this.timelineSource = source;
      this.timelineNextToken = page.nextToken;
      this.hasMoreTimeline = page.nextToken.length > 0;
      this.liveBadge = this.text($r('app.string.status_live_badge'));
      this.statusLine = page.tweets.length > 0 ? this.text(topic.title) : this.text($r('app.string.status_home_empty'));
      this.persistFeed();
    } else if (!this.restoreCachedFeed()) {
      this.timeline = [];
      this.liveBadge = '';
      this.statusLine = this.text($r('app.string.status_home_unavailable'));
    }
  }

  private needsAuth(what: string): boolean {
    // A cookie session is a complete credential for everything except direct
    // messages, so an OAuth token is not required to act.
    if (this.hasAnySession()) {
      return false;
    }
    promptAction.showToast({ message: this.text($r('app.string.toast_sign_in_to_prefix')) + what, duration: 2000 });
    this.openLoginSheet();
    return true;
  }

  private openLoginSheet(): void {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    this.loginAccounts = accountStore.list(context);
    this.loginActiveAccountId = accountStore.activeId(context);
    this.showLoginSheet = true;
  }

  private async startLoginFromSheet(addAccount: boolean): Promise<void> {
    if (addAccount) {
      // AuthWeb verifies the captured identity, so it will not save the active
      // account again if the cookie jar cannot be emptied. Other sites the app
      // loads (Grok web mode) keep their own sessions.
      await xWebCookieBridge.beginFreshXSession();
    }
    this.showLoginSheet = false;
    this.onboardingLoginOnly = true;
    this.onboardingAddAccount = addAccount;
    this.showOnboardingGuide = true;
  }

  private chooseLoginAccount(account: XAccount): void {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    accountStore.setActive(context, account.id);
    xWebCookieBridge.syncAccount(account);
    this.loginActiveAccountId = account.id;
    this.showLoginSheet = false;
  }

  @Builder
  private LoginAccountTile(account: XAccount): void {
    Column({ space: 12 }) {
      Stack({ alignContent: Alignment.Center }) {
        if (account.avatarUrl.length > 0) {
          Image(account.avatarUrl)
            .width(92)
            .height(92)
            .objectFit(ImageFit.Cover)
            .borderRadius(userAvatarRadius(92, 46, account.verifiedType ?? '', account.avatarShape ?? ''))
            .clip(true)
        } else {
          Text(account.initial()).fontFamily(this.appFontFamily)
            .width(92)
            .height(92)
            .fontSize($r('sys.float.Title_L'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_on_accent'))
            .backgroundColor(this.accentColor)
            .borderRadius(userAvatarRadius(92, 46, account.verifiedType ?? '', account.avatarShape ?? ''))
            .textAlign(TextAlign.Center)
        }
        if (account.id === this.loginActiveAccountId) {
          SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
            .fontSize(26)
            .fontColor([verificationBadgeColor(this.profile?.verifiedType ?? '', this.accentColor)])
            .position({ x: 62, y: 62 })
        }
      }
      .width(100)
      .height(100)

      Text(account.title()).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Subtitle_L'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(account.handle()).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('app.color.text_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width(156)
    .height(184)
    .justifyContent(FlexAlign.Center)
    .padding({ left: 12, right: 12, top: 12, bottom: 12 })
    .backgroundColor(this.themedCardSurface())
    .borderRadius(20)
    .onClick((): void => this.chooseLoginAccount(account))
  }

  @Builder
  private LoginAddTile(): void {
    Column({ space: 12 }) {
      SymbolGlyph($r('sys.symbol.plus_circle_fill'))
        .fontSize(54)
        .fontColor([this.accentColor])
      Text($r('app.string.accounts_add')).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Subtitle_L'))
        .fontColor($r('app.color.text_primary'))
      Text($r('app.string.accounts_add_desc')).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_S'))
        .fontColor($r('app.color.text_secondary'))
        .maxLines(2)
        .textAlign(TextAlign.Center)
    }
    .width(156)
    .height(184)
    .justifyContent(FlexAlign.Center)
    .padding({ left: 12, right: 12, top: 12, bottom: 12 })
    .backgroundColor(this.themedCardSurface())
    .borderRadius(20)
    .onClick((): void => { this.startLoginFromSheet(this.loginAccounts.length > 0); })
  }

  @Builder
  private MidAutumnGreetingSheet(): void {
    Column({ space: 0 }) {
      Row() {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(18)
            .fontColor([$r('app.color.text_secondary')])
        }
        .width(36)
        .height(36)
        .backgroundColor(this.themedSecondaryButtonSurface())
        .accessibilityText(this.text($r('app.string.mid_autumn_close')))
        .onClick((): void => {
          this.dismissMidAutumnGreeting();
        })
      }
      .width('100%')
      .justifyContent(FlexAlign.End)

      Column({ space: 8 }) {
        // 三层柔和光晕托一轮满月，纯绘制、不额外引入位图资源。
        Stack({ alignContent: Alignment.Center }) {
          Circle()
            .width(132)
            .height(132)
            .fill($r('app.color.mid_autumn_moon_glow'))
            .opacity(0.35)
          Circle()
            .width(108)
            .height(108)
            .fill($r('app.color.mid_autumn_moon_glow'))
            .opacity(0.6)
          Circle()
            .width(78)
            .height(78)
            .fill($r('app.color.mid_autumn_moon'))
        }
        .width(132)
        .height(132)

        Text($r('app.string.mid_autumn_title')).fontFamily(this.appFontFamily)
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))

        Text($r('app.string.mid_autumn_subtitle')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .margin({ top: 4 })

      Text($r('app.string.mid_autumn_blessing')).fontFamily(this.appFontFamily)
        .width('100%')
        .fontSize($r('sys.float.Body_L'))
        .lineHeight(24)
        .textAlign(TextAlign.Center)
        .fontColor($r('app.color.text_secondary'))
        .margin({ top: 18 })

      Blank()

      Button($r('app.string.mid_autumn_action'), { stateEffect: true })
        .width('100%')
        .height(52)
        .backgroundColor(this.accentColor)
        .fontColor($r('app.color.text_on_accent'))
        .fontSize($r('sys.float.Subtitle_L'))
        .borderRadius(26)
        .onClick((): void => {
          this.dismissMidAutumnGreeting();
        })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 20, right: 20, top: 12, bottom: this.navigationIndicatorHeight + 20 })
  }

  @Builder
  private LoginSheet(): void {
    Column({ space: 18 }) {
      Row() {
        Column({ space: 5 }) {
          Text($r('app.string.login_title')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Title_L'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text(this.loginAccounts.length > 0 ? $r('app.string.accounts_title') :
            $r('app.string.login_description')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('app.color.text_secondary'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(18)
            .fontColor([$r('app.color.text_secondary')])
        }
        .width(40)
        .height(40)
        .backgroundColor(this.themedSecondaryButtonSurface())
        .onClick((): void => { this.showLoginSheet = false; })
      }
      .width('100%')

      List({ space: 12 }) {
        ForEach(this.loginAccounts, (account: XAccount): void => {
          ListItem() {
            this.LoginAccountTile(account)
          }
        }, (account: XAccount): string => account.id)
        ListItem() {
          this.LoginAddTile()
        }
      }
      .width('100%')
      .height(194)
      .listDirection(Axis.Horizontal)
      .scrollBar(BarState.Off)

      Button(this.loginAccounts.length > 0 ? $r('app.string.accounts_add') :
        $r('app.string.login_x_account'), { stateEffect: true })
        .width('100%')
        .height(52)
        .backgroundColor(this.accentColor)
        .fontColor($r('app.color.text_on_accent'))
        .fontSize($r('sys.float.Subtitle_L'))
        .borderRadius(26)
        .onClick((): void => { this.startLoginFromSheet(this.loginAccounts.length > 0); })
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 24, bottom: this.navigationIndicatorHeight + 20 })
  }

  private collectFreshPosts(incoming: Tweet[], current: Tweet[]): Tweet[] {
    const currentIds: Set<string> = new Set();
    const fresh: Tweet[] = [];
    for (let i: number = 0; i < current.length; i++) {
      currentIds.add(current[i].id);
    }
    for (let i: number = 0; i < incoming.length; i++) {
      if (!currentIds.has(incoming[i].id)) {
        fresh.push(incoming[i]);
      }
    }
    return fresh;
  }

  private mergeFreshPosts(fresh: Tweet[], current: Tweet[]): Tweet[] {
    const seen: Set<string> = new Set();
    const merged: Tweet[] = [];
    for (let i: number = 0; i < fresh.length; i++) {
      if (!seen.has(fresh[i].id)) {
        seen.add(fresh[i].id);
        merged.push(fresh[i]);
      }
    }
    for (let i: number = 0; i < current.length; i++) {
      if (!seen.has(current[i].id)) {
        seen.add(current[i].id);
        merged.push(current[i]);
      }
    }
    return merged;
  }

  private async refreshTimelineWithIndicator(offerAtTop: boolean = false, requestContext: string = ''): Promise<void> {
    const previous: Tweet[] = this.copyTweets(this.timeline);
    const previousOffset: number = this.currentHomeOffset();
    const previousPending: Tweet[] = this.pendingNewPosts.slice();
    const snapshot: HomeFeedSnapshot = this.activeFeedSnapshot();
    const request: Promise<void> = this.fetchPosts(true, requestContext);
    const requestId: number = this.homeTimelineRequestId;
    hilog.info(0xFF00, 'HarmonyX-Home', 'refresh start request=%{public}d mode=%{public}d previous=%{public}d offerAtTop=%{public}s',
      requestId, this.homeFeedMode, previous.length, offerAtTop.toString());
    await request;
    if (requestId !== this.homeTimelineRequestId || snapshot !== this.activeFeedSnapshot()) {
      hilog.info(0xFF00, 'HarmonyX-Home', 'refresh superseded request=%{public}d current=%{public}d',
        requestId, this.homeTimelineRequestId);
      return;
    }
    const incoming: Tweet[] = this.copyTweets(this.timeline);
    if (this.feedFromCache || this.homeRefreshFailed) {
      // The re-read never reached X, so the page already on screen is at least
      // as fresh as the cache and there is nothing to offer.
      this.timeline = previous;
      this.pendingNewPosts = previousPending;
      this.pendingAuthors = this.authorsOf(previousPending);
      if (this.feedFromCache) { this.statusLine = this.offlineStatusLine(this.lastFeedAt); }
      this.saveCurrentFeedSnapshot();
      return;
    }
    if ((offerAtTop || previousOffset > 96) && previous.length > 0 && incoming.length > 0) {
      const fresh: Tweet[] = this.collectFreshPosts(incoming, previous);
      if (fresh.length > 0) {
        this.pendingNewPosts = this.mergeFreshPosts(fresh, previousPending);
        this.pendingAuthors = this.authorsOf(this.pendingNewPosts);
        this.timeline = previous;
      } else {
        this.pendingNewPosts = previousPending;
        this.pendingAuthors = this.authorsOf(previousPending);
        this.timeline = previous;
      }
    } else {
      this.pendingNewPosts = [];
      this.pendingAuthors = [];
    }
    hilog.info(0xFF00, 'HarmonyX-Home', 'refresh finish request=%{public}d incoming=%{public}d pending=%{public}d',
      requestId, incoming.length, this.pendingNewPosts.length);
    this.saveCurrentFeedSnapshot();
  }

  private revealPendingPosts(): void {
    if (this.pendingNewPosts.length === 0) {
      return;
    }
    const merged: Tweet[] = this.mergeFreshPosts(this.pendingNewPosts, this.timeline);
    hilog.info(0xFF00, 'HarmonyX-Home', 'capsule reveal mode=%{public}d pending=%{public}d',
      this.homeFeedMode, this.pendingNewPosts.length);
    this.timeline = merged;
    this.pendingNewPosts = [];
    this.pendingAuthors = [];
    this.scrollDepth = 0;
    this.fabMode = 'compose';
    this.fabHidden = false;
    this.setHomeHeaderCollapsed(false);
    this.jumpToNewestPost();
    this.saveCurrentFeedSnapshot();
  }

  private onRefresh(jumpToLatest: boolean = false, requestContext: string = ''): void {
    // Refresh may set the bound `refreshing` state before this callback runs,
    // so keep the business-level reentry guard separate from the UI flag.
    if (this.loading) {
      this.refreshing = false;
      return;
    }
    if (this.homeRefreshInFlight) {
      return;
    }
    this.homeRefreshInFlight = true;
    this.refreshing = true;
    const feedMode: number = this.homeFeedMode;
    const topicId: string = this.activeHomeTopicId;
    this.refreshTimelineWithIndicator(!jumpToLatest, requestContext).then(async (): Promise<void> => {
      if (jumpToLatest && this.currentTab === HOME_TAB_INDEX && this.navPathStack.size() === 0 &&
        this.homeFeedMode === feedMode && this.activeHomeTopicId === topicId && !this.feedFromCache && !this.homeRefreshFailed) {
        if (this.pendingNewPosts.length > 0) { this.revealPendingPosts(); }
        else { this.jumpToNewestPost(); }
      }
      await this.loadSupportingData();
      this.homeRefreshInFlight = false;
      this.refreshing = false;
    }).catch((): void => {
      this.homeRefreshInFlight = false;
      this.refreshing = false;
    });
  }

  // Pull-to-refresh for the Me tab. X recomputes the profile header (avatar,
  // banner, counts) separately from the first page of the user's own posts, so
  // a manual refresh reads both again and rewrites the cached account identity
  // that the switcher and the title bar read from.
  private onMeRefresh(): void {
    if (this.meRefreshInFlight) {
      return;
    }
    this.meRefreshInFlight = true;
    this.meRefreshing = true;
    this.refreshMe().then((): void => {
      this.meRefreshInFlight = false;
      this.meRefreshing = false;
    }).catch((): void => {
      this.meRefreshInFlight = false;
      this.meRefreshing = false;
    });
  }

  private async refreshMe(): Promise<void> {
    await this.refreshOwnProfile();
    if (this.hasAnySession()) {
      if (this.meTimelineTab === 1) {
        await this.loadLikedPosts(true);
      } else {
        await this.loadOwnPosts(true);
      }
    }
  }

  private async refreshOwnProfile(): Promise<void> {
    if (!this.hasAnySession()) {
      this.profile = null;
      return;
    }

    if (this.xPrivate.isSignedIn()) {
      const viewerId: string = this.xPrivate.viewerId();
      if (viewerId.length === 0) {
        return;
      }
      const result: XPrivateResult = await this.xPrivate.userByRestId(viewerId);
      const fresh: UserProfile | null = result.ok ? XUserParser.parse(result.body) : null;
      if (fresh !== null) {
        this.profile = fresh;
        this.cacheAccountProfile();
      }
      return;
    }

    const fresh: UserProfile | null = await this.api.profile();
    if (fresh !== null) {
      this.profile = fresh;
      this.cacheAccountProfile();
    }
  }

  // X supplies personalized trends for the signed-in account. The profile
  // description is a secondary explicit-interest signal when it contains a
  // hashtag. These are collected before the For You query is issued.
  private async loadRecommendationSignals(): Promise<void> {
    if (!this.hasAnySession()) {
      this.profile = null;
      this.trends = MockData.trends();
      return;
    }

    // Private session first: it supplies the real Explore trends and the
    // signed-in user's own profile. Without this the search tab silently fell
    // back to sample topics for cookie-only accounts.
    if (this.xPrivate.isSignedIn()) {
      const viewerId: string = this.xPrivate.viewerId();
      if (viewerId.length > 0) {
        const profileResult: XPrivateResult = await this.xPrivate.userByRestId(viewerId);
        const privateProfile = profileResult.ok ? XUserParser.parse(profileResult.body) : null;
        if (privateProfile !== null) {
          this.profile = privateProfile;
          this.cacheAccountProfile();
        }
      }
      const exploreResult: XPrivateResult = await this.xPrivate.explorePage('');
      if (exploreResult.ok) {
        this.exploreSections = XExploreParser.parseSections(exploreResult.body);
        const privateTrends: string[] = XExploreParser.parseTrends(exploreResult.body);
        if (privateTrends.length > 0) {
          this.trends = privateTrends;
        }
        const initialSection: XExploreSection | null = this.exploreSectionById('explore');
        if (initialSection !== null) {
          await this.loadExploreSection(initialSection);
        }
      }
      if (this.exploreSections.length === 0 || this.trends.length === 0) {
        const trendsResult: XPrivateResult = await this.xPrivate.explore();
        if (trendsResult.ok) {
          const privateTrends: string[] = XExploreParser.parseTrends(trendsResult.body);
          if (privateTrends.length > 0) {
            this.trends = privateTrends;
          }
        }
      }
      this.exploreHomeStatus = this.trends.length > 0 ? this.text($r('app.string.status_live_trends')) :
        this.text($r('app.string.status_live_data_unavailable'));
      this.recommendationSignalsLoaded = true;
      return;
    }

    this.profile = await this.api.profile();
    this.cacheAccountProfile();
    const liveTrends: string[] | null = await this.api.personalizedTrends();
    this.trends = liveTrends === null ? [] : liveTrends;
    this.recommendationSignalsLoaded = true;
  }

  private recommendationSearchQuery(): string {
    for (let i: number = 0; i < this.trends.length; i++) {
      const trend: string = this.trends[i].trim();
      if (trend.length > 0) {
        return trend + ' -is:retweet';
      }
    }

    const bioTag: string = this.profileInterestTag();
    if (bioTag.length > 0) {
      return bioTag + ' -is:retweet';
    }

    // Recent Search requires a standalone search term. This only applies to
    // cold-start accounts with neither personalized trends nor interest tags.
    return 'news -is:retweet';
  }

  // Keeps the account switcher's label and avatar in step with the profile that
  // was just loaded. Cosmetic only: it must not bump the account counter, or
  // loading a profile would trigger another feed reload.
  private cacheAccountProfile(): void {
    if (this.profile === null) {
      return;
    }
    const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const activeId: string = accountStore.activeId(ctx);
    if (activeId.length === 0) {
      return;
    }
    const avatarUrl: string = this.profile.avatarUrl === undefined ? '' : this.profile.avatarUrl;
    accountStore.updateProfile(ctx, activeId, this.profile.name, this.profile.username, avatarUrl, this.profile.verifiedType ?? '', this.profile.avatarShape ?? '');
  }

  private profileInterestTag(): string {
    if (this.profile === null) {
      return '';
    }
    const description: string = this.profile.description;
    const tagStart: number = description.indexOf('#');
    if (tagStart < 0 || tagStart >= description.length - 1) {
      return '';
    }

    let tag: string = '#';
    for (let i: number = tagStart + 1; i < description.length && tag.length < 50; i++) {
      const character: string = description.charAt(i);
      if (!this.isInterestTagCharacter(character)) {
        break;
      }
      tag += character;
    }
    return tag.length > 1 ? tag : '';
  }

  private isInterestTagCharacter(character: string): boolean {
    const code: number = character.charCodeAt(0);
    return (code >= 48 && code <= 57) || (code >= 65 && code <= 90) ||
      (code >= 97 && code <= 122) || code === 95 || (code >= 0x4E00 && code <= 0x9FFF);
  }

  // Keep offline samples for signed-out browsing only. Once a user has a
  // token, each secondary surface shows only data returned by X or a clear
  // availability message; it must never look like live data when it is not.
  private async loadSupportingData(): Promise<void> {
    if (!this.hasAnySession()) {
      this.trends = MockData.trends();
      this.notifications = MockData.notifications();
      this.notificationsCursor = '';
      this.notificationsSource = 'sample';
      this.notificationsFetchedAt = Date.now();
      this.hasMoreNotifications = false;
      this.messages = MockData.messages();
      this.messagesUnread = 0;
      this.unreadMessages = 0;
      this.profile = null;
      this.exploreStatus = this.text($r('app.string.status_sample_sign_in'));
      this.notificationsStatus = '';
      this.messagesStatus = this.text($r('app.string.status_sample_sign_in'));
      return;
    }

    if (!this.recommendationSignalsLoaded) {
      await this.loadRecommendationSignals();
    }

    this.exploreStatus = this.trends.length === 0 ? this.text($r('app.string.status_live_data_unavailable')) :
      this.text($r('app.string.status_live_trends'));

    if (this.notificationAlertsEnabled) {
      await this.loadNotifications(true);
    } else {
      await notificationDeliveryService.clearBadge();
    }

    await this.loadMessages();
  }

  // Private cookie session supplies the inbox. Conversations use the native
  // Chat XDK to recover keys and decrypt signed XChat events on the device.
  private async loadMessages(): Promise<void> {
    if (this.messagesLoading) { return; }
    this.messagesLoading = true;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const accountId: string = accountStore.activeId(context);
    try {
      this.xPrivate.load(context);
      if (this.xPrivate.isSignedIn()) {
        const dmViewerId: string = this.xPrivate.viewerId();
        const dmGeneration: number = this.xPrivate.sessionGeneration();
        const privateResult: XPrivateResult = await this.xPrivate.dmInbox('');
        if (dmGeneration !== this.xPrivate.sessionGeneration() || accountStore.activeId(context) !== accountId) { return; }
        const privatePage: DmInboxPage | null = privateResult.ok ?
          XDmParser.parseInbox(privateResult.body, this.xPrivate.viewerId()) : null;
        if (privatePage !== null) {
          xChatService.cacheInboxProfiles(context, privateResult.body, dmViewerId);
          const decrypted: DirectMessage[] = await xChatService.decryptInbox(context, privateResult.body, privatePage.messages);
          if (dmGeneration !== this.xPrivate.sessionGeneration() || accountStore.activeId(context) !== accountId) { return; }
          this.messages = decrypted;
          xChatActions.applyInboxState(context, this.messages);
          this.messagesFetchedAt = Date.now();
          this.syncMessagesUnread(this.messages);
          this.messagesStatus = '';
          return;
        }
        if (!authStore.isSignedIn() || privateResult.status === 429) {
          this.messagesStatus = privateResult.status === 429 ?
            this.text($r('app.string.dm_rate_limited')) : privateResult.status === 401 || privateResult.status === 403 ?
            this.text($r('app.string.private_session_expired')) :
            this.text($r('app.string.dm_private_unavailable')) + ' HTTP ' + privateResult.status +
            XPrivateClient.explain(privateResult).substring(0, 160);
          return;
        }
      }

      if (authStore.isSignedIn()) {
        const liveMessages: DirectMessage[] | null = await this.api.directMessages();
        if (accountStore.activeId(context) !== accountId) { return; }
        this.messages = liveMessages === null ? [] : liveMessages;
        this.messagesFetchedAt = Date.now();
        this.syncMessagesUnread(this.messages);
        this.messagesStatus = liveMessages === null ?
          this.text($r('app.string.status_dm_scope_required')) :
          this.text($r('app.string.status_live_messages'));
      } else {
        this.messages = [];
        this.syncMessagesUnread(this.messages);
        this.messagesStatus = this.text($r('app.string.status_dm_unsupported'));
      }
    } finally {
      this.messagesLoading = false;
      if (accountStore.activeId(context) !== accountId) { this.loadMessages().catch((): void => {}); }
    }
  }

  // Private session first: it returns X's real notification timeline rather
  // than the mentions-only approximation the official API allows. `reset`
  // starts a new page chain, otherwise the Bottom cursor advances it.
  private async loadNotifications(reset: boolean): Promise<void> {
    if (this.notificationsLoading) {
      return;
    }
    this.notificationsLoading = true;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const accountId: string = accountStore.activeId(context);
    const generation: number = this.xPrivate.sessionGeneration();
    try {
      if (reset) {
        this.notificationsCursor = '';
      }
      if (this.xPrivate.isSignedIn()) {
        const result: XPrivateResult =
          await this.xPrivate.notifications(reset ? '' : this.notificationsCursor, 20);
        if (accountStore.activeId(context) !== accountId || generation !== this.xPrivate.sessionGeneration()) { return; }
        const limitReason: string = NotificationRateLimit.reason(result.status, result.body, result.errorText);
        this.notificationsStatus = limitReason.length > 0 ?
          this.text($r('app.string.notifications_rate_limited')) + ' · ' + limitReason : '';
        const page: XNotificationPage | null = result.ok ?
          XNotificationParser.parsePage(result.body) : null;
        if (page === null) {
          // A failed "more" request keeps the rows already on screen so the
          // reader does not lose their place.
          if (reset) {
            this.notifications = [];
            this.notificationsCursor = '';
            this.hasMoreNotifications = false;
          }
          return;
        }
        const rows: AppNotification[] = reset ? page.items :
          this.appendNotifications(this.notifications, page.items);
        this.notifications = rows;
        this.notificationsCursor = page.cursor;
        this.hasMoreNotifications = page.cursor.length > 0;
        this.notificationsSource = 'private';
        this.notificationsFetchedAt = Date.now();
        if (page.topCursor.length > 0) {
          this.notificationsTopCursor = page.topCursor;
        }
        if (reset) {
          let unread: number = 0;
          for (let i: number = 0; i < page.items.length; i++) {
            if (page.items[i].unread) {
              unread += 1;
            }
          }
          this.notificationsUnread = unread;
          if (unread > 0) {
            this.notificationsSeenMarked = false;
          }
          // Reading the list is what clears the dot, so it only shows while
          // the user is on another tab.
          this.unreadNotifications = this.notificationAlertsEnabled &&
            this.currentTab !== NOTIFICATIONS_TAB_INDEX ? unread : 0;
          this.syncSystemNotifications(page.items, unread);
        }
        return;
      }

      // OAuth fallback: the mentions timeline is the closest API-backed
      // equivalent, and it carries no continuation token.
      this.notificationsCursor = '';
      this.hasMoreNotifications = false;
      this.notificationsSource = 'mentions';
      if (authStore.getUserId().length > 0) {
        const liveMentions: AppNotification[] | null = await this.api.mentions(authStore.getUserId());
        if (accountStore.activeId(context) !== accountId) { return; }
        this.notifications = liveMentions === null ? [] : liveMentions;
        const limitReason: string = this.api.mentionsRateLimitReason();
        this.notificationsStatus = limitReason.length > 0 ?
          this.text($r('app.string.notifications_rate_limited')) + ' · ' + limitReason : '';
      } else {
        this.notifications = [];
        this.notificationsStatus = '';
      }
      this.notificationsFetchedAt = Date.now();
    } finally {
      this.notificationsLoading = false;
      if (accountStore.activeId(context) !== accountId || generation !== this.xPrivate.sessionGeneration()) {
        this.loadNotifications(true).catch((): void => {});
      }
    }
  }

  private async loadNotificationMentions(reset: boolean): Promise<void> {
    if (this.mentionsLoading || !this.xPrivate.isSignedIn() ||
      (!reset && (!this.mentionsHasMore || this.mentionsCursor.length === 0))) { return; }
    this.mentionsLoading = true;
    const requestId: number = ++this.mentionsRequestId;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const accountId: string = accountStore.activeId(context);
    const generation: number = this.xPrivate.sessionGeneration();
    const cursor: string = reset ? '' : this.mentionsCursor;
    try {
      const result: XPrivateResult = await this.xPrivate.notificationMentions(cursor, 20);
      if (requestId !== this.mentionsRequestId || accountStore.activeId(context) !== accountId ||
        generation !== this.xPrivate.sessionGeneration()) { return; }
      const page: XNotificationPage | null = result.ok ? XNotificationParser.parseMentions(result.body) : null;
      hilog.info(0xFF00, 'HarmonyX-Notify', 'mentions timeline HTTP=%{public}d rows=%{public}d more=%{public}s',
        result.status, page?.items.length ?? 0, (page?.cursor.length ?? 0) > 0 ? 'true' : 'false');
      const limitReason: string = NotificationRateLimit.reason(result.status, result.body, result.errorText);
      if (page === null) {
        const detail: string = result.ok ? '' : XPrivateClient.explain(result).substring(0, 160);
        this.mentionsStatus = limitReason.length > 0 ?
          this.text($r('app.string.notifications_rate_limited')) + ' · ' + limitReason :
          this.text($r('app.string.notifications_load_failed')) + (detail.length > 0 ? ' · ' + detail : '');
        // Leave already-read rows in place and require a pull to retry failures.
        this.mentionsHasMore = false;
        return;
      }
      this.mentionsStatus = '';
      this.mentionNotifications = reset ? page.items : this.appendNotifications(this.mentionNotifications, page.items);
      this.mentionsCursor = !reset && page.cursor === cursor ? '' : page.cursor;
      this.mentionsHasMore = this.mentionsCursor.length > 0;
      this.mentionsFetchedAt = Date.now();
    } catch (error) {
      if (requestId === this.mentionsRequestId && accountStore.activeId(context) === accountId &&
        generation === this.xPrivate.sessionGeneration()) {
        this.mentionsStatus = this.text($r('app.string.notifications_load_failed'));
        this.mentionsHasMore = false;
      }
    } finally {
      if (requestId === this.mentionsRequestId) { this.mentionsLoading = false; }
    }
  }

  // The private timeline repeats entries across pages when posts are added
  // between requests, so the id is what keeps the list stable for ForEach.
  private appendNotifications(current: AppNotification[],
    incoming: AppNotification[]): AppNotification[] {
    const seen: Set<string> = new Set();
    const combined: AppNotification[] = [];
    for (let i: number = 0; i < current.length; i++) {
      if (!seen.has(current[i].id)) {
        seen.add(current[i].id);
        combined.push(current[i]);
      }
    }
    for (let i: number = 0; i < incoming.length; i++) {
      if (!seen.has(incoming[i].id)) {
        seen.add(incoming[i].id);
        combined.push(incoming[i]);
      }
    }
    return combined;
  }

  private async loadMoreNotifications(): Promise<void> {
    if (this.loadingMoreNotifications || !this.hasMoreNotifications ||
      this.notificationsCursor.length === 0) {
      return;
    }
    this.loadingMoreNotifications = true;
    try {
      await this.loadNotifications(false);
    } finally {
      this.loadingMoreNotifications = false;
    }
  }

  // onReachEnd can fire repeatedly while the footer stays visible; the loading
  // state guard keeps that to one request per cursor.
  private requestMoreNotifications(): void {
    if (this.usesPrivateMentions()) {
      this.loadNotificationMentions(false).catch((): void => {});
      return;
    }
    this.loadMoreNotifications().then((): void => {
    });
  }

  private onNotificationsRefresh(): void {
    if (this.notificationsSource === 'sample') {
      this.notificationsRefreshing = false;
      return;
    }
    this.notificationsRefreshing = true;
    const loading: Promise<void> = this.usesPrivateMentions() ?
      this.loadNotificationMentions(true) : this.loadNotifications(true);
    loading.finally((): void => {
      this.notificationsRefreshing = false;
    });
  }

  // Notifications are viewer-scoped and change while the app is open, so the
  // tab re-reads them whenever it comes back into focus. The freshness window
  // keeps tab flipping from re-requesting on every pass.
  private refreshNotificationsIfStale(): void {
    if (this.notificationsSource === 'sample') {
      return;
    }
    if (this.usesPrivateMentions()) {
      if (this.mentionsFetchedAt === 0 || Date.now() - this.mentionsFetchedAt >= NOTIFICATIONS_FRESH_MS) {
        this.loadNotificationMentions(true).catch((): void => {});
      }
      return;
    }
    if (this.notificationsLoading || !this.hasAnySession()) {
      return;
    }
    if (this.notificationsSource === '') {
      this.loadNotifications(true).then((): void => {
      });
      return;
    }
    if (Date.now() - this.notificationsFetchedAt < NOTIFICATIONS_FRESH_MS) {
      return;
    }
    this.loadNotifications(true).then((): void => {
    });
  }

  // Rows that point at a post open the conversation; rows that only name an
  // account (follows, profile notices) open the profile.
  private openNotification(n: AppNotification): void {
    if (n.kind === 'alert' || (n.targetPosts ?? []).length > 1) {
      const posts: Tweet[] = (n.targetPosts ?? []).slice();
      if (posts.length === 0 && n.targetPostId.length > 0) { posts.push(this.notificationTweet(n)); }
      const param: NotificationPostsRouteParam = { notification: n, posts: posts };
      this.openContentDestination();
      this.navPathStack.pushPath({ name: 'NotificationPosts', param: param });
      return;
    }
    if (n.targetPostId.length > 0) {
      this.openPost(this.notificationTweet(n));
      return;
    }
    if (n.authorUsername.length > 0) {
      const param: UserDetailRouteParam = { author: this.notificationAuthor(n), posts: [] };
      this.openContentDestination();
      this.navPathStack.pushPath({ name: 'UserDetail', param: param });
    }
  }

  // PostDetail re-reads the canonical post by id, so the row only has to carry
  // enough for the first paint.
  private notificationTweet(n: AppNotification): Tweet {
    const posts: Tweet[] = n.targetPosts ?? [];
    const target: Tweet | undefined = posts.find((post: Tweet): boolean => post.id === n.targetPostId);
    if (target !== undefined) { return target; }
    return {
      id: n.targetPostId,
      author: this.notificationAuthor(n),
      text: n.postText,
      createdAt: new Date().toISOString(),
      metrics: { replyCount: 0, repostCount: 0, likeCount: 0, viewCount: 0 },
      liked: false,
      reposted: false
    };
  }

  private notificationAuthor(n: AppNotification): TweetAuthor {
    const name: string = n.authorName.length > 0 ? n.authorName : n.authorUsername;
    return {
      id: n.authorId,
      name: name.length > 0 ? name : 'X',
      username: n.authorUsername,
      avatarColor: this.accentColor,
      avatarUrl: n.authorAvatarUrl, verifiedType: n.authorVerifiedType, avatarShape: n.authorAvatarShape,
      verified: n.fromVerifiedAccount || (n.authorVerifiedType ?? '').length > 0
    };
  }

  private openComposer(initial: string, replyToId: string, replyUser: string,
    parentTweet: Tweet | null = null): void {
    if (this.needsAuth(replyToId.length > 0 ? this.text($r('app.string.action_reply')) :
      this.text($r('app.string.action_post')))) {
      return;
    }
    const profile: UserProfile | null = this.profile;
    const param: ReplyComposerRouteParam = {
      replyToId: replyToId,
      replyToUser: replyUser,
      avatarUrl: profile === null || profile.avatarUrl === undefined ? '' : profile.avatarUrl,
      avatarName: profile === null ? this.text($r('app.string.tab_me')) : profile.name,
      avatarColor: this.accentColor,
      initialText: initial,
      imageUri: '',
      gifUri: '',
      communityId: '',
      communityName: '',
      parentTweet: parentTweet
    };
    const stack: NavPathStack = this.photoOverlayOpen ? this.photoOverlayStack : this.navPathStack;
    if (!this.photoOverlayOpen) { this.openContentDestination(); }
    NavigationGuard.pushPath<ReplyComposerRouteParam>(stack, { name: 'ReplyComposer', param: param },
      (route: ReplyComposerRouteParam): string => route.replyToId);
  }

  private onPostsChanged(): void {
    this.refreshTimelineWithIndicator().catch((): void => {});
    if (this.currentTab === 4) {
      this.refreshMe().catch((): void => {});
    }
  }

  private onNotificationAlertsChanged(): void {
    if (!this.notificationAlertsEnabled) {
      this.unreadNotifications = 0;
      this.unreadMessages = 0;
      this.syncUnreadBadge();
      return;
    }
    if (!this.hasAnySession()) {
      return;
    }
    if (!this.notificationsLoading) {
      this.loadNotifications(true).then((): void => {});
    }
    if (!this.messagesLoading) {
      this.loadMessages().then((): void => {});
    }
  }

  private onForegroundTick(): void {
    if (this.foregroundTick <= 0) {
      return;
    }
    this.refreshNotificationsIfStale();
    this.refreshHomeSpaces();
    this.refreshMessagesIfStale();
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    meowPushService.checkin(context, accountStore.activeId(context)).catch((): void => {});
    if (this.refreshOnForeground && this.currentTab === HOME_TAB_INDEX && this.navPathStack.size() === 0) {
      this.onRefresh(true, 'foreground');
    }
  }

  private onNotificationLaunchRequested(): void {
    if (this.notificationLaunchRequest <= 0) {
      return;
    }
    // Consume the request before navigating. The root page can appear again
    // after a destination closes and must not replay an old notification tap.
    this.notificationLaunchRequest = 0;
    this.goNotifications();
  }

  private onMessageLaunchRequested(): void {
    if (this.messageLaunchRequest <= 0) {
      return;
    }
    this.messageLaunchRequest = 0;
    this.showSideDrawer = false;
    this.showLinkPreview = false;
    this.linkPreviewUrl = '';
    ResponsiveLayout.closeToMain(this.navPathStack);
    this.updateNavigationMode();
    this.goMessages();
  }

  private startNotificationPolling(): void {
    if (this.notificationPollTimer >= 0) {
      return;
    }
    this.notificationPollTimer = setInterval((): void => {
      this.refreshNotificationsInBackground();
    }, NOTIFICATIONS_BACKGROUND_POLL_MS);
  }

  private stopNotificationPolling(): void {
    if (this.notificationPollTimer < 0) {
      return;
    }
    clearInterval(this.notificationPollTimer);
    this.notificationPollTimer = -1;
  }

  private refreshNotificationsInBackground(): void {
    if (!this.chatAlertsEnabled() || !this.hasAnySession()) {
      return;
    }
    if (this.notificationAlertsEnabled && this.currentTab !== NOTIFICATIONS_TAB_INDEX && !this.notificationsLoading) {
      this.loadNotifications(true).then((): void => {});
    }
    if (this.currentTab !== MESSAGES_TAB_INDEX && !this.messagesLoading) {
      this.loadMessages().then((): void => {});
    }
  }

  private syncSystemNotifications(rows: AppNotification[], unread: number): void {
    if (!this.notificationAlertsEnabled) {
      this.unreadNotifications = 0;
      this.syncUnreadBadge();
      return;
    }
    if (this.currentTab === NOTIFICATIONS_TAB_INDEX) {
      this.syncUnreadBadge();
      return;
    }
    if (!this.systemNotificationsEnabled) {
      this.syncUnreadBadge();
      return;
    }
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    notificationDeliveryService.publishUnread(context, rows, unread, this.totalUnreadBadge(),
      this.notificationDndSilent).then((): void => {});
  }

  private syncMessagesUnread(rows: DirectMessage[]): void {
    let unread: number = 0;
    for (let i: number = 0; i < rows.length; i++) {
      unread += Math.max(0, rows[i].unread);
    }
    this.messagesUnread = unread;
    this.unreadMessages = this.chatAlertsEnabled() && this.currentTab !== MESSAGES_TAB_INDEX ? unread : 0;
    this.syncSystemMessages(rows, unread);
  }

  private syncSystemMessages(rows: DirectMessage[], unread: number): void {
    if (!this.chatAlertsEnabled()) {
      this.unreadMessages = 0;
      this.syncUnreadBadge();
      return;
    }
    if (this.currentTab === MESSAGES_TAB_INDEX) {
      const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      notificationDeliveryService.markUnreadMessagesSeen(context, rows);
      this.syncUnreadBadge();
      return;
    }
    if (!this.systemNotificationsEnabled) {
      this.syncUnreadBadge();
      return;
    }
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    notificationDeliveryService.publishUnreadMessages(context, rows, unread, this.totalUnreadBadge(),
      this.notificationDndSilent).then((): void => {});
  }

  private chatAlertsEnabled(): boolean {
    return this.notificationAlertsEnabled || xChatActions.localBoolean(getContext(this) as common.UIAbilityContext, 'only_chat_push', false);
  }

  private totalUnreadBadge(): number {
    return Math.max(0, this.unreadNotifications) + Math.max(0, this.unreadMessages);
  }

  private syncUnreadBadge(): void {
    notificationDeliveryService.updateBadge(this.totalUnreadBadge()).then((): void => {});
  }

  private async loadOwnPosts(reset: boolean): Promise<void> {
    const viewerId: string = this.xPrivate.isSignedIn() ? this.xPrivate.viewerId() : authStore.getUserId();
    if (viewerId.length === 0 || !this.hasAnySession()) {
      this.ownPosts = [];
      this.ownPostsStatus = this.text($r('app.string.status_home_unavailable'));
      this.ownPostsHasMore = false;
      return;
    }
    if (reset) {
      if (this.ownPostsLoading) {
        return;
      }
      this.ownPostsLoading = true;
      this.ownPostsStatus = '';
      this.ownPostsCursor = '';
      this.ownPostsHasMore = false;
    } else {
      if (this.ownPostsLoadingMore || !this.ownPostsHasMore) {
        return;
      }
      this.ownPostsLoadingMore = true;
    }
    try {
      if (this.xPrivate.isSignedIn()) {
        const result: XPrivateResult = await this.xPrivate.userTweets(viewerId, reset ? '' : this.ownPostsCursor, 20);
        if (!result.ok) {
          this.ownPostsStatus = this.text($r('app.string.status_home_unavailable')) + ' HTTP ' + result.status;
          return;
        }
        const page: TweetPage | null = XTimelineParser.parse(result.body);
        if (page === null) {
          this.ownPostsStatus = this.text($r('app.string.status_home_unavailable'));
          return;
        }
        if (reset) {
          this.ownPosts = page.tweets;
        } else {
          const combined: Tweet[] = [];
          for (let i: number = 0; i < this.ownPosts.length; i++) {
            combined.push(this.ownPosts[i]);
          }
          for (let i: number = 0; i < page.tweets.length; i++) {
            let exists: boolean = false;
            for (let j: number = 0; j < combined.length; j++) {
              if (combined[j].id === page.tweets[i].id) {
                exists = true;
                break;
              }
            }
            if (!exists) {
              combined.push(page.tweets[i]);
            }
          }
          this.ownPosts = combined;
        }
        this.ownPostsCursor = page.nextToken;
        this.ownPostsHasMore = page.nextToken.length > 0;
      } else {
        const posts: Tweet[] | null = await this.api.userPosts(viewerId);
        if (posts === null) {
          this.ownPostsStatus = this.text($r('app.string.status_home_unavailable'));
          return;
        }
        this.ownPosts = posts;
        this.ownPostsHasMore = false;
      }
      this.ownPostsLoadedFor = viewerId;
      this.ownPostsStatus = this.ownPosts.length === 0 ? this.text($r('app.string.status_home_empty')) : '';
    } catch (error) {
      this.ownPostsStatus = this.text($r('app.string.status_home_unavailable'));
    } finally {
      this.ownPostsLoading = false;
      this.ownPostsLoadingMore = false;
    }
  }

  private async loadLikedPosts(reset: boolean): Promise<void> {
    const viewerId: string = this.xPrivate.isSignedIn() ? this.xPrivate.viewerId() : authStore.getUserId();
    if (viewerId.length === 0 || !this.hasAnySession()) {
      this.likedPosts = [];
      this.likedPostsStatus = this.text($r('app.string.profile_likes_unavailable'));
      this.likedPostsHasMore = false;
      return;
    }
    if (reset) {
      if (this.likedPostsLoading || this.likedPostsLoadingMore) {
        return;
      }
      this.likedPostsLoading = true;
      this.likedPostsStatus = '';
      this.likedPostsCursor = '';
      this.likedPostsHasMore = false;
    } else {
      if (this.likedPostsLoadingMore || !this.likedPostsHasMore) {
        return;
      }
      this.likedPostsLoadingMore = true;
    }
    try {
      let page: TweetPage | null = null;
      if (this.xPrivate.isSignedIn()) {
        const result: XPrivateResult = await this.xPrivate.userLikes(viewerId,
          reset ? '' : this.likedPostsCursor, 20);
        if (!result.ok) {
          this.likedPostsStatus = this.text($r('app.string.profile_likes_unavailable')) + ' HTTP ' + result.status;
          return;
        }
        page = XTimelineParser.parse(result.body);
      } else {
        page = await this.api.userLikesPage(viewerId, reset ? '' : this.likedPostsCursor);
      }
      if (page === null) {
        this.likedPostsStatus = this.text($r('app.string.profile_likes_unavailable'));
        return;
      }
      for (let i: number = 0; i < page.tweets.length; i++) {
        page.tweets[i].liked = true;
      }
      if (reset) {
        this.likedPosts = page.tweets;
      } else {
        const combined: Tweet[] = [];
        for (let i: number = 0; i < this.likedPosts.length; i++) {
          combined.push(this.likedPosts[i]);
        }
        for (let i: number = 0; i < page.tweets.length; i++) {
          let exists: boolean = false;
          for (let j: number = 0; j < combined.length; j++) {
            if (combined[j].id === page.tweets[i].id) {
              exists = true;
              break;
            }
          }
          if (!exists) {
            combined.push(page.tweets[i]);
          }
        }
        this.likedPosts = combined;
      }
      this.likedPostsCursor = page.nextToken;
      this.likedPostsHasMore = page.nextToken.length > 0;
      this.likedPostsLoadedFor = viewerId;
      this.likedPostsStatus = this.likedPosts.length === 0 ?
        this.text($r('app.string.profile_likes_empty')) : '';
    } catch (error) {
      this.likedPostsStatus = this.text($r('app.string.profile_likes_unavailable'));
    } finally {
      this.likedPostsLoading = false;
      this.likedPostsLoadingMore = false;
    }
  }

  private selectMeTimeline(tab: number): void {
    if (this.meTimelineTab === tab) {
      return;
    }
    this.meTimelineTab = tab;
    this.syncOwnPostsWaterFlowSections();
    this.ensureMeTimelineLoaded(tab);
  }

  private ensureMeTimelineLoaded(tab: number): void {
    const viewerId: string = this.xPrivate.isSignedIn() ? this.xPrivate.viewerId() : authStore.getUserId();
    if (tab === 1) {
      if (viewerId.length > 0 && viewerId !== this.likedPostsLoadedFor) {
        this.loadLikedPosts(true).catch((): void => {});
      }
    } else if (viewerId.length > 0 && viewerId !== this.ownPostsLoadedFor) {
      this.loadOwnPosts(true).catch((): void => {});
    }
  }

  private visibleMeTimelineLoading(index: number = this.meTimelineTab): boolean {
    return index === 1 ? this.likedPostsLoading : this.ownPostsLoading;
  }

  private visibleMeTimelineLoadingMore(index: number = this.meTimelineTab): boolean {
    return index === 1 ? this.likedPostsLoadingMore : this.ownPostsLoadingMore;
  }

  private visibleMeTimelineHasMore(index: number = this.meTimelineTab): boolean {
    return index === 1 ? this.likedPostsHasMore : this.ownPostsHasMore;
  }

  private visibleMeTimelineStatus(index: number = this.meTimelineTab): string {
    return index === 1 ? this.likedPostsStatus : this.ownPostsStatus;
  }

  private loadMoreMeTimeline(index: number = this.meTimelineTab): Promise<void> {
    if (index === 1) {
      return this.loadLikedPosts(false);
    }
    return this.loadOwnPosts(false);
  }

  // True when either credential is present: the OAuth token (official API) or
  // the cookie session (private interface).
  private hasAnySession(): boolean {
    return authStore.isSignedIn() || this.hasCookieSession || this.xPrivate.isSignedIn();
  }

  // The reason for a refused write lives in the payload: X wraps a posting
  // limit in an HTTP 200, so the status alone cannot tell the two apart.
  private privateFailMsg(action: string, result: XPrivateResult): string {
    if (result.status === 401 || result.status === 403) {
      return this.text($r('app.string.private_session_expired'));
    }
    if (result.isWriteLimit()) {
      return action + this.text($r('app.string.action_write_limit'));
    }
    if (result.status === 404) {
      return action + this.text($r('app.string.action_write_refused'));
    }
    if (result.errorText.length > 0) {
      return action + ' · ' + result.errorText;
    }
    return action + this.text($r('app.string.api_unreachable_suffix'));
  }

  private apiFailMsg(action: string): string {
    if (this.api.lastStatus() === 402) {
      return this.text($r('app.string.api_paid_access'));
    }
    return action + this.text($r('app.string.api_unreachable_suffix'));
  }

  private async onLike(t: Tweet, liked: boolean): Promise<boolean> {
    if (!this.hasAnySession()) {
      this.needsAuth(this.text($r('app.string.action_like_posts')));
      return false;
    }
    let ok: boolean = false;
    if (this.xPrivate.isSignedIn()) {
      const result: XPrivateResult = await this.xPrivate.like(t.id, liked);
      if (!result.ok) promptAction.showToast({
        message: this.privateFailMsg(this.text($r('app.string.action_like')), result), duration: 2200
      });
      ok = result.ok;
    } else {
      ok = await this.api.setLike(t.id, liked);
      if (!ok) promptAction.showToast({
        message: this.apiFailMsg(this.text($r('app.string.action_like'))), duration: 2000
      });
    }
    if (ok && !liked) {
      const remaining: Tweet[] = [];
      for (let i: number = 0; i < this.likedPosts.length; i++) {
        if (this.likedPosts[i].id !== t.id) {
          remaining.push(this.likedPosts[i]);
        }
      }
      this.likedPosts = remaining;
      if (remaining.length === 0 && !this.likedPostsHasMore) {
        this.likedPostsStatus = this.text($r('app.string.profile_likes_empty'));
      }
    }
    return ok;
  }

  private async onRepost(t: Tweet, reposted: boolean): Promise<boolean> {
    if (!this.hasAnySession()) {
      this.needsAuth(this.text($r('app.string.action_repost')));
      return false;
    }
    if (this.xPrivate.isSignedIn()) {
      const result: XPrivateResult = await this.xPrivate.repost(t.id, reposted);
      if (!result.ok) promptAction.showToast({
        message: this.privateFailMsg(this.text($r('app.string.action_repost')), result), duration: 2200
      });
      return result.ok;
    }
    const ok: boolean = await this.api.setRepost(t.id, reposted);
    if (!ok) promptAction.showToast({ message: this.apiFailMsg(this.text($r('app.string.action_repost'))), duration: 2000 });
    return ok;
  }

  private onReply(t: Tweet): void {
    this.openComposer('@' + t.author.username + ' ', t.id, t.author.username, t);
    if (this.hasAnySession()) {
      promptAction.showToast({ message: this.text($r('app.string.toast_replying_to')) + t.author.username, duration: 1500 });
    }
  }

  private appendTimeline(posts: Tweet[]): number {
    const combined: Tweet[] = [];
    let addedCount: number = 0;
    for (let i: number = 0; i < this.timeline.length; i++) {
      combined.push(this.timeline[i]);
    }
    for (let i: number = 0; i < posts.length; i++) {
      const candidate: Tweet = posts[i];
      let exists: boolean = false;
      for (let j: number = 0; j < combined.length; j++) {
        if (combined[j].id === candidate.id) {
          exists = true;
          break;
        }
      }
      if (!exists) {
        combined.push(candidate);
        addedCount += 1;
      }
    }
    this.timeline = combined;
    return addedCount;
  }

  // List.onReachEnd can fire repeatedly while the footer stays visible; the
  // Runs one private GraphQL timeline request and decodes it. Returns null on
  // any failure so the caller keeps its existing fallback chain.
  private async fetchPrivateTimeline(cursor: string, refreshing: boolean = false, requestContext: string = ''): Promise<TweetPage | null> {
    const result: XPrivateResult =
      await this.xPrivate.homeTimeline(this.homeFeedMode === 0, cursor, !refreshing && cursor.length > 0 ? 40 : 20,
        this.seenTweetIdsForTimeline(), refreshing, requestContext);
    if (!result.ok) {
      return null;
    }
    const suggestions: FollowDiscoveryData | null = FollowDiscoveryData.parse(result.body);
    spaceSurfaceStore.ingestTimeline(result.body);
    if (suggestions !== null) {
      this.homeSuggestionGroups = cursor.length === 0 ? suggestions.groups :
        [...this.homeSuggestionGroups, ...suggestions.groups.filter((group: FollowSuggestionGroup): boolean =>
          !this.homeSuggestionGroups.some((existing: FollowSuggestionGroup): boolean => existing.id === group.id))];
    }
    return XTimelineParser.parse(result.body);
  }

  // APK rpb/opb/vg4 sends a persistent observation snapshot for For You.
  // Loading a page alone does not make its unviewed tail an impression.
  private seenTweetIdsForTimeline(includeHistory: boolean = false): string[] {
    if (this.homeFeedMode !== 0) { return []; }
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    return includeHistory ? homeSeenTweetStore.observedIds(context) : homeSeenTweetStore.requestIds(context);
  }

  // Search failures carry the upstream status and body, which is what
  // identifies a rejected query shape or an expired session.
  private searchFailureStatus(): string {
    if (this.lastSearchStatus === 200 || this.lastSearchStatus === 0) {
      return this.text($r('app.string.status_search_no_results'));
    }
    let line: string = this.text($r('app.string.status_search_failed')) +
      ' HTTP ' + this.lastSearchStatus;
    if (this.lastSearchError.length > 0) {
      line += ' · ' + this.lastSearchError;
    }
    return line;
  }

  private exploreSectionById(id: string): XExploreSection | null {
    const target: string = id === 'explore' ? 'for_you' : id.toLowerCase();
    for (let i: number = 0; i < this.exploreSections.length; i++) {
      const section: XExploreSection = this.exploreSections[i];
      const candidate: string = section.id.toLowerCase();
      if (candidate === target || candidate.indexOf(target) >= 0 || target.indexOf(candidate) >= 0) {
        return section;
      }
    }
    return null;
  }

  private exploreSectionLabel(id: string): Resource {
    const normalized: string = id.toLowerCase();
    if (normalized.indexOf('news') >= 0) {
      return $r('app.string.explore_category_news');
    }
    if (normalized.indexOf('sport') >= 0) {
      return $r('app.string.explore_category_sports');
    }
    if (normalized.indexOf('entertain') >= 0) {
      return $r('app.string.explore_category_entertainment');
    }
    if (normalized.indexOf('trend') >= 0) {
      return $r('app.string.explore_category_trending');
    }
    return $r('app.string.explore_title');
  }

  private frameIndexes(count: number): number[] {
    const indexes: number[] = [];
    for (let i: number = 0; i < count; i++) {
      indexes.push(i);
    }
    return indexes;
  }

  private selectExploreHomeCategory(id: string): void {
    const index: number = Math.max(0, EXPLORE_CATEGORY_IDS.indexOf(id));
    if (this.exploreHomeCategory === id) {
      try { this.getExploreScroller().scrollToIndex(0, true, ScrollAlign.START); } catch (_error) {}
    } else {
      this.exploreHomeCategory = id;
      this.applyExplorePage(index);
    }
    const section: XExploreSection | null = this.exploreSectionById(id);
    if (section !== null && !this.exploreCategoryPages[index].loading) { this.loadExploreSection(section, id); }
    else if (section === null) {
      this.exploreCategoryPages[index].status = this.text($r('app.string.explore_section_unavailable'));
      this.exploreCategoryPages[index].loaded = true;
      this.exploreCategoryPages = this.exploreCategoryPages.slice();
      this.applyExplorePage(index);
    }
  }

  private prepareExplorePage(index: number): void {
    const page: ExploreCategoryPage = this.exploreCategoryPages[index];
    if (page.loaded || page.loading) { return; }
    const id: string = EXPLORE_CATEGORY_IDS[index];
    const section: XExploreSection | null = this.exploreSectionById(id);
    if (section !== null) { this.loadExploreSection(section, id); }
  }

  private applyExplorePage(index: number): void {
    const page: ExploreCategoryPage = this.exploreCategoryPages[index];
    this.exploreHomeCards = page.cards;
    this.exploreHomePosts = page.posts;
    this.exploreHomeTrends = page.trends;
    this.exploreTrendItems = page.trendItems;
    this.exploreHero = page.hero;
    this.exploreFrameCount = page.frameCount;
    this.exploreHomeNextToken = page.nextToken;
    this.exploreHomeStatus = page.status;
    this.exploreHomeLoading = page.loading;
  }

  private async onExploreHomeRefresh(): Promise<void> {
    if (this.exploreRefreshInFlight) {
      return;
    }
    this.exploreRefreshInFlight = true;
    this.exploreHomeRefreshing = true;
    try {
      // A manual refresh always reads a new server response.
      const section: XExploreSection | null =
        this.exploreSectionById(this.exploreHomeCategory);
      if (section === null) {
        const index: number = this.exploreCategoryIndex();
        this.exploreCategoryPages[index].status = this.text($r('app.string.explore_section_unavailable'));
        this.exploreCategoryPages = this.exploreCategoryPages.slice();
        this.applyExplorePage(index);
        return;
      }
      await this.loadExploreSection(section);
    } finally {
      this.exploreRefreshInFlight = false;
      this.exploreHomeRefreshing = false;
    }
  }

  private async loadExploreSection(section: XExploreSection, id: string = this.exploreHomeCategory): Promise<void> {
    const index: number = Math.max(0, EXPLORE_CATEGORY_IDS.indexOf(id));
    const state: ExploreCategoryPage = this.exploreCategoryPages[index];
    const requestId: number = ++state.requestId;
    const generation: number = this.exploreHomeRequestId;
    state.loading = true;
    state.status = state.cards.length > 0 ? '' : this.text($r('app.string.status_loading'));
    this.exploreCategoryPages = this.exploreCategoryPages.slice();
    if (id === this.exploreHomeCategory) { this.applyExplorePage(index); }
    try {
      const result: XPrivateResult = await this.xPrivate.genericTimelineById(section.timelineId, '', 20);
      if (generation !== this.exploreHomeRequestId || requestId !== state.requestId) { return; }
      if (!result.ok) {
        state.status = this.text($r('app.string.explore_section_failed'));
        return;
      }
      state.cards = XExploreParser.parseTimelineCards(result.body);
      state.trends = XExploreParser.parseTrends(result.body);
      state.trendItems = XExploreParser.parseTrendItems(result.body);
      state.hero = XExploreParser.parseHero(result.body);
      state.frameCount = XExploreParser.parseFrameCount(result.body);
      const page: TweetPage | null = XTimelineParser.parse(result.body);
      state.posts = page === null ? [] : page.tweets;
      state.nextToken = page === null ? '' : page.nextToken;
      state.status = state.cards.length > 0 ? '' : this.text($r('app.string.explore_section_empty'));
    } catch (_error) {
      if (generation === this.exploreHomeRequestId && requestId === state.requestId) {
        state.status = this.text($r('app.string.explore_section_failed'));
      }
    } finally {
      if (generation === this.exploreHomeRequestId && requestId === state.requestId) {
        state.loading = false;
        state.loaded = true;
        this.exploreCategoryPages = this.exploreCategoryPages.slice();
        if (id === this.exploreHomeCategory) { this.applyExplorePage(index); }
      }
    }
  }

  private clearExploreHomePayload(): void {
    this.exploreHomeRequestId++;
    this.exploreCategoryPages = [new ExploreCategoryPage(), new ExploreCategoryPage(), new ExploreCategoryPage(),
      new ExploreCategoryPage(), new ExploreCategoryPage()];
    this.exploreHomePosts = [];
    this.exploreHomeTrends = [];
    this.exploreTrendItems = [];
    this.exploreHomeCards = [];
    this.exploreHero = null;
    this.exploreFrameCount = 0;
    this.exploreHomeNextToken = '';
  }

  // X's search box understands operators, so the sheet's choices are folded
  // into the query the request carries while the field keeps showing what the
  // reader typed. Applied filters are read here, not the sheet's edits.
  private effectiveSearchQuery(rawQuery: string): string {
    let query: string = rawQuery.trim();
    if (query.length === 0) {
      return query;
    }
    if (this.appliedFilterFrom === 'Following') {
      query += ' filter:follows';
    }
    if (this.appliedFilterSince.length > 0) {
      query += ' since:' + this.appliedFilterSince;
    }
    if (this.appliedFilterLanguage === 'Chinese') {
      query += ' lang:zh';
    }
    if (this.appliedFilterActivity === 'Popular') {
      query += ' min_faves:100';
    }
    if (this.appliedFilterExcludeReplies) {
      query += ' -filter:replies';
    }
    return query;
  }

  // X's own operators take plain dates, so the picker only has to hand back
  // the ISO day (YYYY-MM-DD).
  private isoDay(value: Date): string {
    return value.getFullYear().toString() + '-' + this.twoDigit(value.getMonth() + 1) + '-' +
      this.twoDigit(value.getDate());
  }

  private twoDigit(value: number): string {
    return value < 10 ? '0' + value.toString() : value.toString();
  }

  // The calendar dialog for 发布的日期. Picking a day becomes since:<day>.
  private pickPublishDate(): void {
    const today: Date = new Date();
    const selected: Date = this.searchFilterSince.length > 0 ? new Date(this.searchFilterSince) :
      today;
    this.getUIContext().showDatePickerDialog({
      // X only exists since 2006, and a future day would filter everything out.
      start: new Date('2006-03-21'),
      end: today,
      selected: selected,
      onDateAccept: (value: Date): void => {
        this.searchFilterSince = this.isoDay(value);
      }
    });
  }

  private clearPublishDate(): void {
    this.searchFilterSince = '';
  }

  private hasActiveSearchFilters(): boolean {
    return this.appliedFilterFrom !== 'Anyone' || this.appliedFilterSince.length > 0 ||
      this.appliedFilterLanguage !== 'Any' || this.appliedFilterActivity !== 'Any' ||
      this.appliedFilterExcludeReplies;
  }

  // Appended to the "N 条结果" line so the reader can tell the list is filtered
  // when the filter sheet is closed.
  private activeSearchFilterSuffix(): string {
    return this.hasActiveSearchFilters() ?
      this.text($r('app.string.search_filter_active_suffix')) : '';
  }

  // Opening the sheet shows what the current results were fetched with, so a
  // previously dismissed edit cannot look applied.
  private openSearchFilters(): void {
    this.searchFilterFrom = this.appliedFilterFrom;
    this.searchFilterSince = this.appliedFilterSince;
    this.searchFilterLanguage = this.appliedFilterLanguage;
    this.searchFilterActivity = this.appliedFilterActivity;
    this.searchFilterExcludeReplies = this.appliedFilterExcludeReplies;
    this.searchFilterOpen = true;
  }

  private resetSearchFilters(): void {
    this.searchFilterFrom = 'Anyone';
    this.searchFilterSince = '';
    this.searchFilterLanguage = 'Any';
    this.searchFilterActivity = 'Any';
    this.searchFilterExcludeReplies = false;
  }

  private applySearchFilters(): void {
    this.searchTabSnapshots.clear();
    this.appliedFilterFrom = this.searchFilterFrom;
    this.appliedFilterSince = this.searchFilterSince;
    this.appliedFilterLanguage = this.searchFilterLanguage;
    this.appliedFilterActivity = this.searchFilterActivity;
    this.appliedFilterExcludeReplies = this.searchFilterExcludeReplies;
    this.searchFilterOpen = false;
    if (this.activeExploreQuery.length === 0) {
      return;
    }
    // The operators live in the request query, so the page has to be fetched
    // again for 应用 to mean anything.
    this.submitSearch(this.activeExploreQuery, this.activeSearchQuerySource);
    promptAction.showToast({
      message: this.text($r('app.string.search_filter_applied')),
      duration: 1500
    });
  }

  // Same idea for search: the private surface returns X's own result page,
  // while the OAuth path can only offer the rate-limited recent-search API.
  private async searchViaPrivate(query: string, cursor: string): Promise<TweetPage | null> {
    const result: XPrivateResult =
      await this.xPrivate.searchTimeline(this.effectiveSearchQuery(query), cursor, 20, this.searchProduct,
        this.activeSearchQuerySource);
    this.lastSearchStatus = result.status;
    this.lastSearchError = result.ok ? '' : result.body.substring(0, 200);
    if (!result.ok) {
      return null;
    }
    return XTimelineParser.parse(result.body);
  }

  private selectSearchProduct(product: string): void {
    if (this.searchProduct === product) {
      return;
    }
    const previous: SearchTabSnapshot = new SearchTabSnapshot();
    previous.posts = this.copyTweets(this.exploreResults);
    previous.users = this.exploreUsers.slice();
    previous.status = this.exploreStatus;
    this.searchTabSnapshots.set(this.searchProduct, previous);
    this.searchProduct = product;
    this.exploreUsers = [];
    if (this.activeExploreQuery.length > 0) {
      this.submitSearch(this.activeExploreQuery, this.activeSearchQuerySource);
    }
  }

  // The root HdsTabs is intentionally non-scrollable while Home or Explore is
  // visible. Their horizontal gesture owns the first response, then this
  // method advances the root page only after its secondary tabs reach an end.
  private rootTabsAreSwipeEnabled(): boolean {
    return this.currentTab === MESSAGES_TAB_INDEX || (this.currentTab === ME_TAB_INDEX && !this.hasAnySession());
  }

  private swipeStep(offsetX: number): number {
    if (offsetX < 0) {
      return 1;
    }
    if (offsetX > 0) {
      return -1;
    }
    return 0;
  }

  private isIntentionalSecondarySwipe(event: GestureEvent): boolean {
    const horizontalDistance: number = Math.abs(event.offsetX);
    const verticalDistance: number = Math.abs(event.offsetY);
    return horizontalDistance >= SECONDARY_TAB_SWIPE_DISTANCE && horizontalDistance >= verticalDistance * 1.5;
  }

  private switchRootTabByStep(step: number): void {
    const nextVisibleIndex: number = this.bottomBarPageIndex(this.currentTab) + step;
    const enabledPageCount: number = this.countBottomBarPages();
    if (nextVisibleIndex < 0 || nextVisibleIndex >= enabledPageCount) {
      return;
    }
    this.onTabChange(this.bottomBarPageAt(nextVisibleIndex));
  }

  private onHomeTabSwipe(event: GestureEvent): void {
    if (!this.isIntentionalSecondarySwipe(event)) {
      return;
    }
    const step: number = this.swipeStep(event.offsetX);
    if (step === 0) {
      return;
    }
    const activeIndex: number = this.activeHomeTopicId.length === 0 ? this.homeFeedMode :
      this.pinnedHomeTopics.findIndex((topic: TimelineTopic): boolean => topic.id === this.activeHomeTopicId) + 2;
    const nextMode: number = activeIndex + step;
    if (nextMode >= 0 && nextMode <= 1) {
      this.changeHomeFeed(nextMode);
      return;
    }
    if (nextMode >= 2 && nextMode < this.pinnedHomeTopics.length + 2) {
      this.selectHomeTopic(this.pinnedHomeTopics[nextMode - 2]);
      return;
    }
    this.switchRootTabByStep(step);
  }

  private exploreCategoryIndex(): number {
    for (let i: number = 0; i < EXPLORE_CATEGORY_IDS.length; i++) {
      if (EXPLORE_CATEGORY_IDS[i] === this.exploreHomeCategory) {
        return i;
      }
    }
    return 0;
  }

  private onExploreTabSwipe(event: GestureEvent): void {
    if (!this.isIntentionalSecondarySwipe(event)) {
      return;
    }
    const step: number = this.swipeStep(event.offsetX);
    if (step === 0) {
      return;
    }
    const nextIndex: number = this.exploreCategoryIndex() + step;
    if (nextIndex >= 0 && nextIndex < EXPLORE_CATEGORY_IDS.length) {
      this.selectExploreHomeCategory(EXPLORE_CATEGORY_IDS[nextIndex]);
      return;
    }
    this.switchRootTabByStep(step);
  }

  private searchProductIndex(): number {
    for (let i: number = 0; i < SEARCH_PRODUCT_IDS.length; i++) {
      if (SEARCH_PRODUCT_IDS[i] === this.searchProduct) {
        return i;
      }
    }
    return 0;
  }

  private onSearchResultsSwipe(event: GestureEvent): void {
    if (!this.isIntentionalSecondarySwipe(event)) {
      return;
    }
    const step: number = this.swipeStep(event.offsetX);
    if (step === 0) {
      return;
    }
    const nextIndex: number = this.searchProductIndex() + step;
    if (nextIndex >= 0 && nextIndex < SEARCH_PRODUCT_IDS.length) {
      this.selectSearchProduct(SEARCH_PRODUCT_IDS[nextIndex]);
    }
  }

  private async searchPeopleViaPrivate(query: string, cursor: string): Promise<UserListPage | null> {
    const result: XPrivateResult =
      await this.xPrivate.searchTimeline(this.effectiveSearchQuery(query), cursor, 20, 'People',
        this.activeSearchQuerySource);
    this.lastSearchStatus = result.status;
    this.lastSearchError = result.ok ? '' : result.body.substring(0, 200);
    if (!result.ok) {
      return null;
    }
    return XTimelineParser.parseUserList(result.body);
  }

  private openUserRow(row: UserRow): void {
    const author: TweetAuthor = {
      id: row.id,
      name: row.name,
      username: row.username,
      avatarColor: row.avatarColor,
      avatarUrl: row.avatarUrl,
      verified: row.verified, verifiedType: row.verifiedType, avatarShape: row.avatarShape
    };
    const param: UserDetailRouteParam = { author: author, posts: [] };
    this.openContentDestination();
    this.navPathStack.pushPath({ name: 'UserDetail', param: param });
  }

  private async applyRowFollow(row: UserRow, next: boolean): Promise<boolean> {
    if (!this.xPrivate.isSignedIn()) {
      this.needsAuth(this.text($r('app.string.profile_follow_sign_in')));
      return false;
    }
    const result: XPrivateResult = await this.xPrivate.follow(row.id, next);
    if (!result.ok) {
      promptAction.showToast({
        message: this.text($r('app.string.profile_follow_failed')) + ' · HTTP ' + result.status,
        duration: 2000
      });
      return false;
    }
    const updated: UserRow[] = [];
    for (let i: number = 0; i < this.exploreUsers.length; i++) {
      const current: UserRow = this.exploreUsers[i];
      if (current.id === row.id) {
        const copy: UserRow = {
          id: current.id,
          name: current.name,
          username: current.username,
          avatarUrl: current.avatarUrl,
          avatarColor: current.avatarColor,
          verified: current.verified, verifiedType: current.verifiedType, avatarShape: current.avatarShape,
          bio: current.bio,
          following: next,
          followedBy: current.followedBy
        };
        updated.push(copy);
      } else {
        updated.push(current);
      }
    }
    this.exploreUsers = updated;
    return true;
  }

  private onSearchRequested(): void {
    const query: string = this.searchRequest;
    if (query.length === 0) {
      return;
    }
    this.searchRequest = '';
    this.searchText = query;
    this.submitSearch(query);
    this.showSearchResultsPage();
  }

  // state guard ensures one request per cursor and preserves the reader's spot.
  private async loadMoreTimeline(): Promise<void> {
    if (this.loadingMore || !this.hasMoreTimeline) {
      return;
    }
    this.loadingMore = true;
    const requestId: number = this.homeTimelineRequestId;
    try {
      if (this.timelineSource === 'sample') {
        const nextPage: number = this.sampleTimelinePage + 1;
        const samples: Tweet[] = MockData.timelinePage(nextPage);
        this.sampleTimelinePage = nextPage;
        this.hasMoreTimeline = MockData.hasTimelinePage(nextPage + 1);
        this.appendTimeline(samples);
        return;
      }

      if (this.timelineNextToken.length === 0) {
        this.hasMoreTimeline = false;
        return;
      }

      const requestedCursor: string = this.timelineNextToken;
      if (this.timelineCursorHistory.indexOf(requestedCursor) >= 0) {
        this.hasMoreTimeline = false;
        return;
      }

      let page: TweetPage | null = null;
      if (this.timelineSource === 'private') {
        page = await this.fetchPrivateTimeline(requestedCursor);
      } else if (this.timelineSource === 'home') {
        page = await this.api.homeTimelinePage(authStore.getUserId(), requestedCursor);
      } else if (this.timelineSource === 'recommend') {
        page = await this.api.searchRecentPage(this.activeRecommendationQuery, requestedCursor);
      } else if (this.timelineSource === 'topic-private' || this.timelineSource === 'topic-search') {
        const topic: TimelineTopic | null = homeTimelineStore.topicById(this.activeHomeTopicId);
        if (topic !== null) {
          page = await this.homeTopicPage(topic, requestedCursor, this.timelineSource === 'topic-private');
        }
      }
      if (requestId !== this.homeTimelineRequestId) {
        return;
      }
      if (page === null) {
        // Keep the existing cursor so a later reach-end event can retry a
        // transient network failure without discarding already-read posts.
        return;
      }
      this.timelineCursorHistory.push(requestedCursor);
      const addedCount: number = this.appendTimeline(page.tweets);
      if (addedCount === 0) {
        this.duplicateTimelinePageCount += 1;
      } else {
        this.duplicateTimelinePageCount = 0;
      }
      const cursorRepeated: boolean = page.nextToken.length > 0 &&
        this.timelineCursorHistory.indexOf(page.nextToken) >= 0;
      this.timelineNextToken = page.nextToken;
      this.hasMoreTimeline = page.nextToken.length > 0 && !cursorRepeated &&
        this.duplicateTimelinePageCount < MAX_DUPLICATE_TIMELINE_PAGES;
    } finally {
      if (requestId === this.homeTimelineRequestId) {
        this.loadingMore = false;
        this.saveCurrentFeedSnapshot();
      }
    }
  }

  // Some system-navigation shells consume the final edge event from a nested
  // List. Index-based prefetch is a second, earlier signal, so the feed does
  // not rely on onReachEnd alone.
  private requestMoreTimeline(): void {
    this.loadMoreTimeline().then((): void => {
    });
  }

  private changeHomeFeed(mode: number): void {
    if (this.homeFeedMode === mode && this.activeHomeTopicId.length === 0) {
      return;
    }
    this.applyHomeFeedMode(mode);
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    timelineSettingsStore.saveDefaultHomeFeed(context, mode);
  }

  private onDefaultHomeFeedChanged(): void {
    this.applyHomeFeedMode(this.defaultHomeFeedMode);
  }

  private applyHomeFeedMode(mode: number): void {
    if (this.homeFeedMode === mode && this.activeHomeTopicId.length === 0) {
      return;
    }
    this.saveCurrentFeedSnapshot();
    this.activeHomeTopicId = '';
    this.homeFeedMode = mode;
    this.showSelectedHomeFeed();
  }

  private selectHomeTopic(topic: TimelineTopic): void {
    if (this.activeHomeTopicId === topic.id) {
      return;
    }
    this.saveCurrentFeedSnapshot();
    this.activeHomeTopicId = topic.id;
    this.showSelectedHomeFeed();
  }

  private showSelectedHomeFeed(): void {
    this.homeViewportHasAnchor = false;
    this.homeViewportRevision += 1;
    this.homeViewportChanging = false;
    if (this.homeViewportRestoreTimer >= 0) {
      clearTimeout(this.homeViewportRestoreTimer);
      this.homeViewportRestoreTimer = -1;
    }
    this.homeFirstVisibleItem = 0;
    this.homeVisiblePostId = '';
    this.homeTimelineRequestId += 1;
    this.loadingMore = false;
    this.homeSuggestionGroups = [];
    this.pendingNewPosts = [];
    this.pendingAuthors = [];
    this.scrollDepth = 0;
    this.fabMode = 'compose';
    this.fabHidden = false;
    const snapshot: HomeFeedSnapshot = this.activeFeedSnapshot();
    if (snapshot.loaded) {
      this.restoreFeedSnapshot(snapshot);
      this.loading = false;
      return;
    }
    this.timeline = [];
    this.loading = true;
    const request: Promise<void> = this.fetchPosts();
    const requestId: number = this.homeTimelineRequestId;
    request.then((): void => {
      if (requestId !== this.homeTimelineRequestId) {
        return;
      }
      this.saveCurrentFeedSnapshot();
      this.loading = false;
    }).catch((): void => {
      if (requestId === this.homeTimelineRequestId) {
        this.loading = false;
      }
    });
  }

  private appendExploreResults(posts: Tweet[]): void {
    const combined: Tweet[] = [];
    for (let i: number = 0; i < this.exploreResults.length; i++) {
      combined.push(this.exploreResults[i]);
    }
    for (let i: number = 0; i < posts.length; i++) {
      const candidate: Tweet = posts[i];
      let exists: boolean = false;
      for (let j: number = 0; j < combined.length; j++) {
        if (combined[j].id === candidate.id) {
          exists = true;
          break;
        }
      }
      if (!exists) {
        combined.push(candidate);
      }
    }
    this.exploreResults = combined;
  }

  private async loadMoreExploreResults(): Promise<void> {
    if (this.loadingMoreExplore || !this.hasMoreExplore || this.activeExploreQuery.length === 0) {
      return;
    }
    if (this.exploreNextToken.length === 0) {
      this.hasMoreExplore = false;
      return;
    }
    this.loadingMoreExplore = true;
    const requestId: number = this.searchRequestId;
    const query: string = this.activeExploreQuery;
    const cursor: string = this.exploreNextToken;
    try {
      if (this.searchProduct === 'People') {
        const people: UserListPage | null = await this.searchPeopleViaPrivate(query, cursor);
        if (requestId !== this.searchRequestId || query !== this.activeExploreQuery ||
          people === null) {
          return;
        }
        this.exploreNextToken = people.nextToken;
        this.hasMoreExplore = people.nextToken.length > 0;
        const combinedUsers: UserRow[] = [];
        for (let i: number = 0; i < this.exploreUsers.length; i++) {
          combinedUsers.push(this.exploreUsers[i]);
        }
        for (let i: number = 0; i < people.users.length; i++) {
          combinedUsers.push(people.users[i]);
        }
        this.exploreUsers = combinedUsers;
        this.exploreStatus = this.exploreUsers.length + this.text($r('app.string.toast_results_suffix')) +
          this.activeSearchFilterSuffix();
        return;
      }
      let page: TweetPage | null = null;
      if (this.xPrivate.isSignedIn()) {
        page = await this.searchViaPrivate(query, cursor);
      } else {
        page = await this.api.searchRecentPage(this.effectiveSearchQuery(query), cursor);
      }
      if (requestId !== this.searchRequestId || query !== this.activeExploreQuery) {
        return;
      }
      if (page === null) {
        return;
      }
      this.exploreNextToken = page.nextToken;
      this.hasMoreExplore = page.nextToken.length > 0;
      this.appendExploreResults(page.tweets);
      // The header count is the only place the user sees how much arrived, so it
      // has to follow the appended pages instead of freezing at the first one.
      if (page.tweets.length > 0) {
        this.exploreStatus = this.exploreResults.length + this.text($r('app.string.toast_results_suffix')) +
          this.activeSearchFilterSuffix();
      }
    } finally {
      if (requestId === this.searchRequestId) {
        this.loadingMoreExplore = false;
      }
    }
  }

  private requestMoreExploreResults(): void {
    this.loadMoreExploreResults().then((): void => {
    });
  }

  private exploreResultStartIndex(): number {
    let resultStart: number = 2;
    const query: string = this.searchText.trim().toLowerCase();
    for (let i: number = 0; i < this.trends.length; i++) {
      if (query.length === 0 || this.trends[i].toLowerCase().includes(query)) {
        resultStart += 1;
      }
    }
    return resultStart;
  }

  // Posts opened from the timelines use the platform's own page transition.
  // The shared-element "one take" is kept for the reply rows on the post page,
  // where it reads well; everywhere else it fought the feed's own layout work.
  private openPost(tweet: Tweet): void {
    const param: PostDetailRouteParam = { tweet: tweet };
    this.openRootContent({ name: 'PostDetail', param: param }, (existing: Object): boolean => {
      const current: PostDetailRouteParam = existing as PostDetailRouteParam;
      return current.tweet.id === tweet.id;
    });
  }

  private openRootContent(path: NavPathInfo, matches: (param: Object) => boolean = (): boolean => false): void {
    const fullPage: boolean = path.name === 'PostDetail';
    const replaceBranch: boolean = this.isWideScreen() && !this.isDesktopLayout() && !fullPage;
    this.pendingFullPageDestination = fullPage;
    try {
      this.openContentDestination();
      RootContentNavigation.open(this.navPathStack, path, replaceBranch, matches);
    } finally {
      this.pendingFullPageDestination = false;
      this.updateNavigationMode();
    }
  }

  private isVideoLike(media: MediaAttachment): boolean {
    return media.type === 'video';
  }

  private hasPlayableVideo(tweet: Tweet): boolean {
    const attachments: MediaAttachment[] | undefined = tweet.attachments;
    if (attachments === undefined) {
      return false;
    }
    for (let i: number = 0; i < attachments.length; i++) {
      const media: MediaAttachment = attachments[i];
      if (this.isVideoLike(media) && media.mediaUrl.length > 0) {
        return true;
      }
    }
    return false;
  }

  private openVideoFeed(tweet: Tweet, media: MediaAttachment,
    requestedSource: MediaViewerSource | undefined = undefined): void {
    if (!this.hasPlayableVideo(tweet) || media.id.length === 0) { return; }
    videoPlayerHandoff.request(media.id);
    const source: MediaViewerSource | undefined = requestedSource ?? pendingMediaViewerSource.take(media.id);
    const param: VideoFeedRouteParam = {
      tweets: [tweet],
      sourceTweetIds: [...this.timeline, ...this.exploreResults, ...this.ownPosts, ...this.likedPosts]
        .map((post: Tweet): string => post.id),
      index: 0,
      startPlaying: true,
      startMediaId: media.id,
      source: source,
      startPositionSeconds: videoPlaybackPositionStore.positionFor(media.id),
      onLike: (target: Tweet, liked: boolean): Promise<boolean> => this.onLike(target, liked),
      onRepost: (target: Tweet, reposted: boolean): Promise<boolean> => this.onRepost(target, reposted),
      onReply: (target: Tweet): void => this.onReply(target)
    };
    if (source === undefined) { this.openContentDestination(); }
    this.navPathStack.pushPath({ name: 'VideoFeedViewer', param: param }, source === undefined);
  }

  private openUser(tweet: Tweet): void {
    const param: UserDetailRouteParam = { author: tweet.author, posts: this.timeline };
    this.openRootContent({ name: 'UserDetail', param: param }, (existing: Object): boolean => {
      const current: UserDetailRouteParam = existing as UserDetailRouteParam;
      return current.author.id === tweet.author.id && current.author.username === tweet.author.username;
    });
  }

  // Mention spans only know the handle; the profile page resolves the rest.
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
    this.openContentDestination();
    this.navPathStack.pushPath({ name: 'UserDetail', param: param });
  }

  private openSideDrawer(): void {
    this.showSideDrawer = true;
  }

  private openOwnUserList(mode: string): void {
    const current: UserProfile | null = this.profile;
    let userId: string = current === null ? '' : current.id;
    if (userId.length === 0) {
      userId = this.xPrivate.isSignedIn() ? this.xPrivate.viewerId() : authStore.getUserId();
    }
    if (userId.length === 0) {
      promptAction.showToast({
        message: this.text($r('app.string.profile_not_ready')),
        duration: 2000
      });
      return;
    }
    const param: UserListRouteParam = { mode: mode, userId: userId };
    this.openRootContent({ name: 'UserList', param: param }, (existing: Object): boolean => {
      const current: UserListRouteParam = existing as UserListRouteParam;
      return current.mode === mode && current.userId === userId;
    });
  }

  private onLinkPreviewRequested(): void {
    if (this.linkPreviewUrl.length > 0) {
      const target: XLinkTarget | null = classifyXLink(this.linkPreviewUrl);
      if (target?.kind === X_LINK_SPACE) {
        const link: string = this.linkPreviewUrl;
        this.linkPreviewUrl = '';
        this.openIncomingXLink(link);
        return;
      }
      const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      xWebCookieBridge.syncActive(context);
      // The sheet's Web component reads the application level proxy, so the
      // rule is refreshed before the page is created.
      proxyStore.applyToWebStack();
      this.showLinkPreview = true;
    }
  }

  private onExternalLinkRequested(): void {
    const link: string = this.externalLinkRequest;
    if (link.length === 0) {
      return;
    }
    // Consume it first: the sheet and the route push both run asynchronously.
    this.externalLinkRequest = '';
    this.openIncomingXLink(link);
  }

  private onExternalShareRequested(): void {
    if (this.externalShareRequest.length === 0 || this.externalShareBusy) { return; }
    this.openExternalShare().catch((): void => {});
  }

  private async openExternalShare(): Promise<void> {
    const id: string = this.externalShareRequest;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const accountId: string = accountStore.activeId(context);
    const payload: ExternalSharePayload | null = externalShareStore.read(context, id);
    if (payload === null) {
      this.externalShareRequest = '';
      promptAction.showToast({ message: this.text($r('app.string.share_receive_failed')) });
      return;
    }
    this.externalShareBusy = true;
    try {
      let destination: number = -1;
      while (destination < 0) {
        const result: promptAction.ActionMenuSuccessResponse = await promptAction.showActionMenu({
          title: this.text($r('app.string.share_destination')),
          buttons: [{ text: this.text($r('app.string.action_post')), color: '' },
            { text: this.text($r('app.string.messages_title')), color: '' }]
        });
        if (accountStore.activeId(context) !== accountId || this.externalShareRequest !== id) { return; }
        if (result.index === 0 && !externalShareStore.canPost(payload)) {
          promptAction.showToast({ message: this.text($r('app.string.share_post_media_limit')) });
        } else { destination = result.index; }
      }
      if (destination === 1 && !this.xPrivate.isSignedIn()) { this.openLoginSheet(); return; }
      if (destination === 0 && this.needsAuth(this.text($r('app.string.action_post')))) { return; }
      this.externalShareRequest = '';
      this.showSideDrawer = false;
      this.showLinkPreview = false;
      ResponsiveLayout.closeToMain(this.navPathStack);
      this.openContentDestination();
      if (destination === 1) {
        const param: DmComposeRouteParam = { sharedPayload: payload };
        this.navPathStack.pushPath({ name: 'DmCompose', param: param });
      } else {
        const profile: UserProfile | null = this.profile;
        const param: ReplyComposerRouteParam = { replyToId: '', replyToUser: '',
          avatarUrl: profile?.avatarUrl ?? '', verifiedType: profile?.verifiedType, avatarShape: profile?.avatarShape, avatarName: profile?.name ?? '', avatarColor: this.accentColor,
          initialText: '', imageUri: '', gifUri: '', communityId: '', communityName: '', parentTweet: null,
          sharedPayload: payload };
        this.navPathStack.pushPath({ name: 'ReplyComposer', param: param });
      }
    } catch (error) {
      if (this.externalShareRequest === id) { this.externalShareRequest = ''; }
      externalShareStore.discard(context, id);
    } finally {
      this.externalShareBusy = false;
      if (this.externalShareRequest.length > 0 && (this.externalShareRequest !== id || accountStore.activeId(context) !== accountId)) {
        this.onExternalShareRequested();
      }
    }
  }

  private onContinuationRestoreRequested(): void {
    this.restoreContinuationIfRequested();
  }

  private restoreContinuationIfRequested(): void {
    const request: number = this.continuationRestoreRequest;
    if (request <= 0 || request <= this.handledContinuationRestoreRequest) {
      return;
    }
    this.handledContinuationRestoreRequest = request;
    const state: ContinuationState = continuationStore.current();
    if (state.kind === CONTINUATION_KIND_POST) {
      this.resumeContinuedPost(state).then((): void => {
      });
      return;
    }
    if (state.kind === CONTINUATION_KIND_COMPOSER) {
      this.resumeContinuedComposer(state);
    }
  }

  private async resumeContinuedPost(state: ContinuationState): Promise<void> {
    if (state.postId.length === 0) {
      return;
    }
    const tweet: Tweet | null = await this.resolveIncomingPost(state.postId);
    if (tweet === null) {
      return;
    }
    const param: PostDetailRouteParam = {
      tweet: tweet,
      continuationScrollOffset: state.scrollOffset,
      continuationReplySortMode: state.replySortMode
    };
    this.openRootContent({ name: 'PostDetail', param: param }, (existing: Object): boolean => {
      const current: PostDetailRouteParam = existing as PostDetailRouteParam;
      return current.tweet.id === tweet.id;
    });
  }

  private resumeContinuedComposer(state: ContinuationState): void {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const scope: string = state.replyToId.length > 0 ? 'reply_' + state.replyToId : 'compose';
    if (state.draftText.length > 0) {
      composerDraftStore.save(context, scope,
        new ComposerDraft(state.draftText, [], '', '', Date.now()));
    }
    this.openComposer(state.draftText, state.replyToId, state.replyToUser);
  }

  // Post, profile and shared Community links land on native surfaces; other
  // X destinations without a dedicated page open in the in-app web sheet.
  private openIncomingXLink(link: string): void {
    const target: XLinkTarget | null = classifyXLink(link);
    if (target === null) {
      this.showIncomingLinkPreview(link);
      return;
    }
    if (target.kind === X_LINK_POST) {
      this.openIncomingPost(target);
      return;
    }
    if (target.kind === X_LINK_ARTICLE) {
      this.openContentDestination();
      const param: PostArticleRouteParam = { postId: '', article: { id: target.articleId, title: '', previewText: '', coverUrl: '' } };
      this.navPathStack.pushPath({ name: 'PostArticle', param: param }); return;
    }
    if (target.kind === X_LINK_MESSAGES) {
      this.goMessages();
      return;
    }
    if (target.kind === X_LINK_PROFILE) {
      this.openMention(target.handle);
      return;
    }
    if (target.kind === X_LINK_SEARCH) {
      this.searchRequest = target.query;
      this.onSearchRequested();
      return;
    }
    if (target.kind === X_LINK_COMMUNITY) {
      this.openIncomingCommunity(target);
      return;
    }
    if (target.kind === X_LINK_LIST) {
      this.openContentDestination();
      if (target.listId.length === 0) {
        this.navPathStack.pushPath({ name: 'Lists' });
      } else {
        const param: ListTimelineRouteParam = { listId: target.listId, title: '' };
        this.navPathStack.pushPath({ name: 'ListTimeline', param: param });
      }
      return;
    }
    if (target.kind === X_LINK_SPACE) {
      this.openContentDestination();
      if (target.spaceId.length === 0) { this.navPathStack.pushPath({ name: 'Spaces' }); }
      else {
        this.previewFromHomeCapsule = false;
        this.previewSpaceId = target.spaceId; this.showSpacePreview = true;
      }
      return;
    }
    this.showIncomingLinkPreview(target.link);
  }

  private openIncomingCommunity(target: XLinkTarget): void {
    const param: CommunityTimelineRouteParam = {
      communityId: target.communityId,
      title: '',
      description: '',
      memberCount: 0,
      moderatorCount: 0,
      bannerUrl: '',
      joinPolicy: '',
      ruleCount: 0,
      rules: [],
      joined: false
    };
    this.openContentDestination();
    this.navPathStack.pushPath({ name: 'CommunityTimeline', param: param });
  }

  private async openIncomingPost(target: XLinkTarget): Promise<void> {
    const tweet: Tweet | null = await this.resolveIncomingPostWithinBudget(target.postId);
    if (tweet === null) {
      this.showIncomingLinkPreview(target.link);
      return;
    }
    const param: PostDetailRouteParam = { tweet: tweet };
    this.openRootContent({ name: 'PostDetail', param: param }, (existing: Object): boolean => {
      const current: PostDetailRouteParam = existing as PostDetailRouteParam;
      return current.tweet.id === tweet.id;
    });
  }

  // A deleted or protected post can leave the detail request pending, and the
  // reader would be left staring at the feed. The native page therefore only
  // wins when the post arrives inside the budget.
  private async resolveIncomingPostWithinBudget(postId: string): Promise<Tweet | null> {
    const timeout: Promise<Tweet | null> = new Promise<Tweet | null>(
      (resolve: (value: Tweet | null) => void): void => {
        setTimeout((): void => {
          resolve(null);
        }, INCOMING_LINK_RESOLVE_BUDGET_MS);
      });
    return await Promise.race([this.resolveIncomingPost(postId), timeout]);
  }

  // PostDetail keeps the text of the tweet it was routed with and only
  // refreshes counters, so the link has to be resolved into a real post first:
  // a placeholder would render an empty card. When the post cannot be fetched
  // (signed out, deleted, offline) the web sheet still shows the link.
  private async resolveIncomingPost(postId: string): Promise<Tweet | null> {
    if (postId.length === 0) {
      return null;
    }
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    try {
      await authStore.load(context);
      this.xPrivate.load(context);
      if (this.xPrivate.isSignedIn()) {
        const result: XPrivateResult = await this.xPrivate.tweetDetail(postId);
        if (result.ok) {
          const page: TweetPage | null = XTimelineParser.parse(result.body);
          if (page !== null) {
            for (let i: number = 0; i < page.tweets.length; i++) {
              if (page.tweets[i].id === postId) {
                return page.tweets[i];
              }
            }
          }
        }
      }
      if (authStore.isSignedIn()) {
        this.api.setToken(authStore.getToken());
        this.api.setUser(authStore.getUserId());
        return await this.api.tweetById(postId);
      }
    } catch (error) {
      return null;
    }
    return null;
  }

  private showIncomingLinkPreview(link: string): void {
    if (link.length === 0) {
      return;
    }
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    xWebCookieBridge.syncActive(context);
    this.linkPreviewUrl = link;
    this.showLinkPreview = true;
  }

  private onPhotoRequested(): void {
    const raw: string = this.photoRequest;
    if (raw.length === 0) {
      return;
    }
    this.photoRequest = '';
    const separator: number = raw.indexOf('|');
    if (separator < 0) {
      return;
    }
    try {
      const payload: PhotoRequest = JSON.parse(raw.substring(separator + 1)) as PhotoRequest;
      if (payload.urls === undefined || payload.urls.length === 0) {
        return;
      }
      const param: PhotoViewerRouteParam = {
        urls: payload.urls,
        items: payload.items,
        index: payload.index,
        alt: payload.alt,
        transitionPrefix: payload.transitionPrefix,
        source: payload.source,
        tweet: payload.tweet,
        onLike: (target: Tweet, liked: boolean): Promise<boolean> => this.onLike(target, liked),
        onRepost: (target: Tweet, reposted: boolean): Promise<boolean> => this.onRepost(target, reposted),
        onReply: (target: Tweet): void => this.onReply(target)
      };
      if ((this.isDesktopLayout() && this.photoFullscreen) || this.photoOverlayOpen) {
        param.windowOverlay = true;
        this.photoOverlayOpen = true;
        this.photoOverlayStack.pushPath({ name: 'PhotoViewer', param: param }, payload.source === undefined);
      } else {
        if (payload.source === undefined) { this.openContentDestination(); }
        this.navPathStack.pushPath({ name: 'PhotoViewer', param: param }, payload.source === undefined);
      }
    } catch (error) {
      // A malformed request is not worth interrupting the reader for.
    }
  }

  private onVideoRequested(): void {
    const raw: string = this.videoRequest;
    if (raw.length === 0) { return; }
    this.videoRequest = '';
    const separator: number = raw.indexOf('|');
    if (separator < 0) { return; }
    try {
      const request: VideoViewerRequest = JSON.parse(raw.substring(separator + 1)) as VideoViewerRequest;
      const media: MediaAttachment | undefined = request.tweet.attachments?.find(
        (item: MediaAttachment): boolean => item.id === request.mediaId);
      if (media === undefined) { return; }
      videoPlaybackPositionStore.remember(media.id, request.positionSeconds);
      this.openVideoFeed(request.tweet, media, request.source);
    } catch (error) { }
  }

  private loadSearchHistory(): void {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    this.searchHistory = searchHistoryStore.load(context);
  }

  private scrollCurrentToTop(): void {
    this.scrollDepth = 0;
    this.fabMode = 'compose';
    this.fabHidden = false;
    if (this.currentTab === 1) {
      this.getExploreScroller().scrollEdge(Edge.Top);
      return;
    }
    this.getHomeScroller().scrollEdge(Edge.Top);
  }

  // scrollOffset is the per-frame delta: positive when the user swipes up and
  // reads deeper into the feed; negative when the user swipes down toward its
  // top. Home keeps the compose action; double-tapping its tab refreshes it.
  private onFeedScroll(scrollOffset: number): void {
    if (this.currentTab === HOME_TAB_INDEX) { this.rememberHomeVisibleItem(this.homeFirstVisibleItem); }
    if (this.currentTab !== 0 && this.currentTab !== 1) {
      return;
    }
    if (scrollOffset === 0) {
      return;
    }
    // 首页上滑隐藏悬浮按钮、下滑显示；Explore 保留原来的方向。
    // scrollOffset 为正表示内容向上滚动，负值表示内容回到顶部方向滚动。
    const shouldHideFab: boolean = this.currentTab === HOME_TAB_INDEX ? scrollOffset > 0 : scrollOffset < 0;
    this.fabHidden = this.autoHideFab && shouldHideFab;
    try {
      this.scrollDepth = this.currentTab === 1 ?
        Math.max(0, this.getExploreScroller().currentOffset().yOffset) :
        Math.max(0, this.getHomeScroller().currentOffset().yOffset);
    } catch (error) {
      this.scrollDepth = Math.max(0, this.scrollDepth + scrollOffset);
    }
    if (this.currentTab === HOME_TAB_INDEX) {
      if (!this.useTitleBarLogo() || !this.homeHeaderCollapseEnabled || scrollOffset < 0) {
        this.setHomeHeaderCollapsed(false);
      } else {
        this.setHomeHeaderCollapsed(this.scrollDepth > HOME_HEADER_COLLAPSE_DEPTH_VP);
      }
      this.fabMode = 'compose';
    } else if (this.scrollDepth >= FAB_SWITCH_DEPTH) {
      this.fabMode = 'top';
    } else {
      this.fabMode = 'compose';
    }
    this.onChromeScroll(scrollOffset);
  }

  private onFeedScrollStop(): void {
    if (this.currentTab === HOME_TAB_INDEX) { this.rememberHomeVisibleItem(this.homeFirstVisibleItem); }
    this.onChromeScrollStop();
    if (this.currentTab === 0) {
      if (this.currentHomeOffset() <= HOME_HEADER_COLLAPSE_DEPTH_VP) {
        this.setHomeHeaderCollapsed(false);
      }
      this.saveCurrentFeedSnapshot();
    }
  }

  private setHomeHeaderCollapsed(collapsed: boolean): void {
    if (!this.supportsHdsNavigation() || this.homeHeaderCollapsed === collapsed) {
      return;
    }
    this.getUIContext().animateTo({ duration: 280, curve: Curve.EaseInOut }, (): void => {
      this.homeHeaderCollapsed = collapsed;
    });
  }

  private onHomeHeaderCollapseEnabledChanged(): void {
    if (!this.homeHeaderCollapseEnabled) {
      this.setHomeHeaderCollapsed(false);
    }
  }

  // In-app link preview: a half-modal sheet with the system Web component, so
  // reading a linked page never leaves the app.
  @Builder
  private LinkPreviewSheet(): void {
    Column() {
      if (this.linkPreviewUrl.length > 0) {
        Web({ src: this.linkPreviewUrl, controller: this.linkPreviewController })
          .width('100%')
          .layoutWeight(1)
          .javaScriptAccess(true)
          .domStorageAccess(true)
          .darkMode(this.webDarkMode())
          .forceDarkAccess(this.webForceDark())
          // Without an answer here an authenticated proxy turns every page in
          // this sheet into ERR_TUNNEL_CONNECTION_FAILED.
          .onHttpAuthRequest((event): boolean => {
            if (event === undefined || event === null) {
              return false;
            }
            const credential: WebProxyCredential = proxyStore.webCredential();
            if (!credential.usable) {
              event.handler.cancel();
              return false;
            }
            return event.handler.confirm(credential.username, credential.password);
          })
          .onPageEnd((): void => {
            // A page the reader signs into through this sheet keeps its session
            // only if the jar reaches the disk.
            webview.WebCookieManager.saveCookieAsync().then((): void => {
            }).catch((): void => {
            });
          })
          .backgroundColor(this.themedPageSurface())
      }
    }
    .width('100%')
    .height('100%')
  }

  // The app setting decides the Web override: dark and light are explicit, and
  // "system" hands the decision back to the platform.
  private webDarkMode(): WebDarkMode {
    if (this.displayMode === DISPLAY_MODE_DARK) {
      return WebDarkMode.On;
    }
    if (this.displayMode === DISPLAY_MODE_LIGHT) {
      return WebDarkMode.Off;
    }
    return WebDarkMode.Auto;
  }

  // forceDarkAccess only applies while the Web is in dark mode; leaving it on
  // for "system" is what makes pages without dark styles readable at night.
  private webForceDark(): boolean {
    return this.displayMode !== DISPLAY_MODE_LIGHT;
  }

  private themedPageSurface(): ResourceColor {
    return pageSurfaceColor(this.displayMode, this.darkSurface);
  }

  private themedCardSurface(): ResourceColor {
    return cardSurfaceColor(this.displayMode, this.darkSurface);
  }

  private themedFieldSurface(): ResourceColor {
    return fieldSurfaceColor(this.displayMode, this.darkSurface);
  }

  private themedSecondaryButtonSurface(): ResourceColor {
    return secondaryButtonSurfaceColor(this.displayMode, this.darkSurface);
  }

  private themedTitleBarScrim(): ResourceColor {
    return titleBarScrimColor(this.displayMode, this.darkSurface);
  }

  private openSettings(): void {
    this.openRootContent({ name: 'Settings' });
  }

  private openHelpCenter(): void {
    if (!this.isLargeScreen()) {
      this.showSideDrawer = false;
    }
    this.openRootContent({ name: 'HelpCenter' });
  }

  // Account switcher: its own destination, so the list is reachable from the
  // drawer, from Settings and from the Me tab with the same code.
  private openAccounts(): void {
    if (!this.isLargeScreen()) {
      this.showSideDrawer = false;
    }
    this.openRootContent({ name: 'Accounts' });
  }

  private showDrawerFeature(feature: string): void {
    if (!this.isLargeScreen()) {
      this.showSideDrawer = false;
    }
    if (feature === 'history') {
      this.openRootContent({ name: 'BrowsingHistory' });
      return;
    }
    if (feature === 'bookmarks') {
      this.openRootContent({ name: 'Bookmarks' });
      return;
    }
    if (feature === 'lists') {
      this.openRootContent({ name: 'Lists' });
      return;
    }
    if (feature === 'notifications') {
      this.goNotifications();
      return;
    }
    if (feature === 'premium') {
      this.linkPreviewUrl = 'https://x.com/i/premium_sign_up';
      this.showLinkPreview = true;
      return;
    }
    if (feature === 'communities') {
      this.openRootContent({ name: 'Communities' });
      return;
    }
    if (feature === 'spaces') {
      this.openRootContent({ name: 'Spaces' });
      return;
    }
    if (feature === 'studio' && this.isDesktopLayout()) {
      this.openRootContent({ name: 'CreatorStudio' });
      return;
    }
    if (feature === 'studio') {
      this.linkPreviewUrl = 'https://x.com/i/jf/creators/studio';
      this.showLinkPreview = true;
      return;
    }
    promptAction.showToast({ message: feature, duration: 1500 });
  }

  private goNotifications(): void {
    // A system notification may arrive while a profile or post is covering
    // the root tabs. Selecting the tab alone leaves that destination visible.
    this.showLinkPreview = false;
    this.linkPreviewUrl = '';
    if (!this.isLargeScreen()) {
      this.showSideDrawer = false;
    }
    ResponsiveLayout.closeToMain(this.navPathStack);
    this.updateNavigationMode();
    if (!this.isDesktopLayout() && !this.isBottomBarPageEnabled(NOTIFICATIONS_TAB_INDEX)) {
      this.onNotificationsOpened();
      this.refreshNotificationsIfStale();
      this.openContentDestination();
      this.navPathStack.pushPath({ name: 'Notifications' });
      return;
    }
    this.selectRootTabPage(NOTIFICATIONS_TAB_INDEX);
  }

  private goMessages(): void {
    this.selectRootTabPage(MESSAGES_TAB_INDEX);
  }

  private goMe(): void {
    this.showLinkPreview = false;
    this.linkPreviewUrl = '';
    ResponsiveLayout.closeToMain(this.navPathStack);
    this.selectRootTabPage(ME_TAB_INDEX);
  }

  private openConversation(message: DirectMessage): void {
    const conversationId: string = message.conversationId ?? '';
    if (conversationId.length === 0) {
      promptAction.showToast({ message: $r('app.string.dm_legacy_only'), duration: 1800 });
      return;
    }
    if (message.hidden === true) {
      xChatActions.setInboxHidden(getContext(this) as common.UIAbilityContext, conversationId, message.latestSequenceId ?? '', false);
      message.hidden = false;
      this.messages = this.messages.slice();
    }
    const param: DmConversationRouteParam = {
      conversationId: conversationId,
      title: message.from,
      username: message.username ?? '',
      avatarUrl: message.avatarUrl ?? '', verifiedType: message.verifiedType, avatarShape: message.avatarShape,
      group: message.group ?? false,
      participantIds: message.participantIds ?? [],
      latestSequenceId: message.latestSequenceId ?? ''
    };
    if (this.isDesktopLayout()) {
      while (this.navPathStack.size() > 0) { this.navPathStack.pop(false); }
    }
    this.navPathStack.pushPath({ name: 'DmConversation', param: param });
  }

  private openChatComposer(): void {
    if (!this.xPrivate.isSignedIn()) { this.openLoginSheet(); return; }
    this.navPathStack.pushPath({ name: 'DmCompose' });
  }

  private chatFilterTitle(): Resource {
    if (this.chatFilter === 'unread') { return $r('app.string.chat_unread'); }
    if (this.chatFilter === 'direct') { return $r('app.string.chat_direct'); }
    if (this.chatFilter === 'groups') { return $r('app.string.chat_groups'); }
    return $r('app.string.chat_all');
  }

  private visibleChats(): DirectMessage[] {
    const query: string = this.chatSearch.trim().toLowerCase();
    return this.messages.filter((message: DirectMessage): boolean => {
      if (message.hidden === true && query.length === 0) { return false; }
      if (this.chatFilter === 'unread' && message.unread === 0) { return false; }
      if (this.chatFilter === 'direct' && message.group === true) { return false; }
      if (this.chatFilter === 'groups' && message.group !== true) { return false; }
      return query.length === 0 || message.from.toLowerCase().indexOf(query) >= 0 ||
        (message.username ?? '').toLowerCase().indexOf(query) >= 0 || message.preview.toLowerCase().indexOf(query) >= 0;
    }).sort((left: DirectMessage, right: DirectMessage): number => {
      if (left.pinned === true && right.pinned !== true) { return -1; }
      if (left.pinned !== true && right.pinned === true) { return 1; }
      return (right.timestampMs ?? 0) - (left.timestampMs ?? 0);
    });
  }

  private async markAllChats(): Promise<void> {
    if (this.markingChats) { return; }
    if (!xChatService.isUnlocked() && this.messages.some((row: DirectMessage): boolean => row.unread > 0)) {
      this.requestChatUnlock((): void => { this.markAllChats(); }); return;
    }
    this.markingChats = true;
    const rows: DirectMessage[] = this.messages.slice();
    try {
      for (let i: number = 0; i < rows.length; i++) {
        const message: DirectMessage = rows[i];
        if (message.unread > 0 && (message.conversationId ?? '').length > 0) {
          await xChatService.markRead(message.conversationId ?? '', message.latestSequenceId ?? '', getContext(this) as common.UIAbilityContext);
          message.unread = 0;
        }
      }
      this.messages = this.messages.slice();
      this.syncMessagesUnread(this.messages);
    } catch (error) { promptAction.showToast({ message: this.text($r('app.string.chat_action_failed')) }); }
    finally { this.markingChats = false; this.refreshMessages(); }
  }

  @Builder
  private ChatConversationMenu(message: DirectMessage): void {
    Menu() {
      MenuItem({ content: message.unread > 0 ? $r('app.string.chat_mark_read') : $r('app.string.chat_mark_unread'),
        symbolStartIcon: new SymbolGlyphModifier(message.unread > 0 ? $r('sys.symbol.checkmark') : $r('sys.symbol.envelope_badge_dot')) })
        .enabled(!this.markingChats).onClick((): void => { this.queueChatAction(message, 'read'); })
      MenuItem({ content: message.hidden === true ? $r('app.string.chat_unhide') : $r('app.string.chat_hide'),
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.bell_slash')) })
        .enabled(!this.markingChats).onClick((): void => { this.queueChatAction(message, 'hide'); })
      MenuItem({ content: message.pinned === true ? $r('app.string.chat_unpin_conversation') : $r('app.string.chat_pin_conversation'),
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.pin')) })
        .enabled(!this.markingChats).onClick((): void => { this.queueChatAction(message, 'pin'); })
      MenuItem({ content: $r('app.string.chat_delete'), symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.trash')).fontColor([$r('app.color.danger')]) })
        .contentFontColor($r('app.color.danger')).enabled(!this.markingChats)
        .onClick((): void => { this.queueChatAction(message, 'delete'); })
    }
  }

  private queueChatAction(message: DirectMessage, kind: string): void {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const account: string = xPrivateStore.load(context).cacheIdentity();
    this.afterChatMenuDismiss = (): void => {
      if (account === xPrivateStore.load(context).cacheIdentity()) { this.chatConversationAction(message, kind); }
    };
  }

  private chatMenuDismissed(): void {
    const action: (() => void) | null = this.afterChatMenuDismiss;
    this.afterChatMenuDismiss = null;
    if (action !== null) { action(); }
  }

  private requestChatUnlock(action: () => void): void {
    const account: string = xPrivateStore.load(getContext(this) as common.UIAbilityContext).cacheIdentity();
    if (account !== this.chatUnlockAccount) { this.chatUnlockAttempts = -1; }
    this.chatUnlockAccount = account;
    this.chatUnlockSucceeded = false;
    this.afterChatUnlock = action;
    this.chatUnlockError = '';
    this.showChatUnlock = true;
  }

  private async unlockChat(pin: string): Promise<void> {
    if (this.chatUnlocking || this.chatUnlockAttempts === 0) { return; }
    this.chatUnlocking = true;
    this.chatUnlockError = '';
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const account: string = this.chatUnlockAccount;
    try {
      await xChatService.prepare(context, []);
      if (!this.showChatUnlock || account !== xPrivateStore.load(context).cacheIdentity()) { return; }
      await xChatService.unlock(pin);
      if (!this.showChatUnlock || account !== xPrivateStore.load(context).cacheIdentity()) { return; }
      // Hydrate verified conversation keys before the deferred read receipt.
      await this.loadMessages();
      if (!this.showChatUnlock || account !== xPrivateStore.load(context).cacheIdentity()) { return; }
      this.chatUnlockSucceeded = true;
      this.showChatUnlock = false;
    } catch (error) {
      if (account !== xPrivateStore.load(context).cacheIdentity()) { return; }
      const reason: string = (error as Error).message;
      const budget: RegExpMatchArray | null = reason.match(/guesses_remaining=(\d+)/);
      if (budget !== null) { this.chatUnlockAttempts = parseInt(budget[1], 10); }
      this.chatUnlockError = this.text(this.chatUnlockAttempts === 0 ? $r('app.string.dm_pin_exhausted') :
        reason.indexOf('InvalidPin') >= 0 || reason.indexOf('Invalid PIN') >= 0 ?
          $r('app.string.dm_pin_incorrect') : $r('app.string.dm_unlock_failed'));
    } finally { this.chatUnlocking = false; }
  }

  private chatUnlockDismissed(): void {
    this.showChatUnlock = false;
    const action: (() => void) | null = this.afterChatUnlock;
    this.afterChatUnlock = null;
    const succeeded: boolean = this.chatUnlockSucceeded;
    this.chatUnlockSucceeded = false;
    if (succeeded && action !== null && xChatService.isUnlocked() && this.chatUnlockAccount ===
      xPrivateStore.load(getContext(this) as common.UIAbilityContext).cacheIdentity()) { action(); }
  }

  @Builder
  private ChatUnlockSheet(): void {
    ChatPinPad({ busy: this.chatUnlocking, error: this.chatUnlockError,
      onSubmit: (pin: string): void => { this.unlockChat(pin); },
      onClose: (): void => { this.afterChatUnlock = null; this.showChatUnlock = false; } })
  }

  private async chatConversationAction(message: DirectMessage, kind: string): Promise<void> {
    const id: string = message.conversationId ?? '';
    if (id.length === 0 || this.markingChats) { return; }
    if (!xChatService.isUnlocked() && (kind === 'delete' || (kind === 'read' && message.unread > 0))) {
      this.requestChatUnlock((): void => { this.chatConversationAction(message, kind); }); return;
    }
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const account: string = xPrivateStore.load(context).cacheIdentity();
    if (kind === 'delete') {
      const result: promptAction.ShowDialogSuccessResponse = await promptAction.showDialog({
        message: this.text($r('app.string.chat_delete_confirm')),
        buttons: [{ text: this.text($r('app.string.compose_cancel')), color: '' },
          { text: this.text($r('app.string.chat_delete')), color: '' }]
      });
      if (result.index !== 1 || account !== xPrivateStore.load(context).cacheIdentity()) { return; }
    }
    this.markingChats = true;
    try {
      if (kind === 'read') {
        if (message.unread > 0) { await xChatService.markRead(id, message.latestSequenceId ?? '', context); }
        else { xChatActions.markUnread(context, id, message.latestSequenceId ?? ''); }
      } else if (kind === 'pin') { xChatActions.saveLocal(context, 'pinned:' + id, message.pinned !== true); }
      else if (kind === 'hide') { xChatActions.setInboxHidden(context, id, message.latestSequenceId ?? '', message.hidden !== true); }
      else if (kind === 'delete') { await xChatService.deleteConversation(id); }
      if (account !== xPrivateStore.load(context).cacheIdentity()) { return; }
      if (kind === 'delete') { this.messages = this.messages.filter((row: DirectMessage): boolean => row.id !== message.id); }
      xChatActions.applyInboxState(context, this.messages);
      this.messages = this.messages.slice();
      this.syncMessagesUnread(this.messages);
    } catch (error) {
      hilog.warn(0xFF00, 'HarmonyX-Chat', 'inbox action %{public}s failed: %{public}s', kind, (error as Error).message);
      promptAction.showToast({ message: this.text($r('app.string.chat_action_failed')) });
    }
    finally { this.markingChats = false; this.messagesFetchedAt = 0; }
  }

  @Builder
  private ChatFilterMenu(): void {
    Menu() {
      MenuItem({ content: $r('app.string.chat_all'), symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.message')) }).onClick((): void => { this.chatFilter = 'all'; })
      MenuItem({ content: $r('app.string.chat_unread'), symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.envelope_badge_dot')) }).onClick((): void => { this.chatFilter = 'unread'; })
      MenuItem({ content: $r('app.string.chat_direct'), symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.person')) }).onClick((): void => { this.chatFilter = 'direct'; })
      MenuItem({ content: $r('app.string.chat_groups'), symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.person_2')) }).onClick((): void => { this.chatFilter = 'groups'; })
      MenuItem({ content: $r('app.string.chat_requests'), symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.envelope_badge_arrow_left')) }).onClick((): void => {
        this.navPathStack.pushPath({ name: 'DmRequests' });
      })
      MenuItem({ content: $r('app.string.chat_settings'), symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.gearshape')) }).onClick((): void => {
        const param: DmSettingsRouteParam = { section: '' };
        this.navPathStack.pushPath({ name: 'DmSettings', param: param });
      })
      MenuItem({ content: $r('app.string.chat_mark_all'), symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.checkmark')) }).enabled(!this.markingChats)
        .onClick((): void => { this.markAllChats(); })
    }
  }

  @Builder
  private ChatFilterButton(): void {
    Button({ type: ButtonType.Capsule }) {
      Row({ space: 6 }) {
        Text(this.chatFilterTitle()).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_primary'))
        SymbolGlyph($r('sys.symbol.chevron_down')).fontSize(14).fontColor([$r('app.color.text_primary')])
      }
    }.height(34).padding({ left: 12, right: 12 }).backgroundColor(Color.Transparent)
      .border({ width: this.supportsImmersiveMaterial() ? 0 : 1, color: $r('app.color.divider') })
      .systemMaterial(this.chatFilterMaterialCache.material(this.accentColor)).bindMenu(this.ChatFilterMenu())
  }

  private refreshMessages(): void {
    if (this.messagesRefreshing) {
      return;
    }
    this.messagesRefreshing = true;
    this.loadMessages().then((): void => {
      this.messagesRefreshing = false;
    }).catch((): void => {
      this.messagesRefreshing = false;
    });
  }

  private onChatChanged(): void {
    this.messagesFetchedAt = 0;
    if (this.xPrivate.isSignedIn() && !this.messagesLoading && !this.markingChats) { this.refreshMessages(); }
  }

  private refreshMessagesIfStale(): void {
    if (this.messagesRefreshing) {
      return;
    }
    if (this.messages.length === 0 ||
      Date.now() - this.messagesFetchedAt > MESSAGES_FRESH_MS) {
      this.refreshMessages();
    }
  }

  private onTabChange(index: number): void {
    const changed: boolean = this.currentTab !== index;
    if (index !== HOME_TAB_INDEX) {
      this.lastHomeTabClickAt = 0;
    }
    if (this.currentTab === 0 && index !== 0) {
      this.saveCurrentFeedSnapshot();
    }
    this.currentTab = index;
    this.updateNavigationMode();
    this.scheduleChromeTab(index, changed);
    this.fabHidden = false;
    // A tab switch lands on a fresh list, so the bar always comes back.
    this.setTabBarHidden(false);
    if (changed && index === HOME_TAB_INDEX && this.refreshOnHomeTab && this.navPathStack.size() === 0) {
      this.onRefresh(true);
    }
    if (index !== 0 && index !== 1) {
      this.fabMode = 'compose';
    }
    if (index === 4 && this.hasAnySession()) {
      const viewerId: string = this.xPrivate.isSignedIn() ? this.xPrivate.viewerId() : authStore.getUserId();
      if (this.meTimelineTab === 1) {
        if (viewerId.length > 0 && viewerId !== this.likedPostsLoadedFor) {
          this.loadLikedPosts(true).catch((): void => {});
        }
      } else if (viewerId.length > 0 && viewerId !== this.ownPostsLoadedFor) {
        this.loadOwnPosts(true).catch((): void => {});
      }
    }
    if (index === NOTIFICATIONS_TAB_INDEX) {
      this.onNotificationsOpened();
      this.refreshNotificationsIfStale();
    }
    if (index === MESSAGES_TAB_INDEX) {
      this.onMessagesOpened();
      this.refreshMessagesIfStale();
    }
  }

  private onRootTabBarClick(visibleIndex: number): void {
    if (this.bottomBarPageAt(visibleIndex) !== HOME_TAB_INDEX) {
      this.lastHomeTabClickAt = 0;
      return;
    }
    const now: number = Date.now();
    if (this.lastHomeTabClickAt > 0 && now - this.lastHomeTabClickAt <= HOME_TAB_DOUBLE_TAP_INTERVAL_MS) {
      this.lastHomeTabClickAt = 0;
      this.onRefresh(this.homeDoubleTapLatest);
      return;
    }
    this.lastHomeTabClickAt = now;
  }

  private onClassicTabBarClick(visibleIndex: number): void {
    this.tabsController.changeIndex(visibleIndex);
    this.onRootTabBarClick(visibleIndex);
  }

  private scheduleChromeTab(index: number, changed: boolean): void {
    if (this.chromeTabTimer >= 0) {
      clearTimeout(this.chromeTabTimer);
      this.chromeTabTimer = -1;
    }
    if (!changed) {
      this.chromeTab = index;
      this.chromeTabSettled = index;
      return;
    }
    // The bar used to wait for the whole page swipe before swapping its
    // content, which made the height change feel like a second, late step.
    // Morph it together with the incoming page instead.
    this.getUIContext().animateTo({
      duration: TITLE_BAR_MORPH_DURATION_MS, curve: Curve.EaseOut
    }, (): void => {
      this.chromeTab = index;
    });
    this.chromeTabTimer = setTimeout((): void => {
      this.chromeTabTimer = -1;
      this.chromeTabSettled = index;
    }, ROOT_TAB_SWITCH_DURATION_MS);
  }

  // Require the tab content and the shared title bar to agree before showing
  // root-only chrome such as the pending-posts capsule.
  private isTabChromeVisible(index: number): boolean {
    return this.currentTab === index && this.chromeTab === index;
  }

  private isHomeChromeVisible(): boolean {
    return this.isTabChromeVisible(HOME_TAB_INDEX);
  }

  private isExploreChromeVisible(): boolean {
    return this.isTabChromeVisible(1);
  }

  // Opening the list clears the dot immediately and reports the batch to X in
  // the background. The report is skipped when nothing was flagged unread, so a
  // failed call can never strand the badge.
  private onNotificationsOpened(): void {
    this.unreadNotifications = 0;
    this.syncUnreadBadge();
    if (this.notificationsUnread === 0 || this.notificationsSeenMarked ||
      !this.xPrivate.isSignedIn() || this.notificationsTopCursor.length === 0) {
      return;
    }
    this.notificationsSeenMarked = true;
    this.xPrivate.markNotificationsSeen(this.notificationsTopCursor).then((): void => {
    });
  }

  private onMessagesOpened(): void {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    notificationDeliveryService.markUnreadMessagesSeen(context, this.messages);
    this.unreadMessages = 0;
    this.syncUnreadBadge();
  }

  private goLogin(): void {
    this.onboardingLoginOnly = true;
    this.onboardingAddAccount = false;
    this.showOnboardingGuide = true;
  }

  // Signs out of the account in use by dropping it from the account list. Any
  // other signed-in account takes over right away, which is the whole point of
  // keeping several: the reload below is triggered by the account store's
  // change notification, not repeated here.
  private async signOut(): Promise<void> {
    const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const signOutAccountId: string = accountStore.activeId(ctx);
    try {
      await meowPushService.beforeSignOut(ctx, signOutAccountId);
    } catch (error) {
      promptAction.showToast({ message: this.text($r('app.string.meow_sign_out_error')), duration: 3000 });
      return;
    }
    if (accountStore.activeId(ctx) !== signOutAccountId) { return; }
    const remaining: number = await authStore.signOut(ctx);
    xPrivateClient.load(ctx);
    if (remaining === 0) {
      // Nothing is signed in any more, so the Web cookie jar is cleared too:
      // otherwise the next visit to x.com would still carry the old session.
      try {
        await webview.WebCookieManager.clearAllCookies();
      } catch (error) {
        // Local credentials are already cleared; the Web cookie jar may be
        // unavailable before an ArkWeb instance has initialized.
      }
    } else {
      xWebCookieBridge.syncActive(ctx);
    }
    const active: XAccount | null = accountStore.active(ctx);
    const message: string = active === null ? this.text($r('app.string.toast_sign_out')) :
      this.text($r('app.string.accounts_switched')) + active.title();
    promptAction.showToast({ message: message, duration: 1800 });
  }

  // The account switcher changed the active account. Every surface below is
  // account-scoped, so all of it is dropped before the feed is fetched again;
  // otherwise the reader briefly sees the previous account's posts, mentions
  // and profile.
  private onAccountsChanged(): void {
    postModerationStore.load(getContext(this) as common.UIAbilityContext);
    homeSeenTweetStore.load(getContext(this) as common.UIAbilityContext);
    this.showSpacePreview = false;
    this.previewFromHomeCapsule = false;
    this.previewPerson = null;
    spaceSurfaceStore.clear();
    this.reloadForActiveAccount();
    this.onExternalShareRequested();
  }

  private async reloadForActiveAccount(): Promise<void> {
    this.profile = null;
    this.ownPosts = [];
    this.ownPostsLoadedFor = '';
    this.ownPostsStatus = '';
    this.ownPostsHasMore = false;
    this.likedPosts = [];
    this.likedPostsLoadedFor = '';
    this.likedPostsStatus = '';
    this.likedPostsHasMore = false;
    this.notifications = [];
    this.notificationsStatus = '';
    this.notificationsCursor = '';
    this.notificationsTopCursor = '';
    this.notificationsSource = '';
    this.notificationsFetchedAt = 0;
    this.mentionsRequestId += 1;
    this.mentionNotifications = [];
    this.mentionsStatus = '';
    this.mentionsCursor = '';
    this.mentionsFetchedAt = 0;
    this.mentionsHasMore = false;
    this.mentionsLoading = false;
    this.notificationsUnread = 0;
    this.notificationsSeenMarked = false;
    this.unreadNotifications = 0;
    this.messages = [];
    this.messagesUnread = 0;
    this.messagesFetchedAt = 0;
    this.unreadMessages = 0;
    this.syncUnreadBadge();
    this.trends = [];
    this.exploreSections = [];
    this.clearExploreHomePayload();
    this.exploreResults = [];
    this.timeline = [];
    this.pendingNewPosts = [];
    this.forYouSnapshot = new HomeFeedSnapshot();
    this.followingSnapshot = new HomeFeedSnapshot();
    this.topicSnapshots.clear();
    this.homePageSources.forEach((source: TimelinePageDataSource): void => { source.replace([]); });
    this.homeTimelineRequestId += 1;
    this.recommendationSignalsLoaded = false;
    this.scrollDepth = 0;
    this.fabMode = 'compose';
    this.fabHidden = false;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    xPrivateClient.load(context);
    accountPrivacyService.syncSensitiveMedia(context, true).catch((): void => { });
    xWebCookieBridge.syncActive(context);
    this.refreshHomeSpaces();
    await this.loadTimeline();
  }

  @Builder
  private NewPostsCapsule(): void {
    Row() {
      NewPostsPill({
        authors: this.pendingAuthors,
        newCount: this.pendingNewPosts.length,
        onTap: (): void => {
          this.revealPendingPosts();
        }
      })
    }
    .width('100%')
    .id('home-new-posts-capsule')
    .justifyContent(FlexAlign.Center)
    .position({ x: 0, y: this.homeContentTopInset() + 8 })
    .zIndex(12)
    .transition(TransitionEffect.OPACITY.animation({ duration: 180, curve: Curve.EaseOut }))
  }

  private isDesktopLayout(): boolean {
    return DesktopLayout.active(this.desktopLayoutEnabled, this.breakpoint);
  }

  private onDesktopLayoutChanged(): void {
    this.closeDesktopRail();
    if (this.isDesktopLayout()) {
      const names: string[] = this.navPathStack.getAllPathName();
      if (names.length > 0 && names[names.length - 1] === 'SettingsSection') {
        const params: SettingsRouteParam[] = this.navPathStack.getParamByName('SettingsSection') as SettingsRouteParam[];
        const section: SettingsRouteParam | undefined = params[params.length - 1] as SettingsRouteParam;
        AppStorage.setOrCreate<string>('harmonyx.desktop_settings_section', section?.section ?? 'display');
        this.navPathStack.pop(false);
      }
    }
    this.beginHomeViewportChange();
    this.showSideDrawer = !this.isDesktopLayout() && this.isLargeScreen();
    this.updateNavigationMode();
    this.syncAllWaterFlowSections();
  }

  private syncDesktopRoute(): void {
    const names: string[] = this.navPathStack.getAllPathName();
    if (names.length === 0 && this.contentDestinationOpen) {
      AppStorage.setOrCreate<boolean>(ResponsiveLayout.CONTENT_DESTINATION_OPEN_KEY, false);
    }
    this.desktopModalOpen = names.length > 0 && (names[names.length - 1] === 'ReplyComposer' ||
      names[names.length - 1] === 'TimelineManager');
    let route: string = '';
    for (let i: number = names.length - 1; i >= 0; i--) {
      if (names[i] !== 'ReplyComposer' && names[i] !== 'TimelineManager') { route = names[i]; break; }
    }
    this.desktopRoute = route;
    const params: DmConversationRouteParam[] = this.navPathStack.getParamByName('DmConversation') as DmConversationRouteParam[];
    const chat: DmConversationRouteParam | undefined = params[params.length - 1] as DmConversationRouteParam;
    this.desktopConversationId = chat?.conversationId ?? '';
    this.updateNavigationMode();
  }

  private desktopAsideVisible(): boolean {
    return this.desktopAsideEnabled &&
      DesktopLayout.hasAside(this.breakpoint, this.desktopRoute, this.currentTab === MESSAGES_TAB_INDEX);
  }

  private closeDesktopAside(): void {
    if (!layoutSettingsStore.saveAsideEnabled(getContext(this) as common.UIAbilityContext, false)) {
      promptAction.showToast({ message: this.text($r('app.string.settings_layout_save_failed')) });
    }
  }

  private desktopSelected(): string {
    if (this.desktopRoute === 'Grok') { return 'grok'; }
    if (this.desktopRoute === 'CreatorStudio') { return 'studio'; }
    if (this.desktopRoute === 'Bookmarks') { return 'bookmarks'; }
    if (this.desktopRoute === 'UserDetail') { return 'profile'; }
    if (this.desktopRoute === 'FollowDiscovery') { return 'follow'; }
    if (this.desktopRoute === 'SearchResultsPage' || this.desktopRoute === 'SearchHistoryPage') { return 'explore'; }
    if (this.currentTab === EXPLORE_TAB_INDEX) { return 'explore'; }
    if (this.currentTab === NOTIFICATIONS_TAB_INDEX) { return 'notifications'; }
    if (this.currentTab === MESSAGES_TAB_INDEX) { return 'messages'; }
    if (this.currentTab === ME_TAB_INDEX) { return 'profile'; }
    return 'home';
  }

  private desktopNavigate(name: string): void {
    this.closeDesktopRail();
    ResponsiveLayout.closeToMain(this.navPathStack);
    this.desktopRoute = '';
    if (name === 'home') { this.selectRootTabPage(HOME_TAB_INDEX); }
    else if (name === 'explore') { this.selectRootTabPage(EXPLORE_TAB_INDEX); }
    else if (name === 'notifications') { this.goNotifications(); }
    else if (name === 'messages') { this.goMessages(); }
    else if (name === 'settings') { this.openSettings(); }
    else if (name === 'help') { this.openHelpCenter(); }
    else if (name === 'follow') {
      const param: FollowDiscoveryRouteParam = { tab: 2, contextualUserId: '' };
      this.navPathStack.pushPath({ name: 'FollowDiscovery', param: param });
    } else if (name === 'grok') { this.navPathStack.pushPath({ name: 'Grok' }); }
    else if (name === 'profile') {
      if (this.profile === null) { this.selectRootTabPage(ME_TAB_INDEX); return; }
      const author: TweetAuthor = { id: this.profile.id, name: this.profile.name,
        username: this.profile.username, avatarUrl: this.profile.avatarUrl ?? '',
        avatarColor: this.accentColor, verified: this.profile.verified, verifiedType: this.profile.verifiedType, avatarShape: this.profile.avatarShape };
      const param: UserDetailRouteParam = { author: author, posts: this.ownPosts };
      this.navPathStack.pushPath({ name: 'UserDetail', param: param });
    } else { this.showDrawerFeature(name); }
    this.syncDesktopRoute();
  }

  @Builder
  private DesktopRail(): void {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.desktopRailMaterialLevel >= 0) {
        SideBarMaterialLayer({ materialLevel: this.desktopRailMaterialLevel, layerPrefix: 'desktop-rail' })
      }
    DesktopNavRail({
        compact: DesktopLayout.compactRail(this.breakpoint, this.currentTab === MESSAGES_TAB_INDEX),
        selected: this.desktopSelected(), profile: this.profile, handle: this.handleText,
        unread: this.unreadNotifications, topInset: this.statusBarHeight, bottomInset: this.navigationIndicatorHeight,
        onSelect: (name: string): void => this.desktopNavigate(name),
        onCompose: (): void => { this.closeDesktopRail(); this.openComposer('', '', ''); },
        onAccounts: (): void => { this.closeDesktopRail(); this.openAccounts(); }
      })
        .width(DesktopLayout.compactRail(this.breakpoint, this.currentTab === MESSAGES_TAB_INDEX) ?
          $r('app.float.desktop_rail_compact') : $r('app.float.desktop_rail_width'))
        .opacity(this.desktopModalOpen ? 0.4 : 1).enabled(!this.desktopModalOpen)
    }.width(DesktopLayout.compactRail(this.breakpoint, this.currentTab === MESSAGES_TAB_INDEX) ?
      $r('app.float.desktop_rail_compact') : $r('app.float.desktop_rail_width')).height('100%').borderRadius(0).clip(false)
      .backgroundColor(this.desktopRailMaterialLevel < 0 ? this.themedPageSurface() : Color.Transparent)
      .id('desktop-rail-container')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.START, SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  private closeDesktopRail(): void {
    this.desktopRailOpen = false;
  }

  private openDesktopRail(): void {
    if (this.desktopRailAutoHide && !this.desktopModalOpen && !this.fullscreenDesktopPhoto()) {
      this.desktopRailOpen = true;
    }
  }

  private onDesktopRailSwipe(event: GestureEvent): void {
    if (!this.desktopRailSwipe || this.desktopRailOpen) { return; }
    if (event.offsetX > 40 && Math.abs(event.offsetX) > Math.abs(event.offsetY) * 1.5) {
      this.openDesktopRail();
    }
  }

  private onDesktopRailCloseSwipe(event: GestureEvent): void {
    if (this.desktopRailSwipe && event.offsetX < -40 && Math.abs(event.offsetX) > Math.abs(event.offsetY) * 1.5) {
      this.closeDesktopRail();
    }
  }

  @Builder
  private DesktopRailOverlay(): void {
    if (this.desktopRailAutoHide && !this.fullscreenDesktopPhoto() && !this.desktopModalOpen) {
      if (this.desktopRailOpen) {
        Row({ space: 0 }) {
          Column() { this.DesktopRail() }
            .width(DesktopLayout.compactRail(this.breakpoint, this.currentTab === MESSAGES_TAB_INDEX) ?
              $r('app.float.desktop_rail_compact') : $r('app.float.desktop_rail_width'))
            .height('100%').backgroundColor(Color.Transparent).id('desktop-navigation-panel')
          Column().layoutWeight(1).height('100%').backgroundColor(Color.Transparent)
            .id('desktop-navigation-dismiss').onClick((): void => this.closeDesktopRail())
        }.width('100%').height('100%').zIndex(30)
          .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM],
            [LayoutSafeAreaEdge.START, LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.START, SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
          .parallelGesture(PanGesture({ direction: PanDirection.Left, distance: 40 })
            .onActionEnd((event: GestureEvent): void => this.onDesktopRailCloseSwipe(event)))
          .transition(TransitionEffect.OPACITY.animation({ duration: 180 }))
      } else {
        if (this.desktopRailSwipe) {
          Column().width($r('app.float.desktop_rail_swipe_edge')).height('100%')
            .position({ x: 0, y: 0 }).backgroundColor(Color.Transparent).zIndex(29)
            .hitTestBehavior(HitTestMode.Transparent)
            .id('desktop-navigation-edge-swipe').accessibilityLevel('no')
            .gesture(PanGesture({ direction: PanDirection.Right, distance: 40 })
              .onActionEnd((event: GestureEvent): void => this.onDesktopRailSwipe(event)))
        }
        Button({ type: ButtonType.Normal }) {
          SidebarExpandHandle({ style: this.desktopHandleStyle, imagePath: this.desktopHandlePath })
        }.width($r('app.float.desktop_rail_handle_width')).height($r('app.float.desktop_rail_handle_height'))
          .padding(0).backgroundColor(Color.Transparent).borderRadius({ topRight: 26, bottomRight: 26 })
          .position({ x: 0, y: this.statusBarHeight + 64 }).zIndex(30)
          .accessibilityText($r('app.string.settings_desktop_rail_open')).id('desktop-navigation-open')
          .onClick((): void => this.openDesktopRail())
          .gesture(PanGesture({ direction: PanDirection.Right, distance: 40 })
            .onActionEnd((event: GestureEvent): void => this.onDesktopRailSwipe(event)))
      }
    }
  }

  @Builder
  private DesktopShell(): void {
    Stack({ alignContent: Alignment.TopStart }) {
    Row({ space: 0 }) {
      if (!this.desktopRailAutoHide) { this.DesktopRail() }
      Column() { this.ContentPanelBuilder() }.layoutWeight(1).height('100%')
        // Keep sliding pages inside their pane instead of painting over the rail.
        .clip(true)
        .borderWidth({ end: LengthMetrics.vp(this.desktopMediaDestination() ? 0 : 0.5) })
        .borderColor($r('app.color.divider'))
        .onAreaChange((_oldValue: Area, newValue: Area): void => this.onDesktopContentAreaChanged(newValue))
      if (this.desktopAsideVisible()) {
        Column() { this.DesktopAside() }.width($r('app.float.desktop_aside_width')).height('100%')
          .id('desktop-information-sidebar')
          .opacity(this.desktopModalOpen ? 0.4 : 1).enabled(!this.desktopModalOpen)
      }
    }.width('100%').height('100%')
      .padding({ left: this.desktopMediaDestination() || !this.desktopRailAutoHide ? 0 : $r('app.float.desktop_outer_gutter'),
        right: this.desktopMediaDestination() ? 0 : $r('app.float.desktop_outer_gutter') })
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .backgroundColor(this.themedPageSurface())
    this.DesktopRailOverlay()
    }.width('100%').height('100%')
  }

  private fullscreenDesktopPhoto(): boolean {
    return this.desktopRoute === 'PhotoViewer' && this.photoFullscreen;
  }

  private desktopMediaDestination(): boolean {
    return this.desktopRoute === 'PhotoViewer' || this.desktopRoute === 'VideoFeedViewer' ||
      this.desktopRoute === 'ChatVideoViewer';
  }

  private desktopHeaderHeight(): number {
    if (this.currentTab === HOME_TAB_INDEX) { return 56; }
    if (this.currentTab === EXPLORE_TAB_INDEX) { return this.desktopTitleBarHeight() + this.exploreCategoriesHeight(); }
    if (this.currentTab === MESSAGES_TAB_INDEX) { return 112; }
    if (this.currentTab === NOTIFICATIONS_TAB_INDEX) { return 108; }
    return 56;
  }

  private desktopTitleBarHeight(): number {
    return this.currentTab === EXPLORE_TAB_INDEX ? Math.max(56, this.exploreSearchHeight() + 16) : 56;
  }

  @Builder
  private DesktopTitleBarContent(): void {
    Column() { this.DesktopHeader() }.width('100%').height(this.desktopTitleBarHeight())
      .justifyContent(FlexAlign.Center)
      .systemMaterial(titleBarGlassMaterial(this.titleBarStyleMode, this.titleBarGlassMaterialLevel))
  }

  @Builder
  private DesktopHeader(): void {
    Column({ space: 0 }) {
      if (this.currentTab === HOME_TAB_INDEX) {
        this.HomeFeedSwitch()
      } else if (this.currentTab === EXPLORE_TAB_INDEX) {
        Search({ value: this.searchText, placeholder: $r('app.string.search_placeholder') })
          .width('calc(100% - 32vp)').height(this.exploreSearchHeight()).margin({ top: 8, bottom: 8 })
          .backgroundColor(this.themedFieldSurface()).fontColor($r('app.color.text_primary'))
          .onChange((value: string): void => { this.searchText = value; })
          .onSubmit((value: string): void => this.submitSearchFromHeader(value, false))
      } else {
        Row() {
          Text(this.currentTab === MESSAGES_TAB_INDEX ? $r('app.string.chat_title') :
            this.currentTab === ME_TAB_INDEX ? $r('app.string.side_profile') : $r('app.string.tab_alerts')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Title_M')).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
          if (this.currentTab === MESSAGES_TAB_INDEX) {
            Button({ type: ButtonType.Circle }) {
              SymbolGlyph($r('sys.symbol.message_badge_plus')).fontSize(24).fontColor([$r('app.color.text_primary')])
            }.width(44).height(44).backgroundColor(Color.Transparent).onClick((): void => this.openChatComposer())
          } else if (this.currentTab === NOTIFICATIONS_TAB_INDEX) {
            this.NotificationSettingsButton()
          }
        }.width('100%').height(56).padding({ left: 16, right: 16 })
      }
    }.width('100%').flexShrink(0)
  }

  @Builder
  private DesktopTitleBarBottomContent(): void {
    Column() {
      if (this.currentTab === EXPLORE_TAB_INDEX) { this.ExploreCategoryTabs() }
      else if (this.currentTab === MESSAGES_TAB_INDEX) { this.ChatTitleBarSearch() }
      else if (this.currentTab === NOTIFICATIONS_TAB_INDEX) { this.NotificationTabs(false) }
    }.width('100%').height(Math.max(0, this.desktopHeaderHeight() - this.desktopTitleBarHeight()))
      .systemMaterial(titleBarGlassMaterial(this.titleBarStyleMode, this.titleBarGlassMaterialLevel))
  }

  @Builder
  private DesktopRootPage(): void {
    if (this.currentTab === MESSAGES_TAB_INDEX && this.navPathStack.size() === 0) {
      Row() {
        Column() {
          Column() { this.MessagesTab() }.width('100%').layoutWeight(1)
        }
          .width(360).height('100%').border({ width: { right: 0.5 }, color: $r('app.color.divider') })
        this.DesktopChatEmpty()
      }.width('100%').height('100%')
    } else {
      Column() {
        Column() {
          if (this.currentTab === HOME_TAB_INDEX) { this.HomeTab() }
          else if (this.currentTab === EXPLORE_TAB_INDEX) { this.ExploreTab() }
          else if (this.currentTab === NOTIFICATIONS_TAB_INDEX) { this.NotificationsTab() }
          else if (this.currentTab === MESSAGES_TAB_INDEX) { this.MessagesTab() }
          else { this.MeTab() }
        }.width('100%').layoutWeight(1)
      }.width('100%').height('100%')
    }
  }

  @Builder
  private DesktopChatEmpty(): void {
    Column({ space: 20 }) {
      SymbolGlyph($r('sys.symbol.message')).fontSize(58).fontColor([$r('app.color.text_primary')])
        .width(96).height(96).backgroundColor(this.themedFieldSurface()).borderRadius(48)
      Text($r('app.string.desktop_chat_empty')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Title_L')).fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Text($r('app.string.desktop_chat_empty_desc')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L'))
        .fontColor($r('app.color.text_secondary')).textAlign(TextAlign.Center)
      Button($r('app.string.chat_new')).height(44).padding({ left: 24, right: 24 })
        .fontColor($r('app.color.text_on_inverse')).backgroundColor($r('app.color.text_primary'))
        .onClick((): void => this.openChatComposer())
    }.height('100%').layoutWeight(1).padding(24).justifyContent(FlexAlign.Center)
  }

  @Builder
  private DesktopInlineComposer(): void {
    Column({ space: 14 }) {
      Row({ space: 12 }) {
        ProxyAvatar({verifiedType: this.profile?.verifiedType ?? '', avatarShape: this.profile?.avatarShape ?? '',  url: this.profile?.avatarUrl ?? '', avatarSize: 40, radius: 20,
          fallbackText: this.avatarInitial(), fallbackColor: this.accentColor })
        TextArea({ text: this.desktopInlineDraft, placeholder: $r('app.string.compose_placeholder') }).fontFamily(this.appFontFamily)
          .layoutWeight(1).height(78).padding(8).backgroundColor(Color.Transparent)
          .fontSize($r('sys.float.Title_S')).fontColor($r('app.color.text_primary'))
          .onChange((value: string): void => { this.desktopInlineDraft = value; })
      }.width('100%').alignItems(VerticalAlign.Top)
      Row({ space: 16 }) {
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.picture')).fontSize(24).fontColor([this.accentColor])
        }.width(36).height(36).backgroundColor(Color.Transparent)
          .onClick((): void => this.openComposer(this.desktopInlineDraft, '', ''))
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.face_smiling')).fontSize(24).fontColor([this.accentColor])
        }.width(36).height(36).backgroundColor(Color.Transparent)
          .onClick((): void => this.openComposer(this.desktopInlineDraft, '', ''))
        Blank()
        Button($r('app.string.action_post')).height(38).padding({ left: 20, right: 20 })
          .fontColor($r('app.color.text_on_inverse')).backgroundColor($r('app.color.text_primary'))
          .onClick((): void => this.openComposer(this.desktopInlineDraft, '', ''))
      }.width('100%').padding({ start: LengthMetrics.vp(52) })
    }.width('100%').padding(16).border({ width: { bottom: 0.5 }, color: $r('app.color.divider') })
  }

  @Builder
  private DesktopAside(): void {
    Scroll() {
      Column({ space: 16 }) {
        Row({ space: 8 }) {
          Search({ placeholder: $r('app.string.search_placeholder') }).layoutWeight(1).height(44)
            .backgroundColor(Color.Transparent).border({ width: 1, color: $r('app.color.divider') })
            .fontColor($r('app.color.text_primary')).borderRadius(22)
            .onSubmit((value: string): void => this.submitSearchFromHeader(value, false))
          Button({ type: ButtonType.Circle }) {
            SymbolGlyph($r('sys.symbol.xmark')).fontSize($r('app.float.desktop_aside_close_icon'))
              .fontColor([$r('app.color.text_secondary')])
          }.width($r('app.float.desktop_aside_close_size')).height($r('app.float.desktop_aside_close_size'))
            .backgroundColor(Color.Transparent).id('desktop-aside-close')
            .accessibilityText(this.text($r('app.string.desktop_aside_close')))
            .onClick((): void => this.closeDesktopAside())
        }.width('100%')
        if (this.desktopRoute === 'SearchResultsPage') {
          Column({ space: 16 }) {
            Text($r('app.string.search_filter_title')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Title_M')).fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary')).width('100%')
            Button($r('app.string.search_filter_people')).fontColor($r('app.color.text_primary'))
              .backgroundColor(Color.Transparent).onClick((): void => this.openSearchFilters())
            Button($r('app.string.desktop_advanced_search')).fontColor(this.accentColor).backgroundColor(Color.Transparent)
              .onClick((): void => { this.desktopAdvancedSearchOpen = true; })
          }.width('100%').alignItems(HorizontalAlign.Start).padding(16)
            .border({ width: 1, color: $r('app.color.divider') }).borderRadius($r('app.float.desktop_card_radius'))
        } else {
          Column({ space: 12 }) {
            Text($r('app.string.desktop_premium_title')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Title_M')).fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary')).width('100%')
            Text($r('app.string.desktop_premium_desc')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
              .fontColor($r('app.color.text_primary')).width('100%')
            Button($r('app.string.side_premium')).height(38).backgroundColor(this.accentColor)
              .fontColor($r('app.color.text_on_accent')).onClick((): void => this.showDrawerFeature('premium'))
          }.width('100%').alignItems(HorizontalAlign.Start).padding(16)
            .border({ width: 1, color: $r('app.color.divider') }).borderRadius($r('app.float.desktop_card_radius'))
        }
        Column({ space: 8 }) {
          Text($r('app.string.desktop_whats_happening')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Title_M')).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary')).width('100%').padding(16)
          if (this.exploreTrendItems.length > 0) {
            ForEach(this.exploreTrendItems.slice(0, 4), (item: XExploreTrend) => {
              this.ExploreRichTrendRow(item)
            }, (item: XExploreTrend): string => item.name)
          } else if (this.hasAnySession() && this.trends.length > 0) {
            ForEach(this.trends.slice(0, 4), (trend: string) => { this.ExploreTrendRow(trend) }, (trend: string): string => trend)
          } else {
            Text($r('app.string.explore_section_empty')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
              .fontColor($r('app.color.text_secondary')).padding(16)
          }
          Button($r('app.string.follow_show_more')).width('100%').fontColor(this.accentColor)
            .backgroundColor(Color.Transparent).onClick((): void => this.desktopNavigate('explore'))
        }.width('100%').border({ width: 1, color: $r('app.color.divider') }).borderRadius($r('app.float.desktop_card_radius'))
        FollowSuggestions({ autoLoad: true, vertical: true })
      }.width('100%').padding({ start: LengthMetrics.vp(24), end: LengthMetrics.vp(20),
        top: LengthMetrics.vp(this.statusBarHeight + 8),
        bottom: LengthMetrics.vp(this.navigationIndicatorHeight + 24) })
    }.width($r('app.float.desktop_aside_width')).height('100%').scrollBar(BarState.Auto).align(Alignment.TopStart)
      .bindSheet($$this.desktopAdvancedSearchOpen, this.DesktopAdvancedSearch(), sheetMaterialOptions({
        width: 600, height: Math.min(720, this.windowHeight * 0.85), preferType: SheetType.CENTER,
        showClose: false, dragBar: false, backgroundColor: this.themedPageSurface()
      }, this.sheetMaterialEnabled, this.sheetMaterialLevel, this.sheetWindowBreakpoint, this.compactWindow))
  }

  private advancedSearchSubmit(): void {
    const query: string[] = [];
    const values: string[] = this.desktopAdvancedValues.map((value: string): string => value.trim());
    const datePattern: RegExp = /^\d{4}-\d{2}-\d{2}$/;
    for (let i: number = 7; i < 9; i++) {
      if (values[i].length > 0 && (!datePattern.test(values[i]) ||
        Number.isNaN(Date.parse(values[i])) || new Date(values[i]).toISOString().substring(0, 10) !== values[i])) {
        promptAction.showToast({ message: this.text($r('app.string.desktop_search_date_error')) }); return;
      }
    }
    if (values[7].length > 0 && values[8].length > 0 && values[8] <= values[7]) {
      promptAction.showToast({ message: this.text($r('app.string.desktop_search_date_error')) }); return;
    }
    if (values[0].length > 0) { query.push(values[0]); }
    if (values[1].length > 0) { query.push('"' + values[1].replace(/"/g, '') + '"'); }
    if (values[2].length > 0) { query.push('(' + values[2].split(/\s+/).join(' OR ') + ')'); }
    if (values[3].length > 0) { query.push(values[3].split(/\s+/).map((value: string): string => '-' + value).join(' ')); }
    if (values[4].length > 0) { query.push(values[4].split(/\s+/).map((value: string): string => '#' + value.replace(/^#/, '')).join(' ')); }
    if (values[5].length > 0) { query.push('(' + values[5].split(/\s+/).map((value: string): string => 'from:' + value.replace(/^@/, '')).join(' OR ') + ')'); }
    if (values[6].length > 0) { query.push('(' + values[6].split(/\s+/).map((value: string): string => 'to:' + value.replace(/^@/, '')).join(' OR ') + ')'); }
    if (values[7].length > 0) { query.push('since:' + values[7]); }
    if (values[8].length > 0) { query.push('until:' + values[8]); }
    if (query.length === 0) { return; }
    this.desktopAdvancedSearchOpen = false;
    this.submitSearchFromHeader(query.join(' '), true);
  }

  @Builder
  private AdvancedField(index: number, title: Resource): void {
    TextInput({ text: this.desktopAdvancedValues[index], placeholder: title }).fontFamily(this.appFontFamily)
      .width('100%').height(56).borderRadius(4).backgroundColor(Color.Transparent)
      .border({ width: 1, color: $r('app.color.divider') }).fontColor($r('app.color.text_primary'))
      .onChange((value: string): void => {
        const values: string[] = this.desktopAdvancedValues.slice(); values[index] = value; this.desktopAdvancedValues = values;
      })
  }

  @Builder
  private DesktopAdvancedSearch(): void {
    Column() {
      Row({ space: 16 }) {
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.xmark')).fontSize(22).fontColor([$r('app.color.text_primary')])
        }.width(40).height(40).backgroundColor(Color.Transparent)
          .onClick((): void => { this.desktopAdvancedSearchOpen = false; })
        Text($r('app.string.desktop_advanced_search')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Title_M')).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary')).layoutWeight(1)
        Button($r('app.string.search_action')).height(38).backgroundColor($r('app.color.text_primary'))
          .fontColor($r('app.color.text_on_inverse')).onClick((): void => this.advancedSearchSubmit())
      }.width('100%').padding(16)
      Scroll() {
        Column({ space: 24 }) {
          this.AdvancedField(0, $r('app.string.desktop_search_all'))
          this.AdvancedField(1, $r('app.string.desktop_search_exact'))
          this.AdvancedField(2, $r('app.string.desktop_search_any'))
          this.AdvancedField(3, $r('app.string.desktop_search_exclude'))
          this.AdvancedField(4, $r('app.string.desktop_search_tags'))
          this.AdvancedField(5, $r('app.string.desktop_search_from'))
          this.AdvancedField(6, $r('app.string.desktop_search_to'))
          this.AdvancedField(7, $r('app.string.desktop_search_since'))
          this.AdvancedField(8, $r('app.string.desktop_search_until'))
        }.width('100%').padding(20)
      }.width('100%').layoutWeight(1).scrollBar(BarState.Auto)
    }.width('100%').height('100%')
  }

  @Builder
  private ContentPanelBuilder(): void {
    if (this.supportsHdsNavigation()) {
      HdsNavigation(this.navPathStack) {
        Stack({ alignContent: Alignment.TopStart }) {
          this.MainTabs()

          if (this.isHomeChromeVisible() && this.pendingNewPosts.length > 0) {
            this.NewPostsCapsule()
          }

          if (this.composeButtonEnabled && !this.isDesktopLayout() &&
            (this.currentTab !== HOME_TAB_INDEX || this.homeFloatingAction !== HOME_FLOATING_HIDDEN)) {
            FloatingComposeButton({
              bottomInset: this.floatingTabBottomMargin(),
              bottomBarHeight: this.hasActiveSpace() ? 128 : 56,
              composeSymbol: this.currentTab === MESSAGES_TAB_INDEX ? $r('sys.symbol.message_badge_plus') : $r('sys.symbol.square_and_pencil'),
              accessibilityLabel: this.currentTab === MESSAGES_TAB_INDEX ? this.text($r('app.string.chat_new')) : '',
              mode: this.currentTab === HOME_TAB_INDEX ? this.homeFloatingAction :
                this.currentTab === EXPLORE_TAB_INDEX ? this.fabMode : 'compose',
              refreshing: this.refreshing,
              hidden: this.currentTab === MESSAGES_TAB_INDEX ? false : this.fabHidden,
              onTop: (): void => {
                this.scrollCurrentToTop();
              },
              onRefresh: (): void => {
                if (this.currentTab === HOME_TAB_INDEX) {
                  this.onRefresh();
                }
              },
              onCompose: (): void => {
                if (this.currentTab === MESSAGES_TAB_INDEX) { this.openChatComposer(); return; }
                this.replyToId = '';
                this.replyToUser = '';
                this.openComposer('', '', '');
              }
            })
          }
        }
        .width('100%')
        .height('100%')
        .clip(false)
      }
      .direction(isAppRtl(this.appLocale) ? Direction.Rtl : Direction.Ltr)
      .titleBar(this.rootTitleBarOptions())
      .titleMode(HdsNavigationTitleMode.MINI)
      .hideTitleBar(false)
      .mode(this.mainNavigationMode)
      .enableModeChangeAnimation(true)
      .navBarWidth(this.isDesktopLayout() ? 360 : 480)
      .minContentWidth(this.compactWindow ? 0 : 360)
      .hideBackButton(true)
      .dynamicHideTitleBar(this.titleBarHideParams())
      .bindToScrollable(this.rootScrollableControllers())
      // Named so the picture-in-picture controller can restore this page.
      .id(MAIN_NAVIGATION_ID)
      .navDestination(this.NavigationBuilder)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.BOTTOM])
      .width('100%')
      .height('100%')
      .backgroundColor(this.themedPageSurface())
      .clip(true)
    } else {
      Navigation() {
        Stack({ alignContent: Alignment.TopStart }) {
          this.MainTabs()
          if (this.isHomeChromeVisible() && this.pendingNewPosts.length > 0) {
            this.NewPostsCapsule()
          }
          if (this.composeButtonEnabled &&
            (this.currentTab !== HOME_TAB_INDEX || this.homeFloatingAction !== HOME_FLOATING_HIDDEN)) {
            FloatingComposeButton({
              bottomInset: 0,
              composeSymbol: this.currentTab === MESSAGES_TAB_INDEX ? $r('sys.symbol.message_badge_plus') : $r('sys.symbol.square_and_pencil'),
              accessibilityLabel: this.currentTab === MESSAGES_TAB_INDEX ? this.text($r('app.string.chat_new')) : '',
              mode: this.currentTab === HOME_TAB_INDEX ? this.homeFloatingAction :
                this.currentTab === EXPLORE_TAB_INDEX ? this.fabMode : 'compose',
              refreshing: this.refreshing,
              hidden: this.currentTab === MESSAGES_TAB_INDEX ? false : this.fabHidden,
              onTop: (): void => {
                this.scrollCurrentToTop();
              },
              onRefresh: (): void => {
                if (this.currentTab === HOME_TAB_INDEX) {
                  this.onRefresh();
                }
              },
              onCompose: (): void => {
                if (this.currentTab === MESSAGES_TAB_INDEX) { this.openChatComposer(); return; }
                this.replyToId = '';
                this.replyToUser = '';
                this.openComposer('', '', '');
              }
            })
          }
        }
        .width('100%')
        .height('100%')
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.themedPageSurface())
      .title(this.RootNavigationTitle())
      .titleMode(NavigationTitleMode.Mini)
      .hideTitleBar(false)
      .mode(NavigationMode.Stack)
      .hideBackButton(true)
      .id(MAIN_NAVIGATION_ID)
    }
  }

  build(): void {
    Stack() {
      if (this.isDesktopLayout()) {
        this.DesktopShell()
      } else if (this.supportsHdsNavigation()) {
        Stack() {
        HdsSideBar({
          sideBarPanelBuilder: this.sideBarPanelBuilder,
          contentPanelBuilder: this.contentPanelBuilder,
          isShowSideBar: this.showSideDrawer,
          $isShowSideBar: (show: boolean): void => { this.showSideDrawer = show; },
          onChange: (show: boolean): void => { this.showSideDrawer = show; },
          sideBarWidth: this.sideDrawerWidth(),
          sideBarPosition: SideBarPosition.Start,
          sideBarColor: this.desktopRailMaterialLevel < 0 ? this.themedPageSurface() : Color.Transparent,
          isSideBarBlur: false,
          maxSideBarWidth: this.sideDrawerWidth(),
          minContentWidth: this.isLargeScreen() ? 520 : 0,
          sideBarContainerType: this.isLargeScreen() ? SideBarContainerType.Embed : SideBarContainerType.Overlay,
          contentAreaMask: !this.isLargeScreen(),
          autoHide: ResponsiveLayout.isSmall(this.breakpoint),
          scaleContentEnabled: this.isLargeScreen(),
          swipeEnabled: !this.isLargeScreen()
        })
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Transparent)

        }
        .width('100%')
        .height('100%')
        .backgroundColor(this.themedPageSurface())
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      } else {
        this.ContentPanelBuilder();
      }

      if (this.supportsHdsNavigation() && !this.isLargeScreen() && this.showSideDrawer) {
        Column()
          .width(Math.max(0, (this.windowWidth > 0 ? this.windowWidth : 390) - this.sideDrawerWidth()))
          .height('100%')
          .backgroundColor(Color.Transparent)
          .position({ x: isAppRtl(this.appLocale) ? 0 : this.sideDrawerWidth(), y: 0 })
          .zIndex(20)
          .onClick((): void => {
            this.showSideDrawer = false;
          })
      }

      // 半模态以宿主节点 id 作为 key（引擎侧 SheetKey(targetId)），一个节点只能挂一个。
      // 同一节点上排在后面的 bindSheet(isShow = false) 会把前面刚拉起来的弹窗直接关掉，
      // 所以登录、引导与中秋弹窗各挂一个零尺寸宿主节点，根节点只保留链接预览。
      XXAuthPopupHost({ blocked: this.showOnboardingGuide || this.showLoginSheet ||
        this.showMidAutumnGreeting || this.showChatUnlock || this.showLinkPreview ||
        this.showSideDrawer || this.contentDestinationOpen || this.photoOverlayOpen ||
        this.showSpacePreview || this.showPauseTopics || this.showFollowingOrder })
      Column().width(0).height(0)
        .bindSheet($$this.showSpacePreview, this.SpacePreviewContent(), sheetMaterialOptions({
          width: 560,
          height: this.pauseTopicsSheetHeight(),
          detents: [this.pauseTopicsSheetHeight()],
          preferType: this.isLargeScreen() ? SheetType.CENTER : SheetType.BOTTOM,
          showClose: false, dragBar: true, backgroundColor: this.themedPageSurface(),
          onDisappear: (): void => {
            this.showSpacePreview = false;
            const person: SpaceParticipant | null = this.previewPerson;
            this.previewPerson = null;
            if (person !== null) {
              this.openContentDestination();
              this.navPathStack.pushPath({ name: 'UserDetail', param: spaceUserParam(person) });
            }
          }
        }, this.sheetMaterialEnabled, this.sheetMaterialLevel, this.sheetWindowBreakpoint, this.compactWindow))
      Column()
        .width(0)
        .height(0)
        .bindSheet($$this.showLoginSheet, this.LoginSheet(), sheetMaterialOptions({
          height: SheetSize.MEDIUM,
          preferType: SheetType.BOTTOM,
          showClose: false,
          dragBar: true,
          backgroundColor: this.themedPageSurface()
        }, this.sheetMaterialEnabled, this.sheetMaterialLevel, this.sheetWindowBreakpoint, this.compactWindow))
      Column().width(0).height(0)
        .bindSheet($$this.showChatUnlock, this.ChatUnlockSheet(), sheetMaterialOptions({
          height: SheetSize.FIT_CONTENT, preferType: SheetType.BOTTOM,
          showClose: false, dragBar: false, backgroundColor: this.themedPageSurface(),
          onDisappear: (): void => { this.chatUnlockDismissed(); }
        }, this.sheetMaterialEnabled, this.sheetMaterialLevel, this.sheetWindowBreakpoint, this.compactWindow))
      Column()
        .width(0)
        .height(0)
        .bindSheet($$this.showMidAutumnGreeting, this.MidAutumnGreetingSheet(), sheetMaterialOptions(this.midAutumnGreetingSheetOptions(), this.sheetMaterialEnabled, this.sheetMaterialLevel, this.sheetWindowBreakpoint, this.compactWindow))

      Row().width(0).height(0)
        .bindSheet($$this.showOnboardingGuide, this.OnboardingSheetContent(), sheetMaterialOptions({
          width: 760,
          height: this.onboardingSheetHeight(),
          detents: [this.onboardingSheetHeight()],
          preferType: ResponsiveLayout.isSmall(this.breakpoint) ? SheetType.BOTTOM : SheetType.CENTER,
          dragBar: false,
          backgroundColor: Color.Transparent,
          blurStyle: BlurStyle.Regular,
          showClose: false,
          onDisappear: (): void => { this.showOnboardingGuide = false; }
        }, this.sheetMaterialEnabled, this.sheetMaterialLevel, this.sheetWindowBreakpoint, this.compactWindow))

      Column().width(0).height(0)
        .bindSheet($$this.showPauseTopics, this.PauseTopicsSheetContent(), sheetMaterialOptions({
          height: this.pauseTopicsSheetHeight(),
          preferType: SheetType.BOTTOM,
          dragBar: true,
          showClose: false,
          backgroundColor: this.themedPageSurface(),
          onDisappear: (): void => { this.showPauseTopics = false; }
        }, this.sheetMaterialEnabled, this.sheetMaterialLevel, this.sheetWindowBreakpoint, this.compactWindow))
      Column().width(0).height(0)
        .bindSheet($$this.showFollowingOrder, this.FollowingOrderSheetContent(), sheetMaterialOptions({
          height: Math.min(320 + this.navigationIndicatorHeight, this.pauseTopicsSheetHeight()),
          preferType: SheetType.BOTTOM,
          dragBar: true,
          showClose: false,
          backgroundColor: this.themedPageSurface(),
          onDisappear: (): void => {
            this.showFollowingOrder = false;
            if (this.manageTimelinesAfterDismiss) {
              this.manageTimelinesAfterDismiss = false;
              this.openTimelineManager();
            }
          }
        }, this.sheetMaterialEnabled, this.sheetMaterialLevel, this.sheetWindowBreakpoint, this.compactWindow))

      PhotoViewerOverlay({ pageStack: this.photoOverlayStack, active: this.photoOverlayOpen,
        destinationBuilder: this.NavigationBuilder })
        .visibility(this.photoOverlayOpen ? Visibility.Visible : Visibility.Hidden)
        .hitTestBehavior(this.photoOverlayOpen ? HitTestMode.Default : HitTestMode.None)
        .zIndex(50)
    }
    .width('100%')
    .height('100%')
    .direction(isAppRtl(this.appLocale) ? Direction.Rtl : Direction.Ltr)
    .bindSheet($$this.showLinkPreview, this.LinkPreviewSheet(), sheetMaterialOptions({
      height: SheetSize.MEDIUM,
      detents: [SheetSize.MEDIUM, SheetSize.LARGE],
      preferType: SheetType.BOTTOM,
      showClose: true,
      dragBar: true,
      backgroundColor: this.themedPageSurface(),
      onDisappear: (): void => {
        this.linkPreviewUrl = '';
      }
    }, this.sheetMaterialEnabled, this.sheetMaterialLevel, this.sheetWindowBreakpoint, this.compactWindow))
  }

  @Builder
  private SideBarPanelBuilder(): void {
    XSideDrawer({
      profile: this.profile,
      fallbackName: this.handleText.length > 1 ? this.handleText.substring(1) : 'Croak X',
      fallbackHandle: this.handleText.length > 0 ? this.handleText : '@croakx',
      onClose: (): void => { this.showSideDrawer = false; },
      onProfile: (): void => {
        this.showSideDrawer = false;
        this.goMe();
      },
      onFollowing: (): void => {
        this.showSideDrawer = false;
        this.openOwnUserList(USER_LIST_FOLLOWING);
      },
      onFollowers: (): void => {
        this.showSideDrawer = false;
        this.openOwnUserList(USER_LIST_FOLLOWERS);
      },
      onSettings: (): void => this.openSettings(),
      onAccounts: (): void => this.openAccounts(),
      onMenu: (feature: string): void => {
        if (feature === 'help' || feature === 'support') {
          this.openHelpCenter();
          return;
        }
        this.showDrawerFeature(feature);
      }
    })
  }

  @Builder
  private MainTabs(): void {
    Stack({ alignContent: Alignment.BottomEnd }) {
      if (this.isDesktopLayout()) {
        this.DesktopRootPage()
      } else if (this.supportsHdsNavigation()) {
        this.RootHdsTabs()
        if (!this.usesFloatingTabBar()) {
          this.ClassicTabTouchLayer()
        }
      } else {
        Tabs({ barPosition: BarPosition.End, index: this.bottomBarPageIndex(this.currentTab),
          controller: this.tabsController }) {
          this.LegacyTabContents()
        }
        .width('100%')
        .height('100%')
        .barBackgroundColor(this.themedPageSurface())
        .scrollable(this.rootTabsAreSwipeEnabled())
        .onChange((index: number) => {
          this.onTabChange(this.bottomBarPageAt(index));
        })
        .onTabBarClick((index: number): void => {
          this.onRootTabBarClick(index);
        })
      }
      if (this.hasActiveSpace()) {
        Column() {
          SpaceListeningBar({ onOpen: (room: SpaceRoom): void => {
            this.openSpacePreview(room);
          } })
        }.width('100%').padding({ left: 12, right: 12 })
          .margin({ bottom: this.floatingTabBottomMargin() + (this.tabBarHidden ? 12 : 72) })
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private RootHdsTabs(): void {
    if (this.usesFloatingTabBar()) {
        HdsTabs({ controller: this.hdsTabsController, index: this.bottomBarPageIndex(this.currentTab) }) {
          this.HdsTabContents()
        }
        .width('100%')
        .height('100%')
        .backgroundColor(this.themedPageSurface())
        .barPosition(BarPosition.End)
        .barOverlap(this.usesFloatingTabBar())
        .vertical(false)
        .barHeight(this.usesFloatingTabBar() ? $r('app.float.root_tab_bar_height') : this.classicTabBarHeight())
        .barBackgroundColor(this.usesFloatingTabBar() ? Color.Transparent : this.themedPageSurface())
        // Bind the native style at creation and on safe-area changes. Mutating
        // a modifier before HdsTabs mounts can leave its first layout at 0vp.
        .barFloatingStyle(this.rootTabFloatingStyle())
        .scrollable(this.rootTabsAreSwipeEnabled())
        .animationDuration(ROOT_TAB_SWITCH_DURATION_MS)
        .onChange((index: number) => {
          this.onTabChange(this.bottomBarPageAt(index));
        })
        .onTabBarClick((index: number): void => {
          this.onRootTabBarClick(index);
        })
    } else {
      // The optional classic presentation uses the native Tabs container so
      // its bar can stretch across the window and blur its background.
      Tabs({ barPosition: BarPosition.End, index: this.bottomBarPageIndex(this.currentTab),
        controller: this.tabsController }) {
        this.ClassicTabContents()
      }
        .width('100%')
        .height('100%')
        .barBackgroundColor(Color.Transparent)
        .barBackgroundBlurStyle(BlurStyle.COMPONENT_THICK)
        .barOverlap(true)
        .barHeight(this.tabBarHidden ? 0 : this.classicTabBarHeight())
        .scrollable(this.rootTabsAreSwipeEnabled())
        .animationDuration(ROOT_TAB_SWITCH_DURATION_MS)
        .onChange((index: number) => {
          this.onTabChange(this.bottomBarPageAt(index));
        })
        .onTabBarClick((index: number): void => {
          this.onClassicTabBarClick(index);
        })
    }
  }

  // Secondary pages are dispatched from the shared HdsNavigation stack,
  // matching PaperTalk's pageStack + HdsNavDestination structure.
  @Builder
  private NavigationBuilder(name: string): void {
    if (name === 'Notifications') {
      this.NotificationsDestination();
    } else if (name === 'PostDetail') {
      PostDetailBuilder();
    } else if (name === 'PostArticle') {
      PostArticleBuilder();
    } else if (name === 'Grok') {
      GrokBuilder();
    } else if (name === 'PostInteractions') {
      PostInteractionsBuilder();
    } else if (name === 'EditHistory') {
      EditHistoryBuilder();
    } else if (name === 'ReadAloud') {
      ReadAloudBuilder();
    } else if (name === 'ReplyComposer') {
      ReplyComposerBuilder();
    } else if (name === 'ImageEdit') {
      ImageEditBuilder();
    } else if (name === 'GifSearchPage') {
      GifSearchBuilder();
    } else if (name === 'CreatorStudio') {
      CreatorStudioBuilder();
    } else if (name === 'Settings') {
      if (this.isDesktopLayout()) {
        DesktopSettingsHost({ destinationBuilder: this.NavigationBuilder })
      } else {
        SettingsBuilder();
      }
    } else if (name === 'SettingsSection') {
      SettingsSectionBuilder();
    } else if (name === 'SidebarHandleSettings') {
      SidebarHandleSettingsBuilder();
    } else if (name === 'ProxySettings') {
      ProxySettingsBuilder();
    } else if (name === 'DownloadManager') {
      DownloadManagerBuilder();
    } else if (name === 'DataStorage') {
      DataStorageBuilder();
    } else if (name === 'LogoUniverse') {
      LogoUniverseBuilder();
    } else if (name === 'About') {
      AboutBuilder();
    } else if (name === 'HelpCenter') {
      HelpCenterBuilder();
    } else if (name === 'ProfileWeb') {
      ProfileWebBuilder();
    } else if (name === 'AccountPrivacy') {
      AccountPrivacyBuilder();
    } else if (name === 'NativeAccount') {
      NativeAccountBuilder();
    } else if (name === 'UserDetail') {
      UserDetailBuilder();
    } else if (name === 'Bookmarks') {
      BookmarksBuilder();
    } else if (name === 'UserList') {
      UserListBuilder();
    } else if (name === 'FollowDiscovery') {
      FollowDiscoveryBuilder();
    } else if (name === 'Lists') {
      ListsBuilder();
    } else if (name === 'Spaces') {
      SpacesBuilder();
    } else if (name === 'SpaceRoom') {
      SpaceRoomBuilder();
    } else if (name === 'SpaceMembers') {
      SpaceMembersBuilder();
    } else if (name === 'SpaceInfo') {
      SpaceInfoBuilder();
    } else if (name === 'SpaceDraft') {
      SpaceDraftBuilder();
    } else if (name === 'TimelineManager') {
      TimelineManagerBuilder();
    } else if (name === 'ListTimeline') {
      ListTimelineBuilder();
    } else if (name === 'ListMembers') {
      ListMembersBuilder();
    } else if (name === 'ListEditor') {
      ListEditorBuilder();
    } else if (name === 'Communities') {
      CommunitiesBuilder();
    } else if (name === 'CommunitySearch') {
      CommunitySearchBuilder();
    } else if (name === 'CommunityTimeline') {
      CommunityTimelineBuilder();
    } else if (name === 'CommunityRules') {
      CommunityRulesBuilder();
    } else if (name === 'PhotoViewer') {
      PhotoViewerBuilder();
    } else if (name === 'NotificationPosts') {
      NotificationPostsBuilder();
    } else if (name === 'BrowsingHistory') {
      BrowsingHistoryBuilder();
    } else if (name === 'VideoFeedViewer') {
      VideoFeedViewerBuilder();
    } else if (name === 'ChatVideoViewer') {
      ChatVideoViewerBuilder();
    } else if (name === 'Diagnostics') {
      DiagnosticsBuilder();
    } else if (name === 'Accounts') {
      AccountsBuilder();
    } else if (name === 'DmConversation') {
      DmConversationBuilder();
    } else if (name === 'DmCompose') {
      DmComposeBuilder();
    } else if (name === 'DmSettings') {
      DmSettingsBuilder();
    } else if (name === 'DmInfo') {
      DmInfoBuilder();
    } else if (name === 'DmGroup') {
      DmGroupBuilder();
    } else if (name === 'ChatBackground') {
      ChatBackgroundBuilder();
    } else if (name === 'DmRequests') {
      DmRequestsBuilder();
    } else if (name === 'DmWeb') {
      DmWebBuilder();
    } else if (name === 'SearchHistoryPage') {
      this.SearchHistoryPage();
    } else if (name === 'SearchResultsPage') {
      this.SearchResultsPage();
    }
  }

  @Builder
  private HdsTabContents(): void {
    if (this.isBottomBarPageEnabled(HOME_TAB_INDEX)) {
      TabContent() {
        this.HomeTab()
      }
      .tabBar(this.HdsTabBar(HOME_TAB_INDEX, $r('sys.symbol.house_fill'), $r('app.string.home_title')))
    }

    if (this.isBottomBarPageEnabled(EXPLORE_TAB_INDEX)) {
      TabContent() {
        this.ExploreTab()
      }
      .tabBar(this.HdsTabBar(EXPLORE_TAB_INDEX, $r('sys.symbol.magnifyingglass'), $r('app.string.explore_title')))
    }

    if (this.isBottomBarPageEnabled(NOTIFICATIONS_TAB_INDEX)) {
      TabContent() {
        this.NotificationsTab()
      }
      .tabBar(this.HdsTabBar(NOTIFICATIONS_TAB_INDEX, $r('sys.symbol.bell_fill'), $r('app.string.tab_alerts')))
    }

    if (this.isBottomBarPageEnabled(MESSAGES_TAB_INDEX)) {
      TabContent() {
        this.MessagesTab()
      }
      .tabBar(this.HdsTabBar(MESSAGES_TAB_INDEX, $r('sys.symbol.message_fill'), $r('app.string.chat_title')))
    }

    if (this.isBottomBarPageEnabled(ME_TAB_INDEX)) {
      TabContent() {
        this.MeTab()
      }
      .tabBar(this.HdsTabBar(ME_TAB_INDEX, $r('sys.symbol.person_fill'), $r('app.string.tab_me')))
    }
  }

  @Builder
  private ClassicTabContents(): void {
    if (this.isBottomBarPageEnabled(HOME_TAB_INDEX)) {
      TabContent() {
        this.HomeTab()
      }
      .tabBar(this.ClassicTabBar(HOME_TAB_INDEX, $r('sys.symbol.house_fill'), $r('app.string.home_title')))
    }

    if (this.isBottomBarPageEnabled(EXPLORE_TAB_INDEX)) {
      TabContent() {
        this.ExploreTab()
      }
      .tabBar(this.ClassicTabBar(EXPLORE_TAB_INDEX, $r('sys.symbol.magnifyingglass'),
        $r('app.string.explore_title')))
    }

    if (this.isBottomBarPageEnabled(NOTIFICATIONS_TAB_INDEX)) {
      TabContent() {
        this.NotificationsTab()
      }
      .tabBar(this.ClassicTabBar(NOTIFICATIONS_TAB_INDEX, $r('sys.symbol.bell_fill'),
        $r('app.string.tab_alerts')))
    }

    if (this.isBottomBarPageEnabled(MESSAGES_TAB_INDEX)) {
      TabContent() {
        this.MessagesTab()
      }
      .tabBar(this.ClassicTabBar(MESSAGES_TAB_INDEX, $r('sys.symbol.message_fill'),
        $r('app.string.chat_title')))
    }

    if (this.isBottomBarPageEnabled(ME_TAB_INDEX)) {
      TabContent() {
        this.MeTab()
      }
      .tabBar(this.ClassicTabBar(ME_TAB_INDEX, $r('sys.symbol.person_fill'), $r('app.string.tab_me')))
    }
  }

  @Builder
  private LegacyTabContents(): void {
    if (this.isBottomBarPageEnabled(HOME_TAB_INDEX)) {
      TabContent() {
        this.HomeTab()
      }
      .tabBar(this.TabBar(HOME_TAB_INDEX, $r('sys.symbol.house'), $r('sys.symbol.house_fill'),
        this.text($r('app.string.home_title'))))
    }

    if (this.isBottomBarPageEnabled(EXPLORE_TAB_INDEX)) {
      TabContent() {
        this.ExploreTab()
      }
      .tabBar(this.TabBar(EXPLORE_TAB_INDEX, $r('sys.symbol.magnifyingglass'),
        $r('sys.symbol.magnifyingglass'), this.text($r('app.string.explore_title'))))
    }

    if (this.isBottomBarPageEnabled(NOTIFICATIONS_TAB_INDEX)) {
      TabContent() {
        this.NotificationsTab()
      }
      .tabBar(this.TabBar(NOTIFICATIONS_TAB_INDEX, $r('sys.symbol.bell'), $r('sys.symbol.bell_fill'),
        this.text($r('app.string.tab_alerts'))))
    }

    if (this.isBottomBarPageEnabled(MESSAGES_TAB_INDEX)) {
      TabContent() {
        this.MessagesTab()
      }
      .tabBar(this.TabBar(MESSAGES_TAB_INDEX, $r('sys.symbol.envelope'), $r('sys.symbol.envelope'),
        this.text($r('app.string.messages_title'))))
    }

    if (this.isBottomBarPageEnabled(ME_TAB_INDEX)) {
      TabContent() {
        this.MeTab()
      }
      .tabBar(this.TabBar(ME_TAB_INDEX, $r('sys.symbol.person'), $r('sys.symbol.person_fill'),
        this.text($r('app.string.tab_me'))))
    }
  }

  @Builder
  private ClassicTabBar(index: number, icon: Resource, label: Resource): void {
    RootBottomTabItem({
      icon: icon,
      activeIcon: icon,
      label: label,
      selected: this.currentTab === index,
      unread: index === NOTIFICATIONS_TAB_INDEX ? this.unreadNotifications :
        (index === MESSAGES_TAB_INDEX ? this.unreadMessages : 0),
      floating: false,
      showLabel: this.rootTabLabelsVisible,
      accessibleLabel: this.text(label)
    })
    .width('100%')
    .height('100%')
    .padding({ bottom: Math.max(0, this.navigationIndicatorHeight) })
    .id('classic-root-tab-' + index.toString())
  }

  private classicBottomBarPages(): number[] {
    const pages: number[] = [];
    for (let page: number = 0; page < BOTTOM_BAR_PAGE_COUNT; page++) {
      if (this.isBottomBarPageEnabled(page)) {
        pages.push(page);
      }
    }
    return pages;
  }

  @Builder
  private ClassicTabTouchLayer(): void {
    // The blurred classic bar overlaps the feed. Keep the whole 56vp strip
    // tappable even where the scrolling content sits above the native bar.
    Row() {
      ForEach(this.classicBottomBarPages(), (pageIndex: number, visibleIndex: number): void => {
        Column()
          .height('100%')
          .layoutWeight(1)
          .onClick((): void => this.onClassicTabBarClick(visibleIndex))
      }, (pageIndex: number): string => pageIndex.toString())
    }
    .width('100%')
    .height(this.tabBarHidden ? 0 : this.classicTabBarHeight())
    .visibility(this.tabBarHidden ? Visibility.Hidden : Visibility.Visible)
    .accessibilityLevel('no')
  }

  @Builder
  private HdsTabBar(index: number, icon: Resource, label: Resource): void {
    RootBottomTabItem({
      icon: icon,
      activeIcon: icon,
      label: label,
      selected: this.currentTab === index,
      unread: index === NOTIFICATIONS_TAB_INDEX ? this.unreadNotifications :
        (index === MESSAGES_TAB_INDEX ? this.unreadMessages : 0),
      showLabel: this.rootTabLabelsVisible,
      accessibleLabel: this.text(label)
    })
  }

  // Fallback for systems without API 26 material support.
  @Builder
  private HomeTitle(): void {
    Row() {
      this.TitleBarIdentityRow()
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: this.statusBarHeight + 8, bottom: 8 })
    .backgroundColor(this.themedPageSurface())
  }

  // The root navigation owns the common title-bar identity row for every tab.
  @Builder
  private RootTitleBarContent(): void {
    if (this.isDesktopLayout()) { this.DesktopTitleBarContent(); }
    else { this.ImmersiveTitleBarContent(); }
  }

  @Builder
  private RootTitleBarBottomContent(): void {
    if (this.isDesktopLayout()) { this.DesktopTitleBarBottomContent(); }
    else { this.TitleBarBottomContent(); }
  }

  @Builder
  private ImmersiveTitleBarContent(): void {
    Stack({ alignContent: Alignment.TopStart }) {
      // The one and only material pane for the title bar. It lives in this top
      // slot because that is the only slot HDS lets overflow and draws above
      // the page labels: a single surface can therefore reach behind the
      // system status bar and still sit under every title-bar control.
      this.TitleBarMaterialLayer()

      Stack() {
        this.TitleBarIdentityRow()
        if (this.useTitleBarLogo() && this.chromeTab === MESSAGES_TAB_INDEX) {
          Row() {
            this.ChatTitleBarSearch()
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .position({ x: 0, y: this.statusBarHeight + 42 })
        }
      }
      .width('100%')
      .height('100%')
      .padding({ left: 12, right: 12 })
      .clip(false)
      .hitTestBehavior(HitTestMode.Transparent)

      if (this.chromeTab === EXPLORE_TAB_INDEX) {
        if (this.useTitleBarLogo() || this.activeExploreQuery.length === 0) { this.ExploreTitleBarContent() }
      } else {
        this.TitleBarLabelsBlock()
      }
    }
    .width('100%')
    .height('100%')
    .clip(false)
    .hitTestBehavior(HitTestMode.Transparent)
    .onAreaChange((_oldValue: Area, newValue: Area): void => {
      this.captureTitleBarSurfaceTop(newValue);
    })
  }

  @Builder
  private ExploreTitleBarContent(): void {
    Column({ space: 0 }) {
      if (this.useTitleBarLogo()) {
        Row() { this.ExploreTitleBarSearch() }
          .width('100%').justifyContent(FlexAlign.Center)
          .padding({ top: $r('app.float.title_bar_compact_gap') }).flexShrink(0)
      }
      if (this.activeExploreQuery.length === 0) {
        Column() { this.ExploreCategoryTabs() }
          .width('100%').padding({ top: $r('app.float.title_bar_compact_gap') }).flexShrink(0)
      }
    }.width('100%').padding({ left: 12, right: 12 })
      .margin({ top: this.exploreTitleContentOffset() })
      .id('harmonyx-explore-title-content')
      .clip(false).hitTestBehavior(HitTestMode.Transparent)
  }

  private exploreTitleContentOffset(): number {
    return Math.max(0, this.exploreTitleIdentityBottom - this.titleBarSurfaceTop);
  }

  private captureExploreTitleIdentity(area: Area): void {
    // The retained identity row may keep its bounds when switching to Explore,
    // so cache its measurement on every phone tab rather than waiting for remount.
    if (this.isDesktopLayout()) { return; }
    const bottom: number = Number(area.globalPosition.y) + Number(area.height) + this.titleBarIdentityOffset();
    if (Number(area.height) > 0 && Math.abs(bottom - this.exploreTitleIdentityBottom) > 0.5) {
      this.exploreTitleIdentityBottom = bottom;
    }
    if (this.chromeTab === EXPLORE_TAB_INDEX && !this.useTitleBarLogo() && this.activeExploreQuery.length > 0) {
      if (Math.abs(bottom - this.exploreTitleContentBottom) > 0.5) { this.exploreTitleContentBottom = bottom; }
    }
  }

  private captureExploreTitleContent(area: Area): void {
    if (this.chromeTab !== EXPLORE_TAB_INDEX || this.isDesktopLayout()) { return; }
    // The native top slot constrains its builder's outer height. Read the
    // final visible row's actual bottom, including overflow, instead.
    const bottom: number = Number(area.globalPosition.y) + Number(area.height);
    if (Number(area.height) > 0 && Math.abs(bottom - this.exploreTitleContentBottom) > 0.5) {
      this.exploreTitleContentBottom = bottom;
    }
  }

  @Builder
  private ExploreContentTopSpacer(): void {
    Column().width('100%').height(this.exploreContentTopInset())
  }

  private captureExploreContentTop(area: Area): void {
    const top: number = Number(area.globalPosition.y);
    if (Math.abs(top - this.exploreContentTop) > 0.5) { this.exploreContentTop = top; }
  }

  private captureTitleBarSurfaceTop(area: Area): void {
    const top: number = Number(area.globalPosition.y);
    if (top > 0 && Math.abs(top - this.titleBarSurfaceTop) > 0.5) {
      this.titleBarSurfaceTop = top;
    }
  }

  private captureTitleBarSurfaceBottom(area: Area): void {
    if (this.chromeTab === EXPLORE_TAB_INDEX && !this.isDesktopLayout()) {
      const titleHeight: number = Number(area.globalPosition.y) - this.titleBarSurfaceTop;
      if (titleHeight > 0 && Math.abs(titleHeight - this.exploreNativeTitleHeight) > 0.5) {
        this.exploreNativeTitleHeight = titleHeight;
      }
    }
    const bottom: number = Number(area.globalPosition.y) + Number(area.height);
    if (bottom > 0 && Math.abs(bottom - this.titleBarSurfaceBottom) > 0.5) {
      this.titleBarSurfaceBottom = bottom;
    }
  }

  // The page-label row. It is rendered here, above the material, because HDS's
  // own label slot is drawn below the top slot and would bury it under the
  // surface. The offset keeps it exactly where that slot used to place it.
  @Builder
  private TitleBarLabelsBlock(): void {
    if (this.titleBarLabelsHeight() > 0) {
      Column({ space: 0 }) {
        if (this.chromeTab === HOME_TAB_INDEX) {
          if (this.useTitleBarLogo()) { this.HomeFeedSwitch() }
          if (this.homeSpace() !== null) {
            Row() { this.HomeSpaceCapsule(); }.width('100%').height(60).justifyContent(FlexAlign.Center)
          }
        } else if (this.chromeTab === 1 && this.activeExploreQuery.length === 0) {
          this.ExploreCategoryTabs()
        } else if (this.chromeTab === NOTIFICATIONS_TAB_INDEX && this.useTitleBarLogo()) {
          this.NotificationTabs(false)
        }
      }
      .width('100%')
      .height(this.titleBarLabelsHeight())
      // margin rather than position: a positioned stack would wrap its content
      // and lose the row height the HDS label slot used to provide.
      .margin({ top: this.titleBarLabelsOffset() })
      .translate({ y: this.useTitleBarLogo() && this.chromeTab === HOME_TAB_INDEX && this.homeHeaderCollapsed ?
        -HOME_HEADER_COLLAPSE_TRANSLATE_VP : 0 })
      .clip(false)
      // 这一层比页签本身高，上方那段空白会压住探索页搜索框的下半部分。Transparent
      // 让空白处不拦触摸、直接透给后面的搜索框，页签按钮仍然自己吃掉点击。
      .hitTestBehavior(HitTestMode.Transparent)
    }
  }

  // Height of the one material pane, from the very top of the screen down to
  // the real bottom of the title-bar content on the current page. The pane is
  // mounted at the material slot's top and lifted by that same top edge, so a
  // global bottom reading is exactly the height it needs.
  private titleBarMaterialExtent(): number {
    if (this.chromeTab === EXPLORE_TAB_INDEX && this.exploreTitleContentBottom > 0) {
      return Math.max(this.exploreTitleContentBottom, this.titleBarSurfaceTop + this.exploreNativeTitleHeight) +
        TITLE_BAR_SURFACE_OVERSCAN_VP;
    }
    if (this.rootTitleBarBottomHeight() === 0) {
      return this.titleBarSurfaceTop + TITLE_BAR_TITLE_SLOT_HEIGHT_VP + TITLE_BAR_SURFACE_OVERSCAN_VP;
    }
    if (this.titleBarSurfaceBottom > 0) {
      return this.titleBarSurfaceBottom + TITLE_BAR_SURFACE_OVERSCAN_VP;
    }
    return this.titleBarSurfaceTop + TITLE_BAR_TITLE_SLOT_HEIGHT_VP + TITLE_BAR_SURFACE_OVERSCAN_VP;
  }

  private titleBarLabelsHeight(): number {
    return RootTitleBarLayout.labelsHeight(this.chromeTab, this.useTitleBarLogo(),
      this.homeSpaceHeight(), this.activeExploreQuery.length > 0);
  }

  private titleBarLabelsOffset(): number {
    return RootTitleBarLayout.labelsOffset(this.chromeTab, this.useTitleBarLogo());
  }

  private titleBarIdentityOffset(): number {
    if (this.useTitleBarLogo()) { return 0; }
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    return this.getUIContext().px2vp(context.resourceManager.getNumber(
      $r('app.float.title_bar_compact_vertical_offset').id));
  }

  // 玻璃面板的宽度：窗口宽再左右各加一段过扫，配合同量的横向位移，让左右边缘
  // 都落到屏幕外被裁掉，边上就不会露缝。
  private titleBarMaterialWidth(): number {
    const width: number = this.windowWidth > 0 ? this.windowWidth : 390;
    return width + TITLE_BAR_SURFACE_OVERSCAN_VP * 2;
  }

  @Builder
  private TitleBarMaterialLayer(): void {
    // 只有"玻璃材质"这一档才挂我们自制的这块玻璃面板；另外两档完全交给 HDS
    // 自己的标题栏样式，所以这里连背景都不留。
    if (customTitleBarGlassEnabled(this.titleBarStyleMode)) {
      if (this.supportsImmersiveMaterial()) {
        Column()
          // Size and place the surface by hand: it is oversized on the top, left
          // and right, then shifted by half that overscan, so all three edges sit
          // outside the physical screen and get clipped there. That removes any
          // hairline gap against the status bar or the side edges, while the
          // bottom edge stays on the measured title-bar bottom.
          .height(this.titleBarMaterialExtent())
          .width(this.titleBarMaterialWidth())
          .offset({ x: -TITLE_BAR_SURFACE_OVERSCAN_VP,
            y: -this.titleBarSurfaceTop - TITLE_BAR_SURFACE_OVERSCAN_VP })
          .backgroundColor(Color.Transparent)
          .systemMaterial(this.titleBarMaterialCache.material(this.titleBarGlassMaterialLevel))
          .hitTestBehavior(HitTestMode.None)
      } else {
        Column()
          .height(this.titleBarMaterialExtent())
          .width(this.titleBarMaterialWidth())
          .offset({ x: -TITLE_BAR_SURFACE_OVERSCAN_VP,
            y: -this.titleBarSurfaceTop - TITLE_BAR_SURFACE_OVERSCAN_VP })
          .backgroundColor(this.themedTitleBarScrim())
          .hitTestBehavior(HitTestMode.None)
      }
    }
  }

  // Fallback Navigation keeps the same account identity header for every
  // root tab: avatar on the left, brand in the middle and live status right.
  @Builder
  private RootNavigationTitle(): void {
    Column() {
      this.HomeTitle()
      if (this.useTitleBarLogo()) {
        if (this.chromeTab === HOME_TAB_INDEX) { this.HomeFeedSwitch() }
        else if (this.chromeTab === NOTIFICATIONS_TAB_INDEX) { this.NotificationTabs(false) }
        else if (this.chromeTab === EXPLORE_TAB_INDEX) { this.ExploreTitleBarSearch() }
        else if (this.chromeTab === MESSAGES_TAB_INDEX) { this.ChatTitleBarSearch() }
      }
      if (this.chromeTab === 0 && this.homeSpace() !== null) {
        Row() { this.HomeSpaceCapsule(); }.width('100%').height(60).justifyContent(FlexAlign.Center)
      }
    }.width('100%')
  }

  @Builder
  private TitleBarBottomContent(): void {
    // The labels are rendered in the material slot above. This empty stack
    // reserves the remaining title-bar height and tracks the material pane's
    // bottom edge; Home shortens it after the labels move beside the avatar.
    Stack() {
    }
    .width('100%')
    .height('100%')
    .onAreaChange((_oldValue: Area, newValue: Area): void => {
      this.captureTitleBarSurfaceBottom(newValue);
    })
  }

  private homeTabItems(): IconTabItem[] {
    const items: IconTabItem[] = [
      { key: 'for-you', label: $r('app.string.home_for_you') },
      { key: 'following', label: $r('app.string.home_following') }
    ];
    for (let i: number = 0; i < this.pinnedHomeTopics.length; i++) {
      const topic: TimelineTopic = this.pinnedHomeTopics[i];
      items.push({ key: topic.id, label: topic.title });
    }
    return items;
  }

  private homeTabIndex(): number {
    if (this.activeHomeTopicId.length === 0) { return this.homeFeedMode; }
    const index: number = this.pinnedHomeTopics.findIndex((topic: TimelineTopic): boolean => topic.id === this.activeHomeTopicId);
    return index >= 0 ? index + 2 : this.homeFeedMode;
  }

  private selectHomeIconTab(index: number): void {
    if (index !== this.homeTabIndex()) { this.homePager.changeIndex(index, true); }
    else if (index < 2) { this.openHomeTimelineOptions(index); }
  }

  private isBaseHomeFeedSelected(mode: number): boolean {
    return this.activeHomeTopicId.length === 0 && this.homeFeedMode === mode;
  }

  @Builder
  private HomeIconTabs(height: number): void {
    Row({ space: 4 }) {
      AnimatedIconTabs({ items: this.homeTabItems(), selected: this.homeTabIndex(), tabPosition: this.homeTabPosition,
        barHeight: height, equalWidth: true,
        buttonStyle: !this.useTitleBarLogo() && this.compactSwitchStyle === COMPACT_SWITCH_BUTTONS,
        onSelect: (index: number): void => this.selectHomeIconTab(index),
        onOptions: (index: number): void => this.openHomeTimelineOptions(index) }).layoutWeight(1)
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.plus')).fontSize(18).fontColor([$r('app.color.text_secondary')])
      }.width(32).height(36).padding(6).margin({ right: 12 }).backgroundColor(Color.Transparent)
        .id('home-manage-timelines').accessibilityText(this.text($r('app.string.timeline_manage')))
        .onClick((): void => this.openTimelineManager())
    }.width('100%').height(height)
  }

  @Builder
  private HomeFeedSwitch(): void { this.HomeIconTabs(TITLE_BAR_LABELS_HOME_HEIGHT_VP) }

  @Builder
  private CompactTitleBarCenter(): void {
    if (this.chromeTab === HOME_TAB_INDEX) { this.HomeTimelinePills() }
    else if (this.chromeTab === EXPLORE_TAB_INDEX) { this.ExploreTitleBarSearch() }
    else if (this.chromeTab === MESSAGES_TAB_INDEX) { this.ChatTitleBarSearch() }
    else if (this.chromeTab === NOTIFICATIONS_TAB_INDEX) { this.NotificationTabs(true) }
    else { Blank() }
  }

  @Builder
  private HomeTimelinePills(): void { this.HomeIconTabs(36) }

  @Builder
  private NotificationTabs(compact: boolean): void {
    AnimatedIconTabs({ items: [
      { key: 'all', label: $r('app.string.notifications_all'), icon: $r('sys.symbol.bell') },
      { key: 'mentions', label: $r('app.string.notifications_mentions'), icon: $r('sys.symbol.at') },
      { key: 'verified', label: $r('app.string.notifications_verified'), icon: $r('sys.symbol.checkmark_circle_fill') }
    ], selected: this.notificationFilter, tabPosition: this.notificationTabPosition, barHeight: compact ? 36 : 52,
      buttonStyle: compact && this.compactSwitchStyle === COMPACT_SWITCH_BUTTONS,
      onSelect: (index: number): void => { this.notificationPager.changeIndex(index, true); } })
  }

  @Builder
  private NotificationSettingsButton(): void {
    Button({ type: ButtonType.Circle }) {
      SymbolGlyph($r('sys.symbol.gearshape')).fontSize(24).fontColor([$r('app.color.text_primary')])
    }.width(36).height(36).padding(4).backgroundColor(Color.Transparent)
      .accessibilityText(this.text($r('app.string.settings_notifications')))
      .onClick((): void => {
        this.openContentDestination();
        const param: SettingsRouteParam = { section: 'notifications' };
        this.navPathStack.pushPath({ name: 'SettingsSection', param: param });
      })
  }

  @Builder
  private PauseTopicsSheetContent(): void {
    PauseTopicsSheet();
  }

  @Builder
  private FollowingOrderSheetContent(): void {
    FollowingOrderSheet({ onManage: (): void => {
      this.manageTimelinesAfterDismiss = true;
      this.showFollowingOrder = false;
    } });
  }

  @Builder
  private TitleBarIdentityRow(): void {
    Stack({ alignContent: Alignment.Center }) {
      Row() {
        Button({ type: ButtonType.Normal, stateEffect: true }) {
          if (this.titleBarAvatarUrl().length > 0) {
            ProxyAvatar({verifiedType: this.profile?.verifiedType ?? '', avatarShape: this.profile?.avatarShape ?? '',  url: this.titleBarAvatarUrl(), avatarSize: 36, radius: 18,
              fallbackText: this.avatarInitial(), fallbackColor: this.accentColor })
          } else {
            Text(this.avatarInitial()).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_L'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_on_accent'))
          }
        }
        .width(36)
        .height(36)
        .borderRadius(userAvatarRadius(36, 18, this.profile?.verifiedType ?? '', this.profile?.avatarShape ?? ''))
        .padding(0)
        .backgroundColor(this.titleBarAvatarUrl().length > 0 ? Color.Transparent : this.accentColor)
        .accessibilityText(this.text($r('app.string.tab_me')))
        .onClick((): void => this.openSideDrawer())
        if (!this.useTitleBarLogo()) {
          Row() { this.CompactTitleBarCenter() }
            .layoutWeight(1).height($r('app.float.title_bar_compact_row_height'))
            .margin({ left: $r('app.float.title_bar_compact_gap'), right: $r('app.float.title_bar_compact_gap') })
        } else { Blank() }
        if (this.chromeTab === MESSAGES_TAB_INDEX) { this.ChatFilterButton() }
        else if (this.chromeTab === NOTIFICATIONS_TAB_INDEX) { this.NotificationSettingsButton() }
        else { this.AddFollowButton() }
      }
      .width('100%')

      if (this.useTitleBarLogo()) {
      Image($r('app.media.ui_brand_foreground'))
        .width(30)
        .height(30)
        .objectFit(ImageFit.Contain)
        .borderRadius(15)
        .clip(true)
        .opacity(this.chromeTab === HOME_TAB_INDEX && this.homeHeaderCollapsed ? 0 : 1)
        .gesture(
          TapGesture({ count: 2 })
            .onAction((): void => {
              this.onboardingLoginOnly = false;
              this.onboardingAddAccount = false;
              this.showOnboardingGuide = true;
            })
        )
      }
    }
    .width('100%')
    .height(this.useTitleBarLogo() ? 36 : $r('app.float.title_bar_compact_row_height'))
    .translate({ y: this.titleBarIdentityOffset() })
    .id('harmonyx-root-identity-row')
    .onAreaChange((_oldValue: Area, newValue: Area): void => { this.captureExploreTitleIdentity(newValue); })
  }

  private avatarInitial(): string {
    if (this.handleText.length > 1) {
      return this.handleText.substring(1, 2).toUpperCase();
    }
    return 'O';
  }

  @Builder
  private AddFollowButton(): void {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      Stack({ alignContent: Alignment.TopEnd }) {
        SymbolGlyph($r('sys.symbol.person_badge_plus'))
          .fontSize($r('app.float.follow_header_symbol_size'))
          .fontColor([$r('app.color.text_primary')])
        if (this.liveBadge.length > 0) {
          Column().width($r('app.float.follow_status_dot_size')).height($r('app.float.follow_status_dot_size'))
            .backgroundColor($r('app.color.repost')).borderRadius(5)
            .border({ width: 1.5, color: $r('app.color.bg_page') }).offset({ x: 2, y: -2 })
        }
      }
    }.width(36).height(36).padding(4).backgroundColor(Color.Transparent)
      .accessibilityText(this.text($r('app.string.follow_add_button')))
      .onClick((): void => {
        this.openContentDestination();
        const param: FollowDiscoveryRouteParam = { tab: 0, contextualUserId: '' };
        this.navPathStack.pushPath({ name: 'FollowDiscovery', param: param });
      })
  }

  private titleBarAvatarUrl(): string {
    if (this.profile === null || this.profile.avatarUrl === undefined) {
      return '';
    }
    return this.profile.avatarUrl;
  }

  private profileCardSeed(): string {
    if (this.profile !== null) {
      if (this.profile.avatarUrl !== undefined && this.profile.avatarUrl.length > 0) {
        return this.profile.avatarUrl;
      }
      if (this.profile.username.length > 0) {
        return this.profile.username;
      }
      if (this.profile.name.length > 0) {
        return this.profile.name;
      }
    }
    if (this.handleText.length > 0) {
      return this.handleText;
    }
    return this.accentColor;
  }

  private profileCardBannerUrl(): string {
    if (this.profile !== null && this.profile.bannerUrl !== undefined && this.profile.bannerUrl.length > 0) {
      return this.profile.bannerUrl;
    }
    return '';
  }

  private profileCardHue(): number {
    const seed: string = this.profileCardSeed();
    let hash: number = 17;
    for (let i: number = 0; i < seed.length; i++) {
      hash = (hash * 131 + seed.charCodeAt(i)) % 3600;
    }
    return hash % 360;
  }

  private profileCardColor(lightness: number, hueOffset: number): number {
    let hue: number = this.profileCardHue() + hueOffset;
    while (hue >= 360) {
      hue -= 360;
    }
    while (hue < 0) {
      hue += 360;
    }
    return this.hslColor(hue, 0.62, lightness, 255);
  }

  private hslColor(hue: number, saturation: number, lightness: number, alpha: number): number {
    const c: number = (1 - Math.abs(2 * lightness - 1)) * saturation;
    const segment: number = hue / 60;
    const x: number = c * (1 - Math.abs((segment % 2) - 1));
    let r1: number = 0;
    let g1: number = 0;
    let b1: number = 0;
    if (segment < 1) {
      r1 = c;
      g1 = x;
    } else if (segment < 2) {
      r1 = x;
      g1 = c;
    } else if (segment < 3) {
      g1 = c;
      b1 = x;
    } else if (segment < 4) {
      g1 = x;
      b1 = c;
    } else if (segment < 5) {
      r1 = x;
      b1 = c;
    } else {
      r1 = c;
      b1 = x;
    }
    const m: number = lightness - c / 2;
    return this.argbColor(alpha, Math.round((r1 + m) * 255),
      Math.round((g1 + m) * 255), Math.round((b1 + m) * 255));
  }

  private argbColor(alpha: number, red: number, green: number, blue: number): number {
    return this.clampChannel(alpha) * 16777216 + this.clampChannel(red) * 65536 +
      this.clampChannel(green) * 256 + this.clampChannel(blue);
  }

  private clampChannel(value: number): number {
    if (value < 0) {
      return 0;
    }
    if (value > 255) {
      return 255;
    }
    return Math.round(value);
  }

  @Builder
  private TabBar(index: number, icon: Resource, activeIcon: Resource, label: string): void {
    RootBottomTabItem({
      icon: icon,
      activeIcon: activeIcon,
      label: label,
      selected: this.currentTab === index,
      unread: index === NOTIFICATIONS_TAB_INDEX ? this.unreadNotifications :
        (index === MESSAGES_TAB_INDEX ? this.unreadMessages : 0),
      floating: false,
      showLabel: this.rootTabLabelsVisible,
      accessibleLabel: label
    }).padding({ bottom: 10 })
  }

  @Builder
  private HomePost(tweet: Tweet, index: number, postIndex: number, postCount: number): void {
    Column() {
    if (postIndex === 0) {
      ForEach((index === this.homeTabIndex() ? this.homeSuggestionGroups : this.homeSnapshotAt(index).suggestions).filter((group: FollowSuggestionGroup): boolean => group.afterTweetId.length === 0),
        (group: FollowSuggestionGroup) => { FollowSuggestions({ group: group }) },
        (group: FollowSuggestionGroup): string => group.id)
    }
    TweetCard({
      tweet: tweet,
      videoFeedEnabled: true,
      homeTimelineVideo: true,
      recordRecommendationSeen: index === 0,
      naturalVideoSize: true,
      onLikeChanged: (tt: Tweet, liked: boolean) => this.onLike(tt, liked),
      onRepostChanged: (tt: Tweet, reposted: boolean) => this.onRepost(tt, reposted),
      onReply: (tt: Tweet) => this.onReply(tt),
      onOpen: (tt: Tweet): void => this.openPost(tt),
      onVideoOpen: (tt: Tweet, media: MediaAttachment): void => this.openVideoFeed(tt, media),
      onAuthorTapped: (tt: Tweet) => this.openUser(tt),
      onMentionTapped: (handle: string) => this.openMention(handle)
    })
    ForEach((index === this.homeTabIndex() ? this.homeSuggestionGroups : this.homeSnapshotAt(index).suggestions).filter((group: FollowSuggestionGroup): boolean => group.afterTweetId === tweet.id),
      (group: FollowSuggestionGroup) => { FollowSuggestions({ group: group }) },
      (group: FollowSuggestionGroup): string => group.id)
    if (index === 1 && this.hasCookieSession && (index === this.homeTabIndex() ? this.homeSuggestionGroups : this.homeSnapshotAt(index).suggestions).length === 0 &&
      postIndex === Math.min(2, postCount - 1)) {
      FollowSuggestions({ autoLoad: true })
    }
    }.width('100%')
  }

  @Builder
  private HomeStatusLine(index: number = this.homeTabIndex()): void {
    Column() {
      if (this.isDesktopLayout()) { this.DesktopInlineComposer() }
      else { Column().width('100%').height(this.homeContentTopInset()) }
      if (this.filteredTimeline(index).length === 0 &&
        (index === this.homeTabIndex() ? this.loading : !this.homeSnapshotAt(index).loaded)) {
        LoadingProgress().width(18).height(18).color(this.accentColor).margin({ top: 32, bottom: 16 })
      }
    }.width('100%').padding({ top: this.isDesktopLayout() ? this.homeContentTopInset() : 0 })
  }

  @Builder
  private HomeTimelineFooter(index: number = this.homeTabIndex()): void {
    Row() {
      if (index === this.homeTabIndex() && this.loadingMore) {
        LoadingProgress()
          .width(18)
          .height(18)
          .color(this.accentColor)
          .margin({ top: 14, bottom: 14 })
      } else {
        Text((index === this.homeTabIndex() ? this.hasMoreTimeline : this.homeSnapshotAt(index).hasMore) ? $r('app.string.timeline_load_more') : $r('app.string.timeline_no_more')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 16, bottom: 16 })
      }
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private HomePageItem(item: TimelinePageItem, index: number): void {
    if (item.key === 'header') { this.HomeStatusLine(index) }
    else if (item.key === 'footer') { this.HomeTimelineFooter(index) }
    else if (item.promotion !== null) { this.HomePromotion(item.promotion as XXAuthPromotionPost) }
    else if (item.tweet !== null) {
      this.HomePost(item.tweet as Tweet, index, item.postIndex, this.homePageDataSource(index).postCount())
    }
  }

  @Builder
  private HomePromotion(post: XXAuthPromotionPost): void {
    PromotionPostCard({
      post: post,
      onOpen: (): void => { this.openPromotionLink(post.link); },
      onHideSession: (): void => { this.hidePromotionForSession(); },
      onHideWeek: (): void => { this.hidePromotionPost(); }
    })
  }

  @Builder
  private HomeList(index: number): void {
    List({ space: 0, scroller: this.contentPageScroller('home', this.homeTabItems()[index].key) }) {
      LazyForEach(this.homePageDataSource(index), (item: TimelinePageItem) => {
        ListItem() { this.HomePageItem(item, index) }.width('100%')
      }, (item: TimelinePageItem): string => item.key)
    }
    .width('100%')
    .height('100%')
    .id('harmonyx-home-list-' + this.homeTabItems()[index].key)
    .backgroundColor(this.themedPageSurface())
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .scrollBar(BarState.Off)
    .contentEndOffset(this.contentBottomInset())
    .clipContent(this.isDesktopLayout() ? ContentClipMode.SAFE_AREA : ContentClipMode.BOUNDARY)
    .clip(!this.isDesktopLayout())
    .nestedScroll({ scrollForward: NestedScrollMode.SELF_FIRST, scrollBackward: NestedScrollMode.SELF_FIRST })
    .cachedCount(4, this.isDesktopLayout())
    .onScrollIndex((first: number, last: number): void => {
      if (index === this.homeTabIndex()) {
        this.rememberHomeVisibleItem(first);
        if (!this.homeViewportChanging && last >= this.timeline.length - 6) { this.requestMoreTimeline(); }
      }
    })
    .onDidScroll((offset: number): void => { if (index === this.homeTabIndex()) { this.onFeedScroll(offset); } })
    .onScrollStop((): void => { if (index === this.homeTabIndex()) { this.onFeedScrollStop(); } })
    .onReachEnd((): void => {
      if (index === this.homeTabIndex() && !this.homeViewportChanging) { this.requestMoreTimeline(); }
    })
    .onAreaChange((): void => { if (index === this.homeTabIndex()) { this.scheduleHomeViewportRestore(); } })
    .onAppear((): void => this.onHomeViewportAppear(index, 'list'))
    .onDisAppear((): void => this.onHomeViewportDisappear(index, 'list'))
  }

  @Builder
  private HomeWaterFlow(index: number): void {
      WaterFlow({ scroller: this.contentPageScroller('home', this.homeTabItems()[index].key),
        sections: this.pageSections('home', this.homeTabItems()[index].key, this.filteredTimeline(index).length),
        layoutMode: WaterFlowLayoutMode.SLIDING_WINDOW }) {
        LazyForEach(this.homePageDataSource(index), (item: TimelinePageItem) => {
          FlowItem() { this.HomePageItem(item, index) }.width('100%')
        }, (item: TimelinePageItem): string => item.key)
      }
      .columnsTemplate(this.timelineColumnsTemplate())
      .columnsGap(1)
      .rowsGap(0)
      .width('100%')
      .height('100%')
      .id('harmonyx-home-flow-' + this.homeTabItems()[index].key)
      .backgroundColor(this.themedPageSurface())
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .scrollBar(BarState.Off)
      .contentEndOffset(this.contentBottomInset())
      .clipContent(this.isDesktopLayout() ? ContentClipMode.SAFE_AREA : ContentClipMode.BOUNDARY)
      .clip(!this.isDesktopLayout())
      .nestedScroll({ scrollForward: NestedScrollMode.SELF_FIRST, scrollBackward: NestedScrollMode.SELF_FIRST })
      .cachedCount(8, this.isDesktopLayout())
      .onScrollIndex((first: number, last: number): void => {
        if (index === this.homeTabIndex()) { this.rememberHomeVisibleItem(first); }
        if (index === this.homeTabIndex() && !this.homeViewportChanging && last >= this.timeline.length - 6) {
          this.requestMoreTimeline();
        }
      })
      .onDidScroll((scrollOffset: number): void => {
        if (index === this.homeTabIndex()) { this.onFeedScroll(scrollOffset); }
      })
      .onScrollStop((): void => {
        if (index === this.homeTabIndex()) { this.onFeedScrollStop(); }
      })
      .onReachEnd((): void => {
        if (index === this.homeTabIndex() && !this.homeViewportChanging) { this.requestMoreTimeline(); }
      })
      .onAreaChange((): void => { if (index === this.homeTabIndex()) { this.scheduleHomeViewportRestore(); } })
      .onAppear((): void => this.onHomeViewportAppear(index, 'flow'))
      .onDisAppear((): void => this.onHomeViewportDisappear(index, 'flow'))

  }

  @Builder
  // Refresh draws its own spinner at the top of its container, which on the
  // phone layout sits behind the title-bar material and would show through as
  // a second, blurred spinner next to RootRefreshIndicator. A custom refresh
  // region replaces that spinner while keeping the pull displacement itself.
  private HiddenRefreshSpinner(): void {
    Column().width('100%').height('1vp')
  }

  @Builder
  private HomeTab(): void {
    Stack({ alignContent: Alignment.Top }) {
    Refresh({ refreshing: $$this.refreshing, builder: this.HiddenRefreshSpinner() }) {
      Swiper(this.homePager) {
        ForEach(this.homeTabItems(), (item: IconTabItem, index: number) => {
          // The scroll container keeps its identity while data arrives and while
          // the adjacent page slides into view; no recognizer is replaced mid-drag.
          if (this.useTimelineWaterFlow()) { this.HomeWaterFlow(index) }
          else { this.HomeList(index) }
        }, (item: IconTabItem): string => item.key)
      }.width('100%').height('100%').index(this.homeTabIndex()).loop(false).indicator(false).cachedCount(1)
        .duration(280).curve(Curve.EaseOut).clip(true).disableSwipe(this.refreshing)
        .onAppear((): void => { this.homeTabPosition = this.homeTabIndex(); })
        .onChange((index: number): void => {
          if (index < 2) { this.changeHomeFeed(index); }
          else { this.selectHomeTopic(this.pinnedHomeTopics[index - 2]); }
        })
        .onContentDidScroll((_selected: number, index: number, position: number, _length: number): void => {
          this.homeTabPosition = ProfileTabMotion.scrollPosition(index, position, this.homeTabItems().length);
        })
        .onAnimationEnd((index: number): void => { this.homeTabPosition = index; })
    }.width('100%').height('100%')
      .onOffsetChange((offset: number): void => { this.homeRefreshPullOffset = offset; })
      .onRefreshing((): void => {
      if (this.homeViewportChanging) { this.refreshing = false; } else { this.onRefresh(this.homePullRefreshLatest); }
    })
    RootRefreshIndicator({ topInset: this.homeContentTopInset(), pullOffset: this.homeRefreshPullOffset,
      refreshing: this.refreshing, phoneLayout: !this.isDesktopLayout() })
    }.width('100%').height('100%')
  }

  @Builder
  private ExploreHome(index: number): void {
      List({ scroller: this.contentPageScroller('explore', EXPLORE_CATEGORY_IDS[index]) }) {
      ListItem() {
        if (this.supportsHdsNavigation()) {
          this.ExploreContentTopSpacer()
        } else {
          this.LegacyExploreSearchBar()
        }
      }

      ListItem() {
        if (!this.supportsHdsNavigation()) {
          this.ExploreCategoryTabs()
        }
      }

      // Keep the first payload card clear of the category divider/material.
      ListItem() {
        Column()
          .width('100%')
          .height(15)
      }

      if (this.exploreCategoryPages[index].status.length > 0) {
        ListItem() {
          Text(this.exploreCategoryPages[index].status).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_S'))
            .fontColor($r('app.color.text_secondary'))
            .width('92%')
            .padding({ top: 4, bottom: 8 })
        }
      }

      if (this.exploreCategoryPages[index].loading && this.exploreCategoryPages[index].cards.length === 0 &&
        this.exploreCategoryPages[index].posts.length === 0) {
        ListItem() {
          LoadingProgress()
            .width(28)
            .height(28)
            .color(this.accentColor)
            .margin({ top: 48, bottom: 48 })
        }
        .width('100%')
        .align(Alignment.Center)
      } else if (this.visibleExploreCards(index).length > 0) {
        ForEach(this.visibleExploreCards(index), (card: XExploreTimelineCard) => {
          ListItem() {
            this.ExploreTimelineCard(card)
          }
        }, (card: XExploreTimelineCard) => 'explore-card-' + card.key)
      } else {
        if (index === 0 && this.trends.length > 0) {
          ForEach(this.trends, (trend: string) => {
            ListItem() {
              this.ExploreTrendRow(trend)
            }
          }, (trend: string) => 'explore-home-fallback-trend-' + trend)
        } else if (!this.exploreCategoryPages[index].loading) {
          ListItem() {
            Text(this.exploreCategoryPages[index].status.length > 0 ? this.exploreCategoryPages[index].status :
              $r('app.string.explore_section_empty')).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_L'))
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ top: 48, bottom: 48 })
          }
        }
      }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.themedPageSurface())
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .scrollBar(BarState.Off)
      .contentEndOffset(this.contentBottomInset())
      .clipContent(this.isDesktopLayout() ? ContentClipMode.SAFE_AREA : ContentClipMode.BOUNDARY)
      .clip(!this.isDesktopLayout())
      .nestedScroll({ scrollForward: NestedScrollMode.SELF_FIRST, scrollBackward: NestedScrollMode.SELF_FIRST })
      .cachedCount(8, this.isDesktopLayout())

  }

  @Builder
  private ExploreTimelineCard(card: XExploreTimelineCard): void {
    if (card.kind === 'hero' && card.hero !== null) {
      this.ExploreHeroCard(card.hero)
    } else if (card.kind === 'frame' && card.frame !== null) {
      this.ExploreFrameCard(card.frame)
    } else if (card.kind === 'trend') {
      this.ExploreTrendGroup(card)
    } else if (card.kind === 'users') {
      this.ExploreUserGroup(card)
    } else if (card.kind === 'tweets') {
      this.ExplorePostGroup(card)
    }
  }

  @Builder
  private ExploreCardTitle(title: string): void {
    if (title.length > 0) {
      Text(title).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Title_M'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('92%')
        .padding({ top: 14, bottom: 6 })
    }
  }

  @Builder
  private ExploreTrendGroup(card: XExploreTimelineCard): void {
    Column({ space: 0 }) {
      this.ExploreCardTitle(card.title)
      ForEach(card.trends, (item: XExploreTrend) => {
        this.ExploreRichTrendRow(item)
      }, (item: XExploreTrend) => 'explore-card-trend-' + card.key + '-' + item.name)
      if (card.footerText.length > 0) {
        Text(card.footerText).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M'))
          .fontColor(this.accentColor)
          .width('92%')
          .padding({ top: 12, bottom: 14 })
          .onClick((): void => {
            this.openExploreDestination(card.footerUrl);
          })
      }
    }
    .width('100%')
  }

  @Builder
  private ExploreUserGroup(card: XExploreTimelineCard): void {
    Column({ space: 0 }) {
      this.ExploreCardTitle(card.title)
      ForEach(card.users, (row: UserRow) => {
        UserRowCard({
          row: row,
          onOpen: (r: UserRow): void => this.openUserRow(r),
          onFollowChanged: (r: UserRow, next: boolean): Promise<boolean> => this.applyRowFollow(r, next)
        })
      }, (row: UserRow) => 'explore-card-user-' + card.key + '-' + row.id)
      if (card.footerText.length > 0) {
        Text(card.footerText).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M'))
          .fontColor(this.accentColor)
          .width('92%')
          .padding({ top: 12, bottom: 14 })
          .onClick((): void => {
            this.openExploreDestination(card.footerUrl);
          })
      }
    }
    .width('100%')
  }

  @Builder
  private ExplorePostGroup(card: XExploreTimelineCard): void {
    Column({ space: 0 }) {
      this.ExploreCardTitle(card.title)
      ForEach(contentFilterStore.filter(card.tweets, this.contentFilterSettings()), (tweet: Tweet) => {
        this.ExploreTweetCard(tweet)
      }, (tweet: Tweet) => 'explore-card-post-' + card.key + '-' + tweet.id)
    }
    .width('100%')
  }

  @Builder
  private ExploreFrameCard(frame: XExploreFrame): void {
    if (frame.variant === 'banner') {
      this.ExploreFrameBanner(frame)
    } else {
      this.ExploreMatchCarousel(frame)
    }
  }

  @Builder
  private ExploreMatchCarousel(frame: XExploreFrame): void {
    Scroll() {
      Row({ space: 12 }) {
        ForEach(frame.tiles, (tile: XExploreFrameTile) => {
          Column({ space: 10 }) {
            Row() {
              Text(tile.status).fontFamily(this.appFontFamily)
                .fontSize($r('sys.float.Body_S'))
                .fontWeight(tile.status === 'LIVE' ? FontWeight.Bold : FontWeight.Medium)
                .fontColor(tile.status === 'LIVE' ? this.accentColor :
                  $r('app.color.text_secondary'))
                .maxLines(1)
              Blank()
              Text(tile.schedule).fontFamily(this.appFontFamily)
                .fontSize($r('sys.float.Body_S'))
                .fontColor($r('app.color.text_secondary'))
                .maxLines(1)
            }
            .width('100%')

            Row({ space: 8 }) {
              if (tile.imageOne.length > 0) {
                Image(tile.imageOne)
                  .width(30)
                  .height(30)
                  .objectFit(ImageFit.Contain)
              }
              if (tile.teamOne.length > 0) {
                Text(tile.teamOne).fontFamily(this.appFontFamily)
                  .fontSize($r('sys.float.Subtitle_S'))
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_primary'))
                  .maxLines(1)
              }
              Blank()
              if (tile.scoreOne.length > 0) {
                Text(tile.scoreOne).fontFamily(this.appFontFamily)
                  .fontSize($r('sys.float.Title_M'))
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_primary'))
              }
            }
            .width('100%')
            .height(34)

            Row({ space: 8 }) {
              if (tile.imageTwo.length > 0) {
                Image(tile.imageTwo)
                  .width(30)
                  .height(30)
                  .objectFit(ImageFit.Contain)
              }
              if (tile.teamTwo.length > 0) {
                Text(tile.teamTwo).fontFamily(this.appFontFamily)
                  .fontSize($r('sys.float.Subtitle_S'))
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_primary'))
                  .maxLines(1)
              }
              Blank()
              if (tile.scoreTwo.length > 0) {
                Text(tile.scoreTwo).fontFamily(this.appFontFamily)
                  .fontSize($r('sys.float.Title_M'))
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_primary'))
              }
            }
            .width('100%')
            .height(34)
          }
          .width(190)
          .height(frame.height > 0 ? frame.height : 156)
          .padding({ left: 12, right: 12, top: 12, bottom: 12 })
          .backgroundColor(this.themedFieldSurface())
          .borderRadius(14)
          .onClick((): void => {
            this.openExploreDestination(tile.destinationUrl);
          })
        }, (tile: XExploreFrameTile) => 'explore-frame-tile-' + tile.id)
      }
      .padding({ left: 16, right: 16 })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
    .padding({ top: 6, bottom: 12 })
  }

  @Builder
  private ExploreFrameBanner(frame: XExploreFrame): void {
    Row({ space: 14 }) {
      if (frame.imageUrls.length > 0) {
        Image(frame.imageUrls[0])
          .width(54)
          .height(54)
          .objectFit(ImageFit.Contain)
      }
      Column({ space: 4 }) {
        Text(frame.title).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Title_M'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (frame.subtitle.length > 0) {
          Text(frame.subtitle).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('app.color.text_secondary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('92%')
    .height(frame.height > 0 ? frame.height : 180)
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor(this.themedFieldSurface())
    .borderRadius(14)
    .margin({ top: 6, bottom: 10 })
    .onClick((): void => {
      this.openExploreDestination(frame.destinationUrl);
    })
  }

  @Builder
  private ExploreCategoryTabs(): void {
    Column() {
      AnimatedIconTabs({ items: [
        { key: 'explore', label: $r('app.string.explore_title') },
        { key: 'trending', label: $r('app.string.explore_category_trending'), icon: $r('sys.symbol.arrowshape_turn_up_right') },
        { key: 'news', label: $r('app.string.explore_category_news'), icon: $r('sys.symbol.doc_plaintext') },
        { key: 'sports', label: $r('app.string.explore_category_sports'), icon: $r('sys.symbol.basketball') },
        { key: 'entertainment', label: $r('app.string.explore_category_entertainment'), icon: $r('sys.symbol.movie') }
      ], selected: this.exploreCategoryIndex(), tabPosition: this.exploreTabPosition,
        barHeight: this.exploreCategoriesHeight(),
        buttonStyle: !this.useTitleBarLogo() && this.compactSwitchStyle === COMPACT_SWITCH_BUTTONS,
        contentSized: true,
        onSelect: (index: number): void => {
          if (index === this.exploreCategoryIndex()) { this.selectExploreHomeCategory(EXPLORE_CATEGORY_IDS[index]); }
          else { this.explorePager.changeIndex(index, true); }
        } })
    }.width('100%').height(this.exploreCategoriesHeight())
      .id('harmonyx-explore-categories')
      .onAreaChange((_oldValue: Area, newValue: Area): void => {
        if (this.activeExploreQuery.length === 0) { this.captureExploreTitleContent(newValue); }
      })
  }

  @Builder
  private ExploreTrendRow(trend: string): void {
    Row({ space: 10 }) {
      Column({ space: 3 }) {
        Text($r('app.string.explore_category_trending')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('app.color.text_secondary'))
        Text(trend).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Title_S'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      SymbolGlyph($r('sys.symbol.ellipsis_circle'))
        .fontSize(20)
        .fontColor([$r('app.color.text_secondary')])
    }
    .width('92%')
    .padding({ top: 14, bottom: 14 })
    .border({ width: { bottom: 1 }, color: $r('app.color.divider') })
    .visualEffect(new hdsEffect.HdsEffectBuilder()
      .pointLight({
        illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
      })
      .buildEffect())
    .onClick((): void => {
      this.submitSearchFromTrend(trend);
    })
  }

  @Builder
  private ExploreRichTrendRow(item: XExploreTrend): void {
    Row({ space: 12 }) {
      Column({ space: 6 }) {
        if (item.context.length > 0) {
          Text(item.context).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_S'))
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }

        Row({ space: 6 }) {
          Text(item.name).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Title_S'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          if (item.isAiTrend) {
            Text('AI').fontFamily(this.appFontFamily)
              .fontSize(10)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_on_accent'))
              .backgroundColor(this.accentColor)
              .borderRadius(8)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          }
        }
        .width('100%')

        if (item.avatarUrls.length > 0) {
          Row({ space: 2 }) {
            ForEach(item.avatarUrls.slice(0, 3), (url: string) => {
              Image(url)
                .width(18)
                .height(18)
                .objectFit(ImageFit.Cover)
                .borderRadius(9)
                .border({ width: 1, color: this.themedPageSurface() })
            }, (url: string) => 'explore-face-' + url)
          }
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      SymbolGlyph($r('sys.symbol.ellipsis_circle'))
        .fontSize(20)
        .fontColor([$r('app.color.text_secondary')])
    }
    .width('92%')
    .padding({ top: 14, bottom: 14 })
    .border({ width: { bottom: 1 }, color: $r('app.color.divider') })
    .onClick((): void => {
      this.submitSearchFromTrendItem(item);
    })
  }

  @Builder
  private ExploreHeroCard(hero: XExploreHero): void {
    Stack({ alignContent: Alignment.BottomStart }) {
      if (this.heroHasMedia(hero)) {
        // A TimelineEventSummary can carry a full Tweet video. Rendering the
        // parsed attachments here preserves its stream URL instead of showing
        // only the poster image extracted for the legacy hero fallback.
        PostMedia({
          sourceTweet: hero.mediaTweet,
          attachments: this.heroAttachments(hero),
          videoFeedEnabled: true,
          homeTimelineVideo: true,
          exploreHeroVideo: true,
          exploreHeroMuted: this.exploreHeroMuted,
          showDownloadButton: false,
          onVideoOpen: (media: MediaAttachment): void => {
            this.openHeroVideo(hero, media);
          }
        })
      } else if (hero.imageUrl.length > 0) {
        Image(hero.imageUrl)
          .width('100%')
          .height(this.exploreHeroHeight(hero))
          .objectFit(ImageFit.Cover)
      } else {
        Row()
          .width('100%')
          .height(this.exploreHeroHeight(hero))
          .backgroundColor(this.themedFieldSurface())
      }

      Column({ space: 6 }) {
        if (hero.context.length > 0 || hero.time.length > 0) {
          Row({ space: 6 }) {
            if (hero.context.length > 0) {
              Text(hero.context).fontFamily(this.appFontFamily)
                .fontSize($r('sys.float.Body_S'))
                .fontColor('#E6FFFFFF')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)
            }
            if (hero.time.length > 0) {
              Text(hero.time).fontFamily(this.appFontFamily)
                .fontSize($r('sys.float.Body_S'))
                .fontColor('#E6FFFFFF')
                .maxLines(1)
            }
          }
          .width('100%')
        }
        Text(hero.title).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Title_M'))
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (hero.description.length > 0) {
          Text(hero.description).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M'))
            .fontColor('#E6FFFFFF')
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        if (hero.promoted || hero.authorName.length > 0) {
          Row({ space: 6 }) {
            if (hero.authorAvatarUrl.length > 0) {
              Image(hero.authorAvatarUrl)
                .width(18)
                .height(18)
                .borderRadius(userAvatarRadius(18, 9, hero.mediaTweet?.author?.verifiedType ?? '', hero.mediaTweet?.author?.avatarShape ?? ''))
                .objectFit(ImageFit.Cover)
            }
            if (hero.promoted) {
              Text($r('app.string.post_ad_label')).fontFamily(this.appFontFamily)
                .fontSize($r('sys.float.Body_S'))
                .fontColor('#CCFFFFFF')
                .maxLines(1)
            }
            if (hero.promoted && hero.authorName.length > 0) {
              Text('·').fontFamily(this.appFontFamily)
                .fontSize($r('sys.float.Body_S'))
                .fontColor('#CCFFFFFF')
            }
            if (hero.authorName.length > 0) {
              Text(hero.authorName).fontFamily(this.appFontFamily)
                .fontSize($r('sys.float.Body_S'))
                .fontColor('#CCFFFFFF')
                .maxLines(1)
            }
          }
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 16, right: 16, top: 28, bottom: 16 })
      .linearGradient({
        angle: 180,
        colors: [['#00000000', 0.0], ['#CC000000', 1.0]]
      })
      if (this.heroHasMedia(hero)) {
        this.ExploreHeroMuteButton()
      }
    }
    .width('100%')
    .height(this.exploreHeroHeight(hero))
    .clip(true)
    .onClick((): void => {
      if (!this.heroHasMedia(hero)) {
        this.openExploreDestination(hero.url);
      }
    })
  }

  @Builder
  private ExploreHeroMuteButton(): void {
    Stack({ alignContent: Alignment.TopEnd }) {
      MaterialButton({
        buttonWidth: 38,
        buttonHeight: 38,
        buttonRadius: 19,
        surfaceColor: '#66000000',
        materialLevel: 2,
        applyShadow: true,
        enableFallbackBlur: true,
        buttonBorderWidth: 1,
        buttonBorderColor: '#33FFFFFF',
        accessibilityLabel: this.text(this.exploreHeroMuted ?
          $r('app.string.video_unmute') : $r('app.string.video_mute')),
        buttonMonopolizeEvents: true,
        onButtonClick: (): void => {
          this.exploreHeroMuted = !this.exploreHeroMuted;
        }
      }) {
        SymbolGlyph(this.exploreHeroMuted ?
          $r('sys.symbol.speaker_slash_fill') : $r('sys.symbol.speaker_wave_2_fill'))
          .fontSize(18)
          .fontColor([$r('app.color.text_on_brand')])
      }
    }
    .width('100%')
    .height('100%')
    .padding({ top: 12, right: 12 })
    .zIndex(2)
  }

  private heroHasMedia(hero: XExploreHero): boolean {
    return this.heroAttachments(hero).length > 0;
  }

  private heroAttachments(hero: XExploreHero): MediaAttachment[] {
    if (hero.mediaTweet === null || hero.mediaTweet.attachments === undefined) {
      return [];
    }
    return hero.mediaTweet.attachments;
  }

  private openHeroVideo(hero: XExploreHero, media: MediaAttachment): void {
    if (hero.mediaTweet === null) {
      return;
    }
    this.openVideoFeed(hero.mediaTweet, media);
  }

  private exploreHeroHeight(hero: XExploreHero): number {
    // PostMedia's inline player has a 228vp surface. Keep the hero overlay on
    // that same geometry for a video, while image-only event cards preserve
    // their roomier 260vp presentation.
    return this.heroHasMedia(hero) ? 228 : 260;
  }

  @Builder
  private ExploreFrameRail(frameCount: number): void {
    Column({ space: 10 }) {
      Text($r('app.string.explore_category_sports')).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Title_S'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('92%')
        .padding({ top: 12 })

      Scroll() {
        Row({ space: 10 }) {
          ForEach(this.frameIndexes(frameCount), (index: number) => {
            Stack({ alignContent: Alignment.Center }) {
              SymbolGlyph($r('sys.symbol.flame_fill'))
                .fontSize(28)
                .fontColor([this.accentColor])
              if (index < this.exploreTrendItems.length) {
                Text(this.exploreTrendItems[index].name).fontFamily(this.appFontFamily)
                  .fontSize($r('sys.float.Body_M'))
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary'))
                  .maxLines(2)
                  .textAlign(TextAlign.Center)
                  .padding({ left: 12, right: 12, top: 64 })
              }
            }
            .width(220)
            .height(150)
            .backgroundColor(this.themedFieldSurface())
            .borderRadius(16)
          }, (index: number) => 'explore-frame-' + index)
        }
        .padding({ left: 16, right: 16 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
    }
    .width('100%')
    .padding({ bottom: 12 })
  }

  @Builder
  private ExploreTab(): void {
    Stack({ alignContent: Alignment.Top }) {
    Refresh({ refreshing: $$this.exploreHomeRefreshing, builder: this.HiddenRefreshSpinner() }) {
    Swiper(this.explorePager) {
      ForEach(EXPLORE_CATEGORY_IDS, (id: string, index: number) => { this.ExploreHome(index) }, (id: string): string => id)
    }.width('100%').height('100%').index(this.exploreCategoryIndex()).loop(false).indicator(false).cachedCount(1)
      .duration(280).curve(Curve.EaseOut).clip(true).disableSwipe(this.exploreHomeRefreshing)
      .onAppear((): void => { this.exploreTabPosition = this.exploreCategoryIndex(); })
      .onChange((index: number): void => { this.selectExploreHomeCategory(EXPLORE_CATEGORY_IDS[index]); })
      .onContentDidScroll((_selected: number, index: number, position: number, _length: number): void => {
        this.exploreTabPosition = ProfileTabMotion.scrollPosition(index, position, EXPLORE_CATEGORY_IDS.length);
        this.prepareExplorePage(index);
      })
      .onAnimationStart((_index: number, target: number): void => { this.prepareExplorePage(target); })
      .onAnimationEnd((index: number): void => { this.exploreTabPosition = index; })
    }.width('100%').height('100%').onRefreshing((): void => { this.onExploreHomeRefresh(); })
      .onOffsetChange((offset: number): void => { this.exploreRefreshPullOffset = offset; })
      .onAreaChange((_oldValue: Area, newValue: Area): void => { this.captureExploreContentTop(newValue); })
    RootRefreshIndicator({ topInset: this.exploreContentTopInset(), pullOffset: this.exploreRefreshPullOffset,
      refreshing: this.exploreHomeRefreshing, phoneLayout: !this.isDesktopLayout() })
    }.width('100%').height('100%')
  }

  @Builder
  private ExploreWaterFlow(): void {
    WaterFlow({
      scroller: this.getExploreScroller(),
      sections: this.exploreWaterFlowSections,
      layoutMode: WaterFlowLayoutMode.SLIDING_WINDOW
    }) {
      ForEach(this.pagedFlowItems(this.filteredExploreResults().length), (itemIndex: number) => {
        FlowItem() {
          if (itemIndex === 0) {
            this.ExploreWaterFlowHeader()
          } else if (itemIndex > this.filteredExploreResults().length) {
            this.ExploreWaterFlowFooter()
          } else {
            this.ExploreTweetCard(this.filteredExploreResults()[itemIndex - 1])
          }
        }
        .width('100%')
      }, (itemIndex: number): string => 'explore-flow-' + itemIndex.toString())
    }
    .width('100%')
    .height('100%')
    .onAreaChange((_oldValue: Area, newValue: Area): void => { this.captureExploreContentTop(newValue); })
    .backgroundColor(this.themedPageSurface())
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .scrollBar(BarState.Off)
    .contentEndOffset(this.contentBottomInset())
    .clipContent(this.isDesktopLayout() ? ContentClipMode.SAFE_AREA : ContentClipMode.BOUNDARY)
    .clip(!this.isDesktopLayout())
    .cachedCount(8, this.isDesktopLayout())
    .columnsTemplate(this.timelineColumnsTemplate())
    .rowsGap(0)
    .columnsGap(1)
    .onScrollIndex((start: number): void => {
      if (start >= this.exploreResults.length - 2) {
        this.requestMoreExploreResults();
      }
    })
    .onDidScroll((scrollOffset: number): void => {
      this.onFeedScroll(scrollOffset);
    })
    .onScrollStop((): void => {
      this.onFeedScrollStop();
    })
    .onReachEnd((): void => {
      this.requestMoreExploreResults();
    })
  }

  @Builder
  private ExploreWaterFlowHeader(): void {
    Column({ space: 0 }) {
      if (this.supportsHdsNavigation()) {
        this.ExploreContentTopSpacer()
      } else {
        this.LegacyExploreSearchBar()
      }
      Text(this.exploreStatus).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_S'))
        .fontColor($r('app.color.text_secondary'))
        .width('92%')
        .padding({ top: 4, bottom: 8 })
      if (this.activeExploreQuery.length > 0) {
        this.ExploreFilterChips()
      }
    }
    .width('100%')
  }

  @Builder
  private ExploreFilterChips(): void { this.SearchSurfaceTabs() }

  @Builder
  private ExploreTweetCard(tweet: Tweet): void {
    TweetCard({
      tweet: tweet,
      videoFeedEnabled: true,
      onLikeChanged: (t: Tweet, liked: boolean): Promise<boolean> => this.onLike(t, liked),
      onRepostChanged: (t: Tweet, reposted: boolean): Promise<boolean> => this.onRepost(t, reposted),
      onReply: (t: Tweet): void => this.onReply(t),
      onOpen: (t: Tweet): void => this.openPost(t),
      onVideoOpen: (t: Tweet, media: MediaAttachment): void => this.openVideoFeed(t, media),
      onAuthorTapped: (t: Tweet): void => this.openUser(t),
      onMentionTapped: (handle: string): void => this.openMention(handle)
    })
  }

  @Builder
  private ExploreWaterFlowFooter(): void {
    Row() {
      if (this.loadingMoreExplore) {
        LoadingProgress()
          .width(18)
          .height(18)
          .color(this.accentColor)
      } else {
        Text(this.hasMoreExplore ? $r('app.string.explore_load_more') : $r('app.string.explore_no_more')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_S'))
          .fontColor(this.hasMoreExplore ? $r('app.color.text_accent') : $r('app.color.text_secondary'))
      }
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ top: 16, bottom: 16 })
    // The footer doubles as the load-more control so a tap pages on without
    // waiting for another scroll; the guard keeps repeated taps from stacking
    // requests while one is in flight.
    .onClick((): void => {
      if (this.hasMoreExplore && !this.loadingMoreExplore) {
        this.requestMoreExploreResults();
      }
    })
  }

  @Builder
  private SearchHeader(showFilter: boolean, autoFocus: boolean): void {
    Row({ space: 8 }) {
      if (this.supportsImmersiveMaterial()) {
        Stack() {
          Search({
            value: this.searchText,
            placeholder: $r('app.string.search_placeholder')
          })
            .keyboardAppearance(KeyboardAppearance.IMMERSIVE)
            .width('100%')
            .height(40)
            .backgroundColor(Color.Transparent)
            .fontColor($r('app.color.text_primary'))
            .placeholderColor($r('app.color.text_secondary'))
            .defaultFocus(autoFocus)
            .focusOnTouch(true)
            .searchButton($r('app.string.search_action'))
            .onChange((value: string): void => {
              this.searchText = value;
            })
            .onSubmit((value: string): void => {
              this.submitSearchFromHeader(value, showFilter);
            })
        }
        .layoutWeight(1)
        .height(40)
        .borderRadius(20)
        .clip(true)
        .systemMaterial(new uiMaterial.ImmersiveMaterial({
          style: uiMaterial.ImmersiveStyle.THIN,
          interactive: true,
          applyShadow: false,
          colorInvert: true,
          lightEffect: { color: this.accentColor }
        }))
      } else {
        Search({
          value: this.searchText,
          placeholder: $r('app.string.search_placeholder')
        })
          .keyboardAppearance(KeyboardAppearance.IMMERSIVE)
          .layoutWeight(1)
          .height(40)
          .backgroundColor(this.themedFieldSurface())
          .fontColor($r('app.color.text_primary'))
          .placeholderColor($r('app.color.text_secondary'))
          .borderRadius(20)
          .defaultFocus(autoFocus)
          .focusOnTouch(true)
          .searchButton($r('app.string.search_action'))
          .onChange((value: string): void => {
            this.searchText = value;
          })
          .onSubmit((value: string): void => {
            this.submitSearchFromHeader(value, showFilter);
          })
      }
    }
    .width('100%')
    .height(56)
    .alignItems(VerticalAlign.Center)
    // HDS large-screen buttons occupy 32..72vp at either edge. Keep the
    // custom field 8vp clear of both native controls without replacing them.
    .padding({ left: this.isDesktopLayout() ? $r('app.float.desktop_search_button_inset') : 64,
      right: showFilter ? (this.isDesktopLayout() ? $r('app.float.desktop_search_button_inset') : 64) : 16 })
  }

  @Builder
  private SearchHistoryPage(): void {
    HdsNavDestination() {
      Column({ space: 0 }) {
        List({ scroller: this.searchHistoryScroller }) {
          ListItem() {
            Row() {
              Text($r('app.string.search_history_title')).fontFamily(this.appFontFamily)
                .fontSize($r('sys.float.Title_S'))
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
                .layoutWeight(1)
              MaterialButton({
                buttonWidth: 38,
                buttonHeight: 38,
                buttonRadius: 19,
                surfaceColor: Color.Transparent,
                materialLevel: 0,
                applyShadow: false,
                lightColor: this.accentColor,
                accessibilityLabel: this.text($r('app.string.search_history_clear')),
                onButtonClick: (): void => {
                  const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
                  searchHistoryStore.clear(context);
                  this.searchHistory = [];
                }
              }) {
                SymbolGlyph($r('sys.symbol.trash'))
                  .fontSize(23)
                  .fontColor([$r('app.color.text_primary')])
              }
            }
            .width('100%')
            .padding({ top: 12, bottom: 12 })
          }

          if (this.searchHistory.length > 0) {
            ListItem() {
              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(this.searchHistory, (term: string) => {
                  Text(term).fontFamily(this.appFontFamily)
                    .fontSize($r('sys.float.Body_L'))
                    .fontColor($r('app.color.text_primary'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .constraintSize({ maxWidth: 260 })
                    .padding({ left: 16, right: 16, top: 9, bottom: 9 })
                    .margin({ right: 10, bottom: 10 })
                    .backgroundColor(this.themedFieldSurface())
                    .borderRadius(22)
                    .onClick((): void => {
                      this.submitSearchFromHistory(term);
                    })
                }, (term: string) => 'search-history-' + term)
              }
              .width('100%')
              .padding({ bottom: 12 })
            }
          } else {
            ListItem() {
              Text($r('app.string.search_history_empty')).fontFamily(this.appFontFamily)
                .fontSize($r('sys.float.Body_M'))
                .fontColor($r('app.color.text_secondary'))
                .width('100%')
                .padding({ top: 2, bottom: 20 })
            }
          }

          ListItem() {
            Text($r('app.string.search_suggestion_title')).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Title_S'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .width('100%')
              .padding({ top: 18, bottom: 10 })
          }

          ForEach(this.trends.filter((trend: string) => {
            return this.searchText.trim().length === 0 ||
              trend.toLowerCase().includes(this.searchText.trim().toLowerCase());
          }), (trend: string) => {
            ListItem() {
              Row({ space: 12 }) {
                Stack({ alignContent: Alignment.Center }) {
                  SymbolGlyph($r('sys.symbol.magnifyingglass'))
                    .fontSize(22)
                    .fontColor([$r('app.color.text_secondary')])
                }
                .width(48)
                .height(48)
                .backgroundColor(this.themedFieldSurface())
                .borderRadius(14)

                Text(trend).fontFamily(this.appFontFamily)
                  .fontSize($r('sys.float.Body_L'))
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary'))
                  .layoutWeight(1)
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .width('100%')
              .padding({ top: 10, bottom: 10 })
              .onClick((): void => {
                this.submitSearchFromTrend(trend);
              })
            }
          }, (trend: string) => 'search-suggestion-' + trend)
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16 })
        // Keep the history and the suggestions scrollable *under* the blurred
        // title bar instead of parking them in a band below it.
        .contentStartOffset(this.isDesktopLayout() ? 0 : this.statusBarHeight + 56)
        .clip(!this.isDesktopLayout()).cachedCount(8, this.isDesktopLayout())
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.themedPageSurface())
    }
    .transition(TransitionEffect.OPACITY)
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .hideBackButton(false)
    .titleBar({
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: this.isDesktopLayout(),
      content: {
        stackBuilder: (): void => this.SearchHeader(false, false),
        divider: { showType: DividerShowType.OFF }
      },
      style: destinationTitleBarStyle(ScrollEffectType.GRADIENT_BLUR,
        this.displayMode, this.darkSurface, this.titleBarStyleMode)
    })
    .bindToScrollable([this.searchHistoryScroller])
    .backgroundColor(this.themedPageSurface())
    .onBackPressed((): boolean => {
      this.closeSearchHistoryPage();
      return true;
    })
  }

  @Builder
  private SearchResultsContent(index: number): void {
      List({ scroller: this.contentPageScroller('search', SEARCH_PRODUCT_IDS[index]) }) {
        if (this.searchPageLoading(index) && this.searchPagePosts(index).length === 0 && this.searchPageUsers(index).length === 0) {
          ForEach(this.frameIndexes(4), (index: number) => {
            ListItem() {
              this.SearchResultSkeletonRow(index)
            }
          }, (index: number) => 'search-skeleton-' + index)
        } else {
          if (this.searchPageStatus(index).length > 0) {
            ListItem() {
              Text(this.searchPageStatus(index)).fontFamily(this.appFontFamily)
                .fontSize($r('sys.float.Body_S'))
                .fontColor($r('app.color.text_secondary'))
                .width('92%')
                .padding({ top: 6, bottom: 8 })
            }
          }

          ForEach(this.searchTimelineRows(index), (row: SearchTimelineRow) => {
            ListItem() {
              if (row.promotion !== null) { this.HomePromotion(row.promotion as XXAuthPromotionPost) }
              else { this.ExploreTweetCard(row.tweet as Tweet) }
            }
          }, (row: SearchTimelineRow) => row.key)

          ForEach(this.searchPageUsers(index), (row: UserRow) => {
            ListItem() {
              UserRowCard({
                row: row,
                onOpen: (r: UserRow): void => this.openUserRow(r),
                onFollowChanged: (r: UserRow, next: boolean): Promise<boolean> => this.applyRowFollow(r, next)
              })
            }
          }, (row: UserRow) => 'surface-user-' + row.id)

          if (this.searchPagePosts(index).length > 0 || this.searchPageUsers(index).length > 0) {
            ListItem() {
              this.ExploreWaterFlowFooter()
            }
            .onAppear((): void => {
              if (index === this.searchProductIndex()) { this.requestMoreExploreResults(); }
            })
          }

          if (this.searchPagePosts(index).length === 0 && this.searchPageUsers(index).length === 0 &&
            this.activeExploreQuery.length > 0) {
            ListItem() {
              Text(SEARCH_PRODUCT_IDS[index] === 'Lists' ? $r('app.string.search_lists_empty') :
                this.searchPageStatus(index).length > 0 ? this.searchPageStatus(index) : $r('app.string.search_empty_hint')).fontFamily(this.appFontFamily)
                .fontSize($r('sys.float.Body_L'))
                .fontColor($r('app.color.text_secondary'))
                .width('100%')
                .textAlign(TextAlign.Center)
                .padding({ top: 48, bottom: 48 })
            }
          }
        }
      }
      .width('100%')
      .height('100%')
      // The product tabs live in the title bar's bottom builder, so the
      // results start below bar + tabs and still scroll under both.
      .contentStartOffset(this.isDesktopLayout() ? 0 : this.statusBarHeight + 104)
      .clip(!this.isDesktopLayout()).cachedCount(8, this.isDesktopLayout())
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .scrollBar(BarState.Off)
      // The footer also loads on appear, but a list that ends inside the
      // viewport never fires that callback, so reach-end keeps paging going.
      .onReachEnd((): void => {
        if (index === this.searchProductIndex()) { this.requestMoreExploreResults(); }
      })
      .backgroundColor(this.themedPageSurface())
  }

  @Builder
  private SearchResultsPage(): void {
    HdsNavDestination() {
      Swiper(this.searchPager) {
        ForEach(SEARCH_PRODUCT_IDS, (product: string, index: number) => { this.SearchResultsContent(index) },
          (product: string): string => product)
      }.width('100%').height('100%').index(this.searchProductIndex()).loop(false).indicator(false).cachedCount(1)
        .duration(280).curve(Curve.EaseOut).clip(true).disableSwipe(this.searchFilterOpen)
        .onAppear((): void => { this.searchTabPosition = this.searchProductIndex(); })
        .onChange((index: number): void => { this.selectSearchProduct(SEARCH_PRODUCT_IDS[index]); })
        .onContentDidScroll((_selected: number, index: number, position: number, _length: number): void => {
          this.searchTabPosition = ProfileTabMotion.scrollPosition(index, position, SEARCH_PRODUCT_IDS.length);
        })
        .onAnimationEnd((index: number): void => { this.searchTabPosition = index; })
      .bindSheet($$this.searchFilterOpen, this.SearchFilterSheet(), sheetMaterialOptions({
        height: 560,
        preferType: this.isDesktopLayout() ? SheetType.CENTER : SheetType.BOTTOM,
        width: this.isDesktopLayout() ? 560 : undefined,
        showClose: false,
        dragBar: !this.isDesktopLayout(),
        maskColor: '#66000000',
        radius: { topLeft: 28, topRight: 28 },
        backgroundColor: this.themedPageSurface(),
        onDisappear: (): void => {
          this.searchFilterOpen = false;
        }
      }, this.sheetMaterialEnabled, this.sheetMaterialLevel, this.sheetWindowBreakpoint, this.compactWindow))
    }
    .transition(TransitionEffect.OPACITY)
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .hideBackButton(false)
    .titleBar({
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: this.isDesktopLayout(),
      content: {
        stackBuilder: (): void => this.SearchHeader(true, false),
        // Hand the filter entry to the HDS title bar so the button keeps the
        // native material and its press light instead of a custom wrapper.
        menu: {
          value: [
            {
              content: {
                icon: $r('sys.symbol.slider_horizontal_2_square'),
                label: this.text($r('app.string.search_filter_title')),
                action: (): void => {
                  this.openSearchFilters();
                }
              }
            }
          ]
        },
        // The product filter row is part of the title bar, so it keeps the
        // bar's material and the results slide underneath it.
        bottomBuilder: {
          builder: (): void => {
            this.SearchSurfaceTabs();
          },
          height: 48
        },
        divider: { showType: DividerShowType.OFF }
      },
      style: destinationTitleBarStyle(ScrollEffectType.GRADIENT_BLUR,
        this.displayMode, this.darkSurface, this.titleBarStyleMode)
    })
    .bindToScrollable([this.getSearchSurfaceScroller()])
    .backgroundColor(this.themedPageSurface())
    .onBackPressed((): boolean => {
      this.closeSearchResultsPage();
      return true;
    })
  }

  @Builder
  private SearchResultSkeletonRow(index: number): void {
    Row({ space: 12 }) {
      Row()
        .width(44)
        .height(44)
        .borderRadius(22)
        .backgroundColor(this.themedFieldSurface())

      Column({ space: 10 }) {
        Row()
          .width(index % 2 === 0 ? '42%' : '58%')
          .height(14)
          .borderRadius(7)
          .backgroundColor(this.themedFieldSurface())
        Row()
          .width('94%')
          .height(14)
          .borderRadius(7)
          .backgroundColor(this.themedFieldSurface())
        Row()
          .width(index % 2 === 0 ? '72%' : '84%')
          .height(14)
          .borderRadius(7)
          .backgroundColor(this.themedFieldSurface())
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 20, bottom: 20 })
    .border({ width: { bottom: 1 }, color: $r('app.color.divider') })
    .opacity(0.72)
  }

  @Builder
  private SearchFilterSheet(): void {
    Column({ space: 0 }) {
      Row() {
        Text($r('app.string.search_filter_title')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Title_M'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Text($r('app.string.search_filter_reset')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_L'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_accent'))
          .onClick((): void => {
            this.resetSearchFilters();
          })
      }
      .width('100%')
      .height(60)
      .padding({ left: 16, right: 20 })

      Column({ space: 0 }) {
        // Every row reads its state variable right here. Handing the resolved
        // value to a @Builder as a parameter would freeze it (custom builders
        // with by-value parameters do not refresh), which is why the rows used
        // to look dead even though the tap went through.
        Row({ space: 8 }) {
          Text($r('app.string.search_filter_from')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_L'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
          Text(this.searchFilterFrom === 'Anyone' ? $r('app.string.search_filter_anyone') :
            $r('app.string.search_filter_following')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_L'))
            .fontColor($r('app.color.text_secondary'))
          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontSize(18)
            .fontColor([$r('app.color.text_secondary')])
        }
        .width('100%')
        .height(64)
        .border({ width: { bottom: 1 }, color: $r('app.color.divider') })
        .onClick((): void => {
          this.searchFilterFrom = this.searchFilterFrom === 'Anyone' ? 'Following' : 'Anyone';
        })

        Row({ space: 8 }) {
          Text($r('app.string.search_filter_date')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_L'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
          Text(this.searchFilterSince.length > 0 ?
            this.searchFilterSince + this.text($r('app.string.search_filter_since_suffix')) :
            this.text($r('app.string.search_filter_all_time'))).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_L'))
            .fontColor(this.searchFilterSince.length > 0 ? $r('app.color.text_primary') :
              $r('app.color.text_secondary'))
          // The picked day can be dropped again without resetting every other
          // choice in the sheet.
          if (this.searchFilterSince.length > 0) {
            SymbolGlyph($r('sys.symbol.xmark_circle_fill'))
              .fontSize(18)
              .fontColor([$r('app.color.text_secondary')])
              .accessibilityText(this.text($r('app.string.search_filter_date_clear')))
              .onClick((): void => {
                this.clearPublishDate();
              })
          }
          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontSize(18)
            .fontColor([$r('app.color.text_secondary')])
        }
        .width('100%')
        .height(64)
        .border({ width: { bottom: 1 }, color: $r('app.color.divider') })
        .onClick((): void => {
          this.pickPublishDate();
        })

        Row({ space: 8 }) {
          Text($r('app.string.search_filter_language')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_L'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
          Text(this.searchFilterLanguage === 'Any' ? $r('app.string.search_filter_any') :
            $r('app.string.search_filter_chinese')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_L'))
            .fontColor($r('app.color.text_secondary'))
          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontSize(18)
            .fontColor([$r('app.color.text_secondary')])
        }
        .width('100%')
        .height(64)
        .border({ width: { bottom: 1 }, color: $r('app.color.divider') })
        .onClick((): void => {
          this.searchFilterLanguage = this.searchFilterLanguage === 'Any' ? 'Chinese' : 'Any';
        })

        Row({ space: 8 }) {
          Text($r('app.string.search_filter_activity')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_L'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
          Text(this.searchFilterActivity === 'Any' ? $r('app.string.search_filter_any') :
            $r('app.string.search_filter_popular')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_L'))
            .fontColor($r('app.color.text_secondary'))
          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontSize(18)
            .fontColor([$r('app.color.text_secondary')])
        }
        .width('100%')
        .height(64)
        .border({ width: { bottom: 1 }, color: $r('app.color.divider') })
        .onClick((): void => {
          this.searchFilterActivity = this.searchFilterActivity === 'Any' ? 'Popular' : 'Any';
        })

        Row() {
          Text($r('app.string.search_filter_exclude_replies')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_L'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.searchFilterExcludeReplies })
            .selectedColor(this.accentColor)
            .onChange((isOn: boolean): void => {
              this.searchFilterExcludeReplies = isOn;
            })
        }
        .width('100%')
        .height(64)
        .border({ width: { bottom: 1 }, color: $r('app.color.divider') })
      }
      .width('100%')
      .padding({ left: 20, right: 20 })

      Blank()

      Button($r('app.string.search_filter_apply'))
        .width('calc(100% - 40vp)')
        .height(52)
        .fontSize($r('sys.float.Body_L'))
        .fontWeight(FontWeight.Medium)
        .fontColor(this.themedPageSurface())
        .backgroundColor($r('app.color.text_primary'))
        .borderRadius(26)
        .margin({ bottom: 24 })
        .onClick((): void => {
          this.applySearchFilters();
        })
    }
    .width('100%')
    .height('100%')
    .padding({ top: 8 })
    .backgroundColor(sheetContentBackground(this.themedPageSurface(), this.sheetMaterialEnabled))
  }

  @Builder
  private SearchSurfaceTabs(): void {
    AnimatedIconTabs({ items: [
      { key: 'Top', label: $r('app.string.search_filter_top'), icon: $r('sys.symbol.star') },
      { key: 'Latest', label: $r('app.string.search_filter_latest'), icon: $r('sys.symbol.clock') },
      { key: 'People', label: $r('app.string.search_filter_people'), icon: $r('sys.symbol.person_2') },
      { key: 'Media', label: $r('app.string.search_filter_media'), icon: $r('sys.symbol.picture_2') },
      { key: 'Lists', label: $r('app.string.search_filter_lists'), icon: $r('sys.symbol.list_bullet') }
    ], selected: this.searchProductIndex(), tabPosition: this.searchTabPosition, barHeight: 48,
      buttonStyle: !this.useTitleBarLogo() && this.compactSwitchStyle === COMPACT_SWITCH_BUTTONS,
      onSelect: (index: number): void => this.searchPager.changeIndex(index, true) })
  }

  @Builder
  private ChatTitleBarSearch(): void {
    Search({ value: this.chatSearch, placeholder: $r('app.string.chat_search') })
      .keyboardAppearance(KeyboardAppearance.IMMERSIVE)
      .width(this.useTitleBarLogo() || this.isDesktopLayout() ? '95%' : '100%')
      .constraintSize({ maxWidth: 720 }).height(38)
      .backgroundColor(this.supportsImmersiveMaterial() ? Color.Transparent : this.themedFieldSurface())
      .fontColor($r('app.color.text_primary')).placeholderColor($r('app.color.text_secondary'))
      .borderRadius(19).clip(true).defaultFocus(false)
      .systemMaterial(this.chatSearchMaterialCache.material(this.accentColor))
      .onChange((value: string): void => { this.chatSearch = value; })
  }

  @Builder
  private ExploreTitleBarSearch(): void {
    if (this.supportsImmersiveMaterial()) {
      Stack() {
        Search({
          value: this.searchText,
          placeholder: $r('app.string.search_placeholder')
        })
          .keyboardAppearance(KeyboardAppearance.IMMERSIVE)
          .width('100%')
          .height(this.exploreSearchHeight())
          .backgroundColor(Color.Transparent)
          .fontColor($r('app.color.text_primary'))
          .placeholderColor($r('app.color.text_secondary'))
          .defaultFocus(false)
          .focusOnTouch(false)
          .focusable(false)
          .onClick((): void => {
            this.showSearchPage();
          })
      }
      .width(this.useTitleBarLogo() ? '95%' : '100%')
      .constraintSize({ maxWidth: 720 })
      .height(this.exploreSearchHeight())
      .borderRadius(19)
      .clip(true)
      .systemMaterial(this.exploreSearchMaterialCache.material(this.accentColor, true))
      .onAreaChange((_oldValue: Area, newValue: Area): void => {
        if (this.useTitleBarLogo() && this.activeExploreQuery.length > 0) { this.captureExploreTitleContent(newValue); }
      })
    } else {
      Search({
        value: this.searchText,
        placeholder: $r('app.string.search_placeholder')
      })
        .keyboardAppearance(KeyboardAppearance.IMMERSIVE)
        .width(this.useTitleBarLogo() ? '95%' : '100%')
        .constraintSize({ maxWidth: 720 })
        .height(this.exploreSearchHeight())
        .backgroundColor(this.themedFieldSurface())
        .fontColor($r('app.color.text_primary'))
        .placeholderColor($r('app.color.text_secondary'))
        .borderRadius(19)
        .defaultFocus(false)
        .focusOnTouch(false)
        .focusable(false)
        .onAreaChange((_oldValue: Area, newValue: Area): void => {
          if (this.useTitleBarLogo() && this.activeExploreQuery.length > 0) { this.captureExploreTitleContent(newValue); }
        })
        .onClick((): void => {
          this.showSearchPage();
        })
    }
  }

  private exploreSearchHeight(): number {
    return !this.useTitleBarLogo() && !this.isDesktopLayout() ? 38 : 38 * Math.max(1, this.fontScale);
  }

  private exploreCategoriesHeight(): number { return 52 * Math.max(1, this.fontScale); }

  @Builder
  private LegacyExploreSearchBar(): void {
    Search({
      value: this.searchText,
      placeholder: $r('app.string.search_placeholder')
    })
      .keyboardAppearance(KeyboardAppearance.IMMERSIVE)
      .width('92%')
      .height(44)
      .margin({ top: this.contentTopInset(), bottom: 12 })
      .placeholderColor($r('app.color.text_secondary'))
      .backgroundColor(this.themedFieldSurface())
      .fontColor($r('app.color.text_primary'))
      .borderRadius(22)
      .defaultFocus(false)
      .focusOnTouch(false)
      .focusable(false)
      .onTouch((event: TouchEvent): void => {
        if (event.type === TouchType.Up) {
          this.showSearchPage();
        }
      })
  }

  private submitSearch(value: string, querySource: string = 'typed_query'): void {
    const query: string = value.trim();
    if (query !== this.activeExploreQuery) { this.searchTabSnapshots.clear(); }
    if (query.length > 0) {
      const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      this.searchHistory = searchHistoryStore.add(context, query);
    }
    this.searchRequestId += 1;
    const requestId: number = this.searchRequestId;
    this.searchText = query;
    this.activeExploreQuery = query;
    this.activeSearchQuerySource = querySource;
    this.exploreNextToken = '';
    this.hasMoreExplore = false;
    this.loadingMoreExplore = false;
    this.exploreResults = [];
    this.exploreUsers = [];
    this.exploreStatus = '';
    this.searchLoading = query.length > 0;
    if (!this.hasAnySession()) {
      this.searchLoading = false;
      this.needsAuth(this.text($r('app.string.action_search_live')));
      return;
    }
    if (query.length === 0) {
      this.searchLoading = false;
      this.exploreResults = [];
      return;
    }
    if (this.searchProduct === 'Lists') {
      this.searchLoading = false;
      this.exploreResults = [];
      this.exploreUsers = [];
      this.exploreStatus = this.text($r('app.string.search_lists_empty'));
      return;
    }
    // People search returns account rows rather than posts, and needs the
    // private surface: the OAuth recent-search endpoint has no product switch.
    if (this.searchProduct === 'People') {
      if (!this.xPrivate.isSignedIn()) {
        this.searchLoading = false;
        this.exploreStatus = this.text($r('app.string.user_list_sign_in'));
        return;
      }
      this.searchPeopleViaPrivate(query, '').then((page: UserListPage | null): void => {
        if (requestId !== this.searchRequestId || query !== this.activeExploreQuery) {
          return;
        }
        this.searchLoading = false;
        if (page !== null && page.users.length > 0) {
          this.exploreUsers = page.users;
          this.exploreNextToken = page.nextToken;
          this.hasMoreExplore = page.nextToken.length > 0;
          this.exploreStatus = page.users.length + this.text($r('app.string.toast_results_suffix')) +
            this.activeSearchFilterSuffix();
        } else {
          this.exploreUsers = [];
          this.exploreStatus = this.searchFailureStatus();
        }
      });
      return;
    }
    if (this.xPrivate.isSignedIn()) {
      this.searchViaPrivate(query, '').then((page: TweetPage | null): void => {
        if (requestId !== this.searchRequestId || query !== this.activeExploreQuery) {
          return;
        }
        this.searchLoading = false;
        if (page !== null && page.tweets.length > 0) {
          this.exploreResults = page.tweets;
          this.exploreNextToken = page.nextToken;
          this.hasMoreExplore = page.nextToken.length > 0;
          this.exploreStatus = page.tweets.length + this.text($r('app.string.toast_results_suffix')) +
            this.activeSearchFilterSuffix();
          promptAction.showToast({
            message: page.tweets.length + this.text($r('app.string.toast_results_suffix')),
            duration: 1500
          });
        } else {
          this.exploreResults = [];
          this.exploreStatus = this.searchFailureStatus();
          promptAction.showToast({
            message: this.text($r('app.string.toast_no_live_results')),
            duration: 2000
          });
        }
      });
      return;
    }
    this.api.searchRecentPage(this.effectiveSearchQuery(query)).then((page: TweetPage | null): void => {
      if (requestId !== this.searchRequestId || query !== this.activeExploreQuery) {
        return;
      }
      this.searchLoading = false;
      if (page !== null && page.tweets.length > 0) {
        this.exploreResults = page.tweets;
        this.exploreNextToken = page.nextToken;
        this.hasMoreExplore = page.nextToken.length > 0;
        this.exploreStatus = page.tweets.length + this.text($r('app.string.toast_results_suffix')) +
          this.activeSearchFilterSuffix();
        promptAction.showToast({ message: page.tweets.length + this.text($r('app.string.toast_results_suffix')), duration: 1500 });
      } else {
        this.exploreResults = [];
        this.exploreStatus = this.text($r('app.string.status_live_data_unavailable'));
        promptAction.showToast({ message: this.api.lastStatus() === 402 ?
          this.text($r('app.string.toast_search_paid_api')) : this.text($r('app.string.toast_no_live_results')), duration: 2000 });
      }
    });
  }

  @Builder
  private NotificationsDestination(): void {
    HdsNavDestination() {
      this.NotificationsTab(true)
    }
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .titleBar({
      avoidLayoutSafeArea: true,
      content: {
        title: { mainTitle: $r('app.string.notifications_title') },
        bottomBuilder: { builder: (): void => this.NotificationTabs(false), height: 52 },
        divider: { showType: DividerShowType.OFF }
      },
      style: destinationTitleBarStyle(ScrollEffectType.GRADIENT_BLUR,
        this.displayMode, this.darkSurface, this.titleBarStyleMode)
    })
    .bindToScrollable(this.rootPageScrollers(NOTIFICATIONS_TAB_INDEX))
    .backgroundColor(this.themedPageSurface())
    .onBackPressed((): boolean => {
      ResponsiveLayout.closeContentDestination(this.navPathStack);
      return true;
    })
  }

  @Builder
  private NotificationsTab(standalone: boolean = false): void {
    Stack({ alignContent: Alignment.Top }) {
    Refresh({ refreshing: $$this.notificationsRefreshing, builder: this.HiddenRefreshSpinner() }) {
    Swiper(this.notificationPager) {
      ForEach([0, 1, 2], (index: number) => { this.NotificationPage(index, standalone) }, (index: number): string => index.toString())
    }.width('100%').height('100%').index(this.notificationFilter).loop(false).indicator(false).cachedCount(1)
      .duration(280).curve(Curve.EaseOut).clip(true).disableSwipe(this.notificationsRefreshing)
      .onAppear((): void => { this.notificationTabPosition = this.notificationFilter; })
      .onChange((index: number): void => { this.notificationFilter = index; })
      .onContentDidScroll((_selected: number, index: number, position: number, _length: number): void => {
        this.notificationTabPosition = ProfileTabMotion.scrollPosition(index, position, 3);
      })
      .onAnimationEnd((index: number): void => { this.notificationTabPosition = index; })
    }.width('100%').height('100%').onRefreshing((): void => { this.onNotificationsRefresh(); })
      .onOffsetChange((offset: number): void => { this.notificationsRefreshPullOffset = offset; })
    RootRefreshIndicator({ topInset: this.notificationsContentTopInset(standalone),
      pullOffset: this.notificationsRefreshPullOffset, refreshing: this.notificationsRefreshing,
      phoneLayout: !this.isDesktopLayout() })
    }.width('100%').height('100%')
  }

  @Builder
  private NotificationPage(index: number, standalone: boolean = false): void {
    Column() {
        if (this.useTimelineWaterFlow()) {
          this.NotificationsWaterFlow(index, standalone)
        } else {
          List({ scroller: this.contentPageScroller('notifications', index.toString()) }) {
          ListItem() {
            Column()
              .width('100%')
              .height(this.notificationsContentTopInset(standalone))
          }
          if (this.notificationPageStatus(index).length > 0) {
            ListItem() {
              Text(this.notificationPageStatus(index)).fontFamily(this.appFontFamily)
                .fontSize($r('sys.float.Body_S'))
                .fontColor($r('app.color.text_secondary'))
                .width('92%')
                .padding({ top: 4, bottom: 8 })
            }
            .width('100%')
            .align(Alignment.Center)
          }
          ForEach(this.visibleNotifications(index), (n: AppNotification) => {
            ListItem() {
              this.NotificationItem(n)
            }
            .width('100%')
            .align(Alignment.Center)
          }, (n: AppNotification) => n.id)
          ListItem() {
            this.NotificationsWaterFlowFooter(index)
          }
          .width('100%')
          .align(Alignment.Center)
        }
        .width('100%')
        .backgroundColor(this.themedPageSurface())
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .scrollBar(BarState.Off)
        .contentEndOffset(this.contentBottomInset())
        .clipContent(this.isDesktopLayout() ? ContentClipMode.SAFE_AREA : ContentClipMode.BOUNDARY)
        .clip(!this.isDesktopLayout())
        .nestedScroll({ scrollForward: NestedScrollMode.SELF_FIRST, scrollBackward: NestedScrollMode.SELF_FIRST })
        .cachedCount(8, this.isDesktopLayout())
        .onScrollIndex((start: number): void => {
          if (start >= this.visibleNotifications(index).length - 4) {
            if (index === this.notificationFilter) { this.requestMoreNotifications(); }
          }
        })
          .onDidScroll((scrollOffset: number): void => {
            if (index === this.notificationFilter) { this.onChromeScroll(scrollOffset); }
          })
          .onScrollStop((): void => {
            if (index === this.notificationFilter) { this.onChromeScrollStop(); }
          })
          .onReachEnd((): void => {
            if (index === this.notificationFilter) { this.requestMoreNotifications(); }
          })
        }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themedPageSurface())
  }

  @Builder
  private NotificationsWaterFlow(index: number, standalone: boolean = false): void {
    WaterFlow({
      scroller: this.contentPageScroller('notifications', index.toString()),
      sections: this.pageSections('notifications', index.toString(), this.visibleNotifications(index).length),
      layoutMode: WaterFlowLayoutMode.SLIDING_WINDOW
    }) {
      ForEach(this.pagedFlowItems(this.visibleNotifications(index).length), (itemIndex: number) => {
        FlowItem() {
          if (itemIndex === 0) {
            this.NotificationsWaterFlowHeader(standalone, index)
          } else if (itemIndex > this.visibleNotifications(index).length) {
            this.NotificationsWaterFlowFooter(index)
          } else {
            this.NotificationItem(this.visibleNotifications(index)[itemIndex - 1])
          }
        }
        .width('100%')
      }, (itemIndex: number): string => 'notification-flow-' + itemIndex.toString())
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themedPageSurface())
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .scrollBar(BarState.Off)
    .contentEndOffset(this.contentBottomInset())
    .clipContent(this.isDesktopLayout() ? ContentClipMode.SAFE_AREA : ContentClipMode.BOUNDARY)
    .clip(!this.isDesktopLayout())
    .nestedScroll({ scrollForward: NestedScrollMode.SELF_FIRST, scrollBackward: NestedScrollMode.SELF_FIRST })
    .cachedCount(8, this.isDesktopLayout())
    .columnsTemplate(this.timelineColumnsTemplate())
    .rowsGap(0)
    .columnsGap(1)
    .onScrollIndex((start: number): void => {
      if (start >= this.visibleNotifications(index).length - 2) {
        if (index === this.notificationFilter) { this.requestMoreNotifications(); }
      }
    })
    .onDidScroll((scrollOffset: number): void => {
      if (index === this.notificationFilter) { this.onChromeScroll(scrollOffset); }
    })
    .onScrollStop((): void => {
      if (index === this.notificationFilter) { this.onChromeScrollStop(); }
    })
    .onReachEnd((): void => {
      if (index === this.notificationFilter) { this.requestMoreNotifications(); }
    })
  }

  @Builder
  private NotificationsWaterFlowHeader(standalone: boolean = false, index: number = 0): void {
    Column({ space: 0 }) {
      Column()
        .width('100%')
        .height(this.notificationsContentTopInset(standalone))
      if (this.notificationPageStatus(index).length > 0) {
        Text(this.notificationPageStatus(index)).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('app.color.text_secondary'))
          .width('92%')
          .padding({ top: 4, bottom: 8 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private NotificationItem(n: AppNotification): void {
    if (NotificationPresentation.isPost(n)) {
      NotificationTweetCard({ tweet: this.notificationTweet(n), compactAuthorHeader: true, showReplyContext: true,
        videoFeedEnabled: true,
        onLikeChanged: (tweet: Tweet, liked: boolean): Promise<boolean> => this.onLike(tweet, liked),
        onRepostChanged: (tweet: Tweet, reposted: boolean): Promise<boolean> => this.onRepost(tweet, reposted),
        onReply: (tweet: Tweet): void => this.onReply(tweet),
        onOpen: (tweet: Tweet): void => this.openPost(tweet),
        onVideoOpen: (tweet: Tweet, media: MediaAttachment): void => this.openVideoFeed(tweet, media),
        onAuthorTapped: (tweet: Tweet): void => this.openUser(tweet),
        onMentionTapped: (handle: string): void => this.openMention(handle) })
    } else {
      NotificationSummary({ notification: n, onOpen: (): void => this.openNotification(n),
        onAuthor: (author: TweetAuthor): void => {
          this.openContentDestination();
          const param: UserDetailRouteParam = { author: author, posts: [] };
          this.navPathStack.pushPath({ name: 'UserDetail', param: param });
        } })
    }
  }

  @Builder
  private NotificationsWaterFlowFooter(index: number): void {
    Row() {
      if (this.notificationPageLoading(index)) {
        LoadingProgress()
          .width(18)
          .height(18)
          .color(this.accentColor)
      } else if (this.notificationPageHasMore(index)) {
        Text($r('app.string.timeline_load_more')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('app.color.text_secondary'))
      }
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ top: 16, bottom: 16 })
  }

  private notificationIcon(kind: string): Resource {
    if (kind === 'like') {
      return $r('sys.symbol.heart_fill');
    }
    if (kind === 'repost') {
      return $r('sys.symbol.repeat');
    }
    if (kind === 'follow') {
      return $r('sys.symbol.person_badge_plus');
    }
    if (kind === 'recommendation') {
      return $r('sys.symbol.star_fill');
    }
    if (kind === 'security') {
      return $r('sys.symbol.seal_shield_fill');
    }
    if (kind === 'mention' || kind === 'reply') {
      return $r('sys.symbol.text_bubble_left_2');
    }
    return $r('sys.symbol.bell_fill');
  }

  private notificationColor(kind: string): Resource | string {
    if (kind === 'like') {
      return $r('app.color.like');
    }
    if (kind === 'repost') {
      return $r('app.color.repost');
    }
    return this.accentColor;
  }

  private chatRowSeparatorWidth(): number {
    try {
      return this.getUIContext().getHostContext()?.resourceManager.getNumber($r('app.float.chat_row_separator_width').id) ?? 0.5;
    } catch (error) {
      return 0.5;
    }
  }

  @Builder
  private MessagesTab(): void {
    Stack({ alignContent: Alignment.Top }) {
    Refresh({ refreshing: $$this.messagesRefreshing, builder: this.HiddenRefreshSpinner() }) {
      List({ scroller: this.messagesScroller }) {
        ListItem() { Column().height(this.messagesContentTopInset()) }
        if (this.messagesLoading && this.messages.length === 0) {
          ListItem() { LoadingProgress().color(this.accentColor).width(24).height(24).margin(24) }
        }
        if (this.messagesStatus.length > 0 && this.messages.length === 0) {
          ListItem() {
            Column({ space: 12 }) {
              Text(this.messagesStatus).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary'))
                .textAlign(TextAlign.Center)
              Button($r('app.string.common_retry')).fontColor(this.accentColor).backgroundColor(Color.Transparent)
                .onClick((): void => this.refreshMessages())
            }.width('100%').padding(24)
          }
        } else if (this.visibleChats().length === 0 && !this.messagesLoading) {
          ListItem() {
            Text(this.chatSearch.length > 0 ? $r('app.string.chat_no_results') : $r('app.string.dm_empty')).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_secondary')).width('100%')
              .textAlign(TextAlign.Center).padding(24)
          }
        }
        ForEach(this.visibleChats(), (message: DirectMessage) => {
          ListItem() {
            ConversationInboxRow({ message: message, separatorWidth: this.chatRowSeparatorWidth(),
              selected: this.isDesktopLayout() && message.conversationId === this.desktopConversationId })
              .onClick((): void => this.openConversation(message))
              .bindContextMenu(this.ChatConversationMenu(message), ResponseType.LongPress, {
                onDisappear: (): void => { this.chatMenuDismissed(); }
              })
          }
        }, (message: DirectMessage): string => message.id + '|' + message.preview + '|' + message.time + '|' + message.unread + '|' + (message.pinned ?? false) + '|' + (message.avatarUrl ?? ''))
        ListItem() { Column().height(this.navigationIndicatorHeight + 96) }
      }.width('100%').height('100%').padding({ left: 16, right: 16 }).backgroundColor(this.themedPageSurface())
        .clip(!this.isDesktopLayout()).cachedCount(4, this.isDesktopLayout())
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true }).scrollBar(BarState.Off)
        .onDidScroll((scrollOffset: number): void => { this.onChromeScroll(scrollOffset); })
        .onScrollStop((): void => { this.onChromeScrollStop(); })
    }.clip(!this.isDesktopLayout()).onRefreshing((): void => this.refreshMessages())
      .onOffsetChange((offset: number): void => { this.messagesRefreshPullOffset = offset; })
    RootRefreshIndicator({ topInset: this.messagesContentTopInset(), pullOffset: this.messagesRefreshPullOffset,
      refreshing: this.messagesRefreshing, phoneLayout: !this.isDesktopLayout() })
    }.width('100%').height('100%')
  }

  @Builder
  private MeTab(): void {
    if (!this.hasAnySession()) { this.LegacyMeTab() }
    else {
      Stack({ alignContent: Alignment.Top }) {
      Refresh({ refreshing: $$this.meRefreshing, builder: this.HiddenRefreshSpinner() }) {
        Scroll(this.profileScroller) {
          Column({ space: 12 }) {
            this.MeProfileSummary()
            this.MeTimelinePicker()
            Swiper(this.mePager) {
              this.MeWaterFlow(0)
              this.MeWaterFlow(1)
            }.width('100%').height(Math.max(1, (this.windowHeight > 0 ? this.windowHeight : 844) - this.contentTopInset() - 52))
              .index(this.meTimelineTab).loop(false).indicator(false).cachedCount(1)
              .duration(280).curve(Curve.EaseOut).clip(true).disableSwipe(this.meRefreshing)
              .onAppear((): void => { this.meTabPosition = this.meTimelineTab; })
              .onChange((index: number): void => { this.selectMeTimeline(index); })
              .onContentDidScroll((_selected: number, index: number, position: number, _length: number): void => {
                this.meTabPosition = ProfileTabMotion.scrollPosition(index, position, 2);
                this.ensureMeTimelineLoaded(index);
              })
              .onAnimationStart((_index: number, target: number): void => { this.ensureMeTimelineLoaded(target); })
              .onAnimationEnd((index: number): void => { this.meTabPosition = index; })
          }.width('100%').padding({ top: this.contentTopInset() })
        }.width('100%').height('100%').scrollBar(BarState.Off)
          .onDidScroll((offset: number): void => { this.onChromeScroll(offset); })
          .onScrollStop((): void => { this.onChromeScrollStop(); })
      }.width('100%').height('100%').onRefreshing((): void => { this.onMeRefresh(); })
        .onOffsetChange((offset: number): void => { this.meRefreshPullOffset = offset; })
      RootRefreshIndicator({ topInset: this.contentTopInset(), pullOffset: this.meRefreshPullOffset,
        refreshing: this.meRefreshing, phoneLayout: !this.isDesktopLayout() })
      }.width('100%').height('100%')
    }
  }

  @Builder
  private LegacyMeTab(): void {
    if (this.useTimelineWaterFlow() && this.hasAnySession() && this.visibleMePosts().length > 0) {
      Stack({ alignContent: Alignment.Top }) {
      Refresh({ refreshing: $$this.meRefreshing, builder: this.HiddenRefreshSpinner() }) {
        this.MeWaterFlow()
      }
      .width('100%')
      .height('100%')
      .clip(!this.isDesktopLayout())
      .onOffsetChange((offset: number): void => { this.meRefreshPullOffset = offset; })
      .onRefreshing((): void => {
        this.onMeRefresh();
      })
      RootRefreshIndicator({ topInset: this.contentTopInset(), pullOffset: this.meRefreshPullOffset,
        refreshing: this.meRefreshing, phoneLayout: !this.isDesktopLayout() })
      }.width('100%').height('100%')
    } else {
      Stack({ alignContent: Alignment.Top }) {
      Refresh({ refreshing: $$this.meRefreshing, builder: this.HiddenRefreshSpinner() }) {
        Scroll(this.profileScroller) {
      Column({ space: 12 }) {
        Stack({ alignContent: Alignment.TopStart }) {
          if (this.profileCardBannerUrl().length > 0) {
            Image(this.profileCardBannerUrl())
              .width('100%')
              .height('100%')
              .objectFit(ImageFit.Cover)
          } else {
            Column()
              .width('100%')
              .height('100%')
              .linearGradient({
                angle: 132,
                colors: [
                  [this.profileCardColor(0.64, 28), 0.0],
                  [this.profileCardColor(0.42, 0), 0.56],
                  [this.profileCardColor(0.22, -26), 1.0]
                ]
              })
          }

          Column()
            .width('100%')
            .height('100%')
            .backgroundColor($r('app.color.profile_hero_scrim'))

          Column({ space: 6 }) {
            if (this.profile !== null && this.profile.avatarUrl !== undefined && this.profile.avatarUrl.length > 0) {
              Image(this.profile.avatarUrl)
                .width(64)
                .height(64)
                .objectFit(ImageFit.Cover)
                .borderRadius(userAvatarRadius(64, 32, this.profile?.verifiedType ?? '', this.profile?.avatarShape ?? ''))
                .clip(true)
            } else {
              Text(this.avatarInitial()).fontFamily(this.appFontFamily)
                .width(64)
                .height(64)
                .fontSize($r('sys.float.Title_L'))
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_on_accent'))
                .backgroundColor(this.accentColor)
                .borderRadius(userAvatarRadius(64, 32, this.profile?.verifiedType ?? '', this.profile?.avatarShape ?? ''))
                .textAlign(TextAlign.Center)
            }
            Text(this.profile !== null && this.profile.name.length > 0 ? this.profile.name :
              (this.handleText.length > 0 ? this.handleText : $r('app.string.profile_welcome'))).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Title_S'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_on_brand'))
            Row({ space: 4 }) {
                if (this.hasAnySession()) {
                  SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
                    .fontSize(14)
                    .fontColor([$r('app.color.repost')])
                }
              Text(this.hasAnySession() ? $r('app.string.profile_signed_in') : $r('app.string.profile_browse_free')).fontFamily(this.appFontFamily)
                .fontSize($r('sys.float.Body_M'))
                .fontColor($r('app.color.profile_hero_muted'))
            }
          }
          .width('100%')
          .padding(18)
          .alignItems(HorizontalAlign.Start)
        }
        .width('92%')
        .height(184)
        .borderRadius(22)
        .clip(true)
        .margin({ top: 12 })
        .visualEffect(new hdsEffect.HdsEffectBuilder()
          .pointLight({
            illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
          })
          .buildEffect())

        if (this.profile !== null) {
          if (this.profile.description.length > 0) {
            Text(this.profile.description).fontFamily(this.appFontFamily)
              .width('92%')
              .fontSize($r('sys.float.Body_M'))
              .fontColor($r('app.color.text_primary'))
          }
          Row({ space: 16 }) {
            Row({ space: 4 }) {
              Text(formatCount(this.profile.followingCount)).fontFamily(this.appFontFamily)
                .fontSize($r('sys.float.Body_M'))
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'))
              Text($r('app.string.profile_following')).fontFamily(this.appFontFamily)
                .fontSize($r('sys.float.Body_M'))
                .fontColor($r('app.color.text_secondary'))
            }
            .padding({ top: 8, bottom: 8 })
            .onClick((): void => {
              this.openOwnUserList(USER_LIST_FOLLOWING);
            })

            Row({ space: 4 }) {
              Text(formatCount(this.profile.followersCount)).fontFamily(this.appFontFamily)
                .fontSize($r('sys.float.Body_M'))
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'))
              Text($r('app.string.profile_followers')).fontFamily(this.appFontFamily)
                .fontSize($r('sys.float.Body_M'))
                .fontColor($r('app.color.text_secondary'))
            }
            .padding({ top: 8, bottom: 8 })
            .onClick((): void => {
              this.openOwnUserList(USER_LIST_FOLLOWERS);
            })

            Text(formatCount(this.profile.postCount) + ' ' + this.text($r('app.string.profile_posts'))).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_M'))
              .fontColor($r('app.color.text_secondary'))
          }
          .width('92%')
        }

        if (this.hasAnySession()) {
          this.MeTimelinePicker()
          if (this.visibleMeTimelineLoading()) {
            LoadingProgress().width(18).height(18).color(this.accentColor).margin(16)
          } else if (this.visibleMePosts().length === 0) {
            Text(this.visibleMeTimelineStatus()).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_M'))
              .fontColor($r('app.color.text_secondary'))
              .width('92%')
          }
          ForEach(this.visibleMePosts(), (tweet: Tweet) => {
            TweetCard({
              tweet: tweet,
              videoFeedEnabled: true,
              onLikeChanged: (t: Tweet, liked: boolean): Promise<boolean> => this.onLike(t, liked),
              onRepostChanged: (t: Tweet, reposted: boolean): Promise<boolean> => this.onRepost(t, reposted),
              onReply: (t: Tweet): void => this.onReply(t),
              onOpen: (t: Tweet): void => this.openPost(t),
              onVideoOpen: (t: Tweet, media: MediaAttachment): void => this.openVideoFeed(t, media),
              onAuthorTapped: (t: Tweet): void => this.openUser(t),
              onMentionTapped: (handle: string): void => this.openMention(handle)
            })
          }, (tweet: Tweet) => tweet.id)
          if (this.visibleMeTimelineHasMore()) {
            Button(this.visibleMeTimelineLoadingMore() ? $r('app.string.status_loading') :
              $r('app.string.timeline_load_more'), { stateEffect: true })
              .width('92%')
              .enabled(!this.visibleMeTimelineLoadingMore())
              .onClick((): void => { this.loadMoreMeTimeline(); })
          }
        }

        if (this.hasAnySession()) {
          Button($r('app.string.accounts_manage'), { stateEffect: true })
            .width('92%')
            .backgroundColor(this.themedSecondaryButtonSurface())
            .fontColor($r('app.color.text_primary'))
            .onClick((): void => this.openLoginSheet())
          Button($r('app.string.profile_sign_out'), { stateEffect: true })
            .width('92%')
            .backgroundColor(this.themedSecondaryButtonSurface())
            .fontColor($r('app.color.danger'))
            .onClick(() => this.signOut())
        } else {
          Button($r('app.string.profile_sign_in'), { stateEffect: true })
            .width('92%')
            .backgroundColor(this.accentColor)
            .fontColor($r('app.color.text_on_accent'))
            .onClick(() => this.goLogin())
        }

        Button($r('app.string.about_title'), { stateEffect: true }).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M'))
          .fontColor(this.accentColor)
          .backgroundColor(Color.Transparent)
          .width('92%')
          .padding($r('app.float.about_row_gap'))
          .margin({ top: 8 })
          .onClick((): void => this.openRootContent({ name: 'About' }))
      }
      .width('100%')
      .padding({ top: this.contentTopInset(), bottom: this.navigationIndicatorHeight + 96 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themedPageSurface())
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .scrollBar(BarState.Off)
      .clip(!this.isDesktopLayout())
      .onDidScroll((scrollOffset: number): void => {
        this.onChromeScroll(scrollOffset);
      })
      .onScrollStop((): void => {
        this.onChromeScrollStop();
      })
      }
      .width('100%')
      .height('100%')
      .clip(!this.isDesktopLayout())
      .onOffsetChange((offset: number): void => { this.meRefreshPullOffset = offset; })
      .onRefreshing((): void => {
        this.onMeRefresh();
      })
      RootRefreshIndicator({ topInset: this.contentTopInset(), pullOffset: this.meRefreshPullOffset,
        refreshing: this.meRefreshing, phoneLayout: !this.isDesktopLayout() })
      }.width('100%').height('100%')
    }
  }

  @Builder
  private MeTimelinePicker(): void {
    AnimatedIconTabs({ items: [
      { key: 'posts', label: $r('app.string.profile_detail_posts'), icon: $r('sys.symbol.doc_plaintext') },
      { key: 'likes', label: $r('app.string.profile_detail_likes'), icon: $r('sys.symbol.heart') }
    ], selected: this.meTimelineTab, tabPosition: this.meTabPosition,
      onSelect: (index: number): void => this.mePager.changeIndex(index, true) })
      .width('92%').margin({ top: 10 })
  }

  @Builder
  private MeWaterFlow(index: number = this.meTimelineTab): void {
    WaterFlow({
      scroller: this.contentPageScroller('me', index.toString()),
      sections: this.pageSections('me', index.toString(), this.visibleMePosts(index).length),
      layoutMode: WaterFlowLayoutMode.SLIDING_WINDOW
    }) {
      ForEach(this.pagedFlowItems(this.visibleMePosts(index).length), (itemIndex: number) => {
        FlowItem() {
          if (itemIndex === 0) {
            this.MeWaterFlowHeader(index)
          } else if (itemIndex > this.visibleMePosts(index).length) {
            this.MeWaterFlowFooter(index)
          } else {
            this.MeOwnPostCard(this.visibleMePosts(index)[itemIndex - 1])
          }
        }
        .width('100%')
      }, (itemIndex: number): string => 'me-flow-' + itemIndex.toString())
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themedPageSurface())
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .scrollBar(BarState.Off)
    .nestedScroll({ scrollForward: NestedScrollMode.PARENT_FIRST, scrollBackward: NestedScrollMode.SELF_FIRST })
    .clipContent(this.isDesktopLayout() ? ContentClipMode.SAFE_AREA : ContentClipMode.BOUNDARY)
    .clip(!this.isDesktopLayout())
    .cachedCount(8, this.isDesktopLayout())
    .columnsTemplate(this.timelineColumnsTemplate())
    .rowsGap(0)
    .columnsGap(1)
    .onScrollIndex((start: number): void => {
      if (start >= this.visibleMePosts(index).length - 2 && this.visibleMeTimelineHasMore(index) &&
        !this.visibleMeTimelineLoadingMore(index)) {
        if (index === this.meTimelineTab) { this.loadMoreMeTimeline(index); }
      }
    })
    .onDidScroll((scrollOffset: number): void => {
      if (index === this.meTimelineTab) { this.onChromeScroll(scrollOffset); }
    })
    .onScrollStop((): void => {
      if (index === this.meTimelineTab) { this.onChromeScrollStop(); }
    })
    .onReachEnd((): void => {
      if (this.visibleMeTimelineHasMore(index) && !this.visibleMeTimelineLoadingMore(index)) {
        if (index === this.meTimelineTab) { this.loadMoreMeTimeline(index); }
      }
    })
  }

  @Builder
  private MeWaterFlowHeader(index: number): void {
    Column({ space: 12 }) {
      if (this.visibleMeTimelineLoading(index)) {
        LoadingProgress()
          .width(18)
          .height(18)
          .color(this.accentColor)
          .margin(16)
      } else if (this.visibleMePosts(index).length === 0) {
        Text(this.visibleMeTimelineStatus(index)).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('app.color.text_secondary'))
          .width('92%')
      }
    }
    .width('100%')
    .padding({ top: 8 })
  }

  @Builder
  private MeProfileSummary(): void {
    Column({ space: 12 }) {
      Stack({ alignContent: Alignment.TopStart }) {
        if (this.profileCardBannerUrl().length > 0) {
          Image(this.profileCardBannerUrl())
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Cover)
        } else {
          Column()
            .width('100%')
            .height('100%')
            .linearGradient({
              angle: 132,
              colors: [
                [this.profileCardColor(0.64, 28), 0.0],
                [this.profileCardColor(0.42, 0), 0.56],
                [this.profileCardColor(0.22, -26), 1.0]
              ]
            })
        }

        Column()
          .width('100%')
          .height('100%')
          .backgroundColor($r('app.color.profile_hero_scrim'))

        Column({ space: 6 }) {
          if (this.profile !== null && this.profile.avatarUrl !== undefined && this.profile.avatarUrl.length > 0) {
            Image(this.profile.avatarUrl)
              .width(64)
              .height(64)
              .objectFit(ImageFit.Cover)
              .borderRadius(userAvatarRadius(64, 32, this.profile?.verifiedType ?? '', this.profile?.avatarShape ?? ''))
              .clip(true)
          } else {
            Text(this.avatarInitial()).fontFamily(this.appFontFamily)
              .width(64)
              .height(64)
              .fontSize($r('sys.float.Title_L'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_on_accent'))
              .backgroundColor(this.accentColor)
              .borderRadius(userAvatarRadius(64, 32, this.profile?.verifiedType ?? '', this.profile?.avatarShape ?? ''))
              .textAlign(TextAlign.Center)
          }
          Text(this.profile !== null && this.profile.name.length > 0 ? this.profile.name :
            (this.handleText.length > 0 ? this.handleText : $r('app.string.profile_welcome'))).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Title_S'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_on_brand'))
          Row({ space: 4 }) {
            if (this.hasAnySession()) {
              SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
                .fontSize(14)
                .fontColor([$r('app.color.repost')])
            }
            Text(this.hasAnySession() ? $r('app.string.profile_signed_in') : $r('app.string.profile_browse_free')).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_M'))
              .fontColor($r('app.color.profile_hero_muted'))
          }
        }
        .width('100%')
        .padding(18)
        .alignItems(HorizontalAlign.Start)
      }
      .width('92%')
      .height(184)
      .borderRadius(22)
      .clip(true)
      .margin({ top: 12 })
      .visualEffect(new hdsEffect.HdsEffectBuilder()
        .pointLight({
          illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
        })
        .buildEffect())

      if (this.profile !== null) {
        if (this.profile.description.length > 0) {
          Text(this.profile.description).fontFamily(this.appFontFamily)
            .width('92%')
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('app.color.text_primary'))
        }
        Row({ space: 16 }) {
          Row({ space: 4 }) {
            Text(formatCount(this.profile.followingCount)).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_M'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
            Text($r('app.string.profile_following')).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_M'))
              .fontColor($r('app.color.text_secondary'))
          }
          .padding({ top: 8, bottom: 8 })
          .onClick((): void => {
            this.openOwnUserList(USER_LIST_FOLLOWING);
          })

          Row({ space: 4 }) {
            Text(formatCount(this.profile.followersCount)).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_M'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
            Text($r('app.string.profile_followers')).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_M'))
              .fontColor($r('app.color.text_secondary'))
          }
          .padding({ top: 8, bottom: 8 })
          .onClick((): void => {
            this.openOwnUserList(USER_LIST_FOLLOWERS);
          })

          Text(formatCount(this.profile.postCount) + ' ' + this.text($r('app.string.profile_posts'))).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('app.color.text_secondary'))
        }
        .width('92%')
      }
    }
    .width('100%')
  }

  @Builder
  private MeOwnPostCard(tweet: Tweet): void {
    TweetCard({
      tweet: tweet,
      videoFeedEnabled: true,
      onLikeChanged: (t: Tweet, liked: boolean): Promise<boolean> => this.onLike(t, liked),
      onRepostChanged: (t: Tweet, reposted: boolean): Promise<boolean> => this.onRepost(t, reposted),
      onReply: (t: Tweet): void => this.onReply(t),
      onOpen: (t: Tweet): void => this.openPost(t),
      onVideoOpen: (t: Tweet, media: MediaAttachment): void => this.openVideoFeed(t, media),
      onAuthorTapped: (t: Tweet): void => this.openUser(t),
      onMentionTapped: (handle: string): void => this.openMention(handle)
    })
  }

  @Builder
  private MeWaterFlowFooter(index: number = this.meTimelineTab): void {
    Column({ space: 12 }) {
      if (this.visibleMeTimelineHasMore(index)) {
        Button(this.visibleMeTimelineLoadingMore(index) ? $r('app.string.status_loading') :
          $r('app.string.timeline_load_more'), { stateEffect: true })
          .width('92%')
          .enabled(!this.visibleMeTimelineLoadingMore(index))
          .onClick((): void => {
            this.loadMoreMeTimeline(index);
          })
      }
      Button($r('app.string.accounts_manage'), { stateEffect: true })
        .width('92%')
        .backgroundColor(this.themedSecondaryButtonSurface())
        .fontColor($r('app.color.text_primary'))
        .onClick((): void => this.openLoginSheet())
      Button($r('app.string.profile_sign_out'), { stateEffect: true })
        .width('92%')
        .backgroundColor(this.themedSecondaryButtonSurface())
        .fontColor($r('app.color.danger'))
        .onClick((): void => {
          this.signOut();
        })
      Button($r('app.string.about_title'), { stateEffect: true }).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_M'))
        .fontColor(this.accentColor)
        .backgroundColor(Color.Transparent)
        .width('92%')
        .padding($r('app.float.about_row_gap'))
        .margin({ top: 8 })
        .onClick((): void => this.openRootContent({ name: 'About' }))
    }
    .width('100%')
    .padding({ bottom: this.navigationIndicatorHeight + 96 })
  }
}
