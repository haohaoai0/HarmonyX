import { VideoDanmaku, VideoDanmakuComment } from './VideoDanmaku';
import type { TranslationSettings } from './TranslationStore';
import { TranslationResult, translationService } from './TranslationService';

export class VideoDanmakuTranslation {
  private pending: Map<string, Promise<string>> = new Map<string, Promise<string>>();

  async displayText(comment: VideoDanmakuComment, settings: TranslationSettings, revision: number,
    session: number): Promise<string> {
    if (!settings.shouldAutomaticallyTranslate(comment.language)) { return comment.text; }
    // Inline/fullscreen lanes share requests, including API providers. Settings
    // revisions and account sessions keep in-flight requests isolated.
    const key: string = session.toString() + '|' + revision.toString() + '|' + settings.effectiveTargetLanguage() +
      '|' + comment.id + '|' + comment.originalText;
    const current: Promise<string> | undefined = this.pending.get(key);
    if (current !== undefined) { return current; }
    const request: Promise<string> = this.translate(comment, settings);
    this.pending.set(key, request);
    try { return await request; }
    finally { if (this.pending.get(key) === request) { this.pending.delete(key); } }
  }

  private async translate(comment: VideoDanmakuComment, settings: TranslationSettings): Promise<string> {
    try {
      const result: TranslationResult = await translationService.translate(comment.id, comment.originalText, settings,
        comment.language);
      const translated: string = result.ok ? VideoDanmaku.commentText(result.text) : '';
      return translated.length > 0 ? translated : comment.text;
    } catch (error) { return comment.text; }
  }
}

export const videoDanmakuTranslation: VideoDanmakuTranslation = new VideoDanmakuTranslation();
