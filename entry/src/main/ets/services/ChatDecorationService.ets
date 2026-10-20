import { common } from '@kit.AbilityKit';
import { zlib } from '@kit.BasicServicesKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { http } from '@kit.NetworkKit';
import { image } from '@kit.ImageKit';
import util from '@ohos.util';
import { xChatActions } from './XChatActions';
import { XXAUTH_APP_ID } from './XXAuthService';

const API_ORIGIN: string = 'https://api.xxauth.com';
const API_BASE: string = API_ORIGIN + '/open/v1';
const CATALOG_CODE: string = 'chat_decorations_catalog';
const MAX_PACKAGE_BYTES: number = 8 * 1024 * 1024;
const DOWNLOAD_DIRECTORY: string = 'chat_decorations';
const SELECTION_KEY: string = 'decoration:selection';
const INSTALL_PREFIX: string = 'decoration:installed:';
export const CHAT_DECORATION_REVISION_KEY: string = 'harmonyx.chat_decoration_revision';

interface DecorationEnvelope<T> {
  code: number;
  message?: string;
  data?: T;
}

interface DecorationResourceValue<T> {
  code: string;
  type: string;
  value: T;
}

interface DecorationTicket {
  code: string;
  download_url: string;
  expires_in: number;
  file_name: string;
  file_size: number;
  type: string;
}

interface RawCatalog {
  schemaVersion: number;
  version: string;
  group: string;
  free: boolean;
  items: ChatDecorationCatalogItem[];
}

interface PackageFileRecord {
  role: string;
  path: string;
  bytes: number;
  sha256: string;
  avatarRectHint?: AvatarRectHint;
  textColor?: string;
  sliceHintPx?: BubbleSliceHint;
}

interface PackageManifest {
  id: string;
  version: string;
  files: PackageFileRecord[];
}

interface AvatarRectHint {
  left: number;
  top: number;
  width: number;
  height: number;
}

interface BubbleSliceHint {
  left: number;
  right: number;
  top: number;
  bottom: number;
}

export class ChatDecorationCatalogItem {
  id: string = '';
  name: string = '';
  nameEn: string = '';
  description: string = '';
  resourceCode: string = '';
  file: string = '';
  bytes: number = 0;
  sha256: string = '';
}

export class ChatDecorationInstall {
  id: string = '';
  version: string = '';
  root: string = '';
  framePath: string = '';
  frameUri: string = '';
  bubblePath: string = '';
  bubbleUri: string = '';
  avatarLeft: number = 0.15;
  avatarTop: number = 0.15;
  avatarWidth: number = 0.7;
  avatarHeight: number = 0.7;
  bubbleTextColor: string = '#202C26';
  sliceLeft: number = 0;
  sliceRight: number = 0;
  sliceTop: number = 0;
  sliceBottom: number = 0;
}

export class ChatDecorationSelection {
  frameId: string = '';
  framePath: string = '';
  frameUri: string = '';
  bubbleId: string = '';
  bubblePath: string = '';
  bubbleUri: string = '';
  bubbleTextColor: string = '#202C26';
  sliceLeft: number = 0;
  sliceRight: number = 0;
  sliceTop: number = 0;
  sliceBottom: number = 0;
}

