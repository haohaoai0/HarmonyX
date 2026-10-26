// Run the shared-media return INSIDE Navigation's pop transaction. Navigation
// makes the previous destination visible before invoking transition(), so the
// shrinking image/player never exposes a hidden source behind a black page.
type MediaReturnAction = () => void;
const mediaReturns: Map<string, MediaViewerNavigationReturn> = new Map<string, MediaViewerNavigationReturn>();

export class MediaViewerNavigationReturn {
  private destinationId: string = '';
  private action: MediaReturnAction | null = null;
  private finishTransition: (() => void) | null = null;
  private running: boolean = false;

  attach(context: NavDestinationContext): void {
    this.destinationId = context.navDestinationId ?? '';
    if (this.destinationId.length > 0) { mediaReturns.set(this.destinationId, this); }
  }

  request(action: MediaReturnAction, pop: () => void): boolean {
    if (this.running || this.destinationId.length === 0) { return false; }
    if (this.action !== null) { return true; }
    this.action = action;
    pop();
    return true;
  }

  pending(): boolean { return this.action !== null; }

  start(proxy: NavigationTransitionProxy): void {
    const action: MediaReturnAction | null = this.action;
    this.action = null;
    this.running = true;
    this.finishTransition = (): void => { proxy.finishTransition(); };
    if (action !== null) { action(); }
    else { this.complete(); }
  }

  complete(): boolean {
    if (!this.running) { return false; }
    const finish: (() => void) | null = this.finishTransition;
    this.finishTransition = null;
    if (finish !== null) { finish(); }
    return true;
  }

  ended(): void {
    this.action = null;
    this.finishTransition = null;
    this.running = false;
  }

  detach(): void {
    if (mediaReturns.get(this.destinationId) === this) { mediaReturns.delete(this.destinationId); }
    this.ended();
    this.destinationId = '';
  }
}

export function mediaViewerNavigationTransition(from: NavContentInfo,
  operation: NavigationOperation): NavigationAnimatedTransition | undefined {
  if (operation !== NavigationOperation.POP) { return undefined; }
  const controller: MediaViewerNavigationReturn | undefined = mediaReturns.get(from.navDestinationId ?? '');
  if (controller === undefined || !controller.pending()) { return undefined; }
  return {
    timeout: 1500,
    transition: (proxy: NavigationTransitionProxy): void => controller.start(proxy),
    onTransitionEnd: (_success: boolean): void => controller.ended()
  };
}
