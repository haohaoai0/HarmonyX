import { avSession, AVCastPickerState } from '@kit.AVSessionKit';
import { common } from '@kit.AbilityKit';
import hilog from '@ohos.hilog';

// What the media session needs from whatever is playing. The built-in Video
// component and the AVPlayer-backed surface player both provide these three
// calls, so the session does not have to know which one owns playback.
export interface VideoPlaybackHandle {
  startPlayback(): void;

  pausePlayback(): void;

  seekPlayback(seconds: number): void;
  stopPlayback?(): void;
  castStateChanged?(casting: boolean, state: avSession.AVPlaybackState | undefined): void;
  castFailed?(): void;
}

// A feed can render many Video components, but only one may own system controls.
class VideoMediaSession {
  private session: avSession.AVSession | null = null;
  private ownerId: string = '';
  private pendingOwnerId: string = '';
  private handle: VideoPlaybackHandle | null = null;
  private onOwnerReleased: (() => void) | null = null;
  private generation: number = 0;
  private durationMs: number = 0;
  private positionMs: number = 0;
  private cover: string = '';
  private title: string = 'X 视频';
  private castMediaUrl: string = '';
  private castController: avSession.AVCastController | null = null;
  private castPicker: avSession.AVCastPickerHelper | null = null;
  private castEpoch: number = 0;
  private playing: boolean = false;
  private speed: number = 1;

  isOwner(id: string): boolean {
    return id.length > 0 && this.ownerId === id;
  }

  async claim(context: common.Context, id: string, cover: string, handle: VideoPlaybackHandle,
    durationSeconds: number, onReleased: () => void, title: string = 'X 视频',
    sessionType: avSession.AVSessionType = 'video', castMediaUrl: string = ''): Promise<boolean> {
    if (this.ownerId === id && this.session !== null) {
      if (castMediaUrl.length > 0) { this.castMediaUrl = castMediaUrl; }
      return true;
    }
    const generation: number = ++this.generation;
    this.pendingOwnerId = id;
    const previous: VideoPlaybackHandle | null = this.handle;
    if (previous !== null && this.ownerId !== id) previous.pausePlayback();
    await this.releaseCurrent();
    if (generation !== this.generation) return false;
    this.ownerId = id;
    this.pendingOwnerId = '';
    this.handle = handle;
    this.onOwnerReleased = onReleased;
    this.durationMs = Math.max(0, Math.round(durationSeconds * 1000));
    this.positionMs = 0;
    this.cover = cover;
    this.title = title;
    this.castMediaUrl = castMediaUrl;
    try {
      const session: avSession.AVSession = await avSession.createAVSession(context, 'HarmonyXMedia', sessionType);
      if (generation !== this.generation) {
        await session.destroy();
        return false;
      }
      this.session = session;
      await session.setAVMetadata(this.metadata(id));
      if (sessionType === 'video' && castMediaUrl.length > 0) {
        await session.setExtras({ requireAbilityList: ['url-cast'] });
        session.on('outputDeviceChange', (state: avSession.ConnectionState,
          devices: avSession.OutputDeviceInfo): void => {
          this.onOutputDeviceChanged(session, id, state, devices);
        });
      }
      session.on('play', () => {
        if (this.isOwner(id)) handle.startPlayback();
      });
      session.on('pause', () => {
        if (this.isOwner(id)) handle.pausePlayback();
      });
      session.on('stop', () => {
        if (this.isOwner(id)) {
          if (handle.stopPlayback !== undefined) { handle.stopPlayback(); } else { handle.pausePlayback(); }
        }
      });
      session.on('seek', (position: number) => {
        if (this.isOwner(id)) handle.seekPlayback(Math.max(0, position) / 1000);
      });
      await session.activate();
      return generation === this.generation;
    } catch (err) {
      await this.release(id);
      return false;
    }
  }

  private metadata(id: string): avSession.AVMetadata {
    const metadata: avSession.AVMetadata = {
      assetId: id, title: this.title, mediaImage: this.cover, duration: this.durationMs
    };
    if (this.castMediaUrl.length > 0) {
      metadata.filter = avSession.ProtocolType.TYPE_CAST_PLUS_STREAM | avSession.ProtocolType.TYPE_DLNA;
    }
    return metadata;
  }

  async selectCastDevice(context: common.Context, id: string,
    onPickerChanged: (visible: boolean) => void): Promise<void> {
    if (!this.isOwner(id) || this.session === null || this.castMediaUrl.length === 0) {
      throw new Error('Current video session is unavailable');
    }
    const picker: avSession.AVCastPickerHelper = new avSession.AVCastPickerHelper(context);
    this.castPicker = picker;
    picker.on('pickerStateChange', (state: AVCastPickerState): void => {
      if (this.castPicker !== picker) { return; }
      if (state === AVCastPickerState.STATE_APPEARING) {
        onPickerChanged(true);
      } else if (state === AVCastPickerState.STATE_DISAPPEARING) {
        onPickerChanged(false);
        picker.off('pickerStateChange');
        this.castPicker = null;
      }
    });
    try {
      await picker.select({ sessionType: 'video' });
    } catch (error) {
      picker.off('pickerStateChange');
      if (this.castPicker === picker) { this.castPicker = null; }
      onPickerChanged(false);
      throw new Error('Unable to open the native cast picker');
    }
  }

  isCasting(id: string): boolean {
    return this.isOwner(id) && this.castController !== null;
  }

  sendCastCommand(id: string, command: avSession.AVCastControlCommand): void {
    const controller: avSession.AVCastController | null = this.castController;
    if (!this.isOwner(id) || controller === null) { return; }
    controller.sendControlCommand(command).catch((): void => {
      if (this.isOwner(id) && this.castController === controller) { this.handle?.castFailed?.(); }
    });
  }

