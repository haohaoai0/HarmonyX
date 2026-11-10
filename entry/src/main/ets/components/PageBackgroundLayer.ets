import { PageBackgroundState, STORAGE_KEY_PAGE_BACKGROUND, pageBackgroundFromValue, pageBackgroundActive,
  pageBackgroundPresetColors } from '../services/PageBackgroundStore';
import { chatBackgroundPreset } from '../services/ChatBackgroundStore';
import { pageBackgroundBaseColor, pageBackdropTone } from '../utils/ThemeColors';
import { ChatBackgroundPattern } from './ChatBackgroundPattern';
import { PageMotifLayer } from './PageMotifLayer';
import { pageLightInk } from '../utils/PageBackgroundContrast';
import { ColorMetrics, UIContext } from '@kit.ArkUI';
import { STORAGE_KEY_SYSTEM_DARK } from '../services/AppearanceStore';
import { image } from '@kit.ImageKit';
import { pageBackgroundTextureCache, pageBackgroundTextureStyle, PageBackgroundTexture,
  PAGE_BACKGROUND_TEXTURE_PIXELS } from '../services/PageBackgroundTextureCache';

@Component
export struct PageBackgroundLayer {
  @Prop wallpaper: PageBackgroundState = new PageBackgroundState();
  @Prop rasterWidth: number = 0;
  @Prop rasterHeight: number = 0;
  @Prop syncImages: boolean = false;
  @StorageProp('harmonyx.display_mode') private displayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private darkSurface: string = '';

  private baseColor(): ResourceColor {
    return pageBackgroundBaseColor(this.wallpaper, this.displayMode, this.darkSurface);
  }
  private ink(): number {
    return pageLightInk(pageBackdropTone(this.wallpaper, this.displayMode, this.darkSurface).average) ? 1 : 0;
  }
  private gradientStops(): Array<[ResourceColor, number]> {
    const colors: ResourceColor[] = pageBackgroundPresetColors(this.wallpaper);
    const stops: Array<[ResourceColor, number]> = [];
    for (let index: number = 0; index < colors.length; index++) {
      stops.push([colors[index], colors.length > 1 ? index / (colors.length - 1) : 0]);
    }
    return stops;
  }

  build(): void {
    Stack() {
      Column().width('100%').height('100%').backgroundColor(this.baseColor())
      if (pageBackgroundPresetColors(this.wallpaper).length > 0) {
        Column().width('100%').height('100%').linearGradient({
          angle: chatBackgroundPreset(this.wallpaper.patternIds[0]).angle, colors: this.gradientStops() })
      } else if (this.wallpaper.mode === 'color') {
        Column().width('100%').height('100%').backgroundColor(this.wallpaper.color)
      } else if (this.wallpaper.mode === 'photo' && this.wallpaper.path.length > 0) {
        Image('file://' + this.wallpaper.path).width('100%').height('100%')
          .objectFit(ImageFit.Cover).autoResize(true).draggable(false).syncLoad(this.syncImages)
          .scale({ x: this.wallpaper.blur > 0 ? 1.15 : 1, y: this.wallpaper.blur > 0 ? 1.15 : 1 })
          .blur(this.wallpaper.blur)
      }
      if (this.wallpaper.texture !== 'none') {
        Column().width('100%').height('100%')
          .backgroundImage(this.wallpaper.texture === 'kraft' ? $r('app.media.page_texture_kraft') : $r('app.media.page_texture_parchment'), ImageRepeat.XY)
          .backgroundImageSize({ width: 256, height: 256 }).opacity(this.wallpaper.textureStrength)
      }
      if (this.wallpaper.dim > 0) {
        Column().width('100%').height('100%').backgroundColor(Color.Black).opacity(this.wallpaper.dim)
      }
      Column().width('100%').height('100%')
        .backgroundColor(pageBackdropTone(this.wallpaper, this.displayMode, this.darkSurface).veilLight ? Color.White : Color.Black)
        .opacity(pageBackdropTone(this.wallpaper, this.displayMode, this.darkSurface).veil)
      if (this.wallpaper.patternLayout === 'icons' && this.wallpaper.motifIds.length > 0) {
        PageMotifLayer({ motifIds: this.wallpaper.motifIds, density: this.wallpaper.density,
          strength: this.wallpaper.patternStrength, ink: this.ink(), fixedWidth: this.rasterWidth,
          fixedHeight: this.rasterHeight, syncImages: this.syncImages })
      } else if (this.wallpaper.patternLayout === 'preset' && this.wallpaper.patternStrength > 0) {
        ForEach(this.wallpaper.patternIds, (id: string) => {
          ChatBackgroundPattern({ pattern: chatBackgroundPreset(id).pattern,
            aspect: chatBackgroundPreset(id).patternAspect,
            strength: this.wallpaper.patternStrength / Math.sqrt(this.wallpaper.patternIds.length), ink: this.ink(),
            fixedWidth: this.rasterWidth, fixedHeight: this.rasterHeight, syncImages: this.syncImages })
        }, (id: string): string => id)
      }
    }.width('100%').height('100%').clip(true).renderGroup(true).hitTestBehavior(HitTestMode.None)
  }
}

