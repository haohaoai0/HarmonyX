const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function moduleFrom(name, dependencies) {
  const source = fs.readFileSync('entry/src/main/ets/services/' + name + '.ets', 'utf8');
  const output = ts.transpileModule(source, {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText;
  const result = {};
  new Function('exports', 'require', 'AppStorage', output)(result, id => {
    assert.ok(Object.hasOwn(dependencies, id), 'unexpected dependency ' + id);
    return dependencies[id];
  }, { get: () => undefined, setOrCreate() {} });
  return result;
}

const dns = moduleFrom('DnsOverHttps', { '@ohos.url': { default: { URL } } });

function answer(flags = 0x8180) {
  const bytes = [...dns.dohProbeQuery()];
  bytes[2] = flags >> 8; bytes[3] = flags & 255; bytes[7] = 1;
  return Uint8Array.from([...bytes, 0xc0, 0x0c, 0, 1, 0, 1, 0, 0, 0, 30, 0, 4, 1, 2, 3, 4]).buffer;
}

function fixture(saved = new Map()) {
  let failSave = false, destroyed = 0, response = { responseCode: 200, result: answer() };
  const requests = [], webCalls = [];
  const prefs = {
    getSync: (key, fallback) => saved.has(key) ? saved.get(key) : fallback,
    putSync: (key, value) => { if (failSave) throw Error('storage unavailable'); saved.set(key, value); },
    flushSync() {}
  };
  const platform = {
    RequestMethod: { POST: 'POST' }, HttpDataType: { ARRAY_BUFFER: 2 },
    createHttp: () => ({
      async request(url, options) { requests.push({ url, options }); return response; },
      destroy() { destroyed++; }
    })
  };
  const dependencies = {
    '@kit.ArkData': { preferences: { getPreferencesSync: () => prefs } },
    '@ohos.net.http': { default: platform },
    '@ohos.web.webview': { default: {
      SecureDnsMode: { SECURE_ONLY: 2, OFF: 0 },
      WebviewController: { setHttpDns: (...args) => webCalls.push(args) }
    } },
    '@ohos.hilog': { default: { warn() {}, info() {} } },
    './DnsOverHttps': dns
  };
  const { DnsSettingsStore } = moduleFrom('DnsSettingsStore', dependencies);
  const store = new DnsSettingsStore(); store.load({});
  return { store, saved, webCalls, requests, platform,
    failSave() { failSave = true; },
    respond(value) { response = value; },
    destroyed: () => destroyed };
}

test('only complete HTTPS resolver endpoints are accepted', () => {
  assert.equal(dns.normalizeDohEndpoint('  https://DNS.GOOGLE/dns-query  '), dns.DOH_GOOGLE);
  assert.equal(dns.normalizeDohEndpoint('https://resolver.example/private?token=abc'),
    'https://resolver.example/private?token=abc');
  assert.equal(dns.normalizeDohEndpoint('https://[2606:4700:4700::1111]/dns-query'),
    'https://[2606:4700:4700::1111]/dns-query');
  for (const input of ['', 'http://dns.google/dns-query', 'dns.google',
    'https://name:secret@dns.google/dns-query', 'https://@dns.google/dns-query',
    'https://dns.google/dns-query#fragment', 'https://dns.google/dns-query{?dns}',
    'https://dns.google:0/dns-query', 'https://dns.google:65536/dns-query',
    'https://dns.google/dns query', 'https://dns.google\\bad/dns-query']) {
    assert.equal(dns.normalizeDohEndpoint(input), '', input);
  }
});

test('probe validates the DNS response, question and complete A answers', () => {
  assert.equal(dns.dohProbeAnswerCount(answer()), 1);
  for (const flags of [0x8183, 0x8182, 0x8380, 0x0180, 0x8980]) {
    assert.equal(dns.dohProbeAnswerCount(answer(flags)), 0, 'reject DNS failure/truncation/query/opcode');
  }
  const malformed = new Uint8Array(answer()); malformed[13] = 121;
  assert.equal(dns.dohProbeAnswerCount(malformed.buffer), 0, 'wrong question');
  malformed[13] = 120; malformed[0] = 1;
  assert.equal(dns.dohProbeAnswerCount(malformed.buffer), 0, 'wrong transaction');
  for (let size = 0; size < answer().byteLength; size++) {
    assert.equal(dns.dohProbeAnswerCount(answer().slice(0, size)), 0, 'truncated at ' + size);
  }
  const badPointer = new Uint8Array(answer()); badPointer[23] = 255;
  assert.equal(dns.dohProbeAnswerCount(badPointer.buffer), 0, 'invalid compressed name');
  const empty = new Uint8Array(answer()); empty[7] = 0;
  assert.equal(dns.dohProbeAnswerCount(empty.buffer), 0, 'no DNS answer');
});

test('DoH defaults off, persists across restart and clears native and Web settings when disabled', () => {
  const f = fixture(); const options = {};
  f.store.apply(options); assert.equal(options.dnsOverHttps, undefined);
  assert.deepEqual(f.webCalls.at(-1), [0, '']);
  assert.equal(f.store.save(true, dns.DOH_GOOGLE), true);
  f.store.apply(options); assert.equal(options.dnsOverHttps, dns.DOH_GOOGLE);
  assert.deepEqual(f.webCalls.at(-1), [2, dns.DOH_GOOGLE]);
  const restored = fixture(f.saved); restored.store.apply(options);
  assert.equal(options.dnsOverHttps, dns.DOH_GOOGLE);
  assert.equal(restored.store.save(false, dns.DOH_GOOGLE), true);
  restored.store.apply(options); assert.equal(options.dnsOverHttps, undefined);
  assert.deepEqual(restored.webCalls.at(-1), [0, '']);
});

test('invalid config and storage failure preserve the last active configuration', () => {
  const f = fixture(); f.store.save(true, dns.DOH_GOOGLE);
  assert.equal(f.store.save(true, 'http://insecure.test/dns-query'), false);
  f.failSave(); assert.equal(f.store.save(false, dns.DOH_ALIDNS), false);
  assert.deepEqual(Object.assign({}, f.store.snapshot()), { enabled: true, endpoint: dns.DOH_GOOGLE });
  const broken = fixture(new Map([['enabled', true], ['endpoint', 'http://insecure.test']]));
  assert.equal(broken.store.snapshot().enabled, false);
});

test('resolver test sends a direct wire query and rejects HTTP 200 with failed DNS or non-DNS content', async () => {
  const f = fixture();
  assert.ok(await f.store.testEndpoint(dns.DOH_ALIDNS) >= 0);
  const { options } = f.requests[0];
  assert.equal(options.usingProxy, false); assert.equal(options.usingCache, false);
  assert.equal(options.dnsOverHttps, undefined);
  assert.deepEqual(options.header, { 'Content-Type': 'application/dns-message', Accept: 'application/dns-message' });
  assert.deepEqual(new Uint8Array(options.extraData), dns.dohProbeQuery());
  for (const response of [
    { responseCode: 403, result: answer() }, { responseCode: 200, result: answer(0x8183) },
    { responseCode: 200, result: '<html>login</html>' }, { responseCode: 200, result: new ArrayBuffer(0) }
  ]) {
    f.respond(response); assert.equal(await f.store.testEndpoint(dns.DOH_ALIDNS), -1);
  }
  assert.equal(f.destroyed(), 5);
  assert.equal(f.store.snapshot().enabled, false, 'testing does not enable or save');
  assert.equal(f.saved.size, 0);
  f.platform.createHttp = () => { throw Error('request service unavailable'); };
  assert.equal(await f.store.testEndpoint(dns.DOH_ALIDNS), -1);
});

test('shared request integration applies DoH through VPN bypass, proxy and forced video-CDN routes', async () => {
  const f = fixture(); f.store.save(true, dns.DOH_GOOGLE);
  let vpn = false;
  const { ProxyStore, ProxyEntry } = moduleFrom('ProxyStore', {
    '@kit.ArkData': { preferences: { getPreferencesSync: () => ({ getSync: () => '', putSync() {}, flushSync() {} }) } },
    '@kit.BasicServicesKit': { deviceInfo: { apiAvailable: () => true } },
    '@kit.NetworkKit': { connection: {
      getAllNets: async () => vpn ? [{}] : [], getNetCapabilities: async () => ({ bearerTypes: [9] }),
      NetBearType: { BEARER_VPN: 9 }, Socks5DnsStrategy: { PROXY_MODE: 1 }, setAppHttpProxy() {}
    } },
    '@ohos.net.http': { default: f.platform },
    '@ohos.hilog': { default: { warn() {}, info() {} } },
    './DnsSettingsStore': { dnsSettingsStore: f.store }
  });
  const proxy = new ProxyStore(); proxy.load({});
  assert.equal(proxy.requiresHttpTransport(), true, 'DoH alone opts media into native HTTP');
  let options = {}; await proxy.apply(options);
  assert.equal(options.dnsOverHttps, dns.DOH_GOOGLE); assert.equal(options.usingProxy, false);
  proxy.upsert(new ProxyEntry('one', 'proxy', 'http', '127.0.0.1', 8080, '', '', ''));
  proxy.setEnabled(true);
  options = {}; await proxy.apply(options);
  assert.equal(options.dnsOverHttps, dns.DOH_GOOGLE); assert.equal(options.usingProxy.host, '127.0.0.1');
  vpn = true; options = {}; await proxy.apply(options);
  assert.equal(options.dnsOverHttps, dns.DOH_GOOGLE); assert.equal(options.usingProxy, false);
  proxy.setVideoCdnProxyEnabled(true); options = {};
  await proxy.applyForMediaRequest(options, 'https://video.twimg.com/video.mp4');
  assert.equal(options.dnsOverHttps, dns.DOH_GOOGLE); assert.equal(options.usingProxy.host, '127.0.0.1');
});

test('DoH without an app proxy downloads and decodes media through the configured HTTP path', async () => {
  const f = fixture(); f.store.save(true, dns.DOH_GOOGLE);
  f.respond({ responseCode: 200, resultType: 2, result: new Uint8Array([1, 2, 3]).buffer });
  const pixelMap = { getPixelBytesNumber: () => 12, release: async () => {} };
  const resolver = moduleFrom('ProxyImageResolver', {
    '@kit.CoreFileKit': { fileIo: {} },
    '@kit.ImageKit': { image: { createImageSource: () => ({ createPixelMap: async () => pixelMap, release: async () => {} }) } },
    '@ohos.net.http': { default: f.platform },
    '@ohos.hilog': { default: { info() {}, debug() {}, warn() {} } },
    './ProxyStore': { proxyStore: { requiresHttpTransport: () => f.store.snapshot().enabled,
      apply: async options => f.store.apply(options), noteNetworkFailure() {} } }
  }).proxyImageResolver;
  assert.equal(await resolver.load('https://pbs.twimg.com/test.jpg'), pixelMap);
  assert.equal(f.requests[0].options.dnsOverHttps, dns.DOH_GOOGLE);
  assert.equal(f.destroyed(), 1);
  resolver.release(pixelMap);
});
