// Shared window classes for the phone, tablet and 2-in-1 layouts.
// The wide class intentionally leaves enough room for a persistent sidebar,
// a readable feed column and a post-detail column at the same time.
export class ResponsiveLayout {
  public static readonly BREAKPOINT_SM: string = 'sm';
  public static readonly BREAKPOINT_MD: string = 'md';
  public static readonly BREAKPOINT_LG: string = 'lg';
  public static readonly BREAKPOINT_XL: string = 'xl';
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

  public static closeContentDestination(pageStack: NavPathStack): void {
    pageStack.pop();
    AppStorage.setOrCreate<boolean>(ResponsiveLayout.CONTENT_DESTINATION_OPEN_KEY, pageStack.size() > 0);
  }
}
