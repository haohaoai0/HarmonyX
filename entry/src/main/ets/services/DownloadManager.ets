import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { common, wantAgent, WantAgent } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { fileIo } from '@kit.CoreFileKit';
import { notificationManager } from '@kit.NotificationKit';
import hilog from '@ohos.hilog';
import {
  PROXY_DOWNLOAD_COMPLETE,
  PROXY_DOWNLOAD_FAILED,
  PROXY_DOWNLOAD_STOPPED,
  ProxyDownloadOperation,
  proxyDownloadService
} from './ProxyDownloadService';

const DOMAIN: number = 0xFF00;
const TAG: string = 'HarmonyX-DownloadManager';
const BUNDLE_NAME: string = 'com.haohaoai0.CroakX';
const ABILITY_NAME: string = 'EntryAbility';
const DIRECTORY_NAME: string = 'harmonyx-downloads';
const MANIFEST_NAME: string = 'tasks.txt';
const MAX_TASKS: number = 60;
const PUBLISH_INTERVAL_MS: number = 900;

export enum DownloadTaskStatus {
  QUEUED = 0,
  DOWNLOADING = 1,
  PAUSED = 2,
  READY_TO_SAVE = 3,
  COMPLETED = 4,
  FAILED = 5
}

export class DownloadTask {
  id: string = '';
  url: string = '';
  mediaId: string = '';
  title: string = '';
  extension: string = '';
  filePath: string = '';
  isVideo: boolean = false;
  status: DownloadTaskStatus = DownloadTaskStatus.QUEUED;
  receivedBytes: number = 0;
  totalBytes: number = 0;
  private onReady: DownloadTaskReadyCallback | undefined = undefined;

  constructor(id: string, url: string, mediaId: string, title: string, extension: string,
    filePath: string, isVideo: boolean, onReady: DownloadTaskReadyCallback | undefined = undefined) {
    this.id = id;
    this.url = url;
    this.mediaId = mediaId;
    this.title = title;
    this.extension = extension;
    this.filePath = filePath;
    this.isVideo = isVideo;
    this.onReady = onReady;
  }

  readyCallback(): DownloadTaskReadyCallback | undefined {
    return this.onReady;
  }

  clearReadyCallback(): void {
    this.onReady = undefined;
  }
}

export type DownloadTaskReadyCallback = (taskId: string, ready: boolean) => void;

export class DownloadManager {
  private tasks: DownloadTask[] = [];
  private directory: string = '';
  private manifestPath: string = '';
  private loaded: boolean = false;
  private activeTaskId: string = '';
  private activeOperation: ProxyDownloadOperation | null = null;
  private taskSequence: number = 0;
  private revision: number = 0;
  private lastProgressPersistMs: number = 0;
  private inBackground: boolean = false;
  private requestingBackgroundTask: boolean = false;
  private continuousTaskId: number = -1;
  private notificationId: number = -1;
  private lastNotificationUpdateMs: number = 0;
  private backgroundContext: common.UIAbilityContext | null = null;

  initialize(context: common.UIAbilityContext): void {
    this.ensureLoaded(context);
    this.publishTasks();
    this.startNext();
  }

  getTasks(context: common.UIAbilityContext): DownloadTask[] {
    this.ensureLoaded(context);
    const result: DownloadTask[] = [];
    for (let index: number = this.tasks.length - 1; index >= 0; index--) {
      const task: DownloadTask = this.tasks[index];
      result.push(this.copyTask(task));
    }
    return result;
  }

  enqueue(context: common.UIAbilityContext, url: string, mediaId: string, isVideo: boolean,
    onReady: DownloadTaskReadyCallback): string {
    this.ensureLoaded(context);
    if (url.length === 0) {
      return '';
    }
    const id: string = Date.now().toString() + '-' + this.taskSequence.toString();
    this.taskSequence = this.taskSequence + 1;
    const extension: string = this.extensionFor(url, isVideo);
    const title: string = this.safeName(mediaId) + '-' + id;
    const filePath: string = this.directory + '/' + id + '.' + extension + '.part';
    const task: DownloadTask = new DownloadTask(id, url, mediaId, title, extension, filePath, isVideo, onReady);
    this.tasks.push(task);
    this.trimHistory();
    this.persist();
    this.publishTasks();
    this.startNext();
    return id;
  }

