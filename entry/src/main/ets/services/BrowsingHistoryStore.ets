import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import type { MediaAttachment, Tweet } from '../models/Tweet';

export class BrowsingHistoryEntry {
  id: string = '';
  url: string = '';
  viewedAt: number = 0;
  authorName: string = '';
  authorHandle: string = '';
  avatarUrl: string = '';
  verified: boolean = false;
  text: string = '';
  previewUrl: string = '';
  mediaType: string = '';
  mediaCount: number = 0;
  sensitive: boolean = false;
}

export class BrowsingHistoryBatch {
  rows: BrowsingHistoryEntry[] = [];
  nextOffset: number = 0;
  hasMore: boolean = false;
}

// Keep links and a small local preview of content the reader already saw.
// No timeline/API request is needed to display the history. Rows and indexes stay
// below Preferences' per-value size limit even with a long local history.
export class BrowsingHistoryStore {
  private static readonly MAX_ENTRIES: number = 2000;
  private static readonly INDEX_SIZE: number = 100;

  private store(context: common.Context): preferences.Preferences {
    return preferences.getPreferencesSync(context, { name: 'harmonyx_browsing_history' });
  }

  private ids(store: preferences.Preferences): string[] {
    const count: number = Math.min(20, Math.max(0, store.getSync('index_count', 0) as number));
    const result: string[] = [];
    const seen: Set<string> = new Set<string>();
    for (let i: number = 0; i < count; i++) {
      const chunk: string[] = JSON.parse(store.getSync('index_' + i, '[]') as string) as string[];
      for (const id of chunk) {
        if (/^\d+$/.test(id) && !seen.has(id)) { seen.add(id); result.push(id); }
      }
    }
    return result.slice(0, BrowsingHistoryStore.MAX_ENTRIES);
  }

  load(context: common.Context): BrowsingHistoryEntry[] {
    try {
      const store: preferences.Preferences = this.store(context);
      const rows: BrowsingHistoryEntry[] = [];
      for (const id of this.ids(store)) {
        const row: BrowsingHistoryEntry = JSON.parse(store.getSync('post_' + id, '{}') as string) as BrowsingHistoryEntry;
        if (row.id === id && /^https:\/\/x\.com\/(?:[A-Za-z0-9_]+|i\/web)\/status\/\d+$/.test(row.url)) {
          rows.push(this.normalize(row));
        }
      }
      return rows;
    } catch (error) { return []; }
  }

  // Bound synchronous preference reads to one page instead of parsing 2000
  // snapshots during a navigation frame. Offset counts IDs, including bad rows.
  loadBatch(context: common.Context, offset: number = 0, count: number = 32): BrowsingHistoryBatch {
    const batch: BrowsingHistoryBatch = new BrowsingHistoryBatch();
    try {
      const store: preferences.Preferences = this.store(context);
      const ids: string[] = this.ids(store);
      const start: number = Math.max(0, offset);
      batch.nextOffset = Math.min(ids.length, start + Math.max(1, Math.min(64, count)));
      batch.hasMore = batch.nextOffset < ids.length;
      for (let index: number = start; index < batch.nextOffset; index++) {
        try {
          const id: string = ids[index];
          const row: BrowsingHistoryEntry = JSON.parse(store.getSync('post_' + id, '{}') as string) as BrowsingHistoryEntry;
          if (row.id === id && /^https:\/\/x\.com\/(?:[A-Za-z0-9_]+|i\/web)\/status\/\d+$/.test(row.url)) {
            batch.rows.push(this.normalize(row));
          }
        } catch (_error) { }
      }
    } catch (_error) { }
    return batch;
  }

  record(context: common.Context, tweet: Tweet): void {
    if (!/^\d+$/.test(tweet.id)) { return; }
    try {
      const store: preferences.Preferences = this.store(context);
      const current: string[] = this.ids(store);
      const next: string[] = [tweet.id, ...current.filter((id: string): boolean => id !== tweet.id)];
      const previous: BrowsingHistoryEntry = JSON.parse(store.getSync('post_' + tweet.id, '{}') as string) as BrowsingHistoryEntry;
      const row: BrowsingHistoryEntry = this.snapshot(tweet, previous);
      row.viewedAt = Date.now();
      store.putSync('post_' + row.id, JSON.stringify(row));
      for (const id of next.slice(BrowsingHistoryStore.MAX_ENTRIES)) { store.deleteSync('post_' + id); }
      this.saveIndex(store, next.slice(0, BrowsingHistoryStore.MAX_ENTRIES));
    } catch (error) { }
  }

