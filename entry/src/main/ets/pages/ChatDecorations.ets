import { common } from '@kit.AbilityKit';
import { HdsNavDestination, HdsNavDestinationTitleMode, ScrollEffectType, TextStyleMode } from '@kit.UIDesignKit';
import { STORAGE_KEY_PAGE_TRANSITION_MODE, DEFAULT_PAGE_TRANSITION_MODE } from '../services/PageTransitionSettingsStore';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { chatDecorationService, ChatDecorationCatalogItem, ChatDecorationInstall,
  ChatDecorationSelection } from '../services/ChatDecorationService';
import { effectiveAppLocale, STORAGE_KEY_APP_LOCALE } from '../utils/AppLocale';
import { pageSystemTransition, PageTransitionMotion } from '../utils/PageTransition';
import { destinationTitleBarStyle } from '../utils/DestinationTitleBar';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';
import { cardSurfaceColor, pageSurfaceColor, secondaryButtonSurfaceColor } from '../utils/ThemeColors';
import { xPrivateStore } from '../services/XPrivateStore';

export interface ChatDecorationsRouteParam {
  conversationId: string;
}

@Builder
export function ChatDecorationsBuilder(): void { ChatDecorationsPage(); }

@Component
struct ChatDecorationsPage {
  @State private pageMotion: PageTransitionMotion = new PageTransitionMotion();
  @StorageProp(STORAGE_KEY_PAGE_TRANSITION_MODE) private pageTransitionMode: string = DEFAULT_PAGE_TRANSITION_MODE;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp(STORAGE_KEY_APP_LOCALE) private appLocale: string = effectiveAppLocale();
  @StorageProp('harmonyx.status_bar_height') private statusBarHeight: number = 0;
  @StorageProp('harmonyx.navigation_indicator_height') private bottomInset: number = 0;
  @StorageProp('harmonyx.display_mode') private displayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private darkSurface: string = '';
  @StorageProp('harmonyx.title_bar_style_mode') private titleBarStyleMode: number = 0;
  @StorageLink('harmonyx.accent_color') private accentColor: string = '#007DFF';
  @Consume('pageStack') private pageStack: NavPathStack;
  @State private catalog: ChatDecorationCatalogItem[] = [];
  @State private installedItems: ChatDecorationInstall[] = [];
  @State private selection: ChatDecorationSelection = new ChatDecorationSelection();
  @State private role: string = 'frame';
  @State private loading: boolean = true;
  @State private downloadingId: string = '';
  @State private failed: boolean = false;
  private account: string = '';
  private active: boolean = true;
  private scroller: Scroller = new Scroller();

  private context(): common.UIAbilityContext { return getContext(this) as common.UIAbilityContext; }

  private text(resource: Resource): string {
    return this.context().resourceManager.getStringSync(resource);
  }

  aboutToAppear(): void {
    this.account = xPrivateStore.load(this.context()).cacheIdentity();
    this.selection = chatDecorationService.selection(this.context());
    this.load();
  }

  aboutToDisappear(): void { this.active = false; }

  private valid(): boolean {
    return this.active && this.account === xPrivateStore.load(this.context()).cacheIdentity();
  }

  private async load(): Promise<void> {
    this.loading = true;
    this.failed = false;
    try {
      const items: ChatDecorationCatalogItem[] = await chatDecorationService.catalog();
      if (!this.valid()) { return; }
      const installs: ChatDecorationInstall[] = [];
      for (let i: number = 0; i < items.length; i++) {
        const install: ChatDecorationInstall | null = chatDecorationService.installed(this.context(), items[i].id);
        if (install !== null) { installs.push(install); }
      }
      this.catalog = items;
      this.installedItems = installs;
      this.failed = items.length === 0;
    } catch (error) {
      if (this.valid()) { this.failed = true; }
    } finally {
      if (this.valid()) { this.loading = false; }
    }
  }

  private installFor(item: ChatDecorationCatalogItem): ChatDecorationInstall | null {
    for (let i: number = 0; i < this.installedItems.length; i++) {
      if (this.installedItems[i].id === item.id) { return this.installedItems[i]; }
    }
    return null;
  }

  private rememberInstall(value: ChatDecorationInstall): void {
    const next: ChatDecorationInstall[] = [];
    let replaced: boolean = false;
    for (let i: number = 0; i < this.installedItems.length; i++) {
      if (this.installedItems[i].id === value.id) {
        next.push(value);
        replaced = true;
      } else {
        next.push(this.installedItems[i]);
      }
    }
    if (!replaced) { next.push(value); }
    this.installedItems = next;
  }

  private localizedName(item: ChatDecorationCatalogItem): string {
    if (this.appLocale.startsWith('zh') || item.nameEn.length === 0) { return item.name; }
    return item.nameEn;
  }

  private selectedId(): string {
    return this.role === 'frame' ? this.selection.frameId : this.selection.bubbleId;
  }

  private hasSelection(): boolean {
    return this.selection.frameId.length > 0 || this.selection.bubbleId.length > 0;
  }

  private sizeLabel(bytes: number): string {
    return (bytes / 1024 / 1024).toFixed(1) + ' MB';
  }

