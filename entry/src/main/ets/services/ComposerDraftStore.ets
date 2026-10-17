// Persists one compose draft and independent reply drafts by post id.
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { ComposerOptions } from '../models/ComposerOptions';

export class ComposerDraft {
  text: string;
  imageUris: string[];
  gifUri: string;
  videoUri: string;
  updatedAt: number;
  options: ComposerOptions = new ComposerOptions();

  constructor(text: string, imageUris: string[], gifUri: string, videoUri: string, updatedAt: number) {
    this.text = text;
    this.imageUris = imageUris;
    this.gifUri = gifUri;
    this.videoUri = videoUri;
    this.updatedAt = updatedAt;
  }
}

export class ComposerDraftStore {
  private static readonly STORE_NAME: string = 'harmonyx_composer';
  private static readonly MAX_MEDIA_ITEMS: number = 4;

  load(context: common.Context, scope: string): ComposerDraft {
    try {
      const options: preferences.Options = { name: ComposerDraftStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      const prefix: string = this.prefix(scope);
      const text: string = store.getSync(prefix + 'text', '') as string;
      const storedGifUri: string = store.getSync(prefix + 'gif', '') as string;
      const videoUri: string = store.getSync(prefix + 'video', '') as string;
      const gifUri: string = videoUri.length > 0 ? '' : storedGifUri;
      const maxImageCount: number = videoUri.length > 0 ? 0 :
        ComposerDraftStore.MAX_MEDIA_ITEMS - (gifUri.length > 0 ? 1 : 0);
      const rawImages: string = store.getSync(prefix + 'images', '[]') as string;
      const parsed: string[] = JSON.parse(rawImages) as string[];
      const imageUris: string[] = [];
      for (let i: number = 0; i < parsed.length && imageUris.length < maxImageCount; i++) {
        const uri: string = String(parsed[i]);
        if (uri.length > 0 && imageUris.indexOf(uri) < 0) {
          imageUris.push(uri);
        }
      }
      const updatedAt: number = store.getSync(prefix + 'updated_at', 0) as number;
      const draft: ComposerDraft = new ComposerDraft(text, imageUris, gifUri, videoUri, updatedAt);
      draft.options = ComposerOptions.restore(store.getSync(prefix + 'options', '{}') as string);
      // Older drafts can carry attachments; never restore an incompatible poll.
      if (imageUris.length > 0 || gifUri.length > 0 || videoUri.length > 0) {
        draft.options.pollChoices = []; draft.options.pollImages = [];
      }
      return draft;
    } catch (error) {
      return new ComposerDraft('', [], '', '', 0);
    }
  }

  save(context: common.Context, scope: string, draft: ComposerDraft): void {
    try {
      const options: preferences.Options = { name: ComposerDraftStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      const prefix: string = this.prefix(scope);
      store.putSync(prefix + 'text', draft.text);
      store.putSync(prefix + 'images', JSON.stringify(draft.imageUris));
      store.putSync(prefix + 'gif', draft.gifUri);
      store.putSync(prefix + 'video', draft.videoUri);
      store.putSync(prefix + 'updated_at', draft.updatedAt);
      store.putSync(prefix + 'options', JSON.stringify(draft.options));
      store.flushSync();
    } catch (error) {
      // A draft is a convenience; a write failure must not block composing.
    }
  }

  clear(context: common.Context, scope: string): void {
    this.save(context, scope, new ComposerDraft('', [], '', '', 0));
  }

  private prefix(scope: string): string {
    return 'draft_' + scope + '_';
  }
}

export const composerDraftStore: ComposerDraftStore = new ComposerDraftStore();
