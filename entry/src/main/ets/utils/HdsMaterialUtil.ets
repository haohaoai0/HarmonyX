import { deviceInfo } from '@kit.BasicServicesKit';

/**
 * Minimal HDS material capability helper shared by the Mark-dev HdsButton.
 * HDS floating material is available from SDK API 23 onward.
 */
export class HdsMaterialUtil {
  public static isHdsMaterialAvailable(): boolean {
    return deviceInfo.sdkApiVersion >= 23;
  }

  public static resolveLegacyHdsMaterialLevel(level: number): number {
    if (level <= 0) {
      return 0;
    }
    if (level <= 6) {
      return 1;
    }
    if (level <= 10) {
      return 2;
    }
    return 10;
  }
}
