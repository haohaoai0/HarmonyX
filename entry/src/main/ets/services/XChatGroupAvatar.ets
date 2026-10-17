import { common } from '@kit.AbilityKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import util from '@ohos.util';
import { proxyDownloadService } from './ProxyDownloadService';
import { xPrivateStore } from './XPrivateStore';
import { xPrivateClient } from './XPrivateClient';

export type GroupAvatarDecrypt = (inputPath: string, outputPath: string) => Promise<void>;

// A custom group avatar is an encrypted file even when its metadata is a URL.
// Keep its plaintext in an account-scoped app cache, never in the public avatar cache.
export class XChatGroupAvatar {
  private account: string = '';
  private files: Map<string, string> = new Map<string, string>();
  private pending: Map<string, Promise<string>> = new Map<string, Promise<string>>();

  async resolve(context: common.UIAbilityContext, conversationId: string, url: string,
    decrypt: GroupAvatarDecrypt): Promise<string> {
    if (!/^https:\/\//i.test(url)) { return ''; }
    const account: string = xPrivateStore.load(context).cacheIdentity();
    if (account !== this.account) { this.clear(); this.account = account; }
    const key: string = account + ':' + conversationId + ':' + url;
    const cached: string = this.files.get(key) ?? '';
    if (cached.length > 0 && fileIo.accessSync(cached)) { return fileUri.getUriFromPath(cached); }
    const pending: Promise<string> | undefined = this.pending.get(key);
    if (pending !== undefined) { return pending; }
    const request: Promise<string> = this.download(context, account, key, url, decrypt);
    this.pending.set(key, request);
    try { return await request; } finally { this.pending.delete(key); }
  }

  private async download(context: common.UIAbilityContext, account: string, key: string,
    url: string, decrypt: GroupAvatarDecrypt): Promise<string> {
    const directory: string = context.cacheDir + '/xchat_group_avatars';
    if (!fileIo.accessSync(directory)) { fileIo.mkdirSync(directory); }
    const token: string = util.generateRandomUUID();
    const cipher: string = directory + '/' + token + '.encrypted';
    const output: string = directory + '/' + token + '.img';
    try {
      const prefix: string = 'https://ton.x.com/i/ton/data/xchat_media/';
      if (url.startsWith(prefix)) {
        const path: string = url.substring(prefix.length);
        const separator: number = path.indexOf('/');
        if (separator <= 0) { throw new Error('invalid_group_avatar_path'); }
        const bytes: ArrayBuffer = await xPrivateClient.chatMediaBytes(path.substring(0, separator), path.substring(separator + 1));
        const file: fileIo.File = fileIo.openSync(cipher, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
        try { fileIo.writeSync(file.fd, bytes); } finally { fileIo.closeSync(file.fd); }
      } else if (!await proxyDownloadService.download(url, cipher)) { throw new Error('group_avatar_download_failed'); }
      if (account !== this.account || account !== xPrivateStore.load(context).cacheIdentity()) { throw new Error('account_changed'); }
      await decrypt(cipher, output);
      if (account !== this.account || account !== xPrivateStore.load(context).cacheIdentity()) { throw new Error('account_changed'); }
      this.files.set(key, output);
      return fileUri.getUriFromPath(output);
    } catch (error) {
      this.remove(output);
      throw error as Error;
    } finally { this.remove(cipher); }
  }

  clear(): void {
    this.account = '';
    this.files.forEach((path: string): void => this.remove(path));
    this.files.clear(); this.pending.clear();
  }

  private remove(path: string): void {
    try { if (fileIo.accessSync(path)) { fileIo.unlinkSync(path); } } catch (error) {}
  }
}

export const xChatGroupAvatar: XChatGroupAvatar = new XChatGroupAvatar();
