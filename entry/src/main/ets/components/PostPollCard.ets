import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { STORAGE_KEY_SYSTEM_EMOJI_ENABLED } from '../services/AppearanceStore';
import { common } from '@kit.AbilityKit';
import type { PollOption, TweetPoll } from '../models/Tweet';
import { formatCount } from '../models/Tweet';
import { pollClosed, pollPercentages, pollTotal } from '../utils/PostPoll';
import { hapticTick } from '../utils/Haptics';
import { openExternalLink } from '../utils/PostEntities';
import { STORAGE_KEY_POST_TIME_NOW } from '../utils/PostTime';
import { postPollStore, STORAGE_KEY_POST_POLL_REVISION } from '../services/PostPollStore';
import { xPrivateClient } from '../services/XPrivateClient';
import { ProxyMediaImage } from './ProxyMediaImage';
import { PostMedia } from './PostMedia';
import { EmojiSpans } from './EmojiSpans';

@Component
export struct PostPollCard {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp(STORAGE_KEY_SYSTEM_EMOJI_ENABLED) private systemEmojiEnabled: boolean = false;
  @Prop @Watch('inputChanged') poll: TweetPoll;
  @Prop @Watch('inputChanged') postId: string = '';
  @Prop accentColor: string = '#007DFF';
  @Prop showMedia: boolean = true;
  @StorageProp(STORAGE_KEY_POST_TIME_NOW) private now: number = Date.now();
  @StorageProp(STORAGE_KEY_POST_POLL_REVISION) @Watch('syncSnapshot') private revision: number = 0;
  @State private current: TweetPoll | null = null;
  @State private pendingChoice: string = '';
  @State private reveal: boolean = false;
  @State private busy: boolean = false;
  @State private uncertain: boolean = false;
  @State private status: string = '';
  private alive: boolean = false;

  aboutToAppear(): void { this.alive = true; this.inputChanged(); }
  aboutToDisappear(): void { this.alive = false; }

  private inputChanged(): void {
    this.pendingChoice = ''; this.reveal = false; this.status = '';
    postPollStore.remember(this.postId, this.poll);
    this.syncSnapshot();
  }

  private syncSnapshot(): void {
    this.current = postPollStore.snapshot(this.postId, this.poll);
    this.busy = postPollStore.isBusy(this.postId);
    this.uncertain = postPollStore.isUncertain(this.postId);
  }

  private data(): TweetPoll { return this.current ?? this.poll; }
  private closed(): boolean { return pollClosed(this.data(), this.now); }
  private results(): boolean { return this.reveal || this.closed() || this.data().selectedChoice.length > 0; }
  private percent(index: number): number { return pollPercentages(this.data())[index] ?? 0; }

  private text(resource: Resource, value: string = ''): string {
    try {
      const context: common.UIAbilityContext | undefined = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
      if (context === undefined) { return ''; }
      return value.length > 0 ? context.resourceManager.getStringSync(resource, value) : context.resourceManager.getStringSync(resource);
    } catch (error) { return ''; }
  }

  private timeLabel(): string {
    if (this.closed()) { return this.text($r('app.string.poll_final')); }
    const end: number = Date.parse(this.data().endsAt);
    if (!isFinite(end)) { return this.text($r('app.string.poll_open')); }
    const minutes: number = Math.max(1, Math.ceil((end - this.now) / 60000));
    if (minutes >= 1440) { return this.text($r('app.string.poll_days_left'), String(Math.ceil(minutes / 1440))); }
    if (minutes >= 60) { return this.text($r('app.string.poll_hours_left'), String(Math.ceil(minutes / 60))); }
    return this.text($r('app.string.poll_minutes_left'), String(minutes));
  }

  private statusText(): string {
    if (this.uncertain) { return this.text($r('app.string.poll_unconfirmed')); }
    if (this.status === 'login') { return this.text($r('app.string.poll_login_required')); }
    if (this.status === 'closed') { return this.text($r('app.string.poll_closed')); }
    if (this.status === 'account') { return this.text($r('app.string.poll_account_changed')); }
    if (this.status === 'refresh') { return this.text($r('app.string.poll_refresh_failed')); }
    if (this.status === 'failed' || this.status === 'invalid') { return this.text($r('app.string.poll_vote_failed')); }
    return '';
  }

