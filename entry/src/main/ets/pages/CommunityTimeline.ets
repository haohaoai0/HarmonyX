// Community profile, media and about tabs backed by X community operations.
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import common from '@ohos.app.ability.common';
import promptAction from '@ohos.promptAction';
import { deviceInfo } from '@kit.BasicServicesKit';
import { uiMaterial } from '@kit.ArkUI';
import { HdsNavDestination, HdsNavDestinationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { ProxyAvatar } from '../components/ProxyAvatar';
import { HdsButton } from '../components/HdsButton';
import { CommunityProfileTabs } from '../components/CommunityProfileTabs';
import { ProfileTabMotion } from '../utils/ProfileTabMotion';
import { SystemMaterialUtil } from '../utils/SystemMaterial';
import { FloatingComposeButton } from '../components/FloatingComposeButton';
import { shareCommunity } from '../utils/SharePost';
import { pasteboard } from '@kit.BasicServicesKit';
import { sheetMaterialOptions } from '../utils/SheetMaterial';
import { DEFAULT_SHEET_MATERIAL_LEVEL, STORAGE_KEY_SHEET_MATERIAL_ENABLED, STORAGE_KEY_SHEET_MATERIAL_LEVEL } from '../services/SheetMaterialSettingsStore';
import type { ProfileWebRouteParam } from './ProfileWeb';
import type { UserDetailRouteParam } from './UserDetail';
import { ProxyMediaImage } from '../components/ProxyMediaImage';
import { ConversationTweetCard as TweetCard } from '../components/ConversationTweetCard';
import type { ReplyComposerRouteParam } from '../components/ReplyComposer';
import type { CommunityPage, CommunityRow, CommunityRule } from '../models/Community';
import { formatCount } from '../models/Tweet';
import type { Tweet, TweetAuthor } from '../models/Tweet';
import type { TweetPage } from '../services/XApiClient';
import { communityFavoritesStore } from '../services/CommunityFavoritesStore';
import { XPrivateClient, XPrivateResult, xPrivateClient } from '../services/XPrivateClient';
import { XTimelineParser } from '../services/XTimelineParser';
import { XCommunityParser } from '../services/XCommunityParser';
import { XUserParser } from '../services/XUserParser';
import { destinationTitleBarStyle } from '../utils/DestinationTitleBar';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';
import { fieldSurfaceColor, pageSurfaceColor } from '../utils/ThemeColors';
import type { CommunityRulesRouteParam, CommunityTimelineRouteParam } from './Communities';
import type { PostDetailRouteParam } from './PostDetail';

const PAGE_SIZE = 20;

@Builder
export function CommunityTimelineBuilder(): void {
  CommunityTimeline();
}

@Component
export struct CommunityTimeline {
  @StorageProp('harmonyx.compact_window') private sheetCompactWindow: boolean = false;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp('harmonyx.breakpoint') private sheetWindowBreakpoint: string = 'sm';
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp('harmonyx.status_bar_height') statusBarHeight: number =
    AppStorage.get<number>('harmonyx.status_bar_height') ?? 0;
  @StorageProp('harmonyx.navigation_indicator_height') navigationIndicatorHeight: number =
    AppStorage.get<number>('harmonyx.navigation_indicator_height') ?? 0;
  @StorageLink('harmonyx.accent_color') accentColor: string = '#007DFF';
  @StorageProp('harmonyx.display_mode') private themeDisplayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private themeDarkSurface: string = '';
  @StorageLink('harmonyx.title_bar_style_mode') titleBarStyleMode: number = 0;
  @StorageLink('harmonyx.posts_changed') @Watch('onPostsChanged') postsChanged: number = 0;
  @StorageLink('harmonyx.community_membership_changed')
  @Watch('onMembershipChanged') membershipChanged: number = 0;
  @StorageProp(STORAGE_KEY_SHEET_MATERIAL_ENABLED) sheetMaterialEnabled: boolean = false;
  @StorageProp(STORAGE_KEY_SHEET_MATERIAL_LEVEL) sheetMaterialLevel: number = DEFAULT_SHEET_MATERIAL_LEVEL;
  @State private selectedTab: number = 0;
  @State private tabPosition: number = 0;
  @State private viewportHeight: number = 700;
  @State private timelinePosts: Tweet[] = [];
  @State private mediaPosts: Tweet[] = [];
  @State private myPosts: Tweet[] = [];
  @State private myReplies: Tweet[] = [];
  @State private searchPosts: Tweet[] = [];
  private activitySwiper: SwiperController = new SwiperController();
  private activityScrollers: Scroller[] = [new Scroller(), new Scroller(), new Scroller()];
  @State private sortMode: string = 'Relevance';
  @State private viewMode: number = 0;
  @State private actionSheetOpen: boolean = false;
  @State private actionSheetMode: number = 0;
  @State private moreMenuOpen: boolean = false;
  @State private descriptionExpanded: boolean = false;
  @State private scrollOffset: number = 0;
  @State private communityTopic: string = '';
  @State private communityMembers: TweetAuthor[] = [];
  @State private communityModerators: TweetAuthor[] = [];
  @State private communityCreator: TweetAuthor | undefined = undefined;
  @State private communityCreatedAt: string = '';
  @State private communityJoinQuestion: string = '';
  @State private posts: Tweet[] = [];
  @State private status: string = '';
  @State private requestFailed: boolean = false;
  @State private loading: boolean = true;
  @State private loadingMore: boolean = false;
  @State private refreshing: boolean = false;
  @State private mediaOnly: boolean = false;
  @State private hashtagSearchOpen: boolean = false;
  @State private hashtagInput: string = '';
  @State private hashtagQuery: string = '';
  @State private hashtagRecentFirst: boolean = false;
  @State private title: string = '';
  @State private communityDescription: string = '';
  @State private communityMemberCount: number = 0;
  @State private communityModeratorCount: number = 0;
  @State private communityBannerUrl: string = '';
  @State private communityRuleCount: number = 0;
  @State private communityRules: CommunityRule[] = [];
  @State private communityJoined: boolean = false;
  @State private communityJoinPolicy: string = '';
  @State private membershipBusy: boolean = false;
  @State private joinRequestPending: boolean = false;
  @State private membershipFailed: boolean = false;
  @State private membershipStatus: string = '';
  @State private favorite: boolean = false;
  private communityId: string = '';
  private nextToken: string = '';
  private timelineCursor: string = '';
  private mediaCursor: string = '';
  private myPostsCursor: string = '';
  private myRepliesCursor: string = '';
  private timelineLoaded: boolean = false;
  private mediaLoaded: boolean = false;
  private myPostsLoaded: boolean = false;
  private myRepliesLoaded: boolean = false;
  private requestVersion: number = 0;
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    setTimeout((): void => {
      this.readRoute();
      this.load(true);
      this.loadCommunityInfo();
    }, 30);
  }

  private readRoute(): void {
    const params: CommunityTimelineRouteParam[] =
      this.pageStack.getParamByName('CommunityTimeline') as CommunityTimelineRouteParam[];
    if (params === undefined || params === null || params.length === 0) {
      return;
    }
    const param: CommunityTimelineRouteParam = params[params.length - 1];
    this.communityId = param.communityId;
    this.title = param.title;
    this.communityDescription = param.description;
    this.communityMemberCount = param.memberCount;
    this.communityModeratorCount = param.moderatorCount;
    this.communityBannerUrl = param.bannerUrl;
    this.communityJoinPolicy = param.joinPolicy;
    this.communityRuleCount = param.ruleCount;
    this.communityRules = param.rules;
    this.communityJoined = param.joined;
    if (param.community !== undefined) { this.applyCommunityMetadata(param.community); }
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    this.favorite = communityFavoritesStore.contains(context, this.communityId);
  }

  private text(resource: Resource): string {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    return context.resourceManager.getStringSync(resource);
  }

  private static failureDetail(result: XPrivateResult): string {
    return '\n' + XPrivateClient.explain(result).substring(0, 200);
  }

  private onPostsChanged(): void {
    if (this.communityId.length > 0 && this.communityJoined) {
      this.myPostsLoaded = false; this.myRepliesLoaded = false;
      this.load(true);
    }
  }

  private onMembershipChanged(): void {
    if (this.communityId.length > 0) {
      this.loadCommunityInfo();
    }
  }

  private async loadCommunityInfo(): Promise<void> {
    if (this.communityId.length === 0) {
      return;
    }
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    xPrivateClient.load(context);
    if (!xPrivateClient.isSignedIn()) {
      return;
    }
    const result: XPrivateResult = await xPrivateClient.communityInfo(this.communityId);
    if (!result.ok) {
      return;
    }
    const page: CommunityPage | null = XCommunityParser.parse(result.body);
    if (page === null) {
      return;
    }
    for (let i: number = 0; i < page.communities.length; i++) {
      const row: CommunityRow = page.communities[i];
      if (row.id !== this.communityId) {
        continue;
      }
      this.applyCommunityMetadata(row);
      this.title = row.name;
      this.communityDescription = row.description;
      this.communityMemberCount = row.memberCount;
      this.communityModeratorCount = row.moderatorCount;
      this.communityBannerUrl = row.bannerUrl;
      this.communityJoinPolicy = row.joinPolicy;
      this.communityRuleCount = row.ruleCount;
      this.communityRules = row.rules;
      this.communityJoined = row.joined;
      if (row.joined) {
        this.joinRequestPending = false;
      }
      communityFavoritesStore.update(context, this.currentCommunityRow());
      return;
    }
  }

  private pageMaterial(): uiMaterial.Material | undefined {
    if (!deviceInfo.apiAvailable('26.0.0')) {
      return undefined;
    }
    return new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.REGULAR,
      applyShadow: true,
      colorInvert: true
    });
  }

  private async load(reset: boolean): Promise<void> {
    if (this.communityId.length === 0) {
      this.loading = false;
      return;
    }
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    xPrivateClient.load(context);
    if (!xPrivateClient.isSignedIn()) {
      this.status = this.text($r('app.string.user_list_sign_in'));
      this.requestFailed = true;
      this.loading = false;
      return;
    }
    let requestVersion: number = this.requestVersion;
    const requestedMediaOnly: boolean = this.mediaOnly;
    const requestedViewMode: number = this.viewMode;
    const requestedSort: string = this.sortMode;
    const requestedHashtag: string = this.hashtagQuery;
    const requestedRecentFirst: boolean = this.hashtagRecentFirst;
    if (reset) {
      this.requestVersion += 1;
      requestVersion = this.requestVersion;
      this.loading = true;
      this.status = '';
      this.requestFailed = false;
      this.loadingMore = false;
      this.nextToken = '';
    } else {
      if (this.loading || this.loadingMore || this.status.length > 0 || this.nextToken.length === 0) {
        return;
      }
      this.loadingMore = true;
    }
    const cursor: string = reset ? '' : this.nextToken;
    const result: XPrivateResult = requestedHashtag.length > 0 ?
      await xPrivateClient.communityHashtagSearch(this.communityId, requestedHashtag, cursor, PAGE_SIZE,
        requestedRecentFirst) : requestedMediaOnly ?
        await xPrivateClient.communityMediaTimeline(this.communityId, cursor, PAGE_SIZE) : requestedViewMode > 0 ?
        await xPrivateClient.communityUserTimeline(this.communityId, cursor, PAGE_SIZE, requestedViewMode === 2) :
        await xPrivateClient.communityTimeline(this.communityId, cursor, PAGE_SIZE, requestedSort);
    if (requestVersion !== this.requestVersion || requestedMediaOnly !== this.mediaOnly ||
      requestedHashtag !== this.hashtagQuery || requestedRecentFirst !== this.hashtagRecentFirst || requestedSort !== this.sortMode ||
      requestedViewMode !== this.viewMode) {
      return;
    }
    if (!result.ok) {
      this.requestFailed = true;
      this.status = result.status === 429 ?
        this.text($r('app.string.community_rate_limited')).replace('%s',
          new Date(result.retryAt || Date.now() + 60000).toLocaleTimeString()) :
        result.status === 401 || result.status === 403 ?
        this.text($r('app.string.private_session_expired')) :
        this.text($r('app.string.communities_failed')) + ' HTTP ' + result.status +
        CommunityTimeline.failureDetail(result);
      this.loading = false;
      this.loadingMore = false;
      return;
    }
    const page: TweetPage | null = XTimelineParser.parse(result.body);
    if (page === null) {
      this.requestFailed = true;
      this.status = this.text($r('app.string.communities_failed'));
      this.loading = false;
      this.loadingMore = false;
      return;
    }
    for (let i: number = 0; i < page.tweets.length; i++) {
      page.tweets[i].communityId = this.communityId;
      page.tweets[i].communityName = this.title;
    }
    if (reset) {
      this.posts = page.tweets;
    } else {
      const combined: Tweet[] = [];
      for (let i: number = 0; i < this.posts.length; i++) {
        combined.push(this.posts[i]);
      }
      for (let i: number = 0; i < page.tweets.length; i++) {
        if (!combined.some((post: Tweet): boolean => post.id === page.tweets[i].id)) { combined.push(page.tweets[i]); }
      }
      this.posts = combined;
    }
    this.nextToken = page.tweets.length > 0 && page.nextToken !== cursor ? page.nextToken : '';
    if (requestedHashtag.length > 0) { this.searchPosts = this.posts; }
    else if (requestedMediaOnly) { this.mediaPosts = this.posts; this.mediaLoaded = true; this.mediaCursor = this.nextToken; }
    else if (requestedViewMode === 1) { this.myPosts = this.posts; this.myPostsLoaded = true; this.myPostsCursor = this.nextToken; }
    else if (requestedViewMode === 2) { this.myReplies = this.posts; this.myRepliesLoaded = true; this.myRepliesCursor = this.nextToken; }
    else { this.timelinePosts = this.posts; this.timelineLoaded = true; this.timelineCursor = this.nextToken; }
    this.status = '';
    this.requestFailed = false;
    this.loading = false;
    this.loadingMore = false;
  }

  private selectTimeline(mediaOnly: boolean): void {
    if (this.mediaOnly === mediaOnly && this.hashtagQuery.length === 0 && !this.hashtagSearchOpen) {
      return;
    }
    this.mediaOnly = mediaOnly;
    this.requestVersion++;
    this.hashtagSearchOpen = false;
    this.hashtagQuery = '';
    this.status = '';
    this.loading = false; this.loadingMore = false;
    if (!this.restoreTimelineView()) { this.load(true); }
  }

  private restoreTimelineView(): boolean {
    this.requestFailed = false;
    if (this.mediaOnly) { this.posts = this.mediaPosts; this.nextToken = this.mediaCursor; return this.mediaLoaded; }
    if (this.viewMode === 1) { this.posts = this.myPosts; this.nextToken = this.myPostsCursor; return this.myPostsLoaded; }
    if (this.viewMode === 2) { this.posts = this.myReplies; this.nextToken = this.myRepliesCursor; return this.myRepliesLoaded; }
    this.posts = this.timelinePosts; this.nextToken = this.timelineCursor; return this.timelineLoaded;
  }

  private openHashtagSearch(): void {
    if (this.hashtagSearchOpen) {
      return;
    }
    this.mediaOnly = false;
    this.hashtagSearchOpen = true;
  }

  private submitHashtag(value: string): void {
    let hashtag: string = value.trim();
    if (hashtag.startsWith('#')) {
      hashtag = hashtag.substring(1);
    }
    if (hashtag.length === 0) {
      return;
    }
    this.hashtagInput = hashtag;
    this.hashtagQuery = hashtag;
    this.searchPosts = [];
    this.mediaOnly = false;
    this.hashtagSearchOpen = true;
    this.posts = [];
    this.status = '';
    this.nextToken = '';
    this.load(true);
  }

  private selectHashtagOrder(recentFirst: boolean): void {
    if (this.hashtagRecentFirst === recentFirst) {
      return;
    }
    this.hashtagRecentFirst = recentFirst;
    if (this.hashtagQuery.length > 0) {
      this.load(true);
    }
  }

  private openPost(tweet: Tweet): void {
    const param: PostDetailRouteParam = { tweet: tweet };
    this.pageStack.pushPath({ name: 'PostDetail', param: param });
  }

  private openComposer(initialText: string = '', share: boolean = false): void {
    const param: ReplyComposerRouteParam = {
      replyToId: '',
      replyToUser: '',
      avatarUrl: '',
      avatarName: '',
      avatarColor: this.accentColor,
      initialText: initialText,
      imageUri: '',
      gifUri: '',
      communityId: share ? '' : this.communityId,
      communityName: share ? '' : this.title,
      parentTweet: null
    };
    this.pageStack.pushPath({ name: 'ReplyComposer', param: param });
  }

  private openRules(join: boolean = false): void {
    const param: CommunityRulesRouteParam = {
      title: this.title,
      rules: this.communityRules,
      communityId: join ? this.communityId : '', joinPolicy: this.communityJoinPolicy, joinQuestion: this.communityJoinQuestion
    };
    this.pageStack.pushPath({ name: 'CommunityRules', param: param });
  }

  private toggleFavorite(): void {
    if (this.communityId.length === 0) {
      return;
    }
    const row: CommunityRow = this.currentCommunityRow();
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    this.favorite = communityFavoritesStore.toggle(context, row);
  }

  private currentCommunityRow(): CommunityRow {
    return {
      id: this.communityId,
      name: this.title,
      description: this.communityDescription,
      memberCount: this.communityMemberCount,
      moderatorCount: this.communityModeratorCount,
      bannerUrl: this.communityBannerUrl,
      joinPolicy: this.communityJoinPolicy,
      ruleCount: this.communityRuleCount,
      rules: this.communityRules,
      joined: this.communityJoined, topicName: this.communityTopic, members: this.communityMembers,
      moderators: this.communityModerators, creator: this.communityCreator, createdAt: this.communityCreatedAt, joinQuestion: this.communityJoinQuestion
    };
  }

  private needsJoinRequest(): boolean {
    const policy: string = this.communityJoinPolicy.toLowerCase();
    return policy.indexOf('restricted') >= 0 || policy.indexOf('approval') >= 0;
  }

  private async changeMembership(): Promise<void> {
    if (this.membershipBusy || this.communityId.length === 0) { return; }
    if (!this.communityJoined) { this.openRules(true); return; }
    const dialog: promptAction.ShowDialogSuccessResponse = await promptAction.showDialog({
      title: this.text($r('app.string.community_leave_title')),
      message: this.text($r('app.string.community_leave_confirm')),
      buttons: [{ text: this.text($r('app.string.compose_cancel')), color: '#666666' },
        { text: this.text($r('app.string.community_leave_action')), color: '#E0245E' }]
    });
    if (dialog.index !== 1) { return; }
    this.membershipBusy = true;
    const result: XPrivateResult = await xPrivateClient.leaveCommunity(this.communityId);
    this.membershipBusy = false;
    if (!result.ok) { this.membershipStatus = XPrivateClient.explain(result); this.membershipFailed = true; return; }
    this.communityJoined = false;
    this.communityMemberCount = Math.max(0, this.communityMemberCount - 1);
    communityFavoritesStore.update(getContext(this) as common.UIAbilityContext, this.currentCommunityRow());
    AppStorage.setOrCreate<number>('harmonyx.community_membership_changed',
      (AppStorage.get<number>('harmonyx.community_membership_changed') ?? 0) + 1);
  }

  private applyCommunityMetadata(row: CommunityRow): void {
    this.communityTopic = row.topicName ?? '';
    this.communityMembers = row.members ?? [];
    this.communityModerators = row.moderators ?? [];
    this.communityCreator = row.creator;
    this.communityCreatedAt = row.createdAt ?? '';
    this.communityJoinQuestion = row.joinQuestion ?? '';
  }
  private titleCollapsed(): boolean { return this.scrollOffset > 110; }
  private sortLabel(): Resource {
    return this.sortMode === 'Recency' ? $r('app.string.community_sort_new') :
      this.sortMode === 'Likes' ? $r('app.string.community_sort_top') : $r('app.string.community_sort_trending');
  }
  private selectTab(index: number): void {
    if (this.selectedTab !== index) { this.activitySwiper.changeIndex(index, true); }
  }
  private activityChanged(index: number): void {
    if (this.selectedTab === index) { return; }
    this.selectedTab = index;
    if (index < 2) { this.selectTimeline(index === 1); }
  }
  private selectSort(mode: string): void {
    this.actionSheetOpen = false;
    if (this.sortMode === mode && this.viewMode === 0) { return; }
    this.sortMode = mode; this.viewMode = 0; this.selectedTab = 0; this.tabPosition = 0; this.activitySwiper.changeIndex(0, true); this.mediaOnly = false;
    this.hashtagSearchOpen = false; this.hashtagQuery = ''; this.status = '';
    this.timelinePosts = []; this.timelineLoaded = false; this.posts = []; this.load(true);
  }
  private visiblePosts(tab: number = this.selectedTab): Tweet[] {
    if (tab === 1) { return this.mediaPosts; }
    if (this.hashtagQuery.length > 0) { return this.searchPosts; }
    return this.viewMode === 1 ? this.myPosts : this.viewMode === 2 ? this.myReplies : this.timelinePosts;
  }
  private emptyLabel(tab: number): Resource {
    if (tab === 1) { return $r('app.string.community_timeline_empty'); }
    if (this.hashtagQuery.length > 0) { return $r('app.string.community_hashtag_empty'); }
    if (this.viewMode === 1) { return $r('app.string.community_my_posts_empty'); }
    if (this.viewMode === 2) { return $r('app.string.community_my_replies_empty'); }
    return $r('app.string.community_timeline_empty');
  }
  private creationLabel(): string {
    if (this.communityCreatedAt.length === 0) { return ''; }
    const raw: number = Number(this.communityCreatedAt);
    const date: Date = isNaN(raw) ? new Date(this.communityCreatedAt) : new Date(raw < 100000000000 ? raw * 1000 : raw);
    return isNaN(date.getTime()) ? '' : date.toLocaleDateString();
  }
  private openUser(author: TweetAuthor): void {
    const param: UserDetailRouteParam = { author: author, posts: [] };
    this.pageStack.pushPath({ name: 'UserDetail', param: param });
  }
  private async reaction(post: Tweet, like: boolean, value: boolean): Promise<boolean> {
    const result: XPrivateResult = like ? await xPrivateClient.like(post.id, value) : await xPrivateClient.repost(post.id, value);
    if (!result.ok) { promptAction.showToast({ message: XPrivateClient.explain(result).substring(0, 160) }); }
    return result.ok;
  }
  private bookmark(post: Tweet, value: boolean): void {
    xPrivateClient.bookmark(post.id, value).then((result: XPrivateResult): void => {
      if (result.ok) { post.bookmarked = value; }
      else { promptAction.showToast({ message: XPrivateClient.explain(result).substring(0, 160) }); }
    });
  }
  private openSheet(mode: number): void { this.actionSheetMode = mode; this.actionSheetOpen = true; }
  private chooseMyView(mode: number): void {
    this.actionSheetOpen = false;
    if (this.viewMode === mode && this.selectedTab === 0 && this.hashtagQuery.length === 0) { return; }
    this.viewMode = mode; this.selectedTab = 0; this.tabPosition = 0; this.activitySwiper.changeIndex(0, true);
    this.mediaOnly = false; this.hashtagSearchOpen = false; this.hashtagQuery = '';
    this.requestVersion++; this.status = ''; this.loading = false; this.loadingMore = false;
    if (!this.restoreTimelineView()) { this.load(true); }
  }
  private url(): string { return 'https://x.com/i/communities/' + encodeURIComponent(this.communityId); }
  private copyLink(): void {
    pasteboard.getSystemPasteboard().setData(pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.url()));
    this.actionSheetOpen = false;
    promptAction.showToast({ message: this.text($r('app.string.community_link_copied')) });
  }
  private share(): void {
    this.actionSheetOpen = false;
    shareCommunity(getContext(this) as common.UIAbilityContext, this.communityId, this.title, this.communityDescription);
  }
  private report(): void {
    const param: ProfileWebRouteParam = { url: this.url(), title: this.text($r('app.string.community_report_on_x')) };
    this.pageStack.pushPath({ name: 'ProfileWeb', param: param });
  }

  @Builder
  private IconButton(symbol: Resource, label: Resource, action: () => void): void {
    Stack() {
      HdsButton({ barWidth: 40, barHeight: 52, lightColor: this.accentColor,
        useImmersiveMaterial: true, materialLevel: 2, forceHdsStyle: true,
        enableShadow: true, enablePressLight: true, onButtonClick: action }) {
        SymbolGlyph(symbol).fontSize(23).fontColor([$r('app.color.text_primary')])
      }
    }.width(40).height(40).accessibilityText(this.text(label))
  }
  @Builder
  private NavigationButtons(): void {
    Row({ space: 8 }) {
      this.IconButton($r('sys.symbol.arrow_left'), $r('app.string.common_back'),
        (): void => { ResponsiveLayout.closeContentDestination(this.pageStack); })
      Text(this.title).fontFamily(this.appFontFamily).fontSize($r('sys.float.Subtitle_L')).fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary')).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1).opacity(this.titleCollapsed() ? 1 : 0)
      this.IconButton($r('sys.symbol.magnifyingglass'), $r('app.string.community_search_posts'),
        (): void => { this.selectTab(0); this.openHashtagSearch(); })
      Stack() {
        HdsButton({ barWidth: 40, barHeight: 52, lightColor: this.accentColor,
          useImmersiveMaterial: true, materialLevel: 2, forceHdsStyle: true,
          enableShadow: true, enablePressLight: true,
          onButtonClick: (): void => { this.moreMenuOpen = true; } }) {
          SymbolGlyph($r('sys.symbol.ellipsis_circle')).fontSize(25).fontColor([$r('app.color.text_primary')])
        }
      }.width(40).height(40).accessibilityText(this.text($r('app.string.common_more')))
        .bindMenu(this.moreMenuOpen, this.moreMenuItems(), {
          onDisappear: (): void => { this.moreMenuOpen = false; }
        })
    }.width('100%').height(60).padding({ left: 8, right: 8 })
  }
  @Builder
  private TopNavigation(): void {
    Stack({ alignContent: Alignment.Bottom }) {
      if (SystemMaterialUtil.isApi26OrAbove()) {
        Navigation() { Column().width('100%').height('100%').hitTestBehavior(HitTestMode.None) }
          .title({ builder: (): void => { this.NavigationButtons(); }, height: 60 }, { barStyle: BarStyle.STACK })
          .titleMode(NavigationTitleMode.Full).mode(NavigationMode.Stack).hideToolBar(true)
          .backgroundColor(Color.Transparent).width('100%').height(60)
      } else { this.NavigationButtons() }
    }.width('100%').height(this.statusBarHeight + 60)
  }
  private moreMenuItems(): MenuElement[] {
    const items: MenuElement[] = [
      { value: this.text($r('app.string.community_report_on_x')), action: (): void => {
        this.moreMenuOpen = false; this.report();
      } },
      { value: this.text($r('app.string.community_about_tab')), action: (): void => {
        this.moreMenuOpen = false; this.selectTab(2);
      } }
    ];
    if (this.communityJoined) {
      items.push({ value: this.text($r('app.string.community_leave_action')), action: (): void => {
        this.moreMenuOpen = false; this.changeMembership();
      } });
    }
    return items;
  }
  @Builder
  private ProfileBanner(): void {
    Stack() {
      if (this.communityBannerUrl.length > 0) {
        ProxyMediaImage({ url: this.communityBannerUrl, displayHeight: this.statusBarHeight + 168,
          blurRadius: Math.min(18, this.scrollOffset / 8) })
      } else {
        Column().width('100%').height('100%').backgroundColor(this.accentColor)
        SymbolGlyph($r('sys.symbol.person_2_fill')).fontSize(64).fontColor([Color.White])
      }
    }.width('100%').height(this.statusBarHeight + 168).clip(true).hitTestBehavior(HitTestMode.None)
  }
  @Builder
  private RoundAction(symbol: Resource, label: Resource, action: () => void): void {
    Button({ type: ButtonType.Circle }) {
      SymbolGlyph(symbol).fontSize(21).fontColor([$r('app.color.text_primary')])
    }.width(36).height(36).backgroundColor(Color.Transparent)
      .border({ width: 1, color: $r('app.color.divider') }).accessibilityText(this.text(label)).onClick(action)
  }
  @Builder
  private CommunityOverview(): void {
    Column({ space: 0 }) {
      Column().height(112).width('100%')
      Column({ space: 12 }) {
        Text(this.title).fontFamily(this.appFontFamily).fontSize($r('sys.float.Title_L')).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary')).width('100%')
        if (this.communityTopic.length > 0) {
          Text(this.communityTopic).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S')).fontColor($r('app.color.text_primary'))
            .border({ width: 1, color: $r('app.color.divider') }).borderRadius(16)
            .padding({ left: 12, right: 12, top: 4, bottom: 4 })
        }
        Row({ space: 8 }) {
          if (this.communityMembers.length > 0) {
            Row() {
              ForEach(this.communityMembers.slice(0, 4), (member: TweetAuthor, index: number) => {
                ProxyAvatar({verifiedType: member.verifiedType ?? '', avatarShape: member.avatarShape ?? '',  url: member.avatarUrl ?? '', avatarSize: 24, radius: 12,
                  fallbackText: member.name.substring(0, 1), fallbackColor: member.avatarColor })
                  .border({ width: 1.5, color: $r('app.color.bg_page') }).borderRadius(12)
                  .margin({ left: index > 0 ? -8 : 0 })
                  .onClick((): void => this.openUser(member))
              }, (member: TweetAuthor): string => member.id + member.username)
            }
          }
          Text(formatCount(this.communityMemberCount) + ' ' + this.text($r('app.string.communities_members'))).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_S')).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
            .maxLines(1).minFontSize(11).maxFontSize(14).layoutWeight(1)
          this.RoundAction(this.favorite ? $r('sys.symbol.star_fill') : $r('sys.symbol.star'),
            this.favorite ? $r('app.string.community_favorite_remove') : $r('app.string.community_favorite_add'),
            (): void => this.toggleFavorite())
          this.RoundAction($r('sys.symbol.share'), $r('app.string.community_share_action'), (): void => { this.openSheet(1); })
          Button(this.membershipBusy ? $r('app.string.post_sending') : this.communityJoined ?
            $r('app.string.communities_joined') : $r('app.string.community_join_short'))
            .fontSize($r('sys.float.Body_M')).fontWeight(FontWeight.Bold)
            .fontColor(this.communityJoined ? $r('app.color.text_primary') : $r('app.color.text_on_accent'))
            .backgroundColor(this.communityJoined ? fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface) : this.accentColor)
            .padding({ left: 14, right: 14 }).height(36).enabled(!this.membershipBusy)
            .onClick((): void => { this.changeMembership(); })
        }.width('100%')
        if (this.communityDescription.length > 0) {
          Text(this.communityDescription).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_primary'))
            .maxLines(this.descriptionExpanded ? 100 : 3).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
            .onClick((): void => { this.descriptionExpanded = !this.descriptionExpanded; })
          if (!this.descriptionExpanded && this.communityDescription.length > 130) {
            Text($r('app.string.community_show_more')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor(this.accentColor)
              .onClick((): void => { this.descriptionExpanded = true; })
          }
        }
        if (this.membershipStatus.length > 0) {
          Text(this.membershipStatus).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S')).fontColor($r('app.color.danger')).width('100%')
        }
      }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 16, right: 16, top: 18, bottom: 18 })
        .backgroundColor(pageSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
    }.width('100%')
  }
  @Builder
  private ProfileTabs(): void {
    CommunityProfileTabs({ selected: this.selectedTab, tabPosition: this.tabPosition,
      timelineLabel: this.viewMode === 1 ? $r('app.string.community_my_posts') :
        this.viewMode === 2 ? $r('app.string.community_my_replies') : this.sortLabel(),
      onSelect: (index: number): void => this.selectTab(index), onSort: (): void => { this.openSheet(0); } })
  }
  @Builder
  private InfoRow(symbol: Resource, value: string): void {
    Row({ space: 18 }) {
      SymbolGlyph(symbol).fontSize(23).fontColor([$r('app.color.text_secondary')]).width(28)
      Text(value).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_primary')).layoutWeight(1)
    }.width('100%').padding({ left: 20, right: 20, top: 18, bottom: 18 })
  }
  @Builder
  private About(): void {
    ListItem() {
      Text($r('app.string.community_info_title')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Subtitle_L')).fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary')).width('100%').padding(16)
    }
    ListItem() { this.InfoRow($r('sys.symbol.person_2_fill'), this.text($r('app.string.community_info_members_post'))) }
    ListItem() { this.InfoRow($r('sys.symbol.globe_badge_message'), this.text(this.needsJoinRequest() ?
      $r('app.string.community_info_restricted') : $r('app.string.community_info_public'))) }
    if (this.creationLabel().length > 0 || this.communityCreator !== undefined) {
      ListItem() {
        Row({ space: 18 }) {
          SymbolGlyph($r('sys.symbol.calendar')).fontSize(23).fontColor([$r('app.color.text_secondary')]).width(28)
          Column({ space: 4 }) {
            Text(this.text($r('app.string.community_created_at')) + ' ' + this.creationLabel()).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_primary'))
            if (this.communityCreator !== undefined) {
              Text('@' + this.communityCreator.username).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontColor(this.accentColor)
                .onClick((): void => { if (this.communityCreator !== undefined) { this.openUser(this.communityCreator); } })
            }
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        }.width('100%').padding({ left: 20, right: 20, top: 18, bottom: 18 })
      }
    }
    ListItem() {
      Text($r('app.string.community_rules_title')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Subtitle_L')).fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary')).width('100%').padding(16)
    }
    if (this.communityRules.length === 0) {
      ListItem() { Text($r('app.string.community_rules_empty')).fontFamily(this.appFontFamily).fontColor($r('app.color.text_secondary')).padding(20) }
    }
    ForEach(this.communityRules, (rule: CommunityRule, index: number) => {
      ListItem() {
        Row({ space: 16 }) {
          Text((index + 1).toString()).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.bg_page')).backgroundColor($r('app.color.text_primary'))
            .width(36).height(36).borderRadius(18).textAlign(TextAlign.Center)
          Column({ space: 4 }) {
            Text(rule.name).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
            if (rule.description.length > 0) { Text(rule.description).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary')) }
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        }.width('100%').padding({ left: 16, right: 16, top: 14, bottom: 14 })
      }
    }, (rule: CommunityRule): string => rule.id + rule.name)
    if (this.communityModerators.length > 0) {
      ListItem() { Text($r('app.string.communities_moderators')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Subtitle_L')).fontWeight(FontWeight.Bold).padding(16) }
      ForEach(this.communityModerators, (member: TweetAuthor) => {
        ListItem() {
          Row({ space: 12 }) {
            ProxyAvatar({verifiedType: member.verifiedType ?? '', avatarShape: member.avatarShape ?? '',  url: member.avatarUrl ?? '', avatarSize: 40, radius: 20, fallbackText: member.name.substring(0, 1) })
            Text(member.name).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_primary'))
            Text('@' + member.username).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary'))
          }.width('100%').padding(16).onClick((): void => this.openUser(member))
        }
      }, (member: TweetAuthor): string => member.id)
    }
  }
  @Builder
  private HashtagSearchControl(): void {
    if (this.hashtagSearchOpen) {
      ListItem() {
        Search({ value: this.hashtagInput, placeholder: $r('app.string.community_hashtag_placeholder') })
          .height(44).keyboardAppearance(KeyboardAppearance.IMMERSIVE)
          .backgroundColor(fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
          .onChange((value: string): void => { this.hashtagInput = value; })
          .onSubmit((value: string): void => this.submitHashtag(value)).margin(12)
      }
    }
  }
  @Builder
  private Content(tab: number): void {
    if (this.selectedTab === tab && this.loading && this.visiblePosts(tab).length === 0) {
      ListItem() { LoadingProgress().color(this.accentColor).width(28).height(28).margin({ top: 40, bottom: 40 }) }
    } else if (this.visiblePosts(tab).length === 0 || (this.selectedTab === tab && this.status.length > 0)) {
      ListItem() {
        Column({ space: 16 }) {
          Text(this.selectedTab === tab && this.status.length > 0 ? this.status : this.text(this.emptyLabel(tab))).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_secondary')).textAlign(TextAlign.Center).width('100%')
          if (this.selectedTab === tab && this.requestFailed) {
            Button($r('app.string.common_retry')).backgroundColor(this.accentColor).fontColor($r('app.color.text_on_accent'))
              .onClick((): void => { this.load(true); })
          }
        }.width('100%').padding(24)
      }
    }
    ForEach(this.visiblePosts(tab), (post: Tweet) => {
      ListItem() {
        TweetCard({ tweet: post, onOpen: (item: Tweet): void => this.openPost(item),
          onReply: (item: Tweet): void => this.openPost(item),
          onLikeChanged: (item: Tweet, value: boolean): Promise<boolean> => this.reaction(item, true, value),
          onRepostChanged: (item: Tweet, value: boolean): Promise<boolean> => this.reaction(item, false, value),
          onBookmarkChanged: (item: Tweet, value: boolean): void => this.bookmark(item, value),
          onAuthorTapped: (item: Tweet): void => this.openUser(item.author) })
      }
    }, (post: Tweet): string => post.id)
    if (this.loadingMore) { ListItem() { LoadingProgress().width(24).height(24).color(this.accentColor) } }
  }
  @Builder
  private ActivityList(tab: number): void {
    List({ scroller: this.activityScrollers[tab] }) {
      if (tab === 2) { this.About() }
      else {
        if (tab === 0) { this.HashtagSearchControl() }
        this.Content(tab)
      }
    }.width('100%').height('100%').scrollBar(BarState.Off).contentEndOffset(this.navigationIndicatorHeight)
      .nestedScroll({ scrollForward: NestedScrollMode.PARENT_FIRST, scrollBackward: NestedScrollMode.SELF_FIRST })
      .onReachEnd((): void => { if (tab === this.selectedTab && tab < 2) { this.load(false); } })
  }
  @Builder
  private ActivityPager(): void {
    Swiper(this.activitySwiper) {
      this.ActivityList(0)
      this.ActivityList(1)
      this.ActivityList(2)
    }.width('100%').height(Math.max(1, this.viewportHeight - 52)).index(this.selectedTab)
      .loop(false).indicator(false).cachedCount(1).duration(280).curve(Curve.EaseOut).clip(true).disableSwipe(this.refreshing)
      .onChange((index: number): void => this.activityChanged(index))
      .onContentDidScroll((_selected: number, index: number, position: number, _length: number): void => {
        this.tabPosition = ProfileTabMotion.scrollPosition(index, position, 3);
      }).onAnimationEnd((index: number, _event: SwiperAnimationEvent): void => { this.tabPosition = index; })
  }
  @Builder
  private SortOption(icon: Resource, label: Resource, selected: boolean, value: string, action: () => void): void {
    Row({ space: 16 }) {
      SymbolGlyph(icon).fontSize(24).fontColor([$r('app.color.text_primary')]).width(28)
      Text(label).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary')).layoutWeight(1)
      Radio({ value: value, group: 'community-timeline-options' }).checked(selected)
        .radioStyle({ checkedBackgroundColor: $r('app.color.text_primary') }).width(24).height(24)
        .accessibilityText(label).onChange((checked: boolean): void => { if (checked) { action(); } })
    }.width('100%').padding({ left: 24, right: 24, top: 18, bottom: 18 }).onClick(action)
  }
  @Builder
  private SortSheet(): void {
    Column({ space: 0 }) {
      Text($r('app.string.community_timeline_options')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Title_S')).fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary')).width('100%').padding(24)
      Divider().color($r('app.color.divider')).margin({ left: 24, right: 24, bottom: 18 })
      Text($r('app.string.community_sort_section')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S')).fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_secondary')).width('100%').padding({ left: 24, top: 14, bottom: 12 })
      this.SortOption($r('sys.symbol.flame'), $r('app.string.community_sort_trending'), this.sortMode === 'Relevance' && this.viewMode === 0, 'Relevance',
        (): void => this.selectSort('Relevance'))
      this.SortOption($r('sys.symbol.wand_and_stars'), $r('app.string.community_sort_new'), this.sortMode === 'Recency' && this.viewMode === 0, 'Recency',
        (): void => this.selectSort('Recency'))
      this.SortOption($r('sys.symbol.heart'), $r('app.string.community_sort_top'), this.sortMode === 'Likes' && this.viewMode === 0, 'Likes',
        (): void => this.selectSort('Likes'))
      Text($r('app.string.community_view_section')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S')).fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_secondary')).width('100%').padding({ left: 24, top: 14, bottom: 12 })
      this.SortOption($r('sys.symbol.person'), $r('app.string.community_my_posts'), this.viewMode === 1, 'posts',
        (): void => { this.chooseMyView(1); })
      this.SortOption($r('sys.symbol.person'), $r('app.string.community_my_replies'), this.viewMode === 2, 'replies',
        (): void => { this.chooseMyView(2); })
    }.width('100%').padding({ bottom: this.navigationIndicatorHeight + 16 })
  }
  @Builder
  private ShareAction(icon: Resource, label: Resource, action: () => void): void {
    Row({ space: 20 }) {
      SymbolGlyph(icon).fontSize(25).fontColor([$r('app.color.text_primary')])
      Text(label).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
    }.width('100%').padding({ left: 24, right: 24, top: 20, bottom: 20 }).onClick(action)
  }
  @Builder
  private ShareSheet(): void {
    Column({ space: 0 }) {
      this.ShareAction($r('sys.symbol.square_and_pencil'), $r('app.string.community_share_post'), (): void => {
        this.actionSheetOpen = false; this.openComposer(this.url(), true);
      })
      this.ShareAction($r('sys.symbol.link'), $r('app.string.community_copy_link'), (): void => this.copyLink())
      this.ShareAction($r('sys.symbol.share'), $r('app.string.community_share_action'), (): void => this.share())
      Button($r('app.string.compose_cancel')).width('90%').height(48)
        .fontColor($r('app.color.text_primary')).backgroundColor(fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
        .margin({ top: 16 }).onClick((): void => { this.actionSheetOpen = false; })
    }.width('100%').padding({ top: 16, bottom: this.navigationIndicatorHeight + 20 })
  }
  @Builder
  private ActionSheet(): void {
    if (this.actionSheetMode === 0) { this.SortSheet() } else { this.ShareSheet() }
  }
  build(): void {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.Top }) {
        this.ProfileBanner()
        Column({ space: 0 }) {
          this.TopNavigation()
          Refresh({ refreshing: $$this.refreshing }) {
            List({ scroller: this.scroller }) {
              ListItem() { this.CommunityOverview() }
              ListItemGroup({ header: this.ProfileTabs() }) {
                ListItem() { this.ActivityPager() }
              }
            }.width('100%').height('100%').scrollBar(BarState.Off).sticky(StickyStyle.Header)
              .onDidScroll((): void => { this.scrollOffset = Math.max(0, this.scroller.currentOffset().yOffset); })
          }.width('100%').layoutWeight(1).onRefreshing((): void => {
            this.loadCommunityInfo();
            this.load(true).then((): void => { this.refreshing = false; });
          }).onAreaChange((_old: Area, area: Area): void => {
            const height: number = Number(area.height);
            if (Math.abs(this.viewportHeight - height) > 0.5) { this.viewportHeight = height; }
          })
        }.width('100%').height('100%')
        if (this.communityJoined && this.selectedTab < 2) {
          FloatingComposeButton({ bottomInset: this.navigationIndicatorHeight, bottomBarHeight: 0,
            gripSubscriberKey: 'community-profile-compose', accessibilityLabel: this.text($r('app.string.community_post_action')),
            onCompose: (): void => this.openComposer() })
        }
      }.width('100%').height('100%')
    }.hideTitleBar(true).hideBackButton(true)
      .onBackPressed((): boolean => { ResponsiveLayout.closeContentDestination(this.pageStack); return true; })
      .backgroundColor(pageSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
      .bindSheet($$this.actionSheetOpen, this.ActionSheet(), sheetMaterialOptions({ height: SheetSize.FIT_CONTENT, showClose: true,
        backgroundColor: pageSurfaceColor(this.themeDisplayMode, this.themeDarkSurface) }, this.sheetMaterialEnabled, this.sheetMaterialLevel, this.sheetWindowBreakpoint, this.sheetCompactWindow))
  }
}

