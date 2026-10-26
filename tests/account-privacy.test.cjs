const assert = require('node:assert/strict');
const test = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function evaluate(relative, imports = {}) {
  const source = fs.readFileSync(path.resolve(__dirname, '../entry/src/main/ets', relative), 'utf8');
  const output = ts.transpileModule(source, { compilerOptions: {
    target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
  } }).outputText;
  const module = { exports: {} };
  new Function('require', 'module', 'exports', '$r', output)(id => {
    if (id in imports) return imports[id];
    if (id === './XPostCardParser' || id === './XPollRequest') return require('./post-card-fixture.cjs');
    throw new Error('Unexpected dependency: ' + id);
  }, module, module.exports, name => name);
  return module.exports;
}

function fixture() {
  let generation = 1;
  let signedIn = true;
  let failed = false;
  let acknowledge = true;
  let apply = true;
  let afterRead;
  const requests = [];
  const localWrites = [];
  const account = { screen_name: 'account_one', protected: false, allow_media_tagging: 'none',
    nsfw_user: false, nsfw_admin: false, display_sensitive_media: false,
    geo_enabled: false, allow_ads_personalization: true };
  const preferences = { allow_video_downloads: true, allow_xai_data_sharing: true,
    allow_xai_personalization: true, allow_grok_memory: true, allow_for_you_recommendations: true,
    inferred_location_resolution_preference: 'Country', about_this_account_user_preferences: {
      selected_business_country_code: 'US', business_country_code_preferences: [{ country_code: 'US', country_name: 'United States' }]
    } };
  let sessions = [{ token: 'current', is_current_session: true }, { token: 'other', is_current_session: false }];
  let applications = [{ token: 'one', app_id: 'app', name: 'An app' }, { token_hash: 'two', app_id: 'oauth2' }];
  const result = body => ({ ok: !failed, status: failed ? 503 : 200, body: JSON.stringify(body) });
  const client = {
    isSignedIn: () => signedIn,
    viewerId: () => '1',
    sessionGeneration: () => generation,
    accountSettingsRest: async (method, route, form) => {
      requests.push({ method, route, form });
      if (failed) return result({});
      if (method === 'GET') {
        const out = result(route.includes('/oauth/') ? { applications } : account);
        if (afterRead) await afterRead();
        return out;
      }
      if (apply) {
        if (route.includes('/account/settings')) for (const [key, value] of Object.entries(form))
          account[key] = value === 'true' ? true : value === 'false' ? false : value;
        if (route.endsWith('/sessions/revoke')) sessions = sessions.filter(s => s.token !== form.hashed_token);
        if (route.endsWith('/sessions/revoke_all')) sessions = sessions.filter(s => s.is_current_session);
        if (route.includes('revoke_token_hash')) applications = applications.filter(a => a.token_hash !== form.token_hash);
        if (route.includes('/oauth/revoke')) applications = applications.filter(a => a.token !== form.token);
      }
      return result({});
    },
    accountSettingsGraphql: async (name, variables) => {
      requests.push({ name, variables });
      if (failed) return result({});
      if (name === 'UserSessionsList') return result({ data: { viewer: { user_results: { result: { sessions_list: sessions } } } } });
      if (name.endsWith('Query')) return result({ data: { user_preferences: preferences } });
      if (apply) {
        const map = { isAllowed: 'allow_video_downloads', allowXaiDataSharing: 'allow_xai_data_sharing',
          allowXaiPersonalization: 'allow_xai_personalization', allow_grok_memory: 'allow_grok_memory',
          inferred_location_resolution_preference: 'inferred_location_resolution_preference',
          allow_for_you_recommendations: 'allow_for_you_recommendations' };
        for (const [key, value] of Object.entries(variables)) if (value !== null && map[key]) preferences[map[key]] = value;
      }
      return result({ data: { user_preferences_put: acknowledge } });
    }
  };
  const models = evaluate('models/AccountPrivacy.ets');
  const { accountPrivacyService: service } = evaluate('services/AccountPrivacyService.ets', {
    '../models/AccountPrivacy': models, './XPrivateClient': { xPrivateClient: client },
    './MediaSettingsStore': { mediaSettingsStore: { saveShowSensitiveMedia: (context, value) => localWrites.push(value) } }
  });
  return { service, client, account, preferences, requests, localWrites,
    switchAccount: () => generation++, signOut: () => { signedIn = false; generation++; },
    fail: () => { failed = true; }, noAcknowledgment: () => { acknowledge = false; },
    noApply: () => { apply = false; }, afterRead: hook => { afterRead = hook; },
    sessions: () => sessions, setSessions: value => { sessions = value; }, setApplications: value => { applications = value; } };
}

