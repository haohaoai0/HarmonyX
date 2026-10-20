const scrollingControllers: WeakSet<Scroller> = new WeakSet<Scroller>();
const canceledControllers: WeakSet<Scroller> = new WeakSet<Scroller>();

export function scrollStarted(scroller: Scroller): void {
  canceledControllers.delete(scroller);
  scrollingControllers.add(scroller);
}

export function scrollStopped(scroller: Scroller): void {
  scrollingControllers.delete(scroller);
}

export function scrollFrame(scroller: Scroller, offset: number,
  state: ScrollState): OnScrollFrameBeginHandlerResult {
  if (state === ScrollState.Scroll) { canceledControllers.delete(scroller); }
  // A queued inertia frame must not move the content after the stopping press,
  // including after release. A fresh drag immediately restores native physics.
  return { offsetRemain: state === ScrollState.Fling && canceledControllers.has(scroller) ? 0 : offset };
}

function stopAtCurrentPosition(scroller: Scroller): boolean {
  const wasScrolling: boolean = scrollingControllers.has(scroller);
  canceledControllers.add(scroller);
  scrollStopped(scroller);
  try {
    const offset: OffsetResult = scroller.currentOffset();
    scroller.scrollTo({ xOffset: offset.xOffset, yOffset: offset.yOffset, animation: false });
  } catch (_error) {
    // A pane may have detached its controller during navigation.
  }
  return wasScrolling;
}

// Hit testing runs before a card/media child can consume the press. Cancel
// native inertia and programmatic scroll animations at their current position.
export function stopScrollOnTouch(event: TouchEvent, scroller: Scroller,
  nestedScrollers: Scroller[] = []): HitTestMode {
  if (event.type !== TouchType.Down) { return HitTestMode.Default; }
  let wasScrolling: boolean = stopAtCurrentPosition(scroller);
  for (let index: number = 0; index < nestedScrollers.length; index++) {
    const nestedWasScrolling: boolean = stopAtCurrentPosition(nestedScrollers[index]);
    wasScrolling = wasScrolling || nestedWasScrolling;
  }
  // The stopping press belongs to the scroll container, so it can immediately
  // start another drag without accidentally opening the post under the finger.
  return wasScrolling ? HitTestMode.Block : HitTestMode.Default;
}
