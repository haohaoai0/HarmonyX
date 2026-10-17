import { SpaceRoom, SpacePresencePage } from '../models/Space';
import hilog from '@ohos.hilog';
import { xPrivateClient, XPrivateClient, XPrivateResult } from './XPrivateClient';
import { XSpaceParser } from './XSpaceParser';

export class SpaceDirectory {
  rooms: SpaceRoom[] = [];
  unavailableCount: number = 0;
  // True when the list came from the viewer's own graph (the Spaces tab
  // fleetline, or Space links shared by accounts they follow) instead of the
  // global fallback. The directory labels its sections from this flag.
  personalized: boolean = false;
}

// Shared Space links are the one discovery source that always answers: the
// followed variant is personalised, the bare one is the global fallback.
const FOLLOWED_SPACE_QUERY: string = '(url:twitter.com/i/spaces OR url:x.com/i/spaces) filter:follows';
const GLOBAL_SPACE_QUERY: string = '(url:twitter.com/i/spaces OR url:x.com/i/spaces)';

class XSpaceService {
  // Keep server candidates ahead of followed shares, without filtering for
  // followed hosts: a recommendation can be related through any participant.
  async recommendations(): Promise<SpaceRoom[]> {
    const sources: XPrivateResult[] = await Promise.all([
      xPrivateClient.spaceFleetline(), xPrivateClient.searchTimeline(FOLLOWED_SPACE_QUERY, '', 40, 'Latest')
    ]);
    const fleetline: XPrivateResult = sources[0];
    const shared: XPrivateResult = sources[1];
    if (!fleetline.ok && !shared.ok) { throw new Error(XPrivateClient.explain(fleetline)); }
    const ids: string[] = fleetline.ok ? XSpaceParser.fleetlineIds(fleetline.body) : [];
    const related: string[] = shared.ok ? XSpaceParser.sharedIds(shared.body) : [];
    for (let i: number = 0; i < related.length; i++) {
      if (ids.indexOf(related[i]) < 0) { ids.push(related[i]); }
    }
    // Expired share links often no longer resolve; these are not live candidates.
    return (await this.hydrate(ids, true, 12)).rooms;
  }
  async presence(userIds: string[]): Promise<SpacePresencePage> {
    const result: XPrivateResult = await xPrivateClient.spacePresence(userIds);
    if (!result.ok) { throw new Error(XPrivateClient.explain(result)); }
    const page: SpacePresencePage | null = XSpaceParser.presence(result.body, userIds);
    if (page === null) { throw new Error('space_presence_invalid_response'); }
    return page;
  }
  // A search is query-driven, so it only runs when the reader typed something.
  // The default list follows the viewer's graph first and falls back to the
  // global list so the page still has content when nobody they follow is live.
  async directory(query: string, liveOnly: boolean): Promise<SpaceDirectory> {
    const searching: boolean = query.trim().length > 0;
    if (searching) {
      const search: XPrivateResult = await xPrivateClient.spaceSearch(query.trim(), liveOnly);
      const ids: string[] | null = search.ok ? XSpaceParser.searchIds(search.body) : null;
      const found: SpaceDirectory = await this.hydrate(ids, liveOnly);
      if (found.rooms.length > 0) { return found; }
      const shared: XPrivateResult = await xPrivateClient.searchTimeline(
        GLOBAL_SPACE_QUERY + ' ' + query.trim(), '', 40, 'Latest');
      if (!shared.ok) { throw new Error(XPrivateClient.explain(shared)); }
      return this.settled(await this.hydrate(XSpaceParser.sharedIds(shared.body), liveOnly));
    }
    const followed: string[] | null = await this.followedIds();
    if (followed !== null) {
      // A short probe: Space links stay in posts after the room ends, so the
      // followed list is often stale and should not spend the full request
      // budget before the global fallback gets its turn.
      const personalized: SpaceDirectory = await this.hydrate(followed, liveOnly, 12);
      if (personalized.rooms.length > 0) {
        personalized.personalized = true;
        return personalized;
      }
    }
    const global: XPrivateResult = await xPrivateClient.searchTimeline(GLOBAL_SPACE_QUERY, '', 40, 'Latest');
    if (!global.ok) { throw new Error(XPrivateClient.explain(global)); }
    return this.settled(await this.hydrate(XSpaceParser.sharedIds(global.body), liveOnly));
  }

  // A source that answered but resolved no room at all is reported as a
  // failure so the page offers a retry instead of an empty state. Sources that
  // are merely empty are not: they are the normal "nothing live right now" case.
  private settled(page: SpaceDirectory): SpaceDirectory {
    if (page.rooms.length === 0 && page.unavailableCount > 0) { throw new Error('space_details_unavailable'); }
    return page;
  }

  // The Spaces tab reads the fleetline first because that list is built from the
  // accounts the viewer follows. Space links shared by those same accounts are
  // the second personalised source, and only a failure of both returns null so
  // the caller can fall back to the global list.
  private async followedIds(): Promise<string[] | null> {
    const fleetline: XPrivateResult = await xPrivateClient.spaceFleetline();
    if (!fleetline.ok) {
      hilog.warn(0xFF00, 'HarmonyX-Spaces', 'fleetline lookup status: %{public}d', fleetline.status);
    } else {
      const live: string[] = XSpaceParser.fleetlineIds(fleetline.body);
      if (live.length > 0) { return live; }
    }
    const shared: XPrivateResult = await xPrivateClient.searchTimeline(FOLLOWED_SPACE_QUERY, '', 40, 'Latest');
    if (!shared.ok) {
      hilog.warn(0xFF00, 'HarmonyX-Spaces', 'followed space search status: %{public}d', shared.status);
      return null;
    }
    const ids: string[] = XSpaceParser.sharedIds(shared.body);
    return ids.length > 0 ? ids : null;
  }

  // Each id needs its own metadata lookup, so the fan-out is bounded in groups
  // of four. Ids that fail to resolve are counted, not surfaced.
  private async hydrate(ids: string[] | null, liveOnly: boolean, limit: number = 24): Promise<SpaceDirectory> {
    const page: SpaceDirectory = new SpaceDirectory();
    if (ids === null) { return page; }
    const limited: string[] = ids.slice(0, limit);
    for (let start: number = 0; start < limited.length; start += 4) {
      const pending: Promise<SpaceRoom | null>[] = [];
      for (let i: number = start; i < Math.min(start + 4, limited.length); i++) {
        pending.push(this.detail(limited[i]));
      }
      const rooms: Array<SpaceRoom | null> = await Promise.all(pending);
      for (let i: number = 0; i < rooms.length; i++) {
        const room: SpaceRoom | null = rooms[i];
        if (room === null) { page.unavailableCount++; continue; }
        if (liveOnly ? room.isLive() : room.isLive() || room.isScheduled() || room.replayAvailable) {
          page.rooms.push(room);
        }
      }
    }
    return page;
  }
  async detail(id: string): Promise<SpaceRoom | null> {
    const result: XPrivateResult = await xPrivateClient.spaceDetail(id);
    return result.ok ? XSpaceParser.detail(result.body) : null;
  }
  async stream(room: SpaceRoom): Promise<string> {
    if (!room.canListen()) { return ''; }
    const result: XPrivateResult = await xPrivateClient.spaceStream(room.mediaKey);
    if (!result.ok) { hilog.warn(0xFF00, 'HarmonyX-Spaces', 'stream lookup status: %{public}d', result.status); }
    return result.ok ? XSpaceParser.streamUrl(result.body) : '';
  }
}

export const xSpaceService: XSpaceService = new XSpaceService();
