import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { common } from '@kit.AbilityKit';
import { MaterialButton } from './MaterialButton';
import { SystemMaterialUtil } from '../utils/SystemMaterial';
import promptAction from '@ohos.promptAction';
import { formatCount } from '../models/Tweet';
import type { Tweet } from '../models/Tweet';
import { xPrivateClient, XPrivateResult } from '../services/XPrivateClient';
import { hapticTick } from '../utils/Haptics';
import { sharePost } from '../utils/SharePost';
import { postLikeStore, STORAGE_KEY_POST_LIKES_REVISION } from '../services/PostLikeStore';

// Builder arguments captured by a nested BuilderParam do not subscribe to
// subsequent state changes. Keep icon/count/color as component properties so
// both optimistic updates and rollback redraw the material button content.
@Component
struct MediaViewerCountPill {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Prop symbol: Resource = $r('sys.symbol.heart');
  @Prop count: number = 0;
  @Prop foreground: ResourceColor = $r('app.color.text_on_brand');
  @Prop label: Resource = $r('app.string.action_like');
  @Prop actionEnabled: boolean = true;
  @Prop adaptiveForeground: boolean = false;
  onAction: () => void = (): void => {};

  build(): void {
    MaterialButton({ buttonWidth: '100%', buttonHeight: $r('app.float.media_viewer_action_height'), buttonRadius: 24,
      surfaceColor: $r('app.color.media_viewer_control'), materialLevel: 1, applyShadow: true,
      adaptiveForeground: this.adaptiveForeground, lightColor: this.foreground, buttonEnabled: this.actionEnabled,
      accessibilityLabel: getContext(this).resourceManager.getStringSync(this.label),
      buttonMonopolizeEvents: true, onButtonClick: this.onAction }) {
      Row({ space: 7 }) {
        SymbolGlyph(this.symbol).fontSize(23).fontColor([this.foreground])
        Text(formatCount(this.count)).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
          .fontWeight(FontWeight.Bold).fontColor(this.foreground).maxLines(1).maxFontScale(1.2)
      }.justifyContent(FlexAlign.Center)
    }
  }
}

// Shared pill actions for media viewers; the parent supplies the same live
// like/repost callbacks used by its timeline and opens the conversation sheet.
@Component
export struct MediaViewerPostActions {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Prop @Watch('syncPost') tweet: Tweet;
  @Prop adaptiveForeground: boolean = false;
  @StorageProp(STORAGE_KEY_POST_LIKES_REVISION) @Watch('syncLikeState') private likeRevision: number = 0;
  onOpenPost: () => void = (): void => {};
  onPostChanged: (post: Tweet) => void = (): void => {};
  onLike: (post: Tweet, liked: boolean) => Promise<boolean> = async (): Promise<boolean> => false;
  onRepost: (post: Tweet, reposted: boolean) => Promise<boolean> = async (): Promise<boolean> => false;
  @State private liked: boolean = false;
  @State private reposted: boolean = false;
  @State private bookmarked: boolean = false;
  @State private likes: number = 0;
  @State private reposts: number = 0;
  @State private likePending: boolean = false;
  @State private repostPending: boolean = false;
  @State private bookmarkPending: boolean = false;

  aboutToAppear(): void {
    this.syncPost();
  }

  private syncPost(): void {
    this.syncLikeState();
    this.reposted = this.tweet.reposted;
    this.bookmarked = this.tweet.bookmarked ?? false;
    this.reposts = this.tweet.metrics.repostCount;
  }

  private syncLikeState(): void {
    postLikeStore.apply(this.tweet);
    this.liked = this.tweet.liked;
    this.likes = this.tweet.metrics.likeCount;
  }

  private async toggleLike(): Promise<void> {
    if (this.likePending || postLikeStore.isPending(this.tweet.id)) { return; }
    this.likePending = true;
    const next: boolean = !this.liked;
    const post: Tweet = this.tweet;
    const completion: Promise<boolean> = postLikeStore.setLike(post, next,
      (): Promise<boolean> => this.onLike(post, next));
    this.syncLikeState();
    hapticTick();
    try {
      if (await completion) {
        this.onPostChanged(post);
      }
    } finally {
      this.likePending = false;
      this.syncLikeState();
    }
  }

