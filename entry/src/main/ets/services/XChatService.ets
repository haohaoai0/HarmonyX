import { userAvatarRadius, verificationBadgeColor, userVerifiedType, userAvatarShape } from '../utils/UserIdentity';
import { common } from '@kit.AbilityKit';
import hilog from '@ohos.hilog';
import { invoke } from 'libharmonyx_chat.so';
import type { DirectMessage, DmMessage, DmAttachment, DmPage, DmReaction } from '../models/Tweet';
import { XDmParser } from './XDmParser';
import { XPrivateResult, xPrivateClient } from './XPrivateClient';
import { xPrivateStore } from './XPrivateStore';
import { ProxyEntry, ProxySettings, proxyStore } from './ProxyStore';
import { XNotificationParser } from './XNotificationParser';
import { xChatActions } from './XChatActions';
import { ChatMediaItem, ChatMovingPhotoProtocol } from '../utils/ChatMovingPhotoProtocol';
import { xChatGroupAvatar } from './XChatGroupAvatar';

interface XChatPublicKey {
  public_key: string;
  signing_public_key: string;
  identity_public_key_signature: string;
}
interface XChatKeyMetadata { public_key: XChatPublicKey; version: string; }
interface XChatRealmValue { token: string; address: string; public_key?: string; }
interface XChatRealmToken { key: string; value: XChatRealmValue; }
interface XChatBackupConfig {
  key_store_token_map_json: string;
  token_map: XChatRealmToken[];
  max_guess_count?: number;
}
interface XChatKeyRecord {
  public_key_with_metadata: XChatKeyMetadata;
  token_map?: XChatBackupConfig;
}
interface XChatKeyResult { public_keys_with_token_map?: XChatKeyRecord[]; error?: string; }
interface XChatUser {
  rest_id?: string;
  core?: XChatUserCore;
  avatar?: XChatUserAvatar;
  get_public_keys?: XChatKeyResult;
}
interface XChatUserCore { name: string; screen_name: string; }
interface XChatUserAvatar { image_url: string; }
interface XChatUserResult { rest_id: string; result?: XChatUser; }
interface XChatInboxDetail {
  conversation_id?: string;
  participants_results?: XChatUserResult[];
  group_members_results?: XChatUserResult[];
  message_ttl_msec?: string;
  screen_capture_blocking_enabled?: boolean;
  is_muted?: boolean;
  group_metadata?: XChatGroupMetadata;
}
interface XChatGroupMetadata {
  message_ttl_msec?: string;
  screen_capture_blocking_enabled?: boolean;
  group_name?: string;
  group_avatar_url?: string;
}
export interface XChatGroupDisplay { name: string; avatarUrl: string; }
interface XChatInboxRead { latest_mark_conversation_read_event?: Object; }
interface XChatInboxItem {
  conversation_detail?: XChatInboxDetail;
  latest_message_events?: Object;
  latest_conversation_key_change_events?: Object;
  latest_notifiable_message_create_event?: Object;
  latest_non_notifiable_message_create_event?: Object;
  latest_read_events_per_participant?: XChatInboxRead[];
}
export interface XChatConversationInfo { ttl: string; screenBlocked: boolean; muted: boolean; }
interface XChatInbox { items?: XChatInboxItem[]; encoded_message_events?: Object; }
interface XChatConversationPage {
  encoded_message_events?: string[];
  missing_conversation_key_change_events?: string[];
  has_more?: boolean;
}
interface XChatSendResult { encoded_message_event?: string; error_code?: number; }
interface XChatResponseData {
  user_results_by_rest_ids?: XChatUserResult[];
  get_conversation_page?: XChatConversationPage;
  xchat_send_create_message_event?: XChatSendResult;
  xchat_send_message_event?: XChatSendResult;
  get_initial_chat_page?: XChatInbox;
  get_inbox_page?: XChatInbox;
  get_inbox_page_conversation_data?: XChatInbox;
}
interface XChatEnvelope { data?: XChatResponseData; }
interface XChatSigningKey {
  user_id: string;
  public_key_version: string;
  public_key: string;
  identity_public_key: string;
  identity_public_key_signature: string;
}
interface XChatNativeContent {
  content_type?: string;
  text?: string;
  target_message_id?: string;
  new_text?: string;
  emoji?: string;
  replying_to_preview?: XChatReplyPreview;
}
interface XChatReplyPreview {
  sender_id?: string;
  message_text?: string;
  sender_display_name?: string;
  replying_to_message_sequence_id?: string;
  attachments?: XChatNativeAttachment[];
}
interface XChatDeletedEvent { message_ids?: string[]; }
interface XChatNativeMessage {
  id?: string;
  sequenceId?: string;
  conversationId?: string;
  senderId?: string;
  timestampMs?: number;
  text?: string;
  verified?: boolean;
  keyVersion?: string;
  content?: XChatNativeContent;
  type?: string;
  failure?: string;
  event?: XChatDeletedEvent;
  seenUntilId?: string;
  attachments?: XChatNativeAttachment[];
  rawEvent?: string;
}
interface XChatNativeDimensions { width?: number; height?: number; }
interface XChatNativeAttachment {
  attachment_type: string;
  media_hash_key?: string;
  media_type?: string;
  filename?: string;
  url?: string;
  post_url?: string;
  rest_id?: string;
  dimensions?: XChatNativeDimensions;
  duration_millis?: number;
}
export interface XChatNativeData {
  messages?: XChatNativeMessage[];
  encryption?: XChatEventEncryption[];
  errors?: string[];
  unlocked?: boolean;
  conversation_id?: string;
  message_id?: string;
  encoded_message_create_event?: string;
  encoded_message_event?: string;
  encoded_message_event_signature?: string;
  network?: XChatNetworkDiagnostic[];
  conversation_key_version?: string;
  base64_encoded_key_rotation?: string;
  participant_keys?: XChatParticipantKey[];
  action_signatures?: XChatActionSignature[];
  fingerprint?: string;
  changed?: boolean;
  key_version?: string;
  ciphertext?: string;
  text?: string;
  media_bytes?: number;
  media_path?: string;
  valid?: boolean;
}
interface XChatEventEncryption { conversationId: string; encrypted: boolean; }
interface XChatLocalArgs { conversation_id: string; text?: string; key_version?: string; ciphertext?: string; }
interface XChatVerifyArgs { public_key: string; signature: string; payload: string; }
export interface XChatLocalCipher { key_version: string; ciphertext: string; }
interface XChatParticipantKey { user_id: string; encrypted_key: string; public_key_version: string; }
export interface XChatPublicKeyInput { user_id: string; public_key: string; key_version: string; }
export interface XChatActionSignature {
  message_id: string;
  encoded_message_event_detail: string;
  signature: string;
  signature_version: string;
  public_key_version: string;
  signature_payload?: string;
}
interface XChatEventSignature { signature: string; signature_version: string; public_key_version: string; }
interface XChatActionInput { message_id: string; encoded_message_event_detail: string; message_event_signature: XChatEventSignature; }
interface XChatDeleteArgs { conversation_id: string; sequence_ids: string[]; delete_for_all: boolean; }
interface XChatConversationActionArgs { conversation_id: string; sequence_id?: string; }
interface XChatPinChange { old_pin: string; new_pin: string; }
interface XChatFingerprintArgs { public_key: string; signing_key: string; binding: string; }
interface XChatCreateArgs {
  public_keys: XChatPublicKeyInput[];
  conversation_id: string;
  members: string[];
  admins: string[];
  title: string;
}
interface XChatNetworkDiagnostic { host?: string; status?: number; error?: string; }
interface XChatNativeResult { ok: boolean; data?: XChatNativeData; error?: string; }
interface XChatDecryptArgs { events: string[]; signing_keys: XChatSigningKey[]; }
interface XChatUnlockArgs {
  pin: string;
  config: XChatBackupConfig;
  user_id: string;
  version: string;
  public_key: string;
  proxy: string;
}
export interface XChatReplyTarget { sequence_id: string; sender_id: string; text: string; raw_event: string; key_version?: string; }
interface XChatEncryptArgs { conversation_id: string; text: string; attachments?: XChatMediaDescriptor[]; media_key_version?: string; ttl_msec?: number; message_id?: string; reply?: XChatReplyTarget; }
interface XChatReactionArgs { conversation_id: string; sequence_id: string; emoji: string; remove: boolean; }
export interface XChatMediaDescriptor {
  attachment_type: string;
  media_hash_key: string;
  width: number;
  height: number;
  filesize_bytes: number;
  filename: string;
  media_type: number;
  duration_millis?: number;
}
interface XChatMediaArgs { conversation_id: string; input_path: string; output_path: string; key_version?: string; }
export interface XChatMediaCipher { size: number; keyVersion: string; }
interface XChatPendingSend { text: string; payload: XChatNativeData; }

