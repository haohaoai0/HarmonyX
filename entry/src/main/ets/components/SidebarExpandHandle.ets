import { SIDEBAR_HANDLE_DEFAULT, SIDEBAR_HANDLE_CUSTOM } from '../services/SidebarHandleStore';

// Shared between the live desktop edge and the style-selection preview.
@Component
export struct SidebarExpandHandle {
  @Prop style: string = SIDEBAR_HANDLE_DEFAULT;
  @Prop imagePath: string = '';

  private presetImage(): Resource {
    if (this.style === 'panda') { return $r('app.media.sidebar_handle_panda'); }
    if (this.style === 'cat') { return $r('app.media.sidebar_handle_cat'); }
    if (this.style === 'wave') { return $r('app.media.sidebar_handle_wave'); }
    return $r('app.media.sidebar_handle_eyes');
  }

  build(): void {
    Stack() {
      if (this.style === SIDEBAR_HANDLE_DEFAULT || (this.style === SIDEBAR_HANDLE_CUSTOM && this.imagePath.length === 0)) {
        SymbolGlyph($r('sys.symbol.chevron_right')).fontSize($r('app.float.sidebar_handle_symbol_size'))
          .fontWeight(FontWeight.Bold).fontColor([$r('app.color.text_primary')])
      } else if (this.style === SIDEBAR_HANDLE_CUSTOM) {
        Image('file://' + this.imagePath).width($r('app.float.sidebar_handle_art_size'))
          .height($r('app.float.sidebar_handle_art_size')).objectFit(ImageFit.Contain).draggable(false)
      } else {
        Image(this.presetImage()).width($r('app.float.sidebar_handle_art_size'))
          .height($r('app.float.sidebar_handle_art_size')).objectFit(ImageFit.Contain).draggable(false)
      }
    }.width($r('app.float.desktop_rail_handle_width')).height($r('app.float.desktop_rail_handle_height'))
      .backgroundColor($r('app.color.sidebar_handle_surface'))
      .borderRadius({ topRight: 26, bottomRight: 26 }).hitTestBehavior(HitTestMode.None)
      .accessibilityLevel('no')
  }
}
