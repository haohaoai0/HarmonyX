export class NoteRating {
  helpfulness_level: string = '';
  helpful_tags: string[] = [];
  not_helpful_tags: string[] = [];
  note_match: NoteMatch | undefined = undefined;
}
export class NoteMatch {
  all_url_note_match: boolean | undefined = undefined;
  all_media_note_match: boolean | undefined = undefined;
}
export class CommunityNoteDetail {
  id: string = '';
  tweetId: string = '';
  text: string = '';
  status: string = '';
  sources: string[] = [];
  rating: NoteRating = new NoteRating();
  isMedia: boolean = false;
  isUrl: boolean = false;
  live: boolean = false;
}
export const NOTE_HELPFUL_REASONS: string[] = ['GoodSources', 'Clear', 'AddressesClaim', 'ImportantContext', 'UnbiasedLanguage', 'Other'];
export const NOTE_UNHELPFUL_REASONS: string[] = ['NoSources', 'IrrelevantSources', 'Incorrect', 'OpinionSpeculation', 'Unclear',
  'MissingKeyPoints', 'Rude', 'NoteNotNeeded', 'TwitterViolationAny', 'Other'];
