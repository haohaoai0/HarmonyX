import { common, bundleManager } from '@kit.AbilityKit';
import { fileIo, storageStatistics } from '@kit.CoreFileKit';
import { statistics } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { videoPlaybackCache } from './VideoPlaybackCache';
import { xChatMedia } from './XChatMedia';

export enum StorageCacheKind { ALL = 0, VIDEO = 1, CHAT = 2, TIMELINE = 3 }

export class StorageFileUsage {
  bytes: number = 0;
  count: number = 0;
  failures: number = 0;
}

export class AppStorageUsage {
  appBytes: number = 0;
  dataBytes: number = 0;
  systemAvailable: boolean = false;
  freeBytes: number = -1;
  cache: StorageFileUsage = new StorageFileUsage();
  video: StorageFileUsage = new StorageFileUsage();
  chat: StorageFileUsage = new StorageFileUsage();
  timeline: StorageFileUsage = new StorageFileUsage();
  downloads: StorageFileUsage = new StorageFileUsage();

  clearableBytes(): number { return this.video.bytes + this.chat.bytes + this.timeline.bytes; }
  otherCacheBytes(): number { return Math.max(0, this.cache.bytes - this.clearableBytes()); }
  totalBytes(): number { return this.appBytes + this.dataBytes; }
  hasScanFailures(): boolean {
    return this.cache.failures + this.video.failures + this.chat.failures +
      this.timeline.failures + this.downloads.failures > 0;
  }
}

export class AppNetworkUsage { sent: number = 0; received: number = 0; }
export class StorageClearResult { freedBytes: number = 0; remainingBytes: number = 0; failures: number = 0; }

export function storageBytes(bytes: number): string {
  const value: number = Math.max(0, Number.isFinite(bytes) ? bytes : 0);
  if (value < 1024) { return Math.round(value).toString() + ' B'; }
  if (value < 1024 * 1024) { return (value / 1024).toFixed(1) + ' KB'; }
  if (value < 1024 * 1024 * 1024) { return (value / (1024 * 1024)).toFixed(1) + ' MB'; }
  return (value / (1024 * 1024 * 1024)).toFixed(2) + ' GB';
}

// All scans stay within app-owned directories. lstat prevents following links.
export async function scanStoragePath(path: string): Promise<StorageFileUsage> {
  const usage: StorageFileUsage = new StorageFileUsage();
  try {
    const stat: fileIo.Stat = await fileIo.lstat(path);
    if (stat.isFile()) { usage.bytes = stat.size; usage.count = 1; }
    else if (stat.isDirectory()) {
      const names: string[] = await fileIo.listFile(path);
      for (let offset: number = 0; offset < names.length; offset += 16) {
        const batch: string[] = names.slice(offset, offset + 16).filter((name: string): boolean =>
          name !== '.' && name !== '..' && !name.includes('/') && !name.includes('\\'));
        const children: StorageFileUsage[] = await Promise.all(batch.map((name: string): Promise<StorageFileUsage> =>
          scanStoragePath(path + '/' + name)));
        for (let i: number = 0; i < children.length; i++) {
          usage.bytes += children[i].bytes; usage.count += children[i].count; usage.failures += children[i].failures;
        }
      }
    }
  } catch (error) {
    if ((error as BusinessError).code !== 13900002) { usage.failures++; }
  }
  return usage;
}

async function chatUsage(context: common.UIAbilityContext): Promise<StorageFileUsage> {
  const usage: StorageFileUsage = new StorageFileUsage();
  const paths: string[] = xChatMedia.clearableCachePaths(context);
  for (let i: number = 0; i < paths.length; i++) {
    const file: StorageFileUsage = await scanStoragePath(paths[i]);
    usage.bytes += file.bytes; usage.count += file.count; usage.failures += file.failures;
  }
  return usage;
}

async function timelineUsage(context: common.UIAbilityContext): Promise<StorageFileUsage> {
  const feed: StorageFileUsage = await scanStoragePath(context.cacheDir + '/feed-cache');
  const response: StorageFileUsage = await scanStoragePath(context.cacheDir + '/response-cache');
  feed.bytes += response.bytes; feed.count += response.count; feed.failures += response.failures;
  return feed;
}

