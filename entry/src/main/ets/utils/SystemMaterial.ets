import { uiMaterial } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';

export class SystemMaterialUtil {
  public static isApi26OrAbove(): boolean {
    return deviceInfo.apiAvailable('26.0.0');
  }

  public static resolveImmersiveStyle(level: number): uiMaterial.ImmersiveStyle {
    if (level <= 0) {
      return uiMaterial.ImmersiveStyle.ULTRA_THIN;
    }
    if (level === 1) {
      return uiMaterial.ImmersiveStyle.THIN;
    }
    if (level === 3) {
      return uiMaterial.ImmersiveStyle.THICK;
    }
    if (level >= 4) {
      return uiMaterial.ImmersiveStyle.ULTRA_THICK;
    }
    return uiMaterial.ImmersiveStyle.REGULAR;
  }

  public static immersiveMaterial(
    level: number,
    interactive: boolean,
    applyShadow: boolean,
    colorInvert: boolean,
    lightColor: ResourceColor | undefined,
    materialColor: ResourceColor | undefined = undefined
  ): uiMaterial.Material | undefined {
    if (!SystemMaterialUtil.isApi26OrAbove()) {
      return undefined;
    }
    return new uiMaterial.ImmersiveMaterial({
      style: SystemMaterialUtil.resolveImmersiveStyle(level),
      interactive: false,
      applyShadow: applyShadow,
      colorInvert: colorInvert,
      materialColor: materialColor,
      lightEffect: null
    });
  }
}
