import type { MediaAttachment } from '../models/Tweet';

const PHOTO_GAP: number = 6;
const MIN_PHOTO_RATIO: number = 0.75;
const MAX_PHOTO_RATIO: number = 16 / 9;
const MAX_ROW_HEIGHT: number = 320;

export class PhotoStripLayout {
  height: number = 0;
  widths: number[] = [];
  overflows: boolean = false;
}

// A shared row height keeps portraits readable without turning each cell into
// a tall crop. Two square/landscape photos can fit together; portrait groups
// retain their preview size and scroll when their combined width exceeds it.
export function photoStripLayout(photos: MediaAttachment[], availableWidth: number,
  windowHeight: number = 0): PhotoStripLayout {
  const layout: PhotoStripLayout = new PhotoStripLayout();
  if (photos.length === 0 || availableWidth <= 0) {
    return layout;
  }
  const ratios: number[] = [];
  let totalRatio: number = 0;
  for (let i: number = 0; i < photos.length; i++) {
    const photo: MediaAttachment = photos[i];
    const sourceRatio: number = photo.width > 0 && photo.height > 0 ? photo.width / photo.height : 1;
    const ratio: number = Math.max(MIN_PHOTO_RATIO, Math.min(MAX_PHOTO_RATIO, sourceRatio));
    ratios.push(ratio);
    totalRatio += ratio;
  }
  const gaps: number = PHOTO_GAP * (photos.length - 1);
  const screenLimit: number = windowHeight > 0 ? windowHeight * 0.4 : MAX_ROW_HEIGHT;
  let height: number = Math.min(availableWidth * 0.8, MAX_ROW_HEIGHT, screenLimit);
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
