import { common } from '@kit.AbilityKit';
import fs from '@ohos.file.fs';
import util from '@ohos.util';
import hilog from '@ohos.hilog';
import { DmMessage } from '../models/Tweet';
import { ChatPickedFile, ChatMediaSendOptions, XChatMedia, xChatMedia } from './XChatMedia';
import { XChatPage, XChatReplyTarget, xChatService } from './XChatService';
import { xPrivateClient } from './XPrivateClient';
import { xPrivateStore } from './XPrivateStore';

export class ChatMediaSend {
  id: string = '';
  account: string = '';
  conversationId: string = '';
  files: ChatPickedFile[] = [];
  caption: string = '';
  reply: XChatReplyTarget | undefined = undefined;
  message: DmMessage;
  progress: number[] = [];
  state: string = 'sending';
  context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext, conversationId: string, files: ChatPickedFile[], caption: string,
    replyMessage?: DmMessage) {
    this.context = context;
    this.id = util.generateRandomUUID();
    this.account = xPrivateStore.load(context).cacheIdentity();
    this.conversationId = conversationId;
    // Native MovingPhoto handles must retain their original instance.
    this.files = files.slice(); this.caption = caption;
    this.progress = files.map((_file: ChatPickedFile): number => 0);
    this.reply = replyMessage === undefined ? undefined : { sequence_id: replyMessage.sequenceId ?? '',
      sender_id: replyMessage.senderId, text: replyMessage.text, raw_event: replyMessage.rawEvent ?? '',
      key_version: replyMessage.keyVersion ?? '' };
    this.message = { id: this.id, conversationId: conversationId, senderId: xPrivateClient.viewerId(),
      senderName: '', senderUsername: '', senderAvatarUrl: '', text: caption, time: '', timestampMs: Date.now(),
      outgoing: true, encrypted: true, reply: replyMessage === undefined ? undefined : {
        sequenceId: replyMessage.sequenceId ?? '', senderId: replyMessage.senderId, senderName: replyMessage.senderName,
        text: replyMessage.text, attachments: replyMessage.attachments ?? [] } };
  }
}

// Own in-flight media independently of a page's composer and navigation lifetime.
// Only confirmed messages enter XChatService's received-message cache.
export class ChatMediaOutbox {
  private sends: Map<string, ChatMediaSend> = new Map<string, ChatMediaSend>();
  private listeners: Set<() => void> = new Set<() => void>();
  private epoch: number = 0;

  constructor() { xPrivateClient.onSessionChange((): void => { this.clear(); }); }

  static timeline(messages: DmMessage[], pending: ChatMediaSend[]): DmMessage[] {
    const rows: DmMessage[] = messages.slice();
    pending.forEach((send: ChatMediaSend): void => {
      if (rows.some((message: DmMessage): boolean => message.id === send.id)) { return; }
      const index: number = rows.findIndex((message: DmMessage): boolean => message.timestampMs > send.message.timestampMs);
      if (index < 0) { rows.push(send.message); } else { rows.splice(index, 0, send.message); }
    });
    return rows;
  }

  subscribe(listener: () => void): void { this.listeners.add(listener); }
  unsubscribe(listener: () => void): void { this.listeners.delete(listener); }
  status(id: string): ChatMediaSend | undefined {
    const send: ChatMediaSend | undefined = this.sends.get(id);
    return send !== undefined && this.current(send, this.epoch) ? send : undefined;
  }
  private changed(): void { this.listeners.forEach((listener: () => void): void => { listener(); }); }
  private current(send: ChatMediaSend, epoch: number): boolean {
    return epoch === this.epoch && this.sends.get(send.id) === send &&
      send.account === xPrivateStore.load(send.context).cacheIdentity();
  }

  pending(context: common.UIAbilityContext, conversationId: string): ChatMediaSend[] {
    const account: string = xPrivateStore.load(context).cacheIdentity();
    const key: string = conversationId.replace(':', '-');
    // A timed-out request can later arrive through inbox polling. Reconcile
    // its stable ID instead of keeping a hidden failed entry or resending it.
    this.sends.forEach((send: ChatMediaSend): void => {
      if (send.account === account && send.state === 'failed' && this.confirmed(send)) { this.finish(send, false); }
    });
    return Array.from(this.sends.values()).filter((send: ChatMediaSend): boolean =>
      send.account === account && send.conversationId.replace(':', '-') === key);
  }

