import { common } from '@kit.AbilityKit';
import { asset } from '@kit.AssetStoreKit';
import { util } from '@kit.ArkTS';
import http from '@ohos.net.http';
import { XXAUTH_APP_ID } from './XXAuthService';
import { accountStore } from './AccountStore';
import { SupporterRecord, XXAuthSupporterPolicy } from './XXAuthSupporterPolicy';

export const SUPPORTER_ACTIVE_KEY: string = 'harmonyx.supporter_active';
export const SUPPORTER_EXPIRY_KEY: string = 'harmonyx.supporter_expiry';
const ALIAS: string = 'harmonyx_supporter_v1';
const REFRESH_MS: number = 5 * 60 * 1000;

export enum SupporterOutcome { NONE, SUCCESS, INVALID, NETWORK, STORAGE, NO_ACCOUNT }

interface SupporterLoginRequest { card_no: string; machine_code: string; }
interface SupporterSession { card_id?: string; software_id?: string; expires_at?: string; bound_machine_code?: string; }
interface SupporterEnvelope { code: number; message?: string; data?: SupporterSession; }

// Optional supporter validation is separate from the user's X session. The
// entitlement is keyed by the X user id (rest_id) of the signed-in account, so
// one code belongs to one account and survives a device change; the code itself
// only travels to XXAuth. X cookies and tokens never leave the device.
export class XXAuthSupporterService {
  private records: SupporterRecord[] = [];
  private accountId: string = '';
  private loaded: Promise<void> | null = null;
  private running: Promise<SupporterOutcome> | null = null;
  private lastAttempt: number = 0;

  private bytes(value: string): Uint8Array { return new util.TextEncoder().encodeInto(value); }

  private load(): Promise<void> {
    if (this.loaded === null) { this.loaded = this.readAsset(); }
    return this.loaded;
  }

