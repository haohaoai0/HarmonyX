import { common } from '@kit.AbilityKit';
import fs from '@ohos.file.fs';
import util from '@ohos.util';
import { image } from '@kit.ImageKit';
import hilog from '@ohos.hilog';
import { xPrivateClient, XPrivateResult } from './XPrivateClient';
import { xPrivateStore } from './XPrivateStore';
import { xChatActions } from './XChatActions';
import { XChatMediaCipher, XChatMediaDescriptor, XChatPage, XChatReplyTarget, xChatService } from './XChatService';
import { XChatConversationId } from './XChatConversationId';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { ChatMovingPhoto, ChatMovingPhotoExport } from './ChatMovingPhoto';
import { ChatMovingPhotoProtocol } from '../utils/ChatMovingPhotoProtocol';

export interface ChatPickedFile {
  uri: string; filename: string; type: number; duration?: number; waveform?: number[];
  movingPhoto?: photoAccessHelper.MovingPhoto;
}
interface ChatPickedIdentity { uri: string; filename: string; type: number; duration?: number; waveform?: number[]; movingPhotoUri?: string; }
export interface ChatCachedFile { path: string; type: number; size: number; savedAt: number; account: string; waveform?: number[]; }
interface ChatCacheEntry { key: string; file: ChatCachedFile; }
interface ChatUploadedMedia { descriptor: XChatMediaDescriptor; keyVersion: string; }
interface ChatPendingMedia {
  uploads: ChatUploadedMedia[]; messageId: string; files: ChatPickedFile[]; ownedPaths: string[];
  sourceUris: string[]; sourceIndexes: number[]; managed: boolean;
}
export interface ChatMediaSendOptions {
  messageId: string;
  onProgress: (fileIndex: number, progress: number) => void;
}
interface ChatUploadInit {
  __typename?: string;
  resume_upload_url?: string;
  media_hash_key?: string;
  resume_id?: string;
  upload_error?: string | null;
}
interface ChatUploadSuccess { __typename?: string; upload_error?: string | null; }
interface ChatUploadData { data?: ChatUploadInitData; }
interface ChatUploadInitData { xchat_initialize_media_upload?: ChatUploadInit; }
interface ChatUploadResponse { data?: ChatUploadFinalizeData; }
interface ChatUploadFinalizeData { xchat_finalize_media_upload?: ChatUploadSuccess; }
export interface ChatMediaStats { photos: number; documents: number; voice: number; total: number; }
export interface ChatGroupAvatarUpload { url: string; keyVersion: string; }

// Plain files live only in an account-scoped cache directory. Upload buffers
// always come from Chat XDK's authenticated SecretStream ciphertext.
export class XChatMedia {
  // Match Chat XDK's maximum number of image/GIF/video wire attachments.
  static readonly MAX_MEDIA_ATTACHMENTS: number = 10;
  private files: Map<string, ChatCachedFile> = new Map<string, ChatCachedFile>();
  private context: common.UIAbilityContext | null = null;
  private epoch: number = 0;
  private hydratedAccount: string = '';
  private pendingUploads: Map<string, ChatPendingMedia> = new Map<string, ChatPendingMedia>();
  constructor() { xPrivateClient.onSessionChange((): void => { this.epoch++; this.clear(); }); }

