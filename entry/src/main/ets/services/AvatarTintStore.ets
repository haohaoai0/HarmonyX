// Only decoded 40x40 pixels are retained during extraction; cached results are
// colors, never PixelMaps. Downloads share the existing avatar disk cache.
import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { fileIo } from '@kit.CoreFileKit';
import { AVATAR_TINT_SAMPLE_SIZE, AvatarTintColors, AvatarTintPalette } from '../utils/AvatarTintColors';
import { XUserParser } from './XUserParser';
import { avatarImageStore } from './AvatarImageStore';

const MAX_PALETTES: number = 512;

class AvatarTintStore {
  private palettes: Map<string, AvatarTintPalette> = new Map();
  private pending: Map<string, Promise<AvatarTintPalette | null>> = new Map();

  load(context: common.UIAbilityContext, url: string): Promise<AvatarTintPalette | null> {
    const key: string = XUserParser.highResAvatarUrl(url);
    if (key.length === 0) {
      return Promise.resolve(null);
    }
    const cached: AvatarTintPalette | undefined = this.palettes.get(key);
    if (cached !== undefined) {
      this.palettes.delete(key);
      this.palettes.set(key, cached);
      return Promise.resolve(cached);
    }
    const active: Promise<AvatarTintPalette | null> | undefined = this.pending.get(key);
    if (active !== undefined) {
      return active;
    }
    const request: Promise<AvatarTintPalette | null> = this.extract(context, key)
      .then((palette: AvatarTintPalette | null): AvatarTintPalette | null => {
        if (palette !== null) {
          this.palettes.set(key, palette);
          if (this.palettes.size > MAX_PALETTES) {
            const oldest: string = this.palettes.keys().next().value;
            this.palettes.delete(oldest);
          }
        }
        this.pending.delete(key);
        return palette;
      }).catch((): null => {
        this.pending.delete(key);
        return null;
      });
    this.pending.set(key, request);
    return request;
  }

  private async extract(context: common.UIAbilityContext, url: string): Promise<AvatarTintPalette | null> {
    let file: fileIo.File | null = null;
    let source: image.ImageSource | null = null;
    let pixels: image.PixelMap | null = null;
    try {
      const local: string = await avatarImageStore.load(context, url, true);
      if (!local.startsWith('file://')) {
        return null;
      }
      file = fileIo.openSync(local, fileIo.OpenMode.READ_ONLY);
      source = image.createImageSource(file.fd);
      const options: image.DecodingOptions = {
        editable: false,
        desiredPixelFormat: image.PixelMapFormat.BGRA_8888,
        desiredSize: { width: AVATAR_TINT_SAMPLE_SIZE, height: AVATAR_TINT_SAMPLE_SIZE }
      };
      pixels = await source.createPixelMap(options);
      const buffer: ArrayBuffer = new ArrayBuffer(pixels.getPixelBytesNumber());
      await pixels.readPixelsToBuffer(buffer);
      return AvatarTintColors.fromPixels(new Uint8Array(buffer), url);
    } catch (error) {
      return null;
    } finally {
      if (pixels !== null) { await pixels.release().catch((): void => {}); }
      if (source !== null) { await source.release().catch((): void => {}); }
      if (file !== null) {
        try { fileIo.closeSync(file.fd); } catch (error) { /* Already closed. */ }
      }
    }
  }
}

export const avatarTintStore: AvatarTintStore = new AvatarTintStore();
