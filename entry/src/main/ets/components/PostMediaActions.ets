import { InputModalScope } from '../utils/InputModalScope';
import { contextInputMouse } from '../utils/InputSupport';
import { menuActionVisible } from '../models/MenuActionCatalog';
import { STORAGE_KEY_HIDDEN_MENU_ACTIONS } from '../services/MenuSettingsStore';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { fileUri } from '@kit.CoreFileKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { systemShare } from '@kit.ShareKit';
import promptAction from '@ohos.promptAction';
import type { MediaAttachment, Tweet } from '../models/Tweet';
import type { ReplyComposerRouteParam } from './ReplyComposer';
import { imageUrlForQuality, IMAGE_QUALITY_ORIGINAL } from '../services/MediaSettingsStore';
import { MEDIA_DOWNLOAD_CANCELED, MEDIA_DOWNLOAD_SUCCESS, mediaDownloadService } from '../services/MediaDownloadService';
import { chooseVideoDownloadUrl } from '../services/VideoDownloadChoice';
import { OfflineVideoSaveStatus, offlineVideoStore } from '../services/OfflineVideoStore';
import { proxyDownloadService } from '../services/ProxyDownloadService';
import { proxyImageResolver } from '../services/ProxyImageResolver';
import { backgroundImageStore } from '../services/BackgroundImageStore';
import { chatPageMaterial } from '../utils/ChatMaterial';
import { SystemMaterialUtil } from '../utils/SystemMaterial';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';
import { materialModifier } from '../utils/SystemMaterial';
import { postShareUrl } from '../utils/SharePost';

@Builder
function EmptyMediaActionContent(_onLongPress: () => void): void { Column() {} }

// Keep the same native preview/focus lifecycle as ChatMessageActions. Downloads,
// clipboard and navigation start only after the context menu releases focus.
@Component
export struct PostMediaActions {
  private inputModalScope: InputModalScope = new InputModalScope();

  aboutToDisappear(): void { this.inputModalScope.setActive(false); }
  @StorageProp(STORAGE_KEY_HIDDEN_MENU_ACTIONS) private hiddenMenuActions: string = '';
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Prop media: MediaAttachment;
  @Prop tweet: Tweet | null = null;
  @BuilderParam content: (onLongPress: () => void) => void = EmptyMediaActionContent;
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp('harmonyx.accent_color') private accentColor: string = '#007DFF';
  @State private menuShown: boolean = false;
  private busy: boolean = false;
  private afterDismiss: (() => void) | null = null;
  private requestActions: () => void = (): void => {
    const ids: string[] = this.media.type === 'photo' ?
      ['photo.publish', 'photo.copy', 'photo.save', 'photo.background', 'photo.share'] :
      ['video.publish', 'video.copy_link', 'video.save', 'video.offline'];
    if (!this.busy && ids.some((id: string): boolean => this.menuVisible(id))) { this.menuShown = true; }
  };

  private text(resource: Resource): string {
    return (this.getUIContext().getHostContext() as common.UIAbilityContext).resourceManager.getStringSync(resource);
  }

  private menuVisible(id: string): boolean {
    return menuActionVisible(this.hiddenMenuActions, id);
  }

  private sourceUrl(): string {
    const source: string = this.media.mediaUrl.length > 0 ? this.media.mediaUrl : this.media.previewUrl;
    return this.media.type === 'photo' ? imageUrlForQuality(source, IMAGE_QUALITY_ORIGINAL) : source;
  }

  private dismissThen(action: () => void): void {
    this.afterDismiss = action;
    this.menuShown = false;
  }

  private onMenuDismissed(): void {
    this.menuShown = false;
    const action: (() => void) | null = this.afterDismiss;
    this.afterDismiss = null;
    if (action !== null) { action(); }
  }

  private save(): void {
    if (this.busy) { return; }
    this.busy = true;
    this.saveSelected().catch((): void => {
      promptAction.showToast({ message: this.text($r('app.string.media_download_failed')) });
    }).finally((): void => { this.busy = false; });
  }

