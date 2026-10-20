import { HdsTabs, HdsSideBar, hdsMaterial, HdsNavigation, HdsNavigationTitleMode, DividerShowType, BottomBuilderShowType } from '@kit.UIDesignKit';
import { AnimatorResult, curves } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { DEFAULT_BOTTOM_BAR_PAGES_MASK, STORAGE_KEY_BOTTOM_BAR_PAGES } from '../services/BottomBarSettingsStore';
import { pageBackgroundFromValue, PageBackgroundState } from '../services/PageBackgroundStore';
import { PageBackgroundLayer } from './PageBackgroundLayer';
import { SideBarMaterialLayer } from './SideBarMaterialLayer';
import { RootBottomTabItem } from './RootBottomTabItem';
import { HdsButton } from './HdsButton';
import { SystemMaterialUtil } from '../utils/SystemMaterial';
import { TitleBarGlassMaterialCache, customTitleBarGlassEnabled, rootTitleBarStyle } from '../utils/DestinationTitleBar';
import { STORAGE_KEY_CURRENT_APP_ICON } from '../services/AppIconStore';
import { sheetBlurStyle, sheetMaterialOptions } from '../utils/SheetMaterial';
import { fieldSurfaceColor, pageTextColor } from '../utils/ThemeColors';
import { mixedAccentRoleColor } from '../utils/AccentPalette';
import { replyCapsuleControlMaterial } from '../utils/ReplyCapsuleMaterial';
import { ReplyCapsuleLayout } from './ReplyCapsuleLayout';
import { RootTitleBarIdentity } from './RootTitleBarIdentity';
import { RootTitleBarLogo } from './RootTitleBarLogo';
import { AnimatedIconTabs, IconTabItem } from './AnimatedIconTabs';
import { RootTitleBarLayout } from '../utils/RootTitleBarLayout';
import { motionDuration, motionDistance, motionScale, motionCurve, symbolMotionEnabled } from '../utils/AppMotion';
import { hapticConfirm } from '../utils/Haptics';
import { STORAGE_KEY_REDUCE_MOTION, STORAGE_KEY_MOTION_AMPLITUDE, STORAGE_KEY_SYMBOL_EFFECTS } from '../services/MotionSettingsStore';
import { materialModifier } from '../utils/SystemMaterial';
import { DEFAULT_REPLY_CAPSULE_MATERIAL_LEVEL, STORAGE_KEY_REPLY_CAPSULE_MATERIAL_LEVEL,
  DEFAULT_REPLY_CAPSULE_BUTTON_MATERIAL_ENABLED, STORAGE_KEY_REPLY_CAPSULE_BUTTON_MATERIAL_ENABLED,
  STORAGE_KEY_REPLY_CAPSULE_SPLIT_ENABLED, DEFAULT_REPLY_CAPSULE_SPLIT_ENABLED,
  STORAGE_KEY_TITLE_BAR_LOGO, STORAGE_KEY_COMPACT_SWITCH_STYLE, COMPACT_SWITCH_BUTTONS } from '../services/AppearanceStore';

// One compact illustration shows the app's social controls. Scale its whole
// canvas so native materials, tab labels and their edge clearance stay together.
const PREVIEW_WIDTH: number = 360;
const PREVIEW_HEIGHT: number = 280;

