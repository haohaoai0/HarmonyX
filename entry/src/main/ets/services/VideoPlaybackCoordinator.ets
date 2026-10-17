// Keeps playback exclusive while adjacent pages overlap during a swipe.
export const STORAGE_KEY_VIDEO_FEED_ACTIVE: string = 'harmonyx.video_feed_active';

class VideoPlaybackOwner {
  mediaId: string;
  pause: () => void;

  constructor(mediaId: string, pause: () => void) {
    this.mediaId = mediaId;
    this.pause = pause;
  }
}

class VideoPlaybackCoordinator {
  private owner: VideoPlaybackOwner | null = null;

  claim(mediaId: string, pause: () => void): void {
    if (mediaId.length === 0) {
      return;
    }
    const previous: VideoPlaybackOwner | null = this.owner;
    this.owner = new VideoPlaybackOwner(mediaId, pause);
    if (previous !== null && previous.mediaId !== mediaId) {
      previous.pause();
    }
  }

  release(mediaId: string): void {
    const current: VideoPlaybackOwner | null = this.owner;
    if (current !== null && current.mediaId === mediaId) {
      this.owner = null;
    }
  }

  isOwnedByOther(mediaId: string): boolean {
    return this.owner !== null && this.owner.mediaId !== mediaId;
  }
}

export const videoPlaybackCoordinator: VideoPlaybackCoordinator = new VideoPlaybackCoordinator();
