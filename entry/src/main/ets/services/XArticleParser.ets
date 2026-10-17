import type { ProfileArticle, MediaAttachment } from '../models/Tweet';
import { ArticleBlock, ArticleRun } from '../models/PostContent';
import { XRichCardParser as Card } from './XRichCardParser';

export class XArticleParser {
  static detail(body: string): ProfileArticle | undefined {
    try {
      const data: Record<string, Object> = Card.object((JSON.parse(body) as Record<string, Object>)['data']);
      return XArticleParser.result(Card.object(Card.object(data['article_result_by_rest_id'])['result']));
    } catch (error) { return undefined; }
  }
  static parse(node: Record<string, Object>): ProfileArticle | undefined {
    const wrapper: Record<string, Object> = Card.object(node['article']);
    const article: Record<string, Object> = Card.object(Card.object(wrapper['article_results'])['result']);
    return XArticleParser.result(article);
  }
  private static result(article: Record<string, Object>): ProfileArticle | undefined {
    const id: string = Card.text(article['rest_id']);
    if (id.length === 0) { return undefined; }
    const cover: Record<string, Object> = Card.object(Card.object(article['cover_media_results'])['result']);
    const blocks: ArticleBlock[] = XArticleParser.blocks(article);
    return { id: id, title: Card.text(article['title']), previewText: Card.text(article['preview_text']),
      coverUrl: Card.url(Card.object(cover['media_info'])['original_img_url']), blocks: blocks,
      plainText: Card.text(article['plain_text']) || blocks.map((block: ArticleBlock): string => block.text).join('\n\n') };
  }
  private static blocks(article: Record<string, Object>): ArticleBlock[] {
    let state: Record<string, Object> = Card.object(article['content_state']);
    if (typeof article['content_state'] === 'string') {
      try { state = Card.object(JSON.parse(article['content_state'] as string) as Object); } catch (error) { return []; }
    }
    const blocks: ArticleBlock[] = [];
    const raw: Object | undefined = state['blocks'];
    if (!(raw instanceof Array)) { return blocks; }
    const entries: Object[] = raw as Object[];
    const entities: Record<string, Object> = Card.object(state['entityMap'] ?? state['entity_map']);
    for (let i: number = 0; i < entries.length; i++) {
      const entry: Record<string, Object> = Card.object(entries[i]);
      const block: ArticleBlock = new ArticleBlock(); block.id = Card.text(entry['key']) || String(i);
      block.kind = Card.text(entry['type']) || 'unstyled'; block.text = Card.text(entry['text']);
      const ranges: Object[] = entry['entityRanges'] instanceof Array ? entry['entityRanges'] as Object[] : [];
      const styles: Object[] = entry['inlineStyleRanges'] instanceof Array ? entry['inlineStyleRanges'] as Object[] : [];
      const cuts: number[] = [0, block.text.length];
      const all: Object[] = [...ranges, ...styles];
      for (let j: number = 0; j < all.length; j++) {
        const range: Record<string, Object> = Card.object(all[j]);
        cuts.push(Math.min(block.text.length, Card.number(range['offset'])));
        cuts.push(Math.min(block.text.length, Card.number(range['offset']) + Card.number(range['length'])));
      }
      cuts.sort((a: number, b: number): number => a - b);
      for (let j: number = 0; j < cuts.length - 1; j++) {
        if (cuts[j] === cuts[j + 1]) { continue; }
        const run: ArticleRun = new ArticleRun(); run.text = block.text.substring(cuts[j], cuts[j + 1]);
        for (let s: number = 0; s < styles.length; s++) {
          const style: Record<string, Object> = Card.object(styles[s]);
          if (cuts[j] < Card.number(style['offset']) || cuts[j] >= Card.number(style['offset']) + Card.number(style['length'])) { continue; }
          const name: string = Card.text(style['style']);
          run.bold = run.bold || name === 'BOLD'; run.italic = run.italic || name === 'ITALIC';
          run.underline = run.underline || name === 'UNDERLINE'; run.strike = run.strike || name === 'STRIKETHROUGH';
          run.code = run.code || name === 'CODE';
        }
        for (let r: number = 0; r < ranges.length; r++) {
          const range: Record<string, Object> = Card.object(ranges[r]);
          if (cuts[j] < Card.number(range['offset']) || cuts[j] >= Card.number(range['offset']) + Card.number(range['length'])) { continue; }
          const entity: Record<string, Object> = Card.object(entities[Card.text(range['key'])]);
          const data: Record<string, Object> = Card.object(entity['data']);
          run.url = Card.url(data['url'] ?? data['href']);
        }
        block.runs.push(run);
      }
      for (let r: number = 0; r < ranges.length && block.kind === 'atomic'; r++) {
        const entity: Record<string, Object> = Card.object(entities[Card.text(Card.object(ranges[r])['key'])]);
        const data: Record<string, Object> = Card.object(entity['data']);
        const mediaId: string = Card.text(data['media_id'] ?? data['mediaId']);
        const list: Object | undefined = article['media_entities'];
        if (list instanceof Array) {
          const mediaList: Object[] = list as Object[];
          for (let m: number = 0; m < mediaList.length; m++) {
            const candidate: Record<string, Object> = Card.object(mediaList[m]);
            if (Card.text(candidate['media_id'] ?? candidate['id']) !== mediaId) { continue; }
            const info: Record<string, Object> = Card.object(candidate['media_info']);
            const dimensions: Record<string, Object> = { 'width': info['original_img_width'], 'height': info['original_img_height'] };
            const raw: Record<string, Object> = { 'type': info['__typename'] === 'ApiVideo' ? 'video' : 'photo',
              'media_url_https': info['original_img_url'], 'original_info': info['original_img_width'] !== undefined ?
                dimensions : candidate['original_info'],
              'variants': info['variants'] };
            const media: MediaAttachment | undefined = Card.media(raw, mediaId);
            if (media !== undefined) { block.media.push(media); }
          }
        }
        block.url = Card.url(data['url'] ?? data['src']);
        if (block.media.length === 0 && /IMAGE/i.test(Card.text(entity['type'])) && block.url.length > 0) {
          const media: MediaAttachment | undefined = Card.media({ 'type': 'photo', 'media_url_https': block.url }, block.id);
          if (media !== undefined) { block.media.push(media); block.url = ''; }
        }
      }
      blocks.push(block);
    }
    return blocks;
  }
}