@Component
export struct AppearancePreview {
  @Prop kind: string = 'materials';
  @Prop @Watch('replayChanged') replay: number = 0;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp('harmonyx.page_background') private backgroundValue: string = '';
  @StorageProp('harmonyx.display_mode') private displayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private darkSurface: string = '';
  @StorageProp('harmonyx.accent_color') private accent: string = '#007DFF';
  @StorageProp('harmonyx.accent_theme') private accentTheme: string = '#007DFF';
  @StorageProp('harmonyx.title_bar_style_mode') private titleStyle: number = 0;
  @StorageProp('harmonyx.title_bar_glass_material_level') private titleLevel: number = 0;
  @StorageProp(STORAGE_KEY_TITLE_BAR_LOGO) private titleLogo: boolean = true;
  @StorageProp(STORAGE_KEY_CURRENT_APP_ICON) private currentAppIcon: string = '';
  @StorageProp(STORAGE_KEY_COMPACT_SWITCH_STYLE) private compactSwitchStyle: string = 'tabs';
  @StorageProp('harmonyx.home_tab_material_level') private tabLevel: number = 10;
  @StorageProp('harmonyx.classic_bottom_bar') private classicTabs: boolean = false;
  @StorageProp('harmonyx.root_tab_labels_visible') private tabLabels: boolean = true;
  @StorageProp(STORAGE_KEY_BOTTOM_BAR_PAGES) private pagesMask: number = DEFAULT_BOTTOM_BAR_PAGES_MASK;
  @StorageProp('harmonyx.sheet_material_enabled') private sheetEnabled: boolean = true;
  @StorageProp('harmonyx.sheet_material_level') private sheetLevel: number = 2;
  @StorageProp('harmonyx.sidebar_material_type') private sidebarType: number = 0;
  @StorageProp('harmonyx.desktop_rail_material_level') private sidebarLevel: number = -1;
  @StorageProp(STORAGE_KEY_REPLY_CAPSULE_MATERIAL_LEVEL) private replyLevel: number = DEFAULT_REPLY_CAPSULE_MATERIAL_LEVEL;
  @StorageProp(STORAGE_KEY_REPLY_CAPSULE_BUTTON_MATERIAL_ENABLED)
  private replyButtonMaterial: boolean = DEFAULT_REPLY_CAPSULE_BUTTON_MATERIAL_ENABLED;
  @StorageProp(STORAGE_KEY_REPLY_CAPSULE_SPLIT_ENABLED)
  private replySplit: boolean = DEFAULT_REPLY_CAPSULE_SPLIT_ENABLED;
  @StorageProp(STORAGE_KEY_REDUCE_MOTION) @Watch('motionChanged') private reduceMotion: boolean = false;
  @StorageProp(STORAGE_KEY_MOTION_AMPLITUDE) @Watch('motionChanged') private amplitude: number = 1;
  @StorageProp(STORAGE_KEY_SYMBOL_EFFECTS) private symbolEffects: boolean = true;
  @State private lift: number = 0;
  @State private reactionScale: number = 1;
  @State private symbolTrigger: number = -1;
  @State private viewportWidth: number = 0;
  @State private sheetOpen: boolean = false;
  private titleCache: TitleBarGlassMaterialCache = new TitleBarGlassMaterialCache();
  private sheetCache: TitleBarGlassMaterialCache = new TitleBarGlassMaterialCache();
  private titlePathStack: NavPathStack = new NavPathStack();
  private titleScroller: Scroller = new Scroller();
  private motionAnimator: AnimatorResult | undefined = undefined;

  private previewScale(): number { return this.viewportWidth > 0 ? this.viewportWidth / PREVIEW_WIDTH : 1; }

  private replayChanged(): void { if (this.kind === 'motion') { this.playMotion(); } }

  private motionChanged(): void {
    if (this.reduceMotion || this.amplitude <= 0) {
      this.stopMotion();
      this.lift = 0;
      this.reactionScale = 1;
    }
  }

  private stopMotion(): void {
    const previous: AnimatorResult | undefined = this.motionAnimator;
    this.motionAnimator = undefined;
    previous?.cancel();
  }

  aboutToDisappear(): void { this.stopMotion(); }

  private effectsActive(): boolean { return this.symbolEffects && !this.reduceMotion && this.amplitude > 0; }

  private playMotion(feedback: boolean = true): void {
    if (feedback) { hapticConfirm(); }
    if (symbolMotionEnabled()) { this.symbolTrigger++; }
    this.stopMotion();
    if (this.reduceMotion || this.amplitude <= 0) { this.motionChanged(); return; }
    const curve: curves.ICurve = motionCurve();
    const distance: number = motionDistance(-28);
    const scale: number = motionScale(0.78);
    // A fresh native timeline starts every tap, even when the resting pose is
    // unchanged. Sample the app's actual curve on each frame of both legs.
    const animator: AnimatorResult = this.getUIContext().createAnimator({ duration: motionDuration() * 2,
      easing: 'linear', delay: 0, fill: 'forwards', direction: 'normal', iterations: 2, begin: 0, end: 2 });
    this.motionAnimator = animator;
    this.lift = 0;
    this.reactionScale = 1;
    animator.onFrame = (phase: number): void => {
      if (this.motionAnimator !== animator) { return; }
      const progress: number = phase <= 1 ? curve.interpolate(phase) : 1 - curve.interpolate(phase - 1);
      this.lift = distance * progress;
      this.reactionScale = 1 + (scale - 1) * progress;
    };
    animator.onFinish = (): void => {
      if (this.motionAnimator !== animator) { return; }
      this.motionAnimator = undefined;
      this.lift = 0;
      this.reactionScale = 1;
    };
    animator.play();
  }

  private wallpaper(): PageBackgroundState {
    const state: PageBackgroundState = pageBackgroundFromValue(this.backgroundValue);
    return state.enabled ? state : new PageBackgroundState();
  }

