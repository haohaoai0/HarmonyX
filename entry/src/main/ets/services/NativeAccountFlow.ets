import { NativeFlowState, NativeFlowResponse, NativeFlowTask, NativeFlowTaskContent,
  NativeAccountField, NativeFlowLink, NativeFlowIdentifier } from '../models/NativeAccount';
import { nativeAccountService } from './NativeAccountService';

export class NativeAccountFlow {
  async start(flow: string, generation: number, variant: string = ''): Promise<NativeFlowState> {
    const allowed: string[] = ['add_email', 'add_phone', 'verify_account_ownership', 'enable_automated_account',
      'two-factor-sms-enrollment', 'two-factor-auth-app-enrollment', 'two-factor-security-key-enrollment',
      'passkey_registration', 'passkey_deletion', 'sso_disconnect', 'language_selector', 'uls_content_and_app_language_selector'];
    if (allowed.indexOf(flow) < 0) { throw new Error('invalid_flow'); }
    const startLocation: Record<string, Object | null> = { 'location': 'manual_link' };
    const flowContext: Record<string, Object | null> = { 'start_location': startLocation };
    const input: Record<string, Object | null> = { 'flow_context': flowContext };
    if (variant.length > 0) { input['requested_variant'] = variant; }
    const versions: Record<string, number> = { 'action_list': 2, 'alert_dialog': 1, 'check_logged_in_account': 1,
      'choice_selection': 3, 'cta': 7, 'email_verification': 2, 'end_flow': 1, 'enter_date': 1,
      'enter_email': 2, 'enter_password': 5, 'enter_phone': 2, 'enter_text': 5, 'enter_username': 2,
      'phone_verification': 4, 'security_key': 3, 'settings_list': 7, 'show_code': 1, 'wait_spinner': 3, 'web_modal': 1 };
    const body: string = await nativeAccountService.request('POST', '/1.1/onboarding/task.json?flow_name=' + encodeURIComponent(flow),
      { 'input_flow_data': input, 'subtask_versions': versions }, true, generation);
    return this.parse(body, generation, flow);
  }

  private parse(body: string, generation: number, flow: string): NativeFlowState {
    const response: NativeFlowResponse = JSON.parse(body) as NativeFlowResponse;
    if (response === null || typeof response.flow_token !== 'string' || !Array.isArray(response.subtasks)) { throw new Error('native_flow_unavailable'); }
    if (response.status !== undefined && response.status !== 'success') { throw new Error('native_flow_unavailable'); }
    const state: NativeFlowState = new NativeFlowState();
    state.token = response.flow_token; state.tasks = response.subtasks; state.generation = generation; state.flow = flow;
    const terminal: NativeFlowTaskContent | undefined = response.subtasks[0]?.end_flow;
    if (terminal !== undefined && terminal.status !== 'success') { throw new Error('native_flow_unavailable'); }
    state.completed = response.subtasks.length === 0 || terminal !== undefined;
    return state;
  }

  kind(task: NativeFlowTask): string {
    if (task.enter_password !== undefined) { return 'enter_password'; }
    if (task.enter_text !== undefined) { return 'enter_text'; }
    if (task.enter_email !== undefined) { return 'enter_email'; }
    if (task.enter_phone !== undefined) { return 'enter_phone'; }
    if (task.enter_username !== undefined) { return 'enter_username'; }
    if (task.phone_verification !== undefined) { return 'phone_verification'; }
    if (task.email_verification !== undefined) { return 'email_verification'; }
    if (task.choice_selection !== undefined) { return 'choice_selection'; }
    if (task.settings_list !== undefined) { return 'settings_list'; }
    if (task.cta !== undefined) { return 'cta'; }
    if (task.show_code !== undefined) { return 'show_code'; }
    if (task.check_logged_in_account !== undefined) { return 'check_logged_in_account'; }
    return '';
  }

  content(task: NativeFlowTask): NativeFlowTaskContent | undefined {
    return task.enter_password ?? task.enter_text ?? task.enter_email ?? task.enter_phone ?? task.enter_username ??
      task.phone_verification ?? task.email_verification ?? task.choice_selection ?? task.settings_list ??
      task.cta ?? task.show_code ?? task.check_logged_in_account ?? task.web_modal ?? task.open_link ?? task.passkey ?? task.security_key;
  }

