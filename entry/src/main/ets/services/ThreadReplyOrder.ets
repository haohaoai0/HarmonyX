import type { Tweet } from '../models/Tweet';

export interface ThreadReplyRow {
  tweet: Tweet;
  depth: number;
  replyingToUsername: string;
  isNestedReply: boolean;
  connectAbove: boolean;
  connectBelow: boolean;
}

// Keep direct comments at the top level and place replies immediately after
// their loaded parent. A missing parent leaves the reply visible on its own.
export class ThreadReplyOrder {
  static order(rootId: string, replies: Tweet[]): ThreadReplyRow[] {
    const rows: ThreadReplyRow[] = [];
    const visited: Set<string> = new Set<string>();
    for (let i: number = 0; i < replies.length; i++) {
      if (replies[i].replyToTweetId === rootId) {
        ThreadReplyOrder.append(replies[i], 0, '', false, replies, visited, rows);
      }
    }
    for (let i: number = 0; i < replies.length; i++) {
      const reply: Tweet = replies[i];
      if (!visited.has(reply.id) && reply.id !== rootId) {
        const handle: string = reply.replyToUsername ?? '';
        const isNested: boolean = reply.replyToTweetId !== undefined &&
          reply.replyToTweetId.length > 0 && reply.replyToTweetId !== rootId;
        ThreadReplyOrder.append(reply, 0, handle, isNested, replies, visited, rows);
      }
    }
    for (let i: number = 0; i < rows.length; i++) {
      rows[i].connectAbove = i > 0 && rows[i].tweet.replyToTweetId === rows[i - 1].tweet.id;
      rows[i].connectBelow = i + 1 < rows.length && rows[i + 1].tweet.replyToTweetId === rows[i].tweet.id;
    }
    return rows;
  }

  private static append(reply: Tweet, depth: number, parentHandle: string, isNested: boolean,
    replies: Tweet[], visited: Set<string>, rows: ThreadReplyRow[]): void {
    if (visited.has(reply.id)) {
      return;
    }
    visited.add(reply.id);
    rows.push({ tweet: reply, depth: depth, replyingToUsername: parentHandle, isNestedReply: isNested,
      connectAbove: false, connectBelow: false });
    for (let i: number = 0; i < replies.length; i++) {
      const child: Tweet = replies[i];
      if (child.replyToTweetId === reply.id && !visited.has(child.id)) {
        const handle: string = child.replyToUsername !== undefined && child.replyToUsername.length > 0 ?
          child.replyToUsername : reply.author.username;
        ThreadReplyOrder.append(child, Math.min(depth + 1, 2), handle, true,
          replies, visited, rows);
      }
    }
  }
}
