import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { formatCount } from '../models/Tweet';

// Explicit props keep cached feed cells reactive to optimistic state, server
// rollback and pending completion instead of capturing builder arguments.
@Component
export struct VideoFeedActionButton {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Prop icon: Resource = $r('sys.symbol.heart');
  @Prop label: Resource = $r('app.string.action_like');
  @Prop count: number = 0;
  @Prop selected: boolean = false;
  @Prop pending: boolean = false;
  @Prop selectedColor: ResourceColor = $r('app.color.like');
  onAction: () => void = (): void => {};

  build(): void {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Column({ space: 2 }) {
        if (this.pending) {
          LoadingProgress().width(24).height(24)
            .color(this.selected ? this.selectedColor : $r('app.color.text_on_brand'))
        } else {
          SymbolGlyph(this.icon).fontSize(24)
            .fontColor([this.selected ? this.selectedColor : $r('app.color.text_on_brand')])
        }
        Text(this.count < 0 ? this.getUIContext().getHostContext()?.resourceManager.getStringSync(this.label) ?? '' :
          formatCount(this.count)).fontFamily(this.appFontFamily).fontSize(12).maxFontScale(1)
          .fontColor(this.selected ? this.selectedColor : $r('app.color.text_on_brand')).maxLines(1)
      }.width('100%').height('100%').justifyContent(FlexAlign.Center)
    }.width(42).height(48).padding(0).borderRadius(12).backgroundColor(Color.Transparent)
      .enabled(!this.pending).opacity(this.pending ? 0.65 : 1)
      .accessibilityText(this.label).onClick((): void => this.onAction()).monopolizeEvents(true)
  }
}
