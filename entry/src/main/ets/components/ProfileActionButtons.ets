import { uiMaterial } from '@kit.ArkUI';
import { SystemMaterialUtil } from '../utils/SystemMaterial';
import { ProfileHeaderMotion } from '../utils/ProfileHeaderMotion';

// One title-builder host, matching ReplyComposerCapsule. Keep this component
// mounted while moving between the hero and toolbar; measurement slots are empty.
@Component
export struct ProfileActionButtons {
  @Prop expandedWidth: number = 312;
  @Prop progress: number = 0;
  @Prop following: boolean = false;
  @Prop followLabel: Resource = $r('app.string.profile_detail_follow');
  @Prop followEnabled: boolean = true;
  @Prop accentColor: string = '#007DFF';
  @Prop appFontFamily: string = '';
  onMessage: () => void = (): void => {};
  onFollow: () => void = (): void => {};
  private cachedNeutral: uiMaterial.Material | undefined = undefined;
  private cachedFollow: uiMaterial.Material | undefined = undefined;
  private cachedAccent: string = '';

  private material(follow: boolean = false): uiMaterial.Material | undefined {
    if (!SystemMaterialUtil.isApi26OrAbove()) { return undefined; }
    if (this.cachedNeutral === undefined) {
      this.cachedNeutral = new uiMaterial.ImmersiveMaterial({
        style: uiMaterial.ImmersiveStyle.THIN, interactive: true, applyShadow: false,
        colorInvert: true, lightEffect: {}
      });
    }
    if (!follow || this.following) { return this.cachedNeutral; }
    if (this.cachedFollow === undefined || this.cachedAccent !== this.accentColor) {
      this.cachedAccent = this.accentColor;
      const tint: string = this.accentColor.length === 7 ? '#66' + this.accentColor.substring(1) : '#66007DFF';
      this.cachedFollow = new uiMaterial.ImmersiveMaterial({
        style: uiMaterial.ImmersiveStyle.THIN, materialColor: tint, interactive: true,
        applyShadow: false, colorInvert: false, lightEffect: { color: this.accentColor }
      });
    }
    return this.cachedFollow;
  }

  @Builder
  private Expanded(): void {
    Row({ space: 8 }) {
      Button($r('app.string.profile_message')).layoutWeight(1).height(42)
        .fontFamily(this.appFontFamily).fontSize(16).fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary')).backgroundColor(Color.Transparent)
        .border({ width: SystemMaterialUtil.isApi26OrAbove() ? 0 : 1, color: $r('app.color.divider') })
        .borderRadius(22).clip(true).onClick((): void => this.onMessage())
        .systemMaterial(this.material())
      Button(this.followLabel).layoutWeight(1).height(42)
        .fontFamily(this.appFontFamily).fontSize(16).fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary')).backgroundColor(Color.Transparent)
        .border({ width: SystemMaterialUtil.isApi26OrAbove() ? 0 : 1, color: $r('app.color.divider') })
        .borderRadius(22).clip(true).enabled(this.followEnabled).onClick((): void => this.onFollow())
        .systemMaterial(this.material(true))
    }.width(this.expandedWidth).height(42)
      .scale({ x: ProfileHeaderMotion.interpolate(1, 144 / this.expandedWidth, this.progress),
        y: ProfileHeaderMotion.interpolate(1, 36 / 42, this.progress), centerX: 0, centerY: 0 })
      .opacity(1 - this.progress)
      .hitTestBehavior(this.progress < 0.5 ? HitTestMode.Default : HitTestMode.None)
      .accessibilityLevel(this.progress < 0.5 ? 'auto' : 'no-hide-descendants')
  }

  @Builder
  private Compact(): void {
    Row({ space: 4 }) {
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.envelope')).fontSize(19).fontColor([$r('app.color.text_primary')])
      }.width(36).height(36).backgroundColor(Color.Transparent).borderRadius(18).clip(true)
        .accessibilityText($r('app.string.profile_message')).onClick((): void => this.onMessage())
        .systemMaterial(this.material())
      Button({ type: ButtonType.Capsule }) {
        Text(this.followLabel).fontFamily(this.appFontFamily).fontSize(13).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary')).maxLines(1).minFontSize(11).maxFontSize(13)
          .heightAdaptivePolicy(TextHeightAdaptivePolicy.MIN_FONT_SIZE_FIRST)
      }.width(104).height(36).padding({ left: 8, right: 8 })
        .backgroundColor(Color.Transparent).borderRadius(18).clip(true).enabled(this.followEnabled)
        .onClick((): void => this.onFollow()).systemMaterial(this.material(true))
    }.width(144).height(36)
      .scale({ x: ProfileHeaderMotion.interpolate(this.expandedWidth / 144, 1, this.progress),
        y: ProfileHeaderMotion.interpolate(42 / 36, 1, this.progress), centerX: 0, centerY: 0 })
      .opacity(this.progress)
      .hitTestBehavior(this.progress >= 0.5 ? HitTestMode.Default : HitTestMode.None)
      .accessibilityLevel(this.progress >= 0.5 ? 'auto' : 'no-hide-descendants')
  }

  @Builder
  private Content(): void {
    Stack({ alignContent: Alignment.TopStart }) { this.Expanded(); this.Compact(); }
      .width(this.expandedWidth).height(42).hitTestBehavior(HitTestMode.Transparent)
  }

  build(): void {
    Navigation() { Column().width('100%').height('100%').hitTestBehavior(HitTestMode.None) }
      .title({ builder: (): void => { this.Content(); }, height: 42 }, { barStyle: BarStyle.STACK })
      .titleMode(NavigationTitleMode.Full).mode(NavigationMode.Stack).hideToolBar(true)
      .backgroundColor(Color.Transparent).width(this.expandedWidth).height(42)
      .hitTestBehavior(HitTestMode.Transparent)
  }
}
