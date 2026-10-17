// Last-known-good home feed, kept as the app rendered it.
//
// The private-interface layer already replays the last good *body* of a read,
// but only for the exact operation and variables it was asked for, and only
// through the cookie path. This store keeps the first page the reader actually
// saw — posts, cursor and source — so a cold start with no network shows those
// posts instead of an empty screen, whichever client supplied them.
import fs from '@ohos.file.fs';
import { common } from '@kit.AbilityKit';
import hilog from '@ohos.hilog';
import type { Tweet } from '../models/Tweet';

const DOMAIN = 0xFF00;
const TAG = 'HarmonyX-FeedCache';
const DIRECTORY = 'feed-cache';

// One cached first page. Plain data only: the store round-trips it through
// JSON, so nothing here may carry behaviour.
export interface CachedFeed {
  // Wall-clock time of the fetch that produced this page.
  savedAt: number;
  tweets: Tweet[];
  nextToken: string;
  source: string;
}

export class FeedCache {
  private static directory(context: common.Context): string {
    return context.cacheDir + '/' + DIRECTORY;
  }

  // Filesystem-safe, stable name for an account + feed pair.
  private static fileName(key: string): string {
    let hash: number = 0x811c9dc5;
    for (let i: number = 0; i < key.length; i++) {
      hash = hash ^ key.charCodeAt(i);
      hash = (hash * 0x01000193) >>> 0;
    }
    return hash.toString(16) + '_' + key.length.toString();
  }

  static save(context: common.Context, key: string, feed: CachedFeed): void {
    if (feed.tweets.length === 0) {
      return;
    }
    let file: fs.File | undefined = undefined;
    try {
      const directory: string = FeedCache.directory(context);
      if (!fs.accessSync(directory)) {
        fs.mkdirSync(directory);
      }
      const path: string = directory + '/' + FeedCache.fileName(key);
      file = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, JSON.stringify(feed));
    } catch (error) {
      hilog.debug(DOMAIN, TAG, 'feed cache write failed: %{public}s', JSON.stringify(error));
    } finally {
      if (file !== undefined) {
        try {
          fs.closeSync(file);
        } catch (error) {
          // A descriptor that is already gone is not a problem here.
        }
      }
    }
  }

  // Returns the cached page, or null when there is nothing usable.
  static load(context: common.Context, key: string): CachedFeed | null {
    try {
      const path: string = FeedCache.directory(context) + '/' + FeedCache.fileName(key);
      if (!fs.accessSync(path)) {
        return null;
      }
      const feed: CachedFeed = JSON.parse(fs.readTextSync(path)) as CachedFeed;
      if (feed.tweets === undefined || feed.tweets.length === 0) {
        return null;
      }
      return feed;
    } catch (error) {
      hilog.debug(DOMAIN, TAG, 'feed cache read failed: %{public}s', JSON.stringify(error));
      return null;
    }
  }
}
