// Post detail destination. It lives inside the root HdsNavigation stack to
// share the native secondary-page transition and immersive title bar pattern
// used by PaperTalk's HdsNavDestination child pages.
import {
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  hdsEffect,
  hdsMaterial,
  ScrollEffectType
} from '@kit.UIDesignKit';
import common from '@ohos.app.ability.common';
import promptAction from '@ohos.promptAction';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { deviceInfo } from '@kit.BasicServicesKit';
import { uiMaterial } from '@kit.ArkUI';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { harmonyShare, systemShare } from '@kit.ShareKit';
import { TweetCard } from '../components/TweetCard';
import { PostMedia } from '../components/PostMedia';
import { ReplyComposerCapsuleBuilder } from '../components/ReplyComposer';
import type { ReplyComposerContext, ReplyComposerRouteParam } from '../components/ReplyComposer';
import { formatCount } from '../models/Tweet';
import type { Tweet, UserProfile } from '../models/Tweet';
import { XApiClient } from '../services/XApiClient';
import { authStore } from '../services/AuthStore';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';

export interface PostDetailRouteParam {
  tweet: Tweet;
}

@Builder
export function PostDetailBuilder(): void {
  PostDetail();
}

@Component
export struct PostDetail {
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp('harmonyx.status_bar_height') statusBarHeight: number =
    AppStorage.get<number>('harmonyx.status_bar_height') ?? 0;
  @StorageProp('harmonyx.navigation_indicator_height') navigationIndicatorHeight: number =
    AppStorage.get<number>('harmonyx.navigation_indicator_height') ?? 0;
  @StorageLink('harmonyx.accent_color') accentColor: string = '#007DFF';
  @StorageLink('harmonyx.font_scale') fontScale: number = 1;
  @State tweet: Tweet | null = null;
  @State replies: Tweet[] = [];
  @State currentProfile: UserProfile | null = null;
  @State threadStatus: string = '';
  @State refreshing: boolean = false;
  @State liked: boolean = false;
  @State reposted: boolean = false;
  @State bookmarked: boolean = false;
  @State gestureSharing: boolean = false;
  private scroller: Scroller = new Scroller();
  private api: XApiClient = new XApiClient();
  private gestureShareListening: boolean = false;
  private gestureSharePreviewPostId: string = '';
  private gestureSharePreviewUri: string = '';
  private gesturesShareCallback: (target: harmonyShare.SharableTarget) => void =
    (target: harmonyShare.SharableTarget): void => {
      this.sharePostByGesture(target);
    };

