import { pageTextColor } from '../utils/ThemeColors';
import { appPageBackground } from '../components/PageBackgroundLayer';
import { pageCanvasColor, pageReadingSurfaceColor } from '../utils/ThemeColors';
import { STORAGE_KEY_PAGE_TRANSITION_MODE, DEFAULT_PAGE_TRANSITION_MODE } from '../services/PageTransitionSettingsStore';
import { pageSystemTransition, PageTransitionMotion } from '../utils/PageTransition';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { STORAGE_KEY_SYSTEM_EMOJI_ENABLED } from '../services/AppearanceStore';
import { userAvatarRadius, userVerifiedType, userAvatarShape, verificationBadgeColor } from '../utils/UserIdentity';
// Read-aloud destination.
//
// The post page's floating action button opens this page and the queue starts
// immediately. Playback deliberately outlives the page: leaving it keeps the
// article running and hands the controls over to the TextReader minibar, so the
// page is a starting point rather than a modal player.
import {
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  ScrollEffectType
} from '@kit.UIDesignKit';
import { ReadStateCode, TextReader } from '@kit.SpeechKit';
import common from '@ohos.app.ability.common';
import { EmojiSpans } from '../components/EmojiSpans';
import { destinationTitleBarStyle } from '../utils/DestinationTitleBar';
import { cardSurfaceColor, fieldSurfaceColor, pageSurfaceColor, secondaryButtonSurfaceColor } from '../utils/ThemeColors';
import {
  DEFAULT_CONTENT_FONT_FAMILY,
  STORAGE_KEY_CONTENT_FONT_FAMILY
} from '../services/AppearanceStore';
import {
  ReadAloudArticle,
  buildReadAloudArticle,
  readAloudService
} from '../services/ReadAloudService';
import type { QuotedTweet, Tweet } from '../models/Tweet';
import { formatPostTime, STORAGE_KEY_POST_TIME_NOW } from '../utils/PostTime';

export interface ReadAloudRouteParam {
  tweets: Tweet[];
  startId: string;
}

@Builder
export function ReadAloudBuilder(): void {
  ReadAloudPage();
}

@Component
export struct ReadAloudPage {
  @StorageProp('harmonyx.page_background') private pageBackgroundValue: string = '';
  @State private pageMotion: PageTransitionMotion = new PageTransitionMotion();
  @StorageProp(STORAGE_KEY_PAGE_TRANSITION_MODE) private pageTransitionMode: string = DEFAULT_PAGE_TRANSITION_MODE;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp(STORAGE_KEY_SYSTEM_EMOJI_ENABLED) private systemEmojiEnabled: boolean = false;
  @StorageProp(STORAGE_KEY_POST_TIME_NOW) private postTimeNow: number = Date.now();
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp('harmonyx.status_bar_height') statusBarHeight: number =
    AppStorage.get<number>('harmonyx.status_bar_height') ?? 0;
  @StorageProp('harmonyx.navigation_indicator_height') navigationIndicatorHeight: number =
    AppStorage.get<number>('harmonyx.navigation_indicator_height') ?? 0;
  @StorageLink('harmonyx.accent_color') accentColor: string = '#007DFF';
  @StorageProp('harmonyx.display_mode') private themeDisplayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private themeDarkSurface: string = '';
  @StorageLink('harmonyx.title_bar_style_mode') titleBarStyleMode: number = 0;
  @StorageLink(STORAGE_KEY_CONTENT_FONT_FAMILY) private contentFontFamily: string = DEFAULT_CONTENT_FONT_FAMILY;
  @State private articles: ReadAloudArticle[] = [];
  @State private current: ReadAloudArticle | null = null;
  @State private currentId: string = '';
  @State private readState: ReadStateCode = ReadStateCode.WAITING;
  @State private preparing: boolean = true;
  @State private starting: boolean = false;
  @State private ready: boolean = false;
  @State private failure: string = '';
  private scroller: Scroller = new Scroller();
  private alive: boolean = false;
  private started: boolean = false;

  aboutToAppear(): void {
    this.alive = true;
    readAloudService().setStateListener((state: TextReader.ReadState): void => {
      this.onReadState(state);
    });
  }

  aboutToDisappear(): void {
    this.alive = false;
    // Playback keeps running; only the page's interest in the state ends.
    readAloudService().setStateListener(null);
  }

  private text(resource: Resource): string {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    return context.resourceManager.getStringSync(resource);
  }

  private onReadState(state: TextReader.ReadState): void {
    if (!this.alive) {
      return;
    }
    this.readState = state.state;
    if (state.id !== undefined && state.id.length > 0) {
      this.currentId = state.id;
      this.current = this.articleFor(state.id);
    }
  }

