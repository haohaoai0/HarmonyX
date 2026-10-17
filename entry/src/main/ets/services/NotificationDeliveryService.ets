import { common, wantAgent, WantAgent } from '@kit.AbilityKit';
import { BusinessError, intelligentScene } from '@kit.BasicServicesKit';
import { preferences } from '@kit.ArkData';
import { notificationManager } from '@kit.NotificationKit';
import hilog from '@ohos.hilog';
import type { AppNotification, DirectMessage } from '../models/Tweet';
import { accountStore } from './AccountStore';

const DOMAIN = 0xFF00;
const TAG = 'HarmonyX-Notify';
const BUNDLE_NAME: string = 'com.haohaoai0.harmonx';
const ABILITY_NAME: string = 'EntryAbility';
const NOTIFICATION_GROUP: string = 'harmonyx-x-notifications';
const MESSAGE_GROUP: string = 'harmonyx-x-messages';
const DELIVERED_LIMIT: number = 80;

export class NotificationDeliveryService {
  private static readonly STORE_NAME: string = 'harmonyx_notification_delivery';
  private static readonly DELIVERED_KEY: string = 'delivered_ids';
  private slotReady: boolean = false;
  private deliveryTail: Promise<void> = Promise.resolve();
  private nextPublishAt: number = 0;

  // Both timelines share one queue. Persist each success before the next job
  // checks deduplication, including when two refreshes arrive together.
  private enqueue(job: () => Promise<number>): Promise<number> {
    return new Promise<number>((resolve: (count: number) => void): void => {
      this.deliveryTail = this.deliveryTail.then(async (): Promise<void> => {
        try { resolve(await job()); }
        catch (error) {
          hilog.warn(DOMAIN, TAG, '%{public}s', 'Notification delivery batch failed');
          resolve(0);
        }
      });
    });
  }

  private async waitForPublish(): Promise<void> {
    const delay: number = Math.max(0, this.nextPublishAt - Date.now());
    if (delay > 0) { await new Promise<void>((resolve: () => void): void => { setTimeout(resolve, delay); }); }
    this.nextPublishAt = Date.now() + 250;
  }

  private isCurrentAccount(context: common.Context, accountId: string): boolean {
    return accountId.length > 0 && accountStore.activeId(context) === accountId;
  }

  async ensureAuthorized(context: common.UIAbilityContext): Promise<boolean> {
    try {
      const enabled: boolean = await notificationManager.isNotificationEnabled();
      if (enabled) {
        return true;
      }
      await notificationManager.requestEnableNotification(context);
      return await notificationManager.isNotificationEnabled();
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      hilog.warn(DOMAIN, TAG, 'notification authorization unavailable: %{public}d %{public}s',
        failure.code, failure.message);
      return false;
    }
  }

  async openSystemSettings(context: common.UIAbilityContext): Promise<boolean> {
    try {
      await notificationManager.openNotificationSettings(context);
      return true;
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      hilog.warn(DOMAIN, TAG, 'open notification settings failed: %{public}d %{public}s',
        failure.code, failure.message);
      return false;
    }
  }

  async updateBadge(unread: number): Promise<void> {
    try {
      await notificationManager.setBadgeNumber(unread);
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      hilog.warn(DOMAIN, TAG, 'set badge failed: %{public}d %{public}s', failure.code, failure.message);
    }
  }

  async clearBadge(): Promise<void> {
    await this.updateBadge(0);
  }

  async publishUnread(context: common.UIAbilityContext, rows: AppNotification[],
    unreadCount: number, badgeCount: number, silentInDnd: boolean): Promise<number> {
    const accountId: string = accountStore.activeId(context);
    return this.enqueue((): Promise<number> => this.deliverUnread(context, rows, unreadCount, badgeCount, silentInDnd, accountId));
  }

  private async deliverUnread(context: common.UIAbilityContext, rows: AppNotification[],
    unreadCount: number, badgeCount: number, silentInDnd: boolean, accountId: string): Promise<number> {
    if (!this.isCurrentAccount(context, accountId)) { return 0; }
    if (unreadCount <= 0) {
      await this.updateBadge(badgeCount);
      return 0;
    }
    await this.updateBadge(badgeCount);
    if (silentInDnd && await this.isDoNotDisturbEnabled()) {
      return 0;
    }
    if (!await this.ensureAuthorized(context)) {
      return 0;
    }
    await this.ensureSocialSlot();

    let published: number = 0;
    for (let i: number = 0; i < rows.length; i++) {
      if (!this.isCurrentAccount(context, accountId)) { break; }
      const row: AppNotification = rows[i];
      const deliveredText: string = this.loadDeliveredText(context, accountId);
      if (!row.unread || this.containsDelivered(deliveredText, row.id)) {
        continue;
      }
      await this.waitForPublish();
      if (!this.isCurrentAccount(context, accountId)) { break; }
      const ok: boolean = await this.publishOne(context, row, unreadCount, badgeCount, accountId);
      if (ok) {
        this.saveDeliveredIds(context, accountId, [row.id]);
        published += 1;
      }
    }
    return published;
  }