  private cardMaterial(): uiMaterial.Material | undefined {
    if (!deviceInfo.apiAvailable('26.0.0')) {
      return undefined;
    }
    return new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.REGULAR,
      applyShadow: true,
      colorInvert: true
    });
  }

  private inputMaterial(): uiMaterial.Material | undefined {
    if (!deviceInfo.apiAvailable('26.0.0')) {
      return undefined;
    }
    return new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.THIN,
      interactive: true,
      applyShadow: true,
      colorInvert: true,
      lightEffect: { color: this.accentColor }
    });
  }

  aboutToAppear(): void {
    // The route parameter is ready on the next frame after the destination
    // mounts, matching the child-page handoff used in PaperTalk.
    setTimeout((): void => {
      this.loadRouteParam();
      this.loadLiveThread();
      this.registerGesturesShare();
    }, 50);
  }

  aboutToDisappear(): void {
    this.unregisterGesturesShare();
  }

  private loadRouteParam(): void {
    const params: PostDetailRouteParam[] =
      this.pageStack.getParamByName('PostDetail') as PostDetailRouteParam[];
    if (params === undefined || params === null || params.length === 0) {
      return;
    }
    const param: PostDetailRouteParam = params[params.length - 1];
    if (param !== undefined && param !== null) {
      this.tweet = param.tweet;
      this.syncActionStates(param.tweet);
      this.prepareGestureSharePreview();
    }
  }

  private syncActionStates(tweet: Tweet): void {
    this.liked = tweet.liked;
    this.reposted = tweet.reposted;
  }

  private isXPostId(value: string): boolean {
    if (value.length === 0) {
      return false;
    }
    for (let i = 0; i < value.length; i++) {
      const code: number = value.charCodeAt(i);
      if (code < 48 || code > 57) {
        return false;
      }
    }
    return true;
  }

  private async loadLiveThread(): Promise<void> {
    const current: Tweet | null = this.tweet;
    if (current === null) {
      return;
    }
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    await authStore.load(context);
    if (authStore.isSignedIn()) {
      this.api.setToken(authStore.getToken());
      this.api.setUser(authStore.getUserId());
      this.currentProfile = await this.api.profile();
    }
    if (!this.isXPostId(current.id)) {
      this.threadStatus = this.text($r('app.string.post_detail_local_only'));
      this.refreshing = false;
      return;
    }
    if (!authStore.isSignedIn()) {
      this.threadStatus = this.text($r('app.string.post_detail_sign_in'));
      this.refreshing = false;
      return;
    }
    const latest: Tweet | null = await this.api.tweetById(current.id);
    if (latest !== null) {
      this.tweet = latest;
      this.syncActionStates(latest);
      this.prepareGestureSharePreview();
    }
    const liveReplies: Tweet[] | null = await this.api.conversationReplies(current.id);
    if (liveReplies !== null) {
      this.replies = liveReplies;
      this.threadStatus = liveReplies.length > 0 ? this.text($r('app.string.post_detail_live')) :
        this.text($r('app.string.post_detail_no_replies'));
    } else {
      this.replies = [];
      this.threadStatus = this.text($r('app.string.post_detail_unavailable'));
    }
    this.refreshing = false;
  }

  private onRefresh(): void {
    this.refreshing = true;
    this.loadLiveThread();
  }

  private text(resource: Resource): string {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    return context.resourceManager.getStringSync(resource);
  }

  private openPost(tweet: Tweet): void {
    const param: PostDetailRouteParam = { tweet: tweet };
    this.pageStack.pushPath({ name: 'PostDetail', param: param });
  }

  private replyComposerContext(): ReplyComposerContext {
    const profile: UserProfile | null = this.currentProfile;
    const fallbackName: string = authStore.getUsername().length > 0 ? authStore.getUsername() :
      this.text($r('app.string.tab_me'));
    return {
      replyToId: this.tweet === null ? '' : this.tweet.id,
      replyToUser: this.tweet === null ? '' : this.tweet.author.username,
      avatarUrl: profile === null || profile.avatarUrl === undefined ? '' : profile.avatarUrl,
      avatarName: profile === null ? fallbackName : profile.name,
      avatarColor: this.accentColor,
      accentColor: this.accentColor
    };
  }

  private openReplyComposer(text: string, imageUri: string, gifUri: string): void {
    const context: ReplyComposerContext = this.replyComposerContext();
    const param: ReplyComposerRouteParam = {
      replyToId: context.replyToId,
      replyToUser: context.replyToUser,
      avatarUrl: context.avatarUrl,
      avatarName: context.avatarName,
      avatarColor: context.avatarColor,
      initialText: text,
      imageUri: imageUri,
      gifUri: gifUri
    };
    this.pageStack.pushPath({ name: 'ReplyComposer', param: param });
  }

  private showSignInRequired(action: Resource): void {
    promptAction.showToast({
      message: this.text($r('app.string.toast_sign_in_to_prefix')) + this.text(action),
      duration: 2000
    });
  }

  private syncActionAvailable(): boolean {
    return authStore.isSignedIn() && authStore.getUserId().length > 0;
  }

  private rollbackLike(post: Tweet, liked: boolean): void {
    this.liked = !liked;
    post.liked = !liked;
    if (liked && post.metrics.likeCount > 0) {
      post.metrics.likeCount -= 1;
    } else if (!liked) {
      post.metrics.likeCount += 1;
    }
  }

  private toggleLike(): void {
    const post: Tweet | null = this.tweet;
    if (post === null) {
      return;
    }
    if (!this.syncActionAvailable()) {
      this.showSignInRequired($r('app.string.action_like_posts'));
      return;
    }
    const nextLiked: boolean = !this.liked;
    this.liked = nextLiked;
    post.liked = nextLiked;
    if (nextLiked) {
      post.metrics.likeCount += 1;
    } else if (post.metrics.likeCount > 0) {
      post.metrics.likeCount -= 1;
    }
    if (!this.isXPostId(post.id)) {
      return;
    }
    this.api.setLike(post.id, nextLiked).then((ok: boolean): void => {
      if (!ok) {
        this.rollbackLike(post, nextLiked);
        promptAction.showToast({
          message: this.text($r('app.string.action_like')) + this.text($r('app.string.api_unreachable_suffix')),
          duration: 2000
        });
      }
    });
  }

  private rollbackRepost(post: Tweet, reposted: boolean): void {
    this.reposted = !reposted;
    post.reposted = !reposted;
    if (reposted && post.metrics.repostCount > 0) {
      post.metrics.repostCount -= 1;
    } else if (!reposted) {
      post.metrics.repostCount += 1;
    }
  }

  private toggleRepost(): void {
    const post: Tweet | null = this.tweet;
    if (post === null) {
      return;
    }
    if (!this.syncActionAvailable()) {
      this.showSignInRequired($r('app.string.action_repost'));
      return;
    }
    const nextReposted: boolean = !this.reposted;
    this.reposted = nextReposted;
    post.reposted = nextReposted;
    if (nextReposted) {
      post.metrics.repostCount += 1;
    } else if (post.metrics.repostCount > 0) {
      post.metrics.repostCount -= 1;
    }
    if (!this.isXPostId(post.id)) {
      return;
    }
    this.api.setRepost(post.id, nextReposted).then((ok: boolean): void => {
      if (!ok) {
        this.rollbackRepost(post, nextReposted);
        promptAction.showToast({
          message: this.text($r('app.string.action_repost')) + this.text($r('app.string.api_unreachable_suffix')),
          duration: 2000
        });
      }
    });
  }

  private toggleBookmark(): void {
    this.bookmarked = !this.bookmarked;
    const message: Resource = this.bookmarked ? $r('app.string.toast_bookmark_added') :
      $r('app.string.toast_bookmark_removed');
    promptAction.showToast({ message: this.text(message), duration: 1500 });
  }

  private postShareUrl(post: Tweet): string {
    return 'https://x.com/' + encodeURIComponent(post.author.username) + '/status/' + encodeURIComponent(post.id);
  }

  private registerGesturesShare(): void {
    if (this.gestureShareListening || !canIUse('SystemCapability.Collaboration.HarmonyShare')) {
      return;
    }
    try {
      harmonyShare.on('gesturesShare', this.gesturesShareCallback);
      this.gestureShareListening = true;
    } catch {
      this.gestureShareListening = false;
    }
  }

  private unregisterGesturesShare(): void {
    if (!this.gestureShareListening) {
      return;
    }
    try {
      harmonyShare.off('gesturesShare', this.gesturesShareCallback);
    } catch {
      // The page is already leaving, so the listener state can be safely discarded.
    }
    this.gestureShareListening = false;
  }

  private createGestureShareData(post: Tweet, thumbnailUri: string): systemShare.SharedData {
    if (thumbnailUri.length > 0) {
      return new systemShare.SharedData({
        utd: utd.UniformDataType.HYPERLINK,
        content: this.postShareUrl(post),
        thumbnailUri: thumbnailUri,
        title: post.author.name + ' on X',
        description: post.text
      });
    }
    return new systemShare.SharedData({
      utd: utd.UniformDataType.HYPERLINK,
      content: this.postShareUrl(post),
      title: post.author.name + ' on X',
      description: post.text
    });
  }

  private async captureGestureSharePreview(post: Tweet): Promise<string> {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const previewPath: string = context.filesDir + '/harmonyx-post-' + post.id + '.png';
    try {
      const pixelMap: image.PixelMap = await this.getUIContext().getComponentSnapshot().createFromBuilder(
        (): void => {
          this.GestureSharePreview();
        }, 0, true, { scale: 1, waitUntilRenderFinished: true });
      const packer: image.ImagePacker = image.createImagePacker();
      const data: ArrayBuffer = await packer.packToData(pixelMap, { format: 'image/png', quality: 100 });
      const file: fileIo.File = fileIo.openSync(previewPath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);
      try {
        fileIo.writeSync(file.fd, data);
      } finally {
        fileIo.closeSync(file.fd);
      }
      return fileUri.getUriFromPath(previewPath);
    } catch {
      return '';
    }
  }

  private async prepareGestureSharePreview(): Promise<void> {
    const post: Tweet | null = this.tweet;
    if (post === null || this.gestureSharePreviewPostId === post.id) {
      return;
    }
    const previewUri: string = await this.captureGestureSharePreview(post);
    if (this.tweet !== null && this.tweet.id === post.id) {
      this.gestureSharePreviewPostId = post.id;
      this.gestureSharePreviewUri = previewUri;
    }
  }

  private async sharePostByGesture(target: harmonyShare.SharableTarget): Promise<void> {
    const post: Tweet | null = this.tweet;
    if (post === null) {
      return;
    }
    if (this.gestureSharePreviewPostId !== post.id) {
      await this.prepareGestureSharePreview();
    }
    this.gestureSharing = true;
    try {
      const shareData: systemShare.SharedData = this.createGestureShareData(post, this.gestureSharePreviewUri);
      await target.share(shareData);
    } catch {
      promptAction.showToast({ message: this.text($r('app.string.share_failed')), duration: 2000 });
    }
    this.gestureSharing = false;
  }

  private async shareCurrentPost(): Promise<void> {
    const post: Tweet | null = this.tweet;
    if (post === null) {
      return;
    }
    const sharedData: systemShare.SharedData = new systemShare.SharedData({
      utd: utd.UniformDataType.HYPERLINK,
      content: this.postShareUrl(post),
      title: post.author.name + ' on X',
      description: post.text
    });
    const controller: systemShare.ShareController = new systemShare.ShareController(sharedData);
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    try {
      await controller.show(context, {
        selectionMode: systemShare.SelectionMode.SINGLE,
        previewMode: systemShare.SharePreviewMode.DEFAULT
      });
    } catch {
      promptAction.showToast({ message: this.text($r('app.string.share_failed')), duration: 2000 });
    }
  }

  @Builder
  private ReplyComposerBar(): void {
    ReplyComposerCapsuleBuilder(this.replyComposerContext(),
      (text: string, imageUri: string, gifUri: string): void => {
        this.openReplyComposer(text, imageUri, gifUri);
      });
  }

  @Builder
  private Metric(value: number, label: Resource): void {
    Column({ space: 2 }) {
      Text(formatCount(value))
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Text(label)
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private PostAction(symbol: Resource, count: number, label: Resource, active: boolean, activeColor: ResourceColor,
    showCount: boolean, onClick: () => void): void {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: 5 }) {
        SymbolGlyph(symbol)
          .fontSize(active ? 29 : 27)
          .fontColor([active ? activeColor : $r('app.color.text_secondary')])
          .scale({ x: active ? 1.08 : 1, y: active ? 1.08 : 1 })
          .animation({ duration: 150, curve: Curve.EaseOut })
        if (showCount) {
          Text(formatCount(count))
            .fontSize(15)
            .fontColor(active ? activeColor : $r('app.color.text_secondary'))
            .animation({ duration: 150, curve: Curve.EaseOut })
        }
      }
      .justifyContent(FlexAlign.Center)
    }
    .layoutWeight(1)
    .height(52)
    .padding(0)
    .backgroundColor(Color.Transparent)
    .accessibilityText(this.text(label))
    .onClick(onClick)
  }

  @Builder
  private PostActions(): void {
    if (this.tweet !== null) {
      Row() {
        this.PostAction($r('sys.symbol.ellipsis_bubble'), this.tweet.metrics.replyCount,
          $r('app.string.action_reply'), false, this.accentColor, true,
          (): void => this.openReplyComposer('', '', ''))
        this.PostAction($r('sys.symbol.repeat'), this.tweet.metrics.repostCount,
          $r('app.string.action_repost'), this.reposted, $r('app.color.repost'), true,
          (): void => this.toggleRepost())
        this.PostAction(this.liked ? $r('sys.symbol.heart_fill') : $r('sys.symbol.heart'),
          this.tweet.metrics.likeCount, $r('app.string.action_like'), this.liked, $r('app.color.like'), true,
          (): void => this.toggleLike())
        this.PostAction(this.bookmarked ? $r('sys.symbol.bookmark_fill') : $r('sys.symbol.bookmark'), 0,
          $r('app.string.action_bookmark'), this.bookmarked, this.accentColor, false,
          (): void => this.toggleBookmark())
        this.PostAction($r('sys.symbol.share'), 0, $r('app.string.action_share'), false, this.accentColor, false,
          (): void => {
            this.shareCurrentPost();
          })
      }
      .width('100%')
      .padding({ left: 4, right: 4, top: 2, bottom: 2 })
      .backgroundColor($r('app.color.bg_card'))
      .systemMaterial(this.cardMaterial())
      .borderRadius(16)
      .visualEffect(new hdsEffect.HdsEffectBuilder()
        .pointLight({
          illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
        })
        .buildEffect())
    }
  }

  @Builder
  private GestureSharePreview(): void {
    if (this.tweet !== null) {
      Column({ space: 12 }) {
        Row({ space: 10 }) {
          Image($r('app.media.icon'))
            .width(32)
            .height(32)
            .borderRadius(8)
            .syncLoad(true)
          Column({ space: 2 }) {
            Text($r('app.string.EntryAbility_label'))
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
            Text('@' + this.tweet.author.username)
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        Text(this.tweet.text)
          .width('100%')
          .fontSize(17)
          .fontColor($r('app.color.text_primary'))
          .maxLines(6)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.postShareUrl(this.tweet))
          .width('100%')
          .fontSize(12)
          .fontColor(this.accentColor)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width(320)
      .padding(20)
      .backgroundColor($r('app.color.bg_page'))
      .border({ width: 1, color: $r('app.color.divider') })
      .borderRadius(20)
    }
  }

  @Builder
  private PostHero(): void {
    if (this.tweet !== null) {
      Column({ space: 12 }) {
        Row({ space: 12 }) {
          if (this.tweet.author.avatarUrl !== undefined && this.tweet.author.avatarUrl.length > 0) {
            Image(this.tweet.author.avatarUrl)
              .width(48)
              .height(48)
              .objectFit(ImageFit.Cover)
              .borderRadius(24)
              .clip(true)
          } else {
            Text(this.tweet.author.name.substring(0, 1).toUpperCase())
              .width(48)
              .height(48)
              .fontSize(21)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_on_brand'))
              .backgroundColor(this.tweet.author.avatarColor)
              .borderRadius(24)
              .textAlign(TextAlign.Center)
          }
          Column({ space: 2 }) {
            Row({ space: 5 }) {
              Text(this.tweet.author.name)
                .fontSize(17)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
              if (this.tweet.author.verified) {
                SymbolGlyph($r('sys.symbol.checkmark'))
                  .fontSize(14)
                  .fontColor([this.accentColor])
              }
            }
            Text('@' + this.tweet.author.username)
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          Button($r('app.string.profile_following'), { stateEffect: true })
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_on_brand'))
            .backgroundColor($r('app.color.text_primary'))
            .borderRadius(18)
        }
        .width('100%')
        Text(this.tweet.text)
          .fontSize(19)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
        if (this.tweet.attachments !== undefined && this.tweet.attachments.length > 0) {
          PostMedia({ attachments: this.tweet.attachments })
        }
        Text(this.tweet.createdAt + ' · ' + formatCount(this.tweet.metrics.viewCount) + ' ' +
          this.text($r('app.string.post_detail_views')))
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
      }
      .width('100%')
      .padding({ left: 4, right: 4, top: 6, bottom: 4 })
      .scale({ x: this.gestureSharing ? 0.82 : 1, y: this.gestureSharing ? 0.82 : 1 })
      .opacity(this.gestureSharing ? 0.72 : 1)
      .renderGroup(true)
      .animation({ duration: 180, curve: Curve.EaseOut })
    }
  }

  @Builder
  private ContentBuilder(): void {
    if (this.tweet === null) {
      Column() {
        LoadingProgress().color(this.accentColor)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    } else {
      Refresh({ refreshing: $$this.refreshing }) {
      Stack({ alignContent: Alignment.Bottom }) {
      Scroll(this.scroller) {
        Column({ space: 16 }) {
          this.PostHero()

          this.PostActions()

          Text(this.threadStatus)
            .width('100%')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .padding({ left: 4, right: 4, top: 4 })

          if (this.replies.length > 0) {
            Text($r('app.string.post_detail_replies'))
              .width('100%')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .padding({ left: 4, right: 4, top: 8 })
          }
          ForEach(this.replies, (reply: Tweet) => {
            TweetCard({
              tweet: reply,
              showActions: false,
              onOpen: (selected: Tweet): void => this.openPost(selected)
            })
          }, (reply: Tweet) => reply.id)

        }
        .width('100%')
        .padding({
          left: 12,
          right: 12,
          top: this.statusBarHeight + 64,
          bottom: this.navigationIndicatorHeight + 92
        })
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      Column() {
        this.ReplyComposerBar();
      }
      .width('100%')
      .padding({ left: 12, right: 12, bottom: this.navigationIndicatorHeight + 12 })
      }
      .width('100%')
      .height('100%')
      }
      .width('100%')
      .height('100%')
      .onRefreshing((): void => this.onRefresh())
    }
  }

  build(): void {
    HdsNavDestination() {
      this.ContentBuilder();
    }
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .hideBackButton(false)
    .onBackPressed((): boolean => {
      ResponsiveLayout.closeContentDestination(this.pageStack);
      return true;
    })
    .bindToScrollable([this.scroller])
    .titleBar({
      avoidLayoutSafeArea: true,
      content: { title: { mainTitle: $r('app.string.post_detail_title') } },
      style: {
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.IMMERSIVE,
          materialLevel: hdsMaterial.MaterialLevel.EXQUISITE
        }
      }
    })
    .backgroundColor($r('app.color.bg_page'));
  }
}
