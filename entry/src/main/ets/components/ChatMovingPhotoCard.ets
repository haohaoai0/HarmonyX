import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { common } from '@kit.AbilityKit';
import { MovingPhotoView, MovingPhotoViewController, photoAccessHelper } from '@kit.MediaLibraryKit';
import { connection } from '@kit.NetworkKit';
import { fileUri } from '@kit.CoreFileKit';
import { LengthMetrics } from '@kit.ArkUI';
import { DmAttachment } from '../models/Tweet';
import { xChatMedia } from '../services/XChatMedia';
import { xChatActions } from '../services/XChatActions';
import { chatVoicePlayback } from '../services/ChatVoicePlayback';
import { chatControlMaterial, chatInputMaterial } from '../utils/ChatMaterial';
import { SystemMaterialUtil } from '../utils/SystemMaterial';
import { ChatAlbumGeometry, chatAlbumLayout } from '../utils/ChatAlbumLayout';
import { materialModifier } from '../utils/SystemMaterial';
import { MaterialCompat } from '../utils/MaterialCompat';

interface MovingPhotoPopupState { isVisible: boolean; }

@Component
export struct ChatMovingPhotoCard {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  // MovingPhoto owns a native handle. @Prop deep-copies objects and loses that handle.
  // Keep the original instance; only ordinary UI values participate in state management.
  selectedPhoto: photoAccessHelper.MovingPhoto | undefined = undefined;
  @Prop sourceUri: string = '';
  @Prop attachment: DmAttachment | undefined = undefined;
  @Prop video: DmAttachment | undefined = undefined;
  @Prop conversationId: string = '';
  @Prop keyVersion: string = '';
  @Prop compact: boolean = false;
  @Prop tileWidth: number = 0;
  @Prop tileHeight: number = 0;
  onDimensions: (width: number, height: number) => void = (_width: number, _height: number): void => {};
  onLongPress: () => void = (): void => {};
  @Prop @Watch('visibilityChanged') visible: boolean = true;
  private photo: photoAccessHelper.MovingPhoto | undefined = undefined;
  @State private photoReady: boolean = false;
  @State private coverUri: string = '';
  @State private busy: boolean = false;
  @State private failed: boolean = false;
  @State private onScreen: boolean = true;
  @State private liveEnabled: boolean = true;
  @State private muted: boolean = false;
  @State private menuShown: boolean = false;
  @State private playerRevision: number = 0;
  @StorageLink('harmonyx.accent_color') accentColor: string = '#007DFF';
  private controller: MovingPhotoViewController = new MovingPhotoViewController();
  private active: boolean = true;
  private generation: number = 0;
  private playerPrepared: boolean = false;
  private pendingPlayback: boolean = false;
  private stopPlayback: () => void = (): void => { this.stopPlayer(); };

  private context(): common.UIAbilityContext { return getContext(this) as common.UIAbilityContext; }

  aboutToAppear(): void {
    this.active = true;
    this.photo = this.selectedPhoto;
    this.photoReady = this.photo !== undefined;
    this.coverUri = this.sourceUri;
    if (this.selectedPhoto === undefined) { this.autoLoad(); }
  }

  aboutToDisappear(): void {
    this.active = false; this.generation++; this.visibilityChanged();
  }

  private visibilityChanged(): void {
    if (!this.visible || !this.active) {
      this.menuShown = false;
      this.retirePlayer();
    }
  }

  private canPlay(): boolean { return this.active && this.visible && this.onScreen && this.liveEnabled; }

  private stopPlayer(): void {
    this.pendingPlayback = false;
    this.controller.stopPlayback();
    chatVoicePlayback.release(this.stopPlayback);
  }

  private retirePlayer(): void {
    this.stopPlayer();
    this.playerPrepared = false;
    this.playerRevision++;
    this.controller = new MovingPhotoViewController();
  }

