import { common } from '@kit.AbilityKit';
import promptAction from '@ohos.promptAction';
import hilog from '@ohos.hilog';
import { BusinessError } from '@kit.BasicServicesKit';
import { ComposerOptions, ComposerCoordinates, ComposerPlace, ComposerScheduledPost, replyModeLabel } from '../models/ComposerOptions';
import { xPrivateClient, XPrivateResult } from '../services/XPrivateClient';
import { composerPlaces, composerScheduledPosts } from '../services/XComposerRequest';
import { getComposerLocation, ComposerLocationResult } from '../services/ComposerLocation';
import { ChatEmojiPanel } from './ChatEmojiPanel';
import { sheetMaterialOptions } from '../utils/SheetMaterial';
import { DEFAULT_SHEET_MATERIAL_LEVEL, STORAGE_KEY_SHEET_MATERIAL_ENABLED,
  STORAGE_KEY_SHEET_MATERIAL_LEVEL } from '../services/SheetMaterialSettingsStore';

@Component
export struct ComposerTools {
  @StorageProp('harmonyx.compact_window') private compactWindow: boolean = false;
  @StorageProp('harmonyx.breakpoint') private sheetWindowBreakpoint: string = 'sm';
  @Link options: ComposerOptions;
  @Prop disabled: boolean = false;
  @Prop hasMedia: boolean = false;
  @Prop community: boolean = false;
  @Prop isReply: boolean = false;
  @Prop accentColor: string = '#007DFF';
  @BuilderParam leadingActions: () => void;
  @BuilderParam trailingActions: () => void;
  onChange: () => void = (): void => {};
  onOpen: () => void = (): void => {};
  onEmoji: (emoji: string) => void = (_emoji: string): void => {};
  @StorageProp(STORAGE_KEY_SHEET_MATERIAL_ENABLED) materialEnabled: boolean = false;
  @StorageProp(STORAGE_KEY_SHEET_MATERIAL_LEVEL) materialLevel: number = DEFAULT_SHEET_MATERIAL_LEVEL;
  @State private visible: boolean = false;
  @State private sheet: string = '';
  @State private candidateDate: number = 0;
  @State private query: string = '';
  @State private places: ComposerPlace[] = [];
  @State private scheduled: ComposerScheduledPost[] = [];
  @State private loading: boolean = false;
  @State private error: string = '';
  @State private locationLoading: boolean = false;
  @State private locationError: string = '';
  private coordinates: ComposerCoordinates | null = null;
  private locationRevision: number = 0;
  private pendingEmoji: string = '';
  private queryTimer: number = -1;
  private queryRevision: number = 0;
  private alive: boolean = true;

