import { SplashAdCreative } from '../models/SplashAd';
import { StartupBrand } from './StartupBrand';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';
import { effectiveAppLocale, isAppRtl, STORAGE_KEY_APP_LOCALE } from '../utils/AppLocale';

@Component
export struct SplashAdSurface {
  @Prop creative: SplashAdCreative = new SplashAdCreative();
  @Prop remainingSeconds: number = 3;
  @Prop totalSeconds: number = 3;
  onSkip: () => void = (): void => {};
  onOpen: () => void = (): void => {};
  onUnavailable: () => void = (): void => {};
  onArtworkReady: () => void = (): void => {};
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp(STORAGE_KEY_APP_LOCALE) private appLocale: string = effectiveAppLocale();
  @StorageProp('harmonyx.window_width') private windowWidth: number = 390;
  @StorageProp('harmonyx.window_height') private windowHeight: number = 844;
  @StorageProp('harmonyx.status_bar_height') private topInset: number = 0;
  @StorageProp('harmonyx.navigation_indicator_height') private bottomInset: number = 0;
  @StorageProp('reduceMotionEnabled') private reduceMotion: boolean = false;

  private sideBySide(): boolean {
    return ResponsiveLayout.breakpointForWidth(this.windowWidth) !== ResponsiveLayout.BREAKPOINT_SM ||
      ResponsiveLayout.heightBreakpoint(this.windowWidth, this.windowHeight) === ResponsiveLayout.BREAKPOINT_SM;
  }

  private compact(): boolean { return this.windowHeight > 0 && this.windowHeight < 500; }

  private progress(): number {
    if (!Number.isFinite(this.remainingSeconds) || !Number.isFinite(this.totalSeconds) || this.totalSeconds <= 0) {
      return 0;
    }
    return Math.max(0, Math.min(100, this.remainingSeconds / this.totalSeconds * 100));
  }

  private tileImage(index: number): ResourceStr {
    return this.creative.images.length > 0 ?
      this.creative.images[index % this.creative.images.length] : this.creative.artwork;
  }

  @Builder
  private MosaicTile(index: number, x: number, y: number, width: number, height: number): void {
    Image(this.tileImage(index)).width(width + '%').height(height + '%')
      .objectFit(ImageFit.Cover).draggable(false)
      .borderRadius($r('app.float.splash_ad_tile_radius'))
      .border({ width: 0.5, color: $r('app.color.splash_ad_glass_border') })
      .position({ x: x + '%', y: y + '%' })
      .onComplete((): void => { if (index === 0) { this.onArtworkReady(); } })
      .onError((): void => { if (index === 0) { this.onUnavailable(); } })
      .accessibilityLevel('no').hitTestBehavior(HitTestMode.None)
  }

  @Builder
  private TileMosaic(): void {
    Stack() {
      if (this.sideBySide()) {
        this.MosaicTile(0, -2, -10, 21, 110)
        this.MosaicTile(1, 21, -30, 18, 108)
        this.MosaicTile(2, 41, 4, 18, 110)
        this.MosaicTile(3, 61, -12, 18, 112)
        this.MosaicTile(4, 81, -30, 21, 110)
        this.MosaicTile(5, 21, 80, 18, 108)
        this.MosaicTile(6, 81, 82, 21, 110)
      } else {
      this.MosaicTile(0, -3, -6, 44, 54)
      this.MosaicTile(1, 44, -12, 28, 37)
      this.MosaicTile(2, 75, -3, 30, 42)
      this.MosaicTile(3, 44, 27, 28, 37)
      this.MosaicTile(4, 75, 41, 30, 44)
      this.MosaicTile(5, -3, 50, 44, 54)
      this.MosaicTile(6, 44, 66, 28, 39)
      this.MosaicTile(7, 75, 87, 30, 42)
      }
    }.width('100%').height('100%').clip(true).renderGroup(true)
      .id('splash-ad-mosaic')
  }

  @Builder
  private Header(): void {
    Row() {
      Text($r('app.string.splash_ad_label')).fontFamily(this.appFontFamily)
        .fontSize($r('app.float.splash_ad_caption_size')).fontColor($r('app.color.splash_ad_muted'))
        .padding({ left: 10, right: 10, top: 5, bottom: 5 })
        .borderRadius(8).border({ width: 0.5, color: $r('app.color.splash_ad_hairline') })
      Blank()
      Button({ type: ButtonType.Capsule }) {
        Row({ space: 8 }) {
          Text($r('app.string.splash_ad_skip')).fontFamily(this.appFontFamily)
            .fontSize($r('app.float.splash_ad_body_size')).fontColor($r('app.color.splash_ad_ink'))
          if (this.remainingSeconds > 0) {
            Stack() {
              Progress({ value: this.progress(), total: 100, type: ProgressType.Ring })
                .width(24).height(24).color($r('app.color.splash_ad_ink'))
                .backgroundColor($r('app.color.splash_ad_hairline'))
                .style({ strokeWidth: 1.5, enableSmoothEffect: !this.reduceMotion })
                .accessibilityLevel('no')
              Text(Math.ceil(this.remainingSeconds).toString()).fontFamily(this.appFontFamily)
                .fontSize($r('app.float.splash_ad_caption_size')).fontColor($r('app.color.splash_ad_ink'))
                .accessibilityLevel('no')
            }.width(24).height(24)
          }
        }.padding({ left: 14, right: 10 })
      }
      .height($r('app.float.splash_ad_control_height'))
      .backgroundColor($r('app.color.splash_ad_control'))
      .accessibilityText($r('app.string.splash_ad_skip'))
      .onClick((): void => this.onSkip()).id('splash-ad-skip')
    }
    .width('100%').height(this.compact() ? 48 : 56)
    .padding({ left: 22, right: 16 })
  }

