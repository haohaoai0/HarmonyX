import { PostMedia } from './PostMedia';
import { pageTextColor } from '../utils/ThemeColors';
import { postCardSurfaceColor } from '../utils/ThemeColors';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { STORAGE_KEY_SYSTEM_EMOJI_ENABLED } from '../services/AppearanceStore';
import { PostAdLabel } from './PostAdLabel';
import { userAvatarRadius, userVerifiedType, userAvatarShape, verificationBadgeColor } from '../utils/UserIdentity';
// Compact, non-interactive-media preview for a post quoted by another post.
import type { MediaAttachment, QuotedTweet, Tweet, TweetPoll } from '../models/Tweet';
import { AvatarTintPalette, avatarTintIsDark, avatarTintSurface } from '../utils/AvatarTintColors';
import { SpaceAwareAvatar } from './SpaceAwareAvatar';
import { EmojiSpans } from './EmojiSpans';
import { PostInteractiveContent } from './PostInteractiveContent';
import { postPollStore, STORAGE_KEY_POST_POLL_REVISION } from '../services/PostPollStore';
import { formatPostTime, STORAGE_KEY_POST_TIME_NOW } from '../utils/PostTime';
import { postIsEdited } from '../utils/PostMetadata';
import {
  DEFAULT_CONTENT_FONT_FAMILY,
  STORAGE_KEY_CONTENT_FONT_FAMILY,
  STORAGE_KEY_AVATAR_TINT_ENABLED
} from '../services/AppearanceStore';

@Component
export struct QuotedPostCard {
  @StorageProp('harmonyx.page_background') private pageBackgroundValue: string = '';
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp(STORAGE_KEY_SYSTEM_EMOJI_ENABLED) private systemEmojiEnabled: boolean = false;
  @Prop quoted: QuotedTweet;
  @Prop narrowColumn: boolean = false;
  @StorageProp(STORAGE_KEY_POST_POLL_REVISION) private pollRevision: number = 0;
  @StorageProp(STORAGE_KEY_POST_TIME_NOW) private postTimeNow: number = Date.now();
  @Prop accentColor: string = '#007DFF';
  @StorageProp('harmonyx.display_mode') private themeDisplayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private themeDarkSurface: string = '';
  @StorageProp(STORAGE_KEY_AVATAR_TINT_ENABLED) private avatarTintEnabled: boolean = false;
  @State private palette: AvatarTintPalette | null = null;
  @State private themeDark: boolean = false;
  @StorageLink(STORAGE_KEY_CONTENT_FONT_FAMILY) private contentFontFamily: string = DEFAULT_CONTENT_FONT_FAMILY;
  // The quoted block is the origin when the reader opens the quoted post, the
  // same way a row is the origin for the post it belongs to.
  @Prop sharedElementId: string = '';
  onOpen: (tweet: Tweet) => void = () => {
  };

  private firstMedia(): MediaAttachment | null {
    if (this.quoted.attachments === undefined || this.quoted.attachments.length === 0) {
      return null;
    }
    return this.quoted.attachments[0];
  }

  private interactivePoll(): TweetPoll | undefined {
    return this.quoted.poll ?? postPollStore.known(this.quoted.id, this.pollRevision);
  }

  onWillApplyTheme(theme: Theme): void {
    this.themeDark = avatarTintIsDark(theme);
  }

  private mediaPreview(media: MediaAttachment): string {
    return media.previewUrl.length > 0 ? media.previewUrl : media.mediaUrl;
  }

  private authorTimeLabel(): string {
    const time: string = formatPostTime(this.quoted.createdAt, this.postTimeNow);
    return '@' + this.quoted.author.username + (time.length > 0 ? ' · ' + time : '') +
      (postIsEdited(this.quoted.editHistoryIds) ? ' · ' +
        getContext(this).resourceManager.getStringSync($r('app.string.post_edited').id) : '');
  }

  private asTweet(): Tweet {
    return {
      id: this.quoted.id,
      author: this.quoted.author,
      text: this.quoted.text,
      createdAt: this.quoted.createdAt,
      editHistoryIds: this.quoted.editHistoryIds,
      metrics: {
        replyCount: 0,
        repostCount: 0,
        likeCount: 0,
        viewCount: 0
      },
      liked: false,
      reposted: false,
      bookmarked: false,
      isReply: this.quoted.isReply, replyToTweetId: this.quoted.replyToTweetId,
      replyToUsername: this.quoted.replyToUsername, possiblySensitive: this.quoted.possiblySensitive,
      attachments: this.quoted.attachments,
      poll: this.interactivePoll(),
      card: this.quoted.card,
      article: this.quoted.article,
      presentation: this.quoted.presentation
    };
  }

  private readingText(color: ResourceColor): ResourceColor {
    return pageTextColor(color, this.pageBackgroundValue, postCardSurfaceColor(avatarTintSurface(this.palette, this.quoted.author.avatarUrl ?? '', this.avatarTintEnabled,
      this.themeDisplayMode, this.themeDarkSurface, this.themeDark), this.pageBackgroundValue));
  }

