import { common } from '@kit.AbilityKit';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { STORAGE_KEY_REDUCE_MOTION, STORAGE_KEY_MOTION_DURATION, STORAGE_KEY_MOTION_AMPLITUDE,
  STORAGE_KEY_MOTION_DAMPING, STORAGE_KEY_SYMBOL_EFFECTS, STORAGE_KEY_HAPTICS_ENABLED,
  STORAGE_KEY_HAPTICS_INTENSITY, motionSettingsStore, selectedMotionPreset,
  MOTION_PRESET_QUICK, MOTION_PRESET_STANDARD, MOTION_PRESET_SPRING, MOTION_PRESET_REDUCED,
  MOTION_PRESET_CUSTOM } from '../services/MotionSettingsStore';
import { motionDuration, motionDistance, motionScale, motionCurve, symbolMotionEnabled } from '../utils/AppMotion';
import { hapticTick, hapticConfirm } from '../utils/Haptics';
import { pageTextColor, fieldSurfaceColor } from '../utils/ThemeColors';

@Component
export struct MotionSettingsContent {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp('harmonyx.page_background') private pageBackgroundValue: string = '';
  @StorageProp('harmonyx.display_mode') private displayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private darkSurface: string = '';
  @StorageProp('harmonyx.accent_color') private accentColor: string = '#007DFF';
  @StorageProp(STORAGE_KEY_REDUCE_MOTION) @Watch('motionChanged') private reduceMotion: boolean = false;
  @StorageProp(STORAGE_KEY_MOTION_DURATION) private duration: number = 300;
  @StorageProp(STORAGE_KEY_MOTION_AMPLITUDE) @Watch('motionChanged') private amplitude: number = 1;
  @StorageProp(STORAGE_KEY_MOTION_DAMPING) private damping: number = 0.82;
  @StorageProp(STORAGE_KEY_SYMBOL_EFFECTS) private symbolEffects: boolean = true;
  @StorageProp(STORAGE_KEY_HAPTICS_ENABLED) private hapticsEnabled: boolean = true;
  @StorageProp(STORAGE_KEY_HAPTICS_INTENSITY) private intensity: number = 60;
  @State private previewScale: number = 1;
  @State private previewOffset: number = 0;
  @State private symbolTrigger: number = -1;
  @State private failed: boolean = false;

  private motionChanged(): void {
    if (!this.reduceMotion && this.amplitude > 0) { return; }
    this.getUIContext().animateTo({ duration: 0 }, (): void => {
      this.previewScale = 1;
      this.previewOffset = 0;
    });
  }

  private effectsActive(): boolean {
    return this.symbolEffects && !this.reduceMotion && this.amplitude > 0;
  }

  private preview(): void {
    hapticConfirm();
    if (symbolMotionEnabled()) { this.symbolTrigger++; }
    this.previewScale = motionScale(0.78);
    this.previewOffset = motionDistance(-28);
    this.getUIContext().animateTo({ duration: motionDuration(), curve: motionCurve() }, (): void => {
      this.previewScale = 1;
      this.previewOffset = 0;
    });
  }

  private saveNumber(key: string, value: number, mode: SliderChangeMode): void {
    if (mode === SliderChangeMode.Begin || mode === SliderChangeMode.Moving) { return; }
    const context: common.Context | undefined = this.getUIContext().getHostContext();
    this.failed = context === undefined || !motionSettingsStore.saveNumber(context, key, value);
    if (!this.failed) { this.preview(); }
  }

  private saveBoolean(key: string, value: boolean): void {
    const context: common.Context | undefined = this.getUIContext().getHostContext();
    this.failed = context === undefined || !motionSettingsStore.saveBoolean(context, key, value);
    if (!this.failed) { hapticTick(); }
  }

  private currentPreset(): string {
    return selectedMotionPreset(this.duration, this.amplitude, this.damping, this.reduceMotion, this.symbolEffects);
  }

  private choosePreset(preset: string): void {
    const context: common.Context | undefined = this.getUIContext().getHostContext();
    this.failed = context === undefined || !motionSettingsStore.applyPreset(context, preset);
    if (!this.failed) { this.preview(); }
  }

