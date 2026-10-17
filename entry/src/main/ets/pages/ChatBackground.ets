import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { common } from '@kit.AbilityKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { HdsNavDestination, HdsNavDestinationTitleMode, ScrollEffectType, TextStyleMode } from '@kit.UIDesignKit';
import { ChatBackgroundLayer } from '../components/ChatBackgroundLayer';
import { ChatBackgroundState, ChatBackgroundPreset, chatBackgroundPresets, chatBackgroundStore,
  copyChatBackground } from '../services/ChatBackgroundStore';
import { xPrivateStore } from '../services/XPrivateStore';
import { cardSurfaceColor, pageSurfaceColor, secondaryButtonSurfaceColor } from '../utils/ThemeColors';
import { destinationTitleBarStyle } from '../utils/DestinationTitleBar';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';

export interface ChatBackgroundRouteParam { conversationId: string; }

@Builder
export function ChatBackgroundBuilder(): void { ChatBackgroundPage(); }

// Adapted from Petrelgram's ChatBackgroundPage (Apache-2.0): preview,
// local-photo picker, adjustment card and wallpaper grid. Uses Harmony X's
// destination chrome and account/conversation preferences instead of TDLib.
@Component
struct ChatBackgroundPage {
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp('harmonyx.status_bar_height') statusBarHeight: number = 0;
  @StorageProp('harmonyx.navigation_indicator_height') bottomInset: number = 0;
  @StorageProp('harmonyx.display_mode') displayMode: string = '';
  @StorageProp('harmonyx.dark_surface') darkSurface: string = '';
  @StorageProp('harmonyx.accent_color') accentColor: string = '#007DFF';
  @StorageProp('harmonyx.title_bar_style_mode') titleBarStyleMode: number = 0;
  @StorageProp('harmonyx.accounts_changed') @Watch('accountChanged') accountRevision: number = 0;
  @State private selected: ChatBackgroundState = new ChatBackgroundState();
  @State private photoPath: string = '';
  @State private picking: boolean = false;
  @State private saving: boolean = false;
  private conversationId: string = '';
  private account: string = '';
  private disposed: boolean = false;
  private stagedPath: string = '';
  private scroller: Scroller = new Scroller();

  private context(): common.UIAbilityContext { return getContext(this) as common.UIAbilityContext; }

  aboutToAppear(): void {
    const params: ChatBackgroundRouteParam[] = this.pageStack.getParamByName('ChatBackground') as ChatBackgroundRouteParam[];
    if (params.length === 0) { return; }
    this.conversationId = params[params.length - 1].conversationId;
    this.account = xPrivateStore.load(this.context()).cacheIdentity();
    this.selected = chatBackgroundStore.load(this.context(), this.conversationId);
    this.photoPath = this.selected.path;
  }

  aboutToDisappear(): void { this.disposed = true; this.removeStaged(); }

  private accountChanged(): void {
    this.disposed = true;
    this.removeStaged();
    ResponsiveLayout.closeContentDestination(this.pageStack);
  }

  private valid(): boolean {
    return !this.disposed && this.account === xPrivateStore.load(this.context()).cacheIdentity();
  }

  private removeStaged(): void {
    chatBackgroundStore.removePhoto(this.context(), this.stagedPath);
    this.stagedPath = '';
  }

  private toast(resource: Resource): void {
    this.getUIContext().getPromptAction().showToast({ message: this.context().resourceManager.getStringSync(resource), duration: 1800 });
  }

  private selectPreset(id: string): void {
    const next: ChatBackgroundState = new ChatBackgroundState();
    next.presetId = id;
    next.dim = id === 'default' ? 0 : this.selected.dim;
    next.blur = id === 'default' ? 0 : this.selected.blur;
    next.patternStrength = this.selected.patternStrength;
    this.selected = next;
  }

  private selectPhoto(): void {
    const next: ChatBackgroundState = new ChatBackgroundState();
    next.presetId = 'photo';
    next.path = this.photoPath;
    next.dim = this.selected.dim;
    this.selected = next;
  }

  private async pickPhoto(): Promise<void> {
    if (this.picking || this.saving || !this.valid()) { return; }
    this.picking = true;
    const context: common.UIAbilityContext = this.context();
    let imported: string = '';
    try {
      const options: photoAccessHelper.PhotoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1;
      const result: photoAccessHelper.PhotoSelectResult = await new photoAccessHelper.PhotoViewPicker().select(options);
      if (!this.valid() || result.photoUris.length === 0) { return; }
      imported = await chatBackgroundStore.importPhoto(context, result.photoUris[0]);
      if (!this.valid()) { chatBackgroundStore.removePhoto(context, imported); return; }
      this.removeStaged();
      this.stagedPath = imported;
      this.photoPath = imported;
      this.selectPhoto();
    } catch (error) {
      if (imported.length > 0) { chatBackgroundStore.removePhoto(context, imported); }
      if (this.valid()) { this.toast($r('app.string.chat_background_photo_failed')); }
    } finally { if (!this.disposed) { this.picking = false; } }
  }

