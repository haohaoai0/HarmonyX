const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const root = path.resolve(__dirname, '../entry/src/main/ets');
const APP = '2778143c-260a-4e04-83ad-2889f6aaad0d';

function load(file, mocks = {}, storage = new Map()) {
  const source = fs.readFileSync(path.join(root, file + '.ets'), 'utf8');
  const js = ts.transpileModule(source, { compilerOptions: {
    target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS, esModuleInterop: true } }).outputText;
  const module = { exports: {} };
  new Function('require', 'module', 'exports', 'AppStorage', js)(name => {
    if (name in mocks) return mocks[name];
    if (name === './XXAuthSupporterPolicy') return load('services/XXAuthSupporterPolicy');
    throw new Error('Unexpected import ' + name);
  }, module, module.exports, { setOrCreate: (key, value) => storage.set(key, value) });
  return module.exports;
}

const { XXAuthSupporterPolicy: policy, SupporterRecord } = load('services/XXAuthSupporterPolicy');
const now = Date.now();
const ACCOUNT_A = '1188829372918026241';
const ACCOUNT_B = '44196397';
const CODE_A = 'harmonyx-supporter-code-a';
const CODE_B = 'harmonyx-supporter-code-b';
const record = (cardNo, accountId, extra = {}) => ({ cardNo, accountId,
  expiresAt: now + 86400000, verifiedAt: now, ...extra });
const session = (accountId, extra = {}) => ({ responseCode: 200, result: JSON.stringify({ code: 0,
  data: { card_id: 'fixture-card', software_id: APP,
    expires_at: new Date(now + 86400000).toISOString(), bound_machine_code: accountId, ...extra } }) });

function fixture(initial = [], account = { userId: ACCOUNT_A, username: 'supporter' }) {
  let saved = initial.length > 0 ? initial : null;
  let response = session(account === null ? ACCOUNT_A : account.userId);
  let destroyed = 0;
  let saveFails = false;
  const calls = [];
  const storage = new Map();
  const activeAccount = { current: account };
  const asset = {
    Tag: { ALIAS: 1, SECRET: 2, RETURN_TYPE: 3, ACCESSIBILITY: 4, SYNC_TYPE: 5, CONFLICT_RESOLUTION: 6 },
    ReturnType: { ALL: 1 }, Accessibility: { DEVICE_FIRST_UNLOCKED: 1 },
    SyncType: { NEVER: 0 }, ConflictResolution: { OVERWRITE: 0 },
    query: async () => saved ? [new Map([[2, new TextEncoder().encode(JSON.stringify(saved))]])] : [],
    add: async attributes => {
      if (saveFails) throw new Error('asset unavailable');
      saved = JSON.parse(new TextDecoder().decode(attributes.get(2)));
    }
  };
  const mocks = {
    '@kit.AssetStoreKit': { asset },
    '@kit.ArkTS': { util: {
      TextEncoder: class { encodeInto(value) { return new TextEncoder().encode(value); } },
      TextDecoder: class { decodeToString(value) { return new TextDecoder().decode(value); } } } },
    './XXAuthService': { XXAUTH_APP_ID: APP },
    './AccountStore': { accountStore: { active: () => activeAccount.current } },
    '@ohos.net.http': { RequestMethod: { POST: 'POST' }, HttpDataType: { STRING: 0 },
      createHttp: () => ({
        request: async (url, options) => {
          calls.push({ url, options });
          if (response instanceof Error) throw response;
          return response;
        },
        destroy: () => destroyed++ }) }
  };
  const mod = load('services/XXAuthSupporterService', mocks, storage);
  return { mod, create: () => new mod.XXAuthSupporterService(), calls, storage,
    saved: () => saved, respond: value => { response = value }, saveFails: () => { saveFails = true; },
    destroyed: () => destroyed, signIn: accountOrNull => { activeAccount.current = accountOrNull; } };
}

test('a supporter record is valid only for the X account that redeemed it', () => {
  const rows = [record(CODE_A, ACCOUNT_A)];
  assert.equal(policy.active(rows, ACCOUNT_A, now), true);
  assert.equal(policy.active(rows, ACCOUNT_B, now), false);
  assert.equal(policy.active(rows, '', now), false);
  assert.equal(policy.active(rows, ACCOUNT_A, now + 86400000), false);
  for (const broken of [{ ...record(CODE_A, ACCOUNT_A), verifiedAt: 0 },
    { ...record(CODE_A, ACCOUNT_A), expiresAt: NaN }, { ...record('', ACCOUNT_A) }]) {
    assert.equal(policy.active([broken], ACCOUNT_A, now), false);
  }
  assert.equal(policy.active([], ACCOUNT_A, now), false);
  for (const kind of ['recommendation', 'banner']) assert.equal(policy.promotional(kind), true);
  for (const kind of ['announcement', 'article', 'update', 'versions']) {
    assert.equal(policy.promotional(kind), false);
  }
});

