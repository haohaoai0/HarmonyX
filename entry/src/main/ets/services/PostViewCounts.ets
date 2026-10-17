import type { Tweet } from '../models/Tweet';
import { authStore } from './AuthStore';
import { TweetPage, XApiClient } from './XApiClient';
import { XPrivateResult, xPrivateClient } from './XPrivateClient';
import { XTimelineParser } from './XTimelineParser';

export const STORAGE_KEY_POST_VIEWS_REVISION: string = 'harmonyx.post_views_revision';
const RETRY_INTERVAL: number = 60000;
const MAX_CONCURRENT: number = 2;
const MAX_CACHED_POSTS: number = 512;

// Android timeline responses can omit views. Visible cards resolve that field
// through the same TweetDetail read used by the detail page, sharing its result.
export class PostViewCounts {
  private counts: Map<string, number> = new Map<string, number>();
  private attempts: Map<string, number> = new Map<string, number>();
  private queued: Set<string> = new Set<string>();
  private queue: string[] = [];
  private active: number = 0;

  countFor(id: string, fallback: number, _revision: number = 0): number {
    return this.counts.get(id) ?? fallback;
  }

  remember(id: string, count: number): void {
    if (!isFinite(count) || count < 0 || this.counts.get(id) === count) {
      return;
    }
    this.counts.set(id, count);
    if (this.counts.size > MAX_CACHED_POSTS) {
      const first: string | undefined = this.counts.keys().next().value;
      if (first !== undefined) {
        this.counts.delete(first);
        this.attempts.delete(first);
      }
    }
    const revision: number = AppStorage.get<number>(STORAGE_KEY_POST_VIEWS_REVISION) ?? 0;
    AppStorage.setOrCreate<number>(STORAGE_KEY_POST_VIEWS_REVISION, revision + 1);
  }

  requestMissing(post: Tweet): void {
    if (post.metrics.viewCount > 0) {
      if (!this.counts.has(post.id)) {
        this.remember(post.id, post.metrics.viewCount);
      }
      return;
    }
    if (!/^\d+$/.test(post.id) || this.counts.has(post.id) || this.queued.has(post.id) ||
      (!xPrivateClient.isSignedIn() && !authStore.isSignedIn())) {
      return;
    }
    const attempted: number = this.attempts.get(post.id) ?? 0;
    if (Date.now() - attempted < RETRY_INTERVAL) {
      return;
    }
    this.queue.push(post.id);
    this.queued.add(post.id);
    this.drain();
  }

  private drain(): void {
    while (this.active < MAX_CONCURRENT && this.queue.length > 0) {
      const id: string | undefined = this.queue.shift();
      if (id !== undefined) {
        this.active++;
        this.attempts.set(id, Date.now());
        this.resolve(id);
      }
    }
  }

  private async resolve(id: string): Promise<void> {
    try {
      let focal: Tweet | null = null;
      if (xPrivateClient.isSignedIn()) {
        const result: XPrivateResult = await xPrivateClient.tweetDetail(id);
        if (result.ok) {
          const page: TweetPage | null = XTimelineParser.parse(result.body, false);
          if (page !== null) {
            for (let i: number = 0; i < page.tweets.length; i++) {
              if (page.tweets[i].id === id) {
                focal = page.tweets[i];
                break;
              }
            }
          }
        }
      } else {
        const api: XApiClient = new XApiClient();
        api.setToken(authStore.getToken());
        api.setUser(authStore.getUserId());
        focal = await api.tweetById(id);
      }
      if (focal !== null) {
        this.remember(id, focal.metrics.viewCount);
      }
    } catch (error) {
      // Keep the timeline usable and retry on a later visibility event.
    } finally {
      this.active--;
      this.queued.delete(id);
      this.drain();
    }
  }
}

export const postViewCounts: PostViewCounts = new PostViewCounts();
