export interface ChatAlbumSize { width: number; height: number; }
export class ChatAlbumCell {
  index: number = 0;
  width: number = 0;
  height: number = 0;
  constructor(index: number, width: number, height: number) {
    this.index = index; this.width = width; this.height = height;
  }
}
export class ChatAlbumRow { cells: ChatAlbumCell[] = []; height: number = 0; }
export class ChatAlbumGeometry {
  rows: ChatAlbumRow[] = [];
  leading: ChatAlbumCell | null = null;
  width: number = 0;
  height: number = 0;
  gap: number = 0;
}

export function chatAlbumLayout(sizes: ChatAlbumSize[], width: number, maxHeight: number, requestedGap: number): ChatAlbumGeometry {
  let best: ChatAlbumGeometry = new ChatAlbumGeometry();
  if (sizes.length === 0 || !Number.isFinite(width) || !Number.isFinite(maxHeight) || width <= 0 || maxHeight <= 0) { return best; }
  const gap: number = Number.isFinite(requestedGap) ? Math.max(0, Math.min(requestedGap, width / (sizes.length * 2))) : 0;
  const ratios: number[] = sizes.map((size: ChatAlbumSize): number => {
    const ratio: number = size.width > 0 && size.height > 0 ? size.width / size.height : 1;
    return Number.isFinite(ratio) && ratio > 0 ? ratio : 1;
  });
  if (ratios.length === 1) {
    const row: ChatAlbumRow = new ChatAlbumRow();
    best.width = Math.min(width, maxHeight * ratios[0]); best.height = best.width / ratios[0];
    row.height = best.height; row.cells.push(new ChatAlbumCell(0, best.width, best.height)); best.rows.push(row);
    return best;
  }
  // Extreme panoramas/portraits are cropped only in the collage; the viewer keeps the original.
  for (let i: number = 0; i < ratios.length; i++) { ratios[i] = Math.max(0.5, Math.min(2, ratios[i])); }
  let score: number = Number.POSITIVE_INFINITY;
  const target: number = Math.min(maxHeight, width * (ratios.length === 4 ? 1 : 0.75));
  // Bound row enumeration for larger albums while keeping every attachment.
  for (let mask: number = 0; mask < (1 << Math.min(ratios.length - 1, 8)); mask++) {
    const candidate: ChatAlbumGeometry = new ChatAlbumGeometry(); candidate.width = width; candidate.gap = gap;
    let start: number = 0;
    let narrow: number = 0;
    for (let end: number = 0; end < ratios.length; end++) {
      if (end < ratios.length - 1 && (end < 8 ? (mask & (1 << end)) === 0 : (end + 1) % 3 !== 0)) { continue; }
      let sum: number = 0;
      for (let i: number = start; i <= end; i++) { sum += ratios[i]; }
      const row: ChatAlbumRow = new ChatAlbumRow();
      row.height = Math.max(1, width - gap * (end - start)) / sum;
      for (let i: number = start; i <= end; i++) {
        const cellWidth: number = row.height * ratios[i];
        row.cells.push(new ChatAlbumCell(i, cellWidth, row.height));
        narrow += Math.max(0, 0.23 - cellWidth / width);
      }
      candidate.rows.push(row); candidate.height += row.height;
      start = end + 1;
    }
    candidate.height += gap * (candidate.rows.length - 1);
    const candidateScore: number = Math.pow(Math.log(candidate.height / target), 2) + narrow * 3;
    if (candidateScore < score) { score = candidateScore; best = candidate; }
  }
  if (ratios.length === 3) {
    const rightRatio: number = 1 / (1 / ratios[1] + 1 / ratios[2]);
    const naturalHeight: number = (width - gap + gap * rightRatio) / (ratios[0] + rightRatio);
    // Keep the two smaller tiles readable when a landscape leads two narrow portraits.
    const leftWidth: number = Math.min(width * 0.72 - gap, Math.max(width * 0.45, naturalHeight * ratios[0]));
    const rightWidth: number = width - gap - leftWidth;
    const height: number = Math.max(width * 0.62, leftWidth / ratios[0]);
    const leadingScore: number = Math.pow(Math.log(height / target), 2) +
      Math.max(0, 0.23 - rightWidth / width) * 3;
    if (leadingScore < score) {
      best = new ChatAlbumGeometry(); best.width = width; best.height = height; best.gap = gap;
      best.leading = new ChatAlbumCell(0, leftWidth, height);
      for (let i: number = 1; i < 3; i++) {
        const row: ChatAlbumRow = new ChatAlbumRow();
        row.height = (height - gap) * (1 / ratios[i]) / (1 / ratios[1] + 1 / ratios[2]);
        row.cells.push(new ChatAlbumCell(i, rightWidth, row.height)); best.rows.push(row);
      }
    }
  }
  // Keep very tall collages inside the chat viewport without changing individual aspect ratios.
  if (best.height > maxHeight) {
    const scale: number = maxHeight / best.height;
    // The caller scales the gap together with the geometry.
    best.width *= scale; best.height *= scale;
    best.gap *= scale;
    if (best.leading !== null) { best.leading.width *= scale; best.leading.height *= scale; }
    for (let i: number = 0; i < best.rows.length; i++) {
      best.rows[i].height *= scale;
      for (let j: number = 0; j < best.rows[i].cells.length; j++) {
        best.rows[i].cells[j].width *= scale; best.rows[i].cells[j].height *= scale;
      }
    }
  }
  return best;
}
