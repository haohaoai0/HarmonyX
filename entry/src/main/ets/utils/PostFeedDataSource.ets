export class PostFeedItem {
  key: string;
  index: number;

  constructor(key: string, index: number) {
    this.key = key;
    this.index = index;
  }
}

// Include the full-width header/footer in the same lazy source as the cards.
export class PostFeedDataSource implements IDataSource {
  private items: PostFeedItem[] = [];
  private listeners: DataChangeListener[] = [];

  totalCount(): number { return this.items.length; }
  getData(index: number): PostFeedItem { return this.items[index]; }
  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) { this.listeners.push(listener); }
  }
  unregisterDataChangeListener(listener: DataChangeListener): void {
    const index: number = this.listeners.indexOf(listener);
    if (index >= 0) { this.listeners.splice(index, 1); }
  }
  replace(keys: string[]): void {
    const next: PostFeedItem[] = [new PostFeedItem('header', -1)];
    for (let index: number = 0; index < keys.length; index++) {
      // The builder receives an index into the parent's filtered array. Include
      // it so a retained row cannot keep a stale index after search/deletion.
      next.push(new PostFeedItem('post:' + index.toString() + ':' + keys[index], index));
    }
    next.push(new PostFeedItem('footer', -2));
    const previous: PostFeedItem[] = this.items;
    this.items = next;
    for (const listener of this.listeners) {
      if (previous.length !== next.length) { listener.onDataReloaded(); }
      else {
        for (let index: number = 0; index < next.length; index++) {
          if (previous[index].key !== next[index].key) { listener.onDataChanged(index); }
        }
      }
    }
  }
}
