import { common } from '@kit.AbilityKit';
import { UIContext } from '@kit.ArkUI';
import promptAction from '@ohos.promptAction';
import type { MediaAttachment, VideoRendition } from '../models/Tweet';

export interface VideoDownloadChoice {
  url: string;
  label: Resource;
  width: number;
  height: number;
}

function downloadableVideoUrl(url: string): boolean {
  const lower: string = url.toLowerCase();
  return url.length > 0 && lower.indexOf('.m3u8') < 0 && lower.indexOf('mpegurl') < 0;
}

function renditionFromUrl(url: string): VideoRendition {
  const dimensions: RegExpMatchArray | null = url.match(/\/(\d+)x(\d+)\//);
  return {
    url: url,
    bitrate: 0,
    width: dimensions === null ? 0 : Number(dimensions[1]),
    height: dimensions === null ? 0 : Number(dimensions[2])
  };
}

// Use only files advertised by the post. HLS playlists are playback sources,
// and cannot be saved as MP4 files by the download manager.
export function videoDownloadChoices(media: MediaAttachment): VideoDownloadChoice[] {
  const renditions: VideoRendition[] = [];
  const variants: VideoRendition[] = media.videoVariants ?? [];
  for (let index: number = 0; index < variants.length; index++) {
    const variant: VideoRendition = variants[index];
    if (downloadableVideoUrl(variant.url) &&
      !renditions.some((item: VideoRendition): boolean => item.url === variant.url)) {
      renditions.push(variant);
    }
  }
  if (renditions.length === 0) {
    const urls: string[] = media.videoVariantUrls ?? [];
    for (let index: number = 0; index < urls.length; index++) {
      if (downloadableVideoUrl(urls[index]) &&
        !renditions.some((item: VideoRendition): boolean => item.url === urls[index])) {
        renditions.push(renditionFromUrl(urls[index]));
      }
    }
    const fallbackUrls: string[] = [media.feedUrl, media.mediaUrl];
    for (let index: number = 0; index < fallbackUrls.length; index++) {
      const url: string = fallbackUrls[index];
      if (downloadableVideoUrl(url) &&
        !renditions.some((item: VideoRendition): boolean => item.url === url)) {
        renditions.push(renditionFromUrl(url));
      }
    }
  }
  if (renditions.length === 0) {
    return [];
  }
  renditions.sort((left: VideoRendition, right: VideoRendition): number => {
    if (left.bitrate > 0 && right.bitrate > 0) {
      return left.bitrate - right.bitrate;
    }
    return left.width * left.height - right.width * right.height;
  });
  const low: VideoRendition = renditions[0];
  const high: VideoRendition = renditions[renditions.length - 1];
  let standard: VideoRendition = low;
  const hasBitrates: boolean = renditions.every((item: VideoRendition): boolean => item.bitrate > 0);
  if (hasBitrates) {
    // Match the existing SD playback tier: highest available bitrate <= 1.8 Mbps.
    for (let index: number = 0; index < renditions.length; index++) {
      if (renditions[index].bitrate <= 1800000) {
        standard = renditions[index];
      }
    }
  } else {
    standard = renditions[Math.floor((renditions.length - 1) / 2)];
  }
  return [
    { url: high.url, label: $r('app.string.media_download_quality_hd'), width: high.width, height: high.height },
    { url: standard.url, label: $r('app.string.media_download_quality_sd'), width: standard.width, height: standard.height },
    { url: low.url, label: $r('app.string.media_download_quality_ld'), width: low.width, height: low.height }
  ];
}

export async function chooseVideoDownloadUrl(uiContext: UIContext, media: MediaAttachment): Promise<string> {
  const choices: VideoDownloadChoice[] = videoDownloadChoices(media);
  if (choices.length === 0) {
    return '';
  }
  const context: common.UIAbilityContext = uiContext.getHostContext() as common.UIAbilityContext;
  const buttons: promptAction.Button[] = choices.map((choice: VideoDownloadChoice): promptAction.Button => {
    let label: string = context.resourceManager.getStringSync(choice.label);
    if (choice.width > 0 && choice.height > 0) {
      label += ' · ' + Math.min(choice.width, choice.height).toString() + 'p';
    }
    return { text: label, color: $r('app.color.text_primary') };
  });
  try {
    const options: promptAction.ActionMenuOptions = {
      title: context.resourceManager.getStringSync($r('app.string.media_download_quality_title')),
      buttons: [buttons[0], buttons[1], buttons[2]]
    };
    const result: promptAction.ActionMenuSuccessResponse = await uiContext.getPromptAction().showActionMenu(options);
    return result.index >= 0 && result.index < choices.length ? choices[result.index].url : '';
  } catch (error) {
    // Dismissing the menu never starts a download.
    return '';
  }
}
