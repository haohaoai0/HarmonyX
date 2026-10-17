// Persistent, application-wide display preferences.  Color mode is applied
// through ApplicationContext so resource-qualified dark colors update too.
import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

export const DISPLAY_MODE_SYSTEM: string = 'system';
export const DISPLAY_MODE_LIGHT: string = 'light';
export const DISPLAY_MODE_DARK: string = 'dark';
export const DARK_SURFACE_BLACK: string = 'black';
export const DARK_SURFACE_GENTLE: string = 'gentle';
// Text can either track the system accessibility size or use a scale chosen
// inside the app. The app configuration profile keeps the system path at
// followSystem; the app path is applied with ApplicationContext.
export const FONT_MODE_SYSTEM: string = 'system';
export const FONT_MODE_APP: string = 'app';
// The font preference is intentionally limited to post content. HarmonyOS
// Sans stays the default for controls and the rest of the interface.
export const CONTENT_FONT_FAMILY_SYSTEM: string = 'HarmonyOS Sans';
export const CONTENT_FONT_FAMILY_SERIF: string = 'serif';
export const CONTENT_FONT_FAMILY_MONOSPACE: string = 'monospace';
export const DEFAULT_CONTENT_FONT_FAMILY: string = CONTENT_FONT_FAMILY_SYSTEM;
export const STORAGE_KEY_CONTENT_FONT_FAMILY: string = 'harmonyx.content_font_family';
// OpenHarmony UI design-spec examples use this system blue for selected UI.
export const DEFAULT_ACCENT_COLOR: string = '#007DFF';
const ICON_BLUE: string = '#0B77FD';
export const DEFAULT_FONT_SCALE: number = 1;
export const MIN_FONT_SCALE: number = 0.85;
export const MAX_FONT_SCALE: number = 1.75;
// 显示设置里的两个"自动隐藏"开关：滚动时收起顶部标题栏 / 底部导航栏。
// They live with the other display preferences so the root page can observe
// them through AppStorage like it already does for the colour mode.
export const STORAGE_KEY_AUTO_HIDE_TITLE_BAR: string = 'harmonyx.auto_hide_title_bar';
export const STORAGE_KEY_AUTO_HIDE_TAB_BAR: string = 'harmonyx.auto_hide_tab_bar';
export const STORAGE_KEY_AUTO_HIDE_FAB: string = 'harmonyx.auto_hide_fab';
export const STORAGE_KEY_HOME_HEADER_COLLAPSE: string = 'harmonyx.home_header_collapse';
export const STORAGE_KEY_TITLE_BAR_LOGO: string = 'harmonyx.title_bar_logo';
export const STORAGE_KEY_COMPACT_SWITCH_STYLE: string = 'harmonyx.compact_switch_style';
export const COMPACT_SWITCH_TABS: string = 'tabs';
export const COMPACT_SWITCH_BUTTONS: string = 'buttons';
export const STORAGE_KEY_IMMERSIVE_TITLE_BAR_BLUR: string = 'harmonyx.immersive_title_bar_blur';
// 标题栏样式，显示设置里以三选一呈现，玻璃材质还有个子开关：
//   0 沉浸渐变模糊——标题栏样式全给 HDS；
//   1 渐变模糊——除系统材质外，其余样式字段都不设置；
//   2 玻璃材质——沉浸渐变那套样式 + 我们自制的玻璃面板；
//   3 玻璃材质（关闭沉浸模糊）——只留玻璃面板，样式退化成只剩系统材质。
// 2 和 3 在界面上是同一条"玻璃材质"，额外那个开关只在这两档之间切换，所以页面
// 只需要继续观察这一个数值。
// 旧版本把前两者合并成一个布尔开关，载入时按它迁移（开 → 0，关 → 1）。
export const STORAGE_KEY_TITLE_BAR_STYLE_MODE: string = 'harmonyx.title_bar_style_mode';
export const TITLE_BAR_STYLE_IMMERSIVE: number = 0;
export const TITLE_BAR_STYLE_BLUR: number = 1;
export const TITLE_BAR_STYLE_GLASS: number = 2;
export const TITLE_BAR_STYLE_GLASS_ONLY: number = 3;
// 自制玻璃面板用的是 HarmonyOS 7 的 uiMaterial.ImmersiveStyle，共五档。默认极薄，
// 回复输入框也直接跟随这套五档厚度设置。
export const STORAGE_KEY_TITLE_BAR_GLASS_MATERIAL_LEVEL: string =
  'harmonyx.title_bar_glass_material_level';
