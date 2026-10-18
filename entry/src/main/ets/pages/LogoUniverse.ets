import { appPageBackground } from '../components/PageBackgroundLayer';
import { pageCanvasColor, pageReadingSurfaceColor } from '../utils/ThemeColors';
import { STORAGE_KEY_PAGE_TRANSITION_MODE, DEFAULT_PAGE_TRANSITION_MODE } from '../services/PageTransitionSettingsStore';
import { pageSystemTransition, PageTransitionMotion } from '../utils/PageTransition';
import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { FrameCallback } from '@kit.ArkUI';
import { accountStore, XAccount, STORAGE_KEY_ACCOUNTS_CHANGED } from '../services/AccountStore';
import { proxyImageResolver } from '../services/ProxyImageResolver';
import { logoParticipation, writeLogoKeepsake, saveLogoKeepsake, shareLogoKeepsake } from '../services/LogoKeepsake';
import { sheetMaterialOptions } from '../utils/SheetMaterial';
import { DEFAULT_SHEET_MATERIAL_ENABLED, STORAGE_KEY_SHEET_MATERIAL_ENABLED, STORAGE_KEY_SHEET_MATERIAL_LEVEL } from '../services/SheetMaterialSettingsStore';
import { HdsNavDestination } from '@kit.UIDesignKit';
import { LogoConstellation } from '../components/LogoConstellation';
import { MaterialButton } from '../components/MaterialButton';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';
import { hapticTick } from '../utils/Haptics';

class KeepsakeFrame extends FrameCallback {
  private done: () => void;
  constructor(done: () => void) { super(); this.done = done; }
  onFrame(_time: number): void { this.done(); }
}

@Builder
export function LogoUniverseBuilder(): void { LogoUniverse(); }

@Component
struct LogoUniverse {
  @StorageProp('harmonyx.page_background') private pageBackgroundValue: string = '';
  @State private pageMotion: PageTransitionMotion = new PageTransitionMotion();
  @StorageProp(STORAGE_KEY_PAGE_TRANSITION_MODE) private pageTransitionMode: string = DEFAULT_PAGE_TRANSITION_MODE;
  @StorageProp('harmonyx.compact_window') private compactWindow: boolean = false;
  @StorageProp('harmonyx.breakpoint') private sheetWindowBreakpoint: string = 'sm';
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp('harmonyx.status_bar_height') private topInset: number = 0;
  @StorageProp('harmonyx.navigation_indicator_height') private bottomInset: number = 0;
  @State private visible: boolean = true;
  @State private paused: boolean = false;
  @StorageProp(STORAGE_KEY_ACCOUNTS_CHANGED) @Watch('readAccount') private accountsRevision: number = 0;
  @StorageProp(STORAGE_KEY_SHEET_MATERIAL_ENABLED) private sheetMaterial: boolean = DEFAULT_SHEET_MATERIAL_ENABLED;
  @StorageProp(STORAGE_KEY_SHEET_MATERIAL_LEVEL) private sheetLevel: number = 1;
  @State private personalAvatar: image.PixelMap | null = null;
  @State private personalName: string = '';
  @State private joining: boolean = false;
  @State private exporting: boolean = false;
  @State private showPreview: boolean = false;
  @State private preview: image.PixelMap | null = null;
  @State private status: Resource | null = null;
  @State private saving: boolean = false;
  @State private sharing: boolean = false;
  private accountId: string = '';
  private requestSerial: number = 0;
  private mounted: boolean = true;
  private keepsakePath: string = '';

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  aboutToAppear(): void { this.mounted = true; this.readAccount(); }

  aboutToDisappear(): void {
    this.mounted = false; this.requestSerial++;
    this.detachAvatar();
    const previous: image.PixelMap | null = this.preview;
    this.preview = null;
    if (previous !== null) { setTimeout((): void => { previous.release(); }, 400); }
  }

  private detachAvatar(): void {
    const previous: image.PixelMap | null = this.personalAvatar;
    this.personalAvatar = null;
    if (previous !== null) { setTimeout((): void => { previous.release(); }, 400); }
  }

  private readAccount(): void {
    if (!this.mounted) { return; }
    const account: XAccount | null = accountStore.active(this.context());
    const id: string = account?.id ?? '';
    if (id === this.accountId) { return; }
    this.requestSerial++;
    this.accountId = id;
    this.joining = false;
    this.detachAvatar();
    this.personalName = account?.title() ?? '';
    this.status = null;
    if (id.length > 0 && logoParticipation(this.context(), id)) { this.join(false); }
  }

