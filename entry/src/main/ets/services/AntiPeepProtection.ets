import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { BusinessError, deviceInfo } from '@kit.BasicServicesKit';
import { dlpAntiPeep } from '@kit.DeviceSecurityKit';
import hilog from '@ohos.hilog';

export const STORAGE_KEY_ANTI_PEEP_ENABLED: string = 'harmonyx.anti_peep_enabled';
export const STORAGE_KEY_ANTI_PEEP_STATE: string = 'harmonyx.anti_peep_state';

export enum AntiPeepState {
  DISABLED = 'disabled',
  PAUSED = 'paused',
  CHECKING = 'checking',
  UNSUPPORTED = 'unsupported',
  PERMISSION_REQUIRED = 'permission',
  SYSTEM_OFF = 'system_off',
  FACE_REQUIRED = 'face',
  READY = 'ready',
  PROTECTING = 'protecting',
  PROTECTED = 'protected',
  ERROR = 'error'
}

// Only the user's preference is persisted. Capability, ACL and the system switch
// are checked again on every foreground entry, including after a profile upgrade.
export class AntiPeepProtection {
  private static readonly STORE_NAME: string = 'harmonyx_anti_peep';
  private enabled: boolean = false;
  private foreground: boolean = false;
  private windowId: number = 0;
  private generation: number = 0;
  private configurationVersion: number = 0;
  private episode: number = 0;
  private subscribed: boolean = false;
  private configuring: boolean = false;
  private maskPending: boolean = false;
  private maskShown: boolean = false;
  private peeping: boolean = false;
  private listener: ((status: dlpAntiPeep.DlpAntiPeepStatus) => void) | null = null;

