// Plain data shared by the form UI, the form extension and the app process.
// The form runtime receives JSON objects, so this class intentionally has no
// methods or constructor arguments.
export class ArticleCardItem {
  kind: string = 'post';
  postId: string = '';
  query: string = '';
  articleId: string = '';
  title: string = '';
  label: string = '';
  coverUrl: string = '';
  mediaUrl: string = '';
  mediaIsVideo: boolean = false;
  avatarUrl: string = '';
  gradientStart: string = '';
  gradientEnd: string = '';
  score: number = 0;
  savedAt: number = 0;
}

export class ArticleCardFormData {
  cardList: ArticleCardItem[] = [];
  dimension: string = '2*4';
  source: string = 'for_you';
  formImages: Record<string, number> = {};

  constructor(cardList: ArticleCardItem[], dimension: string, source: string) {
    this.cardList = cardList;
    this.dimension = dimension;
    this.source = source;
  }
}
