import { UIContext } from '@kit.ArkUI';
import { uiEffect } from '@kit.ArkGraphics2D';
import { deviceInfo } from '@kit.BasicServicesKit';
import { resourceManager } from '@kit.LocalizationKit';
import hilog from '@ohos.hilog';

const HDR_HIGHLIGHT_API_VERSION: number = 24;
const DOMAIN: number = 0xFF00;
const TAG: string = 'HarmonyX-UI-HDR';

// Apply once to a small foreground group or glyph, never to both parent and child.
// An empty filter also clears a previously selected component's HDR effect.
export class ComponentHdrHighlight {
  private static neutral: uiEffect.Filter = uiEffect.createFilter();
  private static highlight: uiEffect.Filter | undefined = undefined;
  private static highlightRatio: number = 1;
  private static unavailable: boolean = false;

  static filter(context: UIContext, active: boolean = true, requestedRatio?: number): uiEffect.Filter {
    if (!active || deviceInfo.sdkApiVersion < HDR_HIGHLIGHT_API_VERSION || ComponentHdrHighlight.unavailable) {
      return ComponentHdrHighlight.neutral;
    }
    try {
      let ratio: number = requestedRatio ?? 1;
      if (requestedRatio === undefined) {
        const resources: resourceManager.ResourceManager | undefined = context.getHostContext()?.resourceManager;
        if (resources === undefined) { return ComponentHdrHighlight.neutral; }
        ratio = resources.getNumber($r('app.float.component_hdr_highlight_ratio').id);
      }
      if (!Number.isFinite(ratio) || ratio <= 1) { return ComponentHdrHighlight.neutral; }
      if (ComponentHdrHighlight.highlight !== undefined && ComponentHdrHighlight.highlightRatio === ratio) {
        return ComponentHdrHighlight.highlight;
      }
      const filter: uiEffect.Filter = uiEffect.createFilter().hdrBrightnessRatio(ratio);
      ComponentHdrHighlight.highlight = filter;
      ComponentHdrHighlight.highlightRatio = ratio;
      hilog.info(DOMAIN, TAG, 'component HDR filter ready, requested ratio=%{public}s', ratio.toString());
      return filter;
    } catch (error) {
      // Permission failure or unavailable graphics service must leave controls usable.
      ComponentHdrHighlight.unavailable = true;
      hilog.warn(DOMAIN, TAG, 'component HDR unavailable; using ordinary UI rendering');
      return ComponentHdrHighlight.neutral;
    }
  }
}
