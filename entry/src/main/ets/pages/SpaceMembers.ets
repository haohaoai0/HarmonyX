import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { userAvatarRadius, verificationBadgeColor, userVerifiedType, userAvatarShape } from '../utils/UserIdentity';
import { common } from '@kit.AbilityKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { uiMaterial } from '@kit.ArkUI';
import { HdsNavDestination, HdsNavDestinationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { SpaceParticipant, SpaceRoom, SpaceRouteParam } from '../models/Space';
import { ProxyAvatar } from '../components/ProxyAvatar';
import { xSpaceService } from '../services/XSpaceService';
import { spaceRole, spaceUserParam } from '../utils/SpacePresentation';
import { destinationTitleBarStyle } from '../utils/DestinationTitleBar';
import { pageSurfaceColor } from '../utils/ThemeColors';
import { formatCount } from '../models/Tweet';

@Builder
export function SpaceMembersBuilder(): void { SpaceMembers(); }

@Component
struct SpaceMembers {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp('harmonyx.status_bar_height') statusBarHeight: number = 0;
  @StorageProp('harmonyx.navigation_indicator_height') navigationIndicatorHeight: number = 0;
  @StorageProp('harmonyx.display_mode') themeDisplayMode: string = '';
  @StorageProp('harmonyx.dark_surface') themeDarkSurface: string = '';
  @StorageLink('harmonyx.title_bar_style_mode') titleBarStyleMode: number = 0;
  @State private room: SpaceRoom = new SpaceRoom();
  @State private filter: string = 'all';
  @State private refreshing: boolean = false;
  @State private failed: boolean = false;
  private scroller: Scroller = new Scroller();
  private generation: number = 0;

  aboutToAppear(): void {
    const params: SpaceRouteParam[] = this.pageStack.getParamByName('SpaceMembers') as SpaceRouteParam[];
    if (params?.length > 0) {
      const param: SpaceRouteParam = params[params.length - 1];
      this.room = param.room ?? new SpaceRoom(); this.room.id = param.spaceId;
    }
    this.load();
  }
  aboutToDisappear(): void { ++this.generation; }
  private async load(): Promise<void> {
    const generation: number = ++this.generation;
    try {
      const room: SpaceRoom | null = await xSpaceService.detail(this.room.id);
      if (generation === this.generation) { this.failed = room === null; if (room !== null) { this.room = room; } }
    } catch (error) { if (generation === this.generation) { this.failed = true; } }
    finally { if (generation === this.generation) { this.refreshing = false; } }
  }
  private people(role: string): SpaceParticipant[] {
    return this.room.participants.filter((person: SpaceParticipant): boolean => person.role === role);
  }
  @Builder
  private Filter(title: Resource, role: string): void {
    Button(title).fontSize($r('sys.float.Body_M')).fontWeight(FontWeight.Medium)
      .fontColor(this.filter === role ? $r('app.color.space_card_text') : $r('app.color.text_primary'))
      .backgroundColor(this.filter === role ? $r('app.color.space_button') : $r('app.color.space_soft'))
      .height($r('app.float.space_filter_height')).accessibilitySelected(this.filter === role)
      .onClick((): void => { this.filter = role; this.scroller.scrollTo({ xOffset: 0, yOffset: 0 }); })
  }
  @Builder
  private Group(role: string, title: Resource): void {
    ListItem() {
      Text(title).fontFamily(this.appFontFamily).fontSize($r('sys.float.Title_S')).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
        .width('100%').padding({ top: 22, bottom: 8 })
    }
    if (this.people(role).length === 0) {
      ListItem() { Text($r('app.string.spaces_no_members')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary')) }
    }
    ForEach(this.people(role), (person: SpaceParticipant): void => {
      ListItem() {
        Row({ space: 12 }) {
          ProxyAvatar({verifiedType: person.verifiedType ?? '', avatarShape: person.avatarShape ?? '',  url: person.avatarUrl, avatarSize: 44, radius: 22, fallbackText: person.name.substring(0, 1),
            fallbackColor: $r('app.color.space_button') })
          Column({ space: 4 }) {
            Row({ space: 5 }) {
              Text(person.name || person.username).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary')).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
              if (person.verified) {
                SymbolGlyph($r('sys.symbol.checkmark_circle_fill')).fontSize(16).fontColor([verificationBadgeColor(person.verifiedType, $r('app.color.text_accent'))])
              }
              if (person.protected) {
                SymbolGlyph($r('sys.symbol.lock_fill')).fontSize(16).fontColor([$r('app.color.text_primary')])
              }
            }.width('100%')
            Text(person.username.length > 0 ? '@' + person.username : spaceRole(person)).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary'))
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        }.width('100%').padding({ top: 10, bottom: 10 }).onClick((): void => {
          this.pageStack.pushPath({ name: 'UserDetail', param: spaceUserParam(person) });
        })
      }
    }, (person: SpaceParticipant): string => person.id)
  }
  build(): void {
    HdsNavDestination() {
      Column({ space: 8 }) {
        Scroll() {
          Row({ space: 8 }) {
            this.Filter($r('app.string.spaces_all'), 'all')
            this.Filter($r('app.string.spaces_cohost'), 'cohost')
            this.Filter($r('app.string.spaces_speaker'), 'speaker')
            this.Filter($r('app.string.spaces_listener'), 'listener')
          }.padding({ left: 16, right: 16 })
        }.width('100%').scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
        Refresh({ refreshing: $$this.refreshing }) {
          List({ scroller: this.scroller }) {
            if (this.failed) {
              ListItem() { Text($r('app.string.spaces_refresh_failed')).fontFamily(this.appFontFamily).fontColor($r('app.color.text_secondary')).padding({ top: 12 }) }
            }
            if (this.filter === 'all') { this.Group('host', $r('app.string.spaces_host')) }
            if ((this.filter === 'all' && this.people('cohost').length > 0) || this.filter === 'cohost') {
              this.Group('cohost', $r('app.string.spaces_cohost'))
            }
            if (this.filter === 'all' || this.filter === 'speaker') { this.Group('speaker', $r('app.string.spaces_speaker')) }
            if (this.filter === 'all' || this.filter === 'listener') {
              this.Group('listener', $r('app.string.spaces_listener'))
              ListItem() {
                Text($r('app.string.spaces_members_partial', formatCount(this.room.participantCount))).fontFamily(this.appFontFamily)
                  .fontSize($r('sys.float.Body_S')).fontColor($r('app.color.text_secondary')).padding({ top: 16, bottom: 16 })
              }
            }
          }.width('100%').constraintSize({ maxWidth: $r('app.float.space_content_width') }).height('100%')
            .padding({ left: 16, right: 16 }).scrollBar(BarState.Off).contentEndOffset(this.navigationIndicatorHeight + 24)
        }.layoutWeight(1).width('100%').onRefreshing((): void => { this.load(); })
      }.width('100%').height('100%').padding({ top: this.statusBarHeight + 60 })
    }.titleMode(HdsNavDestinationTitleMode.MINI).hideBackButton(false)
      .bindToScrollable([this.scroller])
      .titleBar({ avoidLayoutSafeArea: true, content: { title: { mainTitle: $r('app.string.spaces_members') } },
        style: destinationTitleBarStyle(ScrollEffectType.IMMERSIVE_GRADIENT_BLUR,
          this.themeDisplayMode, this.themeDarkSurface, this.titleBarStyleMode) })
      .backgroundColor(pageSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
      .systemMaterial(deviceInfo.apiAvailable('26.0.0') ? new uiMaterial.ImmersiveMaterial({
        style: uiMaterial.ImmersiveStyle.REGULAR, applyShadow: true, colorInvert: true }) : undefined)
  }
}
