import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import util from '@ohos.util';
import { ChatBackgroundPreset, chatBackgroundPreset } from './ChatBackgroundStore';
import { validPageMotif } from '../models/PageBackgroundMotifs';
import { backgroundImageStore } from './BackgroundImageStore';
import { PagePhotoTone, samplePagePhoto } from '../utils/PageBackgroundContrast';

export const STORAGE_KEY_PAGE_BACKGROUND: string = 'harmonyx.page_background';
export const DEFAULT_PAGE_SURFACE_OPACITY: number = 0.85;

export class PageBackgroundState {
  enabled: boolean = true;
  mode: string = 'theme';
  color: string = '';
  path: string = '';
  patternId: string = 'none';
  patternIds: string[] = [];
  patternLayout: string = 'icons';
  presetColors: boolean = false;
  motifIds: string[] = [];
  density: number = 50;
  texture: string = 'none';
  textureStrength: number = 0.55;
  patternStrength: number = 0.3;
  blur: number = 0;
  dim: number = 0;
  contentOpacity: number = DEFAULT_PAGE_SURFACE_OPACITY;
  transparentPosts: boolean = false;
  transparentInbox: boolean = false;
  postOpacity: number = DEFAULT_PAGE_SURFACE_OPACITY;
  inboxOpacity: number = DEFAULT_PAGE_SURFACE_OPACITY;
  photoTonePath: string = '';
  photoAverage: string = '#808080';
  photoDarkest: string = '#000000';
  photoLightest: string = '#FFFFFF';
  photoAlpha: number = 1;
  appearanceRevision: number = 0;
}

function bounded(value: number, fallback: number, maximum: number): number {
  return typeof value === 'number' && Number.isFinite(value) ? Math.max(0, Math.min(maximum, value)) : fallback;
}

export function normalizePageBackground(value: PageBackgroundState): PageBackgroundState {
  const state: PageBackgroundState = new PageBackgroundState();
  if (value === null || value === undefined) { return state; }
  state.enabled = value.enabled !== false;
  state.mode = value.mode === 'color' || value.mode === 'photo' ? value.mode : 'theme';
  state.color = typeof value.color === 'string' && /^#[0-9a-fA-F]{6}$/.test(value.color) ? value.color.toUpperCase() : '';
  if (state.mode === 'color' && state.color.length === 0) { state.mode = 'theme'; }
  if (state.mode === 'theme') { state.color = ''; }
  state.path = state.mode === 'photo' && typeof value.path === 'string' ? value.path : '';
  const presetId: string = typeof value.patternId === 'string' ? value.patternId : 'none';
  state.patternId = chatBackgroundPreset(presetId).pattern !== undefined ? presetId : 'none';
  if (Array.isArray(value.patternIds)) {
    for (let i: number = 0; i < Math.min(17, value.patternIds.length) && state.patternIds.length === 0; i++) {
      const id: string = value.patternIds[i];
      if (typeof id === 'string' && chatBackgroundPreset(id).pattern !== undefined && state.patternIds.indexOf(id) < 0) {
        state.patternIds.push(id);
      }
    }
  } else if (state.patternId !== 'none') { state.patternIds = [state.patternId]; }
  state.patternId = state.patternIds.length > 0 ? state.patternIds[0] : 'none';
  state.patternLayout = value.patternLayout === 'preset' ? 'preset' : 'icons';
  state.presetColors = value.presetColors === true;
  if (Array.isArray(value.motifIds)) {
    for (let i: number = 0; i < Math.min(256, value.motifIds.length); i++) {
      const id: string = value.motifIds[i];
      if (typeof id === 'string' && validPageMotif(id) && state.motifIds.indexOf(id) < 0) { state.motifIds.push(id); }
    }
  }
  state.density = bounded(value.density, 50, 100);
  state.texture = value.texture === 'kraft' || value.texture === 'parchment' ? value.texture : 'none';
  state.textureStrength = bounded(value.textureStrength, 0.55, 1);
  state.patternStrength = bounded(value.patternStrength, 0.3, 1);
  state.blur = bounded(value.blur, 0, 30);
  state.dim = bounded(value.dim, 0, 0.6);
  state.contentOpacity = bounded(value.contentOpacity, DEFAULT_PAGE_SURFACE_OPACITY, 1);
  state.transparentPosts = value.transparentPosts === true;
  state.transparentInbox = value.transparentInbox === true;
  state.postOpacity = bounded(value.postOpacity, state.contentOpacity, 1);
  state.inboxOpacity = bounded(value.inboxOpacity, state.contentOpacity, 1);
  state.appearanceRevision = bounded(value.appearanceRevision, 0, 1000000);
  if (typeof value.photoTonePath === 'string' && value.photoTonePath === state.path) {
    state.photoTonePath = value.photoTonePath;
    state.photoAverage = typeof value.photoAverage === 'string' && /^#[0-9a-fA-F]{6}$/.test(value.photoAverage) ? value.photoAverage : '#808080';
    state.photoDarkest = typeof value.photoDarkest === 'string' && /^#[0-9a-fA-F]{6}$/.test(value.photoDarkest) ? value.photoDarkest : '#000000';
    state.photoLightest = typeof value.photoLightest === 'string' && /^#[0-9a-fA-F]{6}$/.test(value.photoLightest) ? value.photoLightest : '#FFFFFF';
    state.photoAlpha = bounded(value.photoAlpha, 1, 1);
  }
  return state;
}

