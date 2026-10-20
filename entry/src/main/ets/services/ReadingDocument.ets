import type { Tweet, ProfileArticle, MediaAttachment } from '../models/Tweet';

export class ReadingParagraph {
  id: string = '';
  postId: string = '';
  authorId: string = '';
  author: string = '';
  text: string = '';
  heading: boolean = false;
  images: string[] = [];
}

export class ReadingDocument {
  id: string = '';
  title: string = '';
  authorId: string = '';
  paragraphs: ReadingParagraph[] = [];
  complete: boolean = true;
}

export class ReadingPosition {
  anchor: string = '';
  progress: number = 0;
  fontSize: number = 18;
  authorOnly: boolean = true;
}

export class ReadingDocuments {
  // Only the explicit ancestor chain and replies reachable from the focal
  // post belong here. Recommendations and orphan replies are never prose.
  static order(root: Tweet, replies: Tweet[]): Tweet[] {
    const posts: Map<string, Tweet> = new Map<string, Tweet>();
    const context: Tweet[] = root.replyContext ?? [];
    for (let i: number = 0; i < context.length; i++) { posts.set(context[i].id, context[i]); }
    for (let i: number = 0; i < replies.length; i++) { posts.set(replies[i].id, replies[i]); }
    posts.set(root.id, root);
    const ancestors: Tweet[] = [];
    const visited: Set<string> = new Set<string>([root.id]);
    let parent: string = root.replyToTweetId ?? '';
    while (parent.length > 0 && !visited.has(parent)) {
      const post: Tweet | undefined = posts.get(parent);
      if (post === undefined) { break; }
      visited.add(parent); ancestors.unshift(post); parent = post.replyToTweetId ?? '';
    }
    const ordered: Tweet[] = [...ancestors, root];
    // Iterative traversal also tolerates malformed cyclic reply metadata.
    const pending: Tweet[] = [root];
    while (pending.length > 0) {
      const current: Tweet = pending.shift() as Tweet;
      const children: Tweet[] = [];
      posts.forEach((post: Tweet): void => {
        if (!visited.has(post.id) && post.replyToTweetId === current.id &&
          (!(post.conversationId ?? '').length || !(root.conversationId ?? '').length ||
            post.conversationId === root.conversationId)) { children.push(post); }
      });
      children.sort((left: Tweet, right: Tweet): number => {
        const authorOrder: number = Number(right.author.id === root.author.id) - Number(left.author.id === root.author.id);
        if (authorOrder !== 0) { return authorOrder; }
        const time: number = Date.parse(left.createdAt) - Date.parse(right.createdAt);
        return Number.isFinite(time) && time !== 0 ? time : left.id.localeCompare(right.id);
      });
      for (let i: number = children.length - 1; i >= 0; i--) { pending.unshift(children[i]); }
      if (current.id !== root.id && !visited.has(current.id)) { ordered.push(current); visited.add(current.id); }
    }
    return ordered;
  }

  static build(root: Tweet, replies: Tweet[] = []): ReadingDocument {
    const document: ReadingDocument = new ReadingDocument();
    document.id = root.id; document.authorId = root.author.id;
    document.title = root.article?.title || root.text.trim().substring(0, 80) || root.author.name;
    const posts: Tweet[] = ReadingDocuments.order(root, replies);
    for (let i: number = 0; i < posts.length; i++) {
      const post: Tweet = posts[i];
      ReadingDocuments.append(document, post, post.text, false);
      const article: ProfileArticle | undefined = post.article;
      if (article !== undefined) {
        ReadingDocuments.append(document, post, article.title, true);
        if ((article.blocks?.length ?? 0) > 0) {
          const blocks = article.blocks ?? [];
          for (let b: number = 0; b < blocks.length; b++) {
            ReadingDocuments.append(document, post, blocks[b].text, blocks[b].kind.startsWith('header'));
            ReadingDocuments.appendImages(document, post, blocks[b].media);
          }
        } else {
          ReadingDocuments.append(document, post, article.plainText || article.previewText, false);
          if (!(article.plainText ?? '').length) { document.complete = false; }
        }
        if (article.coverUrl.length > 0) { ReadingDocuments.image(document, post, article.coverUrl); }
      }
      ReadingDocuments.appendImages(document, post, post.attachments ?? []);
    }
    return document;
  }

  private static append(document: ReadingDocument, post: Tweet, text: string, heading: boolean): void {
    const parts: string[] = text.split(/\n\s*\n/);
    for (let i: number = 0; i < parts.length; i++) {
      // Keep article sections small enough for useful saved scroll anchors.
      for (let start: number = 0; start < parts[i].length; start += 1200) {
        const body: string = parts[i].substring(start, start + 1200).trim();
        if (body.length === 0) { continue; }
        const paragraph: ReadingParagraph = ReadingDocuments.paragraph(document, post);
        paragraph.text = body; paragraph.heading = heading; document.paragraphs.push(paragraph);
      }
    }
  }

  private static paragraph(document: ReadingDocument, post: Tweet): ReadingParagraph {
    const paragraph: ReadingParagraph = new ReadingParagraph();
    paragraph.id = post.id + ':' + document.paragraphs.filter((p: ReadingParagraph): boolean => p.postId === post.id).length.toString();
    paragraph.postId = post.id; paragraph.authorId = post.author.id;
    paragraph.author = post.author.name + ' @' + post.author.username;
    return paragraph;
  }

  private static image(document: ReadingDocument, post: Tweet, url: string): void {
    const paragraph: ReadingParagraph = ReadingDocuments.paragraph(document, post);
    paragraph.images = [url]; document.paragraphs.push(paragraph);
  }

  private static appendImages(document: ReadingDocument, post: Tweet, media: MediaAttachment[]): void {
    for (let i: number = 0; i < media.length; i++) {
      if (media[i].type === 'photo' && media[i].mediaUrl.length > 0) { ReadingDocuments.image(document, post, media[i].mediaUrl); }
    }
  }
}
