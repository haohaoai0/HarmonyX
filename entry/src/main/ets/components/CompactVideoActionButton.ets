import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { hapticTick } from '../utils/Haptics';

// Flexible cells keep long counts within the cover screen's horizontal strip.
@Component
export struct CompactVideoActionButton {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Prop icon: Resource = $r('sys.symbol.heart');
  @Prop label: Resource = $r('app.string.action_like');
  @Prop value: string = '';
  @Prop selected: boolean = false;
  @Prop pending: boolean = false;
  @Prop pill: boolean = false;
  @Prop selectedColor: ResourceColor = $r('app.color.like');
  onAction: () => void = (): void => {};

  build(): void {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: $r('app.float.compact_video_bottom_gap') }) {
        if (this.pending) {
          LoadingProgress().width($r('app.float.compact_video_bottom_icon'))
            .height($r('app.float.compact_video_bottom_icon')).color($r('app.color.text_on_brand'))
        } else {
          SymbolGlyph(this.icon).fontSize($r('app.float.compact_video_bottom_icon'))
            .fontColor([this.selected ? this.selectedColor : $r('app.color.text_on_brand')])
        }
        if (this.value.length > 0) {
          Text(this.value).fontFamily(this.appFontFamily).fontSize($r('app.float.compact_video_count_font'))
            .fontColor(this.selected ? this.selectedColor : $r('app.color.text_on_brand'))
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).maxFontScale(1)
            .layoutWeight(1)
        }
      }.width('100%').justifyContent(FlexAlign.Center)
    }.width('100%').height($r('app.float.compact_video_bottom_action_height'))
      .padding({ left: $r('app.float.compact_video_bottom_gap'), right: $r('app.float.compact_video_bottom_gap') })
      .borderRadius($r('app.float.compact_video_bottom_radius'))
      .backgroundColor(this.pill ? $r('app.color.video_episode_surface') : Color.Transparent)
      .enabled(!this.pending).opacity(this.pending ? 0.6 : 1)
      .accessibilityText(this.label)
      .onClick((): void => { hapticTick(); this.onAction(); }).monopolizeEvents(true)
  }
}
