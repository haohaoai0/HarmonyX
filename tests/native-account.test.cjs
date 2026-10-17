const assert = require('node:assert/strict');
const test = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
function evaluate(relative, imports = {}) {
  const source = fs.readFileSync(path.resolve(__dirname, '../entry/src/main/ets', relative), 'utf8');
  const output = ts.transpileModule(source, { compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS } }).outputText;
  const module = { exports: {} };
  new Function('require', 'module', 'exports', '$r', 'Observed', output)(id => {
    if (id in imports) return imports[id];
    throw Error('Unexpected dependency: ' + id);
  }, module, module.exports, name => name, target => target);
  return module.exports;
}
function fixture() {
  let generation = 1, afterRequest, apply = true;
  const requests = [], replies = {}, graphql = {};
  const model = evaluate('models/NativeAccount.ets');
  const result = data => ({ ok: true, status: 200, body: JSON.stringify(data) });
  const client = { isSignedIn: () => true, sessionGeneration: () => generation, viewerId: () => '1',
    accountManagementRequest: async (method, route, payload, json, requestGeneration) => {
      requests.push({ method, route, payload: structuredClone(payload), json, requestGeneration });
      const out = result(typeof replies[route] === 'function' ? replies[route](method, payload) : replies[route] ?? {});
      if (afterRequest) await afterRequest(); return out;
    },
    accountSettingsGraphql: async (name, variables) => {
      requests.push({ name, variables: structuredClone(variables) });
      const response = graphql[name];
      const out = result(typeof response === 'function' ? response(variables, apply) : response ?? { data: {} });
      if (afterRequest) await afterRequest(); return out;
    },
    userByScreenName: async name => result({ profile: { id: '2', username: name } })
  };
  const service = evaluate('services/NativeAccountService.ets', { '../models/NativeAccount': model,
    './XPrivateClient': { xPrivateClient: client }, './XUserParser': { XUserParser: { parse: body => JSON.parse(body).profile } } }).nativeAccountService;
  const flow = evaluate('services/NativeAccountFlow.ets', { '../models/NativeAccount': model, './NativeAccountService': { nativeAccountService: service } }).nativeAccountFlow;
  return { model, client, service, flow, requests, replies, graphql, switch: () => generation++, after: fn => afterRequest = fn, ignore: () => apply = false };
}
test('missing boolean fields cannot be saved as false, and supplied extra fields are rejected', async () => {
  const f = fixture(); f.replies['/1.1/account/settings.json'] = { discoverable_by_email: true };
  const snapshot = await f.service.load('discoverability');
  assert.equal(snapshot.fields[1].available, false);
  const injected = new f.model.NativeAccountField('protected', 'Protected', 'toggle', 'false');
  await assert.rejects(f.service.save('discoverability', snapshot, [...snapshot.fields, injected]), /unavailable/);
  assert.equal(f.requests.filter(r => r.method === 'POST').length, 0);
});
test('account switches after network preparation reject both REST and GraphQL reads', async () => {
  const f = fixture(); f.after(() => f.switch());
  await assert.rejects(f.service.load('discoverability'), /account_changed/);
  const g = fixture(); g.after(() => g.switch());
  await assert.rejects(g.service.load('passkeys'), /account_changed/);
});
test('unknown features and GraphQL errors are unavailable, not empty management lists', async () => {
  const f = fixture(); await assert.rejects(f.service.load('not_implemented'), /unavailable/);
  f.graphql.PasskeyManagement_Query = { data: { viewer_v2: {} }, errors: [{ message: 'Failed' }] };
  await assert.rejects(f.service.load('passkeys'), /unavailable/);
});
test('sensitive media respects fresh server age restrictions and confirms all saved values', async () => {
  const f = fixture(); let canAllow = true;
  const settings = { view_adult_content: 'Drop', view_other_content: 'Warn', view_violent_content: 'Warn' };
  f.graphql.SensitiveMediaSettingsQuery = () => ({ data: { viewer: { user_results: { result: { sensitive_media_settings: {
    can_user_allow_sensitive_content: canAllow, sensitive_media_settings: { ...settings } } } } } } });
  f.graphql.useEditSensitiveMediaSettingsMutation = variables => {
    for (const key of Object.keys(settings)) settings[key] = variables[key];
    return { data: { user_sensitive_media_settings_put: true } };
  };
  const snapshot = await f.service.load('sensitive_categories');
  snapshot.fields.find(x => x.id === 'view_adult_content').value = 'Allow';
  canAllow = false;
  await assert.rejects(f.service.save('sensitive_categories', snapshot, snapshot.fields), /unconfirmed/);
  assert.equal(settings.view_adult_content, 'Drop');
});
test('language updates preserve disabled languages absent from the visible list', async () => {
  const f = fixture(); const preferences = { language_preferences: { disabled_languages: ['es'], extra: 'keep' } };
  f.replies['/1.1/account/personalization/p13n_data.json'] = { languages: [{ key: 'zh', display: '中文' }, { key: 'en', display: 'English' }] };
  f.replies['/1.1/account/personalization/p13n_preferences.json'] = (method, form) => {
    if (method === 'POST') Object.assign(preferences, form.preferences); return preferences;
  };
  const snapshot = await f.service.load('languages'); snapshot.fields[1].value = 'false';
  await f.service.save('languages', snapshot, snapshot.fields);
  assert.deepEqual(preferences.language_preferences, { disabled_languages: ['es', 'en'], extra: 'keep' });
});
test('mute-word updates verify surfaces and options instead of acknowledging an unchanged record', async () => {
  const f = fixture(); f.replies['/1.1/mutes/keywords/list.json'] = { muted_keywords: [{ id: 'a', keyword: 'word', mute_surfaces: ['notifications'], mute_options: [] }] };
  const fields = [['keyword','word'],['home','true'],['notifications','following'],['duration','keep']].map(([id,value]) => new f.model.NativeAccountField(id,id,'text',value));
  await assert.rejects(f.service.keyword('a', fields, 1), /unconfirmed/);
  assert.equal(f.requests[0].payload.duration, undefined);
});
test('current chat device cannot be deregistered, and device records use official registration tokens', async () => {
  const f = fixture(); f.replies['/1.1/keyregistry/extract_public_keys/1'] = { public_keys: [{ registration_token: 'a', device_type: 'Web', is_current_device: true }, { registration_token: 'b', device_type: 'Android', is_current_device: false }] };
  const snapshot = await f.service.load('chat_devices'); assert.equal(snapshot.rows[0].action, ''); assert.equal(snapshot.rows[1].id, 'b');
  await assert.rejects(f.service.rowAction('chat_devices', { ...snapshot.rows[0], action: 'remove_chat_device' }, 1), /unavailable/);
  assert.equal(f.requests.filter(r => r.method === 'DELETE').length, 0);
});
test('vCard contacts and string location history render real names and values', async () => {
  const f = fixture(); f.replies['/1.1/contacts/addressbook.json'] = { contacts: [{ id: 'a', vcard: 'BEGIN:VCARD\r\nFN:张三\r\nEMAIL;TYPE=INTERNET:test@example.com\r\nTEL:123\r\nEND:VCARD' }] };
  const contacts = await f.service.load('imported_contacts'); assert.equal(contacts.rows[0].title, '张三'); assert.match(contacts.rows[0].detail, /test@example/);
  f.replies['/1.1/account/personalization/p13n_data.json'] = { location_history: ['Shanghai', 'Beijing'] };
  assert.deepEqual((await f.service.load('location_history')).rows.map(x => x.title), ['Shanghai','Beijing']);
});
test('password mismatch and stale deactivation forms never dispatch account mutations', async () => {
  const f = fixture(); const password = await f.service.load('password'); password.fields[0].value = 'current'; password.fields[1].value = 'new-password'; password.fields[2].value = 'different';
  await assert.rejects(f.service.save('password', password, password.fields), /invalid_password/);
  const deactivate = await f.service.load('deactivate'); f.switch();
  await assert.rejects(f.service.save('deactivate', deactivate, deactivate.fields), /account_changed/);
  assert.equal(f.requests.length, 0);
});
test('native flow keeps local subtask transitions until the official server link, and resolves email references', async () => {
  const f = fixture(); const state = new f.model.NativeFlowState(); state.token = 'token'; state.flow = 'add_email'; state.generation = 1;
  const email = { subtask_id: 'email', enter_email: { next_link: { link_id: 'next', link_type: 'subtask', subtask_id: 'verify' } } };
  const verify = { subtask_id: 'verify', email_verification: { email: { subtask_data_reference: { subtask_id: 'email', key: 'email' } }, next_link: { link_id: 'finish', link_type: 'task' } } };
  state.tasks = [email,verify];
  await f.flow.submit(state,email,'next','me@example.com',[]); assert.equal(f.requests.length,0); assert.equal(state.tasks[0],verify);
  await f.flow.sendCode(state); assert.equal(f.requests[0].payload.email,'me@example.com');
  f.replies['/1.1/onboarding/task.json'] = { flow_token:'done',status:'success',subtasks:[] };
  const completed = await f.flow.submit(state,verify,'finish','123456',[]);
  assert.equal(completed.completed,true); assert.equal(f.requests[1].payload.subtask_inputs.length,2);
});
test('native flow rejects unexpected links, choices, settings and failure terminals', async () => {
  const f = fixture(); const state = new f.model.NativeFlowState(); state.token='t';state.generation=1;
  const task={subtask_id:'choice',choice_selection:{choices:[{id:'one'}],next_link:{link_id:'next'}}};state.tasks=[task];
  await assert.rejects(f.flow.submit(state,task,'injected','one',[]),/invalid_flow_link/);
  await assert.rejects(f.flow.submit(state,task,'next','injected',[]),/invalid_flow_choice/);
  const settings={subtask_id:'settings',settings_list:{settings:[{value_identifier:'known',value_type:'boolean'}],next_link:{link_id:'next'}}};state.tasks=[settings];
  await assert.rejects(f.flow.submit(state,settings,'next','',[new f.model.NativeAccountField('injected','X','toggle','true')]),/invalid_flow_setting/);
  f.replies['/1.1/onboarding/task.json?flow_name=add_email']={flow_token:'t',status:'fail',subtasks:[]};
  await assert.rejects(f.flow.start('add_email',1),/flow_unavailable/);
  assert.equal(f.requests.filter(r=>r.route==='/1.1/onboarding/task.json').length,0);
});
test('download URLs reject lookalike hosts and credentials', () => {
  const f=fixture(); assert.equal(f.service.safeDownload('https://x.com.evil.example/archive.zip'),false);
  assert.equal(f.service.safeDownload('https://x.com@evil.example/archive.zip'),false);
  assert.equal(f.service.safeDownload('https://ton.twimg.com/archive.zip'),true);
});

