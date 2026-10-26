import { common } from '@kit.AbilityKit';
import promptAction from '@ohos.promptAction';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { homeTimelineStore, TimelineTopic, STORAGE_KEY_HOME_TIMELINE_REVISION } from '../services/HomeTimelineStore';
import { tabOrderSettingsStore, STORAGE_KEY_BOTTOM_TAB_ORDER, STORAGE_KEY_HOME_TAB_ORDER } from '../services/TabOrderSettingsStore';
import { moveTabId, orderedTabIds } from '../utils/TabOrder';
import { pageTextColor } from '../utils/ThemeColors';

@Component
export struct TabOrderSettings {
  @Prop home: boolean = false;
  @StorageProp(STORAGE_KEY_BOTTOM_TAB_ORDER) private bottomOrder: string = '';
  @StorageProp(STORAGE_KEY_HOME_TAB_ORDER) private homeOrder: string = '';
  @StorageProp(STORAGE_KEY_HOME_TIMELINE_REVISION) private homeRevision: number = 0;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp('harmonyx.page_background') private pageBackgroundValue: string = '';

  private ids(): string[] {
    const available: string[] = this.home ? ['for-you', 'following'] : ['0', '1', '2', '3', '4'];
    if (this.home) {
      const revision: number = this.homeRevision;
      for (const topic of homeTimelineStore.pinnedTopics()) { available.push(topic.id); }
    }
    return orderedTabIds(this.home ? this.homeOrder : this.bottomOrder, available);
  }

  private label(id: string): ResourceStr {
    if (this.home) {
      if (id === 'for-you') { return $r('app.string.home_for_you'); }
      if (id === 'following') { return $r('app.string.home_following'); }
      const topic: TimelineTopic | null = homeTimelineStore.topicById(id);
      return topic === null ? id : topic.displayTitle || topic.title;
    }
    const labels: Resource[] = [$r('app.string.home_title'), $r('app.string.explore_title'),
      $r('app.string.tab_alerts'), $r('app.string.messages_title'), $r('app.string.tab_me')];
    return labels[Number(id)];
  }

  private save(value: string): void {
    if (!tabOrderSettingsStore.save(getContext(this) as common.UIAbilityContext, this.home, value)) {
      promptAction.showToast({ message: $r('app.string.settings_interaction_save_failed') });
    }
  }

  @Builder
  private MoveButton(id: string, index: number, step: number): void {
    Button({ type: ButtonType.Circle }) {
      SymbolGlyph(step < 0 ? $r('sys.symbol.chevron_up') : $r('sys.symbol.chevron_down'))
        .fontSize(16).fontColor([pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent)])
    }.width(40).height(40).backgroundColor(Color.Transparent)
      .enabled(step < 0 ? index > 0 : index < this.ids().length - 1)
      .opacity((step < 0 ? index > 0 : index < this.ids().length - 1) ? 1 : 0.25)
      .accessibilityText(step < 0 ? $r('app.string.settings_tab_move_up') : $r('app.string.settings_tab_move_down'))
      .onClick((): void => this.save(moveTabId(this.ids(), id, step).join(',')))
  }

  build(): void {
    Column({ space: 4 }) {
      Row() {
        Text(this.home ? $r('app.string.settings_home_tab_order') : $r('app.string.settings_bottom_tab_order'))
          .fontFamily(this.appFontFamily).fontSize($r('sys.float.Title_S')).fontWeight(FontWeight.Bold)
          .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent)).layoutWeight(1)
        Button($r('app.string.settings_tab_order_reset')).fontSize($r('sys.float.Body_S'))
          .backgroundColor(Color.Transparent).onClick((): void => this.save(''))
      }.width('100%')
      Text($r('app.string.settings_tab_order_desc')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
        .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)).width('100%')
      ForEach(this.ids(), (id: string, index: number) => {
        Row({ space: 8 }) {
          Text((this.ids().indexOf(id) + 1).toString()).fontSize($r('sys.float.Body_S')).width(24)
            .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
          Text(this.label(id)).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).layoutWeight(1)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent))
          this.MoveButton(id, this.ids().indexOf(id), -1)
          this.MoveButton(id, this.ids().indexOf(id), 1)
        }.width('100%').constraintSize({ minHeight: 48 })
          .id((this.home ? 'home-tab-order-' : 'bottom-tab-order-') + id)
      }, (id: string): string => id)
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
}
