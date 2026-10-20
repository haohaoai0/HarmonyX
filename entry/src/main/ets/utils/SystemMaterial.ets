import { CommonModifier, uiMaterial } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';

class ImmersiveMaterialAttribute extends CommonModifier {
  private material: uiMaterial.Material | undefined;

  constructor(material: uiMaterial.Material | undefined) {
    super();
    this.material = material;
  }

  applyNormalAttribute(instance: CommonAttribute): void {
    if (!deviceInfo.apiAvailable('26.0.0')) {
      return;
    }
    if (this.material === undefined || !uiMaterial.isImmersiveMaterialSupported()) {
      instance.systemMaterial(uiMaterial.Material.empty);
      return;
    }
    instance.systemMaterial(this.material);
  }
}

export function materialModifier(material: uiMaterial.Material | undefined): CommonModifier {
  return new ImmersiveMaterialAttribute(material);
}

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
    if (deviceInfo.apiAvailable('26.0.0')) {
      if (!uiMaterial.isImmersiveMaterialSupported()) {
        return undefined;
      }
      return new uiMaterial.ImmersiveMaterial({
        style: SystemMaterialUtil.resolveImmersiveStyle(level),
        interactive: interactive,
        applyShadow: applyShadow,
        colorInvert: colorInvert,
        materialColor: materialColor,
        lightEffect: interactive && lightColor !== undefined ? { color: lightColor } : null
      });
    }
    return undefined;
  }
}
