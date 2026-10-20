// A movable image belongs to its MediaPhotoNode, not to either ContentSlot.
// Reparenting can emit aboutToDisappear before the viewer attaches the node.
export class MediaImageLifetime {
  private disposed: boolean = false;
  private cleanup: () => void = (): void => {};

  attach(cleanup: () => void): void {
    if (this.disposed) { cleanup(); return; }
    this.cleanup = cleanup;
  }

  release(): void {
    if (this.disposed) { return; }
    this.disposed = true;
    this.cleanup();
    this.cleanup = (): void => {};
  }
}
