import { i18n } from '@kit.LocalizationKit';
import { STORAGE_KEY_TRANSLATION_OPTIONS_REQUEST, STORAGE_KEY_TRANSLATION_OPTIONS_LANGUAGE } from '../services/TranslationStore';
import { common } from '@kit.AbilityKit';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { effectiveAppLocale } from '../utils/AppLocale';

// Shared by timeline cards and the detail hero. The translation stays cached
// while the reader switches between the original and translated body.
@Component
export struct PostTranslationInfo {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Prop language: string = '';
  @Prop showingOriginal: boolean = false;
  @Prop foreground: ResourceColor = $r('app.color.text_secondary');
  @Prop accent: ResourceColor = $r('app.color.text_primary');
  onToggle: () => void = (): void => {};
  private openSettings(): void {
    AppStorage.setOrCreate<string>(STORAGE_KEY_TRANSLATION_OPTIONS_LANGUAGE, this.language);
    AppStorage.setOrCreate<number>(STORAGE_KEY_TRANSLATION_OPTIONS_REQUEST,
      (AppStorage.get<number>(STORAGE_KEY_TRANSLATION_OPTIONS_REQUEST) ?? 0) + 1);
  }

  private sourceLabel(): string {
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    let language: string = '';
    if (this.language.length > 0 && this.language !== 'und') {
      try { language = i18n.System.getDisplayLanguage(this.language, effectiveAppLocale()); }
      catch (error) { language = this.language; }
    }
    return language.length > 0 ?
      context.resourceManager.getStringSync($r('app.string.post_translated_from').id, language) :
      context.resourceManager.getStringSync($r('app.string.post_translated').id);
  }

  build(): void {
    Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Center }) {
      Row({ space: $r('app.float.post_translation_gap') }) {
        SymbolGlyph($r('sys.symbol.translate')).fontSize($r('sys.float.Body_S')).fontColor([this.foreground])
        Text(this.sourceLabel()).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S'))
          .fontColor(this.foreground)
      }.padding({ top: $r('app.float.post_translation_padding'), bottom: $r('app.float.post_translation_padding'),
        right: $r('app.float.post_translation_action_gap') })
        .accessibilityText($r('app.string.settings_translation')).id('post-translation-settings')
        .onClick((): void => this.openSettings()).monopolizeEvents(true)
      Text(this.showingOriginal ? $r('app.string.post_show_translation') : $r('app.string.post_show_original'))
        .fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S')).fontColor(this.accent)
        .padding({ top: $r('app.float.post_translation_padding'), bottom: $r('app.float.post_translation_padding') }).id('post-translation-toggle')
        .onClick((): void => this.onToggle()).monopolizeEvents(true)
    }.width('100%')
  }
}
