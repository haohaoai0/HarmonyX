import { pageTextColor } from '../utils/ThemeColors';
import { appPageBackground } from '../components/PageBackgroundLayer';
import { pageCanvasColor, pageReadingSurfaceColor } from '../utils/ThemeColors';
import { STORAGE_KEY_PAGE_TRANSITION_MODE, DEFAULT_PAGE_TRANSITION_MODE } from '../services/PageTransitionSettingsStore';
import { pageSystemTransition, PageTransitionMotion } from '../utils/PageTransition';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { common } from '@kit.AbilityKit';
import promptAction from '@ohos.promptAction';
import { HdsNavDestination, HdsNavDestinationTitleMode, HdsNavigationMenuItemOptions, TextStyleMode,
  ScrollEffectType, BottomBuilderShowType } from '@kit.UIDesignKit';
import { ProxyAvatar } from '../components/ProxyAvatar';
import { ChatPerson, xChatActions } from '../services/XChatActions';
import { xChatService } from '../services/XChatService';
import { xPrivateClient } from '../services/XPrivateClient';
import { xPrivateStore } from '../services/XPrivateStore';
import { DmConversationRouteParam } from './DmConversation';
import { pageSurfaceColor, fieldSurfaceColor } from '../utils/ThemeColors';
import { destinationTitleBarStyle } from '../utils/DestinationTitleBar';
import { chatControlMaterial, chatPageMaterial } from '../utils/ChatMaterial';
import { SystemMaterialUtil } from '../utils/SystemMaterial';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';
import { ExternalSharePayload } from '../services/ExternalShareStore';
import { verificationBadgeColor } from '../utils/UserIdentity';
import { materialModifier } from '../utils/SystemMaterial';

export interface DmComposeRouteParam { sharedPayload?: ExternalSharePayload; }

@Builder
export function DmComposeBuilder(): void { DmComposePage(); }

