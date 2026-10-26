import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { cloudSync, fileIo, fileUri } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { huaweiAccountService } from './HuaweiAccountService';
import { CLOUD_GROUP_ALL, CLOUD_SETTING_FIELDS, CloudSettingsRepository, CloudSettingsPayload,
  CloudSettingRecord, parseCloudSettings, mergeCloudSettings, preferLocalCloudChanges } from './CloudSettingsRepository';

export const CLOUD_SYNC_ENABLED: string = 'harmonyx.cloud.enabled';
export const CLOUD_SYNC_MASK: string = 'harmonyx.cloud.mask';
export const CLOUD_SYNC_STATUS: string = 'harmonyx.cloud.status';
export const CLOUD_SYNC_LAST: string = 'harmonyx.cloud.last';
export const CLOUD_SYNC_ERROR: string = 'harmonyx.cloud.error';

class PreferenceObserver {
  store: preferences.Preferences;
  callback: (key: string) => void;
  constructor(store: preferences.Preferences, callback: (key: string) => void) {
    this.store = store; this.callback = callback;
  }
}

export class HuaweiCloudSyncService {
  private context: common.UIAbilityContext | null = null;
  private owner: string = '';
  private device: string = '';
  private enabled: boolean = false;
  private mask: number = CLOUD_GROUP_ALL;
  private records: CloudSettingRecord[] = [];
  private timer: number = -1;
  private poll: number = -1;
  private running: boolean = false;
  private pendingChanges: boolean = false;
  private pendingIds: string[] = [];
  private applyingRemote: boolean = false;
  private confirmationPending: boolean = false;
  private operationMode: string = 'merge';
  private generation: number = 0;
  private fileSync: cloudSync.FileSync | null = null;
  private pendingTransfer: ((success: boolean) => void) | null = null;
  private cancelDownload: (() => void) | null = null;
  private observers: PreferenceObserver[] = [];
  private lastAttempt: number = 0;
  private accountListener: () => void = (): void => this.accountChanged();
  private progressListener: ((progress: cloudSync.SyncProgress) => void) | null = null;

  initialize(context: common.UIAbilityContext): void {
    if (this.context !== null) { return; }
    this.context = context;
    const store: preferences.Preferences = this.store();
    this.device = store.getSync('device', '') as string;
    if (!/^[a-zA-Z0-9-]{1,64}$/.test(this.device)) {
      this.device = util.generateRandomUUID(); store.putSync('device', this.device); store.flushSync();
    }
    huaweiAccountService.addListener(this.accountListener);
    const names: string[] = [];
    for (const field of CLOUD_SETTING_FIELDS) {
      if (names.indexOf(field.store) >= 0) { continue; }
      names.push(field.store);
      const prefs: preferences.Preferences = preferences.getPreferencesSync(context, { name: field.store });
      const callback: (key: string) => void = (key: string): void => this.changed();
      prefs.on('change', callback);
      this.observers.push(new PreferenceObserver(prefs, callback));
    }
    this.accountChanged();
  }

  private store(): preferences.Preferences {
    if (this.context === null) { throw new Error('Cloud sync context unavailable'); }
    return preferences.getPreferencesSync(this.context, { name: 'harmonyx_cloud_sync' });
  }

  private accountChanged(): void {
    const owner: string = huaweiAccountService.owner();
    if (owner === this.owner) { return; }
    this.cancel();
    this.owner = owner;
    this.records = [];
    this.pendingIds = []; this.pendingChanges = false;
    this.enabled = false;
    this.mask = CLOUD_GROUP_ALL;
    AppStorage.setOrCreate<number>(CLOUD_SYNC_LAST, 0);
    if (owner.length === 0) { this.publish('signed_out'); return; }
    try {
      const store: preferences.Preferences = this.store();
      const previous: string = store.getSync('last_owner', '') as string;
      this.mask = this.validMask(store.getSync('mask_' + owner, CLOUD_GROUP_ALL) as number);
      if (previous.length > 0 && previous !== owner) { this.publish('account_changed'); return; }
      this.enabled = store.getSync('enabled_' + owner, false) === true;
      const raw: string = store.getSync('records_' + owner, '') as string;
      if (raw.length > 0) { this.records = parseCloudSettings(raw, owner).records; }
      const pending: string[] = JSON.parse(store.getSync('pending_' + owner, '[]') as string) as string[];
      if (Array.isArray(pending)) {
        this.pendingIds = pending.filter((id: string): boolean => typeof id === 'string' &&
          CLOUD_SETTING_FIELDS.some((field): boolean => field.id() === id));
      }
      this.pendingChanges = this.pendingIds.length > 0;
      AppStorage.setOrCreate<number>(CLOUD_SYNC_LAST, store.getSync('last_' + owner, 0) as number);
      this.publish(this.enabled ? 'pending' : 'disabled');
      if (this.enabled) { this.schedule(); }
    } catch (error) { this.enabled = false; this.publish('failed'); }
  }

