import { media as mediaKit } from '@kit.MediaKit';
import hilog from '@ohos.hilog';

class VideoPlayerPreparationTask {
  active: boolean = true;
  promise: Promise<void> = Promise.resolve<void>(undefined);
}

// The native operation belongs to AVPlayer, including across component
// handoffs. Two views must not prepare the same initialized player twice.
export class VideoPlayerPreparationStore {
  private tasks: WeakMap<mediaKit.AVPlayer, VideoPlayerPreparationTask> =
    new WeakMap<mediaKit.AVPlayer, VideoPlayerPreparationTask>();

  prepare(player: mediaKit.AVPlayer, strategy: mediaKit.PlaybackStrategy): Promise<void> {
    const existing: VideoPlayerPreparationTask | undefined = this.tasks.get(player);
    if (existing !== undefined) { return existing.promise; }
    const task: VideoPlayerPreparationTask = new VideoPlayerPreparationTask();
    this.tasks.set(player, task);
    task.promise = player.setPlaybackStrategy(strategy).catch((): void => {
      hilog.warn(0xFF00, 'HarmonyX-Media', 'buffer strategy setup skipped state=%{public}s', player.state);
    }).then(async (): Promise<void> => {
      if (task.active && player.state === 'initialized') { await player.prepare(); }
    });
    const clear: () => void = (): void => {
      if (this.tasks.get(player) === task) { this.tasks.delete(player); }
    };
    task.promise.then(clear).catch(clear);
    return task.promise;
  }

  cancel(player: mediaKit.AVPlayer): void {
    const task: VideoPlayerPreparationTask | undefined = this.tasks.get(player);
    if (task !== undefined) { task.active = false; this.tasks.delete(player); }
  }
}

export const videoPlayerPreparation: VideoPlayerPreparationStore = new VideoPlayerPreparationStore();
