import { common } from '@kit.AbilityKit';
import { XPrivateResult, xPrivateClient } from './XPrivateClient';
import { XExploreParser } from './XExploreParser';
import { XNotificationParser } from './XNotificationParser';
import type { XNotificationPage } from './XNotificationParser';
import {
  ArticleCardStore,
  CARD_SOURCE_FOLLOWING,
  CARD_SOURCE_FOR_YOU,
  CARD_SOURCE_NOTIFICATIONS,
  CARD_SOURCE_TRENDS
} from './ArticleCardStore';
import { ArticleCardPublisher } from './ArticleCardPublisher';
import { accountStore } from './AccountStore';

// Refreshes one card source without changing what is on screen. The settings
// page uses this after a source change so a newly chosen tab is populated.
export class ArticleCardSourceService {
  static async refresh(context: common.UIAbilityContext, source: string): Promise<boolean> {
    if (source === CARD_SOURCE_FOR_YOU || source === CARD_SOURCE_FOLLOWING) {
      // Only the corresponding rendered Home timeline owns this snapshot.
      // A separate recommendation request would produce a different feed.
      ArticleCardPublisher.publish(context);
      return ArticleCardStore.hasSnapshot(context, source);
    }
    xPrivateClient.load(context);
    if (!xPrivateClient.isSignedIn()) {
      return false;
    }
    const accountId: string = accountStore.activeId(context);
    if (source === CARD_SOURCE_TRENDS) {
      const result: XPrivateResult = await xPrivateClient.explorePage('');
      if (!result.ok || accountStore.activeId(context) !== accountId) {
        return false;
      }
      const trends: string[] = XExploreParser.parseTrends(result.body);
      if (trends.length === 0) {
        return false;
      }
      if (ArticleCardStore.rememberTrends(context, trends)) {
        ArticleCardPublisher.publish(context);
      }
      return true;
    }
    if (source === CARD_SOURCE_NOTIFICATIONS) {
      const result: XPrivateResult = await xPrivateClient.notifications('', 20);
      if (!result.ok || accountStore.activeId(context) !== accountId) {
        return false;
      }
      const page: XNotificationPage | null = XNotificationParser.parsePage(result.body);
      if (page === null || page.items.length === 0) {
        return false;
      }
      if (ArticleCardStore.rememberNotifications(context, page.items)) {
        ArticleCardPublisher.publish(context);
        ArticleCardStore.refineAvatarGradients(context, CARD_SOURCE_NOTIFICATIONS).then((changed: boolean): void => {
          if (changed) {
            ArticleCardPublisher.publish(context);
          }
        }).catch((): void => {
        });
      }
      return true;
    }
    return false;
  }
}
