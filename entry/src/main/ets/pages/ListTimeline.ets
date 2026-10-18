import { pageTextColor } from '../utils/ThemeColors';
import { pageBackgroundActive } from '../services/PageBackgroundStore';
import { appPageBackground } from '../components/PageBackgroundLayer';
import { pageCanvasColor, pageReadingSurfaceColor } from '../utils/ThemeColors';
import { STORAGE_KEY_PAGE_TRANSITION_MODE, DEFAULT_PAGE_TRANSITION_MODE } from '../services/PageTransitionSettingsStore';
import { pageSystemTransition, PageTransitionMotion } from '../utils/PageTransition';
// Posts of one list. Same shape as the bookmarks destination: a paged tweet
// timeline served by the private session.
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import common from '@ohos.app.ability.common';
import { deviceInfo } from '@kit.BasicServicesKit';
import { uiMaterial } from '@kit.ArkUI';
import { HdsNavDestination, HdsNavDestinationTitleMode, ScrollEffectType,
  HdsNavigationMenuItemOptions, TitleBarStyleOptions } from '@kit.UIDesignKit';
import promptAction from '@ohos.promptAction';
import { ConversationTweetCard as TweetCard } from '../components/ConversationTweetCard';
import { ProxyAvatar } from '../components/ProxyAvatar';
import { ListCover } from '../components/ListCover';
import { AnchoredCover } from '../components/AnchoredCover';
import { FloatingComposeButton } from '../components/FloatingComposeButton';
import type { Tweet, TweetAuthor, ListRow } from '../models/Tweet';
import { formatCount } from '../models/Tweet';
import { XListParser } from '../services/XListParser';
import { copyList, listStateStore } from '../services/ListStateStore';
import { shareList } from '../utils/SharePost';
import type { TweetPage } from '../services/XApiClient';
import { XPrivateClient, XPrivateResult, xPrivateClient } from '../services/XPrivateClient';
import { XTimelineParser } from '../services/XTimelineParser';
import { destinationTitleBarStyle } from '../utils/DestinationTitleBar';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';
import { pageSurfaceColor } from '../utils/ThemeColors';
import type { PostDetailRouteParam } from './PostDetail';
import type { UserDetailRouteParam } from './UserDetail';
import type { ListMembersRouteParam, ListTimelineRouteParam, ListEditorRouteParam } from './Lists';
import type { ReadAloudRouteParam } from './ReadAloud';
import { STORAGE_KEY_READ_ALOUD_ENTRY_ENABLED } from '../services/ReadAloudSettingsStore';
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

const PAGE_SIZE = 20;

@Builder
export function ListTimelineBuilder(): void {
  ListTimeline();
}

