import { common } from '@kit.AbilityKit';
import {
  DividerShowType,
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  IconStyleMode,
  ScrollEffectType,
  TextStyleMode
} from '@kit.UIDesignKit';
import { AdaptivePostFeed } from '../components/AdaptivePostFeed';
import { ProxyMediaImage } from '../components/ProxyMediaImage';
import { appPageBackground } from '../components/PageBackgroundLayer';
import { GlobalTrendCategory, GlobalTrendCountry, GlobalTrendTopic, GlobalTrendsPage } from '../models/GlobalTrends';
import type { Tweet } from '../models/Tweet';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { STORAGE_KEY_ACCOUNTS_CHANGED } from '../services/AccountStore';
import { XPrivateResult, xPrivateClient } from '../services/XPrivateClient';
import { XTimelineParser } from '../services/XTimelineParser';
import type { TweetPage } from '../services/XApiClient';
import { ContentFilterSettings, contentFilterStore, STORAGE_KEY_FILTER_REVISION } from '../services/ContentFilterStore';
import { DEFAULT_PAGE_TRANSITION_MODE, STORAGE_KEY_PAGE_TRANSITION_MODE } from '../services/PageTransitionSettingsStore';
import { DEFAULT_SHEET_MATERIAL_ENABLED, DEFAULT_SHEET_MATERIAL_LEVEL,
  STORAGE_KEY_SHEET_MATERIAL_ENABLED, STORAGE_KEY_SHEET_MATERIAL_LEVEL } from '../services/SheetMaterialSettingsStore';
import { destinationTitleBarStyle } from '../utils/DestinationTitleBar';
import { DesktopLayout } from '../utils/DesktopLayout';
import { PageTransitionMotion, pageSystemTransition } from '../utils/PageTransition';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';
import { pageCanvasColor, pageTextColor, fieldSurfaceColor } from '../utils/ThemeColors';
import { sheetMaterialOptions } from '../utils/SheetMaterial';

@Component
export struct GlobalTrendsPageView {
  @Consume('pageStack') private pageStack: NavPathStack;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp('harmonyx.page_background') private pageBackgroundValue: string = '';
  @StorageProp('harmonyx.display_mode') private displayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private darkSurface: string = '';
  @StorageProp('harmonyx.accent_color') private accentColor: string = '#007DFF';
  @StorageProp('harmonyx.title_bar_style_mode') private titleBarStyleMode: number = 0;
  @StorageProp('harmonyx.status_bar_height') private statusBarHeight: number = 0;
  @StorageProp('harmonyx.navigation_indicator_height') private bottomInset: number = 0;
  @StorageProp('harmonyx.desktop_layout') private desktopLayout: boolean = false;
  @StorageProp('harmonyx.breakpoint') private breakpoint: string = 'sm';
  @StorageProp(STORAGE_KEY_PAGE_TRANSITION_MODE) private pageTransitionMode: string = DEFAULT_PAGE_TRANSITION_MODE;
  @StorageProp(STORAGE_KEY_SHEET_MATERIAL_ENABLED) private sheetMaterialEnabled: boolean = DEFAULT_SHEET_MATERIAL_ENABLED;
  @StorageProp(STORAGE_KEY_SHEET_MATERIAL_LEVEL) private sheetMaterialLevel: number = DEFAULT_SHEET_MATERIAL_LEVEL;
  @StorageProp(STORAGE_KEY_ACCOUNTS_CHANGED) @Watch('onAccountChanged') private accountRevision: number = 0;
  @StorageProp(STORAGE_KEY_FILTER_REVISION) @Watch('applyFilters') private filterRevision: number = 0;
  @State private pageMotion: PageTransitionMotion = new PageTransitionMotion();
  @State private categories: GlobalTrendCategory[] = [];
  @State private topics: GlobalTrendTopic[] = [];
  @State private countries: GlobalTrendCountry[] = [];
  @State private visiblePosts: Tweet[] = [];
  @State private loading: boolean = true;
  @State private refreshing: boolean = false;
  @State private loadingMore: boolean = false;
  @State private status: string = '';
  @State private countryOpen: boolean = false;
  @State private countryName: string = '';
  @State private countryFlag: string = '🌍';
  @State private countryIsGlobal: boolean = true;
  @State private countryPath: string = '';
  @State private selectedCategory: string = '';
  @State private selectedTopic: string = '';
  @BuilderParam postBuilder: (tweet: Tweet) => void = this.EmptyPost;
  onOpenDestination: (url: string) => void = (): void => {};
  private posts: Tweet[] = [];
  private currentTagPath: string = 'global-trending/tagBrowserPage';
  private currentTimelinePath: string = 'global-trending/timelineGeneric?time=Day';
  private countryTagPath: string = '';
  private countryTimelinePath: string = '';
  private timelineId: string = '';
  private nextPath: string = '';
  private revision: number = 0;
  private generation: number = -1;
  private alive: boolean = false;
  private scroller: Scroller = new Scroller();

