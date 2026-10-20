// Adapted from Petrelgram's PatternTileLayer (Apache-2.0). Preserve each
// original SVG's aspect ratio and tile horizontally at the viewport's height.
import { pagePatternOpacity } from '../utils/PageBackgroundContrast';

@Component
export struct ChatBackgroundPattern {
  @Prop pattern: Resource | undefined = undefined;
  @Prop strength: number = 1;
  @Prop blurRadius: number = 0;
  @Prop aspect: number = 1440 / 2960;
  @Prop ink: number = -1;
  @Prop fixedWidth: number = 0;
  @Prop fixedHeight: number = 0;
  @Prop syncImages: boolean = false;
  @State private viewportWidth: number = 360;
  @State private viewportHeight: number = 640;

  private contentHeight(): number { return this.fixedHeight > 0 ? this.fixedHeight : this.viewportHeight; }
  private tileWidth(): number { return this.contentHeight() * this.aspect; }

  private filter(): ColorFilter {
    return this.ink < 0 ? new ColorFilter([1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0]) :
      new ColorFilter([0, 0, 0, this.ink, 0, 0, 0, 0, this.ink, 0, 0, 0, 0, this.ink, 0, 0, 0, 0, 1, 0]);
  }

  private indices(): number[] {
    const result: number[] = [];
    const width: number = this.fixedWidth > 0 ? this.fixedWidth : this.viewportWidth;
    const count: number = Math.max(1, Math.ceil(width / this.tileWidth()));
    for (let i: number = 0; i < count; i++) { result.push(i); }
    return result;
  }

  build(): void {
    Stack() {
      Row() {
        ForEach(this.indices(), (index: number) => {
          Image(this.pattern).width(this.tileWidth()).height(this.contentHeight())
            .sourceSize({ width: this.tileWidth() * 2, height: this.contentHeight() * 2 })
            .autoResize(false).objectFit(ImageFit.Cover).draggable(false).colorFilter(this.filter()).syncLoad(this.syncImages)
        }, (index: number): string => index.toString())
      }.width(this.indices().length * this.tileWidth()).height(this.contentHeight())
        .opacity(pagePatternOpacity(this.strength, this.ink))
        .scale({ x: this.blurRadius > 0 ? 1.08 : 1, y: this.blurRadius > 0 ? 1.08 : 1 })
        .blur(this.blurRadius).renderGroup(true)
    }.width('100%').height('100%').clip(true).hitTestBehavior(HitTestMode.None)
      .onAreaChange((_old: Area, area: Area): void => {
        const width: number = Number(area.width);
        const height: number = Number(area.height);
        if (this.fixedWidth <= 0 && this.fixedHeight <= 0 && width > 0 && height > 0) {
          this.viewportWidth = width; this.viewportHeight = height;
        }
      })
  }
}
