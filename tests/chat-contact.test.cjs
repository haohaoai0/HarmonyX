const { withDohHttpMock } = require('./doh-http-fixture.cjs');
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
let account = 'a', calls = [], responses = [], listeners = [], parsedMessages = [], uuids = 0, transport = 'plaintext';
const client = {
  viewerId: () => '100', onSessionChange: cb => listeners.push(cb),
  async graphql(name, args) { calls.push({name, args}); return responses.shift(); },
  async restJson(method, path, args) { calls.push({method, path, args}); return responses.shift(); }
};
const mocks = {
  '@kit.AbilityKit': {}, '@ohos.util': {default: {generateRandomUUID: () => 'request-' + ++uuids}},
  './XPrivateClient': {xPrivateClient: client}, './XPrivateStore': {xPrivateStore: {load: () => ({cacheIdentity: () => account})}},
  './XDmParser': {XDmParser: {parseConversation: () => ({messages: parsedMessages})}}
  , './XChatService': {xChatService: {conversationTransport: () => transport, cachePlaintextMessages: () => { transport = 'plaintext'; }}}
};
const mod = {exports: {}};
const code = ts.transpileModule(fs.readFileSync('entry/src/main/ets/services/ChatContactService.ets', 'utf8'), {
  compilerOptions: {target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS}
}).outputText;
new Function('require', 'module', 'exports', code)(id => (() => { withDohHttpMock(mocks); return id === '../utils/UserIdentity' ? require('./post-card-fixture.cjs').load('utils/UserIdentity') : mocks[id] || {}; })(), mod, mod.exports);
const {ChatContactService, ChatContact} = mod.exports;
const ok = body => ({ok: true, status: 200, body: JSON.stringify(body)});
const numberOk = () => ok({data: {xchat_verify_x_number: {enabled: true}}});
function reset() { account = 'a'; calls = []; responses = []; parsedMessages = []; uuids = 0; transport = 'plaintext'; }
function contact() { const c = new ChatContact(); c.id = '200'; c.permissionKnown = true; c.canSend = true; return c; }

test('contact metadata preserves company verification, affiliation, join date and closed inbox', () => {
  const body = {data: {get_member_results: {results: [{id: '200', member_results: {rest_id: '200', result: {
    __typename: 'User', core: {name: 'Business', screen_name: 'XBusiness', created_at_ms: '1267401600000'},
    avatar: {image_url: 'https://pbs.twimg.com/business.jpg'}, relationship_counts: {followers: 1434000},
    verification: {is_blue_verified: false, verified: true, is_verified_organization: true, verified_type: 'Business'},
    identity_profile_labels_highlighted_label: {label: {badge: {url: 'https://pbs.twimg.com/x.jpg'}, description: 'X'}},
    chat_permissions: {can_dm: true, can_dm_on_xchat: false, has_public_key: false, can_dm_reason: 'InboxClosed'}
  }}}]}}};
  const c = ChatContactService.parse(JSON.stringify(body), '200');
  assert.equal(c.name, 'Business'); assert.equal(c.verified, true); assert.equal(c.verifiedType, 'Business');
  assert.equal(c.affiliationUrl, 'https://pbs.twimg.com/x.jpg'); assert.equal(c.followers, 1434000);
  assert.equal(c.createdAt, new Date(1267401600000).toISOString()); assert.equal(c.canSend, false);
  assert.equal(c.cannotMessageReason, 'INBOX_CLOSED'); assert.equal(ChatContactService.parse(JSON.stringify(body), '300'), null);
});
test('the GraphQL Allowed reason enables messaging and missing follower counts stay unknown', () => {
  const c = ChatContactService.parse(JSON.stringify({data: {get_member_results: {results: [{id: '200', member_results: {
    rest_id: '200', result: {__typename: 'User', chat_permissions: {can_dm: true, has_public_key: false, can_dm_reason: 'Allowed'}}
  }}]}}}), '200');
  assert.equal(c.canSend, true); assert.equal(c.cannotMessageReason, ''); assert.equal(c.followersKnown, false);
});
test('number verification uses the recipient mutation and clears no permission on incomplete success', async () => {
  reset(); const service = new ChatContactService();
  await assert.rejects(service.verifyNumber({}, '200', '1234'), /invalid_contact_number/); assert.equal(calls.length, 0);
  responses.push(numberOk()); await service.verifyNumber({}, '200', '1234-5678');
  assert.deepEqual(calls[0], {name: 'VerifyXChatNumberMutation', args: {number: '12345678', target_user_id: '200'}});
  responses.push(ok({data: {xchat_verify_x_number: {enabled: false}}}));
  await assert.rejects(service.verifyNumber({}, '300', '12345678'), /contact_number_rejected/);
  responses.push(ok({data: {xchat_verify_x_number: {enabled: true}}, errors: [{message: 'Rejected'}]}));
  await assert.rejects(service.verifyNumber({}, '300', '12345678'), /contact_number_rejected/);
});
test('a closed inbox stays blocked until its own number is verified for the current account', async () => {
  reset(); const service = new ChatContactService(), c = contact(); c.canSend = false; c.cannotMessageReason = 'INBOX_CLOSED';
  await assert.rejects(service.sendPlaintext({}, c, '100-200', 'hello'), /chat_not_allowed/);
  responses.push(numberOk()); await service.verifyNumber({}, '300', '12345678');
  await assert.rejects(service.sendPlaintext({}, c, '100-200', 'hello'), /chat_not_allowed/);
  responses.push(numberOk()); await service.verifyNumber({}, '200', '12345678');
  account = 'b'; await assert.rejects(service.sendPlaintext({}, c, '100-200', 'hello'), /chat_not_allowed/);
  account = 'a'; c.cannotMessageReason = 'IS_DM_BLOCKING_ME';
  await assert.rejects(service.sendPlaintext({}, c, '100-200', 'hello'), /chat_not_allowed/);
});
test('account changes during number verification cannot grant recipient access', async () => {
  reset(); const service = new ChatContactService();
  responses.push({ok: true, get body() { account = 'b'; return JSON.stringify({data: {xchat_verify_x_number: {enabled: true}}}); }});
  // Change before the service's response check, as a real asynchronous account switch would.
  const prior = client.graphql;
  client.graphql = async (name, args) => { const r = await prior(name, args); account = 'b'; return r; };
  await assert.rejects(service.verifyNumber({}, '200', '12345678'), /account_changed/);
  client.graphql = prior;
});
test('plaintext sending follows the conversation even when a recipient registers a public key', async () => {
  reset(); const service = new ChatContactService(), c = contact(); c.hasPublicKey = true;
  transport = 'encrypted';
  await assert.rejects(service.sendPlaintext({}, c, '100-200', 'hello'), /chat_not_allowed/); assert.equal(calls.length, 0);
  transport = 'unknown';
  await assert.rejects(service.sendPlaintext({}, c, '100-200', 'hello'), /chat_not_allowed/);
  transport = 'plaintext'; responses.push(ok({}));
  await assert.rejects(service.sendPlaintext({}, c, '100-200', 'hello'), /send_unconfirmed/);
  parsedMessages = [{id: '9', conversationId: '100-200', outgoing: true, text: 'hello'}]; responses.push(ok({}));
  const rows = await service.sendPlaintext({}, c, '100-200', 'hello');
  assert.equal(rows[0].id, '9'); assert.equal(calls[0].path, '/1.1/dm/new2.json');
  assert.equal(calls[0].args.request_id, calls[1].args.request_id); assert.equal(calls[0].args.recipient_ids, '200');
  assert.equal(uuids, 1);
});
