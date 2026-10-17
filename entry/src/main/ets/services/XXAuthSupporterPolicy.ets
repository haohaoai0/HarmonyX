// One supporter code belongs to one X account. The X user id (rest_id) is the
// stable identity: a handle can be renamed and released to someone else, while
// the numeric id never changes.
export const SUPPORTER_ACCOUNT_LIMIT: number = 4;

export class SupporterRecord {
  cardNo: string = '';
  accountId: string = '';
  expiresAt: number = 0;
  verifiedAt: number = 0;
}

export class XXAuthSupporterPolicy {
  static valid(record: SupporterRecord | undefined): boolean {
    return record !== undefined && typeof record.cardNo === 'string' && record.cardNo.length > 0 &&
      typeof record.accountId === 'string' && record.accountId.length > 0 &&
      Number.isFinite(record.expiresAt) && Number.isFinite(record.verifiedAt);
  }

  static recordFor(records: SupporterRecord[], accountId: string): SupporterRecord {
    let selected: SupporterRecord = new SupporterRecord();
    if (accountId.length === 0) { return selected; }
    let selectedTime: number = -1;
    for (let i: number = 0; i < records.length; i++) {
      const candidate: SupporterRecord = records[i];
      if (!XXAuthSupporterPolicy.valid(candidate) || candidate.accountId !== accountId) { continue; }
      if (candidate.verifiedAt > selectedTime) { selected = candidate; selectedTime = candidate.verifiedAt; }
    }
    return selected;
  }

  static active(records: SupporterRecord[], accountId: string, now: number): boolean {
    const record: SupporterRecord = XXAuthSupporterPolicy.recordFor(records, accountId);
    return XXAuthSupporterPolicy.valid(record) && record.expiresAt > now && record.verifiedAt > 0;
  }

  // A rejected code for one account never erases another account's record, and
  // each account keeps a single record.
  static upsert(records: SupporterRecord[], record: SupporterRecord): SupporterRecord[] {
    const kept: SupporterRecord[] = [];
    for (let i: number = 0; i < records.length; i++) {
      const candidate: SupporterRecord = records[i];
      if (XXAuthSupporterPolicy.valid(candidate) && candidate.accountId !== record.accountId) {
        kept.push(candidate);
      }
    }
    kept.push(record);
    while (kept.length > SUPPORTER_ACCOUNT_LIMIT) {
      let oldest: number = 0;
      for (let i: number = 1; i < kept.length; i++) {
        if (kept[i].verifiedAt < kept[oldest].verifiedAt) { oldest = i; }
      }
      kept.splice(oldest, 1);
    }
    return kept;
  }

  static promotional(kind: string): boolean {
    return kind === 'recommendation' || kind === 'banner';
  }

  // The card login endpoint answers for one card, so a definitive rejection
  // means that card is unusable: disabled, deleted, expired or bound elsewhere.
  // Rate limits and server faults are transient and keep the cached access, and
  // a wrongly retired code is restored by the next successful verification.
  static revoked(status: number, message: string): boolean {
    if (status === 404 || status === 400) { return true; }
    if (status === 401 || status === 403) { return /卡密|机器码|设备/.test(message); }
    return false;
  }
}
