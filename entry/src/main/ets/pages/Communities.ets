import { pageTextColor } from '../utils/ThemeColors';
import { pageBackgroundActive } from '../services/PageBackgroundStore';
import { appPageBackground } from '../components/PageBackgroundLayer';
import { pageCanvasColor, pageReadingSurfaceColor } from '../utils/ThemeColors';
import { STORAGE_KEY_PAGE_TRANSITION_MODE, DEFAULT_PAGE_TRANSITION_MODE } from '../services/PageTransitionSettingsStore';
import { pageSystemTransition, PageTransitionMotion } from '../utils/PageTransition';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { AnimatedIconTabs } from '../components/AnimatedIconTabs';
import { ProfileTabMotion } from '../utils/ProfileTabMotion';
import { common } from '@kit.AbilityKit';
import promptAction from '@ohos.promptAction';
import { BottomBuilderShowType, DividerShowType, HdsNavDestination, HdsNavDestinationTitleMode,
  ScrollEffectType } from '@kit.UIDesignKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { uiMaterial } from '@kit.ArkUI';
import { destinationTitleBarStyle } from '../utils/DestinationTitleBar';
import { CommunityRowCard } from '../components/CommunityRowCard';
import { ConversationTweetCard } from '../components/ConversationTweetCard';
import { FloatingComposeButton } from '../components/FloatingComposeButton';
import { ProxyAvatar } from '../components/ProxyAvatar';
import { ProxyMediaImage } from '../components/ProxyMediaImage';
import type { ReplyComposerRouteParam } from '../components/ReplyComposer';
import type { CommunityRow, CommunityRule } from '../models/Community';
import type { Tweet } from '../models/Tweet';
import type { TweetPage } from '../services/XApiClient';
import { XCommunityParser } from '../services/XCommunityParser';
import { XTimelineParser } from '../services/XTimelineParser';
import { XPrivateClient, XPrivateResult, xPrivateClient } from '../services/XPrivateClient';
import { communityFavoritesStore } from '../services/CommunityFavoritesStore';
import { communityRoute } from '../utils/CommunityNavigation';
import { pageSurfaceColor } from '../utils/ThemeColors';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';
import { sheetMaterialOptions } from '../utils/SheetMaterial';
import { DEFAULT_SHEET_MATERIAL_ENABLED, DEFAULT_SHEET_MATERIAL_LEVEL, STORAGE_KEY_SHEET_MATERIAL_ENABLED,
  STORAGE_KEY_SHEET_MATERIAL_LEVEL } from '../services/SheetMaterialSettingsStore';
import type { PostDetailRouteParam } from './PostDetail';
import type { UserDetailRouteParam } from './UserDetail';

export interface CommunityTimelineRouteParam {
  communityId: string;
  title: string;
  description: string;
  memberCount: number;
  moderatorCount: number;
  bannerUrl: string;
  joinPolicy: string;
  ruleCount: number;
  rules: CommunityRule[];
  joined: boolean;
  community?: CommunityRow;
}
export interface CommunityRulesRouteParam {
  title: string;
  rules: CommunityRule[];
  communityId?: string;
  joinPolicy?: string;
  joinQuestion?: string;
}
@Observed
class CommunityFeed {
  posts: Tweet[] = [];
  status: string = '';
  loading: boolean = false;
  loadingMore: boolean = false;
  refreshing: boolean = false;
  loaded: boolean = false;
  nextToken: string = '';
  revision: number = 0;
}
@Builder
export function CommunitiesBuilder(): void { Communities(); }

