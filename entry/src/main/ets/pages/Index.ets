// Harmony X main page — iOS-X-style layout built with HarmonyOS design
// components: Navigation + bottom Tabs, SymbolGlyph tab/action icons,
// floating compose button opening a bottom-sheet composer, Search,
// pull-to-refresh, toasts. Theme resources (base + dark) follow the device
// light/dark mode; text uses HarmonyOS Sans (system default).
// The timeline is open (sample posts, zero setup). OAuth sign-in — the only
// auth method — unlocks live data and interactions.
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import common from '@ohos.app.ability.common';
import { deviceInfo } from '@kit.BasicServicesKit';
import { LengthMetrics, SymbolGlyphModifier, uiMaterial } from '@kit.ArkUI';
import {
  DividerShowType,
  HdsNavigation,
  HdsNavigationTitleMode,
  HdsTabs,
  HdsTabsController,
  HdsTabsModifier,
  HdsSideBar,
  hdsEffect,
  hdsMaterial,
  ScrollEffectType,
  TitleBarStyleOptions
} from '@kit.UIDesignKit';
import { FloatingComposeButton } from '../components/FloatingComposeButton';
import { TweetCard } from '../components/TweetCard';
import { formatCount } from '../models/Tweet';
import type { Tweet, AppNotification, DirectMessage, UserProfile } from '../models/Tweet';
import { MockData } from '../services/MockData';
import { XApiClient } from '../services/XApiClient';
import type { TweetPage } from '../services/XApiClient';
import { authStore } from '../services/AuthStore';
import { PostDetailBuilder } from './PostDetail';
import type { PostDetailRouteParam } from './PostDetail';
import { ReplyComposerBuilder } from '../components/ReplyComposer';
import { XSideDrawer } from '../components/XSideDrawer';
import { SettingsBuilder, SettingsSectionBuilder } from './Settings';
import { HelpCenterBuilder } from './HelpCenter';
import { UserDetailBuilder } from './UserDetail';
import type { UserDetailRouteParam } from './UserDetail';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';

// iOS-style bottom-sheet composer.
@CustomDialog
struct ComposeSheet {
  controller?: CustomDialogController;
  @Prop initialText: string = '';
  @Prop replyUser: string = '';
  @State draft: string = '';
  @StorageLink('harmonyx.accent_color') accentColor: string = '#007DFF';
  onCancel: () => void = () => {
  };
  onPost: (text: string) => void = () => {
  };

  aboutToAppear(): void {
    this.draft = this.initialText;
  }

  private text(resource: Resource): string {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    return context.resourceManager.getStringSync(resource);
  }

  build(): void {
    Column({ space: 12 }) {
      Row() {
        Button($r('app.string.compose_cancel'), { stateEffect: true })
          .fontSize(15)
          .backgroundColor($r('app.color.bg_secondary_btn'))
          .fontColor($r('app.color.text_primary'))
          .onClick(() => this.onCancel())
        Blank()
        Button($r('app.string.compose_post'), { stateEffect: true })
          .fontSize(15)
          .backgroundColor(this.accentColor)
          .fontColor($r('app.color.text_on_brand'))
          .enabled(this.draft.trim().length > 0)
          .onClick(() => this.onPost(this.draft))
      }
      .width('100%')
      if (this.replyUser.length > 0) {
        Text(this.text($r('app.string.compose_replying_to')) + this.replyUser)
          .fontSize(13)
          .fontColor(this.accentColor)
          .width('100%')
      }
      TextArea({ placeholder: $r('app.string.compose_placeholder'), text: this.draft })
        .height(140)
        .backgroundColor($r('app.color.bg_field'))
        .fontColor($r('app.color.text_primary'))
        .onChange((v: string) => {
          this.draft = v;
        })
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius({ topLeft: 20, topRight: 20 })
  }
}

@Entry
@Component
struct Index {
  @State currentTab: number = 0;
  // 0 = For you (recommended), 1 = Following.
  @State homeFeedMode: number = 0;
  @State timeline: Tweet[] = [];
  @State trends: string[] = [];
  @State exploreResults: Tweet[] = [];
  @State notifications: AppNotification[] = [];
  @State messages: DirectMessage[] = [];
  @State profile: UserProfile | null = null;
  @State exploreStatus: string = '';
  @State notificationsStatus: string = '';
  @State messagesStatus: string = '';
  @State replyToId: string = '';
  @State replyToUser: string = '';
  @State statusLine: string = '';
  @State searchText: string = '';
  @State refreshing: boolean = false;
  @State loading: boolean = true;
  @State loadingMore: boolean = false;
  @State hasMoreTimeline: boolean = true;
  @State loadingMoreExplore: boolean = false;
  @State hasMoreExplore: boolean = false;
  @State handleText: string = '';
  @State liveBadge: string = '';
  @State showSideDrawer: boolean = false;
  @StorageLink('harmonyx.breakpoint') @Watch('onBreakpointChange') breakpoint: string = ResponsiveLayout.BREAKPOINT_SM;
  @StorageLink('harmonyx.content_destination_open') @Watch('onContentDestinationChange')
  contentDestinationOpen: boolean = false;
  @State mainNavigationMode: NavigationMode = NavigationMode.Stack;
  @StorageLink('harmonyx.accent_color') @Watch('configureImmersiveTabs') accentColor: string = '#007DFF';
  @StorageLink('harmonyx.font_scale') fontScale: number = 1;
  @StorageProp('harmonyx.status_bar_height') statusBarHeight: number =
    AppStorage.get<number>('harmonyx.status_bar_height') ?? 0;
  @StorageProp('harmonyx.navigation_indicator_height') @Watch('configureImmersiveTabs') navigationIndicatorHeight: number =
    AppStorage.get<number>('harmonyx.navigation_indicator_height') ?? 0;
  private api: XApiClient = new XApiClient();
  private tabsController: TabsController = new TabsController();
  private hdsTabsController: HdsTabsController = new HdsTabsController();
  @State hdsTabsModifier: HdsTabsModifier = new HdsTabsModifier();
  @Provide('pageStack') navPathStack: NavPathStack = new NavPathStack();
  private homeScroller: Scroller = new Scroller();
  private exploreScroller: Scroller = new Scroller();
  private notificationsScroller: Scroller = new Scroller();
  private messagesScroller: Scroller = new Scroller();
  private profileScroller: Scroller = new Scroller();
  private searchController: SearchController = new SearchController();
  private composeController: CustomDialogController | null = null;
  private timelineNextToken: string = '';
  private timelineSource: string = '';
  private sampleTimelinePage: number = 0;
  private exploreNextToken: string = '';
  private activeExploreQuery: string = '';
  // Preserve the exact preference-derived query while paging the For You feed.
  private activeRecommendationQuery: string = '';
  private recommendationSignalsLoaded: boolean = false;