export class XChatPage {
  messages: DmMessage[] = [];
  events: XChatNativeMessage[] = [];
  effects: XChatNativeMessage[] = [];
  hasMore: boolean = false;
  minSequenceId: string = '';
  minKeyVersion: string = '';
  needsUnlock: boolean = false;
  error: string = '';
  transport: string = 'unknown';
}

export class XChatService {
  private attachmentUrl(attachment: XChatNativeAttachment): string {
    const url: string = attachment.url ?? '';
    if (url.length > 0) { return url; }
    const postUrl: string = attachment.post_url ?? '';
    if (postUrl.length > 0) { return postUrl; }
    const restId: string = attachment.rest_id ?? '';
    return attachment.attachment_type === 'Post' && /^\d+$/.test(restId) ? 'https://x.com/i/status/' + restId : '';
  }

  private accountId: string = '';
  private generation: number = 0;
  private unlocked: boolean = false;
  private ownRecord: XChatKeyRecord | null = null;
  private signingKeys: XChatSigningKey[] = [];
  private users: Map<string, XChatUser> = new Map<string, XChatUser>();
  private groups: Map<string, XChatGroupMetadata> = new Map<string, XChatGroupMetadata>();
  private nativeQueue: Promise<void> = Promise.resolve();
  private pendingSends: Map<string, XChatPendingSend> = new Map<string, XChatPendingSend>();
  private keyUsers: string[] = [];
  private keysFetchedAt: number = 0;
  private info: Map<string, XChatConversationInfo> = new Map<string, XChatConversationInfo>();
  private messageCache: Map<string, DmMessage[]> = new Map<string, DmMessage[]>();
  private effectCache: Map<string, XChatNativeMessage> = new Map<string, XChatNativeMessage>();
  private legacyCheckedAt: Map<string, number> = new Map<string, number>();
  private transports: Map<string, string> = new Map<string, string>();

  constructor() {
    xPrivateClient.onSessionChange((): void => { this.clear(); });
  }

  private clear(): void {
    this.generation++;
    this.accountId = '';
    this.unlocked = false;
    this.ownRecord = null;
    this.signingKeys = [];
    this.users.clear();
    this.groups.clear();
    xChatGroupAvatar.clear();
    this.info.clear();
    this.messageCache.clear();
    this.effectCache.clear();
    this.legacyCheckedAt.clear();
    this.transports.clear();
    this.pendingSends.clear();
    this.keyUsers = [];
    this.keysFetchedAt = 0;
    this.callNative('reset', '{}').catch((): void => {});
    this.notifyChanged();
  }

  private notifyChanged(): void {
    AppStorage.setOrCreate<number>('harmonyx.chat_revision',
      (AppStorage.get<number>('harmonyx.chat_revision') ?? 0) + 1);
  }

  private async callNative(method: string, input: string): Promise<XChatNativeResult> {
    const previous: Promise<void> = this.nativeQueue;
    let finish: () => void = (): void => {};
    this.nativeQueue = new Promise<void>((resolve: () => void): void => { finish = resolve; });
    await previous;
    try {
      return JSON.parse(await invoke(method, input)) as XChatNativeResult;
    } finally {
      finish();
    }
  }

  isUnlocked(): boolean { return this.unlocked; }
  async groupNative(method: string, input: string): Promise<XChatNativeData> {
    const generation: number = this.generation;
    const result: XChatNativeResult = await this.callNative(method, input);
    if (generation !== this.generation) { throw new Error('account_changed'); }
    if (!result.ok || result.data === undefined) { throw new Error(result.error ?? 'group_crypto_failed'); }
    return result.data;
  }
  groupPublicKeys(memberIds: string[]): XChatPublicKeyInput[] {
    // Preserve the caller's order: the server derives the pre-change roster
    // from this participant list in the order it receives it, so the order is
    // part of the signed payload it reconstructs.
    const result: XChatPublicKeyInput[] = [];
    for (let index: number = 0; index < memberIds.length; index++) {
      const id: string = memberIds[index];
      const key: XChatSigningKey | undefined = XChatService.latestSigningKey(this.signingKeys, id);
      if (key !== undefined) {
        result.push({ user_id: key.user_id, public_key: key.identity_public_key,
          key_version: key.public_key_version });
      }
    }
    return result;
  }
  signingPublicKey(userId: string): string {
    const record: XChatSigningKey | undefined = XChatService.latestSigningKey(this.signingKeys, userId);
    return record === undefined ? '' : record.public_key;
  }
  // A user can publish several key versions; only the newest one is accepted
  // for new conversation key material.
  private static latestSigningKey(keys: XChatSigningKey[], userId: string): XChatSigningKey | undefined {
    let best: XChatSigningKey | undefined = undefined;
    for (let index: number = 0; index < keys.length; index++) {
      const key: XChatSigningKey = keys[index];
      if (key.user_id !== userId) { continue; }
      if (best === undefined || XChatService.compareIds(key.public_key_version, best.public_key_version) > 0) {
        best = key;
      }
    }
    return best;
  }
  async verifyPayload(publicKey: string, signature: string, payload: string): Promise<boolean> {
    if (publicKey.length === 0 || signature.length === 0) { return false; }
    const args: XChatVerifyArgs = { public_key: publicKey, signature: signature, payload: payload };
    const data: XChatNativeData = await this.groupNative('verifyPayload', JSON.stringify(args));
    return data.valid === true;
  }
  async encryptMetadata(conversationId: string, text: string, keyVersion: string = ''): Promise<XChatLocalCipher> {
    const args: XChatLocalArgs = { conversation_id: conversationId, text: text, key_version: keyVersion };
    const data: XChatNativeData = await this.groupNative('encryptMetadata', JSON.stringify(args));
    if ((data.key_version ?? '').length === 0 || (data.ciphertext ?? '').length === 0) { throw new Error('metadata_encrypt_failed'); }
    return { key_version: data.key_version ?? '', ciphertext: data.ciphertext ?? '' };
  }
  async encryptGroupMedia(conversationId: string, inputPath: string, outputPath: string,
    keyVersion: string): Promise<XChatMediaCipher> {
    const args: XChatMediaArgs = { conversation_id: conversationId, input_path: inputPath, output_path: outputPath, key_version: keyVersion };
    // The rotated group key is required; plain "encryptMedia" always uses the
    // latest activated key and would silently encrypt an avatar under the old one.
    const data: XChatNativeData = await this.groupNative('encryptGroupMedia', JSON.stringify(args));
    return { size: data.media_bytes ?? 0, keyVersion: data.key_version ?? '' };
  }
  hasBackup(): boolean { return this.ownRecord?.token_map !== undefined; }

  conversationInfo(id: string): XChatConversationInfo {
    return this.info.get(id.replace(':', '-')) ?? { ttl: '0', screenBlocked: false, muted: false };
  }
  cachedMessages(id: string): DmMessage[] { return this.messageCache.get(id.replace(':', '-')) ?? []; }
  conversationTransport(id: string): string { return this.transports.get(id.replace(':', '-')) ?? 'unknown'; }
  cachePlaintextMessages(id: string, messages: DmMessage[]): void {
    const key: string = id.replace(':', '-');
    const page: XChatPage = new XChatPage();
    page.messages = messages.filter((message: DmMessage): boolean => message.encrypted === false &&
      (message.keyVersion ?? '').length === 0 && message.conversationId.replace(':', '-') === key);
    if (page.messages.length === 0) { return; }
    this.messageCache.set(key, this.mergeConversation(this.cachedMessages(key), page, key));
    this.rememberTransport(key, 'plaintext'); this.legacyCheckedAt.delete(key);
  }
  private rememberTransport(id: string, transport: string): void {
    if (id.length === 0 || transport === 'unknown') { return; }
    const key: string = id.replace(':', '-');
    if (transport === 'empty' && this.transports.has(key)) { return; }
    if (this.transports.get(key) !== 'encrypted') { this.transports.set(key, transport); }
  }
  setConversationInfo(id: string, info: XChatConversationInfo): void { this.info.set(id.replace(':', '-'), info); }

