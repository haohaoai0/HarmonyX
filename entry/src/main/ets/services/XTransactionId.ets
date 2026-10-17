// X-Client-Transaction-Id provider for authenticated private-surface calls.
//
// X rejects a cookie-authenticated write with HTTP 200 / error 226 when the
// browser transaction header is missing. The header is derived from the public
// web client's rotating key material:
//
//   base64(verification) + little-endian time + SHA-256 digest prefix + 3
//
// The pair list is small and public. It is bundled as a fallback and refreshed
// from the community mirror when the network allows it, so a changed X web
// build can be picked up without shipping a new application package.
import http from '@ohos.net.http';
import hilog from '@ohos.hilog';
import util from '@ohos.util';
import { common } from '@kit.AbilityKit';
import { proxyStore } from './ProxyStore';

const DOMAIN = 0xFF00;
const TAG = 'HarmonyX-TxnId';
const RAWFILE_NAME = 'x_tid_pair.json';
const REFRESH_TTL_MS = 6 * 60 * 60 * 1000;
const REQUEST_TIMEOUT_MS = 15000;
const EPOCH_OFFSET_MS = 1682924400000;
const DEFAULT_KEYWORD = 'obfiowerehiring';
const ADDITIONAL_RANDOM_NUMBER = 3;

const PAIR_URLS: string[] = [
  'https://cdn.jsdelivr.net/gh/fa0311/x-client-transaction-id-pair-dict@main/pair.json',
  'https://fastly.jsdelivr.net/gh/fa0311/x-client-transaction-id-pair-dict@main/pair.json',
  'https://raw.githubusercontent.com/fa0311/x-client-transaction-id-pair-dict/refs/heads/main/pair.json'
];

export class XTransactionIdPair {
  animationKey: string = '';
  verification: string = '';

  constructor(animationKey: string, verification: string) {
    this.animationKey = animationKey;
    this.verification = verification;
  }
}

function rightRotate(value: number, bits: number): number {
  return ((value >>> bits) | (value << (32 - bits))) >>> 0;
}

// Minimal SHA-256 over the ASCII transaction string. The input is deliberately
// narrow: method, path and the public key material contain no non-ASCII data.
function sha256Bytes(ascii: string): number[] {
  const bytes: number[] = [];
  for (let index: number = 0; index < ascii.length; index++) {
    bytes.push(ascii.charCodeAt(index) & 0xFF);
  }
  const bitLength: number = bytes.length * 8;
  bytes.push(0x80);
  while (bytes.length % 64 !== 56) {
    bytes.push(0);
  }
  const high: number = Math.floor(bitLength / 0x100000000);
  const low: number = bitLength >>> 0;
  bytes.push((high >>> 24) & 0xFF, (high >>> 16) & 0xFF, (high >>> 8) & 0xFF, high & 0xFF);
  bytes.push((low >>> 24) & 0xFF, (low >>> 16) & 0xFF, (low >>> 8) & 0xFF, low & 0xFF);

  let h0: number = 0x6a09e667;
  let h1: number = 0xbb67ae85;
  let h2: number = 0x3c6ef372;
  let h3: number = 0xa54ff53a;
  let h4: number = 0x510e527f;
  let h5: number = 0x9b05688c;
  let h6: number = 0x1f83d9ab;
  let h7: number = 0x5be0cd19;
  const constants: number[] = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
  ];

  for (let offset: number = 0; offset < bytes.length; offset += 64) {
    const words: number[] = [];
    for (let index: number = 0; index < 16; index++) {
      const position: number = offset + index * 4;
      words.push(((bytes[position] << 24) | (bytes[position + 1] << 16) |
        (bytes[position + 2] << 8) | bytes[position + 3]) >>> 0);
    }
    for (let index: number = 16; index < 64; index++) {
      const s0: number = (rightRotate(words[index - 15], 7) ^
        rightRotate(words[index - 15], 18) ^ (words[index - 15] >>> 3)) >>> 0;
      const s1: number = (rightRotate(words[index - 2], 17) ^
        rightRotate(words[index - 2], 19) ^ (words[index - 2] >>> 10)) >>> 0;
      words.push((words[index - 16] + s0 + words[index - 7] + s1) >>> 0);
    }

    let a: number = h0;
    let b: number = h1;
    let c: number = h2;
    let d: number = h3;
    let e: number = h4;
    let f: number = h5;
    let g: number = h6;
    let h: number = h7;
    for (let index: number = 0; index < 64; index++) {
      const s1: number = (rightRotate(e, 6) ^ rightRotate(e, 11) ^ rightRotate(e, 25)) >>> 0;
      const choose: number = ((e & f) ^ ((~e) & g)) >>> 0;
      const temp1: number = (h + s1 + choose + constants[index] + words[index]) >>> 0;
      const s0: number = (rightRotate(a, 2) ^ rightRotate(a, 13) ^ rightRotate(a, 22)) >>> 0;
      const majority: number = ((a & b) ^ (a & c) ^ (b & c)) >>> 0;
      const temp2: number = (s0 + majority) >>> 0;
      h = g;
      g = f;
      f = e;
      e = (d + temp1) >>> 0;
      d = c;
      c = b;
      b = a;
      a = (temp1 + temp2) >>> 0;
    }
    h0 = (h0 + a) >>> 0;
    h1 = (h1 + b) >>> 0;
    h2 = (h2 + c) >>> 0;
    h3 = (h3 + d) >>> 0;
    h4 = (h4 + e) >>> 0;
    h5 = (h5 + f) >>> 0;
    h6 = (h6 + g) >>> 0;
    h7 = (h7 + h) >>> 0;
  }

  const output: number[] = [];
  const state: number[] = [h0, h1, h2, h3, h4, h5, h6, h7];
  for (let index: number = 0; index < state.length; index++) {
    output.push((state[index] >>> 24) & 0xFF, (state[index] >>> 16) & 0xFF,
      (state[index] >>> 8) & 0xFF, state[index] & 0xFF);
  }
  return output;
}