  initialize(context: common.Context): void {
    this.configurationVersion++;
    this.stop();
    this.foreground = false;
    this.windowId = 0;
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context,
        { name: AntiPeepProtection.STORE_NAME });
      this.enabled = store.getSync('enabled', false) === true;
    } catch (error) {
      this.enabled = false;
    }
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_ANTI_PEEP_ENABLED, this.enabled);
    this.publish(this.enabled ? AntiPeepState.PAUSED : AntiPeepState.DISABLED);
  }

  saveEnabled(context: common.Context, enabled: boolean): boolean {
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context,
        { name: AntiPeepProtection.STORE_NAME });
      store.putSync('enabled', enabled);
      store.flushSync();
    } catch (error) {
      return false;
    }
    this.enabled = enabled;
    this.configurationVersion++;
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_ANTI_PEEP_ENABLED, enabled);
    this.refresh();
    return true;
  }

  attachWindow(windowId: number): void {
    if (this.windowId !== windowId) { this.configurationVersion++; }
    this.windowId = windowId;
    this.refresh();
  }

  detachWindow(): void {
    this.configurationVersion++;
    this.windowId = 0;
    this.stop();
    this.publish(this.enabled ? AntiPeepState.PAUSED : AntiPeepState.DISABLED);
  }

  setForeground(foreground: boolean): void {
    this.foreground = foreground;
    this.refresh();
  }

  async refresh(): Promise<void> {
    this.stop();
    if (!this.enabled) { this.publish(AntiPeepState.DISABLED); return; }
    if (!this.foreground || this.windowId <= 0) { this.publish(AntiPeepState.PAUSED); return; }
    if (!canIUse('SystemCapability.Security.DlpAntiPeep')) {
      this.publish(AntiPeepState.UNSUPPORTED);
      return;
    }
    const generation: number = this.generation;
    this.publish(AntiPeepState.CHECKING);
    try {
      const systemOn: boolean = await dlpAntiPeep.isDlpAntiPeepSwitchOn();
      if (!this.current(generation)) { return; }
      if (!systemOn) { this.publish(AntiPeepState.SYSTEM_OFF); return; }
      // Each subscription owns a callback and a generation, so a queued callback
      // from an old window/background session cannot affect the current window.
      const listener = (status: dlpAntiPeep.DlpAntiPeepStatus): void => {
        if (this.current(generation)) { this.handleStatus(status, generation); }
      };
      dlpAntiPeep.on('dlpAntiPeep', listener);
      this.listener = listener;
      this.subscribed = true;
      this.handleStatus(dlpAntiPeep.getDlpAntiPeepInfo(), generation);
    } catch (error) {
      if (this.current(generation)) {
        this.stop();
        this.failure(error as BusinessError);
      }
    }
  }

  // Only called by the user's settings action, never automatically at launch.
  async configure(context: common.UIAbilityContext): Promise<void> {
    if (this.configuring || !this.enabled || !this.foreground || this.windowId <= 0) { return; }
    if (!canIUse('SystemCapability.Security.DlpAntiPeep')) {
      this.publish(AntiPeepState.UNSUPPORTED);
      return;
    }
    if (deviceInfo.sdkApiVersion < 23) { this.publish(AntiPeepState.SYSTEM_OFF); return; }
    this.configuring = true;
    const configurationVersion: number = this.configurationVersion;
    try {
      // This restricted permission comes from the signing profile, not a
      // requestPermissionsFromUser dialog. Error 201 remains a pending state.
      await dlpAntiPeep.requestAntiPeepOptions(context);
      if (configurationVersion === this.configurationVersion) { await this.refresh(); }
    } catch (error) {
      if (configurationVersion === this.configurationVersion && this.enabled && this.foreground && this.windowId > 0) {
        this.failure(error as BusinessError);
      }
    } finally {
      this.configuring = false;
    }
  }

  private current(generation: number): boolean {
    return generation === this.generation && this.enabled && this.foreground && this.windowId > 0;
  }

  private publish(state: AntiPeepState): void {
    AppStorage.setOrCreate<string>(STORAGE_KEY_ANTI_PEEP_STATE, state);
  }

  private failure(error: BusinessError): void {
    hilog.warn(0xD003900, 'AntiPeepProtection', 'Anti-peep operation failed: %{public}d', error.code);
    if (error.code === 201) { this.publish(AntiPeepState.PERMISSION_REQUIRED); }
    else if (error.code === 801) { this.publish(AntiPeepState.UNSUPPORTED); }
    else if (error.code === 1020600002) { this.publish(AntiPeepState.SYSTEM_OFF); }
    else if (error.code === 1020600004) { this.publish(AntiPeepState.FACE_REQUIRED); }
    else { this.publish(AntiPeepState.ERROR); }
  }

  private handleStatus(status: dlpAntiPeep.DlpAntiPeepStatus, generation: number): void {
    if (status === dlpAntiPeep.DlpAntiPeepStatus.PASS) {
      this.peeping = false;
      this.maskShown = false;
      this.episode++;
      this.publish(AntiPeepState.READY);
    } else if (status === dlpAntiPeep.DlpAntiPeepStatus.HIDE) {
      this.peeping = true;
      if (!this.maskShown && !this.maskPending) { this.showMask(generation); }
    } else {
      this.publish(AntiPeepState.ERROR);
    }
  }

  private async showMask(generation: number): Promise<void> {
    const episode: number = this.episode;
    this.maskPending = true;
    this.maskShown = true;
    this.publish(AntiPeepState.PROTECTING);
    try {
      await dlpAntiPeep.setAntiPeepMaskLayer(this.windowId);
      if (this.current(generation) && this.episode === episode && this.peeping) {
        this.publish(AntiPeepState.PROTECTED);
      }
    } catch (error) {
      if (this.current(generation) && this.episode === episode && this.peeping) {
        this.failure(error as BusinessError);
      }
    } finally {
      if (this.current(generation)) {
        this.maskPending = false;
        // A second risk episode may start while the first native request settles.
        if (this.peeping && !this.maskShown) { this.showMask(generation); }
      }
    }
  }

  private stop(): void {
    this.generation++;
    if (this.subscribed && this.listener !== null) {
      try { dlpAntiPeep.off('dlpAntiPeep', this.listener); }
      catch (error) { hilog.warn(0xD003900, 'AntiPeepProtection', 'Unable to release anti-peep subscription'); }
    }
    this.subscribed = false;
    this.listener = null;
    this.maskPending = false;
    this.maskShown = false;
    this.peeping = false;
    this.episode++;
  }
}

export const antiPeepProtection: AntiPeepProtection = new AntiPeepProtection();
