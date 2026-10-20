import type { MediaAttachment, VideoRendition } from '../models/Tweet';

function mp4Rendition(url: string, bitrate: number = 0, width: number = 0,
  height: number = 0): VideoRendition | null {
  if (!/\.mp4(?:[?#]|$)/i.test(url)) { return null; }
  const size: RegExpMatchArray | null = url.match(/\/(\d+)x(\d+)\//);
  return { url: url, bitrate: bitrate, width: width > 0 ? width : Number(size?.[1] ?? '0'),
    height: height > 0 ? height : Number(size?.[2] ?? '0') };
}

// Save only files advertised by X. Copy the best MP4 bytes without GIF encoding
// or playback-quality downscaling; a native GIF or HLS playlist is never an MP4.
export function gifVideoDownloadUrl(media: MediaAttachment, fallbackUrl: string = ''): string {
  const candidates: VideoRendition[] = [];
  const variants: VideoRendition[] = media.videoVariants ?? [];
  for (let index: number = 0; index < variants.length; index++) {
    const variant: VideoRendition = variants[index];
    const candidate: VideoRendition | null = mp4Rendition(variant.url, variant.bitrate, variant.width, variant.height);
    if (candidate !== null) { candidates.push(candidate); }
  }
  const urls: string[] = [media.mediaUrl, fallbackUrl, ...(media.videoVariantUrls ?? []), media.feedUrl];
  for (let index: number = 0; index < urls.length; index++) {
    const candidate: VideoRendition | null = mp4Rendition(urls[index]);
    if (candidate !== null) { candidates.push(candidate); }
  }
  let best: VideoRendition | null = null;
  for (let index: number = 0; index < candidates.length; index++) {
    const candidate: VideoRendition = candidates[index];
    if (best === null || (candidate.bitrate > 0 && best.bitrate > 0 ? candidate.bitrate > best.bitrate :
      candidate.width * candidate.height > best.width * best.height)) { best = candidate; }
  }
  return best === null ? '' : best.url;
}
