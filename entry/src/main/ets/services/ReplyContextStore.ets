import type { Tweet } from '../models/Tweet';
import { ReplyConversation } from './ReplyConversation';
import { XTimelineParser } from './XTimelineParser';
import { XApiClient } from './XApiClient';
import { authStore } from './AuthStore';
import { XPrivateResult, xPrivateClient } from './XPrivateClient';
import type { TweetPage } from './XApiClient';

interface ReplyContextRequest {
  tweet: Tweet;
  account: string;
  key: string;
  resolve: (context: Tweet[]) => void;
}

class ReplyContextStore {
  private pending: Map<string, Promise<Tweet[]>> = new Map<string, Promise<Tweet[]>>();
  private queue: ReplyContextRequest[] = [];
  private active: number = 0;

  private accountKey(): string {
    const identity: string = xPrivateClient.isSignedIn() ?
      'private:' + xPrivateClient.viewerId() : 'oauth:' + authStore.getUserId();
    return identity + ':' + xPrivateClient.sessionGeneration().toString();
  }

  resolve(tweet: Tweet): Promise<Tweet[]> {
    const account: string = this.accountKey();
    const key: string = account + ':' + tweet.id + ':' + (tweet.replyToTweetId ?? '');
    const existing: Promise<Tweet[]> | undefined = this.pending.get(key);
    if (existing !== undefined) {
      return existing;
    }
    const request: Promise<Tweet[]> = new Promise<Tweet[]>((resolve: (context: Tweet[]) => void): void => {
      this.queue.push({ tweet: ReplyConversation.flat(tweet), account: account, key: key, resolve: resolve });
    });
    this.pending.set(key, request);
    // Bound retained responses as well as simultaneous network requests.
    if (this.pending.size > 200) {
      const keys: string[] = Array.from(this.pending.keys());
      this.pending.delete(keys[0]);
    }
    this.drain();
    return request;
  }

  private drain(): void {
    while (this.active < 2 && this.queue.length > 0) {
      const request: ReplyContextRequest | undefined = this.queue.shift();
      if (request !== undefined) {
        this.active++;
        this.load(request);
      }
    }
  }

  private async load(request: ReplyContextRequest): Promise<void> {
    let context: Tweet[] = [];
    try {
      if (request.account !== this.accountKey()) { return; }
      if (xPrivateClient.isSignedIn()) {
        const response: XPrivateResult = await xPrivateClient.tweetDetail(request.tweet.id);
        if (request.account !== this.accountKey()) { return; }
        const page: TweetPage | null = response.ok ? XTimelineParser.parse(response.body, false) : null;
        if (page !== null) {
          ReplyConversation.attach([request.tweet], page.tweets);
          context = request.tweet.replyContext ?? [];
        }
      } else if (authStore.isSignedIn()) {
        const api: XApiClient = new XApiClient();
        api.setToken(authStore.getToken());
        api.setUser(authStore.getUserId());
        const parent: Tweet | null = await api.tweetById(request.tweet.replyToTweetId ?? '');
        if (request.account !== this.accountKey()) { return; }
        if (parent !== null) {
          ReplyConversation.attach([request.tweet], [...(parent.replyContext ?? []), parent]);
          context = request.tweet.replyContext ?? [];
        }
      }
    } catch {
      context = [];
    } finally {
      // Failed/transient reads must not become permanent empty cache entries.
      if (context.length === 0) { this.pending.delete(request.key); }
      request.resolve(context);
      this.active--;
      this.drain();
    }
  }
}

export const replyContextStore: ReplyContextStore = new ReplyContextStore();
