import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { promptAction } from '@kit.ArkUI';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { HUAWEI_ACCOUNT_SIGNED_IN, HUAWEI_ACCOUNT_NAME, HUAWEI_ACCOUNT_AVATAR,
  HUAWEI_ACCOUNT_BUSY, huaweiAccountService } from '../services/HuaweiAccountService';
import { CLOUD_SYNC_ENABLED, CLOUD_SYNC_MASK, CLOUD_SYNC_STATUS, CLOUD_SYNC_LAST,
  CLOUD_SYNC_ERROR, huaweiCloudSyncService } from '../services/HuaweiCloudSyncService';
import { CLOUD_GROUP_APPEARANCE, CLOUD_GROUP_MEDIA, CLOUD_GROUP_FILTERS } from '../services/CloudSettingsRepository';

@Component
export struct HuaweiAccountSheet {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp(HUAWEI_ACCOUNT_SIGNED_IN) private signedIn: boolean = false;
  @StorageProp(HUAWEI_ACCOUNT_NAME) private nickName: string = '';
  @StorageProp(HUAWEI_ACCOUNT_AVATAR) private avatar: string = '';
  @StorageProp(HUAWEI_ACCOUNT_BUSY) private loggingIn: boolean = false;
  @StorageProp(CLOUD_SYNC_ENABLED) private syncEnabled: boolean = false;
  @StorageProp(CLOUD_SYNC_MASK) private groupsMask: number = 7;
  @StorageProp(CLOUD_SYNC_STATUS) private status: string = 'signed_out';
  @StorageProp(CLOUD_SYNC_ERROR) private syncError: number = 0;
  @StorageProp(CLOUD_SYNC_LAST) private lastSync: number = 0;
  @StorageProp('harmonyx.accent_color') private accent: string = '';
  @StorageProp('harmonyx.navigation_indicator_height') private bottomInset: number = 0;
  @State private avatarFailed: boolean = false;
  @State private errorMessage: Resource | null = null;
  onClose: () => void = (): void => {};

  private text(resource: Resource): string {
    return (getContext(this) as common.UIAbilityContext).resourceManager.getStringSync(resource);
  }

  private syncing(): boolean { return this.status === 'downloading' || this.status === 'uploading'; }

  private async login(): Promise<void> {
    this.errorMessage = null;
    try {
      await huaweiAccountService.login(getContext(this) as common.UIAbilityContext);
      this.avatarFailed = false;
    } catch (error) {
      const code: number = (error as BusinessError).code;
      if (code === 1001502012) { return; }
      this.errorMessage = code === 1001502005 ? $r('app.string.huawei_network_error') :
        code === 1001502014 || code === 1001500003 ? $r('app.string.huawei_authorization_error') :
          $r('app.string.huawei_login_error');
    }
  }

  private async logout(): Promise<void> {
    const result: promptAction.ShowDialogSuccessResponse = await this.getUIContext().getPromptAction().showDialog({
      title: this.text($r('app.string.huawei_logout_title')),
      message: this.text($r('app.string.huawei_logout_description')),
      buttons: [
        { text: this.text($r('app.string.compose_cancel')), color: this.accent },
        { text: this.text($r('app.string.huawei_logout')), color: $r('app.color.danger') }
      ]
    });
    if (result.index === 1) { huaweiAccountService.logout(); this.errorMessage = null; }
  }

  private changeGroup(group: number, enabled: boolean): void {
    const mask: number = enabled ? this.groupsMask | group : this.groupsMask & ~group;
    if (mask === 0) {
      this.getUIContext().getPromptAction().showToast({ message: this.text($r('app.string.huawei_select_group')) });
      return;
    }
    try { huaweiCloudSyncService.setGroups(mask); }
    catch (error) { this.errorMessage = $r('app.string.huawei_save_error'); }
  }

  private statusText(): Resource {
    if (this.status === 'account_changed') { return $r('app.string.huawei_account_changed'); }
    if (!this.syncEnabled) { return $r('app.string.huawei_sync_disabled'); }
    if (this.status === 'unavailable') { return $r('app.string.huawei_sync_unavailable'); }
    if (this.status === 'downloading') { return $r('app.string.huawei_sync_downloading'); }
    if (this.status === 'uploading') { return $r('app.string.huawei_sync_uploading'); }
    if (this.status === 'synced') { return $r('app.string.huawei_sync_success'); }
    if (this.status === 'failed') {
      if (this.syncError === 1 || this.syncError === 2) { return $r('app.string.huawei_network_error'); }
      if (this.syncError === 5 || this.syncError === 6) { return $r('app.string.huawei_storage_full'); }
      return $r('app.string.huawei_sync_failed');
    }
    return $r('app.string.huawei_sync_pending');
  }

