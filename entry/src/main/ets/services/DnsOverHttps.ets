import url from '@ohos.url';

export const DOH_ALIDNS: string = 'https://dns.alidns.com/dns-query';
export const DOH_CLOUDFLARE: string = 'https://cloudflare-dns.com/dns-query';
export const DOH_GOOGLE: string = 'https://dns.google/dns-query';

// Accept RFC 8484 endpoints, including private endpoints with query tokens.
// URI templates, credentials and fragments are not request endpoints.
export function normalizeDohEndpoint(input: string): string {
  const value: string = input.trim();
  if (value.length === 0 || value.length > 2048 || /[\s\\{}#]/.test(value) ||
    !/^https:\/\//i.test(value) || /^https:\/\/[^/]*@/i.test(value)) {
    return '';
  }
  try {
    const parsed: url.URL = new url.URL(value);
    const port: number = parsed.port.length > 0 ? Number(parsed.port) : 443;
    if (parsed.protocol !== 'https:' || parsed.hostname.length === 0 ||
      parsed.username.length > 0 || parsed.password.length > 0 ||
      !Number.isInteger(port) || port < 1 || port > 65535) {
      return '';
    }
    return parsed.href;
  } catch (error) {
    return '';
  }
}

// A real RFC 8484 A query for x.com, without cookies or account information.
export function dohProbeQuery(): Uint8Array {
  return new Uint8Array([0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0,
    1, 120, 3, 99, 111, 109, 0, 0, 1, 0, 1]);
}

function dnsWord(bytes: Uint8Array, offset: number): number {
  return bytes[offset] * 256 + bytes[offset + 1];
}

function skipDnsName(bytes: Uint8Array, start: number): number {
  let offset: number = start;
  while (offset < bytes.length) {
    const length: number = bytes[offset];
    if (length === 0) { return offset + 1; }
    if ((length & 0xC0) === 0xC0) {
      if (offset + 1 >= bytes.length || (dnsWord(bytes, offset) & 0x3FFF) >= bytes.length) {
        return -1;
      }
      return offset + 2;
    }
    if (length > 63 || offset + length + 1 >= bytes.length) { return -1; }
    offset += length + 1;
  }
  return -1;
}

export function dohProbeAnswerCount(buffer: ArrayBuffer): number {
  const bytes: Uint8Array = new Uint8Array(buffer);
  const query: Uint8Array = dohProbeQuery();
  if (bytes.length < query.length || dnsWord(bytes, 0) !== 0 ||
    (bytes[2] & 0xFA) !== 0x80 || (bytes[3] & 0x0F) !== 0 || dnsWord(bytes, 4) !== 1) {
    return 0;
  }
  for (let i: number = 12; i < query.length; i++) {
    if (bytes[i] !== query[i]) { return 0; }
  }
  let offset: number = query.length;
  let addresses: number = 0;
  const answers: number = dnsWord(bytes, 6);
  for (let i: number = 0; i < answers; i++) {
    offset = skipDnsName(bytes, offset);
    if (offset < 0 || offset + 10 > bytes.length) { return 0; }
    const type: number = dnsWord(bytes, offset);
    const recordClass: number = dnsWord(bytes, offset + 2);
    const length: number = dnsWord(bytes, offset + 8);
    offset += 10;
    if (offset + length > bytes.length) { return 0; }
    if (recordClass === 1 && type === 1 && length === 4) { addresses++; }
    offset += length;
  }
  return addresses;
}
