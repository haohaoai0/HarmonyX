// Keep the avatar's measured slot and center fixed. Only its rendered scale
// follows the gallery, so neither author text nor list height moves mid-drag.
export function mediaAvatarPanProgress(offset: number, leadingInset: number): number {
  if (!Number.isFinite(offset) || leadingInset <= 0 || offset <= 0.5) { return 0; }
  return Math.min(1, offset / Math.min(32, leadingInset));
}

export function mediaAvatarScale(progress: number): number {
  const fraction: number = Number.isFinite(progress) ? Math.max(0, Math.min(1, progress)) : 0;
  return 1 - fraction / 6;
}
