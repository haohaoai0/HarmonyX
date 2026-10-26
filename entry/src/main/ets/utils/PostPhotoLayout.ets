import type { MediaAttachment } from '../models/Tweet';

const PHOTO_GAP: number = 6;
const MAX_ROW_HEIGHT: number = 480;
const COMPACT_ROW_HEIGHT: number = 320;

export class PhotoStripLayout {
  height: number = 0;
  widths: number[] = [];
  overflows: boolean = false;
}

// Match the source aspect ratios, including very long screenshots. A shared
// height makes long images narrower instead of cutting off their top/bottom.
export function photoStripLayout(photos: MediaAttachment[], availableWidth: number,
  windowHeight: number = 0, compact: boolean = false): PhotoStripLayout {
  const layout: PhotoStripLayout = new PhotoStripLayout();
  if (photos.length === 0 || availableWidth <= 0) {
    return layout;
  }
  const ratios: number[] = [];
  let totalRatio: number = 0;
  for (let i: number = 0; i < photos.length; i++) {
    const photo: MediaAttachment = photos[i];
    const ratio: number = Number.isFinite(photo.width) && Number.isFinite(photo.height) &&
      photo.width > 0 && photo.height > 0 ? photo.width / photo.height : 1;
    ratios.push(ratio);
    totalRatio += ratio;
  }
  const gaps: number = PHOTO_GAP * (photos.length - 1);
  const rowLimit: number = compact ? COMPACT_ROW_HEIGHT : MAX_ROW_HEIGHT;
  const screenLimit: number = windowHeight > 0 ? windowHeight * (compact ? 0.4 : 0.65) : rowLimit;
  let height: number = Math.min(availableWidth * (compact ? 0.8 : 1.25), rowLimit, screenLimit);
  if (photos.length === 2 && totalRatio >= 2) {
    height = Math.min(height, Math.max(1, availableWidth - gaps) / totalRatio);
  }
  layout.height = Math.max(1, height);
  let contentWidth: number = gaps;
  for (let i: number = 0; i < ratios.length; i++) {
    const width: number = layout.height * ratios[i];
    layout.widths.push(width);
    contentWidth += width;
  }
  layout.overflows = contentWidth > availableWidth + 1;
  return layout;
}
