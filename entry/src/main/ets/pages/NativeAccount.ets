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
import { NativeAccountField, NativeAccountRouteParam, NativeAccountSnapshot, NativeAccountRow,
  NativeAccountChoice, NativeFlowState, NativeFlowTask, NativeFlowTaskContent, NativeFlowChoice, NativeMutedKeyword } from '../models/NativeAccount';
import { ACCOUNT_MANAGEMENT_SECTIONS } from '../services/AccountManagementCatalog';
import { nativeAccountService } from '../services/NativeAccountService';
import { nativeAccountFlow } from '../services/NativeAccountFlow';
import { xPrivateClient } from '../services/XPrivateClient';
import { accountStore } from '../services/AccountStore';
import { authStore } from '../services/AuthStore';
import { destinationTitleBarStyle } from '../utils/DestinationTitleBar';
import { pageSurfaceColor } from '../utils/ThemeColors';
import { ResponsiveLayout } from '../utils/ResponsiveLayout';
import { ProfileWebRouteParam } from './ProfileWeb';
import { materialModifier } from '../utils/SystemMaterial';

@Builder
export function NativeAccountBuilder(): void { NativeAccountPage(); }

@Component
struct NativeAccountPage {
  @StorageProp('harmonyx.page_background') private pageBackgroundValue: string = '';
  @State private pageMotion: PageTransitionMotion = new PageTransitionMotion();
  @StorageProp(STORAGE_KEY_PAGE_TRANSITION_MODE) private pageTransitionMode: string = DEFAULT_PAGE_TRANSITION_MODE;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp('harmonyx.navigation_indicator_height') bottomInset: number = 0;
  @StorageProp('harmonyx.status_bar_height') statusBarHeight: number = 0;
  @StorageProp('harmonyx.display_mode') displayMode: string = '';
  @StorageProp('harmonyx.dark_surface') darkSurface: string = '';
  @StorageProp('harmonyx.title_bar_style_mode') titleBarStyleMode: number = 0;
  @StorageLink('harmonyx.accent_color') accentColor: string = '#007DFF';
  @StorageProp('harmonyx.accounts_changed') @Watch('accountChanged') accountsChanged: number = 0;
  @State private feature: string = '';
  @State private title: Resource | string = '';
  @State private accountLabel: string = '';
  @State private snapshot: NativeAccountSnapshot = new NativeAccountSnapshot();
  @State private fields: NativeAccountField[] = [];
  @State private loading: boolean = false;
  @State private saving: boolean = false;
  @State private dirty: boolean = false;
  @State private failure: string = '';
  @State private authRequired: boolean = false;
  @State private delegateHandle: string = '';
  @State private delegateRole: string = 'Contributor';
  @State private backupCode: string = '';
  @State private verifyPassword: string = '';
  @State private keywordId: string = '';
  @State private keywordEditor: boolean = false;
  @State private flow: NativeFlowState = new NativeFlowState();
  @State private flowValue: string = '';
  @State private flowFields: NativeAccountField[] = [];
  private scroller: Scroller = new Scroller();
  private alive: boolean = true;
  private visible: boolean = false;
  private revision: number = 0;

  private context(): common.UIAbilityContext { return getContext(this) as common.UIAbilityContext; }
  private text(resource: Resource): string { return this.context().resourceManager.getStringSync(resource); }

  aboutToAppear(): void {
    const params: NativeAccountRouteParam[] = this.pageStack.getParamByName('NativeAccount') as NativeAccountRouteParam[];
    this.feature = params.length > 0 ? params[params.length - 1].feature : '';
    for (let i: number = 0; i < ACCOUNT_MANAGEMENT_SECTIONS.length; i++) {
      const item = ACCOUNT_MANAGEMENT_SECTIONS[i].items.find((row): boolean => row.id === this.feature);
      if (item !== undefined) { this.title = item.title; break; }
    }
  }

  aboutToDisappear(): void { this.alive = false; this.revision++; this.clearSecrets(); }