@Component
struct AppPageBackgroundLayer {
  @Prop reuseTexture: boolean = false;
  @StorageProp(STORAGE_KEY_PAGE_BACKGROUND) @Watch('backgroundChanged') private backgroundValue: string = '';
  @StorageProp('harmonyx.display_mode') @Watch('backgroundChanged') private displayMode: string = '';
  @StorageProp('harmonyx.dark_surface') @Watch('backgroundChanged') private darkSurface: string = '';
  @StorageProp(STORAGE_KEY_SYSTEM_DARK) @Watch('backgroundChanged') private systemDark: boolean = false;
  @State private pixels: image.PixelMap | undefined = undefined;
  @State private fallback: boolean = false;
  private viewportWidth: number = 0;
  private viewportHeight: number = 0;
  private mounted: boolean = false;
  private revision: number = 0;
  private displayed: PageBackgroundTexture | undefined = undefined;
  private pending: PageBackgroundTexture | undefined = undefined;
  private resizeTimer: number = -1;

  private appearance(): string {
    const wallpaper: PageBackgroundState = pageBackgroundFromValue(this.backgroundValue);
    const color: ColorMetrics = ColorMetrics.resourceColor(pageBackgroundBaseColor(
      wallpaper, this.displayMode, this.darkSurface));
    return pageBackgroundTextureStyle(wallpaper, this.displayMode + '|' + this.darkSurface + '|' + this.systemDark.toString() +
      '|' + color.red.toString() + ',' + color.green.toString() + ',' + color.blue.toString() +
      '|' + this.getUIContext().vp2px(1).toString());
  }

  aboutToAppear(): void {
    this.mounted = true;
    if (!pageBackgroundActive(this.backgroundValue)) { return; }
    // A new destination can paint a ready texture on its first frame. Its exact
    // pane size is requested after measurement without rebuilding motif nodes.
    this.displayed = pageBackgroundTextureCache.reuse(this.appearance());
    this.pixels = this.displayed?.pixels;
    this.refresh();
  }

  aboutToDisappear(): void {
    this.mounted = false;
    if (this.resizeTimer >= 0) { clearTimeout(this.resizeTimer); this.resizeTimer = -1; }
    this.revision++;
    this.pixels = undefined;
    if (this.pending !== undefined) { pageBackgroundTextureCache.release(this.pending); this.pending = undefined; }
    if (this.displayed !== undefined) { pageBackgroundTextureCache.release(this.displayed); this.displayed = undefined; }
  }

  private backgroundChanged(): void {
    if (!this.mounted) { return; }
    this.refresh();
  }

  @Builder
  private RasterSource(wallpaper: PageBackgroundState, width: number, height: number): void {
    Stack() {
      PageBackgroundLayer({ wallpaper: wallpaper, rasterWidth: width, rasterHeight: height, syncImages: true })
    }.width(width).height(height)
  }

