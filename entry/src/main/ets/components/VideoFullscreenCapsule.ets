import { MaterialButton } from './MaterialButton';
import { motionDuration } from '../utils/AppMotion';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';

const FULLSCREEN_CAPSULE_VISIBLE_MS: number = 3000;

@Component
export struct VideoFullscreenCapsule {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp('reduceMotionEnabled') private reduceMotion: boolean = false;
  @Prop @Watch('reveal') mediaId: string = '';
  @Prop @Watch('reveal') surfaceTapSerial: number = 0;
  @Prop @Watch('reveal') active: boolean = false;
  onOpenFullscreen: () => void = (): void => {};
  @State private visible: boolean = false;
  private hideTimer: number = -1;

  aboutToAppear(): void { this.reveal(); }

  aboutToDisappear(): void { this.clearHideTimer(); }

  private clearHideTimer(): void {
    if (this.hideTimer >= 0) {
      clearTimeout(this.hideTimer);
      this.hideTimer = -1;
    }
  }

  private reveal(): void {
    this.clearHideTimer();
    this.setVisible(this.active);
    if (!this.active) { return; }
    this.hideTimer = setTimeout((): void => {
      this.hideTimer = -1;
      this.setVisible(false);
    }, FULLSCREEN_CAPSULE_VISIBLE_MS);
  }

  private setVisible(visible: boolean): void {
    if (this.visible === visible) { return; }
    this.getUIContext().animateTo({ duration: this.reduceMotion ? 0 : motionDuration(180), curve: Curve.EaseOut }, (): void => {
      this.visible = visible;
    });
  }

  build(): void {
    Row() {
      MaterialButton({ nativeMaterialHost: true, buttonWidth: 136, buttonHeight: 40, buttonRadius: 20,
        materialLevel: 2, applyShadow: true, surfaceColor: $r('app.color.video_episode_surface'),
        buttonPressFeedback: true,
        buttonEnabled: this.visible,
        accessibilityLabel: this.getUIContext().getHostContext()?.resourceManager.getStringSync($r('app.string.video_fullscreen_play')) ?? '',
        onButtonClick: (): void => this.onOpenFullscreen() }) {
        Row({ space: 6 }) {
          SymbolGlyph($r('sys.symbol.arrow_up_left_and_arrow_down_right')).fontSize(18)
            .fontColor([$r('app.color.text_on_brand')])
          Text($r('app.string.video_fullscreen_play')).fontFamily(this.appFontFamily).fontSize(14)
            .fontColor($r('app.color.text_on_brand'))
        }
      }
    }.width(136).height(40)
      .renderGroup(true)
      .opacity(this.visible ? 1 : 0)
      .hitTestBehavior(this.visible ? HitTestMode.Default : HitTestMode.None)
      .accessibilityLevel(this.visible ? 'auto' : 'no-hide-descendants')
  }
}