  private clearSecrets(): void {
    this.verifyPassword = ''; this.flowValue = ''; this.backupCode = '';
    for (let i: number = 0; i < this.fields.length; i++) { if (this.fields[i].kind === 'password') { this.fields[i].value = ''; } }
  }

  private accountChanged(): void {
    if (!this.alive) { return; }
    this.revision++; this.clearSecrets(); this.flow = new NativeFlowState(); this.fields = [];
    this.snapshot = new NativeAccountSnapshot(); this.keywordEditor = false; this.dirty = false;
    if (this.visible && !this.saving) { this.load(); }
  }

  private current(id: number, generation: number): boolean {
    return this.alive && this.visible && id === this.revision && generation === xPrivateClient.sessionGeneration();
  }

  private apply(snapshot: NativeAccountSnapshot, id: number, generation: number): boolean {
    if (!this.current(id, generation) || snapshot.generation !== generation) { return false; }
    this.snapshot = snapshot; this.fields = snapshot.fields; return true;
  }

  private async load(): Promise<void> {
    if (this.saving || this.dirty || this.flow.token.length > 0) { return; }
    const id: number = ++this.revision;
    xPrivateClient.load(this.context());
    const generation: number = xPrivateClient.sessionGeneration();
    const account = accountStore.active(this.context());
    this.accountLabel = account?.handle() ?? '';
    this.loading = true; this.failure = ''; this.authRequired = false;
    try {
      const snapshot: NativeAccountSnapshot = await nativeAccountService.load(this.feature);
      if (this.current(id, generation)) { this.snapshot = snapshot; this.fields = snapshot.fields; }
    } catch (error) {
      if (this.current(id, generation)) {
        const message: string = (error as Error).message;
        this.authRequired = message === 'native_request_failed_401' || message === 'native_request_failed_403';
        this.failure = this.text(message === 'native_unavailable' ? $r('app.string.xnative_available') : $r('app.string.xnative_read_failed'));
      }
    } finally { if (this.alive && id === this.revision) { this.loading = false; } }
  }

  private async confirm(): Promise<boolean> {
    try {
      const result = await promptAction.showDialog({
        title: this.text($r('app.string.xsettings_confirm')), message: this.text(this.feature === 'deactivate' ?
          $r('app.string.xnative_deactivate_confirm') : $r('app.string.xsettings_confirm_change')),
        buttons: [{ text: this.text($r('app.string.xsettings_cancel')), color: this.accentColor },
          { text: this.text($r('app.string.xsettings_confirm')), color: this.accentColor }]
      });
      return result.index === 1;
    } catch (error) { return false; }
  }

  private async perform(action: (id: number, generation: number) => Promise<void>, confirmation: boolean = false): Promise<void> {
    if (this.loading || this.saving || !this.visible) { return; }
    const id: number = ++this.revision;
    const generation: number = xPrivateClient.sessionGeneration();
    this.saving = true; this.failure = '';
    try {
      if (confirmation && !await this.confirm()) { return; }
      if (!this.current(id, generation)) { throw new Error('account_changed'); }
      await action(id, generation);
      if (!this.current(id, generation)) { return; }
    } catch (error) {
      if (this.alive && id === this.revision) {
        const message: string = (error as Error).message;
        this.authRequired = message === 'native_request_failed_401' || message === 'native_request_failed_403';
        this.failure = this.text(generation !== xPrivateClient.sessionGeneration() ?
          $r('app.string.xsettings_account_changed') : $r('app.string.xnative_save_failed'));
      }
    } finally {
      if (this.alive) {
        this.saving = false;
        if (this.visible && id !== this.revision) { this.load(); }
      }
    }
  }

