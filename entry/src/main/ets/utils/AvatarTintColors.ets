/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0.
 * Adapted from icon-main-color-master (ColorUtils.ets / ImageUtils.ets).
 * Changes: representative avatar hue, neutral colors, separate light/dark algorithms.
 */
import { ColorMetrics } from '@kit.ArkUI';
import { DARK_SURFACE_GENTLE, DISPLAY_MODE_DARK, DISPLAY_MODE_LIGHT } from '../services/AppearanceStore';
import { XUserParser } from '../services/XUserParser';
import { pageSurfaceColor } from './ThemeColors';

export const AVATAR_TINT_SAMPLE_SIZE: number = 40;

export class AvatarTintPalette {
  avatarUrl: string = '';
  light: string = '';
  dark: string = '';
  gentleDark: string = '';
}

interface AvatarHsv {
  hue: number;
  saturation: number;
  value: number;
}

class ColorBucket {
  count: number = 0;
  weight: number = 0;
  red: number = 0;
  green: number = 0;
  blue: number = 0;
}

export class AvatarTintColors {
  static fromPixels(pixels: Uint8Array, url: string): AvatarTintPalette | null {
    const buckets: Map<number, ColorBucket> = new Map();
    const hues: Map<number, ColorBucket> = new Map();
    let dominant: ColorBucket | null = null;
    let chromatic: ColorBucket | null = null;
    let visibleCount: number = 0;
    for (let index: number = 0; index + 3 < pixels.length; index += 4) {
      // BGRA_8888: skip transparent edges instead of treating them as black.
      if (pixels[index + 3] < 128) {
        continue;
      }
      const pixelIndex: number = index / 4;
      const halfSize: number = AVATAR_TINT_SAMPLE_SIZE / 2;
      const x: number = (pixelIndex % AVATAR_TINT_SAMPLE_SIZE + 0.5 - halfSize) / halfSize;
      const y: number = (Math.floor(pixelIndex / AVATAR_TINT_SAMPLE_SIZE) + 0.5 - halfSize) / halfSize;
      const distance: number = Math.sqrt(x * x + y * y);
      // Discard square corners hidden by the displayed avatar's round mask.
      if (distance > 1) {
        continue;
      }
      visibleCount++;
      const red: number = pixels[index + 2];
      const green: number = pixels[index + 1];
      const blue: number = pixels[index];
      // Photos rarely contain identical pixels. Group nearby RGB values while
      // averaging the winning bin to preserve its actual hue.
      const key: number = ((red >> 4) << 8) | ((green >> 4) << 4) | (blue >> 4);
      let bucket: ColorBucket | undefined = buckets.get(key);
      if (bucket === undefined) {
        bucket = new ColorBucket();
        buckets.set(key, bucket);
      }
      bucket.count++;
      bucket.red += red;
      bucket.green += green;
      bucket.blue += blue;
      if (dominant === null || bucket.count > dominant.count) {
        dominant = bucket;
      }
      const pixelHsv: AvatarHsv = AvatarTintColors.rgbToHsv(red, green, blue);
      if (pixelHsv.saturation >= 0.06 && pixelHsv.value >= 0.12) {
        // Nearby shades of one hue form a single population. A white/gray
        // backdrop should not beat a logo or face simply because its pixels
        // are more identical. Center pixels have a modest extra vote.
        const hueKey: number = Math.floor(((pixelHsv.hue + 7.5) % 360) / 15);
        let hueBucket: ColorBucket | undefined = hues.get(hueKey);
        if (hueBucket === undefined) {
          hueBucket = new ColorBucket();
          hues.set(hueKey, hueBucket);
        }
        const weight: number = (1 + 0.5 * (1 - distance)) * (0.4 + 0.6 * pixelHsv.saturation);
        hueBucket.count++;
        hueBucket.weight += weight;
        hueBucket.red += red * weight;
        hueBucket.green += green * weight;
        hueBucket.blue += blue * weight;
        if (chromatic === null || hueBucket.weight > chromatic.weight) {
          chromatic = hueBucket;
        }
      }
    }
    if (dominant === null) {
      return null;
    }
    // Do not let a few colored compression artifacts tint an otherwise
    // monochrome avatar. A real colored subject must occupy at least 6%.
    const useChroma: boolean = chromatic !== null && chromatic.count >= visibleCount * 0.06;
    const selected: ColorBucket = useChroma && chromatic !== null ? chromatic : dominant;
    const divisor: number = useChroma ? selected.weight : selected.count;
    const red: number = selected.red / divisor;
    const green: number = selected.green / divisor;
    const blue: number = selected.blue / divisor;
    const hsv: AvatarHsv = AvatarTintColors.rgbToHsv(red, green, blue);
    const palette: AvatarTintPalette = new AvatarTintPalette();
    palette.avatarUrl = url;
    // Light blends the actual RGB with white. Unlike a fixed S/V replacement,
    // this keeps the source's color relationships and saturation differences.
    const neutral: boolean = !useChroma || hsv.saturation < 0.04;
    palette.light = neutral ? AvatarTintColors.hsvToHex(0, 0, 0.95) :
      '#' + AvatarTintColors.hexByte((255 * 0.78 + red * 0.22) / 255) +
      AvatarTintColors.hexByte((255 * 0.78 + green * 0.22) / 255) +
      AvatarTintColors.hexByte((255 * 0.78 + blue * 0.22) / 255);
    // Dark preserves hue and proportional chroma, lowering value separately.
    const darkS: number = neutral ? 0 : Math.min(0.68, hsv.saturation * 0.82);
    const darkV: number = 0.12 + hsv.value * 0.07;
    palette.dark = AvatarTintColors.hsvToHex(hsv.hue, darkS, darkV);
    palette.gentleDark = AvatarTintColors.hsvToHex(hsv.hue, darkS, darkV + 0.04);
    return palette;
  }

