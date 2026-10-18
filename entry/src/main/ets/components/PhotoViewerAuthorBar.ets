import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { common } from '@kit.AbilityKit';
import promptAction from '@ohos.promptAction';
import type { TweetAuthor, UserProfile } from '../models/Tweet';
import { followStateStore, STORAGE_KEY_FOLLOW_REVISION } from '../services/FollowStateStore';
import { xPrivateClient, XPrivateResult } from '../services/XPrivateClient';
import { XUserParser } from '../services/XUserParser';
import { verificationBadgeColor } from '../utils/UserIdentity';
import { SystemMaterialUtil } from '../utils/SystemMaterial';
import { hapticTick } from '../utils/Haptics';
import { MaterialButton } from './MaterialButton';
import { ProxyAvatar } from './ProxyAvatar';

@Component
export struct PhotoViewerAuthorBar {
  @Prop @Watch('onAuthorChanged') author: TweetAuthor;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp('harmonyx.accent_color') private accentColor: string = '#007DFF';
  @StorageProp(STORAGE_KEY_FOLLOW_REVISION) @Watch('syncFollowState') private followRevision: number = 0;
  @State private following: boolean = false;
  @State private followPending: boolean = false;
  private alive: boolean = false;
  private authorGeneration: number = 0;
  onOpenAuthor: () => void = (): void => {};

  aboutToAppear(): void {
    this.alive = true;
    this.onAuthorChanged();
  }

  aboutToDisappear(): void {
    this.alive = false;
    this.authorGeneration += 1;
  }

  private text(resource: Resource): string {
    return (getContext(this) as common.UIAbilityContext).resourceManager.getStringSync(resource);
  }

  private dimension(resource: Resource): number {
    return this.getUIContext().px2vp((getContext(this) as common.UIAbilityContext).resourceManager.getNumber(resource.id));
  }

  private onAuthorChanged(): void {
    this.authorGeneration += 1;
    this.followPending = false;
    this.syncFollowState();
    if (this.alive) { void this.loadFollowState(); }
  }

  private syncFollowState(): void {
    this.following = followStateStore.get(xPrivateClient.viewerId(), this.author.id) ??
      this.author.following ?? false;
  }

  private isOwnAuthor(): boolean {
    return this.author.id.length > 0 && this.author.id === xPrivateClient.viewerId();
  }

  private async loadFollowState(): Promise<void> {
    const viewer: string = xPrivateClient.viewerId();
    const userId: string = this.author.id;
    if (!xPrivateClient.isSignedIn() || this.isOwnAuthor() || userId.length === 0 ||
      this.author.following !== undefined || followStateStore.get(viewer, userId) !== undefined) { return; }
    const generation: number = this.authorGeneration;
    const session: number = xPrivateClient.sessionGeneration();
    try {
      const result: XPrivateResult = await xPrivateClient.userByRestId(userId);
      if (!this.alive || generation !== this.authorGeneration || viewer !== xPrivateClient.viewerId() ||
        session !== xPrivateClient.sessionGeneration() || this.followPending ||
        followStateStore.get(viewer, userId) !== undefined || !result.ok) { return; }
      const profile: UserProfile | null = XUserParser.parse(result.body);
      if (profile !== null && profile.id === userId && profile.following !== undefined) {
        followStateStore.set(viewer, userId, profile.following);
        this.syncFollowState();
      }
    } catch (error) {
      // Keep the relationship supplied with the post if the profile is unavailable.
    }
  }

