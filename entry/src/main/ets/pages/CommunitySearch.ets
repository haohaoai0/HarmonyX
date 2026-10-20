import { pageTextColor } from '../utils/ThemeColors';
import { appPageBackground } from '../components/PageBackgroundLayer';
import { pageCanvasColor, pageReadingSurfaceColor } from '../utils/ThemeColors';
import { STORAGE_KEY_PAGE_TRANSITION_MODE, DEFAULT_PAGE_TRANSITION_MODE } from '../services/PageTransitionSettingsStore';
import { pageSystemTransition, PageTransitionMotion } from '../utils/PageTransition';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { common } from '@kit.AbilityKit';
import {
  BottomBuilderShowType,
  DividerShowType,
  hdsMaterial,
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  ScrollEffectType,
  TitleBarStyleOptions
} from '@kit.UIDesignKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { LengthMetrics, uiMaterial } from '@kit.ArkUI';
import { titleBarFullStyleEnabled, titleBarScrollEffectDisabled } from '../utils/DestinationTitleBar';
import { CommunityRowCard } from '../components/CommunityRowCard';
import type { CommunityPage, CommunityRow, CommunityTopic } from '../models/Community';
import { XCommunityParser } from '../services/XCommunityParser';
import { XPrivateClient, XPrivateResult, xPrivateClient } from '../services/XPrivateClient';
import { communityRoute } from '../utils/CommunityNavigation';
import { fieldSurfaceColor, pageSurfaceColor, titleBarScrimColor } from '../utils/ThemeColors';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';
import { materialModifier } from '../utils/SystemMaterial';

@Builder
export function CommunitySearchBuilder(): void { CommunitySearch(); }

