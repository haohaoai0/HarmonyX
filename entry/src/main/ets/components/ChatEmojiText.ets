import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { STORAGE_KEY_SYSTEM_EMOJI_ENABLED } from '../services/AppearanceStore';
import { EmojiSpans } from './EmojiSpans';

@Component
export struct ChatEmojiText {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp(STORAGE_KEY_SYSTEM_EMOJI_ENABLED) private systemEmojiEnabled: boolean = false;
  @Prop text: string = '';
  @Prop fontSize: number | Resource = $r('sys.float.Body_L');
  @Prop fontColor: ResourceColor = $r('app.color.text_primary');
  @Prop maxLines: number = 2147483647;

  build(): void {
    Text() {
      EmojiSpans(this.getUIContext(), this.text, this.fontSize, this.systemEmojiEnabled)
    }.fontFamily(this.appFontFamily).fontSize(this.fontSize).fontColor(this.fontColor).textAlign(TextAlign.Start)
      .maxLines(this.maxLines).textOverflow({ overflow: TextOverflow.Ellipsis }).accessibilityText(this.text)
  }
}
