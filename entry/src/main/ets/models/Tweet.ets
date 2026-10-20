// Harmony X data models.
// Mirrors a subset of X API v2 objects so the UI works identically
// against live data and the offline mock fallback.

import type { ArticleBlock, PostCardData, PostPresentation } from './PostContent';

export interface TweetAuthor {
  id: string;
  name: string;
  username: string;
  avatarColor: string;
  avatarUrl?: string;
  verified: boolean;
  verifiedType?: string;
  avatarShape?: string;
  following?: boolean;
}

export interface TweetMetrics {
  replyCount: number;
  repostCount: number;
  likeCount: number;
  viewCount: number;
  // Missing counters are unknown, rather than a fabricated zero.
  bookmarkCount?: number;
  quoteCount?: number;
}

export interface VideoRendition {
  url: string;
  bitrate: number;
  width: number;
  height: number;
}

export interface MediaAttachment {
  id: string;
  type: string;
  // Highest-quality MP4, or HLS when no MP4 exists (still image for a photo).
  // Fullscreen playback and sharing use this one.
  mediaUrl: string;
  // Lightest usable MP4 rendition, with an HLS fallback. A feed cell is only ~228vp tall, so
  // starting on this one is what makes an inline video appear quickly; empty
  // when the source exposes a single rendition or the media is a photo.
  feedUrl: string;
  // X video renditions ordered from the lowest MP4 bitrate to the highest,
  // with an HLS URL last when the post exposes one. Playback uses these as
  // recovery sources when the preferred rendition cannot be opened.
  videoVariantUrls?: string[];
  // The bitrate and encoded dimensions let quality choices select a specific
  // rendition instead of collapsing the whole list into two URLs.
  videoVariants?: VideoRendition[];
  // X supplies duration in its video metadata. Unknown duration is zero.
  durationMs?: number;
  // Opt-in length chip on the tile; only promoted media turns it on, so the
  // ordinary feed keeps its current look.
  showDurationBadge?: boolean;
  previewUrl: string;
  width: number;
  height: number;
  altText: string;
  // X marks the enclosing post as possibly sensitive. Keeping the marker on
  // each attachment lets media surfaces avoid mounting the remote resource.
  sensitive?: boolean;
}

export interface QuotedTweet {
  id: string;
  isReply?: boolean;
  replyToTweetId?: string;
  replyToUsername?: string;
  author: TweetAuthor;
  text: string;
  // Original API timestamp; relative/date labels are resolved by the UI.
  createdAt: string;
  editHistoryIds?: string[];
  possiblySensitive?: boolean;
  attachments?: MediaAttachment[];
  poll?: TweetPoll;
  card?: TweetLinkCard;
  article?: ProfileArticle;
  presentation?: PostPresentation;
}

export interface PollOption {
  id: string;
  label: string;
  votes: number;
  imageUrl: string;
}

// CAPI card identity is kept separate from v2's poll id. V2 exposes results,
// while a signed-in private session supplies the card's voting endpoint.
export interface TweetPoll {
  id: string;
  cardUri: string;
  cardName: string;
  api: string;
  options: PollOption[];
  endsAt: string;
  durationMinutes: number;
  countsAreFinal: boolean;
  countsKnown: boolean;
  selectedChoice: string;
  imageUrl: string;
  media?: MediaAttachment[];
}

export interface TweetLinkCard {
  kind: string;
  title: string;
  description: string;
  url: string;
  domain: string;
  imageUrl: string;
  content?: PostCardData;
}

export interface Tweet {
  id: string;
  author: TweetAuthor;
  text: string;
  language?: string;
  editHistoryIds?: string[];
  // Original API timestamp, including the time and zone when available.
  createdAt: string;
  metrics: TweetMetrics;
  liked: boolean;
  reposted: boolean;
  // Viewer-scoped state returned by private timelines.
  bookmarked?: boolean;
  // Timeline-scoped kind flags used by reading filters. They are best-effort:
  // payloads that do not expose the metadata leave them false/undefined.
  isReply?: boolean;
  // Direct parent of this reply, plus the handle X says it addresses. In a
  // thread, a parent matching the focal post is a comment; a parent matching
  // another loaded reply is a nested reply.
  replyToTweetId?: string;
  replyToUsername?: string;
  // Root conversation supplied by X, used to keep suggested posts out of replies.
  conversationId?: string;
  // Ancestors in reading order, ending with the direct parent. Each context
  // post is a complete, flat Tweet so caches never contain recursive graphs.
  replyContext?: Tweet[];
  isRepost?: boolean;
  // Timeline context is separate from the original post and its author.
  repostAuthor?: TweetAuthor;
  repostText?: string;
  quotedTweet?: QuotedTweet;
  possiblySensitive?: boolean;
  attachments?: MediaAttachment[];
  pinned?: boolean;
  communityId?: string;
  communityName?: string;
  article?: ProfileArticle;
  poll?: TweetPoll;
  card?: TweetLinkCard;
  presentation?: PostPresentation;
  feedbackKeys?: string[];
  feedbackActions?: TweetFeedbackAction[];
}

export interface TweetFeedbackAction {
  key: string;
  type: string;
  prompt: string;
  confirmation: string;
  url: string;
}

