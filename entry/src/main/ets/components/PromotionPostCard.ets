import { common } from '@kit.AbilityKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { Tweet } from '../models/Tweet';
import { TweetCard } from './TweetCard';
import { XXAuthPromotionAssets } from '../services/XXAuthPromotionAssets';
import { XXAuthPromotionMedia, XXAuthPromotionPost } from '../services/XXAuthPromotionPost';
import { emptyPromotionTweet, promotionTweet, XXAuthPromotionAsset } from '../utils/XXAuthPromotionTweet';

// A recommendation rendered with the ordinary post card: the only difference
// from a real row is where the tweet values came from, so the feed keeps one
// layout, one media grid and one set of fonts.
@Component
export struct PromotionPostCard {
  @Prop @Watch('onPostChanged') post: XXAuthPromotionPost = new XXAuthPromotionPost();
  @Prop narrowColumn: boolean = false;
  @State private tweet: Tweet = emptyPromotionTweet();
  onOpen: () => void = (): void => { };
  onHideSession: () => void = (): void => { };
  onHideWeek: () => void = (): void => { };
  private alive: boolean = true;
  private assets: XXAuthPromotionAssets | null = null;
  private resolveSerial: number = 0;
  private createdAt: string = '';

  // Tablets and 2-in-1 devices get the record's large-screen artwork when it has
  // one, so an app's pad screenshots are not shown as phone crops.
  private largeScreen(): boolean {
    const type: string = deviceInfo.deviceType;
    return type === 'tablet' || type.startsWith('2in1');
  }

  aboutToAppear(): void {
    this.alive = true;
    this.createdAt = new Date().toISOString();
    this.resolveAssets();
  }

  aboutToDisappear(): void { this.alive = false; }

  private onPostChanged(): void {
    this.resolveAssets();
  }

  private promotionAssets(): XXAuthPromotionAssets {
    if (this.assets === null) {
      this.assets = new XXAuthPromotionAssets(
        this.getUIContext().getHostContext() as common.UIAbilityContext);
    }
    return this.assets;
  }

  // Market CDN images arrive as octet-stream, so their bytes are cached locally
  // by the app instead of relying on ArkUI's own remote image request. Videos
  // keep their stream and only the poster frame is cached.
  private async resolveAssets(): Promise<void> {
    const serial: number = ++this.resolveSerial;
    const avatar: string = await this.promotionAssets().local(this.post.avatarUrl);
    const media: XXAuthPromotionMedia[] = this.largeScreen() && this.post.mediaPad.length > 0 ?
      this.post.mediaPad : this.post.media;
    const resolved: XXAuthPromotionAsset[] = [];
    for (let i: number = 0; i < media.length; i++) {
      const item: XXAuthPromotionMedia = media[i];
      const asset: XXAuthPromotionAsset = new XXAuthPromotionAsset();
      asset.url = item.video ? item.url : await this.promotionAssets().local(item.url);
      if (item.video && item.poster.length > 0) {
        asset.poster = await this.promotionAssets().local(item.poster);
      }
      resolved.push(asset);
    }
    if (!this.alive || serial !== this.resolveSerial) { return; }
    this.tweet = promotionTweet(this.post, avatar, resolved, this.createdAt, this.largeScreen());
  }

  build(): void {
    TweetCard({
      tweet: this.tweet,
      narrowColumn: this.narrowColumn,
      // The row has no real post behind it, so the interaction row is omitted
      // and every tap leads to the recommended app instead.
      showActions: false,
      promotion: true,
      promotionDismissible: this.post.dismissible !== false,
      videoFeedEnabled: false,
      homeTimelineVideo: false,
      recordRecommendationSeen: false,
      onOpen: (): void => this.onOpen(),
      onAuthorTapped: (): void => this.onOpen(),
      onMentionTapped: (): void => { },
      onPromotionHideSession: (): void => { if (this.post.dismissible !== false) { this.onHideSession(); } },
      onPromotionHideWeek: (): void => { if (this.post.dismissible !== false) { this.onHideWeek(); } }
    })
  }
}