  private show(entry: PageBackgroundTexture): void {
    const previous: PageBackgroundTexture | undefined = this.displayed;
    this.displayed = entry;
    this.pending = undefined;
    this.pixels = entry.pixels;
    this.fallback = false;
    if (previous !== undefined) { pageBackgroundTextureCache.release(previous); }
  }

  private refresh(): void {
    if (!this.mounted) { return; }
    if (!pageBackgroundActive(this.backgroundValue)) {
      this.aboutToDisappear(); this.mounted = true; pageBackgroundTextureCache.clear(); return;
    }
    const appearance: string = this.appearance();
    if (this.displayed !== undefined && this.displayed.appearance !== appearance) {
      this.pixels = undefined;
      pageBackgroundTextureCache.release(this.displayed);
      this.displayed = undefined;
    }
    // Small settings previews can crop the existing page texture. Do not build
    // another complete pattern just to match their frame's dimensions.
    if (this.reuseTexture && this.displayed !== undefined) { return; }
    if (this.viewportWidth <= 0 || this.viewportHeight <= 0) { return; }
    const width: number = this.viewportWidth;
    const height: number = this.viewportHeight;
    const key: string = appearance + '|' + width.toString() + 'x' + height.toString();
    if (this.displayed?.key === key || this.pending?.key === key) { return; }
    const revision: number = ++this.revision;
    this.fallback = false;
    if (this.pending !== undefined) { pageBackgroundTextureCache.release(this.pending); this.pending = undefined; }
    const wallpaper: PageBackgroundState = pageBackgroundFromValue(this.backgroundValue);
    const context: UIContext = this.getUIContext();
    const scale: number = Math.min(1, Math.sqrt(PAGE_BACKGROUND_TEXTURE_PIXELS /
      (context.vp2px(width) * context.vp2px(height))));
    const entry: PageBackgroundTexture = pageBackgroundTextureCache.acquire(key, appearance,
      (): Promise<image.PixelMap> => context.getComponentSnapshot().createFromBuilder(
        (): void => { this.RasterSource(wallpaper, width, height); }, 300, true,
        { scale: scale, waitUntilRenderFinished: true }));
    if (entry.pixels !== undefined) { this.show(entry); return; }
    this.pending = entry;
    entry.ready.then((pixels: image.PixelMap | undefined): void => {
      if (!this.mounted || revision !== this.revision) { return; }
      if (pixels !== undefined) { this.show(entry); }
      else {
        this.pending = undefined;
        pageBackgroundTextureCache.release(entry);
        this.fallback = this.displayed === undefined;
      }
    });
  }

  build(): void {
    Stack() {
      if (pageBackgroundActive(this.backgroundValue)) {
        if (this.pixels !== undefined) {
          Image(this.pixels).width('100%').height('100%').objectFit(ImageFit.Cover)
            .draggable(false).syncLoad(true).id('shared-page-background-texture')
        } else if (this.fallback) {
          PageBackgroundLayer({ wallpaper: pageBackgroundFromValue(this.backgroundValue) })
        } else {
          Column().width('100%').height('100%').backgroundColor(pageBackgroundBaseColor(
            pageBackgroundFromValue(this.backgroundValue), this.displayMode, this.darkSurface))
        }
      }
    }.width('100%').height('100%').clip(true).hitTestBehavior(HitTestMode.None)
      .onAreaChange((_old: Area, area: Area): void => {
        const width: number = Math.round(Number(area.width));
        const height: number = Math.round(Number(area.height));
        if (width > 0 && height > 0 && (width !== this.viewportWidth || height !== this.viewportHeight)) {
          this.viewportWidth = width; this.viewportHeight = height;
          if (this.resizeTimer >= 0) { clearTimeout(this.resizeTimer); }
          this.resizeTimer = setTimeout((): void => { this.resizeTimer = -1; this.refresh(); }, 100);
        }
      })
  }
}

// Each destination paints a complete surface, including during native page
// transitions. Transparent content can never reveal the previous destination.
@Builder
export function appPageBackground(reuseTexture: boolean = false): void { AppPageBackgroundLayer({ reuseTexture: reuseTexture }); }
