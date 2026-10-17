import { hdsEffect } from '@kit.UIDesignKit';

export const POINT_LIGHT_PRESS_INTENSITY: number = 2;
export const POINT_LIGHT_HEIGHT: number = 130;

export function buildPointLightEffect(intensity: number,
  illuminatedType: hdsEffect.PointLightIlluminatedType =
    hdsEffect.PointLightIlluminatedType.BORDER_CONTENT): VisualEffect {
  return new hdsEffect.HdsEffectBuilder()
    .pointLight({
      // sourceType overrides options, so custom intensity uses options alone.
      options: { color: Color.White, intensity: intensity, height: POINT_LIGHT_HEIGHT },
      illuminatedType: illuminatedType
    })
    .buildEffect();
}
