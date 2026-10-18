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
import { UserRowCard } from '../components/UserRowCard';
import type { UserListPage, UserRow, ListRow } from '../models/Tweet';
import { xPrivateClient, XPrivateClient, XPrivateResult } from '../services/XPrivateClient';
import { XTimelineParser } from '../services/XTimelineParser';
import { XListParser } from '../services/XListParser';
import { copyList, listStateStore } from '../services/ListStateStore';
import { destinationTitleBarStyle } from '../utils/DestinationTitleBar';
import { pageSurfaceColor } from '../utils/ThemeColors';
import type { ListMembersRouteParam, ListTimelineRouteParam, ListEditorRouteParam } from './Lists';
import type { UserDetailRouteParam } from './UserDetail';

@Builder
export function ListMembersBuilder(): void { ListMembers(); }

@Component
export struct ListMembers {
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
  @State private rows: UserRow[] = [];
  @State private members: UserRow[] = [];
  @State private memberIds: string[] = [];
  @State private pendingIds: string[] = [];
  @State private status: string = '';
  @State private loading: boolean = true;
  @State private loadingMore: boolean = false;
  @State private refreshing: boolean = false;
  @State private listTitle: string = '';
  @State private query: string = '';
  @State private manage: boolean = false;
  @State private creating: boolean = false;
  @State private suggestions: boolean = false;
  private listId: string = '';
  private nextToken: string = '';
  private memberCursor: string = '';
  private submittedQuery: string = '';
  private listRow: ListRow | null = null;
  private membershipReady: boolean = false;
  private scroller: Scroller = new Scroller();
  private generation: number = 0;
  private alive: boolean = true;
  private initialized: boolean = false;
  private searchTimer: number = -1;