// Full wallpaper presets own their gradient. Keep the user's theme, solid
// color and photo settings so turning this off restores their custom base.
const presetColorCache: Map<string, ResourceColor[]> = new Map<string, ResourceColor[]>();
export function pageBackgroundPresetColors(state: PageBackgroundState): ResourceColor[] {
  if (!state.presetColors || state.patternLayout !== 'preset' || state.patternIds.length === 0) { return []; }
  const id: string = state.patternIds[0];
  const cached: ResourceColor[] | undefined = presetColorCache.get(id);
  if (cached !== undefined) { return cached; }
  const preset: ChatBackgroundPreset = chatBackgroundPreset(id);
  if (preset.pattern === undefined) { return []; }
  // Retain resource references, so resolving them still follows light/dark.
  // Foreground contrast requests must not rebuild the 17-item catalog.
  presetColorCache.set(id, preset.colors);
  return preset.colors;
}

let cachedValue: string = '';
let cachedState: PageBackgroundState = new PageBackgroundState();

// The immutable serialized preference is also the UI dependency. Cache its
// validated representation rather than parsing it for every visible post.
export function pageBackgroundFromValue(value: string): PageBackgroundState {
  if (value !== cachedValue) {
    try { cachedState = normalizePageBackground(JSON.parse(value) as PageBackgroundState); }
    catch (error) { cachedState = new PageBackgroundState(); }
    cachedValue = value;
  }
  return cachedState;
}

export function pageBackgroundActive(value: string): boolean {
  const state: PageBackgroundState = pageBackgroundFromValue(value);
  if (!state.enabled) { return false; }
  return state.mode !== 'theme' || state.dim > 0 || state.texture !== 'none' ||
    (state.patternLayout === 'preset' ? state.patternIds.length > 0 : state.motifIds.length > 0);
}

export class PageBackgroundStore {
  private photoTones: Map<string, Promise<PagePhotoTone>> = new Map();
  private directory(context: common.Context): string { return context.filesDir + '/page_backgrounds'; }

  private owns(context: common.Context, path: string): boolean {
    const prefix: string = this.directory(context) + '/';
    return path.startsWith(prefix) && /^[a-fA-F0-9-]+\.img$/.test(path.substring(prefix.length));
  }

  private validPhoto(context: common.Context, path: string): boolean {
    return (this.owns(context, path) || backgroundImageStore.owns(context, path)) && fileIo.accessSync(path);
  }

  private preferences(context: common.Context): preferences.Preferences {
    return preferences.getPreferencesSync(context, { name: 'harmonyx_page_background' });
  }

  load(context: common.Context): PageBackgroundState {
    try {
      const raw: string = this.preferences(context).getSync('state', '') as string;
      const state: PageBackgroundState = normalizePageBackground(JSON.parse(raw) as PageBackgroundState);
      if (state.mode === 'photo' && !this.validPhoto(context, state.path)) {
        state.mode = 'theme'; state.path = '';
      }
      return state;
    } catch (error) { return new PageBackgroundState(); }
  }

  initialize(context: common.Context): void {
    const state: PageBackgroundState = this.load(context);
    const serialized: string = JSON.stringify(state);
    AppStorage.setOrCreate<string>(STORAGE_KEY_PAGE_BACKGROUND, serialized);
    if (state.mode === 'photo' && state.photoTonePath !== state.path) { this.initializePhotoTone(context, state, serialized); }
  }

  refreshAppearance(): void {
    const value: string = AppStorage.get<string>(STORAGE_KEY_PAGE_BACKGROUND) ?? '';
    if (!pageBackgroundActive(value)) { return; }
    const state: PageBackgroundState = normalizePageBackground(pageBackgroundFromValue(value));
    state.appearanceRevision = (state.appearanceRevision + 1) % 1000001;
    // Recompute resolved resource colors after a system/app theme change.
    // This is a render publication only; the user's saved draft is untouched.
    AppStorage.setOrCreate<string>(STORAGE_KEY_PAGE_BACKGROUND, JSON.stringify(state));
  }

