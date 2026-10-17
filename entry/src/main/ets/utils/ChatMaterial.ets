import { uiMaterial } from '@kit.ArkUI';
import { SystemMaterialUtil } from './SystemMaterial';

// Match ReplyComposer's native control/capsule materials and the same stored
// thickness preferences. The page owns a single material per capsule.
export function chatControlMaterial(accent: ResourceColor): uiMaterial.Material | undefined {
  if (!SystemMaterialUtil.isApi26OrAbove()) { return undefined; }
  return new uiMaterial.ImmersiveMaterial({
    style: uiMaterial.ImmersiveStyle.THIN, interactive: true,
    applyShadow: false, colorInvert: true, lightEffect: { color: accent }
  });
}

export function chatInputMaterial(level: number): uiMaterial.Material | undefined {
  if (!SystemMaterialUtil.isApi26OrAbove()) { return undefined; }
  return new uiMaterial.ImmersiveMaterial({
    style: SystemMaterialUtil.resolveImmersiveStyle(level), interactive: true,
    applyShadow: false, colorInvert: true, lightEffect: {}
  });
}

export function chatTintedControlMaterial(tint: ResourceColor): uiMaterial.Material | undefined {
  if (!SystemMaterialUtil.isApi26OrAbove()) { return undefined; }
  return new uiMaterial.ImmersiveMaterial({
    style: uiMaterial.ImmersiveStyle.THIN, interactive: true, materialColor: tint,
    applyShadow: false, colorInvert: false, lightEffect: { color: tint }
  });
}

export function chatPageMaterial(): uiMaterial.Material | undefined {
  if (!SystemMaterialUtil.isApi26OrAbove()) { return undefined; }
  return new uiMaterial.ImmersiveMaterial({
    style: uiMaterial.ImmersiveStyle.REGULAR, applyShadow: true, colorInvert: true
  });
}