  @Builder
  private PresetOption(preset: string, title: Resource, detail: Resource): void {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 14 }) {
        Column({ space: 5 }) {
          Text(title).fontFamily(this.appFontFamily).fontSize($r('sys.float.Subtitle_L'))
            .fontWeight(this.currentPreset() === preset ? FontWeight.Bold : FontWeight.Medium)
            .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent))
          this.Description(detail)
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        SymbolGlyph(this.currentPreset() === preset ? $r('sys.symbol.checkmark_circle_fill') : $r('sys.symbol.circle'))
          .fontSize(24).fontColor([this.currentPreset() === preset ? this.accentColor : $r('app.color.text_secondary')])
      }.width('100%').padding(16)
    }.width('100%').borderRadius(16)
      .backgroundColor(fieldSurfaceColor(this.displayMode, this.darkSurface))
      .id('motion-preset-' + preset).accessibilityText(title)
      .accessibilitySelected(this.currentPreset() === preset)
      .onClick((): void => this.choosePreset(preset))
  }

  @Builder
  private Description(text: Resource): void {
    Text(text).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
      .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)).width('100%')
  }

  @Builder
  private SwitchRow(key: string, title: Resource, detail: Resource, value: boolean): void {
    Row({ space: 12 }) {
      Column({ space: 6 }) {
        Text(title).fontFamily(this.appFontFamily).fontSize($r('sys.float.Subtitle_L'))
          .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent))
        this.Description(detail)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Toggle({ type: ToggleType.Switch, isOn: value }).selectedColor(this.accentColor)
        .id('motion-' + key).accessibilityText(title)
        .onChange((next: boolean): void => { if (next !== value) { this.saveBoolean(key, next); } })
    }.width('100%').padding({ top: 10, bottom: 10 })
  }

  @Builder
  private Adjustment(key: string, title: Resource, detail: Resource, value: number,
    min: number, max: number, step: number, label: string, enabled: boolean): void {
    Column({ space: 8 }) {
      Row({ space: 12 }) {
        Text(title).fontFamily(this.appFontFamily).fontSize($r('sys.float.Subtitle_L')).layoutWeight(1)
          .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent))
        Text(label).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor(this.accentColor)
      }.width('100%')
      Slider({ value: value, min: min, max: max, step: step, style: SliderStyle.InSet })
        .width('100%').selectedColor(this.accentColor).showTips(true).enabled(enabled)
        .id('motion-' + key).accessibilityText(title)
        .onChange((next: number, mode: SliderChangeMode): void => this.saveNumber(key, next, mode))
      this.Description(detail)
    }.width('100%').opacity(enabled ? 1 : 0.5)
  }

  build(): void {
    Column({ space: 20 }) {
      this.Description($r('app.string.motion_intro'))
      Column({ space: 10 }) {
        Text($r('app.string.motion_presets')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Title_S'))
          .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent))
          .width('100%')
        this.PresetOption(MOTION_PRESET_QUICK, $r('app.string.motion_preset_quick'), $r('app.string.motion_preset_quick_desc'))
        this.PresetOption(MOTION_PRESET_STANDARD, $r('app.string.motion_preset_standard'), $r('app.string.motion_preset_standard_desc'))
        this.PresetOption(MOTION_PRESET_SPRING, $r('app.string.motion_preset_spring'), $r('app.string.motion_preset_spring_desc'))
        this.PresetOption(MOTION_PRESET_REDUCED, $r('app.string.motion_preset_reduced'), $r('app.string.motion_preset_reduced_desc'))
        if (this.currentPreset() === MOTION_PRESET_CUSTOM) { this.Description($r('app.string.motion_preset_custom')) }
      }.width('100%')
      Button({ type: ButtonType.Normal }) {
        Column({ space: 12 }) {
          Row({ space: 28 }) {
            SymbolGlyph($r('sys.symbol.wand_and_stars')).fontSize(36).fontColor([this.accentColor])
              .symbolEffect(this.effectsActive() ? new BounceSymbolEffect(EffectScope.WHOLE) : new SymbolEffect(),
                this.effectsActive() ? this.symbolTrigger : -1)
            SymbolGlyph($r('sys.symbol.heart_fill')).fontSize(36).fontColor([this.accentColor])
              .scale({ x: this.previewScale, y: this.previewScale }).translate({ x: this.previewOffset })
          }.height(64)
          Text($r('app.string.motion_preview')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L'))
            .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent))
        }.width('100%').padding(20)
      }.width('100%').borderRadius(20)
        .backgroundColor(fieldSurfaceColor(this.displayMode, this.darkSurface))
        .id('motion-preview').accessibilityText($r('app.string.motion_preview'))
        .onClick((): void => this.preview())
      this.SwitchRow('reduce_motion', $r('app.string.motion_reduce'), $r('app.string.motion_reduce_desc'), this.reduceMotion)
      this.Adjustment('duration', $r('app.string.motion_duration'), $r('app.string.motion_duration_desc'),
        this.duration, 100, 700, 25, Math.round(this.duration).toString() + ' ms', !this.reduceMotion)
      this.Adjustment('amplitude', $r('app.string.motion_amplitude'), $r('app.string.motion_amplitude_desc'),
        this.amplitude, 0, 1.5, 0.1, Math.round(this.amplitude * 100).toString() + '%', !this.reduceMotion)
      this.Adjustment('damping', $r('app.string.motion_damping'), $r('app.string.motion_damping_desc'),
        this.damping, 0.5, 1, 0.02, this.damping.toFixed(2), !this.reduceMotion)
      this.SwitchRow('symbol_effects', $r('app.string.motion_symbol'), $r('app.string.motion_symbol_desc'), this.symbolEffects)
      this.SwitchRow('haptics_enabled', $r('app.string.motion_haptics'), $r('app.string.motion_haptics_desc'), this.hapticsEnabled)
      this.Adjustment('haptics_intensity', $r('app.string.motion_intensity'), $r('app.string.motion_intensity_desc'),
        this.intensity, 1, 100, 1, Math.round(this.intensity).toString() + '%', this.hapticsEnabled)
      if (this.failed) { this.Description($r('app.string.settings_interaction_save_failed')) }
    }.width('100%').padding({ left: 20, right: 20, top: 16, bottom: 28 })
  }
}
