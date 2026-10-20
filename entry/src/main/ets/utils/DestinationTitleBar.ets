// Title-bar styling shared by the pushed destinations.
//
// The HDS defaults paint the title and the navigation icons for a dark
// surface: once the scroll effect engages, the bar switches to its "scrolled"
// style and keeps white text, which is invisible on the light theme's white
// page. Every destination therefore states the theme colours for both states,
// exactly like the home surface's navigation does.
import {
  BuilderOptions,
  HdsTitleBarContentStyle,
  hdsMaterial,
  ScrollEffectType,
  TitleBarStyleOptions
} from '@kit.UIDesignKit';
import { pageSurfaceColor, titleBarScrimColor } from './ThemeColors';
import { ResponsiveLayout } from './ResponsiveLayout';
import { LengthMetrics, uiMaterial } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';
import { SystemMaterialUtil } from './SystemMaterial';
import { pageBackgroundActive } from '../services/PageBackgroundStore';
import {
  TITLE_BAR_STYLE_GLASS,
  TITLE_BAR_STYLE_GLASS_ONLY,
  TITLE_BAR_STYLE_IMMERSIVE,
  TITLE_BAR_STYLE_BLUR
} from '../services/AppearanceStore';

// API 26 can retain the mounted builder node while its observed state changes.
// Legacy builders remount when HDS receives another titleBar configuration.
export function retainedTitleBarBuilder(builder: CustomBuilder): BuilderOptions | undefined {
  if (!SystemMaterialUtil.isApi26OrAbove()) {
    return undefined;
  }
  return { builder: builder, updated: false };
}

// Geometry updates must reuse the material instance. Only a thickness change
// needs a new material; recreating it during area measurement resets the effect.
export class TitleBarGlassMaterialCache {
  private cachedLevel: number = -1;
  private cachedMaterial: uiMaterial.Material | undefined = undefined;

  material(level: number): uiMaterial.Material | undefined {
    if (this.cachedMaterial === undefined || this.cachedLevel !== level) {
      this.cachedMaterial = SystemMaterialUtil.immersiveMaterial(level, false, false, true, undefined);
      this.cachedLevel = level;
    }
    return this.cachedMaterial;
  }
}

// Each search field or filter button keeps its own native control material.
export class TitleBarControlMaterialCache {
  private cachedAccent: string = '';
  private cachedShadow: boolean = false;
  private cachedMaterial: uiMaterial.Material | undefined = undefined;

  material(accent: string, shadow: boolean = false): uiMaterial.Material | undefined {
    if (this.cachedMaterial === undefined || this.cachedAccent !== accent || this.cachedShadow !== shadow) {
      this.cachedMaterial = SystemMaterialUtil.immersiveMaterial(1, true, shadow, true, accent);
      this.cachedAccent = accent;
      this.cachedShadow = shadow;
    }
    return this.cachedMaterial;
  }
}

function titleContentStyle(): HdsTitleBarContentStyle {
  return {
    titleStyle: {
      mainTitleColor: $r('app.color.text_primary'),
      subTitleColor: $r('app.color.text_secondary')
    },
    backIconStyle: { iconColor: $r('app.color.text_primary') },
    subIconStyle: { iconColor: $r('app.color.text_primary') },
    menuStyle: { iconColor: $r('app.color.text_primary') }
  };
}

// 显示设置里的标题栏样式：
//   0 沉浸渐变模糊——标题栏样式全给 HDS：滚动渐变模糊、原始/滚动背景、系统材质。
//   1 渐变模糊——除系统材质外，其余样式字段全部不设置。
//   2 玻璃材质——沉浸渐变那套完整样式 + 我们自制的玻璃面板。
//   3 玻璃材质（关闭沉浸模糊）——把滚动模糊显式关掉，只留玻璃面板和系统材质。
//
// 那块玻璃面板只挂在根页面，子页面没有它；用户要的是子页面照常滚动，所以对子页面
// 来说只有第 1 档会退化成"只剩系统材质"，其余三档都走整套样式。
export function titleBarFullStyleEnabled(titleBarStyleMode: number): boolean {
  return titleBarStyleMode === TITLE_BAR_STYLE_IMMERSIVE ||
    titleBarStyleMode === TITLE_BAR_STYLE_GLASS;
}

// 子页面版本：只有渐变模糊档不给整套样式。
export function destinationTitleBarFullStyleEnabled(titleBarStyleMode: number): boolean {
  return titleBarStyleMode !== TITLE_BAR_STYLE_BLUR;
}

export function customTitleBarGlassEnabled(titleBarStyleMode: number): boolean {
  return titleBarStyleMode === TITLE_BAR_STYLE_GLASS ||
    titleBarStyleMode === TITLE_BAR_STYLE_GLASS_ONLY;
}

// 根页面在玻璃材质下打开"关闭沉浸模糊"时把滚动模糊显式关掉。这里必须写 false 而
// 不是留着字段不设：不设会被 HDS 当成默认值处理，效果就退化成渐变模糊那一档了。
// 子页面不走这一支（见 destinationTitleBarFullStyleEnabled）。
export function titleBarScrollEffectDisabled(titleBarStyleMode: number): boolean {
  return titleBarStyleMode === TITLE_BAR_STYLE_GLASS_ONLY;
}

