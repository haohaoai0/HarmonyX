// Stores one repeating daily app-icon interval. The UI ability checks the
// current interval while foregrounded and corrects it whenever the app opens.
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import {
  APP_ICON_CLASSIC,
  APP_ICON_DEFAULT,
  APP_ICON_MID_AUTUMN,
  AppIconStore,
  isKnownAppIcon,
  isMidAutumnIconAvailable
} from './AppIconStore';

export const DEFAULT_APP_ICON_SCHEDULE_START: number = 8 * 60;
export const DEFAULT_APP_ICON_SCHEDULE_END: number = 20 * 60;

export class AppIconScheduleSettings {
  enabled: boolean;
  startMinute: number;
  endMinute: number;
  iconName: string;
  fallbackIconName: string;

  constructor(enabled: boolean, startMinute: number, endMinute: number,
    iconName: string, fallbackIconName: string) {
    this.enabled = enabled;
    this.startMinute = startMinute;
    this.endMinute = endMinute;
    this.iconName = iconName;
    this.fallbackIconName = fallbackIconName;
  }
}

export class AppIconScheduleStore {
  private static readonly STORE_NAME: string = 'harmonyx_app_icon_schedule';
  private static readonly ENABLED_KEY: string = 'enabled';
  private static readonly START_KEY: string = 'start_minute';
  private static readonly END_KEY: string = 'end_minute';
  private static readonly ICON_KEY: string = 'icon_name';
  private static readonly FALLBACK_KEY: string = 'fallback_icon_name';
  private iconStore: AppIconStore = new AppIconStore();

  load(context: common.Context, currentIconName: string): AppIconScheduleSettings {
    const safeCurrentIcon: string = this.safeIconName(currentIconName, APP_ICON_DEFAULT);
    try {
      const options: preferences.Options = { name: AppIconScheduleStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      const enabled: boolean = store.getSync(AppIconScheduleStore.ENABLED_KEY, false) as boolean;
      const storedStart: number = store.getSync(AppIconScheduleStore.START_KEY,
        DEFAULT_APP_ICON_SCHEDULE_START) as number;
      const storedEnd: number = store.getSync(AppIconScheduleStore.END_KEY,
        DEFAULT_APP_ICON_SCHEDULE_END) as number;
      const storedIcon: string = store.getSync(AppIconScheduleStore.ICON_KEY,
        APP_ICON_CLASSIC) as string;
      const storedFallback: string = store.getSync(AppIconScheduleStore.FALLBACK_KEY,
        safeCurrentIcon) as string;
      const safeStart: number = this.validMinute(storedStart) ? storedStart : DEFAULT_APP_ICON_SCHEDULE_START;
      const safeEnd: number = this.validMinute(storedEnd) ? storedEnd : DEFAULT_APP_ICON_SCHEDULE_END;
      const safeTarget: string = this.safeScheduleIconName(storedIcon, APP_ICON_CLASSIC);
      const safeFallback: string = this.safeIconName(storedFallback, safeCurrentIcon);
      return new AppIconScheduleSettings(enabled && safeStart !== safeEnd, safeStart, safeEnd,
        safeTarget, safeFallback);
    } catch (error) {
      return new AppIconScheduleSettings(false, DEFAULT_APP_ICON_SCHEDULE_START,
        DEFAULT_APP_ICON_SCHEDULE_END, APP_ICON_CLASSIC, safeCurrentIcon);
    }
  }

  save(context: common.Context, settings: AppIconScheduleSettings): boolean {
    if (!this.validMinute(settings.startMinute) || !this.validMinute(settings.endMinute) ||
      settings.startMinute === settings.endMinute ||
      this.safeScheduleIconName(settings.iconName, '') !== settings.iconName ||
      this.safeIconName(settings.fallbackIconName, '') !== settings.fallbackIconName) {
      return false;
    }
    try {
      const options: preferences.Options = { name: AppIconScheduleStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      store.putSync(AppIconScheduleStore.ENABLED_KEY, settings.enabled);
      store.putSync(AppIconScheduleStore.START_KEY, settings.startMinute);
      store.putSync(AppIconScheduleStore.END_KEY, settings.endMinute);
      store.putSync(AppIconScheduleStore.ICON_KEY, settings.iconName);
      store.putSync(AppIconScheduleStore.FALLBACK_KEY, settings.fallbackIconName);
      store.flushSync();
      return true;
    } catch (error) {
      return false;
    }
  }

  iconForTime(settings: AppIconScheduleSettings, now: Date): string {
    if (!settings.enabled) {
      return settings.fallbackIconName;
    }
    const currentMinute: number = now.getHours() * 60 + now.getMinutes();
    let isInsideInterval: boolean = false;
    if (settings.startMinute < settings.endMinute) {
      isInsideInterval = currentMinute >= settings.startMinute && currentMinute < settings.endMinute;
    } else {
      isInsideInterval = currentMinute >= settings.startMinute || currentMinute < settings.endMinute;
    }
    return isInsideInterval ? settings.iconName : settings.fallbackIconName;
  }

  async applyIfEnabled(context: common.Context): Promise<void> {
    try {
      const currentIcon: string = await this.iconStore.currentName();
      const initialSettings: AppIconScheduleSettings = this.load(context, APP_ICON_DEFAULT);
      if (!initialSettings.enabled) {
        return;
      }
      const settings: AppIconScheduleSettings = this.load(context, currentIcon);
      const targetIcon: string = this.iconForTime(settings, new Date());
      if (targetIcon !== currentIcon) {
        await this.iconStore.select(targetIcon);
      }
    } catch (error) {
      // A system theme or cloned app can reject icon changes; the next
      // foreground check will retry after the user or system state changes.
    }
  }

  private validMinute(value: number): boolean {
    return value >= 0 && value < 24 * 60 && Math.floor(value) === value;
  }

  private safeScheduleIconName(value: string, fallback: string): string {
    if (!isKnownAppIcon(value) || value === APP_ICON_MID_AUTUMN && !isMidAutumnIconAvailable()) {
      return fallback;
    }
    // Limited time icons should not be persisted as a recurring daily target.
    if (value === APP_ICON_MID_AUTUMN) {
      return fallback;
    }
    return value;
  }

  private safeIconName(value: string, fallback: string): string {
    if (!isKnownAppIcon(value)) {
      return fallback;
    }
    if (value === APP_ICON_MID_AUTUMN && !isMidAutumnIconAvailable()) {
      return fallback;
    }
    return value;
  }
}
