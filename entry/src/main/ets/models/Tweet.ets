// Harmony X data models.
// Mirrors a subset of X API v2 objects so the UI works identically
// against live data and the offline mock fallback.

export interface TweetAuthor {
  id: string;
  name: string;
  username: string;
  avatarColor: string;
  verified: boolean;
}

export interface TweetMetrics {
  replyCount: number;
  repostCount: number;
  likeCount: number;
  viewCount: number;
}

export interface Tweet {
  id: string;
  author: TweetAuthor;
  text: string;
  createdAt: string;
  metrics: TweetMetrics;
  liked: boolean;
  reposted: boolean;
  // X API v2 includes entities/attachments; we keep a simple optional image hint.
  imageLabel?: string;
}

export interface DirectMessage {
  id: string;
  from: string;
  preview: string;
  time: string;
  unread: number;
}

export interface AppNotification {
  id: string;
  kind: string;
  text: string;
  time: string;
}

export function formatCount(n: number): string {
  if (n >= 1000000) {
    const v: number = n / 1000000;
    return (Math.round(v * 10) / 10).toString() + 'M';
  }
  if (n >= 1000) {
    const v: number = n / 1000;
    return (Math.round(v * 10) / 10).toString() + 'K';
  }
  return n.toString();
}
