// Harmony X main page — iOS-X-style layout built with HarmonyOS design
// components: Navigation + bottom Tabs, SymbolGlyph tab/action icons,
// floating compose button opening a bottom-sheet composer, Search,
// pull-to-refresh, toasts. Theme resources (base + dark) follow the device
// light/dark mode; text uses HarmonyOS Sans (system default).
// The timeline is open (sample posts, zero setup). OAuth sign-in — the only
// auth method — unlocks live data and interactions.
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import common from '@ohos.app.ability.common';
import { deviceInfo } from '@kit.BasicServicesKit';
import { LengthMetrics, SymbolGlyphModifier, uiMaterial } from '@kit.ArkUI';
import {
  DividerShowType,
  HdsNavigation,
  HdsNavigationTitleMode,
  HdsTabs,
  HdsTabsController,
  HdsTabsModifier,
  hdsEffect,
  hdsMaterial,
  ScrollEffectType,
  TitleBarStyleOptions
} from '@kit.UIDesignKit';
import { FloatingComposeButton } from '../components/FloatingComposeButton';
import { TweetCard } from '../components/TweetCard';
import type { Tweet, AppNotification, DirectMessage } from '../models/Tweet';
import { MockData } from '../services/MockData';
import { XApiClient } from '../services/XApiClient';
import { authStore } from '../services/AuthStore';

// iOS-style bottom-sheet composer.
@CustomDialog
struct ComposeSheet {
  controller?: CustomDialogController;
  @Prop initialText: string = '';
  @Prop replyUser: string = '';
  @State draft: string = '';
  onCancel: () => void = () => {
  };
  onPost: (text: string) => void = () => {
  };

  aboutToAppear(): void {
    this.draft = this.initialText;
  }

  private text(resource: Resource): string {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    return context.resourceManager.getStringSync(resource);
  }

  build(): void {
    Column({ space: 12 }) {
      Row() {
        Button($r('app.string.compose_cancel'), { stateEffect: true })
          .fontSize(15)
          .backgroundColor($r('app.color.bg_secondary_btn'))
          .fontColor($r('app.color.text_primary'))
          .onClick(() => this.onCancel())
        Blank()
        Button($r('app.string.compose_post'), { stateEffect: true })
          .fontSize(15)
          .backgroundColor($r('app.color.brand'))
          .fontColor($r('app.color.text_on_brand'))
          .enabled(this.draft.trim().length > 0)
          .onClick(() => this.onPost(this.draft))
      }
      .width('100%')
      if (this.replyUser.length > 0) {
        Text(this.text($r('app.string.compose_replying_to')) + this.replyUser)
          .fontSize(13)
          .fontColor($r('app.color.brand'))
          .width('100%')
      }
      TextArea({ placeholder: $r('app.string.compose_placeholder'), text: this.draft })
        .height(140)
        .backgroundColor($r('app.color.bg_field'))
        .fontColor($r('app.color.text_primary'))
        .onChange((v: string) => {
          this.draft = v;
        })
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius({ topLeft: 20, topRight: 20 })
  }
}

@Entry
@Component
struct Index {
  @State currentTab: number = 0;
  @State timeline: Tweet[] = [];
  @State replyToId: string = '';
  @State replyToUser: string = '';
  @State statusLine: string = '';
  @State searchText: string = '';
  @State refreshing: boolean = false;
  @State loading: boolean = true;
  @State handleText: string = '';
  @State liveBadge: string = '';
  @StorageProp('harmonyx.status_bar_height') statusBarHeight: number =
    AppStorage.get<number>('harmonyx.status_bar_height') ?? 0;
  @StorageProp('harmonyx.navigation_indicator_height') @Watch('configureImmersiveTabs') navigationIndicatorHeight: number =
    AppStorage.get<number>('harmonyx.navigation_indicator_height') ?? 0;
  private api: XApiClient = new XApiClient();
  private tabsController: TabsController = new TabsController();
  private hdsTabsController: HdsTabsController = new HdsTabsController();
  @State hdsTabsModifier: HdsTabsModifier = new HdsTabsModifier();
  private navPathStack: NavPathStack = new NavPathStack();
  private homeScroller: Scroller = new Scroller();
  private exploreScroller: Scroller = new Scroller();
  private notificationsScroller: Scroller = new Scroller();
  private messagesScroller: Scroller = new Scroller();
  private profileScroller: Scroller = new Scroller();
  private searchController: SearchController = new SearchController();
  private composeController: CustomDialogController | null = null;

