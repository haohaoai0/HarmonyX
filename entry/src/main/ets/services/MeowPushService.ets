import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { http } from '@kit.NetworkKit';
import { xPrivateStore, XSession } from './XPrivateStore';
import { XPrivateClient, XPrivateResult } from './XPrivateClient';

export class MeowPushConfig {
  relayBase: string = '';
  relayToken: string = '';
  nickname: string = '';
  previews: boolean = false;
  subKey: string = '';
  pendingId: string = '';
  endpoint: string = '';
  p256dh: string = '';
  auth: string = '';
  registered: boolean = false;
  enabled: boolean = false;
  xCleanupPending: boolean = false;
  relayRemoved: boolean = false;
  lastCheckinAt: number = 0;
}

interface RelayBody {
  subKey: string;
  nickname?: string;
  previews?: boolean;
  pendingId?: string;
  code?: string;
}

export interface MeowRelayStatus {
  ok?: boolean;
  pendingId?: string;
  endpoint?: string;
  p256dh?: string;
  auth?: string;
  active?: boolean;
  receivedAt?: number;
  deliveredAt?: number;
  testAt?: number;
  queued?: number;
  lastError?: string;
}

interface XPushPreferences {
  AddressbookSetting: string;
  AdsSetting: string;
  DirectMessagesSetting: string;
  DmReactionSetting: string;
  FollowersNonVitSetting: string;
  FollowersVitSetting: string;
  LifelineAlertsSetting: string;
  LikesNonVitSetting: string;
  LikesVitSetting: string;
  LiveVideoSetting: string;
  MentionsSetting: string;
  MomentsSetting: string;
  NewsSetting: string;
  PhotoTagsSetting: string;
  RecommendationsSetting: string;
  RetweetsSetting: string;
  SpacesSetting: string;
  TopicsSetting: string;
  TweetsSetting: string;
}

export interface XPushDevice {
  token: string;
  encryption_key1: string;
  encryption_key2: string;
  env: number;
  protocol_version: number;
  locale: string;
  os_version: string;
  udid: string;
  settings?: XPushPreferences;
}
interface XPushWrapper { push_device_info: XPushDevice; }

export function xPushDevice(config: MeowPushConfig, save: boolean = false): XPushDevice {
  const device: XPushDevice = {
    token: config.endpoint, encryption_key1: config.p256dh, encryption_key2: config.auth,
    env: 3, protocol_version: 1, locale: 'en', os_version: 'Linux/Firefox', udid: 'Linux/Firefox'
  };
  if (save) {
    device.settings = {
      AddressbookSetting: 'off', AdsSetting: 'off', DirectMessagesSetting: 'on', DmReactionSetting: 'off',
      FollowersNonVitSetting: 'off', FollowersVitSetting: 'off', LifelineAlertsSetting: 'off',
      LikesNonVitSetting: 'off', LikesVitSetting: 'off', LiveVideoSetting: 'off', MentionsSetting: 'off',
      MomentsSetting: 'off', NewsSetting: 'off', PhotoTagsSetting: 'off', RecommendationsSetting: 'off',
      RetweetsSetting: 'off', SpacesSetting: 'off', TopicsSetting: 'off', TweetsSetting: 'off'
    };
  }
  return device;
}

