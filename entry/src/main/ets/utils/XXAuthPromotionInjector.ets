import { XXAuthPromotionPost } from '../services/XXAuthPromotionPost';

// How far into a list a promotion may be placed. Near enough to the top that
// the reader actually meets it, and fixed, so paging in more rows never moves a
// row that is already on screen.
const SPREAD: number = 6;

export class XXAuthPromotionSlot {
  // Insert before this index in the host list; a value equal to its length appends.
  index: number = 0;
  post: XXAuthPromotionPost = new XXAuthPromotionPost();
}

export class XXAuthPromotionInjector {
  private static seed: number = 0;

  // One seed per app launch: a relaunch shuffles the positions, while a refresh
  // inside the same session keeps every row where the reader left it.
  static launchSeed(): number {
    if (XXAuthPromotionInjector.seed === 0) {
      XXAuthPromotionInjector.seed = Math.floor(Date.now() % 2147483647);
    }
    return XXAuthPromotionInjector.seed;
  }

  // Tests pin the seed so the rotation can be observed without relaunching.
  static resetLaunchSeedForTest(seed: number): void {
    XXAuthPromotionInjector.seed = seed;
  }

  private static hash(value: string): number {
    let result: number = 2166136261;
    for (let i: number = 0; i < value.length; i++) {
      result = result ^ value.charCodeAt(i);
      result = (result * 16777619) >>> 0;
    }
    return result >>> 0;
  }

  // Distinct ascending insertion points in [1, total]; position 0 stays free so
  // a promotion never becomes the first row of a fresh list.
  static positions(total: number, count: number, salt: string): number[] {
    const chosen: number[] = [];
    if (count <= 0) { return chosen; }
    if (total <= 0) { chosen.push(0); return chosen; }
    const span: number = Math.max(1, Math.min(total, SPREAD));
    for (let i: number = 0; i < count; i++) {
      const raw: number = XXAuthPromotionInjector.hash(salt + '#' + i.toString());
      let candidate: number = 1 + (raw % span);
      let guard: number = 0;
      while (chosen.indexOf(candidate) >= 0 && guard < span) {
        candidate = 1 + ((candidate) % span);
        guard++;
      }
      if (chosen.indexOf(candidate) < 0) { chosen.push(candidate); }
    }
    chosen.sort((left: number, right: number): number => left - right);
    // Two promotions never end up side by side: adjacent slots read as one
    // block of advertising instead of two separate rows in the feed.
    const spaced: number[] = [];
    for (let i: number = 0; i < chosen.length; i++) {
      if (spaced.length === 0) {
        if (chosen[i] <= span) { spaced.push(chosen[i]); }
        continue;
      }
      const previous: number = spaced[spaced.length - 1];
      const next: number = chosen[i] <= previous + 1 ? previous + 2 : chosen[i];
      if (next <= span) { spaced.push(next); }
    }
    return spaced;
  }

  // Cycles the configured posts so several slots in one list never repeat the
  // same content back to back.
  static slots(total: number, posts: XXAuthPromotionPost[], count: number,
    salt: string): XXAuthPromotionSlot[] {
    const slots: XXAuthPromotionSlot[] = [];
    if (posts.length === 0) { return slots; }
    const positions: number[] = XXAuthPromotionInjector.positions(total, count, salt);
    // The choice of which promoted app fills the slot is drawn per launch as
    // well, so a reader sees the pool alternate instead of one fixed app in the
    // same timeline forever. Inside one run it stays put.
    const offset: number = XXAuthPromotionInjector.hash(
      'offset:' + salt + ':' + XXAuthPromotionInjector.launchSeed().toString()) % posts.length;
    for (let i: number = 0; i < positions.length; i++) {
      const slot: XXAuthPromotionSlot = new XXAuthPromotionSlot();
      slot.index = positions[i];
      slot.post = posts[(offset + i) % posts.length];
      slots.push(slot);
    }
    return slots;
  }
}
