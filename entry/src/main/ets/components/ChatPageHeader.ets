import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { common } from '@kit.AbilityKit';

@Component
export struct ChatPageHeader {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Prop title: ResourceStr = '';
  @Prop subtitle: string = '';
  @Prop action: ResourceStr = '';
  @Prop actionSymbol: Resource | undefined = undefined;
  @Prop actionEnabled: boolean = true;
  @Prop cancelButton: boolean = false;
  @Prop centeredTitle: boolean = false;
  onBack: () => void = (): void => {};
  onAction: () => void = (): void => {};
  private actionLabel(): string {
    return typeof this.action === 'string' ? this.action as string :
      (getContext(this) as common.UIAbilityContext).resourceManager.getStringSync(this.action as Resource);
  }
  build(): void {
    Row({ space: 16 }) {
      Button({ type: ButtonType.Normal }) {
        if (this.cancelButton) { Text($r('app.string.compose_cancel')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_primary')) }
        else { SymbolGlyph($r('sys.symbol.arrow_left')).fontSize(24).fontColor([$r('app.color.text_primary')]) }
      }.width(this.cancelButton ? 64 : 40).height(40).padding(8).backgroundColor(Color.Transparent)
        .accessibilityText($r('app.string.common_back')).onClick((): void => this.onBack())
      Column({ space: 2 }) {
        Text(this.title).fontFamily(this.appFontFamily).fontSize($r('sys.float.Title_M')).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary')).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.subtitle.length > 0) {
          Text(this.subtitle).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary')).maxLines(1)
        }
      }.alignItems(this.centeredTitle ? HorizontalAlign.Center : HorizontalAlign.Start).layoutWeight(1)
      if (this.action !== '') {
        Button({ type: ButtonType.Normal }) {
          if (this.actionSymbol !== undefined) {
            SymbolGlyph(this.actionSymbol).fontSize(24).fontColor([$r('app.color.text_primary')])
          } else { Text(this.action).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_primary')) }
        }
          .backgroundColor(Color.Transparent).enabled(this.actionEnabled)
          .accessibilityText(this.actionLabel())
          .onClick((): void => this.onAction())
      } else if (this.centeredTitle) {
        Column().width(this.cancelButton ? 64 : 40).height(40)
      }
    }.width('100%').height($r('app.float.chat_header_height')).padding({ left: 8, right: 12 })
      .border({ width: { bottom: 0.5 }, color: $r('app.color.divider') })
  }
}
