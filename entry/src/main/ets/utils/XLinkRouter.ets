// x.com links that arrive from other apps. The system starts the app as the
// handler of the tapped link (the "打开方式" chooser lists us next to the
// browsers), and the root page uses this module to decide which in-app surface
// the link belongs to.
import { url } from '@kit.ArkTS';

// Written by EntryAbility with the link the system delivered, consumed once by
// the root page so a later page appearance does not replay it.
export const STORAGE_KEY_EXTERNAL_LINK: string = 'harmonyx.external_link_request';

export const X_LINK_POST: string = 'post';
export const X_LINK_PROFILE: string = 'profile';
export const X_LINK_SEARCH: string = 'search';
export const X_LINK_COMMUNITY: string = 'community';
export const X_LINK_LIST: string = 'list';
export const X_LINK_SPACE: string = 'space';
export const X_LINK_ARTICLE: string = 'article';
export const X_LINK_MESSAGES: string = 'messages';
export const X_LINK_OTHER: string = 'other';

// Hosts X serves links from. The browser lowercases scheme and host before the
// implicit-Want match, so the same lowercase form has to be listed here.
const X_HOSTS: string[] = [
  'x.com',
  'www.x.com',
  'mobile.x.com',
  'twitter.com',
  'www.twitter.com',
  'mobile.twitter.com'
];

// First path segments that belong to the product rather than to a user handle,
// so `x.com/i/premium_sign_up` is not mistaken for the profile of `i`.
const RESERVED_ROOTS: string[] = [
  'i', 'home', 'explore', 'notifications', 'messages', 'settings', 'search',
  'compose', 'intent', 'share', 'login', 'logout', 'signup', 'tos', 'privacy',
  'about', 'jobs', 'download', 'account', 'following', 'followers', 'lists',
  'bookmarks', 'communities', 'premium', 'topics'
];

export class XLinkTarget {
  kind: string = X_LINK_OTHER;
  // Status id for a post, handle for a profile, tag for a hashtag, or id for a Community.
  postId: string = '';
  handle: string = '';
  query: string = '';
  communityId: string = '';
  listId: string = '';
  spaceId: string = '';
  articleId: string = '';
  // The link as it arrived, which is what the web sheet loads.
  link: string = '';

  constructor(kind: string, postId: string, handle: string, query: string,
    communityId: string, link: string) {
    this.kind = kind;
    this.postId = postId;
    this.handle = handle;
    this.query = query;
    this.communityId = communityId;
    this.link = link;
  }
}

function parseUrl(raw: string): url.URL | null {
  try {
    return url.URL.parseURL(raw);
  } catch (error) {
    return null;
  }
}

function isDigits(value: string): boolean {
  if (value.length === 0) {
    return false;
  }
  for (let i: number = 0; i < value.length; i++) {
    const code: number = value.charCodeAt(i);
    if (code < 48 || code > 57) {
      return false;
    }
  }
  return true;
}

function contains(values: string[], value: string): boolean {
  for (let i: number = 0; i < values.length; i++) {
    if (values[i] === value) {
      return true;
    }
  }
  return false;
}

function pathSegments(pathname: string): string[] {
  const segments: string[] = [];
  let start: number = 0;
  for (let i: number = 0; i <= pathname.length; i++) {
    const atEnd: boolean = i === pathname.length;
    if (atEnd || pathname.charCodeAt(i) === 47) {
      if (i > start) {
        segments.push(pathname.substring(start, i));
      }
      start = i + 1;
    }
  }
  return segments;
}

