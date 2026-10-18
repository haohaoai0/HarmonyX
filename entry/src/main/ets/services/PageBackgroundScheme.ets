import { common } from '@kit.AbilityKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor } from '@kit.ArkData';
import util from '@ohos.util';
import { PageBackgroundState, normalizePageBackground, pageBackgroundStore } from './PageBackgroundStore';

export const PAGE_SCHEME_MAX_BYTES: number = 48 * 1024 * 1024;
export const PAGE_SCHEME_MAX_PHOTO_BYTES: number = 32 * 1024 * 1024;

export class PageBackgroundScheme {
  format: string = 'harmonyx.page-background';
  version: number = 1;
  state: PageBackgroundState = new PageBackgroundState();
  photo: string = '';
}

function portableState(value: PageBackgroundState): PageBackgroundState {
  const state: PageBackgroundState = normalizePageBackground(value);
  state.path = ''; state.photoTonePath = '';
  state.photoAverage = '#808080'; state.photoDarkest = '#000000'; state.photoLightest = '#FFFFFF'; state.photoAlpha = 1;
  state.appearanceRevision = 0;
  return state;
}

// A versioned, self-contained document. No device paths or external image
// references are trusted or carried between installations.
export function encodePageBackgroundScheme(value: PageBackgroundState, photo: string): string {
  const scheme: PageBackgroundScheme = new PageBackgroundScheme();
  scheme.state = portableState(value);
  scheme.photo = scheme.state.mode === 'photo' ? photo : '';
  if (scheme.state.mode === 'photo' && photo.length === 0) { throw new Error('scheme_photo_missing'); }
  return JSON.stringify(scheme);
}

export function decodePageBackgroundScheme(raw: string): PageBackgroundScheme {
  if (raw.length === 0 || raw.length > PAGE_SCHEME_MAX_BYTES) { throw new Error('scheme_size'); }
  const parsed: PageBackgroundScheme = JSON.parse(raw) as PageBackgroundScheme;
  if (parsed === null || typeof parsed !== 'object' || parsed.format !== 'harmonyx.page-background' || parsed.version !== 1 ||
    parsed.state === null || typeof parsed.state !== 'object' || Array.isArray(parsed.state)) { throw new Error('scheme_format'); }
  const scheme: PageBackgroundScheme = new PageBackgroundScheme();
  scheme.state = portableState(parsed.state);
  if (scheme.state.mode === 'photo') {
    if (typeof parsed.photo !== 'string' || parsed.photo.length === 0 ||
      parsed.photo.length > Math.ceil(PAGE_SCHEME_MAX_PHOTO_BYTES / 3) * 4 ||
      parsed.photo.length % 4 !== 0 || !/^[A-Za-z0-9+/]*={0,2}$/.test(parsed.photo)) {
      throw new Error('scheme_photo');
    }
    scheme.photo = parsed.photo;
  }
  return scheme;
}

async function readBytes(uri: string, maximum: number): Promise<Uint8Array> {
  const file: fileIo.File = await fileIo.open(uri, fileIo.OpenMode.READ_ONLY);
  try {
    const size: number = fileIo.statSync(file.fd).size;
    if (size <= 0 || size > maximum) { throw new Error('scheme_size'); }
    const buffer: ArrayBuffer = new ArrayBuffer(size);
    const count: number = await fileIo.read(file.fd, buffer);
    if (count !== size) { throw new Error('scheme_read'); }
    return new Uint8Array(buffer);
  } finally { await fileIo.close(file.fd); }
}

async function writeBytes(path: string, bytes: ArrayBuffer | string): Promise<void> {
  const file: fileIo.File = await fileIo.open(path, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
  try {
    const count: number = await fileIo.write(file.fd, bytes);
    // Scheme JSON contains normalized ASCII identifiers and base64, while
    // imported images are binary. Do not share a truncated document.
    const expected: number = typeof bytes === 'string' ? bytes.length : bytes.byteLength;
    if (count !== expected) { throw new Error('scheme_write'); }
  }
  finally { await fileIo.close(file.fd); }
}

export async function importPageBackgroundScheme(context: common.UIAbilityContext, uri: string): Promise<PageBackgroundState> {
  const bytes: Uint8Array = await readBytes(uri, PAGE_SCHEME_MAX_BYTES);
  const scheme: PageBackgroundScheme = decodePageBackgroundScheme(util.TextDecoder.create('utf-8').decodeToString(bytes).replace(/^\uFEFF/, ''));
  if (scheme.state.mode !== 'photo') { return scheme.state; }
  const photo: Uint8Array = new util.Base64Helper().decodeSync(scheme.photo, util.Type.BASIC);
  if (photo.byteLength === 0 || photo.byteLength > PAGE_SCHEME_MAX_PHOTO_BYTES) { throw new Error('scheme_photo_size'); }
  const temporary: string = context.cacheDir + '/page-scheme-import-' + util.generateRandomUUID() + '.img';
  let imported: string = '';
  try {
    await writeBytes(temporary, photo.buffer as ArrayBuffer);
    imported = await pageBackgroundStore.importPhoto(context, fileUri.getUriFromPath(temporary));
    scheme.state.path = imported;
    return await pageBackgroundStore.withPhotoTone(scheme.state);
  } catch (error) {
    if (imported.length > 0) { pageBackgroundStore.removePhoto(context, imported); }
    throw error as Error;
  } finally { try { fileIo.unlinkSync(temporary); } catch (error) {} }
}

export async function sharePageBackgroundScheme(context: common.UIAbilityContext, value: PageBackgroundState, title: string): Promise<void> {
  const state: PageBackgroundState = normalizePageBackground(value);
  let photo: string = '';
  if (state.mode === 'photo') {
    photo = new util.Base64Helper().encodeToStringSync(await readBytes(state.path, PAGE_SCHEME_MAX_PHOTO_BYTES), util.Type.BASIC);
  }
  const directory: string = context.cacheDir + '/page-background-schemes';
  if (!fileIo.accessSync(directory)) { fileIo.mkdirSync(directory); }
  // Retain recent shared files after opening the share sheet: receiving apps
  // can read the URI later. Expired exports are removed on a subsequent share.
  for (const name of fileIo.listFileSync(directory)) {
    if (!/^HarmonyX-background-\d+\.hxb$/.test(name)) { continue; }
    const timestamp: number = Number(name.substring(20, name.length - 4));
    if (Date.now() - timestamp > 7 * 24 * 60 * 60 * 1000) {
      try { fileIo.unlinkSync(directory + '/' + name); } catch (error) {}
    }
  }
  const path: string = directory + '/HarmonyX-background-' + Date.now().toString() + '.hxb';
  await writeBytes(path, encodePageBackgroundScheme(state, photo));
  const data: systemShare.SharedData = new systemShare.SharedData({
    utd: uniformTypeDescriptor.UniformDataType.FILE, uri: fileUri.getUriFromPath(path), title: title
  });
  await new systemShare.ShareController(data).show(context, { selectionMode: systemShare.SelectionMode.SINGLE,
    previewMode: systemShare.SharePreviewMode.DEFAULT });
}
