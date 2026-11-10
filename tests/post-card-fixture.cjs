const fs = require('node:fs');
const path = require('node:path');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function load(relative, dependencies = {}, storage = new Map()) {
  require('./doh-http-fixture.cjs').withDohHttpMock(dependencies);
  const filename = path.resolve(__dirname, '../entry/src/main/ets', relative + '.ets');
  const output = ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS, esModuleInterop: true }
  }).outputText;
  const module = { exports: {} };
  new Function('require', 'module', 'exports', 'AppStorage', output)(id => {
    if (Object.hasOwn(dependencies, id)) return dependencies[id];
    if (id === '@ohos.util') return { TextEncoder: class { encodeInto(text) { return new TextEncoder().encode(text); } },
      TextDecoder: { create: () => ({ decodeToString: bytes => new TextDecoder().decode(bytes) }) } };
    if (id === '@ohos.hilog') return { info() {}, warn() {}, error() {}, debug() {} };
    if (id === '../utils/PostGif') return require('./post-gif-fixture.cjs');
    if (id.startsWith('../utils/')) return load('utils/' + id.slice('../utils/'.length), dependencies, storage);
    if (id.startsWith('../models/')) return load('models/' + id.slice('../models/'.length), dependencies, storage);
    if (id.startsWith('./')) return load('services/' + id.slice(2), dependencies, storage);
    throw new Error('Unexpected import: ' + id + ' from ' + relative);
  }, module, module.exports, {
    get: key => storage.get(key), setOrCreate: (key, value) => storage.set(key, value)
  });
  return module.exports;
}

module.exports = { load, ...load('services/XPostCardParser'), ...load('services/XPollRequest') };