  @Builder private EmptyPost(_tweet: Tweet): void { Column() }

  aboutToAppear(): void {
    this.alive = true;
    xPrivateClient.load(getContext(this) as common.UIAbilityContext);
    this.generation = xPrivateClient.sessionGeneration();
    void this.loadGlobalTrends();
  }

  aboutToDisappear(): void { this.alive = false; this.revision++; }

  private text(resource: Resource): string {
    return (getContext(this) as common.UIAbilityContext).resourceManager.getStringSync(resource);
  }

  private onAccountChanged(): void {
    this.revision++;
    this.posts = []; this.visiblePosts = []; this.categories = []; this.topics = []; this.countries = [];
    this.nextPath = ''; this.countryName = ''; this.countryFlag = '🌍';
    this.countryIsGlobal = true;
    this.countryPath = ''; this.countryOpen = false;
    this.countryTagPath = ''; this.countryTimelinePath = ''; this.timelineId = '';
    this.selectedCategory = ''; this.selectedTopic = '';
    xPrivateClient.load(getContext(this) as common.UIAbilityContext);
    this.generation = xPrivateClient.sessionGeneration();
    if (this.alive) { void this.loadGlobalTrends(); }
  }

  private applyFilters(): void {
    const settings: ContentFilterSettings = new ContentFilterSettings(
      AppStorage.get<boolean>('harmonyx.filter_only_media') ?? false,
      AppStorage.get<boolean>('harmonyx.filter_hide_reposts') ?? false,
      AppStorage.get<boolean>('harmonyx.filter_hide_replies') ?? false,
      AppStorage.get<string>('harmonyx.filter_keywords') ?? '',
      AppStorage.get<string>('harmonyx.filter_muted_users') ?? '',
      AppStorage.get<boolean>('harmonyx.filter_hide_ads') ?? true,
      AppStorage.get<string>('harmonyx.filter_languages') ?? '');
    this.visiblePosts = contentFilterStore.filter(this.posts, settings);
  }

