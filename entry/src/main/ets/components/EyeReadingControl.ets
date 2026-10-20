import { abilityAccessCtrl, common, PermissionRequestResult } from '@kit.AbilityKit';
import { ARView, arViewController } from '@kit.AREngine';
import { BusinessError } from '@kit.BasicServicesKit';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { EyeReadingSession, eyeReadingSupported } from '../services/EyeReadingSession';
import { EyeReadingSettings, eyeReadingSettingsStore, STORAGE_KEY_EYE_READING_ENABLED,
  STORAGE_KEY_EYE_READING_DWELL, STORAGE_KEY_EYE_READING_THRESHOLD } from '../services/EyeReadingSettingsStore';
import { EyeReadingSample, EyeReadingFeedback, EyeReadingPolicy } from '../utils/EyeReadingPolicy';
import { STORAGE_KEY_INPUT_MODAL_BLOCKED } from '../utils/InputModalScope';
import { pageTextColor, fieldSurfaceColor } from '../utils/ThemeColors';

@Component
export struct EyeReadingControl {
  @Prop @Watch('availabilityChanged') active: boolean = false;
  @Prop @Watch('interactionChanged') interaction: number = 0;
  onPage: (direction: number) => void = (_direction: number): void => { };
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp('harmonyx.page_background') private pageBackground: string = '';
  @StorageProp('harmonyx.display_mode') private displayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private darkSurface: string = '';
  @StorageProp('harmonyx.accent_color') private accent: string = '#007DFF';
  @StorageProp('harmonyx.app_foreground') @Watch('availabilityChanged') private foreground: boolean = true;
  @StorageProp(STORAGE_KEY_INPUT_MODAL_BLOCKED) @Watch('availabilityChanged') private modal: boolean = false;
  @StorageProp(STORAGE_KEY_EYE_READING_ENABLED) @Watch('enabledChanged') private readingEnabled: boolean = false;
  @StorageProp(STORAGE_KEY_EYE_READING_DWELL) @Watch('configurationChanged') private dwell: number = 900;
  @StorageProp(STORAGE_KEY_EYE_READING_THRESHOLD) @Watch('configurationChanged') private threshold: number = 0.22;
  @State private arContext: arViewController.ARViewContext | undefined = undefined;
  @State private running: boolean = false;
  @State private starting: boolean = false;
  @State private supported: boolean = false;
  @State private state: string = 'idle';
  @State private progress: number = 0;
  private alive: boolean = false;
  private generation: number = 0;
  private lastSample: number = 0;
  private watchdog: number = -1;
  private policy: EyeReadingPolicy = new EyeReadingPolicy();
  private session: EyeReadingSession = new EyeReadingSession((): void => {
    this.arContext = undefined; this.running = false; this.clearWatchdog();
  });