  private validMask(mask: number): number {
    return Number.isInteger(mask) && mask > 0 && mask <= CLOUD_GROUP_ALL ? mask : CLOUD_GROUP_ALL;
  }

  setGroups(mask: number): void {
    this.mask = this.validMask(mask);
    if (this.owner.length > 0) {
      const store: preferences.Preferences = this.store();
      store.putSync('mask_' + this.owner, this.mask); store.flushSync();
    }
    AppStorage.setOrCreate<number>(CLOUD_SYNC_MASK, this.mask);
    if (this.enabled) { this.changed(); this.schedule(); }
  }

  setEnabled(enabled: boolean): void {
    if (!huaweiAccountService.isSignedIn() || this.owner.length === 0) { return; }
    const store: preferences.Preferences = this.store();
    store.putSync('enabled_' + this.owner, enabled);
    if (enabled) { store.putSync('last_owner', this.owner); }
    store.flushSync();
    this.enabled = enabled;
    this.cancel();
    this.publish(enabled ? 'pending' : 'disabled');
    if (enabled) { this.changed(); this.schedule(0); }
  }

  private captureLocal(repository: CloudSettingsRepository): void {
    const next: CloudSettingRecord[] = repository.capture(this.records, this.device, this.mask);
    for (const record of next) {
      const previous: CloudSettingRecord | undefined = this.records.find((item: CloudSettingRecord): boolean => item.id === record.id);
      if (record.revision > 0 && (previous === undefined || previous.value !== record.value) &&
        this.pendingIds.indexOf(record.id) < 0) { this.pendingIds.push(record.id); }
    }
    this.records = next;
    this.pendingChanges = this.pendingIds.length > 0;
  }

  private changed(): void {
    if (this.applyingRemote || !this.enabled || this.context === null || !this.current()) { return; }
    try {
      const previous: string = JSON.stringify(this.records);
      this.captureLocal(new CloudSettingsRepository(this.context));
      if (JSON.stringify(this.records) === previous) { return; }
      this.persist();
      if (!this.running) { this.publish('pending'); }
      this.schedule();
    } catch (error) { this.publish('failed'); }
  }

  private current(): boolean { return huaweiAccountService.owner() === this.owner && this.owner.length > 0; }
  private publish(status: string): void {
    AppStorage.setOrCreate<boolean>(CLOUD_SYNC_ENABLED, this.enabled);
    AppStorage.setOrCreate<number>(CLOUD_SYNC_MASK, this.mask);
    AppStorage.setOrCreate<string>(CLOUD_SYNC_STATUS, status);
  }

  private persist(): void {
    const payload: CloudSettingsPayload = new CloudSettingsPayload();
    payload.owner = this.owner; payload.records = this.records;
    const store: preferences.Preferences = this.store();
    store.putSync('records_' + this.owner, JSON.stringify(payload));
    store.putSync('pending_' + this.owner, JSON.stringify(this.pendingIds)); store.flushSync();
  }

  setConfirmationPending(pending: boolean): void {
    this.confirmationPending = pending;
    if (this.timer >= 0) { clearTimeout(this.timer); this.timer = -1; }
    if (!pending && this.enabled) { this.schedule(); }
  }

  private schedule(delay: number = 5000): void {
    if (this.confirmationPending) { return; }
    if (this.timer >= 0) { clearTimeout(this.timer); }
    this.timer = setTimeout((): void => { this.timer = -1; this.sync(); }, delay);
  }

  async overwriteCloud(): Promise<void> { await this.sync('overwrite'); }
  async clearCloud(): Promise<void> { await this.sync('clear'); }

