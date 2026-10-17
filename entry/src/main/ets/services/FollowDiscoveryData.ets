import type { UserRow } from '../models/Tweet';
import { XTimelineParser } from './XTimelineParser';

export class FollowSuggestionGroup {
  id: string = '';
  title: string = '';
  description: string = '';
  users: UserRow[] = [];
  afterTweetId: string = '';
}

export class FollowDiscoveryData {
  groups: FollowSuggestionGroup[] = [];
  users: UserRow[] = [];
  nextToken: string = '';

  // Only user items and recommendation modules qualify. Tweet authors must
  // never turn into "who to follow" rows merely because they share a response.
  static parse(body: string): FollowDiscoveryData | null {
    try {
      const root: Record<string, Object> = JSON.parse(body) as Record<string, Object>;
      const page: FollowDiscoveryData = new FollowDiscoveryData();
      FollowDiscoveryData.walk(root, page, 0);
      page.users = FollowDiscoveryData.unique(page.users);
      page.groups = page.groups.filter((group: FollowSuggestionGroup, index: number): boolean =>
        page.groups.findIndex((candidate: FollowSuggestionGroup): boolean => candidate.id === group.id) === index);
      return page;
    } catch (error) {
      return null;
    }
  }

  static unique(rows: UserRow[]): UserRow[] {
    const seen: Set<string> = new Set<string>();
    const result: UserRow[] = [];
    for (let i: number = 0; i < rows.length; i++) {
      if (!seen.has(rows[i].id)) {
        seen.add(rows[i].id);
        result.push(rows[i]);
      }
    }
    return result;
  }

  static copyFollowing(row: UserRow, following: boolean): UserRow {
    return {
      id: row.id, name: row.name, username: row.username, avatarUrl: row.avatarUrl,
      avatarColor: row.avatarColor, verified: row.verified, bio: row.bio,
      following: following, followedBy: row.followedBy, bannerUrl: row.bannerUrl, verifiedType: row.verifiedType, avatarShape: row.avatarShape
    };
  }

  private static walk(value: Object, page: FollowDiscoveryData, depth: number): void {
    if (depth > 18 || value === null || typeof value !== 'object') { return; }
    if (value instanceof Array) {
      const values: Object[] = value as Object[];
      for (let i: number = 0; i < values.length; i++) { FollowDiscoveryData.walk(values[i], page, depth + 1); }
      return;
    }
    const source: Record<string, Object> = value as Record<string, Object>;
    // Entries preserve X's ordering and module placement in both home/profile.
    const entries: Object | undefined = source['entries'];
    if (entries instanceof Array) {
      let precedingTweet: string = '';
      const list: Record<string, Object>[] = entries as Record<string, Object>[];
      for (let i: number = 0; i < list.length; i++) {
        const content: Record<string, Object> = FollowDiscoveryData.obj(list[i], 'content');
        const item: Record<string, Object> = FollowDiscoveryData.obj(content, 'itemContent');
        const tweet: Record<string, Object> = FollowDiscoveryData.obj(
          FollowDiscoveryData.obj(item, 'tweet_results'), 'result');
        const wrapped: Record<string, Object> = FollowDiscoveryData.obj(tweet, 'tweet');
        const tweetId: string = String(tweet['rest_id'] ?? wrapped['rest_id'] ?? '');
        if (tweetId.length > 0) { precedingTweet = tweetId; }
        const group: FollowSuggestionGroup | null = FollowDiscoveryData.group(list[i], precedingTweet);
        if (group !== null) {
          page.groups.push(group);
          page.users.push(...group.users);
        } else {
          FollowDiscoveryData.walk(content, page, depth + 1);
        }
      }
      return;
    }
    if (String(source['cursorType'] ?? source['cursor_type'] ?? '').toLowerCase() === 'bottom') {
      page.nextToken = String(source['value'] ?? '');
      return;
    }
    if (source['tweet_results'] !== undefined || source['tweet'] !== undefined ||
      String(source['__typename'] ?? '') === 'Tweet') { return; }
    const results: Record<string, Object> = FollowDiscoveryData.obj(source, 'user_results');
    const user: Record<string, Object> = FollowDiscoveryData.obj(results, 'result');
    const row: UserRow | null = XTimelineParser.rowFromUser(user);
    if (row !== null) { page.users.push(row); return; }
    // REST recommendations wrap legacy users in a "user" field.
    const restUser: Record<string, Object> = FollowDiscoveryData.obj(source, 'user');
    const restRow: UserRow | null = XTimelineParser.rowFromUser(restUser);
    if (restRow !== null) { page.users.push(restRow); return; }
    if (String(source['__typename'] ?? '') === 'User' || source['id_str'] !== undefined) {
      const direct: UserRow | null = XTimelineParser.rowFromUser(source);
      if (direct !== null) { page.users.push(direct); }
      return;
    }
    const keys: string[] = Object.keys(source);
    for (let i: number = 0; i < keys.length; i++) {
      const child: Object | undefined = source[keys[i]];
      if (child !== undefined) { FollowDiscoveryData.walk(child, page, depth + 1); }
    }
  }

  private static group(entry: Record<string, Object>, afterTweetId: string): FollowSuggestionGroup | null {
    const content: Record<string, Object> = FollowDiscoveryData.obj(entry, 'content');
    const items: Object | undefined = content['items'];
    if (!(items instanceof Array)) { return null; }
    const users: UserRow[] = [];
    const list: Record<string, Object>[] = items as Record<string, Object>[];
    for (let i: number = 0; i < list.length; i++) {
      const item: Record<string, Object> = FollowDiscoveryData.obj(list[i], 'item');
      const row: UserRow | null = XTimelineParser.parseUserItemContent(FollowDiscoveryData.obj(item, 'itemContent'));
      if (row !== null) { users.push(row); }
    }
    if (users.length === 0) { return null; }
    const group: FollowSuggestionGroup = new FollowSuggestionGroup();
    group.id = String(entry['entryId'] ?? entry['entry_id'] ?? '') ||
      'suggestions-' + afterTweetId + '-' + users.map((row: UserRow): string => row.id).join('-');
    group.title = String(FollowDiscoveryData.obj(content, 'header')['text'] ?? '');
    group.description = String(FollowDiscoveryData.obj(content, 'header')['subtitle'] ?? '');
    group.users = FollowDiscoveryData.unique(users);
    group.afterTweetId = afterTweetId;
    return group;
  }

  private static obj(source: Record<string, Object>, key: string): Record<string, Object> {
    const value: Object | undefined = source[key];
    return value !== undefined && value !== null && typeof value === 'object' && !(value instanceof Array) ?
      value as Record<string, Object> : {};
  }
}
