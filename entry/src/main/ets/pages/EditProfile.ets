import { pageTextColor } from '../utils/ThemeColors';
import { appPageBackground } from '../components/PageBackgroundLayer';
import { pageCanvasColor, pageReadingSurfaceColor } from '../utils/ThemeColors';
import { STORAGE_KEY_PAGE_TRANSITION_MODE, DEFAULT_PAGE_TRANSITION_MODE } from '../services/PageTransitionSettingsStore';
import { pageSystemTransition, PageTransitionMotion } from '../utils/PageTransition';
import { common } from '@kit.AbilityKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { uiMaterial } from '@kit.ArkUI';
import { HdsNavDestination, HdsNavDestinationTitleMode, ScrollEffectType, TextStyleMode } from '@kit.UIDesignKit';
import promptAction from '@ohos.promptAction';
import { UserProfile } from '../models/Tweet';
import { NativeAccountRouteParam, NativeAccountSnapshot, NativeAccountField } from '../models/NativeAccount';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { ProfileEditDraft, profileEditService } from '../services/ProfileEditService';
import { nativeAccountService } from '../services/NativeAccountService';
import { xPrivateClient } from '../services/XPrivateClient';
import { ProxyAvatar } from '../components/ProxyAvatar';
import { ProxyMediaImage } from '../components/ProxyMediaImage';
import { ProfileEditorField } from '../components/ProfileEditorField';
import { fieldSurfaceColor, pageSurfaceColor } from '../utils/ThemeColors';
import { destinationTitleBarStyle } from '../utils/DestinationTitleBar';
import { SystemMaterialUtil } from '../utils/SystemMaterial';
import { userAvatarRadius } from '../utils/UserIdentity';
import { materialModifier } from '../utils/SystemMaterial';

export interface EditProfileRouteParam { profile: UserProfile; }

@Builder
export function EditProfileBuilder(): void { EditProfile(); }

@Component
export struct EditProfile {
  @StorageProp('harmonyx.page_background') private pageBackgroundValue: string = '';
  @State private pageMotion: PageTransitionMotion = new PageTransitionMotion();
  @StorageProp(STORAGE_KEY_PAGE_TRANSITION_MODE) private pageTransitionMode: string = DEFAULT_PAGE_TRANSITION_MODE;
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp('harmonyx.status_bar_height') private topInset: number = 0;
  @StorageProp('harmonyx.navigation_indicator_height') private bottomInset: number = 0;
  @StorageProp('harmonyx.display_mode') private displayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private darkSurface: string = '';
  @StorageProp('harmonyx.title_bar_style_mode') private titleBarStyleMode: number = 0;
  @StorageLink('harmonyx.accent_color') private accentColor: string = '#007DFF';
  @State private draft: ProfileEditDraft | null = null;
  @State private saving: boolean = false;
  @State private picking: boolean = false;
  @State private failure: string = '';
  @State private birthSummary: string = '';
  @State private birthPrivacy: string = '';
  @State private birthLoading: boolean = false;
  private generation: number = -1;
  private alive: boolean = true;
  private leaving: boolean = false;
  private scroller: Scroller = new Scroller();
  private pageMaterial: uiMaterial.Material | undefined =
    SystemMaterialUtil.immersiveMaterial(2, false, true, true, undefined);

  private text(resource: Resource): string { return getContext(this).resourceManager.getStringSync(resource); }

  aboutToAppear(): void {
    this.alive = true;
    xPrivateClient.load(getContext(this) as common.UIAbilityContext);
    this.generation = xPrivateClient.sessionGeneration();
    const params: EditProfileRouteParam[] = this.pageStack.getParamByName('EditProfile') as EditProfileRouteParam[];
    const param: EditProfileRouteParam | undefined = params.length > 0 ? params[params.length - 1] : undefined;
    if (param !== undefined && param.profile.id === xPrivateClient.viewerId()) {
      this.draft = new ProfileEditDraft(param.profile);
      void this.loadBirthdate();
    } else { this.failure = this.text($r('app.string.profile_editor_account_changed')); }
  }

