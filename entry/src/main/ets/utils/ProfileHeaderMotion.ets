// The header uses measured layout anchors and render transforms. Scroll changes
// never resize the hero or title slots, so the List keeps a stable layout.
export class ProfileHeaderAnchor {
  x: number = 0;
  y: number = 0;
  width: number = 0;
  height: number = 0;

  constructor(x: number = 0, y: number = 0, width: number = 0, height: number = 0) {
    this.x = x;
    this.y = y;
    this.width = width;
    this.height = height;
  }
}

export class ProfileHeaderMotion {
  static progress(value: number, start: number, end: number): number {
    if (!isFinite(value) || !isFinite(start) || !isFinite(end) || end <= start) {
      return 0;
    }
    const fraction: number = Math.max(0, Math.min(1, (value - start) / (end - start)));
    return fraction * fraction * (3 - 2 * fraction);
  }

  static interpolate(start: number, end: number, progress: number): number {
    return start + (end - start) * Math.max(0, Math.min(1, progress));
  }

  static sameAnchor(first: ProfileHeaderAnchor, second: ProfileHeaderAnchor): boolean {
    return Math.abs(first.x - second.x) < 0.5 && Math.abs(first.y - second.y) < 0.5 &&
      Math.abs(first.width - second.width) < 0.5 && Math.abs(first.height - second.height) < 0.5;
  }
}