  private save(): void {
    this.perform(async (id: number, generation: number): Promise<void> => {
      let result: NativeAccountSnapshot;
      if (this.keywordEditor) {
        await nativeAccountService.keyword(this.keywordId, this.fields, this.snapshot.generation);
        result = await nativeAccountService.load(this.feature);
      } else { result = await nativeAccountService.save(this.feature, this.snapshot, this.fields); }
      if (!this.apply(result, id, generation)) { return; }
      if (this.feature === 'deactivate') {
        this.clearSecrets();
        await authStore.signOut(this.context());
        ResponsiveLayout.closeContentDestination(this.pageStack);
        promptAction.showToast({ message: this.text($r('app.string.xnative_deactivated')), duration: 1800 });
        return;
      }
      this.keywordEditor = false;
      this.clearSecrets(); this.fields = this.snapshot.fields; this.dirty = false;
      promptAction.showToast({ message: this.text($r('app.string.xsettings_saved')), duration: 1800 });
    }, this.feature === 'deactivate' || this.feature === 'password' || this.feature === 'age' || this.feature === 'password_protection');
  }

  private verify(): void {
    this.perform(async (id: number, generation: number): Promise<void> => {
      try { await nativeAccountService.verify(this.verifyPassword, generation); }
      finally { this.verifyPassword = ''; }
      this.apply(await nativeAccountService.load(this.feature), id, generation);
    });
  }

  private startFlow(name: string, variant: string = ''): void {
    this.perform(async (id: number, generation: number): Promise<void> => {
      const flow: NativeFlowState = await nativeAccountFlow.start(name, generation, variant);
      if (!this.current(id, generation)) { return; }
      this.flow = flow;
      this.prepareFlow();
    });
  }

  private prepareFlow(): void {
    this.flowValue = ''; this.flowFields = [];
    const task: NativeFlowTask | undefined = this.flow.tasks[0];
    if (task === undefined) { return; }
    const content: NativeFlowTaskContent | undefined = nativeAccountFlow.content(task);
    if (task.enter_phone !== undefined) {
      this.flowFields.push(new NativeAccountField('country_code', $r('app.string.xnative_country_code'), 'text', content?.country_code ?? ''));
    }
    const settings = content?.settings ?? [];
    for (let i: number = 0; i < settings.length; i++) {
      if (settings[i].value_type !== 'boolean') { continue; }
      const field: NativeAccountField = new NativeAccountField(settings[i].value_identifier,
        settings[i].value_data?.boolean_data?.primary_text?.text ?? settings[i].value_identifier,
        settings[i].value_type === 'boolean' ? 'toggle' : 'text',
        settings[i].value_type === 'boolean' ? String(settings[i].value_data?.boolean_data?.initial_value === true) : '');
      this.flowFields.push(field);
    }
  }

  private submitFlow(link: string): void {
    const task: NativeFlowTask | undefined = this.flow.tasks[0];
    if (task === undefined) { return; }
    this.perform(async (id: number, generation: number): Promise<void> => {
      const flow: NativeFlowState = await nativeAccountFlow.submit(this.flow, task, link, this.flowValue, this.flowFields);
      if (!this.current(id, generation)) { return; }
      this.flow = flow;
      this.prepareFlow();
      if (this.flow.completed) {
        promptAction.showToast({ message: this.text($r('app.string.xnative_flow_complete')), duration: 1800 });
        this.flow = new NativeFlowState(); this.dirty = false;
        this.apply(await nativeAccountService.load(this.feature), id, generation);
      }
    });
  }

  private sendCode(): void {
    this.perform(async (id: number, generation: number): Promise<void> => {
      await nativeAccountFlow.sendCode(this.flow);
      if (this.current(id, generation)) { promptAction.showToast({ message: this.text($r('app.string.xnative_code_sent')), duration: 1800 }); }
    });
  }

  private inviteDelegate(): void {
    this.perform(async (id: number, generation: number): Promise<void> => {
      const result: NativeAccountSnapshot = await nativeAccountService.invite(this.snapshot, this.delegateHandle, this.delegateRole);
      if (this.apply(result, id, generation)) { this.delegateHandle = ''; }
    }, true);
  }

