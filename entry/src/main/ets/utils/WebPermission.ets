// Capture permissions for the Web component.
//
// ArkWeb never asks the reader itself: a page's getUserMedia request arrives as
// an onPermissionRequest event, and a request the app does not answer is a
// denial. The app therefore has to (1) hold the matching system permission and
// (2) hand the resource to the page. The origin allowlist keeps the second step
// limited to the pages this app owns instead of every site opened in a web
// surface.
import { abilityAccessCtrl, bundleManager, common } from '@kit.AbilityKit';
import type { PermissionRequestResult, Permissions } from '@kit.AbilityKit';
import hilog from '@ohos.hilog';

const DOMAIN: number = 0xFF00;
const TAG: string = 'HarmonyX-WebPerm';
const MICROPHONE_PERMISSION: Permissions = 'ohos.permission.MICROPHONE';

// Values of the platform's ProtectedResourceType enum, spelled out because the
// enum only exists inside the ArkUI component declarations.
export const WEB_AUDIO_CAPTURE: string = 'TYPE_AUDIO_CAPTURE';
export const WEB_VIDEO_CAPTURE: string = 'TYPE_VIDEO_CAPTURE';

class WebPermission {
  private microphoneGranted: boolean = false;

  // Origins allowed to record: X's own pages (voice notes in the message
  // surface) and Grok's web client, which the app opens as a first-class
  // surface.
  private static readonly MICROPHONE_ORIGINS: string[] = [
    'grok.com',
    'x.ai',
    'x.com',
    'twitter.com'
  ];

  isOriginAllowed(origin: string): boolean {
    if (origin.length === 0) {
      return false;
    }
    let host: string = origin;
    const scheme: number = host.indexOf('://');
    if (scheme >= 0) {
      host = host.substring(scheme + 3);
    }
    const slash: number = host.indexOf('/');
    if (slash >= 0) {
      host = host.substring(0, slash);
    }
    const port: number = host.indexOf(':');
    if (port >= 0) {
      host = host.substring(0, port);
    }
    host = host.toLowerCase();
    for (let i: number = 0; i < WebPermission.MICROPHONE_ORIGINS.length; i++) {
      const allowed: string = WebPermission.MICROPHONE_ORIGINS[i];
      if (host === allowed || host.endsWith('.' + allowed)) {
        return true;
      }
    }
    return false;
  }

  // Holds the system permission, asking the reader the first time. The Web
  // resource can only be granted once the app itself may record.
  async canUseMicrophone(context: common.UIAbilityContext, origin: string): Promise<boolean> {
    if (!this.isOriginAllowed(origin)) {
      return false;
    }
    if (this.microphoneGranted) {
      return true;
    }
    const manager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
    try {
      const status: abilityAccessCtrl.GrantStatus = manager.checkAccessTokenSync(
        this.tokenId(), MICROPHONE_PERMISSION);
      if (status === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
        this.microphoneGranted = true;
        return true;
      }
      const result: PermissionRequestResult =
        await manager.requestPermissionsFromUser(context, [MICROPHONE_PERMISSION]);
      const results: number[] = result.authResults;
      const granted: boolean = results.length > 0 && results[0] === 0;
      this.microphoneGranted = granted;
      return granted;
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'microphone request failed: %{public}s', JSON.stringify(error));
      return false;
    }
  }

  private tokenId(): number {
    const info: bundleManager.BundleInfo = bundleManager.getBundleInfoForSelfSync(
      bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
    return info.appInfo.accessTokenId;
  }
}

export const webPermission: WebPermission = new WebPermission();
