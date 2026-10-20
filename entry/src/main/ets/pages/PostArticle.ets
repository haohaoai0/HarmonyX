import { scrollFrame, scrollStarted, scrollStopped, stopScrollOnTouch } from '../utils/ScrollInteraction';
import { pageTextColor } from '../utils/ThemeColors';
import { appPageBackground } from '../components/PageBackgroundLayer';
import { pageCanvasColor, pageReadingSurfaceColor } from '../utils/ThemeColors';
import { STORAGE_KEY_PAGE_TRANSITION_MODE, DEFAULT_PAGE_TRANSITION_MODE } from '../services/PageTransitionSettingsStore';
import { pageSystemTransition, PageTransitionMotion } from '../utils/PageTransition';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { STORAGE_KEY_SYSTEM_EMOJI_ENABLED } from '../services/AppearanceStore';
import { common } from '@kit.AbilityKit';
import { HdsNavDestination, HdsNavDestinationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import type { ProfileArticle } from '../models/Tweet';
import { ArticleBlock, ArticleRun } from '../models/PostContent';
import type { PostArticleRouteParam } from '../utils/PostArticleRoute';
import { XPrivateResult, xPrivateClient } from '../services/XPrivateClient';
import { XTimelineParser } from '../services/XTimelineParser';
import { XArticleParser } from '../services/XArticleParser';
import { openPostCardUrl } from '../utils/PostCardAction';
import { openExternalLink } from '../utils/PostEntities';
import { destinationTitleBarStyle } from '../utils/DestinationTitleBar';
import { pageSurfaceColor } from '../utils/ThemeColors';
import { PostMedia } from '../components/PostMedia';
import { ProxyMediaImage } from '../components/ProxyMediaImage';
import { EmojiSpans, EmojiSpanStyle } from '../components/EmojiSpans';
import { EmojiCopyMenu } from '../utils/EmojiCopyMenu';
import { EyeReadingControl } from '../components/EyeReadingControl';

@Builder
export function PostArticleBuilder(): void { PostArticle(); }

@Component
struct PostArticle {
  private plainTextController: TextController = new TextController();
  private blockTextControllers: Map<string, TextController> = new Map<string, TextController>();
  @StorageProp('harmonyx.page_background') private pageBackgroundValue: string = '';
  @State private pageMotion: PageTransitionMotion = new PageTransitionMotion();
  @StorageProp(STORAGE_KEY_PAGE_TRANSITION_MODE) private pageTransitionMode: string = DEFAULT_PAGE_TRANSITION_MODE;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp(STORAGE_KEY_SYSTEM_EMOJI_ENABLED) private systemEmojiEnabled: boolean = false;
  @StorageProp('harmonyx.status_bar_height') statusBarHeight: number = 0;
  @StorageProp('harmonyx.navigation_indicator_height') navigationIndicatorHeight: number = 0;
  @StorageProp('harmonyx.display_mode') themeDisplayMode: string = '';
  @StorageProp('harmonyx.dark_surface') themeDarkSurface: string = '';
  @StorageLink('harmonyx.title_bar_style_mode') titleBarStyleMode: number = 0;
  @StorageLink('harmonyx.accent_color') accentColor: string = '#007DFF';
  @State private article: ProfileArticle | undefined = undefined;
  @State private loading: boolean = false;
  @State private failed: boolean = false;
  @State private status: number = 0;
  @State private eyeVisible: boolean = false;
  @State private eyeInteraction: number = 0;
  private eyeViewport: number = 400;
  private postId: string = '';
  private scroller: Scroller = new Scroller();
  private alive: boolean = true;
  private generation: number = 0;
  aboutToDisappear(): void { this.alive = false; ++this.generation; }
  private eyePage(direction: number): void {
    if (!this.eyeVisible || !this.alive || this.article === undefined) { return; }
    try { this.scroller.scrollBy(0, direction * Math.max(120, this.eyeViewport * 0.6)); } catch (_error) { }
  }
  private open(url: string): void { openPostCardUrl(getContext(this) as common.UIAbilityContext, url); }
  private async load(): Promise<void> {
    if (this.article === undefined) { return; }
    xPrivateClient.load(getContext(this) as common.UIAbilityContext);
    const generation: number = ++this.generation; const session: number = xPrivateClient.sessionGeneration();
    this.loading = true; this.failed = false;
    try {
      const result: XPrivateResult = await xPrivateClient.postContent(this.postId.length > 0 ? 'TweetResultByRestId' :
        'ArticleEntityResultByRestId', this.postId || this.article.id);
      if (!this.alive || generation !== this.generation || session !== xPrivateClient.sessionGeneration()) { return; }
      const article: ProfileArticle | undefined = result.ok ? this.postId.length > 0 ?
        XTimelineParser.parsePostContent(result.body, this.postId)?.article : XArticleParser.detail(result.body) : undefined;
      if (article !== undefined && article.id === this.article.id) {
        this.article = article;
      }
      this.failed = article === undefined || (article.blocks?.length ?? 0) === 0 && (article.plainText?.length ?? 0) === 0;
      this.status = result.status;
    } catch (error) { if (this.alive && generation === this.generation) { this.failed = true; } }
    finally { if (this.alive && generation === this.generation) { this.loading = false; } }
  }
  private font(block: ArticleBlock): Resource {
    return block.kind === 'header-one' ? $r('sys.float.Title_L') : block.kind === 'header-two' ? $r('sys.float.Title_M') :
      block.kind === 'header-three' ? $r('sys.float.Subtitle_L') : $r('sys.float.Body_L');
  }
  private runStyle(block: ArticleBlock, run: ArticleRun): EmojiSpanStyle {
    return {
      weight: run.bold || block.kind.startsWith('header') ? FontWeight.Bold : FontWeight.Normal,
      fontStyle: run.italic ? FontStyle.Italic : FontStyle.Normal,
      family: this.appFontFamily === DEFAULT_APP_FONT_FAMILY ? (run.code ? 'monospace' : '') : this.appFontFamily,
      decoration: run.strike ? TextDecorationType.LineThrough : run.underline || run.url.length > 0 ?
        TextDecorationType.Underline : TextDecorationType.None,
      color: pageTextColor(run.url.length > 0 ? this.accentColor : $r('app.color.text_primary'), this.pageBackgroundValue)
    };
  }
  private blockTextController(block: ArticleBlock): TextController {
    const existing: TextController | undefined = this.blockTextControllers.get(block.id);
    if (existing !== undefined) { return existing; }
    const controller: TextController = new TextController();
    this.blockTextControllers.set(block.id, controller);
    return controller;
  }
  @Builder
  private Block(block: ArticleBlock, index: number): void {
    Column({ space: 8 }) {
      if (block.text.length > 0) {
        Row({ space: 8 }) {
          if (block.kind === 'unordered-list-item') { Text('•').fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontColor(pageTextColor(this.accentColor, this.pageBackgroundValue)) }
          if (block.kind === 'ordered-list-item') { Text(String(index + 1) + '.').fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontColor(pageTextColor(this.accentColor, this.pageBackgroundValue)) }
          Text(undefined, { controller: this.blockTextController(block) }) {
            ForEach(block.runs, (run: ArticleRun) => {
              EmojiSpans(this.getUIContext(), run.text, this.font(block), this.systemEmojiEnabled,
                (): void => { if (run.url.length > 0) { this.open(run.url); } }, this.accentColor, this.runStyle(block, run))
            })
          }.fontFamily(this.appFontFamily).layoutWeight(1).fontSize(this.font(block)).lineHeight(28).copyOption(CopyOptions.LocalDevice)
            .editMenuOptions(new EmojiCopyMenu(this.getUIContext(), this.blockTextController(block), block.runs.map((run: ArticleRun): string => run.text).join(''), this.systemEmojiEnabled))
        }.width('100%').alignItems(VerticalAlign.Top)
          .padding({ left: block.kind === 'blockquote' ? 12 : 0 })
          .border({ width: { left: block.kind === 'blockquote' ? 3 : 0 }, color: this.accentColor })
      }
      if (block.media.length > 0) { PostMedia({ attachments: block.media, naturalVideoSize: true, limitNaturalHeight: true, pipEnabled: true }) }
      if (block.url.length > 0) {
        Button(block.url).fontColor(this.accentColor).backgroundColor($r('app.color.poll_option_surface'))
          .onClick((): void => this.open(block.url))
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
  build(): void {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        appPageBackground()
      Column() {
        EyeReadingControl({ active: this.eyeVisible && this.article !== undefined, interaction: this.eyeInteraction,
          onPage: (direction: number): void => this.eyePage(direction) })
          .padding({ left: 16, right: 16, top: this.statusBarHeight + 64, bottom: 6 })
      Scroll(this.scroller) {
        Column({ space: 18 }) {
          if (this.article !== undefined) {
            if (this.article.coverUrl.length > 0) { ProxyMediaImage({ url: this.article.coverUrl, displayHeight: 220 }).borderRadius(16).clip(true) }
            Text() { EmojiSpans(this.getUIContext(), this.article.title, $r('sys.float.Title_L'), this.systemEmojiEnabled) }.fontFamily(this.appFontFamily)
              .width('100%').fontSize($r('sys.float.Title_L')).fontWeight(FontWeight.Bold).fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent))
            if ((this.article.blocks?.length ?? 0) > 0) {
              ForEach(this.article.blocks ?? [], (block: ArticleBlock, index: number) => { this.Block(block, index) }, (block: ArticleBlock): string => block.id)
            } else if ((this.article.plainText?.length ?? 0) > 0) {
              Text(undefined, { controller: this.plainTextController }) { EmojiSpans(this.getUIContext(), this.article.plainText ?? '', $r('sys.float.Body_L'), this.systemEmojiEnabled) }.fontFamily(this.appFontFamily)
                .width('100%').fontSize($r('sys.float.Body_L')).fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent)).copyOption(CopyOptions.LocalDevice)
                .editMenuOptions(new EmojiCopyMenu(this.getUIContext(), this.plainTextController, this.article.plainText ?? '', this.systemEmojiEnabled))
            } else {
              Text() { EmojiSpans(this.getUIContext(), this.article.previewText, $r('sys.float.Body_L'), this.systemEmojiEnabled) }.fontFamily(this.appFontFamily)
                .width('100%').fontSize($r('sys.float.Body_L')).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
            }
            if (this.loading) { LoadingProgress().width(28).height(28).color(this.accentColor) }
            if (this.failed) {
              Text($r('app.string.card_article_failed')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
              if (this.status > 0) { Text('HTTP ' + this.status).fontFamily(this.appFontFamily).fontSize($r('sys.float.Caption_L')).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)) }
              Button($r('app.string.card_retry')).fontColor(this.accentColor).backgroundColor($r('app.color.poll_option_surface')).onClick((): void => { void this.load(); })
            }
            Button($r('app.string.card_original')).fontColor(this.accentColor).backgroundColor(Color.Transparent)
              .onClick((): void => openExternalLink(getContext(this) as common.UIAbilityContext, 'https://x.com/i/article/' + this.article?.id))
          }
        }.width('100%').constraintSize({ maxWidth: 780 }).alignItems(HorizontalAlign.Start)
          .padding({ left: 16, right: 16, top: 12, bottom: this.navigationIndicatorHeight + 32 })
      }
      .onScrollStop((): void => scrollStopped(this.scroller))
      .onScrollFrameBegin((offset: number, state: ScrollState): OnScrollFrameBeginHandlerResult =>
        scrollFrame(this.scroller, offset, state))
      .onTouchIntercept((event: TouchEvent): HitTestMode => stopScrollOnTouch(event, this.scroller)).width('100%').layoutWeight(1).scrollBar(BarState.Off)
        .onAreaChange((_old: Area, area: Area): void => { this.eyeViewport = Number(area.height); })
        .onScrollStart((): void => { scrollStarted(this.scroller); this.eyeInteraction++; })
      }.width('100%').height('100%')
        .onTouch((event: TouchEvent): void => { if (event.type === TouchType.Down) { this.eyeInteraction++; } })
        .onKeyEvent((_event: KeyEvent): boolean => { this.eyeInteraction++; return false; })
    
      }.width('100%').height('100%')
    }
    .scale({ x: this.pageMotion.scale, y: this.pageMotion.scale })
    .opacity(this.pageMotion.opacity)
    .systemTransition(pageSystemTransition(this.pageTransitionMode)).onReady((context: NavDestinationContext): void => {
      this.pageMotion.attach(context);
      const param: PostArticleRouteParam = context.pathInfo?.param as PostArticleRouteParam;
      if (param !== undefined) {
        this.article = param.article;
        this.postId = param.postId;
        this.alive = true;
        void this.load();
      }
    }).titleMode(HdsNavDestinationTitleMode.MINI).bindToScrollable([this.scroller]).hideBackButton(false)
      .titleBar({ avoidLayoutSafeArea: true, content: { title: { mainTitle: $r('app.string.card_article') } },
        style: destinationTitleBarStyle(ScrollEffectType.GRADIENT_BLUR, this.themeDisplayMode, this.themeDarkSurface, this.titleBarStyleMode) })
      .backgroundColor(pageCanvasColor(this.themeDisplayMode, this.themeDarkSurface, this.pageBackgroundValue))
      .onShown((): void => { this.eyeVisible = true; })
      .onHidden((): void => { this.eyeVisible = false; })
      .onWillDisappear((): void => { this.eyeVisible = false; })
  }
}
