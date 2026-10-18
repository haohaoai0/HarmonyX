import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { DEFAULT_COMPONENT_HDR_ENABLED, DEFAULT_COMPONENT_HDR_RATIO, STORAGE_KEY_COMPONENT_HDR_ENABLED,
  STORAGE_KEY_COMPONENT_HDR_RATIO, componentHdrSettingsStore,
  parseComponentHdrRatio } from '../services/ComponentHdrSettingsStore';
import { ComponentHdrHighlight } from '../utils/ComponentHdrHighlight';
import { fieldSurfaceColor, pageTextColor } from '../utils/ThemeColors';
import { ComponentHdrBrightnessInfo, ComponentHdrBrightnessMonitor } from '../services/ComponentHdrBrightnessMonitor';

@Component
export struct ComponentHdrSettingsContent {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageLink(STORAGE_KEY_COMPONENT_HDR_ENABLED) private componentHdrEnabled: boolean = DEFAULT_COMPONENT_HDR_ENABLED;
  @StorageProp(STORAGE_KEY_COMPONENT_HDR_RATIO) private ratio: number = DEFAULT_COMPONENT_HDR_RATIO;
  @StorageProp('harmonyx.display_mode') private displayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private darkSurface: string = '';
  @StorageProp('harmonyx.page_background') private pageBackgroundValue: string = '';
  @StorageProp('harmonyx.accent_color') private accentColor: string = '#007DFF';
  @State private draft: string = DEFAULT_COMPONENT_HDR_RATIO.toString();
  @State private invalid: boolean = false;
  @State private saveFailed: boolean = false;
  @State private hdrBrightnessInfo: ComponentHdrBrightnessInfo = new ComponentHdrBrightnessInfo();
  private brightnessMonitor: ComponentHdrBrightnessMonitor = new ComponentHdrBrightnessMonitor();
  private observationToken: number = 0;

  aboutToAppear(): void {
    this.draft = this.ratio.toString();
    this.observeBrightness();
  }

  aboutToDisappear(): void {
    this.observationToken++;
    this.brightnessMonitor.stop();
  }

  private async observeBrightness(): Promise<void> {
    const token: number = ++this.observationToken;
    this.hdrBrightnessInfo = new ComponentHdrBrightnessInfo();
    const context: common.Context | undefined = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    try {
      const current: window.Window = await window.getLastWindow(context);
      if (token !== this.observationToken) { return; }
      this.brightnessMonitor.observe(current, (info: ComponentHdrBrightnessInfo): void => {
        this.hdrBrightnessInfo = info;
      });
    } catch (error) {
      if (token === this.observationToken) { this.hdrBrightnessInfo = new ComponentHdrBrightnessInfo(); }
    }
  }

  private updateRatio(text: string): void {
    // Keep the draft as typed, so entering "1." does not remove the decimal point.
    this.draft = text;
    const value: number | null = parseComponentHdrRatio(text);
    this.invalid = value === null;
    this.saveFailed = false;
    if (value === null || value === this.ratio) { return; }
    const context: common.Context | undefined = this.getUIContext().getHostContext();
    this.saveFailed = context === undefined || !componentHdrSettingsStore.save(context, value);
  }

  private setEnabled(value: boolean): void {
    const previous: boolean = this.componentHdrEnabled;
    const context: common.Context | undefined = this.getUIContext().getHostContext();
    if (context === undefined || !componentHdrSettingsStore.saveEnabled(context, value)) {
      this.saveFailed = true;
      return;
    }
    this.saveFailed = false;
    if (previous !== value) { this.componentHdrEnabled = value; }
  }

  build(): void {
    Column({ space: 16 }) {
      Row() {
        Column({ space: 4 }) {
          Text($r('app.string.settings_component_hdr_enabled')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Title_S')).fontWeight(FontWeight.Bold)
            .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent))
          Text($r('app.string.settings_component_hdr_enabled_desc')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M'))
            .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Toggle({ type: ToggleType.Switch, isOn: this.componentHdrEnabled })
          .selectedColor(this.accentColor)
          .accessibilityText($r('app.string.settings_component_hdr_enabled'))
          .id('settings-component-hdr-enabled')
          .onChange((value: boolean): void => this.setEnabled(value))
      }.width('100%').alignItems(VerticalAlign.Center)
      Text($r('app.string.settings_component_hdr_ratio')).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Title_S')).fontWeight(FontWeight.Bold)
        .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent))
        .width('100%')
      Text($r('app.string.settings_component_hdr_desc')).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_M'))
        .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
        .width('100%')
      Column({ space: 6 }) {
        Text($r('app.string.settings_component_hdr_max')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Subtitle_L')).fontWeight(FontWeight.Medium)
          .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent))
        Text(this.hdrBrightnessInfo.available ? this.hdrBrightnessInfo.maxRatio.toFixed(2) + '×' :
          $r('app.string.settings_component_hdr_max_unavailable')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Title_S')).fontWeight(FontWeight.Bold)
          .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent))
          .id('settings-component-hdr-max-value')
        Text($r('app.string.settings_component_hdr_max_desc')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M'))
          .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
      }.width('100%').alignItems(HorizontalAlign.Start)
        .id('settings-component-hdr-max')
      Row({ space: 12 }) {
        TextInput({ text: this.draft }).fontFamily(this.appFontFamily)
          .type(InputType.NUMBER_DECIMAL).enterKeyType(EnterKeyType.Done)
          .keyboardAppearance(KeyboardAppearance.IMMERSIVE)
          .fontSize($r('sys.float.Body_L'))
          .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue,
            fieldSurfaceColor(this.displayMode, this.darkSurface)))
          .backgroundColor(fieldSurfaceColor(this.displayMode, this.darkSurface))
          .enabled(this.componentHdrEnabled)
          .layoutWeight(1).accessibilityText($r('app.string.settings_component_hdr_ratio'))
          .id('settings-component-hdr-input')
          .onChange((text: string): void => this.updateRatio(text))
          .onSubmit((): void => this.updateRatio(this.draft))
        Text('×').fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L'))
          .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
      }.width('100%')
      if (this.invalid || this.saveFailed) {
        Text(this.invalid ? $r('app.string.settings_component_hdr_invalid') : $r('app.string.settings_layout_save_failed'))
          .fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
          .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
          .width('100%')
      }
      SymbolGlyph($r('sys.symbol.square_and_pencil')).fontSize($r('app.float.component_hdr_preview_size'))
        .fontColor([this.accentColor])
        .foregroundFilter(ComponentHdrHighlight.filter(this.getUIContext(), this.componentHdrEnabled, this.ratio))
        .accessibilityLevel('no')
      Button($r('app.string.settings_component_hdr_reset'))
        .onClick((): void => this.updateRatio(DEFAULT_COMPONENT_HDR_RATIO.toString()))
        .id('settings-component-hdr-reset')
    }.width('100%').alignItems(HorizontalAlign.Start)
      .padding({ left: 20, right: 20, top: 16, bottom: 28 })
      .onVisibleAreaChange([0, 1], (visible: boolean): void => {
        if (visible) { this.brightnessMonitor.refresh(); }
      })
  }
}
