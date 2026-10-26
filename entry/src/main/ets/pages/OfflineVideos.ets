import { AdaptivePostFeed } from '../components/AdaptivePostFeed';
import { ProxyAvatar } from '../components/ProxyAvatar';
import { ProxyMediaImage } from '../components/ProxyMediaImage';
import { PageSearchField } from '../components/PageSearchField';
import { appPageBackground } from '../components/PageBackgroundLayer';
import { pageCanvasColor, pageTextColor, postCardSurfaceColor, cardSurfaceColor } from '../utils/ThemeColors';
import { destinationTitleBarStyle, retainedTitleBarBuilder } from '../utils/DestinationTitleBar';
import { pageSystemTransition, PageTransitionMotion } from '../utils/PageTransition';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { STORAGE_KEY_PAGE_TRANSITION_MODE, DEFAULT_PAGE_TRANSITION_MODE } from '../services/PageTransitionSettingsStore';
import {
  OfflineVideoEntry,
  offlineVideoStore,
  STORAGE_KEY_OFFLINE_VIDEOS_REVISION
} from '../services/OfflineVideoStore';
import { common } from '@kit.AbilityKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { LengthMetrics } from '@kit.ArkUI';
import {
  BottomBuilderShowType,
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  ScrollEffectType,
  TextStyleMode
} from '@kit.UIDesignKit';
import type { VideoFeedRouteParam } from './VideoFeedViewer';
import type { MediaAttachment, Tweet } from '../models/Tweet';

@Builder
export function OfflineVideosBuilder(): void {
  OfflineVideos();
}

@Component
struct OfflineVideos {
  @StorageProp('harmonyx.page_background') private pageBackgroundValue: string = '';
  @StorageProp(STORAGE_KEY_PAGE_TRANSITION_MODE) private pageTransitionMode: string = DEFAULT_PAGE_TRANSITION_MODE;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp('harmonyx.status_bar_height') private statusBarHeight: number = 0;
  @StorageProp('harmonyx.navigation_indicator_height') private bottomInset: number = 0;
  @StorageProp('harmonyx.display_mode') private displayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private darkSurface: string = '';
  @StorageProp('harmonyx.title_bar_style_mode') private titleBarStyleMode: number = 0;
  @StorageProp(STORAGE_KEY_OFFLINE_VIDEOS_REVISION) @Watch('reload')
  private offlineVideoRevision: number = 0;
  @Consume('pageStack') pageStack: NavPathStack;
  private destinationStack: NavPathStack | null = null;
  @State private rows: OfflineVideoEntry[] = [];
  @State private visibleRows: OfflineVideoEntry[] = [];
  @State private query: string = '';
  @State private pageMotion: PageTransitionMotion = new PageTransitionMotion();
  @State private totalBytes: number = 0;
  private scroller: Scroller = new Scroller();
  private context(): common.UIAbilityContext {
    return getContext(this) as common.UIAbilityContext;
  }

  aboutToAppear(): void {
    this.reload();
  }

  private reload(): void {
    this.rows = offlineVideoStore.entries(this.context());
    this.totalBytes = offlineVideoStore.totalBytes(this.context());
    this.filter();
  }

  private filter(): void {
    const needle: string = this.query.trim().toLocaleLowerCase();
    if (needle.length === 0) {
      this.visibleRows = this.rows;
      return;
    }
    this.visibleRows = this.rows.filter((row: OfflineVideoEntry): boolean =>
      (row.authorName + ' ' + row.authorHandle + ' ' + row.text).toLocaleLowerCase().indexOf(needle) >= 0);
  }

  private gap(): number {
    return this.getUIContext().px2vp(
      this.context().resourceManager.getNumber($r('app.float.history_card_gap').id));
  }

  private authorName(row: OfflineVideoEntry): string {
    return row.authorName.length > 0 ? row.authorName :
      row.authorHandle.length > 0 ? '@' + row.authorHandle : 'X';
  }

  private cover(row: OfflineVideoEntry): string {
    if (row.coverFile.length > 0) {
      try {
        if (fileIo.accessSync(row.coverFile)) {
          return fileUri.getUriFromPath(row.coverFile);
        }
      } catch (error) {
      }
    }
    return row.previewUrl;
  }

