// Keeps the most recent playback positions while videos move between pages.
// Limiting this history avoids retaining every post read during a long session.
const MAX_POSITION_RECORDS: number = 8;

class VideoPlaybackPosition {
  mediaId: string;
  seconds: number;

  constructor(mediaId: string, seconds: number) {
    this.mediaId = mediaId;
    this.seconds = seconds;
  }
}

class VideoPlaybackPositionStore {
  private positions: VideoPlaybackPosition[] = [];

  remember(mediaId: string, seconds: number): void {
    if (mediaId.length === 0 || !Number.isFinite(seconds)) {
      return;
    }
    let found: number = -1;
    for (let index: number = 0; index < this.positions.length; index++) {
      if (this.positions[index].mediaId === mediaId) {
        found = index;
        break;
      }
    }
    if (found >= 0) {
      this.positions.splice(found, 1);
    }
    this.positions.push(new VideoPlaybackPosition(mediaId, Math.max(0, seconds)));
    while (this.positions.length > MAX_POSITION_RECORDS) {
      this.positions.shift();
    }
  }

  positionFor(mediaId: string): number {
    for (let index: number = 0; index < this.positions.length; index++) {
      if (this.positions[index].mediaId === mediaId) {
        return this.positions[index].seconds;
      }
    }
    return 0;
  }

  clear(mediaId: string): void {
    for (let index: number = this.positions.length - 1; index >= 0; index--) {
      if (this.positions[index].mediaId === mediaId) {
        this.positions.splice(index, 1);
      }
    }
  }
}

export const videoPlaybackPositionStore: VideoPlaybackPositionStore = new VideoPlaybackPositionStore();
