// Decodes community objects from CommunitiesMyQuery and
// CommunityDiscoveryTimelineQuery. The APK operations use more than one
// timeline wrapper, so the parser also has a constrained recursive fallback.
import hilog from '@ohos.hilog';
import { userIsVerified, userVerifiedType, userAvatarShape } from '../utils/UserIdentity';
import type { CommunityPage, CommunityRow, CommunityRule, CommunityTopic } from '../models/Community';
import type { TweetAuthor } from '../models/Tweet';

const DOMAIN = 0xFF00;
const TAG = 'HarmonyX-Community';

export class XCommunityParser {
  static parse(body: string): CommunityPage | null {
    try {
      const json: Record<string, Object> = JSON.parse(body) as Record<string, Object>;
      const rows: CommunityRow[] = [];
      XCommunityParser.harvest(json, rows, 0);
      return {
        communities: XCommunityParser.dedupe(rows),
        nextToken: XCommunityParser.nextTokenOf(json, 0)
      };
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'community parse failed: %{public}s', JSON.stringify(e));
      return null;
    }
  }

  // FetchUserCommunityTopics has no request variables in the APK table. Its
  // payload shape has changed between X clients, so topic extraction is kept
  // independent from community-directory parsing.
  static parseTopics(body: string): CommunityTopic[] {
    try {
      const json: Record<string, Object> = JSON.parse(body) as Record<string, Object>;
      const topics: CommunityTopic[] = [];
      XCommunityParser.harvestTopics(json, topics, 0);
      return XCommunityParser.dedupeTopics(topics);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'community topic parse failed: %{public}s', JSON.stringify(e));
      return [];
    }
  }

  private static harvest(node: Object, out: CommunityRow[], depth: number): void {
    if (depth > 24 || out.length >= 100 || node === null || node === undefined) {
      return;
    }
    if (node instanceof Array) {
      const items: Array<Object> = node as Array<Object>;
      for (let i: number = 0; i < items.length; i++) {
        XCommunityParser.harvest(items[i], out, depth + 1);
      }
      return;
    }
    if (typeof node !== 'object') {
      return;
    }
    const record: Record<string, Object> = node as Record<string, Object>;
    const row: CommunityRow | null = XCommunityParser.row(record);
    if (row !== null) {
      out.push(row);
      return;
    }
    const keys: string[] = Object.keys(record);
    for (let i: number = 0; i < keys.length; i++) {
      XCommunityParser.harvest(record[keys[i]], out, depth + 1);
    }
  }

  private static row(record: Record<string, Object>): CommunityRow | null {
    const typeName: string = String(record['__typename'] ?? '').toLowerCase();
    if (typeName.indexOf('topic') >= 0 || typeName.indexOf('rule') >= 0) { return null; }
    const isCommunity: boolean = typeName.indexOf('community') >= 0 ||
      record['member_count'] !== undefined || record['join_policy'] !== undefined ||
      record['custom_banner_media'] !== undefined;
    if (!isCommunity) {
      return null;
    }
    const id: string = String(record['rest_id'] ?? record['id'] ?? '');
    const name: string = String(record['name'] ?? '');
    if (id.length === 0 || name.length === 0) {
      return null;
    }
    return {
      id: id,
      name: name,
      description: XCommunityParser.descriptionOf(record),
      memberCount: XCommunityParser.numberOf(record['member_count']),
      moderatorCount: XCommunityParser.numberOf(record['moderator_count']),
      bannerUrl: XCommunityParser.bannerUrl(record),
      joinPolicy: XCommunityParser.stringOf(record['join_policy']),
      ruleCount: XCommunityParser.arrayLength(record['rules']),
      rules: XCommunityParser.rulesOf(record['rules']),
      joined: XCommunityParser.joined(record),
      topicName: XCommunityParser.stringOf(XCommunityParser.objectOf(record['primary_community_topic'])['name'] ??
        XCommunityParser.objectOf(record['topic'])['name'] ?? XCommunityParser.objectOf(record['community_topic'])['topic_name']),
      topicId: XCommunityParser.stringOf(XCommunityParser.objectOf(record['primary_community_topic'])['topic_id'] ??
        XCommunityParser.objectOf(record['topic'])['topic_id'] ?? XCommunityParser.objectOf(record['community_topic'])['topic_id']),
      members: XCommunityParser.people(record['members_facepile_results']),
      moderators: XCommunityParser.people(record['moderators_facepile_results']),
      creator: XCommunityParser.person(record['creator_results'] ?? record['admin_results']),
      createdAt: XCommunityParser.stringOf(record['created_at']),
      joinQuestion: XCommunityParser.stringOf(record['question'])
    };
  }

  private static harvestTopics(node: Object, out: CommunityTopic[], depth: number): void {
    if (depth > 12 || out.length >= 40 || node === null || node === undefined) {
      return;
    }
    if (node instanceof Array) {
      const items: Array<Object> = node as Array<Object>;
      for (let i: number = 0; i < items.length; i++) {
        XCommunityParser.harvestTopics(items[i], out, depth + 1);
      }
      return;
    }
    if (typeof node !== 'object') {
      return;
    }
    const record: Record<string, Object> = node as Record<string, Object>;
    const topic: CommunityTopic | null = XCommunityParser.topic(record);
    if (topic !== null) {
      out.push(topic);
      return;
    }
    const keys: string[] = Object.keys(record);
    for (let i: number = 0; i < keys.length; i++) {
      XCommunityParser.harvestTopics(record[keys[i]], out, depth + 1);
    }
  }

  private static topic(record: Record<string, Object>): CommunityTopic | null {
    const typeName: string = XCommunityParser.stringOf(record['__typename']).toLowerCase();
    const hasTopicId: boolean = record['topic_id'] !== undefined || record['topicId'] !== undefined;
    if (typeName.indexOf('communitytopic') < 0 && !hasTopicId) {
      return null;
    }
    const id: string = XCommunityParser.stringOf(record['topic_id'] ?? record['topicId'] ??
      record['rest_id'] ?? record['id']);
    const name: string = XCommunityParser.stringOf(record['topic_name'] ?? record['name'] ?? record['display_name'] ??
      record['displayName']);
    if (id.length === 0 || name.length === 0) {
      return null;
    }
    return { id: id, name: name };
  }

  // Community directories use the same URT cursor shape as the regular X
  // timelines. Only accept a bottom cursor so a top/refresh cursor cannot
  // accidentally replay the first page.
  private static nextTokenOf(node: Object, depth: number): string {
    if (depth > 14 || node === null || node === undefined) {
      return '';
    }
    if (node instanceof Array) {
      const items: Array<Object> = node as Array<Object>;
      for (let i: number = 0; i < items.length; i++) {
        const found: string = XCommunityParser.nextTokenOf(items[i], depth + 1);
        if (found.length > 0) {
          return found;
        }
      }
      return '';
    }
    if (typeof node !== 'object') {
      return '';
    }
    const record: Record<string, Object> = node as Record<string, Object>;
    const sliceCursor: string = XCommunityParser.stringOf(record['next_cursor']);
    if (sliceCursor.length > 0) { return sliceCursor; }
    const cursorType: string = XCommunityParser.stringOf(record['cursor_type'] ?? record['cursorType']);
    const entryId: string = XCommunityParser.stringOf(record['entry_id'] ?? record['entryId']);
    const value: string = XCommunityParser.stringOf(record['value']);
    if (value.length > 0 && (cursorType === 'Bottom' || entryId.startsWith('cursor-bottom-'))) {
      return value;
    }
    const keys: string[] = Object.keys(record);
    for (let i: number = 0; i < keys.length; i++) {
      const found: string = XCommunityParser.nextTokenOf(record[keys[i]], depth + 1);
      if (found.length > 0) {
        return found;
      }
    }
    return '';
  }

  private static joined(record: Record<string, Object>): boolean {
    const role: string = XCommunityParser.stringOf(record['role']).toLowerCase();
    return Boolean(record['is_member'] ?? record['joined'] ?? false) ||
      (['member', 'moderator', 'admin', 'owner'].indexOf(role) >= 0);
  }

  private static bannerUrl(record: Record<string, Object>): string {
    const custom: string = XCommunityParser.mediaUrl(record['custom_banner_media_results'] ?? record['custom_banner_media']);
    if (custom.length > 0) {
      return custom;
    }
    return XCommunityParser.mediaUrl(record['default_banner_media_results'] ?? record['default_banner_media']);
  }

  private static mediaUrl(value: Object | undefined): string {
    const mediaResults: Record<string, Object> = XCommunityParser.objectOf(value);
    const result: Record<string, Object> = XCommunityParser.objectOf(mediaResults['result'] ?? value);
    const mediaInfo: Record<string, Object> = XCommunityParser.objectOf(result['media_info']);
    return XCommunityParser.stringOf(mediaInfo['original_img_url'] ??
      XCommunityParser.objectOf(mediaInfo['original_img'])['url']);
  }

  static source(node: Record<string, Object>): CommunityRow | null {
    const results: Record<string, Object> = XCommunityParser.objectOf(node['community_results']);
    const community: Record<string, Object> = XCommunityParser.objectOf(results['result'] ?? node['community']);
    return XCommunityParser.row(community);
  }

  private static person(value: Object | undefined): TweetAuthor | undefined {
    const wrapper: Record<string, Object> = XCommunityParser.objectOf(value);
    const user: Record<string, Object> = XCommunityParser.objectOf(wrapper['result'] ?? value);
    const legacy: Record<string, Object> = XCommunityParser.objectOf(user['legacy']);
    const core: Record<string, Object> = XCommunityParser.objectOf(user['core']);
    const name: string = XCommunityParser.stringOf(core['name'] ?? legacy['name']);
    const username: string = XCommunityParser.stringOf(core['screen_name'] ?? legacy['screen_name']);
    if (name.length === 0 && username.length === 0) { return undefined; }
    return { id: XCommunityParser.stringOf(user['rest_id']), name: name.length > 0 ? name : username,
      username: username, avatarColor: '#536471',
      avatarUrl: XCommunityParser.stringOf(XCommunityParser.objectOf(user['avatar'])['image_url'] ??
        legacy['profile_image_url_https']), verified: userIsVerified(user), verifiedType: userVerifiedType(user), avatarShape: userAvatarShape(user) };
  }

  private static people(value: Object | undefined): TweetAuthor[] {
    if (!(value instanceof Array)) { return []; }
    const items: Object[] = value as Object[];
    const users: TweetAuthor[] = [];
    for (let i: number = 0; i < items.length; i++) {
      const user: TweetAuthor | undefined = XCommunityParser.person(items[i]);
      if (user !== undefined) { users.push(user); }
    }
    return users;
  }

  private static objectOf(value: Object | undefined): Record<string, Object> {
    if (value === undefined || value === null || typeof value !== 'object' || value instanceof Array) {
      return {};
    }
    return value as Record<string, Object>;
  }

  private static stringOf(value: Object | undefined): string {
    return value === undefined || value === null ? '' : String(value);
  }

  private static arrayLength(value: Object | undefined): number {
    return value instanceof Array ? value.length : 0;
  }

  private static rulesOf(value: Object | undefined): CommunityRule[] {
    if (!(value instanceof Array)) {
      return [];
    }
    const rawRules: Array<Object> = value as Array<Object>;
    const rules: CommunityRule[] = [];
    for (let i: number = 0; i < rawRules.length; i++) {
      const rawRule: Record<string, Object> = XCommunityParser.objectOf(rawRules[i]);
      const name: string = XCommunityParser.stringOf(rawRule['name']);
      if (name.length === 0) {
        continue;
      }
      rules.push({
        id: XCommunityParser.stringOf(rawRule['rest_id']),
        name: name,
        description: XCommunityParser.stringOf(rawRule['description'])
      });
    }
    return rules;
  }

  private static descriptionOf(record: Record<string, Object>): string {
    const direct: Object | undefined = record['description'];
    if (typeof direct === 'string') {
      return direct;
    }
    if (direct !== undefined && direct !== null && typeof direct === 'object' &&
      !(direct instanceof Array)) {
      const details: Record<string, Object> = direct as Record<string, Object>;
      return String(details['text'] ?? '');
    }
    return '';
  }

  private static numberOf(value: Object | undefined): number {
    if (value === undefined || value === null) {
      return 0;
    }
    const parsed: number = Number(value);
    return isNaN(parsed) ? 0 : parsed;
  }

  private static dedupe(rows: CommunityRow[]): CommunityRow[] {
    const ids: string[] = [];
    const result: CommunityRow[] = [];
    for (let i: number = 0; i < rows.length; i++) {
      if (ids.indexOf(rows[i].id) >= 0) {
        continue;
      }
      ids.push(rows[i].id);
      result.push(rows[i]);
    }
    return result;
  }

  private static dedupeTopics(topics: CommunityTopic[]): CommunityTopic[] {
    const ids: string[] = [];
    const result: CommunityTopic[] = [];
    for (let i: number = 0; i < topics.length; i++) {
      if (ids.indexOf(topics[i].id) >= 0) {
        continue;
      }
      ids.push(topics[i].id);
      result.push(topics[i]);
    }
    return result;
  }
}