  private async toggleRepost(): Promise<void> {
    if (this.repostPending) { return; }
    this.repostPending = true;
    const next: boolean = !this.reposted;
    this.reposted = next;
    this.reposts = Math.max(0, this.reposts + (next ? 1 : -1));
    hapticTick();
    try {
      if (await this.onRepost(this.tweet, next)) {
        this.tweet.reposted = next;
        this.tweet.metrics.repostCount = this.reposts;
        this.onPostChanged(this.tweet);
      } else {
        this.reposted = !next;
        this.reposts = Math.max(0, this.reposts + (next ? -1 : 1));
      }
    } catch (error) {
      this.reposted = !next;
      this.reposts = Math.max(0, this.reposts + (next ? -1 : 1));
    } finally {
      this.repostPending = false;
    }
  }

  private async toggleBookmark(): Promise<void> {
    if (this.bookmarkPending) { return; }
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    if (!xPrivateClient.isSignedIn()) {
      promptAction.showToast({ message: context.resourceManager.getStringSync($r('app.string.bookmarks_sign_in')) });
      return;
    }
    const next: boolean = !this.bookmarked;
    this.bookmarkPending = true;
    const result: XPrivateResult = await xPrivateClient.bookmark(this.tweet.id, next);
    this.bookmarkPending = false;
    if (result.ok) {
      this.bookmarked = next;
      this.tweet.bookmarked = next;
      this.onPostChanged(this.tweet);
      hapticTick();
    } else {
      promptAction.showToast({ message: context.resourceManager.getStringSync($r('app.string.action_bookmark')) +
        ' · HTTP ' + result.status });
    }
  }

  @Builder
  private IconPill(symbol: Resource, color: ResourceColor, label: Resource,
    enabled: boolean, action: () => void): void {
    MaterialButton({ buttonWidth: $r('app.float.media_viewer_action_height'),
      buttonHeight: $r('app.float.media_viewer_action_height'), buttonRadius: 24,
      surfaceColor: $r('app.color.media_viewer_control'), materialLevel: 1, applyShadow: true,
      adaptiveForeground: this.adaptiveForeground,
      lightColor: color, buttonEnabled: enabled, accessibilityLabel: this.text(label),
      buttonMonopolizeEvents: true, onButtonClick: action }) {
      SymbolGlyph(symbol).fontSize(24).fontColor([color])
    }
  }

  private text(resource: Resource): string {
    return getContext(this).resourceManager.getStringSync(resource);
  }

  private neutralForeground(): Resource {
    return this.adaptiveForeground && SystemMaterialUtil.isApi26OrAbove() ?
      $r('sys.color.font_primary') : $r('app.color.text_on_brand');
  }

  build(): void {
    Row({ space: 8 }) {
      MediaViewerCountPill({ symbol: $r('sys.symbol.ellipsis_bubble'), count: this.tweet.metrics.replyCount,
        foreground: this.neutralForeground(), label: $r('app.string.action_reply'),
        adaptiveForeground: this.adaptiveForeground, onAction: this.onOpenPost })
        .layoutWeight(1).height($r('app.float.media_viewer_action_height'))
      MediaViewerCountPill({ symbol: $r('sys.symbol.repeat'), count: this.reposts,
        foreground: this.reposted ? $r('app.color.repost') : this.neutralForeground(),
        label: $r('app.string.action_repost'), actionEnabled: !this.repostPending,
        adaptiveForeground: this.adaptiveForeground && !this.reposted,
        onAction: (): void => { void this.toggleRepost(); } })
        .layoutWeight(1).height($r('app.float.media_viewer_action_height')).id('media-viewer-repost')
      MediaViewerCountPill({ symbol: this.liked ? $r('sys.symbol.heart_fill') : $r('sys.symbol.heart'), count: this.likes,
        foreground: this.liked ? $r('app.color.like') : this.neutralForeground(),
        label: $r('app.string.action_like'), actionEnabled: !this.likePending,
        adaptiveForeground: this.adaptiveForeground && !this.liked,
        onAction: (): void => { void this.toggleLike(); } })
        .layoutWeight(1).height($r('app.float.media_viewer_action_height')).id('media-viewer-like')
      this.IconPill(this.bookmarked ? $r('sys.symbol.bookmark_fill') : $r('sys.symbol.bookmark'),
        this.bookmarked ? $r('app.color.brand') : this.neutralForeground(),
        $r('app.string.action_bookmark'), !this.bookmarkPending, (): void => { void this.toggleBookmark(); })
      this.IconPill($r('sys.symbol.share'), this.neutralForeground(), $r('app.string.action_share'),
        true, (): void => { sharePost(getContext(this) as common.UIAbilityContext, this.tweet); })
    }
    .width('100%')
  }
}
