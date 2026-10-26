import { common } from '@kit.AbilityKit';
import { SymbolGlyphModifier, UIContext } from '@kit.ArkUI';
import { copyPostLink } from '../utils/PostLinkCopy';
import { openExternalLink } from '../utils/PostEntities';

// The containing Text owns bindMenu; Span only selects the tapped destination.
@Builder
export function PostLinkMenu(context: UIContext, url: string): void {
  Menu() {
    MenuItem({ content: $r('app.string.post_link_copy'),
      symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.plus_square_on_square')) })
      .onClick((): void => {
        void copyPostLink(context, url);
      })
    MenuItem({ content: $r('app.string.post_link_open'),
      symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.link')) })
      .onClick((): void => {
        openExternalLink(context.getHostContext() as common.UIAbilityContext, url);
      })
  }
}
