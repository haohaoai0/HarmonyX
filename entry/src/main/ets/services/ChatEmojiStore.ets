import { common } from '@kit.AbilityKit';
import util from '@ohos.util';
import { xChatActions } from './XChatActions';

export interface ChatEmoji { emoji: string; name: string; keywords: string; }
export interface ChatEmojiGroup { id: string; entries: ChatEmoji[]; }

// Default order from the official XChat bundle. The 14th slot in the quick
// panel is the more button; the full recent section also includes pleading.
export const CHAT_DEFAULT_REACTIONS: string[] = ['🎉', '🔥', '🤠', '💯', '👍', '🤔', '😭', '♥️', '😂', '👎', '😢', '😬', '🧠', '🥺'];
export const CHAT_QUICK_REACTIONS: string[] = CHAT_DEFAULT_REACTIONS.slice(0, 13);

export class ChatEmojiStore {
  private groups: ChatEmojiGroup[] = [];
  load(context: common.Context): ChatEmojiGroup[] {
    if (this.groups.length === 0) {
      const bytes: Uint8Array = context.resourceManager.getRawFileContentSync('chat-emoji-17.json');
      this.groups = JSON.parse(util.TextDecoder.create('utf-8').decodeToString(bytes)) as ChatEmojiGroup[];
    }
    return this.groups;
  }
  recent(context: common.Context): ChatEmoji[] {
    let recent: string[] = [];
    try {
      const saved: string[] = JSON.parse(xChatActions.localString(context, 'recent_emoji', '[]')) as string[];
      if (Array.isArray(saved)) { recent = saved.filter((item: string): boolean => typeof item === 'string' && item.length > 0); }
    } catch (error) {}
    return recent.concat(CHAT_DEFAULT_REACTIONS).filter((value: string, index: number, all: string[]): boolean =>
      all.indexOf(value) === index).slice(0, 28).map((value: string): ChatEmoji => ({ emoji: value, name: value, keywords: value }));
  }
  used(context: common.Context, emoji: string): void {
    const recent: string[] = this.recent(context).map((item: ChatEmoji): string => item.emoji);
    xChatActions.saveLocal(context, 'recent_emoji', JSON.stringify([emoji].concat(recent.filter((e: string): boolean => e !== emoji)).slice(0, 28)));
  }
  search(context: common.Context, query: string): ChatEmojiGroup[] {
    const value: string = query.trim().toLowerCase();
    if (value.length === 0) {
      const recent: ChatEmojiGroup = { id: 'recent', entries: this.recent(context) };
      return [recent].concat(this.load(context));
    }
    return this.load(context).map((group: ChatEmojiGroup): ChatEmojiGroup => ({ id: group.id,
      entries: group.entries.filter((entry: ChatEmoji): boolean => entry.emoji.indexOf(value) >= 0 ||
        entry.name.toLowerCase().indexOf(value) >= 0 || entry.keywords.toLowerCase().indexOf(value) >= 0)
    })).filter((group: ChatEmojiGroup): boolean => group.entries.length > 0);
  }
}

export const chatEmojiStore: ChatEmojiStore = new ChatEmojiStore();
