// Mobile title-bar slots and scroll avoidance share the same layout choice.
// Compact controls occupy the identity row; their former lower slots disappear.
const COMPACT_TITLE_BAR_EXTRA_HEIGHT_VP: number = 12;

export class RootTitleBarLayout {
  static measuredBottomHeight(contentHeight: number, titleHeight: number): number {
    return Math.max(0, contentHeight - titleHeight);
  }

  static bottomHeight(tab: number, logo: boolean, collapsed: boolean,
    spaceHeight: number, exploreHasQuery: boolean, exploreCategoryGap: number = 4): number {
    const extra: number = logo ? 0 : COMPACT_TITLE_BAR_EXTRA_HEIGHT_VP;
    // Match the visible Home tab row so its bottom-aligned indicator remains
    // inside the title-bar surface instead of extending past that boundary.
    if (tab === 0) { return (logo ? (collapsed ? 12 : 54) : 0) + spaceHeight + extra; }
    if (tab === 1) { return (exploreHasQuery ? 0 : (logo ? 96 + exploreCategoryGap : 52)) + extra; }
    if (tab === 2) { return logo ? 52 : extra; }
    if (tab === 3) { return logo ? 56 : extra; }
    return extra;
  }

  static labelsHeight(tab: number, logo: boolean, spaceHeight: number,
    exploreHasQuery: boolean, exploreCategoryGap: number = 4): number {
    if (tab === 0) { return (logo ? 54 : 0) + spaceHeight; }
    if (tab === 1 && !exploreHasQuery) { return logo ? 108 + exploreCategoryGap : 52; }
    if (tab === 2) { return logo ? 52 : 0; }
    return 0;
  }

  static labelsOffset(tab: number, logo: boolean): number {
    if (!logo) { return 76 + COMPACT_TITLE_BAR_EXTRA_HEIGHT_VP; }
    // Align the notification underline with the native lower slot's edge.
    if (tab === 2) { return 76; }
    return tab === 0 ? 72 : 69;
  }

  static contentTopInset(tab: number, logo: boolean, statusHeight: number,
    collapsed: boolean, spaceHeight: number, labelsClearance: number = 0, exploreCategoryGap: number = 4): number {
    const extra: number = logo ? 0 : COMPACT_TITLE_BAR_EXTRA_HEIGHT_VP;
    let inset: number = statusHeight + 64 + extra;
    if (tab === 0) { inset = statusHeight + (logo ? (collapsed ? 76 : 104) : 64) + spaceHeight + extra; }
    else if (tab === 1) { inset = logo ? 174 + exploreCategoryGap : 130 + extra; }
    else if (tab === 2) { inset = statusHeight + (logo ? 116 : 64) + extra; }
    else if (tab === 3) { inset = statusHeight + (logo ? 112 : 64) + extra; }
    const labelsHeight: number = RootTitleBarLayout.labelsHeight(tab, logo, spaceHeight, false, exploreCategoryGap);
    if (labelsClearance > 0 && labelsHeight > 0) {
      // Home's expanded labels overflow the native lower slot. Clear the
      // actual label edge, including its underline, rather than that slot.
      const collapseOffset: number = tab === 0 && logo && collapsed ? 58 : 0;
      const labelsBottom: number = (tab === 1 ? 0 : statusHeight) +
        RootTitleBarLayout.labelsOffset(tab, logo) + labelsHeight - collapseOffset;
      inset = Math.max(inset, labelsBottom + labelsClearance);
    }
    return inset;
  }
}
