import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { fieldSurfaceColor } from '../utils/ThemeColors';

@Component
export struct ProfileEditorField {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp('harmonyx.display_mode') private displayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private darkSurface: string = '';
  @Prop label: Resource = $r('app.string.profile_edit_name');
  @Prop value: string = '';
  @Prop limit: number = 50;
  @Prop multiline: boolean = false;
  @Prop website: boolean = false;
  @Prop disabled: boolean = false;
  onValue: (value: string) => void = (): void => {};

  build(): void {
    Column({ space: 8 }) {
      Text(this.label).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary'))
      if (this.multiline) {
        TextArea({ text: this.value }).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_primary'))
          .backgroundColor(fieldSurfaceColor(this.displayMode, this.darkSurface))
          .padding(16).height(112).borderRadius(16).maxLength(this.limit)
          .keyboardAppearance(KeyboardAppearance.IMMERSIVE).enabled(!this.disabled)
          .accessibilityText(this.label).onChange((text: string): void => this.onValue(text))
      } else {
        TextInput({ text: this.value }).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_primary'))
          .backgroundColor(fieldSurfaceColor(this.displayMode, this.darkSurface))
          .padding({ left: 16, right: 16 }).height(52).borderRadius(24).maxLength(this.limit)
          .type(this.website ? InputType.URL : InputType.Normal)
          .keyboardAppearance(KeyboardAppearance.IMMERSIVE).enabled(!this.disabled)
          .accessibilityText(this.label).onChange((text: string): void => this.onValue(text))
      }
      Row() {
        Blank()
        Text(Array.from(this.value).length + '/' + this.limit).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S'))
          .fontColor($r('app.color.text_secondary'))
      }.width('100%')
    }.width('100%').alignItems(HorizontalAlign.Start).margin({ bottom: 18 })
  }
}
