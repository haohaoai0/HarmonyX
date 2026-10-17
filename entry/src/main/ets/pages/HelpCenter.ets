import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { SupporterActivationCard } from '../components/SupporterActivationCard';
import promptAction from '@ohos.promptAction';
import common from '@ohos.app.ability.common';
import { uiMaterial } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';
import {
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  ScrollEffectType
} from '@kit.UIDesignKit';
import { destinationTitleBarStyle } from '../utils/DestinationTitleBar';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';
import { cardSurfaceColor, fieldSurfaceColor, pageSurfaceColor } from '../utils/ThemeColors';

const FEEDBACK_URL: string = 'https://github.com/haohaoai0/HarmonyX/issues/new';
const QQ_GROUP_URL: string = 'https://qm.qq.com/q/QGxbHyYXuI';
const TELEGRAM_GROUP_URL: string = 'https://t.me/HarmonXH';

@Builder
export function HelpCenterBuilder(): void {
  HelpCenter();
}

@Component
struct SupportQrCard {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Prop title: Resource = $r('app.string.help_support_wechat');
  @Prop image: Resource = $r('app.media.support_wechat');
  @Prop imageHeight: number = 380;
  @StorageProp('harmonyx.display_mode') private themeDisplayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private themeDarkSurface: string = '';

  build(): void {
    Column({ space: 12 }) {
      Text(this.title).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Subtitle_L'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
      Image(this.image)
        .width('100%')
        .height(this.imageHeight)
        .objectFit(ImageFit.Contain)
        .borderRadius(16)
        .clip(true)
    }
    .width('100%')
    .padding(16)
    .backgroundColor(cardSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
    .borderRadius(20)
  }
}

@Component
struct HelpCenter {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp('harmonyx.status_bar_height') statusBarHeight: number =
    AppStorage.get<number>('harmonyx.status_bar_height') ?? 0;
  @StorageProp('harmonyx.navigation_indicator_height') navigationIndicatorHeight: number =
    AppStorage.get<number>('harmonyx.navigation_indicator_height') ?? 0;
  @StorageLink('harmonyx.accent_color') accentColor: string = '#007DFF';
  @StorageProp('harmonyx.display_mode') private themeDisplayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private themeDarkSurface: string = '';
  @StorageLink('harmonyx.title_bar_style_mode') titleBarStyleMode: number = 0;
  private scroller: Scroller = new Scroller();

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

  private text(resource: Resource): string {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    return context.resourceManager.getStringSync(resource);
  }

  private async openExternalLink(url: string, successMessage: Resource, failureMessage: Resource): Promise<void> {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    try {
      await context.startAbility({
        action: 'ohos.want.action.viewData',
        entities: ['entity.system.browsable'],
        uri: url
      });
      promptAction.showToast({ message: this.text(successMessage), duration: 2000 });
    } catch (error) {
      promptAction.showToast({ message: this.text(failureMessage), duration: 2500 });
    }
  }

  private openFeedback(): void {
    this.openExternalLink(
      FEEDBACK_URL,
      $r('app.string.help_feedback_opened'),
      $r('app.string.help_feedback_failed')
    );
  }

  private openQqGroup(): void {
    this.openExternalLink(
      QQ_GROUP_URL,
      $r('app.string.help_group_opened'),
      $r('app.string.help_group_failed')
    );
  }

  private openTelegramGroup(): void {
    this.openExternalLink(
      TELEGRAM_GROUP_URL,
      $r('app.string.help_tg_group_opened'),
      $r('app.string.help_tg_group_failed')
    );
  }

