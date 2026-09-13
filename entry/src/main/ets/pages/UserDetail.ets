// Immersive profile destination opened from a post avatar. The hero mirrors
// the reference hierarchy: banner image + scrim + profile information, then
// a rounded, independently readable activity surface.
import common from '@ohos.app.ability.common';
import { display } from '@kit.ArkUI';
import {
  HdsNavDestination,
  HdsNavDestinationTitleMode
} from '@kit.UIDesignKit';
import { TweetCard } from '../components/TweetCard';
import type { Tweet, TweetAuthor, UserProfile } from '../models/Tweet';
import { formatCount } from '../models/Tweet';
import { XApiClient } from '../services/XApiClient';
import { authStore } from '../services/AuthStore';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';

export interface UserDetailRouteParam {
  author: TweetAuthor;
  posts: Tweet[];
}

@Builder
export function UserDetailBuilder(): void {
  UserDetail();
}

@Component
export struct UserDetail {
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp('harmonyx.status_bar_height') statusBarHeight: number =
    AppStorage.get<number>('harmonyx.status_bar_height') ?? 0;
  @StorageProp('harmonyx.navigation_indicator_height') navigationIndicatorHeight: number =
    AppStorage.get<number>('harmonyx.navigation_indicator_height') ?? 0;
  @StorageLink('harmonyx.accent_color') accentColor: string = '#007DFF';
  @StorageLink('harmonyx.font_scale') fontScale: number = 1;
  @State author: TweetAuthor | null = null;
  @State posts: Tweet[] = [];
  @State profile: UserProfile | null = null;
  @State profilePosts: Tweet[] = [];
  @State postsLoaded: boolean = false;
  @State isSelfProfile: boolean = false;
  @State selectedTab: number = 0;
  @State titleCollapsed: boolean = false;
  @State viewportHeight: number = 780;
  private scroller: Scroller = new Scroller();
  private contentScroller: Scroller = new Scroller();
  private api: XApiClient = new XApiClient();

  aboutToAppear(): void {
    setTimeout((): void => {
      this.readViewportHeight();
      this.loadRoute();
      this.loadLiveProfile();
    }, 30);
  }

  private readViewportHeight(): void {
    try {
      const uiContext: UIContext = this.getUIContext();
      const defaultDisplay: display.Display = display.getDefaultDisplaySync();
      const screenHeight: number = uiContext.px2vp(defaultDisplay.height);
      this.viewportHeight = Math.max(640, screenHeight - this.statusBarHeight);
    } catch (error) {
      this.viewportHeight = 780;
    }
  }

  private loadRoute(): void {
    const params: UserDetailRouteParam[] = this.pageStack.getParamByName('UserDetail') as UserDetailRouteParam[];
    if (params === undefined || params === null || params.length === 0) {
      return;
    }
    const param: UserDetailRouteParam = params[params.length - 1];
    this.author = param.author;
    this.posts = param.posts;
  }

  private async loadLiveProfile(): Promise<void> {
    const current: TweetAuthor | null = this.author;
    if (current === null || current.id.length === 0) {
      return;
    }
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    await authStore.load(context);
    if (!authStore.isSignedIn()) {
      return;
    }
    this.isSelfProfile = authStore.getUserId() === current.id;
    this.api.setToken(authStore.getToken());
    this.api.setUser(authStore.getUserId());
    const liveProfile: UserProfile | null = await this.api.userProfile(current.id);
    if (liveProfile !== null) {
      this.profile = liveProfile;
    }
    const livePosts: Tweet[] | null = await this.api.userPosts(current.id);
    if (livePosts !== null) {
      this.profilePosts = livePosts;
      this.postsLoaded = true;
    }
  }

  private scaledFont(size: number): number {
    return Math.round(size * this.fontScale * 10) / 10;
  }

  private text(resource: Resource): string {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    return context.resourceManager.getStringSync(resource);
  }

  private postsForAuthor(): Tweet[] {
    const current: TweetAuthor | null = this.author;
    if (current === null) {
      return [];
    }
    const result: Tweet[] = [];
    for (let index: number = 0; index < this.posts.length; index++) {
      const post: Tweet = this.posts[index];
      if (post.author.id === current.id) {
        result.push(post);
      }
    }
    return result;
  }

  private displayPosts(): Tweet[] {
    return this.postsLoaded ? this.profilePosts : this.postsForAuthor();
  }

  private authorName(): string {
    if (this.profile !== null && this.profile.name.length > 0) {
      return this.profile.name;
    }
    return this.author === null ? '' : this.author.name;
  }

  private authorHandle(): string {
    if (this.profile !== null && this.profile.username.length > 0) {
      return '@' + this.profile.username;
    }
    return this.author === null ? '' : '@' + this.author.username;
  }

  private avatarUrl(): string {
    if (this.profile !== null && this.profile.avatarUrl !== undefined) {
      return this.profile.avatarUrl;
    }
    return this.author === null || this.author.avatarUrl === undefined ? '' : this.author.avatarUrl;
  }

