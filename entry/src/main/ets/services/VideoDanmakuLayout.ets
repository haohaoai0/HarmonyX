import { VideoDanmakuComment } from './VideoDanmaku';

export class VideoDanmakuFlight {
  key: number;
  comment: VideoDanmakuComment;
  text: string;
  width: number;
  lane: number;
  y: number;
  viewportWidth: number;
  duration: number;
  startedAt: number;

  constructor(key: number, comment: VideoDanmakuComment, text: string, width: number,
    lane: number, y: number, viewportWidth: number, duration: number, startedAt: number) {
    this.key = key;
    this.comment = comment;
    this.text = text;
    this.width = width;
    this.lane = lane;
    this.y = y;
    this.viewportWidth = viewportWidth;
    this.duration = duration;
    this.startedAt = startedAt;
  }

  speed(): number {
    return (this.viewportWidth + this.width) / this.duration;
  }

  tailAt(clock: number): number {
    return this.viewportWidth + this.width - Math.max(0, clock - this.startedAt) * this.speed();
  }
}

// Inspired by yunshang-bili's DanmakuTrackManager: admit a new line only after
// the preceding tail has entered, and reject faster lines that would catch it.
// Reference: https://github.com/chunwcc/yunshang-bili/blob/a1abea07c05e5673ec5e3150967957d889ee96bb/entry/src/main/ets/services/DanmakuTrackManager.ets
// X replies have no media timestamps; this clock advances only during playback.
export class VideoDanmakuLayout {
  private width: number = 0;
  private height: number = 0;
  private rowHeight: number = 28;
  private laneGap: number = 4;
  private inset: number = 8;
  private spacing: number = 32;
  private laneCount: number = 0;
  private nextLane: number = 0;
  private serial: number = 0;
  private clock: number = 0;
  private flights: VideoDanmakuFlight[] = [];

  configure(width: number, height: number, rowHeight: number, laneGap: number,
    inset: number, spacing: number): boolean {
    if (Math.abs(this.width - width) < 1 && Math.abs(this.height - height) < 1 &&
      this.rowHeight === rowHeight && this.laneGap === laneGap && this.inset === inset && this.spacing === spacing) {
      return false;
    }
    this.width = Math.max(0, width);
    this.height = Math.max(0, height);
    this.rowHeight = Math.max(1, rowHeight);
    this.laneGap = Math.max(0, laneGap);
    this.inset = Math.max(0, inset);
    this.spacing = Math.max(0, spacing);
    this.laneCount = Math.max(0, Math.min(5,
      Math.floor((this.height - this.inset * 2 + this.laneGap) / (this.rowHeight + this.laneGap))));
    this.clear();
    return true;
  }

  clear(): void {
    this.flights = [];
    this.nextLane = 0;
  }

  advance(elapsed: number): void {
    this.clock += Math.max(0, elapsed);
    this.flights = this.flights.filter((flight: VideoDanmakuFlight): boolean =>
      this.clock - flight.startedAt < flight.duration + 100);
  }

  active(): VideoDanmakuFlight[] {
    return this.flights;
  }

  launch(comment: VideoDanmakuComment, text: string, measuredWidth: number): VideoDanmakuFlight | null {
    if (this.width <= 0 || this.laneCount === 0 || this.flights.length >= 16 ||
      !Number.isFinite(measuredWidth) || measuredWidth <= 0) { return null; }
    const width: number = Math.ceil(measuredWidth);
    // Equal readable speeds let longer replies finish instead of truncating
    // them or making long lines rush across the video.
    const speed: number = Math.max(0.048, Math.min(0.12, this.width / 6000));
    const duration: number = Math.ceil((this.width + width) / speed);
    for (let offset: number = 0; offset < this.laneCount; ++offset) {
      const lane: number = (this.nextLane + offset) % this.laneCount;
      if (!this.laneAvailable(lane, speed)) { continue; }
      const flight: VideoDanmakuFlight = new VideoDanmakuFlight(++this.serial, comment, text, width,
        lane, this.inset + lane * (this.rowHeight + this.laneGap), this.width, duration, this.clock);
      this.flights = [...this.flights, flight];
      this.nextLane = (lane + 1) % this.laneCount;
      return flight;
    }
    return null;
  }

  private laneAvailable(lane: number, speed: number): boolean {
    for (const previous of this.flights) {
      if (previous.lane !== lane) { continue; }
      const tail: number = previous.tailAt(this.clock);
      const gap: number = this.width - tail;
      if (gap < this.spacing) { return false; }
      if (speed > previous.speed() && tail > 0 &&
        (gap - this.spacing) / (speed - previous.speed()) < tail / previous.speed()) { return false; }
    }
    return true;
  }
}
