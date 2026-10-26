import { AdaptivePostFeed } from '../components/AdaptivePostFeed';
import { PageSearchField } from '../components/PageSearchField';
import { pageTextColor } from '../utils/ThemeColors';
import { appPageBackground } from '../components/PageBackgroundLayer';
import { pageCanvasColor, postCardSurfaceColor } from '../utils/ThemeColors';
import { STORAGE_KEY_PAGE_TRANSITION_MODE, DEFAULT_PAGE_TRANSITION_MODE } from '../services/PageTransitionSettingsStore';
import { pageSystemTransition, PageTransitionMotion } from '../utils/PageTransition';
import { common } from '@kit.AbilityKit';
import { LengthMetrics } from '@kit.ArkUI';
import { BottomBuilderShowType, HdsNavDestination, HdsNavDestinationTitleMode, ScrollEffectType, TextStyleMode } from '@kit.UIDesignKit';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { STORAGE_KEY_SHOW_SENSITIVE_MEDIA } from '../services/MediaSettingsStore';
import { ProxyAvatar } from '../components/ProxyAvatar';
import { ProxyMediaImage } from '../components/ProxyMediaImage';
import { BrowsingHistoryBatch, BrowsingHistoryEntry, browsingHistoryStore } from '../services/BrowsingHistoryStore';
import { XPrivateResult, xPrivateClient } from '../services/XPrivateClient';
import { XTimelineParser } from '../services/XTimelineParser';
import type { Tweet } from '../models/Tweet';
import { destinationTitleBarStyle, retainedTitleBarBuilder } from '../utils/DestinationTitleBar';
import { cardSurfaceColor } from '../utils/ThemeColors';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';
import type { PostDetailRouteParam } from './PostDetail';

@Builder
export function BrowsingHistoryBuilder(): void { BrowsingHistory(); }

@Component
struct BrowsingHistory {
  @StorageProp('harmonyx.page_background') private pageBackgroundValue: string = '';
  @State private pageMotion: PageTransitionMotion = new PageTransitionMotion();
  @StorageProp(STORAGE_KEY_PAGE_TRANSITION_MODE) private pageTransitionMode: string = DEFAULT_PAGE_TRANSITION_MODE;
  @Consume('pageStack') pageStack: NavPathStack;
  private destinationStack: NavPathStack | null = null;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp('harmonyx.status_bar_height') private statusBarHeight: number = 0;
  @StorageProp('harmonyx.navigation_indicator_height') private bottomInset: number = 0;
  @StorageProp('harmonyx.display_mode') private displayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private darkSurface: string = '';
  @StorageProp('harmonyx.title_bar_style_mode') private titleBarStyleMode: number = 0;
  @StorageProp(STORAGE_KEY_SHOW_SENSITIVE_MEDIA) private showSensitive: boolean = false;
  @State private rows: BrowsingHistoryEntry[] = [];
  @State private visibleRows: BrowsingHistoryEntry[] = [];
  @State private query: string = '';
  @State private loadingIds: string[] = [];
  @State private failedIds: string[] = [];
  @State private historyLoading: boolean = true;
  private loadOffset: number = 0;
  private hasMore: boolean = true;
  private loadTimer: number = -1;
  private previewTimer: number = -1;
  private visibleStart: number = 0;
  private visibleEnd: number = 3;
  private clientReady: boolean = false;
  private scroller: Scroller = new Scroller();
  private previewQueue: string[] = [];
  private attemptedIds: Set<string> = new Set();
  private previewGeneration: number = 0;
  private activeRequests: number = 0;
  private visible: boolean = false;
  private context(): common.UIAbilityContext { return getContext(this) as common.UIAbilityContext; }
  private text(resource: Resource): string { return this.context().resourceManager.getStringSync(resource); }

