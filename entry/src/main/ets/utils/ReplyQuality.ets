import type { Tweet } from '../models/Tweet';

export class ReplyQualityAssessment {
  reasons: string[] = [];
}

class ReplyQualityFeatures {
  tweet: Tweet;
  fingerprint: string = '';
  links: number = 0;
  promotion: boolean = false;
  contact: boolean = false;
  constructor(tweet: Tweet) {
    this.tweet = tweet;
    const text: string = tweet.text.toLowerCase();
    const urls: RegExpMatchArray | null = text.match(/https?:\/\/[^\s<>]+/g);
    this.links = urls === null ? 0 : new Set<string>(urls).size;
    this.fingerprint = text.replace(/https?:\/\/[^\s<>]+/g, ' ').replace(/(^|\s)@[a-z0-9_]+/g, ' ')
      .replace(/\s+/g, ' ').trim();
    this.promotion = /稳赚|日赚|返利|免费领取|代办|空投|guaranteed\s+(profit|returns)|earn\s+\$|double\s+your|crypto\s+giveaway|investment\s+opportunity/.test(text);
    this.contact = /加我|加群|私信我|主页链接|联系我|\b(dm\s+me|telegram|whatsapp|link\s+in\s+(my\s+)?bio|check\s+my\s+profile)\b|https?:\/\/(t\.me|wa\.me|chat\.whatsapp\.com)\//.test(text);
  }
}

// Conservative, local reading aid. No account-age/follower/verification/like
// threshold, no AI-authorship claim, and no per-reply network requests.
export class ReplyQuality {
  static analyze(replies: Tweet[], rootAuthorId: string, viewerId: string,
    allowedAuthorIds: string[]): Map<string, ReplyQualityAssessment> {
    const features: ReplyQualityFeatures[] = [];
    const byText: Map<string, Set<string>> = new Map();
    const byAuthorText: Map<string, number> = new Map();
    const seen: Set<string> = new Set();
    for (const tweet of replies) {
      if (seen.has(tweet.id)) { continue; }
      seen.add(tweet.id);
      const item: ReplyQualityFeatures = new ReplyQualityFeatures(tweet);
      features.push(item);
      if (item.fingerprint.length < 24) { continue; }
      const authors: Set<string> = byText.get(item.fingerprint) ?? new Set<string>();
      authors.add(tweet.author.id);
      byText.set(item.fingerprint, authors);
      const key: string = tweet.author.id + '\n' + item.fingerprint;
      byAuthorText.set(key, (byAuthorText.get(key) ?? 0) + 1);
    }
    const out: Map<string, ReplyQualityAssessment> = new Map();
    for (const item of features) {
      const tweet: Tweet = item.tweet;
      if (tweet.author.id === rootAuthorId || (viewerId.length > 0 && tweet.author.id === viewerId) ||
        tweet.author.following === true || allowedAuthorIds.indexOf(tweet.author.id) >= 0) { continue; }
      const copies: number = byAuthorText.get(tweet.author.id + '\n' + item.fingerprint) ?? 0;
      const authors: number = byText.get(item.fingerprint)?.size ?? 0;
      const repeatedAuthor: boolean = item.fingerprint.length >= 24 && copies >= 3;
      const duplicatedPromotion: boolean = item.fingerprint.length >= 32 && authors >= 3 &&
        (item.links > 0 || item.promotion || item.contact);
      const solicitation: boolean = item.links > 0 && item.promotion && item.contact;
      const linkFlood: boolean = item.links >= 3 && item.contact;
      if (!repeatedAuthor && !duplicatedPromotion && !solicitation && !linkFlood) { continue; }
      const assessment: ReplyQualityAssessment = new ReplyQualityAssessment();
      if (duplicatedPromotion) { assessment.reasons.push('duplicate'); }
      if (repeatedAuthor) { assessment.reasons.push('author_repeat'); }
      if (item.links >= 3) { assessment.reasons.push('links'); }
      if (item.promotion) { assessment.reasons.push('promotion'); }
      if (item.contact) { assessment.reasons.push('contact'); }
      out.set(tweet.id, assessment);
    }
    return out;
  }
}
