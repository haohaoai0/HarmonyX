import { XXAuthPromotionPlan, XXAuthPromotionPost } from '../services/XXAuthPromotionPost';
import { XXAuthPromotionInjector, XXAuthPromotionSlot } from './XXAuthPromotionInjector';

// Draw once per detail visit. Store reply IDs so paging and rebuilding the UI
// cannot move an existing promotion or split a nested reply from its parent.
export class XXAuthCommentPromotionSession {
  private threadId: string = '';
  private roll: number = 0;
  private salt: string = '';
  private planned: boolean = false;
  private anchors: Map<string, string> = new Map();

  placements(threadId: string, replyIds: string[], plan: XXAuthPromotionPlan): Map<string, XXAuthPromotionPost> {
    const result: Map<string, XXAuthPromotionPost> = new Map();
    if (threadId.length === 0) { return result; }
    if (this.threadId !== threadId) {
      this.threadId = threadId;
      this.roll = Math.random();
      this.salt = Math.random().toString();
      this.planned = false;
      this.anchors.clear();
    }
    // Older published plans also use the new probability default.
    const probability: number = Number.isFinite(plan.commentProbability) ? plan.commentProbability : 0.3;
    const count: number = Math.min(2, Math.max(0, Math.floor(plan.commentCount)), plan.posts.length);
    if (this.roll >= probability || count <= 0 || replyIds.length === 0) { return result; }
    if (!this.planned) {
      const slots: XXAuthPromotionSlot[] = XXAuthPromotionInjector.slots(replyIds.length,
        plan.posts, Math.min(count, replyIds.length), 'comments:' + threadId + ':' + this.salt);
      for (let i: number = 0; i < slots.length; i++) {
        this.anchors.set(replyIds[slots[i].index - 1], slots[i].post.fingerprint);
      }
      this.planned = true;
    }
    for (let i: number = 0; i < replyIds.length && result.size < count; i++) {
      const fingerprint: string | undefined = this.anchors.get(replyIds[i]);
      if (fingerprint === undefined) { continue; }
      const post: XXAuthPromotionPost | undefined = plan.posts.find(
        (item: XXAuthPromotionPost): boolean => item.fingerprint === fingerprint);
      if (post !== undefined) { result.set(replyIds[i], post); }
    }
    return result;
  }
}
