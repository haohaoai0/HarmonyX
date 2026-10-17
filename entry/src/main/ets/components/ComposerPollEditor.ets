import { ComposerOptions } from '../models/ComposerOptions';
import { photoAccessHelper } from '@kit.MediaLibraryKit';

@Component
export struct ComposerPollEditor {
  @Link options: ComposerOptions;
  @Prop disabled: boolean = false;
  @Prop accentColor: string = '#007DFF';
  onChange: () => void = (): void => {};

  private async chooseImage(index: number): Promise<void> {
    const choices: string[] = this.options.pollChoices;
    try {
      const picker: photoAccessHelper.PhotoViewPicker = new photoAccessHelper.PhotoViewPicker();
      const settings: photoAccessHelper.PhotoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
      settings.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE; settings.maxSelectNumber = 1;
      const result: photoAccessHelper.PhotoSelectResult = await picker.select(settings);
      if (this.disabled || result.photoUris.length === 0 || this.options.pollChoices !== choices) { return; }
      const next: ComposerOptions = this.options.copy();
      while (next.pollImages.length < next.pollChoices.length) { next.pollImages.push(''); }
      next.pollImages[index] = result.photoUris[0]; this.options = next; this.onChange();
    } catch (error) {}
  }

  private updateChoice(index: number, text: string): void {
    const next: ComposerOptions = this.options.copy();
    next.pollChoices[index] = text;
    this.options = next;
    this.onChange();
  }

  private duration(part: number, value: string): void {
    const next: ComposerOptions = this.options.copy();
    const days: number = Math.floor(next.pollDurationMinutes / 1440);
    const hours: number = Math.floor(next.pollDurationMinutes % 1440 / 60);
    const minutes: number = next.pollDurationMinutes % 60;
    const number: number = value.length > 0 ? Number(value) : 0;
    next.pollDurationMinutes = (part === 0 ? number : days) * 1440 +
      (part === 1 ? number : hours) * 60 + (part === 2 ? number : minutes);
    this.options = next;
    this.onChange();
  }

  @Builder
  private DurationField(label: Resource, value: number, part: number): void {
    Column({ space: 4 }) {
      Text(label).fontSize($r('sys.float.Body_S')).fontColor($r('app.color.text_secondary'));
      TextInput({ text: value.toString() }).type(InputType.Number).maxLength(2)
        .backgroundColor(Color.Transparent).fontColor($r('app.color.text_primary'))
        .enabled(!this.disabled).onChange((value: string): void => this.duration(part, value));
    }.layoutWeight(1).alignItems(HorizontalAlign.Start).padding(8)
      .border({ width: 1, color: $r('app.color.divider') }).borderRadius(10);
  }

  build(): void {
    Column({ space: 12 }) {
      ForEach(this.options.pollChoices, (choice: string, index: number): void => {
        Row({ space: 8 }) {
          Column({ space: 2 }) {
            Button({ type: ButtonType.Normal }) {
              if (index < this.options.pollImages.length && this.options.pollImages[index].length > 0) {
                Image(this.options.pollImages[index]).width(64).height(64).objectFit(ImageFit.Cover).borderRadius(10);
              } else {
                SymbolGlyph($r('sys.symbol.picture')).fontSize(26).fontColor([$r('app.color.text_secondary')]);
              }
            }.width(64).height(64).backgroundColor($r('app.color.bg_page')).borderRadius(10)
              .border({ width: 1, color: $r('app.color.divider') }).enabled(!this.disabled)
              .accessibilityText(getContext(this).resourceManager.getStringSync($r('app.string.compose_poll_image').id))
              .onClick((): void => { this.chooseImage(index); });
            if (index < this.options.pollImages.length && this.options.pollImages[index].length > 0) {
              Button($r('app.string.compose_poll_image_remove')).fontSize($r('sys.float.Caption_L'))
                .backgroundColor(Color.Transparent).fontColor(this.accentColor).enabled(!this.disabled)
                .onClick((): void => {
                  const next: ComposerOptions = this.options.copy(); next.pollImages[index] = '';
                  this.options = next; this.onChange();
                });
            }
          }
          Column({ space: 2 }) {
            Row() {
              Text(getContext(this).resourceManager.getStringSync($r('app.string.compose_poll_choice').id) +
                (index + 1).toString()).fontSize($r('sys.float.Body_S')).fontColor(this.accentColor);
              Blank();
              Text(Array.from(choice).length.toString() + '/25').fontSize($r('sys.float.Caption_L'))
                .fontColor(Array.from(choice).length > 25 ? $r('app.color.danger') : $r('app.color.text_secondary'));
            }.width('100%');
            TextInput({ text: choice }).backgroundColor(Color.Transparent)
              .fontColor($r('app.color.text_primary')).enabled(!this.disabled)
              .onChange((value: string): void => this.updateChoice(index, value));
          }.layoutWeight(1).padding(8).borderRadius(10).border({ width: 1, color: $r('app.color.divider') });
          if (this.options.pollChoices.length > 2) {
            Button({ type: ButtonType.Circle }) {
              SymbolGlyph($r('sys.symbol.xmark')).fontSize(18).fontColor([$r('app.color.text_secondary')]);
            }.width(32).height(32).backgroundColor(Color.Transparent).enabled(!this.disabled)
              .accessibilityText(getContext(this).resourceManager.getStringSync($r('app.string.compose_poll_remove_choice').id))
              .onClick((): void => {
                const next: ComposerOptions = this.options.copy();
                next.pollChoices.splice(index, 1); next.pollImages.splice(index, 1);
                this.options = next; this.onChange();
              });
          }
        }.width('100%');
      }, (_choice: string, index: number): string => index.toString());
      if (this.options.pollChoices.length < 4) {
        Button($r('app.string.compose_poll_add_choice')).fontColor(this.accentColor).backgroundColor(Color.Transparent)
          .enabled(!this.disabled).onClick((): void => {
            const next: ComposerOptions = this.options.copy(); next.pollChoices.push('');
            this.options = next; this.onChange();
          });
      }
      Divider().color($r('app.color.divider'));
      Text($r('app.string.compose_poll_duration')).width('100%').fontSize($r('sys.float.Body_L'))
        .fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'));
      Row({ space: 8 }) {
        this.DurationField($r('app.string.compose_poll_days'), Math.floor(this.options.pollDurationMinutes / 1440), 0);
        this.DurationField($r('app.string.compose_poll_hours'), Math.floor(this.options.pollDurationMinutes % 1440 / 60), 1);
        this.DurationField($r('app.string.compose_poll_minutes'), this.options.pollDurationMinutes % 60, 2);
      }.width('100%');
      Text($r('app.string.compose_poll_limits')).width('100%').fontSize($r('sys.float.Body_S'))
        .fontColor(this.options.pollDurationMinutes >= 5 && this.options.pollDurationMinutes <= 10080 ?
          $r('app.color.text_secondary') : $r('app.color.danger'));
      Button($r('app.string.compose_poll_remove')).width('100%').fontColor($r('app.color.danger'))
        .backgroundColor(Color.Transparent).enabled(!this.disabled).onClick((): void => {
          const next: ComposerOptions = this.options.copy(); next.pollChoices = []; next.pollImages = [];
          this.options = next; this.onChange();
        });
    }.width('100%').padding(12).border({ width: 1, color: $r('app.color.divider') }).borderRadius(16);
  }
}
