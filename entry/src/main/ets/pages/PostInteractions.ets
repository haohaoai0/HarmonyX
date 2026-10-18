import { AdaptivePostFeed } from '../components/AdaptivePostFeed';
import { pageTextColor } from '../utils/ThemeColors';
import { appPageBackground } from '../components/PageBackgroundLayer';
import { pageCanvasColor, pageReadingSurfaceColor } from '../utils/ThemeColors';
import { STORAGE_KEY_PAGE_TRANSITION_MODE, DEFAULT_PAGE_TRANSITION_MODE } from '../services/PageTransitionSettingsStore';
import { pageSystemTransition, PageTransitionMotion } from '../utils/PageTransition';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { AnimatedIconTabs } from '../components/AnimatedIconTabs';
import { ProfileTabMotion } from '../utils/ProfileTabMotion';
import { userAvatarRadius, userVerifiedType, userAvatarShape, verificationBadgeColor } from '../utils/UserIdentity';
// Live quote and repost activity for one X post. Quotes are searched from X's
// current post index and verified against the quoted-post id; reposts use X's
// dedicated RepostersTimelineQuery user timeline.
import {
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  ScrollEffectType
} from '@kit.UIDesignKit';
import common from '@ohos.app.ability.common';
import { TweetCard } from '../components/TweetCard';
import { XPrivateClient, XPrivateResult, xPrivateClient } from '../services/XPrivateClient';
import { XTimelineParser } from '../services/XTimelineParser';
import type { TweetPage } from '../services/XApiClient';
import { formatCount } from '../models/Tweet';
import type { Tweet, TweetAuthor, UserRow } from '../models/Tweet';
import { destinationTitleBarStyle } from '../utils/DestinationTitleBar';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';
import { pageSurfaceColor } from '../utils/ThemeColors';
import type { PostDetailRouteParam } from './PostDetail';
import type { UserDetailRouteParam } from './UserDetail';

const INTERACTION_TAB_QUOTES: string = 'quotes';
const INTERACTION_TAB_REPOSTS: string = 'reposts';
const ACTIVITY_PAGE_SIZE: number = 30;

export interface PostInteractionsRouteParam {
  tweet: Tweet;
}

@Builder
export function PostInteractionsBuilder(): void {
  PostInteractionsPage();
}

@Component
export struct PostInteractionsPage {
  @StorageProp('harmonyx.page_background') private pageBackgroundValue: string = '';
  @State private pageMotion: PageTransitionMotion = new PageTransitionMotion();
  @StorageProp(STORAGE_KEY_PAGE_TRANSITION_MODE) private pageTransitionMode: string = DEFAULT_PAGE_TRANSITION_MODE;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp('harmonyx.status_bar_height') statusBarHeight: number =
    AppStorage.get<number>('harmonyx.status_bar_height') ?? 0;
  @StorageProp('harmonyx.navigation_indicator_height') navigationIndicatorHeight: number =
    AppStorage.get<number>('harmonyx.navigation_indicator_height') ?? 0;
  @StorageLink('harmonyx.accent_color') accentColor: string = '#007DFF';
  @StorageProp('harmonyx.display_mode') private themeDisplayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private themeDarkSurface: string = '';
  @StorageLink('harmonyx.title_bar_style_mode') titleBarStyleMode: number = 0;
  @State private tweet: Tweet | null = null;
  @State private quotes: Tweet[] = [];
  @State private reposters: UserRow[] = [];
  @State private activeTab: string = INTERACTION_TAB_QUOTES;
  @State private tabPosition: number = 0;
  private pager: SwiperController = new SwiperController();
  @State private quoteLoading: boolean = true;
  @State private repostLoading: boolean = true;
  @State private quoteLoadingMore: boolean = false;
  @State private repostLoadingMore: boolean = false;
  @State private quoteStatus: string = '';
  @State private repostStatus: string = '';
  @State private refreshing: boolean = false;
  private quoteNextToken: string = '';
  private repostNextToken: string = '';
  private activityScrollers: Scroller[] = [new Scroller(), new Scroller()];

  private text(resource: Resource): string {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    return context.resourceManager.getStringSync(resource);
  }

  private applyRouteParam(param: PostInteractionsRouteParam): void {
    this.tweet = param.tweet;
  }

