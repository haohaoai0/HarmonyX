// Decodes the Explore operation, whose payload nests trends inside timeline
// entries and topic modules. Field names have moved between schema revisions,
// so the extractor looks for trend-shaped objects anywhere in the payload
// rather than following one fixed path.
import hilog from '@ohos.hilog';
import util from '@ohos.util';
import type { MediaAttachment, Tweet, UserRow } from '../models/Tweet';
import { XTimelineParser } from './XTimelineParser';

const DOMAIN = 0xFF00;
const TAG = 'HarmonyX-Explore';
const MAX_TRENDS = 24;

export class XExploreSection {
  id: string = '';
  timelineId: string = '';

  constructor(id: string, timelineId: string) {
    this.id = id;
    this.timelineId = timelineId;
  }
}

export class XExploreTrend {
  name: string = '';
  // SearchTimeline should receive the query encoded by Explore rather than
  // rebuilding one from the display title. AI/event trends only expose a
  // trending id, so those deliberately fall back to the visible name.
  query: string = '';
  context: string = '';
  url: string = '';
  avatarUrls: string[] = [];
  isAiTrend: boolean = false;
}

export class XExploreHero {
  eventId: string = '';
  title: string = '';
  description: string = '';
  context: string = '';
  time: string = '';
  imageUrl: string = '';
  authorName: string = '';
  authorAvatarUrl: string = '';
  url: string = '';
  promoted: boolean = false;
  // Event summaries can carry a complete Tweet media entity. Keep the parsed
  // post instead of flattening it to its poster image, otherwise promoted
  // videos become indistinguishable from a static hero image.
  mediaTweet: Tweet | null = null;
}

export class XExploreFrameTile {
  id: string = '';
  status: string = '';
  schedule: string = '';
  teamOne: string = '';
  teamTwo: string = '';
  imageOne: string = '';
  imageTwo: string = '';
  scoreOne: string = '';
  scoreTwo: string = '';
  destinationUrl: string = '';
}

export class XExploreFrame {
  // banner | carousel
  variant: string = 'carousel';
  title: string = '';
  subtitle: string = '';
  height: number = 156;
  imageUrls: string[] = [];
  destinationUrl: string = '';
  tiles: XExploreFrameTile[] = [];
}

export class XExploreTimelineCard {
  // hero | frame | trend | users | tweets
  kind: string = '';
  key: string = '';
  title: string = '';
  footerText: string = '';
  footerUrl: string = '';
  hero: XExploreHero | null = null;
  frame: XExploreFrame | null = null;
  trends: XExploreTrend[] = [];
  users: UserRow[] = [];
  tweets: Tweet[] = [];
}

