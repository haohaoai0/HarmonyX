import { pageBackgroundActive } from '../services/PageBackgroundStore';
import { pageTextColor } from '../utils/ThemeColors';
import { appPageBackground } from '../components/PageBackgroundLayer';
import { pageCanvasColor, pageReadingSurfaceColor } from '../utils/ThemeColors';
import { STORAGE_KEY_PAGE_TRANSITION_MODE, DEFAULT_PAGE_TRANSITION_MODE } from '../services/PageTransitionSettingsStore';
import { pageSystemTransition, PageTransitionMotion } from '../utils/PageTransition';
// Followers / following / blocked-account list. All three are user timelines,
// so they share one page and differ only by the operation they call.
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import common from '@ohos.app.ability.common';
import { deviceInfo } from '@kit.BasicServicesKit';
import { uiMaterial } from '@kit.ArkUI';
import { HdsNavDestination, HdsNavDestinationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import promptAction from '@ohos.promptAction';
import { UserRowCard } from '../components/UserRowCard';
import type { UserListPage, UserRow } from '../models/Tweet';
import { XPrivateClient, XPrivateResult, xPrivateClient } from '../services/XPrivateClient';
import { XTimelineParser } from '../services/XTimelineParser';
import { XUserParser } from '../services/XUserParser';
import { postModerationStore } from '../services/PostModerationStore';
import type { UserProfile } from '../models/Tweet';
import { destinationTitleBarStyle } from '../utils/DestinationTitleBar';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';
import { pageSurfaceColor } from '../utils/ThemeColors';
import type { UserDetailRouteParam } from './UserDetail';

const PAGE_SIZE = 20;

export const USER_LIST_FOLLOWERS: string = 'followers';
export const USER_LIST_FOLLOWING: string = 'following';
export const USER_LIST_BLOCKED: string = 'blocked';
export const USER_LIST_MUTED: string = 'muted';

export interface UserListRouteParam {
  mode: string;
  userId: string;
}

@Builder
export function UserListBuilder(): void {
  UserList();
}

@Component
export struct UserList {
  @StorageProp('harmonyx.page_background') private pageBackgroundValue: string = '';
  @State private pageMotion: PageTransitionMotion = new PageTransitionMotion();
  @StorageProp(STORAGE_KEY_PAGE_TRANSITION_MODE) private pageTransitionMode: string = DEFAULT_PAGE_TRANSITION_MODE;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp('harmonyx.status_bar_height') statusBarHeight: number =
    AppStorage.get<number>('harmonyx.status_bar_height') ?? 0;
  @StorageProp('harmonyx.navigation_indicator_height') navigationIndicatorHeight: number =
    AppStorage.get<number>('harmonyx.navigation_indicator_height') ?? 0;
  @StorageLink('harmonyx.accent_color') accentColor: string = '#007DFF';
  @StorageProp('harmonyx.display_mode') private themeDisplayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private themeDarkSurface: string = '';
  @StorageLink('harmonyx.title_bar_style_mode') titleBarStyleMode: number = 0;
  @State private rows: UserRow[] = [];
  @State private status: string = '';
  @State private loading: boolean = true;
  @State private loadingMore: boolean = false;
  @State private refreshing: boolean = false;
  @State private pendingId: string = '';
  @State private mode: string = '';
  @State private userId: string = '';
  private nextToken: string = '';
  private accountGeneration: number = -1;
  private loadRevision: number = 0;
  private alive: boolean = true;
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    setTimeout((): void => {
      this.readRoute();
      this.load(true);
    }, 30);
  }

  aboutToDisappear(): void { this.alive = false; this.loadRevision++; }

  private readRoute(): void {
    const params: UserListRouteParam[] =
      this.pageStack.getParamByName('UserList') as UserListRouteParam[];
    if (params === undefined || params === null || params.length === 0) {
      return;
    }
    const param: UserListRouteParam = params[params.length - 1];
    this.mode = this.normalizedMode(param.mode);
    this.userId = param.userId;
  }

  private normalizedMode(mode: string): string {
    if (mode === USER_LIST_FOLLOWING || mode === USER_LIST_BLOCKED || mode === USER_LIST_MUTED) {
      return mode;
    }
    return USER_LIST_FOLLOWERS;
  }

  private text(resource: Resource): string {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    return context.resourceManager.getStringSync(resource);
  }

  private titleText(): string {
    if (this.mode === USER_LIST_FOLLOWING) {
      return this.text($r('app.string.user_list_following_title'));
    }
    if (this.mode === USER_LIST_BLOCKED) {
      return this.text($r('app.string.user_list_blocked_title'));
    }
    if (this.mode === USER_LIST_MUTED) { return this.text($r('app.string.xsettings_muted_list')); }
    if (this.mode.length === 0) {
      return '';
    }
    return this.text($r('app.string.user_list_followers_title'));
  }

  private pageMaterial(): uiMaterial.Material | undefined {
    if (!deviceInfo.apiAvailable('26.0.0')) {
      return undefined;
    }
    return new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.REGULAR,
      applyShadow: true,
      colorInvert: true
    });
  }

  private async load(reset: boolean): Promise<void> {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    xPrivateClient.load(context);
    if (!xPrivateClient.isSignedIn()) {
      this.status = this.text($r('app.string.user_list_sign_in'));
      this.loading = false;
      return;
    }
    if (reset) {
      this.loading = true;
      this.nextToken = '';
    } else {
      if (this.loadingMore || this.nextToken.length === 0) {
        return;
      }
      this.loadingMore = true;
    }
    const cursor: string = reset ? '' : this.nextToken;
    const revision: number = ++this.loadRevision;
    const generation: number = xPrivateClient.sessionGeneration();
    if (reset) { this.accountGeneration = generation; }
    if (this.accountGeneration !== generation) { this.loading = false; this.loadingMore = false; return; }
    let result: XPrivateResult;
    if (this.mode === USER_LIST_FOLLOWING) {
      result = await xPrivateClient.userFollowing(this.userId, cursor, PAGE_SIZE);
    } else if (this.mode === USER_LIST_BLOCKED) {
      result = await xPrivateClient.viewerBlocking(cursor, PAGE_SIZE);
    } else if (this.mode === USER_LIST_MUTED) {
      result = await xPrivateClient.viewerMuting(cursor, PAGE_SIZE);
    } else {
      result = await xPrivateClient.userFollowers(this.userId, cursor, PAGE_SIZE);
    }
    if (!this.alive || revision !== this.loadRevision) { return; }
    if (generation !== xPrivateClient.sessionGeneration()) {
      this.rows = [];
      this.status = this.text($r('app.string.xsettings_account_changed'));
      this.loading = false;
      this.loadingMore = false;
      return;
    }
    if (!result.ok) {
      const detail: string = XPrivateClient.explain(result).substring(0, 120);
      this.status = result.status === 401 || result.status === 403 ?
        this.text($r('app.string.private_session_expired')) :
        this.text($r('app.string.user_list_failed')) + ' HTTP ' + result.status +
          (detail.length > 0 ? ' · ' + detail : '');
      this.loading = false;
      this.loadingMore = false;
      return;
    }
    const page: UserListPage | null = XTimelineParser.parseUserList(result.body);
    if (page === null) {
      this.status = this.text($r('app.string.user_list_failed'));
      this.loading = false;
      this.loadingMore = false;
      return;
    }
    if (reset) {
      this.rows = page.users;
    } else {
      const combined: UserRow[] = [];
      for (let i: number = 0; i < this.rows.length; i++) {
        combined.push(this.rows[i]);
      }
      for (let i: number = 0; i < page.users.length; i++) {
        combined.push(page.users[i]);
      }
      this.rows = combined;
    }
    this.nextToken = page.nextToken;
    this.status = this.rows.length === 0 ? this.text($r('app.string.user_list_empty')) : '';
    this.loading = false;
    this.loadingMore = false;
  }

  private openUser(row: UserRow): void {
    const param: UserDetailRouteParam = {
      author: {
        id: row.id,
        name: row.name,
        username: row.username,
        avatarColor: row.avatarColor,
        avatarUrl: row.avatarUrl,
        verified: row.verified, verifiedType: row.verifiedType, avatarShape: row.avatarShape
      },
      posts: []
    };
    this.pageStack.pushPath({ name: 'UserDetail', param: param });
  }

  private async applyFollow(row: UserRow, next: boolean): Promise<boolean> {
    if (this.accountGeneration !== xPrivateClient.sessionGeneration()) { return false; }
    const result: XPrivateResult = await xPrivateClient.follow(row.id, next);
    if (!this.alive || this.accountGeneration !== xPrivateClient.sessionGeneration()) { return false; }
    if (!result.ok) {
      promptAction.showToast({
        message: this.text($r('app.string.profile_follow_failed')) + ' · HTTP ' + result.status,
        duration: 2000
      });
      return false;
    }
    const updated: UserRow[] = [];
    for (let i: number = 0; i < this.rows.length; i++) {
      const current: UserRow = this.rows[i];
      if (current.id === row.id) {
        const copy: UserRow = {
          id: current.id,
          name: current.name,
          username: current.username,
          avatarUrl: current.avatarUrl,
          avatarColor: current.avatarColor,
          verified: current.verified, verifiedType: current.verifiedType, avatarShape: current.avatarShape,
          bio: current.bio,
          following: next,
          followedBy: current.followedBy
        };
        updated.push(copy);
      } else {
        updated.push(current);
      }
    }
    this.rows = updated;
    return true;
  }

  private async applyUnblock(row: UserRow): Promise<boolean> {
    if (this.accountGeneration !== xPrivateClient.sessionGeneration()) { return false; }
    const result: XPrivateResult = this.mode === USER_LIST_MUTED ?
      await xPrivateClient.muteUser(row.id, false) : await xPrivateClient.block(row.id, false);
    if (!this.alive || this.accountGeneration !== xPrivateClient.sessionGeneration()) { return false; }
    if (!result.ok) {
      promptAction.showToast({
        message: this.text($r('app.string.block_failed')) + ' · HTTP ' + result.status,
        duration: 2000
      });
      return false;
    }
    const remaining: UserRow[] = [];
    const refreshed: XPrivateResult = await xPrivateClient.userByRestId(row.id, true);
    if (!this.alive || this.accountGeneration !== xPrivateClient.sessionGeneration()) { return false; }
    const profile: UserProfile | null = refreshed.ok ? XUserParser.parse(refreshed.body) : null;
    if (profile !== null && profile.muting === false && profile.blocking === false) {
      postModerationStore.unhideUser(getContext(this) as common.UIAbilityContext, row.id);
    }
    for (let i: number = 0; i < this.rows.length; i++) {
      if (this.rows[i].id !== row.id) {
        remaining.push(this.rows[i]);
      }
    }
    this.rows = remaining;
    this.status = remaining.length === 0 ? this.text($r('app.string.user_list_empty')) : '';
    promptAction.showToast({ message: this.text(this.mode === USER_LIST_MUTED ?
      $r('app.string.xsettings_saved') : $r('app.string.unblock_done')), duration: 1500 });
    return true;
  }

  @Builder
  private Content(): void {
    if (this.loading) {
      ListItem() {
        Column() {
          LoadingProgress().color(this.accentColor).width(18).height(18)
        }
        .width('100%')
        .padding({ top: 48 })
      }
    } else if (this.rows.length === 0) {
      ListItem() {
        Column() {
          Text(this.status.length > 0 ? this.status : this.text($r('app.string.user_list_empty'))).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_L'))
            .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
            .textAlign(TextAlign.Center)
            .width('100%')
          if (this.status.length > 0) {
            Button($r('app.string.common_retry'), { stateEffect: true })
              .fontSize($r('sys.float.Body_L'))
              .fontColor($r('app.color.text_on_accent'))
              .backgroundColor(this.accentColor)
              .borderRadius(20)
              .margin({ top: 16 })
              .onClick((): void => {
                this.load(true);
              })
          }
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 48 })
      }
    } else {
      ForEach(this.rows, (row: UserRow) => {
        ListItem() {
          UserRowCard({
            row: row,
            blocked: this.mode === USER_LIST_BLOCKED,
            muted: this.mode === USER_LIST_MUTED,
            onOpen: (r: UserRow): void => this.openUser(r),
            onFollowChanged: (r: UserRow, next: boolean): Promise<boolean> => this.applyFollow(r, next),
            onUnblock: (r: UserRow): Promise<boolean> => this.applyUnblock(r),
            onUnmute: (r: UserRow): Promise<boolean> => this.applyUnblock(r)
          })
        }
      }, (row: UserRow) => row.id)
      if (this.nextToken.length > 0) {
        ListItem() {
          Row() {
            if (this.loadingMore) {
              LoadingProgress().color(this.accentColor).width(18).height(18)
            }
            Text($r('app.string.user_list_load_more')).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_M'))
              .fontColor(pageTextColor($r('app.color.text_accent'), this.pageBackgroundValue, Color.Transparent))
              .margin({ left: 8 })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .padding(16)
          .onClick((): void => {
            this.load(false);
          })
        }
      }
    }
  }

  build(): void {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        appPageBackground()
      Refresh({ refreshing: $$this.refreshing }) {
        List({ scroller: this.scroller }) {
          this.Content()
        }
        .width('100%')
        .height('100%')
        .divider({ strokeWidth: 1, color: $r('app.color.divider') })
        .scrollBar(BarState.Off)
        .contentStartOffset(this.statusBarHeight + 60)
        .contentEndOffset(this.navigationIndicatorHeight + 24)
        .onReachEnd((): void => {
          this.load(false);
        })
      }
      .width('100%')
      .height('100%')
      .onRefreshing((): void => {
        this.load(true).then((): void => {
          this.refreshing = false;
        });
      })
    
      }.width('100%').height('100%')
    }
    .scale({ x: this.pageMotion.scale, y: this.pageMotion.scale })
    .opacity(this.pageMotion.opacity)
    .onReady((context: NavDestinationContext): void => { this.pageMotion.attach(context); })
    .systemTransition(pageSystemTransition(this.pageTransitionMode))
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .hideBackButton(false)
    .onBackPressed((): boolean => {
      ResponsiveLayout.closeContentDestination(this.pageStack);
      return true;
    })
    .bindToScrollable([this.scroller])
    .titleBar({
      avoidLayoutSafeArea: true,
      content: { title: { mainTitle: this.titleText() } },
      style: destinationTitleBarStyle(ScrollEffectType.IMMERSIVE_GRADIENT_BLUR,
        this.themeDisplayMode, this.themeDarkSurface, this.titleBarStyleMode)
    })
    .backgroundColor(pageCanvasColor(this.themeDisplayMode, this.themeDarkSurface, this.pageBackgroundValue))
    .systemMaterial(pageBackgroundActive(this.pageBackgroundValue) ? undefined : this.pageMaterial());
  }
}
