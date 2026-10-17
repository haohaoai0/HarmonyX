import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import {
  FOLLOWING_SORT_LATEST, FOLLOWING_SORT_TRENDING, homeTimelineStore,
  STORAGE_KEY_HOME_TIMELINE_REVISION, TimelineTopic
} from '../services/HomeTimelineStore';

@Component
export struct PauseTopicsSheet {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageLink('harmonyx.accent_color') accentColor: string = '#007DFF';
  @StorageProp('harmonyx.navigation_indicator_height') bottomInset: number = 0;
  @StorageLink(STORAGE_KEY_HOME_TIMELINE_REVISION) @Watch('reload') revision: number = 0;
  @State private pausedIds: string[] = [];
  private topics: TimelineTopic[] = homeTimelineStore.pauseTopics();

  aboutToAppear(): void {
    this.reload();
  }

  private reload(): void {
    this.pausedIds = this.topics.filter((topic: TimelineTopic): boolean =>
      homeTimelineStore.isPaused(topic.id)).map((topic: TimelineTopic): string => topic.id);
  }

  private saved(success: boolean): void {
    this.reload();
    if (!success) {
      const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      promptAction.showToast({ message: context.resourceManager.getStringSync($r('app.string.timeline_save_failed')) });
    }
  }

  build(): void {
    Column() {
      Column({ space: 3 }) {
        Text($r('app.string.timeline_pause_title')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_L')).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text($r('app.string.timeline_pause_description')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary'))
      }
      .width('100%').padding({ top: 14, bottom: 14 })
      List() {
        ForEach(this.topics, (topic: TimelineTopic) => {
          ListItem() {
            Row({ space: 18 }) {
              SymbolGlyph(topic.icon).fontSize($r('app.float.timeline_symbol_size'))
                .fontColor([$r('app.color.text_primary')]).width(26)
              Text(topic.title).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_primary'))
                .layoutWeight(1).maxLines(2)
              Toggle({ type: ToggleType.Switch, isOn: this.pausedIds.indexOf(topic.id) >= 0 })
                .selectedColor(this.accentColor).id('pause-topic-' + topic.id)
                .accessibilityText(topic.title)
                .onChange((paused: boolean): void => {
                  this.saved(homeTimelineStore.setPaused(getContext(this), topic.id, paused));
                })
            }
            .width('100%').constraintSize({ minHeight: $r('app.float.timeline_pause_row_height') })
            .padding({ left: 18, right: 18, top: 8, bottom: 8 })
          }
        }, (topic: TimelineTopic): string => topic.id)
      }
      .width('100%').layoutWeight(1).scrollBar(BarState.Off)
      Button($r('app.string.timeline_reset'), { type: ButtonType.Capsule })
        .width('100%').height($r('app.float.timeline_reset_height'))
        .fontSize($r('sys.float.Body_L')).fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_on_accent')).backgroundColor($r('app.color.timeline_reset_background'))
        .id('pause-topics-reset')
        .onClick((): void => this.saved(homeTimelineStore.resetPauses(getContext(this))))
        .margin({ top: 14, bottom: 12 })
    }
    .width('100%').height('100%').padding({ left: 16, right: 16, bottom: this.bottomInset })
  }
}

@Component
export struct FollowingOrderSheet {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageLink('harmonyx.accent_color') accentColor: string = '#007DFF';
  @StorageProp('harmonyx.navigation_indicator_height') bottomInset: number = 0;
  @State private order: number = FOLLOWING_SORT_LATEST;
  onManage: () => void = (): void => {};

  aboutToAppear(): void {
    this.order = homeTimelineStore.followingOrder();
  }

  private select(order: number): void {
    if (homeTimelineStore.setFollowingOrder(getContext(this), order)) {
      this.order = order;
    } else {
      const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      promptAction.showToast({ message: context.resourceManager.getStringSync($r('app.string.timeline_save_failed')) });
    }
  }

  @Builder
  private Option(title: Resource, icon: Resource, value: number): void {
    Row({ space: 18 }) {
      SymbolGlyph(icon).fontSize($r('app.float.timeline_symbol_size')).fontColor([$r('app.color.text_primary')])
      Text(title).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_primary')).layoutWeight(1)
      Radio({ value: value.toString(), group: 'home-timeline-order' })
        .checked(this.order === value).radioStyle({ checkedBackgroundColor: this.accentColor })
        .width(24).height(24).accessibilityText(title).id('following-order-' + value.toString())
        .onChange((checked: boolean): void => { if (checked) { this.select(value); } })
    }
    .width('100%').constraintSize({ minHeight: $r('app.float.timeline_sort_row_height') })
    .padding({ left: 26, right: 26, top: 10, bottom: 10 })
    .onClick((): void => this.select(value))
  }

  build(): void {
    Column() {
      Scroll() {
        Column() {
          Text($r('app.string.timeline_sort_title')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary')).width('100%').padding({ left: 26, top: 20, bottom: 14 })
          this.Option($r('app.string.timeline_sort_latest'), $r('sys.symbol.star'), FOLLOWING_SORT_LATEST)
          this.Option($r('app.string.timeline_sort_trending'), $r('sys.symbol.airplane'), FOLLOWING_SORT_TRENDING)
          Divider().color($r('app.color.divider')).margin({ top: 10 })
          Button({ type: ButtonType.Normal }) {
            Row({ space: 18 }) {
              SymbolGlyph($r('sys.symbol.gearshape')).fontSize($r('app.float.timeline_symbol_size'))
                .fontColor([$r('app.color.text_primary')])
              Text($r('app.string.timeline_manage')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L'))
                .fontColor($r('app.color.text_primary')).layoutWeight(1).textAlign(TextAlign.Start)
            }
            .width('100%').padding({ left: 26, right: 26, top: 22, bottom: 22 })
          }
          .width('100%').padding(0).backgroundColor(Color.Transparent).id('manage-timelines')
          .onClick((): void => this.onManage())
        }
        .width('100%')
      }
      .layoutWeight(1).width('100%').scrollBar(BarState.Off)
    }
    .width('100%').height('100%').padding({ bottom: this.bottomInset })
  }
}
