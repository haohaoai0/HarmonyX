import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { userAvatarRadius, userVerifiedType, userAvatarShape, verificationBadgeColor } from '../utils/UserIdentity';
import { common } from '@kit.AbilityKit';
import promptAction from '@ohos.promptAction';
import type { UserRow } from '../models/Tweet';
import { FollowDiscoveryData, FollowSuggestionGroup } from '../services/FollowDiscoveryData';
import { followStateStore, STORAGE_KEY_FOLLOW_REVISION } from '../services/FollowStateStore';
import { XPrivateResult, xPrivateClient } from '../services/XPrivateClient';
import { ProxyAvatar } from './ProxyAvatar';
import { ProxyMediaImage } from './ProxyMediaImage';
import { pageSurfaceColor } from '../utils/ThemeColors';
import type { FollowDiscoveryRouteParam } from '../pages/FollowDiscovery';
import type { UserDetailRouteParam } from '../pages/UserDetail';

@Component
export struct FollowSuggestions {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Consume('pageStack') pageStack: NavPathStack;
  @Prop @Watch('onGroupChanged') group: FollowSuggestionGroup = new FollowSuggestionGroup();
  @Prop contextualUserId: string = '';
  @Prop showBanner: boolean = false;
  @Prop showMore: boolean = true;
  @Prop autoLoad: boolean = false;
  @Prop vertical: boolean = false;
  @StorageLink('harmonyx.accent_color') accentColor: string = '#007DFF';
  @StorageProp('harmonyx.display_mode') themeDisplayMode: string = '';
  @StorageProp('harmonyx.dark_surface') themeDarkSurface: string = '';
  @StorageProp(STORAGE_KEY_FOLLOW_REVISION) @Watch('syncFollowState') followRevision: number = 0;
  @State private rows: UserRow[] = [];
  @State private pendingIds: string[] = [];
  @State private cardWidth: number = 174;
  private alive: boolean = true;
  private viewerId: string = '';

  aboutToAppear(): void {
    this.alive = true;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    xPrivateClient.load(context);
    this.viewerId = xPrivateClient.viewerId();
    this.rows = followStateStore.apply(this.viewerId, this.group.users);
    if (this.autoLoad && this.rows.length === 0 && xPrivateClient.isSignedIn()) { this.load(); }
  }

  aboutToDisappear(): void { this.alive = false; }

  private text(resource: Resource): string {
    return (getContext(this) as common.UIAbilityContext).resourceManager.getStringSync(resource);
  }

  private async load(): Promise<void> {
    const result: XPrivateResult = await xPrivateClient.connectPeople(this.contextualUserId);
    if (!this.alive || this.viewerId !== xPrivateClient.viewerId() || !result.ok) { return; }
    const page: FollowDiscoveryData | null = FollowDiscoveryData.parse(result.body);
    if (page !== null) {
      this.rows = followStateStore.apply(this.viewerId,
        page.users.filter((row: UserRow): boolean => row.id !== this.viewerId &&
          row.id !== this.contextualUserId && !row.following).slice(0, 8));
    }
  }

  private syncFollowState(): void { this.rows = followStateStore.apply(this.viewerId, this.rows); }

  private onGroupChanged(): void { this.rows = followStateStore.apply(this.viewerId, this.group.users); }

  private openUser(row: UserRow): void {
    const param: UserDetailRouteParam = {
      author: { id: row.id, name: row.name, username: row.username,
        avatarUrl: row.avatarUrl, avatarColor: row.avatarColor, verified: row.verified, verifiedType: row.verifiedType, avatarShape: row.avatarShape }, posts: []
    };
    this.pageStack.pushPath({ name: 'UserDetail', param: param });
  }

  private openMore(): void {
    const param: FollowDiscoveryRouteParam = { tab: 2, contextualUserId: this.contextualUserId };
    this.pageStack.pushPath({ name: 'FollowDiscovery', param: param });
  }

  private async toggleFollow(row: UserRow): Promise<void> {
    if (this.pendingIds.indexOf(row.id) >= 0 || xPrivateClient.viewerId() !== this.viewerId ||
      !xPrivateClient.isSignedIn()) { return; }
    this.pendingIds = [...this.pendingIds, row.id];
    const viewer: string = this.viewerId;
    const previous: boolean = row.following;
    const next: boolean = !previous;
    followStateStore.set(viewer, row.id, next);
    this.syncFollowState();
    try {
      const result: XPrivateResult = await xPrivateClient.follow(row.id, next);
      if (result.ok) { followStateStore.set(viewer, row.id, next); }
      else {
        followStateStore.set(viewer, row.id, previous);
        if (this.alive && viewer === xPrivateClient.viewerId()) {
          this.syncFollowState();
          promptAction.showToast({ message: this.text($r('app.string.profile_follow_failed')) });
        }
      }
    } catch (error) {
      followStateStore.set(viewer, row.id, previous);
      if (this.alive && viewer === xPrivateClient.viewerId()) {
        this.syncFollowState();
        promptAction.showToast({ message: this.text($r('app.string.profile_follow_failed')) });
      }
    } finally {
      this.pendingIds = this.pendingIds.filter((id: string): boolean => id !== row.id);
    }
  }

  @Builder
  private FollowButton(row: UserRow): void {
    Button(row.following ? $r('app.string.profile_detail_following') : $r('app.string.profile_detail_follow'))
      .fontSize($r('sys.float.Body_M')).fontWeight(FontWeight.Bold)
      .fontColor(row.following ? $r('app.color.text_primary') : $r('app.color.text_on_inverse'))
      .backgroundColor(row.following ? Color.Transparent : $r('app.color.text_primary'))
      .border({ width: row.following ? 1 : 0, color: $r('app.color.divider') })
      .height($r('app.float.follow_button_height')).padding({ left: 18, right: 18 })
      .enabled(this.pendingIds.indexOf(row.id) < 0)
      .onClick((): void => { this.toggleFollow(row); })
  }

