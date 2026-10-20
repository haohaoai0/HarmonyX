// The root page and its settings specimen use exactly the same slot geometry.
@Component
export struct RootTitleBarIdentity {
  @Prop showLogo: boolean = true;
  @BuilderParam avatar: () => void = this.Empty;
  @BuilderParam center: () => void = this.Empty;
  @BuilderParam action: () => void = this.Empty;
  @BuilderParam logo: () => void = this.Empty;

  @Builder
  private Empty(): void {}

  build(): void {
    Stack({ alignContent: Alignment.Center }) {
      Row() {
        this.avatar()
        if (this.showLogo) { Blank() }
        else {
          Row() { this.center() }.layoutWeight(1).height($r('app.float.title_bar_compact_row_height'))
            .margin({ left: $r('app.float.title_bar_compact_gap'), right: $r('app.float.title_bar_compact_gap') })
        }
        this.action()
      }.width('100%')
      if (this.showLogo) { this.logo() }
    }.width('100%').height('100%')
  }
}