@Component
export struct Communities {
  @StorageProp('harmonyx.page_background') private pageBackgroundValue: string = '';
  @State private pageMotion: PageTransitionMotion = new PageTransitionMotion();
  @StorageProp(STORAGE_KEY_PAGE_TRANSITION_MODE) private pageTransitionMode: string = DEFAULT_PAGE_TRANSITION_MODE;
  @StorageProp('harmonyx.compact_window') private sheetCompactWindow: boolean = false;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp('harmonyx.breakpoint') private sheetWindowBreakpoint: string = 'sm';
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp('harmonyx.status_bar_height') statusBarHeight: number = 0;
  @StorageProp('harmonyx.navigation_indicator_height') navigationIndicatorHeight: number = 0;
  @StorageLink('harmonyx.accent_color') accentColor: string = '#007DFF';
  @StorageProp('harmonyx.display_mode') themeDisplayMode: string = '';
  @StorageProp('harmonyx.dark_surface') themeDarkSurface: string = '';
  @StorageLink('harmonyx.title_bar_style_mode') titleBarStyleMode: number = 0;
  @StorageProp(STORAGE_KEY_SHEET_MATERIAL_ENABLED) sheetMaterialEnabled: boolean = DEFAULT_SHEET_MATERIAL_ENABLED;
  @StorageProp(STORAGE_KEY_SHEET_MATERIAL_LEVEL) sheetMaterialLevel: number = DEFAULT_SHEET_MATERIAL_LEVEL;
  @StorageProp('harmonyx.community_membership_changed') @Watch('membershipChanged') membershipRevision: number = 0;
  @StorageProp('harmonyx.posts_changed') @Watch('postsChanged') postRevision: number = 0;
  @State private home: CommunityFeed = new CommunityFeed();
  @State private explore: CommunityFeed = new CommunityFeed();
  @State private selectedTab: number = 0;
  @State private tabPosition: number = 0;
  @State private joined: CommunityRow[] = [];
  @State private recommendations: CommunityRow[] = [];
  @State private favorites: CommunityRow[] = [];
  @State private composeOpen: boolean = false;
  @State private newestFirst: boolean = false;
  private pager: SwiperController = new SwiperController();
  private homeScroller: Scroller = new Scroller();
  private exploreScroller: Scroller = new Scroller();
  private directoryRevision: number = 0;

  aboutToAppear(): void { this.loadFeed(0, true); this.loadDirectory(); }
  private text(resource: Resource): string {
    return (getContext(this) as common.UIAbilityContext).resourceManager.getStringSync(resource);
  }
  private membershipChanged(): void { this.loadDirectory(); this.loadFeed(0, true); }
  private postsChanged(): void { this.loadFeed(this.selectedTab, true); }
  private feed(index: number): CommunityFeed { return index === 0 ? this.home : this.explore; }

  private async loadDirectory(): Promise<void> {
    const revision: number = ++this.directoryRevision;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    this.favorites = communityFavoritesStore.load(context);
    xPrivateClient.load(context);
    if (!xPrivateClient.isSignedIn()) { return; }
    const results: XPrivateResult[] = await Promise.all([
      xPrivateClient.myCommunities(), xPrivateClient.communityDirectory('', '')
    ]);
    if (revision !== this.directoryRevision) { return; }
    if (results[0].ok) {
      this.joined = XCommunityParser.parse(results[0].body)?.communities ?? [];
      for (let i: number = 0; i < this.joined.length; i++) { this.joined[i].joined = true; }
    } else if (xPrivateClient.viewerId().length > 0) {
      const fallback: XPrivateResult = await xPrivateClient.joinedCommunities(xPrivateClient.viewerId(), '', 30);
      if (revision !== this.directoryRevision) { return; }
      if (fallback.ok) {
        this.joined = XCommunityParser.parse(fallback.body)?.communities ?? [];
        for (let i: number = 0; i < this.joined.length; i++) { this.joined[i].joined = true; }
      }
    }
    if (results[1].ok) { this.recommendations = XCommunityParser.parse(results[1].body)?.communities ?? []; }
  }

  private syncJoinedFromFeed(body: string): void {
    const rows: CommunityRow[] = XCommunityParser.parse(body)?.communities ?? [];
    const joined: CommunityRow[] = this.joined.slice();
    for (let i: number = 0; i < rows.length; i++) {
      if (!rows[i].joined) { continue; }
      const existing: number = joined.findIndex((row: CommunityRow): boolean => row.id === rows[i].id);
      if (existing >= 0) { joined[existing] = rows[i]; } else { joined.push(rows[i]); }
    }
    this.joined = joined;
  }