  private isLivePost(): boolean {
    const current: Tweet | null = this.tweet;
    if (current === null || current.id.length === 0) {
      return false;
    }
    for (let i: number = 0; i < current.id.length; i++) {
      const code: number = current.id.charCodeAt(i);
      if (code < 48 || code > 57) {
        return false;
      }
    }
    return true;
  }

  private initializePrivateClient(): boolean {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    xPrivateClient.load(context);
    return xPrivateClient.isSignedIn();
  }

  // A quote post carries the original as `quotedTweet` in the returned data.
  // The URL/id search only discovers candidates; this check prevents ordinary
  // discussion of the same id from being shown as a quote.
  private filterQuotes(candidates: Tweet[]): Tweet[] {
    const current: Tweet | null = this.tweet;
    const out: Tweet[] = [];
    if (current === null) {
      return out;
    }
    for (let i: number = 0; i < candidates.length; i++) {
      const quoted = candidates[i].quotedTweet;
      if (quoted !== undefined && quoted.id === current.id) {
        out.push(candidates[i]);
      }
    }
    return out;
  }

  private quoteSearchQuery(): string {
    const current: Tweet | null = this.tweet;
    if (current === null) {
      return '';
    }
    if (current.author.username.length > 0) {
      return 'https://x.com/' + current.author.username + '/status/' + current.id;
    }
    return current.id;
  }

  private mergeTweets(existing: Tweet[], incoming: Tweet[]): Tweet[] {
    const out: Tweet[] = [];
    const seen: string[] = [];
    for (let i: number = 0; i < existing.length; i++) {
      if (seen.indexOf(existing[i].id) < 0) {
        seen.push(existing[i].id);
        out.push(existing[i]);
      }
    }
    for (let i: number = 0; i < incoming.length; i++) {
      if (seen.indexOf(incoming[i].id) < 0) {
        seen.push(incoming[i].id);
        out.push(incoming[i]);
      }
    }
    return out;
  }

  private mergeUsers(existing: UserRow[], incoming: UserRow[]): UserRow[] {
    const out: UserRow[] = [];
    const seen: string[] = [];
    for (let i: number = 0; i < existing.length; i++) {
      if (seen.indexOf(existing[i].id) < 0) {
        seen.push(existing[i].id);
        out.push(existing[i]);
      }
    }
    for (let i: number = 0; i < incoming.length; i++) {
      if (seen.indexOf(incoming[i].id) < 0) {
        seen.push(incoming[i].id);
        out.push(incoming[i]);
      }
    }
    return out;
  }

  private errorStatus(result: XPrivateResult): string {
    const detail: string = XPrivateClient.explain(result).substring(0, 100);
    const prefix: string = result.status === 401 || result.status === 403 ?
      this.text($r('app.string.private_session_expired')) : this.text($r('app.string.post_interactions_load_failed'));
    return detail.length > 0 ? prefix + ' · ' + detail : prefix + ' · HTTP ' + result.status;
  }

  private async loadQuotes(reset: boolean): Promise<void> {
    if (!this.isLivePost()) {
      this.quoteLoading = false;
      this.quoteStatus = this.text($r('app.string.post_detail_local_only'));
      return;
    }
    if (!this.initializePrivateClient()) {
      this.quoteLoading = false;
      this.quoteStatus = this.text($r('app.string.post_detail_sign_in'));
      return;
    }
    if (reset) {
      this.quoteLoading = true;
      this.quoteStatus = '';
      this.quoteNextToken = '';
    } else if (this.quoteLoadingMore || this.quoteNextToken.length === 0) {
      return;
    } else {
      this.quoteLoadingMore = true;
    }
    const cursor: string = reset ? '' : this.quoteNextToken;
    const result: XPrivateResult = await xPrivateClient.searchTimeline(this.quoteSearchQuery(), cursor,
      ACTIVITY_PAGE_SIZE, 'Latest');
    if (!result.ok) {
      this.quoteStatus = this.errorStatus(result);
      this.quoteLoading = false;
      this.quoteLoadingMore = false;
      return;
    }
    const page: TweetPage | null = XTimelineParser.parse(result.body);
    if (page === null) {
      this.quoteStatus = this.text($r('app.string.post_interactions_load_failed'));
      this.quoteLoading = false;
      this.quoteLoadingMore = false;
      return;
    }
    const verifiedQuotes: Tweet[] = this.filterQuotes(page.tweets);
    this.quotes = reset ? verifiedQuotes : this.mergeTweets(this.quotes, verifiedQuotes);
    this.quoteNextToken = page.nextToken;
    this.quoteStatus = this.quotes.length === 0 ? this.text($r('app.string.post_interactions_no_quotes')) : '';
    this.quoteLoading = false;
    this.quoteLoadingMore = false;
  }

