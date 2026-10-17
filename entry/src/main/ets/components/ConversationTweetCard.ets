import type { Tweet, MediaAttachment } from '../models/Tweet';
import { TweetCard } from './TweetCard';
import { replyContextStore } from '../services/ReplyContextStore';

@Component
export struct ConversationTweetCard {
  @Prop @Watch('onTweetChanged') tweet: Tweet;
  @Prop sharedElementId: string = '';
  @Prop showActions: boolean = true;
  @Prop videoFeedEnabled: boolean = false;
  @Prop homeTimelineVideo: boolean = false;
  @Prop recordRecommendationSeen: boolean = false;
  @Prop naturalVideoSize: boolean = true;
  onLikeChanged: (t: Tweet, liked: boolean) => Promise<boolean> = async () => false;
  onRepostChanged: (t: Tweet, reposted: boolean) => Promise<boolean> = async () => false;
  onBookmarkChanged: (t: Tweet, bookmarked: boolean) => void = () => {};
  onReply: (t: Tweet) => void = () => {};
  onOpen: (t: Tweet, sourceId: string) => void = () => {};
  onVideoOpen: (t: Tweet, media: MediaAttachment) => void = () => {};
  onAuthorTapped: (t: Tweet) => void = () => {};
  onMentionTapped: (handle: string) => void = () => {};
  @State private context: Tweet[] = [];
  private alive: boolean = false;
  private visible: boolean = false;
  private generation: number = 0;
  private requestedId: string = '';

  aboutToAppear(): void {
    this.alive = true;
    this.onTweetChanged();
  }

  aboutToDisappear(): void {
    this.alive = false;
    this.generation++;
  }

  private onTweetChanged(): void {
    this.generation++;
    this.context = this.tweet.replyContext ?? [];
    this.requestedId = '';
    this.resolveMissingParent();
  }

  private async resolveMissingParent(): Promise<void> {
    if (!this.alive || !this.visible || this.context.length > 0 ||
      (this.tweet.replyToTweetId ?? '').length === 0 || this.requestedId === this.tweet.id) {
      return;
    }
    this.requestedId = this.tweet.id;
    const generation: number = this.generation;
    const context: Tweet[] = await replyContextStore.resolve(this.tweet);
    if (this.alive && this.generation === generation) {
      this.context = context;
    }
  }

  private sourceId(post: Tweet): string {
    return post.id === this.tweet.id || this.sharedElementId.length === 0 ?
      this.sharedElementId : this.sharedElementId + '-parent-' + post.id;
  }

  @Builder
  private Post(post: Tweet, above: boolean, below: boolean): void {
    TweetCard({
      tweet: post, sharedElementId: this.sourceId(post), showActions: this.showActions,
      videoFeedEnabled: this.videoFeedEnabled, homeTimelineVideo: this.homeTimelineVideo,
      recordRecommendationSeen: this.recordRecommendationSeen,
      naturalVideoSize: this.naturalVideoSize, connectAbove: above, connectBelow: below,
      onLikeChanged: this.onLikeChanged, onRepostChanged: this.onRepostChanged,
      onBookmarkChanged: this.onBookmarkChanged, onReply: this.onReply,
      onOpen: this.onOpen, onVideoOpen: this.onVideoOpen,
      onAuthorTapped: this.onAuthorTapped, onMentionTapped: this.onMentionTapped
    })
  }

  build(): void {
    Column({ space: 0 }) {
      ForEach(this.context, (post: Tweet, index: number) => {
        this.Post(post, index > 0, true)
      }, (post: Tweet): string => this.tweet.id + '-parent-' + post.id)
      this.Post(this.tweet, this.context.length > 0, false)
    }
    .width('100%')
    .onVisibleAreaApproximateChange({ ratios: [0, 0.01], expectedUpdateInterval: 200 },
      (_visible: boolean, ratio: number): void => {
        this.visible = ratio > 0;
        this.resolveMissingParent();
      })
  }
}
