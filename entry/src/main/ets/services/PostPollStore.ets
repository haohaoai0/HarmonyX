import type { PollOption, Tweet, TweetPoll } from '../models/Tweet';
import { copyPoll, pollClosed, pollTotal } from '../utils/PostPoll';
import { xPrivateClient, XPrivateResult } from './XPrivateClient';
import { XTimelineParser } from './XTimelineParser';
import { XPostCardParser } from './XPostCardParser';

export const STORAGE_KEY_POST_POLL_REVISION: string = 'harmonyx.post_poll_revision';

export class PostPollStore {
  private polls: Map<string, TweetPoll> = new Map<string, TweetPoll>();
  private busy: Set<string> = new Set<string>();
  private uncertain: Set<string> = new Set<string>();
  private invalidated: Set<string> = new Set<string>();
  private generation: number = -1;

  constructor() {
    xPrivateClient.onSessionChange((): void => { this.syncSession(); this.changed(); });
  }

  private syncSession(): number {
    const generation: number = xPrivateClient.sessionGeneration();
    if (this.generation !== generation) {
      const ids: string[] = Array.from(this.polls.keys());
      for (let i: number = 0; i < ids.length; i++) { this.invalidated.add(ids[i]); }
      this.polls.clear(); this.busy.clear(); this.uncertain.clear();
      this.generation = generation;
    }
    return generation;
  }

  private changed(): void {
    AppStorage.setOrCreate<number>(STORAGE_KEY_POST_POLL_REVISION,
      (AppStorage.get<number>(STORAGE_KEY_POST_POLL_REVISION) ?? 0) + 1);
  }

  snapshot(postId: string, fallback: TweetPoll): TweetPoll {
    this.syncSession();
    const current: TweetPoll = this.polls.get(postId) ?? fallback;
    if (!this.invalidated.has(postId)) { return current; }
    const clean: TweetPoll = copyPoll(current); clean.selectedChoice = ''; return clean;
  }

  isBusy(postId: string): boolean { this.syncSession(); return this.busy.has(postId); }
  isUncertain(postId: string): boolean { this.syncSession(); return this.uncertain.has(postId); }

  known(postId: string, _revision: number = 0): TweetPoll | undefined {
    this.syncSession();
    const poll: TweetPoll | undefined = this.polls.get(postId);
    return poll === undefined ? undefined : this.snapshot(postId, poll);
  }

  remember(postId: string, poll: TweetPoll, fresh: boolean = false): void {
    this.syncSession();
    const previous: TweetPoll | undefined = this.polls.get(postId);
    const next: TweetPoll = copyPoll(poll);
    if (fresh) { this.invalidated.delete(postId); }
    else if (this.invalidated.has(postId)) { next.selectedChoice = ''; }
    if (previous !== undefined) {
      // Stale route/feed snapshots cannot undo a vote already confirmed by X.
      if (next.selectedChoice.length === 0) { next.selectedChoice = previous.selectedChoice; }
      next.countsAreFinal = next.countsAreFinal || previous.countsAreFinal;
      if ((!fresh && pollTotal(next) < pollTotal(previous)) || !next.countsKnown) {
        next.options = copyPoll(previous).options;
        next.countsKnown = previous.countsKnown;
      }
      if (next.api.length === 0) {
        next.api = previous.api; next.cardUri = previous.cardUri; next.cardName = previous.cardName;
      }
    }
    if (previous !== undefined && JSON.stringify(previous) === JSON.stringify(next)) { return; }
    this.polls.set(postId, next);
    if (this.polls.size > 256) {
      const keys: string[] = Array.from(this.polls.keys());
      for (let i: number = 0; i < keys.length; i++) {
        if (!this.busy.has(keys[i]) && !this.uncertain.has(keys[i])) { this.polls.delete(keys[i]); break; }
      }
    }
    this.changed();
  }

