import type { MediaAttachment } from './Tweet';

// Serializable, typed card content. Order and destinations are scoped to each
// component/slide; a carousel must never borrow the first slide's link.
export class PostCardAction {
  label: string = '';
  kind: string = 'open';
  url: string = '';
}

export class PostCardPerson {
  id: string = '';
  name: string = '';
  username: string = '';
  avatarUrl: string = '';
  verifiedType: string = '';
  avatarShape: string = '';
}

export class PostCardPart {
  id: string = '';
  kind: string = 'details';
  title: string = '';
  text: string = '';
  url: string = '';
  imageUrl: string = '';
  imageWidth: number = 0;
  imageHeight: number = 0;
  iconUrl: string = '';
  verifiedType: string = '';
  avatarShape: string = '';
  subtitle: string = '';
  price: string = '';
  salePrice: string = '';
  platform: string = '';
  rating: number = 0;
  ratingCount: number = 0;
  memberCount: number = -1;
  startsAt: number = 0;
  endsAt: number = 0;
  media: MediaAttachment[] = [];
  people: PostCardPerson[] = [];
  actions: PostCardAction[] = [];
}

export class PostCardSlide {
  id: string = '';
  parts: PostCardPart[] = [];
}

export class PostCardData {
  name: string = '';
  compact: boolean = false;
  broadcastId: string = '';
  mediaKey: string = '';
  state: string = '';
  viewers: number = -1;
  slides: PostCardSlide[] = [];
}

export class PostDisclosure {
  kind: string = '';
  text: string = '';
  url: string = '';
}

export class PostVisibility {
  text: string = '';
  kind: string = '';
  url: string = '';
  hidden: boolean = false;
  actions: string[] = [];
}

export class CommunityNote {
  id: string = '';
  title: string = '';
  text: string = '';
  subtitle: string = '';
  url: string = '';
  sources: string[] = [];
}

export class PostPresentation {
  note: CommunityNote | undefined = undefined;
  visibility: PostVisibility | undefined = undefined;
  labels: PostDisclosure[] = [];
}

export class ArticleRun {
  text: string = '';
  bold: boolean = false;
  italic: boolean = false;
  underline: boolean = false;
  strike: boolean = false;
  code: boolean = false;
  url: string = '';
}

export class ArticleBlock {
  id: string = '';
  kind: string = 'unstyled';
  text: string = '';
  runs: ArticleRun[] = [];
  media: MediaAttachment[] = [];
  url: string = '';
}