  async saveNickname(context: common.UIAbilityContext, conversationId: string, nickname: string): Promise<void> {
    if (nickname.length === 0) { xChatActions.saveLocal(context, 'nickname:' + conversationId, ''); return; }
    const generation: number = this.generation;
    const args: XChatLocalArgs = { conversation_id: conversationId, text: nickname };
    const result: XChatNativeResult = await this.callNative('encryptLocal', JSON.stringify(args));
    if (generation !== this.generation) { throw new Error('account_changed'); }
    if (!result.ok || result.data?.ciphertext === undefined || result.data?.key_version === undefined) {
      throw new Error(result.error ?? 'nickname_encrypt_failed');
    }
    const cipher: XChatLocalCipher = { key_version: result.data.key_version, ciphertext: result.data.ciphertext };
    xChatActions.saveLocal(context, 'nickname:' + conversationId, JSON.stringify(cipher));
  }

  async nickname(context: common.UIAbilityContext, conversationId: string): Promise<string> {
    const cipher: string = xChatActions.localString(context, 'nickname:' + conversationId, '');
    if (cipher.length === 0 || !this.unlocked) { return ''; }
    const saved: XChatLocalCipher = JSON.parse(cipher) as XChatLocalCipher;
    const args: XChatLocalArgs = { conversation_id: conversationId, key_version: saved.key_version, ciphertext: saved.ciphertext };
    const result: XChatNativeResult = await this.callNative('decryptLocal', JSON.stringify(args));
    return result.ok ? result.data?.text ?? '' : '';
  }

  lock(): void { this.clear(); }

  async changePin(context: common.UIAbilityContext, oldPin: string, newPin: string): Promise<void> {
    if (!this.unlocked) { throw new Error('locked'); }
    const generation: number = this.generation;
    this.keysFetchedAt = 0;
    await this.prepare(context, this.keyUsers);
    const vpn: boolean = await proxyStore.refreshSystemVpnState();
    const settings: ProxySettings = proxyStore.snapshot();
    const proxy: ProxyEntry | null = !vpn && settings.enabled ? settings.activeProxy() : null;
    const credentials: string = proxy !== null && proxy.username.length > 0 ?
      encodeURIComponent(proxy.username) + ':' + encodeURIComponent(proxy.password) + '@' : '';
    const url: string = proxy === null ? '' : (proxy.isSocks5() ? 'socks5h://' : 'http://') +
      credentials + proxy.host + ':' + proxy.port;
    if (generation !== this.generation || this.ownRecord?.token_map === undefined) { throw new Error('account_changed'); }
    const configured: XChatNativeResult = await this.callNative('recoveryConfig', JSON.stringify({ config: this.ownRecord.token_map, proxy: url }));
    if (generation !== this.generation || !configured.ok) { throw new Error('recovery_config_failed'); }
    const args: XChatPinChange = { old_pin: oldPin, new_pin: newPin };
    let result: XChatNativeResult;
    try { result = await this.callNative('changePin', JSON.stringify(args)); }
    finally { args.old_pin = ''; args.new_pin = ''; }
    if (generation !== this.generation) { throw new Error('account_changed'); }
    if (!result.ok || result.data?.changed !== true) { throw new Error(result.error ?? 'pin_change_unconfirmed'); }
  }

  async fingerprint(userId: string = ''): Promise<string> {
    const generation: number = this.generation;
    const records: XChatSigningKey[] = this.signingKeys.filter((key: XChatSigningKey): boolean => key.user_id === userId);
    records.sort((left: XChatSigningKey, right: XChatSigningKey): number => XChatService.compareIds(left.public_key_version, right.public_key_version));
    const record: XChatSigningKey | undefined = records.pop();
    if (userId.length > 0 && record === undefined) { throw new Error('missing_identity_key'); }
    const args: XChatFingerprintArgs = { public_key: record?.identity_public_key ?? '', signing_key: record?.public_key ?? '', binding: record?.identity_public_key_signature ?? '' };
    const result: XChatNativeResult = await this.callNative('fingerprint', JSON.stringify(args));
    if (generation !== this.generation) { throw new Error('account_changed'); }
    if (!result.ok) { throw new Error(result.error ?? 'locked'); }
    return result.data?.fingerprint ?? '';
  }

  async markRead(conversationId: string, sequenceId: string, context: common.UIAbilityContext): Promise<void> {
    if (sequenceId.length === 0) { throw new Error('missing_read_sequence'); }
    const account: string = xPrivateStore.load(context).cacheIdentity();
    const generation: number = this.generation;
    const args: XChatConversationActionArgs = { conversation_id: conversationId, sequence_id: sequenceId };
    let native: XChatNativeResult = await this.callNative(this.conversationTransport(conversationId) === 'plaintext' ?
      'preparePlainRead' : 'encryptRead', JSON.stringify(args));
    if (generation !== this.generation || account !== xPrivateStore.load(context).cacheIdentity()) { throw new Error('account_changed'); }
    if (!native.ok && (native.error ?? '').indexOf('no cached conversation key') >= 0) {
      await this.conversation(conversationId);
      if (generation !== this.generation || account !== xPrivateStore.load(context).cacheIdentity()) { throw new Error('account_changed'); }
      native = await this.callNative(this.conversationTransport(conversationId) === 'plaintext' ?
        'preparePlainRead' : 'encryptRead', JSON.stringify(args));
      if (generation !== this.generation || account !== xPrivateStore.load(context).cacheIdentity()) { throw new Error('account_changed'); }
    }
    if (!native.ok || native.data === undefined) { throw new Error(native.error ?? 'read_encrypt_failed'); }
    const payload: XChatNativeData = native.data;
    const result: XPrivateResult = payload.encoded_message_event !== undefined ?
      await xPrivateClient.graphql('SendMessageEventMutation', { 'encoded_message_event': payload.encoded_message_event }) :
      await xPrivateClient.graphql('SendMessageCreateMutation', {
      'conversation_id': payload.conversation_id ?? conversationId, 'message_id': payload.message_id ?? '',
      'encoded_message_create_event': payload.encoded_message_create_event ?? '',
      'encoded_message_event_signature': payload.encoded_message_event_signature ?? ''
    });
    if (generation !== this.generation || account !== xPrivateStore.load(context).cacheIdentity()) { throw new Error('account_changed'); }
    if (!result.ok) { throw new Error('read_http_' + result.status); }
    const data: XChatResponseData | undefined = (JSON.parse(result.body) as XChatEnvelope).data;
    const event: string = (payload.encoded_message_event !== undefined ? data?.xchat_send_message_event :
      data?.xchat_send_create_message_event)?.encoded_message_event ?? '';
    if (event.length === 0) { throw new Error('read_unconfirmed'); }
    const page: XChatPage = await this.decode([event], conversationId);
    if (!page.events.some((e: XChatNativeMessage): boolean => e.verified === true && e.id === payload.message_id &&
      e.senderId === xPrivateClient.viewerId() && (e.content?.content_type === 'MarkRead' ||
        (e.type === 'read' && e.seenUntilId === sequenceId)))) { throw new Error('read_unconfirmed'); }
    if (generation !== this.generation || account !== xPrivateStore.load(context).cacheIdentity()) { throw new Error('account_changed'); }
    xChatActions.saveLocal(context, 'read_state:' + conversationId, 'read:' + sequenceId);
  }

  async deleteConversation(conversationId: string): Promise<void> {
    const generation: number = this.generation;
    const args: XChatConversationActionArgs = { conversation_id: conversationId };
    const native: XChatNativeResult = await this.callNative('prepareConversationDelete', JSON.stringify(args));
    if (generation !== this.generation) { throw new Error('account_changed'); }
    if (!native.ok || (native.data?.action_signatures ?? []).length === 0) { throw new Error(native.error ?? 'delete_signature_failed'); }
    await xChatActions.action('ConversationDeleteMutation', {
      'conversation_id': conversationId, 'action_signatures': XChatService.actionInputs(native.data?.action_signatures ?? [])
    }, 'xchat_delete_conversation');
    if (generation !== this.generation) { throw new Error('account_changed'); }
    const key: string = conversationId.replace(':', '-');
    this.messageCache.delete(key);
    this.transports.delete(key);
    this.legacyCheckedAt.delete(key);
    this.pendingSends.delete(conversationId);
    this.effectCache.forEach((event: XChatNativeMessage, id: string): void => {
      if ((event.conversationId ?? '').replace(':', '-') === key) { this.effectCache.delete(id); }
    });
    this.notifyChanged();
  }

