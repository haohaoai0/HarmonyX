import { pageTextColor } from '../utils/ThemeColors';
import { inboxRowSurfaceColor } from '../utils/ThemeColors';
// Inbox content remains a normal full-width row; only its surface is derived
// from the displayed avatar. Actions and the context menu stay on the parent.
import { hdsEffect } from '@kit.UIDesignKit';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import type { DirectMessage } from '../models/Tweet';
import { ProxyAvatar } from './ProxyAvatar';
import { STORAGE_KEY_AVATAR_TINT_ENABLED } from '../services/AppearanceStore';
import { AvatarTintPalette, avatarTintIsDark, avatarTintSurface } from '../utils/AvatarTintColors';
import { chatRelativeTime } from '../utils/ChatTime';

@Component
export struct ConversationInboxRow {
  @StorageProp('harmonyx.page_background') private pageBackgroundValue: string = '';
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Prop message: DirectMessage;
  @Prop separatorWidth: number = 0.5;
  @Prop selected: boolean = false;
  @StorageProp('harmonyx.display_mode') private displayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private darkSurface: string = '';
  @StorageProp('harmonyx.accent_color') private accentColor: string = '#007DFF';
  @StorageProp(STORAGE_KEY_AVATAR_TINT_ENABLED) private avatarTintEnabled: boolean = false;
  @State private palette: AvatarTintPalette | null = null;
  @State private themeDark: boolean = false;

  onWillApplyTheme(theme: Theme): void {
    this.themeDark = avatarTintIsDark(theme);
  }

  private readingText(color: ResourceColor): ResourceColor {
    return pageTextColor(color, this.pageBackgroundValue, inboxRowSurfaceColor(this.selected ? $r('app.color.bg_field') :
        avatarTintSurface(this.palette, this.message.avatarUrl ?? '', this.avatarTintEnabled,
          this.displayMode, this.darkSurface, this.themeDark), this.pageBackgroundValue));
  }

  build(): void {
    Column() {
      Row({ space: 16 }) {
        ProxyAvatar({verifiedType: this.message.verifiedType ?? '', avatarShape: this.message.avatarShape ?? '',  url: this.message.avatarUrl ?? '', avatarSize: 56,
          radius: this.message.group === true ? 18 : 28,
          fallbackText: this.message.from.substring(0, 1).toUpperCase(), tintBackground: true,
          onTintResolved: (palette: AvatarTintPalette | null): void => { this.palette = palette; } })
        Column({ space: 5 }) {
          Row({ space: 8 }) {
            Text(this.message.from).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L'))
              .fontWeight(this.message.unread > 0 ? FontWeight.Bold : FontWeight.Medium)
              .fontColor(this.readingText($r('app.color.text_primary'))).maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
            if (this.message.pinned === true) {
              SymbolGlyph($r('sys.symbol.pin')).fontSize(14).fontColor([this.readingText($r('app.color.text_secondary'))])
            }
            Text(chatRelativeTime(this.message.timestampMs ?? 0, this.message.time)).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_S')).fontColor(this.readingText($r('app.color.text_secondary'))).maxLines(1)
          }.width('100%')
          Row({ space: 8 }) {
            Text(this.message.preview.length > 0 ? this.message.preview : $r('app.string.dm_encrypted_preview')).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_M')).fontColor(this.readingText($r('app.color.text_secondary'))).maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
            if (this.message.unread > 0) { Circle().width(8).height(8).fill(this.accentColor) }
          }.width('100%')
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      }.width('100%').constraintSize({ minHeight: $r('app.float.chat_row_height') })
        .padding({ top: $r('app.float.chat_row_vertical_padding'), bottom: $r('app.float.chat_row_vertical_padding') })
      Row() {
        Blank().width($r('app.float.chat_row_text_inset'))
        Divider().layoutWeight(1).strokeWidth(this.separatorWidth).color($r('app.color.divider'))
      }.width('100%').height($r('app.float.chat_row_separator_width')).hitTestBehavior(HitTestMode.None)
    }.width('100%')
      .backgroundColor(inboxRowSurfaceColor(this.selected ? $r('app.color.bg_field') :
        avatarTintSurface(this.palette, this.message.avatarUrl ?? '', this.avatarTintEnabled,
          this.displayMode, this.darkSurface, this.themeDark), this.pageBackgroundValue))
      .borderRadius(this.selected ? 16 : 0)
      .border({ width: this.selected ? 1 : 0, color: this.accentColor })
      .visualEffect(new hdsEffect.HdsEffectBuilder()
        .pointLight({
          illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
        })
        .buildEffect())
  }
}
