import { common } from '@kit.AbilityKit';
import { asset } from '@kit.AssetStoreKit';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import http from '@ohos.net.http';
import { XXAUTH_APP_ID } from './XXAuthService';
import { accountStore } from './AccountStore';
import { SupporterRecord, XXAuthSupporterPolicy } from './XXAuthSupporterPolicy';

export const SUPPORTER_ACTIVE_KEY: string = 'harmonyx.supporter_active';
export const SUPPORTER_EXPIRY_KEY: string = 'harmonyx.supporter_expiry';
const LEGACY_ALIAS: string = 'harmonyx_supporter_v1';
const ACCOUNT_ALIAS: string = 'harmonyx_supporter_account_v2_';
const REFRESH_MS: number = 5 * 60 * 1000;

export enum SupporterOutcome { NONE, SUCCESS, INVALID, NETWORK, STORAGE, NO_ACCOUNT, CONFIG }

interface SupporterLoginRequest { card_no: string; machine_code: string; }
interface SupporterSession { card_id?: string; software_id?: string; expires_at?: string; bound_machine_code?: string; }
interface SupporterEnvelope { code: number; message?: string; data?: SupporterSession; }

// Binding is the stable X rest_id, shared by both product variants and every
// device/version. Cookies/tokens never go to XXAuth. Assets stay bundle-local;
// a fresh install/device/variant restores by verifying the original code.
export class XXAuthSupporterService {
  private records: SupporterRecord[] = [];
  private context: common.Context | null = null;
  private loadedAccounts: Set<string> = new Set<string>();
  private loading: Map<string, Promise<boolean>> = new Map<string, Promise<boolean>>();
  private running: Promise<SupporterOutcome> | null = null;
  private runningAccountId: string = '';
  private runningCode: string = '';
  private lastAttempts: Map<string, number> = new Map<string, number>();

  private bytes(value: string): Uint8Array { return new util.TextEncoder().encodeInto(value); }

