import { ComponentHdrHighlight } from '../utils/ComponentHdrHighlight';
import { DEFAULT_COMPONENT_HDR_ENABLED, DEFAULT_COMPONENT_HDR_RATIO, STORAGE_KEY_COMPONENT_HDR_ENABLED, STORAGE_KEY_COMPONENT_HDR_RATIO } from '../services/ComponentHdrSettingsStore';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { DEFAULT_POST_ACTIONS_MASK, STORAGE_KEY_POST_ACTIONS_MASK, STORAGE_KEY_POST_ACTION_COUNTS } from '../services/PostDisplaySettingsStore';
import { STORAGE_KEY_POST_COUNT_FORMAT } from '../services/PostDisplaySettingsStore';
import { formatPostCount } from '../utils/PostCountFormat';
import { pageTextColor } from '../utils/ThemeColors';

@Component
export struct PostActionBar {
  @StorageProp(STORAGE_KEY_COMPONENT_HDR_ENABLED) private componentHdrEnabled: boolean = DEFAULT_COMPONENT_HDR_ENABLED;
  @StorageProp(STORAGE_KEY_COMPONENT_HDR_RATIO) private componentHdrRatio: number = DEFAULT_COMPONENT_HDR_RATIO;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp('harmonyx.font_scale') private fontScale: number = 1;
  @StorageProp(STORAGE_KEY_POST_ACTIONS_MASK) private actionsMask: number = DEFAULT_POST_ACTIONS_MASK;
  @StorageProp(STORAGE_KEY_POST_ACTION_COUNTS) private countsVisible: boolean = true;
  @StorageProp(STORAGE_KEY_POST_COUNT_FORMAT) private countFormat: number = 0;
  @StorageProp('harmonyx.page_background') private pageBackgroundValue: string = '';
  @Prop surface: ResourceColor = Color.Transparent;
  @Prop transparentBackground: boolean = false;
  @Prop detail: boolean = false;
  @Prop readOnly: boolean = false;
  @Prop replyCount: number = 0;
  @Prop repostCount: number = 0;
  @Prop likeCount: number = 0;
  @Prop viewCount: number = 0;
  @Prop bookmarkCount: number = -1;
  @Prop likeScale: number = 1;
  @Prop repostRotation: number = 0;
  @Prop bookmarkScale: number = 1;
  @Prop liked: boolean = false;
  @Prop reposted: boolean = false;
  @Prop bookmarked: boolean = false;
  @Prop translationEnabled: boolean = false;
  @Prop translating: boolean = false;
  @Prop translated: boolean = false;
  @Prop accentColor: string = '#007DFF';
  onReply: () => void = (): void => {};
  onRepost: () => void = (): void => {};
  onLike: () => void = (): void => {};
  onBookmark: () => void = (): void => {};
  onShare: () => void = (): void => {};
  onTranslate: () => void = (): void => {};

  private ids(): number[] {
    const ids: number[] = this.detail ? [1, 2, 4, 16, 32] : [1, 2, 4, 8, 16, 32];
    if (this.translationEnabled && !this.readOnly) { ids.push(64); }
    return ids.filter((id: number): boolean => (this.actionsMask & id) !== 0 &&
      (!this.readOnly || id <= 8));
  }

  private count(id: number): number {
    if (id === 1) { return this.replyCount; }
    if (id === 2) { return this.repostCount; }
    if (id === 4) { return this.likeCount; }
    if (id === 8) { return this.viewCount; }
    return id === 16 && this.detail ? this.bookmarkCount : -1;
  }

  private icon(id: number): Resource {
    if (id === 1) { return $r('sys.symbol.ellipsis_bubble'); }
    if (id === 2) { return $r('sys.symbol.repeat'); }
    if (id === 4) { return this.liked ? $r('sys.symbol.heart_fill') : $r('sys.symbol.heart'); }
    if (id === 8) { return $r('sys.symbol.eye'); }
    if (id === 16) { return this.bookmarked ? $r('sys.symbol.bookmark_fill') : $r('sys.symbol.bookmark'); }
    return id === 32 ? $r('sys.symbol.share') : $r('sys.symbol.translate');
  }

  private label(id: number): Resource {
    if (id === 1) { return $r('app.string.action_reply'); }
    if (id === 2) { return $r('app.string.action_repost'); }
    if (id === 4) { return $r('app.string.action_like'); }
    if (id === 8) { return $r('app.string.post_detail_views'); }
    if (id === 16) { return $r('app.string.action_bookmark'); }
    if (id === 32) { return $r('app.string.action_share'); }
    return this.translated ? $r('app.string.post_hide_translation') : $r('app.string.post_translate');
  }

