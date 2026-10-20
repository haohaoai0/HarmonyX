import { pageTextColor } from '../utils/ThemeColors';
import { appPageBackground } from '../components/PageBackgroundLayer';
import { pageCanvasColor, pageReadingSurfaceColor } from '../utils/ThemeColors';
import { STORAGE_KEY_PAGE_TRANSITION_MODE, DEFAULT_PAGE_TRANSITION_MODE } from '../services/PageTransitionSettingsStore';
import { pageSystemTransition, PageTransitionMotion } from '../utils/PageTransition';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { userAvatarRadius, verificationBadgeColor, userVerifiedType, userAvatarShape } from '../utils/UserIdentity';
import { common } from '@kit.AbilityKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { uiMaterial } from '@kit.ArkUI';
import { HdsNavDestination, HdsNavDestinationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import promptAction from '@ohos.promptAction';
import { SpaceParticipant, SpaceRoom, SpaceRouteParam, SpaceInfoRouteParam } from '../models/Space';
import { ProxyAvatar } from '../components/ProxyAvatar';
import { SpaceRoomCard } from '../components/SpaceRoomCard';
import { SpaceListeningBar } from '../components/SpaceListeningBar';
import { FloatingComposeButton } from '../components/FloatingComposeButton';
import { xPrivateClient } from '../services/XPrivateClient';
import { SpaceDirectory, xSpaceService } from '../services/XSpaceService';
import { SPACE_PLAYBACK_REVISION, spacePlayback } from '../services/SpacePlayback';
import { spacePreferencesStore } from '../services/SpacePreferencesStore';
import { addSpaceToCalendar } from '../services/SpaceCalendar';
import { spaceRole, spaceStatus, spaceTime, spaceUserParam } from '../utils/SpacePresentation';
import { destinationTitleBarStyle } from '../utils/DestinationTitleBar';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';
import { pageSurfaceColor, cardSurfaceColor } from '../utils/ThemeColors';
import { formatCount } from '../models/Tweet';
import { shareSpace } from '../utils/SharePost';
import { materialModifier } from '../utils/SystemMaterial';

@Builder
export function SpacesBuilder(): void { Spaces(); }
@Builder
export function SpaceRoomBuilder(): void { SpaceRoomPage(); }

@Component
struct Spaces {
  @StorageProp('harmonyx.page_background') private pageBackgroundValue: string = '';
  @State private pageMotion: PageTransitionMotion = new PageTransitionMotion();
  @StorageProp(STORAGE_KEY_PAGE_TRANSITION_MODE) private pageTransitionMode: string = DEFAULT_PAGE_TRANSITION_MODE;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp('harmonyx.status_bar_height') statusBarHeight: number = 0;
  @StorageProp('harmonyx.navigation_indicator_height') navigationIndicatorHeight: number = 0;
  @StorageProp('harmonyx.display_mode') themeDisplayMode: string = '';
  @StorageProp('harmonyx.dark_surface') themeDarkSurface: string = '';
  @StorageLink('harmonyx.title_bar_style_mode') titleBarStyleMode: number = 0;
  @StorageProp(SPACE_PLAYBACK_REVISION) playbackRevision: number = 0;
  @State private rooms: SpaceRoom[] = [];
  @State private query: string = '';
  @State private submittedQuery: string = '';
  @State private loading: boolean = true;
  @State private refreshing: boolean = false;
  @State private failed: boolean = false;
  @State private signedIn: boolean = true;
  @State private calendarIds: string[] = [];
  @State private calendarBusy: string = '';
  @State private personalized: boolean = false;
  private scroller: Scroller = new Scroller();
  private generation: number = 0;
  private alive: boolean = true;

  aboutToAppear(): void {
    this.alive = true;
    xPrivateClient.load(getContext(this) as common.UIAbilityContext);
    this.load();
  }
  aboutToDisappear(): void { this.alive = false; ++this.generation; }
  private text(resource: Resource): string {
    return (getContext(this) as common.UIAbilityContext).resourceManager.getStringSync(resource);
  }
  private async load(): Promise<void> {
    const generation: number = ++this.generation;
    this.loading = true; this.failed = false;
    this.signedIn = xPrivateClient.isSignedIn();
    if (!this.signedIn) { this.rooms = []; this.loading = false; this.refreshing = false; return; }
    try {
      const page: SpaceDirectory = await xSpaceService.directory(this.submittedQuery, false);
      const hidden: string[] = spacePreferencesStore.hidden(getContext(this) as common.UIAbilityContext);
      if (this.alive && generation === this.generation) {
        this.rooms = page.rooms.filter((room: SpaceRoom): boolean => hidden.indexOf(room.id) < 0);
        this.personalized = page.personalized;
      }
    } catch (error) {
      if (this.alive && generation === this.generation) { this.failed = true; }
    } finally {
      if (this.alive && generation === this.generation) { this.loading = false; this.refreshing = false; }
    }
  }
  private search(value: string): void {
    this.query = value; this.submittedQuery = value.trim(); this.rooms = []; this.load();
  }
  private open(room: SpaceRoom): void {
    const param: SpaceRouteParam = { spaceId: room.id, room: room };
    this.pageStack.pushPath({ name: 'SpaceRoom', param: param });
  }
  private live(): SpaceRoom[] { return this.rooms.filter((room: SpaceRoom): boolean => room.isLive()); }
  private scheduled(): SpaceRoom[] {
    return this.rooms.filter((room: SpaceRoom): boolean => room.isScheduled())
      .sort((left: SpaceRoom, right: SpaceRoom): number => left.scheduledStart - right.scheduledStart);
  }
  private replays(): SpaceRoom[] {
    return this.rooms.filter((room: SpaceRoom): boolean => !room.isLive() && !room.isScheduled() && room.replayAvailable);
  }
  private hasActiveRoom(): boolean { return this.playbackRevision >= 0 && spacePlayback.room !== null; }
  // The default list is built from the accounts this reader follows; the global
  // list only appears when that graph has nothing live, and the heading says so
  // instead of implying a personal recommendation.
  private liveHeading(): Resource {
    if (this.submittedQuery.length > 0) { return $r('app.string.spaces_search_results'); }
    return this.personalized ? $r('app.string.spaces_following_now') : $r('app.string.spaces_discover_now');
  }
  private liveSubtitle(): Resource {
    if (this.submittedQuery.length > 0) { return $r('app.string.spaces_happening_body'); }
    return this.personalized ? $r('app.string.spaces_following_body') : $r('app.string.spaces_discover_body');
  }
  private hide(room: SpaceRoom): void {
    if (spacePreferencesStore.hide(getContext(this) as common.UIAbilityContext, room.id)) {
      this.rooms = this.rooms.filter((value: SpaceRoom): boolean => value.id !== room.id);
    } else { promptAction.showToast({ message: this.text($r('app.string.spaces_save_failed')) }); }
  }
  private async calendar(room: SpaceRoom): Promise<void> {
    if (this.calendarBusy.length > 0 || this.calendarIds.indexOf(room.id) >= 0) { return; }
    this.calendarBusy = room.id;
    try {
      if (await addSpaceToCalendar(getContext(this) as common.UIAbilityContext, room)) {
        this.calendarIds = [...this.calendarIds, room.id];
        promptAction.showToast({ message: this.text($r('app.string.spaces_calendar_saved')) });
      }
    } catch (error) { promptAction.showToast({ message: this.text($r('app.string.spaces_calendar_failed')) }); }
    finally { this.calendarBusy = ''; }
  }
  @Builder
  private Heading(title: Resource, subtitle: Resource): void {
    Column({ space: 5 }) {
      Text(title).fontFamily(this.appFontFamily).fontSize($r('app.float.space_section_title_size')).fontWeight(FontWeight.Bold)
        .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent)).width('100%')
      Text(subtitle).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)).width('100%')
    }.width('100%').alignItems(HorizontalAlign.Start).padding({ top: 16, bottom: 8 })
  }
  @Builder
  private Card(room: SpaceRoom): void {
    SpaceRoomCard({ room: room, onOpen: (value: SpaceRoom): void => this.open(value),
      onHide: (value: SpaceRoom): void => this.hide(value), onHost: (value: SpaceRoom): void => {
        if (value.host.username.length > 0 || value.host.id.length > 0) {
          this.pageStack.pushPath({ name: 'UserDetail', param: spaceUserParam(value.host) });
        }
      } })
  }
  @Builder
  private ScheduledRow(room: SpaceRoom): void {
    Row({ space: 12 }) {
      Stack() {
        ProxyAvatar({verifiedType: room.host.verifiedType ?? '', avatarShape: room.host.avatarShape ?? '',  url: room.host.avatarUrl, avatarSize: 54, radius: 16,
          fallbackText: room.host.name.substring(0, 1), fallbackColor: $r('app.color.space_card_footer') })
      }.width(76).height(76).borderRadius(22).backgroundColor($r('app.color.space_card_fill'))
        .onClick((): void => this.open(room))
      Column({ space: 5 }) {
        Text(room.host.name || room.host.username).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontWeight(FontWeight.Medium)
          .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(room.title || $r('app.string.spaces_untitled')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontWeight(FontWeight.Bold)
          .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent)).maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(spaceTime(getContext(this) as common.UIAbilityContext, room.scheduledStart)).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M')).fontWeight(FontWeight.Bold).fontColor($r('app.color.space_accent'))
      }.layoutWeight(1).alignItems(HorizontalAlign.Start).onClick((): void => this.open(room))
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph(this.calendarIds.indexOf(room.id) >= 0 ? $r('sys.symbol.checkmark') : $r('sys.symbol.calendar_badge_plus'))
          .fontSize(22).fontColor([$r('app.color.space_card_text')])
      }.width(44).height(44).backgroundColor($r('app.color.space_calendar_button'))
        .enabled(room.scheduledStart > Date.now() && this.calendarBusy.length === 0 && this.calendarIds.indexOf(room.id) < 0)
        .accessibilityText($r('app.string.spaces_add_calendar')).onClick((): void => { this.calendar(room); })
    }.width('100%').alignItems(VerticalAlign.Top).padding({ top: 10, bottom: 14 })
  }
  @Builder
  private DirectoryBody(): void {
    ListItem() {
      Search({ value: this.query, placeholder: this.text($r('app.string.spaces_search_placeholder')) })
        .keyboardAppearance(KeyboardAppearance.IMMERSIVE).height($r('app.float.space_search_height'))
        .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, $r('app.color.space_search_surface'))).backgroundColor($r('app.color.space_search_surface'))
        .searchButton(this.text($r('app.string.list_search_action')))
        .onChange((value: string): void => {
          this.query = value;
          if (value.trim().length === 0 && this.submittedQuery.length > 0) { this.search(''); }
        }).onSubmit((value: string): void => this.search(value))
    }
    if (this.loading && this.rooms.length === 0) {
      ListItem() { LoadingProgress().width(32).height(32).color($r('app.color.space_accent')).margin({ top: 40 }) }
    } else if (!this.signedIn || this.rooms.length === 0) {
      ListItem() {
        Column({ space: 16 }) {
          SymbolGlyph($r('sys.symbol.waveform')).fontSize($r('app.float.space_empty_symbol_size'))
            .fontColor([$r('app.color.space_accent')])
          Text(!this.signedIn ? $r('app.string.user_list_sign_in') : this.failed ?
            $r('app.string.spaces_load_failed') : $r('app.string.spaces_empty_title')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Title_S')).fontWeight(FontWeight.Bold).fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent))
          Text(this.failed ? $r('app.string.spaces_load_failed_body') : $r('app.string.spaces_empty_body')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_L')).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
          if (this.signedIn) {
            Button($r('app.string.common_retry')).backgroundColor($r('app.color.space_button'))
              .fontColor($r('app.color.text_on_accent')).onClick((): void => { this.load(); })
          }
        }.width('100%').padding({ top: 40, bottom: 24 }).alignItems(HorizontalAlign.Start)
      }
    } else {
      if (this.failed) {
        ListItem() { Text($r('app.string.spaces_refresh_failed')).fontFamily(this.appFontFamily).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)) }
      }
      if (this.live().length > 0) {
        ListItem() { this.Heading(this.liveHeading(), this.liveSubtitle()) }
        ForEach(this.live(), (room: SpaceRoom): void => { ListItem() { this.Card(room) } }, (room: SpaceRoom): string => room.id)
      }
      if (this.scheduled().length > 0) {
        ListItem() { this.Heading($r('app.string.spaces_upcoming'), $r('app.string.spaces_upcoming_body')) }
        ForEach(this.scheduled(), (room: SpaceRoom): void => { ListItem() { this.ScheduledRow(room) } }, (room: SpaceRoom): string => room.id)
      }
      if (this.replays().length > 0) {
        ListItem() { this.Heading($r('app.string.spaces_replays'), $r('app.string.spaces_replays_body')) }
        ForEach(this.replays(), (room: SpaceRoom): void => { ListItem() { this.Card(room) } }, (room: SpaceRoom): string => room.id)
      }
    }
  }
  build(): void {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        appPageBackground()
      Stack({ alignContent: Alignment.BottomEnd }) {
        Column() {
          Refresh({ refreshing: $$this.refreshing }) {
            List({ space: 14, scroller: this.scroller }) { this.DirectoryBody() }
              .width('100%').constraintSize({ maxWidth: $r('app.float.space_content_width') })
              .height('100%').padding({ left: 16, right: 16 }).scrollBar(BarState.Off)
              .contentEndOffset(this.navigationIndicatorHeight + 88)
          }.width('100%').layoutWeight(1).onRefreshing((): void => { this.load(); })
          if (this.playbackRevision >= 0 && spacePlayback.room !== null) {
            SpaceListeningBar({ onOpen: (room: SpaceRoom): void => this.open(room) })
              .margin({ left: 12, right: 12, bottom: this.navigationIndicatorHeight + 8 })
          }
        }.width('100%').height('100%').padding({ top: this.statusBarHeight + 60 })
        FloatingComposeButton({ bottomInset: this.navigationIndicatorHeight,
          bottomBarHeight: this.hasActiveRoom() ? 68 : 0, gripSubscriberKey: 'spaces-compose',
          composeSymbol: $r('sys.symbol.music_note_mic'), composeColor: $r('app.color.space_button'),
          accessibilityLabel: this.text($r('app.string.spaces_create_draft')),
          onCompose: (): void => { this.pageStack.pushPath({ name: 'SpaceDraft' }); } })
      }.width('100%').height('100%')
    
      }.width('100%').height('100%')
    }
    .scale({ x: this.pageMotion.scale, y: this.pageMotion.scale })
    .opacity(this.pageMotion.opacity)
    .onReady((context: NavDestinationContext): void => { this.pageMotion.attach(context); })
    .systemTransition(pageSystemTransition(this.pageTransitionMode)).titleMode(HdsNavDestinationTitleMode.MINI).hideBackButton(false)
      .onBackPressed((): boolean => { ResponsiveLayout.closeContentDestination(this.pageStack); return true; })
      .bindToScrollable([this.scroller])
      .titleBar({ avoidLayoutSafeArea: true, content: { title: { mainTitle: $r('app.string.side_spaces') } },
        style: destinationTitleBarStyle(ScrollEffectType.IMMERSIVE_GRADIENT_BLUR,
          this.themeDisplayMode, this.themeDarkSurface, this.titleBarStyleMode) })
      .backgroundColor(pageCanvasColor(this.themeDisplayMode, this.themeDarkSurface, this.pageBackgroundValue))
      .attributeModifier(materialModifier(deviceInfo.apiAvailable('26.0.0') ? new uiMaterial.ImmersiveMaterial({
        style: uiMaterial.ImmersiveStyle.REGULAR, applyShadow: true, colorInvert: true }) : undefined))
  }
}

