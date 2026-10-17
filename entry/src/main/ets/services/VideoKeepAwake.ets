import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

// Window keep-on is shared: a disappearing/preloaded player cannot release
// another visible player's lease. Writes are serialized across handoffs.
export class VideoKeepAwake {
  private owners: Set<string> = new Set<string>();
  private nextOwner: number = 0;
  private foreground: boolean = true;
  private hostWindow: window.Window | null = null;
  private applying: boolean = false;
  private dirty: boolean = false;

  createOwner(): string { return 'video-keep-awake-' + (++this.nextOwner).toString(); }

  update(owner: string, active: boolean, context: common.UIAbilityContext): void {
    if (active) { this.owners.add(owner); } else { this.owners.delete(owner); }
    this.dirty = true;
    this.apply(context);
  }

  setForeground(foreground: boolean, context: common.UIAbilityContext): void {
    this.foreground = foreground;
    this.dirty = true;
    this.apply(context);
  }

  private async apply(context: common.UIAbilityContext): Promise<void> {
    if (this.applying) { return; }
    this.applying = true;
    try {
      if (this.hostWindow === null) { this.hostWindow = await window.getLastWindow(context); }
      while (this.dirty) {
        this.dirty = false;
        await this.hostWindow.setWindowKeepScreenOn(this.foreground && this.owners.size > 0);
      }
    } catch (error) {
      this.hostWindow = null;
      hilog.warn(0x0000, 'VideoKeepAwake', 'window keep-on update failed');
    } finally { this.applying = false; }
  }
}

export const videoKeepAwake: VideoKeepAwake = new VideoKeepAwake();
