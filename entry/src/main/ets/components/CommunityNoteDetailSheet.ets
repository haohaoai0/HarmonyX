import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { STORAGE_KEY_SYSTEM_EMOJI_ENABLED } from '../services/AppearanceStore';
import { common } from '@kit.AbilityKit';
import { CommunityNoteDetail, NoteMatch, NoteRating, NOTE_HELPFUL_REASONS, NOTE_UNHELPFUL_REASONS } from '../models/CommunityNote';
import { CommunityNoteService, NoteLoad, NoteSubmission } from '../services/CommunityNoteService';
import { xPrivateClient } from '../services/XPrivateClient';
import { openExternalLink } from '../utils/PostEntities';
import { openPostCardUrl } from '../utils/PostCardAction';
import { EmojiSpans } from './EmojiSpans';
import { EmojiCopyMenu } from '../utils/EmojiCopyMenu';

@Component
export struct CommunityNoteDetailSheet {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp(STORAGE_KEY_SYSTEM_EMOJI_ENABLED) private systemEmojiEnabled: boolean = false;
  @Prop noteId: string = '';
  @Prop postId: string = '';
  @Prop accentColor: string = '#007DFF';
  @State private note: CommunityNoteDetail | undefined = undefined;
  @State private rating: NoteRating = new NoteRating();
  @State private loading: boolean = false;
  @State private submitting: boolean = false;
  @State private error: string = '';
  @State private confirmed: boolean = false;
  @State private uncertain: boolean = false;
  @State private matches: boolean = true;
  private alive: boolean = true;
  private generation: number = 0;
  aboutToAppear(): void { xPrivateClient.load(getContext(this) as common.UIAbilityContext); this.alive = true; void this.load(); }
  aboutToDisappear(): void { this.alive = false; ++this.generation; }
  private async load(): Promise<void> {
    const generation: number = ++this.generation; this.loading = true;
    const result: NoteLoad = await CommunityNoteService.load(this.noteId);
    if (!this.alive || generation !== this.generation) { return; }
    this.loading = false; this.note = result.note;
    if (this.note !== undefined) { this.rating = this.note.rating; this.confirmed = this.rating.helpfulness_level.length > 0; }
    this.error = result.error.length > 0 ? result.error + (result.status > 0 ? ' · HTTP ' + result.status : '') : '';
  }
  private level(value: string): Resource {
    return value === 'Helpful' ? $r('app.string.note_helpful') : value === 'SomewhatHelpful' ? $r('app.string.note_somewhat') : $r('app.string.note_unhelpful');
  }
  private reason(tag: string): Resource {
    if (tag === 'GoodSources') { return $r('app.string.note_reason_goodsources'); }
    if (tag === 'Clear') { return $r('app.string.note_reason_clear'); }
    if (tag === 'AddressesClaim') { return $r('app.string.note_reason_addressesclaim'); }
    if (tag === 'ImportantContext') { return $r('app.string.note_reason_importantcontext'); }
    if (tag === 'UnbiasedLanguage') { return $r('app.string.note_reason_unbiasedlanguage'); }
    if (tag === 'NoSources') { return $r('app.string.note_reason_nosources'); }
    if (tag === 'IrrelevantSources') { return $r('app.string.note_reason_irrelevantsources'); }
    if (tag === 'Incorrect') { return $r('app.string.note_reason_incorrect'); }
    if (tag === 'OpinionSpeculation') { return $r('app.string.note_reason_opinionspeculation'); }
    if (tag === 'Unclear') { return $r('app.string.note_reason_unclear'); }
    if (tag === 'MissingKeyPoints') { return $r('app.string.note_reason_missingkeypoints'); }
    if (tag === 'Rude') { return $r('app.string.note_reason_rude'); }
    if (tag === 'NoteNotNeeded') { return $r('app.string.note_reason_notenotneeded'); }
    if (tag === 'TwitterViolationAny') { return $r('app.string.note_reason_twitterviolationany'); }
    return $r('app.string.note_reason_other');
  }
  private chooseLevel(value: string): void {
    const rating: NoteRating = new NoteRating(); rating.helpfulness_level = value;
    rating.helpful_tags = this.rating.helpful_tags; rating.not_helpful_tags = this.rating.not_helpful_tags;
    if (value === 'Helpful') { rating.not_helpful_tags = []; }
    if (value === 'NotHelpful') { rating.helpful_tags = []; }
    this.rating = rating; this.confirmed = false;
  }
  private chooseReason(tag: string, helpful: boolean): void {
    const rating: NoteRating = new NoteRating(); rating.helpfulness_level = this.rating.helpfulness_level;
    rating.helpful_tags = [...this.rating.helpful_tags]; rating.not_helpful_tags = [...this.rating.not_helpful_tags];
    const tags: string[] = helpful ? rating.helpful_tags : rating.not_helpful_tags;
    const index: number = tags.indexOf(tag); if (index >= 0) { tags.splice(index, 1); } else { tags.push(tag); }
    this.rating = rating; this.confirmed = false;
  }
  private async submit(): Promise<void> {
    if (this.note === undefined || this.submitting || !CommunityNoteService.valid(this.rating) || this.uncertain) { return; }
    const generation: number = ++this.generation; this.submitting = true; this.error = '';
    const rating: NoteRating = JSON.parse(JSON.stringify(this.rating)) as NoteRating;
    if (this.note.isUrl || this.note.isMedia) {
      rating.note_match = new NoteMatch();
      if (this.note.isUrl) { rating.note_match.all_url_note_match = this.matches; }
      else { rating.note_match.all_media_note_match = this.matches; }
    }
    if (this.note.tweetId.length === 0) { this.note.tweetId = this.postId; }
    const result: NoteSubmission = await CommunityNoteService.submit(this.note, rating);
    if (!this.alive || generation !== this.generation) { return; }
    this.submitting = false; this.confirmed = result.confirmed; this.uncertain = result.uncertain;
    this.error = result.error + (result.status > 0 && result.error.length > 0 ? ' · HTTP ' + result.status : '');
    if (result.note !== undefined) { this.note = result.note; }
  }
  @Builder
  private Reasons(helpful: boolean): void {
    Column({ space: 4 }) {
      Text(helpful ? $r('app.string.note_why_helpful') : $r('app.string.note_why_unhelpful')).fontFamily(this.appFontFamily)
        .fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary')).fontSize($r('sys.float.Body_M'))
      ForEach(helpful ? NOTE_HELPFUL_REASONS : NOTE_UNHELPFUL_REASONS, (tag: string) => {
        Button({ type: ButtonType.Normal }) {
          Row({ space: 8 }) {
            SymbolGlyph((helpful ? this.rating.helpful_tags : this.rating.not_helpful_tags).indexOf(tag) >= 0 ?
              $r('sys.symbol.checkmark_circle_fill') : $r('sys.symbol.circle')).fontSize(20).fontColor([this.accentColor])
            Text(this.reason(tag)).fontFamily(this.appFontFamily).layoutWeight(1).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_primary'))
          }.width('100%').padding(8)
        }.width('100%').padding(0).backgroundColor(Color.Transparent).enabled(!this.submitting)
          .onClick((): void => this.chooseReason(tag, helpful))
      }, (tag: string): string => tag)
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
  build(): void {
    Scroll() {
      Column({ space: 16 }) {
        Text($r('app.string.card_note')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Title_S')).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
        if (this.loading) { LoadingProgress().width(28).height(28).color(this.accentColor) }
        if (this.note !== undefined) {
          Text() { EmojiSpans(this.getUIContext(), this.note.text, $r('sys.float.Body_L'), this.systemEmojiEnabled) }.fontFamily(this.appFontFamily)
            .width('100%').fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_primary')).copyOption(CopyOptions.LocalDevice)
            .editMenuOptions(new EmojiCopyMenu(getContext(this) as common.UIAbilityContext, this.note.text, this.systemEmojiEnabled))
          if (this.note.status.length > 0) {
            Text(this.note.status === 'CurrentlyRatedHelpful' ? $r('app.string.note_status_helpful') :
              this.note.status === 'CurrentlyRatedNotHelpful' ? $r('app.string.note_status_unhelpful') : $r('app.string.note_status_waiting')).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Caption_L')).fontColor(this.accentColor)
          }
          ForEach(this.note.sources, (url: string) => {
            Text(url).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor(this.accentColor).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
              .onClick((): void => openPostCardUrl(getContext(this) as common.UIAbilityContext, url))
          }, (url: string): string => url)
          Text($r('app.string.note_question')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Subtitle_L')).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
          Row({ space: 6 }) {
            ForEach(['Helpful', 'SomewhatHelpful', 'NotHelpful'], (value: string) => {
              Button(this.level(value)).layoutWeight(1).fontSize($r('sys.float.Caption_L')).fontColor(this.rating.helpfulness_level === value ?
                $r('app.color.text_on_brand') : this.accentColor).backgroundColor(this.rating.helpfulness_level === value ? this.accentColor : $r('app.color.poll_option_surface'))
                .enabled(!this.submitting && !this.uncertain).onClick((): void => this.chooseLevel(value))
            }, (value: string): string => value)
          }.width('100%')
          if (this.rating.helpfulness_level === 'Helpful' || this.rating.helpfulness_level === 'SomewhatHelpful') { this.Reasons(true) }
          if (this.rating.helpfulness_level === 'NotHelpful' || this.rating.helpfulness_level === 'SomewhatHelpful') { this.Reasons(false) }
          if (this.note.isMedia || this.note.isUrl) {
            Row() {
              Text($r('app.string.note_all_matches')).fontFamily(this.appFontFamily).layoutWeight(1).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_primary'))
              Toggle({ type: ToggleType.Switch, isOn: this.matches }).selectedColor(this.accentColor).onChange((value: boolean): void => { this.matches = value; })
            }.width('100%')
          }
          if (this.confirmed) { Text($r('app.string.note_rating_saved')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor(this.accentColor) }
          if (this.uncertain) {
            Text($r('app.string.note_rating_uncertain')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary'))
            Button($r('app.string.card_retry')).onClick((): void => { this.uncertain = false; void this.load(); })
          }
          Button(this.submitting ? $r('app.string.poll_submitting') : $r('app.string.note_submit')).width('100%').fontColor($r('app.color.text_on_brand'))
            .backgroundColor(this.accentColor).enabled(CommunityNoteService.valid(this.rating) && !this.submitting && !this.uncertain && !this.confirmed)
            .onClick((): void => { void this.submit(); })
        }
        if (this.error.length > 0) { Text(this.error).fontFamily(this.appFontFamily).width('100%').fontSize($r('sys.float.Body_M')).fontColor($r('app.color.danger')) }
        Button($r('app.string.card_original')).fontColor(this.accentColor).backgroundColor(Color.Transparent)
          .onClick((): void => openExternalLink(getContext(this) as common.UIAbilityContext, 'https://x.com/i/communitynotes/n/' + this.noteId))
      }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 20, right: 20, top: 24, bottom: 32 })
    }.width('100%').height('100%').scrollBar(BarState.Off)
  }
}
