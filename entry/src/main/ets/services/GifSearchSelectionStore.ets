// One-shot handoff from the GIF search destination back to the composer.
export class GifSearchSelectionStore {
  private selectedUri: string = '';

  publish(uri: string): void {
    this.selectedUri = uri;
  }

  take(): string {
    const uri: string = this.selectedUri;
    this.selectedUri = '';
    return uri;
  }
}

export const gifSearchSelectionStore: GifSearchSelectionStore = new GifSearchSelectionStore();
