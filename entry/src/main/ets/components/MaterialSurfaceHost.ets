import { MaterialCompat } from '../utils/MaterialCompat';

// Navigation enables native material on its custom title. Its internal NavBar
// clips unconditionally, so inset the unchanged surface inside a larger host.
@Component
export struct MaterialSurfaceHost {
  @Prop surfaceHeight: number = 64;
  @BuilderParam surfaceContent: () => void = this.EmptyContent;
  @State private overflowMargin: number = 0;
  @State private surfaceWidth: number = 0;

  aboutToAppear(): void {
    this.overflowMargin = this.getUIContext().px2vp(
      getContext(this).resourceManager.getNumber($r('app.float.material_surface_overflow').id));
  }

  private hostWidth(): string {
    return 'calc(100% + ' + (this.overflowMargin * 2).toString() + 'vp)';
  }

  private contentWidth(): string {
    return 'calc(100% - ' + (this.overflowMargin * 2).toString() + 'vp)';
  }

  @Builder
  private EmptyContent(): void {}

  @Builder
  private TitleContent(): void {
    Stack({ alignContent: Alignment.Center }) {
      Stack() { this.surfaceContent(); }
        .width(this.contentWidth()).height(this.surfaceHeight)
        .clip(false)
    }
    .width('100%').height(this.surfaceHeight + this.overflowMargin * 2)
    .clip(false)
    .hitTestBehavior(HitTestMode.Transparent)
  }

  build(): void {
    Stack({ alignContent: Alignment.TopStart }) {
      Navigation() {
        Column().width('100%').height('100%').hitTestBehavior(HitTestMode.None)
      }
      .title({ builder: (): void => { this.TitleContent(); },
        height: this.surfaceHeight + this.overflowMargin * 2 }, {
        barStyle: BarStyle.STACK, backgroundColor: Color.Transparent,
        backgroundBlurStyle: MaterialCompat.NO_PLATE_BLUR
      })
      .titleMode(NavigationTitleMode.Full).mode(NavigationMode.Stack)
      .hideBackButton(true).hideToolBar(true)
      .width(this.hostWidth()).height(this.surfaceHeight + this.overflowMargin * 2)
      .position({ x: -this.overflowMargin, y: -this.overflowMargin })
      .responseRegion({ x: this.overflowMargin, y: this.overflowMargin,
        width: this.surfaceWidth, height: this.surfaceHeight })
      .backgroundColor(Color.Transparent)
      .hitTestBehavior(HitTestMode.Transparent)
      .clip(false)
    }
    .width('100%').height(this.surfaceHeight)
    .onAreaChange((_old: Area, area: Area): void => {
      const width: number = Number(area.width);
      if (width > 0 && width !== this.surfaceWidth) { this.surfaceWidth = width; }
    })
    .clip(false)
    .hitTestBehavior(HitTestMode.Transparent)
  }
}