  aboutToDisappear(): void { this.alive = false; }

  private currentAccount(): boolean {
    return this.draft !== null && xPrivateClient.isSignedIn() &&
      xPrivateClient.viewerId() === this.draft.profile.id && xPrivateClient.sessionGeneration() === this.generation;
  }

  private canSave(): boolean {
    return !this.saving && !this.picking && this.currentAccount() && this.draft !== null &&
      this.draft.valid() && this.draft.hasChanges();
  }

  private async back(): Promise<void> {
    if (this.saving || this.picking || this.leaving) { return; }
    this.leaving = true;
    try {
      if (this.draft !== null && this.draft.hasChanges()) {
        const answer: promptAction.ShowDialogSuccessResponse = await promptAction.showDialog({
          title: this.text($r('app.string.profile_editor_unsaved_title')),
          message: this.text($r('app.string.profile_editor_unsaved_message')),
          buttons: [{ text: this.text($r('app.string.profile_editor_keep_editing')), color: this.accentColor },
            { text: this.text($r('app.string.profile_editor_discard')), color: this.accentColor }]
        });
        if (answer.index !== 1) { return; }
      }
      this.pageStack.pop();
    } finally { this.leaving = false; }
  }

  private async selectPhoto(banner: boolean): Promise<void> {
    if (this.picking || this.saving || !this.currentAccount()) { return; }
    this.picking = true;
    try {
      const options: photoAccessHelper.PhotoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1;
      const result: photoAccessHelper.PhotoSelectResult = await new photoAccessHelper.PhotoViewPicker().select(options);
      if (!this.alive || !this.currentAccount() || result.photoUris.length === 0 || this.draft === null) { return; }
      if (banner) { this.draft.bannerUri = result.photoUris[0]; this.draft.bannerApplied = false; }
      else { this.draft.avatarUri = result.photoUris[0]; this.draft.avatarApplied = false; }
      this.failure = '';
    } catch (error) {
      // Cancellation leaves the existing photo and other draft fields intact.
    } finally { this.picking = false; }
  }

  private async save(): Promise<void> {
    if (!this.canSave() || this.draft === null) { return; }
    this.saving = true; this.failure = '';
    try {
      await profileEditService.save(this.draft, this.generation);
      if (!this.alive || !this.currentAccount()) { return; }
      promptAction.showToast({ message: this.text($r('app.string.profile_edit_saved')), duration: 1600 });
      this.pageStack.pop();
    } catch (error) {
      if (!this.alive) { return; }
      const reason: string = (error as Error).message;
      this.failure = this.text(reason === 'account_changed' ? $r('app.string.profile_editor_account_changed') :
        reason === 'profile_refresh_failed' ? $r('app.string.profile_editor_confirm_failed') :
        this.draft.awaitingRefresh ? $r('app.string.profile_editor_partial') : $r('app.string.profile_edit_failed'));
    } finally { this.saving = false; }
  }

  private birthValue(fields: NativeAccountField[], key: string): string {
    const field: NativeAccountField | undefined = fields.find((item: NativeAccountField): boolean => item.id === key);
    return field?.value ?? '';
  }

  private birthVisibility(fields: NativeAccountField[], key: string): string {
    const field: NativeAccountField | undefined = fields.find((item: NativeAccountField): boolean => item.id === key);
    const choice = field?.choices.find((item): boolean => item.value === field.value);
    if (choice === undefined) { return ''; }
    return typeof choice.label === 'string' ? choice.label : this.text(choice.label);
  }

