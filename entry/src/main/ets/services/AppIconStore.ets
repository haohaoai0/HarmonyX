// 桌面图标切换。HarmonyOS 7.0（API 26）起，应用可以切换自己在
// app.json5 的 alternateIcons 里声明的备用图标，图标随安装包发布，
// 不需要再走 AppGallery Connect 的动态图标服务与审核，也就没有
// 5 个默认 / 10 个上限的配额限制。选择结果由系统按用户保存，
// 所以这里只负责读写系统状态，不再本地落一份偏好。
import { bundleManager } from '@kit.AbilityKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import type { BusinessError } from '@kit.BasicServicesKit';

// 传空字符串表示取消备用图标，回到 app.json5 的默认图标。
export const STORAGE_KEY_CURRENT_APP_ICON: string = 'harmonyx.current_app_icon';
export const APP_ICON_DEFAULT: string = '';
// 备用图标接口的起始版本，低版本设备需要降级处理。
export const APP_ICON_REQUIRED_API: string = '26.0.0';

// 备用图标名称，必须与 app.json5 中 alternateIcons 的 name 字段一致。
export const APP_ICON_CLASSIC: string = 'classic';
export const APP_ICON_SPECTRUM: string = 'spectrum';
export const APP_ICON_OUTLINE: string = 'outline';
export const APP_ICON_BRUSH: string = 'brush';
export const APP_ICON_BLOSSOM: string = 'blossom';
export const APP_ICON_BLUE_BIRD: string = 'blue_bird';
export const APP_ICON_TWITTER_BLUE: string = 'twitter_blue';
export const APP_ICON_TWITTER_WHITE: string = 'twitter_white';
export const APP_ICON_X_BLACK: string = 'x_black';
export const APP_ICON_X_WHITE: string = 'x_white';
export const APP_ICON_FROG_WHITE: string = 'frog_white';
export const APP_ICON_FROG_BLACK: string = 'frog_black';
export const APP_ICON_MILK_FROG_WHITE: string = 'milk_frog_white';
export const APP_ICON_MILK_FROG_BLACK: string = 'milk_frog_black';
export const APP_ICON_ZOMBIE_X: string = 'zombie_x';
export const APP_ICON_MID_AUTUMN: string = 'mid_autumn';

// 中秋限时图标的开放时间：2026 年 9 月 25 日 0 点到 9 月 29 日 0 点，
// 也就是 9 月 25 日至 9 月 28 日全天，按设备本地时间判断。
const MID_AUTUMN_YEAR: number = 2026;
// Date 的月份从 0 开始，8 表示 9 月。
const MID_AUTUMN_MONTH: number = 8;
const MID_AUTUMN_FIRST_DAY: number = 25;
const MID_AUTUMN_END_DAY: number = 29;

// 当前版本提供全部备用图标名称，用来识别系统里残留的旧选择
// （例如某个图标在新版本里被删掉，系统仍记着它的名字）。
export const APP_ICON_NAMES: string[] = [
  APP_ICON_CLASSIC,
  APP_ICON_SPECTRUM,
  APP_ICON_OUTLINE,
  APP_ICON_BRUSH,
  APP_ICON_BLOSSOM,
  APP_ICON_BLUE_BIRD,
  APP_ICON_TWITTER_BLUE,
  APP_ICON_TWITTER_WHITE,
  APP_ICON_X_BLACK,
  APP_ICON_X_WHITE,
  APP_ICON_FROG_WHITE,
  APP_ICON_FROG_BLACK,
  APP_ICON_MILK_FROG_WHITE,
  APP_ICON_MILK_FROG_BLACK,
  APP_ICON_ZOMBIE_X,
  APP_ICON_MID_AUTUMN
];

export function isKnownAppIcon(name: string): boolean {
  if (name === APP_ICON_DEFAULT) {
    return true;
  }
  for (let i: number = 0; i < APP_ICON_NAMES.length; i++) {
    if (APP_ICON_NAMES[i] === name) {
      return true;
    }
  }
  return false;
}

// 中秋限时图标是否还在开放期内。过了 9 月 28 日就不再展示，
// 正在使用它的用户会被换回默认图标。
export function isMidAutumnIconAvailable(): boolean {
  const now: Date = new Date();
  if (now.getFullYear() !== MID_AUTUMN_YEAR) {
    return false;
  }
  if (now.getMonth() !== MID_AUTUMN_MONTH) {
    return false;
  }
  const day: number = now.getDate();
  return day >= MID_AUTUMN_FIRST_DAY && day < MID_AUTUMN_END_DAY;
}

