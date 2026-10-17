import type { PollOption, TweetLinkCard, TweetPoll } from '../models/Tweet';
import { XRichCardParser } from './XRichCardParser';
import { XStructuredCardParser } from './XStructuredCardParser';

// X's GraphQL cards use both a binding array and a binding dictionary. Keep
// decoding here so feeds, detail, quotes and the vote response share a contract.
export class XPostCardParser {
  private static object(value: Object | undefined): Record<string, Object> {
    return value !== null && value !== undefined && typeof value === 'object' && !(value instanceof Array) ?
      value as Record<string, Object> : {};
  }

  private static text(value: Object | undefined): string {
    return typeof value === 'string' || typeof value === 'number' ? String(value) : '';
  }

  private static count(value: Object | undefined): number {
    const count: number = Number(value);
    return isFinite(count) && count >= 0 ? Math.floor(count) : 0;
  }

  static card(node: Record<string, Object>): Record<string, Object> {
    const legacy: Record<string, Object> = XPostCardParser.object(node['legacy']);
    let card: Record<string, Object> = XPostCardParser.object(node['card'] ?? legacy['card']);
    // Android HomeTimeline exposes the same card as tweet_card; web detail
    // exposes card. Decode both before the feed snapshot is persisted.
    if (Object.keys(card).length === 0) {
      card = XPostCardParser.object(node['tweet_card'] ?? legacy['tweet_card']);
    }
    if (Object.keys(card).length === 0) {
      card = XPostCardParser.object(XPostCardParser.object(node['card_results'])['result']);
    }
    if (Object.keys(card).length === 0 && (node['binding_values'] !== undefined || node['card_type'] !== undefined)) {
      card = node;
    }
    const inner: Record<string, Object> = XPostCardParser.object(card['legacy']);
    // New cards carry typed layout/components instead of STRING bindings.
    // A legacy sibling must not replace that layout.
    return card['layout'] !== undefined ? card : Object.keys(inner).length > 0 ? inner : card;
  }

  private static bindings(card: Record<string, Object>): Record<string, Object> {
    const raw: Object | undefined = card['binding_values'] ?? XPostCardParser.object(card['legacy'])['binding_values'];
    if (!(raw instanceof Array)) { return XPostCardParser.object(raw); }
    const values: Record<string, Object> = {};
    const entries: Object[] = raw as Object[];
    for (let i: number = 0; i < entries.length; i++) {
      const entry: Record<string, Object> = XPostCardParser.object(entries[i]);
      const key: string = XPostCardParser.text(entry['key']);
      if (key.length > 0 && entry['value'] !== undefined) { values[key] = entry['value']; }
    }
    return values;
  }

  private static string(values: Record<string, Object>, key: string): string {
    const value: Object | undefined = values[key];
    return typeof value === 'string' ? value : XPostCardParser.text(XPostCardParser.object(value)['string_value']);
  }

  private static boolean(values: Record<string, Object>, key: string): boolean {
    const raw: Object | undefined = values[key];
    const value: Object | undefined = typeof raw === 'boolean' ? raw : XPostCardParser.object(raw)['boolean_value'];
    return value === true || value === 'true';
  }

  private static image(values: Record<string, Object>, keys: string[]): string {
    for (let i: number = 0; i < keys.length; i++) {
      const image: Record<string, Object> = XPostCardParser.object(
        XPostCardParser.object(values[keys[i]])['image_value']);
      const url: string = XPostCardParser.safeUrl(XPostCardParser.text(image['url']));
      if (url.length > 0) { return url; }
    }
    return '';
  }

  private static safeUrl(value: string): string {
    return /^https?:\/\/[^\s]+$/i.test(value) ? value : '';
  }

