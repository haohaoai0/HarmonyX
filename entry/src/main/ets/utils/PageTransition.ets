import { motionDuration, motionScale, motionCurve, motionReduced } from './AppMotion';
import { PAGE_TRANSITION_OFFICIAL } from '../services/PageTransitionSettingsStore';
import { UIContext } from '@kit.ArkUI';

// Use the platform's paired enter/exit animations so interrupted navigation and
// system back gestures also restore scale, opacity and page visibility.
// NONE belongs to an existing media-viewer transition and must stay in control.
export function pageSystemTransition(mode: string,
  fallback: NavigationSystemTransitionType = NavigationSystemTransitionType.DEFAULT): NavigationSystemTransitionType {
  if (motionReduced()) { return NavigationSystemTransitionType.NONE; }
  if (fallback === NavigationSystemTransitionType.NONE) {
    return fallback;
  }
  return mode === PAGE_TRANSITION_OFFICIAL ? NavigationSystemTransitionType.EXPLODE : fallback;
}

const pageMotions: Map<string, WeakRef<PageTransitionMotion>> = new Map<string, WeakRef<PageTransitionMotion>>();

@Observed
export class PageTransitionMotion {
  // Keep page roots in the live render tree: grouping an HDS navigation page
  // offscreen breaks backdrop sampling in its gradient-blurred title bar.
  scale: number = 1;
  opacity: number = 1;
  private revision: number = 0;

  attach(context: NavDestinationContext): void {
    const id: string = context.navDestinationId ?? '';
    if (id.length === 0) { return; }
    pageMotions.forEach((reference: WeakRef<PageTransitionMotion>, key: string): void => {
      if (reference.deref() === undefined) { pageMotions.delete(key); }
    });
    pageMotions.set(id, new WeakRef<PageTransitionMotion>(this));
  }

  begin(scale: number, opacity: number): number {
    this.revision += 1;
    this.scale = scale;
    this.opacity = opacity;
    return this.revision;
  }

  reset(revision: number): void {
    // A completion from an interrupted transition must not reset a newer one.
    if (this.revision !== revision) { return; }
    this.scale = 1;
    this.opacity = 1;
  }
}

function motionFor(info: NavContentInfo, root: PageTransitionMotion): PageTransitionMotion | undefined {
  if (info.index === -1) { return root; }
  return pageMotions.get(info.navDestinationId ?? '')?.deref();
}

// The native EXPLODE on a destination alone leaves the root NavBar's default
// horizontal movement running underneath. Own BOTH surfaces for this mode.
export function officialPageTransition(ui: UIContext, root: PageTransitionMotion, mode: string,
  from: NavContentInfo, to: NavContentInfo, operation: NavigationOperation): NavigationAnimatedTransition | undefined {
  if (mode !== PAGE_TRANSITION_OFFICIAL || from.mode === NavDestinationMode.DIALOG ||
    to.mode === NavDestinationMode.DIALOG) { return undefined; }
  const outgoing: PageTransitionMotion | undefined = motionFor(from, root);
  const incoming: PageTransitionMotion | undefined = motionFor(to, root);
  if (outgoing === undefined || incoming === undefined || outgoing === incoming) { return undefined; }
  const pop: boolean = operation === NavigationOperation.POP;
  let fromRevision: number = 0;
  let toRevision: number = 0;
  let finished: boolean = false;
  return {
    timeout: 1000,
    transition: (proxy: NavigationTransitionProxy): void => {
      fromRevision = outgoing.begin(1, 1);
      toRevision = incoming.begin(motionScale(pop ? 0.96 : 1.04), 0);
      ui.animateTo({
        duration: motionDuration(pop ? 220 : 260),
        curve: motionCurve(),
        onFinish: (): void => {
          if (finished) { return; }
          finished = true;
          proxy.finishTransition();
        }
      }, (): void => {
        outgoing.scale = motionScale(pop ? 1.04 : 0.96);
        outgoing.opacity = 0;
        incoming.scale = 1;
        incoming.opacity = 1;
      });
    },
    onTransitionEnd: (_success: boolean): void => {
      finished = true;
      outgoing.reset(fromRevision);
      incoming.reset(toRevision);
    }
  };
}