  pause(taskId: string, context: common.UIAbilityContext): void {
    this.ensureLoaded(context);
    const task: DownloadTask | null = this.findTask(taskId);
    if (task === null || (task.status !== DownloadTaskStatus.QUEUED &&
      task.status !== DownloadTaskStatus.DOWNLOADING)) {
      return;
    }
    task.status = DownloadTaskStatus.PAUSED;
    this.persist();
    this.publishTasks();
    if (this.activeTaskId === taskId && this.activeOperation !== null) {
      this.activeOperation.cancel();
    }
    this.releaseBackgroundTaskIfIdle(context);
  }

  resume(taskId: string, context: common.UIAbilityContext): void {
    this.ensureLoaded(context);
    const task: DownloadTask | null = this.findTask(taskId);
    if (task === null || (task.status !== DownloadTaskStatus.PAUSED &&
      task.status !== DownloadTaskStatus.FAILED)) {
      return;
    }
    task.status = DownloadTaskStatus.QUEUED;
    this.updateReceivedFromFile(task);
    this.persist();
    this.publishTasks();
    this.startNext();
  }

  delete(taskId: string, context: common.UIAbilityContext): void {
    this.ensureLoaded(context);
    const index: number = this.indexOfTask(taskId);
    if (index < 0) {
      return;
    }
    const task: DownloadTask = this.tasks[index];
    this.tasks.splice(index, 1);
    const onReady: DownloadTaskReadyCallback | undefined = task.readyCallback();
    task.clearReadyCallback();
    if (onReady !== undefined) {
      onReady(taskId, false);
    }
    if (this.activeTaskId === taskId && this.activeOperation !== null) {
      this.activeOperation.cancel();
    } else {
      this.removeFile(task.filePath);
    }
    this.persist();
    this.publishTasks();
    this.startNext();
  }

  saveCompleted(taskId: string, context: common.UIAbilityContext): void {
    this.ensureLoaded(context);
    const task: DownloadTask | null = this.findTask(taskId);
    if (task === null) {
      return;
    }
    task.status = DownloadTaskStatus.COMPLETED;
    task.clearReadyCallback();
    this.removeFile(task.filePath);
    this.persist();
    this.publishTasks();
  }

  leaveReadyToSave(taskId: string, context: common.UIAbilityContext): void {
    this.ensureLoaded(context);
    const task: DownloadTask | null = this.findTask(taskId);
    if (task === null) {
      return;
    }
    task.status = DownloadTaskStatus.READY_TO_SAVE;
    this.persist();
    this.publishTasks();
  }

  getTask(taskId: string, context: common.UIAbilityContext): DownloadTask | null {
    this.ensureLoaded(context);
    const task: DownloadTask | null = this.findTask(taskId);
    return task === null ? null : this.copyTask(task);
  }

  onBackground(context: common.UIAbilityContext): void {
    this.backgroundContext = context;
    this.inBackground = true;
    if (this.hasPendingTransfer()) {
      this.startBackgroundTask(context);
    }
  }

  onForeground(context: common.UIAbilityContext): void {
    this.inBackground = false;
    this.backgroundContext = context;
    this.stopBackgroundTask(context);
  }

  private startNext(): void {
    if (this.activeTaskId.length > 0) {
      return;
    }
    let task: DownloadTask | null = null;
    for (let index: number = 0; index < this.tasks.length; index++) {
      if (this.tasks[index].status === DownloadTaskStatus.QUEUED) {
        task = this.tasks[index];
        break;
      }
    }
    if (task === null) {
      this.releaseBackgroundTaskIfIdle(this.backgroundContext);
      return;
    }
    this.startTask(task);
  }