  private async onOutputDeviceChanged(session: avSession.AVSession, id: string,
    state: avSession.ConnectionState, devices: avSession.OutputDeviceInfo): Promise<void> {
    if (this.session !== session || !this.isOwner(id)) { return; }
    const device: avSession.DeviceInfo | undefined = devices.devices[0];
    if (state === avSession.ConnectionState.STATE_CONNECTED &&
      device?.castCategory === avSession.AVCastCategory.CATEGORY_REMOTE) {
      if (this.castController !== null) { return; }
      const epoch: number = ++this.castEpoch;
      const wasPlaying: boolean = this.playing;
      const startPosition: number = this.positionMs;
      try {
        const controller: avSession.AVCastController = await session.getAVCastController();
        if (this.session !== session || epoch !== this.castEpoch || !this.isOwner(id)) { return; }
        // Pause the native local player before commands begin targeting the receiver.
        this.handle?.pausePlayback();
        this.castController = controller;
        this.handle?.castStateChanged?.(true, undefined);
        controller.on('playbackStateChange', 'all', (remote: avSession.AVPlaybackState): void => {
          if (this.castController !== controller || this.session !== session) { return; }
          if (remote.position !== undefined) { this.positionMs = remote.position.elapsedTime; }
          if (remote.state !== undefined) {
            this.playing = remote.state === avSession.PlaybackState.PLAYBACK_STATE_PLAY;
          }
          if (remote.speed !== undefined) { this.speed = remote.speed; }
          this.handle?.castStateChanged?.(true, remote);
          session.setAVPlaybackState(remote).catch((): void => {});
        });
        controller.on('endOfStream', (): void => {
          if (this.castController === controller && this.session === session) {
            this.playing = false;
            session.stopCasting().catch((): void => {});
          }
        });
        const item: avSession.AVQueueItem = {
          itemId: 0,
          description: {
            assetId: id, title: this.title, mediaImage: this.cover, mediaUri: this.castMediaUrl,
            mediaType: 'VIDEO', startPosition: startPosition, duration: this.durationMs, appName: 'Croak X'
          }
        };
        await controller.prepare(item);
        if (this.session !== session || epoch !== this.castEpoch) { return; }
        await controller.start(item);
        if (this.session !== session || epoch !== this.castEpoch) { return; }
        await controller.sendControlCommand({ command: 'setSpeed', parameter: this.speed });
        if (!wasPlaying) { await controller.sendControlCommand({ command: 'pause' }); }
      } catch (error) {
        if (this.session === session && epoch === this.castEpoch) {
          hilog.warn(0xFF00, 'HarmonyX-Media', 'Native video casting failed');
          this.handle?.castFailed?.();
          this.returnToLocal(false);
          session.stopCasting().catch((): void => {});
          if (wasPlaying) { this.handle?.startPlayback(); }
        }
      }
    } else if (state === avSession.ConnectionState.STATE_DISCONNECTED ||
      (state === avSession.ConnectionState.STATE_CONNECTED &&
        device?.castCategory === avSession.AVCastCategory.CATEGORY_LOCAL)) {
      ++this.castEpoch;
      this.returnToLocal(true);
    }
  }

  private returnToLocal(resume: boolean): void {
    const controller: avSession.AVCastController | null = this.castController;
    if (controller === null) { return; }
    this.castController = null;
    controller.off('playbackStateChange');
    controller.off('endOfStream');
    this.handle?.castStateChanged?.(false, undefined);
    if (resume) {
      this.handle?.seekPlayback(this.positionMs / 1000);
      if (this.playing) { this.handle?.startPlayback(); }
    }
  }

  updateDuration(id: string, seconds: number): void {
    if (!this.isOwner(id)) return;
    this.durationMs = Math.max(0, Math.round(seconds * 1000));
    const session: avSession.AVSession | null = this.session;
    if (session !== null) {
      session.setAVMetadata(this.metadata(id)).catch(() => {});
    }
  }

  updatePosition(id: string, seconds: number): void {
    if (this.isOwner(id)) this.positionMs = Math.max(0, Math.round(seconds * 1000));
  }

  updatePlayback(id: string, playing: boolean, speed: number = 1.0): void {
    if (!this.isOwner(id) || this.session === null) return;
    if (this.castController !== null) { return; }
    this.playing = playing;
    this.speed = speed;
    const state: avSession.AVPlaybackState = {
      state: playing ? avSession.PlaybackState.PLAYBACK_STATE_PLAY :
        avSession.PlaybackState.PLAYBACK_STATE_PAUSE,
      position: { elapsedTime: this.positionMs, updateTime: Date.now() },
      speed: speed
    };
    this.session.setAVPlaybackState(state).catch(() => {});
  }

  async release(id: string): Promise<void> {
    if (!this.isOwner(id) && this.pendingOwnerId !== id) return;
    ++this.generation;
    this.pendingOwnerId = '';
    await this.releaseCurrent();
  }

  private async releaseCurrent(): Promise<void> {
    const session: avSession.AVSession | null = this.session;
    const callback: (() => void) | null = this.onOwnerReleased;
    const wasCasting: boolean = this.castController !== null;
    ++this.castEpoch;
    this.returnToLocal(false);
    this.castMediaUrl = '';
    this.playing = false;
    this.session = null;
    this.ownerId = '';
    this.handle = null;
    this.onOwnerReleased = null;
    if (callback !== null) callback();
    if (session !== null) {
      try {
        if (wasCasting) { await session.stopCasting(); }
        await session.deactivate();
        await session.destroy();
      } catch (err) {
        // The UI player is already detached; no stale session should be reused.
      }
    }
  }
}

export const videoMediaSession: VideoMediaSession = new VideoMediaSession();
