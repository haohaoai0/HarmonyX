import type { Tweet, MediaAttachment } from '../models/Tweet';

export class VideoDanmakuComment {
  id: string;
  text: string;
  own: boolean;
  language: string;
  originalText: string;

  constructor(id: string, text: string, own: boolean = false, language: string = '', originalText: string = text) {
    this.id = id;
    this.text = text;
    this.own = own;
    this.language = language;
    this.originalText = originalText;
  }
}

// Replies have no video timestamps. They are distributed over playback rather
// than represented as a timestamped Bilibili danmaku service.
export class VideoDanmaku {
  static commentText(text: string): string {
    return text.replace(/https?:\/\/\S+/g, '').replace(/^(@[A-Za-z0-9_]+\s*)+/, '')
      .replace(/\s+/g, ' ').trim();
  }

  static comments(replies: Tweet[], rootId: string, verifiedThreadReplies: boolean = false): VideoDanmakuComment[] {
    const result: VideoDanmakuComment[] = [];
    const ids: Set<string> = new Set<string>();
    for (const reply of replies) {
      const parent: string = reply.replyToTweetId ?? '';
      const conversation: string = reply.conversationId ?? '';
      if (reply.id === rootId || ids.has(reply.id) ||
        (!verifiedThreadReplies && parent !== rootId && conversation !== rootId)) { continue; }
      const text: string = VideoDanmaku.commentText(reply.text);
      if (text.length === 0) { continue; }
      ids.add(reply.id);
      result.push(new VideoDanmakuComment(reply.id, text, false, reply.language ?? '', reply.text));
      if (result.length >= 100) { break; }
    }
    return result;
  }

  static episodeIndex(videos: MediaAttachment[], mediaId: string): number {
    const index: number = videos.findIndex((video: MediaAttachment): boolean => video.id === mediaId);
    return index < 0 ? 0 : index;
  }
}