test('failed and absent values remain unavailable; a false setting remains editable', async () => {
  const f = fixture();
  const snapshot = await f.service.read('audience');
  assert.equal(f.service.booleanValue(snapshot, 'protected'), false);
  assert.equal(f.service.booleanValue(snapshot, 'allow_logged_out_device_personalization'), undefined);
  f.account.protected = 'false';
  assert.equal(f.service.booleanValue(await f.service.read('audience'), 'protected'), undefined);
  f.fail();
  const failed = await f.service.read('audience');
  assert.equal(failed.incomplete, true);
  assert.equal(f.service.booleanValue(failed, 'protected'), undefined);
  assert.equal(f.service.booleanValue(failed, 'protected_videos'), undefined);
});

test('a confirmed REST change writes only the selected field and re-reads it', async () => {
  const f = fixture();
  const snapshot = await f.service.saveBoolean('audience', 'protected', true, 1);
  assert.equal(f.service.booleanValue(snapshot, 'protected'), true);
  assert.deepEqual(f.requests.filter(r => r.method === 'POST').map(r => r.form), [{ protected: 'true' }]);
  assert.equal(f.requests.filter(r => r.route?.includes('/account/settings')).length, 3);
});

test('an HTTP success that does not persist the change cannot report success', async () => {
  const f = fixture(); f.noApply();
  await assert.rejects(f.service.saveBoolean('content', 'display_sensitive_media', true, 1), /settings_unconfirmed/);
  assert.deepEqual(f.localWrites, []);
});

test('protected-video UI has inverse semantics to allow_video_downloads', async () => {
  const f = fixture();
  const snapshot = await f.service.saveBoolean('audience', 'protected_videos', true, 1);
  assert.equal(f.service.booleanValue(snapshot, 'protected_videos'), true);
  assert.deepEqual(f.requests.find(r => r.name === 'AudienceAndTaggingAllowVideoDownloadsMutation').variables, { isAllowed: false });
});

test('a rejected GraphQL scalar acknowledgment cannot report success', async () => {
  const f = fixture(); f.noAcknowledgment();
  await assert.rejects(f.service.saveBoolean('grok_privacy', 'allow_xai_data_sharing', false, 1), /settings_unconfirmed/);
});

test('Grok changes do not overwrite other Grok preferences', async () => {
  const f = fixture();
  await f.service.saveBoolean('grok_privacy', 'allow_xai_personalization', false, 1);
  assert.equal(f.preferences.allow_xai_data_sharing, true);
  assert.equal(f.preferences.allow_grok_memory, true);
  assert.deepEqual(f.requests.find(r => r.name === 'XaiPersonalizationSettingsMutation').variables, { allowXaiPersonalization: false });
});

test('a stale page cannot write to a switched or signed-out account', async () => {
  const f = fixture(); f.switchAccount();
  await assert.rejects(f.service.saveBoolean('audience', 'protected', true, 1), /account_changed/);
  assert.equal(f.requests.length, 0);
  f.signOut();
  await assert.rejects(f.service.clearData('contacts', 3), /no_session/);
});

test('an account change during a read prevents writes and local media synchronization', async () => {
  const f = fixture(); f.afterRead(async () => { f.switchAccount(); });
  await assert.rejects(f.service.syncSensitiveMedia({}), /account_changed/);
  assert.equal(f.localWrites.length, 0);
});

test('server-enforced sensitive-media marking cannot be disabled', async () => {
  const f = fixture(); f.account.nsfw_admin = true;
  await assert.rejects(f.service.saveBoolean('posts', 'nsfw_user', true, 1), /settings_unavailable/);
  assert.equal(f.requests.filter(r => r.method === 'POST').length, 0);
});

