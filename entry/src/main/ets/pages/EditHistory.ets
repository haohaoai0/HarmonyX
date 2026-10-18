import { AdaptivePostGrid } from '../components/AdaptivePostGrid';
import { pageTextColor } from '../utils/ThemeColors';
import { appPageBackground } from '../components/PageBackgroundLayer';
import { pageCanvasColor, pageReadingSurfaceColor } from '../utils/ThemeColors';
import { STORAGE_KEY_PAGE_TRANSITION_MODE, DEFAULT_PAGE_TRANSITION_MODE } from '../services/PageTransitionSettingsStore';
import { pageSystemTransition, PageTransitionMotion } from '../utils/PageTransition';
// Revision timeline for an editable X post.  X returns each retained version
// in a regular timeline envelope, so this page uses the same parser and card
// component as the rest of the app instead of duplicating result handling.
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import {
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  ScrollEffectType
} from '@kit.UIDesignKit';
import common from '@ohos.app.ability.common';
import { TweetCard } from '../components/TweetCard';
import { XPrivateResult, xPrivateClient } from '../services/XPrivateClient';
import { XTimelineParser } from '../services/XTimelineParser';
import type { TweetPage } from '../services/XApiClient';
import type { Tweet } from '../models/Tweet';
import { destinationTitleBarStyle } from '../utils/DestinationTitleBar';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';
import { pageSurfaceColor } from '../utils/ThemeColors';

const EDIT_HISTORY_PAGE_SIZE: number = 30;

export interface EditHistoryRouteParam {
  tweet: Tweet;
}

@Builder
export function EditHistoryBuilder(): void {
  EditHistoryPage();
}

@Component
export struct EditHistoryPage {
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
  @State private revisions: Tweet[] = [];
  @State private loading: boolean = true;
  @State private loadingMore: boolean = false;
  @State private status: string = '';
  @State private refreshing: boolean = false;
  private nextToken: string = '';
  private scroller: Scroller = new Scroller();

