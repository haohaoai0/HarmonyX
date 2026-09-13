// Media renderer shared by the timeline and the post detail page.
import type { MediaAttachment } from '../models/Tweet';

@Component
export struct PostMedia {
  @Prop attachments: MediaAttachment[] = [];

  @Builder
  private Preview(media: MediaAttachment): void {
    Stack({ alignContent: Alignment.Center }) {
      Image(media.previewUrl.length > 0 ? media.previewUrl : media.mediaUrl)
        .width('100%')
        .height(228)
        .objectFit(ImageFit.Cover)
        .borderRadius(14)
        .clip(true)
      if (media.type === 'video') {
        Stack() {
          SymbolGlyph($r('sys.symbol.play_fill'))
            .fontSize(22)
            .fontColor([$r('app.color.text_on_brand')])
        }
        .width(48)
        .height(48)
        .borderRadius(24)
        .backgroundColor('#99000000')
        .alignContent(Alignment.Center)
      }
    }
    .width('100%')
    .height(228)
  }

  build(): void {
    Column({ space: 6 }) {
      ForEach(this.attachments, (media: MediaAttachment) => {
        if (media.type === 'video' && media.mediaUrl.length > 0) {
          Video({ src: media.mediaUrl, previewUri: media.previewUrl })
            .width('100%')
            .height(228)
            .objectFit(ImageFit.Cover)
            .borderRadius(14)
            .muted(false)
            .autoPlay(false)
            .controls(true)
        } else {
          this.Preview(media)
        }
      }, (media: MediaAttachment) => media.id)
    }
    .width('100%')
  }
}
