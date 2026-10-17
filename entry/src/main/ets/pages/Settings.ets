// Settings destinations use the same shared NavPathStack as post detail.
// Keeping sidebar callbacks here makes the drawer structure reusable, as in
// PaperTalk, while each settings group remains a real child page.
import { SettingsCategory, SettingsGroup, SETTINGS_GROUPS, settingsCategory, settingsChildren,
  settingsRoots, searchSettings, settingsBreadcrumb } from '../models/SettingsCatalog';
import { uiMaterial } from '@kit.ArkUI';
import { SystemMaterialUtil } from '../utils/SystemMaterial';
import { STORAGE_KEY_SIDEBAR_MATERIAL_TYPE, SIDEBAR_MATERIAL_GLASS, STORAGE_KEY_DESKTOP_RAIL_SWIPE } from '../services/LayoutSettingsStore';
import { STORAGE_KEY_HOME_SPACE_CAPSULE_ENABLED, STORAGE_KEY_HOME_SPACE_CAPSULE_HIDDEN_FOR_SESSION,
  spacePreferencesStore } from '../services/SpacePreferencesStore';
import { HOME_FLOATING_COMPOSE, HOME_FLOATING_REFRESH, HOME_FLOATING_TOP, HOME_FLOATING_HIDDEN,
  STORAGE_KEY_HOME_FLOATING_ACTION, STORAGE_KEY_PHOTO_FULLSCREEN, STORAGE_KEY_REFRESH_ON_FOREGROUND,
  STORAGE_KEY_REFRESH_ON_HOME_TAB, STORAGE_KEY_HOME_DOUBLE_TAP_LATEST, STORAGE_KEY_HOME_PULL_REFRESH_LATEST,
  interactionSettingsStore } from '../services/InteractionSettingsStore';
import { deviceInfo } from '@kit.BasicServicesKit';
import {
  DEFAULT_SHEET_MATERIAL_LEVEL,
  STORAGE_KEY_SHEET_MATERIAL_ENABLED,
  STORAGE_KEY_SHEET_MATERIAL_LEVEL,
  sheetMaterialSettingsStore
} from '../services/SheetMaterialSettingsStore';
import { common, Want } from '@kit.AbilityKit';
import { i18n } from '@kit.LocalizationKit';
import promptAction from '@ohos.promptAction';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY, APP_FONT_NAME_KEY, appFontStore, FontImportResult } from '../services/AppFontStore';
import { effectiveAppLocale, isAppRtl, publishAppLocale, STORAGE_KEY_APP_LOCALE } from '../utils/AppLocale';
import {
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  ScrollEffectType
} from '@kit.UIDesignKit';
import {
  AppearanceSettings,
  AppearanceStore,
  CONTENT_FONT_FAMILY_MONOSPACE,
  CONTENT_FONT_FAMILY_SERIF,
  CONTENT_FONT_FAMILY_SYSTEM,
  DARK_SURFACE_BLACK,
  DARK_SURFACE_GENTLE,
  DEFAULT_ACCENT_COLOR,
  DEFAULT_CONTENT_FONT_FAMILY,
  DEFAULT_FONT_SCALE,
  DISPLAY_MODE_DARK,
  DISPLAY_MODE_LIGHT,
  DISPLAY_MODE_SYSTEM,
  FONT_MODE_APP,
  FONT_MODE_SYSTEM,
  MAX_FONT_SCALE,
  MIN_FONT_SCALE,
  STORAGE_KEY_AUTO_HIDE_FAB,
  STORAGE_KEY_HOME_HEADER_COLLAPSE,
  STORAGE_KEY_TITLE_BAR_LOGO,
  STORAGE_KEY_COMPACT_SWITCH_STYLE,
  COMPACT_SWITCH_TABS,
  COMPACT_SWITCH_BUTTONS,
  STORAGE_KEY_AUTO_HIDE_TAB_BAR,
  STORAGE_KEY_AUTO_HIDE_TITLE_BAR,
  STORAGE_KEY_COMPOSE_BUTTON_ENABLED,
  STORAGE_KEY_AVATAR_TINT_ENABLED,
  STORAGE_KEY_CONTENT_FONT_FAMILY,
  STORAGE_KEY_SYSTEM_EMOJI_ENABLED,
  STORAGE_KEY_DARK_SURFACE,
  STORAGE_KEY_TITLE_BAR_STYLE_MODE,
  STORAGE_KEY_TITLE_BAR_GLASS_MATERIAL_LEVEL,
  STORAGE_KEY_REPLY_CAPSULE_MATERIAL_LEVEL,
  STORAGE_KEY_REPLY_CAPSULE_BUTTON_MATERIAL_ENABLED,
  DEFAULT_TITLE_BAR_GLASS_MATERIAL_LEVEL,
  DEFAULT_REPLY_CAPSULE_MATERIAL_LEVEL,
  DEFAULT_REPLY_CAPSULE_BUTTON_MATERIAL_ENABLED,
  TITLE_BAR_STYLE_BLUR,
  TITLE_BAR_STYLE_GLASS,
  TITLE_BAR_STYLE_GLASS_ONLY,
  TITLE_BAR_STYLE_IMMERSIVE,
  TITLE_BAR_GLASS_ULTRA_THIN,
  TITLE_BAR_GLASS_THIN,
  TITLE_BAR_GLASS_REGULAR,
  TITLE_BAR_GLASS_THICK,
  TITLE_BAR_GLASS_ULTRA_THICK
} from '../services/AppearanceStore';
import {
  BOTTOM_BAR_EXPLORE_PAGE,
  BOTTOM_BAR_HOME_PAGE,
  BOTTOM_BAR_ME_PAGE,
  BOTTOM_BAR_MESSAGES_PAGE,
  BOTTOM_BAR_NOTIFICATIONS_PAGE,
  bottomBarSettingsStore,
  DEFAULT_BOTTOM_BAR_PAGES_MASK,
  STORAGE_KEY_BOTTOM_BAR_PAGES
} from '../services/BottomBarSettingsStore';
import {
  cardSurfaceColor,
  fieldSurfaceColor,
  pageSurfaceColor,
  secondaryButtonSurfaceColor
} from '../utils/ThemeColors';
import {
  APP_LANGUAGE_EN,
  APP_LANGUAGE_IT,
  APP_LANGUAGE_SYSTEM,
  APP_LANGUAGE_ZH_CN,
  DEFAULT_APP_LANGUAGE,
  LanguageStore,
  AppLanguageOption,
  supportedAppLanguages
} from '../services/LanguageStore';
import { GripHandManager } from '../utils/GripHandManager';
import { destinationTitleBarStyle } from '../utils/DestinationTitleBar';
import { layoutSettingsStore, STORAGE_KEY_DESKTOP_LAYOUT, STORAGE_KEY_DESKTOP_ASIDE,
  STORAGE_KEY_DESKTOP_RAIL_AUTO_HIDE, STORAGE_KEY_DESKTOP_RAIL_MATERIAL_LEVEL,
  DEFAULT_DESKTOP_RAIL_MATERIAL_LEVEL } from '../services/LayoutSettingsStore';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';
import { STORAGE_KEY_DESKTOP_VIDEO_LAYOUT, DESKTOP_VIDEO_LAYOUT_SPLIT,
  DESKTOP_VIDEO_LAYOUT_FEED } from '../services/LayoutSettingsStore';
import { NavigationGuard } from '../utils/NavigationGuard';
import type { ListsRouteParam } from './Lists';
import {
  DEFAULT_SOURCE_LANGUAGE,
  DEFAULT_TARGET_LANGUAGE,
  findTranslationProvider,
  TARGET_LANGUAGE_APP,
  normalizeTranslationLanguage,
  SOURCE_LANGUAGE_AUTO,
  TRANSLATION_MODE_API,
  TRANSLATION_MODE_WEB,
  TRANSLATION_MODE_X,
  TRANSLATION_PROVIDERS
} from '../models/Translation';
import type { TranslationProvider } from '../models/Translation';
import { TranslationSettings, translationStore } from '../services/TranslationStore';
import {
  DEFAULT_GROK_BASE_URL,
  DEFAULT_GROK_MODEL,
  GROK_MODE_API,
  GROK_MODE_WEB,
  GrokSettings,
  grokSettingsStore
} from '../services/GrokSettingsStore';
import { USER_LIST_BLOCKED } from './UserList';
import type { UserListRouteParam } from './UserList';
import { linkSettingsStore } from '../services/LinkSettingsStore';
import { AccountPrivacyRouteParam } from '../models/AccountPrivacy';
import { accountPrivacyService } from '../services/AccountPrivacyService';
import { xPrivateClient } from '../services/XPrivateClient';
import {
  DEFAULT_CAPTION_OPACITY,
  IMAGE_QUALITY_DATA_SAVER,
  IMAGE_QUALITY_HIGH,
  IMAGE_QUALITY_ORIGINAL,
  mediaSettingsStore,
  STORAGE_KEY_CAPTION_OPACITY,
  STORAGE_KEY_HOME_VIDEO_MUTED,
  STORAGE_KEY_MEDIA_VIEWER_BLACK_BACKGROUND,
  STORAGE_KEY_MEDIA_COMMENT_BACKGROUND,
  STORAGE_KEY_VIDEO_COMMENT_PROGRESS_RING,
  STORAGE_KEY_SHOW_SENSITIVE_MEDIA,
  STORAGE_KEY_VIDEO_AUTO_PIP,
  STORAGE_KEY_VIDEO_BACKGROUND_MODE,
  STORAGE_KEY_VIDEO_HOLD_SPEED,
  STORAGE_KEY_VIDEO_FEED_TAP_PAUSE,
  STORAGE_KEY_VIDEO_IMMERSIVE_FILL,
  VIDEO_BACKGROUND_AUDIO,
  VIDEO_BACKGROUND_PIP,
  VIDEO_QUALITY_DATA_SAVER,
  VIDEO_QUALITY_HIGH,
  VIDEO_QUALITY_SD,
  VIDEO_QUALITY_LD
} from '../services/MediaSettingsStore';
import { notificationDeliveryService } from '../services/NotificationDeliveryService';
import {
  notificationSettingsStore,
  STORAGE_KEY_NOTIFICATION_DND_SILENT,
  STORAGE_KEY_SYSTEM_NOTIFICATIONS
} from '../services/NotificationSettingsStore';
import {
  HOME_FEED_FOLLOWING,
  HOME_FEED_FOR_YOU,
  STORAGE_KEY_TIMELINE_COLUMNS,
  TIMELINE_COLUMNS_AUTO,
  TIMELINE_COLUMNS_ONE,
  TIMELINE_COLUMNS_THREE,
  TIMELINE_COLUMNS_TWO,
  timelineSettingsStore
} from '../services/TimelineSettingsStore';
import {
  DEFAULT_HOME_TAB_MATERIAL_LEVEL,
  HDS_TAB_MATERIAL_ADAPTIVE,
  HDS_TAB_MATERIAL_EXQUISITE,
  HDS_TAB_MATERIAL_GENTLE,
  HDS_TAB_MATERIAL_SMOOTH,
  hdsTabsSettingsStore,
  STORAGE_KEY_CLASSIC_BOTTOM_BAR,
  STORAGE_KEY_HOME_TAB_MATERIAL_LEVEL,
  STORAGE_KEY_ROOT_TAB_LABELS_VISIBLE
} from '../services/HdsTabsSettingsStore';
import {
  readAloudSettingsStore,
  STORAGE_KEY_READ_ALOUD_ENTRY_ENABLED
} from '../services/ReadAloudSettingsStore';
import {
  ContentFilterSettings,
  contentFilterStore,
  STORAGE_KEY_FILTER_HIDE_ADS,
  STORAGE_KEY_FILTER_HIDE_REPLIES,
  STORAGE_KEY_FILTER_HIDE_REPOSTS,
  STORAGE_KEY_FILTER_KEYWORDS,
  STORAGE_KEY_FILTER_MUTED_USERS,
  STORAGE_KEY_FILTER_ONLY_MEDIA
} from '../services/ContentFilterStore';
import {
  AppIconApplyResult,
  AppIconOption,
  AppIconStore,
  APP_ICON_BLOSSOM,
  APP_ICON_BLUE_BIRD,
  APP_ICON_BRUSH,
  APP_ICON_CLASSIC,
  APP_ICON_DEFAULT,
  APP_ICON_ERROR_CLONE_UNSUPPORTED,
  APP_ICON_ERROR_THEME_CONFLICT,
  APP_ICON_ERROR_UNSUPPORTED,
  APP_ICON_FROG_WHITE,
  APP_ICON_FROG_BLACK,
  APP_ICON_MILK_FROG_WHITE,
  APP_ICON_MILK_FROG_BLACK,
  APP_ICON_MID_AUTUMN,
  APP_ICON_OUTLINE,
  APP_ICON_REQUIRED_API,
  APP_ICON_SPECTRUM,
  APP_ICON_TWITTER_BLUE,
  APP_ICON_TWITTER_WHITE,
  APP_ICON_X_BLACK,
  APP_ICON_X_WHITE,
  isKnownAppIcon,
  isMidAutumnIconAvailable
} from '../services/AppIconStore';
import {
  AppIconScheduleSettings,
  AppIconScheduleStore,
  DEFAULT_APP_ICON_SCHEDULE_END,
  DEFAULT_APP_ICON_SCHEDULE_START
} from '../services/AppIconScheduleStore';
import {
  PressEffectSettingsStore,
  STORAGE_KEY_PRESS_EFFECT_ENABLED
} from '../services/PressEffectSettingsStore';

export interface SettingsRouteParam {
  section: string;
}

@Builder
export function SettingsBuilder(): void {
  SettingsHome();
}

@Builder
export function SettingsSectionBuilder(): void {
  SettingsSection();
}

@Component
struct SettingsRow {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp(STORAGE_KEY_APP_LOCALE) private appLocale: string = effectiveAppLocale();
  @Prop icon: Resource = $r('sys.symbol.gearshape');
  @Prop title: Resource = $r('app.string.settings_title');
  @Prop detail: ResourceStr = $r('app.string.settings_display_desc');
  onRowClick: () => void = (): void => {};

  build(): void {
    Row({ space: 16 }) {
      SymbolGlyph(this.icon)
        .fontSize(25)
        .fontColor([$r('app.color.text_secondary')])
        .width(32)
      Column({ space: 4 }) {
        Text(this.title).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Subtitle_L'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Text(this.detail).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(15)
        .fontColor([$r('app.color.text_secondary')])
        .scale({ x: isAppRtl(this.appLocale) ? -1 : 1 })
    }
    .width('100%')
    .direction(Direction.Auto)
    .padding({ left: 20, right: 20, top: 16, bottom: 16 })
    .onClick((): void => this.onRowClick())
  }
}

@Component
export struct SettingsHome {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Prop embedded: boolean = false;
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp('harmonyx.status_bar_height') statusBarHeight: number =
    AppStorage.get<number>('harmonyx.status_bar_height') ?? 0;
  @StorageProp('harmonyx.navigation_indicator_height') navigationIndicatorHeight: number =
    AppStorage.get<number>('harmonyx.navigation_indicator_height') ?? 0;
  scroller: Scroller = new Scroller();
  @StorageLink('harmonyx.accent_color') accentColor: string = DEFAULT_ACCENT_COLOR;
  @StorageProp('harmonyx.display_mode') private themeDisplayMode: string = DISPLAY_MODE_SYSTEM;
  @StorageLink(STORAGE_KEY_TITLE_BAR_STYLE_MODE) titleBarStyleMode: number = TITLE_BAR_STYLE_IMMERSIVE;
  @StorageLink(STORAGE_KEY_TITLE_BAR_GLASS_MATERIAL_LEVEL)
  titleBarGlassMaterialLevel: number = DEFAULT_TITLE_BAR_GLASS_MATERIAL_LEVEL;
  @StorageProp(STORAGE_KEY_DARK_SURFACE) private themeDarkSurface: string = DARK_SURFACE_BLACK;
  @State searchQuery: string = '';

