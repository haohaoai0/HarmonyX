import { common } from '@kit.AbilityKit';
import { curves } from '@kit.ArkUI';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { DEFAULT_MOTION_DAMPING, DEFAULT_MOTION_DURATION, STORAGE_KEY_MOTION_DAMPING,
  STORAGE_KEY_MOTION_DURATION, STORAGE_KEY_REDUCE_MOTION } from '../services/MotionSettingsStore';
import { cardSurfaceColor, pageReadingSurfaceColor, pageTextColor,
  secondaryButtonSurfaceColor } from '../utils/ThemeColors';

const AFDIAN_PRODUCT_URL: string = 'https://afdian.com/item/5281c678cad911f183da52540025c377';

@Component
export struct SupportPaymentCards {
  @Consume('pageStack') private pageStack: NavPathStack;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp('harmonyx.page_background') private pageBackground: string = '';
  @StorageProp('harmonyx.display_mode') private displayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private darkSurface: string = '';
  @StorageProp(STORAGE_KEY_REDUCE_MOTION) private reduceMotion: boolean = false;
  @StorageProp(STORAGE_KEY_MOTION_DURATION) private motionDuration: number = DEFAULT_MOTION_DURATION;
  @StorageProp(STORAGE_KEY_MOTION_DAMPING) private motionDamping: number = DEFAULT_MOTION_DAMPING;
  @State private expandedMethods: string[] = [];
  @State private linkFailed: boolean = false;

