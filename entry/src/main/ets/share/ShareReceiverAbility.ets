// Share panel entry point. The system lists the apps whose declared UTD covers
// what is being shared and starts this ShareExtensionAbility when the user
// picks Harmony X. Links open their destination; gallery media enters an editor.
import { ShareExtensionAbility, UIExtensionContentSession, Want } from '@kit.AbilityKit';
import { systemShare } from '@kit.ShareKit';
import hilog from '@ohos.hilog';
import { firstXLink } from '../utils/XLinkRouter';
import { externalShareStore, ExternalSharePayload } from '../services/ExternalShareStore';
import promptAction from '@ohos.promptAction';

const DOMAIN = 0xFF00;
const TAG = 'HarmonyX-ShareReceiver';
const ENTRY_ABILITY_NAME: string = 'EntryAbility';

export default class ShareReceiverAbility extends ShareExtensionAbility {
  onSessionCreate(want: Want, session: UIExtensionContentSession): void {
    this.handOff(want, session);
  }

  // The share detail page is only a doorway. A link belongs in the app's own
  // surfaces, so the entry ability is started with it and the panel closes.
  private async handOff(want: Want, session: UIExtensionContentSession): Promise<void> {
    let payload: ExternalSharePayload | null = null;
    try {
      const data: systemShare.SharedData = await systemShare.getSharedData(want);
      const records: systemShare.SharedRecord[] = data.getRecords();
      const hasFiles: boolean = records.some((record: systemShare.SharedRecord): boolean => (record.uri ?? '').length > 0);
      const link: string = hasFiles ? '' : firstXLink(records.map((record: systemShare.SharedRecord): string => record.content ?? '').join('\n'));
      if (link.length > 0) {
        await this.openInApp(link);
      } else {
        payload = await externalShareStore.stage(this.context, records);
        await this.context.startAbility({ bundleName: this.context.applicationInfo.name,
          abilityName: ENTRY_ABILITY_NAME, parameters: { externalShareId: payload.id } });
      }
    } catch (error) {
      if (payload !== null) { externalShareStore.discard(this.context, payload.id); }
      hilog.warn(DOMAIN, TAG, '%{public}s', 'Unable to receive shared media');
      promptAction.showToast({ message: this.context.resourceManager.getStringSync($r('app.string.share_receive_failed')) });
    } finally {
      try { await session.terminateSelf(); }
      catch (error) { hilog.warn(DOMAIN, TAG, '%{public}s', 'Unable to close the share panel session'); }
    }
  }

  private async openInApp(link: string): Promise<void> {
    const want: Want = {
      bundleName: this.context.applicationInfo.name,
      abilityName: ENTRY_ABILITY_NAME,
      uri: link,
      action: 'ohos.want.action.viewData',
      entities: ['entity.system.browsable']
    };
    await this.context.startAbility(want);
  }

}
