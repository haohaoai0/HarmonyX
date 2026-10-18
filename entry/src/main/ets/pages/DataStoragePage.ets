import { pageTextColor } from '../utils/ThemeColors';
import { appPageBackground } from '../components/PageBackgroundLayer';
import { pageCanvasColor, pageReadingSurfaceColor } from '../utils/ThemeColors';
import { STORAGE_KEY_PAGE_TRANSITION_MODE, DEFAULT_PAGE_TRANSITION_MODE } from '../services/PageTransitionSettingsStore';
import { pageSystemTransition, PageTransitionMotion } from '../utils/PageTransition';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { common } from '@kit.AbilityKit';
import { HdsNavDestination, HdsNavDestinationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { promptAction } from '@kit.ArkUI';
import {
  AppStorageUsage, AppNetworkUsage, StorageCacheKind, StorageClearResult,
  getAppStorageUsage, getAppNetworkUsage, clearAppCache, storageBytes
} from '../services/DataStorageService';
import { xChatActions } from '../services/XChatActions';
import { xChatMedia } from '../services/XChatMedia';
import { downloadLocationStore } from '../services/DownloadLocationStore';
import { destinationTitleBarStyle } from '../utils/DestinationTitleBar';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';
import { cardSurfaceColor, pageSurfaceColor, secondaryButtonSurfaceColor } from '../utils/ThemeColors';

@Builder
export function DataStorageBuilder(): void { DataStoragePage(); }

@Component
export struct DataStoragePage {
  @StorageProp('harmonyx.page_background') private pageBackgroundValue: string = '';
  @State private pageMotion: PageTransitionMotion = new PageTransitionMotion();
  @StorageProp(STORAGE_KEY_PAGE_TRANSITION_MODE) private pageTransitionMode: string = DEFAULT_PAGE_TRANSITION_MODE;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp('harmonyx.display_mode') private displayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private darkSurface: string = '';
  @StorageLink('harmonyx.title_bar_style_mode') titleBarStyleMode: number = 0;
  @StorageProp('harmonyx.status_bar_height') statusBarHeight: number = AppStorage.get<number>('harmonyx.status_bar_height') ?? 0;
  @StorageProp('harmonyx.navigation_indicator_height') navigationIndicatorHeight: number =
    AppStorage.get<number>('harmonyx.navigation_indicator_height') ?? 0;
  @State private usage: AppStorageUsage = new AppStorageUsage();
  @State private network: AppNetworkUsage = new AppNetworkUsage();
  @State private loaded: boolean = false;
  @State private loading: boolean = false;
  @State private storageError: boolean = false;
  @State private networkAvailable: boolean = false;
  @State private busy: boolean = false;
  @State private useFolder: boolean = false;
  @State private chatRetention: string = '30';
  private scroller: Scroller = new Scroller();
  private active: boolean = false;
  private sequence: number = 0;
  private lastLoadAt: number = 0;

  aboutToAppear(): void { this.active = true; this.refreshLocation(); this.load(); }
  aboutToDisappear(): void { this.active = false; this.sequence++; }
  private context(): common.UIAbilityContext { return getContext(this) as common.UIAbilityContext; }
  private text(resource: Resource): string { return this.context().resourceManager.getStringSync(resource); }
  private color(resource: Resource): string {
    return '#' + (this.context().resourceManager.getColorSync(resource) >>> 0).toString(16).padStart(8, '0');
  }

  private refreshLocation(): void {
    this.useFolder = downloadLocationStore.useDownloads(this.context());
    this.chatRetention = xChatActions.localString(this.context(), 'retention_days', '30');
  }

  private load(): void {
    if (this.loading || this.busy) { return; }
    const current: number = ++this.sequence;
    this.lastLoadAt = Date.now(); this.loading = true;
    const storageJob: Promise<void> = getAppStorageUsage(this.context()).then((usage: AppStorageUsage): void => {
      if (!this.active || current !== this.sequence) { return; }
      this.usage = usage; this.loaded = true; this.storageError = false;
    }).catch((): void => { if (this.active && current === this.sequence) { this.storageError = true; } });
    const networkJob: Promise<void> = getAppNetworkUsage().then((usage: AppNetworkUsage): void => {
      if (!this.active || current !== this.sequence) { return; }
      this.network = usage; this.networkAvailable = true;
    }).catch((): void => { if (this.active && current === this.sequence) { this.networkAvailable = false; } });
    Promise.all([storageJob, networkJob]).then((): void => {
      if (this.active && current === this.sequence) { this.loading = false; }
    });
  }

  private changeSaveTarget(enabled: boolean): void {
    if (this.busy) { return; }
    this.useFolder = enabled; this.busy = true;
    downloadLocationStore.setUseDownloads(this.context(), enabled)
      .catch((): void => { promptAction.showToast({ message: $r('app.string.storage_directory_failed') }); })
      .finally((): void => { this.refreshLocation(); this.busy = false; });
  }

  private confirmClear(kind: StorageCacheKind): void {
    if (this.busy) { return; }
    this.busy = true;
    getAppStorageUsage(this.context()).then((usage: AppStorageUsage): void => {
      if (!this.active) { this.busy = false; return; }
      this.busy = false;
      promptAction.showDialog({
        title: $r('app.string.storage_clear_title'),
        message: this.context().resourceManager.getStringSync($r('app.string.storage_clear_confirm'),
          storageBytes(usage.clearableBytes())),
        buttons: [{ text: $r('app.string.storage_cancel'), color: this.color($r('app.color.text_secondary')) },
          { text: $r('app.string.storage_clear_action'), color: this.color($r('app.color.brand')) }]
      }).then((response: promptAction.ShowDialogSuccessResponse): void => {
        if (response.index !== 1 || this.busy || !this.active) { return; }
        this.busy = true; this.sequence++;
        clearAppCache(this.context(), kind).then((result: StorageClearResult): void => {
          promptAction.showToast({ message: this.context().resourceManager.getStringSync(
            result.failures > 0 ? $r('app.string.storage_clear_partial') : $r('app.string.storage_clear_done'),
            storageBytes(result.freedBytes)), duration: 2400 });
        }).catch((): void => { promptAction.showToast({ message: $r('app.string.storage_clear_failed') }); })
          .finally((): void => { this.busy = false; if (this.active) { this.load(); } });
      });
    }).catch((): void => {
      this.busy = false;
      promptAction.showToast({ message: $r('app.string.storage_clear_failed') });
    });
  }

  @Builder
  private ValueRow(label: Resource, value: string): void {
    Row({ space: 12 }) {
      Text(label).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, pageReadingSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue))).layoutWeight(1)
      Text(value).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, pageReadingSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue)))
    }.width('100%')
  }

  @Builder
  private SummaryCard(): void {
    Column({ space: 14 }) {
      Text($r('app.string.storage_local_usage')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, pageReadingSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue))).width('100%')
      Text(this.loaded && this.usage.systemAvailable ? storageBytes(this.usage.totalBytes()) : this.text($r('app.string.storage_unavailable'))).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Title_L')).fontWeight(FontWeight.Bold).fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, pageReadingSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue))).width('100%')
      this.ValueRow($r('app.string.storage_package'), this.usage.systemAvailable ? storageBytes(this.usage.appBytes) : '—')
      this.ValueRow($r('app.string.storage_app_data'), this.usage.systemAvailable ? storageBytes(this.usage.dataBytes) : '—')
      this.ValueRow($r('app.string.storage_free_space'), this.usage.freeBytes >= 0 ? storageBytes(this.usage.freeBytes) : '—')
      Text($r('app.string.storage_total_note')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Caption_M')).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, pageReadingSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue))).width('100%')
    }.width('100%').padding(16).borderRadius(16).backgroundColor(pageReadingSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue))
  }

  @Builder
  private CacheCard(): void {
    Column() {
      Button($r('app.string.storage_clear_all')).width('100%')
        .backgroundColor(secondaryButtonSurfaceColor(this.displayMode, this.darkSurface)).fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, secondaryButtonSurfaceColor(this.displayMode, this.darkSurface)))
        .enabled(!this.busy)
        .onClick((): void => this.confirmClear(StorageCacheKind.ALL))
    }.width('100%').padding(16).borderRadius(16).backgroundColor(pageReadingSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue))
  }

  @Builder
  private DownloadsCard(): void {
    Column({ space: 12 }) {
      Text($r('app.string.storage_download_path')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Subtitle_L')).fontWeight(FontWeight.Medium)
        .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, pageReadingSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue))).width('100%')
      Text($r('app.string.storage_system_save')).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_M')).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, pageReadingSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue))).width('100%')
      Row({ space: 12 }) {
        Column({ space: 5 }) {
          Text($r('app.string.storage_save_to_folder')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, pageReadingSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue)))
          Text($r('app.string.storage_save_target_note')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Caption_M')).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, pageReadingSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue)))
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Toggle({ type: ToggleType.Switch, isOn: this.useFolder }).enabled(!this.busy)
          .onChange((enabled: boolean): void => this.changeSaveTarget(enabled))
      }.width('100%')
      this.ValueRow($r('app.string.storage_download_files'), this.loaded ? storageBytes(this.usage.downloads.bytes) : '—')
      this.ValueRow($r('app.string.storage_other_cache'), this.loaded ? storageBytes(this.usage.otherCacheBytes()) : '—')
      Text($r('app.string.storage_protected_note')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Caption_M')).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, pageReadingSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue))).width('100%')
      Button($r('app.string.download_tasks_title')).width('100%')
        .backgroundColor(secondaryButtonSurfaceColor(this.displayMode, this.darkSurface)).fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, secondaryButtonSurfaceColor(this.displayMode, this.darkSurface)))
        .onClick((): void => { this.pageStack.pushPath({ name: 'DownloadManager', param: '' }); })
    }.width('100%').padding(16).borderRadius(16).backgroundColor(pageReadingSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue))
  }

  @Builder
  private NetworkCard(): void {
    Column({ space: 14 }) {
      Text($r('app.string.storage_network_title')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Subtitle_L')).fontWeight(FontWeight.Medium)
        .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, pageReadingSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue))).width('100%')
      this.ValueRow($r('app.string.storage_network_received'), this.networkAvailable ? storageBytes(this.network.received) : '—')
      this.ValueRow($r('app.string.storage_network_sent'), this.networkAvailable ? storageBytes(this.network.sent) : '—')
      Text(this.networkAvailable ? $r('app.string.storage_network_note') : $r('app.string.storage_network_unavailable')).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Caption_M')).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, pageReadingSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue))).width('100%')
    }.width('100%').padding(16).borderRadius(16).backgroundColor(pageReadingSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue))
  }

  private setChatRetention(value: string): void {
    xChatActions.saveLocal(this.context(), 'retention_days', value);
    this.chatRetention = value;
    xChatMedia.prune(this.context());
    this.load();
  }

  @Builder
  private ChatRetentionCard(): void {
    Row({ space: 12 }) {
      Column({ space: 6 }) {
        Text($r('app.string.storage_chat_retention')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Subtitle_L'))
          .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent))
        Text($r('app.string.storage_chat_retention_desc')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
          .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Text(this.chatRetention === '0' ? $r('app.string.chat_forever') : this.chatRetention === '7' ?
        $r('app.string.chat_7_days') : $r('app.string.chat_30_days')).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_M')).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
    }.width('100%').padding(16).borderRadius(16)
      .backgroundColor(pageReadingSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue))
      .id('storage-chat-retention').bindMenu(this.ChatRetentionMenu())
  }

  @Builder
  private ChatRetentionMenu(): void {
    Menu() {
      MenuItem({ content: $r('app.string.chat_7_days') }).onClick((): void => this.setChatRetention('7'))
      MenuItem({ content: $r('app.string.chat_30_days') }).onClick((): void => this.setChatRetention('30'))
      MenuItem({ content: $r('app.string.chat_forever') }).onClick((): void => this.setChatRetention('0'))
    }
  }

  build(): void {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        appPageBackground()
      Scroll(this.scroller) {
        Column({ space: 16 }) {
          Row({ space: 12 }) {
            if (this.loading || this.busy) { LoadingProgress().width(22).height(22).color($r('app.color.brand')) }
            Text(this.busy ? $r('app.string.storage_processing') : (this.loading ? $r('app.string.storage_loading') :
              $r('app.string.storage_stats_note'))).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)).layoutWeight(1)
            Button($r('app.string.storage_refresh')).enabled(!this.busy && !this.loading)
              .backgroundColor(secondaryButtonSurfaceColor(this.displayMode, this.darkSurface)).fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, secondaryButtonSurfaceColor(this.displayMode, this.darkSurface)))
              .onClick((): void => this.load())
          }.width('100%')
          if (this.storageError || this.usage.hasScanFailures()) {
            Text($r('app.string.storage_stats_failed')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.danger')).width('100%')
          }
          this.SummaryCard()
          this.CacheCard()
          this.ChatRetentionCard()
          this.DownloadsCard()
          this.NetworkCard()
        }.width('100%').padding({ left: 16, right: 16, top: this.statusBarHeight + 74, bottom: this.navigationIndicatorHeight + 28 })
      }.width('100%').height('100%').scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    
      }.width('100%').height('100%')
    }
    .scale({ x: this.pageMotion.scale, y: this.pageMotion.scale })
    .opacity(this.pageMotion.opacity)
    .onReady((context: NavDestinationContext): void => { this.pageMotion.attach(context); })
    .systemTransition(pageSystemTransition(this.pageTransitionMode))
    .titleMode(HdsNavDestinationTitleMode.MINI).hideBackButton(false)
    .onBackPressed((): boolean => { ResponsiveLayout.closeContentDestination(this.pageStack); return true; })
    .onShown((): void => { this.refreshLocation(); if (Date.now() - this.lastLoadAt > 1200) { this.load(); } })
    .bindToScrollable([this.scroller])
    .titleBar({ avoidLayoutSafeArea: true, content: { title: { mainTitle: $r('app.string.storage_title') } },
      style: destinationTitleBarStyle(ScrollEffectType.GRADIENT_BLUR, this.displayMode, this.darkSurface, this.titleBarStyleMode) })
    .backgroundColor(pageCanvasColor(this.displayMode, this.darkSurface, this.pageBackgroundValue))
  }
}
