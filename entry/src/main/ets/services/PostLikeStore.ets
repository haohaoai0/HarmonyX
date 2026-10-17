import type { Tweet } from '../models/Tweet';
import { authStore } from './AuthStore';
import { xPrivateClient } from './XPrivateClient';

export const STORAGE_KEY_POST_LIKES_REVISION: string = 'harmonyx.post_likes_revision';

class PostLikeState {
  liked: boolean;
  count: number;

  constructor(liked: boolean, count: number) {
    this.liked = liked;
    this.count = Math.max(0, count);
  }
}

// Media routes serialize posts, and separate timelines can contain different
// objects for the same ID. Keep local writes authoritative for this session.
export class PostLikeStore {
  private states: Map<string, PostLikeState> = new Map<string, PostLikeState>();
  private pending: Set<string> = new Set<string>();
  private scope: string = '';
  private accountRevision: number = 0;

  constructor() {
    xPrivateClient.onSessionChange((): void => {
      this.syncSession();
      this.changed();
    });
  }

  private syncSession(): string {
    const scope: string = xPrivateClient.isSignedIn() ?
      'private:' + xPrivateClient.sessionIdentity() : 'oauth:' + authStore.getUserId();
    if (this.scope !== scope) {
      this.states.clear();
      this.pending.clear();
      this.scope = scope;
      this.accountRevision++;
    }
    return scope;
  }

  private changed(): void {
    const revision: number = AppStorage.get<number>(STORAGE_KEY_POST_LIKES_REVISION) ?? 0;
    AppStorage.setOrCreate<number>(STORAGE_KEY_POST_LIKES_REVISION, revision + 1);
  }

  apply(post: Tweet): void {
    this.syncSession();
    const state: PostLikeState | undefined = this.states.get(post.id);
    if (state === undefined) { return; }
    if (post.liked !== state.liked) { post.liked = state.liked; }
    if (post.metrics.likeCount !== state.count) { post.metrics.likeCount = state.count; }
  }

  isPending(postId: string): boolean {
    this.syncSession();
    return this.pending.has(postId);
  }

  async setLike(post: Tweet, liked: boolean, write: () => Promise<boolean>): Promise<boolean> {
    this.syncSession();
    const accountRevision: number = this.accountRevision;
    if (this.pending.has(post.id)) { return false; }
    this.apply(post);
    const previous: PostLikeState = new PostLikeState(post.liked, post.metrics.likeCount);
    if (previous.liked === liked) { return true; }
    const next: PostLikeState = new PostLikeState(liked, previous.count + (liked ? 1 : -1));
    this.pending.add(post.id);
    this.states.set(post.id, next);
    this.apply(post);
    this.changed();
    let ok: boolean = false;
    try {
      ok = await write();
    } catch (error) {
      ok = false;
    }
    // A late response from a switched-out account cannot overwrite the new one.
    this.syncSession();
    if (accountRevision !== this.accountRevision) { return false; }
    this.pending.delete(post.id);
    if (!ok) { this.states.set(post.id, previous); }
    this.apply(post);
    this.changed();
    return ok;
  }
}

export const postLikeStore: PostLikeStore = new PostLikeStore();
