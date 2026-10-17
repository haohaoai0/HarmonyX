// 中秋祝福弹窗的展示窗口：农历八月十五（2026-09-25）起连续三天，
// 2026-09-28 零点窗口关闭，之后不再展示。窗口内每天最多弹一次，
// 记录落在 preferences，重启应用后依然生效。
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

export class MidAutumnGreetingStore {
  private static readonly STORE_NAME: string = 'harmonyx_festival';
  private static readonly LAST_SHOWN_KEY: string = 'mid_autumn_last_shown_day';
  // 用本地时间构造，避免时区换算把窗口边界挪到前一天或后一天。
  private static readonly WINDOW_START_MS: number = new Date(2026, 8, 25, 0, 0, 0, 0).getTime();
  private static readonly WINDOW_END_MS: number = new Date(2026, 8, 28, 0, 0, 0, 0).getTime();

  isWithinWindow(now: number): boolean {
    return now >= MidAutumnGreetingStore.WINDOW_START_MS && now < MidAutumnGreetingStore.WINDOW_END_MS;
  }

  shouldShow(context: common.Context, now: number): boolean {
    if (!this.isWithinWindow(now)) {
      return false;
    }
    return this.lastShownDay(context) !== this.dayStamp(now);
  }

  markShown(context: common.Context, now: number): void {
    try {
      const store: preferences.Preferences = this.openStore(context);
      store.putSync(MidAutumnGreetingStore.LAST_SHOWN_KEY, this.dayStamp(now));
      store.flushSync();
    } catch (error) {
      // 记录失败只影响“每天一次”的节流，不该拦住弹窗本身。
    }
  }

  private lastShownDay(context: common.Context): string {
    try {
      const store: preferences.Preferences = this.openStore(context);
      return store.getSync(MidAutumnGreetingStore.LAST_SHOWN_KEY, '') as string;
    } catch (error) {
      return '';
    }
  }

  private openStore(context: common.Context): preferences.Preferences {
    const options: preferences.Options = { name: MidAutumnGreetingStore.STORE_NAME };
    return preferences.getPreferencesSync(context, options);
  }

  private dayStamp(now: number): string {
    const date: Date = new Date(now);
    return String(date.getFullYear()) + '-' + this.pad2(date.getMonth() + 1) + '-' + this.pad2(date.getDate());
  }

  private pad2(value: number): string {
    return value < 10 ? '0' + String(value) : String(value);
  }
}

export const midAutumnGreetingStore: MidAutumnGreetingStore = new MidAutumnGreetingStore();
