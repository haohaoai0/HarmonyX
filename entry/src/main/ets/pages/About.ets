import { pageTextColor } from '../utils/ThemeColors';
import { appPageBackground } from '../components/PageBackgroundLayer';
import { pageCanvasColor, pageReadingSurfaceColor } from '../utils/ThemeColors';
import { STORAGE_KEY_PAGE_TRANSITION_MODE, DEFAULT_PAGE_TRANSITION_MODE } from '../services/PageTransitionSettingsStore';
import { pageSystemTransition, PageTransitionMotion } from '../utils/PageTransition';
import { bundleManager, common } from '@kit.AbilityKit';
import { requestXXAuthPopup } from '../services/XXAuthPopupStore';
import { SUPPORTER_ACTIVE_KEY } from '../services/XXAuthSupporterService';
import { HdsNavDestination, HdsNavDestinationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { destinationTitleBarStyle } from '../utils/DestinationTitleBar';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';
import { cardSurfaceColor, pageSurfaceColor, secondaryButtonSurfaceColor } from '../utils/ThemeColors';
import { effectiveAppLocale, isAppRtl, STORAGE_KEY_APP_LOCALE } from '../utils/AppLocale';

const PROJECT_URL: string = 'https://github.com/haohaoai0/HarmonyX';
const RELEASES_URL: string = PROJECT_URL + '/releases';
const AUTHOR_BILIBILI_URL: string = 'https://b23.tv/LHFUSzV';
const AUTHOR_COOLAPK_URL: string = 'https://www.coolapk.com/u/3309989';
const AUTHOR_MEOW_URL: string = 'https://api.chuckfang.com/';

@Builder
export function AboutBuilder(): void {
  About();
}

@Component
struct About {
  @StorageProp('harmonyx.page_background') private pageBackgroundValue: string = '';
  @State private pageMotion: PageTransitionMotion = new PageTransitionMotion();
  @StorageProp(STORAGE_KEY_PAGE_TRANSITION_MODE) private pageTransitionMode: string = DEFAULT_PAGE_TRANSITION_MODE;
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp(STORAGE_KEY_APP_LOCALE) private appLocale: string = effectiveAppLocale();
  @StorageProp('harmonyx.display_mode') private displayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private darkSurface: string = '';
  @StorageProp('harmonyx.title_bar_style_mode') private titleBarStyleMode: number = 0;
  @StorageProp('harmonyx.accent_color') private accentColor: string = '#007DFF';
  @StorageProp('harmonyx.status_bar_height') private statusBarHeight: number = 0;
  @StorageProp('harmonyx.navigation_indicator_height') private navigationIndicatorHeight: number = 0;
  @State private versionName: string = '';
  @State private buildNumber: string = '';
  @State private developer: string = '';
  @State private linkFailed: boolean = false;
  @StorageProp(SUPPORTER_ACTIVE_KEY) private supporterActive: boolean = false;
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    try {
      const info: bundleManager.BundleInfo = bundleManager.getBundleInfoForSelfSync(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
      this.versionName = info.versionName;
      this.buildNumber = info.versionCode.toString();
      this.developer = info.vendor;
    } catch (error) {
      // Keep an explicit unavailable state instead of showing an old resource version.
    }
  }

  private async openLink(url: string): Promise<void> {
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.linkFailed = false;
    try {
      await context.startAbility({ action: 'ohos.want.action.viewData',
        entities: ['entity.system.browsable'], uri: url });
    } catch (error) {
      this.linkFailed = true;
    }
  }

  @Builder
  private Hero(): void {
    Column({ space: $r('app.float.about_gap') }) {
      Button({ type: ButtonType.Normal, stateEffect: false }) {
        Image($r('app.media.app_icon'))
          .width($r('app.float.about_icon_size'))
          .height($r('app.float.about_icon_size'))
          .objectFit(ImageFit.Contain)
          .borderRadius($r('app.float.about_card_radius'))
          .clip(true)
          .accessibilityLevel('no')
      }
      .padding(0)
      .backgroundColor(Color.Transparent)
      .borderRadius($r('app.float.about_card_radius'))
      .accessibilityText($r('app.string.logo_universe_hint'))
      .id('about-logo-universe')
      .onClick((): void => { this.pageStack.pushPath({ name: 'LogoUniverse' }); })
      Text($r('app.string.app_name')).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Title_L'))
        .fontWeight(FontWeight.Bold)
        .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent))
        .textAlign(TextAlign.Center)
      Text($r('app.string.about_tagline')).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_L'))
        .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
        .textAlign(TextAlign.Center)
      if (this.versionName.length > 0) {
        Text(this.versionName).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor(this.accentColor)
      }
      Text($r('app.string.logo_universe_hint')).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_S'))
        .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
        .textAlign(TextAlign.Center)
        .onClick((): void => { this.pageStack.pushPath({ name: 'LogoUniverse' }); })
    }
    .width('100%')
    .padding({ top: $r('app.float.about_section_gap'), bottom: $r('app.float.about_gap') })
    .id('about-app-identity')
  }

  @Builder
  private Feature(icon: Resource, description: Resource): void {
    Row({ space: $r('app.float.about_row_gap') }) {
      SymbolGlyph(icon)
        .fontSize($r('app.float.about_symbol_size'))
        .fontColor([this.accentColor])
        .accessibilityLevel('no')
      Text(description).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_L'))
        .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, pageReadingSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue)))
        .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  private Introduction(): void {
    Column({ space: $r('app.float.about_card_inset') }) {
      Text($r('app.string.about_intro')).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Title_S'))
        .fontWeight(FontWeight.Medium)
        .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, pageReadingSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue)))
        .width('100%')
      this.Feature($r('sys.symbol.text_alignleft'), $r('app.string.about_feature_read'))
      this.Feature($r('sys.symbol.play_circle'), $r('app.string.about_feature_media'))
      this.Feature($r('sys.symbol.paintpalette'), $r('app.string.about_feature_style'))
    }
    .width('100%')
    .padding($r('app.float.about_card_inset'))
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(pageReadingSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue))
    .borderRadius($r('app.float.about_card_radius'))
  }

  @Builder
  private MetadataRow(label: Resource, value: string): void {
    Row({ space: $r('app.float.about_row_gap') }) {
      Text(label).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_L'))
        .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, pageReadingSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue)))
        .layoutWeight(1)
      if (value.length > 0) {
        Text(value).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_L'))
          .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, pageReadingSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue)))
          .textAlign(TextAlign.End)
          .layoutWeight(1)
      } else {
        Text($r('app.string.about_unavailable')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M'))
          .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, pageReadingSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue)))
          .textAlign(TextAlign.End)
          .layoutWeight(1)
      }
    }
    .width('100%')
  }

  @Builder
  private AccountButton(icon: Resource, label: Resource, url: string, id: string, monochrome: boolean): void {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      if (monochrome) {
        Image(icon)
          .width($r('app.float.about_account_icon_size'))
          .height($r('app.float.about_account_icon_size'))
          .objectFit(ImageFit.Contain)
          .fillColor($r('app.color.text_primary'))
          .accessibilityLevel('no')
      } else {
        Image(icon)
          .width($r('app.float.about_account_icon_size'))
          .height($r('app.float.about_account_icon_size'))
          .objectFit(ImageFit.Contain)
          .borderRadius($r('app.float.about_account_image_radius'))
          .accessibilityLevel('no')
      }
    }
    .width($r('app.float.about_account_button_size'))
    .height($r('app.float.about_account_button_size'))
    .padding(0)
    .borderRadius($r('app.float.about_account_button_radius'))
    .backgroundColor(secondaryButtonSurfaceColor(this.displayMode, this.darkSurface))
    .accessibilityText(label)
    .id(id)
    .onClick((): void => { this.openLink(url); })
  }

  @Builder
  private AuthorAccounts(): void {
    Row({ space: $r('app.float.about_account_gap') }) {
      SymbolGlyph($r('sys.symbol.person'))
        .fontSize($r('app.float.about_symbol_size'))
        .fontColor([pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, pageReadingSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue))])
        .accessibilityLevel('no')
      Text($r('app.string.about_official_accounts')).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_L'))
        .fontWeight(FontWeight.Medium)
        .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, pageReadingSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue)))
        .layoutWeight(1)
      this.AccountButton($r('app.media.about_bilibili'), $r('app.string.about_account_bilibili'),
        AUTHOR_BILIBILI_URL, 'about-account-bilibili', true)
      this.AccountButton($r('app.media.about_coolapk'), $r('app.string.about_account_coolapk'),
        AUTHOR_COOLAPK_URL, 'about-account-coolapk', false)
      this.AccountButton($r('app.media.about_meow'), $r('app.string.about_account_meow'),
        AUTHOR_MEOW_URL, 'about-account-meow', false)
    }
    .width('100%')
    .padding($r('app.float.about_card_inset'))
    .backgroundColor(pageReadingSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue))
    .borderRadius($r('app.float.about_card_radius'))
    .id('about-author-accounts')
  }

  @Builder
  private ActionRow(icon: Resource, title: Resource, detail: Resource, action: () => void): void {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: $r('app.float.about_row_gap') }) {
        SymbolGlyph(icon)
          .fontSize($r('app.float.about_symbol_size'))
          .fontColor([this.accentColor])
          .accessibilityLevel('no')
        Column({ space: $r('app.float.about_small_gap') }) {
          Text(title).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Subtitle_L'))
            .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, pageReadingSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue)))
          Text(detail).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M'))
            .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, pageReadingSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue)))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize($r('app.float.about_chevron_size'))
          .fontColor([pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, pageReadingSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue))])
          .scale({ x: isAppRtl(this.appLocale) ? -1 : 1 })
          .accessibilityLevel('no')
      }
      .width('100%')
      .padding($r('app.float.about_card_inset'))
    }
    .width('100%')
    .padding(0)
    .backgroundColor(Color.Transparent)
    .borderRadius(0)
    .onClick(action)
  }

  build(): void {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        appPageBackground()
      Scroll(this.scroller) {
        Column({ space: $r('app.float.about_section_gap') }) {
          this.Hero()
          this.Introduction()
          Column({ space: $r('app.float.about_row_gap') }) {
            this.MetadataRow($r('app.string.about_version'), this.versionName)
            this.MetadataRow($r('app.string.about_build'), this.buildNumber)
            this.MetadataRow($r('app.string.about_developer'), this.developer)
          }
          .width('100%')
          .padding($r('app.float.about_card_inset'))
          .backgroundColor(pageReadingSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue))
          .borderRadius($r('app.float.about_card_radius'))
          .id('about-version-info')

          this.AuthorAccounts()
          Column() {
            this.ActionRow($r('sys.symbol.heart_fill'), $r('app.string.side_support'),
              $r('app.string.help_support_scan'), (): void => { this.pageStack.pushPath({ name: 'Support' }); })
            Divider().color($r('app.color.divider'))
            this.ActionRow($r('sys.symbol.checkmark_shield'), $r('app.string.supporter_title'),
              $r('app.string.supporter_redeem'), (): void => { this.pageStack.pushPath({ name: 'SupporterAccess' }); })
          }.width('100%').backgroundColor(pageReadingSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue))
            .borderRadius($r('app.float.about_card_radius')).clip(true)

          Column() {
            if (!this.supporterActive) {
              this.ActionRow($r('sys.symbol.info_circle'), $r('app.string.xxauth_view_recommendation'),
                $r('app.string.xxauth_discover_apps'), (): void => { requestXXAuthPopup('recommendation'); })
              Divider().color($r('app.color.divider'))
            }
            this.ActionRow($r('sys.symbol.info_circle'), $r('app.string.xxauth_announcements'),
              $r('app.string.xxauth_announcements_desc'), (): void => { requestXXAuthPopup('announcements'); })
            Divider().color($r('app.color.divider'))
            this.ActionRow($r('sys.symbol.doc_text'), $r('app.string.xxauth_articles'),
              $r('app.string.xxauth_articles_desc'), (): void => { requestXXAuthPopup('articles'); })
            Divider().color($r('app.color.divider'))
            this.ActionRow($r('sys.symbol.info_circle'), $r('app.string.settings_check_update'),
              $r('app.string.xxauth_update_desc'), (): void => { requestXXAuthPopup('update'); })
            Divider().color($r('app.color.divider'))
            this.ActionRow($r('sys.symbol.doc_text'), $r('app.string.xxauth_versions'),
              $r('app.string.xxauth_versions_desc'), (): void => { requestXXAuthPopup('versions'); })
            Divider().color($r('app.color.divider'))
            this.ActionRow($r('sys.symbol.doc_text'), $r('app.string.about_releases'),
              $r('app.string.about_releases_desc'), (): void => { this.openLink(RELEASES_URL); })
            Divider().color($r('app.color.divider'))
            this.ActionRow($r('sys.symbol.link'), $r('app.string.about_project'),
              $r('app.string.about_project_desc'), (): void => { this.openLink(PROJECT_URL); })
            Divider().color($r('app.color.divider'))
            this.ActionRow($r('sys.symbol.questionmark_circle'), $r('app.string.side_help'),
              $r('app.string.help_intro'), (): void => {
                this.pageStack.pushPath({ name: 'HelpCenter' });
              })
          }
          .width('100%')
          .backgroundColor(pageReadingSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackgroundValue))
          .borderRadius($r('app.float.about_card_radius'))
          .clip(true)

          if (this.linkFailed) {
            Text($r('app.string.about_link_failed')).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_M'))
              .fontColor($r('app.color.danger'))
              .width('100%')
          }
        }
        .width('100%')
        .constraintSize({ maxWidth: $r('app.float.about_content_max_width') })
        .padding({ left: $r('app.float.about_page_inset'), right: $r('app.float.about_page_inset'),
          top: this.statusBarHeight + 64, bottom: this.navigationIndicatorHeight + 28 })
        .direction(Direction.Auto)
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .align(Alignment.Top)
    
      }.width('100%').height('100%')
    }
    .scale({ x: this.pageMotion.scale, y: this.pageMotion.scale })
    .opacity(this.pageMotion.opacity)
    .onReady((context: NavDestinationContext): void => { this.pageMotion.attach(context); })
    .systemTransition(pageSystemTransition(this.pageTransitionMode))
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .hideBackButton(false)
    .onBackPressed((): boolean => {
      ResponsiveLayout.closeContentDestination(this.pageStack);
      return true;
    })
    .bindToScrollable([this.scroller])
    .titleBar({ avoidLayoutSafeArea: true,
      content: { title: { mainTitle: $r('app.string.about_title') } },
      style: destinationTitleBarStyle(ScrollEffectType.GRADIENT_BLUR, this.displayMode,
        this.darkSurface, this.titleBarStyleMode) })
    .backgroundColor(pageCanvasColor(this.displayMode, this.darkSurface, this.pageBackgroundValue))
  }
}
