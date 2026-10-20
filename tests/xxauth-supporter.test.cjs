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
  const assets = new Map();
  const encode = value => new TextEncoder().encode(JSON.stringify(value));
  const decode = value => JSON.parse(new TextDecoder().decode(value));
  if (initial.length) assets.set('harmonyx_supporter_v1', encode(initial));
  let response = session(account === null ? ACCOUNT_A : account.userId);
  let destroyed = 0;
  let saveFails = false;
  let readError = null;
  let readGate = null;
  const calls = [];
  const queries = [];
  const storage = new Map();
  const activeAccount = { current: account };
  const asset = {
    Tag: { ALIAS: 1, SECRET: 2, RETURN_TYPE: 3, ACCESSIBILITY: 4, SYNC_TYPE: 5, CONFLICT_RESOLUTION: 6 },
    ReturnType: { ALL: 1 }, Accessibility: { DEVICE_FIRST_UNLOCKED: 1 },
    SyncType: { NEVER: 0 }, ConflictResolution: { OVERWRITE: 0 },
    ErrorCode: { NOT_FOUND: 24000002 },
    query: async attributes => {
      const alias = new TextDecoder().decode(attributes.get(1));
      queries.push(alias);
      if (readGate) await readGate;
      if (readError) throw readError;
      if (!assets.has(alias)) throw Object.assign(new Error('not found'), { code: 24000002 });
      return [new Map([[2, assets.get(alias)]])];
    },
    add: async attributes => {
      if (saveFails) throw new Error('asset unavailable');
      assert.ok(attributes.get(2).length <= 1024, 'real AssetStore secret limit');
      assets.set(new TextDecoder().decode(attributes.get(1)), attributes.get(2));
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
          const reply = typeof response === 'function' ? response(url, options) : response;
          if (reply instanceof Error) throw reply;
          return await reply;
        },
        destroy: () => destroyed++ }) }
  };
  const mod = load('services/XXAuthSupporterService', mocks, storage);
  return { mod, create: () => new mod.XXAuthSupporterService(), calls, storage,
    saved: () => {
      let rows = initial.slice();
      for (const [alias, bytes] of assets) {
        if (!alias.startsWith('harmonyx_supporter_account_v2_')) continue;
        const row = decode(bytes);
        rows = rows.filter(item => item.accountId !== row.accountId).concat(row);
      }
      return rows.length ? rows : null;
    },
    assets, queries, respond: value => { response = value }, saveFails: (value = true) => { saveFails = value; },
    readFails: value => { readError = value; }, readWaits: value => { readGate = value; },
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

test('one account keeps one record and switching past four accounts never evicts credentials', () => {
  let rows = [];
  for (let i = 0; i < 6; i++) {
    rows = policy.upsert(rows, record('test-code-' + i, String(100 + i), { verifiedAt: now + i }));
  }
  assert.equal(rows.length, 6);
  const replaced = policy.upsert(rows, record(CODE_B, '105', { verifiedAt: now + 99 }));
  assert.equal(replaced.length, 6);
  assert.equal(replaced.filter(row => row.accountId === '105').length, 1);
  assert.equal(policy.recordFor(replaced, '105').cardNo, CODE_B);
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
  assert.equal(f.calls[0].options.usingCache, false);
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
      expires_at: 'invalid', bound_machine_code: ACCOUNT_A } }) },
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

function deferred() {
  let resolve;
  const promise = new Promise(done => { resolve = done; });
  return { promise, resolve };
}
const settle = () => new Promise(resolve => setImmediate(resolve));

