import type { ListRow } from '../models/Tweet';

export const STORAGE_KEY_LIST_REVISION: string = 'harmonyx.list_revision';

// Successful writes are shared immediately between destinations. X remains
// the source of truth; account-qualified keys prevent cross-account state.
class ListStateStore {
  private rows: Map<string, ListRow> = new Map<string, ListRow>();
  private removed: string[] = [];

  update(viewerId: string, row: ListRow): void {
    const key: string = viewerId + ':' + row.id;
    this.rows.set(key, row);
    this.removed = this.removed.filter((value: string): boolean => value !== key);
    this.touch();
  }

  get(viewerId: string, id: string): ListRow | undefined { return this.rows.get(viewerId + ':' + id); }

  remove(viewerId: string, id: string): void {
    const key: string = viewerId + ':' + id;
    this.rows.delete(key);
    if (this.removed.indexOf(key) < 0) { this.removed.push(key); }
    this.touch();
  }

  isRemoved(viewerId: string, id: string): boolean { return this.removed.indexOf(viewerId + ':' + id) >= 0; }

  values(viewerId: string): ListRow[] {
    const rows: ListRow[] = [];
    this.rows.forEach((row: ListRow, key: string): void => {
      if (key.startsWith(viewerId + ':')) { rows.push(row); }
    });
    return rows;
  }

  touch(): void {
    AppStorage.setOrCreate(STORAGE_KEY_LIST_REVISION,
      (AppStorage.get<number>(STORAGE_KEY_LIST_REVISION) ?? 0) + 1);
  }
}

export const listStateStore: ListStateStore = new ListStateStore();

export function copyList(row: ListRow): ListRow {
  return {
    id: row.id, name: row.name, description: row.description, memberCount: row.memberCount,
    following: row.following, ownerName: row.ownerName, ownerUsername: row.ownerUsername,
    ownerId: row.ownerId, ownerAvatarUrl: row.ownerAvatarUrl, bannerUrl: row.bannerUrl,
    hasCustomBanner: row.hasCustomBanner,
    customBannerMediaId: row.customBannerMediaId,
    isPrivate: row.isPrivate, pinned: row.pinned, subscriberCount: row.subscriberCount
  };
}