export class ChatDecorationService {
  private async requestJson<T>(path: string): Promise<T | null> {
    let request: http.HttpRequest | null = null;
    try {
      request = http.createHttp();
      const response: http.HttpResponse = await request.request(API_BASE + path, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.STRING,
        header: { 'app_id': XXAUTH_APP_ID, 'Accept': 'application/json' },
        connectTimeout: 10000,
        readTimeout: 15000
      });
      if (response.responseCode !== 200 || typeof response.result !== 'string') { return null; }
      const envelope: DecorationEnvelope<T> = JSON.parse(response.result) as DecorationEnvelope<T>;
      if (envelope.code !== 0 || envelope.data === undefined || envelope.data === null) { return null; }
      return envelope.data;
    } catch (error) {
      return null;
    } finally {
      if (request !== null) { request.destroy(); }
    }
  }

  async catalog(): Promise<ChatDecorationCatalogItem[]> {
    const resource: DecorationResourceValue<Object> | null =
      await this.requestJson<DecorationResourceValue<Object>>('/entitlements/resources/' + CATALOG_CODE);
    if (resource === null || resource.value === undefined || resource.value === null) { return []; }
    try {
      const raw: RawCatalog = JSON.parse(JSON.stringify(resource.value)) as RawCatalog;
      if (raw.schemaVersion !== 1 || raw.free !== true || !(raw.items instanceof Array)) { return []; }
      const items: ChatDecorationCatalogItem[] = [];
      for (let i: number = 0; i < raw.items.length; i++) {
        const item: ChatDecorationCatalogItem = this.validCatalogItem(raw.items[i]);
        if (item.id.length > 0) { items.push(item); }
      }
      return items;
    } catch (error) {
      return [];
    }
  }

  private validCatalogItem(value: ChatDecorationCatalogItem): ChatDecorationCatalogItem {
    const item: ChatDecorationCatalogItem = new ChatDecorationCatalogItem();
    if (value === null || value === undefined || typeof value.id !== 'string' ||
      !/^[a-z0-9-]{2,48}$/.test(value.id) || typeof value.name !== 'string' ||
      value.name.trim().length === 0 || typeof value.resourceCode !== 'string' ||
      !/^[A-Za-z0-9._-]{3,96}$/.test(value.resourceCode) || typeof value.file !== 'string' ||
      !/^[A-Za-z0-9._-]+\.zip$/.test(value.file) || typeof value.sha256 !== 'string' ||
      !/^[a-fA-F0-9]{64}$/.test(value.sha256) || !Number.isFinite(value.bytes) ||
      value.bytes <= 0 || value.bytes > MAX_PACKAGE_BYTES) {
      return item;
    }
    item.id = value.id;
    item.name = value.name.trim();
    item.nameEn = typeof value.nameEn === 'string' ? value.nameEn.trim() : '';
    item.description = typeof value.description === 'string' ? value.description.trim() : '';
    item.resourceCode = value.resourceCode;
    item.file = value.file;
    item.bytes = value.bytes;
    item.sha256 = value.sha256.toLowerCase();
    return item;
  }

  private directory(context: common.Context): string {
    return context.filesDir + '/' + DOWNLOAD_DIRECTORY;
  }

  private ensureDirectory(path: string): void {
    if (!fileIo.accessSync(path)) { fileIo.mkdirSync(path, true); }
  }

  private removeFile(path: string): void {
    if (path.length === 0) { return; }
    try {
      if (fileIo.accessSync(path)) { fileIo.unlinkSync(path); }
    } catch (error) {}
  }

  private removeTree(path: string): void {
    if (path.length === 0) { return; }
    try {
      if (!fileIo.accessSync(path)) { return; }
      const stat: fileIo.Stat = fileIo.statSync(path);
      if (!stat.isDirectory()) { fileIo.unlinkSync(path); return; }
      const names: string[] = fileIo.listFileSync(path);
      for (let i: number = 0; i < names.length; i++) {
        this.removeTree(path + '/' + names[i]);
      }
      fileIo.rmdirSync(path);
    } catch (error) {}
  }

  private async ticket(item: ChatDecorationCatalogItem): Promise<DecorationTicket | null> {
    return this.requestJson<DecorationTicket>('/entitlements/resources/' + encodeURIComponent(item.resourceCode));
  }

  private async sha256(data: ArrayBuffer): Promise<string> {
    const md: cryptoFramework.Md = cryptoFramework.createMd('SHA256');
    const blob: cryptoFramework.DataBlob = { data: new Uint8Array(data) };
    await md.update(blob);
    const digest: cryptoFramework.DataBlob = await md.digest();
    let result: string = '';
    for (let i: number = 0; i < digest.data.length; i++) {
      result += digest.data[i].toString(16).padStart(2, '0');
    }
    return result;
  }

  private async download(url: string): Promise<ArrayBuffer> {
    let request: http.HttpRequest | null = null;
    try {
      request = http.createHttp();
      const response: http.HttpResponse = await request.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        usingCache: false,
        maxLimit: MAX_PACKAGE_BYTES,
        connectTimeout: 12000,
        readTimeout: 30000
      });
      if (response.responseCode !== 200 || !(response.result instanceof ArrayBuffer) ||
        response.result.byteLength <= 0 || response.result.byteLength > MAX_PACKAGE_BYTES) {
        throw new Error('decoration_download_invalid');
      }
      return response.result;
    } finally {
      if (request !== null) { request.destroy(); }
    }
  }

  private async write(path: string, bytes: ArrayBuffer): Promise<void> {
    const file: fileIo.File = await fileIo.open(path,
      fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
    try {
      let written: number = 0;
      while (written < bytes.byteLength) {
        const count: number = await fileIo.write(file.fd, bytes.slice(written));
        if (count <= 0) { throw new Error('decoration_write_failed'); }
        written += count;
      }
    } finally {
      await fileIo.close(file.fd);
    }
  }

  private async read(path: string, maximum: number): Promise<ArrayBuffer> {
    const file: fileIo.File = await fileIo.open(path, fileIo.OpenMode.READ_ONLY);
    try {
      const size: number = fileIo.statSync(file.fd).size;
      if (size <= 0 || size > maximum) { throw new Error('decoration_file_size'); }
      const bytes: ArrayBuffer = new ArrayBuffer(size);
      const count: number = await fileIo.read(file.fd, bytes);
      if (count !== size) { throw new Error('decoration_file_read'); }
      return bytes;
    } finally {
      await fileIo.close(file.fd);
    }
  }

  private manifestFile(manifest: PackageManifest, role: string): PackageFileRecord | null {
    if (manifest.files instanceof Array) {
      for (let i: number = 0; i < manifest.files.length; i++) {
        if (manifest.files[i].role === role) { return manifest.files[i]; }
      }
    }
    return null;
  }

  private async verifyImage(path: string, record: PackageFileRecord): Promise<void> {
    const bytes: ArrayBuffer = await this.read(path, MAX_PACKAGE_BYTES);
    if (bytes.byteLength !== record.bytes || await this.sha256(bytes) !== record.sha256.toLowerCase()) {
      throw new Error('decoration_checksum');
    }
    const source: image.ImageSource = image.createImageSource(bytes);
    try {
      const info: image.ImageInfo = await source.getImageInfo();
      if (info.size.width <= 0 || info.size.height <= 0) { throw new Error('decoration_image'); }
    } finally {
      await source.release();
    }
  }

  async install(context: common.Context, item: ChatDecorationCatalogItem): Promise<ChatDecorationInstall> {
    const pending: DecorationTicket | null = await this.ticket(item);
    if (pending === null || pending.download_url.length === 0 || pending.file_size !== item.bytes) {
      throw new Error('decoration_ticket');
    }
    let url: string = pending.download_url;
    if (url.startsWith('/')) { url = API_ORIGIN + url; }
    if (!url.startsWith(API_ORIGIN + '/open/v1/entitlements/download/')) {
      throw new Error('decoration_download_origin');
    }
    const root: string = this.directory(context);
    const stagingRoot: string = root + '/staging';
    this.ensureDirectory(root);
    this.ensureDirectory(stagingRoot);
    const stage: string = stagingRoot + '/' + util.generateRandomUUID();
    const zipPath: string = stage + '.zip';
    this.ensureDirectory(stage);
    try {
      const bytes: ArrayBuffer = await this.download(url);
      if (bytes.byteLength !== item.bytes || await this.sha256(bytes) !== item.sha256) {
        throw new Error('decoration_package_checksum');
      }
      await this.write(zipPath, bytes);
      await zlib.decompressFile(zipPath, stage);
      const manifest: PackageManifest =
        JSON.parse(fileIo.readTextSync(stage + '/manifest.json')) as PackageManifest;
      if (manifest.id !== item.id || typeof manifest.version !== 'string' ||
        !/^[0-9A-Za-z._-]{1,32}$/.test(manifest.version)) {
        throw new Error('decoration_manifest');
      }
      const frame: PackageFileRecord | null = this.manifestFile(manifest, 'frame');
      const bubble: PackageFileRecord | null = this.manifestFile(manifest, 'bubble');
      if (frame === null || bubble === null || frame.path !== 'frame.png' || bubble.path !== 'bubble.png') {
        throw new Error('decoration_manifest_files');
      }
      await this.verifyImage(stage + '/' + frame.path, frame);
      await this.verifyImage(stage + '/' + bubble.path, bubble);
      const idRoot: string = root + '/' + item.id;
      this.ensureDirectory(idRoot);
      const destination: string = idRoot + '/' + manifest.version;
      this.removeTree(destination);
      fileIo.renameSync(stage, destination);
      const versions: string[] = fileIo.listFileSync(idRoot);
      for (let i: number = 0; i < versions.length; i++) {
        if (versions[i] !== manifest.version) { this.removeTree(idRoot + '/' + versions[i]); }
      }
      const installed: ChatDecorationInstall = new ChatDecorationInstall();
      installed.id = item.id;
      installed.version = manifest.version;
      installed.root = destination;
      installed.framePath = destination + '/' + frame.path;
      installed.frameUri = fileUri.getUriFromPath(installed.framePath);
      installed.bubblePath = destination + '/' + bubble.path;
      installed.bubbleUri = fileUri.getUriFromPath(installed.bubblePath);
      if (frame.avatarRectHint !== undefined) {
        installed.avatarLeft = frame.avatarRectHint.left;
        installed.avatarTop = frame.avatarRectHint.top;
        installed.avatarWidth = frame.avatarRectHint.width;
        installed.avatarHeight = frame.avatarRectHint.height;
      }
      if (bubble.textColor !== undefined && /^#[0-9A-Fa-f]{6}$/.test(bubble.textColor)) {
        installed.bubbleTextColor = bubble.textColor;
      }
      if (bubble.sliceHintPx !== undefined) {
        installed.sliceLeft = Math.max(0, Math.floor(bubble.sliceHintPx.left));
        installed.sliceRight = Math.max(0, Math.floor(bubble.sliceHintPx.right));
        installed.sliceTop = Math.max(0, Math.floor(bubble.sliceHintPx.top));
        installed.sliceBottom = Math.max(0, Math.floor(bubble.sliceHintPx.bottom));
      }
      xChatActions.saveLocal(context, INSTALL_PREFIX + item.id, JSON.stringify(installed));
      return installed;
    } catch (error) {
      this.removeTree(stage);
      throw error as Error;
    } finally {
      this.removeFile(zipPath);
    }
  }

  installed(context: common.Context, id: string): ChatDecorationInstall | null {
    if (id.length === 0) { return null; }
    try {
      const raw: string = xChatActions.localString(context, INSTALL_PREFIX + id, '');
      if (raw.length === 0) { return null; }
      const value: ChatDecorationInstall = JSON.parse(raw) as ChatDecorationInstall;
      if (value.id !== id || typeof value.framePath !== 'string' || typeof value.bubblePath !== 'string' ||
        !fileIo.accessSync(value.framePath) || !fileIo.accessSync(value.bubblePath)) {
        return null;
      }
      return value;
    } catch (error) {
      return null;
    }
  }

  selection(context: common.Context): ChatDecorationSelection {
    const value: ChatDecorationSelection = new ChatDecorationSelection();
    try {
      const raw: string = xChatActions.localString(context, SELECTION_KEY, '');
      if (raw.length === 0) { return value; }
      const saved: ChatDecorationSelection = JSON.parse(raw) as ChatDecorationSelection;
      if (typeof saved.framePath === 'string' && saved.framePath.length > 0 && fileIo.accessSync(saved.framePath)) {
        value.frameId = typeof saved.frameId === 'string' ? saved.frameId : '';
        value.framePath = saved.framePath;
        value.frameUri = fileUri.getUriFromPath(saved.framePath);
      }
      if (typeof saved.bubblePath === 'string' && saved.bubblePath.length > 0 && fileIo.accessSync(saved.bubblePath)) {
        value.bubbleId = typeof saved.bubbleId === 'string' ? saved.bubbleId : '';
        value.bubblePath = saved.bubblePath;
        value.bubbleUri = fileUri.getUriFromPath(saved.bubblePath);
        value.bubbleTextColor = typeof saved.bubbleTextColor === 'string' &&
          /^#[0-9A-Fa-f]{6}$/.test(saved.bubbleTextColor) ? saved.bubbleTextColor : '#202C26';
        value.sliceLeft = Number.isFinite(saved.sliceLeft) ? saved.sliceLeft : 0;
        value.sliceRight = Number.isFinite(saved.sliceRight) ? saved.sliceRight : 0;
        value.sliceTop = Number.isFinite(saved.sliceTop) ? saved.sliceTop : 0;
        value.sliceBottom = Number.isFinite(saved.sliceBottom) ? saved.sliceBottom : 0;
      }
    } catch (error) {}
    return value;
  }

  apply(context: common.Context, installed: ChatDecorationInstall, role: string): ChatDecorationSelection {
    const value: ChatDecorationSelection = this.selection(context);
    if (role === 'frame') {
      value.frameId = installed.id;
      value.framePath = installed.framePath;
      value.frameUri = installed.frameUri;
    } else if (role === 'bubble') {
      value.bubbleId = installed.id;
      value.bubblePath = installed.bubblePath;
      value.bubbleUri = installed.bubbleUri;
      value.bubbleTextColor = installed.bubbleTextColor;
      value.sliceLeft = installed.sliceLeft;
      value.sliceRight = installed.sliceRight;
      value.sliceTop = installed.sliceTop;
      value.sliceBottom = installed.sliceBottom;
    } else {
      throw new Error('decoration_role');
    }
    xChatActions.saveLocal(context, SELECTION_KEY, JSON.stringify(value));
    this.publish();
    return value;
  }

  clear(context: common.Context, role: string): ChatDecorationSelection {
    const value: ChatDecorationSelection = this.selection(context);
    if (role === 'frame') {
      value.frameId = '';
      value.framePath = '';
      value.frameUri = '';
    } else if (role === 'bubble') {
      value.bubbleId = '';
      value.bubblePath = '';
      value.bubbleUri = '';
      value.bubbleTextColor = '#202C26';
      value.sliceLeft = 0;
      value.sliceRight = 0;
      value.sliceTop = 0;
      value.sliceBottom = 0;
    }
    xChatActions.saveLocal(context, SELECTION_KEY, JSON.stringify(value));
    this.publish();
    return value;
  }

  private publish(): void {
    AppStorage.setOrCreate<number>(CHAT_DECORATION_REVISION_KEY,
      (AppStorage.get<number>(CHAT_DECORATION_REVISION_KEY) ?? 0) + 1);
  }
}

export const chatDecorationService: ChatDecorationService = new ChatDecorationService();
