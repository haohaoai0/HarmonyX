// Typed view of the GIF items returned by X's private GIF search operations.
export class GifSearchItem {
  id: string;
  fullImageUrl: string;
  thumbnailUrl: string;
  width: number;
  height: number;

  constructor(id: string, fullImageUrl: string, thumbnailUrl: string, width: number, height: number) {
    this.id = id;
    this.fullImageUrl = fullImageUrl;
    this.thumbnailUrl = thumbnailUrl;
    this.width = width;
    this.height = height;
  }
}

export class GifSearchParser {
  static parse(body: string): GifSearchItem[] {
    try {
      const root: Object = JSON.parse(body) as Object;
      const items: GifSearchItem[] = [];
      GifSearchParser.collect(root, items, 0);
      return items;
    } catch (error) {
      return [];
    }
  }

  private static collect(value: Object, items: GifSearchItem[], depth: number): void {
    if (depth > 12 || value === null || value === undefined) {
      return;
    }
    if (value instanceof Array) {
      const values: Object[] = value as Object[];
      for (let i: number = 0; i < values.length; i++) {
        GifSearchParser.collect(values[i], items, depth + 1);
      }
      return;
    }
    if (typeof value !== 'object') {
      return;
    }
    const node: Record<string, Object> = value as Record<string, Object>;
    GifSearchParser.addItem(node, items);
    const keys: string[] = Object.keys(node);
    for (let i: number = 0; i < keys.length; i++) {
      const child: Object | undefined = node[keys[i]];
      if (child !== undefined && child !== null && typeof child === 'object') {
        GifSearchParser.collect(child, items, depth + 1);
      }
    }
  }

  private static addItem(node: Record<string, Object>, items: GifSearchItem[]): void {
    const id: string = GifSearchParser.stringValue(node['id']);
    const fullImage: Record<string, Object> = GifSearchParser.objectValue(node['full_image']);
    const fullUrl: string = GifSearchParser.stringValue(fullImage['url']);
    if (id.length === 0 || fullUrl.length === 0 || GifSearchParser.hasItem(items, id)) {
      return;
    }
    const thumbnails: Object[] = GifSearchParser.arrayValue(node['thumbnail_images']);
    let thumbnailUrl: string = fullUrl;
    if (thumbnails.length > 0) {
      const thumbnail: Record<string, Object> = GifSearchParser.objectValue(thumbnails[0]);
      const parsedThumbnailUrl: string = GifSearchParser.stringValue(thumbnail['url']);
      if (parsedThumbnailUrl.length > 0) {
        thumbnailUrl = parsedThumbnailUrl;
      }
    }
    const width: number = GifSearchParser.numberValue(fullImage['width']);
    const height: number = GifSearchParser.numberValue(fullImage['height']);
    items.push(new GifSearchItem(id, fullUrl, thumbnailUrl, width, height));
  }

  private static objectValue(value: Object | undefined): Record<string, Object> {
    if (value === undefined || value === null || typeof value !== 'object' || value instanceof Array) {
      return {};
    }
    return value as Record<string, Object>;
  }

  private static arrayValue(value: Object | undefined): Object[] {
    if (value === undefined || value === null || !(value instanceof Array)) {
      return [];
    }
    return value as Object[];
  }

  private static stringValue(value: Object | undefined): string {
    if (typeof value === 'string' || typeof value === 'number') {
      return String(value);
    }
    return '';
  }

  private static numberValue(value: Object | undefined): number {
    if (typeof value === 'number') {
      return value;
    }
    if (typeof value === 'string') {
      const parsed: number = Number(value);
      return isNaN(parsed) ? 0 : parsed;
    }
    return 0;
  }

  private static hasItem(items: GifSearchItem[], id: string): boolean {
    for (let i: number = 0; i < items.length; i++) {
      if (items[i].id === id) {
        return true;
      }
    }
    return false;
  }
}
