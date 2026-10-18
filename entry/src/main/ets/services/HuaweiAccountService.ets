import { common } from '@kit.AbilityKit';
import { authentication } from '@kit.AccountKit';
import { preferences } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { BusinessError, commonEventManager } from '@kit.BasicServicesKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { cacheHuaweiAvatar } from './HuaweiAccountAvatar';
import { hilog } from '@kit.PerformanceAnalysisKit';

export const HUAWEI_ACCOUNT_SIGNED_IN: string = 'harmonyx.huawei.signed_in';
export const HUAWEI_ACCOUNT_NAME: string = 'harmonyx.huawei.name';
export const HUAWEI_ACCOUNT_AVATAR: string = 'harmonyx.huawei.avatar';
export const HUAWEI_ACCOUNT_BUSY: string = 'harmonyx.huawei.busy';

export class HuaweiAccountProfile {
  unionID: string = '';
  openID: string = '';
  nickName: string = '';
  avatarUri: string = '';
}

// This session is independent of AccountStore/AuthStore, which own X credentials.
export class HuaweiAccountService {
  private context: common.UIAbilityContext | null = null;
  private profile: HuaweiAccountProfile | null = null;
  private verified: boolean = false;
  private generation: number = 0;
  private busy: boolean = false;
  private subscriber: commonEventManager.CommonEventSubscriber | null = null;
  private listeners: (() => void)[] = [];
  private ready: Promise<void> | null = null;
  private lifecycle: number = 0;
  private avatar: string = '';
  private avatarGeneration: number = -1;

  initialize(context: common.UIAbilityContext): Promise<void> {
    if (this.ready !== null) { return this.ready; }
    this.context = context;
    this.ready = this.restore(++this.lifecycle);
    return this.ready;
  }

  private store(): preferences.Preferences {
    if (this.context === null) { throw new Error('Huawei account context unavailable'); }
    return preferences.getPreferencesSync(this.context, { name: 'harmonyx_huawei_account' });
  }

  private async restore(lifecycle: number): Promise<void> {
    this.publish();
    try {
      const raw: string = this.store().getSync('profile', '') as string;
      if (raw.length > 0) {
        const cached: HuaweiAccountProfile = JSON.parse(raw) as HuaweiAccountProfile;
        if (typeof cached.unionID === 'string' && typeof cached.openID === 'string' &&
          typeof cached.nickName === 'string' && typeof cached.avatarUri === 'string' &&
          (cached.unionID.length > 0 || cached.openID.length > 0)) { this.profile = cached; }
      }
    } catch (error) { this.profile = null; }
    await this.revalidate();
    if (lifecycle !== this.lifecycle) { return; }
    if (this.isSignedIn() && this.context !== null) {
      const path: string = this.context.filesDir + '/huawei-account-avatar.png';
      try { if (fileIo.accessSync(path)) { this.avatar = fileUri.getUriFromPath(path); this.publish(); } } catch (error) { /* Cache miss. */ }
      this.refreshAvatar();
    }
    try {
      const subscriber: commonEventManager.CommonEventSubscriber = await commonEventManager.createSubscriber({ events: [
        commonEventManager.Support.COMMON_EVENT_DISTRIBUTED_ACCOUNT_LOGOUT
      ] });
      if (lifecycle !== this.lifecycle) { commonEventManager.unsubscribe(subscriber); return; }
      this.subscriber = subscriber;
      commonEventManager.subscribe(this.subscriber, (error: BusinessError,
        data: commonEventManager.CommonEventData): void => {
        if (!error && data.event === commonEventManager.Support.COMMON_EVENT_DISTRIBUTED_ACCOUNT_LOGOUT) {
          this.logout();
        }
      });
    } catch (error) { /* Foreground checks remain authoritative if events are unavailable. */ }
  }

  async revalidate(): Promise<boolean> {
    if (this.profile === null) { return false; }
    const generation: number = this.generation;
    const profile: HuaweiAccountProfile = this.profile;
    try {
      const result: authentication.StateResult = await new authentication.HuaweiIDProvider().getHuaweiIDState({
        idType: profile.unionID.length > 0 ? authentication.IdType.UNION_ID : authentication.IdType.OPEN_ID,
        idValue: profile.unionID.length > 0 ? profile.unionID : profile.openID
      });
      if (generation !== this.generation) { return false; }
      if (result.state !== authentication.State.AUTHORIZED) { this.logout(); return false; }
      this.verified = true;
      this.publish();
      this.notify();
      this.refreshAvatar();
      return true;
    } catch (error) {
      // A failed check must never authorize access to the cloud directory.
      if (generation === this.generation) { this.verified = false; this.publish(); this.notify(); }
      return false;
    }
  }