  private async loadGlobalTrends(): Promise<void> {
    const revision: number = ++this.revision;
    const generation: number = xPrivateClient.sessionGeneration();
    this.loading = true; this.loadingMore = false; this.refreshing = false;
    this.status = ''; this.posts = []; this.visiblePosts = []; this.nextPath = '';
    try {
      if (!xPrivateClient.isSignedIn()) { this.status = this.text($r('app.string.user_list_sign_in')); return; }
      const homeResult: XPrivateResult = await xPrivateClient.globalTrends('global-trending/home');
      if (!this.alive || revision !== this.revision || generation !== xPrivateClient.sessionGeneration()) { return; }
      if (!homeResult.ok) { this.status = this.text($r('app.string.explore_section_failed')); return; }
      const home: GlobalTrendsPage = JSON.parse(homeResult.body) as GlobalTrendsPage;
      this.countries = home.countries;
      this.currentTagPath = home.tagBrowserPath;
      this.currentTimelinePath = home.timelineBrowserPath;
      this.applyCurrentCountry();
      const topicResult: XPrivateResult = await xPrivateClient.globalTrends(home.topicBrowserPath);
      const tagResult: XPrivateResult = await xPrivateClient.globalTrends(this.currentTagPath);
      const timelineConfig: XPrivateResult = await xPrivateClient.globalTrends(this.currentTimelinePath);
      if (!this.alive || revision !== this.revision || generation !== xPrivateClient.sessionGeneration()) { return; }
      if (topicResult.ok) {
        this.categories = (JSON.parse(topicResult.body) as GlobalTrendsPage).categories;
      }
      if (tagResult.ok) {
        this.topics = (JSON.parse(tagResult.body) as GlobalTrendsPage).topics;
      }
      if (!timelineConfig.ok) { this.status = this.text($r('app.string.explore_section_failed')); return; }
      this.timelineId = (JSON.parse(timelineConfig.body) as GlobalTrendsPage).timelineId;
      if (this.timelineId.length === 0) { this.status = this.text($r('app.string.explore_section_empty')); return; }
      await this.loadTimeline(revision, generation, true);
    } catch (_error) {
      if (this.alive && revision === this.revision && generation === xPrivateClient.sessionGeneration()) {
        this.status = this.text($r('app.string.explore_section_failed'));
      }
    } finally {
      if (this.alive && revision === this.revision && generation === xPrivateClient.sessionGeneration()) {
        this.loading = false; this.loadingMore = false; this.refreshing = false;
      }
    }
  }

  private async loadTimeline(revision: number, generation: number, reset: boolean): Promise<void> {
    const cursor: string = reset ? '' : this.nextPath;
    const result: XPrivateResult = await xPrivateClient.genericTimelineById(this.timelineId, cursor, 20);
    if (!this.alive || revision !== this.revision || generation !== xPrivateClient.sessionGeneration()) { return; }
    if (!result.ok) {
      this.status = this.text($r('app.string.explore_section_failed'));
      return;
    }
    const page: TweetPage | null = XTimelineParser.parse(result.body);
    if (page === null) {
      this.status = this.text($r('app.string.explore_section_failed'));
      return;
    }
    const incoming: Tweet[] = page.tweets.filter((tweet: Tweet): boolean => reset ||
      !this.posts.some((old: Tweet): boolean => old.id === tweet.id));
    this.posts = reset ? incoming : this.posts.concat(incoming);
    this.nextPath = page.nextToken === cursor ? '' : page.nextToken;
    this.status = '';
    this.applyFilters();
  }

  private async loadSelection(tagPath: string, timelinePath: string): Promise<void> {
    if (tagPath.length === 0 || timelinePath.length === 0) { return; }
    const revision: number = ++this.revision;
    const generation: number = xPrivateClient.sessionGeneration();
    this.loading = true; this.loadingMore = false; this.status = '';
    this.posts = []; this.visiblePosts = []; this.nextPath = '';
    try {
      this.currentTagPath = tagPath;
      this.currentTimelinePath = timelinePath;
      const tagResult: XPrivateResult = await xPrivateClient.globalTrends(tagPath);
      const configResult: XPrivateResult = await xPrivateClient.globalTrends(timelinePath);
      if (!this.alive || revision !== this.revision || generation !== xPrivateClient.sessionGeneration()) { return; }
      if (tagResult.ok) {
        this.topics = (JSON.parse(tagResult.body) as GlobalTrendsPage).topics;
      }
      if (!configResult.ok) { this.status = this.text($r('app.string.explore_section_failed')); return; }
      this.timelineId = (JSON.parse(configResult.body) as GlobalTrendsPage).timelineId;
      if (this.timelineId.length > 0) { await this.loadTimeline(revision, generation, true); }
    } catch (_error) {
      if (this.alive && revision === this.revision) {
        this.status = this.text($r('app.string.explore_section_failed'));
      }
    } finally {
      if (this.alive && revision === this.revision) {
        this.loading = false; this.refreshing = false;
      }
    }
  }

  private async loadMore(): Promise<void> {
    if (this.loading || this.loadingMore || this.nextPath.length === 0) { return; }
    const revision: number = this.revision;
    const generation: number = xPrivateClient.sessionGeneration();
    this.loadingMore = true;
    try {
      await this.loadTimeline(revision, generation, false);
    } finally {
      if (revision === this.revision) { this.loadingMore = false; }
    }
  }

