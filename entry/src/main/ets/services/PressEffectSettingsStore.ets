// Persistent preference for the optional pressed-state scale on post cards.
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

export const STORAGE_KEY_PRESS_EFFECT_ENABLED: string = 'harmonyx.press_effect_enabled';

export class PressEffectSettingsStore {
  private static readonly STORE_NAME: string = 'harmonyx_press_effect';
  private static readonly ENABLED_KEY: string = 'enabled';

  loadEnabled(context: common.Context): boolean {
    try {
      const options: preferences.Options = { name: PressEffectSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      return store.getSync(PressEffectSettingsStore.ENABLED_KEY, false) as boolean;
    } catch (error) {
      return false;
    }
  }

  saveEnabled(context: common.Context, enabled: boolean): boolean {
    try {
      const options: preferences.Options = { name: PressEffectSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      store.putSync(PressEffectSettingsStore.ENABLED_KEY, enabled);
      store.flushSync();
      AppStorage.setOrCreate<boolean>(STORAGE_KEY_PRESS_EFFECT_ENABLED, enabled);
      return true;
    } catch (error) {
      return false;
    }
  }
}
