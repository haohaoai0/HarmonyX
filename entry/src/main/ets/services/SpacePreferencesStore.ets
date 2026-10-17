import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { accountStore } from './AccountStore';

export const STORAGE_KEY_HOME_SPACE_CAPSULE_ENABLED: string = 'harmonyx.home_space_capsule_enabled';
export const STORAGE_KEY_HOME_SPACE_CAPSULE_HIDDEN_FOR_SESSION: string = 'harmonyx.home_space_capsule_hidden_for_session';

class SpacePreferencesStore {
  private store(context: common.Context): preferences.Preferences {
    return preferences.getPreferencesSync(context, { name: 'harmonyx_spaces_preferences' });
  }
  private hiddenKey(context: common.Context): string {
    return 'hidden_' + (accountStore.active(context)?.id || 'guest');
  }
  // Only a new ability launch restores a temporary dismissal. Tab changes,
  // account changes and foregrounding keep the current session's choice.
  beginSession(context: common.Context): void {
    let enabled: boolean = true;
    try { enabled = this.store(context).getSync('home_capsule_enabled', true) as boolean; }
    catch (error) { }
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_HOME_SPACE_CAPSULE_ENABLED, enabled);
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_HOME_SPACE_CAPSULE_HIDDEN_FOR_SESSION, false);
  }
  hideHomeCapsuleForSession(): void {
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_HOME_SPACE_CAPSULE_HIDDEN_FOR_SESSION, true);
  }
  saveHomeCapsuleEnabled(context: common.Context, enabled: boolean): boolean {
    try {
      const store: preferences.Preferences = this.store(context);
      store.putSync('home_capsule_enabled', enabled);
      store.flushSync();
      AppStorage.setOrCreate<boolean>(STORAGE_KEY_HOME_SPACE_CAPSULE_ENABLED, enabled);
      AppStorage.setOrCreate<boolean>(STORAGE_KEY_HOME_SPACE_CAPSULE_HIDDEN_FOR_SESSION, false);
      return true;
    } catch (error) { return false; }
  }
  hidden(context: common.Context): string[] {
    try {
      return JSON.parse(this.store(context).getSync(this.hiddenKey(context), '[]') as string) as string[];
    } catch (error) { return []; }
  }
  hide(context: common.Context, id: string): boolean {
    try {
      const ids: string[] = this.hidden(context).filter((value: string): boolean => value !== id);
      ids.push(id);
      const store: preferences.Preferences = this.store(context);
      store.putSync(this.hiddenKey(context), JSON.stringify(ids.slice(-200)));
      store.flushSync();
      return true;
    } catch (error) { return false; }
  }
  guideSeen(context: common.Context, kind: string): boolean {
    try { return this.store(context).getSync('guide_' + kind, false) as boolean; }
    catch (error) { return false; }
  }
  acknowledge(context: common.Context, kind: string): void {
    try {
      const store: preferences.Preferences = this.store(context);
      store.putSync('guide_' + kind, true); store.flushSync();
    } catch (error) { }
  }
}
export const spacePreferencesStore: SpacePreferencesStore = new SpacePreferencesStore();
