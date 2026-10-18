import { common } from '@kit.AbilityKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { http } from '@kit.NetworkKit';

// A transparent round bitmap lets HDS keep ownership of the native menu button.
export async function cacheHuaweiAvatar(context: common.UIAbilityContext, url: string,
  active: () => boolean): Promise<string> {
  if (!url.startsWith('https://')) { return ''; }
  const request: http.HttpRequest = http.createHttp();
  let source: image.ImageSource | null = null;
  let bitmap: image.PixelMap | null = null;
  const packer: image.ImagePacker = image.createImagePacker();
  try {
    const response: http.HttpResponse = await request.request(url, { method: http.RequestMethod.GET,
      expectDataType: http.HttpDataType.ARRAY_BUFFER, connectTimeout: 10000, readTimeout: 10000, maxLimit: 2097152 });
    if (!active() || response.responseCode !== 200) { return ''; }
    source = image.createImageSource(response.result as ArrayBuffer);
    bitmap = await source.createPixelMap({ desiredSize: { width: 96, height: 96 },
      desiredPixelFormat: image.PixelMapFormat.RGBA_8888, editable: true });
    const pixels: ArrayBuffer = new ArrayBuffer(96 * 96 * 4);
    await bitmap.readPixelsToBuffer(pixels);
    const bytes: Uint8Array = new Uint8Array(pixels);
    for (let y: number = 0; y < 96; y++) {
      for (let x: number = 0; x < 96; x++) {
        const distance: number = Math.sqrt((x - 47.5) * (x - 47.5) + (y - 47.5) * (y - 47.5));
        const alpha: number = Math.max(0, Math.min(1, 48 - distance));
        bytes[(y * 96 + x) * 4 + 3] = Math.round(bytes[(y * 96 + x) * 4 + 3] * alpha);
      }
    }
    await bitmap.writeBufferToPixels(pixels);
    const png: ArrayBuffer = await packer.packing(bitmap, { format: 'image/png', quality: 100 });
    if (!active()) { return ''; }
    const path: string = context.filesDir + '/huawei-account-avatar.png';
    const file: fileIo.File = fileIo.openSync(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
    try { fileIo.writeSync(file.fd, png); } finally { fileIo.closeSync(file); }
    return fileUri.getUriFromPath(path);
  } catch (error) { return ''; }
  finally { request.destroy(); await bitmap?.release(); await source?.release(); await packer.release(); }
}
