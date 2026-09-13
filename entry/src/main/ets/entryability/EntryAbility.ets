import UIAbility from '@ohos.app.ability.UIAbility';
import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import hilog from '@ohos.hilog';
import window from '@ohos.window';
import type Want from '@ohos.app.ability.Want';
import { REDIRECT_URI } from '../services/XApiClient';
import { oauthFlowStore } from '../services/OAuthFlowStore';
import { AppearanceStore } from '../services/AppearanceStore';
import { LanguageStore } from '../services/LanguageStore';
import { GripHandManager } from '../utils/GripHandManager';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';

const DOMAIN = 0xFF00;
const TAG = 'HarmonyX-EntryAbility';
const STATUS_BAR_HEIGHT_KEY: string = 'harmonyx.status_bar_height';
const NAVIGATION_INDICATOR_HEIGHT_KEY: string = 'harmonyx.navigation_indicator_height';
const BREAKPOINT_KEY: string = 'harmonyx.breakpoint';

export default class EntryAbility extends UIAbility {
  private windowStage: window.WindowStage | null = null;
  private callbackUri: string = '';
  private appearanceStore: AppearanceStore = new AppearanceStore();
  private languageStore: LanguageStore = new LanguageStore();

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onCreate');
    const appearance = this.appearanceStore.load(this.context);
    const language: string = this.languageStore.load(this.context);
    AppStorage.setOrCreate<string>('harmonyx.display_mode', appearance.mode);
    AppStorage.setOrCreate<string>('harmonyx.accent_color', appearance.accentColor);
    AppStorage.setOrCreate<number>('harmonyx.font_scale', appearance.fontScale);
    AppStorage.setOrCreate<string>('harmonyx.app_language', language);
    AppStorage.setOrCreate<boolean>('harmonyx.grip_hand_enabled', true);
    AppStorage.setOrCreate<string>(BREAKPOINT_KEY, ResponsiveLayout.BREAKPOINT_SM);
    AppStorage.setOrCreate<boolean>(ResponsiveLayout.CONTENT_DESTINATION_OPEN_KEY, false);
    this.restoreGripHandPreference();
    try {
      this.context.getApplicationContext().setColorMode(this.appearanceStore.colorMode(appearance.mode));
    } catch (error) {
      hilog.warn(DOMAIN, TAG, '%{public}s', 'Unable to restore display color mode');
    }
    this.readOAuthCallback(want);
  }

  private async restoreGripHandPreference(): Promise<void> {
    const manager: GripHandManager = GripHandManager.getInstance();
    await manager.load(this.context);
    AppStorage.setOrCreate<boolean>('harmonyx.grip_hand_enabled', manager.isGripHandEnabled());
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.readOAuthCallback(want);
    if (this.callbackUri.length > 0 && this.windowStage !== null) {
      this.openOAuthCallback(this.callbackUri);
    }
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageCreate');
    this.windowStage = windowStage;
    this.configureFullScreen(windowStage).then(() => {
      this.showInitialPage(windowStage);
    });
  }

  private showInitialPage(windowStage: window.WindowStage): void {
    if (this.callbackUri.length > 0) {
      this.openOAuthCallback(this.callbackUri);
      return;
    }
    this.loadHomePage(windowStage);
  }

  private async configureFullScreen(windowStage: window.WindowStage): Promise<void> {
    try {
      const mainWindow: window.Window = windowStage.getMainWindowSync();
      await mainWindow.setWindowLayoutFullScreen(true);
    } catch (error) {
      const businessError: BusinessError = error as BusinessError;
      hilog.error(DOMAIN, TAG, 'Failed to enable full-screen layout: %{public}d', businessError.code);
    }
  }

  private readOAuthCallback(want: Want): void {
    const uri: string = want.uri === undefined ? '' : want.uri;
    if (uri.startsWith(REDIRECT_URI)) {
      this.callbackUri = uri;
      hilog.info(DOMAIN, TAG, '%{public}s', 'OAuth callback received');
    }
  }

  private async openOAuthCallback(callbackUri: string): Promise<void> {
    if (this.windowStage === null) {
      return;
    }
    const saved: boolean = await oauthFlowStore.saveCallback(this.context, callbackUri);
    if (!saved) {
      hilog.error(DOMAIN, TAG, '%{public}s', 'Unable to save OAuth callback');
      this.loadHomePage(this.windowStage);
      return;
    }
    this.windowStage.loadContent('pages/OAuthCallback', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load callback: %{public}s', JSON.stringify(err));
        return;
      }
      this.restoreApplicationLanguage();
    });
  }

  private loadHomePage(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load content: %{public}s', JSON.stringify(err));
        return;
      }
      this.observeWindowAvoidAreas(windowStage);
      this.restoreApplicationLanguage();
      hilog.info(DOMAIN, TAG, '%{public}s', 'Content loaded successfully');
    });
  }

  // The platform requires the first setLanguage() call after the page has
  // loaded, so restore persisted language from the loadContent callback.
  private restoreApplicationLanguage(): void {
    const language: string = this.languageStore.load(this.context);
    try {
      this.context.getApplicationContext().setLanguage(language);
    } catch (error) {
      hilog.warn(DOMAIN, TAG, '%{public}s', 'Unable to restore application language');
    }
  }

  private observeWindowAvoidAreas(windowStage: window.WindowStage): void {
    try {
      const mainWindow: window.Window = windowStage.getMainWindowSync();
      const uiContext: UIContext = mainWindow.getUIContext();
      const systemAvoidArea: window.AvoidArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const navigationAvoidArea: window.AvoidArea =
        mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      AppStorage.setOrCreate<number>(STATUS_BAR_HEIGHT_KEY, uiContext.px2vp(systemAvoidArea.topRect.height));
      AppStorage.setOrCreate<number>(NAVIGATION_INDICATOR_HEIGHT_KEY,
        uiContext.px2vp(navigationAvoidArea.bottomRect.height));
      const windowRect: window.Rect = mainWindow.getWindowProperties().windowRect;
      this.updateResponsiveState(uiContext, windowRect.width);
      mainWindow.on('windowSizeChange', (windowSize: window.Size): void => {
        this.updateResponsiveState(uiContext, windowSize.width);
      });
      mainWindow.on('avoidAreaChange', (avoidAreaOption) => {
        if (avoidAreaOption.type === window.AvoidAreaType.TYPE_SYSTEM) {
          AppStorage.setOrCreate<number>(STATUS_BAR_HEIGHT_KEY, uiContext.px2vp(avoidAreaOption.area.topRect.height));
        } else if (avoidAreaOption.type === window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR) {
          AppStorage.setOrCreate<number>(NAVIGATION_INDICATOR_HEIGHT_KEY,
            uiContext.px2vp(avoidAreaOption.area.bottomRect.height));
        }
      });
    } catch (error) {
      const businessError: BusinessError = error as BusinessError;
      hilog.error(DOMAIN, TAG, 'Failed to observe window avoid areas: %{public}d', businessError.code);
    }
  }

  private updateResponsiveState(uiContext: UIContext, windowWidthPx: number): void {
    const widthVp: number = uiContext.px2vp(windowWidthPx);
    const breakpoint: string = ResponsiveLayout.breakpointForWidth(widthVp);
    AppStorage.setOrCreate<string>(BREAKPOINT_KEY, breakpoint);
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onBackground');
  }
}