  private selectCategory(category: GlobalTrendCategory): void {
    this.selectedCategory = category.title; this.selectedTopic = '';
    const baseTagPath: string = this.withoutQueryParameter(this.currentTagPath, 'tag');
    const baseTimelinePath: string = this.withoutQueryParameter(this.currentTimelinePath, 'tag');
    const topicPath: string = category.topicId.length > 0 ?
      this.appendQuery(baseTagPath, 'topic_id', encodeURIComponent(category.topicId)) :
      category.path;
    const timelinePath: string = category.topicId.length > 0 ?
      this.appendQuery(baseTimelinePath, 'topic_id', encodeURIComponent(category.topicId)) :
      baseTimelinePath;
    void this.loadSelection(topicPath, timelinePath);
  }

  private selectTopic(topic: GlobalTrendTopic): void {
    this.selectedTopic = topic.title;
    const tag: string = encodeURIComponent(topic.query.length > 0 ? topic.query : topic.title);
    void this.loadSelection(
      this.appendQuery(this.currentTagPath, 'tag', tag),
      this.appendQuery(this.currentTimelinePath, 'tag', tag));
  }

  private selectCountry(country: GlobalTrendCountry): void {
    this.countryOpen = false; this.countryFlag = country.flag;
    this.countryIsGlobal = country.name === 'Global';
    this.countryName = country.flag + ' ' + country.name; this.countryPath = country.path;
    this.countryTagPath = country.tagPath;
    this.countryTimelinePath = country.timelinePath;
    this.selectedCategory = ''; this.selectedTopic = '';
    void this.loadSelection(country.tagPath, country.timelinePath);
  }

  private applyCurrentCountry(): void {
    for (let i: number = 0; i < this.countries.length; i++) {
      const country: GlobalTrendCountry = this.countries[i];
      if (country.tagPath === this.currentTagPath ||
        country.timelinePath === this.currentTimelinePath) {
        this.countryName = country.flag + ' ' + country.name;
        this.countryFlag = country.flag;
        this.countryIsGlobal = country.name === 'Global';
        this.countryPath = country.path;
        this.countryTagPath = country.tagPath;
        this.countryTimelinePath = country.timelinePath;
        return;
      }
    }
    if (this.countries.length > 0) {
      const global: GlobalTrendCountry = this.countries[0];
      this.countryName = global.flag + ' ' + global.name;
      this.countryFlag = global.flag;
      this.countryIsGlobal = true;
      this.countryPath = global.path;
      this.countryTagPath = global.tagPath;
      this.countryTimelinePath = global.timelinePath;
    }
  }

  private appendQuery(path: string, key: string, value: string): string {
    const clean: string = this.withoutQueryParameter(path, key);
    return clean + (clean.indexOf('?') >= 0 ? '&' : '?') + key + '=' + value;
  }

  private withoutQueryParameter(path: string, key: string): string {
    const queryIndex: number = path.indexOf('?');
    if (queryIndex < 0) { return path; }
    const base: string = path.substring(0, queryIndex);
    const parts: string[] = path.substring(queryIndex + 1).split('&');
    const kept: string[] = [];
    for (let i: number = 0; i < parts.length; i++) {
      if (parts[i].length > 0 && parts[i].split('=')[0] !== key) {
        kept.push(parts[i]);
      }
    }
    return kept.length > 0 ? base + '?' + kept.join('&') : base;
  }

  private resetSelection(): void {
    this.selectedCategory = ''; this.selectedTopic = '';
    const tagPath: string = this.countryTagPath.length > 0 ? this.countryTagPath : 'global-trending/tagBrowserPage';
    const timelinePath: string = this.countryTimelinePath.length > 0 ?
      this.countryTimelinePath : 'global-trending/timelineGeneric?time=Day';
    void this.loadSelection(tagPath, timelinePath);
  }

