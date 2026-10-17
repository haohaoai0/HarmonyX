// Lets UIAbility background events reach the AVPlayer-backed PiP player
// directly. ArkUI component watchers can be suspended while the app is moving
// to the background, but the ability lifecycle callback still runs.

export interface VideoPipPlaybackHandle {
  id(): string;

  resumePipPlayback(): void;
}

class VideoPipPlaybackKeeper {
  private handles: VideoPipPlaybackHandle[] = [];

  register(handle: VideoPipPlaybackHandle): void {
    this.unregister(handle.id());
    this.handles.push(handle);
  }

  unregister(id: string): void {
    const next: VideoPipPlaybackHandle[] = [];
    for (let i: number = 0; i < this.handles.length; i++) {
      const handle: VideoPipPlaybackHandle = this.handles[i];
      if (handle.id() !== id) {
        next.push(handle);
      }
    }
    this.handles = next;
  }

  resumeAll(): void {
    for (let i: number = 0; i < this.handles.length; i++) {
      this.handles[i].resumePipPlayback();
    }
  }
}

export const videoPipPlaybackKeeper: VideoPipPlaybackKeeper = new VideoPipPlaybackKeeper();
