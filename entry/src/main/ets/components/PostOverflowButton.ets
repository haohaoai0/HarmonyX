import { InputModalScope } from '../utils/InputModalScope';
import { menuActionVisible, menuActionsForGroup, MenuActionOption } from '../models/MenuActionCatalog';
import { STORAGE_KEY_HIDDEN_MENU_ACTIONS } from '../services/MenuSettingsStore';
import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import type { Tweet, TweetFeedbackAction, ListRow } from '../models/Tweet';
import { xPrivateClient, XPrivateResult } from '../services/XPrivateClient';
import { XListParser } from '../services/XListParser';
import { XUserParser } from '../services/XUserParser';
import { followStateStore } from '../services/FollowStateStore';
import { postModerationStore } from '../services/PostModerationStore';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { DEFAULT_SHEET_MATERIAL_ENABLED, STORAGE_KEY_SHEET_MATERIAL_ENABLED, STORAGE_KEY_SHEET_MATERIAL_LEVEL } from '../services/SheetMaterialSettingsStore';
import { sheetMaterialOptions } from '../utils/SheetMaterial';
import { pageSurfaceColor } from '../utils/ThemeColors';
import { openExternalLink } from '../utils/PostEntities';
import { postShareUrl } from '../utils/SharePost';
import type { PostInteractionsRouteParam } from '../pages/PostInteractions';
import type { ProfileWebRouteParam } from '../pages/ProfileWeb';

@Component
export struct PostOverflowButton {
  private inputModalScope: InputModalScope = new InputModalScope();

  aboutToDisappear(): void { this.inputModalScope.setActive(false); }
  @StorageProp(STORAGE_KEY_HIDDEN_MENU_ACTIONS) private hiddenMenuActions: string = '';
  @Prop foreground: ResourceColor = $r('app.color.text_secondary');
  @StorageProp('harmonyx.compact_window') private compactWindow: boolean = false;
  @Prop tweet: Tweet;
  @Prop @Watch('onInputMenuRequest') inputMenuRequest: number = 0;
  @Prop hideTrigger: boolean = false;

  private onInputMenuRequest(): void {
    if (this.inputMenuRequest <= 0) { return; }
    this.following = this.tweet.author.following === true;
    this.listPicker = false;
    this.showing = true;
  }
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp('harmonyx.display_mode') private themeDisplayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private themeDarkSurface: string = '';
  @StorageProp('harmonyx.breakpoint') private breakpoint: string = 'sm';
  @StorageProp('harmonyx.navigation_indicator_height') private bottomInset: number = 0;
  @StorageProp(STORAGE_KEY_SHEET_MATERIAL_ENABLED) private materialEnabled: boolean = DEFAULT_SHEET_MATERIAL_ENABLED;
  @StorageProp(STORAGE_KEY_SHEET_MATERIAL_LEVEL) private materialLevel: number = 0;
  @State private showing: boolean = false;
  @State private pending: boolean = false;
  @State private listPicker: boolean = false;
  @State private lists: ListRow[] = [];
  @State private listLoading: boolean = false;
  @State private listStatus: string = '';
  @State private following: boolean = false;

  private context(): common.UIAbilityContext { return getContext(this) as common.UIAbilityContext; }
  private text(resource: Resource): string { return this.context().resourceManager.getStringSync(resource); }
  private dimension(resource: Resource): number {
    return this.getUIContext().px2vp(this.context().resourceManager.getNumber(resource.id));
  }
  private menuVisible(id: string): boolean {
    return menuActionVisible(this.hiddenMenuActions, id);
  }

  private own(): boolean { return xPrivateClient.viewerId() === this.tweet.author.id; }
  private toast(resource: Resource, status: number = 0): void {
    promptAction.showToast({ message: this.text(resource) + (status > 0 ? ' · HTTP ' + status.toString() : '') });
  }