  private async loadBirthdate(): Promise<void> {
    if (!this.currentAccount()) { return; }
    this.birthLoading = true;
    try {
      const snapshot: NativeAccountSnapshot = await nativeAccountService.load('age');
      if (!this.alive || !this.currentAccount()) { return; }
      const year: string = this.birthValue(snapshot.fields, 'birthdate_year');
      const month: string = this.birthValue(snapshot.fields, 'birthdate_month');
      const day: string = this.birthValue(snapshot.fields, 'birthdate_day');
      this.birthSummary = year.length > 0 && month.length > 0 && day.length > 0 ? year + '/' + month + '/' + day :
        this.text($r('app.string.profile_editor_birthdate_empty'));
      const visibility: string = this.birthVisibility(snapshot.fields, 'birthdate_visibility');
      const yearVisibility: string = this.birthVisibility(snapshot.fields, 'birthdate_year_visibility');
      this.birthPrivacy = visibility.length > 0 && yearVisibility.length > 0 ?
        getContext(this).resourceManager.getStringSync($r('app.string.profile_editor_birthdate_privacy').id, visibility, yearVisibility) : '';
    } catch (error) {
      if (this.alive) { this.birthSummary = this.text($r('app.string.profile_editor_birthdate_manage')); }
    } finally { this.birthLoading = false; }
  }

  private openBirthdate(): void {
    if (this.saving || !this.currentAccount()) { return; }
    const param: NativeAccountRouteParam = { feature: 'age' };
    this.pageStack.pushPath({ name: 'NativeAccount', param: param,
      onPop: (): void => { void this.loadBirthdate(); } });
  }

  private avatarSize(): number {
    return this.getUIContext().px2vp(getContext(this).resourceManager.getNumber($r('app.float.profile_editor_avatar_size').id));
  }

  @Builder
  private Photos(): void {
    Column() {
      Stack() {
        Column().width('100%').height('100%').backgroundColor(this.accentColor)
        if ((this.draft?.bannerUri || this.draft?.profile.bannerUrl || '').length > 0) {
          ProxyMediaImage({ url: this.draft?.bannerUri || this.draft?.profile.bannerUrl || '', fillParent: true })
        }
        Column().width('100%').height('100%').backgroundColor($r('app.color.profile_editor_image_shade'))
        SymbolGlyph($r('sys.symbol.camera_badge_plus')).fontSize(34).fontColor([$r('app.color.text_on_brand')])
      }.width('100%').aspectRatio(3).clip(true).enabled(!this.saving && !this.picking)
        .accessibilityText($r('app.string.profile_editor_choose_banner')).accessibilityLevel('yes')
        .onClick((): void => { void this.selectPhoto(true); })
      Row() {
        Stack() {
          ProxyAvatar({ url: this.draft?.avatarUri || this.draft?.profile.avatarUrl || '',
            avatarSize: this.avatarSize(), radius: this.avatarSize() / 2,
            verifiedType: this.draft?.profile.verifiedType ?? '', avatarShape: this.draft?.profile.avatarShape ?? '',
            fallbackText: (this.draft?.name ?? '').substring(0, 1), fallbackColor: this.accentColor })
          Column().width('100%').height('100%').backgroundColor($r('app.color.profile_editor_image_shade'))
          SymbolGlyph($r('sys.symbol.camera_badge_plus')).fontSize(30).fontColor([$r('app.color.text_on_brand')])
        }.width(this.avatarSize()).height(this.avatarSize())
          .borderRadius(userAvatarRadius(this.avatarSize(), this.avatarSize() / 2,
            this.draft?.profile.verifiedType ?? '', this.draft?.profile.avatarShape ?? '')).clip(true)
          .enabled(!this.saving && !this.picking).accessibilityText($r('app.string.profile_editor_choose_avatar'))
          .accessibilityLevel('yes').onClick((): void => { void this.selectPhoto(false); })
        Blank()
      }.width('100%').padding({ left: 20, right: 20 }).margin({ top: -this.avatarSize() / 2, bottom: 18 })
    }.width('100%')
  }

