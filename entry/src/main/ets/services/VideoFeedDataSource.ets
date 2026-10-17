import type { MediaAttachment, Tweet } from '../models/Tweet';

// Stable observed entries let post/count changes update a cached page without
// replacing its AVPlayer. LazyForEach owns only the nearby page components.
@Observed
export class VideoFeedItem {
  tweet: Tweet;
  attachments: MediaAttachment[];
  index: number;

  constructor(tweet: Tweet, attachments: MediaAttachment[], index: number) {
    this.tweet = tweet;
    this.attachments = attachments;
    this.index = index;
  }
}

export class VideoFeedDataSource implements IDataSource {
  private items: VideoFeedItem[] = [];
  private ids: Set<string> = new Set<string>();
  private listeners: DataChangeListener[] = [];

  totalCount(): number { return this.items.length; }
  getData(index: number): VideoFeedItem { return this.items[index]; }
  has(tweetId: string): boolean { return this.ids.has(tweetId); }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) { this.listeners.push(listener); }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const index: number = this.listeners.indexOf(listener);
    if (index >= 0) { this.listeners.splice(index, 1); }
  }

  reset(items: VideoFeedItem[]): void {
    this.items = items.slice();
    this.ids.clear();
    for (let index: number = 0; index < this.items.length; index++) {
      this.ids.add(this.items[index].tweet.id);
    }
    for (const listener of this.listeners) { listener.onDataReloaded(); }
  }

  append(items: VideoFeedItem[]): void {
    for (const item of items) {
      const index: number = this.items.length;
      this.items.push(item);
      this.ids.add(item.tweet.id);
      for (const listener of this.listeners) { listener.onDataAdd(index); }
    }
  }

  remove(index: number): void {
    if (index < 0 || index >= this.items.length) { return; }
    this.ids.delete(this.items[index].tweet.id);
    this.items.splice(index, 1);
    for (let next: number = index; next < this.items.length; next++) {
      this.items[next].index = next;
    }
    for (const listener of this.listeners) { listener.onDataDelete(index); }
  }
}
