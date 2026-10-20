import { uiMaterial } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';
import { validSheetMaterialLevel } from '../services/SheetMaterialSettingsStore';
import { SystemMaterialUtil } from './SystemMaterial';
import { ResponsiveLayout } from './ResponsiveLayout';

export function sheetMaterialActive(enabled: boolean): boolean {
  // 低于 API 26 时使用系统 blur，内容层同样需要让出背板。
  return enabled;
}

export function sheetBlurStyle(level: number): BlurStyle {
  switch (validSheetMaterialLevel(level)) {
    case 0: return BlurStyle.COMPONENT_ULTRA_THIN;
    case 1: return BlurStyle.COMPONENT_THIN;
    case 3: return BlurStyle.COMPONENT_THICK;
    case 4: return BlurStyle.COMPONENT_ULTRA_THICK;
    default: return BlurStyle.COMPONENT_REGULAR;
  }
}

export function sheetUsesCenteredPresentation(breakpoint: string): boolean {
  return ResponsiveLayout.isLarge(breakpoint);
}

// Keep callbacks, dismissal guards and keyboard behavior while choosing the
// presentation from the current window, independently of material support.
export function sheetMaterialOptions(options: SheetOptions, enabled: boolean, level: number,
  breakpoint: string = AppStorage.get<string>('harmonyx.breakpoint') ?? 'sm',
  compactWindow: boolean | undefined = undefined): SheetOptions {
  const windowWidth: number = AppStorage.get<number>('harmonyx.window_width') ?? 0;
  const windowHeight: number = AppStorage.get<number>('harmonyx.window_height') ?? 0;
  if (compactWindow ?? ResponsiveLayout.isCompactWindow(windowWidth, windowHeight)) {
    const topInset: number = AppStorage.get<number>('harmonyx.status_bar_height') ?? 0;
    const bottomInset: number = AppStorage.get<number>('harmonyx.navigation_indicator_height') ?? 0;
    const availableHeight: number = Math.max(1, (windowHeight - topInset - bottomInset) * 0.9);
    const availableWidth: number = Math.max(1, windowWidth - 24);
    options.preferType = SheetType.BOTTOM;
    if (typeof options.width === 'number') { options.width = Math.min(options.width, availableWidth); }
    // Fit-content and preset detents can exceed this window. Keep small numeric
    // sheets small, while bounding larger sheets and their expandable detents.
    options.height = compactSheetHeight(options.height, availableHeight, windowHeight);
    if (options.detents !== undefined) {
      const detents: number[] = [];
      for (const height of options.detents) {
        const bounded: number = compactSheetHeight(height, availableHeight, windowHeight);
        if (detents.indexOf(bounded) < 0) { detents.push(bounded); }
      }
      // SheetOptions accepts a tuple of one to three detents.
      if (detents.length >= 3) { options.detents = [detents[0], detents[1], detents[2]]; }
      else if (detents.length === 2) { options.detents = [detents[0], detents[1]]; }
      else { options.detents = [detents.length > 0 ? detents[0] : availableHeight]; }
    }
  }
  if (sheetUsesCenteredPresentation(breakpoint)) {
    const width: number = AppStorage.get<number>('harmonyx.window_width') ?? 840;
    const height: number = AppStorage.get<number>('harmonyx.window_height') ?? 800;
    const topInset: number = AppStorage.get<number>('harmonyx.status_bar_height') ?? 0;
    const bottomInset: number = AppStorage.get<number>('harmonyx.navigation_indicator_height') ?? 0;
    const availableWidth: number = Math.max(280, width - 48);
    options.preferType = SheetType.CENTER;
    options.dragBar = false;
    if (typeof options.width === 'number') {
      options.width = Math.min(options.width, availableWidth);
    } else if (options.width === undefined || options.width === '100%') {
      options.width = Math.min(600, availableWidth);
    }
    if (typeof options.height === 'number') {
      options.height = Math.min(options.height, Math.max(240, height - topInset - bottomInset - 48));
    }
  }
  // Keep an explicit SDK guard beside the material construction.
  if (deviceInfo.apiAvailable('26.0.0')) {
    if (enabled) {
      options.backgroundColor = Color.Transparent;
      options.blurStyle = BlurStyle.NONE;
      options.systemMaterial = new uiMaterial.ImmersiveMaterial({
        style: SystemMaterialUtil.resolveImmersiveStyle(validSheetMaterialLevel(level)),
        interactive: false,
        lightEffect: null
      });
    }
  } else if (enabled) {
    options.backgroundColor = Color.Transparent;
    options.blurStyle = sheetBlurStyle(level);
    options.systemMaterial = undefined;
  }
  return options;
}

function compactSheetHeight(height: SheetSize | string | number | Resource | undefined,
  availableHeight: number, windowHeight: number): number {
  if (typeof height === 'number') { return Math.max(1, Math.min(height, availableHeight)); }
  if (typeof height === 'string' && height.endsWith('%')) {
    const percentage: number = Number.parseFloat(height);
    if (Number.isFinite(percentage)) {
      return Math.max(1, Math.min(windowHeight * percentage / 100, availableHeight));
    }
  }
  return availableHeight;
}

export function sheetContentBackground(original: ResourceColor, enabled: boolean): ResourceColor {
  return sheetMaterialActive(enabled) ? Color.Transparent : original;
}