  private color(id: number, minimum: number = 4.6): ResourceColor {
    let color: ResourceColor = $r('app.color.text_secondary');
    if (id === 4 && this.liked) { color = $r('app.color.like'); }
    if (id === 2 && this.reposted) { color = $r('app.color.repost'); }
    if ((id === 16 && this.bookmarked) || (id === 64 && this.translated)) { color = this.accentColor; }
    return pageTextColor(color, this.transparentBackground ? '' : this.pageBackgroundValue, this.surface, minimum, true);
  }

  private showsCount(id: number): boolean { return this.countsVisible && this.count(id) > 0; }

  private statisticIds(): number[] {
    return this.ids().filter((id: number): boolean => this.isCountedAction(id));
  }

  private trailingIds(): number[] {
    return this.ids().filter((id: number): boolean => !this.isCountedAction(id));
  }

  private isCountedAction(id: number): boolean {
    // X keeps reply/repost/like/views in counted slots even at zero. A missing
    // bookmark count is different from an available count whose value is zero.
    return id <= 8 || id === 16 && this.detail && this.countsVisible && this.bookmarkCount >= 0;
  }

  private measuredActionWidths: Map<string, number> = new Map<string, number>();

  private actionIconWidth(): number {
    const icon: Resource = this.detail ? $r('app.float.post_detail_action_icon') : $r('app.float.post_action_icon');
    const pixels: number = this.getUIContext().getHostContext()?.resourceManager.getNumber(icon.id) ??
      this.getUIContext().fp2px(this.detail ? 23 : 19);
    return this.getUIContext().px2vp(pixels);
  }

  private minimumWidth(id: number): number {
    const counted: boolean = this.showsCount(id);
    const text: string = counted ? formatPostCount(this.count(id), this.countFormat) : '';
    const key: string = this.appFontFamily + ':' + this.detail.toString() + ':' + this.fontScale.toString() + ':' +
      this.getUIContext().fp2px(1).toString() + ':' + text;
    const cached: number | undefined = this.measuredActionWidths.get(key);
    if (cached !== undefined) { return cached; }
    const iconWidth: number = this.actionIconWidth();
    let width: number = Math.max(36, Math.ceil(iconWidth + 8));
    if (counted) {
      const textWidth: number = this.getUIContext().px2vp(this.getUIContext().getMeasureUtils().measureText({
        textContent: text, fontFamily: this.appFontFamily,
        fontSize: this.detail ? $r('app.float.post_detail_action_text') : $r('app.float.post_action_text')
      }));
      width = Math.max(36, Math.ceil(iconWidth + 4 + textWidth + 8));
    }
    if (this.measuredActionWidths.size >= 16) { this.measuredActionWidths.clear(); }
    this.measuredActionWidths.set(key, width);
    return width;
  }

  private minimumContentWidth(): number {
    const statistics: number[] = this.statisticIds();
    const trailing: number[] = this.trailingIds();
    let width: number = Math.max(0, statistics.length + trailing.length - 1) * 8;
    let widest: number = 0;
    for (let index: number = 0; index < statistics.length; index++) {
      widest = Math.max(widest, this.minimumWidth(statistics[index]));
    }
    width += widest * statistics.length;
    for (let index: number = 0; index < trailing.length; index++) { width += this.minimumWidth(trailing[index]); }
    return width;
  }

  private contentWidth(): number {
    // The first render precedes onAreaChange. Keep counts measurable until the
    // real pane width arrives instead of giving counted buttons zero width.
    return this.availableWidth > 0 ? this.availableWidth : this.minimumContentWidth();
  }

  private statisticWidth(id: number): number {
    if (this.packedActions()) { return Math.min(this.contentWidth(), this.packedWidth(id)); }
    // com.x.inlineactionbar.l: reserve intrinsic icon widths, subtract every
    // 8dp gap, then give each counted action the same remaining width.
    const count: number = this.statisticIds().length;
    let fixed: number = Math.max(0, this.ids().length - 1) * 8;
    const trailing: number[] = this.trailingIds();
    for (let index: number = 0; index < trailing.length; index++) { fixed += this.minimumWidth(trailing[index]); }
    return count > 0 ? Math.max(0, this.contentWidth() - fixed) / count : 0;
  }

  private packedActions(): boolean {
    return this.availableWidth > 0 && this.availableWidth < this.minimumContentWidth();
  }

  private packedWidth(id: number): number {
    // The official packed slot adds a 32dp/48dp touch allowance to the icon.
    // Apply the threshold to the actual card pane, including multi-column feeds.
    return this.isCountedAction(id) ? Math.max(this.minimumWidth(id),
      this.actionIconWidth() + (this.availableWidth < 376 ? 32 : 48)) :
      this.minimumWidth(id);
  }

