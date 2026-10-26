import { FrameCallback } from '@kit.ArkUI';
import { StartupAnimation } from './StartupAnimation';
import { STARTUP_MODE_NONE, STARTUP_MODE_IOS, STARTUP_MODE_VIDEO, STORAGE_KEY_STARTUP_MODE, STORAGE_KEY_STARTUP_SPEED,
  normaliseStartupMode } from '../services/StartupSettingsStore';
import { STARTUP_BRAND_DURATION, STARTUP_COVER_TIMEOUT, STARTUP_EXIT_DURATION, STARTUP_NATIVE_TIMEOUT,
  startupVideoTimeout, STARTUP_IOS_ANTICIPATION, STARTUP_IOS_EXIT_DURATION,
  STARTUP_IOS_ZOOM_SCALE } from '../utils/StartupSession';

class StartupReadyFrame extends FrameCallback {
  private ready: () => void;
  constructor(ready: () => void) { super(); this.ready = ready; }
  onIdle: (timeLeftInNano: number) => void = (_timeLeftInNano: number): void => { this.ready(); };
}

@Component
export struct StartupCover {
  @Prop playAnimation: boolean = true;
  @Prop @Watch('tryLeave') contentReady: boolean = false;
  onFinished: () => void = (): void => {};
  @StorageProp(STORAGE_KEY_STARTUP_MODE) private startupMode: string = STARTUP_MODE_VIDEO;
  @StorageProp(STORAGE_KEY_STARTUP_SPEED) private playbackSpeed: number = 1;
  @StorageProp('reduceMotionEnabled') @Watch('onEligibilityChanged') private reduceMotion: boolean = false;
  @StorageProp('harmonyx.app_foreground') @Watch('onEligibilityChanged') private foreground: boolean = true;
  @State private mode: string = STARTUP_MODE_VIDEO;
  @State private coverOpacity: number = 1;
  @State private markScale: number = 1;
  @State private backgroundOpacity: number = 1;
  @State private markOpacity: number = 1;
  private alive: boolean = false;
  private leaving: boolean = false;
  private finished: boolean = false;
  private frameReady: boolean = false;
  private animationReady: boolean = false;
  private timer: number = -1;
  private holdTimer: number = -1;
  private exitTimer: number = -1;
  private revision: number = 0;

  aboutToAppear(): void {
    this.alive = true;
    this.leaving = false;
    this.finished = false;
    this.frameReady = false;
    this.animationReady = !this.playAnimation || this.reduceMotion;
    this.mode = normaliseStartupMode(this.startupMode);
    this.coverOpacity = 1;
    this.markScale = 1;
    this.backgroundOpacity = 1;
    this.markOpacity = 1;
    if (this.mode === STARTUP_MODE_NONE) { this.finish(); return; }
    const revision: number = ++this.revision;
    const timeout: number = !this.playAnimation || this.reduceMotion ? STARTUP_COVER_TIMEOUT :
      (this.mode === STARTUP_MODE_VIDEO ? startupVideoTimeout(this.playbackSpeed) + STARTUP_EXIT_DURATION : STARTUP_NATIVE_TIMEOUT);
    // An absolute deadline covers an offline feed, missing frame or stalled decoder.
    this.timer = setTimeout((): void => this.leave(), timeout);
    if (this.playAnimation && !this.reduceMotion && this.mode !== STARTUP_MODE_VIDEO) {
      this.holdTimer = setTimeout((): void => {
        this.holdTimer = -1;
        this.onAnimationFinished();
      }, STARTUP_BRAND_DURATION);
    }
    this.getUIContext().postFrameCallback(new StartupReadyFrame((): void => {
      if (this.revision !== revision || !this.alive) { return; }
      this.frameReady = true;
      this.tryLeave();
    }));
    if (!this.foreground) { this.finish(); }
  }

  aboutToDisappear(): void {
    this.alive = false;
    ++this.revision;
    this.clearTimers();
  }

  private clearTimers(): void {
    if (this.timer >= 0) { clearTimeout(this.timer); this.timer = -1; }
    if (this.holdTimer >= 0) { clearTimeout(this.holdTimer); this.holdTimer = -1; }
    if (this.exitTimer >= 0) { clearTimeout(this.exitTimer); this.exitTimer = -1; }
  }

  private onEligibilityChanged(): void {
    if (!this.foreground) { this.finish(); return; }
    if (this.reduceMotion) {
      this.animationReady = true;
      if (this.leaving) { this.finish(); } else { this.tryLeave(); }
    }
  }

  private onAnimationFinished(): void {
    if (!this.alive || this.finished) { return; }
    this.animationReady = true;
    this.tryLeave();
  }

  private tryLeave(): void {
    if (!this.frameReady || !this.animationReady) { return; }
    if (this.playAnimation && !this.reduceMotion && !this.contentReady) { return; }
    this.leave();
  }

  private leave(): void {
    if (!this.alive || this.leaving || this.finished) { return; }
    this.leaving = true;
    this.clearTimers();
    if (this.reduceMotion || !this.foreground) { this.finish(); return; }
    if (this.playAnimation && this.mode === STARTUP_MODE_IOS) {
      this.getUIContext().animateTo({ duration: STARTUP_IOS_ANTICIPATION, curve: Curve.EaseOut }, (): void => {
        this.markScale = 0.82;
      });
      this.exitTimer = setTimeout((): void => {
        this.exitTimer = -1;
        if (!this.alive || this.finished) { return; }
        this.getUIContext().animateTo({ duration: STARTUP_IOS_EXIT_DURATION, curve: Curve.EaseIn }, (): void => {
          this.markScale = STARTUP_IOS_ZOOM_SCALE;
          this.backgroundOpacity = 0;
          this.markOpacity = 0;
        });
        this.scheduleFinish(STARTUP_IOS_EXIT_DURATION);
      }, STARTUP_IOS_ANTICIPATION);
      return;
    }
    this.getUIContext().animateTo({ duration: STARTUP_EXIT_DURATION, curve: Curve.EaseOut }, (): void => {
      this.coverOpacity = 0;
    });
    this.scheduleFinish(STARTUP_EXIT_DURATION);
  }

  private scheduleFinish(duration: number): void {
    this.exitTimer = setTimeout((): void => { this.exitTimer = -1; this.finish(); }, duration);
  }

  private finish(): void {
    if (!this.alive || this.finished) { return; }
    this.finished = true;
    this.clearTimers();
    this.onFinished();
  }

  build(): void {
    StartupAnimation({ mode: this.mode, play: this.playAnimation, markScale: this.markScale,
      backgroundOpacity: this.backgroundOpacity, markOpacity: this.markOpacity,
      onFinished: (): void => this.onAnimationFinished() })
      .opacity(this.coverOpacity)
      .renderGroup(true)
      .hitTestBehavior(HitTestMode.Block)
      .id('app-startup-cover')
  }
}