  private async notInterested(): Promise<void> {
    if (this.pending) { return; }
    const tweet: Tweet = this.tweet;
    const action: TweetFeedbackAction | undefined = (tweet.feedbackActions ?? []).find((item: TweetFeedbackAction): boolean =>
      item.type.toLowerCase() === 'dontlike' || item.type.toLowerCase() === 'notinterested' ||
      item.type.toLowerCase() === 'not_interested');
    if (action === undefined || action.url.length === 0) {
      const saved: boolean = postModerationStore.hide(this.context(), tweet.id);
      this.showing = false;
      this.toast(saved ? $r('app.string.post_menu_hidden_local') : $r('app.string.timeline_save_failed'));
      return;
    }
    this.pending = true;
    const generation: number = xPrivateClient.sessionGeneration();
    try {
      const result: XPrivateResult = await xPrivateClient.timelineFeedback(action.url, action.type);
      if (generation !== xPrivateClient.sessionGeneration()) { this.showing = false; return; }
      if (!result.ok) { this.toast($r('app.string.profile_setting_failed'), result.status); return; }
      const saved: boolean = postModerationStore.hide(this.context(), tweet.id);
      this.showing = false;
      this.toast(saved ? $r('app.string.post_menu_feedback_sent') : $r('app.string.timeline_save_failed'));
    } catch (error) { this.toast($r('app.string.profile_setting_failed')); }
    finally { this.pending = false; }
  }

  private async accountAction(action: string): Promise<void> {
    if (this.pending) { return; }
    if (!xPrivateClient.isSignedIn()) { this.toast($r('app.string.profile_follow_sign_in')); return; }
    const tweet: Tweet = this.tweet;
    const generation: number = xPrivateClient.sessionGeneration();
    const nextFollow: boolean = !this.following;
    this.pending = true;
    try {
      const result: XPrivateResult = action === 'mute' ? await xPrivateClient.muteUser(tweet.author.id, true) :
        action === 'block' ? await xPrivateClient.block(tweet.author.id, true) :
        await xPrivateClient.follow(tweet.author.id, nextFollow);
      if (generation !== xPrivateClient.sessionGeneration()) { this.showing = false; return; }
      if (!result.ok) { this.toast($r('app.string.profile_setting_failed'), result.status); return; }
      const refreshed: XPrivateResult = await xPrivateClient.userByRestId(tweet.author.id, true);
      if (generation !== xPrivateClient.sessionGeneration()) { this.showing = false; return; }
      const profile = refreshed.ok ? XUserParser.parse(refreshed.body) : null;
      const confirmed: boolean = profile !== null && (action === 'mute' ? profile.muting === true :
        action === 'block' ? profile.blocking === true : profile.following === nextFollow);
      if (!confirmed) { this.toast($r('app.string.post_menu_unconfirmed')); return; }
      if (action === 'follow') {
        this.following = nextFollow;
        followStateStore.set(xPrivateClient.viewerId(), tweet.author.id, nextFollow);
      }
      else { postModerationStore.hide(this.context(), tweet.author.id, true); }
      this.showing = false;
      this.toast($r('app.string.profile_setting_saved'));
    } catch (error) { this.toast($r('app.string.profile_setting_failed')); }
    finally { this.pending = false; }
  }

  private async loadLists(): Promise<void> {
    if (!xPrivateClient.isSignedIn()) { this.toast($r('app.string.profile_follow_sign_in')); return; }
    this.listPicker = true;
    this.listLoading = true;
    this.listStatus = '';
    const generation: number = xPrivateClient.sessionGeneration();
    try {
      const rows: ListRow[] = [];
      let cursor: string = '';
      const cursors: Set<string> = new Set<string>();
      do {
        cursors.add(cursor);
        // The picker mirrors the web request, which names the account whose
        // membership each row reports.
        const result: XPrivateResult = await xPrivateClient.userLists(
          xPrivateClient.viewerId(), cursor, false, this.tweet.author.id);
        if (generation !== xPrivateClient.sessionGeneration() || !this.showing) { return; }
        const page = result.ok ? XListParser.parse(result.body) : null;
        if (page === null) { this.listStatus = this.text($r('app.string.profile_setting_failed')); break; }
        for (const row of page.lists) {
          if (!rows.some((existing: ListRow): boolean => existing.id === row.id)) { rows.push(row); }
        }
        if (cursors.has(page.nextToken)) { break; }
        cursor = page.nextToken;
      } while (cursor.length > 0);
      this.lists = rows;
    } catch (error) { this.listStatus = this.text($r('app.string.profile_setting_failed')); }
    finally { this.listLoading = false; }
  }

