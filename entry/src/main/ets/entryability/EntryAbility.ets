import UIAbility from '@ohos.app.ability.UIAbility';
import { videoKeepAwake } from '../services/VideoKeepAwake';
import { interactionSettingsStore } from '../services/InteractionSettingsStore';
import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import hilog from '@ohos.hilog';
import window from '@ohos.window';
import type Want from '@ohos.app.ability.Want';
import { WindowManager } from '@kit.SpeechKit';
import { REDIRECT_URI } from '../services/XApiClient';
import { sheetMaterialSettingsStore } from '../services/SheetMaterialSettingsStore';
import { oauthFlowStore } from '../services/OAuthFlowStore';
import {
  AppearanceSettings,
  AppearanceStore,
  STORAGE_KEY_CONTENT_FONT_FAMILY,
  STORAGE_KEY_SYSTEM_EMOJI_ENABLED,
  DEFAULT_ACCENT_COLOR,
  DEFAULT_FONT_SCALE,
  DISPLAY_MODE_SYSTEM,
  FONT_MODE_SYSTEM,
  STORAGE_KEY_AUTO_HIDE_FAB,
  STORAGE_KEY_HOME_HEADER_COLLAPSE,
  STORAGE_KEY_TITLE_BAR_LOGO,
  STORAGE_KEY_COMPACT_SWITCH_STYLE,
  STORAGE_KEY_AUTO_HIDE_TAB_BAR,
  STORAGE_KEY_AUTO_HIDE_TITLE_BAR,
  STORAGE_KEY_COMPOSE_BUTTON_ENABLED,
  STORAGE_KEY_AVATAR_TINT_ENABLED,
  STORAGE_KEY_DARK_SURFACE,
  STORAGE_KEY_IMMERSIVE_TITLE_BAR_BLUR,
  STORAGE_KEY_TITLE_BAR_STYLE_MODE,
  STORAGE_KEY_TITLE_BAR_GLASS_MATERIAL_LEVEL,
  STORAGE_KEY_REPLY_CAPSULE_MATERIAL_LEVEL,
  STORAGE_KEY_REPLY_CAPSULE_BUTTON_MATERIAL_ENABLED
} from '../services/AppearanceStore';
import { APP_LANGUAGE_SYSTEM, LanguageStore } from '../services/LanguageStore';
import { GripHandManager } from '../utils/GripHandManager';
import { layoutSettingsStore, STORAGE_KEY_DESKTOP_LAYOUT, STORAGE_KEY_DESKTOP_ASIDE,
  STORAGE_KEY_DESKTOP_RAIL_AUTO_HIDE, STORAGE_KEY_DESKTOP_RAIL_MATERIAL_LEVEL } from '../services/LayoutSettingsStore';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';
import { STORAGE_KEY_DESKTOP_RAIL_SWIPE, STORAGE_KEY_SIDEBAR_MATERIAL_TYPE } from '../services/LayoutSettingsStore';
import { STORAGE_KEY_DESKTOP_VIDEO_LAYOUT } from '../services/LayoutSettingsStore';
import { sidebarHandleStore, SidebarHandleState, STORAGE_KEY_SIDEBAR_HANDLE_STYLE,
  STORAGE_KEY_SIDEBAR_HANDLE_PATH } from '../services/SidebarHandleStore';
