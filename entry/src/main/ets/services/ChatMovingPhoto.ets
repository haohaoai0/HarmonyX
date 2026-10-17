import { common } from '@kit.AbilityKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { dataSharePredicates } from '@kit.ArkData';
import { fileIo } from '@kit.CoreFileKit';

export interface ChatMovingPhotoExport {
  imagePath: string;
  videoPath: string;
}

class ChatMovingPhotoRequest implements photoAccessHelper.MediaAssetDataHandler<photoAccessHelper.MovingPhoto> {
  private resolve: (photo: photoAccessHelper.MovingPhoto) => void;
  private reject: (error: Error) => void;
  private context: common.UIAbilityContext;
  private requestId: string = '';
  private timer: number = -1;
  private settled: boolean = false;
  private cancelled: boolean = false;

  constructor(context: common.UIAbilityContext, resolve: (photo: photoAccessHelper.MovingPhoto) => void,
    reject: (error: Error) => void) {
    this.context = context; this.resolve = resolve; this.reject = reject;
  }

  start(asset: photoAccessHelper.PhotoAsset): void {
    this.timer = setTimeout((): void => {
      this.cancelled = true;
      this.fail(new Error('moving_photo_timeout'));
      this.cancel();
    }, 60000);
    photoAccessHelper.MediaAssetManager.requestMovingPhoto(this.context, asset,
      { deliveryMode: photoAccessHelper.DeliveryMode.HIGH_QUALITY_MODE }, this)
      .then((id: string): void => {
        this.requestId = id;
        if (this.cancelled) { this.cancel(); }
      }).catch((error: Error): void => { this.fail(error); });
  }

  // MediaLibrary invokes this callback without the handler as its receiver.
  // Capture the request instance instead of relying on the native call's `this`.
  onDataPrepared: (photo: photoAccessHelper.MovingPhoto) => void = (photo: photoAccessHelper.MovingPhoto): void => {
    if (this.settled) { return; }
    if (photo === undefined || photo === null) { this.fail(new Error('moving_photo_unavailable')); return; }
    this.settled = true; clearTimeout(this.timer); this.resolve(photo);
  };

  private fail(error: Error): void {
    if (this.settled) { return; }
    this.settled = true; clearTimeout(this.timer); this.reject(error);
  }

  private cancel(): void {
    if (this.requestId.length > 0) {
      photoAccessHelper.MediaAssetManager.cancelRequest(this.context, this.requestId).catch((): void => {});
    }
  }
}

export class ChatMovingPhoto {
  static async selected(context: common.UIAbilityContext, uri: string): Promise<photoAccessHelper.MovingPhoto | undefined> {
    // Only picker-granted media-library URIs can be queried without library-wide permission.
    if (!uri.startsWith('file://media/')) { return undefined; }
    const helper: photoAccessHelper.PhotoAccessHelper = photoAccessHelper.getPhotoAccessHelper(context);
    const predicates: dataSharePredicates.DataSharePredicates = new dataSharePredicates.DataSharePredicates();
    predicates.equalTo(photoAccessHelper.PhotoKeys.URI, uri);
    const options: photoAccessHelper.FetchOptions = {
      fetchColumns: [photoAccessHelper.PhotoKeys.PHOTO_SUBTYPE], predicates: predicates
    };
    let fetched: photoAccessHelper.FetchResult<photoAccessHelper.PhotoAsset> | undefined = undefined;
    try {
      fetched = await helper.getAssets(options);
      const asset: photoAccessHelper.PhotoAsset = await fetched.getFirstObject();
      if (asset.get(photoAccessHelper.PhotoKeys.PHOTO_SUBTYPE) !== photoAccessHelper.PhotoSubtype.MOVING_PHOTO) { return undefined; }
      return await new Promise<photoAccessHelper.MovingPhoto>((resolve: (photo: photoAccessHelper.MovingPhoto) => void,
        reject: (error: Error) => void): void => { new ChatMovingPhotoRequest(context, resolve, reject).start(asset); });
    } finally {
      fetched?.close();
      await helper.release();
    }
  }

  static async export(context: common.UIAbilityContext, photo: photoAccessHelper.MovingPhoto,
    id: string): Promise<ChatMovingPhotoExport> {
    const imagePath: string = context.cacheDir + '/xchat_moving_' + id + '_image.jpg';
    const videoPath: string = context.cacheDir + '/xchat_moving_' + id + '_video.mp4';
    try {
      // Export original resources, including the video audio track and the original cover.
      await photo.requestContent(imagePath, videoPath);
      if (fileIo.statSync(imagePath).size <= 0 || fileIo.statSync(videoPath).size <= 0) {
        throw new Error('moving_photo_empty_resource');
      }
      return { imagePath: imagePath, videoPath: videoPath };
    } catch (error) {
      ChatMovingPhoto.removeExports(context, [imagePath, videoPath]);
      throw error as Error;
    }
  }

  static removeExports(context: common.UIAbilityContext, paths: string[]): void {
    const prefix: string = context.cacheDir + '/';
    for (let i: number = 0; i < paths.length; i++) {
      const path: string = paths[i];
      if (!path.startsWith(prefix) ||
        !/^xchat_moving_[0-9a-f-]{36}_(image\.jpg|video\.mp4)$/.test(path.substring(prefix.length))) { continue; }
      try { fileIo.unlinkSync(path); } catch (error) {}
    }
  }

  static cleanup(context: common.UIAbilityContext): void {
    const names: string[] = fileIo.listFileSync(context.cacheDir);
    ChatMovingPhoto.removeExports(context, names.map((name: string): string => context.cacheDir + '/' + name));
  }
}
