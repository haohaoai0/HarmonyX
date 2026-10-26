import { HdsNavDestination, HdsNavDestinationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { appPageBackground } from '../components/PageBackgroundLayer';
import { SupporterActivationCard } from '../components/SupporterActivationCard';
import { SupportPaymentCards } from '../components/SupportPaymentCards';
import { destinationTitleBarStyle } from '../utils/DestinationTitleBar';
import { pageCanvasColor } from '../utils/ThemeColors';
import { pageSystemTransition, PageTransitionMotion } from '../utils/PageTransition';
import { DEFAULT_PAGE_TRANSITION_MODE, STORAGE_KEY_PAGE_TRANSITION_MODE } from '../services/PageTransitionSettingsStore';

@Builder
export function SupportBuilder(): void { SupportPage() }

@Builder
export function SupporterAccessBuilder(): void { SupportPage({ activation: true }) }

// Payment methods expand on the support page; account-bound redemption stays
// in its existing destination.
@Component
struct SupportPage {
  @Prop activation: boolean = false;
  @Consume('pageStack') private pageStack: NavPathStack;
  @StorageProp('harmonyx.page_background') private pageBackground: string = '';
  @StorageProp('harmonyx.display_mode') private displayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private darkSurface: string = '';
  @StorageProp('harmonyx.title_bar_style_mode') private titleBarStyleMode: number = 0;
  @StorageProp('harmonyx.status_bar_height') private statusBarHeight: number = 0;
  @StorageProp('harmonyx.navigation_indicator_height') private bottomInset: number = 0;
  @StorageProp(STORAGE_KEY_PAGE_TRANSITION_MODE) private transitionMode: string = DEFAULT_PAGE_TRANSITION_MODE;
  @State private pageMotion: PageTransitionMotion = new PageTransitionMotion();
  private scroller: Scroller = new Scroller();

  build(): void {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.Top }) {
        appPageBackground()
        Scroll(this.scroller) {
          Column({ space: 24 }) {
            if (this.activation) {
              SupporterActivationCard()
            } else {
              SupportPaymentCards()
            }
          }
          .width('100%').constraintSize({ maxWidth: 480 })
          .padding({ left: 24, right: 24, top: this.statusBarHeight + 72, bottom: this.bottomInset + 28 })
        }.width('100%').height('100%').scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true }).align(Alignment.Top)
      }.width('100%').height('100%')
    }
    .scale({ x: this.pageMotion.scale, y: this.pageMotion.scale }).opacity(this.pageMotion.opacity)
    .onReady((context: NavDestinationContext): void => this.pageMotion.attach(context))
    .systemTransition(pageSystemTransition(this.transitionMode))
    .titleMode(HdsNavDestinationTitleMode.MINI).bindToScrollable([this.scroller])
    .titleBar({
      avoidLayoutSafeArea: true,
      content: {
        title: { mainTitle: this.activation ? $r('app.string.supporter_title') : $r('app.string.side_support') },
        menu: { value: this.activation ? [] : [{ content: {
          icon: $r('sys.symbol.checkmark_shield'), label: $r('app.string.supporter_redeem'),
          action: (): void => { this.pageStack.pushPath({ name: 'SupporterAccess' }); }
        } }] }
      },
      style: destinationTitleBarStyle(ScrollEffectType.GRADIENT_BLUR, this.displayMode, this.darkSurface, this.titleBarStyleMode)
    })
    .backgroundColor(pageCanvasColor(this.displayMode, this.darkSurface, this.pageBackground))
  }
}
