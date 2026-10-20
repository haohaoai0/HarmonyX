import { display, window } from '@kit.ArkUI';

export const STORAGE_KEY_VIDEO_FULLSCREEN_OWNER: string = 'harmonyx.video_fullscreen_owner';

// Pura X's inner display can rotate even though its phone desktop cannot.
// Use the same policy at launch and when a fullscreen player restores the app.
export function appWindowOrientation(): window.Orientation {
  try {
    if (display.isFoldable()) {
      return window.Orientation.AUTO_ROTATION_RESTRICTED;
    }
  } catch (error) {
    // Keep the declared desktop policy if display capabilities are unavailable.
  }
  return window.Orientation.FOLLOW_DESKTOP;
}
