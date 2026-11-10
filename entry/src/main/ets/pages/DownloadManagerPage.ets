import { pageTextColor } from '../utils/ThemeColors';
import { appPageBackground } from '../components/PageBackgroundLayer';
import { pageCanvasColor, pageReadingSurfaceColor } from '../utils/ThemeColors';
import { STORAGE_KEY_PAGE_TRANSITION_MODE, DEFAULT_PAGE_TRANSITION_MODE } from '../services/PageTransitionSettingsStore';
import { pageSystemTransition, PageTransitionMotion } from '../utils/PageTransition';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { common } from '@kit.AbilityKit';
import {
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  ScrollEffectType
} from '@kit.UIDesignKit';
import promptAction from '@ohos.promptAction';
import {
  DownloadTask,
  DownloadTaskStatus,
  downloadManager
} from '../services/DownloadManager';
import {
  MEDIA_DOWNLOAD_CANCELED,
  MEDIA_DOWNLOAD_FAILED,
  MEDIA_DOWNLOAD_SUCCESS,
  mediaDownloadService
} from '../services/MediaDownloadService';
import { videoPlaybackCache } from '../services/VideoPlaybackCache';
import { downloadLocationStore, MediaSaveMethod } from '../services/DownloadLocationStore';
import { StorageCacheKind, StorageClearResult, clearAppCache, storageBytes } from '../services/DataStorageService';
import { destinationTitleBarStyle } from '../utils/DestinationTitleBar';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';
import { cardSurfaceColor, pageSurfaceColor, secondaryButtonSurfaceColor } from '../utils/ThemeColors';

@Builder
export function DownloadManagerBuilder(): void {
  DownloadManagerPage();
}

