import { i18n } from '@kit.LocalizationKit';
import { effectiveAppLocale } from './AppLocale';

export function chatRelativeTime(timestamp: number, fallback: string = ''): string {
  if (timestamp <= 0) { return fallback; }
  const elapsed: number = Math.max(0, Date.now() - timestamp);
  let count: number = Math.max(1, Math.floor(elapsed / 60000));
  let unit: string = 'minute';
  if (elapsed >= 31536000000) { unit = 'year'; count = Math.floor(elapsed / 31536000000); }
  else if (elapsed >= 604800000) { unit = 'week'; count = Math.floor(elapsed / 604800000); }
  else if (elapsed >= 86400000) { unit = 'day'; count = Math.floor(elapsed / 86400000); }
  else if (elapsed >= 3600000) { unit = 'hour'; count = Math.floor(elapsed / 3600000); }
  const options: Intl.NumberFormatOptions = { style: 'unit', unit: unit, unitDisplay: 'narrow', useGrouping: false };
  return new Intl.NumberFormat(effectiveAppLocale(), options).format(count);
}

export function chatMessageTime(timestamp: number, fallback: string = '', locale: string = effectiveAppLocale()): string {
  if (timestamp <= 0) { return fallback; }
  const options: Intl.DateTimeFormatOptions = { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' };
  if (i18n.System.is24HourClock()) {
    // hour12: false can select h24 in some locales and display midnight as 24:xx.
    options.hour = '2-digit';
    options.hourCycle = 'h23';
  } else {
    options.hour12 = true;
  }
  return new Intl.DateTimeFormat(locale, options).format(new Date(timestamp));
}