  private onRefresh(): void {
    if (this.selectedCategory.length === 0 && this.selectedTopic.length === 0) {
      void this.loadSelection(this.currentTagPath, this.currentTimelinePath);
      return;
    }
    this.resetSelection();
  }

  @Builder
  private CategoryStrip(): void {
    Scroll() {
      Row({ space: 8 }) {
        ForEach(this.categories, (category: GlobalTrendCategory) => {
          Button({ type: ButtonType.Normal, stateEffect: true }) {
            Stack({ alignContent: Alignment.TopStart }) {
              ProxyMediaImage({ url: category.imageUrl, fillParent: true })
              Text(category.title).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
                .fontWeight(FontWeight.Bold).fontColor($r('app.color.post_card_overlay_text'))
                .padding(10).shadow({ radius: 3, color: $r('app.color.post_card_title_overlay') })
            }.width($r('app.float.global_trends_category_width')).height($r('app.float.global_trends_category_height'))
          }.borderRadius($r('app.float.global_trends_card_radius')).clip(true)
            .backgroundColor(fieldSurfaceColor(this.displayMode, this.darkSurface))
            .border({ width: this.selectedCategory === category.title ? 2 : 0, color: this.accentColor })
            .id('global-trends-category-' + category.id).accessibilityText(category.title)
            .onClick((): void => this.selectCategory(category))
        }, (category: GlobalTrendCategory): string => category.id)
      }.padding({ left: 16, right: 16 })
    }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%')
  }