  private async loadReposters(reset: boolean): Promise<void> {
    const current: Tweet | null = this.tweet;
    if (!this.isLivePost() || current === null) {
      this.repostLoading = false;
      this.repostStatus = this.text($r('app.string.post_detail_local_only'));
      return;
    }
    if (!this.initializePrivateClient()) {
      this.repostLoading = false;
      this.repostStatus = this.text($r('app.string.post_detail_sign_in'));
      return;
    }
    if (reset) {
      this.repostLoading = true;
      this.repostStatus = '';
      this.repostNextToken = '';
    } else if (this.repostLoadingMore || this.repostNextToken.length === 0) {
      return;
    } else {
      this.repostLoadingMore = true;
    }
    const cursor: string = reset ? '' : this.repostNextToken;
    const result: XPrivateResult = await xPrivateClient.reposters(current.id, cursor, ACTIVITY_PAGE_SIZE);
    if (!result.ok) {
      this.repostStatus = this.errorStatus(result);
      this.repostLoading = false;
      this.repostLoadingMore = false;
      return;
    }
    const page = XTimelineParser.parseUserList(result.body);
    if (page === null) {
      this.repostStatus = this.text($r('app.string.post_interactions_load_failed'));
      this.repostLoading = false;
      this.repostLoadingMore = false;
      return;
    }
    this.reposters = reset ? page.users : this.mergeUsers(this.reposters, page.users);
    this.repostNextToken = page.nextToken;
    this.repostStatus = this.reposters.length === 0 ? this.text($r('app.string.post_interactions_no_reposts')) : '';
    this.repostLoading = false;
    this.repostLoadingMore = false;
  }

  private loadAll(reset: boolean): void {
    this.loadQuotes(reset);
    this.loadReposters(reset);
  }

  private async refreshActivities(): Promise<void> {
    await this.loadQuotes(true);
    await this.loadReposters(true);
    this.refreshing = false;
  }

  private quoteTabLabel(): string {
    return this.text($r('app.string.post_interactions_quotes')) + ' ' + formatCount(this.quotes.length);
  }

  private repostTabLabel(): string {
    const current: Tweet | null = this.tweet;
    const count: number = current === null ? 0 : current.metrics.repostCount;
    return this.text($r('app.string.post_interactions_reposts')) + ' ' + formatCount(count);
  }

  private openPost(tweet: Tweet, sourceId: string): void {
    const param: PostDetailRouteParam = sourceId.length > 0 ?
      { tweet: tweet, sharedElementId: sourceId } : { tweet: tweet };
    this.pageStack.pushPath({ name: 'PostDetail', param: param });
  }

  private openUser(row: UserRow): void {
    const author: TweetAuthor = {
      id: row.id,
      name: row.name,
      username: row.username,
      avatarColor: row.avatarColor,
      avatarUrl: row.avatarUrl,
      verified: row.verified, verifiedType: row.verifiedType, avatarShape: row.avatarShape
    };
    const param: UserDetailRouteParam = { author: author, posts: [] };
    this.pageStack.pushPath({ name: 'UserDetail', param: param });
  }

  private openQuoteAuthor(opened: Tweet): void {
    const author: UserRow = {
      id: opened.author.id,
      name: opened.author.name,
      username: opened.author.username,
      avatarUrl: opened.author.avatarUrl ?? '',
      avatarColor: opened.author.avatarColor,
      verified: opened.author.verified, verifiedType: opened.author.verifiedType, avatarShape: opened.author.avatarShape,
      bio: '',
      following: false,
      followedBy: false
    };
    this.openUser(author);
  }

  @Builder
  private ActivityTabs(): void {
    AnimatedIconTabs({ items: [
      { key: INTERACTION_TAB_QUOTES, label: this.quoteTabLabel(), icon: $r('sys.symbol.message') },
      { key: INTERACTION_TAB_REPOSTS, label: this.repostTabLabel(), icon: $r('sys.symbol.arrow_2_circlepath') }
    ], selected: this.activeTab === INTERACTION_TAB_QUOTES ? 0 : 1, tabPosition: this.tabPosition, showDivider: true,
      onSelect: (index: number): void => { this.pager.changeIndex(index, true); } })
  }

