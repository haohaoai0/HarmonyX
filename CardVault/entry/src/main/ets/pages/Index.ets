import { common } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { fileIo, picker } from '@kit.CoreFileKit';
import promptAction from '@ohos.promptAction';
import {
  CardDraft,
  CardRecord,
  CardState,
  CardStats,
  RecipientSummary
} from '../models/CardRecord';
import { CardParseResult, CardTextParser } from '../services/CardTextParser';
import { CardRepository, ImportResult } from '../services/CardRepository';

const TAB_CARDS: string = 'cards';
const TAB_RECIPIENTS: string = 'recipients';
const FILTER_ALL: string = 'all';
const FILTER_UNASSIGNED: string = 'unassigned';
const FILTER_ASSIGNED: string = 'assigned';
const FILTER_USED: string = 'used';
const FILTER_REVOKED: string = 'revoked';

@Entry
@Component
struct Index {
  private repository: CardRepository = new CardRepository();
  @State private cards: CardRecord[] = [];
  @State private keyword: string = '';
  @State private activeFilter: string = FILTER_ALL;
  @State private activeTab: string = TAB_CARDS;
  @State private recipientFilter: string = '';
  @State private loading: boolean = true;
  @State private loadError: string = '';
  @State private importMessage: string = '';
  @State private showEditor: boolean = false;
  @State private isNewCard: boolean = false;
  @State private editCardId: number = 0;
  @State private editCardKey: string = '';
  @State private editRecipient: string = '';
  @State private editDonation: string = '';
  @State private editState: string = CardState.UNUSED;
  @State private editNote: string = '';
  @State private editCreatedAt: number = 0;
  @State private saving: boolean = false;

  aboutToAppear(): void {
    this.refresh();
  }

  private context(): common.UIAbilityContext {
    return getContext(this) as common.UIAbilityContext;
  }

  private text(resource: Resource): string {
    return this.context().resourceManager.getStringSync(resource);
  }

  private async refresh(): Promise<void> {
    this.loading = true;
    this.loadError = '';
    try {
      this.cards = await this.repository.listCards(this.context());
    } catch (error) {
      this.loadError = this.text($r('app.string.load_failed'));
    } finally {
      this.loading = false;
    }
  }

  private stats(): CardStats {
    return new CardStats(this.cards);
  }

  private visibleCards(): CardRecord[] {
    const query: string = this.keyword.trim().toLowerCase();
    const output: CardRecord[] = [];
    for (let i: number = 0; i < this.cards.length; i++) {
      const card: CardRecord = this.cards[i];
      if (this.recipientFilter.length > 0 && card.recipient !== this.recipientFilter) {
        continue;
      }
      if (!this.matchesState(card)) {
        continue;
      }
      if (query.length > 0) {
        const searchable: string =
          (card.cardKey + ' ' + card.recipient + ' ' + card.note).toLowerCase();
        if (!searchable.includes(query)) {
          continue;
        }
      }
      output.push(card);
    }
    return output;
  }

  private matchesState(card: CardRecord): boolean {
    if (this.activeFilter === FILTER_ALL) {
      return true;
    }
    if (this.activeFilter === FILTER_USED) {
      return card.state === CardState.USED;
    }
    if (this.activeFilter === FILTER_REVOKED) {
      return card.state === CardState.REVOKED;
    }
    if (card.state !== CardState.UNUSED) {
      return false;
    }
    if (this.activeFilter === FILTER_UNASSIGNED) {
      return card.recipient.length === 0;
    }
    return card.recipient.length > 0;
  }

  private recipients(): RecipientSummary[] {
    const query: string = this.keyword.trim().toLowerCase();
    const byName: Map<string, RecipientSummary> = new Map<string, RecipientSummary>();
    for (let i: number = 0; i < this.cards.length; i++) {
      const card: CardRecord = this.cards[i];
      if (card.recipient.length === 0) {
        continue;
      }
      if (query.length > 0 && !card.recipient.toLowerCase().includes(query)) {
        continue;
      }
      let summary: RecipientSummary | undefined = byName.get(card.recipient);
      if (summary === undefined) {
        summary = new RecipientSummary(card.recipient, 0, 0, 0);
        byName.set(card.recipient, summary);
      }
      summary.cardCount += 1;
      summary.donation += card.donation;
      if (card.state === CardState.USED) {
        summary.usedCount += 1;
      }
    }
    const output: RecipientSummary[] = Array.from(byName.values());
    output.sort((left: RecipientSummary, right: RecipientSummary): number => {
      if (right.donation !== left.donation) {
        return right.donation - left.donation;
      }
      return right.cardCount - left.cardCount;
    });
    return output;
  }

