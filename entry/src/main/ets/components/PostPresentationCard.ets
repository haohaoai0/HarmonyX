import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { STORAGE_KEY_SYSTEM_EMOJI_ENABLED } from '../services/AppearanceStore';
import { common } from '@kit.AbilityKit';
import { PostDisclosure, PostPresentation } from '../models/PostContent';
import { openPostCardUrl } from '../utils/PostCardAction';
import { CommunityNoteDetailSheet } from './CommunityNoteDetailSheet';
import { sheetMaterialOptions } from '../utils/SheetMaterial';
import { DEFAULT_SHEET_MATERIAL_ENABLED, STORAGE_KEY_SHEET_MATERIAL_ENABLED, STORAGE_KEY_SHEET_MATERIAL_LEVEL } from '../services/SheetMaterialSettingsStore';
import { EmojiSpans } from './EmojiSpans';
import { EmojiCopyMenu } from '../utils/EmojiCopyMenu';

@Component
export struct PostPresentationCard {
  @StorageProp('harmonyx.compact_window') private sheetCompactWindow: boolean = false;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp(STORAGE_KEY_SYSTEM_EMOJI_ENABLED) private systemEmojiEnabled: boolean = false;
  @StorageProp('harmonyx.breakpoint') private sheetWindowBreakpoint: string = 'sm';
  @Prop postId: string = '';
  @Prop presentation: PostPresentation;
  @Prop accentColor: string = '#007DFF';
  @State private expanded: boolean = false;
  @State private showNote: boolean = false;
  @StorageProp(STORAGE_KEY_SHEET_MATERIAL_ENABLED) private sheetMaterialEnabled: boolean = DEFAULT_SHEET_MATERIAL_ENABLED;
  @StorageProp(STORAGE_KEY_SHEET_MATERIAL_LEVEL) private sheetMaterialLevel: number = 0;
  @Builder
  private NoteSheet(): void {
    CommunityNoteDetailSheet({ noteId: this.presentation.note?.id ?? '', postId: this.postId, accentColor: this.accentColor })
  }
  private open(url: string): void { openPostCardUrl(getContext(this) as common.UIAbilityContext, url); }
  private label(item: PostDisclosure): ResourceStr {
    if (item.text.length > 0) { return item.text; }
    if (item.kind === 'ai') { return $r('app.string.card_ai'); }
    if (item.kind === 'paid') { return $r('app.string.card_paid'); }
    if (item.kind === 'ad') { return $r('app.string.card_ad'); }
    return $r('app.string.card_warning');
  }
  private visibilityText(): ResourceStr {
    if ((this.presentation.visibility?.text.length ?? 0) > 0) { return this.presentation.visibility?.text ?? ''; }
    if (this.presentation.visibility?.kind === 'subscriber') { return $r('app.string.card_subscriber'); }
    if (this.presentation.visibility?.kind === 'withheld') { return $r('app.string.card_withheld'); }
    if (this.presentation.visibility?.hidden) { return $r('app.string.card_unavailable'); }
    return $r('app.string.card_limited');
  }
  build(): void {
    Column({ space: 8 }) {
      if (this.presentation.visibility !== undefined) {
        Column({ space: 8 }) {
          Text() { EmojiSpans(this.getUIContext(), this.visibilityText(), $r('sys.float.Body_M'), this.systemEmojiEnabled) }.fontFamily(this.appFontFamily)
            .width('100%').fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary'))
          if (this.postId.length > 0 || (this.presentation.visibility.url.length > 0)) {
            Button($r('app.string.card_original')).fontColor(this.accentColor).backgroundColor(Color.Transparent)
              .onClick((): void => this.open(this.presentation.visibility?.url || 'https://x.com/i/status/' + this.postId))
          }
        }.width('100%').alignItems(HorizontalAlign.Start).padding(12).borderRadius(12)
          .border({ width: 1, color: $r('app.color.divider') }).backgroundColor($r('app.color.poll_option_surface'))
      }
      ForEach(this.presentation.labels.filter((item: PostDisclosure): boolean => item.kind !== 'ad'), (item: PostDisclosure) => {
        Row({ space: 6 }) {
          SymbolGlyph($r('sys.symbol.info_circle')).fontSize(14).fontColor([$r('app.color.text_secondary')])
          Text() { EmojiSpans(this.getUIContext(), this.label(item), $r('sys.float.Caption_L'), this.systemEmojiEnabled) }.fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Caption_L')).fontColor($r('app.color.text_secondary'))
        }.width('100%').onClick((): void => { if (item.url.length > 0) { this.open(item.url); } })
      }, (item: PostDisclosure): string => item.kind + item.text)
      if (this.presentation.note !== undefined) {
        Column({ space: 8 }) {
          Text() { EmojiSpans(this.getUIContext(), this.presentation.note.title || $r('app.string.card_note'), $r('sys.float.Body_M'), this.systemEmojiEnabled) }.fontFamily(this.appFontFamily)
            .width('100%')
            .fontSize($r('sys.float.Body_M')).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
          Text() { EmojiSpans(this.getUIContext(), this.presentation.note.text || this.presentation.note.subtitle, $r('sys.float.Body_M'), this.systemEmojiEnabled) }.fontFamily(this.appFontFamily)
            .width('100%')
            .fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_primary'))
            .maxLines(this.expanded ? 1000 : 4).textOverflow({ overflow: TextOverflow.Ellipsis }).copyOption(CopyOptions.LocalDevice)
            .editMenuOptions(new EmojiCopyMenu(getContext(this) as common.UIAbilityContext, this.presentation.note.text || this.presentation.note.subtitle, this.systemEmojiEnabled))
          if (this.expanded) {
            ForEach(this.presentation.note.sources, (url: string) => {
              Text(url).fontFamily(this.appFontFamily).fontSize($r('sys.float.Caption_L')).fontColor(this.accentColor).maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis }).onClick((): void => this.open(url))
            }, (url: string): string => url)
            if (this.presentation.note.subtitle.length > 0 && this.presentation.note.text.length > 0) {
              Text() { EmojiSpans(this.getUIContext(), this.presentation.note.subtitle, $r('sys.float.Caption_L'), this.systemEmojiEnabled) }.fontFamily(this.appFontFamily)
                .fontSize($r('sys.float.Caption_L')).fontColor($r('app.color.text_secondary'))
            }
          }
          Row({ space: 8 }) {
            Button(this.expanded ? $r('app.string.post_show_less') : $r('app.string.post_show_more')).fontColor(this.accentColor)
              .backgroundColor(Color.Transparent).onClick((): void => { this.expanded = !this.expanded; })
            Blank()
            if (this.presentation.note.url.length > 0) {
              Button($r('app.string.card_note_rate')).fontColor(this.accentColor).backgroundColor(Color.Transparent)
                .onClick((): void => { if (this.presentation.note?.id) { this.showNote = true; } else { this.open(this.presentation.note?.url ?? ''); } })
                .bindSheet($$this.showNote, this.NoteSheet(), sheetMaterialOptions({ height: SheetSize.LARGE, showClose: true,
                  backgroundColor: $r('app.color.poll_option_surface') }, this.sheetMaterialEnabled, this.sheetMaterialLevel, this.sheetWindowBreakpoint, this.sheetCompactWindow))
            }
          }.width('100%')
        }.width('100%').alignItems(HorizontalAlign.Start).padding(12).borderRadius(14)
          .backgroundColor($r('app.color.poll_option_surface')).border({ width: 1, color: $r('app.color.divider') })
      }
    }.width('100%').alignItems(HorizontalAlign.Start).margin({ top: 8 })
  }
}