  private async saveSelected(): Promise<void> {
    const isVideo: boolean = this.media.type === 'video';
    const url: string = isVideo ? await chooseVideoDownloadUrl(this.getUIContext(), this.media) : this.sourceUrl();
    if (url.length === 0) { return; }
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    if (!isVideo) { promptAction.showToast({ message: this.text($r('app.string.media_download_started')) }); }
    await new Promise<void>((resolve: () => void): void => {
      mediaDownloadService.download(context, url, this.media.id, isVideo, (result: number): void => {
        if (isVideo && result === MEDIA_DOWNLOAD_SUCCESS) { resolve(); return; }
        const message: Resource = result === MEDIA_DOWNLOAD_SUCCESS ?
          (isVideo ? $r('app.string.media_video_saved') : $r('app.string.media_image_saved')) :
          result === MEDIA_DOWNLOAD_CANCELED ? $r('app.string.media_download_canceled') : $r('app.string.media_download_failed');
        promptAction.showToast({ message: this.text(message), duration: 2200 });
        resolve();
      });
    });
  }

  private async copyPhoto(): Promise<void> {
    if (this.busy) { return; }
    this.busy = true;
    let pixels: image.PixelMap | null = null;
    try {
      pixels = await proxyImageResolver.loadForViewer(this.sourceUrl(), true);
      if (pixels === null) { throw new Error('Image unavailable'); }
      await pasteboard.getSystemPasteboard().setData(pasteboard.createData(pasteboard.MIMETYPE_PIXELMAP, pixels));
      promptAction.showToast({ message: this.text($r('app.string.photo_copied')) });
    } catch (error) {
      promptAction.showToast({ message: this.text($r('app.string.photo_copy_failed')) });
    } finally {
      if (pixels !== null) { proxyImageResolver.release(pixels); }
      this.busy = false;
    }
  }

  private async saveBackground(): Promise<void> {
    if (this.busy) { return; }
    this.busy = true;
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    promptAction.showToast({ message: this.text($r('app.string.chat_background_saving_photo')) });
    try {
      await backgroundImageStore.savePhoto(context, this.sourceUrl());
      promptAction.showToast({ message: this.text($r('app.string.chat_background_saved_photo')), duration: 2600 });
    } catch (error) {
      promptAction.showToast({ message: this.text($r('app.string.chat_background_save_photo_failed')), duration: 2200 });
    } finally { this.busy = false; }
  }

  private async localPhoto(): Promise<string> {
    const url: string = this.sourceUrl();
    if (url.startsWith('file://')) { return url; }
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const lower: string = url.toLowerCase();
    const extension: string = lower.indexOf('format=png') >= 0 || lower.endsWith('.png') ? 'png' :
      lower.indexOf('format=webp') >= 0 || lower.endsWith('.webp') ? 'webp' : 'jpg';
    const path: string = context.cacheDir + '/post-photo-' + Date.now().toString() + '.' + extension;
    return await proxyDownloadService.downloadWithRetry(url, path, 2) ? fileUri.getUriFromPath(path) : '';
  }

  private async publishPhoto(): Promise<void> {
    if (this.busy) { return; }
    this.busy = true;
    try {
      const uri: string = await this.localPhoto();
      if (uri.length === 0) { throw new Error('Image unavailable'); }
      const param: ReplyComposerRouteParam = {
        replyToId: '', replyToUser: '', avatarUrl: '', avatarName: '', avatarColor: this.accentColor,
        initialText: '', imageUri: uri, gifUri: '', communityId: '', communityName: '', parentTweet: null
      };
      ResponsiveLayout.openContentDestination();
      this.pageStack.pushPath({ name: 'ReplyComposer', param: param });
    } catch (error) {
      promptAction.showToast({ message: this.text($r('app.string.media_download_failed')) });
    } finally { this.busy = false; }
  }

  private targetTweet(): Tweet {
    if (this.tweet !== null) {
      return this.tweet;
    }
    return {
      id: this.media.id,
      author: {
        id: '',
        name: 'X',
        username: '',
        avatarColor: this.accentColor,
        verified: false
      },
      text: '',
      createdAt: '',
      metrics: { replyCount: 0, repostCount: 0, likeCount: 0, viewCount: 0 },
      liked: false,
      reposted: false,
      attachments: [this.media]
    };
  }

  private async localVideo(): Promise<string> {
    const url: string = await chooseVideoDownloadUrl(this.getUIContext(), this.media);
    if (url.length === 0 || url.startsWith('file://')) {
      return url;
    }
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const path: string = context.cacheDir + '/post-video-publish-' + Date.now().toString() + '.mp4';
    return await proxyDownloadService.downloadWithRetry(url, path, 1) ? fileUri.getUriFromPath(path) : '';
  }

