import { uiMaterial } from '@kit.ArkUI';
import { SystemMaterialUtil } from './SystemMaterial';

// Match ReplyComposer's native control/capsule materials and the same stored
// thickness preferences. The page owns a single material per capsule.
export function chatControlMaterial(accent: ResourceColor): uiMaterial.Material | undefined {
  return SystemMaterialUtil.immersiveMaterial(1, true, false, true, accent);
}

export function chatInputMaterial(level: number): uiMaterial.Material | undefined {
  return SystemMaterialUtil.immersiveMaterial(level, true, false, true, Color.White);
}

export function chatTintedControlMaterial(tint: ResourceColor): uiMaterial.Material | undefined {
  return SystemMaterialUtil.immersiveMaterial(1, true, false, false, tint, tint);
}

export function chatPageMaterial(): uiMaterial.Material | undefined {
  return SystemMaterialUtil.immersiveMaterial(2, false, true, true, undefined);
}
