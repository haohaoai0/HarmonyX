import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import type { PostCardReadingState } from '../services/PostCardReadingState';
import { fieldSurfaceColor, pageTextColor } from '../utils/ThemeColors';

@Component
export struct ReplyQualityNotice {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp('harmonyx.display_mode') private displayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private darkSurface: string = '';
  @Prop @Watch('reset') tweetId: string = '';
  @Prop authorName: string = '';
  @Prop reasons: string[] = [];
  @Prop pageBackground: string = '';
  onAllow: () => void = (): void => {};
  @BuilderParam replyBuilder: () => void = this.EmptyReply;
  @State private expanded: boolean = false;
  @State private showingReasons: boolean = false;
  readingState: PostCardReadingState | null = null;

  aboutToAppear(): void {
    if (this.readingState === null) { return; }
    this.expanded = this.readingState.qualityExpanded;
    this.showingReasons = this.readingState.qualityShowingReasons;
  }

  aboutToDisappear(): void {
    if (this.readingState === null) { return; }
    this.readingState.qualityExpanded = this.expanded;
    this.readingState.qualityShowingReasons = this.showingReasons;
  }

  @Builder private EmptyReply(): void { Column() }

  private reset(): void {
    this.expanded = false;
    this.showingReasons = false;
  }

  private reasonText(code: string): Resource {
    if (code === 'duplicate') { return $r('app.string.reply_quality_reason_duplicate'); }
    if (code === 'author_repeat') { return $r('app.string.reply_quality_reason_author_repeat'); }
    if (code === 'links') { return $r('app.string.reply_quality_reason_links'); }
    if (code === 'promotion') { return $r('app.string.reply_quality_reason_promotion'); }
    return $r('app.string.reply_quality_reason_contact');
  }

  private foreground(): ResourceColor {
    return pageTextColor($r('app.color.text_primary'), this.pageBackground, fieldSurfaceColor(this.displayMode, this.darkSurface));
  }

  build(): void {
    Column({ space: 0 }) {
      Column({ space: 8 }) {
        Text($r('app.string.reply_quality_folded')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M')).fontWeight(FontWeight.Medium).fontColor(this.foreground()).width('100%')
        Text(this.authorName).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_S')).fontColor(this.foreground()).width('100%').maxLines(2)
        Flex({ wrap: FlexWrap.Wrap }) {
          Button(this.expanded ? $r('app.string.post_show_less') : $r('app.string.post_show_more'))
            .fontColor(this.foreground()).backgroundColor(Color.Transparent).constraintSize({ minHeight: 40 })
            .id('reply-quality-expand-' + this.tweetId).onClick((): void => { this.expanded = !this.expanded; })
          Button($r('app.string.reply_quality_reasons'))
            .fontColor(this.foreground()).backgroundColor(Color.Transparent).constraintSize({ minHeight: 40 })
            .id('reply-quality-reasons-' + this.tweetId).onClick((): void => { this.showingReasons = !this.showingReasons; })
          Button($r('app.string.reply_quality_allow'))
            .fontColor(this.foreground()).backgroundColor(Color.Transparent).constraintSize({ minHeight: 40 })
            .id('reply-quality-allow-' + this.tweetId).onClick((): void => this.onAllow())
        }.width('100%')
        if (this.showingReasons) {
          ForEach(this.reasons, (code: string) => {
            Text(this.reasonText(code)).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_M')).fontColor(this.foreground()).width('100%')
          }, (code: string): string => code)
        }
      }.width('100%').padding(12).alignItems(HorizontalAlign.Start)
        .backgroundColor(fieldSurfaceColor(this.displayMode, this.darkSurface)).borderRadius(14)
        .border({ width: 1, color: $r('app.color.divider') }).id('reply-quality-fold-' + this.tweetId)
      if (this.expanded) { this.replyBuilder() }
    }.width('100%').padding({ top: 6, bottom: 6 })
  }
}
