// HTTP byte ranges are inclusive. Keep parsing and validation independent of
// sockets so malformed/ignored ranges can never become valid cached video.
export const VIDEO_RANGE_CHUNK_BYTES: number = 256 * 1024;
export const VIDEO_RANGE_START_BYTES: number = 64 * 1024;

export class VideoByteRange {
  start: number;
  end: number;
  partial: boolean;
  constructor(start: number, end: number, partial: boolean = true) {
    this.start = start;
    this.end = end;
    this.partial = partial;
  }
}

export class VideoRemoteRange {
  start: number = 0;
  end: number = 0;
  total: number = 0;
}

export function videoRequestRange(request: string, total: number): VideoByteRange | null {
  if (!Number.isSafeInteger(total) || total <= 0) { return null; }
  const match: RegExpMatchArray | null = request.match(/\r\nrange:\s*bytes=([^\r\n]*)/i);
  if (match === null) {
    if (/\r\nrange:/i.test(request)) { return null; }
    return new VideoByteRange(0, total - 1, false);
  }
  const spec: RegExpMatchArray | null = match[1].trim().match(/^(\d*)-(\d*)$/);
  if (spec === null || (spec[1].length === 0 && spec[2].length === 0)) { return null; }
  let start: number = 0;
  let end: number = total - 1;
  if (spec[1].length === 0) {
    const suffix: number = Number(spec[2]);
    if (!Number.isSafeInteger(suffix) || suffix <= 0) { return null; }
    start = Math.max(0, total - suffix);
  } else {
    start = Number(spec[1]);
    if (spec[2].length > 0) { end = Number(spec[2]); }
  }
  if (!Number.isSafeInteger(start) || !Number.isSafeInteger(end) || start < 0 || start >= total || end < start) {
    return null;
  }
  return new VideoByteRange(start, Math.min(end, total - 1));
}

export function videoHeader(headerText: string, name: string): string {
  const headers: Record<string, Object> = JSON.parse(headerText) as Record<string, Object>;
  // HTTP libraries normalize names differently. Record is the supported
  // ArkTS dictionary type; ordinary objects are never indexed dynamically.
  const keys: string[] = Object.keys(headers);
  for (let i: number = 0; i < keys.length; i++) {
    if (keys[i].toLowerCase() === name.toLowerCase()) {
      const value: Object | undefined = headers[keys[i]];
      return value === undefined ? '' : String(value);
    }
  }
  return '';
}

export function videoResponseRange(headerText: string): VideoRemoteRange | null {
  const match: RegExpMatchArray | null = videoHeader(headerText, 'content-range')
    .match(/^bytes\s+(\d+)-(\d+)\/(\d+)$/i);
  if (match === null) { return null; }
  const range: VideoRemoteRange = new VideoRemoteRange();
  range.start = Number(match[1]); range.end = Number(match[2]); range.total = Number(match[3]);
  if (!Number.isSafeInteger(range.start) || !Number.isSafeInteger(range.end) ||
    !Number.isSafeInteger(range.total) || range.start < 0 || range.end < range.start || range.end >= range.total) {
    return null;
  }
  return range;
}

export function videoResponseStatus(headerText: string): number {
  const match: RegExpMatchArray | null = videoHeader(headerText, 'status-line').trim()
    .match(/^HTTP\/[0-9.]+\s+(\d{3})(?:\s|$)/i);
  return match === null ? 0 : Number(match[1]);
}

export function videoRangeKey(mediaId: string, rendition: string, url: string): string {
  // Signed query tokens may rotate while the rendition's bytes remain valid.
  const path: string = url.split('?')[0];
  const value: string = mediaId + ':' + rendition + ':' + path;
  let first: number = 0x811c9dc5;
  let second: number = 5381;
  for (let i: number = 0; i < value.length; i++) {
    first = Math.imul(first ^ value.charCodeAt(i), 0x01000193) >>> 0;
    second = (Math.imul(second, 33) ^ value.charCodeAt(i)) >>> 0;
  }
  return first.toString(16) + '-' + second.toString(16);
}
