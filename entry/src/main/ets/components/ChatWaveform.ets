import { ChatVoice } from '../utils/ChatVoice';

@Component
export struct ChatWaveform {
  @Prop samples: number[] = [];
  @Prop progress: number = 0;
  @Prop foreground: ResourceColor = '#FFFFFF';
  @Prop dim: ResourceColor = '#99FFFFFF';
  @Prop seekable: boolean = false;
  onSeek: (fraction: number) => void = (): void => {};
  build(): void {
    Stack() {
      Row({ space: 2 }) {
        ForEach(ChatVoice.bars(this.samples), (amplitude: number, index: number) => {
          Column().height(Math.max(3, amplitude * 36)).layoutWeight(1).borderRadius(3)
            .backgroundColor(index / 32 <= this.progress ? this.foreground : this.dim)
        }, (_amplitude: number, index: number): string => index.toString())
      }.width('100%').height(40).alignItems(VerticalAlign.Center).hitTestBehavior(HitTestMode.None)
      if (this.seekable) {
        Slider({ value: this.progress, min: 0, max: 1, step: 0.001 }).width('100%').height(40).opacity(0)
          .accessibilityText($r('app.string.chat_voice_seek'))
          .onChange((value: number, mode: SliderChangeMode): void => {
            if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) { this.onSeek(value); }
          })
      }
    }.width('100%').height(40)
  }
}
