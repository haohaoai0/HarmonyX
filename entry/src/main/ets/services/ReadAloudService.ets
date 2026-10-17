// Read-aloud bridge over SpeechKit's TextReader.
//
// TextReader owns the TTS engine, the playback panel and the media session, so
// the app only hands it a queue of articles. The engine is process-wide and
// initialising it twice fails, so every caller funnels through one shared
// service instance instead of calling the kit directly.
import { ReadStateCode, TextReader } from '@kit.SpeechKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import type { MediaAttachment, QuotedTweet, Tweet } from '../models/Tweet';
import { formatPostTime } from '../utils/PostTime';

const DOMAIN = 0xFF00;
const TAG = 'HarmonyX-ReadAloud';

// One queued article: the TextReader payload plus the post it came from, so the
// read-aloud page can draw its own queue without re-parsing the engine state.
export class ReadAloudArticle {
  tweet: Tweet;
  readInfo: TextReader.ReadInfo;

  constructor(tweet: Tweet, readInfo: TextReader.ReadInfo) {
    this.tweet = tweet;
    this.readInfo = readInfo;
  }
}

// A post is spoken the way a reader would describe it: the body first, then the
// quoted post, then the media description. Attachments carry the only
// machine-readable description X exposes, so it is worth speaking.
function readAloudBody(tweet: Tweet): string {
  const parts: string[] = [];
  parts.push(tweet.text);
  const quoted: QuotedTweet | undefined = tweet.quotedTweet;
  if (quoted !== undefined) {
    parts.push('引用 ' + quoted.author.name + '（@' + quoted.author.username + '）的内容：' + quoted.text);
  }
  const attachments: MediaAttachment[] | undefined = tweet.attachments;
  if (attachments !== undefined && attachments.length > 0) {
    const altText: string = attachments[0].altText;
    if (altText.length > 0) {
      parts.push('附件描述：' + altText);
    }
  }
  return parts.join('\n');
}

function readAloudCover(tweet: Tweet): string {
  const attachments: MediaAttachment[] | undefined = tweet.attachments;
  if (attachments !== undefined && attachments.length > 0) {
    const preview: string = attachments[0].previewUrl;
    if (preview.length > 0) {
      return preview;
    }
  }
  return tweet.author.avatarUrl ?? '';
}

export function buildReadAloudArticle(tweet: Tweet): ReadAloudArticle {
  const title: TextReader.TextInfo = { text: tweet.author.name, isClickable: true };
  const author: TextReader.TextInfo = {
    text: '@' + tweet.author.username + ' · ' + formatPostTime(tweet.createdAt),
    isClickable: true
  };
  const readInfo: TextReader.ReadInfo = {
    id: tweet.id,
    title: title,
    author: author,
    bodyInfo: readAloudBody(tweet)
  };
  const cover: string = readAloudCover(tweet);
  if (cover.length > 0) {
    readInfo.imageUrl = cover;
  }
  return new ReadAloudArticle(tweet, readInfo);
}

export class ReadAloudService {
  private ready: boolean = false;
  private pending: Promise<boolean> | null = null;
  private listening: boolean = false;
  private stateListener: ((state: TextReader.ReadState) => void) | null = null;

  public isReady(): boolean {
    return this.ready;
  }

  // Idempotent: concurrent callers await the same initialisation.
  public async prepare(context: common.BaseContext): Promise<boolean> {
    if (this.ready) {
      return true;
    }
    const pending: Promise<boolean> | null = this.pending;
    if (pending !== null) {
      return pending;
    }
    this.pending = this.initEngine(context);
    const started: boolean = await this.pending;
    this.pending = null;
    return started;
  }

  private async initEngine(context: common.BaseContext): Promise<boolean> {
    const params: TextReader.ReaderParam = {
      isVoiceBrandVisible: true,
      // Keeps the queue audible after the user leaves the page; the manifest
      // declares the matching background mode and permission.
      keepBackgroundRunning: true,
      businessBrandInfo: { panelName: 'Harmony X' }
    };
    try {
      await TextReader.init(context, params);
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      hilog.error(DOMAIN, TAG, 'TextReader.init failed: %{public}d %{public}s',
        failure.code, failure.message);
      return false;
    }
    this.ready = true;
    this.bindListeners();
    return true;
  }

  private bindListeners(): void {
    if (this.listening) {
      return;
    }
    this.listening = true;
    TextReader.on('stateChange', (state: TextReader.ReadState): void => {
      const listener: ((state: TextReader.ReadState) => void) | null = this.stateListener;
      if (listener !== null) {
        listener(state);
      }
    });
    // The panel asks for a tail when the queue runs out. A post thread is
    // finite, so answering with an empty tail is what marks the end.
    TextReader.on('requestMore', (): void => {
      TextReader.loadMore([], true);
    });
  }

  public setStateListener(listener: ((state: TextReader.ReadState) => void) | null): void {
    this.stateListener = listener;
  }

  public async start(articles: ReadAloudArticle[], startId: string): Promise<boolean> {
    const queue: TextReader.ReadInfo[] = [];
    for (let index = 0; index < articles.length; index++) {
      queue.push(articles[index].readInfo);
    }
    if (queue.length === 0) {
      return false;
    }
    try {
      await TextReader.start(queue, startId);
      return true;
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      hilog.error(DOMAIN, TAG, 'TextReader.start failed: %{public}d %{public}s',
        failure.code, failure.message);
      return false;
    }
  }

  public pause(): void {
    try {
      TextReader.pause();
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      hilog.warn(DOMAIN, TAG, 'TextReader.pause failed: %{public}d', failure.code);
    }
  }

  public resume(): void {
    try {
      TextReader.resume();
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      hilog.warn(DOMAIN, TAG, 'TextReader.resume failed: %{public}d', failure.code);
    }
  }

  public playPrevious(): void {
    try {
      TextReader.playPrev();
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      hilog.warn(DOMAIN, TAG, 'TextReader.playPrev failed: %{public}d', failure.code);
    }
  }

  public playNext(): void {
    try {
      TextReader.playNext();
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      hilog.warn(DOMAIN, TAG, 'TextReader.playNext failed: %{public}d', failure.code);
    }
  }

  public async stop(): Promise<void> {
    try {
      await TextReader.stop();
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      hilog.warn(DOMAIN, TAG, 'TextReader.stop failed: %{public}d', failure.code);
    }
  }

  // Only meaningful on phone and tablet: the 2-in-1 panel needs its own window
  // stage, so the read-aloud page owns the controls there.
  public showPanel(): void {
    try {
      TextReader.showPanel();
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      hilog.warn(DOMAIN, TAG, 'TextReader.showPanel failed: %{public}d', failure.code);
    }
  }

  public stateOf(articleId: string): ReadStateCode {
    try {
      return TextReader.queryReadState(articleId).state;
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      hilog.warn(DOMAIN, TAG, 'TextReader.queryReadState failed: %{public}d', failure.code);
      return ReadStateCode.NOT_IN_READ_LIST;
    }
  }
}

let sharedService: ReadAloudService | null = null;

export function readAloudService(): ReadAloudService {
  if (sharedService === null) {
    sharedService = new ReadAloudService();
  }
  return sharedService;
}
