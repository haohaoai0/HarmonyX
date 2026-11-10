import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { batteryInfo } from '@kit.BasicServicesKit';
import { statistics } from '@kit.NetworkKit';
import type { Tweet } from '../models/Tweet';
import { ProxyAvatar } from './ProxyAvatar';
import { MaterialButton } from './MaterialButton';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { videoHoldSpeedLabel } from '../services/MediaSettingsStore';
import { hapticTick } from '../utils/Haptics';

// A mounted component owns the controls, as in Yunshang's VideoControls.
// Links observe the actual AVPlayer owner; icon resources are never snapshots
// passed by value through a nested popup/builder invocation.
@Component
export struct LandscapeVideoControls {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Link playing: boolean;
  @Link muted: boolean;
  @Link controlsVisible: boolean;
  @Link locked: boolean;
  @Link rateIndex: number;
  @Link positionSeconds: number;
  @Link duration: number;
  @Link scrubbing: boolean;
  @Link scrubPosition: number;
  @Prop fullscreen: boolean = false;
  @Prop backgroundAudio: boolean = true;
  @Prop holdSpeedActive: boolean = false;
  @Prop holdSpeedRate: number = 2;
  @Prop rates: number[] = [0.75, 1, 1.25, 1.5, 2];
  @Prop statusBarHeight: number = 0;
  @Prop navigationIndicatorHeight: number = 0;
  @Prop sourceTweet: Tweet | null = null;
  @Prop authorFollowing: boolean = false;
  @Prop danmakuEnabled: boolean = false;
  @Prop danmakuAvailable: boolean = false;
  @Prop qualityLabel: string = '';
  @Prop downloadAvailable: boolean = false;
  @Prop downloading: boolean = false;
  onPlayPause: () => void = (): void => {};
  onMute: () => void = (): void => {};
  onRate: () => void = (): void => {};
  onSeek: (value: number, mode: SliderChangeMode) => void = (): void => {};
  onBack: () => void = (): void => {};
  onFullscreen: () => void = (): void => {};
  onLock: () => void = (): void => {};
  onAspect: () => void = (): void => {};
  onBackground: () => void = (): void => {};
  onMore: () => void = (): void => {};
  onQuality: () => void = (): void => {};
  onDownload: () => void = (): void => {};
  onFollow: () => void = (): void => {};
  onComment: () => void = (): void => {};
  onDanmakuToggle: () => void = (): void => {};
  onDanmakuSend: () => void = (): void => {};
  onInteraction: () => void = (): void => {};
  @State private mirrored: boolean = false;
  @State private mirrorAngle: number = 0;
  @State private clockText: string = '';
  @State private batteryText: string = '';
  @State private networkText: string = '';
  private statusTimer: number = -1;
  private active: boolean = false;
  private lastBytes: number = -1;
  private lastSampleAt: number = 0;

  aboutToAppear(): void {
    this.active = true;
    try { this.mirrored = this.store().getSync('mirrored', false) as boolean; } catch (error) {}
    this.updateStatus();
    this.statusTimer = setInterval((): void => { this.updateStatus(); }, 1000);
  }

  aboutToDisappear(): void {
    this.active = false;
    if (this.statusTimer >= 0) { clearInterval(this.statusTimer); this.statusTimer = -1; }
  }

  private store(): preferences.Preferences {
    return preferences.getPreferencesSync(this.getUIContext().getHostContext() as common.Context,
      { name: 'harmonyx_landscape_video_controls' });
  }

  private async updateStatus(): Promise<void> {
    const now: Date = new Date();
    this.clockText = now.getHours().toString().padStart(2, '0') + ':' + now.getMinutes().toString().padStart(2, '0');
    this.batteryText = batteryInfo.batterySOC.toString() + '%';
    try {
      const bytes: number = await statistics.getAllRxBytes();
      if (!this.active) { return; }
      const at: number = Date.now();
      if (this.lastBytes >= 0 && at > this.lastSampleAt) {
        const kb: number = Math.max(0, bytes - this.lastBytes) * 1000 / (at - this.lastSampleAt) / 1024;
        this.networkText = kb >= 1024 ? (kb / 1024).toFixed(1) + ' MB/s' : kb.toFixed(1) + ' KB/s';
      }
      this.lastBytes = bytes; this.lastSampleAt = at;
    } catch (error) { this.networkText = ''; }
  }

