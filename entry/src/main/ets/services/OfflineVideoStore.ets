import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import util from '@ohos.util';
import type { MediaAttachment, Tweet } from '../models/Tweet';
import { xPrivateStore } from './XPrivateStore';
import { proxyDownloadService } from './ProxyDownloadService';
import { downloadManager, DownloadTask, DownloadTaskStatus } from './DownloadManager';

export const STORAGE_KEY_OFFLINE_VIDEOS_REVISION: string = 'harmonyx.offline_videos_revision';

export enum OfflineVideoSaveStatus {
  SAVED = 0,
  ALREADY_SAVED = 1,
  CANCELED = 2,
  FAILED = 3
}

export class OfflineVideoEntry {
  id: string = '';
  postId: string = '';
  mediaId: string = '';
  url: string = '';
  authorName: string = '';
  authorHandle: string = '';
  avatarUrl: string = '';
  verified: boolean = false;
  text: string = '';
  previewUrl: string = '';
  filePath: string = '';
  coverFile: string = '';
  savedAt: number = 0;
  durationMs: number = 0;
  width: number = 0;
  height: number = 0;
  sizeBytes: number = 0;
}

export class OfflineVideoStore {
  private static readonly MAX_ENTRIES: number = 500;
  private pending: Set<string> = new Set<string>();

  account(context: common.Context): string {
    return xPrivateStore.load(context).cacheIdentity();
  }

  private store(context: common.Context): preferences.Preferences {
    return preferences.getPreferencesSync(context, { name: 'harmonyx_offline_videos' });
  }

  private directory(context: common.Context): string {
    return context.filesDir + '/offline_videos';
  }

  private key(account: string, key: string): string {
    return encodeURIComponent(account) + ':' + key;
  }

  private owns(context: common.Context, path: string): boolean {
    const prefix: string = this.directory(context) + '/';
    return path.startsWith(prefix) && /^[a-fA-F0-9-]+\.(mp4|img)$/.test(path.substring(prefix.length));
  }

  private publish(): void {
    const current: number = AppStorage.get<number>(STORAGE_KEY_OFFLINE_VIDEOS_REVISION) ?? 0;
    AppStorage.setOrCreate<number>(STORAGE_KEY_OFFLINE_VIDEOS_REVISION, current + 1);
  }

  entries(context: common.Context): OfflineVideoEntry[] {
    try {
      const account: string = this.account(context);
      const parsed: OfflineVideoEntry[] = JSON.parse(this.store(context).getSync(
        this.key(account, 'index'), '[]') as string) as OfflineVideoEntry[];
      if (!Array.isArray(parsed)) {
        return [];
      }
      const rows: OfflineVideoEntry[] = [];
      for (let index: number = 0; index < parsed.length; index++) {
        const entry: OfflineVideoEntry = this.normalize(parsed[index]);
        if (entry.id.length > 0 && entry.filePath.length > 0 && this.owns(context, entry.filePath) &&
          fileIo.accessSync(entry.filePath)) {
          rows.push(entry);
        }
      }
      return rows.slice(0, OfflineVideoStore.MAX_ENTRIES);
    } catch (error) {
      return [];
    }
  }

  find(context: common.Context, postId: string, mediaId: string): OfflineVideoEntry | null {
    const id: string = this.entryId(postId, mediaId);
    const rows: OfflineVideoEntry[] = this.entries(context);
    for (let index: number = 0; index < rows.length; index++) {
      if (rows[index].id === id) {
        return rows[index];
      }
    }
    return null;
  }