  private canPress(item: ChatDecorationCatalogItem): boolean {
    return this.downloadingId.length === 0 &&
      (this.downloadingId.length === 0 || this.downloadingId === item.id);
  }

  private toast(resource: Resource): void {
    this.getUIContext().getPromptAction().showToast({
      message: this.text(resource),
      duration: 1800
    });
  }

  private async useItem(item: ChatDecorationCatalogItem): Promise<void> {
    if (!this.canPress(item)) { return; }
    let install: ChatDecorationInstall | null = this.installFor(item);
    if (install !== null && this.selectedId() === item.id) {
      this.selection = chatDecorationService.clear(this.context(), this.role);
      return;
    }
    try {
      if (install === null) {
        this.downloadingId = item.id;
        install = await chatDecorationService.install(this.context(), item);
        if (!this.valid()) { return; }
        this.rememberInstall(install);
      }
      this.selection = chatDecorationService.apply(this.context(), install, this.role);
      this.toast($r('app.string.chat_decoration_applied'));
    } catch (error) {
      if (this.valid()) { this.toast($r('app.string.chat_decoration_download_failed')); }
    } finally {
      if (this.active) { this.downloadingId = ''; }
    }
  }

  private reset(): void {
    if (!this.hasSelection()) { return; }
    this.selection = chatDecorationService.clear(this.context(), 'frame');
    this.selection = chatDecorationService.clear(this.context(), 'bubble');
    this.toast($r('app.string.chat_decoration_reset_done'));
  }

  @Builder
  private RoleTabs(): void {
    Row() {
      Button($r('app.string.chat_decoration_frame'))
        .layoutWeight(1).height(42).borderRadius(21)
        .fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
        .fontColor(this.role === 'frame' ? $r('app.color.text_on_accent') : $r('app.color.text_primary'))
        .backgroundColor(this.role === 'frame' ? this.accentColor : Color.Transparent)
        .onClick((): void => { this.role = 'frame'; })
      Button($r('app.string.chat_decoration_bubble'))
        .layoutWeight(1).height(42).borderRadius(21)
        .fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
        .fontColor(this.role === 'bubble' ? $r('app.color.text_on_accent') : $r('app.color.text_primary'))
        .backgroundColor(this.role === 'bubble' ? this.accentColor : Color.Transparent)
        .onClick((): void => { this.role = 'bubble'; })
    }.width('100%').padding(3).borderRadius(24)
      .backgroundColor(secondaryButtonSurfaceColor(this.displayMode, this.darkSurface))
  }

  @Builder
  private FramePreview(item: ChatDecorationCatalogItem): void {
    Stack({ alignContent: Alignment.Center }) {
      Column().width(72).height(72).borderRadius(36).backgroundColor(this.accentColor)
      Text(this.localizedName(item).substring(0, 1)).fontFamily(this.appFontFamily).fontSize(24)
        .fontWeight(FontWeight.Bold).fontColor($r('app.color.text_on_accent'))
      if (this.installFor(item) !== null) {
        Image((this.installFor(item) as ChatDecorationInstall).frameUri)
          .width(118).height(118).objectFit(ImageFit.Contain)
          .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
      } else {
        SymbolGlyph($r('sys.symbol.paintpalette')).fontSize(28)
          .fontColor([$r('app.color.text_secondary')]).position({ x: 82, y: 8 })
      }
    }.width(122).height(122)
  }

