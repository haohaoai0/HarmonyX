import type { MediaAttachment, Tweet } from '../models/Tweet';
import type { MediaViewerSource } from './MediaViewerMotion';

export const STORAGE_KEY_VIDEO_REQUEST: string = 'harmonyx.video_request';

export class VideoViewerRequest {
  tweet: Tweet;
  mediaId: string;
  positionSeconds: number;
  source?: MediaViewerSource;

  constructor(tweet: Tweet, mediaId: string, positionSeconds: number,
    source: MediaViewerSource | undefined = undefined) {
    this.tweet = tweet;
    this.mediaId = mediaId;
    this.positionSeconds = positionSeconds;
    this.source = source;
  }
}

export function requestVideoViewer(tweet: Tweet, media: MediaAttachment, positionSeconds: number = 0,
  source: MediaViewerSource | undefined = undefined): void {
  const request: VideoViewerRequest = new VideoViewerRequest(tweet, media.id, positionSeconds, source);
  AppStorage.setOrCreate<string>(STORAGE_KEY_VIDEO_REQUEST,
    Date.now().toString() + '|' + JSON.stringify(request));
}
