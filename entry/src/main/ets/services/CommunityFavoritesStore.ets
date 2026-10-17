// Local-only saved communities. This is a personal launcher, not an X
// membership action, so it is kept in app preferences and never sent to X.
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import type { CommunityRow, CommunityRule } from '../models/Community';

export class CommunityFavoritesStore {
  private static readonly STORE_NAME: string = 'harmonyx_community_favorites';
  private static readonly ROWS_KEY: string = 'rows';
  private static readonly MAX_ENTRIES: number = 100;

  load(context: common.Context): CommunityRow[] {
    try {
      const options: preferences.Options = { name: CommunityFavoritesStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      const raw: string = store.getSync(CommunityFavoritesStore.ROWS_KEY, '[]') as string;
      const values: Array<Object> = JSON.parse(raw) as Array<Object>;
      const rows: CommunityRow[] = [];
      for (let i: number = 0; i < values.length; i++) {
        const row: CommunityRow | null = CommunityFavoritesStore.rowOf(values[i]);
        if (row !== null && CommunityFavoritesStore.hasId(rows, row.id) === false &&
          rows.length < CommunityFavoritesStore.MAX_ENTRIES) {
          rows.push(row);
        }
      }
      return rows;
    } catch (error) {
      return [];
    }
  }

  contains(context: common.Context, communityId: string): boolean {
    return CommunityFavoritesStore.hasId(this.load(context), communityId);
  }

  update(context: common.Context, row: CommunityRow): void {
    const current: CommunityRow[] = this.load(context);
    const next: CommunityRow[] = [];
    let found: boolean = false;
    for (let i: number = 0; i < current.length; i++) {
      if (current[i].id === row.id) {
        next.push(row);
        found = true;
      } else {
        next.push(current[i]);
      }
    }
    if (found) {
      this.save(context, next);
    }
  }

  toggle(context: common.Context, row: CommunityRow): boolean {
    const current: CommunityRow[] = this.load(context);
    const next: CommunityRow[] = [];
    let exists: boolean = false;
    for (let i: number = 0; i < current.length; i++) {
      if (current[i].id === row.id) {
        exists = true;
      } else {
        next.push(current[i]);
      }
    }
    if (!exists) {
      next.unshift(row);
    }
    this.save(context, next);
    return !exists;
  }

  private save(context: common.Context, rows: CommunityRow[]): void {
    try {
      const options: preferences.Options = { name: CommunityFavoritesStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      store.putSync(CommunityFavoritesStore.ROWS_KEY, JSON.stringify(rows));
      store.flushSync();
    } catch (error) {
      // Favorites are a convenience and should never block community browsing.
    }
  }

  private static hasId(rows: CommunityRow[], id: string): boolean {
    for (let i: number = 0; i < rows.length; i++) {
      if (rows[i].id === id) {
        return true;
      }
    }
    return false;
  }

  private static rowOf(value: Object): CommunityRow | null {
    if (value === null || value === undefined || typeof value !== 'object' || value instanceof Array) {
      return null;
    }
    const record: Record<string, Object> = value as Record<string, Object>;
    const id: string = CommunityFavoritesStore.stringOf(record['id']);
    const name: string = CommunityFavoritesStore.stringOf(record['name']);
    if (id.length === 0 || name.length === 0) {
      return null;
    }
    return {
      id: id,
      name: name,
      description: CommunityFavoritesStore.stringOf(record['description']),
      memberCount: CommunityFavoritesStore.numberOf(record['memberCount']),
      moderatorCount: CommunityFavoritesStore.numberOf(record['moderatorCount']),
      bannerUrl: CommunityFavoritesStore.stringOf(record['bannerUrl']),
      joinPolicy: CommunityFavoritesStore.stringOf(record['joinPolicy']),
      ruleCount: CommunityFavoritesStore.numberOf(record['ruleCount']),
      rules: CommunityFavoritesStore.rulesOf(record['rules']),
      joined: Boolean(record['joined'] ?? false)
    };
  }

  private static rulesOf(value: Object | undefined): CommunityRule[] {
    if (!(value instanceof Array)) {
      return [];
    }
    const values: Array<Object> = value as Array<Object>;
    const rules: CommunityRule[] = [];
    for (let i: number = 0; i < values.length; i++) {
      const value: Object = values[i];
      if (value === null || value === undefined || typeof value !== 'object' || value instanceof Array) {
        continue;
      }
      const record: Record<string, Object> = value as Record<string, Object>;
      const name: string = CommunityFavoritesStore.stringOf(record['name']);
      if (name.length === 0) {
        continue;
      }
      rules.push({
        id: CommunityFavoritesStore.stringOf(record['id']),
        name: name,
        description: CommunityFavoritesStore.stringOf(record['description'])
      });
    }
    return rules;
  }

  private static stringOf(value: Object | undefined): string {
    return value === undefined || value === null ? '' : String(value);
  }

  private static numberOf(value: Object | undefined): number {
    if (value === undefined || value === null) {
      return 0;
    }
    const parsed: number = Number(value);
    return isNaN(parsed) ? 0 : parsed;
  }
}

export const communityFavoritesStore: CommunityFavoritesStore = new CommunityFavoritesStore();
