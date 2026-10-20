import { scrollFrame, scrollStarted, scrollStopped, stopScrollOnTouch } from '../utils/ScrollInteraction';
import { common } from '@kit.AbilityKit';
import promptAction from '@ohos.promptAction';
import { HdsNavDestination, HdsNavDestinationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import type { Tweet, ProfileArticle } from '../models/Tweet';
import { TRANSLATION_MODE_WEB, TRANSLATION_MODE_X } from '../models/Translation';
import { ReadingDocument, ReadingDocuments, ReadingParagraph, ReadingPosition } from '../services/ReadingDocument';
import { offlineReadingStore, OfflineSaveResult } from '../services/OfflineReadingStore';
import { xPrivateClient, XPrivateResult } from '../services/XPrivateClient';
import { XTimelineParser, TweetDetailPage } from '../services/XTimelineParser';
import { XArticleParser } from '../services/XArticleParser';
import { translationStore, TranslationSettings } from '../services/TranslationStore';
import { translationService, TranslationResult } from '../services/TranslationService';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { ProxyMediaImage } from '../components/ProxyMediaImage';
import { pageCanvasColor, fieldSurfaceColor } from '../utils/ThemeColors';
import { destinationTitleBarStyle } from '../utils/DestinationTitleBar';
import type { SettingsRouteParam } from './Settings';
import { STORAGE_KEY_ACCOUNTS_CHANGED } from '../services/AccountStore';
import { EyeReadingControl } from '../components/EyeReadingControl';

export interface ThreadReaderRouteParam {
  root?: Tweet;
  replies?: Tweet[];
  cursor?: string;
  rankingMode?: string;
  offlineId?: string;
}

class ReaderTranslation {
  id: string = '';
  text: string = '';
}

@Builder
export function ThreadReaderBuilder(): void { ThreadReaderPage(); }

@Component
export struct ThreadReaderPage {
  @Consume('pageStack') private pageStack: NavPathStack;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp('harmonyx.display_mode') private displayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private darkSurface: string = '';
  @StorageProp('harmonyx.status_bar_height') private statusBarHeight: number = 0;
  @StorageProp('harmonyx.navigation_indicator_height') private bottomInset: number = 0;
  @StorageProp('harmonyx.title_bar_style_mode') private titleStyle: number = 0;
  @StorageProp('harmonyx.accent_color') private accent: string = '#007DFF';
  @StorageProp(STORAGE_KEY_ACCOUNTS_CHANGED) @Watch('accountChanged') private accountsRevision: number = 0;
  @State private document: ReadingDocument | null = null;
  @State private authorOnly: boolean = true;
  @State private fontSize: number = 18;
  @State private progress: number = 0;
  @State private loading: boolean = false;
  @State private saving: boolean = false;
  @State private translating: boolean = false;
  @State private translations: ReaderTranslation[] = [];
  @State private message: Resource | null = null;
  @State private nextToken: string = '';
  @State private offline: boolean = false;
  @State private eyeVisible: boolean = false;
  @State private eyeInteraction: number = 0;
  private eyeViewport: number = 400;
  private root: Tweet | null = null;
  private replies: Tweet[] = [];
  private account: string = '';
  private alive: boolean = true;
  private ready: boolean = false;
  private anchor: string = '';
  private visited: Set<string> = new Set<string>();
  private scroller: Scroller = new Scroller();
  private restoreTimer: number = -1;
  private translationGeneration: number = 0;
  private rankingMode: string = 'Recency';
  private firstVisible: number = -1;
  private lastVisible: number = -1;

  private context(): common.UIAbilityContext { return getContext(this) as common.UIAbilityContext; }
  private eyePage(direction: number): void {
    if (!this.eyeVisible || !this.active() || this.document === null) { return; }
    try { this.scroller.scrollBy(0, direction * Math.max(120, this.eyeViewport * 0.6)); } catch (_error) { }
  }
  private text(resource: Resource): string { return this.context().resourceManager.getStringSync(resource); }
  private active(): boolean { return this.alive && this.account === offlineReadingStore.account(this.context()); }
  private accountChanged(): void {
    if (this.account.length > 0 && this.account !== offlineReadingStore.account(this.context())) {
      this.document = null; this.translations = []; this.translationGeneration++;
      this.loading = false; this.saving = false; this.translating = false;
      this.message = $r('app.string.reader_missing');
    }
  }
  aboutToDisappear(): void {
    this.persist(); this.alive = false; this.translationGeneration++;
    if (this.restoreTimer >= 0) { clearTimeout(this.restoreTimer); }
  }
  private async begin(param: ThreadReaderRouteParam): Promise<void> {
    this.account = offlineReadingStore.account(this.context());
    xPrivateClient.load(this.context());
    this.offline = (param.offlineId ?? '').length > 0;
    this.rankingMode = param.rankingMode === 'Relevance' ? 'Relevance' : 'Recency';
    if (this.offline) { this.document = offlineReadingStore.read(this.context(), param.offlineId ?? ''); }
    else if (param.root !== undefined) {
      this.root = JSON.parse(JSON.stringify(param.root)) as Tweet;
      this.replies = JSON.parse(JSON.stringify(param.replies ?? [])) as Tweet[];
      this.document = ReadingDocuments.build(this.root, this.replies);
      this.nextToken = param.cursor ?? '';
    }
    if (this.document === null) { this.message = $r('app.string.reader_missing'); return; }
    const position: ReadingPosition = offlineReadingStore.position(this.context(), this.document.id);
    this.fontSize = position.fontSize; this.authorOnly = position.authorOnly;
    this.anchor = position.anchor; this.progress = position.progress;
    if (!this.offline) {
      if (param.cursor === undefined) { await this.loadMore(true); }
      await this.hydrateArticles();
    }
    if (this.active()) { this.restore(); }
  }
  private visible(): ReadingParagraph[] {
    const document: ReadingDocument | null = this.document;
    if (document === null) { return []; }
    return document.paragraphs.filter((p: ReadingParagraph): boolean => (!this.authorOnly || p.authorId === document.authorId) &&
      (p.text.length > 0 || p.images.length > 0));
  }
  private restore(): void {
    this.ready = false;
    if (this.restoreTimer >= 0) { clearTimeout(this.restoreTimer); }
    this.restoreTimer = setTimeout((): void => {
      this.restoreTimer = -1;
      if (!this.active()) { return; }
      const index: number = this.visible().findIndex((p: ReadingParagraph): boolean => p.id === this.anchor);
      if (index >= 0) { this.scroller.scrollToIndex(index, false, ScrollAlign.START); }
      this.ready = true;
      this.onVisible(this.firstVisible, this.lastVisible);
    }, 120);
  }
  private persist(): void {
    if (!this.ready || !this.active() || this.document === null) { return; }
    const position: ReadingPosition = new ReadingPosition();
    position.anchor = this.anchor; position.progress = this.progress;
    position.fontSize = this.fontSize; position.authorOnly = this.authorOnly;
    try { offlineReadingStore.savePosition(this.context(), this.account, this.document.id, position); } catch (_error) { }
  }
  private onVisible(first: number, last: number): void {
    this.firstVisible = first; this.lastVisible = last;
    if (!this.ready) { return; }
    const paragraphs: ReadingParagraph[] = this.visible();
    if (first < 0 || first >= paragraphs.length) { return; }
    this.anchor = paragraphs[first].id;
    this.progress = paragraphs.length === 0 ? 0 : Math.min(1, (last + 1) / paragraphs.length);
  }
  private async hydrateArticles(): Promise<void> {
    if (this.root === null || this.offline || this.loading) { return; }
    this.loading = true;
    const posts: Tweet[] = ReadingDocuments.order(this.root, this.replies);
    try {
      for (let i: number = 0; i < posts.length; i++) {
        const article: ProfileArticle | undefined = posts[i].article;
        if (article === undefined || (article.plainText ?? '').length > 0 || (article.blocks?.length ?? 0) > 0) { continue; }
        const response: XPrivateResult = await xPrivateClient.postContent('ArticleEntityResultByRestId', article.id);
        if (!this.active()) { return; }
        const full: ProfileArticle | undefined = response.ok ? XArticleParser.detail(response.body) : undefined;
        if (full !== undefined && full.id === article.id) { posts[i].article = full; }
      }
      if (this.active() && this.root !== null) { this.document = ReadingDocuments.build(this.root, this.replies); }
    } catch (_error) { if (this.active()) { this.message = $r('app.string.reader_partial'); } }
    finally { if (this.active()) { this.loading = false; } }
  }
  private async loadMore(initial: boolean = false): Promise<void> {
    const root: Tweet | null = this.root;
    if (root === null || this.offline || this.loading || !initial && this.nextToken.length === 0) { return; }
    const cursor: string = initial ? '' : this.nextToken;
    this.loading = true; this.message = null; this.translationGeneration++; this.translations = []; this.translating = false;
    try {
      const response: XPrivateResult = await xPrivateClient.tweetDetail(root.id, this.rankingMode, cursor);
      if (!this.active()) { return; }
      const page: TweetDetailPage | null = response.ok ?
        XTimelineParser.parseTweetDetail(response.body, root.id, [root, ...this.replies], false) : null;
      if (page === null) { this.message = $r('app.string.reader_load_failed'); return; }
      if (page.focal !== null) { this.root = page.focal; }
      const merged: Map<string, Tweet> = new Map<string, Tweet>();
      for (let i: number = 0; i < this.replies.length; i++) { merged.set(this.replies[i].id, this.replies[i]); }
      for (let i: number = 0; i < page.replies.length; i++) { merged.set(page.replies[i].id, page.replies[i]); }
      const replies: Tweet[] = []; merged.forEach((post: Tweet): void => { replies.push(post); }); this.replies = replies;
      this.visited.add(cursor);
      this.nextToken = page.discoverMoreStarted || this.visited.has(page.nextToken) ? '' : page.nextToken;
      this.document = ReadingDocuments.build(this.root ?? root, this.replies);
    } catch (_error) { if (this.active()) { this.message = $r('app.string.reader_load_failed'); } }
    finally { if (this.active()) { this.loading = false; } }
  }
  private async save(): Promise<void> {
    if (this.document === null || this.saving || !this.active()) { return; }
    this.saving = true;
    const snapshot: ReadingDocument = JSON.parse(JSON.stringify(this.document)) as ReadingDocument;
    if (this.nextToken.length > 0) { snapshot.complete = false; }
    const result: OfflineSaveResult = await offlineReadingStore.save(this.context(), snapshot, this.account,
      offlineReadingStore.includeImages(this.context()));
    if (!this.active()) { return; }
    this.saving = false;
    promptAction.showToast({ message: this.text(result.ok ? result.complete ? $r('app.string.offline_saved') :
      $r('app.string.offline_partial_saved') : $r('app.string.offline_save_failed')), duration: 2500 });
    this.persist();
  }
  private async translatePassages(): Promise<void> {
    if (this.translating) { return; }
    if (this.translations.length > 0) { this.translations = []; return; }
    const settings: TranslationSettings = translationStore.load(this.context());
    if (!settings.isRunnable()) { this.message = $r('app.string.reader_translation_setup'); return; }
    // X's translation endpoint returns one post, so passages use the same
    // keyless web translator used by the app's web translation option.
    if (settings.mode === TRANSLATION_MODE_X) { settings.mode = TRANSLATION_MODE_WEB; }
    this.translating = true; this.message = null;
    const generation: number = ++this.translationGeneration;
    const paragraphs: ReadingParagraph[] = this.visible();
    const translated: ReaderTranslation[] = [];
    try {
      for (let i: number = 0; i < paragraphs.length; i++) {
        if (paragraphs[i].text.length === 0) { continue; }
        const result: TranslationResult = await translationService.translate('reader:' + paragraphs[i].id,
          paragraphs[i].text, settings);
        if (!this.active() || generation !== this.translationGeneration) { return; }
        if (!result.ok) { this.message = $r('app.string.reader_translation_failed'); return; }
        const item: ReaderTranslation = new ReaderTranslation(); item.id = paragraphs[i].id; item.text = result.text;
        translated.push(item);
        this.translations = translated.slice();
      }
    } catch (_error) { if (this.active()) { this.message = $r('app.string.reader_translation_failed'); } }
    finally { if (this.active() && generation === this.translationGeneration) { this.translating = false; } }
  }
  private body(paragraph: ReadingParagraph): string {
    return this.translations.find((item: ReaderTranslation): boolean => item.id === paragraph.id)?.text ?? paragraph.text;
  }
  @Builder
  private Controls(): void {
    Column({ space: 8 }) {
      Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Center }) {
        Row({ space: 6 }) {
          Text($r('app.string.reader_author_only')).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_primary'))
          Toggle({ type: ToggleType.Switch, isOn: this.authorOnly }).selectedColor(this.accent)
            .accessibilityText($r('app.string.reader_author_only')).onChange((value: boolean): void => {
              this.authorOnly = value; this.translations = []; this.translationGeneration++; this.translating = false;
              this.restore();
            })
        }.margin({ right: 12, bottom: 4 })
        Button(this.translating ? $r('app.string.post_translating') : this.translations.length > 0 ?
          $r('app.string.post_hide_translation') : $r('app.string.reader_translate'))
          .fontColor(this.accent).backgroundColor(Color.Transparent).enabled(!this.translating && !this.loading)
          .onClick((): void => { void this.translatePassages(); })
        if (!this.offline) {
          Button(this.saving ? $r('app.string.offline_saving') : $r('app.string.offline_save'))
            .fontColor(this.accent).backgroundColor(Color.Transparent).enabled(!this.saving && !this.loading)
            .onClick((): void => { void this.save(); })
        }
      }.width('100%')
      Row({ space: 8 }) {
        Text($r('app.string.reader_font')).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_primary'))
        Slider({ value: this.fontSize, min: 14, max: 28, step: 1 }).layoutWeight(1).selectedColor(this.accent)
          .accessibilityText($r('app.string.reader_font')).onChange((value: number, mode: SliderChangeMode): void => {
            if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) { this.fontSize = value; this.persist(); }
          })
        Text(Math.round(this.progress * 100).toString() + '%').fontSize($r('sys.float.Body_S')).fontColor(this.accent)
      }.width('100%')
      if (this.message !== null) {
        Text(this.message).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary'))
        if (this.message.id === $r('app.string.reader_translation_setup').id) {
          Button($r('app.string.settings_category_language_tools')).fontColor(this.accent).backgroundColor(Color.Transparent)
            .onClick((): void => {
              const param: SettingsRouteParam = { section: 'translation' };
              this.pageStack.pushPath({ name: 'SettingsSection', param: param });
            })
        }
      }
      if (this.document !== null && !this.document.complete) {
        Text($r('app.string.reader_partial')).fontSize($r('sys.float.Body_S')).fontColor($r('app.color.text_secondary'))
      }
      if (!this.offline && this.nextToken.length > 0) {
        Text($r('app.string.reader_scope')).fontSize($r('sys.float.Body_S')).fontColor($r('app.color.text_secondary'))
      }
    }.width('100%').padding({ left: 16, right: 16, bottom: 8 })
  }
  @Builder
  private Paragraph(paragraph: ReadingParagraph, index: number): void {
    Column({ space: 10 }) {
      if (index === 0 || this.visible()[index - 1].postId !== paragraph.postId) {
        Text(paragraph.author).fontSize($r('sys.float.Body_M')).fontWeight(FontWeight.Medium)
          .fontColor(paragraph.authorId === this.document?.authorId ? this.accent : $r('app.color.text_secondary'))
      }
      if (paragraph.text.length > 0) {
        Text(this.body(paragraph)).fontSize(this.fontSize + (paragraph.heading ? 3 : 0))
          .lineHeight(this.fontSize * 1.7).fontFamily(this.appFontFamily)
          .fontWeight(paragraph.heading ? FontWeight.Bold : FontWeight.Normal)
          .fontColor($r('app.color.text_primary')).copyOption(CopyOptions.LocalDevice).width('100%')
      }
      ForEach(paragraph.images, (url: string): void => {
        if (this.offline) { Image(url).width('100%').constraintSize({ maxHeight: 360 }).objectFit(ImageFit.Contain) }
        else { ProxyMediaImage({ url: url, displayHeight: 280 }) }
      }, (url: string): string => url)
    }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 20, right: 20, top: 10, bottom: 10 })
  }
  build(): void {
    HdsNavDestination() {
      Column() {
        this.Controls()
        EyeReadingControl({ active: this.eyeVisible && this.document !== null, interaction: this.eyeInteraction,
          onPage: (direction: number): void => this.eyePage(direction) })
          .padding({ left: 16, right: 16, bottom: 6 })
        List({ scroller: this.scroller, space: 0 }) {
          ForEach(this.visible(), (paragraph: ReadingParagraph, index: number): void => {
            ListItem() { this.Paragraph(paragraph, index) }
          }, (paragraph: ReadingParagraph): string => paragraph.id)
          ListItem() {
            Column({ space: 12 }) {
              if (this.loading) { LoadingProgress().width(24).height(24).color(this.accent) }
              if (!this.offline && (this.nextToken.length > 0 || this.message?.id === $r('app.string.reader_load_failed').id)) {
                Button($r('app.string.timeline_load_more')).fontColor(this.accent).enabled(!this.loading)
                  .backgroundColor(fieldSurfaceColor(this.displayMode, this.darkSurface))
                  .onClick((): void => { void this.loadMore(this.nextToken.length === 0).then((): void => { void this.hydrateArticles(); }); })
              }
              if (this.offline) { Text($r('app.string.reader_offline_note')).fontSize($r('sys.float.Body_S')).fontColor($r('app.color.text_secondary')) }
            }.width('100%').padding(20)
          }
        }
        .onScrollFrameBegin((offset: number, state: ScrollState): OnScrollFrameBeginHandlerResult =>
          scrollFrame(this.scroller, offset, state))
        .onTouchIntercept((event: TouchEvent): HitTestMode => stopScrollOnTouch(event, this.scroller)).width('100%').layoutWeight(1).scrollBar(BarState.Auto)
          .onAreaChange((_old: Area, area: Area): void => { this.eyeViewport = Number(area.height); })
          .onScrollStart((): void => { scrollStarted(this.scroller); this.eyeInteraction++; })
          .onScrollIndex((first: number, last: number): void => this.onVisible(first, last))
          .onScrollStop((): void => { scrollStopped(this.scroller); this.persist(); })
      }.width('100%').constraintSize({ maxWidth: 820 }).height('100%')
        .padding({ top: this.statusBarHeight + 64, bottom: this.bottomInset })
        .onTouch((event: TouchEvent): void => { if (event.type === TouchType.Down) { this.eyeInteraction++; } })
        .onKeyEvent((_event: KeyEvent): boolean => { this.eyeInteraction++; return false; })
    }.titleMode(HdsNavDestinationTitleMode.MINI).hideBackButton(false)
      .titleBar({ avoidLayoutSafeArea: true, content: { title: { mainTitle: $r('app.string.reader_title') } },
        style: destinationTitleBarStyle(ScrollEffectType.GRADIENT_BLUR, this.displayMode, this.darkSurface, this.titleStyle) })
      .backgroundColor(pageCanvasColor(this.displayMode, this.darkSurface, ''))
      .onShown((): void => { this.eyeVisible = true; })
      .onHidden((): void => { this.eyeVisible = false; this.persist(); })
      .onWillDisappear((): void => { this.eyeVisible = false; })
      .onReady((context: NavDestinationContext): void => {
        const param: ThreadReaderRouteParam = context.pathInfo.param as ThreadReaderRouteParam;
        if (param !== undefined) { void this.begin(param); }
      })
  }
}
