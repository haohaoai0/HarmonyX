import { common } from '@kit.AbilityKit';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { accountStore } from '../services/AccountStore';
import { XXAuthSupporterPolicy } from '../services/XXAuthSupporterPolicy';
import { SUPPORTER_ACTIVE_KEY, SUPPORTER_EXPIRY_KEY, SupporterOutcome,
  xxAuthSupporterService } from '../services/XXAuthSupporterService';
import { cardSurfaceColor, fieldSurfaceColor } from '../utils/ThemeColors';

@Component
export struct SupporterActivationCard {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp(SUPPORTER_ACTIVE_KEY) private active: boolean = false;
  @StorageProp(SUPPORTER_EXPIRY_KEY) private expiresAt: number = 0;
  @StorageProp('harmonyx.accounts_changed') @Watch('onAccountsChanged') private accountsChanged: number = 0;
  @StorageProp('harmonyx.display_mode') private displayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private darkSurface: string = '';
  @StorageProp('harmonyx.accent_color') private accentColor: string = '#007DFF';
  @State private accountName: string = '';
  @State private signedIn: boolean = false;
  @State private code: string = '';
  @State private busy: boolean = false;
  @State private outcome: SupporterOutcome = SupporterOutcome.NONE;
  private revision: number = 0;
  private alive: boolean = false;

  aboutToAppear(): void {
    this.alive = true;
    this.onAccountsChanged();
  }

  aboutToDisappear(): void {
    this.alive = false;
    this.revision++;
    this.code = '';
    this.busy = false;
  }

  // The entitlement belongs to the X account, so a switch re-reads both the
  // account shown here and the cached code that account already redeemed.
  private onAccountsChanged(): void {
    this.revision++;
    this.code = '';
    this.busy = false;
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    try {
      const account = accountStore.active(context);
      this.signedIn = account !== null && XXAuthSupporterPolicy.accountIdValid(account.userId);
      this.accountName = account === null ? '' : account.username;
    } catch (error) {
      this.signedIn = false;
      this.accountName = '';
    }
    this.outcome = SupporterOutcome.NONE;
    xxAuthSupporterService.refresh(context);
  }

  private async redeem(refresh: boolean): Promise<void> {
    if (this.busy) { return; }
    this.busy = true;
    const revision: number = this.revision;
    const value: string = this.code;
    this.code = '';
    this.outcome = SupporterOutcome.NONE;
    try {
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const outcome: SupporterOutcome = refresh ? await xxAuthSupporterService.refresh(context, true) :
        await xxAuthSupporterService.activate(context, value);
      if (this.alive && revision === this.revision) { this.outcome = outcome; }
    } finally { if (this.alive && revision === this.revision) { this.busy = false; } }
  }

  private resultText(): Resource {
    if (this.outcome === SupporterOutcome.INVALID) { return $r('app.string.supporter_invalid'); }
    if (this.outcome === SupporterOutcome.STORAGE) { return $r('app.string.supporter_storage_error'); }
    if (this.outcome === SupporterOutcome.CONFIG) { return $r('app.string.supporter_config_error'); }
    return $r('app.string.supporter_network_error');
  }

  build(): void {
    Column({ space: 12 }) {
      Text($r('app.string.supporter_title')).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Title_S')).fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary')).width('100%')
      Text(this.active ? $r('app.string.supporter_active') : $r('app.string.supporter_description'))
        .fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L'))
        .fontColor(this.active ? this.accentColor : $r('app.color.text_secondary')).width('100%')
      if (this.active) {
        Text($r('app.string.supporter_expiry', new Date(this.expiresAt).toLocaleDateString()))
          .fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
          .fontColor($r('app.color.text_secondary')).width('100%')
        Button($r('app.string.supporter_refresh')).width('100%').enabled(!this.busy)
          .onClick((): void => { this.redeem(true); })
      } else {
        if (this.signedIn) {
          Text($r('app.string.supporter_account', this.accountName)).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary')).width('100%')
        } else {
          Text($r('app.string.supporter_account_hint')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M')).fontColor($r('app.color.danger')).width('100%')
        }
        TextInput({ text: this.code, placeholder: $r('app.string.supporter_code_placeholder') })
          .id('supporter-code-input').type(InputType.Password).showPasswordIcon(true).maxLength(256)
          .height(48).width('100%').backgroundColor(fieldSurfaceColor(this.displayMode, this.darkSurface))
          .onChange((value: string): void => { this.code = value; this.outcome = SupporterOutcome.NONE; })
          .enabled(!this.busy && this.signedIn)
        Button(this.busy ? $r('app.string.supporter_verifying') : $r('app.string.supporter_redeem'))
          .id('supporter-redeem-button').width('100%').backgroundColor(this.accentColor)
          .enabled(!this.busy && this.signedIn && this.code.trim().length >= 8)
          .onClick((): void => { this.redeem(false); })
      }
      Text($r('app.string.supporter_restore_hint')).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary')).width('100%')
      if (this.outcome === SupporterOutcome.INVALID || this.outcome === SupporterOutcome.NETWORK ||
        this.outcome === SupporterOutcome.STORAGE || this.outcome === SupporterOutcome.CONFIG) {
        Text(this.resultText()).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
          .fontColor($r('app.color.danger')).width('100%')
      }
    }.width('100%').padding(18).alignItems(HorizontalAlign.Start)
      .backgroundColor(cardSurfaceColor(this.displayMode, this.darkSurface)).borderRadius(20)
      .id('supporter-activation-card')
  }
}
