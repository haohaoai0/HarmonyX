import type { Tweet } from '../models/Tweet';
import { XPrivateResult, xPrivateClient } from './XPrivateClient';
import { XTimelineParser } from './XTimelineParser';

class CachedChatPost {
  post: Tweet;
  expiresAt: number;

  constructor(post: Tweet) {
    this.post = post;
    this.expiresAt = Date.now() + 5 * 60 * 1000;
  }
}

// Memory-only, bounded and scoped to the current session. Private/protected
// post previews must never cross account switches or persist in a DM cache.
export class ChatPostPreviewService {
  private generation: number = -1;
  private cache: Map<string, CachedChatPost> = new Map();
  private pending: Map<string, Promise<Tweet | null>> = new Map();

  known(postId: string): Tweet | null {
    if (this.generation !== xPrivateClient.sessionGeneration() || !xPrivateClient.isSignedIn()) { return null; }
    const cached: CachedChatPost | undefined = this.cache.get(postId);
    return cached !== undefined && cached.expiresAt > Date.now() ? cached.post : null;
  }

  async load(postId: string): Promise<Tweet | null> {
    if (!/^\d+$/.test(postId) || !xPrivateClient.isSignedIn()) { return null; }
    const generation: number = xPrivateClient.sessionGeneration();
    if (this.generation !== generation) {
      this.cache.clear();
      this.pending.clear();
      this.generation = generation;
    }
    const cached: CachedChatPost | undefined = this.cache.get(postId);
    if (cached !== undefined && cached.expiresAt > Date.now()) { return cached.post; }
    const pending: Promise<Tweet | null> | undefined = this.pending.get(postId);
    if (pending !== undefined) { return pending; }
    const request: Promise<Tweet | null> = this.fetch(postId, generation);
    this.pending.set(postId, request);
    try { return await request; }
    finally { if (this.generation === generation) { this.pending.delete(postId); } }
  }

  private async fetch(postId: string, generation: number): Promise<Tweet | null> {
    try {
      const result: XPrivateResult = await xPrivateClient.postContent('TweetResultByRestId', postId);
      if (!result.ok || generation !== xPrivateClient.sessionGeneration() || !xPrivateClient.isSignedIn()) { return null; }
      const post: Tweet | null = XTimelineParser.parsePostContent(result.body, postId);
      if (post === null || post.id !== postId) { return null; }
      if (this.cache.size >= 64) { this.cache.clear(); }
      this.cache.set(postId, new CachedChatPost(post));
      return post;
    } catch (error) { return null; }
  }
}

export const chatPostPreview: ChatPostPreviewService = new ChatPostPreviewService();