test('one account keeps one record and the cache stops growing past its limit', () => {
  let rows = [];
  for (let i = 0; i < 6; i++) {
    rows = policy.upsert(rows, record('code-' + i, 'account-' + i, { verifiedAt: now + i }));
  }
  assert.equal(rows.length, 4);
  assert.deepEqual(rows.map(row => row.accountId).sort(), ['account-2', 'account-3', 'account-4', 'account-5']);
  const replaced = policy.upsert(rows, record(CODE_B, 'account-5', { verifiedAt: now + 99 }));
  assert.equal(replaced.length, 4);
  assert.equal(replaced.filter(row => row.accountId === 'account-5').length, 1);
  assert.equal(policy.recordFor(replaced, 'account-5').cardNo, CODE_B);
});

test('redeeming binds the code to the X user id and never sends X credentials', async () => {
  const f = fixture();
  const service = f.create();
  assert.equal(await service.activate({}, CODE_A), f.mod.SupporterOutcome.SUCCESS);
  assert.equal(service.active(), true);
  assert.equal(f.calls.length, 1);
  assert.equal(f.calls[0].url, 'https://api.xxauth.com/open/v1/card/login');
  assert.deepEqual(JSON.parse(f.calls[0].options.extraData), { card_no: CODE_A, machine_code: ACCOUNT_A });
  assert.deepEqual(Object.keys(f.calls[0].options.header).sort(), ['Accept', 'Content-Type', 'app_id']);
  assert.equal(f.calls[0].options.header.app_id, APP);
  assert.equal(f.saved().length, 1);
  assert.equal(f.saved()[0].accountId, ACCOUNT_A);
  assert.equal(f.saved()[0].cardNo, CODE_A);
  assert.equal(f.storage.get(f.mod.SUPPORTER_ACTIVE_KEY), true);
  assert.ok(!JSON.stringify([...f.storage.values()]).includes(CODE_A));
  assert.equal(f.destroyed(), 1);
});

test('the entitlement follows the signed-in account instead of the device', async () => {
  const f = fixture([record(CODE_A, ACCOUNT_A)]);
  const service = f.create();
  await service.sync({});
  assert.equal(service.active(), true);
  assert.equal(f.storage.get(f.mod.SUPPORTER_ACTIVE_KEY), true);
  f.signIn({ userId: ACCOUNT_B, username: 'other' });
  await service.sync({});
  assert.equal(service.active(), false);
  assert.equal(f.storage.get(f.mod.SUPPORTER_ACTIVE_KEY), false);
  assert.equal(f.storage.get(f.mod.SUPPORTER_EXPIRY_KEY), 0);
  f.signIn({ userId: ACCOUNT_A, username: 'supporter' });
  await service.sync({});
  assert.equal(service.active(), true);
  assert.equal(f.calls.length, 0);
});

test('activation is refused until an X account is signed in', async () => {
  const f = fixture([], null);
  const service = f.create();
  assert.equal(await service.activate({}, CODE_A), f.mod.SupporterOutcome.NO_ACCOUNT);
  assert.equal(service.active(), false);
  assert.equal(f.calls.length, 0);
});

test('offline, rate-limited, server and malformed replies preserve unexpired access', async () => {
  const responses = [new Error('offline'), { responseCode: 429, result: '{"code":429}' },
    { responseCode: 503, result: 'bad gateway' },
    { responseCode: 200, result: JSON.stringify({ code: 0, data: { card_id: 'c', software_id: APP,
      expires_at: 'invalid' } }) },
    { responseCode: 200, result: JSON.stringify({ code: 0, data: { card_id: 'c', software_id: 'other-app',
      expires_at: new Date(now + 86400000).toISOString() } }) }];
  for (const response of responses) {
    const f = fixture([record(CODE_A, ACCOUNT_A)]);
    f.respond(response);
    const service = f.create();
    assert.equal(await service.refresh({}, true), f.mod.SupporterOutcome.NETWORK);
    assert.equal(service.active(), true);
    assert.equal(f.saved()[0].expiresAt, now + 86400000);
    assert.equal(f.destroyed(), 1);
  }
});

test('a retired code stays inactive offline, while other accounts keep their access', async () => {
  const f = fixture([record(CODE_A, ACCOUNT_A), record(CODE_B, ACCOUNT_B)]);
  const service = f.create();
  await service.sync({});
  assert.equal(service.active(), true);
  f.respond({ responseCode: 400, result: '{"code":400,"message":"卡密已被禁用"}' });
  assert.equal(await service.refresh({}, true), f.mod.SupporterOutcome.INVALID);
  assert.equal(service.active(), false);
  assert.equal(policy.recordFor(f.saved(), ACCOUNT_B).cardNo, CODE_B);
  f.respond(new Error('offline'));
  const restarted = f.create();
  await restarted.refresh({}, true);
  assert.equal(restarted.active(), false);
  assert.equal(f.storage.get(f.mod.SUPPORTER_ACTIVE_KEY), false);
});

