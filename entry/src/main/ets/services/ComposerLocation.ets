import { abilityAccessCtrl, bundleManager, common } from '@kit.AbilityKit';
import type { PermissionRequestResult, Permissions } from '@kit.AbilityKit';
import { geoLocationManager } from '@kit.LocationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { ComposerCoordinates } from '../models/ComposerOptions';

export class ComposerLocationResult {
  coordinates: ComposerCoordinates | null = null;
  error: string = '';
  code: number = 0;
}

// One foreground fix per explicit location action. Coordinates are used for
// the nearby-place request; only the selected X place is kept in a draft.
export async function getComposerLocation(context: common.UIAbilityContext): Promise<ComposerLocationResult> {
  const result: ComposerLocationResult = new ComposerLocationResult();
  const permissions: Permissions[] = ['ohos.permission.APPROXIMATELY_LOCATION', 'ohos.permission.LOCATION'];
  const manager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
  try {
    const info: bundleManager.BundleInfo = bundleManager.getBundleInfoForSelfSync(
      bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
    let granted: boolean = manager.checkAccessTokenSync(info.appInfo.accessTokenId, permissions[0]) ===
      abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
    if (!granted) {
      const request: PermissionRequestResult = await manager.requestPermissionsFromUser(context, permissions);
      granted = request.authResults.length > 0 && request.authResults[0] === 0;
    }
    if (!granted) { result.error = 'denied'; return result; }
    if (!geoLocationManager.isLocationEnabled()) { result.error = 'disabled'; return result; }
    const request: geoLocationManager.CurrentLocationRequest = {
      priority: geoLocationManager.LocationRequestPriority.FIRST_FIX, timeoutMs: 15000
    };
    const location: geoLocationManager.Location = await geoLocationManager.getCurrentLocation(request);
    if (!Number.isFinite(location.latitude) || !Number.isFinite(location.longitude) ||
      Math.abs(location.latitude) > 90 || Math.abs(location.longitude) > 180) {
      result.error = 'unavailable'; return result;
    }
    const coordinates: ComposerCoordinates = new ComposerCoordinates();
    coordinates.latitude = location.latitude; coordinates.longitude = location.longitude;
    coordinates.accuracy = location.accuracy;
    result.coordinates = coordinates;
  } catch (error) {
    result.error = 'unavailable'; result.code = (error as BusinessError).code ?? 0;
  }
  return result;
}
