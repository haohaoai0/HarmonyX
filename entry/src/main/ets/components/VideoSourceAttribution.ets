import type { MediaAttachment } from '../models/Tweet';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { verificationBadgeColor } from '../utils/UserIdentity';
import { ProxyAvatar } from './ProxyAvatar';

@Component
export struct VideoSourceAttribution {
  @Prop media: MediaAttachment;
  @Prop postId: string = '';
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  onOpen: (postId: string) => void = (): void => {};

  build(): void {
    if ((this.media.sourcePostId ?? '').length > 0 && this.media.sourcePostId !== this.postId) {
      Row({ space: 4 }) {
        Text($r('app.string.video_source_from')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_S')).fontColor($r('app.color.text_on_brand'))
        if (this.media.sourceAuthor != null) {
          ProxyAvatar({ url: this.media.sourceAuthor.avatarUrl ?? '', avatarSize: 16, radius: 8,
            fallbackText: this.media.sourceAuthor.name.substring(0, 1),
            fallbackColor: this.media.sourceAuthor.avatarColor })
        }
        Text(this.media.sourceAuthor?.name ?? $r('app.string.video_source_original'))
          .fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S'))
          .fontColor($r('app.color.text_on_brand')).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.media.sourceAuthor?.verified === true) {
          SymbolGlyph($r('sys.symbol.checkmark_circle_fill')).fontSize(12)
            .fontColor([verificationBadgeColor(this.media.sourceAuthor.verifiedType ?? '', '#1D9BF0')])
        }
      }
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      .borderRadius(12).backgroundColor($r('app.color.media_viewer_control'))
      .id('video-source-attribution').monopolizeEvents(true)
      .onClick((): void => this.onOpen(this.media.sourcePostId ?? ''))
    }
  }
}