  aboutToAppear(): void {
    this.configureImmersiveTabs();
    this.bindHdsTabScrollers();
    this.statusLine = this.text($r('app.string.status_loading'));
    this.loadTimeline();
  }

  aboutToDisappear(): void {
    if (!this.supportsHdsFloatingMaterial()) {
      return;
    }
    this.hdsTabsController.unbindScroller(this.homeScroller);
    this.hdsTabsController.unbindScroller(this.exploreScroller);
    this.hdsTabsController.unbindScroller(this.notificationsScroller);
    this.hdsTabsController.unbindScroller(this.messagesScroller);
    this.hdsTabsController.unbindScroller(this.profileScroller);
  }

  private text(resource: Resource): string {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    return context.resourceManager.getStringSync(resource);
  }

  private supportsImmersiveMaterial(): boolean {
    return deviceInfo.sdkApiVersion >= 26;
  }

  private supportsHdsNavigation(): boolean {
    return deviceInfo.sdkApiVersion >= 20;
  }

  private supportsHdsFloatingMaterial(): boolean {
    return deviceInfo.sdkApiVersion >= 23;
  }

  private contentTopInset(): number {
    if (!this.supportsHdsNavigation()) {
      return 12;
    }
    return this.statusBarHeight + 64;
  }

  private exploreContentTopInset(): number {
    if (!this.supportsHdsNavigation()) {
      return 12;
    }
    // The Explore title bar keeps the identity row and adds a second search row.
    // Leave an extra touch-safe gap before the first list item.
    return this.statusBarHeight + 112;
  }

  private titleBarStyle(): TitleBarStyleOptions {
    return {
      scrollEffectOpts: {
        enableScrollEffect: true,
        scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR,
        blurEffectiveStartOffset: LengthMetrics.vp(0),
        blurEffectiveEndOffset: LengthMetrics.vp(16)
      },
      originalStyle: {
        backgroundStyle: {
          backgroundColor: $r('sys.color.ohos_id_color_background_transparent')
        },
        contentStyle: {
          titleStyle: {
            mainTitleColor: $r('app.color.text_primary'),
            subTitleColor: $r('app.color.text_secondary')
          },
          backIconStyle: { iconColor: $r('app.color.text_primary') },
          subIconStyle: { iconColor: $r('app.color.text_primary') },
          menuStyle: { iconColor: $r('app.color.text_primary') }
        }
      },
      scrollEffectStyle: {
        backgroundStyle: {
          backgroundColor: $r('app.color.bg_page')
        },
        contentStyle: {
          titleStyle: {
            mainTitleColor: $r('app.color.text_primary'),
            subTitleColor: $r('app.color.text_secondary')
          },
          backIconStyle: { iconColor: $r('app.color.text_primary') },
          subIconStyle: { iconColor: $r('app.color.text_primary') },
          menuStyle: { iconColor: $r('app.color.text_primary') }
        }
      },
      systemMaterialEffect: {
        materialType: hdsMaterial.MaterialType.IMMERSIVE,
        materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
      }
    };
  }

  private configureImmersiveTabs(): void {
    if (!this.supportsHdsFloatingMaterial()) {
      return;
    }
    this.hdsTabsModifier
      .vertical(false)
      .barPosition(BarPosition.End)
      .barHeight(56)
      .barFloatingStyle({
        adaptToHandedness: true,
        barBottomMargin: this.navigationIndicatorHeight,
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.IMMERSIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE,
        },
      });
  }

  private bindHdsTabScrollers(): void {
    if (!this.supportsHdsFloatingMaterial()) {
      return;
    }
    this.hdsTabsController.bindScroller(0, this.homeScroller);
    this.hdsTabsController.bindScroller(1, this.exploreScroller);
    this.hdsTabsController.bindScroller(2, this.notificationsScroller);
    this.hdsTabsController.bindScroller(3, this.messagesScroller);
    this.hdsTabsController.bindScroller(4, this.profileScroller);
  }

