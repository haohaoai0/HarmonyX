const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function fixture() {
  const disk = new Map();
  const storage = new Map();
  let failRead = false;
  let failWrite = false;
  const preferences = { getPreferencesSync() {
    if (failRead) throw Error('read failure');
    const pending = new Map();
    return {
      getSync: (key, fallback) => disk.has(key) ? disk.get(key) : fallback,
      putSync: (key, value) => pending.set(key, value),
      flushSync: () => {
        if (failWrite) throw Error('write failure');
        for (const [key, value] of pending) disk.set(key, value);
      }
    };
  } };
  function load(file, dependencies = {}) {
    const exports = {};
    const js = ts.transpileModule(fs.readFileSync(`entry/src/main/ets/${file}.ets`, 'utf8'), {
      compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 }
    }).outputText;
    new Function('exports', 'require', 'AppStorage', 'NavigationSystemTransitionType', 'Observed',
      'NavDestinationMode', 'NavigationOperation', 'Curve', js)(
      exports, id => id === '@kit.ArkData' ? { preferences } : dependencies[id],
      { setOrCreate: (key, value) => storage.set(key, value), get: key => storage.get(key) },
      { DEFAULT: 0, NONE: 1, FADE: 4, EXPLODE: 5 }, value => value,
      { STANDARD: 0, DIALOG: 1 }, { PUSH: 0, POP: 1, REPLACE: 2 }, { Friction: 'friction' });
    return exports;
  }
  const settings = load('services/PageTransitionSettingsStore');
  const motionSettings = load('services/MotionSettingsStore');
  const motion = load('utils/AppMotion', { '../services/MotionSettingsStore': motionSettings,
    '@kit.ArkUI': { curves: { springCurve: (...args) => args } } });
  const transition = load('utils/PageTransition', { '../services/PageTransitionSettingsStore': settings,
    './AppMotion': motion });
  return { settings, transition, disk, storage,
    failRead: () => { failRead = true; }, failWrite: () => { failWrite = true; } };
}

test('existing and fresh installs retain classic until the user chooses official', () => {
  const f = fixture();
  assert.equal(f.settings.pageTransitionSettingsStore.load({}), 'classic');
  assert.equal(f.transition.pageSystemTransition('classic'), 0);
  assert.equal(f.transition.pageSystemTransition('classic', 4), 4);
});

test('official selection updates live pages and survives recreation of the settings store', () => {
  const f = fixture();
  assert.equal(f.settings.pageTransitionSettingsStore.save({}, 'official'), true);
  assert.equal(f.storage.get(f.settings.STORAGE_KEY_PAGE_TRANSITION_MODE), 'official');
  assert.equal(new f.settings.PageTransitionSettingsStore().load({}), 'official');
  assert.equal(f.transition.pageSystemTransition('official'), 5);
  assert.equal(f.transition.pageSystemTransition('official', 4), 5);
  assert.equal(f.settings.pageTransitionSettingsStore.save({}, 'classic'), true);
  assert.equal(new f.settings.PageTransitionSettingsStore().load({}), 'classic');
});

test('media transitions retain ownership of pages that disable the system animation', () => {
  const f = fixture();
  assert.equal(f.transition.pageSystemTransition('official', 1), 1);
  assert.equal(f.transition.pageSystemTransition('classic', 1), 1);
});

test('invalid persisted modes and read failures safely restore classic', () => {
  const f = fixture();
  for (const value of ['future-mode', '', null, 8]) {
    f.disk.set('mode', value);
    assert.equal(f.settings.pageTransitionSettingsStore.load({}), 'classic');
  }
  f.failRead();
  assert.equal(f.settings.pageTransitionSettingsStore.load({}), 'classic');
});

test('failed persistence leaves the active selection unchanged', () => {
  const f = fixture();
  assert.equal(f.settings.pageTransitionSettingsStore.save({}, 'official'), true);
  f.failWrite();
  assert.equal(f.settings.pageTransitionSettingsStore.save({}, 'classic'), false);
  assert.equal(f.storage.get(f.settings.STORAGE_KEY_PAGE_TRANSITION_MODE), 'official');
  assert.equal(f.settings.pageTransitionSettingsStore.load({}), 'official');
});

function motionFixture() {
  const f = fixture();
  const root = new f.transition.PageTransitionMotion();
  const first = new f.transition.PageTransitionMotion();
  const second = new f.transition.PageTransitionMotion();
  first.attach({ navDestinationId: 'first' });
  second.attach({ navDestinationId: 'second' });
  let options;
  let finished = 0;
  const ui = { animateTo: (params, processor) => { options = params; processor(); } };
  const proxy = { finishTransition: () => { finished++; } };
  return { ...f, root, first, second, ui, proxy, options: () => options, finished: () => finished };
}

test('official entry owns the root and destination together, eliminating the root slide', () => {
  const f = motionFixture();
  const animation = f.transition.officialPageTransition(f.ui, f.root, 'official',
    { index: -1 }, { index: 0, navDestinationId: 'first' }, 0);
  assert.ok(animation);
  animation.transition(f.proxy);
  assert.equal(f.root.opacity, 0);
  assert.equal(f.root.scale, 0.96);
  assert.equal(f.first.opacity, 1);
  assert.equal(f.first.scale, 1);
  f.options().onFinish();
  assert.equal(f.finished(), 1);
  animation.onTransitionEnd(true);
  assert.equal(f.root.opacity, 1);
  assert.equal(f.root.scale, 1);
});

test('official return restores the root and resets both surfaces when canceled', () => {
  const f = motionFixture();
  const animation = f.transition.officialPageTransition(f.ui, f.root, 'official',
    { index: 0, navDestinationId: 'first' }, { index: -1 }, 1);
  animation.transition(f.proxy);
  assert.equal(f.first.scale, 1.04);
  assert.equal(f.first.opacity, 0);
  assert.equal(f.root.scale, 1);
  animation.onTransitionEnd(false);
  f.options().onFinish();
  assert.equal(f.finished(), 0);
  for (const motion of [f.root, f.first]) {
    assert.equal(motion.scale, 1);
    assert.equal(motion.opacity, 1);
  }
});

test('a late completion cannot reset a newer transition on the same page', () => {
  const f = motionFixture();
  const first = f.transition.officialPageTransition(f.ui, f.root, 'official',
    { index: -1 }, { index: 0, navDestinationId: 'first' }, 0);
  first.transition(f.proxy);
  const next = f.transition.officialPageTransition(f.ui, f.root, 'official',
    { index: 0, navDestinationId: 'first' }, { index: 1, navDestinationId: 'second' }, 0);
  next.transition(f.proxy);
  first.onTransitionEnd(true);
  assert.equal(f.first.opacity, 0);
  assert.equal(f.first.scale, 0.96);
  next.onTransitionEnd(true);
  assert.equal(f.first.opacity, 1);
  assert.equal(f.second.opacity, 1);
});

test('classic and media dialogs retain their existing transition ownership', () => {
  const f = motionFixture();
  const from = { index: -1 };
  const to = { index: 0, navDestinationId: 'first' };
  assert.equal(f.transition.officialPageTransition(f.ui, f.root, 'classic', from, to, 0), undefined);
  assert.equal(f.transition.officialPageTransition(f.ui, f.root, 'official', from, { ...to, mode: 1 }, 0), undefined);
});