  @Builder
  private TopicStrip(): void {
    Scroll() {
      Row({ space: 8 }) {
        ForEach(this.topics, (topic: GlobalTrendTopic) => {
          Button(topic.title).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S'))
            .fontColor(this.selectedTopic === topic.title ? this.accentColor :
              pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent))
            .backgroundColor(Color.Transparent).border({ width: 1, color: $r('app.color.divider') })
            .height($r('app.float.global_trends_topic_height')).padding({ left: 14, right: 14 })
            .id('global-trends-topic-' + topic.id).onClick((): void => this.selectTopic(topic))
        }, (topic: GlobalTrendTopic): string => topic.id)
      }.padding({ left: 16, right: 16 })
    }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%').margin({ top: 12 })
  }

  @Builder
  private FeedHeader(): void {
    Column({ space: 0 }) {
      if (this.categories.length > 0) { this.CategoryStrip() }
      if (this.topics.length > 0) { this.TopicStrip() }
      Row() {
        Text($r('app.string.global_trends_today')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Title_S')).fontWeight(FontWeight.Bold)
        Blank()
        if (this.selectedCategory.length > 0 || this.selectedTopic.length > 0) {
          Button(this.selectedTopic || this.selectedCategory).fontSize($r('sys.float.Body_S'))
            .fontColor(this.accentColor).backgroundColor(Color.Transparent)
            .accessibilityDescription(this.text($r('app.string.global_trends_reset')))
            .onClick((): void => this.resetSelection())
        }
      }.width('100%').padding(16).foregroundColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent))
      if (this.loading) {
        LoadingProgress().width(28).height(28).color(this.accentColor).margin(24)
      }
    }.width('100%')
  }

  @Builder
  private FeedFooter(): void {
    Column({ space: 12 }) {
      if (this.status.length > 0) {
        Text(this.status).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
          .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
        Button($r('app.string.common_retry')).onClick((): void => {
          this.onRefresh();
        })
      } else if (!this.loading && this.visiblePosts.length === 0) {
        Text($r('app.string.explore_section_empty')).fontFamily(this.appFontFamily)
          .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
      } else if (this.loadingMore) {
        LoadingProgress().width(24).height(24).color(this.accentColor)
      } else if (this.nextPath.length > 0) {
        Button($r('app.string.timeline_load_more')).onClick((): void => { void this.loadMore(); })
      }
    }.width('100%').padding(24)
  }

  @Builder
  private CountrySheet(): void {
    Column({ space: 12 }) {
      Text($r('app.string.global_trends_countries')).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Title_M')).fontWeight(FontWeight.Bold).padding(16)
      List({ space: 8 }) {
        ForEach(this.countries, (country: GlobalTrendCountry) => {
          ListItem() {
            Button({ type: ButtonType.Normal }) {
              Row({ space: 10 }) {
                Text(country.flag).fontSize($r('sys.float.Title_M'))
                Text(country.name).fontFamily(this.appFontFamily)
                  .fontSize($r('sys.float.Body_L'))
                  .fontColor(country.path === this.countryPath ? this.accentColor : $r('app.color.text_primary'))
                  .layoutWeight(1)
                if (country.path === this.countryPath) {
                  SymbolGlyph($r('sys.symbol.checkmark')).fontSize(18)
                    .fontColor([this.accentColor])
                }
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 14, bottom: 14 })
            }
              .width('100%').borderRadius($r('app.float.global_trends_card_radius'))
              .backgroundColor(fieldSurfaceColor(this.displayMode, this.darkSurface))
              .accessibilityText(country.flag + ' ' + country.name)
              .id('global-trends-country-' + country.code).onClick((): void => this.selectCountry(country))
          }
        }, (country: GlobalTrendCountry): string => country.code)
      }.layoutWeight(1).width('100%').padding({ left: 16, right: 16, bottom: this.bottomInset + 16 })
    }.width('100%').height('100%').foregroundColor($r('app.color.text_primary'))
  }

  build(): void {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        appPageBackground()
        Refresh({ refreshing: $$this.refreshing }) {
          AdaptivePostFeed({ scroller: this.scroller, feedId: 'global-trends-feed',
            itemKeys: this.visiblePosts.map((tweet: Tweet): string => tweet.id),
            startOffset: DesktopLayout.active(this.desktopLayout, this.breakpoint) ? 0 : this.statusBarHeight + 60,
            endOffset: this.bottomInset + 16,
            header: (): void => this.FeedHeader(),
            item: (index: number): void => this.postBuilder(this.visiblePosts[index]),
            footer: (): void => this.FeedFooter(),
            onLoadMore: (): void => { if (this.status.length === 0) { void this.loadMore(); } } })
        }.width('100%').height('100%').onRefreshing((): void => this.onRefresh())
      }.width('100%').height('100%')
        .bindSheet($$this.countryOpen, this.CountrySheet(), sheetMaterialOptions({
          height: SheetSize.LARGE, showClose: true, dragBar: true,
          backgroundColor: pageCanvasColor(this.displayMode, this.darkSurface, this.pageBackgroundValue)
        }, this.sheetMaterialEnabled, this.sheetMaterialLevel, this.breakpoint))
    }.id('global-trends-page').titleMode(HdsNavDestinationTitleMode.MINI)
      .titleBar({ avoidLayoutSafeArea: true, content: {
        title: { mainTitle: $r('app.string.global_trends_title') },
        menu: { value: [{ content: {
          icon: this.countryIsGlobal ? $r('sys.symbol.worldclock') : undefined,
          label: this.countryIsGlobal ? undefined : this.countryFlag,
          type: this.countryIsGlobal ? IconStyleMode.NORMAL : TextStyleMode.SINGLE_CHARACTER,
          action: (): void => { this.countryOpen = true; }
        } }] },
        divider: { showType: DividerShowType.OFF }
      }, style: destinationTitleBarStyle(ScrollEffectType.GRADIENT_BLUR, this.displayMode, this.darkSurface, this.titleBarStyleMode) })
      .bindToScrollable([this.scroller])
      .scale({ x: this.pageMotion.scale, y: this.pageMotion.scale }).opacity(this.pageMotion.opacity)
      .systemTransition(pageSystemTransition(this.pageTransitionMode))
      .onReady((context: NavDestinationContext): void => { this.pageMotion.attach(context); })
      .onShown((): void => { if (this.generation !== xPrivateClient.sessionGeneration()) { this.onAccountChanged(); } })
      .backgroundColor(pageCanvasColor(this.displayMode, this.darkSurface, this.pageBackgroundValue))
      .onBackPressed((): boolean => { ResponsiveLayout.closeContentDestination(this.pageStack); return true; })
  }
}