export const TITLE_BAR_GLASS_ULTRA_THIN: number = 0;
export const TITLE_BAR_GLASS_THIN: number = 1;
export const TITLE_BAR_GLASS_REGULAR: number = 2;
export const TITLE_BAR_GLASS_THICK: number = 3;
export const TITLE_BAR_GLASS_ULTRA_THICK: number = 4;
export const DEFAULT_TITLE_BAR_GLASS_MATERIAL_LEVEL: number = TITLE_BAR_GLASS_ULTRA_THIN;
export const STORAGE_KEY_REPLY_CAPSULE_MATERIAL_LEVEL: string = 'harmonyx.reply_capsule_material_level';
export const DEFAULT_REPLY_CAPSULE_MATERIAL_LEVEL: number = TITLE_BAR_GLASS_ULTRA_THIN;
export const STORAGE_KEY_REPLY_CAPSULE_BUTTON_MATERIAL_ENABLED: string =
  'harmonyx.reply_capsule_button_material_enabled';
export const DEFAULT_REPLY_CAPSULE_BUTTON_MATERIAL_ENABLED: boolean = true;
export const STORAGE_KEY_COMPOSE_BUTTON_ENABLED: string = 'harmonyx.compose_button_enabled';
export const STORAGE_KEY_DARK_SURFACE: string = 'harmonyx.dark_surface';
export const STORAGE_KEY_AVATAR_TINT_ENABLED: string = 'harmonyx.avatar_tint_enabled';
export const STORAGE_KEY_SYSTEM_EMOJI_ENABLED: string = 'harmonyx.system_emoji_enabled';

export class AppearanceSettings {
  mode: string = DISPLAY_MODE_SYSTEM;
  accentColor: string = DEFAULT_ACCENT_COLOR;
  fontMode: string = FONT_MODE_SYSTEM;
  fontScale: number = DEFAULT_FONT_SCALE;
  contentFontFamily: string = DEFAULT_CONTENT_FONT_FAMILY;
  autoHideTitleBar: boolean = false;
  autoHideTabBar: boolean = false;
  homeHeaderCollapseEnabled: boolean = false;
  titleBarLogoEnabled: boolean = true;
  compactSwitchStyle: string = COMPACT_SWITCH_TABS;
  // true 表示保持原有行为：滑动列表时发帖按钮暂时消失，停止滚动后回来。
  autoHideFab: boolean = true;
  titleBarStyleMode: number = TITLE_BAR_STYLE_IMMERSIVE;
  titleBarGlassMaterialLevel: number = DEFAULT_TITLE_BAR_GLASS_MATERIAL_LEVEL;
  replyCapsuleMaterialLevel: number = DEFAULT_REPLY_CAPSULE_MATERIAL_LEVEL;
  replyCapsuleButtonMaterialEnabled: boolean = DEFAULT_REPLY_CAPSULE_BUTTON_MATERIAL_ENABLED;
  darkSurface: string = DARK_SURFACE_BLACK;
  composeButtonEnabled: boolean = true;
  avatarTintEnabled: boolean = false;
  systemEmojiEnabled: boolean = false;

