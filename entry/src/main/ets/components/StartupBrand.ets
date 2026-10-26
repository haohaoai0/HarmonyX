import { ColorMetrics } from '@kit.ArkUI';
import { APP_ICON_X_BLACK, APP_ICON_X_WHITE, appIconForeground,
  STORAGE_KEY_CURRENT_APP_ICON } from '../services/AppIconStore';

// First-frame artwork, type and spacing. Keep account/network/feed imports out.
@Component
export struct StartupBrand {
  @Prop compact: boolean = false;
  @Prop subtitle: ResourceStr = '';
  @StorageProp(STORAGE_KEY_CURRENT_APP_ICON) private iconName: string = '';

  private foreground(): Resource { return appIconForeground(this.iconName); }

  private markColorFilter(): ColorFilter {
    // The two monochrome X choices share their exact launcher foreground;
    // only ink follows the page theme so white-on-white never disappears.
    if (this.iconName === APP_ICON_X_BLACK || this.iconName === APP_ICON_X_WHITE) {
      const ink: ColorMetrics = ColorMetrics.resourceColor($r('app.color.text_primary'));
      return new ColorFilter([0, 0, 0, ink.red / 255, 0, 0, 0, 0, ink.green / 255, 0,
        0, 0, 0, ink.blue / 255, 0, 0, 0, 0, 1, 0]);
    }
    return new ColorFilter([1, 0, 0, 0, 0, 0, 1, 0, 0, 0,
      0, 0, 1, 0, 0, 0, 0, 0, 1, 0]);
  }

  build(): void {
    if (this.compact) {
      Row({ space: 10 }) {
        Image(this.foreground()).width(36).height(36).objectFit(ImageFit.Contain)
          .colorFilter(this.markColorFilter()).accessibilityLevel('no')
        Column({ space: 3 }) {
          Text($r('app.string.EntryAbility_label')).fontSize($r('app.float.splash_ad_brand_size'))
            .fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary')).maxLines(1)
          Text(this.subtitle).fontSize($r('app.float.splash_ad_caption_size'))
            .fontColor($r('app.color.splash_ad_muted')).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      }.width('100%').height('100%')
    } else {
    Stack() {
      Column({ space: 20 }) {
        Image(this.foreground())
          .width($r('app.float.startup_mark_size'))
          .height($r('app.float.startup_mark_size'))
          .objectFit(ImageFit.Contain)
          .colorFilter(this.markColorFilter())
          .accessibilityLevel('no')
        Text($r('app.string.EntryAbility_label'))
          .fontSize($r('app.float.startup_name_size'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .padding({ left: 24, right: 24 })
      .constraintSize({ maxWidth: 360 })
    }
    .width('100%').height('100%')
    .backgroundColor($r('app.color.start_window_background'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    }
  }
}
