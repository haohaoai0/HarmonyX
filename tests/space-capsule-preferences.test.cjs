const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function fixture() {
  const disk = new Map(), pending = new Map(), storage = new Map();
  let flushes = 0, fail = false;
  const code = ts.transpileModule(fs.readFileSync('entry/src/main/ets/services/SpacePreferencesStore.ets', 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText;
  const load = () => {
    const m = { exports: {} };
    new Function('require', 'module', 'exports', 'AppStorage', code)(id => {
      if (id === '@kit.ArkData') return { preferences: { getPreferencesSync: () => ({
        getSync: (key, fallback) => disk.get(key) ?? fallback,
        putSync: (key, value) => pending.set(key, value),
        flushSync: () => {
          if (fail) throw Error('disk unavailable');
          for (const [key, value] of pending) disk.set(key, value);
          pending.clear(); flushes++;
        }
      }) } };
      if (id === './AccountStore') return { accountStore: { active: () => ({ id: 'account' }) } };
      throw Error('Unexpected dependency: ' + id);
    }, m, m.exports, { setOrCreate: (key, value) => storage.set(key, value) });
    return m.exports;
  };
  return { load, storage, disk, flushes: () => flushes, fail: () => { fail = true; } };
}

test('temporary dismissal hides the capsule without persisting and a new launch restores it', () => {
  const f = fixture(), api = f.load();
  api.spacePreferencesStore.beginSession({});
  assert.equal(f.storage.get(api.STORAGE_KEY_HOME_SPACE_CAPSULE_ENABLED), true);
  api.spacePreferencesStore.hideHomeCapsuleForSession();
  assert.equal(f.storage.get(api.STORAGE_KEY_HOME_SPACE_CAPSULE_HIDDEN_FOR_SESSION), true);
  assert.equal(f.flushes(), 0);
  assert.equal(f.disk.size, 0);
  // Recreating a page/store in the same running app does not reset dismissal.
  const next = f.load();
  assert.equal(f.storage.get(api.STORAGE_KEY_HOME_SPACE_CAPSULE_HIDDEN_FOR_SESSION), true);
  next.spacePreferencesStore.beginSession({});
  assert.equal(f.storage.get(api.STORAGE_KEY_HOME_SPACE_CAPSULE_ENABLED), true);
  assert.equal(f.storage.get(api.STORAGE_KEY_HOME_SPACE_CAPSULE_HIDDEN_FOR_SESSION), false);
});

test('direct close survives a fresh launch and Settings can restore the capsule immediately', () => {
  const f = fixture(), api = f.load();
  api.spacePreferencesStore.beginSession({});
  assert.equal(api.spacePreferencesStore.saveHomeCapsuleEnabled({}, false), true);
  f.storage.clear();
  const next = f.load();
  next.spacePreferencesStore.beginSession({});
  assert.equal(f.storage.get(api.STORAGE_KEY_HOME_SPACE_CAPSULE_ENABLED), false);
  assert.equal(f.storage.get(api.STORAGE_KEY_HOME_SPACE_CAPSULE_HIDDEN_FOR_SESSION), false);
  next.spacePreferencesStore.hideHomeCapsuleForSession();
  assert.equal(next.spacePreferencesStore.saveHomeCapsuleEnabled({}, true), true);
  assert.equal(f.storage.get(api.STORAGE_KEY_HOME_SPACE_CAPSULE_ENABLED), true);
  assert.equal(f.storage.get(api.STORAGE_KEY_HOME_SPACE_CAPSULE_HIDDEN_FOR_SESSION), false);
  f.load().spacePreferencesStore.beginSession({});
  assert.equal(f.storage.get(api.STORAGE_KEY_HOME_SPACE_CAPSULE_ENABLED), true);
});

test('failed permanent close keeps the current capsule state and saved preference unchanged', () => {
  const f = fixture(), api = f.load();
  api.spacePreferencesStore.beginSession({}); f.fail();
  assert.equal(api.spacePreferencesStore.saveHomeCapsuleEnabled({}, false), false);
  assert.equal(f.storage.get(api.STORAGE_KEY_HOME_SPACE_CAPSULE_ENABLED), true);
  assert.equal(f.storage.get(api.STORAGE_KEY_HOME_SPACE_CAPSULE_HIDDEN_FOR_SESSION), false);
  assert.equal(f.disk.size, 0);
});
