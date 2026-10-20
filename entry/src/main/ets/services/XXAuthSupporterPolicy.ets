// One supporter code belongs to one X account. The X user id (rest_id) is the
// stable identity: a handle can be renamed and released to someone else, while
// the numeric id never changes.
export class SupporterRecord {
  cardNo: string = '';
  accountId: string = '';
  expiresAt: number = 0;
  verifiedAt: number = 0;
}

export class XXAuthSupporterPolicy {
  static accountIdValid(accountId: string): boolean {
    return /^[1-9][0-9]{0,31}$/.test(accountId);
  }

  static valid(record: SupporterRecord | undefined): boolean {
    return record !== undefined && record !== null && typeof record.cardNo === 'string' &&
      /^[A-Za-z0-9_-]{8,256}$/.test(record.cardNo) && typeof record.accountId === 'string' &&
      XXAuthSupporterPolicy.accountIdValid(record.accountId) && Number.isFinite(record.expiresAt) &&
      record.expiresAt >= 0 && Number.isFinite(record.verifiedAt) && record.verifiedAt >= 0;
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
    return XXAuthSupporterPolicy.valid(record) && Number.isFinite(now) && record.expiresAt > now &&
      record.verifiedAt > 0 && record.verifiedAt <= now + 5 * 60 * 1000;
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
    return kept;
  }

  static promotional(kind: string): boolean {
    return kind === 'recommendation' || kind === 'banner';
  }

  // HTTP 400 also covers online limits, IP/region restrictions and software
  // configuration. Only an explicit card/binding rejection retires a record.
  static revoked(status: number, message: string): boolean {
    if (status !== 400 && status !== 404 && status !== 401 && status !== 403) { return false; }
    return /(?:卡密|兑换码)[\s：:]*(?:不存在|无效|已过期|已到期|已被禁用|已禁用|已被停用|已停用|已删除|不属于当前软件)/.test(message) ||
      /(?:机器码不匹配|已绑定其他.*(?:账号|账户|机器|设备))/.test(message) ||
      /card(?:\s+is)?\s+(?:not found|invalid|expired|disabled|deleted)|(?:invalid|expired|disabled)\s+card|machine.code\s+mismatch/i.test(message);
  }
}
