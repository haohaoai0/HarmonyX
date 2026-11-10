import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { homeTimelineStore, TimelineTopic } from './HomeTimelineStore';
import { HomeTopicTag, XHomeTopicParser } from './XHomeTopicParser';
import { xPrivateClient, XPrivateResult } from './XPrivateClient';

class HomeTopicPinChange {
  topic: HomeTopicTag = new HomeTopicTag();
  pinned: boolean = false;
}

class HomeTopicPreferences {
  available: HomeTopicTag[] = [];
  pinned: HomeTopicTag[] = [];
  legacyPins: string[] = [];
  pendingPins: HomeTopicPinChange[] = [];
}

export class HomeTopicStore {
  private viewer: string = '';
  private state: HomeTopicPreferences = new HomeTopicPreferences();
  private revision: number = 0;
  private pending: Promise<boolean> | null = null;

  load(context: common.Context, viewer: string): void {
    this.viewer = viewer; this.revision++; this.pending = null;
    this.state = new HomeTopicPreferences();
    if (viewer.length > 0) {
      try {
        const disk = preferences.getPreferencesSync(context, { name: 'harmonyx_home_topics' });
        const raw: string = disk.getSync(viewer, '') as string;
        if (raw.length > 0) {
          const saved: HomeTopicPreferences = JSON.parse(raw) as HomeTopicPreferences;
          this.state.available = this.validRows(saved.available);
          this.state.pinned = this.validRows(saved.pinned);
          this.state.pendingPins = Array.isArray(saved.pendingPins) ? saved.pendingPins.filter((change: HomeTopicPinChange): boolean =>
            change !== null && typeof change.pinned === 'boolean' && this.validRows([change.topic]).length === 1) : [];
          this.state.legacyPins = (saved.legacyPins ?? []).filter((id: string): boolean =>
            homeTimelineStore.legacyTopics().some((topic: TimelineTopic): boolean => topic.id === id));
        }
        // Old keyword pins were global. Claim that migration once, without
        // copying one account's selections to every later account or writing X.
        if ((disk.getSync('legacy_owner', '') as string).length === 0) {
          this.state.legacyPins = homeTimelineStore.legacyPins();
          disk.putSync(viewer, JSON.stringify(this.state)); disk.putSync('legacy_owner', viewer); disk.flushSync();
        }
      } catch (error) { /* Keep this account's in-memory directory. */ }
    }
    this.apply(context);
  }

  private validRows(rows: HomeTopicTag[]): HomeTopicTag[] {
    return Array.isArray(rows) ? rows.filter((row: HomeTopicTag): boolean => row !== null && row !== undefined &&
      XHomeTopicParser.validTag(row.tag) && typeof row.name === 'string' && row.name.length > 0) : [];
  }

  private matchesLegacy(context: common.Context, row: HomeTopicTag, legacy: TimelineTopic): boolean {
    const labels: string[] = [row.tag.toLowerCase(), row.name.toLowerCase(), (row.tabLabel ?? '').toLowerCase()];
    if (labels.indexOf(legacy.id) >= 0 || legacy.keywords.some((word: string): boolean => labels.indexOf(word.toLowerCase()) >= 0)) { return true; }
    try { return labels.indexOf(context.resourceManager.getStringSync(legacy.title).toLowerCase()) >= 0; }
    catch (error) { return false; }
  }

  private apply(context: common.Context): void {
    const rows: HomeTopicTag[] = this.state.available.slice();
    for (const row of this.state.pinned) {
      if (!rows.some((value: HomeTopicTag): boolean => value.tag === row.tag)) { rows.push(row); }
    }
    const topics: TimelineTopic[] = rows.map((row: HomeTopicTag): TimelineTopic =>
      homeTimelineStore.tagSource(row.tag, row.name, row.tabLabel ?? '', row.iconUrl ?? ''));
    const pins: string[] = this.state.pinned.map((row: HomeTopicTag): string => 'tag:' + row.tag);
    for (const id of this.state.legacyPins) {
      const legacy: TimelineTopic | undefined = homeTimelineStore.legacyTopics().find((topic: TimelineTopic): boolean => topic.id === id);
      if (legacy === undefined) { continue; }
      const match: HomeTopicTag | undefined = rows.find((row: HomeTopicTag): boolean => this.matchesLegacy(context, row, legacy));
      const key: string = match === undefined ? id : 'tag:' + match.tag;
      if (match === undefined) { topics.push(legacy); }
      if (pins.indexOf(key) < 0) { pins.push(key); }
    }
    homeTimelineStore.setAccountTopics(topics, pins);
  }

