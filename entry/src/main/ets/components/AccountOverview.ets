import { common } from '@kit.AbilityKit';
import type { UserProfile } from '../models/Tweet';
import { formatCount } from '../models/Tweet';
import { accountStore, STORAGE_KEY_ACCOUNTS_CHANGED } from '../services/AccountStore';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { cardSurfaceColor, pageSurfaceColor } from '../utils/ThemeColors';
import { ProxyAvatar } from './ProxyAvatar';
import { ProxyMediaImage } from './ProxyMediaImage';
import { AnchoredCover } from './AnchoredCover';

@Component
export struct AccountOverviewBanner {
  @StorageProp('harmonyx.display_mode') private displayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private darkSurface: string = '';
  @StorageLink('harmonyx.accent_color') private accentColor: string = '#007DFF';
  @Prop url: string = '';
  @Prop topInset: number = 0;
  @Prop pullOffset: number = 0;
  @Prop scrollOffset: number = 0;

  private heroHeight(): number {
    const heightPx: number = getContext(this).resourceManager.getNumber($r('app.float.account_overview_hero_height').id);
    return this.topInset + this.getUIContext().px2vp(heightPx);
  }

  build(): void {
    AnchoredCover({ coverHeight: this.heroHeight(), pullOffset: this.pullOffset, scrollOffset: this.scrollOffset }) {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({ angle: 145, colors: [
          [$r('app.color.account_overview_hero_base'), 0], [this.accentColor, 1]
        ] })
      if (this.url.length > 0) {
        ProxyMediaImage({ url: this.url, fillParent: true, surfaceColor: Color.Transparent })
      }
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: [
          [$r('app.color.account_overview_hero_scrim'), 0], [$r('app.color.account_overview_hero_shade'), 1]
        ] })
      Column().width('100%').height('100%')
        .linearGradient({ angle: 180, colors: [
          [Color.Transparent, 0.55], [pageSurfaceColor(this.displayMode, this.darkSurface), 1]
        ] })
    }.width('100%').height('100%')
    }
  }
}

// A single account banner, following the sample application's full-width
// BannerItem composition. Account actions remain below the profile information.
@Component
export struct AccountOverview {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp(STORAGE_KEY_ACCOUNTS_CHANGED) @Watch('readCachedIdentity') private accountRevision: number = 0;
  @StorageProp('harmonyx.display_mode') private displayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private darkSurface: string = '';
  @StorageLink('harmonyx.accent_color') private accentColor: string = '#007DFF';
  @Prop profile: UserProfile | null = null;
  @Prop signedIn: boolean = false;
  @Prop topInset: number = 0;
  @State private cachedName: string = '';
  @State private cachedUsername: string = '';
  @State private cachedAvatar: string = '';
  @State private cachedVerifiedType: string = '';
  @State private cachedAvatarShape: string = '';
  onProfile: () => void = (): void => {};
  onFollowing: () => void = (): void => {};
  onFollowers: () => void = (): void => {};
  onAccounts: () => void = (): void => {};
  onLogin: () => void = (): void => {};
  onSignOut: () => void = (): void => {};

  aboutToAppear(): void {
    this.readCachedIdentity();
  }

  private readCachedIdentity(): void {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const account = accountStore.active(context);
    this.cachedName = account?.displayName ?? '';
    this.cachedUsername = account?.username ?? '';
    this.cachedAvatar = account?.avatarUrl ?? '';
    this.cachedVerifiedType = account?.verifiedType ?? '';
    this.cachedAvatarShape = account?.avatarShape ?? '';
  }

  private name(): ResourceStr {
    if (!this.signedIn) { return $r('app.string.profile_welcome'); }
    return this.profile?.name || this.cachedName || this.cachedUsername || $r('app.string.tab_me');
  }

  private handle(): string {
    if (!this.signedIn) { return ''; }
    const username: string = this.profile?.username || this.cachedUsername;
    return username.length > 0 ? '@' + username : '';
  }

  private initial(): string {
    if (!this.signedIn) { return 'X'; }
    return (this.profile?.name || this.cachedName || this.cachedUsername || 'X').substring(0, 1).toUpperCase();
  }

  private joined(): string {
    const date: Date = new Date(this.profile?.createdAt ?? '');
    if (Number.isNaN(date.getTime())) { return ''; }
    return getContext(this).resourceManager.getStringSync($r('app.string.profile_year_month').id,
      date.getFullYear(), date.getMonth() + 1);
  }

  private heroHeight(): number {
    // Dimension resources are physical pixels; ArkUI numeric lengths are vp.
    const heightPx: number = getContext(this).resourceManager.getNumber($r('app.float.account_overview_hero_height').id);
    const heightVp: number = this.getUIContext().px2vp(heightPx);
    return this.topInset + heightVp;
  }