  private play(): void {
    if (!this.canPlay()) { return; }
    this.menuShown = false;
    this.pendingPlayback = true;
    if (!this.photoReady || this.failed) { this.retry(); return; }
    if (this.playerPrepared) {
      this.pendingPlayback = false;
      this.controller.stopPlayback();
      this.controller.startPlayback();
    }
  }

  private prepared(revision: number): void {
    if (revision !== this.playerRevision || !this.canPlay()) { return; }
    this.playerPrepared = true;
    if (this.pendingPlayback) {
      this.pendingPlayback = false;
      this.controller.startPlayback();
    }
  }

  private toggleLive(): void {
    this.menuShown = false;
    this.liveEnabled = !this.liveEnabled;
    if (!this.liveEnabled) { this.retirePlayer(); }
    else if (!this.photoReady || this.failed) { this.retry(); }
  }

  private replay(): void { this.liveEnabled = true; this.play(); }

  private async permits(key: string): Promise<boolean> {
    const policy: string = xChatActions.localString(this.context(), key, 'all');
    if (policy === 'never') { return false; }
    if (policy !== 'wifi') { return true; }
    try {
      const net: connection.NetHandle = await connection.getDefaultNet();
      const capabilities: connection.NetCapabilities = await connection.getNetCapabilities(net);
      return capabilities.bearerTypes.indexOf(connection.NetBearType.BEARER_WIFI) >= 0;
    } catch (error) { return false; }
  }

  private async autoLoad(): Promise<void> {
    const cover: DmAttachment | undefined = this.attachment;
    const video: DmAttachment | undefined = this.video;
    if (cover === undefined || video === undefined) { return; }
    const cached: string = xChatMedia.cachedPath(this.context(), this.conversationId, cover.mediaHash);
    if (cached.length > 0) { this.coverUri = fileUri.getUriFromPath(cached); }
    const cachedVideo: string = xChatMedia.cachedPath(this.context(), this.conversationId, video.mediaHash);
    if (cached.length > 0 && cachedVideo.length > 0) { await this.load(true); return; }
    if (this.coverUri.length === 0 && await this.permits('download_photos')) { await this.load(false); }
    if (this.active && this.coverUri.length > 0 && (cachedVideo.length > 0 || await this.permits('download_videos'))) {
      await this.load(true);
    }
  }

  private async load(withVideo: boolean): Promise<void> {
    const cover: DmAttachment | undefined = this.attachment;
    const video: DmAttachment | undefined = this.video;
    if (!this.active || this.busy || cover === undefined || video === undefined) { return; }
    const generation: number = ++this.generation;
    this.busy = true; this.failed = false;
    try {
      const path: string = await xChatMedia.receive(this.context(), this.conversationId,
        cover.mediaHash, this.keyVersion, 1);
      if (!this.active || generation !== this.generation) { return; }
      this.coverUri = fileUri.getUriFromPath(path);
      if (!withVideo) { return; }
      const videoPath: string = await xChatMedia.receive(this.context(), this.conversationId,
        video.mediaHash, this.keyVersion, 3);
      if (!this.active || generation !== this.generation) { return; }
      const photo: photoAccessHelper.MovingPhoto = await photoAccessHelper.MediaAssetManager.loadMovingPhoto(
        this.context(), this.coverUri, fileUri.getUriFromPath(videoPath));
      if (this.active && generation === this.generation) {
        this.photo = photo;
        this.photoReady = true;
      }
    } catch (error) {
      if (this.active && generation === this.generation) { this.failed = true; }
    } finally {
      if (this.active && generation === this.generation) { this.busy = false; }
    }
  }

  private retry(): void {
    this.retirePlayer();
    this.pendingPlayback = this.canPlay();
    this.failed = false;
    if (this.selectedPhoto !== undefined) { this.photo = this.selectedPhoto; this.photoReady = true; }
    else { this.photoReady = false; this.photo = undefined; this.load(true); }
  }

