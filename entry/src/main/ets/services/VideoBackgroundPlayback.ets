// Keeps a fullscreen video audible after the reader leaves the app or locks
// the screen.
//
// HarmonyOS only allows audio to keep running in the background while the
// UIAbility holds a matching long-running task, and it wants the playback to
// be reported through a media session at the same time. Fullscreen playback
// already claims the session with the control centre, so this service owns
// the audioPlayback task that goes with it: one owner at a time, released as
// soon as that video pauses or is torn down, because an AUDIO_PLAYBACK task
// without audio behind it is what gets an app frozen.
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { common, wantAgent, WantAgent } from '@kit.AbilityKit';
import hilog from '@ohos.hilog';

const DOMAIN = 0xFF00;
const TAG = 'HarmonyX-VideoTask';
const BUNDLE_NAME: string = 'com.haohaoai0.harmonx';
const ABILITY_NAME: string = 'EntryAbility';

class VideoBackgroundPlayback {
  private ownerId: string = '';
  private running: boolean = false;
  private requesting: boolean = false;

  // `id` is the media id of the video that wants to keep sounding; a request
  // from any other video is ignored so a short feed cell cannot release the
  // task out from under the fullscreen player that owns it.
  start(id: string, context: common.UIAbilityContext): void {
    if (id.length === 0) {
      return;
    }
    this.ownerId = id;
    if (this.running || this.requesting) {
      return;
    }
    this.requesting = true;
    const info: wantAgent.WantAgentInfo = {
      wants: [
        {
          bundleName: BUNDLE_NAME,
          abilityName: ABILITY_NAME
        }
      ],
      actionType: wantAgent.OperationType.START_ABILITY,
      requestCode: 0,
      actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    };
    wantAgent.getWantAgent(info).then((agent: WantAgent): void => {
      backgroundTaskManager.startBackgroundRunning(context,
        backgroundTaskManager.BackgroundMode.AUDIO_PLAYBACK, agent).then((): void => {
        this.requesting = false;
        this.running = true;
        // A stopped player can finish requesting after it has been released.
        // Mark the acquired task before releasing it; the newest audio owner
        // may also inherit this pending request rather than start a second one.
        if (this.ownerId.length === 0) {
          this.release(context);
          return;
        }
      }).catch((error: BusinessError): void => {
        this.requesting = false;
        hilog.warn(DOMAIN, TAG, 'background playback refused: %{public}d', error.code);
      });
    }).catch((error: BusinessError): void => {
      this.requesting = false;
      hilog.warn(DOMAIN, TAG, 'background playback agent failed: %{public}d', error.code);
    });
  }

  stop(id: string, context: common.UIAbilityContext): void {
    if (this.ownerId !== id) {
      return;
    }
    this.ownerId = '';
    this.release(context);
  }

  private release(context: common.UIAbilityContext): void {
    if (!this.running) {
      return;
    }
    this.running = false;
    backgroundTaskManager.stopBackgroundRunning(context).then((): void => {
    }).catch((error: BusinessError): void => {
      hilog.warn(DOMAIN, TAG, 'background playback release failed: %{public}d', error.code);
    });
  }
}

export const videoBackgroundPlayback: VideoBackgroundPlayback = new VideoBackgroundPlayback();
