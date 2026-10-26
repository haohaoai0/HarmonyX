class TranslationLink {
  start: number = 0;
  end: number = 0;
  url: string = '';
  token: string = '';
}

// URLs are immutable content. External text translators receive placeholders;
// X translates by post ID, so its returned URL spans are restored separately.
export class TranslationLinks {
  readonly source: string;
  readonly protectedText: string;
  private links: TranslationLink[] = [];

  constructor(source: string) {
    this.source = source;
    this.links = TranslationLinks.find(source);
    let prefix: string = '__HX_LINK_';
    while (source.indexOf(prefix) >= 0) { prefix += '_'; }
    let masked: string = '';
    let cursor: number = 0;
    for (let i: number = 0; i < this.links.length; i++) {
      const link: TranslationLink = this.links[i];
      link.token = prefix + i.toString() + '__';
      masked += source.substring(cursor, link.start) + link.token;
      cursor = link.end;
    }
    this.protectedText = masked + source.substring(cursor);
  }

  onlyLinks(): boolean {
    if (this.links.length === 0) { return false; }
    let prose: string = this.protectedText;
    for (let i: number = 0; i < this.links.length; i++) { prose = prose.replace(this.links[i].token, ''); }
    return prose.replace(/[\s0-9.,:;!?()[\]{}•、，。！？；：\-–—]/g, '').length === 0;
  }

  restoreMasked(translated: string): string | null {
    if (this.links.length === 0 || translated.trim().length === 0) { return translated; }
    const returnedLinks: TranslationLink[] = TranslationLinks.find(translated);
    // A provider may already have preserved the literal addresses. Accept only
    // an exact list, never a translated domain or a newly invented URL.
    if (returnedLinks.length === this.links.length) {
      let exact: boolean = true;
      for (let i: number = 0; i < this.links.length; i++) {
        if (returnedLinks[i].url !== this.links[i].url || translated.indexOf(this.links[i].token) >= 0) {
          exact = false; break;
        }
      }
      if (exact) { return translated; }
    }
    if (returnedLinks.length > 0) { return null; }
    let restored: string = translated;
    for (let i: number = 0; i < this.links.length; i++) {
      const link: TranslationLink = this.links[i];
      const at: number = restored.indexOf(link.token);
      if (at < 0 || restored.lastIndexOf(link.token) !== at) { return null; }
      restored = restored.replace(link.token, link.url);
    }
    return restored;
  }

  restoreX(translated: string): string | null {
    if (this.links.length === 0) { return translated; }
    const returnedLinks: TranslationLink[] = TranslationLinks.find(translated);
    if (returnedLinks.length !== this.links.length) { return null; }
    let restored: string = '';
    let cursor: number = 0;
    for (let i: number = 0; i < returnedLinks.length; i++) {
      restored += translated.substring(cursor, returnedLinks[i].start) + this.links[i].url;
      cursor = returnedLinks[i].end;
    }
    return restored + translated.substring(cursor);
  }

  private static find(text: string): TranslationLink[] {
    const links: TranslationLink[] = [];
    // Include bare website addresses as well as HTTP URLs. Do not capture the
    // domain inside an email address or part of another identifier.
    const pattern: RegExp = /https?:\/\/[^\s<>"'，。！？；（）【】]+|(?:[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?\.)+[A-Za-z]{2,63}(?::[0-9]+)?(?:[/?#][^\s<>"'，。！？；（）【】]*)?/gi;
    let match: RegExpExecArray | null = pattern.exec(text);
    while (match !== null) {
      const start: number = match.index;
      if (start === 0 || !/[A-Za-z0-9_@/]/.test(text.charAt(start - 1))) {
        let value: string = match[0];
        let parentheses: number = 0;
        for (let i: number = 0; i < value.length; i++) {
          if (value.charAt(i) === '(') { parentheses++; }
          if (value.charAt(i) === ')') { parentheses--; }
        }
        while (value.length > 0) {
          const last: string = value.charAt(value.length - 1);
          if (last === ')' && parentheses < 0) { parentheses++; }
          else if (!/[.,!?;:\]}]/.test(last)) { break; }
          value = value.substring(0, value.length - 1);
        }
        const link: TranslationLink = new TranslationLink();
        link.start = start; link.end = start + value.length; link.url = value;
        links.push(link);
      }
      match = pattern.exec(text);
    }
    return links;
  }
}