  build(): void {
    HdsNavDestination() {
      Scroll(this.scroller) {
        Column({ space: 20 }) {
          Column({ space: 8 }) {
            SymbolGlyph($r('sys.symbol.questionmark_circle'))
              .fontSize(34)
              .fontColor([this.accentColor])
            Text($r('app.string.side_help')).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Title_M'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
            Text($r('app.string.help_intro')).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_L'))
              .lineHeight(22)
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          Column({ space: 12 }) {
            Row({ space: 14 }) {
              SymbolGlyph($r('sys.symbol.ellipsis_bubble'))
                .fontSize(26)
                .fontColor([this.accentColor])
              Column({ space: 4 }) {
                Text($r('app.string.help_feedback_title')).fontFamily(this.appFontFamily)
                  .fontSize($r('sys.float.Title_S'))
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_primary'))
                Text($r('app.string.help_feedback_desc')).fontFamily(this.appFontFamily)
                  .fontSize($r('sys.float.Body_M'))
                  .lineHeight(21)
                  .fontColor($r('app.color.text_secondary'))
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
            }
            Button($r('app.string.help_feedback_action'), { stateEffect: true })
              .width('100%')
              .backgroundColor(this.accentColor)
              .fontColor($r('app.color.text_on_accent'))
              .onClick((): void => {
                this.openFeedback();
              })
            Divider().color($r('app.color.divider'))
            Row({ space: 14 }) {
              SymbolGlyph($r('sys.symbol.person_2'))
                .fontSize(24)
                .fontColor([this.accentColor])
              Column({ space: 4 }) {
                Text($r('app.string.help_group_title')).fontFamily(this.appFontFamily)
                  .fontSize($r('sys.float.Subtitle_L'))
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary'))
                Text($r('app.string.help_group_desc')).fontFamily(this.appFontFamily)
                  .fontSize($r('sys.float.Body_M'))
                  .lineHeight(21)
                  .fontColor($r('app.color.text_secondary'))
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
            }
            Button($r('app.string.help_group_action'), { stateEffect: true })
              .width('100%')
              .backgroundColor(fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
              .fontColor($r('app.color.text_accent'))
              .border({ width: 1, color: this.accentColor })
              .onClick((): void => {
                this.openQqGroup();
              })
            Divider().color($r('app.color.divider'))
            Row({ space: 14 }) {
              SymbolGlyph($r('sys.symbol.person_2'))
                .fontSize(24)
                .fontColor([this.accentColor])
              Column({ space: 4 }) {
                Text($r('app.string.help_tg_group_title')).fontFamily(this.appFontFamily)
                  .fontSize($r('sys.float.Subtitle_L'))
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary'))
                Text($r('app.string.help_tg_group_desc')).fontFamily(this.appFontFamily)
                  .fontSize($r('sys.float.Body_M'))
                  .lineHeight(21)
                  .fontColor($r('app.color.text_secondary'))
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
            }
            Button($r('app.string.help_tg_group_action'), { stateEffect: true })
              .width('100%')
              .backgroundColor(fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
              .fontColor($r('app.color.text_accent'))
              .border({ width: 1, color: this.accentColor })
              .onClick((): void => {
                this.openTelegramGroup();
              })
          }
          .width('100%')
          .padding(18)
          .backgroundColor(cardSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
          .borderRadius(20)

          Divider().color($r('app.color.divider'))

          Column({ space: 8 }) {
            Row({ space: 12 }) {
              SymbolGlyph($r('sys.symbol.heart_fill'))
                .fontSize(25)
                .fontColor([$r('app.color.like')])
              Text($r('app.string.help_support_title')).fontFamily(this.appFontFamily)
                .fontSize($r('sys.float.Title_S'))
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
            }
            Text($r('app.string.help_support_desc')).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_L'))
              .lineHeight(22)
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
            Text($r('app.string.help_support_scan')).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_M'))
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
          }
          .width('100%')

          SupporterActivationCard()
          SupportQrCard({
            title: $r('app.string.help_support_wechat'),
            image: $r('app.media.support_wechat'),
            imageHeight: 380
          })
          SupportQrCard({
            title: $r('app.string.help_support_alipay'),
            image: $r('app.media.support_alipay'),
            imageHeight: 460
          })
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: this.statusBarHeight + 88,
          bottom: this.navigationIndicatorHeight + 28 })
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
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
      content: { title: { mainTitle: $r('app.string.side_help') } },
      style: destinationTitleBarStyle(ScrollEffectType.GRADIENT_BLUR, this.themeDisplayMode,
        this.themeDarkSurface, this.titleBarStyleMode)
    })
    .backgroundColor(pageSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
    .systemMaterial(this.pageMaterial());
  }
}
