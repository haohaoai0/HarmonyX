import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import util from '@ohos.util';
import { xChatActions } from './XChatActions';
import { backgroundImageStore } from './BackgroundImageStore';

export class ChatBackgroundState {
  presetId: string = 'default';
  path: string = '';
  blur: number = 0;
  dim: number = 0;
  patternStrength: number = 1;
}

export interface ChatBackgroundPreset {
  id: string;
  title: Resource;
  colors: ResourceColor[];
  pattern?: Resource;
  thumbnail?: Resource;
  patternAspect: number;
  angle: number;
}

export function chatBackgroundPresets(): ChatBackgroundPreset[] {
  return [
    { id: 'default', title: $r('app.string.chat_background_default'),
      colors: [$r('app.color.bg_page'), $r('app.color.bg_page')], patternAspect: 1440 / 2960, angle: 180 },
    { id: 'petrel_zoo', title: $r('app.string.chat_background_petrel_zoo'),
      colors: [$r('app.color.chat_background_zoo_1'), $r('app.color.chat_background_zoo_2'), $r('app.color.chat_background_zoo_3'), $r('app.color.chat_background_zoo_4')],
      pattern: $r('app.media.chat_background_petrel_zoo'), thumbnail: $r('app.media.chat_background_petrel_zoo_thumb'),
      patternAspect: 1440 / 2960, angle: 180 },
    { id: 'petrel_snow', title: $r('app.string.chat_background_petrel_snow'),
      colors: [$r('app.color.chat_background_snow_1'), $r('app.color.chat_background_snow_2'), $r('app.color.chat_background_snow_3'), $r('app.color.chat_background_snow_4')],
      pattern: $r('app.media.chat_background_petrel_snow'), thumbnail: $r('app.media.chat_background_petrel_snow_thumb'),
      patternAspect: 1125 / 2436, angle: 180 },
    { id: 'petrel_beach', title: $r('app.string.chat_background_petrel_beach'),
      colors: [$r('app.color.chat_background_beach_1'), $r('app.color.chat_background_beach_2'), $r('app.color.chat_background_beach_3'), $r('app.color.chat_background_beach_4')],
      pattern: $r('app.media.chat_background_petrel_beach'), thumbnail: $r('app.media.chat_background_petrel_beach_thumb'),
      patternAspect: 1440 / 2960, angle: 180 },
    { id: 'petrel_science', title: $r('app.string.chat_background_petrel_science'),
      colors: [$r('app.color.chat_background_science_1'), $r('app.color.chat_background_science_2'), $r('app.color.chat_background_science_3'), $r('app.color.chat_background_science_4')],
      pattern: $r('app.media.chat_background_petrel_science'), thumbnail: $r('app.media.chat_background_petrel_science_thumb'),
      patternAspect: 1125 / 2436, angle: 180 },
    { id: 'petrel_crystal', title: $r('app.string.chat_background_petrel_crystal'),
      colors: [$r('app.color.chat_background_crystal_1'), $r('app.color.chat_background_crystal_2'), $r('app.color.chat_background_crystal_3'), $r('app.color.chat_background_crystal_4')],
      pattern: $r('app.media.chat_background_petrel_crystal'), thumbnail: $r('app.media.chat_background_petrel_crystal_thumb'),
      patternAspect: 1440 / 2960, angle: 180 },
    { id: 'petrel_gifts', title: $r('app.string.chat_background_petrel_gifts'),
      colors: [$r('app.color.chat_background_gifts_1'), $r('app.color.chat_background_gifts_2'), $r('app.color.chat_background_gifts_3')],
      pattern: $r('app.media.chat_background_petrel_gifts'), thumbnail: $r('app.media.chat_background_petrel_gifts_thumb'),
      patternAspect: 1440 / 2960, angle: 180 },
    { id: 'petrel_holiday', title: $r('app.string.chat_background_petrel_holiday'),
      colors: [$r('app.color.chat_background_holiday_1'), $r('app.color.chat_background_holiday_2'), $r('app.color.chat_background_holiday_3'), $r('app.color.chat_background_holiday_4')],
      pattern: $r('app.media.chat_background_petrel_holiday'), thumbnail: $r('app.media.chat_background_petrel_holiday_thumb'),
      patternAspect: 1440 / 2960, angle: 180 },
    { id: 'petrel_games', title: $r('app.string.chat_background_petrel_games'),
      colors: [$r('app.color.chat_background_games_1'), $r('app.color.chat_background_games_2'), $r('app.color.chat_background_games_3'), $r('app.color.chat_background_games_4')],
      pattern: $r('app.media.chat_background_petrel_games'), thumbnail: $r('app.media.chat_background_petrel_games_thumb'),
      patternAspect: 1125 / 2312.5, angle: 180 },
    { id: 'petrel_pets', title: $r('app.string.chat_background_petrel_pets'),
      colors: [$r('app.color.chat_background_pets_1'), $r('app.color.chat_background_pets_2'), $r('app.color.chat_background_pets_3'), $r('app.color.chat_background_pets_4')],
      pattern: $r('app.media.chat_background_petrel_pets'), thumbnail: $r('app.media.chat_background_petrel_pets_thumb'),
      patternAspect: 1440 / 2960, angle: 180 },
    { id: 'petrel_cats', title: $r('app.string.chat_background_petrel_cats'),
      colors: [$r('app.color.chat_background_cats_1'), $r('app.color.chat_background_cats_2'), $r('app.color.chat_background_cats_3'), $r('app.color.chat_background_cats_4')],
      pattern: $r('app.media.chat_background_petrel_cats'), thumbnail: $r('app.media.chat_background_petrel_cats_thumb'),
      patternAspect: 1440 / 2960, angle: 180 },
    { id: 'petrel_nature', title: $r('app.string.chat_background_petrel_nature'),
      colors: [$r('app.color.chat_background_nature_1'), $r('app.color.chat_background_nature_2'), $r('app.color.chat_background_nature_3'), $r('app.color.chat_background_nature_4')],
      pattern: $r('app.media.chat_background_petrel_nature'), thumbnail: $r('app.media.chat_background_petrel_nature_thumb'),
      patternAspect: 1440 / 2960, angle: 180 },
    { id: 'petrel_warm', title: $r('app.string.chat_background_petrel_warm'),
      colors: [$r('app.color.chat_background_warm_1'), $r('app.color.chat_background_warm_2'), $r('app.color.chat_background_warm_3'), $r('app.color.chat_background_warm_4')],
      pattern: $r('app.media.chat_background_petrel_warm'), thumbnail: $r('app.media.chat_background_petrel_warm_thumb'),
      patternAspect: 1440.6 / 2960.1, angle: 180 },
    { id: 'petrel_dream', title: $r('app.string.chat_background_petrel_dream'),
      colors: [$r('app.color.chat_background_dream_1'), $r('app.color.chat_background_dream_2'), $r('app.color.chat_background_dream_3'), $r('app.color.chat_background_dream_4')],
      pattern: $r('app.media.chat_background_petrel_dream'), thumbnail: $r('app.media.chat_background_petrel_dream_thumb'),
      patternAspect: 1440 / 2960, angle: 180 },
    { id: 'petrel_home', title: $r('app.string.chat_background_petrel_home'),
      colors: [$r('app.color.chat_background_home_1'), $r('app.color.chat_background_home_2'), $r('app.color.chat_background_home_3'), $r('app.color.chat_background_home_4')],
      pattern: $r('app.media.chat_background_petrel_home'), thumbnail: $r('app.media.chat_background_petrel_home_thumb'),
      patternAspect: 1440 / 2960, angle: 180 },
    { id: 'petrel_space', title: $r('app.string.chat_background_petrel_space'),
      colors: [$r('app.color.chat_background_space_1'), $r('app.color.chat_background_space_2'), $r('app.color.chat_background_space_3'), $r('app.color.chat_background_space_4')],
      pattern: $r('app.media.chat_background_petrel_space'), thumbnail: $r('app.media.chat_background_petrel_space_thumb'),
      patternAspect: 1440 / 2960, angle: 180 },
    { id: 'petrel_carnival', title: $r('app.string.chat_background_petrel_carnival'),
      colors: [$r('app.color.chat_background_carnival_1'), $r('app.color.chat_background_carnival_2'), $r('app.color.chat_background_carnival_3'), $r('app.color.chat_background_carnival_4')],
      pattern: $r('app.media.chat_background_petrel_carnival'), thumbnail: $r('app.media.chat_background_petrel_carnival_thumb'),
      patternAspect: 1440 / 2960, angle: 180 },
    { id: 'petrel_adventure', title: $r('app.string.chat_background_petrel_adventure'),
      colors: [$r('app.color.chat_background_adventure_1'), $r('app.color.chat_background_adventure_2'), $r('app.color.chat_background_adventure_3')],
      pattern: $r('app.media.chat_background_petrel_adventure'), thumbnail: $r('app.media.chat_background_petrel_adventure_thumb'),
      patternAspect: 1440 / 2960, angle: 180 }
  ];
}

