import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import fs from '@ohos.file.fs';
import type { Tweet } from '../models/Tweet';

interface ViewedVideo {
  id: string;
  viewedAt: number;
}

class VideoAccountHistory {
  loaded: boolean = false;
  records: ViewedVideo[] = [];
  dirty: boolean = false;
}

export class VideoTimelineState {
  account: string = '';
  seed: string = '';
  provider: string = 'web';
  cursor: string = '';
  timelineId: string = '';
  tweets: Tweet[] = [];
  exhausted: boolean = false;
  cursorHistory: string[] = [];
  updatedAt: number = 0;
  // Never serialized. Two viewers of the same seed share one request chain.
  pending: Promise<string> | null = null;
}

const HISTORY_LIMIT: number = 4096;
const HISTORY_CHUNK: number = 80;
const HISTORY_RETENTION: number = 90 * 24 * 60 * 60 * 1000;
const STATE_LIMIT: number = 16;
const STATE_RETENTION: number = 30 * 60 * 1000;
const STATE_DIRECTORY: string = 'video-recommendations';

// Keep credential-derived fallback identities out of file names and saved data.
export function videoAccountKey(identity: string): string {
  if (identity.length === 0 || identity === 'anonymous') { return ''; }
  let first: number = 0x811c9dc5;
  let second: number = 0x9e3779b9;
  for (let i: number = 0; i < identity.length; i++) {
    first = Math.imul(first ^ identity.charCodeAt(i), 0x01000193) >>> 0;
    second = Math.imul(second ^ identity.charCodeAt(i), 0x85ebca6b) >>> 0;
  }
  return first.toString(16) + '-' + second.toString(16);
}

export class VideoRecommendationStore {
  private histories: Map<string, VideoAccountHistory> = new Map<string, VideoAccountHistory>();
  private timelines: Map<string, VideoTimelineState> = new Map<string, VideoTimelineState>();