  private photoSize(): ChatAlbumGeometry {
    const cover: DmAttachment | undefined = this.attachment;
    const width: number = this.getUIContext().px2vp(this.context().resourceManager.getNumber(this.compact ?
      $r('app.float.chat_moving_photo_preview_size').id : $r('app.float.chat_media_single_max_width').id));
    const height: number = this.getUIContext().px2vp(this.context().resourceManager.getNumber(this.compact ?
      $r('app.float.chat_moving_photo_preview_size').id : $r('app.float.chat_media_single_max_height').id));
    return chatAlbumLayout([{ width: this.compact ? 1 : cover?.width ?? 1,
      height: this.compact ? 1 : cover?.height ?? 1 }], width, height, 0);
  }

  private controlSize(): Resource {
    return this.compact ? $r('app.float.chat_moving_photo_compact_control_size') :
      $r('app.float.chat_moving_photo_control_size');
  }

  @Builder
  private Player(revision: number): void {
    if (this.photo !== undefined) {
      MovingPhotoView({ movingPhoto: this.photo, controller: this.controller })
        .width('100%').height('100%').objectFit(this.compact || this.tileWidth > 0 ? ImageFit.Cover : ImageFit.Contain)
        .muted(this.muted).hitTestBehavior(HitTestMode.None)
        .onPrepared((): void => { this.prepared(revision); })
        .onStart((): void => {
          if (revision === this.playerRevision && this.canPlay()) { chatVoicePlayback.claim(this.stopPlayback); }
        })
        .onFinish((): void => {
          if (revision === this.playerRevision) { chatVoicePlayback.release(this.stopPlayback); }
        })
        .onStop((): void => {
          if (revision === this.playerRevision) { chatVoicePlayback.release(this.stopPlayback); }
        })
        .onError((): void => {
          if (revision === this.playerRevision) {
            this.failed = true; this.playerPrepared = false; this.pendingPlayback = false;
            chatVoicePlayback.release(this.stopPlayback);
          }
        })
    }
  }