  private gap(): number {
    return this.getUIContext().px2vp(this.context().resourceManager.getNumber($r('app.float.history_card_gap').id));
  }
  private reload(): void {
    if (this.loadTimer >= 0) { clearTimeout(this.loadTimer); this.loadTimer = -1; }
    this.rows = [];
    this.loadOffset = 0;
    this.hasMore = true;
    this.historyLoading = true;
    this.filter();
    this.scheduleLoad();
  }
  private scheduleLoad(): void {
    if (!this.visible || !this.hasMore || this.loadTimer >= 0) { return; }
    this.historyLoading = true;
    const generation: number = this.previewGeneration;
    this.loadTimer = setTimeout((): void => {
      this.loadTimer = -1;
      if (!this.visible || generation !== this.previewGeneration) { return; }
      const batch: BrowsingHistoryBatch = browsingHistoryStore.loadBatch(this.context(), this.loadOffset);
      this.loadOffset = batch.nextOffset;
      this.hasMore = batch.hasMore;
      this.rows = [...this.rows, ...batch.rows];
      this.filter();
      this.historyLoading = false;
      this.loadVisiblePreviews(this.visibleStart, this.visibleEnd);
      // Search covers the whole archive while yielding between bounded reads.
      // Also skip corrupt/removed records that leave a page empty.
      if (this.hasMore && (this.query.trim().length > 0 || batch.rows.length === 0)) { this.scheduleLoad(); }
    }, 16);
  }
  private applyPreview(row: BrowsingHistoryEntry): void {
    const index: number = this.rows.findIndex((value: BrowsingHistoryEntry): boolean => value.id === row.id);
    if (index < 0) { return; }
    this.rows[index] = row;
    this.filter();
  }
  private shown(): void {
    this.visible = true;
    this.previewGeneration++;
    this.activeRequests = 0;
    this.previewQueue = [];
    this.attemptedIds.clear();
    this.loadingIds = [];
    this.failedIds = [];
    this.clientReady = false;
    this.reload();
  }
  private hidden(): void {
    this.visible = false;
    this.previewGeneration++;
    this.previewQueue = [];
    if (this.loadTimer >= 0) { clearTimeout(this.loadTimer); this.loadTimer = -1; }
    if (this.previewTimer >= 0) { clearTimeout(this.previewTimer); this.previewTimer = -1; }
  }
  aboutToDisappear(): void { this.hidden(); }
  private needsPreview(row: BrowsingHistoryEntry): boolean {
    return row.text.length === 0 && row.previewUrl.length === 0 && row.mediaCount === 0;
  }
  // Limit legacy-preview work to the viewport and a small lookahead. Let the
  // navigation and local cards render before starting network/parsing work.
  private loadVisiblePreviews(start: number, end: number): void {
    if (!this.visible) { return; }
    this.visibleStart = start;
    this.visibleEnd = end;
    const rows: BrowsingHistoryEntry[] = this.visibleRows.slice(Math.max(0, start), end + 4);
    const queued: string[] = [];
    for (const row of rows) {
      if (!this.needsPreview(row) || this.attemptedIds.has(row.id)) { continue; }
      this.attemptedIds.add(row.id);
      this.previewQueue.push(row.id);
      queued.push(row.id);
    }
    if (queued.length > 0) { this.loadingIds = [...this.loadingIds, ...queued]; }
    if (this.previewQueue.length > 0 && this.previewTimer < 0) {
      this.previewTimer = setTimeout((): void => { this.previewTimer = -1; this.drainPreviews(); }, 200);
    }
  }
  private drainPreviews(): void {
    if (!this.visible || this.previewQueue.length === 0) { return; }
    if (!this.clientReady) { xPrivateClient.load(this.context()); this.clientReady = true; }
    while (this.visible && this.activeRequests < 2 && this.previewQueue.length > 0) {
      const id: string | undefined = this.previewQueue.shift();
      if (id === undefined) { return; }
      this.activeRequests++;
      this.fetchPreview(id, this.previewGeneration);
    }
  }
  private async fetchPreview(id: string, generation: number): Promise<void> {
    const session: number = xPrivateClient.sessionGeneration();
    try {
      let result: XPrivateResult = await xPrivateClient.postContent('TweetResultByRestId', id);
      let tweet: Tweet | null = result.ok ? XTimelineParser.parsePostContent(result.body, id) : null;
      if (!this.visible || generation !== this.previewGeneration || session !== xPrivateClient.sessionGeneration()) { return; }
      if (tweet === null && (result.ok || result.status === 400 || result.status === 404)) {
        result = await xPrivateClient.tweetDetail(id);
        tweet = result.ok ? XTimelineParser.parseTweetDetail(result.body, id)?.focal ?? null : null;
      }
      if (!this.visible || generation !== this.previewGeneration || session !== xPrivateClient.sessionGeneration()) { return; }
      if (tweet !== null && tweet.id === id) {
        const row: BrowsingHistoryEntry | null = browsingHistoryStore.enrich(this.context(), tweet);
        if (row !== null) { this.applyPreview(row); }
      } else {
        this.failedIds = [...this.failedIds, id];
        if (result.status === 429 || result.status === 401 || result.status === 403) {
          this.failedIds = [...this.failedIds, ...this.previewQueue];
          this.loadingIds = this.loadingIds.filter((value: string): boolean => this.previewQueue.indexOf(value) < 0);
          this.previewQueue = [];
        }
      }
    } catch (error) {
      if (this.visible && generation === this.previewGeneration) { this.failedIds = [...this.failedIds, id]; }
    } finally {
      if (this.visible && generation === this.previewGeneration) {
        this.loadingIds = this.loadingIds.filter((value: string): boolean => value !== id);
        this.activeRequests--;
        this.drainPreviews();
      }
    }
  }
  private retry(row: BrowsingHistoryEntry): void {
    if (this.loadingIds.indexOf(row.id) >= 0) { return; }
    this.failedIds = this.failedIds.filter((id: string): boolean => id !== row.id);
    this.attemptedIds.delete(row.id);
    const index: number = this.visibleRows.findIndex((value: BrowsingHistoryEntry): boolean => value.id === row.id);
    this.loadVisiblePreviews(index, index);
  }
  private filter(): void {
    const query: string = this.query.trim().toLocaleLowerCase();
    this.visibleRows = query.length === 0 ? this.rows : this.rows.filter((row: BrowsingHistoryEntry): boolean =>
      (row.authorName + ' ' + row.authorHandle + ' ' + row.text).toLocaleLowerCase().indexOf(query) >= 0);
  }
  private day(row: BrowsingHistoryEntry): string { return new Date(row.viewedAt).toLocaleDateString(); }
  private newDay(index: number): boolean {
    // Retained lazy cards can update before the feed removes their old indexes.
    const row: BrowsingHistoryEntry | undefined = this.visibleRows[index];
    if (row === undefined) { return false; }
    const previous: BrowsingHistoryEntry | undefined = this.visibleRows[index - 1];
    return previous === undefined || this.day(row) !== this.day(previous);
  }
  private dayLabel(row: BrowsingHistoryEntry): string {
    return this.day(row) === new Date().toLocaleDateString() ? this.text($r('app.string.spaces_today')) : this.day(row);
  }
  private time(row: BrowsingHistoryEntry): string {
    const date: Date = new Date(row.viewedAt);
    return date.getHours().toString().padStart(2, '0') + ':' + date.getMinutes().toString().padStart(2, '0');
  }
  private video(row: BrowsingHistoryEntry): boolean { return row.mediaType === 'video' || row.mediaType === 'animated_gif'; }
  private authorName(row: BrowsingHistoryEntry): string { return row.authorName || (row.authorHandle ? '@' + row.authorHandle : 'X'); }

