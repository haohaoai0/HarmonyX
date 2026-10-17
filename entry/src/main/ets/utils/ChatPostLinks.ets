import type { DmAttachment, DmMessage } from '../models/Tweet';
import { classifyXLink, X_LINK_POST } from './XLinkRouter';

export class ChatLinkSegment {
  text: string = '';
  url: string = '';

  constructor(text: string, url: string = '') {
    this.text = text;
    this.url = url;
  }
}

export class ChatPostLink {
  postId: string = '';
  url: string = '';

  constructor(postId: string, url: string) {
    this.postId = postId;
    this.url = url;
  }
}

// Preserve the original message, including punctuation and emoji, while making
// only complete http(s) tokens interactive. Handles and hashtags stay DM text.
export function splitChatLinks(text: string): ChatLinkSegment[] {
  const result: ChatLinkSegment[] = [];
  const pattern: RegExp = /https?:\/\/[^\s<>"\u3000\u3002\uff0c\uff1b\uff1a\uff01\uff1f\uff08\uff09\u3010\u3011\u300c\u300d\u300e\u300f\u201c\u201d\u2018\u2019]+/gi;
  let position: number = 0;
  let match: RegExpExecArray | null = pattern.exec(text);
  while (match !== null) {
    const link: string = match[0].replace(/[.,;:!?\)\]\}\u3002\uff0c\uff01\uff1f\uff09\u3011\u300d\u300f\u201d\u2019]+$/, '');
    if (link.length > 0) {
      if (match.index > position) { result.push(new ChatLinkSegment(text.substring(position, match.index))); }
      result.push(new ChatLinkSegment(link, link));
      position = match.index + link.length;
    }
    match = pattern.exec(text);
  }
  if (position < text.length) { result.push(new ChatLinkSegment(text.substring(position))); }
  return result;
}

export function chatPostLink(raw: string): ChatPostLink | null {
  const target = classifyXLink(raw);
  return target !== null && target.kind === X_LINK_POST ? new ChatPostLink(target.postId, raw) : null;
}

// What the message says besides its links. X shows only the card when a shared
// post is the whole message, so the raw t.co/status URL must not repeat above it.
export function chatTextWithoutLinks(text: string): string {
  let plain: string = '';
  const parts: ChatLinkSegment[] = splitChatLinks(text);
  for (let i: number = 0; i < parts.length; i++) {
    if (parts[i].url.length === 0) { plain += parts[i].text; }
  }
  return plain.trim();
}

// A shared post can be present in both the body and an authenticated XChat
// Post attachment. Deduplicate by status ID, including alternate host/query forms.
export function chatPostLinks(message: DmMessage): ChatPostLink[] {
  const urls: string[] = splitChatLinks(message.text).filter((part: ChatLinkSegment): boolean => part.url.length > 0)
    .map((part: ChatLinkSegment): string => part.url);
  const attachments: DmAttachment[] = message.attachments ?? [];
  for (let i: number = 0; i < attachments.length; i++) {
    if (attachments[i].type !== 'Media' && attachments[i].url.length > 0) { urls.push(attachments[i].url); }
  }
  const result: ChatPostLink[] = [];
  for (let i: number = 0; i < urls.length; i++) {
    const post: ChatPostLink | null = chatPostLink(urls[i]);
    if (post !== null && !result.some((item: ChatPostLink): boolean => item.postId === post.postId)) { result.push(post); }
  }
  return result;
}