  async sync(mode: string = 'merge'): Promise<void> {
    if (this.confirmationPending || this.running || (!this.enabled && mode === 'merge') || this.context === null || !this.current()) { return; }
    const elapsed: number = Date.now() - this.lastAttempt;
    if (elapsed < 15000 && mode === 'merge') { this.publish('pending'); this.schedule(15000 - elapsed); return; }
    this.lastAttempt = Date.now();
    this.operationMode = mode;
    this.running = true;
    const generation: number = this.generation;
    const context: common.UIAbilityContext = this.context;
    const owner: string = this.owner;
    try {
      if (!(await huaweiAccountService.revalidate()) || !this.active(generation)) { return; }
      if (!context.cloudFileDir) { this.publish('unavailable'); return; }
      this.captureLocal(new CloudSettingsRepository(context)); this.persist();
      this.publish('downloading');
      AppStorage.setOrCreate<number>(CLOUD_SYNC_ERROR, 0);
      const engine: cloudSync.FileSync = new cloudSync.FileSync();
      this.fileSync = engine;
      this.progressListener = (progress: cloudSync.SyncProgress): void => {
        if (!this.active(generation) || this.fileSync !== engine) { return; }
        if (progress.state === cloudSync.SyncState.COMPLETED) { this.pendingTransfer?.(true); }
        else if (progress.state === cloudSync.SyncState.UPLOAD_FAILED || progress.state === cloudSync.SyncState.DOWNLOAD_FAILED ||
          progress.state === cloudSync.SyncState.STOPPED) {
          AppStorage.setOrCreate<number>(CLOUD_SYNC_ERROR, progress.error);
          this.pendingTransfer?.(false);
        }
      };
      engine.on('progress', this.progressListener);
      // Complete a cloud round trip before deciding a directory is empty.
      if (!(await this.transfer()) || !this.active(generation)) { throw new Error('Cloud download incomplete'); }
      const directory: string = context.cloudFileDir + '/settings-v1-' + encodeURIComponent(owner);
      let names: string[] = [];
      try { names = await fileIo.listFile(directory); }
      catch (error) {
        if ((error as BusinessError).code !== 13900002) { throw error as Error; }
        fileIo.mkdirSync(directory);
      }
      if (!this.active(generation)) { return; }
      if (mode === 'clear') {
        for (const name of names) {
          if (!/^device-[a-zA-Z0-9-]+\.json$/.test(name)) { continue; }
          if (!this.active(generation)) { return; }
          await fileIo.unlink(directory + '/' + name);
        }
        this.publish('uploading');
        if (!(await this.transfer()) || !this.active(generation)) { throw new Error('Cloud deletion incomplete'); }
        this.records = []; this.pendingIds = []; this.pendingChanges = false; this.persist();
        this.store().putSync('last_' + owner, 0); this.store().flushSync();
        AppStorage.setOrCreate<number>(CLOUD_SYNC_LAST, 0);
        this.setEnabled(false); this.publish('cleared');
        return;
      }
      const repository: CloudSettingsRepository = new CloudSettingsRepository(context);
      this.captureLocal(repository);
      let merged: CloudSettingRecord[] = this.records.slice();
      for (const name of names) {
        if (!/^device-[a-zA-Z0-9-]+\.json$/.test(name)) { continue; }
        const path: string = directory + '/' + name;
        if (fileIo.statSync(path).size > 2000000) { throw new Error('Cloud file too large'); }
        // Opening a cloud-only placeholder without downloading it must not be treated as empty data.
        if (fileIo.statSync(path).location === 2) { await this.download(path); }
        const raw: string = await fileIo.readText(path);
        const payload: CloudSettingsPayload = parseCloudSettings(raw, owner);
        merged = mergeCloudSettings(merged, payload.records, this.mask);
        if (!this.active(generation)) { return; }
      }
      if (!this.active(generation)) { return; }
      // Capture edits made during download before applying remote values.
      this.captureLocal(repository);
      this.records = preferLocalCloudChanges(this.records, merged, this.pendingIds, this.device, this.mask, mode === 'overwrite');
      this.applyingRemote = true;
      try { repository.apply(this.records, this.mask); } finally { this.applyingRemote = false; }
      this.persist();
      const payload: CloudSettingsPayload = new CloudSettingsPayload();
      payload.owner = owner;
      // Retain previously synced values for deselected groups. Never capture new local values for them.
      payload.records = this.records.filter((item: CloudSettingRecord): boolean =>
        CLOUD_SETTING_FIELDS.some((field): boolean => field.id() === item.id));
      if (!this.active(generation)) { return; }
      const path: string = directory + '/device-' + this.device + '.json';
      const file: fileIo.File = fileIo.openSync(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
      try { fileIo.writeSync(file.fd, JSON.stringify(payload)); fileIo.fsyncSync(file.fd); }
      finally { fileIo.closeSync(file); }
      this.pendingChanges = false;
      this.publish('uploading');
      if (!(await this.transfer()) || !this.active(generation)) { throw new Error('Cloud upload incomplete'); }
      const fileState: cloudSync.FileState = cloudSync.getCoreFileSyncState(fileUri.getUriFromPath(path));
      if (fileState !== cloudSync.FileState.UPLOAD_SUCCESS && fileState !== cloudSync.FileState.INITIAL_AFTER_DOWNLOAD) {
        throw new Error('Cloud file upload not confirmed');
      }
      // An edit during upload belongs to the next round, even if its field was
      // also present in the snapshot just uploaded.
      this.pendingIds = this.pendingIds.filter((id: string): boolean => {
        const sent: CloudSettingRecord | undefined = payload.records.find((item: CloudSettingRecord): boolean => item.id === id);
        const current: CloudSettingRecord | undefined = this.records.find((item: CloudSettingRecord): boolean => item.id === id);
        return sent === undefined || current === undefined || sent.revision !== current.revision || sent.value !== current.value;
      });
      this.pendingChanges = this.pendingIds.length > 0; this.persist();
      const last: number = Date.now();
      const store: preferences.Preferences = this.store(); store.putSync('last_' + owner, last); store.flushSync();
      AppStorage.setOrCreate<number>(CLOUD_SYNC_LAST, last);
      this.publish(this.pendingChanges ? 'pending' : 'synced');
    } catch (error) {
      if (this.active(generation)) {
        if (mode === 'clear') { this.setEnabled(false); this.publish('failed'); }
        else { this.publish('failed'); this.schedule(60000); }
      }
    } finally {
      if (generation === this.generation) {
        this.releaseEngine(); this.running = false; this.operationMode = 'merge';
        if (this.pendingChanges && this.enabled) { this.schedule(15000); }
      }
    }
  }

  private active(generation: number): boolean { return generation === this.generation && (this.enabled || this.operationMode !== 'merge') && this.current(); }

  private transfer(): Promise<boolean> {
    return new Promise<boolean>((resolve): void => {
      let settled: boolean = false;
      const timer: number = setTimeout((): void => {
        finish(false);
      }, 30000);
      const finish: (success: boolean) => void = (success: boolean): void => {
        if (settled) { return; }
        settled = true; clearTimeout(timer);
        if (this.pendingTransfer === finish) { this.pendingTransfer = null; }
        resolve(success);
      };
      this.pendingTransfer = finish;
      if (this.fileSync === null) { finish(false); return; }
      try { this.fileSync.start().catch((): void => finish(false)); }
      catch (error) { finish(false); }
    });
  }

  private download(path: string): Promise<void> {
    const cache: cloudSync.CloudFileCache = new cloudSync.CloudFileCache();
    const uri: string = fileUri.getUriFromPath(path);
    return new Promise<void>((resolve, reject): void => {
      let settled: boolean = false;
      const finish: (success: boolean) => void = (success: boolean): void => {
        if (settled) { return; }
        settled = true; clearTimeout(timer); this.cancelDownload = null;
        try { cache.off('progress', progress); } catch (error) { /* Already removed. */ }
        if (success) { resolve(); } else {
          cache.stop(uri).catch((): void => {}); reject(new Error('Cloud file unavailable'));
        }
      };
      const progress: (value: cloudSync.DownloadProgress) => void = (value: cloudSync.DownloadProgress): void => {
        if (value.state === cloudSync.State.COMPLETED) { finish(true); }
        else if (value.state === cloudSync.State.FAILED || value.state === cloudSync.State.STOPPED) { finish(false); }
      };
      const timer: number = setTimeout((): void => finish(false), 30000);
      this.cancelDownload = (): void => finish(false);
      try { cache.on('progress', progress); cache.start(uri).catch((): void => finish(false)); }
      catch (error) { finish(false); }
    });
  }

  private releaseEngine(): void {
    if (this.fileSync !== null) {
      try { if (this.progressListener !== null) { this.fileSync.off('progress', this.progressListener); } }
      catch (error) { /* Already released. */ }
      try { this.fileSync.stop().catch((): void => {}); } catch (error) { /* System service unavailable. */ }
      this.fileSync = null;
    }
    this.progressListener = null;
  }

  private cancel(): void {
    this.generation++;
    this.pendingTransfer?.(false); this.pendingTransfer = null;
    this.cancelDownload?.(); this.cancelDownload = null;
    if (this.timer >= 0) { clearTimeout(this.timer); this.timer = -1; }
    this.releaseEngine(); this.running = false; this.operationMode = 'merge';
  }

  onForeground(): void {
    if (this.enabled) { this.schedule(1000); }
    if (this.poll < 0) { this.poll = setInterval((): void => { if (this.enabled) { this.schedule(0); } }, 120000); }
  }
  onBackground(): void { if (this.poll >= 0) { clearInterval(this.poll); this.poll = -1; } this.changed(); }
  dispose(): void {
    this.cancel();
    if (this.poll >= 0) { clearInterval(this.poll); this.poll = -1; }
    huaweiAccountService.removeListener(this.accountListener);
    for (const observer of this.observers) {
      try { observer.store.off('change', observer.callback); } catch (error) { /* Preferences already released. */ }
    }
    this.observers = []; this.context = null;
  }
}

export const huaweiCloudSyncService: HuaweiCloudSyncService = new HuaweiCloudSyncService();
