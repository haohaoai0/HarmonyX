import type { CommunityRow } from '../models/Community';
import type { CommunityTimelineRouteParam } from '../pages/Communities';

export function communityRoute(row: CommunityRow): CommunityTimelineRouteParam {
  return { communityId: row.id, title: row.name, description: row.description,
    memberCount: row.memberCount, moderatorCount: row.moderatorCount, bannerUrl: row.bannerUrl,
    joinPolicy: row.joinPolicy, ruleCount: row.ruleCount, rules: row.rules, joined: row.joined,
    community: row };
}

export function openCommunitySource(stack: NavPathStack, id: string, name: string): void {
  const row: CommunityRow = { id: id, name: name, description: '', memberCount: 0,
    moderatorCount: 0, bannerUrl: '', joinPolicy: '', ruleCount: 0, rules: [], joined: false };
  stack.pushPath({ name: 'CommunityTimeline', param: communityRoute(row) });
}
