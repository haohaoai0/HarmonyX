import type { MediaAttachment } from '../models/Tweet';

// Geometry for the DM share card. X fills the card's top edge with the post
// media and puts the author row and the text underneath. The official card
// measures a 16:9 media block no matter how many photos it holds, so every tile
// is cropped into that band instead of being sized from its own source ratio.
export const CHAT_POST_MEDIA_GAP: number = 2;
export const CHAT_POST_MEDIA_LIMIT: number = 4;
// The single-media height is expressed as height/width, so a 16:9 source stays
// short and a portrait source grows without swallowing the whole conversation.
const MIN_SINGLE_RATIO: number = 0.55;
const MAX_SINGLE_RATIO: number = 1.2;
const DEFAULT_SINGLE_RATIO: number = 9 / 16;
// The media band under the first photo. 9/16 is what the reference card uses.
const MEDIA_BLOCK_RATIO: number = 9 / 16;

export class ChatPostMediaTile {
  index: number = 0;
  x: number = 0;
  y: number = 0;
  width: number = 0;
  height: number = 0;
}

export class ChatPostMediaLayout {
  width: number = 0;
  height: number = 0;
  tiles: ChatPostMediaTile[] = [];
}

function tile(index: number, x: number, y: number, width: number, height: number): ChatPostMediaTile {
  const cell: ChatPostMediaTile = new ChatPostMediaTile();
  cell.index = index;
  cell.x = x;
  cell.y = y;
  cell.width = width;
  cell.height = height;
  return cell;
}

// A card shows at most four media tiles; extra ones stay reachable through the
// post detail page instead of widening the DM row arbitrarily.
export function chatPostMediaCount(media: MediaAttachment[]): number {
  return Math.min(media.length, CHAT_POST_MEDIA_LIMIT);
}

export function chatPostMediaLayout(media: MediaAttachment[], availableWidth: number): ChatPostMediaLayout {
  const layout: ChatPostMediaLayout = new ChatPostMediaLayout();
  const count: number = chatPostMediaCount(media);
  if (count === 0 || availableWidth <= 0) {
    return layout;
  }
  const gap: number = CHAT_POST_MEDIA_GAP;
  const half: number = Math.max(1, (availableWidth - gap) / 2);
  layout.width = availableWidth;
  if (count === 1) {
    const first: MediaAttachment = media[0];
    const source: number = first.width > 0 && first.height > 0 ? first.height / first.width : DEFAULT_SINGLE_RATIO;
    const ratio: number = Math.max(MIN_SINGLE_RATIO, Math.min(MAX_SINGLE_RATIO, source));
    layout.height = Math.max(1, availableWidth * ratio);
    layout.tiles.push(tile(0, 0, 0, availableWidth, layout.height));
    return layout;
  }
  if (count === 3) {
    const height: number = Math.max(gap + 2, availableWidth * MEDIA_BLOCK_RATIO);
    const stacked: number = Math.max(1, (height - gap) / 2);
    layout.height = height;
    layout.tiles.push(tile(0, 0, 0, half, height));
    layout.tiles.push(tile(1, half + gap, 0, half, stacked));
    layout.tiles.push(tile(2, half + gap, stacked + gap, half, stacked));
    return layout;
  }
  const band: number = availableWidth * MEDIA_BLOCK_RATIO;
  if (count === 2) {
    layout.height = band;
    layout.tiles.push(tile(0, 0, 0, half, band));
    layout.tiles.push(tile(1, half + gap, 0, half, band));
    return layout;
  }
  const rowHeight: number = Math.max(1, (band - gap) / 2);
  layout.height = rowHeight * 2 + gap;
  layout.tiles.push(tile(0, 0, 0, half, rowHeight));
  layout.tiles.push(tile(1, half + gap, 0, half, rowHeight));
  if (count === 4) {
    layout.tiles.push(tile(2, 0, rowHeight + gap, half, rowHeight));
    layout.tiles.push(tile(3, half + gap, rowHeight + gap, half, rowHeight));
  }
  return layout;
}
