// X's animated_gif may contain MP4 renditions. Its transport does not change
// the media kind or make it a normal video with controls and a resume position.
export function normalizedPostMediaType(declared: string, schemaType: string = '',
  hasVideo: boolean = false): string {
  const type: string = declared.toLowerCase();
  const schema: string = schemaType.toLowerCase();
  if (type === 'animated_gif' || type === 'gif' || schema.indexOf('gif') >= 0) {
    return 'animated_gif';
  }
  if (type.length > 0) {
    return type;
  }
  return schema.indexOf('video') >= 0 || hasVideo ? 'video' : 'photo';
}

export function postGifHeight(sourceWidth: number, sourceHeight: number, availableWidth: number,
  windowHeight: number): number {
  const width: number = Math.max(1, availableWidth);
  const ratio: number = sourceWidth > 0 && sourceHeight > 0 ? sourceHeight / sourceWidth : 1;
  const maxHeight: number = windowHeight > 0 ? Math.min(320, windowHeight * 0.4) : 320;
  return Math.max(1, Math.min(width * ratio, width * 4 / 3, maxHeight));
}
