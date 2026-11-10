// Cells that are playing inside the system picture-in-picture window.
//
// The floating window shows the surface of a cell that is still mounted in the
// page, so such a cell must survive the scroll that took it off screen. PostMedia
// asks this registry before it unmounts a player that has left the viewport.
class VideoPipOwner {
  mediaId: string;
  ownerId: string;
  close: () => void;

  constructor(mediaId: string, ownerId: string, close: () => void) {
    this.mediaId = mediaId;
    this.ownerId = ownerId;
    this.close = close;
  }
}

class VideoPipGate {
  private owners: VideoPipOwner[] = [];

  registerOwner(mediaId: string, ownerId: string, close: () => void): void {
    this.unregisterOwner(ownerId);
    this.owners.push(new VideoPipOwner(mediaId, ownerId, close));
  }

  unregisterOwner(ownerId: string): void {
    this.owners = this.owners.filter((owner: VideoPipOwner): boolean => owner.ownerId !== ownerId);
  }

  close(id: string): void {
    this.disarmAuto(id);
    this.release(id);
    // A callback can unregister itself while releasing a retained decoder.
    const owners: VideoPipOwner[] = this.owners.slice();
    for (let i: number = 0; i < owners.length; i++) {
      if (owners[i].mediaId === id) { owners[i].close(); }
    }
  }

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
