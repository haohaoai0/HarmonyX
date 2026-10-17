import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { STORAGE_KEY_SYSTEM_EMOJI_ENABLED } from '../services/AppearanceStore';
import type { AppNotification, TweetAuthor } from '../models/Tweet';
import { NotificationPresentation, NotificationTitleParts } from '../utils/NotificationPresentation';
import { formatPostTime } from '../utils/PostTime';
import { verificationBadgeColor } from '../utils/UserIdentity';
import { EmojiSpans, EmojiSpanStyle } from './EmojiSpans';
import { ProxyAvatar } from './ProxyAvatar';
import { ProxyMediaImage } from './ProxyMediaImage';

@Component
export struct NotificationSummary {
  @Prop notification: AppNotification;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp(STORAGE_KEY_SYSTEM_EMOJI_ENABLED) private systemEmojiEnabled: boolean = false;
  @StorageProp('harmonyx.accent_color') private accentColor: string = '#007DFF';
  onOpen: () => void = (): void => {};
  onAuthor: (author: TweetAuthor) => void = (): void => {};

  private icon(): Resource {
    if (this.notification.kind === 'like') { return $r('sys.symbol.heart_fill'); }
    if (this.notification.kind === 'repost') { return $r('sys.symbol.repeat'); }
    if (this.notification.kind === 'follow') { return $r('sys.symbol.person_fill'); }
    if (this.notification.kind === 'recommendation') { return $r('sys.symbol.star_fill'); }
    if (this.notification.kind === 'security') { return $r('sys.symbol.seal_shield_fill'); }
    return $r('sys.symbol.bell_fill');
  }

  private iconColor(): ResourceColor {
    if (this.notification.kind === 'like') { return $r('app.color.like'); }
    if (this.notification.kind === 'repost') { return $r('app.color.repost'); }
    if (this.notification.kind === 'recommendation') { return $r('app.color.notification_recommendation'); }
    return this.accentColor;
  }

  private titleParts(): NotificationTitleParts { return NotificationPresentation.titleParts(this.notification); }
  private actorStyle(): EmojiSpanStyle {
    return { weight: FontWeight.Bold, fontStyle: FontStyle.Normal, family: this.appFontFamily,
      decoration: TextDecorationType.None, color: $r('app.color.text_primary') };
  }
  private time(): string {
    return this.notification.timestampMs > 0 ? formatPostTime(new Date(this.notification.timestampMs).toISOString()) :
      this.notification.time;
  }

  build(): void {
    Row({ space: 12 }) {
      SymbolGlyph(this.icon()).fontSize($r('app.float.notification_type_icon_size')).fontColor([this.iconColor()])
        .width($r('app.float.notification_icon_column_width')).margin({ top: 3 })
      Column({ space: 8 }) {
        if (NotificationPresentation.actors(this.notification).length > 0) {
          Row({ space: 8 }) {
            ForEach(NotificationPresentation.actors(this.notification), (actor: TweetAuthor) => {
              ProxyAvatar({ url: actor.avatarUrl ?? '', avatarSize: 32, radius: 16,
                verifiedType: actor.verifiedType ?? '', avatarShape: actor.avatarShape ?? '',
                fallbackText: Array.from(actor.name || actor.username)[0] ?? '', fallbackColor: this.accentColor })
                .onClick((): void => this.onAuthor(actor))
            }, (actor: TweetAuthor): string => actor.id || actor.username)
          }.width('100%')
        }
        Row({ space: 12 }) {
          Column({ space: 4 }) {
            Text() {
              EmojiSpans(this.getUIContext(), this.titleParts().before, $r('app.float.notification_text_size'), this.systemEmojiEnabled)
              EmojiSpans(this.getUIContext(), this.titleParts().actor, $r('app.float.notification_text_size'),
                this.systemEmojiEnabled, undefined, $r('app.color.text_primary'), this.actorStyle())
              if (this.titleParts().actor.length > 0 && this.notification.fromVerifiedAccount === true) {
                SymbolSpan($r('sys.symbol.checkmark_circle_fill')).fontSize(14)
                  .fontColor([verificationBadgeColor(this.notification.authorVerifiedType ?? '', this.accentColor)])
              }
              EmojiSpans(this.getUIContext(), this.titleParts().after, $r('app.float.notification_text_size'), this.systemEmojiEnabled)
              if (this.time().length > 0) { Span(' · ' + this.time()).fontColor($r('app.color.text_secondary')) }
            }.fontFamily(this.appFontFamily).fontSize($r('app.float.notification_text_size'))
              .fontColor($r('app.color.text_primary')).maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
            if (NotificationPresentation.excerpt(this.notification).length > 0) {
              Text() { EmojiSpans(this.getUIContext(), NotificationPresentation.excerpt(this.notification),
                $r('app.float.notification_text_size'), this.systemEmojiEnabled) }
                .fontFamily(this.appFontFamily).fontSize($r('app.float.notification_text_size'))
                .fontColor($r('app.color.text_secondary')).maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
            }
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          if (this.notification.imageUrl.length > 0) {
            Stack() {
              ProxyMediaImage({ url: this.notification.imageUrl, displayHeight: 64 })
                .width(64).height(64).borderRadius(12).clip(true)
              if (this.notification.imageIsVideo) {
                SymbolGlyph($r('sys.symbol.play_fill')).fontSize(18).fontColor([$r('app.color.text_on_brand')])
              }
            }.width(64).height(64)
          }
        }.width('100%').alignItems(VerticalAlign.Top)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }.width('100%').alignItems(VerticalAlign.Top).padding($r('app.float.notification_row_padding'))
      .border({ width: { bottom: 0.5 }, color: $r('app.color.divider') })
      .onClick((): void => this.onOpen())
  }
}
