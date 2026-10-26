import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { TitleBarControlMaterialCache } from '../utils/DestinationTitleBar';
import { materialModifier, SystemMaterialUtil } from '../utils/SystemMaterial';
import { fieldSurfaceColor } from '../utils/ThemeColors';

@Component
export struct PageSearchField {
  @Prop value: string = '';
  @Prop placeholder: ResourceStr = '';
  onValueChange: (value: string) => void = (_value: string): void => {};
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp('harmonyx.display_mode') private displayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private darkSurface: string = '';
  @StorageProp('harmonyx.accent_color') private accentColor: string = '#007DFF';
  private searchMaterial: TitleBarControlMaterialCache = new TitleBarControlMaterialCache();

  build(): void {
    Column() {
      Search({ value: this.value, placeholder: this.placeholder })
        .width('100%').height($r('app.float.page_search_height'))
        .textFont({ size: $r('app.float.page_search_font_size'), family: this.appFontFamily })
        .borderRadius($r('app.float.page_search_radius')).clip(true)
        .keyboardAppearance(KeyboardAppearance.IMMERSIVE).fontColor($r('app.color.text_primary'))
        .backgroundColor(SystemMaterialUtil.isApi26OrAbove() ? Color.Transparent :
          fieldSurfaceColor(this.displayMode, this.darkSurface))
        .attributeModifier(materialModifier(this.searchMaterial.material(this.accentColor)))
        .onChange((value: string): void => this.onValueChange(value))
    }.width('100%').height($r('app.float.page_search_band_height'))
      .padding({ left: $r('app.float.page_search_inset'), right: $r('app.float.page_search_inset'),
        top: $r('app.float.page_search_top_inset'), bottom: $r('app.float.page_search_bottom_inset') })
  }
}
