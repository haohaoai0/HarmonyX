import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { STORAGE_KEY_SYSTEM_EMOJI_ENABLED } from '../services/AppearanceStore';
import type { MediaAttachment, Tweet } from '../models/Tweet';
import { chatPostPreview } from '../services/ChatPostPreview';
import { xPrivateClient } from '../services/XPrivateClient';
import { STORAGE_KEY_ACCOUNTS_CHANGED } from '../services/AccountStore';
import { ProxyAvatar } from './ProxyAvatar';
import { ProxyMediaImage } from './ProxyMediaImage';
import { EmojiSpans } from './EmojiSpans';
import {
  ChatPostMediaLayout,
  ChatPostMediaTile,
  chatPostMediaCount,
  chatPostMediaLayout
} from '../utils/ChatPostCardLayout';
import { cardSurfaceColor } from '../utils/ThemeColors';
import { formatPostTime, STORAGE_KEY_POST_TIME_NOW } from '../utils/PostTime';
import { effectiveAppLocale, STORAGE_KEY_APP_LOCALE } from '../utils/AppLocale';
import hilog from '@ohos.hilog';

const SENSITIVE_BLUR: number = 24;
const CARD_RADIUS: number = 16;
const CARD_TEXT_MAX_LINES: number = 3;
const CARD_PADDING: number = 16;
// The reference card keeps its author avatar close to the text's own height.
const AUTHOR_AVATAR: number = 14;
const DOMAIN: number = 0xFF00;
const TAG: string = 'HarmonyX-ChatPost';

// A post shared into a DM renders the way X renders it: media fills the top edge
// of the card, then one line of author/account/time, then the post text. The
// card stays passive - a tap opens the post, and a long press reaches the
// message context menu that already owns this row.
@Component
export struct ChatPostCard {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp(STORAGE_KEY_SYSTEM_EMOJI_ENABLED) private systemEmojiEnabled: boolean = false;
  @StorageProp(STORAGE_KEY_ACCOUNTS_CHANGED) @Watch('reset') private accountRevision: number = 0;
  @StorageProp(STORAGE_KEY_POST_TIME_NOW) private postTimeNow: number = Date.now();
  @StorageProp(STORAGE_KEY_APP_LOCALE) private appLocale: string = effectiveAppLocale();
  @StorageProp('harmonyx.display_mode') private themeDisplayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private themeDarkSurface: string = '';
  @Prop @Watch('reset') postId: string = '';
  @Prop url: string = '';
  @Prop @Watch('load') visible: boolean = true;
  onOpen: (post: Tweet | null, url: string) => void = (_post: Tweet | null, _url: string): void => {};
  onLongPress: () => void = (): void => {};
  @State private post: Tweet | null = null;
  @State private loading: boolean = false;
  @State private mediaLayout: ChatPostMediaLayout = new ChatPostMediaLayout();
  private cardWidth: number = 0;
  private active: boolean = false;
  private inViewport: boolean = false;
  private attempted: boolean = false;
  private requestGeneration: number = 0;
  private session: number = -1;

  aboutToAppear(): void { this.active = true; this.reset(); }
  aboutToDisappear(): void { this.active = false; this.requestGeneration++; }

  private reset(): void {
    this.requestGeneration++;
    this.post = null;
    this.session = -1;
    this.loading = false;
    this.attempted = false;
    this.mediaLayout = new ChatPostMediaLayout();
    this.load();
  }

  private async load(): Promise<void> {
    if (!this.active || !this.visible || !this.inViewport || this.loading || this.attempted) { return; }
    this.attempted = true;
    this.loading = true;
    const generation: number = ++this.requestGeneration;
    const session: number = xPrivateClient.sessionGeneration();
    const post: Tweet | null = await chatPostPreview.load(this.postId);
    if (!this.active || generation !== this.requestGeneration || session !== xPrivateClient.sessionGeneration()) {
      return;
    }
    this.session = session;
    this.post = post;
    this.loading = false;
    this.rebuildMedia();
  }

  // A hidden post must not leave an empty rectangle behind, and the layout is
  // driven by the media that actually has something to draw.
  private media(): MediaAttachment[] {
    const post: Tweet | null = this.post;
    if (post === null || post.presentation?.visibility?.hidden === true) { return []; }
    const attachments: MediaAttachment[] = post.attachments ?? [];
    const visible: MediaAttachment[] = [];
    const limit: number = chatPostMediaCount(attachments);
    for (let i: number = 0; i < attachments.length && visible.length < limit; i++) {
      const media: MediaAttachment = attachments[i];
      if (media.previewUrl.length > 0 || media.mediaUrl.length > 0) { visible.push(media); }
    }
    return visible;
  }

  private previewUrl(media: MediaAttachment): string {
    return media.previewUrl.length > 0 ? media.previewUrl : media.mediaUrl;
  }

  private rebuildMedia(): void {
    this.mediaLayout = chatPostMediaLayout(this.media(), this.cardWidth);
  }

  private authorHandle(post: Tweet): string {
    return post.author.username.length > 0 ? '@' + post.author.username : '';
  }