export function validateMeowConfig(config: MeowPushConfig): void {
  // The supplied server is an HTTPS origin. Disallow credentials, query strings
  // and paths so management auth cannot accidentally be sent to another route.
  if (!/^https:\/\/[A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?(?::[0-9]{1,5})?$/.test(config.relayBase)) {
    throw new Error('relay_url');
  }
  if (config.relayToken.length < 32 || /[\r\n]/.test(config.relayToken)) { throw new Error('relay_token'); }
  if (config.nickname.length === 0 || config.nickname.length > 100 || /[\/\\\x00-\x1f]/.test(config.nickname)) {
    throw new Error('nickname');
  }
}

export class MeowPushService {
  private busy: Set<string> = new Set<string>();

  load(context: common.Context, accountId: string): MeowPushConfig {
    if (accountId.length === 0) { return new MeowPushConfig(); }
    const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: 'harmonyx_meow_push' });
    const raw: string = store.getSync(accountId, '') as string;
    if (raw.length === 0) { return new MeowPushConfig(); }
    // Corrupt saved subscriptions must not silently become a fresh registration
    // (which would leave the old remote subscription impossible to stop).
    return JSON.parse(raw) as MeowPushConfig;
  }

  private save(context: common.Context, accountId: string, config: MeowPushConfig): void {
    const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: 'harmonyx_meow_push' });
    store.putSync(accountId, JSON.stringify(config));
    store.flushSync();
  }

  private lock(accountId: string): void {
    if (this.busy.has(accountId)) { throw new Error('busy'); }
    this.busy.add(accountId);
  }

  private client(context: common.Context, accountId: string): XPrivateClient {
    const session: XSession = xPrivateStore.loadFor(context, accountId);
    if (!session.isUsable()) { throw new Error('sign_in'); }
    const client: XPrivateClient = new XPrivateClient();
    client.load(context);
    client.setSession(session); // Dedicated instance pins all awaits to this account.
    return client;
  }

  async begin(context: common.Context, accountId: string, draft: MeowPushConfig): Promise<void> {
    this.lock(accountId);
    try {
      this.client(context, accountId);
      const previous: MeowPushConfig = this.load(context, accountId);
      if (previous.endpoint.length > 0 || previous.xCleanupPending) { throw new Error('stop_first'); }
      draft.relayBase = draft.relayBase.trim().replace(/\/+$/, '');
      draft.relayToken = draft.relayToken.trim(); draft.nickname = draft.nickname.trim();
      validateMeowConfig(draft);
      draft.subKey = previous.relayBase === draft.relayBase && previous.subKey.length > 0 ? previous.subKey : this.newKey();
      // Save the management capability before any remote mutation.
      this.save(context, accountId, draft);
      const body: RelayBody = { subKey: draft.subKey, nickname: draft.nickname, previews: draft.previews };
      const result: MeowRelayStatus = await this.request(draft, 'register', body);
      if (typeof result.pendingId !== 'string' || !/^[a-f0-9]{48}$/.test(result.pendingId)) { throw new Error('relay_response'); }
      draft.pendingId = result.pendingId;
      this.save(context, accountId, draft);
    } finally { this.busy.delete(accountId); }
  }

  async confirm(context: common.Context, accountId: string, code: string): Promise<void> {
    this.lock(accountId);
    try {
      const client: XPrivateClient = this.client(context, accountId);
      const config: MeowPushConfig = this.load(context, accountId);
      if (config.relayRemoved) { throw new Error('stop_first'); }
      if (config.endpoint.length === 0) {
        if (!/^\d{6}$/.test(code.trim())) { throw new Error('code'); }
        const result: MeowRelayStatus = await this.request(config, 'confirm', {
          subKey: config.subKey, pendingId: config.pendingId, code: code.trim()
        });
        if (typeof result.endpoint !== 'string' || !result.endpoint.startsWith(config.relayBase + '/push/') ||
          !/^[a-f0-9]{48}$/.test(result.endpoint.substring((config.relayBase + '/push/').length)) ||
          !/^[A-Za-z0-9_-]{87}$/.test(result.p256dh ?? '') || !/^[A-Za-z0-9_-]{22}$/.test(result.auth ?? '')) {
          throw new Error('relay_response');
        }
        config.endpoint = result.endpoint; config.p256dh = result.p256dh ?? ''; config.auth = result.auth ?? '';
        this.save(context, accountId, config);
      }
      // Persist enough to clean up even when X accepts login but save fails.
      config.xCleanupPending = true;
      this.save(context, accountId, config);
      const login: XPushWrapper = { push_device_info: xPushDevice(config) };
      this.requireX(await client.notificationPushSettings('login', login));
      const settings: XPushWrapper = { push_device_info: xPushDevice(config, true) };
      this.requireX(await client.notificationPushSettings('save', settings));
      await this.request(config, 'activate', { subKey: config.subKey });
      config.registered = true; config.enabled = true; config.pendingId = ''; config.xCleanupPending = false;
      config.lastCheckinAt = Date.now();
      this.save(context, accountId, config);
    } finally { this.busy.delete(accountId); }
  }

  async stop(context: common.Context, accountId: string): Promise<void> {
    this.lock(accountId);
    try {
      const config: MeowPushConfig = this.load(context, accountId);
      if (config.subKey.length === 0) { return; }
      // Remove the relay first. A failed deletion retains all state and is shown
      // as a failure, never as a successful off switch.
      await this.request(config, 'delete', { subKey: config.subKey });
      config.enabled = false; config.registered = false; config.pendingId = '';
      config.relayRemoved = true;
      config.xCleanupPending = config.endpoint.length > 0;
      this.save(context, accountId, config);
      if (config.xCleanupPending) {
        try {
          this.requireX(await this.client(context, accountId).notificationPushSettings('logout', xPushDevice(config)));
        } catch (error) { throw new Error('x_cleanup'); }
      }
      config.subKey = ''; config.endpoint = ''; config.auth = ''; config.p256dh = ''; config.xCleanupPending = false;
      this.save(context, accountId, config);
    } finally { this.busy.delete(accountId); }
  }

  async beforeSignOut(context: common.Context, accountId: string): Promise<void> {
    try { await this.stop(context, accountId); }
    catch (error) {
      // X registration can remain until its next check-in, but a confirmed
      // relay deletion is sufficient to prevent delivery after signing out.
      if ((error as Error).message !== 'x_cleanup') { throw new Error((error as Error).message); }
    }
  }

  async status(context: common.Context, accountId: string): Promise<MeowRelayStatus> {
    const config: MeowPushConfig = this.load(context, accountId);
    return await this.request(config, 'status', { subKey: config.subKey });
  }

  async test(context: common.Context, accountId: string): Promise<void> {
    const config: MeowPushConfig = this.load(context, accountId);
    await this.request(config, 'test', { subKey: config.subKey });
  }

  async checkin(context: common.Context, accountId: string): Promise<void> {
    if (this.busy.has(accountId)) { return; }
    this.lock(accountId);
    try {
      const config: MeowPushConfig = this.load(context, accountId);
      if (!config.enabled || Date.now() - (config.lastCheckinAt ?? 0) < 12 * 60 * 60 * 1000) { return; }
      const payload: XPushWrapper = { push_device_info: xPushDevice(config) };
      this.requireX(await this.client(context, accountId).notificationPushSettings('checkin', payload));
      config.lastCheckinAt = Date.now();
      this.save(context, accountId, config);
    } finally { this.busy.delete(accountId); }
  }

  private requireX(result: XPrivateResult): void {
    if (!result.ok) { throw new Error('x_' + result.status.toString()); }
  }

  private newKey(): string {
    const bytes: Uint8Array = cryptoFramework.createRandom().generateRandomSync(24).data;
    let result: string = '';
    for (let i: number = 0; i < bytes.length; i++) { result += bytes[i].toString(16).padStart(2, '0'); }
    return result;
  }

  private async request(config: MeowPushConfig, action: string, body: RelayBody): Promise<MeowRelayStatus> {
    validateMeowConfig(config);
    const request: http.HttpRequest = http.createHttp();
    try {
      const response: http.HttpResponse = await request.request(config.relayBase + '/v1/meow/' + action, {
        method: http.RequestMethod.POST, connectTimeout: 15000, readTimeout: 15000,
        header: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + config.relayToken },
        extraData: JSON.stringify(body)
      });
      if (response.responseCode !== 200) { throw new Error('relay_' + response.responseCode.toString()); }
      const result: MeowRelayStatus = JSON.parse(String(response.result)) as MeowRelayStatus;
      if (result === null || result.ok !== true) { throw new Error('relay_response'); }
      return result;
    } finally { request.destroy(); }
  }
}

export const meowPushService: MeowPushService = new MeowPushService();