export async function getAppStorageUsage(context: common.UIAbilityContext): Promise<AppStorageUsage> {
  const usage: AppStorageUsage = new AppStorageUsage();
  await Promise.all<void>([
    storageStatistics.getCurrentBundleStats().then((stats: storageStatistics.BundleStats): void => {
      // dataSize includes cache; adding cacheSize again would double-count it.
      usage.appBytes = stats.appSize; usage.dataBytes = stats.dataSize; usage.systemAvailable = true;
    }).catch((): void => {}),
    storageStatistics.getFreeSize().then((bytes: number): void => { usage.freeBytes = bytes; }).catch((): void => {}),
    scanStoragePath(context.cacheDir).then((result: StorageFileUsage): void => { usage.cache = result; }),
    scanStoragePath(context.cacheDir + '/video-playback-cache').then((result: StorageFileUsage): void => { usage.video = result; }),
    chatUsage(context).then((result: StorageFileUsage): void => { usage.chat = result; }),
    timelineUsage(context).then((result: StorageFileUsage): void => { usage.timeline = result; }),
    scanStoragePath(context.filesDir + '/harmonyx-downloads').then((result: StorageFileUsage): void => { usage.downloads = result; })
  ]);
  return usage;
}

async function ownTraffic(uid: number, received: boolean): Promise<number> {
  try { return await (received ? statistics.getUidRxBytes(uid) : statistics.getUidTxBytes(uid)); }
  catch (error) {
    // The system has no record yet if this app has not used the network since boot.
    if ((error as BusinessError).code === 2103005) { return 0; }
    throw error as Error;
  }
}

export async function getAppNetworkUsage(): Promise<AppNetworkUsage> {
  const info: bundleManager.BundleInfo = bundleManager.getBundleInfoForSelfSync(
    bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
  const values: number[] = await Promise.all([ownTraffic(info.appInfo.uid, false), ownTraffic(info.appInfo.uid, true)]);
  const usage: AppNetworkUsage = new AppNetworkUsage(); usage.sent = values[0]; usage.received = values[1];
  return usage;
}

async function removeTimelineFiles(context: common.UIAbilityContext): Promise<number> {
  let failures: number = 0;
  const roots: string[] = [context.cacheDir + '/feed-cache', context.cacheDir + '/response-cache'];
  for (let i: number = 0; i < roots.length; i++) {
    try {
      const names: string[] = await fileIo.listFile(roots[i]);
      for (let n: number = 0; n < names.length; n++) {
        const name: string = names[n];
        if (name.includes('/') || name.includes('\\') || name === '.' || name === '..') { continue; }
        const path: string = roots[i] + '/' + name;
        try {
          if ((await fileIo.lstat(path)).isFile()) { await fileIo.unlink(path); }
        } catch (error) { if ((error as BusinessError).code !== 13900002) { failures++; } }
      }
    } catch (error) { if ((error as BusinessError).code !== 13900002) { failures++; } }
  }
  return failures;
}

export async function clearAppCache(context: common.UIAbilityContext, kind: StorageCacheKind): Promise<StorageClearResult> {
  const before: AppStorageUsage = await getAppStorageUsage(context);
  const result: StorageClearResult = new StorageClearResult();
  if (kind === StorageCacheKind.ALL || kind === StorageCacheKind.VIDEO) {
    // The player service retires active leases; their bytes are reclaimed after playback closes.
    videoPlaybackCache.clear(context);
    const revision: number = AppStorage.get<number>('harmonyx.video_cache_revision') ?? 0;
    AppStorage.setOrCreate<number>('harmonyx.video_cache_revision', revision + 1);
  }
  if (kind === StorageCacheKind.ALL || kind === StorageCacheKind.CHAT) { result.failures += xChatMedia.clearDownloadedCache(context); }
  if (kind === StorageCacheKind.ALL || kind === StorageCacheKind.TIMELINE) { result.failures += await removeTimelineFiles(context); }
  const after: AppStorageUsage = await getAppStorageUsage(context);
  result.freedBytes = Math.max(0, before.cache.bytes - after.cache.bytes);
  result.remainingBytes = after.clearableBytes();
  if (before.hasScanFailures() || after.hasScanFailures()) { result.failures++; }
  return result;
}
