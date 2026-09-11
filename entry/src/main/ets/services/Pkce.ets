// PKCE helpers for X OAuth 2.0 (Authorization Code Flow with S256).
// Pure ArkTS — no native dependencies, works on any HarmonyOS device.

const B64URL = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';

function rightRotate(v: number, n: number): number {
  return ((v >>> n) | (v << (32 - n))) >>> 0;
}

// Minimal SHA-256 over an ASCII string, returns 32 bytes.
function sha256Bytes(ascii: string): number[] {
  const bytes: number[] = [];
  for (let i = 0; i < ascii.length; i++) {
    bytes.push(ascii.charCodeAt(i) & 0xFF);
  }
  const bitLen: number = bytes.length * 8;
  bytes.push(0x80);
  while (bytes.length % 64 !== 56) {
    bytes.push(0);
  }
  const hi: number = Math.floor(bitLen / 0x100000000);
  const lo: number = bitLen >>> 0;
  bytes.push((hi >>> 24) & 0xFF, (hi >>> 16) & 0xFF, (hi >>> 8) & 0xFF, hi & 0xFF);
  bytes.push((lo >>> 24) & 0xFF, (lo >>> 16) & 0xFF, (lo >>> 8) & 0xFF, lo & 0xFF);

  let h0 = 0x6a09e667, h1 = 0xbb67ae85, h2 = 0x3c6ef372, h3 = 0xa54ff53a;
  let h4 = 0x510e527f, h5 = 0x9b05688c, h6 = 0x1f83d9ab, h7 = 0x5be0cd19;
  const K: number[] = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
  ];

  for (let off = 0; off < bytes.length; off += 64) {
    const w: number[] = [];
    for (let i = 0; i < 16; i++) {
      const j: number = off + i * 4;
      w.push((((bytes[j] << 24) | (bytes[j + 1] << 16) | (bytes[j + 2] << 8) | bytes[j + 3]) >>> 0));
    }
    for (let i = 16; i < 64; i++) {
      const s0: number = (rightRotate(w[i - 15], 7) ^ rightRotate(w[i - 15], 18) ^ (w[i - 15] >>> 3)) >>> 0;
      const s1: number = (rightRotate(w[i - 2], 17) ^ rightRotate(w[i - 2], 19) ^ (w[i - 2] >>> 10)) >>> 0;
      w.push(((w[i - 16] + s0 + w[i - 7] + s1) >>> 0));
    }
    let a = h0, b = h1, c = h2, d = h3, e = h4, f = h5, g = h6, h = h7;
    for (let i = 0; i < 64; i++) {
      const S1: number = (rightRotate(e, 6) ^ rightRotate(e, 11) ^ rightRotate(e, 25)) >>> 0;
      const ch: number = ((e & f) ^ ((~e) & g)) >>> 0;
      const t1: number = (((h + S1 + ch + K[i] + w[i]) >>> 0));
      const S0: number = (rightRotate(a, 2) ^ rightRotate(a, 13) ^ rightRotate(a, 22)) >>> 0;
      const maj: number = ((a & b) ^ (a & c) ^ (b & c)) >>> 0;
      const t2: number = ((S0 + maj) >>> 0);
      h = g; g = f; f = e; e = ((d + t1) >>> 0);
      d = c; c = b; b = a; a = ((t1 + t2) >>> 0);
    }
    h0 = ((h0 + a) >>> 0); h1 = ((h1 + b) >>> 0); h2 = ((h2 + c) >>> 0); h3 = ((h3 + d) >>> 0);
    h4 = ((h4 + e) >>> 0); h5 = ((h5 + f) >>> 0); h6 = ((h6 + g) >>> 0); h7 = ((h7 + h) >>> 0);
  }
  const out: number[] = [];
  const hs: number[] = [h0, h1, h2, h3, h4, h5, h6, h7];
  for (let i = 0; i < hs.length; i++) {
    out.push((hs[i] >>> 24) & 0xFF, (hs[i] >>> 16) & 0xFF, (hs[i] >>> 8) & 0xFF, hs[i] & 0xFF);
  }
  return out;
}

export function base64UrlEncode(data: number[]): string {
  let out = '';
  let i = 0;
  while (i < data.length) {
    const b0: number = data[i];
    const b1: number = i + 1 < data.length ? data[i + 1] : 0;
    const b2: number = i + 2 < data.length ? data[i + 2] : 0;
    const n: number = (b0 << 16) | (b1 << 8) | b2;
    out += B64URL.charAt((n >>> 18) & 0x3F);
    out += B64URL.charAt((n >>> 12) & 0x3F);
    if (i + 1 < data.length) {
      out += B64URL.charAt((n >>> 6) & 0x3F);
    }
    if (i + 2 < data.length) {
      out += B64URL.charAt(n & 0x3F);
    }
    i += 3;
  }
  return out;
}

export class Pkce {
  // RFC 7636 code_verifier: 43-128 chars from [A-Z a-z 0-9 - . _ ~]
  static newVerifier(): string {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    let v = '';
    for (let i = 0; i < 64; i++) {
      v += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return v;
  }

  static challengeS256(verifier: string): string {
    return base64UrlEncode(sha256Bytes(verifier));
  }

  static newState(): string {
    let s = '';
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    for (let i = 0; i < 16; i++) {
      s += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return s;
  }
}
