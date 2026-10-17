import { common } from '@kit.AbilityKit';
import { classifyXLink, STORAGE_KEY_EXTERNAL_LINK, X_LINK_OTHER } from './XLinkRouter';
import { openExternalLink } from './PostEntities';

export function openPostCardUrl(context: common.UIAbilityContext, link: string): void {
  if (!/^https?:\/\/[^\s]+$/i.test(link)) { return; }
  const target = classifyXLink(link);
  if (target !== null && target.kind !== X_LINK_OTHER) {
    AppStorage.setOrCreate(STORAGE_KEY_EXTERNAL_LINK, link);
  } else { openExternalLink(context, link); }
}
