import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { systemShare } from '@kit.ShareKit';
import { preferences, uniformTypeDescriptor } from '@kit.ArkData';

export function logoParticipation(context: common.Context, accountId: string, joined?: boolean): boolean {
  if (accountId.length === 0) { return false; }
  try {
    const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: 'harmonyx_logo_participation' });
    const key: string = 'joined_' + accountId;
    if (joined !== undefined) { store.putSync(key, joined); store.flushSync(); }
    return store.getSync(key, false) as boolean;
  } catch (error) { return false; }
}

export async function writeLogoKeepsake(context: common.Context, pixels: image.PixelMap): Promise<string> {
  const path: string = context.cacheDir + '/HarmonyX-keepsake-' + Date.now().toString() + '.png';
  const packer: image.ImagePacker = image.createImagePacker();
  let file: fileIo.File | null = null;
  try {
    const bytes: ArrayBuffer = await packer.packToData(pixels, { format: 'image/png', quality: 100 });
    file = fileIo.openSync(path, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
    fileIo.writeSync(file.fd, bytes);
    return path;
  } finally {
    if (file !== null) { fileIo.closeSync(file.fd); }
    await packer.release();
  }
}

export async function saveLogoKeepsake(context: common.UIAbilityContext, path: string): Promise<boolean> {
  const helper: photoAccessHelper.PhotoAccessHelper = photoAccessHelper.getPhotoAccessHelper(context);
  const configs: photoAccessHelper.PhotoCreationConfig[] = [{ title: 'HarmonyX-' + Date.now().toString(),
    fileNameExtension: 'png', photoType: photoAccessHelper.PhotoType.IMAGE,
    subtype: photoAccessHelper.PhotoSubtype.DEFAULT }];
  const destinations: string[] = await helper.showAssetsCreationDialog([path], configs);
  if (destinations.length === 0) { return false; }
  const source: fileIo.File = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
  let destination: fileIo.File | null = null;
  try {
    destination = fileIo.openSync(destinations[0], fileIo.OpenMode.WRITE_ONLY);
    await fileIo.copyFile(source.fd, destination.fd);
    return true;
  } finally {
    fileIo.closeSync(source.fd);
    if (destination !== null) { fileIo.closeSync(destination.fd); }
  }
}

export async function shareLogoKeepsake(context: common.UIAbilityContext, path: string, title: string): Promise<void> {
  const data: systemShare.SharedData = new systemShare.SharedData({
    utd: uniformTypeDescriptor.UniformDataType.IMAGE, uri: fileUri.getUriFromPath(path), title: title
  });
  const controller: systemShare.ShareController = new systemShare.ShareController(data);
  await controller.show(context, { selectionMode: systemShare.SelectionMode.SINGLE,
    previewMode: systemShare.SharePreviewMode.DEFAULT });
}
