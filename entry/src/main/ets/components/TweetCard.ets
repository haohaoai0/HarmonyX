// Reusable post card: X-style row (avatar, header, text, action bar)
// with HarmonyOS SymbolGlyph icons and theme-resource colors.
import type { Tweet } from '../models/Tweet';
import { formatCount } from '../models/Tweet';
import { hdsEffect } from '@kit.UIDesignKit';
import { PostMedia } from './PostMedia';

@Component
export struct TweetCard {
  @Prop tweet: Tweet;
  onLikeChanged: (t: Tweet, liked: boolean) => void = () => {
  };
  onRepostChanged: (t: Tweet, reposted: boolean) => void = () => {
  };
  onReply: (t: Tweet) => void = () => {
  };
  onOpen: (t: Tweet) => void = () => {
  };
  onAuthorTapped: (t: Tweet) => void = () => {
  };
  @Prop showActions: boolean = true;
  @State liked: boolean = false;
  @State reposted: boolean = false;
  @StorageLink('harmonyx.accent_color') accentColor: string = '#007DFF';
  @StorageLink('harmonyx.font_scale') fontScale: number = 1;

  private scaledFont(size: number): number {
    return Math.round(size * this.fontScale * 10) / 10;
  }

  aboutToAppear(): void {
    this.liked = this.tweet.liked;
    this.reposted = this.tweet.reposted;
  }

  private avatarUrl(): string {
    return this.tweet.author.avatarUrl ?? '';
  }

  build(): void {
    Column() {
      Row({ space: 10 }) {
        if (this.avatarUrl().length > 0) {
          Image(this.avatarUrl())
            .width(44)
            .height(44)
            .objectFit(ImageFit.Cover)
            .borderRadius(22)
            .clip(true)
            .onClick((): void => this.onAuthorTapped(this.tweet))
        } else {
          Text(this.tweet.author.name.substring(0, 1).toUpperCase())
            .width(44)
            .height(44)
            .fontSize(this.scaledFont(20))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_on_brand'))
            .backgroundColor(this.tweet.author.avatarColor)
            .borderRadius(22)
            .textAlign(TextAlign.Center)
            .onClick((): void => this.onAuthorTapped(this.tweet))
        }

        Column({ space: 4 }) {
          Column({ space: 4 }) {
          Row({ space: 4 }) {
            Text(this.tweet.author.name)
              .fontSize(this.scaledFont(16))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
            if (this.tweet.author.verified) {
              SymbolGlyph($r('sys.symbol.checkmark'))
                .fontSize(this.scaledFont(13))
                .fontWeight(FontWeight.Bold)
                .fontColor([this.accentColor])
            }
            Text('@' + this.tweet.author.username + ' · ' + this.tweet.createdAt)
              .fontSize(this.scaledFont(14))
              .fontColor($r('app.color.text_secondary'))
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .maxLines(1)
          }

          Text(this.tweet.text)
            .fontSize(this.scaledFont(16))
            .fontColor($r('app.color.text_primary'))
            .width('100%')

          if (this.tweet.attachments !== undefined && this.tweet.attachments.length > 0) {
            PostMedia({ attachments: this.tweet.attachments })
              .margin({ top: 8 })
          }
        }
        .onClick((): void => {
          this.onOpen(this.tweet);
        })

        if (this.showActions) {
        // Action bar: reply / repost / like / views (iOS X order).
          Row() {
            Row({ space: 4 }) {
              SymbolGlyph($r('sys.symbol.ellipsis_bubble'))
                .fontSize(17)
                .fontColor([$r('app.color.text_secondary')])
              Text(formatCount(this.tweet.metrics.replyCount))
                .fontSize(13)
                .fontColor($r('app.color.text_secondary'))
            }
            .onClick(() => {
              this.tweet.metrics.replyCount += 1;
              this.onReply(this.tweet);
            })

            Row({ space: 4 }) {
              SymbolGlyph($r('sys.symbol.repeat'))
                .fontSize(18)
                .fontWeight(FontWeight.Medium)
                .fontColor([this.reposted ? $r('app.color.repost') : $r('app.color.text_secondary')])
              Text(formatCount(this.tweet.metrics.repostCount + (this.reposted ? 1 : 0)))
                .fontSize(13)
                .fontColor(this.reposted ? $r('app.color.repost') : $r('app.color.text_secondary'))
            }
            .onClick(() => {
              this.reposted = !this.reposted;
              if (this.reposted) {
                this.tweet.metrics.repostCount += 1;
              } else if (this.tweet.metrics.repostCount > 0) {
                this.tweet.metrics.repostCount -= 1;
              }
              this.onRepostChanged(this.tweet, this.reposted);
            })

            Row({ space: 4 }) {
              SymbolGlyph(this.liked ? $r('sys.symbol.heart_fill') : $r('sys.symbol.heart'))
                .fontSize(18)
                .fontColor([this.liked ? $r('app.color.like') : $r('app.color.text_secondary')])
              Text(formatCount(this.tweet.metrics.likeCount + (this.liked ? 1 : 0)))
                .fontSize(13)
                .fontColor(this.liked ? $r('app.color.like') : $r('app.color.text_secondary'))
            }
            .onClick(() => {
              this.liked = !this.liked;
              this.onLikeChanged(this.tweet, this.liked);
            })

            Row({ space: 4 }) {
              SymbolGlyph($r('sys.symbol.eye'))
                .fontSize(18)
                .fontColor([$r('app.color.text_secondary')])
              Text(formatCount(this.tweet.metrics.viewCount))
                .fontSize(13)
                .fontColor($r('app.color.text_secondary'))
            }
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
          .margin({ top: 8 })
        }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('app.color.bg_page'))
    .border({ width: { bottom: 1 }, color: $r('app.color.divider') })
    .visualEffect(new hdsEffect.HdsEffectBuilder()
      .pointLight({
        illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
      })
      .buildEffect())
  }
}
