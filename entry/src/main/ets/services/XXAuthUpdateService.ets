import { common } from '@kit.AbilityKit';
import { requestXXAuthPopup } from './XXAuthPopupStore';

// Preserve the earlier entry point while sharing transport and presentation
// with the homepage popup host. Automatic checks remain silent without updates.
export class XXAuthUpdateService {
  async checkAndPrompt(context: common.UIAbilityContext, manual: boolean): Promise<void> {
    requestXXAuthPopup(manual ? 'update' : 'refresh');
  }
}

export const xxAuthUpdateService: XXAuthUpdateService = new XXAuthUpdateService();