  constructor(mode: string, accentColor: string, fontMode: string, fontScale: number,
    autoHideTitleBar: boolean = false, autoHideTabBar: boolean = false,
    autoHideFab: boolean = true, darkSurface: string = DARK_SURFACE_BLACK,
    composeButtonEnabled: boolean = true, titleBarStyleMode: number = TITLE_BAR_STYLE_IMMERSIVE,
    titleBarGlassMaterialLevel: number = DEFAULT_TITLE_BAR_GLASS_MATERIAL_LEVEL,
    homeHeaderCollapseEnabled: boolean = false,
    contentFontFamily: string = DEFAULT_CONTENT_FONT_FAMILY,
    replyCapsuleMaterialLevel: number = DEFAULT_REPLY_CAPSULE_MATERIAL_LEVEL,
    avatarTintEnabled: boolean = false, titleBarLogoEnabled: boolean = true,
    systemEmojiEnabled: boolean = false, compactSwitchStyle: string = COMPACT_SWITCH_TABS,
    replyCapsuleButtonMaterialEnabled: boolean = DEFAULT_REPLY_CAPSULE_BUTTON_MATERIAL_ENABLED) {
    this.mode = mode;
    this.accentColor = accentColor;
    this.fontMode = fontMode;
    this.fontScale = fontScale;
    this.contentFontFamily = contentFontFamily;
    this.autoHideTitleBar = autoHideTitleBar;
    this.autoHideTabBar = autoHideTabBar;
    this.homeHeaderCollapseEnabled = homeHeaderCollapseEnabled;
    this.autoHideFab = autoHideFab;
    this.titleBarStyleMode = titleBarStyleMode;
    this.titleBarGlassMaterialLevel = titleBarGlassMaterialLevel;
    this.replyCapsuleMaterialLevel = replyCapsuleMaterialLevel;
    this.replyCapsuleButtonMaterialEnabled = replyCapsuleButtonMaterialEnabled;
    this.darkSurface = darkSurface;
    this.composeButtonEnabled = composeButtonEnabled;
    this.avatarTintEnabled = avatarTintEnabled;
    this.titleBarLogoEnabled = titleBarLogoEnabled;
    this.systemEmojiEnabled = systemEmojiEnabled;
    this.compactSwitchStyle = compactSwitchStyle === COMPACT_SWITCH_BUTTONS ? COMPACT_SWITCH_BUTTONS : COMPACT_SWITCH_TABS;
  }
}

export class AppearanceStore {
  private static readonly STORE_NAME: string = 'harmonyx_appearance';
  private static readonly MODE_KEY: string = 'display_mode';
  private static readonly ACCENT_KEY: string = 'accent_color';
  private static readonly FONT_MODE_KEY: string = 'font_mode';
  private static readonly FONT_KEY: string = 'font_scale';
  private static readonly CONTENT_FONT_FAMILY_KEY: string = 'content_font_family';
  private static readonly AUTO_HIDE_TITLE_BAR_KEY: string = 'auto_hide_title_bar';
  private static readonly AUTO_HIDE_TAB_BAR_KEY: string = 'auto_hide_tab_bar';
  private static readonly AUTO_HIDE_FAB_KEY: string = 'auto_hide_fab';
  private static readonly HOME_HEADER_COLLAPSE_KEY: string = 'home_header_collapse';
  private static readonly TITLE_BAR_LOGO_KEY: string = 'title_bar_logo';
  private static readonly IMMERSIVE_TITLE_BAR_BLUR_KEY: string = 'immersive_title_bar_blur';
  private static readonly TITLE_BAR_STYLE_MODE_KEY: string = 'title_bar_style_mode';
  private static readonly TITLE_BAR_GLASS_MATERIAL_LEVEL_KEY: string = 'title_bar_glass_material_level';
  private static readonly REPLY_CAPSULE_MATERIAL_LEVEL_KEY: string = 'reply_capsule_material_level';
  private static readonly REPLY_CAPSULE_BUTTON_MATERIAL_ENABLED_KEY: string = 'reply_capsule_button_material_enabled';
  private static readonly COMPOSE_BUTTON_ENABLED_KEY: string = 'compose_button_enabled';
  private static readonly DARK_SURFACE_KEY: string = 'dark_surface';
  private static readonly AVATAR_TINT_ENABLED_KEY: string = 'avatar_tint_enabled';
  private static readonly SYSTEM_EMOJI_ENABLED_KEY: string = 'system_emoji_enabled';
  private static readonly COMPACT_SWITCH_STYLE_KEY: string = 'compact_switch_style';

