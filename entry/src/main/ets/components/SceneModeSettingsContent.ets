import { common } from '@kit.AbilityKit';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { sceneModeStore, STORAGE_KEY_SCENE_MODE, SCENE_READING, SCENE_SAVER, SCENE_MEDIA } from '../services/SceneModeStore';
import { fieldSurfaceColor, pageTextColor } from '../utils/ThemeColors';

@Component
export struct SceneModeSettingsContent {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp('harmonyx.page_background') private pageBackground: string = '';
  @StorageProp('harmonyx.display_mode') private displayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private darkSurface: string = '';
  @StorageProp('harmonyx.accent_color') private accent: string = '#007DFF';
  @StorageProp(STORAGE_KEY_SCENE_MODE) private mode: string = '';
  @State private failed: boolean = false;

  private select(mode: string): void {
    const context: common.Context = getContext(this);
    this.failed = !sceneModeStore.apply(context, mode);
  }
  @Builder
  private Option(mode: string, title: Resource, detail: Resource): void {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 12 }) {
        Column({ space: 6 }) {
          Text(title).fontFamily(this.appFontFamily).fontSize($r('sys.float.Subtitle_L'))
            .fontWeight(FontWeight.Medium).fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackground))
          Text(detail).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
            .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackground))
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        SymbolGlyph(this.mode === mode ? $r('sys.symbol.checkmark_circle_fill') : $r('sys.symbol.circle'))
          .fontSize(24).fontColor([this.mode === mode ? this.accent : $r('app.color.text_secondary')])
      }.width('100%').padding(16)
    }.width('100%').borderRadius(16).backgroundColor(fieldSurfaceColor(this.displayMode, this.darkSurface))
      .accessibilityText(title).accessibilitySelected(this.mode === mode).id('scene-' + mode)
      .onClick((): void => this.select(mode))
  }
  build(): void {
    Column({ space: 12 }) {
      Text($r('app.string.scene_intro')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
        .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackground))
      this.Option(SCENE_READING, $r('app.string.scene_reading'), $r('app.string.scene_reading_desc'))
      this.Option(SCENE_SAVER, $r('app.string.scene_saver'), $r('app.string.scene_saver_desc'))
      this.Option(SCENE_MEDIA, $r('app.string.scene_media'), $r('app.string.scene_media_desc'))
      this.Option('', $r('app.string.scene_restore'), $r('app.string.scene_restore_desc'))
      if (this.failed) {
        Text($r('app.string.scene_failed')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
          .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackground))
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
}
