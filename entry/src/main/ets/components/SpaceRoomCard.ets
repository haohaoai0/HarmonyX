import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { userAvatarRadius, verificationBadgeColor, userVerifiedType, userAvatarShape } from '../utils/UserIdentity';
import { common } from '@kit.AbilityKit';
import { SpaceParticipant, SpaceRoom } from '../models/Space';
import { ProxyAvatar } from './ProxyAvatar';
import { formatCount } from '../models/Tweet';
import { spaceStatus } from '../utils/SpacePresentation';
import { shareSpace } from '../utils/SharePost';
import { openExternalLink } from '../utils/PostEntities';

@Component
export struct SpaceRoomCard {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Prop room: SpaceRoom = new SpaceRoom();
  onOpen: (room: SpaceRoom) => void = (): void => {};
  onHide: (room: SpaceRoom) => void = (): void => {};
  onHost: (room: SpaceRoom) => void = (): void => {};

  @Builder
  private Actions(): void {
    Menu() {
      MenuItem({ content: $r('app.string.spaces_share') }).onClick((): void => {
        shareSpace(getContext(this) as common.UIAbilityContext, this.room.id, this.room.title);
      })
      MenuItem({ content: $r('app.string.spaces_not_interested') }).onClick((): void => this.onHide(this.room))
      MenuItem({ content: $r('app.string.spaces_report_on_x') }).onClick((): void => {
        openExternalLink(getContext(this) as common.UIAbilityContext, 'https://x.com/i/spaces/' + this.room.id);
      })
    }
  }
  build(): void {
    Column() {
      Column({ space: 18 }) {
        Row({ space: 6 }) {
          SymbolGlyph($r('sys.symbol.waveform')).fontSize(20).fontColor([$r('app.color.space_card_text')])
          Text(spaceStatus(this.room)).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.space_card_text'))
          Blank()
          Button({ type: ButtonType.Circle }) {
            Text('⋯').fontFamily(this.appFontFamily).fontSize(28).fontColor($r('app.color.space_card_text'))
          }.width(36).height(36).backgroundColor(Color.Transparent)
            .accessibilityText($r('app.string.spaces_more')).bindMenu(this.Actions())
        }.width('100%')
        Text(this.room.title || $r('app.string.spaces_untitled')).fontFamily(this.appFontFamily).width('100%')
          .fontSize($r('app.float.space_card_title_size')).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.space_card_text')).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
        Row({ space: 8 }) {
          Row({ space: -8 }) {
            ForEach(this.room.participants.filter((person: SpaceParticipant): boolean => person.role === 'speaker' || person.role === 'cohost')
              .slice(0, 3), (person: SpaceParticipant): void => {
              ProxyAvatar({verifiedType: person.verifiedType ?? '', avatarShape: person.avatarShape ?? '',  url: person.avatarUrl, avatarSize: 28, radius: 14,
                fallbackText: person.name.substring(0, 1), fallbackColor: $r('app.color.space_card_footer') })
            }, (person: SpaceParticipant): string => person.id)
          }
          Text($r('app.string.spaces_listening_count', formatCount(this.room.participantCount))).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M')).fontWeight(FontWeight.Bold).fontColor($r('app.color.space_card_text'))
        }.width('100%')
      }.width('100%').padding({ left: 20, right: 16, top: 12, bottom: 22 })
        .alignItems(HorizontalAlign.Start).onClick((): void => this.onOpen(this.room))
      Column({ space: 8 }) {
        Row({ space: 6 }) {
          ProxyAvatar({verifiedType: this.room.host.verifiedType ?? '', avatarShape: this.room.host.avatarShape ?? '',  url: this.room.host.avatarUrl, avatarSize: 26, radius: 13,
            fallbackText: this.room.host.name.substring(0, 1), fallbackColor: $r('app.color.space_card_fill') })
          Text(this.room.host.name || this.room.host.username || $r('app.string.spaces_host')).fontFamily(this.appFontFamily)
            .layoutWeight(1).fontSize($r('sys.float.Body_M')).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.space_card_text')).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.room.host.verified) {
            SymbolGlyph($r('sys.symbol.checkmark_circle_fill')).fontSize(16).fontColor([$r('app.color.space_card_text')])
          }
          Text($r('app.string.spaces_host')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S')).fontColor($r('app.color.space_card_text'))
            .padding({ left: 5, right: 5, top: 1, bottom: 1 }).borderRadius(4)
            .backgroundColor($r('app.color.space_card_badge'))
        }.width('100%').onClick((): void => this.onHost(this.room))
        if (this.room.host.description.length > 0) {
          Text(this.room.host.description).fontFamily(this.appFontFamily).width('100%').fontSize($r('sys.float.Body_M'))
            .fontColor($r('app.color.space_card_text')).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
            .onClick((): void => this.onOpen(this.room))
        }
      }.width('100%').padding({ left: 20, right: 20, top: 14, bottom: 16 }).alignItems(HorizontalAlign.Start)
        .backgroundColor($r('app.color.space_card_footer'))
    }.width('100%').backgroundColor($r('app.color.space_card_fill'))
      .borderRadius($r('app.float.space_card_radius')).clip(true)
  }
}