  async submit(state: NativeFlowState, task: NativeFlowTask, link: string, value: string,
    fields: NativeAccountField[]): Promise<NativeFlowState> {
    nativeAccountService.check(state.generation);
    const kind: string = this.kind(task);
    const content: NativeFlowTaskContent | undefined = this.content(task);
    if (kind.length === 0 || content === undefined || !state.tasks.some((item: NativeFlowTask): boolean => item.subtask_id === task.subtask_id)) { throw new Error('native_flow_unavailable'); }
    const knownLinks: string[] = [content.next_link?.link_id ?? '', content.primary_button?.link_id ?? '',
      content.secondary_button?.link_id ?? '', content.primary_action_link?.link_id ?? '', content.secondary_action_link?.link_id ?? ''];
    if (link.length === 0 || knownLinks.indexOf(link) < 0) { throw new Error('invalid_flow_link'); }
    if (kind === 'choice_selection' && !content.choices?.some((choice): boolean => choice.id === value)) { throw new Error('invalid_flow_choice'); }
    if ((kind === 'enter_password' || kind.indexOf('verification') > 0) && value.length === 0) { throw new Error('invalid_flow_input'); }
    const input: Record<string, Object | null> = { 'link': link };
    if (kind === 'enter_password') { input['password'] = value; }
    if (kind === 'enter_text') { input['text'] = value; }
    if (kind === 'enter_username') { input['username'] = value; }
    if (kind === 'enter_email') { input['email'] = value; }
    if (kind === 'enter_phone') {
      input['phone_number'] = value; input['country_code'] = nativeAccountService.value(fields, 'country_code');
    }
    if (kind === 'phone_verification' || kind === 'email_verification') {
      input['code'] = value;
      if (kind === 'phone_verification') { input['normalized_phone'] = state.normalizedPhone; input['by_voice'] = content.send_via_voice === true; }
      else { input['email'] = state.verificationEmail; }
    }
    if (kind === 'choice_selection') { input['selected_choices'] = [value]; }
    if (kind === 'settings_list' || kind === 'enter_email' || kind === 'enter_phone') {
      const responses: Record<string, Object | null>[] = [];
      for (let i: number = 0; i < fields.length; i++) {
        const field: NativeAccountField = fields[i];
        if (field.kind !== 'toggle') { continue; }
        if (!content.settings?.some((setting): boolean => setting.value_identifier === field.id && setting.value_type === 'boolean') ||
          (field.value !== 'true' && field.value !== 'false')) { throw new Error('invalid_flow_setting'); }
        const booleanData: Record<string, Object | null> = { 'result': field.value === 'true' };
        const textData: Record<string, Object | null> = { 'result': field.value };
        const responseData: Record<string, Object | null> = field.kind === 'toggle' ?
          { 'boolean_data': booleanData } : { 'text_data': textData };
        responses.push({ 'key': field.id, 'response_data': responseData });
      }
      input['setting_responses'] = responses;
    }
    if (kind === 'check_logged_in_account') { input['link'] = link; }
    const subtask: Record<string, Object | null> = { 'subtask_id': task.subtask_id };
    subtask[kind] = input;
    state.inputs[task.subtask_id] = input;
    state.pendingInputs = state.pendingInputs.filter((item: Record<string, Object | null>): boolean => item['subtask_id'] !== task.subtask_id);
    state.pendingInputs.push(subtask);
    const links: (NativeFlowLink | undefined)[] = [content.next_link, content.primary_button, content.secondary_button,
      content.primary_action_link, content.secondary_action_link];
    const navigation: NativeFlowLink | undefined = links.find((item: NativeFlowLink | undefined): boolean => item?.link_id === link);
    if (navigation?.link_type === 'subtask') {
      const next: NativeFlowTask | undefined = state.tasks.find((item: NativeFlowTask): boolean => item.subtask_id === navigation.subtask_id);
      if (next === undefined) { throw new Error('native_flow_unavailable'); }
      state.tasks = [next, ...state.tasks.filter((item: NativeFlowTask): boolean => item.subtask_id !== next.subtask_id)];
      state.verificationTask = '';
      if (next.end_flow === undefined) { return state; }
      if (next.end_flow.status !== 'success' || next.end_flow.end_flow_type !== 'finish') { throw new Error('native_flow_unavailable'); }
    }
    const body: string = await nativeAccountService.request('POST', '/1.1/onboarding/task.json',
      { 'flow_token': state.token, 'subtask_inputs': state.pendingInputs }, true, state.generation);
    const next: NativeFlowState = this.parse(body, state.generation, state.flow);
    next.inputs = state.inputs;
    return next;
  }

  private identifier(state: NativeFlowState, value: NativeFlowIdentifier | undefined): string {
    if (typeof value?.string === 'string') { return value.string; }
    if (value?.subtask_data_reference !== undefined) {
      const reference = value.subtask_data_reference;
      return nativeAccountService.string(nativeAccountService.object(state.inputs[reference.subtask_id])[reference.key]);
    }
    return '';
  }

  async sendCode(state: NativeFlowState): Promise<void> {
    const task: NativeFlowTask | undefined = state.tasks[0];
    if (task === undefined) { throw new Error('native_flow_unavailable'); }
    const content: NativeFlowTaskContent | undefined = task.email_verification ?? task.phone_verification;
    if (content === undefined) { return; }
    const form: Record<string, Object | null> = {};
    if (task.email_verification !== undefined) {
      state.verificationEmail = this.identifier(state, content.email);
      if (state.verificationEmail.length === 0) { throw new Error('native_flow_unavailable'); }
      form['email'] = state.verificationEmail;
    } else {
      const phone: string = this.identifier(state, content.phone_number);
      if (phone.length === 0) { throw new Error('native_flow_unavailable'); }
      form['phone'] = phone; form['sim_country_code'] = this.identifier(state, content.phone_country_code);
      form['use_voice'] = content.send_via_voice === true; form['send_auto_verify_hash'] = false;
    }
    const result: Record<string, Object | null> = nativeAccountService.object(JSON.parse(await nativeAccountService.request('POST',
      '/1.1/onboarding/begin_verification.json', form, true, state.generation)) as Object);
    state.normalizedPhone = nativeAccountService.string(result['normalized_phone_number']);
    state.verificationTask = task.subtask_id;
  }
}

export const nativeAccountFlow: NativeAccountFlow = new NativeAccountFlow();