  private editKeyword(row: NativeAccountRow | undefined = undefined): void {
    this.keywordId = row?.id ?? ''; this.keywordEditor = true; this.dirty = false;
    const keyword = new NativeAccountField('keyword', $r('app.string.xnative_keyword'), 'text', typeof row?.title === 'string' ? row.title : '');
    const original: NativeMutedKeyword | undefined = this.snapshot.keywords.find((item: NativeMutedKeyword): boolean => item.id === row?.id);
    keyword.kind = row === undefined ? 'text' : 'readonly';
    const home = new NativeAccountField('home', $r('app.string.xnative_mute_home'), 'toggle', 'true');
    const notifications = new NativeAccountField('notifications', $r('app.string.xnative_mute_notifications'), 'choice', 'following');
    notifications.choices = [{ value: 'following', label: $r('app.string.xnative_not_following') },
      { value: 'everyone', label: $r('app.string.xsettings_everyone') }, { value: 'none', label: $r('app.string.xsettings_nobody') }];
    const duration = new NativeAccountField('duration', $r('app.string.xnative_duration'), 'choice', '');
    duration.choices = [{ value: '', label: $r('app.string.xnative_forever') }, { value: '86400000', label: $r('app.string.xnative_day_duration') },
      { value: '604800000', label: $r('app.string.xnative_week_duration') }, { value: '2592000000', label: $r('app.string.xnative_month_duration') }];
    if (original !== undefined) {
      home.value = String(original.mute_surfaces.indexOf('home_timeline') >= 0);
      notifications.value = original.mute_surfaces.indexOf('notifications') < 0 ? 'none' :
        original.mute_options.indexOf('exclude_following_accounts') >= 0 ? 'following' : 'everyone';
      duration.value = 'keep'; duration.choices.push({ value: 'keep', label: $r('app.string.xnative_keep_duration') });
    }
    this.fields = [keyword, home, notifications, duration];
  }

  private rowAction(row: NativeAccountRow): void {
    if (row.action === 'open_download' && nativeAccountService.safeDownload(row.value)) {
      this.context().startAbility({ action: 'ohos.want.action.viewData', uri: row.value }).catch((): void => {
        this.failure = this.text($r('app.string.xnative_save_failed'));
      }); return;
    }
    if (row.action === 'edit_keyword') { this.editKeyword(row); return; }
    if (row.action === 'delete_passkey') { this.startFlow('passkey_deletion', JSON.stringify({ 'passkey_method_ids': row.id })); return; }
    this.perform(async (id: number, generation: number): Promise<void> => {
      await nativeAccountService.rowAction(this.feature, row, this.snapshot.generation);
      this.apply(await nativeAccountService.load(this.feature), id, generation);
    }, true);
  }

  private secondaryAction(row: NativeAccountRow): void {
    const next: NativeAccountRow = { id: row.id, title: row.title, detail: row.detail, value: row.value,
      action: row.secondaryAction ?? '', targetId: row.targetId, role: row.role };
    this.rowAction(next);
  }

  private showBackup(renew: boolean): void {
    this.perform(async (id: number, generation: number): Promise<void> => {
      const code: string = await nativeAccountService.backup(generation, renew);
      if (this.current(id, generation)) { this.backupCode = code; }
    }, renew);
  }

  private externalChallenge(): void {
    const task: NativeFlowTask | undefined = this.flow.tasks[0];
    const content: NativeFlowTaskContent | undefined = task === undefined ? undefined : nativeAccountFlow.content(task);
    let url: string = content?.url ?? content?.next_link?.url ?? '';
    if (url.length === 0 && (task?.security_key !== undefined || task?.passkey !== undefined)) { url = 'https://x.com/i/flow/' + this.flow.flow; }
    if (!url.startsWith('https://x.com/')) { return; }
    const param: ProfileWebRouteParam = { url: url, title: this.text($r('app.string.xnative_external_verification')), accountSettings: true };
    this.pageStack.pushPath({ name: 'ProfileWeb', param: param });
  }

  @Builder
  private ChoiceMenu(field: NativeAccountField): void {
    Menu() {
      ForEach(field.choices, (choice: NativeAccountChoice) => {
        MenuItem({ content: choice.label }).onClick((): void => { field.value = choice.value; this.dirty = true; })
      }, (choice: NativeAccountChoice): string => choice.value)
    }
  }

  private choiceLabel(field: NativeAccountField): Resource | string {
    return field.choices.find((choice: NativeAccountChoice): boolean => choice.value === field.value)?.label ?? field.value;
  }

