export interface NativeAccountRouteParam { feature: string; }

export interface NativeAccountChoice { value: string; label: Resource | string; }

@Observed
export class NativeAccountField {
  id: string;
  title: Resource | string;
  kind: string;
  value: string;
  available: boolean = true;
  choices: NativeAccountChoice[] = [];
  constructor(id: string, title: Resource | string, kind: string, value: string = '') {
    this.id = id; this.title = title; this.kind = kind; this.value = value;
  }
}

export interface NativeAccountRow {
  id: string;
  title: Resource | string;
  detail: string;
  value: string;
  action: string;
  secondaryAction?: string;
  targetId?: string;
  role?: string;
  verified?: boolean;
}

export class NativeAccountSnapshot {
  generation: number = -1;
  fields: NativeAccountField[] = [];
  rows: NativeAccountRow[] = [];
  data: Record<string, Object | null> = {};
  keywords: NativeMutedKeyword[] = [];
  notice: Resource | string = '';
}

export interface NativeMutedKeyword {
  id: string;
  keyword: string;
  mute_surfaces: string[];
  mute_options: string[];
  valid_until?: string;
}

export interface NativeMutedKeywordList { muted_keywords?: NativeMutedKeyword[]; }

export interface NativeFlowText { text?: string; }
export interface NativeFlowLink { link_id: string; label?: string; link_type?: string; url?: string; subtask_id?: string; }
export interface NativeFlowChoice { id: string; label?: NativeFlowText; description?: NativeFlowText; }
export interface NativeFlowSetting {
  value_identifier: string;
  value_type?: string;
  value_data?: NativeFlowValueData;
}
export interface NativeFlowBooleanData { initial_value?: boolean; primary_text?: NativeFlowText; secondary_text?: NativeFlowText; }
export interface NativeFlowValueData { boolean_data?: NativeFlowBooleanData; }
export interface NativeFlowReference { subtask_id: string; key: string; }
export interface NativeFlowIdentifier { string?: string; subtask_data_reference?: NativeFlowReference; }
export interface NativeFlowTaskContent {
  status?: string;
  end_flow_type?: string;
  header?: NativeFlowText;
  primary_text?: NativeFlowText;
  secondary_text?: NativeFlowText;
  hint_text?: string;
  text?: string;
  next_link?: NativeFlowLink;
  primary_button?: NativeFlowLink;
  secondary_button?: NativeFlowLink;
  primary_action_link?: NativeFlowLink;
  secondary_action_link?: NativeFlowLink;
  detail_text?: NativeFlowText;
  normalized_phone?: string;
  email?: NativeFlowIdentifier;
  phone_number?: NativeFlowIdentifier;
  phone_country_code?: NativeFlowIdentifier;
  country_code?: string;
  send_via_voice?: boolean;
  code?: string;
  url?: string;
  choices?: NativeFlowChoice[];
  settings?: NativeFlowSetting[];
}
export interface NativeFlowTask {
  subtask_id: string;
  enter_text?: NativeFlowTaskContent;
  enter_password?: NativeFlowTaskContent;
  enter_email?: NativeFlowTaskContent;
  enter_phone?: NativeFlowTaskContent;
  enter_username?: NativeFlowTaskContent;
  phone_verification?: NativeFlowTaskContent;
  email_verification?: NativeFlowTaskContent;
  cta?: NativeFlowTaskContent;
  show_code?: NativeFlowTaskContent;
  choice_selection?: NativeFlowTaskContent;
  settings_list?: NativeFlowTaskContent;
  check_logged_in_account?: NativeFlowTaskContent;
  wait_spinner?: NativeFlowTaskContent;
  open_link?: NativeFlowTaskContent;
  web_modal?: NativeFlowTaskContent;
  security_key?: NativeFlowTaskContent;
  passkey?: NativeFlowTaskContent;
  end_flow?: NativeFlowTaskContent;
}
export interface NativeFlowResponse { flow_token?: string; status?: string; subtasks?: NativeFlowTask[]; }

export class NativeFlowState {
  token: string = '';
  tasks: NativeFlowTask[] = [];
  generation: number = -1;
  flow: string = '';
  completed: boolean = false;
  inputs: Record<string, Object | null> = {};
  pendingInputs: Record<string, Object | null>[] = [];
  normalizedPhone: string = '';
  verificationEmail: string = '';
  verificationTask: string = '';
}
