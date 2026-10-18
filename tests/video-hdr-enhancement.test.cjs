const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const compile = source => ts.transpileModule(source, {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText;
const serviceFile = 'entry/src/main/ets/services/VideoHdrEnhancement.ets';

function fixture(api = 26) {
  const published = new Map(), screenListeners = new Map(), windowListeners = new Map();
  const deviceInfo = { sdkApiVersion: api };
  const screens = new Map([[0, { id: 0, hdrFormats: [1, 2, 3, 8] }], [1, { id: 1, hdrFormats: [1, 2, 3] }]]);
  let displayId = 0, failQuery = false, queries = 0;
  const current = {
    getWindowProperties: () => ({ displayId }),
    on: (event, callback) => windowListeners.set(event, callback),
    off: (event, callback) => { if (windowListeners.get(event) === callback) windowListeners.delete(event); }
  };
  const modules = {
    '@kit.ArkUI': { display: {
      getDisplayByIdSync: id => { queries++; if (failQuery) throw Error('display removed'); return screens.get(id); },
      on: (event, callback) => screenListeners.set(event, callback),
      off: (event, callback) => { if (screenListeners.get(event) === callback) screenListeners.delete(event); }
    } },
    '@kit.ArkGraphics2D': { hdrCapability: { HDRFormat: { VIDEO_AIHDR: 8 } } },
    '@kit.BasicServicesKit': { deviceInfo },
    '@ohos.hilog': { default: { info() {}, warn() {} } }
  };
  if (api < 24) Object.defineProperty(modules['@kit.ArkGraphics2D'].hdrCapability, 'HDRFormat', {
    get() { throw Error('API 24 enum accessed on an older device'); }
  });
  const exports = {};
  new Function('require', 'exports', 'AppStorage', 'HdrType', compile(fs.readFileSync(serviceFile, 'utf8')))
    (name => modules[name], exports, { setOrCreate: (key, value) => published.set(key, value) }, { DEFAULT: 0, AIHDR: 1 });
  const capability = new exports.VideoHdrCapability();
  const supported = () => published.get(exports.STORAGE_KEY_VIDEO_HDR_SUPPORTED);
  return { exports, capability, current, supported, screens, screenListeners, windowListeners,
    queryCount: () => queries,
    move: id => { displayId = id; windowListeners.get('displayIdChange')?.(id); },
    fail: () => { failQuery = true; } };
}

test('AI HDR is enabled only when the current screen explicitly advertises VIDEO_AIHDR', () => {
  const f = fixture();
  f.capability.observe(f.current);
  assert.equal(f.supported(), true);
  f.move(1);
  assert.equal(f.supported(), false, 'HLG/HDR10/Vivid support alone is insufficient for AI HDR');
  f.move(0);
  assert.equal(f.supported(), true);
  f.screens.get(0).hdrFormats = [];
  f.screenListeners.get('change')(0);
  assert.equal(f.supported(), false);
});

test('older systems never access the new enum or call the new modifier overload', () => {
  const f = fixture(23);
  f.capability.observe(f.current);
  assert.equal(f.supported(), false);
  assert.equal(f.queryCount(), 0);
  assert.equal(f.screenListeners.size, 0);
  let nativeCalls = 0;
  new f.exports.VideoHdrEnhancementModifier(true, true).applyNormalAttribute({ hdrBrightness() { nativeCalls++; } });
  assert.equal(nativeCalls, 0);
});

test('API 24 devices can use AI HDR without requiring API 26 processor notifications', () => {
  const f = fixture(24);
  f.capability.observe(f.current);
  assert.equal(f.supported(), true);
});

test('capability errors fail closed, and window destruction removes only owned listeners', () => {
  const f = fixture();
  f.capability.observe(f.current);
  assert.equal(f.supported(), true);
  f.fail(); f.capability.refresh();
  assert.equal(f.supported(), false);
  f.capability.stop();
  assert.equal(f.screenListeners.size, 0);
  assert.equal(f.windowListeners.size, 0);
  assert.equal(f.supported(), false);
  f.capability.stop();
});

test('live setting changes reset AI HDR to DEFAULT while retaining native HDR brightness', () => {
  const f = fixture(), calls = [], surface = { hdrBrightness: (...args) => calls.push(args) };
  for (const [enabled, supported] of [[true, true], [false, true], [true, false]]) {
    new f.exports.VideoHdrEnhancementModifier(enabled, supported).applyNormalAttribute(surface);
  }
  assert.deepEqual(calls, [[1, 1], [1, 0], [1, 0]]);
});

test('a rejected enhancement restores normal rendering without touching AVPlayer', () => {
  const f = fixture(), calls = [];
  assert.doesNotThrow(() => new f.exports.VideoHdrEnhancementModifier(true, true).applyNormalAttribute({
    hdrBrightness(brightness, type) { calls.push([brightness, type]); if (type === 1) throw Error('801'); }
  }));
  assert.deepEqual(calls, [[1, 1], [1, 0]]);
  assert.doesNotThrow(() => new f.exports.VideoHdrEnhancementModifier(true, true).applyNormalAttribute({
    hdrBrightness() { throw Error('surface gone'); }
  }));
});

test('the preference survives restart and failed persistence does not publish a changed value', () => {
  const disk = new Map(), published = new Map(); let fail = false;
  const exports = {};
  new Function('require', 'exports', 'AppStorage', compile(fs.readFileSync('entry/src/main/ets/services/MediaSettingsStore.ets', 'utf8')))
    (() => ({ preferences: { getPreferencesSync: () => ({
      getSync: (key, fallback) => disk.get(key) ?? fallback,
      putSync: (key, value) => { if (fail) throw Error('disk full'); disk.set(key, value); },
      flushSync() { if (fail) throw Error('disk full'); }
    }) } }), exports, { setOrCreate: (key, value) => published.set(key, value) });
  let store = new exports.MediaSettingsStore();
  assert.equal(store.loadVideoHdrEnhancement({}), true);
  assert.equal(store.saveVideoHdrEnhancement({}, false), true);
  store = new exports.MediaSettingsStore();
  assert.equal(store.loadVideoHdrEnhancement({}), false);
  fail = true;
  assert.equal(store.saveVideoHdrEnhancement({}, true), false);
  assert.equal(published.get(exports.STORAGE_KEY_VIDEO_HDR_ENHANCEMENT), false);
});

test('both existing video surfaces consume the preference, and settings are searchable in every locale', () => {
  const source = fs.readFileSync('entry/src/main/ets/components/PostMedia.ets', 'utf8');
  assert.equal((source.match(/attributeModifier\(new VideoHdrEnhancementModifier\(this.videoHdrEnhancement && !this.isAnimatedGif\(\), this.videoHdrSupported\)\)/g) || []).length, 2);
  const catalog = fs.readFileSync('entry/src/main/ets/models/SettingsCatalog.ets', 'utf8');
  assert.match(catalog, /app.string.settings_video_hdr_enhancement/);
  const base = 'entry/src/main/resources';
  for (const locale of fs.readdirSync(base)) {
    const file = path.join(base, locale, 'element/string.json');
    if (!fs.existsSync(file)) continue;
    const strings = JSON.parse(fs.readFileSync(file, 'utf8')).string;
    for (const key of ['settings_video_hdr_enhancement', 'settings_video_hdr_enhancement_desc']) {
      assert.equal(strings.filter(s => s.name === key && s.value.length > 0).length, 1, `${locale}: ${key}`);
    }
  }
});
