import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import util from '@ohos.util';
import type { Tweet, ProfileArticle } from '../models/Tweet';
import { ReadingDocument, ReadingDocuments, ReadingParagraph, ReadingPosition } from './ReadingDocument';
import { xPrivateStore } from './XPrivateStore';
import { xPrivateClient, XPrivateResult } from './XPrivateClient';
import { XTimelineParser } from './XTimelineParser';
import { XArticleParser } from './XArticleParser';
import { proxyDownloadService } from './ProxyDownloadService';

export const STORAGE_KEY_OFFLINE_READING_REVISION: string = 'harmonyx.offline_reading_revision';

export class OfflineReadingEntry {
  id: string = '';
  title: string = '';
  author: string = '';
  file: string = '';
  tags: string[] = [];
  note: string = '';
  unread: boolean = true;
  progress: number = 0;
  savedAt: number = 0;
  complete: boolean = true;
  imagesComplete: boolean = true;
  includesImages: boolean = false;
}

export class OfflineSaveResult {
  ok: boolean = false;
  complete: boolean = false;
}

export class OfflineReadingStore {
  private pending: Set<string> = new Set<string>();
  private revisions: Map<string, number> = new Map<string, number>();

  account(context: common.Context): string { return xPrivateStore.load(context).cacheIdentity(); }
  private store(context: common.Context): preferences.Preferences {
    return preferences.getPreferencesSync(context, { name: 'harmonyx_offline_reading' });
  }
  private key(account: string, key: string): string { return encodeURIComponent(account) + ':' + key; }
  private directory(context: common.Context): string { return context.filesDir + '/offline_reading'; }
  private owns(context: common.Context, path: string): boolean {
    const prefix: string = this.directory(context) + '/';
    return path.startsWith(prefix) && /^[a-fA-F0-9-]+\.(json|img)$/.test(path.substring(prefix.length));
  }
  private publish(): void {
    AppStorage.setOrCreate<number>(STORAGE_KEY_OFFLINE_READING_REVISION,
      (AppStorage.get<number>(STORAGE_KEY_OFFLINE_READING_REVISION) ?? 0) + 1);
  }
  entries(context: common.Context): OfflineReadingEntry[] {
    try {
      const parsed: OfflineReadingEntry[] = JSON.parse(this.store(context).getSync(
        this.key(this.account(context), 'index'), '[]') as string) as OfflineReadingEntry[];
      if (!Array.isArray(parsed)) { return []; }
      return parsed.filter((entry: OfflineReadingEntry): boolean => entry !== null &&
        typeof entry.id === 'string' && typeof entry.title === 'string' && typeof entry.file === 'string' &&
        Array.isArray(entry.tags) && typeof entry.note === 'string' && this.owns(context, entry.file));
    } catch (_error) { return []; }
  }
  private writeIndex(context: common.Context, account: string, entries: OfflineReadingEntry[]): void {
    if (account !== this.account(context)) { throw new Error('reading_account_changed'); }
    const store: preferences.Preferences = this.store(context);
    const key: string = this.key(account, 'index');
    const previous: string = store.getSync(key, '[]') as string;
    try { store.putSync(key, JSON.stringify(entries)); store.flushSync(); }
    catch (error) { store.putSync(key, previous); throw new Error('reading_index_failed'); }
    this.publish();
  }
  includeImages(context: common.Context): boolean {
    return this.store(context).getSync(this.key(this.account(context), 'images'), false) === true;
  }
  setIncludeImages(context: common.Context, value: boolean): void {
    const store: preferences.Preferences = this.store(context);
    store.putSync(this.key(this.account(context), 'images'), value); store.flushSync();
  }
  read(context: common.Context, id: string): ReadingDocument | null {
    const entry: OfflineReadingEntry | undefined = this.entries(context).find((item: OfflineReadingEntry): boolean => item.id === id);
    if (entry === undefined) { return null; }
    try {
      const doc: ReadingDocument = JSON.parse(fileIo.readTextSync(entry.file)) as ReadingDocument;
      if (doc.id !== id || !Array.isArray(doc.paragraphs)) { return null; }
      // Offline rendering may only mount durable, owned image files.
      for (let i: number = 0; i < doc.paragraphs.length; i++) {
        const paragraph: ReadingParagraph = doc.paragraphs[i];
        paragraph.images = (paragraph.images ?? []).filter((path: string): boolean =>
          this.owns(context, path) && fileIo.accessSync(path));
      }
      return doc;
    } catch (_error) { return null; }
  }
  update(context: common.Context, id: string, tags: string, note: string, unread: boolean): void {
    const entries: OfflineReadingEntry[] = this.entries(context);
    const entry: OfflineReadingEntry | undefined = entries.find((item: OfflineReadingEntry): boolean => item.id === id);
    if (entry === undefined) { return; }
    const normalized: string[] = [];
    const parts: string[] = tags.split(/[,，\n]/);
    for (let i: number = 0; i < parts.length; i++) {
      const tag: string = parts[i].trim().substring(0, 40);
      if (tag.length > 0 && normalized.indexOf(tag) < 0) { normalized.push(tag); }
    }
    entry.tags = normalized.slice(0, 20); entry.note = note.substring(0, 4000); entry.unread = unread;
    this.writeIndex(context, this.account(context), entries);
  }
  remove(context: common.Context, id: string): void {
    const account: string = this.account(context);
    const operation: string = this.key(account, id);
    this.revisions.set(operation, (this.revisions.get(operation) ?? 0) + 1);
    const entries: OfflineReadingEntry[] = this.entries(context);
    const removed: OfflineReadingEntry | undefined = entries.find((item: OfflineReadingEntry): boolean => item.id === id);
    const document: ReadingDocument | null = this.read(context, id);
    this.writeIndex(context, account, entries.filter((item: OfflineReadingEntry): boolean => item.id !== id));
    if (removed !== undefined) { this.clean(context, removed.file, document); }
  }
  position(context: common.Context, id: string): ReadingPosition {
    try {
      const saved: ReadingPosition = JSON.parse(this.store(context).getSync(this.key(this.account(context), 'read:' + id), '{}') as string) as ReadingPosition;
      const result: ReadingPosition = new ReadingPosition();
      result.anchor = typeof saved.anchor === 'string' ? saved.anchor : '';
      result.progress = Number.isFinite(saved.progress) ? Math.max(0, Math.min(1, saved.progress)) : 0;
      result.fontSize = Number.isFinite(saved.fontSize) ? Math.max(14, Math.min(28, saved.fontSize)) : 18;
      result.authorOnly = saved.authorOnly !== false;
      return result;
    } catch (_error) { return new ReadingPosition(); }
  }
  savePosition(context: common.Context, account: string, id: string, value: ReadingPosition): void {
    if (account !== this.account(context)) { return; }
    const store: preferences.Preferences = this.store(context);
    store.putSync(this.key(account, 'read:' + id), JSON.stringify(value)); store.flushSync();
    const entries: OfflineReadingEntry[] = this.entries(context);
    const entry: OfflineReadingEntry | undefined = entries.find((item: OfflineReadingEntry): boolean => item.id === id);
    if (entry !== undefined) {
      entry.progress = value.progress;
      if (value.progress >= 0.98) { entry.unread = false; }
      this.writeIndex(context, account, entries);
    }
  }
  async capture(context: common.Context, root: Tweet, account: string): Promise<OfflineSaveResult> {
    try { return await this.capturePost(context, root, account); }
    catch (_error) { return new OfflineSaveResult(); }
  }
  private async capturePost(context: common.Context, root: Tweet, account: string): Promise<OfflineSaveResult> {
    // Clone before hydration so saving never mutates a live feed object.
    const post: Tweet = JSON.parse(JSON.stringify(root)) as Tweet;
    const session: number = xPrivateClient.sessionGeneration();
    const operation: string = this.key(account, root.id);
    const revision: number = this.revisions.get(operation) ?? 0;
    if (account !== this.account(context)) { return new OfflineSaveResult(); }
    if (post.article !== undefined && !(post.article.plainText ?? '').length && !(post.article.blocks?.length ?? 0)) {
      try {
        const response: XPrivateResult = await xPrivateClient.postContent('TweetResultByRestId', post.id);
        let article: ProfileArticle | undefined = response.ok ? XTimelineParser.parsePostContent(response.body, post.id)?.article : undefined;
        if (article === undefined || !(article.plainText ?? '').length && !(article.blocks?.length ?? 0)) {
          const detail: XPrivateResult = await xPrivateClient.postContent('ArticleEntityResultByRestId', post.article.id);
          article = detail.ok ? XArticleParser.detail(detail.body) : undefined;
        }
        if (article !== undefined && article.id === post.article.id) { post.article = article; }
      } catch (_error) { }
    }
    if (account !== this.account(context) || session !== xPrivateClient.sessionGeneration() ||
      revision !== (this.revisions.get(operation) ?? 0)) { return new OfflineSaveResult(); }
    return this.save(context, ReadingDocuments.build(post), account, this.includeImages(context));
  }
  async save(context: common.Context, value: ReadingDocument, account: string, images: boolean): Promise<OfflineSaveResult> {
    const result: OfflineSaveResult = new OfflineSaveResult();
    const operation: string = this.key(account, value.id);
    if (account !== this.account(context) || this.pending.has(operation)) { return result; }
    this.pending.add(operation);
    const revision: number = this.revisions.get(operation) ?? 0;
    const document: ReadingDocument = JSON.parse(JSON.stringify(value)) as ReadingDocument;
    const created: string[] = [];
    let file: string = '';
    let committed: boolean = false;
    let imagesComplete: boolean = true;
    try {
      const directory: string = this.directory(context);
      if (!fileIo.accessSync(directory)) { fileIo.mkdirSync(directory); }
      const downloaded: Map<string, string> = new Map<string, string>();
      for (let p: number = 0; p < document.paragraphs.length; p++) {
        const paragraph: ReadingParagraph = document.paragraphs[p];
        const urls: string[] = paragraph.images;
        paragraph.images = [];
        if (!images) { continue; }
        for (let i: number = 0; i < urls.length; i++) {
          let local: string | undefined = downloaded.get(urls[i]);
          if (local === undefined) {
            local = directory + '/' + util.generateRandomUUID() + '.img'; created.push(local);
            let ok: boolean = false;
            if (this.owns(context, urls[i]) && fileIo.accessSync(urls[i])) { fileIo.copyFileSync(urls[i], local); ok = true; }
            else if (urls[i].startsWith('https://') || urls[i].startsWith('http://')) {
              ok = await proxyDownloadService.downloadWithRetry(urls[i], local, 1);
            }
            if (ok) { ok = await this.validImage(local); }
            if (!ok) { imagesComplete = false; this.unlink(context, local); continue; }
            downloaded.set(urls[i], local);
          }
          paragraph.images.push(local);
        }
      }
      if (account !== this.account(context) || revision !== (this.revisions.get(operation) ?? 0)) { return result; }
      file = directory + '/' + util.generateRandomUUID() + '.json';
      this.writeDocument(file, document);
      const previous: ReadingDocument | null = this.read(context, value.id);
      const entries: OfflineReadingEntry[] = this.entries(context);
      const existing: OfflineReadingEntry | undefined = entries.find((item: OfflineReadingEntry): boolean => item.id === value.id);
      const entry: OfflineReadingEntry = existing ?? new OfflineReadingEntry();
      if (existing === undefined) {
        entry.progress = this.position(context, value.id).progress;
        entry.unread = entry.progress < 0.98;
      }
      const oldFile: string = entry.file;
      entry.id = value.id; entry.title = value.title; entry.author = value.paragraphs[0]?.author ?? '';
      entry.file = file; entry.savedAt = Date.now(); entry.complete = document.complete;
      entry.includesImages = images; entry.imagesComplete = imagesComplete;
      this.writeIndex(context, account, [entry, ...entries.filter((item: OfflineReadingEntry): boolean => item.id !== value.id)]);
      committed = true; result.ok = true; result.complete = document.complete && imagesComplete;
      if (oldFile.length > 0) { this.clean(context, oldFile, previous); }
      return result;
    } catch (_error) { return result; }
    finally {
      this.pending.delete(operation);
      if (!committed) {
        this.unlink(context, file);
        for (let i: number = 0; i < created.length; i++) { this.unlink(context, created[i]); }
      }
    }
  }
  private writeDocument(path: string, document: ReadingDocument): void {
    const file: fileIo.File = fileIo.openSync(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
    try { fileIo.writeSync(file.fd, JSON.stringify(document)); fileIo.fsyncSync(file.fd); }
    finally { fileIo.closeSync(file); }
  }
  private async validImage(path: string): Promise<boolean> {
    let source: image.ImageSource | null = null;
    try {
      source = image.createImageSource(path);
      const info: image.ImageInfo = await source.getImageInfo();
      return info.size.width > 0 && info.size.height > 0;
    } catch (_error) { return false; }
    finally { if (source !== null) { try { await source.release(); } catch (_error) { } } }
  }
  private unlink(context: common.Context, path: string): void {
    if (!this.owns(context, path)) { return; }
    try { if (fileIo.accessSync(path)) { fileIo.unlinkSync(path); } } catch (_error) { }
  }
  private clean(context: common.Context, file: string, document: ReadingDocument | null): void {
    this.unlink(context, file);
    if (document === null) { return; }
    for (let p: number = 0; p < document.paragraphs.length; p++) {
      for (let i: number = 0; i < document.paragraphs[p].images.length; i++) { this.unlink(context, document.paragraphs[p].images[i]); }
    }
  }
}

export const offlineReadingStore: OfflineReadingStore = new OfflineReadingStore();
