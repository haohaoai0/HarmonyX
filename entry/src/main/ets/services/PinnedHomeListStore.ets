import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import type { ListRow } from '../models/Tweet';
import { homeTimelineStore } from './HomeTimelineStore';

class PinnedHomeListStore {
  private viewer: string = '';
  private rows: ListRow[] = [];
  load(context: common.Context, viewer: string): void {
    this.viewer = viewer;
    this.rows = [];
    if (viewer.length > 0) {
      try {
        const store = preferences.getPreferencesSync(context, { name: 'harmonyx_home_lists' });
        const rows: ListRow[] = JSON.parse(store.getSync(viewer, '[]') as string) as ListRow[];
        this.rows = rows.filter((row: ListRow): boolean => row !== null &&
          typeof row.id === 'string' && row.id.length > 0 && typeof row.name === 'string' && row.pinned === true);
      } catch (error) { this.rows = []; }
    }
    homeTimelineStore.setListTopics(this.rows);
  }
  current(viewer: string): ListRow[] { return viewer === this.viewer ? this.rows.slice() : []; }
  merge(context: common.Context, viewer: string, updates: ListRow[]): void {
    if (viewer.length === 0 || viewer !== this.viewer) { return; }
    const rows: ListRow[] = this.rows.map((row: ListRow): ListRow =>
      updates.find((update: ListRow): boolean => update.id === row.id) ?? row)
      .filter((row: ListRow): boolean => row.pinned === true);
    for (const row of updates) {
      if (row.pinned && !rows.some((existing: ListRow): boolean => existing.id === row.id)) { rows.push(row); }
    }
    this.rows = rows;
    try {
      const store = preferences.getPreferencesSync(context, { name: 'harmonyx_home_lists' });
      store.putSync(viewer, JSON.stringify(rows)); store.flushSync();
    } catch (error) { }
    homeTimelineStore.setListTopics(rows);
  }
}
export const pinnedHomeListStore: PinnedHomeListStore = new PinnedHomeListStore();
