import type { AppNotification } from '../models/Tweet';

export class NotificationFilters {
  static apply(rows: AppNotification[], tab: number): AppNotification[] {
    if (tab === 1) {
      return rows.filter((row: AppNotification): boolean => row.kind === 'mention' || row.kind === 'reply');
    }
    if (tab === 2) {
      return rows.filter((row: AppNotification): boolean => row.fromVerifiedAccount === true);
    }
    return rows;
  }
}