export class XTransactionIdService {
  private pairs: XTransactionIdPair[] = [];
  private bundledPairs: XTransactionIdPair[] = [];
  private context: common.Context | undefined = undefined;
  private lastRefreshAt: number = 0;
  private refreshInFlight: boolean = false;

  // Reads the bundled fallback once and starts a best-effort refresh. Called
  // from XPrivateClient.load() so every surface that can issue a write has the
  // provider ready before its request is built.
  load(context: common.Context): void {
    this.context = context;
    if (this.bundledPairs.length === 0) {
      this.bundledPairs = XTransactionIdService.readBundledPairs(context);
      if (this.pairs.length === 0) {
        this.pairs = this.bundledPairs;
      }
      if (this.bundledPairs.length > 0) {
        hilog.info(DOMAIN, TAG, 'tid pairs loaded: %{public}d', this.bundledPairs.length);
      }
    }
    this.refresh();
  }

  isConfigured(): boolean {
    return this.pairs.length > 0 || this.bundledPairs.length > 0;
  }

  invalidate(): void {
    this.pairs = [];
    this.bundledPairs = [];
    this.lastRefreshAt = 0;
    const context: common.Context | undefined = this.context;
    if (context !== undefined) {
      this.load(context);
    }
  }

  // Returns an empty string when no usable key material is available. The
  // caller then sends the request without the header, matching the reference
  // client's fallback behaviour.
  async resolve(method: string, path: string): Promise<string> {
    if (this.pairs.length === 0 && this.bundledPairs.length > 0) {
      this.pairs = this.bundledPairs;
    }
    if (this.pairs.length === 0) {
      return '';
    }
    const index: number = Math.floor(Math.random() * this.pairs.length) % this.pairs.length;
    try {
      return await XTransactionIdService.compute(this.pairs[index], method, path);
    } catch (error) {
      hilog.debug(DOMAIN, TAG, 'transaction id compute failed: %{public}s', JSON.stringify(error));
      return '';
    }
  }

  private refresh(): void {
    if (this.refreshInFlight || Date.now() - this.lastRefreshAt < REFRESH_TTL_MS) {
      return;
    }
    this.lastRefreshAt = Date.now();
    this.refreshInFlight = true;
    this.refreshFrom(0);
  }