  async deleteMessages(conversationId: string, sequenceIds: string[], forEveryone: boolean = false): Promise<XChatPage> {
    if (sequenceIds.length === 0 || sequenceIds.some((id: string): boolean => id.length === 0)) { throw new Error('missing_delete_sequence'); }
    const generation: number = this.generation;
    const args: XChatDeleteArgs = {
      conversation_id: conversationId, sequence_ids: sequenceIds, delete_for_all: forEveryone
    };
    const native: XChatNativeResult = await this.callNative('prepareDelete', JSON.stringify(args));
    if (generation !== this.generation) { throw new Error('account_changed'); }
    if (!native.ok || native.data?.action_signatures === undefined) { throw new Error(native.error ?? 'delete_signature_failed'); }
    await xChatActions.action('DeleteMessageMutation', {
      'conversation_id': conversationId, 'sequence_ids': sequenceIds,
      'delete_message_action': forEveryone ? 'DeleteForAll' : 'DeleteForSelf',
      'action_signatures': XChatService.actionInputs(native.data.action_signatures)
    }, 'xchat_delete_messages');
    if (generation !== this.generation) { throw new Error('account_changed'); }
    const deleted: XChatNativeMessage = { type: 'deleted', conversationId: conversationId, event: { message_ids: sequenceIds } };
    this.rememberEffects([deleted]);
    const page: XChatPage = new XChatPage(); page.events = [deleted];
    this.messageCache.set(conversationId.replace(':', '-'), this.mergeConversation(this.cachedMessages(conversationId), page, conversationId));
    this.notifyChanged();
    return page;
  }

  mergeConversation(existing: DmMessage[], page: XChatPage, conversationId: string): DmMessage[] {
    // A fetch can finish after deletion with a page decoded before the delete.
    // Apply the current confirmed effects when updating the visible messages.
    const key: string = conversationId.replace(':', '-');
    page.effects = page.effects.concat(Array.from(this.effectCache.values()).filter((event: XChatNativeMessage): boolean =>
      (event.conversationId ?? '').replace(':', '-') === key));
    return XChatService.merge(existing, page);
  }

  async createGroup(context: common.UIAbilityContext, members: string[], title: string): Promise<string> {
    await this.prepare(context, members);
    if (!this.unlocked) { throw new Error('locked'); }
    const generation: number = this.generation;
    const initialized: XPrivateResult = await xPrivateClient.graphql('InitializeGroupConversationMutation', {});
    if (generation !== this.generation) { throw new Error('account_changed'); }
    if (!initialized.ok) { throw new Error('group_initialize_failed'); }
    const root: Record<string, Object> = JSON.parse(initialized.body) as Record<string, Object>;
    const data: Record<string, Object> = root['data'] as Record<string, Object>;
    const created: Record<string, Object> = data['xchat_initialize_group'] as Record<string, Object>;
    const id: Record<string, Object> | undefined = created?.['conversation_id'] as Record<string, Object> | undefined;
    const conversationId: string = (id?.['rest_id'] ?? id?.['id'] ?? '') as string;
    if (conversationId.length === 0) { throw new Error('group_initialize_unconfirmed'); }
    const all: string[] = [xPrivateClient.viewerId()].concat(members.filter((id: string): boolean => id !== xPrivateClient.viewerId()));
    const keys: XChatPublicKeyInput[] = this.signingKeys.filter((key: XChatSigningKey): boolean => all.indexOf(key.user_id) >= 0)
      .map((key: XChatSigningKey): XChatPublicKeyInput => ({ user_id: key.user_id,
        public_key: key.identity_public_key, key_version: key.public_key_version }));
    const args: XChatCreateArgs = { public_keys: keys, conversation_id: conversationId,
      members: all, admins: [xPrivateClient.viewerId()], title: title };
    const native: XChatNativeResult = await this.callNative('prepareGroup', JSON.stringify(args));
    if (generation !== this.generation) { throw new Error('account_changed'); }
    if (!native.ok || native.data === undefined) { throw new Error(native.error ?? 'group_sign_failed'); }
    const payload: XChatNativeData = native.data;
    const participants: Record<string, Object>[] = (payload.participant_keys ?? [])
      .map((key: XChatParticipantKey): Record<string, Object> => ({ 'user_id': key.user_id,
        'encrypted_conversation_key': key.encrypted_key, 'public_key_version': key.public_key_version }));
    const result: XPrivateResult = await xPrivateClient.graphql('CreateGroupConversationMutation', {
      'conversation_id': conversationId, 'admin_user_ids': [xPrivateClient.viewerId()],
      'member_user_ids': all, 'conversation_key_version': payload.conversation_key_version ?? '',
      'participants': participants, 'action_signatures': XChatService.actionInputs(payload.action_signatures ?? []), 'title': title
    });
    if (generation !== this.generation) { throw new Error('account_changed'); }
    if (!result.ok) { throw new Error('group_http_' + result.status); }
    const response: Record<string, Object> = JSON.parse(result.body) as Record<string, Object>;
    const responseData: Record<string, Object> = response['data'] as Record<string, Object>;
    const group: Record<string, Object> | undefined = responseData?.['xchat_create_group'] as Record<string, Object> | undefined;
    if (group?.['conversation_key_change_sequence_id'] === undefined) { throw new Error('group_create_unconfirmed'); }
    this.notifyChanged();
    return conversationId;
  }

  private static actionInputs(signatures: XChatActionSignature[]): XChatActionInput[] {
    return signatures.map((signature: XChatActionSignature): XChatActionInput => ({
      message_id: signature.message_id, encoded_message_event_detail: signature.encoded_message_event_detail,
      message_event_signature: { signature: signature.signature, signature_version: signature.signature_version,
        public_key_version: signature.public_key_version }
    }));
  }

  private async initializeDirect(conversationId: string): Promise<void> {
    const ids: string[] = conversationId.replace(':', '-').split('-');
    if (ids.length !== 2 || ids.indexOf(xPrivateClient.viewerId()) < 0) { throw new Error('missing_conversation_key'); }
    const generation: number = this.generation;
    const keys: XChatPublicKeyInput[] = this.signingKeys.filter((key: XChatSigningKey): boolean => ids.indexOf(key.user_id) >= 0)
      .map((key: XChatSigningKey): XChatPublicKeyInput => ({ user_id: key.user_id,
        public_key: key.identity_public_key, key_version: key.public_key_version }));
    const args: XChatCreateArgs = { public_keys: keys, conversation_id: '', members: [], admins: [], title: '' };
    const native: XChatNativeResult = await this.callNative('prepareConversation', JSON.stringify(args));
    if (generation !== this.generation) { throw new Error('account_changed'); }
    if (!native.ok || native.data === undefined) { throw new Error(native.error ?? 'conversation_sign_failed'); }
    const payload: XChatNativeData = native.data;
    const participants: Record<string, Object>[] = (payload.participant_keys ?? [])
      .map((key: XChatParticipantKey): Record<string, Object> => ({ 'user_id': key.user_id,
        'encrypted_conversation_key': key.encrypted_key, 'public_key_version': key.public_key_version }));
    await xChatActions.action('AddEncryptedConversationKeysMutation', {
      'conversation_id': payload.conversation_id ?? conversationId,
      'conversation_key_version': payload.conversation_key_version ?? '', 'participants': participants,
      'action_signatures': XChatService.actionInputs(payload.action_signatures ?? [])
    }, 'xchat_add_encrypted_conversation_key');
    if (generation !== this.generation) { throw new Error('account_changed'); }
    await this.conversation(conversationId);
  }

  async processMedia(conversationId: string, inputPath: string, outputPath: string,
    keyVersion: string = ''): Promise<XChatMediaCipher> {
    const generation: number = this.generation;
    const args: XChatMediaArgs = { conversation_id: conversationId, input_path: inputPath,
      output_path: outputPath, key_version: keyVersion };
    let result: XChatNativeResult = await this.callNative(keyVersion.length > 0 ? 'decryptMedia' : 'encryptMedia', JSON.stringify(args));
    if (keyVersion.length === 0 && !result.ok && (result.error ?? '').indexOf('missing_conversation_key') >= 0) {
      await this.conversation(conversationId);
      result = await this.callNative('encryptMedia', JSON.stringify(args));
      if (!result.ok && (result.error ?? '').indexOf('missing_conversation_key') >= 0) {
        await this.initializeDirect(conversationId);
        result = await this.callNative('encryptMedia', JSON.stringify(args));
      }
    }
    if (generation !== this.generation) { throw new Error('account_changed'); }
    if (!result.ok) { throw new Error(result.error ?? 'media_crypto_failed'); }
    return { size: result.data?.media_bytes ?? 0, keyVersion: result.data?.key_version ?? '' };
  }

