import { SPACE_SURFACE_REVISION, spaceSurfaceStore, requestSpacePreview } from '../services/SpaceSurfaceStore';
import { SpacePresence } from '../models/Space';
import { AvatarTintPalette } from '../utils/AvatarTintColors';
import { common } from '@kit.AbilityKit';
import { ProxyAvatar } from './ProxyAvatar';
import { userAvatarRadius } from '../utils/UserIdentity';

@Component
export struct SpaceAwareAvatar {
  @Prop @Watch('onUserChanged') userId: string = '';
  @Prop followed: boolean = false;
  @Prop url: string = '';
  @Prop avatarSize: number = 44;
  @Prop radius: number = 22;
  @Prop verifiedType: string = '';
  @Prop avatarShape: string = '';
  @Prop fallbackText: string = '';
  @Prop fallbackColor: ResourceColor = $r('app.color.brand');
  @Prop tintBackground: boolean = false;
  @StorageProp(SPACE_SURFACE_REVISION) revision: number = 0;
  @StorageProp('harmonyx.app_foreground') @Watch('onForegroundChanged') foreground: boolean = true;
  private visible: boolean = false;
  private timer: number = -1;
  onTintResolved: (palette: AvatarTintPalette | null) => void = (): void => {};
  onProfile: () => void = (): void => {};

  aboutToDisappear(): void { this.visible = false; this.clearTimer(); }
  private clearTimer(): void { if (this.timer >= 0) { clearTimeout(this.timer); this.timer = -1; } }
  private onUserChanged(): void { this.clearTimer(); if (this.visible && this.foreground) { this.refreshPresence(); } }
  private onForegroundChanged(): void { this.onUserChanged(); }
  private refreshPresence(): void {
    this.clearTimer();
    if (!/^[0-9]{1,24}$/.test(this.userId)) { return; }
    spaceSurfaceStore.requestPresence(this.userId, this.followed);
    this.timer = setTimeout((): void => { if (this.visible && this.foreground) { this.refreshPresence(); } }, 31000);
  }

  private presence(): SpacePresence | null { return this.revision >= 0 ? spaceSurfaceStore.presence(this.userId) : null; }
  private inset(): number { return this.presence() !== null ? 3 : 0; }
  private cornerRadius(): number { return userAvatarRadius(this.avatarSize, this.radius, this.verifiedType, this.avatarShape); }
  private label(): string {
    return this.presence() !== null ? (getContext(this) as common.UIAbilityContext).resourceManager.getStringSync(
      $r('app.string.spaces_avatar_live')) : this.fallbackText;
  }
  build(): void {
    Stack({ alignContent: Alignment.Center }) {
      ProxyAvatar({ url: this.url, avatarSize: this.avatarSize - this.inset() * 2,
        radius: Math.max(0, this.cornerRadius() - this.inset()), fallbackText: this.fallbackText,
        fallbackColor: this.fallbackColor, tintBackground: this.tintBackground, onTintResolved: this.onTintResolved })
      if (this.presence() !== null) {
        Stack() {
          SymbolGlyph(this.presence()?.role === 'listener' ? $r('sys.symbol.headphones') : $r('sys.symbol.waveform'))
            .fontSize(Math.max(9, this.avatarSize * 0.22)).fontColor([$r('app.color.space_card_text')])
        }.width(this.avatarSize * 0.38).height(this.avatarSize * 0.38)
          .borderRadius(this.avatarSize).backgroundColor($r('app.color.space_accent'))
          .border({ width: 1.5, color: $r('app.color.bg_page') })
          .position({ x: this.avatarSize * 0.68, y: this.avatarSize * 0.68 })
      }
    }.width(this.avatarSize).height(this.avatarSize).borderRadius(this.cornerRadius()).clip(false)
      .border({ width: this.presence() !== null ? 2 : 0, color: $r('app.color.space_accent') })
      .accessibilityText(this.label())
      .onVisibleAreaApproximateChange({ ratios: [0, 0.01], expectedUpdateInterval: 300 },
        (visible: boolean, ratio: number): void => {
          this.visible = visible && ratio > 0;
          if (this.visible && this.foreground) { this.refreshPresence(); } else { this.clearTimer(); }
        })
      .onClick((): void => {
        const presence: SpacePresence | null = this.presence();
        if (presence !== null) { requestSpacePreview(presence.spaceId); } else { this.onProfile(); }
      }).monopolizeEvents(true)
  }
}
