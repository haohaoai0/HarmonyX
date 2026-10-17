// Notification rows remain available on demand. This preference only controls
// automatic checks and the unread badge outside the notifications tab.
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

export const STORAGE_KEY_NOTIFICATION_ALERTS: string = 'harmonyx.notification_alerts';
export const STORAGE_KEY_SYSTEM_NOTIFICATIONS: string = 'harmonyx.system_notifications';
export const STORAGE_KEY_NOTIFICATION_DND_SILENT: string = 'harmonyx.notification_dnd_silent';

export class NotificationSettingsStore {
  private static readonly STORE_NAME: string = 'harmonyx_notifications';
  private static readonly ALERTS_ENABLED_KEY: string = 'alerts_enabled';
  private static readonly SYSTEM_NOTIFICATIONS_KEY: string = 'system_notifications';
  private static readonly DND_SILENT_KEY: string = 'dnd_silent';

  loadAlertsEnabled(context: common.Context): boolean {
    try {
      const options: preferences.Options = { name: NotificationSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      return store.getSync(NotificationSettingsStore.ALERTS_ENABLED_KEY, true) as boolean;
    } catch (error) {
      return true;
    }
  }

  saveAlertsEnabled(context: common.Context, enabled: boolean): boolean {
    try {
      const options: preferences.Options = { name: NotificationSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      store.putSync(NotificationSettingsStore.ALERTS_ENABLED_KEY, enabled);
      store.flushSync();
      this.publishAlertsEnabled(enabled);
      return true;
    } catch (error) {
      return false;
    }
  }

  publishAlertsEnabled(enabled: boolean): void {
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_NOTIFICATION_ALERTS, enabled);
  }

  loadSystemNotificationsEnabled(context: common.Context): boolean {
    try {
      const options: preferences.Options = { name: NotificationSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      return store.getSync(NotificationSettingsStore.SYSTEM_NOTIFICATIONS_KEY, true) as boolean;
    } catch (error) {
      return true;
    }
  }

  saveSystemNotificationsEnabled(context: common.Context, enabled: boolean): boolean {
    try {
      const options: preferences.Options = { name: NotificationSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      store.putSync(NotificationSettingsStore.SYSTEM_NOTIFICATIONS_KEY, enabled);
      store.flushSync();
      this.publishSystemNotificationsEnabled(enabled);
      return true;
    } catch (error) {
      return false;
    }
  }

  publishSystemNotificationsEnabled(enabled: boolean): void {
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_SYSTEM_NOTIFICATIONS, enabled);
  }

  loadDndSilentEnabled(context: common.Context): boolean {
    try {
      const options: preferences.Options = { name: NotificationSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      return store.getSync(NotificationSettingsStore.DND_SILENT_KEY, true) as boolean;
    } catch (error) {
      return true;
    }
  }

  saveDndSilentEnabled(context: common.Context, enabled: boolean): boolean {
    try {
      const options: preferences.Options = { name: NotificationSettingsStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      store.putSync(NotificationSettingsStore.DND_SILENT_KEY, enabled);
      store.flushSync();
      this.publishDndSilentEnabled(enabled);
      return true;
    } catch (error) {
      return false;
    }
  }

  publishDndSilentEnabled(enabled: boolean): void {
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_NOTIFICATION_DND_SILENT, enabled);
  }
}

export const notificationSettingsStore: NotificationSettingsStore = new NotificationSettingsStore();
