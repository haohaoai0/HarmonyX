import { pageTextColor } from '../utils/ThemeColors';
import { appPageBackground } from '../components/PageBackgroundLayer';
import { pageCanvasColor, pageReadingSurfaceColor } from '../utils/ThemeColors';
import { STORAGE_KEY_PAGE_TRANSITION_MODE, DEFAULT_PAGE_TRANSITION_MODE } from '../services/PageTransitionSettingsStore';
import { pageSystemTransition, PageTransitionMotion } from '../utils/PageTransition';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { AnimatedIconTabs } from '../components/AnimatedIconTabs';
import { ProfileTabMotion } from '../utils/ProfileTabMotion';
import { userAvatarRadius, verificationBadgeColor } from '../utils/UserIdentity';
import { common } from '@kit.AbilityKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { uiMaterial } from '@kit.ArkUI';
import { HdsNavDestination, HdsNavDestinationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import promptAction from '@ohos.promptAction';
import { ProxyAvatar } from '../components/ProxyAvatar';
import { UserRowCard } from '../components/UserRowCard';
import type { UserRow } from '../models/Tweet';
import { FollowDiscoveryData } from '../services/FollowDiscoveryData';
import { StarterPackCategory, StarterPackGroup, StarterPackPage } from '../services/XStarterPackParser';
import { followStateStore, STORAGE_KEY_FOLLOW_REVISION } from '../services/FollowStateStore';
import { XPrivateResult, xPrivateClient } from '../services/XPrivateClient';
import { destinationTitleBarStyle } from '../utils/DestinationTitleBar';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';
import { pageSurfaceColor } from '../utils/ThemeColors';
import type { UserDetailRouteParam } from './UserDetail';
import type { ProfileWebRouteParam } from './ProfileWeb';
import { materialModifier } from '../utils/SystemMaterial';

export interface FollowDiscoveryRouteParam {
  tab: number;
  contextualUserId: string;
}

@Builder
export function FollowDiscoveryBuilder(): void { FollowDiscovery(); }

@Component
export struct FollowDiscovery {
  @StorageProp('harmonyx.page_background') private pageBackgroundValue: string = '';
  @State private pageMotion: PageTransitionMotion = new PageTransitionMotion();
  @StorageProp(STORAGE_KEY_PAGE_TRANSITION_MODE) private pageTransitionMode: string = DEFAULT_PAGE_TRANSITION_MODE;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp('harmonyx.status_bar_height') statusBarHeight: number = 0;
  @StorageProp('harmonyx.navigation_indicator_height') navigationIndicatorHeight: number = 0;
  @StorageLink('harmonyx.accent_color') accentColor: string = '#007DFF';
  @StorageProp('harmonyx.display_mode') themeDisplayMode: string = '';
  @StorageProp('harmonyx.dark_surface') themeDarkSurface: string = '';
  @StorageLink('harmonyx.title_bar_style_mode') titleBarStyleMode: number = 0;
  @StorageProp(STORAGE_KEY_FOLLOW_REVISION) @Watch('syncFollowState') followRevision: number = 0;
  @State private tab: number = 0;
  @State private tabPosition: number = 0;
  @State private pageStatuses: string[] = ['', '', ''];
  private pager: SwiperController = new SwiperController();
  private pageScrollers: Scroller[] = [new Scroller(), new Scroller(), new Scroller()];
  private pageTokens: string[] = ['', '', ''];
  @State private selectedCategory: number = 0;
  @State private categories: StarterPackCategory[] = [];
  @State private packs: StarterPackGroup[] = [];
  @State private rows: UserRow[] = [];
  @State private loading: boolean = true;
  @State private loadingMore: boolean = false;
  @State private refreshing: boolean = false;
  @State private status: string = '';
  @State private pendingGroup: string = '';
  private contextualUserId: string = '';
  private viewerId: string = '';
  private nextToken: string = '';
  private requestId: number = 0;
  private alive: boolean = true;
  private get scroller(): Scroller { return this.pageScrollers[this.tab]; }
  private followedPacks: Set<string> = new Set<string>();

  aboutToAppear(): void {
    this.alive = true;
    setTimeout((): void => {
      if (!this.alive) { return; }
      const params: FollowDiscoveryRouteParam[] = this.pageStack.getParamByName('FollowDiscovery') as FollowDiscoveryRouteParam[];
      if (params !== undefined && params.length > 0) {
        const param: FollowDiscoveryRouteParam = params[params.length - 1];
        this.tab = Math.max(0, Math.min(2, param.tab));
        this.contextualUserId = param.contextualUserId;
      }
      this.load(true);
    }, 30);
  }

  aboutToDisappear(): void { this.alive = false; this.requestId++; }

  private text(resource: Resource): string {
    return (getContext(this) as common.UIAbilityContext).resourceManager.getStringSync(resource);
  }

  private async load(reset: boolean): Promise<void> {
    if (!reset && (this.loading || this.loadingMore || this.nextToken.length === 0)) { return; }
    const request: number = ++this.requestId;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    xPrivateClient.load(context);
    this.viewerId = xPrivateClient.viewerId();
    const viewer: string = this.viewerId;
    if (!xPrivateClient.isSignedIn()) {
      this.status = this.text($r('app.string.follow_sign_in'));
      this.loading = false; this.loadingMore = false; this.refreshing = false;
      return;
    }
    if (reset) { this.loading = true; this.status = ''; }
    else { this.loadingMore = true; }
    const cursor: string = reset ? '' : this.nextToken;
    try {
      if (this.tab === 0) { await this.loadPacks(reset, request, viewer); return; }
      if (this.tab === 1) { this.nextToken = ''; return; }
      const result: XPrivateResult = await xPrivateClient.connectPeople(this.contextualUserId, cursor);
      if (!this.alive || request !== this.requestId || viewer !== xPrivateClient.viewerId()) { return; }
      if (!result.ok) {
        this.status = this.text($r('app.string.follow_load_failed')) + ' · HTTP ' + result.status;
        return;
      }
      const page: FollowDiscoveryData | null = FollowDiscoveryData.parse(result.body);
      if (page === null) { this.status = this.text($r('app.string.follow_load_failed')); return; }
      const fresh: UserRow[] = page.users.filter((row: UserRow): boolean =>
        row.id !== viewer && row.id !== this.contextualUserId && !row.following);
      this.rows = followStateStore.apply(viewer,
        reset ? fresh : FollowDiscoveryData.unique([...this.rows, ...fresh]));
      this.nextToken = page.nextToken === cursor ? '' : page.nextToken;
      this.status = this.rows.length === 0 ? this.text($r('app.string.follow_empty')) : '';
      this.syncFollowState();
    } catch (error) {
      if (this.alive && request === this.requestId) {
        this.status = this.text($r('app.string.follow_load_failed'));
      }
    } finally {
      if (this.alive && request === this.requestId) {
        this.loading = false; this.loadingMore = false; this.refreshing = false;
      }
    }
  }

  private syncFollowState(): void {
    this.rows = followStateStore.apply(this.viewerId, this.rows);
  }

  private async loadPacks(reset: boolean, request: number, viewer: string): Promise<void> {
    if (this.categories.length === 0) {
      const catalog: XPrivateResult = await xPrivateClient.starterPacks();
      if (!this.alive || request !== this.requestId || viewer !== xPrivateClient.viewerId()) { return; }
      if (!catalog.ok) { this.status = this.text($r('app.string.follow_packs_load_failed')); return; }
      const page: StarterPackPage = JSON.parse(catalog.body) as StarterPackPage;
      this.categories = page.categories;
      this.selectedCategory = 0;
    }
    if (this.categories.length === 0) { this.status = this.text($r('app.string.follow_empty')); return; }
    const path: string = reset ? this.categories[this.selectedCategory].path : this.nextToken;
    const result: XPrivateResult = await xPrivateClient.starterPacks(path);
    if (!this.alive || request !== this.requestId || viewer !== xPrivateClient.viewerId()) { return; }
    if (!result.ok) { this.status = this.text($r('app.string.follow_packs_load_failed')); return; }
    const page: StarterPackPage = JSON.parse(result.body) as StarterPackPage;
    const packs: StarterPackGroup[] = reset ? [] : this.packs.slice();
    for (let i: number = 0; i < page.groups.length; i++) {
      const group: StarterPackGroup = page.groups[i];
      group.followed = group.followed || this.followedPacks.has(viewer + ':' + group.id);
      if (!packs.some((pack: StarterPackGroup): boolean => pack.id === group.id)) { packs.push(group); }
    }
    this.packs = packs;
    this.nextToken = page.nextPath === path ? '' : page.nextPath;
    this.status = packs.length === 0 ? this.text($r('app.string.follow_empty')) : '';
  }

  private openUser(row: UserRow): void {
    const param: UserDetailRouteParam = { author: { id: row.id, name: row.name, username: row.username,
      avatarUrl: row.avatarUrl, avatarColor: row.avatarColor, verified: row.verified, verifiedType: row.verifiedType, avatarShape: row.avatarShape }, posts: [] };
    this.pageStack.pushPath({ name: 'UserDetail', param: param });
  }

  private async follow(row: UserRow, next: boolean): Promise<boolean> {
    const viewer: string = this.viewerId;
    if (viewer !== xPrivateClient.viewerId() || !xPrivateClient.isSignedIn()) { return false; }
    const result: XPrivateResult = await xPrivateClient.follow(row.id, next);
    if (viewer !== xPrivateClient.viewerId() || !this.alive) { return false; }
    if (!result.ok) {
      promptAction.showToast({ message: this.text($r('app.string.profile_follow_failed')) });
      return false;
    }
    followStateStore.set(viewer, row.id, next);
    return true;
  }

  private async followPack(group: StarterPackGroup): Promise<void> {
    if (this.pendingGroup.length > 0) { return; }
    const viewer: string = this.viewerId;
    if (viewer !== xPrivateClient.viewerId() || !xPrivateClient.isSignedIn()) { return; }
    this.pendingGroup = group.id;
    try {
      const result: XPrivateResult = await xPrivateClient.followStarterPack(group.id);
      if (viewer !== xPrivateClient.viewerId()) { return; }
      if (!result.ok) {
        if (this.alive) { promptAction.showToast({ message: this.text(result.errorText === 'starter_pack_rate_limited' ?
          $r('app.string.follow_packs_rate_limited') : $r('app.string.profile_follow_failed')) }); }
        return;
      }
      this.followedPacks.add(viewer + ':' + group.id);
      if (!this.alive) { return; }
      this.packs = this.packs.map((pack: StarterPackGroup): StarterPackGroup => {
        const copy: StarterPackGroup = new StarterPackGroup();
        copy.id = pack.id; copy.title = pack.title; copy.description = pack.description;
        copy.users = pack.users; copy.memberCount = pack.memberCount;
        copy.followed = pack.followed || pack.id === group.id;
        return copy;
      });
    } finally { this.pendingGroup = ''; }
  }

  @Builder
  private TabsBar(): void {
    AnimatedIconTabs({ items: [
      { key: 'discovery', label: $r('app.string.follow_discovery_title'), icon: $r('sys.symbol.person_2') },
      { key: 'contacts', label: $r('app.string.follow_people_you_know'), icon: $r('sys.symbol.person') },
      { key: 'recommended', label: $r('app.string.follow_recommended'), icon: $r('sys.symbol.star') }
    ], selected: this.tab, tabPosition: this.tabPosition, showDivider: true,
      onSelect: (index: number): void => { this.pager.changeIndex(index, true); } })
  }

  private selectDiscoveryTab(index: number): void {
    if (this.tab === index) { return; }
    const statuses: string[] = this.pageStatuses.slice();
    statuses[this.tab] = this.status;
    this.pageStatuses = statuses;
    this.pageTokens[this.tab] = this.nextToken;
    this.tab = index;
    this.nextToken = this.pageTokens[index];
    this.status = this.pageStatuses[index];
    this.load(true);
  }

  private contentStatus(index: number): string { return index === this.tab ? this.status : this.pageStatuses[index]; }

  @Builder
  private FindFriends(): void {
    Column({ space: 12 }) {
      Text($r('app.string.follow_find_friends')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Title_L')).fontWeight(FontWeight.Bold)
        .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent)).width('100%')
      Text($r('app.string.follow_contacts_description')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L'))
        .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)).width('100%')
      Text($r('app.string.follow_contacts_sdk_unavailable')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
        .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)).width('100%')
      Button($r('app.string.follow_contacts_open_x')).fontSize($r('sys.float.Body_L')).fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_on_inverse')).backgroundColor($r('app.color.text_primary'))
        .height(44).width('100%').margin({ top: 4 })
        .onClick((): void => {
          const param: ProfileWebRouteParam = { url: 'https://x.com/settings/contacts',
            title: this.text($r('app.string.follow_find_friends')) };
          this.pageStack.pushPath({ name: 'ProfileWeb', param: param });
        })
    }.alignItems(HorizontalAlign.Start).padding(24).width('100%')
  }

  @Builder
  private CategoryBar(): void {
    Scroll() {
      Row({ space: 10 }) {
        ForEach(this.categories, (category: StarterPackCategory, index: number) => {
          Button(this.categoryTitle(category.title))
            .fontSize($r('sys.float.Body_L')).fontWeight(FontWeight.Bold)
            .height($r('app.float.follow_category_height')).padding({ left: 18, right: 18 })
            .backgroundColor(index === this.selectedCategory ? this.accentColor : Color.Transparent)
            .fontColor(index === this.selectedCategory ? $r('app.color.text_on_accent') : pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, index === this.selectedCategory ? this.accentColor : Color.Transparent))
            .border({ width: 1, color: index === this.selectedCategory ? Color.Transparent : $r('app.color.divider') })
            .onClick((): void => {
              if (this.selectedCategory === index) { return; }
              this.selectedCategory = index; this.packs = []; this.nextToken = ''; this.load(true);
            })
        }, (category: StarterPackCategory): string => category.id)
      }.padding({ left: 16, right: 16, top: 12, bottom: 12 })
    }.width('100%').scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
  }

  private categoryTitle(title: string): string {
    const names: string[] = ['News', 'Sports', 'Business & Finance', 'Technology', 'Politics', 'Memes',
      'Cryptocurrency', 'Art', 'Gaming', 'Movies & TV', 'Music', 'Travel', 'Food', 'Health & Fitness',
      'Soccer', 'Celebrity', 'Pets'];
    const keys: string[] = ['news', 'sports', 'business', 'technology', 'politics', 'memes', 'crypto', 'art',
      'gaming', 'movies', 'music', 'travel', 'food', 'health', 'soccer', 'celebrity', 'pets'];
    const index: number = names.indexOf(title);
    return index < 0 ? title : (getContext(this) as common.UIAbilityContext).resourceManager
      .getStringByNameSync('follow_category_' + keys[index]);
  }

  @Builder
  private PackGroup(pack: StarterPackGroup): void {
    Column({ space: 12 }) {
      Row({ space: 12 }) {
        Text(pack.title).fontFamily(this.appFontFamily).fontSize($r('sys.float.Subtitle_L')).fontWeight(FontWeight.Bold)
          .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent)).layoutWeight(1)
        Button(pack.followed ? this.text($r('app.string.follow_pack_followed')) :
          this.text($r('app.string.profile_detail_follow')) + ' ' + pack.memberCount)
          .height($r('app.float.follow_button_height')).padding({ left: 22, right: 22 })
          .fontSize($r('sys.float.Body_M')).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_on_inverse')).backgroundColor($r('app.color.text_primary'))
          .enabled(this.pendingGroup.length === 0 && !pack.followed)
          .onClick((): void => { this.followPack(pack); })
      }.width('100%').padding({ left: 16, right: 16 })
      if (pack.description.length > 0) {
        Text(pack.description).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
          .width('100%').padding({ left: 16, right: 16 })
      }
      Scroll() {
        Row({ space: 12 }) {
          ForEach(pack.users, (row: UserRow) => {
            Column({ space: 6 }) {
              ProxyAvatar({verifiedType: row.verifiedType ?? '', avatarShape: row.avatarShape ?? '',  url: row.avatarUrl, avatarSize: 68, radius: 34,
                fallbackText: row.name.substring(0, 1), fallbackColor: row.avatarColor })
              Row({ space: 3 }) {
                Text(row.name).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontWeight(FontWeight.Bold)
                  .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent)).maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis }).constraintSize({ maxWidth: 86 })
                if (row.verified) {
                  SymbolGlyph($r('sys.symbol.checkmark_circle_fill')).fontSize(12)
                    .fontColor([verificationBadgeColor(row.verifiedType ?? '', this.accentColor)])
                }
              }.justifyContent(FlexAlign.Center).width('100%')
              Text('@' + row.username).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
                .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%').textAlign(TextAlign.Center)
            }.width($r('app.float.follow_pack_member_width')).padding({ top: 8, bottom: 8 })
              .onClick((): void => { this.openUser(row); })
          }, (row: UserRow): string => row.username)
        }.padding({ left: 16, right: 16 })
      }.width('100%').scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
    }.width('100%').padding({ top: 16, bottom: 24 }).alignItems(HorizontalAlign.Start)
  }

  @Builder
  private Content(index: number): void {
    if (index === 1 || index === 2) { ListItem() { this.FindFriends() } }
    if (index === 0 && this.categories.length > 0) { ListItem() { this.CategoryBar() } }
    if (index === this.tab && this.loading && (index === 0 || this.rows.length === 0)) {
      ListItem() { LoadingProgress().width(30).height(30).color(this.accentColor).margin(32) }
    } else if (index === 0) {
      ForEach(this.packs, (pack: StarterPackGroup) => {
        ListItem() { this.PackGroup(pack) }
      }, (pack: StarterPackGroup): string => pack.id)
    } else if (index !== 1 && this.rows.length > 0) {
      ListItem() {
        Text($r('app.string.follow_for_you')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Subtitle_L')).fontWeight(FontWeight.Bold)
          .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent)).width('100%').padding(16)
      }
      ForEach(this.rows, (row: UserRow) => {
        ListItem() {
          UserRowCard({ row: row, onOpen: (r: UserRow): void => this.openUser(r),
            onFollowChanged: (r: UserRow, next: boolean): Promise<boolean> => this.follow(r, next) })
        }
      }, (row: UserRow): string => row.id)
    }
    if (this.contentStatus(index).length > 0 && index !== 1) {
      ListItem() {
        Column({ space: 12 }) {
          Text(this.contentStatus(index)).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
            .textAlign(TextAlign.Center)
          Button($r('app.string.profile_retry')).backgroundColor(Color.Transparent).fontColor(this.accentColor)
            .onClick((): void => { this.load(true); })
        }.width('100%').padding(24)
      }
    }
    if ((index === this.tab ? this.nextToken : this.pageTokens[index]).length > 0 && index !== 1) {
      ListItem() {
        Button($r('app.string.timeline_load_more')).backgroundColor(Color.Transparent).fontColor(this.accentColor)
          .enabled(!this.loadingMore).onClick((): void => { this.load(false); })
      }
    }
  }

  @Builder
  private DiscoveryPage(index: number): void {
    List({ scroller: this.pageScrollers[index] }) { this.Content(index) }
      .width('100%').height('100%').scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .nestedScroll({ scrollForward: NestedScrollMode.SELF_FIRST, scrollBackward: NestedScrollMode.SELF_FIRST })
      .contentEndOffset(this.navigationIndicatorHeight + 24)
      .onReachEnd((): void => { if (index === this.tab && index !== 1) { this.load(false); } })
  }

  build(): void {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        appPageBackground()
      Column() {
        this.TabsBar()
        Refresh({ refreshing: $$this.refreshing }) {
        Swiper(this.pager) {
          ForEach([0, 1, 2], (index: number) => { this.DiscoveryPage(index) }, (index: number): string => index.toString())
        }.width('100%').height('100%').index(this.tab).loop(false).indicator(false).cachedCount(1)
          .duration(280).curve(Curve.EaseOut).clip(true).disableSwipe(this.refreshing)
          .onAppear((): void => { this.tabPosition = this.tab; })
          .onChange((index: number): void => { this.selectDiscoveryTab(index); })
          .onContentDidScroll((_selected: number, index: number, position: number, _length: number): void => {
            this.tabPosition = ProfileTabMotion.scrollPosition(index, position, 3);
          })
          .onAnimationEnd((index: number): void => { this.tabPosition = index; })
        }.width('100%').layoutWeight(1).onRefreshing((): void => { this.load(true); })
      }.width('100%').height('100%').padding({ top: this.statusBarHeight + 60 })
    
      }.width('100%').height('100%')
    }
    .scale({ x: this.pageMotion.scale, y: this.pageMotion.scale })
    .opacity(this.pageMotion.opacity)
    .onReady((context: NavDestinationContext): void => { this.pageMotion.attach(context); })
    .systemTransition(pageSystemTransition(this.pageTransitionMode))
    .titleMode(HdsNavDestinationTitleMode.MINI).hideBackButton(false)
    .onBackPressed((): boolean => { ResponsiveLayout.closeContentDestination(this.pageStack); return true; })
    .bindToScrollable(this.pageScrollers)
    .titleBar({ avoidLayoutSafeArea: true,
      content: { title: { mainTitle: this.text($r('app.string.follow_discovery_title')) } },
      style: destinationTitleBarStyle(ScrollEffectType.IMMERSIVE_GRADIENT_BLUR,
        this.themeDisplayMode, this.themeDarkSurface, this.titleBarStyleMode) })
    .backgroundColor(pageCanvasColor(this.themeDisplayMode, this.themeDarkSurface, this.pageBackgroundValue))
    .attributeModifier(materialModifier(deviceInfo.apiAvailable('26.0.0') ? new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.REGULAR, applyShadow: true, colorInvert: true }) : undefined));
  }
}
