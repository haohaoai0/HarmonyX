import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import util from '@ohos.util';
import { XXAuthPanel, XXAuthPopupConfig } from '../models/XXAuth';
import { XXAuthPopupHistory, XXAuthPopupSchedule } from './XXAuthPopupSchedule';

export const XXAUTH_POPUP_REQUEST: string = 'harmonyx.xxauth_popup_request';
export const XXAUTH_POPUP_CONFIG: string = 'harmonyx_popup';
// Timeline recommendation post, published by the popup host as JSON text.
export const XXAUTH_PROMOTION_POST: string = 'harmonyx.promotion_post';
// Session-only dismissal; AppStorage keeps it for this run of the app only.
export const XXAUTH_PROMOTION_SESSION: string = 'harmonyx.promotion_post_session_hidden';
const STORE: string = 'harmonyx_update';
const SNOOZE_MS: number = 3 * 24 * 60 * 60 * 1000;
const PROMOTION_HIDE_MS: number = 7 * 24 * 60 * 60 * 1000;

interface PromotionHideRecord {
  until: number;
  plan: string;
}

export function requestXXAuthPopup(kind: string): void {
  AppStorage.setOrCreate<string>(XXAUTH_POPUP_REQUEST, kind + ':' + Date.now().toString());
}

export class XXAuthPopupStore {
  private fallbackId: string = '';
  private popupSessionRevision: number = -1;
  private popupSessionCount: number = 0;

  private open(context: common.Context): preferences.Preferences {
    return preferences.getPreferencesSync(context, { name: STORE });
  }

  deviceId(context: common.Context): string {
    try {
      const store: preferences.Preferences = this.open(context);
      const saved: string = store.getSync('device_id', '') as string;
      if (saved.length > 0) { return saved; }
      if (this.fallbackId.length === 0) { this.fallbackId = util.generateRandomUUID(); }
      store.putSync('device_id', this.fallbackId);
      store.flushSync();
    } catch (error) {
      if (this.fallbackId.length === 0) { this.fallbackId = util.generateRandomUUID(); }
    }
    return this.fallbackId;
  }

  private popupHistory(store: preferences.Preferences, config: XXAuthPopupConfig): XXAuthPopupHistory {
    const saved: string = store.getSync('recommendation_schedule_' + XXAuthPopupSchedule.revision(config).toString(), '') as string;
    if (saved.length === 0) { return new XXAuthPopupHistory(); }
    const history: XXAuthPopupHistory = JSON.parse(saved) as XXAuthPopupHistory;
    if (history === null || typeof history.day !== 'string' || !Number.isFinite(history.dayCount) ||
      !Number.isFinite(history.total) || !Number.isFinite(history.last) || history.dayCount < 0 ||
      history.total < 0 || history.last < 0) { throw new Error('Invalid recommendation budget'); }
    return history;
  }

  private sessionCount(config: XXAuthPopupConfig): number {
    const revision: number = XXAuthPopupSchedule.revision(config);
    if (this.popupSessionRevision !== revision) {
      this.popupSessionRevision = revision;
      this.popupSessionCount = 0;
    }
    return this.popupSessionCount;
  }

  markRecommendationShown(context: common.Context, config: XXAuthPopupConfig, now: number): boolean {
    try {
      const store: preferences.Preferences = this.open(context);
      const next: XXAuthPopupHistory = XXAuthPopupSchedule.record(this.popupHistory(store, config), now);
      const key: string = 'recommendation_schedule_' + XXAuthPopupSchedule.revision(config).toString();
      const previous: string = store.getSync(key, '') as string;
      try { store.putSync(key, JSON.stringify(next)); store.flushSync(); }
      catch (error) { store.putSync(key, previous); return false; }
      this.popupSessionCount = this.sessionCount(config) + 1;
      return true;
    } catch (error) { return false; }
  }

  shouldShow(context: common.Context, panel: XXAuthPanel, now: number,
    config: XXAuthPopupConfig = {}, readySince: number = 0): boolean {
    try {
      const store: preferences.Preferences = this.open(context);
      if (panel.kind === 'recommendation') {
        if (!XXAuthPopupSchedule.eligible(config, this.popupHistory(store, config), this.sessionCount(config),
          now, readySince)) { return false; }
        const key: string = 'recommendation_snooze_until' +
          (panel.recommendationAppId.length > 0 ? '_' + panel.recommendationAppId : '');
        return panel.forced || panel.reminderForced || (store.getSync(key, 0) as number) <= now;
      }
      return panel.forced || panel.repeat ||
        store.getSync('seen_' + panel.kind + '_' + panel.id, '') !== panel.fingerprint;
    } catch (error) { return panel.kind !== 'recommendation'; }
  }

  markRead(context: common.Context, panel: XXAuthPanel): void {
    if (panel.kind === 'recommendation' || panel.forced) { return; }
    try {
      const store: preferences.Preferences = this.open(context);
      store.putSync('seen_' + panel.kind + '_' + panel.id, panel.fingerprint);
      store.flushSync();
    } catch (error) { }
  }

  snooze(context: common.Context, now: number, appId: string = ''): boolean {
    try {
      const store: preferences.Preferences = this.open(context);
      const key: string = 'recommendation_snooze_until' + (appId.length > 0 ? '_' + appId : '');
      const previous: number = store.getSync(key, 0) as number;
      try { store.putSync(key, now + SNOOZE_MS); store.flushSync(); }
      catch (error) { store.putSync(key, previous); return false; }
      return true;
    } catch (error) { return false; }
  }

  // Hiding one promotion is scoped to the copy the reader rejected: a week
  // later, or as soon as the developer ships different content, it returns.
  promotionHiddenUntil(context: common.Context, plan: string): number {
    try {
      const store: preferences.Preferences = this.open(context);
      const record: PromotionHideRecord =
        JSON.parse(store.getSync('promotion_post_hidden', '{}') as string) as PromotionHideRecord;
      if (typeof record.until !== 'number' || typeof record.plan !== 'string') { return 0; }
      return record.plan === plan ? record.until : 0;
    } catch (error) { return 0; }
  }

  hidePromotion(context: common.Context, now: number, plan: string): boolean {
    try {
      const store: preferences.Preferences = this.open(context);
      const record: PromotionHideRecord = { until: now + PROMOTION_HIDE_MS, plan: plan };
      store.putSync('promotion_post_hidden', JSON.stringify(record));
      store.flushSync();
      return true;
    } catch (error) { return false; }
  }

  promotionSessionHidden(): boolean {
    return AppStorage.get<boolean>(XXAUTH_PROMOTION_SESSION) === true;
  }

  hidePromotionForSession(): void {
    AppStorage.setOrCreate<boolean>(XXAUTH_PROMOTION_SESSION, true);
  }
}

export const xxAuthPopupStore: XXAuthPopupStore = new XXAuthPopupStore();