  private open(row: BrowsingHistoryEntry): void {
    const tweet: Tweet = { id: row.id, author: { id: '', name: this.authorName(row),
      username: row.authorHandle, avatarUrl: row.avatarUrl, verified: row.verified, avatarColor: '#1D9BF0' },
      text: row.text, createdAt: '', metrics: { replyCount: 0, repostCount: 0, likeCount: 0, viewCount: 0 },
      liked: false, reposted: false };
    const param: PostDetailRouteParam = { tweet: tweet, refreshContent: true };
    (this.destinationStack ?? this.pageStack).pushPath({ name: 'PostDetail', param: param });
  }
  private remove(row: BrowsingHistoryEntry): void {
    if (browsingHistoryStore.remove(this.context(), row.id)) {
      this.rows = this.rows.filter((value: BrowsingHistoryEntry): boolean => value.id !== row.id);
      this.loadOffset = Math.max(0, this.loadOffset - 1);
      this.filter();
      if (this.hasMore && this.visibleRows.length === 0) { this.scheduleLoad(); }
    }
  }
  private clear(): void {
    this.getUIContext().showAlertDialog({ title: $r('app.string.browsing_history_clear'),
      message: $r('app.string.browsing_history_clear_confirm'),
      primaryButton: { value: $r('app.string.compose_cancel'), action: (): void => {} },
      secondaryButton: { value: $r('app.string.browsing_history_clear'), action: (): void => {
        if (browsingHistoryStore.clear(this.context())) { this.reload(); }
      } } });
  }

