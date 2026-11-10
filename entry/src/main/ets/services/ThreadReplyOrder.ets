import type { Tweet } from '../models/Tweet';

export interface ThreadReplyRow {
  tweet: Tweet;
  depth: number;
  replyingToUsername: string;
  isNestedReply: boolean;
  connectAbove: boolean;
  connectBelow: boolean;
}

class PendingReply {
  tweet: Tweet;
  depth: number;
  handle: string;
  nested: boolean;

  constructor(tweet: Tweet, depth: number, handle: string, nested: boolean) {
    this.tweet = tweet;
    this.depth = depth;
    this.handle = handle;
    this.nested = nested;
  }
}

// Keep direct comments at the top level and place replies immediately after
// their loaded parent. A missing parent leaves the reply visible on its own.
export class ThreadReplyOrder {
  static order(rootId: string, replies: Tweet[]): ThreadReplyRow[] {
    const rows: ThreadReplyRow[] = [];
    const visited: Set<string> = new Set<string>();
    const children: Map<string, Tweet[]> = new Map();
    for (const reply of replies) {
      const parentId: string = reply.replyToTweetId ?? '';
      const siblings: Tweet[] = children.get(parentId) ?? [];
      siblings.push(reply);
      children.set(parentId, siblings);
    }
    for (let i: number = 0; i < replies.length; i++) {
      if (replies[i].replyToTweetId === rootId) {
        ThreadReplyOrder.append(replies[i], 0, '', false, children, visited, rows);
      }
    }
    for (let i: number = 0; i < replies.length; i++) {
      const reply: Tweet = replies[i];
      if (!visited.has(reply.id) && reply.id !== rootId) {
        const handle: string = reply.replyToUsername ?? '';
        const isNested: boolean = reply.replyToTweetId !== undefined &&
          reply.replyToTweetId.length > 0 && reply.replyToTweetId !== rootId;
        ThreadReplyOrder.append(reply, 0, handle, isNested, children, visited, rows);
      }
    }
    for (let i: number = 0; i < rows.length; i++) {
      rows[i].connectAbove = i > 0 && rows[i].tweet.replyToTweetId === rows[i - 1].tweet.id;
      rows[i].connectBelow = i + 1 < rows.length && rows[i + 1].tweet.replyToTweetId === rows[i].tweet.id;
    }
    return rows;
  }

  private static append(reply: Tweet, depth: number, parentHandle: string, isNested: boolean,
    children: Map<string, Tweet[]>, visited: Set<string>, rows: ThreadReplyRow[]): void {
    const pending: PendingReply[] = [new PendingReply(reply, depth, parentHandle, isNested)];
    while (pending.length > 0) {
      const current: PendingReply | undefined = pending.pop();
      if (current === undefined || visited.has(current.tweet.id)) { continue; }
      visited.add(current.tweet.id);
      rows.push({ tweet: current.tweet, depth: current.depth, replyingToUsername: current.handle,
        isNestedReply: current.nested, connectAbove: false, connectBelow: false });
      const descendants: Tweet[] = children.get(current.tweet.id) ?? [];
      // A stack visits siblings in the same source order as the old recursion.
      for (let i: number = descendants.length - 1; i >= 0; i--) {
        const child: Tweet = descendants[i];
        if (visited.has(child.id)) { continue; }
        const handle: string = child.replyToUsername !== undefined && child.replyToUsername.length > 0 ?
          child.replyToUsername : current.tweet.author.username;
        pending.push(new PendingReply(child, Math.min(current.depth + 1, 2), handle, true));
      }
    }
  }
}