  private async loadTimeline(): Promise<void> {
    this.loading = true;
    try {
      const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      await authStore.load(ctx);
      this.api.setToken(authStore.getToken());
      this.api.setUser(authStore.getUserId());
      this.handleText = authStore.getUsername().length > 0 ? '@' + authStore.getUsername() : '';
      await this.fetchPosts();
    } finally {
      this.loading = false;
      this.refreshing = false;
    }
  }

  // Live-first when signed in, sample posts otherwise. Never empty.
  private async fetchPosts(): Promise<void> {
    let live: Tweet[] | null = null;
    if (authStore.isSignedIn() && authStore.getUserId().length > 0) {
      live = await this.api.homeTimeline(authStore.getUserId());
    }
    if ((live === null || live.length === 0) && authStore.isSignedIn()) {
      live = await this.api.searchRecent('HarmonyOS');
    }
    if (live !== null && live.length > 0) {
      this.timeline = live;
      this.liveBadge = this.text($r('app.string.status_live_badge'));
      if (authStore.getUserId().length > 0) {
        this.statusLine = this.text($r('app.string.status_home_live_prefix')) + this.handleText;
      } else {
        this.statusLine = this.text($r('app.string.status_live_search'));
      }
    } else {
      this.timeline = MockData.timeline();
      this.liveBadge = '';
      if (!authStore.isSignedIn()) {
        this.statusLine = this.text($r('app.string.status_sample_sign_in'));
      } else if (this.api.lastStatus() === 402) {
        this.statusLine = this.text($r('app.string.status_paid_api_samples'));
      } else {
        this.statusLine = this.text($r('app.string.status_offline_samples'));
      }
    }
  }

  private needsAuth(what: string): boolean {
    if (authStore.isSignedIn()) {
      return false;
    }
    promptAction.showToast({ message: this.text($r('app.string.toast_sign_in_to_prefix')) + what, duration: 2000 });
    router.pushUrl({ url: 'pages/Login' });
    return true;
  }

  private onRefresh(): void {
    this.refreshing = true;
    this.fetchPosts().then(() => {
      this.refreshing = false;
    });
  }

  private openComposer(initial: string, replyToId: string, replyUser: string): void {
    if (this.needsAuth(replyToId.length > 0 ? this.text($r('app.string.action_reply')) :
      this.text($r('app.string.action_post')))) {
      return;
    }
    this.replyToId = replyToId;
    this.replyToUser = replyUser;
    this.composeController = new CustomDialogController({
      builder: ComposeSheet({
        initialText: initial,
        replyUser: replyUser,
        onCancel: (): void => {
          this.composeController?.close();
        },
        onPost: (t: string): void => {
          this.composeController?.close();
          this.publishText(t);
        }
      }),
      alignment: DialogAlignment.Bottom,
      autoCancel: true
    });
    this.composeController.open();
  }

  private publishText(text: string): void {
    const trimmed: string = text.trim();
    if (trimmed.length === 0) {
      return;
    }
    const replyId: string = this.replyToId;
    this.timeline.unshift({
      id: 'local-' + Date.now().toString(),
      author: {
        id: 'me',
        name: this.handleText.length > 0 ? this.handleText : this.text($r('app.string.tab_me')),
        username: authStore.getUsername().length > 0 ? authStore.getUsername() : 'you',
        avatarColor: '#1D9BF0',
        verified: false
      },
      text: trimmed,
      createdAt: 'now',
      metrics: { replyCount: 0, repostCount: 0, likeCount: 0, viewCount: 1 },
      liked: false,
      reposted: false
    });
    this.replyToId = '';
    this.replyToUser = '';
    this.api.postTweet(trimmed, replyId).then((ok: boolean) => {
      promptAction.showToast({ message: ok ? this.text($r('app.string.toast_published')) :
        this.apiFailMsg(this.text($r('app.string.action_post_capitalized'))), duration: 2000 });
    });
  }