  // Fired once per page instance: the route delivers the queue, the engine is
  // brought up, and the thread starts playing without a second tap.
  private async begin(param: ReadAloudRouteParam): Promise<void> {
    if (this.started) {
      return;
    }
    this.started = true;
    const tweets: Tweet[] = param.tweets;
    if (tweets === undefined || tweets === null || tweets.length === 0) {
      this.preparing = false;
      this.failure = this.text($r('app.string.read_aloud_empty'));
      return;
    }
    const queue: ReadAloudArticle[] = [];
    for (let index = 0; index < tweets.length; index++) {
      queue.push(buildReadAloudArticle(tweets[index]));
    }
    this.articles = queue;
    this.currentId = param.startId !== undefined && param.startId.length > 0 ?
      param.startId : tweets[0].id;
    this.current = this.articleFor(this.currentId);

    const context: common.UIAbilityContext =
      this.getUIContext().getHostContext() as common.UIAbilityContext;
    const engineReady: boolean = await readAloudService().prepare(context);
    if (!this.alive) {
      return;
    }
    this.preparing = false;
    if (!engineReady) {
      this.failure = this.text($r('app.string.read_aloud_unavailable'));
      return;
    }
    await this.restart();
  }

  private async restart(): Promise<void> {
    this.starting = true;
    const played: boolean = await readAloudService().start(this.articles, this.currentId);
    this.starting = false;
    if (!this.alive) {
      return;
    }
    if (!played) {
      this.failure = this.text($r('app.string.read_aloud_start_failed'));
      return;
    }
    this.failure = '';
    this.ready = true;
    this.readState = ReadStateCode.PLAYING;
  }

  private togglePlayback(): void {
    if (this.readState === ReadStateCode.PLAYING) {
      readAloudService().pause();
      this.readState = ReadStateCode.PAUSED;
      return;
    }
    if (this.readState === ReadStateCode.PAUSED) {
      readAloudService().resume();
      this.readState = ReadStateCode.PLAYING;
      return;
    }
    // Waiting, finished or dropped out of the engine's list: replay the current
    // article from the top so the button always means "play".
    void this.restart();
  }

  private async stopPlayback(): Promise<void> {
    await readAloudService().stop();
    if (this.alive) {
      this.readState = ReadStateCode.WAITING;
    }
  }

  private articleFor(articleId: string): ReadAloudArticle | null {
    for (let index = 0; index < this.articles.length; index++) {
      if (this.articles[index].tweet.id === articleId) {
        return this.articles[index];
      }
    }
    return this.articles.length > 0 ? this.articles[0] : null;
  }

  private avatarUrlOf(article: ReadAloudArticle): string {
    return article.tweet.author.avatarUrl ?? '';
  }

  private quotedTextOf(article: ReadAloudArticle): string {
    const quoted: QuotedTweet | undefined = article.tweet.quotedTweet;
    return quoted === undefined ? '' : quoted.text;
  }

  private statusText(): Resource {
    if (this.preparing) {
      return $r('app.string.read_aloud_preparing');
    }
    if (this.starting) {
      return $r('app.string.read_aloud_starting');
    }
    if (this.readState === ReadStateCode.PLAYING) {
      return $r('app.string.read_aloud_playing');
    }
    if (this.readState === ReadStateCode.PAUSED) {
      return $r('app.string.read_aloud_paused');
    }
    if (this.readState === ReadStateCode.COMPLETED) {
      return $r('app.string.read_aloud_completed');
    }
    return $r('app.string.read_aloud_idle');
  }

  @Builder
  private ArticleHero(): void {
    if (this.current !== null) {
      this.ArticleHeroBody(this.current);
    }
  }

