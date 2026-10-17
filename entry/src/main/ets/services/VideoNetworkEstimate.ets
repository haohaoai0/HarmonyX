// Network capability bandwidth is often the radio/link maximum, not the
// throughput to the video CDN. Use recent foreground transfers for Auto.
const SAMPLE_MAX_AGE_MS: number = 45000;
const MIN_SAMPLE_BYTES: number = 128 * 1024;

class VideoNetworkSample {
  bitrate: number;
  at: number;
  constructor(bitrate: number, at: number) { this.bitrate = bitrate; this.at = at; }
}

export class VideoNetworkEstimate {
  private samples: Map<string, VideoNetworkSample> = new Map<string, VideoNetworkSample>();
  record(url: string, bytes: number, elapsedMs: number, foreground: boolean, now: number = Date.now()): void {
    if (!foreground || bytes < MIN_SAMPLE_BYTES || elapsedMs <= 0 ||
      !Number.isFinite(bytes) || !Number.isFinite(elapsedMs)) { return; }
    const key: string = this.origin(url);
    if (key.length === 0) { return; }
    const measured: number = bytes * 8000 / elapsedMs;
    const previous: VideoNetworkSample | undefined = this.samples.get(key);
    let bitrate: number = measured;
    if (previous !== undefined && now - previous.at <= SAMPLE_MAX_AGE_MS && now >= previous.at) {
      // React quickly to a slowdown. Raise quality only after multiple good
      // samples, avoiding oscillation between heavy and light renditions.
      const weight: number = measured < previous.bitrate ? 0.75 : 0.2;
      bitrate = previous.bitrate * (1 - weight) + measured * weight;
    }
    if (previous === undefined && this.samples.size >= 8) {
      for (const oldKey of this.samples.keys()) { this.samples.delete(oldKey); break; }
    }
    this.samples.set(key, new VideoNetworkSample(bitrate, now));
  }
  bitrateCap(url: string, configuredCap: number, now: number = Date.now()): number {
    const sample: VideoNetworkSample | undefined = this.samples.get(this.origin(url));
    if (sample === undefined || now < sample.at || now - sample.at > SAMPLE_MAX_AGE_MS) { return configuredCap; }
    return Math.min(configuredCap, Math.max(200000, Math.floor(sample.bitrate * 0.7)));
  }
  private origin(url: string): string {
    const match: RegExpMatchArray | null = url.match(/^https?:\/\/[^/]+/i);
    return match === null ? '' : match[0].toLowerCase();
  }
}

export const videoNetworkEstimate: VideoNetworkEstimate = new VideoNetworkEstimate();
