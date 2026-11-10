import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { MEDIA_DOWNLOAD_FAILED, mediaDownloadService } from '../services/MediaDownloadService';
import { SecureMediaSaveRequest, secureMediaSaveController, STORAGE_KEY_SECURE_MEDIA_SAVE } from '../services/SecureMediaSaveController';
import { pageSurfaceColor } from '../utils/ThemeColors';

@Component
export struct SecureMediaSaveHost {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp(STORAGE_KEY_SECURE_MEDIA_SAVE) @Watch('reload') private revision: number = 0;
  @StorageProp('harmonyx.display_mode') private displayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private darkSurface: string = '';
  @StorageProp('harmonyx.navigation_indicator_height') private bottomInset: number = 0;
  @State private open: boolean = false;
  @State private saving: boolean = false;

  private reload(): void { this.open = secureMediaSaveController.current() !== null; }

  private save(result: SaveButtonOnClickResult): void {
    if (this.saving) { return; }
    const request: SecureMediaSaveRequest | null = secureMediaSaveController.current();
    if (request === null) { return; }
    if (result !== SaveButtonOnClickResult.SUCCESS) {
      secureMediaSaveController.complete(request, MEDIA_DOWNLOAD_FAILED);
      return;
    }
    this.saving = true;
    // Do not defer this call: createAsset consumes the native button's grant
    // immediately, before a remote download or any other asynchronous work.
    void mediaDownloadService.downloadPhotoWithSaveButton(request.context, request.url, request.mediaId,
      (outcome: number): void => {
        this.saving = false;
        secureMediaSaveController.complete(request, outcome);
      }, request.isVideo);
  }

  @Builder
  private Content(): void {
    Column({ space: $r('app.float.media_save_sheet_gap') }) {
      Text($r('app.string.media_save_secure_title')).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Subtitle_L')).fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary')).width('100%')
      Text($r('app.string.media_save_secure_note')).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary')).width('100%')
      if (this.saving) {
        LoadingProgress().width(36).height(36)
        Text($r('app.string.media_download_started')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary'))
      } else {
        SaveButton({ icon: SaveIconStyle.LINES, text: SaveDescription.SAVE, buttonType: ButtonType.Capsule })
          .width('100%').height($r('app.float.media_save_button_height'))
          .onClick((_event: ClickEvent, result: SaveButtonOnClickResult): void => this.save(result))
      }
      Button($r('app.string.compose_cancel')).width('100%').backgroundColor(Color.Transparent)
        .fontColor($r('app.color.text_secondary')).enabled(!this.saving)
        .onClick((): void => secureMediaSaveController.cancel())
    }.width('100%').padding($r('app.float.media_save_sheet_inset')).margin({ bottom: this.bottomInset })
  }

  build(): void {
    Column().width(0).height(0)
      .bindSheet($$this.open, this.Content(), {
        height: SheetSize.FIT_CONTENT, preferType: SheetType.BOTTOM, showClose: false, dragBar: false,
        backgroundColor: pageSurfaceColor(this.displayMode, this.darkSurface),
        onWillDismiss: (action: DismissSheetAction): void => {
          if (!this.saving) { action.dismiss(); secureMediaSaveController.cancel(); }
        },
        onDisappear: (): void => { if (!this.saving) { secureMediaSaveController.cancel(); } }
      })
  }
}
