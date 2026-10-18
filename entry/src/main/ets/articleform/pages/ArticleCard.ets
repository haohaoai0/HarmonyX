import { ArticleCardItem } from '../../models/ArticleCardItem';
import { ArticleCardLaunch, articleCardItemLaunch } from '../../utils/ArticleCardRoute';

const articleCardStorage: LocalStorage = new LocalStorage();

@Component
struct ArticleCardStory {
  @Prop item: ArticleCardItem = new ArticleCardItem();
  @Prop index: number = 0;
  @Prop compact: boolean = false;
  @Prop feature: boolean = false;
  @Prop source: string = 'for_you';

  private onImage(): boolean {
    return this.feature && this.hasImage(this.item.mediaUrl);
  }

  private sourceLabel(): Resource {
    if (this.source === 'following') {
      return $r('app.string.card_source_following');
    }
    if (this.source === 'trends') {
      return $r('app.string.card_source_trends');
    }
    if (this.source === 'notifications') {
      return $r('app.string.card_source_notifications');
    }
    return $r('app.string.card_source_for_you');
  }

  private hasImage(url: string): boolean {
    // Images must be transferred to the isolated card runtime with formImages.
    return url.startsWith('memory://');
  }

  private rank(index: number): string {
    return index < 9 ? '0' + (index + 1).toString() : (index + 1).toString();
  }

  private openItem(): void {
    const launch: ArticleCardLaunch = articleCardItemLaunch(this.item);
    postCardAction(this, {
      action: 'router',
      abilityName: 'EntryAbility',
      params: {
        harmonyxCard: launch.kind,
        query: launch.query,
        postId: launch.postId,
        title: launch.title,
        label: launch.label
      }
    });
  }

