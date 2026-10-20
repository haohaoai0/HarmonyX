const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function load(file, dependencies = {}, storage = new Map()) {
  const code = ts.transpileModule(fs.readFileSync('entry/src/main/ets/' + file + '.ets', 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText;
  const module = { exports: {} };
  new Function('require', 'module', 'exports', 'canIUse', 'AppStorage', code)(id => {
    assert.ok(Object.hasOwn(dependencies, id), 'unexpected import ' + id);
    return dependencies[id];
  }, module, module.exports, () => true, { setOrCreate: (key, value) => storage.set(key, value) });
  return module.exports;
}
const core = load('utils/EyeReadingPolicy');
function harness() {
  const policy = new core.EyeReadingPolicy();
  let time = 1000;
  const actions = [];
  const feed = (y = 0, n = 1, extras = {}, blocked = false) => {
    let result;
    for (let i = 0; i < n; i++) {
      const sample = Object.assign(new core.EyeReadingSample(), { time, valid: true, vertical: y }, extras);
      result = policy.update(sample, blocked); time += 100;
      if (result.action) actions.push(result.action);
    }
    return result;
  };
  return { policy, feed, actions, get time() { return time; }, gap: ms => { time += ms; } };
}

test('requires stable calibration, then neutral dwell, and fires once until rearmed', () => {
  const h = harness();
  assert.equal(h.feed(0, 15).state, 'center');
  assert.equal(h.feed(0, 4).state, 'ready');
  h.feed(0.7, 30); assert.deepEqual(h.actions, [1]);
  h.feed(0, 5); h.feed(-0.7, 30); assert.deepEqual(h.actions, [1, -1]);
});

test('calibration subtracts a nonzero resting eye position', () => {
  const h = harness(); h.feed(0.25, 20);
  h.feed(0.25, 30); assert.deepEqual(h.actions, []);
  h.feed(0.9, 18); assert.deepEqual(h.actions, [1]);
});

test('brief glances and alternating directions do not turn a page', () => {
  const h = harness(); h.feed(0, 20);
  for (let i = 0; i < 8; i++) { h.feed(0.7, 5); h.feed(-0.7, 5); }
  assert.deepEqual(h.actions, []);
});

test('blink, uncertain eyes, invalid weights and lateral gaze cancel dwell', () => {
  for (const extras of [{ blink: 0.8 }, { valid: false }, { vertical: NaN },
    { horizontal: NaN }, { eyeDifference: 0.8 }, { horizontal: 0.8 }]) {
    const h = harness(); h.feed(0, 20); h.feed(0.7, 6); h.feed(0.7, 1, extras);
    h.feed(0.7, 20); assert.deepEqual(h.actions, [], JSON.stringify(extras));
    h.feed(0, 6); h.feed(0.7, 20); assert.deepEqual(h.actions, [1]);
  }
});

test('touch and modal input prevent a pending turn and require neutral rearming', () => {
  const h = harness(); h.feed(0, 20); h.feed(0.7, 7);
  h.policy.suspend(h.time, 1500); h.feed(0.7, 30);
  assert.deepEqual(h.actions, []);
  h.feed(0, 5); h.feed(0.7, 7); h.feed(0.7, 1, {}, true); h.feed(0.7, 20);
  assert.deepEqual(h.actions, []);
  h.feed(0, 5); h.feed(0.7, 20); assert.deepEqual(h.actions, [1]);
});

test('missing frames cannot complete calibration or preserve a pending turn', () => {
  const h = harness(); h.feed(0, 8); h.gap(600);
  assert.equal(h.feed(0).state, 'calibrating'); h.feed(0, 20); h.feed(0.7, 7);
  h.gap(500); h.feed(0.7, 20); assert.deepEqual(h.actions, []);
  h.feed(0, 5); h.feed(0.7, 20); assert.deepEqual(h.actions, [1]);
});

test('prolonged face loss recalibrates and a new session never reuses calibration', () => {
  const h = harness(); h.feed(0, 20); h.feed(0, 25, { valid: false });
  assert.equal(h.feed(0).state, 'calibrating');
  h.feed(0, 20); h.policy.reset(); assert.equal(h.feed(0).state, 'calibrating');
});

test('dwell settings change the required hold duration and malformed settings fall back safely', () => {
  const h = harness(); h.policy.configure(1800, 0.4); h.feed(0, 20);
  h.feed(0.7, 15); assert.deepEqual(h.actions, []); h.feed(0.7, 10); assert.deepEqual(h.actions, [1]);
  h.policy.configure(NaN, NaN); h.feed(0, 20); h.feed(-0.7, 15); assert.deepEqual(h.actions, [1, -1]);
});

function nativeHarness(options = {}) {
  const views = []; const scenes = []; let loads = 0;
  class View {
    constructor() { views.push(this); this.pauses = 0; this.destroys = 0; }
    async init() { if (options.init) await options.init(); this.initialized = true; }
    pause() { this.pauses++; }
    async destroy() { this.destroys++; }
  }
  class Callback {}
  const arEngine = { ARType: { FACE: 16 }, ARFeatureType: { ARENGINE_FEATURE_TYPE_FACE: 6 },
    ARCameraLensFacing: { FRONT: 1 }, ARMultiFaceMode: { MULTIFACE_DISABLE: 768 },
    ARPlaneFindingMode: { DISABLED: 0 }, ARSemanticMode: { NONE: 0 }, ARMeshMode: { DISABLED: 0 },
    ARFocusMode: { AUTO: 1 }, ARTrackableType: { FACE: 7 }, ARTrackingState: { TRACKING: 0 },
    ARBlendShapeType: Object.fromEntries(['EYE_BLINK_LEFT','EYE_BLINK_RIGHT','LEFT_EYEBALL_DOWN',
      'LEFT_EYEBALL_UP','RIGHT_EYEBALL_DOWN','RIGHT_EYEBALL_UP','LEFT_EYEBALL_RIGHT',
      'LEFT_EYEBALL_LEFT','RIGHT_EYEBALL_RIGHT','RIGHT_EYEBALL_LEFT'].map((key, index) => [key, index])) };
  const lib = load('services/EyeReadingSession', {
    '@kit.AREngine': { arEngine, arViewController: { ARViewCallback: Callback, ARViewContext: View, isARTypeSupported: () => true } },
    '@kit.ArkGraphics3D': { Scene: { load: async () => {
      loads++; const scene = { destroys: 0, destroy() { this.destroys++; } }; scenes.push(scene); return scene;
    } } },
    '@kit.BasicServicesKit': { deviceInfo: { sdkApiVersion: 24,
      apiAvailable: version => {
        if (version === '26.0.0') { throw Error('API 26 function must not run on API 24'); }
        return version === '6.1.0(23)';
      } } }, '../utils/EyeReadingPolicy': core
    , '@kit.PerformanceAnalysisKit': { hilog: { info() {}, warn() {} } }
  });
  return { lib, views, scenes, arEngine, get loads() { return loads; } };
}

test('API 23 and 24 capability checks use the AR version guard without an API 26-only call', () => {
  const h = nativeHarness(); assert.equal(h.lib.eyeReadingSupported(), true);
});

test('canceled native startup cannot open a camera, and stopping destroys the active context', async () => {
  const h = nativeHarness(); let shown = 0;
  const session = new h.lib.EyeReadingSession(() => {});
  const first = session.start(() => {}, () => { shown++; }); session.stop(); await first;
  assert.equal(h.loads, 0); assert.equal(shown, 0);
  await session.start(() => {}, () => { shown++; });
  assert.equal(shown, 1); const view = h.views[0]; session.stop();
  assert.equal(view.pauses, 1);
  // A new start is queued after the previous destruction.
  await session.start(() => {}, () => { shown++; });
  assert.equal(view.destroys, 1); session.stop();
  assert.equal(h.scenes[0].destroys, 1);
});

test('canceling during native initialization destroys both context and scene without showing a view', async () => {
  let enter; const entered = new Promise(resolve => { enter = resolve; });
  let finish; const gate = new Promise(resolve => { finish = resolve; });
  const h = nativeHarness({ init: async () => { enter(); await gate; } });
  const session = new h.lib.EyeReadingSession(() => {}); let shown = false;
  const pending = session.start(() => {}, () => { shown = true; }); await entered;
  session.stop(); finish(); await pending;
  assert.equal(shown, false); assert.equal(h.views[0].destroys, 1); assert.equal(h.scenes[0].destroys, 1);
});

test('native initialization failure preserves the error code and frees allocated resources', async () => {
  const h = nativeHarness({ init: async () => { throw Object.assign(new Error('camera unavailable'), { code: 1009200010 }); } });
  const session = new h.lib.EyeReadingSession(() => {});
  await assert.rejects(session.start(() => {}, () => {}), error => error.code === 1009200010);
  assert.equal(h.views[0].destroys, 1); assert.equal(h.scenes[0].destroys, 1);
});

test('only one reading pane owns the camera and stale callbacks cannot act', async () => {
  const h = nativeHarness(); let oldSamples = 0; let closed = 0;
  const first = new h.lib.EyeReadingSession(() => { closed++; });
  const second = new h.lib.EyeReadingSession(() => {});
  await first.start(() => { oldSamples++; }, () => {});
  const old = h.views[0]; await second.start(() => {}, () => {});
  assert.equal(old.destroys, 1); assert.equal(closed, 1);
  old.callback.onFrameUpdate(old, 100000); assert.equal(oldSamples, 0); second.stop();
});

test('adapter maps values by expression type and releases native handles, including on failure', async () => {
  const h = nativeHarness(); const samples = []; let releases = 0;
  const session = new h.lib.EyeReadingSession(() => {});
  await session.start(sample => samples.push(sample), () => {});
  const view = h.views[0]; const types = Object.values(h.arEngine.ARBlendShapeType).reverse();
  const weights = { LEFT_EYEBALL_DOWN: 0.7, RIGHT_EYEBALL_DOWN: 0.7 };
  const values = types.map(type => weights[Object.keys(h.arEngine.ARBlendShapeType).find(key => h.arEngine.ARBlendShapeType[key] === type)] || 0);
  const face = { state: 0, release: async () => { releases++; }, getBlendShapes: () => ({
    getData: () => new Float32Array(values).buffer, getTypes: () => types, release: async () => { releases++; } }) };
  view.session = { getFrame: () => ({ release: async () => { releases++; } }), getAllTrackables: () => [face] };
  view.callback.onFrameUpdate(view, 100000);
  assert.equal(samples[0].valid, true); assert.ok(Math.abs(samples[0].vertical - 0.7) < 0.001);
  assert.equal(releases, 3);
  face.getBlendShapes = () => { throw Error('native failed'); };
  view.callback.onFrameUpdate(view, 200000); assert.equal(samples[1].valid, false); assert.equal(releases, 5);
  session.stop();
});

test('every existing language includes every eye-reading string and a permission reason', () => {
  const base = JSON.parse(fs.readFileSync('entry/src/main/resources/base/element/string.json')).string;
  const keys = base.filter(row => row.name.startsWith('eye_reading_')).map(row => row.name);
  assert.equal(keys.length, 25);
  for (const locale of fs.readdirSync('entry/src/main/resources')) {
    const file = `entry/src/main/resources/${locale}/element/string.json`;
    if (!fs.existsSync(file)) continue;
    const entries = JSON.parse(fs.readFileSync(file)).string;
    if (!entries.some(row => row.name === 'reader_title')) continue;
    for (const key of keys) assert.ok(entries.find(row => row.name === key)?.value.trim(), `${locale}: ${key}`);
  }
});
