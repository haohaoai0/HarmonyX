import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import type { CommunityRow, CommunityPage } from '../models/Community';
import type { ListRow, ListPage } from '../models/Tweet';
import { homeTimelineStore, TimelineTopic } from './HomeTimelineStore';
import { pinnedHomeListStore } from './PinnedHomeListStore';
import { copyList, listStateStore } from './ListStateStore';
import { XCommunityParser } from './XCommunityParser';
import { XListParser } from './XListParser';
import { XPrivateResult, xPrivateClient } from './XPrivateClient';

export class HomeCommunityOrder {
  id: string = '';
  ranking: string = 'Recency';
}

class HomeSourcePreferences {
  communities: CommunityRow[] = [];
  order: string[] = [];
  rankings: HomeCommunityOrder[] = [];
}

export class HomeTimelineSourceStore {
  private viewer: string = '';
  private state: HomeSourcePreferences = new HomeSourcePreferences();
  private lists: ListRow[] = [];
  private communities: CommunityRow[] = [];
  private pendingLoad: Promise<boolean> | null = null;

  load(context: common.Context, viewer: string): void {
    this.viewer = viewer;
    this.state = new HomeSourcePreferences();
    this.lists = pinnedHomeListStore.current(viewer);
    this.communities = [];
    this.pendingLoad = null;
    if (viewer.length > 0) {
      try {
        const store = preferences.getPreferencesSync(context, { name: 'harmonyx_home_sources' });
        const saved: HomeSourcePreferences = JSON.parse(store.getSync(viewer, '{}') as string) as HomeSourcePreferences;
        this.state.communities = (saved.communities ?? []).filter((row: CommunityRow): boolean =>
          row !== null && typeof row.id === 'string' && row.id.length > 0 && typeof row.name === 'string');
        this.state.order = (saved.order ?? []).filter((id: string): boolean => typeof id === 'string');
        this.state.rankings = (saved.rankings ?? []).filter((row: HomeCommunityOrder): boolean =>
          row !== null && typeof row.id === 'string' && this.validRanking(row.ranking));
      } catch (error) { this.state = new HomeSourcePreferences(); }
    }
    this.apply();
  }

  private validRanking(value: string): boolean { return ['Relevance', 'Recency', 'Likes'].indexOf(value) >= 0; }

  private apply(): void {
    homeTimelineStore.setCommunityTopics(this.state.communities,
      this.state.communities.map((row: CommunityRow): string => this.ranking(row.id)), this.state.order);
  }

  private save(context: common.Context, next: HomeSourcePreferences): boolean {
    if (this.viewer.length === 0 || this.viewer !== xPrivateClient.viewerId()) { return false; }
    try {
      const store = preferences.getPreferencesSync(context, { name: 'harmonyx_home_sources' });
      store.putSync(this.viewer, JSON.stringify(next)); store.flushSync();
      this.state = next; this.apply(); return true;
    } catch (error) { return false; }
  }

  private nextState(): HomeSourcePreferences {
    const next: HomeSourcePreferences = new HomeSourcePreferences();
    next.communities = this.state.communities.slice(); next.order = this.state.order.slice();
    next.rankings = this.state.rankings.slice(); return next;
  }

  ranking(id: string): string { return this.state.rankings.find((row: HomeCommunityOrder): boolean => row.id === id)?.ranking ?? 'Recency'; }
  communityPinned(id: string): boolean { return this.state.communities.some((row: CommunityRow): boolean => row.id === id); }
  communityRow(id: string): CommunityRow | undefined {
    return [...this.communities, ...this.state.communities].find((row: CommunityRow): boolean => row.id === id);
  }
  listRow(id: string): ListRow | undefined {
    return [...this.lists, ...pinnedHomeListStore.current(this.viewer)].find((row: ListRow): boolean => row.id === id);
  }

