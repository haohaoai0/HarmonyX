// OpenTwit main page — iOS-X-style layout built with HarmonyOS design
// components: Navigation + bottom Tabs, SymbolGlyph tab/action icons,
// floating compose button opening a bottom-sheet composer, Search,
// pull-to-refresh, toasts. Theme resources (base + dark) follow the device
// light/dark mode; text uses HarmonyOS Sans (system default).
// The timeline is open (sample posts, zero setup). OAuth sign-in — the only
// auth method — unlocks live data and interactions.
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import common from '@ohos.app.ability.common';
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

  build(): void {
    Column({ space: 12 }) {
      Row() {
        Button('Cancel', { stateEffect: true })
          .fontSize(15)
          .backgroundColor($r('app.color.bg_secondary_btn'))
          .fontColor($r('app.color.text_primary'))
          .onClick(() => this.onCancel())
        Blank()
        Button('Post', { stateEffect: true })
          .fontSize(15)
          .backgroundColor($r('app.color.brand'))
          .fontColor($r('app.color.text_on_brand'))
          .enabled(this.draft.trim().length > 0)
          .onClick(() => this.onPost(this.draft))
      }
      .width('100%')
      if (this.replyUser.length > 0) {
        Text('Replying to @' + this.replyUser)
          .fontSize(13)
          .fontColor($r('app.color.brand'))
          .width('100%')
      }
      TextArea({ placeholder: "What's happening?", text: this.draft })
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
  @State statusLine: string = 'Loading…';
  @State searchText: string = '';
  @State refreshing: boolean = false;
  @State loading: boolean = true;
  @State handleText: string = '';
  @State liveBadge: string = '';
  private api: XApiClient = new XApiClient();
  private tabsController: TabsController = new TabsController();
  private composeController: CustomDialogController | null = null;

  aboutToAppear(): void {
    this.loadTimeline();
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
      this.liveBadge = ' · Live';
      if (authStore.getUserId().length > 0) {
        this.statusLine = 'Home timeline · live for ' + this.handleText;
      } else {
        this.statusLine = 'Live search · X API v2';
      }
    } else {
      this.timeline = MockData.timeline();
      this.liveBadge = '';
      if (!authStore.isSignedIn()) {
        this.statusLine = 'Sample posts · sign in for live';
      } else if (this.api.lastStatus() === 402) {
        this.statusLine = 'X needs paid API access (402) · samples shown';
      } else {
        this.statusLine = 'Offline — X unreachable, showing samples';
      }
    }
  }

  private needsAuth(what: string): boolean {
    if (authStore.isSignedIn()) {
      return false;
    }
    promptAction.showToast({ message: 'Sign in with X to ' + what, duration: 2000 });
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
    if (this.needsAuth(replyToId.length > 0 ? 'reply' : 'post')) {
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
        name: this.handleText.length > 0 ? this.handleText : 'You',
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
      promptAction.showToast({ message: ok ? 'Published to X ✓' : this.apiFailMsg('Post'), duration: 2000 });
    });
  }

  private apiFailMsg(action: string): string {
    if (this.api.lastStatus() === 402) {
      return 'X requires paid API access (402)';
    }
    return action + ' kept locally — X unreachable';
  }

  private onLike(t: Tweet, liked: boolean): void {
    if (!authStore.isSignedIn() || authStore.getUserId().length === 0) {
      this.needsAuth('like posts');
      return;
    }
    this.api.setLike(t.id, liked).then((ok: boolean) => {
      if (!ok) {
        promptAction.showToast({ message: this.apiFailMsg('Like'), duration: 2000 });
      }
    });
  }

  private onRepost(t: Tweet, reposted: boolean): void {
    if (!authStore.isSignedIn() || authStore.getUserId().length === 0) {
      this.needsAuth('repost');
      return;
    }
    this.api.setRepost(t.id, reposted).then((ok: boolean) => {
      if (!ok) {
        promptAction.showToast({ message: this.apiFailMsg('Repost'), duration: 2000 });
      }
    });
  }

  private onReply(t: Tweet): void {
    this.openComposer('@' + t.author.username + ' ', t.id, t.author.username);
    if (authStore.isSignedIn()) {
      promptAction.showToast({ message: 'Replying to @' + t.author.username, duration: 1500 });
    }
  }

  private goMe(): void {
    this.currentTab = 4;
    this.tabsController.changeIndex(4);
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
    promptAction.showToast({ message: 'Signed out', duration: 1500 });
  }

  build(): void {
    Navigation() {
      Stack({ alignContent: Alignment.BottomEnd }) {
        Tabs({ barPosition: BarPosition.End, index: this.currentTab, controller: this.tabsController }) {
          TabContent() {
            this.HomeTab()
          }
          .tabBar(this.TabBar(0, $r('sys.symbol.house'), $r('sys.symbol.house_fill'), 'Home'))

          TabContent() {
            this.ExploreTab()
          }
          .tabBar(this.TabBar(1, $r('sys.symbol.magnifyingglass'), $r('sys.symbol.magnifyingglass'), 'Explore'))

          TabContent() {
            this.NotificationsTab()
          }
          .tabBar(this.TabBar(2, $r('sys.symbol.bell'), $r('sys.symbol.bell_fill'), 'Alerts'))

          TabContent() {
            this.MessagesTab()
          }
          .tabBar(this.TabBar(3, $r('sys.symbol.envelope'), $r('sys.symbol.envelope'), 'DMs'))

          TabContent() {
            this.MeTab()
          }
          .tabBar(this.TabBar(4, $r('sys.symbol.person'), $r('sys.symbol.person_fill'), 'Me'))
        }
        .width('100%')
        .height('100%')
        .barBackgroundColor($r('app.color.bg_page'))
        .onChange((index: number) => {
          this.currentTab = index;
        })

        // iOS-style floating compose button.
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.square_and_pencil'))
            .fontSize(24)
            .fontColor([$r('app.color.text_on_brand')])
        }
        .width(56)
        .height(56)
        .backgroundColor($r('app.color.brand'))
        .margin({ right: 16, bottom: 96 })
        .onClick(() => {
          this.replyToId = '';
          this.replyToUser = '';
          this.openComposer('', '', '');
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
    .hideBackButton(true)
  }

  // iOS X top bar: profile avatar left, 𝕏 centered. System title is kept
  // adaptive-safe by using theme colors (never hardcoded).
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
    .padding({ left: 4, right: 4 })
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
      Text(this.statusLine)
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .padding({ left: 16, top: 8, bottom: 2 })

      if (this.loading && this.timeline.length === 0) {
        LoadingProgress().color($r('app.color.brand')).margin({ top: 32 })
        Blank().layoutWeight(1)
      } else {
        Refresh({ refreshing: $$this.refreshing }) {
          List({ space: 0 }) {
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
    Column({ space: 8 }) {
      Search({
        value: this.searchText,
        placeholder: 'Search X',
        controller: new SearchController()
      })
        .width('92%')
        .margin({ top: 12 })
        .backgroundColor($r('app.color.bg_field'))
        .fontColor($r('app.color.text_primary'))
        .onChange((v: string) => {
          this.searchText = v;
        })
        .onSubmit((v: string) => {
          this.searchText = v;
          if (!authStore.isSignedIn()) {
            this.needsAuth('search live');
            return;
          }
          this.api.searchRecent(v).then((live: Tweet[] | null) => {
            if (live !== null && live.length > 0) {
              this.timeline = live;
              this.currentTab = 0;
              this.tabsController.changeIndex(0);
              promptAction.showToast({ message: live.length + ' results', duration: 1500 });
            } else {
              promptAction.showToast({ message: this.api.lastStatus() === 402 ? 'Search needs paid API access (402)' : 'No live results — try again', duration: 2000 });
            }
          });
        })
      List() {
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
          }
        }, (trend: string) => trend)
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private NotificationsTab(): void {
    List() {
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
        }
      }, (n: AppNotification) => n.id)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private MessagesTab(): void {
    List() {
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
        }
      }, (m: DirectMessage) => m.id)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private MeTab(): void {
    Scroll() {
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
          Text(this.handleText.length > 0 ? this.handleText : 'Welcome to OpenTwit')
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
            Text(authStore.isSignedIn() ? 'Signed in with X' : 'Browse free · sign in for live')
              .fontSize(13)
              .fontColor(authStore.isSignedIn() ? $r('app.color.repost') : $r('app.color.text_secondary'))
          }
        }
        .width('100%')
        .padding(16)
        .backgroundColor($r('app.color.bg_card'))
        .borderRadius(16)
        .margin({ left: 12, right: 12, top: 12 })

        if (authStore.isSignedIn()) {
          Button('Sign out', { stateEffect: true })
            .width('92%')
            .backgroundColor($r('app.color.bg_secondary_btn'))
            .fontColor($r('app.color.danger'))
            .onClick(() => this.signOut())
        } else {
          Button('Sign in with X', { stateEffect: true })
            .width('92%')
            .backgroundColor($r('app.color.brand'))
            .fontColor($r('app.color.text_on_brand'))
            .onClick(() => this.goLogin())
        }

        Text('OpenTwit 1.0.0 · HarmonyOS 6.1 (API 24) · Stage model')
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 8 })
      }
      .width('100%')
      .padding({ bottom: 24 })
    }
    .width('100%')
    .height('100%')
  }
}
