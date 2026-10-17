import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { common } from '@kit.AbilityKit';
import type { ProfileArticle, TweetLinkCard, TweetPoll } from '../models/Tweet';
import type { PostPresentation } from '../models/PostContent';
import { openExternalLink } from '../utils/PostEntities';
import { PostPollCard } from './PostPollCard';
import { ProxyMediaImage } from './ProxyMediaImage';
import { SpacePostCard } from './SpacePostCard';
import { PostRichCard } from './PostRichCard';
import { PostArticleCard } from './PostArticleCard';
import { PostPresentationCard } from './PostPresentationCard';

// One entry for every post surface, including quoted posts and reply modules.
@Component
export struct PostInteractiveContent {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Prop postId: string = '';
  @Prop poll: TweetPoll | undefined = undefined;
  @Prop card: TweetLinkCard | undefined = undefined;
  @Prop article: ProfileArticle | undefined = undefined;
  @Prop presentation: PostPresentation | undefined = undefined;
  @Prop accentColor: string = '#007DFF';
  @Prop showPollMedia: boolean = true;

  private cardTitle(): ResourceStr {
    if (this.card !== undefined && this.card.title.length > 0) { return this.card.title; }
    if (this.card?.kind === 'space') { return $r('app.string.post_card_space'); }
    if (this.card?.kind === 'broadcast') { return $r('app.string.post_card_broadcast'); }
    if (this.card?.kind === 'event') { return $r('app.string.post_card_event'); }
    return $r('app.string.post_card_open');
  }

  build(): void {
    Column() {
      if (this.presentation !== undefined) {
        PostPresentationCard({ postId: this.postId, presentation: this.presentation, accentColor: this.accentColor })
      }
      if (this.presentation?.visibility?.hidden === true) {
        Column() {}
      } else if (this.article !== undefined) {
        PostArticleCard({ postId: this.postId, article: this.article, accentColor: this.accentColor })
      } else if (this.poll !== undefined) {
        PostPollCard({ postId: this.postId, poll: this.poll, accentColor: this.accentColor, showMedia: this.showPollMedia })
      } else if (this.card?.kind === 'space') {
        SpacePostCard({ card: this.card })
      } else if (this.card !== undefined && this.card.content !== undefined) {
        PostRichCard({ card: this.card, accentColor: this.accentColor })
      } else if (this.card !== undefined) {
        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Column({ space: 0 }) {
            if (this.card.imageUrl.length > 0) {
              ProxyMediaImage({ url: this.card.imageUrl, displayHeight: 150 })
            }
            Column({ space: 5 }) {
              Row({ space: 8 }) {
                Text(this.cardTitle()).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_primary')).layoutWeight(1).maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                SymbolGlyph($r('sys.symbol.arrow_up_right')).fontSize(18).fontColor([this.accentColor])
              }.width('100%')
              if (this.card.description.length > 0) {
                Text(this.card.description).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary'))
                  .width('100%').maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              Text(this.card.domain).fontFamily(this.appFontFamily).fontSize($r('sys.float.Caption_L')).fontColor($r('app.color.text_secondary'))
                .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            }.width('100%').alignItems(HorizontalAlign.Start).padding(12)
          }.width('100%')
        }
        .width('100%').padding(0).borderRadius(14).clip(true).margin({ top: 8 })
        .backgroundColor($r('app.color.poll_option_surface')).border({ width: 1, color: $r('app.color.divider') })
        .onClick((): void => {
          if (this.card !== undefined) { openExternalLink(getContext(this) as common.UIAbilityContext, this.card.url); }
        })
      }
    }.width('100%')
  }
}
