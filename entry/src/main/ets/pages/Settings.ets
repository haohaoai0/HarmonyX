// Settings destinations use the same shared NavPathStack as post detail.
// Keeping sidebar callbacks here makes the drawer structure reusable, as in
// PaperTalk, while each settings group remains a real child page.
import { uiMaterial } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import promptAction from '@ohos.promptAction';
import router from '@ohos.router';
import {
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  hdsMaterial,
  ScrollEffectType
} from '@kit.UIDesignKit';
import {
  AppearanceSettings,
  AppearanceStore,
  DEFAULT_ACCENT_COLOR,
  DEFAULT_FONT_SCALE,
  DISPLAY_MODE_DARK,
  DISPLAY_MODE_LIGHT,
  DISPLAY_MODE_SYSTEM
} from '../services/AppearanceStore';
import {
  APP_LANGUAGE_EN,
  APP_LANGUAGE_ZH_CN,
  DEFAULT_APP_LANGUAGE,
  LanguageStore
} from '../services/LanguageStore';
import { GripHandManager } from '../utils/GripHandManager';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';
import { OAuthConfigStore, XDeveloperConfig } from '../services/OAuthConfig';
import { authStore } from '../services/AuthStore';
import { oauthFlowStore } from '../services/OAuthFlowStore';
import { REDIRECT_URI } from '../services/XApiClient';

export interface SettingsRouteParam {
  section: string;
}

@Builder
export function SettingsBuilder(): void {
  SettingsHome();
}

@Builder
export function SettingsSectionBuilder(): void {
  SettingsSection();
}

@Component
struct SettingsRow {
  @Prop icon: Resource = $r('sys.symbol.gearshape');
  @Prop title: Resource = $r('app.string.settings_title');
  @Prop detail: Resource = $r('app.string.settings_display_desc');
  onRowClick: () => void = (): void => {};

  build(): void {
    Row({ space: 16 }) {
      SymbolGlyph(this.icon)
        .fontSize(25)
        .fontColor([$r('app.color.text_secondary')])
        .width(32)
      Column({ space: 4 }) {
        Text(this.title)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Text(this.detail)
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(15)
        .fontColor([$r('app.color.text_secondary')])
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 16, bottom: 16 })
    .onClick((): void => this.onRowClick())
  }
}

@Component
export struct SettingsHome {
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp('harmonyx.status_bar_height') statusBarHeight: number =
    AppStorage.get<number>('harmonyx.status_bar_height') ?? 0;
  @StorageProp('harmonyx.navigation_indicator_height') navigationIndicatorHeight: number =
    AppStorage.get<number>('harmonyx.navigation_indicator_height') ?? 0;
  private scroller: Scroller = new Scroller();
  @StorageLink('harmonyx.accent_color') accentColor: string = DEFAULT_ACCENT_COLOR;

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

