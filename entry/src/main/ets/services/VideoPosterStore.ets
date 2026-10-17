// Covers for videos that arrive without one.
//
// X answers a search with the video's renditions but no still image at all, so
// the card had nothing to draw and the old renderer fell back to a black box.
// The cover is therefore taken from the video itself: a key frame is decoded
// once per media id and reused by every cell that shows the same post.
import { media } from '@kit.MediaKit';
import { image } from '@kit.ImageKit';
import hilog from '@ohos.hilog';
import { common } from '@kit.AbilityKit';
import { BusinessError, deviceInfo } from '@kit.BasicServicesKit';
import { fileIo } from '@kit.CoreFileKit';
import type { MediaAttachment, VideoRendition } from '../models/Tweet';
import { videoRangeSource, VideoRangeLease } from './VideoRangeSource';

const DOMAIN = 0xFF00;
const TAG = 'HarmonyX-Poster';
// A hair into the clip: frame zero of an X upload is often a fade-in.
const COVER_TIME_US: number = 120000;
const COVER_WIDTH: number = 480;
const COVER_HEIGHT: number = 270;
// Frames are small but not free; a scrolling session should not keep every
// cover it ever decoded.
const MAX_CACHED: number = 8;
const RETRY_DELAY_MS: number = 1500;
const FRAME_TIMEOUT_MS: number = 6000;

export function videoPosterSource(media: MediaAttachment): string {
  const candidates: string[] = [media.feedUrl, media.mediaUrl];
  const variants: string[] = media.videoVariantUrls ?? [];
  const renditions: VideoRendition[] = media.videoVariants ?? [];
  for (let index: number = 0; index < variants.length; index++) {
    candidates.push(variants[index]);
  }
  for (let index: number = 0; index < renditions.length; index++) {
    candidates.push(renditions[index].url);
  }
  for (let index: number = 0; index < candidates.length; index++) {
    if (candidates[index].split('?')[0].toLowerCase().endsWith('.mp4')) {
      return candidates[index];
    }
  }
  return '';
}

export function videoPosterRendition(media: MediaAttachment, source: string): string {
  const renditions: VideoRendition[] = media.videoVariants ?? [];
  for (let index: number = 0; index < renditions.length; index++) {
    const rendition: VideoRendition = renditions[index];
    if (rendition.url === source) {
      return 'v' + rendition.bitrate.toString() + '-' + rendition.width.toString() + 'x' +
        rendition.height.toString();
    }
  }
  return source === media.feedUrl && source !== media.mediaUrl ? 'feed' : 'full';
}

class VideoPosterStore {
  private cache: Map<string, image.PixelMap> = new Map();
  private order: string[] = [];
  private inflight: Map<string, Promise<image.PixelMap | null>> = new Map();
  private retryAfter: Map<string, number> = new Map();

  cached(id: string): image.PixelMap | null {
    const found: image.PixelMap | undefined = this.cache.get(id);
    return found === undefined ? null : found;
  }

  known(id: string): boolean {
    return this.cache.has(id);
  }

  async load(id: string, url: string, context?: common.UIAbilityContext,
    rendition: string = 'full'): Promise<image.PixelMap | null> {
    const ready: image.PixelMap | null = this.cached(id);
    if (ready !== null) {
      return ready;
    }
    if (url.length === 0) {
      return null;
    }
    const requestKey: string = this.requestKey(id, url);
    const retryAt: number | undefined = this.retryAfter.get(requestKey);
    if (retryAt !== undefined && Date.now() < retryAt) {
      return null;
    }
    const pending: Promise<image.PixelMap | null> | undefined = this.inflight.get(requestKey);
    if (pending !== undefined) {
      return await pending;
    }
    const request: Promise<image.PixelMap | null> = this.fetchFrame(id, url, requestKey, context, rendition);
    this.inflight.set(requestKey, request);
    return await request;
  }

  private async fetchFrame(id: string, url: string, requestKey: string,
    context: common.UIAbilityContext | undefined, rendition: string): Promise<image.PixelMap | null> {
    let extractor: media.AVMetadataExtractor | null = null;
    let lease: VideoRangeLease | null = null;
    let file: fileIo.File | null = null;
    try {
      extractor = await media.createAVMetadataExtractor();
      if (url.startsWith('file://')) {
        file = fileIo.openSync(url, fileIo.OpenMode.READ_ONLY);
        extractor.fdSrc = { fd: file.fd, offset: 0, length: fileIo.statSync(file.fd).size };
      } else if (context !== undefined && url.split('?')[0].toLowerCase().endsWith('.mp4')) {
        lease = await videoRangeSource.open(context, id, rendition, url, false);
        if (lease === null) {
          this.retryAfter.set(requestKey, Date.now() + RETRY_DELAY_MS);
          return null;
        }
        extractor.setUrlSource(lease.url);
      } else {
        extractor.setUrlSource(url);
      }
      const params: media.PixelMapParams = { width: COVER_WIDTH, height: COVER_HEIGHT };
      let frame: image.PixelMap | undefined = undefined;
      if (deviceInfo.apiAvailable('26.0.0')) {
        frame = await extractor.fetchFrameByTimeWithTimeout(COVER_TIME_US,
          media.AVImageQueryOptions.AV_IMAGE_QUERY_CLOSEST, params, FRAME_TIMEOUT_MS);
      } else {
        frame = await extractor.fetchFrameByTime(COVER_TIME_US,
          media.AVImageQueryOptions.AV_IMAGE_QUERY_CLOSEST, params);
      }
      if (frame === undefined) {
        this.retryAfter.set(requestKey, Date.now() + RETRY_DELAY_MS);
        return null;
      }
      this.retryAfter.delete(requestKey);
      this.remember(id, frame);
      hilog.info(DOMAIN, TAG, 'cover ready id=%{public}s', id);
      return frame;
    } catch (err) {
      this.retryAfter.set(requestKey, Date.now() + RETRY_DELAY_MS);
      hilog.warn(DOMAIN, TAG, 'cover unavailable id=%{public}s code=%{public}d', id,
        (err as BusinessError).code);
      return null;
    } finally {
      this.inflight.delete(requestKey);
      if (extractor !== null) {
        await extractor.release().catch((): void => {});
      }
      if (lease !== null) { lease.close(); }
      if (file !== null) { fileIo.closeSync(file.fd); }
    }
  }

  private remember(id: string, frame: image.PixelMap): void {
    this.cache.set(id, frame);
    this.order.push(id);
    while (this.order.length > MAX_CACHED) {
      const oldest: string | undefined = this.order.shift();
      if (oldest !== undefined && oldest !== id) {
        this.cache.delete(oldest);
      }
    }
  }

  private requestKey(id: string, url: string): string {
    return id + '|' + url;
  }
}

export const videoPosterStore: VideoPosterStore = new VideoPosterStore();
