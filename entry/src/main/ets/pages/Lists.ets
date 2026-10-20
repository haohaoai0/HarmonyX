import { pinnedHomeListStore } from '../services/PinnedHomeListStore';
import { DesktopLayout } from '../utils/DesktopLayout';
import { pageTextColor } from '../utils/ThemeColors';
import { appPageBackground } from '../components/PageBackgroundLayer';
import { pageCanvasColor, pageReadingSurfaceColor } from '../utils/ThemeColors';
import { STORAGE_KEY_PAGE_TRANSITION_MODE, DEFAULT_PAGE_TRANSITION_MODE } from '../services/PageTransitionSettingsStore';
import { pageSystemTransition, PageTransitionMotion } from '../utils/PageTransition';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import common from '@ohos.app.ability.common';
import { deviceInfo } from '@kit.BasicServicesKit';
import { uiMaterial } from '@kit.ArkUI';
import { HdsNavDestination, HdsNavDestinationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import promptAction from '@ohos.promptAction';
import { ProxyAvatar } from '../components/ProxyAvatar';
import { ListCover } from '../components/ListCover';
import { FloatingComposeButton } from '../components/FloatingComposeButton';
import type { ListPage, ListRow } from '../models/Tweet';
import { xPrivateClient, XPrivateClient, XPrivateResult } from '../services/XPrivateClient';
import { XListParser } from '../services/XListParser';
import { copyList, listStateStore } from '../services/ListStateStore';
import { accountStore, XAccount } from '../services/AccountStore';
import { destinationTitleBarStyle } from '../utils/DestinationTitleBar';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';
import { pageSurfaceColor } from '../utils/ThemeColors';
import { materialModifier } from '../utils/SystemMaterial';

export interface ListsRouteParam { userId: string; memberships: boolean; title: string; }
export interface ListTimelineRouteParam { listId: string; title: string; row?: ListRow; }
export interface ListEditorRouteParam { row?: ListRow; }
export interface ListMembersRouteParam {
  listId: string;
  title: string;
  row?: ListRow;
  manage?: boolean;
  creating?: boolean;
}

@Builder
export function ListsBuilder(): void { Lists(); }

@Component
export struct Lists {
  @StorageProp('harmonyx.page_background') private pageBackgroundValue: string = '';
  @State private pageMotion: PageTransitionMotion = new PageTransitionMotion();
  @StorageProp(STORAGE_KEY_PAGE_TRANSITION_MODE) private pageTransitionMode: string = DEFAULT_PAGE_TRANSITION_MODE;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp('harmonyx.status_bar_height') statusBarHeight: number = 0;
  @StorageProp('harmonyx.navigation_indicator_height') navigationIndicatorHeight: number = 0;
  @StorageLink('harmonyx.accent_color') accentColor: string = '#007DFF';
  @StorageProp('harmonyx.display_mode') private themeDisplayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private themeDarkSurface: string = '';
  @StorageLink('harmonyx.title_bar_style_mode') titleBarStyleMode: number = 0;
  @StorageProp('harmonyx.desktop_layout') desktopLayoutEnabled: boolean = false;
  @StorageProp('harmonyx.breakpoint') windowBreakpoint: string = 'sm';
  @State private rows: ListRow[] = [];
  @State private searchRows: ListRow[] = [];
  @State private query: string = '';
  @State private submittedQuery: string = '';
  @State private status: string = '';
  @State private loading: boolean = true;
  @State private loadingMore: boolean = false;
  @State private refreshing: boolean = false;
  @State private pendingIds: string[] = [];
  @State private title: string = '';
  @State private username: string = '';
  private nextToken: string = '';
  private directoryOperation: string = '';
  private userId: string = '';
  private memberships: boolean = false;
  private scroller: Scroller = new Scroller();
  private generation: number = 0;
  private loaded: boolean = false;
  private alive: boolean = true;

  aboutToAppear(): void {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    xPrivateClient.load(context);
    const params: ListsRouteParam[] = this.pageStack.getParamByName('Lists') as ListsRouteParam[];
    if (params !== undefined && params.length > 0 && params[params.length - 1] !== undefined &&
      params[params.length - 1] !== null) {
      const param: ListsRouteParam = params[params.length - 1];
      this.userId = param.userId ?? '';
      this.memberships = param.memberships === true;
      this.title = param.title ?? '';
    }
    const account: XAccount | null = accountStore.active(context);
    this.username = account === null ? '' : account.username;
    this.load(true);
  }

  aboutToDisappear(): void { this.alive = false; this.generation++; }
  private text(resource: Resource): string {
    return (getContext(this) as common.UIAbilityContext).resourceManager.getStringSync(resource);
  }
  private ownDirectory(): boolean { return this.userId.length === 0 && !this.memberships; }
  private searching(): boolean { return this.submittedQuery.length > 0; }

  private async load(reset: boolean): Promise<void> {
    if (!reset && (this.loading || this.loadingMore || this.nextToken.length === 0)) { return; }
    if (!xPrivateClient.isSignedIn()) {
      this.status = this.text($r('app.string.user_list_sign_in')); this.loading = false; return;
    }
    const generation: number = reset ? ++this.generation : this.generation;
    const cursor: string = reset ? '' : this.nextToken;
    if (reset) { this.loading = true; this.nextToken = ''; } else { this.loadingMore = true; }
    this.status = '';
    try {
      const result: XPrivateResult = this.searching() ?
        await xPrivateClient.searchTimeline(this.submittedQuery, cursor, 20, 'Lists') :
        this.userId.length > 0 ? await xPrivateClient.userLists(this.userId, cursor, this.memberships) :
        await xPrivateClient.subscribedLists(cursor, 20, reset ? '' : this.directoryOperation);
      if (!this.alive || generation !== this.generation) { return; }
      const page: ListPage | null = result.ok ?
        (this.ownDirectory() && !this.searching() ?
          XListParser.directory(result.body, xPrivateClient.viewerId()) : XListParser.parse(result.body)) : null;
      if (page === null) {
        this.status = result.status === 401 ? this.text($r('app.string.private_session_expired')) :
          this.text($r('app.string.lists_failed')) + ' · ' + XPrivateClient.explain(result).substring(0, 160);
        return;
      }
      const previous: ListRow[] = reset ? [] : (this.searching() ? this.searchRows : this.rows);
      const combined: ListRow[] = [...previous];
      for (let i: number = 0; i < page.lists.length; i++) {
        const row: ListRow = page.lists[i];
        if (!combined.some((value: ListRow): boolean => value.id === row.id)) { combined.push(row); }
      }
      if (this.searching()) { this.searchRows = combined; } else { this.rows = combined; }
      if (this.ownDirectory() && !this.searching()) {
        pinnedHomeListStore.merge(getContext(this) as common.UIAbilityContext, xPrivateClient.viewerId(),
          page.lists.map((row: ListRow): ListRow => listStateStore.get(xPrivateClient.viewerId(), row.id) ?? row));
      }
      this.directoryOperation = result.operation;
      this.nextToken = page.nextToken === cursor ? '' : page.nextToken;
    } catch (error) {
      if (generation === this.generation) { this.status = this.text($r('app.string.lists_failed')); }
    } finally {
      if (generation === this.generation) {
        this.loading = false; this.loadingMore = false; this.refreshing = false; this.loaded = true;
      }
    }
  }

  private search(value: string): void {
    this.submittedQuery = value.trim(); this.searchRows = []; this.load(true);
  }
  private visibleRows(): ListRow[] {
    const source: ListRow[] = this.searching() ? this.searchRows : this.rows;
    const needle: string = this.query.trim().toLowerCase();
    return source.filter((row: ListRow): boolean =>
      !listStateStore.isRemoved(xPrivateClient.viewerId(), row.id) &&
      (this.searching() || needle.length === 0 ||
        (row.name + ' ' + row.description + ' ' + row.ownerUsername).toLowerCase().indexOf(needle) >= 0));
  }
  private openList(row: ListRow): void {
    const param: ListTimelineRouteParam = { listId: row.id, title: row.name, row: row };
    this.pageStack.pushPath({ name: 'ListTimeline', param: param });
  }
  private openCreate(): void { this.pageStack.pushPath({ name: 'ListEditor' }); }
  private openMemberships(): void {
    const param: ListsRouteParam = { userId: xPrivateClient.viewerId(), memberships: true,
      title: this.text($r('app.string.list_memberships_title')) };
    this.pageStack.pushPath({ name: 'Lists', param: param });
  }
  private async pin(row: ListRow): Promise<void> {
    if (this.pendingIds.indexOf(row.id) >= 0) { return; }
    this.pendingIds = [...this.pendingIds, row.id];
    try {
      const result: XPrivateResult = await xPrivateClient.pinList(row.id, !row.pinned);
      if (result.ok) {
        const updated: ListRow = copyList(row); updated.pinned = !row.pinned;
        listStateStore.update(xPrivateClient.viewerId(), updated);
        this.rows = this.rows.map((value: ListRow): ListRow => value.id === row.id ? updated : value);
        this.searchRows = this.searchRows.map((value: ListRow): ListRow => value.id === row.id ? updated : value);
      } else {
        promptAction.showToast({ message: this.text($r('app.string.list_action_failed')) + ' · ' +
          XPrivateClient.explain(result).substring(0, 140) });
      }
    } finally { this.pendingIds = this.pendingIds.filter((id: string): boolean => id !== row.id); }
  }

  @Builder
  private MoreMenu(): void {
    Menu() {
      MenuItem({ content: $r('app.string.list_memberships_title') }).onClick((): void => this.openMemberships())
      MenuItem({ content: $r('app.string.list_create_title') }).onClick((): void => this.openCreate())
    }
  }
  @Builder
  private SearchBar(): void {
    Row({ space: 8 }) {
      Search({ value: this.query, placeholder: this.text($r('app.string.list_search_placeholder')) })
        .keyboardAppearance(KeyboardAppearance.IMMERSIVE)
        .layoutWeight(1).height($r('app.float.list_search_height'))
        .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent)).searchButton(this.text($r('app.string.list_search_action')))
        .onChange((value: string): void => {
          this.query = value;
          if (value.trim().length === 0 && this.searching()) { this.search(''); }
        }).onSubmit((value: string): void => this.search(value))
      if (this.ownDirectory()) {
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.ellipsis_circle')).fontSize(24).fontColor([pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent)])
        }.width(44).height(44).backgroundColor(Color.Transparent)
          .accessibilityText($r('app.string.list_more')).bindMenu(this.MoreMenu)
      }
    }.width('100%').padding({ left: 16, right: 16, bottom: 12 })
  }
  @Builder
  private RowItem(row: ListRow): void {
    Row({ space: 12 }) {
      Row({ space: 12 }) {
        ListCover({ listId: row.id, bannerUrl: row.bannerUrl })
        Column({ space: 6 }) {
          Row({ space: 5 }) {
            Text(row.name).fontFamily(this.appFontFamily).fontSize($r('sys.float.Subtitle_M')).fontWeight(FontWeight.Bold)
              .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent)).maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
            if (row.isPrivate) {
              SymbolGlyph($r('sys.symbol.lock')).fontSize(14).fontColor([pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)])
                .accessibilityText($r('app.string.list_private'))
            }
          }.width('100%')
          Row({ space: 6 }) {
            ProxyAvatar({verifiedType: row.ownerVerifiedType ?? '', avatarShape: row.ownerAvatarShape ?? '',  url: row.ownerAvatarUrl, avatarSize: 20, radius: 10,
              fallbackText: row.ownerName.substring(0, 1) })
            Text(row.ownerName.length > 0 ? row.ownerName : '@' + row.ownerUsername).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_M')).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)).maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      }.layoutWeight(1).onClick((): void => this.openList(row))
      if (this.ownDirectory()) {
        Button({ type: ButtonType.Circle }) {
          if (this.pendingIds.indexOf(row.id) >= 0) {
            LoadingProgress().width(22).height(22).color(this.accentColor)
          } else {
            SymbolGlyph(row.pinned ? $r('sys.symbol.pin_fill') : $r('sys.symbol.pin'))
              .fontSize(24).fontColor([row.pinned ? pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent) : pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)])
          }
        }.width(44).height(44).backgroundColor(Color.Transparent)
          .accessibilityText(row.pinned ? $r('app.string.list_unpin') : $r('app.string.list_pin'))
          .enabled(this.pendingIds.indexOf(row.id) < 0).onClick((): void => { this.pin(row); })
      }
    }.width('100%').padding({ left: 16, right: 16, top: 18, bottom: 18 })
      .border({ width: { bottom: 0.5 }, color: $r('app.color.divider') })
  }
  @Builder
  private Content(): void {
    if (this.ownDirectory() && !this.searching()) {
      ListItem() {
        Text($r('app.string.list_yours')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Title_S')).fontWeight(FontWeight.Bold)
          .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent)).width('100%').padding({ left: 16, right: 16, top: 20, bottom: 20 })
      }
    }
    if (this.loading && this.visibleRows().length === 0) {
      ListItem() { LoadingProgress().width(24).height(24).color(this.accentColor).margin({ top: 36 }) }
    } else if (this.visibleRows().length === 0 && this.status.length === 0) {
      ListItem() {
        Column({ space: 12 }) {
          Text(this.memberships ? $r('app.string.list_memberships_empty_title') : this.query.length > 0 ?
            $r('app.string.list_search_empty_title') : $r('app.string.list_empty_title')).fontFamily(this.appFontFamily)
            .fontSize($r('app.float.list_empty_title_size')).fontWeight(FontWeight.Bold)
            .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent)).width('100%')
          Text(this.memberships ? $r('app.string.list_memberships_empty_body') : this.query.length > 0 ?
            $r('app.string.list_search_empty_body') : $r('app.string.list_empty_body')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_L')).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)).width('100%')
          if (this.ownDirectory() && this.query.length === 0) {
            Button($r('app.string.list_create_title')).backgroundColor(this.accentColor)
              .fontColor($r('app.color.text_on_accent')).margin({ top: 8 }).onClick((): void => this.openCreate())
          }
        }.alignItems(HorizontalAlign.Start).width('100%').padding({ left: 28, right: 28, top: 30 })
      }
    } else {
      ForEach(this.visibleRows(), (row: ListRow) => { ListItem() { this.RowItem(row) } }, (row: ListRow): string => row.id)
    }
    if (this.status.length > 0) {
      ListItem() {
        Column({ space: 12 }) {
          Text(this.status).fontFamily(this.appFontFamily).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)).fontSize($r('sys.float.Body_M'))
          Button($r('app.string.common_retry')).fontColor(this.accentColor).backgroundColor(Color.Transparent)
            .onClick((): void => { this.load(true); })
        }.width('100%').padding(24)
      }
    }
    if (this.nextToken.length > 0) {
      ListItem() {
        Button($r('app.string.lists_load_more')).fontColor(this.accentColor).backgroundColor(Color.Transparent)
          .enabled(!this.loadingMore).onClick((): void => { this.load(false); })
      }
    }
  }

  build(): void {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        appPageBackground()
      Stack({ alignContent: Alignment.BottomEnd }) {
        Column() {
          if (!this.memberships) { this.SearchBar() }
          Refresh({ refreshing: $$this.refreshing }) {
            List({ scroller: this.scroller }) { this.Content() }
              .width('100%').height('100%').scrollBar(BarState.Off)
              .contentEndOffset(this.navigationIndicatorHeight + (this.ownDirectory() ? 90 : 24))
              .clip(!(DesktopLayout.active(this.desktopLayoutEnabled, this.windowBreakpoint)))
              .cachedCount(8, DesktopLayout.active(this.desktopLayoutEnabled, this.windowBreakpoint))
              .onReachEnd((): void => { this.load(false); })
          }.width('100%').layoutWeight(1)
            .clip(!(DesktopLayout.active(this.desktopLayoutEnabled, this.windowBreakpoint)))
            .onRefreshing((): void => { this.load(true); })
        }.width('100%').height('100%').padding({ top: DesktopLayout.active(this.desktopLayoutEnabled, this.windowBreakpoint) ? 0 : this.statusBarHeight + 60 })
        if (this.ownDirectory()) {
          FloatingComposeButton({ bottomInset: this.navigationIndicatorHeight, bottomBarHeight: 0,
            gripSubscriberKey: 'floating-list-create-button', composeSymbol: $r('sys.symbol.list_bullet_square'),
            accessibilityLabel: this.text($r('app.string.list_create_title')),
            onCompose: (): void => this.openCreate() })
        }
      }.width('100%').height('100%')
    
      }.width('100%').height('100%')
    }
    .scale({ x: this.pageMotion.scale, y: this.pageMotion.scale })
    .opacity(this.pageMotion.opacity)
    .onReady((context: NavDestinationContext): void => { this.pageMotion.attach(context); })
    .systemTransition(pageSystemTransition(this.pageTransitionMode)).titleMode(HdsNavDestinationTitleMode.MINI).hideBackButton(false)
      .onShown((): void => { if (this.loaded) { this.load(true); } })
      .onBackPressed((): boolean => { ResponsiveLayout.closeContentDestination(this.pageStack); return true; })
      .bindToScrollable([this.scroller])
      .titleBar({ avoidLayoutSafeArea: true,
        enableComponentSafeArea: DesktopLayout.active(this.desktopLayoutEnabled, this.windowBreakpoint),
        content: { title: { mainTitle: this.title.length > 0 ? this.title : $r('app.string.lists_title'),
          subTitle: this.memberships && this.username.length > 0 ? '@' + this.username : '' } },
        style: destinationTitleBarStyle(ScrollEffectType.IMMERSIVE_GRADIENT_BLUR,
          this.themeDisplayMode, this.themeDarkSurface, this.titleBarStyleMode) })
      .backgroundColor(pageCanvasColor(this.themeDisplayMode, this.themeDarkSurface, this.pageBackgroundValue))
      .attributeModifier(materialModifier(deviceInfo.apiAvailable('26.0.0') ? new uiMaterial.ImmersiveMaterial({
        style: uiMaterial.ImmersiveStyle.REGULAR, applyShadow: true, colorInvert: true }) : undefined));
  }
}
