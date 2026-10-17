// Avatar renderer backed by the proxy-aware disk cache. Keeping a URL/file
// source lets ArkUI recreate the avatar after a page is mounted again.
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { common } from '@kit.AbilityKit';
import { avatarImageStore } from '../services/AvatarImageStore';
import { proxyStore } from '../services/ProxyStore';
import { XUserParser } from '../services/XUserParser';
import { STORAGE_KEY_AVATAR_TINT_ENABLED } from '../services/AppearanceStore';
import { avatarTintStore } from '../services/AvatarTintStore';
import { AvatarTintPalette } from '../utils/AvatarTintColors';
import { userAvatarRadius } from '../utils/UserIdentity';

@Component
export struct ProxyAvatar {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Prop @Watch('onUrlChanged') url: string = '';
  @Prop avatarSize: number = 44;
  @Prop radius: number = 22;
  @Prop verifiedType: string = '';
  @Prop avatarShape: string = '';
  @Prop fallbackText: string = '';
  @Prop fallbackColor: ResourceColor = $r('app.color.brand');
  @Prop tintBackground: boolean = false;
  @StorageProp(STORAGE_KEY_AVATAR_TINT_ENABLED) @Watch('onUrlChanged')
  private avatarTintEnabled: boolean = false;
  onTintResolved: (palette: AvatarTintPalette | null) => void = (): void => {};
  @State private source: string = '';
  private alive: boolean = true;
  private requestGeneration: number = 0;

  aboutToAppear(): void {
    this.alive = true;
    this.resolveSource();
  }

  aboutToDisappear(): void {
    this.alive = false;
    this.requestGeneration += 1;
  }

  private onUrlChanged(): void {
    this.resolveSource();
  }
  private cornerRadius(): number { return userAvatarRadius(this.avatarSize, this.radius, this.verifiedType, this.avatarShape); }

  private resolveSource(): void {
    this.requestGeneration += 1;
    const generation: number = this.requestGeneration;
    const sourceUrl: string = XUserParser.highResAvatarUrl(this.url);
    this.source = sourceUrl;
    if (this.tintBackground) {
      this.onTintResolved(null);
    }
    const tint: boolean = this.tintBackground && this.avatarTintEnabled;
    if (sourceUrl.length === 0 || (!proxyStore.snapshot().enabled && !tint)) {
      return;
    }
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    avatarImageStore.load(context, sourceUrl, tint).then((cachedSource: string): void => {
      if (!this.alive || generation !== this.requestGeneration || sourceUrl !== XUserParser.highResAvatarUrl(this.url)) {
        return;
      }
      if (cachedSource.length > 0) {
        this.source = cachedSource;
        if (tint) {
          avatarTintStore.load(context, sourceUrl).then((palette: AvatarTintPalette | null): void => {
            if (this.alive && generation === this.requestGeneration && this.avatarTintEnabled) {
              this.onTintResolved(palette);
            }
          });
        }
      }
    }).catch((): void => {
      // The URL remains available as ArkUI's native fallback source.
    });
  }

  build(): void {
    Stack({ alignContent: Alignment.Center }) {
      Text(this.fallbackText).fontFamily(this.appFontFamily)
        .width(this.avatarSize)
        .height(this.avatarSize)
        .fontSize(this.avatarSize * 0.42)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_on_brand'))
        .backgroundColor(this.fallbackColor)
        .borderRadius(this.cornerRadius())
        .textAlign(TextAlign.Center)
      if (this.source.length > 0) {
        Image(this.source)
          .width(this.avatarSize)
          .height(this.avatarSize)
          .objectFit(ImageFit.Cover)
      }
    }
    .width(this.avatarSize)
    .height(this.avatarSize)
    .borderRadius(this.cornerRadius())
    .clip(true)
  }
}
