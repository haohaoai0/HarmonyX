import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { STORAGE_KEY_SYSTEM_EMOJI_ENABLED } from '../services/AppearanceStore';
import type { ProfileArticle } from '../models/Tweet';
import type { PostArticleRouteParam } from '../utils/PostArticleRoute';
import { ProxyMediaImage } from './ProxyMediaImage';
import { EmojiSpans } from './EmojiSpans';

@Component
export struct PostArticleCard {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp(STORAGE_KEY_SYSTEM_EMOJI_ENABLED) private systemEmojiEnabled: boolean = false;
  @Consume('pageStack') pageStack: NavPathStack;
  @Prop postId: string = '';
  @Prop article: ProfileArticle;
  @Prop accentColor: string = '#007DFF';
  build(): void {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Column({ space: 0 }) {
        if (this.article.coverUrl.length > 0) { ProxyMediaImage({ url: this.article.coverUrl, displayHeight: 160 }) }
        Column({ space: 8 }) {
          Text($r('app.string.card_article')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Caption_L')).fontColor(this.accentColor)
          Text() { EmojiSpans(this.getUIContext(), this.article.title, $r('sys.float.Subtitle_L'), this.systemEmojiEnabled) }.fontFamily(this.appFontFamily)
            .width('100%').fontSize($r('sys.float.Subtitle_L')).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary')).maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.article.previewText.length > 0) {
            Text() { EmojiSpans(this.getUIContext(), this.article.previewText, $r('sys.float.Body_M'), this.systemEmojiEnabled) }.fontFamily(this.appFontFamily)
              .width('100%').fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary'))
              .maxLines(4).textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          Text($r('app.string.card_article_read')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontWeight(FontWeight.Bold).fontColor(this.accentColor)
        }.width('100%').alignItems(HorizontalAlign.Start).padding(12)
      }.width('100%')
    }.width('100%').padding(0).borderRadius(16).clip(true).margin({ top: 8 }).backgroundColor($r('app.color.poll_option_surface'))
      .border({ width: 1, color: $r('app.color.divider') }).onClick((): void => {
        const param: PostArticleRouteParam = { postId: this.postId, article: this.article };
        this.pageStack.pushPath({ name: 'PostArticle', param: param });
      })
  }
}
