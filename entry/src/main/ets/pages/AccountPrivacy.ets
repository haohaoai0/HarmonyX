import { pageBackgroundActive } from '../services/PageBackgroundStore';
import { pageTextColor } from '../utils/ThemeColors';
import { appPageBackground } from '../components/PageBackgroundLayer';
import { pageCanvasColor, pageReadingSurfaceColor } from '../utils/ThemeColors';
import { STORAGE_KEY_PAGE_TRANSITION_MODE, DEFAULT_PAGE_TRANSITION_MODE } from '../services/PageTransitionSettingsStore';
import { pageSystemTransition, PageTransitionMotion } from '../utils/PageTransition';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { common } from '@kit.AbilityKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { uiMaterial } from '@kit.ArkUI';
import promptAction from '@ohos.promptAction';
import { HdsNavDestination, HdsNavDestinationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import {
  AccountManagementItem, AccountPrivacyChoice, AccountPrivacyRouteParam, AccountPrivacySnapshot,
  XLoginSession, XConnectedApplication, XBusinessCountryPreference
} from '../models/AccountPrivacy';
import { accountManagementSection } from '../services/AccountManagementCatalog';
import { accountPrivacyService } from '../services/AccountPrivacyService';
import { NativeAccountRouteParam } from '../models/NativeAccount';
import { xPrivateClient } from '../services/XPrivateClient';
import { accountStore } from '../services/AccountStore';
import { mediaSettingsStore } from '../services/MediaSettingsStore';
import { destinationTitleBarStyle } from '../utils/DestinationTitleBar';
import { pageSurfaceColor } from '../utils/ThemeColors';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';
import { USER_LIST_BLOCKED, USER_LIST_MUTED, UserListRouteParam } from './UserList';
import { ProfileWebRouteParam } from './ProfileWeb';
import { DmSettingsRouteParam } from './DmSettings';
import { SettingsRouteParam } from './Settings';

@Builder
export function AccountPrivacyBuilder(): void { AccountPrivacyPage(); }

@Component
struct AccountPrivacyPage {
  @StorageProp('harmonyx.page_background') private pageBackgroundValue: string = '';
  @State private pageMotion: PageTransitionMotion = new PageTransitionMotion();
  @StorageProp(STORAGE_KEY_PAGE_TRANSITION_MODE) private pageTransitionMode: string = DEFAULT_PAGE_TRANSITION_MODE;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp('harmonyx.desktop_layout') private desktopLayoutEnabled: boolean = false;
  @StorageProp('harmonyx.breakpoint') private breakpoint: string = 'sm';
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp('harmonyx.status_bar_height') statusBarHeight: number = 0;
  @StorageProp('harmonyx.navigation_indicator_height') bottomInset: number = 0;
  @StorageProp('harmonyx.display_mode') displayMode: string = '';
  @StorageProp('harmonyx.dark_surface') darkSurface: string = '';
  @StorageProp('harmonyx.title_bar_style_mode') titleBarStyleMode: number = 0;
  @StorageLink('harmonyx.accent_color') accentColor: string = '#007DFF';
  @StorageProp('harmonyx.accounts_changed') @Watch('onAccountChange') private accountsChanged: number = 0;
  @State private section: string = 'account';
  @State private items: AccountManagementItem[] = [];
  @State private snapshot: AccountPrivacySnapshot = new AccountPrivacySnapshot();
  @State private loading: boolean = false;
  @State private saving: boolean = false;
  @State private failure: string = '';
  @State private accountLabel: string = '';
  @State private rowRevision: number = 0;
  private scroller: Scroller = new Scroller();
  private alive: boolean = true;
  private visible: boolean = true;
  private requestId: number = 0;

  private context(): common.UIAbilityContext { return getContext(this) as common.UIAbilityContext; }
  private text(resource: Resource): string { return this.context().resourceManager.getStringSync(resource); }

  aboutToAppear(): void {
    const params: AccountPrivacyRouteParam[] = this.pageStack.getParamByName('AccountPrivacy') as AccountPrivacyRouteParam[];
    const requested: string = params.length > 0 ? params[params.length - 1].section : 'account';
    const section = accountManagementSection(requested);
    this.section = section.id;
    this.items = section.items;
    xPrivateClient.load(this.context());
  }

  aboutToDisappear(): void { this.alive = false; this.requestId++; }

  private onAccountChange(): void {
    if (!this.alive) { return; }
    this.requestId++;
    this.snapshot = new AccountPrivacySnapshot();
    if (this.visible && !this.saving) { this.refresh(); }
  }

  private current(id: number, generation: number): boolean {
    return this.alive && this.visible && id === this.requestId && generation === xPrivateClient.sessionGeneration();
  }

  private async refresh(): Promise<void> {
    if (this.saving) { return; }
    const id: number = ++this.requestId;
    xPrivateClient.load(this.context());
    const generation: number = xPrivateClient.sessionGeneration();
    const account = accountStore.active(this.context());
    this.accountLabel = account === null ? '' : account.title() + (account.handle().length > 0 ? ' · ' + account.handle() : '');
    this.snapshot = new AccountPrivacySnapshot();
    this.failure = '';
    this.loading = accountPrivacyService.needsRead(this.section);
    try {
      const result: AccountPrivacySnapshot = await accountPrivacyService.read(this.section);
      if (!this.current(id, generation)) { return; }
      this.snapshot = result;
      if (result.incomplete) { this.failure = this.text($r('app.string.xsettings_partial')); }
      this.syncMedia(result);
    } catch (error) {
      if (this.alive && this.visible && id === this.requestId) {
        this.failure = this.text(generation !== xPrivateClient.sessionGeneration() ?
          $r('app.string.xsettings_account_changed') : !xPrivateClient.isSignedIn() ?
          $r('app.string.xsettings_sign_in') : $r('app.string.xsettings_failed'));
      }
    } finally {
      if (this.alive && id === this.requestId) { this.loading = false; this.rowRevision++; }
    }
  }

  private syncMedia(snapshot: AccountPrivacySnapshot): void {
    if (snapshot.generation !== xPrivateClient.sessionGeneration()) { return; }
    const sensitive: boolean | undefined = accountPrivacyService.booleanValue(snapshot, 'display_sensitive_media');
    if (sensitive !== undefined) { mediaSettingsStore.saveShowSensitiveMedia(this.context(), sensitive); }
  }

  private async confirm(title: Resource | string, message: Resource): Promise<boolean> {
    try {
      const result = await promptAction.showDialog({
        title: typeof title === 'string' ? title : this.text(title), message: this.text(message),
        buttons: [{ text: this.text($r('app.string.xsettings_cancel')), color: this.accentColor },
          { text: this.text($r('app.string.xsettings_confirm')), color: this.accentColor }]
      });
      return result.index === 1;
    } catch (error) { return false; }
  }

  private async mutate(action: (generation: number) => Promise<AccountPrivacySnapshot>,
    title: Resource | string, confirmation: Resource | undefined = undefined): Promise<void> {
    if (this.saving || this.loading || !this.alive) { return; }
    const generation: number = this.snapshot.generation;
    const id: number = ++this.requestId;
    this.saving = true;
    this.failure = '';
    try {
      if (confirmation !== undefined && !await this.confirm(title, confirmation)) { return; }
      if (!this.current(id, generation)) { throw new Error('account_changed'); }
      const result: AccountPrivacySnapshot = await action(generation);
      if (!this.current(id, generation)) { return; }
      this.snapshot = result;
      this.syncMedia(result);
      promptAction.showToast({ message: this.text($r('app.string.xsettings_saved')), duration: 1800 });
    } catch (error) {
      if (this.alive && this.visible && id === this.requestId) {
        this.failure = this.text(generation !== xPrivateClient.sessionGeneration() ?
          $r('app.string.xsettings_account_changed') : $r('app.string.xsettings_failed'));
        // A timeout may occur after X applied a write. Read again to display
        // its actual state, while retaining the failure notice.
        if (generation === xPrivateClient.sessionGeneration()) {
          try {
            const actual: AccountPrivacySnapshot = await accountPrivacyService.read(this.section);
            if (this.current(id, generation)) { this.snapshot = actual; this.syncMedia(actual); }
          } catch (readError) { }
        } else { this.snapshot = new AccountPrivacySnapshot(); }
      }
    } finally {
      if (this.alive) {
        this.saving = false;
        this.rowRevision++;
        if (this.visible && id !== this.requestId) { this.refresh(); }
      }
    }
  }

  private toggle(item: AccountManagementItem, value: boolean): void {
    const confirmation: Resource | undefined = item.field === 'protected' || item.field === 'reply_filter' ?
      $r('app.string.xsettings_confirm_change') : undefined;
    this.mutate((generation: number): Promise<AccountPrivacySnapshot> =>
      accountPrivacyService.saveBoolean(this.section, item.field, value, generation), item.title, confirmation);
  }

  private choices(field: string): AccountPrivacyChoice[] {
    if (field === 'allow_media_tagging') {
      return [{ value: 'all', label: $r('app.string.xsettings_everyone') },
        { value: 'following', label: $r('app.string.xsettings_following') },
        { value: 'none', label: $r('app.string.xsettings_nobody') }];
    }
    if (field === 'inferred_location_resolution_preference') {
      return [{ value: 'Country', label: $r('app.string.xsettings_country') },
        { value: 'Region', label: $r('app.string.xsettings_region') }];
    }
    const result: AccountPrivacyChoice[] = [];
    const countries: XBusinessCountryPreference[] =
      this.snapshot.preferences?.about_this_account_user_preferences?.business_country_code_preferences ?? [];
    for (let i: number = 0; i < countries.length; i++) {
      const country: XBusinessCountryPreference = countries[i];
      if (country.country_code !== undefined && country.country_code.length > 0) {
        result.push({ value: country.country_code, label: country.country_name ?? country.country_code });
      }
    }
    return result;
  }

  private choiceLabel(field: string): Resource | string {
    const value: string | undefined = accountPrivacyService.stringValue(this.snapshot, field);
    const choices: AccountPrivacyChoice[] = this.choices(field);
    for (let i: number = 0; i < choices.length; i++) {
      if (choices[i].value === value) { return choices[i].label; }
    }
    return $r('app.string.xsettings_unavailable');
  }

  private openWeb(path: string, title: Resource): void {
    if (!xPrivateClient.isSignedIn()) {
      promptAction.showToast({ message: this.text($r('app.string.xsettings_sign_in')), duration: 1800 });
      this.pageStack.pushPath({ name: 'Accounts' });
      return;
    }
    const param: ProfileWebRouteParam = {
      url: 'https://x.com' + path, title: this.text(title), accountSettings: true
    };
    this.pageStack.pushPath({ name: 'ProfileWeb', param: param });
  }

  private open(item: AccountManagementItem): void {
    if (this.saving) { return; }
    if (item.action === 'group') {
      const param: AccountPrivacyRouteParam = { section: item.target };
      this.pageStack.pushPath({ name: 'AccountPrivacy', param: param });
    } else if (item.action === 'native') {
      const param: NativeAccountRouteParam = { feature: item.id };
      this.pageStack.pushPath({ name: 'NativeAccount', param: param });
    }
    else if (item.action === 'accounts') { this.pageStack.pushPath({ name: 'Accounts' }); }
    else if (item.action === 'blocked' || item.action === 'muted') {
      const param: UserListRouteParam = { mode: item.action === 'blocked' ? USER_LIST_BLOCKED : USER_LIST_MUTED, userId: '' };
      this.pageStack.pushPath({ name: 'UserList', param: param });
    } else if (item.action === 'dm') {
      const param: DmSettingsRouteParam = { section: '' };
      this.pageStack.pushPath({ name: 'DmSettings', param: param });
    } else if (item.action === 'local_links') {
      const param: SettingsRouteParam = { section: 'link_behavior' };
      this.pageStack.pushPath({ name: 'SettingsSection', param: param });
    } else if (item.action === 'clear') {
      this.mutate(async (generation: number): Promise<AccountPrivacySnapshot> => {
        await accountPrivacyService.clearData(item.target, generation);
        return accountPrivacyService.read(this.section);
      }, item.title, item.target === 'contacts' ? $r('app.string.xsettings_clear_contacts_confirm') :
        $r('app.string.xsettings_clear_locations_confirm'));
    } else if (item.action === 'revoke_all') {
      this.mutate((generation: number): Promise<AccountPrivacySnapshot> =>
        accountPrivacyService.revokeOtherSessions(generation), item.title, $r('app.string.xsettings_revoke_all_confirm'));
    }
  }

  private itemEnabled(item: AccountManagementItem): boolean {
    if (this.loading || this.saving) { return false; }
    if (item.action === 'toggle') {
      return this.snapshot.generation === xPrivateClient.sessionGeneration() &&
        accountPrivacyService.booleanValue(this.snapshot, item.field) !== undefined &&
        (item.field !== 'nsfw_user' || this.snapshot.account?.nsfw_admin !== true);
    }
    if (item.action === 'choice') { return this.snapshot.generation === xPrivateClient.sessionGeneration() &&
      accountPrivacyService.stringValue(this.snapshot, item.field) !== undefined; }
    if (item.action === 'clear') { return xPrivateClient.isSignedIn() && this.snapshot.generation === xPrivateClient.sessionGeneration(); }
    if (item.action === 'revoke_all') {
      return this.snapshot.generation === xPrivateClient.sessionGeneration() &&
        this.snapshot.sessions.some((session: XLoginSession): boolean => session.is_current_session === false);
    }
    return true;
  }

  @Builder
  private ChoiceMenu(item: AccountManagementItem): void {
    Menu() {
      ForEach(this.choices(item.field), (choice: AccountPrivacyChoice) => {
        MenuItem({ content: choice.label })
          .onClick((): void => {
            this.mutate((generation: number): Promise<AccountPrivacySnapshot> =>
              accountPrivacyService.saveChoice(this.section, item.field, choice.value, generation), item.title);
          })
      }, (choice: AccountPrivacyChoice): string => choice.value)
    }
  }

  @Builder
  private Item(item: AccountManagementItem): void {
    Row({ space: 12 }) {
      Column({ space: 5 }) {
        Text(item.title).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Subtitle_L'))
          .fontWeight(FontWeight.Medium)
          .fontColor(item.id === 'deactivate' || item.action === 'clear' ? $r('app.color.danger') : pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent))
        if (this.text(item.detail).length > 0) {
          Text(item.detail).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
        }
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      if (item.action === 'toggle') {
        if (accountPrivacyService.booleanValue(this.snapshot, item.field) === undefined) {
          Text($r('app.string.xsettings_unavailable')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S')).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
        } else {
          Toggle({ type: ToggleType.Switch, isOn: accountPrivacyService.booleanValue(this.snapshot, item.field) === true })
            .selectedColor(this.accentColor)
            .enabled(this.itemEnabled(item))
            .accessibilityText(this.text(item.title))
            .onChange((value: boolean): void => this.toggle(item, value))
        }
      } else if (item.action === 'choice') {
        Button(this.choiceLabel(item.field), { stateEffect: true })
          .fontSize($r('sys.float.Body_M')).fontColor(this.accentColor).backgroundColor(Color.Transparent)
          .enabled(this.itemEnabled(item)).bindMenu(this.ChoiceMenu(item))
      } else {
        SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(16).fontColor([pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)])
      }
    }
    .width('100%').padding({ left: 20, right: 20, top: 17, bottom: 17 })
    .enabled(item.action === 'toggle' || item.action === 'choice' ? true : this.itemEnabled(item))
    .onClick((): void => { if (item.action !== 'toggle' && item.action !== 'choice') { this.open(item); } })
  }

  @Builder
  private Sessions(): void {
    ForEach(this.snapshot.sessions, (session: XLoginSession) => {
      Row({ space: 12 }) {
        Column({ space: 5 }) {
          Text(session.name ?? session.device_name ?? this.text($r('app.string.xsettings_unknown_device'))).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Subtitle_L')).fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent))
          Text([session.summary ?? session.device_summary ?? '', session.location ?? ''].filter((part: string): boolean => part.length > 0).join(' · ')).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_M')).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
          if (session.is_current_session === true) {
            Text($r('app.string.xsettings_current_session')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_S')).fontColor(this.accentColor)
          }
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        if (session.is_current_session === false) {
          Button($r('app.string.xsettings_logout'), { stateEffect: true })
            .fontSize($r('sys.float.Body_M')).fontColor(this.accentColor).backgroundColor(Color.Transparent)
            .enabled(!this.saving && !this.loading && accountPrivacyService.sessionToken(session).length > 0)
            .onClick((): void => {
              this.mutate((generation: number): Promise<AccountPrivacySnapshot> =>
                accountPrivacyService.revokeSession(accountPrivacyService.sessionToken(session), generation),
                $r('app.string.xsettings_logout'), $r('app.string.xsettings_revoke_confirm'));
            })
        }
      }.width('100%').padding({ left: 20, right: 20, top: 16, bottom: 16 })
    }, (session: XLoginSession): string => accountPrivacyService.sessionToken(session))
    if (!this.loading && this.failure.length === 0 && this.snapshot.sessions.length === 0) {
      Text($r('app.string.xsettings_empty')).fontFamily(this.appFontFamily).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)).padding(20)
    }
  }

  @Builder
  private Applications(): void {
    ForEach(this.snapshot.applications, (application: XConnectedApplication) => {
      Column({ space: 8 }) {
        Text(application.name ?? application.app_name ?? this.text($r('app.string.xsettings_unknown_app'))).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Subtitle_L')).fontWeight(FontWeight.Medium).fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent))
        Text(application.description ?? '').fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
        Text(application.permissions ?? '').fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
        Button($r('app.string.xsettings_revoke'), { stateEffect: true })
          .fontSize($r('sys.float.Body_M')).fontColor(this.accentColor).backgroundColor(Color.Transparent)
          .enabled(!this.loading && !this.saving && ((application.token ?? '').length > 0 || (application.token_hash ?? '').length > 0))
          .onClick((): void => {
            this.mutate((generation: number): Promise<AccountPrivacySnapshot> =>
              accountPrivacyService.revokeApplication(application, generation),
              $r('app.string.xsettings_revoke'), $r('app.string.xsettings_revoke_app_confirm'));
          })
      }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 20, right: 20, top: 16, bottom: 16 })
    }, (application: XConnectedApplication): string => application.token ?? application.token_hash ?? application.app_id ?? '')
    if (!this.loading && this.failure.length === 0 && this.snapshot.applications.length === 0) {
      Text($r('app.string.xsettings_empty')).fontFamily(this.appFontFamily).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)).padding(20)
    }
  }

  private material(): uiMaterial.Material | undefined {
    if (!deviceInfo.apiAvailable('26.0.0')) { return undefined; }
    return new uiMaterial.ImmersiveMaterial({ style: uiMaterial.ImmersiveStyle.REGULAR, applyShadow: true, colorInvert: true });
  }

  build(): void {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        appPageBackground()
      Scroll(this.scroller) {
        Column() {
          if (this.accountLabel.length > 0) {
            Text(this.accountLabel).fontFamily(this.appFontFamily).fontSize($r('sys.float.Subtitle_L')).fontWeight(FontWeight.Bold)
              .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent)).width('100%').padding({ left: 20, right: 20, top: 12, bottom: 8 })
          }
          Text($r('app.string.xsettings_remote_note')).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
            .width('100%').padding({ left: 20, right: 20, bottom: 16 })
          if (this.loading || this.saving) { LoadingProgress().color(this.accentColor).width(24).height(24).margin(12) }
          if (this.failure.length > 0) {
            Text(this.failure).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)).padding(20)
            Button($r('app.string.common_retry'), { stateEffect: true }).enabled(!this.loading && !this.saving)
              .onClick((): void => { this.refresh(); })
            if (!xPrivateClient.isSignedIn()) {
              Button($r('app.string.accounts_manage'), { stateEffect: true })
                .onClick((): void => { this.pageStack.pushPath({ name: 'Accounts' }); })
            }
          }
          ForEach(this.items, (item: AccountManagementItem) => { this.Item(item) },
            (item: AccountManagementItem): string => item.id + ':' + this.rowRevision)
          if (this.section === 'sessions') { this.Sessions() }
          if (this.section === 'applications') { this.Applications() }
          if (accountPrivacyService.needsRead(this.section)) {
            Button($r('app.string.xsettings_refresh'), { stateEffect: true }).enabled(!this.loading && !this.saving)
              .onClick((): void => { this.refresh(); })
          }
        }.width('100%').alignItems(HorizontalAlign.Start).padding({ top:
          this.desktopLayoutEnabled && ResponsiveLayout.isLarge(this.breakpoint) ? 12 : this.statusBarHeight + 74,
          bottom: this.bottomInset + 28 })
      }.width('100%').height('100%').align(Alignment.TopStart).scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .clipContent(ContentClipMode.SAFE_AREA)
        .clip(false)
    
      }.width('100%').height('100%')
    }
    .scale({ x: this.pageMotion.scale, y: this.pageMotion.scale })
    .opacity(this.pageMotion.opacity)
    .onReady((context: NavDestinationContext): void => { this.pageMotion.attach(context); })
    .systemTransition(pageSystemTransition(this.pageTransitionMode))
    .onShown((): void => { this.visible = true; this.refresh(); })
    .onHidden((): void => { this.visible = false; this.requestId++; })
    .titleMode(HdsNavDestinationTitleMode.MINI).hideBackButton(false)
    .onBackPressed((): boolean => { ResponsiveLayout.closeContentDestination(this.pageStack); return true; })
    .bindToScrollable([this.scroller])
    .titleBar({ avoidLayoutSafeArea: true,
      enableComponentSafeArea: this.desktopLayoutEnabled && ResponsiveLayout.isLarge(this.breakpoint),
      content: { title: { mainTitle: accountManagementSection(this.section).title } },
      style: destinationTitleBarStyle(ScrollEffectType.GRADIENT_BLUR, this.displayMode, this.darkSurface, this.titleBarStyleMode) })
    .backgroundColor(pageCanvasColor(this.displayMode, this.darkSurface, this.pageBackgroundValue)).systemMaterial(pageBackgroundActive(this.pageBackgroundValue) ? undefined : this.material());
  }
}
