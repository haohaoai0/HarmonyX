import { common } from '@kit.AbilityKit';
import hilog from '@ohos.hilog';
import type { Tweet } from '../models/Tweet';
import type { TweetPage } from './XApiClient';
import { XPrivateResult, xPrivateClient } from './XPrivateClient';
import { XTimelineParser } from './XTimelineParser';
import { VideoTimelineState, videoAccountKey, videoRecommendationStore } from './VideoRecommendationStore';
import { VideoViewingSession } from './VideoViewingSession';

export class VideoRecommendationPage {
  tweets: Tweet[] = [];
  hasMore: boolean = true;
  error: string = '';
}

// Account + seed own the timeline. A viewer owns delivery/visibility only;
// preloaded cards stay unread when the next viewer resumes the same seed.
export class VideoRecommendationStream {
  private generation: number = xPrivateClient.sessionGeneration();
  private identity: string = xPrivateClient.sessionIdentity();
  private account: string = videoAccountKey(this.identity);
  private seedTweetId: string = '';
  private pageName: string = '';
  private context: common.Context | null = null;
  private state: VideoTimelineState = new VideoTimelineState();
  private excludedIds: Set<string> = new Set<string>();
  private viewingSession: VideoViewingSession | null = null;
  private closed: boolean = false;

  constructor(seedTweetId: string = '', sourceIds: string[] = [], context: common.Context | null = null,
    pageName: string = '') {
    this.seedTweetId = seedTweetId; this.pageName = pageName; this.context = context;
    this.state = videoRecommendationStore.state(context, this.account, seedTweetId);
    for (const id of sourceIds) { this.excludedIds.add(id); }
    if (seedTweetId.length > 0) { this.excludedIds.add(seedTweetId); }
    if (context !== null && /^\d+$/.test(seedTweetId)) { this.viewingSession = new VideoViewingSession(); }
  }

  private sameAccount(): boolean {
    return !this.closed && this.generation === xPrivateClient.sessionGeneration() &&
      this.identity === xPrivateClient.sessionIdentity();
  }

  noteViewed(tweetId: string, index: number = 0): void {
    if (!this.sameAccount()) { return; }
    this.excludedIds.add(tweetId);
    videoRecommendationStore.observe(this.context, this.account, tweetId);
    this.viewingSession?.viewed(tweetId, index);
  }

  flush(): void {
    if (!this.sameAccount()) { return; }
    videoRecommendationStore.flushHistory(this.context, this.account);
    videoRecommendationStore.saveState(this.context, this.state);
    this.viewingSession?.flush();
  }

  close(): void {
    if (this.closed) { return; }
    this.flush(); this.viewingSession?.close(); this.closed = true;
  }

  private takeCached(): Tweet[] {
    const viewed: Set<string> = videoRecommendationStore.viewedIds(this.context, this.account);
    return this.state.tweets.filter((tweet: Tweet): boolean => {
      if (this.excludedIds.has(tweet.id) || viewed.has(tweet.id)) { return false; }
      this.excludedIds.add(tweet.id); return true;
    });
  }

  async nextPage(): Promise<VideoRecommendationPage> {
    const output: VideoRecommendationPage = new VideoRecommendationPage();
    if (!this.sameAccount()) { output.hasMore = false; return output; }
    output.tweets = this.takeCached();
    if (output.tweets.length > 0) {
      output.hasMore = !this.state.exhausted;
      hilog.info(0xFF00, 'HarmonyX-VideoFeed', 'resume provider=%{public}s unread=%{public}d',
        this.state.provider, output.tweets.length);
      return output;
    }
    // A terminal timeline can be refreshed after the web loader's stale window.
    // Keep durable watched ids, so a refreshed first page cannot replay them.
    if (this.state.exhausted && Date.now() - this.state.updatedAt >= 60000) {
      this.state.provider = 'web'; this.state.cursor = ''; this.state.timelineId = '';
      this.state.cursorHistory = []; this.state.exhausted = false;
    }
    if (this.state.exhausted) { output.hasMore = false; return output; }
    const request: Promise<string> = this.state.pending ?? this.fetchPage();
    this.state.pending = request;
    try { output.error = await request; }
    catch (error) { output.error = 'video_recommendation_transport_failure'; }
    finally { if (this.state.pending === request) { this.state.pending = null; } }
    if (!this.sameAccount()) { output.error = ''; output.hasMore = false; return output; }
    if (output.error.length > 0) { return output; }
    output.tweets = this.takeCached(); output.hasMore = !this.state.exhausted;
    return output;
  }