  private optionLabel(option: PollOption, index: number): string {
    return option.label + (this.results() && this.data().countsKnown ? ' · ' + this.percent(index) + '%' : '') +
      (this.data().selectedChoice === option.id ? ' · ' + this.text($r('app.string.poll_your_vote')) : '');
  }

  private choose(option: PollOption): void {
    if (this.busy || this.uncertain || this.closed() || this.data().selectedChoice.length > 0) { return; }
    if (this.pendingChoice === option.id && !this.reveal) { return; }
    this.reveal = false; this.pendingChoice = option.id; this.status = ''; hapticTick();
  }

  private async submit(): Promise<void> {
    if (this.pendingChoice.length === 0 || this.busy) { return; }
    const id: string = this.postId;
    const result: string = await postPollStore.vote(id, this.data(), this.pendingChoice);
    if (!this.alive || this.postId !== id) { return; }
    this.status = result; this.syncSnapshot();
    if (result === 'ok' || result === 'voted') { this.pendingChoice = ''; hapticTick(); }
  }

  private async refresh(): Promise<void> {
    const id: string = this.postId;
    const result: string = await postPollStore.refresh(id);
    if (!this.alive || this.postId !== id) { return; }
    this.status = result; this.syncSnapshot();
  }

  @Builder
  private Option(option: PollOption, index: number): void {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Column({ space: 8 }) {
        if (option.imageUrl.length > 0) {
          ProxyMediaImage({ url: option.imageUrl, displayHeight: 100 }).borderRadius(10).clip(true)
        }
        Row({ space: 10 }) {
          if (!this.results()) {
            Radio({ value: option.id, group: 'post-poll-' + this.postId })
              .checked(this.pendingChoice === option.id)
              .radioStyle({ checkedBackgroundColor: this.accentColor,
                uncheckedBorderColor: $r('app.color.text_secondary'), indicatorColor: $r('app.color.text_on_brand') })
              .width(20).height(20).padding(0)
              .enabled(!this.busy && !this.uncertain)
              .onChange((checked: boolean): void => { if (checked) { this.choose(option); } })
              .accessibilityText(option.label)
          }
          Text() { EmojiSpans(this.getUIContext(), option.label, $r('sys.float.Body_M'), this.systemEmojiEnabled) }.fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M')).maxFontScale(1.3)
            .fontWeight(this.data().selectedChoice === option.id ? FontWeight.Medium : FontWeight.Regular)
            .fontColor($r('app.color.text_primary')).layoutWeight(1).maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.results() && this.data().selectedChoice === option.id) {
            SymbolGlyph($r('sys.symbol.checkmark_circle_fill')).fontSize(16).fontColor([this.accentColor])
          }
          if (this.results()) {
            Text(this.data().countsKnown ? String(this.percent(index)) + '%' : '—').fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_M')).fontWeight(FontWeight.Medium)
              .fontColor(this.data().selectedChoice === option.id ? this.accentColor : $r('app.color.text_secondary'))
          }
        }.width('100%').constraintSize({ minHeight: 24 })
        if (this.results()) {
          Progress({ value: this.data().countsKnown ? this.percent(index) : 0, total: 100, type: ProgressType.Linear })
            .width('100%').height($r('app.float.poll_progress_height'))
            .color(this.data().selectedChoice === option.id ? this.accentColor : $r('app.color.poll_result_fill'))
            .backgroundColor($r('app.color.poll_result_track'))
            .style({ strokeWidth: $r('app.float.poll_progress_height'), strokeRadius: $r('app.float.poll_progress_radius'),
              enableSmoothEffect: true })
            .hitTestBehavior(HitTestMode.None)
        }
      }
      .width('100%').padding({ left: 14, right: 14, top: 12, bottom: 12 })
    }
    .width('100%').padding(0).borderRadius(12)
    .backgroundColor(this.pendingChoice === option.id && !this.results() ? $r('app.color.poll_selected_surface') : Color.Transparent)
    .onClick((): void => { this.choose(option); })
    .accessibilityText(this.optionLabel(option, index))
  }

  build(): void {
    Column({ space: 8 }) {
      if (this.showMedia && (this.data().media?.length ?? 0) > 0) {
        PostMedia({ attachments: this.data().media ?? [], naturalVideoSize: true, limitNaturalHeight: true })
      } else if (this.showMedia && this.data().imageUrl.length > 0) {
        ProxyMediaImage({ url: this.data().imageUrl, displayHeight: 160 })
          .borderRadius(12).clip(true)
      }
      Column({ space: 0 }) {
        ForEach(this.data().options, (option: PollOption, index: number) => {
          this.Option(option, index)
          if (index < this.data().options.length - 1) {
            Divider().strokeWidth(0.5).color($r('app.color.divider')).margin({ left: 14, right: 14 })
          }
        }, (option: PollOption): string => this.postId + ':' + option.id)
      }
      .width('100%').padding(4).backgroundColor($r('app.color.poll_option_surface')).borderRadius(16).clip(true)
      if (!this.closed() && this.data().selectedChoice.length === 0 && !this.reveal) {
        Button(this.busy ? $r('app.string.poll_submitting') : $r('app.string.poll_vote'), { type: ButtonType.Capsule })
          .width('100%').height(40).fontSize($r('sys.float.Body_M')).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_on_brand')).backgroundColor(this.accentColor)
          .enabled(this.pendingChoice.length > 0 && !this.busy && !this.uncertain)
          .onClick((): void => { this.submit(); })
      }
      Row({ space: 8 }) {
        Column({ space: 3 }) {
          Text(this.data().countsKnown ? this.text($r('app.string.poll_votes'), formatCount(pollTotal(this.data()))) :
            $r('app.string.poll_counts_unavailable')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Caption_L')).fontColor($r('app.color.text_secondary'))
          Text(this.timeLabel()).fontFamily(this.appFontFamily).fontSize($r('sys.float.Caption_M')).fontColor($r('app.color.text_secondary'))
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        if (!this.closed() && this.data().selectedChoice.length === 0) {
          Button(this.reveal ? $r('app.string.poll_back_to_vote') : $r('app.string.poll_view_results'))
            .fontSize($r('sys.float.Caption_L')).fontColor(this.accentColor).backgroundColor(Color.Transparent)
            .padding({ left: 6, right: 6 }).height(32).enabled(!this.busy)
            .onClick((): void => { this.reveal = !this.reveal; })
        }
        if (this.results() || this.uncertain || this.status === 'refresh') {
          Button({ type: ButtonType.Circle, stateEffect: true }) {
            if (this.busy) {
              LoadingProgress().width(16).height(16).color(this.accentColor)
            } else {
              SymbolGlyph($r('sys.symbol.arrow_clockwise')).fontSize(16).fontColor([$r('app.color.text_secondary')])
            }
          }
          .width(32).height(32).padding(0).backgroundColor($r('app.color.poll_option_surface')).enabled(!this.busy)
          .accessibilityText(this.uncertain ? $r('app.string.poll_check_status') : $r('app.string.poll_refresh'))
          .onClick((): void => { this.refresh(); })
        }
      }.width('100%').padding({ left: 4, right: 4 })
      if (this.busy) {
        Row({ space: 6 }) {
          LoadingProgress().width(16).height(16).color(this.accentColor)
          Text($r('app.string.poll_updating')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Caption_L')).fontColor($r('app.color.text_secondary'))
        }.width('100%')
      }
      if (this.statusText().length > 0) {
        Text(this.statusText()).fontFamily(this.appFontFamily).width('100%').fontSize($r('sys.float.Caption_L')).fontColor($r('app.color.danger'))
      }
      if (this.status === 'login' || (this.data().api.length === 0 && !xPrivateClient.isSignedIn() && !this.closed())) {
        Button($r('app.string.poll_open_original')).fontSize($r('sys.float.Caption_L')).fontColor(this.accentColor)
          .backgroundColor(Color.Transparent).height(32)
          .onClick((): void => {
            openExternalLink(getContext(this) as common.UIAbilityContext, 'https://x.com/i/status/' + this.postId);
          })
      }
    }
    .width('100%').alignItems(HorizontalAlign.Start).margin({ top: 8 })
  }
}
