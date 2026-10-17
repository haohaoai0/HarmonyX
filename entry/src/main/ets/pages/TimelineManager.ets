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
  @State private pinnedIds: string[] = [];
  @State private search: string = '';
  @State private expanded: boolean = true;
  private topics: TimelineTopic[] = homeTimelineStore.allTopics();
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.reload();
  }

  private reload(): void {
    this.pinnedIds = this.topics.filter((topic: TimelineTopic): boolean =>
      homeTimelineStore.isPinned(topic.id)).map((topic: TimelineTopic): string => topic.id);
  }

  private text(resource: Resource): string {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    return context.resourceManager.getStringSync(resource);
  }

  private matches(topic: TimelineTopic): boolean {
    return this.text(topic.title).toLowerCase().indexOf(this.search.trim().toLowerCase()) >= 0;
  }

  private pinnedTopics(): TimelineTopic[] {
    return this.topics.filter((topic: TimelineTopic): boolean => this.pinnedIds.indexOf(topic.id) >= 0 && this.matches(topic));
  }

  private availableTopics(): TimelineTopic[] {
    return this.topics.filter((topic: TimelineTopic): boolean => this.pinnedIds.indexOf(topic.id) < 0 && this.matches(topic));
  }

  private pin(topic: TimelineTopic, pinned: boolean): void {
    if (!homeTimelineStore.setPinned(getContext(this), topic.id, pinned)) {
      promptAction.showToast({ message: this.text($r('app.string.timeline_save_failed')) });
    }
    this.reload();
  }

  private openTopic(topic: TimelineTopic): void {
    ResponsiveLayout.closeToMain(this.pageStack);
    AppStorage.setOrCreate<string>('harmonyx.search_request', topic.query);
  }

  @Builder
  private TopicRow(topic: TimelineTopic, pinned: boolean): void {
    Row({ space: 14 }) {
      Button({ type: ButtonType.Normal }) {
        Row({ space: 14 }) {
          Stack() {
            SymbolGlyph(topic.icon).fontSize($r('app.float.timeline_symbol_size')).fontColor([$r('app.color.text_primary')])
          }
          .width($r('app.float.timeline_topic_icon_size')).height($r('app.float.timeline_topic_icon_size'))
          .borderRadius(12).backgroundColor(fieldSurfaceColor(this.displayMode, this.darkSurface))
          Text(topic.title).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_primary'))
            .layoutWeight(1).textAlign(TextAlign.Start).maxLines(2)
        }
        .width('100%')
      }
      .padding(0).layoutWeight(1).backgroundColor(Color.Transparent)
      .onClick((): void => this.openTopic(topic))
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph(pinned ? $r('sys.symbol.minus_circle_fill') : $r('sys.symbol.plus_circle_fill'))
          .fontSize($r('app.float.timeline_symbol_size'))
          .fontColor([pinned ? $r('app.color.text_secondary') : $r('app.color.timeline_pin_accent')])
      }
      .width(44).height(44).padding(8).backgroundColor(Color.Transparent)
      .id('timeline-pin-' + topic.id)
      .accessibilityText(this.text(pinned ? $r('app.string.timeline_unpin') : $r('app.string.timeline_pin')) +
        ' ' + this.text(topic.title))
      .onClick((): void => this.pin(topic, !pinned))
    }
    .width('100%').constraintSize({ minHeight: $r('app.float.timeline_topic_row_height') })
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
  }

  @Builder
  private TimelineList(): void {
      List({ scroller: this.scroller }) {
        ListItem() {
          Search({ value: this.search, placeholder: this.text($r('app.string.timeline_search')) })
            .keyboardAppearance(KeyboardAppearance.IMMERSIVE)
            .height($r('app.float.timeline_search_height')).backgroundColor(fieldSurfaceColor(this.displayMode, this.darkSurface))
            .fontColor($r('app.color.text_primary')).id('timeline-search')
            .onChange((value: string): void => { this.search = value; })
            .margin({ left: 8, right: 8, top: 8, bottom: 8 })
        }
        ListItem() {
          Text($r('app.string.timeline_pinned')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary')).padding({ left: 16, top: 12, bottom: 12 })
        }
        if (this.pinnedTopics().length === 0) {
          ListItem() {
            Text(this.search.trim().length > 0 ? $r('app.string.timeline_no_results') : $r('app.string.timeline_pinned_empty')).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_secondary'))
              .padding({ left: 16, right: 16, top: 10, bottom: 20 })
          }
        } else {
          ForEach(this.pinnedTopics(), (topic: TimelineTopic) => {
            ListItem() { this.TopicRow(topic, true) }
          }, (topic: TimelineTopic): string => 'pinned-' + topic.id)
        }
        ListItem() {
          Button({ type: ButtonType.Normal }) {
            Row() {
              Text($r('app.string.timeline_follow')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary')).layoutWeight(1).textAlign(TextAlign.Start)
              SymbolGlyph($r('sys.symbol.chevron_down')).fontSize(16).fontColor([$r('app.color.text_primary')])
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
                .fontColor($r('app.color.text_secondary')).padding(16)
            }
          }
        }
      }
      .width('100%').height('100%').scrollBar(BarState.Off)
      .contentStartOffset(this.desktop() ? 8 : this.statusBarHeight + 60).contentEndOffset(this.bottomInset + 20)
  }

  build(): void {
    HdsNavDestination() {
      if (this.desktop()) {
        Stack({ alignContent: Alignment.Center }) {
        Column() {
          Row() {
            Text($r('app.string.timeline_title')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Title_M')).fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary')).layoutWeight(1)
            Button({ type: ButtonType.Circle }) {
              SymbolGlyph($r('sys.symbol.xmark')).fontSize(22).fontColor([$r('app.color.text_primary')])
            }.width(40).height(40).backgroundColor(Color.Transparent).onClick((): void => { this.pageStack.pop(); })
          }.width('100%').padding(12)
          Column() { this.TimelineList() }.width('100%').layoutWeight(1)
        }.width('100%').constraintSize({ maxWidth: $r('app.float.desktop_modal_width') })
          .height(Math.min(760, this.desktopWindowHeight - 48))
          .backgroundColor(pageSurfaceColor(this.displayMode, this.darkSurface))
          .borderRadius($r('app.float.desktop_card_radius')).clip(true)
        }.width('100%').height('100%')
      } else { this.TimelineList() }
    }
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
    .backgroundColor(this.desktop() ? '#88000000' : pageSurfaceColor(this.displayMode, this.darkSurface));
  }
}