export function chatBackgroundPreset(id: string): ChatBackgroundPreset {
  const presets: ChatBackgroundPreset[] = chatBackgroundPresets();
  for (let i: number = 0; i < presets.length; i++) {
    if (presets[i].id === id) { return presets[i]; }
  }
  return presets[0];
}

export function copyChatBackground(state: ChatBackgroundState): ChatBackgroundState {
  const copy: ChatBackgroundState = new ChatBackgroundState();
  copy.presetId = state.presetId;
  copy.path = state.path;
  copy.blur = state.blur;
  copy.dim = state.dim;
  copy.patternStrength = state.patternStrength;
  return copy;
}

class ChatBackgroundStore {
  private directory(context: common.Context): string { return context.filesDir + '/chat_backgrounds'; }
  private ownsIn(directory: string, path: string): boolean {
    const prefix: string = directory + '/';
    return path.startsWith(prefix) && /^[a-fA-F0-9-]+\.img$/.test(path.substring(prefix.length));
  }

  private owns(context: common.Context, path: string): boolean {
    return this.ownsIn(this.directory(context), path) || backgroundImageStore.owns(context, path);
  }

  load(context: common.Context, conversationId: string): ChatBackgroundState {
    const fallback: ChatBackgroundState = new ChatBackgroundState();
    if (conversationId.length === 0) { return fallback; }
    try {
      const saved: string = xChatActions.localString(context, 'background:' + conversationId, '');
      if (saved.length === 0) { return fallback; }
      const parsed: ChatBackgroundState = JSON.parse(saved) as ChatBackgroundState;
      if (parsed === null || typeof parsed.presetId !== 'string' || typeof parsed.path !== 'string') { return fallback; }
      const state: ChatBackgroundState = new ChatBackgroundState();
      if (parsed.presetId === 'photo') {
        if (!this.owns(context, parsed.path) || !fileIo.accessSync(parsed.path)) { return fallback; }
        state.presetId = 'photo';
        state.path = parsed.path;
      } else {
        state.presetId = chatBackgroundPreset(parsed.presetId).id;
      }
      state.blur = Number.isFinite(parsed.blur) ? Math.max(0, Math.min(30, parsed.blur)) : 0;
      state.dim = Number.isFinite(parsed.dim) ? Math.max(0, Math.min(0.6, parsed.dim)) : 0;
      state.patternStrength = Number.isFinite(parsed.patternStrength) ? Math.max(0, Math.min(1, parsed.patternStrength)) : 1;
      return state;
    } catch (error) { return fallback; }
  }

