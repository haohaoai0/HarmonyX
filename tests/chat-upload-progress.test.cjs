// Exercise the real binary transport, with local HTTP events and no X requests.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const transpile = file => ts.transpileModule(fs.readFileSync(file, 'utf8'), {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS, esModuleInterop: true }
}).outputText;
const clientSource = transpile('entry/src/main/ets/services/XPrivateClient.ets');
const conversation = { exports: {} };
new Function('module', 'exports', transpile('entry/src/main/ets/services/XChatConversationId.ets'))(conversation, conversation.exports);
const receipt = { exports: {} };
new Function('module', 'exports', transpile('entry/src/main/ets/services/XPostResponse.ets'))(receipt, receipt.exports);

function harness(responses = [204], proxyRetry = false) {
  const requests = [];
  const http = { RequestMethod: { POST: 'POST' }, createHttp() {
    const request = { listener: undefined, savedListener: undefined, offCount: 0, destroyed: false,
      on(type, callback) { assert.equal(type, 'dataSendProgress'); this.listener = this.savedListener = callback; },
      off(type) { assert.equal(type, 'dataSendProgress'); this.offCount++; this.listener = undefined; },
      emit(value) { this.listener?.(value); },
      request(url, options) {
        this.url = url; this.options = options;
        return new Promise((resolve, reject) => { this.resolve = resolve; this.reject = reject; });
      },
      destroy() { this.destroyed = true; }
    };
    requests.push(request); return request;
  }};
  class Session { cacheIdentity() { return ''; } isUsable() { return false; } }
  const dependencies = {
    '@ohos.net.http': http,
    '@ohos.hilog': { info() {}, warn() {}, error() {} },
    './XPrivateStore': { XSession: Session },
    './XTransactionId': { xTransactionId: { resolve: async () => '' } },
    './XUserAgent': { xUserAgent: { value: () => 'local fixture' } },
    './ProxyStore': { proxyStore: { apply: async () => {}, noteNetworkFailure: () => proxyRetry } },
    './XChatConversationId': conversation.exports,
    './XPostResponse': receipt.exports
  };
  const mod = { exports: {} };
  new Function('require', 'module', 'exports', clientSource)(id => dependencies[id] || {}, mod, mod.exports);
  const client = new mod.exports.XPrivateClient();
  client.setSession({ isUsable: () => true, cacheIdentity: () => 'local-account', rawCookie: 'local-cookie', ct0: 'local-csrf' });
  const start = onProgress => client.uploadChatMediaPart('100-200', 'hash', '123', 0, new ArrayBuffer(1024), '', onProgress);
  const settle = () => new Promise(resolve => setImmediate(resolve));
  const respond = async index => { requests[index].resolve({ responseCode: responses[index], result: '' }); await settle(); };
  return { requests, start, settle, respond };
}

test('HTTP byte events reach the caller while the upload response is still pending', async () => {
  const h = harness(); const values = [];
  const upload = h.start((sent, total) => values.push([sent, total]));
  await h.settle(); const request = h.requests[0];
  request.emit({ sendSize: 128, totalSize: 1024 }); request.emit({ sendSize: 512, totalSize: 1024 });
  assert.deepEqual(values, [[128, 1024], [512, 1024]]); assert.equal(request.destroyed, false);
  request.emit(undefined); request.emit({ sendSize: NaN, totalSize: 1024 }); request.emit({ sendSize: 1, totalSize: 0 });
  assert.equal(values.length, 2);
  await h.respond(0); assert.equal((await upload).ok, true);
  assert.equal(request.offCount, 1); assert.equal(request.destroyed, true);
  request.savedListener({ sendSize: 1024, totalSize: 1024 }); assert.equal(values.length, 2);
});

test('cookie authentication fallback keeps byte events and releases both request subscriptions', async () => {
  const h = harness([401, 204]); const values = [];
  const upload = h.start((sent, total) => values.push([sent, total]));
  await h.settle(); h.requests[0].emit({ sendSize: 128, totalSize: 1024 }); await h.respond(0);
  assert.equal(h.requests.length, 2);
  h.requests[0].savedListener({ sendSize: 1024, totalSize: 1024 });
  h.requests[1].emit({ sendSize: 256, totalSize: 1024 }); await h.respond(1);
  assert.equal((await upload).ok, true); assert.deepEqual(values, [[128, 1024], [256, 1024]]);
  assert.equal(h.requests[0].options.extraData, h.requests[1].options.extraData);
  assert.ok(h.requests.every(request => request.offCount === 1 && request.destroyed));
});

test('proxy retry retains the progress callback and unsubscribes even when the retry fails', async () => {
  const h = harness([0, 0], true); const values = [];
  const upload = h.start((sent, total) => values.push([sent, total]));
  await h.settle(); h.requests[0].emit({ sendSize: 128, totalSize: 1024 });
  h.requests[0].reject(new Error('proxy disconnected')); await h.settle();
  assert.equal(h.requests.length, 2); h.requests[1].emit({ sendSize: 256, totalSize: 1024 });
  h.requests[1].reject(new Error('retry disconnected'));
  assert.equal((await upload).ok, false); assert.deepEqual(values, [[128, 1024], [256, 1024]]);
  assert.ok(h.requests.every(request => request.offCount === 1 && request.destroyed));
});

test('uploads without a progress consumer keep their existing request behavior', async () => {
  const h = harness(); const upload = h.start(); await h.settle();
  assert.equal(h.requests[0].listener, undefined); await h.respond(0);
  assert.equal((await upload).ok, true); assert.equal(h.requests[0].offCount, 0); assert.equal(h.requests[0].destroyed, true);
});
