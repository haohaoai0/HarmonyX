import { BookmarkCollection, ServerDraftTweet } from '../models/Bookmark';

// The collection and server-draft payloads have no complete document in the
// bundled operation registry.  These parsers are intentionally conservative:
// they accept only nodes that carry the explicit id fields X uses for these
// objects, then tolerate the nesting changes that occur between web clients.
export class XBookmarkParser {
  static parseCollections(body: string): BookmarkCollection[] {
    try {
      const root: Object = JSON.parse(body) as Object;
      const rows: BookmarkCollection[] = [];
      XBookmarkParser.collectCollections(root, rows, 0);
      return rows;
    } catch (error) {
      return [];
    }
  }

  static parseDrafts(body: string): ServerDraftTweet[] {
    try {
      const root: Object = JSON.parse(body) as Object;
      const rows: ServerDraftTweet[] = [];
      XBookmarkParser.collectDrafts(root, rows, 0);
      return rows;
    } catch (error) {
      return [];
    }
  }

  private static collectCollections(value: Object, rows: BookmarkCollection[], depth: number): void {
    if (depth > 14 || value === null || value === undefined) {
      return;
    }
    if (value instanceof Array) {
      const items: Object[] = value as Object[];
      for (let i: number = 0; i < items.length; i++) {
        XBookmarkParser.collectCollections(items[i], rows, depth + 1);
      }
      return;
    }
    if (typeof value !== 'object') {
      return;
    }
    const node: Record<string, Object> = value as Record<string, Object>;
    const nested: Object | undefined = node['bookmark_collection'] ?? node['bookmarkCollection'];
    if (nested !== undefined && nested !== null && typeof nested === 'object') {
      XBookmarkParser.addCollection(nested as Record<string, Object>, rows, true);
    }
    XBookmarkParser.addCollection(node, rows);
    const keys: string[] = Object.keys(node);
    for (let i: number = 0; i < keys.length; i++) {
      const child: Object | undefined = node[keys[i]];
      if (child !== undefined && child !== null && typeof child === 'object') {
        XBookmarkParser.collectCollections(child, rows, depth + 1);
      }
    }
  }

  private static addCollection(node: Record<string, Object>, rows: BookmarkCollection[],
    nestedCollection: boolean = false): void {
    const typeName: string = XBookmarkParser.stringOf(node, ['__typename', 'type']);
    const isCollection: boolean = node['bookmark_collection_id'] !== undefined ||
      node['collection_id'] !== undefined ||
      typeName.toLowerCase().indexOf('bookmarkcollection') >= 0 ||
      typeName.toLowerCase().indexOf('bookmark_collection') >= 0;
    if (!nestedCollection && !isCollection) {
      return;
    }
    const id: string = XBookmarkParser.stringOf(node,
      ['bookmark_collection_id', 'collection_id', 'rest_id', 'id']);
    const name: string = XBookmarkParser.stringOf(node,
      ['name', 'title', 'bookmark_collection_name']);
    if (id.length === 0 || name.length === 0 || XBookmarkParser.hasCollection(rows, id)) {
      return;
    }
    const count: number = XBookmarkParser.numberOf(node,
      ['tweet_count', 'item_count', 'bookmark_count', 'count']);
    rows.push(new BookmarkCollection(id, name, count));
  }

  private static collectDrafts(value: Object, rows: ServerDraftTweet[], depth: number): void {
    if (depth > 14 || value === null || value === undefined) {
      return;
    }
    if (value instanceof Array) {
      const items: Object[] = value as Object[];
      for (let i: number = 0; i < items.length; i++) {
        XBookmarkParser.collectDrafts(items[i], rows, depth + 1);
      }
      return;
    }
    if (typeof value !== 'object') {
      return;
    }
    const node: Record<string, Object> = value as Record<string, Object>;
    XBookmarkParser.addDraft(node, rows);
    const keys: string[] = Object.keys(node);
    for (let i: number = 0; i < keys.length; i++) {
      const child: Object | undefined = node[keys[i]];
      if (child !== undefined && child !== null && typeof child === 'object') {
        XBookmarkParser.collectDrafts(child, rows, depth + 1);
      }
    }
  }

  private static addDraft(node: Record<string, Object>, rows: ServerDraftTweet[]): void {
    const id: string = XBookmarkParser.stringOf(node,
      ['draft_tweet_id', 'draftTweetId', 'draft_id']);
    if (id.length === 0 || XBookmarkParser.hasDraft(rows, id)) {
      return;
    }
    const text: string = XBookmarkParser.stringOf(node,
      ['tweet_text', 'full_text', 'text']);
    const reply: Record<string, Object> = XBookmarkParser.objectOf(node['reply']);
    const replyToId: string = XBookmarkParser.stringOf(reply,
      ['in_reply_to_tweet_id', 'in_reply_to_status_id', 'tweet_id']);
    const updatedAt: number = XBookmarkParser.numberOf(node,
      ['updated_at_ms', 'updated_at', 'created_at_ms', 'created_at']);
    rows.push(new ServerDraftTweet(id, text, replyToId, updatedAt));
  }

  private static stringOf(node: Record<string, Object>, keys: string[]): string {
    for (let i: number = 0; i < keys.length; i++) {
      const value: Object | undefined = node[keys[i]];
      if (typeof value === 'string' || typeof value === 'number') {
        const text: string = String(value).trim();
        if (text.length > 0) {
          return text;
        }
      }
    }
    return '';
  }

  private static numberOf(node: Record<string, Object>, keys: string[]): number {
    for (let i: number = 0; i < keys.length; i++) {
      const value: Object | undefined = node[keys[i]];
      if (typeof value === 'number' || typeof value === 'string') {
        const numberValue: number = Number(value);
        if (!isNaN(numberValue) && numberValue >= 0) {
          return numberValue;
        }
      }
    }
    return 0;
  }

  private static objectOf(value: Object | undefined): Record<string, Object> {
    if (value === undefined || value === null || typeof value !== 'object' || value instanceof Array) {
      return {};
    }
    return value as Record<string, Object>;
  }

  private static hasCollection(rows: BookmarkCollection[], id: string): boolean {
    for (let i: number = 0; i < rows.length; i++) {
      if (rows[i].id === id) {
        return true;
      }
    }
    return false;
  }

  private static hasDraft(rows: ServerDraftTweet[], id: string): boolean {
    for (let i: number = 0; i < rows.length; i++) {
      if (rows[i].id === id) {
        return true;
      }
    }
    return false;
  }
}
