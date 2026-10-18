// Post media lives deep inside the page tree, while the full-screen viewer has
// to be pushed on the root navigation stack. The request travels through
// AppStorage as JSON so no page in between has to know about it.
import type { MediaAttachment, Tweet } from '../models/Tweet';
import type { MediaViewerSource } from './MediaViewerMotion';

export const STORAGE_KEY_PHOTO_REQUEST: string = 'harmonyx.photo_request';
export const STORAGE_KEY_PHOTO_RETURN: string = 'harmonyx.photo_return';

export class PhotoViewerPhoto {
  previewUrl: string = '';
  originalUrl: string = '';
  width: number = 0;
  height: number = 0;
  sourceIndex: number = 0;
  altText: string = '';
  sourceId: string = '';
  animation: MediaAttachment | null = null;

  constructor(previewUrl: string, originalUrl: string, width: number, height: number,
    sourceIndex: number, altText: string, sourceId: string = '', animation: MediaAttachment | null = null) {
    this.previewUrl = previewUrl;
    this.originalUrl = originalUrl;
    this.width = width;
    this.height = height;
    this.sourceIndex = sourceIndex;
    this.altText = altText;
    this.sourceId = sourceId;
    this.animation = animation;
    const lower: string = originalUrl.toLowerCase();
    if (animation === null && (lower.split('?')[0].split('#')[0].endsWith('.gif') || lower.indexOf('format=gif') >= 0)) {
      this.animation = { id: sourceId.length > 0 ? sourceId : 'gif-' + sourceIndex.toString(),
        type: 'animated_gif', mediaUrl: originalUrl, feedUrl: '', previewUrl: previewUrl,
        width: width, height: height, altText: altText };
    }
  }
}

export class PhotoRequest {
  urls: string[] = [];
  items: PhotoViewerPhoto[] = [];
  index: number = 0;
  alt: string = '';
  transitionPrefix: string = '';
  tweet: Tweet | null = null;
  source?: MediaViewerSource;

  constructor(items: PhotoViewerPhoto[], index: number, alt: string, transitionPrefix: string,
    tweet: Tweet | null = null, source: MediaViewerSource | undefined = undefined) {
    this.items = items;
    for (let i: number = 0; i < items.length; i++) {
      this.urls.push(items[i].previewUrl);
    }
    this.index = index;
    this.alt = alt;
    this.transitionPrefix = transitionPrefix;
    this.tweet = tweet;
    this.source = source;
  }
}

export function requestPhotoViewer(items: PhotoViewerPhoto[], index: number, alt: string,
  transitionPrefix: string = '', tweet: Tweet | null = null,
  source: MediaViewerSource | undefined = undefined): void {
  if (items.length === 0) {
    return;
  }
  const payload: PhotoRequest = new PhotoRequest(items, index, alt, transitionPrefix, tweet, source);
  // The value carries a counter so asking for the same photo twice still
  // notifies the watcher.
  AppStorage.setOrCreate<string>(STORAGE_KEY_PHOTO_REQUEST,
    Date.now().toString() + '|' + JSON.stringify(payload));
}