  @Builder
  private BubblePreview(item: ChatDecorationCatalogItem): void {
    if (this.installFor(item) !== null) {
      Stack({ alignContent: Alignment.Center }) {
        Column()
          .width('100%').height(94)
          .backgroundImage((this.installFor(item) as ChatDecorationInstall).bubbleUri)
          .backgroundImageSize({ width: '100%', height: '100%' })
          .backgroundImageResizable({ slice: {
            left: (this.installFor(item) as ChatDecorationInstall).sliceLeft.toString() + 'px',
            right: (this.installFor(item) as ChatDecorationInstall).sliceRight.toString() + 'px',
            top: (this.installFor(item) as ChatDecorationInstall).sliceTop.toString() + 'px',
            bottom: (this.installFor(item) as ChatDecorationInstall).sliceBottom.toString() + 'px'
          } })
        Text($r('app.string.chat_decoration_sample_text')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M'))
          .fontColor((this.installFor(item) as ChatDecorationInstall).bubbleTextColor)
          .maxLines(2).textAlign(TextAlign.Center).padding({ left: 38, right: 38 })
      }.width('100%').height(94)
    } else {
      Column({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.line_message')).fontSize(30)
          .fontColor([$r('app.color.text_secondary')])
        Text($r('app.string.chat_decoration_download_preview')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_S')).fontColor($r('app.color.text_secondary'))
      }.width('100%').height(94).justifyContent(FlexAlign.Center)
        .border({ width: 1, color: $r('app.color.divider'), style: BorderStyle.Dashed })
        .borderRadius(16)
    }
  }

  @Builder
  private ItemCard(item: ChatDecorationCatalogItem): void {
    Column({ space: 14 }) {
      Row({ space: 8 }) {
        Text(this.localizedName(item)).fontFamily(this.appFontFamily).fontSize($r('sys.float.Title_S'))
          .fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary')).layoutWeight(1)
        if (this.selectedId() === item.id) {
          Text($r('app.string.chat_decoration_in_use')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_S')).fontColor(this.accentColor)
        }
        Text($r('app.string.chat_decoration_free')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_S')).fontColor(this.accentColor)
      }.width('100%')
      if (this.appLocale.startsWith('zh') && item.description.length > 0) {
        Text(item.description).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
          .fontColor($r('app.color.text_secondary')).width('100%')
      }
      if (this.role === 'frame') { this.FramePreview(item); }
      else { this.BubblePreview(item); }
      Row({ space: 12 }) {
        if (this.installFor(item) === null) {
          Text(this.sizeLabel(item.bytes)).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S'))
            .fontColor($r('app.color.text_secondary')).layoutWeight(1)
        } else {
          Text($r('app.string.chat_decoration_installed')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_S')).fontColor($r('app.color.text_secondary')).layoutWeight(1)
        }
        Button(this.downloadingId === item.id ? $r('app.string.chat_decoration_downloading') :
          this.installFor(item) === null ? $r('app.string.chat_decoration_download') :
          this.selectedId() === item.id ? $r('app.string.chat_decoration_remove') :
          $r('app.string.chat_decoration_use'))
          .height(40).padding({ left: 18, right: 18 }).borderRadius(20)
          .fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
          .fontColor(this.selectedId() === item.id ? this.accentColor : $r('app.color.text_on_accent'))
          .backgroundColor(this.selectedId() === item.id ?
            secondaryButtonSurfaceColor(this.displayMode, this.darkSurface) : this.accentColor)
          .enabled(this.downloadingId.length === 0)
          .onClick((): void => { this.useItem(item); })
      }.width('100%')
    }.width('100%').padding(18).borderRadius(22)
      .backgroundColor(cardSurfaceColor(this.displayMode, this.darkSurface))
  }

  @Builder
  private Content(): void {
    Column({ space: 16 }) {
      Column({ space: 6 }) {
        Text($r('app.string.chat_decoration_subtitle')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary')).width('100%')
        Text($r('app.string.chat_decoration_note')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Body_S')).fontColor($r('app.color.text_secondary')).width('100%')
      }.width('100%')
      this.RoleTabs()
      if (this.loading) {
        Column({ space: 10 }) {
          LoadingProgress().width(28).height(28).color(this.accentColor)
          Text($r('app.string.chat_decoration_loading')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary'))
        }.width('100%').height(180).justifyContent(FlexAlign.Center)
      } else if (this.failed || this.catalog.length === 0) {
        Column({ space: 12 }) {
          SymbolGlyph($r('sys.symbol.exclamationmark_triangle')).fontSize(30)
            .fontColor([$r('app.color.text_secondary')])
          Text($r('app.string.chat_decoration_unavailable')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary')).textAlign(TextAlign.Center)
          Button($r('app.string.common_retry')).height(40).borderRadius(20)
            .fontFamily(this.appFontFamily).fontColor($r('app.color.text_on_accent')).backgroundColor(this.accentColor)
            .onClick((): void => { this.load(); })
        }.width('100%').height(180).justifyContent(FlexAlign.Center)
      } else {
        ForEach(this.catalog, (item: ChatDecorationCatalogItem) => {
          this.ItemCard(item)
        }, (item: ChatDecorationCatalogItem): string => item.id)
      }
      if (this.hasSelection()) {
        Button($r('app.string.chat_decoration_reset')).width('100%').height(46).borderRadius(23)
          .fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
          .fontColor($r('app.color.text_primary'))
          .backgroundColor(secondaryButtonSurfaceColor(this.displayMode, this.darkSurface))
          .enabled(this.downloadingId.length === 0).onClick((): void => { this.reset(); })
      }
    }.width('100%').padding({ left: 16, right: 16, top: this.statusBarHeight + 80,
      bottom: this.bottomInset + 28 })
  }

  build(): void {
    HdsNavDestination() {
      Scroll(this.scroller) {
        this.Content()
      }.width('100%').height('100%').scrollBar(BarState.Off).align(Alignment.Top)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    }
    .scale({ x: this.pageMotion.scale, y: this.pageMotion.scale })
    .opacity(this.pageMotion.opacity)
    .onReady((context: NavDestinationContext): void => { this.pageMotion.attach(context); })
    .systemTransition(pageSystemTransition(this.pageTransitionMode))
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .hideBackButton(false)
    .bindToScrollable([this.scroller])
    .titleBar({ avoidLayoutSafeArea: true,
      content: { title: { mainTitle: $r('app.string.chat_decoration') } },
      style: destinationTitleBarStyle(ScrollEffectType.GRADIENT_BLUR, this.displayMode,
        this.darkSurface, this.titleBarStyleMode)
    })
    .backgroundColor(pageSurfaceColor(this.displayMode, this.darkSurface))
    .onBackPressed((): boolean => {
      ResponsiveLayout.closeContentDestination(this.pageStack);
      return true;
    })
  }
}
