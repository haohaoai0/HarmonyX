import { common } from '@kit.AbilityKit';

export const STORAGE_KEY_SECURE_MEDIA_SAVE: string = 'harmonyx.secure_media_save';

export class SecureMediaSaveRequest {
  context: common.UIAbilityContext;
  url: string;
  mediaId: string;
  isVideo: boolean;
  callback: (result: number) => void;

  constructor(context: common.UIAbilityContext, url: string, mediaId: string, isVideo: boolean,
    callback: (result: number) => void) {
    this.context = context; this.url = url; this.mediaId = mediaId;
    this.isVideo = isVideo; this.callback = callback;
  }
}

export class SecureMediaSaveController {
  private requests: SecureMediaSaveRequest[] = [];

  current(): SecureMediaSaveRequest | null { return this.requests.length > 0 ? this.requests[0] : null; }

  enqueue(request: SecureMediaSaveRequest): void {
    this.requests.push(request);
    this.publish();
  }

  complete(request: SecureMediaSaveRequest, result: number): void {
    if (this.current() !== request) { return; }
    this.requests.shift();
    request.callback(result);
    this.publish();
  }

  cancel(): void {
    const pending: SecureMediaSaveRequest[] = this.requests;
    this.requests = [];
    for (const request of pending) { request.callback(2); }
    this.publish();
  }

  private publish(): void {
    AppStorage.setOrCreate<number>(STORAGE_KEY_SECURE_MEDIA_SAVE,
      (AppStorage.get<number>(STORAGE_KEY_SECURE_MEDIA_SAVE) ?? 0) + 1);
  }
}

export const secureMediaSaveController: SecureMediaSaveController = new SecureMediaSaveController();
