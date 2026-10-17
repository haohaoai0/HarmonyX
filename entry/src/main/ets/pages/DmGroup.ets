import { common } from '@kit.AbilityKit';
import { SymbolGlyphModifier } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import promptAction from '@ohos.promptAction';
import { HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationMenuItemOptions,
  ScrollEffectType, TextStyleMode } from '@kit.UIDesignKit';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { XChatGroupState, XChatGroupMember, xChatGroupService } from '../services/XChatGroupService';
import { ChatPerson, xChatActions } from '../services/XChatActions';
import { xChatService } from '../services/XChatService';
import { xChatMedia, ChatGroupAvatarUpload } from '../services/XChatMedia';
import { xPrivateClient } from '../services/XPrivateClient';
import { xPrivateStore } from '../services/XPrivateStore';
import { ProxyAvatar } from '../components/ProxyAvatar';
import { ChatMoreSymbol } from '../components/ChatMoreSymbol';
import { DmInfoRouteParam } from './DmInfo';
import { DmConversationRouteParam } from './DmConversation';
import { DmWebRouteParam } from './DmWeb';
import { ChatBackgroundRouteParam } from './ChatBackground';
import { pageSurfaceColor, secondaryButtonSurfaceColor, fieldSurfaceColor } from '../utils/ThemeColors';
import { destinationTitleBarStyle } from '../utils/DestinationTitleBar';
import { chatPageMaterial, chatInputMaterial } from '../utils/ChatMaterial';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';
import { STORAGE_KEY_TITLE_BAR_GLASS_MATERIAL_LEVEL, DEFAULT_TITLE_BAR_GLASS_MATERIAL_LEVEL } from '../services/AppearanceStore';

export interface DmGroupRouteParam extends DmInfoRouteParam { memberId?: string; }

@Builder
export function DmGroupBuilder(): void { DmGroupPage(); }

@Component
struct DmGroupPage {
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp('harmonyx.status_bar_height') statusBarHeight: number = 0;
  @StorageProp('harmonyx.navigation_indicator_height') bottomInset: number = 0;
  @StorageProp('harmonyx.display_mode') displayMode: string = '';
  @StorageProp('harmonyx.dark_surface') darkSurface: string = '';
  @StorageProp('harmonyx.accent_color') accentColor: string = '#007DFF';
  @StorageProp('harmonyx.title_bar_style_mode') titleBarStyleMode: number = 0;
  @StorageProp(STORAGE_KEY_TITLE_BAR_GLASS_MATERIAL_LEVEL) inputMaterialLevel: number = DEFAULT_TITLE_BAR_GLASS_MATERIAL_LEVEL;
  @State private group: XChatGroupState = new XChatGroupState();
  @State private section: string = '';
  @State private name: string = '';
  @State private description: string = '';
  @State private avatarUri: string = '';
  @State private query: string = '';
  @State private nickname: string = '';
  @State private people: ChatPerson[] = [];
  @State private selected: string[] = [];
  @State private busy: boolean = false;
  @State private loading: boolean = false;
  @State private loaded: boolean = false;
  @State private error: string = '';
  private route: DmGroupRouteParam | null = null;
  private account: string = '';
  private active: boolean = true;
  private timer: number = -1;
  private searchGeneration: number = 0;
  private scroller: Scroller = new Scroller();

