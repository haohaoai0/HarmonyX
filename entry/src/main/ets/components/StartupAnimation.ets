import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { STORAGE_KEY_CURRENT_APP_ICON, APP_ICON_X_BLACK, APP_ICON_X_WHITE,
  appIconForeground } from '../services/AppIconStore';
import { ColorMetrics } from '@kit.ArkUI';
import { STARTUP_MODE_VIDEO, STORAGE_KEY_STARTUP_SPEED,
  normaliseStartupSpeed } from '../services/StartupSettingsStore';
import { STORAGE_KEY_SYSTEM_DARK } from '../services/AppearanceStore';
import { startupAnimationName } from '../utils/StartupAnimationSource';
import { STARTUP_BRAND_DURATION, startupVideoTimeout } from '../utils/StartupSession';

@Component
export struct StartupAnimation {
  @Prop play: boolean = false;
  @Prop mode: string = STARTUP_MODE_VIDEO;
  @Prop initialFrame: boolean = false;
  @Prop markScale: number = 1;
  @Prop backgroundOpacity: number = 1;
  @Prop markOpacity: number = 1;
  onFinished: () => void = (): void => {};
  @StorageProp(STORAGE_KEY_CURRENT_APP_ICON) private iconName: string = '';
  @StorageProp('harmonyx.display_mode') private displayMode: string = '';
  @StorageProp(STORAGE_KEY_SYSTEM_DARK) private systemDark: boolean = false;
  @StorageProp(STORAGE_KEY_STARTUP_SPEED) private playbackSpeed: number = 1;
  @StorageProp('reduceMotionEnabled') @Watch('onPlaybackEligibilityChanged') private reduceMotion: boolean = false;
  @StorageProp('harmonyx.app_foreground') @Watch('onPlaybackEligibilityChanged') private foreground: boolean = true;
  @State private artwork: string = '';
  @State private completed: boolean = false;
  private alive: boolean = false;
  private timer: number = -1;

  aboutToAppear(): void {
    this.alive = true;
    this.completed = false;
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const dark: boolean = this.displayMode === 'dark' || (this.displayMode !== 'light' && this.systemDark);
    this.artwork = startupAnimationName(this.iconName, dark, context.applicationInfo.name);
    if (!this.play || this.mode !== STARTUP_MODE_VIDEO) { return; }
    // The watchdog covers decoder failure, a missing finish callback and a
    // paused player. It never depends on authentication or network responses.
    this.timer = setTimeout((): void => this.finish(),
      this.reduceMotion || !this.foreground ? STARTUP_BRAND_DURATION : startupVideoTimeout(this.playbackRate()));
  }

  private playbackRate(): number { return normaliseStartupSpeed(this.playbackSpeed); }

  aboutToDisappear(): void {
    this.alive = false;
    this.clearTimer();
  }

  private clearTimer(): void {
    if (this.timer >= 0) { clearTimeout(this.timer); this.timer = -1; }
  }

  private finish(): void {
    if (!this.alive || !this.play || this.completed) { return; }
    this.completed = true;
    this.clearTimer();
    hilog.info(0x0001, 'StartupAnimation', 'Finished %{public}s', this.artwork);
    this.onFinished();
  }

  private onPlaybackEligibilityChanged(): void {
    if (this.reduceMotion || !this.foreground) { this.finish(); }
  }

  private launchBackground(): ResourceColor {
    if (this.artwork === 'launch_twitter_blue') { return $r('app.color.startup_animation_twitter_blue'); }
    if (this.mode !== STARTUP_MODE_VIDEO) { return $r('app.color.start_window_background'); }
    // Values come from the dominant outer-rim color decoded at the original
    // resolution. Never average the logo or sample a resized YUV thumbnail.
    return this.artwork.endsWith('_dark') ? $r('app.color.startup_animation_dark') :
      $r('app.color.startup_animation_light');
  }

  private markColorFilter(): ColorFilter {
    if (this.iconName === APP_ICON_X_BLACK || this.iconName === APP_ICON_X_WHITE) {
      const ink: ColorMetrics = ColorMetrics.resourceColor($r('app.color.text_primary'));
      return new ColorFilter([0, 0, 0, ink.red / 255, 0, 0, 0, 0, ink.green / 255, 0,
        0, 0, 0, ink.blue / 255, 0, 0, 0, 0, 1, 0]);
    }
    return new ColorFilter([1, 0, 0, 0, 0, 0, 1, 0, 0, 0,
      0, 0, 1, 0, 0, 0, 0, 0, 1, 0]);
  }

  build(): void {
    Stack() {
      Column().width('100%').height('100%').backgroundColor(this.launchBackground())
        .opacity(this.backgroundOpacity)
      if (this.mode !== STARTUP_MODE_VIDEO || this.reduceMotion) {
        Image(appIconForeground(this.iconName))
          .width($r('app.float.startup_mark_size')).height($r('app.float.startup_mark_size'))
          .objectFit(ImageFit.Contain).colorFilter(this.markColorFilter())
          .scale({ x: this.markScale, y: this.markScale }).opacity(this.markOpacity)
          .accessibilityLevel('no').hitTestBehavior(HitTestMode.None)
      } else if (this.artwork.length > 0 && !this.initialFrame) {
        if (this.play && !this.reduceMotion && this.foreground && !this.completed) {
          Video({ src: $rawfile('startup/' + this.artwork + '.mp4'), currentProgressRate: this.playbackRate() })
            .muted(true).autoPlay(true).controls(false).loop(false)
            .objectFit(ImageFit.Contain)
            .width('100%').aspectRatio(1)
            .constraintSize({ maxWidth: $r('app.float.startup_animation_size'),
              maxHeight: $r('app.float.startup_animation_size') })
            .backgroundColor(this.launchBackground())
            .onStart((): void => {
              hilog.info(0x0001, 'StartupAnimation', 'Playing %{public}s', this.artwork);
            })
            .onFinish((): void => this.finish())
            .onError((): void => this.finish())
            .accessibilityLevel('no').hitTestBehavior(HitTestMode.None)
        } else {
          // The exact last frame also covers Index's first frame, so routing
          // cannot flash a different icon, title or layout after the animation.
          Image($rawfile('startup/' + this.artwork + '.webp'))
            .objectFit(ImageFit.Contain).width('100%').aspectRatio(1)
            .constraintSize({ maxWidth: $r('app.float.startup_animation_size'),
              maxHeight: $r('app.float.startup_animation_size') })
            .backgroundColor(this.launchBackground())
            .accessibilityLevel('no').hitTestBehavior(HitTestMode.None)
        }
      }
    }.width('100%').height('100%')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