  aboutToAppear(): void {
    this.alive = true; eyeReadingSettingsStore.load(getContext(this));
    this.supported = eyeReadingSupported();
  }
  aboutToDisappear(): void { this.alive = false; this.stop(); }
  private available(): boolean { return this.alive && this.active && this.foreground && !this.modal; }
  private availabilityChanged(): void { if (!this.available()) { this.stop(); } }
  private enabledChanged(): void { if (!this.readingEnabled) { this.stop(); } }
  private interactionChanged(): void { this.policy.suspend(Date.now()); this.progress = 0; }
  private configurationChanged(): void { this.policy.configure(this.dwell, this.threshold); this.progress = 0; }
  private clearWatchdog(): void {
    if (this.watchdog >= 0) { clearInterval(this.watchdog); this.watchdog = -1; }
  }
  private stop(): void {
    this.generation++; this.running = false; this.starting = false; this.arContext = undefined;
    this.state = 'idle'; this.progress = 0; this.policy.reset(); this.clearWatchdog(); this.session.stop();
  }
  private accept(sample: EyeReadingSample): void {
    if (!this.available() || !this.running) { return; }
    this.lastSample = Date.now();
    const feedback: EyeReadingFeedback = this.policy.update(sample, this.modal);
    this.state = feedback.state; this.progress = feedback.progress;
    if (feedback.action !== 0 && this.available()) { this.onPage(feedback.action); }
  }
  private async start(): Promise<void> {
    if (!this.available() || this.starting || this.running) { return; }
    if (!this.supported) { this.state = 'unsupported'; return; }
    const generation: number = ++this.generation;
    this.starting = true; this.state = 'starting';
    try {
      const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      const settings: EyeReadingSettings = eyeReadingSettingsStore.load(context); settings.enabled = true;
      if (!eyeReadingSettingsStore.save(context, settings)) { this.state = 'save_failed'; return; }
      const permission: PermissionRequestResult = await abilityAccessCtrl.createAtManager()
        .requestPermissionsFromUser(context, ['ohos.permission.CAMERA']);
      if (generation !== this.generation || !this.available()) { return; }
      if (permission.authResults.length !== 1 || permission.authResults[0] !== 0) { this.state = 'permission'; return; }
      this.policy.configure(settings.dwell, settings.threshold);
      await this.session.start((sample: EyeReadingSample): void => this.accept(sample),
        (view: arViewController.ARViewContext): void => {
          if (generation !== this.generation || !this.available()) { this.session.stop(); return; }
          this.arContext = view; this.running = true; this.state = 'calibrating'; this.lastSample = Date.now();
          this.watchdog = setInterval((): void => {
            if (this.running && Date.now() - this.lastSample > 700) {
              const missing: EyeReadingSample = new EyeReadingSample(); missing.time = Date.now(); this.accept(missing);
            }
          }, 400);
        });
    } catch (error) {
      if (generation === this.generation) {
        const failure: BusinessError = error as BusinessError;
        this.session.stop(); this.running = false; this.arContext = undefined;
        this.state = failure.code === 201 ? 'permission' : failure.code === 801 || failure.code === 1009200007 ?
          'unsupported' : 'failed';
      }
    } finally { if (generation === this.generation) { this.starting = false; } }
  }
  private message(): Resource {
    if (this.state === 'starting') { return $r('app.string.eye_reading_starting'); }
    if (this.state === 'unsupported') { return $r('app.string.eye_reading_unsupported'); }
    if (this.state === 'permission') { return $r('app.string.eye_reading_permission'); }
    if (this.state === 'failed') { return $r('app.string.eye_reading_failed'); }
    if (this.state === 'save_failed') { return $r('app.string.eye_reading_save_failed'); }
    if (this.state === 'calibrating') { return $r('app.string.eye_reading_calibrating'); }
    if (this.state === 'center') { return $r('app.string.eye_reading_center'); }
    if (this.state === 'ready') { return $r('app.string.eye_reading_ready'); }
    if (this.state === 'up') { return $r('app.string.eye_reading_up'); }
    if (this.state === 'down') { return $r('app.string.eye_reading_down'); }
    if (this.state === 'lost') { return $r('app.string.eye_reading_lost'); }
    if (this.state === 'paused') { return $r('app.string.eye_reading_paused'); }
    return $r('app.string.eye_reading_privacy');
  }
  build(): void {
    Column({ space: 6 }) {
      Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Center }) {
        Button(this.running || this.starting ? $r('app.string.eye_reading_stop') : $r('app.string.eye_reading_start'))
          .fontFamily(this.appFontFamily).fontColor(this.accent).backgroundColor(Color.Transparent)
          .enabled(this.active).id('eye-reading-start').accessibilityText($r('app.string.eye_reading_title'))
          .onClick((): void => { if (this.running || this.starting) { this.stop(); } else { void this.start(); } })
        if (this.running) {
          Button($r('app.string.eye_reading_recalibrate')).fontFamily(this.appFontFamily)
            .fontColor(this.accent).backgroundColor(Color.Transparent).id('eye-reading-recalibrate')
            .onClick((): void => { this.policy.reset(); this.state = 'calibrating'; this.progress = 0; })
        }
      }.width('100%')
      if (this.running || this.starting || this.state !== 'idle') {
        Row({ space: 10 }) {
          // Keep a real, visible AR rendering surface; do not use a zero-sized/hidden camera view.
          if (this.arContext !== undefined) {
            ARView({ context: this.arContext }).width(64).height(64).borderRadius(12).clip(true)
              .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
          }
          Column({ space: 6 }) {
            Text(this.message()).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S'))
              .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackground))
              .width('100%').id('eye-reading-status')
            if (this.running) {
              Progress({ value: Math.round(this.progress * 100), total: 100, type: ProgressType.Linear })
                .width('100%').color(this.accent).height(4)
            }
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        }.width('100%').padding(10).backgroundColor(fieldSurfaceColor(this.displayMode, this.darkSurface)).borderRadius(12)
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
}