  private authorTime(post: Tweet): string {
    return formatPostTime(post.createdAt, this.postTimeNow, this.appLocale);
  }

  private bodyText(post: Tweet): string {
    return post.presentation?.visibility?.hidden === true ? '' : post.text;
  }

  private openPost(): void {
    if (!this.active || !this.visible) { return; }
    this.onOpen(this.session === xPrivateClient.sessionGeneration() ? this.post : null, this.url);
  }

  private longPress(): void {
    hilog.info(DOMAIN, TAG, 'long press on shared post card %{public}s', this.postId);
    if (this.active) { this.onLongPress(); }
  }

  @Builder
  private MediaTile(media: MediaAttachment, cell: ChatPostMediaTile): void {
    Stack({ alignContent: Alignment.Center }) {
      ProxyMediaImage({ url: this.previewUrl(media), fillParent: true,
        blurRadius: media.sensitive === true ? SENSITIVE_BLUR : 0 })
      if (media.type !== 'photo') {
        SymbolGlyph($r('sys.symbol.play_fill')).fontSize(30)
          .fontColor([$r('app.color.text_on_brand')])
          .backgroundColor($r('app.color.chat_media_play_scrim')).padding(10).borderRadius(24)
          .hitTestBehavior(HitTestMode.None)
      }
    }.width(cell.width).height(cell.height).position({ x: cell.x, y: cell.y }).clip(true)
      .hitTestBehavior(HitTestMode.None)
  }

  @Builder
  private Media(): void {
    Stack() {
      ForEach(this.media(), (media: MediaAttachment, index: number) => {
        if (this.mediaLayout.tiles.length > index) {
          this.MediaTile(media, this.mediaLayout.tiles[index])
        }
      }, (media: MediaAttachment, index: number): string =>
        this.postId + ':' + index.toString() + ':' + this.previewUrl(media))
    }.width('100%').height(this.mediaLayout.height)
  }

  @Builder
  private Body(post: Tweet): void {
    Column({ space: 6 }) {
      Row({ space: 6 }) {
        ProxyAvatar({ url: post.author.avatarUrl ?? '', avatarSize: AUTHOR_AVATAR, radius: AUTHOR_AVATAR / 2,
          fallbackText: post.author.name.substring(0, 1).toUpperCase(),
          fallbackColor: post.author.avatarColor })
        Text() {
          Span(post.author.name).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
          Span(this.authorHandle(post).length > 0 ? ' ' + this.authorHandle(post) : '')
            .fontColor($r('app.color.text_secondary'))
        }.fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
        // The time sits against the card's trailing edge, which is what opens
        // the gap between the account and the age in the reference card.
        Text(this.authorTime(post)).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
          .fontColor($r('app.color.text_secondary')).maxLines(1)
      }.width('100%')
      if (this.bodyText(post).length > 0) {
        Text() { EmojiSpans(this.getUIContext(), this.bodyText(post), $r('sys.float.Body_L'), this.systemEmojiEnabled) }
          .width('100%').fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L'))
          .fontColor($r('app.color.text_primary')).maxLines(CARD_TEXT_MAX_LINES)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
      .padding({ left: CARD_PADDING, right: CARD_PADDING, top: 12, bottom: 14 })
  }

  @Builder
  private Unavailable(): void {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        if (this.loading) {
          LoadingProgress().width(20).height(20).color($r('app.color.text_accent'))
        }
        Text(this.loading ? $r('app.string.dm_loading') : $r('app.string.post_detail_unavailable'))
          .fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary'))
          .layoutWeight(1)
      }.width('100%')
      Text(this.url).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
        .fontColor($r('app.color.text_accent')).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
    }.width('100%').alignItems(HorizontalAlign.Start).padding(12)
  }

  build(): void {
    Column() {
      if (this.post !== null) {
        if (this.mediaLayout.height > 0) { this.Media(); }
        this.Body(this.post as Tweet)
      } else {
        this.Unavailable()
      }
    }.width('100%').constraintSize({ maxWidth: '100%' })
      .backgroundColor(cardSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
      .borderRadius(CARD_RADIUS).clip(true)
      .id('chat-post-' + this.postId)
      .onAreaChange((_previous: Area, area: Area): void => {
        const width: number = Number(area.width);
        if (width > 0 && Math.abs(width - this.cardWidth) > 0.5) {
          this.cardWidth = width;
          this.rebuildMedia();
        }
      })
      .onVisibleAreaChange([0], (visible: boolean): void => { this.inViewport = visible; if (visible) { this.load(); } })
      // The same exclusive pair the DM media cards use: a hold opens the message
      // menu, a tap opens the post. Registering both through one gesture group is
      // what keeps the hold from being swallowed by the tap recognizer.
      .gesture(GestureGroup(GestureMode.Exclusive,
        LongPressGesture({ repeat: false, duration: 500 }).onAction((): void => { this.longPress(); }),
        TapGesture().onAction((): void => { this.openPost(); })
      ))
      .accessibilityGroup(true)
      .accessibilityText($r('app.string.chat_post_preview'))
  }
}
