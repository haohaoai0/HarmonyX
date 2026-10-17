import { common } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import hilog from '@ohos.hilog';
import { chatEmojiImages } from '../services/ChatEmojiImages';

export class EmojiCopyMenu implements EditMenuOptions {
  onMenuItemClick: (item: TextMenuItem, range: TextRange) => boolean =
    (_item: TextMenuItem, _range: TextRange): boolean => false;

  constructor(context: common.Context, text: string, systemEmojiEnabled: boolean = false) {
    // ArkUI invokes this callback without a class receiver. Capture immutable
    // inputs rather than relying on `this` in the native callback.
    this.onMenuItemClick = (item: TextMenuItem, range: TextRange): boolean => {
      if (item === undefined || item === null || range === undefined || range === null ||
        !item.id.equals(TextMenuItemId.COPY)) { return false; }
      const selected: string = selectedEmojiText(context, text, range, systemEmojiEnabled);
      if (selected.length === 0) { return false; }
      try {
        pasteboard.getSystemPasteboard().setDataSync(pasteboard.createPlainTextData(selected));
        return true;
      } catch {
        hilog.warn(0xFF00, 'HarmonyX-Emoji', 'Cannot copy selected post text');
        return false;
      }
    };
  }

  onCreateMenu(items: TextMenuItem[]): TextMenuItem[] { return items; }
}

function selectedEmojiText(context: common.Context, text: string, range: TextRange,
  systemEmojiEnabled: boolean): string {
    let start: number = range.start ?? 0;
    let end: number = range.end ?? text.length;
    if (start < 0) { start = 0; }
    if (end < 0) { end = 0; }
    if (end < start) {
      const previousStart: number = start;
      start = end;
      end = previousStart;
    }
    // ImageSpan occupies one selection position, regardless of Unicode length.
    return chatEmojiImages.selection(context, text, start, end, systemEmojiEnabled);
}