  @Builder
  private Copy(): void {
    Column({ space: this.compact() ? 6 : 12 }) {
      Row({ space: 6 }) {
        Column().width(5).height(5).borderRadius(3).backgroundColor($r('app.color.splash_ad_lime'))
        Text(this.creative.eyebrow).fontFamily(this.appFontFamily)
          .fontSize($r('app.float.splash_ad_caption_size')).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.splash_ad_lime')).maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      Text(this.creative.title).fontFamily(this.appFontFamily)
        .fontSize(this.compact() ? $r('app.float.splash_ad_compact_title_size') : $r('app.float.splash_ad_title_size'))
        .fontWeight(FontWeight.Bold).fontColor($r('app.color.splash_ad_poster_ink'))
        .lineBreakStrategy(LineBreakStrategy.BALANCED)
        .maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
      if (!this.compact()) {
        Text(this.creative.description).fontFamily(this.appFontFamily)
          .fontSize($r('app.float.splash_ad_body_size')).fontColor($r('app.color.splash_ad_poster_muted'))
          .lineHeight(22).maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private Action(): void {
    Button({ type: ButtonType.Capsule }) {
      Row() {
        Text(this.creative.action).fontFamily(this.appFontFamily)
          .fontSize($r('app.float.splash_ad_body_size')).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.splash_ad_action_ink')).layoutWeight(1)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        SymbolGlyph($r('sys.symbol.arrow_right')).fontSize(20)
          .fontColor([$r('app.color.splash_ad_action_ink')])
          .scale({ x: isAppRtl(this.appLocale) ? -1 : 1 }).accessibilityLevel('no')
      }.width('100%').padding({ left: 22, right: 20 })
    }
    .width('100%').height($r('app.float.splash_ad_action_height'))
    .backgroundColor($r('app.color.splash_ad_lime'))
    .onClick((): void => this.onOpen()).id('splash-ad-open')
  }

  @Builder
  private Artwork(): void {
    Stack() {
      if (this.creative.images.length > 1) {
        this.TileMosaic()
      } else {
        Image(this.creative.artwork).width('100%').height('100%').objectFit(ImageFit.Cover)
          .blur(32).opacity(0.35).draggable(false).accessibilityLevel('no').hitTestBehavior(HitTestMode.None)
        Image(this.creative.artwork).width('100%').height('100%').objectFit(ImageFit.Contain)
          .draggable(false).onError((): void => this.onUnavailable())
          .onComplete((): void => this.onArtworkReady())
          .accessibilityLevel('no').hitTestBehavior(HitTestMode.None)
      }
    }.width('100%').height('100%').clip(true)
  }

  @Builder
  private Poster(): void {
    Stack({ alignContent: Alignment.BottomStart }) {
      this.Artwork()
      if (this.sideBySide()) {
        Row() {
          Blank().layoutWeight(1)
          Column({ space: this.compact() ? 12 : 24 }) {
            Scroll() { this.Copy() }.layoutWeight(1).width('100%').scrollBar(BarState.Off)
            this.Action()
          }.layoutWeight(1).height('100%').justifyContent(FlexAlign.Center)
            .padding(this.compact() ? 16 : 32)
            .linearGradient({ angle: 90, colors: [[$r('app.color.splash_ad_scrim_middle'), 0],
              [$r('app.color.splash_ad_scrim_end'), 1]] })
        }.width('100%').height('100%')
      } else {
        Column().width('100%').height('100%')
          .linearGradient({ angle: 180, colors: [[$r('app.color.splash_ad_scrim_clear'), 0],
            [$r('app.color.splash_ad_scrim_clear'), 0.32],
            [$r('app.color.splash_ad_scrim_middle'), 0.58], [$r('app.color.splash_ad_scrim_end'), 1]] })
          .hitTestBehavior(HitTestMode.None)
        Column({ space: 24 }) {
          this.Copy()
          this.Action()
        }.width('100%').padding({ left: 28, right: 28, bottom: 28 })
      }
      Row() {
        if (this.creative.icon !== '') {
          Image(this.creative.icon).width(24).height(24).objectFit(ImageFit.Contain)
            .borderRadius(6).margin({ right: 8 }).accessibilityLevel('no')
        }
        Text(this.creative.advertiser).fontFamily(this.appFontFamily)
          .fontSize($r('app.float.splash_ad_caption_size')).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.splash_ad_poster_ink')).maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .backgroundColor($r('app.color.splash_ad_glass')).borderRadius(20)
          .border({ width: 0.5, color: $r('app.color.splash_ad_glass_border') })
      }.width('100%').padding(20).position({ x: 0, y: 0 })
        .hitTestBehavior(HitTestMode.None)
    }
    .width('100%').height('100%').backgroundColor($r('app.color.splash_ad_poster'))
    .borderRadius($r('app.float.splash_ad_poster_radius')).clip(true).id('splash-ad-poster')
  }

  @Builder
  private Signature(): void {
    Row() {
      StartupBrand({ compact: true, subtitle: $r('app.string.splash_ad_signature') })
        .layoutWeight(1).height(48)
    }.width('100%').height(this.compact() ? 58 : 88)
      .padding({ left: 24, right: 24 })
  }

  build(): void {
    Column() {
      this.Header()
      Row() { this.Poster() }.width('100%').layoutWeight(1).padding({ left: 12, right: 12 })
      this.Signature()
    }
    .width('100%').height('100%')
    .padding({ top: this.topInset + 4, bottom: this.bottomInset })
    .backgroundColor($r('app.color.splash_ad_canvas'))
    .direction(isAppRtl(this.appLocale) ? Direction.Rtl : Direction.Ltr)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .id('splash-ad-surface')
  }
}
