// Controls whether timeline/detail child pages expose the floating read-aloud
// entry. The render path observes AppStorage; this store owns persistence.
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

export const STORAGE_KEY_READ_ALOUD_ENTRY_ENABLED: string = 'harmonyx.read_aloud_entry_enabled';

export class ReadAloudSettingsStore {
  private static readonly STORE_NAME: string = 'harmonyx_read_aloud';
  private static readonly ENTRY_ENABLED_KEY: string = 'entry_enabled';

  loadEntryEnabled(context: common.Context): boolean {
    try {
      const options: preferences.Options = { name: ReadAloudSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      return store.getSync(ReadAloudSettingsStore.ENTRY_ENABLED_KEY, false) as boolean;
    } catch (error) {
      return false;
    }
  }

  saveEntryEnabled(context: common.Context, enabled: boolean): boolean {
    try {
      const options: preferences.Options = { name: ReadAloudSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      store.putSync(ReadAloudSettingsStore.ENTRY_ENABLED_KEY, enabled);
      store.flushSync();
      this.publishEntryEnabled(enabled);
      return true;
    } catch (error) {
      return false;
    }
  }

  publishEntryEnabled(enabled: boolean): void {
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_READ_ALOUD_ENTRY_ENABLED, enabled);
  }
}

export const readAloudSettingsStore: ReadAloudSettingsStore = new ReadAloudSettingsStore();
