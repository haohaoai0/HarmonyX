import { DEFAULT_COMPONENT_HDR_ENABLED, DEFAULT_COMPONENT_HDR_RATIO, STORAGE_KEY_COMPONENT_HDR_ENABLED,
  STORAGE_KEY_COMPONENT_HDR_RATIO } from '../services/ComponentHdrSettingsStore';
import { ComponentHdrHighlight } from '../utils/ComponentHdrHighlight';
import { STORAGE_KEY_PAGE_TRANSITION_MODE, DEFAULT_PAGE_TRANSITION_MODE } from '../services/PageTransitionSettingsStore';
import { pageSystemTransition, PageTransitionMotion } from '../utils/PageTransition';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { userAvatarRadius, verificationBadgeColor } from '../utils/UserIdentity';
// Reusable reply capsule and its full-screen editor destination.  Keeping both
// builders here makes the compact entry point reusable by every detail page.
import common from '@ohos.app.ability.common';
import promptAction from '@ohos.promptAction';
import hilog from '@ohos.hilog';
import { Want } from '@kit.AbilityKit';
import { camera, cameraPicker } from '@kit.CameraKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { fileIo, fileUri, picker } from '@kit.CoreFileKit';
import { inputMethod } from '@kit.IMEKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import {
  CollaborationDeviceFilterType,
  CollaborationServiceFilter,
  CollaborationServiceStateDialog,
  createCollaborationServiceMenuItems
} from '@kit.ServiceCollaborationKit';
import { KeyboardAvoidMode, LengthMetrics, uiMaterial, window } from '@kit.ArkUI';
import {
  DividerShowType,
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  ScrollEffectType
} from '@kit.UIDesignKit';
import { XApiClient } from '../services/XApiClient';
import { authStore } from '../services/AuthStore';
import { XPrivateClient, XPrivateResult, xPrivateClient } from '../services/XPrivateClient';
import { XPostFeedback } from '../services/XPostFeedback';
import { XUserParser } from '../services/XUserParser';
import { ComposerDraft, composerDraftStore } from '../services/ComposerDraftStore';
import { ComposerOptions } from '../models/ComposerOptions';
import { ComposerTools } from './ComposerTools';
import { ComposerPollEditor } from './ComposerPollEditor';
import { chatEmojiStore } from '../services/ChatEmojiStore';
import { ExternalSharePayload, ExternalShareFile } from '../services/ExternalShareStore';
import { accountStore } from '../services/AccountStore';
import { continuationStore } from '../services/ContinuationState';
import { XBookmarkParser } from '../services/XBookmarkParser';
import { buildXPostIntentUrl } from '../services/XComposeIntent';
import { gifSearchSelectionStore } from '../services/GifSearchSelectionStore';
import { ServerDraftTweet } from '../models/Bookmark';
import type { Tweet, UserProfile } from '../models/Tweet';
import { TweetCard } from './TweetCard';
import { DesktopLayout } from '../utils/DesktopLayout';
import { STORAGE_KEY_DESKTOP_LAYOUT } from '../services/LayoutSettingsStore';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';
import { destinationTitleBarStyle } from '../utils/DestinationTitleBar';
import { SystemMaterialUtil } from '../utils/SystemMaterial';
import { pageSurfaceColor } from '../utils/ThemeColors';
import type { ImageEditResult, ImageEditRouteParam } from '../pages/ImageEdit';
import type { PhotoViewerRouteParam } from '../pages/PhotoViewer';
import {
  DEFAULT_TITLE_BAR_GLASS_MATERIAL_LEVEL,
  STORAGE_KEY_TITLE_BAR_GLASS_MATERIAL_LEVEL,
  TITLE_BAR_STYLE_BLUR,
  DEFAULT_REPLY_CAPSULE_MATERIAL_LEVEL,
  STORAGE_KEY_REPLY_CAPSULE_MATERIAL_LEVEL,
  DEFAULT_REPLY_CAPSULE_BUTTON_MATERIAL_ENABLED,
  STORAGE_KEY_REPLY_CAPSULE_BUTTON_MATERIAL_ENABLED
} from '../services/AppearanceStore';

const STANDARD_POST_CHARACTERS: number = 280;
const MAX_POST_CHARACTERS: number = 4000;
const COMPOSER_EDITOR_MIN_SCROLL_HEIGHT: number = 360;
const COMPOSER_TEXT_AREA_HEIGHT: number = 240;
const COMPOSER_HEADER_HEIGHT: number = 64;
const COMPOSER_PICKER_BAR_HEIGHT: number = 64;
const COMPOSER_MAX_MEDIA_ITEMS: number = 4;
const COMPOSER_MEDIA_GRID_GAP: number = 8;
const DOMAIN = 0xFF00;
const TAG = 'HarmonyX-Composer';
const PRIVATE_PUBLISH_OK: number = 1;
const PRIVATE_PUBLISH_FALLBACK: number = 0;
const PRIVATE_PUBLISH_ERROR: number = -1;

export interface ReplyComposerContext {
  replyToId: string;
  replyToUser: string;
  avatarUrl: string;
  avatarName: string;
  avatarColor: string;
  verifiedType?: string;
  avatarShape?: string;
  accentColor: string;
}

export interface ReplyComposerRouteParam {
  replyToId: string;
  replyToUser: string;
  avatarUrl: string;
  avatarName: string;
  avatarColor: string;
  verifiedType?: string;
  avatarShape?: string;
  initialText: string;
  imageUri: string;
  gifUri: string;
  communityId: string;
  communityName: string;
  parentTweet: Tweet | null;
  sharedPayload?: ExternalSharePayload;
}

interface ComposerMediaItem {
  uri: string;
  isGif: boolean;
}

@Builder
export function ReplyComposerCapsuleBuilder(
  context: ReplyComposerContext,
  onExpand: (text: string, imageUri: string, gifUri: string) => void,
  onSend: (text: string) => Promise<boolean>,
  onExpandedChange: (expanded: boolean) => void,
  dismissRequest: number
): void {
  if (deviceInfo.apiAvailable('26.0.0')) {
    ReplyComposerCapsuleContent(context, onExpand, onSend, onExpandedChange, dismissRequest, true);
  } else {
    ReplyComposerCapsuleContent(context, onExpand, onSend, onExpandedChange, dismissRequest, false);
  }
}

@Builder
function ReplyComposerCapsuleContent(
  context: ReplyComposerContext,
  onExpand: (text: string, imageUri: string, gifUri: string) => void,
  onSend: (text: string) => Promise<boolean>,
  onExpandedChange: (expanded: boolean) => void,
  dismissRequest: number,
  materialEnabled: boolean
): void {
  ReplyComposerCapsule({
    context: context,
    accentColor: context.accentColor,
    materialEnabled: materialEnabled,
    onExpand: onExpand,
    onSend: onSend,
    onExpandedChange: onExpandedChange,
    dismissRequest: dismissRequest
  });
}

@Builder
export function ReplyComposerBuilder(): void {
  ReplyComposerPage();
}

@Component
export struct ReplyComposerCapsule {
  @StorageProp('harmonyx.compact_window') private compactWindow: boolean = false;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Consume('pageStack') private pageStack: NavPathStack;
  @Prop context: ReplyComposerContext;
  @Prop accentColor: string = '#007DFF';
  @Prop materialEnabled: boolean = false;
  onExpand: (text: string, imageUri: string, gifUri: string) => void = () => {
  };
  onSend: (text: string) => Promise<boolean> = async (_text: string): Promise<boolean> => false;
  onExpandedChange: (expanded: boolean) => void = (_expanded: boolean): void => {
  };
  @Prop @Watch('onDismissRequestChanged')
  private dismissRequest: number = 0;
  @State private draft: string = '';
  @State private imageUri: string = '';
  @State private gifUri: string = '';
  @State private resolvedAvatarUrl: string = '';
  @State private resolvedAvatarName: string = '';
  @State private resolvedVerifiedType: string = '';
  @State private resolvedAvatarShape: string = '';
  @State private expanded: boolean = false;
  @State private sending: boolean = false;
  @StorageLink(STORAGE_KEY_TITLE_BAR_GLASS_MATERIAL_LEVEL)
  private titleBarGlassMaterialLevel: number = DEFAULT_TITLE_BAR_GLASS_MATERIAL_LEVEL;
  @StorageLink(STORAGE_KEY_REPLY_CAPSULE_MATERIAL_LEVEL)
  private replyCapsuleMaterialLevel: number = DEFAULT_REPLY_CAPSULE_MATERIAL_LEVEL;
  @StorageProp(STORAGE_KEY_REPLY_CAPSULE_BUTTON_MATERIAL_ENABLED)
  private replyCapsuleButtonMaterialEnabled: boolean = DEFAULT_REPLY_CAPSULE_BUTTON_MATERIAL_ENABLED;
  private api: XApiClient = new XApiClient();
  private inputController: TextAreaController = new TextAreaController();
  private capsuleMounted: boolean = false;
  private focusRecoveryScheduled: boolean = false;
  private keyboardHeightChangeListener: (height: number) => void = (height: number): void => {
    if (this.capsuleMounted) {
      this.setExpanded(height > 0);
    }
  };

  private onDismissRequestChanged(): void {
    this.setExpanded(false);
  }

  private setExpanded(expanded: boolean): void {
    if (this.expanded === expanded) {
      return;
    }
    this.getUIContext().animateTo({ duration: 280, curve: Curve.EaseOut }, (): void => {
      this.expanded = expanded;
      this.onExpandedChange(expanded);
    });
  }

