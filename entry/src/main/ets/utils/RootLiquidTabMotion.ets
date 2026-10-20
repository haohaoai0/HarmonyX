// Shared by the native bar's decorative surface and the window-level touch
// layer. Keeping the surface inside the bar makes HDS own every hide/show frame.
@Observed
export class RootLiquidTabMotion {
  centerX: number = 0;
  centerY: number = 0;
  restWidth: number = 1;
  restHeight: number = 1;
  scaleX: number = 1;
  scaleY: number = 1;
  contentBlur: number = 0;
  displayPage: number = 0;
  ready: boolean = false;
  dragging: boolean = false;
  touchHeld: boolean = false;
}

@Observed
export class RootLiquidTabHitTarget {
  page: number = 0;
  visibleIndex: number = 0;
  x: number = 0;
  y: number = 0;
  width: number = 0;
  height: number = 0;
}
