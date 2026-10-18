// Keep the cover outside Refresh. Pull gestures scale its render layer from
// the top edge, so neither status-bar coverage nor list layout changes.
@Component
export struct AnchoredCover {
  @Prop coverHeight: number = 164;
  @Prop pullOffset: number = 0;
  @Prop scrollOffset: number = 0;
  @BuilderParam coverBuilder: () => void = this.EmptyCover;

  @Builder
  private EmptyCover(): void { Column() }

  private pullScale(): number {
    return 1 + Math.max(0, this.pullOffset) / Math.max(1, this.coverHeight);
  }

  build(): void {
    Stack() { this.coverBuilder() }
      .width('100%').height(this.coverHeight).clip(true).renderGroup(true)
      .scale({ x: this.pullScale(), y: this.pullScale(), centerX: '50%', centerY: 0 })
      .translate({ y: -Math.max(0, this.scrollOffset) })
      .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
  }
}
