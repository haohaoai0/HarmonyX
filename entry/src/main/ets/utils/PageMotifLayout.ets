export interface PageMotifTile {
  key: string;
  motifIndex: number;
  x: number;
  y: number;
  rotation: number;
}

// Stable, staggered placement: scrolling and reactive redraws never shuffle
// the decoration. Density changes spacing while each icon retains its size.
export function pageMotifTiles(width: number, height: number, density: number, count: number): PageMotifTile[] {
  const result: PageMotifTile[] = [];
  if (width <= 0 || height <= 0 || count <= 0) { return result; }
  let spacing: number = 180 - Math.max(0, Math.min(100, density)) * 1.12;
  spacing = Math.max(spacing, Math.sqrt(width * height / 350));
  const columns: number = Math.ceil(width / spacing) + 1;
  const rows: number = Math.ceil(height / spacing) + 1;
  for (let row: number = 0; row < rows; row++) {
    for (let column: number = 0; column < columns; column++) {
      const seed: number = (row * 37 + column * 17) % 101;
      result.push({ key: row.toString() + ':' + column.toString() + ':' + spacing.toFixed(2), motifIndex: (row * 7 + column) % count,
        x: column * spacing + (row % 2 === 0 ? 0 : spacing * 0.5) - 20,
        y: row * spacing - 12, rotation: (seed % 5 - 2) * 8 });
    }
  }
  return result;
}
