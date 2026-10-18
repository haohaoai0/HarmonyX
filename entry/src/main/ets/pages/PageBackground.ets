import { common } from '@kit.AbilityKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { HdsNavDestination, HdsNavDestinationTitleMode, ScrollEffectType, TextStyleMode } from '@kit.UIDesignKit';
import { PageBackgroundLayer } from '../components/PageBackgroundLayer';
import { ChatBackgroundPreset, chatBackgroundPresets } from '../services/ChatBackgroundStore';
import { PageBackgroundState, normalizePageBackground, pageBackgroundStore } from '../services/PageBackgroundStore';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { STORAGE_KEY_PAGE_TRANSITION_MODE, DEFAULT_PAGE_TRANSITION_MODE } from '../services/PageTransitionSettingsStore';
import { PageTransitionMotion, pageSystemTransition } from '../utils/PageTransition';
import { pageSurfaceColor, cardSurfaceColor, postCardSurfaceColor, inboxRowSurfaceColor, pageTextColor } from '../utils/ThemeColors';
import { destinationTitleBarStyle } from '../utils/DestinationTitleBar';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';
import { PageBackgroundMotif, PageBackgroundMotifSet, pageBackgroundMotifs } from '../models/PageBackgroundMotifs';
import { BackgroundImage, backgroundImageStore } from '../services/BackgroundImageStore';
import { picker } from '@kit.CoreFileKit';
import { importPageBackgroundScheme, sharePageBackgroundScheme } from '../services/PageBackgroundScheme';

@Builder
export function PageBackgroundBuilder(): void { PageBackgroundPage(); }

@Component
struct PageBackgroundPage {
  @Consume('pageStack') private pageStack: NavPathStack;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp('harmonyx.display_mode') private displayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private darkSurface: string = '';
  @StorageProp('harmonyx.accent_color') private accentColor: string = '';
  @StorageProp('harmonyx.title_bar_style_mode') private titleBarStyleMode: number = 0;
  @StorageProp('harmonyx.status_bar_height') private statusBarHeight: number = 0;
  @StorageProp('harmonyx.navigation_indicator_height') private bottomInset: number = 0;
  @StorageProp(STORAGE_KEY_PAGE_TRANSITION_MODE) private pageTransitionMode: string = DEFAULT_PAGE_TRANSITION_MODE;
  @State private pageMotion: PageTransitionMotion = new PageTransitionMotion();
  @State private selected: PageBackgroundState = new PageBackgroundState();
  @State private colorInput: string = '';
  @State private picking: boolean = false;
  @State private saving: boolean = false;
  @State private enabledSaving: boolean = false;
  @State private motifSet: string = 'mobile_brands_systems';
  @State private previewInbox: boolean = false;
  @State private savedPhotos: BackgroundImage[] = [];
  private stagedPath: string = '';
  private disposed: boolean = false;
  private scroller: Scroller = new Scroller();

