import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import util from '@ohos.util';

export const STORAGE_KEY_SIDEBAR_HANDLE_STYLE: string = 'harmonyx.sidebar_handle_style';
export const STORAGE_KEY_SIDEBAR_HANDLE_PATH: string = 'harmonyx.sidebar_handle_path';
export const SIDEBAR_HANDLE_DEFAULT: string = 'bold';
export const SIDEBAR_HANDLE_CUSTOM: string = 'custom';

export interface SidebarHandlePreset { id: string; title: Resource; }
export function sidebarHandlePresets(): SidebarHandlePreset[] {
  return [
    { id: 'bold', title: $r('app.string.sidebar_handle_bold') },
    { id: 'eyes', title: $r('app.string.sidebar_handle_eyes') },
    { id: 'panda', title: $r('app.string.sidebar_handle_panda') },
    { id: 'cat', title: $r('app.string.sidebar_handle_cat') },
    { id: 'wave', title: $r('app.string.sidebar_handle_wave') }
  ];
}
export function validSidebarHandleStyle(style: string): boolean {
  return style === 'bold' || style === 'eyes' || style === 'panda' || style === 'cat' || style === 'wave' ||
    style === SIDEBAR_HANDLE_CUSTOM;
}
export function validSidebarHandleImage(width: number, height: number, bytes: number, mime: string): boolean {
  return width === height && (width === 128 || width === 256) && bytes > 0 && bytes <= 5 * 1024 * 1024 &&
    (mime === 'image/png' || mime === 'image/jpeg' || mime === 'image/gif' || mime === 'image/webp');
}
export class SidebarHandleState {
  style: string = SIDEBAR_HANDLE_DEFAULT;
  path: string = '';
}
export class SidebarHandleStore {
  private owns(context: common.Context, path: string): boolean {
    return path.startsWith(context.filesDir + '/sidebar-handles/') && path.indexOf('/../') < 0;
  }

  load(context: common.Context): SidebarHandleState {
    const state: SidebarHandleState = new SidebarHandleState();
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: 'harmonyx_layout' });
      const style: string = store.getSync('rail_handle_style', SIDEBAR_HANDLE_DEFAULT) as string;
      const path: string = store.getSync('rail_handle_path', '') as string;
      state.path = this.owns(context, path) && fileIo.accessSync(path) ? path : '';
      state.style = validSidebarHandleStyle(style) && (style !== SIDEBAR_HANDLE_CUSTOM || state.path.length > 0) ?
        style : SIDEBAR_HANDLE_DEFAULT;
    } catch (error) {}
    return state;
  }

  select(context: common.Context, style: string): boolean {
    const current: SidebarHandleState = this.load(context);
    if (!validSidebarHandleStyle(style) || (style === SIDEBAR_HANDLE_CUSTOM && current.path.length === 0)) { return false; }
    current.style = style;
    return this.save(context, current);
  }

  private save(context: common.Context, state: SidebarHandleState): boolean {
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: 'harmonyx_layout' });
      store.putSync('rail_handle_style', state.style);
      store.putSync('rail_handle_path', state.path);
      store.flushSync();
      AppStorage.setOrCreate<string>(STORAGE_KEY_SIDEBAR_HANDLE_PATH, state.path);
      AppStorage.setOrCreate<string>(STORAGE_KEY_SIDEBAR_HANDLE_STYLE, state.style);
      return true;
    } catch (error) { return false; }
  }

  async importImage(context: common.Context, uri: string): Promise<void> {
    const directory: string = context.filesDir + '/sidebar-handles';
    if (!fileIo.accessSync(directory)) { fileIo.mkdirSync(directory); }
    const destination: string = directory + '/' + util.generateRandomUUID() + '.img';
    let source: fileIo.File | null = null;
    let decoder: image.ImageSource | null = null;
    let committed: boolean = false;
    try {
      source = await fileIo.open(uri, fileIo.OpenMode.READ_ONLY);
      const bytes: number = fileIo.statSync(source.fd).size;
      if (bytes <= 0 || bytes > 5 * 1024 * 1024) { throw new Error('sidebar_image_spec'); }
      await fileIo.copyFile(source.fd, destination);
      decoder = image.createImageSource(destination);
      const info: image.ImageInfo = await decoder.getImageInfo();
      if (!validSidebarHandleImage(info.size.width, info.size.height, bytes, info.mimeType)) {
        throw new Error('sidebar_image_spec');
      }
      const previous: SidebarHandleState = this.load(context);
      const next: SidebarHandleState = new SidebarHandleState();
      next.style = SIDEBAR_HANDLE_CUSTOM;
      next.path = destination;
      if (!this.save(context, next)) { throw new Error('sidebar_image_save'); }
      committed = true;
      this.remove(context, previous.path);
    } finally {
      if (decoder !== null) { try { await decoder.release(); } catch (error) {} }
      if (source !== null) { try { await fileIo.close(source.fd); } catch (error) {} }
      if (!committed) { this.remove(context, destination); }
    }
  }

  remove(context: common.Context, path: string): void {
    if (!this.owns(context, path)) { return; }
    try { fileIo.unlinkSync(path); } catch (error) {}
  }
}
export const sidebarHandleStore: SidebarHandleStore = new SidebarHandleStore();
