import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { uiMaterial } from '@kit.ArkUI';
import { SystemMaterialUtil } from '../utils/SystemMaterial';
import { DEFAULT_ACCENT_COLOR } from '../services/AppearanceStore';
import { materialModifier } from '../utils/SystemMaterial';

@Component
export struct TitleBarPill {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Prop label: ResourceStr = '';
  @Prop selected: boolean = false;
  @Prop accentColor: string = DEFAULT_ACCENT_COLOR;
  @Prop showChevron: boolean = false;
  onSelect: () => void = (): void => {};
  private cachedAccent: string = '';
  private cachedSelected: boolean = false;
  private cachedMaterial: uiMaterial.Material | undefined = undefined;

  private accessibilityLabel(): string {
    if (typeof this.label === 'string') { return this.label; }
    try { return this.getUIContext().getHostContext()?.resourceManager.getStringSync(this.label) ?? ''; }
    catch (_error) { return ''; }
  }

  private material(): uiMaterial.Material | undefined {
    if (this.cachedMaterial === undefined || this.cachedAccent !== this.accentColor ||
      this.cachedSelected !== this.selected) {
      this.cachedMaterial = SystemMaterialUtil.immersiveMaterial(1, true, false, !this.selected,
        this.accentColor, this.selected ? this.accentColor : undefined);
      this.cachedAccent = this.accentColor;
      this.cachedSelected = this.selected;
    }
    return this.cachedMaterial;
  }

  build(): void {
    Button({ type: ButtonType.Capsule, stateEffect: true }) {
      Row({ space: 4 }) {
        Text(this.label).fontFamily(this.appFontFamily).fontSize($r('app.float.title_bar_pill_font_size')).fontWeight(FontWeight.Medium)
          .fontColor(this.selected ? $r('app.color.text_on_accent') : $r('app.color.text_primary'))
          .maxLines(1)
        if (this.showChevron) {
          SymbolGlyph($r('sys.symbol.chevron_down')).fontSize($r('app.float.title_bar_pill_chevron_size'))
            .fontColor([this.selected ? $r('app.color.text_on_accent') : $r('app.color.text_secondary')])
        }
      }
    }
    .height($r('app.float.title_bar_pill_height'))
    .padding({ left: $r('app.float.title_bar_pill_padding'), right: $r('app.float.title_bar_pill_padding') })
    .backgroundColor(SystemMaterialUtil.isApi26OrAbove() ? Color.Transparent :
      (this.selected ? this.accentColor : $r('app.color.bg_field')))
    .attributeModifier(materialModifier(this.material()))
    .accessibilityGroup(true).accessibilityText(this.accessibilityLabel())
    .onClick((): void => this.onSelect())
  }
}
