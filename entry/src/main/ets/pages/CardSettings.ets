import { pageTextColor } from '../utils/ThemeColors';
import { appPageBackground } from '../components/PageBackgroundLayer';
import { pageCanvasColor, pageReadingSurfaceColor } from '../utils/ThemeColors';
import { STORAGE_KEY_PAGE_TRANSITION_MODE, DEFAULT_PAGE_TRANSITION_MODE } from '../services/PageTransitionSettingsStore';
import { pageSystemTransition, PageTransitionMotion } from '../utils/PageTransition';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { common } from '@kit.AbilityKit';
import { HdsNavDestination, HdsNavDestinationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { STORAGE_KEY_SYSTEM_EMOJI_ENABLED } from '../services/AppearanceStore';
import {
  ArticleCardSourceOption,
  ArticleCardStore
} from '../services/ArticleCardStore';
import { ArticleCardPublisher } from '../services/ArticleCardPublisher';
import { ArticleCardSourceService } from '../services/ArticleCardSourceService';
import { destinationTitleBarStyle } from '../utils/DestinationTitleBar';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';
import { fieldSurfaceColor, pageSurfaceColor } from '../utils/ThemeColors';

@Builder
export function CardSettingsBuilder(): void {
  CardSettings();
}

@Component
struct CardSettings {
  @StorageProp('harmonyx.page_background') private pageBackgroundValue: string = '';
  @State private pageMotion: PageTransitionMotion = new PageTransitionMotion();
  @StorageProp(STORAGE_KEY_PAGE_TRANSITION_MODE) private pageTransitionMode: string = DEFAULT_PAGE_TRANSITION_MODE;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp(STORAGE_KEY_SYSTEM_EMOJI_ENABLED) private systemEmojiEnabled: boolean = false;
  @StorageProp('harmonyx.status_bar_height') private statusBarHeight: number = 0;
  @StorageProp('harmonyx.navigation_indicator_height') private navigationIndicatorHeight: number = 0;
  @StorageProp('harmonyx.display_mode') private displayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private darkSurface: string = '';
  @StorageLink('harmonyx.title_bar_style_mode') private titleBarStyleMode: number = 0;
  @Consume('pageStack') private pageStack: NavPathStack;
  @State private source: string = '';
  @State private refreshing: boolean = false;
  @State private status: string = '';
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    this.source = ArticleCardStore.selectedSource(context);
  }

  private text(resource: Resource): string {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    return context.resourceManager.getStringSync(resource);
  }

  private refreshStatus(refreshed: boolean): string {
    if (refreshed) { return this.text($r('app.string.card_settings_updated')); }
    if (this.source === 'for_you') { return this.text($r('app.string.card_empty_for_you')); }
    if (this.source === 'following') { return this.text($r('app.string.card_empty_following')); }
    return this.text($r('app.string.card_settings_update_failed'));
  }

  private async selectSource(option: ArticleCardSourceOption): Promise<void> {
    if (this.refreshing || this.source === option.id) {
      return;
    }
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    if (!ArticleCardStore.setSource(context, option.id)) {
      return;
    }
    this.source = option.id;
    this.status = this.text($r('app.string.card_settings_refreshing'));
    this.refreshing = true;
    const refreshed: boolean = await ArticleCardSourceService.refresh(context, option.id);
    ArticleCardPublisher.publish(context);
    this.refreshing = false;
    this.status = this.refreshStatus(refreshed);
  }

  private async refreshCurrent(): Promise<void> {
    if (this.refreshing || this.source.length === 0) {
      return;
    }
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    this.refreshing = true;
    this.status = this.text($r('app.string.card_settings_refreshing'));
    const refreshed: boolean = await ArticleCardSourceService.refresh(context, this.source);
    ArticleCardPublisher.publish(context);
    this.refreshing = false;
    this.status = this.refreshStatus(refreshed);
  }

  @Builder
  private SourceRow(option: ArticleCardSourceOption): void {
    Row({ space: 12 }) {
      Column({ space: 3 }) {
        Text(option.title)
          .fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_L'))
          .fontWeight(FontWeight.Medium)
          .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, fieldSurfaceColor(this.displayMode, this.darkSurface)))
        Text(option.description)
          .fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_S'))
          .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, fieldSurfaceColor(this.displayMode, this.darkSurface)))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      if (this.source === option.id) {
        SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
          .fontSize(22)
          .fontColor([$r('app.color.article_card_rank')])
      } else {
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(18)
          .fontColor([pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, fieldSurfaceColor(this.displayMode, this.darkSurface))])
      }
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .borderRadius(16)
    .backgroundColor(fieldSurfaceColor(this.displayMode, this.darkSurface))
    .onClick((): void => {
      this.selectSource(option).catch((): void => {
        this.refreshing = false;
        this.status = this.text($r('app.string.card_settings_update_failed'));
      });
    })
  }

  build(): void {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        appPageBackground()
      List({ space: 10, scroller: this.scroller }) {
        ListItem() {
          Column({ space: 6 }) {
            Text($r('app.string.card_settings_intro'))
              .fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_M'))
              .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
            if (this.status.length > 0) {
              Text(this.status)
                .fontFamily(this.appFontFamily)
                .fontSize($r('sys.float.Body_S'))
                .fontColor($r('app.color.article_card_rank'))
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding({ left: 4, right: 4, top: 4, bottom: 4 })
        }
        ForEach(ArticleCardStore.sources(), (option: ArticleCardSourceOption) => {
          ListItem() {
            this.SourceRow(option)
          }
        }, (option: ArticleCardSourceOption): string => option.id)
        ListItem() {
          Button($r('app.string.card_settings_refresh'))
            .width('100%')
            .height(46)
            .enabled(!this.refreshing)
            .backgroundColor($r('app.color.article_card_rank'))
            .onClick((): void => {
              this.refreshCurrent().catch((): void => {
                this.refreshing = false;
                this.status = this.text($r('app.string.card_settings_update_failed'));
              });
            })
        }
        ListItem() {
          Text($r('app.string.card_settings_note'))
            .fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_S'))
            .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
            .padding({ left: 4, right: 4, top: 4, bottom: 12 })
        }
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .padding({ left: 16, right: 16 })
      .contentStartOffset(this.statusBarHeight + 64)
      .contentEndOffset(this.navigationIndicatorHeight + 24)
    
      }.width('100%').height('100%')
    }
    .scale({ x: this.pageMotion.scale, y: this.pageMotion.scale })
    .opacity(this.pageMotion.opacity)
    .systemTransition(pageSystemTransition(this.pageTransitionMode))
    .onReady((context: NavDestinationContext): void => {
      this.pageMotion.attach(context);
    })
    .hideBackButton(false)
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .bindToScrollable([this.scroller])
    .onBackPressed((): boolean => {
      ResponsiveLayout.closeContentDestination(this.pageStack);
      return true;
    })
    .titleBar({
      avoidLayoutSafeArea: true,
      content: { title: { mainTitle: $r('app.string.card_settings_title') } },
      style: destinationTitleBarStyle(ScrollEffectType.IMMERSIVE_GRADIENT_BLUR,
        this.displayMode, this.darkSurface, this.titleBarStyleMode)
    })
    .backgroundColor(pageCanvasColor(this.displayMode, this.darkSurface, this.pageBackgroundValue))
  }
}
