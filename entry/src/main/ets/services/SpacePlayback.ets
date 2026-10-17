import { common } from '@kit.AbilityKit';
import { media } from '@kit.MediaKit';
import { audio } from '@kit.AudioKit';
import { BusinessError } from '@kit.BasicServicesKit';
import hilog from '@ohos.hilog';
import { SpaceRoom } from '../models/Space';
import { xPrivateClient } from './XPrivateClient';
import { xSpaceService } from './XSpaceService';
import { SpaceHlsLoader } from './SpaceHlsLoader';
import { videoPlaybackCoordinator } from './VideoPlaybackCoordinator';
import { videoMediaSession, VideoPlaybackHandle } from './VideoMediaSession';
import { videoBackgroundPlayback } from './VideoBackgroundPlayback';

export const SPACE_PLAYBACK_REVISION: string = 'harmonyx.space_playback_revision';

class SpacePlayback implements VideoPlaybackHandle {
  room: SpaceRoom | null = null;
  state: string = 'idle';
  private player: media.AVPlayer | null = null;
  private loader: SpaceHlsLoader | null = null;
  private context: common.UIAbilityContext | null = null;
  private generation: number = 0;
  private revision: number = 0;
  private timeoutId: number = -1;
  private wantsPlay: boolean = false;

  constructor() { xPrivateClient.onSessionChange((): void => { this.stop(); }); }

  async listen(context: common.UIAbilityContext, candidate: SpaceRoom): Promise<void> {
    if (this.room?.id === candidate.id && this.player !== null && this.state !== 'error' && this.state !== 'ended' &&
      !(candidate.isLive() && this.state === 'paused')) {
      this.startPlayback(); return;
    }
    const generation: number = ++this.generation;
    await this.releasePlayer();
    if (generation !== this.generation) { return; }
    this.context = context;
    this.room = candidate;
    this.wantsPlay = true;
    this.setState('loading');
    this.armTimeout(generation);
    try {
      // Always refresh the room; a card can become ended while it is visible.
      const room: SpaceRoom | null = await xSpaceService.detail(candidate.id);
      if (generation !== this.generation) { return; }
      if (room === null || !room.canListen()) { await this.fail(generation); return; }
      this.room = room;
      const stream: string = await xSpaceService.stream(room);
      if (generation !== this.generation) { return; }
      if (stream.length === 0) { await this.fail(generation); return; }
      const player: media.AVPlayer = await media.createAVPlayer();
      if (generation !== this.generation) { await player.release(); return; }
      this.player = player;
      this.loader = new SpaceHlsLoader();
      player.on('stateChange', (state: media.AVPlayerState): void => {
        if (this.player !== player || generation !== this.generation) { return; }
        hilog.info(0xFF00, 'HarmonyX-Spaces', 'player state: %{public}s', state);
        if (state === 'initialized') {
          player.audioRendererInfo = {
            content: audio.ContentType.CONTENT_TYPE_SPEECH,
            usage: audio.StreamUsage.STREAM_USAGE_MEDIA,
            rendererFlags: 0
          };
          player.prepare().catch((): void => { this.fail(generation); });
        } else if (state === 'prepared') {
          if (this.wantsPlay) { this.startPlayback(); } else { this.clearTimeout(); this.setState('paused'); }
        } else if (state === 'playing') {
          this.clearTimeout(); this.setState('playing'); this.claimSession(generation);
        } else if (state === 'paused') {
          this.clearTimeout(); this.setState('paused'); this.updateSession(false);
        } else if (state === 'completed') {
          this.clearTimeout(); this.wantsPlay = false; this.setState('ended'); this.updateSession(false);
        }
      });
      player.on('error', (error: BusinessError): void => {
        hilog.warn(0xFF00, 'HarmonyX-Spaces', 'player error: %{public}d', error.code);
        if (error.code === 5400106) {
          hilog.warn(0xFF00, 'HarmonyX-Spaces', 'unsupported format: %{public}s', error.message);
        }
        this.fail(generation);
      });
      player.on('bufferingUpdate', (type: media.BufferingInfoType): void => {
        if (this.player !== player || !this.wantsPlay) { return; }
        if (type === media.BufferingInfoType.BUFFERING_START) {
          this.setState('buffering'); this.armTimeout(generation);
        } else if (type === media.BufferingInfoType.BUFFERING_END && player.state === 'playing') {
          this.clearTimeout(); this.setState('playing');
        }
      });
      const source: media.MediaSource = media.createMediaSourceWithUrl(stream,
        { 'User-Agent': 'HarmonyX', 'Accept-Encoding': 'identity' });
      source.setMediaResourceLoaderDelegate(this.loader.delegate());
      await player.setMediaSource(source);
    } catch (error) { await this.fail(generation); }
  }

