import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { accountStore } from './AccountStore';

interface SeenHomeTweet {
  id: string;
  observedAt: number;
}

const MAX_HISTORY: number = 4096;
const REQUEST_LIMIT: number = 200;
const RETENTION_MS: number = 90 * 24 * 60 * 60 * 1000;

// APK opb/vg4 keeps 90-day observations and sends the latest 200 IDs, rather
// than treating the unread tail of the loaded timeline as already seen.
export class HomeSeenTweetStore {
  private accountId: string = '';
  private loaded: boolean = false;
  private records: SeenHomeTweet[] = [];
  private timer: number = -1;
  private dirty: boolean = false;

  load(context: common.Context): void {
    const accountId: string = accountStore.activeId(context);
    if (this.loaded && this.accountId === accountId) { return; }
    this.flush(context);
    this.accountId = accountId;
    this.loaded = true;
    // A failed write for the previous account must not mark the next account's
    // freshly loaded history as pending data.
    this.dirty = false;
    this.records = [];
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: 'harmonyx_home_seen' });
      const records: SeenHomeTweet[] = JSON.parse(store.getSync(accountId, '[]') as string) as SeenHomeTweet[];
      if (records instanceof Array) {
        this.records = records.filter((row: SeenHomeTweet): boolean => typeof row.id === 'string' &&
          typeof row.observedAt === 'number' && row.observedAt >= Date.now() - RETENTION_MS).slice(0, MAX_HISTORY);
      }
    } catch (error) { }
  }

  observe(context: common.Context, tweetId: string): void {
    if (!/^\d+$/.test(tweetId)) { return; }
    this.load(context);
    const now: number = Date.now();
    const previous: SeenHomeTweet | undefined = this.records.find((row: SeenHomeTweet): boolean => row.id === tweetId);
    if (previous !== undefined && now - previous.observedAt < 60000) { return; }
    const observation: SeenHomeTweet = { id: tweetId, observedAt: now };
    this.records = [observation,
      ...this.records.filter((row: SeenHomeTweet): boolean => row.id !== tweetId && row.observedAt >= now - RETENTION_MS)]
      .slice(0, MAX_HISTORY);
    this.dirty = true;
    if (this.timer < 0) {
      this.timer = setTimeout((): void => { this.timer = -1; this.flush(context); }, 500);
    }
  }

  requestIds(context: common.Context): string[] {
    return this.observedIds(context).slice(0, REQUEST_LIMIT);
  }

  observedIds(context: common.Context): string[] {
    this.load(context);
    return this.records.filter((row: SeenHomeTweet): boolean => row.observedAt >= Date.now() - RETENTION_MS)
      .map((row: SeenHomeTweet): string => row.id);
  }

  flush(context: common.Context): void {
    if (this.timer >= 0) { clearTimeout(this.timer); this.timer = -1; }
    if (!this.dirty) { return; }
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: 'harmonyx_home_seen' });
      store.putSync(this.accountId, JSON.stringify(this.records));
      store.flushSync();
      this.dirty = false;
    } catch (error) { }
  }
}

export const homeSeenTweetStore: HomeSeenTweetStore = new HomeSeenTweetStore();
