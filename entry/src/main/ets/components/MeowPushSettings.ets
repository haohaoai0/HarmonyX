import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { common } from '@kit.AbilityKit';
import { accountStore, XAccount, STORAGE_KEY_ACCOUNTS_CHANGED } from '../services/AccountStore';
import { MeowPushConfig, MeowRelayStatus, meowPushService } from '../services/MeowPushService';
import { fieldSurfaceColor } from '../utils/ThemeColors';

@Component
export struct MeowPushSettings {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageLink(STORAGE_KEY_ACCOUNTS_CHANGED) @Watch('accountChanged') accountTick: number = 0;
  @StorageProp('harmonyx.accent_color') accent: string = '#007DFF';
  @StorageProp('harmonyx.display_mode') displayMode: string = '';
  @StorageProp('harmonyx.dark_surface') darkSurface: string = '';
  @State private relayBase: string = '';
  @State private relayToken: string = '';
  @State private nickname: string = '';
  @State private previews: boolean = false;
  @State private code: string = '';
  @State private pending: boolean = false;
  @State private bound: boolean = false;
  @State private pushEnabled: boolean = false;
  @State private cleanup: boolean = false;
  @State private hasKey: boolean = false;
  @State private signedIn: boolean = false;
  @State private busy: boolean = false;
  @State private note: string = '';
  @State private accountName: string = '';
  private accountId: string = '';
  private generation: number = 0;

  aboutToAppear(): void { this.accountChanged(); }
  aboutToDisappear(): void { this.generation++; }

  private text(resource: Resource): string {
    return (getContext(this) as common.UIAbilityContext).resourceManager.getStringSync(resource);
  }

  private accountChanged(): void {
    this.generation++; this.busy = false; this.code = ''; this.note = '';
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const account: XAccount | null = accountStore.active(context);
    this.accountId = account === null ? '' : account.id;
    this.accountName = account === null ? '' : account.title();
    this.signedIn = account !== null && account.hasCookieSession();
    this.reload();
  }

  private reload(): void {
    try {
      const config: MeowPushConfig = meowPushService.load(getContext(this) as common.UIAbilityContext, this.accountId);
      this.relayBase = config.relayBase; this.relayToken = config.relayToken;
      this.nickname = config.nickname; this.previews = config.previews;
      this.pending = config.pendingId.length > 0; this.bound = config.endpoint.length > 0;
      this.pushEnabled = config.enabled; this.cleanup = config.xCleanupPending && config.relayRemoved;
      this.hasKey = config.subKey.length > 0;
    } catch (error) {
      this.note = this.text($r('app.string.meow_storage_error'));
      this.signedIn = false;
    }
  }

  private errorText(error: Error): string {
    const code: string = error.message;
    if (code === 'relay_url') { return this.text($r('app.string.meow_url_error')); }
    if (code === 'relay_token') { return this.text($r('app.string.meow_token_error')); }
    if (code === 'nickname') { return this.text($r('app.string.meow_nickname_error')); }
    if (code === 'code' || code === 'relay_400' || code === 'relay_403') { return this.text($r('app.string.meow_code_error')); }
    if (code === 'relay_401') { return this.text($r('app.string.meow_auth_error')); }
    if (code === 'relay_404') { return this.text($r('app.string.meow_missing_error')); }
    if (code === 'relay_429') { return this.text($r('app.string.meow_rate_error')); }
    if (code === 'relay_response') { return this.text($r('app.string.meow_response_error')); }
    if (code === 'x_cleanup') { return this.text($r('app.string.meow_cleanup_note')); }
    if (/^x_\d+$/.test(code)) { return this.text($r('app.string.meow_x_error')) + ' HTTP ' + code.substring(2); }
    if (code === 'sign_in') { return this.text($r('app.string.meow_sign_in')); }
    return this.text($r('app.string.meow_network_error'));
  }

  private async act(action: string): Promise<void> {
    if (this.busy) { return; }
    const generation: number = this.generation;
    const accountId: string = this.accountId;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    this.busy = true; this.note = '';
    try {
      let success: Resource = $r('app.string.meow_registered');
      if (action === 'begin') {
        const config: MeowPushConfig = new MeowPushConfig();
        config.relayBase = this.relayBase; config.relayToken = this.relayToken;
        config.nickname = this.nickname; config.previews = this.previews;
        await meowPushService.begin(context, accountId, config);
        success = $r('app.string.meow_code_sent');
      } else if (action === 'confirm') {
        await meowPushService.confirm(context, accountId, this.code);
      } else if (action === 'stop') {
        await meowPushService.stop(context, accountId);
        success = $r('app.string.meow_stopped');
      } else if (action === 'test') {
        await meowPushService.test(context, accountId);
        success = $r('app.string.meow_test_sent');
      } else {
        const status: MeowRelayStatus = await meowPushService.status(context, accountId);
        if (generation !== this.generation) { return; }
        this.note = status.active !== true ? this.text($r('app.string.meow_partial')) :
          (status.deliveredAt ?? 0) > 0 ? this.text($r('app.string.meow_last_delivery')) +
            new Date(status.deliveredAt ?? 0).toLocaleString() : this.text($r('app.string.meow_waiting'));
        if ((status.queued ?? 0) > 0) { this.note += '\n' + this.text($r('app.string.meow_queued')) + (status.queued ?? 0).toString(); }
        if ((status.lastError ?? '').length > 0) { this.note += '\n' + this.text($r('app.string.meow_delivery_error')); }
        return;
      }
      if (generation === this.generation) { this.note = this.text(success); this.code = ''; }
    } catch (error) {
      if (generation === this.generation) { this.note = this.errorText(error as Error); }
    } finally {
      if (generation === this.generation) { this.busy = false; this.reload(); }
    }
  }

