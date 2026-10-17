import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { common } from '@kit.AbilityKit';
import { media } from '@kit.MediaKit';
import { audio } from '@kit.AudioKit';
import { fileIo } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import promptAction from '@ohos.promptAction';
import hilog from '@ohos.hilog';
import { ChatWaveform } from './ChatWaveform';
import { ChatVoice } from '../utils/ChatVoice';
import { chatVoicePlayback } from '../services/ChatVoicePlayback';

@Component
export struct ChatVoicePlayer {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Prop @Watch('sourceChanged') path: string = '';
  @Prop durationMs: number = 0;
  @Prop samples: number[] = [];
  @Prop outgoing: boolean = false;
  @Prop @Watch('visibilityChanged') visible: boolean = true;
  @StorageLink('harmonyx.accent_color') accentColor: string = '#007DFF';
  @State private playing: boolean = false;
  @State private busy: boolean = false;
  @State private elapsedMs: number = 0;
  @State private duration: number = 0;
  private active: boolean = true;
  private generation: number = 0;
  private player: media.AVPlayer | null = null;
  private file: fileIo.File | null = null;
  private stopPlayback: () => void = (): void => { this.release(); };

  aboutToAppear(): void { this.active = true; }
  aboutToDisappear(): void { this.active = false; this.release(); }
  private sourceChanged(): void { this.release(); this.duration = 0; }
  private visibilityChanged(): void { if (!this.visible) { this.release(); } }
  private total(): number { return this.duration > 0 ? this.duration : this.durationMs; }
  private fraction(): number { return this.total() > 0 ? this.elapsedMs / this.total() : 0; }
  private release(): void {
    this.generation++;
    const player: media.AVPlayer | null = this.player;
    const file: fileIo.File | null = this.file;
    this.player = null; this.file = null; this.playing = false; this.busy = false; this.elapsedMs = 0;
    chatVoicePlayback.release(this.stopPlayback);
    const close: () => void = (): void => { if (file !== null) { try { fileIo.closeSync(file.fd); } catch (error) {} } };
    if (player !== null) { player.release().then(close).catch(close); } else { close(); }
  }
  private failed(): void {
    if (!this.active) { return; }
    this.release();
    promptAction.showToast({ message: (getContext(this) as common.UIAbilityContext).resourceManager.getStringSync($r('app.string.chat_voice_play_failed')) });
  }
  private async toggle(): Promise<void> {
    if (this.path.length === 0 || this.busy || !this.visible) { return; }
    if (this.player !== null) {
      try {
        if (this.playing) { await this.player.pause(); }
        else { chatVoicePlayback.claim(this.stopPlayback); await this.player.play(); }
      } catch (error) { this.failed(); }
      return;
    }
    this.busy = true;
    const generation: number = ++this.generation;
    try {
      const player: media.AVPlayer = await media.createAVPlayer();
      if (!this.active || !this.visible || generation !== this.generation) { await player.release(); return; }
      this.player = player;
      chatVoicePlayback.claim(this.stopPlayback);
      player.on('stateChange', (state: string): void => {
        if (!this.active || generation !== this.generation) { return; }
        hilog.info(0xFF00, 'HarmonyX-Voice', 'player state: %{public}s', state);
        if (state === 'initialized') {
          player.audioRendererInfo = { usage: audio.StreamUsage.STREAM_USAGE_VOICE_MESSAGE, rendererFlags: 0 };
          player.prepare().catch((): void => { if (generation === this.generation) { this.failed(); } });
        } else if (state === 'prepared') {
          this.duration = player.duration; this.busy = false;
          player.play().catch((): void => { if (generation === this.generation) { this.failed(); } });
        } else if (state === 'playing') { this.playing = true; }
        else if (state === 'paused') { this.playing = false; }
        else if (state === 'completed') { this.playing = false; this.elapsedMs = 0; }
      });
      player.on('timeUpdate', (position: number): void => {
        if (this.active && generation === this.generation) { this.elapsedMs = position; }
      });
      player.on('durationUpdate', (duration: number): void => {
        if (this.active && generation === this.generation) { this.duration = duration; }
      });
      player.on('error', (error: BusinessError): void => {
        hilog.warn(0xFF00, 'HarmonyX-Voice', 'player error: %{public}d', error.code);
        if (generation === this.generation) { this.failed(); }
      });
      this.file = fileIo.openSync(this.path, fileIo.OpenMode.READ_ONLY);
      player.fdSrc = { fd: this.file.fd, offset: 0, length: fileIo.statSync(this.path).size };
    } catch (error) { if (generation === this.generation) { this.failed(); } }
  }
  private seek(fraction: number): void {
    if (this.player === null || this.total() <= 0) { return; }
    try { this.player.seek(Math.round(Math.max(0, Math.min(1, fraction)) * this.total())); }
    catch (error) { this.failed(); }
  }
  build(): void {
    Row({ space: 10 }) {
      Button({ type: ButtonType.Circle }) {
        if (this.busy) { LoadingProgress().width(18).height(18).color(this.accentColor) }
        else { SymbolGlyph(this.playing ? $r('sys.symbol.pause') : $r('sys.symbol.play_fill'))
          .fontSize(20).fontColor([this.accentColor]) }
      }.width(36).height(36).padding(0).backgroundColor(this.outgoing ? Color.White : $r('app.color.bg_field'))
        .enabled(this.path.length > 0 && this.visible && !this.busy)
        .accessibilityText(this.playing ? $r('app.string.chat_voice_pause') : $r('app.string.chat_voice_play'))
        .onClick((): void => { this.toggle(); })
      ChatWaveform({ samples: this.samples, progress: this.fraction(),
        foreground: this.outgoing ? Color.White : this.accentColor,
        dim: this.outgoing ? '#CCFFFFFF' : $r('app.color.text_secondary'),
        seekable: this.player !== null, onSeek: (fraction: number): void => { this.seek(fraction); } }).layoutWeight(1)
      Text(ChatVoice.time(Math.max(0, this.total() - this.elapsedMs))).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S'))
        .fontColor(this.outgoing ? Color.White : $r('app.color.text_secondary')).width(38).textAlign(TextAlign.End)
    }.width(260).constraintSize({ maxWidth: '100%' }).height(56)
  }
}
