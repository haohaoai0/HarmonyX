import { MediaAttachment, Tweet, TweetAuthor, TweetMetrics } from '../models/Tweet';
import { PostDisclosure, PostPresentation } from '../models/PostContent';
import { XXAuthPromotionMedia, XXAuthPromotionPost } from '../services/XXAuthPromotionPost';
import { parseRecommendationDescription } from '../services/XXAuthRecommendation';

// One media entry after the card resolved its bytes: images become local files,
// videos keep their remote stream and use a local poster frame.
export class XXAuthPromotionAsset {
  url: string = '';
  poster: string = '';
}

// The market screenshots are portrait phone captures; the fixed ratio keeps the
// media grid of a normal post laid out before the bytes arrive.
const MEDIA_WIDTH: number = 1080;
const MEDIA_HEIGHT: number = 1920;
const VIDEO_WIDTH: number = 1920;
const VIDEO_HEIGHT: number = 1080;
const PROMOTION_AUTHOR_ID: string = 'xxauth-promotion';

function promotionId(post: XXAuthPromotionPost): string {
  let hash: number = 2166136261;
  for (let i: number = 0; i < post.fingerprint.length; i++) {
    hash = hash ^ post.fingerprint.charCodeAt(i);
    hash = (hash * 16777619) >>> 0;
  }
  return 'promotion-' + (hash >>> 0).toString(16);
}

// The body keeps the // highlight pairs in the record; the post card shows the
// plain reading text.
export function promotionText(post: XXAuthPromotionPost): string {
  return parseRecommendationDescription(post.content)
    .map((segment): string => segment.text).join('');
}

function handle(post: XXAuthPromotionPost): string {
  return post.handle.replace(/^@/, '');
}

function author(post: XXAuthPromotionPost, avatarUri: string): TweetAuthor {
  return {
    id: PROMOTION_AUTHOR_ID,
    name: post.name,
    username: handle(post),
    avatarColor: '#007DFF',
    avatarUrl: avatarUri.length > 0 ? avatarUri : post.avatarUrl,
    verified: post.verified,
    verifiedType: 'Blue',
    avatarShape: 'Circle',
    following: false
  };
}

function attachment(media: XXAuthPromotionMedia, resolved: XXAuthPromotionAsset,
  index: number): MediaAttachment {
  const source: string = resolved.url.length > 0 ? resolved.url : media.url;
  const poster: string = resolved.poster.length > 0 ? resolved.poster : source;
  return {
    id: PROMOTION_AUTHOR_ID + '-media-' + index.toString(),
    type: media.video ? 'video' : 'photo',
    mediaUrl: source,
    feedUrl: source,
    previewUrl: poster,
    width: media.width > 0 ? media.width : (media.video ? VIDEO_WIDTH : MEDIA_WIDTH),
    height: media.height > 0 ? media.height : (media.video ? VIDEO_HEIGHT : MEDIA_HEIGHT),
    altText: '',
    durationMs: media.durationMs,
    showDurationBadge: media.video && media.durationMs > 0
  };
}

function adPresentation(): PostPresentation {
  const presentation: PostPresentation = new PostPresentation();
  const label: PostDisclosure = new PostDisclosure();
  label.kind = 'ad';
  presentation.labels = [label];
  return presentation;
}

// A promotion row is an ordinary Tweet whose values come from the remote
// records, so the feed renders it with the same card, metrics and media grid.
export function promotionTweet(post: XXAuthPromotionPost, avatarUri: string,
  resolved: XXAuthPromotionAsset[], createdAt: string = '', tablet: boolean = false): Tweet {
  const media: XXAuthPromotionMedia[] = tablet && post.mediaPad.length > 0 ? post.mediaPad : post.media;
  const attachments: MediaAttachment[] = [];
  for (let i: number = 0; i < media.length; i++) {
    attachments.push(attachment(media[i],
      i < resolved.length ? resolved[i] : new XXAuthPromotionAsset(), i));
  }
  const metrics: TweetMetrics = { replyCount: 0, repostCount: 0, likeCount: 0, viewCount: 0 };
  return {
    id: promotionId(post),
    author: author(post, avatarUri),
    text: promotionText(post),
    createdAt: createdAt,
    metrics: metrics,
    liked: false,
    reposted: false,
    attachments: attachments,
    presentation: adPresentation()
  };
}

// Placeholder until the remote values and their cached images are ready, so the
// card never mounts with an undefined tweet.
export function emptyPromotionTweet(): Tweet {
  const author: TweetAuthor = {
    id: PROMOTION_AUTHOR_ID, name: '', username: '', avatarColor: '#007DFF',
    avatarUrl: '', verified: false, verifiedType: 'Blue', avatarShape: 'Circle', following: false
  };
  const metrics: TweetMetrics = { replyCount: 0, repostCount: 0, likeCount: 0, viewCount: 0 };
  return {
    id: 'promotion-empty', author: author, text: '', createdAt: '',
    metrics: metrics, liked: false, reposted: false, attachments: [], presentation: adPresentation()
  };
}
