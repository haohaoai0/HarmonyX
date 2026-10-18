import { pageTextColor } from '../utils/ThemeColors';
import { appPageBackground } from '../components/PageBackgroundLayer';
import { pageCanvasColor, pageReadingSurfaceColor } from '../utils/ThemeColors';
import { STORAGE_KEY_PAGE_TRANSITION_MODE, DEFAULT_PAGE_TRANSITION_MODE } from '../services/PageTransitionSettingsStore';
import { pageSystemTransition, PageTransitionMotion } from '../utils/PageTransition';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { SymbolGlyphModifier } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import promptAction from '@ohos.promptAction';
import { HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationMenuItemOptions, TextStyleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { ProxyAvatar } from '../components/ProxyAvatar';
import { XChatService, XChatPage, XChatConversationInfo, xChatService } from '../services/XChatService';
import { ChatMediaCard } from '../components/ChatMediaCard';
import { DmAttachment } from '../models/Tweet';
import { openExternalLink } from '../utils/PostEntities';
import { xChatActions } from '../services/XChatActions';
import { xPrivateClient } from '../services/XPrivateClient';
import { xPrivateStore } from '../services/XPrivateStore';
import { DmConversationRouteParam } from './DmConversation';
import { DmWebRouteParam } from './DmWeb';
import { UserDetailRouteParam } from './UserDetail';
import { TweetAuthor, DmMessage } from '../models/Tweet';
import { pageSurfaceColor, secondaryButtonSurfaceColor } from '../utils/ThemeColors';
import { ChatMoreSymbol } from '../components/ChatMoreSymbol';
import { destinationTitleBarStyle } from '../utils/DestinationTitleBar';
import { chatInputMaterial, chatPageMaterial } from '../utils/ChatMaterial';
import { SystemMaterialUtil } from '../utils/SystemMaterial';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';
import { STORAGE_KEY_TITLE_BAR_GLASS_MATERIAL_LEVEL, DEFAULT_TITLE_BAR_GLASS_MATERIAL_LEVEL } from '../services/AppearanceStore';
import { ChatBackgroundRouteParam } from './ChatBackground';

export interface DmInfoRouteParam extends DmConversationRouteParam { section?: string; }
interface ChatSharedMedia { attachment: DmAttachment; keyVersion: string; id: string; }

@Builder
export function DmInfoBuilder(): void { DmInfoPage(); }

@Component
struct DmInfoPage {
  @StorageProp('harmonyx.page_background') private pageBackgroundValue: string = '';
  @State private pageMotion: PageTransitionMotion = new PageTransitionMotion();
  @StorageProp(STORAGE_KEY_PAGE_TRANSITION_MODE) private pageTransitionMode: string = DEFAULT_PAGE_TRANSITION_MODE;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp('harmonyx.status_bar_height') statusBarHeight: number = 0;
  @StorageProp('harmonyx.navigation_indicator_height') bottomInset: number = 0;
  @StorageProp('harmonyx.display_mode') displayMode: string = '';
  @StorageProp('harmonyx.dark_surface') darkSurface: string = '';
  @StorageLink('harmonyx.accent_color') accentColor: string = '#007DFF';
  @StorageProp('harmonyx.title_bar_style_mode') titleBarStyleMode: number = 0;
  @StorageProp(STORAGE_KEY_TITLE_BAR_GLASS_MATERIAL_LEVEL) inputMaterialLevel: number = DEFAULT_TITLE_BAR_GLASS_MATERIAL_LEVEL;
  @State private title: string = '';
  @State private username: string = '';
  @State private avatar: string = '';
  @State private section: string = '';
  @State private nickname: string = '';
  @State private ttl: string = '0';
  @State private screenBlocked: boolean = false;
  @State private muted: boolean = false;
  @State private busy: boolean = false;
  @State private error: string = '';
  @State private fingerprint: string = '';
  @State private peerFingerprint: string = '';
  @State private safetyVerified: boolean = false;
  @State private sharedMedia: ChatSharedMedia[] = [];
  @State private sharedLinks: string[] = [];
  private route: DmInfoRouteParam | null = null;
  private active: boolean = true;
  private loading: boolean = false;
  private account: string = '';
  private originalNickname: string = '';
  private scroller: Scroller = new Scroller();
  private context(): common.UIAbilityContext { return getContext(this) as common.UIAbilityContext; }
  private text(resource: Resource): string { return this.context().resourceManager.getStringSync(resource); }
  aboutToAppear(): void {
    const params: DmInfoRouteParam[] = this.pageStack.getParamByName('DmInfo') as DmInfoRouteParam[];
    if (params.length === 0) { return; }
    this.route = params[params.length - 1];
    this.title = this.route.title; this.username = this.route.username; this.avatar = this.route.avatarUrl;
    this.section = this.route.section ?? '';
    this.account = xPrivateStore.load(this.context()).cacheIdentity();
    const info: XChatConversationInfo = xChatService.conversationInfo(this.route.conversationId);
    this.ttl = info.ttl; this.screenBlocked = info.screenBlocked; this.muted = info.muted;
    this.load();
  }
  aboutToDisappear(): void { this.active = false; }
  private valid(): boolean { return this.active && this.account === xPrivateStore.load(this.context()).cacheIdentity(); }
  private async load(): Promise<void> {
    if (this.route === null || this.loading) { return; }
    this.loading = true;
    try {
      const nickname: string = await xChatService.nickname(this.context(), this.route.conversationId);
      if (this.valid()) { this.nickname = nickname; this.originalNickname = nickname; }
      if ((this.section === 'safety' || this.section === '') && xChatService.isUnlocked()) {
        await xChatService.prepare(this.context(), this.route.participantIds);
        const fingerprint: string = await xChatService.fingerprint();
        if (this.valid()) { this.fingerprint = fingerprint; }
        const peers: string[] = this.route.participantIds.filter((id: string): boolean => id !== xPrivateClient.viewerId());
        peers.sort(); const fingerprints: string[] = [];
        for (let i: number = 0; i < peers.length; i++) {
          const value: string = await xChatService.fingerprint(peers[i]);
          fingerprints.push(this.route.group ? peers[i] + ': ' + value : value);
        }
        const theirs: string = fingerprints.join('\n');
        if (this.valid()) {
          this.peerFingerprint = theirs;
          this.safetyVerified = xChatActions.localString(this.context(), 'safety:' + this.route.conversationId, '') === fingerprint + ':' + theirs;
        }
      } else if (this.section === 'media') {
        this.busy = true;
        await this.loadHistory();
        if (!this.valid()) { return; }
        const rows: DmMessage[] = xChatService.cachedMessages(this.route.conversationId);
        const media: ChatSharedMedia[] = []; const links: string[] = [];
        for (let i: number = 0; i < rows.length; i++) {
          const attachments: DmAttachment[] = rows[i].attachments ?? [];
          for (let n: number = 0; n < attachments.length; n++) {
            if (attachments[n].type === 'Media') { media.push({ attachment: attachments[n], keyVersion: rows[i].keyVersion ?? '', id: rows[i].id + ':' + n }); }
            if (/^https?:\/\//i.test(attachments[n].url) && links.indexOf(attachments[n].url) < 0) { links.push(attachments[n].url); }
          }
          const matches: RegExpMatchArray | null = rows[i].text.match(/https?:\/\/[^\s<>]+/g);
          if (matches !== null) { for (let n: number = 0; n < matches.length; n++) { if (links.indexOf(matches[n]) < 0) { links.push(matches[n]); } } }
        }
        this.sharedMedia = media; this.sharedLinks = links;
      }
    } catch (error) { if (this.valid() && this.section.length > 0) { this.error = this.text($r('app.string.chat_action_failed')); } }
    finally { this.loading = false; if (this.valid()) { this.busy = false; } }
  }
  private async loadHistory(strict: boolean = false): Promise<DmMessage[]> {
    if (this.route === null) { return []; }
    let sequence: string = ''; let version: string = '';
    let rows: DmMessage[] = [];
    for (let i: number = 0; i < 200; i++) {
      const page: XChatPage = await xChatService.conversation(this.route.conversationId, sequence, version);
      if (!this.valid() || page.needsUnlock || (strict && page.error.length > 0)) { throw new Error('history_unavailable'); }
      rows = XChatService.merge(rows, page);
      if (!page.hasMore) { return rows; }
      if (page.minSequenceId.length === 0 || page.minSequenceId === sequence) { throw new Error('history_cursor_stalled'); }
      sequence = page.minSequenceId; version = page.minKeyVersion;
    }
    throw new Error('history_too_large');
  }
  private verifySafety(): void {
    if (this.route === null || this.fingerprint.length === 0 || this.peerFingerprint.length === 0) { return; }
    xChatActions.saveLocal(this.context(), 'safety:' + this.route.conversationId, this.fingerprint + ':' + this.peerFingerprint);
    this.safetyVerified = true;
  }
  private open(section: string): void {
    if (this.route === null) { return; }
    const param: DmInfoRouteParam = { conversationId: this.route.conversationId, title: this.route.title,
      username: this.route.username, avatarUrl: this.route.avatarUrl, group: this.route.group,
      participantIds: this.route.participantIds, latestSequenceId: this.route.latestSequenceId, section: section };
    this.pageStack.pushPath({ name: 'DmInfo', param: param });
  }
  private openBackground(): void {
    if (this.route === null) { return; }
    const param: ChatBackgroundRouteParam = { conversationId: this.route.conversationId };
    this.pageStack.pushPath({ name: 'ChatBackground', param: param });
  }
  private async saveNickname(): Promise<void> {
    if (this.route === null || this.busy) { return; }
    this.busy = true;
    try { await xChatService.saveNickname(this.context(), this.route.conversationId, this.nickname.trim()); if (this.valid()) { this.pageStack.pop(); } }
    catch (error) { if (this.valid()) { this.error = this.text($r('app.string.chat_action_failed')); } }
    finally { if (this.valid()) { this.busy = false; } }
  }
  private async act(kind: string, value: string = ''): Promise<void> {
    if (this.route === null || this.busy) { return; }
    const route: DmInfoRouteParam = this.route;
    if (kind === 'delete' || kind === 'clear') {
      const result: promptAction.ShowDialogSuccessResponse = await promptAction.showDialog({
        message: this.text(kind === 'delete' ? $r('app.string.chat_delete_confirm') : $r('app.string.chat_clear_confirm')),
        buttons: [{ text: this.text($r('app.string.compose_cancel')), color: '' },
          { text: this.text(kind === 'delete' ? $r('app.string.chat_delete') : $r('app.string.chat_clear')), color: '' }]
      });
      if (result.index !== 1 || !this.valid()) { return; }
    }
    this.busy = true; this.error = '';
    try {
      if (kind === 'hide') {
        xChatActions.setInboxHidden(this.context(), route.conversationId, route.latestSequenceId, true);
      } else if (kind === 'mute') { await xChatActions.mute(route.conversationId, !this.muted); if (this.valid()) { this.muted = !this.muted; } }
      else if (kind === 'block') {
        await xChatActions.block(route.participantIds.filter((id: string): boolean => id !== xPrivateClient.viewerId()), true);
      } else if (kind === 'screen') { await xChatActions.screenCapture(route.conversationId, !this.screenBlocked); if (this.valid()) { this.screenBlocked = !this.screenBlocked; } }
      else if (kind === 'ttl') { await xChatActions.ttl(route.conversationId, value); if (this.valid()) { this.ttl = value; } }
      else if (kind === 'delete') { await xChatService.deleteConversation(route.conversationId); }
      else if (kind === 'clear') {
        const messages: DmMessage[] = await this.loadHistory(true);
        const sequences: string[] = messages.map((message: DmMessage): string => message.sequenceId ?? '').filter((id: string): boolean => id.length > 0);
        for (let i: number = 0; i < sequences.length; i += 50) {
          if (!this.valid()) { throw new Error('account_changed'); }
          await xChatService.deleteMessages(route.conversationId, sequences.slice(i, i + 50));
        }
      }
      if (this.valid()) { xChatService.setConversationInfo(route.conversationId, { ttl: this.ttl, screenBlocked: this.screenBlocked, muted: this.muted }); }
      if (this.valid() && (kind === 'hide' || kind === 'delete' || kind === 'clear')) { this.pageStack.pop(); }
    } catch (error) { if (this.valid()) { this.error = this.text($r('app.string.chat_action_failed')); } }
    finally { if (this.valid()) { this.busy = false; } }
  }
  private call(): void {
    if (this.route === null) { return; }
    const param: DmWebRouteParam = { conversationId: this.route.conversationId, title: this.title };
    this.pageStack.pushPath({ name: 'DmWeb', param: param });
    promptAction.showToast({ message: this.text($r('app.string.chat_call_web_hint')), duration: 3500 });
  }
  private profile(): void {
    if (this.route === null) { return; }
    const id: string = this.route.participantIds.filter((id: string): boolean => id !== xPrivateClient.viewerId())[0] ?? '';
    if (id.length > 0) {
      const author: TweetAuthor = { id: id, name: this.title, username: this.username,
        avatarColor: this.accentColor, avatarUrl: this.avatar, verified: false };
      const param: UserDetailRouteParam = { author: author, posts: [] };
      this.pageStack.pushPath({ name: 'UserDetail', param: param });
    }
  }
  private report(): void {
    if (this.route === null) { return; }
    const param: DmWebRouteParam = { conversationId: this.route.conversationId, title: this.title };
    this.pageStack.pushPath({ name: 'DmWeb', param: param });
  }

  private pageTitle(): ResourceStr {
    if (this.section === 'nickname') { return $r('app.string.chat_nickname'); }
    if (this.section === 'media') { return $r('app.string.chat_media_links_docs'); }
    if (this.section === 'safety') { return $r('app.string.chat_safety'); }
    return '';
  }

  private titleMenu(): HdsNavigationMenuItemOptions[] {
    if (this.section === 'nickname') {
      return [{ content: { label: $r('app.string.chat_done'), type: TextStyleMode.NORMAL,
        isEnabled: !this.busy && this.nickname.trim() !== this.originalNickname,
        action: (): void => { this.saveNickname(); } } }];
    }
    if (this.section.length === 0) {
      return [{ content: { icon: $r('sys.symbol.square_and_pencil'), label: $r('app.string.chat_nickname'),
        isEnabled: !this.busy, action: (): void => this.open('nickname') } }];
    }
    return [];
  }
  @Builder
  private MoreMenu(): void {
    Menu() {
      MenuItem({ content: $r('app.string.chat_hide'), symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.bell_slash')) }).onClick((): void => { this.act('hide'); })
      MenuItem({ content: $r('app.string.chat_search'), symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.magnifyingglass')) }).onClick((): void => {
        AppStorage.setOrCreate<string>('harmonyx.chat_search_conversation', this.route?.conversationId ?? ''); this.pageStack.pop();
      })
      MenuItem({ content: $r('app.string.chat_block'), symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.lock')) }).onClick((): void => { this.act('block'); })
      MenuItem({ content: $r('app.string.chat_report'), symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.flag')) }).contentFontColor($r('app.color.danger')).onClick((): void => this.report())
      MenuItem({ content: $r('app.string.chat_clear'), symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.trash')) }).contentFontColor($r('app.color.danger')).onClick((): void => { this.act('clear'); })
      MenuItem({ content: $r('app.string.chat_delete'), symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.trash')) }).contentFontColor($r('app.color.danger')).onClick((): void => { this.act('delete'); })
    }
  }
  @Builder
  private TtlMenu(): void {
    Menu() {
      MenuItem({ content: $r('app.string.chat_off') }).onClick((): void => { this.act('ttl', '0'); })
      MenuItem({ content: $r('app.string.chat_24_hours') }).onClick((): void => { this.act('ttl', '86400000'); })
      MenuItem({ content: $r('app.string.chat_7_days') }).onClick((): void => { this.act('ttl', '604800000'); })
    }
  }
  @Builder
  private Shortcut(symbol: Resource, title: Resource): void {
    Column({ space: 8 }) {
      if (title.id === $r('app.string.chat_more').id) {
        Button({ type: ButtonType.Circle }) { ChatMoreSymbol() }
          .width(56).height(56).backgroundColor(secondaryButtonSurfaceColor(this.displayMode, this.darkSurface))
          .accessibilityText(title).bindMenu(this.MoreMenu())
      } else {
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph(symbol).fontSize(24).fontColor([pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, secondaryButtonSurfaceColor(this.displayMode, this.darkSurface))])
        }.width(56).height(56).backgroundColor(secondaryButtonSurfaceColor(this.displayMode, this.darkSurface))
          .accessibilityText(title)
          .onClick((): void => { if (title.id === $r('app.string.chat_profile').id) { this.profile(); } else { this.call(); } })
      }
      Text(title).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent))
    }
  }
  @Builder
  private InfoRow(symbol: Resource, title: Resource, value: ResourceStr = ''): void {
    Row({ space: 12 }) {
      SymbolGlyph(symbol).fontSize(24).fontColor([pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent)])
      Text(title).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent)).layoutWeight(1)
      if (value !== '') { Text(value).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)) }
      SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(18).fontColor([pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)])
    }.width('100%').height(64).padding({ left: 12, right: 12 })
  }
  @Builder
  private Information(): void {
    Column({ space: 16 }) {
      ProxyAvatar({verifiedType: this.route?.verifiedType ?? this.route?.contactProfile?.verifiedType ?? '', avatarShape: this.route?.avatarShape ?? this.route?.contactProfile?.avatarShape ?? '',  url: this.avatar, avatarSize: 88, radius: 44, fallbackText: this.title.substring(0, 1) })
      Column({ space: 2 }) {
        Text(this.nickname.length > 0 ? this.nickname : this.title).fontFamily(this.appFontFamily).fontSize($r('sys.float.Title_S')).fontWeight(FontWeight.Bold).fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent))
        if (this.username.length > 0) { Text('@' + this.username).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)) }
      }
      Row() {
        Column() { this.Shortcut($r('sys.symbol.phone'), $r('app.string.chat_phone')) }.layoutWeight(1)
        Column() { this.Shortcut($r('sys.symbol.video'), $r('app.string.chat_video')) }.layoutWeight(1)
        Column() { this.Shortcut($r('sys.symbol.person'), $r('app.string.chat_profile')) }.layoutWeight(1)
        Column() { this.Shortcut($r('sys.symbol.more'), $r('app.string.chat_more')) }.layoutWeight(1)
      }.width('100%').margin({ top: 16, bottom: 8 })
      Column() {
        Column() { this.InfoRow($r('sys.symbol.camera'), $r('app.string.chat_media_links_docs')) }.onClick((): void => this.open('media'))
        Divider().color($r('app.color.divider'))
        Column() { this.InfoRow($r('sys.symbol.clock'), $r('app.string.chat_disappearing'), this.ttl === '0' ? $r('app.string.chat_off') : $r('app.string.chat_on')) }.bindMenu(this.TtlMenu())
        Divider().color($r('app.color.divider'))
        Column() { this.InfoRow($r('sys.symbol.camera'), $r('app.string.chat_block_capture'), this.screenBlocked ? $r('app.string.chat_on') : $r('app.string.chat_off')) }.onClick((): void => { this.act('screen'); })
        Divider().color($r('app.color.divider'))
        Column() { this.InfoRow($r('sys.symbol.lock'), $r('app.string.chat_safety'), this.safetyVerified ?
          $r('app.string.chat_verified_safety') : $r('app.string.chat_unverified')) }.onClick((): void => this.open('safety'))
        Divider().color($r('app.color.divider'))
        Column() { this.InfoRow($r('sys.symbol.picture'), $r('app.string.chat_background')) }.onClick((): void => this.openBackground())
      }.width('100%').padding({ left: 12, right: 12 }).borderRadius(16)
        .backgroundColor(secondaryButtonSurfaceColor(this.displayMode, this.darkSurface))
    }.width('100%').padding({ left: 16, right: 16, top: 32, bottom: 24 })
  }
  build(): void {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        appPageBackground()
      Scroll(this.scroller) {
        Column() {
          if (this.busy) { LoadingProgress().width(24).height(24).color(this.accentColor).margin(12) }
          if (this.error.length > 0) { Text(this.error).fontFamily(this.appFontFamily).fontColor($r('app.color.danger')).fontSize($r('sys.float.Body_M')).padding(16) }
          if (this.section === 'nickname') {
            Column({ space: 24 }) {
              Text($r('app.string.chat_nickname_hint')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary')).width('100%')
              TextInput({ text: this.nickname, placeholder: $r('app.string.chat_nickname') }).fontFamily(this.appFontFamily)
                .keyboardAppearance(KeyboardAppearance.IMMERSIVE).fontSize($r('sys.float.Body_L'))
                .maxLength(50).height(48).borderRadius(24)
                .border({ width: SystemMaterialUtil.isApi26OrAbove() ? 0 : 1, color: $r('app.color.divider') })
                .systemMaterial(chatInputMaterial(this.inputMaterialLevel))
                .backgroundColor(Color.Transparent).onChange((value: string): void => { this.nickname = value; })
            }.width('100%').padding(24)
          } else if (this.section === 'safety') {
            Column({ space: 24 }) {
              Text($r('app.string.chat_safety_hint')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_secondary'))
              Text($r('app.string.chat_your_key')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary'))
              Text(this.fingerprint).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_primary')).copyOption(CopyOptions.LocalDevice)
              Text($r('app.string.chat_their_key')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary'))
              Text(this.peerFingerprint).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_primary')).copyOption(CopyOptions.LocalDevice)
              Button(this.safetyVerified ? $r('app.string.chat_verified_safety') : $r('app.string.chat_verify'))
                .backgroundColor(this.accentColor).fontColor($r('app.color.text_on_accent'))
                .enabled(!this.safetyVerified && this.peerFingerprint.length > 0).onClick((): void => this.verifySafety())
            }.width('100%').padding(24)
          } else if (this.section === 'media') {
            Column({ space: 20 }) {
              if (this.sharedMedia.length === 0 && this.sharedLinks.length === 0 && !this.busy) {
                Text($r('app.string.chat_no_media')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_secondary'))
              }
              ForEach(this.sharedMedia, (item: ChatSharedMedia) => {
                ChatMediaCard({ attachment: item.attachment, conversationId: this.route?.conversationId ?? '', keyVersion: item.keyVersion })
              }, (item: ChatSharedMedia): string => item.id)
              ForEach(this.sharedLinks, (link: string) => {
                Text(link).fontFamily(this.appFontFamily).fontColor(this.accentColor).fontSize($r('sys.float.Body_L')).copyOption(CopyOptions.LocalDevice)
                  .onClick((): void => { openExternalLink(this.context(), link); })
              })
            }.width('100%').padding(24)
          } else { this.Information() }
        }.width('100%').padding({ top: this.statusBarHeight + 64, bottom: this.bottomInset + 24 })
      }.width('100%').height('100%').scrollBar(BarState.Off).align(Alignment.Top)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    
      }.width('100%').height('100%')
    }
    .scale({ x: this.pageMotion.scale, y: this.pageMotion.scale })
    .opacity(this.pageMotion.opacity)
    .onReady((context: NavDestinationContext): void => { this.pageMotion.attach(context); })
    .systemTransition(pageSystemTransition(this.pageTransitionMode)).titleMode(HdsNavDestinationTitleMode.MINI).hideBackButton(false).bindToScrollable([this.scroller])
      .titleBar({ avoidLayoutSafeArea: true,
        content: { title: { mainTitle: this.pageTitle() }, menu: { value: this.titleMenu() } },
        style: destinationTitleBarStyle(ScrollEffectType.GRADIENT_BLUR, this.displayMode, this.darkSurface, this.titleBarStyleMode)
      })
      .backgroundColor(pageCanvasColor(this.displayMode, this.darkSurface, this.pageBackgroundValue)).systemMaterial(chatPageMaterial())
      .onShown((): void => { this.load(); })
      .onBackPressed((): boolean => { ResponsiveLayout.closeContentDestination(this.pageStack); return true; })
  }
}
