// Five backgroundBlurStyle strengths corresponding to the native material
// selector. API 26 material construction stays gated by SystemMaterialUtil.
export function desktopRailBlurStyle(level: number): BlurStyle {
  if (level === 0) { return BlurStyle.COMPONENT_ULTRA_THIN; }
  if (level === 1) { return BlurStyle.COMPONENT_THIN; }
  if (level === 3) { return BlurStyle.COMPONENT_THICK; }
  if (level === 4) { return BlurStyle.COMPONENT_ULTRA_THICK; }
  return BlurStyle.COMPONENT_REGULAR;
}
