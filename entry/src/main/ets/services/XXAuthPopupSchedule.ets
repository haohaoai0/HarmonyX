import { XXAuthPopupConfig } from '../models/XXAuth';

export class XXAuthPopupHistory {
  day: string = '';
  dayCount: number = 0;
  total: number = 0;
  last: number = 0;
}

// Recommendation budgets are shared by all promoted apps in this installation.
// A new campaign revision resets the budget; copy edits never reset it.
export class XXAuthPopupSchedule {
  static number(value: number | undefined, fallback: number, max: number): number {
    return typeof value === 'number' && Number.isFinite(value) ? Math.max(0, Math.min(max, value)) : fallback;
  }

  static revision(config: XXAuthPopupConfig): number {
    return Math.floor(XXAuthPopupSchedule.number(config.popup_revision, 0, 1000000000));
  }

  static delay(config: XXAuthPopupConfig): number {
    return XXAuthPopupSchedule.number(config.popup_delay_seconds, 0, 3600) * 1000;
  }

  static day(now: number): string {
    const date: Date = new Date(now);
    return date.getFullYear().toString() + '-' + date.getMonth().toString() + '-' + date.getDate().toString();
  }

  // Local clock periods default to 00–06, 06–12, 12–18 and 18–24. Even a
  // legacy cloud config with no budgets must not show on every app launch.
  static period(config: XXAuthPopupConfig, now: number): string {
    const hours: number = Math.max(1, Math.floor(XXAuthPopupSchedule.number(config.popup_period_hours, 6, 24)));
    return XXAuthPopupSchedule.day(now) + ':' + Math.floor(new Date(now).getHours() / hours).toString();
  }

  private static boundary(value: string | undefined): number {
    if (value === undefined || value.trim() === '' || value.trim() === '0') { return 0; }
    // Require an explicit timezone so a campaign has one worldwide boundary.
    if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,3})?(?:Z|[+-]\d{2}:\d{2})$/.test(value.trim())) { return -1; }
    const parsed: number = Date.parse(value.trim());
    return Number.isFinite(parsed) && parsed > 0 ? parsed : -1;
  }

  static eligible(config: XXAuthPopupConfig, history: XXAuthPopupHistory, sessionCount: number,
    now: number, readySince: number): boolean {
    const start: number = XXAuthPopupSchedule.boundary(config.popup_start_at);
    const end: number = XXAuthPopupSchedule.boundary(config.popup_end_at);
    if (start < 0 || end < 0 || (end > 0 && start >= end) ||
      (start > 0 && now < start) || (end > 0 && now >= end)) { return false; }
    if (now < readySince + XXAuthPopupSchedule.delay(config)) { return false; }
    const daily: number = Math.floor(XXAuthPopupSchedule.number(config.popup_daily_limit, 2, 1000));
    const total: number = Math.floor(XXAuthPopupSchedule.number(config.popup_total_limit, 0, 1000000));
    const session: number = Math.floor(XXAuthPopupSchedule.number(config.popup_session_limit, 1, 1000));
    const interval: number = XXAuthPopupSchedule.number(config.popup_interval_hours, 6, 87600) * 3600000;
    if (history.total > 0 && XXAuthPopupSchedule.period(config, history.last) ===
      XXAuthPopupSchedule.period(config, now)) { return false; }
    if (daily > 0 && history.day === XXAuthPopupSchedule.day(now) && history.dayCount >= daily) { return false; }
    if (total > 0 && history.total >= total) { return false; }
    if (session > 0 && sessionCount >= session) { return false; }
    return history.total === 0 || now - history.last >= interval;
  }

  static record(history: XXAuthPopupHistory, now: number): XXAuthPopupHistory {
    const next: XXAuthPopupHistory = new XXAuthPopupHistory();
    next.day = XXAuthPopupSchedule.day(now);
    next.dayCount = (history.day === next.day ? history.dayCount : 0) + 1;
    next.total = history.total + 1;
    next.last = now;
    return next;
  }
}
