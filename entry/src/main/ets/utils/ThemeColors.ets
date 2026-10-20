// Surface-color selection for the optional gentle dark appearance. Resource
// colors still provide the normal light/dark behavior; the extra palette is
// considered only when the app is explicitly set to Dark.
import { DARK_SURFACE_GENTLE, DISPLAY_MODE_DARK } from '../services/AppearanceStore';
import { ColorMetrics } from '@kit.ArkUI';
import { pageBackgroundActive, pageBackgroundFromValue, DEFAULT_PAGE_SURFACE_OPACITY, PageBackgroundState } from '../services/PageBackgroundStore';
import { PageRgb, rgbFromHex, mixPageRgb, pageLightInk, pageContrastRatio, photoReadingVeil, pagePatternOpacity } from './PageBackgroundContrast';

export class PageBackdropTone {
  average: PageRgb = rgbFromHex('#808080');
  darkest: PageRgb = rgbFromHex('#808080');
  lightest: PageRgb = rgbFromHex('#808080');
  veil: number = 0;
  veilLight: boolean = false;
}

let resolvedToneKey: string = '';
let resolvedTone: PageBackdropTone = new PageBackdropTone();
const textColorCache: Map<string, ResourceColor> = new Map();
const readingSurfaceCache: Map<string, ResourceColor> = new Map();

function cachedBackdropTone(backgroundValue: string): PageBackdropTone {
  const state: PageBackgroundState = pageBackgroundFromValue(backgroundValue);
  const display: string = AppStorage.get<string>('harmonyx.display_mode') ?? '';
  const dark: string = AppStorage.get<string>('harmonyx.dark_surface') ?? '';
  const base: ColorMetrics = ColorMetrics.resourceColor(pageBackgroundBaseColor(state, display, dark));
  // Resolve the resource too: system light/dark changes may keep the same
  // serialized wallpaper and display-mode preference.
  const key: string = backgroundValue + '|' + display + '|' + dark + '|' + base.red + ',' + base.green + ',' + base.blue;
  if (key !== resolvedToneKey) {
    resolvedTone = pageBackdropTone(state, display, dark); resolvedToneKey = key;
    textColorCache.clear(); readingSurfaceCache.clear();
  }
  return resolvedTone;
}

export function pageBackgroundBaseColor(state: PageBackgroundState, displayMode: string, darkSurface: string): ResourceColor {
  if (state.mode === 'color') { return state.color; }
  if (state.mode === 'theme' && state.texture === 'kraft') { return $r('app.color.page_background_kraft'); }
  if (state.mode === 'theme' && state.texture === 'parchment') { return $r('app.color.page_background_parchment'); }
  return pageSurfaceColor(displayMode, darkSurface);
}

function resourceRgb(value: ResourceColor): PageRgb {
  const color: ColorMetrics = ColorMetrics.resourceColor(value);
  return { red: color.red, green: color.green, blue: color.blue };
}

function inkContrast(low: PageRgb, high: PageRgb): number {
  return Math.max(Math.min(pageContrastRatio(rgbFromHex('#000000'), low), pageContrastRatio(rgbFromHex('#000000'), high)),
    Math.min(pageContrastRatio(rgbFromHex('#FFFFFF'), low), pageContrastRatio(rgbFromHex('#FFFFFF'), high)));
}

// At some middle opacities, a light panel over a mixed dark photo spans both
// sides of the black/white threshold. Slightly tint its RGB, preserving the
// exact chosen alpha, until one foreground is readable over the entire range.
function readableSurfaceRgb(color: PageRgb, alpha: number, tone: PageBackdropTone): PageRgb {
  if (inkContrast(mixPageRgb(tone.darkest, color, alpha), mixPageRgb(tone.lightest, color, alpha)) >= 4.6) { return color; }
  let best: PageRgb = color; let shortest: number = 2;
  const targets: PageRgb[] = [rgbFromHex('#000000'), rgbFromHex('#FFFFFF')];
  for (let index: number = 0; index < targets.length; index++) {
    if (inkContrast(mixPageRgb(tone.darkest, targets[index], alpha), mixPageRgb(tone.lightest, targets[index], alpha)) < 4.6) { continue; }
    let start: number = 0; let end: number = 1;
    for (let step: number = 0; step < 12; step++) {
      const middle: number = (start + end) / 2;
      const candidate: PageRgb = mixPageRgb(color, targets[index], middle);
      if (inkContrast(mixPageRgb(tone.darkest, candidate, alpha), mixPageRgb(tone.lightest, candidate, alpha)) >= 4.6) { end = middle; }
      else { start = middle; }
    }
    if (end < shortest) { shortest = end; best = mixPageRgb(color, targets[index], end); }
  }
  return best;
}