  private context(): common.UIAbilityContext { return getContext(this) as common.UIAbilityContext; }
  private text(resource: Resource): string { return this.context().resourceManager.getStringSync(resource); }
  private valid(): boolean { return this.active && this.account === xPrivateStore.load(this.context()).cacheIdentity(); }
  aboutToAppear(): void {
    const params: DmGroupRouteParam[] = this.pageStack.getParamByName('DmGroup') as DmGroupRouteParam[];
    if (params.length === 0) { return; }
    this.route = params[params.length - 1]; this.section = this.route.section ?? '';
    this.account = xPrivateStore.load(this.context()).cacheIdentity();
    this.name = this.route.title; this.load();
  }
  aboutToDisappear(): void { this.active = false; this.searchGeneration++; if (this.timer >= 0) { clearTimeout(this.timer); } }
  private async load(): Promise<void> {
    if (this.route === null || this.loading || !this.valid()) { return; }
    this.loading = true; this.error = '';
    try {
      const group: XChatGroupState = await xChatGroupService.load(this.context(), this.route.conversationId);
      if (!this.valid()) { return; }
      this.group = group; this.loaded = true;
      if (this.section === 'edit' && this.avatarUri.length === 0) { this.name = group.name; this.description = group.description; }
      if (this.section === 'nickname') {
        const member: XChatGroupMember | undefined = group.members.find((item: XChatGroupMember): boolean => item.id === this.route?.memberId);
        this.nickname = member?.nickname ?? '';
      }
      if (this.section === 'add') { this.search(); }
    } catch (error) { if (this.valid()) { this.error = this.text($r('app.string.chat_group_load_failed')); } }
    finally { if (this.valid()) { this.loading = false; } }
  }
  private allowed(key: string): boolean {
    if (!this.loaded || this.busy) { return false; }
    if (this.group.isAdmin) { return true; }
    if (key === 'addMember') { return !this.group.permissions.addMember; }
    if (key === 'editGroupInfo') { return !this.group.permissions.editGroupInfo; }
    if (key === 'startCall') { return !this.group.permissions.startCall; }
    if (key === 'editMessageTtl') { return !this.group.permissions.editMessageTtl; }
    if (key === 'blockScreenCapture') { return !this.group.permissions.blockScreenCapture; }
    return false;
  }
  private open(section: string, memberId: string = ''): void {
    if (this.route === null) { return; }
    const param: DmGroupRouteParam = { conversationId: this.route.conversationId,
      title: this.group.name.length > 0 ? this.group.name : this.route.title, username: '',
      avatarUrl: this.group.avatarUrl, group: true, participantIds: this.group.memberIds,
      latestSequenceId: this.route.latestSequenceId, section: section, memberId: memberId };
    this.pageStack.pushPath({ name: 'DmGroup', param: param });
  }
  private openInfo(section: string): void {
    if (this.route === null) { return; }
    const param: DmInfoRouteParam = { conversationId: this.route.conversationId, title: this.group.name,
      username: '', avatarUrl: this.group.avatarUrl, group: true, participantIds: this.group.memberIds,
      latestSequenceId: this.route.latestSequenceId, section: section };
    this.pageStack.pushPath({ name: 'DmInfo', param: param });
  }
  private openBackground(): void {
    if (this.route === null) { return; }
    const param: ChatBackgroundRouteParam = { conversationId: this.route.conversationId };
    this.pageStack.pushPath({ name: 'ChatBackground', param: param });
  }
  private call(): void {
    if (this.route === null || !this.allowed('startCall')) { return; }
    const param: DmWebRouteParam = { conversationId: this.route.conversationId, title: this.group.name };
    this.pageStack.pushPath({ name: 'DmWeb', param: param });
    promptAction.showToast({ message: this.text($r('app.string.chat_call_web_hint')), duration: 3500 });
  }
  private async run(action: () => Promise<void>, close: boolean = false): Promise<void> {
    if (this.busy || !this.valid()) { return; }
    this.busy = true; this.error = '';
    try {
      await action();
      if (!this.valid()) { return; }
      if (close) { this.pageStack.pop(); } else { await this.load(); }
    } catch (error) { if (this.valid()) { this.error = this.text($r('app.string.chat_group_edit_failed')) + ' (' + (error as Error).message + ')'; } }
    finally { if (this.valid()) { this.busy = false; } }
  }
  private async confirm(message: Resource, label: Resource): Promise<boolean> {
    const result: promptAction.ShowDialogSuccessResponse = await promptAction.showDialog({ message: this.text(message),
      buttons: [{ text: this.text($r('app.string.compose_cancel')), color: '' }, { text: this.text(label), color: '' }] });
    return result.index === 1 && this.valid();
  }
  private async leave(): Promise<void> {
    if (this.busy || !await this.confirm($r('app.string.chat_group_leave_confirm'), $r('app.string.chat_group_leave'))) { return; }
    await this.run(async (): Promise<void> => {
      await xChatGroupService.leave(this.context(), this.group);
      if (this.valid()) {
        const names: string[] = this.pageStack.getAllPathName();
        const index: number = names.lastIndexOf('DmConversation');
        if (index >= 0) { this.pageStack.popToIndex(index); this.pageStack.pop(); }
        else { this.pageStack.pop(); }
      }
    });
  }
  private async clear(): Promise<void> {
    if (this.busy || !await this.confirm($r('app.string.chat_clear_confirm'), $r('app.string.chat_clear'))) { return; }
    await this.run(async (): Promise<void> => { await xChatGroupService.clear(this.context(), this.group); });
  }
  private async remove(member: XChatGroupMember): Promise<void> {
    if (!this.group.isAdmin || !await this.confirm($r('app.string.chat_group_remove_confirm'), $r('app.string.chat_group_remove_member'))) { return; }
    await this.run(async (): Promise<void> => { await xChatGroupService.remove(this.context(), this.group, member.id); });
  }
  private async save(): Promise<void> {
    if (this.section === 'edit') {
      if (!this.allowed('editGroupInfo') || this.name.trim().length === 0) { return; }
      await this.run(async (): Promise<void> => {
        let avatar: string | undefined = undefined; let version: string | undefined = undefined;
        if (this.avatarUri.length > 0) {
          const uploaded: ChatGroupAvatarUpload = await xChatMedia.uploadGroupAvatar(this.context(), this.group.id, this.avatarUri);
          avatar = uploaded.url; version = uploaded.keyVersion;
        }
        if (!this.valid()) { throw new Error('account_changed'); }
        await xChatGroupService.edit(this.context(), this.group, this.name.trim(), this.description, avatar, version);
      }, true);
    } else if (this.section === 'add') {
      if (!this.allowed('addMember') || this.selected.length === 0) { return; }
      await this.run(async (): Promise<void> => { await xChatGroupService.add(this.context(), this.group, this.selected); }, true);
    } else if (this.section === 'nickname' && this.route !== null) {
      const id: string = this.route.memberId ?? '';
      await this.run(async (): Promise<void> => { await xChatGroupService.saveMemberNickname(this.context(), this.group.id, id, this.nickname.trim()); }, true);
    }
  }
  private async pickAvatar(): Promise<void> {
    if (!this.allowed('editGroupInfo')) { return; }
    try {
      const options: photoAccessHelper.PhotoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE; options.maxSelectNumber = 1;
      const result: photoAccessHelper.PhotoSelectResult = await new photoAccessHelper.PhotoViewPicker().select(options);
      if (this.valid() && result.photoUris.length > 0) { this.avatarUri = result.photoUris[0]; }
    } catch (error) { if (this.valid()) { this.error = this.text($r('app.string.chat_group_edit_failed')); } }
  }
  private changeQuery(value: string): void {
    this.query = value; this.searchGeneration++;
    if (this.timer >= 0) { clearTimeout(this.timer); }
    this.timer = setTimeout((): void => { this.search(); }, 300);
  }
  private async search(): Promise<void> {
    const generation: number = ++this.searchGeneration;
    try {
      const people: ChatPerson[] = await xChatActions.people(this.query, true);
      if (this.valid() && generation === this.searchGeneration) {
        this.people = people.filter((person: ChatPerson): boolean => this.group.memberIds.indexOf(person.id) < 0 && person.canGroup);
      }
    } catch (error) { if (this.valid() && generation === this.searchGeneration) { this.error = this.text($r('app.string.chat_group_load_failed')); } }
  }
  private message(member: XChatGroupMember): void {
    const ids: string[] = [xPrivateClient.viewerId(), member.id];
    ids.sort((a: string, b: string): number => a.length !== b.length ? a.length - b.length : a > b ? 1 : a < b ? -1 : 0);
    const param: DmConversationRouteParam = { conversationId: ids.join('-'), title: member.name,
      username: member.username, avatarUrl: member.avatarUrl, verifiedType: member.verifiedType,
      avatarShape: member.avatarShape, group: false, participantIds: ids, latestSequenceId: '' };
    this.pageStack.pushPath({ name: 'DmConversation', param: param });
  }
  private async copyLink(): Promise<void> {
    if (!this.group.inviteEnabled || this.group.inviteUrl.length === 0) { return; }
    await pasteboard.getSystemPasteboard().setPasteData(pasteboard.createPlainTextData(this.group.inviteUrl));
    if (this.valid()) { promptAction.showToast({ message: this.text($r('app.string.chat_group_link_copied')) }); }
  }
  private title(): ResourceStr {
    if (this.section === 'edit') { return $r('app.string.chat_group_edit'); }
    if (this.section === 'invite') { return $r('app.string.chat_group_invite'); }
    if (this.section === 'permissions') { return $r('app.string.chat_group_permissions'); }
    if (this.section === 'admins') { return $r('app.string.chat_group_select_admin'); }
    if (this.section === 'add') { return $r('app.string.chat_group_add_members'); }
    if (this.section === 'nickname') { return $r('app.string.chat_group_member_nickname'); }
    if (this.section === 'ttl') { return $r('app.string.chat_disappearing'); }
    if (this.section === 'capture') { return $r('app.string.chat_block_capture'); }
    return $r('app.string.chat_group_info');
  }
  private menu(): HdsNavigationMenuItemOptions[] {
    if (this.section === 'edit' || this.section === 'add' || this.section === 'nickname') {
      return [{ content: { label: this.section === 'add' ? $r('app.string.chat_group_add') : $r('app.string.chat_done'), type: TextStyleMode.NORMAL,
        isEnabled: this.loaded && !this.busy && (this.section !== 'add' || this.selected.length > 0) &&
          (this.section !== 'edit' || this.name.trim().length > 0 && (this.avatarUri.length > 0 || this.name.trim() !== this.group.name || this.description !== this.group.description)),
        action: (): void => { this.save(); } } }];
    }
    if (this.section.length === 0) {
      return [{ content: { icon: $r('sys.symbol.square_and_pencil'), label: $r('app.string.chat_group_edit'),
        isEnabled: this.allowed('editGroupInfo'), action: (): void => this.open('edit') } }];
    }
    return [];
  }
  @Builder
  private MoreMenu(): void {
    Menu() {
      MenuItem({ content: $r('app.string.chat_search'), symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.magnifyingglass')) })
        .onClick((): void => { AppStorage.setOrCreate<string>('harmonyx.chat_search_conversation', this.group.id); this.pageStack.pop(); })
      MenuItem({ content: $r('app.string.chat_group_leave'), symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.arrow_right')) })
        .contentFontColor($r('app.color.danger')).onClick((): void => { this.leave(); })
      MenuItem({ content: $r('app.string.chat_clear'), symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.trash')) })
        .contentFontColor($r('app.color.danger')).onClick((): void => { this.clear(); })
    }
  }
  @Builder
  private MemberMenu(member: XChatGroupMember): void {
    Menu() {
      if (member.id !== xPrivateClient.viewerId()) {
        MenuItem({ content: $r('app.string.chat_group_member_dm') }).onClick((): void => this.message(member))
      }
      MenuItem({ content: $r('app.string.chat_group_member_nickname') }).onClick((): void => this.open('nickname', member.id))
      if (this.group.isAdmin && member.id !== xPrivateClient.viewerId()) {
        MenuItem({ content: member.admin ? $r('app.string.chat_group_remove_admin') : $r('app.string.chat_group_add_admin') })
          .onClick((): void => { this.run(async (): Promise<void> => { await xChatGroupService.setAdmin(this.context(), this.group, member.id, !member.admin); }); })
        MenuItem({ content: $r('app.string.chat_group_remove_member') }).contentFontColor($r('app.color.danger'))
          .onClick((): void => { this.remove(member); })
      }
    }
  }
  @Builder
  private RowContent(symbol: Resource, title: Resource, value: ResourceStr = ''): void {
    Row({ space: 12 }) {
      SymbolGlyph(symbol).fontSize(22).fontColor([$r('app.color.text_primary')])
      Text(title).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_primary')).layoutWeight(1)
      if (value !== '') { Text(value).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary')) }
      SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(16).fontColor([$r('app.color.text_secondary')])
    }.width('100%').constraintSize({ minHeight: 64 }).padding({ left: 16, right: 16, top: 12, bottom: 12 })
  }
  @Builder
  private Hint(value: Resource): void {
    Text(value).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary')).width('100%').padding({ left: 16, right: 16, top: 8, bottom: 16 })
  }
  @Builder
  private Shortcut(symbol: Resource, label: Resource, kind: string, enabled: boolean = true): void {
    Column({ space: 8 }) {
      Button({ type: ButtonType.Circle }) { SymbolGlyph(symbol).fontSize(24).fontColor([$r('app.color.text_primary')]) }
        .width(56).height(56).backgroundColor(secondaryButtonSurfaceColor(this.displayMode, this.darkSurface)).enabled(enabled && !this.busy)
        .accessibilityText(label).onClick((): void => {
          if (kind === 'add') { this.open('add'); }
          else if (kind === 'call') { this.call(); }
          else if (kind === 'hide' && this.route !== null) {
            xChatActions.setInboxHidden(this.context(), this.group.id, this.route.latestSequenceId, true); this.pageStack.pop();
          }
        })
      Text(label).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_primary'))
    }.layoutWeight(1)
  }
  @Builder
  private Member(member: XChatGroupMember): void {
    Row({ space: 12 }) {
      ProxyAvatar({ url: member.avatarUrl, avatarSize: 44, radius: 22, fallbackText: member.name.substring(0, 1), verifiedType: member.verifiedType, avatarShape: member.avatarShape })
      Text(member.nickname.length > 0 ? member.nickname : member.name).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_primary'))
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
      if (member.admin) { Text($r('app.string.chat_group_admin')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S')).fontColor($r('app.color.text_secondary')) }
      Button({ type: ButtonType.Circle }) { ChatMoreSymbol() }.width(40).height(40).backgroundColor(Color.Transparent)
        .enabled(!this.busy).bindMenu(this.MemberMenu(member)).accessibilityText($r('app.string.chat_more'))
    }.width('100%').padding({ left: 16, right: 8, top: 12, bottom: 12 })
  }
  @Builder
  private Information(): void {
    Column({ space: 16 }) {
      ProxyAvatar({ url: this.group.avatarUrl.length > 0 ? this.group.avatarUrl : this.route?.avatarUrl ?? '', avatarSize: 88, radius: 28,
        fallbackText: this.group.name.substring(0, 1) })
      if (this.loaded && this.group.avatarRemoteUrl.length > 0 && this.group.avatarUrl.length === 0) {
        Text($r('app.string.chat_group_avatar_failed')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S')).fontColor($r('app.color.text_secondary'))
          .onClick((): void => { this.load(); })
      }
      Text(this.group.name.length > 0 ? this.group.name : this.route?.title ?? '').fontFamily(this.appFontFamily).fontSize($r('sys.float.Title_S')).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
      Text(this.text($r('app.string.chat_group_members_count')).replace('%d', String(this.group.memberIds.length))).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary'))
      if (this.group.description.length > 0) { Text(this.group.description).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_secondary')) }
      Row() {
        this.Shortcut($r('sys.symbol.person_badge_plus'), $r('app.string.chat_group_add'), 'add', this.allowed('addMember'))
        this.Shortcut($r('sys.symbol.video'), $r('app.string.chat_video'), 'call', this.allowed('startCall'))
        this.Shortcut($r('sys.symbol.bell_slash'), $r('app.string.chat_hide'), 'hide')
        Column({ space: 8 }) {
          Button({ type: ButtonType.Circle }) { ChatMoreSymbol() }.width(56).height(56)
            .backgroundColor(secondaryButtonSurfaceColor(this.displayMode, this.darkSurface)).enabled(!this.busy).bindMenu(this.MoreMenu())
            .accessibilityText($r('app.string.chat_more'))
          Text($r('app.string.chat_more')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_primary'))
        }.layoutWeight(1)
      }.width('100%').margin({ top: 12, bottom: 8 })
      Column() {
        Column() { this.RowContent($r('sys.symbol.camera'), $r('app.string.chat_media_links_docs')) }.onClick((): void => this.openInfo('media'))
        Divider().color($r('app.color.divider'))
        Column() { this.RowContent($r('sys.symbol.clock'), $r('app.string.chat_disappearing'), this.group.ttlMsec > 0 ? $r('app.string.chat_on') : $r('app.string.chat_off')) }
          .enabled(this.allowed('editMessageTtl')).onClick((): void => this.open('ttl'))
        Divider().color($r('app.color.divider'))
        Column() { this.RowContent($r('sys.symbol.camera'), $r('app.string.chat_block_capture'), this.group.screenCaptureBlockingEnabled ? $r('app.string.chat_on') : $r('app.string.chat_off')) }
          .enabled(this.allowed('blockScreenCapture')).onClick((): void => this.open('capture'))
        Divider().color($r('app.color.divider'))
        Column() { this.RowContent($r('sys.symbol.link'), $r('app.string.chat_group_invite'), this.group.inviteEnabled ? $r('app.string.chat_on') : $r('app.string.chat_off')) }
          .onClick((): void => this.open('invite'))
        Divider().color($r('app.color.divider'))
        Column() { this.RowContent($r('sys.symbol.lock'), $r('app.string.chat_group_permissions')) }.onClick((): void => this.open('permissions'))
        Divider().color($r('app.color.divider'))
        Column() { this.RowContent($r('sys.symbol.picture'), $r('app.string.chat_background')) }.onClick((): void => this.openBackground())
      }.width('100%').borderRadius(16).backgroundColor(secondaryButtonSurfaceColor(this.displayMode, this.darkSurface))
      Text(this.text($r('app.string.chat_group_members_count')).replace('%d', String(this.group.memberIds.length))).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary')).width('100%').padding({ left: 16, top: 8 })
      Column() {
        Column() { this.RowContent($r('sys.symbol.plus'), $r('app.string.chat_group_add_members')) }.enabled(this.allowed('addMember')).onClick((): void => this.open('add'))
        ForEach(this.group.members, (member: XChatGroupMember) => {
          Divider().color($r('app.color.divider')).margin({ left: 16, right: 16 })
          this.Member(member)
        }, (member: XChatGroupMember): string => member.id)
      }.width('100%').borderRadius(16).backgroundColor(secondaryButtonSurfaceColor(this.displayMode, this.darkSurface))
    }.width('100%').padding({ left: 16, right: 16, top: 24, bottom: 16 })
  }
  @Builder
  private Edit(): void {
    Column({ space: 16 }) {
      Column({ space: 8 }) {
        ProxyAvatar({ url: this.avatarUri.length > 0 ? this.avatarUri : this.group.avatarUrl, avatarSize: 88, radius: 28, fallbackText: this.name.substring(0, 1) })
        Text($r('app.string.chat_group_avatar_edit')).fontFamily(this.appFontFamily).fontColor(this.accentColor).fontSize($r('sys.float.Body_M'))
      }.onClick((): void => { this.pickAvatar(); }).margin({ bottom: 12 })
      Text($r('app.string.chat_group_title')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary')).width('100%')
      TextInput({ text: this.name, placeholder: $r('app.string.chat_group_empty_name') }).fontFamily(this.appFontFamily)
        .keyboardAppearance(KeyboardAppearance.IMMERSIVE).maxLength(100).height(52).fontSize($r('sys.float.Body_L'))
        .backgroundColor(fieldSurfaceColor(this.displayMode, this.darkSurface)).borderRadius(24).systemMaterial(chatInputMaterial(this.inputMaterialLevel))
        .onChange((value: string): void => { this.name = value; })
      Text($r('app.string.chat_group_description')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary')).width('100%').margin({ top: 12 })
      TextArea({ text: this.description }).fontFamily(this.appFontFamily).keyboardAppearance(KeyboardAppearance.IMMERSIVE).maxLength(1000)
        .height(144).fontSize($r('sys.float.Body_L')).backgroundColor(fieldSurfaceColor(this.displayMode, this.darkSurface)).borderRadius(24)
        .onChange((value: string): void => { this.description = value; })
      this.Hint($r('app.string.chat_group_description_hint'))
    }.width('100%').padding(24).enabled(!this.busy)
  }
  @Builder
  private PermissionMenu(key: string): void {
    Menu() {
      MenuItem({ content: $r('app.string.chat_everyone') }).onClick((): void => { this.run(async (): Promise<void> => { await xChatGroupService.setPermission(this.context(), this.group, key, false); }); })
      MenuItem({ content: $r('app.string.chat_group_admin_only') }).onClick((): void => { this.run(async (): Promise<void> => { await xChatGroupService.setPermission(this.context(), this.group, key, true); }); })
    }
  }
  @Builder
  private PermissionRow(title: Resource, key: string, adminOnly: boolean): void {
    Row({ space: 12 }) {
      Text(title).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_primary')).layoutWeight(1)
      Text(adminOnly ? $r('app.string.chat_group_admin_only') : $r('app.string.chat_everyone')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary'))
      SymbolGlyph($r('sys.symbol.chevron_down')).fontSize(16).fontColor([$r('app.color.text_secondary')])
    }.width('100%').constraintSize({ minHeight: 60 }).padding(16).enabled(this.group.isAdmin && !this.busy).bindMenu(this.PermissionMenu(key))
  }
  @Builder
  private Permissions(): void {
    Column({ space: 16 }) {
      Text($r('app.string.chat_group_admins')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_secondary')).width('100%')
      Column() {
        ForEach(this.group.members.filter((member: XChatGroupMember): boolean => member.admin), (member: XChatGroupMember) => { this.Member(member) }, (member: XChatGroupMember): string => member.id)
        if (this.group.isAdmin) { Column() { this.RowContent($r('sys.symbol.plus'), $r('app.string.chat_group_select_admin')) }.onClick((): void => this.open('admins')) }
      }.width('100%').borderRadius(16).backgroundColor(secondaryButtonSurfaceColor(this.displayMode, this.darkSurface))
      Row() {
        Text($r('app.string.chat_group_all_send')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_primary')).layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: !this.group.permissions.sendMessage }).selectedColor(this.accentColor).enabled(this.group.isAdmin && !this.busy)
          .onChange((value: boolean): void => { if (value === this.group.permissions.sendMessage) { this.run(async (): Promise<void> => { await xChatGroupService.setPermission(this.context(), this.group, 'sendMessage', !value); }); } })
      }.width('100%').padding(16).borderRadius(16).backgroundColor(secondaryButtonSurfaceColor(this.displayMode, this.darkSurface))
      this.Hint($r('app.string.chat_group_all_send_hint'))
      Column() {
        this.PermissionRow($r('app.string.chat_group_add_members'), 'addMember', this.group.permissions.addMember)
        Divider().color($r('app.color.divider'))
        this.PermissionRow($r('app.string.chat_group_edit_info'), 'editGroupInfo', this.group.permissions.editGroupInfo)
        Divider().color($r('app.color.divider'))
        this.PermissionRow($r('app.string.chat_group_start_call'), 'startCall', this.group.permissions.startCall)
        Divider().color($r('app.color.divider'))
        this.PermissionRow($r('app.string.chat_disappearing'), 'editMessageTtl', this.group.permissions.editMessageTtl)
        Divider().color($r('app.color.divider'))
        this.PermissionRow($r('app.string.chat_block_capture'), 'blockScreenCapture', this.group.permissions.blockScreenCapture)
      }.width('100%').borderRadius(16).backgroundColor(secondaryButtonSurfaceColor(this.displayMode, this.darkSurface))
    }.width('100%').padding(16)
  }
  @Builder
  private Invite(): void {
    Column({ space: 16 }) {
      Row() {
        Text($r('app.string.chat_group_invite')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_primary')).layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.group.inviteEnabled }).selectedColor(this.accentColor).enabled(this.group.isAdmin && !this.busy)
          .onChange((value: boolean): void => { if (value !== this.group.inviteEnabled) { this.run(async (): Promise<void> => { await xChatGroupService.setInvite(this.context(), this.group, value); }); } })
      }.width('100%').padding(16).borderRadius(16).backgroundColor(secondaryButtonSurfaceColor(this.displayMode, this.darkSurface))
      this.Hint($r('app.string.chat_group_invite_hint'))
      if (this.group.inviteEnabled && this.group.inviteUrl.length > 0) {
        Text(this.group.inviteUrl).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor(this.accentColor).copyOption(CopyOptions.LocalDevice).padding(16)
      }
      Button($r('app.string.chat_group_copy_link')).width('100%').height(48).backgroundColor(this.accentColor).fontColor($r('app.color.text_on_accent'))
        .enabled(this.group.inviteEnabled && this.group.inviteUrl.length > 0 && !this.busy).onClick((): void => { this.copyLink(); })
      this.Hint($r('app.string.chat_group_invite_privacy'))
    }.width('100%').padding(16)
  }
  @Builder
  private AddMembers(): void {
    Column() {
      Search({ value: this.query, placeholder: this.text($r('app.string.chat_search')) }).textFont({ family: this.appFontFamily })
        .height(48).borderRadius(24).backgroundColor(fieldSurfaceColor(this.displayMode, this.darkSurface)).onChange((value: string): void => this.changeQuery(value)).margin({ bottom: 12 })
      ForEach(this.people, (person: ChatPerson) => {
        Row({ space: 12 }) {
          ProxyAvatar({ url: person.avatarUrl, avatarSize: 44, radius: 22, fallbackText: person.name.substring(0, 1), verifiedType: person.verifiedType, avatarShape: person.avatarShape })
          Column({ space: 4 }) {
            Text(person.name).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_primary')).maxLines(1)
            Text('@' + person.username).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary')).maxLines(1)
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          Toggle({ type: ToggleType.Checkbox, isOn: this.selected.indexOf(person.id) >= 0 }).selectedColor(this.accentColor).hitTestBehavior(HitTestMode.None)
        }.width('100%').padding({ top: 12, bottom: 12 }).enabled(!this.busy).onClick((): void => {
          this.selected = this.selected.indexOf(person.id) >= 0 ? this.selected.filter((id: string): boolean => id !== person.id) : this.selected.concat([person.id]);
        })
      }, (person: ChatPerson): string => person.id)
      if (this.people.length === 0) { Text($r('app.string.chat_no_results')).fontFamily(this.appFontFamily).fontColor($r('app.color.text_secondary')).padding(24) }
    }.width('100%').padding(16)
  }
  @Builder
  private TtlChoice(label: Resource, ttl: number): void {
    Row() {
      Text(label).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_primary')).layoutWeight(1)
      if (this.group.ttlMsec === ttl) { SymbolGlyph($r('sys.symbol.checkmark')).fontSize(20).fontColor([this.accentColor]) }
    }.width('100%').height(60).padding(16).enabled(this.allowed('editMessageTtl')).onClick((): void => {
      this.run(async (): Promise<void> => { await xChatGroupService.setTtl(this.context(), this.group, ttl); });
    })
  }
  build(): void {
    HdsNavDestination() {
      Scroll(this.scroller) {
        Column() {
          if (this.loading || this.busy) { LoadingProgress().width(24).height(24).color(this.accentColor).margin(12) }
          if (this.error.length > 0) { Text(this.error).fontFamily(this.appFontFamily).fontColor($r('app.color.danger')).fontSize($r('sys.float.Body_M')).padding(16).onClick((): void => { this.load(); }) }
          if (this.section === 'edit') { this.Edit() }
          else if (this.section === 'invite') { this.Invite() }
          else if (this.section === 'permissions') { this.Permissions() }
          else if (this.section === 'add') { this.AddMembers() }
          else if (this.section === 'admins') {
            Column() { ForEach(this.group.members, (member: XChatGroupMember) => { this.Member(member) }, (member: XChatGroupMember): string => member.id) }.width('100%').padding(16)
          } else if (this.section === 'nickname') {
            Column({ space: 16 }) {
              this.Hint($r('app.string.chat_group_nickname_local'))
              TextInput({ text: this.nickname, placeholder: $r('app.string.chat_group_member_nickname') }).fontFamily(this.appFontFamily).maxLength(50)
                .keyboardAppearance(KeyboardAppearance.IMMERSIVE).fontSize($r('sys.float.Body_L')).height(52).borderRadius(24)
                .backgroundColor(fieldSurfaceColor(this.displayMode, this.darkSurface)).onChange((value: string): void => { this.nickname = value; })
            }.width('100%').padding(24).enabled(!this.busy)
          } else if (this.section === 'ttl') {
            Column() {
              this.TtlChoice($r('app.string.chat_off'), 0)
              this.TtlChoice($r('app.string.chat_24_hours'), 86400000)
              this.TtlChoice($r('app.string.chat_7_days'), 604800000)
              this.Hint($r('app.string.chat_group_ttl_hint'))
            }.width('100%').padding(16)
          } else if (this.section === 'capture') {
            Column() {
              Row() {
                Text($r('app.string.chat_block_capture')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_primary')).layoutWeight(1)
                Toggle({ type: ToggleType.Switch, isOn: this.group.screenCaptureBlockingEnabled }).selectedColor(this.accentColor).enabled(this.allowed('blockScreenCapture'))
                  .onChange((value: boolean): void => { if (value !== this.group.screenCaptureBlockingEnabled) { this.run(async (): Promise<void> => { await xChatGroupService.setScreenCapture(this.context(), this.group, value); }); } })
              }.width('100%').padding(16).borderRadius(16).backgroundColor(secondaryButtonSurfaceColor(this.displayMode, this.darkSurface))
              this.Hint($r('app.string.chat_group_capture_hint'))
            }.width('100%').padding(16)
          } else { this.Information() }
        }.width('100%').padding({ top: this.statusBarHeight + 64, bottom: this.bottomInset + 24 })
      }.width('100%').height('100%').scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true }).align(Alignment.Top)
    }.titleMode(HdsNavDestinationTitleMode.MINI).hideBackButton(false).bindToScrollable([this.scroller])
      .titleBar({ avoidLayoutSafeArea: true, content: { title: { mainTitle: this.title() }, menu: { value: this.menu() } },
        style: destinationTitleBarStyle(ScrollEffectType.GRADIENT_BLUR, this.displayMode, this.darkSurface, this.titleBarStyleMode) })
      .backgroundColor(pageSurfaceColor(this.displayMode, this.darkSurface)).systemMaterial(chatPageMaterial())
      .onShown((): void => { if (this.section.length === 0 || this.section === 'permissions') { this.load(); } })
      .onBackPressed((): boolean => { ResponsiveLayout.closeContentDestination(this.pageStack); return true; })
  }
}
