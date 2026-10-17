import { common } from '@kit.AbilityKit';
import { LengthMetrics } from '@kit.ArkUI';
import { BottomBuilderShowType, HdsNavDestination, HdsNavDestinationTitleMode, ScrollEffectType, TextStyleMode } from '@kit.UIDesignKit';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { STORAGE_KEY_SHOW_SENSITIVE_MEDIA } from '../services/MediaSettingsStore';
import { ProxyAvatar } from '../components/ProxyAvatar';
import { ProxyMediaImage } from '../components/ProxyMediaImage';
import { BrowsingHistoryEntry, browsingHistoryStore } from '../services/BrowsingHistoryStore';
import { XPrivateResult, xPrivateClient } from '../services/XPrivateClient';
import { XTimelineParser } from '../services/XTimelineParser';
import type { Tweet } from '../models/Tweet';
import { destinationTitleBarStyle, retainedTitleBarBuilder, TitleBarControlMaterialCache } from '../utils/DestinationTitleBar';
import { SystemMaterialUtil } from '../utils/SystemMaterial';
import { cardSurfaceColor, fieldSurfaceColor, pageSurfaceColor } from '../utils/ThemeColors';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';
import type { PostDetailRouteParam } from './PostDetail';

@Builder
export function BrowsingHistoryBuilder(): void { BrowsingHistory(); }

@Component
struct BrowsingHistory {
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp('harmonyx.status_bar_height') private statusBarHeight: number = 0;
  @StorageProp('harmonyx.navigation_indicator_height') private bottomInset: number = 0;
  @StorageProp('harmonyx.display_mode') private displayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private darkSurface: string = '';
  @StorageProp('harmonyx.title_bar_style_mode') private titleBarStyleMode: number = 0;
  @StorageProp(STORAGE_KEY_SHOW_SENSITIVE_MEDIA) private showSensitive: boolean = false;
  @StorageProp('harmonyx.accent_color') private accentColor: string = '#007DFF';
  @State private rows: BrowsingHistoryEntry[] = [];
  @State private visibleRows: BrowsingHistoryEntry[] = [];
  @State private query: string = '';
  @State private loadingIds: string[] = [];
  @State private failedIds: string[] = [];
  private scroller: Scroller = new Scroller();
  private previewQueue: string[] = [];
  private attemptedIds: Set<string> = new Set();
  private previewGeneration: number = 0;
  private activeRequests: number = 0;
  private visible: boolean = false;
  private searchMaterial: TitleBarControlMaterialCache = new TitleBarControlMaterialCache();
  private context(): common.UIAbilityContext { return getContext(this) as common.UIAbilityContext; }
  private text(resource: Resource): string { return this.context().resourceManager.getStringSync(resource); }