  private startTask(task: DownloadTask): void {
    this.activeTaskId = task.id;
    task.status = DownloadTaskStatus.DOWNLOADING;
    this.updateReceivedFromFile(task);
    this.persist();
    this.publishTasks();
    if (this.inBackground && this.backgroundContext !== null) {
      this.startBackgroundTask(this.backgroundContext);
    }
    const operation: ProxyDownloadOperation = proxyDownloadService.startResumableDownload(task.url,
      task.filePath, task.receivedBytes, (received: number, total: number): void => {
        const current: DownloadTask | null = this.findTask(task.id);
        if (current === null || current.status !== DownloadTaskStatus.DOWNLOADING) {
          return;
        }
        current.receivedBytes = received;
        if (total > 0) {
          current.totalBytes = total;
        }
        const now: number = Date.now();
        if (now - this.lastProgressPersistMs >= 700) {
          this.lastProgressPersistMs = now;
          this.persist();
          this.publishTasks();
        }
        this.updateLiveView(current, false);
      });
    this.activeOperation = operation;
    operation.promise.then((result: number): void => {
      const current: DownloadTask | null = this.findTask(task.id);
      this.activeTaskId = '';
      this.activeOperation = null;
      if (current !== null) {
        this.updateReceivedFromFile(current);
        if (result === PROXY_DOWNLOAD_COMPLETE) {
          current.status = DownloadTaskStatus.READY_TO_SAVE;
          this.persist();
          this.publishTasks();
          const onReady: DownloadTaskReadyCallback | undefined = current.readyCallback();
          current.clearReadyCallback();
          if (onReady !== undefined) {
            onReady(current.id, true);
          }
        } else if (result === PROXY_DOWNLOAD_FAILED) {
          current.status = DownloadTaskStatus.FAILED;
          this.persist();
          this.publishTasks();
          const onReady: DownloadTaskReadyCallback | undefined = current.readyCallback();
          current.clearReadyCallback();
          if (onReady !== undefined) {
            onReady(current.id, false);
          }
        } else {
          this.persist();
          this.publishTasks();
        }
      } else {
        this.removeFile(task.filePath);
      }
      if (this.inBackground && this.hasPendingTransfer() && this.backgroundContext !== null) {
        this.updateLiveView(this.findFirstActiveTask(), true);
      }
      this.startNext();
    });
  }

  private startBackgroundTask(context: common.UIAbilityContext): void {
    if (this.continuousTaskId >= 0 || this.requestingBackgroundTask) {
      return;
    }
    this.requestingBackgroundTask = true;
    const info: wantAgent.WantAgentInfo = {
      wants: [{ bundleName: BUNDLE_NAME, abilityName: ABILITY_NAME }],
      actionType: wantAgent.OperationType.START_ABILITY,
      requestCode: 27,
      actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    };
    wantAgent.getWantAgent(info).then((agent: WantAgent): void => {
      const request: backgroundTaskManager.ContinuousTaskRequest =
        new backgroundTaskManager.ContinuousTaskRequest();
      const modes: backgroundTaskManager.BackgroundTaskMode[] = [
        backgroundTaskManager.BackgroundTaskMode.MODE_DATA_TRANSFER
      ];
      const submodes: backgroundTaskManager.BackgroundTaskSubmode[] = [
        backgroundTaskManager.BackgroundTaskSubmode.SUBMODE_LIVE_VIEW_NOTIFICATION
      ];
      request.backgroundTaskModes = modes;
      request.backgroundTaskSubmodes = submodes;
      request.wantAgent = agent;
      backgroundTaskManager.startBackgroundRunning(context, request).then(
        (result: backgroundTaskManager.ContinuousTaskNotification): void => {
          this.requestingBackgroundTask = false;
          this.continuousTaskId = result.continuousTaskId === undefined ? -1 : result.continuousTaskId;
          this.notificationId = result.notificationId;
          if (!this.inBackground || !this.hasPendingTransfer()) {
            this.stopBackgroundTask(context);
            return;
          }
          this.updateLiveView(this.findFirstActiveTask(), true);
        }).catch((error: BusinessError): void => {
          this.requestingBackgroundTask = false;
          hilog.warn(DOMAIN, TAG, 'background transfer task denied: %{public}d %{public}s',
            error.code, error.message);
        });
    }).catch((error: BusinessError): void => {
      this.requestingBackgroundTask = false;
      hilog.warn(DOMAIN, TAG, 'background transfer agent failed: %{public}d %{public}s',
        error.code, error.message);
    });
  }

  private stopBackgroundTask(context: common.UIAbilityContext | null): void {
    if (context === null || this.continuousTaskId < 0) {
      return;
    }
    const taskId: number = this.continuousTaskId;
    this.continuousTaskId = -1;
    this.notificationId = -1;
    backgroundTaskManager.stopBackgroundRunning(context, taskId).then((): void => {
    }).catch((error: BusinessError): void => {
      hilog.warn(DOMAIN, TAG, 'background transfer task release failed: %{public}d', error.code);
    });
  }

  private releaseBackgroundTaskIfIdle(context: common.UIAbilityContext | null): void {
    if (!this.hasPendingTransfer()) {
      this.stopBackgroundTask(context);
    }
  }

