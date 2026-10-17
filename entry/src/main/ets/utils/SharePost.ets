// System share sheet for a single post: the link plus its text, which is what
// other apps can actually consume.
import { common } from '@kit.AbilityKit';
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import hilog from '@ohos.hilog';
import type { Tweet } from '../models/Tweet';

const DOMAIN = 0xFF00;
const TAG = 'HarmonyX-Share';

export function postShareUrl(tweet: Tweet): string {
  return 'https://x.com/' + encodeURIComponent(tweet.author.username) + '/status/' +
    encodeURIComponent(tweet.id);
}

export async function sharePost(context: common.UIAbilityContext, tweet: Tweet): Promise<boolean> {
  const sharedData: systemShare.SharedData = new systemShare.SharedData({
    utd: utd.UniformDataType.HYPERLINK,
    content: postShareUrl(tweet),
    title: tweet.author.name + ' on X',
    description: tweet.text
  });
  const controller: systemShare.ShareController = new systemShare.ShareController(sharedData);
  try {
    await controller.show(context, {
      selectionMode: systemShare.SelectionMode.SINGLE,
      previewMode: systemShare.SharePreviewMode.DEFAULT
    });
    return true;
  } catch (error) {
    hilog.warn(DOMAIN, TAG, 'share failed: %{public}s', JSON.stringify(error));
    return false;
  }
}

export async function shareProfile(context: common.UIAbilityContext, name: string, username: string,
  description: string): Promise<boolean> {
  const data: systemShare.SharedData = new systemShare.SharedData({
    utd: utd.UniformDataType.HYPERLINK, content: 'https://x.com/' + encodeURIComponent(username),
    title: name, description: description
  });
  const controller: systemShare.ShareController = new systemShare.ShareController(data);
  try {
    await controller.show(context, { selectionMode: systemShare.SelectionMode.SINGLE,
      previewMode: systemShare.SharePreviewMode.DEFAULT });
    return true;
  } catch (error) {
    return false;
  }
}

export async function shareList(context: common.UIAbilityContext, listId: string, name: string,
  description: string): Promise<boolean> {
  const data: systemShare.SharedData = new systemShare.SharedData({
    utd: utd.UniformDataType.HYPERLINK, content: 'https://x.com/i/lists/' + encodeURIComponent(listId),
    title: name, description: description
  });
  const controller: systemShare.ShareController = new systemShare.ShareController(data);
  try {
    await controller.show(context, { selectionMode: systemShare.SelectionMode.SINGLE,
      previewMode: systemShare.SharePreviewMode.DEFAULT });
    return true;
  } catch (error) { return false; }
}

export async function shareSpace(context: common.UIAbilityContext, spaceId: string, title: string): Promise<boolean> {
  const data: systemShare.SharedData = new systemShare.SharedData({
    utd: utd.UniformDataType.HYPERLINK, content: 'https://x.com/i/spaces/' + encodeURIComponent(spaceId), title: title
  });
  const controller: systemShare.ShareController = new systemShare.ShareController(data);
  try {
    await controller.show(context, { selectionMode: systemShare.SelectionMode.SINGLE,
      previewMode: systemShare.SharePreviewMode.DEFAULT });
    return true;
  } catch (error) { return false; }
}

export async function shareCommunity(context: common.UIAbilityContext, id: string, name: string,
  description: string): Promise<boolean> {
  const data: systemShare.SharedData = new systemShare.SharedData({
    utd: utd.UniformDataType.HYPERLINK, content: 'https://x.com/i/communities/' + encodeURIComponent(id),
    title: name, description: description
  });
  const controller: systemShare.ShareController = new systemShare.ShareController(data);
  try {
    await controller.show(context, { selectionMode: systemShare.SelectionMode.SINGLE,
      previewMode: systemShare.SharePreviewMode.DEFAULT });
    return true;
  } catch (error) { return false; }
}
