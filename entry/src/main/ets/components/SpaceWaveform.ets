@Component
export struct SpaceWaveform {
  @Prop active: boolean = true;
  @Prop color: ResourceColor = $r('app.color.space_accent');
  @Prop waveformSize: number = 24;
  @State private moving: boolean = false;

  @Builder
  private Bar(index: number): void {
    Column().width(this.waveformSize / 7).height(this.waveformSize)
      .borderRadius(this.waveformSize / 14).backgroundColor(this.color)
      .scale({ y: this.active && this.moving ? (index === 1 ? 0.35 : 1) : (index === 1 ? 0.85 : 0.4) })
      .animation({ duration: 580 + index * 170, curve: Curve.EaseInOut,
        iterations: this.active && this.moving ? -1 : 1, playMode: PlayMode.Alternate })
  }

  build(): void {
    Row({ space: this.waveformSize / 7 }) { this.Bar(0); this.Bar(1); this.Bar(2); }
      .width(this.waveformSize).height(this.waveformSize).alignItems(VerticalAlign.Center)
      .accessibilityLevel('no').hitTestBehavior(HitTestMode.None)
      .onVisibleAreaChange([0, 0.1], (visible: boolean, ratio: number): void => { this.moving = visible && ratio > 0; })
  }
}
