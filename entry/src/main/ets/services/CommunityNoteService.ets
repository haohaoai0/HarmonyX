import { CommunityNoteDetail, NoteRating, NoteMatch, NOTE_HELPFUL_REASONS, NOTE_UNHELPFUL_REASONS } from '../models/CommunityNote';
import { XRichCardParser as Card } from './XRichCardParser';
import { XPrivateResult, xPrivateClient } from './XPrivateClient';

export class NoteLoad {
  note: CommunityNoteDetail | undefined = undefined;
  status: number = 0;
  error: string = '';
}
export class NoteSubmission {
  confirmed: boolean = false;
  uncertain: boolean = false;
  error: string = '';
  status: number = 0;
  note: CommunityNoteDetail | undefined = undefined;
}
export class CommunityNoteService {
  static parse(body: string): CommunityNoteDetail | undefined {
    try {
      const data: Record<string, Object> = Card.object((JSON.parse(body) as Record<string, Object>)['data']);
      const raw: Record<string, Object> = Card.object(data['birdwatch_note_by_rest_id']);
      const id: string = Card.text(raw['rest_id']); if (!/^\d+$/.test(id)) { return undefined; }
      const note: CommunityNoteDetail = new CommunityNoteDetail(); note.id = id;
      const content: Record<string, Object> = Card.object(raw['data_v1']);
      const summary: Record<string, Object> = Card.object(content['summary']);
      note.text = Card.text(summary['text']); note.status = Card.text(raw['rating_status']);
      note.tweetId = Card.text(raw['tweet_id'] ?? Card.object(raw['tweet'])['rest_id']);
      note.isMedia = raw['is_media_note'] === true; note.isUrl = raw['is_url_note'] === true;
      note.live = raw['live_note'] !== undefined && raw['live_note'] !== null;
      const entities: Object | undefined = summary['entities'];
      if (entities instanceof Array) {
        const entries: Object[] = entities as Object[];
        for (let i: number = 0; i < entries.length; i++) {
          const entity: Record<string, Object> = Card.object(entries[i]);
          const url: string = Card.url(entity['expanded_url'] ?? entity['url']);
          if (url.length > 0) { note.sources.push(url); }
        }
      }
      const rating: Record<string, Object> = Card.object(Card.object(raw['rating'])['data_v2']);
      note.rating.helpfulness_level = Card.text(rating['helpfulness_level']);
      note.rating.helpful_tags = CommunityNoteService.strings(rating['helpful_tags']);
      note.rating.not_helpful_tags = CommunityNoteService.strings(rating['not_helpful_tags']);
      return note;
    } catch (error) { return undefined; }
  }
  private static strings(raw: Object | undefined): string[] {
    if (!(raw instanceof Array)) { return []; }
    return (raw as Object[]).filter((item: Object): boolean => typeof item === 'string').map((item: Object): string => String(item));
  }
  static valid(rating: NoteRating): boolean {
    return ['Helpful', 'SomewhatHelpful', 'NotHelpful'].indexOf(rating.helpfulness_level) >= 0 &&
      rating.helpful_tags.every((tag: string): boolean => NOTE_HELPFUL_REASONS.indexOf(tag) >= 0) &&
      rating.not_helpful_tags.every((tag: string): boolean => NOTE_UNHELPFUL_REASONS.indexOf(tag) >= 0) &&
      (rating.helpfulness_level === 'Helpful' ? rating.helpful_tags.length > 0 :
        rating.helpfulness_level === 'NotHelpful' ? rating.not_helpful_tags.length > 0 : rating.helpful_tags.length > 0 && rating.not_helpful_tags.length > 0);
  }
  static async load(id: string): Promise<NoteLoad> {
    const out: NoteLoad = new NoteLoad(); const generation: number = xPrivateClient.sessionGeneration();
    const result: XPrivateResult = await xPrivateClient.postContent('BirdwatchFetchOneNote', id);
    if (generation !== xPrivateClient.sessionGeneration()) { out.error = 'session_changed'; return out; }
    out.status = result.status; out.note = result.ok ? CommunityNoteService.parse(result.body) : undefined;
    out.error = result.ok ? out.note === undefined ? 'missing_note' : '' : result.errorText;
    return out;
  }
  static async submit(note: CommunityNoteDetail, rating: NoteRating): Promise<NoteSubmission> {
    const out: NoteSubmission = new NoteSubmission();
    if (!CommunityNoteService.valid(rating)) { out.error = 'invalid_rating'; return out; }
    const generation: number = xPrivateClient.sessionGeneration();
    const result: XPrivateResult = await xPrivateClient.rateCommunityNote(note.id, note.tweetId, rating, note.live);
    if (generation !== xPrivateClient.sessionGeneration()) { out.error = 'session_changed'; return out; }
    out.status = result.status;
    if (!result.ok) { out.error = result.errorText; out.uncertain = result.status === 0; return out; }
    try {
      const data: Record<string, Object> = Card.object((JSON.parse(result.body) as Record<string, Object>)['data']);
      const response: Record<string, Object> = Card.object(data['birdwatchnote_rate_v3']);
      if (response['type'] === 'BirdwatchError' || response['error_code'] !== undefined) {
        out.error = Card.text(response['error_code']) || 'rating_rejected'; return out;
      }
    } catch (error) { out.error = 'invalid_response'; out.uncertain = true; return out; }
    const refreshed: NoteLoad = await CommunityNoteService.load(note.id); out.note = refreshed.note;
    out.confirmed = refreshed.note !== undefined && refreshed.note.rating.helpfulness_level === rating.helpfulness_level &&
      rating.helpful_tags.every((tag: string): boolean => refreshed.note?.rating.helpful_tags.indexOf(tag) !== -1) &&
      rating.not_helpful_tags.every((tag: string): boolean => refreshed.note?.rating.not_helpful_tags.indexOf(tag) !== -1);
    out.uncertain = !out.confirmed;
    return out;
  }
}