// The same compositing model drives both the rendered veil and foregrounds.
// Include image extremes, grain, pattern ink and the user's dimming level.
export function pageBackdropTone(state: PageBackgroundState, displayMode: string, darkSurface: string): PageBackdropTone {
  const tone: PageBackdropTone = new PageBackdropTone();
  const base: PageRgb = resourceRgb(pageBackgroundBaseColor(state, displayMode, darkSurface));
  tone.average = state.mode === 'photo' ? mixPageRgb(base, rgbFromHex(state.photoAverage), state.photoAlpha) : base;
  tone.darkest = state.mode === 'photo' ? mixPageRgb(base, rgbFromHex(state.photoDarkest), state.photoAlpha) : base;
  tone.lightest = state.mode === 'photo' ? mixPageRgb(base, rgbFromHex(state.photoLightest), state.photoAlpha) : base;
  const black: PageRgb = rgbFromHex('#000000'); const white: PageRgb = rgbFromHex('#FFFFFF');
  if (state.texture !== 'none') {
    tone.darkest = mixPageRgb(tone.darkest, black, state.textureStrength * 0.4);
    tone.lightest = mixPageRgb(tone.lightest, white, state.textureStrength * 0.4);
  }
  const patterns: number = state.patternLayout === 'preset' ? state.patternIds.length : state.motifIds.length;
  if (patterns > 0) {
    const ink: number = pageLightInk(tone.average) ? 1 : 0;
    const strength: number = state.patternLayout === 'preset' ?
      1 - Math.pow(1 - pagePatternOpacity(state.patternStrength / Math.sqrt(patterns), ink), patterns) :
      pagePatternOpacity(state.patternStrength, ink);
    if (pageLightInk(tone.average)) { tone.lightest = mixPageRgb(tone.lightest, white, strength); }
    else { tone.darkest = mixPageRgb(tone.darkest, black, strength); }
  }
  tone.average = mixPageRgb(tone.average, black, state.dim);
  tone.darkest = mixPageRgb(tone.darkest, black, state.dim);
  tone.lightest = mixPageRgb(tone.lightest, black, state.dim);
  tone.veilLight = !pageLightInk(tone.average);
  tone.veil = photoReadingVeil(tone.average, tone.darkest, tone.lightest);
  const veil: PageRgb = tone.veilLight ? white : black;
  tone.average = mixPageRgb(tone.average, veil, tone.veil);
  tone.darkest = mixPageRgb(tone.darkest, veil, tone.veil);
  tone.lightest = mixPageRgb(tone.lightest, veil, tone.veil);
  return tone;
}

// Callers pass the actual backing surface (including its alpha). Solid fields
// keep their own contrast; transparent posts use the visible wallpaper.
export function pageTextColor(original: ResourceColor, backgroundValue: string, surface: ResourceColor = Color.Transparent,
  minimum: number = 4.6): ResourceColor {
  try {
    // Opaque fields still need readable text when wallpaper is off. Disabled
    // wallpaper must use the actual theme canvas rather than its saved color.
    const tone: PageBackdropTone = cachedBackdropTone(pageBackgroundActive(backgroundValue) ? backgroundValue : '');
    const backing: ColorMetrics = ColorMetrics.resourceColor(surface);
    const requestedColor: ColorMetrics = ColorMetrics.resourceColor(original);
    const requested: PageRgb = { red: requestedColor.red, green: requestedColor.green, blue: requestedColor.blue };
    const key: string = requested.red + ',' + requested.green + ',' + requested.blue + ',' + requestedColor.alpha + '|' + minimum + '|' +
      backing.red + ',' + backing.green + ',' + backing.blue + ',' + backing.alpha;
    const cached: ResourceColor | undefined = textColorCache.get(key);
    if (cached !== undefined) { return cached; }
    const rgb: PageRgb = { red: backing.red, green: backing.green, blue: backing.blue };
    const low: PageRgb = mixPageRgb(tone.darkest, rgb, backing.alpha / 255);
    const high: PageRgb = mixPageRgb(tone.lightest, rgb, backing.alpha / 255);
    if (Math.min(pageContrastRatio(mixPageRgb(low, requested, requestedColor.alpha / 255), low),
      pageContrastRatio(mixPageRgb(high, requested, requestedColor.alpha / 255), high)) >= minimum) {
      textColorCache.set(key, original); return original;
    }
    const white: PageRgb = rgbFromHex('#FFFFFF'); const black: PageRgb = rgbFromHex('#000000');
    const light: boolean = Math.min(pageContrastRatio(white, low), pageContrastRatio(white, high)) >
      Math.min(pageContrastRatio(black, low), pageContrastRatio(black, high));
    const target: PageRgb = light ? white : black;
    let start: number = 0; let end: number = 1;
    for (let step: number = 0; step < 10; step++) {
      const middle: number = (start + end) / 2;
      const candidate: PageRgb = mixPageRgb(requested, target, middle);
      if (Math.min(pageContrastRatio(candidate, low), pageContrastRatio(candidate, high)) >= minimum) { end = middle; }
      else { start = middle; }
    }
    const result: PageRgb = mixPageRgb(requested, target, end);
    const output: ResourceColor = ColorMetrics.rgba(Math.round(result.red), Math.round(result.green), Math.round(result.blue), 1).color;
    if (textColorCache.size < 512) { textColorCache.set(key, output); }
    return output;
  } catch (error) { return original; }
}

