// Keep post timestamps intact in the model and localize them only at display.
import { i18n } from '@kit.LocalizationKit';
import { effectiveAppLocale } from './AppLocale';

export const STORAGE_KEY_POST_TIME_NOW: string = 'harmonyx.post_time_now';
const MINUTE_MS: number = 60 * 1000;
const HOUR_MS: number = 60 * MINUTE_MS;
const DAY_MS: number = 24 * HOUR_MS;
const RELATIVE_TIME_LIMIT_MS: number = 7 * DAY_MS;

function postDate(value: string): Date | null {
  // Older cached OAuth posts contain a date without a time. Keep that date
  // local, and do not invent a midnight publication time in the detail view.
  if (/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    return new Date(Number(value.substring(0, 4)), Number(value.substring(5, 7)) - 1,
      Number(value.substring(8, 10)));
  }
  // Date.parse accepts truncated RFC strings by silently supplying 2001.
  // Only accept complete ISO or RFC timestamps returned by the post APIs.
  if (!/^\d{4}-\d{2}-\d{2}[T ]/.test(value) && !/\b\d{4}$/.test(value.trim())) {
    return null;
  }
  const date: Date = new Date(value);
  return isNaN(date.getTime()) ? null : date;
}

function postCalendarDate(date: Date, now: number, locale: string, includeYear: boolean): string {
  const options: Intl.DateTimeFormatOptions = {
    month: 'short',
    day: 'numeric'
  };
  if (includeYear || date.getFullYear() !== new Date(now).getFullYear()) {
    options.year = 'numeric';
  }
  return new Intl.DateTimeFormat(locale, options).format(date);
}

function postTimeUnit(value: number, unit: string, locale: string): string {
  const options: Intl.NumberFormatOptions = {
    style: 'unit',
    unit: unit,
    unitDisplay: 'narrow',
    useGrouping: false,
    maximumFractionDigits: 0
  };
  return new Intl.NumberFormat(locale, options).format(value);
}

export function formatPostTime(value: string, now: number = Date.now(),
  locale: string = effectiveAppLocale()): string {
  const date: Date | null = postDate(value);
  if (date === null) {
    return '';
  }
  // A date-only cache entry has insufficient precision for relative time.
  if (/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    return postCalendarDate(date, now, locale, false);
  }
  const elapsed: number = now - date.getTime();
  if (elapsed < -MINUTE_MS || elapsed >= RELATIVE_TIME_LIMIT_MS) {
    return postCalendarDate(date, now, locale, false);
  }
  if (elapsed < MINUTE_MS) {
    const options: Intl.RelativeTimeFormatOptions = { numeric: 'auto', style: 'narrow' };
    return new Intl.RelativeTimeFormat(locale, options).format(0, 'second');
  }
  if (elapsed < HOUR_MS) {
    return postTimeUnit(Math.floor(elapsed / MINUTE_MS), 'minute', locale);
  }
  if (elapsed < DAY_MS) {
    return postTimeUnit(Math.floor(elapsed / HOUR_MS), 'hour', locale);
  }
  return postTimeUnit(Math.floor(elapsed / DAY_MS), 'day', locale);
}

export function formatPostDetailTime(value: string, now: number = Date.now(),
  locale: string = effectiveAppLocale(),
  hour12: boolean = !i18n.System.is24HourClock()): string {
  const date: Date | null = postDate(value);
  if (date === null) {
    return '';
  }
  if (/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    return postCalendarDate(date, now, locale, true);
  }
  const options: Intl.DateTimeFormatOptions = {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
    hour12: hour12
  };
  // With no explicit timeZone, Intl uses the current device time zone.
  return new Intl.DateTimeFormat(locale, options).format(date);
}
