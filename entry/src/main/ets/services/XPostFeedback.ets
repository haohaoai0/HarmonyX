import { common } from '@kit.AbilityKit';
import { XPostReceipt } from './XPostResponse';

// Shared by the main composer and reply editor. Keep server errors visible in
// the editor; do not expose request headers, cookies, or the full response.
export class XPostFeedback {
  static failure(context: common.Context, status: number, receipt: XPostReceipt): string {
    const resource: Resource = receipt.unconfirmed ? $r('app.string.post_send_unconfirmed') :
      $r('app.string.post_send_failed');
    let message: string = context.resourceManager.getStringSync(resource);
    if (status > 0) {
      message += '\nHTTP ' + status;
    }
    if (receipt.errorCode.length > 0) {
      message += ' · ' + receipt.errorCode;
    }
    if (receipt.errorText.length > 0) {
      message += '\n' + receipt.errorText;
    }
    return message;
  }
}