  async save(context: common.UIAbilityContext, tweet: Tweet, media: MediaAttachment,
    sourceUrl: string): Promise<OfflineVideoSaveStatus> {
    if (sourceUrl.length === 0) {
      return OfflineVideoSaveStatus.FAILED;
    }
    const account: string = this.account(context);
    const id: string = this.entryId(tweet.id, media.id);
    const operation: string = this.key(account, id);
    const existing: OfflineVideoEntry | null = this.find(context, tweet.id, media.id);
    if (existing !== null) {
      return OfflineVideoSaveStatus.ALREADY_SAVED;
    }
    if (this.pending.has(operation)) {
      return OfflineVideoSaveStatus.FAILED;
    }
    this.pending.add(operation);
    return new Promise<OfflineVideoSaveStatus>((resolve: (value: OfflineVideoSaveStatus) => void): void => {
      const taskId: string = downloadManager.enqueue(context, sourceUrl, media.id, true,
        (readyId: string, ready: boolean): void => {
          if (!ready) {
            this.pending.delete(operation);
            const failedTask: DownloadTask | null = downloadManager.getTask(readyId, context);
            if (failedTask !== null) {
              downloadManager.delete(readyId, context);
            }
            resolve(failedTask === null ? OfflineVideoSaveStatus.CANCELED : OfflineVideoSaveStatus.FAILED);
            return;
          }
          const task: DownloadTask | null = downloadManager.getTask(readyId, context);
          if (task === null || task.status !== DownloadTaskStatus.READY_TO_SAVE) {
            downloadManager.delete(readyId, context);
            this.pending.delete(operation);
            resolve(OfflineVideoSaveStatus.FAILED);
            return;
          }
          this.commit(context, account, tweet, media, task).then((status: OfflineVideoSaveStatus): void => {
            if (status === OfflineVideoSaveStatus.SAVED) {
              downloadManager.saveCompleted(readyId, context);
            } else {
              downloadManager.delete(readyId, context);
            }
            this.pending.delete(operation);
            resolve(status);
          }).catch((): void => {
            downloadManager.delete(readyId, context);
            this.pending.delete(operation);
            resolve(OfflineVideoSaveStatus.FAILED);
          });
        });
      if (taskId.length === 0) {
        this.pending.delete(operation);
        resolve(OfflineVideoSaveStatus.FAILED);
      }
    });
  }

  remove(context: common.Context, id: string): boolean {
    const rows: OfflineVideoEntry[] = this.entries(context);
    const removed: OfflineVideoEntry | undefined =
      rows.find((entry: OfflineVideoEntry): boolean => entry.id === id);
    if (removed === undefined) {
      return false;
    }
    try {
      this.writeIndex(context, this.account(context),
        rows.filter((entry: OfflineVideoEntry): boolean => entry.id !== id));
      this.unlink(context, removed.filePath);
      this.unlink(context, removed.coverFile);
      this.publish();
      return true;
    } catch (error) {
      return false;
    }
  }

  clear(context: common.Context): boolean {
    const rows: OfflineVideoEntry[] = this.entries(context);
    try {
      this.writeIndex(context, this.account(context), []);
      for (let index: number = 0; index < rows.length; index++) {
        this.unlink(context, rows[index].filePath);
        this.unlink(context, rows[index].coverFile);
      }
      this.publish();
      return true;
    } catch (error) {
      return false;
    }
  }

  totalBytes(context: common.Context): number {
    const rows: OfflineVideoEntry[] = this.entries(context);
    let total: number = 0;
    for (let index: number = 0; index < rows.length; index++) {
      total += Math.max(0, rows[index].sizeBytes);
    }
    return total;
  }

  private async commit(context: common.UIAbilityContext, account: string, tweet: Tweet,
    media: MediaAttachment, task: DownloadTask): Promise<OfflineVideoSaveStatus> {
    if (account !== this.account(context)) {
      return OfflineVideoSaveStatus.FAILED;
    }
    const directory: string = this.directory(context);
    if (!fileIo.accessSync(directory)) {
      fileIo.mkdirSync(directory);
    }
    const base: string = util.generateRandomUUID();
    const filePath: string = directory + '/' + base + '.mp4';
    const coverFile: string = directory + '/' + base + '.img';
    let committed: boolean = false;
    try {
      fileIo.copyFileSync(task.filePath, filePath);
      const stat = fileIo.statSync(filePath);
      if (!stat.isFile() || stat.size <= 0) {
        throw new Error('offline_video_empty');
      }
      const coverReady: boolean = await this.downloadCover(context, media.previewUrl, coverFile);
      if (account !== this.account(context)) {
        throw new Error('offline_video_account_changed');
      }
      const entry: OfflineVideoEntry = this.snapshot(tweet, media, filePath,
        coverReady ? coverFile : '', stat.size);
      const rows: OfflineVideoEntry[] = this.entries(context);
      const next: OfflineVideoEntry[] = [entry, ...rows.filter(
        (value: OfflineVideoEntry): boolean => value.id !== entry.id)].slice(0, OfflineVideoStore.MAX_ENTRIES);
      this.writeIndex(context, account, next);
      committed = true;
      this.publish();
      return OfflineVideoSaveStatus.SAVED;
    } finally {
      if (!committed) {
        this.unlink(context, filePath);
        this.unlink(context, coverFile);
      }
    }
  }

