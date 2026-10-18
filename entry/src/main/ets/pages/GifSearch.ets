import { pageTextColor } from '../utils/ThemeColors';
import { appPageBackground } from '../components/PageBackgroundLayer';
import { pageCanvasColor, pageReadingSurfaceColor } from '../utils/ThemeColors';
import { STORAGE_KEY_PAGE_TRANSITION_MODE, DEFAULT_PAGE_TRANSITION_MODE } from '../services/PageTransitionSettingsStore';
import { pageSystemTransition, PageTransitionMotion } from '../utils/PageTransition';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import common from '@ohos.app.ability.common';
import promptAction from '@ohos.promptAction';
import { deviceInfo } from '@kit.BasicServicesKit';
import { fileUri } from '@kit.CoreFileKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { systemShare } from '@kit.ShareKit';
import { SymbolGlyphModifier } from '@kit.ArkUI';
import { uiMaterial } from '@kit.ArkUI';
import {
  DividerShowType,
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  ScrollEffectType
} from '@kit.UIDesignKit';
import { GifPreviewImage } from '../components/GifPreviewImage';
import { GifSearchItem, GifSearchParser } from '../services/GifSearchParser';
import { XPrivateClient, XPrivateResult, xPrivateClient } from '../services/XPrivateClient';
import { proxyDownloadService } from '../services/ProxyDownloadService';
import {
  MEDIA_DOWNLOAD_CANCELED,
  MEDIA_DOWNLOAD_FAILED,
  MEDIA_DOWNLOAD_SUCCESS,
  mediaDownloadService
} from '../services/MediaDownloadService';
import { gifSearchSelectionStore } from '../services/GifSearchSelectionStore';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';
import { destinationTitleBarStyle } from '../utils/DestinationTitleBar';
import { fieldSurfaceColor, pageSurfaceColor } from '../utils/ThemeColors';

@Builder
export function GifSearchBuilder(): void {
  GifSearchPage();
}

