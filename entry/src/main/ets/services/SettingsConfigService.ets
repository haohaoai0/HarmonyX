import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { fileIo, picker } from '@kit.CoreFileKit';
import { CLOUD_GROUP_ALL, CloudSettingRecord, CloudSettingsPayload, CloudSettingsRepository,
  cloudField, parseCloudSettings } from './CloudSettingsRepository';

const PORTABLE_SETTINGS_OWNER: string = 'portable-settings-v1';
const MAX_CONFIG_BYTES: number = 2000000;

export class SettingsConfigService {
  private twoDigits(value: number): string {
    return value < 10 ? '0' + value.toString() : value.toString();
  }

  private fileName(): string {
    const now: Date = new Date();
    return 'harmonyx-settings-' + now.getFullYear().toString() +
      this.twoDigits(now.getMonth() + 1) + this.twoDigits(now.getDate()) + '-' +
      this.twoDigits(now.getHours()) + this.twoDigits(now.getMinutes()) +
      this.twoDigits(now.getSeconds()) + '.json';
  }

  private cancelled(error: Error): boolean {
    return (error.message ?? '').toLowerCase().indexOf('cancel') >= 0;
  }

  async exportSettings(context: common.UIAbilityContext): Promise<boolean> {
    const repository: CloudSettingsRepository = new CloudSettingsRepository(context);
    const records: CloudSettingRecord[] = repository.capture([], 'config-export', CLOUD_GROUP_ALL)
      .filter((record: CloudSettingRecord): boolean => cloudField(record.id) !== undefined);
    const payload: CloudSettingsPayload = new CloudSettingsPayload();
    payload.owner = PORTABLE_SETTINGS_OWNER;
    payload.records = records;
    let uris: string[] = [];
    try {
      const options: picker.DocumentSaveOptions = { newFileNames: [this.fileName()] };
      uris = await new picker.DocumentViewPicker(context).save(options);
    } catch (error) {
      if (this.cancelled(error as Error)) { return false; }
      throw error as Error;
    }
    if (uris.length === 0) { return false; }
    const file: fileIo.File = fileIo.openSync(uris[0],
      fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
    try {
      fileIo.writeSync(file.fd, JSON.stringify(payload));
      fileIo.fsyncSync(file.fd);
    } finally {
      fileIo.closeSync(file.fd);
    }
    return true;
  }

  async selectImportFile(context: common.UIAbilityContext): Promise<CloudSettingRecord[] | null> {
    let uris: string[] = [];
    try {
      const options: picker.DocumentSelectOptions = {
        maxSelectNumber: 1,
        fileSuffixFilters: ['JSON|.json']
      };
      uris = await new picker.DocumentViewPicker(context).select(options);
    } catch (error) {
      if (this.cancelled(error as Error)) { return null; }
      throw error as Error;
    }
    if (uris.length === 0) { return null; }
    const raw: string = this.readText(uris[0]);
    const records: CloudSettingRecord[] = parseCloudSettings(raw, PORTABLE_SETTINGS_OWNER).records
      .filter((record: CloudSettingRecord): boolean => cloudField(record.id) !== undefined);
    if (records.length === 0) { throw new Error('Settings config contains no supported fields'); }
    return records;
  }

  private readText(uri: string): string {
    const file: fileIo.File = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
    try {
      const size: number = fileIo.statSync(file.fd).size;
      if (size <= 0 || size > MAX_CONFIG_BYTES) { throw new Error('Invalid settings config size'); }
      const bytes: ArrayBuffer = new ArrayBuffer(size);
      const count: number = fileIo.readSync(file.fd, bytes);
      if (count !== size) { throw new Error('Incomplete settings config'); }
      return util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(bytes)).replace(/^\uFEFF/, '');
    } finally {
      fileIo.closeSync(file.fd);
    }
  }

  applyImport(context: common.UIAbilityContext, records: CloudSettingRecord[]): void {
    new CloudSettingsRepository(context).apply(records, CLOUD_GROUP_ALL);
  }
}

export const settingsConfigService: SettingsConfigService = new SettingsConfigService();
