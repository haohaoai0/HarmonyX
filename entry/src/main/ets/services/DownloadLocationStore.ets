import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { fileIo, fileShare, fileUri, picker } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';

const STORE: string = 'harmonyx_download_location';
const DIRECTORY_KEY: string = 'directory_uri';
const SAVE_TO_FOLDER_KEY: string = 'save_to_folder';
const DOWNLOAD_ROOT: string = 'file://docs/storage/Users/currentUser/Download';
// 下载目录使用应用包名，文件管理器的“来源”按包名文件夹识别并显示入口。
const APP_FOLDER: string = 'com.haohaoai0.CroakX';

export enum LocalFileSaveResult { SAVED = 0, CANCELLED = 2 }

export function downloadFileName(name: string): string {
  const sanitized: string = name.replace(/[\\/:*?"<>|\u0000-\u001f]/g, '_').trim();
  return sanitized.length > 0 && sanitized !== '.' && sanitized !== '..' ? sanitized.substring(0, 180) : 'CroakX-file';
}

function policy(uri: string): fileShare.PolicyInfo {
  return { uri: uri, operationMode: fileShare.OperationMode.READ_MODE | fileShare.OperationMode.WRITE_MODE };
}

export class DownloadLocationStore {
  private saveQueue: Promise<void> = Promise.resolve();
  private selecting: boolean = false;

  supportsDirectory(): boolean {
    return canIUse('SystemCapability.FileManagement.UserFileService.FolderSelection') &&
      canIUse('SystemCapability.FileManagement.AppFileService.FolderAuthorization');
  }

  private store(context: common.Context): preferences.Preferences {
    return preferences.getPreferencesSync(context, { name: STORE });
  }

  private remembered(context: common.Context): string {
    return this.store(context).getSync(DIRECTORY_KEY, '') as string;
  }

  useDownloads(context: common.Context): boolean {
    return this.supportsDirectory() && (this.store(context).getSync(SAVE_TO_FOLDER_KEY, false) as boolean);
  }

  async setUseDownloads(context: common.Context, enabled: boolean): Promise<void> {
    const store: preferences.Preferences = this.store(context);
    const previous: boolean = store.getSync(SAVE_TO_FOLDER_KEY, false) as boolean;
    store.putSync(SAVE_TO_FOLDER_KEY, enabled);
    try { await store.flush(); }
    catch (error) { store.putSync(SAVE_TO_FOLDER_KEY, previous); throw error as Error; }
  }

  path(context: common.Context): string {
    const uri: string = this.remembered(context);
    return this.folderPath(uri.length > 0 ? uri : DOWNLOAD_ROOT);
  }

  hasDirectory(context: common.Context): boolean { return this.remembered(context).length > 0; }

  private folderPath(uri: string): string {
    const base: string = new fileUri.FileUri(uri).path.replace(/\/$/, '');
    return base.endsWith('/' + APP_FOLDER) ? base : base + '/' + APP_FOLDER;
  }

  async chooseDirectory(context: common.UIAbilityContext): Promise<boolean> {
    if (!this.supportsDirectory()) { throw new Error('download_folder_unsupported'); }
    if (this.selecting) { return false; }
    this.selecting = true;
    try {
      const options: picker.DocumentSelectOptions = new picker.DocumentSelectOptions();
      options.selectMode = picker.DocumentSelectMode.FOLDER;
      options.maxSelectNumber = 1;
      options.defaultFilePathUri = this.remembered(context) || DOWNLOAD_ROOT;
      const uris: string[] = await new picker.DocumentViewPicker(context).select(options);
      if (uris.length === 0) { return false; }
      const selected: string = uris[0];
      // Some devices ignore FOLDER mode. Never persist a selected file as a directory.
      if (!(await fileIo.stat(selected)).isDirectory()) { throw new Error('download_folder_unsupported'); }
      await fileShare.persistPermission([policy(selected)]);
      await fileShare.activatePermission([policy(selected)]);
      const store: preferences.Preferences = this.store(context);
      const previous: string = this.remembered(context);
      store.putSync(DIRECTORY_KEY, selected);
      try { await store.flush(); }
      catch (error) {
        store.putSync(DIRECTORY_KEY, previous);
        if (previous !== selected) { await fileShare.revokePermission([policy(selected)]).catch((): void => {}); }
        throw error as Error;
      }
      if (previous.length > 0 && previous !== selected) {
        await fileShare.revokePermission([policy(previous)]).catch((): void => {});
      }
      return true;
    } catch (error) {
      if ((error as BusinessError).code === -1) { return false; }
      throw error as Error;
    } finally { this.selecting = false; }
  }

  // Run on the user's tap, before remote transfers can move the app to the background.
  async prepare(context: common.UIAbilityContext): Promise<boolean> {
    if (!this.supportsDirectory()) { return true; }
    const uri: string = this.remembered(context);
    if (uri.length > 0) {
      try {
        await fileShare.activatePermission([policy(uri)]);
        if ((await fileIo.stat(uri)).isDirectory()) { return true; }
      } catch (error) { /* Reauthorize through the foreground picker. */ }
    }
    return this.chooseDirectory(context);
  }

  save(context: common.UIAbilityContext, sourcePath: string, fileName: string): Promise<LocalFileSaveResult> {
    // Serialize copies so two batch exports cannot pick the same available name.
    const operation: Promise<LocalFileSaveResult> = this.saveQueue.then((): Promise<LocalFileSaveResult> =>
      this.copy(context, sourcePath, downloadFileName(fileName)));
    this.saveQueue = operation.then((): void => {}).catch((): void => {});
    return operation;
  }

  private async copy(context: common.UIAbilityContext, sourcePath: string, fileName: string): Promise<LocalFileSaveResult> {
    let destination: string = '';
    let createdInFolder: boolean = false;
    if (this.supportsDirectory()) {
      const uri: string = this.remembered(context);
      if (uri.length === 0) { throw new Error('download_folder_not_authorized'); }
      // An expired grant never results in a silent write to the sandbox.
      await fileShare.activatePermission([policy(uri)]);
      const directory: string = this.folderPath(uri);
      if (!await fileIo.access(directory)) { await fileIo.mkdir(directory); }
      const dot: number = fileName.lastIndexOf('.');
      const stem: string = dot > 0 ? fileName.substring(0, dot) : fileName;
      const extension: string = dot > 0 ? fileName.substring(dot) : '';
      destination = directory + '/' + fileName;
      let suffix: number = 1;
      while (await fileIo.access(destination)) { destination = directory + '/' + stem + ' (' + suffix++ + ')' + extension; }
      createdInFolder = true;
    } else {
      const options: picker.DocumentSaveOptions = new picker.DocumentSaveOptions();
      options.newFileNames = [fileName]; options.defaultFilePathUri = DOWNLOAD_ROOT;
      let uris: string[] = [];
      try { uris = await new picker.DocumentViewPicker(context).save(options); }
      catch (error) { if ((error as BusinessError).code === -1) { return LocalFileSaveResult.CANCELLED; } throw error as Error; }
      if (uris.length === 0) { return LocalFileSaveResult.CANCELLED; }
      destination = uris[0];
    }
    const source: fileIo.File = await fileIo.open(sourcePath, fileIo.OpenMode.READ_ONLY);
    let target: fileIo.File | null = null;
    try {
      target = await fileIo.open(destination, fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      await fileIo.copyFile(source.fd, target.fd);
    } catch (error) {
      // A failed copy is never marked completed; remove only the newly created partial destination.
      if (target !== null && createdInFolder) { await fileIo.unlink(destination).catch((): void => {}); }
      throw error as Error;
    } finally {
      fileIo.closeSync(source.fd);
      if (target !== null) { fileIo.closeSync(target.fd); }
    }
    return LocalFileSaveResult.SAVED;
  }
}

export const downloadLocationStore: DownloadLocationStore = new DownloadLocationStore();
