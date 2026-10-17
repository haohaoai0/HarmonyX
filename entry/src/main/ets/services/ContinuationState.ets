// Owns the small, non-sensitive state that HarmonyOS transfers during an
// application continuation.  Login credentials, cookies and device-local
// media URIs deliberately never enter this bridge.

export const CONTINUATION_KIND_HOME: string = 'home';
export const CONTINUATION_KIND_POST: string = 'post';
export const CONTINUATION_KIND_COMPOSER: string = 'composer';

export const CONTINUATION_RESTORE_REQUEST_KEY: string = 'harmonyx.continuation.restore_request';
export const CONTINUATION_WANT_KIND: string = 'harmonyx.continuation.kind';
export const CONTINUATION_WANT_POST_ID: string = 'harmonyx.continuation.post_id';
export const CONTINUATION_WANT_SCROLL_OFFSET: string = 'harmonyx.continuation.scroll_offset';
export const CONTINUATION_WANT_REPLY_SORT: string = 'harmonyx.continuation.reply_sort';
export const CONTINUATION_WANT_DRAFT_TEXT: string = 'harmonyx.continuation.draft_text';
export const CONTINUATION_WANT_REPLY_TO_ID: string = 'harmonyx.continuation.reply_to_id';
export const CONTINUATION_WANT_REPLY_TO_USER: string = 'harmonyx.continuation.reply_to_user';

const STATE_KIND_KEY: string = 'harmonyx.continuation.state.kind';
const STATE_POST_ID_KEY: string = 'harmonyx.continuation.state.post_id';
const STATE_SCROLL_OFFSET_KEY: string = 'harmonyx.continuation.state.scroll_offset';
const STATE_REPLY_SORT_KEY: string = 'harmonyx.continuation.state.reply_sort';
const STATE_DRAFT_TEXT_KEY: string = 'harmonyx.continuation.state.draft_text';
const STATE_REPLY_TO_ID_KEY: string = 'harmonyx.continuation.state.reply_to_id';
const STATE_REPLY_TO_USER_KEY: string = 'harmonyx.continuation.state.reply_to_user';
const MAX_DRAFT_LENGTH: number = 8000;

export class ContinuationState {
  kind: string;
  postId: string;
  scrollOffset: number;
  replySortMode: string;
  draftText: string;
  replyToId: string;
  replyToUser: string;

  constructor(kind: string, postId: string, scrollOffset: number, replySortMode: string,
    draftText: string, replyToId: string, replyToUser: string) {
    this.kind = kind;
    this.postId = postId;
    this.scrollOffset = scrollOffset;
    this.replySortMode = replySortMode;
    this.draftText = draftText;
    this.replyToId = replyToId;
    this.replyToUser = replyToUser;
  }
}

export class ContinuationStore {
  publishHome(): void {
    this.save(new ContinuationState(CONTINUATION_KIND_HOME, '', 0, '', '', '', ''));
  }

  publishPost(postId: string, scrollOffset: number, replySortMode: string): void {
    if (postId.length === 0) {
      return;
    }
    this.save(new ContinuationState(CONTINUATION_KIND_POST, postId,
      Math.max(0, scrollOffset), replySortMode, '', '', ''));
  }

  publishComposer(draftText: string, replyToId: string, replyToUser: string): void {
    const text: string = draftText.length > MAX_DRAFT_LENGTH ?
      draftText.substring(0, MAX_DRAFT_LENGTH) : draftText;
    this.save(new ContinuationState(CONTINUATION_KIND_COMPOSER, '', 0, '', text,
      replyToId, replyToUser));
  }

  current(): ContinuationState {
    const kind: string = AppStorage.get<string>(STATE_KIND_KEY) ?? CONTINUATION_KIND_HOME;
    const postId: string = AppStorage.get<string>(STATE_POST_ID_KEY) ?? '';
    const scrollOffset: number = AppStorage.get<number>(STATE_SCROLL_OFFSET_KEY) ?? 0;
    const replySortMode: string = AppStorage.get<string>(STATE_REPLY_SORT_KEY) ?? '';
    const draftText: string = AppStorage.get<string>(STATE_DRAFT_TEXT_KEY) ?? '';
    const replyToId: string = AppStorage.get<string>(STATE_REPLY_TO_ID_KEY) ?? '';
    const replyToUser: string = AppStorage.get<string>(STATE_REPLY_TO_USER_KEY) ?? '';
    return new ContinuationState(kind, postId, Math.max(0, scrollOffset), replySortMode,
      draftText, replyToId, replyToUser);
  }