  private async downloadCover(context: common.Context, url: string, path: string): Promise<boolean> {
    if (url.length === 0) {
      return false;
    }
    try {
      if (url.startsWith('file://')) {
        fileIo.copyFileSync(new fileUri.FileUri(url).path, path);
      } else if (url.startsWith('https://') || url.startsWith('http://')) {
        if (!await proxyDownloadService.downloadWithRetry(url, path, 1)) {
          return false;
        }
      } else {
        return false;
      }
      const stat = fileIo.statSync(path);
      return stat.isFile() && stat.size > 0;
    } catch (error) {
      this.unlink(context, path);
      return false;
    }
  }

  private snapshot(tweet: Tweet, media: MediaAttachment, filePath: string,
    coverFile: string, sizeBytes: number): OfflineVideoEntry {
    const entry: OfflineVideoEntry = new OfflineVideoEntry();
    entry.id = this.entryId(tweet.id, media.id);
    entry.postId = tweet.id;
    entry.mediaId = media.id;
    entry.authorName = (tweet.author.name ?? '').substring(0, 80);
    entry.authorHandle = (tweet.author.username ?? '').substring(0, 80);
    entry.avatarUrl = (tweet.author.avatarUrl ?? '').substring(0, 1024);
    entry.verified = tweet.author.verified;
    entry.text = Array.from(tweet.text ?? '').slice(0, 500).join('');
    entry.url = 'https://x.com/' + (entry.authorHandle.length > 0 ? entry.authorHandle : 'i/web') +
      '/status/' + tweet.id;
    entry.previewUrl = media.previewUrl.substring(0, 1024);
    entry.filePath = filePath;
    entry.coverFile = coverFile;
    entry.savedAt = Date.now();
    entry.durationMs = media.durationMs ?? 0;
    entry.width = media.width;
    entry.height = media.height;
    entry.sizeBytes = sizeBytes;
    return entry;
  }

  private entryId(postId: string, mediaId: string): string {
    return postId + ':' + mediaId;
  }

  private writeIndex(context: common.Context, account: string, entries: OfflineVideoEntry[]): void {
    if (account !== this.account(context)) {
      throw new Error('offline_video_account_changed');
    }
    const store: preferences.Preferences = this.store(context);
    const key: string = this.key(account, 'index');
    const previous: string = store.getSync(key, '[]') as string;
    try {
      store.putSync(key, JSON.stringify(entries));
      store.flushSync();
    } catch (error) {
      store.putSync(key, previous);
      throw new Error('offline_video_index_failed');
    }
  }

  private normalize(saved: OfflineVideoEntry): OfflineVideoEntry {
    const entry: OfflineVideoEntry = new OfflineVideoEntry();
    entry.id = typeof saved.id === 'string' ? saved.id : '';
    entry.postId = typeof saved.postId === 'string' ? saved.postId : '';
    entry.mediaId = typeof saved.mediaId === 'string' ? saved.mediaId : '';
    entry.url = typeof saved.url === 'string' ? saved.url : '';
    entry.authorName = typeof saved.authorName === 'string' ? saved.authorName : '';
    entry.authorHandle = typeof saved.authorHandle === 'string' ? saved.authorHandle : '';
    entry.avatarUrl = typeof saved.avatarUrl === 'string' ? saved.avatarUrl : '';
    entry.verified = saved.verified === true;
    entry.text = typeof saved.text === 'string' ? saved.text : '';
    entry.previewUrl = typeof saved.previewUrl === 'string' ? saved.previewUrl : '';
    entry.filePath = typeof saved.filePath === 'string' ? saved.filePath : '';
    entry.coverFile = typeof saved.coverFile === 'string' ? saved.coverFile : '';
    entry.savedAt = Number.isFinite(saved.savedAt) ? saved.savedAt : 0;
    entry.durationMs = Number.isFinite(saved.durationMs) ? Math.max(0, saved.durationMs) : 0;
    entry.width = Number.isFinite(saved.width) ? Math.max(0, saved.width) : 0;
    entry.height = Number.isFinite(saved.height) ? Math.max(0, saved.height) : 0;
    entry.sizeBytes = Number.isFinite(saved.sizeBytes) ? Math.max(0, saved.sizeBytes) : 0;
    return entry;
  }

  private unlink(context: common.Context, path: string): void {
    if (path.length === 0 || !this.owns(context, path)) {
      return;
    }
    try {
      if (fileIo.accessSync(path)) {
        fileIo.unlinkSync(path);
      }
    } catch (error) {
    }
  }
}

export const offlineVideoStore: OfflineVideoStore = new OfflineVideoStore();