  private surface(): ResourceColor { return fieldSurfaceColor(this.displayMode, this.darkSurface); }

  private role(name: string): ResourceColor {
    return mixedAccentRoleColor(this.accentTheme, name, this.accent);
  }

  private ink(secondary: boolean = false, surface: ResourceColor = Color.Transparent): ResourceColor {
    return pageTextColor(secondary ? $r('app.color.text_secondary') : $r('app.color.text_primary'), this.backgroundValue, surface);
  }

  private pages(): number[] {
    const pages: number[] = [];
    for (let page: number = 0; page < 5; page++) {
      if ((this.pagesMask & (1 << page)) !== 0) { pages.push(page); }
    }
    return pages.length >= 2 ? pages : [0, 1, 2, 3, 4];
  }

  private pageIcon(page: number): Resource {
    if (page === 1) { return $r('sys.symbol.magnifyingglass'); }
    if (page === 2) { return $r('sys.symbol.bell_fill'); }
    if (page === 3) { return $r('sys.symbol.message_fill'); }
    if (page === 4) { return $r('sys.symbol.person_fill'); }
    return $r('sys.symbol.house_fill');
  }

  private pageLabel(page: number): Resource {
    if (page === 1) { return $r('app.string.explore_title'); }
    if (page === 2) { return $r('app.string.tab_alerts'); }
    if (page === 3) { return $r('app.string.chat_title'); }
    if (page === 4) { return $r('app.string.tab_me'); }
    return $r('app.string.home_title');
  }

  @Builder
  private Backdrop(): void {
    if (this.wallpaper().enabled) {
      PageBackgroundLayer({ wallpaper: this.wallpaper() })
      Column().width('100%').height('100%').backgroundColor($r('app.color.appearance_preview_canvas')).opacity(0.45)
    } else {
      Column().width('100%').height('100%').backgroundColor($r('app.color.appearance_preview_canvas'))
    }
    Circle().width(240).height(240).fill(this.role('primary')).opacity(0.12).position({ x: 164, y: -60 })
    Circle().width(180).height(180).fill(this.role('action')).opacity(0.09).position({ x: -54, y: 156 })
    Circle().width(178).height(178).fill(Color.Transparent)
      .stroke(this.role('primary')).strokeWidth(1).opacity(0.12).position({ x: 174, y: 36 })
  }