  private async join(explicit: boolean = true): Promise<void> {
    if (this.joining || this.personalAvatar !== null) { return; }
    const account: XAccount | null = accountStore.active(this.context());
    if (account === null || !account.isUsable()) {
      this.status = $r('app.string.logo_join_login');
      this.pageStack.pushPath({ name: 'Accounts' });
      return;
    }
    if (account.avatarUrl.length === 0) { this.status = $r('app.string.logo_join_failed'); return; }
    this.accountId = account.id;
    this.personalName = account.title();
    this.joining = true;
    this.status = null;
    const serial: number = ++this.requestSerial;
    try {
      const pixels: image.PixelMap | null = await proxyImageResolver.loadForViewer(account.avatarUrl, true);
      if (!this.mounted || serial !== this.requestSerial ||
        accountStore.active(this.context())?.id !== account.id) {
        if (pixels !== null) { pixels.release(); }
        return;
      }
      if (pixels === null) { throw new Error('avatar_unavailable'); }
      this.personalAvatar = pixels;
      if (explicit) { logoParticipation(this.context(), account.id, true); hapticTick(); }
    } catch (error) {
      if (this.mounted && serial === this.requestSerial) {
        this.joining = false; this.status = $r('app.string.logo_join_failed');
      }
    }
  }

  private leave(): void {
    this.requestSerial++;
    logoParticipation(this.context(), this.accountId, false);
    this.joining = false;
    this.detachAvatar();
  }

  private async capture(): Promise<void> {
    if (this.exporting || this.joining) { return; }
    this.exporting = true;
    this.status = null;
    let captured: image.PixelMap | null = null;
    try {
      await new Promise<void>((resolve): void => {
        this.getUIContext().postFrameCallback(new KeepsakeFrame((): void => {
          this.getUIContext().postFrameCallback(new KeepsakeFrame((): void => { resolve(); }));
        }));
      });
      if (!this.mounted) { return; }
      captured = await this.getUIContext().getComponentSnapshot().get('logo-keepsake');
      const path: string = await writeLogoKeepsake(this.context(), captured);
      if (!this.mounted) { captured.release(); captured = null; return; }
      const previous: image.PixelMap | null = this.preview;
      this.preview = captured;
      captured = null;
      if (previous !== null) { previous.release(); }
      this.keepsakePath = path;
      this.showPreview = true;
    } catch (error) {
      if (captured !== null) { captured.release(); }
      this.status = $r('app.string.logo_capture_failed');
    } finally { this.exporting = false; }
  }

  private async save(): Promise<void> {
    if (this.saving || this.keepsakePath.length === 0) { return; }
    this.saving = true;
    try {
      const saved: boolean = await saveLogoKeepsake(this.context(), this.keepsakePath);
      if (saved) { this.status = $r('app.string.logo_saved'); }
    } catch (error) { this.status = $r('app.string.logo_save_failed'); }
    finally { this.saving = false; }
  }

  private async share(): Promise<void> {
    if (this.sharing || this.keepsakePath.length === 0) { return; }
    this.sharing = true;
    try { await shareLogoKeepsake(this.context(), this.keepsakePath, this.label($r('app.string.logo_keepsake'))); }
    catch (error) { this.status = $r('app.string.logo_share_failed'); }
    finally { this.sharing = false; }
  }

  @Builder
  private PreviewSheet(): void {
    Column({ space: 16 }) {
      Text($r('app.string.logo_keepsake')).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Title_S')).fontColor($r('app.color.text_primary'))
      if (this.preview !== null) {
        Image(this.preview).width('100%').layoutWeight(1).objectFit(ImageFit.Contain).borderRadius(16)
      }
      if (this.status !== null) {
        Text(this.status).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
          .fontColor($r('app.color.text_secondary'))
      }
      Row({ space: 12 }) {
        Button($r('app.string.logo_save_gallery')).layoutWeight(1).enabled(!this.saving)
          .onClick((): void => { this.save(); })
        Button($r('app.string.action_share')).layoutWeight(1).enabled(!this.sharing)
          .onClick((): void => { this.share(); })
      }.width('100%')
    }.width('100%').height('100%').padding({ left: 20, right: 20, top: 20, bottom: this.bottomInset + 20 })
  }


  private label(resource: Resource): string {
    try {
      return this.getUIContext().getHostContext()?.resourceManager.getStringSync(resource.id) ?? '';
    } catch (error) { return ''; }
  }

