import { common } from '@kit.AbilityKit';
import { CrashReport, crashDiagnostics, STORAGE_KEY_CRASH_DIAGNOSTICS } from '../services/CrashDiagnostics';

@Component
export struct CrashRecoveryNotice {
  @Prop @Watch('schedulePrompt') blocked: boolean = true;
  @StorageProp(STORAGE_KEY_CRASH_DIAGNOSTICS) @Watch('schedulePrompt') private revision: number = 0;
  @StorageProp('harmonyx.app_foreground') @Watch('schedulePrompt') private foreground: boolean = true;
  onOpenDiagnostics: () => void = (): void => {};
  private alive: boolean = false;
  private timer: number = -1;

  aboutToDisappear(): void {
    this.alive = false;
    if (this.timer >= 0) { clearTimeout(this.timer); this.timer = -1; }
  }

  private schedulePrompt(): void {
    if (!this.alive || this.blocked || !this.foreground || this.timer >= 0) { return; }
    this.timer = setTimeout((): void => {
      this.timer = -1;
      this.showPrompt();
    }, 300);
  }

  private async showPrompt(): Promise<void> {
    if (!this.alive || this.blocked || !this.foreground) { return; }
    const report: CrashReport | undefined = crashDiagnostics.pendingReport();
    if (!report || !crashDiagnostics.claimPrompt(report.id)) { return; }
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const prompt = this.getUIContext().getPromptAction();
    try {
      const result = await prompt.showDialog({
        title: context.resourceManager.getStringSync($r('app.string.crash_recovery_title')),
        message: context.resourceManager.getStringSync($r('app.string.crash_recovery_message')),
        buttons: [
          { text: context.resourceManager.getStringSync($r('app.string.crash_later')), color: $r('app.color.text_secondary') },
          { text: context.resourceManager.getStringSync($r('app.string.crash_export')), color: $r('app.color.text_accent'), primary: true },
          { text: context.resourceManager.getStringSync($r('app.string.crash_contact')), color: $r('app.color.text_accent') }
        ]
      });
      if (!this.alive) { return; }
      if (result.index === 0) {
        for (const saved of crashDiagnostics.snapshot()) { crashDiagnostics.acknowledge(saved.id); }
        return;
      }
      this.onOpenDiagnostics();
      if (result.index === 1) {
        try {
          if (await crashDiagnostics.exportLogs(context)) {
            prompt.showToast({ message: context.resourceManager.getStringSync($r('app.string.crash_export_success')) });
          }
        } catch (error) {
          prompt.showToast({ message: context.resourceManager.getStringSync($r('app.string.crash_export_failed')) });
        }
      } else if (result.index === 2) {
        try {
          await crashDiagnostics.contactDeveloper(context);
          for (const saved of crashDiagnostics.snapshot()) { crashDiagnostics.acknowledge(saved.id); }
        } catch (error) {
          prompt.showToast({ message: context.resourceManager.getStringSync($r('app.string.crash_contact_failed')) });
        }
      }
    } catch (error) { /* Dismissal keeps the report available on the next launch. */ }
  }

  build(): void {
    Column() {}
      .width(0).height(0)
      .accessibilityLevel('no')
      .onAppear((): void => { this.alive = true; this.schedulePrompt(); })
  }
}
