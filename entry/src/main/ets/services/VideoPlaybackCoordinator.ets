// Coordinates audio ownership. Replaced owners silence Home previews while
// viewer pages keep playback exclusive during a swipe.
export const STORAGE_KEY_VIDEO_FEED_ACTIVE: string = 'harmonyx.video_feed_active';

class VideoPlaybackOwner {
  mediaId: string;
  pause: () => void;
  preview: boolean;
  selected: boolean;

  constructor(mediaId: string, pause: () => void, preview: boolean = false, selected: boolean = false) {
    this.mediaId = mediaId;
    this.pause = pause;
    this.preview = preview;
    this.selected = selected;
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

  claimPreview(mediaId: string, silence: () => void, selected: boolean = false): boolean {
    if (mediaId.length === 0) {
      return false;
    }
    const previous: VideoPlaybackOwner | null = this.owner;
    if (previous !== null && previous.mediaId !== mediaId &&
      (!previous.preview || previous.selected && !selected)) {
      return false;
    }
    // Native playing events renew ownership without forgetting a user's choice.
    const keepSelection: boolean = selected || previous !== null &&
      previous.mediaId === mediaId && previous.selected;
    this.owner = new VideoPlaybackOwner(mediaId, silence, true, keepSelection);
    if (previous !== null && previous.mediaId !== mediaId) {
      previous.pause();
    }
    return true;
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