  private hasPendingTransfer(): boolean {
    for (let index: number = 0; index < this.tasks.length; index++) {
      const status: DownloadTaskStatus = this.tasks[index].status;
      if (status === DownloadTaskStatus.QUEUED || status === DownloadTaskStatus.DOWNLOADING) {
        return true;
      }
    }
    return false;
  }

  private findFirstActiveTask(): DownloadTask | null {
    for (let index: number = 0; index < this.tasks.length; index++) {
      const task: DownloadTask = this.tasks[index];
      if (task.status === DownloadTaskStatus.DOWNLOADING || task.status === DownloadTaskStatus.QUEUED) {
        return task;
      }
    }
    return null;
  }

  private updateLiveView(task: DownloadTask | null, force: boolean): void {
    if (task === null || this.notificationId < 0 || !this.inBackground) {
      return;
    }
    const now: number = Date.now();
    if (!force && now - this.lastNotificationUpdateMs < PUBLISH_INTERVAL_MS) {
      return;
    }
    this.lastNotificationUpdateMs = now;
    const percent: number = task.totalBytes > 0 ?
      Math.max(0, Math.min(100, Math.floor(task.receivedBytes * 100 / task.totalBytes))) : 0;
    const title: string = task.title + '.' + task.extension;
    const template: notificationManager.NotificationTemplate = {
      name: 'downloadTemplate',
      data: {
        title: title,
        fileName: title,
        progressValue: percent
      }
    };
    const request: notificationManager.NotificationRequest = {
      content: {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_SYSTEM_LIVE_VIEW,
        systemLiveView: {
          typeCode: 8,
          title: title,
          text: percent.toString() + '%'
        }
      },
      id: this.notificationId,
      notificationSlotType: notificationManager.SlotType.LIVE_VIEW,
      template: template
    };
    notificationManager.publish(request).then((): void => {
    }).catch((error: BusinessError): void => {
      hilog.warn(DOMAIN, TAG, 'download live view update failed: %{public}d', error.code);
    });
  }

  private ensureLoaded(context: common.UIAbilityContext): void {
    const nextDirectory: string = context.filesDir + '/' + DIRECTORY_NAME;
    if (this.loaded && this.directory === nextDirectory) {
      return;
    }
    this.loaded = true;
    this.directory = nextDirectory;
    this.manifestPath = this.directory + '/' + MANIFEST_NAME;
    this.tasks = [];
    this.ensureDirectory();
    try {
      if (!fileIo.accessSync(this.manifestPath)) {
        return;
      }
      const lines: string[] = fileIo.readTextSync(this.manifestPath).split('\n');
      for (let index: number = 0; index < lines.length; index++) {
        const line: string = lines[index];
        if (line.length === 0) {
          continue;
        }
        const fields: string[] = line.split('\t');
        if (fields.length !== 11) {
          continue;
        }
        const id: string = fields[0];
        const statusValue: number = Number(fields[1]);
        const received: number = Number(fields[2]);
        const total: number = Number(fields[3]);
        const isVideo: boolean = fields[4] === '1';
        const url: string = decodeURIComponent(fields[5]);
        const mediaId: string = decodeURIComponent(fields[6]);
        const title: string = decodeURIComponent(fields[7]);
        const extension: string = fields[8];
        const path: string = decodeURIComponent(fields[9]);
        const recordVersion: number = Number(fields[10]);
        if (id.length === 0 || url.length === 0 || recordVersion !== 1 || statusValue < 0 ||
          statusValue > DownloadTaskStatus.FAILED) {
          continue;
        }
        let status: DownloadTaskStatus = statusValue as DownloadTaskStatus;
        if (status === DownloadTaskStatus.DOWNLOADING) {
          status = DownloadTaskStatus.PAUSED;
        }
        const task: DownloadTask = new DownloadTask(id, url, mediaId, title, extension, path, isVideo);
        task.status = status;
        task.receivedBytes = received;
        task.totalBytes = total;
        this.updateReceivedFromFile(task);
        this.tasks.push(task);
      }
    } catch (error) {
      hilog.warn(DOMAIN, TAG, '%{public}s', 'download task manifest could not be restored');
    }
    this.trimHistory();
    this.persist();
  }