  private async publishVideo(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    try {
      const uri: string = await this.localVideo();
      if (uri.length === 0) {
        throw new Error('Video unavailable');
      }
      const param: ReplyComposerRouteParam = {
        replyToId: '',
        replyToUser: '',
        avatarUrl: '',
        avatarName: '',
        avatarColor: this.accentColor,
        initialText: '',
        imageUri: '',
        gifUri: '',
        videoUri: uri,
        communityId: '',
        communityName: '',
        parentTweet: null
      };
      ResponsiveLayout.openContentDestination();
      this.pageStack.pushPath({ name: 'ReplyComposer', param: param });
    } catch (error) {
      promptAction.showToast({ message: this.text($r('app.string.media_download_failed')) });
    } finally {
      this.busy = false;
    }
  }

  private async copyVideoLink(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    try {
      const link: string = this.tweet !== null ? postShareUrl(this.tweet) : this.sourceUrl();
      if (link.length === 0) {
        throw new Error('Video link unavailable');
      }
      await pasteboard.getSystemPasteboard().setData(
        pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, link));
      promptAction.showToast({ message: this.text($r('app.string.post_video_link_copied')) });
    } catch (error) {
      promptAction.showToast({ message: this.text($r('app.string.post_video_link_copy_failed')) });
    } finally {
      this.busy = false;
    }
  }

  private async addOffline(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    try {
      const url: string = await chooseVideoDownloadUrl(this.getUIContext(), this.media);
      if (url.length === 0) {
        return;
      }
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const status: OfflineVideoSaveStatus = await offlineVideoStore.save(
        context, this.targetTweet(), this.media, url);
      if (status === OfflineVideoSaveStatus.SAVED) {
        promptAction.showToast({ message: this.text($r('app.string.offline_videos_added')) });
      } else if (status === OfflineVideoSaveStatus.ALREADY_SAVED) {
        promptAction.showToast({ message: this.text($r('app.string.offline_videos_already')) });
      } else if (status === OfflineVideoSaveStatus.CANCELED) {
        promptAction.showToast({ message: this.text($r('app.string.media_download_canceled')) });
      } else {
        promptAction.showToast({ message: this.text($r('app.string.media_download_failed')) });
      }
    } catch (error) {
      promptAction.showToast({ message: this.text($r('app.string.media_download_failed')) });
    } finally {
      this.busy = false;
    }
  }

  private async share(): Promise<void> {
    if (this.busy) { return; }
    this.busy = true;
    try {
      const photo: boolean = this.media.type === 'photo';
      const uri: string = photo ? await this.localPhoto() : this.sourceUrl();
      if (uri.length === 0) { throw new Error('Media unavailable'); }
      const data: systemShare.SharedData = new systemShare.SharedData({
        utd: photo ? utd.UniformDataType.IMAGE : utd.UniformDataType.HYPERLINK,
        uri: uri, title: this.text(photo ? $r('app.string.post_photo_share') : $r('app.string.action_share'))
      });
      const controller: systemShare.ShareController = new systemShare.ShareController(data);
      await controller.show(this.getUIContext().getHostContext() as common.UIAbilityContext, {
        selectionMode: systemShare.SelectionMode.SINGLE, previewMode: systemShare.SharePreviewMode.DEFAULT
      });
    } catch (error) {
      promptAction.showToast({ message: this.text($r('app.string.post_media_share_failed')) });
    } finally { this.busy = false; }
  }

  private async feedXiaoyi(): Promise<void> {
    if (this.busy) { return; }
    this.busy = true;
    try {
      const uri: string = await this.localPhoto();
      if (uri.length === 0) { throw new Error('Image unavailable'); }
      // Share Kit grants the receiving app access to the downloaded image.
      // Xiaoyi's registered image receiver is selected in the system panel;
      // do not depend on private assistant launch parameters or permissions.
      const data: systemShare.SharedData = new systemShare.SharedData({
        utd: utd.UniformDataType.IMAGE, uri: uri, thumbnailUri: uri,
        title: this.text($r('app.string.post_photo_feed_xiaoyi'))
      });
      const controller: systemShare.ShareController = new systemShare.ShareController(data);
      await controller.show(this.getUIContext().getHostContext() as common.UIAbilityContext, {
        selectionMode: systemShare.SelectionMode.SINGLE, previewMode: systemShare.SharePreviewMode.DETAIL,
        excludedAbilities: [systemShare.ShareAbilityType.PRINT, systemShare.ShareAbilityType.COPY_TO_PASTEBOARD,
          systemShare.ShareAbilityType.SAVE_AS_FILE, systemShare.ShareAbilityType.SAVE_TO_MEDIA_ASSET,
          systemShare.ShareAbilityType.SAVE_TO_SUPERHUB]
      });
      promptAction.showToast({ message: this.text($r('app.string.post_photo_feed_xiaoyi_choose')) });
    } catch (error) {
      promptAction.showToast({ message: this.text($r('app.string.post_photo_feed_xiaoyi_failed')) });
    } finally { this.busy = false; }
  }

  @Builder
  private ActionRow(label: Resource, icon: Resource, action: () => void): void {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 16 }) {
        SymbolGlyph(icon).fontSize(22).fontColor([$r('app.color.text_secondary')])
        Text(label).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_primary')).layoutWeight(1)
      }.width('100%').height('100%')
    }.width('100%').height(52).padding({ left: 16, right: 16 }).borderRadius(0)
      .backgroundColor(Color.Transparent).accessibilityText(label)
      .onClick((): void => this.dismissThen(action))
  }

  @Builder
  private Actions(): void {
    Column() {
      if (this.media.type === 'photo') {
        if (this.menuVisible('photo.publish')) {
          this.ActionRow($r('app.string.post_photo_publish'), $r('sys.symbol.square_and_pencil'), (): void => { void this.publishPhoto(); })
        }
        if (this.menuVisible('photo.copy')) {
          this.ActionRow($r('app.string.post_photo_copy'), $r('sys.symbol.plus_square_on_square'), (): void => { void this.copyPhoto(); })
        }
      } else {
        if (this.menuVisible('video.publish')) {
          this.ActionRow($r('app.string.post_video_publish'), $r('sys.symbol.square_and_pencil'),
            (): void => { void this.publishVideo(); })
        }
        if (this.menuVisible('video.copy_link')) {
          this.ActionRow($r('app.string.post_video_copy_link'), $r('sys.symbol.link'),
            (): void => { void this.copyVideoLink(); })
        }
      }
      if (this.menuVisible(this.media.type === 'photo' ? 'photo.save' : 'video.save')) {
        this.ActionRow(this.media.type === 'photo' ? $r('app.string.post_photo_save_original') : $r('app.string.post_video_save'),
          $r('sys.symbol.download'), (): void => this.save())
      }
      if (this.media.type === 'photo') {
        if (this.menuVisible('photo.background')) {
          this.ActionRow($r('app.string.post_photo_save_background'), $r('sys.symbol.picture'), (): void => { void this.saveBackground(); })
        }
      } else if (this.menuVisible('video.offline')) {
        this.ActionRow($r('app.string.video_feed_add_offline'), $r('sys.symbol.plus'),
          (): void => { void this.addOffline(); })
      }
      if (this.media.type === 'photo' && this.menuVisible('photo.share')) {
        this.ActionRow($r('app.string.action_share'), $r('sys.symbol.share'), (): void => { void this.share(); })
      }
    }.width(300).padding({ top: 8, bottom: 8 }).borderRadius(18).clip(true)
      .backgroundColor(SystemMaterialUtil.isApi26OrAbove() ? Color.Transparent : $r('app.color.bg_field'))
      .attributeModifier(materialModifier(chatPageMaterial()))
  }

  build(): void {
    Column() { this.content(this.requestActions); }
      .width('100%')
      .onMouse((event: MouseEvent): void => contextInputMouse(event, (): void => this.requestActions()))
      .bindContextMenu(this.menuShown, this.Actions(), {
        preview: this.media.type === 'photo' ? MenuPreviewMode.IMAGE : MenuPreviewMode.NONE,
        previewBorderRadius: 14,
        previewAnimationOptions: { scale: [0.98, 1.035] }, borderRadius: 18,
        backgroundColor: Color.Transparent, backgroundBlurStyle: BlurStyle.COMPONENT_THICK,
        mask: { color: $r('app.color.chat_message_menu_mask'), backgroundBlurStyle: BlurStyle.BACKGROUND_THIN },
        modalMode: ModalMode.TARGET_WINDOW, hapticFeedbackMode: HapticFeedbackMode.AUTO,
        onAppear: (): void => { this.inputModalScope.setActive(true); },
        onDisappear: (): void => { this.inputModalScope.setActive(false); this.onMenuDismissed(); }
      })
  }
}
