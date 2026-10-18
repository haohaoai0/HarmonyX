import { image } from '@kit.ImageKit';
import type { PageBackgroundState } from './PageBackgroundStore';

const MAX_CACHED_TEXTURES: number = 4;
const MAX_CACHED_BYTES: number = 32 * 1024 * 1024;
export const PAGE_BACKGROUND_TEXTURE_PIXELS: number = 2000000;

// Card opacity and other foreground preferences do not change the background.
export function pageBackgroundTextureStyle(state: PageBackgroundState, appearance: string): string {
  return [state.mode, state.color, state.path, state.texture, state.textureStrength.toString(),
    state.patternLayout, state.patternLayout === 'preset' ? state.patternIds.join(',') : state.motifIds.join(','),
    state.density.toString(), state.patternStrength.toString(), state.blur.toString(), state.dim.toString(),
    state.photoAverage, state.photoDarkest, state.photoLightest, state.photoAlpha.toString(), appearance].join('|');
}

export class PageBackgroundTexture {
  key: string;
  appearance: string;
  pixels: image.PixelMap | undefined = undefined;
  ready: Promise<image.PixelMap | undefined> = Promise.resolve<image.PixelMap | undefined>(undefined);
  users: number = 0;
  bytes: number = 0;
  lastUsed: number = 0;
  retired: boolean = false;

  constructor(key: string, appearance: string) {
    this.key = key;
    this.appearance = appearance;
  }
}

// Cache the composed background, never a page or its UIContext. Visible pages
// own leases so evicting a cached size cannot release an image still in use.
export class PageBackgroundTextureCache {
  private entries: Map<string, PageBackgroundTexture> = new Map<string, PageBackgroundTexture>();
  private appearance: string = '';
  private clock: number = 0;

  private selectAppearance(appearance: string): void {
    if (this.appearance === appearance) { return; }
    this.appearance = appearance;
    this.clear();
  }

  reuse(appearance: string): PageBackgroundTexture | undefined {
    this.selectAppearance(appearance);
    let newest: PageBackgroundTexture | undefined = undefined;
    for (const entry of this.entries.values()) {
      if (entry.pixels !== undefined && (newest === undefined || entry.lastUsed > newest.lastUsed)) {
        newest = entry;
      }
    }
    if (newest !== undefined) { newest.users++; newest.lastUsed = ++this.clock; }
    return newest;
  }

  acquire(key: string, appearance: string, create: () => Promise<image.PixelMap>): PageBackgroundTexture {
    this.selectAppearance(appearance);
    let entry: PageBackgroundTexture | undefined = this.entries.get(key);
    if (entry !== undefined) { entry.users++; entry.lastUsed = ++this.clock; return entry; }
    entry = new PageBackgroundTexture(key, appearance);
    entry.users = 1;
    entry.lastUsed = ++this.clock;
    this.entries.set(key, entry);
    entry.ready = this.compose(entry, create);
    return entry;
  }

  private async compose(entry: PageBackgroundTexture, create: () => Promise<image.PixelMap>): Promise<image.PixelMap | undefined> {
    try {
      const pixels: image.PixelMap = await create();
      entry.pixels = pixels;
      entry.bytes = pixels.getPixelBytesNumber();
      if (entry.retired && entry.users === 0) { this.dispose(entry); return undefined; }
      console.info('[PageBackgroundTexture] composed ' + Math.round(entry.bytes / 1024).toString() + ' KiB');
      this.trim();
      return pixels;
    } catch (error) {
      if (this.entries.get(entry.key) === entry) { this.entries.delete(entry.key); }
      entry.retired = true;
      this.dispose(entry);
      console.warn('[PageBackgroundTexture] composition failed');
      return undefined;
    }
  }

  release(entry: PageBackgroundTexture): void {
    entry.users = Math.max(0, entry.users - 1);
    if (entry.retired && entry.users === 0) { this.dispose(entry); }
    this.trim();
  }

  private dispose(entry: PageBackgroundTexture): void {
    const pixels: image.PixelMap | undefined = entry.pixels;
    entry.pixels = undefined;
    entry.bytes = 0;
    if (pixels !== undefined) {
      try { pixels.release().catch((): void => {}); } catch (error) {}
    }
  }

  private trim(): void {
    let bytes: number = 0;
    const idle: PageBackgroundTexture[] = [];
    for (const entry of this.entries.values()) {
      bytes += entry.bytes;
      if (entry.users === 0 && entry.pixels !== undefined) { idle.push(entry); }
    }
    idle.sort((left: PageBackgroundTexture, right: PageBackgroundTexture): number => left.lastUsed - right.lastUsed);
    for (const entry of idle) {
      if (this.entries.size <= MAX_CACHED_TEXTURES && bytes <= MAX_CACHED_BYTES) { break; }
      bytes -= entry.bytes;
      this.entries.delete(entry.key);
      entry.retired = true;
      this.dispose(entry);
    }
  }

  clear(): void {
    for (const entry of this.entries.values()) {
      entry.retired = true;
      if (entry.users === 0) { this.dispose(entry); }
    }
    this.entries.clear();
  }
}

export const pageBackgroundTextureCache: PageBackgroundTextureCache = new PageBackgroundTextureCache();