  private history(context: common.Context | null, account: string): VideoAccountHistory {
    let history: VideoAccountHistory | undefined = this.histories.get(account);
    if (history === undefined) {
      history = new VideoAccountHistory();
      this.histories.set(account, history);
    }
    if (history.loaded || context === null || account.length === 0) { return history; }
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: 'harmonyx_video_seen' });
      const count: number = Math.min(Math.ceil(HISTORY_LIMIT / HISTORY_CHUNK),
        Math.max(0, store.getSync(account + ':count', 0) as number));
      const records: ViewedVideo[] = history.records.slice();
      const ids: Set<string> = new Set<string>(records.map((row: ViewedVideo): string => row.id));
      for (let i: number = 0; i < count; i++) {
        const chunk: ViewedVideo[] = JSON.parse(store.getSync(account + ':' + i, '[]') as string) as ViewedVideo[];
        if (!(chunk instanceof Array)) { continue; }
        for (const row of chunk) {
          if (typeof row.id === 'string' && /^\d+$/.test(row.id) && !ids.has(row.id) &&
            typeof row.viewedAt === 'number' && row.viewedAt >= Date.now() - HISTORY_RETENTION &&
            row.viewedAt <= Date.now()) {
            records.push(row); ids.add(row.id);
          }
        }
      }
      history.records = records.sort((a: ViewedVideo, b: ViewedVideo): number => b.viewedAt - a.viewedAt).slice(0, HISTORY_LIMIT);
      history.loaded = true;
    } catch (error) { }
    return history;
  }

  viewedIds(context: common.Context | null, account: string): Set<string> {
    const history: VideoAccountHistory = this.history(context, account);
    return new Set<string>(history.records.filter((row: ViewedVideo): boolean =>
      row.viewedAt >= Date.now() - HISTORY_RETENTION).map((row: ViewedVideo): string => row.id));
  }

  observe(context: common.Context | null, account: string, id: string): void {
    if (account.length === 0 || !/^\d+$/.test(id)) { return; }
    const history: VideoAccountHistory = this.history(context, account);
    const now: number = Date.now();
    const previous: ViewedVideo | undefined = history.records.find((row: ViewedVideo): boolean => row.id === id);
    if (previous !== undefined && now - previous.viewedAt < 60000) { return; }
    const record: ViewedVideo = { id: id, viewedAt: now };
    history.records = [record, ...history.records.filter((row: ViewedVideo): boolean =>
      row.id !== id && row.viewedAt >= now - HISTORY_RETENTION)].slice(0, HISTORY_LIMIT);
    history.dirty = true;
    // Record only visibility, never downloads/preloads. Persist before a process
    // kill can lose a viewed card; chunks stay below Preferences' value limit.
    this.flushHistory(context, account);
  }

  flushHistory(context: common.Context | null, account: string): void {
    const history: VideoAccountHistory = this.history(context, account);
    if (context === null || !history.loaded || !history.dirty) { return; }
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: 'harmonyx_video_seen' });
      const count: number = Math.ceil(history.records.length / HISTORY_CHUNK);
      const oldCount: number = Math.min(52, store.getSync(account + ':count', 0) as number);
      for (let i: number = 0; i < count; i++) {
        store.putSync(account + ':' + i, JSON.stringify(history.records.slice(i * HISTORY_CHUNK, (i + 1) * HISTORY_CHUNK)));
      }
      for (let i: number = count; i < oldCount; i++) { store.deleteSync(account + ':' + i); }
      store.putSync(account + ':count', count);
      store.flushSync(); history.dirty = false;
    } catch (error) { }
  }

  state(context: common.Context | null, account: string, seed: string): VideoTimelineState {
    const key: string = account + ':' + seed;
    let state: VideoTimelineState | undefined = this.timelines.get(key);
    if (state !== undefined && (state.pending !== null || state.updatedAt === 0 ||
      state.updatedAt >= Date.now() - STATE_RETENTION)) { return state; }
    state = new VideoTimelineState(); state.account = account; state.seed = seed;
    if (context !== null && account.length > 0 && /^\d+$/.test(seed)) {
      try {
        const saved: VideoTimelineState = JSON.parse(fs.readTextSync(this.path(context, state))) as VideoTimelineState;
        if (saved.account === account && saved.seed === seed && saved.updatedAt >= Date.now() - STATE_RETENTION &&
          saved.updatedAt <= Date.now() && saved.tweets instanceof Array && saved.cursorHistory instanceof Array &&
          typeof saved.cursor === 'string' && typeof saved.timelineId === 'string' &&
          (saved.provider === 'web' || saved.provider === 'apk')) {
          state.provider = saved.provider; state.cursor = saved.cursor; state.timelineId = saved.timelineId;
          state.tweets = saved.tweets.slice(-120); state.exhausted = saved.exhausted === true;
          state.cursorHistory = saved.cursorHistory.filter((cursor: string): boolean => typeof cursor === 'string').slice(-64);
          state.updatedAt = saved.updatedAt;
        }
      } catch (error) { }
    }
    this.timelines.set(key, state);
    if (this.timelines.size > STATE_LIMIT) {
      for (const entry of this.timelines) {
        if (entry[0] !== key && entry[1].pending === null) { this.timelines.delete(entry[0]); break; }
      }
    }
    return state;
  }

  saveState(context: common.Context | null, state: VideoTimelineState): void {
    if (context === null || state.account.length === 0 || !/^\d+$/.test(state.seed)) { return; }
    let file: fs.File | undefined = undefined;
    try {
      const directory: string = context.cacheDir + '/' + STATE_DIRECTORY;
      if (!fs.accessSync(directory)) { fs.mkdirSync(directory); }
      // pending Promise must never become part of a persisted state.
      const saved: VideoTimelineState = new VideoTimelineState();
      saved.account = state.account; saved.seed = state.seed; saved.provider = state.provider;
      saved.cursor = state.cursor; saved.timelineId = state.timelineId; saved.tweets = state.tweets.slice(-120);
      saved.exhausted = state.exhausted; saved.cursorHistory = state.cursorHistory.slice(-64); saved.updatedAt = state.updatedAt;
      file = fs.openSync(this.path(context, state), fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, JSON.stringify(saved));
      fs.closeSync(file); file = undefined;
      const names: string[] = fs.listFileSync(directory).filter((name: string): boolean => /^[0-9a-f]+-[0-9a-f]+_\d+\.json$/.test(name));
      names.sort((a: string, b: string): number => fs.statSync(directory + '/' + b).mtime - fs.statSync(directory + '/' + a).mtime);
      for (const name of names.slice(STATE_LIMIT)) { fs.unlinkSync(directory + '/' + name); }
    } catch (error) { }
    finally { if (file !== undefined) { try { fs.closeSync(file); } catch (error) { } } }
  }

  private path(context: common.Context, state: VideoTimelineState): string {
    return context.cacheDir + '/' + STATE_DIRECTORY + '/' + state.account + '_' + state.seed + '.json';
  }
}

export const videoRecommendationStore: VideoRecommendationStore = new VideoRecommendationStore();