  aboutToAppear(): void { this.alive = true; }
  aboutToDisappear(): void {
    this.alive = false; this.queryRevision++; this.locationRevision++;
    if (this.queryTimer >= 0) { clearTimeout(this.queryTimer); }
  }
  private text(resource: Resource): string { return getContext(this).resourceManager.getStringSync(resource.id); }
  private open(sheet: string): void {
    if (this.disabled) { return; }
    hilog.info(0x0000, 'HXComposerTools', 'open %{public}s', sheet);
    this.stopEditing(); this.sheet = sheet; this.error = ''; this.visible = true;
    if (sheet === 'schedule') {
      this.candidateDate = this.options.scheduledAt > 0 ? this.options.scheduledAt :
        Math.ceil((Date.now() + 86400000) / 60000) * 60000;
    }
    if (sheet === 'location') {
      this.query = ''; this.places = []; this.queryRevision++; this.coordinates = null;
      this.locate();
    }
  }
  private stopEditing(): void {
    try {
      this.onOpen();
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      hilog.warn(0x0000, 'HXComposerTools', 'stop editing failed code=%{public}d', failure.code);
    }
  }
  private change(next: ComposerOptions): void { this.options = next; this.onChange(); }
  private addPoll(): void {
    if (this.hasMedia || this.options.scheduledAt > 0) {
      promptAction.showToast({ message: this.text($r('app.string.compose_poll_conflict')) }); return;
    }
    const next: ComposerOptions = this.options.copy();
    if (next.pollChoices.length === 0) { next.pollChoices = ['', '']; }
    this.change(next); this.stopEditing();
  }
  private scheduleAllowed(): boolean {
    return !this.community && this.options.pollChoices.length === 0 && this.options.replyMode.length === 0 &&
      this.options.placeId.length === 0;
  }
  private confirmSchedule(): void {
    if (this.disabled) { return; }
    if (!this.scheduleAllowed()) { this.error = this.text($r('app.string.compose_schedule_conflict')); return; }
    if (this.candidateDate < Date.now() + 60000 || this.candidateDate > Date.now() + 548 * 86400000) {
      this.error = this.text($r('app.string.compose_schedule_invalid')); return;
    }
    const next: ComposerOptions = this.options.copy(); next.scheduledAt = this.candidateDate;
    this.change(next); this.visible = false;
  }
  private chooseDate(): void {
    const limit: Date = new Date(Date.now() + 548 * 86400000);
    this.getUIContext().showDatePickerDialog({ start: new Date(), end: limit, selected: new Date(this.candidateDate),
      onAccept: (value: DatePickerResult): void => {
        if (value.year === undefined || value.month === undefined || value.day === undefined) { return; }
        const date: Date = new Date(this.candidateDate); date.setFullYear(value.year, value.month, value.day);
        this.candidateDate = date.getTime();
      } });
  }
  private chooseTime(): void {
    this.getUIContext().showTimePickerDialog({ selected: new Date(this.candidateDate), useMilitaryTime: true,
      format: TimePickerFormat.HOUR_MINUTE, onAccept: (value: TimePickerResult): void => {
        if (value.hour === undefined || value.minute === undefined) { return; }
        const date: Date = new Date(this.candidateDate); date.setHours(value.hour, value.minute, 0, 0);
        this.candidateDate = date.getTime();
      } });
  }
  private search(value: string): void {
    this.query = value; this.error = ''; this.places = []; this.queryRevision++;
    if (this.queryTimer >= 0) { clearTimeout(this.queryTimer); }
    if (value.trim().length === 0 && this.coordinates === null) { this.loading = false; return; }
    this.loading = true;
    const revision: number = this.queryRevision;
    this.queryTimer = setTimeout((): void => { this.queryTimer = -1; this.findPlaces(value, revision); }, 350);
  }
  private async findPlaces(query: string, revision: number): Promise<void> {
    const generation: number = xPrivateClient.sessionGeneration();
    const result: XPrivateResult = await xPrivateClient.searchComposePlaces(query, this.coordinates);
    if (!this.alive || !this.visible || this.sheet !== 'location' || revision !== this.queryRevision ||
      generation !== xPrivateClient.sessionGeneration()) { return; }
    this.loading = false;
    if (!result.ok) { this.error = this.requestError(result); return; }
    this.places = composerPlaces(result.body);
    hilog.info(0x0000, 'HXComposerTools', 'places status=%{public}d count=%{public}d', result.status, this.places.length);
  }
  private async locate(): Promise<void> {
    if (this.locationLoading) { return; }
    this.locationLoading = true; this.locationError = '';
    const revision: number = ++this.locationRevision;
    const generation: number = xPrivateClient.sessionGeneration();
    const result: ComposerLocationResult = await getComposerLocation(getContext(this) as common.UIAbilityContext);
    hilog.info(0x0000, 'HXComposerTools', 'location result fix=%{public}s error=%{public}s code=%{public}d',
      (result.coordinates !== null).toString(), result.error, result.code);
    if (!this.alive || !this.visible || this.sheet !== 'location' || revision !== this.locationRevision ||
      generation !== xPrivateClient.sessionGeneration()) { return; }
    this.locationLoading = false;
    this.coordinates = result.coordinates;
    if (result.error.length > 0) {
      const label: Resource = result.error === 'denied' ? $r('app.string.compose_location_denied') :
        result.error === 'disabled' ? $r('app.string.compose_location_disabled') : $r('app.string.compose_location_failed');
      this.locationError = this.text(label) + (result.code > 0 ? ' · ' + result.code.toString() : '');
      return;
    }
    this.search(this.query);
  }
  private requestError(result: XPrivateResult): string {
    return this.text($r('app.string.compose_options_request_failed')) +
      (result.status > 0 ? ' · HTTP ' + result.status.toString() : '') +
      (result.errorText.length > 0 ? ' · ' + result.errorText : '');
  }
  private async loadScheduled(): Promise<void> {
    this.sheet = 'scheduled'; this.loading = true; this.error = '';
    const generation: number = xPrivateClient.sessionGeneration();
    const result: XPrivateResult = await xPrivateClient.getScheduledTweets();
    if (!this.alive || generation !== xPrivateClient.sessionGeneration()) { return; }
    this.loading = false;
    if (!result.ok) { this.error = this.requestError(result); return; }
    this.scheduled = composerScheduledPosts(result.body);
  }
  private dateLabel(timestamp: number): string { return new Date(timestamp).toLocaleString(); }

