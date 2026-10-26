// Process-local state: background resumes and login must not replay startup.
export const STARTUP_BRAND_DURATION: number = 420;
// Supplied clips are 2500 ms. Decoder setup has a bounded 1500 ms allowance.
export const STARTUP_VIDEO_TIMEOUT: number = 4000;
export function startupVideoTimeout(speed: number): number {
  const rate: number = Number.isFinite(speed) && speed >= 0.5 && speed <= 2 ? speed : 1;
  return Math.ceil(2500 / rate) + 1500;
}
export const STARTUP_EXIT_DURATION: number = 180;
export const STARTUP_COVER_TIMEOUT: number = 1500;
// A slow/offline feed must eventually reveal its ordinary loading/error UI.
export const STARTUP_NATIVE_TIMEOUT: number = 2200;
export const STARTUP_IOS_ANTICIPATION: number = 120;
export const STARTUP_IOS_EXIT_DURATION: number = 360;
export const STARTUP_IOS_ZOOM_SCALE: number = 28;

export class StartupSession {
  private pending: boolean = false;
  begin(): void { this.pending = true; }
  claimCover(): boolean {
    const claimed: boolean = this.pending;
    this.pending = false;
    return claimed;
  }
  cancel(): void { this.pending = false; }
}

export const startupSession: StartupSession = new StartupSession();