  load(context: common.Context): AppearanceSettings {
    try {
      const options: preferences.Options = { name: AppearanceStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      const savedMode: string = store.getSync(AppearanceStore.MODE_KEY, DISPLAY_MODE_SYSTEM) as string;
      const savedAccent: string = store.getSync(AppearanceStore.ACCENT_KEY, DEFAULT_ACCENT_COLOR) as string;
      const savedFontMode: string = store.getSync(AppearanceStore.FONT_MODE_KEY, FONT_MODE_SYSTEM) as string;
      const savedFontScale: number = store.getSync(AppearanceStore.FONT_KEY, DEFAULT_FONT_SCALE) as number;
      const savedContentFontFamily: string = store.getSync(AppearanceStore.CONTENT_FONT_FAMILY_KEY,
        DEFAULT_CONTENT_FONT_FAMILY) as string;
      const savedAutoHideTitleBar: boolean =
        store.getSync(AppearanceStore.AUTO_HIDE_TITLE_BAR_KEY, false) as boolean;
      const savedAutoHideTabBar: boolean =
        store.getSync(AppearanceStore.AUTO_HIDE_TAB_BAR_KEY, false) as boolean;
      const savedHomeHeaderCollapseEnabled: boolean =
        store.getSync(AppearanceStore.HOME_HEADER_COLLAPSE_KEY, false) as boolean;
      const savedTitleBarLogoEnabled: boolean =
        store.getSync(AppearanceStore.TITLE_BAR_LOGO_KEY, true) as boolean;
      const savedAutoHideFab: boolean = store.getSync(AppearanceStore.AUTO_HIDE_FAB_KEY, true) as boolean;
      const savedImmersiveTitleBarBlurEnabled: boolean =
        store.getSync(AppearanceStore.IMMERSIVE_TITLE_BAR_BLUR_KEY, true) as boolean;
      const savedTitleBarStyleMode: number =
        store.getSync(AppearanceStore.TITLE_BAR_STYLE_MODE_KEY, -1) as number;
      const savedTitleBarGlassMaterialLevel: number =
        store.getSync(AppearanceStore.TITLE_BAR_GLASS_MATERIAL_LEVEL_KEY, -1) as number;
      const savedReplyCapsuleMaterialLevel: number =
        store.getSync(AppearanceStore.REPLY_CAPSULE_MATERIAL_LEVEL_KEY, -1) as number;
      const savedReplyCapsuleButtonMaterialEnabled: boolean =
        store.getSync(AppearanceStore.REPLY_CAPSULE_BUTTON_MATERIAL_ENABLED_KEY,
          DEFAULT_REPLY_CAPSULE_BUTTON_MATERIAL_ENABLED) as boolean;
      const savedComposeButtonEnabled: boolean =
        store.getSync(AppearanceStore.COMPOSE_BUTTON_ENABLED_KEY, true) as boolean;
      const savedDarkSurface: string =
        store.getSync(AppearanceStore.DARK_SURFACE_KEY, DARK_SURFACE_BLACK) as string;
      const savedAvatarTintEnabled: boolean =
        store.getSync(AppearanceStore.AVATAR_TINT_ENABLED_KEY, false) as boolean;
      const savedSystemEmojiEnabled: boolean =
        store.getSync(AppearanceStore.SYSTEM_EMOJI_ENABLED_KEY, false) as boolean;
      const savedCompactSwitchStyle: string =
        store.getSync(AppearanceStore.COMPACT_SWITCH_STYLE_KEY, COMPACT_SWITCH_TABS) as string;
      const mode: string = this.isValidMode(savedMode) ? savedMode : DISPLAY_MODE_SYSTEM;
      // Earlier builds used X blue and icon blue as implicit defaults. Migrate
      // only those defaults while preserving any explicit color selection.
    const accentColor: string = savedAccent === ICON_BLUE ? DEFAULT_ACCENT_COLOR :
      (savedAccent.length === 7 ? savedAccent : DEFAULT_ACCENT_COLOR);
      const fontMode: string = savedFontMode === FONT_MODE_APP ? FONT_MODE_APP : FONT_MODE_SYSTEM;
      return new AppearanceSettings(mode, accentColor, fontMode, this.clampFontScale(savedFontScale),
        savedAutoHideTitleBar === true, savedAutoHideTabBar === true, savedAutoHideFab === true,
        this.isValidDarkSurface(savedDarkSurface) ? savedDarkSurface : DARK_SURFACE_BLACK,
        savedComposeButtonEnabled === true,
        // 旧开关的"开"就是整份样式（沉浸档），"关"就是只剩材质（渐变档）。
        this.isValidTitleBarStyle(savedTitleBarStyleMode) ? savedTitleBarStyleMode :
          (savedImmersiveTitleBarBlurEnabled === true ? TITLE_BAR_STYLE_IMMERSIVE : TITLE_BAR_STYLE_BLUR),
        this.isValidTitleBarGlassLevel(savedTitleBarGlassMaterialLevel) ? savedTitleBarGlassMaterialLevel :
          DEFAULT_TITLE_BAR_GLASS_MATERIAL_LEVEL,
        savedHomeHeaderCollapseEnabled === true, this.validContentFontFamily(savedContentFontFamily) ?
          savedContentFontFamily : DEFAULT_CONTENT_FONT_FAMILY,
        this.isValidReplyCapsuleMaterialLevel(savedReplyCapsuleMaterialLevel) ?
          savedReplyCapsuleMaterialLevel : DEFAULT_REPLY_CAPSULE_MATERIAL_LEVEL,
        savedAvatarTintEnabled === true, savedTitleBarLogoEnabled === true, savedSystemEmojiEnabled === true,
        savedCompactSwitchStyle, savedReplyCapsuleButtonMaterialEnabled === true);
    } catch (error) {
      return new AppearanceSettings(DISPLAY_MODE_SYSTEM, DEFAULT_ACCENT_COLOR, FONT_MODE_SYSTEM,
        DEFAULT_FONT_SCALE, false, false, true, DARK_SURFACE_BLACK, true, TITLE_BAR_STYLE_IMMERSIVE,
        DEFAULT_TITLE_BAR_GLASS_MATERIAL_LEVEL);
    }
  }

  save(context: common.Context, settings: AppearanceSettings): void {
    try {
      const options: preferences.Options = { name: AppearanceStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      store.putSync(AppearanceStore.MODE_KEY, settings.mode);
      store.putSync(AppearanceStore.ACCENT_KEY, settings.accentColor);
      store.putSync(AppearanceStore.FONT_MODE_KEY, settings.fontMode);
      store.putSync(AppearanceStore.FONT_KEY, this.clampFontScale(settings.fontScale));
      store.putSync(AppearanceStore.CONTENT_FONT_FAMILY_KEY,
        this.validContentFontFamily(settings.contentFontFamily) ?
          settings.contentFontFamily : DEFAULT_CONTENT_FONT_FAMILY);
      store.putSync(AppearanceStore.AUTO_HIDE_TITLE_BAR_KEY, settings.autoHideTitleBar);
      store.putSync(AppearanceStore.AUTO_HIDE_TAB_BAR_KEY, settings.autoHideTabBar);
      store.putSync(AppearanceStore.AUTO_HIDE_FAB_KEY, settings.autoHideFab);
      store.putSync(AppearanceStore.HOME_HEADER_COLLAPSE_KEY, settings.homeHeaderCollapseEnabled);
      store.putSync(AppearanceStore.TITLE_BAR_STYLE_MODE_KEY,
        this.isValidTitleBarStyle(settings.titleBarStyleMode) ?
          settings.titleBarStyleMode : TITLE_BAR_STYLE_IMMERSIVE);
      store.putSync(AppearanceStore.TITLE_BAR_GLASS_MATERIAL_LEVEL_KEY,
        this.isValidTitleBarGlassLevel(settings.titleBarGlassMaterialLevel) ?
          settings.titleBarGlassMaterialLevel : DEFAULT_TITLE_BAR_GLASS_MATERIAL_LEVEL);
      store.putSync(AppearanceStore.REPLY_CAPSULE_MATERIAL_LEVEL_KEY,
        this.isValidReplyCapsuleMaterialLevel(settings.replyCapsuleMaterialLevel) ?
          settings.replyCapsuleMaterialLevel : DEFAULT_REPLY_CAPSULE_MATERIAL_LEVEL);
      store.putSync(AppearanceStore.REPLY_CAPSULE_BUTTON_MATERIAL_ENABLED_KEY,
        settings.replyCapsuleButtonMaterialEnabled);
      // 写回旧键，降级到旧版本时仍能得到接近的行为：只有整份样式对应旧版的"开"。
      store.putSync(AppearanceStore.IMMERSIVE_TITLE_BAR_BLUR_KEY,
        settings.titleBarStyleMode === TITLE_BAR_STYLE_IMMERSIVE);
      store.putSync(AppearanceStore.COMPOSE_BUTTON_ENABLED_KEY, settings.composeButtonEnabled);
      store.putSync(AppearanceStore.AVATAR_TINT_ENABLED_KEY, settings.avatarTintEnabled);
      store.putSync(AppearanceStore.SYSTEM_EMOJI_ENABLED_KEY, settings.systemEmojiEnabled);
      store.putSync(AppearanceStore.TITLE_BAR_LOGO_KEY, settings.titleBarLogoEnabled);
      store.putSync(AppearanceStore.COMPACT_SWITCH_STYLE_KEY,
        settings.compactSwitchStyle === COMPACT_SWITCH_BUTTONS ? COMPACT_SWITCH_BUTTONS : COMPACT_SWITCH_TABS);
      store.putSync(AppearanceStore.DARK_SURFACE_KEY,
        this.isValidDarkSurface(settings.darkSurface) ? settings.darkSurface : DARK_SURFACE_BLACK);
      store.flushSync();
    } catch (error) {
      // Preferences are an enhancement: a failed write must not interrupt UI.
    }
  }

  // The platform lets an app scale its own text with setFontSizeScale, but that
  // call permanently stops the process from following the system text size.
  // Apply it only for the in-app mode, and only when the process starts, so the
  // follow-system mode keeps working through the app configuration profile.
  applyFontMode(context: common.Context, settings: AppearanceSettings): void {
    if (settings.fontMode !== FONT_MODE_APP) {
      return;
    }
    this.applyFontScale(context, settings.fontScale);
  }

  applyFontScale(context: common.Context, fontScale: number): void {
    try {
      context.getApplicationContext().setFontSizeScale(this.clampFontScale(fontScale));
    } catch (error) {
      // The UI keeps rendering at the current scale when the platform refuses.
    }
  }

  clampFontScale(fontScale: number): number {
    if (fontScale < MIN_FONT_SCALE) {
      return MIN_FONT_SCALE;
    }
    if (fontScale > MAX_FONT_SCALE) {
      return MAX_FONT_SCALE;
    }
    return Math.round(fontScale * 100) / 100;
  }

  // AbilityContext exposes the merged Configuration, including the system text
  // scale that the follow-system mode tracks.
  systemFontScale(context: common.UIAbilityContext): number {
    const scale: number | undefined = context.config.fontSizeScale;
    if (scale === undefined || scale <= 0) {
      return DEFAULT_FONT_SCALE;
    }
    return scale;
  }

  colorMode(mode: string): ConfigurationConstant.ColorMode {
    if (mode === DISPLAY_MODE_LIGHT) {
      return ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
    }
    if (mode === DISPLAY_MODE_DARK) {
      return ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    }
    return ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
  }

  private isValidMode(mode: string): boolean {
    return mode === DISPLAY_MODE_SYSTEM || mode === DISPLAY_MODE_LIGHT || mode === DISPLAY_MODE_DARK;
  }

  private validContentFontFamily(family: string): boolean {
    return family === CONTENT_FONT_FAMILY_SYSTEM || family === CONTENT_FONT_FAMILY_SERIF ||
      family === CONTENT_FONT_FAMILY_MONOSPACE;
  }

  private isValidDarkSurface(surface: string): boolean {
    return surface === DARK_SURFACE_BLACK || surface === DARK_SURFACE_GENTLE;
  }

  private isValidTitleBarStyle(mode: number): boolean {
    return mode === TITLE_BAR_STYLE_IMMERSIVE || mode === TITLE_BAR_STYLE_BLUR ||
      mode === TITLE_BAR_STYLE_GLASS || mode === TITLE_BAR_STYLE_GLASS_ONLY;
  }

  private isValidTitleBarGlassLevel(level: number): boolean {
    return level === TITLE_BAR_GLASS_ULTRA_THIN || level === TITLE_BAR_GLASS_THIN ||
      level === TITLE_BAR_GLASS_REGULAR || level === TITLE_BAR_GLASS_THICK ||
      level === TITLE_BAR_GLASS_ULTRA_THICK;
  }

  private isValidReplyCapsuleMaterialLevel(level: number): boolean {
    return level === TITLE_BAR_GLASS_ULTRA_THIN || level === TITLE_BAR_GLASS_THIN ||
      level === TITLE_BAR_GLASS_REGULAR || level === TITLE_BAR_GLASS_THICK ||
      level === TITLE_BAR_GLASS_ULTRA_THICK;
  }
}
