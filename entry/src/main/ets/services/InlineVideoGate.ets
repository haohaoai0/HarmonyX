// Registry of the cells that are streaming right now.
//
// It used to hand a single cell the right to stream, on the theory that one
// rendition per screen keeps the video the reader is looking at starting
// quickly. That broke the case that matters most: a post can carry several
// videos and a page can show several posts at once, so any second cell that
// came into the viewport demoted the first one back to its cover. The video the
// reader had just tapped stopped mid-playback and had to open again from the
// start, and two neighbouring cells sitting near the threshold could trade the
// claim back and forth so that neither of them ever played.
//
// Cells therefore stream side by side. This registry now only remembers who is
// streaming, which is what the media log reports; the number of live streams is
// bounded by the visibility thresholds in PostMedia instead of by an eviction
// order, so a cell starts at 35% visible and releases below 5%.
class InlineVideoGate {
  private streaming: Map<string, boolean> = new Map<string, boolean>();

  claim(id: string): void {
    if (id.length === 0) {
      return;
    }
    this.streaming.set(id, true);
  }

  release(id: string): void {
    if (id.length === 0) {
      return;
    }
    this.streaming.delete(id);
  }

  streamingCount(): number {
    return this.streaming.size;
  }
}

export const inlineVideoGate: InlineVideoGate = new InlineVideoGate();