  @Builder
  private Tool(symbol: Resource, label: Resource, action: () => void, enabled: boolean): void {
    Button({ type: ButtonType.Circle }) {
      SymbolGlyph(symbol).fontSize(24).fontColor([enabled ? this.accentColor : $r('app.color.text_secondary')]);
    }.width(44).height(48).backgroundColor(Color.Transparent).enabled(!this.disabled && enabled)
      .accessibilityText(this.text(label)).onClick(action);
  }
  @Builder
  private ReplyChoice(mode: string, label: Resource, symbol: Resource, supported: boolean): void {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 16 }) {
        SymbolGlyph(symbol).fontSize(25).fontColor([$r('app.color.text_primary')]);
        Text(label).layoutWeight(1).fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_primary'));
        Radio({ value: mode, group: 'composer-reply-policy' }).checked(this.options.replyMode === mode)
          .radioStyle({ checkedBackgroundColor: this.accentColor }).hitTestBehavior(HitTestMode.None);
      }.width('100%').padding({ top: 12, bottom: 12 });
    }.width('100%').backgroundColor(Color.Transparent).enabled(supported && !this.disabled)
      .opacity(supported ? 1 : 0.45).onClick((): void => {
        const next: ComposerOptions = this.options.copy(); next.replyMode = mode;
        this.change(next); this.visible = false;
      });
  }
  @Builder
  private ReplySheet(): void {
    Text($r('app.string.compose_reply_help')).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary'));
    this.ReplyChoice('', $r('app.string.compose_reply_everyone'), $r('sys.symbol.globe_badge_message'), true);
    this.ReplyChoice('Verified', $r('app.string.compose_reply_verified'), $r('sys.symbol.checkmark_circle'), true);
    this.ReplyChoice('Community', $r('app.string.compose_reply_following'), $r('sys.symbol.person'), true);
    this.ReplyChoice('ByInvitation', $r('app.string.compose_reply_mentioned'), $r('sys.symbol.at'), true);
    this.ReplyChoice('MyNetwork', $r('app.string.compose_reply_network'), $r('sys.symbol.person_2'), true);
  }
  @Builder
  private ScheduleSheet(): void {
    Text(this.dateLabel(this.candidateDate)).fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_primary'));
    Button($r('app.string.compose_schedule_date')).width('100%').onClick((): void => this.chooseDate());
    Button($r('app.string.compose_schedule_time')).width('100%').onClick((): void => this.chooseTime());
    Text(this.text($r('app.string.compose_schedule_timezone')) + ' ' +
      'UTC' + (new Date().getTimezoneOffset() <= 0 ? '+' : '-') +
      (Math.abs(new Date().getTimezoneOffset()) / 60).toString()).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary'));
    Text($r('app.string.compose_schedule_server_hint')).fontSize($r('sys.float.Body_S')).fontColor($r('app.color.text_secondary'));
    Button($r('app.string.compose_options_confirm')).width('100%').backgroundColor(this.accentColor)
      .fontColor($r('app.color.text_on_accent')).onClick((): void => this.confirmSchedule());
    if (this.options.scheduledAt > 0) {
      Button($r('app.string.compose_schedule_remove')).fontColor($r('app.color.danger')).backgroundColor(Color.Transparent)
        .onClick((): void => { const next: ComposerOptions = this.options.copy(); next.scheduledAt = 0;
          this.change(next); this.visible = false; });
    }
    Button($r('app.string.compose_scheduled_posts')).fontColor(this.accentColor).backgroundColor(Color.Transparent)
      .onClick((): void => { this.loadScheduled(); });
  }
  @Builder
  private DisclosureRow(label: Resource, hint: Resource, paid: boolean): void {
    Row({ space: 12 }) {
      Column({ space: 6 }) {
        Text(label).fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_primary')).width('100%');
        Text(hint).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary')).width('100%');
      }.layoutWeight(1);
      Toggle({ type: ToggleType.Switch, isOn: paid ? this.options.paidPartnership : this.options.madeWithAi })
        .enabled(!this.disabled).selectedColor(this.accentColor).onChange((value: boolean): void => {
          const next: ComposerOptions = this.options.copy();
          if (paid) { next.paidPartnership = value; } else { next.madeWithAi = value; }
          this.change(next);
        });
    }.width('100%').padding({ top: 16, bottom: 16 });
  }
  @Builder
  private LocationSheet(): void {
    Search({ value: this.query, placeholder: this.text($r('app.string.compose_location_search')) })
      .height(44).onChange((value: string): void => this.search(value));
    Button($r('app.string.compose_location_current')).fontColor(this.accentColor).backgroundColor(Color.Transparent)
      .enabled(!this.locationLoading).onClick((): void => { this.locate(); });
    if (this.locationLoading) {
      Row({ space: 8 }) {
        LoadingProgress().width(24).height(24).color(this.accentColor);
        Text($r('app.string.compose_location_locating')).fontColor($r('app.color.text_secondary'));
      }
    }
    if (this.locationError.length > 0) {
      Text(this.locationError).fontColor($r('app.color.text_secondary')).fontSize($r('sys.float.Body_M'));
    }
    if (this.options.placeId.length > 0) {
      Text(this.options.placeName).fontColor(this.accentColor);
      Button($r('app.string.compose_location_remove')).fontColor($r('app.color.danger')).backgroundColor(Color.Transparent)
        .onClick((): void => { const next: ComposerOptions = this.options.copy(); next.placeId = ''; next.placeName = '';
          next.geoSearchRequestId = '';
          this.change(next); this.visible = false; });
    }
    if (!this.loading && !this.locationLoading && this.error.length === 0 && this.places.length === 0) {
      Text(this.query.length > 0 ? $r('app.string.compose_location_empty') : $r('app.string.compose_location_hint'))
        .fontColor($r('app.color.text_secondary')).fontSize($r('sys.float.Body_M'));
    }
    ForEach(this.places, (place: ComposerPlace): void => {
      Button({ type: ButtonType.Normal }) {
        Column({ space: 4 }) {
          Text(place.full_name).fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_primary')).width('100%');
          Text(place.country).fontSize($r('sys.float.Body_S')).fontColor($r('app.color.text_secondary')).width('100%');
        }.padding(12).width('100%');
      }.width('100%').backgroundColor(Color.Transparent).enabled(!this.disabled).onClick((): void => {
        const next: ComposerOptions = this.options.copy(); next.placeId = place.id; next.placeName = place.full_name;
        next.geoSearchRequestId = place.geoSearchRequestId;
        this.change(next); this.visible = false;
      });
    }, (place: ComposerPlace): string => place.id);
  }
  private sheetTitle(): Resource {
    if (this.sheet === 'emoji') { return $r('app.string.compose_emoji'); }
    if (this.sheet === 'reply') { return $r('app.string.compose_reply_title'); }
    if (this.sheet === 'location') { return $r('app.string.compose_location'); }
    if (this.sheet === 'disclosure') { return $r('app.string.compose_disclosure'); }
    if (this.sheet === 'scheduled') { return $r('app.string.compose_scheduled_posts'); }
    return $r('app.string.compose_schedule');
  }
  @Builder
  private Sheet(): void {
    Column({ space: 12 }) {
      Row() {
        Text(this.sheetTitle()).fontSize($r('sys.float.Title_M')).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary')).layoutWeight(1);
        Button($r('app.string.compose_options_done')).fontColor(this.accentColor).backgroundColor(Color.Transparent)
          .onClick((): void => { this.visible = false; });
      }.width('100%');
      if (this.sheet === 'emoji') {
        ChatEmojiPanel({ onSelect: (emoji: string): void => { this.pendingEmoji = emoji; this.visible = false; } }).layoutWeight(1);
      } else {
        Scroll() {
          Column({ space: 12 }) {
            if (this.error.length > 0) {
              Text(this.error).fontColor($r('app.color.danger')).width('100%').fontSize($r('sys.float.Body_M'));
            }
            if (this.loading) { LoadingProgress().width(32).height(32).color(this.accentColor); }
            if (this.sheet === 'reply') { this.ReplySheet(); }
            if (this.sheet === 'schedule') { this.ScheduleSheet(); }
            if (this.sheet === 'location') { this.LocationSheet(); }
            if (this.sheet === 'disclosure') {
              this.DisclosureRow($r('app.string.compose_disclosure_ai'), $r('app.string.compose_disclosure_ai_hint'), false);
              this.DisclosureRow($r('app.string.compose_disclosure_paid'), $r('app.string.compose_disclosure_paid_hint'), true);
            }
            if (this.sheet === 'scheduled') {
              if (!this.loading && this.scheduled.length === 0 && this.error.length === 0) {
                Text($r('app.string.compose_scheduled_empty')).fontColor($r('app.color.text_secondary'));
              }
              ForEach(this.scheduled, (post: ComposerScheduledPost): void => {
                Column({ space: 8 }) {
                  Text(this.dateLabel(post.executeAt)).fontColor(this.accentColor).fontSize($r('sys.float.Body_S'));
                  Text(post.text).fontColor($r('app.color.text_primary')).fontSize($r('sys.float.Body_L'));
                }.width('100%').alignItems(HorizontalAlign.Start).padding(12);
              }, (post: ComposerScheduledPost): string => post.id);
            }
          }.width('100%').alignItems(HorizontalAlign.Start);
        }.layoutWeight(1).width('100%').align(Alignment.TopStart);
      }
    }.width('100%').height('100%').padding(20);
  }
  build(): void {
    Column() {
      if (!this.isReply && !this.community) {
        Button({ type: ButtonType.Normal }) {
          Row({ space: 8 }) {
            SymbolGlyph($r('sys.symbol.globe_badge_message')).fontSize(18).fontColor([this.accentColor]);
            Text(replyModeLabel(this.options.replyMode)).fontColor(this.accentColor).fontSize($r('sys.float.Body_M'));
          }.width('100%');
        }.width('100%').height(40).padding({ left: 16 }).backgroundColor(Color.Transparent)
          .enabled(!this.disabled && this.options.scheduledAt === 0).onClick((): void => this.open('reply'));
      }
      if (this.options.scheduledAt > 0 || this.options.placeId.length > 0 ||
        this.options.paidPartnership || this.options.madeWithAi) {
        Scroll() {
          Row({ space: 12 }) {
            if (this.options.scheduledAt > 0) {
              Text(this.dateLabel(this.options.scheduledAt)).fontColor(this.accentColor).onClick((): void => this.open('schedule'));
            }
            if (this.options.placeId.length > 0) {
              Text(this.options.placeName).fontColor(this.accentColor).onClick((): void => this.open('location'));
            }
            if (this.options.madeWithAi) {
              Text($r('app.string.compose_disclosure_ai')).fontColor(this.accentColor).onClick((): void => this.open('disclosure'));
            }
            if (this.options.paidPartnership) {
              Text($r('app.string.compose_disclosure_paid')).fontColor(this.accentColor).onClick((): void => this.open('disclosure'));
            }
          }.padding({ left: 16, right: 16 }).height(32);
        }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%');
      }
      Divider().color($r('app.color.divider'));
      Scroll() {
        Row({ space: 2 }) {
          this.leadingActions();
          this.Tool($r('sys.symbol.list_bullet'), $r('app.string.compose_poll'), (): void => this.addPoll(), true);
          this.Tool($r('sys.symbol.face_smiling'), $r('app.string.compose_emoji'), (): void => this.open('emoji'), true);
          this.Tool($r('sys.symbol.calendar_badge_play'), $r('app.string.compose_schedule'), (): void => this.open('schedule'), !this.community);
          this.Tool($r('sys.symbol.mappin_and_rectangle'), $r('app.string.compose_location'), (): void => this.open('location'), this.options.scheduledAt === 0);
          this.Tool($r('sys.symbol.flag'), $r('app.string.compose_disclosure'), (): void => this.open('disclosure'), true);
          this.trailingActions();
        }.padding({ left: 10, right: 10 }).height(this.compactWindow ?
          $r('app.float.compact_window_tool_bar_height') : 64);
      }.width('100%').scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off);
    }.width('100%').bindSheet($$this.visible, this.Sheet(), sheetMaterialOptions({
      height: 560, dragBar: true, showClose: false, backgroundColor: $r('app.color.bg_page'),
      onAppear: (): void => { hilog.info(0x0000, 'HXComposerTools', 'sheet appeared %{public}s', this.sheet); },
      onDisappear: (): void => {
        this.queryRevision++; this.locationRevision++; this.loading = false; this.locationLoading = false;
        this.coordinates = null;
        if (this.queryTimer >= 0) { clearTimeout(this.queryTimer); this.queryTimer = -1; }
        if (this.pendingEmoji.length > 0 && this.alive) {
          const emoji: string = this.pendingEmoji; this.pendingEmoji = ''; this.onEmoji(emoji);
        }
      }
    }, this.materialEnabled, this.materialLevel, this.sheetWindowBreakpoint, this.compactWindow));
  }
}