  cacheInboxProfiles(context: common.UIAbilityContext, body: string, viewerId: string): void {
    if (viewerId !== xPrivateClient.viewerId()) { return; }
    const identity: string = xPrivateStore.load(context).cacheIdentity();
    if (identity !== this.accountId) { this.clear(); this.accountId = identity; }
    const data: XChatResponseData | undefined = (JSON.parse(body) as XChatEnvelope).data;
    const items: XChatInboxItem[] = (data?.get_initial_chat_page ?? data?.get_inbox_page ?? data?.get_inbox_page_conversation_data)?.items ?? [];
    for (let i: number = 0; i < items.length; i++) {
      const detail: XChatInboxDetail | undefined = items[i].conversation_detail;
      if (detail?.conversation_id !== undefined) {
        if (detail.group_metadata !== undefined) { this.groups.set(detail.conversation_id.replace(':', '-'), detail.group_metadata); }
        this.info.set(detail.conversation_id.replace(':', '-'), {
          ttl: detail.group_metadata?.message_ttl_msec ?? detail.message_ttl_msec ?? '0',
          screenBlocked: detail.group_metadata?.screen_capture_blocking_enabled ?? detail.screen_capture_blocking_enabled ?? false,
          muted: detail.is_muted ?? false
        });
      }
      const participants: XChatUserResult[] = (detail?.participants_results ?? [])
        .concat(detail?.group_members_results ?? []);
      for (let n: number = 0; n < participants.length; n++) {
        const profile: XChatUser | undefined = participants[n].result;
        if (profile !== undefined) { this.users.set(participants[n].rest_id, profile); }
      }
    }
  }

  async decryptInbox(context: common.UIAbilityContext, body: string,
    rows: DirectMessage[]): Promise<DirectMessage[]> {
    for (let i: number = 0; i < rows.length; i++) {
      rows[i].hidden = xChatActions.localBoolean(context, 'hidden:' + (rows[i].conversationId ?? ''), false);
      if (rows[i].group === true && rows[i].from.length === 0) { rows[i].from = context.resourceManager.getStringSync($r('app.string.chat_groups')); }
    }
    if (!this.unlocked) { return rows; }
    const generation: number = this.generation;
    const ids: string[] = [];
    for (let i: number = 0; i < rows.length; i++) {
      const members: string[] = rows[i].participantIds ?? [];
      for (let n: number = 0; n < members.length; n++) {
        if (ids.indexOf(members[n]) < 0) { ids.push(members[n]); }
      }
    }
    await this.prepare(context, ids);
    if (generation !== this.generation) { throw new Error('account_changed'); }
    const data: XChatResponseData | undefined = (JSON.parse(body) as XChatEnvelope).data;
    const inbox: XChatInbox | undefined = data?.get_initial_chat_page ?? data?.get_inbox_page;
    const items: XChatInboxItem[] = inbox?.items ?? [];
    let events: string[] = XChatService.encodedEvents(inbox?.encoded_message_events);
    for (let i: number = 0; i < items.length; i++) {
      const item: XChatInboxItem = items[i];
      events = events.concat(XChatService.encodedEvents(item.latest_conversation_key_change_events),
        XChatService.encodedEvents(item.latest_message_events),
        XChatService.encodedEvents(item.latest_notifiable_message_create_event),
        XChatService.encodedEvents(item.latest_non_notifiable_message_create_event));
      const readEvents: XChatInboxRead[] = item.latest_read_events_per_participant ?? [];
      for (let n: number = 0; n < readEvents.length; n++) {
        events = events.concat(XChatService.encodedEvents(readEvents[n].latest_mark_conversation_read_event));
      }
    }
    const decoded: XChatPage = await this.decode(events, '');
    const messages: DmMessage[] = XChatService.merge([], decoded);
    const latest: Map<string, DmMessage> = new Map<string, DmMessage>();
    for (let i: number = 0; i < messages.length; i++) {
      const message: DmMessage = messages[i];
      const conversation: string = message.conversationId.replace(':', '-');
      const previous: DmMessage | undefined = latest.get(conversation);
      if (previous === undefined || XChatService.compareIds(message.sequenceId ?? '', previous.sequenceId ?? '') > 0) {
        latest.set(conversation, message);
      }
    }
    for (let i: number = 0; i < rows.length; i++) {
      const id: string = rows[i].conversationId ?? '';
      if (rows[i].group === true) {
        const name: string = await this.decryptMetadata(id, rows[i].groupNameCipher ?? '');
        const rawAvatar: string = rows[i].groupAvatarCipher ?? '';
        const avatar: string = /^https:\/\//i.test(rawAvatar) ? rawAvatar : await this.decryptMetadata(id, rawAvatar);
        if (generation !== this.generation) { throw new Error('account_changed'); }
        if (name.length > 0) { rows[i].from = name; }
        if (/^https:\/\//.test(avatar)) {
          rows[i].avatarUrl = await this.resolveGroupAvatar(context, id, avatar);
          if (generation !== this.generation) { throw new Error('account_changed'); }
        }
      }
      let message: DmMessage | undefined = latest.get(id.replace(':', '-'));
      if (message === undefined && id.length > 0 && (rows[i].latestSequenceId ?? '').length > 0) {
        const legacy: DmMessage[] = await this.legacyConversation(id);
        if (generation !== this.generation) { throw new Error('account_changed'); }
        message = legacy.length > 0 ? legacy[legacy.length - 1] : undefined;
      }
      if (message === undefined) { continue; }
      rows[i].preview = message.text.length > 0 ? message.text : context.resourceManager.getStringSync(
        ChatMovingPhotoProtocol.group(message.attachments ?? []).some((item: ChatMediaItem): boolean => item.video !== undefined) ?
          $r('app.string.chat_moving_photo') : (message.attachments?.[0]?.mediaType ?? 5) === 4 ? $r('app.string.chat_voice_messages') :
          (message.attachments?.[0]?.mediaType ?? 5) === 3 ? $r('app.string.chat_video') :
            (message.attachments?.[0]?.mediaType ?? 5) <= 2 ? $r('app.string.chat_photos') : $r('app.string.chat_documents'));
      rows[i].time = message.time;
      rows[i].timestampMs = message.timestampMs;
      rows[i].latestSequenceId = message.sequenceId ?? rows[i].latestSequenceId;
      const read: XChatNativeMessage | undefined = decoded.events.filter((event: XChatNativeMessage): boolean =>
        event.type === 'read' && event.senderId === xPrivateClient.viewerId() &&
        (event.conversationId ?? '').replace(':', '-') === (rows[i].conversationId ?? '').replace(':', '-')).pop();
      if (message.outgoing) { rows[i].unread = 0; }
      else if (read !== undefined) { rows[i].unread = XChatService.compareIds(message.sequenceId ?? '', read.seenUntilId ?? '') > 0 ? 1 : 0; }
      rows[i].hidden = xChatActions.localBoolean(context, 'hidden:' + (rows[i].conversationId ?? ''), false);
      const nickname: string = await this.nickname(context, rows[i].conversationId ?? '');
      if (generation !== this.generation) { throw new Error('account_changed'); }
      if (nickname.length > 0) { rows[i].from = nickname; }
    }
    rows.sort((a: DirectMessage, b: DirectMessage): number => (b.timestampMs ?? 0) - (a.timestampMs ?? 0));
    hilog.info(0xFF00, 'HarmonyX-Chat', 'inbox events=%{public}d conversations=%{public}d previews=%{public}d',
      events.length, rows.length, latest.size);
    return rows;
  }

  async groupDisplay(conversationId: string, context?: common.UIAbilityContext): Promise<XChatGroupDisplay> {
    const metadata: XChatGroupMetadata | undefined = this.groups.get(conversationId.replace(':', '-'));
    const name: string = await this.decryptMetadata(conversationId, metadata?.group_name ?? '');
    const rawAvatar: string = metadata?.group_avatar_url ?? '';
    const avatar: string = /^https:\/\//i.test(rawAvatar) ? rawAvatar : await this.decryptMetadata(conversationId, rawAvatar);
    return { name: name, avatarUrl: /^https:\/\//.test(avatar) ?
      context === undefined ? avatar : await this.resolveGroupAvatar(context, conversationId, avatar) : '' };
  }

  async resolveGroupAvatar(context: common.UIAbilityContext, conversationId: string, url: string): Promise<string> {
    try {
      return await xChatGroupAvatar.resolve(context, conversationId, url, async (inputPath: string, outputPath: string): Promise<void> => {
        const args: XChatMediaArgs = { conversation_id: conversationId, input_path: inputPath, output_path: outputPath };
        await this.groupNative('decryptMetadataFile', JSON.stringify(args));
      });
    } catch (error) {
      hilog.warn(0xFF00, 'HarmonyX-Chat', 'group avatar unavailable: %{public}s', (error as Error).message);
      return '';
    }
  }

