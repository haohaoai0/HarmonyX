const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function fixture() {
  const disk = new Map(), published = new Map(), modules = new Map();
  let failFlush = false;
  const preferences = { getPreferencesSync: (_context, options) => {
    if (!disk.has(options.name)) disk.set(options.name, new Map());
    const saved = disk.get(options.name), pending = new Map();
    return { getSync: (key, fallback) => saved.has(key) ? saved.get(key) : fallback,
      putSync: (key, value) => pending.set(key, value),
      flushSync: () => {
        if (failFlush) throw Error('disk unavailable');
        for (const [key, value] of pending) saved.set(key, value);
      } };
  } };
  const load = relative => {
    const filename = path.resolve('entry/src/main/ets', relative + '.ets');
    if (modules.has(filename)) return modules.get(filename);
    const exports = {};
    const code = ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
      compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
    }).outputText;
    new Function('require', 'exports', 'AppStorage', '$r', code)(id => {
      if (id === '@kit.ArkData') return { preferences };
      if (id.startsWith('.')) return load(path.relative('entry/src/main/ets', path.resolve(path.dirname(filename), id)));
      throw Error(id);
    }, exports, { setOrCreate: (key, value) => published.set(key, value) }, id => id);
    modules.set(filename, exports);
    return exports;
  };
  return { load, disk, published, fail: () => { failFlush = true; } };
}

test('compact counts preserve K/M precision and promote rounded unit boundaries', () => {
  const { formatPostCount } = fixture().load('utils/PostCountFormat');
  for (const [count, expected] of [[0, '0'], [999, '999'], [1000, '1K'], [13642, '13.6K'],
    [185231, '185.2K'], [999949, '999.9K'], [999950, '1M'], [1000000, '1M'],
    [12345678, '12.3M'], [999950000, '1B']]) assert.equal(formatPostCount(count, 0), expected);
});

test('Chinese and full-number alternatives handle large counts and invalid values', () => {
  const { formatPostCount } = fixture().load('utils/PostCountFormat');
  assert.equal(formatPostCount(13642, 1), '1.4万');
  assert.equal(formatPostCount(123456789, 1), '1.2亿');
  assert.equal(formatPostCount(99995000, 1), '1亿');
  assert.equal(formatPostCount(123456789, 2), '123456789');
  for (const value of [NaN, Infinity, -1]) assert.equal(formatPostCount(value, 0), '0');
});

test('count format survives restart, rejects invalid choices and keeps confirmed state on save failure', () => {
  const f = fixture(), mod = f.load('services/PostDisplaySettingsStore');
  assert.equal(mod.postDisplaySettingsStore.loadCountFormat({}), 0);
  for (const format of [2, 1, 0]) {
    assert.equal(mod.postDisplaySettingsStore.saveCountFormat({}, format), true);
    assert.equal(new mod.PostDisplaySettingsStore().loadCountFormat({}), format);
    assert.equal(f.published.get(mod.STORAGE_KEY_POST_COUNT_FORMAT), format);
  }
  for (const format of [-1, 3, 0.5, NaN]) assert.equal(mod.postDisplaySettingsStore.saveCountFormat({}, format), false);
  f.fail();
  assert.equal(mod.postDisplaySettingsStore.saveCountFormat({}, 2), false);
  assert.equal(mod.postDisplaySettingsStore.loadCountFormat({}), 0);
  assert.equal(f.published.get(mod.STORAGE_KEY_POST_COUNT_FORMAT), 0);
});

test('sidebar ordering removes duplicate/retired IDs and appends all newly available features', () => {
  const mod = fixture().load('utils/SidebarItems');
  const ids = mod.sidebarOrderedIds('messages,explore,messages,removed');
  assert.deepEqual(ids.slice(0, 2), ['messages', 'explore']);
  assert.equal(new Set(ids).size, mod.SIDEBAR_ITEM_IDS.length);
  assert.equal(ids.includes('removed'), false);
  assert.equal(mod.SIDEBAR_ITEM_IDS.includes('search'), false);
  assert.equal(mod.sidebarOrderedIds('search,explore')[0], 'explore');
  assert.equal(mod.sidebarVisibleIds('messages,explore', 'explore,unknown').includes('explore'), false);
  assert.equal(mod.sidebarVisibleIds('messages,explore', '').includes('explore'), true);
  assert.deepEqual(mod.sidebarVisibleIds('', mod.SIDEBAR_ITEM_IDS.join(',')), []);
});