// Returns null when the link is not an http(s) link on an X host, which tells
// the caller the link was not meant for this app.
export function classifyXLink(raw: string): XLinkTarget | null {
  if (raw.length === 0) {
    return null;
  }
  const parsed: url.URL | null = parseUrl(raw);
  if (parsed === null) {
    return null;
  }
  const scheme: string = parsed.protocol.toLowerCase();
  if (scheme !== 'http:' && scheme !== 'https:') {
    return null;
  }
  if (!contains(X_HOSTS, parsed.hostname.toLowerCase())) {
    return null;
  }
  const segments: string[] = pathSegments(parsed.pathname);
  if (segments.length === 0) {
    return new XLinkTarget(X_LINK_OTHER, '', '', '', '', raw);
  }
  const first: string = segments[0].toLowerCase();
  if (first === 'i' && segments.length > 2 && segments[1].toLowerCase() === 'article' && isDigits(segments[2])) {
    const target: XLinkTarget = new XLinkTarget(X_LINK_ARTICLE, '', '', '', '', raw);
    target.articleId = segments[2]; return target;
  }
  if (first === 'messages') {
    return new XLinkTarget(X_LINK_MESSAGES, '', '', '', '', raw);
  }
  if (first === 'i' && segments.length >= 2 && segments[1].toLowerCase() === 'spaces') {
    const target: XLinkTarget = new XLinkTarget(X_LINK_SPACE, '', '', '', '', raw);
    if (segments.length > 2) {
      if (!/^[A-Za-z0-9]{5,64}$/.test(segments[2])) { return new XLinkTarget(X_LINK_OTHER, '', '', '', '', raw); }
      target.spaceId = segments[2];
    }
    return target;
  }
  if (first === 'i' && segments.length === 2 && segments[1].toLowerCase() === 'lists') {
    return new XLinkTarget(X_LINK_LIST, '', '', '', '', raw);
  }
  if (first === 'i' && segments.length > 2 && segments[1].toLowerCase() === 'lists' && isDigits(segments[2])) {
    const target: XLinkTarget = new XLinkTarget(X_LINK_LIST, '', '', '', '', raw);
    target.listId = segments[2];
    return target;
  }
  if (first === 'i' && segments.length > 2 && segments[1].toLowerCase() === 'communities' &&
    isDigits(segments[2])) {
    return new XLinkTarget(X_LINK_COMMUNITY, '', '', '', segments[2], raw);
  }
  if (first === 'hashtag' && segments.length > 1) {
    return new XLinkTarget(X_LINK_SEARCH, '', '', segments[1], '', raw);
  }
  if (first === 'status' && segments.length > 1 && isDigits(segments[1])) {
    return new XLinkTarget(X_LINK_POST, segments[1], '', '', '', raw);
  }
  if (first === 'i' && segments.length > 3 && segments[1].toLowerCase() === 'web' &&
    segments[2].toLowerCase() === 'status' && isDigits(segments[3])) {
    return new XLinkTarget(X_LINK_POST, segments[3], '', '', '', raw);
  }
  // Canonical post links are /<handle>/status/<id>; the trailing /photo/1 or
  // /analytics segments some clients append do not change the target.
  if (segments.length > 2 && segments[1].toLowerCase() === 'status' && isDigits(segments[2])) {
    return new XLinkTarget(X_LINK_POST, segments[2], segments[0], '', '', raw);
  }
  if (segments.length === 1 && !contains(RESERVED_ROOTS, first)) {
    return new XLinkTarget(X_LINK_PROFILE, '', segments[0], '', '', raw);
  }
  return new XLinkTarget(X_LINK_OTHER, '', '', '', '', raw);
}

// Trailing punctuation that a sentence around the link can leave behind, e.g.
// "see https://x.com/foo." — the url has to be cut before it is parsed.
function trimTrailingPunctuation(value: string): string {
  let end: number = value.length;
  while (end > 0) {
    const last: string = value.charAt(end - 1);
    if (last === ',' || last === '.' || last === ';' || last === ':' || last === ')' ||
      last === ']' || last === '}' || last === '>' || last === '!' || last === '?' || last === '"' ||
      last === "'" || last === '。' || last === '，' || last === '）' || last === '】') {
      end--;
    } else {
      break;
    }
  }
  return value.substring(0, end);
}

// Shared text usually embeds the link in a sentence, so the first http(s) token
// that turns out to be an X link is what this returns.
export function firstXLink(text: string): string {
  let index: number = 0;
  while (index < text.length) {
    const at: number = text.indexOf('http', index);
    if (at < 0) {
      return '';
    }
    let end: number = at;
    while (end < text.length) {
      const code: number = text.charCodeAt(end);
      if (code === 32 || code === 9 || code === 10 || code === 13) {
        break;
      }
      end++;
    }
    const candidate: string = trimTrailingPunctuation(text.substring(at, end));
    if (classifyXLink(candidate) !== null) {
      return candidate;
    }
    index = end + 1;
  }
  return '';
}
