export interface MediaCommentLayoutInput {
  viewportWidth: number;
  frameWidth: number;
  frameHeight: number;
  frameCenterY: number;
  previewTop: number;
  previewHeight: number;
  controlSize: number;
  controlSpacing: number;
  inset: number;
  gap: number;
  progress: number;
}

export class MediaCommentLayout {
  scale: number = 1;
  offsetX: number = 0;
  offsetY: number = 0;
  controlsY: number = 0;
  controlsOpacity: number = 0;
}

// Transform the existing surface, keeping its measured size and player intact.
export function mediaCommentLayout(input: MediaCommentLayoutInput): MediaCommentLayout {
  const result: MediaCommentLayout = new MediaCommentLayout();
  const progress: number = Math.max(0, Math.min(1, input.progress));
  const previewHeight: number = Math.max(0, input.previewHeight);
  const frameWidth: number = Math.max(1, input.frameWidth);
  const frameHeight: number = Math.max(1, input.frameHeight);
  const controlsWidth: number = input.controlSize * 2 + input.controlSpacing;
  let scale: number = Math.min(1, previewHeight / frameHeight);
  let centerX: number = input.viewportWidth / 2;
  const controlsLeft: number = input.viewportWidth - input.inset - controlsWidth;
  if (centerX + frameWidth * scale / 2 + input.gap > controlsLeft) {
    // Wide clips use the space beside the buttons; tall clips remain centered.
    const availableWidth: number = Math.max(0, controlsLeft - input.gap - input.inset);
    scale = Math.min(scale, availableWidth / frameWidth);
    centerX = input.inset + availableWidth / 2;
  }
  const centerY: number = input.previewTop + previewHeight / 2;
  const controlsY: number = Math.max(input.previewTop,
    centerY + frameHeight * scale / 2 - input.controlSize - input.gap);
  const originalControlsY: number = input.frameCenterY + frameHeight / 2 - input.controlSize;
  result.scale = 1 + (scale - 1) * progress;
  result.offsetX = (centerX - input.viewportWidth / 2) * progress;
  result.offsetY = (centerY - input.frameCenterY) * progress;
  result.controlsY = originalControlsY + (controlsY - originalControlsY) * progress;
  result.controlsOpacity = progress * Math.min(1, previewHeight / Math.max(1, input.controlSize));
  return result;
}