  private persist(): void {
    if (!this.loaded || this.manifestPath.length === 0) {
      return;
    }
    let content: string = '';
    for (let index: number = 0; index < this.tasks.length; index++) {
      const task: DownloadTask = this.tasks[index];
      content = content + task.id + '\t' + task.status.toString() + '\t' +
        task.receivedBytes.toString() + '\t' + task.totalBytes.toString() + '\t' +
        (task.isVideo ? '1' : '0') + '\t' + encodeURIComponent(task.url) + '\t' +
        encodeURIComponent(task.mediaId) + '\t' + encodeURIComponent(task.title) + '\t' +
        task.extension + '\t' + encodeURIComponent(task.filePath) + '\t1\n';
    }
    let file: fileIo.File | undefined = undefined;
    try {
      file = fileIo.openSync(this.manifestPath,
        fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(file.fd, content);
    } catch (error) {
      hilog.warn(DOMAIN, TAG, '%{public}s', 'download task manifest write failed');
    } finally {
      if (file !== undefined) {
        try {
          fileIo.closeSync(file.fd);
        } catch (error) {
          // A failed write may already have closed the descriptor.
        }
      }
    }
  }

  private publishTasks(): void {
    this.revision = this.revision + 1;
    AppStorage.setOrCreate<number>('harmonyx.download_revision', this.revision);
  }

  private copyTask(task: DownloadTask): DownloadTask {
    const copy: DownloadTask = new DownloadTask(task.id, task.url, task.mediaId, task.title,
      task.extension, task.filePath, task.isVideo);
    copy.status = task.status;
    copy.receivedBytes = task.receivedBytes;
    copy.totalBytes = task.totalBytes;
    return copy;
  }

  private updateReceivedFromFile(task: DownloadTask): void {
    try {
      if (fileIo.accessSync(task.filePath)) {
        const stat = fileIo.statSync(task.filePath);
        if (stat.isFile() && stat.size >= 0) {
          task.receivedBytes = stat.size;
        }
      } else {
        task.receivedBytes = 0;
      }
    } catch (error) {
      task.receivedBytes = 0;
    }
  }

  private findTask(taskId: string): DownloadTask | null {
    const index: number = this.indexOfTask(taskId);
    return index >= 0 ? this.tasks[index] : null;
  }

  private indexOfTask(taskId: string): number {
    for (let index: number = 0; index < this.tasks.length; index++) {
      if (this.tasks[index].id === taskId) {
        return index;
      }
    }
    return -1;
  }

  private trimHistory(): void {
    while (this.tasks.length > MAX_TASKS) {
      let removableIndex: number = -1;
      for (let index: number = 0; index < this.tasks.length; index++) {
        const status: DownloadTaskStatus = this.tasks[index].status;
        if (status === DownloadTaskStatus.COMPLETED || status === DownloadTaskStatus.FAILED) {
          removableIndex = index;
          break;
        }
      }
      if (removableIndex < 0) {
        break;
      }
      const removed: DownloadTask = this.tasks[removableIndex];
      this.removeFile(removed.filePath);
      this.tasks.splice(removableIndex, 1);
    }
  }

  private ensureDirectory(): void {
    try {
      if (!fileIo.accessSync(this.directory)) {
        fileIo.mkdirSync(this.directory);
      }
    } catch (error) {
      try {
        fileIo.mkdirSync(this.directory);
      } catch (createError) {
        hilog.warn(DOMAIN, TAG, '%{public}s', 'download directory unavailable');
      }
    }
  }

  private removeFile(path: string): void {
    try {
      if (fileIo.accessSync(path)) {
        fileIo.unlinkSync(path);
      }
    } catch (error) {
      // Missing partial files are harmless when a task is removed.
    }
  }

  private extensionFor(url: string, isVideo: boolean): string {
    if (isVideo) {
      return 'mp4';
    }
    const lower: string = url.toLowerCase();
    if (lower.indexOf('format=png') >= 0 || lower.indexOf('.png') >= 0) {
      return 'png';
    }
    if (lower.indexOf('format=webp') >= 0 || lower.indexOf('.webp') >= 0) {
      return 'webp';
    }
    if (lower.indexOf('format=gif') >= 0 || lower.indexOf('.gif') >= 0) {
      return 'gif';
    }
    return 'jpg';
  }

  private safeName(value: string): string {
    let result: string = '';
    for (let index: number = 0; index < value.length; index++) {
      const code: number = value.charCodeAt(index);
      const allowed: boolean = (code >= 48 && code <= 57) || (code >= 65 && code <= 90) ||
        (code >= 97 && code <= 122);
      result = result + (allowed ? value.charAt(index) : '-');
    }
    return result.length > 0 ? result : 'media';
  }
}

export const downloadManager: DownloadManager = new DownloadManager();