test('choices reject arbitrary values and countries absent from server options', async () => {
  const f = fixture();
  await assert.rejects(f.service.saveChoice('audience', 'allow_media_tagging', 'arbitrary', 1), /invalid_choice/);
  await assert.rejects(f.service.saveChoice('about_account', 'selected_business_country_code', 'FAKE', 1), /invalid_choice/);
  assert.equal(f.requests.filter(r => r.method === 'POST').length, 0);
});

test('revocation preserves the current session and refuses an ambiguous session', async () => {
  const f = fixture();
  await assert.rejects(f.service.revokeSession('current', 1), /invalid_session/);
  f.setSessions([{ token: 'uncertain' }]);
  await assert.rejects(f.service.revokeSession('uncertain', 1), /invalid_session/);
  assert.equal(f.requests.filter(r => r.method === 'POST').length, 0);
});

test('revocation is confirmed by the remaining session list', async () => {
  const f = fixture();
  const remaining = await f.service.revokeSession('other', 1);
  assert.deepEqual(remaining.sessions.map(s => s.token), ['current']);
  const g = fixture(); g.noApply();
  await assert.rejects(g.service.revokeOtherSessions(1), /settings_unconfirmed/);
});

test('OAuth 1 and OAuth 2 revoke only the selected grant and require removal', async () => {
  const f = fixture();
  await f.service.revokeApplication({ token_hash: 'two' }, 1);
  assert.deepEqual(f.requests.find(r => r.route === '/2/oauth2/revoke_token_hash').form, { token_hash: 'two' });
  const remaining = await f.service.revokeApplication({ token: 'one' }, 1);
  assert.equal(remaining.applications.length, 0);
  const g = fixture(); g.noApply();
  await assert.rejects(g.service.revokeApplication({ token: 'one' }, 1), /settings_unconfirmed/);
});

test('all management sections are reachable and all resource names exist in every locale', () => {
  const { ACCOUNT_MANAGEMENT_SECTIONS: sections } = evaluate('services/AccountManagementCatalog.ets');
  const locales = ['base', 'zh_CN', 'en', 'it'].map(locale => new Set(JSON.parse(fs.readFileSync(
    path.resolve(__dirname, '../entry/src/main/resources', locale, 'element/string.json'), 'utf8')).string.map(row => row.name)));
  const sectionMap = new Map(sections.map(section => [section.id, section]));
  const reachable = new Set(['account', 'security', 'privacy']);
  for (let changed = true; changed;) {
    changed = false;
    for (const id of [...reachable]) for (const item of sectionMap.get(id).items) if (item.action === 'group' && !reachable.has(item.target)) {
      assert.ok(sectionMap.has(item.target), item.target); reachable.add(item.target); changed = true;
    }
  }
  assert.equal(reachable.size, sections.length);
  for (const section of sections) {
    assert.match(section.officialPath, /^\/(settings\/|i\/)/);
    for (const resource of [section.title, ...section.items.flatMap(item => [item.title, item.detail])]) {
      for (const locale of locales) assert.ok(locale.has(resource.replace('app.string.', '')), resource);
    }
  }
});