  setCommunityPinned(context: common.Context, row: CommunityRow, pinned: boolean): boolean {
    const next: HomeSourcePreferences = this.nextState();
    next.communities = next.communities.filter((value: CommunityRow): boolean => value.id !== row.id);
    if (pinned) { next.communities.push(row); }
    return this.save(context, next);
  }

  setRanking(context: common.Context, id: string, ranking: string): boolean {
    if (!this.validRanking(ranking) || !this.communityPinned(id)) { return false; }
    const next: HomeSourcePreferences = this.nextState();
    next.rankings = next.rankings.filter((row: HomeCommunityOrder): boolean => row.id !== id);
    next.rankings.push({ id: id, ranking: ranking });
    return this.save(context, next);
  }

  setOrder(context: common.Context, ids: string[]): boolean {
    const pinned: TimelineTopic[] = homeTimelineStore.pinnedTopics();
    if (ids.length !== pinned.length || new Set<string>(ids).size !== ids.length ||
      pinned.some((row: TimelineTopic): boolean => ids.indexOf(row.id) < 0)) { return false; }
    const next: HomeSourcePreferences = this.nextState(); next.order = ids.slice();
    return this.save(context, next);
  }

  listSources(): TimelineTopic[] {
    const rows: ListRow[] = this.lists.slice();
    for (const row of pinnedHomeListStore.current(this.viewer)) {
      const index: number = rows.findIndex((value: ListRow): boolean => value.id === row.id);
      if (index >= 0) { rows[index] = row; } else { rows.push(row); }
    }
    return rows.filter((row: ListRow): boolean => !listStateStore.isRemoved(this.viewer, row.id))
      .map((row: ListRow): TimelineTopic => homeTimelineStore.listSource(listStateStore.get(this.viewer, row.id) ?? row));
  }

  communitySources(): TimelineTopic[] {
    const rows: CommunityRow[] = this.communities.slice();
    for (const row of this.state.communities) {
      if (!rows.some((value: CommunityRow): boolean => value.id === row.id)) { rows.push(row); }
    }
    return rows.map((row: CommunityRow): TimelineTopic => homeTimelineStore.communitySource(row, this.ranking(row.id)));
  }

  async setPinned(context: common.Context, source: TimelineTopic, pinned: boolean): Promise<boolean> {
    if (source.communityId.length > 0) {
      const row: CommunityRow | undefined = [...this.communities, ...this.state.communities]
        .find((value: CommunityRow): boolean => value.id === source.communityId);
      return row !== undefined && this.setCommunityPinned(context, row, pinned);
    }
    if (source.listId.length === 0) { return homeTimelineStore.setPinned(context, source.id, pinned); }
    const viewer: string = this.viewer;
    const generation: number = xPrivateClient.sessionGeneration();
    const row: ListRow | undefined = [...this.lists, ...pinnedHomeListStore.current(viewer)]
      .find((value: ListRow): boolean => value.id === source.listId);
    if (row === undefined || viewer !== xPrivateClient.viewerId()) { return false; }
    try {
      const result: XPrivateResult = await xPrivateClient.pinList(source.listId, pinned);
      if (!result.ok || viewer !== this.viewer || generation !== xPrivateClient.sessionGeneration()) { return false; }
      const updated: ListRow = copyList(row); updated.pinned = pinned;
      listStateStore.update(viewer, updated); pinnedHomeListStore.merge(context, viewer, [updated]);
      this.lists = this.lists.map((value: ListRow): ListRow => value.id === row.id ? updated : value);
      return true;
    } catch (error) { return false; }
  }

  async refresh(context: common.Context): Promise<boolean> {
    if (this.pendingLoad !== null) { return this.pendingLoad; }
    const pending: Promise<boolean> = this.loadDirectories(context);
    this.pendingLoad = pending;
    try { return await pending; } finally { if (this.pendingLoad === pending) { this.pendingLoad = null; } }
  }

