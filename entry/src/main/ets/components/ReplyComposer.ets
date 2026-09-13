// Reusable reply capsule and its full-screen editor destination.  Keeping both
// builders here makes the compact entry point reusable by every detail page.
import common from '@ohos.app.ability.common';
import promptAction from '@ohos.promptAction';
import { deviceInfo } from '@kit.BasicServicesKit';
import { picker } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { KeyboardAvoidMode, uiMaterial } from '@kit.ArkUI';
import {
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  HdsTabs,
  hdsMaterial
} from '@kit.UIDesignKit';
import { XApiClient } from '../services/XApiClient';
import { authStore } from '../services/AuthStore';
import type { UserProfile } from '../models/Tweet';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';

export interface ReplyComposerContext {
  replyToId: string;
  replyToUser: string;
  avatarUrl: string;
  avatarName: string;
  avatarColor: string;
  accentColor: string;
}

export interface ReplyComposerRouteParam {
  replyToId: string;
  replyToUser: string;
  avatarUrl: string;
  avatarName: string;
  avatarColor: string;
  initialText: string;
  imageUri: string;
  gifUri: string;
}

@Builder
export function ReplyComposerCapsuleBuilder(
  context: ReplyComposerContext,
  onExpand: (text: string, imageUri: string, gifUri: string) => void
): void {
  if (deviceInfo.apiAvailable('26.0.0')) {
    HdsTabs() {
      TabContent() {
      }
      .tabBar(ReplyComposerCapsuleContent(context, onExpand, true));
    }
    .scrollable(false)
    .barPosition(BarPosition.End)
    .barMode(BarMode.Fixed)
    .barHeight('100%')
    .barWidth('100%')
    .barFloatingStyle({
      lightColor: context.accentColor,
      systemMaterialEffect: {
        materialType: hdsMaterial.MaterialType.ADAPTIVE,
        materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
      },
      thermoCtrl: true
    })
    .width('100%')
    .height(64);
  } else {
    ReplyComposerCapsuleContent(context, onExpand, false);
  }
}

@Builder
function ReplyComposerCapsuleContent(
  context: ReplyComposerContext,
  onExpand: (text: string, imageUri: string, gifUri: string) => void,
  materialEnabled: boolean
): void {
  ReplyComposerCapsule({
    context: context,
    accentColor: context.accentColor,
    materialEnabled: materialEnabled,
    onExpand: onExpand
  });
}

@Builder
export function ReplyComposerBuilder(): void {
  ReplyComposerPage();
}

@Component
export struct ReplyComposerCapsule {
  @Prop context: ReplyComposerContext;
  @Prop accentColor: string = '#007DFF';
  @Prop materialEnabled: boolean = false;
  onExpand: (text: string, imageUri: string, gifUri: string) => void = () => {
  };
  @State private draft: string = '';
  @State private imageUri: string = '';
  @State private gifUri: string = '';
  @State private resolvedAvatarUrl: string = '';
  @State private resolvedAvatarName: string = '';
  private api: XApiClient = new XApiClient();

  aboutToAppear(): void {
    this.resolvedAvatarUrl = this.context.avatarUrl;
    this.resolvedAvatarName = this.context.avatarName;
    this.loadCurrentUserAvatar();
  }

  private async loadCurrentUserAvatar(): Promise<void> {
    const abilityContext: common.UIAbilityContext =
      this.getUIContext().getHostContext() as common.UIAbilityContext;
    await authStore.load(abilityContext);
    if (!authStore.isSignedIn()) {
      return;
    }
    this.api.setToken(authStore.getToken());
    this.api.setUser(authStore.getUserId());
    const profile: UserProfile | null = await this.api.profile();
    if (profile === null) {
      return;
    }
    if (profile.avatarUrl !== undefined && profile.avatarUrl.length > 0) {
      this.resolvedAvatarUrl = profile.avatarUrl;
    }
    if (profile.name.length > 0) {
      this.resolvedAvatarName = profile.name;
    }
  }

