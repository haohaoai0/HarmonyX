import { TouchHdrLight } from './TouchHdrLight';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { buildPointLightEffect, POINT_LIGHT_PRESS_INTENSITY } from '../utils/PointLight';

@Component
export struct ChatPinPad {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Prop title: ResourceStr = $r('app.string.dm_unlock_title');
  @Prop error: string = '';
  @Prop @Watch('onLightAvailabilityChanged') busy: boolean = false;
  @StorageLink('harmonyx.accent_color') accentColor: string = '#007DFF';
  @State private pin: string = '';
  @State private lightKey: string = '';
  @State private lightIntensity: number = 0;
  onSubmit: (pin: string) => void = (pin: string): void => {};
  onClose: () => void = (): void => {};
  aboutToDisappear(): void {
    this.lightIntensity = 0;
    this.lightKey = '';
  }
  private onLightAvailabilityChanged(): void {
    if (this.busy) { this.lightIntensity = 0; }
  }
  private keyLightEffect(key: string): VisualEffect {
    return buildPointLightEffect(this.lightKey === key ? this.lightIntensity : 0);
  }
  private updatePointLight(key: string, event: TouchEvent): void {
    if (event.type === TouchType.Down) {
      if (this.busy || (key === 'continue' && this.pin.length !== 4)) { return; }
      this.lightKey = key;
      this.lightIntensity = POINT_LIGHT_PRESS_INTENSITY;
    } else if ((event.type === TouchType.Up || event.type === TouchType.Cancel) && this.lightKey === key) {
      this.lightIntensity = 0;
    }
  }
  private digit(value: string): void {
    if (!this.busy && this.pin.length < 4) { this.pin += value; }
  }
  @Builder
  private HdrKeyLight(key: string): void {
    TouchHdrLight({ active: !this.busy && this.lightKey === key && this.lightIntensity > 0,
      cornerRadius: 29 })
  }

  @Builder
  private Key(value: string): void {
    Button(value).fontSize(28).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
      .backgroundColor(Color.Transparent).layoutWeight(1).height(58).enabled(!this.busy)
      .visualEffect(this.keyLightEffect(value))
        .overlay(this.HdrKeyLight(value))
      .animation({ duration: 300, curve: Curve.Smooth })
      .onTouch((event: TouchEvent): void => { this.updatePointLight(value, event); })
      .onClick((): void => this.digit(value))
  }
  build(): void {
    Column({ space: 16 }) {
      Row() {
        Text(this.title).fontFamily(this.appFontFamily).fontSize($r('sys.float.Title_M')).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary')).layoutWeight(1)
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.xmark')).fontSize(22).fontColor([$r('app.color.text_primary')])
        }.width(40).height(40).backgroundColor(Color.Transparent).enabled(!this.busy)
          .onClick((): void => { this.pin = ''; this.onClose(); })
      }.width('100%')
      Divider().color($r('app.color.divider'))
      Row({ space: 16 }) {
        ForEach([0, 1, 2, 3], (index: number) => {
          Stack() {
            if (this.pin.length > index) {
              Circle().width(16).height(16).fill($r('app.color.text_primary'))
            }
          }.layoutWeight(1).aspectRatio(1).borderRadius(100)
            .border({ width: 1.5, color: $r('app.color.text_secondary') })
        })
      }.width('100%').margin({ top: 20, bottom: 6 })
        .accessibilityText($r('app.string.dm_pin_hint')).accessibilityLevel('yes')
      Text(this.error.length > 0 ? this.error : $r('app.string.chat_pin_hint')).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_M')).fontColor(this.error.length > 0 ?
          $r('app.color.like') : $r('app.color.text_secondary')).textAlign(TextAlign.Center).width('100%')
      Column({ space: 6 }) {
        Row() { this.Key('1'); this.Key('2'); this.Key('3') }.width('100%')
        Row() { this.Key('4'); this.Key('5'); this.Key('6') }.width('100%')
        Row() { this.Key('7'); this.Key('8'); this.Key('9') }.width('100%')
        Row() {
          Blank().layoutWeight(1)
          this.Key('0')
          Button({ type: ButtonType.Normal }) {
            SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(26).fontColor([$r('app.color.text_primary')])
          }.layoutWeight(1).height(58).backgroundColor(Color.Transparent).enabled(!this.busy)
            .visualEffect(this.keyLightEffect('backspace'))
        .overlay(this.HdrKeyLight('backspace'))
            .animation({ duration: 300, curve: Curve.Smooth })
            .onTouch((event: TouchEvent): void => { this.updatePointLight('backspace', event); })
            .onClick((): void => { this.pin = this.pin.substring(0, Math.max(0, this.pin.length - 1)); })
        }.width('100%')
      }.width('100%')
      Button($r('app.string.chat_continue')).width('100%').height(48)
        .fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_on_accent'))
        .backgroundColor(this.accentColor).enabled(this.pin.length === 4 && !this.busy)
        .visualEffect(this.keyLightEffect('continue'))
        .overlay(this.HdrKeyLight('continue'))
        .animation({ duration: 300, curve: Curve.Smooth })
        .onTouch((event: TouchEvent): void => { this.updatePointLight('continue', event); })
        .onClick((): void => { const pin: string = this.pin; this.pin = ''; this.onSubmit(pin); })
      if (this.busy) { LoadingProgress().width(22).height(22).color(this.accentColor) }
    }.width('100%').padding({ left: 24, right: 24, top: 12, bottom: 24 })
  }
}