  private apply(): void {
    if (this.picking || this.saving || !this.valid()) { return; }
    this.saving = true;
    try {
      chatBackgroundStore.save(this.context(), this.conversationId, this.selected);
      if (this.selected.path === this.stagedPath) { this.stagedPath = ''; }
      this.toast($r('app.string.chat_background_applied'));
      ResponsiveLayout.closeContentDestination(this.pageStack);
    } catch (error) { this.toast($r('app.string.chat_background_apply_failed')); }
    finally { this.saving = false; }
  }

  private adjust(value: number, kind: string): void {
    const next: ChatBackgroundState = copyChatBackground(this.selected);
    if (kind === 'blur') { next.blur = value; }
    else if (kind === 'pattern') { next.patternStrength = value / 100; }
    else { next.dim = value / 100; }
    this.selected = next;
  }

  @Builder
  private Preview(): void {
    Stack() {
      ChatBackgroundLayer({ wallpaper: this.selected, displayMode: this.displayMode, darkSurface: this.darkSurface })
      Column({ space: 12 }) {
        Row() {
          Text($r('app.string.chat_background_preview_incoming')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
            .fontColor($r('app.color.text_primary')).padding(12).borderRadius(18)
            .backgroundColor(secondaryButtonSurfaceColor(this.displayMode, this.darkSurface))
        }.width('100%').justifyContent(FlexAlign.Start)
        Row() {
          Text($r('app.string.chat_background_preview_outgoing')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
            .fontColor($r('app.color.text_on_accent')).padding(12).borderRadius(18).backgroundColor(this.accentColor)
        }.width('100%').justifyContent(FlexAlign.End)
      }.width('100%').padding(20)
    }.width('100%').height($r('app.float.chat_background_preview_height')).clip(true).borderRadius(20)
      .border({ width: 1, color: $r('app.color.divider') })
  }

  @Builder
  private PhotoPickerRow(): void {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 12 }) {
        SymbolGlyph($r('sys.symbol.picture')).fontSize(24).fontColor([this.accentColor])
        Text($r('app.string.chat_background_pick_photo')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L'))
          .fontColor($r('app.color.text_primary')).layoutWeight(1).textAlign(TextAlign.Start)
        if (this.picking) { LoadingProgress().width(24).height(24).color(this.accentColor) }
        else { SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(18).fontColor([$r('app.color.text_secondary')]) }
      }.width('100%')
    }.width('100%').height(64).padding({ left: 16, right: 16 }).borderRadius(16)
      .backgroundColor(cardSurfaceColor(this.displayMode, this.darkSurface)).enabled(!this.picking && !this.saving)
      .onClick((): void => { this.pickPhoto(); })
  }