  async publishUnreadMessages(context: common.UIAbilityContext, rows: DirectMessage[],
    unreadCount: number, badgeCount: number, silentInDnd: boolean): Promise<number> {
    const accountId: string = accountStore.activeId(context);
    return this.enqueue((): Promise<number> => this.deliverMessages(context, rows, unreadCount, badgeCount, silentInDnd, accountId));
  }

  private async deliverMessages(context: common.UIAbilityContext, rows: DirectMessage[],
    unreadCount: number, badgeCount: number, silentInDnd: boolean, accountId: string): Promise<number> {
    if (!this.isCurrentAccount(context, accountId)) { return 0; }
    if (unreadCount <= 0) {
      await this.updateBadge(badgeCount);
      return 0;
    }
    await this.updateBadge(badgeCount);
    if (silentInDnd && await this.isDoNotDisturbEnabled()) {
      return 0;
    }
    if (!await this.ensureAuthorized(context)) {
      return 0;
    }
    await this.ensureSocialSlot();

    let published: number = 0;
    for (let i: number = 0; i < rows.length; i++) {
      if (!this.isCurrentAccount(context, accountId)) { break; }
      const row: DirectMessage = rows[i];
      const deliveredText: string = this.loadDeliveredText(context, accountId);
      const deliveredId: string = this.messageDeliveryId(row);
      if (row.unread <= 0 || deliveredId.length === 0 || this.containsDelivered(deliveredText, deliveredId)) {
        continue;
      }
      await this.waitForPublish();
      if (!this.isCurrentAccount(context, accountId)) { break; }
      const ok: boolean = await this.publishMessageOne(context, row, unreadCount, badgeCount, deliveredId, accountId);
      if (ok) {
        this.saveDeliveredIds(context, accountId, [deliveredId]);
        published += 1;
      }
    }
    return published;
  }

  markUnreadMessagesSeen(context: common.Context, rows: DirectMessage[]): void {
    const accountId: string = accountStore.activeId(context);
    const deliveredText: string = this.loadDeliveredText(context, accountId);
    const newIds: string[] = [];
    for (let i: number = 0; i < rows.length; i++) {
      const row: DirectMessage = rows[i];
      const deliveredId: string = this.messageDeliveryId(row);
      if (row.unread > 0 && deliveredId.length > 0 && !this.containsDelivered(deliveredText, deliveredId)) {
        newIds.push(deliveredId);
      }
    }
    if (newIds.length > 0) {
      this.saveDeliveredIds(context, accountId, newIds);
    }
  }

  private async isDoNotDisturbEnabled(): Promise<boolean> {
    try {
      return await intelligentScene.isDoNotDisturbEnabled();
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      hilog.warn(DOMAIN, TAG, 'do-not-disturb state unavailable: %{public}d %{public}s',
        failure.code, failure.message);
      return false;
    }
  }

  private async ensureSocialSlot(): Promise<void> {
    if (this.slotReady) {
      return;
    }
    try {
      await notificationManager.addSlot(notificationManager.SlotType.SOCIAL_COMMUNICATION);
      this.slotReady = true;
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      hilog.warn(DOMAIN, TAG, 'add notification slot failed: %{public}d %{public}s',
        failure.code, failure.message);
    }
  }

  private async publishOne(context: common.UIAbilityContext, row: AppNotification,
    unreadCount: number, badgeCount: number, accountId: string): Promise<boolean> {
    try {
    const title: string = row.authorName.length > 0 ? row.authorName : 'Harmony X';
    const body: string = row.text.length > 0 ? row.text : row.postText;
    const additional: string = unreadCount > 1 ? unreadCount.toString() + ' unread' : row.time;
    const request: notificationManager.NotificationRequest = {
      id: this.notificationId(accountId + ':' + row.id),
      appMessageId: accountId + ':' + row.id,
      groupName: NOTIFICATION_GROUP + ':' + accountId,
      badgeNumber: badgeCount,
      notificationSlotType: notificationManager.SlotType.SOCIAL_COMMUNICATION,
      tapDismissed: true,
      autoDeletedTime: Date.now() + 172800000,
      wantAgent: await this.createLaunchAgent(row, accountId),
      content: {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: {
          title: title,
          text: body,
          additionalText: additional
        }
      }
    };
      if (!this.isCurrentAccount(context, accountId) || this.containsDelivered(this.loadDeliveredText(context, accountId), row.id)) { return false; }
      await notificationManager.publish(request);
      return true;
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      hilog.warn(DOMAIN, TAG, 'publish notification failed: %{public}d %{public}s',
        failure.code, failure.message);
      return false;
    }
  }

