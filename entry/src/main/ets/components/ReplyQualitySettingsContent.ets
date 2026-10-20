import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { STORAGE_KEY_ACCOUNTS_CHANGED } from '../services/AccountStore';
import { ReplyQualityAllowedAuthor, ReplyQualitySettings, replyQualityStore,
  STORAGE_KEY_REPLY_QUALITY_REVISION } from '../services/ReplyQualityStore';
import { common } from '@kit.AbilityKit';
import promptAction from '@ohos.promptAction';
import { pageTextColor } from '../utils/ThemeColors';

@Component
export struct ReplyQualitySettingsContent {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp('harmonyx.page_background') private pageBackground: string = '';
  @StorageProp(STORAGE_KEY_REPLY_QUALITY_REVISION) @Watch('reload') private revision: number = 0;
  @StorageProp(STORAGE_KEY_ACCOUNTS_CHANGED) @Watch('reload') private accountRevision: number = 0;
  @State private foldEnabled: boolean = false;
  @State private authors: ReplyQualityAllowedAuthor[] = [];

  aboutToAppear(): void { this.reload(); }

  private reload(): void {
    const settings: ReplyQualitySettings = replyQualityStore.load(this.getUIContext().getHostContext() as common.UIAbilityContext);
    this.foldEnabled = settings.enabled;
    this.authors = settings.authors;
  }

  private saveFailed(): void {
    promptAction.showToast({ message: this.getUIContext().getHostContext()?.resourceManager.getStringSync($r('app.string.settings_filter_save_failed').id) ?? '' });
  }

  private setEnabled(value: boolean): void {
    this.foldEnabled = value;
    if (!replyQualityStore.setEnabled(this.getUIContext().getHostContext() as common.UIAbilityContext, value)) {
      this.reload();
      this.saveFailed();
    }
  }

  private remove(authorId: string): void {
    if (!replyQualityStore.remove(this.getUIContext().getHostContext() as common.UIAbilityContext, authorId)) { this.saveFailed(); }
  }

  private foreground(): ResourceColor {
    return pageTextColor($r('app.color.text_primary'), this.pageBackground, Color.Transparent);
  }

  build(): void {
    Column({ space: 10 }) {
      Row({ space: 12 }) {
        Text($r('app.string.settings_reply_quality')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Title_S')).fontColor(this.foreground()).layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.foldEnabled }).id('settings-reply-quality-enabled')
          .onChange((value: boolean): void => this.setEnabled(value))
      }.width('100%')
      Text($r('app.string.settings_reply_quality_desc')).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_M')).fontColor(this.foreground()).width('100%')
      Text($r('app.string.reply_quality_whitelist')).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Title_S')).fontColor(this.foreground()).width('100%')
      Text($r('app.string.reply_quality_whitelist_desc')).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_M')).fontColor(this.foreground()).width('100%')
      if (this.authors.length === 0) {
        Text($r('app.string.reply_quality_empty')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M')).fontColor(this.foreground()).width('100%')
      } else {
        ForEach(this.authors, (author: ReplyQualityAllowedAuthor) => {
          Row({ space: 8 }) {
            Column({ space: 4 }) {
              Text(author.name || author.username || author.id).fontFamily(this.appFontFamily)
                .fontSize($r('sys.float.Body_M')).fontColor(this.foreground()).maxLines(2)
              if (author.username.length > 0) {
                Text('@' + author.username).fontFamily(this.appFontFamily)
                  .fontSize($r('sys.float.Body_S')).fontColor(this.foreground()).maxLines(1)
              }
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            Button($r('app.string.xnative_remove')).fontColor(this.foreground()).backgroundColor(Color.Transparent)
              .constraintSize({ minHeight: 40 }).id('reply-quality-remove-' + author.id)
              .onClick((): void => this.remove(author.id))
          }.width('100%').padding({ top: 6, bottom: 6 })
        }, (author: ReplyQualityAllowedAuthor): string => author.id)
      }
    }.width('100%').padding({ left: 20, right: 20, top: 16, bottom: 16 }).id('settings-reply-quality')
  }
}
