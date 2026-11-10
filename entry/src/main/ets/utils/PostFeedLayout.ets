import { DesktopLayout } from './DesktopLayout';

// Secondary feeds use their own measured pane width, including when the app
// has a desktop rail, a detail pane or a smaller floating window.
export class PostFeedLayout {
  static columns(width: number, preferred: number = 0): number {
    if (!Number.isFinite(width) || width < 600) { return 1; }
    const available: number = DesktopLayout.timelineColumns(0, width);
    // These are persisted modes: 4 remains adaptive two, 5/6 mean four/five.
    if (preferred === 5) { return 4; }
    if (preferred === 6) { return 5; }
    if (preferred === 4) { return 2; }
    return preferred >= 1 && preferred <= 3 ? Math.min(preferred, available) : available;
  }

  static template(columns: number): string {
    if (columns >= 5) { return '1fr 1fr 1fr 1fr 1fr'; }
    if (columns === 4) { return '1fr 1fr 1fr 1fr'; }
    return columns === 3 ? '1fr 1fr 1fr' : columns === 2 ? '1fr 1fr' : '1fr';
  }
}
