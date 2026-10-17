import { DmAttachment } from '../models/Tweet';

export interface ChatMediaItem {
  attachment: DmAttachment;
  video?: DmAttachment;
}

// The filename is part of the signed, encrypted XChat media descriptor.
// Both resources stay ordinary image/video attachments for other clients.
export class ChatMovingPhotoProtocol {
  static imageName(id: string): string { return 'HXMP_v1_' + id + '_image.jpg'; }
  static videoName(id: string): string { return 'HXMP_v1_' + id + '_video.mp4'; }

  private static pairId(attachment: DmAttachment): string {
    if (attachment.type !== 'Media' || attachment.mediaHash.length === 0) { return ''; }
    const match: RegExpMatchArray | null = attachment.filename.match(
      /^HXMP_v1_([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})_(image\.jpg|video\.mp4)$/);
    if (match === null || (match[2] === 'image.jpg' ? attachment.mediaType !== 1 : attachment.mediaType !== 3)) { return ''; }
    return match[1];
  }

  static group(attachments: DmAttachment[]): ChatMediaItem[] {
    const result: ChatMediaItem[] = [];
    const consumed: number[] = [];
    for (let i: number = 0; i < attachments.length; i++) {
      if (consumed.indexOf(i) >= 0) { continue; }
      const current: DmAttachment = attachments[i];
      const id: string = ChatMovingPhotoProtocol.pairId(current);
      const matches: number[] = [];
      if (id.length > 0) {
        for (let j: number = 0; j < attachments.length; j++) {
          if (ChatMovingPhotoProtocol.pairId(attachments[j]) === id) { matches.push(j); }
        }
      }
      if (matches.length === 2) {
        const first: DmAttachment = attachments[matches[0]];
        const second: DmAttachment = attachments[matches[1]];
        if (first.mediaType !== second.mediaType && first.mediaHash !== second.mediaHash) {
          result.push({ attachment: first.mediaType === 1 ? first : second,
            video: first.mediaType === 3 ? first : second });
          consumed.push(matches[0], matches[1]);
          continue;
        }
      }
      result.push({ attachment: current });
    }
    return result;
  }
}
