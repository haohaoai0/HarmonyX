// Offline check for the cookie-session transaction-id provider. The bundled
// pair file is real key material, so this validates the request-shaping path
// without touching X.
const assert = require('node:assert/strict');
const test = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function loadService(name, dependencies = {}) {
  require('./doh-http-fixture.cjs').withDohHttpMock(dependencies);
  const filename = path.resolve(__dirname, '../entry/src/main/ets/services', name + '.ets');
  const output = ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
    fileName: name + '.ts',
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS, esModuleInterop: true }
  }).outputText;
  const module = { exports: {} };
  const requireStub = (id) => {
    if (Object.hasOwn(dependencies, id)) return dependencies[id];
    throw new Error('Unexpected dependency: ' + id);
  };
  new Function('require', 'module', 'exports', output)(requireStub, module, module.exports);
  return module.exports;
}

class FakeBase64Helper {
  decodeSync(input) {
    return new Uint8Array(Buffer.from(input, 'base64'));
  }

  encodeToStringSync(input) {
    return Buffer.from(input).toString('base64');
  }
}

test('cookie-session transaction id is generated from the bundled pair', async () => {
  const logStub = { info() {}, warn() {}, error() {}, debug() {} };
  const { XTransactionIdService } = loadService('XTransactionId', {
    '@ohos.net.http': {
      RequestMethod: { GET: 'GET' },
      createHttp: () => {
        throw new Error('network disabled in fixture');
      }
    },
    '@ohos.hilog': logStub,
    '@ohos.util': {
      Base64Helper: FakeBase64Helper,
      Type: { BASIC: 0 },
      TextDecoder: {
        create: () => ({
          decodeToString: (bytes) => Buffer.from(bytes).toString('utf8')
        })
      }
    },
    './ProxyStore': { proxyStore: { apply: async () => {}, noteNetworkFailure: () => false } }
  });
  const raw = fs.readFileSync(
    path.resolve(__dirname, '../entry/src/main/resources/rawfile/x_tid_pair.json'));
  const context = {
    resourceManager: {
      getRawFileContentSync: () => new Uint8Array(raw)
    }
  };
  const service = new XTransactionIdService();
  service.load(context);
  assert.equal(service.isConfigured(), true);
  const value = await service.resolve('POST', '/graphql/fixture/CreateTweet');
  assert.equal(value.length > 40, true);
  assert.equal(value.includes('='), false);
  assert.equal(/^[A-Za-z0-9+/]+$/.test(value), true);
});
