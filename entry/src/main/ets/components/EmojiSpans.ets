import { common } from '@kit.AbilityKit';
import { UIContext } from '@kit.ArkUI';
import { ChatEmojiSegment, chatEmojiImages } from '../services/ChatEmojiImages';

export interface EmojiSpanStyle {
  weight: FontWeight;
  fontStyle: FontStyle;
  family: string;
  decoration: TextDecorationType;
  color: ResourceColor;
}

function emojiImageSize(context: UIContext, size: number | Resource): number {
  if (typeof size === 'number') { return context.px2vp(context.fp2px(size)); }
  const host: common.UIAbilityContext = context.getHostContext() as common.UIAbilityContext;
  return context.px2vp(host.resourceManager.getNumber((size as Resource).id));
}

function emojiText(context: UIContext, text: ResourceStr): string {
  if (typeof text === 'string') { return text; }
  return (context.getHostContext() as common.UIAbilityContext).resourceManager.getStringSync(text);
}

// Keep the caller's Text font, layout, selection and entity click behavior.
@Builder
export function EmojiSpans(context: UIContext, text: ResourceStr, size: number | Resource,
  systemEmojiEnabled: boolean, onEntityClick?: () => void,
  entityColor: ResourceColor = $r('app.color.text_accent'), textStyle?: EmojiSpanStyle): void {
  ForEach(chatEmojiImages.split(context.getHostContext() as common.UIAbilityContext, emojiText(context, text), systemEmojiEnabled), (segment: ChatEmojiSegment) => {
    if (segment.file.length > 0) {
      if (onEntityClick !== undefined) {
        ImageSpan($rawfile(segment.file)).width(emojiImageSize(context, size)).height(emojiImageSize(context, size))
          .verticalAlign(ImageSpanAlignment.CENTER).objectFit(ImageFit.Contain).onClick(onEntityClick)
      } else {
        ImageSpan($rawfile(segment.file)).width(emojiImageSize(context, size)).height(emojiImageSize(context, size))
          .verticalAlign(ImageSpanAlignment.CENTER).objectFit(ImageFit.Contain)
      }
    } else if (textStyle !== undefined) {
      Span(segment.text).fontWeight(textStyle.weight).fontStyle(textStyle.fontStyle).fontFamily(textStyle.family)
        .decoration({ type: textStyle.decoration }).fontColor(textStyle.color)
        .onClick((): void => { if (onEntityClick !== undefined) { onEntityClick(); } })
    } else if (onEntityClick !== undefined) {
      Span(segment.text).fontColor(entityColor).onClick(onEntityClick)
    } else {
      Span(segment.text)
    }
  }, (segment: ChatEmojiSegment, index: number): string => index.toString() + ':' + segment.file + ':' + segment.text)
}