  private text(resource: Resource): string {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    return context.resourceManager.getStringSync(resource);
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

  // The history endpoint uses a regular timeline cursor. Keep the version key
  // broader than only tweet id: edit-history entries can share an id in some
  // response shapes while still representing distinct text revisions.
  private appendRevisions(incoming: Tweet[]): void {
    const combined: Tweet[] = [];
    const seen: Map<string, boolean> = new Map();
    for (let i: number = 0; i < this.revisions.length; i++) {
      const existing: Tweet = this.revisions[i];
      const existingKey: string = existing.id + '|' + existing.createdAt + '|' + existing.text;
      if (!seen.has(existingKey)) {
        seen.set(existingKey, true);
        combined.push(existing);
      }
    }
    for (let i: number = 0; i < incoming.length; i++) {
      const revision: Tweet = incoming[i];
      const revisionKey: string = revision.id + '|' + revision.createdAt + '|' + revision.text;
      if (!seen.has(revisionKey)) {
        seen.set(revisionKey, true);
        combined.push(revision);
      }
    }
    this.revisions = combined;
  }

  private async loadHistory(reset: boolean): Promise<void> {
    if (!this.isLivePost()) {
      this.loading = false;
      this.loadingMore = false;
      this.refreshing = false;
      this.status = this.text($r('app.string.post_detail_local_only'));
      return;
    }
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    xPrivateClient.load(context);
    if (!xPrivateClient.isSignedIn()) {
      this.loading = false;
      this.loadingMore = false;
      this.refreshing = false;
      this.status = this.text($r('app.string.post_detail_sign_in'));
      return;
    }
    const current: Tweet | null = this.tweet;
    if (current === null) {
      return;
    }
    if (reset) {
      this.loading = true;
      this.loadingMore = false;
      this.nextToken = '';
      this.revisions = [];
      this.status = '';
    } else {
      if (this.loadingMore || this.nextToken.length === 0) {
        return;
      }
      this.loadingMore = true;
      this.status = '';
    }
    const cursor: string = reset ? '' : this.nextToken;
    const result: XPrivateResult = await xPrivateClient.editHistory(current.id, cursor, EDIT_HISTORY_PAGE_SIZE);
    this.loading = false;
    this.loadingMore = false;
    this.refreshing = false;
    if (!result.ok) {
      this.status = this.text($r('app.string.post_edit_history_load_failed')) +
        ' · HTTP ' + result.status.toString();
      return;
    }
    const page: TweetPage | null = XTimelineParser.parse(result.body);
    if (page === null || page.tweets.length === 0) {
      if (reset) {
        this.revisions = [];
        this.status = this.text($r('app.string.post_edit_history_empty'));
      }
      // An empty continuation never adds a useful card. Stop here even if an
      // upstream response carried a stale cursor, otherwise reaching bottom
      // would keep making the same request.
      this.nextToken = '';
      return;
    }
    if (reset) {
      this.revisions = page.tweets;
    } else {
      this.appendRevisions(page.tweets);
    }
    this.nextToken = page.nextToken === cursor ? '' : page.nextToken;
    this.status = '';
  }

  @Builder
  private Content(): void {
    Refresh({ refreshing: $$this.refreshing }) {
      Scroll(this.scroller) {
        Column({ space: 10 }) {
          if (this.loading) {
            LoadingProgress().width(28).height(28).color(this.accentColor).margin({ top: 56 })
          } else if (this.revisions.length > 0) {
            Text($r('app.string.post_edit_history_hint')).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_M'))
              .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
              .width('100%')
              .padding({ left: 16, right: 16, top: 8, bottom: 2 })
            AdaptivePostGrid({ itemKeys: this.revisions.map((post: Tweet): string => post.id),
        item: (index: number): void => this.RevisionCard(this.revisions[index]) })
            if (this.status.length > 0) {
              Text(this.status).fontFamily(this.appFontFamily)
                .fontSize($r('sys.float.Body_S'))
                .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
                .width('100%')
                .textAlign(TextAlign.Center)
                .padding({ left: 24, right: 24, top: 8, bottom: 4 })
            }
            if (this.nextToken.length > 0) {
              Row() {
                if (this.loadingMore) {
                  LoadingProgress().width(18).height(18).color(this.accentColor)
                }
                Text(this.loadingMore ? $r('app.string.status_loading') :
                  $r('app.string.timeline_load_more')).fontFamily(this.appFontFamily)
                  .fontSize($r('sys.float.Body_M'))
                  .fontColor(pageTextColor($r('app.color.text_accent'), this.pageBackgroundValue, Color.Transparent))
                  .margin({ left: this.loadingMore ? 8 : 0 })
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)
              .padding(16)
              .onClick((): void => {
                this.loadHistory(false);
              })
            }
          } else {
            Text(this.status).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_M'))
              .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ left: 24, right: 24, top: 64 })
          }
        }
        .width('100%')
        .padding({
          top: this.statusBarHeight + 64,
          bottom: this.navigationIndicatorHeight + 28
        })
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .onReachEnd((): void => {
        this.loadHistory(false);
      })
    }
    .width('100%')
    .height('100%')
    .onRefreshing((): void => {
      this.refreshing = true;
      this.loadHistory(true);
    })
  }

  @Builder
  private RevisionCard(revision: Tweet): void {
    TweetCard({
      tweet: revision,
      showActions: false
    })
  }

  build(): void {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        appPageBackground()
      this.Content();
    
      }.width('100%').height('100%')
    }
    .scale({ x: this.pageMotion.scale, y: this.pageMotion.scale })
    .opacity(this.pageMotion.opacity)
    .systemTransition(pageSystemTransition(this.pageTransitionMode))
    .onReady((context: NavDestinationContext): void => {
      this.pageMotion.attach(context);
      const param: EditHistoryRouteParam = context.pathInfo?.param as EditHistoryRouteParam;
      if (param !== undefined && param !== null) {
        this.tweet = param.tweet;
        this.loadHistory(true);
      }
    })
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .hideBackButton(false)
    .onBackPressed((): boolean => {
      ResponsiveLayout.closeContentDestination(this.pageStack);
      return true;
    })
    .bindToScrollable([this.scroller])
    .titleBar({
      avoidLayoutSafeArea: true,
      content: { title: { mainTitle: $r('app.string.post_edit_history_title') } },
      style: destinationTitleBarStyle(ScrollEffectType.GRADIENT_BLUR, this.themeDisplayMode,
        this.themeDarkSurface, this.titleBarStyleMode)
    })
    .backgroundColor(pageCanvasColor(this.themeDisplayMode, this.themeDarkSurface, this.pageBackgroundValue));
  }
}