test('an in-flight A activation never activates B, and B verifies its own code after A finishes', async () => {
  const f = fixture();
  const service = f.create();
  const pending = deferred();
  f.respond(pending.promise);
  const first = service.activate({}, CODE_A);
  await settle();
  assert.equal(f.calls.length, 1);
  f.signIn({ userId: ACCOUNT_B, username: 'other' });
  assert.equal(service.active(), false, 'no watcher required to stop A access leaking to B');
  const second = service.activate({}, CODE_B);
  await settle();
  assert.equal(f.calls.length, 1, 'different requests are serialized');
  assert.equal(f.storage.get(f.mod.SUPPORTER_ACTIVE_KEY), false);
  f.respond(session(ACCOUNT_B));
  pending.resolve(session(ACCOUNT_A));
  assert.equal(await first, f.mod.SupporterOutcome.SUCCESS);
  assert.equal(await second, f.mod.SupporterOutcome.SUCCESS);
  assert.equal(f.calls.length, 2);
  assert.deepEqual(f.calls.map(call => JSON.parse(call.options.extraData)), [
    { card_no: CODE_A, machine_code: ACCOUNT_A }, { card_no: CODE_B, machine_code: ACCOUNT_B }
  ]);
  assert.equal(service.active(), true);
  f.signIn({ userId: ACCOUNT_A, username: 'renamed_handle' });
  await service.sync({});
  assert.equal(service.active(), true);
});

test('switching to B during an A request publishes B cached expiry and never A expiry', async () => {
  const bExpiry = now + 123456;
  const f = fixture([record(CODE_A, ACCOUNT_A), record(CODE_B, ACCOUNT_B, { expiresAt: bExpiry })]);
  const service = f.create();
  const pending = deferred();
  f.respond(pending.promise);
  const first = service.refresh({}, true);
  await settle();
  f.signIn({ userId: ACCOUNT_B, username: 'other' });
  await service.sync({});
  assert.equal(f.storage.get(f.mod.SUPPORTER_EXPIRY_KEY), bExpiry);
  pending.resolve(session(ACCOUNT_A));
  await first;
  assert.equal(f.storage.get(f.mod.SUPPORTER_ACTIVE_KEY), true);
  assert.equal(f.storage.get(f.mod.SUPPORTER_EXPIRY_KEY), bExpiry);
});

test('an activation started before storage loads is cancelled if the selected account changes', async () => {
  const f = fixture();
  const service = f.create();
  const read = deferred();
  f.readWaits(read.promise);
  const task = service.activate({}, CODE_A);
  f.signIn({ userId: ACCOUNT_B, username: 'other' });
  read.resolve();
  assert.equal(await task, f.mod.SupporterOutcome.NONE);
  assert.equal(f.calls.length, 0, 'must not bind A input to B');
  assert.equal(service.active(), false);
});

test('a queued activation is cancelled on logout and an older response cannot restore logged-out access', async () => {
  const f = fixture();
  const service = f.create();
  const pending = deferred();
  f.respond(pending.promise);
  const first = service.activate({}, CODE_A);
  await settle();
  f.signIn({ userId: ACCOUNT_B, username: 'other' });
  const second = service.activate({}, CODE_B);
  await settle();
  f.signIn(null);
  await service.sync({});
  pending.resolve(session(ACCOUNT_A));
  await first;
  assert.equal(await second, f.mod.SupporterOutcome.NONE);
  assert.equal(f.calls.length, 1);
  assert.equal(service.active(), false);
  assert.equal(f.storage.get(f.mod.SUPPORTER_ACTIVE_KEY), false);
});

test('a new code never borrows the result of another code being checked for the same account', async () => {
  const f = fixture([record(CODE_A, ACCOUNT_A)]);
  const service = f.create();
  const pending = deferred();
  f.respond(pending.promise);
  const first = service.refresh({}, true);
  await settle();
  const second = service.activate({}, CODE_B);
  await settle();
  f.respond({ responseCode: 404, result: '{"code":404,"message":"卡密不存在"}' });
  pending.resolve(session(ACCOUNT_A));
  assert.equal(await first, f.mod.SupporterOutcome.SUCCESS);
  assert.equal(await second, f.mod.SupporterOutcome.INVALID);
  assert.equal(f.calls.length, 2);
  assert.equal(policy.recordFor(f.saved(), ACCOUNT_A).cardNo, CODE_A);
  assert.equal(service.active(), true);
});

