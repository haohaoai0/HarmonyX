import type { Tweet } from '../models/Tweet';
import { ReplyConversation } from './ReplyConversation';

// Profile tabs keep separate cursors, but all append with the same identity
// rule because X can repeat a post at a page boundary.
export class ProfileTweetPage {
  static merge(tab: number, existing: Tweet[], incoming: Tweet[], replace: boolean): Tweet[] {
    const combined: Tweet[] = [];
    if (!replace) {
      for (let i: number = 0; i < existing.length; i++) {
        combined.push(existing[i]);
      }
    }
    // Capture full parent posts before the Replies/Media tab removes context
    // rows which do not themselves match its filter.
    const contextual: Tweet[] = ReplyConversation.attach(incoming, combined);
    for (let i: number = 0; i < contextual.length; i++) {
      const tweet: Tweet = contextual[i];
      if (tab === 1 && tweet.isReply !== true) {
        continue;
      }
      if (tab === 2 && (tweet.attachments === undefined || tweet.attachments.length === 0)) {
        continue;
      }
      let duplicate: boolean = false;
      for (let j: number = 0; j < combined.length; j++) {
        if (combined[j].id === tweet.id) {
          duplicate = true;
          break;
        }
      }
      if (!duplicate) {
        combined.push(tweet);
      }
    }
    return combined;
  }
}