  private bannerUrl(): string {
    if (this.profile !== null && this.profile.bannerUrl !== undefined) {
      return this.profile.bannerUrl;
    }
    return '';
  }

  private profileDescription(): string {
    return this.profile === null ? '' : this.profile.description;
  }

  private isVerified(): boolean {
    return this.profile !== null ? this.profile.verified : (this.author !== null && this.author.verified);
  }

  private profilePostCount(): number {
    return this.profile === null ? this.postsForAuthor().length : this.profile.postCount;
  }

  private followingCount(): string {
    return this.profile === null ? '-' : formatCount(this.profile.followingCount);
  }

  private followersCount(): string {
    return this.profile === null ? '-' : formatCount(this.profile.followersCount);
  }

  private back(): void {
    ResponsiveLayout.closeContentDestination(this.pageStack);
  }

  @Builder
  private HeroAvatar(): void {
    if (this.avatarUrl().length > 0) {
      Image(this.avatarUrl())
        .width(96)
        .height(96)
        .objectFit(ImageFit.Cover)
        .borderRadius(48)
        .clip(true)
        .border({ width: 3, color: $r('app.color.profile_hero_outline') })
    } else if (this.author !== null) {
      Text(this.authorName().substring(0, 1).toUpperCase())
        .width(96)
        .height(96)
        .fontSize(this.scaledFont(36))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_on_brand'))
        .backgroundColor(this.author.avatarColor)
        .borderRadius(48)
        .textAlign(TextAlign.Center)
        .border({ width: 3, color: $r('app.color.profile_hero_outline') })
    }
  }

  @Builder
  private HeroMetric(value: string, label: Resource): void {
    Row({ space: 6 }) {
      Text(value)
        .fontSize(this.scaledFont(22))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_on_brand'))
      Text(label)
        .fontSize(this.scaledFont(15))
        .fontColor($r('app.color.profile_hero_muted'))
    }
  }

  @Builder
  private HeroNavigation(): void {
    Row() {
      Stack() {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(27)
          .fontColor([$r('app.color.text_on_brand')])
      }
      .width(46)
      .height(46)
      .borderRadius(23)
      .backgroundColor($r('app.color.profile_hero_control'))
      .onClick((): void => this.back())

      Blank().layoutWeight(1)

      Row({ space: 10 }) {
        Stack() {
          SymbolGlyph($r('sys.symbol.magnifyingglass'))
            .fontSize(24)
            .fontColor([$r('app.color.text_on_brand')])
        }
        .width(46)
        .height(46)
        .borderRadius(23)
        .backgroundColor($r('app.color.profile_hero_control'))

        Stack() {
          SymbolGlyph($r('sys.symbol.ellipsis_circle'))
            .fontSize(25)
            .fontColor([$r('app.color.text_on_brand')])
        }
        .width(46)
        .height(46)
        .borderRadius(23)
        .backgroundColor($r('app.color.profile_hero_control'))
      }
    }
    .width('100%')
  }

