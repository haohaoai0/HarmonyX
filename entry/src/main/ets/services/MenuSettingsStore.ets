import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { MENU_ACTION_OPTIONS, MenuActionOption, normalizeHiddenMenuActions } from '../models/MenuActionCatalog';

export const STORAGE_KEY_HIDDEN_MENU_ACTIONS: string = 'harmonyx.hidden_menu_actions';

export class MenuSettingsStore {
  private store(context: common.Context): preferences.Preferences {
    return preferences.getPreferencesSync(context, { name: 'harmonyx_menus' });
  }

  load(context: common.Context): string {
    try { return normalizeHiddenMenuActions(this.store(context).getSync('hidden_actions', '') as string); }
    catch (error) { return ''; }
  }

  publish(hidden: string): void {
    AppStorage.setOrCreate<string>(STORAGE_KEY_HIDDEN_MENU_ACTIONS, normalizeHiddenMenuActions(hidden));
  }

  private save(context: common.Context, hidden: string): boolean {
    try {
      const store: preferences.Preferences = this.store(context);
      const value: string = normalizeHiddenMenuActions(hidden);
      store.putSync('hidden_actions', value);
      store.flushSync();
      this.publish(value);
      return true;
    } catch (error) { return false; }
  }

  saveVisible(context: common.Context, id: string, visible: boolean): boolean {
    if (!MENU_ACTION_OPTIONS.some((option: MenuActionOption): boolean => option.id === id)) { return false; }
    const hidden: string[] = this.load(context).split(',').filter((value: string): boolean => value.length > 0 && value !== id);
    if (!visible) { hidden.push(id); }
    return this.save(context, hidden.join(','));
  }

  resetGroup(context: common.Context, group: string): boolean {
    const hidden: string[] = this.load(context).split(',');
    return this.save(context, MENU_ACTION_OPTIONS.filter((option: MenuActionOption): boolean =>
      option.group !== group && hidden.indexOf(option.id) >= 0).map((option: MenuActionOption): string => option.id).join(','));
  }
}

export const menuSettingsStore: MenuSettingsStore = new MenuSettingsStore();
