import { UIContext } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';

export async function copyPostLink(context: UIContext, url: string): Promise<void> {
  if (url.length === 0) { return; }
  try {
    await pasteboard.getSystemPasteboard().setData(pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, url));
    context.getPromptAction().showToast({ message: $r('app.string.photo_copied') });
  } catch (error) {
    context.getPromptAction().showToast({ message: $r('app.string.photo_copy_failed') });
  }
}