export class XExploreParser {
  // Preserves the order and grouping of X's timeline entries. The Explore
  // surfaces are not uniform: For You mixes a hero, frames, trends, a user
  // module and a post module, while News/Sports/Entertainment can be a single
  // trend module. Rendering the parsed cards is therefore the only way to
  // represent all of those payloads without inventing a shape.
  static parseTimelineCards(body: string): XExploreTimelineCard[] {
    const out: XExploreTimelineCard[] = [];
    try {
      const json: Record<string, Object> = JSON.parse(body) as Record<string, Object>;
      const data: Record<string, Object> = XExploreParser.obj(json, 'data');
      const timeline: Record<string, Object> = XExploreParser.findTimeline(data, 0);
      const instructions: Array<Record<string, Object>> =
        XExploreParser.arr(timeline, 'instructions');
      for (let i: number = 0; i < instructions.length; i++) {
        const entries: Array<Record<string, Object>> =
          XExploreParser.arr(instructions[i], 'entries');
        for (let e: number = 0; e < entries.length; e++) {
          const card: XExploreTimelineCard | null =
            XExploreParser.cardFromEntry(entries[e], out.length);
          if (card !== null) {
            out.push(card);
          }
          const moduleCards: XExploreTimelineCard[] =
            XExploreParser.moduleCards(entries[e], out.length);
          for (let m: number = 0; m < moduleCards.length; m++) {
            out.push(moduleCards[m]);
          }
        }
      }
      const kinds: string[] = [];
      for (let i: number = 0; i < out.length; i++) {
        kinds.push(out[i].kind);
      }
      hilog.info(DOMAIN, TAG, 'timeline cards %{public}d: %{public}s',
        out.length, kinds.join(','));
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'timeline card parse failed: %{public}s', JSON.stringify(e));
    }
    return out;
  }

  static parseTrendItems(body: string): XExploreTrend[] {
    const out: XExploreTrend[] = [];
    try {
      const json: Object = JSON.parse(body) as Object;
      XExploreParser.collectTrendItems(json, out, 0);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'trend item parse failed: %{public}s', JSON.stringify(e));
    }
    return XExploreParser.dedupeTrendItems(out);
  }

  static parseHero(body: string): XExploreHero | null {
    try {
      const json: Record<string, Object> = JSON.parse(body) as Record<string, Object>;
      return XExploreParser.findHero(json, 0);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'hero parse failed: %{public}s', JSON.stringify(e));
      return null;
    }
  }

  static parseFrameCount(body: string): number {
    try {
      const json: Object = JSON.parse(body) as Object;
      return XExploreParser.countFrames(json, 0);
    } catch (e) {
      return 0;
    }
  }

  static parseSections(body: string): XExploreSection[] {
    const out: XExploreSection[] = [];
    try {
      const json: Record<string, Object> = JSON.parse(body) as Record<string, Object>;
      const data: Record<string, Object> =
        XExploreParser.obj(json, 'data');
      const page: Record<string, Object> =
        XExploreParser.obj(data, 'explore_page');
      const pageBody: Record<string, Object> =
        XExploreParser.obj(page, 'body');
      const timelines: Array<Record<string, Object>> =
        XExploreParser.arr(pageBody, 'timelines');
      for (let i: number = 0; i < timelines.length; i++) {
        const row: Record<string, Object> = timelines[i];
        const id: string = String(row['id'] ?? '').trim();
        const timeline: Record<string, Object> = XExploreParser.obj(row, 'timeline');
        const timelineId: string = String(timeline['id'] ?? '').trim();
        if (id.length === 0 || timelineId.length === 0) {
          continue;
        }
        out.push(new XExploreSection(id, timelineId));
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'section parse failed: %{public}s', JSON.stringify(e));
    }
    return out;
  }

  static parseTrends(body: string): string[] {
    const out: string[] = [];
    try {
      const json: Object = JSON.parse(body) as Object;
      XExploreParser.collect(json, out, 0);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'trend parse failed: %{public}s', JSON.stringify(e));
      return [];
    }
    return XExploreParser.dedupe(out);
  }

  private static collect(node: Object, out: string[], depth: number): void {
    if (depth > 16 || out.length >= MAX_TRENDS * 3) {
      return;
    }
    if (node === null || node === undefined) {
      return;
    }
    if (node instanceof Array) {
      const items: Array<Object> = node as Array<Object>;
      for (let i: number = 0; i < items.length; i++) {
        XExploreParser.collect(items[i], out, depth + 1);
      }
      return;
    }
    if (typeof node !== 'object') {
      return;
    }
    const record: Record<string, Object> = node as Record<string, Object>;
    const typeName: string = String(record['__typename'] ?? '');
    if (typeName.indexOf('Trend') >= 0) {
      const label: string = XExploreParser.labelOf(record);
      if (label.length > 0) {
        out.push(label);
      }
      // A trend node owns its own subtree; descending would only revisit it.
      return;
    }
    const keys: string[] = Object.keys(record);
    for (let i: number = 0; i < keys.length; i++) {
      XExploreParser.collect(record[keys[i]], out, depth + 1);
    }
  }

  // A trend exposes its display text under one of several names depending on
  // the surface; the search query is the best fallback because tapping a trend
  // searches for it.
  private static labelOf(record: Record<string, Object>): string {
    const candidates: string[] = ['trend_name', 'name', 'query'];
    for (let i: number = 0; i < candidates.length; i++) {
      const value: Object | undefined = record[candidates[i]];
      if (value === undefined || value === null) {
        continue;
      }
      const text: string = String(value).trim();
      if (text.length > 0) {
        return text;
      }
    }
    return '';
  }

  private static dedupe(values: string[]): string[] {
    const seen: Map<string, boolean> = new Map();
    const out: string[] = [];
    for (let i: number = 0; i < values.length && out.length < MAX_TRENDS; i++) {
      const value: string = values[i];
      if (!seen.has(value)) {
        seen.set(value, true);
        out.push(value);
      }
    }
    return out;
  }

  private static collectTrendItems(node: Object, out: XExploreTrend[], depth: number): void {
    if (node === null || node === undefined || depth > 16) {
      return;
    }
    if (node instanceof Array) {
      const items: Array<Object> = node as Array<Object>;
      for (let i: number = 0; i < items.length; i++) {
        XExploreParser.collectTrendItems(items[i], out, depth + 1);
      }
      return;
    }
    if (typeof node !== 'object') {
      return;
    }
    const record: Record<string, Object> = node as Record<string, Object>;
    if (String(record['__typename'] ?? '') === 'TimelineTrend') {
      const item: XExploreTrend | null = XExploreParser.trendFromRecord(record);
      if (item !== null) {
        out.push(item);
      }
      return;
    }
    const keys: string[] = Object.keys(record);
    for (let i: number = 0; i < keys.length; i++) {
      XExploreParser.collectTrendItems(record[keys[i]], out, depth + 1);
    }
  }

  private static findHero(node: Object, depth: number): XExploreHero | null {
    if (node === null || node === undefined || depth > 16) {
      return null;
    }
    if (node instanceof Array) {
      const items: Array<Object> = node as Array<Object>;
      for (let i: number = 0; i < items.length; i++) {
        const found: XExploreHero | null = XExploreParser.findHero(items[i], depth + 1);
        if (found !== null) {
          return found;
        }
      }
      return null;
    }
    if (typeof node !== 'object') {
      return null;
    }
    const record: Record<string, Object> = node as Record<string, Object>;
    if (String(record['__typename'] ?? '') === 'TimelineEventSummary') {
      const hero: XExploreHero | null = XExploreParser.heroFromRecord(record);
      if (hero !== null) {
        return hero;
      }
    }
    const keys: string[] = Object.keys(record);
    for (let i: number = 0; i < keys.length; i++) {
      const found: XExploreHero | null = XExploreParser.findHero(record[keys[i]], depth + 1);
      if (found !== null) {
        return found;
      }
    }
    return null;
  }

  private static countFrames(node: Object, depth: number): number {
    if (node === null || node === undefined || depth > 16) {
      return 0;
    }
    if (node instanceof Array) {
      let count: number = 0;
      const items: Array<Object> = node as Array<Object>;
      for (let i: number = 0; i < items.length; i++) {
        count += XExploreParser.countFrames(items[i], depth + 1);
      }
      return count;
    }
    if (typeof node !== 'object') {
      return 0;
    }
    const record: Record<string, Object> = node as Record<string, Object>;
    let count: number = String(record['__typename'] ?? '') === 'TimelineFrame' ? 1 : 0;
    const keys: string[] = Object.keys(record);
    for (let i: number = 0; i < keys.length; i++) {
      count += XExploreParser.countFrames(record[keys[i]], depth + 1);
    }
    return count;
  }

  private static findTimeline(node: Object, depth: number): Record<string, Object> {
    if (node === null || node === undefined || depth > 8) {
      return {};
    }
    if (node instanceof Array) {
      const items: Array<Object> = node as Array<Object>;
      for (let i: number = 0; i < items.length; i++) {
        const found: Record<string, Object> = XExploreParser.findTimeline(items[i], depth + 1);
        if (Object.keys(found).length > 0) {
          return found;
        }
      }
      return {};
    }
    if (typeof node !== 'object') {
      return {};
    }
    const record: Record<string, Object> = node as Record<string, Object>;
    if (record['instructions'] instanceof Array) {
      return record;
    }
    const keys: string[] = Object.keys(record);
    for (let i: number = 0; i < keys.length; i++) {
      const found: Record<string, Object> = XExploreParser.findTimeline(record[keys[i]], depth + 1);
      if (Object.keys(found).length > 0) {
        return found;
      }
    }
    return {};
  }

  private static cardFromEntry(entry: Record<string, Object>, index: number): XExploreTimelineCard | null {
    const content: Record<string, Object> = XExploreParser.obj(entry, 'content');
    const type: string = String(content['__typename'] ?? content['entryType'] ?? '');
    if (type !== 'TimelineTimelineItem') {
      return null;
    }
    const item: Record<string, Object> = XExploreParser.obj(content, 'itemContent');
    const entryId: string = String(entry['entryId'] ?? entry['entry_id'] ?? '');
    return XExploreParser.cardFromItem(item, entryId.length > 0 ? entryId : 'card-' + index, '');
  }

  private static moduleCards(entry: Record<string, Object>, index: number): XExploreTimelineCard[] {
    const out: XExploreTimelineCard[] = [];
    const content: Record<string, Object> = XExploreParser.obj(entry, 'content');
    const type: string = String(content['__typename'] ?? content['entryType'] ?? '');
    if (type !== 'TimelineTimelineModule') {
      return out;
    }
    const header: Record<string, Object> = XExploreParser.obj(content, 'header');
    const footer: Record<string, Object> = XExploreParser.obj(content, 'footer');
    const title: string = String(header['text'] ?? '');
    const footerText: string = String(footer['text'] ?? '');
    const footerLandingUrl: Record<string, Object> = XExploreParser.obj(footer, 'landingUrl');
    const footerUrl: Record<string, Object> = XExploreParser.obj(footer, 'url');
    const footerDestination: string = String(footerLandingUrl['url'] ?? footerUrl['url'] ?? '');
    const entryId: string = String(entry['entryId'] ?? entry['entry_id'] ?? 'module-' + index);
    const trends: XExploreTrend[] = [];
    const users: UserRow[] = [];
    const tweets: Tweet[] = [];
    const items: Array<Record<string, Object>> = XExploreParser.arr(content, 'items');
    for (let i: number = 0; i < items.length; i++) {
      const item: Record<string, Object> = XExploreParser.obj(items[i], 'item');
      const itemContent: Record<string, Object> = XExploreParser.obj(item, 'itemContent');
      const itemType: string = String(itemContent['__typename'] ?? itemContent['itemType'] ?? '');
      if (itemType === 'TimelineTrend') {
        const trend: XExploreTrend | null = XExploreParser.trendFromRecord(itemContent);
        if (trend !== null) {
          trends.push(trend);
        }
      } else if (itemType === 'TimelineUser') {
        const user: UserRow | null = XTimelineParser.parseUserItemContent(itemContent);
        if (user !== null) {
          users.push(user);
        }
      } else if (itemType === 'TimelineTweet') {
        const tweet: Tweet | null = XTimelineParser.parseTweetItemContent(itemContent);
        if (tweet !== null) {
          tweets.push(tweet);
        }
      }
    }
    if (trends.length > 0) {
      const card: XExploreTimelineCard = XExploreParser.newCard('trend', entryId + '-trends');
      card.title = title;
      card.footerText = footerText;
      card.footerUrl = footerDestination;
      card.trends = trends;
      out.push(card);
    }
    if (users.length > 0) {
      const card: XExploreTimelineCard = XExploreParser.newCard('users', entryId + '-users');
      card.title = title;
      card.footerText = footerText;
      card.footerUrl = footerDestination;
      card.users = users;
      out.push(card);
    }
    if (tweets.length > 0) {
      const card: XExploreTimelineCard = XExploreParser.newCard('tweets', entryId + '-tweets');
      card.title = title;
      card.footerText = footerText;
      card.footerUrl = footerDestination;
      card.tweets = tweets;
      out.push(card);
    }
    return out;
  }

  private static cardFromItem(itemContent: Record<string, Object>, key: string,
    title: string): XExploreTimelineCard | null {
    const type: string = String(itemContent['__typename'] ?? itemContent['itemType'] ?? '');
    if (type === 'TimelineEventSummary') {
      const hero: XExploreHero | null = XExploreParser.heroFromRecord(itemContent);
      if (hero === null) {
        return null;
      }
      const card: XExploreTimelineCard = XExploreParser.newCard('hero', key);
      card.title = title;
      card.hero = hero;
      return card;
    }
    if (type === 'TimelineFrame') {
      const frame: XExploreFrame | null = XExploreParser.frameFromItem(itemContent, key);
      if (frame === null) {
        return null;
      }
      const card: XExploreTimelineCard = XExploreParser.newCard('frame', key);
      card.title = title;
      card.frame = frame;
      return card;
    }
    if (type === 'TimelineTrend') {
      const trend: XExploreTrend | null = XExploreParser.trendFromRecord(itemContent);
      if (trend === null) {
        return null;
      }
      const card: XExploreTimelineCard = XExploreParser.newCard('trend', key);
      card.title = title;
      card.trends = [trend];
      return card;
    }
    if (type === 'TimelineUser') {
      const user: UserRow | null = XTimelineParser.parseUserItemContent(itemContent);
      if (user === null) {
        return null;
      }
      const card: XExploreTimelineCard = XExploreParser.newCard('users', key);
      card.title = title;
      card.users = [user];
      return card;
    }
    if (type === 'TimelineTweet') {
      const tweet: Tweet | null = XTimelineParser.parseTweetItemContent(itemContent);
      if (tweet === null) {
        return null;
      }
      const card: XExploreTimelineCard = XExploreParser.newCard('tweets', key);
      card.title = title;
      card.tweets = [tweet];
      return card;
    }
    return null;
  }

  private static newCard(kind: string, key: string): XExploreTimelineCard {
    const card: XExploreTimelineCard = new XExploreTimelineCard();
    card.kind = kind;
    card.key = key;
    return card;
  }

  private static trendFromRecord(record: Record<string, Object>): XExploreTrend | null {
    const item: XExploreTrend = new XExploreTrend();
    item.name = String(record['name'] ?? '').trim();
    const social: Record<string, Object> = XExploreParser.obj(record, 'social_context');
    const metadata: Record<string, Object> = XExploreParser.obj(record, 'trend_metadata');
    item.context = String(social['text'] ?? metadata['domain_context'] ?? '');
    item.avatarUrls = XExploreParser.strArr(social, 'contextImageUrls');
    item.isAiTrend = Boolean(record['is_ai_trend'] ?? false);
    const trendUrl: Record<string, Object> = XExploreParser.obj(record, 'trend_url');
    const metadataUrl: Record<string, Object> = XExploreParser.obj(metadata, 'url');
    item.url = String(trendUrl['url'] ?? metadataUrl['url'] ?? '');
    item.query = XExploreParser.queryFromTrendUrl(item.url);
    return item.name.length > 0 ? item : null;
  }

  private static queryFromTrendUrl(url: string): string {
    const marker: string = 'query=';
    const markerIndex: number = url.indexOf(marker);
    if (markerIndex < 0) {
      return '';
    }
    const start: number = markerIndex + marker.length;
    const ampersand: number = url.indexOf('&', start);
    const encoded: string = ampersand < 0 ? url.substring(start) : url.substring(start, ampersand);
    if (encoded.length === 0) {
      return '';
    }
    try {
      const decoded: string = decodeURIComponent(encoded.split('+').join(' ')).trim();
      return decoded;
    } catch (error) {
      return '';
    }
  }

  private static heroFromRecord(record: Record<string, Object>): XExploreHero | null {
    const hero: XExploreHero = new XExploreHero();
    const event: Record<string, Object> = XExploreParser.obj(record, 'event');
    hero.eventId = String(event['rest_id'] ?? '');
    hero.title = String(record['title'] ?? '');
    const promoted: Record<string, Object> = XExploreParser.obj(record, 'promotedMetadata');
    hero.promoted = Object.keys(promoted).length > 0;
    hero.description = String(record['supportingText'] ?? record['supporting_text'] ??
      promoted['promotedTrendDescription'] ?? '');
    hero.time = String(record['timeString'] ?? record['time_string'] ?? '');
    const social: Record<string, Object> = XExploreParser.obj(record, 'socialContext');
    const legacySocial: Record<string, Object> = XExploreParser.obj(record, 'social_context');
    hero.context = String(social['text'] ?? legacySocial['text'] ?? '');
    const eventUrl: Record<string, Object> = XExploreParser.obj(record, 'eventSummaryUrl');
    const currentEventUrl: Record<string, Object> = XExploreParser.obj(record, 'url');
    hero.url = String(eventUrl['url'] ?? currentEventUrl['url'] ?? '');
    const advertiser: Record<string, Object> = XExploreParser.obj(
      XExploreParser.obj(promoted, 'advertiser_results'), 'result');
    const advertiserCore: Record<string, Object> = XExploreParser.obj(advertiser, 'core');
    const advertiserAvatar: Record<string, Object> = XExploreParser.obj(advertiser, 'avatar');
    hero.authorName = String(advertiserCore['name'] ?? '');
    hero.authorAvatarUrl = String(advertiserAvatar['image_url'] ?? '');
    const directImage: Record<string, Object> = XExploreParser.obj(record, 'eventImage');
    const currentImage: Record<string, Object> = XExploreParser.obj(record, 'image');
    hero.imageUrl = String(directImage['url'] ?? currentImage['url'] ?? '');
    const media: Record<string, Object> = XExploreParser.obj(record, 'media');
    const mediaEntity: Record<string, Object> = XExploreParser.obj(media, 'mediaEntity');
    const mediaTweet: Tweet | null = XTimelineParser.parseTweetItemContent(mediaEntity);
    if (mediaTweet !== null) {
      hero.mediaTweet = mediaTweet;
      const attachments: MediaAttachment[] | undefined = mediaTweet.attachments;
      if (hero.imageUrl.length === 0 && attachments !== undefined && attachments.length > 0) {
        hero.imageUrl = attachments[0].previewUrl;
      }
    }
    return hero.title.length > 0 || hero.description.length > 0 ? hero : null;
  }

  private static frameFromItem(itemContent: Record<string, Object>,
    entryId: string): XExploreFrame | null {
    const payload: string = String(itemContent['payload'] ?? '');
    if (payload.length === 0) {
      return null;
    }
    const strings: string[] = XExploreParser.frameStrings(payload);
    if (strings.length === 0) {
      return null;
    }
    const frame: XExploreFrame = new XExploreFrame();
    frame.height = Number(itemContent['height'] ?? 156);
    const marker: string = strings.join(' ');
    if (entryId.indexOf('NflHubBanner') >= 0 || marker.indexOf('nfl_hub_banner') >= 0) {
      frame.variant = 'banner';
      frame.title = XExploreParser.firstString(strings, 'NFL', 'NFL');
      frame.subtitle = XExploreParser.firstString(strings, 'Scores', '');
      frame.destinationUrl = XExploreParser.firstUrl(strings, 'https://x.com');
    } else {
      frame.variant = 'carousel';
      frame.tiles = XExploreParser.frameTiles(strings);
    }
    const urls: string[] = XExploreParser.frameUrls(strings);
    frame.imageUrls = urls;
    if (frame.destinationUrl.length === 0) {
      frame.destinationUrl = XExploreParser.firstUrl(urls, 'https://x.com');
    }
    return frame;
  }

  private static frameStrings(payload: string): string[] {
    try {
      const helper: util.Base64Helper = new util.Base64Helper();
      const bytes: Uint8Array = helper.decodeSync(payload, util.Type.BASIC);
      const decoder: util.TextDecoder = util.TextDecoder.create('utf-8');
      return XExploreParser.printableStrings(decoder.decodeToString(bytes));
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'frame payload decode failed: %{public}s', JSON.stringify(e));
      return [];
    }
  }

  private static printableStrings(text: string): string[] {
    const out: string[] = [];
    let current: string = '';
    for (let i: number = 0; i < text.length; i++) {
      const code: number = text.charCodeAt(i);
      if (code >= 32 && code <= 126) {
        current += text.charAt(i);
      } else {
        if (current.length >= 2 || XExploreParser.isScoreValue(current)) {
          out.push(current);
        }
        current = '';
      }
    }
    if (current.length >= 2 || XExploreParser.isScoreValue(current)) {
      out.push(current);
    }
    return out;
  }

  private static frameUrls(strings: string[]): string[] {
    const out: string[] = [];
    const seen: Map<string, boolean> = new Map();
    for (let i: number = 0; i < strings.length; i++) {
      const text: string = strings[i];
      const at: number = text.indexOf('http');
      if (at < 0) {
        continue;
      }
      const url: string = text.substring(at);
      if (!seen.has(url)) {
        seen.set(url, true);
        out.push(url);
      }
    }
    return out;
  }

  private static firstUrl(strings: string[], prefix: string): string {
    for (let i: number = 0; i < strings.length; i++) {
      const at: number = strings[i].indexOf('http');
      if (at < 0) {
        continue;
      }
      const url: string = strings[i].substring(at);
      if (url.indexOf(prefix) === 0) {
        return url;
      }
    }
    return '';
  }

  private static firstString(strings: string[], contains: string, fallback: string): string {
    for (let i: number = 0; i < strings.length; i++) {
      if (strings[i] === contains && strings[i].indexOf('http') < 0) {
        return strings[i];
      }
    }
    for (let i: number = 0; i < strings.length; i++) {
      if (strings[i].indexOf(contains) >= 0 && strings[i].indexOf('http') < 0) {
        return strings[i];
      }
    }
    return fallback;
  }

  private static frameTiles(strings: string[]): XExploreFrameTile[] {
    const out: XExploreFrameTile[] = [];
    const sharedSchedule: string = XExploreParser.frameSchedule(strings);
    for (let i: number = 0; i < strings.length; i++) {
      if (!XExploreParser.isNumericId(strings[i])) {
        continue;
      }
      let end: number = strings.length;
      for (let next: number = i + 1; next < strings.length; next++) {
        if (XExploreParser.isNumericId(strings[next])) {
          end = next;
          break;
        }
      }
      const tile: XExploreFrameTile = new XExploreFrameTile();
      tile.id = strings[i];
      tile.status = XExploreParser.frameTileStatus(strings, i);
      tile.schedule = sharedSchedule;
      let contentStarted: boolean = false;
      for (let item: number = i + 1; item < end; item++) {
        const text: string = strings[item];
        if (contentStarted && text === 'game_status') {
          break;
        }
        const imageIndex: number = text.indexOf('https://pbs.twimg.com/');
        if (imageIndex >= 0) {
          const imageUrl: string = text.substring(imageIndex);
          if (tile.imageOne.length === 0) {
            tile.imageOne = imageUrl;
          } else if (tile.teamOne.length > 0 && tile.teamTwo.length === 0) {
            // Some Jetfuel tiles contain an extra badge before the away-team
            // crest. Keeping the last image before team two mirrors X's data.
            tile.imageTwo = imageUrl;
          }
          contentStarted = true;
        } else if (contentStarted && XExploreParser.isTeamCode(text)) {
          if (tile.teamOne.length === 0) {
            tile.teamOne = text;
          } else if (tile.teamTwo.length === 0) {
            tile.teamTwo = text;
          }
        } else if (contentStarted && XExploreParser.isScoreValue(text)) {
          if (tile.imageTwo.length === 0 && tile.scoreOne.length === 0) {
            tile.scoreOne = text;
          } else if (tile.scoreTwo.length === 0) {
            tile.scoreTwo = text;
          }
        } else if (text.indexOf('https://x.com/i/jf/') >= 0) {
          tile.destinationUrl = text.substring(text.indexOf('http'));
        }
      }
      if (tile.status === 'Final' || tile.status === 'LIVE') {
        // Jetfuel omits scalar zero values. A missing score in a live/final
        // tile therefore means zero, not “no score returned”.
        if (tile.scoreOne.length === 0) {
          tile.scoreOne = '0';
        }
        if (tile.scoreTwo.length === 0) {
          tile.scoreTwo = '0';
        }
      }
      if (tile.teamOne.length > 0 || tile.teamTwo.length > 0 ||
        tile.imageOne.length > 0 || tile.imageTwo.length > 0) {
        out.push(tile);
      }
    }
    return out;
  }

  private static frameTileStatus(strings: string[], idIndex: number): string {
    const start: number = idIndex > 16 ? idIndex - 16 : 0;
    for (let i: number = idIndex - 1; i >= start; i--) {
      if (strings[i] === 'game_status' && i + 1 < idIndex) {
        return strings[i + 1];
      }
    }
    return '';
  }

  private static frameSchedule(strings: string[]): string {
    for (let i: number = 0; i < strings.length; i++) {
      const text: string = strings[i];
      if (text === 'Yesterday' || text === 'Today' || text === 'Tomorrow') {
        return text;
      }
    }
    return '';
  }

  private static isScoreValue(value: string): boolean {
    if (value.length === 0 || value.length > 2) {
      return false;
    }
    for (let i: number = 0; i < value.length; i++) {
      const code: number = value.charCodeAt(i);
      if (code < 48 || code > 57) {
        return false;
      }
    }
    return true;
  }

  private static isNumericId(value: string): boolean {
    if (value.length < 15) {
      return false;
    }
    for (let i: number = 0; i < value.length; i++) {
      const code: number = value.charCodeAt(i);
      if (code < 48 || code > 57) {
        return false;
      }
    }
    return true;
  }

  private static isTeamCode(value: string): boolean {
    if (value.length !== 3) {
      return false;
    }
    for (let i: number = 0; i < value.length; i++) {
      const code: number = value.charCodeAt(i);
      if (code < 65 || code > 90) {
        return false;
      }
    }
    return value !== 'NFL';
  }

  private static dedupeTrendItems(items: XExploreTrend[]): XExploreTrend[] {
    const seen: Map<string, boolean> = new Map();
    const out: XExploreTrend[] = [];
    for (let i: number = 0; i < items.length; i++) {
      const item: XExploreTrend = items[i];
      if (!seen.has(item.name)) {
        seen.set(item.name, true);
        out.push(item);
      }
    }
    return out;
  }

  private static strArr(source: Record<string, Object>, key: string): string[] {
    const values: Object | undefined = source[key];
    if (!(values instanceof Array)) {
      return [];
    }
    const items: Array<Object> = values as Array<Object>;
    const out: string[] = [];
    for (let i: number = 0; i < items.length; i++) {
      const value: string = String(items[i] ?? '');
      if (value.length > 0) {
        out.push(value);
      }
    }
    return out;
  }

  private static obj(source: Record<string, Object>, key: string): Record<string, Object> {
    const value: Object | undefined = source[key];
    if (value === undefined || value === null || typeof value !== 'object') {
      return {};
    }
    return value as Record<string, Object>;
  }

  private static arr(source: Record<string, Object>, key: string): Array<Record<string, Object>> {
    const value: Object | undefined = source[key];
    if (value instanceof Array) {
      return value as Array<Record<string, Object>>;
    }
    return [];
  }
}
