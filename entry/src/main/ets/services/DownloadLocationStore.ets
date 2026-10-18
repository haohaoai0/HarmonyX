import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { fileIo, picker } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';

const STORE: string = 'harmonyx_download_location';
const SAVE_TO_FOLDER_KEY: string = 'save_to_folder';
const DOWNLOAD_ROOT: string = 'file://docs/storage/Users/currentUser/Download';

export enum LocalFileSaveResult { SAVED = 0, CANCELLED = 2 }

export function downloadFileName(name: string): string {
  const sanitized: string = name.replace(/[\\/:*?"<>|\u0000-\u001f]/g, '_').trim();
  return sanitized.length > 0 && sanitized !== '.' && sanitized !== '..' ? sanitized.substring(0, 180) : 'HarmonyX-file';
}

export class DownloadLocationStore {
  private saveQueue: Promise<void> = Promise.resolve();

  private store(context: common.Context): preferences.Preferences {
    return preferences.getPreferencesSync(context, { name: STORE });
  }

  useDownloads(context: common.Context): boolean {
    return this.store(context).getSync(SAVE_TO_FOLDER_KEY, false) as boolean;
  }

  async setUseDownloads(context: common.Context, enabled: boolean): Promise<void> {
    const store: preferences.Preferences = this.store(context);
    const previous: boolean = store.getSync(SAVE_TO_FOLDER_KEY, false) as boolean;
    store.putSync(SAVE_TO_FOLDER_KEY, enabled);
    try { await store.flush(); }
    catch (error) { store.putSync(SAVE_TO_FOLDER_KEY, previous); throw error as Error; }
  }

  save(context: common.UIAbilityContext, sourcePath: string, fileName: string): Promise<LocalFileSaveResult> {
    // Serialize picker dialogs and copies, including multi-image exports.
    const operation: Promise<LocalFileSaveResult> = this.saveQueue.then((): Promise<LocalFileSaveResult> =>
      this.copy(context, sourcePath, downloadFileName(fileName)));
    this.saveQueue = operation.then((): void => {}).catch((): void => {});
    return operation;
  }

  private async copy(context: common.UIAbilityContext, sourcePath: string, fileName: string): Promise<LocalFileSaveResult> {
    const options: picker.DocumentSaveOptions = new picker.DocumentSaveOptions();
    options.newFileNames = [fileName];
    options.defaultFilePathUri = DOWNLOAD_ROOT;
    let uris: string[] = [];
    try { uris = await new picker.DocumentViewPicker(context).save(options); }
    catch (error) {
      if ((error as BusinessError).code === -1) { return LocalFileSaveResult.CANCELLED; }
      throw error as Error;
    }
    if (uris.length === 0) { return LocalFileSaveResult.CANCELLED; }
    const source: fileIo.File = await fileIo.open(sourcePath, fileIo.OpenMode.READ_ONLY);
    let target: fileIo.File | null = null;
    try {
      target = await fileIo.open(uris[0], fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      await fileIo.copyFile(source.fd, target.fd);
    } finally {
      fileIo.closeSync(source.fd);
      if (target !== null) { fileIo.closeSync(target.fd); }
    }
    return LocalFileSaveResult.SAVED;
  }
}

export const downloadLocationStore: DownloadLocationStore = new DownloadLocationStore();
