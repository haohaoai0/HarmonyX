import promptAction from '@ohos.promptAction';
import common from '@ohos.app.ability.common';
import { uiMaterial } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';
import {
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  hdsMaterial,
  ScrollEffectType
} from '@kit.UIDesignKit';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';

const FEEDBACK_URL: string = 'https://github.com/haohaoai0/HarmonyX/issues/new';
const QQ_GROUP_URL: string = 'https://qm.qq.com/q/QGxbHyYXuI';

@Builder
export function HelpCenterBuilder(): void {
  HelpCenter();
}

@Component
struct SupportQrCard {
  @Prop title: Resource = $r('app.string.help_support_wechat');
  @Prop image: Resource = $r('app.media.support_wechat');
  @Prop imageHeight: number = 380;

  build(): void {
    Column({ space: 12 }) {
      Text(this.title)
        .fontSize(17)
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
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius(20)
  }
}

@Component
struct HelpCenter {
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp('harmonyx.status_bar_height') statusBarHeight: number =
    AppStorage.get<number>('harmonyx.status_bar_height') ?? 0;
  @StorageProp('harmonyx.navigation_indicator_height') navigationIndicatorHeight: number =
    AppStorage.get<number>('harmonyx.navigation_indicator_height') ?? 0;
  @StorageLink('harmonyx.accent_color') accentColor: string = '#007DFF';
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

  build(): void {
    HdsNavDestination() {
      Scroll(this.scroller) {
        Column({ space: 20 }) {
          Column({ space: 8 }) {
            SymbolGlyph($r('sys.symbol.questionmark_circle'))
              .fontSize(34)
              .fontColor([this.accentColor])
            Text($r('app.string.side_help'))
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
            Text($r('app.string.help_intro'))
              .fontSize(15)
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
                Text($r('app.string.help_feedback_title'))
                  .fontSize(19)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_primary'))
                Text($r('app.string.help_feedback_desc'))
                  .fontSize(14)
                  .lineHeight(21)
                  .fontColor($r('app.color.text_secondary'))
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
            }
            Button($r('app.string.help_feedback_action'), { stateEffect: true })
              .width('100%')
              .backgroundColor(this.accentColor)
              .fontColor($r('app.color.text_on_brand'))
              .onClick((): void => {
                this.openFeedback();
              })
            Divider().color($r('app.color.divider'))
            Row({ space: 14 }) {
              SymbolGlyph($r('sys.symbol.person_2'))
                .fontSize(24)
                .fontColor([this.accentColor])
              Column({ space: 4 }) {
                Text($r('app.string.help_group_title'))
                  .fontSize(17)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary'))
                Text($r('app.string.help_group_desc'))
                  .fontSize(14)
                  .lineHeight(21)
                  .fontColor($r('app.color.text_secondary'))
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
            }
            Button($r('app.string.help_group_action'), { stateEffect: true })
              .width('100%')
              .backgroundColor($r('app.color.bg_field'))
              .fontColor(this.accentColor)
              .border({ width: 1, color: this.accentColor })
              .onClick((): void => {
                this.openQqGroup();
              })
          }
          .width('100%')
          .padding(18)
          .backgroundColor($r('app.color.bg_card'))
          .borderRadius(20)

          Divider().color($r('app.color.divider'))

          Column({ space: 8 }) {
            Row({ space: 12 }) {
              SymbolGlyph($r('sys.symbol.heart_fill'))
                .fontSize(25)
                .fontColor([$r('app.color.like')])
              Text($r('app.string.help_support_title'))
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
            }
            Text($r('app.string.help_support_desc'))
              .fontSize(15)
              .lineHeight(22)
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
            Text($r('app.string.help_support_scan'))
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
          }
          .width('100%')

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
      .scrollBar(BarState.Auto)
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
      style: {
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.IMMERSIVE,
          materialLevel: hdsMaterial.MaterialLevel.EXQUISITE
        }
      }
    })
    .backgroundColor($r('app.color.bg_page'))
    .systemMaterial(this.pageMaterial());
  }
}