  private async readSecret(alias: string): Promise<Uint8Array | null> {
    const query: asset.AssetMap = new Map();
    query.set(asset.Tag.ALIAS, this.bytes(alias));
    query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL);
    try {
      const rows: asset.AssetMap[] = await asset.query(query);
      if (rows.length === 0) { return null; }
      const secret: Uint8Array = rows[0].get(asset.Tag.SECRET) as Uint8Array;
      if (!(secret instanceof Uint8Array)) { throw new Error('Invalid supporter asset'); }
      return secret;
    } catch (error) {
      if ((error as BusinessError).code === asset.ErrorCode.NOT_FOUND) { return null; }
      throw new Error('Supporter storage unavailable');
    }
  }

  private async readAsset(accountId: string): Promise<boolean> {
    try {
      const secret: Uint8Array | null = await this.readSecret(ACCOUNT_ALIAS + accountId);
      if (secret !== null) {
        const record: SupporterRecord =
          JSON.parse(new util.TextDecoder('utf-8').decodeToString(secret)) as SupporterRecord;
        if (!XXAuthSupporterPolicy.valid(record) || record.accountId !== accountId) { return false; }
        this.records = XXAuthSupporterPolicy.upsert(this.records, record);
      } else {
        // Read old arrays without overwriting them. The next cloud-confirmed
        // write migrates just this account; other accounts remain recoverable.
        const legacy: Uint8Array | null = await this.readSecret(LEGACY_ALIAS);
        if (legacy !== null) {
          const parsed: SupporterRecord[] =
            JSON.parse(new util.TextDecoder('utf-8').decodeToString(legacy)) as SupporterRecord[];
          if (!(parsed instanceof Array)) { return false; }
          const record: SupporterRecord = XXAuthSupporterPolicy.recordFor(parsed, accountId);
          if (XXAuthSupporterPolicy.valid(record)) {
            this.records = XXAuthSupporterPolicy.upsert(this.records, record);
          }
        }
      }
      this.loadedAccounts.add(accountId);
      return true;
    } catch (error) {
      // Locked/unavailable/corrupt storage is retryable and must never be
      // mistaken for an empty cache that is safe to overwrite.
      return false;
    }
  }

  private async load(accountId: string): Promise<boolean> {
    if (this.loadedAccounts.has(accountId)) { return true; }
    const existing: Promise<boolean> | undefined = this.loading.get(accountId);
    if (existing !== undefined) { return existing; }
    const task: Promise<boolean> = this.readAsset(accountId);
    this.loading.set(accountId, task);
    try { return await task; }
    finally { this.loading.delete(accountId); }
  }

  private async save(record: SupporterRecord): Promise<void> {
    const secret: Uint8Array = this.bytes(JSON.stringify(record));
    if (secret.length > 1024) { throw new Error('Supporter asset too large'); }
    const attributes: asset.AssetMap = new Map();
    attributes.set(asset.Tag.ALIAS, this.bytes(ACCOUNT_ALIAS + record.accountId));
    attributes.set(asset.Tag.SECRET, secret);
    attributes.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_FIRST_UNLOCKED);
    attributes.set(asset.Tag.SYNC_TYPE, asset.SyncType.NEVER);
    attributes.set(asset.Tag.CONFLICT_RESOLUTION, asset.ConflictResolution.OVERWRITE);
    await asset.add(attributes);
    this.records = XXAuthSupporterPolicy.upsert(this.records, record);
  }

  private currentAccountId(context: common.Context): string {
    try {
      const account = accountStore.active(context);
      const id: string = account === null ? '' : account.userId;
      return XXAuthSupporterPolicy.accountIdValid(id) ? id : '';
    } catch (error) { return ''; }
  }

  private selectedAccountId(): string {
    return this.context === null ? '' : this.currentAccountId(this.context);
  }

  active(): boolean {
    // Read the actual account even if a component's watcher was skipped while
    // another refresh was running. Old async work never owns current UI state.
    return XXAuthSupporterPolicy.active(this.records, this.selectedAccountId(), Date.now());
  }

  private publish(): void {
    const record: SupporterRecord = XXAuthSupporterPolicy.recordFor(this.records, this.selectedAccountId());
    const live: boolean = this.active();
    AppStorage.setOrCreate<boolean>(SUPPORTER_ACTIVE_KEY, live);
    AppStorage.setOrCreate<number>(SUPPORTER_EXPIRY_KEY, live ? record.expiresAt : 0);
  }

  async sync(context: common.Context): Promise<void> {
    this.context = context;
    this.publish();
    // A switch during the asset read loads the latest account as well.
    let accountId: string = this.currentAccountId(context);
    while (accountId.length > 0) {
      await this.load(accountId);
      const current: string = this.currentAccountId(context);
      if (current === accountId) { break; }
      accountId = current;
    }
    this.publish();
  }

  async refresh(context: common.Context, force: boolean = false): Promise<SupporterOutcome> {
    const accountId: string = this.currentAccountId(context);
    await this.sync(context);
    if (accountId.length === 0 || this.currentAccountId(context) !== accountId) { return SupporterOutcome.NONE; }
    if (!this.loadedAccounts.has(accountId)) { return SupporterOutcome.STORAGE; }
    const record: SupporterRecord = XXAuthSupporterPolicy.recordFor(this.records, accountId);
    if (record.cardNo.length === 0) { return SupporterOutcome.NONE; }
    const lastAttempt: number = this.lastAttempts.get(accountId) ?? 0;
    const elapsed: number = Date.now() - lastAttempt;
    if (!force && elapsed >= 0 && elapsed < REFRESH_MS) { return SupporterOutcome.NONE; }
    return this.verifySerial(context, record.cardNo, accountId);
  }

  async activate(context: common.Context, input: string): Promise<SupporterOutcome> {
    // Capture before the first await: a code typed for A must never bind to B.
    const accountId: string = this.currentAccountId(context);
    await this.sync(context);
    if (accountId.length === 0) { return SupporterOutcome.NO_ACCOUNT; }
    if (this.currentAccountId(context) !== accountId) { return SupporterOutcome.NONE; }
    if (!this.loadedAccounts.has(accountId)) { return SupporterOutcome.STORAGE; }
    const code: string = input.trim();
    if (!/^[A-Za-z0-9_-]{8,256}$/.test(code)) { return SupporterOutcome.INVALID; }
    return this.verifySerial(context, code, accountId);
  }

  private async verifySerial(context: common.Context, code: string, accountId: string): Promise<SupporterOutcome> {
    while (this.running !== null) {
      if (this.runningAccountId === accountId && this.runningCode === code) { return this.running; }
      await this.running;
      if (this.currentAccountId(context) !== accountId) { return SupporterOutcome.NONE; }
    }
    if (this.currentAccountId(context) !== accountId) { return SupporterOutcome.NONE; }
    this.lastAttempts.set(accountId, Date.now());
    this.runningAccountId = accountId;
    this.runningCode = code;
    this.running = this.verify(code, accountId);
    try {
      const outcome: SupporterOutcome = await this.running;
      if (outcome === SupporterOutcome.NETWORK || outcome === SupporterOutcome.STORAGE || outcome === SupporterOutcome.CONFIG) {
        this.lastAttempts.delete(accountId);
      }
      return outcome;
    }
    finally {
      this.running = null;
      this.runningAccountId = '';
      this.runningCode = '';
      this.publish();
    }
  }

  private async invalidate(code: string, accountId: string): Promise<SupporterOutcome> {
    const current: SupporterRecord = XXAuthSupporterPolicy.recordFor(this.records, accountId);
    if (current.cardNo !== code) { return SupporterOutcome.INVALID; }
    const retired: SupporterRecord = new SupporterRecord();
    retired.cardNo = code;
    retired.accountId = accountId;
    retired.verifiedAt = Date.now();
    // An explicit cloud revocation takes effect in memory even if disk fails.
    this.records = XXAuthSupporterPolicy.upsert(this.records, retired);
    try { await this.save(retired); }
    catch (error) { return SupporterOutcome.STORAGE; }
    return SupporterOutcome.INVALID;
  }

  private async verify(code: string, accountId: string): Promise<SupporterOutcome> {
    let request: http.HttpRequest | null = null;
    try {
      request = http.createHttp();
      const body: SupporterLoginRequest = { card_no: code, machine_code: accountId };
      const response: http.HttpResponse = await request.request('https://api.xxauth.com/open/v1/card/login', {
        method: http.RequestMethod.POST, expectDataType: http.HttpDataType.STRING,
        header: { app_id: XXAUTH_APP_ID, 'Accept': 'application/json', 'Content-Type': 'application/json' },
        extraData: JSON.stringify(body), connectTimeout: 8000, readTimeout: 8000, usingCache: false
      });
      if (typeof response.result !== 'string') { return SupporterOutcome.NETWORK; }
      const result: SupporterEnvelope = JSON.parse(response.result as string) as SupporterEnvelope;
      if (result === null || typeof result !== 'object') { return SupporterOutcome.NETWORK; }
      const session: SupporterSession | undefined = result.data;
      if (response.responseCode === 200 && result.code === 0 && session !== undefined && session !== null &&
        session.software_id === XXAUTH_APP_ID && typeof session.card_id === 'string' && session.card_id.length > 0) {
        // Never accept an unbound success: the server binding switch may have
        // been disabled or its response contract may have changed.
        if (typeof session.bound_machine_code !== 'string' || session.bound_machine_code.length === 0) {
          return SupporterOutcome.CONFIG;
        }
        if (session.bound_machine_code !== accountId) { return this.invalidate(code, accountId); }
        const expiresAt: number = Date.parse(session.expires_at ?? '');
        if (!Number.isFinite(expiresAt)) { return SupporterOutcome.NETWORK; }
        if (expiresAt <= Date.now()) { return this.invalidate(code, accountId); }
        const record: SupporterRecord = new SupporterRecord();
        record.cardNo = code;
        record.accountId = accountId;
        record.expiresAt = expiresAt;
        record.verifiedAt = Date.now();
        try { await this.save(record); }
        catch (error) { return SupporterOutcome.STORAGE; }
        return SupporterOutcome.SUCCESS;
      }
      const message: string = typeof result.message === 'string' ? result.message : '';
      const rejectionStatus: number = response.responseCode === 200 && Number.isFinite(result.code) && result.code !== 0 ?
        400 : response.responseCode;
      if (XXAuthSupporterPolicy.revoked(rejectionStatus, message)) { return this.invalidate(code, accountId); }
      return SupporterOutcome.NETWORK;
    } catch (error) { return SupporterOutcome.NETWORK; }
    finally { if (request !== null) { request.destroy(); } }
  }
}

export const xxAuthSupporterService: XXAuthSupporterService = new XXAuthSupporterService();