@Component
struct DmComposePage {
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
  @State private query: string = '';
  @State private people: ChatPerson[] = [];
  @State private loading: boolean = true;
  @State private error: string = '';
  @State private group: boolean = false;
  @State private selected: ChatPerson[] = [];
  @State private groupTitle: string = '';
  @State private creating: boolean = false;
  private generation: number = 0;
  private timer: number = -1;
  private active: boolean = true;
  private account: string = '';
  private sharedPayload: ExternalSharePayload | undefined = undefined;
  private scroller: Scroller = new Scroller();
  private context(): common.UIAbilityContext { return getContext(this) as common.UIAbilityContext; }
  private text(resource: Resource): string { return this.context().resourceManager.getStringSync(resource); }
  aboutToAppear(): void {
    this.active = true;
    xPrivateClient.load(this.context());
    this.account = xPrivateStore.load(this.context()).cacheIdentity();
    this.search();
  }
  aboutToDisappear(): void { this.active = false; this.generation++; if (this.timer >= 0) { clearTimeout(this.timer); } }
  private valid(): boolean { return this.active && this.account === xPrivateStore.load(this.context()).cacheIdentity(); }
  private changeQuery(query: string): void {
    this.query = query;
    this.generation++;
    if (this.timer >= 0) { clearTimeout(this.timer); }
    this.timer = setTimeout((): void => { this.search(); }, 300);
  }
  private async search(): Promise<void> {
    const generation: number = ++this.generation;
    this.loading = true; this.error = '';
    try {
      const people: ChatPerson[] = await xChatActions.people(this.query, this.group);
      if (this.valid() && generation === this.generation) { this.people = people; }
    } catch (error) {
      if (this.valid() && generation === this.generation) { this.error = this.text($r('app.string.chat_action_failed')); }
    } finally { if (this.valid() && generation === this.generation) { this.loading = false; } }
  }
  private select(person: ChatPerson): void {
    if (!this.valid()) { return; }
    if (this.group) {
      const has: boolean = this.selected.some((item: ChatPerson): boolean => item.id === person.id);
      if (!has && !person.canGroup) { promptAction.showToast({ message: this.text($r('app.string.chat_not_allowed')) }); return; }
      this.selected = has ? this.selected.filter((item: ChatPerson): boolean => item.id !== person.id) : this.selected.concat([person]);
    } else {
      const ids: string[] = [xPrivateClient.viewerId(), person.id];
      ids.sort((a: string, b: string): number => a.length !== b.length ? a.length - b.length : (a > b ? 1 : a < b ? -1 : 0));
      const param: DmConversationRouteParam = { conversationId: ids.join('-'), title: person.name,
        username: person.username, avatarUrl: person.avatarUrl, verifiedType: person.verifiedType, avatarShape: person.avatarShape,
        group: false, participantIds: ids, latestSequenceId: '', sharedPayload: this.sharedPayload };
      this.pageStack.replacePath({ name: 'DmConversation', param: param });
    }
  }
  private async createGroupChat(): Promise<void> {
    if (this.creating || this.selected.length < 2) { return; }
    if (!xChatService.isUnlocked()) { promptAction.showToast({ message: this.text($r('app.string.dm_unlock_hint')) }); return; }
    this.creating = true;
    try {
      const ids: string[] = this.selected.map((person: ChatPerson): string => person.id);
      const title: string = this.groupTitle.trim().length > 0 ? this.groupTitle.trim() :
        this.selected.map((person: ChatPerson): string => person.name).join('、');
      const conversation: string = await xChatService.createGroup(this.context(), ids, title);
      if (!this.valid()) { return; }
      const param: DmConversationRouteParam = { conversationId: conversation, title: title,
        username: '', avatarUrl: '', group: true, participantIds: [xPrivateClient.viewerId()].concat(ids), latestSequenceId: '', sharedPayload: this.sharedPayload };
      this.pageStack.replacePath({ name: 'DmConversation', param: param });
    } catch (error) { if (this.valid()) { this.error = this.text($r('app.string.chat_action_failed')); } }
    finally { if (this.valid()) { this.creating = false; } }
  }
  private titleMenu(): HdsNavigationMenuItemOptions[] {
    if (!this.group) { return []; }
    return [{ content: { label: $r('app.string.chat_group_create'), type: TextStyleMode.NORMAL,
      isEnabled: this.selected.length >= 2 && !this.creating,
      action: (): void => { this.createGroupChat(); } } }];
  }
  @Builder
  private SearchField(): void {
    Search({ value: this.query, placeholder: $r('app.string.chat_search') })
      .keyboardAppearance(KeyboardAppearance.IMMERSIVE)
      .height($r('app.float.chat_search_height')).borderRadius(24).clip(true)
      .backgroundColor(SystemMaterialUtil.isApi26OrAbove() ? Color.Transparent : fieldSurfaceColor(this.displayMode, this.darkSurface))
      .fontColor($r('app.color.text_primary')).margin({ left: 16, right: 16, top: 4 })
      .attributeModifier(materialModifier(chatControlMaterial(this.accentColor)))
      .onChange((value: string): void => this.changeQuery(value))
  }
  @Builder
  private PersonRow(person: ChatPerson): void {
    Row({ space: 12 }) {
      ProxyAvatar({verifiedType: person.verifiedType ?? '', avatarShape: person.avatarShape ?? '',  url: person.avatarUrl, avatarSize: 48, radius: 24, fallbackText: person.name.substring(0, 1) })
      Column({ space: 4 }) {
        Row({ space: 4 }) {
          Text(person.name).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontWeight(FontWeight.Bold).fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent))
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
          if (person.verified) { SymbolGlyph($r('sys.symbol.checkmark_circle_fill')).fontSize(14).fontColor([verificationBadgeColor(person.verifiedType, this.accentColor)]) }
        }.width('100%')
        Text('@' + person.username).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)).maxLines(1)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      if (this.group) {
        Toggle({ type: ToggleType.Checkbox, isOn: this.selected.some((item: ChatPerson): boolean => item.id === person.id) })
          .selectedColor(this.accentColor).hitTestBehavior(HitTestMode.None)
      }
    }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 }).onClick((): void => this.select(person))
  }
  build(): void {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        appPageBackground()
        List({ scroller: this.scroller }) {
          ListItem() { Column().width('100%').height(this.statusBarHeight + 120) }
          if (this.group) {
            ListItem() {
              TextInput({ text: this.groupTitle, placeholder: $r('app.string.chat_group_title') }).fontFamily(this.appFontFamily)
                .keyboardAppearance(KeyboardAppearance.IMMERSIVE).maxLength(50)
                .fontSize($r('sys.float.Body_L')).backgroundColor(fieldSurfaceColor(this.displayMode, this.darkSurface))
                .borderRadius(24).margin({ left: 16, right: 16, bottom: 8 }).onChange((value: string): void => { this.groupTitle = value; })
            }
          }
          if (!this.group) {
            ListItem() {
              Row({ space: 12 }) {
                Button({ type: ButtonType.Circle }) {
                  SymbolGlyph($r('sys.symbol.person_2')).fontSize(24).fontColor([$r('app.color.text_primary')])
                }.width(48).height(48).backgroundColor(fieldSurfaceColor(this.displayMode, this.darkSurface))
                Text($r('app.string.chat_create_group')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_primary')).layoutWeight(1)
                SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(18).fontColor([$r('app.color.text_secondary')])
              }.width('100%').padding(16).onClick((): void => { this.group = true; this.search(); })
            }
          }
          ForEach(this.people, (person: ChatPerson) => { ListItem() { this.PersonRow(person) } }, (person: ChatPerson): string => person.id)
          if (this.loading || this.creating) { ListItem() { LoadingProgress().width(24).height(24).color(this.accentColor).margin(24) } }
          if (this.error.length > 0) { ListItem() { Text(this.error).fontFamily(this.appFontFamily).fontColor($r('app.color.danger')).padding(16).onClick((): void => { this.search(); }) } }
          if (this.people.length === 0 && !this.loading && this.error.length === 0) {
            ListItem() { Text($r('app.string.chat_no_results')).fontFamily(this.appFontFamily).fontColor($r('app.color.text_secondary')).padding(24) }
          }
          ListItem() { Column().height(this.bottomInset + 24) }
        }.height('100%').width('100%').scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    
      }.width('100%').height('100%')
    }
    .scale({ x: this.pageMotion.scale, y: this.pageMotion.scale })
    .opacity(this.pageMotion.opacity)
    .systemTransition(pageSystemTransition(this.pageTransitionMode)).onReady((context: NavDestinationContext): void => {
      this.pageMotion.attach(context);
      const param: DmComposeRouteParam | undefined = context.pathInfo?.param as DmComposeRouteParam | undefined;
      this.sharedPayload = param?.sharedPayload;
    }).titleMode(HdsNavDestinationTitleMode.MINI).hideBackButton(false).bindToScrollable([this.scroller])
      .titleBar({ avoidLayoutSafeArea: true,
        content: { title: { mainTitle: this.group ? $r('app.string.chat_create_group') : $r('app.string.chat_new') },
          bottomBuilder: { builder: (): void => this.SearchField(), height: 56, showType: BottomBuilderShowType.DIRECTLY_SHOW },
          menu: { value: this.titleMenu() } },
        style: destinationTitleBarStyle(ScrollEffectType.GRADIENT_BLUR, this.displayMode, this.darkSurface, this.titleBarStyleMode)
      })
      .backgroundColor(pageCanvasColor(this.displayMode, this.darkSurface, this.pageBackgroundValue)).attributeModifier(materialModifier(chatPageMaterial()))
      .onBackPressed((): boolean => {
        if (this.group) { this.group = false; this.selected = []; this.search(); }
        else { ResponsiveLayout.closeContentDestination(this.pageStack); }
        return true;
      })
  }
}
