// Bookmarks destination. Reads the account's bookmark timeline through the
// private interface, which is the only credential that can serve it: the
// official API v2 has no bookmarks endpoint in the free tier.
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import common from '@ohos.app.ability.common';
import { deviceInfo } from '@kit.BasicServicesKit';
import { uiMaterial } from '@kit.ArkUI';
import { HdsNavDestination, HdsNavDestinationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import promptAction from '@ohos.promptAction';
import { ConversationTweetCard as TweetCard } from '../components/ConversationTweetCard';
import { FloatingComposeButton } from '../components/FloatingComposeButton';
import { BookmarkCollection } from '../models/Bookmark';
import type { Tweet, TweetAuthor } from '../models/Tweet';
import type { TweetPage } from '../services/XApiClient';
import { XPrivateClient, XPrivateResult, xPrivateClient } from '../services/XPrivateClient';
import { XBookmarkParser } from '../services/XBookmarkParser';
import { XTimelineParser } from '../services/XTimelineParser';
import { destinationTitleBarStyle } from '../utils/DestinationTitleBar';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';
import { pageSurfaceColor } from '../utils/ThemeColors';
import type { PostDetailRouteParam } from './PostDetail';
import type { UserDetailRouteParam } from './UserDetail';
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
export function BookmarksBuilder(): void {
  BookmarksPage();
}

@Component
export struct BookmarksPage {
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
  @StorageProp('harmonyx.desktop_layout') desktopLayoutEnabled: boolean = false;
  @StorageProp('harmonyx.breakpoint') windowBreakpoint: string = 'sm';
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
  @State private readAloudFabMode: string = 'read';
  @State private collections: BookmarkCollection[] = [];
  @State private collectionsLoading: boolean = false;
  @State private showCollections: boolean = false;
  @State private searchInput: string = '';
  @State private submittedSearch: string = '';
  @State private selectedCollectionId: string = '';
  @State private selectedCollectionName: string = '';
  private nextToken: string = '';
  // Bookmark searches and collection switches can overlap on a slow private
  // session.  Only the newest reset may update the visible feed.
  private feedRequestId: number = 0;
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    contentFilterStore.load(context);
    this.load(true);
    this.loadCollections();
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

  private text(resource: Resource): string {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    return context.resourceManager.getStringSync(resource);
  }

  // The API's own message, so "HTTP 400" says which field X rejected.
  private static failureDetail(result: XPrivateResult): string {
    return '\n' + XPrivateClient.explain(result).substring(0, 200);
  }

  private async load(reset: boolean): Promise<void> {
    if (reset) {
      this.feedRequestId += 1;
    }
    const requestId: number = this.feedRequestId;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    xPrivateClient.load(context);
    if (!xPrivateClient.isSignedIn()) {
      this.status = this.text($r('app.string.bookmarks_sign_in'));
      this.loading = false;
      return;
    }
    if (reset) {
      this.loading = true;
      this.nextToken = '';
      this.posts = [];
      this.status = '';
    } else {
      if (this.loadingMore || this.nextToken.length === 0) {
        return;
      }
      this.loadingMore = true;
    }

    const cursor: string = reset ? '' : this.nextToken;
    const collectionId: string = this.selectedCollectionId;
    const searchQuery: string = this.submittedSearch;
    let result: XPrivateResult;
    if (collectionId.length > 0) {
      result = await xPrivateClient.bookmarkCollectionTimeline(collectionId, cursor, PAGE_SIZE);
    } else if (searchQuery.length > 0) {
      result = await xPrivateClient.bookmarkSearchTimeline(searchQuery, cursor, PAGE_SIZE);
    } else {
      result = await xPrivateClient.bookmarks(cursor, PAGE_SIZE);
    }
    if (requestId !== this.feedRequestId) {
      return;
    }
    if (!result.ok) {
      this.status = result.status === 401 || result.status === 403 ?
        this.text($r('app.string.private_session_expired')) :
        this.text($r('app.string.bookmarks_failed')) + ' HTTP ' + result.status +
        BookmarksPage.failureDetail(result);
      this.loading = false;
      this.loadingMore = false;
      return;
    }
    const page: TweetPage | null = XTimelineParser.parse(result.body);
    if (page === null) {
      this.status = this.text($r('app.string.bookmarks_failed'));
      this.loading = false;
      this.loadingMore = false;
      return;
    }
    for (let i: number = 0; i < page.tweets.length; i++) {
      page.tweets[i].bookmarked = true;
    }
    if (reset) {
      this.posts = page.tweets;
    } else {
      const combined: Tweet[] = [];
      for (let i: number = 0; i < this.posts.length; i++) {
        combined.push(this.posts[i]);
      }
      for (let i: number = 0; i < page.tweets.length; i++) {
        combined.push(page.tweets[i]);
      }
      this.posts = combined;
    }
    this.nextToken = page.nextToken;
    this.status = this.posts.length === 0 ? this.text($r('app.string.bookmarks_empty')) : '';
    this.loading = false;
    this.loadingMore = false;
  }

  private updateReadAloudFabMode(scrollOffset: number): void {
    if (scrollOffset === 0 || this.refreshing) {
      return;
    }
    this.readAloudFabMode = scrollOffset > 0 ? 'refresh' : 'read';
  }

  private refreshBookmarks(): void {
    this.refreshing = true;
    if (this.showCollections) {
      this.loadCollections().then((): void => {
        this.refreshing = false;
      });
      return;
    }
    this.load(true).then((): void => {
      this.refreshing = false;
    });
  }

  private async loadCollections(): Promise<void> {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    xPrivateClient.load(context);
    if (!xPrivateClient.isSignedIn() || this.collectionsLoading) {
      return;
    }
    this.collectionsLoading = true;
    const result: XPrivateResult = await xPrivateClient.bookmarkCollections();
    this.collectionsLoading = false;
    if (!result.ok) {
      return;
    }
    this.collections = XBookmarkParser.parseCollections(result.body);
  }

  private switchToAll(): void {
    this.showCollections = false;
    this.selectedCollectionId = '';
    this.selectedCollectionName = '';
    this.searchInput = '';
    this.submittedSearch = '';
    this.load(true);
  }

  private openCollection(collection: BookmarkCollection): void {
    this.showCollections = false;
    this.selectedCollectionId = collection.id;
    this.selectedCollectionName = collection.name;
    this.submittedSearch = '';
    this.searchInput = '';
    this.load(true);
  }

  private clearCollection(): void {
    this.selectedCollectionId = '';
    this.selectedCollectionName = '';
    this.load(true);
  }

  private submitSearch(value: string): void {
    this.showCollections = false;
    this.selectedCollectionId = '';
    this.selectedCollectionName = '';
    this.submittedSearch = value.trim();
    this.searchInput = value;
    this.load(true);
  }

  private async toggleLike(tweet: Tweet, liked: boolean): Promise<boolean> {
    const result: XPrivateResult = await xPrivateClient.like(tweet.id, liked);
    if (!result.ok) {
      promptAction.showToast({ message: this.actionFailure($r('app.string.action_like'), result), duration: 2200 });
    }
    return result.ok;
  }

  private async toggleRepost(tweet: Tweet, reposted: boolean): Promise<boolean> {
    const result: XPrivateResult = await xPrivateClient.repost(tweet.id, reposted);
    if (!result.ok) {
      promptAction.showToast({ message: this.actionFailure($r('app.string.action_repost'), result), duration: 2200 });
    }
    return result.ok;
  }

  // X returns 200 with a GraphQL error for a refused write, so the payload is
  // what says whether the session died or the account hit its posting limit.
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

  private onBookmarkChanged(tweet: Tweet, bookmarked: boolean): void {
    if (bookmarked) {
      return;
    }
    const remaining: Tweet[] = [];
    for (let i: number = 0; i < this.posts.length; i++) {
      if (this.posts[i].id !== tweet.id) {
        remaining.push(this.posts[i]);
      }
    }
    this.posts = remaining;
    if (this.selectedCollectionId.length > 0) {
      const updatedCollections: BookmarkCollection[] = [];
      for (let i: number = 0; i < this.collections.length; i++) {
        const collection: BookmarkCollection = this.collections[i];
        if (collection.id === this.selectedCollectionId) {
          updatedCollections.push(new BookmarkCollection(collection.id, collection.name,
            Math.max(0, collection.itemCount - 1)));
        } else {
          updatedCollections.push(collection);
        }
      }
      this.collections = updatedCollections;
    }
    if (this.posts.length === 0) {
      this.status = this.text($r('app.string.bookmarks_empty'));
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

  private visiblePosts(): Tweet[] {
    return contentFilterStore.filter(this.posts, this.contentFilterSettings());
  }

  @Builder
  private BookmarkControls(): void {
    ListItem() {
      Column({ space: 10 }) {
        if (!this.showCollections) {
          Search({ value: this.searchInput, placeholder: $r('app.string.bookmarks_search_placeholder') })
            .keyboardAppearance(KeyboardAppearance.IMMERSIVE)
            .width('100%')
            .height(44)
            .onChange((value: string): void => {
              this.searchInput = value;
            })
            .onSubmit((value: string): void => {
              this.submitSearch(value);
            })
        }
        Row({ space: 8 }) {
          Button($r('app.string.bookmarks_all'), { stateEffect: true })
            .layoutWeight(1)
            .fontColor(this.showCollections ? $r('app.color.text_primary') : $r('app.color.text_on_accent'))
            .backgroundColor(this.showCollections ? $r('app.color.bg_field') : this.accentColor)
            .borderRadius(18)
            .onClick((): void => {
              this.switchToAll();
            })
          Button($r('app.string.bookmarks_collections'), { stateEffect: true })
            .layoutWeight(1)
            .fontColor(this.showCollections ? $r('app.color.text_on_accent') : $r('app.color.text_primary'))
            .backgroundColor(this.showCollections ? this.accentColor : $r('app.color.bg_field'))
            .borderRadius(18)
            .onClick((): void => {
              this.showCollections = true;
              this.loadCollections();
            })
        }
        .width('100%')
        if (this.selectedCollectionName.length > 0) {
          Row({ space: 8 }) {
            Text(this.selectedCollectionName).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_M'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_accent'))
              .layoutWeight(1)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Button($r('app.string.bookmarks_collection_clear'), { stateEffect: true })
              .fontSize($r('sys.float.Body_S'))
              .fontColor(this.accentColor)
              .backgroundColor(Color.Transparent)
              .onClick((): void => {
                this.clearCollection();
              })
          }
          .width('100%')
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 10, bottom: 4 })
    }
    if (this.showCollections) {
      if (this.collectionsLoading) {
        ListItem() {
          Row({ space: 8 }) {
            LoadingProgress().width(16).height(16).color(this.accentColor)
            Text($r('app.string.bookmarks_collections_loading')).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_M'))
              .fontColor($r('app.color.text_secondary'))
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .padding(18)
        }
      } else if (this.collections.length === 0) {
        ListItem() {
          Text($r('app.string.bookmarks_collections_empty')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding(24)
        }
      } else {
        ForEach(this.collections, (collection: BookmarkCollection): void => {
          ListItem() {
            Row({ space: 12 }) {
              SymbolGlyph($r('sys.symbol.bookmark'))
                .fontSize(22)
                .fontColor([this.accentColor])
              Column({ space: 3 }) {
                Text(collection.name).fontFamily(this.appFontFamily)
                  .fontSize($r('sys.float.Body_L'))
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                if (collection.itemCount > 0) {
                  Text(collection.itemCount.toString()).fontFamily(this.appFontFamily)
                    .fontSize($r('sys.float.Body_S'))
                    .fontColor($r('app.color.text_secondary'))
                }
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
              SymbolGlyph($r('sys.symbol.chevron_right'))
                .fontSize(18)
                .fontColor([$r('app.color.text_secondary')])
            }
            .width('100%')
            .padding({ left: 20, right: 20, top: 14, bottom: 14 })
            .onClick((): void => {
              this.openCollection(collection);
            })
          }
        }, (collection: BookmarkCollection): string => collection.id)
      }
    }
  }

  // The platform's own page transition, as on every other post entry point.
  private openPost(tweet: Tweet): void {
    const param: PostDetailRouteParam = { tweet: tweet };
    this.pageStack.pushPath({ name: 'PostDetail', param: param });
  }

  private openReadAloud(): void {
    const visible: Tweet[] = this.visiblePosts();
    if (visible.length === 0) {
      return;
    }
    const param: ReadAloudRouteParam = { tweets: visible, startId: visible[0].id };
    this.pageStack.pushPath({ name: 'ReadAloud', param: param });
  }

  @Builder
  private Content(): void {
    if (!this.showCollections && this.loading) {
      Column() {
        LoadingProgress().color(this.accentColor).width(18).height(18)
        Text($r('app.string.bookmarks_loading')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 12 })
      }
      .width('100%')
      .padding({ top: 48 })
    } else if (!this.showCollections && this.visiblePosts().length === 0) {
      Column() {
        Text(this.status.length > 0 ? this.status : this.text($r('app.string.bookmarks_empty'))).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_L'))
          .fontColor($r('app.color.text_secondary'))
          .textAlign(TextAlign.Center)
          .width('100%')
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
      .padding({ left: 24, right: 24, top: 48 })
    } else if (!this.showCollections) {
      ForEach(this.visiblePosts(), (tweet: Tweet) => {
        ListItem() {
          TweetCard({
            tweet: tweet,
            onLikeChanged: (t: Tweet, liked: boolean): Promise<boolean> => this.toggleLike(t, liked),
            onRepostChanged: (t: Tweet, reposted: boolean): Promise<boolean> => this.toggleRepost(t, reposted),
            onBookmarkChanged: (t: Tweet, bookmarked: boolean): void =>
              this.onBookmarkChanged(t, bookmarked),
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
            Text($r('app.string.bookmarks_load_more')).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_M'))
              .fontColor($r('app.color.text_accent'))
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

  build(): void {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.BottomEnd }) {
        Refresh({ refreshing: $$this.refreshing }) {
          List({ scroller: this.scroller }) {
            this.BookmarkControls()
            this.Content()
          }
          .width('100%')
          .height('100%')
          .scrollBar(BarState.Off)
          .contentStartOffset(this.desktopLayoutEnabled && ResponsiveLayout.isLarge(this.windowBreakpoint) ?
            0 : this.statusBarHeight + 60)
          .clip(!(this.desktopLayoutEnabled && ResponsiveLayout.isLarge(this.windowBreakpoint)))
          .cachedCount(8, this.desktopLayoutEnabled && ResponsiveLayout.isLarge(this.windowBreakpoint))
          .contentEndOffset(this.navigationIndicatorHeight + 24)
          .onReachEnd((): void => {
            if (!this.showCollections) {
              this.load(false);
            }
          })
          .onDidScroll((_scrollOffset: number): void => {
            this.updateReadAloudFabMode(_scrollOffset);
          })
        }
        .width('100%')
          .height('100%')
          .clip(!(this.desktopLayoutEnabled && ResponsiveLayout.isLarge(this.windowBreakpoint)))
          .onRefreshing((): void => {
            this.refreshBookmarks();
          })

        if (!this.showCollections && this.readAloudEntryEnabled && this.visiblePosts().length > 0) {
          FloatingComposeButton({
            bottomInset: this.navigationIndicatorHeight,
            mode: this.readAloudFabMode,
            refreshing: this.refreshing,
            onRefresh: (): void => {
              this.refreshBookmarks();
            },
            onRead: (): void => {
              this.openReadAloud();
            }
          })
        }
      }
      .width('100%')
      .height('100%')
      .clip(!(this.desktopLayoutEnabled && ResponsiveLayout.isLarge(this.windowBreakpoint)))
    }
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .hideBackButton(false)
    .onBackPressed((): boolean => {
      ResponsiveLayout.closeContentDestination(this.pageStack);
      return true;
    })
    .bindToScrollable([this.scroller])
    .titleBar({
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: this.desktopLayoutEnabled && ResponsiveLayout.isLarge(this.windowBreakpoint),
      content: { title: { mainTitle: $r('app.string.bookmarks_title') } },
      style: destinationTitleBarStyle(ScrollEffectType.IMMERSIVE_GRADIENT_BLUR,
        this.themeDisplayMode, this.themeDarkSurface, this.titleBarStyleMode)
    })
    .backgroundColor(pageSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
    .systemMaterial(this.pageMaterial());
  }
}
