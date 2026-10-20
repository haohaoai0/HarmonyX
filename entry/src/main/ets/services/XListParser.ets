// Decodes REST lists and both Android/web GraphQL List fragments.
import hilog from '@ohos.hilog';
import type { ListPage, ListRow } from '../models/Tweet';
import { userVerifiedType, userAvatarShape } from '../utils/UserIdentity';

const DOMAIN = 0xFF00;
const TAG = 'HarmonyX-List';

export class XListParser {
  static parse(body: string): ListPage | null {
    try {
      const json: Record<string, Object> = JSON.parse(body) as Record<string, Object>;
      const data: Record<string, Object> = XListParser.obj(json, 'data');
      if (json['errors'] !== undefined && Object.keys(data).length === 0) {
        return null;
      }
      const timeline: Record<string, Object> = XListParser.firstTimeline(data);
      let nextToken: string = '';
      const undirected: string[] = [];
      const rows: ListRow[] = [];
      const instructions: Array<Record<string, Object>> = XListParser.arr(timeline, 'instructions');
      for (let i: number = 0; i < instructions.length; i++) {
        const entries: Array<Record<string, Object>> = [...XListParser.arr(instructions[i], 'entries')];
        const replacement: Record<string, Object> = XListParser.obj(instructions[i], 'entry');
        if (Object.keys(replacement).length > 0) { entries.push(replacement); }
        for (let e: number = 0; e < entries.length; e++) {
          const entry: Record<string, Object> = entries[e];
          const content: Record<string, Object> = XListParser.obj(entry, 'content');
          const cursorType: string = String(content['cursor_type'] ?? content['cursorType'] ?? '');
          const value: string = String(content['value'] ?? content['cursorValue'] ?? content['cursor'] ?? '');
          if (value.length > 0) {
            const entryId: string = String(entry['entry_id'] ?? entry['entryId'] ?? '');
            if (cursorType.toLowerCase() === 'bottom' || entryId.startsWith('cursor-bottom-')) {
              nextToken = value;
            } else if (cursorType.length === 0 && entryId.length === 0) {
              undirected.push(value);
            }
            continue;
          }
          const itemContent: Record<string, Object> = XListParser.obj(content, 'itemContent');
          const list: Record<string, Object> = XListParser.obj(itemContent, 'list');
          const row: ListRow | null = XListParser.row(list);
          if (row !== null) {
            rows.push(row);
          }
        }
      }
      if (nextToken.length === 0 && undirected.length >= 2) {
        nextToken = undirected[undirected.length - 1];
      }
      // Fallback: harvest every List-shaped object in the payload.
      const harvested: ListRow[] = [...rows];
      XListParser.harvest(json, harvested, 0);
      if (harvested.length === 0 && Object.keys(timeline).length === 0 &&
        !(data['lists'] instanceof Array)) { return null; }
      return { lists: XListParser.dedupe(harvested), nextToken: nextToken };
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'list parse failed: %{public}s', JSON.stringify(e));
      return null;
    }
  }

  // Management timelines may also contain discovery/recommendation modules.
  // Only the default directory is limited to lists the viewer owns or follows;
  // search, profile memberships and detail reads keep their full results.
  static directory(body: string, viewerId: string): ListPage | null {
    const page: ListPage | null = XListParser.parse(body);
    if (page === null) { return null; }
    return {
      lists: page.lists.filter((row: ListRow): boolean => row.following ||
        (viewerId.length > 0 && row.ownerId === viewerId)),
      nextToken: page.nextToken
    };
  }

  private static row(list: Record<string, Object>): ListRow | null {
    const id: string = String(list['listId'] ?? list['rest_id'] ?? list['id_str'] ?? '');
    const name: string = String(list['name'] ?? '');
    const listShape: boolean = list['__typename'] === 'List' || list['member_count'] !== undefined ||
      list['memberCount'] !== undefined || list['subscriber_count'] !== undefined ||
      list['subscriberCount'] !== undefined || list['accessibility'] !== undefined || list['mode'] !== undefined;
    if (id.length === 0 || name.length === 0 || !listShape) {
      return null;
    }
    // The web List schema carries the owner as user_results; the Android family
    // spells it owner_results/ownerResult. Without the web key the owner is
    // blank and the row no longer reads as the viewer's own list.
    let ownerResults: Record<string, Object> = XListParser.obj(list, 'user_results');
    if (Object.keys(ownerResults).length === 0) { ownerResults = XListParser.obj(list, 'owner_results'); }
    if (Object.keys(ownerResults).length === 0) { ownerResults = XListParser.obj(list, 'ownerResult'); }
    let owner: Record<string, Object> = XListParser.obj(ownerResults, 'result');
    if (Object.keys(owner).length === 0) {
      owner = XListParser.obj(list, 'owner');
    }
    if (Object.keys(owner).length === 0) {
      owner = XListParser.obj(list, 'user');
    }
    const ownerCore: Record<string, Object> = XListParser.obj(owner, 'core');
    const ownerLegacy: Record<string, Object> = XListParser.obj(owner, 'legacy');
    const avatar: Record<string, Object> = XListParser.obj(owner, 'avatar');
    return {
      id: id,
      name: name,
      description: String(list['description'] ?? ''),
      memberCount: XListParser.num(list, list['memberCount'] === undefined ? 'member_count' : 'memberCount'),
      following: Boolean(list['following'] ?? false),
      ownerName: String(ownerCore['name'] ?? ownerLegacy['name'] ?? owner['name'] ?? ''),
      ownerUsername: String(ownerCore['screen_name'] ?? ownerLegacy['screen_name'] ?? owner['screen_name'] ?? ''),
      ownerId: String(owner['rest_id'] ?? ownerResults['rest_id'] ?? owner['id_str'] ?? ''),
      ownerVerifiedType: userVerifiedType(owner), ownerAvatarShape: userAvatarShape(owner),
      ownerAvatarUrl: String(avatar['image_url'] ?? ownerLegacy['profile_image_url_https'] ??
        owner['profile_image_url_https'] ?? ''),
      bannerUrl: XListParser.banner(list),
      hasCustomBanner: XListParser.banner(list, true).length > 0,
      customBannerMediaId: XListParser.customBannerMediaId(list),
      isPrivate: String(list['accessibility'] ?? list['mode'] ?? '').toLowerCase() === 'private',
      pinned: list['pinning'] === true || list['pinned'] === true,
      subscriberCount: XListParser.num(list,
        list['subscriberCount'] === undefined ? 'subscriber_count' : 'subscriberCount')
    };
  }

  static detail(body: string, id: string = ''): ListRow | null {
    const page: ListPage | null = XListParser.parse(body);
    if (page === null) { return null; }
    for (let i: number = 0; i < page.lists.length; i++) {
      if (id.length === 0 || page.lists[i].id === id) { return page.lists[i]; }
    }
    return null;
  }

  private static banner(list: Record<string, Object>, customOnly: boolean = false): string {
    const keys: string[] = customOnly ? ['custom_banner_media_results', 'custom_banner_media', 'banner_media_results'] :
      ['custom_banner_media_results', 'custom_banner_media', 'banner_media_results',
        'default_banner_media_results', 'default_banner_media'];
    for (let i: number = 0; i < keys.length; i++) {
      const media: Record<string, Object> = XListParser.obj(list, keys[i]);
      let result: Record<string, Object> = XListParser.obj(media, 'result');
      if (Object.keys(result).length === 0) { result = media; }
      const info: Record<string, Object> = XListParser.obj(result, 'media_info');
      const image: Record<string, Object> = XListParser.obj(info, 'original_img');
      const url: string = String(image['url'] ?? info['original_img_url'] ?? result['media_url_https'] ?? '');
      if (url.length > 0) { return url; }
    }
    return customOnly ? '' : String(list['banner_url'] ?? '');
  }

  private static customBannerMediaId(list: Record<string, Object>): string {
    const keys: string[] = ['custom_banner_media_results', 'custom_banner_media', 'banner_media_results'];
    for (let i: number = 0; i < keys.length; i++) {
      const media: Record<string, Object> = XListParser.obj(list, keys[i]);
      let result: Record<string, Object> = XListParser.obj(media, 'result');
      if (Object.keys(result).length === 0) { result = media; }
      const key: string = String(result['media_key'] ?? '');
      const match: RegExpMatchArray | null = key.match(/^\d+_(\d+)$/);
      if (match !== null) { return match[1]; }
      const id: Object | undefined = result['media_id'] ?? result['rest_id'] ?? result['id_str'];
      if (typeof id === 'string' && id.length > 0) { return id; }
    }
    return '';
  }

  private static harvest(node: Object, out: ListRow[], depth: number): void {
    if (depth > 24 || out.length >= 500) {
      return;
    }
    if (node === null || node === undefined) {
      return;
    }
    if (node instanceof Array) {
      const items: Array<Object> = node as Array<Object>;
      for (let i: number = 0; i < items.length; i++) {
        XListParser.harvest(items[i], out, depth + 1);
      }
      return;
    }
    if (typeof node !== 'object') {
      return;
    }
    const record: Record<string, Object> = node as Record<string, Object>;
    const row: ListRow | null = XListParser.row(record);
    if (row !== null) {
      out.push(row);
      return;
    }
    const keys: string[] = Object.keys(record);
    for (let i: number = 0; i < keys.length; i++) {
      XListParser.harvest(record[keys[i]], out, depth + 1);
    }
  }

  private static dedupe(rows: ListRow[]): ListRow[] {
    const seen: string[] = [];
    const out: ListRow[] = [];
    for (let i: number = 0; i < rows.length; i++) {
      if (seen.indexOf(rows[i].id) >= 0) {
        continue;
      }
      seen.push(rows[i].id);
      out.push(rows[i]);
    }
    return out;
  }

  private static firstTimeline(data: Record<string, Object>): Record<string, Object> {
    const keys: string[] = Object.keys(data);
    for (let i: number = 0; i < keys.length; i++) {
      const found: Record<string, Object> = XListParser.searchTimeline(data[keys[i]], 0);
      if (Object.keys(found).length > 0) {
        return found;
      }
    }
    return {};
  }

  private static searchTimeline(node: Object, depth: number): Record<string, Object> {
    if (depth > 10 || node === null || node === undefined || typeof node !== 'object') {
      return {};
    }
    if (node instanceof Array) {
      const items: Array<Object> = node as Array<Object>;
      for (let i: number = 0; i < items.length; i++) {
        const found: Record<string, Object> = XListParser.searchTimeline(items[i], depth + 1);
        if (Object.keys(found).length > 0) {
          return found;
        }
      }
      return {};
    }
    const record: Record<string, Object> = node as Record<string, Object>;
    if (record['instructions'] !== undefined) {
      return record;
    }
    const keys: string[] = Object.keys(record);
    for (let i: number = 0; i < keys.length; i++) {
      const found: Record<string, Object> = XListParser.searchTimeline(record[keys[i]], depth + 1);
      if (Object.keys(found).length > 0) {
        return found;
      }
    }
    return {};
  }

  private static arr(source: Record<string, Object>, key: string): Array<Record<string, Object>> {
    const value: Object | undefined = source[key];
    if (value === undefined || value === null || !(value instanceof Array)) {
      return [];
    }
    return value as Array<Record<string, Object>>;
  }

  private static obj(source: Record<string, Object>, key: string): Record<string, Object> {
    const value: Object | undefined = source[key];
    if (value === undefined || value === null || typeof value !== 'object' ||
      value instanceof Array) {
      return {};
    }
    return value as Record<string, Object>;
  }

  private static num(source: Record<string, Object>, key: string): number {
    const value: Object | undefined = source[key];
    if (value === undefined || value === null) {
      return 0;
    }
    const parsed: number = Number(value);
    return isNaN(parsed) ? 0 : parsed;
  }
}
