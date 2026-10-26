import type { Tweet } from '../models/Tweet';
import type { TweetPage } from './XApiClient';
import { XPrivateResult, xPrivateClient } from './XPrivateClient';
import { XTimelineParser } from './XTimelineParser';
import { VideoRecommendationPage, VideoRecommendationStream } from './VideoRecommendationStream';

// Profile media owns its own cursor. Only a terminal profile page can hand
// delivery over to the seed video's existing recommendation stream.
export class ProfileVideoStream {
  private userId: string;
  private recommendations: VideoRecommendationStream;
  private generation: number = xPrivateClient.sessionGeneration();
  private identity: string = xPrivateClient.sessionIdentity();
  private cursor: string = '';
  private cursors: Set<string> = new Set<string>();
  private exhausted: boolean = false;

  constructor(userId: string, recommendations: VideoRecommendationStream) {
    this.userId = userId;
    this.recommendations = recommendations;
  }

  async nextPage(): Promise<VideoRecommendationPage> {
    const page: VideoRecommendationPage = new VideoRecommendationPage();
    if (this.generation !== xPrivateClient.sessionGeneration() ||
      this.identity !== xPrivateClient.sessionIdentity()) {
      page.hasMore = false;
      return page;
    }
    if (this.exhausted) { return this.recommendations.nextPage(); }
    const cursor: string = this.cursor;
    const result: XPrivateResult = await xPrivateClient.userMedia(this.userId, cursor, 40);
    if (this.generation !== xPrivateClient.sessionGeneration() ||
      this.identity !== xPrivateClient.sessionIdentity()) {
      page.hasMore = false;
      return page;
    }
    const parsed: TweetPage | null = result.ok ? XTimelineParser.parse(result.body) : null;
    if (parsed === null) {
      page.error = result.operation + ' · HTTP ' + result.status.toString();
      return page;
    }
    page.tweets = parsed.tweets.filter((tweet: Tweet): boolean =>
      tweet.author.id === this.userId && tweet.isRepost !== true);
    this.exhausted = parsed.nextToken.length === 0 || parsed.nextToken === cursor ||
      this.cursors.has(parsed.nextToken);
    if (cursor.length > 0) { this.cursors.add(cursor); }
    this.cursor = parsed.nextToken;
    // Even the last profile batch may be followed by recommendations.
    page.hasMore = true;
    return page;
  }
}
