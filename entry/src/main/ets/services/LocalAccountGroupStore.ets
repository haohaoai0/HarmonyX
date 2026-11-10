import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import type { UserRow } from '../models/Tweet';
import { homeTimelineStore, TimelineTopic } from './HomeTimelineStore';
import { xPrivateClient } from './XPrivateClient';

export const DEFAULT_ACCOUNT_GROUP_ICON: string = '📁';

export class LocalAccountGroup {
  id: string = '';
  name: string = '';
  icon: string = DEFAULT_ACCOUNT_GROUP_ICON;
  members: UserRow[] = [];
  pinned: boolean = false;
  version: number = 0;
}

export class LocalAccountGroupStore {
  private viewer: string = '';
  private groups: LocalAccountGroup[] = [];

  load(context: common.Context, viewer: string): void {
    this.viewer = viewer;
    this.groups = [];
    if (viewer.length > 0) {
      try {
        const disk: preferences.Preferences = preferences.getPreferencesSync(context, { name: 'harmonyx_local_account_groups' });
        const rows: LocalAccountGroup[] = JSON.parse(disk.getSync(viewer, '[]') as string) as LocalAccountGroup[];
        const seen: Set<string> = new Set<string>();
        if (Array.isArray(rows)) {
          for (const row of rows) {
            if (row === null || typeof row.id !== 'string' || row.id.length === 0 || seen.has(row.id) ||
              typeof row.name !== 'string' || row.name.trim().length === 0 || !Array.isArray(row.members)) { continue; }
            seen.add(row.id);
            const group: LocalAccountGroup = new LocalAccountGroup();
            group.id = row.id; group.name = row.name.trim().slice(0, 40);
            group.icon = typeof row.icon === 'string' && row.icon.trim().length > 0 ? row.icon.trim().slice(0, 16) : DEFAULT_ACCOUNT_GROUP_ICON;
            group.members = this.uniqueMembers(row.members); group.pinned = row.pinned === true;
            group.version = Number.isFinite(row.version) ? row.version : 0;
            this.groups.push(group);
          }
        }
      } catch (error) { this.groups = []; }
    }
    this.publish();
  }

  private uniqueMembers(rows: UserRow[]): UserRow[] {
    const seen: Set<string> = new Set<string>();
    return rows.filter((row: UserRow): boolean => {
      if (row === null || typeof row.id !== 'string' || row.id.length === 0 || seen.has(row.id) ||
        typeof row.name !== 'string' || typeof row.username !== 'string') { return false; }
      seen.add(row.id); return true;
    });
  }

  private copy(group: LocalAccountGroup): LocalAccountGroup {
    const result: LocalAccountGroup = new LocalAccountGroup();
    result.id = group.id; result.name = group.name; result.icon = group.icon;
    result.members = group.members.slice(); result.pinned = group.pinned; result.version = group.version;
    return result;
  }

  current(): LocalAccountGroup[] { return this.groups.map((row: LocalAccountGroup): LocalAccountGroup => this.copy(row)); }
  get(id: string): LocalAccountGroup | null {
    const row: LocalAccountGroup | undefined = this.groups.find((value: LocalAccountGroup): boolean => value.id === id);
    return row === undefined ? null : this.copy(row);
  }
  source(group: LocalAccountGroup): TimelineTopic {
    const topic: TimelineTopic = new TimelineTopic('local-group:' + group.id, $r('app.string.account_groups_title'),
      $r('sys.symbol.person_2'), '', [], false);
    topic.localGroupId = group.id; topic.localGroupVersion = group.version;
    topic.displayTitle = group.name; topic.iconText = group.icon;
    return topic;
  }
  sources(): TimelineTopic[] { return this.groups.map((group: LocalAccountGroup): TimelineTopic => this.source(group)); }
  private publish(): void {
    homeTimelineStore.setLocalGroupTopics(this.sources(), this.groups.filter((row: LocalAccountGroup): boolean => row.pinned)
      .map((row: LocalAccountGroup): string => 'local-group:' + row.id));
  }
  private save(context: common.Context, next: LocalAccountGroup[], viewer: string): boolean {
    if (viewer.length === 0 || viewer !== this.viewer || viewer !== xPrivateClient.viewerId()) { return false; }
    try {
      const disk: preferences.Preferences = preferences.getPreferencesSync(context, { name: 'harmonyx_local_account_groups' });
      disk.putSync(viewer, JSON.stringify(next)); disk.flushSync();
      this.groups = next; this.publish(); return true;
    } catch (error) { return false; }
  }
  upsert(context: common.Context, value: LocalAccountGroup, viewer: string): string {
    if (value.name.trim().length === 0 || value.name.trim().length > 40) { return ''; }
    const previous: LocalAccountGroup | null = this.get(value.id);
    if (value.id.length > 0 && previous === null) { return ''; }
    const row: LocalAccountGroup = this.copy(value);
    row.id = previous?.id ?? (Date.now().toString(36) + '-' + Math.random().toString(36).slice(2, 10));
    row.name = row.name.trim(); row.icon = row.icon.trim().slice(0, 16) || DEFAULT_ACCOUNT_GROUP_ICON;
    row.members = this.uniqueMembers(row.members);
    const changed: boolean = previous === null || previous.members.map((member: UserRow): string => member.id).join(',') !==
      row.members.map((member: UserRow): string => member.id).join(',');
    row.version = previous === null ? 1 : previous.version + (changed ? 1 : 0);
    const next: LocalAccountGroup[] = this.current();
    const index: number = next.findIndex((group: LocalAccountGroup): boolean => group.id === row.id);
    if (index >= 0) { next[index] = row; } else { next.push(row); }
    return this.save(context, next, viewer) ? row.id : '';
  }
  setPinned(context: common.Context, id: string, pinned: boolean): boolean {
    const next: LocalAccountGroup[] = this.current();
    const row: LocalAccountGroup | undefined = next.find((group: LocalAccountGroup): boolean => group.id === id);
    if (row === undefined) { return false; }
    row.pinned = pinned; return this.save(context, next, this.viewer);
  }
  remove(context: common.Context, id: string, viewer: string): boolean {
    if (this.get(id) === null) { return false; }
    return this.save(context, this.groups.filter((group: LocalAccountGroup): boolean => group.id !== id), viewer);
  }
}

export const localAccountGroupStore: LocalAccountGroupStore = new LocalAccountGroupStore();