  private async loadFeed(index: number, reset: boolean): Promise<void> {
    const state: CommunityFeed = this.feed(index);
    if (!reset && (state.loading || state.loadingMore || state.status.length > 0 || state.nextToken.length === 0)) { return; }
    const revision: number = reset ? ++state.revision : state.revision;
    if (reset) { state.loading = true; state.loadingMore = false; state.status = ''; state.nextToken = ''; }
    else { state.loadingMore = true; }
    xPrivateClient.load(getContext(this) as common.UIAbilityContext);
    if (!xPrivateClient.isSignedIn()) {
      state.status = this.text($r('app.string.user_list_sign_in'));
      state.loading = false; state.refreshing = false; state.loadingMore = false;
      return;
    }
    const cursor: string = reset ? '' : state.nextToken;
    const result: XPrivateResult = index === 0 ? await xPrivateClient.communitiesTimeline(cursor, 20) :
      await xPrivateClient.communityExplorePosts(cursor, 20);
    if (revision !== state.revision) { return; }
    const page: TweetPage | null = result.ok ? XTimelineParser.parse(result.body) : null;
    if (page === null) {
      state.status = this.text(result.status === 401 || result.status === 403 ?
        $r('app.string.private_session_expired') : $r('app.string.communities_failed')) +
        (result.ok ? '' : '\n' + XPrivateClient.explain(result).substring(0, 180));
    } else {
      if (index === 0) { this.syncJoinedFromFeed(result.body); }
      const posts: Tweet[] = reset ? [] : state.posts.slice();
      for (let i: number = 0; i < page.tweets.length; i++) {
        if (!posts.some((post: Tweet): boolean => post.id === page.tweets[i].id)) { posts.push(page.tweets[i]); }
      }
      state.posts = posts;
      state.nextToken = page.tweets.length > 0 && page.nextToken !== cursor ? page.nextToken : '';
      state.status = '';
    }
    state.loaded = true; state.loading = false; state.loadingMore = false; state.refreshing = false;
  }

  private selectTab(index: number): void {
    this.selectedTab = index;
    if (!this.feed(index).loaded && !this.feed(index).loading) { this.loadFeed(index, true); }
  }
  private openCommunity(row: CommunityRow): void {
    this.pageStack.pushPath({ name: 'CommunityTimeline', param: communityRoute(row) });
  }
  private search(): void { this.pageStack.pushPath({ name: 'CommunitySearch' }); }
  private openPost(post: Tweet): void {
    const param: PostDetailRouteParam = { tweet: post };
    this.pageStack.pushPath({ name: 'PostDetail', param: param });
  }
  private openComposer(row: CommunityRow): void {
    this.composeOpen = false;
    const param: ReplyComposerRouteParam = { replyToId: '', replyToUser: '', avatarUrl: '', avatarName: '',
      avatarColor: this.accentColor, initialText: '', imageUri: '', gifUri: '', communityId: row.id,
      communityName: row.name, parentTweet: null };
    this.pageStack.pushPath({ name: 'ReplyComposer', param: param });
  }
  private async reaction(post: Tweet, like: boolean, value: boolean): Promise<boolean> {
    const result: XPrivateResult = like ? await xPrivateClient.like(post.id, value) :
      await xPrivateClient.repost(post.id, value);
    if (!result.ok) { promptAction.showToast({ message: XPrivateClient.explain(result).substring(0, 160) }); }
    return result.ok;
  }
  private bookmark(post: Tweet, value: boolean): void {
    xPrivateClient.bookmark(post.id, value).then((result: XPrivateResult): void => {
      if (result.ok) { post.bookmarked = value; }
      else { promptAction.showToast({ message: XPrivateClient.explain(result).substring(0, 160) }); }
    });
  }
  private orderedPosts(index: number): Tweet[] {
    const posts: Tweet[] = this.feed(index).posts.slice();
    if (this.newestFirst) { posts.sort((a: Tweet, b: Tweet): number => Date.parse(b.createdAt) - Date.parse(a.createdAt)); }
    return posts;
  }
  private async sort(): Promise<void> {
    const result: promptAction.ActionMenuSuccessResponse = await promptAction.showActionMenu({
      title: this.text($r('app.string.community_timeline_options')),
      buttons: [{ text: this.text($r('app.string.community_sort_trending')), color: this.accentColor },
        { text: this.text($r('app.string.community_sort_new')), color: this.accentColor }]
    });
    this.newestFirst = result.index === 1;
  }