@Component
struct SpaceRoomPage {
  @StorageProp('harmonyx.page_background') private pageBackgroundValue: string = '';
  @State private pageMotion: PageTransitionMotion = new PageTransitionMotion();
  @StorageProp(STORAGE_KEY_PAGE_TRANSITION_MODE) private pageTransitionMode: string = DEFAULT_PAGE_TRANSITION_MODE;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp('harmonyx.status_bar_height') statusBarHeight: number = 0;
  @StorageProp('harmonyx.navigation_indicator_height') navigationIndicatorHeight: number = 0;
  @StorageProp('harmonyx.display_mode') themeDisplayMode: string = '';
  @StorageProp('harmonyx.dark_surface') themeDarkSurface: string = '';
  @StorageLink('harmonyx.title_bar_style_mode') titleBarStyleMode: number = 0;
  @StorageProp(SPACE_PLAYBACK_REVISION) playbackRevision: number = 0;
  @State private room: SpaceRoom | null = null;
  @State private loading: boolean = true;
  @State private failed: boolean = false;
  private spaceId: string = '';
  private scroller: Scroller = new Scroller();
  private alive: boolean = true;
  private generation: number = 0;
  private poll: number = -1;
  private visible: boolean = true;

  aboutToAppear(): void {
    this.alive = true;
    xPrivateClient.load(getContext(this) as common.UIAbilityContext);
    const params: SpaceRouteParam[] = this.pageStack.getParamByName('SpaceRoom') as SpaceRouteParam[];
    if (params?.length > 0) {
      const param: SpaceRouteParam = params[params.length - 1]; this.spaceId = param.spaceId; this.room = param.room ?? null;
    }
    this.load();
  }
  aboutToDisappear(): void { this.alive = false; ++this.generation; this.clearPoll(); }
  private clearPoll(): void { if (this.poll >= 0) { clearTimeout(this.poll); this.poll = -1; } }
  private async load(): Promise<void> {
    const generation: number = ++this.generation;
    this.clearPoll();
    try {
      const room: SpaceRoom | null = this.spaceId.length > 0 ? await xSpaceService.detail(this.spaceId) : null;
      if (!this.alive || generation !== this.generation) { return; }
      this.failed = room === null;
      if (room !== null) {
        this.room = room;
        if (!room.canListen() && spacePlayback.room?.id === room.id) { spacePlayback.stop(); }
      }
    } catch (error) { if (this.alive && generation === this.generation) { this.failed = true; } }
    finally {
      if (this.alive && generation === this.generation) {
        this.loading = false;
        if (this.visible && (this.room?.isLive() || this.room?.isScheduled())) {
          this.poll = setTimeout((): void => { this.load(); }, 30000);
        }
      }
    }
  }
  private text(resource: Resource): string {
    return (getContext(this) as common.UIAbilityContext).resourceManager.getStringSync(resource);
  }
  private active(): boolean { return this.playbackRevision >= 0 && spacePlayback.room?.id === this.spaceId; }
  private playbackState(): string { return this.active() ? spacePlayback.state : 'idle'; }
  private busy(): boolean { return this.playbackState() === 'loading' || this.playbackState() === 'buffering'; }
  private playing(): boolean { return this.playbackState() === 'playing' || this.playbackState() === 'buffering'; }
  private info(kind: string): void {
    const param: SpaceInfoRouteParam = { kind: kind }; this.pageStack.pushPath({ name: 'SpaceInfo', param: param });
  }
  private toggle(): void {
    if (this.playing()) { spacePlayback.pausePlayback(); return; }
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    if (!spacePreferencesStore.guideSeen(context, 'welcome') && this.room !== null) {
      const param: SpaceInfoRouteParam = { kind: 'welcome', room: this.room, listenAfter: true };
      this.pageStack.pushPath({ name: 'SpaceInfo', param: param }); return;
    }
    if (this.room !== null) { spacePlayback.listen(context, this.room); }
  }
  private members(): void {
    if (this.room !== null) {
      const param: SpaceRouteParam = { spaceId: this.spaceId, room: this.room };
      this.pageStack.pushPath({ name: 'SpaceMembers', param: param });
    }
  }
  private people(room: SpaceRoom): SpaceParticipant[] {
    return this.active() ? room.participants : room.participants.filter(
      (person: SpaceParticipant): boolean => person.role !== 'listener');
  }
  private async calendar(room: SpaceRoom): Promise<void> {
    try { await addSpaceToCalendar(getContext(this) as common.UIAbilityContext, room); }
    catch (error) { promptAction.showToast({ message: this.text($r('app.string.spaces_calendar_failed')) }); }
  }
  @Builder
  private Participant(person: SpaceParticipant): void {
    Column({ space: 5 }) {
      ProxyAvatar({verifiedType: person.verifiedType ?? '', avatarShape: person.avatarShape ?? '',  url: person.avatarUrl, avatarSize: 60, radius: 30, fallbackText: person.name.substring(0, 1),
        fallbackColor: $r('app.color.space_button') })
      Row({ space: 3 }) {
        Text(person.name || person.username).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontWeight(FontWeight.Bold)
          .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent)).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
        if (person.verified) {
          SymbolGlyph($r('sys.symbol.checkmark_circle_fill')).fontSize(12).fontColor([verificationBadgeColor(person.verifiedType, pageTextColor($r('app.color.text_accent'), this.pageBackgroundValue, Color.Transparent))])
        }
        if (person.protected) {
          SymbolGlyph($r('sys.symbol.lock_fill')).fontSize(12).fontColor([pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent)])
        }
      }.width('100%')
      Text(spaceRole(person)).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S')).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
    }.width('25%').padding({ left: 5, right: 5, top: 12, bottom: 12 }).onClick((): void => {
      this.pageStack.pushPath({ name: 'UserDetail', param: spaceUserParam(person) });
    })
  }
  @Builder
  private RoomBody(room: SpaceRoom): void {
    Column({ space: 20 }) {
      Row({ space: 8 }) {
        Row({ space: 5 }) {
          SymbolGlyph($r('sys.symbol.waveform')).fontSize(16).fontColor([$r('app.color.space_accent')])
          Text(spaceStatus(room)).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.space_accent'))
        }.padding({ left: 8, right: 8, top: 4, bottom: 4 }).borderRadius(8).backgroundColor($r('app.color.space_soft'))
        if (room.replayAvailable) {
          Button($r('app.string.spaces_recording_info')).fontSize($r('sys.float.Body_S'))
            .fontColor($r('app.color.space_recording')).backgroundColor($r('app.color.space_recording_soft'))
            .height(28).onClick((): void => this.info('recording'))
        }
        Blank()
      }.width('100%')
      Text(room.title || $r('app.string.spaces_untitled')).fontFamily(this.appFontFamily).fontSize($r('app.float.space_room_title_size'))
        .fontWeight(FontWeight.Bold).fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent)).width('100%')
      if (room.isScheduled()) {
        Text(spaceTime(getContext(this) as common.UIAbilityContext, room.scheduledStart)).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_L')).fontWeight(FontWeight.Bold).fontColor($r('app.color.space_accent'))
      }
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.people(room), (person: SpaceParticipant): void => { this.Participant(person) }, (person: SpaceParticipant): string => person.id)
      }.width('100%')
      Button($r('app.string.spaces_view_members', formatCount(room.participantCount)))
        .fontSize($r('sys.float.Body_M')).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)).backgroundColor(Color.Transparent)
        .onClick((): void => this.members())
      if (this.failed) {
        Text($r('app.string.spaces_refresh_failed')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
      }
    }.width('100%').constraintSize({ maxWidth: $r('app.float.space_content_width') })
      .padding({ left: 16, right: 16, top: 20, bottom: 24 }).alignItems(HorizontalAlign.Start)
  }
  @Builder
  private Controls(room: SpaceRoom): void {
    Column({ space: 14 }) {
      if (this.active() && this.playing()) {
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.waveform')).fontSize(18).fontColor([$r('app.color.space_card_text')])
          Text($r('app.string.spaces_listening')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.space_card_text'))
          Blank()
          Button($r('app.string.spaces_minimize')).fontSize($r('sys.float.Body_S'))
            .fontColor($r('app.color.space_card_text')).backgroundColor(Color.Transparent)
            .onClick((): void => { ResponsiveLayout.closeContentDestination(this.pageStack); })
        }.width('100%').padding({ left: 16, right: 8 }).borderRadius(12).backgroundColor($r('app.color.space_button'))
      }
      if (this.playbackState() === 'error') {
        Text($r('app.string.spaces_audio_failed')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, pageReadingSurfaceColor(cardSurfaceColor(this.themeDisplayMode, this.themeDarkSurface), this.pageBackgroundValue)))
      } else if (room.isScheduled()) {
        Text($r('app.string.spaces_not_started')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, pageReadingSurfaceColor(cardSurfaceColor(this.themeDisplayMode, this.themeDarkSurface), this.pageBackgroundValue)))
      } else {
        Text(room.canListen() ? $r('app.string.spaces_listen_only_body') : $r('app.string.spaces_no_audio')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_S')).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, pageReadingSurfaceColor(cardSurfaceColor(this.themeDisplayMode, this.themeDarkSurface), this.pageBackgroundValue))).textAlign(TextAlign.Center)
      }
      Row({ space: 12 }) {
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.person_2')).fontSize(22).fontColor([pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, $r('app.color.space_soft'))])
        }.width(48).height(48).backgroundColor($r('app.color.space_soft'))
          .accessibilityText($r('app.string.spaces_members')).onClick((): void => this.members())
        Button(room.isScheduled() ? $r('app.string.spaces_add_calendar') : this.busy() ? $r('app.string.spaces_connecting') :
          this.playing() ? $r('app.string.spaces_pause') : this.playbackState() === 'error' ? $r('app.string.spaces_retry_audio') :
          room.isLive() ? $r('app.string.spaces_listen') : $r('app.string.spaces_play_replay'))
          .layoutWeight(1).height($r('app.float.space_listen_height')).fontSize($r('sys.float.Body_L'))
          .fontWeight(FontWeight.Bold).fontColor($r('app.color.space_card_text')).backgroundColor($r('app.color.space_button'))
          .enabled(room.isScheduled() ? room.scheduledStart > Date.now() : room.canListen() && !this.busy())
          .onClick((): void => { if (room.isScheduled()) { this.calendar(room); } else { this.toggle(); } })
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.arrowshape_turn_up_right')).fontSize(22).fontColor([$r('app.color.space_accent')])
        }.width(48).height(48).backgroundColor($r('app.color.space_soft'))
          .accessibilityText($r('app.string.spaces_share')).onClick((): void => {
            shareSpace(getContext(this) as common.UIAbilityContext, room.id, room.title);
          })
      }.width('100%')
      if (this.active()) {
        Button($r('app.string.spaces_leave')).width('100%').backgroundColor(Color.Transparent)
          .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, pageReadingSurfaceColor(cardSurfaceColor(this.themeDisplayMode, this.themeDarkSurface), this.pageBackgroundValue))).onClick((): void => { spacePlayback.stop(); })
      }
    }.width('100%').constraintSize({ maxWidth: $r('app.float.space_content_width') })
      .padding({ left: 16, right: 16, top: 14, bottom: this.navigationIndicatorHeight + 16 })
      .backgroundColor(pageReadingSurfaceColor(cardSurfaceColor(this.themeDisplayMode, this.themeDarkSurface), this.pageBackgroundValue))
  }
  build(): void {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        appPageBackground()
      Column() {
        Scroll(this.scroller) {
          Column() {
            if (this.room !== null) { this.RoomBody(this.room) }
            else if (this.loading) { LoadingProgress().width(32).height(32).color($r('app.color.space_accent')).margin(40) }
            else {
              Column({ space: 16 }) {
                Text($r('app.string.spaces_room_unavailable')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Title_S'))
                  .fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
                Button($r('app.string.common_retry')).backgroundColor($r('app.color.space_button'))
                  .fontColor($r('app.color.space_card_text')).onClick((): void => { this.load(); })
              }.width('100%').padding(24)
            }
          }.width('100%')
        }.width('100%').layoutWeight(1).align(Alignment.TopStart).scrollBar(BarState.Off)
        if (this.room !== null) { this.Controls(this.room) }
      }.width('100%').height('100%').padding({ top: this.statusBarHeight + 60 })
    
      }.width('100%').height('100%')
    }
    .scale({ x: this.pageMotion.scale, y: this.pageMotion.scale })
    .opacity(this.pageMotion.opacity)
    .onReady((context: NavDestinationContext): void => { this.pageMotion.attach(context); })
    .systemTransition(pageSystemTransition(this.pageTransitionMode)).titleMode(HdsNavDestinationTitleMode.MINI).hideBackButton(false)
      .onHidden((): void => { this.visible = false; this.clearPoll(); })
      .onShown((): void => { this.visible = true; if (!this.loading) { this.load(); } })
      .onBackPressed((): boolean => { ResponsiveLayout.closeContentDestination(this.pageStack); return true; })
      .bindToScrollable([this.scroller])
      .titleBar({ avoidLayoutSafeArea: true, content: { title: { mainTitle: $r('app.string.side_spaces') },
        menu: { value: [{ content: { icon: $r('sys.symbol.info_circle'), label: $r('app.string.spaces_about'),
          action: (): void => this.info('welcome') } }], maxCount: 1 } },
        style: destinationTitleBarStyle(ScrollEffectType.IMMERSIVE_GRADIENT_BLUR,
          this.themeDisplayMode, this.themeDarkSurface, this.titleBarStyleMode) })
      .backgroundColor(pageCanvasColor(this.themeDisplayMode, this.themeDarkSurface, this.pageBackgroundValue))
      .attributeModifier(materialModifier(deviceInfo.apiAvailable('26.0.0') ? new uiMaterial.ImmersiveMaterial({
        style: uiMaterial.ImmersiveStyle.REGULAR, applyShadow: true, colorInvert: true }) : undefined))
  }
}