@Component
export struct GifSearchPage {
  @StorageProp('harmonyx.page_background') private pageBackgroundValue: string = '';
  @State private pageMotion: PageTransitionMotion = new PageTransitionMotion();
  @StorageProp(STORAGE_KEY_PAGE_TRANSITION_MODE) private pageTransitionMode: string = DEFAULT_PAGE_TRANSITION_MODE;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp('harmonyx.status_bar_height') statusBarHeight: number =
    AppStorage.get<number>('harmonyx.status_bar_height') ?? 0;
  @StorageLink('harmonyx.accent_color') accentColor: string = '#007DFF';
  @StorageProp('harmonyx.display_mode') private themeDisplayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private themeDarkSurface: string = '';
  @StorageLink('harmonyx.title_bar_style_mode') titleBarStyleMode: number = 0;
  @StorageLink('harmonyx.breakpoint') breakpoint: string = ResponsiveLayout.BREAKPOINT_SM;
  @State private query: string = '';
  @State private results: GifSearchItem[] = [];
  @State private loading: boolean = true;
  @State private loadFailed: boolean = false;
  @State private downloadingId: string = '';
  @State private actionMenuItemId: string = '';
  private gifActionBusy: boolean = false;
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.loadResults(true);
  }

  private text(resource: Resource): string {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    return context.resourceManager.getStringSync(resource);
  }

  private columnsTemplate(): string {
    if (ResponsiveLayout.isWide(this.breakpoint)) {
      return '1fr 1fr 1fr 1fr 1fr';
    }
    if (ResponsiveLayout.isLarge(this.breakpoint)) {
      return '1fr 1fr 1fr 1fr';
    }
    if (this.breakpoint === ResponsiveLayout.BREAKPOINT_MD) {
      return '1fr 1fr 1fr';
    }
    return '1fr 1fr';
  }

  private async loadResults(recommend: boolean): Promise<void> {
    if (this.loading && this.results.length > 0) {
      return;
    }
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    xPrivateClient.load(context);
    this.loading = true;
    this.loadFailed = false;
    const searchTerm: string = this.query.trim();
    const showRecommendations: boolean = recommend || searchTerm.length === 0;
    const operation: string = showRecommendations ? 'GifEnumerateCategoryQuery' : 'GifSearchQuery';
    const variables: Record<string, Object> = showRecommendations ? { 'category': 'trending' } :
      { 'query': searchTerm };
    const result: XPrivateResult = await xPrivateClient.graphql(operation, variables);
    this.loading = false;
    if (!result.ok) {
      this.loadFailed = true;
      this.results = [];
      return;
    }
    this.results = GifSearchParser.parse(result.body);
    this.loadFailed = false;
  }

  private submitSearch(): void {
    this.scroller.scrollEdge(Edge.Top);
    this.loadResults(this.query.trim().length === 0);
  }

  private closePage(): void {
    ResponsiveLayout.closeContentDestination(this.pageStack);
  }

  private gifMenuMaterial(): uiMaterial.ImmersiveMaterial | undefined {
    if (!deviceInfo.apiAvailable('26.0.0')) {
      return undefined;
    }
    return new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.THIN,
      interactive: true,
      applyShadow: false,
      colorInvert: true
    });
  }

  private showGifActionMenu(item: GifSearchItem): void {
    this.actionMenuItemId = item.id;
  }

  private saveGif(item: GifSearchItem): void {
    if (this.gifActionBusy) {
      return;
    }
    this.gifActionBusy = true;
    promptAction.showToast({ message: this.text($r('app.string.gif_save_started')), duration: 1800 });
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    mediaDownloadService.download(context, item.fullImageUrl, item.id, false, (result: number): void => {
      this.gifActionBusy = false;
      if (result === MEDIA_DOWNLOAD_SUCCESS) {
        promptAction.showToast({ message: this.text($r('app.string.gif_saved')), duration: 2200 });
      } else if (result === MEDIA_DOWNLOAD_CANCELED) {
        promptAction.showToast({ message: this.text($r('app.string.media_download_canceled')), duration: 1800 });
      } else if (result === MEDIA_DOWNLOAD_FAILED) {
        promptAction.showToast({ message: this.text($r('app.string.media_download_failed')), duration: 2400 });
      }
    });
  }

  private async shareGif(item: GifSearchItem): Promise<void> {
    if (this.gifActionBusy) {
      return;
    }
    this.gifActionBusy = true;
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const filePath: string = context.cacheDir + '/harmonyx-gif-share-' + Date.now().toString() + '.gif';
    const downloaded: boolean = await proxyDownloadService.downloadWithRetry(item.fullImageUrl, filePath, 2);
    if (!downloaded) {
      this.gifActionBusy = false;
      promptAction.showToast({ message: this.text($r('app.string.gif_share_failed')), duration: 2200 });
      return;
    }
    const sharedData: systemShare.SharedData = new systemShare.SharedData({
      utd: utd.UniformDataType.GIF,
      uri: fileUri.getUriFromPath(filePath),
      title: this.text($r('app.string.gif_share_title'))
    });
    const controller: systemShare.ShareController = new systemShare.ShareController(sharedData);
    try {
      await controller.show(context, {
        selectionMode: systemShare.SelectionMode.SINGLE,
        previewMode: systemShare.SharePreviewMode.DEFAULT
      });
    } catch (error) {
      promptAction.showToast({ message: this.text($r('app.string.gif_share_failed')), duration: 2200 });
    }
    this.gifActionBusy = false;
  }

  @Builder
  private GifActionMenu(item: GifSearchItem): void {
    Menu() {
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.download')),
        content: $r('app.string.gif_action_save')
      }).onClick((): void => {
        this.saveGif(item);
      });
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.share')),
        content: $r('app.string.gif_action_share')
      }).onClick((): void => {
        void this.shareGif(item);
      });
    }
  }

  private async chooseGif(item: GifSearchItem): Promise<void> {
    if (this.downloadingId.length > 0) {
      return;
    }
    this.downloadingId = item.id;
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const filePath: string = context.cacheDir + '/harmonyx-gif-search-' + Date.now().toString() + '.gif';
    const downloaded: boolean = await proxyDownloadService.downloadWithRetry(item.fullImageUrl, filePath, 2);
    this.downloadingId = '';
    if (!downloaded) {
      promptAction.showToast({ message: this.text($r('app.string.gif_search_download_failed')), duration: 2000 });
      return;
    }
    gifSearchSelectionStore.publish(fileUri.getUriFromPath(filePath));
    this.pageStack.pop();
  }

  @Builder
  private SearchControls(): void {
    Column({ space: 12 }) {
      Text(this.query.trim().length === 0 ? $r('app.string.gif_search_trending') :
        $r('app.string.gif_search_results')).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Title_S'))
        .fontWeight(FontWeight.Bold)
        .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent))
        .width('100%')
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
  }

  @Builder
  private SearchField(height: number): void {
    if (deviceInfo.apiAvailable('26.0.0')) {
      Stack() {
        Search({ value: this.query, placeholder: $r('app.string.gif_search_placeholder') })
          .keyboardAppearance(KeyboardAppearance.IMMERSIVE)
          .width('100%')
          .height(height)
          .backgroundColor(Color.Transparent)
          .fontColor($r('app.color.text_primary'))
          .placeholderColor($r('app.color.text_secondary'))
          .focusOnTouch(true)
          .searchButton($r('app.string.search_action'))
          .onChange((value: string): void => {
            this.query = value;
          })
          .onSubmit((value: string): void => {
            this.query = value;
            this.submitSearch();
          })
      }
      .width('100%')
      .height(height)
      .borderRadius(height / 2)
      .clip(true)
      .systemMaterial(new uiMaterial.ImmersiveMaterial({
        style: uiMaterial.ImmersiveStyle.THIN,
        interactive: true,
        applyShadow: false,
        colorInvert: true,
        lightEffect: { color: this.accentColor }
      }))
    } else {
      Search({ value: this.query, placeholder: $r('app.string.gif_search_placeholder') })
        .keyboardAppearance(KeyboardAppearance.IMMERSIVE)
        .width('100%')
        .height(height)
        .backgroundColor(fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
        .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface)))
        .placeholderColor($r('app.color.text_secondary'))
        .borderRadius(height / 2)
        .focusOnTouch(true)
        .searchButton($r('app.string.search_action'))
        .onChange((value: string): void => {
          this.query = value;
        })
        .onSubmit((value: string): void => {
          this.query = value;
          this.submitSearch();
        })
    }
  }

  @Builder
  private TitleBarContent(): void {
    Row() {
      this.SearchField(40)
    }
    .width('100%')
    .height(56)
    .padding({ left: 64, right: 16 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private ResultGrid(): void {
    if (this.results.length > 0) {
      WaterFlow({ scroller: this.scroller, layoutMode: WaterFlowLayoutMode.SLIDING_WINDOW }) {
        ForEach(this.results, (item: GifSearchItem) => {
          FlowItem() {
            Stack({ alignContent: Alignment.BottomEnd }) {
              GifPreviewImage({
                url: item.fullImageUrl,
                previewUrl: item.thumbnailUrl,
                displayHeight: this.thumbnailHeight(item),
                surfaceColor: fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface)
              })
                .borderRadius(14)
                .clip(true)
              if (this.downloadingId === item.id) {
                LoadingProgress()
                  .color($r('app.color.text_on_inverse'))
                  .width(28)
                  .height(28)
                  .margin(10)
              }
            }
            .width('100%')
            .onClick((): void => {
              this.chooseGif(item);
            })
            .parallelGesture(
              LongPressGesture({ fingers: 1, repeat: false, duration: 500 })
                .onAction((): void => {
                  this.showGifActionMenu(item);
                })
            )
            .bindContextMenu(this.actionMenuItemId === item.id, this.GifActionMenu(item), {
              preview: MenuPreviewMode.IMAGE,
              borderRadius: 16,
              backgroundColor: Color.Transparent,
              backgroundBlurStyle: BlurStyle.BACKGROUND_THIN,
              systemMaterial: this.gifMenuMaterial(),
              mask: {
                color: '#52000000',
                backgroundBlurStyle: BlurStyle.BACKGROUND_THIN
              },
              modalMode: ModalMode.TARGET_WINDOW,
              hapticFeedbackMode: HapticFeedbackMode.AUTO,
              onDisappear: (): void => {
                if (this.actionMenuItemId === item.id) {
                  this.actionMenuItemId = '';
                }
              }
            })
          }
          .width('100%')
          .padding(5)
        }, (item: GifSearchItem): string => item.id)
      }
      .columnsTemplate(this.columnsTemplate())
      .columnsGap(2)
      .rowsGap(2)
      .width('100%')
      .height('100%')
      .contentStartOffset(this.statusBarHeight + 104)
      .backgroundColor(pageCanvasColor(this.themeDisplayMode, this.themeDarkSurface, this.pageBackgroundValue))
      .cachedCount(8)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .scrollBar(BarState.Off)
    } else {
      Column({ space: 12 }) {
        if (this.loading) {
          LoadingProgress().color(this.accentColor).width(30).height(30)
        } else if (this.loadFailed) {
          Text($r('app.string.gif_search_load_failed')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M'))
            .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
            .textAlign(TextAlign.Center)
        } else {
          Text($r('app.string.gif_search_empty')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M'))
            .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
            .textAlign(TextAlign.Center)
        }
      }
      .layoutWeight(1)
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ left: 28, right: 28, top: this.statusBarHeight + 104, bottom: 36 })
      .backgroundColor(pageCanvasColor(this.themeDisplayMode, this.themeDarkSurface, this.pageBackgroundValue))
      .onClick((): void => {
        if (this.loadFailed) {
          this.loadResults(this.query.trim().length === 0);
        }
      })
    }
  }

  private thumbnailHeight(item: GifSearchItem): number {
    if (item.width > 0 && item.height > 0) {
      return Math.min(240, Math.max(110, 155 * item.height / item.width));
    }
    return 155;
  }

  build(): void {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        appPageBackground()
      this.ResultGrid();
    
      }.width('100%').height('100%')
    }
    .scale({ x: this.pageMotion.scale, y: this.pageMotion.scale })
    .opacity(this.pageMotion.opacity)
    .onReady((context: NavDestinationContext): void => { this.pageMotion.attach(context); })
    .systemTransition(pageSystemTransition(this.pageTransitionMode))
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .hideBackButton(false)
    .titleBar({
      avoidLayoutSafeArea: true,
      content: {
        stackBuilder: (): void => this.TitleBarContent(),
        bottomBuilder: {
          builder: (): void => this.SearchControls(),
          height: 48
        },
        divider: { showType: DividerShowType.OFF }
      },
      style: destinationTitleBarStyle(ScrollEffectType.IMMERSIVE_GRADIENT_BLUR,
        this.themeDisplayMode, this.themeDarkSurface, this.titleBarStyleMode)
    })
    .bindToScrollable([this.scroller])
    .onBackPressed((): boolean => {
      this.closePage();
      return true;
    })
    .backgroundColor(pageCanvasColor(this.themeDisplayMode, this.themeDarkSurface, this.pageBackgroundValue));
  }
}