test('refresh throttles are per account so switching A to B does not postpone B cloud verification', async () => {
  const f = fixture([record(CODE_A, ACCOUNT_A), record(CODE_B, ACCOUNT_B)]);
  f.respond((url, options) => session(JSON.parse(options.extraData).machine_code));
  const service = f.create();
  await service.refresh({});
  f.signIn({ userId: ACCOUNT_B, username: 'other' });
  await service.refresh({});
  assert.equal(f.calls.length, 2);
  f.signIn({ userId: ACCOUNT_A, username: 'renamed' });
  await service.refresh({});
  assert.equal(f.calls.length, 2, 'A keeps its own throttle');
  assert.equal(service.active(), true);
});

test('locked asset storage retries after unlock without binding a new card or overwriting old accounts', async () => {
  const f = fixture([record(CODE_A, ACCOUNT_A), record(CODE_B, ACCOUNT_B)]);
  const service = f.create();
  f.readFails(Object.assign(new Error('locked'), { code: 24000003 }));
  assert.equal(await service.activate({}, CODE_B), f.mod.SupporterOutcome.STORAGE);
  assert.equal(f.calls.length, 0);
  assert.equal(f.saved().length, 2);
  f.readFails(null);
  await service.sync({});
  assert.equal(service.active(), true);
  assert.equal(policy.recordFor(f.saved(), ACCOUNT_A).cardNo, CODE_A);
});

test('credentials for many accounts use separate assets under 1024 bytes and survive a service restart', async () => {
  const f = fixture();
  const service = f.create();
  f.respond((url, options) => session(JSON.parse(options.extraData).machine_code));
  for (let i = 0; i < 8; i++) {
    f.signIn({ userId: String(1000 + i), username: 'account' + i });
    assert.equal(await service.activate({}, 'x'.repeat(253) + String(i).padStart(3, '0')), f.mod.SupporterOutcome.SUCCESS);
  }
  assert.equal(f.assets.size, 8);
  const restarted = f.create();
  for (let i = 7; i >= 0; i--) {
    f.signIn({ userId: String(1000 + i), username: 'renamed' + i });
    await restarted.sync({});
    assert.equal(restarted.active(), true);
  }
  assert.equal(f.calls.length, 8, 'cached switches do not activate again');
});

test('v2 revocation overrides an old v1 entitlement through upgrades and offline restarts', async () => {
  const f = fixture([null, record(CODE_A, ACCOUNT_A), record(CODE_B, ACCOUNT_B)]);
  const service = f.create();
  f.respond({ responseCode: 400, result: '{"code":400,"message":"卡密已被禁用"}' });
  assert.equal(await service.refresh({}, true), f.mod.SupporterOutcome.INVALID);
  assert.ok(f.assets.has('harmonyx_supporter_v1'), 'legacy remains intact for other accounts');
  f.respond(new Error('offline'));
  const restarted = f.create();
  await restarted.refresh({}, true);
  assert.equal(restarted.active(), false);
  f.signIn({ userId: ACCOUNT_B, username: 'other' });
  await restarted.sync({});
  assert.equal(restarted.active(), true);
});

test('storage failure cannot keep a cloud-revoked account active during the current process', async () => {
  const f = fixture([record(CODE_A, ACCOUNT_A)]);
  const service = f.create();
  await service.sync({});
  f.saveFails();
  f.respond({ responseCode: 400, result: '{"code":400,"message":"卡密已过期"}' });
  assert.equal(await service.refresh({}, true), f.mod.SupporterOutcome.STORAGE);
  assert.equal(service.active(), false);
  assert.equal(f.storage.get(f.mod.SUPPORTER_ACTIVE_KEY), false);
});

test('missing server binding never activates and mismatched binding retires only its original record', async () => {
  for (const binding of [undefined, null, '', 123]) {
    const f = fixture();
    f.respond(session(ACCOUNT_A, { bound_machine_code: binding }));
    const service = f.create();
    assert.equal(await service.activate({}, CODE_A), f.mod.SupporterOutcome.CONFIG);
    assert.equal(service.active(), false);
    assert.equal(f.saved(), null);
  }
  const f = fixture([record(CODE_A, ACCOUNT_A), record(CODE_B, ACCOUNT_B)]);
  f.respond(session(ACCOUNT_B));
  const service = f.create();
  assert.equal(await service.refresh({}, true), f.mod.SupporterOutcome.INVALID);
  assert.equal(service.active(), false);
  f.signIn({ userId: ACCOUNT_B, username: 'other' });
  await service.sync({});
  assert.equal(service.active(), true);
});

