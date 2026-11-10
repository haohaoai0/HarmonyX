const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function fixture() {
  const calls = [], cancellations = [], events = new Map();
  let nativeFinish, destroyed = 0;
  const system = {
    on(type, fn) { events.set(type, fn); }, off(type) { events.delete(type); },
    destroy() { destroyed++; },
    async request(url, options) { calls.push({ system: true, url, options }); return { responseCode: 204 }; },
    async requestInStream(url, options) { calls.push({ system: true, url, options }); return 206; }
  };
  const http = { createHttp: () => system, RequestMethod: { GET: 'GET', POST: 'POST' },
    HttpDataType: { STRING: 0, OBJECT: 1, ARRAY_BUFFER: 2 } };
  const exports = {};
  const output = ts.transpileModule(fs.readFileSync('entry/src/main/ets/services/DohHttpRequest.ets', 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText;
  const dependencies = {
    '@ohos.net.http': { default: http },
    '@ohos.util': { default: { TextEncoder: class { encodeInto(text) { return new TextEncoder().encode(text); } },
      TextDecoder: { create: () => ({ decodeToString: bytes => new TextDecoder().decode(bytes) }) } } },
    '@ohos.hilog': { default: { debug() {}, error() {} } },
    'libharmonyx_doh.so': {
      request(id, metadata, body, onEvent) {
        calls.push({ id, metadata: JSON.parse(metadata), body, onEvent });
        return new Promise(resolve => { nativeFinish = resolve; });
      }, cancel(id) { cancellations.push(id); }
    }
  };
  new Function('require', 'exports', output)(id => {
    assert.ok(dependencies[id], id); return dependencies[id];
  }, exports);
  return { ...exports, calls, cancellations, http, request: exports.createDohHttpRequest(),
    destroyed: () => destroyed,
    finish(body = '', meta = {}) { nativeFinish({ metadata: JSON.stringify({ ok: true, responseCode: 200,
      header: { 'content-type': 'text/plain' }, ech: true, ...meta }),
      body: typeof body === 'string' ? new TextEncoder().encode(body).buffer : body }); }
  };
}
const endpoint = 'https://resolver.example/dns-query';

test('DoH dispatch preserves system HTTP for disabled DoH, app proxies and explicit certificate configuration', async () => {
  const f = fixture();
  for (const options of [{}, { dnsOverHttps: endpoint, usingProxy: { host: 'proxy', port: 8080 } },
    { dnsOverHttps: endpoint, usingSocks5Proxy: {} }, { dnsOverHttps: endpoint, caPath: '/custom/ca' },
    { dnsOverHttps: endpoint, clientCert: {} }, { dnsOverHttps: endpoint, multiFormDataList: [] }]) {
    assert.equal((await f.request.request('https://x.com/', options)).responseCode, 204);
  }
  assert.ok(f.calls.every(call => call.system));
  assert.equal(f.usesNativeDoh('https://x.com/', { dnsOverHttps: endpoint, usingProxy: false }), true);
});

test('native HTTP preserves request method, headers, UTF-8 body and binary response', async () => {
  const f = fixture();
  const pending = f.request.request('https://x.com/i/api/example', { method: 'POST', dnsOverHttps: endpoint,
    usingProxy: false, header: { Cookie: 'session', 'x-csrf-token': 'csrf' }, extraData: '正文',
    expectDataType: f.http.HttpDataType.ARRAY_BUFFER, maxLimit: 1024 });
  const call = f.calls[0];
  assert.equal(call.metadata.endpoint, endpoint);
  assert.equal(call.metadata.method, 'POST');
  assert.equal(call.metadata.headers.Cookie, 'session');
  assert.equal(new TextDecoder().decode(call.body), '正文');
  const bytes = new Uint8Array([0, 255, 128]).buffer;
  f.finish(bytes, { responseCode: 206 });
  const response = await pending;
  assert.equal(response.responseCode, 206);
  assert.equal(response.resultType, f.http.HttpDataType.ARRAY_BUFFER);
  assert.deepEqual(new Uint8Array(response.result), new Uint8Array(bytes));
  f.request.destroy(); assert.equal(f.destroyed(), 1);
});

test('streaming headers, chunks and progress reach consumers before dataEnd and status settlement', async () => {
  const f = fixture(), order = [];
  f.request.on('headersReceive', headers => order.push(['headers', headers['content-range']]));
  f.request.on('dataReceive', bytes => order.push(['bytes', bytes.byteLength]));
  f.request.on('dataReceiveProgress', progress => order.push(['progress', progress.receiveSize]));
  f.request.on('dataEnd', () => order.push(['end']));
  const pending = f.request.requestInStream('https://video.twimg.com/a.mp4', { dnsOverHttps: endpoint,
    usingProxy: false, header: { Range: 'bytes=0-2' } });
  const call = f.calls[0]; assert.equal(call.metadata.stream, true);
  call.onEvent(1, JSON.stringify({ 'content-range': 'bytes 0-2/3', 'status-line': 'HTTP/2 206' }), new ArrayBuffer(0));
  call.onEvent(2, 'null', new Uint8Array([1, 2, 3]).buffer);
  call.onEvent(4, '{"receiveSize":3,"totalSize":3}', new ArrayBuffer(0));
  f.finish('', { responseCode: 206 });
  assert.equal(await pending, 206);
  assert.deepEqual(order, [['headers', 'bytes 0-2/3'], ['bytes', 3], ['progress', 3], ['end']]);
});

test('destroy cancels the native task, suppresses late chunks and rejects its pending result', async () => {
  const f = fixture(); let chunks = 0;
  f.request.on('dataReceive', () => { chunks++; });
  const pending = f.request.requestInStream('https://video.twimg.com/a.mp4', { dnsOverHttps: endpoint, usingProxy: false });
  const call = f.calls[0]; f.request.destroy(); f.request.destroy();
  assert.deepEqual(f.cancellations, [call.id]);
  call.onEvent(2, 'null', new Uint8Array([1]).buffer);
  f.finish();
  await assert.rejects(pending, /cancelled/);
  assert.equal(chunks, 0); assert.equal(f.destroyed(), 1);
  await assert.rejects(f.request.request('https://x.com/', {}), /destroyed/);
});

test('TLS/DoH failures remain failures and never dispatch a system-DNS fallback', async () => {
  const f = fixture();
  const pending = f.request.request('https://x.com/', { dnsOverHttps: endpoint, usingProxy: false });
  f.finish('', { ok: false, error: 'HTTPS/ECH handshake or connection failed', code: 2300999 });
  await assert.rejects(pending, /handshake/);
  assert.equal(f.calls.length, 1); assert.equal(f.calls[0].system, undefined);
});