  private recentRecipients(): string[] {
    const names: Set<string> = new Set<string>();
    const output: string[] = [];
    for (let i: number = 0; i < this.cards.length && output.length < 8; i++) {
      const name: string = this.cards[i].recipient.trim();
      if (name.length > 0 && !names.has(name)) {
        names.add(name);
        output.push(name);
      }
    }
    return output;
  }

  private derivedStatus(card: CardRecord): string {
    if (card.state === CardState.USED) {
      return FILTER_USED;
    }
    if (card.state === CardState.REVOKED) {
      return FILTER_REVOKED;
    }
    return card.recipient.length > 0 ? FILTER_ASSIGNED : FILTER_UNASSIGNED;
  }

  private statusText(status: string): ResourceStr {
    if (status === FILTER_USED) {
      return $r('app.string.status_used');
    }
    if (status === FILTER_REVOKED) {
      return $r('app.string.status_revoked');
    }
    if (status === FILTER_ASSIGNED) {
      return $r('app.string.status_assigned');
    }
    return $r('app.string.status_unassigned');
  }

  private statusColor(status: string): ResourceColor {
    if (status === FILTER_USED) {
      return $r('app.color.positive');
    }
    if (status === FILTER_REVOKED) {
      return $r('app.color.danger');
    }
    if (status === FILTER_ASSIGNED) {
      return $r('app.color.accent_text');
    }
    return $r('app.color.text_secondary');
  }

  private statusBackground(status: string): ResourceColor {
    if (status === FILTER_USED) {
      return $r('app.color.positive_soft');
    }
    if (status === FILTER_REVOKED) {
      return $r('app.color.danger_soft');
    }
    if (status === FILTER_ASSIGNED) {
      return $r('app.color.accent_soft');
    }
    return $r('app.color.neutral_soft');
  }

  private displayKey(key: string): string {
    if (key.length <= 24) {
      return key;
    }
    return key.substring(0, 10) + '••••' + key.substring(key.length - 8);
  }

  private formatMoney(value: number): string {
    return '¥' + value.toFixed(2);
  }

  private formatDate(timestamp: number): string {
    const date: Date = new Date(timestamp);
    const year: string = date.getFullYear().toString();
    const month: string = (date.getMonth() + 1).toString().padStart(2, '0');
    const day: string = date.getDate().toString().padStart(2, '0');
    return year + '-' + month + '-' + day;
  }

  private selectFilter(filter: string): void {
    this.activeFilter = filter;
    this.recipientFilter = '';
  }

  private openNew(): void {
    this.isNewCard = true;
    this.editCardId = 0;
    this.editCardKey = '';
    this.editRecipient = '';
    this.editDonation = '';
    this.editState = CardState.UNUSED;
    this.editNote = '';
    this.editCreatedAt = Date.now();
    this.showEditor = true;
  }

  private openEdit(card: CardRecord): void {
    this.isNewCard = false;
    this.editCardId = card.id;
    this.editCardKey = card.cardKey;
    this.editRecipient = card.recipient;
    this.editDonation = card.donation > 0 ? card.donation.toFixed(2) : '';
    this.editState = card.state;
    this.editNote = card.note;
    this.editCreatedAt = card.createdAt;
    this.showEditor = true;
  }

  private closeEditor(): void {
    if (this.saving) {
      return;
    }
    this.showEditor = false;
  }

  private parsedDonation(): number {
    const cleaned: string = this.editDonation.replace(/[¥￥,\s]/g, '');
    if (cleaned.length === 0) {
      return 0;
    }
    const value: number = Number(cleaned);
    if (Number.isNaN(value) || value < 0) {
      return 0;
    }
    return Math.round(value * 100) / 100;
  }

