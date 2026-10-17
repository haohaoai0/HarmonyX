import { SpaceParticipant, SpaceRoom, SpacePresence, SpacePresencePage } from '../models/Space';
import { xPrivateClient } from './XPrivateClient';
import { xSpaceService } from './XSpaceService';
import { XSpaceParser } from './XSpaceParser';

export const SPACE_SURFACE_REVISION: string = 'harmonyx.space_surface_revision';
export const SPACE_PREVIEW_REQUEST: string = 'harmonyx.space_preview_request';

class RoomSnapshot {
  room: SpaceRoom;
  expiresAt: number;
  constructor(room: SpaceRoom, expiresAt: number) { this.room = room; this.expiresAt = expiresAt; }
}

class PresenceSnapshot {
  spaceId: string;
  expiresAt: number;
  constructor(spaceId: string, expiresAt: number) { this.spaceId = spaceId; this.expiresAt = expiresAt; }
}

// Shared across home, posts, quotes and detail. Presence is independently
// queried for visible authors, including rooms outside the home recommendation.
class SpaceSurfaceStore {
  recommendations: SpaceRoom[] = [];
  private snapshots: Map<string, RoomSnapshot> = new Map();
  private pending: Map<string, Promise<SpaceRoom | null>> = new Map();
  private generation: number = 0;
  private revision: number = 0;
  private recommendedAt: number = 0;
  private refreshing: boolean = false;
  private presences: Map<string, PresenceSnapshot> = new Map();
  private presenceQueue: Map<string, boolean> = new Map();
  private followedUsers: Set<string> = new Set();
  private relatedRooms: Map<string, number> = new Map();
  private presenceTimer: number = -1;
  private expiryTimer: number = -1;
  private presenceLoading: boolean = false;

  constructor() { xPrivateClient.onSessionChange((): void => this.clear()); }

  clear(): void {
    this.generation++;
    this.snapshots.clear(); this.pending.clear(); this.recommendations = [];
    this.presences.clear(); this.presenceQueue.clear(); this.followedUsers.clear(); this.relatedRooms.clear();
    if (this.presenceTimer >= 0) { clearTimeout(this.presenceTimer); this.presenceTimer = -1; }
    if (this.expiryTimer >= 0) { clearTimeout(this.expiryTimer); this.expiryTimer = -1; }
    this.presenceLoading = false;
    this.recommendedAt = 0; this.refreshing = false; this.publish();
  }

  async refresh(): Promise<void> {
    if (!xPrivateClient.isSignedIn() || this.refreshing || Date.now() - this.recommendedAt < 30000) { return; }
    this.refreshing = true;
    const generation: number = this.generation;
    try {
      const rooms: SpaceRoom[] = await xSpaceService.recommendations();
      if (generation !== this.generation) { return; }
      this.recommendations = rooms;
      this.recommendedAt = Date.now();
      for (let i: number = 0; i < rooms.length; i++) { this.remember(rooms[i]); }
      this.publish();
    } finally {
      if (generation === this.generation) { this.refreshing = false; this.publish(); }
    }
  }

  liveRecommendations(): SpaceRoom[] {
    const rooms: SpaceRoom[] = Date.now() - this.recommendedAt < 90000 ? this.recommendations.filter(
      (room: SpaceRoom): boolean => this.cached(room.id)?.isLive() === true) : [];
    this.relatedRooms.forEach((expiry: number, id: string): void => {
      const room: SpaceRoom | null = this.cached(id);
      if (expiry > Date.now() && room?.isLive() && !rooms.some((value: SpaceRoom): boolean => value.id === id)) {
        rooms.push(room);
      }
    });
    return rooms;
  }

  followedParticipants(room: SpaceRoom): SpaceParticipant[] {
    return room.participants.filter((person: SpaceParticipant): boolean => this.followedUsers.has(person.id));
  }

