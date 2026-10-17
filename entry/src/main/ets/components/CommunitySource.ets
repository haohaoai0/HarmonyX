import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { openCommunitySource } from '../utils/CommunityNavigation';

@Component
export struct CommunitySource {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Consume('pageStack') pageStack: NavPathStack;
  @Prop communityId: string = '';
  @Prop communityName: string = '';
  @Prop inset: number = 0;

  build(): void {
    if (this.communityId.length > 0 && this.communityName.length > 0) {
      Row({ space: 6 }) {
        SymbolGlyph($r('sys.symbol.person_2_fill')).fontSize(14).fontColor([$r('app.color.text_secondary')])
        Text(this.communityName).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S')).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_secondary')).maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
        SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(10).fontColor([$r('app.color.text_secondary')])
      }.width('100%').padding({ left: this.inset, right: 12, top: 8, bottom: 2 })
        .accessibilityText(this.communityName)
        .onClick((): void => openCommunitySource(this.pageStack, this.communityId, this.communityName))
    }
  }
}