  @Builder
  private Hero(): void {
    Stack({ alignContent: Alignment.BottomStart }) {
      Column({ space: 10 }) {
        Row({ space: 12 }) {
          ProxyAvatar({ url: this.signedIn ? this.profile?.avatarUrl || this.cachedAvatar : '',
            avatarSize: 52, radius: 26, fallbackText: this.initial(), fallbackColor: this.accentColor,
            verifiedType: this.profile?.verifiedType ?? this.cachedVerifiedType,
            avatarShape: this.profile?.avatarShape ?? this.cachedAvatarShape })
          Column({ space: 4 }) {
            Text(this.name()).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Title_S')).fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.account_overview_identity_text')).maxLines(2).maxFontScale(1.3)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            if (this.handle().length > 0) {
              Text(this.handle()).fontFamily(this.appFontFamily)
                .fontSize($r('sys.float.Body_M')).fontColor($r('app.color.account_overview_identity_secondary'))
                .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            }
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          if (this.signedIn) {
            SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(18)
              .fontColor([$r('app.color.account_overview_identity_secondary')])
          }
        }.width('100%')
        Row({ space: 6 }) {
          if (this.signedIn) {
            SymbolGlyph($r('sys.symbol.checkmark_circle_fill')).fontSize(14)
              .fontColor([this.accentColor])
          }
          Text(this.signedIn ? $r('app.string.profile_signed_in') : $r('app.string.account_overview_signed_out'))
            .fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S'))
            .fontColor($r('app.color.account_overview_identity_text'))
        }.padding({ left: 10, right: 10, top: 5, bottom: 5 })
          .backgroundColor($r('app.color.account_overview_status_bg')).borderRadius(20)
      }.width('100%').alignItems(HorizontalAlign.Start)
        .padding({ left: 20, right: 20, top: this.topInset + 12, bottom: 20 })
    }.width('100%').height(this.heroHeight()).clip(true)
      .accessibilityText($r('app.string.side_profile'))
      .onClick((): void => { if (this.signedIn) { this.onProfile(); } else { this.onLogin(); } })
  }

  @Builder
  private InfoRow(title: Resource, value: string): void {
    Row({ space: 12 }) {
      Text(title).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S'))
        .fontColor($r('app.color.text_secondary'))
      Text(value.length > 0 ? value : $r('app.string.profile_info_unavailable'))
        .fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
        .fontColor($r('app.color.text_primary')).copyOption(CopyOptions.LocalDevice)
        .layoutWeight(1).textAlign(TextAlign.End)
    }.width('100%').padding({ top: 6, bottom: 6 })
  }

  @Builder
  private ProfileInformation(): void {
    Column({ space: 10 }) {
      Text(this.profile?.description || $r('app.string.account_overview_no_bio'))
        .fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
        .fontColor($r('app.color.text_secondary')).width('100%').copyOption(CopyOptions.LocalDevice)
      if (this.profile !== null) {
        Row({ space: 16 }) {
          Button({ type: ButtonType.Normal }) {
            Row({ space: 6 }) {
              Text(formatCount(this.profile.followingCount)).fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary')).fontSize($r('sys.float.Body_M'))
              Text($r('app.string.profile_following')).fontColor($r('app.color.text_secondary'))
                .fontSize($r('sys.float.Body_S'))
            }.padding({ top: 6, bottom: 6 })
          }.layoutWeight(1).backgroundColor(Color.Transparent).onClick((): void => this.onFollowing())
          Button({ type: ButtonType.Normal }) {
            Row({ space: 6 }) {
              Text(formatCount(this.profile.followersCount)).fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary')).fontSize($r('sys.float.Body_M'))
              Text($r('app.string.profile_followers')).fontColor($r('app.color.text_secondary'))
                .fontSize($r('sys.float.Body_S'))
            }.padding({ top: 6, bottom: 6 })
          }.layoutWeight(1).backgroundColor(Color.Transparent).onClick((): void => this.onFollowers())
        }.width('100%')
      }
      Divider().color($r('app.color.divider'))
      Column() {
        this.InfoRow($r('app.string.account_overview_handle'), this.handle())
        if ((this.profile?.location ?? '').length > 0) {
          this.InfoRow($r('app.string.account_overview_location'), this.profile?.location ?? '')
        }
        if ((this.profile?.website ?? '').length > 0) {
          this.InfoRow($r('app.string.account_overview_website'), this.profile?.website ?? '')
        }
        if (this.joined().length > 0) {
          this.InfoRow($r('app.string.profile_join_date'), this.joined())
        }
      }.width('100%')
    }.width('100%').alignItems(HorizontalAlign.Start).padding(16)
      .backgroundColor(cardSurfaceColor(this.displayMode, this.darkSurface)).borderRadius(20)
  }

  @Builder
  private AccountActions(): void {
    Column({ space: 12 }) {
      Button({ type: ButtonType.Normal }) {
        Row({ space: 12 }) {
          SymbolGlyph($r('sys.symbol.person_2_badge_arrow_2_circlepath')).fontSize(22).fontColor([this.accentColor])
          Text($r('app.string.account_overview_manage')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M')).fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary')).layoutWeight(1).textAlign(TextAlign.Start)
          SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(14)
            .fontColor([$r('app.color.text_secondary')])
        }.width('100%').constraintSize({ minHeight: 56 }).padding({ left: 16, right: 16, top: 12, bottom: 12 })
      }.width('100%').borderRadius(20)
        .backgroundColor(cardSurfaceColor(this.displayMode, this.darkSurface))
        .onClick((): void => this.onAccounts())
      if (this.signedIn) {
        Button($r('app.string.profile_sign_out'), { stateEffect: true }).fontFamily(this.appFontFamily)
          .width('100%').constraintSize({ minHeight: 44 }).fontSize($r('sys.float.Body_M'))
          .fontColor($r('app.color.danger'))
          .backgroundColor(cardSurfaceColor(this.displayMode, this.darkSurface))
          .onClick((): void => this.onSignOut())
      } else {
        Button($r('app.string.profile_sign_in'), { stateEffect: true }).fontFamily(this.appFontFamily)
          .width('100%').constraintSize({ minHeight: 44 }).fontSize($r('sys.float.Body_M'))
          .fontColor($r('app.color.text_on_accent')).backgroundColor(this.accentColor)
          .onClick((): void => this.onLogin())
      }
    }.width('100%')
  }

  build(): void {
    Column() {
      this.Hero()
      Column({ space: 12 }) {
        if (this.signedIn) { this.ProfileInformation() }
        else {
          Text($r('app.string.profile_browse_free')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary'))
            .width('100%').padding({ top: 4, bottom: 4 })
        }
        this.AccountActions()
      }.width('100%').padding(16)
    }.width('100%')
  }
}
