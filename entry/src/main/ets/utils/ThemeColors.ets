// Surface-color selection for the optional gentle dark appearance. Resource
// colors still provide the normal light/dark behavior; the extra palette is
// considered only when the app is explicitly set to Dark.
import { DARK_SURFACE_GENTLE, DISPLAY_MODE_DARK } from '../services/AppearanceStore';

function useGentleDarkSurface(displayMode: string, darkSurface: string): boolean {
  return displayMode === DISPLAY_MODE_DARK && darkSurface === DARK_SURFACE_GENTLE;
}

export function pageSurfaceColor(displayMode: string, darkSurface: string): ResourceColor {
  return useGentleDarkSurface(displayMode, darkSurface) ? $r('app.color.gentle_bg_page') :
    $r('app.color.bg_page');
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
