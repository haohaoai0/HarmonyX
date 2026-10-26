import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { proxyImageResolver } from './ProxyImageResolver';
import { videoPosterStore } from './VideoPosterStore';

const ARTWORK_MAX_EDGE: number = 512;

export class VideoMediaArtworkLease {
  pixelMap: image.PixelMap;
  private owned: boolean;

  constructor(pixelMap: image.PixelMap, owned: boolean) {
    this.pixelMap = pixelMap;
    this.owned = owned;
  }

  release(): void {
    if (!this.owned) { return; }
    this.owned = false;
    this.pixelMap.release().catch((): void => {});
  }
}

class VideoMediaArtwork {
  async load(context: common.Context, id: string, cover: string,
    videoUrl: string): Promise<VideoMediaArtworkLease | null> {
    // The system media center cannot use the app's configured image proxy.
    // Give it decoded pixels, independent of the visible cover's lifetime.
    let pixels: image.PixelMap | null = null;
    try {
      pixels = await proxyImageResolver.loadForViewer(cover, true);
      if (pixels !== null) {
        const info: image.ImageInfo = await pixels.getImageInfo();
        const edge: number = Math.max(info.size.width, info.size.height);
        if (edge > ARTWORK_MAX_EDGE) {
          const factor: number = ARTWORK_MAX_EDGE / edge;
          await pixels.scale(factor, factor);
        }
        return new VideoMediaArtworkLease(pixels, true);
      }
    } catch (error) {
      if (pixels !== null) { pixels.release().catch((): void => {}); }
    }
    if (videoUrl.length === 0) { return null; }
    // Search results and local clips may have no poster URL. Reuse the
    // existing frame extractor/cache, whose PixelMaps stay owned by the store.
    const poster: image.PixelMap | null = await videoPosterStore.load(id, videoUrl,
      context as common.UIAbilityContext);
    return poster === null ? null : new VideoMediaArtworkLease(poster, false);
  }
}

export const videoMediaArtwork: VideoMediaArtwork = new VideoMediaArtwork();
