export const POST_COUNT_COMPACT: number = 0;
export const POST_COUNT_CHINESE: number = 1;
export const POST_COUNT_FULL: number = 2;

function shortCount(value: number, divisor: number, suffix: string): string {
  return (Math.round(value / divisor * 10) / 10).toString() + suffix;
}

export function formatPostCount(value: number, format: number = POST_COUNT_COMPACT): string {
  const count: number = Number.isFinite(value) ? Math.max(0, Math.floor(value)) : 0;
  if (format === POST_COUNT_FULL) { return count.toString(); }
  if (format === POST_COUNT_CHINESE) {
    if (count >= 99995000) { return shortCount(count, 100000000, '亿'); }
    if (count >= 10000) { return shortCount(count, 10000, '万'); }
    return count.toString();
  }
  if (count >= 999950000) { return shortCount(count, 1000000000, 'B'); }
  if (count >= 999950) { return shortCount(count, 1000000, 'M'); }
  if (count >= 1000) { return shortCount(count, 1000, 'K'); }
  return count.toString();
}