test('absent verification flags remain unknown and malformed credential lists fail visibly', async () => {
  const f = fixture();
  f.replies['/1.1/users/email_phone_info.json'] = { emails: [{ email: 'one@example.com' }, { email: 'two@example.com', email_verified: false }] };
  const snapshot = await f.service.load('email');
  assert.equal(snapshot.rows[0].verified, undefined);
  assert.equal(snapshot.rows[1].verified, false);
  assert.equal(snapshot.rows[1].action, 'resend_email');
  await assert.rejects(f.service.load('passkeys'), /unavailable/);
  await assert.rejects(f.service.load('connected_accounts'), /unavailable/);
  await assert.rejects(f.service.load('archive'), /unavailable/);
});

test('REST success status with API errors does not acknowledge a completed password change', async () => {
  const f = fixture();
  const snapshot = await f.service.load('password');
  snapshot.fields[1].value = 'new-password'; snapshot.fields[2].value = 'new-password';
  await assert.rejects(f.service.save('password', snapshot, snapshot.fields), /invalid_password/);
  assert.equal(f.requests.length, 0);
  snapshot.fields[0].value = 'current-password';
  f.replies['/i/account/change_password.json'] = { errors: [{ message: 'Invalid password', code: 32 }] };
  await assert.rejects(f.service.save('password', snapshot, snapshot.fields), /native_request_failed/);
});

