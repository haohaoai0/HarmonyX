const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function load(name, dependencies = {}) {
  const output = ts.transpileModule(fs.readFileSync(`entry/src/main/ets/services/${name}.ets`, 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText;
  const result = {};
  new Function('exports', 'require', 'AppStorage', output)(result, id => {
    assert.ok(Object.hasOwn(dependencies, id), `Unexpected import ${id}`); return dependencies[id];
  }, { get() {}, setOrCreate() {} });
  return result;
}

function fixture(options = {}) {
  let netId = 1, dnsQueries = 0;
  const web = [], requests = [], saved = new Map();
  const connection = {
    getAllNets: async () => [], NetBearType: { BEARER_VPN: 9 },
    Socks5DnsStrategy: { PROXY_MODE: 1 }, setAppHttpProxy: config => web.push(config),
    getDefaultNet: async () => {
      if (options.failProbe) throw Error('Network changed');
      return { netId, getAddressesByName: async () => {
        dnsQueries++;
        if (options.failDns) throw Error('DNS unavailable');
        return options.addresses || [{ address: '192.0.2.10', family: 1 }, { address: '2001:db8::10', family: 2 }];
      } };
    },
    getConnectionProperties: async () => ({
      linkAddresses: (options.families || [1, 2]).map(family => ({ address: { family } }))
    })
  };
  const api = load('ProxyStore', {
    './DohHttpRequest': { createDohHttpRequest: () => ({ request: async (url, config) => {
      requests.push({ url, config }); return { responseCode: 200 };
    }, destroy() {} }) },
    '@kit.ArkData': { preferences: { getPreferencesSync: () => ({
      getSync: (key, fallback) => saved.get(key) ?? fallback,
      putSync: (key, value) => saved.set(key, value), flushSync() {}
    }) } },
    '@kit.BasicServicesKit': { deviceInfo: { apiAvailable: () => true } },
    '@kit.NetworkKit': { connection }, '@ohos.net.http': { default: { RequestMethod: { GET: 0 } } },
    '@ohos.hilog': { default: { info() {}, warn() {} } },
    './DnsSettingsStore': { dnsSettingsStore: { apply() {}, snapshot: () => ({ enabled: false }) } }
  });
  const store = new api.ProxyStore(); store.load({});
  const entry = new api.ProxyEntry('server', 'server', options.type || 'http',
    options.host || 'proxy.example', 8080, 'user', 'password', 'localhost');
  store.settings = new api.ProxySettings(true, entry.id, true, [entry], true, options.prefer || false);
  return { store, entry, web, requests, api, saved,
    changeNetwork: () => { netId++; }, dnsQueries: () => dnsQueries };
}

test('proxy hostnames keep platform resolution without an application-selected address', async () => {
  for (const host of ['127.0.0.1', 'proxy.example', '[2001:db8::1]']) {
    const h = fixture({ host }), config = {};
    await h.store.apply(config);
    assert.equal(config.usingProxy.host, host);
    assert.equal(h.dnsQueries(), 0);
  }
});

test('IPv6 literals work across normal requests, media routing, probes and Web proxy rules', async () => {
  for (const type of ['http', 'socks5']) {
    const h = fixture({ type, host: '[2001:db8::1]' });
    const field = type === 'socks5' ? 'usingSocks5Proxy' : 'usingProxy';
    for (const method of ['apply', 'applyForMediaRequest']) {
      const config = {}; await h.store[method](config, 'https://video.twimg.com/video.mp4');
      assert.equal(config[field].host, '[2001:db8::1]');
      assert.equal(config[field].username, 'user'); assert.equal(config[field].password, 'password');
    }
    assert.ok(await h.store.testLatency(h.entry) >= 0);
    assert.equal(h.requests[0].config[field].host, '[2001:db8::1]');
    await h.store.applyToWebStack();
    assert.equal(h.web.at(-1).host, type === 'http' ? '[2001:db8::1]' : '');
    assert.equal(h.dnsQueries(), 0);
  }
});

test('IPv6-only link metadata never pins proxy domains to an unverified AAAA address', async () => {
  for (const options of [{ families: [2] }, { prefer: true }]) {
    const h = fixture(options), config = {}; await h.store.apply(config);
    assert.equal(config.usingProxy.host, 'proxy.example');
    assert.equal(h.dnsQueries(), 0);
    assert.equal(config.addressFamily, undefined, 'proxy selection must not force the destination family');
  }
});

test('dual stack defaults, missing AAAA and failed probes retain native automatic resolution', async () => {
  for (const options of [{}, { families: [] }, { prefer: true, addresses: [{ address: '192.0.2.10', family: 1 }] },
    { prefer: true, failDns: true }, { failProbe: true }]) {
    const h = fixture(options), config = {}; await h.store.apply(config);
    assert.equal(config.usingProxy.host, 'proxy.example');
  }
});

test('network changes leave proxy address selection to the platform without a pinned cache', async () => {
  const h = fixture({ prefer: true });
  await h.store.apply({}); await h.store.apply({}); assert.equal(h.dnsQueries(), 0);
  h.changeNetwork(); await h.store.apply({}); assert.equal(h.dnsQueries(), 0);
  h.store.settings.preferIpv6 = false;
  const config = {}; await h.store.apply(config); assert.equal(config.usingProxy.host, 'proxy.example');
});

test('old saved proxy entries survive encode/decode without a new IPv6 policy', () => {
  const h = fixture({ prefer: true, host: '[2001:db8::1]' });
  const decoded = h.store.decode(h.store.encode(h.store.snapshot()));
  assert.equal(decoded.preferIpv6, undefined); assert.equal(decoded.proxies[0].host, '[2001:db8::1]');
  const legacy = h.store.decode(JSON.stringify({ enabled: true, activeProxyId: 'server', proxies: [h.entry] }));
  assert.equal(legacy.preferIpv6, undefined); assert.equal(legacy.proxies[0].host, '[2001:db8::1]');
});