function transportFixture() {
  const requests = [];
  const logs = [];
  let transactionHook = async () => {};
  let proxyHook = async () => {};
  let requestHook = async () => ({ responseCode: 200, result: '{}' });
  let failureHook = () => true;
  class Session {
    constructor(authToken = '', ct0 = '', userId = '') {
      this.authToken = authToken; this.ct0 = ct0; this.userId = userId;
      this.rawCookie = 'auth_token=' + authToken + '; ct0=' + ct0;
    }
    cacheIdentity() { return this.userId; }
    isUsable() { return !!this.authToken && !!this.ct0; }
  }
  const imports = {
    '@ohos.net.http': { default: { RequestMethod: { POST: 'POST', GET: 'GET' }, createHttp: () => ({
      request: async (url, options) => { requests.push({ url, options }); return requestHook(); }, destroy: () => {}
    }) } },
    '@ohos.hilog': { default: Object.fromEntries(['info', 'warn', 'error'].map(level => [level, (...args) => logs.push(args)])) },
    '@ohos.file.fs': {}, '@ohos.util': {}, '@kit.ImageKit': {},
    '../models/XOperations': {}, './XPrivateStore': { XSession: Session },
    './XTransactionId': { xTransactionId: { resolve: async () => { await transactionHook(); return 'transaction'; } } },
    './XUserAgent': { xUserAgent: { value: () => 'test-agent' } },
    './ProxyStore': { proxyStore: { apply: async () => proxyHook(), noteNetworkFailure: () => failureHook() } },
    './XTimelineParser': {}, './XListParser': {}, './XConnectFeatures': {}, './JetfuelDecoder': {},
    './XStarterPackParser': {}, './XGlobalTrendsParser': {}, './XPostContentOperations': {
      postContentOperation: () => ({ id: '', features: {}, toggles: {} })
    }, './XPostResponse': { XPostReceipt: class {} }, './ResponseCache': {},
    './RequestLog': { requestLog: { record: (...args) => logs.push(args) } },
    './XSpaceOperations': {}, './XChatConversationId': {},
    '../models/ComposerOptions': { ComposerOptions: class {}, ComposerCoordinates: class {} },
    './XComposerRequest': { composerPrivateFields: () => ({}), composerPollCard: () => ({}),
      composerScheduleVariables: () => ({}) },
    './XComposerOperations': { COMPOSER_WEB_FLAGS: {}, composerWebQueryId: () => '',
      composerWebToggles: () => ({}) },
    './XVideoOperations': { IMMERSIVE_MEDIA_QUERY_ID: '', IMMERSIVE_TIMELINE_QUERY_ID: '',
      immersiveWebFeatures: () => ({}), immersiveWebToggles: () => ({}) },
    '../models/AccountPrivacy': evaluate('models/AccountPrivacy.ets')
  };
  const { XPrivateClient } = evaluate('services/XPrivateClient.ets', imports);
  const client = new XPrivateClient();
  client.setSession(new Session('auth_one', 'csrf_one', '1'));
  return { client, requests, logs,
    rotate: () => client.setSession(new Session('auth_two', 'csrf_two', '2')),
    signOut: () => client.setSession(new Session()),
    transaction: hook => { transactionHook = hook; }, proxy: hook => { proxyHook = hook; },
    request: hook => { requestHook = hook; }, failure: hook => { failureHook = hook; }
  };
}

test('a switch during transaction preparation cancels the REST write before dispatch', async () => {
  const f = transportFixture();
  f.transaction(async () => f.rotate());
  const result = await f.client.accountSettingsRest('POST', '/1.1/account/settings.json', { protected: 'true' });
  assert.equal(result.errorText, 'account_changed');
  assert.equal(f.requests.length, 0);
});

test('signing out during proxy preparation cancels a GraphQL write before dispatch', async () => {
  const f = transportFixture();
  f.proxy(async () => f.signOut());
  const result = await f.client.accountSettingsGraphql('XaiDataSharingSettingsMutation', { allowXaiDataSharing: false });
  assert.equal(result.errorText, 'account_changed');
  assert.equal(f.requests.length, 0);
});

test('settings writes are not retried, and private exception details stay out of logs', async () => {
  const f = transportFixture();
  f.request(async () => { throw { message: 'private-submitted-value', cookie: 'private-auth-cookie' }; });
  const result = await f.client.accountSettingsRest('POST', '/1.1/account/settings.json', { protected: 'true' });
  assert.equal(result.ok, false);
  assert.equal(f.requests.length, 1);
  assert.doesNotMatch(JSON.stringify(f.logs), /private-submitted-value|private-auth-cookie/);
});

test('a retry of a settings read retains its original account binding', async () => {
  const f = transportFixture();
  f.request(async () => { throw new Error('network failed'); });
  f.failure(() => { f.rotate(); return true; });
  const result = await f.client.accountSettingsRest('GET', '/1.1/account/settings.json', {});
  assert.equal(result.errorText, 'account_changed');
  assert.equal(f.requests.length, 1);
});