  private inputMaterial(): uiMaterial.Material | undefined {
    if (!deviceInfo.apiAvailable('26.0.0')) {
      return undefined;
    }
    return new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.THIN,
      interactive: true,
      applyShadow: true,
      colorInvert: true,
      lightEffect: { color: this.accentColor }
    });
  }

  private open(section: string): void {
    const param: SettingsRouteParam = { section: section };
    this.pageStack.pushPath({ name: 'SettingsSection', param: param });
  }

  build(): void {
    HdsNavDestination() {
      Scroll(this.scroller) {
        Column({ space: 4 }) {
          Search({ placeholder: $r('app.string.settings_search') })
            .width('100%')
            .height(44)
            .margin({ top: this.statusBarHeight + 76, bottom: 12 })
            .backgroundColor($r('app.color.bg_field'))
            .systemMaterial(this.inputMaterial())
          SettingsRow({
            icon: $r('sys.symbol.person'),
            title: $r('app.string.settings_account'),
            detail: $r('app.string.settings_account_desc'),
            onRowClick: (): void => this.open('account')
          })
          SettingsRow({
            icon: $r('sys.symbol.link'),
            title: $r('app.string.settings_api_title'),
            detail: $r('app.string.settings_api_desc'),
            onRowClick: (): void => this.open('developer_api')
          })
          SettingsRow({
            icon: $r('sys.symbol.lock'),
            title: $r('app.string.settings_security'),
            detail: $r('app.string.settings_security_desc'),
            onRowClick: (): void => this.open('security')
          })
          SettingsRow({
            icon: $r('sys.symbol.seal_shield_fill'),
            title: $r('app.string.settings_privacy'),
            detail: $r('app.string.settings_privacy_desc'),
            onRowClick: (): void => this.open('privacy')
          })
          SettingsRow({
            icon: $r('sys.symbol.bell'),
            title: $r('app.string.settings_notifications'),
            detail: $r('app.string.settings_notifications_desc'),
            onRowClick: (): void => this.open('notifications')
          })
          SettingsRow({
            icon: $r('sys.symbol.display'),
            title: $r('app.string.settings_accessibility'),
            detail: $r('app.string.settings_accessibility_desc'),
            onRowClick: (): void => this.open('accessibility')
          })
          SettingsRow({
            icon: $r('sys.symbol.link'),
            title: $r('app.string.settings_resources'),
            detail: $r('app.string.settings_resources_desc'),
            onRowClick: (): void => this.open('resources')
          })
        }
        .width('100%')
        .padding({ left: 12, right: 12, bottom: this.navigationIndicatorHeight + 28 })
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Auto)
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
      content: { title: { mainTitle: $r('app.string.settings_title') } },
      style: {
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.IMMERSIVE,
          materialLevel: hdsMaterial.MaterialLevel.EXQUISITE
        }
      }
    })
    .backgroundColor($r('app.color.bg_page'))
    .systemMaterial(this.pageMaterial());
  }
}

@Component
export struct SettingsSection {
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp('harmonyx.status_bar_height') statusBarHeight: number =
    AppStorage.get<number>('harmonyx.status_bar_height') ?? 0;
  @StorageProp('harmonyx.navigation_indicator_height') navigationIndicatorHeight: number =
    AppStorage.get<number>('harmonyx.navigation_indicator_height') ?? 0;
  @State section: string = 'accessibility';
  @StorageLink('harmonyx.display_mode') displayMode: string = DISPLAY_MODE_SYSTEM;
  @StorageLink('harmonyx.accent_color') accentColor: string = DEFAULT_ACCENT_COLOR;
  @StorageLink('harmonyx.font_scale') fontScale: number = DEFAULT_FONT_SCALE;
  @StorageLink('harmonyx.grip_hand_enabled') gripHandEnabled: boolean = true;
  @StorageLink('harmonyx.app_language') appLanguage: string = DEFAULT_APP_LANGUAGE;
  @State notificationsEnabled: boolean = true;
  @State apiClientId: string = '';
  private scroller: Scroller = new Scroller();
  private appearanceStore: AppearanceStore = new AppearanceStore();
  private languageStore: LanguageStore = new LanguageStore();
  private gripHandManager: GripHandManager = GripHandManager.getInstance();
  private oauthConfigStore: OAuthConfigStore = new OAuthConfigStore();

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

  aboutToAppear(): void {
    this.loadGripHandPreference();
    this.loadLanguagePreference();
    this.loadDeveloperApiConfiguration();
    setTimeout((): void => {
      const params: SettingsRouteParam[] = this.pageStack.getParamByName('SettingsSection') as SettingsRouteParam[];
      if (params !== undefined && params !== null && params.length > 0) {
        this.section = params[params.length - 1].section;
      }
    }, 30);
  }

  private loadLanguagePreference(): void {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    this.appLanguage = this.languageStore.load(context);
  }

  private loadDeveloperApiConfiguration(): void {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const config: XDeveloperConfig = this.oauthConfigStore.load(context);
    this.apiClientId = config.clientId;
  }

  private async saveDeveloperApiConfiguration(): Promise<void> {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const previous: XDeveloperConfig = this.oauthConfigStore.load(context);
    const nextClientId: string = this.apiClientId.trim();
    const saved: boolean = this.oauthConfigStore.save(context, nextClientId);
    if (!saved) {
      promptAction.showToast({ message: this.text($r('app.string.settings_api_save_failed')), duration: 2500 });
      return;
    }
    this.apiClientId = nextClientId;
    if (previous.clientId !== nextClientId) {
      await authStore.signOut(context);
      await oauthFlowStore.clear(context);
      promptAction.showToast({ message: this.text($r('app.string.settings_api_saved')), duration: 2000 });
      router.pushUrl({ url: 'pages/Login' });
      return;
    }
    promptAction.showToast({ message: this.text($r('app.string.settings_api_saved')), duration: 2000 });
  }