test('online, IP, region, configuration, gateway 404 and ambiguous client errors preserve valid access', async () => {
  for (const [status, message] of [[400, '超过最大在线数'], [400, 'IP 不匹配'], [400, '地区限制'],
    [400, '同 IP 登录账号数超限'], [400, '当前登录模式不支持卡密'], [404, 'route not found'],
    [403, '设备访问受限'], [400, '参数错误'], [401, '请重新登录'], [400, '卡密登录过于频繁'],
    [400, '卡密签名无效'], [400, 'card signature invalid']]) {
    const f = fixture([record(CODE_A, ACCOUNT_A)]);
    f.respond({ responseCode: status, result: JSON.stringify({ code: status, message }) });
    const service = f.create();
    assert.equal(await service.refresh({}, true), f.mod.SupporterOutcome.NETWORK, message);
    assert.equal(service.active(), true, message);
  }
});

test('malformed envelopes and corrupt assets do not revoke or overwrite another account', async () => {
  for (const body of ['null', '[]', '{}', '{"code":0,"data":null}', 'broken']) {
    const f = fixture([record(CODE_A, ACCOUNT_A)]);
    f.respond({ responseCode: 200, result: body });
    const service = f.create();
    assert.equal(await service.refresh({}, true), f.mod.SupporterOutcome.NETWORK);
    assert.equal(service.active(), true);
  }
  const f = fixture([record(CODE_B, ACCOUNT_B)]);
  f.assets.set('harmonyx_supporter_account_v2_' + ACCOUNT_A, new TextEncoder().encode('broken'));
  const service = f.create();
  assert.equal(await service.activate({}, CODE_A), f.mod.SupporterOutcome.STORAGE);
  assert.equal(f.calls.length, 0);
  f.signIn({ userId: ACCOUNT_B, username: 'other' });
  await service.sync({});
  assert.equal(service.active(), true);
});

test('a fresh device or app bundle restores the same code only under the same stable X account', async () => {
  for (const username of ['renamed', 'another_handle']) {
    const f = fixture([], { userId: ACCOUNT_A, username });
    const service = f.create();
    assert.equal(await service.activate({}, CODE_A), f.mod.SupporterOutcome.SUCCESS);
    assert.equal(service.active(), true);
    assert.equal(JSON.parse(f.calls[0].options.extraData).machine_code, ACCOUNT_A);
  }
  for (const userId of ['', 'handle', 'u:' + ACCOUNT_A, '0', '-1']) {
    const f = fixture([], { userId, username: 'signed_in_but_no_stable_id' });
    assert.equal(await f.create().activate({}, CODE_A), f.mod.SupporterOutcome.NO_ACCOUNT);
    assert.equal(f.calls.length, 0);
  }
  assert.equal(policy.active([record(CODE_A, ACCOUNT_A)], ACCOUNT_A, now - 600001), false, 'clock rollback');
  assert.equal(policy.valid(null), false);
});

test('transient failures retry on the next foreground poll instead of consuming the five-minute success throttle', async () => {
  const f = fixture([record(CODE_A, ACCOUNT_A)]);
  const service = f.create();
  f.respond(new Error('offline'));
  assert.equal(await service.refresh({}), f.mod.SupporterOutcome.NETWORK);
  f.respond(session(ACCOUNT_A));
  assert.equal(await service.refresh({}), f.mod.SupporterOutcome.SUCCESS);
  assert.equal(f.calls.length, 2);
});

test('an explicit card revocation in a successful HTTP envelope also retires the original account', async () => {
  const f = fixture([record(CODE_A, ACCOUNT_A)]);
  const service = f.create();
  f.respond({ responseCode: 200, result: '{"code":1001,"message":"卡密已过期"}' });
  assert.equal(await service.refresh({}, true), f.mod.SupporterOutcome.INVALID);
  assert.equal(service.active(), false);
});