  aboutToAppear(): void {
    this.capsuleMounted = true;
    this.resolvedAvatarUrl = this.context.avatarUrl;
    this.resolvedAvatarName = this.context.avatarName;
    this.resolvedVerifiedType = this.context.verifiedType ?? ''; this.resolvedAvatarShape = this.context.avatarShape ?? '';
    this.loadCurrentUserAvatar();
    const hostContext: common.Context | undefined = this.getUIContext().getHostContext();
    if (hostContext !== undefined) {
      window.getLastWindow(hostContext).then((currentWindow): void => {
        if (this.capsuleMounted) {
          currentWindow.on('keyboardHeightChange', this.keyboardHeightChangeListener);
          const keyboardVisible: boolean =
            currentWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_KEYBOARD).bottomRect.height > 0;
          if (this.expanded === keyboardVisible) {
            this.onExpandedChange(keyboardVisible);
          } else {
            this.setExpanded(keyboardVisible);
          }
        } else {
          currentWindow.off('keyboardHeightChange', this.keyboardHeightChangeListener);
        }
      }).catch((): void => {
      });
    }
  }

  aboutToDisappear(): void {
    this.capsuleMounted = false;
    this.onExpandedChange(false);
    const hostContext: common.Context | undefined = this.getUIContext().getHostContext();
    if (hostContext !== undefined) {
      window.getLastWindow(hostContext).then((currentWindow): void => {
        currentWindow.off('keyboardHeightChange', this.keyboardHeightChangeListener);
      }).catch((): void => {
      });
    }
  }

  private async loadCurrentUserAvatar(): Promise<void> {
    const abilityContext: common.UIAbilityContext =
      this.getUIContext().getHostContext() as common.UIAbilityContext;
    await authStore.load(abilityContext);
    const profile: UserProfile | null = await this.resolveViewer(abilityContext);
    if (profile === null) {
      return;
    }
    if (profile.avatarUrl !== undefined && profile.avatarUrl.length > 0) {
      this.resolvedAvatarUrl = profile.avatarUrl;
      this.resolvedVerifiedType = profile.verifiedType ?? ''; this.resolvedAvatarShape = profile.avatarShape ?? '';
    }
    if (profile.name.length > 0) {
      this.resolvedAvatarName = profile.name;
    }
  }

  // Cookie-only X sessions do not have an OAuth profile token. Resolve that
  // viewer first so the capsule can still load the signed-in user's avatar.
  private async resolveViewer(context: common.UIAbilityContext): Promise<UserProfile | null> {
    xPrivateClient.load(context);
    if (xPrivateClient.isSignedIn()) {
      const viewerId: string = xPrivateClient.viewerId();
      if (viewerId.length > 0) {
        const result: XPrivateResult = await xPrivateClient.userByRestId(viewerId);
        const profile: UserProfile | null = result.ok ? XUserParser.parse(result.body) : null;
        if (profile !== null) {
          return profile;
        }
      }
    }
    if (!authStore.isSignedIn()) {
      return null;
    }
    this.api.setToken(authStore.getToken());
    this.api.setUser(authStore.getUserId());
    return await this.api.profile();
  }

  private async selectImage(): Promise<void> {
    try {
      const options: photoAccessHelper.PhotoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1;
      const photoPicker: photoAccessHelper.PhotoViewPicker = new photoAccessHelper.PhotoViewPicker();
      const result: photoAccessHelper.PhotoSelectResult = await photoPicker.select(options);
      if (result.photoUris.length > 0) {
        const selectedUri: string = result.photoUris[0];
        this.imageUri = selectedUri;
        this.setExpanded(true);
        this.recoverInputFocus();
      }
    } catch (error) {
    }
  }

  private async selectGif(): Promise<void> {
    try {
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const options: picker.DocumentSelectOptions = new picker.DocumentSelectOptions();
      options.fileSuffixFilters = ['gif'];
      options.maxSelectNumber = 1;
      const gifPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(context);
      const result: Array<string> = await gifPicker.select(options);
      if (result.length > 0) {
        const selectedUri: string = result[0];
        this.gifUri = selectedUri;
        this.onExpand(this.draft, this.imageUri, selectedUri);
      }
    } catch (error) {
    }
  }

  @Builder
  private Avatar(): void {
    if (this.resolvedAvatarUrl.length > 0) {
      Image(this.resolvedAvatarUrl)
        .width(40)
        .height(40)
        .objectFit(ImageFit.Cover)
        .borderRadius(userAvatarRadius(40, 20, this.resolvedVerifiedType, this.resolvedAvatarShape))
        .clip(true)
    } else {
      Text(this.resolvedAvatarName.substring(0, 1).toUpperCase()).fontFamily(this.appFontFamily)
        .width(40)
        .height(40)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_on_primary'))
        .backgroundColor(this.context.avatarColor)
        .borderRadius(userAvatarRadius(40, 20, this.resolvedVerifiedType, this.resolvedAvatarShape))
        .textAlign(TextAlign.Center)
    }
  }

  @Builder
  private AvatarButton(): void {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      this.Avatar();
    }
    .width(42)
    .height(42)
    .padding(1)
    .backgroundColor(Color.Transparent)
    .borderRadius(userAvatarRadius(42, 21, this.resolvedVerifiedType, this.resolvedAvatarShape))
    .clip(true)
    .systemMaterial(this.controlMaterial())
  }

  @Builder
  private ToolButton(symbol: Resource, onClick: () => void): void {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph(symbol)
        .fontSize(23)
        .fontColor([$r('sys.color.icon_primary')]);
    }
    .width(42)
    .height(42)
    .backgroundColor(Color.Transparent)
    .borderRadius(21)
    .clip(true)
    .onClick(onClick)
    .systemMaterial(this.controlMaterial())
  }

  private innerMaterialEnabled(): boolean {
    return this.materialEnabled && this.replyCapsuleButtonMaterialEnabled && deviceInfo.apiAvailable('26.0.0');
  }

  private controlMaterial(): uiMaterial.Material | undefined {
    if (!deviceInfo.apiAvailable('26.0.0')) {
      return undefined;
    }
    if (!this.innerMaterialEnabled()) {
      return uiMaterial.Material.empty;
    }
    return new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.THIN,
      interactive: true,
      applyShadow: false,
      colorInvert: true,
      lightEffect: { color: this.accentColor }
    });
  }

  private removeImageMaterial(): uiMaterial.Material | undefined {
    if (!deviceInfo.apiAvailable('26.0.0')) {
      return undefined;
    }
    if (!this.innerMaterialEnabled()) {
      return uiMaterial.Material.empty;
    }
    return new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.THIN,
      materialColor: this.removeImageTint(),
      interactive: true,
      applyShadow: false,
      colorInvert: false,
      lightEffect: { color: $r('app.color.danger') }
    });
  }

  private removeImageTint(): string {
    return '#66B4232D';
  }

  private inputMaterial(): uiMaterial.Material | undefined {
    if (!deviceInfo.apiAvailable('26.0.0')) {
      return undefined;
    }
    if (!this.innerMaterialEnabled()) {
      return uiMaterial.Material.empty;
    }
    return new uiMaterial.ImmersiveMaterial({
      style: SystemMaterialUtil.resolveImmersiveStyle(this.titleBarGlassMaterialLevel),
      interactive: true,
      applyShadow: false,
      colorInvert: true,
      lightEffect: { color: this.accentColor }
    });
  }

  private requestKeyboard(): void {
    try {
      inputMethod.getController().showTextInput().catch((): void => {
      });
    } catch (error) {
    }
  }

  private inputFocusId(): string {
    return 'reply-capsule-input-' + this.context.replyToId;
  }

  private recoverInputFocus(): void {
    if (this.focusRecoveryScheduled) {
      return;
    }
    this.focusRecoveryScheduled = true;
    setTimeout((): void => {
      if (this.capsuleMounted && this.expanded) {
        try {
          this.getUIContext().getFocusController().requestFocus(this.inputFocusId());
        } catch (error) {
        }
        this.requestKeyboard();
      }
      this.focusRecoveryScheduled = false;
    }, 80);
  }

  private capsuleMaterial(): uiMaterial.Material | undefined {
    if (!this.materialEnabled || !deviceInfo.apiAvailable('26.0.0')) {
      return undefined;
    }
    return new uiMaterial.ImmersiveMaterial({
      style: SystemMaterialUtil.resolveImmersiveStyle(this.replyCapsuleMaterialLevel),
      interactive: true,
      applyShadow: false,
      colorInvert: true,
      lightEffect: {}
    });
  }

  private replyButtonTint(): string {
    if (this.accentColor.length === 7 && this.accentColor.substring(0, 1) === '#') {
      return '#66' + this.accentColor.substring(1);
    }
    return '#66007DFF';
  }

  private replyButtonMaterial(): uiMaterial.Material | undefined {
    if (!deviceInfo.apiAvailable('26.0.0')) {
      return undefined;
    }
    if (!this.innerMaterialEnabled()) {
      return uiMaterial.Material.empty;
    }
    return new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.THIN,
      materialColor: this.replyButtonTint(),
      interactive: true,
      applyShadow: false,
      colorInvert: false,
      lightEffect: { color: this.accentColor }
    });
  }

  private async sendReply(): Promise<void> {
    const content: string = this.draft.trim();
    if (this.sending) {
      return;
    }
    if (this.imageUri.length > 0 || this.gifUri.length > 0) {
      this.onExpand(this.draft, this.imageUri, this.gifUri);
      return;
    }
    if (content.length === 0) {
      return;
    }
    this.sending = true;
    try {
      const sent: boolean = await this.onSend(content);
      if (sent) {
        this.draft = '';
        this.setExpanded(false);
        this.inputController.stopEditing();
      }
    } catch (error) {
    } finally {
      this.sending = false;
    }
  }

  private openCapsuleImageEditor(): void {
    const sourceUri: string = this.imageUri;
    if (sourceUri.length === 0) {
      return;
    }
    const param: ImageEditRouteParam = { imageUri: sourceUri };
    this.pageStack.pushPath({
      name: 'ImageEdit',
      param: param,
      onPop: (popInfo: PopInfo): void => {
        const result: ImageEditResult = popInfo.result as ImageEditResult;
        if (result !== undefined && result !== null && result.imageUri.length > 0) {
          this.imageUri = result.imageUri;
        }
      }
    });
  }

  private capsuleHeight(): number {
    if (!this.expanded) {
      return 64;
    }
    return this.compactWindow ? this.compactDimension($r('app.float.compact_reply_capsule_height')) :
      (this.imageUri.length > 0 ? 288 : 164);
  }

  private compactDimension(resource: Resource): number {
    return this.getUIContext().px2vp(getContext(this).resourceManager.getNumber(resource.id));
  }

  private capsulePreviewSize(): number {
    return this.compactWindow ? this.compactDimension($r('app.float.compact_reply_preview_size')) :
      (this.expanded ? 136 : 52);
  }

  private capsuleInputRowHeight(): number {
    if (!this.expanded) {
      return 64;
    }
    if (this.compactWindow) { return 48; }
    return this.imageUri.length > 0 ? 64 : 104;
  }

  private capsuleTextAreaHeight(): number {
    if (!this.expanded) {
      return 48;
    }
    return this.compactWindow ? 48 : (this.imageUri.length > 0 ? 56 : 96);
  }

  @Builder
  private CapsuleImagePreview(): void {
    if (this.imageUri.length > 0) {
      Stack({ alignContent: Alignment.TopEnd }) {
        Image(this.imageUri)
          .width(this.capsulePreviewSize())
          .height(this.capsulePreviewSize())
          .objectFit(ImageFit.Cover)
          .borderRadius(12)
          .clip(true)
          .onClick((): void => {
            this.openCapsuleImageEditor();
          });
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(12)
            .fontColor([this.innerMaterialEnabled() ? Color.White : $r('app.color.danger')]);
        }
        .width(28)
        .height(28)
        .padding(0)
        .backgroundColor(Color.Transparent)
        .onClick((): void => {
          this.imageUri = '';
        })
        .systemMaterial(this.removeImageMaterial());
      }
      .width(this.capsulePreviewSize())
      .height(this.capsulePreviewSize());
    }
  }

  @Builder
  private CapsuleSurfaceContent(): void {
    Column({ space: 4 }) {
      if (this.expanded && !this.compactWindow && this.imageUri.length > 0) {
        Row() {
          this.CapsuleImagePreview();
          Blank();
        }
        .width('100%')
        .height(160)
        .padding({ start: LengthMetrics.vp(16), end: LengthMetrics.vp(12),
          top: LengthMetrics.vp(12), bottom: LengthMetrics.vp(12) });
      }
      Row({ space: 6 }) {
        this.AvatarButton();
        if (!this.expanded || this.compactWindow) {
          this.CapsuleImagePreview();
        }
        TextArea({
          placeholder: $r('app.string.post_detail_reply_placeholder'),
          text: this.draft,
          controller: this.inputController
        }).fontFamily(this.appFontFamily)
          .keyboardAppearance(KeyboardAppearance.IMMERSIVE)
          .layoutWeight(1)
          .height(this.capsuleTextAreaHeight())
          .backgroundColor(Color.Transparent)
          .borderRadius(this.expanded && this.imageUri.length > 0 ? 28 : 24)
          .clip(true)
          .fontSize(17)
          .fontColor($r('sys.color.font_primary'))
          .placeholderColor($r('sys.color.font_secondary'))
          .align(this.expanded && this.imageUri.length === 0 ? Alignment.TopStart : Alignment.Center)
          .id(this.inputFocusId())
          .focusable(true)
          .onChange((value: string): void => {
            this.draft = value;
          })
          .onFocus((): void => {
            this.requestKeyboard();
            this.setExpanded(true);
            this.recoverInputFocus();
          })
          .onClick((): void => {
            this.setExpanded(true);
            this.recoverInputFocus();
          })
          .systemMaterial(this.inputMaterial());
        if (this.expanded) {
          this.ToolButton($r('sys.symbol.arrow_up_left_and_arrow_down_right'), (): void => {
            this.onExpand(this.draft, this.imageUri, this.gifUri);
          });
        } else {
          if (this.imageUri.length === 0) {
            this.ToolButton($r('sys.symbol.picture'), (): void => {
              this.selectImage();
            });
          }
          this.ToolButton($r('sys.symbol.gif'), (): void => {
            this.selectGif();
          });
          this.ToolButton($r('sys.symbol.arrow_up_left_and_arrow_down_right'), (): void => {
            this.onExpand(this.draft, this.imageUri, this.gifUri);
          });
        }
      }
      .width('100%')
      .height(this.capsuleInputRowHeight())
      .padding({ start: LengthMetrics.vp(10), end: LengthMetrics.vp(8) })
      if (this.expanded) {
        Row({ space: 6 }) {
          this.ToolButton($r('sys.symbol.picture'), (): void => {
            this.selectImage();
          });
          this.ToolButton($r('sys.symbol.gif'), (): void => {
            this.selectGif();
          });
          Blank();
          Button({ type: ButtonType.Capsule, stateEffect: true }) {
            if (this.sending) {
              LoadingProgress()
                .width(18)
                .height(18)
                .color(this.innerMaterialEnabled() ? $r('sys.color.font_on_primary') : this.accentColor);
            } else {
              Text($r('app.string.action_reply')).fontFamily(this.appFontFamily)
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.innerMaterialEnabled() ? $r('sys.color.font_on_primary') : this.accentColor);
            }
          }
          .height(48)
          .padding({ left: 22, right: 22 })
          .backgroundColor(Color.Transparent)
          .enabled((this.draft.trim().length > 0 || this.imageUri.length > 0 || this.gifUri.length > 0) && !this.sending)
          .onClick((): void => {
            this.sendReply();
          })
          .systemMaterial(this.replyButtonMaterial());
        }
        .width('100%')
        .height(56)
        .padding({ start: LengthMetrics.vp(10), end: LengthMetrics.vp(8), bottom: LengthMetrics.vp(8) });
      }
    }
    .width('100%')
    .height(this.capsuleHeight())
    .backgroundColor(this.materialEnabled ? Color.Transparent : $r('app.color.bg_field'))
    .border({ width: this.materialEnabled ? 0 : 1, color: $r('app.color.divider') })
    .borderRadius(32)
    .clip(true)
    .systemMaterial(this.capsuleMaterial())
  }

  build(): void {
    Navigation() {
      Column()
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.None)
    }
    .title({
      builder: (): void => {
        this.CapsuleSurfaceContent();
      },
      height: this.capsuleHeight()
    }, { barStyle: BarStyle.STACK })
    .titleMode(NavigationTitleMode.Full)
    .mode(NavigationMode.Stack)
    .hideToolBar(true)
    .backgroundColor(Color.Transparent)
    .width('100%')
    .height(this.capsuleHeight())
  }
}

