import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { userAvatarRadius, verificationBadgeColor, userVerifiedType, userAvatarShape } from '../utils/UserIdentity';
import { common } from '@kit.AbilityKit';
import { SpaceParticipant, SpaceRoom } from '../models/Space';
import { formatCount } from '../models/Tweet';
import { spaceSurfaceStore } from '../services/SpaceSurfaceStore';
import { SPACE_PLAYBACK_REVISION, spacePlayback } from '../services/SpacePlayback';
import { addSpaceToCalendar } from '../services/SpaceCalendar';
import { spaceRole, spaceStatus, spaceTime } from '../utils/SpacePresentation';
import { shareSpace } from '../utils/SharePost';
import { openExternalLink } from '../utils/PostEntities';
import { ProxyAvatar } from './ProxyAvatar';
import { SpaceWaveform } from './SpaceWaveform';

@Component
export struct SpacePreviewSheet {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Prop @Watch('onSpaceChanged') spaceId: string = '';
  @Prop canCloseHomeCapsule: boolean = false;
  @StorageProp(SPACE_PLAYBACK_REVISION) playbackRevision: number = 0;
  @StorageProp('harmonyx.navigation_indicator_height') bottomInset: number = 0;
  @StorageProp('harmonyx.accent_color') accentColor: string = '#007DFF';
  @State private room: SpaceRoom | null = null;
  @State private loading: boolean = true;
  @State private failed: boolean = false;
  @State private calendarBusy: boolean = false;
  @State private calendarSaved: boolean = false;
  private alive: boolean = false;
  private generation: number = 0;
  private timer: number = -1;
  onClose: () => void = (): void => {};
  onCloseHomeCapsule: (permanent: boolean) => void = (): void => {};
  onPerson: (person: SpaceParticipant) => void = (): void => {};

