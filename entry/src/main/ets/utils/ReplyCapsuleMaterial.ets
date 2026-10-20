import { uiMaterial } from '@kit.ArkUI';
import { SystemMaterialUtil } from './SystemMaterial';

// The live composer and appearance specimen share the same native materials.
export function replyCapsuleMaterial(enabled: boolean, level: number): uiMaterial.Material | undefined {
  if (!enabled) { return undefined; }
  return SystemMaterialUtil.immersiveMaterial(level, true, false, true, '#FFFFFFFF');
}

export function replyCapsuleControlMaterial(enabled: boolean, accent: ResourceColor,
  level: number = 1): uiMaterial.Material | undefined {
  if (!enabled) { return undefined; }
  return SystemMaterialUtil.immersiveMaterial(level, true, false, true, accent);
}
