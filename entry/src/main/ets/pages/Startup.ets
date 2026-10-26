import { StartupAnimation } from '../components/StartupAnimation';
import { startupSession } from '../utils/StartupSession';
import { FrameCallback } from '@kit.ArkUI';
import { STORAGE_KEY_STARTUP_MODE, STARTUP_MODE_NONE, STARTUP_MODE_VIDEO } from '../services/StartupSettingsStore';

class StartupBridgeFrame extends FrameCallback {
  private ready: () => void;
  constructor(ready: () => void) { super(); this.ready = ready; }
  onIdle: (timeLeftInNano: number) => void = (_timeLeftInNano: number): void => { this.ready(); };
}

@Entry
@Component
struct Startup {
  @State private failed: boolean = false;
  @StorageProp(STORAGE_KEY_STARTUP_MODE) private startupMode: string = STARTUP_MODE_VIDEO;
  private alive: boolean = false;
  private opening: boolean = false;
  private timer: number = -1;

  aboutToAppear(): void {
    this.alive = true;
    startupSession.begin();
    // Mount home behind its cover so cache restore and refresh run in parallel.
    this.timer = setTimeout((): void => this.openHome(), 32);
    this.getUIContext().postFrameCallback(new StartupBridgeFrame((): void => this.openHome()));
  }

  aboutToDisappear(): void {
    this.alive = false;
    if (this.timer >= 0) { clearTimeout(this.timer); this.timer = -1; }
  }

  onBackPress(): boolean { this.openHome(); return true; }

  private openHome(): void {
    if (!this.alive || this.opening) { return; }
    this.opening = true;
    if (this.timer >= 0) { clearTimeout(this.timer); this.timer = -1; }
    this.failed = false;
    startupSession.begin();
    this.getUIContext().getRouter().replaceUrl({ url: 'pages/Index' }).catch((): void => {
      if (!this.alive) { return; }
      this.opening = false;
      this.failed = true;
      startupSession.cancel();
    });
  }

  pageTransition(): void {
    PageTransitionEnter({ duration: 0 })
    PageTransitionExit({ duration: 0 })
  }

  build(): void {
    Stack({ alignContent: Alignment.Bottom }) {
      if (this.startupMode !== STARTUP_MODE_NONE) {
        StartupAnimation({ mode: this.startupMode, initialFrame: true })
      }
      if (this.failed) {
        Button($r('app.string.xxauth_retry'))
          .onClick((): void => this.openHome())
          .margin({ bottom: 48 })
      }
    }
    .width('100%').height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
