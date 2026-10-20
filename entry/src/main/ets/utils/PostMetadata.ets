import type { TweetMetrics } from '../models/Tweet';

// Shared by private timelines and API v2; preserve absent metrics as unknown.
export function optionalPostCount(value: Object | undefined): number | undefined {
  if ((typeof value !== 'number' && typeof value !== 'string') || String(value).trim().length === 0) { return undefined; }
  const count: number = Number(value);
  return isFinite(count) && count >= 0 ? Math.floor(count) : undefined;
}

function metadataObject(value: Object | undefined): Record<string, Object> {
  return value !== undefined && value !== null && typeof value === 'object' ? value as Record<string, Object> : {};
}

export function postEditHistoryIds(node: Record<string, Object>): string[] | undefined {
  const legacy: Record<string, Object> = metadataObject(node['legacy']);
  const control: Record<string, Object> = metadataObject(node['edit_control'] ?? legacy['edit_control']);
  const initial: Record<string, Object> = metadataObject(control['edit_control_initial']);
  const raw: Object | undefined = node['edit_history_tweet_ids'] ?? control['edit_tweet_ids'] ?? initial['edit_tweet_ids'];
  if (!(raw instanceof Array)) { return undefined; }
  const ids: string[] = [];
  for (const value of raw as Object[]) {
    const id: string = String(value);
    if (/^\d+$/.test(id) && ids.indexOf(id) < 0) { ids.push(id); }
  }
  return ids.length > 0 ? ids : undefined;
}

export function postIsEdited(ids: string[] | undefined): boolean {
  return ids !== undefined && ids.length > 1;
}

export function refreshedPostMetrics(previous: TweetMetrics, incoming: TweetMetrics): TweetMetrics {
  return { replyCount: incoming.replyCount, repostCount: incoming.repostCount,
    likeCount: incoming.likeCount, viewCount: incoming.viewCount,
    bookmarkCount: incoming.bookmarkCount ?? previous.bookmarkCount,
    quoteCount: incoming.quoteCount ?? previous.quoteCount };
}

export function bookmarkCountAfter(count: number | undefined, previous: boolean, next: boolean): number | undefined {
  return count === undefined ? undefined : Math.max(0, count + (previous === next ? 0 : next ? 1 : -1));
}
