// Bookmark folders are called collections by the Android GraphQL operation
// names.  Keep the app model neutral so either spelling from a response maps
// to the same UI.
export class BookmarkCollection {
  id: string;
  name: string;
  itemCount: number;

  constructor(id: string, name: string, itemCount: number) {
    this.id = id;
    this.name = name;
    this.itemCount = itemCount;
  }
}

// A remote composer draft belongs to a specific post reply or to the root
// composer.  Attachments remain local because X draft payloads only guarantee
// text and reply metadata across client versions.
export class ServerDraftTweet {
  id: string;
  text: string;
  replyToId: string;
  updatedAt: number;

  constructor(id: string, text: string, replyToId: string, updatedAt: number) {
    this.id = id;
    this.text = text;
    this.replyToId = replyToId;
    this.updatedAt = updatedAt;
  }
}