function useGentleDarkSurface(displayMode: string, darkSurface: string): boolean {
  return displayMode === DISPLAY_MODE_DARK && darkSurface === DARK_SURFACE_GENTLE;
}

export function pageSurfaceColor(displayMode: string, darkSurface: string): ResourceColor {
  return useGentleDarkSurface(displayMode, darkSurface) ? $r('app.color.gentle_bg_page') :
    $r('app.color.bg_page');
}

// Only page canvases become transparent. Sheets, dialogs, fields and chat
// wallpapers keep their normal opaque theme surfaces.
export function pageCanvasColor(displayMode: string, darkSurface: string, backgroundValue: string): ResourceColor {
  return pageBackgroundActive(backgroundValue) ? Color.Transparent : pageSurfaceColor(displayMode, darkSurface);
}

export function pageReadingSurfaceColor(surface: ResourceColor, backgroundValue: string, opacity: number = -1): ResourceColor {
  if (!pageBackgroundActive(backgroundValue) && (opacity < 0 || opacity === DEFAULT_PAGE_SURFACE_OPACITY)) { return surface; }
  try {
    const color: ColorMetrics = ColorMetrics.resourceColor(surface);
    const alpha: number = color.alpha / 255 * (opacity < 0 ? pageBackgroundFromValue(backgroundValue).contentOpacity : opacity);
    let rgb: PageRgb = { red: color.red, green: color.green, blue: color.blue };
    if (pageBackgroundActive(backgroundValue)) {
      const tone: PageBackdropTone = cachedBackdropTone(backgroundValue);
      const key: string = color.red + ',' + color.green + ',' + color.blue + ',' + alpha;
      const cached: ResourceColor | undefined = readingSurfaceCache.get(key);
      if (cached !== undefined) { return cached; }
      rgb = readableSurfaceRgb(rgb, alpha, tone);
      const output: ResourceColor = ColorMetrics.rgba(Math.round(rgb.red), Math.round(rgb.green), Math.round(rgb.blue), alpha).color;
      if (readingSurfaceCache.size < 128) { readingSurfaceCache.set(key, output); }
      return output;
    }
    return ColorMetrics.rgba(Math.round(rgb.red), Math.round(rgb.green), Math.round(rgb.blue), alpha).color;
  } catch (error) { return surface; }
}

export function postCardSurfaceColor(surface: ResourceColor, backgroundValue: string): ResourceColor {
  const state: PageBackgroundState = pageBackgroundFromValue(backgroundValue);
  if (!state.enabled) { return surface; }
  return state.transparentPosts ? Color.Transparent : pageReadingSurfaceColor(surface, backgroundValue, state.postOpacity);
}

export function postCardUsesCustomSurface(backgroundValue: string): boolean {
  const state: PageBackgroundState = pageBackgroundFromValue(backgroundValue);
  if (!state.enabled) { return false; }
  return pageBackgroundActive(backgroundValue) || state.transparentPosts || state.postOpacity !== DEFAULT_PAGE_SURFACE_OPACITY;
}

export function inboxRowSurfaceColor(surface: ResourceColor, backgroundValue: string): ResourceColor {
  const state: PageBackgroundState = pageBackgroundFromValue(backgroundValue);
  if (!state.enabled) { return surface; }
  return state.transparentInbox ? Color.Transparent : pageReadingSurfaceColor(surface, backgroundValue, state.inboxOpacity);
}

export function cardSurfaceColor(displayMode: string, darkSurface: string): ResourceColor {
  return useGentleDarkSurface(displayMode, darkSurface) ? $r('app.color.gentle_bg_card') :
    $r('app.color.bg_card');
}

export function fieldSurfaceColor(displayMode: string, darkSurface: string): ResourceColor {
  return useGentleDarkSurface(displayMode, darkSurface) ? $r('app.color.gentle_bg_field') :
    $r('app.color.bg_field');
}

export function secondaryButtonSurfaceColor(displayMode: string, darkSurface: string): ResourceColor {
  return useGentleDarkSurface(displayMode, darkSurface) ? $r('app.color.gentle_bg_secondary_btn') :
    $r('app.color.bg_secondary_btn');
}

export function titleBarScrimColor(displayMode: string, darkSurface: string): ResourceColor {
  return useGentleDarkSurface(displayMode, darkSurface) ? $r('app.color.gentle_title_bar_scrim') :
    $r('app.color.title_bar_scrim');
}