  private text(resource: Resource): string {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    return context.resourceManager.getStringSync(resource);
  }

  private async loadGripHandPreference(): Promise<void> {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    await this.gripHandManager.load(context);
    this.gripHandEnabled = this.gripHandManager.isGripHandEnabled();
  }

  private setGripHandEnabled(value: boolean): void {
    this.gripHandEnabled = value;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    this.gripHandManager.saveGripHandEnabled(context, value);
  }

  private title(): Resource {
    if (this.section === 'display') {
      return $r('app.string.settings_display');
    }
    if (this.section === 'account') {
      return $r('app.string.settings_account');
    }
    if (this.section === 'security') {
      return $r('app.string.settings_security');
    }
    if (this.section === 'privacy') {
      return $r('app.string.settings_privacy');
    }
    if (this.section === 'notifications') {
      return $r('app.string.settings_notifications');
    }
    if (this.section === 'resources') {
      return $r('app.string.settings_resources');
    }
    if (this.section === 'developer_api') {
      return $r('app.string.settings_api_title');
    }
    if (this.section === 'language') {
      return $r('app.string.settings_language');
    }
    return $r('app.string.settings_accessibility');
  }

  @Builder
  private SimpleItem(title: Resource, detail: Resource, onClick: () => void = (): void => {}): void {
    Row() {
      Column({ space: 4 }) {
        Text(title).fontSize(17).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
        Text(detail).fontSize(14).fontColor($r('app.color.text_secondary')).maxLines(2)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(15).fontColor([$r('app.color.text_secondary')])
    }
    .width('100%')
    .padding({ top: 16, bottom: 16, left: 20, right: 20 })
    .onClick((): void => onClick())
  }

  private saveAppearance(): void {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const settings: AppearanceSettings = new AppearanceSettings(this.displayMode, this.accentColor, this.fontScale);
    this.appearanceStore.save(context, settings);
  }

  private selectDisplayMode(mode: string): void {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    try {
      context.getApplicationContext().setColorMode(this.appearanceStore.colorMode(mode));
      this.displayMode = mode;
      this.saveAppearance();
    } catch (error) {
      // Keep the currently rendered color mode when the system rejects a change.
    }
  }

  private selectAccent(color: string): void {
    this.accentColor = color;
    this.saveAppearance();
  }

  private openDisplay(): void {
    const param: SettingsRouteParam = { section: 'display' };
    this.pageStack.pushPath({ name: 'SettingsSection', param: param });
  }

  private openLanguage(): void {
    const param: SettingsRouteParam = { section: 'language' };
    this.pageStack.pushPath({ name: 'SettingsSection', param: param });
  }

  private selectLanguage(language: string): void {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    try {
      context.getApplicationContext().setLanguage(language);
      this.appLanguage = language;
      this.languageStore.save(context, language);
    } catch (error) {
      // Retain the current language if the system declines the configuration change.
    }
  }

  private scaledFont(size: number): number {
    return Math.round(size * this.fontScale * 10) / 10;
  }

  @Builder
  private DisplayModeOption(mode: string, icon: Resource, label: Resource): void {
    Column({ space: 8 }) {
      SymbolGlyph(icon)
        .fontSize(28)
        .fontColor([this.displayMode === mode ? this.accentColor : $r('app.color.text_primary')])
      Text(label)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
    }
    .width(96)
    .height(92)
    .justifyContent(FlexAlign.Center)
    .borderRadius(18)
    .backgroundColor(this.displayMode === mode ? $r('app.color.bg_field') : $r('app.color.bg_card'))
    .border({ width: this.displayMode === mode ? 2 : 1,
      color: this.displayMode === mode ? this.accentColor : $r('app.color.divider') })
    .onClick((): void => this.selectDisplayMode(mode))
  }

  @Builder
  private AccentOption(color: string): void {
    Stack({ alignContent: Alignment.Center }) {
      if (this.accentColor === color) {
        Circle({ width: 38, height: 38 }).fill(Color.Transparent)
          .stroke(this.accentColor).strokeWidth(3)
      }
      Circle({ width: 30, height: 30 }).fill(color)
    }
    .width(42)
    .height(42)
    .onClick((): void => this.selectAccent(color))
  }

  @Builder
  private DisplayContent(): void {
    Column({ space: 18 }) {
      Text($r('app.string.settings_display_intro'))
        .fontSize(this.scaledFont(16))
        .lineHeight(this.scaledFont(23))
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
      Row({ space: 10 }) {
        this.DisplayModeOption(DISPLAY_MODE_SYSTEM, $r('sys.symbol.phone'), $r('app.string.settings_theme_system'))
        this.DisplayModeOption(DISPLAY_MODE_LIGHT, $r('sys.symbol.sun_max'), $r('app.string.settings_theme_light'))
        this.DisplayModeOption(DISPLAY_MODE_DARK, $r('sys.symbol.moon'), $r('app.string.settings_theme_dark'))
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      Divider().color($r('app.color.divider'))
      Text($r('app.string.settings_font_size'))
        .fontSize(this.scaledFont(20))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
      Text($r('app.string.settings_font_preview'))
        .fontSize(this.scaledFont(17))
        .lineHeight(this.scaledFont(25))
        .fontColor($r('app.color.text_primary'))
        .width('100%')
      Row({ space: 10 }) {
        Text('Aa').fontSize(14).fontColor($r('app.color.text_secondary'))
        Slider({ value: this.fontScale, min: 0.85, max: 1.35, step: 0.1, style: SliderStyle.InSet })
          .layoutWeight(1)
          .selectedColor(this.accentColor)
          .showTips(true)
          .onChange((value: number): void => {
            this.fontScale = value;
            this.saveAppearance();
          })
        Text('Aa').fontSize(24).fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      Divider().color($r('app.color.divider'))
      Text($r('app.string.settings_theme_color'))
        .fontSize(this.scaledFont(20))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
      Row({ space: 2 }) {
        this.AccentOption('#007DFF')
        this.AccentOption('#1D9BF0')
        this.AccentOption('#F7B500')
        this.AccentOption('#F91880')
        this.AccentOption('#7856FF')
        this.AccentOption('#FF7A00')
        this.AccentOption('#00BA7C')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 20, bottom: 28 })
  }

  @Builder
  private AccessibilityContent(): void {
    Text($r('app.string.settings_accessibility_intro'))
      .fontSize(15)
      .fontColor($r('app.color.text_secondary'))
      .width('100%')
      .padding({ left: 20, right: 20, top: 20, bottom: 8 })
    this.SimpleItem($r('app.string.settings_a11y'), $r('app.string.settings_a11y_desc'))
    this.SimpleItem($r('app.string.settings_display'), $r('app.string.settings_display_desc'),
      (): void => this.openDisplay())
    Row({ space: 16 }) {
      SymbolGlyph($r('sys.symbol.hand_raised_fingers_spread'))
        .fontSize(25)
        .fontColor([this.accentColor])
        .width(32)
      Column({ space: 4 }) {
        Text($r('app.string.settings_grip_hand'))
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Text($r('app.string.settings_grip_hand_desc'))
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .maxLines(2)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Toggle({ type: ToggleType.Switch, isOn: this.gripHandEnabled })
        .selectedColor(this.accentColor)
        .onChange((value: boolean): void => this.setGripHandEnabled(value))
    }
    .width('100%')
    .padding({ top: 16, bottom: 16, left: 20, right: 20 })
    this.SimpleItem($r('app.string.settings_language'), $r('app.string.settings_language_desc'),
      (): void => this.openLanguage())
  }

  @Builder
  private LanguageOption(language: string, title: Resource, detail: Resource): void {
    Row({ space: 14 }) {
      Column({ space: 4 }) {
        Text(title)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Text(detail)
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      if (this.appLanguage === language) {
        SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
          .fontSize(23)
          .fontColor([this.accentColor])
      }
    }
    .width('100%')
    .padding({ top: 18, bottom: 18, left: 20, right: 20 })
    .onClick((): void => this.selectLanguage(language))
  }

  @Builder
  private LanguageContent(): void {
    Column({ space: 0 }) {
      Text($r('app.string.settings_language_intro'))
        .fontSize(15)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .padding({ left: 20, right: 20, top: 20, bottom: 8 })
      this.LanguageOption(APP_LANGUAGE_ZH_CN, $r('app.string.settings_language_zh_cn'),
        $r('app.string.settings_language_zh_cn_desc'))
      Divider().color($r('app.color.divider'))
      this.LanguageOption(APP_LANGUAGE_EN, $r('app.string.settings_language_en'),
        $r('app.string.settings_language_en_desc'))
    }
    .width('100%')
  }

  @Builder
  private DeveloperApiContent(): void {
    Column({ space: 16 }) {
      Text($r('app.string.settings_api_intro'))
        .fontSize(15)
        .lineHeight(22)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
      Text($r('app.string.settings_api_client_id'))
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
      TextInput({ placeholder: $r('app.string.settings_api_client_id_placeholder'), text: this.apiClientId })
        .width('100%')
        .height(48)
        .fontSize(16)
        .backgroundColor($r('app.color.bg_field'))
        .borderRadius(12)
        .padding({ left: 14, right: 14 })
        .onChange((value: string): void => {
          this.apiClientId = value;
        })
      this.CopyableApiAddress(
        $r('app.string.settings_api_developer_portal'),
        this.text($r('app.string.settings_api_developer_url')),
        $r('app.string.settings_api_developer_url_hint'))
      this.CopyableApiAddress(
        $r('app.string.settings_api_redirect_uri'),
        REDIRECT_URI,
        $r('app.string.settings_api_redirect_uri_hint'))
      Text($r('app.string.settings_api_secret_note'))
        .fontSize(14)
        .lineHeight(21)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
      Button($r('app.string.settings_api_save'), { stateEffect: true })
        .width('100%')
        .backgroundColor(this.accentColor)
        .fontColor($r('app.color.text_on_brand'))
        .onClick((): void => {
          this.saveDeveloperApiConfiguration();
        })
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 20, bottom: 28 })
  }

  @Builder
  private CopyableApiAddress(title: Resource, address: string, hint: Resource): void {
    Column({ space: 8 }) {
      Text(title)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.link'))
          .fontSize(18)
          .fontColor([this.accentColor])
        Text(address)
          .layoutWeight(1)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.accentColor)
          .copyOption(CopyOptions.LocalDevice)
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 13, bottom: 13 })
      .backgroundColor($r('app.color.bg_field'))
      .border({ width: 1, color: this.accentColor })
      .borderRadius(12)
      Text(hint)
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
    }
    .width('100%')
  }

  @Builder
  private GenericContent(): void {
    if (this.section === 'notifications') {
      Row() {
        Column({ space: 4 }) {
          Text($r('app.string.settings_push')).fontSize(17).fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
          Text($r('app.string.settings_push_desc')).fontSize(14).fontColor($r('app.color.text_secondary'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Toggle({ type: ToggleType.Switch, isOn: this.notificationsEnabled })
          .selectedColor(this.accentColor)
          .onChange((value: boolean): void => { this.notificationsEnabled = value; })
      }
      .width('100%')
      .padding(20)
    }
    this.SimpleItem($r('app.string.settings_general_one'), $r('app.string.settings_general_one_desc'))
    this.SimpleItem($r('app.string.settings_general_two'), $r('app.string.settings_general_two_desc'))
    this.SimpleItem($r('app.string.settings_general_three'), $r('app.string.settings_general_three_desc'))
  }

  build(): void {
    HdsNavDestination() {
      Scroll(this.scroller) {
        Column({ space: 0 }) {
          if (this.section === 'display') {
            this.DisplayContent()
          } else if (this.section === 'accessibility') {
            this.AccessibilityContent()
          } else if (this.section === 'language') {
            this.LanguageContent()
          } else if (this.section === 'developer_api') {
            this.DeveloperApiContent()
          } else {
            this.GenericContent()
          }
        }
        .width('100%')
        .padding({ top: this.statusBarHeight + 74, bottom: this.navigationIndicatorHeight + 28 })
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Auto)
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
      content: { title: { mainTitle: this.title() } },
      style: {
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.IMMERSIVE,
          materialLevel: hdsMaterial.MaterialLevel.EXQUISITE
        }
      }
    })
    .backgroundColor($r('app.color.bg_page'))
    .systemMaterial(this.pageMaterial());
  }
}
