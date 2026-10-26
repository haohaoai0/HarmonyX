import type { MediaAttachment } from '../models/Tweet';
import { normalizedPostMediaType } from './PostGif';

// Feed cards and detail heroes share the same attachment order. A still image
// beside a video must not switch the whole post back to a vertical column.
export function postUsesHorizontalMediaStrip(attachments: MediaAttachment[], viewer: boolean): boolean {
  return !viewer && attachments.length > 1 && attachments.some((media: MediaAttachment): boolean =>
    normalizedPostMediaType(media.type) === 'video' || normalizedPostMediaType(media.type) === 'animated_gif');
}
