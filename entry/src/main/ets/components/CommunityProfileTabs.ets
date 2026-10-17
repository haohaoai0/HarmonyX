import { AnimatedIconTabs } from './AnimatedIconTabs';
import { pageSurfaceColor } from '../utils/ThemeColors';

@Component
export struct CommunityProfileTabs {
  @Prop selected: number = 0;
  @Prop tabPosition: number = 0;
  @Prop timelineLabel: Resource = $r('app.string.community_sort_trending');
  @StorageProp('harmonyx.display_mode') displayMode: string = '';
  @StorageProp('harmonyx.dark_surface') darkSurface: string = '';
  onSelect: (index: number) => void = (): void => {};
  onSort: () => void = (): void => {};

  private activate(index: number): void {
    if (index === 0 && this.selected === 0 && Math.abs(this.tabPosition) < 0.01) { this.onSort(); }
    else { this.onSelect(index); }
  }

  build(): void {
    AnimatedIconTabs({ items: [
      { key: 'timeline', label: this.timelineLabel, icon: $r('sys.symbol.doc_plaintext'), chevron: true },
      { key: 'media', label: $r('app.string.community_timeline_media'), icon: $r('sys.symbol.picture_2') },
      { key: 'about', label: $r('app.string.community_about_tab'), icon: $r('sys.symbol.info_circle') }
    ], selected: this.selected, tabPosition: this.tabPosition, showDivider: true,
      onSelect: (index: number): void => this.activate(index), onOptions: (): void => this.onSort() })
      .backgroundColor(pageSurfaceColor(this.displayMode, this.darkSurface))
  }
}