  build(): void {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        appPageBackground()
      Stack({ alignContent: Alignment.Top }) {
        Stack({ alignContent: Alignment.Top }) {
          Column() {
            LogoConstellation({ active: this.visible && !this.showPreview,
              paused: this.paused || this.exporting, personalAvatar: $personalAvatar,
              onJoinSettled: (): void => { this.joining = false; },
              onOwnAvatarTapped: (): void => { hapticTick(); } })
          }
          .width('100%').height('100%')
          .padding({ top: this.topInset + 76, bottom: this.bottomInset + 220 })
          Column({ space: 8 }) {
            Text($r('app.string.app_name')).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Title_S')).fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_on_brand'))
            Text($r('app.string.logo_part_of_you')).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_on_brand'))
            if (this.personalAvatar !== null) {
              Text(this.personalName).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M'))
                .fontColor($r('app.color.logo_particle_blue')).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            }
          }
          .width('100%').height('100%').justifyContent(FlexAlign.End)
          .padding({ left: 24, right: 24, bottom: this.bottomInset + 150 })
          .hitTestBehavior(HitTestMode.None)
        }
        .width('100%').height('100%').backgroundColor($r('app.color.media_viewer_black_background'))
        .id('logo-keepsake')

        Row() {
          MaterialButton({ buttonWidth: 44, buttonHeight: 44, buttonRadius: 22,
            surfaceColor: $r('app.color.media_viewer_control'), materialLevel: 0,
            materialTint: $r('app.color.media_viewer_comment_control_tint'),
            accessibilityLabel: this.label($r('app.string.common_back')),
            onButtonClick: (): void => { hapticTick(); ResponsiveLayout.closeContentDestination(this.pageStack); } }) {
            SymbolGlyph($r('sys.symbol.arrow_left')).fontSize(22).fontColor([$r('app.color.text_on_brand')])
          }
          Blank()
          Text($r('app.string.app_name')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Subtitle_L')).fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_on_brand'))
          Blank()
          MaterialButton({ buttonWidth: 44, buttonHeight: 44, buttonRadius: 22,
            surfaceColor: $r('app.color.media_viewer_control'), materialLevel: 0,
            materialTint: $r('app.color.media_viewer_comment_control_tint'),
            accessibilityLabel: this.label(this.paused ? $r('app.string.logo_motion_play') : $r('app.string.logo_motion_pause')),
            onButtonClick: (): void => { hapticTick(); this.paused = !this.paused; } }) {
            SymbolGlyph(this.paused ? $r('sys.symbol.play_fill') : $r('sys.symbol.pause_fill'))
              .fontSize(20).fontColor([$r('app.color.text_on_brand')])
          }
        }
        .width('100%').padding({ left: 20, right: 20, top: this.topInset + 12 })

        Column({ space: 10 }) {
          Text($r('app.string.logo_touch_hint')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_S')).fontColor($r('app.color.video_feed_secondary_text'))
            .textAlign(TextAlign.Center)
          if (this.status !== null && !this.showPreview) {
            Text(this.status).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S'))
              .fontColor($r('app.color.video_feed_secondary_text'))
          }
          Row({ space: 12 }) {
            Button(this.joining ? $r('app.string.status_loading') : this.personalAvatar === null ?
              $r('app.string.logo_join') : $r('app.string.logo_leave'))
              .fontSize($r('sys.float.Body_M')).layoutWeight(1).enabled(!this.joining && !this.exporting)
              .backgroundColor($r('app.color.logo_particle_blue')).fontColor($r('app.color.text_on_brand'))
              .onClick((): void => { if (this.personalAvatar === null) { this.join(); } else { this.leave(); } })
            Button($r('app.string.logo_keepsake')).fontSize($r('sys.float.Body_M')).layoutWeight(1)
              .enabled(!this.exporting && !this.joining)
              .backgroundColor($r('app.color.media_viewer_control')).fontColor($r('app.color.text_on_brand'))
              .onClick((): void => { this.capture(); })
          }.width('100%')
        }
        .width('100%').padding({ left: 24, right: 24, bottom: this.bottomInset + 24 })
        .height('100%').justifyContent(FlexAlign.End)
        .hitTestBehavior(HitTestMode.Transparent)
      }
      .width('100%').height('100%').backgroundColor($r('app.color.media_viewer_black_background'))
    
      }.width('100%').height('100%')
    }
    .scale({ x: this.pageMotion.scale, y: this.pageMotion.scale })
    .opacity(this.pageMotion.opacity)
    .onReady((context: NavDestinationContext): void => { this.pageMotion.attach(context); })
    .systemTransition(pageSystemTransition(this.pageTransitionMode))
    .hideTitleBar(true)
    .bindSheet($$this.showPreview, this.PreviewSheet(), sheetMaterialOptions({ height: SheetSize.LARGE,
      showClose: true, dragBar: true, backgroundColor: $r('app.color.bg_page') }, this.sheetMaterial, this.sheetLevel,
      this.sheetWindowBreakpoint, this.compactWindow))
    .onShown((): void => { this.visible = true; this.readAccount(); })
    .onHidden((): void => { this.visible = false; })
    .onBackPressed((): boolean => { ResponsiveLayout.closeContentDestination(this.pageStack); return true; })
  }
}