  // Split into a parameterised builder so the article reaches the layout as a
  // fully typed value instead of re-resolving an optional state field.
  @Builder
  private ArticleHeroBody(article: ReadAloudArticle): void {
    Column({ space: 12 }) {
      Row({ space: 10 }) {
        if (this.avatarUrlOf(article).length > 0) {
          Image(this.avatarUrlOf(article))
            .width(44)
            .height(44)
            .objectFit(ImageFit.Cover)
            .borderRadius(userAvatarRadius(44, 22, article.tweet.author.verifiedType ?? '', article.tweet.author.avatarShape ?? ''))
            .clip(true)
        } else {
          Text(article.tweet.author.name.substring(0, 1).toUpperCase()).fontFamily(this.appFontFamily)
            .width(44)
            .height(44)
            .fontSize($r('sys.float.Subtitle_L'))
            .maxFontScale(1)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_on_brand'))
            .backgroundColor(article.tweet.author.avatarColor)
            .borderRadius(userAvatarRadius(44, 22, article.tweet.author.verifiedType ?? '', article.tweet.author.avatarShape ?? ''))
            .textAlign(TextAlign.Center)
        }
        Column({ space: 3 }) {
          Text(article.tweet.author.name).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_L'))
            .fontWeight(FontWeight.Medium)
            .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, pageReadingSurfaceColor(cardSurfaceColor(this.themeDisplayMode, this.themeDarkSurface), this.pageBackgroundValue)))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text('@' + article.tweet.author.username + ' · ' +
            formatPostTime(article.tweet.createdAt, this.postTimeNow)).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M'))
            .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, pageReadingSurfaceColor(cardSurfaceColor(this.themeDisplayMode, this.themeDarkSurface), this.pageBackgroundValue)))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')