  aboutToAppear(): void {
    this.onBreakpointChange();
    this.configureImmersiveTabs();
    this.bindHdsTabScrollers();
    this.statusLine = this.text($r('app.string.status_loading'));
    this.loadTimeline();
  }

  aboutToDisappear(): void {
    if (!this.supportsHdsFloatingMaterial()) {
      return;
    }
    this.hdsTabsController.unbindScroller(this.homeScroller);
    this.hdsTabsController.unbindScroller(this.exploreScroller);
    this.hdsTabsController.unbindScroller(this.notificationsScroller);
    this.hdsTabsController.unbindScroller(this.messagesScroller);
    this.hdsTabsController.unbindScroller(this.profileScroller);
  }

  private text(resource: Resource): string {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    return context.resourceManager.getStringSync(resource);
  }

  private supportsImmersiveMaterial(): boolean {
    return deviceInfo.sdkApiVersion >= 26;
  }

  private supportsHdsNavigation(): boolean {
    return deviceInfo.sdkApiVersion >= 20;
  }

  private supportsHdsFloatingMaterial(): boolean {
    return deviceInfo.sdkApiVersion >= 23;
  }

  private isLargeScreen(): boolean {
    return ResponsiveLayout.isLarge(this.breakpoint);
  }

  private isWideScreen(): boolean {
    return ResponsiveLayout.isWide(this.breakpoint);
  }

  // At 840vp the drawer becomes a persistent navigation rail. At 1200vp we
  // additionally have room for the feed and a destination side by side.
  private onBreakpointChange(): void {
    if (ResponsiveLayout.isSmall(this.breakpoint)) {
      this.showSideDrawer = false;
      this.updateNavigationMode();
      return;
    }
    this.showSideDrawer = this.isLargeScreen();
    this.updateNavigationMode();
  }

  private onContentDestinationChange(): void {
    this.updateNavigationMode();
  }

  private updateNavigationMode(): void {
    this.mainNavigationMode = this.isWideScreen() && this.contentDestinationOpen ?
      NavigationMode.Split : NavigationMode.Stack;
  }

  private openContentDestination(): void {
    ResponsiveLayout.openContentDestination();
    this.updateNavigationMode();
    if (!this.isLargeScreen()) {
      this.showSideDrawer = false;
    }
  }

  private contentTopInset(): number {
    if (!this.supportsHdsNavigation()) {
      return 12;
    }
    if (this.currentTab === 0) {
      return this.statusBarHeight + 104;
    }
    return this.statusBarHeight + 64;
  }

  private exploreContentTopInset(): number {
    if (!this.supportsHdsNavigation()) {
      return 12;
    }
    // The Explore title bar keeps the identity row and adds a second search row.
    // Leave an extra touch-safe gap before the first list item.
    return this.statusBarHeight + 112;
  }

  private titleBarStyle(): TitleBarStyleOptions {
    return {
      scrollEffectOpts: {
        enableScrollEffect: true,
        scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR,
        blurEffectiveStartOffset: LengthMetrics.vp(0),
        blurEffectiveEndOffset: LengthMetrics.vp(16)
      },
      originalStyle: {
        backgroundStyle: {
          backgroundColor: $r('sys.color.ohos_id_color_background_transparent')
        },
        contentStyle: {
          titleStyle: {
            mainTitleColor: $r('app.color.text_primary'),
            subTitleColor: $r('app.color.text_secondary')
          },
          backIconStyle: { iconColor: $r('app.color.text_primary') },
          subIconStyle: { iconColor: $r('app.color.text_primary') },
          menuStyle: { iconColor: $r('app.color.text_primary') }
        }
      },
      scrollEffectStyle: {
        backgroundStyle: {
          backgroundColor: $r('app.color.bg_page')
        },
        contentStyle: {
          titleStyle: {
            mainTitleColor: $r('app.color.text_primary'),
            subTitleColor: $r('app.color.text_secondary')
          },
          backIconStyle: { iconColor: $r('app.color.text_primary') },
          subIconStyle: { iconColor: $r('app.color.text_primary') },
          menuStyle: { iconColor: $r('app.color.text_primary') }
        }
      },
      systemMaterialEffect: {
        materialType: hdsMaterial.MaterialType.IMMERSIVE,
        materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
      }
    };
  }

  private configureImmersiveTabs(): void {
    if (!this.supportsHdsFloatingMaterial()) {
      return;
    }
    this.hdsTabsModifier
      .vertical(false)
      .barPosition(BarPosition.End)
      .barHeight(56)
      .barFloatingStyle({
        adaptToHandedness: true,
        barBottomMargin: this.navigationIndicatorHeight,
        lightColor: this.accentColor,
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.IMMERSIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE,
        },
      });
  }

  private bindHdsTabScrollers(): void {
    if (!this.supportsHdsFloatingMaterial()) {
      return;
    }
    this.hdsTabsController.bindScroller(0, this.homeScroller);
    this.hdsTabsController.bindScroller(1, this.exploreScroller);
    this.hdsTabsController.bindScroller(2, this.notificationsScroller);
    this.hdsTabsController.bindScroller(3, this.messagesScroller);
    this.hdsTabsController.bindScroller(4, this.profileScroller);
  }

  private async loadTimeline(): Promise<void> {
    this.loading = true;
    try {
      const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      await authStore.load(ctx);
      this.api.setToken(authStore.getToken());
      this.api.setUser(authStore.getUserId());
      this.handleText = authStore.getUsername().length > 0 ? '@' + authStore.getUsername() : '';
      await this.fetchPosts();
      await this.loadSupportingData();
    } finally {
      this.loading = false;
      this.refreshing = false;
    }
  }