  async decryptMetadata(conversationId: string, ciphertext: string): Promise<string> {
    if (ciphertext.length === 0) { return ''; }
    const generation: number = this.generation;
    const args: XChatLocalArgs = { conversation_id: conversationId, ciphertext: ciphertext };
    const result: XChatNativeResult = await this.callNative('decryptMetadata', JSON.stringify(args));
    if (generation !== this.generation) { throw new Error('account_changed'); }
    return result.ok ? result.data?.text ?? '' : '';
  }

  private async legacyConversation(conversationId: string): Promise<DmMessage[]> {
    const id: string = conversationId.replace(':', '-');
    const cache: DmMessage[] = this.cachedMessages(id).filter((message: DmMessage): boolean =>
      (message.keyVersion ?? '').length === 0);
    if (Date.now() - (this.legacyCheckedAt.get(id) ?? 0) < 60000) { return cache; }
    const generation: number = this.generation;
    try {
      const result: XPrivateResult = await xPrivateClient.rest('GET', '/1.1/dm/conversation/' + encodeURIComponent(id) +
        '.json?dm_users=true&include_groups=true&include_entities=true&count=100', {});
      if (generation !== this.generation) { throw new Error('account_changed'); }
      if (!result.ok) { return cache; }
      // Only plaintext supplied by the authenticated legacy endpoint is eligible.
      // Unsigned encrypted XChat events still go through strict XDK verification.
      const parsed: DmPage | null = XDmParser.parseConversation(result.body, id, xPrivateClient.viewerId());
      if (parsed === null) { return cache; }
      this.legacyCheckedAt.set(id, Date.now());
      const messages: DmMessage[] = (parsed?.messages ?? []).filter((message: DmMessage): boolean =>
        message.encrypted === false && message.text.length > 0 && message.conversationId.replace(':', '-') === id);
      const page: XChatPage = new XChatPage(); page.messages = messages;
      this.messageCache.set(id, this.mergeConversation(this.cachedMessages(id), page, id));
      this.rememberTransport(id, messages.length > 0 ? 'plaintext' : 'empty');
      return this.mergeConversation([], page, id);
    } catch (error) { if (generation !== this.generation) { throw new Error('account_changed'); } return cache; }
  }

  private static encodedEvents(value: Object | undefined): string[] {
    if (value === undefined || value === null) { return []; }
    if (typeof value === 'string') { return (value as string).length > 0 ? [value as string] : []; }
    if (value instanceof Array) {
      const items: Object[] = value as Object[];
      let events: string[] = [];
      for (let i: number = 0; i < items.length; i++) { events = events.concat(XChatService.encodedEvents(items[i])); }
      return events;
    }
    const event: Record<string, Object> = value as Record<string, Object>;
    return XChatService.encodedEvents(event['encoded_message_event'] ?? event['encoded_message_events'] ?? event['events']);
  }

  async prepare(context: common.UIAbilityContext, participantIds: string[]): Promise<void> {
    xPrivateClient.load(context);
    const identity: string = xPrivateStore.load(context).cacheIdentity();
    if (identity !== this.accountId) {
      this.clear();
      this.accountId = identity;
    }
    const generation: number = this.generation;
    const ids: string[] = [xPrivateClient.viewerId()];
    for (let i: number = 0; i < participantIds.length; i++) {
      if (ids.indexOf(participantIds[i]) < 0) { ids.push(participantIds[i]); }
    }
    if (ids[0].length === 0) { throw new Error('no_session'); }
    if (Date.now() - this.keysFetchedAt < 60000 &&
      ids.every((id: string): boolean => this.keyUsers.indexOf(id) >= 0)) { return; }
    // The private client reads participant keys through GetPublicKeysQuery; the
    // legacy GetPublicKeys operation reports identity keys the server no longer
    // accepts for group key material.
    const result: XPrivateResult = await xPrivateClient.graphql('GetPublicKeysQuery', {
      'ids': ids, 'include_juicebox_tokens': true
    });
    if (generation !== this.generation) { throw new Error('account_changed'); }
    if (!result.ok) { throw new Error('public_keys_http_' + result.status.toString()); }
    const envelope: XChatEnvelope = JSON.parse(result.body) as XChatEnvelope;
    const users: XChatUserResult[] = envelope.data?.user_results_by_rest_ids ?? [];
    if (users.length === 0) { throw new Error('public_keys_unavailable'); }
    const keys: XChatSigningKey[] = [];
    for (let i: number = 0; i < users.length; i++) {
      const user: XChatUser | undefined = users[i].result;
      if (user === undefined) { continue; }
      const profile: XChatUser | undefined = this.users.get(users[i].rest_id);
      if (user.core === undefined) { user.core = profile?.core; }
      if (user.avatar === undefined) { user.avatar = profile?.avatar; }
      this.users.set(users[i].rest_id, user);
      const records: XChatKeyRecord[] = user.get_public_keys?.public_keys_with_token_map ?? [];
      for (let n: number = 0; n < records.length; n++) {
        const record: XChatKeyRecord = records[n];
        const metadata: XChatKeyMetadata = record.public_key_with_metadata;
        keys.push({
          user_id: users[i].rest_id,
          public_key_version: metadata.version,
          public_key: metadata.public_key.signing_public_key,
          identity_public_key: metadata.public_key.public_key,
          identity_public_key_signature: metadata.public_key.identity_public_key_signature
        });
        if (users[i].rest_id === xPrivateClient.viewerId() && record.token_map !== undefined &&
          (this.ownRecord === null || XChatService.compareIds(metadata.version,
            this.ownRecord.public_key_with_metadata.version) >= 0)) {
          this.ownRecord = record;
        }
      }
    }
    this.signingKeys = keys;
    this.keyUsers = ids;
    this.keysFetchedAt = Date.now();
    hilog.info(0xFF00, 'HarmonyX-Chat', 'keys users=%{public}d versions=%{public}d recovery=%{public}s',
      users.length, keys.length, this.ownRecord === null ? 'unavailable' : 'available');
  }

  async unlock(pin: string): Promise<void> {
    const record: XChatKeyRecord | null = this.ownRecord;
    if (record === null || record.token_map === undefined) { throw new Error('keys_not_registered'); }
    const generation: number = this.generation;
    const metadata: XChatKeyMetadata = record.public_key_with_metadata;
    const systemVpnActive: boolean = await proxyStore.refreshSystemVpnState();
    if (generation !== this.generation) { throw new Error('account_changed'); }
    const settings: ProxySettings = proxyStore.snapshot();
    const proxy: ProxyEntry | null = !systemVpnActive && settings.enabled ? settings.activeProxy() : null;
    let proxyUrl: string = '';
    if (proxy !== null) {
      const credentials: string = proxy.username.length > 0 ?
        encodeURIComponent(proxy.username) + ':' + encodeURIComponent(proxy.password) + '@' : '';
      proxyUrl = (proxy.isSocks5() ? 'socks5h://' : 'http://') + credentials + proxy.host + ':' + proxy.port.toString();
    }
    hilog.info(0xFF00, 'HarmonyX-Chat', 'recovery proxy=%{public}s',
      systemVpnActive ? 'system-vpn' : (proxy === null ? 'direct' : (proxy.isSocks5() ? 'socks5' : 'http')));
    const args: XChatUnlockArgs = {
      pin: pin, config: record.token_map, user_id: xPrivateClient.viewerId(),
      version: metadata.version, public_key: metadata.public_key.public_key, proxy: proxyUrl
    };
    let result: XChatNativeResult;
    try { result = await this.callNative('unlock', JSON.stringify(args)); }
    finally { args.pin = ''; }
    if (generation !== this.generation) { throw new Error('account_changed'); }
    if (!result.ok) {
      // SDK recovery errors contain categories and attempt counts, never PINs or keys.
      hilog.warn(0xFF00, 'HarmonyX-Chat', 'unlock failed: %{public}s', result.error ?? 'unlock_failed');
      const diagnostic: XChatNativeResult = await this.callNative('diagnostics', '{}');
      if (diagnostic.ok) {
        hilog.warn(0xFF00, 'HarmonyX-Chat', 'recovery network: %{public}s',
          JSON.stringify(diagnostic.data?.network ?? []));
      }
      throw new Error(result.error ?? 'unlock_failed');
    }
    this.unlocked = true;
    this.notifyChanged();
  }

