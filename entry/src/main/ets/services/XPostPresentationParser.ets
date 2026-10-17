import { CommunityNote, PostDisclosure, PostPresentation, PostVisibility } from '../models/PostContent';
import { XRichCardParser as Card } from './XRichCardParser';

export class XPostPresentationParser {
  private static richText(value: Object | undefined): string {
    const raw: Record<string, Object> = Card.object(value);
    return Card.text(raw['text']) || Card.text(value);
  }
  static parse(input: Record<string, Object>, node: Record<string, Object> = input): PostPresentation | undefined {
    const out: PostPresentation = new PostPresentation();
    const legacy: Record<string, Object> = Card.object(node['legacy']);
    const pivot: Record<string, Object> = Card.object(node['birdwatch_pivot'] ?? legacy['birdwatch_pivot']);
    if (Object.keys(pivot).length > 0) {
      const note: CommunityNote = new CommunityNote();
      const raw: Record<string, Object> = Card.object(pivot['note']);
      note.id = Card.text(raw['rest_id'] ?? raw['id'] ?? pivot['note_id']);
      note.title = XPostPresentationParser.richText(pivot['title']);
      note.text = XPostPresentationParser.richText(raw['text']);
      note.subtitle = XPostPresentationParser.richText(pivot['subtitle']);
      note.url = Card.url(pivot['destination_url']) || (/^\d+$/.test(note.id) ? 'https://x.com/i/birdwatch/n/' + note.id : '');
      const urls: RegExpMatchArray | null = note.text.match(/https?:\/\/[^\s<>]+/g);
      note.sources = urls === null ? [] : urls.map((url: string): string => url.replace(/[.,;!?)。，；！）]+$/, ''));
      out.note = note;
    }
    const disclosure: Record<string, Object> = Card.object(node['content_disclosure'] ?? legacy['content_disclosure']);
    const ai: Record<string, Object> = Card.object(disclosure['ai_generated_disclosure']);
    const paid: Record<string, Object> = Card.object(disclosure['advertising_disclosure']);
    if (ai['has_ai_generated_media'] === true) { XPostPresentationParser.label(out, 'ai', '', ''); }
    if (paid['is_paid_promotion'] === true) { XPostPresentationParser.label(out, 'paid', '', ''); }
    const promoted: Record<string, Object> = Card.object(input['tweetPromotedMetadata'] ?? input['tweet_promoted_metadata'] ??
      input['promotedMetadata'] ?? input['promoted_metadata'] ?? node['tweetPromotedMetadata'] ?? node['tweet_promoted_metadata'] ??
      node['promotedMetadata'] ?? node['promoted_metadata']);
    if (Object.keys(promoted).length > 0) {
      XPostPresentationParser.label(out, 'ad', Card.text(promoted['disclaimerText']), Card.url(promoted['advertiser_url']));
    }
    const intervention: Record<string, Object> = Card.object(input['softIntervention'] ?? node['softIntervention']);
    if (Object.keys(intervention).length > 0) {
      XPostPresentationParser.label(out, 'warning', XPostPresentationParser.richText(intervention['displayText'] ?? intervention['text']),
        Card.url(intervention['landingUrl'] ?? intervention['url']));
    }
    const type: string = Card.text(input['__typename']);
    const tombstone: Record<string, Object> = Card.object(input['tombstone'] ?? input['tombstoneInfo'] ?? node['tombstoneInfo']);
    const limited: Record<string, Object> = Card.object(input['limitedActionResults'] ?? node['limitedActionResults']);
    const policy: Record<string, Object> = Card.object(limited['limited_actions_policy']);
    const interstitial: Record<string, Object> = Card.object(input['interstitial'] ?? node['interstitial']);
    const exclusivity: Record<string, Object> = Card.object(node['exclusivityInfo']);
    const premium: Record<string, Object> = Card.object(node['premium_tweet_info']);
    const withheld: Object | undefined = legacy['withheld_in_countries'];
    if (Object.keys(tombstone).length > 0 || type === 'TweetTombstone' || type === 'TweetUnavailable' ||
      Object.keys(limited).length > 0 || Object.keys(interstitial).length > 0 ||
      node['is_tweet_preview_display'] === true || (withheld instanceof Array && withheld.length > 0)) {
      const visibility: PostVisibility = new PostVisibility();
      visibility.kind = type === 'TweetTombstone' || type === 'TweetUnavailable' ? 'unavailable' :
        node['is_tweet_preview_display'] === true && (Object.keys(exclusivity).length > 0 || Object.keys(premium).length > 0) ?
          'subscriber' : withheld instanceof Array && withheld.length > 0 ? 'withheld' : 'limited';
      visibility.text = XPostPresentationParser.richText(tombstone['text'] ?? tombstone['richText'] ??
        interstitial['text'] ?? interstitial['displayText'] ?? limited['text']);
      visibility.hidden = visibility.kind === 'unavailable' || visibility.kind === 'withheld' ||
        tombstone['displayType'] === 'NonCompliant' || interstitial['displayType'] === 'NonCompliant';
      visibility.url = Card.url(tombstone['url'] ?? interstitial['url']);
      const actions: Object | undefined = policy['limited_actions'] ?? limited['limited_actions'];
      if (actions instanceof Array) {
        const entries: Object[] = actions as Object[];
        for (let i: number = 0; i < entries.length; i++) {
          const action: Record<string, Object> = Card.object(entries[i]);
          const name: string = Card.text(action['action'] ?? action['type']);
          if (name.length > 0) { visibility.actions.push(name.toLowerCase()); }
          const prompt: Record<string, Object> = Card.object(action['prompt']);
          visibility.text = visibility.text || XPostPresentationParser.richText(prompt['text']);
        }
      }
      out.visibility = visibility;
    }
    return out.note !== undefined || out.visibility !== undefined || out.labels.length > 0 ? out : undefined;
  }
  private static label(out: PostPresentation, kind: string, text: string, url: string): void {
    const label: PostDisclosure = new PostDisclosure(); label.kind = kind; label.text = text; label.url = url; out.labels.push(label);
  }
}