  private async saveEditor(): Promise<void> {
    if (this.saving) {
      return;
    }
    const key: string = this.editCardKey.trim().replace(/\s+/g, '');
    if (key.length === 0) {
      promptAction.showToast({ message: $r('app.string.card_key_required') });
      return;
    }
    if (!/^[A-Za-z0-9][A-Za-z0-9_-]{5,127}$/.test(key)) {
      promptAction.showToast({ message: $r('app.string.card_key_invalid') });
      return;
    }
    this.saving = true;
    try {
      if (this.isNewCard) {
        const draft: CardDraft = new CardDraft(key, this.editRecipient.trim(), this.parsedDonation(),
          this.editState, this.editNote.trim(), this.editCreatedAt);
        await this.repository.insertCard(this.context(), draft);
      } else {
        const card: CardRecord = new CardRecord(this.editCardId, this.editCardKey,
          this.editRecipient.trim(), this.parsedDonation(), this.editState, this.editNote.trim(),
          this.editCreatedAt, Date.now());
        await this.repository.updateCard(this.context(), card);
      }
      this.showEditor = false;
      await this.refresh();
    } catch (error) {
      const message: string = (error as Error).message;
      const toast: ResourceStr = message.includes('UNIQUE') ?
        $r('app.string.card_key_exists') : $r('app.string.save_failed');
      promptAction.showToast({ message: toast });
    } finally {
      this.saving = false;
    }
  }

  private async copyCard(card: CardRecord): Promise<void> {
    try {
      await pasteboard.getSystemPasteboard().setPasteData(
        pasteboard.createPlainTextData(card.cardKey));
      promptAction.showToast({ message: $r('app.string.copy_success') });
    } catch (error) {
      promptAction.showToast({ message: $r('app.string.save_failed') });
    }
  }

  private confirmDelete(card: CardRecord): void {
    AlertDialog.show({
      title: $r('app.string.delete_confirm_title'),
      message: $r('app.string.delete_confirm_message'),
      primaryButton: {
        value: $r('app.string.action_cancel'),
        action: (): void => {
        }
      },
      secondaryButton: {
        value: $r('app.string.action_delete'),
        fontColor: $r('app.color.danger'),
        action: (): void => {
          this.deleteCard(card.id);
        }
      }
    });
  }

  private async deleteCard(id: number): Promise<void> {
    try {
      await this.repository.deleteCard(this.context(), id);
      this.showEditor = false;
      await this.refresh();
      promptAction.showToast({ message: $r('app.string.delete_success') });
    } catch (error) {
      promptAction.showToast({ message: $r('app.string.save_failed') });
    }
  }

  private async importTxt(): Promise<void> {
    let tempPath: string = '';
    try {
      const dialog: picker.DocumentViewPicker = new picker.DocumentViewPicker(this.context());
      const options: picker.DocumentSelectOptions = {
        maxSelectNumber: 1,
        fileSuffixFilters: ['文本文件|.txt']
      };
      const uris: string[] = await dialog.select(options);
      if (uris.length === 0) {
        return;
      }
      tempPath = this.context().cacheDir + '/card-import-' + Date.now() + '.txt';
      const source: fileIo.File = fileIo.openSync(uris[0], fileIo.OpenMode.READ_ONLY);
      try {
        fileIo.copyFileSync(source.fd, tempPath);
      } finally {
        fileIo.closeSync(source.fd);
      }
      const text: string = fileIo.readTextSync(tempPath);
      const parsed: CardParseResult = CardTextParser.parse(text);
      const result: ImportResult = await this.repository.importCards(this.context(),
        parsed.rows, parsed.duplicateLines, parsed.invalidLines);
      this.importMessage = this.text($r('app.string.import_done')) + ' · ' +
        this.text($r('app.string.import_added')) + ' ' + result.added.toString() + ' · ' +
        this.text($r('app.string.import_existing')) + ' ' +
        (result.existing + result.duplicateLines).toString() + ' · ' +
        this.text($r('app.string.import_invalid')) + ' ' + result.invalidLines.toString();
      await this.refresh();
    } catch (error) {
      promptAction.showToast({ message: $r('app.string.import_failed') });
    } finally {
      if (tempPath.length > 0) {
        try {
          fileIo.unlinkSync(tempPath);
        } catch (error) {
        }
      }
    }
  }