  private pageMaterial(): uiMaterial.Material | undefined {
    if (!deviceInfo.apiAvailable('26.0.0')) {
      return undefined;
    }
    return new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.REGULAR,
      applyShadow: true,
      colorInvert: true
    });
  }

  private inputMaterial(): uiMaterial.Material | undefined {
    if (!deviceInfo.apiAvailable('26.0.0')) {
      return undefined;
    }
    return new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.THIN,
      interactive: true,
      applyShadow: true,
      colorInvert: true,
      lightEffect: { color: this.accentColor }
    });
  }

  private openCategory(category: SettingsCategory): void {
    if (this.embedded) { this.pageStack.clear(false); }
    if (category.destination === 'AccountPrivacy') {
      AppStorage.setOrCreate<string>('harmonyx.desktop_settings_section', category.id);
      const param: AccountPrivacyRouteParam = { section: category.id };
      NavigationGuard.pushPath<AccountPrivacyRouteParam>(this.pageStack, { name: category.destination, param: param },
        (route: AccountPrivacyRouteParam): string => route.section);
    } else if (category.destination === 'UserList') {
      const param: UserListRouteParam = { mode: USER_LIST_BLOCKED, userId: '' };
      this.pageStack.pushPath({ name: category.destination, param: param });
    } else if (category.destination === 'Lists') {
      const param: ListsRouteParam = { userId: '', memberships: false, title: '' };
      this.pageStack.pushPath({ name: category.destination, param: param });
    } else if (category.destination.length > 0) {
      this.pageStack.pushPath({ name: category.destination });
    } else {
      AppStorage.setOrCreate<string>('harmonyx.desktop_settings_section', category.id);
      const param: SettingsRouteParam = { section: category.id };
      NavigationGuard.pushPath<SettingsRouteParam>(this.pageStack, { name: 'SettingsSection', param: param },
        (route: SettingsRouteParam): string => route.section);
    }
  }

  private text(resource: Resource): string {
    return (getContext(this) as common.UIAbilityContext).resourceManager.getStringSync(resource);
  }

  private roots(group: string): SettingsCategory[] {
    return settingsRoots(group);
  }

  private results(): SettingsCategory[] {
    return searchSettings(this.searchQuery, (resource: Resource): string => this.text(resource));
  }

  private searchDetail(category: SettingsCategory): string {
    return settingsBreadcrumb(category, (resource: Resource): string => this.text(resource));
  }

  @Builder
  private CategoryRow(category: SettingsCategory, searching: boolean = false): void {
    SettingsRow({ icon: category.icon, title: category.title,
      detail: searching ? this.searchDetail(category) : category.detail,
      onRowClick: (): void => this.openCategory(category) })
  }

  @Builder
  private ListContent(): void {
    Scroll(this.scroller) {
      Column({ space: 12 }) {
        Search({ value: this.searchQuery, placeholder: $r('app.string.settings_search') })
          .keyboardAppearance(KeyboardAppearance.IMMERSIVE)
          .width('100%').height(44)
          .margin({ top: this.embedded ? 12 : this.statusBarHeight + 76, bottom: 4 })
          .backgroundColor(fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
          .systemMaterial(this.inputMaterial())
          .onChange((value: string): void => { this.searchQuery = value; })
        if (this.searchQuery.trim().length === 0) {
          ForEach(SETTINGS_GROUPS, (group: SettingsGroup) => {
            Column({ space: 8 }) {
              Text(group.title).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
                .fontWeight(FontWeight.Medium).fontColor($r('app.color.text_secondary'))
                .width('100%').padding({ left: 12, top: 8 })
              Column() {
                ForEach(this.roots(group.id), (category: SettingsCategory) => {
                  this.CategoryRow(category)
                }, (category: SettingsCategory): string => category.id)
              }.width('100%').borderRadius(20)
                .backgroundColor(cardSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
            }.width('100%')
          }, (group: SettingsGroup): string => group.id)
        } else {
          Column() {
            ForEach(this.results(), (category: SettingsCategory) => {
              this.CategoryRow(category, true)
            }, (category: SettingsCategory): string => category.id)
          }.width('100%').borderRadius(20)
            .backgroundColor(cardSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
          if (this.results().length === 0) {
            Text($r('app.string.settings_search_no_results')).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_secondary'))
              .textAlign(TextAlign.Center).width('100%').padding({ top: 48, bottom: 48 })
          }
        }
      }.width('100%').padding({ left: $r('app.float.settings_page_horizontal_padding'),
        right: $r('app.float.settings_page_horizontal_padding'), bottom: this.navigationIndicatorHeight + 28 })
    }.width('100%').height('100%').align(Alignment.TopStart).scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .clipContent(ContentClipMode.SAFE_AREA).clip(false)
  }

  build(): void {
    if (this.embedded) {
      this.ListContent()
    } else {
    HdsNavDestination() {
      this.ListContent()
    }
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .hideBackButton(false)
    .onBackPressed((): boolean => {
      ResponsiveLayout.closeContentDestination(this.pageStack);
      return true;
    })
    .bindToScrollable([this.scroller])
    .titleBar({
      avoidLayoutSafeArea: true,
      content: { title: { mainTitle: $r('app.string.settings_title') } },
      style: destinationTitleBarStyle(ScrollEffectType.GRADIENT_BLUR, this.themeDisplayMode,
        this.themeDarkSurface, this.titleBarStyleMode)
    })
    .backgroundColor(pageSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
    .systemMaterial(this.pageMaterial());
  }
  }
}

@Component
export struct SettingsSection {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp(STORAGE_KEY_APP_LOCALE) private appLocale: string = effectiveAppLocale();
  @StorageProp('harmonyx.breakpoint') private breakpoint: string = 'sm';
  @StorageLink(STORAGE_KEY_DESKTOP_LAYOUT) desktopLayoutEnabled: boolean = false;
  @StorageProp(STORAGE_KEY_DESKTOP_VIDEO_LAYOUT) desktopVideoLayout: number = DESKTOP_VIDEO_LAYOUT_SPLIT;
  @StorageProp(STORAGE_KEY_DESKTOP_ASIDE) desktopAsideEnabled: boolean = true;
  @StorageProp(STORAGE_KEY_DESKTOP_RAIL_AUTO_HIDE) desktopRailAutoHide: boolean = true;
  @StorageProp(STORAGE_KEY_DESKTOP_RAIL_SWIPE) desktopRailSwipe: boolean = true;
  @StorageProp(STORAGE_KEY_SIDEBAR_MATERIAL_TYPE) sidebarMaterialType: number = SIDEBAR_MATERIAL_GLASS;
  @StorageProp(STORAGE_KEY_DESKTOP_RAIL_MATERIAL_LEVEL)
  desktopRailMaterialLevel: number = DEFAULT_DESKTOP_RAIL_MATERIAL_LEVEL;
  @StorageLink(STORAGE_KEY_SHEET_MATERIAL_ENABLED) private sheetMaterialEnabled: boolean = false;
  @StorageLink(STORAGE_KEY_SHEET_MATERIAL_LEVEL) private sheetMaterialLevel: number = DEFAULT_SHEET_MATERIAL_LEVEL;
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp('harmonyx.status_bar_height') statusBarHeight: number =
    AppStorage.get<number>('harmonyx.status_bar_height') ?? 0;
  @StorageProp('harmonyx.navigation_indicator_height') navigationIndicatorHeight: number =
    AppStorage.get<number>('harmonyx.navigation_indicator_height') ?? 0;
  @State section: string = 'accessibility';
  @StorageLink('harmonyx.display_mode') displayMode: string = DISPLAY_MODE_SYSTEM;
  @StorageLink('harmonyx.accent_color') accentColor: string = DEFAULT_ACCENT_COLOR;
  @StorageLink('harmonyx.font_mode') fontMode: string = FONT_MODE_SYSTEM;
  @StorageLink('harmonyx.font_scale') fontScale: number = DEFAULT_FONT_SCALE;
  @StorageLink(STORAGE_KEY_CONTENT_FONT_FAMILY) contentFontFamily: string = DEFAULT_CONTENT_FONT_FAMILY;
  @StorageProp(APP_FONT_NAME_KEY) private appFontName: string = '';
  @State private appFontBusy: boolean = false;
  @StorageLink(STORAGE_KEY_SYSTEM_EMOJI_ENABLED) systemEmojiEnabled: boolean = false;
  @StorageLink(STORAGE_KEY_AUTO_HIDE_TITLE_BAR) autoHideTitleBar: boolean = false;
  @StorageLink(STORAGE_KEY_AUTO_HIDE_TAB_BAR) autoHideTabBar: boolean = false;
  @StorageLink(STORAGE_KEY_BOTTOM_BAR_PAGES) bottomBarPagesMask: number = DEFAULT_BOTTOM_BAR_PAGES_MASK;
  @StorageLink(STORAGE_KEY_CLASSIC_BOTTOM_BAR) classicBottomBar: boolean = false;
  @StorageLink(STORAGE_KEY_ROOT_TAB_LABELS_VISIBLE) rootTabLabelsVisible: boolean = true;
  @StorageLink(STORAGE_KEY_AUTO_HIDE_FAB) autoHideFab: boolean = true;
  @StorageLink(STORAGE_KEY_HOME_HEADER_COLLAPSE) homeHeaderCollapseEnabled: boolean = false;
  @StorageLink(STORAGE_KEY_TITLE_BAR_LOGO) titleBarLogoEnabled: boolean = true;
  @StorageLink(STORAGE_KEY_COMPACT_SWITCH_STYLE) compactSwitchStyle: string = COMPACT_SWITCH_TABS;
  @StorageLink(STORAGE_KEY_TITLE_BAR_STYLE_MODE) titleBarStyleMode: number = TITLE_BAR_STYLE_IMMERSIVE;
  @StorageLink(STORAGE_KEY_TITLE_BAR_GLASS_MATERIAL_LEVEL)
  titleBarGlassMaterialLevel: number = DEFAULT_TITLE_BAR_GLASS_MATERIAL_LEVEL;
  @StorageLink(STORAGE_KEY_REPLY_CAPSULE_MATERIAL_LEVEL)
  replyCapsuleMaterialLevel: number = DEFAULT_REPLY_CAPSULE_MATERIAL_LEVEL;
  @StorageLink(STORAGE_KEY_REPLY_CAPSULE_BUTTON_MATERIAL_ENABLED)
  replyCapsuleButtonMaterialEnabled: boolean = DEFAULT_REPLY_CAPSULE_BUTTON_MATERIAL_ENABLED;
  @StorageLink(STORAGE_KEY_COMPOSE_BUTTON_ENABLED) composeButtonEnabled: boolean = true;
  @StorageProp(STORAGE_KEY_HOME_FLOATING_ACTION) homeFloatingAction: string = HOME_FLOATING_COMPOSE;
  @StorageProp(STORAGE_KEY_PHOTO_FULLSCREEN) photoFullscreen: boolean = true;
  @StorageProp(STORAGE_KEY_REFRESH_ON_FOREGROUND) refreshOnForeground: boolean = false;
  @StorageProp(STORAGE_KEY_REFRESH_ON_HOME_TAB) refreshOnHomeTab: boolean = false;
  @StorageProp(STORAGE_KEY_HOME_DOUBLE_TAP_LATEST) homeDoubleTapLatest: boolean = true;
  @StorageProp(STORAGE_KEY_HOME_PULL_REFRESH_LATEST) homePullRefreshLatest: boolean = true;
  @StorageProp(STORAGE_KEY_HOME_SPACE_CAPSULE_ENABLED) homeSpaceCapsuleEnabled: boolean = true;
  @StorageProp(STORAGE_KEY_HOME_SPACE_CAPSULE_HIDDEN_FOR_SESSION) homeSpaceCapsuleHiddenForSession: boolean = false;
  @StorageLink(STORAGE_KEY_AVATAR_TINT_ENABLED) avatarTintEnabled: boolean = false;
  @StorageLink(STORAGE_KEY_DARK_SURFACE) darkSurface: string = DARK_SURFACE_BLACK;
  @StorageLink(STORAGE_KEY_PRESS_EFFECT_ENABLED) pressEffectEnabled: boolean = false;
  @StorageLink('harmonyx.grip_hand_enabled') gripHandEnabled: boolean = true;
  @StorageLink('harmonyx.grip_preferred_hand') gripPreferredHand: string = 'right';
  @StorageLink('harmonyx.link_in_app') linkInApp: boolean = false;
  @StorageLink('harmonyx.video_autoplay') videoAutoplay: boolean = true;
  @StorageLink(STORAGE_KEY_SHOW_SENSITIVE_MEDIA) showSensitiveMedia: boolean = false;
  @State private sensitiveMediaSaving: boolean = false;
  @StorageLink(STORAGE_KEY_HOME_VIDEO_MUTED) homeVideoMuted: boolean = true;
  @StorageProp(STORAGE_KEY_MEDIA_VIEWER_BLACK_BACKGROUND) mediaViewerBlackBackground: boolean = false;
  @StorageProp(STORAGE_KEY_MEDIA_COMMENT_BACKGROUND) mediaCommentBackground: boolean = true;
  @StorageProp(STORAGE_KEY_VIDEO_COMMENT_PROGRESS_RING) videoCommentProgressRing: boolean = true;
  @StorageLink(STORAGE_KEY_VIDEO_AUTO_PIP) videoAutoPip: boolean = true;
  @StorageLink(STORAGE_KEY_VIDEO_IMMERSIVE_FILL) videoImmersiveFill: boolean = false;
  @StorageLink(STORAGE_KEY_VIDEO_HOLD_SPEED) videoHoldSpeed: boolean = true;
  @StorageLink(STORAGE_KEY_VIDEO_FEED_TAP_PAUSE) private videoFeedTapPause: boolean = false;
  @StorageLink(STORAGE_KEY_VIDEO_BACKGROUND_MODE) videoBackgroundMode: number = VIDEO_BACKGROUND_AUDIO;
  @StorageLink(STORAGE_KEY_CAPTION_OPACITY) captionOpacity: number = DEFAULT_CAPTION_OPACITY;
  @StorageLink('harmonyx.image_quality') imageQuality: number = IMAGE_QUALITY_ORIGINAL;
  @StorageLink('harmonyx.video_quality') videoQuality: number = VIDEO_QUALITY_DATA_SAVER;
  @StorageLink('harmonyx.app_language') appLanguage: string = DEFAULT_APP_LANGUAGE;
  @StorageLink('harmonyx.notification_alerts') notificationAlertsEnabled: boolean = true;
  @StorageLink(STORAGE_KEY_SYSTEM_NOTIFICATIONS) systemNotificationsEnabled: boolean = true;
  @StorageLink(STORAGE_KEY_NOTIFICATION_DND_SILENT) notificationDndSilent: boolean = true;
  @StorageLink('harmonyx.default_home_feed') defaultHomeFeedMode: number = HOME_FEED_FOR_YOU;
  @StorageLink(STORAGE_KEY_TIMELINE_COLUMNS) timelineColumnsMode: number = TIMELINE_COLUMNS_AUTO;
  @StorageLink(STORAGE_KEY_HOME_TAB_MATERIAL_LEVEL) homeTabMaterialLevel: number = DEFAULT_HOME_TAB_MATERIAL_LEVEL;
  @StorageLink(STORAGE_KEY_READ_ALOUD_ENTRY_ENABLED) readAloudEntryEnabled: boolean = false;
  @StorageLink(STORAGE_KEY_FILTER_ONLY_MEDIA) filterOnlyMedia: boolean = false;
  @StorageLink(STORAGE_KEY_FILTER_HIDE_REPOSTS) filterHideReposts: boolean = false;
  @StorageLink(STORAGE_KEY_FILTER_HIDE_REPLIES) filterHideReplies: boolean = false;
  @StorageLink(STORAGE_KEY_FILTER_HIDE_ADS) filterHideAds: boolean = true;
  @StorageLink(STORAGE_KEY_FILTER_KEYWORDS) filterKeywords: string = '';
  @StorageLink(STORAGE_KEY_FILTER_MUTED_USERS) filterMutedUsers: string = '';
  @State translationEnabled: boolean = false;
  @State translationReplaceOriginal: boolean = false;
  @State translationAutoEnabled: boolean = false;
  @State translationSource: string = DEFAULT_SOURCE_LANGUAGE;
  @State translationAutoExcludedLanguages: string = '';
  @State translationMode: string = TRANSLATION_MODE_API;
  @State translationProviderId: string = TRANSLATION_PROVIDERS[0].id;
  @State translationModel: string = '';
  @State translationApiKey: string = '';
  @State translationTarget: string = DEFAULT_TARGET_LANGUAGE;
  @State translationBaseUrl: string = '';
  @State grokMode: string = GROK_MODE_WEB;
  @State grokApiKey: string = '';
  @State grokModel: string = DEFAULT_GROK_MODEL;
  @State grokBaseUrl: string = DEFAULT_GROK_BASE_URL;
  @State grokUseXWebSession: boolean = true;
  // Set once the process has called setFontSizeScale, which cannot be undone
  // while the app keeps running.
  @State private appFontScaleApplied: boolean = false;
  @State private fontRestartPending: boolean = false;
  private systemFontScale: number = DEFAULT_FONT_SCALE;
  private translationProviderList: TranslationProvider[] = TRANSLATION_PROVIDERS;
  private translationLanguageList: AppLanguageOption[] = supportedAppLanguages();
  private scroller: Scroller = new Scroller();
  private appearanceStore: AppearanceStore = new AppearanceStore();
  private languageStore: LanguageStore = new LanguageStore();
  private pressEffectSettingsStore: PressEffectSettingsStore = new PressEffectSettingsStore();
  private gripHandManager: GripHandManager = GripHandManager.getInstance();
  // 备用图标名称与 app.json5 的 alternateIcons 一一对应，
  // 系统据此切换桌面图标。
  @State private currentAppIcon: string = APP_ICON_DEFAULT;
  @State private appIconBusy: boolean = false;
  @State private appIconScheduleEnabled: boolean = false;
  @State private appIconScheduleStartMinute: number = DEFAULT_APP_ICON_SCHEDULE_START;
  @State private appIconScheduleEndMinute: number = DEFAULT_APP_ICON_SCHEDULE_END;
  @State private appIconScheduleTarget: string = APP_ICON_CLASSIC;
  @State private appIconScheduleFallback: string = APP_ICON_DEFAULT;
  private appIconSupported: boolean = false;
  private appIconStore: AppIconStore = new AppIconStore();
  private appIconScheduleStore: AppIconScheduleStore = new AppIconScheduleStore();
  private appIconScheduleIconNames: string[] = [
    APP_ICON_DEFAULT,
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
    APP_ICON_MILK_FROG_BLACK
  ];
  private appIconOptions: AppIconOption[] = [
    new AppIconOption(APP_ICON_CLASSIC, $r('app.string.settings_app_icon_classic'),
      $r('app.media.alt_icon_classic')),
    new AppIconOption(APP_ICON_SPECTRUM, $r('app.string.settings_app_icon_spectrum'),
      $r('app.media.alt_icon_spectrum')),
    new AppIconOption(APP_ICON_OUTLINE, $r('app.string.settings_app_icon_outline'),
      $r('app.media.alt_icon_outline')),
    new AppIconOption(APP_ICON_BRUSH, $r('app.string.settings_app_icon_brush'),
      $r('app.media.alt_icon_brush')),
    new AppIconOption(APP_ICON_BLOSSOM, $r('app.string.settings_app_icon_blossom'),
      $r('app.media.alt_icon_blossom')),
    new AppIconOption(APP_ICON_BLUE_BIRD, $r('app.string.settings_app_icon_blue_bird'),
      $r('app.media.alt_icon_blue_bird')),
    new AppIconOption(APP_ICON_TWITTER_BLUE, $r('app.string.settings_app_icon_twitter_blue'),
      $r('app.media.alt_icon_twitter_blue')),
    new AppIconOption(APP_ICON_TWITTER_WHITE, $r('app.string.settings_app_icon_twitter_white'),
      $r('app.media.alt_icon_twitter_white')),
    new AppIconOption(APP_ICON_X_BLACK, $r('app.string.settings_app_icon_x_black'),
      $r('app.media.alt_icon_x_black')),
    new AppIconOption(APP_ICON_X_WHITE, $r('app.string.settings_app_icon_x_white'),
      $r('app.media.alt_icon_x_white')),
    new AppIconOption(APP_ICON_FROG_WHITE, $r('app.string.settings_app_icon_frog_white'),
      $r('app.media.alt_icon_frog_white_preview')),
    new AppIconOption(APP_ICON_FROG_BLACK, $r('app.string.settings_app_icon_frog_black'),
      $r('app.media.alt_icon_frog_black_preview')),
    new AppIconOption(APP_ICON_MILK_FROG_WHITE, $r('app.string.settings_app_icon_milk_frog_white'),
      $r('app.media.alt_icon_milk_frog_white_preview')),
    new AppIconOption(APP_ICON_MILK_FROG_BLACK, $r('app.string.settings_app_icon_milk_frog_black'),
      $r('app.media.alt_icon_milk_frog_black_preview'))
  ];

  private pageMaterial(): uiMaterial.Material | undefined {
    if (!deviceInfo.apiAvailable('26.0.0')) {
      return undefined;
    }
    return new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.REGULAR,
      applyShadow: true,
      colorInvert: true
    });
  }

  aboutToAppear(): void {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    this.systemFontScale = this.appearanceStore.systemFontScale(context);
    // EntryAbility applies the in-app scale before the first frame, so a saved
    // app mode means this process already stopped following the system size.
    this.appFontScaleApplied = this.fontMode === FONT_MODE_APP;
    this.loadGripHandPreference();
    this.loadLanguagePreference();
    this.loadTranslationConfiguration();
    this.loadGrokConfiguration();
    this.loadContentFilters();
    this.appIconSupported = this.appIconStore.supported();
    if (this.appIconSupported) {
      this.loadCurrentAppIcon();
    }

  }

  private loadLanguagePreference(): void {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    this.appLanguage = this.languageStore.load(context);
  }

  // The translation panel is stored separately from the X developer config so
  // rotating a vendor key never signs the user out of X.
  private loadTranslationConfiguration(): void {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const settings: TranslationSettings = translationStore.load(context);
    this.translationEnabled = settings.enabled;
    this.translationReplaceOriginal = settings.replaceOriginal;
    this.translationAutoEnabled = settings.autoTranslate;
    this.translationSource = settings.sourceLanguage;
    this.translationAutoExcludedLanguages = settings.autoTranslateExcludedLanguages;
    this.translationMode = settings.mode;
    this.translationProviderId = settings.providerId;
    this.translationModel = settings.model;
    this.translationApiKey = settings.apiKey;
    this.translationTarget = settings.targetLanguage;
    this.translationBaseUrl = settings.baseUrlOverride;
    translationStore.publish(settings);
  }

  private loadGrokConfiguration(): void {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const settings: GrokSettings = grokSettingsStore.load(context);
    this.grokMode = settings.mode;
    this.grokApiKey = settings.apiKey;
    this.grokModel = settings.effectiveModel();
    this.grokBaseUrl = settings.effectiveBaseUrl();
    this.grokUseXWebSession = settings.useXWebSession;
  }

  private selectGrokMode(mode: string): void {
    this.grokMode = mode === GROK_MODE_API ? GROK_MODE_API : GROK_MODE_WEB;
  }

  private saveGrokConfiguration(): void {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const settings: GrokSettings = new GrokSettings(this.grokMode, this.grokApiKey, this.grokModel,
      this.grokBaseUrl, this.grokUseXWebSession);
    const saved: boolean = grokSettingsStore.save(context, settings);
    promptAction.showToast({
      message: saved ? this.text($r('app.string.settings_grok_saved')) :
        this.text($r('app.string.settings_grok_mode_save_failed')),
      duration: 2200
    });
  }

  private saveTranslationConfiguration(): void {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const settings: TranslationSettings = new TranslationSettings(this.translationEnabled,
      this.translationReplaceOriginal, this.translationAutoEnabled, this.translationSource,
      this.translationAutoExcludedLanguages, this.translationMode, this.translationProviderId,
      this.translationModel, this.translationApiKey,
      this.translationTarget, this.translationBaseUrl);
    const saved: boolean = translationStore.save(context, settings);
    promptAction.showToast({
      message: saved ? this.text($r('app.string.settings_translation_saved')) :
        this.text($r('app.string.settings_translation_save_failed')),
      duration: 2200
    });
  }

  // Preset model list for the currently selected vendor, shown as a hint under
  // the free-text model field.
  private translationModelHint(): string {
    const provider: TranslationProvider | undefined = findTranslationProvider(this.translationProviderId);
    if (provider === undefined || provider.models.length === 0) {
      return '';
    }
    let out: string = '';
    for (let i: number = 0; i < provider.models.length; i++) {
      out += i === 0 ? provider.models[i] : ', ' + provider.models[i];
    }
    return out;
  }

  private translationBaseUrlHint(): string {
    const provider: TranslationProvider | undefined = findTranslationProvider(this.translationProviderId);
    if (provider === undefined || provider.baseUrl.length === 0) {
      return this.text($r('app.string.settings_translation_base_url_placeholder'));
    }
    return provider.baseUrl;
  }

  private text(resource: Resource): string {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    return context.resourceManager.getStringSync(resource);
  }

  private async loadGripHandPreference(): Promise<void> {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    await this.gripHandManager.load(context);
    this.gripPreferredHand = this.gripHandManager.getPreferredHand();
    this.gripHandEnabled = this.gripHandManager.isGripHandEnabled();
  }

  private setGripHandEnabled(value: boolean): void {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    this.gripHandManager.saveGripHandEnabled(context, value);
    this.gripHandEnabled = value;
  }

  private setGripPreferredHand(index: number): void {
    const hand: string = index === 1 ? 'left' : 'right';
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    this.gripHandManager.savePreferredHand(context, hand);
    this.gripPreferredHand = hand;
  }

  private setLinkInApp(value: boolean): void {
    this.linkInApp = value;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    linkSettingsStore.save(context, value);
  }

  private setVideoAutoplay(value: boolean): void {
    const previous: boolean = this.videoAutoplay;
    this.videoAutoplay = value;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    if (!mediaSettingsStore.saveVideoAutoplay(context, value)) {
      this.videoAutoplay = previous;
    }
  }

  private async setShowSensitiveMedia(value: boolean): Promise<void> {
    if (this.sensitiveMediaSaving) { return; }
    const previous: boolean = this.showSensitiveMedia;
    this.showSensitiveMedia = value;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    xPrivateClient.load(context);
    const generation: number = xPrivateClient.sessionGeneration();
    this.sensitiveMediaSaving = true;
    try {
      const confirmed = await accountPrivacyService.saveBoolean('content', 'display_sensitive_media', value, generation);
      if (generation !== xPrivateClient.sessionGeneration()) { return; }
      mediaSettingsStore.saveShowSensitiveMedia(context, confirmed.account?.display_sensitive_media === true);
      promptAction.showToast({ message: this.text($r('app.string.xsettings_saved')), duration: 1800 });
    } catch (error) {
      if (generation === xPrivateClient.sessionGeneration()) { this.showSensitiveMedia = previous; }
      promptAction.showToast({ message: this.text(xPrivateClient.isSignedIn() ?
        $r('app.string.xsettings_failed') : $r('app.string.xsettings_sign_in')), duration: 2000 });
    } finally {
      this.sensitiveMediaSaving = false;
    }
  }

  private setHomeVideoMuted(value: boolean): void {
    const previous: boolean = this.homeVideoMuted;
    this.homeVideoMuted = value;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    if (!mediaSettingsStore.saveHomeVideoMuted(context, value)) {
      this.homeVideoMuted = previous;
    }
  }

  private setMediaViewerBlackBackground(value: boolean): void {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    this.interactionSaved(mediaSettingsStore.saveMediaViewerBlackBackground(context, value));
  }

  private setVideoCommentProgressRing(value: boolean): void {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    this.interactionSaved(mediaSettingsStore.saveVideoCommentProgressRing(context, value));
  }

  private setMediaCommentBackground(value: boolean): void {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    this.interactionSaved(mediaSettingsStore.saveMediaCommentBackground(context, value));
  }

  private setVideoAutoPip(value: boolean): void {
    const previous: boolean = this.videoAutoPip;
    this.videoAutoPip = value;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    if (!mediaSettingsStore.saveVideoAutoPip(context, value)) {
      this.videoAutoPip = previous;
    }
  }

  private setVideoImmersiveFill(value: boolean): void {
    const previous: boolean = this.videoImmersiveFill;
    this.videoImmersiveFill = value;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    if (!mediaSettingsStore.saveVideoImmersiveFill(context, value)) {
      this.videoImmersiveFill = previous;
    }
  }

  private setVideoBackgroundMode(mode: number): void {
    if (this.videoBackgroundMode === mode) {
      return;
    }
    const previous: number = this.videoBackgroundMode;
    this.videoBackgroundMode = mode;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    if (!mediaSettingsStore.saveVideoBackgroundMode(context, mode)) {
      this.videoBackgroundMode = previous;
    }
  }

  private setVideoHoldSpeed(value: boolean): void {
    const previous: boolean = this.videoHoldSpeed;
    this.videoHoldSpeed = value;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    if (!mediaSettingsStore.saveVideoHoldSpeed(context, value)) {
      this.videoHoldSpeed = previous;
    }
  }

  private setVideoFeedTapPause(value: boolean): void {
    const previous: boolean = this.videoFeedTapPause;
    this.videoFeedTapPause = value;
    if (!mediaSettingsStore.saveVideoFeedTapPause(getContext(this) as common.UIAbilityContext, value)) {
      this.videoFeedTapPause = previous;
    }
  }

  private setCaptionOpacity(value: number): void {
    const previous: number = this.captionOpacity;
    this.captionOpacity = value;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    if (!mediaSettingsStore.saveCaptionOpacity(context, value)) {
      this.captionOpacity = previous;
    }
  }

  private setImageQuality(value: number): void {
    const previous: number = this.imageQuality;
    this.imageQuality = value;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    if (!mediaSettingsStore.saveImageQuality(context, value)) {
      this.imageQuality = previous;
    }
  }

  private setVideoQuality(value: number): void {
    const previous: number = this.videoQuality;
    this.videoQuality = value;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    if (!mediaSettingsStore.saveVideoQuality(context, value)) {
      this.videoQuality = previous;
    }
  }

  private setNotificationAlertsEnabled(value: boolean): void {
    const previous: boolean = this.notificationAlertsEnabled;
    this.notificationAlertsEnabled = value;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    if (!notificationSettingsStore.saveAlertsEnabled(context, value)) {
      this.notificationAlertsEnabled = previous;
    }
  }

  private setSystemNotificationsEnabled(value: boolean): void {
    const previous: boolean = this.systemNotificationsEnabled;
    this.systemNotificationsEnabled = value;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    if (!notificationSettingsStore.saveSystemNotificationsEnabled(context, value)) {
      this.systemNotificationsEnabled = previous;
      return;
    }
    if (value) {
      notificationDeliveryService.ensureAuthorized(context).then((enabled: boolean): void => {
        if (!enabled) {
          promptAction.showToast({
            message: this.text($r('app.string.settings_notification_permission_needed')),
            duration: 2200
          });
        }
      });
    }
  }

  private setNotificationDndSilent(value: boolean): void {
    const previous: boolean = this.notificationDndSilent;
    this.notificationDndSilent = value;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    if (!notificationSettingsStore.saveDndSilentEnabled(context, value)) {
      this.notificationDndSilent = previous;
    }
  }

  private openNotificationSystemSettings(): void {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    notificationDeliveryService.openSystemSettings(context).then((opened: boolean): void => {
      if (!opened) {
        promptAction.showToast({
          message: this.text($r('app.string.settings_notification_settings_failed')),
          duration: 1800
        });
      }
    });
  }

  private setDefaultHomeFeed(mode: number): void {
    const previous: number = this.defaultHomeFeedMode;
    this.defaultHomeFeedMode = mode;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    if (!timelineSettingsStore.saveDefaultHomeFeed(context, mode)) {
      this.defaultHomeFeedMode = previous;
    }
  }

  private setTimelineColumns(mode: number): void {
    const previous: number = this.timelineColumnsMode;
    this.timelineColumnsMode = mode;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    if (!timelineSettingsStore.saveTimelineColumns(context, mode)) {
      this.timelineColumnsMode = previous;
    }
  }

  private setReadAloudEntryEnabled(value: boolean): void {
    const previous: boolean = this.readAloudEntryEnabled;
    this.readAloudEntryEnabled = value;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    if (!readAloudSettingsStore.saveEntryEnabled(context, value)) {
      this.readAloudEntryEnabled = previous;
    }
  }

  private loadContentFilters(): void {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const settings: ContentFilterSettings = contentFilterStore.load(context);
    this.filterOnlyMedia = settings.onlyMedia;
    this.filterHideReposts = settings.hideReposts;
    this.filterHideReplies = settings.hideReplies;
    this.filterHideAds = settings.hideAds;
    this.filterKeywords = settings.keywordsText;
    this.filterMutedUsers = settings.mutedUsersText;
  }

  private saveContentFilters(): void {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const settings: ContentFilterSettings = new ContentFilterSettings(
      this.filterOnlyMedia,
      this.filterHideReposts,
      this.filterHideReplies,
      this.filterKeywords,
      this.filterMutedUsers,
      this.filterHideAds
    );
    if (!contentFilterStore.save(context, settings)) {
      promptAction.showToast({
        message: this.text($r('app.string.settings_filter_save_failed')),
        duration: 1800
      });
    }
  }

  private setFilterOnlyMedia(value: boolean): void {
    this.filterOnlyMedia = value;
    this.saveContentFilters();
  }

  private setFilterHideReposts(value: boolean): void {
    this.filterHideReposts = value;
    this.saveContentFilters();
  }

  private setFilterHideReplies(value: boolean): void {
    this.filterHideReplies = value;
    this.saveContentFilters();
  }

  private setFilterHideAds(value: boolean): void {
    this.filterHideAds = value;
    this.saveContentFilters();
  }

  private setFilterKeywords(value: string): void {
    this.filterKeywords = value;
    this.saveContentFilters();
  }

  private setFilterMutedUsers(value: string): void {
    this.filterMutedUsers = value;
    this.saveContentFilters();
  }

  private homeTabMaterialIndex(): number {
    if (this.homeTabMaterialLevel === HDS_TAB_MATERIAL_EXQUISITE) {
      return 0;
    }
    if (this.homeTabMaterialLevel === HDS_TAB_MATERIAL_GENTLE) {
      return 1;
    }
    if (this.homeTabMaterialLevel === HDS_TAB_MATERIAL_SMOOTH) {
      return 2;
    }
    return 3;
  }

  private homeTabMaterialLabel(): Resource {
    if (this.homeTabMaterialLevel === HDS_TAB_MATERIAL_EXQUISITE) {
      return $r('app.string.settings_hds_tabs_material_exquisite');
    }
    if (this.homeTabMaterialLevel === HDS_TAB_MATERIAL_GENTLE) {
      return $r('app.string.settings_hds_tabs_material_gentle');
    }
    if (this.homeTabMaterialLevel === HDS_TAB_MATERIAL_SMOOTH) {
      return $r('app.string.settings_hds_tabs_material_smooth');
    }
    return $r('app.string.settings_hds_tabs_material_adaptive');
  }

  private timelineColumnsIndex(): number {
    if (this.timelineColumnsMode === TIMELINE_COLUMNS_ONE) {
      return 1;
    }
    if (this.timelineColumnsMode === TIMELINE_COLUMNS_TWO) {
      return 2;
    }
    if (this.timelineColumnsMode === TIMELINE_COLUMNS_THREE) {
      return 3;
    }
    return 0;
  }

  private timelineColumnsLabel(): Resource {
    if (this.timelineColumnsMode === TIMELINE_COLUMNS_ONE) {
      return $r('app.string.settings_timeline_columns_one');
    }
    if (this.timelineColumnsMode === TIMELINE_COLUMNS_TWO) {
      return $r('app.string.settings_timeline_columns_two');
    }
    if (this.timelineColumnsMode === TIMELINE_COLUMNS_THREE) {
      return $r('app.string.settings_timeline_columns_three');
    }
    return $r('app.string.settings_timeline_columns_auto');
  }

  private selectTimelineColumns(index: number): void {
    let mode: number = TIMELINE_COLUMNS_AUTO;
    if (index === 1) {
      mode = TIMELINE_COLUMNS_ONE;
    } else if (index === 2) {
      mode = TIMELINE_COLUMNS_TWO;
    } else if (index === 3) {
      mode = TIMELINE_COLUMNS_THREE;
    }
    this.setTimelineColumns(mode);
  }

  private selectHomeTabMaterial(index: number): void {
    let level: number = HDS_TAB_MATERIAL_ADAPTIVE;
    if (index === 0) {
      level = HDS_TAB_MATERIAL_EXQUISITE;
    } else if (index === 1) {
      level = HDS_TAB_MATERIAL_GENTLE;
    } else if (index === 2) {
      level = HDS_TAB_MATERIAL_SMOOTH;
    }
    const previous: number = this.homeTabMaterialLevel;
    this.homeTabMaterialLevel = level;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    if (!hdsTabsSettingsStore.saveHomeTabMaterialLevel(context, level)) {
      this.homeTabMaterialLevel = previous;
    }
  }

  private setClassicBottomBar(enabled: boolean): void {
    const previous: boolean = this.classicBottomBar;
    this.classicBottomBar = enabled;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    if (!hdsTabsSettingsStore.saveClassicBottomBar(context, enabled)) {
      this.classicBottomBar = previous;
      promptAction.showToast({ message: this.text($r('app.string.settings_interaction_save_failed')) });
    }
  }

  private setRootTabLabelsVisible(visible: boolean): void {
    const previous: boolean = this.rootTabLabelsVisible;
    this.rootTabLabelsVisible = visible;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    if (!hdsTabsSettingsStore.saveRootTabLabelsVisible(context, visible)) {
      this.rootTabLabelsVisible = previous;
      promptAction.showToast({ message: this.text($r('app.string.settings_interaction_save_failed')) });
    }
  }

  private loadCurrentAppIcon(): void {
    this.appIconStore.currentName().then((name: string): void => {
      if (!isKnownAppIcon(name)) {
        // 系统里还记着旧版本删掉的图标，先回到默认图标再展示。
        this.appIconStore.select(APP_ICON_DEFAULT).then((): void => {
          this.finishLoadingAppIconSettings(APP_ICON_DEFAULT);
        });
        return;
      }
      if (name === APP_ICON_MID_AUTUMN && !isMidAutumnIconAvailable()) {
        // 中秋限时图标过期后不再展示，桌面上的图标一并换回默认，
        // 否则系统会一直保留这个已经下架的选择。
        this.appIconStore.select(APP_ICON_DEFAULT).then((result: AppIconApplyResult): void => {
          if (result.ok) {
            promptAction.showToast({
              message: this.text($r('app.string.settings_app_icon_mid_autumn_ended')),
              duration: 3200
            });
          }
          this.finishLoadingAppIconSettings(APP_ICON_DEFAULT);
        });
        return;
      }
      this.finishLoadingAppIconSettings(name);
    });
  }

  private finishLoadingAppIconSettings(currentIconName: string): void {
    this.currentAppIcon = currentIconName;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const settings: AppIconScheduleSettings = this.appIconScheduleStore.load(context, currentIconName);
    this.appIconScheduleEnabled = settings.enabled;
    this.appIconScheduleStartMinute = settings.startMinute;
    this.appIconScheduleEndMinute = settings.endMinute;
    this.appIconScheduleTarget = settings.iconName;
    this.appIconScheduleFallback = settings.fallbackIconName;
    if (settings.enabled) {
      this.applyAppIconSchedule(settings, false, $r('app.string.settings_app_icon_schedule_saved'));
    }
  }

  private selectAppIcon(name: string): void {
    if ((!this.appIconScheduleEnabled && name === this.currentAppIcon) || this.appIconBusy) {
      return;
    }
    if (!this.appIconSupported) {
      promptAction.showToast({
        message: this.text($r('app.string.settings_app_icon_unsupported')),
        duration: 2600
      });
      return;
    }
    if (this.appIconScheduleEnabled) {
      const settings: AppIconScheduleSettings = this.createAppIconScheduleSettings(true,
        this.appIconScheduleStartMinute, this.appIconScheduleEndMinute,
        this.appIconScheduleTarget, name);
      this.saveAndApplyAppIconSchedule(settings, true,
        $r('app.string.settings_app_icon_schedule_fallback_saved'));
      return;
    }
    const previous: string = this.currentAppIcon;
    this.appIconBusy = true;
    this.appIconStore.select(name).then((result: AppIconApplyResult): void => {
      this.appIconBusy = false;
      if (result.ok) {
        this.currentAppIcon = name;
        this.appIconScheduleFallback = name;
        const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
        const settings: AppIconScheduleSettings = this.createAppIconScheduleSettings(false,
          this.appIconScheduleStartMinute, this.appIconScheduleEndMinute,
          this.appIconScheduleTarget, name);
        this.appIconScheduleStore.save(context, settings);
        promptAction.showToast({
          message: this.text($r('app.string.settings_app_icon_applied')),
          duration: 2200
        });
        return;
      }
      // 系统拒绝时回退到原来的勾选状态。
      this.currentAppIcon = previous;
      promptAction.showToast({
        message: this.appIconFailureMessage(result.code),
        duration: 3200
      });
    });
  }

  private appIconFailureMessage(code: number): string {
    if (code === APP_ICON_ERROR_THEME_CONFLICT) {
      return this.text($r('app.string.settings_app_icon_theme_conflict'));
    }
    if (code === APP_ICON_ERROR_CLONE_UNSUPPORTED) {
      return this.text($r('app.string.settings_app_icon_clone'));
    }
    if (code === APP_ICON_ERROR_UNSUPPORTED) {
      return this.text($r('app.string.settings_app_icon_unsupported'));
    }
    return this.text($r('app.string.settings_app_icon_failed'));
  }

  private createAppIconScheduleSettings(enabled: boolean, startMinute: number, endMinute: number,
    iconName: string, fallbackIconName: string): AppIconScheduleSettings {
    return new AppIconScheduleSettings(enabled, startMinute, endMinute, iconName, fallbackIconName);
  }

  private saveAndApplyAppIconSchedule(settings: AppIconScheduleSettings, showSuccess: boolean,
    successMessage: Resource): void {
    if (this.appIconBusy) {
      return;
    }
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    if (!this.appIconScheduleStore.save(context, settings)) {
      promptAction.showToast({
        message: this.text($r('app.string.settings_app_icon_schedule_save_failed')),
        duration: 3000
      });
      return;
    }
    this.appIconScheduleEnabled = settings.enabled;
    this.appIconScheduleStartMinute = settings.startMinute;
    this.appIconScheduleEndMinute = settings.endMinute;
    this.appIconScheduleTarget = settings.iconName;
    this.appIconScheduleFallback = settings.fallbackIconName;
    this.applyAppIconSchedule(settings, showSuccess, successMessage);
  }

  private applyAppIconSchedule(settings: AppIconScheduleSettings, showSuccess: boolean,
    successMessage: Resource): void {
    const targetIcon: string = this.appIconScheduleStore.iconForTime(settings, new Date());
    if (targetIcon === this.currentAppIcon) {
      if (showSuccess) {
        promptAction.showToast({ message: this.text(successMessage), duration: 2200 });
      }
      return;
    }
    const previous: string = this.currentAppIcon;
    this.appIconBusy = true;
    this.appIconStore.select(targetIcon).then((result: AppIconApplyResult): void => {
      this.appIconBusy = false;
      if (result.ok) {
        this.currentAppIcon = targetIcon;
        if (showSuccess) {
          promptAction.showToast({ message: this.text(successMessage), duration: 2200 });
        }
        return;
      }
      this.currentAppIcon = previous;
      promptAction.showToast({
        message: this.appIconFailureMessage(result.code),
        duration: 3200
      });
    });
  }

  private changeAppIconScheduleEnabled(enabled: boolean): void {
    if (!this.appIconSupported) {
      promptAction.showToast({
        message: this.text($r('app.string.settings_app_icon_unsupported')),
        duration: 2600
      });
      return;
    }
    const settings: AppIconScheduleSettings = this.createAppIconScheduleSettings(enabled,
      this.appIconScheduleStartMinute, this.appIconScheduleEndMinute,
      this.appIconScheduleTarget, this.appIconScheduleFallback);
    this.saveAndApplyAppIconSchedule(settings, true,
      $r('app.string.settings_app_icon_schedule_saved'));
  }

  private changeAppIconScheduleTime(isStart: boolean, minute: number): void {
    let startMinute: number = this.appIconScheduleStartMinute;
    let endMinute: number = this.appIconScheduleEndMinute;
    if (isStart) {
      startMinute = minute;
    } else {
      endMinute = minute;
    }
    if (startMinute === endMinute) {
      promptAction.showToast({
        message: this.text($r('app.string.settings_app_icon_schedule_invalid')),
        duration: 2600
      });
      return;
    }
    const settings: AppIconScheduleSettings = this.createAppIconScheduleSettings(
      this.appIconScheduleEnabled, startMinute, endMinute,
      this.appIconScheduleTarget, this.appIconScheduleFallback);
    this.saveAndApplyAppIconSchedule(settings, true,
      $r('app.string.settings_app_icon_schedule_saved'));
  }

  private changeAppIconScheduleTarget(index: number): void {
    if (index < 0 || index >= this.appIconScheduleIconNames.length) {
      return;
    }
    const iconName: string = this.appIconScheduleIconNames[index];
    const settings: AppIconScheduleSettings = this.createAppIconScheduleSettings(
      this.appIconScheduleEnabled, this.appIconScheduleStartMinute,
      this.appIconScheduleEndMinute, iconName, this.appIconScheduleFallback);
    this.saveAndApplyAppIconSchedule(settings, true,
      $r('app.string.settings_app_icon_schedule_saved'));
  }

  private appIconScheduleIconIndex(): number {
    for (let index: number = 0; index < this.appIconScheduleIconNames.length; index++) {
      if (this.appIconScheduleIconNames[index] === this.appIconScheduleTarget) {
        return index;
      }
    }
    return 0;
  }

  private appIconScheduleIconLabel(): Resource {
    const index: number = this.appIconScheduleIconIndex();
    if (index === 1) {
      return $r('app.string.settings_app_icon_classic');
    }
    if (index === 2) {
      return $r('app.string.settings_app_icon_spectrum');
    }
    if (index === 3) {
      return $r('app.string.settings_app_icon_outline');
    }
    if (index === 4) {
      return $r('app.string.settings_app_icon_brush');
    }
    if (index === 5) {
      return $r('app.string.settings_app_icon_blossom');
    }
    if (index === 6) {
      return $r('app.string.settings_app_icon_blue_bird');
    }
    if (index === 7) {
      return $r('app.string.settings_app_icon_twitter_blue');
    }
    if (index === 8) {
      return $r('app.string.settings_app_icon_twitter_white');
    }
    if (index === 9) {
      return $r('app.string.settings_app_icon_x_black');
    }
    if (index === 10) {
      return $r('app.string.settings_app_icon_x_white');
    }
    if (index === 11) {
      return $r('app.string.settings_app_icon_frog_white');
    }
    if (index === 12) {
      return $r('app.string.settings_app_icon_frog_black');
    }
    if (index === 13) {
      return $r('app.string.settings_app_icon_milk_frog_white');
    }
    if (index === 14) {
      return $r('app.string.settings_app_icon_milk_frog_black');
    }
    return $r('app.string.settings_app_icon_default');
  }

  private appIconScheduleTimeLabel(minute: number): string {
    const hour: number = Math.floor(minute / 60);
    const minutePart: number = minute % 60;
    const hourText: string = hour < 10 ? `0${hour}` : `${hour}`;
    const minuteText: string = minutePart < 10 ? `0${minutePart}` : `${minutePart}`;
    return `${hourText}:${minuteText}`;
  }

  private showAppIconScheduleTimePicker(isStart: boolean): void {
    if (this.appIconBusy) {
      return;
    }
    const minute: number = isStart ? this.appIconScheduleStartMinute : this.appIconScheduleEndMinute;
    const selected: Date = new Date();
    selected.setHours(Math.floor(minute / 60), minute % 60, 0, 0);
    this.getUIContext().showTimePickerDialog({
      useMilitaryTime: true,
      selected: selected,
      format: TimePickerFormat.HOUR_MINUTE,
      onAccept: (value: TimePickerResult): void => {
        if (value.hour === undefined || value.minute === undefined) {
          return;
        }
        this.changeAppIconScheduleTime(isStart, value.hour * 60 + value.minute);
      }
    });
  }

  private isAppIconTileSelected(name: string): boolean {
    if (this.appIconScheduleEnabled) {
      return this.appIconScheduleFallback === name;
    }
    return this.currentAppIcon === name;
  }

  private title(): Resource {
    if (this.section === 'link_behavior') { return $r('app.string.settings_link_in_app'); }
    return settingsCategory(this.section)?.title ?? $r('app.string.settings_title');
  }

  private children(): SettingsCategory[] {
    return settingsChildren(this.section);
  }

  private openSection(section: string): void {
    AppStorage.setOrCreate<string>('harmonyx.desktop_settings_section', section);
    const param: SettingsRouteParam = { section: section };
    NavigationGuard.pushPath<SettingsRouteParam>(this.pageStack, { name: 'SettingsSection', param: param },
      (route: SettingsRouteParam): string => route.section);
  }

  @Builder
  private CategoryContent(): void {
    Column() {
      Column({ space: 8 }) {
        ForEach(this.children(), (category: SettingsCategory) => {
          SettingsRow({ icon: category.icon, title: category.title, detail: category.detail,
            onRowClick: (): void => this.openSection(category.id) })
        }, (category: SettingsCategory): string => category.id)
      }.width('100%').borderRadius(20)
        .backgroundColor(cardSurfaceColor(this.displayMode, this.darkSurface))
    }.width('100%').padding({ left: $r('app.float.settings_page_horizontal_padding'),
      right: $r('app.float.settings_page_horizontal_padding'), top: 12 })
  }

  @Builder
  private SimpleItem(title: Resource, detail: Resource, onClick: () => void): void {
    Row() {
      Column({ space: 4 }) {
        Text(title).fontFamily(this.appFontFamily).fontSize($r('sys.float.Subtitle_L')).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Text(detail).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary'))
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(15).fontColor([$r('app.color.text_secondary')])
        .scale({ x: isAppRtl(this.appLocale) ? -1 : 1 })
    }
    .width('100%')
    .padding({ top: 16, bottom: 16, left: 20, right: 20 })
    .onClick((): void => onClick())
  }

  private saveAppearance(): void {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const settings: AppearanceSettings = new AppearanceSettings(this.displayMode, this.accentColor,
      this.fontMode, this.fontScale, this.autoHideTitleBar, this.autoHideTabBar, this.autoHideFab,
      this.darkSurface, this.composeButtonEnabled, this.titleBarStyleMode,
      this.titleBarGlassMaterialLevel, this.homeHeaderCollapseEnabled, this.contentFontFamily,
      this.replyCapsuleMaterialLevel, this.avatarTintEnabled, this.titleBarLogoEnabled, this.systemEmojiEnabled,
      this.compactSwitchStyle, this.replyCapsuleButtonMaterialEnabled);
    this.appearanceStore.save(context, settings);
  }

  private saveSheetMaterial(enabled: boolean, level: number): void {
    const previousEnabled: boolean = this.sheetMaterialEnabled;
    const previousLevel: number = this.sheetMaterialLevel;
    this.sheetMaterialEnabled = enabled;
    this.sheetMaterialLevel = level;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    if (!sheetMaterialSettingsStore.save(context, enabled, level)) {
      this.sheetMaterialEnabled = previousEnabled;
      this.sheetMaterialLevel = previousLevel;
      promptAction.showToast({ message: this.text($r('app.string.settings_sheet_material_save_failed')) });
    }
  }

  private sheetMaterialLevelLabel(): Resource {
    const labels: Resource[] = [
      $r('app.string.settings_title_bar_glass_level_ultra_thin'),
      $r('app.string.settings_title_bar_glass_level_thin'),
      $r('app.string.settings_title_bar_glass_level_regular'),
      $r('app.string.settings_title_bar_glass_level_thick'),
      $r('app.string.settings_title_bar_glass_level_ultra_thick')
    ];
    return labels[this.sheetMaterialLevel];
  }

  private setAutoHideTitleBar(value: boolean): void {
    this.autoHideTitleBar = value;
    this.saveAppearance();
  }

  private setAutoHideTabBar(value: boolean): void {
    this.autoHideTabBar = value;
    this.saveAppearance();
  }

  private isBottomBarPageEnabled(pageIndex: number): boolean {
    return (this.bottomBarPagesMask & (1 << pageIndex)) !== 0;
  }

  private bottomBarPageSwitchDisabled(pageIndex: number): boolean {
    return this.isBottomBarPageEnabled(pageIndex) &&
      bottomBarSettingsStore.enabledPageCount(this.bottomBarPagesMask) <= 2;
  }

  private setBottomBarPageEnabled(pageIndex: number, enabled: boolean): void {
    let nextMask: number = this.bottomBarPagesMask;
    const pageBit: number = 1 << pageIndex;
    if (enabled) {
      nextMask = nextMask | pageBit;
    } else {
      if (bottomBarSettingsStore.enabledPageCount(nextMask) <= 2) {
        return;
      }
      nextMask = nextMask & ~pageBit;
    }
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    bottomBarSettingsStore.save(context, nextMask);
  }

  private setAutoHideFab(value: boolean): void {
    this.autoHideFab = value;
    this.saveAppearance();
  }

  private setHomeHeaderCollapseEnabled(value: boolean): void {
    this.homeHeaderCollapseEnabled = value;
    this.saveAppearance();
  }

  private setTitleBarStyleMode(value: number): void {
    this.titleBarStyleMode = value;
    this.saveAppearance();
  }

  // 玻璃材质下的子开关：打开后关掉沉浸模糊，只留那块玻璃。
  private setGlassImmersiveBlurOff(value: boolean): void {
    this.titleBarStyleMode = value ? TITLE_BAR_STYLE_GLASS_ONLY : TITLE_BAR_STYLE_GLASS;
    this.saveAppearance();
  }

  private glassImmersiveBlurOff(): boolean {
    return this.titleBarStyleMode === TITLE_BAR_STYLE_GLASS_ONLY;
  }

  private isGlassTitleBarStyle(): boolean {
    return this.titleBarStyleMode === TITLE_BAR_STYLE_GLASS ||
      this.titleBarStyleMode === TITLE_BAR_STYLE_GLASS_ONLY;
  }

  private setTitleBarGlassMaterialLevel(value: number): void {
    this.titleBarGlassMaterialLevel = value;
    this.saveAppearance();
  }

  private setReplyCapsuleMaterialLevel(value: number): void {
    this.replyCapsuleMaterialLevel = value;
    this.saveAppearance();
  }

  private setReplyCapsuleButtonMaterialEnabled(value: boolean): void {
    this.replyCapsuleButtonMaterialEnabled = value;
    this.saveAppearance();
  }

  private titleBarGlassLevelIndex(): number {
    if (this.titleBarGlassMaterialLevel === TITLE_BAR_GLASS_ULTRA_THIN) {
      return 0;
    }
    if (this.titleBarGlassMaterialLevel === TITLE_BAR_GLASS_REGULAR) {
      return 2;
    }
    if (this.titleBarGlassMaterialLevel === TITLE_BAR_GLASS_THICK) {
      return 3;
    }
    if (this.titleBarGlassMaterialLevel === TITLE_BAR_GLASS_ULTRA_THICK) {
      return 4;
    }
    return 1;
  }

  private titleBarGlassLevelLabel(): Resource {
    const index: number = this.titleBarGlassLevelIndex();
    if (index === 0) {
      return $r('app.string.settings_title_bar_glass_level_ultra_thin');
    }
    if (index === 2) {
      return $r('app.string.settings_title_bar_glass_level_regular');
    }
    if (index === 3) {
      return $r('app.string.settings_title_bar_glass_level_thick');
    }
    if (index === 4) {
      return $r('app.string.settings_title_bar_glass_level_ultra_thick');
    }
    return $r('app.string.settings_title_bar_glass_level_thin');
  }

  private replyCapsuleMaterialLevelLabel(): Resource {
    if (this.replyCapsuleMaterialLevel === TITLE_BAR_GLASS_ULTRA_THIN) {
      return $r('app.string.settings_title_bar_glass_level_ultra_thin');
    }
    if (this.replyCapsuleMaterialLevel === TITLE_BAR_GLASS_THIN) {
      return $r('app.string.settings_title_bar_glass_level_thin');
    }
    if (this.replyCapsuleMaterialLevel === TITLE_BAR_GLASS_REGULAR) {
      return $r('app.string.settings_title_bar_glass_level_regular');
    }
    if (this.replyCapsuleMaterialLevel === TITLE_BAR_GLASS_THICK) {
      return $r('app.string.settings_title_bar_glass_level_thick');
    }
    return $r('app.string.settings_title_bar_glass_level_ultra_thick');
  }

  private titleBarStyleIndex(): number {
    if (this.titleBarStyleMode === TITLE_BAR_STYLE_BLUR) {
      return 1;
    }
    if (this.isGlassTitleBarStyle()) {
      return 2;
    }
    return 0;
  }

  private titleBarStyleLabel(): Resource {
    const index: number = this.titleBarStyleIndex();
    if (index === 1) {
      return $r('app.string.settings_title_bar_style_blur');
    }
    if (index === 2) {
      return $r('app.string.settings_title_bar_style_glass');
    }
    return $r('app.string.settings_title_bar_style_immersive');
  }

  private setComposeButtonEnabled(value: boolean): void {
    this.composeButtonEnabled = value;
    this.saveAppearance();
  }

  private setAvatarTintEnabled(value: boolean): void {
    this.avatarTintEnabled = value;
    this.saveAppearance();
  }

  private setSystemEmojiEnabled(value: boolean): void {
    this.systemEmojiEnabled = value;
    this.saveAppearance();
  }

  private setPressEffectEnabled(value: boolean): void {
    const previous: boolean = this.pressEffectEnabled;
    this.pressEffectEnabled = value;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    if (!this.pressEffectSettingsStore.saveEnabled(context, value)) {
      this.pressEffectEnabled = previous;
    }
  }

  private selectDarkSurface(surface: string): void {
    this.darkSurface = surface;
    this.saveAppearance();
  }

  private selectFontMode(mode: string): void {
    if (mode === this.fontMode) {
      return;
    }
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    this.fontMode = mode;
    if (mode === FONT_MODE_APP) {
      this.appFontScaleApplied = true;
      this.fontRestartPending = false;
      this.appearanceStore.applyFontScale(context, this.fontScale);
    } else if (this.appFontScaleApplied) {
      // setFontSizeScale() disables follow-system for the rest of this process,
      // so the switch back is persisted now and applied on the next launch.
      this.fontRestartPending = true;
    }
    this.saveAppearance();
  }

  private onFontScaleChange(value: number): void {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    this.fontScale = value;
    this.appFontScaleApplied = true;
    this.appearanceStore.applyFontScale(context, value);
    this.saveAppearance();
  }

  private selectContentFontFamily(family: string): void {
    if (family === this.contentFontFamily) {
      return;
    }
    this.contentFontFamily = family;
    this.saveAppearance();
  }

  private async importAppFont(): Promise<void> {
    if (this.appFontBusy) { return; }
    this.appFontBusy = true;
    try {
      const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      const result: FontImportResult = await appFontStore.importFont(context, this.getUIContext());
      if (result.cancelled) { return; }
      if (result.applied) {
        promptAction.showToast({ message: this.text($r('app.string.settings_custom_font_imported')) });
        return;
      }
      let reason: Resource = $r('app.string.settings_custom_font_register_failed');
      if (result.error === 'picker') { reason = $r('app.string.settings_custom_font_picker_failed'); }
      if (result.error === 'format') { reason = $r('app.string.settings_custom_font_invalid'); }
      if (result.error === 'read') { reason = $r('app.string.settings_custom_font_read_failed'); }
      if (result.error === 'save') { reason = $r('app.string.settings_custom_font_save_failed'); }
      promptAction.showToast({ message: this.text(reason), duration: 3000 });
    } finally {
      this.appFontBusy = false;
    }
  }

  private async clearAppFont(): Promise<void> {
    if (this.appFontBusy) { return; }
    this.appFontBusy = true;
    try {
      const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      if (!await appFontStore.clear(context)) {
        promptAction.showToast({ message: this.text($r('app.string.settings_custom_font_save_failed')) });
      }
    } finally {
      this.appFontBusy = false;
    }
  }

  private restartApplication(): void {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    try {
      const want: Want = {
        bundleName: context.abilityInfo.bundleName,
        abilityName: context.abilityInfo.name
      };
      context.getApplicationContext().restartApp(want);
    } catch (error) {
      promptAction.showToast({ message: this.text($r('app.string.settings_font_restart_failed')), duration: 3000 });
    }
  }

  private selectDisplayMode(mode: string): void {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    try {
      context.getApplicationContext().setColorMode(this.appearanceStore.colorMode(mode));
      this.displayMode = mode;
      this.saveAppearance();
    } catch (error) {
      // Keep the currently rendered color mode when the system rejects a change.
    }
  }

  private selectAccent(color: string): void {
    this.accentColor = color;
    this.saveAppearance();
  }



  // The account switcher is a destination of its own, shared with the drawer
  // and the Me tab.
  private openAccounts(): void {
    this.pageStack.pushPath({ name: 'Accounts' });
  }

  private openBlockedAccounts(): void {
    const param: UserListRouteParam = { mode: USER_LIST_BLOCKED, userId: '' };
    this.pageStack.pushPath({ name: 'UserList', param: param });
  }

  private openHelpCenter(): void {
    this.pageStack.pushPath({ name: 'HelpCenter', param: '' });
  }

  private openDiagnostics(): void {
    this.pageStack.pushPath({ name: 'Diagnostics', param: '' });
  }



  private selectLanguage(language: string): void {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    try {
      if (language === APP_LANGUAGE_SYSTEM) {
        i18n.System.setAppPreferredLanguage('default');
      } else {
        i18n.System.setAppPreferredLanguage(language);
      }
      this.appLanguage = language;
      this.languageStore.save(context, language);
      publishAppLocale();
      if (language === APP_LANGUAGE_SYSTEM) {
        promptAction.showToast({ message: this.text($r('app.string.settings_language_restart')) });
      }
    } catch (error) {
      // Retain the current language if the system declines the configuration change.
    }
  }

  @Builder
  private DisplayModeOption(mode: string, icon: Resource, label: Resource): void {
    Column({ space: 8 }) {
      SymbolGlyph(icon)
        .fontSize(28)
        .fontColor([this.displayMode === mode ? this.accentColor : $r('app.color.text_primary')])
      Text(label).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_M'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .textAlign(TextAlign.Center)
    }
    .layoutWeight(1)
    .constraintSize({ minHeight: 92 })
    .padding({ left: 8, right: 8, top: 12, bottom: 12 })
    .justifyContent(FlexAlign.Center)
    .borderRadius(18)
    .backgroundColor(this.displayMode === mode ?
      fieldSurfaceColor(this.displayMode, this.darkSurface) : cardSurfaceColor(this.displayMode, this.darkSurface))
    .border({ width: this.displayMode === mode ? 2 : 1,
      color: this.displayMode === mode ? this.accentColor : $r('app.color.divider') })
    .onClick((): void => this.selectDisplayMode(mode))
  }

  @Builder
  private DarkSurfaceOption(surface: string, label: Resource, swatch: ResourceColor): void {
    Row({ space: 10 }) {
      Circle({ width: 24, height: 24 })
        .fill(swatch)
        .stroke($r('app.color.divider'))
        .strokeWidth(1)
      Text(label).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_M'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
      if (this.darkSurface === surface) {
        SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
          .fontSize(19)
          .fontColor([this.accentColor])
      }
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .borderRadius(16)
    .backgroundColor(this.darkSurface === surface ?
      fieldSurfaceColor(this.displayMode, this.darkSurface) : cardSurfaceColor(this.displayMode, this.darkSurface))
    .border({ width: this.darkSurface === surface ? 2 : 1,
      color: this.darkSurface === surface ? this.accentColor : $r('app.color.divider') })
    .onClick((): void => this.selectDarkSurface(surface))
  }

  @Builder
  private AccentOption(color: string, swatch: Resource, label: Resource): void {
    Stack({ alignContent: Alignment.Center }) {
      if (this.accentColor === color) {
        Circle({ width: 38, height: 38 }).fill(Color.Transparent)
          .stroke(this.accentColor).strokeWidth(3)
      }
      Circle({ width: 30, height: 30 }).fill(swatch)
    }
    .width(42)
    .height(42)
    .flexShrink(0)
    .margin({ right: 8, bottom: 8 })
    .id('settings-accent-' + color.substring(1))
    .accessibilityText(label)
    .onClick((): void => this.selectAccent(color))
  }

  @Builder
  private FontModeOption(mode: string, icon: Resource, label: Resource): void {
    Row({ space: 8 }) {
      SymbolGlyph(icon)
        .fontSize(20)
        .fontColor([this.fontMode === mode ? $r('app.color.text_accent') : $r('app.color.text_primary')])
      Text(label).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_M'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
    }
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .padding({ left: 12, right: 12, top: 12, bottom: 12 })
    .borderRadius(16)
    .backgroundColor(this.fontMode === mode ?
      fieldSurfaceColor(this.displayMode, this.darkSurface) : cardSurfaceColor(this.displayMode, this.darkSurface))
    .border({ width: this.fontMode === mode ? 2 : 1,
      color: this.fontMode === mode ? this.accentColor : $r('app.color.divider') })
    .onClick((): void => this.selectFontMode(mode))
  }

  @Builder
  private ContentFontOption(family: string, label: Resource): void {
    Column({ space: 7 }) {
      Text($r('app.string.settings_content_font_sample'))
        .fontSize($r('sys.float.Title_S'))
        .fontWeight(FontWeight.Medium)
        .fontFamily(family)
        .fontColor($r('app.color.text_primary'))
      Text(label).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Caption_L'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .textAlign(TextAlign.Center)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
    .padding({ top: 11, bottom: 11, left: 4, right: 4 })
    .borderRadius(14)
    .backgroundColor(this.contentFontFamily === family ?
      fieldSurfaceColor(this.displayMode, this.darkSurface) : cardSurfaceColor(this.displayMode, this.darkSurface))
    .border({ width: this.contentFontFamily === family ? 2 : 1,
      color: this.contentFontFamily === family ? this.accentColor : $r('app.color.divider') })
    .onClick((): void => this.selectContentFontFamily(family))
  }

  @Builder
  private ContentFontSection(): void {
    Column({ space: 10 }) {
      Text($r('app.string.settings_content_font_title')).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Title_S'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
      Row({ space: 8 }) {
        this.ContentFontOption(CONTENT_FONT_FAMILY_SYSTEM, $r('app.string.settings_content_font_system'))
        this.ContentFontOption(CONTENT_FONT_FAMILY_SERIF, $r('app.string.settings_content_font_serif'))
        this.ContentFontOption(CONTENT_FONT_FAMILY_MONOSPACE,
          $r('app.string.settings_content_font_monospace'))
      }
      .width('100%')
      Text($r('app.string.settings_content_font_hint')).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('app.color.text_secondary'))
        .lineHeight(20)
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private AppFontSection(): void {
    Column({ space: 12 }) {
      Text($r('app.string.settings_custom_font_title')).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Title_S'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
      Row({ space: 10 }) {
        Text($r('app.string.settings_custom_font_current')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_L'))
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Text(this.appFontName.length > 0 ? this.appFontName : $r('app.string.settings_custom_font_system')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      Column({ space: 4 }) {
        Text($r('app.string.settings_custom_font_sample_large')).fontFamily(this.appFontFamily)
          .fontSize(28)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Text($r('app.string.settings_custom_font_sample_medium')).fontFamily(this.appFontFamily)
          .fontSize(17)
          .fontColor($r('app.color.text_primary'))
        Text($r('app.string.settings_custom_font_sample_small')).fontFamily(this.appFontFamily)
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(12)
      .backgroundColor(fieldSurfaceColor(this.displayMode, this.darkSurface))
      .borderRadius(8)
      Row({ space: 10 }) {
        Column({ space: 3 }) {
          Text($r('app.string.settings_custom_font_import')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_L'))
            .fontColor($r('app.color.text_primary'))
          Text($r('app.string.settings_custom_font_import_desc')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('app.color.text_secondary'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(16)
          .fontColor([$r('app.color.text_secondary')])
      }
      .width('100%')
      .opacity(this.appFontBusy ? 0.45 : 1)
      .enabled(!this.appFontBusy)
      .onClick((): void => { this.importAppFont(); })
      if (this.appFontName.length > 0) {
        Button($r('app.string.settings_custom_font_reset'))
          .width('100%')
          .enabled(!this.appFontBusy)
          .onClick((): void => { this.clearAppFont(); })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private FontSizeSection(): void {
    Column({ space: 12 }) {
      Text($r('app.string.settings_font_size')).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Title_S'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
      Row({ space: 10 }) {
        this.FontModeOption(FONT_MODE_SYSTEM, $r('sys.symbol.gearshape'),
          $r('app.string.settings_font_follow_system'))
        this.FontModeOption(FONT_MODE_APP, $r('sys.symbol.textformat_size_square'),
          $r('app.string.settings_font_app_scale'))
      }
      .width('100%')
      Text($r('app.string.settings_font_preview')).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_L'))
        .fontColor($r('app.color.text_primary'))
        .width('100%')
      Text(this.fontMode === FONT_MODE_APP ?
        $r('app.string.settings_font_app_hint') : $r('app.string.settings_font_system_hint')).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
      if (this.fontMode === FONT_MODE_SYSTEM) {
        Text(this.text($r('app.string.settings_font_system_scale_label')) +
          this.systemFontScale.toFixed(2) + '×').fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_accent'))
          .width('100%')
      }
      if (this.fontMode === FONT_MODE_APP) {
        Row({ space: 10 }) {
          Text('Aa').fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_S'))
            .fontColor($r('app.color.text_secondary'))
          Slider({
            value: this.fontScale,
            min: MIN_FONT_SCALE,
            max: MAX_FONT_SCALE,
            step: 0.05,
            style: SliderStyle.InSet
          })
            .layoutWeight(1)
            .selectedColor(this.accentColor)
            .showTips(true)
            .onChange((value: number): void => {
              this.onFontScaleChange(value);
            })
          Text('Aa').fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Title_S'))
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
      }
      if (this.fontRestartPending) {
        Column({ space: 8 }) {
          Text($r('app.string.settings_font_restart_hint')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
          Button($r('app.string.settings_font_restart_action'), { stateEffect: true })
            .width('100%')
            .backgroundColor(secondaryButtonSurfaceColor(this.displayMode, this.darkSurface))
            .fontColor($r('app.color.text_primary'))
            .onClick((): void => this.restartApplication())
        }
        .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private TimelineColumnsSection(): void {
    Column({ space: 12 }) {
      Column({ space: 4 }) {
        Text($r('app.string.settings_timeline_columns_title')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Title_S'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text($r('app.string.settings_timeline_columns_desc')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('app.color.text_secondary'))
          .lineHeight(20)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      Row({ space: 12 }) {
        Text($r('app.string.settings_timeline_columns_label')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Subtitle_L'))
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Select([
          { value: $r('app.string.settings_timeline_columns_auto') },
          { value: $r('app.string.settings_timeline_columns_one') },
          { value: $r('app.string.settings_timeline_columns_two') },
          { value: $r('app.string.settings_timeline_columns_three') }
        ])
          .selected(this.timelineColumnsIndex())
          .value(this.timelineColumnsLabel())
          .selectedOptionFontColor(this.accentColor)
          .selectedOptionBgColor(fieldSurfaceColor(this.displayMode, this.darkSurface))
          .onSelect((index: number): void => this.selectTimelineColumns(index))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
  }

  @Builder
  private AutoHideSwitchRow(title: Resource, detail: Resource, isOn: boolean,
    onChange: (value: boolean) => void, enabled: boolean = true): void {
    Row({ space: 14 }) {
      Column({ space: 4 }) {
        Text(title).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Subtitle_L'))
          .fontColor($r('app.color.text_primary'))
        Text(detail).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .selectedColor(this.accentColor)
        .enabled(enabled)
        .onChange((value: boolean): void => onChange(value))
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private CustomBottomBarSection(): void {
    Column({ space: 8 }) {
      Column({ space: 4 }) {
        Text($r('app.string.settings_custom_bottom_bar_title')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Title_S'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text($r('app.string.settings_custom_bottom_bar_desc')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('app.color.text_secondary'))
          .lineHeight(20)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      this.AutoHideSwitchRow($r('app.string.home_title'),
        $r('app.string.settings_custom_bottom_bar_page_desc'), this.isBottomBarPageEnabled(BOTTOM_BAR_HOME_PAGE),
        (value: boolean): void => this.setBottomBarPageEnabled(BOTTOM_BAR_HOME_PAGE, value),
        !this.bottomBarPageSwitchDisabled(BOTTOM_BAR_HOME_PAGE))
      this.AutoHideSwitchRow($r('app.string.explore_title'),
        $r('app.string.settings_custom_bottom_bar_page_desc'), this.isBottomBarPageEnabled(BOTTOM_BAR_EXPLORE_PAGE),
        (value: boolean): void => this.setBottomBarPageEnabled(BOTTOM_BAR_EXPLORE_PAGE, value),
        !this.bottomBarPageSwitchDisabled(BOTTOM_BAR_EXPLORE_PAGE))
      this.AutoHideSwitchRow($r('app.string.tab_alerts'),
        $r('app.string.settings_custom_bottom_bar_page_desc'),
        this.isBottomBarPageEnabled(BOTTOM_BAR_NOTIFICATIONS_PAGE),
        (value: boolean): void => this.setBottomBarPageEnabled(BOTTOM_BAR_NOTIFICATIONS_PAGE, value),
        !this.bottomBarPageSwitchDisabled(BOTTOM_BAR_NOTIFICATIONS_PAGE))
      this.AutoHideSwitchRow($r('app.string.messages_title'),
        $r('app.string.settings_custom_bottom_bar_page_desc'),
        this.isBottomBarPageEnabled(BOTTOM_BAR_MESSAGES_PAGE),
        (value: boolean): void => this.setBottomBarPageEnabled(BOTTOM_BAR_MESSAGES_PAGE, value),
        !this.bottomBarPageSwitchDisabled(BOTTOM_BAR_MESSAGES_PAGE))
      this.AutoHideSwitchRow($r('app.string.tab_me'),
        $r('app.string.settings_custom_bottom_bar_page_desc'), this.isBottomBarPageEnabled(BOTTOM_BAR_ME_PAGE),
        (value: boolean): void => this.setBottomBarPageEnabled(BOTTOM_BAR_ME_PAGE, value),
        !this.bottomBarPageSwitchDisabled(BOTTOM_BAR_ME_PAGE))
    }
    .width('100%')
  }

  // 显示设置 → 滚动自动隐藏。顶部标题栏交给 HdsNavigation 的
  // dynamicHideTitleBar，底部导航栏交给 HdsTabs 的隐藏动效。
  @Builder
  private AutoHideSection(): void {
    Column({ space: 12 }) {
      Column({ space: 4 }) {
        Text($r('app.string.settings_auto_hide_title')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Title_S'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text($r('app.string.settings_auto_hide_note')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('app.color.text_secondary'))
          .lineHeight(20)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      this.AutoHideSwitchRow($r('app.string.settings_auto_hide_title_bar'),
        $r('app.string.settings_auto_hide_title_bar_desc'), this.autoHideTitleBar,
        (value: boolean): void => this.setAutoHideTitleBar(value))
      this.AutoHideSwitchRow($r('app.string.settings_home_header_collapse'),
        $r('app.string.settings_home_header_collapse_desc'), this.homeHeaderCollapseEnabled,
        (value: boolean): void => this.setHomeHeaderCollapseEnabled(value))
      this.AutoHideSwitchRow($r('app.string.settings_auto_hide_tab_bar'),
        $r('app.string.settings_auto_hide_tab_bar_desc'), this.autoHideTabBar,
        (value: boolean): void => this.setAutoHideTabBar(value))
      this.AutoHideSwitchRow($r('app.string.settings_auto_hide_fab'),
        $r('app.string.settings_auto_hide_fab_desc'), this.autoHideFab,
        (value: boolean): void => this.setAutoHideFab(value))
    }
    .width('100%')
  }

  private interactionSaved(saved: boolean): void {
    if (!saved) { promptAction.showToast({ message: $r('app.string.settings_interaction_save_failed') }); }
  }

  private floatingActionIndex(): number {
    if (this.homeFloatingAction === HOME_FLOATING_REFRESH) { return 1; }
    if (this.homeFloatingAction === HOME_FLOATING_TOP) { return 2; }
    if (this.homeFloatingAction === HOME_FLOATING_HIDDEN) { return 3; }
    return 0;
  }

  private floatingActionLabel(): Resource {
    if (this.homeFloatingAction === HOME_FLOATING_REFRESH) { return $r('app.string.settings_floating_refresh'); }
    if (this.homeFloatingAction === HOME_FLOATING_TOP) { return $r('app.string.settings_floating_top'); }
    if (this.homeFloatingAction === HOME_FLOATING_HIDDEN) { return $r('app.string.settings_floating_hidden'); }
    return $r('app.string.settings_floating_compose');
  }

  @Builder
  private HomeInteractionSection(): void {
    Column({ space: 16 }) {
      Text($r('app.string.settings_home_interaction')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Title_S'))
        .fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
      Row({ space: 12 }) {
        Column({ space: 4 }) {
          Text($r('app.string.settings_floating_action')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L'))
            .fontColor($r('app.color.text_primary'))
          Text($r('app.string.settings_floating_action_desc')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
            .fontColor($r('app.color.text_secondary'))
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Select([
          { value: $r('app.string.settings_floating_compose') },
          { value: $r('app.string.settings_floating_refresh') },
          { value: $r('app.string.settings_floating_top') },
          { value: $r('app.string.settings_floating_hidden') }
        ]).selected(this.floatingActionIndex()).value(this.floatingActionLabel())
          .onSelect((index: number): void => {
            const actions: string[] = [HOME_FLOATING_COMPOSE, HOME_FLOATING_REFRESH, HOME_FLOATING_TOP, HOME_FLOATING_HIDDEN];
            this.interactionSaved(interactionSettingsStore.saveHomeFloatingAction(
              getContext(this) as common.UIAbilityContext, actions[index] ?? HOME_FLOATING_COMPOSE));
          })
      }.width('100%')
      this.AutoHideSwitchRow($r('app.string.settings_refresh_on_foreground'),
        $r('app.string.settings_refresh_on_foreground_desc'), this.refreshOnForeground,
        (value: boolean): void => { this.interactionSaved(interactionSettingsStore.saveRefreshOnForeground(
          getContext(this) as common.UIAbilityContext, value)); })
      this.AutoHideSwitchRow($r('app.string.settings_refresh_on_home_tab'),
        $r('app.string.settings_refresh_on_home_tab_desc'), this.refreshOnHomeTab,
        (value: boolean): void => { this.interactionSaved(interactionSettingsStore.saveRefreshOnHomeTab(
          getContext(this) as common.UIAbilityContext, value)); })
      this.AutoHideSwitchRow($r('app.string.settings_home_double_tap_latest'),
        $r('app.string.settings_home_double_tap_latest_desc'), this.homeDoubleTapLatest,
        (value: boolean): void => { this.interactionSaved(interactionSettingsStore.saveHomeDoubleTapLatest(
          getContext(this) as common.UIAbilityContext, value)); })
      this.AutoHideSwitchRow($r('app.string.settings_home_pull_refresh_latest'),
        $r('app.string.settings_home_pull_refresh_latest_desc'), this.homePullRefreshLatest,
        (value: boolean): void => { this.interactionSaved(interactionSettingsStore.saveHomePullRefreshLatest(
          getContext(this) as common.UIAbilityContext, value)); })
      this.AutoHideSwitchRow($r('app.string.settings_home_space_capsule'),
        $r('app.string.settings_home_space_capsule_desc'), this.homeSpaceCapsuleEnabled && !this.homeSpaceCapsuleHiddenForSession,
        (value: boolean): void => {
          if (!spacePreferencesStore.saveHomeCapsuleEnabled(getContext(this) as common.UIAbilityContext, value)) {
            promptAction.showToast({ message: this.text($r('app.string.spaces_save_failed')) });
          }
        })
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private ImmersiveTitleBarBlurSection(): void {
    Column({ space: 12 }) {
      this.AutoHideSwitchRow($r('app.string.settings_title_bar_logo'),
        $r('app.string.settings_title_bar_logo_desc'), this.titleBarLogoEnabled,
        (value: boolean): void => { this.titleBarLogoEnabled = value; this.saveAppearance(); })
      if (!this.titleBarLogoEnabled) {
        Row({ space: 12 }) {
          Column({ space: 4 }) {
            Text($r('app.string.settings_compact_switch_style')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Subtitle_L'))
              .fontColor($r('app.color.text_primary'))
            Text($r('app.string.settings_compact_switch_style_desc')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
              .fontColor($r('app.color.text_secondary'))
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          Select([
            { value: $r('app.string.settings_compact_switch_tabs') },
            { value: $r('app.string.settings_compact_switch_buttons') }
          ]).selected(this.compactSwitchStyle === COMPACT_SWITCH_BUTTONS ? 1 : 0)
            .value(this.compactSwitchStyle === COMPACT_SWITCH_BUTTONS ?
              $r('app.string.settings_compact_switch_buttons') : $r('app.string.settings_compact_switch_tabs'))
            .selectedOptionFontColor(this.accentColor)
            .selectedOptionBgColor(fieldSurfaceColor(this.displayMode, this.darkSurface))
            .id('settings-compact-switch-style')
            .onSelect((index: number): void => {
              this.compactSwitchStyle = index === 1 ? COMPACT_SWITCH_BUTTONS : COMPACT_SWITCH_TABS;
              this.saveAppearance();
            })
        }.width('100%').alignItems(VerticalAlign.Center)
      }
      Column({ space: 4 }) {
        Text($r('app.string.settings_immersive_title_bar_blur')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Title_S'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text($r('app.string.settings_immersive_title_bar_blur_note')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('app.color.text_secondary'))
          .lineHeight(20)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      Row({ space: 12 }) {
        Text($r('app.string.settings_immersive_title_bar_blur_switch')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Subtitle_L'))
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Select([
          { value: $r('app.string.settings_title_bar_style_immersive') },
          { value: $r('app.string.settings_title_bar_style_blur') },
          { value: $r('app.string.settings_title_bar_style_glass') }
        ])
          .selected(this.titleBarStyleIndex())
          .value(this.titleBarStyleLabel())
          .selectedOptionFontColor(this.accentColor)
          .selectedOptionBgColor(fieldSurfaceColor(this.displayMode, this.darkSurface))
          .onSelect((index: number): void => this.setTitleBarStyleMode(index))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      // 这个开关只在玻璃材质下出现，默认关闭：关闭状态下玻璃仍然跟着滚动做
      // 沉浸渐变，打开后只剩那块玻璃。
      if (this.isGlassTitleBarStyle()) {
        this.AutoHideSwitchRow($r('app.string.settings_title_bar_glass_blur_off'),
          $r('app.string.settings_title_bar_glass_blur_off_desc'), this.glassImmersiveBlurOff(),
          (value: boolean): void => this.setGlassImmersiveBlurOff(value))
        Row({ space: 12 }) {
          Column({ space: 4 }) {
            Text($r('app.string.settings_title_bar_glass_level_label')).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Subtitle_L'))
              .fontColor($r('app.color.text_primary'))
            Text($r('app.string.settings_title_bar_glass_level_desc')).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_M'))
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          Select([
            { value: $r('app.string.settings_title_bar_glass_level_ultra_thin') },
            { value: $r('app.string.settings_title_bar_glass_level_thin') },
            { value: $r('app.string.settings_title_bar_glass_level_regular') },
            { value: $r('app.string.settings_title_bar_glass_level_thick') },
            { value: $r('app.string.settings_title_bar_glass_level_ultra_thick') }
          ])
            .selected(this.titleBarGlassLevelIndex())
            .value(this.titleBarGlassLevelLabel())
            .selectedOptionFontColor(this.accentColor)
            .selectedOptionBgColor(fieldSurfaceColor(this.displayMode, this.darkSurface))
            .onSelect((index: number): void => this.setTitleBarGlassMaterialLevel(index))
        }
        .width('100%')
        .padding({ top: 12, bottom: 12 })
        .alignItems(VerticalAlign.Center)
      }
    }.width('100%')
  }

  @Builder
  private AppIconContent(): void {
    Column({ space: 0 }) {
      Text($r('app.string.settings_app_icon_intro')).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_L'))
        .lineHeight(23)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .padding({ left: 20, right: 20, top: 20, bottom: 10 })
      if (this.appIconSupported) {
        Text($r('app.string.settings_app_icon_note')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M'))
          .lineHeight(20)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
          .padding({ left: 20, right: 20, bottom: 14 })
      } else {
        Text($r('app.string.settings_app_icon_unsupported')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M'))
          .lineHeight(20)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
          .padding({ left: 20, right: 20, bottom: 14 })
      }
      // 中秋限时图标只在 9 月 25 日至 9 月 28 日出现，过期后这行提示
      // 和图标一起消失。
      if (isMidAutumnIconAvailable()) {
        Text($r('app.string.settings_app_icon_mid_autumn_note')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M'))
          .lineHeight(20)
          .fontColor($r('app.color.text_accent'))
          .width('100%')
          .padding({ left: 20, right: 20, bottom: 14 })
      }
      Divider()
        .color($r('app.color.divider'))
        .margin({ left: 20, right: 20 })
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
        this.AppIconTile(APP_ICON_DEFAULT, $r('app.string.settings_app_icon_default'),
          $r('app.media.app_icon'), false)
        ForEach(this.appIconOptions, (option: AppIconOption): void => {
          this.AppIconTile(option.name, option.label, option.preview, false)
        }, (option: AppIconOption): string => option.name)
        if (isMidAutumnIconAvailable()) {
          this.AppIconTile(APP_ICON_MID_AUTUMN, $r('app.string.settings_app_icon_mid_autumn'),
            $r('app.media.alt_icon_mid_autumn'), true)
        }
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 8, bottom: 24 })
      Divider()
        .color($r('app.color.divider'))
        .margin({ left: 20, right: 20 })
      Column({ space: 14 }) {
        Row({ space: 12 }) {
          Column({ space: 4 }) {
            Text($r('app.string.settings_app_icon_schedule_title')).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Subtitle_L'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
            Text($r('app.string.settings_app_icon_schedule_desc')).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_M'))
              .lineHeight(20)
              .fontColor($r('app.color.text_secondary'))
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          Toggle({ type: ToggleType.Switch, isOn: this.appIconScheduleEnabled })
            .enabled(this.appIconSupported && !this.appIconBusy)
            .onChange((enabled: boolean): void => this.changeAppIconScheduleEnabled(enabled))
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        if (this.appIconScheduleEnabled) {
          Row({ space: 12 }) {
            this.AppIconScheduleTimeButton($r('app.string.settings_app_icon_schedule_start'),
              this.appIconScheduleStartMinute, true)
            this.AppIconScheduleTimeButton($r('app.string.settings_app_icon_schedule_end'),
              this.appIconScheduleEndMinute, false)
          }
          .width('100%')
          Row({ space: 12 }) {
            Text($r('app.string.settings_app_icon_schedule_target')).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Subtitle_L'))
              .fontColor($r('app.color.text_primary'))
              .layoutWeight(1)
            Select([
              { value: $r('app.string.settings_app_icon_default') },
              { value: $r('app.string.settings_app_icon_classic') },
              { value: $r('app.string.settings_app_icon_spectrum') },
              { value: $r('app.string.settings_app_icon_outline') },
              { value: $r('app.string.settings_app_icon_brush') },
              { value: $r('app.string.settings_app_icon_blossom') },
              { value: $r('app.string.settings_app_icon_blue_bird') },
              { value: $r('app.string.settings_app_icon_twitter_blue') },
              { value: $r('app.string.settings_app_icon_twitter_white') },
              { value: $r('app.string.settings_app_icon_x_black') },
              { value: $r('app.string.settings_app_icon_x_white') },
              { value: $r('app.string.settings_app_icon_frog_white') },
              { value: $r('app.string.settings_app_icon_frog_black') },
              { value: $r('app.string.settings_app_icon_milk_frog_white') },
              { value: $r('app.string.settings_app_icon_milk_frog_black') }
            ])
              .selected(this.appIconScheduleIconIndex())
              .value(this.appIconScheduleIconLabel())
              .selectedOptionFontColor(this.accentColor)
              .selectedOptionBgColor(fieldSurfaceColor(this.displayMode, this.darkSurface))
              .enabled(!this.appIconBusy)
              .onSelect((index: number): void => this.changeAppIconScheduleTarget(index))
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          Text($r('app.string.settings_app_icon_schedule_background_note')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_S'))
            .lineHeight(19)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
        }
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16, bottom: 24 })
    }
    .width('100%')
  }

  @Builder
  private AppIconScheduleTimeButton(label: Resource, minute: number, isStart: boolean): void {
    Column({ space: 5 }) {
      Text(label).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_S'))
        .fontColor($r('app.color.text_secondary'))
      Text(this.appIconScheduleTimeLabel(minute)).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Subtitle_L'))
        .fontColor($r('app.color.text_primary'))
        .fontWeight(FontWeight.Medium)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 14, right: 14, top: 11, bottom: 11 })
    .backgroundColor(fieldSurfaceColor(this.displayMode, this.darkSurface))
    .borderRadius(12)
    .enabled(!this.appIconBusy)
    .onClick((): void => this.showAppIconScheduleTimePicker(isStart))
  }

  @Builder
  private AppIconTile(name: string, label: Resource, preview: Resource, limited: boolean): void {
    Column({ space: 8 }) {
      Stack({ alignContent: Alignment.BottomEnd }) {
        Image(preview)
          .width(72)
          .height(72)
          .borderRadius(20)
          .interpolation(ImageInterpolation.High)
        if (this.appIconSupported && this.isAppIconTileSelected(name)) {
          SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
            .fontSize(21)
            .fontColor([this.accentColor])
        }
      }
      .width(72)
      .height(72)
      if (limited) {
        Text($r('app.string.settings_app_icon_limited')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Caption_L'))
          .fontColor($r('app.color.text_on_accent'))
          .backgroundColor(this.accentColor)
          .borderRadius(6)
          .padding({ left: 6, right: 6, top: 1, bottom: 1 })
      }
      Text(label).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_S'))
        .fontColor(this.appIconSupported && this.isAppIconTileSelected(name) ? this.accentColor :
          $r('app.color.text_secondary'))
        .width('100%')
        .textAlign(TextAlign.Center)
    }
    .width('33.3%')
    .padding({ top: 10, bottom: 14 })
    // 低版本系统只做展示：置灰、不显示选中态，点按给出升级提示。
    .opacity(this.appIconSupported ? 1 : 0.38)
    .onClick((): void => this.selectAppIcon(name))
  }

  @Builder
  private DisplayContent(): void {
    Column({ space: 18 }) {
      Text($r('app.string.settings_display_intro')).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_L'))
        .lineHeight(23)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
      Row({ space: 10 }) {
        this.DisplayModeOption(DISPLAY_MODE_SYSTEM, $r('sys.symbol.phone'), $r('app.string.settings_theme_system'))
        this.DisplayModeOption(DISPLAY_MODE_LIGHT, $r('sys.symbol.sun_max'), $r('app.string.settings_theme_light'))
        this.DisplayModeOption(DISPLAY_MODE_DARK, $r('sys.symbol.moon'), $r('app.string.settings_theme_dark'))
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      if (this.displayMode === DISPLAY_MODE_DARK) {
        Column({ space: 8 }) {
          Text($r('app.string.settings_dark_surface_title')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Title_S'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .width('100%')
          Text($r('app.string.settings_dark_surface_desc')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M'))
            .lineHeight(20)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
          this.DarkSurfaceOption(DARK_SURFACE_BLACK, $r('app.string.settings_dark_surface_black'), '#000000')
          this.DarkSurfaceOption(DARK_SURFACE_GENTLE, $r('app.string.settings_dark_surface_gentle'),
            $r('app.color.gentle_bg_page'))
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      this.AutoHideSwitchRow($r('app.string.settings_avatar_tint'),
        $r('app.string.settings_avatar_tint_desc'), this.avatarTintEnabled,
        (value: boolean): void => this.setAvatarTintEnabled(value))
      Text($r('app.string.settings_theme_color')).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Title_S'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
        this.AccentOption('#007DFF', $r('app.color.theme_system_blue'),
          $r('app.string.settings_theme_system_blue'))
        this.AccentOption('#1D9BF0', $r('app.color.theme_x_blue'),
          $r('app.string.settings_theme_x_blue'))
        this.AccentOption('#F7B500', $r('app.color.theme_yellow'),
          $r('app.string.settings_theme_yellow'))
        this.AccentOption('#F91880', $r('app.color.theme_pink'),
          $r('app.string.settings_theme_pink'))
        this.AccentOption('#7856FF', $r('app.color.theme_purple'),
          $r('app.string.settings_theme_purple'))
        this.AccentOption('#FF7A00', $r('app.color.theme_orange'),
          $r('app.string.settings_theme_orange'))
        this.AccentOption('#00BA7C', $r('app.color.theme_green'),
          $r('app.string.settings_theme_green'))
        this.AccentOption('#345483', $r('app.color.theme_cat_blue'),
          $r('app.string.settings_theme_cat_blue'))
        this.AccentOption('#D8333A', $r('app.color.theme_huawei_red'),
          $r('app.string.settings_theme_huawei_red'))
      }
      .width('100%')

    }.width('100%').padding({ left: 20, right: 20, top: 16, bottom: 28 })
  }

  @Builder
  private DesktopLayoutSection(): void {
    Column({ space: 10 }) {
      Text($r('app.string.settings_desktop_layout')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Title_S'))
        .fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
      Text($r('app.string.settings_desktop_layout_desc')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
        .fontColor($r('app.color.text_secondary')).lineHeight(20)
      Row({ space: 12 }) {
        this.LayoutOption(false, $r('app.string.settings_layout_current'))
        this.LayoutOption(true, $r('app.string.settings_layout_desktop'))
      }.width('100%')
      Column({ space: 8 }) {
        Text($r('app.string.settings_desktop_video_layout')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Subtitle_L')).fontColor($r('app.color.text_primary'))
        Text($r('app.string.settings_desktop_video_layout_desc')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary'))
        Select([
          { value: $r('app.string.settings_desktop_video_split') },
          { value: $r('app.string.settings_desktop_video_feed') }
        ]).selected(this.desktopVideoLayout)
          .value(this.desktopVideoLayout === DESKTOP_VIDEO_LAYOUT_FEED ?
            $r('app.string.settings_desktop_video_feed') : $r('app.string.settings_desktop_video_split'))
          .onSelect((index: number): void => {
            if (!layoutSettingsStore.saveDesktopVideoLayout(getContext(this) as common.UIAbilityContext, index)) {
              promptAction.showToast({ message: this.text($r('app.string.settings_layout_save_failed')) });
            }
          })
      }.width('100%').alignItems(HorizontalAlign.Start).padding({ top: 12, bottom: 12 })
        .id('settings-desktop-video-layout')
      Column() {
        this.AutoHideSwitchRow($r('app.string.settings_desktop_aside'),
          $r('app.string.settings_desktop_aside_desc'), this.desktopAsideEnabled,
          (value: boolean): void => {
            if (!layoutSettingsStore.saveAsideEnabled(getContext(this) as common.UIAbilityContext, value)) {
              promptAction.showToast({ message: this.text($r('app.string.settings_layout_save_failed')) });
            }
          }, this.desktopLayoutEnabled)
      }.width('100%').id('settings-desktop-aside')
      Column() {
        this.AutoHideSwitchRow($r('app.string.settings_desktop_rail_auto_hide'),
          $r('app.string.settings_desktop_rail_auto_hide_desc'), this.desktopRailAutoHide,
          (value: boolean): void => {
            if (!layoutSettingsStore.saveRailAutoHide(getContext(this) as common.UIAbilityContext, value)) {
              promptAction.showToast({ message: this.text($r('app.string.settings_layout_save_failed')) });
            }
          }, this.desktopLayoutEnabled)
      }.width('100%').id('settings-desktop-rail-auto-hide')
      Column() {
        this.AutoHideSwitchRow($r('app.string.sidebar_swipe'), $r('app.string.sidebar_swipe_desc'),
          this.desktopRailSwipe, (value: boolean): void => {
            if (!layoutSettingsStore.saveRailSwipe(getContext(this) as common.UIAbilityContext, value)) {
              promptAction.showToast({ message: this.text($r('app.string.settings_layout_save_failed')) });
            }
          }, this.desktopLayoutEnabled && this.desktopRailAutoHide)
      }.width('100%').id('settings-desktop-rail-swipe')
      Button({ type: ButtonType.Normal }) {
        Row({ space: 12 }) {
          Column({ space: 4 }) {
            Text($r('app.string.sidebar_handle_style')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Subtitle_L'))
              .fontColor($r('app.color.text_primary'))
            Text($r('app.string.sidebar_handle_style_desc')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
              .fontColor($r('app.color.text_secondary'))
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(20).fontColor([$r('app.color.text_secondary')])
        }.width('100%')
      }.width('100%').padding({ top: 12, bottom: 12 }).backgroundColor(Color.Transparent)
        .id('settings-sidebar-handle-style').onClick((): void => { this.pageStack.pushPath({ name: 'SidebarHandleSettings' }); })
    }.width('100%').alignItems(HorizontalAlign.Start).id('settings-desktop-layout')
  }

  @Builder
  private SidebarMaterialSection(): void {
      if (SystemMaterialUtil.isApi26OrAbove()) {
        Row({ space: 12 }) {
          Text($r('app.string.sidebar_material_type')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Subtitle_L'))
            .fontColor($r('app.color.text_primary')).layoutWeight(1)
          Select([{ value: $r('app.string.sidebar_material_glass') }, { value: $r('app.string.sidebar_material_blur') }])
            .selected(this.sidebarMaterialType)
            .value(this.sidebarMaterialType === SIDEBAR_MATERIAL_GLASS ?
              $r('app.string.sidebar_material_glass') : $r('app.string.sidebar_material_blur'))
            .onSelect((index: number): void => {
              if (!layoutSettingsStore.saveSidebarMaterialType(getContext(this) as common.UIAbilityContext, index)) {
                promptAction.showToast({ message: this.text($r('app.string.settings_layout_save_failed')) });
              }
            })
        }.width('100%').padding({ top: 12, bottom: 12 }).id('settings-sidebar-material-type')
      }
      Row({ space: 12 }) {
        Column({ space: 4 }) {
          Text($r('app.string.settings_desktop_rail_material')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Subtitle_L')).fontColor($r('app.color.text_primary'))
          Text($r('app.string.settings_desktop_rail_material_desc')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary'))
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Select([
          { value: $r('app.string.chat_off') },
          { value: $r('app.string.settings_title_bar_glass_level_ultra_thin') },
          { value: $r('app.string.settings_title_bar_glass_level_thin') },
          { value: $r('app.string.settings_title_bar_glass_level_regular') },
          { value: $r('app.string.settings_title_bar_glass_level_thick') },
          { value: $r('app.string.settings_title_bar_glass_level_ultra_thick') }
        ]).selected(this.desktopRailMaterialLevel + 1).value(this.desktopRailMaterialLabel())
          .selectedOptionFontColor(this.accentColor)
          .selectedOptionBgColor(fieldSurfaceColor(this.displayMode, this.darkSurface))
          .onSelect((index: number): void => {
            if (!layoutSettingsStore.saveRailMaterialLevel(getContext(this) as common.UIAbilityContext, index - 1)) {
              promptAction.showToast({ message: this.text($r('app.string.settings_layout_save_failed')) });
            }
          })
      }.width('100%').padding({ top: 12, bottom: 12 })
        .id('settings-desktop-rail-material')
  }

  @Builder
  private LayoutOption(desktop: boolean, title: Resource): void {
    Button(title).layoutWeight(1).height(48).borderRadius(12)
      .fontColor(this.desktopLayoutEnabled === desktop ? this.accentColor : $r('app.color.text_primary'))
      .backgroundColor(Color.Transparent)
      .border({ width: this.desktopLayoutEnabled === desktop ? 2 : 1,
        color: this.desktopLayoutEnabled === desktop ? this.accentColor : $r('app.color.divider') })
      .id(desktop ? 'layout-desktop' : 'layout-current')
      .onClick((): void => {
        if (!layoutSettingsStore.save(getContext(this) as common.UIAbilityContext, desktop)) {
          promptAction.showToast({ message: this.text($r('app.string.settings_layout_save_failed')) });
        }
      })
  }

  private desktopRailMaterialLabel(): Resource {
    if (this.desktopRailMaterialLevel < 0) { return $r('app.string.chat_off'); }
    const labels: Resource[] = [
      $r('app.string.settings_title_bar_glass_level_ultra_thin'), $r('app.string.settings_title_bar_glass_level_thin'),
      $r('app.string.settings_title_bar_glass_level_regular'), $r('app.string.settings_title_bar_glass_level_thick'),
      $r('app.string.settings_title_bar_glass_level_ultra_thick')
    ];
    return labels[this.desktopRailMaterialLevel];
  }

  @Builder
  private SheetMaterialSection(): void {
    Column({ space: 12 }) {
      Row({ space: 12 }) {
        Column({ space: 4 }) {
          Text($r('app.string.settings_sheet_material_title')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Title_S'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text($r('app.string.settings_sheet_material_desc')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('app.color.text_secondary'))
            .lineHeight(20)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Toggle({ type: ToggleType.Switch, isOn: this.sheetMaterialEnabled })
          .id('sheetMaterialToggle')
          .selectedColor(this.accentColor)
          .onChange((enabled: boolean): void => this.saveSheetMaterial(enabled, this.sheetMaterialLevel))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      if (!deviceInfo.apiAvailable('26.0.0')) {
        Text($r('app.string.settings_sheet_material_unavailable')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
      }
      if (this.sheetMaterialEnabled) {
        Row({ space: 12 }) {
          Text($r('app.string.settings_sheet_material_level')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Subtitle_L'))
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
          Select([
            { value: $r('app.string.settings_title_bar_glass_level_ultra_thin') },
            { value: $r('app.string.settings_title_bar_glass_level_thin') },
            { value: $r('app.string.settings_title_bar_glass_level_regular') },
            { value: $r('app.string.settings_title_bar_glass_level_thick') },
            { value: $r('app.string.settings_title_bar_glass_level_ultra_thick') }
          ])
            .id('sheetMaterialLevel')
            .selected(this.sheetMaterialLevel)
            .value(this.sheetMaterialLevelLabel())
            .selectedOptionFontColor(this.accentColor)
            .selectedOptionBgColor(fieldSurfaceColor(this.displayMode, this.darkSurface))
            .onSelect((index: number): void => this.saveSheetMaterial(true, index))
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
    }
    .width('100%')
  }

  @Builder
  private HdsTabsMaterialSection(): void {
    Column({ space: 12 }) {
      Column({ space: 4 }) {
        Text($r('app.string.settings_hds_tabs_material_title')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Title_S'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text($r('app.string.settings_hds_tabs_material_note')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('app.color.text_secondary'))
          .lineHeight(20)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      Row({ space: 12 }) {
        Text($r('app.string.settings_hds_tabs_material_label')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Subtitle_L'))
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Select([
          { value: $r('app.string.settings_hds_tabs_material_exquisite') },
          { value: $r('app.string.settings_hds_tabs_material_gentle') },
          { value: $r('app.string.settings_hds_tabs_material_smooth') },
          { value: $r('app.string.settings_hds_tabs_material_adaptive') }
        ])
          .selected(this.homeTabMaterialIndex())
          .value(this.homeTabMaterialLabel())
          .enabled(!this.classicBottomBar)
          .selectedOptionFontColor(this.accentColor)
          .selectedOptionBgColor(fieldSurfaceColor(this.displayMode, this.darkSurface))
          .onSelect((index: number): void => this.selectHomeTabMaterial(index))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
  }

  @Builder
  private BackgroundPlaybackOption(mode: number, title: Resource, detail: Resource): void {
    Row({ space: 14 }) {
      Column({ space: 4 }) {
        Text(title).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Subtitle_L'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Text(detail).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      if (this.videoBackgroundMode === mode) {
        SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
          .fontSize(23)
          .fontColor([this.accentColor])
      }
    }
    .width('100%')
    .padding({ top: 15, bottom: 15, left: 20, right: 20 })
    .backgroundColor(this.videoBackgroundMode === mode ?
      fieldSurfaceColor(this.displayMode, this.darkSurface) : Color.Transparent)
    .onClick((): void => this.setVideoBackgroundMode(mode))
  }

  @Builder
  private ImageQualityOption(value: number, title: Resource, detail: Resource): void {
    Row({ space: 14 }) {
      Column({ space: 4 }) {
        Text(title).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Subtitle_L'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Text(detail).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      if (this.imageQuality === value) {
        SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
          .fontSize(23)
          .fontColor([this.accentColor])
      }
    }
    .width('100%')
    .padding({ top: 15, bottom: 15, left: 20, right: 20 })
    .backgroundColor(this.imageQuality === value ?
      fieldSurfaceColor(this.displayMode, this.darkSurface) : Color.Transparent)
    .onClick((): void => this.setImageQuality(value))
  }

  @Builder
  private VideoQualityOption(value: number, title: Resource, detail: Resource): void {
    Row({ space: 14 }) {
      Column({ space: 4 }) {
        Text(title).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Subtitle_L'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Text(detail).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      if (this.videoQuality === value) {
        SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
          .fontSize(23)
          .fontColor([this.accentColor])
      }
    }
    .width('100%')
    .padding({ top: 15, bottom: 15, left: 20, right: 20 })
    .backgroundColor(this.videoQuality === value ?
      fieldSurfaceColor(this.displayMode, this.darkSurface) : Color.Transparent)
    .onClick((): void => this.setVideoQuality(value))
  }

  @Builder
  private FontsContent(): void {
    Column({ space: 18 }) {
      this.FontSizeSection()
      Divider().color($r('app.color.divider'))
      this.AppFontSection()
      if (this.appFontName.length === 0) {
        this.ContentFontSection()
      }
      Divider().color($r('app.color.divider'))
      this.AutoHideSwitchRow($r('app.string.settings_system_emoji'),
        $r('app.string.settings_system_emoji_desc'), this.systemEmojiEnabled,
        (value: boolean): void => this.setSystemEmojiEnabled(value))
    }.width('100%').padding({ left: 20, right: 20, top: 16, bottom: 28 })
  }

  @Builder
  private NavigationContent(): void {
    Column({ space: 18 }) {
      this.AutoHideSwitchRow($r('app.string.settings_classic_bottom_bar'),
        $r('app.string.settings_classic_bottom_bar_desc'), this.classicBottomBar,
        (value: boolean): void => this.setClassicBottomBar(value))
      this.AutoHideSwitchRow($r('app.string.settings_root_tab_labels'),
        $r('app.string.settings_root_tab_labels_desc'), this.rootTabLabelsVisible,
        (value: boolean): void => this.setRootTabLabelsVisible(value))
      Divider().color($r('app.color.divider'))
      this.CustomBottomBarSection()
      Divider().color($r('app.color.divider'))
      this.AutoHideSwitchRow($r('app.string.settings_compose_button'),
        $r('app.string.settings_compose_button_desc'), this.composeButtonEnabled,
        (value: boolean): void => this.setComposeButtonEnabled(value))
      Divider().color($r('app.color.divider'))
      this.AutoHideSection()
    }.width('100%').padding({ left: 20, right: 20, top: 16, bottom: 28 })
  }

  @Builder
  private ReplyMaterialSection(): void {
    Column({ space: 18 }) {
      Row({ space: 12 }) {
        Column({ space: 4 }) {
          Text($r('app.string.settings_reply_capsule_material_level_label')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Subtitle_L'))
            .fontColor($r('app.color.text_primary'))
          Text($r('app.string.settings_reply_capsule_material_level_desc')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Select([
          { value: $r('app.string.settings_title_bar_glass_level_ultra_thin') },
          { value: $r('app.string.settings_title_bar_glass_level_thin') },
          { value: $r('app.string.settings_title_bar_glass_level_regular') },
          { value: $r('app.string.settings_title_bar_glass_level_thick') },
          { value: $r('app.string.settings_title_bar_glass_level_ultra_thick') }
        ])
          .selected(this.replyCapsuleMaterialLevel)
          .value(this.replyCapsuleMaterialLevelLabel())
          .selectedOptionFontColor(this.accentColor)
          .selectedOptionBgColor(fieldSurfaceColor(this.displayMode, this.darkSurface))
          .onSelect((index: number): void => this.setReplyCapsuleMaterialLevel(index))
      }
      .width('100%')
      .padding({ top: 12, bottom: 12 })
      .alignItems(VerticalAlign.Center)
      this.AutoHideSwitchRow($r('app.string.settings_reply_capsule_button_material'),
        $r('app.string.settings_reply_capsule_button_material_desc'), this.replyCapsuleButtonMaterialEnabled,
        (value: boolean): void => this.setReplyCapsuleButtonMaterialEnabled(value),
        deviceInfo.apiAvailable('26.0.0'))

    }.width('100%').padding({ left: 20, right: 20, top: 16, bottom: 28 })
  }

  @Builder
  private LayoutContent(): void {
    Column({ space: 18 }) {
      this.DesktopLayoutSection()
      Divider().color($r('app.color.divider'))
      this.TimelineColumnsSection()
    }.width('100%').padding({ left: 20, right: 20, top: 16, bottom: 28 })
  }

  @Builder
  private FeedContent(): void {
    Column() {
      Text($r('app.string.settings_default_feed')).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Title_S'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .padding({ left: 20, right: 20, top: 20, bottom: 4 })
      Text($r('app.string.settings_default_feed_desc')).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .padding({ left: 20, right: 20, bottom: 8 })
      this.HomeFeedOption(HOME_FEED_FOR_YOU, $r('app.string.home_for_you'),
        $r('app.string.settings_default_feed_for_you_desc'))
      this.HomeFeedOption(HOME_FEED_FOLLOWING, $r('app.string.home_following'),
        $r('app.string.settings_default_feed_following_desc'))

    }.width('100%')
  }

  @Builder
  private PhotosContent(): void {
    Column({ space: 18 }) {
      this.AutoHideSwitchRow($r('app.string.settings_photo_fullscreen'),
        $r('app.string.settings_photo_fullscreen_desc'), this.photoFullscreen,
        (value: boolean): void => { this.interactionSaved(interactionSettingsStore.savePhotoFullscreen(
          getContext(this) as common.UIAbilityContext, value)); })
    }.width('100%').padding({ left: 20, right: 20, top: 16, bottom: 28 })
  }

  @Builder
  private ViewerContent(): void {
    Column({ space: 0 }) {
      this.AutoHideSwitchRow($r('app.string.settings_media_black_background'),
        $r('app.string.settings_media_black_background_desc'), this.mediaViewerBlackBackground,
        (value: boolean): void => this.setMediaViewerBlackBackground(value))
      this.AutoHideSwitchRow($r('app.string.settings_media_comment_background'),
        $r('app.string.settings_media_comment_background_desc'), this.mediaCommentBackground,
        (value: boolean): void => this.setMediaCommentBackground(value))
      this.AutoHideSwitchRow($r('app.string.settings_video_comment_progress_ring'),
        $r('app.string.settings_video_comment_progress_ring_desc'), this.videoCommentProgressRing,
        (value: boolean): void => this.setVideoCommentProgressRing(value))
    }.width('100%').padding({ left: 20, right: 20, top: 16, bottom: 28 })
  }

  @Builder
  private PlaybackContent(): void {
    Column() {
      Column() {
      this.AutoHideSwitchRow($r('app.string.settings_video_autoplay'),
        $r('app.string.settings_video_autoplay_desc'), this.videoAutoplay,
        (value: boolean): void => this.setVideoAutoplay(value))
      this.AutoHideSwitchRow($r('app.string.settings_home_video_mute'),
        $r('app.string.settings_home_video_mute_desc'), this.homeVideoMuted,
        (value: boolean): void => this.setHomeVideoMuted(value))
      this.AutoHideSwitchRow($r('app.string.settings_video_auto_pip'),
        $r('app.string.settings_video_auto_pip_desc'), this.videoAutoPip,
        (value: boolean): void => this.setVideoAutoPip(value))
      }.width('100%').padding({ left: 20, right: 20 })
      Column({ space: 4 }) {
        Text($r('app.string.settings_video_background')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Title_S'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text($r('app.string.settings_video_background_intro')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('app.color.text_secondary'))
          .lineHeight(20)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 20, right: 20, bottom: 4 })
      this.BackgroundPlaybackOption(VIDEO_BACKGROUND_AUDIO,
        $r('app.string.settings_video_background_audio'),
        $r('app.string.settings_video_background_audio_desc'))
      this.BackgroundPlaybackOption(VIDEO_BACKGROUND_PIP,
        $r('app.string.settings_video_background_pip'),
        $r('app.string.settings_video_background_pip_desc'))

    }.width('100%')
  }

  @Builder
  private VideoControlsContent(): void {
    Column() {
      Row({ space: 14 }) {
        Column({ space: 4 }) {
          Text($r('app.string.settings_video_immersive_fill')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Subtitle_L'))
            .fontColor($r('app.color.text_primary'))
          Text($r('app.string.settings_video_immersive_fill_desc')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Toggle({ type: ToggleType.Switch, isOn: this.videoImmersiveFill })
          .selectedColor(this.accentColor)
          .onChange((value: boolean): void => this.setVideoImmersiveFill(value))
      }
      .width('100%')
      .padding({ top: 16, bottom: 16, left: 20, right: 20 })
      Row({ space: 14 }) {
        Column({ space: 4 }) {
          Text($r('app.string.settings_video_hold_speed')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Subtitle_L'))
            .fontColor($r('app.color.text_primary'))
          Text($r('app.string.settings_video_hold_speed_desc')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Toggle({ type: ToggleType.Switch, isOn: this.videoHoldSpeed })
          .selectedColor(this.accentColor)
          .onChange((value: boolean): void => this.setVideoHoldSpeed(value))
      }
      .width('100%')
      .padding({ top: 0, bottom: 16, left: 20, right: 20 })
      Row({ space: 14 }) {
        Column({ space: 4 }) {
          Text($r('app.string.settings_video_feed_tap_pause')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Subtitle_L')).fontColor($r('app.color.text_primary'))
          Text($r('app.string.settings_video_feed_tap_pause_desc')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary')).width('100%')
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Toggle({ type: ToggleType.Switch, isOn: this.videoFeedTapPause })
          .selectedColor(this.accentColor)
          .onChange((value: boolean): void => this.setVideoFeedTapPause(value))
      }.width('100%').padding({ top: 0, bottom: 16, left: 20, right: 20 })
      // The system caption component only reads the panel opacity while it is
      // being created, so this value is stored and replayed on every rebuild.
      Column({ space: 10 }) {
        Row({ space: 12 }) {
          Text($r('app.string.video_feed_caption_background')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Subtitle_L'))
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
          Text(Math.round(this.captionOpacity * 100).toString() + '%').fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        Slider({
          value: this.captionOpacity * 100,
          min: 0,
          max: 100,
          step: 5,
          style: SliderStyle.InSet
        })
          .width('100%')
          .selectedColor(this.accentColor)
          .showTips(true)
          .onChange((value: number, mode: SliderChangeMode): void => {
            if (mode === SliderChangeMode.Begin || mode === SliderChangeMode.Moving) {
              return;
            }
            this.setCaptionOpacity(value / 100);
          })
      }
      .width('100%')
      .padding({ left: 20, right: 20, bottom: 16 })

    }.width('100%')
  }

  @Builder
  private QualityContent(): void {
    Column() {
      Text($r('app.string.settings_image_quality')).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Title_S'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .padding({ left: 20, right: 20, bottom: 4 })
      this.ImageQualityOption(IMAGE_QUALITY_DATA_SAVER, $r('app.string.settings_quality_data_saver'),
        $r('app.string.settings_image_quality_data_saver_desc'))
      this.ImageQualityOption(IMAGE_QUALITY_HIGH, $r('app.string.settings_quality_high'),
        $r('app.string.settings_image_quality_high_desc'))
      this.ImageQualityOption(IMAGE_QUALITY_ORIGINAL, $r('app.string.settings_quality_original'),
        $r('app.string.settings_image_quality_original_desc'))
      Divider()
        .color($r('app.color.divider'))
        .margin({ left: 20, right: 20, top: 8, bottom: 18 })
      Text($r('app.string.settings_video_quality')).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Title_S'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .padding({ left: 20, right: 20, bottom: 4 })
      this.VideoQualityOption(VIDEO_QUALITY_DATA_SAVER, $r('app.string.settings_quality_auto'),
        $r('app.string.settings_video_quality_auto_desc'))
      this.VideoQualityOption(VIDEO_QUALITY_HIGH, $r('app.string.settings_quality_hd'),
        $r('app.string.settings_video_quality_high_desc'))
      this.VideoQualityOption(VIDEO_QUALITY_SD, $r('app.string.settings_quality_sd'),
        $r('app.string.settings_video_quality_sd_desc'))
      this.VideoQualityOption(VIDEO_QUALITY_LD, $r('app.string.settings_quality_ld'),
        $r('app.string.settings_video_quality_ld_desc'))

    }.width('100%')
  }

  @Builder
  private AlertsContent(): void {
    Column() {
        this.SettingsSwitchRow($r('app.string.settings_push'), $r('app.string.settings_push_desc'),
          this.notificationAlertsEnabled, (value: boolean): void => this.setNotificationAlertsEnabled(value))
        this.SettingsSwitchRow($r('app.string.settings_system_notifications'),
          $r('app.string.settings_system_notifications_desc'), this.systemNotificationsEnabled,
          (value: boolean): void => this.setSystemNotificationsEnabled(value))
        this.SettingsSwitchRow($r('app.string.settings_notification_dnd_silent'),
          $r('app.string.settings_notification_dnd_silent_desc'), this.notificationDndSilent,
          (value: boolean): void => this.setNotificationDndSilent(value))
        this.SimpleItem($r('app.string.settings_notification_system_settings'),
          $r('app.string.settings_notification_system_settings_desc'),
          (): void => this.openNotificationSystemSettings())

    }.width('100%')
  }

  @Builder
  private AccessibilityContent(): void {
    Row({ space: 14 }) {
      Column({ space: 4 }) {
        Text($r('app.string.settings_grip_hand')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Subtitle_L'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Text($r('app.string.settings_grip_hand_desc')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Toggle({ type: ToggleType.Switch, isOn: this.gripHandEnabled })
        .selectedColor(this.accentColor)
        .onChange((value: boolean): void => this.setGripHandEnabled(value))
    }
    .width('100%')
    .padding({ top: 16, bottom: 16, left: 20, right: 20 })
    if (this.gripHandEnabled) {
    Row({ space: 14 }) {
      Column({ space: 4 }) {
        Text($r('app.string.settings_grip_hand_preference')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Subtitle_L'))
          .fontColor($r('app.color.text_primary'))
        Text($r('app.string.settings_grip_hand_preference_desc')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Select([
        { value: $r('app.string.settings_grip_hand_right') },
        { value: $r('app.string.settings_grip_hand_left') }
      ])
        .selected(this.gripPreferredHand === 'left' ? 1 : 0)
        .value(this.gripPreferredHand === 'left' ?
          $r('app.string.settings_grip_hand_left') : $r('app.string.settings_grip_hand_right'))
        .onSelect((index: number): void => this.setGripPreferredHand(index))
    }
    .width('100%')
    .padding({ top: 8, bottom: 16, left: 20, right: 20 })
    }
    Row({ space: 14 }) {
      Column({ space: 4 }) {
        Text($r('app.string.settings_link_in_app')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Subtitle_L'))
          .fontColor($r('app.color.text_primary'))
        Text($r('app.string.settings_link_in_app_desc')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Toggle({ type: ToggleType.Switch, isOn: this.linkInApp })
        .selectedColor(this.accentColor)
        .onChange((value: boolean): void => this.setLinkInApp(value))
    }
    .width('100%')
    .padding({ top: 16, bottom: 16, left: 20, right: 20 })

    Column() {
      this.AutoHideSwitchRow($r('app.string.settings_press_effect'),
        $r('app.string.settings_press_effect_desc'), this.pressEffectEnabled,
        (value: boolean): void => this.setPressEffectEnabled(value))
      this.AutoHideSwitchRow($r('app.string.settings_read_aloud_entry'),
        $r('app.string.settings_read_aloud_entry_desc'), this.readAloudEntryEnabled,
        (value: boolean): void => this.setReadAloudEntryEnabled(value))
    }.width('100%').padding({ left: 20, right: 20 })
  }

  @Builder
  private LanguageOption(language: string, title: Resource, detail?: Resource): void {
    Row({ space: 14 }) {
      Column({ space: 4 }) {
        Text(title).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Subtitle_L'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        if (detail !== undefined) {
          Text(detail).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('app.color.text_secondary'))
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      if (this.appLanguage === language) {
        SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
          .fontSize(23)
          .fontColor([this.accentColor])
      }
    }
    .width('100%')
    .padding({ top: 18, bottom: 18, left: 20, right: 20 })
    .onClick((): void => this.selectLanguage(language))
  }

  @Builder
  private LanguageContent(): void {
    Column({ space: 0 }) {
      Text($r('app.string.settings_language_intro')).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_L'))
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .padding({ left: 20, right: 20, top: 20, bottom: 8 })
      this.LanguageOption(APP_LANGUAGE_SYSTEM, $r('app.string.settings_language_system'),
        $r('app.string.settings_language_system_desc'))
      ForEach(supportedAppLanguages(), (language: AppLanguageOption): void => {
        Divider().color($r('app.color.divider'))
        this.LanguageOption(language.tag, language.name)
      }, (language: AppLanguageOption): string => language.tag)
    }
    .width('100%')
  }

  @Builder
  private ProviderChip(provider: TranslationProvider): void {
    Row({ space: 6 }) {
      Text(provider.name).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_M'))
        .fontColor(this.translationProviderId === provider.id ?
          $r('app.color.text_on_accent') : $r('app.color.text_primary'))
      if (this.translationProviderId === provider.id) {
        SymbolGlyph($r('sys.symbol.checkmark'))
          .fontSize(12)
          .fontColor([$r('app.color.text_on_accent')])
      }
    }
    .padding({ left: 14, right: 14, top: 9, bottom: 9 })
    .backgroundColor(this.translationProviderId === provider.id ? this.accentColor :
      fieldSurfaceColor(this.displayMode, this.darkSurface))
    .borderRadius(18)
    .margin({ right: 8, bottom: 8 })
    .onClick((): void => {
      this.translationProviderId = provider.id;
      // Preset models differ per vendor, so clear the previous choice.
      this.translationModel = '';
    })
  }

  @Builder
  private TranslationModeChip(id: string, label: Resource): void {
    Text(label).fontFamily(this.appFontFamily)
      .fontSize($r('sys.float.Body_M'))
      .fontColor(this.translationMode === id ? $r('app.color.text_on_accent') : $r('app.color.text_primary'))
      .padding({ left: 14, right: 14, top: 9, bottom: 9 })
      .backgroundColor(this.translationMode === id ? this.accentColor :
        fieldSurfaceColor(this.displayMode, this.darkSurface))
      .borderRadius(18)
      .margin({ right: 8, bottom: 8 })
      .onClick((): void => {
        this.translationMode = id;
      })
  }

  @Builder
  private GrokModeChip(id: string, label: Resource): void {
    Text(label).fontFamily(this.appFontFamily)
      .fontSize($r('sys.float.Body_M'))
      .fontColor(this.grokMode === id ? $r('app.color.text_on_accent') : $r('app.color.text_primary'))
      .padding({ left: 14, right: 14, top: 9, bottom: 9 })
      .backgroundColor(this.grokMode === id ? this.accentColor :
        fieldSurfaceColor(this.displayMode, this.darkSurface))
      .borderRadius(18)
      .margin({ right: 8 })
      .onClick((): void => {
        this.selectGrokMode(id);
      })
  }

  @Builder
  private TargetChip(id: string, label: Resource): void {
    Text(label).fontFamily(this.appFontFamily)
      .fontSize($r('sys.float.Body_M'))
      .fontColor(this.translationTarget === id ? $r('app.color.text_on_accent') : $r('app.color.text_primary'))
      .padding({ left: 14, right: 14, top: 9, bottom: 9 })
      .backgroundColor(this.translationTarget === id ? this.accentColor :
        fieldSurfaceColor(this.displayMode, this.darkSurface))
      .borderRadius(18)
      .margin({ right: 8, bottom: 8 })
      .onClick((): void => {
        this.translationTarget = id;
      })
  }

  @Builder
  private SourceChip(id: string, label: Resource): void {
    Text(label).fontFamily(this.appFontFamily)
      .fontSize($r('sys.float.Body_M'))
      .fontColor(this.translationSource === id ? $r('app.color.text_on_accent') : $r('app.color.text_primary'))
      .padding({ left: 14, right: 14, top: 9, bottom: 9 })
      .backgroundColor(this.translationSource === id ? this.accentColor :
        fieldSurfaceColor(this.displayMode, this.darkSurface))
      .borderRadius(18)
      .margin({ right: 8, bottom: 8 })
      .onClick((): void => {
        this.translationSource = id;
      })
  }

  private isAutoExcludedLanguage(id: string): boolean {
    const selected: string[] = this.translationAutoExcludedLanguages.split(',');
    for (let i: number = 0; i < selected.length; i++) {
      if (selected[i] === id) {
        return true;
      }
    }
    return false;
  }

  private toggleAutoExcludedLanguage(id: string): void {
    const selected: string[] = this.translationAutoExcludedLanguages.split(',');
    const updated: string[] = [];
    let alreadySelected: boolean = false;
    for (let i: number = 0; i < selected.length; i++) {
      if (selected[i] === id) {
        alreadySelected = true;
      } else if (selected[i].length > 0) {
        updated.push(selected[i]);
      }
    }
    if (!alreadySelected) {
      updated.push(id);
    }
    this.translationAutoExcludedLanguages = updated.join(',');
  }

  @Builder
  private AutoExcludedLanguageChip(id: string, label: Resource): void {
    Text(label).fontFamily(this.appFontFamily)
      .fontSize($r('sys.float.Body_M'))
      .fontColor(this.isAutoExcludedLanguage(id) ? $r('app.color.text_on_accent') :
        $r('app.color.text_primary'))
      .padding({ left: 14, right: 14, top: 9, bottom: 9 })
      .backgroundColor(this.isAutoExcludedLanguage(id) ? this.accentColor :
        fieldSurfaceColor(this.displayMode, this.darkSurface))
      .borderRadius(18)
      .margin({ right: 8, bottom: 8 })
      .onClick((): void => {
        this.toggleAutoExcludedLanguage(id);
      })
  }

  @Builder
  private FieldLabel(title: Resource): void {
    Text(title).fontFamily(this.appFontFamily)
      .fontSize($r('sys.float.Subtitle_L'))
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.text_primary'))
      .width('100%')
  }

  @Builder
  private TranslationContent(): void {
    Column({ space: 16 }) {
      Text($r('app.string.settings_translation_intro')).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_L'))
        .lineHeight(22)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')

      Row() {
        Column({ space: 4 }) {
          Text($r('app.string.settings_translation_enable')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Subtitle_L'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
          Text($r('app.string.settings_translation_enable_desc')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Toggle({ type: ToggleType.Switch, isOn: this.translationEnabled })
          .selectedColor(this.accentColor)
          .onChange((value: boolean): void => {
            this.translationEnabled = value;
          })
      }
      .width('100%')

      Row({ space: 14 }) {
        Column({ space: 4 }) {
          Text($r('app.string.settings_translation_replace_original')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Subtitle_L'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
          Text($r('app.string.settings_translation_replace_original_desc')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M'))
            .lineHeight(20)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Toggle({ type: ToggleType.Switch, isOn: this.translationReplaceOriginal })
          .selectedColor(this.accentColor)
          .onChange((value: boolean): void => {
            this.translationReplaceOriginal = value;
          })
      }
      .width('100%')
      .padding({ top: 16, bottom: 16, left: 16, right: 16 })
      .backgroundColor(fieldSurfaceColor(this.displayMode, this.darkSurface))
      .borderRadius(20)

      this.FieldLabel($r('app.string.settings_translation_mode'))
      Flex({ wrap: FlexWrap.Wrap }) {
        this.TranslationModeChip(TRANSLATION_MODE_X, $r('app.string.settings_translation_mode_x'))
        this.TranslationModeChip(TRANSLATION_MODE_WEB, $r('app.string.settings_translation_mode_web'))
        this.TranslationModeChip(TRANSLATION_MODE_API, $r('app.string.settings_translation_mode_api'))
      }
      .width('100%')

      if (this.translationMode === TRANSLATION_MODE_WEB) {
        Text($r('app.string.settings_translation_web_note')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M'))
          .lineHeight(20)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
      } else if (this.translationMode === TRANSLATION_MODE_X) {
        Text($r('app.string.settings_translation_x_note')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M'))
          .lineHeight(20)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
      } else {
        this.FieldLabel($r('app.string.settings_translation_provider'))
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.translationProviderList, (provider: TranslationProvider): void => {
            this.ProviderChip(provider)
          }, (provider: TranslationProvider): string => provider.id)
        }
        .width('100%')

        this.FieldLabel($r('app.string.settings_translation_model'))
        TextInput({ placeholder: this.translationModelHint(), text: this.translationModel }).fontFamily(this.appFontFamily)
          .keyboardAppearance(KeyboardAppearance.IMMERSIVE)
          .width('100%')
          .height(48)
          .fontSize($r('sys.float.Body_L'))
          .maxFontScale(1.5)
          .backgroundColor(fieldSurfaceColor(this.displayMode, this.darkSurface))
          .borderRadius(12)
          .padding({ left: 14, right: 14 })
          .onChange((value: string): void => {
            this.translationModel = value;
          })
        Text(this.translationModelHint()).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('app.color.text_secondary'))
          .width('100%')

        this.FieldLabel($r('app.string.settings_translation_api_key'))
        TextInput({
          placeholder: $r('app.string.settings_translation_api_key_placeholder'),
          text: this.translationApiKey
        }).fontFamily(this.appFontFamily)
          .keyboardAppearance(KeyboardAppearance.IMMERSIVE)
          .type(InputType.Password)
          .width('100%')
          .height(48)
          .fontSize($r('sys.float.Body_L'))
          .maxFontScale(1.5)
          .backgroundColor(fieldSurfaceColor(this.displayMode, this.darkSurface))
          .borderRadius(12)
          .padding({ left: 14, right: 14 })
          .onChange((value: string): void => {
            this.translationApiKey = value;
          })
        Text($r('app.string.settings_translation_api_key_note')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M'))
          .lineHeight(20)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
      }

      if (this.translationMode !== TRANSLATION_MODE_X) {
        this.FieldLabel($r('app.string.settings_translation_source'))
        Flex({ wrap: FlexWrap.Wrap }) {
          this.SourceChip(SOURCE_LANGUAGE_AUTO, $r('app.string.settings_translation_source_auto'))
          ForEach(this.translationLanguageList, (language: AppLanguageOption): void => {
            this.SourceChip(normalizeTranslationLanguage(language.tag), language.name)
          }, (language: AppLanguageOption): string => language.tag)
        }
        .width('100%')
      }

      this.FieldLabel($r('app.string.settings_translation_target'))
      Flex({ wrap: FlexWrap.Wrap }) {
        this.TargetChip(TARGET_LANGUAGE_APP, $r('app.string.settings_translation_target_app'))
        ForEach(this.translationLanguageList, (language: AppLanguageOption): void => {
          this.TargetChip(normalizeTranslationLanguage(language.tag), language.name)
        }, (language: AppLanguageOption): string => language.tag)
      }
      .width('100%')

      if (this.translationMode === TRANSLATION_MODE_API || this.translationMode === TRANSLATION_MODE_X) {
        Row({ space: 14 }) {
          Column({ space: 4 }) {
            Text($r('app.string.settings_translation_auto_enable')).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Subtitle_L'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
            Text($r('app.string.settings_translation_auto_enable_desc')).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_M'))
              .lineHeight(20)
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          Toggle({ type: ToggleType.Switch, isOn: this.translationAutoEnabled })
            .selectedColor(this.accentColor)
            .onChange((value: boolean): void => {
              this.translationAutoEnabled = value;
            })
        }
        .width('100%')
        .padding({ top: 16, bottom: 16, left: 16, right: 16 })
        .backgroundColor(fieldSurfaceColor(this.displayMode, this.darkSurface))
        .borderRadius(20)

        if (this.translationAutoEnabled) {
          this.FieldLabel($r('app.string.settings_translation_auto_exclude'))
          Text($r('app.string.settings_translation_auto_exclude_desc')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.translationLanguageList, (language: AppLanguageOption): void => {
              this.AutoExcludedLanguageChip(normalizeTranslationLanguage(language.tag), language.name)
            }, (language: AppLanguageOption): string => language.tag)
          }
          .width('100%')
        }

      }

      if (this.translationMode === TRANSLATION_MODE_API) {
        this.FieldLabel($r('app.string.settings_translation_base_url'))
        TextInput({ placeholder: this.translationBaseUrlHint(), text: this.translationBaseUrl }).fontFamily(this.appFontFamily)
          .keyboardAppearance(KeyboardAppearance.IMMERSIVE)
          .width('100%')
          .height(48)
          .fontSize($r('sys.float.Body_L'))
          .maxFontScale(1.5)
          .backgroundColor(fieldSurfaceColor(this.displayMode, this.darkSurface))
          .borderRadius(12)
          .padding({ left: 14, right: 14 })
          .onChange((value: string): void => {
            this.translationBaseUrl = value;
          })
        Text($r('app.string.settings_translation_base_url_note')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M'))
          .lineHeight(20)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
      }

      Button($r('app.string.settings_translation_save'), { stateEffect: true })
        .width('100%')
        .backgroundColor(this.accentColor)
        .fontColor($r('app.color.text_on_accent'))
        .onClick((): void => {
          this.saveTranslationConfiguration();
        })
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 20, bottom: 28 })
  }

  @Builder
  private GrokContent(): void {
    Column({ space: 16 }) {
      Text($r('app.string.settings_grok_intro')).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_L'))
        .lineHeight(22)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')

      this.FieldLabel($r('app.string.settings_grok_mode'))
      Row() {
        this.GrokModeChip(GROK_MODE_WEB, $r('app.string.settings_grok_mode_web'))
        this.GrokModeChip(GROK_MODE_API, $r('app.string.settings_grok_mode_api'))
      }
      .width('100%')
      Text(this.grokMode === GROK_MODE_WEB ? $r('app.string.settings_grok_mode_web_note') :
        $r('app.string.settings_grok_mode_api_note')).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_M'))
        .lineHeight(20)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')

      Row({ space: 14 }) {
        Column({ space: 4 }) {
          Text($r('app.string.settings_grok_x_session')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Subtitle_L'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
          Text($r('app.string.settings_grok_x_session_desc')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M'))
            .lineHeight(20)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Toggle({ type: ToggleType.Switch, isOn: this.grokUseXWebSession })
          .selectedColor(this.accentColor)
          .onChange((value: boolean): void => {
            this.grokUseXWebSession = value;
          })
      }
      .width('100%')

      if (this.grokMode === GROK_MODE_API) {
        this.FieldLabel($r('app.string.settings_grok_model'))
        TextInput({ placeholder: $r('app.string.settings_grok_model_hint'), text: this.grokModel }).fontFamily(this.appFontFamily)
          .keyboardAppearance(KeyboardAppearance.IMMERSIVE)
          .width('100%')
          .height(48)
          .fontSize($r('sys.float.Body_L'))
          .maxFontScale(1.5)
          .backgroundColor(fieldSurfaceColor(this.displayMode, this.darkSurface))
          .borderRadius(12)
          .padding({ left: 14, right: 14 })
          .onChange((value: string): void => {
            this.grokModel = value;
          })

        this.FieldLabel($r('app.string.settings_grok_api_key'))
        TextInput({
          placeholder: $r('app.string.settings_grok_api_key_placeholder'),
          text: this.grokApiKey
        }).fontFamily(this.appFontFamily)
          .keyboardAppearance(KeyboardAppearance.IMMERSIVE)
          .type(InputType.Password)
          .width('100%')
          .height(48)
          .fontSize($r('sys.float.Body_L'))
          .maxFontScale(1.5)
          .backgroundColor(fieldSurfaceColor(this.displayMode, this.darkSurface))
          .borderRadius(12)
          .padding({ left: 14, right: 14 })
          .onChange((value: string): void => {
            this.grokApiKey = value;
          })
        Text($r('app.string.settings_grok_api_key_note')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M'))
          .lineHeight(20)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')

        this.FieldLabel($r('app.string.settings_grok_base_url'))
        TextInput({ placeholder: $r('app.string.settings_grok_base_url_hint'), text: this.grokBaseUrl }).fontFamily(this.appFontFamily)
          .keyboardAppearance(KeyboardAppearance.IMMERSIVE)
          .width('100%')
          .height(48)
          .fontSize($r('sys.float.Body_L'))
          .maxFontScale(1.5)
          .backgroundColor(fieldSurfaceColor(this.displayMode, this.darkSurface))
          .borderRadius(12)
          .padding({ left: 14, right: 14 })
          .onChange((value: string): void => {
            this.grokBaseUrl = value;
          })
      }

      Button($r('app.string.settings_grok_save'), { stateEffect: true })
        .width('100%')
        .backgroundColor(this.accentColor)
        .fontColor($r('app.color.text_on_accent'))
        .onClick((): void => {
          this.saveGrokConfiguration();
        })
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 20, bottom: 28 })
  }

  @Builder
  private GenericContent(): void {
    if (this.section === 'account' || this.section === 'privacy' || this.section === 'security') {
      this.SimpleItem(this.title(), $r('app.string.xsettings_remote_note'), (): void => {
        const param: AccountPrivacyRouteParam = { section: this.section };
        this.pageStack.pushPath({ name: 'AccountPrivacy', param: param });
      })
    } else if (this.section === 'link_behavior') {
      Row({ space: 14 }) {
        Column({ space: 4 }) {
          Text($r('app.string.settings_link_in_app')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Subtitle_L'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
          Text($r('app.string.settings_link_in_app_desc')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Toggle({ type: ToggleType.Switch, isOn: this.linkInApp })
          .selectedColor(this.accentColor)
          .onChange((value: boolean): void => this.setLinkInApp(value))
      }
      .width('100%')
      .padding({ top: 16, bottom: 16, left: 20, right: 20 })
    } else if (this.section === 'resources') {
      this.SimpleItem($r('app.string.side_help'), $r('app.string.help_intro'),
        (): void => this.openHelpCenter())
      this.SimpleItem($r('app.string.settings_diagnostics'), $r('app.string.diagnostics_desc'),
        (): void => this.openDiagnostics())
    }
  }

  @Builder
  private SettingsSwitchRow(title: Resource, detail: Resource, enabled: boolean,
    onChange: (value: boolean) => void): void {
    Row({ space: 14 }) {
      Column({ space: 4 }) {
        Text(title).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Subtitle_L'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Text(detail).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Toggle({ type: ToggleType.Switch, isOn: enabled })
        .selectedColor(this.accentColor)
        .onChange(onChange)
    }
    .width('100%')
    .padding({ top: 16, bottom: 16, left: 20, right: 20 })
  }

  @Builder
  private HomeFeedOption(mode: number, title: Resource, detail: Resource): void {
    Row({ space: 14 }) {
      Column({ space: 4 }) {
        Text(title).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Subtitle_L'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Text(detail).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      if (this.defaultHomeFeedMode === mode) {
        SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
          .fontSize(23)
          .fontColor([this.accentColor])
      }
    }
    .width('100%')
    .padding({ top: 18, bottom: 18, left: 20, right: 20 })
    .onClick((): void => this.setDefaultHomeFeed(mode))
  }

  @Builder
  private ContentPreferencesContent(): void {
    Column() {
      Row({ space: 14 }) {
        Column({ space: 4 }) {
          Text($r('app.string.settings_sensitive_media')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Subtitle_L'))
            .fontColor($r('app.color.text_primary'))
          Text($r('app.string.settings_sensitive_media_desc')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Toggle({ type: ToggleType.Switch, isOn: this.showSensitiveMedia })
          .selectedColor(this.accentColor)
          .enabled(!this.sensitiveMediaSaving)
          .onChange((value: boolean): void => { this.setShowSensitiveMedia(value); })
      }
      .width('100%')
      .padding({ top: 16, bottom: 16, left: 20, right: 20 })

      this.FilterSection()
    }.width('100%')
  }

  @Builder
  private FilterTextArea(title: Resource, detail: Resource, placeholder: Resource, text: string,
    onChange: (value: string) => void): void {
    Column({ space: 8 }) {
      Text(title).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Subtitle_L'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
      Text(detail).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('app.color.text_secondary'))
        .lineHeight(20)
        .width('100%')
      TextArea({ placeholder: placeholder, text: text }).fontFamily(this.appFontFamily)
        .keyboardAppearance(KeyboardAppearance.IMMERSIVE)
        .width('100%')
        .height(92)
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('app.color.text_primary'))
        .placeholderColor($r('app.color.text_secondary'))
        .backgroundColor(fieldSurfaceColor(this.displayMode, this.darkSurface))
        .borderRadius(12)
        .padding({ left: 12, right: 12, top: 10, bottom: 10 })
        .onChange((value: string): void => onChange(value))
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 12, bottom: 12 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private FilterSection(): void {
    Column({ space: 0 }) {
      Text($r('app.string.settings_filter_title')).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Title_S'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .padding({ left: 20, right: 20, top: 12, bottom: 4 })
      Text($r('app.string.settings_filter_desc')).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('app.color.text_secondary'))
        .lineHeight(20)
        .width('100%')
        .padding({ left: 20, right: 20, bottom: 8 })
      Text($r('app.string.xsettings_local_filter_note')).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .padding({ left: 20, right: 20, bottom: 8 })
      Column({ space: 0 }) {
        this.AutoHideSwitchRow($r('app.string.settings_filter_hide_ads'),
          $r('app.string.settings_filter_hide_ads_desc'), this.filterHideAds,
          (value: boolean): void => this.setFilterHideAds(value))
        this.AutoHideSwitchRow($r('app.string.settings_filter_only_media'),
          $r('app.string.settings_filter_only_media_desc'), this.filterOnlyMedia,
          (value: boolean): void => this.setFilterOnlyMedia(value))
        this.AutoHideSwitchRow($r('app.string.settings_filter_hide_reposts'),
          $r('app.string.settings_filter_hide_reposts_desc'), this.filterHideReposts,
          (value: boolean): void => this.setFilterHideReposts(value))
        this.AutoHideSwitchRow($r('app.string.settings_filter_hide_replies'),
          $r('app.string.settings_filter_hide_replies_desc'), this.filterHideReplies,
          (value: boolean): void => this.setFilterHideReplies(value))
      }
      .width('100%')
      .padding({ left: 20, right: 20 })
      this.FilterTextArea($r('app.string.settings_filter_keywords'),
        $r('app.string.settings_filter_keywords_desc'),
        $r('app.string.settings_filter_keywords_placeholder'), this.filterKeywords,
        (value: string): void => this.setFilterKeywords(value))
      this.FilterTextArea($r('app.string.settings_filter_muted_users'),
        $r('app.string.settings_filter_muted_users_desc'),
        $r('app.string.settings_filter_muted_users_placeholder'), this.filterMutedUsers,
        (value: string): void => this.setFilterMutedUsers(value))
    }
    .width('100%')
  }

  build(): void {
    HdsNavDestination() {
      Scroll(this.scroller) {
        Column({ space: 0 }) {
          if (this.children().length > 0) {
            this.CategoryContent()
          } else if (this.section === 'theme') {
            this.DisplayContent()
          } else if (this.section === 'fonts') {
            this.FontsContent()
          } else if (this.section === 'titlebar') {
            Column({ space: 16 }) { this.ImmersiveTitleBarBlurSection() }
              .width('100%').padding({ left: 20, right: 20, top: 16, bottom: 28 })
          } else if (this.section === 'tabmaterial') {
            Column({ space: 16 }) { this.HdsTabsMaterialSection() }
              .width('100%').padding({ left: 20, right: 20, top: 16, bottom: 28 })
          } else if (this.section === 'sheetmaterial') {
            Column({ space: 16 }) { this.SheetMaterialSection() }
              .width('100%').padding({ left: 20, right: 20, top: 16, bottom: 28 })
          } else if (this.section === 'sidebarmaterial') {
            Column({ space: 16 }) { this.SidebarMaterialSection() }
              .width('100%').padding({ left: 20, right: 20, top: 16, bottom: 28 })
          } else if (this.section === 'replymaterial') {
            this.ReplyMaterialSection()
          } else if (this.section === 'feed') {
            this.FeedContent()
          } else if (this.section === 'navigation') {
            this.NavigationContent()
          } else if (this.section === 'home_interaction') {
            Column({ space: 16 }) { this.HomeInteractionSection() }
              .width('100%').padding({ left: 20, right: 20, top: 16, bottom: 28 })
          } else if (this.section === 'layout') {
            this.LayoutContent()
          } else if (this.section === 'photos') {
            this.PhotosContent()
          } else if (this.section === 'playback') {
            this.PlaybackContent()
          } else if (this.section === 'video_controls') {
            this.VideoControlsContent()
          } else if (this.section === 'viewer') {
            this.ViewerContent()
          } else if (this.section === 'quality') {
            this.QualityContent()
          } else if (this.section === 'accessibility') {
            this.AccessibilityContent()
          } else if (this.section === 'language') {
            this.LanguageContent()
          } else if (this.section === 'translation') {
            this.TranslationContent()
          } else if (this.section === 'grok') {
            this.GrokContent()
          } else if (this.section === 'content') {
            this.ContentPreferencesContent()
          } else if (this.section === 'appicon') {
            this.AppIconContent()
          } else if (this.section === 'alerts') {
            this.AlertsContent()
          } else {
            this.GenericContent()
          }
        }
        .width('100%')
        .padding({ top: this.desktopLayoutEnabled && ResponsiveLayout.isLarge(this.breakpoint) ? 12 : this.statusBarHeight + 74,
          bottom: this.navigationIndicatorHeight + 28 })
      }
      .width('100%')
      .height('100%')
      .align(Alignment.TopStart)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .clipContent(ContentClipMode.SAFE_AREA)
      .clip(false)
    }
    .onReady((context: NavDestinationContext): void => {
      const param: SettingsRouteParam = context.pathInfo.param as SettingsRouteParam;
      if (param !== undefined && param !== null) {
        // Previously remembered desktop destinations return to notifications while this entry is hidden.
        this.section = param.section === 'meow' ? 'notifications' : param.section;
      }
    })
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .hideBackButton(false)
    .onBackPressed((): boolean => {
      ResponsiveLayout.closeContentDestination(this.pageStack);
      return true;
    })
    .bindToScrollable([this.scroller])
    .titleBar({
      avoidLayoutSafeArea: true,
      content: { title: { mainTitle: this.title() } },
      enableComponentSafeArea: this.desktopLayoutEnabled && ResponsiveLayout.isLarge(this.breakpoint),
      style: destinationTitleBarStyle(ScrollEffectType.GRADIENT_BLUR, this.displayMode, this.darkSurface,
        this.titleBarStyleMode)
    })
    .backgroundColor(pageSurfaceColor(this.displayMode, this.darkSurface))
    .systemMaterial(this.pageMaterial());
  }
}
