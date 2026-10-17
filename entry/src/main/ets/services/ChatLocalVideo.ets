import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { media } from '@kit.MediaKit';

export interface ChatVideoPreview { frame: image.PixelMap; width: number; height: number; durationMs: number; }

export async function chatVideoPreview(path: string): Promise<ChatVideoPreview> {
  const file: fileIo.File = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
  let extractor: media.AVMetadataExtractor | null = null;
  let frame: image.PixelMap | null = null;
  try {
    extractor = await media.createAVMetadataExtractor();
    extractor.fdSrc = { fd: file.fd, offset: 0, length: fileIo.statSync(file.fd).size };
    const metadata: media.AVMetadata = await extractor.fetchMetadata();
    const width: number = Number(metadata.videoWidth ?? '0');
    const height: number = Number(metadata.videoHeight ?? '0');
    const params: media.PixelMapParams = width > 0 && height > 0 ?
      { width: Math.min(480, width), height: Math.max(1, Math.round(Math.min(480, width) * height / width)) } : {};
    frame = await extractor.fetchFrameByTime(0,
      media.AVImageQueryOptions.AV_IMAGE_QUERY_CLOSEST_SYNC, params);
    const orientation: number = Number(metadata.videoOrientation ?? '0');
    const quarterTurn: boolean = orientation === 90 || orientation === 270;
    if (quarterTurn && width > 0 && height > 0) {
      const info: image.ImageInfo = await frame.getImageInfo();
      // Some decoders return an upright frame already. Rotate only a frame still using encoded dimensions.
      if (Math.abs(info.size.width / info.size.height - width / height) < 0.02) { await frame.rotate(orientation); }
    } else if (orientation === 180) { await frame.rotate(orientation); }
    return { frame: frame, width: quarterTurn ? height : width, height: quarterTurn ? width : height,
      durationMs: Number(metadata.duration ?? '0') };
  } catch (error) {
    if (frame !== null) { await frame.release().catch((): void => {}); }
    throw error as Error;
  } finally {
    try { if (extractor !== null) { await extractor.release().catch((): void => {}); } }
    finally { fileIo.closeSync(file.fd); }
  }
}
