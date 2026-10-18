export interface PageRgb { red: number; green: number; blue: number; }

export class PagePhotoTone {
  average: string = '#808080';
  darkest: string = '#000000';
  lightest: string = '#FFFFFF';
  alpha: number = 1;
}

export function rgbFromHex(value: string): PageRgb {
  return { red: parseInt(value.substring(1, 3), 16), green: parseInt(value.substring(3, 5), 16),
    blue: parseInt(value.substring(5, 7), 16) };
}

export function mixPageRgb(base: PageRgb, overlay: PageRgb, opacity: number): PageRgb {
  const alpha: number = Math.max(0, Math.min(1, opacity));
  return { red: base.red * (1 - alpha) + overlay.red * alpha,
    green: base.green * (1 - alpha) + overlay.green * alpha, blue: base.blue * (1 - alpha) + overlay.blue * alpha };
}

function linearChannel(value: number): number {
  const channel: number = value / 255;
  return channel <= 0.04045 ? channel / 12.92 : Math.pow((channel + 0.055) / 1.055, 2.4);
}

export function pageLuminance(color: PageRgb): number {
  return linearChannel(color.red) * 0.2126 + linearChannel(color.green) * 0.7152 + linearChannel(color.blue) * 0.0722;
}

export function pageContrastRatio(first: PageRgb, second: PageRgb): number {
  const a: number = pageLuminance(first); const b: number = pageLuminance(second);
  return (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05);
}

export function pageLightInk(background: PageRgb): boolean {
  const luminance: number = pageLuminance(background);
  return 1.05 / (luminance + 0.05) > (luminance + 0.05) / 0.05;
}

function rgbHex(color: PageRgb): string {
  return '#' + Math.round(color.red).toString(16).padStart(2, '0') +
    Math.round(color.green).toString(16).padStart(2, '0') + Math.round(color.blue).toString(16).padStart(2, '0');
}

export function samplePagePhoto(bytes: Uint8Array): PagePhotoTone {
  const tone: PagePhotoTone = new PagePhotoTone();
  let red: number = 0; let green: number = 0; let blue: number = 0; let alpha: number = 0;
  let low: number = 2; let high: number = -1;
  for (let index: number = 0; index + 3 < bytes.length; index += 4) {
    const weight: number = bytes[index + 3] / 255;
    if (weight < 0.05) { continue; }
    const color: PageRgb = { red: bytes[index], green: bytes[index + 1], blue: bytes[index + 2] };
    const luminance: number = pageLuminance(color);
    red += color.red * weight; green += color.green * weight; blue += color.blue * weight; alpha += weight;
    if (luminance < low) { low = luminance; tone.darkest = rgbHex(color); }
    if (luminance > high) { high = luminance; tone.lightest = rgbHex(color); }
  }
  if (alpha > 0) {
    tone.average = rgbHex({ red: red / alpha, green: green / alpha, blue: blue / alpha });
    tone.alpha = Math.min(1, alpha / Math.max(1, Math.floor(bytes.length / 4)));
  } else { tone.alpha = 0; }
  return tone;
}

// A mixed photo can contain both white and black under the same text. Use
// its sampled extremes to add only the veil required by the selected ink.
export function photoReadingVeil(average: PageRgb, darkest: PageRgb, lightest: PageRgb): number {
  const light: boolean = pageLightInk(average);
  const ink: PageRgb = light ? { red: 255, green: 255, blue: 255 } : { red: 0, green: 0, blue: 0 };
  const veil: PageRgb = light ? { red: 0, green: 0, blue: 0 } : { red: 255, green: 255, blue: 255 };
  if (pageContrastRatio(ink, darkest) >= 5 && pageContrastRatio(ink, lightest) >= 5) { return 0; }
  let low: number = 0; let high: number = 1;
  for (let step: number = 0; step < 14; step++) {
    const middle: number = (low + high) / 2;
    if (Math.min(pageContrastRatio(ink, mixPageRgb(darkest, veil, middle)),
      pageContrastRatio(ink, mixPageRgb(lightest, veil, middle))) >= 5) { high = middle; }
    else { low = middle; }
  }
  return high;
}