export interface ProfileArticle {
  id: string;
  title: string;
  previewText: string;
  coverUrl: string;
  blocks?: ArticleBlock[];
  plainText?: string;
}

export interface DirectMessage {
  id: string;
  from: string;
  preview: string;
  time: string;
  unread: number;
  avatarUrl?: string;
  verifiedType?: string;
  avatarShape?: string;
  // Private inbox rows add the conversation-scoped fields below. The official
  // DM event fallback leaves them empty, so callers must check
  // `conversationId` before opening a thread.
  conversationId?: string;
  username?: string;
  group?: boolean;
  groupNameCipher?: string;
  groupAvatarCipher?: string;
  muted?: boolean;
  timestampMs?: number;
  participantIds?: string[];
  // XChat's lower sequence bound for the thread. The conversation page query
  // rejects an empty/zero pair with a reversed-range error.
  latestSequenceId?: string;
  hidden?: boolean;
  pinned?: boolean;
}

// A native DM row. XChat text is populated only after verified local decryption.
export interface DmMessage {
  id: string;
  sequenceId?: string;
  conversationId: string;
  senderId: string;
  senderName: string;
  senderUsername: string;
  senderAvatarUrl: string;
  senderVerifiedType?: string;
  senderAvatarShape?: string;
  text: string;
  time: string;
  timestampMs: number;
  outgoing: boolean;
  encrypted: boolean;
  read?: boolean;
  attachments?: DmAttachment[];
  keyVersion?: string;
  rawEvent?: string;
  reply?: DmReply;
  reactions?: DmReaction[];
}

export interface DmReply {
  sequenceId: string;
  senderId: string;
  senderName: string;
  text: string;
  attachments: DmAttachment[];
}

// Keep each sender's latest add/remove event, including tombstones. Polling
// and history pagination can replay events in a different order.
export interface DmReaction {
  emoji: string;
  senderId: string;
  sequenceId: string;
  active: boolean;
}

export interface DmAttachment {
  type: string;
  mediaHash: string;
  mediaType: number;
  filename: string;
  url: string;
  width: number;
  height: number;
  durationMs?: number;
}

export interface DmInboxPage {
  messages: DirectMessage[];
  nextToken: string;
}

export interface DmPage {
  messages: DmMessage[];
  minEntryId: string;
  maxEntryId: string;
}

export interface UserProfile {
  id: string;
  name: string;
  username: string;
  description: string;
  followersCount: number;
  followingCount: number;
  postCount: number;
  verified: boolean;
  // Viewer-scoped follow state from relationship_perspectives.
  following?: boolean;
  followedBy?: boolean;
  blocking?: boolean;
  avatarUrl?: string;
  bannerUrl?: string;
  verifiedType?: string;
  avatarShape?: string;
  createdAt?: string;
  location?: string;
  website?: string;
  muting?: boolean;
  notifications?: boolean;
}

// A row in a followers / following / muted / search-people list. The timeline
// carries the same User object as a profile, minus the profile-only fields.
export interface UserRow {
  id: string;
  name: string;
  username: string;
  avatarUrl: string;
  avatarColor: string;
  verified: boolean;
  verifiedType?: string;
  avatarShape?: string;
  bio: string;
  following: boolean;
  followedBy: boolean;
  bannerUrl?: string;
}

export interface UserListPage {
  users: UserRow[];
  nextToken: string;
}

// A row in the "my lists" timeline.
export interface ListRow {
  id: string;
  name: string;
  description: string;
  memberCount: number;
  following: boolean;
  ownerName: string;
  ownerUsername: string;
  ownerId: string;
  ownerAvatarUrl: string;
  ownerVerifiedType?: string;
  ownerAvatarShape?: string;
  bannerUrl: string;
  hasCustomBanner?: boolean;
  customBannerMediaId?: string;
  isPrivate: boolean;
  pinned: boolean;
  subscriberCount: number;
}

export interface ListPage {
  lists: ListRow[];
  nextToken: string;
}

export interface AppNotification {
  id: string;
  // Normalised action token: like | repost | follow | mention | reply | alert |
  // default. The UI maps it to a symbol, so X's raw icon name never leaks into
  // a comparison.
  kind: string;
  text: string;
  // Relative label ("2h") when the payload carries a timestamp, otherwise the
  // source's own text.
  time: string;
  timestampMs: number;
  // What the row points at. A row with a target post opens PostDetail; one with
  // only an account opens UserDetail.
  targetPostId: string;
  postText: string;
  authorId: string;
  authorName: string;
  authorUsername: string;
  authorAvatarUrl: string;
  authorVerifiedType?: string;
  authorAvatarShape?: string;
  // Present when the notification payload identifies a verified actor.
  fromVerifiedAccount?: boolean;
  // Thumbnail of the post the row points at, '' when the post has no media.
  imageUrl: string;
  imageIsVideo: boolean;
  // The timeline's unread boundary said this row is newer than the last seen
  // notification.
  unread: boolean;
  deepLink: string;
  // A bell notification can contain several posts. Preserve the entire group.
  targetPosts?: Tweet[];
  // Keep the notification sentence separate from the target post preview.
  actionText?: string;
  actors?: TweetAuthor[];
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