  private async setListMember(row: ListRow, member: boolean): Promise<void> {
    if (this.pending) { return; }
    const userId: string = this.tweet.author.id;
    const generation: number = xPrivateClient.sessionGeneration();
    this.pending = true;
    try {
      const result: XPrivateResult = await xPrivateClient.setListMember(row.id, userId, member);
      if (generation !== xPrivateClient.sessionGeneration()) { this.showing = false; return; }
      if (!result.ok) { this.toast($r('app.string.profile_setting_failed'), result.status); return; }
      let found: boolean = false;
      let cursor: string = '';
      const cursors: Set<string> = new Set<string>();
      do {
        cursors.add(cursor);
        const refreshed: XPrivateResult = await xPrivateClient.userLists(userId, cursor, true);
        if (generation !== xPrivateClient.sessionGeneration()) { this.showing = false; return; }
        const page = refreshed.ok ? XListParser.parse(refreshed.body) : null;
        if (page === null) { this.toast($r('app.string.post_menu_unconfirmed')); return; }
        found = page.lists.some((list: ListRow): boolean => list.id === row.id);
        if (found || cursors.has(page.nextToken)) { break; }
        cursor = page.nextToken;
      } while (cursor.length > 0);
      this.toast(found === member ? $r('app.string.profile_setting_saved') : $r('app.string.post_menu_unconfirmed'));
    } catch (error) { this.toast($r('app.string.profile_setting_failed')); }
    finally { this.pending = false; }
  }

  private openWeb(suffix: string, title: Resource): void {
    this.showing = false;
    const param: ProfileWebRouteParam = { url: postShareUrl(this.tweet) + suffix, title: this.text(title) };
    this.pageStack.pushPath({ name: 'ProfileWeb', param: param });
  }

  @Builder
  private Action(symbol: Resource, title: Resource, action: () => void, handle: boolean = false): void {
    Button({ type: ButtonType.Normal }) {
      Row({ space: this.dimension($r('app.float.post_menu_row_gap')) }) {
        SymbolGlyph(symbol).fontSize($r('app.float.post_menu_icon_size')).fontColor([$r('app.color.text_secondary')])
          .width($r('app.float.post_menu_icon_width'))
        Text(this.text(title) + (handle ? ' @' + this.tweet.author.username : ''))
          .fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L'))
          .fontColor($r('app.color.text_primary')).layoutWeight(1).textAlign(TextAlign.Start).maxLines(2)
      }.width('100%')
    }.width('100%').constraintSize({ minHeight: $r('app.float.post_menu_row_height') })
      .padding({ left: $r('app.float.post_menu_horizontal_padding'), right: $r('app.float.post_menu_horizontal_padding'),
        top: $r('app.float.post_menu_vertical_padding'), bottom: $r('app.float.post_menu_vertical_padding') })
      .backgroundColor(Color.Transparent).enabled(!this.pending).onClick(action)
  }