      Text() { EmojiSpans(this.getUIContext(), article.tweet.text, $r('sys.float.Body_L'), this.systemEmojiEnabled) }
        .width('100%')
        .fontSize($r('sys.float.Body_L'))
        .fontFamily(this.appFontFamily === DEFAULT_APP_FONT_FAMILY ? this.contentFontFamily : this.appFontFamily)
        .fontWeight(FontWeight.Medium)
        .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, pageReadingSurfaceColor(cardSurfaceColor(this.themeDisplayMode, this.themeDarkSurface), this.pageBackgroundValue)))
        .maxLines(12)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      if (this.quotedTextOf(article).length > 0) {
        Text() { EmojiSpans(this.getUIContext(), this.quotedTextOf(article), $r('sys.float.Body_M'), this.systemEmojiEnabled) }
          .width('100%')
          .fontSize($r('sys.float.Body_M'))
          .fontFamily(this.appFontFamily === DEFAULT_APP_FONT_FAMILY ? this.contentFontFamily : this.appFontFamily)
          .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface)))
          .maxLines(4)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .padding(10)
          .borderRadius(12)
          .backgroundColor(fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
      }
    }
    .width('100%')
    .padding(16)
    .borderRadius(20)
    .backgroundColor(pageReadingSurfaceColor(cardSurfaceColor(this.themeDisplayMode, this.themeDarkSurface), this.pageBackgroundValue))
  }

  @Builder
  private PlaybackControls(): void {
    // The controls are built inline on purpose: a parameterised @Builder passes
    // its arguments by value, so the transport would keep painting the state it
    // was created with instead of the one the engine reports.
    Row({ space: 10 }) {
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Row({ space: 8 }) {
          SymbolGlyph(this.readState === ReadStateCode.PLAYING ?
            $r('sys.symbol.pause') : $r('sys.symbol.play_fill'))
            .fontSize(26)
            .fontColor([$r('app.color.text_on_accent')])
          Text(this.readState === ReadStateCode.PLAYING ?
            $r('app.string.read_aloud_pause') : $r('app.string.read_aloud_play')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_L'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_on_accent'))
            .maxLines(1)
        }
        .justifyContent(FlexAlign.Center)
      }
      .height(52)
      .layoutWeight(2)
      .padding(0)
      .backgroundColor(this.accentColor)
      .borderRadius(26)
      .opacity(this.preparing || this.starting || this.failure.length > 0 ? 0.5 : 1)
      .enabled(!this.preparing && !this.starting && this.failure.length === 0)
      .accessibilityText(this.text(this.readState === ReadStateCode.PLAYING ?
        $r('app.string.read_aloud_pause') : $r('app.string.read_aloud_play')))
      .onClick((): void => {
        this.togglePlayback();
      })

      Button({ type: ButtonType.Normal, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.backward_end_fill'))
          .fontSize(24)
          .fontColor([pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, secondaryButtonSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))])
      }
      .height(46)
      .layoutWeight(1)
      .padding(0)
      .backgroundColor(secondaryButtonSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
      .borderRadius(23)
      .opacity(this.ready ? 1 : 0.5)
      .accessibilityText(this.text($r('app.string.read_aloud_previous')))
      .onClick((): void => {
        if (this.ready) {
          readAloudService().playPrevious();
        }
      })

      Button({ type: ButtonType.Normal, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.forward_end_fill'))
          .fontSize(24)
          .fontColor([pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, secondaryButtonSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))])
      }
      .height(46)
      .layoutWeight(1)
      .padding(0)
      .backgroundColor(secondaryButtonSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
      .borderRadius(23)
      .opacity(this.ready ? 1 : 0.5)
      .accessibilityText(this.text($r('app.string.read_aloud_next')))
      .onClick((): void => {
        if (this.ready) {
          readAloudService().playNext();
        }
      })

      Button({ type: ButtonType.Normal, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.stop_circle_fill'))
          .fontSize(24)
          .fontColor([pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, secondaryButtonSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))])
      }
      .height(46)
      .layoutWeight(1)
      .padding(0)
      .backgroundColor(secondaryButtonSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
      .borderRadius(23)
      .opacity(this.ready ? 1 : 0.5)
      .accessibilityText(this.text($r('app.string.read_aloud_stop')))
      .onClick((): void => {
        if (this.ready) {
          void this.stopPlayback();
        }
      })
    }
    .width('100%')
  }

  @Builder
  private StatusLine(): void {
    Row({ space: 8 }) {
      if (this.preparing || this.starting) {
        LoadingProgress()
          .width(16)
          .height(16)
          .color(this.accentColor)
      } else if (this.readState === ReadStateCode.PLAYING) {
        SymbolGlyph($r('sys.symbol.waveform'))
          .fontSize(16)
          .fontColor([this.accentColor])
      }
      Text(this.failure.length > 0 ? this.failure : this.text(this.statusText())).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_M'))
        .fontColor(this.failure.length > 0 ? $r('app.color.danger') : pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
        .maxLines(2)
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private QueueRow(article: ReadAloudArticle, index: number): void {
    Row({ space: 12 }) {
      Text((index + 1).toString()).fontFamily(this.appFontFamily)
        .width(24)
        .fontSize($r('sys.float.Body_M'))
        .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
        .textAlign(TextAlign.Center)
      Column({ space: 3 }) {
        Text(article.tweet.author.name + ' · @' + article.tweet.author.username).fontFamily(this.appFontFamily)
          .width('100%')
          .fontSize($r('sys.float.Body_M'))
          .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text() { EmojiSpans(this.getUIContext(), article.tweet.text, $r('sys.float.Body_L'), this.systemEmojiEnabled) }
          .width('100%')
          .fontSize($r('sys.float.Body_L'))
          .fontFamily(this.appFontFamily === DEFAULT_APP_FONT_FAMILY ? this.contentFontFamily : this.appFontFamily)
          .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      if (article.tweet.id === this.currentId) {
        SymbolGlyph(this.readState === ReadStateCode.PLAYING ?
          $r('sys.symbol.waveform') : $r('sys.symbol.pause'))
          .fontSize(18)
          .fontColor([this.accentColor])
      }
    }
    .width('100%')
    .padding(12)
    .borderRadius(14)
    .backgroundColor(pageCanvasColor(this.themeDisplayMode, this.themeDarkSurface, this.pageBackgroundValue))
    .border({
      width: 1,
      color: article.tweet.id === this.currentId ? this.accentColor : $r('app.color.divider')
    })
    .accessibilityText(article.tweet.author.name + ' ' + article.tweet.text)
    .onClick((): void => {
      this.currentId = article.tweet.id;
      this.current = article;
      void this.restart();
    })
  }

  @Builder
  private ContentBuilder(): void {
    Scroll(this.scroller) {
      Column({ space: 16 }) {
        this.ArticleHero()
        this.PlaybackControls()
        this.StatusLine()

        if (this.articles.length > 1) {
          Text($r('app.string.read_aloud_queue')).fontFamily(this.appFontFamily)
            .width('100%')
            .fontSize($r('sys.float.Subtitle_L'))
            .fontWeight(FontWeight.Bold)
            .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent))
            .margin({ top: 4 })
          ForEach(this.articles, (article: ReadAloudArticle, index: number) => {
            this.QueueRow(article, index)
          }, (article: ReadAloudArticle) => article.tweet.id)
        }
      }
      .width('100%')
      .padding({
        left: 12,
        right: 12,
        top: this.statusBarHeight + 64,
        bottom: this.navigationIndicatorHeight + 32
      })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
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
      const param: ReadAloudRouteParam = context.pathInfo?.param as ReadAloudRouteParam;
      if (param !== undefined && param !== null) {
        void this.begin(param);
      }
    })
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .hideBackButton(false)
    .bindToScrollable([this.scroller])
    .titleBar({
      avoidLayoutSafeArea: true,
      content: { title: { mainTitle: $r('app.string.read_aloud_title') } },
      style: destinationTitleBarStyle(ScrollEffectType.GRADIENT_BLUR, this.themeDisplayMode,
        this.themeDarkSurface, this.titleBarStyleMode)
    })
    .backgroundColor(pageCanvasColor(this.themeDisplayMode, this.themeDarkSurface, this.pageBackgroundValue));
  }
}