  private async toggleFollow(): Promise<void> {
    if (this.followPending || this.isOwnAuthor() || this.author.id.length === 0) { return; }
    if (!xPrivateClient.isSignedIn()) {
      promptAction.showToast({ message: this.text($r('app.string.profile_follow_sign_in')) });
      return;
    }
    this.syncFollowState();
    const viewer: string = xPrivateClient.viewerId();
    const session: number = xPrivateClient.sessionGeneration();
    const userId: string = this.author.id;
    const generation: number = this.authorGeneration;
    const next: boolean = !this.following;
    this.followPending = true;
    try {
      const result: XPrivateResult = await xPrivateClient.follow(userId, next);
      if (viewer !== xPrivateClient.viewerId() || session !== xPrivateClient.sessionGeneration()) { return; }
      if (result.ok) {
        // Publish success even if the reader has already closed the viewer.
        followStateStore.set(viewer, userId, next);
        if (this.alive && generation === this.authorGeneration) {
          this.following = next;
          hapticTick();
        }
      } else if (this.alive && generation === this.authorGeneration) {
        promptAction.showToast({ message: this.text($r('app.string.profile_follow_failed')) });
      }
    } catch (error) {
      if (this.alive && generation === this.authorGeneration && viewer === xPrivateClient.viewerId() &&
        session === xPrivateClient.sessionGeneration()) {
        promptAction.showToast({ message: this.text($r('app.string.profile_follow_failed')) });
      }
    } finally {
      if (this.alive && generation === this.authorGeneration) { this.followPending = false; }
    }
  }

  private followForeground(): Resource {
    return SystemMaterialUtil.isApi26OrAbove() ? $r('sys.color.font_primary') : $r('app.color.text_on_brand');
  }

  @Builder
  private FollowButton(): void {
    MaterialButton({ buttonWidth: $r('app.float.photo_viewer_follow_width'),
      buttonHeight: $r('app.float.photo_viewer_follow_height'),
      buttonRadius: $r('app.float.photo_viewer_follow_radius'),
      surfaceColor: $r('app.color.media_viewer_control'), materialLevel: 1, applyShadow: true,
      adaptiveForeground: true, enableFallbackBlur: true, lightColor: this.accentColor,
      buttonEnabled: !this.followPending && this.author.id.length > 0,
      buttonOpacity: this.followPending ? 0.6 : 1, buttonPressFeedback: true,
      accessibilityLabel: this.text(this.following ? $r('app.string.profile_detail_following') :
        $r('app.string.profile_detail_follow')),
      buttonMonopolizeEvents: true, onButtonClick: (): void => { void this.toggleFollow(); } }) {
      Text(this.following ? $r('app.string.profile_detail_following') : $r('app.string.profile_detail_follow'))
        .fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontWeight(FontWeight.Bold)
        .fontColor(this.followForeground()).maxLines(1).maxFontScale(1.2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
  }

  build(): void {
    Row({ space: this.dimension($r('app.float.photo_viewer_author_gap')) }) {
      Row({ space: this.dimension($r('app.float.photo_viewer_author_identity_gap')) }) {
        ProxyAvatar({ url: this.author.avatarUrl ?? '',
          avatarSize: this.dimension($r('app.float.photo_viewer_author_avatar_size')),
          radius: this.dimension($r('app.float.photo_viewer_author_avatar_size')) / 2,
          verifiedType: this.author.verifiedType ?? '', avatarShape: this.author.avatarShape ?? '',
          fallbackText: this.author.name.substring(0, 1), fallbackColor: this.author.avatarColor })
        Column({ space: this.dimension($r('app.float.photo_viewer_author_line_gap')) }) {
          Row({ space: this.dimension($r('app.float.photo_viewer_author_badge_gap')) }) {
            Text(this.author.name).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L'))
              .fontWeight(FontWeight.Bold).fontColor($r('app.color.text_on_brand'))
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).flexShrink(1)
            if (this.author.verified) {
              SymbolGlyph($r('sys.symbol.checkmark_circle_fill')).fontSize($r('app.float.photo_viewer_author_badge_size'))
                .fontColor([verificationBadgeColor(this.author.verifiedType ?? '', this.accentColor)])
            }
          }.width('100%')
          Text('@' + this.author.username).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
            .fontColor($r('app.color.media_viewer_placeholder')).maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .onClick((): void => this.onOpenAuthor())
      .monopolizeEvents(true)
      .id('photo-viewer-author-profile')
      if (!this.isOwnAuthor()) { this.FollowButton() }
    }
    .width('100%')
    .padding({ left: $r('app.float.photo_viewer_author_inset'), right: $r('app.float.photo_viewer_author_inset'),
      top: $r('app.float.photo_viewer_author_inset'), bottom: $r('app.float.photo_viewer_author_bottom') })
    .id('photo-viewer-author-bar')
  }
}