  private async read(postId: string, generation: number): Promise<TweetPoll | undefined> {
    const result: XPrivateResult = await xPrivateClient.tweetDetail(postId, 'Relevance', '', true);
    if (!result.ok || generation !== xPrivateClient.sessionGeneration()) { return undefined; }
    const posts: Tweet[] = XTimelineParser.parse(result.body, false)?.tweets ?? [];
    for (let i: number = 0; i < posts.length; i++) {
      if (posts[i].id === postId) { return posts[i].poll; }
    }
    return undefined;
  }

  async refresh(postId: string): Promise<string> {
    const generation: number = this.syncSession();
    if (!xPrivateClient.isSignedIn()) { return 'login'; }
    if (this.busy.has(postId)) { return 'busy'; }
    this.busy.add(postId); this.changed();
    try {
      const poll: TweetPoll | undefined = await this.read(postId, generation);
      if (generation !== xPrivateClient.sessionGeneration()) { return 'account'; }
      if (poll === undefined) { return 'refresh'; }
      this.remember(postId, poll, true);
      this.uncertain.delete(postId);
      return 'ok';
    } catch (error) { return 'refresh'; }
    finally {
      if (generation === xPrivateClient.sessionGeneration()) { this.busy.delete(postId); this.changed(); }
    }
  }

  async vote(postId: string, fallback: TweetPoll, choice: string): Promise<string> {
    const generation: number = this.syncSession();
    if (!xPrivateClient.isSignedIn()) { return 'login'; }
    if (this.busy.has(postId)) { return 'busy'; }
    if (this.uncertain.has(postId)) { return 'unconfirmed'; }
    let poll: TweetPoll = this.snapshot(postId, fallback);
    if (poll.selectedChoice.length > 0) { return 'voted'; }
    if (pollClosed(poll, Date.now())) { return 'closed'; }
    if (!poll.options.some((option: PollOption): boolean => option.id === choice)) { return 'invalid'; }
    this.busy.add(postId); this.changed();
    try {
      if (poll.api.length === 0 || poll.cardUri.length === 0 || this.invalidated.has(postId)) {
        const hydrated: TweetPoll | undefined = await this.read(postId, generation);
        if (generation !== xPrivateClient.sessionGeneration()) { return 'account'; }
        if (hydrated === undefined) { return 'refresh'; }
        poll = hydrated; this.remember(postId, poll, true);
        if (poll.selectedChoice.length > 0) { return 'voted'; }
        if (pollClosed(poll, Date.now())) { return 'closed'; }
      }
      const result: XPrivateResult = await xPrivateClient.votePoll(postId, poll, choice, generation);
      if (generation !== xPrivateClient.sessionGeneration()) { return 'account'; }
      if (!result.ok && result.status >= 400 && result.status < 500) { return 'failed'; }
      if (!result.ok && result.status === 0) { return 'invalid'; }
      // Confirm selected_choice in the returned card or a fresh detail read.
      // HTTP 200 alone is insufficient; no synthetic vote counts are created.
      let confirmed: TweetPoll | undefined = result.ok ? XPostCardParser.voteResponse(result.body) : undefined;
      if (confirmed !== undefined && confirmed.cardUri !== poll.cardUri) { confirmed = undefined; }
      if (confirmed === undefined || confirmed.selectedChoice.length === 0) {
        confirmed = await this.read(postId, generation);
      }
      if (generation !== xPrivateClient.sessionGeneration()) { return 'account'; }
      if (confirmed !== undefined && confirmed.selectedChoice.length > 0) {
        this.remember(postId, confirmed, true); this.uncertain.delete(postId); return 'ok';
      }
      this.uncertain.add(postId);
      return 'unconfirmed';
    } catch (error) {
      if (generation === xPrivateClient.sessionGeneration()) { this.uncertain.add(postId); }
      return 'unconfirmed';
    } finally {
      if (generation === xPrivateClient.sessionGeneration()) { this.busy.delete(postId); this.changed(); }
    }
  }
}

export const postPollStore: PostPollStore = new PostPollStore();
