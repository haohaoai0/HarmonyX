@Component
export struct ChatMoreSymbol {
  build(): void {
    Row({ space: 4 }) {
      SymbolGlyph($r('sys.symbol.dot')).fontSize(8).fontColor([$r('app.color.text_primary')])
      SymbolGlyph($r('sys.symbol.dot')).fontSize(8).fontColor([$r('app.color.text_primary')])
      SymbolGlyph($r('sys.symbol.dot')).fontSize(8).fontColor([$r('app.color.text_primary')])
    }.height(24).justifyContent(FlexAlign.Center).alignItems(VerticalAlign.Center)
  }
}