test('a mistyped code cannot revoke access and each X account redeems its own code', async () => {
  const f = fixture([record(CODE_A, ACCOUNT_A)]);
  const service = f.create();
  f.respond({ responseCode: 404, result: '{"code":404,"message":"卡密不存在"}' });
  assert.equal(await service.activate({}, 'typed-by-mistake'), f.mod.SupporterOutcome.INVALID);
  assert.equal(service.active(), true);
  assert.equal(policy.recordFor(f.saved(), ACCOUNT_A).cardNo, CODE_A);
  // Another signed-in account has no entitlement of its own and inherits none.
  f.signIn({ userId: ACCOUNT_B, username: 'other' });
  assert.equal(await service.refresh({}, true), f.mod.SupporterOutcome.NONE);
  assert.equal(service.active(), false);
  assert.equal(f.calls.length, 1);
  // A code already bound to another account is refused without touching it.
  f.respond({ responseCode: 400, result: '{"code":400,"message":"机器码不匹配"}' });
  assert.equal(await service.activate({}, CODE_A), f.mod.SupporterOutcome.INVALID);
  assert.equal(policy.recordFor(f.saved(), ACCOUNT_B).cardNo, '');
  assert.equal(policy.recordFor(f.saved(), ACCOUNT_A).cardNo, CODE_A);
  // Redeeming a code for this account while signed in succeeds.
  f.respond(session(ACCOUNT_B));
  assert.equal(await service.activate({}, CODE_B), f.mod.SupporterOutcome.SUCCESS);
  assert.equal(service.active(), true);
  assert.equal(policy.recordFor(f.saved(), ACCOUNT_A).cardNo, CODE_A);
  assert.equal(policy.recordFor(f.saved(), ACCOUNT_B).cardNo, CODE_B);
  f.signIn({ userId: ACCOUNT_A, username: 'supporter' });
  await service.sync({});
  assert.equal(service.active(), true);
});

test('a code bound to another account is rejected and unsaved codes never activate', async () => {
  const bound = fixture();
  bound.respond({ responseCode: 400, result: '{"code":400,"message":"机器码不匹配"}' });
  const rejected = bound.create();
  assert.equal(await rejected.activate({}, CODE_A), bound.mod.SupporterOutcome.INVALID);
  assert.equal(rejected.active(), false);
  const unsaved = fixture();
  unsaved.saveFails();
  const service = unsaved.create();
  assert.equal(await service.activate({}, CODE_A), unsaved.mod.SupporterOutcome.STORAGE);
  assert.equal(service.active(), false);
  const expired = fixture();
  expired.respond(session(ACCOUNT_A, { expires_at: new Date(now - 1000).toISOString() }));
  const stale = expired.create();
  await stale.activate({}, CODE_A);
  assert.equal(stale.active(), false);
});

test('revocation covers every card-level rejection without distrusting transient faults', () => {
  // Observed live: a disabled card answers 400 "卡密已被禁用".
  assert.equal(policy.revoked(400, '卡密已被禁用'), true);
  assert.equal(policy.revoked(400, '卡密已被停用'), true);
  assert.equal(policy.revoked(400, '机器码不匹配'), true);
  assert.equal(policy.revoked(404, '卡密不存在'), true);
  assert.equal(policy.revoked(403, '卡密不属于当前软件'), true);
  assert.equal(policy.revoked(403, 'app_id is not allowed'), false);
  for (const status of [408, 429, 500, 502, 503, 0]) {
    assert.equal(policy.revoked(status, ''), false, 'status ' + status);
  }
});

test('expired cached access stays disabled offline and refreshes are coalesced', async () => {
  const f = fixture([record(CODE_A, ACCOUNT_A, { expiresAt: now - 1 })]);
  f.respond(new Error('offline'));
  const service = f.create();
  await Promise.all([service.refresh({}, true), service.refresh({}, true)]);
  assert.equal(service.active(), false);
  assert.equal(f.calls.length, 1);
});

test('supporter labels exist in every locale and match the strings the card uses', () => {
  const source = fs.readFileSync(path.join(root, 'components/SupporterActivationCard.ets'), 'utf8');
  const keys = [...source.matchAll(/\$r\('app\.string\.([^']+)'/g)].map(match => match[1]);
  assert.ok(keys.includes('supporter_account'));
  assert.ok(keys.includes('supporter_account_hint'));
  for (const locale of fs.readdirSync('entry/src/main/resources')) {
    const file = path.join('entry/src/main/resources', locale, 'element/string.json');
    if (!fs.existsSync(file)) continue;
    const rows = JSON.parse(fs.readFileSync(file, 'utf8')).string;
    for (const key of keys) assert.ok(rows.some(row => row.name === key && row.value), locale + ': ' + key);
  }
});