import { classifyXLink, STORAGE_KEY_EXTERNAL_LINK } from '../utils/XLinkRouter';
import { linkSettingsStore, STORAGE_KEY_LINK_IN_APP, STORAGE_KEY_LINK_PREVIEW_URL } from '../services/LinkSettingsStore';
import {
  mediaSettingsStore,
  STORAGE_KEY_CAPTION_OPACITY,
  STORAGE_KEY_HOME_VIDEO_MUTED,
  STORAGE_KEY_VIEWER_VIDEO_MUTED,
  STORAGE_KEY_IMAGE_QUALITY,
  STORAGE_KEY_MEDIA_VIEWER_BLACK_BACKGROUND,
  STORAGE_KEY_MEDIA_COMMENT_BACKGROUND,
  STORAGE_KEY_VIDEO_COMMENT_PROGRESS_RING,
  STORAGE_KEY_SHOW_SENSITIVE_MEDIA,
  STORAGE_KEY_VIDEO_AUTO_PIP,
  STORAGE_KEY_VIDEO_AUTOPLAY,
  STORAGE_KEY_VIDEO_BACKGROUND_MODE,
  STORAGE_KEY_VIDEO_CONTROL_STYLE,
  STORAGE_KEY_VIDEO_FEED_CONTROLS_ALWAYS_VISIBLE,
  STORAGE_KEY_VIDEO_FEED_LAYOUT,
  STORAGE_KEY_VIDEO_FEED_TAP_PAUSE,
  STORAGE_KEY_VIDEO_HOLD_SPEED,
  STORAGE_KEY_VIDEO_IMMERSIVE_FILL,
  STORAGE_KEY_VIDEO_QUALITY,
  STORAGE_KEY_VIDEO_AUTO_BITRATE_CAP,
  DEFAULT_VIDEO_AUTO_BITRATE_CAP,
  VIDEO_CONTROL_STYLE_SPACED
} from '../services/MediaSettingsStore';
import {
  notificationSettingsStore,
  STORAGE_KEY_NOTIFICATION_ALERTS,
  STORAGE_KEY_NOTIFICATION_DND_SILENT,
  STORAGE_KEY_SYSTEM_NOTIFICATIONS
} from '../services/NotificationSettingsStore';
import {
  STORAGE_KEY_DEFAULT_HOME_FEED,
  STORAGE_KEY_TIMELINE_COLUMNS,
  timelineSettingsStore
} from '../services/TimelineSettingsStore';
import {
  bottomBarSettingsStore,
  STORAGE_KEY_BOTTOM_BAR_PAGES
} from '../services/BottomBarSettingsStore';
import {
  hdsTabsSettingsStore,
  STORAGE_KEY_CLASSIC_BOTTOM_BAR,
  STORAGE_KEY_HOME_TAB_MATERIAL_LEVEL,
  STORAGE_KEY_ROOT_TAB_LABELS_VISIBLE
} from '../services/HdsTabsSettingsStore';
import {
  readAloudSettingsStore,
  STORAGE_KEY_READ_ALOUD_ENTRY_ENABLED
} from '../services/ReadAloudSettingsStore';
import { videoPipPlaybackKeeper } from '../services/VideoPipPlaybackKeeper';
import {
  PressEffectSettingsStore,
  STORAGE_KEY_PRESS_EFFECT_ENABLED
} from '../services/PressEffectSettingsStore';
import {
  STORAGE_KEY_TRANSLATION_AUTO_ENABLED,
  STORAGE_KEY_TRANSLATION_ENABLED,
  STORAGE_KEY_TRANSLATION_REPLACE_ORIGINAL,
  TranslationSettings,
  translationStore
} from '../services/TranslationStore';
import { proxyStore } from '../services/ProxyStore';
import { GROK_WEB_SESSION_ORIGINS, webSessionStore } from '../services/WebSessionStore';
import { continuationStore } from '../services/ContinuationState';
import { downloadManager } from '../services/DownloadManager';
import { AppIconScheduleStore } from '../services/AppIconScheduleStore';
import { STORAGE_KEY_POST_TIME_NOW } from '../utils/PostTime';
import { accountStore } from '../services/AccountStore';
import { spacePreferencesStore } from '../services/SpacePreferencesStore';
import { xPrivateClient } from '../services/XPrivateClient';
import { externalShareStore, STORAGE_KEY_EXTERNAL_SHARE } from '../services/ExternalShareStore';
import promptAction from '@ohos.promptAction';
import { Configuration } from '@kit.AbilityKit';
import { i18n } from '@kit.LocalizationKit';
import { publishAppLocale } from '../utils/AppLocale';
import { appFontStore } from '../services/AppFontStore';

const DOMAIN = 0xFF00;
const TAG = 'HarmonyX-EntryAbility';
const STATUS_BAR_HEIGHT_KEY: string = 'harmonyx.status_bar_height';
const NAVIGATION_INDICATOR_HEIGHT_KEY: string = 'harmonyx.navigation_indicator_height';
const BREAKPOINT_KEY: string = 'harmonyx.breakpoint';
const WINDOW_WIDTH_KEY: string = 'harmonyx.window_width';
const WINDOW_HEIGHT_KEY: string = 'harmonyx.window_height';
const OPEN_NOTIFICATIONS_KEY: string = 'harmonyx.open_notifications_request';
const OPEN_MESSAGES_KEY: string = 'harmonyx.open_messages_request';
const SUPPORT_CONTINUE_PAGE_STACK_PARAMETER: string =
  'ohos.extra.param.key.supportContinuePageStack';

