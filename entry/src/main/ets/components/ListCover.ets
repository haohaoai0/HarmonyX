import { ProxyMediaImage } from './ProxyMediaImage';

@Component
export struct ListCover {
  @Prop listId: string = '';
  @Prop bannerUrl: string = '';
  @Prop wide: boolean = false;
  @Prop fillParent: boolean = false;
  private color(): ResourceColor {
    const colors: ResourceColor[] = [$r('app.color.list_cover_blue'), $r('app.color.list_cover_cyan'),
      $r('app.color.list_cover_teal'), $r('app.color.list_cover_purple')];
    let hash: number = 0;
    for (let i: number = 0; i < this.listId.length; i++) { hash = (hash * 31 + this.listId.charCodeAt(i)) % 100000; }
    return colors[hash % colors.length];
  }
  build(): void {
    Stack() {
      SymbolGlyph($r('sys.symbol.list_bullet_square'))
        .fontSize(this.wide ? 72 : 30).fontColor([$r('app.color.list_cover_symbol')])
      if (this.bannerUrl.length > 0) {
        ProxyMediaImage({ url: this.bannerUrl, displayHeight: this.wide ? 150 : 60, fillParent: this.fillParent })
      }
    }.width(this.wide ? '100%' : 60)
      .height(this.fillParent ? '100%' : this.wide ? $r('app.float.list_banner_height') : 60)
      .backgroundColor(this.color()).borderRadius(this.wide ? 0 : 14).clip(true)
  }
}
