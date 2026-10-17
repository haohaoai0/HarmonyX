import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { userAvatarRadius, userVerifiedType, userAvatarShape, verificationBadgeColor } from '../utils/UserIdentity';
// One account row, shared by the followers/following list, the blocked list and
// the People search results. The parent owns the network call; this component
// only reports the intent and shows the pending state.
import type { UserRow } from '../models/Tweet';
import { fieldSurfaceColor } from '../utils/ThemeColors';
import { SpaceAwareAvatar } from './SpaceAwareAvatar';

@Component
export struct UserRowCard {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Prop row: UserRow;
  // Blocked rows swap the follow button for "unblock".
  @Prop blocked: boolean = false;
  @Prop muted: boolean = false;
  // Read-only contexts such as a list's member directory should still open
  // profiles without exposing an account-changing action in the row.
  @Prop showFollow: boolean = true;
  @StorageProp('harmonyx.display_mode') private themeDisplayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private themeDarkSurface: string = '';
  @StorageLink('harmonyx.accent_color') accentColor: string = '#007DFF';
  onOpen: (row: UserRow) => void = () => {
  };
  onFollowChanged: (row: UserRow, next: boolean) => Promise<boolean> = async () => false;
  onUnblock: (row: UserRow) => Promise<boolean> = async () => false;
  onUnmute: (row: UserRow) => Promise<boolean> = async () => false;
  @State private pending: boolean = false;

  private async toggleFollow(): Promise<void> {
    if (this.pending) {
      return;
    }
    this.pending = true;
    try {
      await this.onFollowChanged(this.row, !this.row.following);
    } finally {
      this.pending = false;
    }
  }

  private async unblock(): Promise<void> {
    if (this.pending) {
      return;
    }
    this.pending = true;
    try {
      if (this.muted) { await this.onUnmute(this.row); }
      else { await this.onUnblock(this.row); }
    } finally {
      this.pending = false;
    }
  }

  @Builder
  private Avatar(): void {
    SpaceAwareAvatar({verifiedType: this.row.verifiedType ?? '', avatarShape: this.row.avatarShape ?? '',  userId: this.blocked || this.muted ? '' : this.row.id,
      followed: this.row.following, url: this.row.avatarUrl, avatarSize: 44, radius: 22,
      fallbackText: this.row.name.substring(0, 1).toUpperCase(), fallbackColor: this.row.avatarColor,
      onProfile: (): void => this.onOpen(this.row) })
  }

  build(): void {
    Row({ space: 10 }) {
      this.Avatar()
      Column({ space: 3 }) {
        Row({ space: 4 }) {
          Text(this.row.name).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Subtitle_M'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.row.verified) {
            SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
              .fontSize(16)
              .fontColor([verificationBadgeColor(this.row.verifiedType ?? '', this.accentColor)])
          }
        }
        .width('100%')
        Text('@' + this.row.username).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.row.bio.length > 0) {
          Text(this.row.bio).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('app.color.text_secondary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (this.showFollow) {
        if (this.blocked || this.muted) {
          Button(this.muted ? $r('app.string.xsettings_unmute') : $r('app.string.menu_unblock_user'), { stateEffect: true })
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('app.color.text_on_inverse'))
            .backgroundColor($r('app.color.text_primary'))
            .borderRadius(16)
            .enabled(!this.pending)
            .onClick((): void => {
              this.unblock();
            })
        } else if (this.row.following) {
          Button($r('app.string.profile_detail_following'), { stateEffect: true })
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('app.color.text_primary'))
            .backgroundColor(fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
            .borderRadius(16)
            .enabled(!this.pending)
            .onClick((): void => {
              this.toggleFollow();
            })
        } else {
          Button($r('app.string.profile_detail_follow'), { stateEffect: true })
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('app.color.text_on_inverse'))
            .backgroundColor($r('app.color.text_primary'))
            .borderRadius(16)
            .enabled(!this.pending)
            .onClick((): void => {
              this.toggleFollow();
            })
        }
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .alignItems(VerticalAlign.Top)
    .onClick((): void => this.onOpen(this.row))
  }
}
