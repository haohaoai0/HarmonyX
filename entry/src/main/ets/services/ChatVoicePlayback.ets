// A conversation can mount many bubbles. Only the selected one owns a player.
class ChatVoicePlayback {
  private stop: (() => void) | null = null;
  claim(stop: () => void): void {
    if (this.stop !== null && this.stop !== stop) { this.stop(); }
    this.stop = stop;
  }
  release(stop: () => void): void { if (this.stop === stop) { this.stop = null; } }
}
export const chatVoicePlayback: ChatVoicePlayback = new ChatVoicePlayback();
