import { common } from '@kit.AbilityKit';
import { systemShare } from '@kit.ShareKit';
import fs from '@ohos.file.fs';
import util from '@ohos.util';
import utd from '@ohos.data.uniformTypeDescriptor';

export const STORAGE_KEY_EXTERNAL_SHARE: string = 'harmonyx.external_share_request';

export class ExternalShareFile {
  uri: string = '';
  filename: string = '';
  type: number = 1;
}

export class ExternalSharePayload {
  id: string = '';
  text: string = '';
  files: ExternalShareFile[] = [];
}

// ShareExtensionAbility may run in another process. Only a random manifest ID
// crosses the Want; copy temporary granted URIs before closing that session.
export class ExternalShareStore {
  validId(id: string): boolean { return /^[a-f0-9]{32}$/.test(id); }

  private directory(context: common.Context, id: string): string {
    return context.getApplicationContext().filesDir + '/share-inbox/' + id;
  }

  mediaType(typeId: string): number {
    try {
      const descriptor: utd.TypeDescriptor = utd.getTypeDescriptor(typeId);
      if (descriptor.belongsTo(utd.UniformDataType.VIDEO)) { return 3; }
      if (descriptor.belongsTo(utd.UniformDataType.GIF)) { return 2; }
      if (descriptor.belongsTo(utd.UniformDataType.IMAGE)) { return 1; }
    } catch (error) { }
    return 0;
  }

  canPost(payload: ExternalSharePayload): boolean {
    const videos: number = payload.files.filter((file: ExternalShareFile): boolean => file.type === 3).length;
    const gifs: number = payload.files.filter((file: ExternalShareFile): boolean => file.type === 2).length;
    return videos > 0 ? videos === 1 && payload.files.length === 1 : payload.files.length <= 4 && gifs <= 1;
  }

  async stage(context: common.Context, records: systemShare.SharedRecord[]): Promise<ExternalSharePayload> {
    const payload: ExternalSharePayload = new ExternalSharePayload();
    payload.id = util.generateRandomUUID().replace(/-/g, '').toLowerCase();
    const directory: string = this.directory(context, payload.id);
    fs.mkdirSync(directory, true);
    try {
      for (let i: number = 0; i < records.length; i++) {
        const record: systemShare.SharedRecord = records[i];
        if ((record.content ?? '').length > 0) {
          payload.text += (payload.text.length > 0 ? '\n' : '') + record.content;
        }
        if ((record.uri ?? '').length === 0) { continue; }
        const type: number = this.mediaType(record.utd);
        if (type === 0 || payload.files.length >= 10) { throw new Error('Unsupported shared media'); }
        const file: ExternalShareFile = new ExternalShareFile();
        file.type = type;
        const sourceUri: string = record.uri ?? '';
        let filename: string = decodeURIComponent(sourceUri.split('?')[0].split('/').pop() ?? '');
        filename = filename.replace(/[\\/:*?"<>|\x00-\x1f]/g, '_');
        if (filename.length === 0 || filename === '.' || filename === '..') { filename = 'shared'; }
        if (filename.indexOf('.') < 0) { filename += type === 3 ? '.mp4' : type === 2 ? '.gif' : '.jpg'; }
        file.filename = filename;
        const fileDirectory: string = directory + '/' + payload.files.length.toString();
        fs.mkdirSync(fileDirectory);
        file.uri = fileDirectory + '/' + filename;
        const source: fs.File = await fs.open(sourceUri, fs.OpenMode.READ_ONLY);
        try { await fs.copyFile(source.fd, file.uri); }
        finally { fs.closeSync(source); }
        payload.files.push(file);
      }
      const manifest: fs.File = fs.openSync(directory + '/payload.json', fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
      try { fs.writeSync(manifest.fd, JSON.stringify(payload)); }
      finally { fs.closeSync(manifest); }
      return payload;
    } catch (error) {
      this.discard(context, payload.id);
      throw new Error('Unable to stage shared content');
    }
  }

  read(context: common.Context, id: string): ExternalSharePayload | null {
    if (!this.validId(id)) { return null; }
    try {
      const directory: string = this.directory(context, id);
      const payload: ExternalSharePayload = JSON.parse(fs.readTextSync(directory + '/payload.json')) as ExternalSharePayload;
      if (payload.id !== id || payload.files.length > 10) { return null; }
      for (let i: number = 0; i < payload.files.length; i++) {
        const file: ExternalShareFile = payload.files[i];
        if (!file.uri.startsWith(directory + '/') || file.uri.indexOf('/../') >= 0 ||
          file.type < 1 || file.type > 3 || !fs.accessSync(file.uri)) { return null; }
      }
      return payload;
    } catch (error) { return null; }
  }

  discard(context: common.Context, id: string): void {
    if (!this.validId(id)) { return; }
    try { fs.rmdirSync(this.directory(context, id)); } catch (error) { }
  }
}

export const externalShareStore: ExternalShareStore = new ExternalShareStore();
