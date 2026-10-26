import { common } from '@kit.AbilityKit';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { downloadManager } from '../services/DownloadManager';
import { VIDEO_DOWNLOAD_NOTICE_KEY, VideoDownloadNoticeState } from '../services/VideoDownloadNoticeStore';
import { motionDuration } from '../utils/AppMotion';
import { hapticTick } from '../utils/Haptics';
import { MaterialButton } from './MaterialButton';
import { NEW_POSTS_PILL_MAX_WIDTH } from './NewPostsPill';

@Component
export struct VideoDownloadNotice {
  @Prop rowOffset: number = 0;
  @Prop availableWidth: number = 390;
  @StorageProp(VIDEO_DOWNLOAD_NOTICE_KEY) private notice: VideoDownloadNoticeState = new VideoDownloadNoticeState();
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp('harmonyx.accent_color') private accentColor: string = '#007DFF';
  @StorageProp('reduceMotionEnabled') private reduceMotion: boolean = false;

  private label(): Resource {
    if (this.notice.phase === 'completed') { return $r('app.string.video_download_notice_completed'); }
    if (this.notice.phase === 'saving') { return $r('app.string.video_download_notice_saving'); }
    return $r('app.string.video_download_notice_downloading');
  }

  private percent(): number {
    return this.notice.totalBytes > 0 ?
      Math.max(0, Math.min(100, this.notice.receivedBytes * 100 / this.notice.totalBytes)) : 0;
  }

  private canCancel(): boolean {
    return this.notice.phase === 'downloading' || this.notice.phase === 'queued';
  }

  build(): void {
    Column() {
      if (this.notice.phase !== 'hidden') {
        Stack() {
          // Exactly the same material carrier, level, tint and shadow as NewPostsPill.
          MaterialButton({ buttonWidth: '100%', buttonHeight: $r('app.float.video_download_notice_height'),
            buttonRadius: $r('app.float.video_download_notice_radius'), surfaceColor: this.accentColor,
            materialLevel: 2, applyShadow: true, lightColor: this.accentColor,
            buttonPressFeedback: false, enableHdrHighlight: false })
            .hitTestBehavior(HitTestMode.None).focusable(false).accessibilityLevel('no')
          Row({ space: 6 }) {
            if (this.notice.phase === 'completed') {
              SymbolGlyph($r('sys.symbol.checkmark_circle'))
                .fontSize($r('app.float.video_download_notice_icon_size'))
                .fontColor([$r('app.color.text_on_accent')]).accessibilityLevel('no')
            } else {
              Progress({ value: this.percent(), total: 100, type: ProgressType.Ring })
                .width($r('app.float.video_download_notice_icon_size'))
                .height($r('app.float.video_download_notice_icon_size'))
                .color($r('app.color.text_on_accent'))
                .backgroundColor($r('app.color.video_download_notice_track'))
                .style({ strokeWidth: 2.5, enableSmoothEffect: !this.reduceMotion,
                  status: this.notice.totalBytes > 0 && this.notice.phase !== 'saving' ?
                    ProgressStatus.PROGRESSING : ProgressStatus.LOADING })
                .accessibilityText(this.notice.totalBytes > 0 ? Math.floor(this.percent()).toString() + '%' : '')
            }
            Text(this.label()).fontFamily(this.appFontFamily)
              .fontSize($r('app.float.video_download_notice_font_size')).fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_on_accent')).maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
            if (this.canCancel()) {
              Button($r('app.string.compose_cancel'), { type: ButtonType.Capsule })
                .id('video-download-notice-cancel').height($r('app.float.video_download_notice_height'))
                .padding({ left: 4, right: 4 }).fontFamily(this.appFontFamily)
                .fontSize($r('app.float.video_download_notice_font_size'))
                .fontColor($r('app.color.text_on_accent'))
                .backgroundColor(Color.Transparent)
                .onClick((): void => {
                  hapticTick();
                  downloadManager.cancelVideoDownload(this.notice.taskId,
                    this.getUIContext().getHostContext() as common.UIAbilityContext);
                })
            }
          }.width('100%').height($r('app.float.video_download_notice_height'))
            .padding({ left: 8, right: this.canCancel() ? 4 : 8 })
        }
        .id('video-download-notice')
        .width(Math.max(0, Math.min(NEW_POSTS_PILL_MAX_WIDTH, (this.availableWidth > 0 ? this.availableWidth : 390) - 32)))
        .height($r('app.float.video_download_notice_height'))
        .transition(TransitionEffect.OPACITY.animation({ duration: motionDuration(180), curve: Curve.EaseOut }))
      }
    }
    .translate({ y: this.rowOffset })
    .animation({ duration: motionDuration(240), curve: Curve.EaseInOut })
    .width('100%').height($r('app.float.video_download_notice_height')).hitTestBehavior(HitTestMode.Transparent)
  }
}
