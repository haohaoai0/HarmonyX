// Media downloads use the persistent task manager, then ask the system to copy
// completed files into Gallery with user-scoped authorization.
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import hilog from '@ohos.hilog';
import { downloadLocationStore, LocalFileSaveResult } from './DownloadLocationStore';
import { gifTranscoder } from './GifTranscoder';
import {
  DownloadTask,
  DownloadTaskReadyCallback,
  DownloadTaskStatus,
  downloadManager
} from './DownloadManager';

const DOMAIN: number = 0xFF00;
const TAG: string = 'HarmonyX-Download';

export const MEDIA_DOWNLOAD_SUCCESS: number = 0;
export const MEDIA_DOWNLOAD_FAILED: number = 1;
export const MEDIA_DOWNLOAD_CANCELED: number = 2;
// Only the animated-GIF path reports this: the GIF could not be produced, so the
// MP4 rendition was saved instead.
export const MEDIA_DOWNLOAD_SAVED_AS_VIDEO: number = 3;

export type MediaDownloadCallback = (result: number) => void;

class DownloadedMediaFile {
  taskId: string = '';
  sourcePath: string = '';
  title: string = '';
  extension: string = '';

  constructor(taskId: string, sourcePath: string, title: string, extension: string) {
    this.taskId = taskId;
    this.sourcePath = sourcePath;
    this.title = title;
    this.extension = extension;
  }
}

class DownloadImageBatch {
  total: number = 0;
  finished: number = 0;
  failed: boolean = false;
  finalized: boolean = false;
  files: DownloadedMediaFile[] = [];
  callback: MediaDownloadCallback;

  constructor(total: number, callback: MediaDownloadCallback) {
    this.total = total;
    this.callback = callback;
  }
}

export class MediaDownloadService {
  private savingTasks: Set<string> = new Set<string>();

  // Only call directly from a successful native SaveButton click. Create and
  // open the Gallery destination before downloading: the temporary grant is
  // consumed immediately, while writing to the open file has no time limit.
  async downloadPhotoWithSaveButton(context: common.UIAbilityContext, url: string,
    mediaId: string, callback: MediaDownloadCallback): Promise<void> {
    if (downloadLocationStore.useDownloads(context)) {
      this.download(context, url, mediaId, false, callback);
      return;
    }
    if (url.length === 0) { callback(MEDIA_DOWNLOAD_FAILED); return; }
    let destination: fileIo.File | null = null;
    let task: DownloadTask | null = null;
    let result: number = MEDIA_DOWNLOAD_FAILED;
    try {
      const helper: photoAccessHelper.PhotoAccessHelper = photoAccessHelper.getPhotoAccessHelper(context);
      const uri: string = await helper.createAsset(photoAccessHelper.PhotoType.IMAGE,
        this.photoExtension(url));
      destination = await fileIo.open(uri, fileIo.OpenMode.WRITE_ONLY);
      let sourcePath: string = url;
      if (!url.startsWith('file://')) {
        task = await this.photoDownloadForSave(context, url, mediaId);
        if (task === null) { throw new Error('photo_download_failed'); }
        sourcePath = task.filePath;
      }
      const source: fileIo.File = await fileIo.open(sourcePath, fileIo.OpenMode.READ_ONLY);
      try {
        await fileIo.copyFile(source.fd, destination.fd);
      } finally {
        fileIo.closeSync(source.fd);
      }
      // Close before completing the task so Gallery sees a committed image.
      fileIo.closeSync(destination.fd);
      destination = null;
      if (task !== null) { downloadManager.saveCompleted(task.id, context); }
      result = MEDIA_DOWNLOAD_SUCCESS;
    } catch (error) {
      if (task !== null) { downloadManager.leaveReadyToSave(task.id, context); }
      const failure: BusinessError = error as BusinessError;
      hilog.warn(DOMAIN, TAG, 'Photo save failed code=%{public}d', failure.code ?? 0);
    } finally {
      if (destination !== null) { fileIo.closeSync(destination.fd); }
      if (task !== null) { this.savingTasks.delete(task.id); }
    }
    callback(result);
  }