  private persist(context: common.Context): void {
    try {
      const disk = preferences.getPreferencesSync(context, { name: 'harmonyx_home_topics' });
      disk.putSync(this.viewer, JSON.stringify(this.state)); disk.flushSync();
    } catch (error) { /* A cache failure must not discard a confirmed server state. */ }
    this.apply(context);
  }

  async refresh(context: common.Context): Promise<boolean> {
    if (this.pending !== null) { return this.pending; }
    const request: Promise<boolean> = this.readDirectory(context);
    this.pending = request;
    try { return await request; } finally { if (this.pending === request) { this.pending = null; } }
  }

  private async readDirectory(context: common.Context): Promise<boolean> {
    const viewer: string = this.viewer;
    const generation: number = xPrivateClient.sessionGeneration();
    const revision: number = this.revision;
    if (viewer.length === 0 || viewer !== xPrivateClient.viewerId()) { return false; }
    try {
      const results: XPrivateResult[] = await Promise.all([xPrivateClient.pinnableTimelines(), xPrivateClient.pinnedTimelines()]);
      if (viewer !== this.viewer || generation !== xPrivateClient.sessionGeneration() || revision !== this.revision) { return false; }
      const available: HomeTopicTag[] | null = results[0].ok ? XHomeTopicParser.parse(results[0].body, false) : null;
      const pinned: HomeTopicTag[] | null = results[1].ok ? XHomeTopicParser.parse(results[1].body, true) : null;
      if (available !== null) { this.state.available = available; }
      if (pinned !== null) {
        // A successful mutation can reach the directory replica later. Keep
        // the account's saved intent until a read acknowledges it, including
        // removals, so reopening the manager or restarting cannot undo it.
        this.state.pendingPins = this.state.pendingPins.filter((change: HomeTopicPinChange): boolean =>
          pinned.some((row: HomeTopicTag): boolean => row.tag === change.topic.tag) !== change.pinned);
        this.state.pinned = pinned;
        for (const change of this.state.pendingPins) {
          this.state.pinned = this.state.pinned.filter((row: HomeTopicTag): boolean => row.tag !== change.topic.tag);
          if (change.pinned) { this.state.pinned.push(change.topic); }
        }
      }
      if (available !== null || pinned !== null) { this.persist(context); }
      return available !== null && pinned !== null;
    } catch (error) { return false; }
  }

  async setPinned(context: common.Context, source: TimelineTopic, pinned: boolean): Promise<boolean> {
    const viewer: string = this.viewer;
    const generation: number = xPrivateClient.sessionGeneration();
    if (viewer.length === 0 || viewer !== xPrivateClient.viewerId()) { return false; }
    if (source.tag.length === 0) {
      if (pinned || this.state.legacyPins.indexOf(source.id) < 0) { return false; }
      this.state.legacyPins = this.state.legacyPins.filter((id: string): boolean => id !== source.id);
      this.revision++; this.persist(context); return true;
    }
    const row: HomeTopicTag | undefined = [...this.state.available, ...this.state.pinned]
      .find((value: HomeTopicTag): boolean => value.tag === source.tag);
    if (row === undefined) { return false; }
    this.revision++;
    try {
      const result: XPrivateResult = await xPrivateClient.pinHomeTopic(row.tag, pinned);
      if (!result.ok || viewer !== this.viewer || generation !== xPrivateClient.sessionGeneration()) { return false; }
      this.state.pinned = this.state.pinned.filter((value: HomeTopicTag): boolean => value.tag !== row.tag);
      if (pinned) { this.state.pinned.push(row); }
      this.state.pendingPins = this.state.pendingPins.filter((change: HomeTopicPinChange): boolean => change.topic.tag !== row.tag);
      this.state.pendingPins.push({ topic: row, pinned: pinned });
      this.state.legacyPins = this.state.legacyPins.filter((id: string): boolean => {
        const legacy: TimelineTopic | undefined = homeTimelineStore.legacyTopics().find((topic: TimelineTopic): boolean => topic.id === id);
        return legacy !== undefined && !this.matchesLegacy(context, row, legacy);
      });
      this.revision++; this.persist(context); return true;
    } catch (error) { return false; }
  }
}

export const homeTopicStore: HomeTopicStore = new HomeTopicStore();