  private static rgbToHsv(red: number, green: number, blue: number): AvatarHsv {
    const r: number = red / 255;
    const g: number = green / 255;
    const b: number = blue / 255;
    const max: number = Math.max(r, g, b);
    const min: number = Math.min(r, g, b);
    const delta: number = max - min;
    let hue: number = 0;
    if (delta > 0) {
      if (max === r) {
        hue = ((g - b) / delta) * 60;
      } else if (max === g) {
        hue = ((b - r) / delta + 2) * 60;
      } else {
        hue = ((r - g) / delta + 4) * 60;
      }
      if (hue < 0) {
        hue += 360;
      }
    }
    return { hue: hue, saturation: max === 0 ? 0 : delta / max, value: max };
  }

  private static hsvToHex(hue: number, saturation: number, value: number): string {
    const sector: number = Math.floor(hue / 60) % 6;
    const fraction: number = hue / 60 - Math.floor(hue / 60);
    const p: number = value * (1 - saturation);
    const q: number = value * (1 - fraction * saturation);
    const t: number = value * (1 - (1 - fraction) * saturation);
    const red: number[] = [value, q, p, p, t, value];
    const green: number[] = [t, value, value, q, p, p];
    const blue: number[] = [p, p, t, value, value, q];
    return '#' + AvatarTintColors.hexByte(red[sector]) + AvatarTintColors.hexByte(green[sector]) +
      AvatarTintColors.hexByte(blue[sector]);
  }

  private static hexByte(value: number): string {
    return Math.round(value * 255).toString(16).padStart(2, '0');
  }
}

export function avatarTintIsDark(theme: Theme): boolean {
  try {
    const color: ColorMetrics = ColorMetrics.resourceColor(theme.colors.backgroundPrimary);
    return color.red * 0.2126 + color.green * 0.7152 + color.blue * 0.0722 < 128;
  } catch (error) {
    return false;
  }
}

export function avatarTintSurface(palette: AvatarTintPalette | null, url: string, enabled: boolean,
  displayMode: string, darkSurface: string, systemDark: boolean): ResourceColor {
  if (!enabled || palette === null || palette.avatarUrl !== XUserParser.highResAvatarUrl(url)) {
    return pageSurfaceColor(displayMode, darkSurface);
  }
  const dark: boolean = displayMode === DISPLAY_MODE_DARK ||
    (displayMode !== DISPLAY_MODE_LIGHT && systemDark);
  return dark ? (displayMode === DISPLAY_MODE_DARK && darkSurface === DARK_SURFACE_GENTLE ?
    palette.gentleDark : palette.dark) : palette.light;
}