  @Builder
  private Adjustments(): void {
    Column({ space: 12 }) {
      Column({ space: 12 }) {
        Row() {
          Text($r('app.string.chat_background_blur')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_primary')).layoutWeight(1)
          Text(Math.round(this.selected.blur).toString()).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary'))
        }.width('100%')
        Slider({ value: this.selected.blur, min: 0, max: 30, step: 1 }).width('100%')
          .selectedColor(this.accentColor).blockColor(this.accentColor)
          .onChange((value: number): void => { this.adjust(value, 'blur'); })
        Divider().color($r('app.color.divider'))
      }
      if (this.selected.path.length === 0) {
        Row() {
          Text($r('app.string.chat_background_pattern_strength')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_primary')).layoutWeight(1)
          Text(Math.round(this.selected.patternStrength * 100).toString() + '%').fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary'))
        }.width('100%')
        Slider({ value: this.selected.patternStrength * 100, min: 0, max: 100, step: 5 }).width('100%')
          .selectedColor(this.accentColor).blockColor(this.accentColor)
          .onChange((value: number): void => { this.adjust(value, 'pattern'); })
        Divider().color($r('app.color.divider'))
      }
      Row() {
        Text($r('app.string.chat_background_dim')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_primary')).layoutWeight(1)
        Text(Math.round(this.selected.dim * 100).toString() + '%').fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary'))
      }.width('100%')
      Slider({ value: this.selected.dim * 100, min: 0, max: 60, step: 5 }).width('100%')
        .selectedColor(this.accentColor).blockColor(this.accentColor)
        .onChange((value: number): void => { this.adjust(value, 'dim'); })
    }.width('100%').padding(16).borderRadius(16).backgroundColor(cardSurfaceColor(this.displayMode, this.darkSurface))
  }

  private tileBackground(preset: ChatBackgroundPreset): ChatBackgroundState {
    const state: ChatBackgroundState = new ChatBackgroundState();
    state.presetId = preset.id;
    return state;
  }

  @Builder
  private SelectionMark(): void {
    SymbolGlyph($r('sys.symbol.checkmark')).fontSize(14).fontColor([$r('app.color.text_on_accent')])
      .width(26).height(26).borderRadius(13).backgroundColor(this.accentColor).margin(8)
  }

  @Builder
  private PresetTile(preset: ChatBackgroundPreset): void {
    Column({ space: 8 }) {
      Button({ type: ButtonType.Normal }) {
        Stack({ alignContent: Alignment.TopEnd }) {
          if (preset.thumbnail !== undefined) {
            Image(preset.thumbnail).width('100%').height('100%').autoResize(true).objectFit(ImageFit.Cover).draggable(false)
          } else {
            ChatBackgroundLayer({ wallpaper: this.tileBackground(preset), displayMode: this.displayMode, darkSurface: this.darkSurface })
          }
          if (this.selected.presetId === preset.id) { this.SelectionMark() }
        }.width('100%').height('100%')
      }.width('100%').height($r('app.float.chat_background_tile_height')).padding(0).borderRadius(16).clip(true)
        .border({ width: this.selected.presetId === preset.id ? 2 : 1,
          color: this.selected.presetId === preset.id ? this.accentColor : $r('app.color.divider') })
        .backgroundColor(Color.Transparent).accessibilityText(preset.title)
        .enabled(!this.picking && !this.saving).onClick((): void => { this.selectPreset(preset.id); })
      Text(preset.title).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S')).fontColor($r('app.color.text_secondary'))
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
    }.width('100%')
  }

  @Builder
  private PhotoTile(): void {
    Column({ space: 8 }) {
      Button({ type: ButtonType.Normal }) {
        Stack({ alignContent: Alignment.TopEnd }) {
          Image('file://' + this.photoPath).width('100%').height('100%').autoResize(true).objectFit(ImageFit.Cover).draggable(false)
          if (this.selected.presetId === 'photo') { this.SelectionMark() }
        }.width('100%').height('100%')
      }.width('100%').height($r('app.float.chat_background_tile_height')).padding(0).borderRadius(16).clip(true)
        .border({ width: this.selected.presetId === 'photo' ? 2 : 1,
          color: this.selected.presetId === 'photo' ? this.accentColor : $r('app.color.divider') })
        .accessibilityText($r('app.string.chat_background_my_photo')).enabled(!this.picking && !this.saving)
        .onClick((): void => { this.selectPhoto(); })
      Text($r('app.string.chat_background_my_photo')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S')).fontColor($r('app.color.text_secondary'))
    }.width('100%')
  }

  build(): void {
    HdsNavDestination() {
      Scroll(this.scroller) {
        Column({ space: 16 }) {
          this.Preview()
          Text($r('app.string.chat_background_note')).fontFamily(this.appFontFamily).width('100%').fontSize($r('sys.float.Body_S'))
            .fontColor($r('app.color.text_secondary'))
          this.PhotoPickerRow()
          if (this.selected.presetId !== 'default') { this.Adjustments() }
          Text($r('app.string.chat_background_presets')).fontFamily(this.appFontFamily).width('100%').fontSize($r('sys.float.Body_L'))
            .fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
          GridRow({ columns: 3, gutter: { x: 12, y: 16 } }) {
            ForEach(chatBackgroundPresets(), (preset: ChatBackgroundPreset) => {
              GridCol() { this.PresetTile(preset) }
            }, (preset: ChatBackgroundPreset): string => preset.id)
            if (this.photoPath.length > 0) { GridCol() { this.PhotoTile() } }
          }
        }.width('100%').padding({ left: 16, right: 16, top: this.statusBarHeight + 80, bottom: this.bottomInset + 24 })
      }.width('100%').height('100%').scrollBar(BarState.Off).align(Alignment.Top)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    }.titleMode(HdsNavDestinationTitleMode.MINI).hideBackButton(false).bindToScrollable([this.scroller])
      .titleBar({ avoidLayoutSafeArea: true,
        content: { title: { mainTitle: $r('app.string.chat_background') }, menu: { value: [
          { content: { label: $r('app.string.chat_background_apply'), type: TextStyleMode.NORMAL,
            isEnabled: !this.picking && !this.saving, action: (): void => { this.apply(); } } }
        ] } },
        style: destinationTitleBarStyle(ScrollEffectType.GRADIENT_BLUR, this.displayMode, this.darkSurface, this.titleBarStyleMode)
      })
      .backgroundColor(pageSurfaceColor(this.displayMode, this.darkSurface))
      .onBackPressed((): boolean => { ResponsiveLayout.closeContentDestination(this.pageStack); return true; })
  }
}