  private async refreshFrom(index: number): Promise<void> {
    if (index >= PAIR_URLS.length) {
      this.refreshInFlight = false;
      return;
    }
    let httpRequest: http.HttpRequest | undefined = undefined;
    try {
      httpRequest = http.createHttp();
      const options: http.HttpRequestOptions = {
        method: http.RequestMethod.GET,
        header: { 'accept': 'application/json', 'cache-control': 'no-cache' },
        connectTimeout: REQUEST_TIMEOUT_MS,
        readTimeout: REQUEST_TIMEOUT_MS
      };
      await proxyStore.apply(options);
      const response: http.HttpResponse = await httpRequest.request(PAIR_URLS[index], options);
      if (response.responseCode === 200) {
        const text: string = typeof response.result === 'string' ?
          response.result as string : JSON.stringify(response.result);
        const parsed: XTransactionIdPair[] = XTransactionIdService.parsePairs(text);
        if (parsed.length > 0) {
          this.pairs = parsed;
          hilog.info(DOMAIN, TAG, 'transaction id pairs refreshed: %{public}d', parsed.length);
          this.refreshInFlight = false;
          return;
        }
      }
    } catch (error) {
      hilog.debug(DOMAIN, TAG, 'pair refresh failed: %{public}s', JSON.stringify(error));
    } finally {
      if (httpRequest !== undefined) {
        httpRequest.destroy();
      }
    }
    await this.refreshFrom(index + 1);
  }

  private static readBundledPairs(context: common.Context): XTransactionIdPair[] {
    try {
      const bytes: Uint8Array = context.resourceManager.getRawFileContentSync(RAWFILE_NAME);
      const decoder: util.TextDecoder = util.TextDecoder.create('utf-8');
      return XTransactionIdService.parsePairs(decoder.decodeToString(bytes));
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'bundled pair load failed: %{public}s', JSON.stringify(error));
      return [];
    }
  }

  private static parsePairs(text: string): XTransactionIdPair[] {
    const output: XTransactionIdPair[] = [];
    try {
      const root: Object = JSON.parse(text) as Object;
      if (!(root instanceof Array)) {
        return output;
      }
      const rows: Array<Object> = root as Array<Object>;
      for (let index: number = 0; index < rows.length; index++) {
        const row: Record<string, Object> = rows[index] as Record<string, Object>;
        const animationKey: string = String(row['animationKey'] ?? '');
        const verification: string = String(row['verification'] ?? '');
        if (animationKey.length > 0 && verification.length > 0) {
          output.push(new XTransactionIdPair(animationKey, verification));
        }
      }
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'pair parse failed: %{public}s', JSON.stringify(error));
    }
    return output;
  }

  private static async compute(pair: XTransactionIdPair, method: string,
    path: string): Promise<string> {
    const helper: util.Base64Helper = new util.Base64Helper();
    const keyBytes: Uint8Array = helper.decodeSync(pair.verification, util.Type.BASIC);
    const timeNow: number = Math.floor((Date.now() - EPOCH_OFFSET_MS) / 1000);
    const data: string = method + '!' + path + '!' + timeNow.toString() +
      DEFAULT_KEYWORD + pair.animationKey;
    const hash: number[] = sha256Bytes(data);

    const body: number[] = [];
    for (let index: number = 0; index < keyBytes.length; index++) {
      body.push(keyBytes[index] & 0xFF);
    }
    for (let index: number = 0; index < 4; index++) {
      body.push((timeNow >> (index * 8)) & 0xFF);
    }
    for (let index: number = 0; index < 16 && index < hash.length; index++) {
      body.push(hash[index] & 0xFF);
    }
    body.push(ADDITIONAL_RANDOM_NUMBER);

    const random: number = Math.floor(Math.random() * 256) & 0xFF;
    const output: Uint8Array = new Uint8Array(body.length + 1);
    output[0] = random;
    for (let index: number = 0; index < body.length; index++) {
      output[index + 1] = (body[index] ^ random) & 0xFF;
    }
    let encoded: string = helper.encodeToStringSync(output, util.Type.BASIC);
    while (encoded.length > 0 && encoded.charAt(encoded.length - 1) === '=') {
      encoded = encoded.substring(0, encoded.length - 1);
    }
    return encoded;
  }
}

export const xTransactionId: XTransactionIdService = new XTransactionIdService();
