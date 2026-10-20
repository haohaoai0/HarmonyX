// The AR adapter supplies expression weights, never camera images.
export class EyeReadingSample {
  time: number = 0;
  valid: boolean = false;
  vertical: number = 0;
  horizontal: number = 0;
  eyeDifference: number = 0;
  blink: number = 0;
}

export class EyeReadingFeedback {
  state: string = 'calibrating';
  progress: number = 0;
  direction: number = 0;
  action: number = 0;
}

export class EyeReadingPolicy {
  private calibrated: boolean = false;
  private calibrationStart: number = 0;
  private calibrationCount: number = 0;
  private baseline: number = 0;
  private horizontalBaseline: number = 0;
  private filtered: number = 0;
  private lastTime: number = 0;
  private lostSince: number = 0;
  private centerStart: number = 0;
  private candidateStart: number = 0;
  private candidate: number = 0;
  private armed: boolean = false;
  private blockedUntil: number = 0;
  private cooldownUntil: number = 0;
  private dwell: number = 900;
  private threshold: number = 0.22;

  configure(dwell: number, threshold: number): void {
    this.dwell = Number.isFinite(dwell) ? Math.max(600, Math.min(2000, dwell)) : 900;
    this.threshold = Number.isFinite(threshold) ? Math.max(0.12, Math.min(0.5, threshold)) : 0.22;
    this.reset();
  }

  reset(): void {
    this.calibrated = false; this.calibrationStart = 0; this.calibrationCount = 0;
    this.baseline = 0; this.horizontalBaseline = 0; this.filtered = 0; this.lastTime = 0; this.lostSince = 0;
    this.blockedUntil = 0; this.cooldownUntil = 0; this.disarm();
  }

  suspend(time: number, duration: number = 1500): void {
    this.blockedUntil = Math.max(this.blockedUntil, time + duration);
    this.disarm();
  }

  private disarm(): void {
    this.armed = false; this.centerStart = 0; this.candidate = 0; this.candidateStart = 0;
  }

  update(sample: EyeReadingSample, blocked: boolean = false): EyeReadingFeedback {
    const result: EyeReadingFeedback = new EyeReadingFeedback();
    if (!Number.isFinite(sample.time) || sample.time <= this.lastTime) {
      this.disarm(); result.state = 'lost'; return result;
    }
    const gap: number = this.lastTime === 0 ? 0 : sample.time - this.lastTime;
    this.lastTime = sample.time;
    // Never accumulate a dwell across missing frames or an app interruption.
    if (gap > 250) {
      this.disarm();
      if (!this.calibrated) { this.calibrationStart = 0; this.calibrationCount = 0; }
    }
    if (gap > 1800) {
      this.calibrated = false; this.calibrationStart = 0; this.calibrationCount = 0;
    }
    if (blocked || sample.time < this.blockedUntil) {
      this.disarm(); this.calibrationStart = 0; this.calibrationCount = 0;
      result.state = 'paused'; return result;
    }
    if (!sample.valid || !Number.isFinite(sample.vertical) || !Number.isFinite(sample.horizontal) ||
      !Number.isFinite(sample.blink) || !Number.isFinite(sample.eyeDifference) || sample.blink > 0.45 ||
      sample.eyeDifference > 0.35) {
      this.disarm(); this.calibrationStart = 0; this.calibrationCount = 0;
      if (this.lostSince === 0) { this.lostSince = sample.time; }
      if (sample.time - this.lostSince > 1800) { this.calibrated = false; }
      result.state = 'lost'; return result;
    }
    this.lostSince = 0;
    if (!this.calibrated) {
      if (this.calibrationCount === 0 || Math.abs(sample.vertical - this.baseline) > 0.12 ||
        Math.abs(sample.horizontal - this.horizontalBaseline) > 0.12) {
        this.calibrationStart = sample.time; this.calibrationCount = 0;
        this.baseline = sample.vertical; this.horizontalBaseline = sample.horizontal;
      }
      this.calibrationCount++;
      this.baseline += (sample.vertical - this.baseline) / this.calibrationCount;
      this.horizontalBaseline += (sample.horizontal - this.horizontalBaseline) / this.calibrationCount;
      result.progress = Math.min(1, (sample.time - this.calibrationStart) / 1400);
      if (result.progress >= 1 && this.calibrationCount >= 12) {
        this.calibrated = true; this.filtered = 0; result.state = 'center'; result.progress = 0;
      }
      return result;
    }
    if (Math.abs(sample.horizontal - this.horizontalBaseline) > 0.3) {
      this.disarm(); result.state = 'center'; return result;
    }
    this.filtered = gap > 250 ? sample.vertical - this.baseline :
      this.filtered * 0.5 + (sample.vertical - this.baseline) * 0.5;
    const centered: boolean = Math.abs(sample.vertical - this.baseline) < this.threshold * 0.55;
    if (centered) {
      this.candidate = 0; this.candidateStart = 0;
      if (this.centerStart === 0) { this.centerStart = sample.time; }
      if (sample.time - this.centerStart >= 250 && sample.time >= this.cooldownUntil) { this.armed = true; }
      result.state = this.armed ? 'ready' : 'center'; return result;
    }
    this.centerStart = 0;
    if (!this.armed || sample.time < this.cooldownUntil) { result.state = 'center'; return result; }
    const direction: number = this.filtered >= this.threshold ? 1 : this.filtered <= -this.threshold ? -1 : 0;
    if (direction === 0) { this.candidate = 0; this.candidateStart = 0; result.state = 'ready'; return result; }
    if (direction !== this.candidate) { this.candidate = direction; this.candidateStart = sample.time; }
    result.direction = direction; result.state = direction > 0 ? 'down' : 'up';
    result.progress = Math.min(1, (sample.time - this.candidateStart) / this.dwell);
    if (result.progress >= 1) {
      result.action = direction; this.cooldownUntil = sample.time + 900;
      this.disarm(); result.state = 'center'; result.progress = 0;
    }
    return result;
  }
}