  private clock(seconds: number): string {
    const value: number = Math.max(0, Math.floor(seconds));
    return Math.floor(value / 60).toString().padStart(2, '0') + ':' + (value % 60).toString().padStart(2, '0');
  }

  private tap(action: () => void): void { hapticTick(); this.onInteraction(); action(); }

  private entrance(from: number): TransitionEffect {
    return TransitionEffect.OPACITY.combine(TransitionEffect.translate({ x: from }))
      .animation({ duration: 300, curve: Curve.EaseInOut });
  }

  private ownerWidth(): number {
    const name: string = this.sourceTweet?.author.name ?? '';
    const width: number = this.getUIContext().getMeasureUtils().measureText({ textContent: name,
      fontFamily: this.appFontFamily, fontSize: $r('sys.float.Body_S') });
    return Math.min(230, Math.max(100, this.getUIContext().px2vp(width) + 65));
  }

  @LocalBuilder
  private GlassBacking(): void {
    // Keep the native material host outside the visible control bounds.
    MaterialButton({ nativeMaterialHost: true, buttonWidth: '100%', buttonHeight: '100%', buttonRadius: $r('app.float.landscape_player_glass_radius'),
      surfaceColor: $r('app.color.video_control_glass_tint'), materialLevel: 2, enableFallbackBlur: true,
      lightColor: Color.White, applyShadow: true, enableHdrHighlight: false, buttonPressFeedback: false })
      .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
  }

  private mirror(): void {
    this.onInteraction(); hapticTick();
    this.getUIContext().animateTo({ duration: 300, curve: Curve.EaseInOut }, (): void => {
      this.mirrored = !this.mirrored; this.mirrorAngle += 180;
    });
    try { const store: preferences.Preferences = this.store(); store.putSync('mirrored', this.mirrored); store.flushSync(); }
    catch (error) {}
  }