  // Explicit Space IDs injected by the server into the real home timeline.
  // Ordinary shared links are handled separately and never become a ranked signal.
  ingestTimeline(body: string): void { this.resolveRelated(XSpaceParser.fleetlineIds(body).slice(0, 8), 90000); }

  requestPresence(userId: string, followed: boolean = false): void {
    if (!xPrivateClient.isSignedIn() || !/^[0-9]{1,24}$/.test(userId)) { return; }
    if (followed) { this.followedUsers.add(userId); }
    if (this.followedUsers.size > 300) { this.followedUsers.delete(Array.from(this.followedUsers.values())[0]); }
    const current: PresenceSnapshot | undefined = this.presences.get(userId);
    if (current !== undefined && current.expiresAt > Date.now()) {
      if (followed && current.spaceId.length > 0) { this.resolveRelated([current.spaceId], current.expiresAt - Date.now()); }
      return;
    }
    this.presenceQueue.set(userId, followed || this.presenceQueue.get(userId) === true);
    if (this.presenceTimer < 0 && !this.presenceLoading) {
      this.presenceTimer = setTimeout((): void => { this.presenceTimer = -1; this.flushPresence(); }, 250);
    }
  }

  private async flushPresence(): Promise<void> {
    if (this.presenceLoading || !xPrivateClient.isSignedIn()) { return; }
    const ids: string[] = Array.from(this.presenceQueue.keys()).slice(0, 100);
    if (ids.length === 0) { return; }
    ids.forEach((id: string): void => { this.presenceQueue.delete(id); });
    const generation: number = this.generation;
    this.presenceLoading = true;
    try {
      const page: SpacePresencePage = await xSpaceService.presence(ids);
      if (generation !== this.generation) { return; }
      const expiry: number = Date.now() + page.refreshAfterMs;
      const related: string[] = [];
      for (let i: number = 0; i < page.users.length; i++) {
        const userId: string = page.users[i].userId;
        const id: string = page.users[i].spaceId;
        this.presences.set(userId, new PresenceSnapshot(id, expiry));
        if (id.length > 0 && this.followedUsers.has(userId) && related.indexOf(id) < 0) { related.push(id); }
      }
      while (this.presences.size > 300) { this.presences.delete(Array.from(this.presences.keys())[0]); }
      this.resolveRelated(related.slice(0, 8), page.refreshAfterMs);
      this.publish(); this.scheduleExpiry();
    } catch (error) {
      // Do not turn an upstream failure into an authoritative "offline" answer.
      this.publish();
    } finally {
      if (generation === this.generation) {
        this.presenceLoading = false;
        if (this.presenceQueue.size > 0) {
          this.presenceTimer = setTimeout((): void => { this.presenceTimer = -1; this.flushPresence(); }, 250);
        }
      }
    }
  }

  private async resolveRelated(ids: string[], lifetime: number): Promise<void> {
    const generation: number = this.generation;
    const expiry: number = Date.now() + lifetime;
    for (let start: number = 0; start < ids.length; start += 4) {
      const requests: Promise<SpaceRoom | null>[] = ids.slice(start, start + 4).map(
        (id: string): Promise<SpaceRoom | null> => this.detail(id).catch((): null => null));
      const rooms: Array<SpaceRoom | null> = await Promise.all(requests);
      if (generation !== this.generation) { return; }
      for (let i: number = 0; i < rooms.length; i++) {
        const room: SpaceRoom | null = rooms[i];
        if (room?.isLive()) { this.relatedRooms.set(room.id, expiry); }
      }
    }
    this.relatedRooms.forEach((expiresAt: number, id: string): void => {
      if (expiresAt <= Date.now()) { this.relatedRooms.delete(id); }
    });
    while (this.relatedRooms.size > 80) { this.relatedRooms.delete(Array.from(this.relatedRooms.keys())[0]); }
    this.publish();
  }

  cached(id: string): SpaceRoom | null {
    const value: RoomSnapshot | undefined = this.snapshots.get(id);
    return value !== undefined && value.expiresAt > Date.now() ? value.room : null;
  }