export default class EntryAbility extends UIAbility {
  private windowStage: window.WindowStage | null = null;
  private observedWindow: window.Window | null = null;
  private windowSizeListener: ((size: window.Size) => void) | null = null;
  private avoidAreaListener: ((area: window.AvoidAreaOptions) => void) | null = null;
  private callbackUri: string = '';
  private appearanceStore: AppearanceStore = new AppearanceStore();
  private appearanceSettings: AppearanceSettings = new AppearanceSettings(DISPLAY_MODE_SYSTEM,
    DEFAULT_ACCENT_COLOR, FONT_MODE_SYSTEM, DEFAULT_FONT_SCALE);
  private languageStore: LanguageStore = new LanguageStore();
  private pressEffectSettingsStore: PressEffectSettingsStore = new PressEffectSettingsStore();
  private appIconScheduleStore: AppIconScheduleStore = new AppIconScheduleStore();
  private appIconScheduleRefreshTimerId: number = -1;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onCreate');
    AppStorage.setOrCreate<number>(STORAGE_KEY_POST_TIME_NOW, Date.now());
    downloadManager.initialize(this.context);
    const appearance = this.appearanceStore.load(this.context);
    appFontStore.initialize(this.context);
    sheetMaterialSettingsStore.initialize(this.context);
    spacePreferencesStore.beginSession(this.context);
    this.appearanceSettings = appearance;
    const language: string = this.languageStore.load(this.context);
    AppStorage.setOrCreate<string>('harmonyx.display_mode', appearance.mode);
    AppStorage.setOrCreate<string>('harmonyx.accent_color', appearance.accentColor);
    AppStorage.setOrCreate<string>('harmonyx.font_mode', appearance.fontMode);
    AppStorage.setOrCreate<number>('harmonyx.font_scale', appearance.fontScale);
    AppStorage.setOrCreate<string>(STORAGE_KEY_CONTENT_FONT_FAMILY, appearance.contentFontFamily);
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_SYSTEM_EMOJI_ENABLED, appearance.systemEmojiEnabled);
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_AUTO_HIDE_TITLE_BAR, appearance.autoHideTitleBar);
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_AUTO_HIDE_TAB_BAR, appearance.autoHideTabBar);
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_AUTO_HIDE_FAB, appearance.autoHideFab);
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_HOME_HEADER_COLLAPSE, appearance.homeHeaderCollapseEnabled);
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_TITLE_BAR_LOGO, appearance.titleBarLogoEnabled);
    AppStorage.setOrCreate<string>(STORAGE_KEY_COMPACT_SWITCH_STYLE, appearance.compactSwitchStyle);
    AppStorage.setOrCreate<number>(STORAGE_KEY_TITLE_BAR_STYLE_MODE, appearance.titleBarStyleMode);
    AppStorage.setOrCreate<number>(STORAGE_KEY_TITLE_BAR_GLASS_MATERIAL_LEVEL,
      appearance.titleBarGlassMaterialLevel);
    AppStorage.setOrCreate<number>(STORAGE_KEY_REPLY_CAPSULE_MATERIAL_LEVEL,
      appearance.replyCapsuleMaterialLevel);
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_REPLY_CAPSULE_BUTTON_MATERIAL_ENABLED,
      appearance.replyCapsuleButtonMaterialEnabled);
    // 旧键仍写入，旧版本或尚未迁移的读取方按它的语义（开 = 有模糊）工作。
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_IMMERSIVE_TITLE_BAR_BLUR,
      appearance.titleBarStyleMode !== 2);
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_COMPOSE_BUTTON_ENABLED, appearance.composeButtonEnabled);
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_AVATAR_TINT_ENABLED, appearance.avatarTintEnabled);
    AppStorage.setOrCreate<string>(STORAGE_KEY_DARK_SURFACE, appearance.darkSurface);
    AppStorage.setOrCreate<string>('harmonyx.app_language', language);
    AppStorage.setOrCreate<boolean>('harmonyx.grip_hand_enabled', true);
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_DESKTOP_LAYOUT, layoutSettingsStore.load(this.context));
    AppStorage.setOrCreate<number>(STORAGE_KEY_DESKTOP_VIDEO_LAYOUT, layoutSettingsStore.loadDesktopVideoLayout(this.context));
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_DESKTOP_ASIDE, layoutSettingsStore.loadAsideEnabled(this.context));
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_DESKTOP_RAIL_AUTO_HIDE, layoutSettingsStore.loadRailAutoHide(this.context));
    AppStorage.setOrCreate<number>(STORAGE_KEY_DESKTOP_RAIL_MATERIAL_LEVEL, layoutSettingsStore.loadRailMaterialLevel(this.context));
    AppStorage.setOrCreate<number>(STORAGE_KEY_SIDEBAR_MATERIAL_TYPE, layoutSettingsStore.loadSidebarMaterialType(this.context));
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_DESKTOP_RAIL_SWIPE, layoutSettingsStore.loadRailSwipe(this.context));
    const handleState: SidebarHandleState = sidebarHandleStore.load(this.context);
    AppStorage.setOrCreate<string>(STORAGE_KEY_SIDEBAR_HANDLE_PATH, handleState.path);
    AppStorage.setOrCreate<string>(STORAGE_KEY_SIDEBAR_HANDLE_STYLE, handleState.style);
    AppStorage.setOrCreate<string>(BREAKPOINT_KEY, ResponsiveLayout.BREAKPOINT_SM);
    AppStorage.setOrCreate<number>(WINDOW_WIDTH_KEY, 0);
    AppStorage.setOrCreate<number>(WINDOW_HEIGHT_KEY, 0);
    AppStorage.setOrCreate<boolean>(ResponsiveLayout.CONTENT_DESTINATION_OPEN_KEY, false);
    AppStorage.setOrCreate<number>('harmonyx.posts_changed', 0);
    // Bumped by the account store so the root page reloads on a switch.
    AppStorage.setOrCreate<number>('harmonyx.accounts_changed', 0);
    const linkInApp: boolean = linkSettingsStore.load(this.context);
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_LINK_IN_APP, linkInApp);
    AppStorage.setOrCreate<string>(STORAGE_KEY_LINK_PREVIEW_URL, '');
    const videoAutoplay: boolean = mediaSettingsStore.loadVideoAutoplay(this.context);
    interactionSettingsStore.publish(interactionSettingsStore.load(this.context));
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_VIDEO_AUTOPLAY, videoAutoplay);
    const showSensitiveMedia: boolean = mediaSettingsStore.loadShowSensitiveMedia(this.context);
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_SHOW_SENSITIVE_MEDIA, showSensitiveMedia);
    const homeVideoMuted: boolean = mediaSettingsStore.loadHomeVideoMuted(this.context);
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_HOME_VIDEO_MUTED, homeVideoMuted);
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_VIEWER_VIDEO_MUTED,
      mediaSettingsStore.loadViewerVideoMuted(this.context));
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_MEDIA_VIEWER_BLACK_BACKGROUND,
      mediaSettingsStore.loadMediaViewerBlackBackground(this.context));
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_MEDIA_COMMENT_BACKGROUND,
      mediaSettingsStore.loadMediaCommentBackground(this.context));
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_VIDEO_COMMENT_PROGRESS_RING,
      mediaSettingsStore.loadVideoCommentProgressRing(this.context));
    const imageQuality: number = mediaSettingsStore.loadImageQuality(this.context);
    AppStorage.setOrCreate<number>(STORAGE_KEY_IMAGE_QUALITY, imageQuality);
    const videoQuality: number = mediaSettingsStore.loadVideoQuality(this.context);
    AppStorage.setOrCreate<number>(STORAGE_KEY_VIDEO_QUALITY, videoQuality);
    AppStorage.setOrCreate<number>(STORAGE_KEY_VIDEO_AUTO_BITRATE_CAP, DEFAULT_VIDEO_AUTO_BITRATE_CAP);
    const videoAutoPip: boolean = mediaSettingsStore.loadVideoAutoPip(this.context);
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_VIDEO_AUTO_PIP, videoAutoPip);
    const videoImmersiveFill: boolean = mediaSettingsStore.loadVideoImmersiveFill(this.context);
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_VIDEO_IMMERSIVE_FILL, videoImmersiveFill);
    const videoFeedControlsAlwaysVisible: boolean =
      mediaSettingsStore.loadVideoFeedControlsAlwaysVisible(this.context);
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_VIDEO_FEED_CONTROLS_ALWAYS_VISIBLE,
      videoFeedControlsAlwaysVisible);
    const videoHoldSpeed: boolean = mediaSettingsStore.loadVideoHoldSpeed(this.context);
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_VIDEO_HOLD_SPEED, videoHoldSpeed);
    AppStorage.setOrCreate<number>(STORAGE_KEY_VIDEO_FEED_LAYOUT, mediaSettingsStore.loadVideoFeedLayout(this.context));
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_VIDEO_FEED_TAP_PAUSE, mediaSettingsStore.loadVideoFeedTapPause(this.context));
    // Keep the retired original floating-control option disabled, including for
    // users whose saved preference still points to it.
    mediaSettingsStore.saveVideoControlStyle(this.context, VIDEO_CONTROL_STYLE_SPACED);
    AppStorage.setOrCreate<number>(STORAGE_KEY_VIDEO_CONTROL_STYLE, VIDEO_CONTROL_STYLE_SPACED);
    const videoBackgroundMode: number = mediaSettingsStore.loadVideoBackgroundMode(this.context);
    AppStorage.setOrCreate<number>(STORAGE_KEY_VIDEO_BACKGROUND_MODE, videoBackgroundMode);
    const captionOpacity: number = mediaSettingsStore.loadCaptionOpacity(this.context);
    AppStorage.setOrCreate<number>(STORAGE_KEY_CAPTION_OPACITY, captionOpacity);
    const notificationAlerts: boolean = notificationSettingsStore.loadAlertsEnabled(this.context);
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_NOTIFICATION_ALERTS, notificationAlerts);
    const systemNotifications: boolean = notificationSettingsStore.loadSystemNotificationsEnabled(this.context);
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_SYSTEM_NOTIFICATIONS, systemNotifications);
    const dndSilent: boolean = notificationSettingsStore.loadDndSilentEnabled(this.context);
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_NOTIFICATION_DND_SILENT, dndSilent);
    const defaultHomeFeed: number = timelineSettingsStore.loadDefaultHomeFeed(this.context);
    AppStorage.setOrCreate<number>(STORAGE_KEY_DEFAULT_HOME_FEED, defaultHomeFeed);
    const timelineColumns: number = timelineSettingsStore.loadTimelineColumns(this.context);
    AppStorage.setOrCreate<number>(STORAGE_KEY_TIMELINE_COLUMNS, timelineColumns);
    const bottomBarPages: number = bottomBarSettingsStore.load(this.context);
    AppStorage.setOrCreate<number>(STORAGE_KEY_BOTTOM_BAR_PAGES, bottomBarPages);
    const homeTabMaterialLevel: number = hdsTabsSettingsStore.loadHomeTabMaterialLevel(this.context);
    AppStorage.setOrCreate<number>(STORAGE_KEY_HOME_TAB_MATERIAL_LEVEL, homeTabMaterialLevel);
    const classicBottomBar: boolean = hdsTabsSettingsStore.loadClassicBottomBar(this.context);
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_CLASSIC_BOTTOM_BAR, classicBottomBar);
    const rootTabLabelsVisible: boolean = hdsTabsSettingsStore.loadRootTabLabelsVisible(this.context);
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_ROOT_TAB_LABELS_VISIBLE, rootTabLabelsVisible);
    const readAloudEntryEnabled: boolean = readAloudSettingsStore.loadEntryEnabled(this.context);
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_READ_ALOUD_ENTRY_ENABLED, readAloudEntryEnabled);
    const pressEffectEnabled: boolean = this.pressEffectSettingsStore.loadEnabled(this.context);
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_PRESS_EFFECT_ENABLED, pressEffectEnabled);
    // Tweet cards link their translation affordance to AppStorage. Restore it
    // before the first page is drawn instead of waiting for Settings to mount.
    const translationSettings: TranslationSettings = translationStore.load(this.context);
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_TRANSLATION_ENABLED, translationSettings.enabled);
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_TRANSLATION_REPLACE_ORIGINAL,
      translationSettings.replaceOriginal);
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_TRANSLATION_AUTO_ENABLED, translationSettings.autoTranslate);
    // Proxy settings must be available before any page creates an HTTP client.
    proxyStore.load(this.context);
    // Prime the VPN state during application entry. Each request checks again
    // because the user can change the system VPN while Harmony X stays open.
    proxyStore.refreshSystemVpnState();
    // Web surfaces (the in-app browser, Grok web mode, the private-message
    // thread) read the application level proxy instead of the per-request one.
    proxyStore.applyToWebStack();
    this.restoreGripHandPreference();
    try {
      this.context.getApplicationContext().setColorMode(this.appearanceStore.colorMode(appearance.mode));
    } catch (error) {
      hilog.warn(DOMAIN, TAG, '%{public}s', 'Unable to restore display color mode');
    }
    if (!this.restoreContinuation(want, launchParam)) {
      this.readOAuthCallback(want);
      this.readNotificationLaunch(want);
      this.readExternalLink(want);
      this.readExternalShare(want);
    }
  }

  onContinue(wantParam: Record<string, Object>): AbilityConstant.OnContinueResult {
    try {
      // Harmony X uses Navigation.  Its stack is not auto-restorable by the
      // framework, so the target rebuilds the focused screen from the small
      // application payload below.
      wantParam[SUPPORT_CONTINUE_PAGE_STACK_PARAMETER] = false;
      continuationStore.writeToWant(wantParam);
      return AbilityConstant.OnContinueResult.AGREE;
    } catch (error) {
      hilog.error(DOMAIN, TAG, '%{public}s', 'Unable to prepare continuation payload');
      return AbilityConstant.OnContinueResult.REJECT;
    }
  }

  private async restoreGripHandPreference(): Promise<void> {
    const manager: GripHandManager = GripHandManager.getInstance();
    await manager.load(this.context);
    AppStorage.setOrCreate<boolean>('harmonyx.grip_hand_enabled', manager.isGripHandEnabled());
  }

  private persistGrokWebSession(): void {
    webSessionStore.persist(this.context, GROK_WEB_SESSION_ORIGINS).then((): void => {
    }).catch((): void => {
    });
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    if (this.restoreContinuation(want, launchParam)) {
      return;
    }
    this.readOAuthCallback(want);
    this.readNotificationLaunch(want);
    this.readExternalLink(want);
    this.readExternalShare(want);
    if (this.callbackUri.length > 0 && this.windowStage !== null) {
      this.openOAuthCallback(this.callbackUri);
    }
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onDestroy');
    this.releaseWindowListeners();
    this.windowStage = null;
    if (this.appIconScheduleRefreshTimerId >= 0) {
      clearInterval(this.appIconScheduleRefreshTimerId);
      this.appIconScheduleRefreshTimerId = -1;
    }
    this.persistGrokWebSession();
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageCreate');
    this.releaseWindowListeners();
    this.windowStage = windowStage;
    // The read-aloud panel is rendered by SpeechKit, so it needs the stage
    // before any page can start playback.
    try {
      WindowManager.setWindowStage(windowStage);
    } catch (error) {
      hilog.warn(DOMAIN, TAG, '%{public}s', 'Unable to register the read-aloud window stage');
    }
    // Must run before the content loads so the first frame already uses the
    // saved in-app text scale instead of the system scale.
    this.appearanceStore.applyFontMode(this.context, this.appearanceSettings);
    this.configureFullScreen(windowStage).then(() => {
      if (this.windowStage === windowStage) { this.showInitialPage(windowStage); }
    });
  }

  onWindowStageRestore(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageRestore');
    this.releaseWindowListeners();
    this.windowStage = windowStage;
    try {
      WindowManager.setWindowStage(windowStage);
    } catch (error) {
      hilog.warn(DOMAIN, TAG, '%{public}s', 'Unable to register restored window stage');
    }
    this.appearanceStore.applyFontMode(this.context, this.appearanceSettings);
    this.configureFullScreen(windowStage).then((): void => {
      // The continuation state is already in AppStorage.  Index receives its
      // restore request after this content tree has mounted.
      if (this.windowStage === windowStage) { this.loadHomePage(windowStage); }
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

  private readNotificationLaunch(want: Want): void {
    const uri: string = want.uri === undefined ? '' : want.uri;
    if (!/^harmonyx:\/\/(notifications|messages)(\/|$)/.test(uri)) { return; }
    const accountId: string = typeof want.parameters?.accountId === 'string' ? want.parameters.accountId : '';
    if (accountId.length > 0) {
      if (!accountStore.setActive(this.context, accountId)) {
        promptAction.showToast({ message: this.context.resourceManager.getStringSync($r('app.string.notification_account_missing')) });
        return;
      }
      xPrivateClient.load(this.context);
    }
    if (uri.startsWith('harmonyx://notifications')) {
      AppStorage.setOrCreate<number>(OPEN_NOTIFICATIONS_KEY, Date.now());
    } else if (uri.startsWith('harmonyx://messages')) {
      AppStorage.setOrCreate<number>(OPEN_MESSAGES_KEY, Date.now());
    }
  }

  private readExternalShare(want: Want): void {
    const id: string = typeof want.parameters?.externalShareId === 'string' ? want.parameters.externalShareId : '';
    if (externalShareStore.validId(id)) { AppStorage.setOrCreate<string>(STORAGE_KEY_EXTERNAL_SHARE, id); }
  }

  // Another app asked the system to open an x.com link and the user picked
  // Harmony X from the chooser. The link is handed to the root page, which
  // resolves it into a post, a profile or the in-app web sheet.
  private readExternalLink(want: Want): void {
    const uri: string = want.uri === undefined ? '' : want.uri;
    if (uri.length === 0 || classifyXLink(uri) === null) {
      return;
    }
    hilog.info(DOMAIN, TAG, '%{public}s', 'External x.com link received');
    AppStorage.setOrCreate<string>(STORAGE_KEY_EXTERNAL_LINK, uri);
  }

  private restoreContinuation(want: Want, launchParam: AbilityConstant.LaunchParam): boolean {
    if (launchParam.launchReason !== AbilityConstant.LaunchReason.CONTINUATION) {
      return false;
    }
    if (!continuationStore.restoreFromWant(want.parameters)) {
      return false;
    }
    try {
      this.context.setMissionContinueState(AbilityConstant.ContinueState.ACTIVE, (): void => {
      });
      // This must remain synchronous: the platform invokes onWindowStageRestore
      // only after this call has prepared the migrated stage.
      this.context.restoreWindowStage(new LocalStorage());
      return true;
    } catch (error) {
      hilog.error(DOMAIN, TAG, '%{public}s', 'Unable to restore continuation stage');
      return false;
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
      if (this.windowStage !== windowStage) { return; }
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load content: %{public}s', JSON.stringify(err));
        return;
      }
      this.observeWindowAvoidAreas(windowStage);
      this.restoreApplicationLanguage();
      hilog.info(DOMAIN, TAG, '%{public}s', 'Content loaded successfully');
    });
  }

  // Migrate the existing preference to the platform's persistent app language.
  private restoreApplicationLanguage(): void {
    const language: string = this.languageStore.load(this.context);
    if (language === APP_LANGUAGE_SYSTEM) {
      publishAppLocale();
      return;
    }
    try {
      i18n.System.setAppPreferredLanguage(language);
      publishAppLocale();
    } catch (error) {
      hilog.warn(DOMAIN, TAG, '%{public}s', 'Unable to restore application language');
    }
  }

  onConfigurationUpdate(configuration: Configuration): void {
    if ((configuration.language ?? '').length > 0) { publishAppLocale(); }
  }

  private observeWindowAvoidAreas(windowStage: window.WindowStage): void {
    this.releaseWindowListeners();
    try {
      const mainWindow: window.Window = windowStage.getMainWindowSync();
      this.observedWindow = mainWindow;
      const uiContext: UIContext = mainWindow.getUIContext();
      const systemAvoidArea: window.AvoidArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const navigationAvoidArea: window.AvoidArea =
        mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      AppStorage.setOrCreate<number>(STATUS_BAR_HEIGHT_KEY, uiContext.px2vp(systemAvoidArea.topRect.height));
      AppStorage.setOrCreate<number>(NAVIGATION_INDICATOR_HEIGHT_KEY,
        uiContext.px2vp(navigationAvoidArea.bottomRect.height));
      const windowRect: window.Rect = mainWindow.getWindowProperties().windowRect;
      this.updateResponsiveState(uiContext, windowRect.width, windowRect.height);
      this.windowSizeListener = (windowSize: window.Size): void => {
        if (this.observedWindow !== mainWindow) { return; }
        this.updateResponsiveState(uiContext, windowSize.width, windowSize.height);
      };
      this.avoidAreaListener = (avoidAreaOption: window.AvoidAreaOptions): void => {
        if (this.observedWindow !== mainWindow) { return; }
        if (avoidAreaOption.type === window.AvoidAreaType.TYPE_SYSTEM) {
          AppStorage.setOrCreate<number>(STATUS_BAR_HEIGHT_KEY, uiContext.px2vp(avoidAreaOption.area.topRect.height));
        } else if (avoidAreaOption.type === window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR) {
          AppStorage.setOrCreate<number>(NAVIGATION_INDICATOR_HEIGHT_KEY,
            uiContext.px2vp(avoidAreaOption.area.bottomRect.height));
        }
      };
      mainWindow.on('windowSizeChange', this.windowSizeListener);
      mainWindow.on('avoidAreaChange', this.avoidAreaListener);
    } catch (error) {
      const businessError: BusinessError = error as BusinessError;
      hilog.error(DOMAIN, TAG, 'Failed to observe window avoid areas: %{public}d', businessError.code);
    }
  }

  private updateResponsiveState(uiContext: UIContext, windowWidthPx: number, windowHeightPx: number): void {
    const widthVp: number = uiContext.px2vp(windowWidthPx);
    const heightVp: number = uiContext.px2vp(windowHeightPx);
    const breakpoint: string = ResponsiveLayout.breakpointForWidth(widthVp);
    AppStorage.setOrCreate<number>(WINDOW_WIDTH_KEY, widthVp);
    AppStorage.setOrCreate<number>(WINDOW_HEIGHT_KEY, heightVp);
    AppStorage.setOrCreate<string>(ResponsiveLayout.HEIGHT_BREAKPOINT_KEY,
      ResponsiveLayout.heightBreakpoint(widthVp, heightVp));
    AppStorage.setOrCreate<boolean>(ResponsiveLayout.COMPACT_WINDOW_KEY,
      ResponsiveLayout.isCompactWindow(widthVp, heightVp));
    AppStorage.setOrCreate<string>(BREAKPOINT_KEY, breakpoint);
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageDestroy');
    this.releaseWindowListeners();
    this.windowStage = null;
  }

  private releaseWindowListeners(): void {
    const observed: window.Window | null = this.observedWindow;
    this.observedWindow = null;
    if (observed !== null) {
      try {
        if (this.windowSizeListener !== null) { observed.off('windowSizeChange', this.windowSizeListener); }
      } catch (error) { hilog.warn(DOMAIN, TAG, '%{public}s', 'Unable to release window size listener'); }
      try {
        if (this.avoidAreaListener !== null) { observed.off('avoidAreaChange', this.avoidAreaListener); }
      } catch (error) { hilog.warn(DOMAIN, TAG, '%{public}s', 'Unable to release avoid area listener'); }
    }
    this.windowSizeListener = null;
    this.avoidAreaListener = null;
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onForeground');
    downloadManager.onForeground(this.context);
    AppStorage.setOrCreate<boolean>('harmonyx.app_foreground', true);
    videoKeepAwake.setForeground(true, this.context);
    AppStorage.setOrCreate<number>('harmonyx.foreground_tick', Date.now());
    AppStorage.setOrCreate<number>(STORAGE_KEY_POST_TIME_NOW, Date.now());
    this.refreshScheduledAppIcon();
    if (this.appIconScheduleRefreshTimerId >= 0) {
      clearInterval(this.appIconScheduleRefreshTimerId);
    }
    this.appIconScheduleRefreshTimerId = setInterval((): void => {
      AppStorage.setOrCreate<number>(STORAGE_KEY_POST_TIME_NOW, Date.now());
      this.refreshScheduledAppIcon();
    }, 60 * 1000);
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onBackground');
    downloadManager.onBackground(this.context);
    if (this.appIconScheduleRefreshTimerId >= 0) {
      clearInterval(this.appIconScheduleRefreshTimerId);
      this.appIconScheduleRefreshTimerId = -1;
    }
    this.persistGrokWebSession();
    // The video player reads this when a picture-in-picture window closes: a
    // window dismissed while the app stays behind stops playback, one that is
    // tapped to return to the app does not.
    AppStorage.setOrCreate<boolean>('harmonyx.app_foreground', false);
    videoKeepAwake.setForeground(false, this.context);
    AppStorage.setOrCreate<number>('harmonyx.background_tick', Date.now());
    videoPipPlaybackKeeper.resumeAll();
    setTimeout((): void => {
      videoPipPlaybackKeeper.resumeAll();
    }, 160);
    setTimeout((): void => {
      videoPipPlaybackKeeper.resumeAll();
    }, 520);
  }

  private refreshScheduledAppIcon(): void {
    this.appIconScheduleStore.applyIfEnabled(this.context);
  }
}
