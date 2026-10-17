// X stores an animated GIF as an MP4 rendition, so "save as GIF" means decoding
// a bounded frame sequence and re-encoding it as a real animated GIF file.
import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { media } from '@kit.MediaKit';
import hilog from '@ohos.hilog';

const DOMAIN: number = 0xFF00;
const TAG: string = 'HarmonyX-Gif';

// Sampling stays coarse and bounded: the encoder holds every frame in memory at
// once, and the reader waits for the file to be produced.
const GIF_FRAME_INTERVAL_MS: number = 140;
const GIF_MAX_FRAMES: number = 72;
const GIF_MAX_WIDTH: number = 320;
const GIF_MAX_HEIGHT: number = 480;
const GIF_MIN_FRAMES: number = 2;
// GIF delays are expressed in hundredths of a second.
const GIF_DELAY_UNIT_MS: number = 10;
const GIF_DEFAULT_DURATION_MS: number = 2800;
const GIF_DISPOSAL_KEEP: number = 1;

interface GifSourceInfo {
  durationMs: number;
  width: number;
  height: number;
}

class GifFrameSize {
  width: number = 0;
  height: number = 0;

  constructor(width: number, height: number) {
    this.width = width;
    this.height = height;
  }
}

function even(value: number): number {
  const rounded: number = Math.max(2, Math.round(value));
  return rounded % 2 === 0 ? rounded : rounded + 1;
}

// Keep the source aspect ratio, but cap both edges so a tall clip cannot ask the
// encoder for more pixels than a GIF can reasonably carry.
export function gifFrameSize(sourceWidth: number, sourceHeight: number): GifFrameSize {
  const width: number = sourceWidth > 0 ? sourceWidth : GIF_MAX_WIDTH;
  const height: number = sourceHeight > 0 ? sourceHeight : GIF_MAX_WIDTH;
  const scale: number = Math.min(1, GIF_MAX_WIDTH / width, GIF_MAX_HEIGHT / height);
  return new GifFrameSize(even(width * scale), even(height * scale));
}

export class GifTranscoder {
  async transcode(context: common.UIAbilityContext, sourcePath: string, cacheName: string,
    durationMs: number, sourceWidth: number, sourceHeight: number): Promise<string> {
    const info: GifSourceInfo = await this.readSourceInfo(sourcePath, durationMs, sourceWidth, sourceHeight);
    const size: GifFrameSize = gifFrameSize(info.width, info.height);
    const frameCount: number = this.frameCount(info.durationMs);
    const frames: image.PixelMap[] = [];
    let generator: media.AVImageGenerator | null = null;
    let packer: image.ImagePacker | null = null;
    let sourceFile: fileIo.File | null = null;
    try {
      sourceFile = await fileIo.open(sourcePath, fileIo.OpenMode.READ_ONLY);
      generator = await media.createAVImageGenerator();
      const sourceDescriptor: media.AVFileDescriptor = { fd: sourceFile.fd };
      generator.fdSrc = sourceDescriptor;
      const params: media.PixelMapParams = { width: size.width, height: size.height };
      for (let index: number = 0; index < frameCount; index++) {
        const timeUs: number = index * GIF_FRAME_INTERVAL_MS * 1000;
        const frame: image.PixelMap = await generator.fetchFrameByTime(timeUs,
          media.AVImageQueryOptions.AV_IMAGE_QUERY_CLOSEST, params);
        frames.push(frame);
      }
      packer = image.createImagePacker();
      const options: image.PackingOptionsForSequence = {
        frameCount: frames.length,
        delayTimeList: this.delays(frames.length),
        disposalTypes: this.disposals(frames.length),
        // Animated GIFs loop forever, exactly like the post they came from.
        loopCount: 0
      };
      const data: ArrayBuffer = await packer.packToDataFromPixelmapSequence(frames, options);
      const destination: string = context.cacheDir + '/harmonyx-gif-' + cacheName + '.gif';
      const target: fileIo.File = await fileIo.open(destination,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      try {
        await fileIo.write(target.fd, data);
      } finally {
        fileIo.closeSync(target.fd);
      }
      return destination;
    } finally {
      for (let index: number = 0; index < frames.length; index++) {
        await frames[index].release().catch((): void => {});
      }
      if (packer !== null) {
        await packer.release().catch((): void => {});
      }
      if (generator !== null) {
        await generator.release().catch((): void => {});
      }
      if (sourceFile !== null) {
        fileIo.closeSync(sourceFile.fd);
      }
    }
  }

  private frameCount(durationMs: number): number {
    const duration: number = durationMs > 0 ? durationMs : GIF_DEFAULT_DURATION_MS;
    const sampled: number = Math.ceil(duration / GIF_FRAME_INTERVAL_MS);
    return Math.min(GIF_MAX_FRAMES, Math.max(GIF_MIN_FRAMES, sampled));
  }

  private delays(count: number): number[] {
    const delay: number = Math.round(GIF_FRAME_INTERVAL_MS / GIF_DELAY_UNIT_MS);
    const list: number[] = [];
    for (let index: number = 0; index < count; index++) {
      list.push(delay);
    }
    return list;
  }

  private disposals(count: number): number[] {
    const list: number[] = [];
    for (let index: number = 0; index < count; index++) {
      list.push(GIF_DISPOSAL_KEEP);
    }
    return list;
  }

  // The post already carries the animation's duration and size; the file is only
  // consulted when one of them is missing.
  private async readSourceInfo(sourcePath: string, durationMs: number, sourceWidth: number,
    sourceHeight: number): Promise<GifSourceInfo> {
    const known: GifSourceInfo = {
      durationMs: durationMs, width: sourceWidth, height: sourceHeight
    };
    if (known.durationMs > 0 && known.width > 0 && known.height > 0) {
      return known;
    }
    let file: fileIo.File | null = null;
    let extractor: media.AVMetadataExtractor | null = null;
    try {
      file = await fileIo.open(sourcePath, fileIo.OpenMode.READ_ONLY);
      extractor = await media.createAVMetadataExtractor();
      const sourceDescriptor: media.AVFileDescriptor = { fd: file.fd };
      extractor.fdSrc = sourceDescriptor;
      const metadata: media.AVMetadata = await extractor.fetchMetadata();
      return {
        durationMs: known.durationMs > 0 ? known.durationMs : Number(metadata.duration ?? '0'),
        width: known.width > 0 ? known.width : Number(metadata.videoWidth ?? '0'),
        height: known.height > 0 ? known.height : Number(metadata.videoHeight ?? '0')
      };
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'GIF source metadata unavailable');
      return known;
    } finally {
      if (extractor !== null) {
        await extractor.release().catch((): void => {});
      }
      if (file !== null) {
        fileIo.closeSync(file.fd);
      }
    }
  }
}

export const gifTranscoder: GifTranscoder = new GifTranscoder();