test('sidebar visibility and order survive reopening and restore defaults without losing features', () => {
  const f = fixture(), mod = f.load('services/SidebarSettingsStore');
  assert.equal(mod.sidebarSettingsStore.save({}, 'messages,explore', 'explore,retired,explore'), true);
  const state = new mod.SidebarSettingsStore().load({});
  assert.equal(state.order.split(',')[0], 'messages');
  assert.equal(state.hidden, 'explore');
  assert.equal(f.published.get(mod.STORAGE_KEY_SIDEBAR_HIDDEN), 'explore');
  assert.equal(mod.sidebarSettingsStore.save({}, '', ''), true);
  assert.equal(mod.sidebarSettingsStore.load({}).hidden, '');
});

test('Home, Explore and Messages default off while explicit user visibility choices survive reopening', () => {
  const f = fixture(), mod = f.load('services/SidebarSettingsStore');
  const items = f.load('utils/SidebarItems');
  const defaults = mod.sidebarSettingsStore.load({});
  assert.equal(defaults.hidden, items.DEFAULT_SIDEBAR_HIDDEN);
  const visible = items.sidebarVisibleIds(defaults.order, defaults.hidden);
  for (const id of ['home', 'explore', 'messages']) assert.equal(visible.includes(id), false);
  assert.equal(visible.includes('profile'), true);
  mod.sidebarSettingsStore.save({}, defaults.order, '');
  assert.equal(new mod.SidebarSettingsStore().load({}).hidden, '');
});

test('support and help remain in the footer partition even after an old saved order moves them first', () => {
  const mod = fixture().load('utils/SidebarItems');
  const order = mod.sidebarOrderedIds('help,support,messages,profile');
  assert.deepEqual(order.slice(-2), ['support', 'help']);
  assert.deepEqual(order.slice(0, 2), ['messages', 'profile']);
  assert.equal(mod.sidebarMainIds(order.join(','), '').includes('support'), false);
  assert.equal(mod.sidebarMainIds(order.join(','), '').includes('help'), false);
  assert.equal(mod.sidebarVisibleIds(order.join(','), 'support').includes('support'), false);
});

test('failed sidebar writes retain the prior saved and published configuration', () => {
  const f = fixture(), mod = f.load('services/SidebarSettingsStore');
  mod.sidebarSettingsStore.save({}, 'explore', 'premium');
  const before = mod.sidebarSettingsStore.load({});
  f.fail();
  assert.equal(mod.sidebarSettingsStore.save({}, 'home', 'messages'), false);
  assert.deepEqual(mod.sidebarSettingsStore.load({}), before);
  assert.equal(f.published.get(mod.STORAGE_KEY_SIDEBAR_HIDDEN), 'premium');
});

test('sidebar search capsule defaults off, persists independently and retains its choice on failure', () => {
  const f = fixture(), mod = f.load('services/SidebarSettingsStore');
  const store = mod.sidebarSettingsStore;
  assert.equal(store.load({}).searchCapsule, false);
  assert.equal(store.saveSearchCapsule({}, true), true);
  store.save({}, 'explore,home', 'premium');
  assert.equal(new mod.SidebarSettingsStore().load({}).searchCapsule, true);
  assert.equal(f.published.get(mod.STORAGE_KEY_SIDEBAR_SEARCH_CAPSULE), true);
  assert.equal(store.saveSearchCapsule({}, false), true);
  assert.equal(store.load({}).searchCapsule, false);
  f.fail();
  assert.equal(store.saveSearchCapsule({}, true), false);
  assert.equal(store.load({}).searchCapsule, false);
  assert.equal(f.published.get(mod.STORAGE_KEY_SIDEBAR_SEARCH_CAPSULE), false);
});

