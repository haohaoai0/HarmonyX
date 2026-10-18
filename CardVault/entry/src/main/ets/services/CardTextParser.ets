import { CardDraft, CardState } from '../models/CardRecord';

export class CardParseResult {
  rows: CardDraft[] = [];
  duplicateLines: number = 0;
  invalidLines: number = 0;
  totalLines: number = 0;
}

export class CardTextParser {
  private static readonly KEY_PATTERN: RegExp = /^[A-Za-z0-9][A-Za-z0-9_-]{5,127}$/;

  static parse(text: string): CardParseResult {
    const result: CardParseResult = new CardParseResult();
    const seen: Set<string> = new Set<string>();
    const normalized: string = text.replace(/^\uFEFF/, '');
    const lines: string[] = normalized.split(/\r?\n/);
    const now: number = Date.now();
    for (let i: number = 0; i < lines.length; i++) {
      const raw: string = lines[i].trim();
      if (raw.length === 0 || raw.startsWith('#')) {
        continue;
      }
      result.totalLines += 1;
      const parts: string[] = CardTextParser.columns(raw);
      let key: string = CardTextParser.extractKey(parts[0]);
      if (key.length === 0) {
        result.invalidLines += 1;
        continue;
      }
      if (!CardTextParser.KEY_PATTERN.test(key)) {
        result.invalidLines += 1;
        continue;
      }
      if (seen.has(key)) {
        result.duplicateLines += 1;
        continue;
      }
      seen.add(key);
      const recipient: string = parts.length > 1 ? parts[1].trim() : '';
      const donation: number = parts.length > 2 ? CardTextParser.parseMoney(parts[2]) : 0;
      const state: string = parts.length > 3 ? CardTextParser.parseState(parts[3]) : CardState.UNUSED;
      const note: string = parts.length > 4 ? parts.slice(4).join(' ').trim() : '';
      result.rows.push(new CardDraft(key, recipient, donation, state, note, now));
    }
    return result;
  }

  private static columns(line: string): string[] {
    if (line.indexOf('\t') >= 0) {
      return line.split('\t');
    }
    if (line.indexOf(',') >= 0) {
      return line.split(',');
    }
    return [line];
  }

  private static extractKey(value: string): string {
    let key: string = value.trim();
    const separatorIndex: number = key.search(/[:：]/);
    if (separatorIndex >= 0) {
      key = key.substring(separatorIndex + 1).trim();
    }
    return key.replace(/\s+/g, '');
  }

  private static parseMoney(value: string): number {
    const cleaned: string = value.replace(/[¥￥,\s]/g, '');
    const parsed: number = Number(cleaned);
    if (Number.isNaN(parsed) || parsed < 0) {
      return 0;
    }
    return Math.round(parsed * 100) / 100;
  }

  private static parseState(value: string): string {
    const normalized: string = value.trim().toLowerCase();
    if (normalized.includes('使用') || normalized === 'used') {
      return CardState.USED;
    }
    if (normalized.includes('作废') || normalized.includes('禁用') || normalized === 'revoked') {
      return CardState.REVOKED;
    }
    return CardState.UNUSED;
  }
}