  startPlayback(): void {
    // Reconnect live audio at the current edge. A paused live HLS source can
    // retain expired playlist chunks; replay keeps its existing position.
    if (this.state === 'paused' && this.room?.isLive() && this.context !== null) {
      this.listen(this.context, this.room); return;
    }
    const player: media.AVPlayer | null = this.player;
    if (player === null) { return; }
    this.wantsPlay = true;
    if (player.state === 'prepared' || player.state === 'paused') {
      videoPlaybackCoordinator.claim(this.ownerId(), (): void => this.pausePlayback());
      this.armTimeout(this.generation);
      const generation: number = this.generation;
      player.play().catch((): void => { this.fail(generation); });
    }
  }
  pausePlayback(): void {
    this.wantsPlay = false;
    this.clearTimeout();
    const player: media.AVPlayer | null = this.player;
    if (player?.state === 'playing') {
      player.pause().catch((): void => {});
    }
    if (this.room !== null && this.state !== 'error' && this.state !== 'ended') { this.setState('paused'); }
    this.updateSession(false);
  }
  // Live Spaces cannot seek. Replay playback uses AVPlayer's own seek bounds.
  seekPlayback(seconds: number): void {
    if (this.room?.isLive() === false && this.player?.state === 'playing') {
      this.player.seek(Math.max(0, seconds * 1000));
    }
  }
  stopPlayback(): void { this.stop(); }
  async stop(): Promise<void> {
    const generation: number = ++this.generation;
    await this.releasePlayer();
    if (generation !== this.generation) { return; }
    this.room = null;
    this.setState('idle');
  }
  private ownerId(): string { return 'space:' + (this.room?.id ?? ''); }
  private setState(state: string): void {
    this.state = state;
    AppStorage.setOrCreate<number>(SPACE_PLAYBACK_REVISION, ++this.revision);
  }
  private async claimSession(generation: number): Promise<void> {
    const context: common.UIAbilityContext | null = this.context;
    const room: SpaceRoom | null = this.room;
    if (context === null || room === null) { return; }
    const owner: string = this.ownerId();
    await videoMediaSession.claim(context, owner, room.host.avatarUrl, this, 0,
      (): void => this.pausePlayback(), room.title.length > 0 ? room.title :
        context.resourceManager.getStringSync($r('app.string.side_spaces')), 'audio');
    if (generation !== this.generation || !this.wantsPlay || this.player?.state !== 'playing') { return; }
    videoMediaSession.updatePlayback(owner, true);
    videoBackgroundPlayback.start(owner, context);
  }
  private updateSession(playing: boolean): void {
    const owner: string = this.ownerId();
    videoMediaSession.updatePlayback(owner, playing);
    if (!playing && this.context !== null) { videoBackgroundPlayback.stop(owner, this.context); }
  }
  private async fail(generation: number): Promise<void> {
    if (generation !== this.generation) { return; }
    const failureGeneration: number = ++this.generation;
    await this.releasePlayer();
    if (failureGeneration !== this.generation) { return; }
    this.setState('error');
  }
  private async releasePlayer(): Promise<void> {
    this.wantsPlay = false;
    this.clearTimeout();
    const owner: string = this.ownerId();
    const player: media.AVPlayer | null = this.player;
    this.player = null;
    this.loader?.dispose(); this.loader = null;
    if (this.context !== null) { videoBackgroundPlayback.stop(owner, this.context); }
    videoPlaybackCoordinator.release(owner);
    await videoMediaSession.release(owner);
    if (player !== null) {
      player.off('stateChange'); player.off('error'); player.off('bufferingUpdate');
      try { await player.release(); } catch (error) {}
    }
  }
  private armTimeout(generation: number): void {
    this.clearTimeout();
    this.timeoutId = setTimeout((): void => {
      hilog.warn(0xFF00, 'HarmonyX-Spaces', 'playback timeout: %{public}s', this.state);
      this.fail(generation);
    }, 30000);
  }
  private clearTimeout(): void {
    if (this.timeoutId >= 0) { clearTimeout(this.timeoutId); this.timeoutId = -1; }
  }
}

export const spacePlayback: SpacePlayback = new SpacePlayback();