test('hiding the whole bottom bar preserves its separately configured pages', () => {
  const f = fixture(), mod = f.load('services/BottomBarSettingsStore'), store = mod.bottomBarSettingsStore;
  assert.equal(store.loadVisible({}), true);
  assert.equal(store.save({}, 3), true);
  assert.equal(store.saveVisible({}, false), true);
  assert.equal(new mod.BottomBarSettingsStore().loadVisible({}), false);
  assert.equal(store.load({}), 3);
  assert.equal(store.saveVisible({}, true), true);
  assert.equal(store.load({}), 3);
  f.fail();
  assert.equal(store.saveVisible({}, false), false);
  assert.equal(f.published.get(mod.STORAGE_KEY_BOTTOM_BAR_VISIBLE), true);
});

test('hidden-bar navigation selects every stable page ID even if the saved visible bar excludes it', () => {
  const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8').replace('struct Index', 'class Index');
  const parsed = ts.createSourceFile('Index.ts', source, ts.ScriptTarget.Latest, true);
  const root = parsed.statements.find(node => ts.isClassDeclaration(node) && node.name.text === 'Index');
  const method = root.members.find(node => node.name?.getText(parsed) === 'selectRootTabPage').getText(parsed);
  const code = ts.transpileModule('export class Root {\n' + method + '\n}', {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText;
  const api = {};
  new Function('exports', code)(api);
  const rootPage = new api.Root(), selected = [], mounted = [];
  Object.assign(rootPage, { bottomBarVisible: false, isDesktopLayout: () => false,
    onTabChange: id => selected.push(id), tabsController: { changeIndex: id => mounted.push(id) },
    isBottomBarPageEnabled: () => false });
  for (const id of [0, 1, 2, 3, 4]) rootPage.selectRootTabPage(id);
  assert.deepEqual(selected, [0, 1, 2, 3, 4]);
  assert.deepEqual(mounted, selected);
});

test('sidebar title inset converts resource pixels to vp once at every display density', () => {
  const source = fs.readFileSync('entry/src/main/ets/components/XSideDrawer.ets', 'utf8').replace('struct XSideDrawer', 'class XSideDrawer');
  const parsed = ts.createSourceFile('Drawer.ts', source, ts.ScriptTarget.Latest, true);
  const root = parsed.statements.find(node => ts.isClassDeclaration(node) && node.name.text === 'XSideDrawer');
  const method = root.members.find(node => node.name?.getText(parsed) === 'sidebarContentTopInset').getText(parsed);
  const code = ts.transpileModule('export class Drawer {\n' + method + '\n}', {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText;
  for (const density of [1, 2, 3.375]) {
    const api = {};
    new Function('exports', 'getContext', '$r', code)(api,
      () => ({ resourceManager: { getNumber: () => 56 * density } }), () => ({ id: 1 }));
    const drawer = new api.Drawer();
    Object.assign(drawer, { statusBarHeight: 39, getUIContext: () => ({ px2vp: px => px / density }) });
    assert.equal(drawer.sidebarContentTopInset(), 95);
  }
});

test('sidebar immersive material starts at API 23 and keeps gradient blur below that level', () => {
  const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8').replace('struct Index', 'class Index');
  const parsed = ts.createSourceFile('Index.ts', source, ts.ScriptTarget.Latest, true);
  const root = parsed.statements.find(node => ts.isClassDeclaration(node) && node.name.text === 'Index');
  const method = root.members.find(node => node.name?.getText(parsed) === 'sidebarTitleBarStyle').getText(parsed);
  const code = ts.transpileModule('export class Root {\n' + method + '\n}', {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText;
  for (const apiLevel of [22, 23, 24, 26]) {
    const api = {};
    new Function('exports', 'deviceInfo', 'ScrollEffectType', 'hdsMaterial', '$r', code)(api,
      { apiAvailable: version => { assert.equal(version, '6.1.0(23)'); return apiLevel >= 23; } },
      { GRADIENT_BLUR: 'gradient', IMMERSIVE_GRADIENT_BLUR: 'immersive' },
      { MaterialType: { IMMERSIVE: 'immersive' }, MaterialLevel: { ADAPTIVE: 'adaptive' } }, value => value);
    const style = new api.Root().sidebarTitleBarStyle();
    assert.equal(style.scrollEffectOpts.enableScrollEffect, true);
    assert.equal(style.scrollEffectOpts.scrollEffectType, apiLevel >= 23 ? 'immersive' : 'gradient');
    assert.deepEqual(style.systemMaterialEffect, apiLevel >= 23 ? { materialType: 'immersive', materialLevel: 'adaptive' } : undefined);
  }
});