  private apiFailMsg(action: string): string {
    if (this.api.lastStatus() === 402) {
      return this.text($r('app.string.api_paid_access'));
    }
    return action + this.text($r('app.string.api_unreachable_suffix'));
  }

  private onLike(t: Tweet, liked: boolean): void {
    if (!authStore.isSignedIn() || authStore.getUserId().length === 0) {
      this.needsAuth(this.text($r('app.string.action_like_posts')));
      return;
    }
    this.api.setLike(t.id, liked).then((ok: boolean) => {
      if (!ok) {
        promptAction.showToast({ message: this.apiFailMsg(this.text($r('app.string.action_like'))), duration: 2000 });
      }
    });
  }

  private onRepost(t: Tweet, reposted: boolean): void {
    if (!authStore.isSignedIn() || authStore.getUserId().length === 0) {
      this.needsAuth(this.text($r('app.string.action_repost')));
      return;
    }
    this.api.setRepost(t.id, reposted).then((ok: boolean) => {
      if (!ok) {
        promptAction.showToast({ message: this.apiFailMsg(this.text($r('app.string.action_repost'))), duration: 2000 });
      }
    });
  }

  private onReply(t: Tweet): void {
    this.openComposer('@' + t.author.username + ' ', t.id, t.author.username);
    if (authStore.isSignedIn()) {
      promptAction.showToast({ message: this.text($r('app.string.toast_replying_to')) + t.author.username, duration: 1500 });
    }
  }

  private goMe(): void {
    this.currentTab = 4;
    if (!this.supportsHdsFloatingMaterial()) {
      this.tabsController.changeIndex(4);
    }
  }

  private goLogin(): void {
    router.pushUrl({ url: 'pages/Login' });
  }

  private async signOut(): Promise<void> {
    const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    await authStore.signOut(ctx);
    this.handleText = '';
    this.liveBadge = '';
    await this.fetchPosts();
    promptAction.showToast({ message: this.text($r('app.string.toast_sign_out')), duration: 1500 });
  }

