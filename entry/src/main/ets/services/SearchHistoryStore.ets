// Recent submitted queries and profiles opened from search, most recent first.
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import type { UserRow } from '../models/Tweet';

export class SearchHistoryStore {
  private static readonly STORE_NAME: string = 'harmonyx_search';
  private static readonly RECENT_KEY: string = 'recent';
  private static readonly MAX_ENTRIES: number = 10;
  private static readonly USERS_KEY: string = 'recent_users';
  private static readonly MAX_USERS: number = 20;

  load(context: common.Context): string[] {
    try {
      const options: preferences.Options = { name: SearchHistoryStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      const raw: string = store.getSync(SearchHistoryStore.RECENT_KEY, '[]') as string;
      const parsed: string[] = JSON.parse(raw) as string[];
      const out: string[] = [];
      for (let i: number = 0; i < parsed.length; i++) {
        const value: string = String(parsed[i]).trim();
        if (value.length > 0 && out.indexOf(value) < 0 && out.length < SearchHistoryStore.MAX_ENTRIES) {
          out.push(value);
        }
      }
      return out;
    } catch (error) {
      return [];
    }
  }

  add(context: common.Context, query: string): string[] {
    const trimmed: string = query.trim();
    const current: string[] = this.load(context);
    if (trimmed.length === 0) {
      return current;
    }
    const next: string[] = [trimmed];
    for (let i: number = 0; i < current.length; i++) {
      if (current[i] !== trimmed && next.length < SearchHistoryStore.MAX_ENTRIES) {
        next.push(current[i]);
      }
    }
    this.save(context, next);
    return next;
  }

  clear(context: common.Context): void {
    this.save(context, []);
    this.saveUsers(context, []);
  }

  remove(context: common.Context, query: string): string[] {
    const next: string[] = this.load(context).filter((value: string): boolean => value !== query.trim());
    this.save(context, next);
    return next;
  }

  removeUser(context: common.Context, id: string): UserRow[] {
    const next: UserRow[] = this.loadUsers(context).filter((row: UserRow): boolean => row.id !== id);
    this.saveUsers(context, next);
    return next;
  }

  loadUsers(context: common.Context): UserRow[] {
    try {
      const options: preferences.Options = { name: SearchHistoryStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      const parsed: UserRow[] = JSON.parse(store.getSync(SearchHistoryStore.USERS_KEY, '[]') as string) as UserRow[];
      if (!Array.isArray(parsed)) { return []; }
      const users: UserRow[] = [];
      for (let i: number = 0; i < parsed.length && users.length < SearchHistoryStore.MAX_USERS; i++) {
        const row: UserRow | null = parsed[i];
        if (row !== null && typeof row.id === 'string' && row.id.length > 0 &&
          typeof row.username === 'string' && row.username.length > 0 && typeof row.name === 'string' &&
          typeof row.avatarUrl === 'string' && typeof row.avatarColor === 'string' &&
          !users.some((user: UserRow): boolean => user.id === row.id)) {
          users.push(row);
        }
      }
      return users;
    } catch (error) { return []; }
  }

  addUser(context: common.Context, row: UserRow): UserRow[] {
    const users: UserRow[] = this.loadUsers(context);
    if (row.id.length === 0 || row.username.length === 0) { return users; }
    // Store only identity needed to reopen the profile, without stale follow/bio data.
    const recent: UserRow = {
      id: row.id, name: row.name, username: row.username, avatarUrl: row.avatarUrl,
      avatarColor: row.avatarColor, verified: row.verified, verifiedType: row.verifiedType,
      avatarShape: row.avatarShape, bio: '', following: false, followedBy: false
    };
    const next: UserRow[] = [recent];
    for (let i: number = 0; i < users.length && next.length < SearchHistoryStore.MAX_USERS; i++) {
      if (users[i].id !== row.id) { next.push(users[i]); }
    }
    this.saveUsers(context, next);
    return next;
  }

  private saveUsers(context: common.Context, users: UserRow[]): void {
    try {
      const options: preferences.Options = { name: SearchHistoryStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      store.putSync(SearchHistoryStore.USERS_KEY, JSON.stringify(users));
      store.flushSync();
    } catch (error) { }
  }

  private save(context: common.Context, entries: string[]): void {
    try {
      const options: preferences.Options = { name: SearchHistoryStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      store.putSync(SearchHistoryStore.RECENT_KEY, JSON.stringify(entries));
      store.flushSync();
    } catch (error) {
      // History is a convenience; a write failure must not break the search.
    }
  }
}

export const searchHistoryStore: SearchHistoryStore = new SearchHistoryStore();