  build(): void {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
          SpaceAwareAvatar({verifiedType: this.quoted.author.verifiedType ?? '', avatarShape: this.quoted.author.avatarShape ?? '',  userId: this.quoted.author.id, url: this.quoted.author.avatarUrl ?? '', avatarSize: 24, radius: 12,
            followed: this.quoted.author.following === true,
            fallbackText: this.quoted.author.name.substring(0, 1).toUpperCase(),
            fallbackColor: this.quoted.author.avatarColor, tintBackground: true,
            onTintResolved: (palette: AvatarTintPalette | null): void => { this.palette = palette; },
            onProfile: (): void => this.onOpen(this.asTweet()) })
        Column({ space: 1 }) {
          Flex({ alignItems: ItemAlign.Center }) {
            Text() { EmojiSpans(this.getUIContext(), this.quoted.author.name, (this.narrowColumn ? $r('app.float.timeline_column_meta_font') : $r('sys.float.Body_M')), this.systemEmojiEnabled) }.fontFamily(this.appFontFamily)
              .fontSize((this.narrowColumn ? $r('app.float.timeline_column_meta_font') : $r('sys.float.Body_M')))
              .fontWeight(FontWeight.Bold)
              .fontColor(this.readingText($r('app.color.text_primary')))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .flexShrink(1)
              .margin({ right: 4 })
            if (this.quoted.author.verified) {
              SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
                .fontSize(14)
                .fontColor([verificationBadgeColor(this.quoted.author.verifiedType ?? '', this.accentColor)])
                .flexShrink(0)
            }
          }
          .width('100%')
          Text(this.authorTimeLabel()).fontFamily(this.appFontFamily)
            .fontSize((this.narrowColumn ? $r('app.float.timeline_column_meta_font') : $r('sys.float.Body_M')))
            .fontColor(this.readingText($r('app.color.text_secondary')))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        PostAdLabel({ foreground: this.readingText($r('app.color.text_secondary')), presentation: this.quoted.presentation })
      }
      .width('100%')
      if ((this.quoted.replyToUsername ?? '').length > 0) {
        Text() {
          Span($r('app.string.compose_replying_to'))
          Span(this.quoted.replyToUsername ?? '')
        }.fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
          .fontColor(this.readingText($r('app.color.text_secondary'))).width('100%')
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      if (this.quoted.text.length > 0 && this.quoted.presentation?.visibility?.hidden !== true) {
        Text() { EmojiSpans(this.getUIContext(), this.quoted.text, (this.narrowColumn ? $r('app.float.timeline_column_body_font') : $r('sys.float.Body_L')), this.systemEmojiEnabled) }
          .width('100%')
          .fontSize((this.narrowColumn ? $r('app.float.timeline_column_body_font') : $r('sys.float.Body_L')))
          .fontFamily(this.appFontFamily === DEFAULT_APP_FONT_FAMILY ? this.contentFontFamily : this.appFontFamily)
          .fontColor(this.readingText($r('app.color.text_primary')))
          .maxLines(4)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      if (this.interactivePoll() !== undefined || this.quoted.card !== undefined || this.quoted.article !== undefined || this.quoted.presentation !== undefined) {
        PostInteractiveContent({ postId: this.quoted.id, poll: this.interactivePoll(), card: this.quoted.card,
          article: this.quoted.article, presentation: this.quoted.presentation,
          accentColor: this.accentColor, showPollMedia: this.firstMedia() === null })
      }
      if (this.firstMedia() !== null && this.quoted.presentation?.visibility?.hidden !== true) {
        PostMedia({ sourceTweet: this.asTweet(), attachments: this.quoted.attachments ?? [],
          playbackEnabled: false, showDownloadButton: false, hideInlineControls: true,
          naturalVideoSize: true,
          onVideoOpen: (): void => this.onOpen(this.asTweet()) }).width('100%')
      }
    }
    .width('100%')
    .padding(this.narrowColumn ? $r('app.float.timeline_column_inset') : 12)
    .margin({ top: 8 })
    .backgroundColor(postCardSurfaceColor(avatarTintSurface(this.palette, this.quoted.author.avatarUrl ?? '', this.avatarTintEnabled,
      this.themeDisplayMode, this.themeDarkSurface, this.themeDark), this.pageBackgroundValue))
    .border({ width: 1, color: $r('app.color.divider') })
    .borderRadius(16)
    .clip(true)
    .geometryTransition(this.sharedElementId, { follow: true })
    .transition(TransitionEffect.opacity(0.99))
    .onClick((): void => {
      this.onOpen(this.asTweet());
    })
    .accessibilityGroup(this.interactivePoll() === undefined && this.quoted.card === undefined)
    .accessibilityText($r('app.string.post_quoted'))
  }
}
