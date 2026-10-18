import { display, window } from '@kit.ArkUI';
import { hdrCapability } from '@kit.ArkGraphics2D';
import { deviceInfo } from '@kit.BasicServicesKit';
import hilog from '@ohos.hilog';

export const STORAGE_KEY_VIDEO_HDR_SUPPORTED: string = 'harmonyx.video_hdr_supported';
const DOMAIN: number = 0xFF00;
const TAG: string = 'HarmonyX-HDR';
const AI_HDR_API_VERSION: number = 24;

// Capability belongs to the window's current display, not the device model.
// Do not persist it: an external display or a folded screen can differ.
export class VideoHdrCapability {
  private observedWindow: window.Window | null = null;
  private displayListener: (id: number) => void = (_id: number): void => this.refresh();
  private windowListener: (id: number) => void = (_id: number): void => this.refresh();

  observe(current: window.Window): void {
    this.stop();
    this.observedWindow = current;
    this.refresh();
    if (deviceInfo.sdkApiVersion < AI_HDR_API_VERSION) { return; }
    try {
      display.on('change', this.displayListener);
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'display capability listener unavailable');
    }
    try {
      current.on('displayIdChange', this.windowListener);
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'window display listener unavailable');
    }
  }

  refresh(): void {
    let supported: boolean = false;
    try {
      const current: window.Window | null = this.observedWindow;
      if (deviceInfo.sdkApiVersion >= AI_HDR_API_VERSION && current !== null) {
        const screen: display.Display = display.getDisplayByIdSync(current.getWindowProperties().displayId);
        supported = screen.hdrFormats.indexOf(hdrCapability.HDRFormat.VIDEO_AIHDR) >= 0;
        hilog.info(DOMAIN, TAG, 'AI HDR display=%{public}d supported=%{public}s formats=%{public}s',
          screen.id, supported.toString(), screen.hdrFormats.join(','));
      }
    } catch (error) {
      // A failed query must never prevent ordinary video playback.
      hilog.warn(DOMAIN, TAG, 'AI HDR capability query failed; using ordinary playback');
    }
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_VIDEO_HDR_SUPPORTED, supported);
  }

  stop(): void {
    const current: window.Window | null = this.observedWindow;
    this.observedWindow = null;
    if (current !== null && deviceInfo.sdkApiVersion >= AI_HDR_API_VERSION) {
      try { display.off('change', this.displayListener); } catch (error) {}
      try { current.off('displayIdChange', this.windowListener); } catch (error) {}
    }
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_VIDEO_HDR_SUPPORTED, false);
  }
}

// XComponent AIHDR expands SDR content in the system rendering pipeline.
// Keeping this on the existing surface preserves AVPlayer handoff and PiP.
export class VideoHdrEnhancementModifier implements AttributeModifier<XComponentAttribute> {
  private enabled: boolean;
  private supported: boolean;

  constructor(enabled: boolean, supported: boolean) {
    this.enabled = enabled;
    this.supported = supported;
  }

  applyNormalAttribute(instance: XComponentAttribute): void {
    // HdrType and the two-argument overload were introduced in API 24.
    if (deviceInfo.sdkApiVersion < AI_HDR_API_VERSION) { return; }
    try {
      instance.hdrBrightness(1, this.enabled && this.supported ? HdrType.AIHDR : HdrType.DEFAULT);
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'AI HDR unavailable; restoring ordinary playback');
      try { instance.hdrBrightness(1, HdrType.DEFAULT); } catch (fallbackError) {}
    }
  }
}

export const videoHdrCapability: VideoHdrCapability = new VideoHdrCapability();