@Component
export struct ListTimeline {
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
  @StorageLink(STORAGE_KEY_READ_ALOUD_ENTRY_ENABLED) readAloudEntryEnabled: boolean = false;
  @StorageLink(STORAGE_KEY_FILTER_ONLY_MEDIA) filterOnlyMedia: boolean = false;
  @StorageLink(STORAGE_KEY_FILTER_HIDE_REPOSTS) filterHideReposts: boolean = false;
  @StorageLink(STORAGE_KEY_FILTER_HIDE_REPLIES) filterHideReplies: boolean = false;
  @StorageLink(STORAGE_KEY_FILTER_HIDE_ADS) filterHideAds: boolean = true;
  @StorageLink(STORAGE_KEY_FILTER_KEYWORDS) filterKeywords: string = '';
  @StorageLink(STORAGE_KEY_FILTER_MUTED_USERS) filterMutedUsers: string = '';
  @StorageLink(STORAGE_KEY_FILTER_REVISION) filterRevision: number = 0;
  @State private posts: Tweet[] = [];
  @State private status: string = '';
  @State private loading: boolean = true;
  @State private loadingMore: boolean = false;
  @State private refreshing: boolean = false;
  @State private coverPullOffset: number = 0;
  @State private coverScrollOffset: number = 0;
  @State private readAloudFabMode: string = 'read';
  private listId: string = '';
  @State private title: string = '';
  @State private row: ListRow | null = null;
  @State private actionPending: boolean = false;
  @State private detailStatus: string = '';
  private generation: number = 0;
  private alive: boolean = true;
  private loaded: boolean = false;
  private nextToken: string = '';
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    contentFilterStore.load(context);
    setTimeout((): void => {
      this.readRoute();
      this.load(true);
      this.loadDetail();
    }, 30);
  }

  private readRoute(): void {
    const params: ListTimelineRouteParam[] =
      this.pageStack.getParamByName('ListTimeline') as ListTimelineRouteParam[];
    if (params === undefined || params === null || params.length === 0 ||
      params[params.length - 1] === undefined || params[params.length - 1] === null) {
      return;
    }
    const param: ListTimelineRouteParam = params[params.length - 1];
    this.listId = param.listId;
    this.title = param.title;
    this.row = param.row ?? null;
  }

  aboutToDisappear(): void { this.alive = false; this.generation++; }

  private owned(): boolean { return this.row !== null && this.row.ownerId === xPrivateClient.viewerId(); }

  private share(): void {
    if (this.row !== null && !this.row.isPrivate) {
      shareList(getContext(this) as common.UIAbilityContext, this.listId, this.title, this.row.description);
    } else {
      promptAction.showToast({ message: this.text($r('app.string.list_private_share')) });
    }
  }

  private titleMenuItems(): HdsNavigationMenuItemOptions[] {
    const items: HdsNavigationMenuItemOptions[] = [
      { content: { icon: $r('sys.symbol.arrowshape_turn_up_right'), label: $r('app.string.list_share'),
        isEnabled: this.row !== null && !this.actionPending, action: (): void => this.share() } },
      { content: { icon: this.row !== null && this.row.pinned ? $r('sys.symbol.pin_fill') : $r('sys.symbol.pin'),
        label: this.row !== null && this.row.pinned ? $r('app.string.list_unpin') : $r('app.string.list_pin'),
        isEnabled: this.row !== null && !this.actionPending, action: (): void => { this.pinList(); } } },
      { content: { icon: $r('sys.symbol.person_2'), label: $r('app.string.list_members_action'),
        isEnabled: this.row !== null, action: (): void => this.openMembers() } }
    ];
    if (this.owned()) {
      items.push({ content: { icon: $r('sys.symbol.square_and_pencil'), label: $r('app.string.list_edit'),
        isEnabled: !this.actionPending, action: (): void => this.editList() } });
    }
    return items;
  }

  private coverTitleBarStyle(): TitleBarStyleOptions {
    const style: TitleBarStyleOptions = destinationTitleBarStyle(ScrollEffectType.IMMERSIVE_GRADIENT_BLUR,
      this.themeDisplayMode, this.themeDarkSurface, this.titleBarStyleMode);
    style.originalStyle = {
      backgroundStyle: { backgroundColor: Color.Transparent },
      contentStyle: style.originalStyle?.contentStyle
    };
    return style;
  }

  private async loadDetail(): Promise<void> {
    const result: XPrivateResult = await xPrivateClient.listDetail(this.listId);
    if (!this.alive) { return; }
    const row: ListRow | null = result.ok ? XListParser.detail(result.body, this.listId) : null;
    if (row !== null) {
      if (row.bannerUrl.length === 0 && this.row !== null && result.operation.indexOf('/1.1/') === 0) {
        row.bannerUrl = this.row.bannerUrl; row.pinned = this.row.pinned;
        row.hasCustomBanner = this.row.hasCustomBanner;
        row.customBannerMediaId = this.row.customBannerMediaId;
      }
      this.row = row; this.title = row.name; this.detailStatus = '';
    } else if (this.row === null) { this.detailStatus = this.text($r('app.string.lists_failed')); }
  }

  private editList(): void {
    if (!this.owned() || this.row === null || this.actionPending) { return; }
    const param: ListEditorRouteParam = { row: this.row };
    this.pageStack.pushPath({ name: 'ListEditor', param: param });
  }

  private async followList(): Promise<void> {
    const row: ListRow | null = this.row;
    if (row === null || this.owned() || this.actionPending) { return; }
    this.actionPending = true;
    try {
      const result: XPrivateResult = await xPrivateClient.followList(row.id, !row.following);
      if (result.ok) {
        const updated: ListRow = copyList(row); updated.following = !row.following;
        this.row = updated; listStateStore.update(xPrivateClient.viewerId(), updated);
      } else { promptAction.showToast({ message: this.actionFailure($r('app.string.list_follow'), result) }); }
    } finally { this.actionPending = false; }
  }

  private async pinList(): Promise<void> {
    const row: ListRow | null = this.row;
    if (row === null || this.actionPending) { return; }
    this.actionPending = true;
    try {
      const result: XPrivateResult = await xPrivateClient.pinList(row.id, !row.pinned);
      if (result.ok) {
        const updated: ListRow = copyList(row); updated.pinned = !row.pinned;
        this.row = updated; listStateStore.update(xPrivateClient.viewerId(), updated);
      } else { promptAction.showToast({ message: this.actionFailure($r('app.string.list_pin'), result) }); }
    } finally { this.actionPending = false; }
  }

  private text(resource: Resource): string {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    return context.resourceManager.getStringSync(resource);
  }

  // The API's own message, so "HTTP 400" says which field X rejected.
  private static failureDetail(result: XPrivateResult): string {
    return '\n' + XPrivateClient.explain(result).substring(0, 200);
  }

  private pageMaterial(): uiMaterial.Material | undefined {
    if (pageBackgroundActive(this.pageBackgroundValue) || !deviceInfo.apiAvailable('26.0.0')) {
      return undefined;
    }
    return new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.REGULAR,
      applyShadow: true,
      colorInvert: true
    });
  }

  private async load(reset: boolean): Promise<void> {
    if (!reset && (this.loading || this.loadingMore || this.nextToken.length === 0)) { return; }
    if (this.listId.length === 0) {
      this.loading = false;
      return;
    }
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    xPrivateClient.load(context);
    if (!xPrivateClient.isSignedIn()) {
      this.status = this.text($r('app.string.user_list_sign_in'));
      this.loading = false;
      return;
    }
    if (reset) {
      this.loading = true;
      this.nextToken = '';
      this.status = '';
    } else {
      if (this.loadingMore || this.nextToken.length === 0) {
        return;
      }
      this.loadingMore = true;
    }
    const generation: number = reset ? ++this.generation : this.generation;
    const cursor: string = reset ? '' : this.nextToken;
    const result: XPrivateResult =
      await xPrivateClient.listTimeline(this.listId, reset ? '' : this.nextToken, PAGE_SIZE);
    if (!this.alive || generation !== this.generation) { return; }
    if (!result.ok) {
      this.status = result.status === 401 || result.status === 403 ?
        this.text($r('app.string.private_session_expired')) :
        this.text($r('app.string.lists_failed')) + ' HTTP ' + result.status +
        ListTimeline.failureDetail(result);
      this.loading = false;
      this.loadingMore = false;
      return;
    }
    const page: TweetPage | null = XTimelineParser.parse(result.body);
    if (page === null) {
      this.status = this.text($r('app.string.lists_failed'));
      this.loading = false;
      this.loadingMore = false;
      return;
    }
    if (reset) {
      this.posts = page.tweets;
    } else {
      const combined: Tweet[] = [];
      for (let i: number = 0; i < this.posts.length; i++) {
        combined.push(this.posts[i]);
      }
      for (let i: number = 0; i < page.tweets.length; i++) {
        if (!combined.some((tweet: Tweet): boolean => tweet.id === page.tweets[i].id)) {
          combined.push(page.tweets[i]);
        }
      }
      this.posts = combined;
    }
    this.nextToken = page.nextToken === cursor ? '' : page.nextToken;
    this.status = '';
    this.loaded = true;
    this.loading = false;
    this.loadingMore = false;
  }

  private updateReadAloudFabMode(scrollOffset: number): void {
    if (scrollOffset === 0 || this.refreshing) {
      return;
    }
    this.readAloudFabMode = scrollOffset > 0 ? 'refresh' : 'read';
  }

  private refreshTimeline(): void {
    this.refreshing = true;
    this.load(true).then((): void => {
      this.refreshing = false;
    });
  }

  // The platform's own page transition, as on every other post entry point.
  private openPost(tweet: Tweet): void {
    const param: PostDetailRouteParam = { tweet: tweet };
    this.pageStack.pushPath({ name: 'PostDetail', param: param });
  }

  private openMembers(): void {
    if (this.listId.length === 0) {
      return;
    }
    const param: ListMembersRouteParam = { listId: this.listId, title: this.title, row: this.row ?? undefined };
    this.pageStack.pushPath({ name: 'ListMembers', param: param });
  }

  // List timelines expose the same post actions as Home and Bookmarks.  The
  // card retains the optimistic animation only after X accepts the mutation.
  private async toggleLike(tweet: Tweet, liked: boolean): Promise<boolean> {
    const result: XPrivateResult = await xPrivateClient.like(tweet.id, liked);
    if (!result.ok) {
      promptAction.showToast({
        message: this.actionFailure($r('app.string.action_like'), result),
        duration: 2200
      });
    }
    return result.ok;
  }

  private async toggleRepost(tweet: Tweet, reposted: boolean): Promise<boolean> {
    const result: XPrivateResult = await xPrivateClient.repost(tweet.id, reposted);
    if (!result.ok) {
      promptAction.showToast({
        message: this.actionFailure($r('app.string.action_repost'), result),
        duration: 2200
      });
    }
    return result.ok;
  }

  private actionFailure(action: Resource, result: XPrivateResult): string {
    const label: string = this.text(action);
    if (result.status === 401 || result.status === 403) {
      return this.text($r('app.string.private_session_expired'));
    }
    if (result.isWriteLimit()) {
      return label + this.text($r('app.string.action_write_limit'));
    }
    if (result.status === 404) {
      return label + this.text($r('app.string.action_write_refused'));
    }
    if (result.errorText.length > 0) {
      return label + ' · ' + result.errorText;
    }
    return label + this.text($r('app.string.api_unreachable_suffix'));
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

  private visiblePosts(): Tweet[] {
    return contentFilterStore.filter(this.posts, this.contentFilterSettings());
  }

  // Everything the list has paged in becomes the reading queue.
  private openReadAloud(): void {
    const visible: Tweet[] = this.visiblePosts();
    if (visible.length === 0) {
      return;
    }
    const param: ReadAloudRouteParam = { tweets: visible, startId: visible[0].id };
    this.pageStack.pushPath({ name: 'ReadAloud', param: param });
  }

  @Builder
  private Header(): void {
    Column({ space: 16 }) {
      Column().width('100%').height(this.coverHeight())
      Row({ space: 6 }) {
        Text(this.title).fontFamily(this.appFontFamily).fontSize($r('sys.float.Title_L')).fontWeight(FontWeight.Bold)
          .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent)).maxLines(3).textAlign(TextAlign.Center)
        if (this.row !== null && this.row.isPrivate) {
          SymbolGlyph($r('sys.symbol.lock')).fontSize(20).fontColor([pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)])
        }
      }.padding({ left: 20, right: 20 })
      if (this.row !== null) {
        Row({ space: 6 }) {
          ProxyAvatar({verifiedType: this.row.ownerVerifiedType ?? '', avatarShape: this.row.ownerAvatarShape ?? '',  url: this.row.ownerAvatarUrl, avatarSize: 24, radius: 12,
            fallbackText: this.row.ownerName.substring(0, 1) })
          Text(this.row.ownerName).fontFamily(this.appFontFamily).fontWeight(FontWeight.Bold).fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent))
          Text('@' + this.row.ownerUsername).fontFamily(this.appFontFamily).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).constraintSize({ maxWidth: '55%' })
        }.padding({ left: 20, right: 20 })
        if (this.row.description.length > 0) {
          Text(this.row.description).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent))
            .padding({ left: 24, right: 24 }).textAlign(TextAlign.Center)
        }
        Button(this.owned() ? $r('app.string.list_edit') : this.row.following ?
          $r('app.string.list_following') : $r('app.string.list_follow'))
          .backgroundColor($r('app.color.text_primary')).fontColor($r('app.color.text_on_inverse'))
          .enabled(!this.actionPending).onClick((): void => { if (this.owned()) { this.editList(); } else { this.followList(); } })
        Text(formatCount(this.row.memberCount) + ' ' + this.text($r('app.string.list_members_label')) + ' · ' +
          formatCount(this.row.subscriberCount) + ' ' + this.text($r('app.string.list_followers_label'))).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M')).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
          .onClick((): void => this.openMembers())
      } else if (this.detailStatus.length > 0) {
        Button($r('app.string.common_retry')).backgroundColor(Color.Transparent).fontColor(this.accentColor)
          .onClick((): void => { this.loadDetail(); })
      }
    }.width('100%').padding({ bottom: 24 })
  }

  @Builder
  private Content(): void {
    ListItem() { this.Header() }
    ListItem() {
      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.person_2'))
          .fontSize(20)
          .fontColor([this.accentColor])
        Text($r('app.string.list_members_action')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_L'))
          .fontWeight(FontWeight.Medium)
          .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent))
        Blank()
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(16)
          .fontColor([pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)])
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .onClick((): void => {
        this.openMembers();
      })
    }
    if (this.loading) {
      ListItem() {
        Column() {
          LoadingProgress().color(this.accentColor).width(18).height(18)
        }
        .width('100%')
        .padding({ top: 48 })
      }
    } else if (this.visiblePosts().length === 0) {
      ListItem() {
        Column({ space: 12 }) {
          Text(this.status.length > 0 ? this.status : this.text($r('app.string.list_waiting_posts'))).fontFamily(this.appFontFamily)
            .fontSize(this.status.length > 0 ? $r('sys.float.Body_L') : $r('app.float.list_empty_title_size'))
            .fontWeight(this.status.length > 0 ? FontWeight.Regular : FontWeight.Bold)
            .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent))
            .width('100%')
          if (this.status.length === 0) {
            Text($r('app.string.list_waiting_posts_body')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L'))
              .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)).width('100%')
          }
          if (this.status.length > 0) {
            Button($r('app.string.common_retry'), { stateEffect: true })
              .fontSize($r('sys.float.Body_L'))
              .fontColor($r('app.color.text_on_accent'))
              .backgroundColor(this.accentColor)
              .borderRadius(20)
              .margin({ top: 16 })
              .onClick((): void => {
                this.load(true);
              })
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 28, right: 28, top: 30 })
      }
    } else {
      ForEach(this.visiblePosts(), (tweet: Tweet) => {
        ListItem() {
          TweetCard({
            tweet: tweet,
            onLikeChanged: (t: Tweet, liked: boolean): Promise<boolean> => this.toggleLike(t, liked),
            onRepostChanged: (t: Tweet, reposted: boolean): Promise<boolean> => this.toggleRepost(t, reposted),
            onOpen: (t: Tweet): void => this.openPost(t),
            onAuthorTapped: (t: Tweet): void => {
              const param: UserDetailRouteParam = { author: t.author, posts: [] };
              this.pageStack.pushPath({ name: 'UserDetail', param: param });
            },
            onMentionTapped: (handle: string): void => {
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
          })
        }
      }, (tweet: Tweet) => tweet.id)
      if (this.nextToken.length > 0) {
        ListItem() {
          Row() {
            if (this.loadingMore) {
              LoadingProgress().color(this.accentColor).width(18).height(18)
            }
            Text($r('app.string.lists_load_more')).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_M'))
              .fontColor(pageTextColor($r('app.color.text_accent'), this.pageBackgroundValue, Color.Transparent))
              .margin({ left: 8 })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .padding(16)
          .onClick((): void => {
            this.load(false);
          })
        }
      }
    }
  }

  private coverHeight(): number {
    const heightPx: number = getContext(this).resourceManager.getNumber($r('app.float.list_banner_height').id);
    return this.statusBarHeight + 60 + this.getUIContext().px2vp(heightPx);
  }

  build(): void {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        appPageBackground()
      Stack({ alignContent: Alignment.BottomEnd }) {
        Column() {
          AnchoredCover({ coverHeight: this.coverHeight(), pullOffset: this.coverPullOffset,
            scrollOffset: this.coverScrollOffset }) {
            ListCover({ listId: this.listId, bannerUrl: this.row?.bannerUrl ?? '', wide: true, fillParent: true })
          }
        }.width('100%').height(this.coverHeight()).align(Alignment.Top)
          .position({ x: 0, y: 0 })
        Refresh({ refreshing: $$this.refreshing }) {
          List({ scroller: this.scroller }) {
            this.Content()
          }
          .width('100%')
          .height('100%')
          .scrollBar(BarState.Off)
          .contentStartOffset(0)
          .contentEndOffset(this.navigationIndicatorHeight + 24)
          .onReachEnd((): void => {
            this.load(false);
          })
          .onDidScroll((_scrollOffset: number): void => {
            this.coverScrollOffset = Math.max(0, this.scroller.currentOffset().yOffset);
            this.updateReadAloudFabMode(_scrollOffset);
          })
        }
        .width('100%')
        .height('100%')
        .onRefreshing((): void => {
          this.refreshTimeline();
        })
        .onOffsetChange((offset: number): void => { this.coverPullOffset = offset; })
        .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])

        if (this.readAloudEntryEnabled && this.visiblePosts().length > 0) {
          // The same material button as the feed: it lights the cards it floats
          // over and turns the visible timeline into a reading queue.
          FloatingComposeButton({
            bottomInset: this.navigationIndicatorHeight,
            mode: this.readAloudFabMode,
            refreshing: this.refreshing,
            onRefresh: (): void => {
              this.refreshTimeline();
            },
            onRead: (): void => {
              this.openReadAloud();
            }
          })
        }
      }
    .width('100%')
    .height('100%')
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
    
      }.width('100%').height('100%')
    }
    .scale({ x: this.pageMotion.scale, y: this.pageMotion.scale })
    .opacity(this.pageMotion.opacity)
    .onReady((context: NavDestinationContext): void => { this.pageMotion.attach(context); })
    .systemTransition(pageSystemTransition(this.pageTransitionMode))
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
    .hideBackButton(false)
    .onShown((): void => {
      if (listStateStore.isRemoved(xPrivateClient.viewerId(), this.listId)) { this.pageStack.pop(); return; }
      const updated: ListRow | undefined = listStateStore.get(xPrivateClient.viewerId(), this.listId);
      if (updated !== undefined) { this.row = updated; this.title = updated.name; }
      if (this.loaded) { this.load(true); this.loadDetail(); }
    })
    .onBackPressed((): boolean => {
      ResponsiveLayout.closeContentDestination(this.pageStack);
      return true;
    })
    .bindToScrollable([this.scroller])
    .titleBar({
      avoidLayoutSafeArea: true,
      content: {
        title: { mainTitle: this.title.length > 0 ? this.title : this.text($r('app.string.lists_title')) },
        menu: { value: this.titleMenuItems(), maxCount: 2 }
      },
      style: this.coverTitleBarStyle()
    })
    .backgroundColor(pageCanvasColor(this.themeDisplayMode, this.themeDarkSurface, this.pageBackgroundValue))
    .systemMaterial(pageBackgroundActive(this.pageBackgroundValue) ? undefined : this.pageMaterial());
  }
}
