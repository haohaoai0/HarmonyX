import { common } from '@kit.AbilityKit';
import { i18n } from '@kit.LocalizationKit';
import { translationStore, TranslationSettings, STORAGE_KEY_TRANSLATION_OPTIONS_REQUEST,
  STORAGE_KEY_TRANSLATION_OPTIONS_LANGUAGE } from '../services/TranslationStore';
import { normalizeTranslationLanguage, sameTranslationLanguage, TRANSLATION_MODE_WEB } from '../models/Translation';
import { supportedAppLanguages, AppLanguageOption } from '../services/LanguageStore';
import { effectiveAppLocale } from '../utils/AppLocale';
import { NavigationGuard } from '../utils/NavigationGuard';
import type { SettingsRouteParam } from '../pages/Settings';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { sheetMaterialOptions } from '../utils/SheetMaterial';
import { DEFAULT_SHEET_MATERIAL_ENABLED, DEFAULT_SHEET_MATERIAL_LEVEL,
  STORAGE_KEY_SHEET_MATERIAL_ENABLED, STORAGE_KEY_SHEET_MATERIAL_LEVEL } from '../services/SheetMaterialSettingsStore';
import { pageSurfaceColor } from '../utils/ThemeColors';

// The root owns this sheet so changing auto-translation may remove the source
// card's translation without dismissing its settings halfway through an edit.
@Component
export struct PostTranslationOptionsHost {
  @Consume('pageStack') private pageStack: NavPathStack;
  @StorageProp(STORAGE_KEY_TRANSLATION_OPTIONS_REQUEST) @Watch('openOptions') private request: number = 0;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp('harmonyx.accent_color') private accent: string = '#007DFF';
  @StorageProp('harmonyx.display_mode') private displayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private darkSurface: string = '';
  @StorageProp('harmonyx.navigation_indicator_height') private bottomInset: number = 0;
  @StorageProp(STORAGE_KEY_SHEET_MATERIAL_ENABLED) private materialEnabled: boolean = DEFAULT_SHEET_MATERIAL_ENABLED;
  @StorageProp(STORAGE_KEY_SHEET_MATERIAL_LEVEL) private materialLevel: number = DEFAULT_SHEET_MATERIAL_LEVEL;
  @State private open: boolean = false;
  @State private choosingLanguages: boolean = false;
  @State private autoEnabled: boolean = false;
  @State private canAutoTranslate: boolean = false;
  @State private excluded: string = '';
  @State private sourceLanguage: string = '';
  private languages: AppLanguageOption[] = supportedAppLanguages();

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private refresh(): void {
    const settings: TranslationSettings = translationStore.load(this.context());
    this.autoEnabled = settings.autoTranslate;
    this.excluded = settings.autoTranslateExcludedLanguages;
    this.canAutoTranslate = settings.isRunnable() && settings.mode !== TRANSLATION_MODE_WEB;
  }

  private openOptions(): void {
    this.sourceLanguage = normalizeTranslationLanguage(AppStorage.get<string>(STORAGE_KEY_TRANSLATION_OPTIONS_LANGUAGE) ?? '');
    this.refresh(); this.choosingLanguages = false; this.open = true;
  }

  private allowed(language: string): boolean {
    return !this.excluded.split(',').some((tag: string): boolean => sameTranslationLanguage(tag, language));
  }

  private saveAutomatic(enabled: boolean): void {
    const settings: TranslationSettings = translationStore.load(this.context());
    settings.autoTranslate = enabled;
    translationStore.save(this.context(), settings); this.refresh();
  }

  private saveLanguage(language: string, allowed: boolean, enableAutomatic: boolean = false): void {
    const settings: TranslationSettings = translationStore.load(this.context());
    const tags: string[] = settings.autoTranslateExcludedLanguages.split(',').filter((tag: string): boolean =>
      tag.length > 0 && !sameTranslationLanguage(tag, language));
    if (!allowed) { tags.push(language); }
    settings.autoTranslateExcludedLanguages = tags.join(',');
    if (allowed && enableAutomatic) { settings.autoTranslate = true; }
    translationStore.save(this.context(), settings); this.refresh();
  }

  private sourceTitle(): string {
    let name: string = this.sourceLanguage;
    try { name = i18n.System.getDisplayLanguage(this.sourceLanguage, effectiveAppLocale()); } catch (error) { }
    return this.context().resourceManager.getStringSync($r('app.string.post_translation_auto_language').id, name);
  }

