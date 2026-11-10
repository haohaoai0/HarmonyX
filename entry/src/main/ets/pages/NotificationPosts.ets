import { AdaptivePostFeed } from '../components/AdaptivePostFeed';
import { pageTextColor } from '../utils/ThemeColors';
import { appPageBackground } from '../components/PageBackgroundLayer';
import { pageCanvasColor, pageReadingSurfaceColor } from '../utils/ThemeColors';
import { STORAGE_KEY_PAGE_TRANSITION_MODE, DEFAULT_PAGE_TRANSITION_MODE } from '../services/PageTransitionSettingsStore';
import { pageSystemTransition, PageTransitionMotion } from '../utils/PageTransition';
import { common } from '@kit.AbilityKit';
import { HdsNavDestination, HdsNavDestinationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { TweetCard } from '../components/TweetCard';
import type { AppNotification, MediaAttachment, Tweet } from '../models/Tweet';
import { xPrivateClient, XPrivateResult } from '../services/XPrivateClient';
import { XNotificationParser } from '../services/XNotificationParser';
import { XTimelineParser } from '../services/XTimelineParser';
import hilog from '@ohos.hilog';
import { destinationTitleBarStyle } from '../utils/DestinationTitleBar';
import { pageSurfaceColor } from '../utils/ThemeColors';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';
import { DesktopLayout } from '../utils/DesktopLayout';
import {
  STORAGE_KEY_TIMELINE_COLUMNS,
  TIMELINE_COLUMNS_AUTO_TWO,
  TIMELINE_COLUMNS_TWO
} from '../services/TimelineSettingsStore';
import type { PostDetailRouteParam } from './PostDetail';
import type { UserDetailRouteParam } from './UserDetail';
import type { VideoFeedRouteParam } from './VideoFeedViewer';
import { pendingMediaViewerSource } from '../utils/MediaViewerMotion';
import { videoPlayerHandoff } from '../services/VideoPlayerHandoff';

export interface NotificationPostsRouteParam {
  notification: AppNotification;
  posts: Tweet[];
}

@Builder
export function NotificationPostsBuilder(): void { NotificationPosts(); }

@Component
struct NotificationPosts {
  @StorageProp('harmonyx.page_background') private pageBackgroundValue: string = '';
  @State private pageMotion: PageTransitionMotion = new PageTransitionMotion();
  @StorageProp(STORAGE_KEY_PAGE_TRANSITION_MODE) private pageTransitionMode: string = DEFAULT_PAGE_TRANSITION_MODE;
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp('harmonyx.status_bar_height') private statusBarHeight: number = 0;
  @StorageProp('harmonyx.navigation_indicator_height') private bottomInset: number = 0;
  @StorageProp('harmonyx.display_mode') private themeDisplayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private themeDarkSurface: string = '';
  @StorageProp('harmonyx.title_bar_style_mode') private titleBarStyleMode: number = 0;
  @StorageProp('harmonyx.desktop_layout') private desktopLayoutEnabled: boolean = false;
  @StorageProp('harmonyx.breakpoint') private windowBreakpoint: string = 'sm';
  @StorageProp(STORAGE_KEY_TIMELINE_COLUMNS) private timelineColumnsMode: number = 0;
  @State private posts: Tweet[] = [];
  @State private refreshing: boolean = false;
  @State private status: string = '';
  private notificationId: string = '';
  private notification: AppNotification | null = null;
  private cursor: string = '';
  private generation: number = 0;
  private alive: boolean = true;
  private requesting: boolean = false;
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.alive = true;
    setTimeout((): void => {
      if (!this.alive || this.notification !== null) { return; }
      const params: NotificationPostsRouteParam[] = this.pageStack.getParamByName('NotificationPosts') as NotificationPostsRouteParam[];
      if (params !== undefined && params.length > 0) { this.applyRoute(params[params.length - 1]); }
    }, 30);
  }
  aboutToDisappear(): void { this.alive = false; }

  private sameAccount(): boolean {
    if (this.generation === xPrivateClient.sessionGeneration()) { return true; }
    this.posts = [];
    return false;
  }

  private openPost(tweet: Tweet, sharedElementId: string = ''): void {
    if (!this.sameAccount()) { return; }
    const param: PostDetailRouteParam = { tweet: tweet, sharedElementId: sharedElementId };
    this.pageStack.pushPath({ name: 'PostDetail', param: param });
  }

  private openAuthor(tweet: Tweet): void {
    if (!this.sameAccount()) { return; }
    const param: UserDetailRouteParam = { author: tweet.author, posts: [] };
    this.pageStack.pushPath({ name: 'UserDetail', param: param });
  }

  private openVideo(tweet: Tweet, media: MediaAttachment): void {
    if (!this.sameAccount()) { return; }
    const param: VideoFeedRouteParam = { tweets: this.posts,
      source: pendingMediaViewerSource.take(media.id),
      index: this.posts.findIndex((post: Tweet): boolean => post.id === tweet.id),
      startPlaying: true, startMediaId: media.id,
      onLike: async (post: Tweet, liked: boolean): Promise<boolean> => (await xPrivateClient.like(post.id, liked)).ok,
      onRepost: async (post: Tweet, reposted: boolean): Promise<boolean> => (await xPrivateClient.repost(post.id, reposted)).ok,
      onReply: (post: Tweet): void => this.openPost(post) };
    videoPlayerHandoff.request(media.id);
    this.pageStack.pushPath({ name: 'VideoFeedViewer', param: param }, param.source === undefined);
  }

  private applyRoute(param: NotificationPostsRouteParam | undefined): void {
    if (param === undefined || param === null || param.notification === undefined) { return; }
    this.notification = param.notification;
    this.notificationId = param.notification.id;
    this.posts = (param.posts ?? param.notification.targetPosts ?? []).slice();
    this.generation = xPrivateClient.sessionGeneration();
    hilog.info(0xFF00, 'HarmonyX-Notify', 'group route received posts=%{public}d bell=%{public}s',
      this.posts.length, String(param.notification.kind === 'alert'));
    if (this.posts.length === 0 || param.notification.kind === 'alert') { void this.refreshPosts(); }
  }

  private async refreshPosts(append: boolean = false): Promise<void> {
    if (this.requesting || !this.sameAccount()) { return; }
    this.requesting = true;
    this.refreshing = true;
    const generation: number = xPrivateClient.sessionGeneration();
    try {
      const bell: boolean = this.notification?.kind === 'alert';
      const result: XPrivateResult = bell ? await xPrivateClient.notificationDeviceFollow(append ? this.cursor : '', 40) :
        await xPrivateClient.notifications('', 80);
      if (!this.alive || generation !== xPrivateClient.sessionGeneration()) { return; }
      if (bell) {
        const page = result.ok ? XTimelineParser.parseDeviceFollow(result.body) : null;
        hilog.info(0xFF00, 'HarmonyX-Notify', 'group timeline HTTP=%{public}d posts=%{public}d more=%{public}s',
          result.status, page?.tweets.length ?? 0, String((page?.nextToken ?? '').length > 0));
        if (page !== null) {
          this.posts = append ? this.posts.concat(page.tweets.filter((post: Tweet): boolean =>
            !this.posts.some((old: Tweet): boolean => old.id === post.id))) : page.tweets;
          this.cursor = append && page.nextToken === this.cursor ? '' : page.nextToken;
          this.status = '';
        } else {
          const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
          this.status = context.resourceManager.getStringSync($r('app.string.profile_setting_failed')) +
            ' · ' + (result.errorText || 'HTTP ' + result.status.toString());
        }
        return;
      }
      const page = result.ok ? XNotificationParser.parsePage(result.body) : null;
      const row: AppNotification | undefined = page?.items.find((item: AppNotification): boolean => item.id === this.notificationId);
      if (row !== undefined && (row.targetPosts ?? []).length > 0) {
        this.posts = row.targetPosts ?? [];
        this.status = '';
      } else if (!result.ok || page === null) {
        const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
        this.status = context.resourceManager.getStringSync($r('app.string.profile_setting_failed')) +
          ' · HTTP ' + result.status.toString();
      }
    } catch (error) {
      if (this.alive && generation === xPrivateClient.sessionGeneration()) {
        const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
        this.status = context.resourceManager.getStringSync($r('app.string.profile_setting_failed'));
      }
    } finally { this.requesting = false; this.refreshing = false; }
  }

  @Builder
  private FeedHeader(): void {
    if (this.useListFeed()) {
      Column().width('100%').height(this.statusBarHeight + 56)
    }
    if (this.status.length > 0 || this.posts.length === 0) {
      Column() {
        Text(this.status.length > 0 ? this.status : $r('app.string.notification_posts_empty'))
          .fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
          .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)).width('100%').padding(20)
      }
    }
  }

  private isDesktopLayout(): boolean {
    return DesktopLayout.active(this.desktopLayoutEnabled, this.windowBreakpoint);
  }

  private useTimelineWaterFlow(): boolean {
    return this.isDesktopLayout() || ResponsiveLayout.isLarge(this.windowBreakpoint) ||
      this.timelineColumnsMode === TIMELINE_COLUMNS_TWO ||
      this.timelineColumnsMode === TIMELINE_COLUMNS_AUTO_TWO;
  }

  private useListFeed(): boolean {
    return !this.useTimelineWaterFlow();
  }

  private feedStartOffset(): number {
    if (this.useListFeed() || this.isDesktopLayout()) {
      return 0;
    }
    return this.statusBarHeight + 56;
  }

  @Builder
  private FeedPost(tweet: Tweet): void {
    TweetCard({ tweet: tweet, videoFeedEnabled: true,
      onOpen: (post: Tweet, id: string): void => this.openPost(post, id),
      onAuthorTapped: (post: Tweet): void => this.openAuthor(post),
      onReply: (post: Tweet): void => this.openPost(post),
      onVideoOpen: (post: Tweet, media: MediaAttachment): void => this.openVideo(post, media),
      onLikeChanged: async (post: Tweet, liked: boolean): Promise<boolean> => {
        return (await xPrivateClient.like(post.id, liked)).ok;
      },
      onRepostChanged: async (post: Tweet, reposted: boolean): Promise<boolean> => {
        return (await xPrivateClient.repost(post.id, reposted)).ok;
      }
    })
  }

  @Builder
  private FeedFooter(): void {
    if (this.cursor.length > 0) {
      Column() { Button($r('app.string.timeline_load_more')).width('100%').enabled(!this.refreshing)
        .onClick((): void => { void this.refreshPosts(true); }) }
    }
  }

  build(): void {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        appPageBackground()
      Refresh({ refreshing: $$this.refreshing }) {
        AdaptivePostFeed({ scroller: this.scroller, itemKeys: this.posts.map((post: Tweet): string => post.id),
          useList: this.useListFeed(), lazyItems: true,
          feedId: 'notification-post-feed', startOffset: this.feedStartOffset(), endOffset: this.bottomInset + 12,
          forwardMode: NestedScrollMode.SELF_FIRST,
          backwardMode: NestedScrollMode.SELF_FIRST,
          clipContent: !this.isDesktopLayout(),
          header: (): void => this.FeedHeader(), item: (index: number): void => this.FeedPost(this.posts[index]),
          footer: (): void => this.FeedFooter() })
      }.width('100%').height('100%').onRefreshing((): void => {
        void this.refreshPosts();
      })
    
      }.width('100%').height('100%')
    }
    .scale({ x: this.pageMotion.scale, y: this.pageMotion.scale })
    .opacity(this.pageMotion.opacity)
    .systemTransition(pageSystemTransition(this.pageTransitionMode))
    .onReady((context: NavDestinationContext): void => {
      this.pageMotion.attach(context);
      const param: NotificationPostsRouteParam = context.pathInfo?.param as NotificationPostsRouteParam;
      if (param === undefined || param === null) { return; }
      this.applyRoute(param);
    })
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .bindToScrollable([this.scroller])
    .onShown((): void => { this.sameAccount(); })
    .titleBar({ avoidLayoutSafeArea: true,
      content: { title: { mainTitle: $r('app.string.notification_posts_title') } },
      style: destinationTitleBarStyle(ScrollEffectType.GRADIENT_BLUR, this.themeDisplayMode,
        this.themeDarkSurface, this.titleBarStyleMode) })
    .backgroundColor(pageCanvasColor(this.themeDisplayMode, this.themeDarkSurface, this.pageBackgroundValue))
    .onBackPressed((): boolean => { ResponsiveLayout.closeContentDestination(this.pageStack); return true; })
  }
}
