// The root pull-to-refresh spinner.
//
// Every root tab mounts its Refresh container at the very top of the page so
// the timeline can run under the title-bar material. That material also covers
// Refresh's own spinner, which is why the platform animation is invisible on
// the phone layout. This layer sits below the title bar instead and is fed the
// live pull offset, so it appears exactly where the content that Refresh is
// displacing opens up.
//
// The offset and the flags arrive as @Prop, so a parent state change keeps the
// spinner in step with the gesture; passing them as @Builder arguments would
// freeze them at their first value.
@Component
export struct RootRefreshIndicator {
  @Prop topInset: number = 0;
  @Prop pullOffset: number = 0;
  @Prop refreshing: boolean = false;
  // The phone layout draws the title bar over the page. The desktop shell keeps
  // its header in normal flow, so there Refresh's own spinner is already clear.
  @Prop phoneLayout: boolean = true;
  @StorageLink('harmonyx.accent_color') accentColor: string = '#007DFF';

  build() {
    Row() {
      LoadingProgress()
        .width($r('app.float.root_refresh_indicator_size'))
        .height($r('app.float.root_refresh_indicator_size'))
        .color(this.accentColor)
    }
    .height($r('app.float.root_refresh_indicator_height'))
    .justifyContent(FlexAlign.Center)
    .margin({ top: this.phoneLayout ? this.topInset : 0 })
    // Opacity rather than add/remove: the spinner appears and disappears while
    // the finger is moving, and a conditional node would re-measure the stack.
    .opacity(this.phoneLayout && (this.refreshing || this.pullOffset > 0) ? 1 : 0)
    .hitTestBehavior(HitTestMode.None)
  }
}
