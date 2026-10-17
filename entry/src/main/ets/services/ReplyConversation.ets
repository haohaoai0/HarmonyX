import type { Tweet } from '../models/Tweet';

export class ReplyConversation {
  static attach(tweets: Tweet[], extra: Tweet[] = []): Tweet[] {
    const byId: Map<string, Tweet> = new Map<string, Tweet>();
    for (let i: number = 0; i < extra.length; i++) {
      const context: Tweet[] = extra[i].replyContext ?? [];
      for (let j: number = 0; j < context.length; j++) {
        byId.set(context[j].id, context[j]);
      }
      byId.set(extra[i].id, extra[i]);
    }
    for (let i: number = 0; i < tweets.length; i++) {
      const context: Tweet[] = tweets[i].replyContext ?? [];
      for (let j: number = 0; j < context.length; j++) {
        byId.set(context[j].id, context[j]);
      }
    }
    for (let i: number = 0; i < tweets.length; i++) {
      byId.set(tweets[i].id, tweets[i]);
    }
    for (let i: number = 0; i < tweets.length; i++) {
      tweets[i].replyContext = ReplyConversation.ancestors(tweets[i], byId);
    }
    return tweets;
  }

  // Only collapse posts inside the same server-supplied conversation module.
  // Separate timeline entries can legitimately repeat an original post.
  static module(tweets: Tweet[]): Tweet[] {
    ReplyConversation.attach(tweets);
    const parents: Set<string> = new Set<string>();
    for (let i: number = 0; i < tweets.length; i++) {
      const context: Tweet[] = tweets[i].replyContext ?? [];
      for (let j: number = 0; j < context.length; j++) {
        parents.add(context[j].id);
      }
    }
    return tweets.filter((tweet: Tweet): boolean => !parents.has(tweet.id));
  }

  private static ancestors(tweet: Tweet, byId: Map<string, Tweet>): Tweet[] {
    const context: Tweet[] = [];
    const visited: Set<string> = new Set<string>();
    visited.add(tweet.id);
    let parentId: string = tweet.replyToTweetId ?? '';
    while (parentId.length > 0) {
      if (visited.has(parentId)) {
        return [];
      }
      visited.add(parentId);
      const parent: Tweet | undefined = byId.get(parentId);
      if (parent === undefined) {
        break;
      }
      context.unshift(ReplyConversation.flat(parent));
      parentId = parent.replyToTweetId ?? '';
    }
    return context;
  }

  static flat(tweet: Tweet): Tweet {
    return {
      id: tweet.id, author: tweet.author, text: tweet.text, language: tweet.language,
      createdAt: tweet.createdAt, metrics: tweet.metrics, liked: tweet.liked,
      reposted: tweet.reposted, bookmarked: tweet.bookmarked, isReply: tweet.isReply,
      replyToTweetId: tweet.replyToTweetId, replyToUsername: tweet.replyToUsername,
      conversationId: tweet.conversationId,
      isRepost: tweet.isRepost, repostAuthor: tweet.repostAuthor, repostText: tweet.repostText,
      quotedTweet: tweet.quotedTweet, attachments: tweet.attachments,
      pinned: tweet.pinned, article: tweet.article, poll: tweet.poll, card: tweet.card
    };
  }
}
