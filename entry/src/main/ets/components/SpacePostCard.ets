import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { STORAGE_KEY_SYSTEM_EMOJI_ENABLED } from '../services/AppearanceStore';
import { userAvatarRadius, verificationBadgeColor, userVerifiedType, userAvatarShape } from '../utils/UserIdentity';
import { common } from '@kit.AbilityKit';
import { SpaceRoom } from '../models/Space';
import { formatCount, TweetLinkCard } from '../models/Tweet';
import { spaceSurfaceStore, requestSpacePreview } from '../services/SpaceSurfaceStore';
import { spaceStatus, spaceTime } from '../utils/SpacePresentation';
import { ProxyAvatar } from './ProxyAvatar';
import { SpaceWaveform } from './SpaceWaveform';
import { EmojiSpans } from './EmojiSpans';

@Component
export struct SpacePostCard {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp(STORAGE_KEY_SYSTEM_EMOJI_ENABLED) private systemEmojiEnabled: boolean = false;
  @Prop @Watch('onCardChanged') card: TweetLinkCard;
  @State private room: SpaceRoom | null = null;
  @State private failed: boolean = false;
  private alive: boolean = false;
  private visible: boolean = false;
  private generation: number = 0;
  private timer: number = -1;

  aboutToAppear(): void { this.alive = true; this.onCardChanged(); }
  aboutToDisappear(): void { this.alive = false; this.generation++; this.clearTimer(); }
  private spaceId(): string { return this.card.url.match(/\/i\/spaces\/([A-Za-z0-9]{5,64})/)?.[1] ?? ''; }
  private clearTimer(): void { if (this.timer >= 0) { clearTimeout(this.timer); this.timer = -1; } }
  private onCardChanged(): void {
    this.generation++; this.clearTimer(); this.room = spaceSurfaceStore.cached(this.spaceId()); this.failed = false;
    if (this.visible) { this.load(); }
  }
  private async load(): Promise<void> {
    this.clearTimer();
    const generation: number = ++this.generation;
    try {
      const room: SpaceRoom | null = await spaceSurfaceStore.detail(this.spaceId());
      if (!this.alive || generation !== this.generation) { return; }
      this.room = room; this.failed = room === null;
    } catch (error) { if (generation === this.generation) { this.failed = true; } }
    finally {
      if (this.alive && this.visible && generation === this.generation && this.room?.isLive()) {
        this.timer = setTimeout((): void => { this.load(); }, 65000);
      }
    }
  }
  private summary(room: SpaceRoom): string {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    let text: string = spaceTime(context, room.isScheduled() ? room.scheduledStart : room.startedAt);
    if (room.endedAt > room.startedAt && room.startedAt > 0) {
      const minutes: number = Math.max(1, Math.round((room.endedAt - room.startedAt) / 60000));
      text += ' · ' + context.resourceManager.getStringSync($r('app.string.spaces_duration_short').id,
        Math.floor(minutes / 60).toString(), (minutes % 60).toString());
    }
    if (room.isLive() || room.totalListenerCount > 0) {
      text += (text.length > 0 ? ' · ' : '') + context.resourceManager.getStringSync(
        (room.isLive() ? $r('app.string.spaces_listening_count') : $r('app.string.spaces_replay_count')).id,
        formatCount(room.isLive() ? room.participantCount : room.totalListenerCount));
    }
    return text;
  }
  private action(): Resource {
    return this.room === null ? $r('app.string.spaces_view_space') : this.room.isLive() ? $r('app.string.spaces_pill_listen') :
      this.room.isScheduled() ? $r('app.string.spaces_view_space') : this.room.replayAvailable ?
        $r('app.string.spaces_play_replay') : $r('app.string.spaces_ended');
  }
  build(): void {
    Column({ space: 14 }) {
      if (this.room !== null) {
        Row({ space: 6 }) {
          ProxyAvatar({verifiedType: this.room.host.verifiedType ?? '', avatarShape: this.room.host.avatarShape ?? '',  url: this.room.host.avatarUrl, avatarSize: 24, radius: 12,
            fallbackText: this.room.host.name.substring(0, 1), fallbackColor: $r('app.color.space_card_footer') })
          Text() { EmojiSpans(this.getUIContext(), this.room.host.name || this.room.host.username, $r('sys.float.Body_M'), this.systemEmojiEnabled) }.fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M'))
            .fontWeight(FontWeight.Medium).fontColor($r('app.color.space_card_text')).maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
          if (this.room.host.verified) {
            SymbolGlyph($r('sys.symbol.checkmark_circle_fill')).fontSize(16).fontColor([verificationBadgeColor(this.room.host.verifiedType, $r('app.color.text_accent'))])
          }
          Text($r('app.string.spaces_host')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S')).fontColor($r('app.color.space_card_text'))
            .padding({ left: 6, right: 6, top: 2, bottom: 2 }).borderRadius(5).backgroundColor($r('app.color.space_card_badge'))
        }.width('100%')
      }
      Text() { EmojiSpans(this.getUIContext(), this.room?.title || this.card.title || $r('app.string.spaces_untitled'), $r('sys.float.Title_S'), this.systemEmojiEnabled) }.fontFamily(this.appFontFamily)
        .width('100%')
        .fontSize($r('sys.float.Title_S')).fontWeight(FontWeight.Bold).fontColor($r('app.color.space_card_text'))
        .maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
      if (this.room !== null) {
        Text(this.summary(this.room) || spaceStatus(this.room)).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S'))
          .fontColor($r('app.color.space_card_text')).width('100%')
      } else {
        Text(this.failed ? $r('app.string.spaces_room_unavailable') : $r('app.string.side_spaces')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_S')).fontColor($r('app.color.space_card_text'))
      }
      Button({ type: ButtonType.Capsule }) {
        Row({ space: 8 }) {
          if (this.room?.isLive()) { SpaceWaveform({ color: $r('app.color.space_card_action_text'), waveformSize: 20 }) }
          else { SymbolGlyph($r('sys.symbol.play_fill')).fontSize(18).fontColor([$r('app.color.space_card_action_text')]) }
          Text(this.action()).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.space_card_action_text'))
        }
      }.width('100%').height(40).backgroundColor($r('app.color.space_card_action_surface'))
        .onClick((): void => requestSpacePreview(this.spaceId())).monopolizeEvents(true)
    }.width('100%').padding(14).alignItems(HorizontalAlign.Start).borderRadius(16)
      .backgroundColor($r('app.color.space_card_fill')).margin({ top: 8 })
      .onClick((): void => requestSpacePreview(this.spaceId())).monopolizeEvents(true)
      .onVisibleAreaApproximateChange({ ratios: [0, 0.01], expectedUpdateInterval: 300 },
        (visible: boolean, ratio: number): void => {
          this.visible = visible && ratio > 0;
          if (this.visible) { this.load(); } else { this.clearTimer(); }
        })
  }
}