  private canFallback(result: XPrivateResult, page: TweetPage | null): boolean {
    if (result.status === 401 || result.status === 403 || result.status === 429 || result.status < 0) { return false; }
    return result.ok && page === null || result.status === 400 || result.status === 404 ||
      result.status === 410 || result.status === 501 ||
      /unknown_operation|missing_video_timeline|unknown query|query not found|persistedquerynotfound/i.test(result.errorText);
  }

  private errorText(result: XPrivateResult): string {
    return result.operation + ' · HTTP ' + result.status.toString() + ' · ' +
      (result.errorText.length > 0 ? result.errorText : 'invalid_timeline');
  }

  private async fetchPage(): Promise<string> {
    let provider: string = this.state.provider;
    let cursor: string = this.state.cursor;
    let result: XPrivateResult = provider === 'apk' ?
      await xPrivateClient.immersiveVideoTimeline(cursor, cursor.length > 0 ? 40 : 20, this.seedTweetId) :
      cursor.length === 0 ? await xPrivateClient.immersiveMedia(this.seedTweetId, this.pageName) :
        await xPrivateClient.immersiveMediaPage(this.state.timelineId, cursor, 20);
    if (!this.sameAccount()) { return ''; }
    let page: TweetPage | null = result.ok ? XTimelineParser.parse(result.body, false) : null;
    if (provider === 'web' && this.canFallback(result, page)) {
      const primaryError: string = this.errorText(result);
      provider = 'apk'; cursor = '';
      // Cursors are opaque and provider-specific. Start the seed mixer afresh;
      // never hand a web GenericTimelineById cursor to the APK operation.
      result = await xPrivateClient.immersiveVideoTimeline('', 20, this.seedTweetId);
      if (!this.sameAccount()) { return ''; }
      page = result.ok ? XTimelineParser.parse(result.body, false) : null;
      if (!result.ok || page === null) { return primaryError + ' → ' + this.errorText(result); }
      hilog.info(0xFF00, 'HarmonyX-VideoFeed', 'web capability unavailable; using APK seed mixer');
    }
    if (!result.ok || page === null) { return this.errorText(result); }
    if (provider !== this.state.provider) { this.state.cursorHistory = []; this.state.timelineId = ''; }
    this.state.provider = provider;
    if (provider === 'web' && cursor.length === 0) { this.state.timelineId = XTimelineParser.videoTimelineId(result.body); }
    const viewed: Set<string> = videoRecommendationStore.viewedIds(this.context, this.account);
    const ids: Set<string> = new Set<string>();
    this.state.tweets = [...this.state.tweets, ...page.tweets].filter((tweet: Tweet): boolean => {
      if (viewed.has(tweet.id) || ids.has(tweet.id)) { return false; }
      ids.add(tweet.id); return true;
    });
    this.state.tweets = this.state.tweets.slice(-120);
    this.state.exhausted = page.nextToken.length === 0 || page.nextToken === cursor ||
      this.state.cursorHistory.indexOf(page.nextToken) >= 0;
    if (cursor.length > 0) { this.state.cursorHistory.push(cursor); }
    this.state.cursorHistory = this.state.cursorHistory.slice(-64);
    this.state.cursor = page.nextToken; this.state.updatedAt = Date.now();
    videoRecommendationStore.saveState(this.context, this.state);
    hilog.info(0xFF00, 'HarmonyX-VideoFeed', 'page provider=%{public}s HTTP=%{public}d posts=%{public}d timelineId=%{public}s more=%{public}s',
      provider, result.status, page.tweets.length, this.state.timelineId.length > 0 ? 'present' : 'absent',
      this.state.exhausted ? 'false' : 'true');
    return '';
  }
}
