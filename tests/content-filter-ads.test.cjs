const assert = require('node:assert/strict');
const test = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function loadSource(file, dependencies = {}, appStorage = {}) {
  const source = fs.readFileSync(path.resolve(__dirname, file), 'utf8');
  const output = ts.transpileModule(source, {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText;
  const module = { exports: {} };
  new Function('require', 'module', 'exports', 'AppStorage', output)(
    id => {
      if (Object.hasOwn(dependencies, id)) return dependencies[id];
      throw new Error(id);
    }, module, module.exports, appStorage);
  return module.exports;
}

function fixture() {
  const disk = new Map();
  const storage = new Map();
  const preferences = { getPreferencesSync: () => ({
    getSync: (key, fallback) => disk.has(key) ? disk.get(key) : fallback,
    putSync: (key, value) => disk.set(key, value),
    flushSync() {}
  }) };
  const content = loadSource('../entry/src/main/ets/models/PostContent.ets');
  const disclosure = loadSource('../entry/src/main/ets/utils/PostDisclosure.ets', {
    '../models/PostContent': content
  });
  const filter = loadSource('../entry/src/main/ets/services/ContentFilterStore.ets', {
    '@kit.ArkData': { preferences }, '../utils/PostDisclosure': disclosure
  }, {
    get: key => storage.get(key), setOrCreate: (key, value) => storage.set(key, value)
  });
  return { ...filter, disk, storage };
}

function post(id, label = '') {
  return { id, text: '', author: { id, name: id, username: id },
    presentation: label ? { labels: [{ kind: label }] } : undefined };
}

test('ads are hidden by default, while paid promotion disclosures remain', () => {
  const { contentFilterStore, STORAGE_KEY_FILTER_HIDE_ADS, storage } = fixture();
  const settings = contentFilterStore.load({});
  assert.equal(settings.hideAds, true);
  assert.equal(storage.get(STORAGE_KEY_FILTER_HIDE_ADS), true);
  assert.deepEqual(contentFilterStore.filter([post('ad', 'ad'), post('paid', 'paid'), post('normal')], settings)
    .map(item => item.id), ['paid', 'normal']);
});

test('turning the switch off restores ads and survives reload', () => {
  const { ContentFilterStore, contentFilterStore, disk } = fixture();
  const settings = contentFilterStore.load({});
  settings.hideAds = false;
  assert.equal(contentFilterStore.save({}, settings), true);
  assert.equal(disk.get('hide_ads'), false);
  const restored = new ContentFilterStore().load({});
  assert.equal(restored.hideAds, false);
  assert.equal(contentFilterStore.shouldHide(post('ad', 'ad'), restored), false);
});
