// Network proxy management for the app's HTTP clients. The page mirrors the
// proxy workflow of the reference client while adding multiple saved servers,
// HTTP authentication, latency checks, SOCKS5 on API 26, and failover.
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { common } from '@kit.AbilityKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { uiMaterial } from '@kit.ArkUI';
import {
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  ScrollEffectType
} from '@kit.UIDesignKit';
import promptAction from '@ohos.promptAction';
import {
  PROXY_TYPE_HTTP,
  PROXY_TYPE_SOCKS5,
  ProxyEntry,
  ProxySettings,
  proxyStore
} from '../services/ProxyStore';
import { destinationTitleBarStyle } from '../utils/DestinationTitleBar';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';
import {
  cardSurfaceColor,
  fieldSurfaceColor,
  pageSurfaceColor,
  secondaryButtonSurfaceColor
} from '../utils/ThemeColors';

@Builder
export function ProxySettingsBuilder(): void {
  ProxySettingsPage();
}

@Component
export struct ProxySettingsPage {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp('harmonyx.status_bar_height') statusBarHeight: number =
    AppStorage.get<number>('harmonyx.status_bar_height') ?? 0;
  @StorageProp('harmonyx.navigation_indicator_height') navigationIndicatorHeight: number =
    AppStorage.get<number>('harmonyx.navigation_indicator_height') ?? 0;
  @StorageLink('harmonyx.accent_color') accentColor: string = '#007DFF';
  @StorageProp('harmonyx.display_mode') private displayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private darkSurface: string = '';
  @StorageLink('harmonyx.title_bar_style_mode') titleBarStyleMode: number = 0;
  @State private proxies: ProxyEntry[] = [];
  @State private activeProxyId: string = '';
  @State private proxyEnabled: boolean = false;
  @State private autoSwitch: boolean = true;
  @State private videoCdnProxyEnabled: boolean = false;
  @State private editorVisible: boolean = false;
  @State private editingId: string = '';
  @State private editorName: string = '';
  @State private editorType: string = PROXY_TYPE_HTTP;
  @State private editorHost: string = '';
  @State private editorPort: string = '8080';
  @State private editorUsername: string = '';
  @State private editorPassword: string = '';
  @State private editorExclusions: string = '';
  @State private testingId: string = '';
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.loadSettings();
  }

  private text(resource: Resource): string {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    return context.resourceManager.getStringSync(resource);
  }

  private loadSettings(): void {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const settings: ProxySettings = proxyStore.load(context);
    this.proxies = settings.proxies;
    this.activeProxyId = settings.activeProxyId;
    this.proxyEnabled = settings.enabled;
    this.autoSwitch = settings.autoSwitch;
    this.videoCdnProxyEnabled = settings.videoCdnProxyEnabled;
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

  private activeProxyName(): string {
    for (let i: number = 0; i < this.proxies.length; i++) {
      if (this.proxies[i].id === this.activeProxyId) {
        return this.proxies[i].displayName();
      }
    }
    return this.text($r('app.string.proxy_none'));
  }

  private setEnabled(value: boolean): void {
    if (value && this.proxies.length === 0) {
      this.beginAdd();
      return;
    }
    if (!proxyStore.setEnabled(value)) {
      promptAction.showToast({ message: $r('app.string.proxy_save_failed'), duration: 1800 });
      return;
    }
    this.loadSettings();
  }

  private setAutoSwitch(value: boolean): void {
    if (!proxyStore.setAutoSwitch(value)) {
      promptAction.showToast({ message: $r('app.string.proxy_save_failed'), duration: 1800 });
      return;
    }
    this.loadSettings();
  }

  private setVideoCdnProxyEnabled(value: boolean): void {
    if (value && this.proxies.length === 0) {
      promptAction.showToast({ message: $r('app.string.proxy_video_requires_server'), duration: 2200 });
      return;
    }
    if (!proxyStore.setVideoCdnProxyEnabled(value)) {
      promptAction.showToast({ message: $r('app.string.proxy_save_failed'), duration: 1800 });
      return;
    }
    this.loadSettings();
  }

  private activate(proxy: ProxyEntry): void {
    if (!proxyStore.setActive(proxy.id)) {
      promptAction.showToast({ message: $r('app.string.proxy_save_failed'), duration: 1800 });
      return;
    }
    this.loadSettings();
  }

  private beginAdd(): void {
    this.editorVisible = true;
    this.editingId = '';
    this.editorName = '';
    this.editorType = PROXY_TYPE_HTTP;
    this.editorHost = '';
    this.editorPort = '8080';
    this.editorUsername = '';
    this.editorPassword = '';
    this.editorExclusions = '';
  }

  private beginEdit(proxy: ProxyEntry): void {
    this.editorVisible = true;
    this.editingId = proxy.id;
    this.editorName = proxy.name;
    this.editorType = proxy.type;
    this.editorHost = proxy.host;
    this.editorPort = proxy.port.toString();
    this.editorUsername = proxy.username;
    this.editorPassword = proxy.password;
    this.editorExclusions = proxy.exclusionList;
  }

  private cancelEdit(): void {
    this.editorVisible = false;
    this.editingId = '';
  }

  private saveEditor(): void {
    const port: number = Number(this.editorPort.trim());
    if (this.editorHost.trim().length === 0 || port <= 0 || port >= 65536 ||
      Math.floor(port) !== port) {
      promptAction.showToast({ message: $r('app.string.proxy_invalid'), duration: 2200 });
      return;
    }
    if (this.editorType === PROXY_TYPE_SOCKS5 && !proxyStore.supportedSocks5()) {
      promptAction.showToast({ message: $r('app.string.proxy_socks5_unsupported'), duration: 2600 });
      return;
    }
    const entry: ProxyEntry = new ProxyEntry(
      this.editingId,
      this.editorName,
      this.editorType,
      this.editorHost,
      port,
      this.editorUsername,
      this.editorPassword,
      this.editorExclusions
    );
    const saved: ProxyEntry | null = proxyStore.upsert(entry);
    if (saved === null) {
      promptAction.showToast({ message: $r('app.string.proxy_save_failed'), duration: 1800 });
      return;
    }
    this.loadSettings();
    if (this.proxies.length === 1 && !this.proxyEnabled) {
      proxyStore.setEnabled(true);
      this.loadSettings();
    }
    this.editorVisible = false;
    this.editingId = '';
    promptAction.showToast({ message: $r('app.string.proxy_saved'), duration: 1600 });
  }

  private remove(proxy: ProxyEntry): void {
    if (!proxyStore.remove(proxy.id)) {
      promptAction.showToast({ message: $r('app.string.proxy_save_failed'), duration: 1800 });
      return;
    }
    if (this.editingId === proxy.id) {
      this.cancelEdit();
    }
    this.loadSettings();
    promptAction.showToast({ message: $r('app.string.proxy_removed'), duration: 1600 });
  }

  private async test(proxy: ProxyEntry): Promise<void> {
    if (this.testingId.length > 0) {
      return;
    }
    this.testingId = proxy.id;
    const latency: number = await proxyStore.testLatency(proxy);
    proxyStore.updateLatency(proxy.id, latency);
    this.testingId = '';
    this.loadSettings();
  }

  private latencyText(proxy: ProxyEntry): string {
    if (this.testingId === proxy.id) {
      return this.text($r('app.string.proxy_testing'));
    }
    if (proxy.latencyMs < 0) {
      return this.text($r('app.string.proxy_untested'));
    }
    return proxy.latencyMs.toString() + ' ms';
  }

  private typeIndex(): number {
    return this.editorType === PROXY_TYPE_SOCKS5 ? 1 : 0;
  }

  private selectType(index: number): void {
    this.editorType = index === 1 ? PROXY_TYPE_SOCKS5 : PROXY_TYPE_HTTP;
  }

  @Builder
  private FieldLabel(label: Resource): void {
    Text(label).fontFamily(this.appFontFamily)
      .fontSize($r('sys.float.Body_M'))
      .fontColor($r('app.color.text_secondary'))
      .width('100%')
  }

  @Builder
  private ProxyFieldInput(label: Resource, placeholder: Resource, value: string,
    password: boolean, onChange: (value: string) => void): void {
    Column({ space: 6 }) {
      this.FieldLabel(label)
      TextInput({ placeholder: placeholder, text: value }).fontFamily(this.appFontFamily)
        .keyboardAppearance(KeyboardAppearance.IMMERSIVE)
        .type(password ? InputType.Password : InputType.Normal)
        .width('100%')
        .height(46)
        .fontSize($r('sys.float.Body_L'))
        .backgroundColor(fieldSurfaceColor(this.displayMode, this.darkSurface))
        .borderRadius(12)
        .padding({ left: 14, right: 14 })
        .onChange((next: string): void => onChange(next))
    }
    .width('100%')
  }

  @Builder
  private Editor(): void {
    Column({ space: 12 }) {
      Row({ space: 12 }) {
        Text(this.editingId.length > 0 ? $r('app.string.proxy_edit') : $r('app.string.proxy_add')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Title_S'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Button($r('app.string.proxy_cancel'), { stateEffect: true })
          .backgroundColor(secondaryButtonSurfaceColor(this.displayMode, this.darkSurface))
          .fontColor($r('app.color.text_primary'))
          .onClick((): void => this.cancelEdit())
      }
      .width('100%')

      this.ProxyFieldInput($r('app.string.proxy_name'), $r('app.string.proxy_name_hint'),
        this.editorName, false,
        (value: string): void => {
          this.editorName = value;
        })

      Column({ space: 6 }) {
        this.FieldLabel($r('app.string.proxy_type'))
        Select([
          { value: $r('app.string.proxy_type_http') },
          { value: $r('app.string.proxy_type_socks5') }
        ])
          .selected(this.typeIndex())
          .value(this.editorType === PROXY_TYPE_SOCKS5 ?
            $r('app.string.proxy_type_socks5') : $r('app.string.proxy_type_http'))
          .selectedOptionFontColor(this.accentColor)
          .selectedOptionBgColor(fieldSurfaceColor(this.displayMode, this.darkSurface))
          .onSelect((index: number): void => this.selectType(index))
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      if (this.editorType === PROXY_TYPE_SOCKS5 && !proxyStore.supportedSocks5()) {
        Text($r('app.string.proxy_socks5_unsupported')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('app.color.danger'))
          .width('100%')
      }

      this.ProxyFieldInput($r('app.string.proxy_host'), $r('app.string.proxy_host_hint'),
        this.editorHost, false,
        (value: string): void => {
          this.editorHost = value;
        })
      this.ProxyFieldInput($r('app.string.proxy_port'), $r('app.string.proxy_port_hint'),
        this.editorPort, false,
        (value: string): void => {
          this.editorPort = value;
        })
      this.ProxyFieldInput($r('app.string.proxy_username'), $r('app.string.proxy_optional'),
        this.editorUsername, false,
        (value: string): void => {
          this.editorUsername = value;
        })
      this.ProxyFieldInput($r('app.string.proxy_password'), $r('app.string.proxy_optional'),
        this.editorPassword, true,
        (value: string): void => {
          this.editorPassword = value;
        })
      this.ProxyFieldInput($r('app.string.proxy_exclusions'), $r('app.string.proxy_exclusions_hint'),
        this.editorExclusions, false,
        (value: string): void => {
          this.editorExclusions = value;
        })

      Button($r('app.string.proxy_save'), { stateEffect: true })
        .width('100%')
        .backgroundColor(this.accentColor)
        .fontColor($r('app.color.text_on_accent'))
        .onClick((): void => this.saveEditor())
    }
    .width('100%')
    .padding(16)
    .borderRadius(16)
    .backgroundColor(cardSurfaceColor(this.displayMode, this.darkSurface))
    .border({ width: 1, color: $r('app.color.divider') })
  }

  @Builder
  private ProxyCard(proxy: ProxyEntry): void {
    Column({ space: 12 }) {
      Row({ space: 10 }) {
        Column({ space: 3 }) {
          Row({ space: 8 }) {
            Text(proxy.displayName()).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Subtitle_L'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
            if (proxy.id === this.activeProxyId) {
              Text($r('app.string.proxy_active')).fontFamily(this.appFontFamily)
                .fontSize($r('sys.float.Body_S'))
                .fontColor($r('app.color.text_on_accent'))
                .backgroundColor(this.accentColor)
                .borderRadius(8)
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            }
          }
          .width('100%')
          Text((proxy.isSocks5() ? 'SOCKS5' : 'HTTP') + '  ·  ' +
            proxy.host + ':' + proxy.port.toString()).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.latencyText(proxy)).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_S'))
            .fontColor(proxy.latencyMs >= 0 ? $r('app.color.text_accent') :
              $r('app.color.text_secondary'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        if (this.proxyEnabled && proxy.id === this.activeProxyId) {
          SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
            .fontSize(22)
            .fontColor([this.accentColor])
        } else {
          SymbolGlyph($r('sys.symbol.circle'))
            .fontSize(22)
            .fontColor([$r('app.color.text_secondary')])
        }
      }
      .width('100%')
      .onClick((): void => this.activate(proxy))

      Row({ space: 8 }) {
        Button($r('app.string.proxy_test'), { stateEffect: true })
          .layoutWeight(1)
          .backgroundColor(secondaryButtonSurfaceColor(this.displayMode, this.darkSurface))
          .fontColor($r('app.color.text_primary'))
          .enabled(this.testingId.length === 0)
          .onClick((): void => {
            this.test(proxy);
          })
        Button($r('app.string.proxy_edit'), { stateEffect: true })
          .layoutWeight(1)
          .backgroundColor(secondaryButtonSurfaceColor(this.displayMode, this.darkSurface))
          .fontColor($r('app.color.text_primary'))
          .onClick((): void => this.beginEdit(proxy))
        Button($r('app.string.proxy_delete'), { stateEffect: true })
          .layoutWeight(1)
          .backgroundColor(secondaryButtonSurfaceColor(this.displayMode, this.darkSurface))
          .fontColor($r('app.color.danger'))
          .onClick((): void => this.remove(proxy))
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .borderRadius(16)
    .backgroundColor(this.proxyEnabled && proxy.id === this.activeProxyId ?
      fieldSurfaceColor(this.displayMode, this.darkSurface) :
      cardSurfaceColor(this.displayMode, this.darkSurface))
    .border({
      width: this.proxyEnabled && proxy.id === this.activeProxyId ? 2 : 1,
      color: this.proxyEnabled && proxy.id === this.activeProxyId ?
        this.accentColor : $r('app.color.divider')
    })
  }

  build(): void {
    HdsNavDestination() {
      Scroll(this.scroller) {
        Column({ space: 16 }) {
          Column({ space: 12 }) {
            Row({ space: 14 }) {
              Column({ space: 4 }) {
                Text($r('app.string.proxy_enable')).fontFamily(this.appFontFamily)
                  .fontSize($r('sys.float.Subtitle_L'))
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary'))
                Text(this.proxyEnabled ? this.activeProxyName() : $r('app.string.proxy_direct')).fontFamily(this.appFontFamily)
                  .fontSize($r('sys.float.Body_M'))
                  .fontColor($r('app.color.text_secondary'))
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
              Toggle({ type: ToggleType.Switch, isOn: this.proxyEnabled })
                .selectedColor(this.accentColor)
                .onChange((value: boolean): void => this.setEnabled(value))
            }
            .width('100%')

            Row({ space: 14 }) {
              Column({ space: 4 }) {
                Text($r('app.string.proxy_auto_switch')).fontFamily(this.appFontFamily)
                  .fontSize($r('sys.float.Subtitle_L'))
                  .fontColor($r('app.color.text_primary'))
                Text($r('app.string.proxy_auto_switch_desc')).fontFamily(this.appFontFamily)
                  .fontSize($r('sys.float.Body_M'))
                  .fontColor($r('app.color.text_secondary'))
                  .maxLines(3)
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
              Toggle({ type: ToggleType.Switch, isOn: this.autoSwitch })
                .selectedColor(this.accentColor)
                .onChange((value: boolean): void => this.setAutoSwitch(value))
            }
            .width('100%')

            Row({ space: 14 }) {
              Column({ space: 4 }) {
                Text($r('app.string.proxy_video_cdn')).fontFamily(this.appFontFamily)
                  .fontSize($r('sys.float.Subtitle_L'))
                  .fontColor($r('app.color.text_primary'))
                Text($r('app.string.proxy_video_cdn_desc')).fontFamily(this.appFontFamily)
                  .fontSize($r('sys.float.Body_M'))
                  .fontColor($r('app.color.text_secondary'))
                  .maxLines(4)
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
              Toggle({ type: ToggleType.Switch, isOn: this.videoCdnProxyEnabled })
                .selectedColor(this.accentColor)
                .onChange((value: boolean): void => this.setVideoCdnProxyEnabled(value))
            }
            .width('100%')

            Text($r('app.string.proxy_scope_note')).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_M'))
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
          }
          .width('100%')
          .padding(16)
          .borderRadius(16)
          .backgroundColor(cardSurfaceColor(this.displayMode, this.darkSurface))
          .border({ width: 1, color: $r('app.color.divider') })

          if (this.editorVisible) {
            this.Editor()
          }

          Row({ space: 12 }) {
            Text($r('app.string.proxy_saved_servers')).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Title_S'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .layoutWeight(1)
            Button($r('app.string.proxy_add'), { stateEffect: true })
              .backgroundColor(this.accentColor)
              .fontColor($r('app.color.text_on_accent'))
              .onClick((): void => this.beginAdd())
          }
          .width('100%')

          if (this.proxies.length === 0) {
            Column({ space: 10 }) {
              SymbolGlyph($r('sys.symbol.link'))
                .fontSize(30)
                .fontColor([$r('app.color.text_secondary')])
              Text($r('app.string.proxy_empty')).fontFamily(this.appFontFamily)
                .fontSize($r('sys.float.Body_L'))
                .fontColor($r('app.color.text_secondary'))
                .textAlign(TextAlign.Center)
            }
            .width('100%')
            .padding(24)
          } else {
            ForEach(this.proxies, (proxy: ProxyEntry): void => {
              this.ProxyCard(proxy)
            }, (proxy: ProxyEntry): string => proxy.id + proxy.latencyMs.toString())
          }
        }
        .width('100%')
        .padding({
          left: 16,
          right: 16,
          top: this.statusBarHeight + 74,
          bottom: this.navigationIndicatorHeight + 28
        })
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    }
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .hideBackButton(false)
    .onBackPressed((): boolean => {
      ResponsiveLayout.closeContentDestination(this.pageStack);
      return true;
    })
    .bindToScrollable([this.scroller])
    .titleBar({
      avoidLayoutSafeArea: true,
      content: { title: { mainTitle: $r('app.string.settings_proxy') } },
      style: destinationTitleBarStyle(ScrollEffectType.GRADIENT_BLUR,
        this.displayMode, this.darkSurface, this.titleBarStyleMode)
    })
    .backgroundColor(pageSurfaceColor(this.displayMode, this.darkSurface))
    .systemMaterial(this.pageMaterial());
  }
}
