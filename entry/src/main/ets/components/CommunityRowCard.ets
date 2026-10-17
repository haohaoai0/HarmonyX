import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import type { CommunityRow } from '../models/Community';
import type { TweetAuthor } from '../models/Tweet';
import { formatCount } from '../models/Tweet';
import { ProxyAvatar } from './ProxyAvatar';
import { ProxyMediaImage } from './ProxyMediaImage';

@Component
export struct CommunityRowCard {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Prop community: CommunityRow;
  onOpen: (row: CommunityRow) => void = (): void => {};

  build(): void {
    Row({ space: 14 }) {
      Stack() {
        if (this.community.bannerUrl.length > 0) {
          ProxyMediaImage({ url: this.community.bannerUrl, displayHeight: 86 })
        } else {
          SymbolGlyph($r('sys.symbol.person_2_fill')).fontSize(30).fontColor([$r('app.color.text_secondary')])
        }
      }.width(86).height(86).borderRadius(14).clip(true).backgroundColor($r('app.color.bg_field'))
      Column({ space: 3 }) {
        Text(this.community.name).fontFamily(this.appFontFamily).fontSize($r('sys.float.Subtitle_L')).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary')).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(formatCount(this.community.memberCount) + ' ' +
          this.getUIContext().getHostContext()?.resourceManager.getStringSync($r('app.string.communities_members'))).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary'))
        if ((this.community.topicName ?? '').length > 0) {
          Text(this.community.topicName ?? '').fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S')).fontColor($r('app.color.text_primary'))
        }
        if ((this.community.members?.length ?? 0) > 0) {
          Row() {
            ForEach((this.community.members ?? []).slice(0, 5), (member: TweetAuthor, index: number) => {
              ProxyAvatar({verifiedType: member.verifiedType ?? '', avatarShape: member.avatarShape ?? '',  url: member.avatarUrl ?? '', avatarSize: 28, radius: 14,
                fallbackText: member.name.substring(0, 1), fallbackColor: member.avatarColor })
                .border({ width: 1.5, color: $r('app.color.bg_page') }).borderRadius(14)
                .margin({ left: index > 0 ? -7 : 0 })
            }, (member: TweetAuthor): string => member.id + member.username)
          }.margin({ top: 3 })
        }
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
    }.width('100%').padding({ left: 16, right: 16, top: 14, bottom: 14 })
      .onClick((): void => this.onOpen(this.community))
  }
}
