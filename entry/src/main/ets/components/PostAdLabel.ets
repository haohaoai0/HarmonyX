import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import type { PostPresentation } from '../models/PostContent';
import { isAdPost } from '../utils/PostDisclosure';

@Component
export struct PostAdLabel {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Prop presentation: PostPresentation | undefined = undefined;
  build(): void {
    if (isAdPost(this.presentation)) {
      Text($r('app.string.post_ad_label')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary'))
        .maxLines(1).flexShrink(0).accessibilityText($r('app.string.card_ad'))
    }
  }
}