test('Grok history follows server cursors, deduplicates pages, and isolates account changes', async () => {
  const f = fixture();
  f.graphql.GrokHistory = variables => ({ data: { grok_conversation_history: {
    cursor: variables.cursor ? null : 'next-page', items: variables.cursor ? [
      { grokConversation: { id: '1' }, title: 'First' }, { grokConversation: { id: '2' }, title: 'Second' }
    ] : [{ grokConversation: { id: '1' }, title: 'First' }] } } });
  const first = await f.service.load('grok_history');
  const next = await f.service.moreHistory(first);
  assert.deepEqual(next.rows.map(row => row.id), ['1', '2']); assert.equal(first.rows.length, 1);
  assert.equal(f.requests.at(-1).variables.cursor, 'next-page');
  f.switch(); await assert.rejects(f.service.moreHistory(first), /account_changed/);
});

test('Grok deletion requires both an error-free response and an empty refreshed history', async () => {
  const f = fixture();
  f.graphql.ClearGrokConversations = { data: { clear_grok_conversations: { grok_deletion_error: { error_code: null } } } };
  await assert.rejects(f.service.clearHistory(1), /unconfirmed/);
  f.graphql.ClearGrokConversations = { data: { clear_grok_conversations: { grok_deletion_error: null } } };
  f.graphql.GrokHistory = { data: { grok_conversation_history: { items: [{ grokConversation: { id: '1' }, title: 'Still present' }] } } };
  await assert.rejects(f.service.clearHistory(1), /unconfirmed/);
  f.graphql.GrokHistory = { data: { grok_conversation_history: { items: [] } } };
  assert.equal((await f.service.clearHistory(1)).rows.length, 0);
});

test('flow terminal tasks do not skip preceding input and reject cancel/failure status', async () => {
  const f = fixture(), route = '/1.1/onboarding/task.json?flow_name=add_email';
  f.replies[route] = { flow_token: 't', status: 'success', subtasks: [
    { subtask_id: 'email', enter_email: { next_link: { link_id: 'next', link_type: 'subtask', subtask_id: 'end' } } },
    { subtask_id: 'end', end_flow: { status: 'success', end_flow_type: 'finish' } }
  ] };
  const state = await f.flow.start('add_email', 1); assert.equal(state.completed, false);
  f.replies['/1.1/onboarding/task.json'] = { flow_token: 'done', status: 'success', subtasks: [] };
  assert.equal((await f.flow.submit(state, state.tasks[0], 'next', 'me@example.com', [])).completed, true);
  assert.equal(f.requests.at(-1).payload.subtask_inputs[0].enter_email.email, 'me@example.com');
  f.replies[route].subtasks = [{ subtask_id: 'end', end_flow: { status: 'cancel' } }];
  await assert.rejects(f.flow.start('add_email', 1), /flow_unavailable/);
});
