const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
function load(file, deps) {
  const mod = {exports: {}};
  new Function('require', 'exports', ts.transpileModule(fs.readFileSync(file, 'utf8'), {
    compilerOptions: {target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS}
  }).outputText)(id => deps[id], mod.exports);
  return mod.exports;
}
test('local image decoding bypasses proxy and shared cache, balancing native source and FD', async () => {
  let reads = 0, proxyReads = 0; const trace = []; let failed = false;
  const maps = [];
  const resolver = load('entry/src/main/ets/services/ProxyImageResolver.ets', {
    '@kit.CoreFileKit': {fileIo: {OpenMode: {READ_ONLY: 0}, openSync: () => ({fd: ++reads}), closeSync: fd => trace.push(['close', fd])}},
    '@kit.ImageKit': {image: {createImageSource: fd => ({
      async createPixelMap() {if (failed) throw Error('decode'); const map = {release: async () => trace.push(['map', fd])}; maps.push(map); return map;},
      release: async () => trace.push(['source', fd])
    })}},
    './ProxyStore': {proxyStore: {snapshot: () => {proxyReads++; return {enabled: false};}}},
    '@ohos.hilog': {default: {}}
  }).proxyImageResolver;
  const first = await resolver.load('file://private/photo.jpg');
  const second = await resolver.load('file://private/photo.jpg');
  assert.notEqual(first, second); assert.equal(reads, 2); assert.equal(proxyReads, 0);
  assert.deepEqual(trace, [['source', 1], ['close', 1], ['source', 2], ['close', 2]]);
  resolver.release(first); resolver.release(second); await Promise.resolve();
  assert.deepEqual(trace.slice(-2), [['map', 1], ['map', 2]]);
  failed = true; assert.equal(await resolver.load('file://private/bad.jpg'), null);
  assert.deepEqual(trace.slice(-2), [['source', 3], ['close', 3]]);
});
function saveHarness(cancel = false) {
  const trace = []; let fd = 0; let enqueued = 0;
  const service = load('entry/src/main/ets/services/MediaDownloadService.ets', {
    '@kit.CoreFileKit': {fileIo: {OpenMode: {READ_ONLY: 0, WRITE_ONLY: 1},
      open: async uri => {trace.push(['open', uri]); return {fd: ++fd};},
      copyFile: async (from, to) => trace.push(['copy', from, to]), closeSync: fd => trace.push(['close', fd])}},
    '@kit.MediaLibraryKit': {photoAccessHelper: {PhotoType: {IMAGE: 1, VIDEO: 2}, PhotoSubtype: {DEFAULT: 0},
      getPhotoAccessHelper: () => ({showAssetsCreationDialog: async (sources, configs) => {
        trace.push(['dialog', sources, configs]); return cancel ? [] : sources.map((_, i) => 'file://gallery/' + i);
      }})}},
    './DownloadManager': {downloadManager: {enqueue: () => {enqueued++; throw Error('must not enqueue local file');}}},
    './DownloadLocationStore': {downloadLocationStore: {useDownloads: () => false}},
    '@ohos.hilog': {default: {error: () => {}}}
  });
  return {service: service.mediaDownloadService, trace, enqueued: () => enqueued};
}
test('viewer saves local images and video via the existing Gallery dialog without HTTP tasks', async () => {
  const h = saveHarness();
  const result = await new Promise(resolve => h.service.download({}, 'file://private/movie.mp4', 'movie', true, resolve));
  assert.equal(result, 0); assert.equal(h.enqueued(), 0);
  assert.equal(h.trace[0][2][0].photoType, 2); assert.equal(h.trace[0][2][0].fileNameExtension, 'mp4');
  assert.deepEqual(h.trace.slice(-2), [['close', 1], ['close', 2]]);
  h.trace.length = 0;
  assert.equal(await new Promise(resolve => h.service.downloadImages({}, ['file://private/a.jpg', 'file://private/b.gif'], 'album', resolve)), 0);
  assert.deepEqual(h.trace[0][1], ['file://private/a.jpg', 'file://private/b.gif']);
  assert.deepEqual(h.trace[0][2].map(item => item.fileNameExtension), ['jpg', 'gif']);
  assert.equal(h.trace.filter(item => item[0] === 'copy').length, 2); assert.equal(h.enqueued(), 0);
});
test('canceling the local Gallery dialog copies no files', async () => {
  const h = saveHarness(true);
  assert.equal(await new Promise(resolve => h.service.downloadImages({}, ['file://private/a.jpg'], 'album', resolve)), 2);
  assert.equal(h.trace.length, 1); assert.equal(h.enqueued(), 0);
});
test('conversation and media viewer privacy changes execute in visibility order', async () => {
  const trace = []; let finish;
  const first = new Promise(resolve => {finish = resolve;});
  const privacy = load('entry/src/main/ets/utils/ChatWindowPrivacy.ets', {
    '@kit.ArkUI': {window: {getLastWindow: async () => ({setWindowPrivacyMode: async value => {
      trace.push(value); if (trace.length === 1) await first;
    }})}}
  });
  privacy.setChatWindowPrivacy({}, false); privacy.setChatWindowPrivacy({}, true);
  await new Promise(resolve => setImmediate(resolve)); assert.deepEqual(trace, [false]);
  finish(); await new Promise(resolve => setImmediate(resolve)); assert.deepEqual(trace, [false, true]);
});