// 系统版本低于 7.0，接口不存在。
export const APP_ICON_ERROR_UNSUPPORTED: number = -1;
// 用户启用了带本应用图标的第三方主题，系统拒绝切换。
export const APP_ICON_ERROR_THEME_CONFLICT: number = 17700310;
// 分身应用不支持备用图标。
export const APP_ICON_ERROR_CLONE_UNSUPPORTED: number = 17700311;

export class AppIconOption {
  name: string;
  label: Resource;
  preview: Resource;

  constructor(name: string, label: Resource, preview: Resource) {
    this.name = name;
    this.label = label;
    this.preview = preview;
  }
}

export class AppIconApplyResult {
  ok: boolean;
  code: number;

  constructor(ok: boolean, code: number) {
    this.ok = ok;
    this.code = code;
  }
}

export function appIconForeground(name: string): Resource {
  if (name === APP_ICON_CLASSIC) { return $r('app.media.app_icon_classic_foreground'); }
  if (name === APP_ICON_SPECTRUM) { return $r('app.media.app_icon_spectrum_foreground'); }
  if (name === APP_ICON_OUTLINE) { return $r('app.media.app_icon_outline_foreground'); }
  if (name === APP_ICON_BRUSH) { return $r('app.media.app_icon_brush_foreground'); }
  if (name === APP_ICON_BLOSSOM) { return $r('app.media.app_icon_blossom_foreground'); }
  if (name === APP_ICON_BLUE_BIRD) { return $r('app.media.app_icon_blue_bird_foreground'); }
  if (name === APP_ICON_TWITTER_BLUE) { return $r('app.media.app_icon_twitter_blue_foreground'); }
  if (name === APP_ICON_TWITTER_WHITE) { return $r('app.media.app_icon_twitter_white_foreground'); }
  if (name === APP_ICON_X_BLACK) { return $r('app.media.app_icon_x_black_foreground'); }
  if (name === APP_ICON_X_WHITE) { return $r('app.media.app_icon_x_white_foreground'); }
  if (name === APP_ICON_FROG_WHITE || name === APP_ICON_FROG_BLACK) { return $r('app.media.frog_foreground'); }
  if (name === APP_ICON_MILK_FROG_WHITE || name === APP_ICON_MILK_FROG_BLACK) { return $r('app.media.milk_frog_foreground'); }
  if (name === APP_ICON_ZOMBIE_X) { return $r('app.media.zombie_x_foreground'); }
  if (name === APP_ICON_MID_AUTUMN) { return $r('app.media.app_icon_mid_autumn_foreground'); }
  return $r('app.media.ui_brand_foreground');
}

// The title-bar mark is always glyph artwork. The default branding resource
// can carry an icon plate in some resource qualifiers, so use a transparent
// X-only foreground and let RootTitleBarLogo apply the selected ink color.
export function titleBarLogoForeground(name: string): Resource {
  if (name === APP_ICON_DEFAULT) {
    return $r('app.media.title_bar_logo_foreground');
  }
  return appIconForeground(name);
}

export class AppIconStore {
  supported(): boolean {
    if (deviceInfo.apiAvailable('26.0.0')) {
      return true;
    }
    return false;
  }

  // 当前启用的备用图标名称；返回空串表示正在使用默认图标。
  async currentName(): Promise<string> {
    if (!this.supported()) {
      return APP_ICON_DEFAULT;
    }
    try {
      const icons: bundleManager.AlternateIconInfo[] = await bundleManager.getAlternateIcons();
      for (let i: number = 0; i < icons.length; i++) {
        if (icons[i].enabled) {
          AppStorage.setOrCreate<string>(STORAGE_KEY_CURRENT_APP_ICON, icons[i].iconName);
          return icons[i].iconName;
        }
      }
    } catch (error) {
      // 分身应用会拒绝查询，此时按默认图标展示。
    }
    AppStorage.setOrCreate<string>(STORAGE_KEY_CURRENT_APP_ICON, APP_ICON_DEFAULT);
    return APP_ICON_DEFAULT;
  }

  async select(name: string): Promise<AppIconApplyResult> {
    if (!this.supported()) {
      return new AppIconApplyResult(false, APP_ICON_ERROR_UNSUPPORTED);
    }
    try {
      await bundleManager.setAlternateIcon(name);
      AppStorage.setOrCreate<string>(STORAGE_KEY_CURRENT_APP_ICON, name);
      return new AppIconApplyResult(true, 0);
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      return new AppIconApplyResult(false, failure.code);
    }
  }
}
