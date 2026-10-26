import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { backgroundImageStore } from '../services/BackgroundImageStore';
import { pageBackgroundStore } from '../services/PageBackgroundStore';
import { xPrivateStore } from '../services/XPrivateStore';

@Component
export struct BackgroundSelectionMark {
  @Prop accentColor: string = '';

  build(): void {
    Stack({ alignContent: Alignment.Center }) {
      SymbolGlyph($r('sys.symbol.checkmark')).fontSize($r('app.float.background_selection_icon_size'))
        .fontColor([$r('app.color.text_on_accent')])
    }.width($r('app.float.background_selection_size')).height($r('app.float.background_selection_size'))
      .borderRadius($r('app.float.background_selection_radius')).backgroundColor(this.accentColor)
      .hitTestBehavior(HitTestMode.None)
  }
}

@Component
export struct BackgroundPhotoTile {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Prop path: string = '';
  @Prop selected: boolean = false;
  @Prop interactive: boolean = true;
  @Prop accentColor: string = '';
  @State private removing: boolean = false;
  onSelect: (path: string) => void = (_path: string): void => {};
  onDeleted: (path: string) => void = (_path: string): void => {};
  private disposed: boolean = false;

  aboutToAppear(): void { this.disposed = false; }
  aboutToDisappear(): void { this.disposed = true; }

  private async remove(): Promise<void> {
    if (!this.interactive || this.removing) { return; }
    this.removing = true;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const account: string = xPrivateStore.load(context).cacheIdentity();
    const path: string = this.path;
    try {
      const result: promptAction.ShowDialogSuccessResponse = await this.getUIContext().getPromptAction().showDialog({
        title: $r('app.string.background_photo_delete'),
        message: $r('app.string.background_photo_delete_confirm'),
        buttons: [
          { text: $r('app.string.compose_cancel'), color: $r('app.color.text_secondary') },
          { text: $r('app.string.background_photo_delete'), color: $r('app.color.danger') }
        ]
      });
      if (result.index !== 1 || this.disposed || !this.interactive ||
        account !== xPrivateStore.load(context).cacheIdentity()) { return; }
      if (!backgroundImageStore.removePhoto(context, path)) { return; }
      pageBackgroundStore.initialize(context);
      this.getUIContext().getPromptAction().showToast({
        message: context.resourceManager.getStringSync($r('app.string.background_photo_deleted'))
      });
      this.onDeleted(path);
    } catch (error) {
      if (!this.disposed && account === xPrivateStore.load(context).cacheIdentity()) {
        this.getUIContext().getPromptAction().showToast({
          message: context.resourceManager.getStringSync($r('app.string.background_photo_delete_failed'))
        });
      }
    } finally { if (!this.disposed) { this.removing = false; } }
  }

  build(): void {
    Column({ space: 8 }) {
      Button({ type: ButtonType.Normal }) {
        Stack({ alignContent: Alignment.TopEnd }) {
          Image('file://' + this.path).width('100%').height('100%').autoResize(true)
            .objectFit(ImageFit.Cover).draggable(false)
          if (this.selected) { BackgroundSelectionMark({ accentColor: this.accentColor }).margin(8) }
        }.width('100%').height('100%')
      }.width('100%').height($r('app.float.chat_background_tile_height')).padding(0).borderRadius(16).clip(true)
        .backgroundColor(Color.Transparent).border({ width: this.selected ? 2 : 1,
          color: this.selected ? this.accentColor : $r('app.color.divider') })
        .accessibilityText($r('app.string.chat_background_my_photo')).enabled(this.interactive && !this.removing)
        .onClick((): void => { this.onSelect(this.path); })
      Row({ space: 4 }) {
        Text($r('app.string.chat_background_my_photo')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S'))
          .fontColor($r('app.color.text_secondary')).layoutWeight(1).maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.trash')).fontSize($r('app.float.background_photo_delete_icon_size'))
            .fontColor([$r('app.color.danger')])
        }.width($r('app.float.background_photo_delete_button_size')).height($r('app.float.background_photo_delete_button_size'))
          .padding(0).backgroundColor(Color.Transparent).enabled(this.interactive && !this.removing)
          .accessibilityText($r('app.string.background_photo_delete')).onClick((): void => { this.remove(); })
      }.width('100%')
    }.width('100%')
  }
}
