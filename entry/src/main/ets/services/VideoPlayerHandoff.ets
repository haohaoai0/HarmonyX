import { media as mediaKit } from '@kit.MediaKit';
import { VideoCacheLease, VideoDataSourceLease } from './VideoPlaybackCache';

export class VideoPlayerHandoffPayload {
  player: mediaKit.AVPlayer;
  source: string;
  cacheLease: VideoCacheLease | null;
  dataSourceLease: VideoDataSourceLease | null;
  playerState: string;
  positionSeconds: number;
  durationSeconds: number;
  ready: boolean;
  playing: boolean;
  muted: boolean;
  volume: number;

  constructor(player: mediaKit.AVPlayer, source: string, cacheLease: VideoCacheLease | null,
    dataSourceLease: VideoDataSourceLease | null, playerState: string, positionSeconds: number,
    durationSeconds: number, ready: boolean, playing: boolean, muted: boolean, volume: number) {
    this.player = player;
    this.source = source;
    this.cacheLease = cacheLease;
    this.dataSourceLease = dataSourceLease;
    this.playerState = playerState;
    this.positionSeconds = positionSeconds;
    this.durationSeconds = durationSeconds;
    this.ready = ready;
    this.playing = playing;
    this.muted = muted;
    this.volume = volume;
  }
}

export type VideoPlayerTakeCallback = () => VideoPlayerHandoffPayload | null;
export type VideoPlayerExpireCallback = () => void;

export class VideoPlayerReturnTarget {
  owner: string;
  sourceId: string;
  canAccept: () => boolean;
  accept: (payload: VideoPlayerHandoffPayload) => void;

  constructor(owner: string, sourceId: string, canAccept: () => boolean, accept: (payload: VideoPlayerHandoffPayload) => void) {
    this.owner = owner;
    this.sourceId = sourceId;
    this.canAccept = canAccept;
    this.accept = accept;
  }
}

class VideoPlayerHandoffOffer {
  mediaId: string;
  player: mediaKit.AVPlayer;
  take: VideoPlayerTakeCallback;
  expire: VideoPlayerExpireCallback;

  constructor(mediaId: string, player: mediaKit.AVPlayer, take: VideoPlayerTakeCallback,
    expire: VideoPlayerExpireCallback) {
    this.mediaId = mediaId;
    this.player = player;
    this.take = take;
    this.expire = expire;
  }
}

const REQUEST_TIMEOUT_MS: number = 5000;

export class VideoPlayerHandoffStore {
  private offers: Map<string, VideoPlayerHandoffOffer> = new Map<string, VideoPlayerHandoffOffer>();
  private requestedMediaId: string = '';
  private requestTimer: number = -1;
  private requestRevision: number = 0;
  private returnTargets: Map<string, VideoPlayerReturnTarget> = new Map<string, VideoPlayerReturnTarget>();
  private returningMediaId: string = '';
  private returningOwner: string = '';

  register(mediaId: string, player: mediaKit.AVPlayer, take: VideoPlayerTakeCallback,
    expire: VideoPlayerExpireCallback, returnTarget: VideoPlayerReturnTarget | null = null): void {
    this.offers.set(mediaId, new VideoPlayerHandoffOffer(mediaId, player, take, expire));
    if (returnTarget !== null) { this.registerReturnTarget(mediaId, returnTarget); }
  }

  registerReturnTarget(mediaId: string, target: VideoPlayerReturnTarget): void {
    this.returnTargets.set(mediaId + '|' + target.sourceId, target);
  }

  returnToSource(mediaId: string, sourceId: string): boolean {
    const target: VideoPlayerReturnTarget | undefined = this.returnTargets.get(mediaId + '|' + sourceId);
    if (target === undefined || !target.canAccept() || !this.offers.has(mediaId)) { return false; }
    // The source may resume underneath the still-mounted dialog for this
    // handoff. Other timeline players remain covered until the dialog exits.
    this.returningMediaId = mediaId;
    this.returningOwner = target.owner;
    this.request(mediaId);
    const payload: VideoPlayerHandoffPayload | null = this.take(mediaId);
    if (payload === null) { this.completeReturn(mediaId); return false; }
    target.accept(payload);
    return true;
  }

  isReturning(mediaId: string, owner: string = ''): boolean {
    return mediaId.length > 0 && this.returningMediaId === mediaId &&
      (owner.length === 0 || this.returningOwner === owner);
  }

  completeReturn(mediaId: string): void {
    if (this.returningMediaId === mediaId) { this.returningMediaId = ''; this.returningOwner = ''; }
  }

  unregisterReturnTarget(mediaId: string, owner: string): void {
    const prefix: string = mediaId + '|';
    this.returnTargets.forEach((target: VideoPlayerReturnTarget, key: string): void => {
      if (key.startsWith(prefix) && target.owner === owner) { this.returnTargets.delete(key); }
    });
  }

  request(mediaId: string): void {
    this.clearRequestTimer();
    this.requestedMediaId = mediaId;
    const revision: number = ++this.requestRevision;
    this.requestTimer = setTimeout((): void => {
      if (revision !== this.requestRevision) { return; }
      this.requestTimer = -1;
      const offer: VideoPlayerHandoffOffer | undefined = this.offers.get(mediaId);
      if (offer !== undefined) {
        this.offers.delete(mediaId);
        this.completeReturn(mediaId);
        offer.expire();
      }
      if (this.requestedMediaId === mediaId) {
        this.requestedMediaId = '';
      }
    }, REQUEST_TIMEOUT_MS);
  }

  isRequested(mediaId: string): boolean {
    return mediaId.length > 0 && this.requestedMediaId === mediaId && this.offers.has(mediaId);
  }

  take(mediaId: string): VideoPlayerHandoffPayload | null {
    if (mediaId.length === 0 || mediaId !== this.requestedMediaId) {
      return null;
    }
    const offer: VideoPlayerHandoffOffer | undefined = this.offers.get(mediaId);
    if (offer === undefined) {
      this.clearRequest();
      return null;
    }
    this.offers.delete(mediaId);
    this.clearRequest();
    return offer.take();
  }

  unregister(mediaId: string, player: mediaKit.AVPlayer | null): void {
    if (player === null) {
      return;
    }
    const offer: VideoPlayerHandoffOffer | undefined = this.offers.get(mediaId);
    if (offer !== undefined && offer.player === player) {
      this.offers.delete(mediaId);
    }
  }

  private clearRequest(): void {
    ++this.requestRevision;
    this.requestedMediaId = '';
    this.clearRequestTimer();
  }

  private clearRequestTimer(): void {
    if (this.requestTimer >= 0) {
      clearTimeout(this.requestTimer);
      this.requestTimer = -1;
    }
  }
}

export const videoPlayerHandoff: VideoPlayerHandoffStore = new VideoPlayerHandoffStore();
