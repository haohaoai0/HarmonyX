const { withDohHttpMock } = require('./doh-http-fixture.cjs');
const fs = require('node:fs');
const path = require('node:path');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function loadGifPreview({ loadPreview, downloadGif = async () => false, proxyEnabled = false }) {
  const filename = path.resolve(__dirname, '../entry/src/main/ets/components/GifPreviewImage.ets');
  let source = fs.readFileSync(filename, 'utf8');
  source = source.slice(0, source.indexOf('  build(): void {')) + '}';
  source = source.replace(/export struct GifPreviewImage/, 'export class GifPreviewImage')
    .replace(/@(Component|StorageProp|Prop|State|Watch)(\([^)]*\))?\s*/g, '');
  const output = ts.transpileModule(source, {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText;
  const released = [];
  const removed = [];
  const dependencies = {
    '@ohos.hilog': { default: { info() {}, warn() {} } },
    '@kit.CoreFileKit': { fileIo: { unlinkSync: path => removed.push(path) },
      fileUri: { getUriFromPath: path => 'file://' + path } },
    '../services/ProxyDownloadService': { proxyDownloadService: { downloadWithRetry: downloadGif } },
    '../services/ProxyImageResolver': { proxyImageResolver: {
      load: loadPreview, release: pixelMap => released.push(pixelMap)
    } },
    '../services/ProxyStore': { proxyStore: { snapshot: () => ({ enabled: proxyEnabled }), requiresHttpTransport: () => proxyEnabled } }
  };
  const module = { exports: {} };
  new Function('require', 'module', 'exports', 'getContext', 'ImageFit', output)(
    name => (() => { withDohHttpMock(dependencies); return dependencies[name] || {}; })(), module, module.exports, () => ({ cacheDir: '/app/cache' }), { Cover: 'cover' });
  return { component: new module.exports.GifPreviewImage(), released, removed };
}

module.exports = { loadGifPreview };