  @Builder
  private LiveMenuPanel(): void {
    Column() {
      Button({ type: ButtonType.Normal }) {
        Row({ space: 8 }) {
          SymbolGlyph(this.liveEnabled ? $r('sys.symbol.livephoto_slash') : $r('sys.symbol.livephoto'))
            .fontSize($r('sys.float.Body_L')).fontColor([$r('app.color.text_primary')])
          Text(this.liveEnabled ? $r('app.string.chat_moving_photo_disable') : $r('app.string.chat_moving_photo_enable')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_primary'))
        }.width('100%')
      }.height($r('app.float.chat_moving_photo_menu_row_height')).width('100%')
        .backgroundColor(Color.Transparent).borderRadius($r('app.float.chat_moving_photo_menu_row_radius'))
        .onClick((): void => { this.toggleLive(); }).monopolizeEvents(true)
      Divider().color($r('app.color.divider'))
      Button({ type: ButtonType.Normal }) {
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.arrow_clockwise')).fontSize($r('sys.float.Body_L'))
            .fontColor([$r('app.color.text_primary')])
          Text($r('app.string.chat_moving_photo_replay')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
            .fontColor($r('app.color.text_primary'))
        }.width('100%')
      }.height($r('app.float.chat_moving_photo_menu_row_height')).width('100%')
        .backgroundColor(Color.Transparent).borderRadius($r('app.float.chat_moving_photo_menu_row_radius'))
        .onClick((): void => { this.menuShown = false; this.replay(); }).monopolizeEvents(true)
    }.width('100%').height('100%').padding($r('app.float.chat_moving_photo_menu_padding'))
      .borderRadius($r('app.float.chat_moving_photo_menu_radius')).clip(true)
      .backgroundColor(SystemMaterialUtil.isApi26OrAbove() ? Color.Transparent : $r('app.color.bg_secondary_btn'))
      .attributeModifier(materialModifier(chatInputMaterial(3)))
  }

  @Builder
  private LiveMenu(): void {
    Navigation() { Column().height(0).hitTestBehavior(HitTestMode.None) }
      .title({ builder: (): void => { this.LiveMenuPanel(); }, height: $r('app.float.chat_moving_photo_menu_height') },
        { barStyle: BarStyle.STACK, backgroundColor: Color.Transparent,
          paddingStart: LengthMetrics.vp(0), paddingEnd: LengthMetrics.vp(0) })
      .titleMode(NavigationTitleMode.Full).mode(NavigationMode.Stack).hideBackButton(true).hideToolBar(true)
      .width($r('app.float.chat_moving_photo_menu_width')).height($r('app.float.chat_moving_photo_menu_height'))
      .backgroundColor(Color.Transparent)
  }

  @Builder
  private LiveBadgeButton(): void {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 4 }) {
        SymbolGlyph(this.liveEnabled ? $r('sys.symbol.livephoto') : $r('sys.symbol.livephoto_slash'))
          .fontSize($r('sys.float.Body_M')).fontColor([$r('app.color.text_primary')])
        if (!this.compact) {
          Text($r('app.string.chat_moving_photo_live')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S'))
            .fontColor($r('app.color.text_primary')).maxLines(1)
        }
        SymbolGlyph($r('sys.symbol.chevron_down')).fontSize($r('app.float.chat_moving_photo_chevron_size'))
          .fontColor([$r('app.color.text_primary')])
      }
    }.width('100%').height('100%').padding(0).borderRadius(this.controlSize()).clip(!SystemMaterialUtil.isApi26OrAbove())
      .backgroundColor(SystemMaterialUtil.isApi26OrAbove() ? Color.Transparent : $r('app.color.bg_secondary_btn'))
      .attributeModifier(materialModifier(chatControlMaterial(this.accentColor)))
      .accessibilityText($r('app.string.chat_moving_photo_options'))
      .onClick((): void => { this.menuShown = !this.menuShown; })
      .bindPopup(this.menuShown, { builder: this.LiveMenu(), placement: Placement.BottomLeft, enableArrow: false,
        popupColor: Color.Transparent, backgroundBlurStyle: BlurStyle.NONE, autoCancel: true,
        onStateChange: (state: MovingPhotoPopupState): void => { this.menuShown = state.isVisible; } })
  }

  @Builder
  private LiveBadge(): void {
    Navigation() { Column().height(0).hitTestBehavior(HitTestMode.None) }
      .title({ builder: (): void => { this.LiveBadgeButton(); }, height: this.controlSize() },
        { barStyle: BarStyle.STACK, backgroundColor: Color.Transparent,
          backgroundBlurStyle: MaterialCompat.NO_PLATE_BLUR,
          paddingStart: LengthMetrics.vp(0), paddingEnd: LengthMetrics.vp(0) })
      .titleMode(NavigationTitleMode.Full).mode(NavigationMode.Stack).hideBackButton(true).hideToolBar(true)
      .width(this.compact ? $r('app.float.chat_moving_photo_compact_badge_width') : $r('app.float.chat_moving_photo_badge_width'))
      .height(this.controlSize()).backgroundColor(Color.Transparent)
      .clip(false)
      .id('chat-moving-photo-live-badge')
      .alignRules({ left: { anchor: '__container__', align: HorizontalAlign.Start },
        top: { anchor: '__container__', align: VerticalAlign.Top } })
      .margin({ top: $r('app.float.chat_moving_photo_control_inset'),
        left: $r('app.float.chat_moving_photo_control_inset') })
  }

  @Builder
  private SoundButton(): void {
    Button({ type: ButtonType.Circle }) {
      SymbolGlyph(this.muted ? $r('sys.symbol.speaker_slash_fill') : $r('sys.symbol.speaker_wave_2_fill'))
        .fontSize($r('sys.float.Body_L')).fontColor([$r('app.color.text_primary')])
    }.width('100%').height('100%').padding(0)
      .clip(false)
      .backgroundColor(SystemMaterialUtil.isApi26OrAbove() ? Color.Transparent : $r('app.color.bg_secondary_btn'))
      .attributeModifier(materialModifier(chatControlMaterial(this.accentColor))).enabled(this.liveEnabled)
      .accessibilityText(this.muted ? $r('app.string.chat_moving_photo_unmute') : $r('app.string.chat_moving_photo_mute'))
      .onClick((): void => { this.muted = !this.muted; })
  }

  @Builder
  private SoundControl(): void {
    Navigation() { Column().height(0).hitTestBehavior(HitTestMode.None) }
      .title({ builder: (): void => { this.SoundButton(); }, height: this.controlSize() },
        { barStyle: BarStyle.STACK, backgroundColor: Color.Transparent,
          backgroundBlurStyle: MaterialCompat.NO_PLATE_BLUR,
          paddingStart: LengthMetrics.vp(0), paddingEnd: LengthMetrics.vp(0) })
      .titleMode(NavigationTitleMode.Full).mode(NavigationMode.Stack).hideBackButton(true).hideToolBar(true)
      .width(this.controlSize()).height(this.controlSize()).backgroundColor(Color.Transparent)
      .clip(false)
      .id('chat-moving-photo-sound')
      .alignRules({ right: { anchor: '__container__', align: HorizontalAlign.End },
        bottom: { anchor: '__container__', align: VerticalAlign.Bottom } })
      .margin({ bottom: $r('app.float.chat_moving_photo_control_inset'),
        right: $r('app.float.chat_moving_photo_control_inset') })
  }

  build(): void {
    Column({ space: 4 }) {
      Stack() {
        if (this.photoReady && this.photo !== undefined && !this.failed && this.canPlay()) {
          ForEach([this.playerRevision], (revision: number) => { this.Player(revision); }, (revision: number): string => revision.toString())
        } else if (this.coverUri.length > 0) {
          Image(this.coverUri).width('100%').height('100%').objectFit(this.compact || this.tileWidth > 0 ? ImageFit.Cover : ImageFit.Contain)
            .draggable(false).hitTestBehavior(HitTestMode.None)
            .onComplete((event): void => {
              if (event !== undefined && event.width > 0 && event.height > 0) { this.onDimensions(event.width, event.height); }
            })
        } else {
          Column().width('100%').height('100%').backgroundColor($r('app.color.bg_secondary_btn'))
        }
        if (this.busy) {
          LoadingProgress().width($r('app.float.chat_moving_photo_loading_size'))
            .height($r('app.float.chat_moving_photo_loading_size')).color(this.accentColor)
            .align(Alignment.Center).hitTestBehavior(HitTestMode.None)
        }
        RelativeContainer() { this.LiveBadge(); this.SoundControl(); }
          .width('100%').height('100%').hitTestBehavior(HitTestMode.Transparent)
      }.width(this.tileWidth > 0 ? this.tileWidth : this.photoSize().width)
        .height(this.tileHeight > 0 ? this.tileHeight : this.photoSize().height)
        .borderRadius(this.tileWidth > 0 ? 0 : $r('app.float.chat_bubble_radius')).clip(true)
        .gesture(GestureGroup(GestureMode.Exclusive,
          LongPressGesture({ repeat: false, duration: 500 }).onAction((): void => { this.onLongPress(); }),
          TapGesture().onAction((): void => { this.play(); })
        ))
        .accessibilityText($r('app.string.chat_moving_photo_play_hint'))
        .onVisibleAreaChange([0, 1], (visible: boolean, ratio: number): void => {
          const onScreen: boolean = visible && ratio > 0;
          if (this.onScreen && !onScreen) { this.menuShown = false; this.retirePlayer(); }
          this.onScreen = onScreen;
        })
      if (this.failed && this.tileWidth === 0) {
        Text($r('app.string.chat_retry')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S')).fontColor(this.accentColor)
          .onClick((): void => { this.retry(); })
      } else if (!this.compact && this.photoReady && this.tileWidth === 0) {
        Text($r('app.string.chat_moving_photo_play_hint')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S'))
          .fontColor($r('app.color.text_secondary'))
      }
    }.alignItems(HorizontalAlign.Start)
  }
}
