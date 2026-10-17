import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { userAvatarRadius, verificationBadgeColor } from '../utils/UserIdentity';
// The new-posts capsule.
//
// When a re-read brings back posts that are not on screen yet, the feed offers
// them behind this control instead of jumping the reader's position. The faces
// on the capsule say *who* posted, so the tap is an informed one: it merges the
// fresh posts at the top, which is also the newest post in the list.
//
// The surface is the same API 26 immersive material the app's buttons use,
// tinted with the accent colour, falling back to a solid accent capsule on
// platforms without the material.
import { common } from '@kit.AbilityKit';
import { MaterialButton } from './MaterialButton';
import { ProxyAvatar } from './ProxyAvatar';
import type { TweetAuthor } from '../models/Tweet';

const PILL_HEIGHT: number = 44;
const PILL_PADDING_LEFT: number = 16;
const PILL_PADDING_RIGHT: number = 12;
const ARROW_SIZE: number = 20;
const ARROW_GAP: number = 8;
const AVATAR_SIZE: number = 30;
// Consecutive faces overlap by AVATAR_SIZE - AVATAR_STEP so three of them still
// fit comfortably inside the capsule.
const AVATAR_STEP: number = 20;
const MAX_AVATARS: number = 3;
// Shown instead of a fourth face when more accounts posted than fit.
const BADGE_SIZE: number = AVATAR_SIZE;

@Component
export struct NewPostsPill {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Prop authors: TweetAuthor[] = [];
  @Prop newCount: number = 0;
  @Prop materialEnabled: boolean = true;
  @Prop materialLevel: number = 2;
  @StorageLink('harmonyx.accent_color') accentColor: string = '#007DFF';
  onTap: () => void = (): void => {
  };

  // One face per account, in the order the posts arrived, capped at what the
  // capsule can hold.
  private shownAuthors(): TweetAuthor[] {
    const seen: Set<string> = new Set();
    const shown: TweetAuthor[] = [];
    for (let i: number = 0; i < this.authors.length; i++) {
      const author: TweetAuthor = this.authors[i];
      if (seen.has(author.id)) {
        continue;
      }
      seen.add(author.id);
      if (shown.length < MAX_AVATARS) {
        shown.push(author);
      }
    }
    return shown;
  }

  private hiddenAuthorCount(): number {
    const seen: Set<string> = new Set();
    for (let i: number = 0; i < this.authors.length; i++) {
      seen.add(this.authors[i].id);
    }
    const hidden: number = seen.size - this.shownAuthors().length;
    return hidden > 0 ? hidden : 0;
  }

  private avatarRowWidth(): number {
    const count: number = this.shownAuthors().length;
    if (count === 0) {
      return 0;
    }
    return AVATAR_SIZE + (count - 1) * AVATAR_STEP;
  }

  // The capsule sizes itself: the material layer and the faces inside share one
  // fixed box, so the width has to be known before layout.
  private pillWidth(): number {
    let width: number = PILL_PADDING_LEFT + ARROW_SIZE + ARROW_GAP + AVATAR_SIZE + PILL_PADDING_RIGHT;
    const shown: number = this.shownAuthors().length;
    if (shown > 1) {
      width += (shown - 1) * AVATAR_STEP;
    }
    if (this.hiddenAuthorCount() > 0) {
      width += AVATAR_STEP;
    }
    return width;
  }

  private summary(): string {
    const count: string = (this.newCount > 0 ? this.newCount : 1).toString();
    const suffix: string = this.text($r('app.string.timeline_new_posts_suffix'));
    let line: string = count + suffix;
    const shown: TweetAuthor[] = this.shownAuthors();
    for (let i: number = 0; i < shown.length; i++) {
      line += (i === 0 ? ' · ' : '、') + shown[i].name;
    }
    return line;
  }

  private avatarUrl(author: TweetAuthor): string {
    return author.avatarUrl === undefined ? '' : author.avatarUrl;
  }

  private text(resource: Resource): string {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    return context.resourceManager.getStringSync(resource);
  }