  @Builder
  private Header() {
    Row() {
      Column({ space: 3 }) {
        Text($r('app.string.app_title'))
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text($r('app.string.app_tagline'))
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Row({ space: 8 }) {
        Button({ type: ButtonType.Normal }) {
          Row({ space: 6 }) {
            SymbolGlyph($r('sys.symbol.square_and_arrow_down'))
              .fontSize(17)
              .fontColor([$r('app.color.accent')])
            Text($r('app.string.action_import'))
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.accent'))
          }
        }
        .height(40)
        .padding({ left: 12, right: 12 })
        .borderRadius(14)
        .backgroundColor($r('app.color.accent_soft'))
        .onClick((): void => {
          this.importTxt();
        })
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.plus'))
            .fontSize(19)
            .fontColor([$r('app.color.accent')])
        }
        .width(40)
        .height(40)
        .backgroundColor($r('app.color.accent_soft'))
        .onClick((): void => {
          this.openNew();
        })
      }
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 16, bottom: 12 })
  }

  @Builder
  private SummaryHero() {
    Column({ space: 18 }) {
      Row() {
        Column({ space: 5 }) {
          Text($r('app.string.summary_total'))
            .fontSize(12)
            .fontColor($r('app.color.hero_muted'))
          Text(this.stats().total.toString())
            .fontSize(42)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.hero_text'))
        }
        .alignItems(HorizontalAlign.Start)
        Blank()
        Column({ space: 5 }) {
          Text($r('app.string.summary_donation'))
            .fontSize(12)
            .fontColor($r('app.color.hero_muted'))
          Text(this.formatMoney(this.stats().donation))
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.hero_text'))
        }
        .alignItems(HorizontalAlign.End)
      }
      .width('100%')
      Row({ space: 0 }) {
        Column({ space: 3 }) {
          Text(this.stats().assigned.toString())
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.hero_text'))
          Text($r('app.string.filter_assigned'))
            .fontSize(11)
            .fontColor($r('app.color.hero_muted'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Column({ space: 3 }) {
          Text(this.stats().used.toString())
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.hero_text'))
          Text($r('app.string.filter_used'))
            .fontSize(11)
            .fontColor($r('app.color.hero_muted'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Column({ space: 3 }) {
          Text(this.stats().recipients.toString())
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.hero_text'))
          Text($r('app.string.summary_recipients'))
            .fontSize(11)
            .fontColor($r('app.color.hero_muted'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding({ top: 14 })
      .border({ width: { top: 1 }, color: '#33FFFFFF' })
    }
    .width('100%')
    .padding(20)
    .borderRadius(24)
    .linearGradient({
      angle: 135,
      colors: [[$r('app.color.hero_start'), 0], [$r('app.color.hero_end'), 1]]
    })
  }

  @Builder
  private TabSwitch() {
    Row() {
      Button({ type: ButtonType.Normal }) {
        Text($r('app.string.tab_cards'))
          .fontSize(14)
          .fontWeight(this.activeTab === TAB_CARDS ? FontWeight.Bold : FontWeight.Medium)
          .fontColor(this.activeTab === TAB_CARDS ?
            $r('app.color.text_primary') : $r('app.color.text_secondary'))
      }
      .layoutWeight(1)
      .height(38)
      .borderRadius(11)
      .backgroundColor(this.activeTab === TAB_CARDS ?
        $r('app.color.surface') : Color.Transparent)
      .onClick((): void => {
        this.activeTab = TAB_CARDS;
      })
      Button({ type: ButtonType.Normal }) {
        Text($r('app.string.tab_recipients'))
          .fontSize(14)
          .fontWeight(this.activeTab === TAB_RECIPIENTS ? FontWeight.Bold : FontWeight.Medium)
          .fontColor(this.activeTab === TAB_RECIPIENTS ?
            $r('app.color.text_primary') : $r('app.color.text_secondary'))
      }
      .layoutWeight(1)
      .height(38)
      .borderRadius(11)
      .backgroundColor(this.activeTab === TAB_RECIPIENTS ?
        $r('app.color.surface') : Color.Transparent)
      .onClick((): void => {
        this.activeTab = TAB_RECIPIENTS;
      })
    }
    .width('100%')
    .padding(4)
    .borderRadius(15)
    .backgroundColor($r('app.color.surface_strong'))
  }

  @Builder
  private FilterChip(label: Resource, value: string) {
    Button({ type: ButtonType.Normal }) {
      Text(label)
        .fontSize(12)
        .fontWeight(this.activeFilter === value ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(this.activeFilter === value ?
          $r('app.color.accent_text') : $r('app.color.text_secondary'))
    }
    .height(32)
    .padding({ left: 13, right: 13 })
    .borderRadius(16)
    .backgroundColor(this.activeFilter === value ?
      $r('app.color.accent_soft') : $r('app.color.surface'))
    .border({
      width: 1,
      color: this.activeFilter === value ? $r('app.color.accent_soft') : $r('app.color.line')
    })
    .onClick((): void => {
      this.selectFilter(value);
    })
  }

  @Builder
  private StatusPill(status: string) {
    Text(this.statusText(status))
      .fontSize(11)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.statusColor(status))
      .padding({ left: 9, right: 9, top: 5, bottom: 5 })
      .borderRadius(10)
      .backgroundColor(this.statusBackground(status))
  }

  @Builder
  private CardRow(card: CardRecord) {
    Column({ space: 12 }) {
      Row({ space: 10 }) {
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.key'))
            .fontSize(17)
            .fontColor([$r('app.color.accent')])
          Text(this.displayKey(card.cardKey))
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .letterSpacing(0.4)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        this.StatusPill(this.derivedStatus(card))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      Row({ space: 8 }) {
        Row({ space: 5 }) {
          SymbolGlyph($r('sys.symbol.person_2'))
            .fontSize(14)
            .fontColor([$r('app.color.text_secondary')])
          Text(card.recipient.length > 0 ?
            card.recipient : $r('app.string.recipient_unassigned'))
            .fontSize(13)
            .fontColor(card.recipient.length > 0 ?
              $r('app.color.text_primary') : $r('app.color.text_tertiary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        Row({ space: 4 }) {
          SymbolGlyph($r('sys.symbol.gift'))
            .fontSize(13)
            .fontColor([card.donation > 0 ?
              $r('app.color.warning') : $r('app.color.text_tertiary')])
          Text(card.donation > 0 ?
            this.formatMoney(card.donation) : $r('app.string.donation_none'))
            .fontSize(12)
            .fontWeight(card.donation > 0 ? FontWeight.Bold : FontWeight.Regular)
            .fontColor(card.donation > 0 ?
              $r('app.color.warning') : $r('app.color.text_tertiary'))
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      if (card.note.length > 0) {
        Text(card.note)
          .width('100%')
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .padding({ left: 10, right: 10, top: 8, bottom: 8 })
          .borderRadius(10)
          .backgroundColor($r('app.color.surface_alt'))
      }
      Row({ space: 8 }) {
        Text(this.formatDate(card.updatedAt))
          .fontSize(11)
          .fontColor($r('app.color.text_tertiary'))
        Blank()
        Button({ type: ButtonType.Normal }) {
          Row({ space: 5 }) {
            SymbolGlyph($r('sys.symbol.rectangle_on_rectangle'))
              .fontSize(14)
              .fontColor([$r('app.color.text_secondary')])
            Text($r('app.string.action_copy'))
              .fontSize(11)
              .fontColor($r('app.color.text_secondary'))
          }
        }
        .height(30)
        .padding({ left: 9, right: 9 })
        .borderRadius(9)
        .backgroundColor($r('app.color.surface_alt'))
        .onClick((): void => {
          this.copyCard(card);
        })
        Button({ type: ButtonType.Normal }) {
          Row({ space: 5 }) {
            SymbolGlyph($r('sys.symbol.pencil_line'))
              .fontSize(14)
              .fontColor([$r('app.color.accent')])
            Text($r('app.string.action_edit'))
              .fontSize(11)
              .fontColor($r('app.color.accent'))
          }
        }
        .height(30)
        .padding({ left: 9, right: 9 })
        .borderRadius(9)
        .backgroundColor($r('app.color.accent_soft'))
        .onClick((): void => {
          this.openEdit(card);
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding(16)
    .borderRadius(18)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.line') })
  }

  @Builder
  private RecipientRow(summary: RecipientSummary) {
    Row({ space: 14 }) {
      Text(summary.name.substring(0, 1))
        .width(44)
        .height(44)
        .textAlign(TextAlign.Center)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.accent_text'))
        .borderRadius(15)
        .backgroundColor($r('app.color.accent_soft'))
      Column({ space: 4 }) {
        Text(summary.name)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(summary.cardCount.toString() + ' ' +
          this.text($r('app.string.recipient_card_count')) + ' · ' +
          this.text($r('app.string.recipient_used_count')) + ' ' + summary.usedCount.toString())
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Column({ space: 4 }) {
        Text(this.formatMoney(summary.donation))
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(summary.donation > 0 ?
            $r('app.color.warning') : $r('app.color.text_tertiary'))
        Text($r('app.string.recipient_donation'))
          .fontSize(10)
          .fontColor($r('app.color.text_tertiary'))
      }
      .alignItems(HorizontalAlign.End)
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(13)
        .fontColor([$r('app.color.text_tertiary')])
    }
    .width('100%')
    .padding(16)
    .borderRadius(18)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.line') })
    .onClick((): void => {
      this.recipientFilter = summary.name;
      this.activeFilter = FILTER_ALL;
      this.activeTab = TAB_CARDS;
    })
  }

  @Builder
  private EmptyState(recipientMode: boolean) {
    Column({ space: 12 }) {
      SymbolGlyph(recipientMode ? $r('sys.symbol.person_2') : $r('sys.symbol.key'))
        .fontSize(38)
        .fontColor([$r('app.color.text_tertiary')])
      Text(recipientMode ?
        $r('app.string.empty_recipient_title') : $r('app.string.empty_title'))
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Text(recipientMode ?
        $r('app.string.empty_recipient_desc') : $r('app.string.empty_desc'))
        .width('85%')
        .fontSize(12)
        .lineHeight(19)
        .textAlign(TextAlign.Center)
        .fontColor($r('app.color.text_secondary'))
    }
    .width('100%')
    .padding({ top: 48, bottom: 48, left: 20, right: 20 })
    .borderRadius(20)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.line') })
  }

  @Builder
  private StateChip(label: Resource, value: string) {
    Text(label)
      .fontSize(12)
      .fontWeight(this.editState === value ? FontWeight.Bold : FontWeight.Medium)
      .fontColor(this.editState === value ?
        $r('app.color.accent_text') : $r('app.color.text_secondary'))
      .textAlign(TextAlign.Center)
      .layoutWeight(1)
      .padding({ top: 10, bottom: 10 })
      .borderRadius(11)
      .backgroundColor(this.editState === value ?
        $r('app.color.accent_soft') : $r('app.color.surface_alt'))
      .onClick((): void => {
        this.editState = value;
      })
  }

  @Builder
  private InputLabel(label: Resource) {
    Text(label)
      .fontSize(12)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.text_secondary'))
  }

  @Builder
  private EditorOverlay() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.scrim'))
        .onClick((): void => {
          this.closeEditor();
        })
      Column() {
        Row()
          .width(40)
          .height(4)
          .borderRadius(2)
          .backgroundColor($r('app.color.line'))
          .margin({ top: 10, bottom: 8 })
        Row() {
          Column({ space: 3 }) {
            Text(this.isNewCard ?
              $r('app.string.editor_new_title') : $r('app.string.editor_edit_title'))
              .fontSize(21)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
            Text(this.isNewCard ? $r('app.string.import_hint') : this.displayKey(this.editCardKey))
              .fontSize(11)
              .fontColor($r('app.color.text_secondary'))
              .maxLines(2)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          Button({ type: ButtonType.Circle }) {
            SymbolGlyph($r('sys.symbol.xmark_circle'))
              .fontSize(24)
              .fontColor([$r('app.color.text_tertiary')])
          }
          .width(38)
          .height(38)
          .backgroundColor(Color.Transparent)
          .onClick((): void => {
            this.closeEditor();
          })
        }
        .width('100%')
        .padding({ bottom: 14 })
        Scroll() {
          Column({ space: 10 }) {
            this.InputLabel($r('app.string.card_key_label'))
            TextInput({
              text: this.editCardKey,
              placeholder: $r('app.string.card_key_placeholder')
            })
              .height(44)
              .fontSize(14)
              .fontColor(this.isNewCard ?
                $r('app.color.text_primary') : $r('app.color.text_secondary'))
              .backgroundColor($r('app.color.surface_alt'))
              .borderRadius(12)
              .enabled(this.isNewCard)
              .onChange((value: string): void => {
                this.editCardKey = value;
              })
            this.InputLabel($r('app.string.recipient_label'))
            TextInput({
              text: this.editRecipient,
              placeholder: $r('app.string.recipient_placeholder')
            })
              .height(44)
              .fontSize(14)
              .backgroundColor($r('app.color.surface_alt'))
              .borderRadius(12)
              .onChange((value: string): void => {
                this.editRecipient = value;
              })
            if (this.recentRecipients().length > 0) {
              Column({ space: 7 }) {
                Text($r('app.string.recipient_suggestions'))
                  .fontSize(10)
                  .fontColor($r('app.color.text_tertiary'))
                Scroll() {
                  Row({ space: 6 }) {
                    ForEach(this.recentRecipients(), (name: string) => {
                      Text(name)
                        .fontSize(11)
                        .fontColor($r('app.color.accent_text'))
                        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                        .borderRadius(9)
                        .backgroundColor($r('app.color.accent_soft'))
                        .onClick((): void => {
                          this.editRecipient = name;
                        })
                    }, (name: string): string => name)
                  }
                }
                .scrollable(ScrollDirection.Horizontal)
                .scrollBar(BarState.Off)
              }
              .alignItems(HorizontalAlign.Start)
            }
            this.InputLabel($r('app.string.donation_label'))
            TextInput({
              text: this.editDonation,
              placeholder: $r('app.string.donation_placeholder')
            })
              .height(44)
              .type(InputType.Number)
              .fontSize(14)
              .backgroundColor($r('app.color.surface_alt'))
              .borderRadius(12)
              .onChange((value: string): void => {
                this.editDonation = value;
              })
            this.InputLabel($r('app.string.status_label'))
            Row({ space: 8 }) {
              this.StateChip($r('app.string.status_unassigned'), CardState.UNUSED)
              this.StateChip($r('app.string.status_used'), CardState.USED)
              this.StateChip($r('app.string.status_revoked'), CardState.REVOKED)
            }
            .width('100%')
            this.InputLabel($r('app.string.note_label'))
            TextArea({
              text: this.editNote,
              placeholder: $r('app.string.note_placeholder')
            })
              .height(82)
              .fontSize(13)
              .backgroundColor($r('app.color.surface_alt'))
              .borderRadius(12)
              .onChange((value: string): void => {
                this.editNote = value;
              })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding({ bottom: 14 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        Row({ space: 10 }) {
          if (!this.isNewCard) {
            Button({ type: ButtonType.Normal }) {
              Text($r('app.string.action_delete'))
                .fontSize(13)
                .fontColor($r('app.color.danger'))
            }
            .height(44)
            .padding({ left: 14, right: 14 })
            .borderRadius(13)
            .backgroundColor($r('app.color.danger_soft'))
            .onClick((): void => {
              const card: CardRecord = new CardRecord(this.editCardId, this.editCardKey,
                this.editRecipient, this.parsedDonation(), this.editState, this.editNote,
                this.editCreatedAt, Date.now());
              this.confirmDelete(card);
            })
          }
          Blank()
          Button({ type: ButtonType.Normal }) {
            Text($r('app.string.action_cancel'))
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
          }
          .height(44)
          .padding({ left: 16, right: 16 })
          .borderRadius(13)
          .backgroundColor($r('app.color.surface_alt'))
          .onClick((): void => {
            this.closeEditor();
          })
          Button({ type: ButtonType.Normal }) {
            Row({ space: 6 }) {
              if (this.saving) {
                LoadingProgress()
                  .width(15)
                  .height(15)
                  .color($r('app.color.hero_text'))
              }
              Text($r('app.string.action_save'))
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.hero_text'))
            }
          }
          .height(44)
          .padding({ left: 20, right: 20 })
          .borderRadius(13)
          .backgroundColor($r('app.color.accent'))
          .enabled(!this.saving)
          .onClick((): void => {
            this.saveEditor();
          })
        }
        .width('100%')
        .padding({ top: 10, bottom: 8 })
      }
      .width('100%')
      .height('88%')
      .padding({ left: 20, right: 20 })
      .borderRadius({ topLeft: 28, topRight: 28 })
      .backgroundColor($r('app.color.surface'))
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        this.Header()
        List({ space: 12 }) {
          ListItem() {
            this.SummaryHero()
          }
          ListItem() {
            this.TabSwitch()
          }
          if (this.activeTab === TAB_CARDS) {
            ListItem() {
              Search({
                value: this.keyword,
                placeholder: $r('app.string.search_placeholder')
              })
                .width('100%')
                .height(44)
                .backgroundColor($r('app.color.surface'))
                .borderRadius(13)
                .placeholderColor($r('app.color.text_tertiary'))
                .textFont({ size: 13 })
                .onChange((value: string): void => {
                  this.keyword = value;
                })
            }
            ListItem() {
              Scroll() {
                Row({ space: 7 }) {
                  this.FilterChip($r('app.string.filter_all'), FILTER_ALL)
                  this.FilterChip($r('app.string.filter_unassigned'), FILTER_UNASSIGNED)
                  this.FilterChip($r('app.string.filter_assigned'), FILTER_ASSIGNED)
                  this.FilterChip($r('app.string.filter_used'), FILTER_USED)
                  this.FilterChip($r('app.string.filter_revoked'), FILTER_REVOKED)
                }
              }
              .width('100%')
              .scrollable(ScrollDirection.Horizontal)
              .scrollBar(BarState.Off)
            }
            if (this.recipientFilter.length > 0) {
              ListItem() {
                Row({ space: 8 }) {
                  Text($r('app.string.filter_recipient'))
                    .fontSize(11)
                    .fontColor($r('app.color.text_secondary'))
                  Text(this.recipientFilter)
                    .fontSize(12)
                    .fontWeight(FontWeight.Bold)
                    .fontColor($r('app.color.accent_text'))
                    .layoutWeight(1)
                  Text($r('app.string.clear_filter'))
                    .fontSize(11)
                    .fontColor($r('app.color.accent'))
                    .onClick((): void => {
                      this.recipientFilter = '';
                    })
                }
                .width('100%')
                .padding({ left: 13, right: 13, top: 10, bottom: 10 })
                .borderRadius(12)
                .backgroundColor($r('app.color.accent_soft'))
              }
            }
            if (this.importMessage.length > 0) {
              ListItem() {
                Row({ space: 8 }) {
                  SymbolGlyph($r('sys.symbol.checkmark_circle'))
                    .fontSize(17)
                    .fontColor([$r('app.color.positive')])
                  Text(this.importMessage)
                    .fontSize(11)
                    .fontColor($r('app.color.positive'))
                    .layoutWeight(1)
                  SymbolGlyph($r('sys.symbol.xmark_circle'))
                    .fontSize(17)
                    .fontColor([$r('app.color.text_tertiary')])
                    .onClick((): void => {
                      this.importMessage = '';
                    })
                }
                .width('100%')
                .padding(12)
                .borderRadius(12)
                .backgroundColor($r('app.color.positive_soft'))
              }
            }
            if (this.loading) {
              ListItem() {
                Row({ space: 10 }) {
                  LoadingProgress()
                    .width(20)
                    .height(20)
                    .color($r('app.color.accent'))
                  Text($r('app.string.load_failed'))
                    .fontSize(12)
                    .fontColor($r('app.color.text_secondary'))
                }
                .width('100%')
                .justifyContent(FlexAlign.Center)
                .padding(28)
              }
            } else if (this.loadError.length > 0) {
              ListItem() {
                Text(this.loadError)
                  .width('100%')
                  .textAlign(TextAlign.Center)
                  .fontSize(13)
                  .fontColor($r('app.color.danger'))
                  .padding(24)
                  .borderRadius(16)
                  .backgroundColor($r('app.color.danger_soft'))
              }
            } else if (this.visibleCards().length === 0) {
              ListItem() {
                this.EmptyState(false)
              }
            } else {
              ListItem() {
                Row() {
                  Text(this.visibleCards().length.toString() + ' ' +
                    this.text($r('app.string.records_count')))
                    .fontSize(11)
                    .fontColor($r('app.color.text_tertiary'))
                  Blank()
                  Text(this.text($r('app.string.import_hint')))
                    .fontSize(9)
                    .fontColor($r('app.color.text_tertiary'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .width('58%')
                }
                .width('100%')
              }
              ForEach(this.visibleCards(), (card: CardRecord) => {
                ListItem() {
                  this.CardRow(card)
                }
              }, (card: CardRecord): string => card.id.toString())
            }
          } else {
            ListItem() {
              Search({
                value: this.keyword,
                placeholder: $r('app.string.search_placeholder')
              })
                .width('100%')
                .height(44)
                .backgroundColor($r('app.color.surface'))
                .borderRadius(13)
                .placeholderColor($r('app.color.text_tertiary'))
                .textFont({ size: 13 })
                .onChange((value: string): void => {
                  this.keyword = value;
                })
            }
            if (this.recipients().length === 0) {
              ListItem() {
                this.EmptyState(true)
              }
            } else {
              ForEach(this.recipients(), (summary: RecipientSummary) => {
                ListItem() {
                  this.RecipientRow(summary)
                }
              }, (summary: RecipientSummary): string => summary.name)
            }
          }
          ListItem() {
            Row()
              .height(18)
          }
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 20, right: 20 })
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.app_bg'))
      if (this.showEditor) {
        this.EditorOverlay()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.app_bg'))
  }
}