@Component
export struct ReplyComposerPage {
  @StorageProp(STORAGE_KEY_COMPONENT_HDR_ENABLED) private componentHdrEnabled: boolean = DEFAULT_COMPONENT_HDR_ENABLED;
  @StorageProp(STORAGE_KEY_COMPONENT_HDR_RATIO) private componentHdrRatio: number = DEFAULT_COMPONENT_HDR_RATIO;
  @State private pageMotion: PageTransitionMotion = new PageTransitionMotion();
  @StorageProp(STORAGE_KEY_PAGE_TRANSITION_MODE) private pageTransitionMode: string = DEFAULT_PAGE_TRANSITION_MODE;
  @StorageProp('harmonyx.compact_window') private compactWindow: boolean = false;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp(STORAGE_KEY_DESKTOP_LAYOUT) desktopLayoutEnabled: boolean = false;
  @StorageProp('harmonyx.breakpoint') breakpoint: string = 'sm';
  @StorageProp('harmonyx.window_height') desktopWindowHeight: number = 780;
  private desktop(): boolean { return DesktopLayout.active(this.desktopLayoutEnabled, this.breakpoint); }
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp('harmonyx.display_mode') private themeDisplayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private themeDarkSurface: string = '';
  @StorageProp('harmonyx.status_bar_height') statusBarHeight: number =
    AppStorage.get<number>('harmonyx.status_bar_height') ?? 0;
  @StorageProp('harmonyx.navigation_indicator_height') navigationIndicatorHeight: number =
    AppStorage.get<number>('harmonyx.navigation_indicator_height') ?? 0;
  @State private replyToId: string = '';
  @State private replyToUser: string = '';
  @State private parentTweet: Tweet | null = null;
  @State private communityId: string = '';
  @State private communityName: string = '';
  @State private avatarUrl: string = '';
  @State private avatarName: string = '';
  @State private verifiedType: string = '';
  @State private avatarShape: string = '';
  @State private avatarColor: string = '#007DFF';
  @StorageLink('harmonyx.accent_color') accentColor: string = '#007DFF';
  @State private draft: string = '';
  @State private imageUris: string[] = [];
  @State private gifUri: string = '';
  @State private videoUri: string = '';
  @State private publishing: boolean = false;
  @State private publishError: string = '';
  @State private draftNotice: string = '';
  @State private composeOptions: ComposerOptions = new ComposerOptions();
  @State private pickerAreaHeight: number = 105;
  private editorController: TextAreaController = new TextAreaController();
  private selectionStart: number = 0;
  private selectionEnd: number = 0;
  @State private videoUploadPercent: number = -1;
  @State private undoPublishEnabled: boolean = false;
  @State private mediaGridWidth: number = 0;
  private api: XApiClient = new XApiClient();
  private routeInitialText: string = '';
  private routeLoaded: boolean = false;
  private sharedImportId: string = '';
  private persistDraftOnExit: boolean = true;
  private draftSaveTimer: number = -1;
  private serverDraftId: string = '';
  private serverDraftSyncing: boolean = false;
  private hasLocalDraft: boolean = false;
  private serverDraftLoaded: boolean = false;
  private composerScroller: Scroller = new Scroller();
  @State private composerViewportHeight: number = 0;
  @State private replyTargetHeight: number = 0;
  @State private replyTargetTop: number = 0;
  @State private replyEditorTop: number = 0;
  @State private replyTargetPositioned: boolean = false;
  private initialReplyScrollScheduled: boolean = false;
  private composerPageActive: boolean = false;