  // The selected home mode determines the source. Recommended content is never
  // used as an implicit fallback for the Following feed.
  private async fetchPosts(): Promise<void> {
    this.timelineNextToken = '';
    this.timelineSource = '';
    this.sampleTimelinePage = 0;
    this.hasMoreTimeline = false;
    let page: TweetPage | null = null;
    if (authStore.isSignedIn()) {
      if (this.homeFeedMode === 0) {
        this.recommendationSignalsLoaded = false;
        await this.loadRecommendationSignals();
        this.activeRecommendationQuery = this.recommendationSearchQuery();
        page = await this.api.searchRecentPage(this.activeRecommendationQuery);
        if (page !== null && page.tweets.length > 0) {
          this.timelineSource = 'recommend';
        }
      } else if (authStore.getUserId().length > 0) {
        page = await this.api.homeTimelinePage(authStore.getUserId());
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

  private needsAuth(what: string): boolean {
    if (authStore.isSignedIn()) {
      return false;
    }
    promptAction.showToast({ message: this.text($r('app.string.toast_sign_in_to_prefix')) + what, duration: 2000 });
    router.pushUrl({ url: 'pages/Login' });
    return true;
  }

  private onRefresh(): void {
    this.refreshing = true;
    this.fetchPosts().then(async (): Promise<void> => {
      await this.loadSupportingData();
      this.refreshing = false;
    });
  }

  // X supplies personalized trends for the signed-in account. The profile
  // description is a secondary explicit-interest signal when it contains a
  // hashtag. These are collected before the For You query is issued.
  private async loadRecommendationSignals(): Promise<void> {
    if (!authStore.isSignedIn()) {
      this.profile = null;
      this.trends = MockData.trends();
      return;
    }

    this.profile = await this.api.profile();
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
    if (!authStore.isSignedIn()) {
      this.trends = MockData.trends();
      this.notifications = MockData.notifications();
      this.messages = MockData.messages();
      this.profile = null;
      this.exploreStatus = this.text($r('app.string.status_sample_sign_in'));
      this.notificationsStatus = this.text($r('app.string.status_sample_sign_in'));
      this.messagesStatus = this.text($r('app.string.status_sample_sign_in'));
      return;
    }

    if (!this.recommendationSignalsLoaded) {
      await this.loadRecommendationSignals();
    }

    this.exploreStatus = this.trends.length === 0 ? this.text($r('app.string.status_live_data_unavailable')) :
      this.text($r('app.string.status_live_trends'));

    if (authStore.getUserId().length > 0) {
      const liveMentions: AppNotification[] | null = await this.api.mentions(authStore.getUserId());
      this.notifications = liveMentions === null ? [] : liveMentions;
      this.notificationsStatus = liveMentions === null ? this.text($r('app.string.status_live_data_unavailable')) :
        this.text($r('app.string.status_live_mentions'));
    } else {
      this.notifications = [];
      this.notificationsStatus = this.text($r('app.string.status_live_data_unavailable'));
    }

    const liveMessages: DirectMessage[] | null = await this.api.directMessages();
    this.messages = liveMessages === null ? [] : liveMessages;
    this.messagesStatus = liveMessages === null ? this.text($r('app.string.status_dm_scope_required')) :
      this.text($r('app.string.status_live_messages'));

  }

  private openComposer(initial: string, replyToId: string, replyUser: string): void {
    if (this.needsAuth(replyToId.length > 0 ? this.text($r('app.string.action_reply')) :
      this.text($r('app.string.action_post')))) {
      return;
    }
    this.replyToId = replyToId;
    this.replyToUser = replyUser;
    this.composeController = new CustomDialogController({
      builder: ComposeSheet({
        initialText: initial,
        replyUser: replyUser,
        onCancel: (): void => {
          this.composeController?.close();
        },
        onPost: (t: string): void => {
          this.composeController?.close();
          this.publishText(t);
        }
      }),
      alignment: DialogAlignment.Bottom,
      autoCancel: true
    });
    this.composeController.open();
  }

  private publishText(text: string): void {
    const trimmed: string = text.trim();
    if (trimmed.length === 0) {
      return;
    }
    const replyId: string = this.replyToId;
    this.timeline.unshift({
      id: 'local-' + Date.now().toString(),
      author: {
        id: 'me',
        name: this.handleText.length > 0 ? this.handleText : this.text($r('app.string.tab_me')),
        username: authStore.getUsername().length > 0 ? authStore.getUsername() : 'you',
        avatarColor: '#1D9BF0',
        verified: false
      },
      text: trimmed,
      createdAt: 'now',
      metrics: { replyCount: 0, repostCount: 0, likeCount: 0, viewCount: 1 },
      liked: false,
      reposted: false
    });
    this.replyToId = '';
    this.replyToUser = '';
    this.api.postTweet(trimmed, replyId).then((ok: boolean) => {
      promptAction.showToast({ message: ok ? this.text($r('app.string.toast_published')) :
        this.apiFailMsg(this.text($r('app.string.action_post_capitalized'))), duration: 2000 });
    });
  }

  private apiFailMsg(action: string): string {
    if (this.api.lastStatus() === 402) {
      return this.text($r('app.string.api_paid_access'));
    }
    return action + this.text($r('app.string.api_unreachable_suffix'));
  }

  private onLike(t: Tweet, liked: boolean): void {
    if (!authStore.isSignedIn() || authStore.getUserId().length === 0) {
      this.needsAuth(this.text($r('app.string.action_like_posts')));
      return;
    }
    this.api.setLike(t.id, liked).then((ok: boolean) => {
      if (!ok) {
        promptAction.showToast({ message: this.apiFailMsg(this.text($r('app.string.action_like'))), duration: 2000 });
      }
    });
  }

  private onRepost(t: Tweet, reposted: boolean): void {
    if (!authStore.isSignedIn() || authStore.getUserId().length === 0) {
      this.needsAuth(this.text($r('app.string.action_repost')));
      return;
    }
    this.api.setRepost(t.id, reposted).then((ok: boolean) => {
      if (!ok) {
        promptAction.showToast({ message: this.apiFailMsg(this.text($r('app.string.action_repost'))), duration: 2000 });
      }
    });
  }

  private onReply(t: Tweet): void {
    this.openComposer('@' + t.author.username + ' ', t.id, t.author.username);
    if (authStore.isSignedIn()) {
      promptAction.showToast({ message: this.text($r('app.string.toast_replying_to')) + t.author.username, duration: 1500 });
    }
  }

  private appendTimeline(posts: Tweet[]): void {
    const combined: Tweet[] = [];
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
      }
    }
    this.timeline = combined;
  }

  // List.onReachEnd can fire repeatedly while the footer stays visible; the
  // state guard ensures one request per cursor and preserves the reader's spot.
  private async loadMoreTimeline(): Promise<void> {
    if (this.loadingMore || !this.hasMoreTimeline) {
      return;
    }
    this.loadingMore = true;
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

      let page: TweetPage | null = null;
      if (this.timelineSource === 'home') {
        page = await this.api.homeTimelinePage(authStore.getUserId(), this.timelineNextToken);
      } else if (this.timelineSource === 'recommend') {
        page = await this.api.searchRecentPage(this.activeRecommendationQuery, this.timelineNextToken);
      }
      if (page === null) {
        // Keep the existing cursor so a later reach-end event can retry a
        // transient network failure without discarding already-read posts.
        return;
      }
      this.timelineNextToken = page.nextToken;
      this.hasMoreTimeline = page.nextToken.length > 0;
      this.appendTimeline(page.tweets);
    } finally {
      this.loadingMore = false;
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
    if (this.homeFeedMode === mode) {
      return;
    }
    this.homeFeedMode = mode;
    this.timeline = [];
    this.loading = true;
    this.fetchPosts().then(async (): Promise<void> => {
      this.loading = false;
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
    try {
      const page: TweetPage | null = await this.api.searchRecentPage(this.activeExploreQuery, this.exploreNextToken);
      if (page === null) {
        return;
      }
      this.exploreNextToken = page.nextToken;
      this.hasMoreExplore = page.nextToken.length > 0;
      this.appendExploreResults(page.tweets);
    } finally {
      this.loadingMoreExplore = false;
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

  private openPost(tweet: Tweet): void {
    const param: PostDetailRouteParam = { tweet: tweet };
    this.openContentDestination();
    this.navPathStack.pushPath({ name: 'PostDetail', param: param });
  }

  private openUser(tweet: Tweet): void {
    const param: UserDetailRouteParam = { author: tweet.author, posts: this.timeline };
    this.openContentDestination();
    this.navPathStack.pushPath({ name: 'UserDetail', param: param });
  }

  private openSideDrawer(): void {
    this.showSideDrawer = true;
  }

  private openSettings(): void {
    this.openContentDestination();
    this.navPathStack.pushPath({ name: 'Settings' });
  }

  private openHelpCenter(): void {
    if (!this.isLargeScreen()) {
      this.showSideDrawer = false;
    }
    this.openContentDestination();
    this.navPathStack.pushPath({ name: 'HelpCenter' });
  }

  private showDrawerFeature(feature: string): void {
    if (!this.isLargeScreen()) {
      this.showSideDrawer = false;
    }
    promptAction.showToast({ message: feature, duration: 1500 });
  }

  private goMe(): void {
    this.currentTab = 4;
    if (!this.supportsHdsFloatingMaterial()) {
      this.tabsController.changeIndex(4);
    }
  }

  private goLogin(): void {
    router.pushUrl({ url: 'pages/Login' });
  }

  private async signOut(): Promise<void> {
    const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    await authStore.signOut(ctx);
    this.handleText = '';
    this.liveBadge = '';
    await this.fetchPosts();
    await this.loadSupportingData();
    promptAction.showToast({ message: this.text($r('app.string.toast_sign_out')), duration: 1500 });
  }

  @Builder
  private ContentPanelBuilder(): void {
    if (this.supportsHdsNavigation()) {
      HdsNavigation(this.navPathStack) {
        Stack({ alignContent: Alignment.TopStart }) {
          this.MainTabs()

          FloatingComposeButton({
            bottomInset: this.navigationIndicatorHeight,
            onCompose: (): void => {
              this.replyToId = '';
              this.replyToUser = '';
              this.openComposer('', '', '');
            }
          })
        }
        .width('100%')
        .height('100%')
      }
      .titleBar({
        style: this.titleBarStyle(),
        avoidLayoutSafeArea: true,
        content: {
          stackBuilder: (): void => this.ImmersiveTitleBarContent(),
          divider: { showType: DividerShowType.OFF }
        }
      })
      .titleMode(HdsNavigationTitleMode.MINI)
      .mode(this.mainNavigationMode)
      .navBarWidth(480)
      .minContentWidth(360)
      .hideBackButton(true)
      .bindToScrollable([
        this.homeScroller,
        this.exploreScroller,
        this.notificationsScroller,
        this.messagesScroller,
        this.profileScroller
      ])
      .navDestination(this.NavigationBuilder)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.BOTTOM])
      .width('100%')
      .height('100%')
    } else {
      Navigation() {
        Stack({ alignContent: Alignment.TopStart }) {
          this.MainTabs()
          FloatingComposeButton({
            bottomInset: 0,
            onCompose: (): void => {
              this.replyToId = '';
              this.replyToUser = '';
              this.openComposer('', '', '');
            }
          })
        }
        .width('100%')
        .height('100%')
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.bg_page'))
      .title(this.HomeTitle())
      .titleMode(NavigationTitleMode.Mini)
      .mode(NavigationMode.Stack)
      .hideBackButton(true)
    }
  }

  build(): void {
    if (this.supportsHdsNavigation()) {
      Stack() {
        HdsSideBar({
          sideBarPanelBuilder: (): void => { this.SideBarPanelBuilder(); },
          contentPanelBuilder: (): void => { this.ContentPanelBuilder(); },
          isShowSideBar: this.showSideDrawer,
          $isShowSideBar: (show: boolean): void => { this.showSideDrawer = show; },
          onChange: (show: boolean): void => { this.showSideDrawer = show; },
          sideBarWidth: this.isLargeScreen() ? 300 : 330,
          minContentWidth: this.isLargeScreen() ? 520 : 0,
          sideBarContainerType: this.isLargeScreen() ? SideBarContainerType.Embed : SideBarContainerType.Overlay,
          contentAreaMask: !this.isLargeScreen(),
          autoHide: ResponsiveLayout.isSmall(this.breakpoint)
        })
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Transparent)
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.bg_page'))
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    } else {
      this.ContentPanelBuilder();
    }
  }

  @Builder
  private SideBarPanelBuilder(): void {
    XSideDrawer({
      profile: this.profile,
      fallbackName: this.handleText.length > 1 ? this.handleText.substring(1) : 'Harmony X',
      fallbackHandle: this.handleText.length > 0 ? this.handleText : '@harmonyx',
      onClose: (): void => { this.showSideDrawer = false; },
      onProfile: (): void => {
        this.showSideDrawer = false;
        this.goMe();
      },
      onSettings: (): void => this.openSettings(),
      onMenu: (feature: string): void => {
        if (feature === 'help') {
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
      if (this.supportsHdsFloatingMaterial()) {
        HdsTabs({ controller: this.hdsTabsController, index: this.currentTab }) {
          this.HdsTabContents()
        }
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.bg_page'))
        .barPosition(BarPosition.End)
        .barOverlap(true)
        .scrollable(true)
        .animationDuration(0)
        .attributeModifier(this.hdsTabsModifier)
        .onChange((index: number) => {
          this.currentTab = index;
        })
      } else {
        Tabs({ barPosition: BarPosition.End, index: this.currentTab, controller: this.tabsController }) {
          this.LegacyTabContents()
        }
        .width('100%')
        .height('100%')
        .barBackgroundColor($r('app.color.bg_page'))
        .onChange((index: number) => {
          this.currentTab = index;
        })
      }

    }
    .width('100%')
    .height('100%')
  }

  // Secondary pages are dispatched from the shared HdsNavigation stack,
  // matching PaperTalk's pageStack + HdsNavDestination structure.
  @Builder
  private NavigationBuilder(name: string): void {
    if (name === 'PostDetail') {
      PostDetailBuilder();
    } else if (name === 'ReplyComposer') {
      ReplyComposerBuilder();
    } else if (name === 'Settings') {
      SettingsBuilder();
    } else if (name === 'SettingsSection') {
      SettingsSectionBuilder();
    } else if (name === 'HelpCenter') {
      HelpCenterBuilder();
    } else if (name === 'UserDetail') {
      UserDetailBuilder();
    }
  }

  @Builder
  private HdsTabContents(): void {
    TabContent() {
      this.HomeTab()
    }
    .tabBar(this.HdsTabBar($r('sys.symbol.house_fill'), $r('app.string.home_title')))

    TabContent() {
      this.ExploreTab()
    }
    .tabBar(this.HdsTabBar($r('sys.symbol.magnifyingglass'), $r('app.string.explore_title')))

    TabContent() {
      this.NotificationsTab()
    }
    .tabBar(this.HdsTabBar($r('sys.symbol.bell_fill'), $r('app.string.tab_alerts')))

    TabContent() {
      this.MessagesTab()
    }
    .tabBar(this.HdsTabBar($r('sys.symbol.envelope'), $r('app.string.messages_title')))

    TabContent() {
      this.MeTab()
    }
    .tabBar(this.HdsTabBar($r('sys.symbol.person_fill'), $r('app.string.tab_me')))
  }

  @Builder
  private LegacyTabContents(): void {
    TabContent() {
      this.HomeTab()
    }
    .tabBar(this.TabBar(0, $r('sys.symbol.house'), $r('sys.symbol.house_fill'), this.text($r('app.string.home_title'))))

    TabContent() {
      this.ExploreTab()
    }
    .tabBar(this.TabBar(1, $r('sys.symbol.magnifyingglass'), $r('sys.symbol.magnifyingglass'), this.text($r('app.string.explore_title'))))

    TabContent() {
      this.NotificationsTab()
    }
    .tabBar(this.TabBar(2, $r('sys.symbol.bell'), $r('sys.symbol.bell_fill'), this.text($r('app.string.tab_alerts'))))

    TabContent() {
      this.MessagesTab()
    }
    .tabBar(this.TabBar(3, $r('sys.symbol.envelope'), $r('sys.symbol.envelope'), this.text($r('app.string.messages_title'))))

    TabContent() {
      this.MeTab()
    }
    .tabBar(this.TabBar(4, $r('sys.symbol.person'), $r('sys.symbol.person_fill'), this.text($r('app.string.tab_me'))))
  }

  private HdsTabBar(icon: Resource, label: Resource): BottomTabBarStyle {
    const normalGlyphModifier: SymbolGlyphModifier = new SymbolGlyphModifier(icon)
      .renderingStrategy(SymbolRenderingStrategy.SINGLE);
    normalGlyphModifier.fontColor([$r('sys.color.icon_primary')]);
    const selectedGlyphModifier: SymbolGlyphModifier = new SymbolGlyphModifier(icon)
      .renderingStrategy(SymbolRenderingStrategy.SINGLE);
    selectedGlyphModifier.fontColor([this.accentColor]);
    return BottomTabBarStyle.of({
      normal: normalGlyphModifier,
      selected: selectedGlyphModifier
    }, label)
      .labelStyle({
        unselectedColor: $r('sys.color.font_primary'),
        selectedColor: this.accentColor
      })
      .padding({ bottom: 0 });
  }

  // Fallback for systems without API 26 material support.
  @Builder
  private HomeTitle(): void {
    Row({ space: 8 }) {
      Text(this.avatarInitial())
        .width(34)
        .height(34)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_on_brand'))
        .backgroundColor(this.accentColor)
        .borderRadius(17)
        .textAlign(TextAlign.Center)
        .onClick(() => this.openSideDrawer())
      Blank()
      Text('𝕏')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Blank()
      Text(this.liveBadge.length > 0 ? '●' : '')
        .fontSize(10)
        .fontColor($r('app.color.repost'))
        .width(34)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: this.statusBarHeight + 8, bottom: 8 })
    .backgroundColor($r('app.color.bg_page'))
  }

  // The title bar owns the avatar and foreground mark so HdsNavigation can
  // blend it while the active page scrolls underneath.
  @Builder
  private ImmersiveTitleBarContent(): void {
    if (this.currentTab === 1) {
      Stack() {
        this.TitleBarIdentityRow()
        Row() {
          this.ExploreTitleBarSearch()
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .position({ x: 0, y: this.statusBarHeight + 42 })
      }
      .width('100%')
      .height('100%')
      .padding({ left: 12, right: 12 })
      .clip(false)
      .hitTestBehavior(HitTestMode.Transparent)
    } else if (this.currentTab === 0) {
      Stack() {
        this.TitleBarIdentityRow()
        Column() {
          this.HomeFeedSwitch()
        }
          .width('100%')
          .position({ x: 0, y: this.statusBarHeight + 42 })
      }
      .width('100%')
      .height('100%')
      .padding({ left: 12, right: 12 })
      .clip(false)
      .hitTestBehavior(HitTestMode.Transparent)
    } else {
      Stack() {
        this.TitleBarIdentityRow()
      }
      .width('100%')
      .height('100%')
      .padding({ left: 12, right: 12 })
      .hitTestBehavior(HitTestMode.Transparent)
    }
  }

  @Builder
  private HomeFeedSwitch(): void {
    Row({ space: 26 }) {
      Column({ space: 6 }) {
        Text($r('app.string.home_for_you'))
          .fontSize(16)
          .fontWeight(this.homeFeedMode === 0 ? FontWeight.Bold : FontWeight.Regular)
          .fontColor(this.homeFeedMode === 0 ? $r('app.color.text_primary') : $r('app.color.text_secondary'))
          .onClick((): void => this.changeHomeFeed(0))
        Divider()
          .width(58)
          .height(3)
          .color(this.homeFeedMode === 0 ? this.accentColor : Color.Transparent)
      }
      .alignItems(HorizontalAlign.Center)
      .accessibilityText(this.text($r('app.string.home_for_you')))

      Column({ space: 6 }) {
        Text($r('app.string.home_following'))
          .fontSize(16)
          .fontWeight(this.homeFeedMode === 1 ? FontWeight.Bold : FontWeight.Regular)
          .fontColor(this.homeFeedMode === 1 ? $r('app.color.text_primary') : $r('app.color.text_secondary'))
          .onClick((): void => this.changeHomeFeed(1))
        Divider()
          .width(58)
          .height(3)
          .color(this.homeFeedMode === 1 ? this.accentColor : Color.Transparent)
      }
      .alignItems(HorizontalAlign.Center)
      .accessibilityText(this.text($r('app.string.home_following')))
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private TitleBarIdentityRow(): void {
    Stack({ alignContent: Alignment.Center }) {
      Row() {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          if (this.profile !== null && this.profile.avatarUrl !== undefined && this.profile.avatarUrl.length > 0) {
            Image(this.profile.avatarUrl)
              .width(36)
              .height(36)
              .objectFit(ImageFit.Cover)
              .borderRadius(18)
              .clip(true)
          } else {
            Text(this.avatarInitial())
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_on_brand'))
          }
        }
        .width(36)
        .height(36)
        .padding(0)
        .backgroundColor(this.accentColor)
        .accessibilityText(this.text($r('app.string.tab_me')))
        .onClick((): void => this.openSideDrawer())
        Blank()
        Text(this.liveBadge.length > 0 ? '●' : '')
          .width(36)
          .fontSize(10)
          .fontColor($r('app.color.repost'))
          .textAlign(TextAlign.End)
      }
      .width('100%')

      Image($r('app.media.ui_brand_foreground'))
        .width(30)
        .height(30)
        .objectFit(ImageFit.Contain)
        .borderRadius(15)
        .clip(true)
    }
    .width('100%')
    .height(36)
  }

  private avatarInitial(): string {
    if (this.handleText.length > 1) {
      return this.handleText.substring(1, 2).toUpperCase();
    }
    return 'O';
  }

  @Builder
  private TabBar(index: number, icon: Resource, activeIcon: Resource, label: string): void {
    Column({ space: 2 }) {
      SymbolGlyph(this.currentTab === index ? activeIcon : icon)
        .fontSize(24)
        .fontColor([this.currentTab === index ? this.accentColor : $r('app.color.text_secondary')])
      Text(label)
        .fontSize(11)
        .fontColor(this.currentTab === index ? this.accentColor : $r('app.color.text_secondary'))
    }
    .justifyContent(FlexAlign.Center)
    .padding({ bottom: 10 })
  }

  @Builder
  private HomeTab(): void {
    Column() {
      if (this.loading && this.timeline.length === 0) {
        LoadingProgress()
          .width(32)
          .height(32)
          .color(this.accentColor)
          .margin({ top: this.contentTopInset() + 32 })
        Blank().layoutWeight(1)
      } else {
        Refresh({ refreshing: $$this.refreshing }) {
          List({ space: 0, scroller: this.homeScroller }) {
            ListItem() {
              Text(this.statusLine)
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
                .width('100%')
                .padding({ left: 16, right: 16, top: this.contentTopInset(), bottom: 8 })
            }
            ForEach(this.timeline, (t: Tweet) => {
              ListItem() {
                TweetCard({
                  tweet: t,
                  onLikeChanged: (tt: Tweet, liked: boolean) => this.onLike(tt, liked),
                  onRepostChanged: (tt: Tweet, reposted: boolean) => this.onRepost(tt, reposted),
                  onReply: (tt: Tweet) => this.onReply(tt),
                  onOpen: (tt: Tweet) => this.openPost(tt),
                  onAuthorTapped: (tt: Tweet) => this.openUser(tt)
                })
              }
            }, (t: Tweet) => t.id)
            ListItem() {
              if (this.loadingMore) {
                LoadingProgress()
                  .color(this.accentColor)
                  .margin({ top: 14, bottom: 14 })
              } else {
                Text(this.hasMoreTimeline ? $r('app.string.timeline_load_more') : $r('app.string.timeline_no_more'))
                  .fontSize(12)
                  .fontColor($r('app.color.text_secondary'))
                  .margin({ top: 16, bottom: 16 })
              }
            }
            .width('100%')
            .align(Alignment.Center)
          }
          .width('100%')
          .backgroundColor($r('app.color.bg_page'))
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
          .scrollBar(BarState.Auto)
          .cachedCount(8)
          .onScrollIndex((start: number): void => {
            if (start >= this.timeline.length - 8) {
              this.requestMoreTimeline();
            }
          })
          .onReachEnd((): void => {
            this.requestMoreTimeline();
          })
        }
        .width('100%')
        .layoutWeight(1)
        .onRefreshing(() => {
          this.onRefresh();
        })
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private ExploreTab(): void {
    List({ scroller: this.exploreScroller }) {
      ListItem() {
        if (this.supportsHdsNavigation()) {
          Column()
            .width('100%')
            .height(this.exploreContentTopInset())
        } else {
          this.LegacyExploreSearchBar()
        }
      }
      ListItem() {
        Text(this.exploreStatus)
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .width('92%')
          .padding({ top: 4, bottom: 8 })
      }
      ForEach(this.trends.filter((t: string) => {
          return this.searchText.trim().length === 0 ||
            t.toLowerCase().includes(this.searchText.trim().toLowerCase());
        }), (trend: string) => {
          ListItem() {
            Row({ space: 8 }) {
              SymbolGlyph($r('sys.symbol.magnifyingglass'))
                .fontSize(16)
                .fontColor([$r('app.color.text_secondary')])
              Text(trend)
                .fontSize(16)
                .fontColor($r('app.color.text_primary'))
                .layoutWeight(1)
            }
            .width('92%')
            .padding(12)
            .border({ width: { bottom: 1 }, color: $r('app.color.divider') })
            .visualEffect(new hdsEffect.HdsEffectBuilder()
              .pointLight({
                illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
              })
              .buildEffect())
          }
        }, (trend: string) => trend)
      ForEach(this.exploreResults, (tweet: Tweet) => {
        ListItem() {
          TweetCard({
            tweet: tweet,
            onLikeChanged: (t: Tweet, liked: boolean) => this.onLike(t, liked),
            onRepostChanged: (t: Tweet, reposted: boolean) => this.onRepost(t, reposted),
            onReply: (t: Tweet) => this.onReply(t),
            onOpen: (t: Tweet) => this.openPost(t),
            onAuthorTapped: (t: Tweet) => this.openUser(t)
          })
        }
      }, (tweet: Tweet) => tweet.id)
      if (this.exploreResults.length > 0) {
        ListItem() {
          if (this.loadingMoreExplore) {
            LoadingProgress()
              .color(this.accentColor)
              .margin({ top: 14, bottom: 14 })
          } else {
            Text(this.hasMoreExplore ? $r('app.string.explore_load_more') : $r('app.string.explore_no_more'))
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .margin({ top: 16, bottom: 16 })
          }
        }
        .width('100%')
        .align(Alignment.Center)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .scrollBar(BarState.Auto)
    .cachedCount(4)
    .onScrollIndex((start: number): void => {
      if (this.exploreResults.length > 0 &&
        start >= this.exploreResultStartIndex() + this.exploreResults.length - 2) {
        this.requestMoreExploreResults();
      }
    })
    .onReachEnd((): void => {
      this.requestMoreExploreResults();
    })
  }

  @Builder
  private ExploreTitleBarSearch(): void {
    if (this.supportsImmersiveMaterial()) {
      Stack() {
        Search({
          value: this.searchText,
          placeholder: $r('app.string.explore_title'),
          controller: this.searchController
        })
          .width('100%')
          .height(38)
          .backgroundColor(Color.Transparent)
          .fontColor($r('app.color.text_primary'))
          .onChange((v: string): void => {
            this.searchText = v;
          })
          .onSubmit((v: string): void => this.submitSearch(v))
      }
      .width('86%')
      .height(38)
      .borderRadius(20)
      .clip(true)
      .systemMaterial(new uiMaterial.ImmersiveMaterial({
        style: uiMaterial.ImmersiveStyle.THIN,
        colorInvert: true,
        applyShadow: true,
        lightEffect: { color: this.accentColor }
      }))
    } else {
      Search({
        value: this.searchText,
        placeholder: $r('app.string.explore_title'),
        controller: this.searchController
      })
        .width('86%')
        .height(38)
        .backgroundColor($r('app.color.bg_field'))
        .fontColor($r('app.color.text_primary'))
        .borderRadius(20)
        .onChange((v: string): void => {
          this.searchText = v;
        })
        .onSubmit((v: string): void => this.submitSearch(v))
    }
  }

  @Builder
  private LegacyExploreSearchBar(): void {
    Search({
      value: this.searchText,
      placeholder: $r('app.string.explore_title'),
      controller: this.searchController
    })
      .width('92%')
      .height(48)
      .margin({ top: this.contentTopInset(), bottom: 12 })
      .backgroundColor($r('app.color.bg_field'))
      .fontColor($r('app.color.text_primary'))
      .borderRadius(24)
      .onChange((v: string): void => {
        this.searchText = v;
      })
      .onSubmit((v: string): void => this.submitSearch(v))
  }

  private submitSearch(value: string): void {
    const query: string = value.trim();
    this.searchText = query;
    this.activeExploreQuery = query;
    this.exploreNextToken = '';
    this.hasMoreExplore = false;
    this.loadingMoreExplore = false;
    if (!authStore.isSignedIn()) {
      this.needsAuth(this.text($r('app.string.action_search_live')));
      return;
    }
    if (query.length === 0) {
      this.exploreResults = [];
      return;
    }
    this.api.searchRecentPage(query).then((page: TweetPage | null): void => {
      if (page !== null && page.tweets.length > 0) {
        this.exploreResults = page.tweets;
        this.exploreNextToken = page.nextToken;
        this.hasMoreExplore = page.nextToken.length > 0;
        this.exploreStatus = page.tweets.length + this.text($r('app.string.toast_results_suffix'));
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
  private NotificationsTab(): void {
    List({ scroller: this.notificationsScroller }) {
      ListItem() {
        Column()
          .width('100%')
          .height(this.contentTopInset())
      }
      ListItem() {
        Text(this.notificationsStatus)
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .width('92%')
          .padding({ top: 4, bottom: 8 })
      }
      ForEach(this.notifications, (n: AppNotification) => {
        ListItem() {
          Row({ space: 12 }) {
            if (n.kind === '♥') {
              SymbolGlyph($r('sys.symbol.heart_fill'))
                .fontSize(22)
                .fontColor([$r('app.color.like')])
            } else if (n.kind === '↻') {
              SymbolGlyph($r('sys.symbol.repeat'))
                .fontSize(22)
                .fontColor([$r('app.color.repost')])
            } else {
              SymbolGlyph($r('sys.symbol.person_fill'))
                .fontSize(22)
                .fontColor([this.accentColor])
            }
            Column({ space: 2 }) {
              Text(n.text).fontSize(15).fontColor($r('app.color.text_primary'))
              Text(n.time).fontSize(12).fontColor($r('app.color.text_secondary'))
            }
            .alignItems(HorizontalAlign.Start)
          }
          .width('92%')
          .padding(12)
          .border({ width: { bottom: 1 }, color: $r('app.color.divider') })
          .visualEffect(new hdsEffect.HdsEffectBuilder()
            .pointLight({
              illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
            })
            .buildEffect())
        }
      }, (n: AppNotification) => n.id)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .scrollBar(BarState.Auto)
  }

  @Builder
  private MessagesTab(): void {
    List({ scroller: this.messagesScroller }) {
      ListItem() {
        Column()
          .width('100%')
          .height(this.contentTopInset())
      }
      ListItem() {
        Text(this.messagesStatus)
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .width('92%')
          .padding({ top: 4, bottom: 8 })
      }
      ForEach(this.messages, (m: DirectMessage) => {
        ListItem() {
          Row({ space: 12 }) {
            if (m.avatarUrl !== undefined && m.avatarUrl.length > 0) {
              Image(m.avatarUrl)
                .width(44)
                .height(44)
                .objectFit(ImageFit.Cover)
                .borderRadius(22)
                .clip(true)
            } else {
              Text(m.from.substring(0, 1).toUpperCase())
                .width(44)
                .height(44)
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_on_brand'))
                .backgroundColor($r('app.color.text_secondary'))
                .borderRadius(22)
                .textAlign(TextAlign.Center)
            }
            Column({ space: 2 }) {
              Row() {
                Text(m.from).fontSize(15).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
                Blank()
                Text(m.time).fontSize(12).fontColor($r('app.color.text_secondary'))
              }
              .width('100%')
              Text(m.preview).fontSize(14).fontColor($r('app.color.text_secondary'))
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            if (m.unread > 0) {
              Text(m.unread.toString())
                .fontSize(12)
                .fontColor($r('app.color.text_on_brand'))
                .backgroundColor(this.accentColor)
                .borderRadius(10)
                .padding({ left: 8, right: 8, top: 2, bottom: 2 })
            }
          }
          .width('92%')
          .padding(12)
          .border({ width: { bottom: 1 }, color: $r('app.color.divider') })
          .visualEffect(new hdsEffect.HdsEffectBuilder()
            .pointLight({
              illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
            })
            .buildEffect())
        }
      }, (m: DirectMessage) => m.id)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .scrollBar(BarState.Auto)
  }

  @Builder
  private MeTab(): void {
    Scroll(this.profileScroller) {
      Column({ space: 12 }) {
        // The resource-qualified artwork switches with the app's color mode.
        Stack({ alignContent: Alignment.TopStart }) {
          Image($r('app.media.account_card_background'))
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Cover)

          Column({ space: 6 }) {
            if (this.profile !== null && this.profile.avatarUrl !== undefined && this.profile.avatarUrl.length > 0) {
              Image(this.profile.avatarUrl)
                .width(64)
                .height(64)
                .objectFit(ImageFit.Cover)
                .borderRadius(32)
                .clip(true)
            } else {
              Text(this.avatarInitial())
                .width(64)
                .height(64)
                .fontSize(28)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_on_brand'))
                .backgroundColor(this.accentColor)
                .borderRadius(32)
                .textAlign(TextAlign.Center)
            }
            Text(this.profile !== null && this.profile.name.length > 0 ? this.profile.name :
              (this.handleText.length > 0 ? this.handleText : $r('app.string.profile_welcome')))
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
            Row({ space: 4 }) {
              if (authStore.isSignedIn()) {
                SymbolGlyph($r('sys.symbol.checkmark'))
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor([$r('app.color.repost')])
              }
              Text(authStore.isSignedIn() ? $r('app.string.profile_signed_in') : $r('app.string.profile_browse_free'))
                .fontSize(13)
                .fontColor(authStore.isSignedIn() ? $r('app.color.repost') : $r('app.color.text_secondary'))
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
            Text(this.profile.description)
              .width('92%')
              .fontSize(14)
              .fontColor($r('app.color.text_primary'))
          }
          Row({ space: 16 }) {
            Text(formatCount(this.profile.followingCount) + ' ' + this.text($r('app.string.profile_following')))
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
            Text(formatCount(this.profile.followersCount) + ' ' + this.text($r('app.string.profile_followers')))
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
            Text(formatCount(this.profile.postCount) + ' ' + this.text($r('app.string.profile_posts')))
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
          }
          .width('92%')
        }

        if (authStore.isSignedIn()) {
          Button($r('app.string.profile_sign_out'), { stateEffect: true })
            .width('92%')
            .backgroundColor($r('app.color.bg_secondary_btn'))
            .fontColor($r('app.color.danger'))
            .onClick(() => this.signOut())
        } else {
          Button($r('app.string.profile_sign_in'), { stateEffect: true })
            .width('92%')
            .backgroundColor(this.accentColor)
            .fontColor($r('app.color.text_on_brand'))
            .onClick(() => this.goLogin())
        }

        Text($r('app.string.profile_version'))
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 8 })
      }
      .width('100%')
      .padding({ top: this.contentTopInset(), bottom: this.navigationIndicatorHeight + 96 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .scrollBar(BarState.Auto)
  }
}
