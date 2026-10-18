import type { Tweet } from '../models/Tweet';
import type { ArticleCardItem } from '../models/ArticleCardItem';

export const STORAGE_KEY_ARTICLE_CARD_REQUEST: string = 'harmonyx.article_card_request';

export class ArticleCardLaunch {
  kind: string = '';
  postId: string = '';
  query: string = '';
  articleId: string = '';
  title: string = '';
  previewText: string = '';
  coverUrl: string = '';
  label: string = '';
}


export function articleCardItemLaunch(item: ArticleCardItem): ArticleCardLaunch {
  const launch: ArticleCardLaunch = new ArticleCardLaunch();
  launch.kind = item.kind === 'trend' ? 'trend' : item.kind === 'notification' ? 'notification' : 'post';
  launch.postId = item.postId;
  launch.query = item.query;
  launch.title = item.title;
  launch.label = item.label;
  return launch;
}

// The detail page opens immediately with the same preview the reader tapped.
// refreshContent on its route replaces this excerpt with the canonical post.
export function articleCardPostPreview(item: ArticleCardItem, avatarColor: string): Tweet {
  const username: string = item.label.startsWith('@') ? item.label.substring(1) : '';
  return {
    id: item.postId,
    text: item.title,
    author: {
      id: '',
      name: username.length > 0 ? username : item.label,
      username: username,
      avatarUrl: item.avatarUrl,
      avatarColor: avatarColor,
      verified: false
    },
    createdAt: '',
    metrics: { replyCount: 0, repostCount: 0, likeCount: 0, viewCount: 0 },
    liked: false,
    reposted: false
  };
}
