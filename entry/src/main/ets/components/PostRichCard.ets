import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { STORAGE_KEY_SYSTEM_EMOJI_ENABLED } from '../services/AppearanceStore';
import { common } from '@kit.AbilityKit';
import { calendarManager } from '@kit.CalendarKit';
import promptAction from '@ohos.promptAction';
import type { TweetLinkCard } from '../models/Tweet';
import { formatCount } from '../models/Tweet';
import { PostCardAction, PostCardPart, PostCardPerson, PostCardSlide } from '../models/PostContent';
import { postCardService, PostCardLoad } from '../services/PostCardService';
import { STORAGE_KEY_POST_TIME_NOW } from '../utils/PostTime';
import { openPostCardUrl } from '../utils/PostCardAction';
import { WebsiteCardPresentation, websiteCardPresentation } from '../utils/PostWebsiteCard';
import { ProxyAvatar } from './ProxyAvatar';
import { ProxyMediaImage } from './ProxyMediaImage';
import { PostMedia } from './PostMedia';
import { EmojiSpans } from './EmojiSpans';

@Component
export struct PostRichCard {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp(STORAGE_KEY_SYSTEM_EMOJI_ENABLED) private systemEmojiEnabled: boolean = false;
  @Prop @Watch('onCardChanged') card: TweetLinkCard;
  @Prop accentColor: string = '#007DFF';
  @StorageProp(STORAGE_KEY_POST_TIME_NOW) private now: number = Date.now();
  @State private resolved: TweetLinkCard | undefined = undefined;
  @State private loading: boolean = false;
  @State private failed: boolean = false;
  @State private status: number = 0;
  @State private page: number = 0;
  @State private cardWidth: number = 0;
  @StorageProp('harmonyx.window_width') private windowWidth: number = 360;
  private alive: boolean = true;
  private started: boolean = false;
  private generation: number = 0;
  private data(): TweetLinkCard { return this.resolved ?? this.card; }
  private slides(): PostCardSlide[] { return this.data().content?.slides ?? []; }
  aboutToDisappear(): void { this.alive = false; ++this.generation; this.loading = false; this.started = false; }
  aboutToAppear(): void { this.alive = true; }
  private onCardChanged(): void {
    ++this.generation; this.resolved = undefined; this.loading = false; this.started = false;
    this.failed = false; this.status = 0; this.page = 0;
  }
  private async hydrate(fresh: boolean = false): Promise<void> {
    if (this.loading || (!fresh && this.started) || ['list', 'community', 'profile', 'broadcast'].indexOf(this.card.kind) < 0) { return; }
    this.started = true; this.loading = true; const generation: number = ++this.generation;
    const result: PostCardLoad = await postCardService.hydrate(this.card, fresh);
    if (!this.alive || generation !== this.generation) { return; }
    this.resolved = result.card; this.failed = result.error.length > 0; this.status = result.status; this.loading = false;
  }
  private open(link: string): void { openPostCardUrl(getContext(this) as common.UIAbilityContext, link); }
  private label(action: PostCardAction): ResourceStr {
    if (action.label.length > 0) { return action.label; }
    if (['shop', 'shopNow', 'shop_now', 'order_now'].indexOf(action.kind) >= 0) { return $r('app.string.card_shop'); }
    if (action.kind === 'store') { return $r('app.string.card_store'); }
    if (['play', 'play_now', 'watch_now'].indexOf(action.kind) >= 0) { return $r('app.string.card_play'); }
    return $r('app.string.post_card_open');
  }
  private title(part: PostCardPart): ResourceStr {
    if (part.title.length > 0) { return part.title; }
    if (part.kind === 'community' || part.kind === 'community_details') { return $r('app.string.card_community'); }
    if (part.kind === 'list' || part.kind === 'twitter_list_details') { return $r('app.string.card_list'); }
    if (part.kind === 'profile') { return $r('app.string.card_profile'); }
    if (part.kind === 'starter') { return $r('app.string.card_starter'); }
    if (part.kind === 'event' || part.kind === 'reminder') { return $r('app.string.post_card_event'); }
    if (part.kind === 'broadcast') { return $r('app.string.post_card_broadcast'); }
    if (part.kind === 'player') { return $r('app.string.card_play'); }
    return $r('app.string.post_card_open');
  }
  private time(part: PostCardPart): string {
    if (part.startsAt <= 0) { return ''; }
    const start: string = new Date(part.startsAt).toLocaleString();
    return part.endsAt > part.startsAt ? start + ' — ' + new Date(part.endsAt).toLocaleString() : start;
  }
  private countdown(part: PostCardPart): string {
    if (part.startsAt <= this.now) { return ''; }
    const minutes: number = Math.ceil((part.startsAt - this.now) / 60000);
    return (getContext(this) as common.UIAbilityContext).resourceManager.getStringSync(
      $r('app.string.card_starts_in').id, minutes > 1440 ? String(Math.ceil(minutes / 1440)) + 'd' :
        minutes > 60 ? String(Math.ceil(minutes / 60)) + 'h' : String(minutes) + 'm');
  }
  private async calendar(part: PostCardPart): Promise<void> {
    if (part.startsAt <= 0) { return; }
    try {
      const event: calendarManager.Event = { type: calendarManager.EventType.NORMAL,
        title: part.title || (getContext(this) as common.UIAbilityContext).resourceManager.getStringSync($r('app.string.post_card_event')),
        startTime: part.startsAt, endTime: part.endsAt > part.startsAt ? part.endsAt : part.startsAt + 3600000,
        description: part.url, reminderTime: [10] };
      await calendarManager.getCalendarManager(getContext(this) as common.UIAbilityContext).editEvent(event);
    } catch (error) { promptAction.showToast({ message: $r('app.string.card_calendar_failed') }); }
  }
  private compact(part: PostCardPart): boolean {
    return this.data().content?.compact === true || part.kind === 'media_with_details_horizontal';
  }
  private thumbnail(part: PostCardPart): string {
    return part.imageUrl || (part.media[0]?.type === 'photo' ? part.media[0].mediaUrl : part.media[0]?.previewUrl ?? '');
  }
  private thumbnailSize(): number {
    return (getContext(this) as common.UIAbilityContext).resourceManager.getNumber($r('app.float.post_card_thumbnail_size'));
  }
  private hasDestination(): boolean {
    const slides: PostCardSlide[] = this.slides();
    return slides.some((slide: PostCardSlide): boolean => slide.parts.some((part: PostCardPart): boolean =>
      part.url.length > 0 || part.actions.length > 0));
  }
  private website(slide: PostCardSlide): WebsiteCardPresentation | undefined {
    return websiteCardPresentation(this.data(), slide);
  }
  private websiteStyle(): boolean {
    return this.slides().length > 0 && this.slides().every((slide: PostCardSlide): boolean => this.website(slide) !== undefined);
  }
  private mediaWidth(): number { return this.cardWidth > 0 ? this.cardWidth : Math.max(1, this.windowWidth - 80); }
  private websiteHeight(presentation: WebsiteCardPresentation): number {
    return this.mediaWidth() / presentation.aspectRatio;
  }
  private websiteTitleWidth(presentation: WebsiteCardPresentation): number {
    const inset: number = (getContext(this) as common.UIAbilityContext).resourceManager.getNumber($r('app.float.post_card_cover_inset'));
    const video: boolean = presentation.media.media[0]?.type === 'video';
    const control: number = video ? (getContext(this) as common.UIAbilityContext).resourceManager.getNumber(
      $r('app.float.post_card_video_control_size')) + inset : 0;
    return Math.max(1, this.mediaWidth() - inset * 2 - control);
  }
  @Builder
  private WebsiteSlide(presentation: WebsiteCardPresentation): void {
    Column({ space: 0 }) {
      Stack({ alignContent: Alignment.BottomStart }) {
        if (presentation.media.media.length > 0 && (presentation.media.media[0].type !== 'photo' ||
          presentation.media.media[0].sensitive === true)) {
          PostMedia({ controlSurface: $r('app.color.poll_option_surface'), attachments: presentation.media.media, naturalVideoSize: true, limitNaturalHeight: false,
            photoViewportHeight: this.websiteHeight(presentation), showDownloadButton: false, linkCardVideo: true,
            onVideoOpen: (): void => this.open(presentation.url) })
        } else {
          ProxyMediaImage({ url: presentation.media.media[0]?.mediaUrl || presentation.media.imageUrl,
            displayHeight: this.websiteHeight(presentation), contain: true })
            .onClick((): void => this.open(presentation.url))
        }
        if (presentation.title.length > 0 && presentation.media.media[0]?.sensitive !== true) {
          Row() {
            Text() { EmojiSpans(this.getUIContext(), presentation.title, $r('sys.float.Body_L'), this.systemEmojiEnabled) }.fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_L')).fontColor($r('app.color.post_card_overlay_text'))
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              .constraintSize({ maxWidth: this.websiteTitleWidth(presentation) })
              .padding({ left: $r('app.float.post_card_title_horizontal_padding'), right: $r('app.float.post_card_title_horizontal_padding'),
                top: $r('app.float.post_card_title_vertical_padding'), bottom: $r('app.float.post_card_title_vertical_padding') })
              .backgroundColor($r('app.color.post_card_title_overlay')).borderRadius($r('app.float.post_card_title_radius'))
              .monopolizeEvents(true).onClick((): void => this.open(presentation.url))
          }.width('100%').padding($r('app.float.post_card_cover_inset')).hitTestBehavior(HitTestMode.Transparent)
        }
      }.width('100%').borderRadius($r('app.float.post_card_cover_radius')).clip(true)
      if (presentation.domain.length > 0) {
        Text($r('app.string.post_card_source', presentation.domain)).fontFamily(this.appFontFamily).width('100%').fontSize($r('sys.float.Body_M'))
          .fontColor($r('app.color.text_secondary')).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          .padding({ left: $r('app.float.post_card_source_inset'), top: $r('app.float.post_card_source_gap') })
          .onClick((): void => this.open(presentation.url))
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
  @Builder
  private CompactPart(part: PostCardPart): void {
    Row({ space: 12 }) {
      if (this.thumbnail(part).length > 0) {
        ProxyMediaImage({ url: this.thumbnail(part), displayHeight: this.thumbnailSize() })
          .width($r('app.float.post_card_thumbnail_size')).borderRadius(10).clip(true)
      }
      Column({ space: 5 }) {
        Text() { EmojiSpans(this.getUIContext(), this.title(part), $r('sys.float.Body_L'), this.systemEmojiEnabled) }.fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_L')).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary')).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
        if (part.text.length > 0) {
          Text() { EmojiSpans(this.getUIContext(), part.text, $r('sys.float.Body_M'), this.systemEmojiEnabled) }.fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary'))
            .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        if (part.subtitle.length > 0) {
          Text() { EmojiSpans(this.getUIContext(), part.subtitle, $r('sys.float.Caption_L'), this.systemEmojiEnabled) }.fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Caption_L')).fontColor($r('app.color.text_secondary'))
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      if (part.url.length > 0) { SymbolGlyph($r('sys.symbol.arrow_up_right')).fontSize(18).fontColor([this.accentColor]) }
    }.width('100%').padding(12).onClick((): void => this.open(part.url))
  }
  @Builder
  private Action(action: PostCardAction): void {
    Button(this.label(action), { type: ButtonType.Capsule }).fontSize($r('sys.float.Body_M'))
      .fontWeight(FontWeight.Bold).fontColor(this.accentColor).backgroundColor($r('app.color.poll_option_surface'))
      .constraintSize({ minHeight: 40 }).layoutWeight(1).onClick((): void => this.open(action.url))
  }
  @Builder
  private Part(part: PostCardPart): void {
    if (this.compact(part) && (part.media.length === 0 || part.media[0].type === 'photo' && part.media[0].sensitive !== true)) {
      this.CompactPart(part)
    } else {
    Column({ space: 8 }) {
      if (part.media.length > 0) {
        if (part.media.length === 1 && part.media[0].type === 'photo' && part.media[0].sensitive !== true && part.url.length > 0) {
          ProxyMediaImage({ url: part.media[0].mediaUrl, displayHeight: 170 })
            .onClick((): void => this.open(part.url))
        } else {
          PostMedia({ controlSurface: $r('app.color.poll_option_surface'), attachments: part.media, naturalVideoSize: true, limitNaturalHeight: true })
        }
      } else if (part.imageUrl.length > 0) {
        ProxyMediaImage({ url: part.imageUrl, displayHeight: this.data().content?.compact === true ? 96 : 170 })
          .onClick((): void => this.open(part.url))
      }
      if (part.kind !== 'media' || part.title.length > 0 || part.url.length > 0 && part.media.length === 0) {
        Column({ space: 8 }) {
          if (part.kind !== 'button_group' && part.kind !== 'facepile') {
            Row({ space: 10 }) {
              if (part.iconUrl.length > 0) { ProxyAvatar({verifiedType: part.verifiedType ?? '', avatarShape: part.avatarShape ?? '',  url: part.iconUrl, avatarSize: 48, radius: part.kind === 'profile' ? 24 : 12 }) }
              Column({ space: 4 }) {
                Text() { EmojiSpans(this.getUIContext(), this.title(part), $r('sys.float.Subtitle_L'), this.systemEmojiEnabled) }.fontFamily(this.appFontFamily)
                  .fontSize($r('sys.float.Subtitle_L')).fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_primary')).maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
                if (part.subtitle.length > 0) {
                  Text() { EmojiSpans(this.getUIContext(), part.subtitle, $r('sys.float.Caption_L'), this.systemEmojiEnabled) }.fontFamily(this.appFontFamily)
                    .fontSize($r('sys.float.Caption_L')).fontColor($r('app.color.text_secondary'))
                    .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                }
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              if (part.url.length > 0) { SymbolGlyph($r('sys.symbol.arrow_up_right')).fontSize(18).fontColor([this.accentColor]) }
            }.width('100%').onClick((): void => this.open(part.url))
          }
          if (part.text.length > 0) {
            Text() { EmojiSpans(this.getUIContext(), part.text, $r('sys.float.Body_M'), this.systemEmojiEnabled) }.fontFamily(this.appFontFamily)
              .width('100%').fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary'))
              .maxLines(4).textOverflow({ overflow: TextOverflow.Ellipsis }).onClick((): void => this.open(part.url))
          }
          if (part.people.length > 0 || part.memberCount >= 0) {
            Row({ space: 6 }) {
              ForEach(part.people.slice(0, 5), (person: PostCardPerson) => {
                ProxyAvatar({verifiedType: person.verifiedType ?? '', avatarShape: person.avatarShape ?? '',  url: person.avatarUrl, avatarSize: 28, radius: 14, fallbackText: person.name.substring(0, 1) })
                  .onClick((): void => { if (person.username.length > 0) { this.open('https://x.com/' + person.username); } })
              }, (person: PostCardPerson): string => person.id)
              if (part.memberCount >= 0) {
                Text(formatCount(part.memberCount)).fontFamily(this.appFontFamily).fontSize($r('sys.float.Caption_L')).fontColor($r('app.color.text_secondary'))
                Text(part.kind === 'profile' ? $r('app.string.card_followers') : $r('app.string.card_members')).fontFamily(this.appFontFamily)
                  .fontSize($r('sys.float.Caption_L')).fontColor($r('app.color.text_secondary'))
              }
            }.width('100%')
          }
          if (part.price.length > 0 || part.salePrice.length > 0) {
            Row({ space: 8 }) {
              Text(part.salePrice || part.price).fontFamily(this.appFontFamily).fontSize($r('sys.float.Subtitle_L')).fontWeight(FontWeight.Bold).fontColor(this.accentColor)
              if (part.salePrice.length > 0 && part.price.length > 0) {
                Text(part.price).fontFamily(this.appFontFamily).fontSize($r('sys.float.Caption_L')).decoration({ type: TextDecorationType.LineThrough })
                  .fontColor($r('app.color.text_secondary'))
              }
            }.width('100%')
          }
          if (part.platform.length > 0) {
            Text(part.platform + (part.rating > 0 ? ' · ★ ' + part.rating.toFixed(1) + ' (' + formatCount(part.ratingCount) + ')' : '')).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Caption_L')).fontColor($r('app.color.text_secondary'))
          }
          if (part.startsAt > 0) {
            Text(this.time(part)).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_primary'))
            if (this.countdown(part).length > 0) { Text(this.countdown(part)).fontFamily(this.appFontFamily).fontSize($r('sys.float.Caption_L')).fontColor(this.accentColor) }
            Button($r('app.string.card_calendar')).fontColor(this.accentColor).backgroundColor($r('app.color.poll_option_surface'))
              .onClick((): void => { void this.calendar(part); })
          }
          if (part.kind === 'broadcast' && this.data().content?.state) {
            Row({ space: 8 }) {
              Text(this.data().content?.state.toLowerCase() === 'running' ? $r('app.string.spaces_live') : $r('app.string.spaces_ended')).fontFamily(this.appFontFamily)
                .fontSize($r('sys.float.Caption_L')).fontWeight(FontWeight.Bold).fontColor(this.accentColor)
              if ((this.data().content?.viewers ?? -1) >= 0) {
                Text(formatCount(this.data().content?.viewers ?? 0)).fontFamily(this.appFontFamily).fontSize($r('sys.float.Caption_L')).fontColor($r('app.color.text_secondary'))
                Text($r('app.string.card_viewers')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Caption_L')).fontColor($r('app.color.text_secondary'))
              }
            }.width('100%')
          }
          if (part.actions.length > 0) {
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(part.actions, (action: PostCardAction) => { this.Action(action) },
                (action: PostCardAction): string => action.kind + action.url + action.label)
            }.width('100%')
          } else if (['app', 'app_store_details', 'product', 'dpa_details', 'player', 'broadcast', 'starter', 'job_details'].indexOf(part.kind) >= 0 && part.url.length > 0) {
            Button(part.kind === 'product' || part.kind === 'dpa_details' ? $r('app.string.card_shop') :
              part.kind === 'app' || part.kind === 'app_store_details' ? $r('app.string.card_store') : $r('app.string.post_card_open'))
              .width('100%').fontColor(this.accentColor).backgroundColor($r('app.color.poll_option_surface'))
              .onClick((): void => this.open(part.url))
          }
        }.width('100%').alignItems(HorizontalAlign.Start).padding(12)
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
    }
  }
  @Builder
  private Slide(slide: PostCardSlide): void {
    if (this.website(slide) !== undefined) {
      this.WebsiteSlide(this.website(slide) as WebsiteCardPresentation)
    } else {
    Column({ space: 0 }) {
      ForEach(slide.parts, (part: PostCardPart) => { this.Part(part) }, (part: PostCardPart): string => part.id)
    }.width('100%').alignItems(HorizontalAlign.Start)
    }
  }
  build(): void {
    Column({ space: 0 }) {
      if (this.slides().length > 1) {
        Swiper() {
          ForEach(this.slides(), (slide: PostCardSlide) => { this.Slide(slide) }, (slide: PostCardSlide): string => slide.id)
        }.width('100%').loop(false).autoPlay(false).indicator(false)
          .onChange((index: number): void => { this.page = index; })
        Row({ space: 8 }) {
          Text($r('app.string.card_swipe')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Caption_L')).fontColor($r('app.color.text_secondary')).layoutWeight(1)
          Text(String(this.page + 1) + ' / ' + this.slides().length).fontFamily(this.appFontFamily).fontSize($r('sys.float.Caption_L')).fontColor(this.accentColor)
        }.width('100%').padding(12)
      } else if (this.slides().length > 0) { this.Slide(this.slides()[0]) }
      if (this.slides().length > 0 && !this.hasDestination()) {
        Button($r('app.string.post_card_open')).fontColor(this.accentColor).backgroundColor(Color.Transparent)
          .width('100%').onClick((): void => this.open(this.data().url))
      }
      if (this.loading) { LoadingProgress().width(20).height(20).color(this.accentColor).margin(8) }
      if (this.failed) {
        Row({ space: 8 }) {
          Text($r('app.string.card_load_failed')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Caption_L')).fontColor($r('app.color.text_secondary')).layoutWeight(1)
          if (this.status > 0) { Text('HTTP ' + this.status).fontFamily(this.appFontFamily).fontSize($r('sys.float.Caption_L')).fontColor($r('app.color.text_secondary')) }
          Button($r('app.string.card_retry')).fontColor(this.accentColor).backgroundColor(Color.Transparent)
            .onClick((): void => { void this.hydrate(true); })
        }.width('100%').padding(8)
      }
    }.width('100%').borderRadius(this.websiteStyle() ? 0 : 16).clip(!this.websiteStyle()).margin({ top: 8 })
      .backgroundColor(this.websiteStyle() ? Color.Transparent : $r('app.color.poll_option_surface'))
      .border({ width: this.websiteStyle() ? 0 : 1, color: $r('app.color.divider') })
      .onAreaChange((_previous: Area, area: Area): void => {
        const width: number = Number(area.width);
        if (width > 0 && Math.abs(width - this.cardWidth) > 0.5) { this.cardWidth = width; }
      })
      .onVisibleAreaChange([0.1], (visible: boolean): void => { if (visible) { void this.hydrate(); } })
  }
}