  @Builder
  private Field(label: Resource, value: string, secret: boolean, change: (value: string) => void) {
    Text(label).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary')).width('100%')
    TextInput({ text: value, placeholder: label }).fontFamily(this.appFontFamily)
      .type(secret ? InputType.Password : InputType.Normal)
      .keyboardAppearance(KeyboardAppearance.IMMERSIVE)
      .fontSize($r('sys.float.Body_L')).height(48).width('100%')
      .backgroundColor(fieldSurfaceColor(this.displayMode, this.darkSurface)).borderRadius(12)
      .enabled(!this.busy && !this.bound && !this.pending && this.signedIn)
      .onChange(change)
  }

  @Builder
  private Action(label: Resource, action: string) {
    Button(label).width('100%').backgroundColor(this.accent).fontColor($r('app.color.text_on_accent'))
      .enabled(!this.busy && this.signedIn).onClick((): void => { this.act(action); })
  }

  build() {
    Column({ space: 12 }) {
      Divider().color($r('app.color.divider'))
      Text($r('app.string.meow_title')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Title_S')).fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary')).width('100%')
      Text($r('app.string.meow_intro')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
        .fontColor($r('app.color.text_secondary')).width('100%')
      if (this.signedIn) {
        Text(this.accountName).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor(this.accent).width('100%')
        Text(this.cleanup ? $r('app.string.meow_cleanup_note') : this.pushEnabled ? $r('app.string.meow_registered') : this.bound ?
          $r('app.string.meow_partial') : $r('app.string.meow_not_bound')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_primary')).width('100%')
      } else {
        Text($r('app.string.meow_sign_in')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary'))
      }
      this.Field($r('app.string.meow_relay_url'), this.relayBase, false, (value: string): void => { this.relayBase = value; })
      this.Field($r('app.string.meow_relay_token'), this.relayToken, true, (value: string): void => { this.relayToken = value; })
      this.Field($r('app.string.meow_nickname'), this.nickname, false, (value: string): void => { this.nickname = value; })
      Row({ space: 12 }) {
        Text($r('app.string.meow_previews')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L'))
          .fontColor($r('app.color.text_primary')).layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.previews }).selectedColor(this.accent)
          .enabled(!this.busy && !this.bound && !this.pending && this.signedIn)
          .onChange((value: boolean): void => { this.previews = value; })
      }.width('100%')
      Text($r('app.string.meow_privacy')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S'))
        .fontColor($r('app.color.text_secondary')).width('100%')
      if (!this.bound && !this.pending) { this.Action($r('app.string.meow_send_code'), 'begin') }
      if (this.pending && !this.bound) {
        TextInput({ text: this.code, placeholder: $r('app.string.meow_code') }).fontFamily(this.appFontFamily).type(InputType.Number).maxLength(6)
          .height(48).width('100%').backgroundColor(fieldSurfaceColor(this.displayMode, this.darkSurface))
          .enabled(!this.busy).onChange((value: string): void => { this.code = value; })
      }
      if (!this.pushEnabled && !this.cleanup && (this.pending || this.bound)) {
        this.Action(this.bound ? $r('app.string.meow_retry') : $r('app.string.meow_confirm'), 'confirm')
      }
      if (this.pushEnabled) {
        this.Action($r('app.string.meow_test'), 'test')
        this.Action($r('app.string.meow_status'), 'status')
      }
      if (this.hasKey) {
        this.Action(this.cleanup ? $r('app.string.meow_retry_stop') : $r('app.string.meow_stop'), 'stop')
      }
      if (this.busy) { LoadingProgress().width(24).height(24).color(this.accent) }
      if (this.note.length > 0) {
        Text(this.note).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_primary')).width('100%')
      }
      Text($r('app.string.meow_scope_note')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S'))
        .fontColor($r('app.color.text_secondary')).width('100%')
    }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 20, right: 20, top: 12, bottom: 24 })
  }
}
