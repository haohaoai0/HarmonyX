import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { HdsNavDestination, HdsNavDestinationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import type { UserRow, UserListPage } from '../models/Tweet';
import { ProxyAvatar } from '../components/ProxyAvatar';
import { appPageBackground } from '../components/PageBackgroundLayer';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { LocalAccountGroup, localAccountGroupStore, DEFAULT_ACCOUNT_GROUP_ICON } from '../services/LocalAccountGroupStore';
import { STORAGE_KEY_HOME_TIMELINE_REVISION } from '../services/HomeTimelineStore';
import { XPrivateResult, xPrivateClient } from '../services/XPrivateClient';
import { XTimelineParser } from '../services/XTimelineParser';
import { STORAGE_KEY_PAGE_TRANSITION_MODE, DEFAULT_PAGE_TRANSITION_MODE } from '../services/PageTransitionSettingsStore';
import { pageSystemTransition, PageTransitionMotion } from '../utils/PageTransition';
import { destinationTitleBarStyle } from '../utils/DestinationTitleBar';
import { DesktopLayout } from '../utils/DesktopLayout';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';
import { pageCanvasColor, pageTextColor, fieldSurfaceColor } from '../utils/ThemeColors';

interface AccountGroupRouteParam { id: string; }

@Builder
export function AccountGroupsBuilder(): void { AccountGroups(); }
@Builder
export function AccountGroupEditorBuilder(): void { AccountGroupEditor(); }

@Component
struct AccountGroups {
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp('harmonyx.page_background') private pageBackgroundValue: string = '';
  @StorageProp('harmonyx.display_mode') private displayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private darkSurface: string = '';
  @StorageProp('harmonyx.title_bar_style_mode') private titleBarStyleMode: number = 0;
  @StorageProp('harmonyx.status_bar_height') private topInset: number = 0;
  @StorageProp('harmonyx.navigation_indicator_height') private bottomInset: number = 0;
  @StorageProp('harmonyx.desktop_layout') private desktopEnabled: boolean = false;
  @StorageProp('harmonyx.breakpoint') private breakpoint: string = 'sm';
  @StorageProp(STORAGE_KEY_PAGE_TRANSITION_MODE) private transitionMode: string = DEFAULT_PAGE_TRANSITION_MODE;
  @StorageProp(STORAGE_KEY_HOME_TIMELINE_REVISION) @Watch('reload') private revision: number = 0;
  @State private motion: PageTransitionMotion = new PageTransitionMotion();
  @State private groups: LocalAccountGroup[] = [];
  private viewer: string = '';
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    xPrivateClient.load(getContext(this)); this.viewer = xPrivateClient.viewerId();
    localAccountGroupStore.load(getContext(this), this.viewer); this.reload();
  }
  private reload(): void { this.groups = localAccountGroupStore.current(); }
  private text(resource: Resource): string { return getContext(this).resourceManager.getStringSync(resource); }
  private edit(id: string): void {
    if (this.viewer.length === 0) {
      promptAction.showToast({ message: this.text($r('app.string.user_list_sign_in')) }); return;
    }
    const param: AccountGroupRouteParam = { id: id };
    this.pageStack.pushPath({ name: 'AccountGroupEditor', param: param });
  }
  private open(group: LocalAccountGroup): void {
    ResponsiveLayout.closeToMain(this.pageStack);
    AppStorage.setOrCreate<string>('harmonyx.home_source_request', 'local-group:' + group.id + '|' + Date.now().toString());
  }
  private pin(group: LocalAccountGroup): void {
    if (!localAccountGroupStore.setPinned(getContext(this), group.id, !group.pinned)) {
      promptAction.showToast({ message: this.text($r('app.string.timeline_save_failed')) });
    }
  }
  private remove(group: LocalAccountGroup): void {
    const viewer: string = this.viewer;
    AlertDialog.show({ title: this.text($r('app.string.account_group_delete')), message: group.name,
      primaryButton: { value: this.text($r('app.string.account_group_cancel')), action: (): void => {} },
      secondaryButton: { value: this.text($r('app.string.account_group_delete')), action: (): void => {
        if (!localAccountGroupStore.remove(getContext(this), group.id, viewer)) {
          promptAction.showToast({ message: this.text($r('app.string.timeline_save_failed')) });
        }
      } }
    });
  }
  @Builder
  private GroupRow(group: LocalAccountGroup): void {
    Column({ space: 8 }) {
      Button({ type: ButtonType.Normal }) {
        Row({ space: 12 }) {
          Text(group.icon).fontSize($r('sys.float.Title_L')).width(40)
          Column({ space: 4 }) {
            Text(group.name).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary')).width('100%').textAlign(TextAlign.Start).maxLines(2)
            Text($r('app.string.account_group_member_count', group.members.length)).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_S')).fontColor($r('app.color.text_secondary')).width('100%').textAlign(TextAlign.Start)
          }.layoutWeight(1)
          SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(16).fontColor([$r('app.color.text_secondary')])
        }.width('100%')
      }.width('100%').padding(0).backgroundColor(Color.Transparent).onClick((): void => this.open(group))
      Row() {
        Button(group.pinned ? $r('app.string.timeline_unpin') : $r('app.string.timeline_pin'))
          .backgroundColor(Color.Transparent).onClick((): void => this.pin(group))
        Blank()
        Button($r('app.string.timeline_edit')).backgroundColor(Color.Transparent).onClick((): void => this.edit(group.id))
        Button($r('app.string.account_group_delete')).backgroundColor(Color.Transparent).onClick((): void => this.remove(group))
      }.width('100%')
    }.width('100%').padding(16).borderRadius(18).backgroundColor(fieldSurfaceColor(this.displayMode, this.darkSurface))
  }
  build(): void {
    HdsNavDestination() {
      Stack() {
        appPageBackground()
        List({ space: 12, scroller: this.scroller }) {
          ListItem() {
            Text($r('app.string.account_groups_hint')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
              .fontColor($r('app.color.text_secondary')).width('100%')
          }
          ListItem() {
            Button($r('app.string.account_group_create')).width('100%').id('account-group-create')
              .onClick((): void => this.edit(''))
          }
          if (this.groups.length === 0) {
            ListItem() {
              Text($r('app.string.account_groups_empty')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L'))
                .fontColor($r('app.color.text_secondary')).width('100%').textAlign(TextAlign.Center).padding(24)
            }
          }
          ForEach(this.groups, (group: LocalAccountGroup) => {
            ListItem() { this.GroupRow(group) }
          }, (group: LocalAccountGroup): string => group.id + group.name + group.icon + group.members.length + group.pinned.toString())
        }.width('100%').height('100%').padding({ left: 16, right: 16 }).scrollBar(BarState.Off)
          .contentStartOffset(DesktopLayout.active(this.desktopEnabled, this.breakpoint) ? 12 : this.topInset + 64)
          .contentEndOffset(this.bottomInset + 20)
      }.width('100%').height('100%')
    }.titleMode(HdsNavDestinationTitleMode.MINI).hideBackButton(false)
      .titleBar({ avoidLayoutSafeArea: true, enableComponentSafeArea: DesktopLayout.active(this.desktopEnabled, this.breakpoint),
        content: { title: { mainTitle: $r('app.string.account_groups_title') } },
        style: destinationTitleBarStyle(ScrollEffectType.GRADIENT_BLUR, this.displayMode, this.darkSurface, this.titleBarStyleMode) })
      .onReady((context: NavDestinationContext): void => this.motion.attach(context))
      .scale({ x: this.motion.scale, y: this.motion.scale }).opacity(this.motion.opacity)
      .systemTransition(pageSystemTransition(this.transitionMode))
      .backgroundColor(pageCanvasColor(this.displayMode, this.darkSurface, this.pageBackgroundValue))
  }
}

@Component
struct AccountGroupEditor {
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp('harmonyx.page_background') private pageBackgroundValue: string = '';
  @StorageProp('harmonyx.display_mode') private displayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private darkSurface: string = '';
  @StorageProp('harmonyx.title_bar_style_mode') private titleBarStyleMode: number = 0;
  @StorageProp('harmonyx.status_bar_height') private topInset: number = 0;
  @StorageProp('harmonyx.navigation_indicator_height') private bottomInset: number = 0;
  @StorageProp('harmonyx.desktop_layout') private desktopEnabled: boolean = false;
  @StorageProp('harmonyx.breakpoint') private breakpoint: string = 'sm';
  @StorageProp(STORAGE_KEY_PAGE_TRANSITION_MODE) private transitionMode: string = DEFAULT_PAGE_TRANSITION_MODE;
  @State private motion: PageTransitionMotion = new PageTransitionMotion();
  @State private name: string = '';
  @State private icon: string = DEFAULT_ACCOUNT_GROUP_ICON;
  @State private pinned: boolean = false;
  @State private selected: UserRow[] = [];
  @State private following: UserRow[] = [];
  @State private search: string = '';
  @State private loading: boolean = false;
  @State private failed: boolean = false;
  @State private nextCursor: string = '';
  private groupId: string = '';
  private viewer: string = '';
  private generation: number = -1;
  private alive: boolean = true;
  private loaded: boolean = false;
  private cursors: string[] = [];
  private scroller: Scroller = new Scroller();

  aboutToDisappear(): void { this.alive = false; }
  private text(resource: Resource): string { return getContext(this).resourceManager.getStringSync(resource); }
  private initialize(param?: AccountGroupRouteParam): void {
    this.viewer = xPrivateClient.viewerId(); this.generation = xPrivateClient.sessionGeneration();
    this.groupId = param?.id ?? '';
    const group: LocalAccountGroup | null = localAccountGroupStore.get(this.groupId);
    if (group !== null) {
      this.name = group.name; this.icon = group.icon; this.pinned = group.pinned; this.selected = group.members;
    }
    this.loadFollowing();
  }
  private current(): boolean {
    return this.alive && this.viewer.length > 0 && this.viewer === xPrivateClient.viewerId() &&
      this.generation === xPrivateClient.sessionGeneration();
  }
  private async loadFollowing(): Promise<void> {
    if (this.loading || !this.current() || (this.loaded && this.nextCursor.length === 0)) { return; }
    this.loading = true; this.failed = false;
    const cursor: string = this.nextCursor;
    try {
      const result: XPrivateResult = await xPrivateClient.userFollowing(this.viewer, cursor, 50);
      if (!this.current()) { return; }
      const page: UserListPage | null = result.ok ? XTimelineParser.parseUserList(result.body) : null;
      if (page === null) { this.failed = true; return; }
      const combined: UserRow[] = this.following.slice();
      for (const row of page.users) {
        if (!combined.some((value: UserRow): boolean => value.id === row.id)) { combined.push(row); }
      }
      this.following = combined; this.loaded = true; this.cursors.push(cursor);
      this.nextCursor = this.cursors.indexOf(page.nextToken) >= 0 ? '' : page.nextToken;
    } catch (error) { if (this.current()) { this.failed = true; } }
    finally { if (this.alive) { this.loading = false; } }
  }
  private save(): void {
    if (!this.current()) {
      promptAction.showToast({ message: this.text($r('app.string.xsettings_account_changed')) }); return;
    }
    const group: LocalAccountGroup = new LocalAccountGroup();
    group.id = this.groupId; group.name = this.name; group.icon = this.icon; group.pinned = this.pinned; group.members = this.selected;
    if (localAccountGroupStore.upsert(getContext(this), group, this.viewer).length === 0) {
      promptAction.showToast({ message: this.text($r('app.string.timeline_save_failed')) }); return;
    }
    this.pageStack.pop();
  }
  private hasMember(id: string): boolean { return this.selected.some((row: UserRow): boolean => row.id === id); }
  private toggle(row: UserRow): void {
    this.selected = this.hasMember(row.id) ? this.selected.filter((value: UserRow): boolean => value.id !== row.id) : [...this.selected, row];
  }
  private filtered(): UserRow[] {
    const needle: string = this.search.trim().toLowerCase();
    return this.following.filter((row: UserRow): boolean =>
      (row.name + ' @' + row.username).toLowerCase().indexOf(needle) >= 0);
  }
  @Builder
  private MemberRow(row: UserRow): void {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 12 }) {
        ProxyAvatar({ url: row.avatarUrl, avatarSize: 40, radius: 20, fallbackText: row.name.slice(0, 1), fallbackColor: row.avatarColor,
          verifiedType: row.verifiedType ?? '', avatarShape: row.avatarShape ?? '' })
        Column({ space: 3 }) {
          Text(row.name).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_primary'))
            .width('100%').textAlign(TextAlign.Start).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          Text('@' + row.username).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S')).fontColor($r('app.color.text_secondary'))
            .width('100%').textAlign(TextAlign.Start).maxLines(1)
        }.layoutWeight(1)
        SymbolGlyph(this.hasMember(row.id) ? $r('sys.symbol.checkmark_circle_fill') : $r('sys.symbol.circle'))
          .fontSize(24).fontColor([$r('app.color.text_primary')])
      }.width('100%').padding({ top: 10, bottom: 10 })
    }.width('100%').padding(0).backgroundColor(Color.Transparent).accessibilitySelected(this.hasMember(row.id))
      .onClick((): void => this.toggle(row))
  }
  build(): void {
    HdsNavDestination() {
      Stack() {
        appPageBackground()
        List({ space: 10, scroller: this.scroller }) {
          ListItem() {
            TextInput({ text: this.name, placeholder: $r('app.string.account_group_name') }).fontFamily(this.appFontFamily)
              .maxLength(40).id('account-group-name').onChange((value: string): void => { this.name = value; })
          }
          ListItem() {
            TextInput({ text: this.icon, placeholder: $r('app.string.account_group_icon') }).fontFamily(this.appFontFamily)
              .maxLength(16).id('account-group-icon').onChange((value: string): void => { this.icon = value; })
          }
          ListItem() {
            Row() {
              Text($r('app.string.timeline_pin')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L'))
                .fontColor($r('app.color.text_primary')).layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.pinned }).onChange((value: boolean): void => { this.pinned = value; })
            }.width('100%').padding({ top: 8, bottom: 8 })
          }
          ListItem() {
            Button($r('app.string.account_group_save')).width('100%').enabled(this.name.trim().length > 0).id('account-group-save')
              .onClick((): void => this.save())
          }
          ListItem() {
            Text($r('app.string.account_group_selected', this.selected.length)).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_L')).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
          }
          ForEach(this.selected, (row: UserRow) => {
            ListItem() { this.MemberRow(row) }
          }, (row: UserRow): string => 'selected-' + row.id)
          ListItem() {
            Search({ value: this.search, placeholder: this.text($r('app.string.account_group_search')) })
              .backgroundColor(fieldSurfaceColor(this.displayMode, this.darkSurface))
              .onChange((value: string): void => { this.search = value; })
          }
          ForEach(this.filtered(), (row: UserRow) => {
            ListItem() { this.MemberRow(row) }
          }, (row: UserRow): string => 'following-' + row.id)
          if (this.loading) { ListItem() { LoadingProgress().width(28).height(28).margin(12) } }
          if (this.failed || this.nextCursor.length > 0) {
            ListItem() {
              Button(this.failed ? $r('app.string.common_retry') : $r('app.string.user_list_load_more'))
                .width('100%').enabled(!this.loading).onClick((): void => { this.loadFollowing(); })
            }
          }
          if (!this.loading && !this.failed && this.following.length === 0) {
            ListItem() {
              Text($r('app.string.user_list_empty')).fontFamily(this.appFontFamily).fontColor($r('app.color.text_secondary')).padding(16)
            }
          }
        }.width('100%').height('100%').padding({ left: 16, right: 16 }).scrollBar(BarState.Off)
          .contentStartOffset(DesktopLayout.active(this.desktopEnabled, this.breakpoint) ? 12 : this.topInset + 64)
          .contentEndOffset(this.bottomInset + 20)
          .onReachEnd((): void => { if (this.search.trim().length === 0) { this.loadFollowing(); } })
      }.width('100%').height('100%')
    }.titleMode(HdsNavDestinationTitleMode.MINI).hideBackButton(false)
      .titleBar({ avoidLayoutSafeArea: true, enableComponentSafeArea: DesktopLayout.active(this.desktopEnabled, this.breakpoint),
        content: { title: { mainTitle: $r('app.string.account_group_edit_title') } },
        style: destinationTitleBarStyle(ScrollEffectType.GRADIENT_BLUR, this.displayMode, this.darkSurface, this.titleBarStyleMode) })
      .onReady((context: NavDestinationContext): void => {
        this.motion.attach(context); this.initialize(context.pathInfo?.param as AccountGroupRouteParam | undefined);
      })
      .scale({ x: this.motion.scale, y: this.motion.scale }).opacity(this.motion.opacity)
      .systemTransition(pageSystemTransition(this.transitionMode))
      .backgroundColor(pageCanvasColor(this.displayMode, this.darkSurface, this.pageBackgroundValue))
  }
}