  private surface(): ResourceColor {
    return pageReadingSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), this.pageBackground);
  }

  private textColor(secondary: boolean = false): ResourceColor {
    return pageTextColor(secondary ? $r('app.color.text_secondary') : $r('app.color.text_primary'),
      this.pageBackground, this.surface());
  }

  private toggle(method: string): void {
    const next: string[] = this.expandedMethods.includes(method) ?
      this.expandedMethods.filter((value: string): boolean => value !== method) :
      this.expandedMethods.concat([method]);
    this.linkFailed = false;
    if (this.reduceMotion) {
      this.expandedMethods = next;
      return;
    }
    this.getUIContext().animateTo({ duration: this.motionDuration,
      curve: curves.springMotion(this.motionDuration / 1000, this.motionDamping) }, (): void => {
      this.expandedMethods = next;
    });
  }

  private brandColor(method: string): Resource {
    if (method === 'wechat') { return $r('app.color.support_wechat'); }
    if (method === 'alipay') { return $r('app.color.support_alipay'); }
    return $r('app.color.support_afdian');
  }

  private iconSurface(method: string): Resource {
    if (method === 'wechat') { return $r('app.color.support_wechat_surface'); }
    if (method === 'alipay') { return $r('app.color.support_alipay_surface'); }
    return $r('app.color.support_afdian_surface');
  }

  private async openAfdian(): Promise<void> {
    this.linkFailed = false;
    try {
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await context.startAbility({ action: 'ohos.want.action.viewData',
        entities: ['entity.system.browsable'], uri: AFDIAN_PRODUCT_URL });
    } catch (error) {
      this.linkFailed = true;
    }
  }

  @Builder
  private MethodIcon(method: string): void {
    Stack() {
      if (method === 'afdian') {
        SymbolGlyph($r('sys.symbol.bolt_fill'))
          .fontSize($r('app.float.about_account_icon_size')).fontColor([this.brandColor(method)])
          .accessibilityLevel('no')
      } else {
        Image(method === 'wechat' ? $r('app.media.page_motif_popular_apps_cn_wechat') :
          $r('app.media.page_motif_popular_apps_cn_alipay'))
          .width($r('app.float.about_account_icon_size')).height($r('app.float.about_account_icon_size'))
          .objectFit(ImageFit.Contain).fillColor(this.brandColor(method)).accessibilityLevel('no')
      }
    }
    .width($r('app.float.about_account_button_size')).height($r('app.float.about_account_button_size'))
    .backgroundColor(this.iconSurface(method))
    .borderRadius($r('app.float.about_account_button_radius')).accessibilityLevel('no')
  }

  @Builder
  private AfdianContent(): void {
    Column({ space: $r('app.float.about_gap') }) {
      Text($r('app.string.help_support_afdian_desc')).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_M')).fontColor(this.textColor(true)).width('100%')
      Button($r('app.string.help_support_afdian_buy')).fontFamily(this.appFontFamily)
        .width('100%').backgroundColor($r('app.color.support_afdian_action')).fontColor(Color.White)
        .id('support-afdian-buy')
        .onClick((): void => { this.openAfdian(); })
      Button($r('app.string.supporter_redeem')).fontFamily(this.appFontFamily)
        .width('100%').backgroundColor(secondaryButtonSurfaceColor(this.displayMode, this.darkSurface))
        .fontColor(this.textColor()).id('support-afdian-redeem')
        .onClick((): void => { this.pageStack.pushPath({ name: 'SupporterAccess' }); })
      if (this.linkFailed) {
        Text($r('app.string.about_link_failed')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M')).fontColor($r('app.color.danger')).width('100%')
      }
    }.width('100%')
  }

  @Builder
  private MethodCard(method: string, title: Resource, summary: Resource, expanded: boolean): void {
    Column() {
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Row({ space: $r('app.float.about_row_gap') }) {
          this.MethodIcon(method)
          Column({ space: $r('app.float.about_small_gap') }) {
            Row({ space: $r('app.float.about_account_gap') }) {
              Text(title).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L'))
                .fontWeight(FontWeight.Medium).fontColor(this.brandColor(method))
              if (method === 'afdian') {
                Text($r('app.string.help_support_recommended')).fontFamily(this.appFontFamily)
                  .fontSize($r('sys.float.Body_S')).fontWeight(FontWeight.Medium)
                  .fontColor(this.brandColor(method)).backgroundColor(this.iconSurface(method))
                  .padding({ left: $r('app.float.about_account_gap'), right: $r('app.float.about_account_gap'),
                    top: $r('app.float.about_small_gap'), bottom: $r('app.float.about_small_gap') })
                  .borderRadius($r('app.float.about_account_image_radius')).id('support-afdian-recommended')
              }
            }.width('100%')
            Text(summary).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
              .fontColor(this.textColor(true)).width('100%')
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          SymbolGlyph($r('sys.symbol.chevron_down')).fontSize($r('app.float.about_chevron_size'))
            .fontColor([this.textColor(true)])
            .rotate({ angle: expanded ? 180 : 0 }).accessibilityLevel('no')
        }.width('100%').padding($r('app.float.about_card_inset'))
      }
      .width('100%').padding(0).backgroundColor(Color.Transparent)
      .borderRadius($r('app.float.about_card_radius')).accessibilityText(title)
      .accessibilityDescription(expanded ?
        $r('app.string.help_support_collapse') : $r('app.string.help_support_expand'))
      .id('support-' + method + '-toggle').onClick((): void => { this.toggle(method); })
      if (expanded) {
        Column({ space: $r('app.float.about_gap') }) {
          if (method === 'afdian') {
            this.AfdianContent()
          } else {
            Image(method === 'wechat' ? $r('app.media.support_wechat') : $r('app.media.support_alipay'))
              .width('100%').objectFit(ImageFit.Contain).accessibilityText(title)
              .id('support-' + method + '-qr')
            Text($r('app.string.help_support_scan_code')).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_M')).fontColor(this.textColor(true)).width('100%')
          }
        }.width('100%').padding({ left: $r('app.float.about_card_inset'),
          right: $r('app.float.about_card_inset'), bottom: $r('app.float.about_card_inset') })
          .renderGroup(true).transition(this.reduceMotion ? TransitionEffect.IDENTITY : TransitionEffect.OPACITY)
      }
    }.width('100%').backgroundColor(this.surface()).borderRadius($r('app.float.about_card_radius'))
      .border({ width: 1, color: method === 'afdian' ? $r('app.color.support_afdian_outline') : Color.Transparent })
      .clip(true).geometryTransition(this.reduceMotion ? '' : 'support-' + method + '-surface', { follow: true })
      .transition(this.reduceMotion ? TransitionEffect.IDENTITY : TransitionEffect.OPACITY)
      .id('support-' + method + (expanded ? '-expanded' : '-collapsed'))
  }

  @Builder
  private PaymentMethod(method: string, title: Resource, summary: Resource): void {
    Column() {
      if (this.expandedMethods.includes(method)) {
        this.MethodCard(method, title, summary, true)
      } else {
        this.MethodCard(method, title, summary, false)
      }
    }.width('100%').id('support-' + method + '-card')
  }

  build(): void {
    Column({ space: $r('app.float.about_gap') }) {
      this.PaymentMethod('afdian', $r('app.string.help_support_afdian'), $r('app.string.help_support_afdian_summary'))
      this.PaymentMethod('wechat', $r('app.string.help_support_wechat'), $r('app.string.help_support_qr_summary'))
      this.PaymentMethod('alipay', $r('app.string.help_support_alipay'), $r('app.string.help_support_qr_summary'))
    }.width('100%').direction(Direction.Auto).id('support-payment-methods')
  }
}
