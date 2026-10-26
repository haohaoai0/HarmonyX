// Stable page IDs keep cached feeds, scroll positions and actions attached to
// the same page when the reader changes its visual position.
export function orderedTabIds(saved: string, available: string[]): string[] {
  const result: string[] = [];
  const ids: string[] = saved.split(',');
  for (const id of ids) {
    if (available.indexOf(id) >= 0 && result.indexOf(id) < 0) { result.push(id); }
  }
  for (const id of available) {
    if (result.indexOf(id) < 0) { result.push(id); }
  }
  return result;
}

export function moveTabId(ids: string[], id: string, step: number): string[] {
  const result: string[] = [...ids];
  const from: number = result.indexOf(id);
  const to: number = from + step;
  if (from < 0 || to < 0 || to >= result.length || Math.abs(step) !== 1) { return result; }
  const other: string = result[to];
  result[to] = id;
  result[from] = other;
  return result;
}
