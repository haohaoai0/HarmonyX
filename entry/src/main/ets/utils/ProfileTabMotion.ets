// Geometry shared by the tab labels, hit areas and indicator during a native Swiper transition.
export class ProfileTabMotion {
  private static readonly count: number = 5;
  private static readonly expansion: number = 0.5;

  static clamp(position: number, count: number = ProfileTabMotion.count): number {
    return isFinite(position) ? Math.max(0, Math.min(count - 1, position)) : 0;
  }

  static scrollPosition(index: number, pageOffset: number, count: number = ProfileTabMotion.count): number {
    return ProfileTabMotion.clamp(index - pageOffset, count);
  }

  static fraction(index: number, position: number, count: number = ProfileTabMotion.count): number {
    return Math.max(0, 1 - Math.abs(ProfileTabMotion.clamp(position, count) - index));
  }

  static baseWidth(width: number, count: number = ProfileTabMotion.count,
    expansion: number = ProfileTabMotion.expansion): number {
    return Math.max(0, width) / (Math.max(1, count) + expansion);
  }

  static expandedWidth(width: number, count: number = ProfileTabMotion.count,
    expansion: number = ProfileTabMotion.expansion): number {
    return ProfileTabMotion.baseWidth(width, count, expansion) * (1 + expansion);
  }

  static slotWidth(index: number, position: number, width: number, count: number = ProfileTabMotion.count,
    expansion: number = ProfileTabMotion.expansion): number {
    return ProfileTabMotion.baseWidth(width, count, expansion) *
      (1 + expansion * ProfileTabMotion.fraction(index, position, count));
  }

  static slotStart(index: number, position: number, width: number, count: number = ProfileTabMotion.count,
    expansion: number = ProfileTabMotion.expansion): number {
    let start: number = 0;
    for (let i: number = 0; i < index; i++) {
      start += ProfileTabMotion.slotWidth(i, position, width, count, expansion);
    }
    return start;
  }

  static center(index: number, position: number, width: number, count: number = ProfileTabMotion.count,
    expansion: number = ProfileTabMotion.expansion): number {
    return ProfileTabMotion.slotStart(index, position, width, count, expansion) +
      ProfileTabMotion.slotWidth(index, position, width, count, expansion) / 2;
  }

  static tabAt(x: number, position: number, width: number, count: number = ProfileTabMotion.count,
    expansion: number = ProfileTabMotion.expansion): number {
    for (let i: number = 0; i < count - 1; i++) {
      if (x < ProfileTabMotion.slotStart(i + 1, position, width, count, expansion)) {
        return i;
      }
    }
    return count - 1;
  }

  static indicatorWidth(width: number, count: number = ProfileTabMotion.count,
    expansion: number = ProfileTabMotion.expansion): number {
    return ProfileTabMotion.baseWidth(width, count, expansion) * 0.9;
  }

  static indicatorLeft(position: number, width: number, count: number = ProfileTabMotion.count,
    expansion: number = ProfileTabMotion.expansion): number {
    return ProfileTabMotion.baseWidth(width, count, expansion) * ProfileTabMotion.clamp(position, count) +
      (ProfileTabMotion.expandedWidth(width, count, expansion) - ProfileTabMotion.indicatorWidth(width, count, expansion)) / 2;
  }
}