  private fullSettings(): void {
    this.open = false;
    const param: SettingsRouteParam = { section: 'translation' };
    NavigationGuard.pushPath<SettingsRouteParam>(this.pageStack, { name: 'SettingsSection', param: param },
      (route: SettingsRouteParam): string => route.section);
  }

  @Builder
  private Options(): void {
    Column({ space: $r('app.float.post_translation_sheet_gap') }) {
      Row() {
        Text(this.choosingLanguages ? $r('app.string.post_translation_choose_languages') : $r('app.string.settings_translation_auto_enable'))
          .fontFamily(this.appFontFamily).fontSize($r('sys.float.Title_S')).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary')).layoutWeight(1)
        if (this.choosingLanguages) {
          Button($r('app.string.image_edit_done')).fontFamily(this.appFontFamily).fontColor(this.accent)
            .backgroundColor(Color.Transparent).onClick((): void => { this.open = false; })
        }
      }.width('100%')
      if (this.choosingLanguages) {
        Text($r('app.string.post_translation_languages_description')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary')).width('100%')
        List() {
          ForEach(this.languages, (language: AppLanguageOption) => {
            ListItem() {
              Row() {
                Text(language.name).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L'))
                  .fontColor($r('app.color.text_primary')).layoutWeight(1)
                Checkbox().select(this.allowed(language.tag)).selectedColor(this.accent).accessibilityText(language.name)
                  .onChange((selected: boolean): void => this.saveLanguage(language.tag, selected))
              }.width('100%').padding({ top: $r('app.float.post_translation_language_padding'), bottom: $r('app.float.post_translation_language_padding') })
            }
          }, (language: AppLanguageOption): string => language.tag)
        }.layoutWeight(1).width('100%').scrollBar(BarState.Auto)
      } else {
        Text($r('app.string.settings_translation_auto_enable_desc')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary')).width('100%')
        Row() {
          Text($r('app.string.settings_translation_auto_enable')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_primary')).layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.autoEnabled }).selectedColor(this.accent)
            .enabled(this.canAutoTranslate).accessibilityText($r('app.string.settings_translation_auto_enable'))
            .onChange((enabled: boolean): void => this.saveAutomatic(enabled))
        }.width('100%')
        if (this.sourceLanguage.length > 0 && this.languages.some((language: AppLanguageOption): boolean =>
          sameTranslationLanguage(language.tag, this.sourceLanguage))) {
          Row() {
            Text(this.sourceTitle()).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L'))
              .fontColor($r('app.color.text_primary')).layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.autoEnabled && this.allowed(this.sourceLanguage) })
              .selectedColor(this.accent).enabled(this.canAutoTranslate).accessibilityText(this.sourceTitle())
              .onChange((enabled: boolean): void => this.saveLanguage(this.sourceLanguage, enabled, true))
          }.width('100%')
        }
        Button($r('app.string.post_translation_choose_languages')).fontFamily(this.appFontFamily)
          .fontColor(this.accent).backgroundColor(Color.Transparent).width('100%')
          .onClick((): void => { this.choosingLanguages = true; })
        Button($r('app.string.settings_translation')).fontFamily(this.appFontFamily)
          .fontColor(this.accent).backgroundColor(Color.Transparent).width('100%')
          .onClick((): void => this.fullSettings())
      }
    }.width('100%').height('100%').alignItems(HorizontalAlign.Start)
      .padding({ left: $r('app.float.post_translation_sheet_inset'), right: $r('app.float.post_translation_sheet_inset'),
        top: $r('app.float.post_translation_sheet_top'), bottom: this.bottomInset })
  }

  build(): void {
    Column().width(0).height(0)
      .bindSheet($$this.open, this.Options(), sheetMaterialOptions({
        height: this.choosingLanguages ? '85%' : $r('app.float.post_translation_sheet_height'),
        width: $r('app.float.post_translation_sheet_width'), showClose: !this.choosingLanguages,
        dragBar: !this.choosingLanguages, backgroundColor: pageSurfaceColor(this.displayMode, this.darkSurface),
        onDisappear: (): void => { this.open = false; }
      }, this.materialEnabled, this.materialLevel))
  }
}
