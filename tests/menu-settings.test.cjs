const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function fixture() {
  const disk = new Map(), storage = new Map();
  let fail = false;
  const compile = file => ts.transpileModule(fs.readFileSync(file, 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText;
  const catalog = {}, api = {};
  new Function('exports', '$r', compile('entry/src/main/ets/models/MenuActionCatalog.ets'))(catalog, value => value);
  const requireMock = name => name.includes('MenuActionCatalog') ? catalog : { preferences: {
    getPreferencesSync: () => {
      const pending = new Map();
      return {
        getSync: (key, fallback) => disk.get(key) ?? fallback,
        putSync: (key, value) => pending.set(key, value),
        flushSync: () => {
          if (fail) throw Error('disk full');
          for (const [key, value] of pending) disk.set(key, value);
        }
      };
    }
  } };
  new Function('exports', 'require', 'AppStorage', compile('entry/src/main/ets/services/MenuSettingsStore.ets'))(
    api, requireMock, { setOrCreate: (key, value) => storage.set(key, value) });
  return { catalog, api, disk, storage, fail: () => { fail = true; } };
}

test('each menu action can be hidden independently, restored and reloaded', () => {
  const f = fixture(), store = new f.api.MenuSettingsStore();
  assert.equal(store.load({}), '');
  for (const option of f.catalog.MENU_ACTION_OPTIONS) {
    assert.equal(store.saveVisible({}, option.id, false), true);
    assert.equal(f.catalog.menuActionVisible(new f.api.MenuSettingsStore().load({}), option.id), false);
    for (const other of f.catalog.MENU_ACTION_OPTIONS) {
      assert.equal(f.catalog.menuActionVisible(store.load({}), other.id), other.id !== option.id);
    }
    assert.equal(f.storage.get(f.api.STORAGE_KEY_HIDDEN_MENU_ACTIONS), option.id);
    assert.equal(store.saveVisible({}, option.id, true), true);
    assert.equal(store.load({}), '');
  }
});

test('restoring an entire menu preserves choices in the other menus', () => {
  const f = fixture(), store = new f.api.MenuSettingsStore();
  for (const option of f.catalog.MENU_ACTION_OPTIONS) store.saveVisible({}, option.id, false);
  store.resetGroup({}, 'photo_menu');
  for (const option of f.catalog.MENU_ACTION_OPTIONS) {
    assert.equal(f.catalog.menuActionVisible(store.load({}), option.id), option.group === 'photo_menu');
  }
});

test('invalid saved IDs are ignored and failed writes do not change the active menu', () => {
  const f = fixture(), store = new f.api.MenuSettingsStore();
  f.disk.set('hidden_actions', 'removed.action,photo.save,photo.save,');
  assert.equal(store.load({}), 'photo.save');
  store.publish(store.load({}));
  assert.equal(store.saveVisible({}, 'invented.action', false), false);
  f.fail();
  assert.equal(store.saveVisible({}, 'photo.save', true), false);
  assert.equal(f.storage.get(f.api.STORAGE_KEY_HIDDEN_MENU_ACTIONS), 'photo.save');
  assert.equal(store.load({}), 'photo.save');
});
