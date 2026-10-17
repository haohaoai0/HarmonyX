import { common } from '@kit.AbilityKit';
import { picker } from '@kit.CoreFileKit';
import { HdsNavDestination, HdsNavDestinationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { sidebarHandlePresets, SidebarHandlePreset, sidebarHandleStore, STORAGE_KEY_SIDEBAR_HANDLE_STYLE,
  STORAGE_KEY_SIDEBAR_HANDLE_PATH, SIDEBAR_HANDLE_DEFAULT, SIDEBAR_HANDLE_CUSTOM } from '../services/SidebarHandleStore';
import { SidebarExpandHandle } from '../components/SidebarExpandHandle';
import { cardSurfaceColor, pageSurfaceColor } from '../utils/ThemeColors';
import { destinationTitleBarStyle } from '../utils/DestinationTitleBar';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';

@Builder
export function SidebarHandleSettingsBuilder(): void { SidebarHandleSettings(); }

@Component
struct SidebarHandleSettings {
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp(STORAGE_KEY_SIDEBAR_HANDLE_STYLE) private selected: string = SIDEBAR_HANDLE_DEFAULT;
  @StorageProp(STORAGE_KEY_SIDEBAR_HANDLE_PATH) private imagePath: string = '';
  @StorageProp('harmonyx.status_bar_height') private topInset: number = 0;
  @StorageProp('harmonyx.navigation_indicator_height') private bottomInset: number = 0;
  @StorageProp('harmonyx.display_mode') private displayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private darkSurface: string = '';
  @StorageProp('harmonyx.accent_color') private accent: string = '#007DFF';
  @StorageProp('harmonyx.title_bar_style_mode') private titleBarStyle: number = 0;
  @StorageProp('harmonyx.desktop_layout') private desktopLayout: boolean = false;
  @StorageProp('harmonyx.breakpoint') private breakpoint: string = 'sm';
  @State private picking: boolean = false;
  private disposed: boolean = false;
  private scroller: Scroller = new Scroller();

  aboutToDisappear(): void { this.disposed = true; }

  private toast(resource: Resource): void {
    this.getUIContext().getPromptAction().showToast({
      message: (getContext(this) as common.UIAbilityContext).resourceManager.getStringSync(resource)
    });
  }

  private select(style: string): void {
    if (!sidebarHandleStore.select(getContext(this) as common.UIAbilityContext, style)) {
      this.toast($r('app.string.settings_layout_save_failed'));
    }
  }

  private async importImage(): Promise<void> {
    if (this.picking) { return; }
    this.picking = true;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    try {
      const dialog: picker.DocumentViewPicker = new picker.DocumentViewPicker(context);
      const options: picker.DocumentSelectOptions = { maxSelectNumber: 1,
        fileSuffixFilters: ['PNG|.png', 'JPEG|.jpg,.jpeg', 'GIF|.gif', 'WebP|.webp'] };
      const uris: string[] = await dialog.select(options);
      if (uris.length === 0 || this.disposed) { return; }
      await sidebarHandleStore.importImage(context, uris[0]);
      if (!this.disposed) { this.toast($r('app.string.sidebar_handle_imported')); }
    } catch (error) {
      if (!this.disposed) {
        this.toast((error as Error).message === 'sidebar_image_spec' ?
          $r('app.string.sidebar_handle_invalid') : $r('app.string.sidebar_handle_import_failed'));
      }
    } finally { if (!this.disposed) { this.picking = false; } }
  }

  @Builder
  private Preview(): void {
    Stack({ alignContent: Alignment.Start }) {
      Column({ space: 14 }) {
        Row({ space: 10 }) {
          Circle().width(24).height(24).fill($r('app.color.sidebar_preview_accent'))
          Column().height(10).layoutWeight(1).borderRadius(5).backgroundColor($r('app.color.sidebar_preview_line'))
        }.width('100%')
        Column().width('100%').height(72).borderRadius(14).backgroundColor($r('app.color.sidebar_preview_tile'))
        Column().width('72%').height(10).borderRadius(5).backgroundColor($r('app.color.sidebar_preview_line'))
      }.width('100%').padding({ left: 72, right: 24, top: 24, bottom: 24 }).alignItems(HorizontalAlign.Start)
      SidebarExpandHandle({ style: this.selected, imagePath: this.imagePath })
    }.width('100%').height(200).borderRadius(20).clip(true)
      .backgroundColor(cardSurfaceColor(this.displayMode, this.darkSurface)).id('sidebar-handle-preview')
  }

  @Builder
  private Tile(id: string, title: Resource): void {
    Button({ type: ButtonType.Normal }) {
      Column({ space: 12 }) {
        Stack({ alignContent: Alignment.Start }) {
          SidebarExpandHandle({ style: id, imagePath: this.imagePath })
          if (this.selected === id) {
            SymbolGlyph($r('sys.symbol.checkmark_circle_fill')).fontSize(20).fontColor([this.accent])
              .position({ x: '76%', y: 10 })
          }
        }.width('100%').height(100).borderRadius(14).clip(true)
          .backgroundColor(cardSurfaceColor(this.displayMode, this.darkSurface))
        Text(title).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
          .fontWeight(this.selected === id ? FontWeight.Bold : FontWeight.Regular)
          .fontColor(this.selected === id ? this.accent : $r('app.color.text_primary')).maxLines(1)
      }.width('100%')
    }.width('100%').padding(10).borderRadius(18).backgroundColor(Color.Transparent)
      .border({ width: this.selected === id ? 2 : 1, color: this.selected === id ? this.accent : $r('app.color.divider') })
      .borderRadius(18)
      .accessibilityText(title).id('sidebar-handle-style-' + id).enabled(!this.picking)
      .onClick((): void => this.select(id))
  }

  build(): void {
    HdsNavDestination() {
      Scroll(this.scroller) {
        Column({ space: 18 }) {
          this.Preview()
          Text($r('app.string.sidebar_handle_style_desc')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
            .fontColor($r('app.color.text_secondary')).width('100%')
          GridRow({ columns: 2, gutter: { x: 12, y: 12 } }) {
            ForEach(sidebarHandlePresets(), (preset: SidebarHandlePreset): void => {
              GridCol() { this.Tile(preset.id, preset.title) }
            }, (preset: SidebarHandlePreset): string => preset.id)
            if (this.imagePath.length > 0) {
              GridCol() { this.Tile(SIDEBAR_HANDLE_CUSTOM, $r('app.string.sidebar_handle_custom')) }
            }
          }.width('100%')
          Button({ type: ButtonType.Normal }) {
            Row({ space: 12 }) {
              SymbolGlyph($r('sys.symbol.picture')).fontSize(24).fontColor([this.accent])
              Text($r('app.string.sidebar_handle_import')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L'))
                .fontColor($r('app.color.text_primary')).layoutWeight(1).textAlign(TextAlign.Start)
              if (this.picking) { LoadingProgress().width(24).height(24) }
              else { SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(18).fontColor([$r('app.color.text_secondary')]) }
            }.width('100%')
          }.width('100%').height(60).padding({ left: 16, right: 16 }).borderRadius(16)
            .backgroundColor(cardSurfaceColor(this.displayMode, this.darkSurface)).enabled(!this.picking)
            .id('sidebar-handle-import').onClick((): void => { this.importImage(); })
          Text($r('app.string.sidebar_handle_image_spec')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S'))
            .fontColor($r('app.color.text_secondary')).width('100%')
        }.width('100%').padding({ left: 20, right: 20,
          top: this.desktopLayout && ResponsiveLayout.isLarge(this.breakpoint) ? 12 : this.topInset + 74,
          bottom: this.bottomInset + 28 })
      }.width('100%').height('100%').scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    }.titleMode(HdsNavDestinationTitleMode.MINI).hideBackButton(false).bindToScrollable([this.scroller])
      .titleBar({ avoidLayoutSafeArea: true,
        enableComponentSafeArea: this.desktopLayout && ResponsiveLayout.isLarge(this.breakpoint),
        content: { title: { mainTitle: $r('app.string.sidebar_handle_style') } },
        style: destinationTitleBarStyle(ScrollEffectType.GRADIENT_BLUR, this.displayMode, this.darkSurface, this.titleBarStyle) })
      .backgroundColor(pageSurfaceColor(this.displayMode, this.darkSurface))
      .onBackPressed((): boolean => { ResponsiveLayout.closeContentDestination(this.pageStack); return true; })
  }
}