  private actionLabel(action: string): Resource {
    if (action === 'edit_keyword') { return $r('app.string.xnative_edit'); }
    if (action === 'open_download') { return $r('app.string.xnative_open_download'); }
    if (action === 'topic_follow') { return $r('app.string.xnative_topic_follow'); }
    if (action === 'topic_unfollow') { return $r('app.string.xnative_topic_unfollow'); }
    if (action === 'topic_ignore') { return $r('app.string.xnative_topic_not_interested'); }
    if (action === 'topic_restore') { return $r('app.string.xnative_topic_restore'); }
    if (action === 'resend_email') { return $r('app.string.xnative_resend'); }
    if (action === 'accept_delegate') { return $r('app.string.xnative_accept'); }
    if (action === 'change_delegate_role') { return $r('app.string.xnative_change_role'); }
    return $r('app.string.xnative_remove');
  }

  @Builder
  private Field(field: NativeAccountField): void {
    Column({ space: 10 }) {
      if (field.kind === 'toggle') {
        Row({ space: 16 }) {
          Text(field.title).fontFamily(this.appFontFamily).fontSize($r('sys.float.Subtitle_L')).fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent)).layoutWeight(1)
          if (field.available) {
            Toggle({ type: ToggleType.Switch, isOn: field.value === 'true' }).selectedColor(this.accentColor)
              .enabled(!this.saving).onChange((value: boolean): void => { field.value = String(value); this.dirty = true; })
          } else { Text($r('app.string.xsettings_unavailable')).fontFamily(this.appFontFamily).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)) }
        }.width('100%')
      } else {
        Text(field.title).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
        if (!field.available) { Text($r('app.string.xsettings_unavailable')).fontFamily(this.appFontFamily).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)) }
        else if (field.kind === 'readonly') {
          Text(field.choices.length > 0 ? this.choiceLabel(field) : field.id === 'is_identity_verified' ?
            field.value === 'true' ? $r('app.string.xnative_verified') : $r('app.string.xnative_unverified') :
            field.value === 'true' ? $r('app.string.xnative_enabled') : field.value === 'false' ? $r('app.string.xnative_disabled') : field.value).fontFamily(this.appFontFamily)
            .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent)).copyOption(CopyOptions.InApp)
        }
        else if (field.kind === 'choice') {
          Button(this.choiceLabel(field)).bindMenu(this.ChoiceMenu(field)).enabled(!this.saving)
            .fontColor(this.accentColor).backgroundColor(Color.Transparent)
        } else {
          TextInput({ text: field.value }).fontFamily(this.appFontFamily)
            .type(field.kind === 'password' ? InputType.Password : field.kind === 'number' ? InputType.Number : InputType.Normal)
            .fontSize($r('sys.float.Body_L')).fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent)).enabled(!this.saving)
            .onChange((value: string): void => { field.value = value; this.dirty = true; })
        }
      }
    }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 20, right: 20, top: 14, bottom: 14 })
  }

  @Builder
  private Flow(): void {
    if (this.flow.tasks.length > 0) {
      Column({ space: 18 }) {
        Text(nativeAccountFlow.content(this.flow.tasks[0])?.header?.text ??
          nativeAccountFlow.content(this.flow.tasks[0])?.primary_text?.text ?? '').fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Title_S')).fontWeight(FontWeight.Bold).fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent))
        Text(nativeAccountFlow.content(this.flow.tasks[0])?.secondary_text?.text ??
          nativeAccountFlow.content(this.flow.tasks[0])?.detail_text?.text ?? '').fontFamily(this.appFontFamily).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
        if (nativeAccountFlow.kind(this.flow.tasks[0]).indexOf('enter_') === 0 ||
          nativeAccountFlow.kind(this.flow.tasks[0]).indexOf('verification') > 0) {
          TextInput({ text: this.flowValue, placeholder: nativeAccountFlow.content(this.flow.tasks[0])?.hint_text ?? '' }).fontFamily(this.appFontFamily)
            .type(this.flow.tasks[0].enter_password !== undefined ? InputType.Password : InputType.Normal)
            .fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent)).enabled(!this.saving)
            .onChange((value: string): void => { this.flowValue = value; })
        }
        ForEach(this.flowFields, (field: NativeAccountField) => { this.Field(field) }, (field: NativeAccountField): string => field.id)
        if (this.flow.tasks[0].show_code !== undefined) {
          Text(this.flow.tasks[0].show_code?.code ?? '').fontFamily(this.appFontFamily).fontSize($r('sys.float.Title_M')).fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent)).copyOption(CopyOptions.InApp)
        }
        if (this.flow.tasks[0].choice_selection !== undefined) {
          ForEach(this.flow.tasks[0].choice_selection?.choices ?? [], (choice: NativeFlowChoice) => {
            Button(choice.label?.text ?? choice.id).enabled(!this.saving).onClick((): void => { this.flowValue = choice.id; })
          }, (choice: NativeFlowChoice): string => choice.id)
        }
        if (this.flow.tasks[0].email_verification !== undefined || this.flow.tasks[0].phone_verification !== undefined) {
          Button($r('app.string.xnative_resend')).enabled(!this.saving).onClick((): void => this.sendCode())
        }
        if (nativeAccountFlow.kind(this.flow.tasks[0]).length > 0) {
          Button(nativeAccountFlow.content(this.flow.tasks[0])?.next_link?.label ??
            nativeAccountFlow.content(this.flow.tasks[0])?.primary_button?.label ?? this.text($r('app.string.xnative_continue')))
            .enabled(!this.saving).onClick((): void => this.submitFlow(nativeAccountFlow.content(this.flow.tasks[0])?.next_link?.link_id ??
              nativeAccountFlow.content(this.flow.tasks[0])?.primary_button?.link_id ?? nativeAccountFlow.content(this.flow.tasks[0])?.primary_action_link?.link_id ?? ''))
        } else {
          Text($r('app.string.xnative_external_required')).fontFamily(this.appFontFamily).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent))
          Button($r('app.string.xnative_external_verification')).onClick((): void => this.externalChallenge())
        }
        Button($r('app.string.xsettings_cancel')).backgroundColor(Color.Transparent).fontColor(this.accentColor)
          .enabled(!this.saving).onClick((): void => { this.flow = new NativeFlowState(); this.flowValue = ''; this.flowFields = []; this.dirty = false; this.load(); })
      }.width('100%').alignItems(HorizontalAlign.Start).padding(20)
    }
  }

  @Builder
  private Actions(): void {
    if (this.feature === 'email' || this.feature === 'phone') {
      Button($r('app.string.xnative_change')).onClick((): void => this.startFlow(this.feature === 'email' ? 'add_email' : 'add_phone'))
    } else if (this.feature === 'two_factor' || this.feature === 'security_keys') {
      Button($r('app.string.xnative_auth_app')).onClick((): void => this.startFlow('two-factor-auth-app-enrollment'))
      Button($r('app.string.xnative_sms')).onClick((): void => this.startFlow('two-factor-sms-enrollment'))
      Button($r('app.string.xsettings_security_keys')).onClick((): void => this.startFlow('two-factor-security-key-enrollment'))
      if (this.snapshot.data['twoFactorAuthEnabled'] === true) {
        Button($r('app.string.xnative_show_backup')).onClick((): void => this.showBackup(false))
        if (this.backupCode.length > 0) {
          Text(this.backupCode).fontFamily(this.appFontFamily).fontSize($r('sys.float.Title_M')).fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent)).copyOption(CopyOptions.InApp)
          Button($r('app.string.xnative_generate_backup')).onClick((): void => this.showBackup(true))
        }
      }
    } else if (this.feature === 'passkeys') {
      Button($r('app.string.xnative_add')).onClick((): void => this.startFlow('passkey_registration'))
    } else if (this.feature === 'automation') {
      Button($r('app.string.xnative_manage')).onClick((): void => this.startFlow('enable_automated_account'))
    } else if (this.feature === 'muted_words') {
      Button($r('app.string.xnative_add')).onClick((): void => this.editKeyword())
    } else if (this.feature === 'delegate') {
      TextInput({ text: this.delegateHandle, placeholder: $r('app.string.xnative_delegate_name') }).fontFamily(this.appFontFamily)
        .onChange((value: string): void => { this.delegateHandle = value; })
      Row({ space: 12 }) {
        Button($r('app.string.xnative_contributor')).onClick((): void => { this.delegateRole = 'Contributor'; })
          .backgroundColor(this.delegateRole === 'Contributor' ? this.accentColor : $r('app.color.bg_card'))
        Button($r('app.string.xnative_admin')).onClick((): void => { this.delegateRole = 'Admin'; })
          .backgroundColor(this.delegateRole === 'Admin' ? this.accentColor : $r('app.color.bg_card'))
      }
      Button($r('app.string.xnative_invite')).enabled(this.delegateHandle.trim().length > 0).onClick((): void => this.inviteDelegate())
    } else if (this.feature === 'grok_history') {
      if (nativeAccountService.string(this.snapshot.data['cursor']).length > 0) {
        Button($r('app.string.xnative_more')).onClick((): void => {
          this.perform(async (id: number, generation: number): Promise<void> => {
            this.apply(await nativeAccountService.moreHistory(this.snapshot), id, generation);
          });
        })
      }
      Button($r('app.string.xnative_delete_history')).onClick((): void => {
        this.perform(async (id: number, generation: number): Promise<void> => {
          this.apply(await nativeAccountService.clearHistory(this.snapshot.generation), id, generation);
        }, true);
      })
    } else if (this.feature === 'languages') {
      Button($r('app.string.xnative_content_languages')).onClick((): void => this.startFlow('uls_content_and_app_language_selector'))
    } else if (this.feature === 'archive') {
      Button($r('app.string.xnative_request_archive')).onClick((): void => {
        this.perform(async (id: number, generation: number): Promise<void> => {
          await nativeAccountService.request('POST', '/1.1/account/user_twitter_data', {}, true, this.snapshot.generation);
          this.apply(await nativeAccountService.load(this.feature), id, generation);
        }, true);
      })
    }
  }

  private material(): uiMaterial.Material | undefined {
    return deviceInfo.apiAvailable('26.0.0') ? new uiMaterial.ImmersiveMaterial({ style: uiMaterial.ImmersiveStyle.REGULAR, applyShadow: true, colorInvert: true }) : undefined;
  }

  build(): void {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        appPageBackground()
      Scroll(this.scroller) {
        Column({ space: 8 }) {
          Text(this.accountLabel).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)).width('100%').padding({ left: 20, right: 20, top: 12 })
          if (this.loading || this.saving) { LoadingProgress().color(this.accentColor).width(24).height(24).margin(12) }
          if (this.snapshot.notice !== '') { Text(this.snapshot.notice).fontFamily(this.appFontFamily).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)).padding(20) }
          if (this.failure.length > 0) {
            Text(this.failure).fontFamily(this.appFontFamily).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)).padding(20)
            if (this.authRequired) {
              TextInput({ text: this.verifyPassword, placeholder: $r('app.string.xnative_current_password') }).fontFamily(this.appFontFamily).type(InputType.Password)
              .enabled(!this.saving).onChange((value: string): void => { this.verifyPassword = value; }).margin({ left: 20, right: 20 })
            Button($r('app.string.xnative_verify')).enabled(!this.saving && this.verifyPassword.length > 0).onClick((): void => this.verify())
            }
            Button($r('app.string.common_retry')).enabled(!this.saving).onClick((): void => { this.dirty = false; this.load(); })
          }
          if (this.flow.token.length > 0) { this.Flow() }
          else {
            ForEach(this.fields, (field: NativeAccountField) => { this.Field(field) }, (field: NativeAccountField): string => field.id)
            if (this.fields.some((field: NativeAccountField): boolean => field.available && field.kind !== 'readonly')) {
              Button(this.feature === 'deactivate' ? $r('app.string.xsettings_deactivate') : $r('app.string.xnative_save'))
                .enabled(!this.saving && !this.loading).onClick((): void => this.save()).margin(12)
            }
            if (!this.keywordEditor) {
              ForEach(this.snapshot.rows, (row: NativeAccountRow) => {
                Row({ space: 16 }) {
                  Column({ space: 7 }) {
                    Text(row.title).fontFamily(this.appFontFamily).fontSize($r('sys.float.Subtitle_L')).fontColor(pageTextColor($r('app.color.text_primary'), this.pageBackgroundValue, Color.Transparent))
                    if (row.verified !== undefined) { Text(row.verified ? $r('app.string.xnative_verified') : $r('app.string.xnative_unverified')).fontFamily(this.appFontFamily).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)) }
                    if (row.detail.length > 0) { Text(row.detail).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_M')).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)) }
                  }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                  if (row.action.length > 0 && row.action !== 'data_section') {
                    Button(this.actionLabel(row.action))
                      .fontColor(this.accentColor).backgroundColor(Color.Transparent).enabled(!this.saving)
                      .onClick((): void => this.rowAction(row))
                  }
                  if (row.secondaryAction !== undefined && row.secondaryAction.length > 0) {
                    Button(this.actionLabel(row.secondaryAction))
                      .backgroundColor(Color.Transparent).fontColor(this.accentColor).enabled(!this.saving)
                      .onClick((): void => this.secondaryAction(row))
                  }
                  if (row.action === 'edit_keyword') {
                    Button($r('app.string.xnative_remove')).fontColor($r('app.color.danger')).backgroundColor(Color.Transparent)
                      .enabled(!this.saving).onClick((): void => this.rowAction({ id: row.id, title: row.title, detail: row.detail, value: row.value, action: 'delete_keyword' }))
                  }
                }.width('100%').padding({ left: 20, right: 20, top: 16, bottom: 16 })
              }, (row: NativeAccountRow): string => row.id)
              if (!this.loading && this.failure.length === 0 && this.snapshot.rows.length === 0 && this.fields.length === 0) {
                Text($r('app.string.xsettings_empty')).fontFamily(this.appFontFamily).fontColor(pageTextColor($r('app.color.text_secondary'), this.pageBackgroundValue, Color.Transparent)).padding(20)
              }
              if (this.failure.length === 0) { Column({ space: 14 }) { this.Actions() }.padding(20).enabled(!this.saving && !this.loading) }
            } else {
              Button($r('app.string.xsettings_cancel')).onClick((): void => { this.keywordEditor = false; this.dirty = false; this.fields = this.snapshot.fields; })
            }
          }
        }.width('100%').alignItems(HorizontalAlign.Start).padding({ top: this.statusBarHeight + 74, bottom: this.bottomInset + 24 })
      }.width('100%').height('100%').align(Alignment.TopStart).scrollBar(BarState.Off)
    
      }.width('100%').height('100%')
    }
    .scale({ x: this.pageMotion.scale, y: this.pageMotion.scale })
    .opacity(this.pageMotion.opacity)
    .onReady((context: NavDestinationContext): void => { this.pageMotion.attach(context); })
    .systemTransition(pageSystemTransition(this.pageTransitionMode))
    .onShown((): void => { this.visible = true; this.load(); })
    .onHidden((): void => { this.visible = false; this.revision++; this.clearSecrets(); this.flow = new NativeFlowState(); this.flowFields = []; })
    .titleMode(HdsNavDestinationTitleMode.MINI).hideBackButton(false)
    .onBackPressed((): boolean => { ResponsiveLayout.closeContentDestination(this.pageStack); return true; })
    .bindToScrollable([this.scroller])
    .titleBar({ avoidLayoutSafeArea: true, content: { title: { mainTitle: this.title } },
      style: destinationTitleBarStyle(ScrollEffectType.GRADIENT_BLUR, this.displayMode, this.darkSurface, this.titleBarStyleMode) })
    .backgroundColor(pageCanvasColor(this.displayMode, this.darkSurface, this.pageBackgroundValue)).attributeModifier(materialModifier(pageBackgroundActive(this.pageBackgroundValue) ? undefined : this.material()));
  }
}