  private async publishMessageOne(context: common.UIAbilityContext, row: DirectMessage,
    unreadCount: number, badgeCount: number, deliveredId: string, accountId: string): Promise<boolean> {
    try {
    const title: string = row.from.length > 0 ? row.from : 'Harmony X';
    const body: string = row.preview.length > 0 ? row.preview : 'New direct message';
    const additional: string = unreadCount > 1 ? unreadCount.toString() + ' unread messages' : row.time;
    const request: notificationManager.NotificationRequest = {
      id: this.notificationId(accountId + ':' + deliveredId),
      appMessageId: accountId + ':' + deliveredId,
      groupName: MESSAGE_GROUP + ':' + accountId,
      badgeNumber: badgeCount,
      notificationSlotType: notificationManager.SlotType.SOCIAL_COMMUNICATION,
      tapDismissed: true,
      autoDeletedTime: Date.now() + 172800000,
      wantAgent: await this.createMessagesLaunchAgent(row, deliveredId, accountId),
      content: {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: {
          title: title,
          text: body,
          additionalText: additional
        }
      }
    };
      if (!this.isCurrentAccount(context, accountId) || this.containsDelivered(this.loadDeliveredText(context, accountId), deliveredId)) { return false; }
      await notificationManager.publish(request);
      return true;
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      hilog.warn(DOMAIN, TAG, 'publish message notification failed: %{public}d %{public}s',
        failure.code, failure.message);
      return false;
    }
  }

  private async createLaunchAgent(row: AppNotification, accountId: string): Promise<WantAgent> {
    const info: wantAgent.WantAgentInfo = {
      wants: [
        {
          deviceId: '',
          bundleName: BUNDLE_NAME,
          abilityName: ABILITY_NAME,
          uri: 'harmonyx://notifications/' + row.id,
          parameters: {
            accountId: accountId,
            notificationId: row.id,
            targetPostId: row.targetPostId,
            authorUsername: row.authorUsername
          }
        }
      ],
      actionType: wantAgent.OperationType.START_ABILITY,
      requestCode: this.notificationId(accountId + ':' + row.id),
      actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    };
    return await wantAgent.getWantAgent(info);
  }

  private async createMessagesLaunchAgent(row: DirectMessage, deliveredId: string, accountId: string): Promise<WantAgent> {
    const conversationId: string = row.conversationId === undefined ? '' : row.conversationId;
    const info: wantAgent.WantAgentInfo = {
      wants: [
        {
          deviceId: '',
          bundleName: BUNDLE_NAME,
          abilityName: ABILITY_NAME,
          uri: conversationId.length > 0 ? 'harmonyx://messages/' + conversationId : 'harmonyx://messages',
          parameters: {
            accountId: accountId,
            notificationId: deliveredId,
            conversationId: conversationId,
            senderUsername: row.username === undefined ? '' : row.username
          }
        }
      ],
      actionType: wantAgent.OperationType.START_ABILITY,
      requestCode: this.notificationId(accountId + ':' + deliveredId),
      actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    };
    return await wantAgent.getWantAgent(info);
  }

  private messageDeliveryId(row: DirectMessage): string {
    if (row.id.length > 0) {
      return 'dm:' + row.id;
    }
    const conversationId: string = row.conversationId === undefined ? '' : row.conversationId;
    if (conversationId.length > 0) {
      return 'dm:' + conversationId;
    }
    return '';
  }

  private notificationId(id: string): number {
    let hash: number = 0;
    for (let i: number = 0; i < id.length; i++) {
      hash = (hash * 31 + id.charCodeAt(i)) % 900000;
    }
    return 210000 + hash;
  }

  private loadDeliveredText(context: common.Context, accountId: string): string {
    try {
      const options: preferences.Options = { name: NotificationDeliveryService.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      return store.getSync(NotificationDeliveryService.DELIVERED_KEY + ':' + accountId, '') as string;
    } catch (error) {
      return '';
    }
  }

  private containsDelivered(deliveredText: string, id: string): boolean {
    if (id.length === 0 || deliveredText.length === 0) {
      return false;
    }
    return ('\n' + deliveredText + '\n').indexOf('\n' + id + '\n') >= 0;
  }

  private saveDeliveredIds(context: common.Context, accountId: string, newIds: string[]): void {
    const deliveredText: string = this.loadDeliveredText(context, accountId);
    const all: string[] = [];
    for (let i: number = 0; i < newIds.length; i++) {
      all.push(newIds[i]);
    }
    const previous: string[] = deliveredText.length > 0 ? deliveredText.split('\n') : [];
    for (let i: number = 0; i < previous.length && all.length < DELIVERED_LIMIT; i++) {
      if (previous[i].length > 0 && !this.containsArray(all, previous[i])) {
        all.push(previous[i]);
      }
    }
    try {
      const options: preferences.Options = { name: NotificationDeliveryService.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      store.putSync(NotificationDeliveryService.DELIVERED_KEY + ':' + accountId, all.join('\n'));
      store.flushSync();
    } catch (error) {
      hilog.warn(DOMAIN, TAG, '%{public}s', 'save delivered notification ids failed');
    }
  }

  private containsArray(values: string[], target: string): boolean {
    for (let i: number = 0; i < values.length; i++) {
      if (values[i] === target) {
        return true;
      }
    }
    return false;
  }
}

export const notificationDeliveryService: NotificationDeliveryService = new NotificationDeliveryService();
