import type { ProfileArticle } from '../models/Tweet';

export interface PostArticleRouteParam {
  postId: string;
  article: ProfileArticle;
}