  @Builder
  private FixedProfileBackground(): void {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.bannerUrl().length > 0) {
        Image(this.bannerUrl())
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
      } else {
        Row()
          .width('100%')
          .height('100%')
          .backgroundColor(this.accentColor)
      }
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.profile_hero_scrim'))
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private ProfileHero(): void {
    if (this.author !== null) {
      Column({ space: 14 }) {
        this.HeroNavigation()
        Blank().layoutWeight(1)

        Row({ space: 12 }) {
          this.HeroAvatar()
          Blank().layoutWeight(1)
          Button(this.isSelfProfile ? $r('app.string.profile_detail_edit') :
            $r('app.string.profile_detail_follow'), { stateEffect: true })
            .fontSize(this.scaledFont(16))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_on_brand'))
            .backgroundColor($r('app.color.profile_hero_control'))
            .border({ width: 1, color: $r('app.color.profile_hero_outline') })
            .borderRadius(24)
            .padding({ left: 20, right: 20 })
        }
        .width('100%')
        .alignItems(VerticalAlign.Bottom)

        Row({ space: 7 }) {
          Text(this.authorName())
            .fontSize(this.scaledFont(26))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_on_brand'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.isVerified()) {
            SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
              .fontSize(20)
              .fontColor([this.accentColor])
          }
        }
        .width('100%')

        Text(this.authorHandle())
          .fontSize(this.scaledFont(15))
          .fontColor($r('app.color.profile_hero_muted'))
          .width('100%')

        if (this.profileDescription().length > 0) {
          Text(this.profileDescription())
            .fontSize(this.scaledFont(16))
            .fontColor($r('app.color.text_on_brand'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }

        Row({ space: 24 }) {
          this.HeroMetric(formatCount(this.profilePostCount()), $r('app.string.profile_detail_posts'))
          this.HeroMetric(this.followingCount(), $r('app.string.profile_following'))
          this.HeroMetric(this.followersCount(), $r('app.string.profile_followers'))
        }
        .width('100%')
      }
      .width('100%')
      .height(560)
      .padding({ left: 18, right: 18, top: this.statusBarHeight + 12, bottom: 48 })
    }
  }

  @Builder
  private ProfileTab(label: Resource, index: number): void {
    Column({ space: 8 }) {
      Text(label)
        .fontSize(this.scaledFont(16))
        .fontWeight(this.selectedTab === index ? FontWeight.Bold : FontWeight.Regular)
        .fontColor(this.selectedTab === index ? this.accentColor : $r('app.color.text_secondary'))
      Row()
        .height(3)
        .width(30)
        .borderRadius(2)
        .backgroundColor(this.accentColor)
        .opacity(this.selectedTab === index ? 1 : 0)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
    .onClick((): void => {
      this.selectedTab = index;
    })
  }

  @Builder
  private ActivitySurface(): void {
    Column({ space: 0 }) {
      Row() {
        this.ProfileTab($r('app.string.profile_detail_posts_tab'), 0)
        this.ProfileTab($r('app.string.profile_detail_replies_tab'), 1)
        this.ProfileTab($r('app.string.profile_detail_media_tab'), 2)
      }
      .width('100%')
      .padding({ top: 20, left: 10, right: 10, bottom: 12 })

      Divider().color($r('app.color.divider'))

      Scroll(this.contentScroller) {
        Column({ space: 0 }) {
          if (this.selectedTab === 0) {
            Text(this.text($r('app.string.profile_detail_all_posts')) + ' (' +
              formatCount(this.profilePostCount()) + ')')
              .fontSize(this.scaledFont(15))
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
              .padding({ left: 18, right: 18, top: 16, bottom: 10 })

            ForEach(this.displayPosts(), (post: Tweet) => {
              TweetCard({ tweet: post })
                .margin({ left: 10, right: 10, bottom: 10 })
                .borderRadius(18)
                .clip(true)
                .backgroundColor($r('app.color.bg_card'))
            }, (post: Tweet) => post.id)
          }
        }
        .width('100%')
        .padding({ bottom: this.navigationIndicatorHeight + 24 })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .nestedScroll({
        scrollForward: NestedScrollMode.PARENT_FIRST,
        scrollBackward: NestedScrollMode.SELF_FIRST
      })
    }
    .width('100%')
    .height(this.viewportHeight)
    .backgroundColor($r('app.color.profile_surface'))
    .borderRadius(28)
    .margin({ top: -28 })
    .padding({ top: this.titleCollapsed ? this.statusBarHeight + 60 : 0 })
  }

  @Builder
  private CollapsedTitleBar(): void {
    if (this.titleCollapsed) {
      Row({ space: 12 }) {
        Stack() {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(24)
            .fontColor([$r('app.color.text_primary')])
        }
        .width(40)
        .height(40)
        .borderRadius(20)
        .backgroundColor($r('app.color.bg_field'))
        .onClick((): void => this.back())

        if (this.avatarUrl().length > 0) {
          Image(this.avatarUrl())
            .width(36)
            .height(36)
            .objectFit(ImageFit.Cover)
            .borderRadius(18)
            .clip(true)
        } else if (this.author !== null) {
          Text(this.authorName().substring(0, 1).toUpperCase())
            .width(36)
            .height(36)
            .fontSize(this.scaledFont(15))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_on_brand'))
            .backgroundColor(this.author.avatarColor)
            .borderRadius(18)
            .textAlign(TextAlign.Center)
        }

        Column({ space: 1 }) {
          Text(this.authorName())
            .fontSize(this.scaledFont(17))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
          Text(formatCount(this.profilePostCount()) + ' ' + this.text($r('app.string.profile_detail_posts')))
            .fontSize(this.scaledFont(12))
            .fontColor($r('app.color.text_secondary'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .height(this.statusBarHeight + 60)
      .padding({ left: 14, right: 14, top: this.statusBarHeight + 8, bottom: 8 })
      .backgroundColor($r('app.color.profile_surface'))
    }
  }

  build(): void {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.Top }) {
        this.FixedProfileBackground()

        Scroll(this.scroller) {
          Column({ space: 0 }) {
            this.ProfileHero()
            this.ActivitySurface()
          }
          .width('100%')
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Auto)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .onScroll((_xOffset: number, yOffset: number): void => {
          this.titleCollapsed = yOffset > 530;
        })

        this.CollapsedTitleBar()
      }
      .width('100%')
      .height('100%')
    }
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .hideTitleBar(true)
    .hideBackButton(true)
    .onBackPressed((): boolean => {
      this.back();
      return true;
    })
    .bindToScrollable([this.scroller])
    .backgroundColor($r('app.color.bg_page'));
  }
}