  @Builder
  private HistoryCard(row: BrowsingHistoryEntry): void {
    Column({ space: 12 }) {
      Row({ space: 10 }) {
        ProxyAvatar({ url: row.avatarUrl, avatarSize: 36, radius: 18,
          fallbackText: this.authorName(row).substring(0, 1), fallbackColor: $r('app.color.brand') })
        Column({ space: 2 }) {
          Row({ space: 4 }) {
            Text(this.authorName(row)).fontFamily(this.appFontFamily).fontSize(15).fontWeight(FontWeight.Bold)
              .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, postCardSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue))).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              .constraintSize({ maxWidth: '85%' }).flexShrink(1)
            if (row.verified) {
              SymbolGlyph($r('sys.symbol.checkmark_circle_fill')).fontSize(14).fontColor([$r('app.color.brand')])
            }
          }.width('100%').justifyContent(FlexAlign.Start)
          if (row.authorHandle.length > 0) {
            Text('@' + row.authorHandle).fontFamily(this.appFontFamily).fontSize(12)
              .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, postCardSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue))).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Text(this.time(row)).fontFamily(this.appFontFamily).fontSize(12).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, postCardSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue)))
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.ellipsis_circle')).fontSize(20).fontColor([pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, postCardSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue))])
        }.width(32).height(36).backgroundColor(Color.Transparent).monopolizeEvents(true)
          .accessibilityText($r('app.string.profile_more'))
          .bindMenu([{ value: this.text($r('app.string.browsing_history_delete')), action: (): void => this.remove(row) }])
      }.width('100%')
      Row({ space: 12 }) {
        if (this.needsPreview(row)) {
          if (this.failedIds.indexOf(row.id) >= 0) {
            Column({ space: 6 }) {
              Text($r('app.string.post_detail_unavailable')).fontFamily(this.appFontFamily).fontSize(14)
                .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, postCardSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue)))
              Button($r('app.string.common_retry')).fontFamily(this.appFontFamily).fontSize(14)
                .backgroundColor(Color.Transparent).fontColor($r('app.color.brand')).monopolizeEvents(true)
                .onClick((): void => this.retry(row))
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          } else {
            Row({ space: 8 }) {
              LoadingProgress().width(18).height(18).color($r('app.color.brand'))
              Text($r('app.string.status_loading')).fontFamily(this.appFontFamily).fontSize(14)
                .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, postCardSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue)))
            }.layoutWeight(1).height(52)
          }
        } else if (row.text.length > 0) {
          Text(row.text).fontFamily(this.appFontFamily).fontSize(16).fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, postCardSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue)))
            .maxLines(4).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
            .lineSpacing(LengthMetrics.vp(4))
        } else {
          Blank().layoutWeight(1)
        }
        if (row.previewUrl.length > 0 && (!row.sensitive || this.showSensitive)) {
          Stack() {
            ProxyMediaImage({ url: row.previewUrl, displayHeight: 84 })
            if (this.video(row)) {
              Stack() {
                SymbolGlyph($r('sys.symbol.play_fill')).fontSize(18).fontColor([Color.White])
              }.width(32).height(32).borderRadius(16).backgroundColor($r('app.color.media_viewer_sheet'))
            }
          }.width(84).height(84).borderRadius(12).clip(true)
        }
      }.width('100%').alignItems(VerticalAlign.Center)
      Row({ space: 6 }) {
        SymbolGlyph(this.video(row) ? $r('sys.symbol.play_fill') : row.mediaCount > 0 ?
          $r('sys.symbol.picture') : $r('sys.symbol.text_alignleft'))
          .fontSize(13).fontColor([pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, postCardSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue))])
        Text(this.video(row) ? $r('app.string.compose_video_label') : row.mediaCount > 0 ?
          $r('app.string.profile_photos_tab') : $r('app.string.profile_detail_posts'))
          .fontFamily(this.appFontFamily).fontSize(12).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, postCardSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue)))
        Blank()
        SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(12).fontColor([pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, postCardSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue))])
      }.width('100%')
    }.width('100%').padding($r('app.float.history_card_padding')).alignItems(HorizontalAlign.Start)
      .id('history-card-' + row.id)
      .backgroundColor(postCardSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue)).borderRadius(20)
      .border({ width: 0.5, color: $r('app.color.divider') }).onClick((): void => this.open(row))
  }

  @Builder
  private SearchField(): void {
    PageSearchField({ value: this.query, placeholder: $r('app.string.browsing_history_search'),
      onValueChange: (value: string): void => {
        this.query = value; this.filter(); this.loadVisiblePreviews(0, 3);
        if (value.trim().length > 0) { this.scheduleLoad(); }
      } })
  }

  @Builder
  private HistoryHeader(): void {
    Column() {
      Row({ space: 6 }) {
        SymbolGlyph($r('sys.symbol.lock')).fontSize(12).fontColor([pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)])
        Text($r('app.string.browsing_history_local')).fontFamily(this.appFontFamily).fontSize(12)
          .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
      }.width('100%').padding({ left: 18, right: 18, top: 8, bottom: 4 })
    }
    if (this.visibleRows.length === 0 && !this.historyLoading) {
      Column() {
        Column({ space: 16 }) {
          SymbolGlyph($r('sys.symbol.clock')).fontSize(48).fontColor([pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)])
          Text(this.query.length > 0 ? $r('app.string.browsing_history_no_results') : $r('app.string.browsing_history_empty'))
            .fontFamily(this.appFontFamily).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
        }.width('100%').padding({ top: 72, bottom: 72 })
      }
    }
  }

  @Builder
  private HistoryFooter(): void {
    if (this.historyLoading) {
      Row({ space: 8 }) {
        LoadingProgress().width(20).height(20).color($r('app.color.brand'))
        Text($r('app.string.status_loading')).fontFamily(this.appFontFamily)
          .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
      }.width('100%').justifyContent(FlexAlign.Center).padding(16)
    }
  }

  @Builder
  private HistoryRow(row: BrowsingHistoryEntry | undefined, index: number): void {
    if (row !== undefined) {
      Column({ space: 10 }) {
        if (this.newDay(index)) {
          Text(this.dayLabel(row)).fontFamily(this.appFontFamily).fontSize(14).fontWeight(FontWeight.Medium)
            .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)).width('100%').padding({ left: 4, top: 10 })
        }
        this.HistoryCard(row)
      }.width('100%').padding({ left: $r('app.float.history_page_inset'), right: $r('app.float.history_page_inset') })
    }
  }

  build(): void {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        appPageBackground()
      AdaptivePostFeed({ scroller: this.scroller, lazyItems: true, singleColumnGap: this.gap(),
        itemKeys: this.visibleRows.map((row: BrowsingHistoryEntry): string => row.id + '-' + row.viewedAt + '-' +
          row.authorName + '-' + row.avatarUrl + '-' + row.verified + '-' + row.text + '-' + row.previewUrl),
        feedId: 'browsing-history-post-feed', startOffset: this.statusBarHeight + 116, endOffset: this.bottomInset + 20,
        header: (): void => this.HistoryHeader(),
        footer: (): void => this.HistoryFooter(),
        item: (index: number): void => this.HistoryRow(this.visibleRows[index], index),
        onLoadMore: (): void => this.scheduleLoad(),
        onVisibleItems: (start: number, end: number): void => this.loadVisiblePreviews(start, end) })
    
      }.width('100%').height('100%')
    }
    .scale({ x: this.pageMotion.scale, y: this.pageMotion.scale })
    .opacity(this.pageMotion.opacity)
    .onReady((context: NavDestinationContext): void => { this.pageMotion.attach(context); this.destinationStack = context.pathStack; })
    .systemTransition(pageSystemTransition(this.pageTransitionMode)).onShown((): void => this.shown()).onHidden((): void => this.hidden())
      .titleMode(HdsNavDestinationTitleMode.MINI).bindToScrollable([this.scroller])
      .titleBar({ avoidLayoutSafeArea: true,
        content: { title: { mainTitle: $r('app.string.browsing_history_title') },
          bottomBuilder: { builder: (): void => this.SearchField(),
            builderContent: retainedTitleBarBuilder((): void => this.SearchField()),
            height: 56, showType: BottomBuilderShowType.DIRECTLY_SHOW },
          menu: { value: [
            { content: { label: $r('app.string.offline_videos_title'), type: TextStyleMode.NORMAL,
              isEnabled: true, action: (): void => { (this.destinationStack ?? this.pageStack).pushPath({ name: 'OfflineVideos' }); } } },
            { content: { label: $r('app.string.browsing_history_clear'), type: TextStyleMode.NORMAL,
              isEnabled: this.rows.length > 0, action: (): void => this.clear() } }
          ] } },
        style: destinationTitleBarStyle(ScrollEffectType.GRADIENT_BLUR, this.displayMode, this.darkSurface, this.titleBarStyleMode) })
      .backgroundColor(pageCanvasColor(this.displayMode, this.darkSurface, this.pageBackgroundValue))
      .onBackPressed((): boolean => false)
  }
}