  @Builder
  private ContentLines(): void {
    Column({ space: 9 }) {
      Row().width('92%').height(7).borderRadius(4).backgroundColor(this.ink(true, this.surface())).opacity(0.15)
      Row().width('70%').height(7).borderRadius(4).backgroundColor(this.ink(true, this.surface())).opacity(0.09)
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private PostCard(): void {
    Column({ space: 20 }) {
      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.person_crop_circle_fill')).fontSize($r('app.float.appearance_preview_avatar_size'))
          .fontColor([this.role('profile')])
        Column({ space: 6 }) {
          Text($r('app.string.EntryAbility_label')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
            .fontWeight(FontWeight.Bold).fontColor(this.ink(false, this.surface())).maxLines(1)
          Row().width(46).height(5).borderRadius(3).backgroundColor(this.ink(true, this.surface())).opacity(0.15)
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        SymbolGlyph($r('sys.symbol.ellipsis_circle')).fontSize(18).fontColor([this.ink(true, this.surface())])
      }.width('100%')
      this.ContentLines()
      Row({ space: 18 }) {
        SymbolGlyph($r('sys.symbol.message')).fontSize(20).fontColor([this.role('messages')])
        SymbolGlyph($r('sys.symbol.arrow_2_circlepath')).fontSize(20).fontColor([this.role('control')])
        SymbolGlyph($r('sys.symbol.heart_fill')).fontSize(20).fontColor([this.role('action')])
        Blank()
        SymbolGlyph($r('sys.symbol.bookmark')).fontSize(18).fontColor([this.role('primary')])
      }.width('100%')
    }.width(250).padding(20).borderRadius($r('app.float.appearance_preview_card_radius'))
      .backgroundColor(this.surface())
      .border({ width: 1, color: $r('app.color.appearance_preview_edge') })
      .shadow({ radius: 20, color: $r('app.color.appearance_preview_object_shadow'), offsetY: 10 })
      .id('appearance-preview-post-card')
  }

  @Builder
  private ComposeButton(): void {
    HdsButton({ barWidth: 44, barHeight: 56, iconSize: 24, iconResource: $r('sys.symbol.plus'),
      iconColor: [this.role('action')], forceHdsStyle: true, enableShadow: true, enableHdrHighlight: false })
      .id('appearance-preview-compose')
  }

  @Builder
  private LikeBubble(): void {
    Row({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.heart_fill')).fontSize(26).fontColor([this.role('action')])
      Row().width(20).height(6).borderRadius(3).backgroundColor(this.role('action')).opacity(0.4)
    }.height(50).padding({ left: 16, right: 16 }).borderRadius(25)
      .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
      .border({ width: 1, color: $r('app.color.appearance_preview_edge') })
      .shadow({ radius: 16, color: $r('app.color.appearance_preview_object_shadow'), offsetY: 8 })
      .id('appearance-preview-like')
  }

  @Builder
  private ThemeSample(): void {
    Stack({ alignContent: Alignment.TopStart }) {
      Stack() { this.PostCard() }
        .rotate({ angle: -5 }).position({ x: 42, y: 59 })
      Stack() { this.LikeBubble() }
        .rotate({ angle: 8 }).position({ x: 240, y: 34 })
      Row({ space: 12 }) {
        SymbolGlyph($r('sys.symbol.message_fill')).fontSize(22).fontColor([this.role('messages')])
        Toggle({ type: ToggleType.Switch, isOn: true }).selectedColor(this.role('control')).focusable(false)
      }.height(52).padding({ left: 16, right: 12 }).borderRadius(26)
        .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
        .border({ width: 1, color: $r('app.color.appearance_preview_edge') })
        .shadow({ radius: 16, color: $r('app.color.appearance_preview_object_shadow'), offsetY: 8 })
        .position({ x: 28, y: 209 })
      Stack() { this.ComposeButton() }.position({ x: 270, y: 202 })
    }.width('100%').height('100%').id('appearance-preview-theme-sample')
  }

  @Builder
  private MotionSample(): void {
    Stack({ alignContent: Alignment.TopStart }) {
      Stack() { this.PostCard() }.renderGroup(true)
        .rotate({ angle: -5 + this.lift * 0.12 })
        .translate({ x: this.lift * 0.45, y: this.lift * 0.65 }).position({ x: 42, y: 66 })
        .id('appearance-preview-motion-card')
      Stack() {
        SymbolGlyph($r('sys.symbol.heart_fill')).fontSize(32).fontColor([this.role('action')])
          .symbolEffect(this.effectsActive() ? new BounceSymbolEffect(EffectScope.WHOLE) : new SymbolEffect(),
            this.effectsActive() ? this.symbolTrigger : -1)
      }.width(68).height(68).borderRadius(34).backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
        .border({ width: this.replySplit ? 0 : 1, color: $r('app.color.appearance_preview_edge') })
        .shadow({ radius: 20, color: $r('app.color.appearance_preview_object_shadow'), offsetY: 10 })
        .scale({ x: this.reactionScale, y: this.reactionScale })
        .translate({ x: this.lift * 1.2, y: -this.lift * 0.7 }).position({ x: 246, y: 30 })
        .id('appearance-preview-motion-reaction')
      Stack() { this.ComposeButton() }.translate({ y: this.lift * 0.35 }).position({ x: 272, y: 206 })
    }.width('100%').height('100%')
  }

  @Builder
  private TitleTabs(compact: boolean): void {
    AnimatedIconTabs({ items: [
      { key: 'for-you', label: $r('app.string.home_for_you') } as IconTabItem,
      { key: 'following', label: $r('app.string.home_following') } as IconTabItem
    ], selected: 0, barHeight: compact ? 36 : 54, equalWidth: true,
      buttonStyle: compact && this.compactSwitchStyle === COMPACT_SWITCH_BUTTONS })
      .width('100%').id('appearance-preview-title-tabs')
  }

  @Builder
  private TitleAvatar(): void {
        Button({ type: ButtonType.Circle, stateEffect: false }) {
          SymbolGlyph($r('sys.symbol.person_crop_circle_fill')).fontSize(36).fontColor([this.accent])
        }.width(36).height(36).padding(0).backgroundColor(Color.Transparent)
          .id('appearance-preview-title-identity')
  }

  @Builder
  private TitleAction(): void {
        Button({ type: ButtonType.Circle, stateEffect: false }) {
          SymbolGlyph($r('sys.symbol.person_badge_plus')).fontSize($r('app.float.follow_header_symbol_size'))
            .fontColor([$r('app.color.text_primary')])
        }.width(36).height(36).padding(4).backgroundColor(Color.Transparent)
          .id('appearance-preview-title-action')
  }

  @Builder
  private TitleLogo(): void {
        RootTitleBarLogo().width(30).height(30)
          .id('appearance-preview-title-logo')
  }

  private titlePreviewKey(): string {
    // HDS retains its custom title builder. A structural settings change must
    // mount fresh native slots rather than leave the previous logo arrangement.
    return this.titleLogo.toString() + '|' + this.compactSwitchStyle + '|' + this.currentAppIcon + '|' +
      this.titleStyle.toString() + '|' + this.titleLevel.toString();
  }

  @Builder
  private TitleIdentity(): void {
    RootTitleBarIdentity({ showLogo: this.titleLogo,
      avatar: (): void => { this.TitleAvatar(); },
      center: (): void => { this.TitleTabs(true); },
      action: (): void => { this.TitleAction(); },
      logo: (): void => { this.TitleLogo(); } })
      .width('100%').height(this.titleLogo ? 36 : $r('app.float.title_bar_compact_row_height'))
      .id('appearance-preview-title-identity-row')
  }

  @Builder
  private TitleContent(): void {
    Stack({ alignContent: Alignment.TopStart }) {
      if (customTitleBarGlassEnabled(this.titleStyle)) {
        Column().width('100%').height(this.titleLogo ? 132 : 76).backgroundColor(Color.Transparent)
          .attributeModifier(materialModifier(this.titleCache.material(this.titleLevel))).hitTestBehavior(HitTestMode.None)
          .id('appearance-preview-title-material')
      }
      Stack() { this.TitleIdentity() }.width('100%').height('100%').padding({ left: 12, right: 12 })
      if (this.titleLogo) {
        Column() { this.TitleTabs(false) }.width('100%').padding({ left: 12, right: 12 })
          .position({ x: 0, y: RootTitleBarLayout.labelsOffset(0, true) })
      }
    }.width('100%').height('100%').clip(false)
  }

  @Builder
  private TitleBottom(): void {
    Column().width('100%').height('100%')
  }

  @Builder
  private TitleSpecimen(): void {
    HdsNavigation(this.titlePathStack) {
      List({ scroller: this.titleScroller, space: 18 }) {
        ForEach([0, 1, 2, 3, 4], (index: number): void => {
          ListItem() {
            Column() { this.ContentLines() }.width('100%').padding(20)
          }
        }, (index: number): string => index.toString())
      }.width('100%').height('100%').padding({ top: 16 }).scrollBar(BarState.Off).hitTestBehavior(HitTestMode.None)
    }
    .titleBar({
      avoidLayoutSafeArea: false, enableComponentSafeArea: true,
      content: {
        stackBuilder: (): void => { this.TitleContent(); },
        bottomBuilder: { builder: (): void => { this.TitleBottom(); },
          height: RootTitleBarLayout.bottomHeight(0, this.titleLogo, false, 0, false),
          showType: BottomBuilderShowType.DIRECTLY_SHOW },
        divider: { showType: DividerShowType.OFF }
      },
      style: rootTitleBarStyle(this.displayMode, this.darkSurface, this.titleStyle, false)
    })
    .titleMode(HdsNavigationTitleMode.MINI).mode(NavigationMode.Stack).hideBackButton(true)
    .bindToScrollable([this.titleScroller]).width('92%').height(224)
    .backgroundColor(Color.Transparent).borderRadius($r('app.float.appearance_preview_card_radius')).clip(true)
    .border({ width: 1, color: $r('app.color.appearance_preview_edge') })
    .shadow({ radius: 18, color: $r('app.color.appearance_preview_object_shadow'), offsetY: 9 })
    .id('appearance-preview-native-titlebar')
  }

  @Builder
  private TabLabel(page: number): void {
    RootBottomTabItem({ page: page, icon: this.pageIcon(page), activeIcon: this.pageIcon(page),
      label: this.pageLabel(page), selected: page === this.pages()[0],
      floating: !this.classicTabs, showLabel: this.tabLabels })
      .width('100%').height('100%').id('appearance-preview-tab-' + page.toString())
  }

  @Builder
  private TabContents(): void {
    ForEach(this.pages(), (page: number): void => {
      TabContent() {
        Column() { this.PostCard() }
          .width('100%').height('100%').justifyContent(FlexAlign.Center).padding({ bottom: 88 })
      }.tabBar(this.TabLabel(page))
    }, (page: number): string => page.toString())
  }

  @Builder
  private TabsSample(): void {
    if (this.classicTabs) {
      this.ClassicTabsSample();
    } else {
      if (deviceInfo.apiAvailable('6.1.0(23)')) {
        this.FloatingTabsSample();
      } else {
        this.ClassicTabsSample();
      }
    }
  }

  @Builder
  private ClassicTabsSample(): void {
    Tabs({ index: 0, barPosition: BarPosition.End }) { this.TabContents() }
      .width('100%').height('100%').barHeight($r('app.float.root_tab_bar_height'))
      .barOverlap(true).barBackgroundColor(this.surface()).barBackgroundBlurStyle(BlurStyle.NONE)
      .scrollable(false).id('appearance-preview-classic-tabs')
  }

  @Builder
  private FloatingTabsSample(): void {
      HdsTabs({ index: 0 }) { this.TabContents() }
        .width('100%').height('100%').barPosition(BarPosition.End).barHeight($r('app.float.root_tab_bar_height'))
        .barOverlap(true).barBackgroundColor(Color.Transparent).scrollable(false)
        .barFloatingStyle({ barBottomMargin: 24, barSideMargin: 20, lightColor: this.accent,
          systemMaterialEffect: { materialType: hdsMaterial.MaterialType.IMMERSIVE, materialLevel: this.tabLevel } })
        .id('appearance-preview-native-tabs')
  }

  @Builder
  private ReplyTool(symbol: Resource): void {
    Button({ type: ButtonType.Circle, stateEffect: false }) {
      SymbolGlyph(symbol).fontSize(23).fontColor([$r('sys.color.icon_primary')])
    }.width(42).height(42).padding(0).backgroundColor(Color.Transparent).borderRadius(21).clip(true)
      .attributeModifier(materialModifier(replyCapsuleControlMaterial(this.replyButtonMaterial, this.accent))).focusable(false)
  }

  @Builder
  private ReplyContent(): void {
    Row({ space: 6 }) {
      Button({ type: ButtonType.Circle, stateEffect: false }) {
        SymbolGlyph($r('sys.symbol.person_crop_circle_fill')).fontSize(36).fontColor([this.role('profile')])
      }.width(42).height(42).padding(1).backgroundColor(Color.Transparent).borderRadius(21).clip(true)
        .attributeModifier(materialModifier(replyCapsuleControlMaterial(this.replyButtonMaterial, this.accent))).focusable(false)
      TextArea({ placeholder: $r('app.string.post_detail_reply_placeholder'), text: '' }).fontFamily(this.appFontFamily)
        .layoutWeight(1).height(48).backgroundColor(Color.Transparent).borderRadius(24).clip(true)
        .fontSize($r('sys.float.Body_M')).fontColor($r('sys.color.font_primary'))
        .placeholderColor($r('sys.color.font_secondary')).focusable(false)
        .attributeModifier(materialModifier(replyCapsuleControlMaterial(this.replyButtonMaterial, this.accent, this.titleLevel)))
      this.ReplyTool($r('sys.symbol.picture'))
      this.ReplyTool($r('sys.symbol.arrow_up_left_and_arrow_down_right'))
    }.width('100%').height(64).padding({ left: 10, right: 8 })
  }

  @Builder
  private SplitReplyContent(): void {
    Row({ space: 6 }) {
      SymbolGlyph($r('sys.symbol.square_and_pencil'))
        .fontSize($r('app.float.reply_capsule_split_icon_size')).fontWeight(FontWeight.Medium)
        .fontColor([$r('sys.color.icon_primary')]).flexShrink(0)
      Text($r('app.string.reply_capsule_write_reply')).fontFamily(this.appFontFamily)
        .fontSize(16).fontColor($r('sys.color.font_primary')).maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
    }.width('100%').height($r('app.float.root_tab_bar_height')).padding({ left: 10, right: 10 })
  }

  @Builder
  private ReplyActionSample(symbol: Resource, count: ResourceStr): void {
    Column({ space: 2 }) {
      SymbolGlyph(symbol).fontSize($r('app.float.reply_capsule_split_icon_size')).fontWeight(FontWeight.Medium)
        .fontColor([$r('sys.color.icon_primary')])
      Text(count).fontFamily(this.appFontFamily).fontSize($r('app.float.reply_capsule_split_caption_size')).maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis }).fontColor($r('sys.color.font_secondary'))
    }.width($r('app.float.reply_capsule_split_action_width')).height($r('app.float.root_tab_bar_height'))
      .justifyContent(FlexAlign.Center)
  }

  @Builder
  private ReplyActionsSample(): void {
    Scroll() {
      Row() {
        this.ReplyActionSample($r('sys.symbol.heart'), '237')
        this.ReplyActionSample($r('sys.symbol.ellipsis_bubble'), '12')
        this.ReplyActionSample($r('sys.symbol.bookmark'), '22')
        this.ReplyActionSample($r('sys.symbol.repeat'), '8')
        this.ReplyActionSample($r('sys.symbol.share'), $r('app.string.action_share'))
      }.width($r('app.float.reply_capsule_split_actions_width')).height($r('app.float.root_tab_bar_height'))
    }.width('100%').height($r('app.float.root_tab_bar_height')).padding({ left: 6, right: 6 })
      .scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
  }

  private replySampleHeight(): number {
    return this.replySplit ? this.getUIContext().px2vp(
      getContext(this).resourceManager.getNumber($r('app.float.root_tab_bar_height').id)) : 64;
  }

  @Builder
  private ReplySample(): void {
    Column({ space: 28 }) {
      Column({ space: 12 }) {
        SymbolGlyph($r('sys.symbol.message_fill')).fontSize(38).fontColor([this.role('messages')])
        this.ContentLines()
      }.width('62%').alignItems(HorizontalAlign.Start)
      ReplyCapsuleLayout({ split: this.replySplit, actionWidth: 176, capsuleHeight: this.replySampleHeight(),
        materialEnabled: SystemMaterialUtil.isApi26OrAbove(), materialLevel: this.replyLevel,
        capsuleContent: (): void => {
          if (this.replySplit) { this.SplitReplyContent(); }
          else { this.ReplyContent(); }
        }, postActions: (): void => { this.ReplyActionsSample(); } })
        .width('92%').height(this.replySampleHeight()).borderRadius(this.replySampleHeight() / 2)
        .border({ width: 1, color: $r('app.color.appearance_preview_edge') })
        .shadow({ radius: 20, color: $r('app.color.appearance_preview_object_shadow'), offsetY: 10 })
        .id('appearance-preview-reply')
    }.width('100%').height('100%').justifyContent(FlexAlign.Center)
  }

  @Builder
  private SheetSample(): void {
    Column({ space: 16 }) {
      Column().width(32).height(4).borderRadius(2).backgroundColor(this.ink(true)).opacity(0.4)
      Row({ space: 14 }) {
        SymbolGlyph($r('sys.symbol.message_fill')).fontSize(28).fontColor([this.role('messages')])
        Text($r('app.string.appearance_preview_title')).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Title_S')).fontWeight(FontWeight.Bold).fontColor(this.ink())
      }.width('100%')
      this.ContentLines()
      Row({ space: 14 }) {
        Circle().width(22).height(22).fill(this.role('primary'))
        Circle().width(22).height(22).fill(this.role('messages'))
        Circle().width(22).height(22).fill(this.role('action'))
        Blank()
        SymbolGlyph($r('sys.symbol.plus')).fontSize(24).fontColor([this.role('action')])
      }.width('100%')
    }.width('86%').padding(24).borderRadius($r('app.float.appearance_preview_card_radius'))
      .backgroundColor(this.sheetEnabled ? Color.Transparent : this.surface())
      .backgroundBlurStyle(this.sheetEnabled && !SystemMaterialUtil.isApi26OrAbove() ? sheetBlurStyle(this.sheetLevel) : BlurStyle.NONE)
      .attributeModifier(materialModifier(this.sheetEnabled ? this.sheetCache.material(this.sheetLevel) : undefined))
      .border({ width: 1, color: $r('app.color.appearance_preview_edge') })
      .shadow({ radius: 20, color: $r('app.color.appearance_preview_object_shadow'), offsetY: 10 })
      .id('appearance-preview-sheet')
  }

  @Builder
  private SidebarContent(): void {
    Column({ space: 18 }) {
      SymbolGlyph($r('sys.symbol.person_crop_circle_fill')).fontSize(36).fontColor([this.accent])
      ForEach([0, 4], (page: number): void => {
        Row({ space: 14 }) {
          SymbolGlyph(this.pageIcon(page)).fontSize(24).fontColor([page === 0 ? this.accent : this.ink()])
          Text(this.pageLabel(page)).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontColor(this.ink())
        }.width('100%')
      }, (page: number): string => page.toString())
    }.width('100%').height('100%').padding(24).alignItems(HorizontalAlign.Start)
  }

  @Builder
  private SidebarSample(): void {
    Stack({ alignContent: Alignment.Start }) {
      if (this.sidebarType === 2 && this.sidebarLevel >= 0) {
        HdsSideBar({ sideBarPanelBuilder: (): void => { this.SidebarContent(); }, contentPanelBuilder: (): void => {},
          isShowSideBar: true, sideBarWidth: '100%', minSideBarWidth: '100%', maxSideBarWidth: '100%',
          minContentWidth: 0, sideBarContainerType: SideBarContainerType.Embed, contentAreaMask: false, autoHide: false })
          .width('100%').height('100%')
      } else {
        SideBarMaterialLayer({ materialType: this.sidebarType, materialLevel: this.sidebarLevel, layerPrefix: 'preview-sidebar' })
        this.SidebarContent()
      }
    }.width(218).height(228).borderRadius($r('app.float.appearance_preview_card_radius'))
      .backgroundColor(this.sidebarLevel < 0 ? this.surface() : Color.Transparent).clip(true)
      .border({ width: 1, color: $r('app.color.appearance_preview_edge') })
      .shadow({ radius: 20, color: $r('app.color.appearance_preview_object_shadow'), offsetY: 10 })
      .id('appearance-preview-sidebar')
  }

  @Builder
  private Specimen(): void {
    Stack({ alignContent: Alignment.Center }) {
      this.Backdrop()
      if (this.kind === 'tabmaterial' || this.kind === 'materials') { this.TabsSample() }
      else if (this.kind === 'titlebar') {
        ForEach([this.titlePreviewKey()], (key: string): void => { this.TitleSpecimen(); }, (key: string): string => key)
      }
      else if (this.kind === 'sheetmaterial') { this.SheetSample() }
      else if (this.kind === 'sidebarmaterial') { this.SidebarSample() }
      else if (this.kind === 'replymaterial') { this.ReplySample() }
      else if (this.kind === 'motion') { this.MotionSample() }
      else { this.ThemeSample() }
    }.width(PREVIEW_WIDTH).height(PREVIEW_HEIGHT)
      .constraintSize({ minWidth: PREVIEW_WIDTH, maxWidth: PREVIEW_WIDTH, minHeight: PREVIEW_HEIGHT, maxHeight: PREVIEW_HEIGHT })
      .scale({ x: this.previewScale(), y: this.previewScale(), centerX: 0, centerY: 0 }).position({ x: 0, y: 0 })
      .hitTestBehavior(HitTestMode.None).accessibilityLevel('no-hide-descendants').id('appearance-preview-specimen')
  }

  @Builder
  private ExpandedSheet(): void {
    Column({ space: 16 }) {
      Text($r('app.string.appearance_preview_title')).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Title_S')).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
      Text($r('app.string.page_background_preview_text')).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_secondary'))
    }.width('100%').padding(24)
  }

  build(): void {
    Column({ space: 12 }) {
      Text($r('app.string.appearance_preview_title')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Title_S'))
        .fontColor(this.ink()).width('100%')
      // Clip only the canvas. The separate outer shell leaves room for its
      // floating shadow on every settings page, including native specimens.
      Stack() {
        Stack({ alignContent: Alignment.TopStart }) { this.Specimen() }
          .width('100%').height('100%').borderRadius($r('app.float.appearance_preview_frame_radius')).clip(true)
      }.width('86%').constraintSize({ maxWidth: $r('app.float.appearance_preview_max_width') })
        .aspectRatio(PREVIEW_WIDTH / PREVIEW_HEIGHT).borderRadius($r('app.float.appearance_preview_frame_radius'))
        .backgroundColor(this.surface())
        .border({ width: 1, color: $r('app.color.appearance_preview_edge') })
        .shadow({ radius: 28, color: $r('app.color.appearance_preview_stage_shadow'), offsetY: 14 })
        .margin({ top: 8, bottom: 16 })
        .onAreaChange((_old: Area, area: Area): void => {
          const width: number = Number(area.width);
          if (width > 0 && Math.abs(width - this.viewportWidth) > 0.5) { this.viewportWidth = width; }
        })
        .onClick((): void => {
          if (this.kind === 'sheetmaterial') { this.sheetOpen = true; }
          else if (this.kind === 'motion') { this.playMotion(); }
        })
        .onAppear((): void => { if (this.kind === 'motion') { this.playMotion(false); } })
        .accessibilityText(this.kind === 'motion' ? $r('app.string.motion_preview') : $r('app.string.appearance_preview_title'))
        .bindSheet($$this.sheetOpen, this.ExpandedSheet(), sheetMaterialOptions({
          height: SheetSize.FIT_CONTENT, showClose: true, dragBar: true }, this.sheetEnabled, this.sheetLevel))
        .id('appearance-preview-' + this.kind)
      Text(this.kind === 'motion' ? $r('app.string.motion_preview') : $r('app.string.appearance_preview_hint'))
        .fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S'))
        .fontColor(this.ink(true)).width('100%')
    }.width('100%').padding({ left: 20, right: 20, top: 16, bottom: 16 })
  }
}