  private async initializePhotoTone(context: common.Context, state: PageBackgroundState, previous: string): Promise<void> {
    const next: PageBackgroundState = await this.withPhotoTone(state);
    const current: string = AppStorage.get<string>(STORAGE_KEY_PAGE_BACKGROUND) ?? '';
    if (current !== previous) {
      const active: PageBackgroundState = pageBackgroundFromValue(current);
      const expected: PageBackgroundState = normalizePageBackground(state);
      expected.appearanceRevision = active.appearanceRevision;
      if (JSON.stringify(expected) !== JSON.stringify(active)) { return; }
      next.appearanceRevision = active.appearanceRevision;
    }
    try { this.save(context, next); } catch (error) {}
  }

  async withPhotoTone(value: PageBackgroundState): Promise<PageBackgroundState> {
    const next: PageBackgroundState = normalizePageBackground(value);
    if (next.mode !== 'photo' || next.path.length === 0 || next.photoTonePath === next.path) { return next; }
    const tone: PagePhotoTone = await this.photoTone(next.path);
    next.photoTonePath = next.path; next.photoAverage = tone.average;
    next.photoDarkest = tone.darkest; next.photoLightest = tone.lightest; next.photoAlpha = tone.alpha;
    return next;
  }

  save(context: common.Context, value: PageBackgroundState): void {
    const state: PageBackgroundState = normalizePageBackground(value);
    if (state.mode === 'photo' && !this.validPhoto(context, state.path)) {
      throw new Error('missing_page_background_image');
    }
    const store: preferences.Preferences = this.preferences(context);
    const previousRaw: string = store.getSync('state', '') as string;
    const previous: PageBackgroundState = this.load(context);
    const serialized: string = JSON.stringify(state);
    try { store.putSync('state', serialized); store.flushSync(); }
    catch (error) {
      try { store.putSync('state', previousRaw); } catch (rollbackError) {}
      throw new Error('page_background_save_failed');
    }
    AppStorage.setOrCreate<string>(STORAGE_KEY_PAGE_BACKGROUND, serialized);
    if (previous.path !== state.path) { this.removePhoto(context, previous.path); }
  }

  async importPhoto(context: common.Context, uri: string): Promise<string> {
    const directory: string = this.directory(context);
    if (!fileIo.accessSync(directory)) { fileIo.mkdirSync(directory); }
    const destination: string = directory + '/' + util.generateRandomUUID() + '.img';
    let source: fileIo.File | null = null;
    let decoder: image.ImageSource | null = null;
    try {
      source = await fileIo.open(uri, fileIo.OpenMode.READ_ONLY);
      await fileIo.copyFile(source.fd, destination);
      decoder = image.createImageSource(destination);
      const info: image.ImageInfo = await decoder.getImageInfo();
      if (info.size.width <= 0 || info.size.height <= 0) { throw new Error('invalid_page_background_image'); }
      return destination;
    } catch (error) {
      this.removePhoto(context, destination);
      throw new Error('page_background_import_failed');
    } finally {
      if (decoder !== null) { try { await decoder.release(); } catch (error) {} }
      if (source !== null) { try { await fileIo.close(source.fd); } catch (error) {} }
    }
  }

  photoTone(path: string): Promise<PagePhotoTone> {
    const cached: Promise<PagePhotoTone> | undefined = this.photoTones.get(path);
    if (cached !== undefined) { return cached; }
    const pending: Promise<PagePhotoTone> = this.decodePhotoTone(path);
    if (this.photoTones.size >= 24) { this.photoTones.clear(); }
    this.photoTones.set(path, pending);
    return pending;
  }

  private async decodePhotoTone(path: string): Promise<PagePhotoTone> {
    let source: image.ImageSource | null = null;
    let pixels: image.PixelMap | null = null;
    try {
      source = image.createImageSource(path);
      pixels = await source.createPixelMap({ desiredSize: { width: 40, height: 40 }, editable: false,
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888 });
      const buffer: ArrayBuffer = new ArrayBuffer(pixels.getPixelBytesNumber());
      await pixels.readPixelsToBuffer(buffer);
      return samplePagePhoto(new Uint8Array(buffer));
    } catch (error) { return new PagePhotoTone(); }
    finally {
      if (pixels !== null) { try { await pixels.release(); } catch (error) {} }
      if (source !== null) { try { await source.release(); } catch (error) {} }
    }
  }

  removePhoto(context: common.Context, path: string): void {
    if (!this.owns(context, path) || this.load(context).path === path) { return; }
    try { if (fileIo.accessSync(path)) { fileIo.unlinkSync(path); } } catch (error) {}
  }
}

export const pageBackgroundStore: PageBackgroundStore = new PageBackgroundStore();