// Root navigation uses the same appearance choice at every window size.
// Only its background is transparent on desktop, where HDS owns safe-area rendering.
export function rootTitleBarStyle(displayMode: string, darkSurface: string,
  titleBarStyleMode: number, desktop: boolean): TitleBarStyleOptions {
  const full: boolean = titleBarFullStyleEnabled(titleBarStyleMode);
  const custom: boolean = pageBackgroundActive(AppStorage.get<string>('harmonyx.page_background') ?? '');
  let effectType: ScrollEffectType = ScrollEffectType.GRADIENT_BLUR;
  if (deviceInfo.apiAvailable('6.1.0(23)')) {
    effectType = ScrollEffectType.IMMERSIVE_GRADIENT_BLUR;
  }
  const options: TitleBarStyleOptions = {
    scrollEffectOpts: full ? {
      enableScrollEffect: true,
      scrollEffectType: effectType,
      blurEffectiveStartOffset: LengthMetrics.vp(0),
      blurEffectiveEndOffset: LengthMetrics.vp(16)
    } : (titleBarScrollEffectDisabled(titleBarStyleMode) ? { enableScrollEffect: false } : undefined),
    originalStyle: full || custom ? {
      backgroundStyle: { backgroundColor: custom ? pageSurfaceColor(displayMode, darkSurface) :
        (desktop ? Color.Transparent : titleBarScrimColor(displayMode, darkSurface)) },
      contentStyle: titleContentStyle()
    } : undefined,
    scrollEffectStyle: full || custom ? {
      backgroundStyle: { backgroundColor: desktop && !custom ? Color.Transparent : pageSurfaceColor(displayMode, darkSurface) },
      contentStyle: titleContentStyle()
    } : undefined
  };
  if (deviceInfo.apiAvailable('6.1.0(23)')) {
    options.systemMaterialEffect = {
      materialType: hdsMaterial.MaterialType.IMMERSIVE,
      materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
    };
  }
  return options;
}

// Reuse the selected glass material directly on native title-bar content.
// Geometry and scroll avoidance remain owned by HDS.
export function titleBarGlassMaterial(titleBarStyleMode: number,
  materialLevel: number): uiMaterial.Material | undefined {
  return customTitleBarGlassEnabled(titleBarStyleMode) ?
    SystemMaterialUtil.immersiveMaterial(materialLevel, false, false, true, undefined) : undefined;
}

// `preferredEffect` is the effect each destination was tuned with, used as-is
// on the immersive-gradient setting only.
export function destinationTitleBarStyle(
  preferredEffect: ScrollEffectType, displayMode: string, darkSurface: string,
  titleBarStyleMode: number, backgroundDimmed: boolean = false): TitleBarStyleOptions {
  const desktop: boolean = (AppStorage.get<boolean>('harmonyx.desktop_layout') ?? false) &&
    ResponsiveLayout.isLarge(AppStorage.get<string>('harmonyx.breakpoint') ?? 'sm');
  const full: boolean = destinationTitleBarFullStyleEnabled(titleBarStyleMode);
  const custom: boolean = pageBackgroundActive(AppStorage.get<string>('harmonyx.page_background') ?? '');
  const hasExplicitBackground: boolean = full || backgroundDimmed || custom;
  let effectType: ScrollEffectType = ScrollEffectType.GRADIENT_BLUR;
  if (deviceInfo.apiAvailable('6.1.0(23)')) {
    effectType = desktop ? ScrollEffectType.IMMERSIVE_GRADIENT_BLUR : preferredEffect;
  }
  const options: TitleBarStyleOptions = {
    scrollEffectOpts: full ? {
      enableScrollEffect: true,
      scrollEffectType: effectType
    } : undefined,
    originalStyle: hasExplicitBackground ? {
      backgroundStyle: {
        backgroundColor: backgroundDimmed ? $r('app.color.reply_composer_scrim') :
          (custom ? pageSurfaceColor(displayMode, darkSurface) : (desktop ? Color.Transparent : titleBarScrimColor(displayMode, darkSurface)))
      },
      contentStyle: full || custom ? titleContentStyle() : undefined
    } : undefined,
    scrollEffectStyle: hasExplicitBackground ? {
      backgroundStyle: {
        backgroundColor: backgroundDimmed ? $r('app.color.reply_composer_scrim') :
          (desktop && !custom ? Color.Transparent : pageSurfaceColor(displayMode, darkSurface))
      },
      contentStyle: full || custom ? titleContentStyle() : undefined
    } : undefined
  };
  if (deviceInfo.apiAvailable('6.1.0(23)')) {
    options.systemMaterialEffect = {
      materialType: hdsMaterial.MaterialType.IMMERSIVE,
      materialLevel: hdsMaterial.MaterialLevel.EXQUISITE
    };
  }
  return options;
}