  writeToWant(wantParam: Record<string, Object>): void {
    const state: ContinuationState = this.current();
    wantParam[CONTINUATION_WANT_KIND] = state.kind;
    wantParam[CONTINUATION_WANT_POST_ID] = state.postId;
    wantParam[CONTINUATION_WANT_SCROLL_OFFSET] = state.scrollOffset;
    wantParam[CONTINUATION_WANT_REPLY_SORT] = state.replySortMode;
    wantParam[CONTINUATION_WANT_DRAFT_TEXT] = state.draftText;
    wantParam[CONTINUATION_WANT_REPLY_TO_ID] = state.replyToId;
    wantParam[CONTINUATION_WANT_REPLY_TO_USER] = state.replyToUser;
  }

  restoreFromWant(wantParam: Record<string, Object> | undefined): boolean {
    if (wantParam === undefined) {
      return false;
    }
    const kindValue: Object | undefined = wantParam[CONTINUATION_WANT_KIND];
    if (typeof kindValue !== 'string' || !this.isSupportedKind(kindValue)) {
      return false;
    }
    const postId: string = this.readString(wantParam[CONTINUATION_WANT_POST_ID]);
    const replySortMode: string = this.readString(wantParam[CONTINUATION_WANT_REPLY_SORT]);
    const draftText: string = this.readString(wantParam[CONTINUATION_WANT_DRAFT_TEXT]);
    const replyToId: string = this.readString(wantParam[CONTINUATION_WANT_REPLY_TO_ID]);
    const replyToUser: string = this.readString(wantParam[CONTINUATION_WANT_REPLY_TO_USER]);
    const scrollOffset: number = this.readNonNegativeNumber(wantParam[CONTINUATION_WANT_SCROLL_OFFSET]);
    this.save(new ContinuationState(kindValue, postId, scrollOffset, replySortMode,
      draftText, replyToId, replyToUser));
    const currentRequest: number = AppStorage.get<number>(CONTINUATION_RESTORE_REQUEST_KEY) ?? 0;
    AppStorage.setOrCreate<number>(CONTINUATION_RESTORE_REQUEST_KEY, currentRequest + 1);
    return true;
  }

  private save(state: ContinuationState): void {
    AppStorage.setOrCreate<string>(STATE_KIND_KEY, state.kind);
    AppStorage.setOrCreate<string>(STATE_POST_ID_KEY, state.postId);
    AppStorage.setOrCreate<number>(STATE_SCROLL_OFFSET_KEY, state.scrollOffset);
    AppStorage.setOrCreate<string>(STATE_REPLY_SORT_KEY, state.replySortMode);
    AppStorage.setOrCreate<string>(STATE_DRAFT_TEXT_KEY, state.draftText);
    AppStorage.setOrCreate<string>(STATE_REPLY_TO_ID_KEY, state.replyToId);
    AppStorage.setOrCreate<string>(STATE_REPLY_TO_USER_KEY, state.replyToUser);
  }

  private readString(value: Object | undefined): string {
    if (typeof value !== 'string') {
      return '';
    }
    return value.length > MAX_DRAFT_LENGTH ? value.substring(0, MAX_DRAFT_LENGTH) : value;
  }

  private readNonNegativeNumber(value: Object | undefined): number {
    if (typeof value !== 'number' || value < 0) {
      return 0;
    }
    return value;
  }

  private isSupportedKind(kind: string): boolean {
    return kind === CONTINUATION_KIND_HOME || kind === CONTINUATION_KIND_POST ||
      kind === CONTINUATION_KIND_COMPOSER;
  }
}

export const continuationStore: ContinuationStore = new ContinuationStore();
