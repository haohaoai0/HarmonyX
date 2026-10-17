import { common } from '@kit.AbilityKit';
import util from '@ohos.util';

interface ChatEmojiAsset { emoji: string; file: string; }

class ChatEmojiNode {
  children: Map<string, ChatEmojiNode> = new Map();
  file: string = '';
}

export interface ChatEmojiSegment { text: string; file: string; }

// Emoji stay Unicode in the message, clipboard, search and encrypted transport.
// Local Twemoji graphics supply glyphs even when the OS font lacks newer emoji.
export class ChatEmojiImages {
  private root: ChatEmojiNode = new ChatEmojiNode();
  private loaded: boolean = false;
  private cache: Map<string, ChatEmojiSegment[]> = new Map();

  private add(emoji: string, file: string): void {
    let node: ChatEmojiNode = this.root;
    for (let i: number = 0; i < emoji.length; i++) {
      const character: string = emoji.charAt(i);
      let child: ChatEmojiNode | undefined = node.children.get(character);
      if (child === undefined) {
        child = new ChatEmojiNode();
        node.children.set(character, child);
      }
      node = child;
    }
    node.file = file;
  }

  private addVariants(emoji: string, file: string): void {
    // A ZWJ sequence may omit any subset of its emoji presentation selectors.
    // Adding only the fully qualified and completely stripped forms misses
    // partially qualified posts, splitting one emoji into several glyphs.
    const variants: string[] = [''];
    for (let i: number = 0; i < emoji.length; i++) {
      const character: string = emoji.charAt(i);
      const count: number = variants.length;
      for (let j: number = 0; j < count; j++) {
        if (character === '\uFE0F') { variants.push(variants[j]); }
        variants[j] += character;
      }
    }
    variants.forEach((variant: string): void => { this.add(variant, file); });
  }

  private load(context: common.Context): void {
    if (this.loaded) { return; }
    const bytes: Uint8Array = context.resourceManager.getRawFileContentSync('chat-twemoji-17.json');
    const assets: ChatEmojiAsset[] = JSON.parse(util.TextDecoder.create('utf-8').decodeToString(bytes)) as ChatEmojiAsset[];
    assets.forEach((asset: ChatEmojiAsset): void => {
      const file: string = 'chat-twemoji/' + asset.file + '.svg';
      this.addVariants(asset.emoji, file);
    });
    this.loaded = true;
  }

  split(context: common.Context, text: string, systemEmojiEnabled: boolean = false): ChatEmojiSegment[] {
    // Native rendering keeps Unicode in ordinary text spans and needs no assets.
    if (systemEmojiEnabled) { return [{ text: text, file: '' }]; }
    this.load(context);
    const cached: ChatEmojiSegment[] | undefined = this.cache.get(text);
    if (cached !== undefined) { return cached; }
    const segments: ChatEmojiSegment[] = [];
    let plain: string = '';
    let index: number = 0;
    while (index < text.length) {
      let node: ChatEmojiNode = this.root;
      let end: number = index;
      let file: string = '';
      for (let position: number = index; position < text.length; position++) {
        const child: ChatEmojiNode | undefined = node.children.get(text.charAt(position));
        if (child === undefined) { break; }
        node = child;
        // VS15 explicitly requests text presentation; preserve that sequence.
        if (node.file.length > 0 && text.charAt(position + 1) !== '\uFE0E') {
          end = position + 1;
          file = node.file;
        }
      }
      if (file.length === 0) {
        plain += text.charAt(index);
        index++;
        continue;
      }
      if (plain.length > 0) { segments.push({ text: plain, file: '' }); plain = ''; }
      segments.push({ text: text.substring(index, end), file: file });
      index = end;
    }
    if (plain.length > 0) { segments.push({ text: plain, file: '' }); }
    if (this.cache.size >= 128) { this.cache.clear(); }
    this.cache.set(text, segments);
    return segments;
  }

  enlarged(context: common.Context, text: string): boolean {
    const segments: ChatEmojiSegment[] = this.split(context, text.trim());
    const count: number = segments.filter((segment: ChatEmojiSegment): boolean => segment.file.length > 0).length;
    return count > 0 && count <= 3 && segments.every((segment: ChatEmojiSegment): boolean =>
      segment.file.length > 0 || segment.text.trim().length === 0);
  }

  selection(context: common.Context, text: string, start: number, end: number,
    systemEmojiEnabled: boolean = false): string {
    if (systemEmojiEnabled) { return text.substring(start, end); }
    const segments: ChatEmojiSegment[] = this.split(context, text);
    let position: number = 0;
    let selected: string = '';
    for (let i: number = 0; i < segments.length; i++) {
      const segment: ChatEmojiSegment = segments[i];
      const length: number = segment.file.length > 0 ? 1 : segment.text.length;
      if (start < position + length && end > position) {
        selected += segment.file.length > 0 ? segment.text :
          segment.text.substring(Math.max(0, start - position), Math.min(length, end - position));
      }
      position += length;
    }
    return selected;
  }
}

export const chatEmojiImages: ChatEmojiImages = new ChatEmojiImages();