  @Builder
  private Avatar(author: TweetAuthor, first: boolean): void {
    Stack() {
      if (this.avatarUrl(author).length > 0) {
        ProxyAvatar({verifiedType: author.verifiedType ?? '', avatarShape: author.avatarShape ?? '',  url: this.avatarUrl(author), avatarSize: AVATAR_SIZE, radius: AVATAR_SIZE / 2,
          fallbackText: author.name.substring(0, 1).toUpperCase(), fallbackColor: author.avatarColor })
      } else {
        Text(author.name.length > 0 ? author.name.substring(0, 1).toUpperCase() : '?').fontFamily(this.appFontFamily)
          .width(AVATAR_SIZE)
          .height(AVATAR_SIZE)
          .fontSize(14)
          // The circle is a fixed size, so the initial must not scale out of it.
          .maxFontScale(1)
          .fontWeight(FontWeight.Bold)
          .textAlign(TextAlign.Center)
          .fontColor($r('app.color.text_on_brand'))
          .backgroundColor(author.avatarColor)
      }
    }
    .width(AVATAR_SIZE)
    .height(AVATAR_SIZE)
    .borderRadius(userAvatarRadius(AVATAR_SIZE, AVATAR_SIZE / 2, author.verifiedType ?? '', author.avatarShape ?? ''))
    .clip(true)
    .border({ width: 1.5, color: $r('app.color.pill_avatar_ring') })
    .margin({ left: first ? 0 : -(AVATAR_SIZE - AVATAR_STEP) })
  }

  // More accounts posted than the capsule shows faces for.
  @Builder
  private OverflowBadge(): void {
    Text('+' + this.hiddenAuthorCount().toString()).fontFamily(this.appFontFamily)
      .width(BADGE_SIZE)
      .height(BADGE_SIZE)
      .fontSize(12)
      .maxFontScale(1)
      .fontWeight(FontWeight.Medium)
      .textAlign(TextAlign.Center)
      .fontColor($r('app.color.text_on_accent'))
      .borderRadius(BADGE_SIZE / 2)
      .border({ width: 1.5, color: $r('app.color.pill_avatar_ring') })
      .margin({ left: -(AVATAR_SIZE - AVATAR_STEP) })
  }

  @Builder
  private FallbackCount(): void {
    Text((this.newCount > 0 ? this.newCount : 1).toString()).fontFamily(this.appFontFamily)
      .width(BADGE_SIZE)
      .height(BADGE_SIZE)
      .fontSize(13)
      .maxFontScale(1)
      .fontWeight(FontWeight.Medium)
      .textAlign(TextAlign.Center)
      .fontColor($r('app.color.text_on_accent'))
      .borderRadius(BADGE_SIZE / 2)
      .border({ width: 1.5, color: $r('app.color.pill_avatar_ring') })
  }

  @Builder
  private PillContent(): void {
    Row() {
      SymbolGlyph($r('sys.symbol.chevron_up'))
        .fontSize(ARROW_SIZE)
        .fontColor([$r('app.color.text_on_accent')])
      if (this.shownAuthors().length === 0) {
        this.FallbackCount();
      } else {
        ForEach(this.shownAuthors(), (author: TweetAuthor, index: number) => {
          this.Avatar(author, index === 0);
        }, (author: TweetAuthor) => author.id)
        if (this.hiddenAuthorCount() > 0) {
          this.OverflowBadge();
        }
      }
    }
    .alignItems(VerticalAlign.Center)
  }

  build(): void {
    MaterialButton({
      buttonWidth: this.pillWidth(),
      buttonHeight: PILL_HEIGHT,
      buttonRadius: PILL_HEIGHT / 2,
      surfaceColor: this.accentColor,
      materialEnabled: this.materialEnabled,
      materialLevel: this.materialLevel,
      applyShadow: true,
      lightColor: this.accentColor,
      onButtonClick: (): void => {
        this.onTap();
      }
    }) {
      this.PillContent();
    }
  }
}
