import { homeTimelineSourceStore } from '../services/HomeTimelineSourceStore';
import { localAccountGroupStore } from '../services/LocalAccountGroupStore';
import { ProxyMediaImage } from '../components/ProxyMediaImage';
import type { CommunityRow } from '../models/Community';
import type { ListRow } from '../models/Tweet';
import type { CommunityTimelineRouteParam } from './Communities';
import type { ListTimelineRouteParam } from './Lists';
import { pageTextColor } from '../utils/ThemeColors';
import { appPageBackground } from '../components/PageBackgroundLayer';
import { pageCanvasColor, pageReadingSurfaceColor } from '../utils/ThemeColors';
import { STORAGE_KEY_PAGE_TRANSITION_MODE, DEFAULT_PAGE_TRANSITION_MODE } from '../services/PageTransitionSettingsStore';
import { pageSystemTransition, PageTransitionMotion } from '../utils/PageTransition';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { HdsNavDestination, HdsNavDestinationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { homeTimelineStore, STORAGE_KEY_HOME_TIMELINE_REVISION, TimelineTopic } from '../services/HomeTimelineStore';
import { destinationTitleBarStyle } from '../utils/DestinationTitleBar';
import { DesktopLayout } from '../utils/DesktopLayout';
import { STORAGE_KEY_DESKTOP_LAYOUT } from '../services/LayoutSettingsStore';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';
import { fieldSurfaceColor, pageSurfaceColor } from '../utils/ThemeColors';

@Builder
export function TimelineManagerBuilder(): void {
  TimelineManager();
}

@Component
struct TimelineManager {
  @StorageProp('harmonyx.page_background') private pageBackgroundValue: string = '';
  @State private pageMotion: PageTransitionMotion = new PageTransitionMotion();
  @StorageProp(STORAGE_KEY_PAGE_TRANSITION_MODE) private pageTransitionMode: string = DEFAULT_PAGE_TRANSITION_MODE;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp(STORAGE_KEY_DESKTOP_LAYOUT) desktopLayoutEnabled: boolean = false;
  @StorageProp('harmonyx.breakpoint') breakpoint: string = 'sm';
  @StorageProp('harmonyx.window_height') desktopWindowHeight: number = 780;
  private desktop(): boolean { return DesktopLayout.active(this.desktopLayoutEnabled, this.breakpoint); }
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp('harmonyx.status_bar_height') statusBarHeight: number = 0;
  @StorageProp('harmonyx.navigation_indicator_height') bottomInset: number = 0;
  @StorageProp('harmonyx.display_mode') displayMode: string = '';
  @StorageProp('harmonyx.dark_surface') darkSurface: string = '';
  @StorageLink('harmonyx.title_bar_style_mode') titleBarStyleMode: number = 0;
  @StorageLink(STORAGE_KEY_HOME_TIMELINE_REVISION) @Watch('reload') revision: number = 0;
  @StorageProp('harmonyx.accent_color') private accentColor: string = '#007DFF';
  @State private pinned: TimelineTopic[] = [];
  @State private listSources: TimelineTopic[] = [];
  @State private communitySources: TimelineTopic[] = [];
  @State private groupSources: TimelineTopic[] = [];
  @State private pendingIds: string[] = [];
  @State private editing: boolean = false;
  @State private loadingSources: boolean = false;
  @State private sourceLoadFailed: boolean = false;
  private alive: boolean = true;
  @State private search: string = '';
  @State private expanded: boolean = true;
  @State private topics: TimelineTopic[] = [];
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void { this.alive = true; this.reload(); this.loadSources(); }
  aboutToDisappear(): void { this.alive = false; }

  private async loadSources(): Promise<void> {
    if (this.loadingSources) { return; }
    this.loadingSources = true;
    const ok: boolean = await homeTimelineSourceStore.refresh(getContext(this));
    if (this.alive) { this.loadingSources = false; this.sourceLoadFailed = !ok; this.reload(); }
  }
  private reload(): void {
    this.topics = homeTimelineStore.allTopics();
    this.pinned = homeTimelineStore.pinnedTopics();
    this.listSources = homeTimelineSourceStore.listSources();
    this.communitySources = homeTimelineSourceStore.communitySources();
    this.groupSources = localAccountGroupStore.sources();
  }
  private text(resource: Resource): string { return getContext(this).resourceManager.getStringSync(resource); }
  private label(source: TimelineTopic): string { return source.displayTitle || this.text(source.title); }
  private matches(source: TimelineTopic): boolean { return this.label(source).toLowerCase().indexOf(this.search.trim().toLowerCase()) >= 0; }
  private pinnedTopics(): TimelineTopic[] { return this.pinned.filter((row: TimelineTopic): boolean => this.matches(row)); }
  private availableTopics(): TimelineTopic[] {
    return this.topics.filter((source: TimelineTopic): boolean => !homeTimelineStore.isPinned(source.id) && this.matches(source));
  }
  private availableSources(rows: TimelineTopic[]): TimelineTopic[] {
    return rows.filter((source: TimelineTopic): boolean => !homeTimelineStore.isPinned(source.id) && this.matches(source));
  }
  private async pin(source: TimelineTopic, pinned: boolean): Promise<void> {
    if (this.pendingIds.indexOf(source.id) >= 0) { return; }
    this.pendingIds = [...this.pendingIds, source.id];
    try {
      if (!await homeTimelineSourceStore.setPinned(getContext(this), source, pinned) && this.alive) {
        promptAction.showToast({ message: this.text($r('app.string.timeline_save_failed')) });
      }
    } finally {
      if (this.alive) { this.pendingIds = this.pendingIds.filter((id: string): boolean => id !== source.id); this.reload(); }
    }
  }
  private move(from: number, to: number): void {
    if (!this.editing || this.search.trim().length > 0 || from < 0 || to < 0 || from >= this.pinned.length || to >= this.pinned.length) { return; }
    const rows: TimelineTopic[] = this.pinned.slice(); const source: TimelineTopic = rows.splice(from, 1)[0]; rows.splice(to, 0, source);
    if (!homeTimelineSourceStore.setOrder(getContext(this), rows.map((row: TimelineTopic): string => row.id))) {
      promptAction.showToast({ message: this.text($r('app.string.timeline_save_failed')) });
    }
    this.reload();
  }
  private openTopic(source: TimelineTopic): void {
    if (homeTimelineStore.isPinned(source.id) || source.tag.length > 0 || source.localGroupId.length > 0) {
      ResponsiveLayout.closeToMain(this.pageStack);
      AppStorage.setOrCreate<string>('harmonyx.home_source_request', source.id + '|' + Date.now().toString());
    } else if (source.communityId.length > 0) {
      const row: CommunityRow | undefined = homeTimelineSourceStore.communityRow(source.communityId);
      if (row === undefined) { return; }
      const param: CommunityTimelineRouteParam = { communityId: row.id, title: row.name, description: row.description,
        memberCount: row.memberCount, moderatorCount: row.moderatorCount, bannerUrl: row.bannerUrl,
        joinPolicy: row.joinPolicy, ruleCount: row.ruleCount, rules: row.rules, joined: row.joined, community: row };
      this.pageStack.pushPath({ name: 'CommunityTimeline', param: param });
    } else if (source.listId.length > 0) {
      const row: ListRow | undefined = homeTimelineSourceStore.listRow(source.listId);
      const param: ListTimelineRouteParam = { listId: source.listId, title: this.label(source), row: row };
      this.pageStack.pushPath({ name: 'ListTimeline', param: param });
    }
  }
  @Builder
  private TopicRow(source: TimelineTopic, pinned: boolean): void {
    Row({ space: 14 }) {
      Button({ type: ButtonType.Normal }) {
        Row({ space: 14 }) {
          Stack() {
            if (source.iconText.length > 0) { Text(source.iconText).fontSize($r('app.float.timeline_symbol_size')) }
            else if (source.bannerUrl.length > 0) { ProxyMediaImage({ url: source.bannerUrl, fillParent: true }) }
            else { SymbolGlyph(source.icon).fontSize($r('app.float.timeline_symbol_size')).fontColor([$r('app.color.text_primary')]) }
          }.width($r('app.float.timeline_topic_icon_size')).height($r('app.float.timeline_topic_icon_size'))
            .borderRadius(12).clip(true).backgroundColor(fieldSurfaceColor(this.displayMode, this.darkSurface))
          Column({ space: 3 }) {
            Text(this.label(source)).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L'))
              .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent))
              .width('100%').textAlign(TextAlign.Start).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
            if (source.listId.length > 0 || source.communityId.length > 0) {
              Text(source.communityId.length > 0 ? $r('app.string.timeline_sources_communities') : $r('app.string.timeline_sources_lists'))
                .fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S')).fontColor($r('app.color.text_secondary')).width('100%')
            }
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        }.width('100%')
      }.padding(0).layoutWeight(1).backgroundColor(Color.Transparent).onClick((): void => this.openTopic(source))
      if (pinned && this.editing) {
        Column() {
          Button({ type: ButtonType.Circle }) { SymbolGlyph($r('sys.symbol.arrow_up')).fontSize(16).fontColor([$r('app.color.text_secondary')]) }
            .width(36).height(32).backgroundColor(Color.Transparent).accessibilityText($r('app.string.timeline_move_up'))
            .enabled(this.pinned.findIndex((row: TimelineTopic): boolean => row.id === source.id) > 0)
            .onClick((): void => { const index: number = this.pinned.findIndex((row: TimelineTopic): boolean => row.id === source.id); this.move(index, index - 1); })
          Button({ type: ButtonType.Circle }) { SymbolGlyph($r('sys.symbol.arrow_down')).fontSize(16).fontColor([$r('app.color.text_secondary')]) }
            .width(36).height(32).backgroundColor(Color.Transparent).accessibilityText($r('app.string.timeline_move_down'))
            .enabled(this.pinned.findIndex((row: TimelineTopic): boolean => row.id === source.id) < this.pinned.length - 1)
            .onClick((): void => { const index: number = this.pinned.findIndex((row: TimelineTopic): boolean => row.id === source.id); this.move(index, index + 1); })
        }
        SymbolGlyph($r('sys.symbol.line_3_horizontal')).fontSize(20).fontColor([$r('app.color.text_secondary')]).width(24)
      }
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph(pinned ? $r('sys.symbol.minus_circle_fill') : $r('sys.symbol.plus_circle_fill'))
          .fontSize($r('app.float.timeline_symbol_size')).fontColor([pinned ? $r('app.color.text_secondary') : $r('app.color.timeline_pin_accent')])
      }.width(44).height(44).padding(8).backgroundColor(Color.Transparent).enabled(this.pendingIds.indexOf(source.id) < 0)
        .id('timeline-pin-' + source.id).accessibilityText(this.text(pinned ? $r('app.string.timeline_unpin') : $r('app.string.timeline_pin')) + ' ' + this.label(source))
        .onClick((): void => { this.pin(source, !pinned); })
    }.width('100%').constraintSize({ minHeight: $r('app.float.timeline_topic_row_height') })
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
  }
  @Builder
  private SourceSection(title: Resource, rows: TimelineTopic[]): void {
    if (this.availableSources(rows).length > 0) {
      ListItem() {
        Text(title).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary')).padding({ left: 16, top: 20, bottom: 8 })
      }
      ForEach(this.availableSources(rows), (source: TimelineTopic) => {
        ListItem() { this.TopicRow(source, false) }
      }, (source: TimelineTopic): string => 'available-' + source.id + this.label(source))
    }
  }

  @Builder
  private TimelineList(): void {
      List({ scroller: this.scroller }) {
        ListItem() {
          Search({ value: this.search, placeholder: this.text($r('app.string.timeline_search')) })
            .keyboardAppearance(KeyboardAppearance.IMMERSIVE)
            .height($r('app.float.timeline_search_height')).backgroundColor(fieldSurfaceColor(this.displayMode, this.darkSurface))
            .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, fieldSurfaceColor(this.displayMode, this.darkSurface))).id('timeline-search')
            .onChange((value: string): void => { this.search = value; })
            .margin({ left: 8, right: 8, top: 8, bottom: 8 })
        }
        ListItem() {
          Row() {
            Text($r('app.string.timeline_pinned')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary')).layoutWeight(1)
            Button(this.editing ? $r('app.string.timeline_done') : $r('app.string.timeline_edit'))
              .fontColor(this.accentColor).backgroundColor(Color.Transparent).enabled(this.search.trim().length === 0)
              .onClick((): void => { this.editing = !this.editing; })
          }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 8 })
        }
        if (this.pinnedTopics().length === 0) {
          ListItem() {
            Text(this.search.trim().length > 0 ? $r('app.string.timeline_no_results') : $r('app.string.timeline_sources_pinned_empty')).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_L')).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
              .padding({ left: 16, right: 16, top: 10, bottom: 20 })
          }
        } else {
          ForEach(this.pinnedTopics(), (topic: TimelineTopic) => {
            ListItem() { this.TopicRow(topic, true) }.draggable(this.editing && this.search.trim().length === 0)
          }, (topic: TimelineTopic): string => 'pinned-' + topic.id + this.label(topic))
          .onMove(this.editing && this.search.trim().length === 0 ? (from: number, to: number): void => this.move(from, to) : undefined)
        }
        if (this.loadingSources) { ListItem() { LoadingProgress().width(28).height(28).margin(12) } }
        if (this.sourceLoadFailed) {
          ListItem() {
            Button($r('app.string.timeline_sources_failed')).fontColor(this.accentColor).backgroundColor(Color.Transparent)
              .width('100%').onClick((): void => { this.loadSources(); })
          }
        }
        this.SourceSection($r('app.string.timeline_sources_lists'), this.listSources)
        this.SourceSection($r('app.string.timeline_sources_communities'), this.communitySources)
        ListItem() {
          Button($r('app.string.account_groups_manage')).width('100%').backgroundColor(Color.Transparent)
            .onClick((): void => { this.pageStack.pushPath({ name: 'AccountGroups' }); })
        }
        this.SourceSection($r('app.string.account_groups_title'), this.groupSources)
        ListItem() {
          Button({ type: ButtonType.Normal }) {
            Row() {
              Text($r('app.string.timeline_follow')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontWeight(FontWeight.Bold)
                .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent)).layoutWeight(1).textAlign(TextAlign.Start)
              SymbolGlyph($r('sys.symbol.chevron_down')).fontSize(16).fontColor([pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent)])
                .rotate({ angle: this.expanded ? 0 : -90 })
            }
            .width('100%').padding({ left: 16, right: 26, top: 16, bottom: 8 })
          }
          .width('100%').padding(0).backgroundColor(Color.Transparent).id('timeline-follow-section')
          .onClick((): void => { this.expanded = !this.expanded; })
        }
        if (this.expanded || this.search.trim().length > 0) {
          ForEach(this.availableTopics(), (topic: TimelineTopic) => {
            ListItem() { this.TopicRow(topic, false) }
          }, (topic: TimelineTopic): string => 'available-' + topic.id)
          if (this.availableTopics().length === 0) {
            ListItem() {
              Text($r('app.string.timeline_no_results')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
                .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)).padding(16)
            }
          }
        }
      }
      .width('100%').height('100%').scrollBar(BarState.Off)
      .contentStartOffset(this.desktop() ? 8 : this.statusBarHeight + 60).contentEndOffset(this.bottomInset + 20)
  }

  build(): void {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        appPageBackground()
      if (this.desktop()) {
        Stack({ alignContent: Alignment.Center }) {
        Column() {
          Row() {
            Text($r('app.string.timeline_title')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Title_M')).fontWeight(FontWeight.Bold)
              .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent)).layoutWeight(1)
            Button({ type: ButtonType.Circle }) {
              SymbolGlyph($r('sys.symbol.xmark')).fontSize(22).fontColor([pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent)])
            }.width(40).height(40).backgroundColor(Color.Transparent).onClick((): void => { this.pageStack.pop(); })
          }.width('100%').padding(12)
          Column() { this.TimelineList() }.width('100%').layoutWeight(1)
        }.width('100%').constraintSize({ maxWidth: $r('app.float.desktop_modal_width') })
          .height(Math.min(760, this.desktopWindowHeight - 48))
          .backgroundColor(pageCanvasColor(this.displayMode, this.darkSurface, this.pageBackgroundValue))
          .borderRadius($r('app.float.desktop_card_radius')).clip(true)
        }.width('100%').height('100%')
      } else { this.TimelineList() }
    
      }.width('100%').height('100%')
    }
    .scale({ x: this.pageMotion.scale, y: this.pageMotion.scale })
    .opacity(this.pageMotion.opacity)
    .onReady((context: NavDestinationContext): void => { this.pageMotion.attach(context); })
    .systemTransition(pageSystemTransition(this.pageTransitionMode))
    .mode(this.desktop() ? NavDestinationMode.DIALOG : NavDestinationMode.STANDARD)
    .hideTitleBar(this.desktop()).titleMode(HdsNavDestinationTitleMode.MINI).hideBackButton(false)
    .onBackPressed((): boolean => { ResponsiveLayout.closeContentDestination(this.pageStack); return true; })
    .bindToScrollable([this.scroller])
    .titleBar({
      avoidLayoutSafeArea: true,
      content: { title: { mainTitle: $r('app.string.timeline_title') } },
      style: destinationTitleBarStyle(ScrollEffectType.IMMERSIVE_GRADIENT_BLUR,
        this.displayMode, this.darkSurface, this.titleBarStyleMode)
    })
    .backgroundColor(this.desktop() ? '#88000000' : pageCanvasColor(this.displayMode, this.darkSurface, this.pageBackgroundValue));
  }
}