  @Builder
  private Name(row: UserRow): void {
    Row({ space: 4 }) {
      Text(row.name).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary')).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        .flexShrink(1)
      if (row.verified) {
        SymbolGlyph($r('sys.symbol.checkmark_circle_fill')).fontSize(16).fontColor([verificationBadgeColor(row.verifiedType ?? '', this.accentColor)])
      }
    }
    .width('100%').justifyContent(this.showBanner || this.vertical ? FlexAlign.Start : FlexAlign.Center)
    Text('@' + row.username).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary'))
      .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
      .textAlign(this.showBanner || this.vertical ? TextAlign.Start : TextAlign.Center)
  }

  @Builder
  private Card(row: UserRow): void {
    Column() {
      if (this.showBanner) {
        Stack({ alignContent: Alignment.BottomStart }) {
          if ((row.bannerUrl ?? '').length > 0) {
            ProxyMediaImage({ url: row.bannerUrl ?? '', displayHeight: 116 })
              .width('100%').height($r('app.float.follow_banner_height'))
          } else {
            Column().width('100%').height($r('app.float.follow_banner_height'))
              .backgroundColor($r('app.color.bg_field'))
          }
          ProxyAvatar({verifiedType: row.verifiedType ?? '', avatarShape: row.avatarShape ?? '',  url: row.avatarUrl, avatarSize: 64, radius: 32,
            fallbackText: row.name.substring(0, 1), fallbackColor: row.avatarColor })
            .margin({ left: 12, bottom: -24 }).border({ width: 3, color: $r('app.color.bg_page') })
            .borderRadius(userAvatarRadius(64, 32, row.verifiedType ?? '', row.avatarShape ?? '')).onClick((): void => this.openUser(row))
        }.width('100%')
        Row() { Blank(); this.FollowButton(row) }.width('100%').padding({ right: 12, top: 10 })
        Column({ space: 4 }) {
          this.Name(row)
          Text(row.bio).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_primary'))
            .maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%').margin({ top: 5 })
        }.width('100%').alignItems(HorizontalAlign.Start).padding(12)
          .onClick((): void => this.openUser(row))
      } else {
        Column({ space: 10 }) {
          ProxyAvatar({verifiedType: row.verifiedType ?? '', avatarShape: row.avatarShape ?? '',  url: row.avatarUrl, avatarSize: 80, radius: 40,
            fallbackText: row.name.substring(0, 1), fallbackColor: row.avatarColor })
          this.Name(row)
        }.width('100%').padding({ left: 12, right: 12, top: 16, bottom: 14 })
          .onClick((): void => this.openUser(row))
        this.FollowButton(row)
      }
    }
    .width(this.cardWidth).height(this.showBanner ? 300 : 230)
    .border({ width: 1, color: $r('app.color.divider') }).borderRadius(12).clip(true)
    .backgroundColor(pageSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
  }

  build(): void {
    if (this.rows.length > 0) {
      Column({ space: 16 }) {
        Text(this.group.title.length > 0 ? this.group.title : this.text($r('app.string.follow_suggestions_title'))).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Subtitle_L')).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
          .width('100%').padding({ left: 16, right: 16 })
        if (this.group.description.length > 0) {
          Text(this.group.description).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary'))
            .width('100%').padding({ left: 16, right: 16 })
        }
        if (this.vertical) {
          Column({ space: 18 }) {
            ForEach(this.rows.slice(0, 3), (row: UserRow) => {
              Row({ space: 10 }) {
                ProxyAvatar({verifiedType: row.verifiedType ?? '', avatarShape: row.avatarShape ?? '',  url: row.avatarUrl, avatarSize: 40, radius: 20,
                  fallbackText: row.name.substring(0, 1), fallbackColor: row.avatarColor })
                  .onClick((): void => this.openUser(row))
                Column({ space: 2 }) { this.Name(row) }.layoutWeight(1)
                  .onClick((): void => this.openUser(row))
                this.FollowButton(row)
              }.width('100%')
            }, (row: UserRow): string => row.id + ':' + row.following + ':' + (this.pendingIds.indexOf(row.id) >= 0))
          }.width('100%').padding({ left: 16, right: 16 })
        } else {
        List({ space: 12 }) {
          ForEach(this.rows, (row: UserRow) => { ListItem() { this.Card(row) } }, (row: UserRow): string => row.id + ':' + row.following + ':' + (this.pendingIds.indexOf(row.id) >= 0))
        }.listDirection(Axis.Horizontal).height(this.showBanner ? 300 : 230)
          .width('100%').scrollBar(BarState.Off).padding({ left: 16, right: 16 })
        }
        if (this.showMore) {
          Button($r('app.string.follow_show_more')).fontSize($r('sys.float.Body_L'))
            .fontColor(this.accentColor).backgroundColor(Color.Transparent).width('100%')
            .padding({ left: 16, right: 16 }).align(Alignment.Start)
            .onClick((): void => this.openMore())
        }
      }
      .width('100%').alignItems(HorizontalAlign.Start).padding({ top: 18, bottom: 14 })
      .border({ width: this.vertical ? 1 : { top: 1, bottom: 1 }, color: $r('app.color.divider') })
      .borderRadius(this.vertical ? $r('app.float.desktop_card_radius') : 0)
      .onAreaChange((oldArea: Area, area: Area): void => {
        const width: number = Number(area.width);
        this.cardWidth = this.showBanner ? Math.min(340, Math.max(250, width * 0.8)) :
          Math.min(200, Math.max(150, (width - 48) / 2.15));
      })
    }
  }
}
