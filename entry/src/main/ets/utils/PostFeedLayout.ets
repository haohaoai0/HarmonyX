import { DesktopLayout } from './DesktopLayout';

// Secondary feeds use their own measured pane width, including when the app
// has a desktop rail, a detail pane or a smaller floating window.
export class PostFeedLayout {
  static columns(width: number, preferred: number = 0): number {
    if (!Number.isFinite(width) || width < 600) { return 1; }
    const available: number = DesktopLayout.timelineColumns(0, width);
    return preferred >= 1 && preferred <= 3 ? Math.min(preferred, available) : available;
  }

  static template(columns: number): string {
    return columns >= 3 ? '1fr 1fr 1fr' : columns === 2 ? '1fr 1fr' : '1fr';
  }
}