  aboutToAppear(): void { this.alive = true; this.onSpaceChanged(); }
  aboutToDisappear(): void { this.alive = false; this.generation++; this.clearTimer(); }
  private clearTimer(): void { if (this.timer >= 0) { clearTimeout(this.timer); this.timer = -1; } }
  private onSpaceChanged(): void {
    this.generation++; this.clearTimer(); this.room = spaceSurfaceStore.cached(this.spaceId);
    this.loading = this.room === null; this.failed = false; this.calendarSaved = false; this.load();
  }
  private async load(): Promise<void> {
    const generation: number = ++this.generation;
    this.clearTimer();
    try {
      const room: SpaceRoom | null = await spaceSurfaceStore.detail(this.spaceId);
      if (!this.alive || generation !== this.generation) { return; }
      this.failed = room === null;
      this.room = room;
    } catch (error) { if (this.alive && generation === this.generation) { this.failed = true; } }
    finally {
      if (this.alive && generation === this.generation) {
        this.loading = false;
        if (this.room?.isLive() || this.room?.isScheduled()) {
          this.timer = setTimeout((): void => { this.load(); }, 65000);
        }
      }
    }
  }
  private state(): string { return this.playbackRevision >= 0 && spacePlayback.room?.id === this.spaceId ? spacePlayback.state : 'idle'; }
  private playing(): boolean { return this.state() === 'playing' || this.state() === 'buffering'; }
  private busy(): boolean { return this.state() === 'loading' || this.state() === 'buffering'; }
  private async toggle(): Promise<void> {
    const room: SpaceRoom | null = this.room;
    if (room === null) { return; }
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    if (room.isScheduled()) {
      this.calendarBusy = true;
      try { this.calendarSaved = await addSpaceToCalendar(context, room); }
      finally { this.calendarBusy = false; }
    } else if (this.playing()) { spacePlayback.pausePlayback(); }
    else { await spacePlayback.listen(context, room); }
  }
  private buttonText(room: SpaceRoom): Resource {
    return this.calendarSaved ? $r('app.string.spaces_calendar_saved') : room.isScheduled() ? $r('app.string.spaces_add_calendar') :
      this.busy() ? $r('app.string.spaces_connecting') : this.playing() ? $r('app.string.spaces_pause') :
        this.state() === 'error' ? $r('app.string.spaces_retry_audio') : room.isLive() ? $r('app.string.spaces_listen') :
          room.replayAvailable ? $r('app.string.spaces_play_replay') : $r('app.string.spaces_ended');
  }
  @Builder
  private MenuContent(): void {
    Menu() {
      MenuItem({ content: $r('app.string.spaces_share') }).onClick((): void => {
        shareSpace(getContext(this) as common.UIAbilityContext, this.spaceId, this.room?.title ?? '');
      })
      if (this.canCloseHomeCapsule) {
        MenuItem({ content: $r('app.string.spaces_home_capsule_close_session') })
          .onClick((): void => this.onCloseHomeCapsule(false))
        MenuItem({ content: $r('app.string.spaces_home_capsule_close') })
          .onClick((): void => this.onCloseHomeCapsule(true))
      }
      MenuItem({ content: $r('app.string.spaces_about') }).onClick((): void => {
        openExternalLink(getContext(this) as common.UIAbilityContext, 'https://help.x.com/en/using-x/spaces');
      })
      MenuItem({ content: $r('app.string.spaces_report_on_x') }).onClick((): void => {
        openExternalLink(getContext(this) as common.UIAbilityContext, 'https://help.x.com/en/forms/safety-and-sensitive-content');
      })
    }
  }
  @Builder
  private Person(person: SpaceParticipant): void {
    Column({ space: 6 }) {
      ProxyAvatar({verifiedType: person.verifiedType ?? '', avatarShape: person.avatarShape ?? '',  url: person.avatarUrl, avatarSize: 58, radius: 29,
        fallbackText: person.name.substring(0, 1), fallbackColor: this.accentColor })
      Row({ space: 3 }) {
        Text(person.name || person.username).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S')).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary')).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).flexShrink(1)
        if (person.verified) {
          SymbolGlyph($r('sys.symbol.checkmark_circle_fill')).fontSize(12).fontColor([this.accentColor])
        }
      }.width('100%').justifyContent(FlexAlign.Center)
      Row({ space: 3 }) {
        if (person.muted !== undefined && person.role !== 'listener') {
          SymbolGlyph(person.muted ? $r('sys.symbol.mic_slash') : $r('sys.symbol.mic'))
            .fontSize(12).fontColor([person.muted ? $r('app.color.like') : this.accentColor])
        }
        Text(spaceRole(person)).fontFamily(this.appFontFamily).fontSize($r('sys.float.Caption_L')).fontColor($r('app.color.text_secondary'))
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }.width('25%').padding({ left: 4, right: 4, top: 12, bottom: 12 })
      .onClick((): void => this.onPerson(person))
  }
  build(): void {
    Column({ space: 12 }) {
      Row() {
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.xmark')).fontSize(22).fontColor([$r('app.color.text_primary')])
        }.width(40).height(40).backgroundColor(Color.Transparent).onClick((): void => this.onClose())
          .accessibilityText($r('app.string.spaces_minimize'))
        Blank()
        Button({ type: ButtonType.Circle }) {
          Text('⋯').fontFamily(this.appFontFamily).fontSize(28).fontColor($r('app.color.text_primary'))
        }.width(40).height(40).backgroundColor(Color.Transparent).bindMenu(this.MenuContent())
          .accessibilityText($r('app.string.spaces_more'))
      }.width('100%')
      if (this.room !== null) {
        Scroll() {
          Column({ space: 14 }) {
            Row({ space: 6 }) {
              SpaceWaveform({ active: this.room.isLive(), color: this.accentColor, waveformSize: 18 })
              Text(spaceStatus(this.room)).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S')).fontColor(this.accentColor)
              if (this.room.replayAvailable) {
                Text($r('app.string.spaces_recording_info')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S'))
                  .fontColor($r('app.color.space_recording')).padding({ left: 6, right: 6, top: 3, bottom: 3 })
                  .borderRadius(5).backgroundColor($r('app.color.space_recording_soft'))
              }
            }.width('100%')
            Text(this.room.title || $r('app.string.spaces_untitled')).fontFamily(this.appFontFamily).fontSize($r('app.float.space_room_title_size'))
              .fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary')).width('100%')
            if (this.room.isScheduled()) {
              Text(spaceTime(getContext(this) as common.UIAbilityContext, this.room.scheduledStart)).fontFamily(this.appFontFamily)
                .fontSize($r('sys.float.Body_M')).fontColor(this.accentColor)
            }
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(this.room.participants, (person: SpaceParticipant): void => { this.Person(person); },
                (person: SpaceParticipant): string => person.id)
            }.width('100%')
            Text(this.room.isLive() ? $r('app.string.spaces_members_partial', formatCount(this.room.participantCount)) :
              $r('app.string.spaces_replay_count', formatCount(this.room.totalListenerCount))).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_S')).fontColor($r('app.color.text_secondary')).width('100%')
            if (this.failed) {
              Text($r('app.string.spaces_refresh_failed')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S')).fontColor($r('app.color.text_secondary'))
              Button($r('app.string.common_retry')).fontColor(this.accentColor).backgroundColor(Color.Transparent)
                .onClick((): void => { this.loading = true; this.load(); })
            }
          }.width('100%').alignItems(HorizontalAlign.Start)
        }.width('100%').layoutWeight(1).scrollBar(BarState.Off)
        Text(this.state() === 'error' ? $r('app.string.spaces_audio_failed') : $r('app.string.spaces_listen_only_body')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_S')).fontColor($r('app.color.text_secondary')).width('100%')
        Button(this.buttonText(this.room)).width('100%').height($r('app.float.space_listen_height'))
          .fontSize($r('sys.float.Body_L')).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_on_accent'))
          .backgroundColor(this.accentColor).enabled(!this.busy() && !this.calendarBusy && !this.failed &&
            (this.room.canListen() || (this.room.isScheduled() && !this.calendarSaved && this.room.scheduledStart > Date.now())))
          .onClick((): void => { this.toggle().catch((): void => { this.failed = true; }); })
        if (this.state() !== 'idle') {
          Button($r('app.string.spaces_leave')).fontColor($r('app.color.text_secondary')).backgroundColor(Color.Transparent)
            .onClick((): void => { spacePlayback.stop(); })
        }
      } else if (this.loading) {
        LoadingProgress().width(36).height(36).color(this.accentColor).layoutWeight(1)
      } else {
        Column({ space: 16 }) {
          Text($r('app.string.spaces_room_unavailable')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Title_S')).fontColor($r('app.color.text_primary'))
          Button($r('app.string.common_retry')).backgroundColor(this.accentColor).fontColor($r('app.color.text_on_accent'))
            .onClick((): void => { this.loading = true; this.load(); })
        }.layoutWeight(1).justifyContent(FlexAlign.Center)
      }
    }.width('100%').height('100%').padding({ left: 16, right: 16, top: 8, bottom: this.bottomInset + 16 })
  }
}
