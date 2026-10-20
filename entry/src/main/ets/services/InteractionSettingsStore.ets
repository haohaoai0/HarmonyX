import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

export const STORAGE_KEY_PHOTO_FULLSCREEN: string = 'harmonyx.photo_fullscreen';
export const STORAGE_KEY_HOME_FLOATING_ACTION: string = 'harmonyx.home_floating_action';
export const STORAGE_KEY_FLOATING_COMPOSE_MATERIAL_TINT: string = 'harmonyx.floating_compose_material_tint';
export const STORAGE_KEY_REFRESH_ON_FOREGROUND: string = 'harmonyx.refresh_on_foreground';
export const STORAGE_KEY_REFRESH_ON_HOME_TAB: string = 'harmonyx.refresh_on_home_tab';
export const STORAGE_KEY_HOME_DOUBLE_TAP_LATEST: string = 'harmonyx.home_double_tap_latest';
export const STORAGE_KEY_HOME_PULL_REFRESH_LATEST: string = 'harmonyx.home_pull_refresh_latest';
export const STORAGE_KEY_CONFIRM_APP_EXIT: string = 'harmonyx.confirm_app_exit';
export const HOME_FLOATING_COMPOSE: string = 'compose';
export const HOME_FLOATING_REFRESH: string = 'refresh';
export const HOME_FLOATING_TOP: string = 'top';
export const HOME_FLOATING_HIDDEN: string = 'hidden';

export class InteractionSettings {
  photoFullscreen: boolean = true;
  homeFloatingAction: string = HOME_FLOATING_COMPOSE;
  floatingComposeMaterialTint: boolean = true;
  refreshOnForeground: boolean = false;
  refreshOnHomeTab: boolean = false;
  homeDoubleTapLatest: boolean = true;
  homePullRefreshLatest: boolean = true;
  confirmAppExit: boolean = true;
}

export class InteractionSettingsStore {
  private store(context: common.Context): preferences.Preferences {
    return preferences.getPreferencesSync(context, { name: 'harmonyx_interaction' });
  }

  private normaliseAction(value: string): string {
    if (value === HOME_FLOATING_REFRESH || value === HOME_FLOATING_TOP || value === HOME_FLOATING_HIDDEN) {
      return value;
    }
    return HOME_FLOATING_COMPOSE;
  }

  load(context: common.Context): InteractionSettings {
    const settings: InteractionSettings = new InteractionSettings();
    try {
      const store: preferences.Preferences = this.store(context);
      settings.photoFullscreen = store.getSync('photo_fullscreen', true) as boolean;
      settings.homeFloatingAction = this.normaliseAction(store.getSync('home_floating_action', HOME_FLOATING_COMPOSE) as string);
      settings.floatingComposeMaterialTint = store.getSync('floating_compose_material_tint', true) as boolean;
      settings.refreshOnForeground = store.getSync('refresh_on_foreground', false) as boolean;
      settings.refreshOnHomeTab = store.getSync('refresh_on_home_tab', false) as boolean;
      settings.homeDoubleTapLatest = store.getSync('home_double_tap_latest', true) as boolean;
      settings.homePullRefreshLatest = store.getSync('home_pull_refresh_latest', true) as boolean;
      settings.confirmAppExit = store.getSync('confirm_app_exit', true) as boolean;
    } catch (error) { }
    return settings;
  }

  publish(settings: InteractionSettings): void {
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_PHOTO_FULLSCREEN, settings.photoFullscreen);
    AppStorage.setOrCreate<string>(STORAGE_KEY_HOME_FLOATING_ACTION, this.normaliseAction(settings.homeFloatingAction));
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_FLOATING_COMPOSE_MATERIAL_TINT, settings.floatingComposeMaterialTint);
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_REFRESH_ON_FOREGROUND, settings.refreshOnForeground);
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_REFRESH_ON_HOME_TAB, settings.refreshOnHomeTab);
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_HOME_DOUBLE_TAP_LATEST, settings.homeDoubleTapLatest);
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_HOME_PULL_REFRESH_LATEST, settings.homePullRefreshLatest);
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_CONFIRM_APP_EXIT, settings.confirmAppExit);
  }

  private saveBoolean(context: common.Context, key: string, storageKey: string, value: boolean): boolean {
    try {
      const store: preferences.Preferences = this.store(context);
      store.putSync(key, value);
      store.flushSync();
      AppStorage.setOrCreate<boolean>(storageKey, value);
      return true;
    } catch (error) { return false; }
  }

  savePhotoFullscreen(context: common.Context, value: boolean): boolean {
    return this.saveBoolean(context, 'photo_fullscreen', STORAGE_KEY_PHOTO_FULLSCREEN, value);
  }

  saveFloatingComposeMaterialTint(context: common.Context, value: boolean): boolean {
    return this.saveBoolean(context, 'floating_compose_material_tint', STORAGE_KEY_FLOATING_COMPOSE_MATERIAL_TINT, value);
  }

  saveRefreshOnForeground(context: common.Context, value: boolean): boolean {
    return this.saveBoolean(context, 'refresh_on_foreground', STORAGE_KEY_REFRESH_ON_FOREGROUND, value);
  }

  saveRefreshOnHomeTab(context: common.Context, value: boolean): boolean {
    return this.saveBoolean(context, 'refresh_on_home_tab', STORAGE_KEY_REFRESH_ON_HOME_TAB, value);
  }

  saveHomeDoubleTapLatest(context: common.Context, value: boolean): boolean {
    return this.saveBoolean(context, 'home_double_tap_latest', STORAGE_KEY_HOME_DOUBLE_TAP_LATEST, value);
  }

  saveHomePullRefreshLatest(context: common.Context, value: boolean): boolean {
    return this.saveBoolean(context, 'home_pull_refresh_latest', STORAGE_KEY_HOME_PULL_REFRESH_LATEST, value);
  }

  saveHomeFloatingAction(context: common.Context, action: string): boolean {
    const value: string = this.normaliseAction(action);
    try {
      const store: preferences.Preferences = this.store(context);
      store.putSync('home_floating_action', value);
      store.flushSync();
      AppStorage.setOrCreate<string>(STORAGE_KEY_HOME_FLOATING_ACTION, value);
      return true;
    } catch (error) { return false; }
  }

  saveConfirmAppExit(context: common.Context, value: boolean): boolean {
    return this.saveBoolean(context, 'confirm_app_exit', STORAGE_KEY_CONFIRM_APP_EXIT, value);
  }
}

export const interactionSettingsStore: InteractionSettingsStore = new InteractionSettingsStore();