  save(context: common.Context, conversationId: string, state: ChatBackgroundState): void {
    if (conversationId.length === 0) { throw new Error('missing_conversation'); }
    if (state.presetId === 'photo' && (!this.owns(context, state.path) || !fileIo.accessSync(state.path))) {
      throw new Error('missing_background_image');
    }
    const previous: ChatBackgroundState = this.load(context, conversationId);
    xChatActions.saveLocal(context, 'background:' + conversationId, JSON.stringify(state));
    if (previous.path !== state.path) { this.removePhoto(context, previous.path); }
  }

  // Adapted from Petrelgram's local-wallpaper import: keep a durable sandbox
  // copy and use a unique name so ArkUI never reuses the previous image cache.
  async importPhoto(context: common.Context, uri: string): Promise<string> {
    const directory: string = this.directory(context);
    if (!fileIo.accessSync(directory)) { fileIo.mkdirSync(directory); }
    const destination: string = directory + '/' + util.generateRandomUUID() + '.img';
    let source: fileIo.File | null = null;
    let decoder: image.ImageSource | null = null;
    try {
      source = await fileIo.open(uri, fileIo.OpenMode.READ_ONLY);
      await fileIo.copyFile(source.fd, destination);
      decoder = image.createImageSource(destination);
      const info: image.ImageInfo = await decoder.getImageInfo();
      if (info.size.width <= 0 || info.size.height <= 0) { throw new Error('invalid_background_image'); }
      return destination;
    } catch (error) {
      this.removePhoto(context, destination);
      throw new Error('background_import_failed');
    } finally {
      if (decoder !== null) { try { await decoder.release(); } catch (error) {} }
      if (source !== null) { try { await fileIo.close(source.fd); } catch (error) {} }
    }
  }

  removePhoto(context: common.Context, path: string): void {
    // Library images may be used by several chats and must survive replacement.
    if (!this.ownsIn(this.directory(context), path)) { return; }
    try { fileIo.unlinkSync(path); } catch (error) {}
  }
}

export const chatBackgroundStore: ChatBackgroundStore = new ChatBackgroundStore();