  async login(context: common.UIAbilityContext): Promise<void> {
    await this.initialize(context);
    if (this.busy) { return; }
    this.busy = true;
    const generation: number = ++this.generation;
    this.publish();
    try {
      const request: authentication.AuthorizationWithHuaweiIDRequest =
        new authentication.HuaweiIDProvider().createAuthorizationWithHuaweiIDRequest();
      request.scopes = ['profile'];
      request.permissions = ['serviceauthcode'];
      request.forceAuthorization = true;
      request.idTokenSignAlgorithm = authentication.IdTokenSignAlgorithm.PS256;
      request.state = util.generateRandomUUID();
      const response: authentication.AuthorizationWithHuaweiIDResponse =
        await new authentication.AuthenticationController(context).executeRequest(request) as
          authentication.AuthorizationWithHuaweiIDResponse;
      if (generation !== this.generation) { return; }
      if (response.state !== undefined && response.state !== request.state) { throw new Error('State mismatch'); }
      if (response.data === undefined) { throw new Error('Huawei account profile unavailable'); }
      const profile: HuaweiAccountProfile = new HuaweiAccountProfile();
      profile.unionID = response.data.unionID ?? '';
      profile.openID = response.data.openID ?? '';
      profile.nickName = response.data.nickName ?? '';
      profile.avatarUri = response.data.avatarUri ?? '';
      if (profile.unionID.length === 0 && profile.openID.length === 0) { throw new Error('Missing account ID'); }
      if (!profile.avatarUri.startsWith('https://')) { profile.avatarUri = ''; }
      const store: preferences.Preferences = this.store();
      store.putSync('profile', JSON.stringify(profile));
      store.flushSync();
      this.profile = profile;
      this.avatar = '';
      this.verified = true;
      this.publish();
      this.notify();
      this.refreshAvatar();
    } catch (error) {
      // Never log the response, authorization code, profile or account identifier.
      hilog.warn(0xFF00, 'HarmonyX-HuaweiAccount', 'Authorization failed, code=%{public}d',
        (error as BusinessError).code ?? 0);
      throw error as Error;
    } finally {
      if (generation === this.generation) { this.busy = false; this.publish(); }
    }
  }

  logout(): void {
    this.generation++;
    this.busy = false;
    this.verified = false;
    this.profile = null;
    this.avatar = '';
    if (this.context !== null) {
      try { fileIo.unlinkSync(this.context.filesDir + '/huawei-account-avatar.png'); } catch (error) { /* Cache miss. */ }
    }
    try { const store: preferences.Preferences = this.store(); store.putSync('profile', ''); store.flushSync(); }
    catch (error) { /* Keep the active session signed out even if storage fails. */ }
    this.publish();
    this.notify();
  }

  isSignedIn(): boolean { return this.verified && this.profile !== null; }
  owner(): string { return this.isSignedIn() && this.profile !== null ? this.profile.unionID || this.profile.openID : ''; }
  sessionGeneration(): number { return this.generation; }
  addListener(listener: () => void): void { this.listeners.push(listener); }
  removeListener(listener: () => void): void { this.listeners = this.listeners.filter((item: () => void): boolean => item !== listener); }
  private notify(): void { this.listeners.forEach((listener: () => void): void => listener()); }

  private publish(): void {
    AppStorage.setOrCreate<boolean>(HUAWEI_ACCOUNT_SIGNED_IN, this.isSignedIn());
    AppStorage.setOrCreate<boolean>(HUAWEI_ACCOUNT_BUSY, this.busy);
    AppStorage.setOrCreate<string>(HUAWEI_ACCOUNT_NAME, this.isSignedIn() ? this.profile?.nickName ?? '' : '');
    AppStorage.setOrCreate<string>(HUAWEI_ACCOUNT_AVATAR, this.isSignedIn() ? this.avatar : '');
  }

  private refreshAvatar(): void {
    if (this.context === null || this.profile === null || !this.isSignedIn()) { return; }
    const generation: number = this.generation;
    if (this.avatarGeneration === generation) { return; }
    this.avatarGeneration = generation;
    cacheHuaweiAvatar(this.context, this.profile.avatarUri,
      (): boolean => this.generation === generation && this.isSignedIn()).then((avatar: string): void => {
      if (generation === this.generation && this.isSignedIn() && avatar.length > 0) { this.avatar = avatar; this.publish(); }
    }).catch((): void => {});
  }

  dispose(): void {
    this.generation++;
    this.lifecycle++;
    if (this.subscriber !== null) {
      try { commonEventManager.unsubscribe(this.subscriber); } catch (error) { /* Already unsubscribed. */ }
    }
    this.subscriber = null;
    this.ready = null;
  }
}

export const huaweiAccountService: HuaweiAccountService = new HuaweiAccountService();