  @Builder
  private Byline(): void {
    Row({ space: 4 }) {
      if (this.item.mediaIsVideo) {
        SymbolGlyph($r('sys.symbol.play_fill'))
          .fontSize($r('app.float.article_card_meta_size'))
          .fontColor([this.onImage() ? $r('app.color.article_card_on_media_secondary') :
            $r('app.color.article_card_secondary')])
      }
      Text(this.item.label.length > 0 ? this.item.label : this.sourceLabel())
        .fontSize($r('app.float.article_card_meta_size'))
        .lineHeight($r('app.float.article_card_meta_line'))
        .fontColor(this.onImage() ? $r('app.color.article_card_on_media_secondary') :
          $r('app.color.article_card_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
    }
    .width('100%')
  }

  @Builder
  private Thumbnail(): void {
    if (this.hasImage(this.item.mediaUrl)) {
      Stack() {
        Image(this.item.mediaUrl)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .interpolation(ImageInterpolation.High)
        if (this.item.mediaIsVideo) {
          SymbolGlyph($r('sys.symbol.play_circle_fill'))
            .fontSize($r('app.float.article_card_brand_size'))
            .fontColor([$r('app.color.article_card_on_media')])
        }
      }
      .width(this.compact ? $r('app.float.article_card_compact_thumbnail_size') : $r('app.float.article_card_thumbnail_size'))
      .height(this.compact ? $r('app.float.article_card_compact_thumbnail_size') : $r('app.float.article_card_thumbnail_size'))
      .backgroundColor($r('app.color.article_card_surface'))
      .borderRadius($r('app.float.article_card_thumbnail_radius'))
      .clip(true)
    } else if (this.hasImage(this.item.avatarUrl)) {
      Image(this.item.avatarUrl)
        .width($r('app.float.article_card_avatar_size'))
        .height($r('app.float.article_card_avatar_size'))
        .objectFit(ImageFit.Cover)
        .interpolation(ImageInterpolation.High)
        .borderRadius($r('app.float.article_card_avatar_size'))
    } else if (this.item.kind === 'trend') {
      Text(this.rank(this.index))
        .fontSize($r('app.float.article_card_rank_size'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.article_card_rank'))
        .width($r('app.float.article_card_rank_width'))
    }
  }

  @Builder
  private StoryRow(): void {
    Row({ space: 10 }) {
      if (this.item.kind === 'trend') {
        this.Thumbnail()
      }
      Column({ space: 3 }) {
        Text(this.item.title)
          .width('100%')
          .fontSize($r('app.float.article_card_row_title_size'))
          .lineHeight($r('app.float.article_card_row_title_line'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.article_card_primary'))
          .maxLines(this.compact ? 1 : 2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.item.kind !== 'trend' || this.item.label.length > 0) {
          this.Byline()
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      if (this.item.kind !== 'trend') {
        this.Thumbnail()
      }
    }
    .width('100%')
    .height('100%')
    .alignItems(VerticalAlign.Center)
    .clip(true)
    .onClick((): void => this.openItem())
  }

  @Builder
  private Feature(): void {
    Stack({ alignContent: this.hasImage(this.item.mediaUrl) ? Alignment.BottomStart : Alignment.Start }) {
      if (this.hasImage(this.item.mediaUrl)) {
        Image(this.item.mediaUrl)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .interpolation(ImageInterpolation.High)
        Column()
          .width('100%')
          .height('100%')
          .linearGradient({
            angle: 180,
            colors: [[$r('app.color.article_card_scrim_clear'), 0],
              [$r('app.color.article_card_scrim_middle'), 0.35],
              [$r('app.color.article_card_scrim_end'), 1]]
          })
      }
      Column({ space: 6 }) {
        if (this.item.kind === 'trend' && !this.compact) {
          Text(this.rank(this.index))
            .fontSize($r('app.float.article_card_heading_size'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.article_card_rank'))
        }
        Text(this.item.title)
          .width('100%')
          .fontSize(this.compact ? $r('app.float.article_card_small_title_size') :
            $r('app.float.article_card_feature_title_size'))
          .lineHeight(this.compact ? $r('app.float.article_card_small_title_line') :
            $r('app.float.article_card_feature_title_line'))
          .fontWeight(FontWeight.Bold)
          .fontColor(this.hasImage(this.item.mediaUrl) ? $r('app.color.article_card_on_media') :
            $r('app.color.article_card_primary'))
          .maxLines(this.compact ? 2 : 3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Row({ space: 8 }) {
          Row() {
            if (this.item.kind !== 'trend' || this.item.label.length > 0) {
              this.Byline()
            }
          }
          .layoutWeight(1)
          SymbolGlyph($r('sys.symbol.arrow_up_right'))
            .fontSize($r('app.float.article_card_meta_size'))
            .fontColor([this.hasImage(this.item.mediaUrl) ? $r('app.color.article_card_on_media_secondary') :
              $r('app.color.article_card_rank')])
        }
        .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(this.hasImage(this.item.mediaUrl) ? (this.compact ?
        $r('app.float.article_card_small_feature_inset') : $r('app.float.article_card_feature_inset')) : 0)
    }
    .width('100%')
    .height('100%')
    .borderRadius(this.hasImage(this.item.mediaUrl) ? $r('app.float.article_card_feature_radius') : 0)
    .clip(true)
    .onClick((): void => this.openItem())
  }

  build(): void {
    if (this.feature) {
      this.Feature()
    } else {
      this.StoryRow()
    }
  }
}

@Entry(articleCardStorage)
@Component
struct ArticleCard {
  @LocalStorageProp('cardList') cardList: ArticleCardItem[] = [];
  @LocalStorageProp('dimension') dimension: string = '2*4';
  @LocalStorageProp('source') source: string = 'for_you';

  private sourceLabel(): Resource {
    if (this.source === 'following') {
      return $r('app.string.card_source_following');
    }
    if (this.source === 'trends') {
      return $r('app.string.card_source_trends');
    }
    if (this.source === 'notifications') {
      return $r('app.string.card_source_notifications');
    }
    return $r('app.string.card_source_for_you');
  }

  private sourceEmpty(): Resource {
    if (this.source === 'following') {
      return $r('app.string.card_empty_following');
    }
    if (this.source === 'trends') {
      return $r('app.string.card_empty_trends');
    }
    if (this.source === 'notifications') {
      return $r('app.string.card_empty_notifications');
    }
    return $r('app.string.card_empty_for_you');
  }

  private openHome(): void {
    postCardAction(this, {
      action: 'router',
      abilityName: 'EntryAbility',
      params: { harmonyxCard: 'home' }
    });
  }

  private openSettings(): void {
    postCardAction(this, {
      action: 'router',
      abilityName: 'EntryAbility',
      params: { harmonyxCard: 'settings' }
    });
  }

  @Builder
  private Header(): void {
    Row({ space: 7 }) {
      Image($r('app.media.icon'))
        .width($r('app.float.article_card_brand_size'))
        .height($r('app.float.article_card_brand_size'))
        .borderRadius($r('app.float.article_card_brand_radius'))
        .objectFit(ImageFit.Cover)
        .onClick((): void => this.openHome())
      Text(this.sourceLabel())
        .fontSize($r('app.float.article_card_heading_size'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.article_card_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
        .onClick((): void => this.openHome())
      SymbolGlyph($r('sys.symbol.gearshape'))
        .fontSize($r('app.float.article_card_action_size'))
        .fontColor([$r('app.color.article_card_secondary')])
        .width($r('app.float.article_card_action_target'))
        .height($r('app.float.article_card_action_target'))
        .accessibilityText($r('app.string.card_settings_title'))
        .onClick((): void => this.openSettings())
    }
    .width('100%')
    .height($r('app.float.article_card_header_height'))
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private CompactBody(): void {
    Swiper() {
      ForEach(this.cardList, (item: ArticleCardItem, index: number) => {
        ArticleCardStory({ item: item, index: index, compact: true, feature: true, source: this.source })
      }, (item: ArticleCardItem): string => item.kind + item.postId + item.query + item.title)
    }
    .width('100%')
    .layoutWeight(1)
    .vertical(true)
    .autoPlay(false)
    .loop(false)
    .indicator(false)
  }

  @Builder
  private WideBody(): void {
    List({ space: 4 }) {
      ForEach(this.cardList, (item: ArticleCardItem, index: number) => {
        ListItem() {
          ArticleCardStory({ item: item, index: index, compact: true, source: this.source })
        }
        .width('100%')
        .height($r('app.float.article_card_scroll_row_height'))
      }, (item: ArticleCardItem): string => item.kind + item.postId + item.query + item.title)
    }
    .width('100%')
    .layoutWeight(1)
    .listDirection(Axis.Vertical)
    .scrollBar(BarState.Off)
    .divider({ strokeWidth: $r('app.float.article_card_rule_height'), color: $r('app.color.article_card_separator') })
    .clip(true)
  }

  @Builder
  private LargeBody(): void {
    List({ space: 8 }) {
      ForEach(this.cardList, (item: ArticleCardItem, index: number) => {
        ListItem() {
          ArticleCardStory({ item: item, index: index, feature: index === 0, source: this.source })
        }
        .width('100%')
        .height(index === 0 ? $r('app.float.article_card_scroll_feature_height') :
          $r('app.float.article_card_large_row_height'))
      }, (item: ArticleCardItem): string => item.kind + item.postId + item.query + item.title)
    }
    .width('100%')
    .layoutWeight(1)
    .listDirection(Axis.Vertical)
    .scrollBar(BarState.Off)
    .clip(true)
  }

  @Builder
  private EmptyState(): void {
    Column({ space: 10 }) {
      SymbolGlyph($r('sys.symbol.message'))
        .fontSize($r('app.float.article_card_empty_symbol_size'))
        .fontColor([$r('app.color.article_card_rank')])
      Text(this.sourceEmpty())
        .fontSize($r('app.float.article_card_row_title_size'))
        .fontColor($r('app.color.article_card_secondary'))
        .textAlign(TextAlign.Center)
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .onClick((): void => this.openHome())
  }

  build(): void {
    Column({ space: 8 }) {
      this.Header()
      if (this.cardList.length === 0) {
        this.EmptyState()
      } else if (this.dimension === '2*2') {
        this.CompactBody()
      } else if (this.dimension === '4*4') {
        this.LargeBody()
      } else {
        this.WideBody()
      }
    }
    .width('100%')
    .height('100%')
    .padding($r('app.float.article_card_inset'))
    .alignItems(HorizontalAlign.Start)
    // The launcher owns the outer shape, including corners and clipping.
    .backgroundColor($r('app.color.article_card_bg_start'))
  }
}
