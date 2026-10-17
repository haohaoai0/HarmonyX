// Adapted from Petrelgram's PatternTileLayer (Apache-2.0). Preserve each
// original SVG's aspect ratio and tile horizontally at the viewport's height.
@Component
export struct ChatBackgroundPattern {
  @Prop pattern: Resource | undefined = undefined;
  @Prop strength: number = 1;
  @Prop blurRadius: number = 0;
  @Prop aspect: number = 1440 / 2960;
  @State private viewportWidth: number = 360;
  @State private viewportHeight: number = 640;

  private tileWidth(): number { return this.viewportHeight * this.aspect; }

  private indices(): number[] {
    const result: number[] = [];
    const count: number = Math.max(1, Math.ceil(this.viewportWidth / this.tileWidth()));
    for (let i: number = 0; i < count; i++) { result.push(i); }
    return result;
  }

  build(): void {
    Stack() {
      Row() {
        ForEach(this.indices(), (index: number) => {
          Image(this.pattern).width(this.tileWidth()).height(this.viewportHeight)
            .sourceSize({ width: this.tileWidth() * 2, height: this.viewportHeight * 2 })
            .autoResize(false).objectFit(ImageFit.Cover).draggable(false)
        }, (index: number): string => index.toString())
      }.width(this.indices().length * this.tileWidth()).height(this.viewportHeight)
        .opacity(0.5 * this.strength)
        .scale({ x: this.blurRadius > 0 ? 1.08 : 1, y: this.blurRadius > 0 ? 1.08 : 1 })
        .blur(this.blurRadius).renderGroup(true)
    }.width('100%').height('100%').clip(true).hitTestBehavior(HitTestMode.None)
      .onAreaChange((_old: Area, area: Area): void => {
        const width: number = Number(area.width);
        const height: number = Number(area.height);
        if (width > 0 && height > 0) { this.viewportWidth = width; this.viewportHeight = height; }
      })
  }
}