  private photoDownloadForSave(context: common.UIAbilityContext, url: string,
    mediaId: string): Promise<DownloadTask | null> {
    return new Promise<DownloadTask | null>((resolve: (task: DownloadTask | null) => void): void => {
      const taskId: string = downloadManager.enqueue(context, url, mediaId, false,
        (id: string, ready: boolean): void => {
          const task: DownloadTask | null = ready ? downloadManager.getTask(id, context) : null;
          if (task === null || task.status !== DownloadTaskStatus.READY_TO_SAVE || this.savingTasks.has(id)) {
            resolve(null);
            return;
          }
          this.savingTasks.add(id);
          resolve(task);
        });
      if (taskId.length === 0) { resolve(null); }
    });
  }

  private photoExtension(url: string): string {
    const lower: string = url.toLowerCase();
    if (lower.indexOf('format=png') >= 0 || lower.indexOf('.png') >= 0) { return 'png'; }
    if (lower.indexOf('format=webp') >= 0 || lower.indexOf('.webp') >= 0) { return 'webp'; }
    if (lower.indexOf('format=gif') >= 0 || lower.indexOf('.gif') >= 0) { return 'gif'; }
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) { return 'heic'; }
    return 'jpg';
  }

  download(context: common.UIAbilityContext, url: string, mediaId: string,
    isVideo: boolean, callback: MediaDownloadCallback): void {
    if (downloadLocationStore.useDownloads(context)) {
      downloadLocationStore.prepare(context).then((ready: boolean): void => {
        if (ready) { this.startDownload(context, url, mediaId, isVideo, callback); }
        else { callback(MEDIA_DOWNLOAD_CANCELED); }
      }).catch((): void => { callback(MEDIA_DOWNLOAD_FAILED); });
      return;
    }
    this.startDownload(context, url, mediaId, isVideo, callback);
  }

  private startDownload(context: common.UIAbilityContext, url: string, mediaId: string,
    isVideo: boolean, callback: MediaDownloadCallback): void {
    if (url.length === 0) {
      callback(MEDIA_DOWNLOAD_FAILED);
      return;
    }
    if (url.startsWith('file://')) {
      this.copyToDestination(context, url, mediaId, isVideo ? 'mp4' : this.localImageExtension(url), isVideo)
        .then(callback).catch((): void => { callback(MEDIA_DOWNLOAD_FAILED); });
      return;
    }
    const onReady: DownloadTaskReadyCallback = (taskId: string, ready: boolean): void => {
      if (!ready) {
        callback(MEDIA_DOWNLOAD_FAILED);
        return;
      }
      this.saveTask(context, taskId, callback);
    };
    const taskId: string = downloadManager.enqueue(context, url, mediaId, isVideo, onReady);
    if (taskId.length === 0) {
      callback(MEDIA_DOWNLOAD_FAILED);
    }
  }

  // An animated GIF is fetched as the MP4 rendition X publishes, then re-encoded
  // into a real GIF file so the saved item is an animation, not a video.
  downloadAnimatedGif(context: common.UIAbilityContext, url: string, mediaId: string,
    durationMs: number, sourceWidth: number, sourceHeight: number,
    callback: MediaDownloadCallback): void {
    if (downloadLocationStore.useDownloads(context)) {
      downloadLocationStore.prepare(context).then((ready: boolean): void => {
        if (ready) {
          this.startAnimatedGifDownload(context, url, mediaId, durationMs, sourceWidth, sourceHeight, callback);
        } else { callback(MEDIA_DOWNLOAD_CANCELED); }
      }).catch((): void => { callback(MEDIA_DOWNLOAD_FAILED); });
      return;
    }
    this.startAnimatedGifDownload(context, url, mediaId, durationMs, sourceWidth, sourceHeight, callback);
  }

  private startAnimatedGifDownload(context: common.UIAbilityContext, url: string, mediaId: string,
    durationMs: number, sourceWidth: number, sourceHeight: number,
    callback: MediaDownloadCallback): void {
    if (url.length === 0) {
      callback(MEDIA_DOWNLOAD_FAILED);
      return;
    }
    if (url.startsWith('file://')) {
      const localPath: string = new fileUri.FileUri(url).path;
      this.encodeAnimatedGif(context, localPath, mediaId, durationMs, sourceWidth, sourceHeight, callback);
      return;
    }
    const onReady: DownloadTaskReadyCallback = (taskId: string, ready: boolean): void => {
      if (!ready) {
        callback(MEDIA_DOWNLOAD_FAILED);
        return;
      }
      const task: DownloadTask | null = downloadManager.getTask(taskId, context);
      if (task === null || task.status !== DownloadTaskStatus.READY_TO_SAVE || this.savingTasks.has(taskId)) {
        callback(MEDIA_DOWNLOAD_FAILED);
        return;
      }
      this.savingTasks.add(taskId);
      this.encodeAnimatedGif(context, task.filePath, task.title, durationMs, sourceWidth, sourceHeight,
        (result: number): void => {
          this.savingTasks.delete(taskId);
          if (result === MEDIA_DOWNLOAD_SUCCESS) {
            downloadManager.saveCompleted(taskId, context);
          } else {
            downloadManager.leaveReadyToSave(taskId, context);
          }
          callback(result);
        }, task);
    };
    const taskId: string = downloadManager.enqueue(context, url, mediaId, false, onReady);
    if (taskId.length === 0) {
      callback(MEDIA_DOWNLOAD_FAILED);
    }
  }

  // Falling back to the MP4 keeps a failed encode from leaving the reader with
  // nothing, and says so through MEDIA_DOWNLOAD_SAVED_AS_VIDEO.
  private encodeAnimatedGif(context: common.UIAbilityContext, sourcePath: string, title: string,
    durationMs: number, sourceWidth: number, sourceHeight: number, callback: MediaDownloadCallback,
    task: DownloadTask | null = null): void {
    const extension: string = task === null ? 'mp4' : task.extension;
    const cacheName: string = Date.now().toString();
    gifTranscoder.transcode(context, sourcePath, cacheName, durationMs, sourceWidth, sourceHeight)
      .then(async (gifPath: string): Promise<void> => {
        let result: number = MEDIA_DOWNLOAD_FAILED;
        try {
          result = await this.copyToDestination(context, gifPath, title, 'gif', false);
        } finally {
          await fileIo.unlink(gifPath).catch((): void => {});
        }
        callback(result);
      })
      .catch(async (error: BusinessError): Promise<void> => {
        hilog.warn(DOMAIN, TAG, 'GIF encode failed code=%{public}d', error.code);
        const fallback: number = await this.copyToDestination(context, sourcePath, title, extension, true)
          .catch((): number => MEDIA_DOWNLOAD_FAILED);
        callback(fallback === MEDIA_DOWNLOAD_SUCCESS ? MEDIA_DOWNLOAD_SAVED_AS_VIDEO : fallback);
      });
  }

  saveTask(context: common.UIAbilityContext, taskId: string, callback: MediaDownloadCallback,
    forceDownloads: boolean = false): void {
    if (this.savingTasks.has(taskId)) { callback(MEDIA_DOWNLOAD_FAILED); return; }
    const task: DownloadTask | null = downloadManager.getTask(taskId, context);
    if (task === null || task.status !== DownloadTaskStatus.READY_TO_SAVE) {
      callback(MEDIA_DOWNLOAD_FAILED);
      return;
    }
    try {
      if (!fileIo.accessSync(task.filePath)) {
        downloadManager.leaveReadyToSave(taskId, context);
        callback(MEDIA_DOWNLOAD_FAILED);
        return;
      }
    } catch (error) {
      downloadManager.leaveReadyToSave(taskId, context);
      callback(MEDIA_DOWNLOAD_FAILED);
      return;
    }
    this.savingTasks.add(taskId);
    const operation: Promise<number> = forceDownloads ?
      downloadLocationStore.save(context, task.filePath, task.title + '.' + task.extension) :
      this.copyToDestination(context, task.filePath, task.title, task.extension, task.isVideo);
    operation
      .then((result: number): void => {
        this.savingTasks.delete(taskId);
        if (result === MEDIA_DOWNLOAD_SUCCESS) {
          downloadManager.saveCompleted(taskId, context);
        } else {
          downloadManager.leaveReadyToSave(taskId, context);
        }
        callback(result);
      })
      .catch((error: BusinessError): void => {
        this.savingTasks.delete(taskId);
        downloadManager.leaveReadyToSave(taskId, context);
        hilog.error(DOMAIN, TAG, 'Gallery save failed code=%{public}d', error.code);
        callback(MEDIA_DOWNLOAD_FAILED);
      });
  }

  // Each image gets its own pausable task. Gallery exports use one dialog;
  // file exports ask the system picker for each destination.
  downloadImages(context: common.UIAbilityContext, urls: string[], mediaId: string,
    callback: MediaDownloadCallback): void {
    if (downloadLocationStore.useDownloads(context)) {
      downloadLocationStore.prepare(context).then((ready: boolean): void => {
        if (ready) { this.startImageDownloads(context, urls, mediaId, callback); }
        else { callback(MEDIA_DOWNLOAD_CANCELED); }
      }).catch((): void => { callback(MEDIA_DOWNLOAD_FAILED); });
      return;
    }
    this.startImageDownloads(context, urls, mediaId, callback);
  }

  private startImageDownloads(context: common.UIAbilityContext, urls: string[], mediaId: string,
    callback: MediaDownloadCallback): void {
    if (urls.length === 0) {
      callback(MEDIA_DOWNLOAD_FAILED);
      return;
    }
    for (let index: number = 0; index < urls.length; index++) {
      if (urls[index].length === 0) {
        callback(MEDIA_DOWNLOAD_FAILED);
        return;
      }
    }
    if (urls.every((url: string): boolean => url.startsWith('file://'))) {
      const files: DownloadedMediaFile[] = urls.map((url: string, index: number): DownloadedMediaFile =>
        new DownloadedMediaFile('', url, mediaId + '-' + index.toString(), this.localImageExtension(url)));
      this.copyImagesToDestination(context, files).then(callback)
        .catch((): void => { callback(MEDIA_DOWNLOAD_FAILED); });
      return;
    }
    const batch: DownloadImageBatch = new DownloadImageBatch(urls.length, callback);
    for (let index: number = 0; index < urls.length; index++) {
      const onReady: DownloadTaskReadyCallback = (taskId: string, ready: boolean): void => {
        this.onBatchTaskReady(context, batch, taskId, ready);
      };
      const taskId: string = downloadManager.enqueue(context, urls[index], mediaId, false, onReady);
      if (taskId.length === 0) {
        batch.failed = true;
        batch.finished = batch.finished + 1;
      }
    }
    this.finishBatchIfReady(context, batch);
  }

  private localImageExtension(url: string): string {
    const lower: string = url.toLowerCase();
    if (lower.endsWith('.gif')) { return 'gif'; }
    if (lower.endsWith('.png')) { return 'png'; }
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) { return 'heic'; }
    if (lower.endsWith('.webp')) { return 'webp'; }
    return 'jpg';
  }

  private onBatchTaskReady(context: common.UIAbilityContext, batch: DownloadImageBatch,
    taskId: string, ready: boolean): void {
    if (ready) {
      const task: DownloadTask | null = downloadManager.getTask(taskId, context);
      if (task !== null && task.status === DownloadTaskStatus.READY_TO_SAVE) {
        batch.files.push(new DownloadedMediaFile(task.id, task.filePath, task.title, task.extension));
      } else {
        batch.failed = true;
      }
    } else {
      batch.failed = true;
    }
    batch.finished = batch.finished + 1;
    this.finishBatchIfReady(context, batch);
  }

  private finishBatchIfReady(context: common.UIAbilityContext, batch: DownloadImageBatch): void {
    if (batch.finished < batch.total || batch.finalized) {
      return;
    }
    batch.finalized = true;
    if (batch.files.length === 0) {
      batch.callback(MEDIA_DOWNLOAD_FAILED);
      return;
    }
    if (batch.files.some((file: DownloadedMediaFile): boolean => this.savingTasks.has(file.taskId))) {
      batch.callback(MEDIA_DOWNLOAD_FAILED); return;
    }
    batch.files.forEach((file: DownloadedMediaFile): void => { this.savingTasks.add(file.taskId); });
    this.copyImagesToDestination(context, batch.files)
      .then((result: number): void => {
        batch.files.forEach((file: DownloadedMediaFile): void => { this.savingTasks.delete(file.taskId); });
        if (result === MEDIA_DOWNLOAD_SUCCESS) {
          for (let index: number = 0; index < batch.files.length; index++) {
            downloadManager.saveCompleted(batch.files[index].taskId, context);
          }
        }
        const finalResult: number = batch.failed && result === MEDIA_DOWNLOAD_SUCCESS ?
          MEDIA_DOWNLOAD_FAILED : result;
        batch.callback(finalResult);
      })
      .catch((error: BusinessError): void => {
        batch.files.forEach((file: DownloadedMediaFile): void => { this.savingTasks.delete(file.taskId); });
        hilog.error(DOMAIN, TAG, 'Gallery batch save failed code=%{public}d', error.code);
        batch.callback(MEDIA_DOWNLOAD_FAILED);
      });
  }

  private copyToDestination(context: common.UIAbilityContext, sourcePath: string,
    title: string, extension: string, isVideo: boolean): Promise<number> {
    if (downloadLocationStore.useDownloads(context)) {
      return downloadLocationStore.save(context, sourcePath, 'HarmonyX-' + title + '.' + extension);
    }
    return this.copyToGallery(context, sourcePath, title, extension, isVideo);
  }

  private async copyImagesToDestination(context: common.UIAbilityContext,
    files: DownloadedMediaFile[]): Promise<number> {
    if (!downloadLocationStore.useDownloads(context)) { return this.copyImagesToGallery(context, files); }
    for (let i: number = 0; i < files.length; i++) {
      const file: DownloadedMediaFile = files[i];
      const result: LocalFileSaveResult = await downloadLocationStore.save(context, file.sourcePath,
        'HarmonyX-' + file.title + '.' + file.extension);
      if (result !== LocalFileSaveResult.SAVED) { return MEDIA_DOWNLOAD_CANCELED; }
      // A later failed batch copy must not re-export or lose a file already saved successfully.
      if (file.taskId.length > 0) { downloadManager.saveCompleted(file.taskId, context); }
    }
    return MEDIA_DOWNLOAD_SUCCESS;
  }

  private async copyToGallery(context: common.UIAbilityContext, sourcePath: string,
    title: string, extension: string, isVideo: boolean): Promise<number> {
    const helper: photoAccessHelper.PhotoAccessHelper = photoAccessHelper.getPhotoAccessHelper(context);
    const sources: string[] = [sourcePath];
    const configs: photoAccessHelper.PhotoCreationConfig[] = [{
      title: 'HarmonyX-' + title,
      fileNameExtension: extension,
      photoType: isVideo ? photoAccessHelper.PhotoType.VIDEO : photoAccessHelper.PhotoType.IMAGE,
      subtype: photoAccessHelper.PhotoSubtype.DEFAULT
    }];
    const destinations: string[] = await helper.showAssetsCreationDialog(sources, configs);
    if (destinations.length === 0) {
      return MEDIA_DOWNLOAD_CANCELED;
    }
    const source: fileIo.File = await fileIo.open(sourcePath, fileIo.OpenMode.READ_ONLY);
    let destination: fileIo.File | null = null;
    try {
      destination = await fileIo.open(destinations[0], fileIo.OpenMode.WRITE_ONLY);
      await fileIo.copyFile(source.fd, destination.fd);
    } finally {
      fileIo.closeSync(source.fd);
      if (destination !== null) {
        fileIo.closeSync(destination.fd);
      }
    }
    return MEDIA_DOWNLOAD_SUCCESS;
  }

  private async copyImagesToGallery(context: common.UIAbilityContext,
    files: DownloadedMediaFile[]): Promise<number> {
    const helper: photoAccessHelper.PhotoAccessHelper = photoAccessHelper.getPhotoAccessHelper(context);
    const sources: string[] = [];
    const configs: photoAccessHelper.PhotoCreationConfig[] = [];
    for (let index: number = 0; index < files.length; index++) {
      const file: DownloadedMediaFile = files[index];
      sources.push(file.sourcePath);
      const config: photoAccessHelper.PhotoCreationConfig = {
        title: 'HarmonyX-' + file.title,
        fileNameExtension: file.extension,
        photoType: photoAccessHelper.PhotoType.IMAGE,
        subtype: photoAccessHelper.PhotoSubtype.DEFAULT
      };
      configs.push(config);
    }
    const destinations: string[] = await helper.showAssetsCreationDialog(sources, configs);
    if (destinations.length === 0) {
      return MEDIA_DOWNLOAD_CANCELED;
    }
    if (destinations.length !== files.length) {
      return MEDIA_DOWNLOAD_FAILED;
    }
    for (let index: number = 0; index < files.length; index++) {
      const source: fileIo.File = await fileIo.open(files[index].sourcePath, fileIo.OpenMode.READ_ONLY);
      let destination: fileIo.File | null = null;
      try {
        destination = await fileIo.open(destinations[index], fileIo.OpenMode.WRITE_ONLY);
        await fileIo.copyFile(source.fd, destination.fd);
      } finally {
        fileIo.closeSync(source.fd);
        if (destination !== null) {
          fileIo.closeSync(destination.fd);
        }
      }
    }
    return MEDIA_DOWNLOAD_SUCCESS;
  }
}

export const mediaDownloadService: MediaDownloadService = new MediaDownloadService();
