import { common } from '@kit.AbilityKit';
import { UIContext } from '@kit.ArkUI';
import { MentionSegment, splitPostText } from '../utils/MentionText';
import { openExternalLink } from '../utils/PostEntities';
import { EmojiSpans } from './EmojiSpans';

// Translated prose keeps the same address labels and direct link targets as
// the original body, including when translation replaces the original text.
@Builder
export function PostLinkSpans(context: UIContext, text: string, size: number | Resource,
  systemEmojiEnabled: boolean, onLinkClick?: (url: string) => void): void {
  ForEach(splitPostText(text), (segment: MentionSegment) => {
    if (segment.url.length > 0) {
      EmojiSpans(context, segment.text, size, systemEmojiEnabled, (): void => {
        if (onLinkClick !== undefined) { onLinkClick(segment.url); }
        else { openExternalLink(context.getHostContext() as common.UIAbilityContext, segment.url); }
      })
    } else {
      EmojiSpans(context, segment.text, size, systemEmojiEnabled)
    }
  })
}
