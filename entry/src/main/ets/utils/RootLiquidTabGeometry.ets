export class LiquidTabTarget {
  page: number = 0;
  visibleIndex: number = 0;
  x: number = 0;
  y: number = 0;
  width: number = 0;
  height: number = 0;
}

export class RootLiquidTabGeometry {
  static width(slotWidth: number, showLabel: boolean, labeledWidth: number,
    compactWidth: number, overhang: number): number {
    return Math.max(1, Math.min(slotWidth + overhang, showLabel ? labeledWidth : compactWidth));
  }

  static nearest(targets: LiquidTabTarget[], x: number): number {
    let nearest: number = -1;
    let distance: number = Number.MAX_VALUE;
    for (let index: number = 0; index < targets.length; index++) {
      const next: number = Math.abs(targets[index].x - x);
      if (next < distance) {
        distance = next;
        nearest = index;
      }
    }
    return nearest;
  }

  static rubberBand(targets: LiquidTabTarget[], x: number): number {
    if (targets.length === 0) { return x; }
    let min: number = targets[0].x;
    let max: number = min;
    for (let index: number = 1; index < targets.length; index++) {
      min = Math.min(min, targets[index].x);
      max = Math.max(max, targets[index].x);
    }
    if (x < min) { return min + (x - min) * 0.25; }
    if (x > max) { return max + (x - max) * 0.25; }
    return x;
  }
}
