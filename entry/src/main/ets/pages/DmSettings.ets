import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { DEFAULT_SHEET_MATERIAL_LEVEL, STORAGE_KEY_SHEET_MATERIAL_ENABLED, STORAGE_KEY_SHEET_MATERIAL_LEVEL } from '../services/SheetMaterialSettingsStore';
import { sheetMaterialOptions } from '../utils/SheetMaterial';
import { common } from '@kit.AbilityKit';
import promptAction from '@ohos.promptAction';
import { HdsNavDestination, HdsNavDestinationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { ChatPinPad } from '../components/ChatPinPad';
import { ChatSettings, xChatActions } from '../services/XChatActions';
import { xChatService } from '../services/XChatService';
import { ChatMediaStats, xChatMedia } from '../services/XChatMedia';
import { xPrivateClient } from '../services/XPrivateClient';
import { xPrivateStore } from '../services/XPrivateStore';
import { notificationSettingsStore } from '../services/NotificationSettingsStore';
import { pageSurfaceColor } from '../utils/ThemeColors';
import { destinationTitleBarStyle } from '../utils/DestinationTitleBar';
import { chatPageMaterial } from '../utils/ChatMaterial';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';

export interface DmSettingsRouteParam { section: string; }

@Builder
export function DmSettingsBuilder(): void { DmSettingsPage(); }

@Component
struct DmSettingsPage {
  @StorageProp('harmonyx.compact_window') private sheetCompactWindow: boolean = false;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp('harmonyx.breakpoint') private sheetWindowBreakpoint: string = 'sm';
  @StorageProp(STORAGE_KEY_SHEET_MATERIAL_ENABLED) private sheetMaterialEnabled: boolean = false;
  @StorageProp(STORAGE_KEY_SHEET_MATERIAL_LEVEL) private sheetMaterialLevel: number = DEFAULT_SHEET_MATERIAL_LEVEL;
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp('harmonyx.status_bar_height') statusBarHeight: number = 0;
  @StorageProp('harmonyx.navigation_indicator_height') bottomInset: number = 0;
  @StorageProp('harmonyx.display_mode') displayMode: string = '';
  @StorageProp('harmonyx.dark_surface') darkSurface: string = '';
  @StorageLink('harmonyx.accent_color') accentColor: string = '#007DFF';
  @StorageProp('harmonyx.title_bar_style_mode') titleBarStyleMode: number = 0;
  @State private username: string = '';
  @State private section: string = '';
  @State private settings: ChatSettings | null = null;
  @State private busy: boolean = false;
  @State private failure: string = '';
  @State private onlyChatPush: boolean = false;
  @State private photoPolicy: string = 'all';
  @State private videoPolicy: string = 'all';
  @State private documentPolicy: string = 'all';
  @State private retention: string = '30';
  @State private mediaStats: ChatMediaStats = { photos: 0, documents: 0, voice: 0, total: 0 };
  @State private pinSheet: boolean = false;
  @State private pinStep: number = 0;
  @State private pinError: string = '';
  private oldPin: string = '';
  private newPin: string = '';
  private active: boolean = true;
  private account: string = '';
  private scroller: Scroller = new Scroller();

  private context(): common.UIAbilityContext { return getContext(this) as common.UIAbilityContext; }
  private text(resource: Resource): string { return this.context().resourceManager.getStringSync(resource); }
  aboutToAppear(): void {
    const params: DmSettingsRouteParam[] = this.pageStack.getParamByName('DmSettings') as DmSettingsRouteParam[];
    this.section = params.length > 0 ? params[params.length - 1].section : '';
    const context: common.UIAbilityContext = this.context();
    xPrivateClient.load(context);
    this.account = xPrivateStore.load(context).cacheIdentity();
    this.username = xPrivateStore.load(context).username;
    this.onlyChatPush = xChatActions.localBoolean(context, 'only_chat_push', false);
    this.photoPolicy = xChatActions.localString(context, 'download_photos', 'all');
    this.videoPolicy = xChatActions.localString(context, 'download_videos', 'all');
    this.documentPolicy = xChatActions.localString(context, 'download_documents', 'all');
    this.retention = xChatActions.localString(context, 'retention_days', '30');
    xChatMedia.initialize(context); this.mediaStats = xChatMedia.stats();
    this.load();
  }
  aboutToDisappear(): void { this.active = false; this.oldPin = ''; this.newPin = ''; }
  private valid(): boolean { return this.active && this.account === xPrivateStore.load(this.context()).cacheIdentity(); }
  private async load(): Promise<void> {
    this.busy = true; this.failure = '';
    try { const settings: ChatSettings = await xChatActions.settings(); if (this.valid()) { this.settings = settings; } }
    catch (error) { if (this.valid()) { this.failure = this.text($r('app.string.chat_action_failed')); } }
    finally { if (this.valid()) { this.busy = false; } }
  }
  private async update(field: string, value: string | boolean): Promise<void> {
    if (this.busy || this.settings === null) { return; }
    // Keep all settings from the latest server response, including permissions
    // not represented by the three audience options on this page.
    const next: ChatSettings = JSON.parse(JSON.stringify(this.settings)) as ChatSettings;
    if (field === 'requests') { next.allow_dms_from = value as string; }
    else if (field === 'calls') { next.av_settings.has_av_calls_enabled = value as boolean; }
    else if (field === 'relay') { next.av_settings.has_enhanced_call_privacy_enabled = value as boolean; }
    else if (field === 'call_audience') {
      const audience: string = value as string;
      next.av_settings.av_call_permissions.accept_calls_from_everyone = audience === 'all';
      next.av_settings.av_call_permissions.accept_calls_from_following = audience === 'following';
      next.av_settings.av_call_permissions.accept_calls_from_verified = audience === 'verified';
    }
    this.busy = true; this.failure = '';
    try { const confirmed: ChatSettings = await xChatActions.updateSettings(next); if (this.valid()) { this.settings = confirmed; } }
    catch (error) { if (this.valid()) { this.failure = this.text($r('app.string.chat_action_failed')); } }
    finally { if (this.valid()) { this.busy = false; } }
  }
  private open(section: string): void {
    const param: DmSettingsRouteParam = { section: section };
    this.pageStack.pushPath({ name: 'DmSettings', param: param });
  }
  private title(): Resource {
    if (this.section === 'notifications') { return $r('app.string.chat_notifications'); }
    if (this.section === 'requests') { return $r('app.string.chat_dm_requests'); }
    if (this.section === 'calls') { return $r('app.string.chat_calls'); }
    if (this.section === 'data') { return $r('app.string.chat_data'); }
    if (this.section === 'storage') { return $r('app.string.chat_storage'); }
    return $r('app.string.chat_settings');
  }
  private audience(value: string): Resource {
    return value === 'all' ? $r('app.string.chat_everyone') : value === 'verified' ?
      $r('app.string.chat_verified') : $r('app.string.chat_following');
  }
  private policy(value: string): Resource {
    return value === 'never' ? $r('app.string.chat_never') : value === 'wifi' ?
      $r('app.string.chat_wifi') : $r('app.string.chat_wifi_cellular');
  }
  private savePolicy(key: string, value: string): void {
    xChatActions.saveLocal(this.context(), key, value);
    if (key === 'download_photos') { this.photoPolicy = value; }
    if (key === 'download_videos') { this.videoPolicy = value; }
    if (key === 'download_documents') { this.documentPolicy = value; }
    if (key === 'retention_days') { this.retention = value; xChatMedia.prune(this.context()); this.mediaStats = xChatMedia.stats(); }
  }
  private bytes(value: number): string {
    return value < 1024 ? value.toString() + ' B' : value < 1048576 ? (value / 1024).toFixed(1) + ' KB' : (value / 1048576).toFixed(1) + ' MB';
  }
  private clearMedia(): void { xChatMedia.clear(); this.mediaStats = xChatMedia.stats(); }
  private async pin(value: string): Promise<void> {
    if (this.pinStep === 0) { this.oldPin = value; this.pinStep = 1; return; }
    if (this.pinStep === 1) { this.newPin = value; this.pinStep = 2; return; }
    if (value !== this.newPin) { this.pinError = this.text($r('app.string.chat_pin_mismatch')); return; }
    this.busy = true; this.pinError = '';
    try {
      await xChatService.changePin(this.context(), this.oldPin, this.newPin);
      if (this.valid()) { this.pinSheet = false; promptAction.showToast({ message: this.text($r('app.string.chat_pin_changed')) }); }
    } catch (error) {
      if (this.valid()) { this.pinError = this.text($r('app.string.chat_action_failed')); this.pinStep = 0; }
    } finally { this.oldPin = ''; this.newPin = ''; if (this.valid()) { this.busy = false; } }
  }
  private async reset(): Promise<void> {
    const response: promptAction.ShowDialogSuccessResponse = await promptAction.showDialog({
      message: this.text($r('app.string.chat_reset_confirm')),
      buttons: [{ text: this.text($r('app.string.compose_cancel')), color: '' },
        { text: this.text($r('app.string.chat_reset')), color: '' }]
    });
    if (response.index !== 1 || !this.valid()) { return; }
    xChatMedia.clear(); xChatService.lock();
    this.pageStack.pop();
  }
  @Builder
  private PinSheet(): void {
    ChatPinPad({ title: this.pinStep === 0 ? $r('app.string.chat_pin_old') :
      this.pinStep === 1 ? $r('app.string.chat_pin_create') : $r('app.string.chat_pin_confirm'),
      busy: this.busy, error: this.pinError, onSubmit: (pin: string): void => { this.pin(pin); },
      onClose: (): void => { this.pinSheet = false; this.oldPin = ''; this.newPin = ''; } })
  }
  @Builder
  private Option(symbol: Resource, title: Resource, value: ResourceStr = '', danger: boolean = false): void {
    Row({ space: 20 }) {
      SymbolGlyph(symbol).fontSize(24).fontColor([danger ? $r('app.color.danger') : $r('app.color.text_secondary')])
      Text(title).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontColor(danger ? $r('app.color.danger') : $r('app.color.text_primary')).layoutWeight(1)
      if (value !== '') { Text(value).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary')) }
      SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(18).fontColor([$r('app.color.text_secondary')])
    }.width('100%').constraintSize({ minHeight: 60 }).padding({ left: 16, right: 20 })
  }
  @Builder
  private AudienceMenu(field: string): void {
    Menu() {
      MenuItem({ content: $r('app.string.chat_following') }).onClick((): void => { this.update(field, 'following'); })
      MenuItem({ content: $r('app.string.chat_verified') }).onClick((): void => { this.update(field, 'verified'); })
      MenuItem({ content: $r('app.string.chat_everyone') }).onClick((): void => { this.update(field, 'all'); })
    }
  }
  @Builder
  private PolicyMenu(key: string): void {
    Menu() {
      MenuItem({ content: $r('app.string.chat_wifi_cellular') }).onClick((): void => this.savePolicy(key, 'all'))
      MenuItem({ content: $r('app.string.chat_wifi') }).onClick((): void => this.savePolicy(key, 'wifi'))
      MenuItem({ content: $r('app.string.chat_never') }).onClick((): void => this.savePolicy(key, 'never'))
    }
  }
  @Builder
  private ToggleRow(title: Resource, hint: Resource, enabled: boolean, field: string): void {
    Row({ space: 16 }) {
      Column({ space: 6 }) {
        Text(title).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_primary'))
        Text(hint).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary'))
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Toggle({ type: ToggleType.Switch, isOn: enabled }).selectedColor(this.accentColor).enabled(!this.busy)
        .onChange((value: boolean): void => {
          if (field === 'push') {
            if (value) { xChatActions.saveLocal(this.context(), 'alerts_before_chat_only', notificationSettingsStore.loadAlertsEnabled(this.context())); }
            xChatActions.saveLocal(this.context(), 'only_chat_push', value);
            notificationSettingsStore.saveAlertsEnabled(this.context(), value ? false :
              xChatActions.localBoolean(this.context(), 'alerts_before_chat_only', true));
            this.onlyChatPush = value;
          } else { this.update(field, value); }
        })
    }.width('100%').padding(16)
  }
  @Builder
  private Body(): void {
    Column() {
      if (this.section === '') {
        Column() { this.Option($r('sys.symbol.bell'), $r('app.string.chat_notifications')) }
          .onClick((): void => this.open('notifications'))
        Column() { this.Option($r('sys.symbol.envelope'), $r('app.string.chat_dm_requests')) }
          .onClick((): void => this.open('requests'))
        Column() { this.Option($r('sys.symbol.video'), $r('app.string.chat_calls')) }.onClick((): void => this.open('calls'))
        Column() { this.Option($r('sys.symbol.lock'), $r('app.string.chat_change_pin')) }.onClick((): void => {
          if (!xChatService.isUnlocked()) { promptAction.showToast({ message: this.text($r('app.string.dm_unlock_hint')) }); return; }
          this.pinStep = 0; this.pinError = ''; this.pinSheet = true;
        })
        Column() { this.Option($r('sys.symbol.clock'), $r('app.string.chat_data')) }.onClick((): void => this.open('data'))
        Column() { this.Option($r('sys.symbol.doc'), $r('app.string.chat_storage')) }.onClick((): void => this.open('storage'))
        Column() { this.Option($r('sys.symbol.info_circle'), $r('app.string.chat_help')) }.onClick((): void => {
          this.pageStack.pushPath({ name: 'HelpCenter' });
        })
      } else if (this.section === 'notifications') {
        this.ToggleRow($r('app.string.chat_only_push'), $r('app.string.chat_only_push_hint'), this.onlyChatPush, 'push')
      } else if (this.section === 'requests') {
        Row() {
          Text($r('app.string.chat_requests_from')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_primary')).layoutWeight(1)
          Text(this.audience(this.settings?.allow_dms_from ?? 'following')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary'))
        }.width('100%').padding(16).enabled(this.settings !== null && !this.busy)
          .bindMenu(this.AudienceMenu('requests'))
        Text($r('app.string.chat_requests_hint')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary'))
          .width('100%').padding(16).margin({ top: 16 })
      } else if (this.section === 'calls') {
        this.ToggleRow($r('app.string.chat_enable_calls'), $r('app.string.chat_enable_calls_hint'),
          this.settings?.av_settings.has_av_calls_enabled ?? false, 'calls')
        Column() {
        this.ToggleRow($r('app.string.chat_relay_calls'), $r('app.string.chat_relay_hint'),
          this.settings?.av_settings.has_enhanced_call_privacy_enabled ?? false, 'relay')
        }
          .enabled(this.settings?.av_settings.has_av_calls_enabled === true).opacity(this.settings?.av_settings.has_av_calls_enabled === true ? 1 : 0.4)
        Row() {
          Text($r('app.string.chat_calls_from')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L')).fontColor($r('app.color.text_primary')).layoutWeight(1)
          Text(this.audience(this.settings?.av_settings.av_call_permissions.accept_calls_from_everyone === true ? 'all' :
            this.settings?.av_settings.av_call_permissions.accept_calls_from_verified === true ? 'verified' : 'following')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary'))
        }.width('100%').padding(16).enabled(this.settings !== null && !this.busy).bindMenu(this.AudienceMenu('call_audience'))
        Text($r('app.string.chat_calls_hint')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.text_secondary'))
          .padding(16).margin({ top: 16 })
      } else if (this.section === 'data') {
        Column() { this.Option($r('sys.symbol.camera'), $r('app.string.chat_photos'), this.policy(this.photoPolicy)) }
          .bindMenu(this.PolicyMenu('download_photos'))
        Column() { this.Option($r('sys.symbol.video'), $r('app.string.chat_video'), this.policy(this.videoPolicy)) }
          .bindMenu(this.PolicyMenu('download_videos'))
        Column() { this.Option($r('sys.symbol.doc'), $r('app.string.chat_documents'), this.policy(this.documentPolicy)) }
          .bindMenu(this.PolicyMenu('download_documents'))
      } else if (this.section === 'storage') {
        Column() { this.Option($r('sys.symbol.clock'), $r('app.string.chat_keep_media'), this.retention === '0' ?
          $r('app.string.chat_forever') : this.retention === '7' ? $r('app.string.chat_7_days') : $r('app.string.chat_30_days')) }
          .bindMenu(this.RetentionMenu())
        Column() { this.Option($r('sys.symbol.camera'), $r('app.string.chat_photos_videos'), this.bytes(this.mediaStats.photos)) }
        Column() { this.Option($r('sys.symbol.doc'), $r('app.string.chat_documents'), this.bytes(this.mediaStats.documents)) }
        Column() { this.Option($r('sys.symbol.waveform'), $r('app.string.chat_voice_messages'), this.bytes(this.mediaStats.voice)) }
        Column() { this.Option($r('sys.symbol.trash'), $r('app.string.chat_clear_media'), this.bytes(this.mediaStats.total)) }.onClick((): void => this.clearMedia())
        Column() { this.Option($r('sys.symbol.trash'), $r('app.string.chat_reset'), '', true) }.onClick((): void => { this.reset(); })
      }
    }.width('100%').padding({ top: 8, bottom: this.bottomInset + 20 })
  }
  @Builder
  private RetentionMenu(): void {
    Menu() {
      MenuItem({ content: $r('app.string.chat_7_days') }).onClick((): void => this.savePolicy('retention_days', '7'))
      MenuItem({ content: $r('app.string.chat_30_days') }).onClick((): void => this.savePolicy('retention_days', '30'))
      MenuItem({ content: $r('app.string.chat_forever') }).onClick((): void => this.savePolicy('retention_days', '0'))
    }
  }
  build(): void {
    HdsNavDestination() {
      Scroll(this.scroller) {
        Column() {
          if (this.busy) { LoadingProgress().width(20).height(20).color(this.accentColor).margin(12) }
          if (this.failure.length > 0) {
            Text(this.failure).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor($r('app.color.danger')).padding(16)
              .onClick((): void => { this.load(); })
          }
          this.Body()
        }.width('100%').padding({ top: this.statusBarHeight + 64 })
      }.width('100%').height('100%').scrollBar(BarState.Off).align(Alignment.Top)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .bindSheet($$this.pinSheet, this.PinSheet(), sheetMaterialOptions({ height: SheetSize.FIT_CONTENT, showClose: false, dragBar: false,
          onDisappear: (): void => { this.oldPin = ''; this.newPin = ''; } }, this.sheetMaterialEnabled, this.sheetMaterialLevel, this.sheetWindowBreakpoint, this.sheetCompactWindow))
    }.titleMode(HdsNavDestinationTitleMode.MINI).hideBackButton(false).bindToScrollable([this.scroller])
      .titleBar({ avoidLayoutSafeArea: true,
        content: { title: { mainTitle: this.title(), subTitle: this.username.length > 0 ? '@' + this.username : '' } },
        style: destinationTitleBarStyle(ScrollEffectType.GRADIENT_BLUR, this.displayMode, this.darkSurface, this.titleBarStyleMode)
      })
      .backgroundColor(pageSurfaceColor(this.displayMode, this.darkSurface)).systemMaterial(chatPageMaterial())
      .onBackPressed((): boolean => { ResponsiveLayout.closeContentDestination(this.pageStack); return true; })
  }
}