  @Builder
  private MenuSheet(): void {
    Scroll() {
      Column() {
        if (this.listPicker) {
          this.Action($r('sys.symbol.arrow_left'), $r('app.string.common_back'), (): void => { this.listPicker = false; })
          if (this.listLoading) { LoadingProgress().width($r('app.float.post_menu_spinner_size')).height($r('app.float.post_menu_spinner_size')) }
          if (this.listStatus.length > 0 || (!this.listLoading && this.lists.length === 0)) {
            Text(this.listStatus.length > 0 ? this.listStatus : $r('app.string.post_menu_lists_empty'))
              .fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary'))
              .padding($r('app.float.post_menu_horizontal_padding'))
          }
          ForEach(this.lists, (list: ListRow) => {
            Row({ space: this.dimension($r('app.float.post_menu_vertical_padding')) }) {
              Text(list.name).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L'))
                .fontColor($r('app.color.text_primary')).layoutWeight(1)
              Button($r('app.string.post_menu_list_add')).enabled(!this.pending)
                .onClick((): void => { void this.setListMember(list, true); })
              Button($r('app.string.post_menu_list_remove')).enabled(!this.pending)
                .onClick((): void => { void this.setListMember(list, false); })
            }.width('100%').padding({ left: $r('app.float.post_menu_horizontal_padding'), right: $r('app.float.post_menu_horizontal_padding'),
              top: $r('app.float.post_menu_vertical_padding'), bottom: $r('app.float.post_menu_vertical_padding') })
          }, (list: ListRow): string => list.id)
        } else {
          if (!this.own()) {
            if (this.menuVisible('post.not_interested')) {
              this.Action($r('sys.symbol.face_sading'), $r('app.string.video_feed_not_interested'), (): void => { void this.notInterested(); })
            }
            if (this.menuVisible('post.follow')) {
              this.Action($r('sys.symbol.person_badge_plus'), this.following ? $r('app.string.post_menu_unfollow') :
                $r('app.string.profile_detail_follow'), (): void => { void this.accountAction('follow'); }, true)
            }
            if (this.menuVisible('post.lists')) {
              this.Action($r('sys.symbol.list_bullet'), $r('app.string.post_menu_lists'), (): void => { void this.loadLists(); })
            }
            if (this.menuVisible('post.mute')) {
              this.Action($r('sys.symbol.speaker_slash'), $r('app.string.post_menu_mute'), (): void => { void this.accountAction('mute'); }, true)
            }
            if (this.menuVisible('post.block')) {
              this.Action($r('sys.symbol.nosign'), $r('app.string.post_menu_block'), (): void => { void this.accountAction('block'); }, true)
            }
          }
          if (menuActionsForGroup('post_menu').filter((option: MenuActionOption): boolean =>
            !this.own() || ['post.report', 'post.note', 'post.interactions', 'post.hidden_replies'].indexOf(option.id) >= 0)
            .every((option: MenuActionOption): boolean => !this.menuVisible(option.id))) {
            Text($r('app.string.settings_menu_empty')).fontFamily(this.appFontFamily).fontColor($r('app.color.text_secondary')).padding(20)
          }
          if (this.menuVisible('post.report')) {
            this.Action($r('sys.symbol.flag'), $r('app.string.video_feed_report_post'), (): void => {
              this.showing = false;
              openExternalLink(this.context(), postShareUrl(this.tweet));
              this.toast($r('app.string.video_feed_report_handoff'));
            })
          }
          if (this.menuVisible('post.note')) {
            this.Action($r('sys.symbol.text_bubble_left_2'), $r('app.string.post_menu_request_note'), (): void => {
              this.openWeb('', $r('app.string.post_menu_request_note'));
              this.toast($r('app.string.post_menu_note_handoff'));
            })
          }
          if (this.menuVisible('post.interactions')) {
            this.Action($r('sys.symbol.repeat'), $r('app.string.post_interactions_title'), (): void => {
              this.showing = false;
              const param: PostInteractionsRouteParam = { tweet: this.tweet };
              this.pageStack.pushPath({ name: 'PostInteractions', param: param });
            })
          }
          if (this.menuVisible('post.hidden_replies')) {
            this.Action($r('sys.symbol.eye_slash'), $r('app.string.post_menu_hidden_replies'), (): void => {
              this.openWeb('/hidden', $r('app.string.post_menu_hidden_replies'));
            })
          }
        }
      }.width('100%').padding({ top: $r('app.float.post_menu_top_padding'),
        bottom: this.bottomInset + this.dimension($r('app.float.post_menu_vertical_padding')) })
    }.width('100%').scrollBar(BarState.Off)
  }

  build(): void {
    Button({ type: ButtonType.Circle }) {
      SymbolGlyph($r('sys.symbol.line_3_horizontal'))
        .fontSize($r('app.float.post_menu_button_icon')).fontColor([this.foreground])
    }.width(this.hideTrigger ? 0 : $r('app.float.post_menu_button_size')).height(this.hideTrigger ? 0 : $r('app.float.post_menu_button_size')).backgroundColor(Color.Transparent)
      .focusable(!this.hideTrigger).accessibilityLevel(this.hideTrigger ? 'no' : 'auto')
      .id('post-overflow-' + this.tweet.id)
      .accessibilityText($r('app.string.post_menu_more')).monopolizeEvents(true)
      .onClick((): void => { this.following = this.tweet.author.following === true;
        this.listPicker = false; this.showing = true; })
      .bindSheet($$this.showing, this.MenuSheet(), sheetMaterialOptions({ height: SheetSize.FIT_CONTENT,
        preferType: SheetType.BOTTOM, dragBar: true, showClose: false,
        backgroundColor: pageSurfaceColor(this.themeDisplayMode, this.themeDarkSurface),
        onAppear: (): void => { this.inputModalScope.setActive(true); },
        onDisappear: (): void => { this.inputModalScope.setActive(false); this.showing = false; } }, this.materialEnabled, this.materialLevel,
        this.breakpoint, this.compactWindow))
  }
}
