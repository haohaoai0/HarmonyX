import { vibrator } from '@kit.SensorServiceKit';
import hilog from '@ohos.hilog';
import { STORAGE_KEY_HAPTICS_ENABLED, STORAGE_KEY_HAPTICS_INTENSITY } from '../services/MotionSettingsStore';

const DOMAIN = 0xFF00;
const TAG = 'HarmonyX-Haptics';
const support: Map<string, boolean> = new Map<string, boolean>();
let lastTick: number = -1000;
let feedbackRevision: number = 0;

function hapticsEnabled(): boolean {
  return AppStorage.get<boolean>(STORAGE_KEY_HAPTICS_ENABLED) ?? true;
}

async function playHaptic(effectId: string, fallbackDuration: number, revision: number): Promise<void> {
  try {
    let supported: boolean | undefined = support.get(effectId);
    if (supported === undefined) {
      supported = await vibrator.isSupportEffect(effectId);
      support.set(effectId, supported);
    }
    // Capability detection may finish after the user turns feedback off.
    if (!hapticsEnabled() || revision !== feedbackRevision || Date.now() - lastTick > 250) { return; }
    const intensity: number = Math.round(Math.max(1, Math.min(100,
      AppStorage.get<number>(STORAGE_KEY_HAPTICS_INTENSITY) ?? 60)));
    if (supported) {
      await vibrator.startVibration({ type: 'preset', effectId: effectId, count: 1, intensity: intensity },
        { id: 0, usage: 'touch' });
    } else {
      await vibrator.startVibration({ type: 'time', duration: fallbackDuration }, { id: 0, usage: 'touch' });
    }
  } catch (_error) {
    hilog.debug(DOMAIN, TAG, 'touch feedback unavailable');
  }
}

function feedback(effectId: string, duration: number): void {
  const now: number = Date.now();
  // Shared buttons and their actions may both request feedback for one tap.
  if (!hapticsEnabled() || now - lastTick < 80) { return; }
  lastTick = now;
  playHaptic(effectId, duration, ++feedbackRevision);
}

export function hapticTick(): void {
  feedback('haptic.effect.soft', 12);
}

export function hapticConfirm(): void {
  feedback('haptic.effect.sharp', 18);
}