  aboutToAppear(): void {
    this.composerPageActive = true;
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE);
    setTimeout((): void => {
      this.loadRouteParam();
      this.loadCurrentUserAvatar();
    }, 50);
  }

  aboutToDisappear(): void {
    this.composerPageActive = false;
    this.cancelDraftSave();
    if (this.persistDraftOnExit) {
      this.saveDraftNow();
    }
    // A closing root composer should not remain the next continuation task.
    // When it returns to a post, that destination immediately publishes its
    // own reading state in onShown().
    continuationStore.publishHome();
    // A reply composer returns to PostDetail, which owns the resize-mode
    // keyboard layout. Only a standalone composer restores the default mode.
    if (this.replyToId.length === 0) {
      this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.OFFSET);
    }
  }

  private async loadCurrentUserAvatar(): Promise<void> {
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    await authStore.load(context);
    const profile: UserProfile | null = await this.resolveViewer(context);
    if (profile === null) {
      return;
    }
    if (profile.avatarUrl !== undefined && profile.avatarUrl.length > 0) {
      this.avatarUrl = profile.avatarUrl;
      this.verifiedType = profile.verifiedType ?? ''; this.avatarShape = profile.avatarShape ?? '';
    }
    if (profile.name.length > 0) {
      this.avatarName = profile.name;
    }
  }

  private loadRouteParam(): void {
    const params: ReplyComposerRouteParam[] =
      this.pageStack.getParamByName('ReplyComposer') as ReplyComposerRouteParam[];
    if (params === undefined || params === null || params.length === 0) {
      return;
    }
    const param: ReplyComposerRouteParam = params[params.length - 1];
    this.replyToId = param.replyToId;
    this.replyToUser = param.replyToUser;
    this.parentTweet = param.parentTweet ?? null;
    this.communityId = param.communityId;
    this.communityName = param.communityName;
    this.avatarUrl = param.avatarUrl;
    this.avatarName = param.avatarName;
    this.avatarColor = param.avatarColor;
    this.routeInitialText = param.initialText;
    this.draft = param.initialText;
    const routeImages: string[] = [];
    if (param.imageUri.length > 0) {
      routeImages.push(param.imageUri);
    }
    this.imageUris = routeImages;
    this.gifUri = param.gifUri;
    this.routeLoaded = true;
    this.positionReplyTargetAboveEditor();
    this.restoreDraft();
    this.publishContinuationState();
    if (param.sharedPayload !== undefined) {
      this.importSharedPayload(param.sharedPayload).catch((): void => {});
    } else { this.loadServerDraft(); }
  }

  private async importSharedPayload(payload: ExternalSharePayload): Promise<void> {
    if (this.sharedImportId === payload.id) { return; }
    this.sharedImportId = payload.id;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const accountId: string = accountStore.activeId(context);
    if (this.draft.length > 0 || this.imageUris.length > 0 || this.gifUri.length > 0 || this.videoUri.length > 0 ||
      this.composeOptions.hasSettings()) {
      const choice: promptAction.ShowDialogSuccessResponse = await promptAction.showDialog({
        message: this.text($r('app.string.share_replace_draft')),
        buttons: [{ text: this.text($r('app.string.compose_cancel')), color: '' },
          { text: this.text($r('app.string.share_use_content')), color: '' }]
      });
      if (choice.index !== 1) { return; }
    }
    if (!this.composerPageActive || this.publishing || accountStore.activeId(context) !== accountId) { return; }
    this.composeOptions = new ComposerOptions();
    this.draft = payload.text;
    this.imageUris = payload.files.filter((file: ExternalShareFile): boolean => file.type === 1)
      .map((file: ExternalShareFile): string => file.uri);
    this.gifUri = payload.files.find((file: ExternalShareFile): boolean => file.type === 2)?.uri ?? '';
    this.videoUri = payload.files.find((file: ExternalShareFile): boolean => file.type === 3)?.uri ?? '';
    this.draftNotice = '';
    this.scheduleDraftSave();
  }

  private minimumScrollContentHeight(): number {
    const viewportHeight: number = this.compactWindow ? Math.max(0, this.composerViewportHeight) :
      Math.max(this.composerViewportHeight, COMPOSER_EDITOR_MIN_SCROLL_HEIGHT);
    return this.parentTweet === null ? viewportHeight : viewportHeight + this.replyTargetHeight;
  }

  private fixedPickerAreaHeight(): number {
    return this.pickerAreaHeight;
  }

  private onComposerViewportAreaChanged(oldArea: Area, newArea: Area): void {
    const height: number = Number(newArea.height);
    if (height <= 0 || Math.abs(height - this.composerViewportHeight) < 1) {
      return;
    }
    this.composerViewportHeight = height;
    this.positionReplyTargetAboveEditor();
  }

  private onReplyTargetAreaChanged(oldArea: Area, newArea: Area): void {
    const height: number = Number(newArea.height);
    this.replyTargetTop = Number(newArea.position.y);
    if (height <= 0 || Math.abs(height - this.replyTargetHeight) < 1) {
      return;
    }
    this.replyTargetHeight = height;
    this.positionReplyTargetAboveEditor();
  }

  private onReplyEditorAreaChanged(oldArea: Area, newArea: Area): void {
    this.replyEditorTop = Number(newArea.position.y);
    this.positionReplyTargetAboveEditor();
  }

  private replyThreadLineTop(): number {
    return this.replyTargetTop + 56;
  }

  private replyThreadLineHeight(): number {
    const lineBottom: number = this.replyEditorTop + 22;
    return Math.max(0, lineBottom - this.replyThreadLineTop());
  }

  private imageGridColumnsTemplate(): string {
    return this.imageGridItemCount() > 1 ? '1fr 1fr' : '1fr';
  }

  private imageGridRowsTemplate(): string {
    return this.imageGridItemCount() > 2 ? '1fr 1fr' : '1fr';
  }

  private imageGridItemCount(): number {
    return this.imageUris.length + (this.gifUri.length > 0 ? 1 : 0);
  }

  private remainingImageSlots(): number {
    return Math.max(0, COMPOSER_MAX_MEDIA_ITEMS - this.imageGridItemCount());
  }

  private imageGridItems(): ComposerMediaItem[] {
    const items: ComposerMediaItem[] = [];
    for (let index: number = 0; index < this.imageUris.length; index++) {
      const uri: string = this.imageUris[index];
      items.push({ uri: uri, isGif: false });
    }
    if (this.gifUri.length > 0) {
      items.push({ uri: this.gifUri, isGif: true });
    }
    return items;
  }

  private imageGridHeight(): number {
    const itemCount: number = this.imageGridItemCount();
    const columnCount: number = itemCount > 1 ? 2 : 1;
    const rowCount: number = Math.ceil(itemCount / columnCount);
    const measuredWidth: number = this.mediaGridWidth > 0 ? this.mediaGridWidth : 240;
    const cellWidth: number = (measuredWidth - (columnCount - 1) * COMPOSER_MEDIA_GRID_GAP) / columnCount;
    return rowCount * cellWidth + (rowCount - 1) * COMPOSER_MEDIA_GRID_GAP;
  }

  private onImageGridAreaChanged(oldArea: Area, newArea: Area): void {
    const width: number = Number(newArea.width);
    if (width <= 0 || Math.abs(width - this.mediaGridWidth) < 1) {
      return;
    }
    this.mediaGridWidth = width;
  }

  private positionReplyTargetAboveEditor(): void {
    if (!this.composerPageActive || !this.routeLoaded || this.parentTweet === null ||
      this.composerViewportHeight <= 0 || this.replyTargetHeight <= 0 || this.replyEditorTop <= 0 ||
      this.initialReplyScrollScheduled) {
      return;
    }
    this.initialReplyScrollScheduled = true;
    setTimeout((): void => {
      if (this.composerPageActive && this.parentTweet !== null) {
        try {
          this.composerScroller.scrollTo({
            xOffset: 0,
            yOffset: this.replyTargetHeight,
            animation: { duration: 0 }
          });
        } catch (error) {
        }
        this.replyTargetPositioned = true;
      }
    }, 100);
  }

  private text(resource: Resource): string {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    return context.resourceManager.getStringSync(resource);
  }

  private draftScope(): string {
    if (this.replyToId.length > 0) {
      return 'reply_' + this.replyToId;
    }
    if (this.replyToUser.length > 0) {
      return 'author_' + this.replyToUser.toLowerCase();
    }
    return this.communityId.length > 0 ? 'community_' + this.communityId : 'compose';
  }

  private isReply(): boolean {
    return this.replyToId.length > 0 || this.replyToUser.length > 0;
  }

  private publishContinuationState(): void {
    if (!this.routeLoaded) {
      return;
    }
    continuationStore.publishComposer(this.draft, this.replyToId, this.replyToUser);
  }

  private restoreDraft(): void {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const saved: ComposerDraft = composerDraftStore.load(context, this.draftScope());
    if (saved.updatedAt <= 0) {
      return;
    }
    this.hasLocalDraft = true;
    this.draft = saved.text;
    this.imageUris = saved.imageUris;
    this.gifUri = saved.gifUri;
    this.videoUri = saved.videoUri;
    this.composeOptions = saved.options;
    this.draftNotice = this.text($r('app.string.compose_draft_restored'));
  }

  private cancelDraftSave(): void {
    if (this.draftSaveTimer >= 0) {
      clearTimeout(this.draftSaveTimer);
      this.draftSaveTimer = -1;
    }
  }

  private scheduleDraftSave(): void {
    if (!this.routeLoaded || !this.persistDraftOnExit) {
      return;
    }
    this.publishContinuationState();
    this.draftNotice = '';
    this.cancelDraftSave();
    this.draftSaveTimer = setTimeout((): void => {
      this.draftSaveTimer = -1;
      this.saveDraftNow();
    }, 350);
  }

  private saveDraftNow(): void {
    if (!this.routeLoaded || !this.persistDraftOnExit) {
      return;
    }
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const hasChangedText: boolean = this.draft !== this.routeInitialText && this.draft.trim().length > 0;
    if (!hasChangedText && this.serverDraftLoaded && this.draft.trim().length > 0 &&
      this.imageUris.length === 0 && this.gifUri.length === 0 && this.videoUri.length === 0 &&
      !this.composeOptions.hasSettings()) {
      // A reply capsule may have supplied text before the server-draft lookup
      // finishes. Closing without changing that supplied text must not erase
      // an independent server draft for the same conversation.
      return;
    }
    if (!hasChangedText && this.imageUris.length === 0 && this.gifUri.length === 0 &&
      this.videoUri.length === 0 && !this.composeOptions.hasSettings()) {
      composerDraftStore.clear(context, this.draftScope());
      this.hasLocalDraft = false;
      this.deleteServerDraft();
      return;
    }
    const images: string[] = [];
    for (let i: number = 0; i < this.imageUris.length; i++) {
      images.push(this.imageUris[i]);
    }
    const saved: ComposerDraft = new ComposerDraft(this.draft, images, this.gifUri, this.videoUri, Date.now());
    saved.options = this.composeOptions.copy();
    composerDraftStore.save(context, this.draftScope(), saved);
    this.hasLocalDraft = true;
    this.syncServerDraft();
  }

  private clearSavedDraft(context: common.UIAbilityContext): void {
    this.cancelDraftSave();
    composerDraftStore.clear(context, this.draftScope());
    this.hasLocalDraft = false;
    this.deleteServerDraft();
    this.persistDraftOnExit = false;
  }

  private canPublish(): boolean {
    const text: string = this.draft.trim();
    const mentionOnly: boolean = this.replyToId.length === 0 && this.replyToUser.length > 0 &&
      text === '@' + this.replyToUser.trim();
    const hasContent: boolean =
      (text.length > 0 && !mentionOnly) || this.imageUris.length > 0 || this.gifUri.length > 0 ||
      this.videoUri.length > 0;
    return hasContent && this.draft.length <= this.maxCharacters() && this.composeOptions.pollValid();
  }

  private maxCharacters(): number {
    return this.communityId.length > 0 || this.composeOptions.scheduledAt > 0 ||
      this.composeOptions.pollChoices.length > 0 ? STANDARD_POST_CHARACTERS : MAX_POST_CHARACTERS;
  }

  private characterCountLabel(): string {
    return this.draft.length.toString() + '/' + this.maxCharacters().toString();
  }

  private isLongPost(): boolean {
    return this.communityId.length === 0 && this.draft.length > STANDARD_POST_CHARACTERS;
  }

  // Existing server drafts have already been created by X, so they can be
  // resumed, edited and removed with the operation set bundled in this app.
  // Fresh local drafts remain local until X exposes a CreateDraft operation in
  // the registry; this avoids fabricating a write request from incomplete data.
  private async loadServerDraft(): Promise<void> {
    if (!this.routeLoaded || this.communityId.length > 0 ||
      (this.replyToId.length === 0 && this.replyToUser.length > 0)) {
      return;
    }
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    xPrivateClient.load(context);
    if (!xPrivateClient.isSignedIn()) {
      return;
    }
    const result: XPrivateResult = await xPrivateClient.getDraftTweets();
    if (!result.ok) {
      return;
    }
    const drafts: ServerDraftTweet[] = XBookmarkParser.parseDrafts(result.body);
    let matched: ServerDraftTweet | null = null;
    for (let i: number = 0; i < drafts.length; i++) {
      if (drafts[i].replyToId === this.replyToId) {
        matched = drafts[i];
        break;
      }
    }
    if (matched === null) {
      return;
    }
    this.serverDraftId = matched.id;
    this.serverDraftLoaded = true;
    if (!this.hasLocalDraft && this.routeInitialText.length === 0) {
      this.draft = matched.text;
      this.draftNotice = this.text($r('app.string.compose_server_draft_restored'));
      this.publishContinuationState();
    }
  }

  private syncServerDraft(): void {
    if (this.serverDraftId.length === 0 || this.serverDraftSyncing || this.draft.trim().length === 0) {
      return;
    }
    if (this.imageUris.length > 0 || this.gifUri.length > 0 || this.videoUri.length > 0 || this.composeOptions.hasSettings()) {
      // Existing draft text is still kept locally with its attachments.  X's
      // draft response shape does not consistently preserve media across
      // clients, so do not overwrite a remote draft with a partial payload.
      return;
    }
    this.serverDraftSyncing = true;
    xPrivateClient.editDraftTweet(this.serverDraftId, this.draft).then((result: XPrivateResult): void => {
      this.serverDraftSyncing = false;
      if (!result.ok) {
        // The local draft was persisted first; a transient server failure does
        // not erase it or keep retrying an account write in the background.
      }
    });
  }

  private deleteServerDraft(): void {
    if (this.serverDraftId.length === 0 || this.serverDraftSyncing) {
      return;
    }
    const id: string = this.serverDraftId;
    this.serverDraftSyncing = true;
    xPrivateClient.deleteDraftTweet(id).then((result: XPrivateResult): void => {
      this.serverDraftSyncing = false;
      if (result.ok && this.serverDraftId === id) {
        this.serverDraftId = '';
        this.serverDraftLoaded = false;
      }
    });
  }

  private async confirmDeleteServerDraft(): Promise<void> {
    if (this.serverDraftId.length === 0 || this.serverDraftSyncing || this.publishing) {
      return;
    }
    const dialog: promptAction.ShowDialogSuccessResponse = await promptAction.showDialog({
      title: this.text($r('app.string.compose_delete_server_draft')),
      message: this.text($r('app.string.compose_delete_server_draft_confirm')),
      buttons: [
        { text: this.text($r('app.string.compose_cancel')), color: '#666666' },
        { text: this.text($r('app.string.compose_delete_server_draft')), color: '#E0245E' }
      ]
    });
    if (dialog.index !== 1) {
      return;
    }
    const id: string = this.serverDraftId;
    this.serverDraftSyncing = true;
    const result: XPrivateResult = await xPrivateClient.deleteDraftTweet(id);
    this.serverDraftSyncing = false;
    if (!result.ok) {
      promptAction.showToast({
        message: this.text($r('app.string.compose_server_draft_delete_failed')) + ' · HTTP ' + result.status,
        duration: 2200
      });
      return;
    }
    const keepLocalDraft: boolean = this.hasLocalDraft;
    this.serverDraftId = '';
    this.serverDraftLoaded = false;
    if (!keepLocalDraft) {
      this.cancelDraftSave();
      const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      composerDraftStore.clear(context, this.draftScope());
      this.draft = '';
      this.imageUris = [];
      this.gifUri = '';
      this.videoUri = '';
    }
    this.draftNotice = this.text($r('app.string.compose_server_draft_deleted'));
    promptAction.showToast({ message: this.draftNotice, duration: 1500 });
  }

  private async selectImage(): Promise<void> {
    if (this.publishing || this.composeOptions.pollChoices.length > 0) { return; }
    const remaining: number = this.remainingImageSlots();
    if (remaining <= 0) {
      promptAction.showToast({ message: this.text($r('app.string.compose_media_limit')), duration: 1800 });
      return;
    }
    try {
      const options: photoAccessHelper.PhotoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = remaining;
      const photoPicker: photoAccessHelper.PhotoViewPicker = new photoAccessHelper.PhotoViewPicker();
      const result: photoAccessHelper.PhotoSelectResult = await photoPicker.select(options);
      if (this.publishing || this.composeOptions.pollChoices.length > 0) { return; }
      if (result.photoUris.length > 0) {
        const next: string[] = [];
        for (let i: number = 0; i < this.imageUris.length; i++) {
          next.push(this.imageUris[i]);
        }
        const gifCount: number = this.gifUri.length > 0 ? 1 : 0;
        for (let i: number = 0; i < result.photoUris.length &&
          next.length + gifCount < COMPOSER_MAX_MEDIA_ITEMS; i++) {
          const uri: string = result.photoUris[i];
          if (uri.length > 0 && next.indexOf(uri) < 0) {
            next.push(uri);
          }
        }
        this.imageUris = next;
        this.videoUri = '';
        this.scheduleDraftSave();
      }
    } catch (error) {
    }
  }

  private async selectGif(): Promise<void> {
    if (this.composeOptions.pollChoices.length > 0) {
      promptAction.showToast({ message: this.text($r('app.string.compose_poll_conflict')) }); return;
    }
    if (this.gifUri.length === 0 && this.remainingImageSlots() <= 0) {
      promptAction.showToast({ message: this.text($r('app.string.compose_media_limit')), duration: 1800 });
      return;
    }
    try {
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const options: picker.DocumentSelectOptions = new picker.DocumentSelectOptions();
      options.fileSuffixFilters = ['gif'];
      options.maxSelectNumber = 1;
      const gifPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(context);
      const result: Array<string> = await gifPicker.select(options);
      if (result.length > 0) {
        this.gifUri = result[0];
        this.videoUri = '';
        this.scheduleDraftSave();
      }
    } catch (error) {
    }
  }

  private openGifSearch(): void {
    if (this.composeOptions.pollChoices.length > 0) {
      promptAction.showToast({ message: this.text($r('app.string.compose_poll_conflict')) }); return;
    }
    if (this.gifUri.length === 0 && this.remainingImageSlots() <= 0) {
      promptAction.showToast({ message: this.text($r('app.string.compose_media_limit')), duration: 1800 });
      return;
    }
    this.pageStack.pushPath({ name: 'GifSearchPage' }, false);
  }

  private consumeGifSearchSelection(): void {
    const uri: string = gifSearchSelectionStore.take();
    if (uri.length === 0) {
      return;
    }
    if (this.publishing || this.composeOptions.pollChoices.length > 0) { return; }
    if (this.gifUri.length === 0 && this.remainingImageSlots() <= 0) {
      promptAction.showToast({ message: this.text($r('app.string.compose_media_limit')), duration: 1800 });
      return;
    }
    this.gifUri = uri;
    this.videoUri = '';
    this.scheduleDraftSave();
  }

  private removeImage(uri: string): void {
    const next: string[] = [];
    for (let i: number = 0; i < this.imageUris.length; i++) {
      if (this.imageUris[i] !== uri) {
        next.push(this.imageUris[i]);
      }
    }
    this.imageUris = next;
    this.scheduleDraftSave();
  }

  private removeGif(): void {
    this.gifUri = '';
    this.scheduleDraftSave();
  }

  private async selectVideo(): Promise<void> {
    if (this.composeOptions.pollChoices.length > 0) {
      promptAction.showToast({ message: this.text($r('app.string.compose_poll_conflict')) }); return;
    }
    try {
      const options: photoAccessHelper.PhotoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.VIDEO_TYPE;
      options.maxSelectNumber = 1;
      const videoPicker: photoAccessHelper.PhotoViewPicker = new photoAccessHelper.PhotoViewPicker();
      const result: photoAccessHelper.PhotoSelectResult = await videoPicker.select(options);
      if (result.photoUris.length > 0) {
        this.videoUri = result.photoUris[0];
        this.imageUris = [];
        this.gifUri = '';
        this.scheduleDraftSave();
      }
    } catch (error) {
    }
  }

  private removeVideo(): void {
    this.videoUri = '';
    this.scheduleDraftSave();
  }

  // The camera button uses the system camera picker, which provides the
  // security-reviewed capture surface without requiring the app to hold the
  // CAMERA permission. The captured file comes back as a media URI.
  private async takePhoto(): Promise<void> {
    if (this.composeOptions.pollChoices.length > 0) {
      promptAction.showToast({ message: this.text($r('app.string.compose_poll_conflict')) }); return;
    }
    if (this.remainingImageSlots() <= 0) {
      promptAction.showToast({ message: this.text($r('app.string.compose_media_limit')), duration: 1800 });
      return;
    }
    try {
      const context: common.UIAbilityContext =
        this.getUIContext().getHostContext() as common.UIAbilityContext;
      const filePath: string = context.filesDir + '/harmonyx-camera-' +
        Date.now().toString() + '.jpg';
      const file: fileIo.File = fileIo.openSync(filePath,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE);
      fileIo.closeSync(file.fd);
      const profile: cameraPicker.PickerProfile = {
        cameraPosition: camera.CameraPosition.CAMERA_POSITION_BACK,
        saveUri: fileUri.getUriFromPath(filePath)
      };
      const mediaTypes: Array<cameraPicker.PickerMediaType> =
        [cameraPicker.PickerMediaType.PHOTO];
      const result: cameraPicker.PickerResult =
        await cameraPicker.pick(context, mediaTypes, profile);
      if (result.resultCode !== 0 || result.resultUri.length === 0) {
        return;
      }
      const next: string[] = [];
      const gifCount: number = this.gifUri.length > 0 ? 1 : 0;
      for (let i: number = 0; i < this.imageUris.length &&
        next.length + gifCount < COMPOSER_MAX_MEDIA_ITEMS; i++) {
        next.push(this.imageUris[i]);
      }
      if (result.resultUri.length > 0 && next.length + gifCount < COMPOSER_MAX_MEDIA_ITEMS &&
        next.indexOf(result.resultUri) < 0) {
        next.push(result.resultUri);
      }
      this.imageUris = next;
      this.videoUri = '';
      this.scheduleDraftSave();
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'cameraPicker failed: %{public}s', JSON.stringify(error));
      promptAction.showToast({
        message: this.text($r('app.string.compose_camera_failed')),
        duration: 2000
      });
    }
  }

  // This is deliberately a local recording path.  ServiceCollaborationKit
  // exposes TAKE_PHOTO for a remote camera, but no public TAKE_VIDEO service.
  private async takeVideo(): Promise<void> {
    if (this.publishing || this.composeOptions.pollChoices.length > 0) { return; }
    try {
      const context: common.UIAbilityContext =
        this.getUIContext().getHostContext() as common.UIAbilityContext;
      const filePath: string = context.filesDir + '/harmonyx-video-' +
        Date.now().toString() + '.mp4';
      const file: fileIo.File = fileIo.openSync(filePath,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE);
      fileIo.closeSync(file.fd);
      const profile: cameraPicker.PickerProfile = {
        cameraPosition: camera.CameraPosition.CAMERA_POSITION_BACK,
        saveUri: fileUri.getUriFromPath(filePath)
      };
      const mediaTypes: Array<cameraPicker.PickerMediaType> =
        [cameraPicker.PickerMediaType.VIDEO];
      const result: cameraPicker.PickerResult =
        await cameraPicker.pick(context, mediaTypes, profile);
      if (result.resultCode !== 0 || result.resultUri.length === 0) {
        return;
      }
      this.videoUri = result.resultUri;
      this.imageUris = [];
      this.gifUri = '';
      this.scheduleDraftSave();
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'camera video picker failed: %{public}s', JSON.stringify(error));
      promptAction.showToast({
        message: this.text($r('app.string.compose_camera_failed')),
        duration: 2000
      });
    }
  }

  @Builder
  private CameraMenu(): void {
    Menu() {
      MenuItem({ content: $r('app.string.compose_take_photo') })
        .onClick((): void => {
          this.takePhoto();
        });
      MenuItem({ content: $r('app.string.compose_record_video') })
        .onClick((): void => {
          this.takeVideo();
        });
      createCollaborationServiceMenuItems(
        [CollaborationServiceFilter.TAKE_PHOTO],
        4,
        [
          CollaborationDeviceFilterType.PHONE,
          CollaborationDeviceFilterType.TABLET,
          CollaborationDeviceFilterType.PC_2IN1
        ]
      );
    }
  }

  // The system gallery picker is only local. The collaboration menu appends
  // nearby devices that can provide their own gallery, and the state dialog
  // below receives the selected bytes back into this composer.  Passing the
  // device type filter is required for tablets to be offered as collaborators.
  @Builder
  private ImageGalleryMenu(): void {
    Menu() {
      MenuItem({ content: $r('app.string.compose_gallery_local_image') })
        .onClick((): void => {
          this.selectImage();
        });
      createCollaborationServiceMenuItems(
        [CollaborationServiceFilter.IMAGE_PICKER],
        4,
        [
          CollaborationDeviceFilterType.PHONE,
          CollaborationDeviceFilterType.TABLET,
          CollaborationDeviceFilterType.PC_2IN1
        ]
      );
    }
  }

  @Builder
  private GifMenu(): void {
    Menu() {
      MenuItem({ content: $r('app.string.compose_gif_local') })
        .onClick((): void => {
          this.selectGif();
        });
      MenuItem({ content: $r('app.string.compose_gif_search') })
        .onClick((): void => {
          this.openGifSearch();
        });
    }
  }

  @Builder
  private VideoGalleryMenu(): void {
    Menu() {
      MenuItem({ content: $r('app.string.compose_gallery_local_video') })
        .onClick((): void => {
          this.selectVideo();
        });
      createCollaborationServiceMenuItems(
        [CollaborationServiceFilter.VIDEO_PICKER],
        1,
        [
          CollaborationDeviceFilterType.PHONE,
          CollaborationDeviceFilterType.TABLET,
          CollaborationDeviceFilterType.PC_2IN1
        ]
      );
    }
  }

  private handleRemoteMedia(stateCode: number, bufferType: string, buffer: ArrayBuffer): void {
    if (this.publishing || this.composeOptions.pollChoices.length > 0 || stateCode !== 0 || buffer.byteLength === 0) {
      return;
    }
    const uri: string = this.storeRemoteMedia(buffer, bufferType);
    if (uri.length === 0) {
      return;
    }
    if (bufferType === 'general.video') {
      this.videoUri = uri;
      this.imageUris = [];
      this.gifUri = '';
    } else {
      const next: string[] = [];
      const gifCount: number = this.gifUri.length > 0 ? 1 : 0;
      for (let i: number = 0; i < this.imageUris.length &&
        next.length + gifCount < COMPOSER_MAX_MEDIA_ITEMS; i++) {
        next.push(this.imageUris[i]);
      }
      if (next.length + gifCount < COMPOSER_MAX_MEDIA_ITEMS && next.indexOf(uri) < 0) {
        next.push(uri);
      }
      this.imageUris = next;
      this.videoUri = '';
    }
    this.scheduleDraftSave();
  }

  private storeRemoteMedia(buffer: ArrayBuffer, bufferType: string): string {
    let file: fileIo.File | undefined = undefined;
    try {
      const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      const extension: string = bufferType === 'general.video' ? '.mp4' : '.jpg';
      const path: string = context.cacheDir + '/harmonyx-remote-' +
        Date.now().toString() + '-' +
        Math.floor(Math.random() * 100000).toString() + extension;
      file = fileIo.openSync(path,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(file.fd, buffer);
      return fileUri.getUriFromPath(path);
    } catch (error) {
      promptAction.showToast({
        message: this.text($r('app.string.compose_remote_media_failed')),
        duration: 2000
      });
      return '';
    } finally {
      if (file !== undefined) {
        try {
          fileIo.closeSync(file.fd);
        } catch (error) {
        }
      }
    }
  }

  // Resolves the signed-in account for the composer header. Prefers the cookie
  // session, which is the only credential a cookie-only user has; the viewer id
  // comes from the twid cookie.
  private async resolveViewer(context: common.UIAbilityContext): Promise<UserProfile | null> {
    xPrivateClient.load(context);
    if (xPrivateClient.isSignedIn()) {
      const viewerId: string = xPrivateClient.viewerId();
      if (viewerId.length > 0) {
        const result: XPrivateResult = await xPrivateClient.userByRestId(viewerId);
        const profile: UserProfile | null = result.ok ? XUserParser.parse(result.body) : null;
        if (profile !== null) {
          return profile;
        }
      }
    }
    if (!authStore.isSignedIn()) {
      return null;
    }
    this.api.setToken(authStore.getToken());
    this.api.setUser(authStore.getUserId());
    return await this.api.profile();
  }

  private async publish(): Promise<void> {
    const content: string = this.draft.trim();
    const options: ComposerOptions = this.composeOptions.copy();
    if (!this.canPublish() || this.publishing) {
      return;
    }
    this.publishing = true;
    this.publishError = '';
    try {
      const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      await authStore.load(context);
      xPrivateClient.load(context);
      const usePrivate: boolean = xPrivateClient.isSignedIn();
      if (this.composeOptions.scheduledAt > 0 &&
        (this.composeOptions.scheduledAt < Date.now() + 60000 ||
        this.composeOptions.scheduledAt > Date.now() + 548 * 86400000 || this.composeOptions.pollChoices.length > 0 ||
        this.composeOptions.replyMode.length > 0 || this.composeOptions.placeId.length > 0 ||
        this.communityId.length > 0)) {
        this.publishError = this.text($r('app.string.compose_schedule_invalid')); return;
      }
      if (this.composeOptions.pollChoices.length > 0 &&
        (this.imageUris.length > 0 || this.gifUri.length > 0 || this.videoUri.length > 0)) {
        this.publishError = this.text($r('app.string.compose_poll_conflict')); return;
      }
      if (this.communityId.length > 0 && !usePrivate) {
        this.publishError = this.text($r('app.string.community_post_session_required'));
        return;
      }
      if (!authStore.isSignedIn() && !usePrivate) {
        this.publishError = this.text($r('app.string.post_detail_sign_in'));
        return;
      }
      const hasMedia: boolean =
        this.imageUris.length > 0 || this.gifUri.length > 0 || this.videoUri.length > 0;
      const canUseOfficialApi: boolean = authStore.isSignedIn() &&
        authStore.getUserId().length > 0 && !hasMedia && !this.isLongPost() &&
        !this.undoPublishEnabled && this.communityId.length === 0 && !this.composeOptions.needsWebSession();
      if (canUseOfficialApi) {
        this.api.setToken(authStore.getToken());
        this.api.setUser(authStore.getUserId());
        const published: boolean = await this.api.postTweet(content, this.replyToId, options);
        if (published) {
          this.completePublished(context);
          return;
        }
        // A transport loss or an unparseable success response cannot safely be
        // retried or handed to another route: X may have created the post.
        const status: number = this.api.lastStatus();
        if (status < 0 || (status >= 200 && status < 300)) {
          this.publishError = XPostFeedback.failure(context, status, this.api.lastPostReceipt());
          return;
        }
      }
      if (usePrivate) {
        const outcome: number = await this.publishViaPrivate(context, content, options);
        if (outcome === PRIVATE_PUBLISH_OK) {
          this.completePublished(context);
          return;
        }
        if (outcome === PRIVATE_PUBLISH_ERROR) {
          return;
        }
        if (outcome === PRIVATE_PUBLISH_FALLBACK && this.communityId.length > 0) {
          this.publishError = this.text($r('app.string.community_post_fallback_unsupported'));
          return;
        }
      }
      if (this.composeOptions.hasSettings()) {
        this.publishError = this.text($r('app.string.compose_options_session_required')); return;
      }
      await this.openXComposer(context, content, hasMedia);
    } catch (error) {
      this.publishError = this.text($r('app.string.post_send_unconfirmed'));
    } finally {
      this.publishing = false;
      this.videoUploadPercent = -1;
    }
  }

  // Publishes through the cookie session with the transaction id X expects.
  // Returns OK, FALLBACK (for the 226 challenge) or ERROR with publishError set.
  private async publishViaPrivate(context: common.UIAbilityContext, content: string, options: ComposerOptions): Promise<number> {
    const generation: number = xPrivateClient.sessionGeneration();
    const mediaUris: string[] = [];
    for (let i: number = 0; i < this.imageUris.length; i++) {
      mediaUris.push(this.imageUris[i]);
    }
    if (this.gifUri.length > 0) {
      mediaUris.push(this.gifUri);
    }
    const mediaIds: string[] = [];
    if (this.videoUri.length > 0) {
      this.videoUploadPercent = 0;
      const upload: XPrivateResult = await xPrivateClient.uploadVideo(this.videoUri,
        (percent: number): void => {
          this.videoUploadPercent = percent;
        });
      this.videoUploadPercent = -1;
      const mediaId: string = upload.ok ? XPrivateClient.mediaIdFrom(upload.body) : '';
      if (mediaId.length === 0) {
        this.publishError = this.videoUploadError(upload);
        return PRIVATE_PUBLISH_ERROR;
      }
      mediaIds.push(mediaId);
    } else {
      for (let i: number = 0; i < mediaUris.length; i++) {
        const upload: XPrivateResult = await xPrivateClient.uploadMedia(mediaUris[i], '');
        if (generation !== xPrivateClient.sessionGeneration()) {
          this.publishError = this.text($r('app.string.compose_account_changed')); return PRIVATE_PUBLISH_ERROR;
        }
        const mediaId: string = upload.ok ? XPrivateClient.mediaIdFrom(upload.body) : '';
        if (mediaId.length === 0) {
          const status: string = upload.status > 0 ? ' · HTTP ' + upload.status.toString() : '';
          this.publishError = this.text($r('app.string.post_media_failed')) + status;
          return PRIVATE_PUBLISH_ERROR;
        }
        mediaIds.push(mediaId);
      }
    }
    if (generation !== xPrivateClient.sessionGeneration()) {
      this.publishError = this.text($r('app.string.compose_account_changed')); return PRIVATE_PUBLISH_ERROR;
    }
    if (options.scheduledAt > 0) {
      const schedule: XPrivateResult = await xPrivateClient.createScheduledTweet(content, this.replyToId,
        mediaIds, options.scheduledAt, options);
      if (generation !== xPrivateClient.sessionGeneration()) {
        this.publishError = this.text($r('app.string.compose_account_changed')); return PRIVATE_PUBLISH_ERROR;
      }
      if (schedule.ok) { return PRIVATE_PUBLISH_OK; }
      this.publishError = this.text($r('app.string.compose_schedule_failed')) +
        (schedule.status > 0 ? ' · HTTP ' + schedule.status.toString() : '') + ' · ' + schedule.errorText;
      return PRIVATE_PUBLISH_ERROR;
    }
    let cardUri: string = '';
    if (options.pollChoices.length > 0) {
      const imageIds: string[] = [];
      for (let i: number = 0; i < options.pollChoices.length; i++) {
        const uri: string = i < options.pollImages.length ? options.pollImages[i] : '';
        let imageId: string = '';
        if (uri.length > 0) {
          const upload: XPrivateResult = await xPrivateClient.uploadMedia(uri, '');
          if (generation !== xPrivateClient.sessionGeneration()) {
            this.publishError = this.text($r('app.string.compose_account_changed')); return PRIVATE_PUBLISH_ERROR;
          }
          imageId = upload.ok ? XPrivateClient.mediaIdFrom(upload.body) : '';
          if (imageId.length === 0) {
            this.publishError = this.text($r('app.string.post_media_failed')) + ' · ' + upload.errorText;
            return PRIVATE_PUBLISH_ERROR;
          }
        }
        imageIds.push(imageId);
      }
      const card: XPrivateResult = await xPrivateClient.createComposePoll(options, imageIds);
      if (!card.ok) {
        this.publishError = this.text($r('app.string.compose_poll_failed')) +
          (card.status > 0 ? ' · HTTP ' + card.status.toString() : '') + ' · ' + card.errorText;
        return PRIVATE_PUBLISH_ERROR;
      }
      cardUri = XPrivateClient.composeCardUri(card.body);
    }
    if (generation !== xPrivateClient.sessionGeneration()) {
      this.publishError = this.text($r('app.string.compose_account_changed')); return PRIVATE_PUBLISH_ERROR;
    }
    let result: XPrivateResult;
    if (this.communityId.length > 0) {
      result = await xPrivateClient.createCommunityTweet(content, this.communityId, mediaIds, options, cardUri);
    } else if (this.isLongPost()) {
      result = await xPrivateClient.createNoteTweetWithMedia(content, this.replyToId, mediaIds, options, cardUri);
    } else if (this.undoPublishEnabled && !options.hasSettings()) {
      result = await xPrivateClient.createTweetWithUndo(content, this.replyToId, mediaIds, options, cardUri);
    } else {
      result = await xPrivateClient.createTweetWithMedia(content, this.replyToId, mediaIds, options, cardUri);
    }
    if (generation !== xPrivateClient.sessionGeneration()) {
      this.publishError = this.text($r('app.string.compose_account_changed')); return PRIVATE_PUBLISH_ERROR;
    }
    if (result.ok) {
      return PRIVATE_PUBLISH_OK;
    }
    if (result.postReceipt.errorCode === '226') {
      return PRIVATE_PUBLISH_FALLBACK;
    }
    this.publishError = XPostFeedback.failure(context, result.status, result.postReceipt);
    return PRIVATE_PUBLISH_ERROR;
  }

  private videoUploadError(upload: XPrivateResult): string {
    if (upload.errorText === 'video_too_large') {
      return this.text($r('app.string.compose_video_too_large'));
    }
    if (upload.errorText === 'video_processing_failed') {
      return this.text($r('app.string.compose_video_process_failed'));
    }
    if (upload.errorText === 'video_processing_timeout') {
      return this.text($r('app.string.compose_video_process_timeout'));
    }
    const status: string = upload.status > 0 ? ' · HTTP ' + upload.status.toString() : '';
    return this.text($r('app.string.post_video_failed')) + status;
  }

  // Last resort: X's documented Web Intent in the system browser. The in-app
  // ArkWeb composer is intentionally not used because X's own web app can
  // still answer a write from that renderer with error 226.
  private async openXComposer(context: common.UIAbilityContext, content: string,
    hasMedia: boolean): Promise<void> {
    const want: Want = {
      action: 'ohos.want.action.viewData',
      entities: ['entity.system.browsable'],
      uri: buildXPostIntentUrl(content, this.replyToId)
    };
    try {
      await context.startAbility(want);
      const message: Resource = hasMedia ? $r('app.string.post_continue_in_x_with_media') :
        $r('app.string.post_continue_in_x');
      promptAction.showToast({ message: this.text(message), duration: 2500 });
      // The draft is intentionally retained until X confirms publication in
      // its own UI. This also prevents loss if the user cancels the composer.
      ResponsiveLayout.closeContentDestination(this.pageStack);
    } catch (error) {
      this.publishError = this.text($r('app.string.post_open_web_failed'));
    }
  }

  private completePublished(context: common.UIAbilityContext): void {
    this.clearSavedDraft(context);
    promptAction.showToast({ message: this.text(this.composeOptions.scheduledAt > 0 ?
      $r('app.string.compose_schedule_saved') : $r('app.string.toast_published')), duration: 1500 });
    if (this.composeOptions.scheduledAt === 0) { this.notifyPublished(); }
    ResponsiveLayout.closeContentDestination(this.pageStack);
  }

  private publishButtonLabel(): string {
    if (this.videoUploadPercent >= 0) {
      return this.text($r('app.string.compose_video_uploading')) + ' ' +
        this.videoUploadPercent.toString() + '%';
    }
    if (this.publishing) {
      return this.text($r('app.string.post_sending'));
    }
    if (this.composeOptions.scheduledAt > 0) { return this.text($r('app.string.compose_schedule_action')); }
    const resource: Resource = this.communityId.length > 0 ? $r('app.string.community_post_action') :
      this.isReply() ? $r('app.string.action_reply') : $r('app.string.compose_post');
    return this.text(resource);
  }

  private notifyPublished(): void {
    const current: number = AppStorage.get<number>('harmonyx.posts_changed') ?? 0;
    AppStorage.setOrCreate<number>('harmonyx.posts_changed', current + 1);
  }

  @Builder
  private Avatar(): void {
    if (this.avatarUrl.length > 0) {
      Image(this.avatarUrl)
        .width(52)
        .height(52)
        .objectFit(ImageFit.Cover)
        .borderRadius(userAvatarRadius(52, 26, this.verifiedType, this.avatarShape))
        .clip(true)
    } else {
      Text(this.avatarName.substring(0, 1).toUpperCase()).fontFamily(this.appFontFamily)
        .width(52)
        .height(52)
        .fontSize($r('sys.float.Subtitle_L'))
        .maxFontScale(1)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_on_brand'))
        .backgroundColor(this.avatarColor)
        .borderRadius(userAvatarRadius(52, 26, this.verifiedType, this.avatarShape))
        .textAlign(TextAlign.Center)
    }
  }

  @Builder
  private Header(): void {
    Row() {
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.xmark'))
          .fontSize(25)
          .fontColor([$r('app.color.text_primary')]);
      }
      .width(48)
      .height(48)
      .backgroundColor(Color.Transparent)
      .enabled(!this.publishing)
      .onClick((): void => {
        ResponsiveLayout.closeContentDestination(this.pageStack);
      });
      Blank();
      Button(this.publishButtonLabel(), { stateEffect: true })
        .fontSize($r('sys.float.Body_L'))
        .maxFontScale(1.5)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_on_accent'))
        .backgroundColor(this.accentColor)
        .foregroundFilter(ComponentHdrHighlight.filter(this.getUIContext(), this.componentHdrEnabled && this.canPublish() && !this.publishing, this.componentHdrRatio))
        .borderRadius(24)
        .enabled(this.canPublish() && !this.publishing)
        .onClick((): void => {
          this.publish();
        });
    }
    .width('100%')
    .height(COMPOSER_HEADER_HEIGHT)
    .padding({ start: LengthMetrics.vp(8), end: LengthMetrics.vp(12) });
  }

  @Builder
  private TitleBarContent(): void {
    this.Header();
  }

  @Builder
  private Attachment(
    uri: string,
    isGif: boolean,
    onRemove: () => void,
    onEdit: () => void,
    imageFit: ImageFit
  ): void {
    Stack({ alignContent: Alignment.TopEnd }) {
      Image(uri)
        .width('100%')
        .height('100%')
        .objectFit(imageFit)
        .borderRadius(12)
        .clip(true)
        .onClick(onEdit);
      if (isGif) {
        Text('GIF').fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Caption_L'))
          .maxFontScale(1)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_on_accent'))
          .backgroundColor(this.accentColor)
          .borderRadius(6)
          .padding({ left: 6, right: 6, top: 3, bottom: 3 })
          .margin(6);
      }
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.xmark'))
          .fontSize(13)
          .fontColor([$r('app.color.text_on_inverse')]);
      }
      .width(26)
      .height(26)
      .backgroundColor($r('app.color.text_primary'))
      .margin(6)
      .enabled(!this.publishing)
      .onClick(onRemove);
    }
    .width('100%')
    .height('100%');
  }

  @Builder
  private ImageGrid(): void {
    Grid() {
      ForEach(this.imageGridItems(), (item: ComposerMediaItem): void => {
        GridItem() {
          this.Attachment(item.uri, item.isGif, (): void => {
            if (item.isGif) {
              this.removeGif();
            } else {
              this.removeImage(item.uri);
            }
          }, (): void => {
            if (item.isGif) {
              this.openGifPreview(item.uri);
            } else {
              this.openImageEditor(item.uri);
            }
          }, item.isGif ? ImageFit.Contain : ImageFit.Cover);
        }
      }, (item: ComposerMediaItem): string => item.uri)
    }
    .columnsTemplate(this.imageGridColumnsTemplate())
    .rowsTemplate(this.imageGridRowsTemplate())
    .columnsGap(COMPOSER_MEDIA_GRID_GAP)
    .rowsGap(COMPOSER_MEDIA_GRID_GAP)
    .width('100%')
    .height(this.imageGridHeight())
    .onAreaChange((oldArea: Area, newArea: Area): void => {
      this.onImageGridAreaChanged(oldArea, newArea);
    });
  }

  private openGifPreview(uri: string): void {
    const param: PhotoViewerRouteParam = { urls: [uri], index: 0, alt: '', transitionPrefix: '' };
    this.pageStack.pushPath({ name: 'PhotoViewer', param: param });
  }

  private openImageEditor(uri: string): void {
    const param: ImageEditRouteParam = { imageUri: uri };
    this.pageStack.pushPath({
      name: 'ImageEdit',
      param: param,
      onPop: (popInfo: PopInfo): void => {
        const result: ImageEditResult = popInfo.result as ImageEditResult;
        if (result === undefined || result === null || result.imageUri.length === 0) {
          return;
        }
        const next: string[] = [];
        for (let index: number = 0; index < this.imageUris.length; index++) {
          const current: string = this.imageUris[index];
          next.push(current === uri ? result.imageUri : current);
        }
        this.imageUris = next;
        this.scheduleDraftSave();
      }
    });
  }

  @Builder
  private VideoAttachment(onRemove: () => void): void {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width(112)
        .height(112)
        .backgroundColor($r('app.color.bg_field'))
        .borderRadius(12)
      SymbolGlyph($r('sys.symbol.video_fill'))
        .fontSize(34)
        .fontColor([this.accentColor])
        .foregroundFilter(ComponentHdrHighlight.filter(this.getUIContext(), this.componentHdrEnabled && !this.publishing, this.componentHdrRatio));
      Text($r('app.string.compose_video_label')).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Caption_L'))
        .maxFontScale(1)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_on_accent'))
        .backgroundColor(this.accentColor)
        .borderRadius(6)
        .padding({ left: 6, right: 6, top: 3, bottom: 3 })
        .position({ x: 6, y: 6 });
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.xmark'))
          .fontSize(13)
          .fontColor([$r('app.color.text_on_inverse')]);
      }
      .width(26)
      .height(26)
      .backgroundColor($r('app.color.text_primary'))
      .position({ x: 80, y: 6 })
      .enabled(!this.publishing)
      .onClick(onRemove);
    }
    .width(112)
    .height(112)
  }

  @Builder
  private ToolbarButton(symbol: Resource, label: Resource, onClick: () => void): void {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph(symbol)
        .fontSize(25)
        .fontColor([this.accentColor])
        .foregroundFilter(ComponentHdrHighlight.filter(this.getUIContext(), this.componentHdrEnabled && !this.publishing, this.componentHdrRatio));
    }
    .width(48)
    .height(48)
    .backgroundColor(Color.Transparent)
    .enabled(!this.publishing)
    .accessibilityText(this.text(label))
    .onClick(onClick)
  }

  @Builder
  private ImageGalleryButton(): void {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph($r('sys.symbol.picture'))
        .fontSize(25)
        .fontColor([this.accentColor])
        .foregroundFilter(ComponentHdrHighlight.filter(this.getUIContext(), this.componentHdrEnabled && !this.publishing, this.componentHdrRatio));
    }
    .width(48)
    .height(48)
    .backgroundColor(Color.Transparent)
    .enabled(!this.publishing && this.composeOptions.pollChoices.length === 0)
    .accessibilityText(this.text($r('app.string.compose_add_images')))
    .bindMenu(this.ImageGalleryMenu)
  }

  @Builder
  private GifButton(): void {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph($r('sys.symbol.gif'))
        .fontSize(25)
        .fontColor([this.accentColor])
        .foregroundFilter(ComponentHdrHighlight.filter(this.getUIContext(), this.componentHdrEnabled && !this.publishing, this.componentHdrRatio));
    }
    .width(48)
    .height(48)
    .backgroundColor(Color.Transparent)
    .enabled(!this.publishing && this.composeOptions.pollChoices.length === 0)
    .accessibilityText(this.text($r('app.string.compose_add_gif')))
    .bindMenu(this.GifMenu)
  }

  @Builder
  private CameraButton(): void {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph($r('sys.symbol.camera'))
        .fontSize(25)
        .fontColor([this.accentColor])
        .foregroundFilter(ComponentHdrHighlight.filter(this.getUIContext(), this.componentHdrEnabled && !this.publishing, this.componentHdrRatio));
    }
    .width(48)
    .height(48)
    .backgroundColor(Color.Transparent)
    .enabled(!this.publishing && this.composeOptions.pollChoices.length === 0)
    .accessibilityText(this.text($r('app.string.compose_take_photo')))
    .bindMenu(this.CameraMenu)
  }

  @Builder
  private VideoGalleryButton(): void {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph($r('sys.symbol.video'))
        .fontSize(25)
        .fontColor([this.accentColor])
        .foregroundFilter(ComponentHdrHighlight.filter(this.getUIContext(), this.componentHdrEnabled && !this.publishing, this.componentHdrRatio));
    }
    .width(48)
    .height(48)
    .backgroundColor(Color.Transparent)
    .enabled(!this.publishing && this.composeOptions.pollChoices.length === 0)
    .accessibilityText(this.text($r('app.string.compose_add_video')))
    .bindMenu(this.VideoGalleryMenu)
  }

  @Builder
  private ReplyTargetPost(): void {
    if (this.parentTweet !== null) {
      Column() {
        TweetCard({
          tweet: this.parentTweet,
          showActions: false,
          videoFeedEnabled: false,
          naturalVideoSize: true
        });
      }
      .width('100%')
      .padding({ start: LengthMetrics.vp(10), end: LengthMetrics.vp(6) })
      .onAreaChange((oldArea: Area, newArea: Area): void => {
        this.onReplyTargetAreaChanged(oldArea, newArea);
      })
      .opacity(this.replyTargetPositioned ? 1 : 0);
    }
  }

  @Builder
  private PrimaryComposeTools(): void {
    Row({ space: 2 }) { this.ImageGalleryButton(); this.GifButton(); }
  }

  @Builder
  private ExtraComposeTools(): void {
      Row({ space: 4 }) {
        this.CameraButton();
        this.VideoGalleryButton();
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.arrow_counterclockwise'))
            .fontSize(22)
            .fontColor([this.undoPublishEnabled ? this.accentColor : $r('app.color.text_secondary')]);
        }
        .width(48)
        .height(48)
        .backgroundColor(Color.Transparent)
        .enabled(!this.publishing && !this.isLongPost() && this.communityId.length === 0 && !this.composeOptions.hasSettings())
        .accessibilityText(this.text(this.undoPublishEnabled ? $r('app.string.compose_undo_enabled') :
          $r('app.string.compose_undo_disabled')))
        .onClick((): void => {
          this.undoPublishEnabled = !this.undoPublishEnabled;
          this.scheduleDraftSave();
        });
      }
  }

  private insertEmoji(emoji: string): void {
    const start: number = Math.max(0, Math.min(this.draft.length, this.selectionStart));
    const end: number = Math.max(start, Math.min(this.draft.length, this.selectionEnd));
    this.draft = this.draft.substring(0, start) + emoji + this.draft.substring(end);
    this.selectionStart = start + emoji.length; this.selectionEnd = this.selectionStart;
    chatEmojiStore.used(getContext(this) as common.UIAbilityContext, emoji);
    this.scheduleDraftSave();
    setTimeout((): void => {
      if (this.composerPageActive) {
        this.getUIContext().getFocusController().requestFocus('composer-main-input');
        this.editorController.caretPosition(this.selectionStart);
      }
    }, 180);
  }

  @Builder
  private FixedPickerBar(): void {
    Column() {
      ComposerTools({ options: $composeOptions, disabled: this.publishing, accentColor: this.accentColor,
        hasMedia: this.imageUris.length > 0 || this.gifUri.length > 0 || this.videoUri.length > 0,
        community: this.communityId.length > 0, isReply: this.isReply(),
        leadingActions: (): void => this.PrimaryComposeTools(), trailingActions: (): void => this.ExtraComposeTools(),
        onChange: (): void => {
          if (this.composeOptions.hasSettings()) { this.undoPublishEnabled = false; }
          this.scheduleDraftSave();
        }, onOpen: (): void => this.editorController.stopEditing(),
        onEmoji: (emoji: string): void => this.insertEmoji(emoji) });
      Blank().height(this.navigationIndicatorHeight);
    }
    .width('100%')
    .onAreaChange((_old: Area, area: Area): void => {
      const height: number = Number(area.height);
      if (height > 0 && Math.abs(this.pickerAreaHeight - height) > 1) { this.pickerAreaHeight = height; }
    })
    .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN);
  }

  @Builder
  private ContentBuilder(): void {
    Stack() {
      Column() {
        CollaborationServiceStateDialog({
          onState: (stateCode: number, bufferType: string, buffer: ArrayBuffer): void => {
            this.handleRemoteMedia(stateCode, bufferType, buffer);
          }
        })
        Stack({ alignContent: Alignment.Bottom }) {
          Scroll(this.composerScroller) {
            Stack({ alignContent: Alignment.TopStart }) {
              Column() {
                if (this.parentTweet !== null) {
                  this.ReplyTargetPost();
                }
                if (this.publishError.length > 0) {
                  Text(this.publishError).fontFamily(this.appFontFamily)
                    .fontSize($r('sys.float.Body_M'))
                    .fontColor($r('app.color.danger'))
                    .width('100%')
                    .padding(12);
                }
                if (this.draftNotice.length > 0) {
                  Text(this.draftNotice).fontFamily(this.appFontFamily)
                    .fontSize($r('sys.float.Body_M'))
                    .fontColor($r('app.color.text_accent'))
                    .width('100%')
                    .padding({ left: 18, right: 18, top: 8 });
                }
                if (this.serverDraftId.length > 0) {
                  Button($r('app.string.compose_delete_server_draft'), { stateEffect: true })
                    .fontSize($r('sys.float.Body_S'))
                    .fontColor($r('app.color.danger'))
                    .backgroundColor(Color.Transparent)
                    .enabled(!this.publishing && !this.serverDraftSyncing)
                    .margin({ start: LengthMetrics.vp(12), top: LengthMetrics.vp(4) })
                    .onClick((): void => {
                      this.confirmDeleteServerDraft();
                    });
                }
                Blank().height(this.desktop() ? 0 : this.statusBarHeight + COMPOSER_HEADER_HEIGHT);
                Row({ space: 12 }) {
                  this.Avatar();
                  Column({ space: 8 }) {
                    if (this.communityName.length > 0) {
                      Text(this.text($r('app.string.community_posting_in')) + this.communityName).fontFamily(this.appFontFamily)
                        .fontSize($r('sys.float.Body_L'))
                        .fontColor($r('app.color.text_accent'))
                        .width('100%');
                      Text($r('app.string.community_post_visibility')).fontFamily(this.appFontFamily)
                        .fontSize($r('sys.float.Body_S'))
                        .fontColor($r('app.color.text_secondary'))
                        .width('100%');
                    }
                    if (this.isReply()) {
                      Text(this.text($r('app.string.compose_replying_to')) + this.replyToUser).fontFamily(this.appFontFamily)
                        .fontSize($r('sys.float.Body_L'))
                        .fontColor($r('app.color.text_secondary'))
                        .width('100%');
                    }
                    TextArea({
                      placeholder: this.isReply() ?
                        $r('app.string.post_detail_reply_placeholder') : this.composeOptions.pollChoices.length > 0 ?
                        $r('app.string.compose_poll_question') : $r('app.string.compose_placeholder'),
                      text: this.draft, controller: this.editorController
                    }).fontFamily(this.appFontFamily)
                      .id('composer-main-input')
                      .keyboardAppearance(KeyboardAppearance.IMMERSIVE)
                      .enabled(!this.publishing)
                      .width('100%')
                      .height(this.compactWindow ? $r('app.float.compact_window_editor_height') :
                        (this.composeOptions.pollChoices.length > 0 ? 80 : COMPOSER_TEXT_AREA_HEIGHT))
                      .backgroundColor(Color.Transparent)
                      .fontSize($r('sys.float.Title_M'))
                      .fontColor($r('app.color.text_primary'))
                      .placeholderColor($r('app.color.text_secondary'))
                      .enterKeyType(EnterKeyType.Send)
                      .onTextSelectionChange((start: number, end: number): void => {
                        this.selectionStart = start; this.selectionEnd = end;
                      })
                      .onChange((value: string): void => {
                        this.draft = value;
                        this.scheduleDraftSave();
                      })
                      .onSubmit((enterKey: EnterKeyType, event: SubmitEvent): void => {
                        event.keepEditableState();
                      });
                    if (this.composeOptions.pollChoices.length > 0) {
                      ComposerPollEditor({ options: $composeOptions, disabled: this.publishing,
                        accentColor: this.accentColor, onChange: (): void => this.scheduleDraftSave() });
                    }
                    if (this.imageGridItemCount() > 0) {
                      this.ImageGrid();
                    } else if (this.videoUri.length > 0) {
                      this.VideoAttachment((): void => {
                        this.removeVideo();
                      });
                    }
                    Row() {
                      Blank();
                      Text(this.characterCountLabel()).fontFamily(this.appFontFamily)
                        .fontSize($r('sys.float.Body_M'))
                        .fontColor(this.draft.length > this.maxCharacters() ?
                          $r('app.color.danger') : $r('app.color.text_secondary'))
                        .accessibilityText(this.text($r('app.string.compose_character_count')) +
                          this.characterCountLabel());
                    }
                    .width('100%');
                    if (this.isLongPost()) {
                      Text($r('app.string.compose_long_post_active')).fontFamily(this.appFontFamily)
                        .fontSize($r('sys.float.Body_S'))
                        .fontColor($r('app.color.text_accent'))
                        .width('100%');
                    }
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start);
                }
                .width('100%')
                .padding({ left: 18, right: 18, top: 22, bottom: 12 })
                .alignItems(VerticalAlign.Top)
                .onAreaChange((oldArea: Area, newArea: Area): void => {
                  this.onReplyEditorAreaChanged(oldArea, newArea);
                });
                Blank().height(this.fixedPickerAreaHeight());
              }
              .width('100%')
              .constraintSize({ minHeight: this.minimumScrollContentHeight() });
              if (this.parentTweet !== null && this.replyEditorTop > 0 && this.replyTargetPositioned) {
                Column()
                  .width(2)
                  .height(this.replyThreadLineHeight())
                  .backgroundColor($r('app.color.divider'))
                  .borderRadius(1)
                  .position({ x: 44, y: this.replyThreadLineTop() })
                  .hitTestBehavior(HitTestMode.None);
              }
            }
          }
          .width('100%')
          .height('100%')
          .scrollBar(BarState.Off)
          .onAreaChange((oldArea: Area, newArea: Area): void => {
            this.onComposerViewportAreaChanged(oldArea, newArea);
          });
          this.FixedPickerBar();
        }
        .width('100%')
        .layoutWeight(1);
      }
      .width('100%')
      .height('100%')
      .backgroundColor(pageSurfaceColor(this.themeDisplayMode, this.themeDarkSurface));
    }
    .width('100%')
    .height('100%')
    .backgroundColor(pageSurfaceColor(this.themeDisplayMode, this.themeDarkSurface));
  }

  build(): void {
    HdsNavDestination() {
      if (this.desktop()) {
        Stack({ alignContent: Alignment.Center }) {
        Column() {
          this.Header()
          Column() { this.ContentBuilder() }.width('100%').layoutWeight(1)
        }.width('100%').constraintSize({ maxWidth: $r('app.float.desktop_modal_width') })
          .height(Math.min(640, this.desktopWindowHeight - 48))
          .backgroundColor(pageSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
          .borderRadius($r('app.float.desktop_card_radius')).clip(true)
        }.width('100%').height('100%')
      } else { this.ContentBuilder(); }
    }
    .scale({ x: this.pageMotion.scale, y: this.pageMotion.scale })
    .opacity(this.pageMotion.opacity)
    .onReady((context: NavDestinationContext): void => { this.pageMotion.attach(context); })
    .systemTransition(pageSystemTransition(this.pageTransitionMode))
    .mode(this.desktop() ? NavDestinationMode.DIALOG : NavDestinationMode.STANDARD)
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .hideTitleBar(this.desktop())
    .hideBackButton(true)
    .titleBar({
      avoidLayoutSafeArea: true,
      content: {
        stackBuilder: (): void => this.TitleBarContent(),
        divider: { showType: DividerShowType.OFF }
      },
      style: destinationTitleBarStyle(ScrollEffectType.IMMERSIVE_GRADIENT_BLUR,
        this.themeDisplayMode, this.themeDarkSurface, TITLE_BAR_STYLE_BLUR)
    })
    .bindToScrollable([this.composerScroller])
    .onBackPressed((): boolean => {
      if (!this.publishing) {
        ResponsiveLayout.closeContentDestination(this.pageStack);
      }
      return true;
    })
    .onShown((): void => {
      this.consumeGifSearchSelection();
    })
    .backgroundColor(this.desktop() ? '#88000000' : pageSurfaceColor(this.themeDisplayMode, this.themeDarkSurface));
  }
}
