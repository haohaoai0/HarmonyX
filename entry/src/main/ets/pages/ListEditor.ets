import { pageTextColor } from '../utils/ThemeColors';
import { appPageBackground } from '../components/PageBackgroundLayer';
import { pageCanvasColor, pageReadingSurfaceColor } from '../utils/ThemeColors';
import { STORAGE_KEY_PAGE_TRANSITION_MODE, DEFAULT_PAGE_TRANSITION_MODE } from '../services/PageTransitionSettingsStore';
import { pageSystemTransition, PageTransitionMotion } from '../utils/PageTransition';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import common from '@ohos.app.ability.common';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { uiMaterial } from '@kit.ArkUI';
import { HdsNavDestination, HdsNavDestinationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import promptAction from '@ohos.promptAction';
import { ListCover } from '../components/ListCover';
import type { ListRow } from '../models/Tweet';
import { xPrivateClient, XPrivateClient, XPrivateResult } from '../services/XPrivateClient';
import { XListParser } from '../services/XListParser';
import { copyList, listStateStore } from '../services/ListStateStore';
import { accountStore, XAccount } from '../services/AccountStore';
import { destinationTitleBarStyle } from '../utils/DestinationTitleBar';
import { pageSurfaceColor, fieldSurfaceColor } from '../utils/ThemeColors';
import type { ListEditorRouteParam, ListMembersRouteParam } from './Lists';
import { materialModifier } from '../utils/SystemMaterial';

@Builder
export function ListEditorBuilder(): void { ListEditor(); }

@Component
export struct ListEditor {
  @StorageProp('harmonyx.page_background') private pageBackgroundValue: string = '';
  @State private pageMotion: PageTransitionMotion = new PageTransitionMotion();
  @StorageProp(STORAGE_KEY_PAGE_TRANSITION_MODE) private pageTransitionMode: string = DEFAULT_PAGE_TRANSITION_MODE;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp('harmonyx.status_bar_height') statusBarHeight: number = 0;
  @StorageProp('harmonyx.navigation_indicator_height') navigationIndicatorHeight: number = 0;
  @StorageLink('harmonyx.accent_color') accentColor: string = '#007DFF';
  @StorageProp('harmonyx.display_mode') private themeDisplayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private themeDarkSurface: string = '';
  @StorageLink('harmonyx.title_bar_style_mode') titleBarStyleMode: number = 0;
  @State private name: string = '';
  @State private description: string = '';
  @State private isPrivate: boolean = false;
  @State private bannerUri: string = '';
  @State private bannerUrl: string = '';
  @State private hasCustomBanner: boolean = false;
  @State private removeBanner: boolean = false;
  @State private editing: boolean = false;
  @State private busy: boolean = false;
  @State private status: string = '';
  @State private bannerFailed: boolean = false;
  @State private unresolvedCreate: boolean = false;
  private savedRow: ListRow | null = null;
  private scroller: Scroller = new Scroller();
  private active: boolean = false;

  aboutToAppear(): void {
    this.active = true;
    xPrivateClient.load(getContext(this) as common.UIAbilityContext);
    const params: ListEditorRouteParam[] = this.pageStack.getParamByName('ListEditor') as ListEditorRouteParam[];
    if (params !== undefined && params.length > 0 && params[params.length - 1] !== undefined &&
      params[params.length - 1] !== null) {
      const row: ListRow | undefined = params[params.length - 1].row;
      if (row !== undefined) {
        this.savedRow = copyList(row); this.name = row.name; this.description = row.description;
        this.isPrivate = row.isPrivate; this.bannerUrl = row.bannerUrl;
        this.hasCustomBanner = row.hasCustomBanner === true; this.editing = true;
      }
    }
  }
  private text(resource: Resource): string {
    return (getContext(this) as common.UIAbilityContext).resourceManager.getStringSync(resource);
  }
  aboutToDisappear(): void { this.active = false; }
  private valid(): boolean {
    return this.name.trim().length > 0 && this.name.trim().length <= 25 && this.description.length <= 100;
  }
  private canEdit(): boolean {
    return xPrivateClient.isSignedIn() && (this.savedRow === null ||
      this.savedRow.ownerId === xPrivateClient.viewerId());
  }
  private async selectBanner(): Promise<void> {
    if (this.busy) { return; }
    try {
      const options: photoAccessHelper.PhotoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE; options.maxSelectNumber = 1;
      const picker: photoAccessHelper.PhotoViewPicker = new photoAccessHelper.PhotoViewPicker();
      const result: photoAccessHelper.PhotoSelectResult = await picker.select(options);
      if (result.photoUris.length > 0) { this.bannerUri = result.photoUris[0]; this.removeBanner = false; }
    } catch (error) {
      // Dismissing the system picker preserves the draft.
    }
  }
  private async save(): Promise<void> {
    if (this.busy || this.unresolvedCreate || !this.valid() || !this.canEdit()) { return; }
    this.busy = true; this.status = ''; this.bannerFailed = false;
    try {
      const current: ListRow | null = this.savedRow;
      const result: XPrivateResult = current === null ?
        await xPrivateClient.createList(this.name.trim(), this.description, this.isPrivate) :
        await xPrivateClient.updateList(current.id, this.name.trim(), this.description, this.isPrivate);
      if (!result.ok) {
        this.unresolvedCreate = current === null && (result.status <= 0 || result.status >= 500);
        this.status = this.unresolvedCreate ? this.text($r('app.string.list_create_unconfirmed')) : this.failure(result);
        return;
      }
      let row: ListRow | null = XListParser.detail(result.body, current === null ? '' : current.id);
      if (row === null && current !== null) { row = copyList(current); }
      if (row === null) {
        // Never retry a successful create automatically: that would duplicate
        // the user's list if the service changes its response shape.
        this.status = this.text($r('app.string.list_created_unresolved')); this.unresolvedCreate = true; return;
      }
      row.name = this.name.trim(); row.description = this.description; row.isPrivate = this.isPrivate;
      if (current !== null) {
        row.pinned = current.pinned; row.bannerUrl = current.bannerUrl; row.hasCustomBanner = current.hasCustomBanner;
        row.customBannerMediaId = current.customBannerMediaId;
      }
      const account: XAccount | null = accountStore.active(getContext(this) as common.UIAbilityContext);
      row.ownerId = xPrivateClient.viewerId();
      if (account !== null) {
        row.ownerName = account.displayName; row.ownerUsername = account.username; row.ownerAvatarUrl = account.avatarUrl;
      }
      this.savedRow = row; listStateStore.update(xPrivateClient.viewerId(), row);
      if (this.bannerUri.length > 0 || this.removeBanner) {
        let mediaId: string = '';
        if (!this.removeBanner) {
          const upload: XPrivateResult = await xPrivateClient.uploadListBanner(this.bannerUri);
          mediaId = upload.ok ? XPrivateClient.mediaIdFrom(upload.body) : '';
          if (mediaId.length === 0) {
            this.bannerFailed = true; this.status = this.text($r('app.string.list_banner_failed')) + ' · ' +
              XPrivateClient.explain(upload).substring(0, 120);
            return;
          }
        }
        const banner: XPrivateResult = await xPrivateClient.setListBanner(row.id, mediaId);
        if (!banner.ok) {
          this.bannerFailed = true; this.status = this.text($r('app.string.list_banner_failed'));
          if (banner.errorText !== 'list_banner_unconfirmed') {
            this.status += ' · ' + XPrivateClient.explain(banner).substring(0, 120);
          }
          return;
        }
        const updated: ListRow | null = XListParser.detail(banner.body, row.id);
        row.hasCustomBanner = !this.removeBanner;
        row.customBannerMediaId = mediaId;
        this.hasCustomBanner = row.hasCustomBanner;
        row.bannerUrl = this.removeBanner ? '' : updated !== null && updated.bannerUrl.length > 0 ?
          updated.bannerUrl : this.bannerUri;
        this.bannerUrl = row.bannerUrl; this.bannerUri = ''; this.removeBanner = false;
        if (row.bannerUrl.length > 0 && !row.bannerUrl.startsWith('https://') && !row.bannerUrl.startsWith('http://')) {
          const detail: XPrivateResult = await xPrivateClient.listDetail(row.id);
          const remote: ListRow | null = detail.ok ? XListParser.detail(detail.body, row.id) : null;
          if (remote !== null && remote.bannerUrl.length > 0) { row.bannerUrl = remote.bannerUrl; this.bannerUrl = remote.bannerUrl; }
        }
        this.savedRow = row; listStateStore.update(xPrivateClient.viewerId(), row);
      }
      this.finish();
    } catch (error) { this.status = this.text($r('app.string.list_action_failed')); }
    finally {
      this.busy = false;
      if (this.status.length > 0) {
        setTimeout((): void => { if (this.active) { this.scroller.scrollEdge(Edge.Bottom); } }, 60);
      }
    }
  }
  private failure(result: XPrivateResult): string {
    return this.text($r('app.string.list_action_failed')) + ' · ' + XPrivateClient.explain(result).substring(0, 160);
  }
  private finish(): void {
    const row: ListRow | null = this.savedRow;
    if (row === null) { return; }
    if (this.editing) { this.pageStack.pop(); return; }
    const param: ListMembersRouteParam = { listId: row.id, title: row.name, row: row, manage: true, creating: true };
    this.pageStack.replacePath({ name: 'ListMembers', param: param });
  }
  private manage(): void {
    const row: ListRow | null = this.savedRow;
    if (row === null || this.busy) { return; }
    const param: ListMembersRouteParam = { listId: row.id, title: row.name, row: row, manage: true, creating: false };
    this.pageStack.pushPath({ name: 'ListMembers', param: param });
  }
  private async deleteList(): Promise<void> {
    const row: ListRow | null = this.savedRow;
    if (row === null || this.busy || !this.canEdit()) { return; }
    const response: promptAction.ShowDialogSuccessResponse = await promptAction.showDialog({
      title: this.text($r('app.string.list_delete')), message: this.text($r('app.string.list_delete_confirm')),
      buttons: [{ text: this.text($r('app.string.compose_cancel')), color: this.accentColor },
        { text: this.text($r('app.string.list_delete')), color: this.textColor() }]
    });
    if (response.index !== 1) { return; }
    this.busy = true;
    try {
      const result: XPrivateResult = await xPrivateClient.deleteList(row.id);
      if (result.ok) { listStateStore.remove(xPrivateClient.viewerId(), row.id); this.pageStack.pop(); }
      else { this.status = this.failure(result); }
    } finally { this.busy = false; }
  }
  private textColor(): string {
    return '#' + (getContext(this) as common.UIAbilityContext).resourceManager
      .getColorSync($r('app.color.like')).toString(16).padStart(8, '0');
  }

  @Builder
  private Form(): void {
    Column({ space: 20 }) {
      Stack() {
        ListCover({ listId: this.savedRow === null ? '' : this.savedRow.id,
          bannerUrl: this.removeBanner ? '' : this.bannerUri.length > 0 ? this.bannerUri : this.bannerUrl, wide: true })
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.camera_badge_plus')).fontSize(32).fontColor([$r('app.color.text_on_brand')])
        }.width(60).height(60).backgroundColor($r('app.color.list_cover_button'))
          .accessibilityText($r('app.string.list_choose_cover')).onClick((): void => { this.selectBanner(); })
      }.width('100%').clip(true).borderRadius(12)
      if (this.bannerUri.length > 0 || (this.hasCustomBanner && !this.removeBanner)) {
        Button($r('app.string.list_remove_cover')).fontColor(this.accentColor).backgroundColor(Color.Transparent)
          .enabled(!this.busy).onClick((): void => { this.bannerUri = ''; this.removeBanner = this.hasCustomBanner; })
      }
      Column({ space: 8 }) {
        Text($r('app.string.list_name')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
        TextInput({ text: this.name, placeholder: this.text($r('app.string.list_name_placeholder')) }).fontFamily(this.appFontFamily)
          .keyboardAppearance(KeyboardAppearance.IMMERSIVE)
          .maxLength(25).fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface)))
          .backgroundColor(fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
          .enabled(!this.busy).onChange((value: string): void => { this.name = value; })
        Text(this.name.length + '/25').fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S')).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
          .width('100%').textAlign(TextAlign.End)
      }.alignItems(HorizontalAlign.Start).width('100%')
      Column({ space: 8 }) {
        Text($r('app.string.list_description')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
        TextArea({ text: this.description, placeholder: this.text($r('app.string.list_description_placeholder')) }).fontFamily(this.appFontFamily)
          .keyboardAppearance(KeyboardAppearance.IMMERSIVE)
          .maxLength(100).height(100).fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface)))
          .backgroundColor(fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
          .enabled(!this.busy).onChange((value: string): void => { this.description = value; })
        Text(this.description.length + '/100').fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S')).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
          .width('100%').textAlign(TextAlign.End)
      }.alignItems(HorizontalAlign.Start).width('100%')
      Row({ space: 16 }) {
        Column({ space: 6 }) {
          Text($r('app.string.list_private')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontWeight(FontWeight.Bold)
            .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent))
          Text($r('app.string.list_private_description')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
            .fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Toggle({ type: ToggleType.Switch, isOn: this.isPrivate }).selectedColor(this.accentColor)
          .enabled(!this.busy).onChange((value: boolean): void => { this.isPrivate = value; })
      }.width('100%')
      if (this.editing) {
        Button($r('app.string.list_manage_members')).width('100%').backgroundColor(Color.Transparent)
          .fontColor(this.accentColor).enabled(!this.busy).onClick((): void => this.manage())
        Button($r('app.string.list_delete')).width('100%').backgroundColor(Color.Transparent)
          .fontColor($r('app.color.like')).enabled(!this.busy).onClick((): void => { this.deleteList(); })
      }
      if (this.status.length > 0) {
        Text(this.status).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)).width('100%')
        if (this.bannerFailed) {
          Button($r('app.string.list_continue_without_cover')).backgroundColor(Color.Transparent)
            .fontColor(this.accentColor).onClick((): void => this.finish())
        }
      }
    }.width('100%').padding({ left: 20, right: 20, top: 16, bottom: 24 })
  }
  build(): void {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        appPageBackground()
      Column() {
        Scroll(this.scroller) { this.Form() }.width('100%').layoutWeight(1).scrollBar(BarState.Off)
        Row() {
          Blank()
          Button(this.editing ? $r('app.string.list_save') : $r('app.string.list_create_action'))
            .fontColor($r('app.color.text_on_accent')).backgroundColor(this.accentColor)
            .enabled(this.valid() && !this.busy && !this.unresolvedCreate && this.canEdit())
            .onClick((): void => { this.save(); })
          if (this.busy) { LoadingProgress().width(24).height(24).color(this.accentColor).margin({ left: 12 }) }
        }.width('100%').padding({ left: 20, right: 20, top: 12, bottom: this.navigationIndicatorHeight + 16 })
      }.width('100%').height('100%').padding({ top: this.statusBarHeight + 60 })
    
      }.width('100%').height('100%')
    }
    .scale({ x: this.pageMotion.scale, y: this.pageMotion.scale })
    .opacity(this.pageMotion.opacity)
    .onReady((context: NavDestinationContext): void => { this.pageMotion.attach(context); })
    .systemTransition(pageSystemTransition(this.pageTransitionMode)).titleMode(HdsNavDestinationTitleMode.MINI).hideBackButton(false)
      .onBackPressed((): boolean => { if (!this.busy) { this.pageStack.pop(); } return true; })
      .titleBar({ avoidLayoutSafeArea: true,
        content: { title: { mainTitle: this.editing ? $r('app.string.list_edit') : $r('app.string.list_create_title'),
          subTitle: this.editing ? '' : $r('app.string.list_create_step_one') } },
        style: destinationTitleBarStyle(ScrollEffectType.IMMERSIVE_GRADIENT_BLUR,
          this.themeDisplayMode, this.themeDarkSurface, this.titleBarStyleMode) })
      .backgroundColor(pageCanvasColor(this.themeDisplayMode, this.themeDarkSurface, this.pageBackgroundValue))
      .attributeModifier(materialModifier(deviceInfo.apiAvailable('26.0.0') ? new uiMaterial.ImmersiveMaterial({
        style: uiMaterial.ImmersiveStyle.REGULAR, applyShadow: true, colorInvert: true }) : undefined));
  }
}
