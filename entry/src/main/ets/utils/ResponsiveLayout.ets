// Shared window classes for the phone, tablet and 2-in-1 layouts.
// The wide class intentionally leaves enough room for a persistent sidebar,
// a readable feed column and a post-detail column at the same time.
export class ResponsiveLayout {
  public static readonly BREAKPOINT_SM: string = 'sm';
  public static readonly BREAKPOINT_MD: string = 'md';
  public static readonly BREAKPOINT_LG: string = 'lg';
  public static readonly BREAKPOINT_XL: string = 'xl';
  public static readonly HEIGHT_BREAKPOINT_KEY: string = 'harmonyx.height_breakpoint';
  public static readonly COMPACT_WINDOW_KEY: string = 'harmonyx.compact_window';
  public static readonly CONTENT_DESTINATION_OPEN_KEY: string = 'harmonyx.content_destination_open';

  public static breakpointForWidth(widthVp: number): string {
    if (widthVp < 600) {
      return ResponsiveLayout.BREAKPOINT_SM;
    }
    if (widthVp < 840) {
      return ResponsiveLayout.BREAKPOINT_MD;
    }
    if (widthVp < 1200) {
      return ResponsiveLayout.BREAKPOINT_LG;
    }
    return ResponsiveLayout.BREAKPOINT_XL;
  }

  public static isSmall(breakpoint: string): boolean {
    return breakpoint === ResponsiveLayout.BREAKPOINT_SM;
  }

  // Height breakpoints describe the window's aspect ratio, not pixel height.
  // Pura X's 326 x 326 vp cover is sm/md; its 440 x 707 vp inner screen is sm/lg.
  public static heightBreakpoint(widthVp: number, heightVp: number): string {
    if (widthVp <= 0 || heightVp <= 0) { return ResponsiveLayout.BREAKPOINT_LG; }
    const ratio: number = heightVp / widthVp;
    if (ratio < 0.8) { return ResponsiveLayout.BREAKPOINT_SM; }
    return ratio < 1.2 ? ResponsiveLayout.BREAKPOINT_MD : ResponsiveLayout.BREAKPOINT_LG;
  }

  public static isCompactWindow(widthVp: number, heightVp: number): boolean {
    return widthVp > 0 && heightVp > 0 && widthVp < 600 &&
      ResponsiveLayout.heightBreakpoint(widthVp, heightVp) !== ResponsiveLayout.BREAKPOINT_LG;
  }

  public static mediaSheetHeight(widthVp: number, heightVp: number, maxHeight: number,
    topInset: number, bottomInset: number): number {
    const available: number = Math.max(0, heightVp - topInset - bottomInset);
    return Math.min(maxHeight, ResponsiveLayout.isCompactWindow(widthVp, heightVp) ?
      available * 0.9 : heightVp * 0.66);
  }

  public static isLarge(breakpoint: string): boolean {
    return breakpoint === ResponsiveLayout.BREAKPOINT_LG ||
      breakpoint === ResponsiveLayout.BREAKPOINT_XL;
  }

  public static isWide(breakpoint: string): boolean {
    return breakpoint === ResponsiveLayout.BREAKPOINT_XL;
  }

  public static openContentDestination(): void {
    AppStorage.setOrCreate<boolean>(ResponsiveLayout.CONTENT_DESTINATION_OPEN_KEY, true);
  }

  public static closeContentDestination(pageStack: NavPathStack, animated: boolean = true): void {
    pageStack.pop(animated);
    // Settings owns a nested stack in desktop mode. Its local back action
    // must not change the root feed/destination state.
    if (pageStack.getParent() !== null) { return; }
    // Only a stack that actually held a content destination is updated: a
    // narrow-screen flow never sets the flag (see Index.openPost), and a nested
    // destination - a reply, say - popping back onto an open detail must leave
    // it alone. Writing it unconditionally re-synced the feed in the middle of
    // the popping page's shared-element animation.
    const open: boolean =
      AppStorage.get<boolean>(ResponsiveLayout.CONTENT_DESTINATION_OPEN_KEY) === true;
    if (open) {
      AppStorage.setOrCreate<boolean>(ResponsiveLayout.CONTENT_DESTINATION_OPEN_KEY, pageStack.size() > 0);
    }
  }

  public static closeToMain(pageStack: NavPathStack): void {
    pageStack.clear();
    AppStorage.setOrCreate<boolean>(ResponsiveLayout.CONTENT_DESTINATION_OPEN_KEY, false);
  }
}