  selectedFile(uri: string, defaultType: number): ChatPickedFile {
    const path: string = uri.split('?')[0].split('#')[0];
    let filename: string = path.split('/').pop() ?? '';
    try { filename = decodeURIComponent(filename); } catch (error) {}
    if (filename.length === 0) { filename = defaultType === 5 ? 'file' : 'photo.jpg'; }
    let type: number = defaultType;
    if (defaultType === 1) {
      if (/\.gif$/i.test(filename)) { type = 2; }
      else if (/\/video\//i.test(path) || /\.(mp4|mov|m4v|3gp|webm)$/i.test(filename)) { type = 3; }
    }
    return { uri: uri, filename: filename, type: type };
  }

  async selectedMedia(context: common.UIAbilityContext, uri: string): Promise<ChatPickedFile> {
    const file: ChatPickedFile = this.selectedFile(uri, 1);
    if (file.type === 1) { file.movingPhoto = await ChatMovingPhoto.selected(context, uri); }
    return file;
  }

  static mediaSlots(files: ChatPickedFile[]): number {
    let count: number = 0;
    for (let i: number = 0; i < files.length; i++) { count += files[i].movingPhoto === undefined ? 1 : 2; }
    return count;
  }

  private removePending(pending: ChatPendingMedia): void {
    if (this.context !== null) { ChatMovingPhoto.removeExports(this.context, pending.ownedPaths); }
  }

  discardPicked(files: ChatPickedFile[]): void {
    this.pendingUploads.forEach((pending: ChatPendingMedia, key: string): void => {
      if (!pending.managed && files.some((file: ChatPickedFile): boolean => pending.sourceUris.indexOf(file.uri) >= 0)) {
        this.removePending(pending); this.pendingUploads.delete(key);
      }
    });
  }

  discardSend(messageId: string): void {
    this.pendingUploads.forEach((pending: ChatPendingMedia, key: string): void => {
      if (pending.messageId === messageId) { this.removePending(pending); this.pendingUploads.delete(key); }
    });
  }

  cachedPath(context: common.UIAbilityContext, conversationId: string, mediaHash: string): string {
    this.directory(context);
    this.prune(context);
    const key: string = xPrivateStore.load(context).cacheIdentity() + ':' + conversationId + ':' + mediaHash;
    const file: ChatCachedFile | undefined = this.files.get(key);
    return file !== undefined && fs.accessSync(file.path) ? file.path : '';
  }

  private directory(context: common.UIAbilityContext): string {
    this.context = context;
    const path: string = context.cacheDir + '/xchat_media';
    if (!fs.accessSync(path)) { fs.mkdirSync(path); }
    const account: string = xPrivateStore.load(context).cacheIdentity();
    if (this.hydratedAccount !== account) {
      this.files.clear(); this.hydratedAccount = account;
      ChatMovingPhoto.cleanup(context);
      try {
        const index: string = path + '/index.json';
        if (fs.accessSync(index)) {
          const entries: ChatCacheEntry[] = JSON.parse(fs.readTextSync(index)) as ChatCacheEntry[];
          for (let i: number = 0; i < entries.length; i++) {
            const entry: ChatCacheEntry = entries[i];
            const name: string = entry.file.path.substring(path.length + 1);
            if (entry.file.account === account && entry.file.path.startsWith(path + '/') &&
              /^[a-fA-F0-9-]+\.(jpg|gif|mp4|m4a|bin)$/.test(name) && fs.accessSync(entry.file.path)) {
              entry.file.size = fs.statSync(entry.file.path).size; this.files.set(entry.key, entry.file);
            }
          }
        }
        const paths: string[] = [];
        this.files.forEach((file: ChatCachedFile): void => { paths.push(file.path); });
        const names: string[] = fs.listFileSync(path);
        for (let i: number = 0; i < names.length; i++) {
          if (names[i] !== 'index.json' && paths.indexOf(path + '/' + names[i]) < 0) { fs.unlinkSync(path + '/' + names[i]); }
        }
      } catch (error) { /* A missing or corrupt cache index is rebuilt on download. */ }
    }
    return path;
  }

  private persist(): void {
    if (this.context === null) { return; }
    const entries: ChatCacheEntry[] = [];
    this.files.forEach((file: ChatCachedFile, key: string): void => { entries.push({ key: key, file: file }); });
    const file: fs.File = fs.openSync(this.context.cacheDir + '/xchat_media/index.json', fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
    try { fs.writeSync(file.fd, JSON.stringify(entries)); } finally { fs.closeSync(file.fd); }
  }

  initialize(context: common.UIAbilityContext): void { this.directory(context); this.prune(context); }

  stats(): ChatMediaStats {
    const stats: ChatMediaStats = { photos: 0, documents: 0, voice: 0, total: 0 };
    this.files.forEach((file: ChatCachedFile): void => {
      stats.total += file.size;
      if (file.type === 4) { stats.voice += file.size; }
      else if (file.type === 5) { stats.documents += file.size; }
      else { stats.photos += file.size; }
    });
    return stats;
  }

  // Storage cleanup must not discard pending sends, their ciphertext or picked originals.
  clearableCachePaths(context: common.UIAbilityContext): string[] {
    this.directory(context);
    const protectedPaths: Set<string> = new Set<string>();
    this.pendingUploads.forEach((pending: ChatPendingMedia): void => {
      pending.ownedPaths.forEach((path: string): void => { protectedPaths.add(path); });
      pending.sourceUris.forEach((uri: string): void => { protectedPaths.add(uri); });
    });
    const root: string = context.cacheDir + '/xchat_media/';
    const paths: string[] = [];
    this.files.forEach((file: ChatCachedFile): void => {
      if (file.path.startsWith(root) && /^[a-fA-F0-9-]+\.(jpg|gif|mp4|m4a|bin)$/.test(file.path.substring(root.length)) &&
        !protectedPaths.has(file.path) && !protectedPaths.has('file://' + file.path)) { paths.push(file.path); }
    });
    return paths;
  }

  clearDownloadedCache(context: common.UIAbilityContext): number {
    const paths: Set<string> = new Set<string>(this.clearableCachePaths(context));
    let failures: number = 0;
    this.files.forEach((file: ChatCachedFile, key: string): void => {
      if (!paths.has(file.path)) { return; }
      try {
        if (fs.accessSync(file.path)) { fs.unlinkSync(file.path); }
        this.files.delete(key);
      } catch (error) { failures++; }
    });
    this.persist();
    return failures;
  }

  clear(): void {
    this.epoch++;
    this.files.forEach((file: ChatCachedFile): void => { try { if (fs.accessSync(file.path)) { fs.unlinkSync(file.path); } } catch (error) {} });
    this.files.clear();
    this.pendingUploads.forEach((pending: ChatPendingMedia): void => { this.removePending(pending); });
    this.pendingUploads.clear();
    // Also clear files left by an interrupted process. The directory is fixed
    // below this application's cacheDir; no caller-controlled delete paths.
    if (this.context !== null) {
      ChatMovingPhoto.cleanup(this.context);
      const dir: string = this.context.cacheDir + '/xchat_media';
      try {
        if (fs.accessSync(dir)) {
          const names: string[] = fs.listFileSync(dir);
          for (let i: number = 0; i < names.length; i++) { fs.unlinkSync(dir + '/' + names[i]); }
        }
      } catch (error) {}
    }
  }

  prune(context: common.UIAbilityContext): void {
    const days: number = Number(xChatActions.localString(context, 'retention_days', '30'));
    if (days <= 0) { return; }
    this.files.forEach((file: ChatCachedFile, key: string): void => {
      if (Date.now() - file.savedAt > days * 86400000) {
        try { fs.unlinkSync(file.path); } catch (error) {}
        this.files.delete(key);
      }
    });
    this.persist();
  }

  async send(context: common.UIAbilityContext, conversationId: string, file: ChatPickedFile, caption: string): Promise<XChatPage> {
    return this.sendMany(context, conversationId, [file], caption);
  }

  async sendMany(context: common.UIAbilityContext, conversationId: string, files: ChatPickedFile[], caption: string,
    reply?: XChatReplyTarget, options?: ChatMediaSendOptions): Promise<XChatPage> {
    if (files.length === 0 || XChatMedia.mediaSlots(files) > XChatMedia.MAX_MEDIA_ATTACHMENTS) { throw new Error('invalid_media_count'); }
    if (files.length > 1 && files.some((file: ChatPickedFile): boolean => file.type < 1 || file.type > 3)) {
      throw new Error('invalid_media_combination');
    }
    if (XChatConversationId.canonical(conversationId).length === 0) { throw new Error('invalid_media_conversation'); }
    if (options !== undefined && !/^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/.test(options.messageId)) {
      throw new Error('invalid_media_message_id');
    }
    const epoch: number = this.epoch;
    const account: string = xPrivateStore.load(context).cacheIdentity();
    // Keep the whole batch (including completed parts) after an uncertain send.
    // Removing/reordering a file or editing the caption creates a new message.
    this.directory(context);
    const identities: ChatPickedIdentity[] = files.map((file: ChatPickedFile): ChatPickedIdentity => ({
      uri: file.uri, filename: file.filename, type: file.type, duration: file.duration, waveform: file.waveform,
      movingPhotoUri: file.movingPhoto?.getUri()
    }));
    const pendingKey: string = JSON.stringify([account, conversationId, caption, identities, reply, options?.messageId]);
    let pending: ChatPendingMedia | undefined = this.pendingUploads.get(pendingKey);
    if (pending === undefined) {
      if (this.pendingUploads.size >= 8) {
        throw new Error('media_queue_full');
      }
      pending = { uploads: [], messageId: options?.messageId ?? util.generateRandomUUID(), files: [], ownedPaths: [],
        sourceUris: files.map((file: ChatPickedFile): string => file.uri), sourceIndexes: [], managed: options !== undefined };
      this.pendingUploads.set(pendingKey, pending);
    }
    if (pending.files.length === 0) {
      try {
        for (let i: number = 0; i < files.length; i++) {
          const file: ChatPickedFile = files[i];
          if (file.movingPhoto === undefined) { pending.files.push(file); pending.sourceIndexes.push(i); continue; }
          const id: string = util.generateRandomUUID();
          const exported: ChatMovingPhotoExport = await ChatMovingPhoto.export(context, file.movingPhoto, id);
          pending.ownedPaths.push(exported.imagePath, exported.videoPath);
          if (epoch !== this.epoch || account !== xPrivateStore.load(context).cacheIdentity()) { throw new Error('account_changed'); }
          pending.files.push({ uri: exported.imagePath, filename: ChatMovingPhotoProtocol.imageName(id), type: 1 },
            { uri: exported.videoPath, filename: ChatMovingPhotoProtocol.videoName(id), type: 3 });
          pending.sourceIndexes.push(i, i);
        }
      } catch (error) {
        this.removePending(pending); this.pendingUploads.delete(pendingKey);
        if (epoch !== this.epoch || account !== xPrivateStore.load(context).cacheIdentity()) { throw new Error('account_changed'); }
        throw error as Error;
      }
    }
    const expanded: ChatPickedFile[] = pending.files;
    const completedUploads: number = pending.uploads.length;
    const wireProgress: number[] = expanded.map((_file: ChatPickedFile, index: number): number =>
      index < completedUploads ? 97 : 0);
    const sourceIndexes: number[] = pending.sourceIndexes;
    const report: (wireIndex: number, progress: number) => void = (wireIndex: number, progress: number): void => {
      if (options === undefined || epoch !== this.epoch || account !== xPrivateStore.load(context).cacheIdentity()) { return; }
      wireProgress[wireIndex] = progress;
      const sourceIndex: number = sourceIndexes[wireIndex];
      let total: number = 0; let count: number = 0;
      for (let index: number = 0; index < sourceIndexes.length; index++) {
        if (sourceIndexes[index] === sourceIndex) { total += wireProgress[index]; count++; }
      }
      if (count > 0) { options.onProgress(sourceIndex, total / count); }
    };
    for (let i: number = 0; i < wireProgress.length; i++) { report(i, wireProgress[i]); }
    for (let i: number = pending.uploads.length; i < expanded.length; i++) {
      const uploaded: ChatUploadedMedia = await this.upload(context, conversationId, expanded[i], pending.messageId,
        (progress: number): void => { report(i, progress); });
      if (epoch !== this.epoch || account !== xPrivateStore.load(context).cacheIdentity()) { throw new Error('account_changed'); }
      if (pending.uploads.length > 0 && uploaded.keyVersion !== pending.uploads[0].keyVersion) {
        this.removePending(pending); this.pendingUploads.delete(pendingKey); throw new Error('media_key_changed');
      }
      pending.uploads.push(uploaded);
    }
    if (epoch !== this.epoch || account !== xPrivateStore.load(context).cacheIdentity()) { throw new Error('account_changed'); }
    const descriptors: XChatMediaDescriptor[] = pending.uploads.map((uploaded: ChatUploadedMedia): XChatMediaDescriptor => uploaded.descriptor);
    for (let i: number = 0; i < expanded.length; i++) { report(i, 98); }
    const confirmed: XChatPage = await xChatService.send(conversationId, caption, descriptors, pending.uploads[0].keyVersion, pending.messageId, reply);
    if (epoch !== this.epoch || account !== xPrivateStore.load(context).cacheIdentity()) { throw new Error('account_changed'); }
    for (let i: number = 0; i < expanded.length; i++) { this.cacheSent(context, account, conversationId, expanded[i], descriptors[i]); }
    for (let i: number = 0; i < expanded.length; i++) { report(i, 100); }
    hilog.info(0xFF00, 'HarmonyX-Chat', 'media message confirmed: attachments=%{public}d', expanded.length);
    this.removePending(pending);
    this.pendingUploads.delete(pendingKey);
    return confirmed;
  }

  private cacheSent(context: common.UIAbilityContext, account: string, conversationId: string,
    picked: ChatPickedFile, descriptor: XChatMediaDescriptor): void {
    try {
      const directory: string = this.directory(context);
      const type: number = descriptor.media_type;
      const output: string = directory + '/' + util.generateRandomUUID() +
        (type === 3 ? '.mp4' : type === 4 ? '.m4a' : type === 2 ? '.gif' : type === 1 ? '.jpg' : '.bin');
      const source: fs.File = fs.openSync(picked.uri, fs.OpenMode.READ_ONLY);
      try { fs.copyFileSync(source.fd, output); } finally { fs.closeSync(source.fd); }
      const key: string = account + ':' + conversationId + ':' + descriptor.media_hash_key;
      this.files.set(key, { path: output, type: type, size: fs.statSync(output).size,
        savedAt: Date.now(), account: account, waveform: picked.waveform });
      this.persist();
    } catch (error) { /* The confirmed attachment can be downloaded again. */ }
  }

  waveform(context: common.UIAbilityContext, conversationId: string, mediaHash: string): number[] {
    this.directory(context);
    const key: string = xPrivateStore.load(context).cacheIdentity() + ':' + conversationId + ':' + mediaHash;
    return this.files.get(key)?.waveform ?? [];
  }

  async uploadGroupAvatar(context: common.UIAbilityContext, conversationId: string, uri: string,
    keyVersion: string = ''): Promise<ChatGroupAvatarUpload> {
    const id: string = XChatConversationId.canonical(conversationId);
    const result: ChatUploadedMedia = await this.upload(context, id, this.selectedFile(uri, 1),
      'avatar-' + id + '-' + util.generateRandomUUID(), (_progress: number): void => {}, true, keyVersion);
    return { url: 'https://ton.x.com/i/ton/data/xchat_media/' + id + '/' + result.descriptor.media_hash_key,
      keyVersion: result.keyVersion };
  }

  private async upload(context: common.UIAbilityContext, conversationId: string, file: ChatPickedFile,
    messageId: string, onProgress: (progress: number) => void = (_progress: number): void => {},
    groupAvatar: boolean = false, keyVersion: string = ''): Promise<ChatUploadedMedia> {
    const uploadConversationId: string = XChatConversationId.canonical(conversationId);
    if (uploadConversationId.length === 0) { throw new Error('invalid_media_conversation'); }
    const epoch: number = this.epoch;
    const account: string = xPrivateStore.load(context).cacheIdentity();
    const directory: string = this.directory(context);
    const token: string = util.generateRandomUUID();
    const plain: string = directory + '/' + token + '.source';
    const cipher: string = directory + '/' + token + '.encrypted';
    try {
      const source: fs.File = fs.openSync(file.uri, fs.OpenMode.READ_ONLY);
      try { fs.copyFileSync(source.fd, plain); } finally { fs.closeSync(source.fd); }
      const bytes: number = fs.statSync(plain).size;
      if (bytes > 32 * 1024 * 1024 || bytes <= 0) { throw new Error('media_too_large'); }
      hilog.info(0xFF00, 'HarmonyX-Chat', 'media read: bytes=%{public}d type=%{public}d', bytes, file.type);
      let width: number = 0; let height: number = 0;
      let mediaType: number = file.type;
      if (file.type === 1 || file.type === 2) {
        const input: image.ImageSource = image.createImageSource(plain);
        try {
          const info: image.ImageInfo = await input.getImageInfo();
          width = info.size.width; height = info.size.height;
          // Media-library URIs do not always include the original extension.
          if (info.mimeType === 'image/gif') { mediaType = 2; }
        }
        finally { await input.release(); }
      }
      const encrypted: XChatMediaCipher = keyVersion.length > 0 ?
        await xChatService.encryptGroupMedia(conversationId, plain, cipher, keyVersion) :
        await xChatService.processMedia(conversationId, plain, cipher);
      hilog.info(0xFF00, 'HarmonyX-Chat', 'media encrypted: bytes=%{public}d', encrypted.size);
      if (epoch !== this.epoch || account !== xPrivateStore.load(context).cacheIdentity()) { throw new Error('account_changed'); }
      const init: XPrivateResult = await xPrivateClient.graphql('InitializeXChatMediaUploadMutation', {
        'conversation_id': uploadConversationId, 'message_id': messageId,
        'total_bytes': encrypted.size.toString(), 'is_public': false
      });
      if (!init.ok) { throw new Error('media_init_http_' + init.status); }
      const upload: ChatUploadInit | undefined = (JSON.parse(init.body) as ChatUploadData).data?.xchat_initialize_media_upload;
      if (upload?.__typename !== 'InitializeMediaUploadResult' || (upload.media_hash_key ?? '').length === 0 ||
        !/^\d+$/.test(upload.resume_id ?? '') || upload.upload_error !== undefined && upload.upload_error !== null) {
        throw new Error('media_init_unconfirmed');
      }
      const mediaHash: string = upload.media_hash_key ?? '';
      const resumeId: string = upload.resume_id ?? '';
      hilog.info(0xFF00, 'HarmonyX-Chat', 'media upload initialized');
      const input: fs.File = fs.openSync(cipher, fs.OpenMode.READ_ONLY);
      let parts: number = 0;
      let reportedBytes: number = 0;
      try {
        for (let offset: number = 0; offset < encrypted.size; offset += 1024 * 1024) {
          if (epoch !== this.epoch || account !== xPrivateStore.load(context).cacheIdentity()) { throw new Error('account_changed'); }
          const chunk: ArrayBuffer = new ArrayBuffer(Math.min(1024 * 1024, encrypted.size - offset));
          const count: number = fs.readSync(input.fd, chunk, { offset: offset, length: chunk.byteLength });
          if (count !== chunk.byteLength) { throw new Error('media_read_failed'); }
          const append: XPrivateResult = await xPrivateClient.uploadChatMediaPart(uploadConversationId, mediaHash, resumeId, parts, chunk,
            upload.resume_upload_url ?? '', (sentBytes: number, totalBytes: number): void => {
              if (epoch !== this.epoch || account !== xPrivateStore.load(context).cacheIdentity() ||
                !Number.isFinite(sentBytes) || !Number.isFinite(totalBytes) || totalBytes <= 0 || sentBytes < 0) { return; }
              // Native progress is cumulative within this part. Retransmitting
              // a part after auth/proxy fallback must not count its bytes twice.
              reportedBytes = Math.max(reportedBytes, offset + count * Math.min(1, sentBytes / totalBytes));
              onProgress(95 * reportedBytes / encrypted.size);
            });
          // TON acknowledges a successful binary part with an empty 2xx body.
          if (!append.ok) { throw new Error('media_append_http_' + append.status); }
          if (epoch !== this.epoch || account !== xPrivateStore.load(context).cacheIdentity()) { throw new Error('account_changed'); }
          parts++;
          reportedBytes = Math.max(reportedBytes, offset + count);
          onProgress(95 * reportedBytes / encrypted.size);
        }
      } finally { fs.closeSync(input.fd); }
      hilog.info(0xFF00, 'HarmonyX-Chat', 'media parts uploaded: %{public}d', parts);
      const finalizeArgs: Record<string, Object> = {
        'conversation_id': uploadConversationId, 'message_id': messageId, 'is_public': false,
        'media_hash_key': mediaHash, 'resume_id': resumeId, 'num_parts': parts.toString()
      };
      const ttl: string = xChatService.conversationInfo(conversationId).ttl;
      if (!groupAvatar && Number(ttl) > 0) { finalizeArgs['ttl_msec'] = ttl; }
      const finalize: XPrivateResult = await xPrivateClient.graphql('FinalizeXChatMediaUploadMutation', finalizeArgs);
      if (!finalize.ok) { throw new Error('media_finalize_http_' + finalize.status); }
      const finalized: ChatUploadSuccess | undefined =
        (JSON.parse(finalize.body) as ChatUploadResponse).data?.xchat_finalize_media_upload;
      // The server omits a null upload_error in a successful response. Require
      // the known result type so an unrelated 200 body cannot pass this check.
      if (finalized?.__typename !== 'FinalizeMediaUploadResponse' ||
        finalized.upload_error !== undefined && finalized.upload_error !== null) { throw new Error('media_finalize_unconfirmed'); }
      hilog.info(0xFF00, 'HarmonyX-Chat', 'media upload finalized');
      if (epoch !== this.epoch || account !== xPrivateStore.load(context).cacheIdentity()) { throw new Error('account_changed'); }
      onProgress(97);
      const descriptor: XChatMediaDescriptor = { attachment_type: 'media', media_hash_key: mediaHash,
        width: width, height: height, filesize_bytes: bytes, filename: file.filename,
        media_type: mediaType, duration_millis: file.duration };
      return { descriptor: descriptor, keyVersion: encrypted.keyVersion };
    } finally {
      try { if (fs.accessSync(plain)) { fs.unlinkSync(plain); } } catch (error) {}
      try { if (fs.accessSync(cipher)) { fs.unlinkSync(cipher); } } catch (error) {}
    }
  }

  async receive(context: common.UIAbilityContext, conversationId: string, mediaHash: string,
    keyVersion: string, type: number): Promise<string> {
    if (!xChatService.isUnlocked()) { throw new Error('locked'); }
    const directory: string = this.directory(context);
    this.prune(context);
    const account: string = xPrivateStore.load(context).cacheIdentity();
    const key: string = account + ':' + conversationId + ':' + mediaHash;
    const cached: ChatCachedFile | undefined = this.files.get(key);
    if (cached !== undefined && fs.accessSync(cached.path)) { return cached.path; }
    const epoch: number = this.epoch;
    const token: string = util.generateRandomUUID();
    const cipher: string = directory + '/' + token + '.encrypted';
    const output: string = directory + '/' + token + (type === 3 ? '.mp4' : type === 4 ? '.m4a' : type === 2 ? '.gif' : type === 1 ? '.jpg' : '.bin');
    try {
      const bytes: ArrayBuffer = await xPrivateClient.chatMediaBytes(conversationId, mediaHash);
      if (epoch !== this.epoch || account !== xPrivateStore.load(context).cacheIdentity()) { throw new Error('account_changed'); }
      const file: fs.File = fs.openSync(cipher, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
      try { fs.writeSync(file.fd, bytes); } finally { fs.closeSync(file.fd); }
      const decrypted: XChatMediaCipher = await xChatService.processMedia(conversationId, cipher, output, keyVersion);
      if (epoch !== this.epoch || account !== xPrivateStore.load(context).cacheIdentity()) { fs.unlinkSync(output); throw new Error('account_changed'); }
      this.files.set(key, { path: output, type: type, size: decrypted.size, savedAt: Date.now(), account: account });
      this.persist();
      return output;
    } catch (error) {
      try { if (fs.accessSync(output)) { fs.unlinkSync(output); } } catch (cleanupError) {}
      throw error as Error;
    } finally { try { if (fs.accessSync(cipher)) { fs.unlinkSync(cipher); } } catch (error) {} }
  }
}

export const xChatMedia: XChatMedia = new XChatMedia();