  static poll(node: Record<string, Object>): TweetPoll | undefined {
    const card: Record<string, Object> = XPostCardParser.card(node);
    const name: string = XPostCardParser.text(card['name'] ?? card['card_type']);
    const type: string = name.replace(/^\d+:/, '');
    if (!/^poll[234]choice_(text_only|image|video)$/.test(type) && type !== 'poll_choice_images') {
      return undefined;
    }
    const values: Record<string, Object> = XPostCardParser.bindings(card);
    const options: PollOption[] = [];
    let countsKnown: boolean = true;
    for (let i: number = 1; i <= 4; i++) {
      const label: string = XPostCardParser.string(values, 'choice' + i + '_label');
      if (label.length === 0) { continue; }
      const rawCount: string = XPostCardParser.string(values, 'choice' + i + '_count');
      countsKnown = countsKnown && rawCount.length > 0 && isFinite(Number(rawCount)) && Number(rawCount) >= 0;
      options.push({ id: String(i), label: label, votes: XPostCardParser.count(rawCount),
        imageUrl: XPostCardParser.image(values, ['choice' + i + '_image_original', 'choice' + i + '_image']) });
    }
    if (options.length < 2) { return undefined; }
    const uri: string = XPostCardParser.text(card['url'] ?? card['card_uri']) || XPostCardParser.string(values, 'card_url');
    const selected: string = XPostCardParser.string(values, 'selected_choice');
    return {
      id: uri, cardUri: uri, cardName: name, api: XPostCardParser.string(values, 'api'),
      options: options, endsAt: XPostCardParser.string(values, 'end_datetime_utc'),
      durationMinutes: XPostCardParser.count(XPostCardParser.string(values, 'duration_minutes')),
      countsAreFinal: XPostCardParser.boolean(values, 'counts_are_final'), countsKnown: countsKnown,
      selectedChoice: options.some((option: PollOption): boolean => option.id === selected) ? selected : '',
      imageUrl: XPostCardParser.image(values, ['image_original', 'player_image_original', 'summary_photo_image_original']),
      media: XRichCardParser.player(values, uri || name)
    };
  }

  static v2Poll(post: Record<string, Object>, polls: Array<Record<string, Object>>): TweetPoll | undefined {
    const attachment: Record<string, Object> = XPostCardParser.object(post['attachments']);
    const ids: Object | undefined = attachment['poll_ids'];
    if (!(ids instanceof Array) || ids.length === 0) { return undefined; }
    const id: string = XPostCardParser.text(ids[0]);
    for (let i: number = 0; i < polls.length; i++) {
      const raw: Record<string, Object> = polls[i];
      if (XPostCardParser.text(raw['id']) !== id || !(raw['options'] instanceof Array)) { continue; }
      const entries: Object[] = raw['options'] as Object[];
      const options: PollOption[] = [];
      let countsKnown: boolean = true;
      for (let j: number = 0; j < entries.length && j < 4; j++) {
        const option: Record<string, Object> = XPostCardParser.object(entries[j]);
        const position: number = XPostCardParser.count(option['position']);
        const label: string = XPostCardParser.text(option['label']);
        if (position < 1 || position > 4 || label.length === 0) { continue; }
        countsKnown = countsKnown && option['votes'] !== undefined && isFinite(Number(option['votes'])) && Number(option['votes']) >= 0;
        options.push({ id: String(position), label: label, votes: XPostCardParser.count(option['votes']), imageUrl: '' });
      }
      if (options.length < 2) { return undefined; }
      return { id: id, cardUri: '', cardName: '', api: '', options: options,
        endsAt: XPostCardParser.text(raw['end_datetime']), durationMinutes: XPostCardParser.count(raw['duration_minutes']),
        countsAreFinal: raw['voting_status'] === 'closed', countsKnown: countsKnown, selectedChoice: '', imageUrl: '' };
    }
    return undefined;
  }