  private capsuleMaterial(): uiMaterial.Material | undefined {
    if (!this.materialEnabled || !deviceInfo.apiAvailable('26.0.0')) {
      return undefined;
    }
    return new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.ULTRA_THIN,
      interactive: true,
      applyShadow: false,
      colorInvert: true,
      lightEffect: { color: this.accentColor }
    });
  }

  private controlMaterial(): uiMaterial.Material | undefined {
    if (!this.materialEnabled || !deviceInfo.apiAvailable('26.0.0')) {
      return undefined;
    }
    return new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.THIN,
      interactive: true,
      applyShadow: false,
      colorInvert: true,
      lightEffect: { color: this.accentColor }
    });
  }

  private async selectImage(): Promise<void> {
    try {
      const options: photoAccessHelper.PhotoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1;
      const photoPicker: photoAccessHelper.PhotoViewPicker = new photoAccessHelper.PhotoViewPicker();
      const result: photoAccessHelper.PhotoSelectResult = await photoPicker.select(options);
      if (result.photoUris.length > 0) {
        this.imageUri = result.photoUris[0];
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
        this.gifUri = result[0];
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
        .borderRadius(20)
        .clip(true)
    } else {
      Text(this.resolvedAvatarName.substring(0, 1).toUpperCase())
        .width(40)
        .height(40)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_on_primary'))
        .backgroundColor(this.context.avatarColor)
        .borderRadius(20)
        .textAlign(TextAlign.Center)
    }
  }

  @Builder
  private AvatarButton(): void {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      this.Avatar();
    }
    .width(42)
    .height(42)
    .padding(1)
    .backgroundColor(this.materialEnabled ? Color.Transparent : $r('app.color.bg_field'))
    .borderRadius(21)
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
    .backgroundColor(this.materialEnabled ? Color.Transparent : $r('app.color.bg_field'))
    .borderRadius(21)
    .clip(true)
    .onClick(onClick)
    .systemMaterial(this.controlMaterial())
  }

  build(): void {
    Row({ space: 6 }) {
      this.AvatarButton();
      TextInput({ placeholder: $r('app.string.post_detail_reply_placeholder'), text: this.draft })
        .layoutWeight(1)
        .height(48)
        .backgroundColor(this.materialEnabled ? Color.Transparent : $r('app.color.bg_field'))
        .borderRadius(24)
        .clip(true)
        .fontSize(17)
        .fontColor($r('sys.color.font_primary'))
        .placeholderColor($r('sys.color.font_secondary'))
        .onChange((value: string): void => {
          this.draft = value;
        })
        .systemMaterial(this.controlMaterial());
      this.ToolButton($r('sys.symbol.picture'), (): void => {
        this.selectImage();
      });
      this.ToolButton($r('sys.symbol.gif'), (): void => {
        this.selectGif();
      });
      this.ToolButton($r('sys.symbol.arrow_up_left_and_arrow_down_right'), (): void => {
        this.onExpand(this.draft, this.imageUri, this.gifUri);
      });
    }
    .width('100%')
    .height(64)
    .padding({ left: 10, right: 8 })
    .backgroundColor(this.materialEnabled ? Color.Transparent : $r('app.color.bg_field'))
    .border({ width: this.materialEnabled ? 0 : 1, color: $r('app.color.divider') })
    .borderRadius(32)
    .clip(true)
    .systemMaterial(this.capsuleMaterial())
  }
}

@Component
export struct ReplyComposerPage {
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp('harmonyx.status_bar_height') statusBarHeight: number =
    AppStorage.get<number>('harmonyx.status_bar_height') ?? 0;
  @StorageProp('harmonyx.navigation_indicator_height') navigationIndicatorHeight: number =
    AppStorage.get<number>('harmonyx.navigation_indicator_height') ?? 0;
  @State private replyToId: string = '';
  @State private replyToUser: string = '';
  @State private avatarUrl: string = '';
  @State private avatarName: string = '';
  @State private avatarColor: string = '#007DFF';
  @StorageLink('harmonyx.accent_color') accentColor: string = '#007DFF';
  @State private draft: string = '';
  @State private imageUri: string = '';
  @State private gifUri: string = '';
  @State private publishing: boolean = false;
  private api: XApiClient = new XApiClient();

