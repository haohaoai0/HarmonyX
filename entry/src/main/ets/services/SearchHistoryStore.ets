// Recent search terms, most recent first. Only the query strings are kept.
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

export class SearchHistoryStore {
  private static readonly STORE_NAME: string = 'harmonyx_search';
  private static readonly RECENT_KEY: string = 'recent';
  private static readonly MAX_ENTRIES: number = 10;

  load(context: common.Context): string[] {
    try {
      const options: preferences.Options = { name: SearchHistoryStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      const raw: string = store.getSync(SearchHistoryStore.RECENT_KEY, '[]') as string;
      const parsed: string[] = JSON.parse(raw) as string[];
      const out: string[] = [];
      for (let i: number = 0; i < parsed.length; i++) {
        const value: string = String(parsed[i]).trim();
        if (value.length > 0 && out.length < SearchHistoryStore.MAX_ENTRIES) {
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