  private visibleIds(): number[] {
    const ids: number[] = this.ids();
    if (!this.packedActions()) { return ids; }
    // Reserve the user-enabled translation action before packing the remaining
    // slots. Otherwise long counts can permanently hide its only quick entry.
    const priority: number[] = ids.filter((id: number): boolean => id !== 8 && id !== 64);
    if (ids.indexOf(8) >= 0) { priority.push(8); }
    const selected: number[] = ids.indexOf(64) >= 0 ? [64] : [];
    let occupied: number = selected.length > 0 ? this.packedWidth(64) : 0;
    for (let index: number = 0; index < priority.length; index++) {
      const width: number = this.packedWidth(priority[index]);
      const gap: number = selected.length > 0 ? this.minimumActionGap() : 0;
      if (selected.length > 0 && occupied + gap + width > this.contentWidth()) { continue; }
      selected.push(priority[index]);
      occupied += gap + width;
    }
    return ids.filter((id: number): boolean => selected.indexOf(id) >= 0);
  }

  private minimumActionGap(): number {
    return this.packedActions() && this.availableWidth < 376 ? 0 : 8;
  }

  private actionSpacing(): number {
    if (!this.packedActions()) { return 8; }
    const ids: number[] = this.visibleIds();
    if (ids.length < 2) { return 0; }
    let occupied: number = 0;
    for (let index: number = 0; index < ids.length; index++) { occupied += this.packedWidth(ids[index]); }
    return Math.max(this.minimumActionGap(), Math.min(35, (this.contentWidth() - occupied) / (ids.length - 1)));
  }

  private actionWidth(id: number): number {
    if (this.packedActions()) { return Math.min(this.contentWidth(), this.packedWidth(id)); }
    return this.isCountedAction(id) ? this.statisticWidth(id) : this.minimumWidth(id);
  }

  @State private availableWidth: number = 0;

  private activate(id: number): void {
    if (this.readOnly || id === 8) { return; }
    if (id === 1) { this.onReply(); }
    else if (id === 2) { this.onRepost(); }
    else if (id === 4) { this.onLike(); }
    else if (id === 16) { this.onBookmark(); }
    else if (id === 32) { this.onShare(); }
    else { this.onTranslate(); }
  }

  @Builder
  private Action(id: number): void {
    Button({ type: ButtonType.Normal, stateEffect: !this.readOnly && id !== 8 }) {
      Row({ space: 4 }) {
        if (id === 64 && this.translating) { LoadingProgress().width(18).height(18).color(this.accentColor) }
        else {
          SymbolGlyph(this.icon(id)).fontSize(this.detail ? $r('app.float.post_detail_action_icon') : $r('app.float.post_action_icon'))
            .fontColor([this.color(id, 3)]).accessibilityLevel('no')
            .flexShrink(0)
            .scale({ x: id === 4 ? this.likeScale : id === 16 ? this.bookmarkScale : 1,
              y: id === 4 ? this.likeScale : id === 16 ? this.bookmarkScale : 1 })
            .rotate({ angle: id === 2 ? this.repostRotation : 0 })
            .foregroundFilter(ComponentHdrHighlight.filter(this.getUIContext(), this.componentHdrEnabled &&
              ((id === 4 && this.liked) || (id === 2 && this.reposted) || (id === 16 && this.bookmarked)), this.componentHdrRatio))
        }
        if (this.showsCount(id)) {
          Text(formatPostCount(this.count(id), this.countFormat)).fontFamily(this.appFontFamily)
            .fontSize(this.detail ? $r('app.float.post_detail_action_text') : $r('app.float.post_action_text'))
            .fontColor(this.color(id)).flexShrink(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }.width('100%').justifyContent(this.isCountedAction(id) ? FlexAlign.Start : FlexAlign.Center)
    }.padding({ left: 4, right: 4 }).height($r('app.float.post_action_hit_height')).backgroundColor(Color.Transparent)
      // Read reactive state inside the component update. A numeric @Builder
      // argument is captured when ForEach creates a key and then stays stale.
      .width(this.actionWidth(id)).flexShrink(0)
      .accessibilityText(this.label(id)).id('post-action-' + id.toString())
      .onClick((): void => this.activate(id))
  }

  build(): void {
    if (this.ids().length > 0) {
      Row({ space: this.actionSpacing() }) {
        ForEach(this.visibleIds(), (id: number) => {
          this.Action(id)
        }, (id: number): string => id.toString())
      }.width('100%').height($r('app.float.post_action_hit_height'))
        .justifyContent(FlexAlign.Start)
        .onAreaChange((_old: Area, area: Area): void => {
          const width: number = Number(area.width);
          if (width > 0 && Math.abs(width - this.availableWidth) > 1) { this.availableWidth = width; }
        })
        .onClick((): void => {})
    }
  }
}
