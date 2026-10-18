import { PageBackgroundState, STORAGE_KEY_PAGE_BACKGROUND, pageBackgroundFromValue, pageBackgroundActive } from '../services/PageBackgroundStore';
import { chatBackgroundPreset } from '../services/ChatBackgroundStore';
import { pageBackgroundBaseColor, pageBackdropTone } from '../utils/ThemeColors';
import { ChatBackgroundPattern } from './ChatBackgroundPattern';
import { PageMotifLayer } from './PageMotifLayer';
import { pageLightInk } from '../utils/PageBackgroundContrast';
import { rgbFromHex } from '../utils/PageBackgroundContrast';
import { ColorMetrics } from '@kit.ArkUI';

@Component
export struct PageBackgroundLayer {
  @Prop wallpaper: PageBackgroundState = new PageBackgroundState();
  @StorageProp('harmonyx.display_mode') private displayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private darkSurface: string = '';

  private baseColor(): ResourceColor {
    return pageBackgroundBaseColor(this.wallpaper, this.displayMode, this.darkSurface);
  }
  private ink(): number {
    if (this.wallpaper.mode === 'photo') { return pageLightInk(rgbFromHex(this.wallpaper.photoAverage)) ? 1 : 0; }
    const color: ColorMetrics = ColorMetrics.resourceColor(this.baseColor());
    return pageLightInk({ red: color.red, green: color.green, blue: color.blue }) ? 1 : 0;
  }

  build(): void {
    Stack() {
      Column().width('100%').height('100%').backgroundColor(this.baseColor())
      if (this.wallpaper.mode === 'color') {
        Column().width('100%').height('100%').backgroundColor(this.wallpaper.color)
      } else if (this.wallpaper.mode === 'photo' && this.wallpaper.path.length > 0) {
        Image('file://' + this.wallpaper.path).width('100%').height('100%')
          .objectFit(ImageFit.Cover).autoResize(true).draggable(false)
          .scale({ x: this.wallpaper.blur > 0 ? 1.15 : 1, y: this.wallpaper.blur > 0 ? 1.15 : 1 })
          .blur(this.wallpaper.blur)
      }
      if (this.wallpaper.texture !== 'none') {
        Column().width('100%').height('100%')
          .backgroundImage(this.wallpaper.texture === 'kraft' ? $r('app.media.page_texture_kraft') : $r('app.media.page_texture_parchment'), ImageRepeat.XY)
          .backgroundImageSize({ width: 256, height: 256 }).opacity(this.wallpaper.textureStrength)
      }
      if (this.wallpaper.patternLayout === 'icons' && this.wallpaper.motifIds.length > 0) {
        PageMotifLayer({ motifIds: this.wallpaper.motifIds, density: this.wallpaper.density, strength: this.wallpaper.patternStrength, ink: this.ink() })
      } else if (this.wallpaper.patternLayout === 'preset' && this.wallpaper.patternStrength > 0) {
        ForEach(this.wallpaper.patternIds, (id: string) => {
          ChatBackgroundPattern({ pattern: chatBackgroundPreset(id).pattern,
            aspect: chatBackgroundPreset(id).patternAspect,
            strength: this.wallpaper.patternStrength / Math.sqrt(this.wallpaper.patternIds.length), ink: this.ink() })
        }, (id: string): string => id)
      }
      if (this.wallpaper.dim > 0) {
        Column().width('100%').height('100%').backgroundColor(Color.Black).opacity(this.wallpaper.dim)
      }
      Column().width('100%').height('100%')
        .backgroundColor(pageBackdropTone(this.wallpaper, this.displayMode, this.darkSurface).veilLight ? Color.White : Color.Black)
        .opacity(pageBackdropTone(this.wallpaper, this.displayMode, this.darkSurface).veil)
    }.width('100%').height('100%').clip(true).renderGroup(true).hitTestBehavior(HitTestMode.None)
  }
}

@Component
struct AppPageBackgroundLayer {
  @StorageProp(STORAGE_KEY_PAGE_BACKGROUND) private backgroundValue: string = '';
  build(): void {
    if (pageBackgroundActive(this.backgroundValue)) {
      // An applied scheme is one render snapshot. Replace only the decorative
      // layer when it changes so reused destinations cannot retain old image,
      // motif or render-group nodes. Feed rows and scroll positions stay alive.
      ForEach([this.backgroundValue], (value: string) => {
        PageBackgroundLayer({ wallpaper: pageBackgroundFromValue(value) })
      }, (value: string): string => value)
    }
  }
}

// Each destination paints a complete surface, including during native page
// transitions. Transparent content can never reveal the previous destination.
@Builder
export function appPageBackground(): void { AppPageBackgroundLayer(); }