  @Builder
  private Form(): void {
    Column() {
      this.Photos()
      Column() {
        ProfileEditorField({ label: $r('app.string.profile_edit_name'), value: this.draft?.name ?? '', limit: 50,
          disabled: this.saving, onValue: (value: string): void => { if (this.draft !== null) { this.draft.name = value; } } })
        ProfileEditorField({ label: $r('app.string.profile_edit_bio'), value: this.draft?.bio ?? '', limit: 160, multiline: true,
          disabled: this.saving, onValue: (value: string): void => { if (this.draft !== null) { this.draft.bio = value; } } })
        ProfileEditorField({ label: $r('app.string.xnative_location'), value: this.draft?.location ?? '', limit: 30,
          disabled: this.saving, onValue: (value: string): void => { if (this.draft !== null) { this.draft.location = value; } } })
        ProfileEditorField({ label: $r('app.string.xnative_website'), value: this.draft?.website ?? '', limit: 100, website: true,
          disabled: this.saving, onValue: (value: string): void => { if (this.draft !== null) { this.draft.website = value; } } })
        Row({ space: 12 }) {
          Column({ space: 10 }) {
            Text($r('app.string.profile_editor_birthdate')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
              .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, fieldSurfaceColor(this.displayMode, this.darkSurface)))
            Text(this.birthSummary).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, fieldSurfaceColor(this.displayMode, this.darkSurface)))
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          if (this.birthLoading) { LoadingProgress().width(22).height(22).color(this.accentColor) }
          SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(15).fontColor([pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, fieldSurfaceColor(this.displayMode, this.darkSurface))])
        }.width('100%').padding(16).borderRadius(16)
          .backgroundColor(fieldSurfaceColor(this.displayMode, this.darkSurface))
          .enabled(!this.saving).onClick((): void => this.openBirthdate()).margin({ bottom: 12 })
        if (this.birthPrivacy.length > 0) {
          Text(this.birthPrivacy).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S')).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)).width('100%')
        }
        if (this.saving) { LoadingProgress().width(24).height(24).color(this.accentColor).margin({ top: 16 }) }
        if (this.failure.length > 0) {
          Text(this.failure).fontFamily(this.appFontFamily).fontSize(14).fontColor($r('app.color.like'))
            .width('100%').margin({ top: 18 }).accessibilityLevel('yes')
        }
      }.width('100%').padding({ left: 20, right: 20, bottom: this.bottomInset + 24 })
    }.width('100%').padding({ top: this.topInset + 74 })
  }

  build(): void {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        appPageBackground()
      Scroll(this.scroller) { this.Form() }
        .width('100%').height('100%').scrollBar(BarState.Off).align(Alignment.Top)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    
      }.width('100%').height('100%')
    }
    .scale({ x: this.pageMotion.scale, y: this.pageMotion.scale })
    .opacity(this.pageMotion.opacity)
    .onReady((context: NavDestinationContext): void => { this.pageMotion.attach(context); })
    .systemTransition(pageSystemTransition(this.pageTransitionMode))
      .titleMode(HdsNavDestinationTitleMode.MINI).hideBackButton(false)
      .bindToScrollable([this.scroller])
      .titleBar({ avoidLayoutSafeArea: true,
        content: { title: { mainTitle: $r('app.string.profile_edit_title') }, menu: { value: [
          { content: { label: $r('app.string.profile_edit_save'), type: TextStyleMode.NORMAL,
            isEnabled: this.canSave(), action: (): void => { void this.save(); } } }
        ] } },
        style: destinationTitleBarStyle(ScrollEffectType.GRADIENT_BLUR,
          this.displayMode, this.darkSurface, this.titleBarStyleMode) })
      .onBackPressed((): boolean => { void this.back(); return true; })
      .backgroundColor(pageCanvasColor(this.displayMode, this.darkSurface, this.pageBackgroundValue))
      .attributeModifier(materialModifier(this.pageMaterial))
  }
}