  aboutToAppear(): void {
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE);
    setTimeout((): void => {
      this.loadRouteParam();
      this.loadCurrentUserAvatar();
    }, 50);
  }

  aboutToDisappear(): void {
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.OFFSET);
  }

  private async loadCurrentUserAvatar(): Promise<void> {
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    await authStore.load(context);
    if (!authStore.isSignedIn()) {
      return;
    }
    this.api.setToken(authStore.getToken());
    this.api.setUser(authStore.getUserId());
    const profile: UserProfile | null = await this.api.profile();
    if (profile === null) {
      return;
    }
    if (profile.avatarUrl !== undefined && profile.avatarUrl.length > 0) {
      this.avatarUrl = profile.avatarUrl;
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
    this.avatarUrl = param.avatarUrl;
    this.avatarName = param.avatarName;
    this.avatarColor = param.avatarColor;
    this.draft = param.initialText;
    this.imageUri = param.imageUri;
    this.gifUri = param.gifUri;
  }

  private text(resource: Resource): string {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    return context.resourceManager.getStringSync(resource);
  }

  private async selectImage(): Promise<void> {
    try {
      const options: photoAccessHelper.PhotoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1;
      const photoPicker: photoAccessHelper.PhotoViewPicker = new photoAccessHelper.PhotoViewPicker();
      const result: photoAccessHelper.PhotoSelectResult = await photoPicker.select(options);
      if (result.photoUris.length > 0) {
        this.imageUri = result.photoUris[0];
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
        this.gifUri = result[0];
      }
    } catch (error) {
    }
  }

  private removeImage(): void {
    this.imageUri = '';
  }

  private removeGif(): void {
    this.gifUri = '';
  }

  private async publish(): Promise<void> {
    const content: string = this.draft.trim();
    if (content.length === 0 || this.publishing) {
      return;
    }
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    await authStore.load(context);
    if (!authStore.isSignedIn()) {
      promptAction.showToast({ message: this.text($r('app.string.post_detail_sign_in')), duration: 2000 });
      return;
    }
    this.api.setToken(authStore.getToken());
    this.api.setUser(authStore.getUserId());
    this.publishing = true;
    const published: boolean = await this.api.postTweet(content, this.replyToId);
    this.publishing = false;
    if (published) {
      promptAction.showToast({ message: this.text($r('app.string.toast_published')), duration: 1500 });
      ResponsiveLayout.closeContentDestination(this.pageStack);
      return;
    }
    promptAction.showToast({ message: this.text($r('app.string.reply_publish_failed')), duration: 2000 });
  }

  @Builder
  private Avatar(): void {
    if (this.avatarUrl.length > 0) {
      Image(this.avatarUrl)
        .width(52)
        .height(52)
        .objectFit(ImageFit.Cover)
        .borderRadius(26)
        .clip(true)
    } else {
      Text(this.avatarName.substring(0, 1).toUpperCase())
        .width(52)
        .height(52)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_on_brand'))
        .backgroundColor(this.avatarColor)
        .borderRadius(26)
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
      .onClick((): void => {
        ResponsiveLayout.closeContentDestination(this.pageStack);
      });
      Blank();
      Button($r('app.string.action_reply'), { stateEffect: true })
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_on_brand'))
        .backgroundColor(this.accentColor)
        .borderRadius(24)
        .enabled(this.draft.trim().length > 0 && !this.publishing)
        .onClick((): void => {
          this.publish();
        });
    }
    .width('100%')
    .height(64)
    .padding({ left: 8, right: 12 });
  }

  @Builder
  private Attachment(uri: string, isGif: boolean, onRemove: () => void): void {
    Stack({ alignContent: Alignment.TopEnd }) {
      Image(uri)
        .width(112)
        .height(112)
        .objectFit(ImageFit.Cover)
        .borderRadius(12)
        .clip(true);
      if (isGif) {
        Text('GIF')
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_on_brand'))
          .backgroundColor(this.accentColor)
          .borderRadius(6)
          .padding({ left: 6, right: 6, top: 3, bottom: 3 })
          .margin(6);
      }
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.xmark'))
          .fontSize(13)
          .fontColor([$r('app.color.text_on_brand')]);
      }
      .width(26)
      .height(26)
      .backgroundColor($r('app.color.text_primary'))
      .margin(6)
      .onClick(onRemove);
    }
  }

  @Builder
  private ToolbarButton(symbol: Resource, onClick: () => void): void {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph(symbol)
        .fontSize(25)
        .fontColor([this.accentColor]);
    }
    .width(48)
    .height(48)
    .backgroundColor(Color.Transparent)
    .onClick(onClick)
  }

  @Builder
  private ContentBuilder(): void {
    Column() {
      this.Header();
      Divider().color($r('app.color.divider'));
      Row({ space: 12 }) {
        this.Avatar();
        Column({ space: 8 }) {
          Text(this.text($r('app.string.compose_replying_to')) + this.replyToUser)
            .fontSize(16)
            .fontColor($r('app.color.text_secondary'))
            .width('100%');
          TextArea({ placeholder: $r('app.string.post_detail_reply_placeholder'), text: this.draft })
            .layoutWeight(1)
            .width('100%')
            .backgroundColor(Color.Transparent)
            .fontSize(22)
            .fontColor($r('app.color.text_primary'))
            .placeholderColor($r('app.color.text_secondary'))
            .enterKeyType(EnterKeyType.Send)
            .onChange((value: string): void => {
              this.draft = value;
            })
            .onSubmit((enterKey: EnterKeyType, event: SubmitEvent): void => {
              event.keepEditableState();
            });
          Row({ space: 10 }) {
            if (this.imageUri.length > 0) {
              this.Attachment(this.imageUri, false, (): void => {
                this.removeImage();
              });
            }
            if (this.gifUri.length > 0) {
              this.Attachment(this.gifUri, true, (): void => {
                this.removeGif();
              });
            }
          }
          .width('100%');
        }
        .layoutWeight(1)
        .height('100%')
        .alignItems(HorizontalAlign.Start);
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: 18, right: 18, top: 22, bottom: 12 })
      .alignItems(VerticalAlign.Top);
      Divider().color($r('app.color.divider'));
      Row({ space: 4 }) {
        this.ToolbarButton($r('sys.symbol.picture'), (): void => {
          this.selectImage();
        });
        this.ToolbarButton($r('sys.symbol.camera'), (): void => {
          this.selectImage();
        });
        this.ToolbarButton($r('sys.symbol.gif'), (): void => {
          this.selectGif();
        });
        this.ToolbarButton($r('sys.symbol.list_bullet'), (): void => {
        });
        this.ToolbarButton($r('sys.symbol.location_up'), (): void => {
        });
        Blank();
      }
      .width('100%')
      .height(64)
      .padding({ left: 10, right: 10 });
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.statusBarHeight + 64, bottom: this.navigationIndicatorHeight })
    .backgroundColor($r('app.color.bg_page'));
  }

  build(): void {
    HdsNavDestination() {
      this.ContentBuilder();
    }
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .hideBackButton(true)
    .onBackPressed((): boolean => {
      ResponsiveLayout.closeContentDestination(this.pageStack);
      return true;
    })
    .titleBar({
      avoidLayoutSafeArea: true,
      content: { title: { mainTitle: '' } },
      style: {
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.IMMERSIVE,
          materialLevel: hdsMaterial.MaterialLevel.EXQUISITE
        }
      }
    })
    .backgroundColor($r('app.color.bg_page'));
  }
}