  async conversation(conversationId: string, sequenceId: string = '', keyVersion: string = ''): Promise<XChatPage> {
    const generation: number = this.generation;
    const querySettings: Record<string, Object> = { 'conversation_event_limit': 50 };
    const result: XPrivateResult = await xPrivateClient.graphql('GetConversationPageQuery', {
      'conversation_id': conversationId,
      'min_local_sequence_id': sequenceId.length > 0 ? sequenceId : '9223372036854775807',
      'min_conversation_key_version': keyVersion.length > 0 ? keyVersion : '9223372036854775807',
      'query_settings': querySettings
    });
    if (generation !== this.generation) { throw new Error('account_changed'); }
    if (!result.ok) {
      const legacy: DmMessage[] = await this.legacyConversation(conversationId);
      if (legacy.length === 0) { throw new Error('conversation_http_' + result.status.toString()); }
      const fallback: XChatPage = new XChatPage(); fallback.messages = legacy;
      fallback.transport = this.conversationTransport(conversationId); return fallback;
    }
    const envelope: XChatEnvelope = JSON.parse(result.body) as XChatEnvelope;
    const page: XChatConversationPage | undefined = envelope.data?.get_conversation_page;
    if (page === undefined) {
      const fallback: XChatPage = new XChatPage(); fallback.messages = await this.legacyConversation(conversationId);
      fallback.transport = this.conversationTransport(conversationId);
      if (fallback.messages.length === 0 && fallback.transport !== 'empty') { throw new Error('conversation_unavailable'); }
      return fallback;
    }
    const events: string[] = page.missing_conversation_key_change_events ?? [];
    const messages: string[] = page.encoded_message_events ?? [];
    const all: string[] = events.concat(messages);
    const decoded: XChatPage = await this.decode(all, conversationId);
    hilog.info(0xFF00, 'HarmonyX-Chat', 'events=%{public}d messages=%{public}d locked=%{public}s',
      all.length, decoded.messages.length, this.unlocked ? 'false' : 'true');
    decoded.hasMore = page.has_more ?? false;
    if (sequenceId.length === 0 && (decoded.messages.length === 0 || !this.unlocked)) {
      const legacyPage: XChatPage = new XChatPage();
      legacyPage.messages = await this.legacyConversation(conversationId);
      // Keep readable history when some newer encrypted messages remain locked.
      decoded.messages = XChatService.merge(legacyPage.messages, decoded);
    }
    if (all.length === 0 && decoded.messages.length === 0) { this.rememberTransport(conversationId, 'empty'); }
    decoded.transport = this.conversationTransport(conversationId);
    this.messageCache.set(conversationId.replace(':', '-'), this.mergeConversation(this.cachedMessages(conversationId), decoded, conversationId));
    return decoded;
  }

  private rememberEffects(events: XChatNativeMessage[]): void {
    events.forEach((event: XChatNativeMessage): void => {
      const conversation: string = (event.conversationId ?? '').replace(':', '-');
      const kind: string = event.content?.content_type ?? event.type ?? '';
      const targets: string[] = kind === 'deleted' ? event.event?.message_ids ?? [] :
        (kind === 'Reaction' || kind === 'ReactionRemoved' || kind === 'Edit') ? [event.content?.target_message_id ?? ''] :
          kind === 'read' ? [event.senderId ?? ''] : [];
      targets.forEach((target: string): void => {
        const key: string = conversation + ':' + (kind === 'ReactionRemoved' ? 'Reaction' : kind) + ':' + target +
          (kind === 'Reaction' || kind === 'ReactionRemoved' ? ':' + (event.senderId ?? '') + ':' + (event.content?.emoji ?? '') : '');
        const previous: XChatNativeMessage | undefined = this.effectCache.get(key);
        if (previous === undefined || kind === 'deleted' || XChatService.compareIds(
          kind === 'read' ? event.seenUntilId ?? '' : event.sequenceId ?? '',
          kind === 'read' ? previous.seenUntilId ?? '' : previous.sequenceId ?? '') > 0) { this.effectCache.set(key, event); }
      });
    });
  }

  private async decode(events: string[], conversationId: string): Promise<XChatPage> {
    const generation: number = this.generation;
    const args: XChatDecryptArgs = { events: events, signing_keys: this.signingKeys };
    const result: XChatNativeResult = await this.callNative('decrypt', JSON.stringify(args));
    if (generation !== this.generation) { throw new Error('account_changed'); }
    if (!result.ok) { throw new Error(result.error ?? 'decode_failed'); }
    const page: XChatPage = new XChatPage();
    page.events = result.data?.messages ?? [];
    const encryption: XChatEventEncryption[] = result.data?.encryption ?? [];
    encryption.forEach((event: XChatEventEncryption): void => {
      this.rememberTransport(event.conversationId, event.encrypted ? 'encrypted' : 'plaintext');
    });
    page.events.forEach((event: XChatNativeMessage): void => {
      if (event.type === 'keyChange' || (event.keyVersion ?? '').length > 0) {
        this.rememberTransport(event.conversationId ?? '', 'encrypted');
      } else if (event.content?.content_type === 'Text') { this.rememberTransport(event.conversationId ?? '', 'plaintext'); }
    });
    page.transport = this.conversationTransport(conversationId);
    page.needsUnlock = !this.unlocked && page.transport === 'encrypted' && (result.data?.errors?.length ?? 0) > 0;
    if (!page.needsUnlock && (result.data?.errors?.length ?? 0) > 0) { page.error = 'some_messages_unavailable'; }
    for (let i: number = 0; i < page.events.length; i++) {
      const event: XChatNativeMessage = page.events[i];
      const eventConversation: string = event.conversationId ?? '';
      if (conversationId.length > 0 &&
        eventConversation.replace(':', '-') !== conversationId.replace(':', '-')) { continue; }
      const sequence: string = event.sequenceId ?? '';
      if (sequence.length > 0 && (page.minSequenceId.length === 0 ||
        XChatService.compareIds(sequence, page.minSequenceId) < 0)) {
        page.minSequenceId = sequence;
        page.minKeyVersion = event.keyVersion ?? '';
      }
      if (event.content?.content_type !== 'Text') { continue; }
      const sender: string = event.senderId ?? '';
      const user: XChatUser | undefined = this.users.get(sender);
      const timestamp: number = event.timestampMs ?? 0;
      const preview: XChatReplyPreview | undefined = event.content?.replying_to_preview;
      const attachments: DmAttachment[] = (event.attachments ?? []).map((attachment: XChatNativeAttachment): DmAttachment => ({
        type: attachment.attachment_type, mediaHash: attachment.media_hash_key ?? '',
        mediaType: attachment.media_type === 'image' ? 1 : attachment.media_type === 'gif' ? 2 :
          attachment.media_type === 'video' ? 3 : attachment.media_type === 'audio' ? 4 : 5,
        filename: attachment.filename ?? '', url: this.attachmentUrl(attachment),
        width: attachment.dimensions?.width ?? 0, height: attachment.dimensions?.height ?? 0,
        durationMs: attachment.duration_millis ?? 0
      }));
      page.messages.push({
        id: event.id ?? sequence, sequenceId: sequence,
        conversationId: conversationId.length > 0 ? conversationId : eventConversation, senderId: sender,
        senderName: user?.core?.name ?? '', senderUsername: user?.core?.screen_name ?? '',
        senderAvatarUrl: user?.avatar?.image_url ?? '', senderVerifiedType: userVerifiedType(user), senderAvatarShape: userAvatarShape(user), text: event.text ?? event.content?.text ?? '',
        time: timestamp > 0 ? XNotificationParser.relativeTime(timestamp) : '',
        timestampMs: timestamp, outgoing: sender === xPrivateClient.viewerId(), encrypted: false,
        attachments: attachments, keyVersion: event.keyVersion ?? '', rawEvent: event.rawEvent,
        reply: preview === undefined ? undefined : {
          sequenceId: preview.replying_to_message_sequence_id ?? '', senderId: preview.sender_id ?? '',
          senderName: this.users.get(preview.sender_id ?? '')?.core?.name ?? preview.sender_display_name ?? '',
          text: preview.message_text ?? '', attachments: (preview.attachments ?? []).map((a: XChatNativeAttachment): DmAttachment => ({
            type: a.attachment_type, mediaHash: a.media_hash_key ?? '', mediaType: a.media_type === 'audio' ? 4 : 1,
            filename: a.filename ?? '', url: this.attachmentUrl(a), width: a.dimensions?.width ?? 0, height: a.dimensions?.height ?? 0
          }))
        }
      });
    }
    page.messages.sort((a: DmMessage, b: DmMessage): number =>
      XChatService.compareIds(a.sequenceId ?? '', b.sequenceId ?? ''));
    this.rememberEffects(page.events);
    const effects: XChatNativeMessage[] = Array.from(this.effectCache.values()).filter((e: XChatNativeMessage): boolean =>
      conversationId.length === 0 || (e.conversationId ?? '').replace(':', '-') === conversationId.replace(':', '-'));
    page.effects = effects;
    return page;
  }

