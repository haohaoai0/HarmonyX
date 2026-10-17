export const SPACE_TITLE_LIMIT: number = 70;
export const SPACE_TOPIC_LIMIT: number = 3;
export const SPACE_SCHEDULE_DAYS: number = 14;
export const SPACE_TOPIC_KEYS: string[] = ['Technology', 'Music', 'Science', 'Entertainment', 'Arts & Culture', 'Sports'];

export class SpaceDraft {
  title: string = '';
  record: boolean = true;
  topics: string[] = [];
  scheduledStart: number = 0;
  updatedAt: number = 0;

  static titleLength(title: string): number { return Array.from(title).length; }
  static trimTitle(title: string): string { return Array.from(title).slice(0, SPACE_TITLE_LIMIT).join(''); }
  static scheduleValid(value: number, now: number): boolean {
    return Number.isFinite(value) && value >= now + 60000 && value <= now + SPACE_SCHEDULE_DAYS * 86400000;
  }
  static normalize(source: SpaceDraft): SpaceDraft {
    const draft: SpaceDraft = new SpaceDraft();
    draft.title = typeof source.title === 'string' ? SpaceDraft.trimTitle(source.title) : '';
    draft.record = source.record !== false;
    const topics: string[] = Array.isArray(source.topics) ? source.topics : [];
    for (let i: number = 0; i < topics.length && draft.topics.length < SPACE_TOPIC_LIMIT; i++) {
      if (SPACE_TOPIC_KEYS.indexOf(topics[i]) >= 0 && draft.topics.indexOf(topics[i]) < 0) { draft.topics.push(topics[i]); }
    }
    draft.scheduledStart = Number.isFinite(source.scheduledStart) && source.scheduledStart > 0 ? source.scheduledStart : 0;
    draft.updatedAt = Number.isFinite(source.updatedAt) && source.updatedAt > 0 ? source.updatedAt : 0;
    return draft;
  }
}
