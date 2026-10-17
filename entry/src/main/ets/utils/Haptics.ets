// Short haptic confirmation for like / repost. Vibration is a nice-to-have, so
// every failure is swallowed: a device without a vibrator must not break the
// action that triggered it.
import { vibrator } from '@kit.SensorServiceKit';
import hilog from '@ohos.hilog';

const DOMAIN = 0xFF00;
const TAG = 'HarmonyX-Haptics';
const TICK_MS: number = 18;

export function hapticTick(): void {
  try {
    vibrator.startVibration({
      type: 'time',
      duration: TICK_MS
    }, {
      id: 0,
      usage: 'unknown'
    }).catch((error: Object): void => {
      hilog.debug(DOMAIN, TAG, 'vibration unavailable: %{public}s', JSON.stringify(error));
    });
  } catch (error) {
    hilog.debug(DOMAIN, TAG, 'vibration threw: %{public}s', JSON.stringify(error));
  }
}
