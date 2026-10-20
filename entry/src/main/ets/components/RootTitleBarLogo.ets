import { ColorMetrics } from '@kit.ArkUI';
import {
  APP_ICON_DEFAULT,
  APP_ICON_X_BLACK,
  APP_ICON_X_WHITE,
  STORAGE_KEY_CURRENT_APP_ICON,
  titleBarLogoForeground
} from '../services/AppIconStore';
import { STORAGE_KEY_SYSTEM_DARK, STORAGE_KEY_TITLE_BAR_LOGO_AUTO_CONTRAST } from '../services/AppearanceStore';

@Component
export struct RootTitleBarLogo {
  @StorageProp(STORAGE_KEY_CURRENT_APP_ICON) private iconName: string = '';
  @StorageProp('harmonyx.display_mode') private displayMode: string = '';
  @StorageProp(STORAGE_KEY_SYSTEM_DARK) private systemDark: boolean = false;
  @StorageProp(STORAGE_KEY_TITLE_BAR_LOGO_AUTO_CONTRAST) private autoContrast: boolean = true;

  private isDarkMode(): boolean {
    return this.displayMode === 'dark' || (this.displayMode !== 'light' && this.systemDark);
  }

  private shouldTintX(): boolean {
    return this.autoContrast && (this.iconName === APP_ICON_DEFAULT ||
      this.iconName === APP_ICON_X_BLACK || this.iconName === APP_ICON_X_WHITE);
  }

  private filter(): ColorFilter {
    const inkColor: ResourceColor = this.isDarkMode() ? Color.White : Color.Black;
    const ink: ColorMetrics = ColorMetrics.resourceColor(inkColor);
    return new ColorFilter([0, 0, 0, ink.red / 255, 0, 0, 0, 0, ink.green / 255, 0,
      0, 0, 0, ink.blue / 255, 0, 0, 0, 0, 1, 0]);
  }

  build(): void {
    if (this.shouldTintX()) {
      Image(titleBarLogoForeground(this.iconName)).width(30).height(30).objectFit(ImageFit.Contain)
        .colorFilter(this.filter());
    } else {
      Image(titleBarLogoForeground(this.iconName)).width(30).height(30).objectFit(ImageFit.Contain);
    }
  }
}