  static link(node: Record<string, Object>, postId: string): TweetLinkCard | undefined {
    const card: Record<string, Object> = XPostCardParser.card(node);
    const name: string = XPostCardParser.text(card['name'] ?? card['card_type']);
    if (XPostCardParser.poll(node) !== undefined) { return undefined; }
    const values: Record<string, Object> = XPostCardParser.bindings(card);
    const linkedSpace: string = XPostCardParser.spaceLink(node);
    const sharedLink: string = XRichCardParser.entityLink(node);
    if (name.length === 0 && card['layout'] === undefined && linkedSpace.length === 0 && sharedLink.length === 0) { return undefined; }
    let target: string = XPostCardParser.safeUrl(XPostCardParser.string(values, 'card_url'));
    target = target || XPostCardParser.safeUrl(XPostCardParser.text(card['url'])) || sharedLink;
    let title: string = XPostCardParser.string(values, 'title') || XPostCardParser.string(values, 'audio_space_title') ||
      XPostCardParser.string(values, 'broadcast_title');
    let description: string = XPostCardParser.string(values, 'description');
    let image: string = XPostCardParser.image(values, ['summary_photo_image_original', 'photo_image_full_size_original',
      'thumbnail_image_original', 'thumbnail_image', 'player_image_original', 'image_original']);
    // Classic unified cards contain a JSON document inside a STRING binding.
    const unified: string = XPostCardParser.string(values, 'unified_card');
    if (unified.length > 0) {
      try {
        const document: Record<string, Object> = XPostCardParser.object(JSON.parse(unified) as Object);
        const destinations: Record<string, Object> = XPostCardParser.object(document['destination_objects']);
        const keys: string[] = Object.keys(destinations);
        for (let i: number = 0; i < keys.length; i++) {
          const data: Record<string, Object> = XPostCardParser.object(XPostCardParser.object(destinations[keys[i]])['data']);
          const candidate: string = XPostCardParser.safeUrl(XPostCardParser.text(data['url']));
          if (candidate.length > 0) { target = candidate; break; }
        }
        const components: Record<string, Object> = XPostCardParser.object(document['component_objects']);
        const componentKeys: string[] = Object.keys(components);
        for (let i: number = 0; i < componentKeys.length; i++) {
          const data: Record<string, Object> = XPostCardParser.object(XPostCardParser.object(components[componentKeys[i]])['data']);
          title = title || XPostCardParser.text(data['title']);
          description = description || XPostCardParser.text(data['description']);
        }
        const media: Record<string, Object> = XPostCardParser.object(document['media_entities']);
        const mediaKeys: string[] = Object.keys(media);
        for (let i: number = 0; i < mediaKeys.length && image.length === 0; i++) {
          const entry: Record<string, Object> = XPostCardParser.object(media[mediaKeys[i]]);
          image = XPostCardParser.safeUrl(XPostCardParser.text(entry['media_url_https']));
        }
      } catch (error) { /* A malformed optional card never hides the post. */ }
    }
    const space: string = XPostCardParser.string(values, 'id') || XPostCardParser.string(values, 'audio_space_id');
    let kind: string = linkedSpace.length > 0 || /^https:\/\/(?:www\.)?(?:x\.com|twitter\.com)\/i\/spaces\/[A-Za-z0-9]{5,64}(?:[?#].*)?$/i.test(target) ||
      name.indexOf('audiospace') >= 0 || name.indexOf('audio_space') >= 0 ? 'space' :
      name.indexOf('broadcast') >= 0 ? 'broadcast' : name.indexOf('event') >= 0 ? 'event' :
        name.indexOf('app') >= 0 ? 'app' : 'link';
    if (kind === 'space' && /^[A-Za-z0-9]{5,64}$/.test(space)) { target = 'https://x.com/i/spaces/' + space; }
    if (kind === 'space' && linkedSpace.length > 0) { target = linkedSpace; }
    if (kind === 'space' && !/^https:\/\/(?:www\.)?(?:x\.com|twitter\.com)\/i\/spaces\/[A-Za-z0-9]{5,64}(?:[?#].*)?$/i.test(target)) {
      kind = 'link';
    }
    if (target.length === 0) { target = 'https://x.com/i/status/' + postId; }
    const domain: string = XPostCardParser.string(values, 'vanity_url') ||
      target.replace(/^https?:\/\//, '').split('/')[0];
    const link: TweetLinkCard = { kind: kind, title: title, description: description, url: target, domain: domain, imageUrl: image };
    if (card['layout'] !== undefined) { return XStructuredCardParser.enrich(link, card); }
    return XRichCardParser.enrich(link, name, values);
  }

  private static spaceLink(node: Record<string, Object>): string {
    const legacy: Record<string, Object> = XPostCardParser.object(node['legacy']);
    const entities: Record<string, Object> = XPostCardParser.object(legacy['entities'] ?? node['entities']);
    const raw: Object | undefined = entities['urls'];
    if (!(raw instanceof Array)) { return ''; }
    const urls: Object[] = raw as Object[];
    for (let i: number = 0; i < urls.length; i++) {
      const url: Record<string, Object> = XPostCardParser.object(urls[i]);
      const expanded: string = XPostCardParser.text(url['expanded_url']);
      const match: RegExpMatchArray | null = expanded.match(/^https:\/\/(?:www\.)?(?:x\.com|twitter\.com)\/i\/spaces\/([A-Za-z0-9]{5,64})(?:[?#].*)?$/i);
      if (match !== null) { return 'https://x.com/i/spaces/' + match[1]; }
    }
    return '';
  }

  static voteResponse(body: string): TweetPoll | undefined {
    try { return XPostCardParser.poll(JSON.parse(body) as Record<string, Object>); }
    catch (error) { return undefined; }
  }
}
