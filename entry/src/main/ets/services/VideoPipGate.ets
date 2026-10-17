// Cells that are playing inside the system picture-in-picture window.
//
// The floating window shows the surface of a cell that is still mounted in the
// page, so such a cell must survive the scroll that took it off screen. PostMedia
// asks this registry before it unmounts a player that has left the viewport.
class VideoPipGate {
  private held: Map<string, boolean> = new Map<string, boolean>();
  // Automatic hand-off is armed only by a real downward scroll on the detail
  // page. Navigation and lifecycle changes clear it so a page transition
  // cannot hand an about-to-unmount surface to the floating window.
  private autoArmed: Map<string, boolean> = new Map<string, boolean>();

  hold(id: string): void {
    if (id.length === 0) {
      return;
    }
    this.held.set(id, true);
  }

  release(id: string): void {
    if (id.length === 0) {
      return;
    }
    this.held.delete(id);
  }

  isHeld(id: string): boolean {
    return this.held.get(id) === true;
  }

  armAuto(id: string): void {
    if (id.length === 0) {
      return;
    }
    this.autoArmed.set(id, true);
  }

  disarmAuto(id: string): void {
    if (id.length === 0) {
      return;
    }
    this.autoArmed.delete(id);
  }

  isAutoArmed(id: string): boolean {
    return this.autoArmed.get(id) === true;
  }
}

export const videoPipGate: VideoPipGate = new VideoPipGate();
