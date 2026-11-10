import type { ThreadReplyRow } from './ThreadReplyOrder';
import type { XXAuthPromotionPost } from './XXAuthPromotionPost';
import type { ReplyQualityAssessment } from '../utils/ReplyQuality';
import { PostCardReadingState } from './PostCardReadingState';

export class CommentTimelineRow {
  key: string = '';
  revision: number = 0;
  reply: ThreadReplyRow | null = null;
  promotion: XXAuthPromotionPost | null = null;
  quality: ReplyQualityAssessment | null = null;
  readingState: PostCardReadingState = new PostCardReadingState();
}

// A single instance survives pagination, sorting and viewport changes. Append
// notifications leave existing cells alone, including a newly loaded nested
// reply inserted beside its parent. Keys retain reading choices on reorders.
export class CommentTimelineDataSource implements IDataSource {
  private rows: CommentTimelineRow[] = [];
  private listeners: DataChangeListener[] = [];

  totalCount(): number { return this.rows.length; }
  getData(index: number): CommentTimelineRow | undefined { return this.rows[index]; }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) { this.listeners.push(listener); }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const index: number = this.listeners.indexOf(listener);
    if (index >= 0) { this.listeners.splice(index, 1); }
  }

  replace(incoming: CommentTimelineRow[]): void {
    const previous: Map<string, CommentTimelineRow> = new Map();
    const previousPositions: Map<string, number> = new Map();
    for (let index: number = 0; index < this.rows.length; index++) {
      previous.set(this.rows[index].key, this.rows[index]);
      previousPositions.set(this.rows[index].key, index);
    }
    const next: CommentTimelineRow[] = [];
    const seen: Set<string> = new Set();
    for (const row of incoming) {
      if (seen.has(row.key)) { continue; }
      seen.add(row.key);
      const old: CommentTimelineRow | undefined = previous.get(row.key);
      if (old !== undefined) {
        row.readingState = old.readingState;
        row.revision = old.revision;
        if (this.sameContent(old, row)) { next.push(old); continue; }
        row.revision++;
      }
      next.push(row);
    }
    let lastPosition: number = -1;
    for (const row of next) {
      const position: number | undefined = previousPositions.get(row.key);
      if (position === undefined) { continue; }
      if (position < lastPosition) {
        // An explicit ranking change may reorder existing replies. Reloading
        // retains components whose stable keys have not changed.
        this.rows = next;
        for (const listener of this.listeners) { listener.onDataReloaded(); }
        return;
      }
      lastPosition = position;
    }
    // Remove from the end so each notification refers to the current source.
    // Pagination and filtering need no whole-list key comparison in ArkUI.
    for (let index: number = this.rows.length - 1; index >= 0; index--) {
      if (seen.has(this.rows[index].key)) { continue; }
      this.rows.splice(index, 1);
      for (const listener of this.listeners) { listener.onDataDelete(index); }
    }
    for (let index: number = 0; index < next.length; index++) {
      const current: CommentTimelineRow | undefined = this.rows[index];
      if (current === undefined || current.key !== next[index].key) {
        this.rows.splice(index, 0, next[index]);
        for (const listener of this.listeners) { listener.onDataAdd(index); }
      } else if (current !== next[index]) {
        this.rows[index] = next[index];
        for (const listener of this.listeners) { listener.onDataChange(index); }
      }
    }
  }

  private sameContent(left: CommentTimelineRow, right: CommentTimelineRow): boolean {
    if (left.promotion !== right.promotion) { return false; }
    if (left.quality?.reasons.join('|') !== right.quality?.reasons.join('|')) { return false; }
    if (left.reply === null || right.reply === null) { return left.reply === right.reply; }
    return left.reply.tweet === right.reply.tweet && left.reply.depth === right.reply.depth &&
      left.reply.replyingToUsername === right.reply.replyingToUsername &&
      left.reply.isNestedReply === right.reply.isNestedReply &&
      left.reply.connectAbove === right.reply.connectAbove && left.reply.connectBelow === right.reply.connectBelow;
  }
}