  private cardSurface(): ResourceColor {
    return postCardSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue);
  }

  private textColor(resource: Resource): ResourceColor {
    return pageTextColor(resource, this.pageBackgroundValue, this.cardSurface());
  }

  private day(row: OfflineVideoEntry): string {
    return new Date(row.savedAt).toLocaleDateString();
  }

  private newDay(index: number): boolean {
    return index === 0 || this.day(this.visibleRows[index]) !== this.day(this.visibleRows[index - 1]);
  }

  private dayLabel(row: OfflineVideoEntry): string {
    return this.day(row) === new Date().toLocaleDateString() ?
      this.context().resourceManager.getStringSync($r('app.string.spaces_today')) : this.day(row);
  }

  private duration(row: OfflineVideoEntry): string {
    const seconds: number = Math.max(0, Math.round(row.durationMs / 1000));
    const minutes: number = Math.floor(seconds / 60);
    const rest: number = seconds % 60;
    return minutes.toString() + ':' + (rest < 10 ? '0' : '') + rest.toString();
  }

  private formatSize(bytes: number): string {
    if (bytes >= 1024 * 1024 * 1024) {
      return (bytes / (1024 * 1024 * 1024)).toFixed(1) + ' GB';
    }
    if (bytes >= 1024 * 1024) {
      return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
    }
    if (bytes >= 1024) {
      return Math.max(1, Math.round(bytes / 1024)).toString() + ' KB';
    }
    return Math.max(0, Math.round(bytes)).toString() + ' B';
  }

  private open(row: OfflineVideoEntry): void {
    if (!fileIo.accessSync(row.filePath)) {
      this.reload();
      return;
    }
    const media: MediaAttachment = this.playbackMedia(row);
    const tweet: Tweet = this.playbackTweet(row, media);
    const param: VideoFeedRouteParam = {
      tweets: [tweet],
      index: 0,
      startPlaying: true,
      startMediaId: row.mediaId,
      sourceTweetIds: [],
      offline: true,
      onLike: async (_target: Tweet, _liked: boolean): Promise<boolean> => false,
      onRepost: async (_target: Tweet, _reposted: boolean): Promise<boolean> => false,
      onReply: (_target: Tweet): void => {}
    };
    (this.destinationStack ?? this.pageStack).pushPath({ name: 'VideoFeedViewer', param: param });
  }

  private playbackMedia(row: OfflineVideoEntry): MediaAttachment {
    const uri: string = fileUri.getUriFromPath(row.filePath);
    return {
      id: row.mediaId,
      type: 'video',
      mediaUrl: uri,
      feedUrl: uri,
      videoVariantUrls: [],
      videoVariants: [],
      durationMs: row.durationMs,
      previewUrl: this.cover(row),
      width: row.width,
      height: row.height,
      altText: ''
    };
  }

  private playbackTweet(row: OfflineVideoEntry, media: MediaAttachment): Tweet {
    return {
      id: row.postId,
      author: {
        id: '',
        name: this.authorName(row),
        username: row.authorHandle,
        avatarUrl: row.avatarUrl,
        verified: row.verified,
        avatarColor: '#1D9BF0'
      },
      text: row.text,
      createdAt: '',
      metrics: { replyCount: 0, repostCount: 0, likeCount: 0, viewCount: 0 },
      liked: false,
      reposted: false,
      attachments: [media]
    };
  }

  private remove(row: OfflineVideoEntry): void {
    offlineVideoStore.remove(this.context(), row.id);
    this.reload();
  }

  private clear(): void {
    this.getUIContext().showAlertDialog({
      title: $r('app.string.offline_videos_clear'),
      message: $r('app.string.offline_videos_clear_confirm'),
      primaryButton: { value: $r('app.string.compose_cancel'), action: (): void => {} },
      secondaryButton: {
        value: $r('app.string.offline_videos_clear'),
        action: (): void => {
          offlineVideoStore.clear(this.context());
          this.reload();
        }
      }
    });
  }

  @Builder
  private HistoryCard(row: OfflineVideoEntry): void {
    Column({ space: 12 }) {
      Row({ space: 10 }) {
        ProxyAvatar({
          url: row.avatarUrl,
          avatarSize: 36,
          radius: 18,
          fallbackText: this.authorName(row).substring(0, 1),
          fallbackColor: $r('app.color.brand')
        })
        Column({ space: 2 }) {
          Row({ space: 4 }) {
            Text(this.authorName(row)).fontFamily(this.appFontFamily).fontSize(15)
              .fontWeight(FontWeight.Bold).fontColor(this.textColor($r('app.color.text_primary')))
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              .constraintSize({ maxWidth: '85%' }).flexShrink(1)
            if (row.verified) {
              SymbolGlyph($r('sys.symbol.checkmark_circle_fill')).fontSize(14)
                .fontColor([$r('app.color.brand')])
            }
          }.width('100%').justifyContent(FlexAlign.Start)
          if (row.authorHandle.length > 0) {
            Text('@' + row.authorHandle).fontFamily(this.appFontFamily).fontSize(12)
              .fontColor(this.textColor($r('app.color.text_secondary'))).maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Text(this.formatSize(row.sizeBytes)).fontFamily(this.appFontFamily).fontSize(12)
          .fontColor(this.textColor($r('app.color.text_secondary')))
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.ellipsis_circle')).fontSize(20)
            .fontColor([this.textColor($r('app.color.text_secondary'))])
        }.width(32).height(36).backgroundColor(Color.Transparent).monopolizeEvents(true)
          .accessibilityText($r('app.string.profile_more'))
          .bindMenu([{
            value: this.context().resourceManager.getStringSync($r('app.string.offline_videos_delete')),
            action: (): void => this.remove(row)
          }])
      }.width('100%')
      Row({ space: 12 }) {
        if (row.text.length > 0) {
          Text(row.text).fontFamily(this.appFontFamily).fontSize(16)
            .fontColor(this.textColor($r('app.color.text_primary')))
            .maxLines(4).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
            .lineSpacing(LengthMetrics.vp(4))
        } else {
          Blank().layoutWeight(1)
        }
        Stack({ alignContent: Alignment.Center }) {
          if (this.cover(row).length > 0) {
            ProxyMediaImage({ url: this.cover(row), displayHeight: 92 })
          } else {
            Column().width('100%').height('100%').backgroundColor($r('app.color.bg_field'))
          }
          Stack() {
            SymbolGlyph($r('sys.symbol.play_fill')).fontSize(20).fontColor([Color.White])
          }.width(36).height(36).borderRadius(18)
            .backgroundColor($r('app.color.media_viewer_sheet'))
          if (row.durationMs > 0) {
            Text(this.duration(row)).fontFamily(this.appFontFamily).fontSize(11)
              .fontColor(Color.White).backgroundColor('#99000000').borderRadius(6)
              .padding({ left: 5, right: 5, top: 2, bottom: 2 })
              .position({ x: 50, y: 72 })
          }
        }.width(92).height(92).borderRadius(12).clip(true)
      }.width('100%').alignItems(VerticalAlign.Center)
      Row({ space: 6 }) {
        SymbolGlyph($r('sys.symbol.video')).fontSize(13)
          .fontColor([this.textColor($r('app.color.text_secondary'))])
        Text($r('app.string.offline_videos_play')).fontFamily(this.appFontFamily).fontSize(12)
          .fontColor(this.textColor($r('app.color.text_secondary')))
        Blank()
        SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(12)
          .fontColor([this.textColor($r('app.color.text_secondary'))])
      }.width('100%')
    }.width('100%').padding($r('app.float.history_card_padding')).alignItems(HorizontalAlign.Start)
      .id('offline-video-card-' + row.id)
      .backgroundColor(this.cardSurface()).borderRadius(20)
      .border({ width: 0.5, color: $r('app.color.divider') })
      .onClick((): void => this.open(row))
  }

  @Builder
  private SearchField(): void {
    PageSearchField({
      value: this.query,
      placeholder: $r('app.string.offline_videos_search'),
      onValueChange: (value: string): void => {
        this.query = value;
        this.filter();
      }
    })
  }

  @Builder
  private FeedHeader(): void {
    Column({ space: 6 }) {
      Row({ space: 6 }) {
        SymbolGlyph($r('sys.symbol.lock')).fontSize(12)
          .fontColor([pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)])
        Text($r('app.string.offline_videos_local')).fontFamily(this.appFontFamily).fontSize(12)
          .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
        Blank()
        if (this.rows.length > 0) {
          Text(this.rows.length.toString() + ' · ' + this.formatSize(this.totalBytes)).fontFamily(this.appFontFamily)
            .fontSize(12)
            .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
        }
      }.width('100%')
      if (this.visibleRows.length === 0) {
        Column({ space: 14 }) {
          SymbolGlyph($r('sys.symbol.video')).fontSize(48)
            .fontColor([pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)])
          Text(this.query.length > 0 ? $r('app.string.offline_videos_no_results') : $r('app.string.offline_videos_empty'))
            .fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L'))
            .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
            .textAlign(TextAlign.Center)
        }.width('100%').padding({ top: 72, bottom: 32 }).justifyContent(FlexAlign.Center)
      }
    }.width('100%').padding({ left: 18, right: 18, top: 8, bottom: 4 })
  }

  @Builder
  private FeedRow(row: OfflineVideoEntry, index: number): void {
    Column({ space: 10 }) {
      if (this.newDay(index)) {
        Text(this.dayLabel(row)).fontFamily(this.appFontFamily).fontSize(14).fontWeight(FontWeight.Medium)
          .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
          .width('100%').padding({ left: 4, top: 10 })
      }
      this.HistoryCard(row)
    }.width('100%').padding({
      left: $r('app.float.history_page_inset'),
      right: $r('app.float.history_page_inset')
    })
  }

  build(): void {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        appPageBackground()
        AdaptivePostFeed({
          scroller: this.scroller,
          lazyItems: true,
          singleColumnGap: this.gap(),
          itemKeys: this.visibleRows.map((row: OfflineVideoEntry): string =>
            row.id + '-' + row.savedAt + '-' + row.sizeBytes + '-' + row.coverFile),
          feedId: 'offline-video-post-feed',
          startOffset: this.statusBarHeight + 116,
          endOffset: this.bottomInset + 20,
          header: (): void => this.FeedHeader(),
          footer: (): void => {},
          item: (index: number): void => this.FeedRow(this.visibleRows[index], index),
          onLoadMore: (): void => {},
          onVisibleItems: (_start: number, _end: number): void => {}
        })
      }.width('100%').height('100%')
    }
    .scale({ x: this.pageMotion.scale, y: this.pageMotion.scale })
    .opacity(this.pageMotion.opacity)
    .onReady((context: NavDestinationContext): void => {
      this.pageMotion.attach(context); this.destinationStack = context.pathStack;
      this.reload();
    })
    .systemTransition(pageSystemTransition(this.pageTransitionMode))
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .bindToScrollable([this.scroller])
    .titleBar({
      avoidLayoutSafeArea: true,
      content: {
        title: { mainTitle: $r('app.string.offline_videos_title') },
        bottomBuilder: {
          builder: (): void => this.SearchField(),
          builderContent: retainedTitleBarBuilder((): void => this.SearchField()),
          height: 56,
          showType: BottomBuilderShowType.DIRECTLY_SHOW
        },
        menu: {
          value: [{
            content: {
              label: $r('app.string.offline_videos_clear'),
              type: TextStyleMode.NORMAL,
              isEnabled: this.rows.length > 0,
              action: (): void => this.clear()
            }
          }]
        }
      },
      style: destinationTitleBarStyle(ScrollEffectType.GRADIENT_BLUR, this.displayMode,
        this.darkSurface, this.titleBarStyleMode)
    })
    .backgroundColor(pageCanvasColor(this.displayMode, this.darkSurface, this.pageBackgroundValue))
    // Returning false delegates both title-bar and system back to this destination's Navigation.
    .onBackPressed((): boolean => false)
  }
}
