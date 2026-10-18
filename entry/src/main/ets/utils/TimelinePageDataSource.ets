import type { Tweet } from '../models/Tweet';
import type { XXAuthPromotionPost } from '../services/XXAuthPromotionPost';
import { XXAuthPromotionInjector, XXAuthPromotionSlot } from './XXAuthPromotionInjector';

// Upper bound of promotions inside one timeline, whatever the remote asks for.
const PROMOTION_LIMIT: number = 3;

export class TimelinePageItem {
  key: string;
  tweet: Tweet | null;
  postIndex: number;
  // Set only on an injected recommendation row; the feed renders it as a post
  // while paging, numbering and cursors stay untouched.
  promotion: XXAuthPromotionPost | null;

  constructor(key: string, tweet: Tweet | null = null, postIndex: number = -1,
    promotion: XXAuthPromotionPost | null = null) {
    this.key = key;
    this.tweet = tweet;
    this.postIndex = postIndex;
    this.promotion = promotion;
  }
}

// One lazy source includes the header and footer, so paging never builds every
// TweetCard or replaces the scroll container when the selected feed changes.
export class TimelinePageDataSource implements IDataSource {
  private rows: TimelinePageItem[] = [new TimelinePageItem('header'), new TimelinePageItem('footer')];
  private listeners: DataChangeListener[] = [];
  private posts: number = 0;

  totalCount(): number { return this.rows.length; }
  // WaterFlow sections contain a header and footer outside the content section.
  // Keep this count in the data source so injected promotion rows are included
  // in the same count as the LazyForEach rows.
  contentCount(): number { return Math.max(0, this.rows.length - 2); }
  postCount(): number { return this.posts; }
  getData(index: number): TimelinePageItem { return this.rows[index]; }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) { this.listeners.push(listener); }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const index: number = this.listeners.indexOf(listener);
    if (index >= 0) { this.listeners.splice(index, 1); }
  }

  // Promotions are spread over the first page at launch-randomised positions,
  // so the reader meets them while scrolling instead of at the very top.
  // `count` is the remote budget for this surface; the posts list is the pool
  // the injector cycles through, so one timeline only ever carries one row.
  replace(posts: Tweet[], promotions: XXAuthPromotionPost[] = [], salt: string = '',
    count: number = 0, onRowsReady: ((contentCount: number) => void) | null = null): void {
    const desired: TimelinePageItem[] = [];
    for (let i: number = 0; i < posts.length; i++) {
      desired.push(new TimelinePageItem('post:' + posts[i].id, posts[i], i));
    }
    if (promotions.length > 0 && count > 0) {
      const slots: XXAuthPromotionSlot[] = XXAuthPromotionInjector.slots(posts.length,
        promotions, Math.min(count, PROMOTION_LIMIT), 'home:' + salt);
      for (let i: number = 0; i < slots.length; i++) {
        const slot: XXAuthPromotionSlot = slots[i];
        // Earlier insertions shift every later position by their own count.
        const index: number = Math.min(slot.index + i, desired.length);
        desired.splice(index, 0,
          new TimelinePageItem('promo:' + slot.post.fingerprint + ':' + index.toString(),
            null, -1, slot.post));
      }
    }
    this.posts = posts.length;

    const previous: TimelinePageItem[] = this.rows;
    let structureChanged: boolean = previous.length - 2 !== desired.length;
    if (!structureChanged) {
      for (let i: number = 0; i < desired.length; i++) {
        if (previous[i + 1].key !== desired[i].key) { structureChanged = true; break; }
      }
    }
    const changed: number[] = [];
    const rows: TimelinePageItem[] = [previous[0]];
    for (let i: number = 0; i < desired.length; i++) {
      const item: TimelinePageItem = desired[i];
      const old: TimelinePageItem | undefined = previous[i + 1];
      // Identical key and content means the same card; reuse it so LazyForEach
      // neither rebuilds the post nor re-runs its media setup.
      if (!structureChanged && old !== undefined && old.key === item.key && old.tweet === item.tweet) {
        rows.push(old);
      } else {
        rows.push(item);
        changed.push(i + 1);
      }
    }
    rows.push(previous[previous.length - 1]);
    this.rows = rows;
    // Publish matching WaterFlow sections before LazyForEach receives its
    // notification. A stale section count can leave an otherwise loaded feed
    // blank until its container is mounted again.
    if (onRowsReady !== null) { onRowsReady(this.contentCount()); }
    for (let i: number = 0; i < this.listeners.length; i++) {
      const listener: DataChangeListener = this.listeners[i];
      if (structureChanged) { listener.onDataReloaded(); }
      else {
        for (let j: number = 0; j < changed.length; j++) { listener.onDataChanged(changed[j]); }
      }
    }
  }
}