  aboutToAppear(): void {
    xPrivateClient.load(getContext(this) as common.UIAbilityContext);
    const params: ListMembersRouteParam[] = this.pageStack.getParamByName('ListMembers') as ListMembersRouteParam[];
    if (params !== undefined && params.length > 0 && params[params.length - 1] !== undefined &&
      params[params.length - 1] !== null) {
      const param: ListMembersRouteParam = params[params.length - 1];
      this.listId = param.listId; this.listTitle = param.title; this.listRow = param.row ?? null;
      this.manage = param.manage ?? false; this.creating = param.creating ?? false; this.suggestions = this.creating;
    }
    this.initialize();
  }
  aboutToDisappear(): void { this.alive = false; this.generation++; clearTimeout(this.searchTimer); }
  private text(resource: Resource): string {
    return (getContext(this) as common.UIAbilityContext).resourceManager.getStringSync(resource);
  }
  private async initialize(): Promise<void> {
    if (!xPrivateClient.isSignedIn() || this.listId.length === 0) {
      this.status = this.text($r('app.string.user_list_sign_in')); this.loading = false; return;
    }
    if (this.manage && (this.listRow === null || this.listRow.ownerId !== xPrivateClient.viewerId())) {
      const detail: XPrivateResult = await xPrivateClient.listDetail(this.listId);
      this.listRow = detail.ok ? XListParser.detail(detail.body, this.listId) : null;
      this.manage = this.listRow !== null && this.listRow.ownerId === xPrivateClient.viewerId();
    }
    if (this.manage) {
      // Complete the membership directory before enabling search actions so
      // an existing member is never shown with an incorrect Add button.
      this.memberCursor = ''; this.members = []; this.memberIds = [];
      let cursor: string = '';
      const seen: string[] = [];
      do {
        const result: XPrivateResult = await xPrivateClient.listMembers(this.listId, cursor, 100);
        if (!this.alive) { return; }
        const page: UserListPage | null = result.ok ? XTimelineParser.parseUserList(result.body) : null;
        if (page === null) { this.status = this.failure(result); this.loading = false; return; }
        this.members = this.combine(this.members, page.users);
        this.memberIds = this.members.map((row: UserRow): string => row.id);
        seen.push(cursor); cursor = page.nextToken;
      } while (cursor.length > 0 && seen.indexOf(cursor) < 0);
      this.membershipReady = true;
    }
    this.initialized = true; this.load(true);
  }
  private combine(previous: UserRow[], incoming: UserRow[]): UserRow[] {
    const rows: UserRow[] = [...previous];
    for (let i: number = 0; i < incoming.length; i++) {
      if (!rows.some((row: UserRow): boolean => row.id === incoming[i].id)) { rows.push(incoming[i]); }
    }
    return rows;
  }
  private failure(result: XPrivateResult): string {
    return this.text($r('app.string.list_members_failed')) + ' · ' + XPrivateClient.explain(result).substring(0, 140);
  }
  private async load(reset: boolean): Promise<void> {
    if (!reset && (this.loading || this.loadingMore || this.nextToken.length === 0)) { return; }
    const generation: number = reset ? ++this.generation : this.generation;
    const cursor: string = reset ? '' : this.nextToken;
    this.status = '';
    if (reset) { this.loading = true; this.nextToken = ''; } else { this.loadingMore = true; }
    try {
      if (this.manage && !this.suggestions) {
        const needle: string = this.query.trim().toLowerCase();
        this.rows = this.members.filter((row: UserRow): boolean => needle.length === 0 ||
          (row.name + ' ' + row.username).toLowerCase().indexOf(needle) >= 0);
        return;
      }
      let result: XPrivateResult = this.submittedQuery.length > 0 ?
        await xPrivateClient.searchTimeline(this.submittedQuery, cursor, 20, 'People') :
        this.suggestions ? await xPrivateClient.listRecommendations(this.listId, cursor) :
        await xPrivateClient.listMembers(this.listId, cursor, 20);
      if (this.suggestions && this.submittedQuery.length === 0 && !result.ok) {
        result = await xPrivateClient.userFollowing(xPrivateClient.viewerId(), cursor, 20);
      }
      if (!this.alive || generation !== this.generation) { return; }
      const page: UserListPage | null = result.ok ? XTimelineParser.parseUserList(result.body) : null;
      if (page === null) { this.status = this.failure(result); return; }
      this.rows = this.combine(reset ? [] : this.rows, page.users);
      this.nextToken = page.nextToken === cursor ? '' : page.nextToken;
    } catch (error) { if (generation === this.generation) { this.status = this.text($r('app.string.list_members_failed')); } }
    finally {
      if (generation === this.generation) { this.loading = false; this.loadingMore = false; this.refreshing = false; }
    }
  }
  private search(value: string): void {
    this.query = value;
    clearTimeout(this.searchTimer);
    this.searchTimer = setTimeout((): void => {
      this.submittedQuery = this.query.trim(); this.load(true);
    }, 350);
  }
  private selectMode(suggestions: boolean): void {
    clearTimeout(this.searchTimer); this.suggestions = suggestions; this.query = ''; this.submittedQuery = '';
    this.rows = []; this.load(true);
  }
  private async toggleMember(row: UserRow): Promise<void> {
    if (!this.manage || !this.membershipReady || this.pendingIds.indexOf(row.id) >= 0) { return; }
    const member: boolean = this.memberIds.indexOf(row.id) >= 0;
    this.pendingIds = [...this.pendingIds, row.id];
    try {
      const result: XPrivateResult = await xPrivateClient.setListMember(this.listId, row.id, !member);
      if (!result.ok) {
        promptAction.showToast({ message: this.text($r('app.string.list_action_failed')) + ' · ' +
          XPrivateClient.explain(result).substring(0, 140) }); return;
      }
      this.memberIds = this.memberIds.filter((id: string): boolean => id !== row.id);
      this.members = this.members.filter((value: UserRow): boolean => value.id !== row.id);
      if (!member) { this.memberIds = [...this.memberIds, row.id]; this.members = [...this.members, row]; }
      if (!this.suggestions) { this.rows = this.rows.filter((value: UserRow): boolean => value.id !== row.id); }
      if (this.listRow !== null) {
        const updated: ListRow = copyList(this.listRow); updated.memberCount = this.memberIds.length;
        this.listRow = updated; listStateStore.update(xPrivateClient.viewerId(), updated);
      } else { listStateStore.touch(); }
    } finally { this.pendingIds = this.pendingIds.filter((id: string): boolean => id !== row.id); }
  }
  private openUser(row: UserRow): void {
    const param: UserDetailRouteParam = { author: { id: row.id, name: row.name, username: row.username,
      avatarColor: row.avatarColor, avatarUrl: row.avatarUrl, verified: row.verified, verifiedType: row.verifiedType, avatarShape: row.avatarShape }, posts: [] };
    this.pageStack.pushPath({ name: 'UserDetail', param: param });
  }
  private finish(): void {
    if (this.pendingIds.length > 0) { return; }
    if (this.creating) {
      const param: ListTimelineRouteParam = { listId: this.listId, title: this.listTitle, row: this.listRow ?? undefined };
      this.pageStack.replacePath({ name: 'ListTimeline', param: param });
    } else { this.pageStack.pop(); }
  }
  private edit(): void {
    if (this.listRow === null || this.pendingIds.length > 0) { return; }
    const param: ListEditorRouteParam = { row: this.listRow };
    this.pageStack.pushPath({ name: 'ListEditor', param: param });
  }

