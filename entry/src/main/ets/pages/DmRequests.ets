import { appPageBackground } from '../components/PageBackgroundLayer';
import { pageCanvasColor, pageReadingSurfaceColor } from '../utils/ThemeColors';
import { STORAGE_KEY_PAGE_TRANSITION_MODE, DEFAULT_PAGE_TRANSITION_MODE } from '../services/PageTransitionSettingsStore';
import { pageSystemTransition, PageTransitionMotion } from '../utils/PageTransition';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { userAvatarRadius, userVerifiedType, userAvatarShape, verificationBadgeColor } from '../utils/UserIdentity';
import { common } from '@kit.AbilityKit';
import promptAction from '@ohos.promptAction';
import { HdsNavDestination, HdsNavDestinationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { ProxyAvatar } from '../components/ProxyAvatar';
import { xChatActions } from '../services/XChatActions';
import { xPrivateClient, XPrivateResult } from '../services/XPrivateClient';
import { DmConversationRouteParam } from './DmConversation';
import { pageSurfaceColor } from '../utils/ThemeColors';
import { destinationTitleBarStyle } from '../utils/DestinationTitleBar';
import { chatPageMaterial } from '../utils/ChatMaterial';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';

interface RequestProfile { core?: RequestCore; avatar?: RequestAvatar; }
interface RequestCore { name: string; }
interface RequestAvatar { image_url: string; }
interface RequestUser { rest_id: string; result?: RequestProfile; }
interface RequestItem { conversation_id: string; social_proof_users_results?: RequestUser[]; }
interface RequestCursor { cursor_id?: string; descending?: boolean; pull_finished?: boolean; }
interface RequestPage { message_request_items?: RequestItem[]; cursor?: RequestCursor; }
interface RequestData { get_message_requests_page?: RequestPage; }
interface RequestEnvelope { data?: RequestData; }

@Builder
export function DmRequestsBuilder(): void { DmRequestsPage(); }

@Component
struct DmRequestsPage {
  @StorageProp('harmonyx.page_background') private pageBackgroundValue: string = '';
  @State private pageMotion: PageTransitionMotion = new PageTransitionMotion();
  @StorageProp(STORAGE_KEY_PAGE_TRANSITION_MODE) private pageTransitionMode: string = DEFAULT_PAGE_TRANSITION_MODE;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp('harmonyx.status_bar_height') topInset: number = 0;
  @StorageProp('harmonyx.navigation_indicator_height') bottomInset: number = 0;
  @StorageProp('harmonyx.display_mode') displayMode: string = '';
  @StorageProp('harmonyx.dark_surface') darkSurface: string = '';
  @StorageLink('harmonyx.accent_color') accentColor: string = '#007DFF';
  @StorageProp('harmonyx.title_bar_style_mode') titleBarStyleMode: number = 0;
  @State private rows: RequestItem[] = [];
  @State private loading: boolean = true;
  @State private error: string = '';
  @State private more: boolean = false;
  private cursor: string = '9223372036854775807';
  private active: boolean = true;
  private viewer: string = '';
  private scroller: Scroller = new Scroller();
  private context(): common.UIAbilityContext { return getContext(this) as common.UIAbilityContext; }
  private text(resource: Resource): string { return this.context().resourceManager.getStringSync(resource); }
  aboutToAppear(): void { this.viewer = xPrivateClient.viewerId(); this.load(); }
  aboutToDisappear(): void { this.active = false; }
  private async load(): Promise<void> {
    this.loading = true; this.error = '';
    try {
      const cursor: Record<string, Object> = { 'cursor_id': this.cursor, 'descending': true };
      const result: XPrivateResult = await xPrivateClient.graphql('GetMessageRequestsPageQuery', {
        'cursor': cursor
      });
      if (!this.active || this.viewer !== xPrivateClient.viewerId()) { return; }
      if (!result.ok) { throw new Error('requests_http_' + result.status); }
      const page: RequestPage | undefined = (JSON.parse(result.body) as RequestEnvelope).data?.get_message_requests_page;
      if (page === undefined) { throw new Error('requests_unavailable'); }
      this.rows = this.rows.concat(page.message_request_items ?? []);
      this.more = page.cursor?.cursor_id !== undefined && page.cursor.pull_finished !== true;
      this.cursor = page.cursor?.cursor_id ?? this.cursor;
    } catch (error) { if (this.active) { this.error = this.text($r('app.string.chat_action_failed')); } }
    finally { if (this.active) { this.loading = false; } }
  }
  private peer(row: RequestItem): RequestUser | undefined {
    return (row.social_proof_users_results ?? []).filter((user: RequestUser): boolean => user.rest_id !== this.viewer)[0];
  }
  private async accept(row: RequestItem): Promise<void> {
    const ids: string[] = row.conversation_id.replace(':', '-').split('-');
    const id: string = ids.filter((id: string): boolean => id !== this.viewer)[0] ?? '';
    if (id.length === 0 || this.loading) { return; }
    this.loading = true;
    try {
      await xChatActions.action('AcceptMessageRequestMutation', { 'targetUserId': id }, 'user_add_trust');
      if (!this.active || this.viewer !== xPrivateClient.viewerId()) { return; }
      const person: RequestUser | undefined = this.peer(row);
      const param: DmConversationRouteParam = { conversationId: row.conversation_id,
        title: person?.result?.core?.name ?? id, avatarUrl: person?.result?.avatar?.image_url ?? '',
        username: '', participantIds: ids, group: row.conversation_id.startsWith('g'), latestSequenceId: '' };
      this.pageStack.replacePath({ name: 'DmConversation', param: param });
    } catch (error) { promptAction.showToast({ message: this.text($r('app.string.chat_action_failed')) }); }
    finally { if (this.active) { this.loading = false; } }
  }
  build(): void {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        appPageBackground()
        List({ scroller: this.scroller }) {
          ListItem() { Column().width('100%').height(this.topInset + 64) }
          ForEach(this.rows, (row: RequestItem) => {
            ListItem() {
              Row({ space: 12 }) {
                ProxyAvatar({verifiedType: userVerifiedType(this.peer(row)?.result), avatarShape: userAvatarShape(this.peer(row)?.result),  url: this.peer(row)?.result?.avatar?.image_url ?? '', avatarSize: 48, radius: 24,
                  fallbackText: (this.peer(row)?.result?.core?.name ?? 'X').substring(0, 1) })
                Column({ space: 4 }) {
                  Text(this.peer(row)?.result?.core?.name ?? row.conversation_id).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L'))
                    .fontColor($r('app.color.text_primary')).fontWeight(FontWeight.Bold).maxLines(1)
                  Text($r('app.string.chat_request_hint')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary'))
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                Button($r('app.string.chat_accept')).fontColor(this.accentColor).backgroundColor(Color.Transparent)
                  .enabled(!this.loading).onClick((): void => { this.accept(row); })
              }.width('100%').padding(16)
            }
          }, (row: RequestItem): string => row.conversation_id)
          if (this.loading) { ListItem() { LoadingProgress().width(24).height(24).color(this.accentColor).margin(24) } }
          if (this.error.length > 0) { ListItem() { Text(this.error).fontFamily(this.appFontFamily).fontColor($r('app.color.danger')).padding(24).onClick((): void => { this.load(); }) } }
          if (this.rows.length === 0 && !this.loading && this.error.length === 0) { ListItem() { Text($r('app.string.dm_empty')).fontFamily(this.appFontFamily).fontColor($r('app.color.text_secondary')).padding(24) } }
          if (this.more) { ListItem() { Button($r('app.string.dm_load_earlier')).onClick((): void => { this.load(); }) } }
          ListItem() { Column().height(this.bottomInset + 24) }
        }.width('100%').height('100%').scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    
      }.width('100%').height('100%')
    }
    .scale({ x: this.pageMotion.scale, y: this.pageMotion.scale })
    .opacity(this.pageMotion.opacity)
    .onReady((context: NavDestinationContext): void => { this.pageMotion.attach(context); })
    .systemTransition(pageSystemTransition(this.pageTransitionMode)).titleMode(HdsNavDestinationTitleMode.MINI).hideBackButton(false).bindToScrollable([this.scroller])
      .titleBar({ avoidLayoutSafeArea: true, content: { title: { mainTitle: $r('app.string.chat_requests') } },
        style: destinationTitleBarStyle(ScrollEffectType.GRADIENT_BLUR, this.displayMode, this.darkSurface, this.titleBarStyleMode)
      })
      .backgroundColor(pageCanvasColor(this.displayMode, this.darkSurface, this.pageBackgroundValue)).systemMaterial(chatPageMaterial())
      .onBackPressed((): boolean => { ResponsiveLayout.closeContentDestination(this.pageStack); return true; })
  }
}