  build(): void {
    if (this.supportsHdsNavigation()) {
      HdsNavigation(this.navPathStack) {
        Stack({ alignContent: Alignment.TopStart }) {
          this.MainTabs()

          FloatingComposeButton({
            bottomInset: this.navigationIndicatorHeight,
            onCompose: (): void => {
              this.replyToId = '';
              this.replyToUser = '';
              this.openComposer('', '', '');
            }
          })
        }
        .width('100%')
        .height('100%')
      }
      .titleBar({
        style: this.titleBarStyle(),
        avoidLayoutSafeArea: true,
        content: {
          stackBuilder: (): void => this.ImmersiveTitleBarContent(),
          divider: { showType: DividerShowType.OFF }
        }
      })
      .titleMode(HdsNavigationTitleMode.MINI)
      .mode(NavigationMode.Stack)
      .hideBackButton(true)
      .bindToScrollable([
        this.homeScroller,
        this.exploreScroller,
        this.notificationsScroller,
        this.messagesScroller,
        this.profileScroller
      ])
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.BOTTOM])
      .width('100%')
      .height('100%')
    } else {
      Navigation() {
        Stack({ alignContent: Alignment.TopStart }) {
          this.MainTabs()
          FloatingComposeButton({
            bottomInset: 0,
            onCompose: (): void => {
              this.replyToId = '';
              this.replyToUser = '';
              this.openComposer('', '', '');
            }
          })
        }
        .width('100%')
        .height('100%')
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.bg_page'))
      .title(this.HomeTitle())
      .titleMode(NavigationTitleMode.Mini)
      .mode(NavigationMode.Stack)
      .hideBackButton(true)
    }
  }

  @Builder
  private MainTabs(): void {
    Stack({ alignContent: Alignment.BottomEnd }) {
      if (this.supportsHdsFloatingMaterial()) {
        HdsTabs({ controller: this.hdsTabsController, index: this.currentTab }) {
          this.HdsTabContents()
        }
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.bg_page'))
        .barPosition(BarPosition.End)
        .barOverlap(true)
        .scrollable(true)
        .animationDuration(0)
        .attributeModifier(this.hdsTabsModifier)
        .onChange((index: number) => {
          this.currentTab = index;
        })
      } else {
        Tabs({ barPosition: BarPosition.End, index: this.currentTab, controller: this.tabsController }) {
          this.LegacyTabContents()
        }
        .width('100%')
        .height('100%')
        .barBackgroundColor($r('app.color.bg_page'))
        .onChange((index: number) => {
          this.currentTab = index;
        })
      }

    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private HdsTabContents(): void {
    TabContent() {
      this.HomeTab()
    }
    .tabBar(this.HdsTabBar($r('sys.symbol.house_fill'), this.text($r('app.string.home_title'))))

    TabContent() {
      this.ExploreTab()
    }
    .tabBar(this.HdsTabBar($r('sys.symbol.magnifyingglass'), this.text($r('app.string.explore_title'))))

    TabContent() {
      this.NotificationsTab()
    }
    .tabBar(this.HdsTabBar($r('sys.symbol.bell_fill'), this.text($r('app.string.tab_alerts'))))

    TabContent() {
      this.MessagesTab()
    }
    .tabBar(this.HdsTabBar($r('sys.symbol.envelope'), this.text($r('app.string.messages_title'))))

    TabContent() {
      this.MeTab()
    }
    .tabBar(this.HdsTabBar($r('sys.symbol.person_fill'), this.text($r('app.string.tab_me'))))
  }

  @Builder
  private LegacyTabContents(): void {
    TabContent() {
      this.HomeTab()
    }
    .tabBar(this.TabBar(0, $r('sys.symbol.house'), $r('sys.symbol.house_fill'), this.text($r('app.string.home_title'))))

    TabContent() {
      this.ExploreTab()
    }
    .tabBar(this.TabBar(1, $r('sys.symbol.magnifyingglass'), $r('sys.symbol.magnifyingglass'), this.text($r('app.string.explore_title'))))

    TabContent() {
      this.NotificationsTab()
    }
    .tabBar(this.TabBar(2, $r('sys.symbol.bell'), $r('sys.symbol.bell_fill'), this.text($r('app.string.tab_alerts'))))

    TabContent() {
      this.MessagesTab()
    }
    .tabBar(this.TabBar(3, $r('sys.symbol.envelope'), $r('sys.symbol.envelope'), this.text($r('app.string.messages_title'))))

    TabContent() {
      this.MeTab()
    }
    .tabBar(this.TabBar(4, $r('sys.symbol.person'), $r('sys.symbol.person_fill'), this.text($r('app.string.tab_me'))))
  }

  private HdsTabBar(icon: Resource, label: string): BottomTabBarStyle {
    const normalGlyphModifier: SymbolGlyphModifier = new SymbolGlyphModifier(icon)
      .renderingStrategy(SymbolRenderingStrategy.SINGLE);
    normalGlyphModifier.fontColor([$r('sys.color.icon_primary')]);
    return BottomTabBarStyle.of({
      normal: normalGlyphModifier,
      selected: new SymbolGlyphModifier(icon).renderingStrategy(SymbolRenderingStrategy.SINGLE)
    }, label)
      .labelStyle({ unselectedColor: $r('sys.color.font_primary') })
      .padding({ bottom: 0 });
  }

  // Fallback for systems without API 26 material support.
  @Builder
  private HomeTitle(): void {
    Row({ space: 8 }) {
      Text(this.avatarInitial())
        .width(34)
        .height(34)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_on_brand'))
        .backgroundColor($r('app.color.brand'))
        .borderRadius(17)
        .textAlign(TextAlign.Center)
        .onClick(() => this.goMe())
      Blank()
      Text('𝕏')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Blank()
      Text(this.liveBadge.length > 0 ? '●' : '')
        .fontSize(10)
        .fontColor($r('app.color.repost'))
        .width(34)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: this.statusBarHeight + 8, bottom: 8 })
    .backgroundColor($r('app.color.bg_page'))
  }

  // The title bar owns the avatar and foreground mark so HdsNavigation can
  // blend it while the active page scrolls underneath.
  @Builder
  private ImmersiveTitleBarContent(): void {
    if (this.currentTab === 1) {
      Stack() {
        this.TitleBarIdentityRow()
        Row() {
          this.ExploreTitleBarSearch()
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .position({ x: 0, y: this.statusBarHeight + 42 })
      }
      .width('100%')
      .height('100%')
      .padding({ left: 12, right: 12 })
      .clip(false)
      .hitTestBehavior(HitTestMode.Transparent)
    } else {
      Stack() {
        this.TitleBarIdentityRow()
      }
      .width('100%')
      .height('100%')
      .padding({ left: 12, right: 12 })
      .hitTestBehavior(HitTestMode.Transparent)
    }
  }

  @Builder
  private TitleBarIdentityRow(): void {
    Stack({ alignContent: Alignment.Center }) {
      Row() {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          Text(this.avatarInitial())
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_on_brand'))
        }
        .width(36)
        .height(36)
        .padding(0)
        .backgroundColor($r('app.color.brand'))
        .accessibilityText(this.text($r('app.string.tab_me')))
        .onClick((): void => this.goMe())
        Blank()
        Text(this.liveBadge.length > 0 ? '●' : '')
          .width(36)
          .fontSize(10)
          .fontColor($r('app.color.repost'))
          .textAlign(TextAlign.End)
      }
      .width('100%')

      Image($r('app.media.icon_foreground'))
        .width(30)
        .height(30)
        .objectFit(ImageFit.Contain)
        .borderRadius(15)
        .clip(true)
    }
    .width('100%')
    .height(36)
  }

  private avatarInitial(): string {
    if (this.handleText.length > 1) {
      return this.handleText.substring(1, 2).toUpperCase();
    }
    return 'O';
  }

  @Builder
  private TabBar(index: number, icon: Resource, activeIcon: Resource, label: string): void {
    Column({ space: 2 }) {
      SymbolGlyph(this.currentTab === index ? activeIcon : icon)
        .fontSize(24)
        .fontColor([this.currentTab === index ? $r('app.color.brand') : $r('app.color.text_secondary')])
      Text(label)
        .fontSize(11)
        .fontColor(this.currentTab === index ? $r('app.color.brand') : $r('app.color.text_secondary'))
    }
    .justifyContent(FlexAlign.Center)
    .padding({ bottom: 10 })
  }

  @Builder
  private HomeTab(): void {
    Column() {
      if (this.loading && this.timeline.length === 0) {
        LoadingProgress().color($r('app.color.brand')).margin({ top: this.contentTopInset() + 32 })
        Blank().layoutWeight(1)
      } else {
        Refresh({ refreshing: $$this.refreshing }) {
          List({ space: 0, scroller: this.homeScroller }) {
            ListItem() {
              Text(this.statusLine)
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
                .width('100%')
                .padding({ left: 16, right: 16, top: this.contentTopInset(), bottom: 8 })
            }
            ForEach(this.timeline, (t: Tweet) => {
              ListItem() {
                TweetCard({
                  tweet: t,
                  onLikeChanged: (tt: Tweet, liked: boolean) => this.onLike(tt, liked),
                  onRepostChanged: (tt: Tweet, reposted: boolean) => this.onRepost(tt, reposted),
                  onReply: (tt: Tweet) => this.onReply(tt)
                })
              }
            }, (t: Tweet) => t.id)
          }
          .width('100%')
          .backgroundColor($r('app.color.bg_page'))
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
          .scrollBar(BarState.Auto)
        }
        .width('100%')
        .layoutWeight(1)
        .onRefreshing(() => {
          this.onRefresh();
        })
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private ExploreTab(): void {
    List({ scroller: this.exploreScroller }) {
      ListItem() {
        if (this.supportsHdsNavigation()) {
          Column()
            .width('100%')
            .height(this.exploreContentTopInset())
        } else {
          this.LegacyExploreSearchBar()
        }
      }
      ForEach(MockData.trends().filter((t: string) => {
          return this.searchText.trim().length === 0 ||
            t.toLowerCase().includes(this.searchText.trim().toLowerCase());
        }), (trend: string) => {
          ListItem() {
            Row({ space: 8 }) {
              SymbolGlyph($r('sys.symbol.magnifyingglass'))
                .fontSize(16)
                .fontColor([$r('app.color.text_secondary')])
              Text(trend)
                .fontSize(16)
                .fontColor($r('app.color.text_primary'))
                .layoutWeight(1)
            }
            .width('92%')
            .padding(12)
            .border({ width: { bottom: 1 }, color: $r('app.color.divider') })
            .visualEffect(new hdsEffect.HdsEffectBuilder()
              .pointLight({
                illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
              })
              .buildEffect())
          }
        }, (trend: string) => trend)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .scrollBar(BarState.Auto)
  }

  @Builder
  private ExploreTitleBarSearch(): void {
    if (this.supportsImmersiveMaterial()) {
      Stack() {
        Search({
          value: this.searchText,
          placeholder: $r('app.string.explore_title'),
          controller: this.searchController
        })
          .width('100%')
          .height(38)
          .backgroundColor(Color.Transparent)
          .fontColor($r('app.color.text_primary'))
          .onChange((v: string): void => {
            this.searchText = v;
          })
          .onSubmit((v: string): void => this.submitSearch(v))
      }
      .width('86%')
      .height(38)
      .borderRadius(20)
      .clip(true)
      .systemMaterial(new uiMaterial.ImmersiveMaterial({
        style: uiMaterial.ImmersiveStyle.THIN,
        colorInvert: true,
        applyShadow: true,
        lightEffect: { color: $r('app.color.brand') }
      }))
    } else {
      Search({
        value: this.searchText,
        placeholder: $r('app.string.explore_title'),
        controller: this.searchController
      })
        .width('86%')
        .height(38)
        .backgroundColor($r('app.color.bg_field'))
        .fontColor($r('app.color.text_primary'))
        .borderRadius(20)
        .onChange((v: string): void => {
          this.searchText = v;
        })
        .onSubmit((v: string): void => this.submitSearch(v))
    }
  }

  @Builder
  private LegacyExploreSearchBar(): void {
    Search({
      value: this.searchText,
      placeholder: $r('app.string.explore_title'),
      controller: this.searchController
    })
      .width('92%')
      .height(48)
      .margin({ top: this.contentTopInset(), bottom: 12 })
      .backgroundColor($r('app.color.bg_field'))
      .fontColor($r('app.color.text_primary'))
      .borderRadius(24)
      .onChange((v: string): void => {
        this.searchText = v;
      })
      .onSubmit((v: string): void => this.submitSearch(v))
  }

  private submitSearch(value: string): void {
    this.searchText = value;
    if (!authStore.isSignedIn()) {
      this.needsAuth(this.text($r('app.string.action_search_live')));
      return;
    }
    this.api.searchRecent(value).then((live: Tweet[] | null): void => {
      if (live !== null && live.length > 0) {
        this.timeline = live;
        this.currentTab = 0;
        if (!this.supportsHdsFloatingMaterial()) {
          this.tabsController.changeIndex(0);
        }
        promptAction.showToast({ message: live.length + this.text($r('app.string.toast_results_suffix')), duration: 1500 });
      } else {
        promptAction.showToast({ message: this.api.lastStatus() === 402 ?
          this.text($r('app.string.toast_search_paid_api')) : this.text($r('app.string.toast_no_live_results')), duration: 2000 });
      }
    });
  }

  @Builder
  private NotificationsTab(): void {
    List({ scroller: this.notificationsScroller }) {
      ListItem() {
        Column()
          .width('100%')
          .height(this.contentTopInset())
      }
      ForEach(MockData.notifications(), (n: AppNotification) => {
        ListItem() {
          Row({ space: 12 }) {
            if (n.kind === '♥') {
              SymbolGlyph($r('sys.symbol.heart_fill'))
                .fontSize(22)
                .fontColor([$r('app.color.like')])
            } else if (n.kind === '↻') {
              SymbolGlyph($r('sys.symbol.repeat'))
                .fontSize(22)
                .fontColor([$r('app.color.repost')])
            } else {
              SymbolGlyph($r('sys.symbol.person_fill'))
                .fontSize(22)
                .fontColor([$r('app.color.brand')])
            }
            Column({ space: 2 }) {
              Text(n.text).fontSize(15).fontColor($r('app.color.text_primary'))
              Text(n.time).fontSize(12).fontColor($r('app.color.text_secondary'))
            }
            .alignItems(HorizontalAlign.Start)
          }
          .width('92%')
          .padding(12)
          .border({ width: { bottom: 1 }, color: $r('app.color.divider') })
          .visualEffect(new hdsEffect.HdsEffectBuilder()
            .pointLight({
              illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
            })
            .buildEffect())
        }
      }, (n: AppNotification) => n.id)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .scrollBar(BarState.Auto)
  }

  @Builder
  private MessagesTab(): void {
    List({ scroller: this.messagesScroller }) {
      ListItem() {
        Column()
          .width('100%')
          .height(this.contentTopInset())
      }
      ForEach(MockData.messages(), (m: DirectMessage) => {
        ListItem() {
          Row({ space: 12 }) {
            Text(m.from.substring(0, 1).toUpperCase())
              .width(44)
              .height(44)
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_on_brand'))
              .backgroundColor($r('app.color.text_secondary'))
              .borderRadius(22)
              .textAlign(TextAlign.Center)
            Column({ space: 2 }) {
              Row() {
                Text(m.from).fontSize(15).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
                Blank()
                Text(m.time).fontSize(12).fontColor($r('app.color.text_secondary'))
              }
              .width('100%')
              Text(m.preview).fontSize(14).fontColor($r('app.color.text_secondary'))
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            if (m.unread > 0) {
              Text(m.unread.toString())
                .fontSize(12)
                .fontColor($r('app.color.text_on_brand'))
                .backgroundColor($r('app.color.brand'))
                .borderRadius(10)
                .padding({ left: 8, right: 8, top: 2, bottom: 2 })
            }
          }
          .width('92%')
          .padding(12)
          .border({ width: { bottom: 1 }, color: $r('app.color.divider') })
          .visualEffect(new hdsEffect.HdsEffectBuilder()
            .pointLight({
              illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
            })
            .buildEffect())
        }
      }, (m: DirectMessage) => m.id)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .scrollBar(BarState.Auto)
  }

  @Builder
  private MeTab(): void {
    Scroll(this.profileScroller) {
      Column({ space: 12 }) {
        // Profile header card.
        Column({ space: 6 }) {
          Text(this.avatarInitial())
            .width(64)
            .height(64)
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_on_brand'))
            .backgroundColor($r('app.color.brand'))
            .borderRadius(32)
            .textAlign(TextAlign.Center)
          Text(this.handleText.length > 0 ? this.handleText : $r('app.string.profile_welcome'))
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Row({ space: 4 }) {
            if (authStore.isSignedIn()) {
              SymbolGlyph($r('sys.symbol.checkmark'))
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor([$r('app.color.repost')])
            }
            Text(authStore.isSignedIn() ? $r('app.string.profile_signed_in') : $r('app.string.profile_browse_free'))
              .fontSize(13)
              .fontColor(authStore.isSignedIn() ? $r('app.color.repost') : $r('app.color.text_secondary'))
          }
        }
        .width('100%')
        .padding(16)
        .backgroundColor($r('app.color.bg_card'))
        .borderRadius(16)
        .margin({ left: 12, right: 12, top: 12 })
        .visualEffect(new hdsEffect.HdsEffectBuilder()
          .pointLight({
            illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
          })
          .buildEffect())

        if (authStore.isSignedIn()) {
          Button($r('app.string.profile_sign_out'), { stateEffect: true })
            .width('92%')
            .backgroundColor($r('app.color.bg_secondary_btn'))
            .fontColor($r('app.color.danger'))
            .onClick(() => this.signOut())
        } else {
          Button($r('app.string.profile_sign_in'), { stateEffect: true })
            .width('92%')
            .backgroundColor($r('app.color.brand'))
            .fontColor($r('app.color.text_on_brand'))
            .onClick(() => this.goLogin())
        }

        Text($r('app.string.profile_version'))
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 8 })
      }
      .width('100%')
      .padding({ top: this.contentTopInset(), bottom: this.navigationIndicatorHeight + 96 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .scrollBar(BarState.Auto)
  }
}
