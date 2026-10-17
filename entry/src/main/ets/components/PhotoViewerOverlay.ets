import { HdsNavigation } from '@kit.UIDesignKit';

// A window-sized navigation layer keeps the desktop pane and its live photo
// sources mounted at the same size throughout the viewer's open/return motion.
@Component
export struct PhotoViewerOverlay {
  @Provide({ allowOverride: 'pageStack' }) pageStack: NavPathStack = new NavPathStack();
  @BuilderParam destinationBuilder: (name: string) => void;
  @Prop active: boolean = false;

  build(): void {
    HdsNavigation(this.pageStack) {
      Column().width('100%').height('100%').hitTestBehavior(HitTestMode.None)
    }
    .mode(NavigationMode.Stack)
    .hideTitleBar(true)
    .hideBackButton(true)
    .navDestination(this.destinationBuilder)
    .width('100%').height('100%')
    .backgroundColor(Color.Transparent)
    .visibility(this.active ? Visibility.Visible : Visibility.Hidden)
    .enabled(this.active)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM,
      LayoutSafeAreaEdge.START, LayoutSafeAreaEdge.END])
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM,
      SafeAreaEdge.START, SafeAreaEdge.END])
    .id('photo-viewer-overlay')
  }
}
