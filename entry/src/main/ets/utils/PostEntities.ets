// Side effects for the tappable parts of a post body.
import common from '@ohos.app.ability.common';
import { Want } from '@kit.AbilityKit';
import hilog from '@ohos.hilog';
import { LinkSettingsStore, STORAGE_KEY_LINK_IN_APP } from '../services/LinkSettingsStore';

const DOMAIN = 0xFF00;
const TAG = 'HarmonyX-Entity';

// Index owns the explore tab, so a hashtag only publishes the query here and
// the tab picks it up and runs the search.
export const SEARCH_REQUEST_KEY: string = 'harmonyx.search_request';

export function requestSearch(query: string): void {
  if (query.length === 0) {
    return;
  }
  AppStorage.setOrCreate<string>(SEARCH_REQUEST_KEY, query);
}

// Post bodies already use the destination supplied by X's URL entities.
// Missing expansions still fall back to opening the original short link.
export function openExternalLink(context: common.UIAbilityContext, url: string): void {
  if (url.length === 0) {
    return;
  }
  // The in-app option hands the URL to the root page's half-modal sheet.
  const inApp: boolean = AppStorage.get<boolean>(STORAGE_KEY_LINK_IN_APP) ?? false;
  if (inApp) {
    LinkSettingsStore.requestPreview(url);
    return;
  }
  const want: Want = {
    action: 'ohos.want.action.viewData',
    entities: ['entity.system.browsable'],
    uri: url
  };
  context.startAbility(want).catch((error: Object): void => {
    hilog.warn(DOMAIN, TAG, 'open link failed: %{public}s', JSON.stringify(error));
  });
}
