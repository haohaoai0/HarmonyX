import { appPageBackground } from '../components/PageBackgroundLayer';
import { pageCanvasColor, pageReadingSurfaceColor } from '../utils/ThemeColors';
import { STORAGE_KEY_PAGE_TRANSITION_MODE, DEFAULT_PAGE_TRANSITION_MODE } from '../services/PageTransitionSettingsStore';
import { pageSystemTransition, PageTransitionMotion } from '../utils/PageTransition';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { common } from '@kit.AbilityKit';
import { HdsNavDestination, HdsNavDestinationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { uiMaterial } from '@kit.ArkUI';
import { destinationTitleBarStyle } from '../utils/DestinationTitleBar';
import type { CommunityRow, CommunityRule } from '../models/Community';
import { XCommunityParser } from '../services/XCommunityParser';
import { XPrivateClient, XPrivateResult, xPrivateClient } from '../services/XPrivateClient';
import { XUserParser } from '../services/XUserParser';
import { pageSurfaceColor } from '../utils/ThemeColors';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';
import type { CommunityRulesRouteParam } from './Communities';

@Builder
export function CommunityRulesBuilder(): void { CommunityRules(); }

@Component
export struct CommunityRules {
  @StorageProp('harmonyx.page_background') private pageBackgroundValue: string = '';
  @State private pageMotion: PageTransitionMotion = new PageTransitionMotion();
  @StorageProp(STORAGE_KEY_PAGE_TRANSITION_MODE) private pageTransitionMode: string = DEFAULT_PAGE_TRANSITION_MODE;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp('harmonyx.status_bar_height') statusBarHeight: number = 0;
  @StorageProp('harmonyx.navigation_indicator_height') navigationIndicatorHeight: number = 0;
  @StorageLink('harmonyx.accent_color') accentColor: string = '#007DFF';
  @StorageProp('harmonyx.display_mode') themeDisplayMode: string = '';
  @StorageProp('harmonyx.dark_surface') themeDarkSurface: string = '';
  @StorageLink('harmonyx.title_bar_style_mode') titleBarStyleMode: number = 0;
  @State private title: string = '';
  @State private rules: CommunityRule[] = [];
  @State private communityId: string = '';
  @State private joinPolicy: string = '';
  @State private question: string = '';
  @State private answer: string = '';
  @State private busy: boolean = false;
  @State private loading: boolean = false;
  @State private ready: boolean = false;
  @State private status: string = '';
  @State private requested: boolean = false;
  private scroller: Scroller = new Scroller();

  private text(resource: Resource): string {
    return (getContext(this) as common.UIAbilityContext).resourceManager.getStringSync(resource);
  }
  private restricted(): boolean {
    const policy: string = this.joinPolicy.toLowerCase();
    return policy.indexOf('restricted') >= 0 || policy.indexOf('approval') >= 0;
  }
  private readRoute(param: CommunityRulesRouteParam): void {
    this.title = param.title; this.rules = param.rules;
    this.communityId = param.communityId ?? ''; this.joinPolicy = param.joinPolicy ?? '';
    this.question = param.joinQuestion ?? '';
    if (this.communityId.length > 0) { this.loadRules(); }
  }
  private async loadRules(): Promise<void> {
    this.loading = true; this.ready = false; this.status = '';
    xPrivateClient.load(getContext(this) as common.UIAbilityContext);
    const result: XPrivateResult = await xPrivateClient.communityInfo(this.communityId);
    const row: CommunityRow | undefined = result.ok ? XCommunityParser.parse(result.body)?.communities.find(
      (item: CommunityRow): boolean => item.id === this.communityId) : undefined;
    this.loading = false;
    if (row === undefined) { this.status = this.text($r('app.string.community_rules_load_failed')); return; }
    this.rules = row.rules; this.joinPolicy = row.joinPolicy; this.question = row.joinQuestion ?? '';
    this.ready = true;
  }
  private async join(): Promise<void> {
    if (this.busy || !this.ready || this.requested) { return; }
    if (this.restricted() && this.question.length > 0 && this.answer.trim().length === 0) {
      this.status = this.text($r('app.string.community_join_answer_required')); return;
    }
    this.busy = true; this.status = '';
    if (xPrivateClient.viewerId().length > 0) {
      const profile: XPrivateResult = await xPrivateClient.userByRestId(xPrivateClient.viewerId());
      if (profile.ok && XUserParser.isProtectedAccount(profile.body)) {
        this.busy = false; this.status = this.text($r('app.string.community_public_account_required')); return;
      }
    }
    const result: XPrivateResult = this.restricted() ?
      await xPrivateClient.requestToJoinCommunity(this.communityId, this.answer.trim()) :
      await xPrivateClient.joinCommunity(this.communityId);
    this.busy = false;
    if (!result.ok) { this.status = XPrivateClient.explain(result).substring(0, 220); return; }
    AppStorage.setOrCreate<number>('harmonyx.community_membership_changed',
      (AppStorage.get<number>('harmonyx.community_membership_changed') ?? 0) + 1);
    if (this.restricted()) { this.requested = true; this.status = this.text($r('app.string.community_join_request_sent')); }
    else { this.pageStack.pop(); }
  }
  build(): void {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        appPageBackground()
      Column({ space: 0 }) {
        List({ scroller: this.scroller }) {
          ListItem() {
            Column({ space: 10 }) {
              Text(this.communityId.length > 0 ? this.text($r('app.string.community_join_review')) + ' ' + this.title : this.title).fontFamily(this.appFontFamily)
                .fontSize($r('sys.float.Title_M')).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary')).width('100%')
              Text($r('app.string.community_join_rules_intro')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
                .fontColor($r('app.color.text_secondary')).width('100%')
            }.width('100%').padding({ left: 16, right: 16, top: 36, bottom: 24 })
          }
          if (this.loading) { ListItem() { LoadingProgress().color(this.accentColor).width(28).height(28).margin(20) } }
          ForEach(this.rules, (rule: CommunityRule, index: number) => {
            ListItem() {
              Row({ space: 16 }) {
                Text((index + 1).toString()).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontWeight(FontWeight.Bold)
                  .width(36).height(36).borderRadius(18).textAlign(TextAlign.Center)
                  .fontColor($r('app.color.bg_page')).backgroundColor($r('app.color.text_primary'))
                Column({ space: 6 }) {
                  Text(rule.name).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
                  if (rule.description.length > 0) { Text(rule.description).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary')) }
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              }.width('100%').padding({ left: 16, right: 16, top: 16, bottom: 16 })
            }
          }, (rule: CommunityRule): string => rule.id + rule.name)
          if (this.rules.length === 0 && !this.loading) {
            ListItem() { Text($r('app.string.community_rules_empty')).fontFamily(this.appFontFamily).fontColor($r('app.color.text_secondary')).padding(20) }
          }
          if (this.restricted() && this.question.length > 0) {
            ListItem() {
              Column({ space: 10 }) {
                Text(this.question).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
                TextArea({ text: this.answer, placeholder: $r('app.string.community_join_answer') }).fontFamily(this.appFontFamily)
                  .height(100).onChange((value: string): void => { this.answer = value; })
              }.width('100%').padding(16)
            }
          }
          if (this.status.length > 0) {
            ListItem() {
              Column({ space: 12 }) {
                Text(this.status).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary'))
                if (!this.ready && !this.loading) { Button($r('app.string.common_retry')).onClick((): void => { this.loadRules(); }) }
              }.width('100%').padding(20)
            }
          }
        }.width('100%').layoutWeight(1).scrollBar(BarState.Off)
        if (this.communityId.length > 0) {
          Button(this.busy ? $r('app.string.post_sending') : this.requested ? $r('app.string.community_join_request_sent') :
            $r('app.string.community_join_agree')).height(50).width('100%')
            .fontSize($r('sys.float.Body_L')).fontWeight(FontWeight.Bold).backgroundColor(this.accentColor)
            .fontColor($r('app.color.text_on_accent')).enabled(this.ready && !this.busy && !this.requested)
            .onClick((): void => { this.join(); })
            .margin({ left: 16, right: 16, top: 12, bottom: this.navigationIndicatorHeight + 16 })
        }
      }.width('100%').height('100%').padding({ top: this.statusBarHeight + 60 })
    
      }.width('100%').height('100%')
    }
    .scale({ x: this.pageMotion.scale, y: this.pageMotion.scale })
    .opacity(this.pageMotion.opacity)
    .systemTransition(pageSystemTransition(this.pageTransitionMode)).titleMode(HdsNavDestinationTitleMode.MINI).hideBackButton(false)
      .onReady((context: NavDestinationContext): void => {
      this.pageMotion.attach(context); this.readRoute(context.pathInfo.param as CommunityRulesRouteParam); })
      .onBackPressed((): boolean => { if (!this.busy) { ResponsiveLayout.closeContentDestination(this.pageStack); } return true; })
      .bindToScrollable([this.scroller])
      .titleBar({ avoidLayoutSafeArea: true,
        content: { title: { mainTitle: this.communityId.length > 0 ? $r('app.string.community_join_action') : $r('app.string.community_rules_title') } },
        style: destinationTitleBarStyle(ScrollEffectType.IMMERSIVE_GRADIENT_BLUR,
          this.themeDisplayMode, this.themeDarkSurface, this.titleBarStyleMode) })
      .backgroundColor(pageCanvasColor(this.themeDisplayMode, this.themeDarkSurface, this.pageBackgroundValue))
      .systemMaterial(deviceInfo.apiAvailable('26.0.0') ? new uiMaterial.ImmersiveMaterial({
        style: uiMaterial.ImmersiveStyle.REGULAR, applyShadow: true, colorInvert: true }) : undefined)
  }
}