  private async loadDirectories(context: common.Context): Promise<boolean> {
    const viewer: string = this.viewer;
    const generation: number = xPrivateClient.sessionGeneration();
    if (viewer.length === 0 || viewer !== xPrivateClient.viewerId()) { return false; }
    const results: boolean[] = await Promise.all([
      this.loadLists(context, viewer, generation), this.loadCommunities(viewer, generation)
    ]);
    return results.every((ok: boolean): boolean => ok);
  }

  private async loadLists(context: common.Context, viewer: string, generation: number): Promise<boolean> {
    const rows: ListRow[] = []; let cursor: string = ''; const seen: string[] = []; let complete: boolean = false; let operation: string = '';
    try {
      for (let pageIndex: number = 0; pageIndex < 10; pageIndex++) {
        const result: XPrivateResult = await xPrivateClient.subscribedLists(cursor, 20, operation);
        if (viewer !== this.viewer || generation !== xPrivateClient.sessionGeneration()) { return false; }
        const page: ListPage | null = result.ok ? XListParser.directory(result.body, viewer) : null;
        if (page === null) { return false; }
        operation = result.operation;
        for (const row of page.lists) {
          const current: ListRow = listStateStore.get(viewer, row.id) ?? row;
          if (!rows.some((value: ListRow): boolean => value.id === row.id)) { rows.push(current); }
        }
        this.lists = rows.slice(); pinnedHomeListStore.merge(context, viewer, page.lists.map(
          (row: ListRow): ListRow => listStateStore.get(viewer, row.id) ?? row));
        if (page.nextToken.length === 0) { complete = true; break; }
        if (seen.indexOf(page.nextToken) >= 0) { break; }
        cursor = page.nextToken; seen.push(cursor);
      }
      if (complete) {
        const missing: ListRow[] = pinnedHomeListStore.current(viewer)
          .filter((row: ListRow): boolean => !rows.some((current: ListRow): boolean => current.id === row.id))
          .map((row: ListRow): ListRow => { const removed: ListRow = copyList(row); removed.pinned = false; return removed; });
        pinnedHomeListStore.merge(context, viewer, missing);
      }
      homeTimelineStore.publish(); return true;
    } catch (error) { return false; }
  }

  private async loadCommunities(viewer: string, generation: number): Promise<boolean> {
    const rows: CommunityRow[] = []; let cursor: string = ''; const seen: string[] = [];
    let useJoinedDirectory: boolean = false;
    try {
      for (let pageIndex: number = 0; pageIndex < 10; pageIndex++) {
        let result: XPrivateResult = useJoinedDirectory ? await xPrivateClient.joinedCommunities(viewer, cursor, 30) :
          await xPrivateClient.myCommunities(cursor, 30);
        if (viewer !== this.viewer || generation !== xPrivateClient.sessionGeneration()) { return false; }
        let page: CommunityPage | null = result.ok ? XCommunityParser.parse(result.body) : null;
        // Use the same native directory as Communities; some accounts cannot use
        // GetJoinedCommunities. A fallback starts at page one with its own cursor.
        if (page === null && pageIndex === 0) {
          useJoinedDirectory = true;
          result = await xPrivateClient.joinedCommunities(viewer, '', 30);
          if (viewer !== this.viewer || generation !== xPrivateClient.sessionGeneration()) { return false; }
          page = result.ok ? XCommunityParser.parse(result.body) : null;
        }
        if (page === null) { return false; }
        for (const row of page.communities) {
          row.joined = true;
          if (!rows.some((value: CommunityRow): boolean => value.id === row.id)) { rows.push(row); }
        }
        this.communities = rows.slice();
        if (page.nextToken.length === 0 || seen.indexOf(page.nextToken) >= 0) { break; }
        cursor = page.nextToken; seen.push(cursor);
      }
      this.state.communities = this.state.communities.map((row: CommunityRow): CommunityRow =>
        rows.find((value: CommunityRow): boolean => value.id === row.id) ?? row);
      this.apply(); return true;
    } catch (error) { return false; }
  }
}

export const homeTimelineSourceStore: HomeTimelineSourceStore = new HomeTimelineSourceStore();
