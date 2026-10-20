import { common } from '@kit.AbilityKit';
import promptAction from '@ohos.promptAction';
import { translationStore, STORAGE_KEY_TRANSLATION_ENABLED, STORAGE_KEY_TRANSLATION_SETTINGS_REVISION,
  TranslationSettings } from '../services/TranslationStore';
import { translationService, TranslationResult } from '../services/TranslationService';
import { xPrivateClient } from '../services/XPrivateClient';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';

@Component
export struct ProfileBioTranslation {
  @Prop @Watch('resetTranslation') userId: string = '';
  @Prop @Watch('resetTranslation') bio: string = '';
  @StorageProp(STORAGE_KEY_TRANSLATION_ENABLED) private translationEnabled: boolean = false;
  @StorageProp(STORAGE_KEY_TRANSLATION_SETTINGS_REVISION) @Watch('resetTranslation') private revision: number = 0;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp('harmonyx.accent_color') private accentColor: string = '#007DFF';
  @State private translated: string = '';
  @State private pending: boolean = false;
  private serial: number = 0;
  aboutToDisappear(): void { this.resetTranslation(); }
  private resetTranslation(): void { this.serial++; this.translated = ''; this.pending = false; }
  private async runBioTranslation(): Promise<void> {
    if (this.pending) { return; }
    if (this.translated.length > 0) { this.translated = ''; return; }
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const settings: TranslationSettings = translationStore.load(context);
    const serial: number = ++this.serial;
    const session: number = xPrivateClient.sessionGeneration();
    this.pending = true;
    try {
      const result: TranslationResult = await translationService.translateBiography(this.userId, this.bio, settings);
      if (serial !== this.serial || session !== xPrivateClient.sessionGeneration()) { return; }
      if (result.ok) { this.translated = result.text; }
      else { promptAction.showToast({ message: context.resourceManager.getStringSync(
        settings.isRunnable() ? $r('app.string.post_translate_failed') : $r('app.string.post_translate_no_key')) }); }
    } catch (error) {
      if (serial === this.serial) { promptAction.showToast({
        message: context.resourceManager.getStringSync($r('app.string.post_translate_failed')) }); }
    } finally { if (serial === this.serial) { this.pending = false; } }
  }
  build(): void {
    if (this.translationEnabled && this.bio.trim().length > 0) {
      Column({ space: 6 }) {
        Button(this.pending ? $r('app.string.post_translating') : this.translated.length > 0 ?
          $r('app.string.post_hide_translation') : $r('app.string.post_translate'))
          .fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor(this.accentColor)
          .backgroundColor(Color.Transparent).padding({ left: 0, right: 12 }).height(40)
          .enabled(!this.pending).onClick((): void => { this.runBioTranslation(); })
        if (this.translated.length > 0) {
          Text(this.translated).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
            .fontColor($r('app.color.text_primary')).width('100%').copyOption(CopyOptions.LocalDevice)
        }
      }.width('100%').alignItems(HorizontalAlign.Start)
    }
  }
}
