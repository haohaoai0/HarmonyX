import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { STORAGE_KEY_SYSTEM_EMOJI_ENABLED } from '../services/AppearanceStore';
import { ChatLinkSegment, splitChatLinks } from '../utils/ChatPostLinks';
import { EmojiSpans } from './EmojiSpans';

@Component
export struct ChatLinkText {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp(STORAGE_KEY_SYSTEM_EMOJI_ENABLED) private systemEmojiEnabled: boolean = false;
  @Prop text: string = '';
  @Prop fontSize: number | Resource = $r('sys.float.Body_L');
  @Prop fontColor: ResourceColor = $r('app.color.text_primary');
  @Prop linkColor: ResourceColor = $r('app.color.text_accent');
  onLink: (url: string) => void = (_url: string): void => {};

  build(): void {
    Text() {
      ForEach(splitChatLinks(this.text), (part: ChatLinkSegment) => {
        if (part.url.length > 0) {
          EmojiSpans(this.getUIContext(), part.text, this.fontSize, this.systemEmojiEnabled,
            (): void => { this.onLink(part.url); }, this.linkColor)
        } else {
          EmojiSpans(this.getUIContext(), part.text, this.fontSize, this.systemEmojiEnabled)
        }
      }, (part: ChatLinkSegment, index: number): string => index.toString() + ':' + part.text)
    }.fontFamily(this.appFontFamily).fontSize(this.fontSize).fontColor(this.fontColor)
      .textAlign(TextAlign.Start).accessibilityText(this.text)
  }
}