  private async readAsset(): Promise<void> {
    const query: asset.AssetMap = new Map();
    query.set(asset.Tag.ALIAS, this.bytes(ALIAS));
    query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL);
    try {
      const rows: asset.AssetMap[] = await asset.query(query);
      if (rows.length > 0) {
        const secret: Uint8Array = rows[0].get(asset.Tag.SECRET) as Uint8Array;
        const parsed: SupporterRecord[] =
          JSON.parse(new util.TextDecoder('utf-8').decodeToString(secret)) as SupporterRecord[];
        this.records = parsed instanceof Array ? parsed.filter(
          (item: SupporterRecord): boolean => XXAuthSupporterPolicy.valid(item)) : [];
      }
    } catch (error) {
      // Missing/locked/unavailable assets never create a supporter entitlement.
    }
  }

  private async save(records: SupporterRecord[]): Promise<void> {
    const attributes: asset.AssetMap = new Map();
    attributes.set(asset.Tag.ALIAS, this.bytes(ALIAS));
    attributes.set(asset.Tag.SECRET, this.bytes(JSON.stringify(records)));
    attributes.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_FIRST_UNLOCKED);
    attributes.set(asset.Tag.SYNC_TYPE, asset.SyncType.NEVER);
    attributes.set(asset.Tag.CONFLICT_RESOLUTION, asset.ConflictResolution.OVERWRITE);
    await asset.add(attributes);
    this.records = records;
  }

  private currentAccountId(context: common.Context): string {
    try {
      const account = accountStore.active(context);
      return account === null ? '' : account.userId;
    } catch (error) { return ''; }
  }

  private live(): boolean {
    return XXAuthSupporterPolicy.active(this.records, this.accountId, Date.now());
  }

  active(): boolean { return this.live(); }

  private publish(): void {
    const record: SupporterRecord = XXAuthSupporterPolicy.recordFor(this.records, this.accountId);
    const live: boolean = this.live();
    AppStorage.setOrCreate<boolean>(SUPPORTER_ACTIVE_KEY, live);
    AppStorage.setOrCreate<number>(SUPPORTER_EXPIRY_KEY, live ? record.expiresAt : 0);
  }

  // Reload the encrypted cache and re-evaluate it against the signed-in account.
  async sync(context: common.Context): Promise<void> {
    await this.load();
    this.accountId = this.currentAccountId(context);
    this.publish();
  }

  async refresh(context: common.Context, force: boolean = false): Promise<SupporterOutcome> {
    await this.sync(context);
    if (this.running !== null) { return this.running; }
    const record: SupporterRecord = XXAuthSupporterPolicy.recordFor(this.records, this.accountId);
    if (record.cardNo.length === 0) { return SupporterOutcome.NONE; }
    if (!force && Date.now() - this.lastAttempt < REFRESH_MS) { return SupporterOutcome.NONE; }
    return this.activate(context, record.cardNo);
  }

  async activate(context: common.Context, input: string): Promise<SupporterOutcome> {
    await this.sync(context);
    if (this.running !== null) { return this.running; }
    if (this.accountId.length === 0) { return SupporterOutcome.NO_ACCOUNT; }
    const code: string = input.trim();
    if (!/^[A-Za-z0-9_-]{8,256}$/.test(code)) { return SupporterOutcome.INVALID; }
    this.lastAttempt = Date.now();
    this.running = this.verify(code, this.accountId);
    try { return await this.running; }
    finally { this.running = null; this.publish(); }
  }

  // Only a record that already belonged to this account can be retired, so a
  // mistyped or reused code never revokes valid supporter access.
  private async invalidate(code: string, accountId: string): Promise<SupporterOutcome> {
    const current: SupporterRecord = XXAuthSupporterPolicy.recordFor(this.records, accountId);
    if (current.cardNo !== code) { return SupporterOutcome.INVALID; }
    const retired: SupporterRecord = new SupporterRecord();
    retired.cardNo = code;
    retired.accountId = accountId;
    retired.expiresAt = 0;
    retired.verifiedAt = Date.now();
    try { await this.save(XXAuthSupporterPolicy.upsert(this.records, retired)); }
    catch (error) { return SupporterOutcome.STORAGE; }
    return SupporterOutcome.INVALID;
  }

  private async verify(code: string, accountId: string): Promise<SupporterOutcome> {
    let request: http.HttpRequest | null = null;
    try {
      request = http.createHttp();
      // XXAuth binds the code to this opaque value on first use; the X user id
      // is stable across renames and re-installs on the same account.
      const body: SupporterLoginRequest = { card_no: code, machine_code: accountId };
      const response: http.HttpResponse = await request.request('https://api.xxauth.com/open/v1/card/login', {
        method: http.RequestMethod.POST, expectDataType: http.HttpDataType.STRING,
        header: { app_id: XXAUTH_APP_ID, 'Accept': 'application/json', 'Content-Type': 'application/json' },
        extraData: JSON.stringify(body), connectTimeout: 8000, readTimeout: 8000
      });
      if (typeof response.result !== 'string') { return SupporterOutcome.NETWORK; }
      const result: SupporterEnvelope = JSON.parse(response.result as string) as SupporterEnvelope;
      const session: SupporterSession | undefined = result.data;
      if (response.responseCode === 200 && result.code === 0 && session !== undefined &&
        session.software_id === XXAUTH_APP_ID && typeof session.card_id === 'string' && session.card_id.length > 0) {
        const expiresAt: number = Date.parse(session.expires_at ?? '');
        if (!Number.isFinite(expiresAt)) { return SupporterOutcome.NETWORK; }
        if (expiresAt <= Date.now()) { return this.invalidate(code, accountId); }
        if (session.bound_machine_code && session.bound_machine_code !== accountId) {
          return SupporterOutcome.INVALID;
        }
        const record: SupporterRecord = new SupporterRecord();
        record.cardNo = code;
        record.accountId = accountId;
        record.expiresAt = expiresAt;
        record.verifiedAt = Date.now();
        try { await this.save(XXAuthSupporterPolicy.upsert(this.records, record)); }
        catch (error) { return SupporterOutcome.STORAGE; }
        return SupporterOutcome.SUCCESS;
      }
      if (XXAuthSupporterPolicy.revoked(response.responseCode, result.message ?? '')) {
        return this.invalidate(code, accountId);
      }
      return SupporterOutcome.NETWORK;
    } catch (error) { return SupporterOutcome.NETWORK; }
    finally { if (request !== null) { request.destroy(); } }
  }
}

export const xxAuthSupporterService: XXAuthSupporterService = new XXAuthSupporterService();
