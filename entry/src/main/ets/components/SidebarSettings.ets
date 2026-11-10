import { common } from '@kit.AbilityKit';
import promptAction from '@ohos.promptAction';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { sidebarSettingsStore, STORAGE_KEY_SIDEBAR_ORDER, STORAGE_KEY_SIDEBAR_HIDDEN, STORAGE_KEY_SIDEBAR_SEARCH_CAPSULE } from '../services/SidebarSettingsStore';
import { sidebarOrderedIds, sidebarItemLabel, sidebarFooterItem, DEFAULT_SIDEBAR_HIDDEN } from '../utils/SidebarItems';
import { moveTabId } from '../utils/TabOrder';
import { pageTextColor } from '../utils/ThemeColors';

@Component
export struct SidebarSettings {
  @StorageProp(STORAGE_KEY_SIDEBAR_SEARCH_CAPSULE) private searchCapsule: boolean = false;
  @StorageProp(STORAGE_KEY_SIDEBAR_ORDER) private order: string = '';
  @StorageProp(STORAGE_KEY_SIDEBAR_HIDDEN) private hidden: string = DEFAULT_SIDEBAR_HIDDEN;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp('harmonyx.page_background') private pageBackgroundValue: string = '';

  private ids(): string[] { return sidebarOrderedIds(this.order); }

  private save(order: string, hidden: string): void {
    if (!sidebarSettingsStore.save(getContext(this) as common.UIAbilityContext, order, hidden)) {
      promptAction.showToast({ message: $r('app.string.settings_interaction_save_failed') });
    }
  }

  private setVisible(id: string, visible: boolean): void {
    const hidden: string[] = this.hidden.split(',').filter((item: string): boolean => item.length > 0 && item !== id);
    if (!visible) { hidden.push(id); }
    this.save(this.order, hidden.join(','));
  }

  private canMove(id: string, step: number): boolean {
    const ids: string[] = this.ids();
    const target: number = ids.indexOf(id) + step;
    return target >= 0 && target < ids.length && !sidebarFooterItem(id) && !sidebarFooterItem(ids[target]);
  }

  @Builder
  private MoveButton(id: string, step: number): void {
    Button({ type: ButtonType.Circle }) {
      SymbolGlyph(step < 0 ? $r('sys.symbol.chevron_up') : $r('sys.symbol.chevron_down'))
        .fontSize(16).fontColor([pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent)])
    }.width(36).height(40).backgroundColor(Color.Transparent)
      .enabled(this.canMove(id, step))
      .accessibilityText(step < 0 ? $r('app.string.settings_tab_move_up') : $r('app.string.settings_tab_move_down'))
      .onClick((): void => this.save(moveTabId(this.ids(), id, step).join(','), this.hidden))
  }

  build(): void {
    Column({ space: 4 }) {
      Row() {
        Text($r('app.string.settings_sidebar_items')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Title_S')).fontWeight(FontWeight.Bold).layoutWeight(1)
          .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent))
        Button($r('app.string.settings_tab_order_reset')).fontSize($r('sys.float.Body_S'))
          .backgroundColor(Color.Transparent).onClick((): void => this.save('', DEFAULT_SIDEBAR_HIDDEN))
      }.width('100%')
      Text($r('app.string.settings_sidebar_items_desc')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
        .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)).width('100%')
      Row({ space: 12 }) {
        Column({ space: 4 }) {
          Text($r('app.string.settings_sidebar_search_capsule')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L'))
            .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent))
          Text($r('app.string.settings_sidebar_search_capsule_desc')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
            .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Toggle({ type: ToggleType.Switch, isOn: this.searchCapsule })
          .accessibilityText($r('app.string.settings_sidebar_search_capsule'))
          .onChange((enabled: boolean): void => {
            if (!sidebarSettingsStore.saveSearchCapsule(getContext(this) as common.UIAbilityContext, enabled)) {
              promptAction.showToast({ message: $r('app.string.settings_interaction_save_failed') });
            }
          })
      }.width('100%').padding({ top: 12, bottom: 12 }).id('settings-sidebar-search-capsule')
      Divider().color($r('app.color.divider'))
      ForEach(this.ids(), (id: string) => {
        if (id === 'support') { Divider().color($r('app.color.divider')).margin({ top: 8, bottom: 8 }) }
        Row({ space: 4 }) {
          Text(sidebarItemLabel(id)).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).layoutWeight(1)
            .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent))
          if (!sidebarFooterItem(id)) {
            this.MoveButton(id, -1)
            this.MoveButton(id, 1)
          }
          Toggle({ type: ToggleType.Switch, isOn: this.hidden.split(',').indexOf(id) < 0 })
            .accessibilityText(sidebarItemLabel(id)).onChange((visible: boolean): void => this.setVisible(id, visible))
        }.width('100%').constraintSize({ minHeight: 52 }).id('sidebar-item-setting-' + id)
      }, (id: string): string => id)
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
}
