import { ResponsiveLayout } from './ResponsiveLayout';

export class DesktopLayout {
  static active(enabled: boolean, breakpoint: string): boolean {
    // Medium windows include portrait tablets and unfolded wide phones.
    return enabled && (breakpoint === ResponsiveLayout.BREAKPOINT_MD || ResponsiveLayout.isLarge(breakpoint));
  }

  static timelineColumns(mode: number, contentWidth: number): number {
    if (mode === 1 || mode === 2 || mode === 3) { return mode; }
    const contentBreakpoint: string = ResponsiveLayout.breakpointForWidth(contentWidth);
    if (ResponsiveLayout.isSmall(contentBreakpoint)) { return 1; }
    return ResponsiveLayout.isLarge(contentBreakpoint) ? 3 : 2;
  }

  static hasAside(breakpoint: string, page: string, messages: boolean): boolean {
    return ResponsiveLayout.isWide(breakpoint) && !messages &&
      page !== 'Settings' && page !== 'SettingsSection' && page !== 'AccountPrivacy' &&
      page !== 'Grok' && page !== 'PostDetail' && page !== 'PhotoViewer' && page !== 'VideoFeedViewer';
  }

  static compactRail(breakpoint: string, messages: boolean): boolean {
    return messages || !ResponsiveLayout.isWide(breakpoint);
  }
}
