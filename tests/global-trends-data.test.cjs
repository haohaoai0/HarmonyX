const { withDohHttpMock } = require('./doh-http-fixture.cjs');
const assert = require('node:assert/strict');
const test = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

const util = {
  TextDecoder: { create: () => ({ decodeToString: bytes => new TextDecoder().decode(bytes) }) },
  TextEncoder: class { encodeInto(value) { return new TextEncoder().encode(value); } },
  Base64Helper: class { encodeToStringSync(value) { return Buffer.from(value).toString('base64'); } }
};

function load(relative, dependencies = {}) {
  const filename = path.resolve(__dirname, '../entry/src/main/ets', relative + '.ets');
  const output = ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS, esModuleInterop: true }
  }).outputText;
  const module = { exports: {} };
  new Function('require', 'module', 'exports', output)(id => { withDohHttpMock(dependencies);
    if (Object.hasOwn(dependencies, id)) return dependencies[id];
    if (id === '@ohos.util') return util;
    if (id === '@kit.AbilityKit') return {};
    if (id === '@ohos.hilog') return { info() {}, warn() {}, error() {} };
    if (id.startsWith('../models/')) return load('models/' + id.slice('../models/'.length), dependencies);
    if (id.startsWith('../utils/')) return load('utils/' + id.slice('../utils/'.length), dependencies);
    if (id.startsWith('./')) return load('services/' + id.slice(2), dependencies);
    throw Error('Unexpected dependency ' + id);
  }, module, module.exports);
  return module.exports;
}

const { XGlobalTrendsParser } = load('services/XGlobalTrendsParser');
const { JetfuelDocument } = load('services/JetfuelDecoder');

test('only permits server paths under global-trending, including nested percent-encoded traversal rejection', () => {
  for (const value of ['global-trending', '/global-trending', 'global-trending?country=JP',
    '/global-trending/remotes/feed?cursor=abc%2Fdef']) {
    assert.equal(XGlobalTrendsParser.requestPath(value), value.replace(/^\//, ''));
  }
  for (const value of ['', 'https://x.com/i/jfapi/global-trending', '//attacker.test/global-trending',
    'global-trending-evil', 'connect/starter_packs', 'global-trending/../onboarding',
    'global-trending/%2e%2e/onboarding', 'global-trending/%252e%252e/onboarding',
    'global-trending#fragment', 'global-trending\\..\\other', 'global-trending\0']) {
    assert.equal(XGlobalTrendsParser.requestPath(value), '', value);
  }
});

function clientFixture() {
  let generation = 7;
  let usable = true;
  let requestHook = async () => ({ responseCode: 200, result: new ArrayBuffer(4) });
  let transactionHook = async () => '';
  let proxyHook = async () => {};
  const calls = [];
  let destroyed = 0;
  const source = fs.readFileSync(path.resolve(__dirname, '../entry/src/main/ets/services/XPrivateClient.ets'), 'utf8');
  const output = ts.transpileModule(source, { compilerOptions: {
    target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS, esModuleInterop: true
  } }).outputText;
  const module = { exports: {} };
  const imports = {
    '@ohos.net.http': { RequestMethod: { GET: 'GET' }, HttpDataType: { ARRAY_BUFFER: 1 }, createHttp: () => ({
      request: async (url, options) => { calls.push({ url, options }); return requestHook(); },
      destroy: () => destroyed++
    }) },
    '@ohos.util': util,
    '@ohos.hilog': { info() {}, warn() {} },
    './XPrivateStore': { XSession: class {} },
    './XGlobalTrendsParser': { XGlobalTrendsParser },
    './JetfuelDecoder': { JetfuelDecoder: { load: () => ({ decode: () => new JetfuelDocument() }) } },
    './XPostResponse': { XPostReceipt: class {} },
    './XTransactionId': { xTransactionId: { resolve: () => transactionHook() } },
    './ProxyStore': { proxyStore: { apply: () => proxyHook() } }
  };
  new Function('require', 'module', 'exports', 'AppStorage', output)(
    id => withDohHttpMock(imports)[id] || {}, module, module.exports, { get: () => 'dark' });
  const client = new module.exports.XPrivateClient();
  client.session = { isUsable: () => usable };
  client.context = {};
  client.headers = () => ({ 'fixture-header': 'present' });
  client.sessionGeneration = () => generation;
  return { client, calls, rotate: () => generation++, signOut: () => { usable = false; },
    request: hook => { requestHook = hook; }, transaction: hook => { transactionHook = hook; },
    proxy: hook => { proxyHook = hook; }, destroyed: () => destroyed };
}

test('trends client supplies JP-5 headers and retains server query paths', async () => {
  const f = clientFixture();
  const result = await f.client.globalTrends('/global-trending?country=JP');
  assert.equal(result.ok, true);
  assert.equal(f.calls[0].url, 'https://x.com/i/jfapi/global-trending?country=JP');
  assert.equal(f.calls[0].options.header['x-jf-v'], 'JP-5');
  assert.equal(f.calls[0].options.header['x-jf-client-theme'], 'dark');
  assert.equal(f.destroyed(), 1);
});

test('account switches during transaction or proxy preparation suppress the network request', async () => {
  for (const phase of ['transaction', 'proxy']) {
    const f = clientFixture();
    f[phase](async () => { f.rotate(); return ''; });
    assert.equal((await f.client.globalTrends()).errorText, 'stale_session');
    assert.equal(f.calls.length, 0);
    assert.equal(f.destroyed(), 1);
  }
});

test('account switch or sign-out during a response prevents old-account data from returning', async () => {
  for (const action of ['rotate', 'signOut']) {
    const f = clientFixture();
    f.request(async () => { f[action](); return { responseCode: 200, result: new ArrayBuffer(4) }; });
    const result = await f.client.globalTrends();
    assert.equal(result.errorText, 'stale_session');
    assert.equal(result.body, '');
  }
});

test('non-success responses and invalid paths stay failures and release their request', async () => {
  const f = clientFixture();
  f.request(async () => ({ responseCode: 429, result: new ArrayBuffer(4) }));
  const result = await f.client.globalTrends();
  assert.equal(result.ok, false);
  assert.equal(result.status, 429);
  assert.equal(f.destroyed(), 1);
  assert.equal((await f.client.globalTrends('connect/starter_packs')).errorText, 'invalid_trends_path');
  assert.equal(f.calls.length, 1);
});
