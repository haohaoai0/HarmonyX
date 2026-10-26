// Splits post text so @handles, #hashtags and links can render as separate
// tappable spans.
//
// X treats a mention or hashtag as starting at '@' / '#' when the preceding
// character is not part of a word, which is what keeps an address like
// "a@b.com" from turning into a mention. A handle stops at the first character
// outside [A-Za-z0-9_]; a hashtag also accepts non-ASCII letters so Chinese
// tags stay intact.
export class MentionSegment {
  text: string = '';
  mention: boolean = false;
  handle: string = '';
  hashtag: string = '';
  url: string = '';

  constructor(text: string, mention: boolean, handle: string, hashtag: string, url: string) {
    this.text = text;
    this.mention = mention;
    this.handle = handle;
    this.hashtag = hashtag;
    this.url = url;
  }
}

function isHandleChar(character: string): boolean {
  if (character >= 'a' && character <= 'z') {
    return true;
  }
  if (character >= 'A' && character <= 'Z') {
    return true;
  }
  if (character >= '0' && character <= '9') {
    return true;
  }
  return character === '_';
}

function isWordChar(character: string): boolean {
  return isHandleChar(character);
}

// Hashtags allow any non-ASCII letter (Chinese, Japanese, Cyrillic...), which
// is what X does, plus the ASCII handle set.
function isHashtagChar(character: string): boolean {
  if (isHandleChar(character)) {
    return true;
  }
  return character.charCodeAt(0) > 0x7F;
}

function linkPrefixLength(input: string, index: number): number {
  const rest: string = input.substring(index).toLowerCase();
  if (rest.startsWith('https://')) {
    return 8;
  }
  if (rest.startsWith('http://')) {
    return 7;
  }
  return 0;
}

function isTrailingNoise(character: string): boolean {
  return character === '.' || character === ',' ||
    character === '，' || character === '。';
}

export function splitPostText(input: string): MentionSegment[] {
  const segments: MentionSegment[] = [];
  let plain: string = '';
  let index: number = 0;
  while (index < input.length) {
    const character: string = input.charAt(index);
    const precededByWord: boolean = index > 0 && isWordChar(input.charAt(index - 1));
    if (character === '@') {
      let end: number = index + 1;
      while (end < input.length && isHandleChar(input.charAt(end))) {
        end += 1;
      }
      if (!precededByWord && end > index + 1) {
        if (plain.length > 0) {
          segments.push(new MentionSegment(plain, false, '', '', ''));
          plain = '';
        }
        segments.push(new MentionSegment(input.substring(index, end), true,
          input.substring(index + 1, end), '', ''));
        index = end;
        continue;
      }
    }
    if (character === '#') {
      let end: number = index + 1;
      while (end < input.length && isHashtagChar(input.charAt(end))) {
        end += 1;
      }
      if (!precededByWord && end > index + 1) {
        if (plain.length > 0) {
          segments.push(new MentionSegment(plain, false, '', '', ''));
          plain = '';
        }
        segments.push(new MentionSegment(input.substring(index, end), false, '',
          input.substring(index + 1, end), ''));
        index = end;
        continue;
      }
    }
    const prefix: number = linkPrefixLength(input, index);
    if (prefix > 0) {
      let end: number = index + prefix;
      while (end < input.length && !isWhitespace(input.charAt(end))) {
        end += 1;
      }
      let parentheses: number = 0;
      for (let cursor: number = index + prefix; cursor < end; cursor++) {
        if (input.charAt(cursor) === '(') { parentheses++; }
        if (input.charAt(cursor) === ')') { parentheses--; }
      }
      while (end > index + prefix) {
        const last: string = input.charAt(end - 1);
        if (last === ')' && parentheses < 0) {
          parentheses++;
        } else if (!isTrailingNoise(last)) {
          break;
        }
        end -= 1;
      }
      if (end > index + prefix) {
        if (plain.length > 0) {
          segments.push(new MentionSegment(plain, false, '', '', ''));
          plain = '';
        }
        const link: string = input.substring(index, end);
        // Keep the complete destination for taps while showing the original
        // site's address in the same compact form as X (example.com).
        const label: string = link.replace(/^https?:\/\//i, '').replace(/^([^/?#]+)\/$/, '$1');
        segments.push(new MentionSegment(label, false, '', '', link));
        index = end;
        continue;
      }
    }
    plain += character;
    index += 1;
  }
  if (plain.length > 0) {
    segments.push(new MentionSegment(plain, false, '', '', ''));
  }
  return segments;
}

function isWhitespace(character: string): boolean {
  return character === ' ' || character === '\t' || character === '\n' ||
    character === '\r' || character === '\u3000';
}
