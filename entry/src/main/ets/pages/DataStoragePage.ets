import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { common } from '@kit.AbilityKit';
import { HdsNavDestination, HdsNavDestinationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { promptAction } from '@kit.ArkUI';
import {
  AppStorageUsage, AppNetworkUsage, StorageFileUsage, StorageCacheKind, StorageClearResult,
  getAppStorageUsage, getAppNetworkUsage, clearAppCache, storageBytes
} from '../services/DataStorageService';
import { downloadLocationStore } from '../services/DownloadLocationStore';
import { destinationTitleBarStyle } from '../utils/DestinationTitleBar';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';
import { cardSurfaceColor, pageSurfaceColor, secondaryButtonSurfaceColor } from '../utils/ThemeColors';

@Builder
export function DataStorageBuilder(): void { DataStoragePage(); }

@Component
export struct DataStoragePage {
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
  @State private folderPath: string = '';
  @State private folderSupported: boolean = false;
  @State private folderAuthorized: boolean = false;
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
    this.folderSupported = downloadLocationStore.supportsDirectory();
    this.folderPath = downloadLocationStore.path(this.context());
    this.folderAuthorized = downloadLocationStore.hasDirectory(this.context());
    this.useFolder = downloadLocationStore.useDownloads(this.context());
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

  private chooseDirectory(): void {
    if (this.busy) { return; }
    this.busy = true;
    downloadLocationStore.chooseDirectory(this.context()).then((changed: boolean): void => {
      if (changed && this.active) { this.refreshLocation(); promptAction.showToast({ message: $r('app.string.storage_directory_changed') }); }
    }).catch((): void => { promptAction.showToast({ message: $r('app.string.storage_directory_failed') }); })
      .finally((): void => { this.busy = false; });
  }

  private changeSaveTarget(enabled: boolean): void {
    if (this.busy) { return; }
    this.useFolder = enabled; this.busy = true;
    const prepared: Promise<boolean> = enabled ? downloadLocationStore.prepare(this.context()) : Promise.resolve(true);
    prepared.then((ready: boolean): Promise<void> => {
      return ready ? downloadLocationStore.setUseDownloads(this.context(), enabled) : Promise.resolve();
    }).catch((): void => { promptAction.showToast({ message: $r('app.string.storage_directory_failed') }); })
      .finally((): void => { this.refreshLocation(); this.busy = false; });
  }

  private confirmClear(kind: StorageCacheKind, bytes: number): void {
    if (this.busy || this.loading || !this.loaded) { return; }
    promptAction.showDialog({
      title: $r('app.string.storage_clear_title'),
      message: this.context().resourceManager.getStringSync($r('app.string.storage_clear_confirm'), storageBytes(bytes)),
      buttons: [{ text: $r('app.string.storage_cancel'), color: this.color($r('app.color.text_secondary')) },
        { text: $r('app.string.storage_clear_action'), color: this.color($r('app.color.brand')) }]
    }).then((response: promptAction.ShowDialogSuccessResponse): void => {
      if (response.index !== 1 || this.busy || !this.active) { return; }
      this.busy = true; this.sequence++;
      clearAppCache(this.context(), kind).then((result: StorageClearResult): void => {
        const message: string = this.context().resourceManager.getStringSync(
          result.failures > 0 ? $r('app.string.storage_clear_partial') : $r('app.string.storage_clear_done'), storageBytes(result.freedBytes));
        promptAction.showToast({ message: message, duration: 2400 });
      }).catch((): void => { promptAction.showToast({ message: $r('app.string.storage_clear_failed') }); })
        .finally((): void => { this.busy = false; if (this.active) { this.load(); } });
    });
  }

  @Builder
  private ValueRow(label: Resource, value: string): void {
    Row({ space: 12 }) {
      Text(label).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary')).layoutWeight(1)
      Text(value).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_primary'))
    }.width('100%')
  }

  @Builder
  private SummaryCard(): void {
    Column({ space: 14 }) {
      Text($r('app.string.storage_local_usage')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary')).width('100%')
      Text(this.loaded && this.usage.systemAvailable ? storageBytes(this.usage.totalBytes()) : this.text($r('app.string.storage_unavailable'))).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Title_L')).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary')).width('100%')
      this.ValueRow($r('app.string.storage_package'), this.usage.systemAvailable ? storageBytes(this.usage.appBytes) : '—')
      this.ValueRow($r('app.string.storage_app_data'), this.usage.systemAvailable ? storageBytes(this.usage.dataBytes) : '—')
      this.ValueRow($r('app.string.storage_free_space'), this.usage.freeBytes >= 0 ? storageBytes(this.usage.freeBytes) : '—')
      Text($r('app.string.storage_total_note')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Caption_M')).fontColor($r('app.color.text_secondary')).width('100%')
    }.width('100%').padding(16).borderRadius(16).backgroundColor(cardSurfaceColor(this.displayMode, this.darkSurface))
  }

  @Builder
  private CacheCategory(title: Resource, usage: StorageFileUsage, kind: StorageCacheKind): void {
    Column({ space: 8 }) {
      Row({ space: 12 }) {
        Text(title).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_primary')).layoutWeight(1)
        Text(this.loaded ? storageBytes(usage.bytes) : '—').fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary'))
      }.width('100%')
      Row({ space: 12 }) {
        Text(this.context().resourceManager.getStringSync($r('app.string.storage_file_count'), usage.count)).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Caption_M')).fontColor($r('app.color.text_secondary')).layoutWeight(1)
        Button($r('app.string.storage_clear_action'))
          .fontSize($r('sys.float.Body_M')).backgroundColor(secondaryButtonSurfaceColor(this.displayMode, this.darkSurface))
          .fontColor($r('app.color.text_primary')).enabled(this.loaded && usage.count > 0 && !this.busy && !this.loading)
          .onClick((): void => this.confirmClear(kind, usage.bytes))
      }.width('100%')
    }.width('100%').padding({ top: 8, bottom: 8 })
  }

  @Builder
  private CacheCard(): void {
    Column({ space: 12 }) {
      this.ValueRow($r('app.string.storage_clearable'), this.loaded ? storageBytes(this.usage.clearableBytes()) : '—')
      this.CacheCategory($r('app.string.storage_video_cache'), this.usage.video, StorageCacheKind.VIDEO)
      Divider().color($r('app.color.divider'))
      this.CacheCategory($r('app.string.storage_chat_cache'), this.usage.chat, StorageCacheKind.CHAT)
      Divider().color($r('app.color.divider'))
      this.CacheCategory($r('app.string.storage_timeline_cache'), this.usage.timeline, StorageCacheKind.TIMELINE)
      Text($r('app.string.storage_clear_note')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Caption_M')).fontColor($r('app.color.text_secondary')).width('100%')
      Button($r('app.string.storage_clear_all')).width('100%')
        .backgroundColor(secondaryButtonSurfaceColor(this.displayMode, this.darkSurface)).fontColor($r('app.color.text_primary'))
        .enabled(this.loaded && this.usage.clearableBytes() > 0 && !this.busy && !this.loading)
        .onClick((): void => this.confirmClear(StorageCacheKind.ALL, this.usage.clearableBytes()))
    }.width('100%').padding(16).borderRadius(16).backgroundColor(cardSurfaceColor(this.displayMode, this.darkSurface))
  }

  @Builder
  private DownloadsCard(): void {
    Column({ space: 12 }) {
      Text($r('app.string.storage_download_path')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Subtitle_L')).fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary')).width('100%')
      Text(this.folderSupported ? this.folderPath : $r('app.string.storage_system_save')).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary')).copyOption(CopyOptions.LocalDevice).width('100%')
      Text(this.folderSupported ? (this.folderAuthorized ? $r('app.string.storage_path_note') : $r('app.string.storage_path_authorize')) :
        $r('app.string.storage_folder_fallback')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Caption_M')).fontColor($r('app.color.text_secondary')).width('100%')
      Button($r('app.string.storage_change_path')).width('100%')
        .backgroundColor(secondaryButtonSurfaceColor(this.displayMode, this.darkSurface)).fontColor($r('app.color.text_primary'))
        .enabled(this.folderSupported && !this.busy).onClick((): void => this.chooseDirectory())
      Row({ space: 12 }) {
        Column({ space: 5 }) {
          Text($r('app.string.storage_save_to_folder')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_primary'))
          Text($r('app.string.storage_save_target_note')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Caption_M')).fontColor($r('app.color.text_secondary'))
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Toggle({ type: ToggleType.Switch, isOn: this.useFolder }).enabled(this.folderSupported && !this.busy)
          .onChange((enabled: boolean): void => this.changeSaveTarget(enabled))
      }.width('100%')
      this.ValueRow($r('app.string.storage_download_files'), this.loaded ? storageBytes(this.usage.downloads.bytes) : '—')
      this.ValueRow($r('app.string.storage_other_cache'), this.loaded ? storageBytes(this.usage.otherCacheBytes()) : '—')
      Text($r('app.string.storage_protected_note')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Caption_M')).fontColor($r('app.color.text_secondary')).width('100%')
      Button($r('app.string.download_tasks_title')).width('100%')
        .backgroundColor(secondaryButtonSurfaceColor(this.displayMode, this.darkSurface)).fontColor($r('app.color.text_primary'))
        .onClick((): void => { this.pageStack.pushPath({ name: 'DownloadManager', param: '' }); })
    }.width('100%').padding(16).borderRadius(16).backgroundColor(cardSurfaceColor(this.displayMode, this.darkSurface))
  }

  @Builder
  private NetworkCard(): void {
    Column({ space: 14 }) {
      Text($r('app.string.storage_network_title')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Subtitle_L')).fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary')).width('100%')
      this.ValueRow($r('app.string.storage_network_received'), this.networkAvailable ? storageBytes(this.network.received) : '—')
      this.ValueRow($r('app.string.storage_network_sent'), this.networkAvailable ? storageBytes(this.network.sent) : '—')
      Text(this.networkAvailable ? $r('app.string.storage_network_note') : $r('app.string.storage_network_unavailable')).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Caption_M')).fontColor($r('app.color.text_secondary')).width('100%')
    }.width('100%').padding(16).borderRadius(16).backgroundColor(cardSurfaceColor(this.displayMode, this.darkSurface))
  }

  build(): void {
    HdsNavDestination() {
      Scroll(this.scroller) {
        Column({ space: 16 }) {
          Row({ space: 12 }) {
            if (this.loading || this.busy) { LoadingProgress().width(22).height(22).color($r('app.color.brand')) }
            Text(this.busy ? $r('app.string.storage_processing') : (this.loading ? $r('app.string.storage_loading') :
              $r('app.string.storage_stats_note'))).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary')).layoutWeight(1)
            Button($r('app.string.storage_refresh')).enabled(!this.busy && !this.loading)
              .backgroundColor(secondaryButtonSurfaceColor(this.displayMode, this.darkSurface)).fontColor($r('app.color.text_primary'))
              .onClick((): void => this.load())
          }.width('100%')
          if (this.storageError || this.usage.hasScanFailures()) {
            Text($r('app.string.storage_stats_failed')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.danger')).width('100%')
          }
          this.SummaryCard()
          this.CacheCard()
          this.DownloadsCard()
          this.NetworkCard()
        }.width('100%').padding({ left: 16, right: 16, top: this.statusBarHeight + 74, bottom: this.navigationIndicatorHeight + 28 })
      }.width('100%').height('100%').scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    }
    .titleMode(HdsNavDestinationTitleMode.MINI).hideBackButton(false)
    .onBackPressed((): boolean => { ResponsiveLayout.closeContentDestination(this.pageStack); return true; })
    .onShown((): void => { this.refreshLocation(); if (Date.now() - this.lastLoadAt > 1200) { this.load(); } })
    .bindToScrollable([this.scroller])
    .titleBar({ avoidLayoutSafeArea: true, content: { title: { mainTitle: $r('app.string.storage_title') } },
      style: destinationTitleBarStyle(ScrollEffectType.GRADIENT_BLUR, this.displayMode, this.darkSurface, this.titleBarStyleMode) })
    .backgroundColor(pageSurfaceColor(this.displayMode, this.darkSurface))
  }
}
