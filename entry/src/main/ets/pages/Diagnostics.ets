import { pageBackgroundActive } from '../services/PageBackgroundStore';
import { pageTextColor } from '../utils/ThemeColors';
import { appPageBackground } from '../components/PageBackgroundLayer';
import { pageCanvasColor, pageReadingSurfaceColor } from '../utils/ThemeColors';
import { STORAGE_KEY_PAGE_TRANSITION_MODE, DEFAULT_PAGE_TRANSITION_MODE } from '../services/PageTransitionSettingsStore';
import { pageSystemTransition, PageTransitionMotion } from '../utils/PageTransition';
// Diagnostics: the recent private-interface calls plus the same self-check the
// settings page offers, in one place and with a copyable report.
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import common from '@ohos.app.ability.common';
import { deviceInfo } from '@kit.BasicServicesKit';
import { LengthMetrics, uiMaterial } from '@kit.ArkUI';
import { HdsNavDestination, HdsNavDestinationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import promptAction from '@ohos.promptAction';
import { RequestLogEntry, requestLog } from '../services/RequestLog';
import { XPrivateResult, xPrivateClient } from '../services/XPrivateClient';
import { destinationTitleBarStyle } from '../utils/DestinationTitleBar';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';
import { fieldSurfaceColor, pageSurfaceColor } from '../utils/ThemeColors';
import { materialModifier } from '../utils/SystemMaterial';
import { CrashReport, crashDiagnostics, STORAGE_KEY_CRASH_DIAGNOSTICS } from '../services/CrashDiagnostics';

@Builder
export function DiagnosticsBuilder(): void {
  Diagnostics();
}

@Component
export struct Diagnostics {
  @StorageProp('harmonyx.page_background') private pageBackgroundValue: string = '';
  @State private pageMotion: PageTransitionMotion = new PageTransitionMotion();
  @StorageProp(STORAGE_KEY_PAGE_TRANSITION_MODE) private pageTransitionMode: string = DEFAULT_PAGE_TRANSITION_MODE;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp('harmonyx.status_bar_height') statusBarHeight: number =
    AppStorage.get<number>('harmonyx.status_bar_height') ?? 0;
  @StorageProp('harmonyx.navigation_indicator_height') navigationIndicatorHeight: number =
    AppStorage.get<number>('harmonyx.navigation_indicator_height') ?? 0;
  @StorageLink('harmonyx.accent_color') accentColor: string = '#007DFF';
  @StorageProp('harmonyx.display_mode') private themeDisplayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private themeDarkSurface: string = '';
  @StorageLink('harmonyx.title_bar_style_mode') titleBarStyleMode: number = 0;
  @State private entries: RequestLogEntry[] = [];
  @State private probing: boolean = false;
  @State private probeResult: string = '';
  @StorageProp(STORAGE_KEY_CRASH_DIAGNOSTICS) @Watch('refreshCrashes') private crashRevision: number = 0;
  @State private crashes: CrashReport[] = [];
  @State private exporting: boolean = false;

  aboutToAppear(): void {
    this.refresh();
  }

  private text(resource: Resource): string {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    return context.resourceManager.getStringSync(resource);
  }

  private refresh(): void {
    this.entries = requestLog.snapshot();
    this.refreshCrashes();
  }

  private refreshCrashes(): void { this.crashes = crashDiagnostics.snapshot(); }

  private async exportLogs(): Promise<void> {
    if (this.exporting) { return; }
    this.exporting = true;
    try {
      if (await crashDiagnostics.exportLogs(getContext(this) as common.UIAbilityContext)) {
        this.getUIContext().getPromptAction().showToast({ message: this.text($r('app.string.crash_export_success')) });
      }
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: this.text($r('app.string.crash_export_failed')) });
    } finally { this.exporting = false; }
  }

  private async contactDeveloper(): Promise<void> {
    try { await crashDiagnostics.contactDeveloper(getContext(this) as common.UIAbilityContext); }
    catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: this.text($r('app.string.crash_contact_failed')) });
    }
  }

  @Builder
  private CrashSection(): void {
    Column({ space: 12 }) {
      Text($r('app.string.crash_logs_title')).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Title_S'))
        .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent))
      Text($r('app.string.crash_logs_description')).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_M'))
        .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
      Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(12), cross: LengthMetrics.vp(8) } }) {
        Button(this.exporting ? $r('app.string.status_loading') : $r('app.string.crash_export'))
          .fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_on_accent'))
          .backgroundColor(this.accentColor).enabled(!this.exporting)
          .id('diagnostics-export-logs')
          .onClick((): void => { this.exportLogs(); })
        Button($r('app.string.crash_contact'))
          .fontSize($r('sys.float.Body_M'))
          .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface)))
          .backgroundColor(fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
          .id('diagnostics-contact-developer')
          .onClick((): void => { this.contactDeveloper(); })
      }
      if (this.crashes.length === 0) {
        Text($r('app.string.crash_logs_empty')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M'))
          .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
      }
    }.width('100%').alignItems(HorizontalAlign.Start).padding(16)
  }

  private pageMaterial(): uiMaterial.Material | undefined {
    if (!deviceInfo.apiAvailable('26.0.0')) {
      return undefined;
    }
    return new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.REGULAR,
      applyShadow: true,
      colorInvert: true
    });
  }

  private clock(ms: number): string {
    const date: Date = new Date(ms);
    const hours: number = date.getHours();
    const minutes: number = date.getMinutes();
    const seconds: number = date.getSeconds();
    return (hours < 10 ? '0' + hours : String(hours)) + ':' +
      (minutes < 10 ? '0' + minutes : String(minutes)) + ':' +
      (seconds < 10 ? '0' + seconds : String(seconds));
  }

  private async runProbe(): Promise<void> {
    if (this.probing) {
      return;
    }
    this.probing = true;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    xPrivateClient.load(context);
    this.probeResult = await xPrivateClient.probeTimeline();
    this.probing = false;
    this.refresh();
  }

  @Builder
  private EntryRow(entry: RequestLogEntry): void {
    Row({ space: 10 }) {
      Text(this.clock(entry.time)).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_S'))
        .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
        .width(64)
      Column({ space: 2 }) {
        Text(entry.operation).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M'))
          .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (entry.note.length > 0) {
          Text(entry.note).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_S'))
            .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Text('HTTP ' + entry.status).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_S'))
        .fontColor(entry.ok ? pageTextColor($r('app.color.text_accent'), this.pageBackgroundValue, Color.Transparent) : $r('app.color.danger'))
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
    .alignItems(VerticalAlign.Top)
  }

  build(): void {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        appPageBackground()
      List() {
        ListItem() { this.CrashSection() }
        ForEach(this.crashes, (crash: CrashReport): void => {
          ListItem() {
            Column({ space: 6 }) {
              Text(new Date(crash.time).toLocaleString() + ' · ' + crash.type).fontFamily(this.appFontFamily)
                .fontSize($r('sys.float.Body_M')).fontWeight(FontWeight.Medium)
                .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent))
              Text(crash.text.substring(0, 6000)).fontFamily(this.appFontFamily)
                .fontSize($r('sys.float.Body_S'))
                .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
                .copyOption(CopyOptions.LocalDevice)
            }.width('100%').alignItems(HorizontalAlign.Start).padding(16)
          }
        }, (crash: CrashReport): string => crash.id)
        ListItem() {
          Row({ space: 12 }) {
            Button(this.probing ? $r('app.string.status_loading') :
              $r('app.string.diagnostics_probe'), { stateEffect: true })
              .fontSize($r('sys.float.Body_M'))
              .fontColor($r('app.color.text_on_accent'))
              .backgroundColor(this.accentColor)
              .borderRadius(18)
              .enabled(!this.probing)
              .onClick((): void => {
                this.runProbe();
              })
            Button($r('app.string.diagnostics_clear'), { stateEffect: true })
              .fontSize($r('sys.float.Body_M'))
              .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface)))
              .backgroundColor(fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
              .borderRadius(18)
              .onClick((): void => {
                requestLog.clear();
                this.refresh();
              })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        }
        if (this.probeResult.length > 0) {
          ListItem() {
            Text(this.probeResult).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_S'))
              .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface)))
              .width('100%')
              .padding(12)
              .borderRadius(12)
              .backgroundColor(fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
              .copyOption(CopyOptions.LocalDevice)
          }
          .padding({ left: 16, right: 16, bottom: 8 })
        }
        if (this.entries.length === 0) {
          ListItem() {
            Text($r('app.string.diagnostics_empty')).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_L'))
              .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ top: 40 })
          }
        } else {
          ForEach(this.entries, (entry: RequestLogEntry) => {
            ListItem() {
              this.EntryRow(entry)
            }
          }, (entry: RequestLogEntry) => entry.time.toString() + entry.operation)
        }
      }
      .width('100%')
      .height('100%')
      .divider({ strokeWidth: 1, color: $r('app.color.divider') })
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .contentStartOffset(this.statusBarHeight + 60)
      .contentEndOffset(this.navigationIndicatorHeight + 24)
    
      }.width('100%').height('100%')
    }
    .scale({ x: this.pageMotion.scale, y: this.pageMotion.scale })
    .opacity(this.pageMotion.opacity)
    .onReady((context: NavDestinationContext): void => { this.pageMotion.attach(context); })
    .systemTransition(pageSystemTransition(this.pageTransitionMode))
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .hideBackButton(false)
    .onBackPressed((): boolean => {
      ResponsiveLayout.closeContentDestination(this.pageStack);
      return true;
    })
    .titleBar({
      avoidLayoutSafeArea: true,
      content: { title: { mainTitle: $r('app.string.diagnostics_title') } },
      style: destinationTitleBarStyle(ScrollEffectType.IMMERSIVE_GRADIENT_BLUR,
        this.themeDisplayMode, this.themeDarkSurface, this.titleBarStyleMode)
    })
    .backgroundColor(pageCanvasColor(this.themeDisplayMode, this.themeDarkSurface, this.pageBackgroundValue))
    .attributeModifier(materialModifier(pageBackgroundActive(this.pageBackgroundValue) ? undefined : this.pageMaterial()));
  }
}