  @Builder
  private Toolbar(): void {
    if (this.manage) {
      Search({ value: this.query, placeholder: this.text($r('app.string.list_people_search')) })
        .keyboardAppearance(KeyboardAppearance.IMMERSIVE)
        .height($r('app.float.list_search_height')).margin({ left: 16, right: 16, bottom: 12 })
        .onChange((value: string): void => this.search(value))
      Row({ space: 12 }) {
        Button($r('app.string.list_members_title')).layoutWeight(1)
          .backgroundColor(Color.Transparent).fontColor(this.suggestions ? pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent) : this.accentColor)
          .onClick((): void => this.selectMode(false))
        Button($r('app.string.list_add_members')).layoutWeight(1)
          .backgroundColor(Color.Transparent).fontColor(this.suggestions ? this.accentColor : pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
          .onClick((): void => this.selectMode(true))
      }.width('100%')
    }
  }
  @Builder
  private Content(): void {
    if (this.loading && this.rows.length === 0) {
      ListItem() { LoadingProgress().color(this.accentColor).width(24).height(24).margin({ top: 32 }) }
    } else {
      ForEach(this.rows, (row: UserRow) => {
        ListItem() {
          Row() {
            UserRowCard({ row: row, showFollow: false, onOpen: (user: UserRow): void => this.openUser(user) })
              .layoutWeight(1)
            if (this.manage) {
              Button(this.pendingIds.indexOf(row.id) >= 0 ? $r('app.string.list_working') :
                this.memberIds.indexOf(row.id) >= 0 ? $r('app.string.list_remove_member') : $r('app.string.list_add_member'))
                .fontSize($r('sys.float.Body_M')).fontColor(this.accentColor).backgroundColor(Color.Transparent)
                .border({ width: 1, color: this.accentColor }).borderRadius(20)
                .enabled(this.membershipReady && this.pendingIds.indexOf(row.id) < 0)
                .margin({ right: 16 }).onClick((): void => { this.toggleMember(row); })
            }
          }.width('100%').alignItems(VerticalAlign.Top)
        }
      }, (row: UserRow): string => row.id)
      if (this.rows.length === 0 && this.status.length === 0) {
        ListItem() {
          Text(this.query.length > 0 ? $r('app.string.list_people_empty') : $r('app.string.list_members_empty')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_L')).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)).width('100%').padding(28)
        }
      }
    }
    if (this.status.length > 0) {
      ListItem() {
        Column({ space: 12 }) {
          Text(this.status).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
          Button($r('app.string.common_retry')).backgroundColor(Color.Transparent).fontColor(this.accentColor)
            .onClick((): void => { if (this.initialized) { this.load(true); } else { this.initialize(); } })
        }.width('100%').padding(24)
      }
    }
    if (this.nextToken.length > 0) {
      ListItem() {
        Button($r('app.string.lists_load_more')).backgroundColor(Color.Transparent).fontColor(this.accentColor)
          .enabled(!this.loadingMore).onClick((): void => { this.load(false); })
      }
    }
  }
  build(): void {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        appPageBackground()
      Column() {
        this.Toolbar()
        Refresh({ refreshing: $$this.refreshing }) {
          List({ scroller: this.scroller }) { this.Content() }.width('100%').height('100%').scrollBar(BarState.Off)
            .divider({ strokeWidth: 0.5, color: $r('app.color.divider') })
            .contentEndOffset(this.manage ? 16 : this.navigationIndicatorHeight + 24)
            .onReachEnd((): void => { this.load(false); })
        }.width('100%').layoutWeight(1).onRefreshing((): void => { this.initialize(); })
        if (this.manage) {
          Column({ space: 10 }) {
            if (this.creating) {
              Text(this.memberIds.length === 0 ? $r('app.string.list_create_no_members') :
                this.memberIds.length + ' ' + this.text($r('app.string.list_members_label'))).fontFamily(this.appFontFamily)
                .fontSize($r('sys.float.Subtitle_M')).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
              if (this.memberIds.length === 0) {
                Text($r('app.string.list_create_members_hint')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
                  .fontColor($r('app.color.text_secondary')).width('100%')
              }
            }
            Row() {
              if (this.creating) {
                Button($r('app.string.list_edit')).backgroundColor(Color.Transparent).fontColor(this.accentColor)
                  .onClick((): void => this.edit())
              }
              Blank()
              Button($r('app.string.list_done')).backgroundColor(this.accentColor).fontColor($r('app.color.text_on_accent'))
                .enabled(this.pendingIds.length === 0).onClick((): void => this.finish())
            }.width('100%')
          }.width('100%').padding({ left: 20, right: 20, top: 12, bottom: this.navigationIndicatorHeight + 12 })
        }
      }.width('100%').height('100%').padding({ top: this.statusBarHeight + 60 })
    
      }.width('100%').height('100%')
    }
    .scale({ x: this.pageMotion.scale, y: this.pageMotion.scale })
    .opacity(this.pageMotion.opacity)
    .onReady((context: NavDestinationContext): void => { this.pageMotion.attach(context); })
    .systemTransition(pageSystemTransition(this.pageTransitionMode)).titleMode(HdsNavDestinationTitleMode.MINI).hideBackButton(false)
      .onShown((): void => {
        const updated: ListRow | undefined = listStateStore.get(xPrivateClient.viewerId(), this.listId);
        if (updated !== undefined) { this.listRow = updated; this.listTitle = updated.name; }
      })
      .onBackPressed((): boolean => { if (this.pendingIds.length === 0) { this.pageStack.pop(); } return true; })
      .bindToScrollable([this.scroller])
      .titleBar({ avoidLayoutSafeArea: true, content: { title: {
        mainTitle: this.creating ? $r('app.string.list_create_add_title') : this.manage ?
          $r('app.string.list_manage_members') : $r('app.string.list_members_title'),
        subTitle: this.creating ? $r('app.string.list_create_step_two') : this.listTitle } },
        style: destinationTitleBarStyle(ScrollEffectType.IMMERSIVE_GRADIENT_BLUR,
          this.themeDisplayMode, this.themeDarkSurface, this.titleBarStyleMode) })
      .backgroundColor(pageCanvasColor(this.themeDisplayMode, this.themeDarkSurface, this.pageBackgroundValue))
      .systemMaterial(deviceInfo.apiAvailable('26.0.0') ? new uiMaterial.ImmersiveMaterial({
        style: uiMaterial.ImmersiveStyle.REGULAR, applyShadow: true, colorInvert: true }) : undefined);
  }
}