  @Builder
  private TitleBarTabs(): void {
    AnimatedIconTabs({ items: [
      { key: 'home', label: $r('app.string.community_home_tab'), icon: $r('sys.symbol.person_2') },
      { key: 'explore', label: $r('app.string.communities_explore'), icon: $r('sys.symbol.magnifyingglass') }
    ], selected: this.selectedTab, tabPosition: this.tabPosition, barHeight: 48,
      onSelect: (index: number): void => this.pager.changeIndex(index, true) })
  }

  @Builder
  private JoinedCommunities(): void {
    ListItem() {
      Scroll() {
        Row({ space: 22 }) {
          ForEach(this.joined, (row: CommunityRow) => {
            Column({ space: 0 }) {
              Stack() {
                if (row.bannerUrl.length > 0) {
                  ProxyMediaImage({ url: row.bannerUrl, displayHeight: 52 })
                } else {
                  SymbolGlyph($r('sys.symbol.person_2_fill')).fontSize(24).fontColor([pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, $r('app.color.bg_field'))])
                }
              }.width('100%').height(52).clip(true).backgroundColor($r('app.color.bg_field'))
              Text(row.name).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontWeight(FontWeight.Bold)
                .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent)).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%').height(32).padding({ left: 8, right: 8 })
            }.width(130).height(84).borderRadius(12).clip(true)
              .backgroundColor(pageCanvasColor(this.themeDisplayMode, this.themeDarkSurface, this.pageBackgroundValue))
              .border({ width: 0.5, color: $r('app.color.divider') })
              .onClick((): void => this.openCommunity(row))
          }, (row: CommunityRow): string => row.id)
          Button({ type: ButtonType.Circle }) {
            SymbolGlyph($r('sys.symbol.arrow_right')).fontSize(24).fontColor([pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent)])
          }.width(52).height(52).backgroundColor(Color.Transparent)
            .border({ width: 1, color: $r('app.color.divider') })
            .accessibilityText($r('app.string.community_explore_more')).id('community-explore-more')
            .onClick((): void => this.search())
        }.padding({ left: 16, right: 24, top: 10, bottom: 12 })
      }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%').align(Alignment.Start)
    }
  }
  @Builder
  private JoinedStrip(rows: CommunityRow[], label: Resource): void {
    if (rows.length > 0) {
      ListItem() {
        Column({ space: 10 }) {
          Text(label).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontWeight(FontWeight.Bold).fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent))
          Scroll() {
            Row({ space: 16 }) {
              ForEach(rows, (row: CommunityRow) => {
                Column({ space: 6 }) {
                  ProxyAvatar({ url: row.bannerUrl, avatarSize: 52, radius: 14,
                    fallbackText: row.name.substring(0, 1), fallbackColor: this.accentColor })
                  Text(row.name).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S')).fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent))
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width(80).textAlign(TextAlign.Center)
                }.width(80).onClick((): void => this.openCommunity(row))
              }, (row: CommunityRow): string => row.id)
            }
          }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%')
        }.alignItems(HorizontalAlign.Start).width('100%').padding({ left: 16, right: 16, top: 14, bottom: 14 })
      }
    }
  }
  @Builder
  private Recommendations(): void {
    if (this.recommendations.length > 0) {
      ListItem() {
        Text($r('app.string.community_discover_new')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Subtitle_L')).fontWeight(FontWeight.Bold)
          .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent)).width('100%').padding({ left: 16, top: 20, bottom: 8 })
      }
      ForEach(this.recommendations.slice(0, 3), (row: CommunityRow) => {
        ListItem() { CommunityRowCard({ community: row, onOpen: (item: CommunityRow): void => this.openCommunity(item) }) }
      }, (row: CommunityRow): string => row.id)
      ListItem() {
        Row() {
          Text($r('app.string.community_show_more')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontColor(this.accentColor)
          Blank()
          SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(14).fontColor([pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)])
        }.width('100%').padding(16).onClick((): void => this.search())
      }
    }
  }
  @Builder
  private FeedContent(index: number): void {
    if (this.feed(index).loading && this.feed(index).posts.length === 0) {
      ListItem() { LoadingProgress().width(28).height(28).color(this.accentColor).margin({ top: 48, bottom: 48 }) }
    } else if (this.feed(index).status.length > 0) {
      ListItem() {
        Column({ space: 14 }) {
          Text(this.feed(index).status).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)).textAlign(TextAlign.Center)
          Button($r('app.string.common_retry')).backgroundColor(this.accentColor).fontColor($r('app.color.text_on_accent'))
            .onClick((): void => { this.loadFeed(index, true); })
        }.width('100%').padding(24)
      }
    } else if (this.feed(index).posts.length === 0 && (index === 1 || this.recommendations.length === 0)) {
      ListItem() {
        Text($r('app.string.community_home_empty')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
          .textAlign(TextAlign.Center).width('100%').padding(32)
      }
    }
    ForEach(this.orderedPosts(index), (post: Tweet) => {
      ListItem() {
        ConversationTweetCard({ tweet: post,
          onOpen: (item: Tweet): void => this.openPost(item), onReply: (item: Tweet): void => this.openPost(item),
          onLikeChanged: (item: Tweet, value: boolean): Promise<boolean> => this.reaction(item, true, value),
          onRepostChanged: (item: Tweet, value: boolean): Promise<boolean> => this.reaction(item, false, value),
          onBookmarkChanged: (item: Tweet, value: boolean): void => this.bookmark(item, value),
          onAuthorTapped: (item: Tweet): void => {
            const param: UserDetailRouteParam = { author: item.author, posts: [] };
            this.pageStack.pushPath({ name: 'UserDetail', param: param });
          } })
      }
    }, (post: Tweet): string => post.id)
    if (this.feed(index).loadingMore) { ListItem() { LoadingProgress().width(24).height(24).color(this.accentColor) } }
  }
  @Builder
  private FeedPage(index: number): void {
    Refresh({ refreshing: this.feed(index).refreshing }) {
      List({ scroller: index === 0 ? this.homeScroller : this.exploreScroller }) {
        if (index === 0) {
          this.JoinedCommunities()
          this.JoinedStrip(this.favorites, $r('app.string.communities_favorites'))
          ListItem() {
            Row({ space: 6 }) {
              SymbolGlyph($r('sys.symbol.arrow_up_and_down_square_portrait')).fontSize(15).fontColor([pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent)])
              Text(this.newestFirst ? $r('app.string.community_sort_new') : $r('app.string.community_sort_trending')).fontFamily(this.appFontFamily)
                .fontSize($r('sys.float.Body_M')).fontWeight(FontWeight.Medium).fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent))
            }.padding({ left: 14, right: 14, top: 7, bottom: 7 }).borderRadius(20)
              .border({ width: 1, color: $r('app.color.divider') }).margin({ left: 16, top: 8, bottom: 8 })
              .onClick((): void => { this.sort(); })
          }
        }
        this.FeedContent(index)
        if (index === 0) { this.Recommendations() }
      }.width('100%').height('100%').scrollBar(BarState.Off)
        .contentStartOffset(this.statusBarHeight + 108)
        .divider({ strokeWidth: 0.5, color: $r('app.color.divider') })
        .contentEndOffset(this.navigationIndicatorHeight + 80)
        .clip(false)
        .onReachEnd((): void => { this.loadFeed(index, false); })
    }.width('100%').height('100%').clip(false)
      .onRefreshing((): void => { this.feed(index).refreshing = true; this.loadFeed(index, true); if (index === 0) { this.loadDirectory(); } })
  }
  @Builder
  private ComposeSheet(): void {
    List() {
      ListItem() { Text($r('app.string.community_choose_post')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Title_S')).fontWeight(FontWeight.Bold).padding(20) }
      ForEach(this.joined, (row: CommunityRow) => {
        ListItem() { CommunityRowCard({ community: row, onOpen: (item: CommunityRow): void => this.openComposer(item) }) }
      }, (row: CommunityRow): string => row.id)
    }.width('100%').height('100%').scrollBar(BarState.Off)
  }
  build(): void {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        appPageBackground()
      Stack() {
        Swiper(this.pager) { this.FeedPage(0); this.FeedPage(1) }
          .width('100%').height('100%').loop(false).indicator(false).cachedCount(1).clip(false)
          .duration(280).curve(Curve.EaseOut)
          .onChange((index: number): void => this.selectTab(index))
          .onContentDidScroll((_selected: number, index: number, position: number, _length: number): void => {
            this.tabPosition = ProfileTabMotion.scrollPosition(index, position, 2);
          })
          .onAnimationEnd((index: number): void => { this.tabPosition = index; })
        FloatingComposeButton({ bottomInset: this.navigationIndicatorHeight, bottomBarHeight: 0,
          gripSubscriberKey: 'communities-compose', accessibilityLabel: this.text($r('app.string.community_post_action')),
          onCompose: (): void => { if (this.joined.length > 0) { this.composeOpen = true; } else { this.search(); } } })
      }.width('100%').height('100%')
    
      }.width('100%').height('100%')
    }
    .scale({ x: this.pageMotion.scale, y: this.pageMotion.scale })
    .opacity(this.pageMotion.opacity)
    .onReady((context: NavDestinationContext): void => { this.pageMotion.attach(context); })
    .systemTransition(pageSystemTransition(this.pageTransitionMode)).titleMode(HdsNavDestinationTitleMode.MINI).hideBackButton(false)
      .onShown((): void => { this.favorites = communityFavoritesStore.load(getContext(this) as common.UIAbilityContext); })
      .onBackPressed((): boolean => { ResponsiveLayout.closeContentDestination(this.pageStack); return true; })
      .bindToScrollable([this.homeScroller, this.exploreScroller])
      .titleBar({ avoidLayoutSafeArea: true,
        content: { title: { mainTitle: $r('app.string.communities_title') },
          bottomBuilder: { builder: (): void => this.TitleBarTabs(), height: 48,
            showType: BottomBuilderShowType.DIRECTLY_SHOW },
          divider: { showType: DividerShowType.OFF },
          menu: { value: [{ content: { icon: $r('sys.symbol.magnifyingglass'),
            label: $r('app.string.community_search_placeholder'), action: (): void => this.search() } }], maxCount: 1 } },
        style: destinationTitleBarStyle(ScrollEffectType.IMMERSIVE_GRADIENT_BLUR,
          this.themeDisplayMode, this.themeDarkSurface, this.titleBarStyleMode) })
      .backgroundColor(pageCanvasColor(this.themeDisplayMode, this.themeDarkSurface, this.pageBackgroundValue))
      .systemMaterial(!pageBackgroundActive(this.pageBackgroundValue) && deviceInfo.apiAvailable('26.0.0') ? new uiMaterial.ImmersiveMaterial({
        style: uiMaterial.ImmersiveStyle.REGULAR, applyShadow: true, colorInvert: true }) : undefined)
      .bindSheet($$this.composeOpen, this.ComposeSheet(), sheetMaterialOptions({ height: SheetSize.LARGE,
        showClose: true, backgroundColor: pageSurfaceColor(this.themeDisplayMode, this.themeDarkSurface) },
        this.sheetMaterialEnabled, this.sheetMaterialLevel, this.sheetWindowBreakpoint, this.sheetCompactWindow))
  }
}

