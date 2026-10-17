import { ChatBackgroundState, chatBackgroundPreset } from '../services/ChatBackgroundStore';
import { pageSurfaceColor } from '../utils/ThemeColors';
import { ChatBackgroundPattern } from './ChatBackgroundPattern';

// Adapted from Petrelgram's WallpaperPreview (Apache-2.0). Shared by the
// selector and conversation so blur, gradients and dimming render identically.
@Component
export struct ChatBackgroundLayer {
  @Prop wallpaper: ChatBackgroundState = new ChatBackgroundState();
  @Prop displayMode: string = '';
  @Prop darkSurface: string = '';
  // A conversation uses the actual window height so RESIZE only clips the
  // wallpaper at the keyboard edge, without refitting its image or pattern.
  // Wallpaper previews retain their own container sizing with the default.
  @Prop viewportHeight: number = 0;

  private gradientColors(): Array<[ResourceColor, number]> {
    const colors: ResourceColor[] = chatBackgroundPreset(this.wallpaper.presetId).colors;
    const stops: Array<[ResourceColor, number]> = [];
    for (let i: number = 0; i < colors.length; i++) { stops.push([colors[i], i / (colors.length - 1)]); }
    return stops;
  }

  build(): void {
    Stack() {
      if (this.wallpaper.presetId === 'default') {
        Column().width('100%').height('100%').backgroundColor(pageSurfaceColor(this.displayMode, this.darkSurface))
      } else if (this.wallpaper.path.length > 0) {
        Image('file://' + this.wallpaper.path).width('100%').height('100%')
          .autoResize(true).objectFit(ImageFit.Cover).draggable(false)
          .scale({ x: this.wallpaper.blur > 0 ? 1.18 : 1, y: this.wallpaper.blur > 0 ? 1.18 : 1 })
          .blur(this.wallpaper.blur)
      } else {
        Column().width('100%').height('100%').linearGradient({
          angle: chatBackgroundPreset(this.wallpaper.presetId).angle, colors: this.gradientColors() })
        if (chatBackgroundPreset(this.wallpaper.presetId).pattern !== undefined) {
          ChatBackgroundPattern({ pattern: chatBackgroundPreset(this.wallpaper.presetId).pattern,
            aspect: chatBackgroundPreset(this.wallpaper.presetId).patternAspect,
            strength: this.wallpaper.patternStrength, blurRadius: this.wallpaper.blur })
        }
      }
      if (this.wallpaper.presetId !== 'default') {
        Column().width('100%').height('100%').backgroundColor($r('app.color.chat_background_scrim'))
        Column().width('100%').height('100%').backgroundColor(Color.Black).opacity(this.wallpaper.dim)
      }
    }.width('100%').height(this.viewportHeight > 0 ? this.viewportHeight : '100%')
      .clip(true).renderGroup(true).hitTestBehavior(HitTestMode.None)
  }
}