@Component
export struct CommunitySearch {
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
  @State private input: string = '';
  @State private query: string = '';
  @State private topicId: string = '';
  @State private topics: CommunityTopic[] = [];
  @State private rows: CommunityRow[] = [];
  @State private loading: boolean = true;
  @State private loadingMore: boolean = false;
  @State private status: string = '';
  private nextToken: string = '';
  private revision: number = 0;
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void { this.load(true); this.loadTopics(); }
  aboutToDisappear(): void { this.revision++; }
  private text(resource: Resource): string {
    return (getContext(this) as common.UIAbilityContext).resourceManager.getStringSync(resource);
  }
  private supportsImmersiveMaterial(): boolean {
    return deviceInfo.apiAvailable('26.0.0');
  }
  private topicTint(): string {
    if (this.accentColor.length === 7 && this.accentColor.substring(0, 1) === '#') {
      return '#66' + this.accentColor.substring(1);
    }
    return '#66007DFF';
  }
  private topicMaterial(selected: boolean): uiMaterial.Material | undefined {
    if (!this.supportsImmersiveMaterial()) {
      return undefined;
    }
    if (selected) {
      return new uiMaterial.ImmersiveMaterial({
        style: uiMaterial.ImmersiveStyle.THIN,
        materialColor: this.topicTint(),
        interactive: true,
        applyShadow: false,
        colorInvert: false,
        lightEffect: { color: this.accentColor }
      });
    }
    return new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.THIN,
      interactive: true,
      applyShadow: false,
      colorInvert: true,
      lightEffect: { color: this.accentColor }
    });
  }
  // Match the root surface's title-bar parameters exactly: the same scroll
  // effect, original/scrolled background colours and IMMERSIVE/ADAPTIVE
  // material level. The search field and topic row live in this title bar, so
  // both inherit the same material as the home surface.
  private titleBarStyle(): TitleBarStyleOptions {
    const full: boolean = titleBarFullStyleEnabled(this.titleBarStyleMode);
    let effectType: ScrollEffectType = ScrollEffectType.GRADIENT_BLUR;
    if (deviceInfo.apiAvailable('6.1.0(23)')) {
      effectType = ScrollEffectType.IMMERSIVE_GRADIENT_BLUR;
    }
    const options: TitleBarStyleOptions = {
      scrollEffectOpts: full ? {
        enableScrollEffect: true,
        scrollEffectType: effectType,
        blurEffectiveStartOffset: LengthMetrics.vp(0),
        blurEffectiveEndOffset: LengthMetrics.vp(16)
      } : (titleBarScrollEffectDisabled(this.titleBarStyleMode) ? {
        enableScrollEffect: false
      } : undefined),
      originalStyle: full ? {
        backgroundStyle: {
          backgroundColor: titleBarScrimColor(this.themeDisplayMode, this.themeDarkSurface)
        },
        contentStyle: {
          titleStyle: {
            mainTitleColor: $r('app.color.text_primary'),
            subTitleColor: $r('app.color.text_secondary')
          },
          backIconStyle: { iconColor: $r('app.color.text_primary') },
          subIconStyle: { iconColor: $r('app.color.text_primary') },
          menuStyle: { iconColor: $r('app.color.text_primary') }
        }
      } : undefined,
      scrollEffectStyle: full ? {
        backgroundStyle: {
          backgroundColor: pageSurfaceColor(this.themeDisplayMode, this.themeDarkSurface)
        },
        contentStyle: {
          titleStyle: {
            mainTitleColor: $r('app.color.text_primary'),
            subTitleColor: $r('app.color.text_secondary')
          },
          backIconStyle: { iconColor: $r('app.color.text_primary') },
          subIconStyle: { iconColor: $r('app.color.text_primary') },
          menuStyle: { iconColor: $r('app.color.text_primary') }
        }
      } : undefined
    };
    if (deviceInfo.apiAvailable('6.1.0(23)')) {
      options.systemMaterialEffect = {
        materialType: hdsMaterial.MaterialType.IMMERSIVE,
        materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
      };
    }
    return options;
  }
  private async loadTopics(): Promise<void> {
    xPrivateClient.load(getContext(this) as common.UIAbilityContext);
    if (!xPrivateClient.isSignedIn()) { return; }
    const result: XPrivateResult = await xPrivateClient.communityTopics();
    if (result.ok) { this.topics = XCommunityParser.parseTopics(result.body); }
  }
  private submit(value: string): void {
    const query: string = value.trim();
    this.input = value; this.query = query; this.topicId = ''; this.load(true);
  }
  private selectTopic(topic: CommunityTopic): void {
    this.topicId = this.topicId === topic.id ? '' : topic.id;
    this.query = ''; this.input = ''; this.load(true);
  }
  private async load(reset: boolean): Promise<void> {
    if (!reset && (this.loading || this.loadingMore || this.nextToken.length === 0)) { return; }
    const revision: number = reset ? ++this.revision : this.revision;
    const query: string = this.query;
    const topic: string = this.topicId;
    const cursor: string = reset ? '' : this.nextToken;
    if (reset) { this.rows = []; this.loading = true; this.loadingMore = false; this.nextToken = ''; this.status = ''; }
    else { this.loadingMore = true; }
    xPrivateClient.load(getContext(this) as common.UIAbilityContext);
    if (!xPrivateClient.isSignedIn()) {
      this.status = this.text($r('app.string.user_list_sign_in')); this.loading = false; this.loadingMore = false; return;
    }
    // Server search and X's discovery/popular directory are separate contracts.
    const result: XPrivateResult = query.length > 0 ? await xPrivateClient.searchCommunities(query, cursor) :
      await xPrivateClient.communityDirectory(topic, cursor);
    if (revision !== this.revision || query !== this.query || topic !== this.topicId) { return; }
    const page: CommunityPage | null = result.ok ? XCommunityParser.parse(result.body) : null;
    if (page === null) {
      this.status = this.text($r('app.string.communities_failed')) + '\n' + XPrivateClient.explain(result).substring(0, 180);
    } else {
      const combined: CommunityRow[] = reset ? [] : this.rows.slice();
      for (let i: number = 0; i < page.communities.length; i++) {
        if (!combined.some((row: CommunityRow): boolean => row.id === page.communities[i].id)) { combined.push(page.communities[i]); }
      }
      this.rows = combined;
      this.nextToken = page.communities.length > 0 && page.nextToken !== cursor ? page.nextToken : '';
    }
    this.loading = false; this.loadingMore = false;
  }
  @Builder
  private Header(): void {
    Row({ space: 8 }) {
      if (this.supportsImmersiveMaterial()) {
        Stack() {
          Search({ value: this.input, placeholder: $r('app.string.community_search_placeholder') })
            .keyboardAppearance(KeyboardAppearance.IMMERSIVE)
            .width('100%').height(40)
            .backgroundColor(Color.Transparent)
            .fontColor($r('app.color.text_primary'))
            .placeholderColor($r('app.color.text_secondary'))
            .searchButton($r('app.string.search_action'))
            .onChange((value: string): void => {
              this.input = value;
              if (value.trim().length === 0 && this.query.length > 0) { this.submit(''); }
            }).onSubmit((value: string): void => { this.submit(value); })
        }
        .layoutWeight(1).height(40).borderRadius(20).clip(true)
        .attributeModifier(materialModifier(new uiMaterial.ImmersiveMaterial({
          style: uiMaterial.ImmersiveStyle.THIN,
          interactive: true,
          applyShadow: false,
          colorInvert: true,
          lightEffect: { color: this.accentColor }
        })))
      } else {
        Search({ value: this.input, placeholder: $r('app.string.community_search_placeholder') })
          .layoutWeight(1).height(40).keyboardAppearance(KeyboardAppearance.IMMERSIVE)
          .backgroundColor(fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
          .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface)))
          .placeholderColor($r('app.color.text_secondary'))
          .borderRadius(20)
          .searchButton($r('app.string.search_action'))
          .onChange((value: string): void => {
            this.input = value;
            if (value.trim().length === 0 && this.query.length > 0) { this.submit(''); }
          }).onSubmit((value: string): void => { this.submit(value); })
      }
    }
    .width('100%').height(56).alignItems(VerticalAlign.Center)
    // `mini` keeps its back button at the left, so the field starts after it.
    .padding({ left: 64, right: 16 })
  }
  @Builder
  private Topics(): void {
    if (this.topics.length > 0) {
      Scroll() {
        Row({ space: 9 }) {
          ForEach(this.topics, (topic: CommunityTopic) => {
            if (this.supportsImmersiveMaterial()) {
              Stack() {
                Text(topic.name).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontWeight(FontWeight.Medium)
                  .fontColor(this.topicId === topic.id ? $r('app.color.text_on_accent') : $r('app.color.text_primary'))
                  .padding({ left: 18, right: 18, top: 9, bottom: 9 })
              }
              .borderRadius(22).clip(true)
              .backgroundColor(Color.Transparent)
              .border({ width: 1, color: this.topicId === topic.id ? this.accentColor : $r('app.color.divider') })
              .attributeModifier(materialModifier(this.topicMaterial(this.topicId === topic.id)))
              .onClick((): void => this.selectTopic(topic))
            } else {
              Text(topic.name).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontWeight(FontWeight.Medium)
                .fontColor(this.topicId === topic.id ? $r('app.color.text_on_accent') : pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, this.topicId === topic.id ? this.accentColor :
                  fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface)))
                .backgroundColor(this.topicId === topic.id ? this.accentColor :
                  fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
                .border({ width: 1, color: this.topicId === topic.id ? this.accentColor : $r('app.color.divider') })
                .borderRadius(22).padding({ left: 18, right: 18, top: 9, bottom: 9 })
                .onClick((): void => this.selectTopic(topic))
            }
          }, (topic: CommunityTopic): string => topic.id)
        }.height('100%').alignItems(VerticalAlign.Center).padding({ left: 16, right: 16 })
      }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%').height('100%')
    }
  }
  build(): void {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        appPageBackground()
      List({ scroller: this.scroller }) {
        if (this.loading) {
          ListItem() { LoadingProgress().width(28).height(28).color(this.accentColor).margin({ top: 40 }) }
        } else if (this.rows.length === 0) {
          ListItem() {
            Column({ space: 16 }) {
              Text(this.status.length > 0 ? this.status : this.text($r('app.string.community_search_empty'))).fontFamily(this.appFontFamily)
                .fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_secondary')).textAlign(TextAlign.Center)
              if (this.status.length > 0) {
                Button($r('app.string.common_retry')).backgroundColor(this.accentColor).fontColor($r('app.color.text_on_accent'))
                  .onClick((): void => { this.load(true); })
              }
            }.width('100%').padding(32)
          }
        }
        ForEach(this.rows, (row: CommunityRow) => {
          ListItem() { CommunityRowCard({ community: row, onOpen: (item: CommunityRow): void => {
            this.pageStack.pushPath({ name: 'CommunityTimeline', param: communityRoute(item) });
          } }) }
        }, (row: CommunityRow): string => row.id)
        if (this.loadingMore) { ListItem() { LoadingProgress().width(24).height(24).color(this.accentColor) } }
      }
      .width('100%').height('100%')
      // The search field (56vp) and topic row (56vp) are both in the title
      // bar now, so the list begins below that full height and still scrolls
      // underneath the material while dragging.
      .contentStartOffset(this.statusBarHeight + 112)
      .scrollBar(BarState.Off)
      .contentEndOffset(this.navigationIndicatorHeight + 24)
      .clip(false)
      .onReachEnd((): void => { this.load(false); })
    
      }.width('100%').height('100%')
    }
    .scale({ x: this.pageMotion.scale, y: this.pageMotion.scale })
    .opacity(this.pageMotion.opacity)
    .onReady((context: NavDestinationContext): void => { this.pageMotion.attach(context); })
    .systemTransition(pageSystemTransition(this.pageTransitionMode)).titleMode(HdsNavDestinationTitleMode.MINI).hideBackButton(false)
      .onBackPressed((): boolean => { ResponsiveLayout.closeContentDestination(this.pageStack); return true; })
      .bindToScrollable([this.scroller])
      .titleBar({ avoidLayoutSafeArea: true,
        content: {
          stackBuilder: (): void => this.Header(),
          bottomBuilder: {
            builder: (): void => this.Topics(),
            height: 56,
            showType: BottomBuilderShowType.DIRECTLY_SHOW
          },
          divider: { showType: DividerShowType.OFF }
        },
        style: this.titleBarStyle() })
      .backgroundColor(pageCanvasColor(this.themeDisplayMode, this.themeDarkSurface, this.pageBackgroundValue))
      .attributeModifier(materialModifier(deviceInfo.apiAvailable('26.0.0') ? new uiMaterial.ImmersiveMaterial({
        style: uiMaterial.ImmersiveStyle.REGULAR, applyShadow: true, colorInvert: true }) : undefined))
  }
}
