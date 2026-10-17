import { FrameCallback, RectShape } from '@kit.ArkUI';
import { fittedMediaViewerRect, MediaViewerMotionState, MediaViewerRect } from '../utils/MediaViewerMotion';

export class MediaViewerMotionFrame extends FrameCallback {
  private action: () => void;
  constructor(action: () => void) { super(); this.action = action; }
  onFrame(_frameTimeInNano: number): void { this.action(); }
}

@Component
export struct MediaViewerMotion {
  @ObjectLink motion: MediaViewerMotionState;
  @Prop surfaceId: string = '';
  @Prop targetId: string = '';
  @Prop mediaWidth: number = 0;
  @Prop mediaHeight: number = 0;
  @Prop targetContainsMedia: boolean = true;
  @Prop @Watch('scheduleOpen') contentReady: boolean = false;
  @Prop @Watch('scheduleOpen') presentation: number = 0;
  @StorageProp('reduceMotionEnabled') private reduceMotion: boolean = false;
  @BuilderParam content: () => void;
  private mounted: boolean = false;
  private scheduled: boolean = false;
  private revision: number = 0;

  private viewport(): MediaViewerRect | undefined {
    try {
      const ui = this.getUIContext();
      const rect = ui.getComponentUtils().getRectangleById(this.surfaceId);
      const result: MediaViewerRect = new MediaViewerRect();
      result.x = ui.px2vp(rect.windowOffset.x);
      result.y = ui.px2vp(rect.windowOffset.y);
      result.width = ui.px2vp(rect.size.width);
      result.height = ui.px2vp(rect.size.height);
      return result.width > 1 && result.height > 1 ? result : undefined;
    } catch (_error) { return undefined; }
  }

  private target(viewport: MediaViewerRect): MediaViewerRect {
    const frame: MediaViewerRect = new MediaViewerRect();
    frame.width = viewport.width;
    frame.height = viewport.height;
    if (this.targetId.length > 0) {
      try {
        const ui = this.getUIContext();
        const rect = ui.getComponentUtils().getRectangleById(this.targetId);
        if (rect.size.width > 0 && rect.size.height > 0) {
          frame.x = ui.px2vp(rect.windowOffset.x) - viewport.x;
          frame.y = ui.px2vp(rect.windowOffset.y) - viewport.y;
          frame.width = ui.px2vp(rect.size.width);
          frame.height = ui.px2vp(rect.size.height);
        }
      } catch (_error) { /* The media viewport itself remains a valid target. */ }
    }
    return fittedMediaViewerRect(this.mediaWidth, this.mediaHeight, frame, this.targetContainsMedia);
  }

  private scheduleOpen(): void {
    if (!this.mounted || !this.contentReady || !this.motion.waiting() || this.scheduled) { return; }
    this.scheduled = true;
    const revision: number = this.revision;
    this.getUIContext().postFrameCallback(new MediaViewerMotionFrame((): void => {
      this.scheduled = false;
      if (!this.mounted || revision !== this.revision || !this.motion.waiting()) { return; }
      const viewport: MediaViewerRect | undefined = this.viewport();
      if (viewport === undefined) { return; }
      if (this.motion.stage(viewport, this.target(viewport))) {
        // Commit the card frame before animating, so a 0→1 mutation in one
        // render transaction cannot make the destination jump to fullscreen.
        this.getUIContext().postFrameCallback(new MediaViewerMotionFrame((): void => {
          if (this.mounted && revision === this.revision) {
            this.motion.open(this.getUIContext(), this.reduceMotion);
          }
        }));
      }
    }));
  }

  aboutToDisappear(): void { this.mounted = false; ++this.revision; this.motion.detach(); }

  build(): void {
    Stack({ alignContent: Alignment.TopStart }) {
      Stack({ alignContent: Alignment.TopStart }) { this.content() }
        .width('100%').height('100%')
        .scale({ x: this.motion.scale, y: this.motion.scale, centerX: 0, centerY: 0 })
        .translate({ x: this.motion.offsetX, y: this.motion.offsetY })
    }.width('100%').height('100%').id(this.surfaceId)
      .clipShape(this.motion.clipping ? new RectShape({ width: this.motion.clipWidth, height: this.motion.clipHeight })
        .offset({ x: this.motion.clipX, y: this.motion.clipY }).radius(this.motion.radius) : undefined)
      .opacity(this.motion.visible ? this.motion.opacity : 0)
      .enabled(this.motion.interactive)
      .onAppear((): void => { this.mounted = true; this.scheduleOpen(); })
      .onAreaChange((): void => {
        if (this.motion.waiting()) { this.scheduleOpen(); return; }
        const viewport: MediaViewerRect | undefined = this.viewport();
        if (viewport !== undefined) { this.motion.resized(viewport); }
      })
  }
}
