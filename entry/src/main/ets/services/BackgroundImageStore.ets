import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import util from '@ohos.util';
import { xChatActions } from './XChatActions';
import { xPrivateStore } from './XPrivateStore';
import { proxyDownloadService } from './ProxyDownloadService';

export interface BackgroundImage {
  path: string;
  sourceUrl: string;
}

class BackgroundImageStore {
  private directory(context: common.Context): string { return context.filesDir + '/background_images'; }

  private ownsIn(directory: string, path: string): boolean {
    const prefix: string = directory + '/';
    return path.startsWith(prefix) && /^[a-fA-F0-9-]+\.img$/.test(path.substring(prefix.length));
  }

  owns(context: common.Context, path: string): boolean {
    // Read the original chat-only library in place; migration must not copy it.
    return this.ownsIn(this.directory(context), path) || this.ownsIn(context.filesDir + '/chat_backgrounds_saved', path);
  }

  photos(context: common.Context): BackgroundImage[] {
    const photos: BackgroundImage[] = [];
    try {
      const parsed: BackgroundImage[] = JSON.parse(xChatActions.localString(context, 'background_photos', '[]')) as BackgroundImage[];
      if (!Array.isArray(parsed)) { return photos; }
      for (let i: number = 0; i < parsed.length; i++) {
        const photo: BackgroundImage = parsed[i];
        if (photo === null || typeof photo.path !== 'string' || typeof photo.sourceUrl !== 'string' ||
          !this.owns(context, photo.path) || !fileIo.accessSync(photo.path)) { continue; }
        if (!photos.some((entry: BackgroundImage): boolean => entry.path === photo.path)) {
          photos.push({ path: photo.path, sourceUrl: photo.sourceUrl });
        }
      }
    } catch (error) {}
    return photos;
  }

  removePhoto(context: common.Context, path: string): boolean {
    if (!this.owns(context, path)) { return false; }
    const photos: BackgroundImage[] = this.photos(context);
    if (!photos.some((photo: BackgroundImage): boolean => photo.path === path)) { return false; }
    const previous: string = xChatActions.localString(context, 'background_photos', '[]');
    const remaining: BackgroundImage[] = photos.filter((photo: BackgroundImage): boolean => photo.path !== path);
    try {
      // Commit the list first. A failed write must never remove an image file.
      xChatActions.saveLocal(context, 'background_photos', JSON.stringify(remaining));
      fileIo.unlinkSync(path);
    } catch (error) {
      try { xChatActions.saveLocal(context, 'background_photos', previous); } catch (rollbackError) {}
      throw new Error('background_delete_failed');
    }
    // Page/chat loaders already discard preferences whose image no longer exists.
    return true;
  }

  // Store one durable file. Page and chat preferences both reference this path;
  // neither setting owns or deletes the reusable library image.
  async savePhoto(context: common.Context, url: string): Promise<void> {
    if (url.length === 0) { throw new Error('missing_background_source'); }
    const account: string = xPrivateStore.load(context).cacheIdentity();
    if (this.photos(context).some((photo: BackgroundImage): boolean => photo.sourceUrl === url)) { return; }
    const directory: string = this.directory(context);
    if (!fileIo.accessSync(directory)) { fileIo.mkdirSync(directory); }
    const destination: string = directory + '/' + util.generateRandomUUID() + '.img';
    let source: fileIo.File | null = null;
    let decoder: image.ImageSource | null = null;
    try {
      if (url.startsWith('https://') || url.startsWith('http://')) {
        if (!await proxyDownloadService.downloadWithRetry(url, destination, 2)) { throw new Error('background_download_failed'); }
      } else {
        source = await fileIo.open(url, fileIo.OpenMode.READ_ONLY);
        await fileIo.copyFile(source.fd, destination);
      }
      decoder = image.createImageSource(destination);
      const info: image.ImageInfo = await decoder.getImageInfo();
      if (info.size.width <= 0 || info.size.height <= 0) { throw new Error('invalid_background_image'); }
      if (account !== xPrivateStore.load(context).cacheIdentity()) { throw new Error('background_account_changed'); }
      const photos: BackgroundImage[] = this.photos(context);
      if (photos.some((photo: BackgroundImage): boolean => photo.sourceUrl === url)) {
        fileIo.unlinkSync(destination);
        return;
      }
      photos.unshift({ path: destination, sourceUrl: url });
      xChatActions.saveLocal(context, 'background_photos', JSON.stringify(photos));
    } catch (error) {
      try { fileIo.unlinkSync(destination); } catch (cleanupError) {}
      throw new Error('background_save_failed');
    } finally {
      if (decoder !== null) { try { await decoder.release(); } catch (error) {} }
      if (source !== null) { try { await fileIo.close(source.fd); } catch (error) {} }
    }
  }
}

export const backgroundImageStore: BackgroundImageStore = new BackgroundImageStore();