  // A detail fetch can fill an old link-only entry without changing visit order.
  enrich(context: common.Context, tweet: Tweet): BrowsingHistoryEntry | null {
    if (!/^\d+$/.test(tweet.id)) { return null; }
    try {
      const store: preferences.Preferences = this.store(context);
      const previous: BrowsingHistoryEntry = JSON.parse(store.getSync('post_' + tweet.id, '{}') as string) as BrowsingHistoryEntry;
      if (previous.id !== tweet.id) { return null; }
      const row: BrowsingHistoryEntry = this.snapshot(tweet, previous);
      row.viewedAt = previous.viewedAt;
      store.putSync('post_' + tweet.id, JSON.stringify(row));
      store.flush().catch((): void => {});
      return row;
    } catch (error) { }
    return null;
  }

  private normalize(saved: BrowsingHistoryEntry): BrowsingHistoryEntry {
    const row: BrowsingHistoryEntry = new BrowsingHistoryEntry();
    row.id = saved.id;
    row.url = saved.url;
    row.viewedAt = saved.viewedAt;
    const handle: string = saved.url.split('/')[3];
    row.authorHandle = saved.authorHandle ?? (handle === 'i' ? '' : handle);
    row.authorName = saved.authorName ?? '';
    row.avatarUrl = saved.avatarUrl ?? '';
    row.verified = saved.verified === true;
    row.text = saved.text ?? '';
    row.previewUrl = saved.previewUrl ?? '';
    row.mediaType = saved.mediaType ?? '';
    row.mediaCount = saved.mediaCount ?? 0;
    row.sensitive = saved.sensitive === true;
    return row;
  }

  private snapshot(tweet: Tweet, previous: BrowsingHistoryEntry): BrowsingHistoryEntry {
    const row: BrowsingHistoryEntry = new BrowsingHistoryEntry();
    row.id = tweet.id;
    const handle: string = tweet.author.username;
    row.authorHandle = /^[A-Za-z0-9_]+$/.test(handle) && handle !== 'x' ? handle : previous.authorHandle ?? '';
    row.url = 'https://x.com/' + (row.authorHandle.length > 0 ? row.authorHandle : 'i/web') + '/status/' + tweet.id;
    row.authorName = (tweet.author.name ?? '').substring(0, 80) || previous.authorName || '';
    row.avatarUrl = (tweet.author.avatarUrl ?? '').substring(0, 1024) || previous.avatarUrl || '';
    row.verified = tweet.author.verified;
    row.text = Array.from(tweet.text || tweet.article?.title || tweet.card?.title || previous.text || '')
      .slice(0, 500).join('');
    const media: MediaAttachment | undefined = tweet.attachments?.[0];
    row.previewUrl = (media?.previewUrl || (media?.type === 'photo' ? media.mediaUrl : '') ||
      tweet.article?.coverUrl || tweet.card?.imageUrl || previous.previewUrl || '').substring(0, 1024);
    row.mediaType = media?.type ?? previous.mediaType ?? '';
    row.mediaCount = tweet.attachments?.length ?? previous.mediaCount ?? 0;
    row.sensitive = media?.sensitive ?? previous.sensitive ?? false;
    return row;
  }

  remove(context: common.Context, id: string): boolean {
    try {
      const store: preferences.Preferences = this.store(context);
      const next: string[] = this.ids(store).filter((item: string): boolean => item !== id);
      store.deleteSync('post_' + id);
      this.saveIndex(store, next);
      return true;
    } catch (error) { return false; }
  }

  clear(context: common.Context): boolean {
    try {
      const store: preferences.Preferences = this.store(context);
      for (const id of this.ids(store)) { store.deleteSync('post_' + id); }
      this.saveIndex(store, []);
      return true;
    } catch (error) { return false; }
  }

  private saveIndex(store: preferences.Preferences, ids: string[]): void {
    const oldCount: number = store.getSync('index_count', 0) as number;
    const count: number = Math.ceil(ids.length / BrowsingHistoryStore.INDEX_SIZE);
    for (let i: number = 0; i < count; i++) {
      store.putSync('index_' + i, JSON.stringify(ids.slice(i * BrowsingHistoryStore.INDEX_SIZE,
        (i + 1) * BrowsingHistoryStore.INDEX_SIZE)));
    }
    for (let i: number = count; i < oldCount; i++) { store.deleteSync('index_' + i); }
    store.putSync('index_count', count);
    store.flushSync();
  }
}

export const browsingHistoryStore: BrowsingHistoryStore = new BrowsingHistoryStore();
