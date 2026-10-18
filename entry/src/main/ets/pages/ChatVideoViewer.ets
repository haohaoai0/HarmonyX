import { STORAGE_KEY_PAGE_TRANSITION_MODE, DEFAULT_PAGE_TRANSITION_MODE } from '../services/PageTransitionSettingsStore';
import { pageSystemTransition } from '../utils/PageTransition';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { SurfaceVideoPlayer } from '../components/PostMedia';
import { MediaAttachment } from '../models/Tweet';
import { common } from '@kit.AbilityKit';
import { setChatWindowPrivacy } from '../utils/ChatWindowPrivacy';
import { MediaViewerMotion } from '../components/MediaViewerMotion';
import { captureMediaViewerSource, createMediaSourcePrefix, measureMediaViewerGeometry,
  MediaViewerGeometry, MediaViewerMotionState, MediaViewerSource } from '../utils/MediaViewerMotion';

export interface ChatVideoViewerRouteParam { media: MediaAttachment; screenBlocked?: boolean; source?: MediaViewerSource; }

@Builder
export function ChatVideoViewerBuilder(): void { ChatVideoViewer(); }

@Component
export struct ChatVideoViewer {
  @StorageProp(STORAGE_KEY_PAGE_TRANSITION_MODE) private pageTransitionMode: string = DEFAULT_PAGE_TRANSITION_MODE;
  @State private motion: MediaViewerMotionState = new MediaViewerMotionState();
  @State private initialVideoReady: boolean = false;
  private motionSurfaceId: string = createMediaSourcePrefix() + 'chat-video';
  private closing: boolean = false;
  @StorageProp('reduceMotionEnabled') private reduceMotion: boolean = false;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Consume('pageStack') pageStack: NavPathStack;
  @State private media: MediaAttachment | undefined = undefined;
  @State private visible: boolean = true;
  @State private viewportHeight: number = 0;
  @StorageProp('harmonyx.status_bar_height') statusBarHeight: number = 0;
  @StorageProp('harmonyx.navigation_indicator_height') navigationIndicatorHeight: number = 0;
  private screenBlocked: boolean = false;

  private close(): void {
    if (this.closing) { return; }
    this.closing = true;
    if (!this.motion.enabled()) { this.pageStack.pop(); return; }
    const media: MediaAttachment | undefined = this.media;
    const geometry: MediaViewerGeometry | undefined = measureMediaViewerGeometry(this.getUIContext(),
      this.motionSurfaceId, this.motionSurfaceId + '-frame', media?.width ?? 0, media?.height ?? 0);
    if (geometry === undefined) { this.pageStack.pop(false); return; }
    const openingSource: MediaViewerSource | undefined = this.motion.source;
    const source: MediaViewerSource | undefined = media !== undefined && openingSource !== undefined ?
      captureMediaViewerSource(this.getUIContext(), openingSource.id, media.id,
        media.width, media.height, openingSource.contain, openingSource.radius) : undefined;
    this.motion.dismiss(this.getUIContext(), source, geometry.viewport, geometry.target, this.reduceMotion,
      (): void => { this.pageStack.pop(false); });
  }

  private titleHeight(): number {
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    return this.statusBarHeight + this.getUIContext().px2vp(context.resourceManager.getNumber($r('app.float.chat_video_title_height').id));
  }

  @Builder
  private VideoTitle(): void {
    Row({ space: 8 }) {
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.chevron_left')).fontSize($r('sys.float.Title_M'))
          .fontColor([$r('app.color.text_on_brand')])
      }.width($r('app.float.chat_video_back_size')).height($r('app.float.chat_video_back_size'))
        .backgroundColor(Color.Transparent).onClick((): void => this.close())
        .accessibilityText($r('app.string.common_back'))
      Text($r('app.string.chat_video')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Title_M')).fontColor($r('app.color.text_on_brand'))
    }.width('100%').height(this.titleHeight())
      .padding({ top: this.statusBarHeight, left: $r('app.float.chat_video_title_inset'), right: $r('app.float.chat_video_title_inset') })
      .backgroundColor(Color.Black)
  }

  build(): void {
    NavDestination() {
      MediaViewerMotion({ motion: this.motion, surfaceId: this.motionSurfaceId,
        presentation: this.motion.presentation,
        targetId: this.motionSurfaceId + '-frame', contentReady: this.media !== undefined && this.initialVideoReady,
        mediaWidth: this.media?.width ?? 0, mediaHeight: this.media?.height ?? 0 }) {
      Column() {
        this.VideoTitle()
        Stack() {
          if (this.media !== undefined) {
            SurfaceVideoPlayer({ media: this.media, manualStart: true, playbackEnabled: this.visible,
              onViewerSurfaceReady: (): void => { if (!this.closing) { this.initialVideoReady = true; } },
              retainViewerPlayback: this.motion.enabled() && !this.motion.interactive,
              transitionSourceId: this.motionSurfaceId + '-frame',
              naturalVideoSize: true, fillVideoViewport: true, containVideo: true, videoViewportHeight: this.viewportHeight,
              adaptiveShortVideo: true, forceUnmuted: true, allowPip: false })
          }
        }.width('100%').layoutWeight(1).backgroundColor(Color.Black)
          .onAreaChange((_previous: Area, area: Area): void => {
            const height: number = Number(area.height);
            if (height > 0 && Math.abs(height - this.viewportHeight) > 0.5) { this.viewportHeight = height; }
          })
      }.width('100%').height('100%').padding({ bottom: this.navigationIndicatorHeight }).backgroundColor(Color.Black)
      }
    }
    .mode(NavDestinationMode.DIALOG)
    .systemTransition(pageSystemTransition(this.pageTransitionMode, this.motion.enabled() ? NavigationSystemTransitionType.NONE : NavigationSystemTransitionType.DEFAULT))
    .hideTitleBar(true).hideBackButton(true)
    .onReady((context: NavDestinationContext): void => {
      const param: ChatVideoViewerRouteParam = context.pathInfo.param as ChatVideoViewerRouteParam;
      if (param !== undefined && param !== null) {
        this.motion.prepare(param.source);
        this.initialVideoReady = param.source === undefined;
        this.media = param.media; this.screenBlocked = param.screenBlocked === true;
      }
    })
    .onShown((): void => {
      this.visible = true;
      if (this.screenBlocked) { setChatWindowPrivacy(this.getUIContext().getHostContext() as common.UIAbilityContext, true); }
    })
    .onWillHide((): void => {
      this.visible = false;
      if (this.screenBlocked) { setChatWindowPrivacy(this.getUIContext().getHostContext() as common.UIAbilityContext, false); }
    })
    .onBackPressed((): boolean => { this.close(); return true; })
    .backgroundColor(Color.Transparent)
  }
}
