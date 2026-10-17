import type { TweetLinkCard } from '../models/Tweet';
import { PostCardPart, PostCardSlide } from '../models/PostContent';

export class WebsiteCardPresentation {
  media: PostCardPart = new PostCardPart();
  title: string = '';
  domain: string = '';
  url: string = '';
  aspectRatio: number = 2;
}

function websiteDomain(value: string): string {
  const host: string = value.trim().replace(/^https?:\/\//i, '').split(/[/?#]/)[0].replace(/^www\./i, '');
  return /^[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?\.[a-z]{2,}(?::\d+)?$/i.test(host) ? host : '';
}

// Only combine a cover and ordinary website details when they share a target.
// App/product/action cards and carousel pages with separate links keep their
// full component layout rather than losing information or changing a tap.
export function websiteCardPresentation(card: TweetLinkCard, slide: PostCardSlide): WebsiteCardPresentation | undefined {
  if (card.content?.compact === true || slide.parts.length === 0 || slide.parts.length > 2) { return undefined; }
  let cover: PostCardPart | undefined = undefined;
  let details: PostCardPart | undefined = undefined;
  let url: string = '';
  for (let i: number = 0; i < slide.parts.length; i++) {
    const part: PostCardPart = slide.parts[i];
    if (['media', 'details', 'link'].indexOf(part.kind) < 0 || part.actions.length > 0 ||
      part.people.length > 0 || part.memberCount >= 0 || part.startsAt > 0 || part.iconUrl.length > 0 ||
      part.price.length > 0 || part.salePrice.length > 0 || part.platform.length > 0) { return undefined; }
    if (part.url.length > 0) {
      if (url.length > 0 && part.url !== url) { return undefined; }
      url = part.url;
    }
    if (part.media.length > 1) { return undefined; }
    if (part.media.length === 1 || part.imageUrl.length > 0) {
      if (cover !== undefined) { return undefined; }
      cover = part;
    } else {
      if (details !== undefined) { return undefined; }
      details = part;
    }
  }
  if (cover === undefined || cover.media[0]?.sensitive === true || !/^https?:\/\//i.test(url)) { return undefined; }
  const presentation: WebsiteCardPresentation = new WebsiteCardPresentation();
  presentation.media = cover; presentation.url = url;
  presentation.title = details?.title || cover.title;
  if (presentation.title.length === 0 && card.content?.slides.length === 1) { presentation.title = card.title; }
  if (presentation.title.replace(/[\s\u200B-\u200F\u2060\uFEFF]/g, '').length === 0) { presentation.title = ''; }
  presentation.domain = websiteDomain(details?.subtitle || cover.subtitle) || websiteDomain(url);
  const width: number = cover.media[0]?.width ?? cover.imageWidth;
  const height: number = cover.media[0]?.height ?? cover.imageHeight;
  if (isFinite(width) && isFinite(height) && width > 0 && height > 0) { presentation.aspectRatio = width / height; }
  else if (cover.media[0]?.type === 'video' || cover.media[0]?.type === 'animated_gif') { presentation.aspectRatio = 16 / 9; }
  return presentation;
}
