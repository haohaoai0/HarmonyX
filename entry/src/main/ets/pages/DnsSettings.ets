import { common } from '@kit.AbilityKit';
import { HdsNavDestination, HdsNavDestinationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import promptAction from '@ohos.promptAction';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { DnsSettings, dnsSettingsStore } from '../services/DnsSettingsStore';
import { DOH_ALIDNS, DOH_CLOUDFLARE, DOH_GOOGLE, normalizeDohEndpoint } from '../services/DnsOverHttps';
import { STORAGE_KEY_PAGE_TRANSITION_MODE, DEFAULT_PAGE_TRANSITION_MODE } from '../services/PageTransitionSettingsStore';
import { appPageBackground } from '../components/PageBackgroundLayer';
import { destinationTitleBarStyle } from '../utils/DestinationTitleBar';
import { pageSystemTransition, PageTransitionMotion } from '../utils/PageTransition';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';
import { cardSurfaceColor, fieldSurfaceColor, pageCanvasColor, pageReadingSurfaceColor,
  pageTextColor, secondaryButtonSurfaceColor } from '../utils/ThemeColors';

@Builder
export function DnsSettingsBuilder(): void {
  DnsSettingsPage();
}

@Component
export struct DnsSettingsPage {
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp('harmonyx.page_background') private pageBackgroundValue: string = '';
  @StorageProp('harmonyx.display_mode') private displayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private darkSurface: string = '';
  @StorageProp('harmonyx.accent_color') private accentColor: string = '#007DFF';
  @StorageProp('harmonyx.title_bar_style_mode') private titleBarStyleMode: number = 0;
  @StorageProp('harmonyx.status_bar_height') private statusBarHeight: number = 0;
  @StorageProp('harmonyx.navigation_indicator_height') private navigationIndicatorHeight: number = 0;
  @StorageProp(STORAGE_KEY_PAGE_TRANSITION_MODE) private pageTransitionMode: string = DEFAULT_PAGE_TRANSITION_MODE;
  @State private pageMotion: PageTransitionMotion = new PageTransitionMotion();
  @State private dohEnabled: boolean = false;
  @State private endpoint: string = DOH_ALIDNS;
  @State private provider: number = 0;
  @State private testing: boolean = false;
  @State private testResult: string = '';
  private scroller: Scroller = new Scroller();
  private testRevision: number = 0;

  aboutToAppear(): void {
    const settings: DnsSettings = dnsSettingsStore.snapshot();
    this.dohEnabled = settings.enabled;
    this.endpoint = settings.endpoint;
    this.provider = this.endpoint === DOH_ALIDNS ? 0 : this.endpoint === DOH_CLOUDFLARE ? 1 :
      this.endpoint === DOH_GOOGLE ? 2 : 3;
  }

  aboutToDisappear(): void {
    this.testRevision++;
  }

  private text(resource: Resource): string {
    return (getContext(this) as common.UIAbilityContext).resourceManager.getStringSync(resource);
  }

  private providerTitle(): Resource {
    return this.provider === 0 ? $r('app.string.dns_provider_ali') :
      this.provider === 1 ? $r('app.string.dns_provider_cloudflare') :
      this.provider === 2 ? $r('app.string.dns_provider_google') : $r('app.string.dns_provider_custom');
  }

  private invalidateTest(): void {
    this.testRevision++;
    this.testing = false;
    this.testResult = '';
  }

  private selectProvider(index: number): void {
    this.invalidateTest();
    this.provider = index;
    if (index < 3) {
      this.endpoint = index === 0 ? DOH_ALIDNS : index === 1 ? DOH_CLOUDFLARE : DOH_GOOGLE;
    }
  }

  private save(): void {
    if (normalizeDohEndpoint(this.endpoint).length === 0) {
      promptAction.showToast({ message: $r('app.string.dns_invalid'), duration: 2200 });
      return;
    }
    if (!dnsSettingsStore.save(this.dohEnabled, this.endpoint)) {
      promptAction.showToast({ message: $r('app.string.proxy_save_failed'), duration: 2200 });
      return;
    }
    this.endpoint = dnsSettingsStore.snapshot().endpoint;
    promptAction.showToast({ message: $r('app.string.dns_saved'), duration: 2200 });
  }

  private async test(): Promise<void> {
    if (normalizeDohEndpoint(this.endpoint).length === 0) {
      promptAction.showToast({ message: $r('app.string.dns_invalid'), duration: 2200 });
      return;
    }
    const revision: number = ++this.testRevision;
    this.testing = true;
    this.testResult = '';
    const latency: number = await dnsSettingsStore.testEndpoint(this.endpoint);
    if (revision !== this.testRevision) { return; }
    this.testing = false;
    this.testResult = latency >= 0 ? this.text($r('app.string.dns_test_success')) + ' · ' +
      latency.toString() + ' ms' : this.text($r('app.string.dns_test_failed'));
  }

  @Builder
  private Label(value: Resource): void {
    Text(value).fontFamily(this.appFontFamily).fontSize($r('sys.float.Subtitle_L'))
      .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue,
        pageReadingSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue)))
  }

  @Builder
  private Note(value: ResourceStr): void {
    Text(value).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
      .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue,
        pageReadingSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue)))
      .width('100%')
  }

  build(): void {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        appPageBackground()
        Scroll(this.scroller) {
          Column({ space: 16 }) {
            Column({ space: 16 }) {
              Row({ space: 14 }) {
                Column({ space: 6 }) {
                  this.Label($r('app.string.dns_enable'))
                  this.Note($r('app.string.dns_enable_desc'))
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                Toggle({ type: ToggleType.Switch, isOn: this.dohEnabled })
                  .selectedColor(this.accentColor)
                  .onChange((value: boolean): void => { this.dohEnabled = value; })
              }.width('100%')
              this.Note($r('app.string.dns_scope'))
              this.Note($r('app.string.dns_failure_note'))
            }.width('100%').padding(16).borderRadius(16)
              .backgroundColor(pageReadingSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue))

            Column({ space: 12 }) {
              this.Label($r('app.string.dns_provider'))
              Select([
                { value: $r('app.string.dns_provider_ali') },
                { value: $r('app.string.dns_provider_cloudflare') },
                { value: $r('app.string.dns_provider_google') },
                { value: $r('app.string.dns_provider_custom') }
              ]).selected(this.provider).value(this.providerTitle())
                .selectedOptionFontColor(this.accentColor)
                .onSelect((index: number): void => this.selectProvider(index))
              this.Label($r('app.string.dns_endpoint'))
              TextInput({ text: this.endpoint, placeholder: $r('app.string.dns_endpoint_hint') })
                .fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L'))
                .type(InputType.Normal).maxLength(2048).enabled(this.provider === 3)
                .backgroundColor(fieldSurfaceColor(this.displayMode, this.darkSurface))
                .onChange((value: string): void => { this.endpoint = value; this.invalidateTest(); })
              this.Note($r('app.string.dns_endpoint_desc'))
              Button(this.testing ? $r('app.string.proxy_testing') : $r('app.string.dns_test'))
                .width('100%').enabled(!this.testing)
                .backgroundColor(secondaryButtonSurfaceColor(this.displayMode, this.darkSurface))
                .fontColor($r('app.color.text_primary'))
                .onClick((): void => { this.test(); })
              if (this.testResult.length > 0) { this.Note(this.testResult) }
              this.Note($r('app.string.dns_test_desc'))
            }.width('100%').alignItems(HorizontalAlign.Start).padding(16).borderRadius(16)
              .backgroundColor(pageReadingSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue))

            Button($r('app.string.proxy_save')).width('100%')
              .backgroundColor(this.accentColor).fontColor($r('app.color.text_on_accent'))
              .onClick((): void => this.save())
          }.width('100%').padding({ left: 16, right: 16, top: this.statusBarHeight + 74,
            bottom: this.navigationIndicatorHeight + 28 })
        }.width('100%').height('100%').scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      }.width('100%').height('100%')
    }.scale({ x: this.pageMotion.scale, y: this.pageMotion.scale }).opacity(this.pageMotion.opacity)
      .onReady((context: NavDestinationContext): void => { this.pageMotion.attach(context); })
      .systemTransition(pageSystemTransition(this.pageTransitionMode))
      .titleMode(HdsNavDestinationTitleMode.MINI).hideBackButton(false)
      .onBackPressed((): boolean => { ResponsiveLayout.closeContentDestination(this.pageStack); return true; })
      .bindToScrollable([this.scroller])
      .titleBar({ avoidLayoutSafeArea: true, content: { title: { mainTitle: $r('app.string.dns_title') } },
        style: destinationTitleBarStyle(ScrollEffectType.GRADIENT_BLUR,
          this.displayMode, this.darkSurface, this.titleBarStyleMode) })
      .backgroundColor(pageCanvasColor(this.displayMode, this.darkSurface, this.pageBackgroundValue));
  }
}