  enqueue(context: common.UIAbilityContext, conversationId: string, files: ChatPickedFile[], caption: string,
    replyMessage?: DmMessage): ChatMediaSend {
    if (files.length === 0 || XChatMedia.mediaSlots(files) > XChatMedia.MAX_MEDIA_ATTACHMENTS) {
      throw new Error('invalid_media_count');
    }
    if (this.sends.size >= 8) { throw new Error('media_queue_full'); }
    const send: ChatMediaSend = new ChatMediaSend(context, conversationId, files, caption, replyMessage);
    this.sends.set(send.id, send); this.changed();
    // Commit the local bubble before copying/encrypting the selected resources.
    setTimeout((): void => { this.run(send); }, 0);
    return send;
  }

  retry(id: string): void {
    const send: ChatMediaSend | undefined = this.sends.get(id);
    if (send === undefined || send.state !== 'failed' || !this.current(send, this.epoch)) { return; }
    if (this.confirmed(send)) { this.finish(send); return; }
    send.state = 'sending'; send.progress = send.files.map((_file: ChatPickedFile): number => 0);
    this.changed(); this.run(send);
  }

  discard(id: string): void {
    const send: ChatMediaSend | undefined = this.sends.get(id);
    if (send !== undefined && send.state === 'failed') { this.finish(send); }
  }

  private confirmed(send: ChatMediaSend): boolean {
    return xChatService.cachedMessages(send.conversationId).some((message: DmMessage): boolean =>
      message.id === send.id && message.outgoing);
  }

  private async run(send: ChatMediaSend): Promise<void> {
    const epoch: number = this.epoch;
    if (!this.current(send, epoch)) { return; }
    try {
      const options: ChatMediaSendOptions = { messageId: send.id,
        onProgress: (index: number, progress: number): void => {
          if (!this.current(send, epoch)) { return; }
          const next: number = Math.min(100, Math.max(0, progress));
          if (Math.abs(next - send.progress[index]) < 0.1) { return; }
          send.progress = send.progress.map((value: number, i: number): number => i === index ? next : value);
          this.changed();
        } };
      const page: XChatPage = await xChatMedia.sendMany(send.context, send.conversationId,
        send.files, send.caption, send.reply, options);
      if (!this.current(send, epoch)) { return; }
      if (!page.messages.some((message: DmMessage): boolean => message.id === send.id && message.outgoing)) {
        throw new Error('media_send_unconfirmed');
      }
      this.finish(send);
    } catch (error) {
      if (!this.current(send, epoch)) { return; }
      if (this.confirmed(send)) { this.finish(send); return; }
      send.state = 'failed'; this.changed();
      hilog.warn(0xFF00, 'HarmonyX-Chat', 'media send failed: %{public}s', (error as Error).message);
    }
  }

  private removeOwned(send: ChatMediaSend): void {
    const root: string = send.context.cacheDir + '/';
    send.files.forEach((file: ChatPickedFile): void => {
      if (!file.uri.startsWith(root) || !/^xchat_(voice_\d+\.m4a|camera_\d+\.jpg)$/.test(file.uri.substring(root.length))) { return; }
      try { if (fs.accessSync(file.uri)) { fs.unlinkSync(file.uri); } } catch (error) {}
    });
  }

  private finish(send: ChatMediaSend, notify: boolean = true): void {
    this.sends.delete(send.id); xChatMedia.discardSend(send.id); this.removeOwned(send);
    if (notify) { this.changed(); }
  }

  private clear(): void {
    this.epoch++;
    this.sends.forEach((send: ChatMediaSend): void => { this.removeOwned(send); });
    this.sends.clear(); this.changed();
  }
}

export const chatMediaOutbox: ChatMediaOutbox = new ChatMediaOutbox();
