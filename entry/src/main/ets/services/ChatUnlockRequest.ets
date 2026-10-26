// Share the root PIN sheet with nested native DM pages without persisting keys.
export class ChatUnlockRequest {
  private callback: (action: () => void) => void;

  constructor(callback: (action: () => void) => void) {
    this.callback = callback;
  }

  request(action: () => void): void {
    this.callback(action);
  }
}
