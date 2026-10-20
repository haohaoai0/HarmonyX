import { EyeReadingSettings, eyeReadingSettingsStore, STORAGE_KEY_EYE_READING_ENABLED,
  STORAGE_KEY_EYE_READING_DWELL, STORAGE_KEY_EYE_READING_THRESHOLD } from '../services/EyeReadingSettingsStore';
import { eyeReadingSupported } from '../services/EyeReadingSession';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { pageTextColor } from '../utils/ThemeColors';

@Component
export struct EyeReadingSettingsContent {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp('harmonyx.page_background') private pageBackground: string = '';
  @StorageProp('harmonyx.accent_color') private accent: string = '#007DFF';
  @StorageProp(STORAGE_KEY_EYE_READING_ENABLED) private readingEnabled: boolean = false;
  @StorageProp(STORAGE_KEY_EYE_READING_DWELL) private dwell: number = 900;
  @StorageProp(STORAGE_KEY_EYE_READING_THRESHOLD) private threshold: number = 0.22;
  @State private supported: boolean = false;
  @State private failed: boolean = false;
  aboutToAppear(): void { eyeReadingSettingsStore.load(getContext(this)); this.supported = eyeReadingSupported(); }
  private save(key: string, value: number): void {
    const settings: EyeReadingSettings = eyeReadingSettingsStore.load(getContext(this));
    if (key === 'enabled') { settings.enabled = value > 0; }
    if (key === 'dwell') { settings.dwell = value; }
    if (key === 'threshold') { settings.threshold = value; }
    this.failed = !eyeReadingSettingsStore.save(getContext(this), settings);
  }
  @Builder
  private Copy(value: Resource): void {
    Text(value).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
      .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackground)).width('100%')
  }
  build(): void {
    Column({ space: 16 }) {
      this.Copy($r('app.string.eye_reading_intro'))
      Row({ space: 12 }) {
        Text($r('app.string.eye_reading_enable')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Subtitle_L'))
          .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackground)).layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.readingEnabled }).selectedColor(this.accent).enabled(this.supported)
          .id('eye-reading-enabled').accessibilityText($r('app.string.eye_reading_enable'))
          .onChange((value: boolean): void => { if (value !== this.readingEnabled) { this.save('enabled', value ? 1 : 0); } })
      }.width('100%')
      this.Copy(this.supported ? $r('app.string.eye_reading_supported') : $r('app.string.eye_reading_unsupported'))
      Text($r('app.string.eye_reading_dwell')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Subtitle_L'))
        .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackground))
      Text((this.dwell / 1000).toFixed(1) + ' s').fontFamily(this.appFontFamily).fontColor(this.accent)
      Slider({ value: this.dwell, min: 600, max: 2000, step: 100 }).width('100%').selectedColor(this.accent)
        .id('eye-reading-dwell').accessibilityText($r('app.string.eye_reading_dwell'))
        .onChange((value: number, mode: SliderChangeMode): void => {
          if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) { this.save('dwell', value); }
        })
      Text($r('app.string.eye_reading_threshold')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Subtitle_L'))
        .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackground))
      Slider({ value: this.threshold, min: 0.12, max: 0.5, step: 0.02 }).width('100%').selectedColor(this.accent)
        .id('eye-reading-threshold').accessibilityText($r('app.string.eye_reading_threshold'))
        .onChange((value: number, mode: SliderChangeMode): void => {
          if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) { this.save('threshold', value); }
        })
      this.Copy($r('app.string.eye_reading_threshold_desc'))
      this.Copy($r('app.string.eye_reading_help'))
      this.Copy($r('app.string.eye_reading_privacy'))
      if (this.failed) { this.Copy($r('app.string.eye_reading_save_failed')) }
    }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 20, right: 20, top: 16, bottom: 28 })
  }
}
