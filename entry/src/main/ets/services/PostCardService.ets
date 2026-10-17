import type { CommunityRow } from '../models/Community';
import type { ListRow, MediaAttachment, TweetLinkCard, UserProfile } from '../models/Tweet';
import { PostCardPerson, PostCardPart } from '../models/PostContent';
import { XPrivateResult, xPrivateClient } from './XPrivateClient';
import { XRichCardParser as Card } from './XRichCardParser';
import { XListParser } from './XListParser';
import { XCommunityParser } from './XCommunityParser';
import { XUserParser } from './XUserParser';
import { XSpaceParser } from './XSpaceParser';

export class PostCardLoad {
  card: TweetLinkCard;
  status: number = 0;
  error: string = '';
  constructor(card: TweetLinkCard) { this.card = card; }
}
class CardCacheEntry {
  expiresAt: number = 0;
  pending: Promise<PostCardLoad>;
  constructor(pending: Promise<PostCardLoad>) { this.pending = pending; this.expiresAt = Date.now() + 120000; }
}
class PostCardService {
  private cache: Map<string, CardCacheEntry> = new Map<string, CardCacheEntry>();
  private generation: number = -1;
  async hydrate(card: TweetLinkCard, fresh: boolean = false): Promise<PostCardLoad> {
    const generation: number = xPrivateClient.sessionGeneration();
    if (this.generation !== generation) { this.cache.clear(); this.generation = generation; }
    const cached: CardCacheEntry | undefined = this.cache.get(card.url);
    if (!fresh && cached !== undefined && cached.expiresAt > Date.now()) { return cached.pending; }
    if (this.cache.size >= 64) { this.cache.clear(); }
    const pending: Promise<PostCardLoad> = this.load(card, generation);
    this.cache.set(card.url, new CardCacheEntry(pending));
    return pending;
  }
  private async load(original: TweetLinkCard, generation: number): Promise<PostCardLoad> {
    const card: TweetLinkCard = JSON.parse(JSON.stringify(original)) as TweetLinkCard;
    const out: PostCardLoad = new PostCardLoad(card);
    const part: PostCardPart | undefined = card.content?.slides[0]?.parts[0];
    if (part === undefined || !xPrivateClient.isSignedIn()) { return out; }
    try {
      let result: XPrivateResult | undefined = undefined;
      const path: string = card.url.replace(/^https?:\/\/[^/]+/, '').split(/[?#]/)[0];
      if (card.kind === 'list') {
        const id: string = path.split('/')[3] ?? ''; result = await xPrivateClient.listDetail(id);
        const list: ListRow | null = result.ok ? XListParser.detail(result.body, id) : null;
        if (list !== null) {
          part.title = list.name; part.text = list.description; part.imageUrl = list.bannerUrl;
          part.memberCount = list.memberCount; part.subtitle = list.ownerName;
          const person: PostCardPerson = new PostCardPerson(); person.id = list.ownerId; person.name = list.ownerName;
          person.username = list.ownerUsername; person.avatarUrl = list.ownerAvatarUrl; person.verifiedType = list.ownerVerifiedType ?? ''; person.avatarShape = list.ownerAvatarShape ?? ''; part.people = [person];
        }
      } else if (card.kind === 'community') {
        const id: string = path.split('/')[3] ?? ''; result = await xPrivateClient.communityInfo(id);
        const community: CommunityRow | undefined = result.ok ? XCommunityParser.parse(result.body)?.communities.find(
          (row: CommunityRow): boolean => row.id === id) : undefined;
        if (community !== undefined) {
          part.title = community.name; part.text = community.description; part.imageUrl = community.bannerUrl;
          part.memberCount = community.memberCount; part.people = [];
          const members = community.members ?? [];
          for (let i: number = 0; i < members.length; i++) {
            const person: PostCardPerson = new PostCardPerson(); person.id = members[i].id; person.name = members[i].name;
            person.username = members[i].username; person.avatarUrl = members[i].avatarUrl ?? ''; person.verifiedType = members[i].verifiedType ?? ''; person.avatarShape = members[i].avatarShape ?? ''; part.people.push(person);
          }
        }
      } else if (card.kind === 'profile') {
        result = await xPrivateClient.userByScreenName(path.substring(1));
        const profile: UserProfile | null = result.ok ? XUserParser.parse(result.body) : null;
        if (profile !== null) {
          part.title = profile.name; part.text = profile.description; part.iconUrl = profile.avatarUrl ?? ''; part.verifiedType = profile.verifiedType ?? ''; part.avatarShape = profile.avatarShape ?? '';
          part.imageUrl = profile.bannerUrl ?? ''; part.subtitle = '@' + profile.username; part.memberCount = profile.followersCount;
        }
      } else if (card.kind === 'broadcast') {
        result = await xPrivateClient.postContent('BroadcastQuery', card.content?.broadcastId ?? '');
        if (result.ok) {
          const broadcast: Record<string, Object> = Card.object(Card.object((JSON.parse(result.body) as Record<string, Object>)['data'])['broadcast']);
          if (Object.keys(broadcast).length > 0 && card.content !== undefined) {
            card.content.state = Card.text(broadcast['state']);
            card.content.mediaKey = Card.text(broadcast['media_key']) || card.content.mediaKey;
            card.content.viewers = Card.number(broadcast['total_watching'], -1);
            part.title = Card.text(broadcast['title']) || part.title;
            part.imageUrl = Card.url(broadcast['image_url'] ?? broadcast['thumbnail_url']) || part.imageUrl;
            if (card.content.mediaKey.length > 0) {
              const stream: XPrivateResult = await xPrivateClient.spaceStream(card.content.mediaKey);
              if (!stream.ok) { out.status = stream.status; out.error = stream.errorText; }
              const url: string = stream.ok ? XSpaceParser.streamUrl(stream.body) : '';
              const media: MediaAttachment | undefined = url.length > 0 ? Card.media({ 'type': 'video', 'stream_url': url,
                'media_url_https': part.imageUrl }, card.content.mediaKey) : undefined;
              if (media !== undefined) { part.media = [media]; }
            }
          } else { out.error = 'missing_content'; }
        }
      }
      if (result !== undefined && !result.ok) { out.status = result.status; out.error = result.errorText; }
    } catch (error) { out.error = 'content_failed'; }
    if (generation !== xPrivateClient.sessionGeneration()) { return new PostCardLoad(original); }
    return out;
  }
}
export const postCardService: PostCardService = new PostCardService();