  @Builder
  private GroupRow(title: Resource, description: Resource, group: number): void {
    Row({ space: 12 }) {
      Column({ space: 4 }) {
        Text(title).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L'))
          .fontColor($r('app.color.text_primary')).width('100%')
        Text(description).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S'))
          .fontColor($r('app.color.text_secondary')).width('100%')
      }.layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: (this.groupsMask & group) !== 0 }).selectedColor(this.accent)
        .enabled(!this.syncing()).accessibilityText(title)
        .onChange((enabled: boolean): void => this.changeGroup(group, enabled))
    }.width('100%').padding({ top: 12, bottom: 12 })
  }

  build(): void {
    Scroll() {
      Column({ space: 16 }) {
        Text($r('app.string.huawei_account_title')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Title_S')).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary')).width('100%')
        Row({ space: 14 }) {
          if (this.signedIn && this.avatar.length > 0 && !this.avatarFailed) {
            Image(this.avatar).width($r('app.float.huawei_account_avatar_size'))
              .height($r('app.float.huawei_account_avatar_size')).borderRadius('50%').objectFit(ImageFit.Cover)
              .onError((): void => { this.avatarFailed = true; })
          } else {
            SymbolGlyph($r('sys.symbol.person_crop_circle_fill')).fontSize($r('app.float.huawei_account_avatar_size'))
              .fontColor([$r('app.color.text_secondary')])
          }
          Column({ space: 4 }) {
            Text(this.signedIn && this.nickName.length > 0 ? this.nickName : $r('app.string.huawei_account_name'))
              .fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary')).width('100%')
            Text(this.signedIn ? $r('app.string.huawei_signed_in') : $r('app.string.huawei_signed_out_description'))
              .fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
              .fontColor($r('app.color.text_secondary')).width('100%')
          }.layoutWeight(1)
        }.width('100%').padding({ top: 6, bottom: 6 })
        if (!this.signedIn) {
          Text($r('app.string.huawei_sync_description')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary')).width('100%')
          Button(this.loggingIn ? $r('app.string.huawei_logging_in') : $r('app.string.huawei_login'))
            .width('100%').height($r('app.float.huawei_account_button_height')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_on_accent')).backgroundColor(this.accent)
            .enabled(!this.loggingIn).id('huawei-account-login').onClick((): void => { this.login(); })
        } else {
          Column({ space: 6 }) {
            Row() {
              Text($r('app.string.huawei_cloud_sync')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L'))
                .fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary')).layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.syncEnabled }).selectedColor(this.accent)
                .id('huawei-cloud-toggle').accessibilityText($r('app.string.huawei_cloud_sync'))
                .onChange((enabled: boolean): void => {
                  try { huaweiCloudSyncService.setEnabled(enabled); }
                  catch (error) { this.errorMessage = $r('app.string.huawei_save_error'); }
                })
            }.width('100%')
            Text(this.statusText()).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
              .fontColor($r('app.color.text_secondary')).width('100%')
            if (this.lastSync > 0) {
              Text(this.text($r('app.string.huawei_last_sync')) + ' ' + new Date(this.lastSync).toLocaleString())
                .fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S'))
                .fontColor($r('app.color.text_secondary')).width('100%')
            }
          }.width('100%')
          Column() {
            this.GroupRow($r('app.string.huawei_group_appearance'), $r('app.string.huawei_group_appearance_description'), CLOUD_GROUP_APPEARANCE)
            this.GroupRow($r('app.string.huawei_group_media'), $r('app.string.huawei_group_media_description'), CLOUD_GROUP_MEDIA)
            this.GroupRow($r('app.string.huawei_group_filters'), $r('app.string.huawei_group_filters_description'), CLOUD_GROUP_FILTERS)
          }.width('100%')
          if (this.syncEnabled) {
            Button(this.syncing() ? $r('app.string.huawei_syncing') : $r('app.string.huawei_sync_now'))
              .width('100%').height($r('app.float.huawei_account_button_height')).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_L')).backgroundColor(this.accent).fontColor($r('app.color.text_on_accent'))
              .enabled(!this.syncing()).id('huawei-cloud-sync-now')
              .onClick((): void => { huaweiCloudSyncService.sync(); })
          }
          Button($r('app.string.huawei_logout')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L'))
            .width('100%').height($r('app.float.huawei_account_button_height')).backgroundColor(Color.Transparent)
            .fontColor($r('app.color.danger')).id('huawei-account-logout')
            .onClick((): void => { this.logout().catch((): void => {}); })
        }
        if (this.errorMessage !== null) {
          Text(this.errorMessage).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
            .fontColor($r('app.color.danger')).width('100%')
        }
        Text($r('app.string.huawei_local_data_note')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S'))
          .fontColor($r('app.color.text_secondary')).width('100%')
      }.width('100%').padding({ left: $r('app.float.settings_page_horizontal_padding'),
        right: $r('app.float.settings_page_horizontal_padding'), top: 20, bottom: this.bottomInset + 24 })
    }.width('100%').height('100%').align(Alignment.TopStart).scrollBar(BarState.Auto)
  }
}