  async detail(id: string): Promise<SpaceRoom | null> {
    if (!/^[A-Za-z0-9]{5,64}$/.test(id)) { return null; }
    const cached: SpaceRoom | null = this.cached(id);
    if (cached !== null) { return cached; }
    const pending: Promise<SpaceRoom | null> | undefined = this.pending.get(id);
    if (pending !== undefined) { return pending; }
    const generation: number = this.generation;
    const request: Promise<SpaceRoom | null> = this.resolve(id, generation);
    this.pending.set(id, request);
    return request;
  }

  presence(userId: string): SpacePresence | null {
    if (userId.length === 0) { return null; }
    const direct: PresenceSnapshot | undefined = this.presences.get(userId);
    if (direct !== undefined && direct.expiresAt <= Date.now()) { return null; }
    if (direct !== undefined && direct.expiresAt > Date.now()) {
      if (direct.spaceId.length === 0) { return null; }
      const room: SpaceRoom | null = this.cached(direct.spaceId);
      if (room !== null && !room.isLive()) { return null; }
      const presence: SpacePresence = new SpacePresence();
      presence.spaceId = direct.spaceId;
      presence.role = room?.participants.find((person: SpaceParticipant): boolean => person.id === userId)?.role ?? '';
      return presence;
    }
    const values: RoomSnapshot[] = Array.from(this.snapshots.values());
    for (let i: number = 0; i < values.length; i++) {
      const room: SpaceRoom = values[i].room;
      if (values[i].expiresAt <= Date.now() || !room.isLive()) { continue; }
      const person: SpaceParticipant | undefined = room.participants.find(
        (person: SpaceParticipant): boolean => person.id === userId);
      if (person !== undefined) {
        const presence: SpacePresence = new SpacePresence();
        presence.spaceId = room.id; presence.role = person.role;
        return presence;
      }
    }
    return null;
  }

  private async resolve(id: string, generation: number): Promise<SpaceRoom | null> {
    try {
      const room: SpaceRoom | null = await xSpaceService.detail(id);
      if (generation !== this.generation) { return null; }
      if (room !== null) { this.remember(room); } else { this.snapshots.delete(id); }
      this.publish();
      return room;
    } finally {
      if (generation === this.generation) { this.pending.delete(id); }
    }
  }

  private remember(room: SpaceRoom): void {
    this.snapshots.set(room.id, new RoomSnapshot(room, Date.now() + (room.isLive() ? 65000 : 300000)));
    if (this.snapshots.size > 80) {
      const oldest: string = Array.from(this.snapshots.keys())[0];
      this.snapshots.delete(oldest);
    }
    this.scheduleExpiry();
  }
  private scheduleExpiry(): void {
    if (this.expiryTimer >= 0) { clearTimeout(this.expiryTimer); this.expiryTimer = -1; }
    let next: number = Date.now() + 300000;
    this.presences.forEach((value: PresenceSnapshot): void => {
      if (value.expiresAt > Date.now()) { next = Math.min(next, value.expiresAt); }
    });
    this.snapshots.forEach((value: RoomSnapshot): void => {
      if (value.room.isLive() && value.expiresAt > Date.now()) { next = Math.min(next, value.expiresAt); }
    });
    if (next < Date.now() + 300000) {
      this.expiryTimer = setTimeout((): void => { this.expiryTimer = -1; this.publish(); this.scheduleExpiry(); },
        Math.max(1, next - Date.now() + 1));
    }
  }
  private publish(): void { AppStorage.setOrCreate<number>(SPACE_SURFACE_REVISION, ++this.revision); }
}

export function requestSpacePreview(id: string): void {
  if (/^[A-Za-z0-9]{5,64}$/.test(id)) { AppStorage.setOrCreate<string>(SPACE_PREVIEW_REQUEST, id); }
}

export const spaceSurfaceStore: SpaceSurfaceStore = new SpaceSurfaceStore();
