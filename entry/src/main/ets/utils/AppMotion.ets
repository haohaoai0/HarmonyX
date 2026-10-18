import { curves } from '@kit.ArkUI';
import { boundedMotionValue, DEFAULT_MOTION_DURATION, DEFAULT_MOTION_AMPLITUDE, DEFAULT_MOTION_DAMPING,
  STORAGE_KEY_REDUCE_MOTION, STORAGE_KEY_MOTION_DURATION, STORAGE_KEY_MOTION_AMPLITUDE,
  STORAGE_KEY_MOTION_DAMPING, STORAGE_KEY_SYMBOL_EFFECTS } from '../services/MotionSettingsStore';

export function motionReduced(): boolean {
  return AppStorage.get<boolean>(STORAGE_KEY_REDUCE_MOTION) ?? false;
}

export function motionDuration(base: number = DEFAULT_MOTION_DURATION): number {
  if (motionReduced()) { return 0; }
  const duration: number = boundedMotionValue(AppStorage.get<number>(STORAGE_KEY_MOTION_DURATION) ??
    DEFAULT_MOTION_DURATION, DEFAULT_MOTION_DURATION, 100, 700);
  return Math.round(base * duration / DEFAULT_MOTION_DURATION);
}

export function motionDistance(distance: number): number {
  if (motionReduced()) { return 0; }
  return distance * boundedMotionValue(AppStorage.get<number>(STORAGE_KEY_MOTION_AMPLITUDE) ??
    DEFAULT_MOTION_AMPLITUDE, DEFAULT_MOTION_AMPLITUDE, 0, 1.5);
}

export function motionScale(scale: number): number {
  return 1 + motionDistance(scale - 1);
}

export function motionCurve(): curves.ICurve {
  const damping: number = boundedMotionValue(AppStorage.get<number>(STORAGE_KEY_MOTION_DAMPING) ??
    DEFAULT_MOTION_DAMPING, DEFAULT_MOTION_DAMPING, 0.5, 1);
  // springMotion ignores duration. springCurve honours the user's duration;
  // 30 = 2 * sqrt(225), so the slider expresses a damping ratio.
  return curves.springCurve(0, 1, 225, motionReduced() ? 30 : 30 * damping);
}

export function symbolMotionEnabled(): boolean {
  return !motionReduced() && (AppStorage.get<boolean>(STORAGE_KEY_SYMBOL_EFFECTS) ?? true) &&
    (AppStorage.get<number>(STORAGE_KEY_MOTION_AMPLITUDE) ?? DEFAULT_MOTION_AMPLITUDE) > 0;
}
