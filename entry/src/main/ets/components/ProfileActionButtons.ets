import { SystemMaterialUtil } from '../utils/SystemMaterial';
import { ProfileHeaderMotion } from '../utils/ProfileHeaderMotion';
import { MaterialButton } from './MaterialButton';

// Keep this component mounted while moving between the hero and toolbar.
// Each button uses the same native touch light and deformation as viewer controls.
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

  private text(resource: Resource): string {
    return getContext(this).resourceManager.getStringSync(resource);
  }

  private followTint(): ResourceColor | undefined {
    if (this.following) { return undefined; }
    return this.accentColor.length === 7 ? '#66' + this.accentColor.substring(1) : '#66007DFF';
  }

  @Builder
  private Expanded(): void {
    Row({ space: 8 }) {
      Stack() {
        MaterialButton({ nativeMaterialHost: true, buttonWidth: '100%', buttonHeight: 42, buttonRadius: 22,
          adaptiveForeground: true, lightColor: Color.White,
          buttonBorderWidth: SystemMaterialUtil.isApi26OrAbove() ? 0 : 1,
          buttonBorderColor: $r('app.color.divider'), accessibilityLabel: this.text($r('app.string.profile_message')),
          onButtonClick: (): void => this.onMessage() }) {
          Text($r('app.string.profile_message')).fontFamily(this.appFontFamily).fontSize(16)
            .fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
        }
      }.layoutWeight(1).height(42).clip(false)
      Stack() {
        MaterialButton({ nativeMaterialHost: true, buttonWidth: '100%', buttonHeight: 42, buttonRadius: 22,
          adaptiveForeground: true, lightColor: this.following ? Color.White : this.accentColor,
          materialTint: this.followTint(), buttonEnabled: this.followEnabled,
          buttonBorderWidth: SystemMaterialUtil.isApi26OrAbove() ? 0 : 1,
          buttonBorderColor: $r('app.color.divider'), accessibilityLabel: this.text(this.followLabel),
          onButtonClick: (): void => this.onFollow() }) {
          Text(this.followLabel).fontFamily(this.appFontFamily).fontSize(16)
            .fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
        }
      }.layoutWeight(1).height(42).clip(false)
    }.width(this.expandedWidth).height(42).clip(false)
      .scale({ x: ProfileHeaderMotion.interpolate(1, 144 / this.expandedWidth, this.progress),
        y: ProfileHeaderMotion.interpolate(1, 36 / 42, this.progress), centerX: 0, centerY: 0 })
      .opacity(1 - this.progress)
      .hitTestBehavior(this.progress < 0.5 ? HitTestMode.Default : HitTestMode.None)
      .accessibilityLevel(this.progress < 0.5 ? 'auto' : 'no-hide-descendants')
  }

  @Builder
  private Compact(): void {
    Row({ space: 4 }) {
      MaterialButton({ nativeMaterialHost: true, buttonWidth: 36, buttonHeight: 36, buttonRadius: 18,
        adaptiveForeground: true, lightColor: Color.White,
        accessibilityLabel: this.text($r('app.string.profile_message')),
        onButtonClick: (): void => this.onMessage() }) {
        SymbolGlyph($r('sys.symbol.envelope')).fontSize(19).fontColor([$r('app.color.text_primary')])
      }
      MaterialButton({ nativeMaterialHost: true, buttonWidth: 104, buttonHeight: 36, buttonRadius: 18,
        adaptiveForeground: true, lightColor: this.following ? Color.White : this.accentColor,
        materialTint: this.followTint(), buttonEnabled: this.followEnabled,
        accessibilityLabel: this.text(this.followLabel), onButtonClick: (): void => this.onFollow() }) {
        Text(this.followLabel).fontFamily(this.appFontFamily).fontSize(13).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary')).maxLines(1).minFontSize(11).maxFontSize(13)
          .heightAdaptivePolicy(TextHeightAdaptivePolicy.MIN_FONT_SIZE_FIRST)
          .padding({ left: 8, right: 8 })
      }
    }.width(144).height(36).clip(false)
      .scale({ x: ProfileHeaderMotion.interpolate(this.expandedWidth / 144, 1, this.progress),
        y: ProfileHeaderMotion.interpolate(42 / 36, 1, this.progress), centerX: 0, centerY: 0 })
      .opacity(this.progress)
      .hitTestBehavior(this.progress >= 0.5 ? HitTestMode.Default : HitTestMode.None)
      .accessibilityLevel(this.progress >= 0.5 ? 'auto' : 'no-hide-descendants')
  }

  build(): void {
    Stack({ alignContent: Alignment.TopStart }) { this.Expanded(); this.Compact(); }
      .width(this.expandedWidth).height(42).hitTestBehavior(HitTestMode.Transparent)
      .clip(false)
  }
}
