import type { UserRow } from '../models/Tweet';
import { FollowDiscoveryData } from './FollowDiscoveryData';

export const STORAGE_KEY_FOLLOW_REVISION: string = 'harmonyx.follow_revision';

class FollowStateStore {
  private states: Map<string, boolean> = new Map<string, boolean>();

  set(viewerId: string, userId: string, following: boolean): void {
    if (viewerId.length === 0 || userId.length === 0) { return; }
    this.states.set(viewerId + ':' + userId, following);
    AppStorage.setOrCreate(STORAGE_KEY_FOLLOW_REVISION,
      (AppStorage.get<number>(STORAGE_KEY_FOLLOW_REVISION) ?? 0) + 1);
  }

  get(viewerId: string, userId: string): boolean | undefined { return this.states.get(viewerId + ':' + userId); }

  apply(viewerId: string, rows: UserRow[]): UserRow[] {
    return rows.map((row: UserRow): UserRow => {
      const following: boolean | undefined = this.states.get(viewerId + ':' + row.id);
      return following === undefined ? row : FollowDiscoveryData.copyFollowing(row, following);
    });
  }
}

export const followStateStore: FollowStateStore = new FollowStateStore();
