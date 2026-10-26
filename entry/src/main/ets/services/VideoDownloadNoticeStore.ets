import { hapticConfirm } from '../utils/Haptics';

export const VIDEO_DOWNLOAD_NOTICE_KEY: string = 'harmonyx.video_download_notice';
const COMPLETION_DURATION_MS: number = 2200;

export class VideoDownloadNoticeState {
  taskId: string = '';
  phase: string = 'hidden';
  receivedBytes: number = 0;
  totalBytes: number = 0;

  constructor(taskId: string = '', phase: string = 'hidden', received: number = 0, total: number = 0) {
    this.taskId = taskId;
    this.phase = phase;
    this.receivedBytes = received;
    this.totalBytes = total;
  }
}

// One application-wide owner: navigation and multiple mounted tabs cannot
// replay completion feedback or create competing dismissal timers.
export class VideoDownloadNoticeStore {
  private transfers: VideoDownloadNoticeState[] = [];
  private localSaves: VideoDownloadNoticeState[] = [];
  private completionTimer: number = -1;

  update(transfers: VideoDownloadNoticeState[]): void {
    this.transfers = transfers;
    if (this.completionTimer < 0) { this.showNext(); }
  }

  savingLocal(taskId: string): void {
    this.localSaves.push(new VideoDownloadNoticeState(taskId, 'saving'));
    if (this.completionTimer < 0) { this.showNext(); }
  }

  finishedLocal(taskId: string, saved: boolean, foreground: boolean): void {
    this.localSaves = this.localSaves.filter((state: VideoDownloadNoticeState): boolean => state.taskId !== taskId);
    if (saved) { this.completed(taskId, foreground); }
    else if (this.completionTimer < 0) { this.showNext(); }
  }

  completed(taskId: string, foreground: boolean): void {
    if (this.completionTimer >= 0) { clearTimeout(this.completionTimer); }
    this.publish(new VideoDownloadNoticeState(taskId, 'completed'));
    if (foreground) { hapticConfirm(); }
    this.completionTimer = setTimeout((): void => {
      this.completionTimer = -1;
      this.showNext();
    }, COMPLETION_DURATION_MS);
  }

  private showNext(): void {
    // Prefer the transfer using the network; queued videos still expose cancel.
    let next: VideoDownloadNoticeState = new VideoDownloadNoticeState();
    for (let index: number = 0; index < this.transfers.length; index++) {
      const transfer: VideoDownloadNoticeState = this.transfers[index];
      if (next.phase === 'hidden' || transfer.phase === 'downloading') { next = transfer; }
      if (transfer.phase === 'downloading') { break; }
    }
    if (next.phase === 'hidden' && this.localSaves.length > 0) { next = this.localSaves[0]; }
    this.publish(next);
  }

  private publish(state: VideoDownloadNoticeState): void {
    AppStorage.setOrCreate<VideoDownloadNoticeState>(VIDEO_DOWNLOAD_NOTICE_KEY, state);
  }
}

export const videoDownloadNoticeStore: VideoDownloadNoticeStore = new VideoDownloadNoticeStore();
