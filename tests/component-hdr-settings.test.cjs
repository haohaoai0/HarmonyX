const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const compile = source => ts.transpileModule(source, {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText;

function fixture() {
  const disk = new Map();
  const live = new Map();
  const pending = new Map();
  let failWrite = false;
  let failRead = false;
  const store = {
    getSync: (key, fallback) => { if (failRead) throw Error('read failed'); return disk.has(key) ? disk.get(key) : fallback; },
    putSync: (key, value) => pending.set(key, value),
    flushSync: () => {
      if (failWrite) throw Error('write failed');
      for (const [key, value] of pending) disk.set(key, value);
      pending.clear();
    }
  };
  const exports = {};
  new Function('require', 'exports', 'AppStorage', compile(fs.readFileSync(
    'entry/src/main/ets/services/ComponentHdrSettingsStore.ets', 'utf8')))(id => {
    assert.equal(id, '@kit.ArkData');
    return { preferences: { getPreferencesSync: () => store } };
  }, exports, { setOrCreate: (key, value) => live.set(key, value) });
  return { exports, disk, live, failWrite: () => { failWrite = true; }, failRead: () => { failRead = true; } };
}

test('first launch disables the effect and initializes a 1.25 multiplier', () => {
  const f = fixture();
  const { componentHdrSettingsStore: store, STORAGE_KEY_COMPONENT_HDR_RATIO: key,
    STORAGE_KEY_COMPONENT_HDR_ENABLED: enabledKey } = f.exports;
  store.initialize({});
  assert.equal(store.load({}), 1.25);
  assert.equal(f.live.get(key), 1.25);
  assert.equal(store.loadEnabled({}), false);
  assert.equal(f.live.get(enabledKey), false);
  assert.equal(store.saveEnabled({}, true), true);
  assert.equal(f.live.get(enabledKey), true);
  assert.equal(new f.exports.ComponentHdrSettingsStore().loadEnabled({}), true);
  assert.equal(store.saveEnabled({}, false), true);
  assert.equal(f.live.get(enabledKey), false);
  assert.equal(store.save({}, 2.375), true);
  assert.equal(f.live.get(key), 2.375);
  assert.equal(new f.exports.ComponentHdrSettingsStore().load({}), 2.375);
  assert.equal(store.save({}, 1), true);
  assert.equal(new f.exports.ComponentHdrSettingsStore().load({}), 1);
  assert.equal(store.save({}, f.exports.DEFAULT_COMPONENT_HDR_RATIO), true);
  assert.equal(store.load({}), 1.25);
});

test('invalid values and failed writes preserve the last saved and published multiplier', () => {
  const f = fixture();
  const { componentHdrSettingsStore: store, STORAGE_KEY_COMPONENT_HDR_RATIO: key } = f.exports;
  store.save({}, 1.75);
  for (const value of [NaN, Infinity, -1, 0, 0.99]) assert.equal(store.save({}, value), false);
  f.failWrite();
  assert.equal(store.save({}, 2.5), false);
  assert.equal(f.live.get(key), 1.75);
  assert.equal(store.load({}), 1.75);
});

test('corrupted preferences or unavailable storage fall back to 1.25', () => {
  const f = fixture();
  for (const value of [NaN, Infinity, -1, 0, '2']) {
    f.disk.set('ratio', value);
    assert.equal(f.exports.componentHdrSettingsStore.load({}), 1.25);
  }
  f.disk.set('enabled', 'true');
  assert.equal(f.exports.componentHdrSettingsStore.loadEnabled({}), false);
  f.failRead();
  assert.equal(f.exports.componentHdrSettingsStore.load({}), 1.25);
  assert.equal(f.exports.componentHdrSettingsStore.loadEnabled({}), false);
});

test('decimal input accepts arbitrary precision and comma separators without accepting partial garbage', () => {
  const { parseComponentHdrRatio: parse } = fixture().exports;
  for (const [text, value] of [['1.25', 1.25], ['1.', 1], ['2.375', 2.375], [' 1,625 ', 1.625], ['16', 16]]) {
    assert.equal(parse(text), value);
  }
  for (const text of ['', ' ', '0.9', '-1', 'NaN', 'Infinity', '1.2abc', '1..2', '0x10']) assert.equal(parse(text), null);
});

test('editing the actual settings handler preserves a trailing decimal and invalid drafts keep the applied value', () => {
  const f = fixture();
  const source = fs.readFileSync('entry/src/main/ets/components/ComponentHdrSettingsContent.ets', 'utf8')
    .replace('struct ComponentHdrSettingsContent', 'class ComponentHdrSettingsContent');
  const tree = ts.createSourceFile('settings.ts', source, ts.ScriptTarget.Latest, true);
  const component = tree.statements.find(node => ts.isClassDeclaration(node));
  const handler = component.members.find(node => node.name?.getText(tree) === 'updateRatio').getText(tree);
  const Handler = new Function('parseComponentHdrRatio', 'componentHdrSettingsStore', compile(`class Handler { ${handler} }; exports.Handler = Handler;`)
    .replace('exports.Handler = Handler;', 'return Handler;'))(f.exports.parseComponentHdrRatio, {
    save: (_context, value) => { control.ratio = value; return true; }
  });
  const control = Object.assign(new Handler(), { ratio: 1.25, getUIContext: () => ({ getHostContext: () => ({}) }) });
  control.updateRatio('2.');
  assert.equal(control.draft, '2.');
  control.updateRatio('2.375');
  assert.equal(control.draft, '2.375');
  assert.equal(control.ratio, 2.375);
  control.updateRatio('0.5');
  assert.equal(control.invalid, true);
  assert.equal(control.ratio, 2.375);
  control.updateRatio('1.25');
  assert.equal(control.invalid, false);
  assert.equal(control.ratio, 1.25);
});

test('every existing locale has the HDR setting labels and the numeric default matches 1.25', () => {
  const resources = 'entry/src/main/resources';
  const keys = ['settings_component_hdr_enabled', 'settings_component_hdr_enabled_desc', 'settings_component_hdr_ratio', 'settings_component_hdr_desc', 'settings_component_hdr_invalid', 'settings_component_hdr_reset',
    'settings_component_hdr_max', 'settings_component_hdr_max_unavailable', 'settings_component_hdr_max_desc'];
  for (const locale of fs.readdirSync(resources)) {
    const file = path.join(resources, locale, 'element/string.json');
    if (!fs.existsSync(file)) continue;
    const strings = JSON.parse(fs.readFileSync(file, 'utf8')).string;
    for (const key of keys) {
      const values = strings.filter(item => item.name === key);
      assert.equal(values.length, 1, `${locale}: ${key}`);
      assert.ok(values[0].value.length > 0);
    }
  }
  const numeric = JSON.parse(fs.readFileSync(path.join(resources, 'base/element/float.json'), 'utf8')).float;
  assert.equal(Number(numeric.find(item => item.name === 'component_hdr_highlight_ratio').value), 1.25);
});
