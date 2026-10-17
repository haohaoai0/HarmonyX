import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';

let privacyQueue: Promise<void> = Promise.resolve();

// Serialize the conversation and its media viewer so a delayed hide cannot clear the next page's flag.
export function setChatWindowPrivacy(context: common.UIAbilityContext, enabled: boolean): void {
  privacyQueue = privacyQueue.then(async (): Promise<void> => {
    const win: window.Window = await window.getLastWindow(context);
    await win.setWindowPrivacyMode(enabled);
  }).catch((): void => {});
}
