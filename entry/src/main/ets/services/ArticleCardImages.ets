import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { formBindingData } from '@kit.FormKit';
import { ArticleCardFormData, ArticleCardItem } from '../models/ArticleCardItem';
import { proxyDownloadService } from './ProxyDownloadService';
import { XUserParser } from './XUserParser';

const IMAGE_EDGE: number = 1536;
const CACHE_LIMIT: number = 48;

export class ArticleCardImageBinding {
  data: ArticleCardFormData;
  files: fileIo.File[] = [];

  constructor(items: ArticleCardItem[], dimension: string, source: string) {
    this.data = new ArticleCardFormData(items, dimension, source);
  }

  bindingData(): formBindingData.FormBindingData {
    return formBindingData.createFormBindingData(this.data);
  }

  close(): void {
    for (let i: number = 0; i < this.files.length; i++) {
      try { fileIo.closeSync(this.files[i]); } catch (error) { }
    }
    this.files = [];
  }
}

// Network access stays in the app process. Forms receive only small, local
// JPEGs through Form Kit's descriptor transport, never remote/file URLs.
export class ArticleCardImages {
  private static pending: Map<string, Promise<boolean>> = new Map();

  private static directory(context: common.Context): string {
    return context.cacheDir + '/article-card-images-v2-hd';
  }

  private static key(url: string): string {
    let hash: number = 0x811C9DC5;
    let second: number = 5381;
    for (let i: number = 0; i < url.length; i++) {
      hash = Math.imul(hash ^ url.charCodeAt(i), 0x01000193) >>> 0;
      second = Math.imul(second, 33) ^ url.charCodeAt(i);
    }
    return hash.toString(16) + '-' + (second >>> 0).toString(16);
  }

  private static path(context: common.Context, url: string): string {
    return ArticleCardImages.directory(context) + '/' + ArticleCardImages.key(url) + '.jpg';
  }

  private static ready(path: string): boolean {
    try {
      return fileIo.statSync(path).size > 0;
    } catch (error) {
      return false;
    }
  }

  private static attach(context: common.Context, url: string, binding: ArticleCardImageBinding,
    suffix: string): string {
    if (url.length === 0 || !ArticleCardImages.ready(ArticleCardImages.path(context, url))) {
      return '';
    }
    try {
      const file: fileIo.File = fileIo.openSync(ArticleCardImages.path(context, url), fileIo.OpenMode.READ_ONLY);
      binding.files.push(file);
      const name: string = 'card-hd2-' + ArticleCardImages.key(url) + '-' + suffix;
      binding.data.formImages[name] = file.fd;
      return 'memory://' + name;
    } catch (error) {
      return '';
    }
  }

  static bind(context: common.Context, items: ArticleCardItem[], dimension: string,
    source: string): ArticleCardImageBinding {
    const binding: ArticleCardImageBinding = new ArticleCardImageBinding([], dimension, source);
    for (let i: number = 0; i < items.length; i++) {
      const item: ArticleCardItem = items[i];
      const out: ArticleCardItem = new ArticleCardItem();
      out.kind = item.kind;
      out.postId = item.postId;
      out.query = item.query;
      out.title = item.title;
      out.label = item.label;
      out.mediaIsVideo = item.mediaIsVideo;
      out.mediaUrl = ArticleCardImages.attach(context, item.mediaUrl, binding, 'media');
      out.avatarUrl = ArticleCardImages.attach(context, XUserParser.highResAvatarUrl(item.avatarUrl), binding, 'avatar');
      binding.data.cardList.push(out);
    }
    return binding;
  }

  static async warm(context: common.Context, items: ArticleCardItem[]): Promise<boolean> {
    let changed: boolean = false;
    for (let i: number = 0; i < items.length; i++) {
      const item: ArticleCardItem = items[i];
      const url: string = item.mediaUrl.length > 0 ? item.mediaUrl : XUserParser.highResAvatarUrl(item.avatarUrl);
      if (url.length === 0) { continue; }
      if (await ArticleCardImages.load(context, url)) { changed = true; }
    }
    return changed;
  }

  private static load(context: common.Context, url: string): Promise<boolean> {
    const path: string = ArticleCardImages.path(context, url);
    if (ArticleCardImages.ready(path)) { return Promise.resolve(false); }
    const active: Promise<boolean> | undefined = ArticleCardImages.pending.get(path);
    if (active !== undefined) { return active; }
    const request: Promise<boolean> = ArticleCardImages.download(context, url, path)
      .finally((): void => { ArticleCardImages.pending.delete(path); });
    ArticleCardImages.pending.set(path, request);
    return request;
  }

  private static async download(context: common.Context, url: string, path: string): Promise<boolean> {
    const temporary: string = path + '.download';
    let original: fileIo.File | null = null;
    let output: fileIo.File | null = null;
    let source: image.ImageSource | null = null;
    let pixels: image.PixelMap | null = null;
    let packer: image.ImagePacker | null = null;
    try {
      const directory: string = ArticleCardImages.directory(context);
      if (!fileIo.accessSync(directory)) { fileIo.mkdirSync(directory, true); }
      if (!await proxyDownloadService.download(url, temporary)) { return false; }
      original = fileIo.openSync(temporary, fileIo.OpenMode.READ_ONLY);
      source = image.createImageSource(original.fd);
      const info: image.ImageInfo = await source.getImageInfo();
      const scale: number = Math.min(1, IMAGE_EDGE / Math.max(info.size.width, info.size.height));
      pixels = await source.createPixelMap({
        desiredSize: {
          width: Math.max(1, Math.round(info.size.width * scale)),
          height: Math.max(1, Math.round(info.size.height * scale))
        }
      });
      packer = image.createImagePacker();
      const bytes: ArrayBuffer = await packer.packToData(pixels, { format: 'image/jpeg', quality: 94 });
      output = fileIo.openSync(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(output.fd, bytes);
      ArticleCardImages.prune(directory, path);
      return true;
    } catch (error) {
      try { fileIo.unlinkSync(path); } catch (removeError) { }
      return false;
    } finally {
      if (output !== null) { try { fileIo.closeSync(output); } catch (error) { } }
      if (packer !== null) { await packer.release().catch((): void => { }); }
      if (pixels !== null) { await pixels.release().catch((): void => { }); }
      if (source !== null) { await source.release().catch((): void => { }); }
      if (original !== null) { try { fileIo.closeSync(original); } catch (error) { } }
      try { fileIo.unlinkSync(temporary); } catch (error) { }
    }
  }

  private static prune(directory: string, keep: string): void {
    try {
      const names: string[] = fileIo.listFileSync(directory).filter((name: string): boolean => name.endsWith('.jpg'));
      names.sort((left: string, right: string): number =>
        fileIo.statSync(directory + '/' + right).mtime - fileIo.statSync(directory + '/' + left).mtime);
      for (let i: number = CACHE_LIMIT; i < names.length; i++) {
        const path: string = directory + '/' + names[i];
        if (path !== keep) { try { fileIo.unlinkSync(path); } catch (error) { } }
      }
    } catch (error) { }
  }
}