  @LocalBuilder
  private Icon(symbol: Resource, label: Resource, action: () => void): void {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph(symbol).fontSize($r('app.float.landscape_player_icon')).fontColor([$r('app.color.text_on_brand')])
    }.width($r('app.float.landscape_player_target')).height($r('app.float.landscape_player_target'))
      .backgroundColor(Color.Transparent).accessibilityText(label).monopolizeEvents(true)
      .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.85 })
      .onClick((): void => this.tap(action))
  }

  @LocalBuilder
  private PlayButton(): void {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      if (this.playing) {
        SymbolGlyph($r('sys.symbol.pause_fill')).fontSize($r('app.float.landscape_player_icon')).fontColor([$r('app.color.text_on_brand')])
      } else {
        SymbolGlyph($r('sys.symbol.play_fill')).fontSize($r('app.float.landscape_player_icon')).fontColor([$r('app.color.text_on_brand')])
      }
    }.width($r('app.float.landscape_player_target')).height($r('app.float.landscape_player_target'))
      .backgroundColor(Color.Transparent).monopolizeEvents(true).id('landscape-control-play')
      .accessibilityText(this.playing ? $r('app.string.video_pause') : $r('app.string.video_play'))
      .onClick((): void => this.tap(this.onPlayPause))
  }

  @LocalBuilder
  private MuteButton(): void {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      if (this.muted) {
        SymbolGlyph($r('sys.symbol.speaker_slash_fill')).fontSize($r('app.float.landscape_player_icon')).fontColor([$r('app.color.text_on_brand')])
      } else {
        SymbolGlyph($r('sys.symbol.speaker_wave_2_fill')).fontSize($r('app.float.landscape_player_icon')).fontColor([$r('app.color.text_on_brand')])
      }
    }.width($r('app.float.landscape_player_target')).height($r('app.float.landscape_player_target'))
      .backgroundColor(Color.Transparent).monopolizeEvents(true).id('landscape-control-mute')
      .accessibilityText(this.muted ? $r('app.string.video_unmute') : $r('app.string.video_mute'))
      .onClick((): void => this.tap(this.onMute))
  }

  @LocalBuilder
  private Owner(): void {
    Row({ space: 6 }) {
      if (this.sourceTweet !== null) {
        if (this.mirrored) { this.FollowButton() }
        Stack() {
        MaterialButton({ nativeMaterialHost: true, buttonWidth: this.ownerWidth(), buttonHeight: $r('app.float.landscape_player_target'),
          buttonRadius: $r('app.float.landscape_player_glass_radius'), surfaceColor: $r('app.color.video_control_glass_tint'),
          materialLevel: 2, enableFallbackBlur: true, applyShadow: true, lightColor: Color.White,
          buttonMonopolizeEvents: true, onButtonClick: (): void => { this.onInteraction(); this.onBack(); } }) {
          Row({ space: 8 }) {
            if (this.mirrored) { this.OwnerName(); this.OwnerAvatar() }
            else { this.OwnerAvatar(); this.OwnerName() }
          }.padding({ left: this.mirrored ? 15 : 6, right: this.mirrored ? 6 : 15, top: 6, bottom: 6 })
        }
        }.id('landscape-control-owner').accessibilityText($r('app.string.common_back'))
        if (!this.mirrored) { this.FollowButton() }
      } else { this.Icon($r('sys.symbol.arrow_left'), $r('app.string.common_back'), this.onBack) }
    }.transition(this.entrance(this.mirrored ? -45 : 45))
  }

  @LocalBuilder
  private OwnerAvatar(): void {
    if (this.sourceTweet !== null) {
      ProxyAvatar({ url: this.sourceTweet.author.avatarUrl ?? '', avatarSize: 36, radius: 18,
        fallbackText: this.sourceTweet.author.name.substring(0, 1), fallbackColor: this.sourceTweet.author.avatarColor })
    }
  }

  @LocalBuilder
  private OwnerName(): void {
    if (this.sourceTweet !== null) {
      Text(this.sourceTweet.author.name).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S'))
        .fontColor($r('app.color.text_on_brand')).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
    }
  }

  @LocalBuilder
  private FollowButton(): void {
    Stack() {
    MaterialButton({ nativeMaterialHost: true, buttonWidth: $r('app.float.landscape_player_target'), buttonHeight: $r('app.float.landscape_player_target'),
      buttonRadius: $r('app.float.landscape_player_glass_radius'), surfaceColor: $r('app.color.video_control_glass_tint'),
      materialLevel: 2, enableFallbackBlur: true, applyShadow: true, lightColor: Color.White, buttonMonopolizeEvents: true,
      onButtonClick: (): void => { this.onInteraction(); this.onFollow(); } }) {
      SymbolGlyph(this.authorFollowing ? $r('sys.symbol.checkmark_circle_fill') : $r('sys.symbol.plus_circle'))
        .fontSize(26).fontColor([this.authorFollowing ? $r('app.color.brand') : $r('app.color.text_on_brand')])
    }
    }.id('landscape-control-follow').accessibilityText($r('app.string.profile_detail_follow'))
  }

  @LocalBuilder
  private TopActions(): void {
    Stack() {
      this.GlassBacking()
    Row({ space: 2 }) {
      if (this.mirrored) {
        this.TopAction($r('sys.symbol.ellipsis_circle'), $r('app.string.video_controls_more'), this.onMore)
        this.TopAction($r('sys.symbol.aspectratio'), $r('app.string.video_controls_aspect'), this.onAspect)
      }
      this.BackgroundAction()
      if (!this.mirrored) {
        this.TopAction($r('sys.symbol.aspectratio'), $r('app.string.video_controls_aspect'), this.onAspect)
        this.TopAction($r('sys.symbol.ellipsis_circle'), $r('app.string.video_controls_more'), this.onMore)
      }
    }.padding($r('app.float.landscape_player_glass_padding'))
    }.width($r('app.float.landscape_player_top_capsule_width')).height($r('app.float.landscape_player_top_capsule_height'))
      .id('landscape-control-top-capsule')
      .transition(this.entrance(this.mirrored ? 45 : -45))
  }

  @LocalBuilder
  private TopAction(symbol: Resource, label: Resource, action: () => void): void {
    Button({ type: ButtonType.Capsule, stateEffect: true }) {
      Column({ space: 2 }) {
        SymbolGlyph(symbol).fontSize($r('app.float.landscape_player_top_icon')).fontColor([$r('app.color.text_on_brand')])
        Text(label).fontSize($r('app.float.landscape_player_top_label')).fontColor($r('app.color.text_on_brand'))
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }.width($r('app.float.landscape_player_top_width')).height($r('app.float.landscape_player_target'))
      .backgroundColor(Color.Transparent).accessibilityText(label).monopolizeEvents(true)
      .onClick((): void => this.tap(action))
  }

  @LocalBuilder
  private BackgroundAction(): void {
    Button({ type: ButtonType.Capsule, stateEffect: true }) {
      Column({ space: 2 }) {
        if (this.backgroundAudio) {
          SymbolGlyph($r('sys.symbol.headphones')).fontSize($r('app.float.landscape_player_top_icon'))
            .fontColor([$r('app.color.text_on_brand')])
        } else {
          SymbolGlyph($r('sys.symbol.rectangle_on_rectangle')).fontSize($r('app.float.landscape_player_top_icon'))
            .fontColor([$r('app.color.text_on_brand')])
        }
        Text($r('app.string.video_controls_background')).fontSize($r('app.float.landscape_player_top_label'))
          .fontColor($r('app.color.text_on_brand')).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }.width($r('app.float.landscape_player_top_width')).height($r('app.float.landscape_player_target'))
      .backgroundColor(Color.Transparent).monopolizeEvents(true).id('landscape-control-background')
      .accessibilityText($r('app.string.settings_video_background_audio')).onClick((): void => this.tap(this.onBackground))
  }

  @LocalBuilder
  private PrimaryActions(): void {
    Row({ space: 14 }) {
      if (!this.mirrored) { this.PlayButton(); this.MuteButton() }
      if (this.danmakuAvailable && this.mirrored) {
        this.SendDanmakuButton()
      }
      if (this.danmakuAvailable) {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.message')).fontSize($r('app.float.landscape_player_icon'))
            .fontColor([this.danmakuEnabled ? $r('app.color.text_on_brand') : $r('app.color.video_feed_secondary_text')])
        }.width($r('app.float.landscape_player_target')).height($r('app.float.landscape_player_target'))
          .backgroundColor(Color.Transparent).monopolizeEvents(true).id('landscape-control-danmaku')
          .accessibilityText($r('app.string.video_danmaku_toggle')).onClick((): void => this.tap(this.onDanmakuToggle))
        if (!this.mirrored) { this.SendDanmakuButton() }
      }
      if (this.mirrored) { this.MuteButton(); this.PlayButton() }
    }.transition(this.entrance(this.mirrored ? -45 : 45))
  }

  @LocalBuilder
  private SendDanmakuButton(): void {
    Button($r('app.string.video_danmaku_send'), { type: ButtonType.Capsule, stateEffect: true })
      .fontSize($r('sys.float.Caption_M')).fontColor($r('app.color.text_on_brand'))
      .height(34).backgroundColor($r('app.color.media_viewer_control')).monopolizeEvents(true)
      .onClick((): void => this.tap(this.onDanmakuSend))
  }

  @LocalBuilder
  private SecondaryActions(): void {
    Row({ space: 8 }) {
      if (this.mirrored) {
        this.FullscreenButton()
        if (this.downloadAvailable) { this.DownloadButton() }
        this.QualityButton()
      }
      Stack() {
      MaterialButton({ nativeMaterialHost: true, buttonWidth: $r('app.float.landscape_player_speed_width'), buttonHeight: $r('app.float.landscape_player_target'),
        buttonRadius: $r('app.float.landscape_player_glass_radius'), surfaceColor: $r('app.color.video_control_glass_tint'),
        materialLevel: 2, enableFallbackBlur: true, applyShadow: true, lightColor: Color.White, buttonMonopolizeEvents: true,
        onButtonClick: (): void => { this.onInteraction(); this.onRate(); } }) {
        Row({ space: 5 }) {
          Text(videoHoldSpeedLabel(this.holdSpeedActive ? this.holdSpeedRate : this.rates[this.rateIndex]))
            .fontSize($r('app.float.landscape_player_value_font')).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_on_brand')).maxLines(1)
          Text($r('app.string.video_controls_speed')).fontSize($r('app.float.landscape_player_label_font'))
            .fontColor($r('app.color.text_on_brand')).maxLines(1)
        }
      }
      }.accessibilityText($r('app.string.video_playback_speed')).id('landscape-control-rate')
      if (!this.mirrored) {
        this.QualityButton()
        if (this.downloadAvailable) { this.DownloadButton() }
        this.FullscreenButton()
      }
    }.transition(this.entrance(this.mirrored ? 45 : -45))
  }

  @LocalBuilder
  private QualityButton(): void {
    Stack() {
    MaterialButton({ nativeMaterialHost: true, buttonWidth: $r('app.float.landscape_player_quality_width'), buttonHeight: $r('app.float.landscape_player_target'),
      buttonRadius: $r('app.float.landscape_player_glass_radius'), surfaceColor: $r('app.color.video_control_glass_tint'),
      materialLevel: 2, enableFallbackBlur: true, applyShadow: true, lightColor: Color.White, buttonMonopolizeEvents: true,
      onButtonClick: (): void => { this.onInteraction(); this.onQuality(); } }) {
      Column({ space: 1 }) {
        Text(this.qualityLabel).fontSize($r('app.float.landscape_player_label_font')).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_on_brand')).maxLines(1)
        Text($r('app.string.video_feed_quality')).fontSize($r('app.float.landscape_player_top_label'))
          .fontColor($r('app.color.text_on_brand')).maxLines(1)
      }
    }
    }.accessibilityText($r('app.string.video_feed_quality')).id('landscape-control-quality')
  }

  @LocalBuilder
  private DownloadButton(): void {
    Stack() {
    MaterialButton({ nativeMaterialHost: true, buttonWidth: $r('app.float.landscape_player_download_width'), buttonHeight: $r('app.float.landscape_player_target'),
      buttonRadius: $r('app.float.landscape_player_glass_radius'), surfaceColor: $r('app.color.video_control_glass_tint'),
      materialLevel: 2, enableFallbackBlur: true, applyShadow: true, lightColor: Color.White, buttonMonopolizeEvents: true,
      buttonEnabled: !this.downloading, onButtonClick: (): void => { this.onInteraction(); this.onDownload(); } }) {
      Row({ space: 6 }) {
        if (this.downloading) {
          LoadingProgress().width($r('app.float.landscape_player_icon')).height($r('app.float.landscape_player_icon'))
            .color($r('app.color.text_on_brand'))
        } else {
          SymbolGlyph($r('sys.symbol.arrow_down_to_line')).fontSize($r('app.float.landscape_player_icon'))
            .fontColor([$r('app.color.text_on_brand')])
        }
        Text($r('app.string.video_controls_download')).fontSize($r('app.float.landscape_player_label_font'))
          .fontWeight(FontWeight.Bold).fontColor($r('app.color.text_on_brand')).maxLines(1)
      }
    }
    }.id('landscape-control-download').accessibilityText($r('app.string.media_download'))
  }

  @LocalBuilder
  private FullscreenButton(): void {
    this.Icon(this.fullscreen ? $r('sys.symbol.exit_full_screen') : $r('sys.symbol.arrow_up_left_and_arrow_down_right'),
      this.fullscreen ? $r('app.string.video_exit_fullscreen') : $r('app.string.video_fullscreen'), this.onFullscreen)
  }

  @LocalBuilder
  private Side(side: string): void {
    Column({ space: 12 }) {
      Column() {
        if (this.controlsVisible && !this.locked) {
          Button({ type: ButtonType.Circle, stateEffect: true }) {
            SymbolGlyph($r('sys.symbol.arrow_left_arrow_right')).fontSize(24).fontColor([$r('app.color.text_on_brand')])
              .rotate({ angle: this.mirrorAngle })
          }.width(40).height(40).backgroundColor(Color.Transparent).monopolizeEvents(true)
            .accessibilityText($r('app.string.video_controls_mirror')).id('landscape-control-mirror-' + side)
            .transition(TransitionEffect.OPACITY.combine(TransitionEffect.scale({ x: 0.6, y: 0.6 }))
              .animation({ duration: 300, curve: Curve.EaseInOut }))
            .onClick((): void => this.mirror())
        }
      }.width(40).height(40).hitTestBehavior(HitTestMode.Transparent)
      Column() {
        if ((side === 'left') !== this.mirrored) {
          if (this.controlsVisible) {
            Button({ type: ButtonType.Circle, stateEffect: true }) {
              SymbolGlyph(this.locked ? $r('sys.symbol.lock_fill') : $r('sys.symbol.lock_open_fill'))
                .fontSize(24).fontColor([$r('app.color.text_on_brand')])
            }.width(40).height(40).backgroundColor(Color.Transparent).monopolizeEvents(true)
              .accessibilityText(this.locked ? $r('app.string.video_player_unlock_controls') : $r('app.string.video_player_lock_controls'))
              .id('landscape-control-lock').onClick((): void => this.tap(this.onLock))
              .transition(TransitionEffect.OPACITY.combine(TransitionEffect.scale({ x: 0.6, y: 0.6 }))
                .animation({ duration: 300, curve: Curve.EaseInOut, delay: 60 }))
          }
        } else if (this.controlsVisible && !this.locked && this.danmakuAvailable) {
          this.Icon($r('sys.symbol.ellipsis_bubble'), $r('app.string.action_reply'), this.onComment)
        }
      }.width(40).height(40).hitTestBehavior(HitTestMode.Transparent)
    }.position({ x: side === 'left' ? 36 : '100%', y: '50%' })
      .translate({ x: side === 'left' ? 0 : -76, y: '-50%' }).hitTestBehavior(HitTestMode.Transparent)
  }

  build(): void {
    Stack() {
      if (this.controlsVisible && !this.locked) {
        Column() {
          Stack() {
            Row() {
              if (this.mirrored) { this.TopActions(); Blank(); this.Owner() }
              else { this.Owner(); Blank(); this.TopActions() }
            }.width('100%').height(56).padding({ left: 19, right: 16 }).margin({ top: 20 })
            Row({ space: 10 }) {
              Text(this.networkText).fontSize($r('sys.float.Body_S')).fontColor($r('app.color.text_on_brand'))
              Text(this.clockText).fontSize($r('sys.float.Body_S')).fontColor($r('app.color.text_on_brand')).fontWeight(FontWeight.Bold)
              Text(this.batteryText).fontSize($r('sys.float.Body_S')).fontColor($r('app.color.text_on_brand'))
            }.position({ x: '50%', y: 0 }).translate({ x: '-50%' }).hitTestBehavior(HitTestMode.None)
          }.width('100%').padding({ top: this.statusBarHeight })
            .linearGradient({ direction: GradientDirection.Bottom,
              colors: [[$r('app.color.video_control_gradient_bottom'), 0], [$r('app.color.video_control_gradient_top'), 1]] })
          Blank()
          Column() {
            if (this.sourceTweet !== null && this.sourceTweet.text.length > 0) {
              Text(this.sourceTweet.text).fontFamily(this.appFontFamily).fontSize($r('sys.float.Caption_M'))
                .fontColor($r('app.color.text_on_brand')).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%').padding({ left: 37, right: 37 }).margin({ bottom: 8 })
                .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: 8 }))
                  .animation({ duration: 300, curve: Curve.EaseInOut }))
            }
            Row({ space: 8 }) {
              Text(this.clock(this.scrubbing ? this.scrubPosition : this.positionSeconds)).fontSize($r('sys.float.Caption_M'))
                .fontColor($r('app.color.text_on_brand')).width(50).textAlign(TextAlign.End).maxFontScale(1)
              Slider({ value: this.scrubbing ? this.scrubPosition : this.positionSeconds, min: 0,
                max: this.duration > 0 ? this.duration : 1, step: 1, style: SliderStyle.OutSet })
                .layoutWeight(1).height(44).trackThickness(this.scrubbing ? 5 : 4)
                .selectedColor($r('app.color.text_on_brand')).blockColor($r('app.color.text_on_brand'))
                .trackColor($r('app.color.video_control_progress_track')).monopolizeEvents(true).id('landscape-player-seek')
                .onChange((value: number, mode: SliderChangeMode): void => this.onSeek(value, mode))
                .onTouch((event: TouchEvent): void => {
                  if (event.type === TouchType.Cancel && this.scrubbing) { this.onSeek(this.scrubPosition, SliderChangeMode.End); }
                })
              Text(this.clock(this.duration)).fontSize($r('sys.float.Caption_M')).fontColor($r('app.color.text_on_brand'))
                .width(50).textAlign(TextAlign.Start).maxFontScale(1)
            }.width('100%').height(44).padding({ left: 16, right: 16 })
              .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: 8 }))
                .animation({ duration: 300, curve: Curve.EaseInOut }))
            Row() {
              if (this.mirrored) { this.SecondaryActions(); Blank(); this.PrimaryActions() }
              else { this.PrimaryActions(); Blank(); this.SecondaryActions() }
            }.width('100%').height($r('app.float.landscape_player_target')).padding({ left: 16, right: 16 })
          }.width('100%').padding({ bottom: this.navigationIndicatorHeight + 10 })
            .linearGradient({ direction: GradientDirection.Top,
              colors: [[$r('app.color.video_control_gradient_bottom'), 0], [$r('app.color.video_control_gradient_top'), 1]] })
        }.width('100%').height('100%').hitTestBehavior(HitTestMode.Transparent)
          .transition(TransitionEffect.OPACITY.animation({ duration: 300, curve: Curve.EaseInOut }))
      }
      if (this.fullscreen) { this.Side('left'); this.Side('right') }
    }.width('100%').height('100%').hitTestBehavior(HitTestMode.Transparent)
  }
}
