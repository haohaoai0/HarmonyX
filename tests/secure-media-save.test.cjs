const fs = require('node:fs');
const test = require('node:test');
const assert = require('node:assert/strict');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
function load(name, deps = {}, storage = new Map()) {
  const api = {};
  const compiled = ts.transpileModule(fs.readFileSync('entry/src/main/ets/' + name + '.ets', 'utf8'), {
    compilerOptions: {target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS}
  }).outputText;
  new Function('require', 'exports', 'AppStorage', compiled)(id => deps[id] || {}, api,
    {get: key => storage.get(key), setOrCreate: (key, value) => storage.set(key, value)});
  return api;
}
function fixture() {
  const secure = load('services/SecureMediaSaveController');
  const calls = [];
  const service = load('services/MediaDownloadService', {
    './SecureMediaSaveController': secure,
    './DownloadLocationStore': {MediaSaveMethod: {SECURE_BUTTON: 1},
      downloadLocationStore: {method: () => 1, useDownloads: () => false}},
    '@kit.MediaLibraryKit': {photoAccessHelper: {PhotoType: {IMAGE: 1, VIDEO: 2},
      getPhotoAccessHelper: () => ({createAsset: async (type, ext) => {calls.push(['create', type, ext]); return 'file://gallery';}})}},
    '@kit.CoreFileKit': {fileIo: {OpenMode: {READ_ONLY: 0, WRITE_ONLY: 1},
      open: async uri => {calls.push(['open', uri]); return {fd: calls.length};},
      copyFile: async () => calls.push(['copy']), closeSync() {}}},
    '@ohos.hilog': {default: {warn() {}}}
  }).mediaDownloadService;
  return {service, controller: secure.secureMediaSaveController, secure, calls};
}

test('secure mode waits for an actual save-button click before creating a Gallery asset', async () => {
  const h = fixture(), results = [];
  h.service.download({}, 'file://image.png', 'photo', false, r => results.push(r));
  const request = h.controller.current();
  assert.equal(request.url, 'file://image.png'); assert.deepEqual(h.calls, []);
  await h.service.downloadPhotoWithSaveButton(request.context, request.url, request.mediaId,
    r => h.controller.complete(request, r), request.isVideo);
  assert.deepEqual(results, [0]); assert.equal(h.controller.current(), null);
  assert.deepEqual(h.calls[0], ['create', 1, 'png']);
});

test('a secure photo batch queues every item before showing the button and cancellation reports once', async () => {
  const h = fixture(), results = [];
  h.service.downloadImages({}, ['file://a.jpg', 'file://b.png', 'file://c.jpg'], 'batch', r => results.push(r));
  const first = h.controller.current(); assert.equal(first.url, 'file://a.jpg');
  h.controller.complete(first, 0);
  const second = h.controller.current(); assert.equal(second.url, 'file://b.png');
  assert.deepEqual(results, []);
  h.controller.complete(first, 0); assert.equal(h.controller.current(), second);
  h.controller.cancel(); await new Promise(done => setImmediate(done));
  assert.deepEqual(results, [2]); assert.equal(h.controller.current(), null);
  assert.deepEqual(h.calls, []);
});

test('native direct saving preserves the video type and never opens a second authorization dialog', async () => {
  const h = fixture();
  await h.service.downloadPhotoWithSaveButton({}, 'file://video.mp4', 'video', r => assert.equal(r, 0), true);
  assert.deepEqual(h.calls[0], ['create', 2, 'mp4']);
});

test('all locale catalogs expose distinct, complete save choices', () => {
  for (const locale of fs.readdirSync('entry/src/main/resources')) {
    const path = `entry/src/main/resources/${locale}/element/string.json`;
    if (!fs.existsSync(path)) continue;
    const entries = JSON.parse(fs.readFileSync(path, 'utf8')).string;
    const choices = ['media_save_gallery_dialog', 'media_save_secure_button', 'media_save_directory', 'media_save_file_picker']
      .map(name => {const found = entries.filter(e => e.name === name); assert.equal(found.length, 1); return found[0].value;});
    assert.equal(new Set(choices).size, 4, locale);
  }
});
