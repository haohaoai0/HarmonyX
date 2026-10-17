import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { common } from '@kit.AbilityKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { uiMaterial } from '@kit.ArkUI';
import { SpaceRoom } from '../models/Space';
import { SPACE_PLAYBACK_REVISION, spacePlayback } from '../services/SpacePlayback';
import {
  DEFAULT_REPLY_CAPSULE_MATERIAL_LEVEL,
  STORAGE_KEY_REPLY_CAPSULE_MATERIAL_LEVEL
} from '../services/AppearanceStore';
import { cardSurfaceColor } from '../utils/ThemeColors';
import { SystemMaterialUtil } from '../utils/SystemMaterial';

@Component
export struct SpaceListeningBar {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp(SPACE_PLAYBACK_REVISION) playbackRevision: number = 0;
  @StorageProp('harmonyx.display_mode') themeDisplayMode: string = '';
  @StorageProp('harmonyx.dark_surface') themeDarkSurface: string = '';
  @StorageLink(STORAGE_KEY_REPLY_CAPSULE_MATERIAL_LEVEL)
  private capsuleMaterialLevel: number = DEFAULT_REPLY_CAPSULE_MATERIAL_LEVEL;
  onOpen: (room: SpaceRoom) => void = (): void => {};

  private room(): SpaceRoom | null { return this.playbackRevision >= 0 ? spacePlayback.room : null; }
  private state(): string { return this.playbackRevision >= 0 ? spacePlayback.state : 'idle'; }
  private playing(): boolean { return this.state() === 'playing' || this.state() === 'buffering'; }
  private busy(): boolean { return this.state() === 'loading' || this.state() === 'buffering'; }
  private status(): Resource {
    return this.busy() ? $r('app.string.spaces_connecting') : this.state() === 'error' ?
      $r('app.string.spaces_audio_failed') : this.state() === 'ended' ? $r('app.string.spaces_ended') :
      this.playing() ? $r('app.string.spaces_listening') : $r('app.string.spaces_paused');
  }
  private capsuleMaterial(): uiMaterial.Material | undefined {
    if (!deviceInfo.apiAvailable('26.0.0')) {
      return undefined;
    }
    return new uiMaterial.ImmersiveMaterial({
      style: SystemMaterialUtil.resolveImmersiveStyle(this.capsuleMaterialLevel),
      interactive: true,
      applyShadow: false,
      colorInvert: true,
      lightEffect: {}
    });
  }

  @Builder
  private CapsuleSurfaceContent(): void {
    Row({ space: 8 }) {
      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.waveform')).fontSize(24).fontColor([$r('app.color.space_accent')])
        Column({ space: 3 }) {
          Text(this.room()?.title || $r('app.string.spaces_untitled')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
            .fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.status()).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S')).fontColor($r('app.color.space_accent'))
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      }.layoutWeight(1).onClick((): void => {
        const room: SpaceRoom | null = this.room(); if (room !== null) { this.onOpen(room); }
      }).accessibilityText($r('app.string.spaces_expand'))
      Button({ type: ButtonType.Circle }) {
        if (this.busy()) { LoadingProgress().width(22).height(22).color($r('app.color.space_accent')) }
        else {
          SymbolGlyph(this.playing() ? $r('sys.symbol.pause_fill') : $r('sys.symbol.play_fill'))
            .fontSize(18).fontColor([$r('app.color.space_accent')])
        }
      }.width(40).height(40).backgroundColor(Color.Transparent).enabled(!this.busy())
        .accessibilityText(this.playing() ? $r('app.string.spaces_pause') : $r('app.string.spaces_listen'))
        .onClick((): void => {
          const room: SpaceRoom | null = this.room();
          if (this.playing()) { spacePlayback.pausePlayback(); }
          else if (room !== null && spacePlayback.state !== 'ended') {
            spacePlayback.listen(getContext(this) as common.UIAbilityContext, room);
          }
        })
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.xmark')).fontSize(18).fontColor([$r('app.color.text_secondary')])
      }.width(40).height(40).backgroundColor(Color.Transparent)
        .accessibilityText($r('app.string.spaces_leave')).onClick((): void => { spacePlayback.stop(); })
    }.width('100%').height(64).padding({ left: 16, right: 8, top: 8, bottom: 8 })
      .backgroundColor(SystemMaterialUtil.isApi26OrAbove() ? Color.Transparent :
        cardSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
      .border({ width: SystemMaterialUtil.isApi26OrAbove() ? 0 : 1, color: $r('app.color.divider') })
      .borderRadius(32)
      .clip(true)
      .systemMaterial(this.capsuleMaterial())
  }

  build(): void {
    if (this.room() !== null) {
      // Use the same native title-builder host as ReplyComposerCapsule.
      Navigation() {
        Column().width('100%').height('100%').hitTestBehavior(HitTestMode.None)
      }
      .title({
        builder: (): void => { this.CapsuleSurfaceContent(); },
        height: 64
      }, { barStyle: BarStyle.STACK })
      .titleMode(NavigationTitleMode.Full)
      .mode(NavigationMode.Stack)
      .hideToolBar(true)
      .backgroundColor(Color.Transparent)
      .width('100%')
      .height(64)
    }
  }
}
