import { HdsNavigation } from '@kit.UIDesignKit';
import { PhotoViewer, PhotoViewerRouteParam } from '../pages/PhotoViewer';
import { PhotoRequest } from '../utils/PhotoViewerRequest';

// The sheet owns this stack. Descendant actions still consume the app's
// pageStack; closing the photo returns to the mounted comment list below it.
@Component
export struct CommentPhotoViewer {
  @Prop request: PhotoRequest;
  @Prop viewportHeight: number = 0;
  onBack: () => void = (): void => {};
  private viewerStack: NavPathStack = new NavPathStack();

  private viewerHeight(): number | string {
    return this.viewportHeight > 0 ? this.viewportHeight : '100%';
  }

  aboutToAppear(): void {
    const route: PhotoViewerRouteParam = {
      urls: this.request.urls, items: this.request.items, index: this.request.index,
      alt: this.request.alt, transitionPrefix: '', commentPreview: true,
      onCommentPreviewBack: (): void => this.onBack()
    };
    this.viewerStack.pushPath({ name: 'CommentPhoto', param: route }, false);
  }

  @Builder
  private Destination(_name: string, _param: Object): void {
    PhotoViewer()
  }

  build(): void {
    Stack({ alignContent: Alignment.Top }) {
      HdsNavigation(this.viewerStack) {
        Column().width('100%').height('100%')
      }
      .mode(NavigationMode.Stack)
      .hideTitleBar(true)
      .navDestination(this.Destination)
      .width('100%').height(this.viewerHeight())
      .constraintSize({ minHeight: this.viewerHeight(), maxHeight: this.viewerHeight() })
      .backgroundColor(Color.Black)
      .clip(false)
      .id('comment-photo-viewer')
    }
    .width('100%').height('100%')
    .clip(false)
    .id('comment-photo-viewport')
  }
}
