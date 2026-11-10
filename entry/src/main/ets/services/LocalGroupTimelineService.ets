import type { Tweet, UserRow } from '../models/Tweet';
import type { TweetPage } from './XApiClient';
import { LocalAccountGroup, localAccountGroupStore } from './LocalAccountGroupStore';
import { XPrivateResult, xPrivateClient } from './XPrivateClient';
import { XTimelineParser } from './XTimelineParser';

class MemberFeed {
  id: string = '';
  cursor: string = '';
  ended: boolean = false;
  buffer: Tweet[] = [];
  pinned: Tweet[] = [];
  cursors: string[] = [];
}

class GroupFeed {
  groupId: string = '';
  version: number = 0;
  generation: number = 0;
  members: MemberFeed[] = [];
  seen: string[] = [];
}

// Each continuation owns unconsumed posts and every member's server cursor.
// Clone before advancing so a failed member request leaves the retry intact.
export class LocalGroupTimelineService {
  private viewer: string = '';
  private continuations: Map<string, GroupFeed> = new Map<string, GroupFeed>();
  private serial: number = 0;

  private current(feed: GroupFeed): boolean {
    return feed.generation === xPrivateClient.sessionGeneration() && this.viewer === xPrivateClient.viewerId() &&
      localAccountGroupStore.get(feed.groupId)?.version === feed.version;
  }
  private fresh(group: LocalAccountGroup): GroupFeed {
    const feed: GroupFeed = new GroupFeed();
    feed.groupId = group.id; feed.version = group.version; feed.generation = xPrivateClient.sessionGeneration();
    feed.members = group.members.map((member: UserRow): MemberFeed => {
      const lane: MemberFeed = new MemberFeed(); lane.id = member.id; return lane;
    });
    return feed;
  }
  private copy(source: GroupFeed): GroupFeed {
    const feed: GroupFeed = new GroupFeed();
    feed.groupId = source.groupId; feed.version = source.version; feed.generation = source.generation;
    feed.seen = source.seen.slice();
    feed.members = source.members.map((sourceLane: MemberFeed): MemberFeed => {
      const lane: MemberFeed = new MemberFeed();
      lane.id = sourceLane.id; lane.cursor = sourceLane.cursor; lane.ended = sourceLane.ended;
      lane.buffer = sourceLane.buffer.slice(); lane.pinned = sourceLane.pinned.slice();
      lane.cursors = sourceLane.cursors.slice(); return lane;
    });
    return feed;
  }
  private async fill(feed: GroupFeed, lane: MemberFeed): Promise<boolean> {
    if (lane.ended || lane.buffer.length > 0) { return true; }
    let result: XPrivateResult;
    try { result = await xPrivateClient.userTweets(lane.id, lane.cursor, 20); }
    catch (error) { return false; }
    if (!this.current(feed)) { return false; }
    const page: TweetPage | null = result.ok ? XTimelineParser.parse(result.body) : null;
    if (page === null) { return false; }
    lane.cursors.push(lane.cursor);
    lane.ended = page.nextToken.length === 0 || lane.cursors.indexOf(page.nextToken) >= 0;
    lane.cursor = page.nextToken;
    const posts: Tweet[] = page.tweets.filter((tweet: Tweet): boolean =>
      (tweet.author.id === lane.id || (tweet.isRepost === true && tweet.repostAuthor?.id === lane.id)) &&
      feed.seen.indexOf(tweet.id) < 0);
    for (const tweet of posts) {
      if (tweet.pinned === true && !lane.pinned.some((row: Tweet): boolean => row.id === tweet.id)) { lane.pinned.push(tweet); }
    }
    lane.buffer = posts.filter((tweet: Tweet): boolean => tweet.pinned !== true);
    const oldest: number = lane.buffer.length > 0 ? Math.min(...lane.buffer.map((tweet: Tweet): number => this.time(tweet))) : Number.POSITIVE_INFINITY;
    lane.buffer.push(...lane.pinned.filter((tweet: Tweet): boolean => lane.ended || this.time(tweet) >= oldest));
    lane.pinned = lane.pinned.filter((tweet: Tweet): boolean => !lane.ended && this.time(tweet) < oldest);
    lane.buffer.sort((a: Tweet, b: Tweet): number => this.time(b) - this.time(a));
    return true;
  }
  private time(tweet: Tweet): number {
    const timestamp: number = Date.parse(tweet.createdAt); return Number.isFinite(timestamp) ? timestamp : 0;
  }
  async page(groupId: string, cursor: string = '', count: number = 20): Promise<TweetPage | null> {
    const viewer: string = xPrivateClient.viewerId();
    if (viewer !== this.viewer) { this.continuations.clear(); this.viewer = viewer; }
    const group: LocalAccountGroup | null = localAccountGroupStore.get(groupId);
    if (group === null || !xPrivateClient.isSignedIn() || viewer.length === 0) { return null; }
    const saved: GroupFeed | undefined = this.continuations.get(cursor);
    const feed: GroupFeed = cursor.length === 0 ? this.fresh(group) : saved !== undefined ? this.copy(saved) : new GroupFeed();
    if (feed.groupId !== groupId || !this.current(feed)) { return null; }
    const tweets: Tweet[] = [];
    // A sparse/deleted-only server page can advance without any visible post.
    // Keep the operation bounded and preserve its cursor for the next request.
    for (let round: number = 0; round < Math.max(1, count) + 3; round++) {
      for (const lane of feed.members) {
        lane.buffer = lane.buffer.filter((tweet: Tweet): boolean => feed.seen.indexOf(tweet.id) < 0);
      }
      const empty: MemberFeed[] = feed.members.filter((lane: MemberFeed): boolean => !lane.ended && lane.buffer.length === 0);
      for (let offset: number = 0; offset < empty.length; offset += 4) {
        const results: boolean[] = await Promise.all(empty.slice(offset, offset + 4)
          .map((lane: MemberFeed): Promise<boolean> => this.fill(feed, lane)));
        if (results.some((ok: boolean): boolean => !ok)) { return null; }
      }
      if (!this.current(feed)) { return null; }
      // Do not emit an older head while another member still has an unknown head.
      if (feed.members.some((lane: MemberFeed): boolean => !lane.ended && lane.buffer.length === 0)) { continue; }
      let best: MemberFeed | null = null;
      for (const lane of feed.members) {
        while (lane.buffer.length > 0 && feed.seen.indexOf(lane.buffer[0].id) >= 0) { lane.buffer.shift(); }
        if (lane.buffer.length > 0 && (best === null || this.time(lane.buffer[0]) > this.time(best.buffer[0]))) { best = lane; }
      }
      if (best === null) { break; }
      const tweet: Tweet = best.buffer.shift() as Tweet;
      feed.seen.push(tweet.id); tweets.push(tweet);
      if (tweets.length >= count) { break; }
    }
    let nextToken: string = '';
    if (feed.members.some((lane: MemberFeed): boolean => !lane.ended || lane.buffer.length > 0)) {
      nextToken = 'local-group:' + (++this.serial).toString(); this.continuations.set(nextToken, feed);
      if (this.continuations.size > 128) {
        const keys: string[] = Array.from(this.continuations.keys()); this.continuations.delete(keys[0]);
      }
    }
    return { tweets: tweets, nextToken: nextToken };
  }
}

export const localGroupTimelineService: LocalGroupTimelineService = new LocalGroupTimelineService();