  private reload(): void { this.rows = browsingHistoryStore.load(this.context()); this.filter(); }
  private shown(): void {
    this.visible = true;
    this.previewGeneration++;
    this.activeRequests = 0;
    this.previewQueue = [];
    this.attemptedIds.clear();
    this.loadingIds = [];
    this.failedIds = [];
    xPrivateClient.load(this.context());
    this.reload();
    this.loadVisiblePreviews(0, 19);
  }
  private hidden(): void {
    this.visible = false;
    this.previewGeneration++;
    this.previewQueue = [];
  }
  private needsPreview(row: BrowsingHistoryEntry): boolean {
    return row.text.length === 0 && row.previewUrl.length === 0 && row.mediaCount === 0;
  }
  // Old link-only records are filled on entry; subsequent rows are prefetched
  // as the reader scrolls. Two requests at a time avoid flooding X with a long history.
  private loadVisiblePreviews(start: number, end: number): void {
    if (!this.visible) { return; }
    const rows: BrowsingHistoryEntry[] = this.visibleRows.slice(Math.max(0, start), end + 9);
    for (const row of rows) {
      if (!this.needsPreview(row) || this.attemptedIds.has(row.id)) { continue; }
      this.attemptedIds.add(row.id);
      this.previewQueue.push(row.id);
      this.loadingIds = [...this.loadingIds, row.id];
    }
    this.drainPreviews();
  }
  private drainPreviews(): void {
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
        browsingHistoryStore.enrich(this.context(), tweet);
        this.reload();
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
    return index === 0 || this.day(this.visibleRows[index]) !== this.day(this.visibleRows[index - 1]);
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
    this.pageStack.pushPath({ name: 'PostDetail', param: param });
  }
  private remove(row: BrowsingHistoryEntry): void {
    if (browsingHistoryStore.remove(this.context(), row.id)) { this.reload(); }
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
              .fontColor($r('app.color.text_primary')).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              .constraintSize({ maxWidth: '85%' }).flexShrink(1)
            if (row.verified) {
              SymbolGlyph($r('sys.symbol.checkmark_circle_fill')).fontSize(14).fontColor([$r('app.color.brand')])
            }
          }.width('100%').justifyContent(FlexAlign.Start)
          if (row.authorHandle.length > 0) {
            Text('@' + row.authorHandle).fontFamily(this.appFontFamily).fontSize(12)
              .fontColor($r('app.color.text_secondary')).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Text(this.time(row)).fontFamily(this.appFontFamily).fontSize(12).fontColor($r('app.color.text_secondary'))
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.ellipsis_circle')).fontSize(20).fontColor([$r('app.color.text_secondary')])
        }.width(32).height(36).backgroundColor(Color.Transparent).monopolizeEvents(true)
          .accessibilityText($r('app.string.profile_more'))
          .bindMenu([{ value: this.text($r('app.string.browsing_history_delete')), action: (): void => this.remove(row) }])
      }.width('100%')
      Row({ space: 12 }) {
        if (this.needsPreview(row)) {
          if (this.failedIds.indexOf(row.id) >= 0) {
            Column({ space: 6 }) {
              Text($r('app.string.post_detail_unavailable')).fontFamily(this.appFontFamily).fontSize(14)
                .fontColor($r('app.color.text_secondary'))
              Button($r('app.string.common_retry')).fontFamily(this.appFontFamily).fontSize(14)
                .backgroundColor(Color.Transparent).fontColor($r('app.color.brand')).monopolizeEvents(true)
                .onClick((): void => this.retry(row))
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          } else {
            Row({ space: 8 }) {
              LoadingProgress().width(18).height(18).color($r('app.color.brand'))
              Text($r('app.string.status_loading')).fontFamily(this.appFontFamily).fontSize(14)
                .fontColor($r('app.color.text_secondary'))
            }.layoutWeight(1).height(52)
          }
        } else if (row.text.length > 0) {
          Text(row.text).fontFamily(this.appFontFamily).fontSize(16).fontColor($r('app.color.text_primary'))
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
          .fontSize(13).fontColor([$r('app.color.text_secondary')])
        Text(this.video(row) ? $r('app.string.compose_video_label') : row.mediaCount > 0 ?
          $r('app.string.profile_photos_tab') : $r('app.string.profile_detail_posts'))
          .fontFamily(this.appFontFamily).fontSize(12).fontColor($r('app.color.text_secondary'))
        Blank()
        SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(12).fontColor([$r('app.color.text_secondary')])
      }.width('100%')
    }.width('100%').padding(14).alignItems(HorizontalAlign.Start)
      .backgroundColor(cardSurfaceColor(this.displayMode, this.darkSurface)).borderRadius(20)
      .border({ width: 0.5, color: $r('app.color.divider') }).onClick((): void => this.open(row))
  }

  @Builder
  private SearchField(): void {
    Column() {
      Search({ value: this.query, placeholder: this.text($r('app.string.browsing_history_search')) })
        .width('100%').textFont({ size: 16, family: this.appFontFamily }).height(44).borderRadius(22).clip(true)
        .keyboardAppearance(KeyboardAppearance.IMMERSIVE).fontColor($r('app.color.text_primary'))
        .backgroundColor(SystemMaterialUtil.isApi26OrAbove() ? Color.Transparent :
          fieldSurfaceColor(this.displayMode, this.darkSurface))
        .systemMaterial(this.searchMaterial.material(this.accentColor))
        .onChange((value: string): void => {
          this.query = value; this.filter(); this.loadVisiblePreviews(0, 19);
        })
    }.width('100%').height(56).padding({ left: 14, right: 14, top: 4, bottom: 8 })
  }

  build(): void {
    HdsNavDestination() {
      List({ space: 12, scroller: this.scroller }) {
        ListItem() {
          Row({ space: 6 }) {
            SymbolGlyph($r('sys.symbol.lock')).fontSize(12).fontColor([$r('app.color.text_secondary')])
            Text($r('app.string.browsing_history_local')).fontFamily(this.appFontFamily).fontSize(12)
              .fontColor($r('app.color.text_secondary'))
          }.width('100%').padding({ left: 18, right: 18, top: 8, bottom: 4 })
        }
        if (this.visibleRows.length === 0) {
          ListItem() {
            Column({ space: 16 }) {
              SymbolGlyph($r('sys.symbol.clock')).fontSize(48).fontColor([$r('app.color.text_secondary')])
              Text(this.query.length > 0 ? $r('app.string.browsing_history_no_results') : $r('app.string.browsing_history_empty'))
                .fontFamily(this.appFontFamily).fontColor($r('app.color.text_secondary'))
            }.width('100%').padding({ top: 72, bottom: 72 })
          }
        }
        ForEach(this.visibleRows, (row: BrowsingHistoryEntry, index: number) => {
          ListItem() {
            Column({ space: 10 }) {
              if (this.newDay(index)) {
                Text(this.dayLabel(row)).fontFamily(this.appFontFamily).fontSize(14).fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_secondary')).width('100%').padding({ left: 4, top: 10 })
              }
              this.HistoryCard(row)
            }.width('100%').padding({ left: 14, right: 14 })
          }
        }, (row: BrowsingHistoryEntry): string => row.id + '-' + row.viewedAt + '-' + row.authorName + '-' +
          row.avatarUrl + '-' + row.verified + '-' + row.text + '-' + row.previewUrl)
      }.width('100%').height('100%').scrollBar(BarState.Off)
        .contentStartOffset(this.statusBarHeight + 116).contentEndOffset(this.bottomInset + 20)
        .clip(false).onScrollIndex((start: number, end: number): void => this.loadVisiblePreviews(start - 1, end))
    }.onShown((): void => this.shown()).onHidden((): void => this.hidden())
      .titleMode(HdsNavDestinationTitleMode.MINI).bindToScrollable([this.scroller])
      .titleBar({ avoidLayoutSafeArea: true,
        content: { title: { mainTitle: $r('app.string.browsing_history_title') },
          bottomBuilder: { builder: (): void => this.SearchField(),
            builderContent: retainedTitleBarBuilder((): void => this.SearchField()),
            height: 56, showType: BottomBuilderShowType.DIRECTLY_SHOW },
          menu: { value: [{ content: { label: $r('app.string.browsing_history_clear'), type: TextStyleMode.NORMAL,
            isEnabled: this.rows.length > 0, action: (): void => this.clear() } }] } },
        style: destinationTitleBarStyle(ScrollEffectType.GRADIENT_BLUR, this.displayMode, this.darkSurface, this.titleBarStyleMode) })
      .backgroundColor(pageSurfaceColor(this.displayMode, this.darkSurface))
      .onBackPressed((): boolean => { ResponsiveLayout.closeContentDestination(this.pageStack); return true; })
  }
}
