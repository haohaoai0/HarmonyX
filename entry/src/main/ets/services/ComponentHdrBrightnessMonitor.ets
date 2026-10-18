import { display, window } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';
import hilog from '@ohos.hilog';

const BRIGHTNESS_INFO_API_VERSION: number = 22;
const DOMAIN: number = 0xFF00;
const TAG: string = 'HarmonyX-UI-HDR';

export class ComponentHdrBrightnessInfo {
  available: boolean = false;
  maxRatio: number = 0;
  displayId: number = -1;
}

// Brightness headroom belongs to the display hosting the settings window.
// Observe it only while the settings component exists; never persist it.
export class ComponentHdrBrightnessMonitor {
  private observedWindow: window.Window | null = null;
  private onChange: (info: ComponentHdrBrightnessInfo) => void = (_info: ComponentHdrBrightnessInfo): void => {};
  private brightnessListening: boolean = false;
  private displayListening: boolean = false;
  private windowListening: boolean = false;
  private lastMaxRatio: number = -1;
  private lastDisplayId: number = -1;
  private brightnessListener: display.BrightnessCallback<number, display.BrightnessInfo> =
    (id: number, _info: display.BrightnessInfo): void => {
      const current: window.Window | null = this.observedWindow;
      if (current === null) { return; }
      try {
        if (current.getWindowProperties().displayId === id) { this.refresh(); }
      } catch (error) { this.refresh(); }
    };
  private displayListener: (id: number) => void = (_id: number): void => this.refresh();
  private windowListener: (id: number) => void = (_id: number): void => this.refresh();

  observe(current: window.Window, onChange: (info: ComponentHdrBrightnessInfo) => void): void {
    this.stop();
    this.observedWindow = current;
    this.onChange = onChange;
    this.refresh();
    if (deviceInfo.sdkApiVersion < BRIGHTNESS_INFO_API_VERSION) { return; }
    try {
      display.on('brightnessInfoChange', this.brightnessListener);
      this.brightnessListening = true;
    } catch (error) {}
    try {
      display.on('change', this.displayListener);
      this.displayListening = true;
    } catch (error) {}
    try {
      current.on('displayIdChange', this.windowListener);
      this.windowListening = true;
    } catch (error) {}
  }

  refresh(): void {
    const current: window.Window | null = this.observedWindow;
    if (current === null) { return; }
    const result: ComponentHdrBrightnessInfo = new ComponentHdrBrightnessInfo();
    try {
      if (deviceInfo.sdkApiVersion >= BRIGHTNESS_INFO_API_VERSION) {
        const id: number | undefined = current.getWindowProperties().displayId;
        if (id !== undefined && Number.isInteger(id) && id >= 0) {
          const info: display.BrightnessInfo = display.getBrightnessInfo(id);
          if (Number.isFinite(info.maxHeadroom) && info.maxHeadroom >= 1) {
            result.available = true;
            result.maxRatio = info.maxHeadroom;
            result.displayId = id;
            if (this.lastMaxRatio !== result.maxRatio || this.lastDisplayId !== id) {
              hilog.info(DOMAIN, TAG, 'screen HDR maximum display=%{public}d maxHeadroom=%{public}s',
                id, result.maxRatio.toString());
            }
          }
        }
      }
    } catch (error) {
      // Unknown is different from a reported 1x. Do not invent a device limit.
      hilog.warn(DOMAIN, TAG, 'screen HDR maximum unavailable');
    }
    this.lastMaxRatio = result.maxRatio;
    this.lastDisplayId = result.displayId;
    this.onChange(result);
  }

  stop(): void {
    const current: window.Window | null = this.observedWindow;
    this.observedWindow = null;
    if (this.brightnessListening) {
      try { display.off('brightnessInfoChange', this.brightnessListener); } catch (error) {}
    }
    if (this.displayListening) {
      try { display.off('change', this.displayListener); } catch (error) {}
    }
    if (current !== null && this.windowListening) {
      try { current.off('displayIdChange', this.windowListener); } catch (error) {}
    }
    this.brightnessListening = false;
    this.displayListening = false;
    this.windowListening = false;
    this.lastMaxRatio = -1;
    this.lastDisplayId = -1;
    this.onChange = (_info: ComponentHdrBrightnessInfo): void => {};
  }
}