  private context(): common.UIAbilityContext { return getContext(this) as common.UIAbilityContext; }
  aboutToAppear(): void {
    this.disposed = false;
    this.selected = pageBackgroundStore.load(this.context());
    this.colorInput = this.selected.color;
    this.savedPhotos = backgroundImageStore.photos(this.context());
    this.refreshSelectedTone();
  }
  aboutToDisappear(): void {
    this.disposed = true;
    pageBackgroundStore.removePhoto(this.context(), this.stagedPath);
    this.stagedPath = '';
  }
  private toast(value: Resource): void {
    this.getUIContext().getPromptAction().showToast({ message: this.context().resourceManager.getStringSync(value) });
  }
  private setMode(mode: string): void {
    const next: PageBackgroundState = normalizePageBackground(this.selected);
    next.mode = mode;
    this.selected = normalizePageBackground(next);
  }
  private setColor(value: string): void {
    this.colorInput = value;
    const candidate: string = value.startsWith('#') ? value : '#' + value;
    if (!/^#[0-9a-fA-F]{6}$/.test(candidate)) { return; }
    const next: PageBackgroundState = normalizePageBackground(this.selected);
    next.color = candidate.toUpperCase(); next.mode = 'color';
    this.selected = next;
  }
  private selectSwatch(index: number): void {
    this.setColor(this.swatchHex(index));
  }
  private swatchHex(index: number): string {
    const color: number = this.context().resourceManager.getColorSync(this.swatches()[index]);
    return '#' + (color & 0xFFFFFF).toString(16).padStart(6, '0').toUpperCase();
  }
  private setTexture(kind: string): void {
    const next: PageBackgroundState = normalizePageBackground(this.selected);
    next.texture = kind; this.selected = next;
  }
  private paperPreview(kind: string): PageBackgroundState {
    const state: PageBackgroundState = new PageBackgroundState(); state.texture = kind; return state;
  }
  private setPattern(id: string): void {
    const next: PageBackgroundState = normalizePageBackground(this.selected);
    next.patternIds = id === 'none' ? [] : next.patternIds.indexOf(id) >= 0 ?
      next.patternIds.filter((item: string): boolean => item !== id) : [...next.patternIds, id];
    next.patternId = next.patternIds.length > 0 ? next.patternIds[0] : 'none';
    next.patternLayout = 'preset'; this.selected = next;
  }
  private setLayout(layout: string): void {
    const next: PageBackgroundState = normalizePageBackground(this.selected);
    next.patternLayout = layout; this.selected = next;
  }
  private toggleMotif(id: string): void {
    const next: PageBackgroundState = normalizePageBackground(this.selected);
    next.motifIds = next.motifIds.indexOf(id) >= 0 ? next.motifIds.filter((item: string): boolean => item !== id) : [...next.motifIds, id];
    this.selected = next;
  }
  private wholeSetSelected(): boolean {
    return pageBackgroundMotifs(this.motifSet).every((motif: PageBackgroundMotif): boolean => this.selected.motifIds.indexOf(motif.id) >= 0);
  }
  private toggleSet(): void {
    const remove: boolean = this.wholeSetSelected();
    const motifs: PageBackgroundMotif[] = pageBackgroundMotifs(this.motifSet);
    const next: PageBackgroundState = normalizePageBackground(this.selected);
    for (let i: number = 0; i < motifs.length; i++) {
      const id: string = motifs[i].id;
      if (remove) { next.motifIds = next.motifIds.filter((item: string): boolean => item !== id); }
      else if (next.motifIds.indexOf(id) < 0) { next.motifIds.push(id); }
    }
    this.selected = next;
  }
  private setOptions(): SelectOption[] {
    return this.motifSets().map((preset: PageBackgroundMotifSet): SelectOption => {
      return { value: this.context().resourceManager.getStringSync(preset.title) };
    });
  }
  private motifName(motif: PageBackgroundMotif): string {
    const title: Resource | undefined = motif.title;
    return title === undefined ? motif.id : this.context().resourceManager.getStringSync(title);
  }
  private motifSets(): PageBackgroundMotifSet[] {
    const sets: PageBackgroundMotifSet[] = [
      { id: 'mobile_brands_systems', title: $r('app.string.page_background_set_mobile_brands_systems') },
      { id: 'ai_assistants', title: $r('app.string.page_background_set_ai_assistants') },
      { id: 'signature_icons', title: $r('app.string.page_background_set_signature_icons') },
      { id: 'garden_defense', title: $r('app.string.page_background_set_garden_defense') }
    ];
    this.patterns().forEach((preset: ChatBackgroundPreset): void => { sets.push({ id: preset.id, title: preset.title }); });
    return sets;
  }
  private adjust(kind: string, value: number): void {
    const next: PageBackgroundState = normalizePageBackground(this.selected);
    if (kind === 'blur') { next.blur = value; }
    else if (kind === 'density') { next.density = value; }
    else if (kind === 'texture') { next.textureStrength = value / 100; }
    else if (kind === 'dim') { next.dim = value / 100; }
    else if (kind === 'pattern') { next.patternStrength = value / 100; }
    else if (kind === 'postOpacity') { next.postOpacity = value / 100; this.previewInbox = false; }
    else if (kind === 'inboxOpacity') { next.inboxOpacity = value / 100; this.previewInbox = true; }
    else { next.contentOpacity = value / 100; }
    this.selected = next;
  }
  private adjustmentValue(kind: string): number {
    if (kind === 'blur') { return this.selected.blur; }
    if (kind === 'density') { return this.selected.density; }
    if (kind === 'texture') { return this.selected.textureStrength * 100; }
    if (kind === 'dim') { return this.selected.dim * 100; }
    if (kind === 'pattern') { return this.selected.patternStrength * 100; }
    if (kind === 'postOpacity') { return this.selected.postOpacity * 100; }
    if (kind === 'inboxOpacity') { return this.selected.inboxOpacity * 100; }
    return this.selected.contentOpacity * 100;
  }
  private setTransparency(kind: string, enabled: boolean): void {
    const next: PageBackgroundState = normalizePageBackground(this.selected);
    if (kind === 'posts') { next.transparentPosts = enabled; this.previewInbox = false; }
    else { next.transparentInbox = enabled; this.previewInbox = true; }
    this.selected = next;
  }
  private async pickPhoto(): Promise<void> {
    if (this.picking || this.saving) { return; }
    this.picking = true;
    const context: common.UIAbilityContext = this.context();
    try {
      const options: photoAccessHelper.PhotoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE; options.maxSelectNumber = 1;
      const result: photoAccessHelper.PhotoSelectResult = await new photoAccessHelper.PhotoViewPicker().select(options);
      if (this.disposed || result.photoUris.length === 0) { return; }
      const path: string = await pageBackgroundStore.importPhoto(context, result.photoUris[0]);
      if (this.disposed) { pageBackgroundStore.removePhoto(context, path); return; }
      pageBackgroundStore.removePhoto(context, this.stagedPath);
      this.stagedPath = path;
      const next: PageBackgroundState = normalizePageBackground(this.selected);
      next.mode = 'photo'; next.path = path; this.selected = next;
      await this.refreshSelectedTone();
    } catch (error) { if (!this.disposed) { this.toast($r('app.string.chat_background_photo_failed')); } }
    finally { if (!this.disposed) { this.picking = false; } }
  }

  private selectSavedPhoto(path: string): void {
    const next: PageBackgroundState = normalizePageBackground(this.selected);
    next.mode = 'photo'; next.path = path;
    this.selected = next;
    this.refreshSelectedTone();
  }
  private async refreshSelectedTone(): Promise<void> {
    const path: string = this.selected.path;
    const sampled: PageBackgroundState = await pageBackgroundStore.withPhotoTone(this.selected);
    if (this.disposed || this.selected.mode !== 'photo' || this.selected.path !== path) { return; }
    const next: PageBackgroundState = normalizePageBackground(this.selected);
    next.photoTonePath = sampled.photoTonePath; next.photoAverage = sampled.photoAverage;
    next.photoDarkest = sampled.photoDarkest; next.photoLightest = sampled.photoLightest; next.photoAlpha = sampled.photoAlpha;
    this.selected = next;
  }
  private async apply(): Promise<void> {
    if (this.picking || this.saving) { return; }
    this.saving = true;
    try {
      const next: PageBackgroundState = await pageBackgroundStore.withPhotoTone(this.selected);
      if (this.disposed) { return; }
      pageBackgroundStore.save(this.context(), next);
      this.toast($r('app.string.page_background_applied'));
      ResponsiveLayout.closeContentDestination(this.pageStack);
    } catch (error) { this.toast($r('app.string.page_background_apply_failed')); }
    finally { this.saving = false; }
  }
  private async setEnabled(enabled: boolean): Promise<void> {
    if (this.picking || this.saving || this.enabledSaving) { return; }
    this.enabledSaving = true;
    try {
      const durable: PageBackgroundState = pageBackgroundStore.load(this.context());
      durable.enabled = enabled;
      const next: PageBackgroundState = await pageBackgroundStore.withPhotoTone(durable);
      if (this.disposed) { return; }
      next.enabled = enabled;
      pageBackgroundStore.save(this.context(), next);
      const draft: PageBackgroundState = normalizePageBackground(this.selected);
      draft.enabled = enabled; this.selected = draft;
    } catch (error) {
      if (!this.disposed) {
        this.selected = normalizePageBackground(this.selected);
        this.toast($r('app.string.page_background_apply_failed'));
      }
    } finally { if (!this.disposed) { this.enabledSaving = false; } }
  }
  private async importScheme(): Promise<void> {
    if (this.picking || this.saving) { return; }
    this.picking = true;
    try {
      const options: picker.DocumentSelectOptions = { maxSelectNumber: 1,
        fileSuffixFilters: ['HarmonyX|.hxb', 'JSON|.json'] };
      const uris: string[] = await new picker.DocumentViewPicker(this.context()).select(options);
      if (this.disposed || uris.length === 0) { return; }
      const next: PageBackgroundState = await importPageBackgroundScheme(this.context(), uris[0]);
      if (this.disposed) { pageBackgroundStore.removePhoto(this.context(), next.path); return; }
      pageBackgroundStore.removePhoto(this.context(), this.stagedPath);
      this.stagedPath = next.mode === 'photo' ? next.path : '';
      this.selected = next; this.colorInput = next.color; this.previewInbox = false;
      this.scroller.scrollEdge(Edge.Top);
      this.toast($r('app.string.page_background_scheme_imported'));
    } catch (error) { if (!this.disposed && (error as Error).message.toLowerCase().indexOf('cancel') < 0) {
      this.toast($r('app.string.page_background_scheme_import_failed'));
    } } finally { if (!this.disposed) { this.picking = false; } }
  }
  private async shareScheme(): Promise<void> {
    if (this.picking || this.saving) { return; }
    this.saving = true;
    try {
      await sharePageBackgroundScheme(this.context(), this.selected,
        this.context().resourceManager.getStringSync($r('app.string.page_background_scheme_title')));
    } catch (error) { if (!this.disposed) { this.toast($r('app.string.page_background_scheme_share_failed')); } }
    finally { if (!this.disposed) { this.saving = false; } }
  }
  private reset(): void {
    const enabled: boolean = this.selected.enabled;
    this.selected = new PageBackgroundState(); this.selected.enabled = enabled; this.colorInput = '';
  }
  private patterns(): ChatBackgroundPreset[] {
    return chatBackgroundPresets().filter((preset: ChatBackgroundPreset): boolean => preset.pattern !== undefined);
  }
  private swatches(): Resource[] {
    return [$r('app.color.page_background_blue'), $r('app.color.page_background_green'),
      $r('app.color.page_background_sand'), $r('app.color.page_background_rose'),
      $r('app.color.page_background_lilac'), $r('app.color.page_background_slate')];
  }
  private swatchNames(): Resource[] {
    return [$r('app.string.settings_theme_cloisonne'), $r('app.string.settings_theme_bamboo_green'),
      $r('app.string.settings_theme_amber'), $r('app.string.settings_theme_rouge'),
      $r('app.string.settings_theme_begonia'), $r('app.string.settings_theme_mountain')];
  }
  private patternPreview(id: string): PageBackgroundState {
    const state: PageBackgroundState = normalizePageBackground(this.selected);
    state.patternId = id; state.patternIds = id === 'none' ? [] : [id];
    state.patternLayout = 'preset'; state.patternStrength = Math.max(0.5, state.patternStrength); return state;
  }

  private previewText(color: ResourceColor): ResourceColor {
    const value: string = JSON.stringify(this.selected);
    const surface: ResourceColor = this.previewInbox ? inboxRowSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), value) :
      postCardSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), value);
    return pageTextColor(color, value, surface);
  }

  @Builder
  private Heading(title: Resource): void {
    Text(title).fontFamily(this.appFontFamily).fontSize($r('sys.float.Title_S')).fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.text_primary')).width('100%')
  }
  @Builder
  private Mark(): void {
    SymbolGlyph($r('sys.symbol.checkmark')).fontSize(14).fontColor([$r('app.color.text_on_accent')])
      .width(26).height(26).borderRadius(13).backgroundColor(this.accentColor).margin(8)
  }
  @Builder
  private Preview(): void {
    Stack({ alignContent: Alignment.Center }) {
      if (this.selected.enabled) {
        PageBackgroundLayer({ wallpaper: this.selected })
      } else {
        Column().width('100%').height('100%').backgroundColor(pageSurfaceColor(this.displayMode, this.darkSurface))
      }
      Column({ space: 12 }) {
        Row({ space: 10 }) {
          SymbolGlyph($r('sys.symbol.person_crop_circle_fill')).fontSize(32).fontColor([this.accentColor])
          Text($r('app.string.page_background_preview')).fontFamily(this.appFontFamily).fontWeight(FontWeight.Bold)
            .fontSize($r('sys.float.Body_L')).fontColor(this.previewText($r('app.color.text_primary'))).layoutWeight(1)
        }.width('100%')
        Text(this.previewInbox ? $r('app.string.chat_background_preview_incoming') : $r('app.string.page_background_preview_text')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_L')).fontColor(this.previewText($r('app.color.text_primary'))).width('100%')
        Divider().color($r('app.color.divider'))
        Text($r('app.string.page_background_preview_hint')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_S')).fontColor(this.previewText($r('app.color.text_secondary'))).width('100%')
      }.width('88%').padding(16).borderRadius(20)
        .backgroundColor(this.previewInbox ? inboxRowSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), JSON.stringify(this.selected)) :
          postCardSurfaceColor(cardSurfaceColor(this.displayMode, this.darkSurface), JSON.stringify(this.selected)))
    }.width('100%').height($r('app.float.page_background_preview_height')).borderRadius(24).clip(true)
      .border({ width: 1, color: $r('app.color.divider') }).id('page-background-preview')
  }
  @Builder
  private BackgroundControls(): void {
    Column({ space: 12 }) {
      Button($r('app.string.settings_theme_system')).width('100%')
        .fontColor(this.selected.mode === 'theme' ? this.accentColor : $r('app.color.text_primary'))
        .backgroundColor(cardSurfaceColor(this.displayMode, this.darkSurface))
        .border({ width: 1, color: this.selected.mode === 'theme' ? this.accentColor : $r('app.color.divider') })
        .id('page-background-theme').onClick((): void => { this.setMode('theme'); })
      GridRow({ columns: 6, gutter: 8 }) {
        ForEach(this.swatches(), (color: Resource, index: number) => {
          GridCol() {
            Button() {
              Stack({ alignContent: Alignment.Center }) {
                Column().width('100%').height(40).backgroundColor(color)
                if (this.selected.mode === 'color' && this.selected.color === this.swatchHex(index)) { this.Mark() }
              }
            }
              .width('100%').height(44).padding(2).borderRadius(12).clip(true)
              .backgroundColor(cardSurfaceColor(this.displayMode, this.darkSurface))
              .border({ width: this.selected.mode === 'color' && this.selected.color === this.swatchHex(index) ? 2 : 1,
                color: this.selected.mode === 'color' && this.selected.color === this.swatchHex(index) ? this.accentColor : $r('app.color.divider') })
              .accessibilityText(this.swatchNames()[index]).id('page-background-color-' + index.toString())
              .onClick((): void => { this.selectSwatch(index); })
          }
        }, (_color: Resource, index: number): string => index.toString())
      }
      TextInput({ text: this.colorInput, placeholder: $r('app.string.page_background_color_placeholder') })
        .maxLength(7).fontFamily(this.appFontFamily).fontColor($r('app.color.text_primary'))
        .backgroundColor(cardSurfaceColor(this.displayMode, this.darkSurface))
        .id('page-background-custom-color').onChange((value: string): void => { this.setColor(value); })
      Button({ type: ButtonType.Normal }) {
        Row({ space: 10 }) {
          Text($r('app.string.chat_background_pick_photo')).fontFamily(this.appFontFamily)
            .fontColor($r('app.color.text_primary')).layoutWeight(1).textAlign(TextAlign.Start)
          if (this.picking) { LoadingProgress().width(24).height(24).color(this.accentColor) }
          else if (this.selected.mode === 'photo') { this.Mark() }
          else { SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(16).fontColor([$r('app.color.text_secondary')]) }
        }.width('100%').padding(16)
      }.width('100%').borderRadius(16).backgroundColor(cardSurfaceColor(this.displayMode, this.darkSurface))
        .enabled(!this.picking && !this.saving).id('page-background-photo').onClick((): void => { this.pickPhoto(); })
    }.width('100%')
  }
  @Builder
  private EnabledSwitch(): void {
    Row({ space: 16 }) {
      Column({ space: 6 }) {
        Text($r('app.string.page_background_switch_title')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Subtitle_L')).fontColor($r('app.color.text_primary')).width('100%')
        Text($r('app.string.page_background_switch_desc')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_S')).fontColor($r('app.color.text_secondary')).width('100%')
      }.layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: this.selected.enabled })
        .selectedColor(this.accentColor).enabled(!this.picking && !this.saving && !this.enabledSaving)
        .id('page-background-enabled').accessibilityText($r('app.string.page_background_switch_title'))
        .onChange((value: boolean): void => { this.setEnabled(value); })
    }.width('100%').padding(16).borderRadius(20)
      .backgroundColor(cardSurfaceColor(this.displayMode, this.darkSurface))
  }
  @Builder
  private PaperTile(kind: string, title: Resource): void {
    Column({ space: 6 }) {
      Button({ type: ButtonType.Normal }) {
        Stack({ alignContent: Alignment.TopEnd }) {
          PageBackgroundLayer({ wallpaper: this.paperPreview(kind) })
          if (this.selected.texture === kind) { this.Mark() }
        }.width('100%').height('100%')
      }.width('100%').height(72).padding(0).borderRadius(16).clip(true)
        .backgroundColor(Color.Transparent).border({ width: this.selected.texture === kind ? 2 : 1,
          color: this.selected.texture === kind ? this.accentColor : $r('app.color.divider') })
        .id('page-background-paper-' + kind).accessibilityText(title).onClick((): void => { this.setTexture(kind); })
      Text(title).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S')).fontColor($r('app.color.text_secondary'))
    }.layoutWeight(1)
  }

  @Builder
  private SavedPhotoTile(photo: BackgroundImage): void {
    Column({ space: 8 }) {
      Button({ type: ButtonType.Normal }) {
        Stack({ alignContent: Alignment.TopEnd }) {
          Image('file://' + photo.path).width('100%').height('100%').autoResize(true).objectFit(ImageFit.Cover).draggable(false)
          if (this.selected.path === photo.path) { this.Mark() }
        }.width('100%').height('100%')
      }.width('100%').height($r('app.float.chat_background_tile_height')).padding(0).borderRadius(16).clip(true)
        .backgroundColor(Color.Transparent).border({ width: this.selected.path === photo.path ? 2 : 1,
          color: this.selected.path === photo.path ? this.accentColor : $r('app.color.divider') })
        .accessibilityText($r('app.string.chat_background_my_photo')).enabled(!this.picking && !this.saving)
        .onClick((): void => { this.selectSavedPhoto(photo.path); })
      Text($r('app.string.chat_background_my_photo')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S'))
        .fontColor($r('app.color.text_secondary'))
    }.width('100%')
  }
  @Builder
  private Adjustment(title: Resource, maximum: number, kind: string): void {
    Column({ space: 4 }) {
      Row() {
        Text(title).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
          .fontColor($r('app.color.text_primary')).layoutWeight(1)
        Text(Math.round(this.adjustmentValue(kind)).toString() + (kind === 'blur' ? '' : '%')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary'))
      }.width('100%')
      Slider({ value: this.adjustmentValue(kind), min: 0, max: maximum, step: 1 }).width('100%')
        .selectedColor(this.accentColor).id('page-background-' + kind)
        .accessibilityText(title).onChange((next: number): void => {
          if (Math.abs(next - this.adjustmentValue(kind)) > 0.001) { this.adjust(kind, next); }
        })
    }.width('100%')
  }
  @Builder
  private TransparencySwitch(title: Resource, detail: Resource, kind: string): void {
    Row({ space: 12 }) {
      Column({ space: 6 }) {
        Text(title).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_primary')).width('100%')
        Text(detail).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S')).fontColor($r('app.color.text_secondary')).width('100%')
      }.layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: kind === 'posts' ? this.selected.transparentPosts : this.selected.transparentInbox })
        .selectedColor(this.accentColor)
        .id('page-background-transparent-' + kind).accessibilityText(title)
        .onChange((value: boolean): void => { this.setTransparency(kind, value); })
    }.width('100%')
  }
  @Builder
  private LayoutChoice(layout: string, label: Resource): void {
    Button(label).layoutWeight(1).fontColor(this.selected.patternLayout === layout ? this.accentColor : $r('app.color.text_secondary'))
      .backgroundColor(cardSurfaceColor(this.displayMode, this.darkSurface))
      .border({ width: 1, color: this.selected.patternLayout === layout ? this.accentColor : $r('app.color.divider') })
      .id('page-background-layout-' + layout).onClick((): void => { this.setLayout(layout); })
  }
  @Builder
  private IconControls(): void {
    Column({ space: 12 }) {
      Text($r('app.string.page_background_mix_hint')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S'))
        .fontColor($r('app.color.text_secondary')).width('100%')
      Select(this.setOptions()).selected(this.motifSets().findIndex((preset: PageBackgroundMotifSet): boolean => preset.id === this.motifSet))
        .value(this.context().resourceManager.getStringSync(this.motifSets().filter((preset: PageBackgroundMotifSet): boolean => preset.id === this.motifSet)[0].title))
        .width('100%').fontColor($r('app.color.text_primary')).id('page-background-motif-set')
        .onSelect((index: number): void => { if (index >= 0 && index < this.motifSets().length) { this.motifSet = this.motifSets()[index].id; } })
      Button(this.wholeSetSelected() ? $r('app.string.page_background_set_remove') : $r('app.string.page_background_set_add'))
        .width('100%').fontColor(this.accentColor).backgroundColor(cardSurfaceColor(this.displayMode, this.darkSurface))
        .id('page-background-select-set').onClick((): void => { this.toggleSet(); })
      GridRow({ columns: { sm: 3, md: 4, lg: 5, xl: 5 }, gutter: 12 }) {
        ForEach(pageBackgroundMotifs(this.motifSet), (motif: PageBackgroundMotif) => {
          GridCol() {
            Button({ type: ButtonType.Normal }) {
              Stack({ alignContent: Alignment.Center }) {
                Column({ space: 6 }) {
                  Image(motif.image).width(40).height(40).objectFit(ImageFit.Contain).draggable(false)
                  if (motif.title !== undefined) {
                    Text(this.motifName(motif)).fontFamily(this.appFontFamily).fontSize($r('sys.float.Caption_M'))
                      .fontColor($r('app.color.text_secondary')).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                }.width('100%').padding({ left: 8, right: 8 })
                if (this.selected.motifIds.indexOf(motif.id) >= 0) {
                  Column() {
                    this.Mark()
                    Blank()
                  }.width('100%').height('100%').alignItems(HorizontalAlign.End).hitTestBehavior(HitTestMode.None)
                }
              }.width('100%').height(88)
            }.width('100%').height(88).padding(0)
              .backgroundColor(cardSurfaceColor(this.displayMode, this.darkSurface))
              .border({ width: this.selected.motifIds.indexOf(motif.id) >= 0 ? 2 : 1,
                color: this.selected.motifIds.indexOf(motif.id) >= 0 ? this.accentColor : $r('app.color.divider') }).borderRadius(16)
              .id('page-background-motif-' + motif.id).accessibilityText(this.motifName(motif))
              .onClick((): void => { this.toggleMotif(motif.id); })
          }
        }, (motif: PageBackgroundMotif): string => motif.id)
      }
      Text(this.context().resourceManager.getStringSync($r('app.string.page_background_selected'), this.selected.motifIds.length))
        .fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary')).width('100%')
      Button($r('app.string.page_background_icons_clear')).width('100%').backgroundColor(Color.Transparent).fontColor(this.accentColor)
        .enabled(this.selected.motifIds.length > 0).id('page-background-clear-motifs')
        .onClick((): void => { const next: PageBackgroundState = normalizePageBackground(this.selected); next.motifIds = []; this.selected = next; })
    }.width('100%')
  }
  @Builder
  private PatternTile(id: string, title: Resource): void {
    Column({ space: 6 }) {
      Button({ type: ButtonType.Normal }) {
        Stack({ alignContent: Alignment.TopEnd }) {
          PageBackgroundLayer({ wallpaper: this.patternPreview(id) })
          if (id === 'none' ? this.selected.patternIds.length === 0 : this.selected.patternIds.indexOf(id) >= 0) { this.Mark() }
        }.width('100%').height('100%')
      }.width('100%').height($r('app.float.page_background_tile_height')).padding(0).borderRadius(16).clip(true)
        .backgroundColor(Color.Transparent).border({ width: this.selected.patternIds.indexOf(id) >= 0 ? 2 : 1,
          color: this.selected.patternIds.indexOf(id) >= 0 ? this.accentColor : $r('app.color.divider') })
        .accessibilityText(title).id('page-background-pattern-' + id).onClick((): void => { this.setPattern(id); })
      Text(title).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S'))
        .fontColor($r('app.color.text_secondary')).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
    }.width('100%')
  }
  build(): void {
    HdsNavDestination() {
      Scroll(this.scroller) {
        Column({ space: 18 }) {
          this.EnabledSwitch()
          this.Preview()
          Text($r('app.string.page_background_note')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S'))
            .fontColor($r('app.color.text_secondary')).width('100%')
          this.Heading($r('app.string.page_background_base'))
          this.BackgroundControls()
          if (this.savedPhotos.length > 0) {
            this.Heading($r('app.string.chat_background_saved_photos'))
            GridRow({ columns: { sm: 3, md: 4, lg: 5, xl: 5 }, gutter: { x: 12, y: 16 } }) {
              ForEach(this.savedPhotos, (photo: BackgroundImage) => {
                GridCol() { this.SavedPhotoTile(photo) }
              }, (photo: BackgroundImage): string => photo.path)
            }.id('page-background-saved-photos')
          }
          this.Heading($r('app.string.page_background_paper'))
          Row({ space: 10 }) {
            this.PaperTile('none', $r('app.string.page_background_paper_none'))
            this.PaperTile('kraft', $r('app.string.page_background_kraft'))
            this.PaperTile('parchment', $r('app.string.page_background_parchment'))
          }.width('100%')
          if (this.selected.texture !== 'none') {
            this.Adjustment($r('app.string.page_background_texture_strength'), 100, 'texture')
          }
          this.Heading($r('app.string.page_background_pattern'))
          Row({ space: 8 }) {
            this.LayoutChoice('icons', $r('app.string.page_background_layout_icons'))
            this.LayoutChoice('preset', $r('app.string.page_background_layout_preset'))
          }.width('100%')
          if (this.selected.patternLayout === 'icons') { this.IconControls() }
          else {
            Text($r('app.string.page_background_presets_mix')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S'))
              .fontColor($r('app.color.text_secondary')).width('100%')
            GridRow({ columns: { sm: 3, md: 4, lg: 5, xl: 5 }, gutter: { x: 12, y: 16 } }) {
              GridCol() { this.PatternTile('none', $r('app.string.page_background_pattern_none')) }
              ForEach(this.patterns(), (preset: ChatBackgroundPreset) => {
                GridCol() { this.PatternTile(preset.id, preset.title) }
              }, (preset: ChatBackgroundPreset): string => preset.id)
            }.id('page-background-patterns')
          }
          Column({ space: 12 }) {
            this.TransparencySwitch($r('app.string.page_background_transparent_posts'),
              $r('app.string.page_background_transparent_posts_desc'), 'posts')
            if (!this.selected.transparentPosts) {
              this.Adjustment($r('app.string.page_background_post_opacity'), 100, 'postOpacity')
            }
            this.TransparencySwitch($r('app.string.page_background_transparent_inbox'),
              $r('app.string.page_background_transparent_inbox_desc'), 'inbox')
            if (!this.selected.transparentInbox) {
              this.Adjustment($r('app.string.page_background_inbox_opacity'), 100, 'inboxOpacity')
            }
            if (this.selected.patternLayout === 'icons' && this.selected.motifIds.length > 0) {
              this.Adjustment($r('app.string.page_background_density'), 100, 'density')
            }
            if ((this.selected.patternLayout === 'preset' && this.selected.patternIds.length > 0) ||
              (this.selected.patternLayout === 'icons' && this.selected.motifIds.length > 0)) {
              this.Adjustment($r('app.string.chat_background_pattern_strength'), 100, 'pattern')
            }
            if (this.selected.mode === 'photo') {
              this.Adjustment($r('app.string.chat_background_blur'), 30, 'blur')
            }
            this.Adjustment($r('app.string.chat_background_dim'), 60, 'dim')
            this.Adjustment($r('app.string.page_background_content_opacity'), 100, 'content')
          }.width('100%').padding(16).borderRadius(20).backgroundColor(cardSurfaceColor(this.displayMode, this.darkSurface))
          Button($r('app.string.page_background_reset')).width('100%').fontColor(this.accentColor)
            .backgroundColor(cardSurfaceColor(this.displayMode, this.darkSurface)).id('page-background-reset')
            .enabled(!this.picking && !this.saving).onClick((): void => { this.reset(); })
        }.width('100%').padding({ left: 16, right: 16, top: this.statusBarHeight + 80, bottom: this.bottomInset + 28 })
      }.width('100%').height('100%').scrollBar(BarState.Off).align(Alignment.TopStart)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    }.scale({ x: this.pageMotion.scale, y: this.pageMotion.scale }).opacity(this.pageMotion.opacity)
      .onReady((context: NavDestinationContext): void => { this.pageMotion.attach(context); })
      .systemTransition(pageSystemTransition(this.pageTransitionMode))
      .titleMode(HdsNavDestinationTitleMode.MINI).hideBackButton(false).bindToScrollable([this.scroller])
      .titleBar({ avoidLayoutSafeArea: true,
        content: { title: { mainTitle: $r('app.string.page_background_title') }, menu: { maxCount: 3, value: [
          { content: { icon: $r('sys.symbol.plus'), label: $r('app.string.page_background_scheme_import'),
            isEnabled: !this.picking && !this.saving, action: (): void => { this.importScheme(); } } },
          { content: { icon: $r('sys.symbol.share'), label: $r('app.string.page_background_scheme_share'),
            isEnabled: !this.picking && !this.saving, action: (): void => { this.shareScheme(); } } },
          { content: { label: $r('app.string.chat_background_apply'), type: TextStyleMode.NORMAL,
            isEnabled: !this.picking && !this.saving, action: (): void => { this.apply(); } } }
        ] } }, style: destinationTitleBarStyle(ScrollEffectType.GRADIENT_BLUR, this.displayMode, this.darkSurface, this.titleBarStyleMode) })
      .backgroundColor(pageSurfaceColor(this.displayMode, this.darkSurface))
      .onBackPressed((): boolean => { ResponsiveLayout.closeContentDestination(this.pageStack); return true; })
  }
}