  async send(conversationId: string, text: string, attachments: XChatMediaDescriptor[] = [], mediaKeyVersion: string = '', messageId: string = '', reply?: XChatReplyTarget): Promise<XChatPage> {
    const generation: number = this.generation;
    const ttl: number = Number(this.conversationInfo(conversationId).ttl);
    const args: XChatEncryptArgs = { conversation_id: conversationId, text: text, attachments: attachments,
      media_key_version: mediaKeyVersion, ttl_msec: Number.isFinite(ttl) && ttl > 0 ? ttl : undefined,
      message_id: messageId.length > 0 ? messageId : undefined, reply: reply };
    const pendingKey: string = JSON.stringify([messageId, text, attachments, reply]);
    let pending: XChatPendingSend | undefined = this.pendingSends.get(conversationId);
    if (pending === undefined || pending.text !== pendingKey) {
      let encrypted: XChatNativeResult = await this.callNative('encrypt', JSON.stringify(args));
      if (!encrypted.ok && (encrypted.error ?? '').indexOf('no cached conversation key') >= 0) {
        try { await this.conversation(conversationId); }
        catch (error) { if ((error as Error).message !== 'conversation_unavailable') { throw error as Error; } }
        encrypted = await this.callNative('encrypt', JSON.stringify(args));
        if (!encrypted.ok && (encrypted.error ?? '').indexOf('no cached conversation key') >= 0) {
          await this.initializeDirect(conversationId);
          encrypted = await this.callNative('encrypt', JSON.stringify(args));
        }
      }
      if (generation !== this.generation) { throw new Error('account_changed'); }
      if (!encrypted.ok || encrypted.data === undefined) { throw new Error(encrypted.error ?? 'encrypt_failed'); }
      if (messageId.length > 0 && encrypted.data.message_id !== messageId) { throw new Error('media_message_id_mismatch'); }
      pending = { text: pendingKey, payload: encrypted.data };
      this.pendingSends.set(conversationId, pending);
    }
    const payload: XChatNativeData = pending.payload;
    const result: XPrivateResult = await xPrivateClient.graphql('SendMessageCreateMutation', {
      'conversation_id': payload.conversation_id ?? conversationId,
      'message_id': payload.message_id ?? '',
      'encoded_message_create_event': payload.encoded_message_create_event ?? '',
      'encoded_message_event_signature': payload.encoded_message_event_signature ?? ''
    });
    if (generation !== this.generation) { throw new Error('account_changed'); }
    if (!result.ok) { throw new Error('send_http_' + result.status.toString()); }
    const envelope: XChatEnvelope = JSON.parse(result.body) as XChatEnvelope;
    const event: string = envelope.data?.xchat_send_create_message_event?.encoded_message_event ?? '';
    if (event.length === 0) { throw new Error('send_unconfirmed'); }
    const decoded: XChatPage = await this.decode([event], conversationId);
    if (decoded.events.some((e: XChatNativeMessage): boolean => e.type === 'failure')) {
      this.pendingSends.delete(conversationId);
      throw new Error('send_rejected');
    }
    if (!decoded.messages.some((m: DmMessage): boolean => m.id === payload.message_id)) {
      throw new Error('send_unconfirmed');
    }
    this.pendingSends.delete(conversationId);
    this.messageCache.set(conversationId.replace(':', '-'), this.mergeConversation(this.cachedMessages(conversationId), decoded, conversationId));
    this.notifyChanged();
    return decoded;
  }

  async react(conversationId: string, sequenceId: string, emoji: string, remove: boolean): Promise<XChatPage> {
    if (sequenceId.length === 0 || emoji.length === 0) { throw new Error('invalid_reaction'); }
    const generation: number = this.generation;
    const args: XChatReactionArgs = { conversation_id: conversationId, sequence_id: sequenceId, emoji: emoji, remove: remove };
    const encrypted: XChatNativeResult = await this.callNative('encryptReaction', JSON.stringify(args));
    if (generation !== this.generation) { throw new Error('account_changed'); }
    if (!encrypted.ok || encrypted.data === undefined) { throw new Error(encrypted.error ?? 'reaction_encrypt_failed'); }
    const payload: XChatNativeData = encrypted.data;
    const result: XPrivateResult = await xPrivateClient.graphql('SendMessageCreateMutation', {
      'conversation_id': payload.conversation_id ?? conversationId, 'message_id': payload.message_id ?? '',
      'encoded_message_create_event': payload.encoded_message_create_event ?? '',
      'encoded_message_event_signature': payload.encoded_message_event_signature ?? ''
    });
    if (generation !== this.generation) { throw new Error('account_changed'); }
    if (!result.ok) { throw new Error('reaction_http_' + result.status.toString()); }
    const envelope: XChatEnvelope = JSON.parse(result.body) as XChatEnvelope;
    const event: string = envelope.data?.xchat_send_create_message_event?.encoded_message_event ?? '';
    if (event.length === 0) { throw new Error('reaction_unconfirmed'); }
    const page: XChatPage = await this.decode([event], conversationId);
    if (!page.events.some((e: XChatNativeMessage): boolean => e.verified === true && e.id === payload.message_id &&
      e.content?.content_type === (remove ? 'ReactionRemoved' : 'Reaction') &&
      e.content?.emoji === emoji && e.content?.target_message_id === sequenceId)) { throw new Error('reaction_unconfirmed'); }
    this.messageCache.set(conversationId.replace(':', '-'), this.mergeConversation(this.cachedMessages(conversationId), page, conversationId));
    this.notifyChanged();
    return page;
  }

  static compareIds(left: string, right: string): number {
    if (left.length !== right.length) { return left.length > right.length ? 1 : -1; }
    return left === right ? 0 : (left > right ? 1 : -1);
  }

  static merge(existing: DmMessage[], page: XChatPage): DmMessage[] {
    const merged: Map<string, DmMessage> = new Map<string, DmMessage>();
    existing.forEach((m: DmMessage): void => { merged.set(m.id, m); });
    page.messages.forEach((m: DmMessage): void => {
      const prior: DmMessage | undefined = merged.get(m.id);
      if (prior !== undefined) { m.reactions = prior.reactions; m.read = prior.read; }
      merged.set(m.id, m);
    });
    page.events.concat(page.effects).forEach((e: XChatNativeMessage): void => {
      if (e.type === 'deleted') {
        const ids: string[] = e.event?.message_ids ?? [];
        merged.forEach((m: DmMessage, id: string): void => {
          if (((e.conversationId ?? '').length === 0 ||
            m.conversationId.replace(':', '-') === (e.conversationId ?? '').replace(':', '-')) &&
            (ids.indexOf(m.id) >= 0 || ids.indexOf(m.sequenceId ?? '') >= 0)) { merged.delete(id); }
        });
      } else if (e.content?.content_type === 'Reaction' || e.content?.content_type === 'ReactionRemoved') {
        merged.forEach((m: DmMessage): void => {
          if (m.sequenceId !== e.content?.target_message_id ||
            m.conversationId.replace(':', '-') !== (e.conversationId ?? '').replace(':', '-')) { return; }
          const entries: DmReaction[] = (m.reactions ?? []).slice();
          const previous: DmReaction | undefined = entries.find((r: DmReaction): boolean => r.emoji === e.content?.emoji && r.senderId === e.senderId);
          if (previous !== undefined && XChatService.compareIds(previous.sequenceId, e.sequenceId ?? '') >= 0) { return; }
          const update: DmReaction = { emoji: e.content?.emoji ?? '', senderId: e.senderId ?? '',
            sequenceId: e.sequenceId ?? '', active: e.content?.content_type === 'Reaction' };
          m.reactions = entries.filter((r: DmReaction): boolean => r.emoji !== update.emoji || r.senderId !== update.senderId).concat([update]);
        });
      } else if (e.content?.content_type === 'Edit') {
        merged.forEach((m: DmMessage): void => {
          if (m.sequenceId === e.content?.target_message_id && (e.senderId === undefined || e.senderId === m.senderId)) { m.text = e.content?.new_text ?? m.text; }
        });
      } else if (e.type === 'read' && e.senderId !== xPrivateClient.viewerId()) {
        merged.forEach((m: DmMessage): void => {
          if (m.outgoing && m.conversationId.replace(':', '-') === (e.conversationId ?? '').replace(':', '-') &&
            XChatService.compareIds(m.sequenceId ?? '', e.seenUntilId ?? '') <= 0) { m.read = true; }
        });
      }
    });
    const rows: DmMessage[] = Array.from(merged.values());
    rows.sort((a: DmMessage, b: DmMessage): number => XChatService.compareIds(a.sequenceId ?? '', b.sequenceId ?? ''));
    return rows;
  }
}

export const xChatService: XChatService = new XChatService();