@Component
export struct DownloadManagerPage {
  @StorageProp('harmonyx.page_background') private pageBackgroundValue: string = '';
  @State private pageMotion: PageTransitionMotion = new PageTransitionMotion();
  @StorageProp(STORAGE_KEY_PAGE_TRANSITION_MODE) private pageTransitionMode: string = DEFAULT_PAGE_TRANSITION_MODE;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp('harmonyx.display_mode') private displayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private darkSurface: string = '';
  @StorageLink('harmonyx.title_bar_style_mode') titleBarStyleMode: number = 0;
  @StorageProp('harmonyx.status_bar_height') statusBarHeight: number =
    AppStorage.get<number>('harmonyx.status_bar_height') ?? 0;
  @StorageProp('harmonyx.navigation_indicator_height') navigationIndicatorHeight: number =
    AppStorage.get<number>('harmonyx.navigation_indicator_height') ?? 0;
  @StorageProp('harmonyx.download_revision') @Watch('refreshTasks') private downloadRevision: number = 0;
  @StorageProp('harmonyx.video_cache_revision') @Watch('refreshCache') private videoCacheRevision: number = 0;
  @State private tasks: DownloadTask[] = [];
  @State private videoCacheSize: number = 0;
  @State private savingTaskId: string = '';
  @State private clearingCache: boolean = false;
  @State private saveToFolder: boolean = false;
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.refreshTasks();
    this.refreshCache();
    this.saveToFolder = downloadLocationStore.useDownloads(this.context());
  }

  private context(): common.UIAbilityContext {
    return getContext(this) as common.UIAbilityContext;
  }

  private text(resource: Resource): string {
    return this.context().resourceManager.getStringSync(resource);
  }
  private color(resource: Resource): string {
    return '#' + (this.context().resourceManager.getColorSync(resource) >>> 0).toString(16).padStart(8, '0');
  }

  private refreshTasks(): void {
    this.tasks = downloadManager.getTasks(this.context());
  }

  private refreshCache(): void {
    this.videoCacheSize = videoPlaybackCache.getCacheSize(this.context());
  }

  private clearVideoCache(): void {
    if (this.clearingCache) { return; }
    promptAction.showDialog({ title: $r('app.string.storage_clear_title'),
      message: this.context().resourceManager.getStringSync($r('app.string.storage_clear_confirm'), storageBytes(this.videoCacheSize)),
      buttons: [{ text: $r('app.string.storage_cancel'), color: this.color($r('app.color.text_secondary')) },
        { text: $r('app.string.storage_clear_action'), color: this.color($r('app.color.brand')) }]
    }).then((response: promptAction.ShowDialogSuccessResponse): void => {
      if (response.index !== 1 || this.clearingCache) { return; }
      this.clearingCache = true;
      clearAppCache(this.context(), StorageCacheKind.VIDEO).then((result: StorageClearResult): void => {
        this.refreshCache();
        promptAction.showToast({ message: this.context().resourceManager.getStringSync(
          result.failures > 0 ? $r('app.string.storage_clear_partial') : $r('app.string.storage_clear_done'), storageBytes(result.freedBytes)) });
      }).catch((): void => { promptAction.showToast({ message: $r('app.string.storage_clear_failed') }); })
        .finally((): void => { this.clearingCache = false; });
    });
  }

  private operate(task: DownloadTask, forceDownloads: boolean = false): void {
    if (this.savingTaskId.length > 0) { return; }
    const context: common.UIAbilityContext = this.context();
    if (task.status === DownloadTaskStatus.DOWNLOADING || task.status === DownloadTaskStatus.QUEUED) {
      downloadManager.pause(task.id, context);
      return;
    }
    if (task.status === DownloadTaskStatus.PAUSED || task.status === DownloadTaskStatus.FAILED) {
      downloadManager.resume(task.id, context);
      return;
    }
    if (task.status === DownloadTaskStatus.READY_TO_SAVE) {
      this.savingTaskId = task.id;
      mediaDownloadService.saveTask(context, task.id, (result: number): void => {
        this.savingTaskId = '';
        if (result === MEDIA_DOWNLOAD_SUCCESS) {
          const savedMessage: Resource = task.isVideo ? $r('app.string.media_video_saved') :
            $r('app.string.media_image_saved');
          promptAction.showToast({ message: this.text(savedMessage), duration: 1800 });
        } else if (result === MEDIA_DOWNLOAD_CANCELED) {
          promptAction.showToast({ message: this.text($r('app.string.media_download_canceled')), duration: 1800 });
        } else {
          promptAction.showToast({ message: this.text($r('app.string.media_download_failed')), duration: 2200 });
        }
      }, forceDownloads);
    }
  }

  private deleteTask(task: DownloadTask): void {
    downloadManager.delete(task.id, this.context());
  }

  private statusText(task: DownloadTask): Resource {
    if (task.status === DownloadTaskStatus.QUEUED) {
      return $r('app.string.download_status_queued');
    }
    if (task.status === DownloadTaskStatus.DOWNLOADING) {
      return $r('app.string.download_status_downloading');
    }
    if (task.status === DownloadTaskStatus.PAUSED) {
      return $r('app.string.download_status_paused');
    }
    if (task.status === DownloadTaskStatus.READY_TO_SAVE) {
      return $r('app.string.download_status_ready');
    }
    if (task.status === DownloadTaskStatus.COMPLETED) {
      return $r('app.string.download_status_completed');
    }
    return $r('app.string.download_status_failed');
  }

  private progressPercent(task: DownloadTask): number {
    if (task.totalBytes <= 0) {
      return 0;
    }
    return Math.max(0, Math.min(100, Math.floor(task.receivedBytes * 100 / task.totalBytes)));
  }

  private formatCacheSize(): string {
    const megabytes: number = this.videoCacheSize / (1024 * 1024);
    return megabytes.toFixed(1) + ' ' + this.text($r('app.string.download_cache_unit_mb'));
  }

  private formatTaskSize(task: DownloadTask): string {
    const receivedMb: number = task.receivedBytes / (1024 * 1024);
    if (task.totalBytes <= 0) {
      return receivedMb.toFixed(1) + ' ' + this.text($r('app.string.download_cache_unit_mb'));
    }
    const totalMb: number = task.totalBytes / (1024 * 1024);
    return receivedMb.toFixed(1) + ' / ' + totalMb.toFixed(1) + ' ' +
      this.text($r('app.string.download_cache_unit_mb'));
  }

  private actionText(task: DownloadTask): Resource {
    if (task.status === DownloadTaskStatus.DOWNLOADING || task.status === DownloadTaskStatus.QUEUED) {
      return $r('app.string.download_pause');
    }
    if (task.status === DownloadTaskStatus.PAUSED || task.status === DownloadTaskStatus.FAILED) {
      return $r('app.string.download_resume');
    }
    if (downloadLocationStore.method(this.context()) === MediaSaveMethod.FILE_PICKER) {
      return $r('app.string.media_save_file_picker');
    }
    return this.saveToFolder ? (downloadLocationStore.supportsDirectory() ?
      $r('app.string.storage_save_to_remembered') : $r('app.string.storage_save_to_downloads')) :
      $r('app.string.download_save_to_gallery');
  }

  private hasAction(task: DownloadTask): boolean {
    return task.status !== DownloadTaskStatus.COMPLETED;
  }

  @Builder
  private TaskCard(task: DownloadTask): void {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        Column({ space: 5 }) {
          Text(task.title + '.' + task.extension).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Subtitle_L'))
            .fontWeight(FontWeight.Medium)
            .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, pageReadingSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue)))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.statusText(task)).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M'))
            .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, pageReadingSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue)))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Text(this.progressPercent(task).toString() + '%').fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M'))
          .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, pageReadingSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue)))
      }
      .width('100%')

      Progress({ value: this.progressPercent(task), total: 100 })
        .width('100%')
        .visibility(task.status === DownloadTaskStatus.COMPLETED ? Visibility.None : Visibility.Visible)

      Row({ space: 10 }) {
        Text(this.formatTaskSize(task)).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, pageReadingSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue)))
          .layoutWeight(1)
        if (this.hasAction(task)) {
          Button(this.actionText(task))
            .backgroundColor(secondaryButtonSurfaceColor(this.displayMode, this.darkSurface))
            .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, secondaryButtonSurfaceColor(this.displayMode, this.darkSurface)))
            .enabled(this.savingTaskId.length === 0)
            .onClick((): void => this.operate(task))
        }
        Button($r('app.string.download_delete'))
          .backgroundColor(secondaryButtonSurfaceColor(this.displayMode, this.darkSurface))
          .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, secondaryButtonSurfaceColor(this.displayMode, this.darkSurface)))
          .enabled(this.savingTaskId.length === 0)
          .onClick((): void => this.deleteTask(task))
      }
      .width('100%')
      if (task.status === DownloadTaskStatus.READY_TO_SAVE && !this.saveToFolder) {
        Button($r('app.string.storage_save_to_downloads')).width('100%')
          .backgroundColor(secondaryButtonSurfaceColor(this.displayMode, this.darkSurface))
          .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, secondaryButtonSurfaceColor(this.displayMode, this.darkSurface))).enabled(this.savingTaskId.length === 0)
          .onClick((): void => this.operate(task, true))
      }
    }
    .width('100%')
    .padding(16)
    .borderRadius(16)
    .backgroundColor(pageReadingSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue))
    .border({ width: 1, color: $r('app.color.divider') })
  }

  build(): void {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        appPageBackground()
      Scroll(this.scroller) {
        Column({ space: 16 }) {
          Column({ space: 10 }) {
            Text($r('app.string.download_background_note')).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_M'))
              .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, pageReadingSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue)))
              .width('100%')
            Text($r('app.string.download_background_limit')).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Caption_M'))
              .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, pageReadingSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue)))
              .width('100%')
          }
          .width('100%')
          .padding(16)
          .borderRadius(16)
          .backgroundColor(pageReadingSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue))

          Column({ space: 12 }) {
            Row({ space: 10 }) {
              Column({ space: 4 }) {
                Text($r('app.string.download_cache_title')).fontFamily(this.appFontFamily)
                  .fontSize($r('sys.float.Subtitle_L'))
                  .fontWeight(FontWeight.Medium)
                  .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, pageReadingSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue)))
                Text($r('app.string.download_cache_desc')).fontFamily(this.appFontFamily)
                  .fontSize($r('sys.float.Body_M'))
                  .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, pageReadingSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue)))
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
              Text(this.formatCacheSize()).fontFamily(this.appFontFamily)
                .fontSize($r('sys.float.Body_M'))
                .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, pageReadingSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue)))
            }
            .width('100%')
            Button($r('app.string.download_cache_clear'))
              .width('100%')
              .backgroundColor(secondaryButtonSurfaceColor(this.displayMode, this.darkSurface))
              .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, secondaryButtonSurfaceColor(this.displayMode, this.darkSurface)))
              .enabled(!this.clearingCache)
              .onClick((): void => this.clearVideoCache())
            Button($r('app.string.storage_title')).width('100%')
              .backgroundColor(secondaryButtonSurfaceColor(this.displayMode, this.darkSurface))
              .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, secondaryButtonSurfaceColor(this.displayMode, this.darkSurface)))
              .onClick((): void => { this.pageStack.pushPath({ name: 'DataStorage', param: '' }); })
          }
          .width('100%')
          .padding(16)
          .borderRadius(16)
          .backgroundColor(pageReadingSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue))
          .border({ width: 1, color: $r('app.color.divider') })

          Row() {
            Text($r('app.string.download_tasks_title')).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Title_S'))
              .fontWeight(FontWeight.Bold)
              .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent))
          }
          .width('100%')

          if (this.tasks.length === 0) {
            Column({ space: 10 }) {
              SymbolGlyph($r('sys.symbol.download'))
                .fontSize(34)
                .fontColor([pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)])
              Text($r('app.string.download_tasks_empty')).fontFamily(this.appFontFamily)
                .fontSize($r('sys.float.Body_L'))
                .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
            }
            .width('100%')
            .padding({ top: 28, bottom: 28 })
          } else {
            ForEach(this.tasks, (task: DownloadTask): void => {
              this.TaskCard(task)
            }, (task: DownloadTask): string => task.id)
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: this.statusBarHeight + 74,
          bottom: this.navigationIndicatorHeight + 28 })
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    
      }.width('100%').height('100%')
    }
    .scale({ x: this.pageMotion.scale, y: this.pageMotion.scale })
    .opacity(this.pageMotion.opacity)
    .onReady((context: NavDestinationContext): void => { this.pageMotion.attach(context); })
    .systemTransition(pageSystemTransition(this.pageTransitionMode))
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .hideBackButton(false)
    .onShown((): void => {
      this.refreshTasks(); this.refreshCache(); this.saveToFolder = downloadLocationStore.useDownloads(this.context());
    })
    .onBackPressed((): boolean => {
      ResponsiveLayout.closeContentDestination(this.pageStack);
      return true;
    })
    .bindToScrollable([this.scroller])
    .titleBar({
      avoidLayoutSafeArea: true,
      content: { title: { mainTitle: $r('app.string.download_manager_title') } },
      style: destinationTitleBarStyle(ScrollEffectType.GRADIENT_BLUR, this.displayMode,
        this.darkSurface, this.titleBarStyleMode)
    })
    .backgroundColor(pageCanvasColor(this.displayMode, this.darkSurface, this.pageBackgroundValue))
  }
}