  @Builder
  private LoadingActivity(): void {
    Column() {
      LoadingProgress().color(this.accentColor).width(22).height(22)
    }
    .width('100%')
    .padding({ top: 56 })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private EmptyActivity(icon: Resource, title: string, detail: string): void {
    Column({ space: 12 }) {
      SymbolGlyph(icon)
        .fontSize(36)
        .fontColor([pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)])
      Text(title).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Title_L'))
        .fontWeight(FontWeight.Bold)
        .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent))
        .textAlign(TextAlign.Center)
      Text(detail).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_L'))
        .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
        .textAlign(TextAlign.Center)
        .maxLines(4)
      Button($r('app.string.common_retry'), { stateEffect: true })
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('app.color.text_on_accent'))
        .backgroundColor(this.accentColor)
        .borderRadius(18)
        .margin({ top: 8 })
        .onClick((): void => {
          if (this.activeTab === INTERACTION_TAB_QUOTES) {
            this.loadQuotes(true);
          } else {
            this.loadReposters(true);
          }
        })
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 72 })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private ReposterRow(row: UserRow): void {
    Row({ space: 12 }) {
      if (row.avatarUrl.length > 0) {
        Image(row.avatarUrl)
          .width(46)
          .height(46)
          .borderRadius(userAvatarRadius(46, 23, row.verifiedType ?? '', row.avatarShape ?? ''))
          .objectFit(ImageFit.Cover)
          .clip(true)
      } else {
        Text(row.name.substring(0, 1).toUpperCase()).fontFamily(this.appFontFamily)
          .width(46)
          .height(46)
          .fontSize($r('sys.float.Subtitle_L'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_on_brand'))
          .backgroundColor(row.avatarColor)
          .borderRadius(userAvatarRadius(46, 23, row.verifiedType ?? '', row.avatarShape ?? ''))
          .textAlign(TextAlign.Center)
      }
      Column({ space: 4 }) {
        Row({ space: 4 }) {
          Text(row.name).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Subtitle_M'))
            .fontWeight(FontWeight.Bold)
            .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (row.verified) {
            SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
              .fontSize(16)
              .fontColor([verificationBadgeColor(row.verifiedType ?? '', this.accentColor)])
          }
        }
        Text('@' + row.username).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M'))
          .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(18)
        .fontColor([pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)])
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .alignItems(VerticalAlign.Center)
    .onClick((): void => {
      this.openUser(row);
    })
  }

  @Builder
  private QuoteContent(): void {
    if (this.quoteLoading && this.quotes.length === 0) {
      this.LoadingActivity()
    } else if (this.quotes.length === 0) {
      this.EmptyActivity($r('sys.symbol.quote'), this.quoteStatus.length > 0 ? this.quoteStatus :
        this.text($r('app.string.post_interactions_no_quotes')),
        this.text($r('app.string.post_interactions_no_quotes_detail')))
    }
  }

  @Builder
  private QuotePost(quote: Tweet): void {
    TweetCard({
      tweet: quote,
      showActions: false,
      onOpen: (opened: Tweet, sourceId: string): void => this.openPost(opened, sourceId),
      onAuthorTapped: (opened: Tweet): void => this.openQuoteAuthor(opened)
    })
  }

  @Builder
  private QuoteFooter(): void {
    if (this.quoteNextToken.length > 0) {
      this.LoadMore(this.quoteLoadingMore)
    }
  }

  @Builder
  private RepostContent(): void {
    if (this.repostLoading && this.reposters.length === 0) {
      this.LoadingActivity()
    } else if (this.reposters.length > 0) {
      ForEach(this.reposters, (row: UserRow): void => {
        this.ReposterRow(row)
      }, (row: UserRow): string => row.id)
      if (this.repostNextToken.length > 0) {
        this.LoadMore(this.repostLoadingMore)
      }
    } else {
      this.EmptyActivity($r('sys.symbol.repeat'), this.repostStatus.length > 0 ? this.repostStatus :
        this.text($r('app.string.post_interactions_no_reposts')),
        this.text($r('app.string.post_interactions_no_reposts_detail')))
    }
  }

  @Builder
  private LoadMore(loading: boolean): void {
    Row({ space: 8 }) {
      if (loading) {
        LoadingProgress().color(this.accentColor).width(18).height(18)
      }
      Text($r('app.string.user_list_load_more')).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_M'))
        .fontColor(pageTextColor($r('app.color.text_accent'), this.pageBackgroundValue, Color.Transparent))
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .padding(16)
    .onClick((): void => {
      if (this.activeTab === INTERACTION_TAB_QUOTES) {
        this.loadQuotes(false);
      } else {
        this.loadReposters(false);
      }
    })
  }

  @Builder
  private ActivityPage(index: number): void {
    if (index === 0) {
      AdaptivePostFeed({ scroller: this.activityScrollers[index],
        itemKeys: this.quotes.map((post: Tweet): string => post.id), feedId: 'quote-post-feed',
        endOffset: this.navigationIndicatorHeight + 28,
        forwardMode: NestedScrollMode.SELF_FIRST, backwardMode: NestedScrollMode.SELF_FIRST,
        header: (): void => this.QuoteContent(), item: (item: number): void => this.QuotePost(this.quotes[item]),
        footer: (): void => this.QuoteFooter(), onLoadMore: (): void => { void this.loadQuotes(false); } })
    } else {
      Scroll(this.activityScrollers[index]) {
        Column({ space: 14 }) { this.RepostContent() }
          .width('100%').padding({ left: 12, right: 12, bottom: this.navigationIndicatorHeight + 28 })
      }.width('100%').height('100%').scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .nestedScroll({ scrollForward: NestedScrollMode.SELF_FIRST, scrollBackward: NestedScrollMode.SELF_FIRST })
        .onReachEnd((): void => { void this.loadReposters(false); })
    }
  }

  @Builder
  private ContentBuilder(): void {
    Column({ space: 14 }) {
      this.ActivityTabs()
      Refresh({ refreshing: $$this.refreshing }) {
      Swiper(this.pager) { this.ActivityPage(0); this.ActivityPage(1) }
        .width('100%').height('100%').index(this.activeTab === INTERACTION_TAB_QUOTES ? 0 : 1)
        .loop(false).indicator(false).cachedCount(1).duration(280).curve(Curve.EaseOut).clip(true)
        .disableSwipe(this.refreshing)
        .onChange((index: number): void => { this.activeTab = index === 0 ? INTERACTION_TAB_QUOTES : INTERACTION_TAB_REPOSTS; })
        .onContentDidScroll((_selected: number, index: number, position: number, _length: number): void => {
          this.tabPosition = ProfileTabMotion.scrollPosition(index, position, 2);
        })
        .onAnimationEnd((index: number): void => { this.tabPosition = index; })
      }.width('100%').layoutWeight(1).onRefreshing((): void => { this.refreshActivities(); })
    }.width('100%').height('100%').padding({ top: this.statusBarHeight + 64, left: 12, right: 12 })
  }

  build(): void {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        appPageBackground()
      this.ContentBuilder();
    
      }.width('100%').height('100%')
    }
    .scale({ x: this.pageMotion.scale, y: this.pageMotion.scale })
    .opacity(this.pageMotion.opacity)
    .systemTransition(pageSystemTransition(this.pageTransitionMode))
    .onReady((context: NavDestinationContext): void => {
      this.pageMotion.attach(context);
      const param: PostInteractionsRouteParam = context.pathInfo?.param as PostInteractionsRouteParam;
      if (param !== undefined && param !== null) {
        this.applyRouteParam(param);
        this.loadAll(true);
      }
    })
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .hideBackButton(false)
    .onBackPressed((): boolean => {
      ResponsiveLayout.closeContentDestination(this.pageStack);
      return true;
    })
    .bindToScrollable(this.activityScrollers)
    .titleBar({
      avoidLayoutSafeArea: true,
      content: { title: { mainTitle: $r('app.string.post_interactions_title') } },
      style: destinationTitleBarStyle(ScrollEffectType.GRADIENT_BLUR, this.themeDisplayMode,
        this.themeDarkSurface, this.titleBarStyleMode)
    })
    .backgroundColor(pageCanvasColor(this.themeDisplayMode, this.themeDarkSurface, this.pageBackgroundValue));
  }
}
